#include "TrackpadBridge.h"
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdbool.h>
#include <stddef.h>
#include <math.h>

// Private ABI declarations adapted from OpenMultitouchSupport, MIT.
// Copyright (c) 2019 TakutoNakamura. See THIRD_PARTY_NOTICES.md.
typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint position, velocity; } MTVector;
typedef struct {
    int frame; double timestamp;
    int identifier, state, fingerId, handId;
    MTVector normalizedPosition;
    float total, pressure, angle, majorAxis, minorAxis;
    MTVector absolutePosition;
    int field14, field15; float density;
} MTTouch;
_Static_assert(sizeof(MTTouch) == 96, "Unexpected multitouch ABI");
_Static_assert(offsetof(MTTouch, normalizedPosition) == 32, "Unexpected contact offset");
typedef void *MTDevice;
typedef void (*MTCallback)(MTDevice, MTTouch *, int, double, int);
static CFArrayRef (*createList)(void);
static void (*registerCallback)(MTDevice, MTCallback);
static void (*unregisterCallback)(MTDevice, MTCallback);
static int (*startDevice)(MTDevice, int);
static int (*stopDevice)(MTDevice);
static bool (*isBuiltIn)(MTDevice);
static void *framework;
static CFArrayRef devices;
static MTDevice selected;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static BeiraFrameHandler receiver;
static void *receiverContext;
static const char *errorMessage = "";
static const char *deviceKind = "Trackpad";

static void receiveFrame(MTDevice device, MTTouch *touches, int count, double timestamp, int frame) {
    (void)frame;
    if (count < 0 || count > 32 || (count > 0 && !touches)) return;
    BeiraContact copied[32];
    for (int i = 0; i < count; i++) {
        copied[i] = (BeiraContact){touches[i].identifier, touches[i].state,
            touches[i].normalizedPosition.position.x, touches[i].normalizedPosition.position.y};
    }
    pthread_mutex_lock(&lock);
    if (receiver && device == selected) receiver(receiverContext, copied, count, timestamp);
    pthread_mutex_unlock(&lock);
}

const char *BeiraTrackpadError(void) { return errorMessage; }
const char *BeiraTrackpadDeviceKind(void) { return deviceKind; }

void BeiraTrackpadStop(void) {
    pthread_mutex_lock(&lock);
    receiver = NULL; receiverContext = NULL;
    MTDevice old = selected; selected = NULL;
    pthread_mutex_unlock(&lock);
    if (old) { unregisterCallback(old, receiveFrame); stopDevice(old); }
    if (devices) { CFRelease(devices); devices = NULL; }
}

int BeiraTrackpadStart(BeiraFrameHandler handler, void *context) {
    BeiraTrackpadStop();
    if (!framework) {
        framework = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW | RTLD_LOCAL);
        if (!framework) { errorMessage = "Não foi possível acessar o trackpad neste macOS."; return 0; }
        createList = dlsym(framework, "MTDeviceCreateList");
        registerCallback = dlsym(framework, "MTRegisterContactFrameCallback");
        unregisterCallback = dlsym(framework, "MTUnregisterContactFrameCallback");
        startDevice = dlsym(framework, "MTDeviceStart");
        stopDevice = dlsym(framework, "MTDeviceStop");
        isBuiltIn = dlsym(framework, "MTDeviceIsBuiltIn");
    }
    if (!createList || !registerCallback || !unregisterCallback || !startDevice || !stopDevice) {
        errorMessage = "Esta versão do macOS não oferece a interface de trackpad esperada."; return 0;
    }
    devices = createList();
    if (!devices) { errorMessage = "Nenhum trackpad encontrado."; return 0; }
    MTDevice choice = NULL;
    for (CFIndex i = 0; i < CFArrayGetCount(devices); i++) {
        MTDevice candidate = (MTDevice)CFArrayGetValueAtIndex(devices, i);
        // OpaqueSurface is not a trackpad predicate: the built-in Force Touch
        // trackpad on MacBookPro18,1 reports false. Prefer BuiltIn directly.
        if (!choice) choice = candidate;
        if (isBuiltIn && isBuiltIn(candidate)) { choice = candidate; break; }
    }
    if (!choice) { BeiraTrackpadStop(); errorMessage = "Conecte um trackpad para usar o Beira."; return 0; }
    deviceKind = isBuiltIn && isBuiltIn(choice) ? "Trackpad do MacBook" : "Trackpad externo";
    pthread_mutex_lock(&lock);
    selected = choice; receiver = handler; receiverContext = context;
    pthread_mutex_unlock(&lock);
    registerCallback(choice, receiveFrame);
    int result = startDevice(choice, 0);
    if (result != 0) { BeiraTrackpadStop(); errorMessage = "O trackpad não iniciou. Tente reconectar."; return 0; }
    errorMessage = "";
    return 1;
}
