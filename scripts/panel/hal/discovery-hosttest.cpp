// Host-side check of discovery.h against the real Sonos system (run on tellah, not the panel).
// Build+run: scripts/panel/hal/hosttest.sh
#include <cstdio>
#include <unistd.h>
#define SDLOGI(...) do { fprintf(stderr, __VA_ARGS__); fputc(10, stderr); } while (0)
#define SDLOGW SDLOGI
#define SDLOGE SDLOGI
#include "discovery.h"
int main() {
    SonosDiscovery d(4097);
    d.searchNow();   // the same blocking search the audio service runs at start
    for (auto& z : d.all()) printf("%s\t%s\t%d\t%s\n", z.ip.c_str(), z.name.c_str(), z.portId, z.uuid.c_str());
    return d.all().empty() ? 1 : 0;
}
