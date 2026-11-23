// Configure keyboard services without opening devices or listening to HID reports.
#import <Foundation/Foundation.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>
#import <IOKit/hidsystem/IOHIDServiceClient.h>
#import <IOKit/hid/IOHIDUsageTables.h>

@interface KeyboardMapping : NSObject
- (BOOL)refresh;
- (void)restore;
- (BOOL)updateKeyboard:(id)registryID current:(NSArray *)current restoring:(BOOL)restoring
                 write:(BOOL (^)(NSArray *))write;
@end

@implementation KeyboardMapping {
    IOHIDEventSystemClientRef _client;
    NSMutableDictionary *_snapshots;
}
static NSString *const sourceKey = @"HIDKeyboardModifierMappingSrc";
static NSString *const destinationKey = @"HIDKeyboardModifierMappingDst";
static const uint64_t caps = 0x700000039, option = 0x7000000e2;

- (instancetype)init {
    if ((self = [super init])) {
        _client = IOHIDEventSystemClientCreateSimpleClient(NULL);
        _snapshots = [NSMutableDictionary new];
    }
    return self;
}
- (BOOL)updateKeyboard:(id)registryID current:(NSArray *)current restoring:(BOOL)restoring
                 write:(BOOL (^)(NSArray *))write {
    if (current && ![current isKindOfClass:NSArray.class]) return NO;
    current = current ?: @[];
    NSDictionary *desired = @{sourceKey:@(caps), destinationKey:@(option)};
    id snapshot = _snapshots[registryID];
    if (restoring && (!snapshot || snapshot == NSNull.null)) return YES;
    if (!restoring && snapshot) return YES; // Respect edits made while the app runs.
    if (restoring && [current isEqual:snapshot[@"applied"]]) return write(snapshot[@"before"]);
    NSMutableArray *others = [NSMutableArray new], *capsEntries = [NSMutableArray new];
    for (id entry in current) {
        if ([entry isKindOfClass:NSDictionary.class] && [entry[sourceKey] isEqual:@(caps)])
            [capsEntries addObject:entry];
        else
            [others addObject:entry];
    }
    BOOL configured = [capsEntries isEqual:@[desired]];
    if (restoring) {
        if (!configured) return YES;
        [others addObjectsFromArray:snapshot[@"caps"]];
        return write(others);
    }
    if (configured) { _snapshots[registryID] = NSNull.null; return YES; }
    [others addObject:desired];
    if (!write(others)) return NO;
    _snapshots[registryID] = @{@"before":[current copy], @"applied":[others copy], @"caps":capsEntries};
    return YES;
}
- (BOOL)update:(BOOL)restoring {
    if (!_client) return NO;
    NSArray *services = CFBridgingRelease(IOHIDEventSystemClientCopyServices(_client));
    if (!services) return NO;
    BOOL success = YES;
    NSMutableSet *connected = [NSMutableSet new];
    for (id item in services) {
        IOHIDServiceClientRef service = (__bridge IOHIDServiceClientRef)item;
        if (!IOHIDServiceClientConformsTo(service, kHIDPage_GenericDesktop, kHIDUsage_GD_Keyboard)) continue;
        id registryID = (__bridge id)IOHIDServiceClientGetRegistryID(service);
        if (!registryID) continue;
        [connected addObject:registryID];
        NSArray *current = CFBridgingRelease(IOHIDServiceClientCopyProperty(service, CFSTR("UserKeyMapping")));
        BOOL updated = [self updateKeyboard:registryID current:current restoring:restoring write:^BOOL(NSArray *mapping) {
            return IOHIDServiceClientSetProperty(service, CFSTR("UserKeyMapping"), (__bridge CFArrayRef)mapping);
        }];
        if (!updated) success = NO;
    }
    for (id key in _snapshots.allKeys) if (![connected containsObject:key]) [_snapshots removeObjectForKey:key];
    return success;
}
- (BOOL)refresh { return [self update:NO]; }
- (void)restore { [self update:YES]; }
- (void)dealloc { if (_client) CFRelease(_client); }
@end
