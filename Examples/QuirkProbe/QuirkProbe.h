#import <AppKit/AppKit.h>

/* Regression checks for WinUITheme, after the Adwaita theme's QuirkProbe.
   Each check builds controls, renders them offscreen where it needs pixels,
   and measures the result, so it doesn't depend on reference screenshots.
   Results go to stdout as PASS/FAIL/KNOWN/SKIP lines; the exit status is the
   number of failures. Run it through Tests/Scripts/Invoke-QuirkProbe.ps1. */
@interface QuirkProbe : NSObject <NSToolbarDelegate, NSTableViewDataSource>
{
  NSString *_outputDirectory;
  NSMutableArray *_windows;
  NSWindow *_firstWindow;
  NSWindow *_lateWindow;
  NSUInteger _passed;
  NSUInteger _failed;
  NSUInteger _known;
  NSUInteger _skipped;
}
@end
