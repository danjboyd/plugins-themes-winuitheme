#import "QuirkProbe.h"

#import <GNUstepGUI/GSTheme.h>
#import <GNUstepGUI/GSDisplayServer.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN 1
#include <windows.h>
#endif

static NSString *QuirkProbeImageItem = @"ImageItem";
static const NSTimeInterval QuirkProbeSettleDelay = 0.8;

static BOOL QuirkProbeHasArgument(NSString *flag, NSString *value);

/* Moves the pointer to `point` in GNUstep screen coordinates (origin at
   the bottom left). libs-back's Windows server doesn't implement
   -setMouseLocation:onScreen:. */
static void
QuirkProbeSetPointer(NSPoint point)
{
#ifdef _WIN32
  CGFloat screenHeight = NSHeight([[NSScreen mainScreen] frame]);

  SetCursorPos((int)point.x, (int)(screenHeight - point.y));
#else
  [GSCurrentServer() setMouseLocation: point onScreen: [[NSScreen mainScreen] screenNumber]];
#endif
}

/* What a timer firing during menu tracking saw. */
static NSString *QuirkProbeMenuSeen = nil;

#pragma mark Pixels

/* Ink extent of the pixels a test accepts, in pixels from the top left. */
typedef struct
{
  NSInteger minX;
  NSInteger minY;
  NSInteger width;
  NSInteger height;
  NSUInteger count;
} QuirkProbeInk;

typedef BOOL (*QuirkProbePixelTest)(NSUInteger red, NSUInteger green, NSUInteger blue);

/* The probe's test images are magenta, a colour the theme never draws. */
static BOOL
QuirkProbeIsMagenta(NSUInteger red, NSUInteger green, NSUInteger blue)
{
  return red > 200 && green < 80 && blue > 200;
}

/* Ink on the background whose red + green + blue is QuirkProbeInkBackground,
   darker or lighter: text in any palette. Set the background first. */
static NSUInteger QuirkProbeInkBackground = 750;

static BOOL
QuirkProbeIsInk(NSUInteger red, NSUInteger green, NSUInteger blue)
{
  NSInteger difference = (NSInteger)(red + green + blue) - (NSInteger)QuirkProbeInkBackground;

  return difference > 150 || difference < -150;
}

/* Anything visibly different from that background, however faint:
   disabled outlines and fills. */
static BOOL
QuirkProbeIsFaintInk(NSUInteger red, NSUInteger green, NSUInteger blue)
{
  NSInteger difference = (NSInteger)(red + green + blue) - (NSInteger)QuirkProbeInkBackground;

  return difference > 30 || difference < -30;
}

static NSBitmapImageRep *
QuirkProbeRender(NSView *view)
{
  NSRect bounds = [view bounds];
  NSBitmapImageRep *rep = [view bitmapImageRepForCachingDisplayInRect: bounds];

  [view cacheDisplayInRect: bounds toBitmapImageRep: rep];
  return rep;
}

/* Device pixels per point in a render of `view`. */
static CGFloat
QuirkProbeScale(NSBitmapImageRep *rep, NSView *view)
{
  CGFloat width = NSWidth([view bounds]);

  return (width > 0.0) ? [rep pixelsWide] / width : 1.0;
}

static BOOL
QuirkProbePixel(NSBitmapImageRep *rep, NSInteger x, NSInteger y,
                NSUInteger *red, NSUInteger *green, NSUInteger *blue)
{
  NSInteger samples = [rep samplesPerPixel];
  NSInteger bits = [rep bitsPerSample];
  NSUInteger maxValue = (bits >= 16) ? 65535 : ((1u << bits) - 1);
  BOOL alphaFirst = ([rep hasAlpha]
                     && ([rep bitmapFormat] & NSAlphaFirstBitmapFormat) != 0);
  NSInteger colorStart = alphaFirst ? 1 : 0;
  NSUInteger pixel[5];

  if (samples < 3 || samples > 5
      || x < 0 || y < 0 || x >= [rep pixelsWide] || y >= [rep pixelsHigh])
    {
      return NO;
    }
  [rep getPixel: pixel atX: x y: y];
  *red = pixel[colorStart] * 255 / maxValue;
  *green = pixel[colorStart + 1] * 255 / maxValue;
  *blue = pixel[colorStart + 2] * 255 / maxValue;
  return YES;
}

/* Measures the accepted pixels in `area` (pixels, top-left origin), or in
   the whole image when `area` is empty. */
static QuirkProbeInk
QuirkProbeMeasureIn(NSBitmapImageRep *rep, QuirkProbePixelTest test, NSRect area)
{
  QuirkProbeInk ink = { 0, 0, 0, 0, 0 };
  NSInteger minX = NSIntegerMax, minY = NSIntegerMax, maxX = -1, maxY = -1;
  NSInteger startX = 0, startY = 0;
  NSInteger endX = [rep pixelsWide], endY = [rep pixelsHigh];
  NSInteger x, y;

  if (NSIsEmptyRect(area) == NO)
    {
      startX = MAX(0, (NSInteger)NSMinX(area));
      startY = MAX(0, (NSInteger)NSMinY(area));
      endX = MIN(endX, (NSInteger)NSMaxX(area));
      endY = MIN(endY, (NSInteger)NSMaxY(area));
    }
  for (y = startY; y < endY; y++)
    {
      for (x = startX; x < endX; x++)
        {
          NSUInteger red, green, blue;

          if (QuirkProbePixel(rep, x, y, &red, &green, &blue) && test(red, green, blue))
            {
              ink.count++;
              minX = MIN(minX, x);
              maxX = MAX(maxX, x);
              minY = MIN(minY, y);
              maxY = MAX(maxY, y);
            }
        }
    }
  if (ink.count > 0)
    {
      ink.minX = minX;
      ink.minY = minY;
      ink.width = maxX - minX + 1;
      ink.height = maxY - minY + 1;
    }
  return ink;
}

static NSView *
QuirkProbeFindViewOfClass(NSView *view, Class viewClass)
{
  NSEnumerator *enumerator = nil;
  NSView *subview = nil;

  if (viewClass == Nil)
    {
      return nil;
    }
  if ([view isKindOfClass: viewClass])
    {
      return view;
    }
  enumerator = [[view subviews] objectEnumerator];
  while ((subview = [enumerator nextObject]) != nil)
    {
      NSView *found = QuirkProbeFindViewOfClass(subview, viewClass);

      if (found != nil)
        {
          return found;
        }
    }
  return nil;
}

/* The accent blue (any of Windows' blue accents): clearly bluer than red. */
static BOOL
QuirkProbeIsAccentBlue(NSUInteger red, NSUInteger green, NSUInteger blue)
{
  return blue > 150 && blue > red + 60;
}

/* Pixel rect, top-left origin, of `frame` (in `view`'s coordinates) in a
   render of `view`. */
static NSRect
QuirkProbePixelRect(NSView *view, NSRect frame, CGFloat scale)
{
  if ([view isFlipped] == NO)
    {
      frame.origin.y = NSHeight([view bounds]) - NSMaxY(frame);
    }
  return NSMakeRect(floor(NSMinX(frame) * scale), floor(NSMinY(frame) * scale),
                    ceil(NSWidth(frame) * scale), ceil(NSHeight(frame) * scale));
}

/* How many pixels of row `y` (top-left origin) between x0 and x1 pass `test`. */
static NSUInteger
QuirkProbeRowCount(NSBitmapImageRep *rep, QuirkProbePixelTest test,
                   NSInteger y, NSInteger x0, NSInteger x1)
{
  NSUInteger count = 0;
  NSInteger x;

  for (x = x0; x < x1; x++)
    {
      NSUInteger red, green, blue;

      if (QuirkProbePixel(rep, x, y, &red, &green, &blue) && test(red, green, blue))
        {
          count++;
        }
    }
  return count;
}

/* Which way the chevron in `area` of `rep` points: 1 up (narrow at its
   top), -1 down (narrow at its bottom), 0 if there's no chevron. */
static NSInteger
QuirkProbeChevronDirection(NSBitmapImageRep *rep, NSRect area)
{
  QuirkProbeInk ink = QuirkProbeMeasureIn(rep, QuirkProbeIsInk, area);
  NSInteger x0 = (NSInteger)NSMinX(area);
  NSInteger x1 = (NSInteger)NSMaxX(area);
  NSUInteger top, bottom;

  if (ink.count == 0 || ink.height < 2)
    {
      return 0;
    }
  top = QuirkProbeRowCount(rep, QuirkProbeIsInk, ink.minY, x0, x1);
  bottom = QuirkProbeRowCount(rep, QuirkProbeIsInk, ink.minY + ink.height - 1, x0, x1);
  if (top < bottom)
    {
      return 1;
    }
  return (top > bottom) ? -1 : 0;
}

/* The module (DLL) whose code `address` is in. */
static void *
QuirkProbeModuleOfAddress(void *address)
{
#ifdef _WIN32
  HMODULE module = NULL;

  if (address != NULL
      && GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS
                            | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                            (LPCWSTR)address, &module))
    {
      return (void *)module;
    }
#endif
  return NULL;
}

#pragma mark Test classes

/* A button cell subclass, as GSToolbarButtonCell is: theme overrides
   installed on NSButtonCell reach it through inheritance. */
@interface QuirkProbeButtonCell : NSButtonCell
@end

@implementation QuirkProbeButtonCell
@end

@interface QuirkProbe ()
- (void) checkTheme;
- (void) checkSubclassImageCell;
- (void) checkToolbarImageItem;
- (void) checkScrollerEdge;
- (void) checkTableHeader;
- (void) checkMultilineLabels;
- (void) checkSwitches;
- (void) checkStepper;
- (void) checkDefaultButtons;
- (void) checkPopUpClick;
- (void) checkWindowsMenuConventions;
- (void) checkAccentColor;
- (void) checkAlertLayout;
- (void) checkTemplateImages;
- (void) checkButtonChrome;
- (void) checkMenuFlyout;
- (void) checkOverlayScrollers;
- (void) checkFocusVisual;
- (void) checkTextBox;
- (void) checkComboBoxes;
- (void) checkListSelection;
- (void) checkSearchField;
- (void) checkHorizontalOnlyScroller;
- (void) createLateWindow: (NSTimer *)timer;
- (void) checkLateWindow: (NSTimer *)timer;
- (void) checkMenuBarTitles: (NSWindow *)window;
- (void) checkThemeSwitchRestoresMethods;
- (void) finish;
@end

/* A document view in mid grey, 128 in each channel, for telling a scroll
   bar from what's under it. */
@interface QuirkProbeFillView : NSView
@end

@implementation QuirkProbeFillView

- (void) drawRect: (NSRect)rect
{
  [[NSColor colorWithCalibratedRed: 128.0 / 255.0 green: 128.0 / 255.0 blue: 128.0 / 255.0 alpha: 1.0] set];
  NSRectFill(rect);
}

- (BOOL) isOpaque
{
  return YES;
}

@end

/* Rows for the selection checks: a table of three, and an outline whose
   "Parent" holds an expandable "Child" holding "Leaf". */
@interface QuirkProbeRows : NSObject
@end

@implementation QuirkProbeRows

- (NSInteger) numberOfRowsInTableView: (NSTableView *)tableView
{
  return 3;
}

- (id) tableView: (NSTableView *)tableView objectValueForTableColumn: (NSTableColumn *)column row: (NSInteger)row
{
  return [NSString stringWithFormat: @"Row %ld", (long)row];
}

- (NSInteger) outlineView: (NSOutlineView *)outlineView numberOfChildrenOfItem: (id)item
{
  return (item == nil || [item isEqual: @"Parent"] || [item isEqual: @"Child"]) ? 1 : 0;
}

- (id) outlineView: (NSOutlineView *)outlineView child: (NSInteger)index ofItem: (id)item
{
  return item == nil ? @"Parent" : ([item isEqual: @"Parent"] ? @"Child" : @"Leaf");
}

- (BOOL) outlineView: (NSOutlineView *)outlineView isItemExpandable: (id)item
{
  return [item isEqual: @"Parent"] || [item isEqual: @"Child"];
}

- (id) outlineView: (NSOutlineView *)outlineView objectValueForTableColumn: (NSTableColumn *)column byItem: (id)item
{
  return item;
}

@end

@implementation QuirkProbe

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      _windows = [NSMutableArray new];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_outputDirectory);
  RELEASE(_windows);
  [super dealloc];
}

#pragma mark Results

- (void) report: (NSString *)status ident: (NSString *)ident detail: (NSString *)detail
{
  if ([detail length] > 0)
    {
      printf("%-5s %s: %s\n", [status UTF8String], [ident UTF8String], [detail UTF8String]);
    }
  else
    {
      printf("%-5s %s\n", [status UTF8String], [ident UTF8String]);
    }
  fflush(stdout);
}

- (void) pass: (NSString *)ident detail: (NSString *)detail
{
  _passed++;
  [self report: @"PASS" ident: ident detail: detail];
}

- (void) fail: (NSString *)ident detail: (NSString *)detail
{
  _failed++;
  [self report: @"FAIL" ident: ident detail: detail];
}

- (void) known: (NSString *)ident detail: (NSString *)detail
{
  _known++;
  [self report: @"KNOWN" ident: ident detail: detail];
}

- (void) skip: (NSString *)ident detail: (NSString *)detail
{
  _skipped++;
  [self report: @"SKIP" ident: ident detail: detail];
}

#pragma mark Helpers

- (void) after: (NSTimeInterval)delay perform: (SEL)selector
{
  [NSTimer scheduledTimerWithTimeInterval: delay
                                   target: self
                                 selector: selector
                                 userInfo: nil
                                  repeats: NO];
}

- (void) saveView: (NSView *)view named: (NSString *)name
{
  NSData *png = nil;
  NSString *path = nil;

  if (_outputDirectory == nil || view == nil)
    {
      return;
    }
  png = [QuirkProbeRender(view) representationUsingType: NSPNGFileType
                                             properties: [NSDictionary dictionary]];
  path = [_outputDirectory stringByAppendingPathComponent:
    [name stringByAppendingPathExtension: @"png"]];
  [png writeToFile: path atomically: YES];
}

- (NSWindow *) windowWithFrame: (NSRect)frame title: (NSString *)title
{
  NSWindow *window = [[NSWindow alloc] initWithContentRect: frame
                                                 styleMask: (NSTitledWindowMask
                                                             | NSClosableWindowMask
                                                             | NSResizableWindowMask)
                                                   backing: NSBackingStoreBuffered
                                                     defer: NO];

  [window setTitle: title];
  [window setReleasedWhenClosed: NO];
  [_windows addObject: window];
  RELEASE(window);
  return window;
}

- (NSImage *) magentaImage
{
  NSImage *image = [[NSImage alloc] initWithSize: NSMakeSize(24, 24)];

  [image lockFocus];
  [[NSColor colorWithCalibratedRed: 1.0 green: 0.0 blue: 1.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(2, 2, 20, 20));
  [image unlockFocus];
  return AUTORELEASE(image);
}

#pragma mark Toolbar delegate

- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar
      itemForItemIdentifier: (NSString *)identifier
  willBeInsertedIntoToolbar: (BOOL)flag
{
  NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier: identifier];

  [item setLabel: @"Image"];
  [item setImage: [self magentaImage]];
  /* An item without an action is disabled, and draws its image faded. */
  [item setTarget: self];
  [item setAction: @selector(toolbarItemClicked:)];
  return AUTORELEASE(item);
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *)toolbar
{
  return [NSArray arrayWithObject: QuirkProbeImageItem];
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *)toolbar
{
  return [NSArray arrayWithObject: QuirkProbeImageItem];
}

- (void) toolbarItemClicked: (id)sender
{
}

#pragma mark Table data source

- (NSInteger) numberOfRowsInTableView: (NSTableView *)tableView
{
  return 3;
}

- (id) tableView: (NSTableView *)tableView
objectValueForTableColumn: (NSTableColumn *)column
             row: (NSInteger)row
{
  return [NSString stringWithFormat: @"Row %ld", (long)row];
}

- (NSTextField *) labelWithText: (NSString *)text frame: (NSRect)frame
{
  NSTextField *label = [[NSTextField alloc] initWithFrame: frame];

  [label setStringValue: text];
  [label setBezeled: NO];
  [label setBordered: NO];
  [label setEditable: NO];
  [label setSelectable: NO];
  [label setDrawsBackground: YES];
  [label setBackgroundColor: [NSColor whiteColor]];
  [label setTextColor: [NSColor blackColor]];
  return AUTORELEASE(label);
}

#pragma mark Checks

/* The theme under test is loaded, and libs-gui installed its
   _override<Class>Method_<selector> methods. libs-gui before 0.32
   (a8018d6c8) misparses those names, installs none of them and overruns a
   stack buffer while trying. */
- (void) checkTheme
{
  GSTheme *theme = [GSTheme theme];
  NSString *className = NSStringFromClass([theme class]);
  SEL selector = @selector(titleRectForBounds:);
  IMP installed = [NSTextFieldCell instanceMethodForSelector: selector];
  IMP override = [[theme class] instanceMethodForSelector:
    NSSelectorFromString(@"_overrideNSTextFieldCellMethod_titleRectForBounds:")];

  if ([className isEqualToString: @"WinUITheme"])
    {
      [self pass: @"theme-loaded" detail: [[theme bundle] bundlePath]];
    }
  else
    {
      [self fail: @"theme-loaded" detail:
        [NSString stringWithFormat: @"the active theme is %@; pass -GSTheme PATH", className]];
    }

  /* The theme's GSThemeDomain (Windows 95 menus and scrollers) is in
     effect. A clean build once shipped a generated Info-gnustep.plist
     without it, putting scrollers on the left. */
  if ([[[NSUserDefaults standardUserDefaults] searchList] containsObject: @"GSThemeDomain"]
      && [[[NSUserDefaults standardUserDefaults] stringForKey: @"NSScrollViewInterfaceStyle"]
           isEqualToString: @"NSWindows95InterfaceStyle"])
    {
      [self pass: @"theme-domain" detail: @"the theme's GSThemeDomain defaults are in effect"];
    }
  else
    {
      [self fail: @"theme-domain" detail:
        @"GSThemeDomain is missing: the bundle's Info-gnustep.plist lacks the theme's defaults"];
    }

  if (override == NULL)
    {
      [self skip: @"overrides-installed" detail: @"the theme has no NSTextFieldCell override"];
    }
  else if (installed == override)
    {
      [self pass: @"overrides-installed" detail: @"libs-gui installed the theme's method overrides"];
    }
  else
    {
      [self fail: @"overrides-installed" detail:
        @"libs-gui didn't install the theme's overrides (libs-gui before 0.32 misparses them)"];
    }
}

/* Overrides reached from a subclass call the original implementation
   (issue #2). Before the fix, an image button whose cell is an NSButtonCell
   subclass drew nothing. */
- (void) checkSubclassImageCell
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(80, 520, 200, 80)
                                     title: @"QuirkProbe Subclass Cell"];
  NSButton *button = [[NSButton alloc] initWithFrame: NSMakeRect(20, 20, 60, 40)];
  QuirkProbeButtonCell *cell = [[QuirkProbeButtonCell alloc] initImageCell: [self magentaImage]];
  QuirkProbeInk ink;

  [cell setBezelStyle: NSRoundedBezelStyle];
  [cell setImagePosition: NSImageOnly];
  [button setCell: cell];
  RELEASE(cell);
  [[window contentView] addSubview: button];
  RELEASE(button);
  [window orderFront: nil];
  [window display];

  ink = QuirkProbeMeasureIn(QuirkProbeRender(button), QuirkProbeIsMagenta, NSZeroRect);
  [self saveView: button named: @"subclass-image-cell"];
  if (ink.count >= 100)
    {
      [self pass: @"subclass-image-cell" detail:
        [NSString stringWithFormat: @"the image drew (%lu px)", (unsigned long)ink.count]];
    }
  else
    {
      [self fail: @"subclass-image-cell" detail:
        [NSString stringWithFormat: @"an NSButtonCell subclass drew %lu px of its image",
                                    (unsigned long)ink.count]];
    }
}

/* An image toolbar item draws its image (issue #2): GSToolbarButtonCell is
   an NSButtonCell subclass. */
- (void) checkToolbarImageItem
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(320, 480, 320, 140)
                                     title: @"QuirkProbe Toolbar"];
  NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier: @"QuirkProbeToolbar"];
  NSView *frameView = nil;
  NSView *toolbarView = nil;
  QuirkProbeInk ink;

  [toolbar setDelegate: self];
  [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
  [window setToolbar: toolbar];
  RELEASE(toolbar);
  [window orderFront: nil];
  [window display];

  frameView = [[window contentView] superview];
  toolbarView = QuirkProbeFindViewOfClass(frameView, NSClassFromString(@"GSToolbarView"));
  if (toolbarView == nil)
    {
      [self skip: @"toolbar-image-item" detail: @"no GSToolbarView in the window"];
      return;
    }
  ink = QuirkProbeMeasureIn(QuirkProbeRender(toolbarView), QuirkProbeIsMagenta, NSZeroRect);
  [self saveView: toolbarView named: @"toolbar-image-item"];
  if (ink.count >= 100)
    {
      [self pass: @"toolbar-image-item" detail:
        [NSString stringWithFormat: @"the item's image drew (%lu px)", (unsigned long)ink.count]];
    }
  else
    {
      [self fail: @"toolbar-image-item" detail:
        [NSString stringWithFormat: @"the item drew %lu px of its image", (unsigned long)ink.count]];
    }

  /* WinUI's CommandBar (issue #21): an icon-only toolbar is a 48pt row
     (libs-gui's was about 40pt, 62pt with labels), and the line under it
     is a faint divider, not libs-gui's dark grey. */
  {
    CGFloat height = NSHeight([toolbarView frame]);
    NSBitmapImageRep *rep = QuirkProbeRender(toolbarView);
    CGFloat scale = QuirkProbeScale(rep, toolbarView);
    NSInteger x = [rep pixelsWide] - (NSInteger)(20 * scale);
    NSUInteger red, green, blue, lineRed, lineGreen, lineBlue;
    NSInteger lineY = [rep pixelsHigh] - 1;
    NSInteger contrast;

    if (fabs(height - 48.0) <= 1.0)
      {
        [self pass: @"toolbar-row-height" detail: @"an icon-only toolbar is 48pt, as CommandBar"];
      }
    else
      {
        [self fail: @"toolbar-row-height" detail:
          [NSString stringWithFormat: @"an icon-only toolbar is %.0fpt, expected 48", height]];
      }

    QuirkProbePixel(rep, x, [rep pixelsHigh] / 2, &red, &green, &blue);
    QuirkProbePixel(rep, x, lineY, &lineRed, &lineGreen, &lineBlue);
    contrast = llabs((long long)(red + green + blue) - (long long)(lineRed + lineGreen + lineBlue));
    if (QuirkProbeHasArgument(@"--high-contrast", nil))
      {
        [self skip: @"toolbar-bottom-line" detail: @"high contrast draws a full-strength line"];
      }
    else if (contrast <= 90)
      {
        [self pass: @"toolbar-bottom-line" detail:
          [NSString stringWithFormat: @"the line under the toolbar is %ld from its background (of 765)",
                                      (long)contrast]];
      }
    else
      {
        [self fail: @"toolbar-bottom-line" detail:
          [NSString stringWithFormat: @"the line under the toolbar is %ld from its background (of 765)",
                                      (long)contrast]];
      }
  }
}

/* Vertical scrollers sit on the trailing (right) edge (issue #4). */
- (void) checkScrollerEdge
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(80, 260, 320, 200)
                                     title: @"QuirkProbe Scroller"];
  NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame: NSMakeRect(10, 10, 300, 180)];
  NSView *document = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 280, 800)];
  NSRect content;
  NSRect scroller;

  [scrollView setHasVerticalScroller: YES];
  [scrollView setDocumentView: document];
  RELEASE(document);
  [[window contentView] addSubview: scrollView];
  RELEASE(scrollView);
  [window orderFront: nil];
  [scrollView tile];
  [window display];

  content = [[scrollView contentView] frame];
  scroller = [[scrollView verticalScroller] frame];
  [self saveView: scrollView named: @"scroller-edge"];
  /* Beside the content, or over its trailing edge where scroll bars
     overlay it (#29). */
  if (NSMaxX(scroller) >= NSMaxX(content) - 1.0 && NSMinX(scroller) > NSMidX(content))
    {
      [self pass: @"scroller-trailing-edge" detail:
        [NSString stringWithFormat: @"scroller at x=%.0f, content ends at %.0f",
                                    NSMinX(scroller), NSMaxX(content)]];
    }
  else
    {
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

      [self fail: @"scroller-trailing-edge" detail:
        [NSString stringWithFormat: @"scroller at x=%.0f is left of the content (x=%.0f); "
                                    @"style %d, NSScrollViewInterfaceStyle=%@, "
                                    @"NSInterfaceStyleDefault=%@, search list %@",
                                    NSMinX(scroller), NSMinX(content),
                                    (int)NSInterfaceStyleForKey(@"NSScrollViewInterfaceStyle", nil),
                                    [defaults stringForKey: @"NSScrollViewInterfaceStyle"],
                                    [defaults stringForKey: @"NSInterfaceStyleDefault"],
                                    [[defaults searchList] componentsJoinedByString: @","]]];
    }
}

/* A table header shows each title once, 12pt in from the leading edge
   (issue #3). The theme drew the title in -drawTableHeaderCell:... and
   NSTableHeaderCell drew it again. */
- (void) checkTableHeader
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(420, 220, 340, 200)
                                     title: @"QuirkProbe Table"];
  NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame: NSMakeRect(10, 10, 320, 180)];
  NSTableView *tableView = [[NSTableView alloc] initWithFrame: NSMakeRect(0, 0, 300, 160)];
  NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier: @"name"];
  NSTableHeaderView *headerView = nil;
  NSBitmapImageRep *rep = nil;
  NSDictionary *attributes = nil;
  NSSize titleSize;
  CGFloat scale;
  NSUInteger red, green, blue;
  QuirkProbeInk ink;
  NSRect area;
  CGFloat inset;

  [[column headerCell] setStringValue: @"Name"];
  [column setWidth: 260];
  [tableView addTableColumn: column];
  RELEASE(column);
  [tableView setDataSource: self];
  [scrollView setHasVerticalScroller: YES];
  [scrollView setDocumentView: tableView];
  RELEASE(tableView);
  [[window contentView] addSubview: scrollView];
  RELEASE(scrollView);
  [window orderFront: nil];
  [window display];

  headerView = [tableView headerView];
  if (headerView == nil || NSIsEmptyRect([headerView bounds]))
    {
      [self skip: @"table-header-title-once" detail: @"the table has no header view"];
      return;
    }
  rep = QuirkProbeRender(headerView);
  scale = QuirkProbeScale(rep, headerView);
  [self saveView: headerView named: @"table-header"];

  /* The background: a pixel to the right of the title, mid-height. */
  if (QuirkProbePixel(rep, (NSInteger)(200 * scale),
                      [rep pixelsHigh] / 2, &red, &green, &blue) == NO)
    {
      [self skip: @"table-header-title-once" detail: @"couldn't read the header's pixels"];
      return;
    }
  QuirkProbeInkBackground = red + green + blue;

  /* The title's column, less the divider at its trailing edge and the line
     under the header. */
  area = NSMakeRect(0, 1, 240 * scale, [rep pixelsHigh] - 3);
  ink = QuirkProbeMeasureIn(rep, QuirkProbeIsInk, area);
  attributes = [NSDictionary dictionaryWithObject: [[column headerCell] font]
                                           forKey: NSFontAttributeName];
  titleSize = [@"Name" sizeWithAttributes: attributes];

  if (ink.count == 0)
    {
      [self fail: @"table-header-title-once" detail: @"the header shows no title"];
      return;
    }
  if (ink.width <= ceil(titleSize.width * scale) + 3
      && ink.height <= ceil(titleSize.height * scale) + 2)
    {
      [self pass: @"table-header-title-once" detail:
        [NSString stringWithFormat: @"title ink %ldx%ld px, one title is %.0fx%.0f",
                                    (long)ink.width, (long)ink.height,
                                    titleSize.width * scale, titleSize.height * scale]];
    }
  else
    {
      [self fail: @"table-header-title-once" detail:
        [NSString stringWithFormat: @"title ink %ldx%ld px is larger than one title (%.0fx%.0f)",
                                    (long)ink.width, (long)ink.height,
                                    titleSize.width * scale, titleSize.height * scale]];
    }

  inset = ink.minX / scale;
  if (inset >= 10.0 && inset <= 16.0)
    {
      [self pass: @"table-header-title-inset" detail:
        [NSString stringWithFormat: @"title starts %.0fpt in", inset]];
    }
  else
    {
      [self fail: @"table-header-title-inset" detail:
        [NSString stringWithFormat: @"title starts %.0fpt in, expected about 12", inset]];
    }
}

/* Labels whose text needs more than one line show every line that fits
   (issue #15): wrapping text, and text with line breaks. The theme centred
   every label on a single line. */
- (void) checkMultilineLabels
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(780, 220, 300, 220)
                                     title: @"QuirkProbe Labels"];
  NSTextField *wrapping = [self labelWithText:
    @"The files stay on this computer. The app stops syncing this folder "
    @"and forgets its settings; you can add it again later."
                                        frame: NSMakeRect(10, 110, 220, 100)];
  NSTextField *breaks = [self labelWithText: @"First line\nSecond line\nThird line"
                                      frame: NSMakeRect(10, 10, 220, 90)];
  NSArray *labels = [NSArray arrayWithObjects: wrapping, breaks, nil];
  NSArray *names = [NSArray arrayWithObjects: @"label-wraps", @"label-line-breaks", nil];
  NSUInteger index;

  [[wrapping cell] setWraps: YES];
  [[wrapping cell] setLineBreakMode: NSLineBreakByWordWrapping];
  [[window contentView] addSubview: wrapping];
  [[window contentView] addSubview: breaks];
  [window orderFront: nil];
  [window display];

  QuirkProbeInkBackground = 765;
  for (index = 0; index < [labels count]; index++)
    {
      NSTextField *label = [labels objectAtIndex: index];
      NSString *name = [names objectAtIndex: index];
      NSBitmapImageRep *rep = QuirkProbeRender(label);
      CGFloat scale = QuirkProbeScale(rep, label);
      NSDictionary *attributes = [NSDictionary dictionaryWithObject: [label font]
                                                             forKey: NSFontAttributeName];
      CGFloat lineHeight = [@"Ag" sizeWithAttributes: attributes].height * scale;
      QuirkProbeInk ink = QuirkProbeMeasureIn(rep, QuirkProbeIsInk, NSZeroRect);

      [self saveView: label named: name];
      if (ink.count > 0 && ink.height > 1.5 * lineHeight)
        {
          [self pass: name detail:
            [NSString stringWithFormat: @"text spans %ld px, a line is %.0f",
                                        (long)ink.height, lineHeight]];
        }
      else
        {
          [self fail: name detail:
            [NSString stringWithFormat: @"text spans %ld px: one line of %.0f",
                                        (long)ink.height, lineHeight]];
        }
    }
}

/* NSSwitch (issue #6): enabled when made in code (libs-gui 0.32 left it
   disabled), WinUI's 40x20 track rather than one stretched to the frame,
   and On distinguishable from Off, enabled or not. */
- (void) checkSwitches
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(780, 480, 320, 80)
                                     title: @"QuirkProbe Switches"];
  NSView *content = [window contentView];
  NSRect frames[4] = {
    { { 10, 30 }, { 60, 28 } }, { { 80, 30 }, { 60, 28 } },
    { { 150, 30 }, { 60, 28 } }, { { 220, 30 }, { 60, 28 } }
  };
  NSSwitch *switches[4];
  QuirkProbeInk accent[4];
  QuirkProbeInk ink[4];
  NSBitmapImageRep *rep = nil;
  CGFloat scale;
  NSUInteger red, green, blue;
  NSUInteger index;

  for (index = 0; index < 4; index++)
    {
      switches[index] = AUTORELEASE([[NSSwitch alloc] initWithFrame: frames[index]]);
      [content addSubview: switches[index]];
    }

  if ([switches[0] isEnabled])
    {
      [self pass: @"switch-enabled-by-default" detail: @"a switch made in code is enabled"];
    }
  else
    {
      [self fail: @"switch-enabled-by-default" detail: @"a switch made in code is disabled"];
    }

  /* On, off, disabled on, disabled off. */
  [switches[0] setState: NSControlStateValueOn];
  [switches[1] setState: NSControlStateValueOff];
  [switches[2] setState: NSControlStateValueOn];
  [switches[2] setEnabled: NO];
  [switches[3] setState: NSControlStateValueOff];
  [switches[3] setEnabled: NO];
  [window orderFront: nil];
  [window display];

  rep = QuirkProbeRender(content);
  scale = QuirkProbeScale(rep, content);
  [self saveView: content named: @"switches"];
  QuirkProbePixel(rep, 2, 2, &red, &green, &blue);
  QuirkProbeInkBackground = red + green + blue;
  for (index = 0; index < 4; index++)
    {
      NSRect area = QuirkProbePixelRect(content, frames[index], scale);

      accent[index] = QuirkProbeMeasureIn(rep, QuirkProbeIsAccentBlue, area);
      ink[index] = QuirkProbeMeasureIn(rep, QuirkProbeIsFaintInk, area);
    }

  /* The off switch's outline spans the track. */
  if (ink[1].width >= 36 * scale && ink[1].width <= 42 * scale)
    {
      [self pass: @"switch-track-size" detail:
        [NSString stringWithFormat: @"track %ld px wide in a 60pt frame", (long)ink[1].width]];
    }
  else
    {
      [self fail: @"switch-track-size" detail:
        [NSString stringWithFormat: @"track %ld px wide in a 60pt frame, expected about 40",
                                    (long)ink[1].width]];
    }

  /* On fills its track (in the accent, where the palette has one); off is
     an outline and a knob. */
  if (ink[0].count > 2 * MAX((NSUInteger)1, ink[1].count))
    {
      [self pass: @"switch-on-off-differ" detail:
        [NSString stringWithFormat: @"on has %lu px of ink (%lu accent), off %lu",
                                    (unsigned long)ink[0].count, (unsigned long)accent[0].count,
                                    (unsigned long)ink[1].count]];
    }
  else
    {
      [self fail: @"switch-on-off-differ" detail:
        [NSString stringWithFormat: @"on has %lu px of ink (%lu accent), off %lu",
                                    (unsigned long)ink[0].count, (unsigned long)accent[0].count,
                                    (unsigned long)ink[1].count]];
    }

  /* Disabled: the on track is filled, the off one only outlined. */
  if (ink[2].count > 2 * MAX((NSUInteger)1, ink[3].count))
    {
      [self pass: @"switch-disabled-on-off-differ" detail:
        [NSString stringWithFormat: @"disabled on has %lu px of ink, disabled off %lu",
                                    (unsigned long)ink[2].count, (unsigned long)ink[3].count]];
    }
  else
    {
      [self fail: @"switch-disabled-on-off-differ" detail:
        [NSString stringWithFormat: @"disabled on has %lu px of ink, disabled off %lu",
                                    (unsigned long)ink[2].count, (unsigned long)ink[3].count]];
    }
}

/* NSStepper's chevrons point out of the control: up in its upper half,
   down in its lower half (issue #7). NSStepper isn't flipped, and the
   theme's chevrons pointed the other way in unflipped views. */
- (void) checkStepper
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(80, 120, 120, 80)
                                     title: @"QuirkProbe Stepper"];
  NSStepper *stepper = AUTORELEASE([[NSStepper alloc] initWithFrame: NSMakeRect(20, 10, 22, 42)]);
  NSBitmapImageRep *rep = nil;
  CGFloat scale;
  NSInteger width, height;
  NSUInteger red, green, blue;
  NSInteger upper, lower;
  NSRect upperArea, lowerArea;

  [[window contentView] addSubview: stepper];
  [window orderFront: nil];
  [window display];

  rep = QuirkProbeRender(stepper);
  scale = QuirkProbeScale(rep, stepper);
  width = [rep pixelsWide];
  height = [rep pixelsHigh];
  [self saveView: stepper named: @"stepper"];

  /* The control's fill, just inside its left edge. */
  QuirkProbePixel(rep, (NSInteger)(3 * scale), height / 4, &red, &green, &blue);
  QuirkProbeInkBackground = red + green + blue;

  /* Each half, less the border and the line between the halves. */
  upperArea = NSMakeRect(3 * scale, 3 * scale, width - 6 * scale, height / 2 - 5 * scale);
  lowerArea = NSMakeRect(3 * scale, height / 2 + 2 * scale, width - 6 * scale, height / 2 - 5 * scale);
  upper = QuirkProbeChevronDirection(rep, upperArea);
  lower = QuirkProbeChevronDirection(rep, lowerArea);

  if (upper == 1 && lower == -1)
    {
      [self pass: @"stepper-chevrons-point-out" detail: @"up in the upper half, down in the lower"];
    }
  else
    {
      [self fail: @"stepper-chevrons-point-out" detail:
        [NSString stringWithFormat: @"upper half points %@, lower half %@",
                                    upper == 1 ? @"up" : (upper == -1 ? @"down" : @"nowhere"),
                                    lower == 1 ? @"up" : (lower == -1 ? @"down" : @"nowhere")]];
    }
}

/* A default button's title is readable on its fill (issue #53). NSAlert
   makes its buttons with -init, which leaves no bezel style; the theme
   drew those with GNUstep's white bezel but the default button's white
   title. Checks one made that way with a Return key equivalent, and one
   made default with -setDefaultButtonCell:. */
- (void) checkDefaultButtons
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(420, 120, 300, 80)
                                     title: @"QuirkProbe Default Buttons"];
  NSButton *alertStyle = AUTORELEASE([[NSButton alloc] initWithFrame: NSMakeRect(20, 20, 100, 32)]);
  NSButton *windowDefault = AUTORELEASE([[NSButton alloc] initWithFrame: NSMakeRect(160, 20, 100, 32)]);
  NSArray *buttons = [NSArray arrayWithObjects: alertStyle, windowDefault, nil];
  NSArray *names = [NSArray arrayWithObjects: @"alert-style", @"window-default", nil];
  NSMutableArray *unreadable = [NSMutableArray array];
  NSUInteger index;

  [alertStyle setButtonType: NSMomentaryPushInButton];
  [alertStyle setTitle: @"OK"];
  [alertStyle setKeyEquivalent: @"\r"];
  [windowDefault setButtonType: NSMomentaryPushInButton];
  [windowDefault setTitle: @"OK"];
  [[window contentView] addSubview: alertStyle];
  [[window contentView] addSubview: windowDefault];
  [window setDefaultButtonCell: [windowDefault cell]];
  [window orderFront: nil];
  [window display];

  for (index = 0; index < [buttons count]; index++)
    {
      NSButton *button = [buttons objectAtIndex: index];
      NSString *name = [names objectAtIndex: index];
      NSBitmapImageRep *rep = QuirkProbeRender(button);
      CGFloat scale = QuirkProbeScale(rep, button);
      NSInteger width = [rep pixelsWide];
      NSInteger height = [rep pixelsHigh];
      NSUInteger red, green, blue;
      QuirkProbeInk ink;

      [self saveView: button named: [@"default-button-" stringByAppendingString: name]];
      /* The fill, inside the left edge, then the title's ink against it,
         away from the border. */
      QuirkProbePixel(rep, (NSInteger)(8 * scale), height / 2, &red, &green, &blue);
      QuirkProbeInkBackground = red + green + blue;
      ink = QuirkProbeMeasureIn(rep, QuirkProbeIsInk,
                                NSMakeRect(6 * scale, 6 * scale,
                                           width - 12 * scale, height - 12 * scale));
      if (ink.count < 20)
        {
          [unreadable addObject: [NSString stringWithFormat: @"%@ (%lu px of title)",
                                                             name, (unsigned long)ink.count]];
        }
    }

  if ([unreadable count] == 0)
    {
      [self pass: @"default-button-title-readable" detail:
        @"default buttons' titles stand out from their fill"];
    }
  else
    {
      [self fail: @"default-button-title-readable" detail:
        [@"unreadable: " stringByAppendingString: [unreadable componentsJoinedByString: @", "]]];
    }
}

/* Fires while a pop-up button's menu is tracking: notes whether it's
   showing, then clicks well away from it, which should close it. */
- (void) inspectPopUpMenu: (NSTimer *)timer
{
  NSPopUpButton *popUp = [timer userInfo];
  NSWindow *window = [popUp window];
  NSWindow *menuWindow = [[[popUp menu] menuRepresentation] window];
  NSPoint away = NSMakePoint(NSWidth([window frame]) - 20, 20);
  NSEvent *down = [NSEvent mouseEventWithType: NSLeftMouseDown location: away modifierFlags: 0
                                    timestamp: 0 windowNumber: [window windowNumber] context: nil
                                  eventNumber: 0 clickCount: 1 pressure: 1];
  NSEvent *up = [NSEvent mouseEventWithType: NSLeftMouseUp location: away modifierFlags: 0
                                  timestamp: 0 windowNumber: [window windowNumber] context: nil
                                eventNumber: 0 clickCount: 1 pressure: 0];

  ASSIGN(QuirkProbeMenuSeen, (menuWindow != nil && [menuWindow isVisible]) ? @"open" : @"closed");
  QuirkProbeSetPointer([window convertBaseToScreen: away]);
  [NSApp postEvent: down atStart: NO];
  [NSApp postEvent: up atStart: NO];
}

/* A click on a pop-up button opens its menu and the menu stays open
   (issue #54): in gui 0.32 the click's release ended menu tracking, so the
   menu closed at once. A click elsewhere closes it and changes nothing.
   Moves the pointer, so only with -ProbeMovesPointer YES. */
- (void) checkPopUpClick
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(420, 300, 340, 160)
                                     title: @"QuirkProbe Pop-up"];
  NSPopUpButton *popUp = AUTORELEASE([[NSPopUpButton alloc] initWithFrame: NSMakeRect(20, 100, 180, 32)
                                                                pullsDown: NO]);
  NSMutableArray *seen = [NSMutableArray array];
  NSString *before = nil;
  NSRect frame;
  NSPoint point;
  NSWindow *menuWindow = nil;
  NSString *detail = nil;
  int i;

  if ([[NSUserDefaults standardUserDefaults] boolForKey: @"ProbeMovesPointer"] == NO)
    {
      [self skip: @"popup-click-stays-open" detail: @"moves the pointer: needs -ProbeMovesPointer YES"];
      return;
    }

  [popUp addItemsWithTitles: [NSArray arrayWithObjects: @"First", @"Second", @"Third", nil]];
  [[window contentView] addSubview: popUp];
  [window makeKeyAndOrderFront: nil];
  [window display];
  before = [popUp titleOfSelectedItem];
  frame = [popUp convertRect: [popUp bounds] toView: nil];
  point = NSMakePoint(NSMidX(frame), NSMidY(frame));

  for (i = 0; i < 3; i++)
    {
      NSEvent *down = [NSEvent mouseEventWithType: NSLeftMouseDown location: point modifierFlags: 0
                                        timestamp: 0 windowNumber: [window windowNumber] context: nil
                                      eventNumber: 0 clickCount: 1 pressure: 1];
      NSEvent *up = [NSEvent mouseEventWithType: NSLeftMouseUp location: point modifierFlags: 0
                                      timestamp: 0 windowNumber: [window windowNumber] context: nil
                                    eventNumber: 0 clickCount: 1 pressure: 0];
      NSTimer *timer = [NSTimer timerWithTimeInterval: 0.3
                                               target: self
                                             selector: @selector(inspectPopUpMenu:)
                                             userInfo: popUp
                                              repeats: NO];

      ASSIGN(QuirkProbeMenuSeen, @"closed");
      QuirkProbeSetPointer([window convertBaseToScreen: point]);
      [[NSRunLoop currentRunLoop] addTimer: timer forMode: NSEventTrackingRunLoopMode];
      /* The release is queued before the press is handled, as with a
         click that's already over when the app gets to it. */
      [NSApp postEvent: up atStart: NO];
      [popUp mouseDown: down];
      [timer invalidate];
      [seen addObject: QuirkProbeMenuSeen];
    }

  menuWindow = [[[popUp menu] menuRepresentation] window];
  detail = [NSString stringWithFormat: @"0.3s after each of 3 clicks: %@; after a click elsewhere: %@, selection %@ -> %@",
                                       [seen componentsJoinedByString: @", "],
                                       [menuWindow isVisible] ? @"showing" : @"closed",
                                       before, [popUp titleOfSelectedItem]];
  if ([seen containsObject: @"closed"] == NO && [menuWindow isVisible] == NO
      && [before isEqualToString: [popUp titleOfSelectedItem]])
    {
      [self pass: @"popup-click-stays-open" detail: detail];
    }
  else
    {
      [self fail: @"popup-click-stays-open" detail: detail];
    }
}

/* Whether the probe runs with `flag` (--mode dark, --high-contrast), as
   the theme reads them. */
static BOOL
QuirkProbeHasArgument(NSString *flag, NSString *value)
{
  NSArray *arguments = [[NSProcessInfo processInfo] arguments];
  NSUInteger index = [arguments indexOfObject: flag];

  if (index == NSNotFound)
    {
      return NO;
    }
  return value == nil
    || (index + 1 < [arguments count]
        && [[[arguments objectAtIndex: index + 1] lowercaseString] isEqualToString: value]);
}

/* Shade `index` of Windows' AccentPalette (0 Light3 ... 3 the accent ...
   6 Dark3), or nil. */
static NSColor *
QuirkProbeSystemAccentShade(NSUInteger index)
{
#ifdef _WIN32
  HKEY key = NULL;
  DWORD type = 0;
  BYTE bytes[32];
  DWORD size = sizeof(bytes);

  if (RegOpenKeyExA(HKEY_CURRENT_USER,
                    "Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Accent",
                    0, KEY_QUERY_VALUE, &key) != ERROR_SUCCESS)
    {
      return nil;
    }
  if (RegQueryValueExA(key, "AccentPalette", NULL, &type, bytes, &size) != ERROR_SUCCESS
      || type != REG_BINARY || size < 28)
    {
      RegCloseKey(key);
      return nil;
    }
  RegCloseKey(key);
  return [NSColor colorWithCalibratedRed: bytes[index * 4] / 255.0
                                   green: bytes[index * 4 + 1] / 255.0
                                    blue: bytes[index * 4 + 2] / 255.0
                                   alpha: 1.0];
#else
  return nil;
#endif
}

static NSString *
QuirkProbeHex(NSColor *color)
{
  NSColor *rgb = [color colorUsingColorSpaceName: NSCalibratedRGBColorSpace];

  if (rgb == nil)
    {
      return @"(none)";
    }
  return [NSString stringWithFormat: @"#%02X%02X%02X",
                                     (int)round([rgb redComponent] * 255),
                                     (int)round([rgb greenComponent] * 255),
                                     (int)round([rgb blueComponent] * 255)];
}

/* The accent (issue #34): Windows' accent palette, filled with its Dark1
   shade in the light palette and Light2 in the dark one, as WinUI's
   AccentFillColorDefault; text on it white, or black in the dark palette.
   The theme read DWM's frame colour and used one shade everywhere. */
- (void) checkAccentColor
{
  BOOL dark = QuirkProbeHasArgument(@"--mode", @"dark");
  NSColorList *colors = [[GSTheme theme] colors];
  NSColor *accent = [colors colorWithKey: @"accentColor"];
  NSColor *onAccent = [colors colorWithKey: @"selectedControlTextColor"];
  NSColor *expected = QuirkProbeSystemAccentShade(dark ? 1 : 4);
  NSString *expectedOn = dark ? @"#000000" : @"#FFFFFF";

  if (QuirkProbeHasArgument(@"--high-contrast", nil))
    {
      [self skip: @"accent-shade" detail: @"high contrast uses the contrast theme's colours (#45)"];
      return;
    }
  if (expected == nil)
    {
      [self skip: @"accent-shade" detail: @"no AccentPalette in the registry"];
    }
  else if ([QuirkProbeHex(accent) isEqualToString: QuirkProbeHex(expected)])
    {
      [self pass: @"accent-shade" detail:
        [NSString stringWithFormat: @"%@, the accent's %@ shade", QuirkProbeHex(accent),
                                    dark ? @"Light2" : @"Dark1"]];
    }
  else
    {
      [self fail: @"accent-shade" detail:
        [NSString stringWithFormat: @"%@, expected the accent's %@ shade %@", QuirkProbeHex(accent),
                                    dark ? @"Light2" : @"Dark1", QuirkProbeHex(expected)]];
    }

  if ([QuirkProbeHex(onAccent) isEqualToString: expectedOn])
    {
      [self pass: @"text-on-accent" detail: QuirkProbeHex(onAccent)];
    }
  else
    {
      [self fail: @"text-on-accent" detail:
        [NSString stringWithFormat: @"%@, expected %@", QuirkProbeHex(onAccent), expectedOn]];
    }
}

/* The panel of an NSAlert, laid out without running it. */
static NSPanel *
QuirkProbeAlertPanel(NSAlert *alert)
{
  NSPanel *panel = nil;

  [alert performSelector: @selector(_setupPanel)];
  panel = [alert window];
  if ([panel respondsToSelector: @selector(sizePanelToFit)])
    {
      [panel performSelector: @selector(sizePanelToFit)];
    }
  return panel;
}

/* Alerts as WinUI's ContentDialog (issue #23): within its 320-548pt
   widths, no icon, the title left-aligned at the 24pt padding, and 32pt
   buttons of equal width with the primary one first (Save, Don't Save,
   Cancel), a lone button in the right half. */
- (void) checkAlertLayout
{
  NSAlert *alert = AUTORELEASE([NSAlert new]);
  NSAlert *single = AUTORELEASE([NSAlert new]);
  NSPanel *panel = nil;
  NSPanel *singlePanel = nil;
  NSMutableArray *problems = [NSMutableArray array];
  NSButton *save, *cancel, *dontSave, *ok;
  NSTextField *titleField = nil;
  NSButton *icon = nil;
  CGFloat width;

  [alert setMessageText: @"Save changes to \"Notes\"?"];
  [alert setInformativeText: @"Your changes will be lost if you don't save them."];
  save = [alert addButtonWithTitle: @"Save"];
  cancel = [alert addButtonWithTitle: @"Cancel"];
  dontSave = [alert addButtonWithTitle: @"Don't Save"];
  panel = QuirkProbeAlertPanel(alert);
  if (panel == nil)
    {
      [self skip: @"alert-content-dialog" detail: @"NSAlert made no panel"];
      return;
    }
  [single setMessageText: @"Done"];
  [single setInformativeText: @"The file was exported."];
  [single addButtonWithTitle: @"OK"];
  singlePanel = QuirkProbeAlertPanel(single);

  /* The panel's buttons are copies of the alert's, matched by title. */
  {
    NSEnumerator *enumerator = [[[panel contentView] subviews] objectEnumerator];
    NSView *view = nil;

    while ((view = [enumerator nextObject]) != nil)
      {
        if ([view isKindOfClass: [NSButton class]] && [view isHidden] == NO)
          {
            NSString *title = [(NSButton *)view title];

            if ([title isEqualToString: @"Save"]) save = (NSButton *)view;
            else if ([title isEqualToString: @"Cancel"]) cancel = (NSButton *)view;
            else if ([title isEqualToString: @"Don't Save"]) dontSave = (NSButton *)view;
          }
      }
    enumerator = [[[singlePanel contentView] subviews] objectEnumerator];
    ok = nil;
    while ((view = [enumerator nextObject]) != nil)
      {
        if ([view isKindOfClass: [NSButton class]] && [[(NSButton *)view title] isEqualToString: @"OK"])
          {
            ok = (NSButton *)view;
          }
      }
  }
  titleField = [panel valueForKey: @"titleField"];
  icon = [panel valueForKey: @"icoButton"];
  width = NSWidth([[panel contentView] bounds]);

  if (width < 320.0 || width > 548.0)
    {
      [problems addObject: [NSString stringWithFormat: @"%.0fpt wide", width]];
    }
  if (icon != nil && [icon superview] != nil && [icon isHidden] == NO)
    {
      [problems addObject: @"the icon shows"];
    }
  if (titleField == nil || fabs(NSMinX([titleField frame]) - 22.0) > 2.0
      || [titleField alignment] != NSLeftTextAlignment)
    {
      [problems addObject: [NSString stringWithFormat: @"title at x=%.0f, not left-aligned at 22",
                                                      NSMinX([titleField frame])]];
    }
  if (!(NSMinX([save frame]) < NSMinX([dontSave frame])
        && NSMinX([dontSave frame]) < NSMinX([cancel frame])))
    {
      [problems addObject: [NSString stringWithFormat: @"button order Save x=%.0f, Don't Save x=%.0f, Cancel x=%.0f",
                                                      NSMinX([save frame]), NSMinX([dontSave frame]),
                                                      NSMinX([cancel frame])]];
    }
  if (fabs(NSHeight([save frame]) - 32.0) > 0.5
      || fabs(NSWidth([save frame]) - NSWidth([dontSave frame])) > 1.5)
    {
      [problems addObject: [NSString stringWithFormat: @"buttons %.0fx%.0f and %.0fx%.0f",
                                                      NSWidth([save frame]), NSHeight([save frame]),
                                                      NSWidth([dontSave frame]), NSHeight([dontSave frame])]];
    }
  if (ok == nil || NSMinX([ok frame]) < NSWidth([[singlePanel contentView] bounds]) / 2.0 - 1.0)
    {
      [problems addObject: [NSString stringWithFormat: @"a lone OK at x=%.0f, not in the right half",
                                                      NSMinX([ok frame])]];
    }

  [self saveView: [panel contentView] named: @"alert"];
  if ([problems count] == 0)
    {
      [self pass: @"alert-content-dialog" detail:
        [NSString stringWithFormat: @"%.0fpt wide, Save | Don't Save | Cancel, 32pt buttons", width]];
    }
  else
    {
      [self fail: @"alert-content-dialog" detail: [problems componentsJoinedByString: @"; "]];
    }
}

/* A 20x20 black square named "...Template", as Cocoa apps ship
   template icons. */
static NSImage *
QuirkProbeTemplateSquare(void)
{
  NSImage *image = [NSImage imageNamed: @"ProbeSquareTemplate"];

  if (image != nil)
    {
      return image;
    }
  image = AUTORELEASE([[NSImage alloc] initWithSize: NSMakeSize(20, 20)]);
  [image lockFocus];
  [[NSColor blackColor] set];
  NSRectFill(NSMakeRect(0, 0, 20, 20));
  [image unlockFocus];
  [image setName: @"ProbeSquareTemplate"];
  return image;
}

/* Whether the pixel at the centre of `view`'s render is within `slack`
   (summed over the channels, 0-765) of `color`. */
static BOOL
QuirkProbeCentreIs(NSView *view, NSColor *color, NSUInteger slack, NSString **seen)
{
  NSBitmapImageRep *rep = QuirkProbeRender(view);
  NSColor *rgb = [color colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
  NSUInteger red, green, blue;
  NSInteger difference;

  if (QuirkProbePixel(rep, [rep pixelsWide] / 2, [rep pixelsHigh] / 2, &red, &green, &blue) == NO
      || rgb == nil)
    {
      return NO;
    }
  *seen = [NSString stringWithFormat: @"#%02lX%02lX%02lX",
                                      (unsigned long)red, (unsigned long)green, (unsigned long)blue];
  difference = llabs((long long)red - (NSInteger)round([rgb redComponent] * 255))
    + llabs((long long)green - (NSInteger)round([rgb greenComponent] * 255))
    + llabs((long long)blue - (NSInteger)round([rgb blueComponent] * 255));
  return difference <= (NSInteger)slack;
}

/* Template images follow the text colour around them (issue #25): a black
   "...Template" image draws in the text colour in a button and a segment,
   and in the text-on-accent colour on a default button, in every palette. */
- (void) checkTemplateImages
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(780, 700, 300, 80)
                                     title: @"QuirkProbe Template Images"];
  NSColorList *colors = [[GSTheme theme] colors];
  NSColor *text = [colors colorWithKey: @"labelColor"];
  NSColor *onAccent = [colors colorWithKey: @"selectedControlTextColor"];
  NSButton *plain = AUTORELEASE([[NSButton alloc] initWithFrame: NSMakeRect(10, 20, 60, 40)]);
  NSButton *primary = AUTORELEASE([[NSButton alloc] initWithFrame: NSMakeRect(80, 20, 60, 40)]);
  NSSegmentedControl *segments = AUTORELEASE([[NSSegmentedControl alloc]
                                               initWithFrame: NSMakeRect(150, 20, 120, 40)]);
  NSMutableArray *wrong = [NSMutableArray array];
  NSString *seen = nil;
  NSView *segmentView = nil;

  [plain setBezelStyle: NSRoundedBezelStyle];
  [plain setImage: QuirkProbeTemplateSquare()];
  [plain setImagePosition: NSImageOnly];
  [primary setBezelStyle: NSRoundedBezelStyle];
  [primary setImage: QuirkProbeTemplateSquare()];
  [primary setImagePosition: NSImageOnly];
  [primary setKeyEquivalent: @"\r"];
  [segments setSegmentCount: 1];
  [segments setImage: QuirkProbeTemplateSquare() forSegment: 0];
  [segments setWidth: 118 forSegment: 0];
  [[window contentView] addSubview: plain];
  [[window contentView] addSubview: primary];
  [[window contentView] addSubview: segments];
  [window orderFront: nil];
  [window display];
  segmentView = segments;

  if (QuirkProbeCentreIs(plain, text, 60, &seen) == NO)
    {
      [wrong addObject: [NSString stringWithFormat: @"button %@ (text is %@)", seen, QuirkProbeHex(text)]];
    }
  if (QuirkProbeCentreIs(primary, onAccent, 60, &seen) == NO)
    {
      [wrong addObject: [NSString stringWithFormat: @"default button %@ (text on accent is %@)",
                                                    seen, QuirkProbeHex(onAccent)]];
    }
  if (QuirkProbeCentreIs(segmentView, text, 60, &seen) == NO)
    {
      [wrong addObject: [NSString stringWithFormat: @"segment %@ (text is %@)", seen, QuirkProbeHex(text)]];
    }

  [self saveView: [window contentView] named: @"template-images"];
  if ([wrong count] == 0)
    {
      [self pass: @"template-images" detail: @"template images take the text colour around them"];
    }
  else
    {
      [self fail: @"template-images" detail: [wrong componentsJoinedByString: @"; "]];
    }
}

/* A window created after launch gets the main menu (issue #1). libs-gui
   only attaches the Windows 95 style menu to windows that exist when it
   first updates the menu. */
- (void) createLateWindow: (NSTimer *)timer
{
  _lateWindow = [self windowWithFrame: NSMakeRect(480, 560, 300, 100)
                                title: @"QuirkProbe Late Window"];
  [_lateWindow makeKeyAndOrderFront: nil];
  /* Without the desktop's focus the window may not become key; the main
     window is GNUstep's own state either way. */
  [_lateWindow makeMainWindow];
  [self after: QuirkProbeSettleDelay perform: @selector(checkLateWindow:)];
}

/* Handles the events that arrive in the next `seconds`, as the app's
   run loop would: the probe runs inside one event. */
static void
QuirkProbeDispatchEvents(NSTimeInterval seconds)
{
  NSDate *until = [NSDate dateWithTimeIntervalSinceNow: seconds];
  NSEvent *event = nil;

  while ((event = [NSApp nextEventMatchingMask: NSAnyEventMask
                                     untilDate: until
                                        inMode: NSDefaultRunLoopMode
                                       dequeue: YES]) != nil)
    {
      [NSApp sendEvent: event];
    }
}

/* The sum of red, green and blue at (x, y) points from the top left. */
static NSInteger
QuirkProbeBrightnessAt(NSBitmapImageRep *rep, CGFloat scale, CGFloat x, CGFloat y)
{
  NSUInteger red, green, blue;

  QuirkProbePixel(rep, (NSInteger)(x * scale), (NSInteger)(y * scale), &red, &green, &blue);
  return (NSInteger)(red + green + blue);
}

/* WinUI's Button (issues #38, #10, #35): a flat fill, without the gloss
   over its top half; 4pt corners; a title that doesn't move when pressed;
   and a lighter fill under the pointer (only with -ProbeMovesPointer YES). */
- (void) checkButtonChrome
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(420, 460, 300, 80)
                                     title: @"QuirkProbe Button Chrome"];
  NSButton *button = AUTORELEASE([[NSButton alloc] initWithFrame: NSMakeRect(20, 20, 120, 32)]);
  NSButton *other = AUTORELEASE([[NSButton alloc] initWithFrame: NSMakeRect(160, 20, 120, 32)]);
  NSBitmapImageRep *rep = nil;
  CGFloat scale;
  NSInteger height, top, bottom, fill, corner;
  QuirkProbeInk resting, pressed;
  BOOL highContrast = QuirkProbeHasArgument(@"--high-contrast", nil);

  [button setButtonType: NSMomentaryPushInButton];
  [button setBezelStyle: NSRoundedBezelStyle];
  [button setTitle: @"Button"];
  [other setButtonType: NSMomentaryPushInButton];
  [other setBezelStyle: NSRoundedBezelStyle];
  [other setTitle: @"Other"];
  [[window contentView] addSubview: button];
  [[window contentView] addSubview: other];
  [window makeKeyAndOrderFront: nil];
  /* Without a focus ring, which is #36's. */
  [window makeFirstResponder: window];
  [window display];

  rep = QuirkProbeRender(button);
  scale = QuirkProbeScale(rep, button);
  height = NSHeight([button bounds]);
  [self saveView: button named: @"button-chrome"];

  /* The fill left of the title, a third of the way down and up. */
  top = QuirkProbeBrightnessAt(rep, scale, 7, height * 0.3);
  bottom = QuirkProbeBrightnessAt(rep, scale, 7, height * 0.7);
  if (llabs((long long)(top - bottom)) <= 6)
    {
      [self pass: @"button-no-gloss" detail: [NSString stringWithFormat:
        @"the fill is even: %ld at the top, %ld at the bottom (of 765)", (long)top, (long)bottom]];
    }
  else
    {
      [self fail: @"button-no-gloss" detail: [NSString stringWithFormat:
        @"the top is %ld, the bottom %ld (of 765): a gloss", (long)top, (long)bottom]];
    }

  /* 2.5 effective pixels in from the top corner is inside a 4px corner's
     stroke, on a 7px one's or outside it. The theme scales its corners
     with the desktop (--scale here), not the drawing. */
  {
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    NSUInteger index = [arguments indexOfObject: @"--scale"];
    CGFloat desktop = 1.0;

    if (index != NSNotFound && index + 1 < [arguments count])
      {
        desktop = MAX(1.0, [[arguments objectAtIndex: index + 1] doubleValue]);
      }
    fill = QuirkProbeBrightnessAt(rep, scale, 7, height / 2.0);
    corner = QuirkProbeBrightnessAt(rep, scale, 2.5 * desktop, 2.5 * desktop);
  }
  if (llabs((long long)(fill - corner)) <= 12)
    {
      [self pass: @"button-corner-radius" detail: @"the fill reaches 2.5pt from the corner: 4pt corners"];
    }
  else
    {
      [self fail: @"button-corner-radius" detail: [NSString stringWithFormat:
        @"2.5pt from the corner is %ld, the fill %ld (of 765): corners wider than 4pt",
        (long)corner, (long)fill]];
    }

  /* The title's ink, resting and pressed. */
  QuirkProbeInkBackground = fill;
  resting = QuirkProbeMeasureIn(rep, QuirkProbeIsInk,
                                NSMakeRect(10 * scale, 4 * scale,
                                           [rep pixelsWide] - 20 * scale, [rep pixelsHigh] - 8 * scale));
  [button highlight: YES];
  /* -highlight: doesn't redraw, and renders come from the window. */
  [button display];
  rep = QuirkProbeRender(button);
  [self saveView: button named: @"button-chrome-pressed"];
  QuirkProbeInkBackground = QuirkProbeBrightnessAt(rep, scale, 7, height / 2.0);
  pressed = QuirkProbeMeasureIn(rep, QuirkProbeIsInk,
                                NSMakeRect(10 * scale, 4 * scale,
                                           [rep pixelsWide] - 20 * scale, [rep pixelsHigh] - 8 * scale));
  [button highlight: NO];
  [button display];
  if (resting.count < 20 || pressed.count < 20)
    {
      [self fail: @"button-pressed-title-still" detail: [NSString stringWithFormat:
        @"couldn't find the title: %lu px resting, %lu pressed",
        (unsigned long)resting.count, (unsigned long)pressed.count]];
    }
  else
    {
      /* By its ink's centre: a pressed title's lighter colour can trim a
         pixel of antialiasing from each side. */
      CGFloat dx = (pressed.minX + pressed.width / 2.0) - (resting.minX + resting.width / 2.0);
      CGFloat dy = (pressed.minY + pressed.height / 2.0) - (resting.minY + resting.height / 2.0);

      if (fabs(dx) < 1.0 && fabs(dy) < 1.0)
        {
          [self pass: @"button-pressed-title-still" detail: @"the title stays put when pressed"];
        }
      else
        {
          [self fail: @"button-pressed-title-still" detail: [NSString stringWithFormat:
            @"the title moves (%.1f, %.1f) px when pressed", dx, dy]];
        }
    }

  if ([[NSUserDefaults standardUserDefaults] boolForKey: @"ProbeMovesPointer"] == NO)
    {
      [self skip: @"button-hover" detail: @"moves the pointer: needs -ProbeMovesPointer YES"];
    }
  else if (highContrast)
    {
      [self skip: @"button-hover" detail: @"high contrast has no pointer-over fill"];
    }
  else
    {
      NSRect frame = [button convertRect: [button bounds] toView: nil];
      NSRect away = [other convertRect: [other bounds] toView: nil];
      NSInteger over;

      QuirkProbeSetPointer([window convertBaseToScreen:
        NSMakePoint(NSMinX(away) + 6, NSMidY(away))]);
      QuirkProbeDispatchEvents(0.3);
      QuirkProbeSetPointer([window convertBaseToScreen:
        NSMakePoint(NSMinX(frame) + 6, NSMidY(frame))]);
      QuirkProbeDispatchEvents(0.3);
      rep = QuirkProbeRender(button);
      over = QuirkProbeBrightnessAt(rep, scale, 7, height * 0.3);
      QuirkProbeSetPointer([window convertBaseToScreen:
        NSMakePoint(NSMinX(away) + 6, NSMidY(away))]);
      QuirkProbeDispatchEvents(0.3);
      if (over != top)
        {
          [self pass: @"button-hover" detail: [NSString stringWithFormat:
            @"the fill is %ld under the pointer, %ld at rest (of 765)", (long)over, (long)top]];
        }
      else
        {
          [self fail: @"button-hover" detail: @"the fill doesn't change under the pointer"];
        }
    }
  [window orderOut: nil];
}

/* The top and bottom pixel rows of item `index` in a render of `view`. */
static void
QuirkProbeMenuRows(NSMenuView *view, NSBitmapImageRep *rep, NSInteger index,
                   NSInteger *top, NSInteger *bottom)
{
  NSRect rect = [view rectOfItemAtIndex: index];
  CGFloat scale = QuirkProbeScale(rep, view);
  CGFloat height = NSHeight([view bounds]);
  CGFloat minY = [view isFlipped] ? NSMinY(rect) : height - NSMaxY(rect);

  *top = (NSInteger)ceil(minY * scale);
  *bottom = (NSInteger)floor((minY + NSHeight(rect)) * scale) - 1;
}

/* WinUI's MenuFlyout (issue #39): an item under the pointer has a neutral
   SubtleFill, not a blue selection; a shortcut sits 24pt clear of the
   longest title, in the secondary text colour; separators run the
   flyout's width. */
- (void) checkMenuFlyout
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(780, 300, 360, 200)
                                     title: @"QuirkProbe Menu"];
  NSMenu *menu = AUTORELEASE([[NSMenu alloc] initWithTitle: @"Probe"]);
  NSMenuView *view = nil;
  NSBitmapImageRep *rep = nil;
  NSInteger width, top, bottom, x, y, middle;
  NSUInteger background, red, green, blue;
  NSInteger firstInk = -1, lastInk = -1, gap = 0, run = 0, titleEnd = -1, keyStart = -1;
  NSUInteger titleDarkest = 765, keyDarkest = 765;
  BOOL highContrast = QuirkProbeHasArgument(@"--high-contrast", nil);
  CGFloat scale;

  [menu setAutoenablesItems: NO];
  [menu addItemWithTitle: @"Find in Document" action: @selector(terminate:) keyEquivalent: @"f"];
  [menu addItem: [NSMenuItem separatorItem]];
  [menu addItemWithTitle: @"Open" action: @selector(terminate:) keyEquivalent: @"o"];
  view = AUTORELEASE([[NSMenuView alloc] initWithFrame: NSMakeRect(20, 20, 100, 100)]);
  [view setMenu: menu];
  [view sizeToFit];
  [view setFrameOrigin: NSMakePoint(20, 20)];
  [[window contentView] addSubview: view];
  [window orderFront: nil];
  [view setHighlightedItemIndex: 2];
  [window display];

  rep = QuirkProbeRender(view);
  scale = QuirkProbeScale(rep, view);
  width = [rep pixelsWide];
  [self saveView: view named: @"menu-flyout"];

  /* The background, from the separator's row away from its line. */
  QuirkProbeMenuRows(view, rep, 1, &top, &bottom);
  QuirkProbePixel(rep, width / 2, top, &red, &green, &blue);
  background = red + green + blue;

  /* The separator runs from edge to edge, inside the border. */
  middle = -1;
  for (y = top; y <= bottom && middle < 0; y++)
    {
      QuirkProbePixel(rep, width / 2, y, &red, &green, &blue);
      if (llabs((long long)(red + green + blue) - (long long)background) >= 9)
        {
          middle = y;
        }
    }
  if (middle < 0)
    {
      [self fail: @"menu-separator-width" detail: @"couldn't find the separator"];
    }
  else
    {
      NSInteger left = 0, right = 0;

      while (left < width / 2)
        {
          QuirkProbePixel(rep, left, middle, &red, &green, &blue);
          if (llabs((long long)(red + green + blue) - (long long)background) >= 9 && left >= 1)
            {
              break;
            }
          left++;
        }
      while (right < width / 2)
        {
          QuirkProbePixel(rep, width - 1 - right, middle, &red, &green, &blue);
          if (llabs((long long)(red + green + blue) - (long long)background) >= 9 && right >= 1)
            {
              break;
            }
          right++;
        }
      if (left <= 2 * scale && right <= 2 * scale)
        {
          [self pass: @"menu-separator-width" detail: @"the separator runs the flyout's width"];
        }
      else
        {
          [self fail: @"menu-separator-width" detail: [NSString stringWithFormat:
            @"the separator stops %ld px from the left and %ld from the right", (long)left, (long)right]];
        }
    }

  /* The highlighted item's fill, inside its left end. */
  QuirkProbeMenuRows(view, rep, 2, &top, &bottom);
  QuirkProbePixel(rep, (NSInteger)(6 * scale), (top + bottom) / 2, &red, &green, &blue);
  if (highContrast)
    {
      [self skip: @"menu-hover-fill" detail: @"high contrast keeps the system highlight"];
    }
  else if (llabs((long long)blue - (long long)red) <= 6
           && llabs((long long)(red + green + blue) - (long long)background) >= 6)
    {
      [self pass: @"menu-hover-fill" detail: [NSString stringWithFormat:
        @"the item under the pointer is a neutral %lu,%lu,%lu", (unsigned long)red,
        (unsigned long)green, (unsigned long)blue]];
    }
  else
    {
      [self fail: @"menu-hover-fill" detail: [NSString stringWithFormat:
        @"the item under the pointer is %lu,%lu,%lu over %lu: not WinUI's subtle fill",
        (unsigned long)red, (unsigned long)green, (unsigned long)blue, (unsigned long)background]];
    }

  /* The first row: its title, a gap, its shortcut. A column has ink if any
     pixel in the row's middle half differs from the background. */
  QuirkProbeMenuRows(view, rep, 0, &top, &bottom);
  for (x = (NSInteger)(2 * scale); x < width - (NSInteger)(2 * scale); x++)
    {
      BOOL ink = NO;
      for (y = top + (bottom - top) / 4; y <= bottom - (bottom - top) / 4; y++)
        {
          NSUInteger sum;

          QuirkProbePixel(rep, x, y, &red, &green, &blue);
          sum = red + green + blue;
          if (llabs((long long)sum - (long long)background) > 90)
            {
              ink = YES;
            }
        }
      if (ink)
        {
          if (firstInk < 0)
            {
              firstInk = x;
            }
          if (run > gap && firstInk >= 0 && x - run > firstInk)
            {
              gap = run;
              titleEnd = x - run;
              keyStart = x;
            }
          run = 0;
          lastInk = x;
        }
      else if (firstInk >= 0)
        {
          run++;
        }
    }
  if (titleEnd < 0 || keyStart < 0)
    {
      [self fail: @"menu-shortcut-gap" detail: @"couldn't find the title and shortcut"];
      [self fail: @"menu-shortcut-colour" detail: @"couldn't find the title and shortcut"];
    }
  else
    {
      if (gap >= 20 * scale)
        {
          [self pass: @"menu-shortcut-gap" detail: [NSString stringWithFormat:
            @"%ld px between the longest title and its shortcut", (long)gap]];
        }
      else
        {
          [self fail: @"menu-shortcut-gap" detail: [NSString stringWithFormat:
            @"%ld px between the longest title and its shortcut, WinUI has 24pt", (long)gap]];
        }

      /* The strongest ink of each: secondary text is fainter. */
      for (x = firstInk; x <= lastInk; x++)
        {
          for (y = top; y <= bottom; y++)
            {
              NSUInteger sum, contrast;

              QuirkProbePixel(rep, x, y, &red, &green, &blue);
              sum = red + green + blue;
              contrast = (NSUInteger)llabs((long long)sum - (long long)background);
              if (x < titleEnd)
                {
                  titleDarkest = (titleDarkest == 765) ? contrast : MAX(titleDarkest, contrast);
                }
              else if (x >= keyStart)
                {
                  keyDarkest = (keyDarkest == 765) ? contrast : MAX(keyDarkest, contrast);
                }
            }
        }
      if (highContrast)
        {
          [self skip: @"menu-shortcut-colour" detail: @"high contrast has one text colour"];
        }
      else if (keyDarkest + 60 <= titleDarkest)
        {
          [self pass: @"menu-shortcut-colour" detail: [NSString stringWithFormat:
            @"the shortcut's contrast is %lu, the title's %lu (of 765)",
            (unsigned long)keyDarkest, (unsigned long)titleDarkest]];
        }
      else
        {
          [self fail: @"menu-shortcut-colour" detail: [NSString stringWithFormat:
            @"the shortcut's contrast is %lu, the title's %lu (of 765): not secondary text",
            (unsigned long)keyDarkest, (unsigned long)titleDarkest]];
        }
    }
  /* The view doesn't retain its menu: let both go together. */
  [view removeFromSuperview];
  [window orderOut: nil];
}

/* The sum of red, green and blue down the middle of a scroll view's
   vertical scroller strip, `inset` px in from its trailing edge, that
   differ from `fill` by more than 30: how much of the scroll bar shows. */
static NSUInteger
QuirkProbeStripInk(NSScrollView *scrollView, NSUInteger fill, CGFloat inset)
{
  NSBitmapImageRep *rep = QuirkProbeRender(scrollView);
  CGFloat scale = QuirkProbeScale(rep, scrollView);
  NSRect strip = [[scrollView verticalScroller] frame];
  NSInteger x = (NSInteger)((NSMaxX(strip) - inset) * scale);
  NSInteger y;
  NSUInteger ink = 0;

  for (y = [rep pixelsHigh] / 4; y < 3 * [rep pixelsHigh] / 4; y++)
    {
      NSUInteger red, green, blue;

      QuirkProbePixel(rep, x, y, &red, &green, &blue);
      if (llabs((long long)(red + green + blue) - (long long)fill) > 30)
        {
          ink++;
        }
    }
  return ink;
}

/* A scroll view with only a horizontal scroller keeps it above the
   content, which overlay scroll bars run under (issue #29). Re-raised
   "below the vertical scroller" when there was none, it went under the
   clip view, unseen and unclickable. It's re-raised once something else
   is above it, as here. */
- (void) checkHorizontalOnlyScroller
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSWindow *window = [self windowWithFrame: NSMakeRect(80, 360, 260, 200)
                                     title: @"QuirkProbe Horizontal Scroller"];
  NSScrollView *scrollView = AUTORELEASE([[NSScrollView alloc] initWithFrame: NSMakeRect(20, 20, 200, 150)]);
  NSView *document = AUTORELEASE([[NSView alloc] initWithFrame: NSMakeRect(0, 0, 600, 140)]);
  NSView *above = AUTORELEASE([[NSView alloc] initWithFrame: NSMakeRect(0, 0, 10, 10)]);
  NSArray *subviews = nil;
  NSUInteger clip, scroller;

  if (QuirkProbeHasArgument(@"--high-contrast", nil))
    {
      [self skip: @"scroller-horizontal-only-above" detail: @"high contrast keeps classic scroll bars"];
      return;
    }
  /* Whatever the Windows setting here. */
  [defaults setBool: YES forKey: @"WinUIThemeOverlayScrollbars"];
  [scrollView setHasHorizontalScroller: YES];
  [scrollView setHasVerticalScroller: NO];
  [scrollView setDocumentView: document];
  [[window contentView] addSubview: scrollView];
  [window orderFront: nil];
  [scrollView tile];
  [scrollView addSubview: above];
  [scrollView tile];
  subviews = [scrollView subviews];
  [defaults removeObjectForKey: @"WinUIThemeOverlayScrollbars"];
  clip = [subviews indexOfObjectIdenticalTo: [scrollView contentView]];
  scroller = [subviews indexOfObjectIdenticalTo: [scrollView horizontalScroller]];
  if (scroller != NSNotFound && clip != NSNotFound && scroller > clip)
    {
      [self pass: @"scroller-horizontal-only-above" detail: @"a lone horizontal scroller sits above the content"];
    }
  else
    {
      [self fail: @"scroller-horizontal-only-above" detail: [NSString stringWithFormat:
        @"the horizontal scroller is subview %ld, the clip view %ld: under the content",
        (long)scroller, (long)clip]];
    }
  [window orderOut: nil];
}

/* WinUI's ScrollBar (issue #29): the content runs under the scroll bar,
   which shows nothing at rest, a thin indicator while the content
   scrolls, then fades; WinUIThemeOverlayScrollbars NO keeps a classic
   strip; and freeing a scroll view while its indicator fades is safe. */
- (void) checkOverlayScrollers
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSWindow *window = nil;
  NSScrollView *scrollView = nil;
  QuirkProbeFillView *document = nil;
  NSRect clip, strip;
  NSUInteger fill = 3 * 128;
  NSUInteger ink;

  if (QuirkProbeHasArgument(@"--high-contrast", nil))
    {
      [self skip: @"scroller-content-under" detail: @"high contrast keeps classic scroll bars"];
      [self skip: @"scroller-hidden-at-rest" detail: @"high contrast keeps classic scroll bars"];
      [self skip: @"scroller-indicator-fades" detail: @"high contrast keeps classic scroll bars"];
      [self skip: @"scroller-classic-setting" detail: @"high contrast keeps classic scroll bars"];
      [self skip: @"scroller-freed-mid-fade" detail: @"high contrast keeps classic scroll bars"];
      return;
    }

  /* Whatever the Windows setting here. */
  [defaults setBool: YES forKey: @"WinUIThemeOverlayScrollbars"];
  window = [self windowWithFrame: NSMakeRect(80, 360, 260, 200) title: @"QuirkProbe Scrollers"];
  scrollView = AUTORELEASE([[NSScrollView alloc] initWithFrame: NSMakeRect(20, 20, 200, 150)]);
  /* As wide as the scroll view, as a table or text view tracks it. */
  document = AUTORELEASE([[QuirkProbeFillView alloc] initWithFrame: NSMakeRect(0, 0, 200, 600)]);
  [document setAutoresizingMask: NSViewWidthSizable];
  [scrollView setBorderType: NSBezelBorder];
  [scrollView setHasVerticalScroller: YES];
  [scrollView setDocumentView: document];
  [[window contentView] addSubview: scrollView];
  [window orderFront: nil];
  [scrollView tile];
  [window display];

  clip = [[scrollView contentView] frame];
  strip = [[scrollView verticalScroller] frame];
  if (NSMaxX(clip) > NSMidX(strip))
    {
      [self pass: @"scroller-content-under" detail: @"the content runs under the scroll bar"];
    }
  else
    {
      [self fail: @"scroller-content-under" detail: [NSString stringWithFormat:
        @"the content stops at %.0f, the scroll bar at %.0f", NSMaxX(clip), NSMaxX(strip)]];
    }

  [self saveView: scrollView named: @"scroller-rest"];
  ink = QuirkProbeStripInk(scrollView, fill, 3.0) + QuirkProbeStripInk(scrollView, fill, NSWidth(strip) / 2.0);
  if (ink == 0)
    {
      [self pass: @"scroller-hidden-at-rest" detail: @"nothing over the content at rest"];
    }
  else
    {
      [self fail: @"scroller-hidden-at-rest" detail: [NSString stringWithFormat:
        @"%lu px of scroll bar over the content at rest", (unsigned long)ink]];
    }

  [document scrollPoint: NSMakePoint(0, 200)];
  [window display];
  [self saveView: scrollView named: @"scroller-scrolled"];
  ink = QuirkProbeStripInk(scrollView, fill, 4.0);
  QuirkProbeDispatchEvents(1.6);
  [window display];
  [self saveView: scrollView named: @"scroller-faded"];
  if (ink > 0 && QuirkProbeStripInk(scrollView, fill, 4.0) == 0)
    {
      [self pass: @"scroller-indicator-fades" detail: [NSString stringWithFormat:
        @"scrolling shows %lu px of indicator, gone 1.6s later", (unsigned long)ink]];
    }
  else
    {
      [self fail: @"scroller-indicator-fades" detail: [NSString stringWithFormat:
        @"%lu px of indicator while scrolling, %lu px 1.6s later",
        (unsigned long)ink, (unsigned long)QuirkProbeStripInk(scrollView, fill, 4.0)]];
    }

  /* Classic: the content stops at the strip, which is always drawn. */
  [defaults setBool: NO forKey: @"WinUIThemeOverlayScrollbars"];
  [scrollView tile];
  [window display];
  clip = [[scrollView contentView] frame];
  strip = [[scrollView verticalScroller] frame];
  ink = QuirkProbeStripInk(scrollView, fill, NSWidth(strip) / 2.0);
  if (NSMaxX(clip) <= NSMinX(strip) + 0.5 && ink > 0)
    {
      [self pass: @"scroller-classic-setting" detail: @"WinUIThemeOverlayScrollbars NO keeps the strip"];
    }
  else
    {
      [self fail: @"scroller-classic-setting" detail: [NSString stringWithFormat:
        @"with WinUIThemeOverlayScrollbars NO the content stops at %.0f, the strip starts at %.0f, %lu px drawn",
        NSMaxX(clip), NSMinX(strip), (unsigned long)ink]];
    }
  [defaults setBool: YES forKey: @"WinUIThemeOverlayScrollbars"];
  [scrollView removeFromSuperview];

  /* Freed while its indicator fades: the fade timer mustn't touch it. */
  {
    CREATE_AUTORELEASE_POOL(pool);
    NSScrollView *doomed = AUTORELEASE([[NSScrollView alloc] initWithFrame: NSMakeRect(20, 20, 200, 150)]);
    QuirkProbeFillView *content = AUTORELEASE([[QuirkProbeFillView alloc] initWithFrame: NSMakeRect(0, 0, 180, 600)]);

    [doomed setHasVerticalScroller: YES];
    [doomed setDocumentView: content];
    [[window contentView] addSubview: doomed];
    [doomed tile];
    [window display];
    [content scrollPoint: NSMakePoint(0, 200)];
    [doomed removeFromSuperview];
    RELEASE(pool);
  }
  QuirkProbeDispatchEvents(1.6);
  [self pass: @"scroller-freed-mid-fade" detail: @"a scroll view freed while its indicator faded"];

  [defaults removeObjectForKey: @"WinUIThemeOverlayScrollbars"];
  [window orderOut: nil];
}

/* Pixels that differ between two renders of the same size. */
static NSUInteger
QuirkProbeDifferingPixels(NSBitmapImageRep *a, NSBitmapImageRep *b)
{
  NSInteger x, y;
  NSUInteger count = 0;

  if ([a pixelsWide] != [b pixelsWide] || [a pixelsHigh] != [b pixelsHigh])
    {
      return NSUIntegerMax;
    }
  for (y = 0; y < [a pixelsHigh]; y++)
    {
      for (x = 0; x < [a pixelsWide]; x++)
        {
          NSUInteger r1, g1, b1, r2, g2, b2;

          QuirkProbePixel(a, x, y, &r1, &g1, &b1);
          QuirkProbePixel(b, x, y, &r2, &g2, &b2);
          if (llabs((long long)(r1 + g1 + b1) - (long long)(r2 + g2 + b2)) > 6)
            {
              count++;
            }
        }
    }
  return count;
}

/* Sends `window` a press and release of the left button at `point`. */
static void
QuirkProbeClickAt(NSWindow *window, NSPoint point)
{
  NSEvent *down = [NSEvent mouseEventWithType: NSLeftMouseDown location: point modifierFlags: 0
                                    timestamp: 0 windowNumber: [window windowNumber] context: nil
                                  eventNumber: 0 clickCount: 1 pressure: 1];
  NSEvent *up = [NSEvent mouseEventWithType: NSLeftMouseUp location: point modifierFlags: 0
                                  timestamp: 0 windowNumber: [window windowNumber] context: nil
                                eventNumber: 0 clickCount: 1 pressure: 0];

  [NSApp sendEvent: down];
  [NSApp sendEvent: up];
}

/* The brightness 2px left of `view`'s middle, in a render of its window's
   content view: on the ring's outer stroke. */
static NSInteger
QuirkProbeBrightnessLeftOf(NSView *view)
{
  NSView *content = [[view window] contentView];
  NSBitmapImageRep *rep = QuirkProbeRender(content);
  CGFloat scale = QuirkProbeScale(rep, content);
  NSRect frame = [content convertRect: [view bounds] fromView: view];
  CGFloat y = [content isFlipped] ? NSMidY(frame) : NSHeight([content bounds]) - NSMidY(frame);

  return QuirkProbeBrightnessAt(rep, scale, NSMinX(frame) - 2.0, y);
}

/* WinUI's focus visual (issue #36): a control focused by a click shows no
   ring; Tab to the next one shows the double stroke outside it, in the
   text colour rather than the accent; a click clears it. */
- (void) checkFocusVisual
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(420, 620, 300, 80)
                                     title: @"QuirkProbe Focus"];
  NSButton *first = AUTORELEASE([[NSButton alloc] initWithFrame: NSMakeRect(20, 24, 100, 32)]);
  NSButton *second = AUTORELEASE([[NSButton alloc] initWithFrame: NSMakeRect(160, 24, 100, 32)]);
  NSBitmapImageRep *focused, *plain;
  NSUInteger differing;
  NSInteger background, ring, cleared;
  NSEvent *tab = nil;

  [first setButtonType: NSMomentaryPushInButton];
  [first setBezelStyle: NSRoundedBezelStyle];
  [first setTitle: @"First"];
  [second setButtonType: NSMomentaryPushInButton];
  [second setBezelStyle: NSRoundedBezelStyle];
  [second setTitle: @"Second"];
  [first setNextKeyView: second];
  [second setNextKeyView: first];
  [[window contentView] addSubview: first];
  [[window contentView] addSubview: second];
  [window makeKeyAndOrderFront: nil];

  /* Focused, after a press of the pointer: as unfocused. */
  QuirkProbeClickAt(window, NSMakePoint(290, 70));
  [window makeFirstResponder: first];
  [window display];
  focused = RETAIN(QuirkProbeRender(first));
  [window makeFirstResponder: window];
  [window display];
  plain = QuirkProbeRender(first);
  differing = QuirkProbeDifferingPixels(focused, plain);
  RELEASE(focused);
  if (differing == 0)
    {
      [self pass: @"focus-ring-hidden-after-click" detail: @"a button focused by the pointer shows no ring"];
    }
  else
    {
      [self fail: @"focus-ring-hidden-after-click" detail: [NSString stringWithFormat:
        @"a button focused by the pointer differs from an unfocused one in %lu px", (unsigned long)differing]];
    }

  /* Tab: the ring shows outside the next button. */
  [window makeFirstResponder: first];
  [window display];
  background = QuirkProbeBrightnessLeftOf(second);
  tab = [NSEvent keyEventWithType: NSKeyDown location: NSZeroPoint modifierFlags: 0 timestamp: 0
                     windowNumber: [window windowNumber] context: nil characters: @"\t"
      charactersIgnoringModifiers: @"\t" isARepeat: NO keyCode: 0x09];
  [NSApp sendEvent: tab];
  [window display];
  [self saveView: [window contentView] named: @"focus-ring"];
  ring = QuirkProbeBrightnessLeftOf(second);
  if ([window firstResponder] != second)
    {
      [self fail: @"focus-ring-after-keyboard" detail: @"Tab didn't move focus to the next button"];
    }
  else if (llabs((long long)(ring - background)) >= 150)
    {
      [self pass: @"focus-ring-after-keyboard" detail: [NSString stringWithFormat:
        @"after Tab, 2px outside the button is %ld, the background %ld (of 765)", (long)ring, (long)background]];
    }
  else
    {
      [self fail: @"focus-ring-after-keyboard" detail: [NSString stringWithFormat:
        @"after Tab, 2px outside the button is %ld, the background %ld (of 765): no ring",
        (long)ring, (long)background]];
    }

  /* A press of the pointer clears it, margin and all. */
  QuirkProbeClickAt(window, NSMakePoint(290, 70));
  [window display];
  cleared = QuirkProbeBrightnessLeftOf(second);
  if (llabs((long long)(cleared - background)) <= 6)
    {
      [self pass: @"focus-ring-cleared-by-click" detail: @"a press of the pointer clears the ring"];
    }
  else
    {
      [self fail: @"focus-ring-cleared-by-click" detail: [NSString stringWithFormat:
        @"after a click, 2px outside the button is %ld, the background %ld (of 765)",
        (long)cleared, (long)background]];
    }
  [window orderOut: nil];
}

/* WinUI's TextBox (issue #37): filled with ControlFillColorDefault, a
   step off the window rather than the window's own colour; a darker
   bottom edge; focused, a 2px accent underline. */
- (void) checkTextBox
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(780, 620, 300, 100)
                                     title: @"QuirkProbe TextBox"];
  NSTextField *field = AUTORELEASE([[NSTextField alloc] initWithFrame: NSMakeRect(20, 50, 200, 32)]);
  NSTextField *other = AUTORELEASE([[NSTextField alloc] initWithFrame: NSMakeRect(20, 10, 200, 32)]);
  NSBitmapImageRep *rep = nil;
  CGFloat scale;
  NSInteger height, width, fill, window_, edge, bottom, above;
  NSUInteger red, green, blue, red2, green2, blue2;
  BOOL highContrast = QuirkProbeHasArgument(@"--high-contrast", nil);

  [field setStringValue: @""];
  [other setStringValue: @""];
  [[window contentView] addSubview: field];
  [[window contentView] addSubview: other];
  [window makeKeyAndOrderFront: nil];
  [window makeFirstResponder: window];
  [window display];

  rep = QuirkProbeRender(field);
  scale = QuirkProbeScale(rep, field);
  height = [rep pixelsHigh];
  width = [rep pixelsWide];
  [self saveView: field named: @"textbox-rest"];
  fill = QuirkProbeBrightnessAt(rep, scale, 100, NSHeight([field bounds]) / 2.0);
  {
    NSBitmapImageRep *content = QuirkProbeRender([window contentView]);

    window_ = QuirkProbeBrightnessAt(content, QuirkProbeScale(content, [window contentView]), 260, 50);
  }
  QuirkProbePixel(rep, width / 2, height - 1, &red, &green, &blue);
  edge = (NSInteger)(red + green + blue);

  if (highContrast)
    {
      [self skip: @"textbox-fill" detail: @"high contrast fills with the window colour"];
      [self skip: @"textbox-bottom-edge" detail: @"high contrast draws one border colour"];
    }
  else
    {
      /* Light: brighter than the window; dark: a little lighter too. */
      if (fill - window_ >= 9)
        {
          [self pass: @"textbox-fill" detail: [NSString stringWithFormat:
            @"the field is %ld, the window %ld (of 765)", (long)fill, (long)window_]];
        }
      else
        {
          [self fail: @"textbox-fill" detail: [NSString stringWithFormat:
            @"the field is %ld, the window %ld (of 765): not ControlFillColorDefault", (long)fill, (long)window_]];
        }
      if (llabs((long long)(edge - fill)) >= 150)
        {
          [self pass: @"textbox-bottom-edge" detail: [NSString stringWithFormat:
            @"the bottom edge is %ld against a fill of %ld (of 765)", (long)edge, (long)fill]];
        }
      else
        {
          [self fail: @"textbox-bottom-edge" detail: [NSString stringWithFormat:
            @"the bottom edge is %ld against a fill of %ld (of 765): no strong stroke", (long)edge, (long)fill]];
        }
    }

  /* Focused: the two bottom rows are the accent. */
  [window makeFirstResponder: field];
  [window display];
  rep = QuirkProbeRender(field);
  [self saveView: field named: @"textbox-focused"];
  QuirkProbePixel(rep, width / 2, height - 1, &red, &green, &blue);
  QuirkProbePixel(rep, width / 2, height - 2, &red2, &green2, &blue2);
  bottom = (NSInteger)blue - (NSInteger)red;
  above = (NSInteger)blue2 - (NSInteger)red2;
  if (highContrast)
    {
      [self skip: @"textbox-focus-underline" detail: @"high contrast's highlight may not be blue"];
    }
  else if (bottom >= 40 && above >= 40)
    {
      [self pass: @"textbox-focus-underline" detail: @"focused, a 2px accent underline"];
    }
  else
    {
      [self fail: @"textbox-focus-underline" detail: [NSString stringWithFormat:
        @"focused, the bottom rows are %lu,%lu,%lu and %lu,%lu,%lu: no 2px accent underline",
        (unsigned long)red, (unsigned long)green, (unsigned long)blue,
        (unsigned long)red2, (unsigned long)green2, (unsigned long)blue2]];
    }
  [window makeFirstResponder: window];
  [window orderOut: nil];
}

/* Pixels in `area` (pixels, from the top left) that differ from `fill`
   by more than `threshold`, and the strongest difference. */
static NSUInteger
QuirkProbeInkIn(NSBitmapImageRep *rep, NSRect area, NSInteger fill, NSInteger threshold, NSInteger *strongest)
{
  NSInteger x, y;
  NSUInteger count = 0;

  if (strongest != NULL)
    {
      *strongest = 0;
    }
  for (y = (NSInteger)NSMinY(area); y < (NSInteger)NSMaxY(area); y++)
    {
      for (x = (NSInteger)NSMinX(area); x < (NSInteger)NSMaxX(area); x++)
        {
          NSUInteger red, green, blue;
          NSInteger difference;

          QuirkProbePixel(rep, x, y, &red, &green, &blue);
          difference = llabs((long long)(red + green + blue) - (long long)fill);
          if (difference > threshold)
            {
              count++;
            }
          if (strongest != NULL && difference > *strongest)
            {
              *strongest = difference;
            }
        }
    }
  return count;
}

/* WinUI's ComboBox (issues #40, #8): a pop-up button is one box, its title
   in the primary text colour and no divided lane before its chevron; a
   non-editable combo box keeps its value when focused, without a text
   editor (libs-gui's empty field and "..." button). */
- (void) checkComboBoxes
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(780, 100, 300, 120)
                                     title: @"QuirkProbe ComboBox"];
  NSPopUpButton *popUp = AUTORELEASE([[NSPopUpButton alloc] initWithFrame: NSMakeRect(20, 70, 200, 32)
                                                                pullsDown: NO]);
  NSComboBox *combo = AUTORELEASE([[NSComboBox alloc] initWithFrame: NSMakeRect(20, 20, 200, 32)]);
  NSBitmapImageRep *rep = nil;
  CGFloat scale;
  NSInteger width, height, fill, strongest;
  NSUInteger lane;
  BOOL highContrast = QuirkProbeHasArgument(@"--high-contrast", nil);

  [popUp addItemsWithTitles: [NSArray arrayWithObjects: @"A", @"B", nil]];
  [combo addItemsWithObjectValues: [NSArray arrayWithObjects: @"Value", @"Other", nil]];
  [combo setEditable: NO];
  [combo selectItemAtIndex: 0];
  [[window contentView] addSubview: popUp];
  [[window contentView] addSubview: combo];
  [window makeKeyAndOrderFront: nil];
  [window makeFirstResponder: window];
  [window display];

  rep = QuirkProbeRender(popUp);
  scale = QuirkProbeScale(rep, popUp);
  width = [rep pixelsWide];
  height = [rep pixelsHigh];
  [self saveView: popUp named: @"combobox-popup"];
  fill = QuirkProbeBrightnessAt(rep, scale, NSWidth([popUp bounds]) / 2.0, NSHeight([popUp bounds]) / 2.0);

  /* Between the title and the chevron: only the fill. */
  lane = QuirkProbeInkIn(rep, NSMakeRect(width * 0.4, height * 0.2, width * 0.6 - 30 * scale, height * 0.6),
                         fill, 12, NULL);
  if (lane == 0)
    {
      [self pass: @"popup-no-lane" detail: @"one box, nothing between the title and the chevron"];
    }
  else
    {
      [self fail: @"popup-no-lane" detail: [NSString stringWithFormat:
        @"%lu px of lane or divider before the chevron", (unsigned long)lane]];
    }

  /* The title "A": primary text, nearly the full contrast. */
  QuirkProbeInkIn(rep, NSMakeRect(4 * scale, height * 0.2, 40 * scale, height * 0.6), fill, 12, &strongest);
  if (highContrast)
    {
      [self skip: @"popup-title-primary" detail: @"high contrast has one text colour"];
    }
  else if (strongest >= 560)
    {
      [self pass: @"popup-title-primary" detail: [NSString stringWithFormat:
        @"the title's contrast is %ld (of 765)", (long)strongest]];
    }
  else
    {
      [self fail: @"popup-title-primary" detail: [NSString stringWithFormat:
        @"the title's contrast is %ld (of 765): secondary text", (long)strongest]];
    }

  /* Focused, the combo box keeps its value and starts no editor. */
  [window makeFirstResponder: combo];
  [window display];
  rep = QuirkProbeRender(combo);
  [self saveView: combo named: @"combobox-focused"];
  fill = QuirkProbeBrightnessAt(rep, scale, NSWidth([combo bounds]) - 50.0, NSHeight([combo bounds]) / 2.0);
  {
    NSUInteger value = QuirkProbeInkIn(rep, NSMakeRect(4 * scale, [rep pixelsHigh] * 0.2, 60 * scale,
                                                       [rep pixelsHigh] * 0.6), fill, 150, NULL);

    if ([combo currentEditor] == nil && value > 10)
      {
        [self pass: @"combobox-focused-keeps-value" detail: @"focused, it shows its value and no text editor"];
      }
    else
      {
        [self fail: @"combobox-focused-keeps-value" detail: [NSString stringWithFormat:
          @"focused, %@ text editor and %lu px of its value",
          [combo currentEditor] != nil ? @"a" : @"no", (unsigned long)value]];
      }
  }
  [window makeFirstResponder: window];
  [window orderOut: nil];
}

/* WinUI's ListView and TreeView (issues #43, #51): a selected row gets a
   neutral subtle fill and an accent pill at its leading edge, not a blue
   fill; a nested row's chevron sits before its title, not over it. */
- (void) checkListSelection
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(80, 620, 320, 220)
                                     title: @"QuirkProbe Lists"];
  QuirkProbeRows *rows = AUTORELEASE([QuirkProbeRows new]);
  NSTableView *table = AUTORELEASE([[NSTableView alloc] initWithFrame: NSMakeRect(10, 120, 300, 90)]);
  NSOutlineView *outline = AUTORELEASE([[NSOutlineView alloc] initWithFrame: NSMakeRect(10, 10, 300, 100)]);
  NSTableColumn *column = AUTORELEASE([[NSTableColumn alloc] initWithIdentifier: @"name"]);
  NSTableColumn *outlineColumn = AUTORELEASE([[NSTableColumn alloc] initWithIdentifier: @"name"]);
  NSBitmapImageRep *rep = nil;
  CGFloat scale;
  NSRect row;
  NSInteger y, x, background, fill, pill;
  NSUInteger red, green, blue;
  BOOL highContrast = QuirkProbeHasArgument(@"--high-contrast", nil);

  [column setWidth: 280];
  [table addTableColumn: column];
  [table setHeaderView: nil];
  [table setDataSource: rows];
  [table setUsesAlternatingRowBackgroundColors: NO];
  [outlineColumn setWidth: 280];
  [outline addTableColumn: outlineColumn];
  [outline setOutlineTableColumn: outlineColumn];
  [outline setHeaderView: nil];
  [outline setDataSource: rows];
  [[window contentView] addSubview: table];
  [[window contentView] addSubview: outline];
  [window makeKeyAndOrderFront: nil];
  [table reloadData];
  [table selectRowIndexes: [NSIndexSet indexSetWithIndex: 1] byExtendingSelection: NO];
  [outline reloadData];
  [outline expandItem: @"Parent"];
  [window display];

  /* The selected row: neutral fill at its middle, the pill at its edge. */
  rep = QuirkProbeRender(table);
  scale = QuirkProbeScale(rep, table);
  [self saveView: table named: @"list-selection"];
  row = [table rectOfRow: 1];
  y = [table isFlipped] ? NSMidY(row) : NSHeight([table bounds]) - NSMidY(row);
  background = QuirkProbeBrightnessAt(rep, scale, 200, [table isFlipped] ? NSMidY([table rectOfRow: 0])
                                                                       : NSHeight([table bounds]) - NSMidY([table rectOfRow: 0]));
  QuirkProbePixel(rep, (NSInteger)(200 * scale), (NSInteger)(y * scale), &red, &green, &blue);
  fill = (NSInteger)(red + green + blue);
  {
    NSUInteger pillRed, pillGreen, pillBlue;

    QuirkProbePixel(rep, (NSInteger)((NSMinX(row) + 5.0) * scale), (NSInteger)(y * scale),
                    &pillRed, &pillGreen, &pillBlue);
    pill = (NSInteger)(pillRed + pillGreen + pillBlue);
    /* The accent itself, not text over a tinted fill. */
    {
      NSColor *accent = [[NSColor selectedControlColor] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];

      if (accent == nil
          || llabs((long long)pillRed - (long long)lrint([accent redComponent] * 255.0)) > 30
          || llabs((long long)pillGreen - (long long)lrint([accent greenComponent] * 255.0)) > 30
          || llabs((long long)pillBlue - (long long)lrint([accent blueComponent] * 255.0)) > 30)
        {
          pill = fill;
        }
    }
  }
  if (highContrast)
    {
      [self skip: @"list-selection-fill" detail: @"high contrast keeps the system highlight"];
      [self skip: @"list-selection-pill" detail: @"high contrast keeps the system highlight"];
    }
  else
    {
      if (llabs((long long)blue - (long long)red) <= 6 && llabs((long long)(fill - background)) >= 6)
        {
          [self pass: @"list-selection-fill" detail: [NSString stringWithFormat:
            @"the selected row is a neutral %lu,%lu,%lu", (unsigned long)red, (unsigned long)green,
            (unsigned long)blue]];
        }
      else
        {
          [self fail: @"list-selection-fill" detail: [NSString stringWithFormat:
            @"the selected row is %lu,%lu,%lu over rows of %ld: not a subtle fill",
            (unsigned long)red, (unsigned long)green, (unsigned long)blue, (long)background]];
        }
      if (llabs((long long)(pill - fill)) >= 150)
        {
          [self pass: @"list-selection-pill" detail: @"an accent pill at the selected row's leading edge"];
        }
      else
        {
          [self fail: @"list-selection-pill" detail: [NSString stringWithFormat:
            @"the selected row's leading edge is %ld, its fill %ld (of 765): no accent pill", (long)pill, (long)fill]];
        }
    }

  /* "Child", at level 1: its leftmost ink (the chevron) within the level's
     indent and slot, then a gap before the title. */
  rep = QuirkProbeRender(outline);
  [self saveView: outline named: @"outline-nested-row"];
  {
    NSInteger rowIndex = [outline rowForItem: @"Child"];
    NSRect cell = [outline frameOfCellAtColumn: 0 row: rowIndex];
    CGFloat indent = [outline indentationPerLevel] * [outline levelForRow: rowIndex];
    CGFloat midY = [outline isFlipped] ? NSMidY(cell) : NSHeight([outline bounds]) - NSMidY(cell);
    NSInteger rowBackground = QuirkProbeBrightnessAt(rep, scale, NSMaxX(cell) - 10.0, midY);
    NSInteger first = -1, firstEnd = -1, gap = 0, run = 0;

    for (x = (NSInteger)(NSMinX(cell) * scale); x < (NSInteger)((NSMinX(cell) + 120) * scale); x++)
      {
        BOOL ink = NO;

        for (y = (NSInteger)((midY - 6) * scale); y <= (NSInteger)((midY + 6) * scale); y++)
          {
            QuirkProbePixel(rep, x, y, &red, &green, &blue);
            if (llabs((long long)(red + green + blue) - (long long)rowBackground) > 90)
              {
                ink = YES;
              }
          }
        if (ink)
          {
            if (first < 0)
              {
                first = x;
              }
            else if (firstEnd >= 0 && gap == 0)
              {
                gap = run;
              }
            run = 0;
          }
        else if (first >= 0)
          {
            if (firstEnd < 0)
              {
                firstEnd = x;
              }
            run++;
          }
      }
    if (rowIndex < 0 || first < 0)
      {
        [self fail: @"outline-chevron-before-title" detail: @"couldn't find the nested row's ink"];
      }
    else if (first <= (NSMinX(cell) + indent + 15.0) * scale && gap >= 3 * scale)
      {
        [self pass: @"outline-chevron-before-title" detail: [NSString stringWithFormat:
          @"the chevron starts %.0fpt into the row's indent slot, %ld px clear of the title",
          first / scale - NSMinX(cell) - indent, (long)gap]];
      }
    else
      {
        [self fail: @"outline-chevron-before-title" detail: [NSString stringWithFormat:
          @"the row's first ink is %.0fpt past its indent (the slot is 15pt), %ld px before the next: "
          @"the chevron is over the title", first / scale - NSMinX(cell) - indent, (long)gap]];
      }
  }
  [window orderOut: nil];
}

/* WinUI's AutoSuggestBox (issue #9): an empty search field shows only
   the magnifier, at its trailing edge, nothing before its text; with
   text, the delete cross shows just before the magnifier. */
- (void) checkSearchField
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(420, 780, 300, 80)
                                     title: @"QuirkProbe Search"];
  NSSearchField *search = AUTORELEASE([[NSSearchField alloc] initWithFrame: NSMakeRect(20, 24, 240, 32)]);
  NSBitmapImageRep *rep = nil;
  CGFloat scale;
  NSInteger width, height, fill;
  NSUInteger leading, query, emptyDelete, delete;

  [[search cell] setPlaceholderString: nil];
  [search setStringValue: @""];
  [[window contentView] addSubview: search];
  [window makeKeyAndOrderFront: nil];
  [window makeFirstResponder: window];
  [window display];

  rep = QuirkProbeRender(search);
  scale = QuirkProbeScale(rep, search);
  width = [rep pixelsWide];
  height = [rep pixelsHigh];
  [self saveView: search named: @"search-empty"];
  fill = QuirkProbeBrightnessAt(rep, scale, NSWidth([search bounds]) / 2.0, NSHeight([search bounds]) / 2.0);
  leading = QuirkProbeInkIn(rep, NSMakeRect(3 * scale, height * 0.25, 18 * scale, height * 0.5), fill, 150, NULL);
  query = QuirkProbeInkIn(rep, NSMakeRect(width - 30 * scale, height * 0.25, 24 * scale, height * 0.5),
                          fill, 150, NULL);
  emptyDelete = QuirkProbeInkIn(rep, NSMakeRect(width - 60 * scale, height * 0.25, 26 * scale, height * 0.5),
                                fill, 150, NULL);
  if (leading == 0 && query >= 8)
    {
      [self pass: @"search-query-trailing" detail: @"the magnifier is inside the field, at its trailing edge"];
    }
  else
    {
      [self fail: @"search-query-trailing" detail: [NSString stringWithFormat:
        @"%lu px of glyph before the text, %lu px at the trailing edge", (unsigned long)leading,
        (unsigned long)query]];
    }

  [search setStringValue: @"q"];
  [window display];
  rep = QuirkProbeRender(search);
  [self saveView: search named: @"search-text"];
  delete = QuirkProbeInkIn(rep, NSMakeRect(width - 60 * scale, height * 0.25, 26 * scale, height * 0.5),
                           fill, 150, NULL);
  if (emptyDelete == 0 && delete >= 6)
    {
      [self pass: @"search-delete-with-text" detail: @"the delete cross shows before the magnifier only with text"];
    }
  else
    {
      [self fail: @"search-delete-with-text" detail: [NSString stringWithFormat:
        @"before the magnifier: %lu px empty, %lu px with text", (unsigned long)emptyDelete,
        (unsigned long)delete]];
    }
  [window orderOut: nil];
}

- (void) checkLateWindow: (NSTimer *)timer
{
  NSMenu *mainMenu = [NSApp mainMenu];

  if (NSInterfaceStyleForKey(@"NSMenuInterfaceStyle", nil) != NSWindows95InterfaceStyle)
    {
      [self skip: @"late-window-menu" detail: @"the menu style isn't NSWindows95InterfaceStyle"];
    }
  else if ([_lateWindow menu] == mainMenu)
    {
      [self pass: @"late-window-menu" detail: @"a window created after launch shows the main menu"];
    }
  else
    {
      [self fail: @"late-window-menu" detail: @"a window created after launch has no menu bar"];
    }
  [self saveView: [[_lateWindow contentView] superview] named: @"late-window"];
  [self checkMenuBarTitles: _lateWindow];
  [self checkWindowsMenuConventions];
  [self checkThemeSwitchRestoresMethods];
  [self finish];
}

/* Menu bar titles aren't clipped. NSMenuView sizes an item for its title
   plus a 4pt pad each side; the theme drew titles further in, so "File"
   showed as "Fil". Measures each title's ink against its text width. */
- (void) checkMenuBarTitles: (NSWindow *)window
{
  NSView *frameView = [[window contentView] superview];
  NSMenuView *menuView = (NSMenuView *)QuirkProbeFindViewOfClass(frameView, [NSMenuView class]);
  NSBitmapImageRep *rep = nil;
  CGFloat scale;
  NSUInteger red, green, blue;
  NSInteger index;
  NSMutableArray *clipped = [NSMutableArray array];

  if (menuView == nil || [menuView isHorizontal] == NO)
    {
      [self skip: @"menu-bar-titles-fit" detail: @"the window has no menu bar"];
      return;
    }
  [menuView sizeToFit];
  [window display];
  rep = QuirkProbeRender(menuView);
  scale = QuirkProbeScale(rep, menuView);
  [self saveView: menuView named: @"menu-bar"];

  /* The bar's background: its last pixel column, past every item. */
  if (QuirkProbePixel(rep, [rep pixelsWide] - 2, [rep pixelsHigh] / 2, &red, &green, &blue) == NO)
    {
      [self skip: @"menu-bar-titles-fit" detail: @"couldn't read the menu bar's pixels"];
      return;
    }
  QuirkProbeInkBackground = red + green + blue;

  for (index = 0; index < [[menuView menu] numberOfItems]; index++)
    {
      NSMenuItemCell *cell = [menuView menuItemCellForItemAtIndex: index];
      NSString *title = [[cell menuItem] title];
      NSRect itemRect = [menuView rectOfItemAtIndex: index];
      NSRect pixelRect;
      NSDictionary *attributes = nil;
      CGFloat expected;
      QuirkProbeInk ink;

      if ([title length] == 0)
        {
          continue;
        }
      if ([menuView isFlipped] == NO)
        {
          itemRect.origin.y = NSHeight([menuView bounds]) - NSMaxY(itemRect);
        }
      pixelRect = NSMakeRect(NSMinX(itemRect) * scale, NSMinY(itemRect) * scale + 2,
                             NSWidth(itemRect) * scale, NSHeight(itemRect) * scale - 4);
      attributes = [NSDictionary dictionaryWithObject: [cell font] forKey: NSFontAttributeName];
      expected = [title sizeWithAttributes: attributes].width * scale;
      ink = QuirkProbeMeasureIn(rep, QuirkProbeIsInk, pixelRect);
      if (ink.width < expected * 0.85 - 2)
        {
          [clipped addObject: [NSString stringWithFormat: @"%@ (%ld of %.0f px)",
                                                          title, (long)ink.width, expected]];
        }
    }

  if ([clipped count] == 0)
    {
      [self pass: @"menu-bar-titles-fit" detail: @"every menu bar title is shown in full"];
    }
  else
    {
      [self fail: @"menu-bar-titles-fit" detail:
        [@"clipped: " stringByAppendingString: [clipped componentsJoinedByString: @", "]]];
    }
}

/* Whether any item in `menu` or its submenus has `action`, or a submenu
   titled `title`. */
static BOOL
QuirkProbeMenuTreeHas(NSMenu *menu, SEL action, NSString *title)
{
  NSEnumerator *enumerator = [[menu itemArray] objectEnumerator];
  NSMenuItem *item = nil;

  while ((item = [enumerator nextObject]) != nil)
    {
      if ((action != NULL && [item action] != NULL && sel_isEqual([item action], action))
          || (title != nil && [item hasSubmenu] && [[item title] isEqualToString: title]))
        {
          return YES;
        }
      if ([item hasSubmenu] && QuirkProbeMenuTreeHas([item submenu], action, title))
        {
          return YES;
        }
    }
  return NO;
}

/* The last item of the main menu's submenu titled `title`. */
static NSMenuItem *
QuirkProbeLastItemOfMenu(NSString *title)
{
  NSMenu *submenu = [[[NSApp mainMenu] itemWithTitle: title] submenu];

  if (submenu == nil || [submenu numberOfItems] == 0)
    {
      return nil;
    }
  return (NSMenuItem *)[submenu itemAtIndex: [submenu numberOfItems] - 1];
}

/* Windows menu conventions (issue #24). The probe's main menu is
   Cocoa-style: an untitled application menu (About, Preferences, Services,
   Hide, Show All, Quit), File, Edit and no Help. The theme should leave no
   application menu, end File with Exit, Edit with Preferences and a new
   Help with About, and drop Hide, Show All and Services; and show key
   equivalents as Windows does ("Ctrl+Q"). */
- (void) checkWindowsMenuConventions
{
  NSMenu *mainMenu = [NSApp mainMenu];
  NSMutableArray *problems = [NSMutableArray array];
  NSMenuItem *first = ([mainMenu numberOfItems] > 0) ? (NSMenuItem *)[mainMenu itemAtIndex: 0] : nil;
  NSMenuItem *exitItem = QuirkProbeLastItemOfMenu(@"File");
  NSMenuItem *preferencesItem = QuirkProbeLastItemOfMenu(@"Edit");
  NSMenuItem *aboutItem = QuirkProbeLastItemOfMenu(@"Help");
  NSString *quit = [[GSTheme theme] keyForKeyEquivalent: @"#q"];
  NSString *redo = [[GSTheme theme] keyForKeyEquivalent: @"/#z"];

  if (NSInterfaceStyleForKey(@"NSMenuInterfaceStyle", nil) != NSWindows95InterfaceStyle)
    {
      [self skip: @"windows-menu-conventions" detail: @"the menu style isn't NSWindows95InterfaceStyle"];
      return;
    }
  if ([[first title] length] == 0 || [[first title] isEqualToString: @"QuirkProbe"])
    {
      [problems addObject: [NSString stringWithFormat: @"the bar starts with \"%@\"", [first title]]];
    }
  if (exitItem == nil || sel_isEqual([exitItem action], @selector(terminate:)) == NO
      || [[exitItem title] isEqualToString: @"Exit"] == NO)
    {
      [problems addObject: [NSString stringWithFormat: @"File ends with \"%@\", not Exit", [exitItem title]]];
    }
  if (preferencesItem == nil
      || sel_isEqual([preferencesItem action], @selector(orderFrontPreferencesPanel:)) == NO)
    {
      [problems addObject: [NSString stringWithFormat: @"Edit ends with \"%@\", not Preferences",
                                                      [preferencesItem title]]];
    }
  if (aboutItem == nil
      || sel_isEqual([aboutItem action], @selector(orderFrontStandardAboutPanel:)) == NO)
    {
      [problems addObject: @"no Help menu ending with About"];
    }
  if (QuirkProbeMenuTreeHas(mainMenu, @selector(hide:), nil)
      || QuirkProbeMenuTreeHas(mainMenu, @selector(unhideAllApplications:), nil))
    {
      [problems addObject: @"Hide or Show All is still there"];
    }
  if (QuirkProbeMenuTreeHas(mainMenu, NULL, @"Services"))
    {
      [problems addObject: @"Services is still there"];
    }

  if ([problems count] == 0)
    {
      [self pass: @"windows-menu-conventions" detail:
        @"no application menu; File ends with Exit, Edit with Preferences, Help with About"];
    }
  else
    {
      [self fail: @"windows-menu-conventions" detail: [problems componentsJoinedByString: @"; "]];
    }

  if ([quit isEqualToString: @"Ctrl+Q"] && [redo isEqualToString: @"Ctrl+Shift+Z"])
    {
      [self pass: @"shortcut-text" detail: @"Command-Q shows as Ctrl+Q, Command-Shift-Z as Ctrl+Shift+Z"];
    }
  else
    {
      [self fail: @"shortcut-text" detail:
        [NSString stringWithFormat: @"Command-Q shows as \"%@\", Command-Shift-Z as \"%@\"", quit, redo]];
    }
}

/* Switching to another theme at run time leaves no WinUITheme code in
   AppKit's menu item and segment methods (issue #12). The theme used to
   replace them with Objective-C categories, which stay for the life of the
   process. Run last: it deactivates the theme. */
- (void) checkThemeSwitchRestoresMethods
{
  struct { Class cls; const char *selector; } methods[] = {
    { [NSMenuItemCell class], "imagePosition" },
    { [NSMenuItemCell class], "imageWidth" },
    { [NSMenuItemCell class], "keyEquivalentWidth" },
    { [NSMenuItemCell class], "stateImageWidth" },
    { [NSMenuItemCell class], "imageRectForBounds:" },
    { [NSMenuItemCell class], "keyEquivalentRectForBounds:" },
    { [NSMenuItemCell class], "stateImageRectForBounds:" },
    { [NSMenuItemCell class], "drawImageWithFrame:inView:" },
    { [NSMenuItemCell class], "drawKeyEquivalentWithFrame:inView:" },
    { [NSMenuItemCell class], "drawStateImageWithFrame:inView:" },
    { [NSSegmentedCell class], "drawSegment:inFrame:withView:" },
  };
  void *themeModule = QuirkProbeModuleOfAddress(
    (void *)[[[GSTheme theme] class] instanceMethodForSelector: @selector(colors)]);
  NSMutableArray *left = [NSMutableArray array];
  NSUInteger index;

  if (themeModule == NULL)
    {
      [self skip: @"theme-switch-restores-methods" detail: @"can't find the theme's module"];
      return;
    }

  [GSTheme setTheme: nil];
  for (index = 0; index < sizeof(methods) / sizeof(methods[0]); index++)
    {
      IMP imp = [methods[index].cls instanceMethodForSelector:
                   sel_getUid(methods[index].selector)];

      if (QuirkProbeModuleOfAddress((void *)imp) == themeModule)
        {
          [left addObject: [NSString stringWithFormat: @"-[%@ %s]",
                                                       NSStringFromClass(methods[index].cls),
                                                       methods[index].selector]];
        }
    }

  if ([left count] == 0)
    {
      [self pass: @"theme-switch-restores-methods" detail:
        @"after switching themes, AppKit's menu item and segment methods are its own"];
    }
  else
    {
      [self fail: @"theme-switch-restores-methods" detail:
        [@"still the theme's after switching themes: " stringByAppendingString:
          [left componentsJoinedByString: @", "]]];
    }
}

- (void) finish
{
  printf("SUMMARY %lu passed, %lu failed, %lu known, %lu skipped\n",
         (unsigned long)_passed, (unsigned long)_failed,
         (unsigned long)_known, (unsigned long)_skipped);
  fflush(stdout);
  exit((int)_failed);
}

- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
  NSString *output = [[NSUserDefaults standardUserDefaults] stringForKey: @"ProbeOutput"];

  if ([output length] > 0)
    {
      ASSIGN(_outputDirectory, output);
      [[NSFileManager defaultManager] createDirectoryAtPath: output
                                withIntermediateDirectories: YES
                                                 attributes: nil
                                                      error: NULL];
    }
  printf("THEME %s\n", [[[[GSTheme theme] bundle] bundlePath] UTF8String] ?: "(default)");
  fflush(stdout);

  [self checkTheme];
  [self checkAccentColor];
  [self checkSubclassImageCell];
  [self checkToolbarImageItem];
  [self checkScrollerEdge];
  [self checkTableHeader];
  [self checkMultilineLabels];
  [self checkSwitches];
  [self checkStepper];
  [self checkDefaultButtons];
  [self checkAlertLayout];
  [self checkTemplateImages];
  [self checkButtonChrome];
  [self checkMenuFlyout];
  [self checkOverlayScrollers];
  [self checkFocusVisual];
  [self checkTextBox];
  [self checkComboBoxes];
  [self checkListSelection];
  [self checkSearchField];
  [self checkHorizontalOnlyScroller];
  [self checkPopUpClick];
  [self after: QuirkProbeSettleDelay perform: @selector(createLateWindow:)];
}

@end
