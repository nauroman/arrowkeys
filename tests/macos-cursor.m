#import <Cocoa/Cocoa.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 2;
        [NSApplication sharedApplication];
        NSRect frame = NSMakeRect(0, 0, 640, 240);
        NSWindow *window = [[NSWindow alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskTitled
                                                      backing:NSBackingStoreBuffered defer:NO];
        NSTextView *text = [[NSTextView alloc] initWithFrame:frame];
        window.contentView = text;
        [window makeFirstResponder:text];
        text.font = [NSFont monospacedSystemFontOfSize:15 weight:NSFontWeightRegular];
        text.string = @"alpha bravo charlie\nsecond line here\nthird line here";
        [text.layoutManager ensureLayoutForTextContainer:text.textContainer];
        NSDictionary *positions = @{@"j":@28, @"k":@46, @"l":@30, @"i":@9,
                                    @"u":@20, @"o":@36, @"h":@27, @"semicolon":@31};
        NSDictionary *arrows = @{@"left_arrow":@[@(NSLeftArrowFunctionKey), @123],
                                 @"right_arrow":@[@(NSRightArrowFunctionKey), @124],
                                 @"down_arrow":@[@(NSDownArrowFunctionKey), @125],
                                 @"up_arrow":@[@(NSUpArrowFunctionKey), @126]};
        NSData *data = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]];
        NSArray *records = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (records.count != 48) return 2;
        for (NSDictionary *record in records) {
            NSArray *arrow = arrows[record[@"arrow"]];
            unichar character = [arrow[0] unsignedShortValue];
            NSString *characters = [NSString stringWithCharacters:&character length:1];
            NSEventModifierFlags flags = NSEventModifierFlagNumericPad | NSEventModifierFlagFunction;
            if ([record[@"modifiers"] containsObject:@"left_option"]) flags |= NSEventModifierFlagOption;
            if ([record[@"modifiers"] containsObject:@"left_command"]) flags |= NSEventModifierFlagCommand;
            NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint
                                         modifierFlags:flags timestamp:0 windowNumber:window.windowNumber
                                               context:nil characters:characters charactersIgnoringModifiers:characters
                                             isARepeat:NO keyCode:[arrow[1] unsignedShortValue]];
            [text setSelectedRange:NSMakeRange(29, 0)];
            [text interpretKeyEvents:@[event]];
            NSUInteger expected = [positions[record[@"input"]] unsignedIntegerValue];
            if (text.selectedRange.location != expected || text.selectedRange.length) {
                NSLog(@"%@ moved to %@, expected %lu", record, NSStringFromRange(text.selectedRange), expected);
                return 1;
            }
        }
        puts("All 48 remapped event sequences moved the AppKit text cursor to the expected positions.");
    }
    return 0;
}
