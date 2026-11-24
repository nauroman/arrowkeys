#define main productionMain
#import "../../macos/StoreApp.m"
#undef main
#include <assert.h>

// Exercise the production alert and restart without requesting any system keyboard permission.
@interface SetupChecks : StoreApp
@property NSInteger chosenLogin;
@end

@implementation SetupChecks
- (void)setLoginEnabled:(BOOL)enabled { self.chosenLogin = enabled; }
- (void)requestCursorPermission:(BOOL)openSettings {}
- (void)refresh {}
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    [super applicationDidFinishLaunching:note];
    if (![NSProcessInfo.processInfo.arguments containsObject:@"--check-first-launch"]) return;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    for (NSNumber *enabled in @[@YES, @NO]) {
        [self dismissSetup:nil];
        [defaults removeObjectForKey:@"CompletedSetup"];
        [defaults removeObjectForKey:loginChoiceRecorded];
        [self setup:nil];
        NSAlert *alert = [self valueForKey:@"setupAlert"];
        NSButton *checkbox = (NSButton *)alert.accessoryView;
        assert([checkbox isKindOfClass:NSButton.class] && [checkbox.title isEqual:@"Open at Login"]);
        assert(checkbox.state == NSControlStateValueOn);
        if (!enabled.boolValue) [checkbox performClick:nil];
        self.chosenLogin = -1;
        [alert.buttons.firstObject performClick:nil];
        assert(self.chosenLogin == enabled.integerValue);
    }
    assert(!loginRegistered(SMAppServiceStatusNotRegistered) && !loginRegistered(SMAppServiceStatusNotFound));
    assert(loginRegistered(SMAppServiceStatusEnabled) && loginRegistered(SMAppServiceStatusRequiresApproval));
    printf("Setup checkbox default and opt-out passed. Restarting PID %d\n", getpid());
    fflush(stdout);
    [self restartForPermission:nil];
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
