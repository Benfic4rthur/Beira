#ifndef BEIRA_TRACKPAD_BRIDGE_H
#define BEIRA_TRACKPAD_BRIDGE_H
#include <stdint.h>

typedef struct {
    int32_t identifier;
    int32_t state;
    double x;
    double y;
} BeiraContact;

typedef void (*BeiraFrameHandler)(void *context, const BeiraContact *contacts,
                                 int count, double timestamp);
// Calls start/stop on the main thread; a frame handler must not call either.
int BeiraTrackpadStart(BeiraFrameHandler handler, void *context);
void BeiraTrackpadStop(void);
const char *BeiraTrackpadError(void);
const char *BeiraTrackpadDeviceKind(void);
#endif
