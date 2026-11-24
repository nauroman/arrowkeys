#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <unistd.h>

static dispatch_source_t watchBundleRemoval(void (^removed)(void)) {
    int fd = open(NSBundle.mainBundle.bundlePath.fileSystemRepresentation, O_EVTONLY);
    if (fd < 0) return nil;
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, fd,
        DISPATCH_VNODE_DELETE | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_REVOKE, dispatch_get_main_queue());
    if (!source) { close(fd); return nil; }
    dispatch_source_set_event_handler(source, removed);
    dispatch_source_set_cancel_handler(source, ^{ close(fd); });
    dispatch_resume(source);
    return source;
}
