# gapprobe: for each bitrate, sync to a 0x120 generator frame at 100k, then switch and send one
# 101#01 inside the ~1 s quiet gap; report whether the controller got it ACKed (tx_packets moved).
P=/data/local/tmp
setbr(){ ip link set can0 down; ip link set can0 type can bitrate $1 restart-ms 0 $2; ip link set can0 up; }
for br in 16666 20000 25000 33333 40000 50000 62500 83333 125000 200000 250000 400000 500000 800000 1000000; do
  setbr 100000
  $P/canprobe 1200 >/dev/null 2>&1          # wait until a generator frame has gone by
  setbr $br
  p0=$(cat /sys/class/net/can0/statistics/tx_packets)
  $P/canprobe 200 101#01 > $P/gp.txt 2>&1
  p1=$(cat /sys/class/net/can0/statistics/tx_packets)
  st=$(ip -d link show can0 | grep -o "can state [A-Z-]* (berr-counter tx [0-9]* rx [0-9]*)")
  real=$(ip -d link show can0 | grep -o "bitrate [0-9]*" | head -1)
  echo "== $real acked=$((p1-p0)) $st $(grep RX $P/gp.txt | head -2 | tr '\n' ' ')"
done
setbr 100000; ip link set can0 down; ip link set can0 type can bitrate 100000 restart-ms 100; ip link set can0 up
ip -d link show can0 | grep -o "can state [A-Z-]*"
