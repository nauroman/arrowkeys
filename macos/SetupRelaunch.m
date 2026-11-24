#import <AppKit/AppKit.h>
#include <poll.h>
#include <unistd.h>

// Only restart our containing bundle, and only after the app finishes its normal cleanup.
int main(int argc, const char **argv) {
    @autoreleasepool {
        if (argc != 1) return 1;
        NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[0]]];
        for (int i = 0; i < 3; i++) url = url.URLByDeletingLastPathComponent;
        if (![[NSBundle bundleWithURL:url].bundleIdentifier isEqual:@"com.nauroman.ArrowKeys.Store"]) return 1;

        struct pollfd parent = { .fd = STDIN_FILENO, .events = POLLIN };
        char request = 0;
        if (poll(&parent, 1, 15000) <= 0 || read(parent.fd, &request, 1) != 1 || request != 'R') return 1;
        if (poll(&parent, 1, 15000) <= 0 || read(parent.fd, &request, 1) != 0) return 1;
        for (int i = 0; i < 100; ++i) {
            if ([NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.nauroman.ArrowKeys.Store"].count == 0) break;
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }
        if (![NSFileManager.defaultManager fileExistsAtPath:url.path]) return 1;

        NSWorkspaceOpenConfiguration *config = [NSWorkspaceOpenConfiguration configuration];
        config.activates = NO;
        __block BOOL finished = NO, opened = NO;
        [NSWorkspace.sharedWorkspace openApplicationAtURL:url configuration:config
            completionHandler:^(NSRunningApplication *app, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{ opened = app != nil; finished = YES; });
            }];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
        while (!finished && deadline.timeIntervalSinceNow > 0)
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        return opened ? 0 : 1;
    }
}
