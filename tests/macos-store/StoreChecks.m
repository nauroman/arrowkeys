// The receiver checks the production Carbon registrations without posting events to another app.
#import "../../macos/StoreHotKeys.h"
#import "../../macos/KeyboardMapping.h"
#import "../../macos/BundleRemoval.h"
#import <Security/Security.h>
#include <assert.h>

@interface Receiver : StoreHotKeys
@property unsigned down, up;
@end
@implementation Receiver
- (void)shortcut:(UInt32)key pressed:(BOOL)pressed {
    if (pressed) self.down |= 1U << (key - 1);
    else self.up |= 1U << (key - 1);
}
@end

static int receiveShortcuts(void) {
    SecTaskRef task = SecTaskCreateFromSelf(NULL);
    NSNumber *sandbox = CFBridgingRelease(SecTaskCopyValueForEntitlement(task, CFSTR("com.apple.security.app-sandbox"), NULL));
    CFRelease(task);
    assert(sandbox.boolValue);
    Receiver *receiver = [Receiver new];
    EventHotKeyRef last = NULL;
    EventHotKeyID collision = {'TstK', 1};
    assert(RegisterEventHotKey(bindings[bindingCount-1].input, optionKey, collision,
        GetApplicationEventTarget(), kEventHotKeyExclusive, &last) == noErr);
    assert([receiver registerShortcuts] != noErr);
    UnregisterEventHotKey(last);
    assert([receiver registerShortcuts] == noErr); // Includes all seven before the collision.
    puts("READY: sandbox, collision rollback and eight exclusive registrations verified");
    fflush(stdout);
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:40];
    while ((receiver.down != 255 || receiver.up != 255) && deadline.timeIntervalSinceNow > 0) {
        NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny untilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]
                                               inMode:NSDefaultRunLoopMode dequeue:YES];
        if (event) [NSApp sendEvent:event];
    }
    [receiver unregisterShortcuts];
    printf("Registered Option shortcuts: pressed=%#x released=%#x\n", receiver.down, receiver.up);
    return receiver.down == 255 && receiver.up == 255 ? 0 : 1;
}

// Only the disposable runner's test driver synthesizes Option and the eight letters.
static int driveReceiver(NSString *bundleID) {
    NSDictionary *env = NSProcessInfo.processInfo.environment;
    NSArray *fixtureApps = @[@"com.apple.TextEdit", @"com.apple.Safari", @"com.apple.dt.Xcode"];
    if (![env[@"RUNNER_ENVIRONMENT"] isEqual:@"github-hosted"] || ![env[@"GITHUB_ACTIONS"] isEqual:@"true"] ||
        ![fixtureApps containsObject:bundleID] || !CGPreflightPostEventAccess()) return 77;
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:25];
    while (![NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier isEqual:bundleID] && deadline.timeIntervalSinceNow > 0)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]];
    for (NSUInteger i = 0; i < bindingCount; ++i) {
        const CGKeyCode keys[] = {kVK_Option, bindings[i].input, bindings[i].input, kVK_Option};
        for (int j = 0; j < 4; ++j) {
            if (![NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier isEqual:bundleID]) {
                fprintf(stderr, "Test fixture application lost focus: %s\n", bundleID.UTF8String);
                return 2;
            }
            CGEventRef event = CGEventCreateKeyboardEvent(NULL, keys[j], j < 2);
            if (j == 0 || j == 3) CGEventSetType(event, kCGEventFlagsChanged);
            CGEventSetFlags(event, j == 3 ? 0 : kCGEventFlagMaskAlternate);
            CGEventPost(kCGHIDEventTap, event);
            CFRelease(event);
            usleep(35000);
        }
    }
    return 0;
}

static void testRecovery(void) {
    NSString *suite = [@"ArrowKeysStoreTest." stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    KeyboardMapping *first = [[KeyboardMapping alloc] initWithRecoveryDefaults:defaults];
    NSArray *other = @[@{sourceKey:@4, destinationKey:@5}];
    __block NSArray *actual = other;
    BOOL (^write)(NSArray *) = ^BOOL(NSArray *v) { actual = [v copy]; return YES; };
    assert([first updateKeyboard:@17 current:actual restoring:NO write:write]);
    assert(![actual isEqual:other]);
    KeyboardMapping *reopened = [[KeyboardMapping alloc] initWithRecoveryDefaults:defaults];
    assert([reopened updateKeyboard:@17 current:actual restoring:YES write:write]);
    assert([actual isEqual:other]);
    assert(![defaults objectForKey:@"OwnedCapsLockMappings"]);
    [defaults removePersistentDomainForName:suite];
    puts("Recovered the previous Caps Lock assignment after relaunch.");
}

static NSDictionary *readKeyboardState(void) {
    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreateSimpleClient(NULL);
    if (!client) return nil;
    NSArray *services = CFBridgingRelease(IOHIDEventSystemClientCopyServices(client));
    NSMutableDictionary *state = [NSMutableDictionary new];
    for (id item in services) {
        IOHIDServiceClientRef device = (__bridge IOHIDServiceClientRef)item;
        if (!IOHIDServiceClientConformsTo(device, kHIDPage_GenericDesktop, kHIDUsage_GD_Keyboard)) continue;
        NSNumber *key = (__bridge NSNumber *)IOHIDServiceClientGetRegistryID(device);
        if (!key) continue;
        state[key.stringValue] = CFBridgingRelease(IOHIDServiceClientCopyProperty(device, CFSTR("UserKeyMapping"))) ?: @[];
    }
    CFRelease(client);
    return state;
}

static int keyboardState(void) {
    NSDictionary *state = readKeyboardState();
    if (!state.count) return 2;
    NSData *json = [NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingSortedKeys error:NULL];
    if (!json) return 2;
    fwrite(json.bytes, 1, json.length, stdout);
    putchar('\n');
    return 0;
}

// Only invoked by the hosted workflow on its disposable login session. No keyboard events are posted.
static int checkLiveRemoval(void) {
    if (![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.nauroman.ArrowKeys.Store.RegistrationCheck"]) return 2;
    NSDictionary *before = readKeyboardState();
    if (!before.count) { puts("NO_KEYBOARD: no keyboard service visible in this sandbox."); return 77; }
    KeyboardMapping *mapping = [KeyboardMapping new];
    __block BOOL removed = NO, restored = NO;
    dispatch_source_t watch = watchBundleRemoval(^{
        restored = [mapping restore];
        removed = YES;
    });
    if (!watch) return 2;
    if (![mapping refresh]) {
        BOOL clean = [mapping restore] && [before isEqual:readKeyboardState()];
        printf("MAPPING_UNAVAILABLE: macOS declined the device assignment. Baseline restored: %s\n", clean ? "yes" : "no");
        return clean ? 77 : 1;
    }
    NSDictionary *applied = readKeyboardState();
    if (!applied.count || [before isEqual:applied]) { [mapping restore]; return 2; }
    puts("APPLIED: sandbox keyboard mapping read back; waiting for bundle removal");
    fflush(stdout);
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:25];
    while (!removed && deadline.timeIntervalSinceNow > 0)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    if (!removed) [mapping restore];
    dispatch_source_cancel(watch);
    BOOL ok = removed && restored && [before isEqual:readKeyboardState()];
    puts(ok ? "RESTORED: live keyboard assignments match after removal" : "FAIL: removal or keyboard restoration");
    return ok ? 0 : 1;
}

static NSString *readTestFile(const char *path) {
    return [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:path] encoding:NSUTF8StringEncoding error:NULL];
}

static int checkActiveMapping(const char *baseline, const char *active) {
    NSData *beforeData = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:baseline]];
    NSData *afterData = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:active]];
    if (!beforeData || !afterData) return 2;
    NSDictionary *before = [NSJSONSerialization JSONObjectWithData:beforeData options:0 error:NULL];
    NSDictionary *after = [NSJSONSerialization JSONObjectWithData:afterData options:0 error:NULL];
    if (!before.count || ![[NSSet setWithArray:before.allKeys] isEqual:[NSSet setWithArray:after.allKeys]]) return 2;
    NSDictionary *expected = @{sourceKey:@(caps), destinationKey:@(option)};
    for (NSString *device in before) {
        NSMutableArray *unrelated = [NSMutableArray new];
        for (NSDictionary *entry in before[device])
            if (![entry[sourceKey] isEqual:@(caps)]) [unrelated addObject:entry];
        NSMutableArray *actual = [after[device] mutableCopy];
        if (actual.count != unrelated.count + 1 || ![actual containsObject:expected]) return 1;
        [actual removeObject:expected];
        if (![actual isEqual:unrelated]) return 1;
    }
    if ([before isEqual:after]) {
        puts("Caps Lock was already mapped before this test; there is no new assignment to restore.");
        return 1;
    }
    puts("The temporary Caps Lock assignment is visible on each test keyboard.");
    return 0;
}

static int compareEditors(NSString *reference, NSString *observed, NSString *fixture) {
    if (!reference || !observed || !fixture) return 2;
    NSMutableString *expected = [reference mutableCopy], *actual = [observed mutableCopy];
    const char labels[] = "JKLIUOH;";
    NSUInteger positions[9], measured[9];
    // Peel off later markers to reconstruct the caret immediately after each keystroke.
    for (int i = 8; i >= 0; --i) {
        NSString *digit = [NSString stringWithFormat:@"%d", i];
        if ([expected componentsSeparatedByString:digit].count != 2 ||
            [actual componentsSeparatedByString:digit].count != 2) {
            printf("Missing or duplicate marker %d. Repeat these two documents.\n", i);
            return 1;
        }
        positions[i] = [expected rangeOfString:digit].location;
        measured[i] = [actual rangeOfString:digit].location;
        [expected deleteCharactersInRange:NSMakeRange(positions[i], 1)];
        [actual deleteCharactersInRange:NSMakeRange(measured[i], 1)];
    }
    BOOL ok = [expected isEqual:fixture] && [actual isEqual:fixture] && positions[0] == 29 && measured[0] == 29;
    if (!ok) puts("Fixture text or starting caret changed.");
    for (int i = 1; i <= 8; ++i) {
        BOOL pass = positions[i] != positions[i - 1] + 1 && measured[i] == positions[i];
        printf("Caps + %c: reference=%lu observed=%lu %s\n", labels[i-1], (unsigned long)positions[i],
               (unsigned long)measured[i], pass ? "PASS" : "FAIL");
        if (!pass) ok = NO;
    }
    return ok ? 0 : 1;
}

static int checkSafari(const char *path, const char *runID) {
    NSData *data = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:path]];
    if (!data) return 2;
    NSDictionary *report = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if (![report[@"run"] isEqual:[NSString stringWithUTF8String:runID]]) return 2;
    NSArray *observations = report[@"observations"];
    NSArray *labels = @[@"J",@"K",@"L",@"I",@"U",@"O",@"H",@";"];
    if (observations.count != labels.count) return 2;
    BOOL ok = YES;
    for (NSUInteger i = 0; i < labels.count; ++i) {
        NSDictionary *item = observations[i];
        BOOL pass = [item[@"key"] isEqual:labels[i]] && [item[@"pass"] boolValue] &&
                    [item[@"reference"] isEqual:item[@"position"]] && [item[@"reference"] integerValue] != 35;
        printf("Caps + %s: reference=%ld observed=%ld %s\n", [labels[i] UTF8String],
               (long)[item[@"reference"] integerValue], (long)[item[@"position"] integerValue], pass ? "PASS" : "FAIL");
        if (!pass) ok = NO;
    }
    return ok ? 0 : 1;
}

int main(int argc, const char **argv) {
    @autoreleasepool {
        if (argc == 3 && strcmp(argv[1], "--drive") == 0) {
            [NSApplication sharedApplication];
            [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
            [NSApp finishLaunching];
            return driveReceiver([NSString stringWithUTF8String:argv[2]]);
        }
        if (argc == 5 && strcmp(argv[1], "--compare-editors") == 0)
            return compareEditors(readTestFile(argv[2]), readTestFile(argv[3]), readTestFile(argv[4]));
        if (argc == 4 && strcmp(argv[1], "--check-safari") == 0) return checkSafari(argv[2], argv[3]);
        if (argc == 4 && strcmp(argv[1], "--check-active") == 0) return checkActiveMapping(argv[2], argv[3]);
        if (argc != 2) return 2;
        if (strcmp(argv[1], "--store-running") == 0)
            return [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.nauroman.ArrowKeys.Store"].count ? 0 : 1;
        if (strcmp(argv[1], "--github-running") == 0)
            return [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.nauroman.ArrowKeys"].count ? 0 : 1;
        if (strcmp(argv[1], "--keyboard-state") == 0) return keyboardState();
        if (strcmp(argv[1], "--recovery") == 0) { testRecovery(); return 0; }
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
        [NSApp finishLaunching];
        if (strcmp(argv[1], "--live-removal") == 0) return checkLiveRemoval();
        if (strcmp(argv[1], "--receive") == 0) return receiveShortcuts();
        return 2;
    }
}
