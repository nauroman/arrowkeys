// Configure keyboard services without opening devices or listening to HID reports.
#import <Foundation/Foundation.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>
#import <IOKit/hidsystem/IOHIDServiceClient.h>
#import <IOKit/hid/IOHIDUsageTables.h>
#include <sys/sysctl.h>

@interface KeyboardMapping : NSObject
- (instancetype)initWithRecoveryDefaults:(NSUserDefaults *)defaults;
@property(nonatomic, readonly) NSUInteger connectedKeyboards;
- (BOOL)refresh;
- (BOOL)restore;
- (BOOL)updateKeyboard:(id)registryID current:(NSArray *)current restoring:(BOOL)restoring
                 write:(BOOL (^)(NSArray *))write;
@end

@implementation KeyboardMapping {
    NSMutableDictionary *_snapshots;
    NSUserDefaults *_defaults;
    NSString *_bootID;
}
static NSString *const sourceKey = @"HIDKeyboardModifierMappingSrc";
static NSString *const destinationKey = @"HIDKeyboardModifierMappingDst";
static const uint64_t caps = 0x700000039, option = 0x7000000e2;

- (instancetype)init {
    return [self initWithRecoveryDefaults:nil];
}
- (instancetype)initWithRecoveryDefaults:(NSUserDefaults *)defaults {
    if ((self = [super init])) {
        _snapshots = [NSMutableDictionary new];
        if (defaults) {
            // IORegistry IDs and UserKeyMapping belong to one boot.
            char uuid[64] = {};
            size_t length = sizeof(uuid);
            if (sysctlbyname("kern.bootsessionuuid", uuid, &length, NULL, 0) == 0) {
                _bootID = [NSString stringWithUTF8String:uuid];
                _defaults = defaults;
                NSDictionary *journal = [defaults dictionaryForKey:@"OwnedCapsLockMappings"];
                if ([_bootID isEqual:journal[@"boot"]])
                    [journal[@"devices"] enumerateKeysAndObjectsUsingBlock:^(NSString *key, id entry, BOOL *stop) {
                        self->_snapshots[@(key.longLongValue)] = entry;
                    }];
            }
        }
    }
    return self;
}
- (void)saveSnapshots {
    if (!_defaults) return;
    NSMutableDictionary *devices = [NSMutableDictionary new];
    for (NSNumber *key in _snapshots)
        if (_snapshots[key] != NSNull.null) devices[key.stringValue] = _snapshots[key];
    if (devices.count)
        [_defaults setObject:@{@"boot":_bootID, @"devices":devices} forKey:@"OwnedCapsLockMappings"];
    else
        [_defaults removeObjectForKey:@"OwnedCapsLockMappings"];
    [_defaults synchronize];
}
- (BOOL)updateKeyboard:(id)registryID current:(NSArray *)current restoring:(BOOL)restoring
                 write:(BOOL (^)(NSArray *))write {
    if (current && ![current isKindOfClass:NSArray.class]) return NO;
    current = current ?: @[];
    NSDictionary *desired = @{sourceKey:@(caps), destinationKey:@(option)};
    id snapshot = _snapshots[registryID];
    if (restoring && (!snapshot || snapshot == NSNull.null)) {
        [_snapshots removeObjectForKey:registryID];
        return YES;
    }
    if (!restoring && snapshot) return YES; // Respect edits made while the app runs.
    NSMutableArray *others = [NSMutableArray new], *capsEntries = [NSMutableArray new];
    for (id entry in current) {
        if ([entry isKindOfClass:NSDictionary.class] && [entry[sourceKey] isEqual:@(caps)])
            [capsEntries addObject:entry];
        else
            [others addObject:entry];
    }
    BOOL configured = [capsEntries isEqual:@[desired]];
    if (restoring) {
        if (configured) {
            [others addObjectsFromArray:snapshot[@"caps"]];
            NSArray *restored = [current isEqual:snapshot[@"applied"]] ? snapshot[@"before"] : others;
            if (!write(restored)) return NO;
        }
        [_snapshots removeObjectForKey:registryID];
        [self saveSnapshots];
        return YES;
    }
    if (configured) { _snapshots[registryID] = NSNull.null; return YES; }
    [others addObject:desired];
    _snapshots[registryID] = @{@"before":[current copy], @"applied":[others copy], @"caps":capsEntries};
    [self saveSnapshots];
    return write(others);
}
- (BOOL)update:(BOOL)restoring {
    // A client lists only the services present when it was created, so use a new one each time
    // to include keyboards connected later.
    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreateSimpleClient(NULL);
    if (!client) return NO;
    BOOL success = [self update:restoring client:client];
    CFRelease(client);
    return success;
}
- (BOOL)update:(BOOL)restoring client:(IOHIDEventSystemClientRef)client {
    NSArray *services = CFBridgingRelease(IOHIDEventSystemClientCopyServices(client));
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
            if (!IOHIDServiceClientSetProperty(service, CFSTR("UserKeyMapping"), (__bridge CFArrayRef)mapping))
                return NO;
            NSArray *actual = CFBridgingRelease(IOHIDServiceClientCopyProperty(service, CFSTR("UserKeyMapping")));
            return [(actual ?: @[]) isEqual:mapping];
        }];
        if (!updated) success = NO;
    }
    _connectedKeyboards = connected.count;
    // A disconnected device loses its temporary mapping. Its new service has a new ID.
    // Keep the recovery record if the service list is temporarily empty.
    for (id key in _snapshots.allKeys) if (connected.count && ![connected containsObject:key]) {
        [_snapshots removeObjectForKey:key];
        [self saveSnapshots];
    }
    return success && (restoring || connected.count != 0);
}
- (BOOL)refresh { return [self update:NO]; }
- (BOOL)restore { return !_snapshots.count || [self update:YES]; }
@end
