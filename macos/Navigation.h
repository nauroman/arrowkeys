#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

typedef struct { CGKeyCode input, arrow; CGEventFlags modifier; } Binding;
static const Binding bindings[] = {
    {kVK_ANSI_J, kVK_LeftArrow, 0}, {kVK_ANSI_K, kVK_DownArrow, 0},
    {kVK_ANSI_L, kVK_RightArrow, 0}, {kVK_ANSI_I, kVK_UpArrow, 0},
    {kVK_ANSI_U, kVK_LeftArrow, kCGEventFlagMaskCommand},
    {kVK_ANSI_O, kVK_RightArrow, kCGEventFlagMaskCommand},
    {kVK_ANSI_H, kVK_LeftArrow, kCGEventFlagMaskAlternate},
    {kVK_ANSI_Semicolon, kVK_RightArrow, kCGEventFlagMaskAlternate}
};
enum { bindingCount = sizeof(bindings) / sizeof(bindings[0]) };

static void setNavigationArrow(CGEventRef event, Binding binding, CGEventFlags locks) {
    const UniChar characters[] = {NSLeftArrowFunctionKey, NSRightArrowFunctionKey,
                                  NSDownArrowFunctionKey, NSUpArrowFunctionKey};
    CGEventSetIntegerValueField(event, kCGKeyboardEventKeycode, binding.arrow);
    CGEventSetFlags(event, (locks & kCGEventFlagMaskAlphaShift) | binding.modifier |
                           kCGEventFlagMaskNumericPad | kCGEventFlagMaskSecondaryFn);
    CGEventKeyboardSetUnicodeString(event, 1, &characters[binding.arrow - kVK_LeftArrow]);
}

static NSImage *menuBarIcon(void) {
    NSImage *icon = [NSImage imageNamed:@"ArrowKeysMenuTemplate.svg"];
    icon.template = YES;
    return icon;
}
