#import "StoreHotKeys.h"
#import "KeyboardMapping.h"
#import <ServiceManagement/ServiceManagement.h>
#include <fcntl.h>
#include <signal.h>

@interface StoreApp : NSObject <NSApplicationDelegate, NSMenuDelegate>
@end

@implementation StoreApp {
    KeyboardMapping *_keyboards;
    StoreHotKeys *_hotKeys;
    NSStatusItem *_item;
    NSMenuItem *_status, *_login;
    NSAlert *_setupAlert;
    dispatch_source_t _bundleWatcher, _termination;
    BOOL _restorePending, _suspended, _ending;
}

- (void)stopNavigation {
    [_hotKeys unregisterShortcuts];
    _restorePending = ![_keyboards restore];
}

- (void)refresh {
    if (_ending) return;
    NSString *unavailable = nil;
    if (!_bundleWatcher) unavailable = @"Could not watch the installed application";
    else if (_suspended) unavailable = @"Navigation paused";
    else if (![NSUserDefaults.standardUserDefaults boolForKey:@"CompletedSetup"])
        unavailable = @"Set Up ArrowKeys…";
    else if ([NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.nauroman.ArrowKeys"].count)
        unavailable = @"Quit the GitHub edition to use ArrowKeys";
    else if (!CGPreflightPostEventAccess()) unavailable = @"Allow Cursor Control…";
    else if (IsSecureEventInputEnabled()) unavailable = @"Paused during secure keyboard entry";
    else if (_restorePending && ![_keyboards restore]) unavailable = @"Restoring the previous keyboard setting…";
    else {
        _restorePending = NO;
        OSStatus result = [_hotKeys registerShortcuts];
        if (result == eventHotKeyExistsErr) unavailable = @"A navigation shortcut is in use by another app";
        else if (result != noErr) unavailable = @"macOS could not register the navigation shortcuts";
        else if (![_keyboards refresh]) unavailable = _keyboards.connectedKeyboards ?
            @"macOS could not apply the Caps Lock assignment" : @"Waiting for a keyboard";
    }
    if (unavailable) [self stopNavigation];
    _status.title = unavailable ?: @"Navigation active";
}

- (void)setup:(id)sender {
    if (_setupAlert) {
        [NSApp activateIgnoringOtherApps:YES];
        [_setupAlert.window makeKeyAndOrderFront:nil];
        return;
    }
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL first = ![defaults boolForKey:@"CompletedSetup"];
    NSAlert *alert = [NSAlert new];
    alert.icon = NSApp.applicationIconImage;
    alert.messageText = first ? @"Use Caps Lock for navigation" : @"Allow ArrowKeys to move the cursor";
    alert.informativeText = first ?
        @"Hold Caps Lock or Option and press J, K, L or I for the arrows, U or O for line ends, and H or semicolon for words. macOS will ask to allow keyboard events in other apps. Quitting restores your keyboard." :
        @"Allow ArrowKeys Store in System Settings → Privacy & Security. On macOS 15 and 26 this control is under Accessibility. If an old copy is already enabled, remove it with − and add this copy from Applications with +.";
    NSButton *enable = [alert addButtonWithTitle:first ? @"Enable Navigation" : @"Open Permission Settings"];
    enable.target = self;
    enable.action = @selector(enable:);
    NSButton *later = [alert addButtonWithTitle:@"Later"];
    later.target = self;
    later.action = @selector(dismissSetup:);
    if (first) {
        alert.showsSuppressionButton = YES;
        alert.suppressionButton.title = @"Open at Login";
        alert.suppressionButton.state = NSControlStateValueOn;
    }
    [alert layout];
    [alert.window center];
    _setupAlert = alert;
    [NSApp activateIgnoringOtherApps:YES];
    [alert.window makeKeyAndOrderFront:nil];
}

- (void)dismissSetup:(id)sender {
    [_setupAlert.window orderOut:nil];
    _setupAlert = nil;
}

- (void)enable:(id)sender {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL first = ![defaults boolForKey:@"CompletedSetup"];
    BOOL openAtLogin = _setupAlert.suppressionButton.state == NSControlStateValueOn;
    [self dismissSetup:nil];
    if (first) {
        [defaults setBool:YES forKey:@"CompletedSetup"];
        SMAppService *login = SMAppService.mainAppService;
        if (openAtLogin && login.status == SMAppServiceStatusNotRegistered)
            [self toggleLogin:nil];
        else if (!openAtLogin && (login.status == SMAppServiceStatusEnabled || login.status == SMAppServiceStatusRequiresApproval)) {
            NSError *error = nil;
            if (![login unregisterAndReturnError:&error] && error) [NSApp presentError:error];
        }
    }
    if (!CGPreflightPostEventAccess()) {
        CGRequestPostEventAccess();
        if (!first && !CGPreflightPostEventAccess())
            [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
    }
    [self refresh];
}

- (void)toggleLogin:(id)sender {
    SMAppService *service = SMAppService.mainAppService;
    NSError *error = nil;
    switch (service.status) {
        case SMAppServiceStatusEnabled: [service unregisterAndReturnError:&error]; break;
        case SMAppServiceStatusRequiresApproval: [SMAppService openSystemSettingsLoginItems]; break;
        default: [service registerAndReturnError:&error]; break;
    }
    if (error) [NSApp presentError:error];
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    [self refresh];
    SMAppServiceStatus status = SMAppService.mainAppService.status;
    _login.title = status == SMAppServiceStatusRequiresApproval ? @"Open at Login (Approval Required…)" : @"Open at Login";
    _login.state = status == SMAppServiceStatusEnabled ? NSControlStateValueOn :
                   status == SMAppServiceStatusRequiresApproval ? NSControlStateValueMixed : NSControlStateValueOff;
}

- (void)suspend:(NSNotification *)note { _suspended = YES; [self refresh]; }
- (void)resume:(NSNotification *)note { _suspended = NO; [self refresh]; }
- (void)focusChanged:(NSNotification *)note { [_hotKeys cancelRepeat]; }

- (void)watchBundle {
    int fd = open(NSBundle.mainBundle.bundlePath.fileSystemRepresentation, O_EVTONLY);
    if (fd < 0) return;
    _bundleWatcher = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, fd,
        DISPATCH_VNODE_DELETE | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_REVOKE, dispatch_get_main_queue());
    if (!_bundleWatcher) { close(fd); return; }
    dispatch_source_set_event_handler(_bundleWatcher, ^{
        self->_ending = YES;
        [self stopNavigation];
        SMAppService *login = SMAppService.mainAppService;
        if (login.status == SMAppServiceStatusEnabled || login.status == SMAppServiceStatusRequiresApproval)
            [login unregisterAndReturnError:NULL];
        [NSApp terminate:nil];
    });
    dispatch_source_set_cancel_handler(_bundleWatcher, ^{ close(fd); });
    dispatch_resume(_bundleWatcher);
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    _keyboards = [[KeyboardMapping alloc] initWithRecoveryDefaults:defaults];
    _restorePending = ![_keyboards restore];
    _hotKeys = [StoreHotKeys new];
    _item = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    _item.button.image = menuBarIcon();
    _item.button.imagePosition = NSImageOnly;
    _item.button.toolTip = @"ArrowKeys Store";
    [_item.button setAccessibilityLabel:@"ArrowKeys Store"];
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"ArrowKeys"];
    menu.delegate = self;
    _status = [menu addItemWithTitle:@"ArrowKeys" action:nil keyEquivalent:@""];
    [menu addItemWithTitle:@"Set Up Cursor Control…" action:@selector(setup:) keyEquivalent:@""].target = self;
    _login = [menu addItemWithTitle:@"Open at Login" action:@selector(toggleLogin:) keyEquivalent:@""];
    _login.target = self;
    [menu addItemWithTitle:@"Quit ArrowKeys" action:@selector(terminate:) keyEquivalent:@"q"].target = NSApp;
    _item.menu = menu;
    [self watchBundle];
    _termination = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, dispatch_get_main_queue());
    signal(SIGTERM, SIG_IGN);
    dispatch_source_set_event_handler(_termination, ^{ [NSApp terminate:nil]; });
    dispatch_resume(_termination);
    NSNotificationCenter *workspace = NSWorkspace.sharedWorkspace.notificationCenter;
    [workspace addObserver:self selector:@selector(focusChanged:) name:NSWorkspaceDidActivateApplicationNotification object:nil];
    [workspace addObserver:self selector:@selector(suspend:) name:NSWorkspaceSessionDidResignActiveNotification object:nil];
    [workspace addObserver:self selector:@selector(resume:) name:NSWorkspaceSessionDidBecomeActiveNotification object:nil];
    [workspace addObserver:self selector:@selector(suspend:) name:NSWorkspaceWillSleepNotification object:nil];
    [workspace addObserver:self selector:@selector(resume:) name:NSWorkspaceDidWakeNotification object:nil];
    [self refresh];
    [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer){ [self refresh]; }];
    if (![defaults boolForKey:@"CompletedSetup"]) [self setup:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    _ending = YES;
    [self stopNavigation];
    if (_bundleWatcher) dispatch_source_cancel(_bundleWatcher);
    if (_termination) dispatch_source_cancel(_termination);
}
@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        __attribute__((objc_precise_lifetime)) StoreApp *controller = [StoreApp new];
        app.delegate = controller;
        [app run];
    }
    return 0;
}
