#import "StoreHotKeys.h"
#import "KeyboardMapping.h"
#import "BundleRemoval.h"
#import <ServiceManagement/ServiceManagement.h>
#include <signal.h>

static NSString *const loginChoiceRecorded = @"StoreLoginChoiceRecorded";

static BOOL loginRegistered(SMAppServiceStatus status) {
    return status == SMAppServiceStatusEnabled || status == SMAppServiceStatusRequiresApproval;
}

static NSButton *newLoginCheckbox(void) {
    NSButton *button = [NSButton checkboxWithTitle:@"Open at Login" target:nil action:NULL];
    button.state = NSControlStateValueOn;
    [button sizeToFit];
    return button;
}

@interface StoreApp : NSObject <NSApplicationDelegate, NSMenuDelegate>
@end

@implementation StoreApp {
    KeyboardMapping *_keyboards;
    StoreHotKeys *_hotKeys;
    NSStatusItem *_item;
    NSMenuItem *_status, *_login;
    NSAlert *_setupAlert;
    NSButton *_loginChoice;
    NSFileHandle *_relaunchWriter;
    dispatch_source_t _bundleWatcher, _termination;
    BOOL _restorePending, _suspended, _ending, _waitingForEditor;
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
    _status.action = ([unavailable isEqual:@"Allow Cursor Control…"] || [unavailable isEqual:@"Set Up ArrowKeys…"]) ?
        @selector(setup:) : NULL;
    if (!unavailable) _waitingForEditor = NO;
}

- (void)setup:(id)sender {
    if (_setupAlert) {
        [NSApp activateIgnoringOtherApps:YES];
        [_setupAlert.window makeKeyAndOrderFront:nil];
        return;
    }
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL first = ![defaults boolForKey:@"CompletedSetup"];
    BOOL chooseLogin = first || ![defaults boolForKey:loginChoiceRecorded];
    NSAlert *alert = [NSAlert new];
    alert.icon = NSApp.applicationIconImage;
    alert.messageText = first ? @"Use Caps Lock for navigation" :
        chooseLogin ? @"Choose when ArrowKeys opens" : @"Allow ArrowKeys to move the cursor";
    alert.informativeText = first ?
        @"Hold Caps Lock or Option and press J, K, L or I for the arrows, U or O for line ends, and H or semicolon for words. Allow keyboard events when macOS asks, then switch back to your editor. ArrowKeys may reopen once to apply your permission." :
        chooseLogin ? @"Open the menu bar app automatically when you sign in to your Mac. You can change this choice in its menu. If this build needs cursor control, macOS will ask when you save." :
        @"In System Settings → Privacy & Security, allow ArrowKeys Store to send keyboard events. Then return to your editor. If you already allowed this copy, choose Restart ArrowKeys.";
    NSButton *enable = [alert addButtonWithTitle:first ? @"Enable Navigation" : chooseLogin ? @"Save" : @"Open Permission Settings"];
    enable.target = self;
    enable.action = @selector(enable:);
    NSButton *later = [alert addButtonWithTitle:@"Later"];
    later.target = self;
    later.action = @selector(dismissSetup:);
    if (chooseLogin) {
        _loginChoice = newLoginCheckbox();
        alert.accessoryView = _loginChoice;
    } else if (!CGPreflightPostEventAccess()) {
        NSButton *restart = [alert addButtonWithTitle:@"Restart ArrowKeys"];
        restart.target = self;
        restart.action = @selector(restartForPermission:);
    }
    [alert layout];
    [alert.window center];
    _setupAlert = alert;
    [NSApp activateIgnoringOtherApps:YES];
    [alert.window makeKeyAndOrderFront:nil];
}

- (void)dismissSetup:(id)sender {
    if (sender && _loginChoice && [NSUserDefaults.standardUserDefaults boolForKey:@"CompletedSetup"])
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:loginChoiceRecorded];
    [_setupAlert.window orderOut:nil];
    _setupAlert = nil;
    _loginChoice = nil;
}

- (void)enable:(id)sender {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL first = ![defaults boolForKey:@"CompletedSetup"];
    BOOL chooseLogin = _loginChoice != nil;
    BOOL openAtLogin = _loginChoice.state == NSControlStateValueOn;
    [self dismissSetup:nil];
    if (first) [defaults setBool:YES forKey:@"CompletedSetup"];
    if (chooseLogin) [self setLoginEnabled:openAtLogin];
    if (!CGPreflightPostEventAccess()) [self requestCursorPermission:!chooseLogin];
    [self refresh];
}

- (void)requestCursorPermission:(BOOL)openSettings {
    _waitingForEditor = YES;
    CGRequestPostEventAccess();
    if (openSettings && !CGPreflightPostEventAccess())
        [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
}

- (void)setLoginEnabled:(BOOL)enabled {
    SMAppService *service = SMAppService.mainAppService;
    NSError *error = nil;
    BOOL ok = YES;
    if (enabled && !loginRegistered(service.status)) ok = [service registerAndReturnError:&error];
    else if (!enabled && loginRegistered(service.status)) ok = [service unregisterAndReturnError:&error];
    NSLog(@"Open at Login requested=%d status=%ld error=%@", enabled, (long)service.status, error);
    if (ok || loginRegistered(service.status) == enabled)
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:loginChoiceRecorded];
    else if (error) [NSApp presentError:error];
}

- (void)toggleLogin:(id)sender {
    SMAppServiceStatus status = SMAppService.mainAppService.status;
    if (status == SMAppServiceStatusRequiresApproval) [SMAppService openSystemSettingsLoginItems];
    else [self setLoginEnabled:status != SMAppServiceStatusEnabled];
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
- (void)restartForPermission:(id)sender {
    if (_ending || _relaunchWriter) return;
    _waitingForEditor = NO;
    NSPipe *pipe = [NSPipe pipe];
    NSTask *helper = [NSTask new];
    helper.executableURL = [NSBundle.mainBundle.bundleURL URLByAppendingPathComponent:@"Contents/Helpers/SetupRelaunch"];
    helper.standardInput = pipe;
    NSError *error = nil;
    if (![helper launchAndReturnError:&error]) { [NSApp presentError:error]; return; }
    _relaunchWriter = pipe.fileHandleForWriting;
    [self dismissSetup:nil];
    [NSApp terminate:nil];
}

- (void)focusChanged:(NSNotification *)note {
    [_hotKeys cancelRepeat];
    NSRunningApplication *next = note.userInfo[NSWorkspaceApplicationKey];
    if (!_waitingForEditor || next.activationPolicy != NSApplicationActivationPolicyRegular ||
        [next.bundleIdentifier isEqual:@"com.apple.systempreferences"]) return;
    _waitingForEditor = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!self->_ending && !CGPreflightPostEventAccess()) [self restartForPermission:nil];
    });
}

- (void)watchBundle {
    _bundleWatcher = watchBundleRemoval(^{
        self->_ending = YES;
        [self->_relaunchWriter closeFile];
        self->_relaunchWriter = nil;
        [self stopNavigation];
        SMAppService *login = SMAppService.mainAppService;
        if (login.status == SMAppServiceStatusEnabled || login.status == SMAppServiceStatusRequiresApproval)
            [login unregisterAndReturnError:NULL];
        [NSApp terminate:nil];
    });
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
    _status.target = self;
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
    if (loginRegistered(SMAppService.mainAppService.status)) [defaults setBool:YES forKey:loginChoiceRecorded];
    if (![defaults boolForKey:@"CompletedSetup"] || ![defaults boolForKey:loginChoiceRecorded]) [self setup:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    _ending = YES;
    [self stopNavigation];
    if (_bundleWatcher) dispatch_source_cancel(_bundleWatcher);
    if (_termination) dispatch_source_cancel(_termination);
    if (_relaunchWriter) {
        [_relaunchWriter writeData:[@"R" dataUsingEncoding:NSASCIIStringEncoding] error:NULL];
        [_relaunchWriter closeFile];
    }
}

- (void)retryRestoreBeforeQuit:(NSUInteger)attempts {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC * 250), dispatch_get_main_queue(), ^{
        if ([self->_keyboards restore] || attempts == 1) [NSApp replyToApplicationShouldTerminate:YES];
        else [self retryRestoreBeforeQuit:attempts - 1];
    });
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    _ending = YES;
    [self stopNavigation];
    if (!_restorePending) return NSTerminateNow;
    [self retryRestoreBeforeQuit:8];
    return NSTerminateLater;
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
