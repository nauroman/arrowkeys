#import "StoreHotKeys.h"
#import "KeyboardMapping.h"
#import "BundleRemoval.h"
#import <ServiceManagement/ServiceManagement.h>
#include <signal.h>

static NSString *const loginChoiceRecorded = @"StoreLoginChoiceRecorded";
static NSString *const deferredPermissionBuild = @"DeferredCursorPermissionForBuild";
static NSString *const openedPermissionBuild = @"OpenedCursorPermissionForBuild";

static NSString *currentBuild(void) {
    return [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
}

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
    NSMenuItem *_status, *_login, *_setupItem;
    NSAlert *_setupAlert;
    NSButton *_loginChoice;
    NSFileHandle *_relaunchWriter;
    dispatch_source_t _bundleWatcher, _termination;
    BOOL _restorePending, _suspended, _ending, _awaitingPermissionReturn, _sawPermissionSettings, _permissionGuide;
}

- (void)stopNavigation {
    [_hotKeys unregisterShortcuts];
    _restorePending = ![_keyboards restore];
}

- (void)refresh {
    if (_ending) return;
    BOOL canPost = [self cursorPermissionGranted];
    if (canPost && _permissionGuide) [self dismissSetup:nil];
    NSString *unavailable = nil;
    if (!_bundleWatcher) unavailable = @"Could not watch the installed application";
    else if (_suspended) unavailable = @"Navigation paused";
    else if (![NSUserDefaults.standardUserDefaults boolForKey:@"CompletedSetup"])
        unavailable = @"Set Up ArrowKeys…";
    else if ([NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.nauroman.ArrowKeys"].count)
        unavailable = @"Quit the GitHub edition to use ArrowKeys";
    else if (!canPost) unavailable = @"Allow Cursor Control…";
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
    NSString *title = unavailable ?: @"Navigation active";
    if (![_status.title isEqual:title]) NSLog(@"Navigation status: %@", title);
    _status.title = title;
    _status.action = ([unavailable isEqual:@"Allow Cursor Control…"] || [unavailable isEqual:@"Set Up ArrowKeys…"]) ?
        @selector(setup:) : NULL;
    _setupItem.hidden = canPost && [NSUserDefaults.standardUserDefaults boolForKey:@"CompletedSetup"] &&
                        [NSUserDefaults.standardUserDefaults boolForKey:loginChoiceRecorded];
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
    if (!chooseLogin) {
        if (![self cursorPermissionGranted]) [self showPermissionGuide:YES];
        return;
    }
    NSAlert *alert = [NSAlert new];
    alert.icon = NSApp.applicationIconImage;
    alert.messageText = first ? @"Use Caps Lock for navigation" : @"Choose when ArrowKeys opens";
    alert.informativeText = first ?
        @"Hold Caps Lock or Option and press J, K, L or I for the arrows, U or O for line ends, and H or semicolon for words. Choose Enable Navigation to set up cursor control in System Settings." :
        @"Open the menu bar app automatically when you sign in to your Mac. You can change this choice in its menu. If cursor control needs permission, System Settings will open when you save.";
    NSButton *enable = [alert addButtonWithTitle:first ? @"Enable Navigation" : @"Save"];
    enable.target = self;
    enable.action = @selector(enable:);
    NSButton *later = [alert addButtonWithTitle:@"Later"];
    later.target = self;
    later.action = @selector(dismissSetup:);
    _loginChoice = newLoginCheckbox();
    alert.accessoryView = _loginChoice;
    [self presentSetup:alert activate:YES];
}

- (void)presentSetup:(NSAlert *)alert activate:(BOOL)activate {
    [alert layout];
    [alert.window center];
    _setupAlert = alert;
    if (activate) {
        [NSApp activateIgnoringOtherApps:YES];
        [alert.window makeKeyAndOrderFront:nil];
    } else {
        [alert.window orderBack:nil];
    }
}

- (void)showPermissionGuide:(BOOL)activate {
    if (_permissionGuide) return;
    NSAlert *alert = [NSAlert new];
    alert.icon = NSApp.applicationIconImage;
    alert.messageText = @"Allow ArrowKeys Store to move the cursor";
    NSOperatingSystemVersion os = NSProcessInfo.processInfo.operatingSystemVersion;
    NSString *instructions;
    if (os.majorVersion < 27)
        instructions = @"In Privacy & Security → Accessibility, turn on ArrowKeys Store. If it is missing, click + and select this app.";
    else if (os.majorVersion == 27 && os.minorVersion < 3)
        instructions = @"In Privacy & Security → Device Control and Data Access, allow ArrowKeys Store. If it is missing, click + and select this app.";
    else
        instructions = @"In Privacy & Security, follow the macOS prompt to allow ArrowKeys Store to send navigation keys to your editor.";
    alert.informativeText = [instructions stringByAppendingString:@"\n\nSwitch back to your editor after allowing access. ArrowKeys will reopen if needed. If you already allowed this copy, choose Restart ArrowKeys."];
    NSButton *settings = [alert addButtonWithTitle:@"Open Permission Settings"];
    settings.target = self;
    settings.action = @selector(openPermissionSettings:);
    NSButton *restart = [alert addButtonWithTitle:@"Restart ArrowKeys"];
    restart.target = self;
    restart.action = @selector(restartForPermission:);
    NSButton *later = [alert addButtonWithTitle:@"Later"];
    later.target = self;
    later.action = @selector(dismissSetup:);
    NSButton *reveal = [NSButton buttonWithTitle:@"Show This App in Finder" target:self action:@selector(revealApp:)];
    [reveal sizeToFit];
    alert.accessoryView = reveal;
    _permissionGuide = YES;
    [self presentSetup:alert activate:activate];
}

- (void)revealApp:(id)sender {
    [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[NSBundle.mainBundle.bundleURL]];
}

- (void)showPrivacyPolicy:(id)sender {
    NSURL *policy = [NSURL URLWithString:@"https://github.com/nauroman/arrowkeys/blob/main/PRIVACY.md"];
    [NSWorkspace.sharedWorkspace openURL:policy];
}

- (void)dismissSetup:(id)sender {
    if (sender && _loginChoice && [NSUserDefaults.standardUserDefaults boolForKey:@"CompletedSetup"])
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:loginChoiceRecorded];
    if (sender && _permissionGuide) {
        [NSUserDefaults.standardUserDefaults setObject:currentBuild() forKey:deferredPermissionBuild];
    }
    _permissionGuide = NO;
    _awaitingPermissionReturn = NO;
    _sawPermissionSettings = NO;
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
    if (![self cursorPermissionGranted]) {
        [self showPermissionGuide:NO];
        [self openPermissionSettings:nil];
    }
    [self refresh];
}

- (BOOL)cursorPermissionGranted { return CGPreflightPostEventAccess(); }

- (void)requestSystemCursorAccess { CGRequestPostEventAccess(); }

- (void)openPermissionSettings:(id)sender {
    if ([self cursorPermissionGranted]) { [self refresh]; return; }
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults removeObjectForKey:deferredPermissionBuild];
    [defaults setObject:currentBuild() forKey:openedPermissionBuild];
    _awaitingPermissionReturn = YES;
    _sawPermissionSettings = NO;
    [self requestSystemCursorAccess];
    if ([self cursorPermissionGranted]) { [self refresh]; return; }
    [self openSystemPrivacyPane];
}

- (void)openSystemPrivacyPane {
    NSWorkspace *workspace = NSWorkspace.sharedWorkspace;
    NSURL *privacy = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"];
    if (![workspace openURL:privacy]) {
        NSURL *settings = [workspace URLForApplicationWithBundleIdentifier:@"com.apple.systempreferences"];
        if (settings) [workspace openApplicationAtURL:settings configuration:NSWorkspaceOpenConfiguration.configuration completionHandler:nil];
    }
    if ([workspace.frontmostApplication.bundleIdentifier isEqual:@"com.apple.systempreferences"])
        _sawPermissionSettings = YES;
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
    if (!_awaitingPermissionReturn || !next) return;
    if ([next.bundleIdentifier isEqual:@"com.apple.systempreferences"]) { _sawPermissionSettings = YES; return; }
    if (!_sawPermissionSettings || [next.bundleIdentifier isEqual:@"com.apple.finder"]) return;
    if (next.activationPolicy != NSApplicationActivationPolicyRegular || next.processIdentifier == getpid()) return;
    _awaitingPermissionReturn = NO;
    _sawPermissionSettings = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!self->_ending && self->_permissionGuide && !self->_sawPermissionSettings && ![self cursorPermissionGranted])
            [self restartForPermission:nil];
    });
}

- (void)resumeSetupIfNeeded {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (![defaults boolForKey:@"CompletedSetup"] || ![defaults boolForKey:loginChoiceRecorded]) {
        [self setup:nil];
        return;
    }
    if ([self cursorPermissionGranted] || [[defaults stringForKey:deferredPermissionBuild] isEqual:currentBuild()]) return;
    [self showPermissionGuide:NO];
    if (![[defaults stringForKey:openedPermissionBuild] isEqual:currentBuild()]) [self openPermissionSettings:nil];
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
    _setupItem = [menu addItemWithTitle:@"Set Up Cursor Control…" action:@selector(setup:) keyEquivalent:@""];
    _setupItem.target = self;
    _login = [menu addItemWithTitle:@"Open at Login" action:@selector(toggleLogin:) keyEquivalent:@""];
    _login.target = self;
    [menu addItemWithTitle:@"Privacy Policy…" action:@selector(showPrivacyPolicy:) keyEquivalent:@""].target = self;
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
    SMAppServiceStatus loginStatus = SMAppService.mainAppService.status;
    NSLog(@"Open at Login status=%ld", (long)loginStatus);
    if (loginRegistered(loginStatus)) [defaults setBool:YES forKey:loginChoiceRecorded];
    [self resumeSetupIfNeeded];
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
