#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <ApplicationServices/ApplicationServices.h>
#import <ServiceManagement/ServiceManagement.h>

typedef struct { CGKeyCode input, arrow; CGEventFlags modifier; } Binding;
static const Binding bindings[] = {
    {kVK_ANSI_J, kVK_LeftArrow, 0}, {kVK_ANSI_K, kVK_DownArrow, 0},
    {kVK_ANSI_L, kVK_RightArrow, 0}, {kVK_ANSI_I, kVK_UpArrow, 0},
    {kVK_ANSI_U, kVK_LeftArrow, kCGEventFlagMaskCommand},
    {kVK_ANSI_O, kVK_RightArrow, kCGEventFlagMaskCommand},
    {kVK_ANSI_H, kVK_LeftArrow, kCGEventFlagMaskAlternate},
    {kVK_ANSI_Semicolon, kVK_RightArrow, kCGEventFlagMaskAlternate}
};
static bool held[sizeof(bindings) / sizeof(bindings[0])];
static CFMachPortRef tap;

static CGEventRef translate(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *context) {
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        memset(held, 0, sizeof(held));
        if (tap) CGEventTapEnable(tap, true);
        return event;
    }
    if (type != kCGEventKeyDown && type != kCGEventKeyUp) return event;
    int64_t code = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    CGEventFlags flags = CGEventGetFlags(event);
    const CGEventFlags modifiers = kCGEventFlagMaskAlternate | kCGEventFlagMaskCommand |
        kCGEventFlagMaskShift | kCGEventFlagMaskControl | kCGEventFlagMaskSecondaryFn;
    for (size_t i = 0; i < sizeof(bindings) / sizeof(bindings[0]); ++i) {
        if (bindings[i].input != code) continue;
        if (type == kCGEventKeyDown && !CGEventGetIntegerValueField(event, kCGKeyboardEventAutorepeat))
            held[i] = (flags & modifiers) == kCGEventFlagMaskAlternate;
        if (!held[i]) break;
        if (type == kCGEventKeyUp) held[i] = false;
        CGEventSetIntegerValueField(event, kCGKeyboardEventKeycode, bindings[i].arrow);
        // Clear device-dependent Option bits too. Arrow key events carry the keypad flag.
        CGEventSetFlags(event, (flags & kCGEventFlagMaskAlphaShift) |
                        bindings[i].modifier | kCGEventFlagMaskNumericPad | kCGEventFlagMaskSecondaryFn);
        const UniChar arrowCharacters[] = {NSLeftArrowFunctionKey, NSRightArrowFunctionKey,
                                           NSDownArrowFunctionKey, NSUpArrowFunctionKey};
        CGEventKeyboardSetUnicodeString(event, 1, &arrowCharacters[bindings[i].arrow - kVK_LeftArrow]);
        break;
    }
    return event;
}

#ifndef ARROWKEYS_TEST
#import "KeyboardMapping.h"
@interface Controller : NSObject <NSApplicationDelegate>
@property(strong) KeyboardMapping *keyboards;
@property(strong) NSStatusItem *item;
@property(strong) NSMenuItem *status;
@property(strong) NSMenuItem *login;
@end
@implementation Controller
- (void)connect {
    if (tap && CFMachPortIsValid(tap) && CGEventTapIsEnabled(tap)) {
        self.status.title = [self.keyboards refresh] ? @"Navigation active" : @"Could not configure a keyboard";
        return;
    }
    if (tap) { CFMachPortInvalidate(tap); CFRelease(tap); tap = NULL; }
    memset(held, 0, sizeof(held));
    if (AXIsProcessTrusted()) {
        CGEventMask keys = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp);
        tap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault,
                               keys, translate, NULL);
        if (tap) {
            CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(NULL, tap, 0);
            CFRunLoopAddSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes);
            CFRelease(source);
        }
    }
    self.status.title = tap ? @"Navigation active" : @"Waiting for Accessibility permission";
}
- (void)applicationWillTerminate:(NSNotification *)notification { [self.keyboards restore]; }
- (void)access:(id)sender {
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
}
- (void)toggleLogin:(id)sender {
    SMAppService *service = SMAppService.mainAppService;
    NSError *error = nil;
    if (service.status == SMAppServiceStatusEnabled) [service unregisterAndReturnError:&error];
    else if (service.status == SMAppServiceStatusRequiresApproval) [SMAppService openSystemSettingsLoginItems];
    else [service registerAndReturnError:&error];
    self.login.state = service.status == SMAppServiceStatusEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    if (error) [NSApp presentError:error];
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.keyboards = [KeyboardMapping new];
    self.item = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.item.button.title = @"⇥";
    self.item.button.toolTip = @"ArrowKeys";
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"ArrowKeys"];
    self.status = [menu addItemWithTitle:@"ArrowKeys" action:nil keyEquivalent:@""];
    [menu addItemWithTitle:@"Accessibility Settings…" action:@selector(access:) keyEquivalent:@""].target = self;
    self.login = [menu addItemWithTitle:@"Open at Login" action:@selector(toggleLogin:) keyEquivalent:@""];
    self.login.target = self;
    self.login.state = SMAppService.mainAppService.status == SMAppServiceStatusEnabled;
    [menu addItemWithTitle:@"Quit ArrowKeys" action:@selector(terminate:) keyEquivalent:@"q"].target = NSApp;
    self.item.menu = menu;
    if (!AXIsProcessTrusted()) {
        NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
        AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    }
    [self connect];
    [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer){ [self connect]; }];
}
@end
int main(void) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        __attribute__((objc_precise_lifetime)) Controller *controller = [Controller new];
        app.delegate = controller;
        [app run];
    }
    return 0;
}
#endif
