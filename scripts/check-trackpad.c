// Standalone read-only bridge diagnostic. Never emits keyboard or mouse events.
#include "TrackpadBridge.h"
#include <stdio.h>
#include <unistd.h>
#include <stdatomic.h>
#include <math.h>

static atomic_int frames, activeContacts, invalidContacts;
static void receive(void *context, const BeiraContact *contacts, int count, double timestamp) {
    (void)context; (void)timestamp;
    atomic_fetch_add(&frames, 1);
    for (int i = 0; i < count; i++) {
        if (!isfinite(contacts[i].x) || !isfinite(contacts[i].y) ||
            contacts[i].x < 0 || contacts[i].x > 1 || contacts[i].y < 0 || contacts[i].y > 1 ||
            contacts[i].state < 0 || contacts[i].state > 7) atomic_fetch_add(&invalidContacts, 1);
        if (contacts[i].state == 3 || contacts[i].state == 4) atomic_fetch_add(&activeContacts, 1);
    }
}
int main(void) {
    int started = BeiraTrackpadStart(receive, NULL);
    if (!started) { fprintf(stderr, "%s\n", BeiraTrackpadError()); return 1; }
    printf("Device: %s\n", BeiraTrackpadDeviceKind());
    sleep(3);
    BeiraTrackpadStop();
    printf("Frames: %d; active contact samples: %d; invalid samples: %d\n",
        atomic_load(&frames), atomic_load(&activeContacts), atomic_load(&invalidContacts));
    return atomic_load(&invalidContacts) == 0 ? 0 : 2;
}
