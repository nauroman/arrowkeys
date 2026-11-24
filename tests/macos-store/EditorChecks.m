// Runs only on the disposable hosted Mac, in the foreground fixture selected by the test.
#import "../../macos/StoreHotKeys.h"

static void pump(NSTimeInterval seconds) {
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (until.timeIntervalSinceNow > 0) {
        NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny untilDate:until
                                               inMode:NSDefaultRunLoopMode dequeue:YES];
        if (event) [NSApp sendEvent:event];
    }
}

static void keyEvent(CGKeyCode code, BOOL down, CGEventFlags flags, BOOL modifier) {
    CGEventRef event = CGEventCreateKeyboardEvent(NULL, code, down);
    if (modifier) CGEventSetType(event, kCGEventFlagsChanged);
    CGEventSetFlags(event, flags);
    CGEventPost(kCGHIDEventTap, event);
    CFRelease(event);
    pump(0.04);
}

static void press(NSString *app, CGKeyCode code, CGEventFlags flags) {
    if (![NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier isEqual:app]) {
        fprintf(stderr, "Fixture lost focus: %s\n", app.UTF8String);
        exit(2);
    }
    CGKeyCode modifier = flags == kCGEventFlagMaskCommand ? kVK_Command : kVK_Option;
    if (flags) keyEvent(modifier, YES, flags, YES);
    CGEventFlags arrowFlags = (code >= kVK_LeftArrow && code <= kVK_UpArrow) ?
        kCGEventFlagMaskNumericPad | kCGEventFlagMaskSecondaryFn : 0;
    keyEvent(code, YES, flags | arrowFlags, NO);
    keyEvent(code, NO, flags | arrowFlags, NO);
    if (flags) keyEvent(modifier, NO, 0, YES);
    pump(0.04);
}

static NSString *copyFixture(NSString *app) {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    NSInteger initial = [pasteboard clearContents];
    press(app, kVK_ANSI_A, kCGEventFlagMaskCommand);
    press(app, kVK_ANSI_C, kCGEventFlagMaskCommand);
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3];
    while (pasteboard.changeCount == initial && deadline.timeIntervalSinceNow > 0) pump(0.05);
    if (pasteboard.changeCount == initial) return nil;
    NSString *text = [pasteboard stringForType:NSPasteboardTypeString];
    return [[text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"]
                 stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
}

int main(int argc, const char **argv) {
    @autoreleasepool {
        NSDictionary *env = NSProcessInfo.processInfo.environment;
        if (argc != 5 || ![env[@"GITHUB_ACTIONS"] isEqual:@"true"] ||
            ![env[@"RUNNER_ENVIRONMENT"] isEqual:@"github-hosted"] || !CGPreflightPostEventAccess()) return 77;
        NSString *app = @(argv[1]), *mode = @(argv[2]);
        BOOL shortcuts = [mode isEqual:@"shortcuts"];
        if (![@[@"com.apple.TextEdit", @"com.apple.Safari", @"com.apple.ScriptEditor2"] containsObject:app] ||
            (!shortcuts && ![mode isEqual:@"reference"])) return 2;
        NSString *fixture = [NSString stringWithContentsOfFile:@(argv[3]) encoding:NSUTF8StringEncoding error:NULL];
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
        [NSApp finishLaunching];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:20];
        while (![NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier isEqual:app] &&
               deadline.timeIntervalSinceNow > 0) pump(0.1);
        NSString *original = nil;
        BOOL omitsFinalNewline = NO;
        // Launch Services may activate an app before its new document has keyboard focus.
        deadline = [NSDate dateWithTimeIntervalSinceNow:15];
        do {
            pump(0.5);
            original = copyFixture(app);
            omitsFinalNewline = original && [[original stringByAppendingString:@"\n"] isEqual:fixture];
            if ([original isEqual:fixture] || omitsFinalNewline) break;
        } while (deadline.timeIntervalSinceNow > 0);
        if (!fixture || (![original isEqual:fixture] && !omitsFinalNewline)) {
            fprintf(stderr, "%s: the focused field did not contain the pristine fixture (%lu of %lu characters).\n",
                    app.UTF8String, (unsigned long)original.length, (unsigned long)fixture.length);
            return 2;
        }
        StoreHotKeys *navigation = [StoreHotKeys new];
        if (shortcuts && [navigation registerShortcuts] != noErr) return 1;
        press(app, kVK_UpArrow, kCGEventFlagMaskCommand);
        press(app, kVK_DownArrow, 0);
        for (int i = 0; i < 3; ++i) press(app, kVK_RightArrow, 0);
        press(app, kVK_ANSI_0, 0);
        const struct { CGKeyCode input, arrow, marker; CGEventFlags flags; } cases[] = {
            {kVK_ANSI_J, kVK_LeftArrow, kVK_ANSI_1, 0}, {kVK_ANSI_K, kVK_DownArrow, kVK_ANSI_2, 0},
            {kVK_ANSI_L, kVK_RightArrow, kVK_ANSI_3, 0}, {kVK_ANSI_I, kVK_UpArrow, kVK_ANSI_4, 0},
            {kVK_ANSI_U, kVK_LeftArrow, kVK_ANSI_5, kCGEventFlagMaskCommand},
            {kVK_ANSI_O, kVK_RightArrow, kVK_ANSI_6, kCGEventFlagMaskCommand},
            {kVK_ANSI_H, kVK_LeftArrow, kVK_ANSI_7, kCGEventFlagMaskAlternate},
            {kVK_ANSI_Semicolon, kVK_RightArrow, kVK_ANSI_8, kCGEventFlagMaskAlternate}
        };
        for (NSUInteger i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
            press(app, shortcuts ? cases[i].input : cases[i].arrow,
                  shortcuts ? kCGEventFlagMaskAlternate : cases[i].flags);
            press(app, cases[i].marker, 0);
        }
        [navigation unregisterShortcuts];
        NSString *result = copyFixture(app);
        if (omitsFinalNewline) result = [result stringByAppendingString:@"\n"];
        return [result writeToFile:@(argv[4]) atomically:YES encoding:NSUTF8StringEncoding error:NULL] ? 0 : 1;
    }
}
