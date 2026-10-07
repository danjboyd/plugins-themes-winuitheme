#import <AppKit/AppKit.h>
#import "QuirkProbe.h"

int
main(int argc, const char *argv[])
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSMenu *mainMenu = nil;
  NSMenu *fileMenu = nil;
  NSMenuItem *fileItem = nil;
  QuirkProbe *probe = nil;

  [NSApplication sharedApplication];

  mainMenu = [[NSMenu alloc] initWithTitle: @"QuirkProbe"];
  fileMenu = [[NSMenu alloc] initWithTitle: @"File"];
  [fileMenu addItemWithTitle: @"Exit"
                      action: @selector(terminate:)
               keyEquivalent: @"q"];
  fileItem = (NSMenuItem *)[mainMenu addItemWithTitle: @"File"
                                               action: NULL
                                        keyEquivalent: @""];
  [mainMenu setSubmenu: fileMenu forItem: fileItem];
  [NSApp setMainMenu: mainMenu];
  RELEASE(fileMenu);
  RELEASE(mainMenu);

  /* NSApp doesn't retain its delegate. */
  probe = [QuirkProbe new];
  [NSApp setDelegate: probe];
  [NSApp run];

  RELEASE(probe);
  [pool drain];
  return 0;
}
