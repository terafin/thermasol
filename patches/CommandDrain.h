#pragma once
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <deque>
#include <mutex>
#include <vector>

// Tracks command acknowledgements, not the controller's command-credit count.
class CommandDrain {
 public:
  uint64_t submit(const std::vector<uint8_t>& packet) {
    if (packet.size()<3 || packet.size()!=static_cast<size_t>(packet[2])+3) return 0;
    const uint16_t opcode=packet[0]|(static_cast<uint16_t>(packet[1])<<8);
    // Host Number Of Completed Packets has no Command Complete/Status event.
    if (opcode==0x0c35) return 0;
    std::lock_guard<std::mutex> lock(mutex_);
    const uint64_t token=++sequence_;
    pending_.push_back({token,opcode});
    return token;
  }
  void cancel(uint64_t token) {
    std::lock_guard<std::mutex> lock(mutex_);
    for (auto i=pending_.begin();i!=pending_.end();++i) if(i->token==token) {pending_.erase(i);break;}
    cv_.notify_all();
  }
  void event(const std::vector<uint8_t>& packet) {
    if (packet.size()<2 || packet.size()!=static_cast<size_t>(packet[1])+2) return;
    size_t offset;
    if(packet[0]==0x0e && packet.size()>=5) offset=3;
    else if(packet[0]==0x0f && packet.size()==6) offset=4;
    else return;
    const uint16_t opcode=packet[offset]|(static_cast<uint16_t>(packet[offset+1])<<8);
    std::lock_guard<std::mutex> lock(mutex_);
    for(auto i=pending_.begin();i!=pending_.end();++i) if(i->opcode==opcode) {pending_.erase(i);break;}
    cv_.notify_all();
  }
  bool waitFor(std::chrono::milliseconds timeout) {
    std::unique_lock<std::mutex> lock(mutex_);
    return cv_.wait_for(lock,timeout,[this]{return pending_.empty();});
  }
  size_t pending() {std::lock_guard<std::mutex> lock(mutex_);return pending_.size();}
  void clear() {std::lock_guard<std::mutex> lock(mutex_);pending_.clear();cv_.notify_all();}
 private:
  struct Entry {uint64_t token;uint16_t opcode;};
  std::mutex mutex_;
  std::condition_variable cv_;
  std::deque<Entry> pending_;
  uint64_t sequence_{0};
};
