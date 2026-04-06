#import <AppKit/AppKit.h>

#import "TDAppDelegate.h"

int main(int argc, const char **argv)
{
  (void)argc;
  (void)argv;

  @autoreleasepool
    {
      NSApplication *application = [NSApplication sharedApplication];
      TDAppDelegate *delegate = [[TDAppDelegate alloc] init];

      [application setDelegate: delegate];
      [application run];
      [delegate release];
    }

  return 0;
}

