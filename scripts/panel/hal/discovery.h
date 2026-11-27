// Runtime Sonos zone discovery (replaces the hardcoded zones file).
//
// Method (proven against the live house fleet):
//   1. SSDP M-SEARCH to 239.255.255.250:1900 for ST
//      urn:schemas-upnp-org:device:ZonePlayer:1 -> every live player's IP + USN
//      (USN carries the UDN = uuid:RINCON_<hex>, our stable key).
//   2. Per player: DeviceProperties.GetZoneAttributes (SOAP POST :1400) ->
//      CurrentZoneName (full room name, no truncation).
//   3. Stable port id per UDN via a persistent map (survives refresh/reorder).
//
// The static zones file (kZonesFile) is an OPTIONAL override/seed only: if present
// its lines seed the discovery (and force name/ip overrides); it is never the sole
// source of truth. If discovery finds nothing we keep the last good set (or the
// file's contents) rather than clearing.
#pragma once
#include <atomic>
#include <cerrno>
#include <cstring>
#include <map>
#include <set>
#include <mutex>
#include <netinet/in.h>
#include <poll.h>
#include <string>
#include <thread>
#include <vector>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>

#ifndef SDLOGI   /* host test defines its own */
#define SD_LOG_TAG "sonos_disc"
#define SDLOGI(...) __android_log_print(ANDROID_LOG_INFO, SD_LOG_TAG, __VA_ARGS__)
#define SDLOGW(...) __android_log_print(ANDROID_LOG_WARN, SD_LOG_TAG, __VA_ARGS__)
#define SDLOGE(...) __android_log_print(ANDROID_LOG_ERROR, SD_LOG_TAG, __VA_ARGS__)
#endif

struct SdZone {
    std::string uuid;   // RINCON_<hex> (stable key)
    std::string ip;
    std::string name;
    int portId = 0;
};

class SonosDiscovery {
public:
    // a device that can play advertises AVTransport; a Boost (bridge) or a hidden bonded half does not
    static bool isPlayer(const std::string& ip) {
        std::string d = httpGetBody(ip, "/xml/device_description.xml", 3000);
        if (d.empty()) return true;   // unreachable now: keep it (a remembered amp stays listed)
        return d.find("urn:schemas-upnp-org:service:AVTransport:1") != std::string::npos;
    }
    std::set<std::string> notPlayers() { std::lock_guard<std::mutex> g(m_); return notPlayers_; }
    explicit SonosDiscovery(const char* zonesFile, int firstPortId)
        : zonesFile_(zonesFile), firstPortId_(firstPortId) {}

    // Never blocks the caller: the first search runs on the discovery thread. Audio services are
    // created during boot, before the network is up, and audio policy waits on them.
    void start() {
        loadSeedFromFileLocked();
        running_.store(true);
        thread_ = std::thread([this] { refresh(); loop(); });
    }
    void stop() {
        running_.store(false);
        if (thread_.joinable()) thread_.join();
    }
    std::vector<SdZone> all() {
        std::lock_guard<std::mutex> g(m_);
        return zones_;
    }

private:
    static constexpr int kRefreshSec = 20;

    void loop() {
        while (running_.load()) {
            for (int i = 0; i < kRefreshSec * 5 && running_.load(); i++) usleep(200 * 1000);
            if (!running_.load()) break;
            refresh();
        }
    }

    // ---- low-level helpers -------------------------------------------------
    static std::string httpGetBody(const std::string& ip, const std::string& path, int timeoutMs) {
        int fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd < 0) return "";
        sockaddr_in sa{};
        sa.sin_family = AF_INET;
        sa.sin_port = htons(1400);
        if (inet_pton(AF_INET, ip.c_str(), &sa.sin_addr) != 1) { close(fd); return ""; }
        timeval tv{timeoutMs / 1000, (timeoutMs % 1000) * 1000};
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
        if (connect(fd, (sockaddr*)&sa, sizeof(sa)) < 0) { close(fd); return ""; }
        std::string req = "GET " + path + " HTTP/1.1\r\nHost: " + ip + ":1400\r\nConnection: close\r\n\r\n";
        send(fd, req.data(), req.size(), MSG_NOSIGNAL);
        std::string body;
        char buf[2048];
        ssize_t n;
        bool hdrDone = false;
        size_t hdrSkip = 0;
        std::string raw;
        while ((n = recv(fd, buf, sizeof(buf), 0)) > 0) {
            raw.append(buf, n);
            if (!hdrDone) {
                size_t p = raw.find("\r\n\r\n");
                if (p != std::string::npos) { hdrDone = true; hdrSkip = p + 4; }
            }
            if (raw.size() > 65536) break;
        }
        close(fd);
        if (hdrDone && raw.size() > hdrSkip) body = raw.substr(hdrSkip);
        return body;
    }

    static std::string soapGetZoneName(const std::string& ip, int timeoutMs) {
        int fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd < 0) return "";
        sockaddr_in sa{};
        sa.sin_family = AF_INET;
        sa.sin_port = htons(1400);
        if (inet_pton(AF_INET, ip.c_str(), &sa.sin_addr) != 1) { close(fd); return ""; }
        timeval tv{timeoutMs / 1000, (timeoutMs % 1000) * 1000};
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
        if (connect(fd, (sockaddr*)&sa, sizeof(sa)) < 0) { close(fd); return ""; }
        std::string bodyXml =
            "<u:GetZoneAttributes xmlns:u=\"urn:schemas-upnp-org:service:DeviceProperties:1\">"
            "<InstanceID>0</InstanceID></u:GetZoneAttributes>";
        std::string env =
            "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
            "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" "
            "s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">"
            "<s:Body>" + bodyXml + "</s:Body></s:Envelope>";
        std::string req = "POST /DeviceProperties/Control HTTP/1.1\r\n"
            "Host: " + ip + ":1400\r\n"
            "Content-Type: text/xml; charset=\"utf-8\"\r\n"
            "SOAPACTION: \"urn:schemas-upnp-org:service:DeviceProperties:1#GetZoneAttributes\"\r\n"
            "Connection: close\r\n"
            "Content-Length: " + std::to_string(env.size()) + "\r\n\r\n" + env;
        send(fd, req.data(), req.size(), MSG_NOSIGNAL);
        std::string raw;
        char buf[2048];
        ssize_t n;
        while ((n = recv(fd, buf, sizeof(buf), 0)) > 0) { raw.append(buf, n); if (raw.size() > 65536) break; }
        close(fd);
        // extract <CurrentZoneName>...</CurrentZoneName>
        size_t a = raw.find("<CurrentZoneName>");
        if (a == std::string::npos) return "";
        a += strlen("<CurrentZoneName>");
        size_t b = raw.find("</CurrentZoneName>", a);
        if (b == std::string::npos) return "";
        return raw.substr(a, b - a);
    }


    // ZoneGroupTopology.GetZoneGroupState from one player: the set of player IPs that are
    // VISIBLE (not Invisible="1": subs, surrounds, bonded stereo partners, players hidden in the
    // Sonos app). One entry per player; two separate rooms may share a name (two "Loft"s here).
    // Returns empty on any failure; caller then falls back to the raw SSDP set.
    static std::map<std::string, std::string> visibleRooms(const std::string& ip, int timeoutMs) {
        std::map<std::string, std::string> out;   // ip -> room name
        int fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd < 0) return out;
        sockaddr_in sa{}; sa.sin_family = AF_INET; sa.sin_port = htons(1400);
        if (inet_pton(AF_INET, ip.c_str(), &sa.sin_addr) != 1) { close(fd); return out; }
        timeval tv{timeoutMs / 1000, (timeoutMs % 1000) * 1000};
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
        if (connect(fd, (sockaddr*)&sa, sizeof(sa)) < 0) { close(fd); return out; }
        std::string env =
            "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
            "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" "
            "s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"><s:Body>"
            "<u:GetZoneGroupState xmlns:u=\"urn:schemas-upnp-org:service:ZoneGroupTopology:1\"/>"
            "</s:Body></s:Envelope>";
        std::string req = "POST /ZoneGroupTopology/Control HTTP/1.1\r\nHost: " + ip + ":1400\r\n"
            "Content-Type: text/xml; charset=\"utf-8\"\r\n"
            "SOAPACTION: \"urn:schemas-upnp-org:service:ZoneGroupTopology:1#GetZoneGroupState\"\r\n"
            "Connection: close\r\nContent-Length: " + std::to_string(env.size()) + "\r\n\r\n" + env;
        send(fd, req.data(), req.size(), MSG_NOSIGNAL);
        std::string raw; char buf[4096]; ssize_t n;
        while ((n = recv(fd, buf, sizeof(buf), 0)) > 0) { raw.append(buf, n); if (raw.size() > 1 << 20) break; }
        close(fd);
        // the state is XML-escaped inside the SOAP body
        auto unesc = [](std::string t) {
            const char* from[] = {"&lt;", "&gt;", "&quot;", "&apos;", "&amp;"};
            const char* to[]   = {"<", ">", "\"", "'", "&"};
            for (int i = 0; i < 5; i++) { size_t q = 0; while ((q = t.find(from[i], q)) != std::string::npos) { t.replace(q, strlen(from[i]), to[i]); q += strlen(to[i]); } }
            return t;
        };
        raw = unesc(raw);
        auto attr = [](const std::string& tag, const char* key) -> std::string {
            std::string k = std::string(" ") + key + "=\"";
            size_t a = tag.find(k); if (a == std::string::npos) return "";
            a += k.size(); size_t b = tag.find('"', a); if (b == std::string::npos) return "";
            return tag.substr(a, b - a);
        };
        size_t pos = 0;
        while ((pos = raw.find("<ZoneGroupMember ", pos)) != std::string::npos) {
            size_t end = raw.find('>', pos); if (end == std::string::npos) break;
            std::string tag = raw.substr(pos, end - pos); pos = end;
            if (attr(tag, "Invisible") == "1") continue;
            std::string name = attr(tag, "ZoneName"), loc = attr(tag, "Location");
            size_t s1 = loc.find("//"), s2 = loc.find(':', s1 == std::string::npos ? 0 : s1 + 2);
            if (name.empty() || s1 == std::string::npos || s2 == std::string::npos) continue;
            out[loc.substr(s1 + 2, s2 - s1 - 2)] = name;
        }
        return out;
    }

    // SSDP M-SEARCH: returns map ip -> udn(RINCON_...)
    static std::map<std::string, std::string> ssdpSearch(int timeoutMs) {
        std::map<std::string, std::string> out;
        int fd = socket(AF_INET, SOCK_DGRAM, 0);
        if (fd < 0) { SDLOGW("discovery: cannot open UDP socket (errno %d) - no network permission?", errno); return out; }
        // Unbound socket: M-SEARCH replies are unicast back to our ephemeral port, so there is
        // no need to bind :1900 or join the multicast group (that would need extra SELinux grants
        // and could collide with another SSDP listener on the panel).
        unsigned char ttl = 2;
        setsockopt(fd, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, sizeof(ttl));
        const char* q =
            "M-SEARCH * HTTP/1.1\r\n"
            "HOST: 239.255.255.250:1900\r\n"
            "MAN: \"ssdp:discover\"\r\n"
            "MX: 2\r\n"
            "ST: urn:schemas-upnp-org:device:ZonePlayer:1\r\n\r\n";
        sockaddr_in dst{};
        dst.sin_family = AF_INET;
        dst.sin_port = htons(1900);
        dst.sin_addr.s_addr = inet_addr("239.255.255.250");
        sendto(fd, q, strlen(q), 0, (sockaddr*)&dst, sizeof(dst));
        sendto(fd, q, strlen(q), 0, (sockaddr*)&dst, sizeof(dst));
        pollfd pf{fd, POLLIN, 0};
        char rbuf[2048];
        while (poll(&pf, 1, timeoutMs) > 0) {
            socklen_t cl = sizeof(dst);
            ssize_t n = recvfrom(fd, rbuf, sizeof(rbuf) - 1, 0, (sockaddr*)&dst, &cl);
            if (n <= 0) break;
            rbuf[n] = 0;
            std::string t(rbuf, n);
            // LOCATION: http://IP:1400/...
            size_t lp = t.find("LOCATION:");
            std::string ip;
            if (lp != std::string::npos) {
                size_t s = t.find_first_not_of(" \t", lp + 9);
                size_t e = t.find_first_of(" \t\r\n", s);
                std::string loc = t.substr(s, e - s);          // http://IP:1400/...
                size_t cs = loc.find("://");
                if (cs != std::string::npos) {
                    size_t sl = cs + 3;
                    size_t el = loc.find(':', sl);             // end of IP (before :port)
                    if (el != std::string::npos) ip = loc.substr(sl, el - sl);
                }
            }
            // USN: uuid:RINCON_...:urn:...
            std::string udn;
            size_t up = t.find("USN:");
            if (up != std::string::npos) {
                size_t s = t.find_first_not_of(" \t", up + 4);
                size_t e = t.find_first_of(" \t\r\n", s);
                std::string usn = t.substr(s, e - s);
                size_t uu = usn.find("uuid:");
                if (uu != std::string::npos) {
                    size_t rs = uu + 5;
                    size_t re = usn.find(':', rs);             // RINCON_<hex> ends before next ':'
                    if (re != std::string::npos) udn = usn.substr(rs, re - rs);
                }
            }
            if (!ip.empty()) {
                if (!udn.empty()) out[ip] = udn;               // prefer USN-derived udn
                else if (out.find(ip) == out.end()) out[ip] = "";
            }
        }
        close(fd);
        return out;
    }

    // ---- registry maintenance ---------------------------------------------
    void loadSeedFromFileLocked() {
        FILE* f = fopen(zonesFile_, "r");
        if (!f) return;
        char line[320];
        while (fgets(line, sizeof(line), f)) {
            // format: <ip> <name...>   (name may contain spaces)
            char ipbuf[64] = {};
            char* sp = strchr(line, ' ');
            if (!sp) continue;
            size_t il = sp - line;
            if (il >= sizeof(ipbuf)) il = sizeof(ipbuf) - 1;
            memcpy(ipbuf, line, il);
            ipbuf[il] = 0;
            std::string name = sp + 1;
            while (!name.empty() && (name.front() == ' ' || name.front() == '\t')) name.erase(name.begin());
            while (!name.empty() && (name.back() == '\n' || name.back() == '\r' || name.back() == ' ')) name.pop_back();
            if (name.empty()) name = ipbuf;
            auto it = seed_.find(std::string(ipbuf));
            seed_[std::string(ipbuf)] = name;
        }
        fclose(f);
    }

    int assignPortLocked(const std::string& uuid) {
        auto it = uuidToPort_.find(uuid);
        if (it != uuidToPort_.end()) return it->second;
        int p = firstPortId_ + nextPort_++;   // device ports start after the mix port
        uuidToPort_[uuid] = p;
        return p;
    }

    void refresh() {
        std::map<std::string, std::string> found = ssdpSearch(2500);   // ip -> udn
        // one output per Sonos amp/player SSDP finds; no Sonos grouping is applied
        // merge file seeds (they may carry a udn-less ip we still want)
        {
            std::lock_guard<std::mutex> g(m_);
            for (auto& kv : seed_) if (found.find(kv.first) == found.end()) found[kv.first] = "";
        }
        std::vector<SdZone> next;
        int got = 0;
        for (auto& kv : found) {
            const std::string& ip = kv.first;
            // only a device that can play is an output: a Boost (bridge) or the hidden half of a
            // bonded pair advertises no AVTransport service, and picking it would play nothing.
            if (!isPlayer(ip)) {
                SDLOGI("discovery: %s is not a player (no AVTransport); skipped", ip.c_str());
                std::lock_guard<std::mutex> g(m_);
                notPlayers_.insert(ip);
                continue;
            }
            std::string udn = kv.second;
            std::string name;
            if (!udn.empty()) name = udn;                 // fallback name = udn
            std::string zn = soapGetZoneName(ip, 3000);
            if (!zn.empty()) name = zn;
            // optional file override wins for the name if present
            {
                std::lock_guard<std::mutex> g(m_);
                auto sit = seed_.find(ip);
                if (sit != seed_.end() && !sit->second.empty()) name = sit->second;
            }
            if (udn.empty()) udn = "ip-" + ip;            // stable-ish key if no UDN
            SdZone z;
            z.uuid = udn; z.ip = ip; z.name = name;
            {
                std::lock_guard<std::mutex> g(m_);
                z.portId = assignPortLocked(udn);
            }
            next.push_back(z);
            got++;
        }
        std::lock_guard<std::mutex> g(m_);
        if (got > 0) {
            zones_ = std::move(next);
        } else if (zones_.empty()) {
            // never had anything: fall back to file seeds so we're not empty
            for (auto& kv : seed_) {
                SdZone z; z.uuid = "ip-" + kv.first; z.ip = kv.first; z.name = kv.second;
                z.portId = assignPortLocked(z.uuid);
                zones_.push_back(z);
            }
        }
        // else: keep last good set (do NOT clear on transient failure)
        SDLOGI("discovery: %zu zones (ssdp=%zu)", zones_.size(), found.size());
    }

    const char* zonesFile_;
    int firstPortId_;
    int nextPort_ = 0;
    std::map<std::string, std::string> seed_;        // ip -> forced name (optional override)
    std::map<std::string, int> uuidToPort_;           // stable port assignment
    std::mutex m_;
    std::vector<SdZone> zones_;
    std::set<std::string> notPlayers_;                 // answered, but cannot play (Boost, bonded half)
    std::atomic<bool> running_{false};
    std::thread thread_;
};
