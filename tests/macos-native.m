#define ARROWKEYS_TEST
#import "../macos/ArrowKeys.m"
#include <assert.h>

static NSEvent *sendKey(CGKeyCode key, CGEventType type, CGEventFlags flags, bool repeat) {
    CGEventRef event = CGEventCreateKeyboardEvent(NULL, key, type == kCGEventKeyDown);
    CGEventSetFlags(event, flags);
    CGEventSetIntegerValueField(event, kCGKeyboardEventAutorepeat, repeat);
    CGEventRef translated = translate(NULL, type, event, NULL);
    NSEvent *result = [NSEvent eventWithCGEvent:translated];
    CFRelease(event);
    return result;
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSTextView *text = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 640, 240)];
        text.font = [NSFont monospacedSystemFontOfSize:15 weight:NSFontWeightRegular];
        text.string = @"alpha bravo charlie\nsecond line here\nthird line here";
        [text.layoutManager ensureLayoutForTextContainer:text.textContainer];
        const NSUInteger expected[] = {28, 46, 30, 9, 20, 36, 27, 31};
        for (size_t i = 0; i < sizeof(expected)/sizeof(expected[0]); ++i) {
            for (int repeat = 0; repeat < 2; ++repeat) {
                NSEvent *event = sendKey(bindings[i].input, kCGEventKeyDown, kCGEventFlagMaskAlternate, repeat);
                text.selectedRange = NSMakeRange(29, 0);
                [text interpretKeyEvents:@[event]];
                assert(NSEqualRanges(text.selectedRange, NSMakeRange(expected[i], 0)));
            }
            assert(sendKey(bindings[i].input, kCGEventKeyUp, 0, false).keyCode == bindings[i].arrow);
            assert(sendKey(bindings[i].input, kCGEventKeyDown, 0, false).keyCode == bindings[i].input);
            assert(sendKey(bindings[i].input, kCGEventKeyDown, kCGEventFlagMaskAlternate | kCGEventFlagMaskShift, false).keyCode == bindings[i].input);
        }
        puts("Passed all eight AppKit cursor movements, repeats, release order and modifier checks.");
    }
}
