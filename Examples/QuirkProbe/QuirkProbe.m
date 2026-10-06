#import "QuirkProbe.h"

#import <GNUstepGUI/GSTheme.h>
#include <stdio.h>
#include <stdlib.h>

static NSString *QuirkProbeImageItem = @"ImageItem";
static const NSTimeInterval QuirkProbeSettleDelay = 0.8;

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
- (void) createLateWindow: (NSTimer *)timer;
- (void) checkLateWindow: (NSTimer *)timer;
- (void) checkMenuBarTitles: (NSWindow *)window;
- (void) finish;
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
  if (NSMinX(scroller) >= NSMaxX(content) - 1.0)
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
  [self checkSubclassImageCell];
  [self checkToolbarImageItem];
  [self checkScrollerEdge];
  [self checkTableHeader];
  [self checkMultilineLabels];
  [self after: QuirkProbeSettleDelay perform: @selector(createLateWindow:)];
}

@end
