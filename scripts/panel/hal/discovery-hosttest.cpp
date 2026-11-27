// Host-side check of discovery.h against the real Sonos system (run on tellah, not the panel).
// Build+run: scripts/panel/hal/hosttest.sh
#include <cstdio>
#include <unistd.h>
#define SDLOGI(...) do { fprintf(stderr, __VA_ARGS__); fputc(10, stderr); } while (0)
#define SDLOGW SDLOGI
#define SDLOGE SDLOGI
#include "discovery.h"
int main() {
    SonosDiscovery d("/nonexistent", 4097);
    d.start();
    // start() searches on its own thread; wait out the whole first search (SSDP 2.5 s + topology 3 s)
    usleep(9 * 1000 * 1000);
    for (auto& z : d.all()) printf("%s\t%s\t%d\t%s\n", z.ip.c_str(), z.name.c_str(), z.portId, z.uuid.c_str());
    d.stop();
    return d.all().empty() ? 1 : 0;
}
