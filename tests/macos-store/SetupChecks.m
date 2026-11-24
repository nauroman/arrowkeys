#define main productionMain
#import "../../macos/StoreApp.m"
#undef main
#include <assert.h>

// Open the actual settings pane on the disposable runner. Never request keyboard permission.
@interface SetupChecks : StoreApp
@property NSInteger chosenLogin;
@property BOOL permitted, useSystemSettings;
@property NSInteger requests, paneOpens;
@end

@implementation SetupChecks
- (void)setLoginEnabled:(BOOL)enabled {
    self.chosenLogin = enabled;
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:loginChoiceRecorded];
}
- (BOOL)cursorPermissionGranted { return self.permitted; }
- (void)requestSystemCursorAccess { self.requests++; }
- (void)openSystemPrivacyPane {
    self.paneOpens++;
    if (self.useSystemSettings) [super openSystemPrivacyPane];
}
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    [self suspend:nil]; // Keep real keyboard assignments untouched even in simulated granted cases.
    [super applicationDidFinishLaunching:note];
    if (![NSProcessInfo.processInfo.arguments containsObject:@"--check-first-launch"]) return;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    for (NSNumber *first in @[@YES, @NO]) {
        [self dismissSetup:nil];
        [defaults setBool:!first.boolValue forKey:@"CompletedSetup"];
        [defaults removeObjectForKey:loginChoiceRecorded];
        [self setup:nil];
        NSAlert *alert = [self valueForKey:@"setupAlert"];
        assert([alert.buttons.firstObject.title isEqual:(first.boolValue ? @"Enable Navigation" : @"Save")]);
        NSButton *checkbox = (NSButton *)alert.accessoryView;
        assert([checkbox isKindOfClass:NSButton.class] && [checkbox.title isEqual:@"Open at Login"]);
        assert(checkbox.state == NSControlStateValueOn);
        if (!first.boolValue) [checkbox performClick:nil];
        self.chosenLogin = -1;
        NSInteger initial = self.paneOpens;
        [alert.buttons.firstObject performClick:nil];
        assert(self.chosenLogin == first.integerValue);
        assert(self.paneOpens == initial + 1 && self.requests == self.paneOpens);
        NSAlert *guide = [self valueForKey:@"setupAlert"];
        assert(guide.window.visible && [guide.messageText isEqual:@"Allow ArrowKeys Store to move the cursor"]);
        assert([[guide.buttons valueForKey:@"title"] isEqual:(@[@"Open Permission Settings", @"Restart ArrowKeys", @"Later"])]);
        assert([[(NSButton *)guide.accessoryView title] isEqual:@"Show This App in Finder"]);
        [guide.buttons.lastObject performClick:nil];
        [self resumeSetupIfNeeded];
        assert(![self valueForKey:@"setupAlert"] && self.paneOpens == initial + 1);
    }
    assert(!loginRegistered(SMAppServiceStatusNotRegistered) && !loginRegistered(SMAppServiceStatusNotFound));
    assert(loginRegistered(SMAppServiceStatusEnabled) && loginRegistered(SMAppServiceStatusRequiresApproval));
    NSInteger initial = self.paneOpens;
    [defaults removeObjectForKey:deferredPermissionBuild];
    [self resumeSetupIfNeeded]; // The same build already opened Settings.
    assert([self valueForKey:@"setupAlert"] && self.paneOpens == initial);
    self.permitted = YES;
    [self refresh];
    assert(![self valueForKey:@"setupAlert"]);
    [defaults removeObjectForKey:@"CompletedSetup"];
    [self setup:nil];
    NSAlert *alert = [self valueForKey:@"setupAlert"];
    [alert.buttons.firstObject performClick:nil];
    assert(![self valueForKey:@"setupAlert"] && self.paneOpens == initial);
    [self resumeSetupIfNeeded];
    assert(![self valueForKey:@"setupAlert"] && self.paneOpens == initial);

    // Reproduce an upgrade with the old process still reporting denied after a grant.
    self.permitted = NO;
    self.useSystemSettings = YES;
    [defaults setObject:@"earlier-build" forKey:openedPermissionBuild];
    [self resumeSetupIfNeeded];
    assert(self.paneOpens == initial + 1);
    [NSTimer scheduledTimerWithTimeInterval:0.2 repeats:YES block:^(NSTimer *timer) {
        if (![NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier isEqual:@"com.apple.systempreferences"]) return;
        [timer invalidate];
        printf("Setup, opt-out, granted and deferred cases passed. System Settings is in front. Restarting PID %d\n", getpid());
        fflush(stdout);
    }];
}
@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        __attribute__((objc_precise_lifetime)) SetupChecks *checks = [SetupChecks new];
        app.delegate = checks;
        [app run];
    }
    return 0;
}
