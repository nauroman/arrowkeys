#import "Navigation.h"
#include <unistd.h>

@interface StoreHotKeys : NSObject
- (OSStatus)registerShortcuts;
- (void)unregisterShortcuts;
- (void)cancelRepeat;
@end

@implementation StoreHotKeys {
    EventHandlerRef _handler;
    EventHotKeyRef _keys[bindingCount];
    NSTimer *_repeat;
    UInt32 _heldID;
    pid_t _target;
}

- (void)cancelRepeat {
    [_repeat invalidate];
    _repeat = nil;
    _heldID = 0;
    _target = 0;
}

- (BOOL)sendArrow {
    NSRunningApplication *front = NSWorkspace.sharedWorkspace.frontmostApplication;
    if (!_heldID || _target <= 0 || _target == getpid() || front.processIdentifier != _target ||
        IsSecureEventInputEnabled() || !CGPreflightPostEventAccess()) return NO;
    Binding binding = bindings[_heldID - 1];
    CGEventRef down = CGEventCreateKeyboardEvent(NULL, binding.arrow, true);
    CGEventRef up = CGEventCreateKeyboardEvent(NULL, binding.arrow, false);
    if (down && up) {
        setNavigationArrow(down, binding, 0);
        setNavigationArrow(up, binding, 0);
        CGEventPostToPid(_target, down);
        CGEventPostToPid(_target, up);
    }
    BOOL sent = down && up;
    if (down) CFRelease(down);
    if (up) CFRelease(up);
    return sent;
}

- (void)shortcut:(UInt32)identifier pressed:(BOOL)pressed {
    if (!pressed) {
        if (_heldID == identifier) [self cancelRepeat];
        return;
    }
    if (_heldID == identifier) return;
    [self cancelRepeat];
    _heldID = identifier;
    _target = NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier;
    if (![self sendArrow]) { [self cancelRepeat]; return; }
    NSTimeInterval interval = NSEvent.keyRepeatInterval, delay = NSEvent.keyRepeatDelay;
    if (interval <= 0 || delay <= 0) return;
    _repeat = [NSTimer timerWithTimeInterval:interval repeats:YES block:^(NSTimer *timer) {
        if (![self sendArrow]) [self cancelRepeat];
    }];
    _repeat.fireDate = [NSDate dateWithTimeIntervalSinceNow:delay];
    [[NSRunLoop mainRunLoop] addTimer:_repeat forMode:NSRunLoopCommonModes];
}

static OSStatus handleShortcut(EventHandlerCallRef next, EventRef event, void *context) {
    EventHotKeyID key;
    OSStatus result = GetEventParameter(event, kEventParamDirectObject, typeEventHotKeyID,
                                        NULL, sizeof(key), NULL, &key);
    if (result != noErr || key.signature != 'ArKS' || key.id < 1 || key.id > bindingCount)
        return eventNotHandledErr;
    [(__bridge StoreHotKeys *)context shortcut:key.id pressed:GetEventKind(event) == kEventHotKeyPressed];
    return noErr;
}

- (OSStatus)registerShortcuts {
    if (_handler) return noErr;
    const EventTypeSpec events[] = {{kEventClassKeyboard, kEventHotKeyPressed},
                                    {kEventClassKeyboard, kEventHotKeyReleased}};
    OSStatus status = InstallApplicationEventHandler(handleShortcut, 2, events,
                                                      (__bridge void *)self, &_handler);
    for (UInt32 i = 0; status == noErr && i < bindingCount; ++i) {
        EventHotKeyID key = {'ArKS', i + 1};
        status = RegisterEventHotKey(bindings[i].input, optionKey, key,
                                     GetApplicationEventTarget(), kEventHotKeyExclusive, &_keys[i]);
    }
    if (status != noErr) [self unregisterShortcuts];
    return status;
}

- (void)unregisterShortcuts {
    [self cancelRepeat];
    for (NSUInteger i = 0; i < bindingCount; ++i) {
        if (_keys[i]) UnregisterEventHotKey(_keys[i]);
        _keys[i] = NULL;
    }
    if (_handler) RemoveEventHandler(_handler);
    _handler = NULL;
}
@end
