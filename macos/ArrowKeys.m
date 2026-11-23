#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <ApplicationServices/ApplicationServices.h>
#import <ServiceManagement/ServiceManagement.h>
#include <fcntl.h>
#include <unistd.h>

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

static NSImage *menuBarIcon(void) {
    NSImage *icon = [NSImage imageNamed:@"ArrowKeysMenuTemplate.svg"];
    icon.template = YES;
    return icon;
}

static NSString *const loginSetupKey = @"OpenAtLoginConfigured";

static BOOL offerAccessibilitySetup(NSUserDefaults *defaults, NSString *build, BOOL trusted) {
    NSString *const key = @"AccessibilitySetupShownForBuild";
    if (trusted || [[defaults stringForKey:key] isEqualToString:build]) return NO;
    [defaults setObject:build forKey:key];
    return YES;
}

static void configureLoginDefault(NSUserDefaults *defaults, SMAppServiceStatus status, BOOL (^registerItem)(void)) {
    if ([defaults boolForKey:loginSetupKey]) return;
    // Once configured, macOS owns the setting, including changes in System Settings.
    if (status == SMAppServiceStatusEnabled || status == SMAppServiceStatusRequiresApproval || registerItem())
        [defaults setBool:YES forKey:loginSetupKey];
}

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
@interface Controller : NSObject <NSApplicationDelegate, NSMenuDelegate>
@property(strong) KeyboardMapping *keyboards;
@property(strong) NSStatusItem *item;
@property(strong) NSMenuItem *status;
@property(strong) NSMenuItem *login;
@property(strong) NSAlert *accessibilityHelp;
@property(strong) dispatch_source_t bundleWatcher;
@end
@implementation Controller
- (void)disconnect {
    if (tap) {
        CGEventTapEnable(tap, false);
        CFMachPortInvalidate(tap);
        CFRelease(tap);
        tap = NULL;
    }
    memset(held, 0, sizeof(held));
    [self.keyboards restore];
}
- (void)connect {
    if (!AXIsProcessTrusted()) {
        [self disconnect];
        self.status.title = @"Set Up Accessibility…";
        self.status.action = @selector(showAccessibilitySetup:);
        return;
    }
    self.status.action = nil;
    if (self.accessibilityHelp) [self dismissAccessibilitySetup:nil];
    if (tap && (!CFMachPortIsValid(tap) || !CGEventTapIsEnabled(tap))) {
        [self disconnect];
    }
    if (!tap) {
        CGEventMask keys = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp);
        tap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault,
                               keys, translate, NULL);
        if (tap) {
            CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(NULL, tap, 0);
            CFRunLoopAddSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes);
            CFRelease(source);
        }
    }
    if (!tap) {
        [self.keyboards restore];
        self.status.title = @"Keyboard connection unavailable — retrying";
        return;
    }
    self.status.title = [self.keyboards refresh] ? @"Navigation active" : @"Could not configure a keyboard";
}
- (void)applicationWillTerminate:(NSNotification *)notification {
    if (self.bundleWatcher) dispatch_source_cancel(self.bundleWatcher);
    [self disconnect];
}
- (void)dismissAccessibilitySetup:(id)sender {
    [self.accessibilityHelp.window orderOut:nil];
    self.accessibilityHelp = nil;
}
- (void)showAccessibilitySetup:(id)sender {
    if (!self.accessibilityHelp) {
        NSAlert *help = [NSAlert new];
        help.icon = NSApp.applicationIconImage;
        help.messageText = @"Allow ArrowKeys to move the cursor";
        help.informativeText = @"In Accessibility Settings, turn on ArrowKeys. If it is missing, click + and choose ArrowKeys from Applications.\n\n"
                               @"Already on after an update? Select ArrowKeys and click −. Then click +, add ArrowKeys from Applications again and turn it on. If macOS asks, choose Quit & Reopen.";
        NSButton *open = [help addButtonWithTitle:@"Open Accessibility Settings"];
        open.target = self;
        open.action = @selector(access:);
        NSButton *later = [help addButtonWithTitle:@"Later"];
        later.target = self;
        later.action = @selector(dismissAccessibilitySetup:);
        [help layout];
        [help.window center];
        self.accessibilityHelp = help;
    }
    [NSApp activateIgnoringOtherApps:YES];
    [self.accessibilityHelp.window makeKeyAndOrderFront:nil];
}
- (void)access:(id)sender {
    [self dismissAccessibilitySetup:nil];
    if (!AXIsProcessTrusted()) {
        NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
        AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    }
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
}
- (void)toggleLogin:(id)sender {
    SMAppService *service = SMAppService.mainAppService;
    NSError *error = nil;
    if (service.status == SMAppServiceStatusEnabled) [service unregisterAndReturnError:&error];
    else if (service.status == SMAppServiceStatusRequiresApproval) [SMAppService openSystemSettingsLoginItems];
    else [service registerAndReturnError:&error];
    if (error) [NSApp presentError:error];
    else [NSUserDefaults.standardUserDefaults setBool:YES forKey:loginSetupKey];
    [self menuNeedsUpdate:self.item.menu];
}
- (void)menuNeedsUpdate:(NSMenu *)menu {
    SMAppServiceStatus status = SMAppService.mainAppService.status;
    self.login.title = status == SMAppServiceStatusRequiresApproval ? @"Open at Login (Approval Required…)" : @"Open at Login";
    self.login.state = status == SMAppServiceStatusRequiresApproval ? NSControlStateValueMixed :
                       status == SMAppServiceStatusEnabled ? NSControlStateValueOn : NSControlStateValueOff;
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.keyboards = [KeyboardMapping new];
    self.item = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.item.button.image = menuBarIcon();
    self.item.button.imagePosition = NSImageOnly;
    [self.item.button setAccessibilityLabel:@"ArrowKeys"];
    self.item.button.toolTip = @"ArrowKeys";
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"ArrowKeys"];
    menu.delegate = self;
    self.status = [menu addItemWithTitle:@"ArrowKeys" action:nil keyEquivalent:@""];
    self.status.target = self;
    [menu addItemWithTitle:@"Accessibility Settings…" action:@selector(access:) keyEquivalent:@""].target = self;
    self.login = [menu addItemWithTitle:@"Open at Login" action:@selector(toggleLogin:) keyEquivalent:@""];
    self.login.target = self;
    [menu addItemWithTitle:@"Quit ArrowKeys" action:@selector(terminate:) keyEquivalent:@"q"].target = NSApp;
    self.item.menu = menu;
    SMAppService *loginService = SMAppService.mainAppService;
    configureLoginDefault(NSUserDefaults.standardUserDefaults, loginService.status, ^BOOL {
        NSError *error = nil;
        if ([loginService registerAndReturnError:&error] || loginService.status == SMAppServiceStatusRequiresApproval ||
            error.code == kSMErrorLaunchDeniedByUser)
            return YES;
        NSLog(@"Open at Login registration failed: %@", error);
        return NO;
    });
    [self menuNeedsUpdate:menu];
    // A menu-bar process can outlive its on-disk bundle when it is moved or deleted.
    int fd = open(NSBundle.mainBundle.bundlePath.fileSystemRepresentation, O_EVTONLY);
    if (fd >= 0) {
        self.bundleWatcher = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, fd,
            DISPATCH_VNODE_DELETE | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_REVOKE, dispatch_get_main_queue());
        dispatch_source_set_event_handler(self.bundleWatcher, ^{
            SMAppService *login = SMAppService.mainAppService;
            SMAppServiceStatus status = login.status;
            if (status == SMAppServiceStatusEnabled || status == SMAppServiceStatusRequiresApproval) {
                BOOL removed = [login unregisterAndReturnError:NULL];
                if (removed && status == SMAppServiceStatusEnabled)
                    [NSUserDefaults.standardUserDefaults removeObjectForKey:loginSetupKey];
            }
            [NSApp terminate:nil];
        });
        dispatch_source_set_cancel_handler(self.bundleWatcher, ^{ close(fd); });
        dispatch_resume(self.bundleWatcher);
    }
    [self connect];
    [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer){ [self connect]; }];
    NSString *build = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    if (offerAccessibilitySetup(NSUserDefaults.standardUserDefaults, build, AXIsProcessTrusted()))
        [self showAccessibilitySetup:nil];
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
