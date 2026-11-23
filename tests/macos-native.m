#define ARROWKEYS_TEST
#import "../macos/ArrowKeys.m"
#import "../macos/KeyboardMapping.h"
#include <assert.h>

static void testKeyboardRestoration(void) {
    KeyboardMapping *mapping = [KeyboardMapping new];
    NSDictionary *capsToControl = @{sourceKey:@(caps), destinationKey:@(0x7000000e0)};
    NSDictionary *capsToOption = @{sourceKey:@(caps), destinationKey:@(option)};
    NSDictionary *other = @{sourceKey:@(0x70000003a), destinationKey:@(0x70000003b)};
    NSDictionary *newOther = @{sourceKey:@(0x70000003a), destinationKey:@(0x70000003c)};
    NSArray *before = @[capsToControl, other];
    __block NSArray *current = before;
    BOOL (^write)(NSArray *) = ^BOOL(NSArray *value) { current = [value copy]; return YES; };
    BOOL (^neverWrite)(NSArray *) = ^BOOL(NSArray *unused) { abort(); };
    assert([mapping updateKeyboard:@1 current:current restoring:NO write:write]);
    assert(([current isEqual:@[other, capsToOption]]));
    assert([mapping updateKeyboard:@1 current:current restoring:YES write:write]);
    assert([current isEqual:before]);
    // Preserve new unrelated assignments made after ArrowKeys launched.
    current = @[newOther, capsToOption];
    assert([mapping updateKeyboard:@1 current:current restoring:YES write:write]);
    assert(([current isEqual:@[newOther, capsToControl]]));
    // Do not overwrite a later user change to Caps on refresh or removal.
    assert([mapping updateKeyboard:@1 current:@[newOther] restoring:NO write:neverWrite]);
    assert([mapping updateKeyboard:@1 current:@[newOther] restoring:YES write:neverWrite]);
    // A second keyboard already configured by its owner is never claimed.
    assert([mapping updateKeyboard:@2 current:@[capsToOption] restoring:NO write:neverWrite]);
    assert([mapping updateKeyboard:@2 current:@[capsToOption] restoring:YES write:neverWrite]);
    // Restore a keyboard that started with no custom assignment.
    assert([mapping updateKeyboard:@3 current:nil restoring:NO write:write]);
    assert([mapping updateKeyboard:@3 current:current restoring:YES write:write]);
    assert(current.count == 0);
    puts("Restored original Caps Lock assignments and preserved independent keyboard edits.");
}

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
        testKeyboardRestoration();
        [NSApplication sharedApplication];
        NSImage *icon = menuBarIcon();
        assert(icon.isTemplate && NSEqualSizes(icon.size, NSMakeSize(26, 18)));
        CGImageRef rendered = [icon CGImageForProposedRect:NULL context:nil hints:nil];
        assert(rendered);
        NSBitmapImageRep *mask = [[NSBitmapImageRep alloc] initWithCGImage:rendered];
        // Both center keys have a transparent arrow surrounded by a solid keycap.
        NSInteger middle = mask.pixelsWide / 2;
        for (NSInteger row = 1; row <= 3; row += 2) {
            NSInteger y = mask.pixelsHigh * row / 4;
            assert([mask colorAtX:middle y:y].alphaComponent < 0.15);
            assert([mask colorAtX:mask.pixelsWide * 9 / 26 y:y].alphaComponent > 0.8);
        }
        puts("Loaded and rendered the branded menu bar template with transparent arrow cutouts.");
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
        // The language switcher's Option+Shift chord consists of flags-changed events.
        const CGKeyCode keys[] = {kVK_Option, kVK_Shift, kVK_Shift, kVK_Option};
        const CGEventFlags flags[] = {kCGEventFlagMaskAlternate, kCGEventFlagMaskAlternate | kCGEventFlagMaskShift,
                                      kCGEventFlagMaskAlternate, 0};
        for (size_t i = 0; i < 4; ++i) {
            CGEventRef event = CGEventCreateKeyboardEvent(NULL, keys[i], true);
            CGEventSetType(event, kCGEventFlagsChanged);
            CGEventSetFlags(event, flags[i]);
            assert(translate(NULL, kCGEventFlagsChanged, event, NULL) == event);
            assert(CGEventGetFlags(event) == flags[i] && CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode) == keys[i]);
            CFRelease(event);
        }
        puts("The complete Option+Shift modifier sequence passed through unchanged.");
    }
}
