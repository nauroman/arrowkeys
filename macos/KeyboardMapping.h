// Configure keyboard services without opening devices or listening to HID reports.
#import <Foundation/Foundation.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>
#import <IOKit/hidsystem/IOHIDServiceClient.h>
#import <IOKit/hid/IOHIDUsageTables.h>

@interface KeyboardMapping : NSObject
- (BOOL)refresh;
- (void)restore;
@end

@implementation KeyboardMapping {
    IOHIDEventSystemClientRef _client;
    NSMutableDictionary *_previousCaps;
}
static NSString *const sourceKey = @"HIDKeyboardModifierMappingSrc";
static NSString *const destinationKey = @"HIDKeyboardModifierMappingDst";
static const uint64_t caps = 0x700000039, option = 0x7000000e2;

- (instancetype)init {
    if ((self = [super init])) {
        _client = IOHIDEventSystemClientCreateSimpleClient(NULL);
        _previousCaps = [NSMutableDictionary new];
    }
    return self;
}
- (BOOL)update:(BOOL)restoring {
    if (!_client) return NO;
    NSArray *services = CFBridgingRelease(IOHIDEventSystemClientCopyServices(_client));
    if (!services) return NO;
    BOOL success = YES;
    NSMutableSet *connected = [NSMutableSet new];
    NSDictionary *desired = @{sourceKey:@(caps), destinationKey:@(option)};
    for (id item in services) {
        IOHIDServiceClientRef service = (__bridge IOHIDServiceClientRef)item;
        if (!IOHIDServiceClientConformsTo(service, kHIDPage_GenericDesktop, kHIDUsage_GD_Keyboard)) continue;
        id registryID = (__bridge id)IOHIDServiceClientGetRegistryID(service);
        if (!registryID) continue;
        [connected addObject:registryID];
        NSArray *current = CFBridgingRelease(IOHIDServiceClientCopyProperty(service, CFSTR("UserKeyMapping")));
        if (current && ![current isKindOfClass:NSArray.class]) { success = NO; continue; }
        NSMutableArray *other = [NSMutableArray new], *original = [NSMutableArray new];
        for (id entry in current) {
            if ([entry isKindOfClass:NSDictionary.class] && [entry[sourceKey] isEqual:@(caps)]) [original addObject:entry];
            else [other addObject:entry];
        }
        BOOL configured = [original isEqual:@[desired]];
        if (restoring) {
            if (!configured || !_previousCaps[registryID]) continue;
            [other addObjectsFromArray:_previousCaps[registryID]];
        } else {
            if (configured) continue;
            [other addObject:desired];
        }
        if (IOHIDServiceClientSetProperty(service, CFSTR("UserKeyMapping"), (__bridge CFArrayRef)other)) {
            if (!restoring) _previousCaps[registryID] = original;
        } else success = NO;
    }
    for (id key in _previousCaps.allKeys) if (![connected containsObject:key]) [_previousCaps removeObjectForKey:key];
    return success;
}
- (BOOL)refresh { return [self update:NO]; }
- (void)restore { [self update:YES]; }
- (void)dealloc { if (_client) CFRelease(_client); }
@end
