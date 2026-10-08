/*
   Copyright (C) 2026 Daniel Boyd

   This file is part of the GNUstep WinUI theme.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <https://www.gnu.org/licenses/>.
*/

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

/* YES when the probe runs with -WinUIThemeMetrics compact. */
static BOOL
QuirkProbeCompactMetrics(void)
{
  NSString *choice = [[NSUserDefaults standardUserDefaults] stringForKey: @"WinUIThemeMetrics"];

  return choice != nil && [choice caseInsensitiveCompare: @"compact"] == NSOrderedSame;
}

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

/* A toolbar icon as ScreenshotTool's (#89): "-symbolic", 32x32pt from a
   24px bitmap, a 20px square of ink in it. */
static NSImage *
QuirkProbeToolbarSymbolicImage(void)
{
  NSImage *image = [NSImage imageNamed: @"probe-toolbar-symbolic"];
  NSBitmapImageRep *rep = nil;
  unsigned char *data = NULL;
  NSInteger x, y;

  if (image != nil)
    {
      return image;
    }
  rep = AUTORELEASE([[NSBitmapImageRep alloc]
                      initWithBitmapDataPlanes: NULL
                                    pixelsWide: 24
                                    pixelsHigh: 24
                                 bitsPerSample: 8
                               samplesPerPixel: 4
                                      hasAlpha: YES
                                      isPlanar: NO
                                colorSpaceName: NSCalibratedRGBColorSpace
                                   bytesPerRow: 0
                                  bitsPerPixel: 0]);
  data = [rep bitmapData];
  for (y = 0; y < 24; y++)
    {
      for (x = 0; x < 24; x++)
        {
          unsigned char *pixel = data + y * [rep bytesPerRow] + x * 4;
          BOOL ink = (x >= 2 && x < 22 && y >= 2 && y < 22);

          pixel[0] = 0;
          pixel[1] = 0;
          pixel[2] = 0;
          pixel[3] = ink ? 255 : 0;
        }
    }
  [rep setSize: NSMakeSize(32, 32)];
  image = AUTORELEASE([[NSImage alloc] initWithSize: NSMakeSize(32, 32)]);
  [image addRepresentation: rep];
  [image setName: @"probe-toolbar-symbolic"];
  return image;
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

#pragma mark Window tabs

/* Apple's window tabbing API and the shared tab bar's layout methods
   (gnustep-window-tabbing), which the theme installs at run time (#72).
   The probe doesn't compile that code in, so it declares what it calls and
   checks that NSWindow has it. */
@interface NSWindow (QuirkProbeTabbing)
- (void) addTabbedWindow: (NSWindow *)window ordered: (NSWindowOrderingMode)ordered;
- (NSArray *) tabbedWindows;
- (void) selectNextTab: (id)sender;
@end

@interface NSView (QuirkProbeTabBar)
- (NSUInteger) numberOfTabs;
- (NSRect) rectForTabAtIndex: (NSUInteger)index;
- (NSRect) closeButtonRectForTabAtIndex: (NSUInteger)index;
- (NSRect) newTabButtonRect;
@end

/* Notes whether a window was on screen when another one began to close. */
@interface QuirkProbeCloseWatcher : NSObject
{
@public
  NSWindow *_closing;
  NSWindow *_other;
  BOOL _heard;
  BOOL _otherVisible;
}
@end

@implementation QuirkProbeCloseWatcher
/* Registered for every window, as NSApplication is: the centre tells the
   observers of a name in turn, the latest first, so this hears it when
   NSApplication does. */
- (void) windowWillClose: (NSNotification *)notification
{
  if ([notification object] == _closing && _heard == NO)
    {
      _heard = YES;
      _otherVisible = [_other isVisible];
    }
}
@end

/* The tab bar among `view`'s subviews. */
static NSView *
QuirkProbeFindTabBar(NSView *view)
{
  NSEnumerator *enumerator = [[view subviews] objectEnumerator];
  NSView *subview = nil;

  if ([view respondsToSelector: @selector(newTabButtonRect)]
      && [view respondsToSelector: @selector(rectForTabAtIndex:)])
    {
      return view;
    }
  while ((subview = [enumerator nextObject]) != nil)
    {
      NSView *found = QuirkProbeFindTabBar(subview);

      if (found != nil)
        {
          return found;
        }
    }
  return nil;
}

/* The colour at `point` (in `bar`'s coordinates) of a render of `view`,
   which contains the bar. */
static BOOL
QuirkProbeTabPixel(NSBitmapImageRep *rep, NSView *view, NSView *bar, NSPoint point,
                   NSUInteger rgb[3])
{
  CGFloat scale = QuirkProbeScale(rep, view);
  NSPoint inView = [bar convertPoint: point toView: view];
  NSRect pixel = QuirkProbePixelRect(view, NSMakeRect(floor(inView.x), floor(inView.y), 1.0, 1.0), scale);

  return QuirkProbePixel(rep, (NSInteger)NSMinX(pixel), (NSInteger)NSMinY(pixel),
                         &rgb[0], &rgb[1], &rgb[2]);
}

static NSUInteger
QuirkProbeTabColorDistance(NSUInteger a[3], NSUInteger b[3])
{
  NSUInteger distance = 0;
  NSUInteger i;

  for (i = 0; i < 3; i++)
    {
      NSUInteger d = (a[i] > b[i]) ? a[i] - b[i] : b[i] - a[i];

      distance = MAX(distance, d);
    }
  return distance;
}

static NSString *
QuirkProbeTabHex(NSUInteger rgb[3])
{
  return [NSString stringWithFormat: @"#%02lX%02lX%02lX",
                                     (unsigned long)rgb[0], (unsigned long)rgb[1], (unsigned long)rgb[2]];
}

/* Pixels passing `test` in `rect` (the bar's coordinates) of a render of
   `view`. */
static QuirkProbeInk
QuirkProbeTabInk(NSBitmapImageRep *rep, NSView *view, NSView *bar, NSRect rect,
                 QuirkProbePixelTest test)
{
  CGFloat scale = QuirkProbeScale(rep, view);

  return QuirkProbeMeasureIn(rep, test,
                             QuirkProbePixelRect(view, [bar convertRect: rect toView: view], scale));
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
- (void) checkToolbarIconSize;
- (void) checkScrollerEdge;
- (void) checkTextAlignment;
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
- (void) checkEarlyTemplateImages;
- (void) checkButtonChrome;
- (void) checkSizeToFit;
- (void) checkTypography;
- (void) checkSlider;
- (void) checkProgress;
- (void) checkLevelIndicator;
- (void) checkDatePicker;
- (void) checkBrowser;
- (void) checkBrowserTitles;
- (void) checkColorWell;
- (void) checkBoxes;
- (void) checkContrastTheme;
- (void) checkSegmentedControl;
- (void) checkCellSizes;
- (void) checkTabView;
- (void) checkMetricsChoice;
- (void) checkTableDefaults;
- (void) checkLiveSettings;
- (void) checkIndicators;
- (void) checkMenuFlyout;
- (void) checkOverlayScrollers;
- (void) checkOverlayAutohide;
- (void) checkFocusVisual;
- (void) checkTextBox;
- (void) checkComboBoxes;
- (void) checkListSelection;
- (void) checkSelectedRowText;
- (void) checkToolTip;
- (void) checkInspectorIndicators;
- (void) checkSearchField;
- (void) checkHorizontalOnlyScroller;
- (void) checkWindowTabs;
- (void) checkFileDialogFilters;
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

/* A flipped container, as a split view is: the font panel's browsers and
   its "Size" label sit in a plain view inside one. */
@interface QuirkProbeFlippedView : NSView
@end

@implementation QuirkProbeFlippedView

- (BOOL) isFlipped
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

/* Rows whose text colour the app sets, as MarkdownViewer does (#66): a
   table's as attributed strings, an outline's from -willDisplayCell:. */
@interface QuirkProbeColouredRows : NSObject
{
  NSColor *_color;
}
- (id) initWithColor: (NSColor *)color;
@end

@implementation QuirkProbeColouredRows

- (id) initWithColor: (NSColor *)color
{
  self = [super init];
  if (self != nil)
    {
      ASSIGN(_color, color);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_color);
  [super dealloc];
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *)tableView
{
  return 3;
}

- (id) tableView: (NSTableView *)tableView objectValueForTableColumn: (NSTableColumn *)column row: (NSInteger)row
{
  NSString *title = [NSString stringWithFormat: @"Document %ld", (long)row];
  NSDictionary *attributes = [NSDictionary dictionaryWithObject: _color forKey: NSForegroundColorAttributeName];

  return AUTORELEASE([[NSAttributedString alloc] initWithString: title attributes: attributes]);
}

- (NSInteger) outlineView: (NSOutlineView *)outlineView numberOfChildrenOfItem: (id)item
{
  return item == nil ? 3 : 0;
}

- (id) outlineView: (NSOutlineView *)outlineView child: (NSInteger)index ofItem: (id)item
{
  return [NSString stringWithFormat: @"Folder %ld", (long)index];
}

- (BOOL) outlineView: (NSOutlineView *)outlineView isItemExpandable: (id)item
{
  return NO;
}

- (id) outlineView: (NSOutlineView *)outlineView objectValueForTableColumn: (NSTableColumn *)column byItem: (id)item
{
  return item;
}

- (void) outlineView: (NSOutlineView *)outlineView willDisplayCell: (id)cell
      forTableColumn: (NSTableColumn *)column item: (id)item
{
  if ([cell respondsToSelector: @selector(setTextColor:)])
    {
      [cell setTextColor: _color];
    }
}

@end

/* How many pixels of the title area of `view`'s selected `row` stand out
   from the selection's fill, which is sampled at the row's trailing end. */
static NSUInteger
QuirkProbeSelectedRowInk(NSTableView *view, NSInteger row, NSBitmapImageRep *rep, CGFloat scale)
{
  NSRect rect = [view frameOfCellAtColumn: 0 row: row];
  NSRect pixels = QuirkProbePixelRect(view, rect, scale);
  NSUInteger red = 0, green = 0, blue = 0, count = 0;
  NSInteger fill, x, y;

  QuirkProbePixel(rep, (NSInteger)(NSMaxX(pixels) - 12 * scale), (NSInteger)NSMidY(pixels), &red, &green, &blue);
  fill = (NSInteger)(red + green + blue);
  for (y = (NSInteger)NSMinY(pixels) + 1; y < (NSInteger)NSMaxY(pixels) - 1; y++)
    {
      for (x = (NSInteger)(NSMinX(pixels) + 20 * scale); x < (NSInteger)(NSMinX(pixels) + 130 * scale); x++)
        {
          if (QuirkProbePixel(rep, x, y, &red, &green, &blue)
              && llabs((long long)(red + green + blue) - (long long)fill) > 150)
            {
              count++;
            }
        }
    }
  return count;
}

/* The accent colour's pixels (the checked box or radio), whatever the
   palette: within 40 of selectedControlColor in each channel. */
static NSUInteger QuirkProbeAccentRGB[3];

static BOOL
QuirkProbeIsPaletteAccent(NSUInteger red, NSUInteger green, NSUInteger blue)
{
  return labs((long)red - (long)QuirkProbeAccentRGB[0]) <= 40
    && labs((long)green - (long)QuirkProbeAccentRGB[1]) <= 40
    && labs((long)blue - (long)QuirkProbeAccentRGB[2]) <= 40;
}

static void
QuirkProbeLoadAccent(void)
{
  NSColor *accent = [[NSColor selectedControlColor] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];

  QuirkProbeAccentRGB[0] = (NSUInteger)lrint([accent redComponent] * 255.0);
  QuirkProbeAccentRGB[1] = (NSUInteger)lrint([accent greenComponent] * 255.0);
  QuirkProbeAccentRGB[2] = (NSUInteger)lrint([accent blueComponent] * 255.0);
}

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

/* The tab bar's "+" shows only when something answers -newWindowForTab:
   (checkWindowTabs); the probe, NSApp's delegate, answers only while that
   check asks it to. */
- (BOOL) respondsToSelector: (SEL)selector
{
  if (sel_isEqual(selector, @selector(newWindowForTab:)))
    {
      return _offersNewTab;
    }
  return [super respondsToSelector: selector];
}

- (void) newWindowForTab: (id)sender
{
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
  [item setImage: [[toolbar identifier] isEqualToString: @"QuirkProbeIconSizeToolbar"]
                   ? QuirkProbeToolbarSymbolicImage() : [self magentaImage]];
  /* The alignment check needs a view item (the theme draws its label)
     with a label much narrower than the view. */
  if ([[toolbar identifier] isEqualToString: @"QuirkProbeAlignmentToolbar"])
    {
      NSImageView *view = [[NSImageView alloc] initWithFrame: NSMakeRect(0, 0, 96, 24)];

      [view setImage: [self magentaImage]];
      [view setImageScaling: NSImageScaleNone];
      [item setView: view];
      [item setMinSize: NSMakeSize(96, 24)];
      [item setMaxSize: NSMakeSize(96, 24)];
      [item setLabel: @"Go"];
      RELEASE(view);
    }
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

#pragma mark Browser delegate

/* Four rows a column; the browser's tag is the column whose rows are
   leaves. */
- (NSInteger) browser: (NSBrowser *)browser numberOfRowsInColumn: (NSInteger)column
{
  return 4;
}

- (void) browser: (NSBrowser *)browser
 willDisplayCell: (id)cell
           atRow: (NSInteger)row
          column: (NSInteger)column
{
  /* checkBrowserTitles' browsers (tag 100) compare their titles' "TTTT"
     with rows that start the same way. */
  [cell setStringValue: ([browser tag] == 100) ? [NSString stringWithFormat: @"TTTT %ld", (long)row]
                                               : [NSString stringWithFormat: @"Item %ld.%ld", (long)column, (long)row]];
  [cell setLeaf: column >= [browser tag]];
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

/* The ink of the toolbar's icon, on the toolbar's background. */
static QuirkProbeInk
QuirkProbeToolbarIconInk(NSView *toolbarView)
{
  NSBitmapImageRep *rep = QuirkProbeRender(toolbarView);
  NSUInteger red, green, blue;

  QuirkProbePixel(rep, [rep pixelsWide] - 4, [rep pixelsHigh] / 2, &red, &green, &blue);
  QuirkProbeInkBackground = red + green + blue;
  return QuirkProbeMeasureIn(rep, QuirkProbeIsInk,
                             NSMakeRect(0, 0, [rep pixelsWide], [rep pixelsHigh] - 2));
}

/* An image toolbar item keeps its size through a relayout (issue #89).
   The theme set the item's own NSImage to the icon's 20pt, so the app's
   image changed under it, and after a relayout ScreenshotTool's 32pt
   icons drew at about 12px. WinUI's AppBarButton draws its icon at 20px
   whatever the source's size. */
- (void) checkToolbarIconSize
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(320, 440, 360, 140)
                                     title: @"QuirkProbe Toolbar Icon"];
  NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier: @"QuirkProbeIconSizeToolbar"];
  NSImage *image = QuirkProbeToolbarSymbolicImage();
  NSView *toolbarView = nil;
  CGFloat scale;
  QuirkProbeInk before, after;
  NSSize sizeBefore, sizeAfter;
  NSString *detail = nil;

  [toolbar setDelegate: self];
  [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
  [window setToolbar: toolbar];
  RELEASE(toolbar);
  [window orderFront: nil];
  [window display];
  toolbarView = QuirkProbeFindViewOfClass([[window contentView] superview],
                                          NSClassFromString(@"GSToolbarView"));
  if (toolbarView == nil)
    {
      [self skip: @"toolbar-icon-size" detail: @"no GSToolbarView in the window"];
      [self skip: @"toolbar-icon-image-kept" detail: @"no GSToolbarView in the window"];
      return;
    }
  scale = QuirkProbeScale(QuirkProbeRender(toolbarView), toolbarView);
  sizeBefore = [image size];
  before = QuirkProbeToolbarIconInk(toolbarView);
  [self saveView: toolbarView named: @"toolbar-icon-before"];

  /* Relaid out twice: the window narrower, as ScreenshotTool's when it
     opens a file, and the display mode switched and back. */
  [window setFrame: NSMakeRect(320, 440, 300, 140) display: YES];
  [toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
  [window display];
  [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
  [window setFrame: NSMakeRect(320, 440, 340, 140) display: YES];
  /* And the app sets the item's image again, as validation may. */
  [[[toolbar items] objectAtIndex: 0] setImage: image];
  [window display];
  sizeAfter = [image size];
  after = QuirkProbeToolbarIconInk(toolbarView);
  [self saveView: toolbarView named: @"toolbar-icon-after"];

  /* The 20px square in a 24px bitmap, drawn at 20pt: about 17pt. */
  detail = [NSString stringWithFormat: @"the icon's ink %.0fx%.0fpt, %.0fx%.0fpt after two relayouts",
                                       before.width / scale, before.height / scale,
                                       after.width / scale, after.height / scale];
  if (before.count > 0 && llabs((long long)(before.width - after.width)) <= 1
      && llabs((long long)(before.height - after.height)) <= 1
      && fabs(after.height / scale - 20.0 * 20.0 / 24.0) <= 2.0)
    {
      [self pass: @"toolbar-icon-size" detail: detail];
    }
  else
    {
      [self fail: @"toolbar-icon-size" detail: [detail stringByAppendingString: @" (expected about 17)"]];
    }

  detail = [NSString stringWithFormat: @"the item's image %.0fx%.0fpt, %.0fx%.0fpt after layout (its own 32x32)",
                                       sizeBefore.width, sizeBefore.height, sizeAfter.width, sizeAfter.height];
  if (NSEqualSizes(sizeBefore, NSMakeSize(32, 32)) && NSEqualSizes(sizeAfter, NSMakeSize(32, 32)))
    {
      [self pass: @"toolbar-icon-image-kept" detail: detail];
    }
  else
    {
      [self fail: @"toolbar-icon-image-kept" detail: detail];
    }
  [window setToolbar: nil];
  [window orderOut: nil];
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

  /* 12pt, and a point or two of the "N"'s side bearing. */
  inset = ink.minX / scale;
  if (inset >= 11.0 && inset <= 14.5)
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

/* Centred text stays centred whichever way the running libs-gui numbers
   NSTextAlignment (issue #13): libs-gui after 0.32 swapped centre and
   right, so the label of a toolbar view item, set with 0.32's
   NSCenterTextAlignment, drew right-aligned under its view. Measured from the drawing; the table
   header check covers left alignment and the menu check the shortcuts. */
- (void) checkTextAlignment
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(320, 300, 320, 160)
                                     title: @"QuirkProbe Alignment"];
  NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier: @"QuirkProbeAlignmentToolbar"];
  NSView *toolbarView = nil;
  NSBitmapImageRep *rep = nil;
  NSUInteger red, green, blue;
  QuirkProbeInk icon, label;
  CGFloat scale, iconCentre, labelCentre;

  [toolbar setDelegate: self];
  [toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
  [window setToolbar: toolbar];
  RELEASE(toolbar);
  [window orderFront: nil];
  [window display];

  toolbarView = QuirkProbeFindViewOfClass([[window contentView] superview],
                                          NSClassFromString(@"GSToolbarView"));
  if (toolbarView == nil)
    {
      [self skip: @"toolbar-label-centred" detail: @"no GSToolbarView in the window"];
      return;
    }
  /* The magenta square is centred in its view. */
  rep = QuirkProbeRender(toolbarView);
  scale = QuirkProbeScale(rep, toolbarView);
  [self saveView: toolbarView named: @"toolbar-label"];

  icon = QuirkProbeMeasureIn(rep, QuirkProbeIsMagenta, NSZeroRect);
  if (icon.count == 0
      || QuirkProbePixel(rep, [rep pixelsWide] - (NSInteger)(10 * scale),
                         icon.minY + icon.height + (NSInteger)(4 * scale),
                         &red, &green, &blue) == NO)
    {
      [self fail: @"toolbar-label-centred" detail: @"couldn't find the item's view"];
      return;
    }
  QuirkProbeInkBackground = red + green + blue;
  /* Under the icon, across the item's width either side of it, above the
     line under the toolbar. */
  label = QuirkProbeMeasureIn(rep, QuirkProbeIsInk,
                              NSMakeRect(MAX(0, icon.minX - 60 * scale),
                                         icon.minY + icon.height + 1,
                                         icon.width + 120 * scale,
                                         [rep pixelsHigh] - (icon.minY + icon.height + 1) - 2));
  if (label.count == 0)
    {
      [self fail: @"toolbar-label-centred" detail: @"the item shows no label"];
      return;
    }
  iconCentre = (icon.minX + icon.width / 2.0) / scale;
  labelCentre = (label.minX + label.width / 2.0) / scale;
  if (fabs(labelCentre - iconCentre) <= 2.0)
    {
      [self pass: @"toolbar-label-centred" detail:
        [NSString stringWithFormat: @"the label is centred under the view (%.1fpt off)",
                                    labelCentre - iconCentre]];
    }
  else
    {
      [self fail: @"toolbar-label-centred" detail:
        [NSString stringWithFormat: @"the label's centre is %.1fpt from the view's",
                                    labelCentre - iconCentre]];
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

  /* A switch from a .gorm file (an NSArchiver archive, which holds no
     enabled flag for it), as the WinUI Gorm palette's ToggleSwitch (#32). */
  {
    NSSwitch *decoded = [NSUnarchiver unarchiveObjectWithData:
                           [NSArchiver archivedDataWithRootObject: switches[0]]];

    if ([decoded isKindOfClass: [NSSwitch class]] && [decoded isEnabled])
      {
        [self pass: @"switch-decoded-enabled" detail: @"a switch decoded from a .gorm archive is enabled"];
      }
    else
      {
        [self fail: @"switch-decoded-enabled" detail: @"a switch decoded from a .gorm archive is disabled"];
      }
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
  NSColor *onAccent = [colors colorWithKey: @"accentTextColor"];
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
  NSColor *onAccent = [colors colorWithKey: @"accentTextColor"];
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

/* A 20x20 opaque black square in a bitmap, named "...-symbolic", as an
   app's PNG icons load. */
static NSImage *
QuirkProbeSymbolicSquare(void)
{
  NSImage *image = [NSImage imageNamed: @"probe-square-symbolic"];
  NSBitmapImageRep *rep = nil;
  unsigned char *data = NULL;
  NSInteger index;

  if (image != nil)
    {
      return image;
    }
  rep = AUTORELEASE([[NSBitmapImageRep alloc]
                      initWithBitmapDataPlanes: NULL
                                    pixelsWide: 20
                                    pixelsHigh: 20
                                 bitsPerSample: 8
                               samplesPerPixel: 4
                                      hasAlpha: YES
                                      isPlanar: NO
                                colorSpaceName: NSCalibratedRGBColorSpace
                                   bytesPerRow: 0
                                  bitsPerPixel: 0]);
  data = [rep bitmapData];
  for (index = 0; index < 20 * 20; index++)
    {
      data[index * 4] = 0;
      data[index * 4 + 1] = 0;
      data[index * 4 + 2] = 0;
      data[index * 4 + 3] = 255;
    }
  image = AUTORELEASE([[NSImage alloc] initWithSize: NSMakeSize(20, 20)]);
  [image addRepresentation: rep];
  [image setName: @"probe-square-symbolic"];
  return image;
}

/* A template image first drawn while its window is off screen still draws
   in the text colour once the window is shown (issue #64): the tinted copy
   made then was blank on Windows, and kept. */
- (void) checkEarlyTemplateImages
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(780, 600, 160, 80)
                                     title: @"QuirkProbe Early Template Images"];
  NSColor *text = [[[GSTheme theme] colors] colorWithKey: @"labelColor"];
  NSSegmentedControl *segments = AUTORELEASE([[NSSegmentedControl alloc]
                                               initWithFrame: NSMakeRect(20, 20, 120, 40)]);
  NSString *seen = nil;

  [segments setSegmentCount: 1];
  [segments setImage: QuirkProbeSymbolicSquare() forSegment: 0];
  [segments setWidth: 118 forSegment: 0];
  [[window contentView] addSubview: segments];
  /* Drawn before the window is on screen, as an app's bars are while
     it builds them. */
  [window display];
  QuirkProbeRender(segments);
  [window orderFront: nil];
  [window display];

  [self saveView: [window contentView] named: @"early-template-images"];
  if (QuirkProbeCentreIs(segments, text, 60, &seen))
    {
      [self pass: @"early-template-images"
            detail: @"a template image tinted before its window is shown draws in the text colour"];
    }
  else
    {
      [self fail: @"early-template-images"
            detail: [NSString stringWithFormat: @"segment %@ (text is %@)", seen, QuirkProbeHex(text)]];
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

/* The desktop scale the theme was given (--scale), by which it scales its
   metrics; the probe's drawing stays 1:1. */
static CGFloat
QuirkProbeDesktopScale(void)
{
  NSArray *arguments = [[NSProcessInfo processInfo] arguments];
  NSUInteger index = [arguments indexOfObject: @"--scale"];

  if (index != NSNotFound && index + 1 < [arguments count])
    {
      return MAX(1.0, [[arguments objectAtIndex: index + 1] doubleValue]);
    }
  return 1.0;
}

/* The pixels in column `x` (pixels) of `rep` that pass `test`, between
   rows y0 and y1. */
static NSUInteger
QuirkProbeColumnCount(NSBitmapImageRep *rep, QuirkProbePixelTest test,
                      NSInteger x, NSInteger y0, NSInteger y1)
{
  NSUInteger count = 0;
  NSInteger y;

  for (y = y0; y < y1; y++)
    {
      NSUInteger red, green, blue;

      if (QuirkProbePixel(rep, x, y, &red, &green, &blue) && test(red, green, blue))
        {
          count++;
        }
    }
  return count;
}

/* WinUI's Slider (issue #41): a 4px track, the value part in the accent,
   and a 20px thumb around an accent dot, 12px at rest and 10px pressed.
   The theme drew a plain circle on a 6px bordered track. */
- (void) checkSlider
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(420, 300, 280, 80)
                                     title: @"QuirkProbe Slider"];
  NSSlider *slider = AUTORELEASE([[NSSlider alloc] initWithFrame: NSMakeRect(20, 28, 240, 24)]);
  NSBitmapImageRep *rep = nil;
  CGFloat scale, desktop;
  NSInteger height, centreX, centreY;
  NSUInteger value, rest, pressed;
  NSUInteger red, green, blue;

  if (QuirkProbeHasArgument(@"--high-contrast", nil))
    {
      [self skip: @"slider-track" detail: @"high contrast's highlight may not be blue"];
      [self skip: @"slider-thumb-dot" detail: @"high contrast's highlight may not be blue"];
      return;
    }
  [slider setMinValue: 0.0];
  [slider setMaxValue: 100.0];
  [slider setDoubleValue: 50.0];
  [[window contentView] addSubview: slider];
  [window orderFront: nil];
  [window display];
  rep = QuirkProbeRender(slider);
  scale = QuirkProbeScale(rep, slider);
  desktop = QuirkProbeDesktopScale();
  height = [rep pixelsHigh];
  [self saveView: slider named: @"slider"];

  /* The value part, a quarter of the way along: an accent band 4pt deep. */
  value = QuirkProbeColumnCount(rep, QuirkProbeIsAccentBlue, (NSInteger)(60 * scale), 0, height);
  if (fabs(value - 4.0 * desktop * scale) <= 0.5)
    {
      [self pass: @"slider-track" detail: [NSString stringWithFormat:
        @"the value part is %lu px deep", (unsigned long)value]];
    }
  else
    {
      [self fail: @"slider-track" detail: [NSString stringWithFormat:
        @"the value part is %lu px deep, expected %.0f", (unsigned long)value, 4.0 * desktop * scale]];
    }

  /* The thumb's centre: the accent dot, across a row of the thumb. */
  centreX = (NSInteger)(120 * scale);
  centreY = height / 2;
  QuirkProbePixel(rep, centreX, centreY, &red, &green, &blue);
  rest = QuirkProbeRowCount(rep, QuirkProbeIsAccentBlue, centreY,
                            centreX - (NSInteger)(9 * desktop * scale),
                            centreX + (NSInteger)(9 * desktop * scale));
  [[slider cell] setHighlighted: YES];
  [slider display];
  rep = QuirkProbeRender(slider);
  pressed = QuirkProbeRowCount(rep, QuirkProbeIsAccentBlue, centreY,
                               centreX - (NSInteger)(9 * desktop * scale),
                               centreX + (NSInteger)(9 * desktop * scale));
  [[slider cell] setHighlighted: NO];
  [slider display];
  if (QuirkProbeIsAccentBlue(red, green, blue)
      && fabs(rest - 12.0 * desktop * scale) <= 2.0 && fabs(pressed - 10.0 * desktop * scale) <= 2.0)
    {
      [self pass: @"slider-thumb-dot" detail: [NSString stringWithFormat:
        @"an accent dot %lu px wide, %lu pressed", (unsigned long)rest, (unsigned long)pressed]];
    }
  else
    {
      [self fail: @"slider-thumb-dot" detail: [NSString stringWithFormat:
        @"the thumb's centre is %lu,%lu,%lu; accent %lu px across, %lu pressed (expected 12 and 10)",
        (unsigned long)red, (unsigned long)green, (unsigned long)blue,
        (unsigned long)rest, (unsigned long)pressed]];
    }
  [window orderOut: nil];
}

/* WinUI's ProgressBar and ProgressRing (issue #42): a 3px accent bar on a
   1px track line, not a bordered bezel; and an accent ring, hollow, not
   GNUstep's NeXT spinner. */
- (void) checkProgress
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(420, 200, 300, 100)
                                     title: @"QuirkProbe Progress"];
  NSProgressIndicator *bar = AUTORELEASE([[NSProgressIndicator alloc]
    initWithFrame: NSMakeRect(20, 60, 200, 20)]);
  NSProgressIndicator *ring = AUTORELEASE([[NSProgressIndicator alloc]
    initWithFrame: NSMakeRect(240, 50, 32, 32)]);
  NSBitmapImageRep *rep = nil;
  CGFloat scale;
  NSInteger height;
  NSUInteger filled, track;
  QuirkProbeInk ringInk;
  NSUInteger red, green, blue;

  if (QuirkProbeHasArgument(@"--high-contrast", nil))
    {
      [self skip: @"progress-bar" detail: @"high contrast's highlight may not be blue"];
      [self skip: @"progress-ring" detail: @"high contrast's highlight may not be blue"];
      return;
    }
  [bar setIndeterminate: NO];
  [bar setMinValue: 0.0];
  [bar setMaxValue: 100.0];
  [bar setDoubleValue: 50.0];
  [ring setStyle: NSProgressIndicatorSpinningStyle];
  /* Stopped, a spinner hides unless it's displayed when stopped. */
  [ring setDisplayedWhenStopped: YES];
  [ring setFrame: NSMakeRect(240, 50, 32, 32)];
  [ring setIndeterminate: NO];
  [ring setMinValue: 0.0];
  [ring setMaxValue: 100.0];
  [ring setDoubleValue: 75.0];
  [[window contentView] addSubview: bar];
  [[window contentView] addSubview: ring];
  [window orderFront: nil];
  [window display];

  rep = QuirkProbeRender(bar);
  scale = QuirkProbeScale(rep, bar);
  height = [rep pixelsHigh];
  [self saveView: bar named: @"progress-bar"];
  QuirkProbePixel(rep, 2, 1, &red, &green, &blue);
  QuirkProbeInkBackground = red + green + blue;
  filled = QuirkProbeColumnCount(rep, QuirkProbeIsAccentBlue, (NSInteger)(50 * scale), 0, height);
  track = QuirkProbeColumnCount(rep, QuirkProbeIsFaintInk, (NSInteger)(150 * scale), 0, height);
  if (fabs(filled - 3.0 * scale) <= 1.0 && track >= 1 && track <= ceil(scale) + 1)
    {
      [self pass: @"progress-bar" detail: [NSString stringWithFormat:
        @"a %lu px accent bar, a %lu px track", (unsigned long)filled, (unsigned long)track]];
    }
  else
    {
      [self fail: @"progress-bar" detail: [NSString stringWithFormat:
        @"the bar is %lu px deep (expected %.0f), the track %lu (expected 1)",
        (unsigned long)filled, 3.0 * scale, (unsigned long)track]];
    }

  rep = QuirkProbeRender(ring);
  [self saveView: ring named: @"progress-ring"];
  ringInk = QuirkProbeMeasureIn(rep, QuirkProbeIsAccentBlue, NSZeroRect);
  QuirkProbePixel(rep, [rep pixelsWide] / 2, [rep pixelsHigh] / 2, &red, &green, &blue);
  if (ringInk.count > 20 && QuirkProbeIsAccentBlue(red, green, blue) == NO
      && ringInk.width >= [rep pixelsWide] - 4)
    {
      [self pass: @"progress-ring" detail: [NSString stringWithFormat:
        @"an accent ring %ld px across, hollow", (long)ringInk.width]];
    }
  else
    {
      [self fail: @"progress-ring" detail: [NSString stringWithFormat:
        @"%lu accent px, %ld px across; the centre is %lu,%lu,%lu",
        (unsigned long)ringInk.count, (long)ringInk.width,
        (unsigned long)red, (unsigned long)green, (unsigned long)blue]];
    }
  [window orderOut: nil];
}

/* SystemFillColorCritical in either palette, or libs-gui's pure red:
   clearly redder than green and blue. */
static BOOL
QuirkProbeIsCriticalRed(NSUInteger red, NSUInteger green, NSUInteger blue)
{
  return red > 150 && red > green + 60 && red > blue + 50;
}

static NSLevelIndicator *
QuirkProbeLevelIndicator(NSView *content, NSRect frame, NSLevelIndicatorStyle style,
                         double maximum, double value, double warning, double critical)
{
  NSLevelIndicator *level = AUTORELEASE([[NSLevelIndicator alloc] initWithFrame: frame]);

  [[level cell] setLevelIndicatorStyle: style];
  [level setMinValue: 0.0];
  [level setMaxValue: maximum];
  [level setWarningValue: warning];
  [level setCriticalValue: critical];
  [level setDoubleValue: value];
  [content addSubview: level];
  return level;
}

/* NSLevelIndicator as WinUI's ProgressBar and RatingControl (issue #57).
   libs-gui filled a square white well, and with the warning and critical
   values left at 0 every level was critical: solid red. */
- (void) checkLevelIndicator
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(420, 160, 260, 200)
                                     title: @"QuirkProbe Level"];
  NSView *content = [window contentView];
  NSLevelIndicator *unset = QuirkProbeLevelIndicator(content, NSMakeRect(20, 160, 200, 20),
    NSContinuousCapacityLevelIndicatorStyle, 10.0, 6.0, 0.0, 0.0);
  NSLevelIndicator *critical = QuirkProbeLevelIndicator(content, NSMakeRect(20, 120, 200, 20),
    NSContinuousCapacityLevelIndicatorStyle, 10.0, 6.0, 3.0, 5.0);
  NSLevelIndicator *discrete = QuirkProbeLevelIndicator(content, NSMakeRect(20, 80, 200, 20),
    NSDiscreteCapacityLevelIndicatorStyle, 10.0, 6.0, 0.0, 0.0);
  NSLevelIndicator *rating = QuirkProbeLevelIndicator(content, NSMakeRect(20, 40, 200, 20),
    NSRatingLevelIndicatorStyle, 5.0, 3.0, 0.0, 0.0);
  NSBitmapImageRep *rep = nil;
  CGFloat scale;
  QuirkProbeInk accent, red;

  if (QuirkProbeHasArgument(@"--high-contrast", nil))
    {
      [self skip: @"level-unset-thresholds" detail: @"high contrast's highlight may not be blue"];
      [self skip: @"level-critical" detail: @"high contrast keeps the highlight colour"];
      [self skip: @"level-discrete-segments" detail: @"high contrast's highlight may not be blue"];
      [self skip: @"level-rating" detail: @"high contrast's highlight may not be blue"];
      return;
    }
  [window orderFront: nil];
  [window display];

  /* 6 of 10, thresholds unset: a 3px accent bar 60% along, no red. */
  rep = QuirkProbeRender(unset);
  scale = QuirkProbeScale(rep, unset);
  [self saveView: unset named: @"level-unset"];
  accent = QuirkProbeMeasureIn(rep, QuirkProbeIsAccentBlue, NSZeroRect);
  red = QuirkProbeMeasureIn(rep, QuirkProbeIsCriticalRed, NSZeroRect);
  if (red.count == 0 && accent.count > 0
      && fabs((accent.minX + accent.width) / scale - 120.0) <= 3.0
      && fabs(accent.height - 3.0 * scale) <= 1.0)
    {
      [self pass: @"level-unset-thresholds" detail: [NSString stringWithFormat:
        @"a %ld px accent bar to %.0fpt of 200, no red",
        (long)accent.height, (accent.minX + accent.width) / scale]];
    }
  else
    {
      [self fail: @"level-unset-thresholds" detail: [NSString stringWithFormat:
        @"%lu red px; accent %ld px deep to %.0fpt (expected 3 px to 120pt)",
        (unsigned long)red.count, (long)accent.height,
        accent.count > 0 ? (accent.minX + accent.width) / scale : 0.0]];
    }

  /* 6 of 10 with the critical value at 5: the critical colour, as long. */
  rep = QuirkProbeRender(critical);
  [self saveView: critical named: @"level-critical"];
  accent = QuirkProbeMeasureIn(rep, QuirkProbeIsAccentBlue, NSZeroRect);
  red = QuirkProbeMeasureIn(rep, QuirkProbeIsCriticalRed, NSZeroRect);
  if (accent.count == 0 && red.count > 0
      && fabs((red.minX + red.width) / scale - 120.0) <= 3.0
      && fabs(red.height - 3.0 * scale) <= 1.0)
    {
      [self pass: @"level-critical" detail: [NSString stringWithFormat:
        @"past the critical value, a %ld px critical bar to %.0fpt",
        (long)red.height, (red.minX + red.width) / scale]];
    }
  else
    {
      [self fail: @"level-critical" detail: [NSString stringWithFormat:
        @"%lu accent px; critical %ld px deep to %.0fpt (expected 3 px to 120pt)",
        (unsigned long)accent.count, (long)red.height,
        red.count > 0 ? (red.minX + red.width) / scale : 0.0]];
    }

  /* Discrete, 6 of 10: six accent segments. */
  rep = QuirkProbeRender(discrete);
  [self saveView: discrete named: @"level-discrete"];
  accent = QuirkProbeMeasureIn(rep, QuirkProbeIsAccentBlue, NSZeroRect);
  {
    NSInteger x, y = accent.minY + accent.height / 2;
    NSUInteger runs = 0;
    BOOL inRun = NO;

    for (x = 0; accent.count > 0 && x < [rep pixelsWide]; x++)
      {
        NSUInteger r, g, b;
        BOOL hit = QuirkProbePixel(rep, x, y, &r, &g, &b) && QuirkProbeIsAccentBlue(r, g, b);

        if (hit && inRun == NO)
          {
            runs++;
          }
        inRun = hit;
      }
    if (runs == 6 && fabs(accent.height - 3.0 * scale) <= 1.0)
      {
        [self pass: @"level-discrete-segments" detail: @"6 of 10: six 3px accent segments"];
      }
    else
      {
        [self fail: @"level-discrete-segments" detail: [NSString stringWithFormat:
          @"6 of 10 drew %lu accent segments, %ld px deep", (unsigned long)runs, (long)accent.height]];
      }
  }

  /* Rating 3 of 5: accent stars up to the third, outlines after. */
  rep = QuirkProbeRender(rating);
  [self saveView: rating named: @"level-rating"];
  accent = QuirkProbeMeasureIn(rep, QuirkProbeIsAccentBlue, NSZeroRect);
  {
    NSUInteger background = QuirkProbeInkBackground, r, g, b;
    QuirkProbeInk outline;

    QuirkProbePixel(rep, [rep pixelsWide] - 1, 0, &r, &g, &b);
    QuirkProbeInkBackground = r + g + b;
    outline = QuirkProbeMeasureIn(rep, QuirkProbeIsFaintInk,
                                  NSMakeRect(accent.minX + accent.width + 2, 0,
                                             [rep pixelsWide], [rep pixelsHigh]));
    QuirkProbeInkBackground = background;
    /* Three 16pt stars 8pt apart end at 64pt; two outlines follow. */
    if (accent.count > 0 && fabs((accent.minX + accent.width) / scale - 64.0) <= 2.0
        && accent.height >= 12.0 * scale && outline.count > 0
        && fabs((outline.minX + outline.width) / scale - 112.0) <= 2.0)
      {
        [self pass: @"level-rating" detail: [NSString stringWithFormat:
          @"accent stars to %.0fpt, outlines to %.0fpt",
          (accent.minX + accent.width) / scale, (outline.minX + outline.width) / scale]];
      }
    else
      {
        [self fail: @"level-rating" detail: [NSString stringWithFormat:
          @"accent %lu px to %.0fpt, %ld px high; outlines to %.0fpt (expected 64, 16 high, 112)",
          (unsigned long)accent.count,
          accent.count > 0 ? (accent.minX + accent.width) / scale : 0.0, (long)accent.height,
          outline.count > 0 ? (outline.minX + outline.width) / scale : 0.0]];
      }
  }
  [window orderOut: nil];
}

/* How many columns of `area` (pixels) have accepted pixels in at least
   `minimum` of its rows, and the first of them in `first`. */
static NSUInteger
QuirkProbeSolidColumns(NSBitmapImageRep *rep, QuirkProbePixelTest test, NSRect area,
                       NSUInteger minimum, NSInteger *first)
{
  NSUInteger solid = 0;
  NSInteger x;

  if (first != NULL)
    {
      *first = -1;
    }
  for (x = (NSInteger)NSMinX(area); x < (NSInteger)NSMaxX(area); x++)
    {
      if (QuirkProbeColumnCount(rep, test, x, (NSInteger)NSMinY(area), (NSInteger)NSMaxY(area)) >= minimum)
        {
          if (first != NULL && *first < 0)
            {
              *first = x;
            }
          solid++;
        }
    }
  return solid;
}

/* YES when Windows' time format is a 12-hour clock. */
static BOOL
QuirkProbeTwelveHourClock(void)
{
#ifdef _WIN32
  wchar_t format[80];

  if (GetLocaleInfoEx(LOCALE_NAME_USER_DEFAULT, LOCALE_STIMEFORMAT, format, 80) > 0)
    {
      return wcschr(format, L'H') == NULL;
    }
#endif
  return YES;
}

- (void) datePickerChanged: (id)sender
{
  _datePickerActions++;
}

/* Renders the date picker flyout while it's open, then accepts it with
   Enter (see checkDatePicker). */
- (void) inspectDatePickerFlyout: (NSTimer *)timer
{
  NSEnumerator *enumerator = [[NSApp windows] objectEnumerator];
  NSWindow *window = nil;
  NSView *flyout = nil;
  NSWindow *owner = [timer userInfo];

  while ((window = [enumerator nextObject]) != nil)
    {
      if ([window isVisible]
          && [NSStringFromClass([[window contentView] class]) isEqualToString: @"WinUIThemeDatePickerFlyoutView"])
        {
          flyout = [window contentView];
        }
    }
  if (flyout == nil)
    {
      [self fail: @"date-picker-flyout-band" detail: @"no flyout opened"];
    }
  else
    {
      NSBitmapImageRep *rep = QuirkProbeRender(flyout);
      CGFloat scale = QuirkProbeScale(rep, flyout);
      QuirkProbeInk band = QuirkProbeMeasureIn(rep, QuirkProbeIsAccentBlue, NSZeroRect);
      CGFloat centre = (band.minY + band.height / 2.0) / scale;

      [self saveView: flyout named: @"date-picker-flyout"];
      if (band.count > 0 && band.width >= [rep pixelsWide] - 10 * scale
          && fabs(band.height / scale - 36.0) <= 2.0 && fabs(centre - 180.0) <= 2.0)
        {
          [self pass: @"date-picker-flyout-band" detail: [NSString stringWithFormat:
            @"an accent band %.0fx%.0fpt across the flyout's middle row",
            band.width / scale, band.height / scale]];
        }
      else
        {
          [self fail: @"date-picker-flyout-band" detail: [NSString stringWithFormat:
            @"accent %ldx%ld px centred %.0fpt down (expected the flyout's width, 36pt, at 180pt)",
            (long)band.width, (long)band.height, centre]];
        }
    }
  [NSApp postEvent: [NSEvent keyEventWithType: NSKeyDown
                                     location: NSZeroPoint
                                modifierFlags: 0
                                    timestamp: 0
                                 windowNumber: [owner windowNumber]
                                      context: nil
                                   characters: @"\r"
                  charactersIgnoringModifiers: @"\r"
                                    isARepeat: NO
                                      keyCode: 0]
           atStart: NO];
  /* Ends the click's tracking where no flyout took it. */
  [NSApp postEvent: [NSEvent mouseEventWithType: NSLeftMouseUp
                                       location: NSMakePoint(80, 386)
                                  modifierFlags: 0
                                      timestamp: 0
                                   windowNumber: [owner windowNumber]
                                        context: nil
                                    eventNumber: 0
                                     clickCount: 1
                                       pressure: 0.0]
           atStart: NO];
}

/* NSDatePicker as WinUI's DatePicker, TimePicker and CalendarView (issue
   #56). gui 0.32 drew "2026-10-05 19:00:00 -0500" as plain text, with no
   chrome and no way to edit it. */
- (void) checkDatePicker
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(120, 120, 640, 420)
                                     title: @"QuirkProbe Date Picker"];
  NSView *content = [window contentView];
  NSDatePicker *date = AUTORELEASE([[NSDatePicker alloc] initWithFrame: NSMakeRect(20, 370, 296, 32)]);
  NSDatePicker *time = AUTORELEASE([[NSDatePicker alloc] initWithFrame: NSMakeRect(340, 370, 242, 32)]);
  NSDatePicker *calendar = AUTORELEASE([[NSDatePicker alloc] initWithFrame: NSMakeRect(20, 0, 300, 360)]);
  NSCalendarDate *day = [NSCalendarDate dateWithYear: 2026 month: 10 day: 5 hour: 19 minute: 0 second: 0
                                            timeZone: [NSTimeZone timeZoneWithName: @"America/Chicago"]];
  NSBitmapImageRep *rep = nil;
  CGFloat scale;
  NSUInteger red, green, blue;
  BOOL highContrast = QuirkProbeHasArgument(@"--high-contrast", nil);

  [date setDatePickerElements: NSYearMonthDayDatePickerElementFlag];
  [date setTimeZone: [NSTimeZone timeZoneWithName: @"America/Chicago"]];
  [date setDateValue: day];
  [date setTarget: self];
  [date setAction: @selector(datePickerChanged:)];
  [time setDatePickerElements: NSHourMinuteDatePickerElementFlag];
  [time setTimeZone: [NSTimeZone timeZoneWithName: @"America/Chicago"]];
  [time setDateValue: day];
  [calendar setDatePickerStyle: NSClockAndCalendarDatePickerStyle];
  [calendar setDatePickerElements: NSYearMonthDayDatePickerElementFlag];
  [calendar setDateValue: [NSDate date]];
  [content addSubview: date];
  [content addSubview: time];
  [content addSubview: calendar];
  [window orderFront: nil];
  [window display];

  /* The DatePicker field: a rounded border, dividers 136pt and 216pt in,
     and a short label in each part: no time zone, no time. */
  rep = QuirkProbeRender(date);
  scale = QuirkProbeScale(rep, date);
  [self saveView: date named: @"date-picker-field"];
  QuirkProbePixel(rep, [rep pixelsWide] / 2, 2 * scale, &red, &green, &blue);
  QuirkProbeInkBackground = red + green + blue;
  {
    NSInteger height = [rep pixelsHigh];
    NSRect inside = NSMakeRect(0, 4 * scale, [rep pixelsWide], height - 8 * scale);
    NSInteger divider1 = -1, divider2 = -1;
    NSUInteger lines1 = QuirkProbeSolidColumns(rep, QuirkProbeIsFaintInk,
                                               NSMakeRect(130 * scale, 4 * scale, 12 * scale, height - 8 * scale),
                                               height - 9 * scale, &divider1);
    NSUInteger lines2 = QuirkProbeSolidColumns(rep, QuirkProbeIsFaintInk,
                                               NSMakeRect(210 * scale, 4 * scale, 12 * scale, height - 8 * scale),
                                               height - 9 * scale, &divider2);
    QuirkProbeInk month = QuirkProbeMeasureIn(rep, QuirkProbeIsInk,
                                              NSMakeRect(2 * scale, NSMinY(inside), 128 * scale, NSHeight(inside)));
    QuirkProbeInk dayInk = QuirkProbeMeasureIn(rep, QuirkProbeIsInk,
                                               NSMakeRect(142 * scale, NSMinY(inside), 68 * scale, NSHeight(inside)));
    QuirkProbeInk year = QuirkProbeMeasureIn(rep, QuirkProbeIsInk,
                                             NSMakeRect(222 * scale, NSMinY(inside), 70 * scale, NSHeight(inside)));
    NSUInteger edgeRed, edgeGreen, edgeBlue;

    QuirkProbePixel(rep, 0, height / 2, &edgeRed, &edgeGreen, &edgeBlue);
    if (lines1 >= 1 && lines1 <= 2 * ceil(scale) && lines2 >= 1 && lines2 <= 2 * ceil(scale)
        && fabs(divider1 / scale - 136.0) <= 2.0 && fabs(divider2 / scale - 216.0) <= 2.0
        && llabs((long long)(edgeRed + edgeGreen + edgeBlue) - (long long)QuirkProbeInkBackground) >= 12
        && fabs(height / scale - 32.0) <= 1.0)
      {
        [self pass: @"date-picker-field" detail: [NSString stringWithFormat:
          @"a bordered 32pt field, dividers at %.0f and %.0fpt", divider1 / scale, divider2 / scale]];
      }
    else
      {
        [self fail: @"date-picker-field" detail: [NSString stringWithFormat:
          @"dividers %lu px at %.0fpt and %lu px at %.0fpt (expected 136, 216); edge %lu of %lu; %.0fpt high",
          (unsigned long)lines1, divider1 / scale, (unsigned long)lines2, divider2 / scale,
          (unsigned long)(edgeRed + edgeGreen + edgeBlue), (unsigned long)QuirkProbeInkBackground,
          height / scale]];
      }
    /* The month from 12pt in; "5" centred in its 80pt; "2026" in its,
       with room to spare even in large text. */
    if (month.count > 0 && fabs(month.minX / scale - 12.0) <= 2.5
        && dayInk.count > 0 && dayInk.width / scale <= 24.0
        && fabs((dayInk.minX + dayInk.width / 2.0) / scale - 176.0) <= 3.0
        && year.count > 0 && year.width / scale <= 56.0
        && fabs((year.minX + year.width / 2.0) / scale - 256.0) <= 3.0)
      {
        [self pass: @"date-picker-no-offset" detail: [NSString stringWithFormat:
          @"month %.0fpt in, day %.0fpt and year %.0fpt wide, centred: no time or zone",
          month.minX / scale, dayInk.width / scale, year.width / scale]];
      }
    else
      {
        [self fail: @"date-picker-no-offset" detail: [NSString stringWithFormat:
          @"month ink from %.0fpt, day %.0fpt wide at %.0f, year %.0fpt wide at %.0f",
          month.count ? month.minX / scale : -1.0,
          dayInk.width / scale, dayInk.count ? (dayInk.minX + dayInk.width / 2.0) / scale : -1.0,
          year.width / scale, year.count ? (year.minX + year.width / 2.0) / scale : -1.0]];
      }
  }

  /* The TimePicker field: hour, minute and (on a 12-hour clock) AM/PM in
     equal columns, each with its label. */
  rep = QuirkProbeRender(time);
  [self saveView: time named: @"time-picker-field"];
  {
    NSUInteger columns = QuirkProbeTwelveHourClock() ? 3 : 2;
    CGFloat width = 242.0 / columns;
    NSUInteger index, labelled = 0, dividers = 0;

    for (index = 0; index < columns; index++)
      {
        QuirkProbeInk ink = QuirkProbeMeasureIn(rep, QuirkProbeIsInk,
                                                NSMakeRect((index * width + 4) * scale, 4 * scale,
                                                           (width - 8) * scale, [rep pixelsHigh] - 8 * scale));

        if (ink.count > 0 && fabs((ink.minX + ink.width / 2.0) / scale - (index + 0.5) * width) <= 3.0)
          {
            labelled++;
          }
        if (index > 0 && QuirkProbeSolidColumns(rep, QuirkProbeIsFaintInk,
                                                NSMakeRect((index * width - 3) * scale, 4 * scale, 6 * scale,
                                                           [rep pixelsHigh] - 8 * scale),
                                                [rep pixelsHigh] - 9 * scale, NULL) > 0)
          {
            dividers++;
          }
      }
    if (labelled == columns && dividers == columns - 1)
      {
        [self pass: @"time-picker-field" detail: [NSString stringWithFormat:
          @"%lu centred parts between %lu dividers", (unsigned long)columns, (unsigned long)dividers]];
      }
    else
      {
        [self fail: @"time-picker-field" detail: [NSString stringWithFormat:
          @"%lu of %lu parts centred, %lu dividers", (unsigned long)labelled,
          (unsigned long)columns, (unsigned long)dividers]];
      }
  }

  /* CalendarView: today, picked, filled with the accent and ringed. */
  rep = QuirkProbeRender(calendar);
  scale = QuirkProbeScale(rep, calendar);
  [self saveView: calendar named: @"date-picker-calendar"];
  if (highContrast)
    {
      [self skip: @"date-picker-calendar" detail: @"high contrast's highlight may not be blue"];
    }
  else
    {
      QuirkProbeInk today = QuirkProbeMeasureIn(rep, QuirkProbeIsAccentBlue, NSZeroRect);

      if (today.count > 0 && today.width / scale >= 32.0 && today.width / scale <= 44.0
          && today.height / scale >= 32.0 && today.height / scale <= 44.0)
        {
          [self pass: @"date-picker-calendar" detail: [NSString stringWithFormat:
            @"today is an accent circle %.0fpt across", today.width / scale]];
        }
      else
        {
          [self fail: @"date-picker-calendar" detail: [NSString stringWithFormat:
            @"the accent covers %.0fx%.0fpt (%lu px); expected one day's circle",
            today.width / scale, today.height / scale, (unsigned long)today.count]];
        }
    }

  /* The flyout: a click opens it over the field; Down moves the month on
     and Enter accepts. inspectDatePickerFlyout: renders it while open. */
  if (highContrast)
    {
      [self skip: @"date-picker-flyout-band" detail: @"high contrast's highlight may not be blue"];
      [self skip: @"date-picker-flyout-pick" detail: @"needs the flyout band check"];
      [window orderOut: nil];
      return;
    }
  {
    NSTimer *timer = [NSTimer timerWithTimeInterval: 0.3
                                             target: self
                                           selector: @selector(inspectDatePickerFlyout:)
                                           userInfo: window
                                            repeats: NO];
    NSEvent *click = [NSEvent mouseEventWithType: NSLeftMouseDown
                                        location: [date convertPoint: NSMakePoint(60, 16) toView: nil]
                                   modifierFlags: 0
                                       timestamp: 0
                                    windowNumber: [window windowNumber]
                                         context: nil
                                     eventNumber: 0
                                      clickCount: 1
                                        pressure: 1.0];
    NSCalendarDate *picked = nil;

    [[NSRunLoop currentRunLoop] addTimer: timer forMode: NSEventTrackingRunLoopMode];
    [NSApp postEvent: [NSEvent keyEventWithType: NSKeyDown
                                       location: NSZeroPoint
                                  modifierFlags: 0
                                      timestamp: 0
                                   windowNumber: [window windowNumber]
                                        context: nil
                                     characters: [NSString stringWithFormat: @"%C", (unichar)NSDownArrowFunctionKey]
                    charactersIgnoringModifiers: [NSString stringWithFormat: @"%C", (unichar)NSDownArrowFunctionKey]
                                      isARepeat: NO
                                        keyCode: 0]
             atStart: NO];
    _datePickerActions = 0;
    [date mouseDown: click];
    [timer invalidate];

    picked = [[date dateValue] dateWithCalendarFormat: nil
                                              timeZone: [NSTimeZone timeZoneWithName: @"America/Chicago"]];
    if ([picked yearOfCommonEra] == 2026 && [picked monthOfYear] == 11 && [picked dayOfMonth] == 5
        && _datePickerActions == 1)
      {
        [self pass: @"date-picker-flyout-pick" detail: @"Down and Enter in the flyout picked November 5, and sent the action"];
      }
    else
      {
        [self fail: @"date-picker-flyout-pick" detail: [NSString stringWithFormat:
          @"after Down and Enter the date is %@ (%lu actions); expected 2026-11-05",
          [picked descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M %z"],
          (unsigned long)_datePickerActions]];
      }
  }
  [window orderOut: nil];
}

static NSBrowser *
QuirkProbeBrowser(QuirkProbe *probe, NSView *content, NSRect frame, NSInteger leafColumn, NSInteger depth)
{
  NSBrowser *browser = AUTORELEASE([[NSBrowser alloc] initWithFrame: frame]);
  NSInteger column;

  [browser setTag: leafColumn];
  [browser setDelegate: (id)probe];
  [browser setMaxVisibleColumns: 3];
  [browser setTitled: NO];
  [content addSubview: browser];
  [browser loadColumnZero];
  for (column = 0; column < depth; column++)
    {
      [browser selectRow: (column == 0) ? 2 : 1 inColumn: column];
    }
  return browser;
}

/* NSBrowser as WinUI lists side by side (issue #58): ListView's selection
   (a subtle fill and a 3pt accent pill) rather than a saturated bar with
   white text, a secondary chevron on branch rows, and no horizontal
   scroller while every column fits; when there are columns to scroll to,
   WinUI's thin bar. libs-gui drew the scroller as a heavy grey strip under
   the columns, always. */
- (void) checkBrowser
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(160, 140, 600, 420)
                                     title: @"QuirkProbe Browser"];
  NSView *content = [window contentView];
  NSBrowser *fits = QuirkProbeBrowser(self, content, NSMakeRect(20, 220, 540, 170), 2, 2);
  NSBrowser *scrolls = QuirkProbeBrowser(self, content, NSMakeRect(20, 20, 540, 170), 5, 4);
  NSScrollView *column = nil;
  NSMatrix *matrix = nil;
  NSBitmapImageRep *rep = nil;
  NSScroller *scroller = nil;
  CGFloat scale;
  NSUInteger red, green, blue;
  BOOL highContrast = QuirkProbeHasArgument(@"--high-contrast", nil);

  /* Key, so the pill is the accent. */
  [window makeKeyAndOrderFront: nil];
  [window display];

  /* The selection in the first column: row 2. */
  matrix = [fits matrixInColumn: 0];
  column = [matrix enclosingScrollView];
  if (matrix == nil || column == nil)
    {
      [self fail: @"browser-selection" detail: @"the browser has no first column"];
      [window orderOut: nil];
      return;
    }
  rep = QuirkProbeRender(column);
  scale = QuirkProbeScale(rep, column);
  [self saveView: column named: @"browser-column"];
  if (highContrast)
    {
      [self skip: @"browser-selection" detail: @"high contrast keeps the system highlight"];
    }
  else
    {
      NSRect row = [column convertRect: [matrix cellFrameAtRow: 2 column: 0] fromView: matrix];
      NSRect pixels = QuirkProbePixelRect(column, row, scale);
      QuirkProbeInk accent = QuirkProbeMeasureIn(rep, QuirkProbeIsAccentBlue, pixels);
      NSUInteger fill, card;

      QuirkProbePixel(rep, (NSInteger)(NSMinX(pixels) + 90 * scale), (NSInteger)NSMidY(pixels) - 6 * scale,
                      &red, &green, &blue);
      fill = red + green + blue;
      QuirkProbePixel(rep, (NSInteger)(NSMinX(pixels) + 90 * scale), (NSInteger)NSMaxY(pixels) + 6 * scale,
                      &red, &green, &blue);
      card = red + green + blue;
      if (accent.count > 0 && accent.width <= ceil(3.0 * scale) + 1
          && (accent.minX - NSMinX(pixels)) / scale <= 8.0
          && llabs((long long)fill - (long long)card) >= 3 && llabs((long long)fill - (long long)card) <= 60)
        {
          [self pass: @"browser-selection" detail: [NSString stringWithFormat:
            @"a %ld px accent pill %.0fpt in; a subtle fill (%lu over the card's %lu)",
            (long)accent.width, (accent.minX - NSMinX(pixels)) / scale,
            (unsigned long)fill, (unsigned long)card]];
        }
      else
        {
          [self fail: @"browser-selection" detail: [NSString stringWithFormat:
            @"accent %ld px wide from %.0fpt; the row's fill %lu over the card's %lu",
            (long)accent.width, accent.count ? (accent.minX - NSMinX(pixels)) / scale : -1.0,
            (unsigned long)fill, (unsigned long)card]];
        }
    }

  /* A branch row's chevron, fainter than its title; none on a leaf. */
  {
    NSRect branch = QuirkProbePixelRect(column, [column convertRect: [matrix cellFrameAtRow: 0 column: 0]
                                                           fromView: matrix], scale);
    NSScrollView *leaves = [[fits matrixInColumn: 2] enclosingScrollView];
    NSUInteger titleContrast = 0, chevronContrast = 0, background;
    NSInteger x, y;
    QuirkProbeInk chevron, leafInk = { 0, 0, 0, 0, 0 };

    /* The row's top edge, clear of its title at any text size. */
    QuirkProbePixel(rep, (NSInteger)NSMidX(branch), (NSInteger)NSMinY(branch) + 1, &red, &green, &blue);
    background = red + green + blue;
    QuirkProbeInkBackground = background;
    chevron = QuirkProbeMeasureIn(rep, QuirkProbeIsFaintInk,
                                  NSMakeRect(NSMaxX(branch) - 28 * scale, NSMinY(branch),
                                             20 * scale, NSHeight(branch)));
    for (y = (NSInteger)NSMinY(branch); y < (NSInteger)NSMaxY(branch); y++)
      {
        for (x = (NSInteger)NSMinX(branch); x < (NSInteger)NSMaxX(branch); x++)
          {
            NSUInteger contrast;

            QuirkProbePixel(rep, x, y, &red, &green, &blue);
            contrast = (NSUInteger)llabs((long long)(red + green + blue) - (long long)background);
            if (x >= NSMaxX(branch) - 28 * scale)
              {
                chevronContrast = MAX(chevronContrast, contrast);
              }
            else
              {
                titleContrast = MAX(titleContrast, contrast);
              }
          }
      }
    if (leaves != nil)
      {
        NSBitmapImageRep *leafRep = QuirkProbeRender(leaves);
        NSMatrix *leafMatrix = [fits matrixInColumn: 2];
        NSRect leaf = QuirkProbePixelRect(leaves, [leaves convertRect: [leafMatrix cellFrameAtRow: 0 column: 0]
                                                             fromView: leafMatrix], scale);

        QuirkProbePixel(leafRep, (NSInteger)NSMidX(leaf), (NSInteger)NSMinY(leaf) + 1, &red, &green, &blue);
        QuirkProbeInkBackground = red + green + blue;
        leafInk = QuirkProbeMeasureIn(leafRep, QuirkProbeIsFaintInk,
                                      NSMakeRect(NSMaxX(leaf) - 28 * scale, NSMinY(leaf) + 2 * scale,
                                                 20 * scale, NSHeight(leaf) - 4 * scale));
      }
    if (chevron.count > 0 && chevron.width / scale <= 7.0 && chevron.height / scale <= 11.0
        && (highContrast || chevronContrast < titleContrast) && leaves != nil && leafInk.count == 0)
      {
        [self pass: @"browser-chevron" detail: [NSString stringWithFormat:
          @"a %.0fx%.0fpt chevron at %lu contrast (the title's %lu); none on a leaf",
          chevron.width / scale, chevron.height / scale,
          (unsigned long)chevronContrast, (unsigned long)titleContrast]];
      }
    else
      {
        [self fail: @"browser-chevron" detail: [NSString stringWithFormat:
          @"the branch mark is %.0fx%.0fpt at %lu contrast (the title's %lu); %lu px on a leaf",
          chevron.width / scale, chevron.height / scale, (unsigned long)chevronContrast,
          (unsigned long)titleContrast, (unsigned long)leafInk.count]];
      }
  }

  /* Every column fits: no horizontal scroller, and the columns reach the
     browser's foot. */
  {
    NSRect last = [[[fits matrixInColumn: 2] enclosingScrollView] frame];
    CGFloat foot = [fits isFlipped] ? NSHeight([fits bounds]) - NSMaxY(last) : NSMinY(last);
    NSScroller *horizontal = nil;
    NSEnumerator *enumerator = [[fits subviews] objectEnumerator];
    NSView *subview = nil;

    while ((subview = [enumerator nextObject]) != nil)
      {
        if ([subview isKindOfClass: [NSScroller class]])
          {
            horizontal = (NSScroller *)subview;
          }
      }
    if ((horizontal == nil || [horizontal isHidden]) && foot <= 1.0)
      {
        [self pass: @"browser-scroller-hidden" detail: @"all three columns fit: no scroller, the columns reach the foot"];
      }
    else
      {
        [self fail: @"browser-scroller-hidden" detail: [NSString stringWithFormat:
          @"the scroller is %@, the columns stop %.0fpt above the foot",
          (horizontal == nil || [horizontal isHidden]) ? @"hidden" : @"shown", foot]];
      }
  }

  /* Five columns in three: the thin bar, its 6pt thumb. */
  {
    NSEnumerator *enumerator = [[scrolls subviews] objectEnumerator];
    NSView *subview = nil;

    while ((subview = [enumerator nextObject]) != nil)
      {
        if ([subview isKindOfClass: [NSScroller class]])
          {
            scroller = (NSScroller *)subview;
          }
      }
    if (scroller == nil || [scroller isHidden])
      {
        [self fail: @"browser-scroller-shown" detail: @"five columns in three, and no scroller"];
      }
    else
      {
        NSBitmapImageRep *bar = nil;
        QuirkProbeInk thumb;

        [scrolls display];
        bar = QuirkProbeRender(scrolls);
        scale = QuirkProbeScale(bar, scrolls);
        [self saveView: scrolls named: @"browser-scrolls"];
        /* The strip's edge, beside the thumb. */
        {
          NSRect strip = QuirkProbePixelRect(scrolls, [scroller frame], scale);

          QuirkProbePixel(bar, (NSInteger)NSMidX(strip), (NSInteger)NSMinY(strip), &red, &green, &blue);
          QuirkProbeInkBackground = red + green + blue;
        }
        thumb = QuirkProbeMeasureIn(bar, QuirkProbeIsInk,
                                    QuirkProbePixelRect(scrolls, NSInsetRect([scroller frame], 16.0, 0.0), scale));
        if (thumb.count > 0 && thumb.height / scale <= 7.0 && thumb.width / scale >= 40.0)
          {
            [self pass: @"browser-scroller-shown" detail: [NSString stringWithFormat:
              @"five columns in three: a %.0fpt thumb %.0fpt long", thumb.height / scale, thumb.width / scale]];
          }
        else
          {
            [self fail: @"browser-scroller-shown" detail: [NSString stringWithFormat:
              @"the scroller's ink is %.0fx%.0fpt; expected a thin thumb",
              thumb.width / scale, thumb.height / scale]];
          }
      }
  }

  /* A column whose rows fit shows no scroll bar (the strip clear of the
     card's corners). */
  {
    NSRect strip = NSMakeRect(NSWidth([column bounds]) - 7.0, 8.0, 5.0, NSHeight([column bounds]) - 16.0);
    QuirkProbeInk bar;

    rep = QuirkProbeRender(column);
    scale = QuirkProbeScale(rep, column);
    QuirkProbePixel(rep, (NSInteger)(NSWidth([column bounds]) * scale / 2),
                    [rep pixelsHigh] - (NSInteger)(10 * scale), &red, &green, &blue);
    QuirkProbeInkBackground = red + green + blue;
    bar = QuirkProbeMeasureIn(rep, QuirkProbeIsInk, QuirkProbePixelRect(column, strip, scale));
    if (bar.count == 0)
      {
        [self pass: @"browser-column-scroller" detail: @"a column whose rows fit shows no scroll bar"];
      }
    else
      {
        [self fail: @"browser-column-scroller" detail: [NSString stringWithFormat:
          @"%lu px of scroll bar beside rows that fit", (unsigned long)bar.count]];
      }
  }
  [window orderOut: nil];
}

/* What's wrong with a "TTTT" title drawn in `pixels` (a render's pixel
   rect, top-left origin) over the window colour `window` (red + green +
   blue), or nil. It should sit on no bezel (the rect's trailing end is
   the window's colour), be upright (the T's crossbars, its heaviest row,
   in the top third of its ink), whole (clear of the rect's top and
   bottom, at least 6pt tall), and start `textEdge` pixels in, give or
   take 2pt. */
static NSString *
QuirkProbeColumnTitleProblem(NSBitmapImageRep *rep, NSRect pixels, CGFloat scale,
                             NSUInteger window, CGFloat textEdge, NSString **measured)
{
  NSUInteger red = 0, green = 0, blue = 0, background, heaviest = 0;
  NSInteger y, heaviestY = 0;
  QuirkProbeInk ink;

  QuirkProbePixel(rep, (NSInteger)(NSMaxX(pixels) - 6 * scale), (NSInteger)NSMidY(pixels), &red, &green, &blue);
  background = red + green + blue;
  QuirkProbeInkBackground = window;
  ink = QuirkProbeMeasureIn(rep, QuirkProbeIsInk, pixels);
  for (y = ink.minY; ink.count > 0 && y < ink.minY + ink.height; y++)
    {
      NSUInteger count = QuirkProbeRowCount(rep, QuirkProbeIsInk, y, (NSInteger)NSMinX(pixels), (NSInteger)NSMaxX(pixels));

      if (count > heaviest)
        {
          heaviest = count;
          heaviestY = y;
        }
    }
  *measured = [NSString stringWithFormat:
    @"ink %.0fx%.0fpt, %.0fpt in and %.0fpt down the %.0fpt rect, heaviest row %.0fpt down the ink; behind it %lu (window %lu)",
    ink.width / scale, ink.height / scale, (ink.minX - NSMinX(pixels)) / scale,
    (ink.minY - NSMinY(pixels)) / scale, NSHeight(pixels) / scale, (heaviestY - ink.minY) / scale,
    (unsigned long)background, (unsigned long)window];
  if (llabs((long long)background - (long long)window) > 9)
    {
      return @"a bezel behind the title";
    }
  if (ink.count == 0)
    {
      return @"no title";
    }
  if (ink.minY <= (NSInteger)NSMinY(pixels) || ink.minY + ink.height >= (NSInteger)NSMaxY(pixels)
      || ink.height < 6.0 * scale)
    {
      return @"the title is cut off";
    }
  if ((heaviestY - ink.minY) * 3 > ink.height)
    {
      return @"the title is upside down";
    }
  if (fabs((ink.minX - NSMinX(pixels)) - textEdge) > 2.0 * scale)
    {
      return @"the title isn't at the rows' text edge";
    }
  return nil;
}

/* Column titles (#74): the font panel's "Family" and "Typeface" were drawn
   upside down and cut in half, on libs-gui's grey bezel, and its "Size"
   label (a text field with the browser's title cell) on the bezel too.
   WinUI has no titled list column; the nearest, a section label, is
   secondary text on the window, no bezel, at the rows' text edge. Two
   titled browsers, one in the window and one as the font panel has them
   (a plain view in a flipped split view), and that label. */
- (void) checkBrowserTitles
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(180, 160, 560, 300)
                                     title: @"QuirkProbe Browser Titles"];
  NSView *content = [window contentView];
  NSView *flipped = AUTORELEASE([[QuirkProbeFlippedView alloc] initWithFrame: NSMakeRect(330, 10, 220, 280)]);
  NSView *pane = AUTORELEASE([[NSView alloc] initWithFrame: NSMakeRect(0, 0, 220, 280)]);
  NSBrowser *plain = AUTORELEASE([[NSBrowser alloc] initWithFrame: NSMakeRect(20, 20, 290, 220)]);
  NSBrowser *nested = AUTORELEASE([[NSBrowser alloc] initWithFrame: NSMakeRect(0, 0, 120, 220)]);
  Class titleCellClass = NSClassFromString(@"GSBrowserTitleCell");
  NSTextField *label = AUTORELEASE([[NSTextField alloc] initWithFrame: NSMakeRect(130, 199, 80, 21)]);
  NSBitmapImageRep *rep = nil;
  NSMatrix *matrix = nil;
  NSUInteger red = 0, green = 0, blue = 0, windowSum, card;
  CGFloat scale, textEdge;
  NSArray *browsers = [NSArray arrayWithObjects: plain, nested, nil];
  NSUInteger index;

  [content addSubview: flipped];
  [flipped addSubview: pane];
  [content addSubview: plain];
  [pane addSubview: nested];
  for (index = 0; index < [browsers count]; index++)
    {
      NSBrowser *browser = [browsers objectAtIndex: index];

      [browser setTag: 100];
      [browser setDelegate: (id)self];
      [browser setMaxVisibleColumns: 1];
      [browser setHasHorizontalScroller: NO];
      [browser setTitled: YES];
      [browser loadColumnZero];
      [browser setTitle: @"TTTT" ofColumn: 0];
    }
  if (titleCellClass != Nil)
    {
      [label setCell: AUTORELEASE([titleCellClass new])];
    }
  [label setFont: [NSFont boldSystemFontOfSize: 0]];
  [label setAlignment: NSCenterTextAlignment];
  [label setDrawsBackground: YES];
  [label setEditable: NO];
  [label setTextColor: [NSColor windowFrameTextColor]];
  [label setBackgroundColor: [NSColor controlShadowColor]];
  [label setStringValue: @"TTTT"];
  [pane addSubview: label];

  [window makeKeyAndOrderFront: nil];
  [window display];
  rep = QuirkProbeRender(content);
  scale = QuirkProbeScale(rep, content);
  [self saveView: content named: @"browser-titles"];
  QuirkProbePixel(rep, 2, 2, &red, &green, &blue);
  windowSum = red + green + blue;

  /* The rows' text edge: where row 0's "TTTT 0" starts, from its
     column's leading edge. */
  matrix = [plain matrixInColumn: 0];
  {
    NSRect column = QuirkProbePixelRect(content, [content convertRect: [[matrix enclosingScrollView] bounds]
                                                              fromView: [matrix enclosingScrollView]], scale);
    NSRect row = QuirkProbePixelRect(content, [content convertRect: [matrix cellFrameAtRow: 0 column: 0]
                                                           fromView: matrix], scale);
    QuirkProbeInk rowInk;

    QuirkProbePixel(rep, (NSInteger)NSMidX(row), (NSInteger)NSMinY(row) + 1, &red, &green, &blue);
    card = red + green + blue;
    QuirkProbeInkBackground = card;
    rowInk = QuirkProbeMeasureIn(rep, QuirkProbeIsInk, NSInsetRect(row, 1.0, 1.0));
    textEdge = rowInk.count > 0 ? rowInk.minX - NSMinX(column) : 16.0 * scale;
  }

  {
    NSString *measured[3] = { nil, nil, nil };
    NSString *problems[3] = { nil, nil, nil };
    NSString *names[3] = { @"in the window", @"in a flipped split view", @"the Size label" };
    NSRect rects[3];
    NSUInteger failures = 0, i;

    rects[0] = [content convertRect: [plain titleFrameOfColumn: 0] fromView: plain];
    rects[1] = [content convertRect: [nested titleFrameOfColumn: 0] fromView: nested];
    rects[2] = [content convertRect: [label bounds] fromView: label];
    for (i = 0; i < 3; i++)
      {
        problems[i] = QuirkProbeColumnTitleProblem(rep, QuirkProbePixelRect(content, rects[i], scale), scale,
                                                   windowSum, textEdge, &measured[i]);
        if (problems[i] != nil)
          {
            failures++;
          }
      }
    if (titleCellClass == Nil)
      {
        failures++;
        problems[2] = @"libs-gui has no GSBrowserTitleCell";
      }
    if (failures == 0)
      {
        [self pass: @"browser-column-titles" detail: [NSString stringWithFormat:
          @"upright on the window at the rows' %.0fpt edge, in the window, a flipped split view and the Size label (%@)",
          textEdge / scale, measured[1]]];
      }
    else
      {
        NSMutableArray *details = [NSMutableArray array];

        for (i = 0; i < 3; i++)
          {
            [details addObject: [NSString stringWithFormat: @"%@: %@ (%@)", names[i],
              problems[i] ?: @"fine", measured[i]]];
          }
        [self fail: @"browser-column-titles" detail: [NSString stringWithFormat:
          @"rows' text edge %.0fpt; %@", textEdge / scale, [details componentsJoinedByString: @"; "]]];
      }
  }
  [window orderOut: nil];
}

static BOOL
QuirkProbeIsSwatchRed(NSUInteger red, NSUInteger green, NSUInteger blue)
{
  return red > 200 && green < 60 && blue < 60;
}

/* NSColorWell as WinUI's colour button (issue #26): the theme's button
   holding a rounded swatch 6pt in from its sides; checked (accent chrome)
   while the colour panel is attached. libs-gui drew NeXT's bevelled well,
   its swatch 2pt in, square. */
- (void) checkColorWell
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(200, 200, 260, 120)
                                     title: @"QuirkProbe Colour Well"];
  NSColorWell *rest = AUTORELEASE([[NSColorWell alloc] initWithFrame: NSMakeRect(20, 60, 64, 32)]);
  NSColorWell *active = AUTORELEASE([[NSColorWell alloc] initWithFrame: NSMakeRect(120, 60, 64, 32)]);
  NSBitmapImageRep *rep = nil;
  CGFloat scale;
  QuirkProbeInk swatch;
  NSUInteger red, green, blue, corner;
  BOOL highContrast = QuirkProbeHasArgument(@"--high-contrast", nil);

  [rest setColor: [NSColor colorWithCalibratedRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0]];
  [active setColor: [NSColor colorWithCalibratedRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0]];
  [[window contentView] addSubview: rest];
  [[window contentView] addSubview: active];
  [window orderFront: nil];
  [window display];

  /* At rest: the swatch 6pt and 5pt in, its corners rounded (a point
     more in high contrast, whose solid edge covers the swatch's rim). */
  rep = QuirkProbeRender(rest);
  scale = QuirkProbeScale(rep, rest);
  [self saveView: rest named: @"colour-well"];
  swatch = QuirkProbeMeasureIn(rep, QuirkProbeIsSwatchRed, NSZeroRect);
  QuirkProbePixel(rep, swatch.minX, swatch.minY, &red, &green, &blue);
  corner = (QuirkProbeIsSwatchRed(red, green, blue) ? 1 : 0);
  if (swatch.count > 0 && fabs(swatch.minX / scale - 6.0) <= 1.5 && fabs(swatch.minY / scale - 5.0) <= 1.5
      && fabs(swatch.width / scale - 52.0) <= 2.5 && corner == 0)
    {
      [self pass: @"colour-well-swatch" detail: [NSString stringWithFormat:
        @"a %.0fx%.0fpt swatch %.0fpt in, its corners rounded",
        swatch.width / scale, swatch.height / scale, swatch.minX / scale]];
    }
  else
    {
      [self fail: @"colour-well-swatch" detail: [NSString stringWithFormat:
        @"the swatch is %.0fx%.0fpt, %.0fpt in from the left and %.0fpt from the top; its corner is %@",
        swatch.width / scale, swatch.height / scale, swatch.minX / scale, swatch.minY / scale,
        corner ? @"square" : @"rounded"]];
    }

  /* Active: the accent chrome round the swatch. */
  if (highContrast)
    {
      [self skip: @"colour-well-active" detail: @"high contrast's highlight may not be blue"];
    }
  else
    {
      QuirkProbeInk accentInk;

      [active activate: YES];
      [window display];
      rep = QuirkProbeRender(active);
      [self saveView: active named: @"colour-well-active"];
      accentInk = QuirkProbeMeasureIn(rep, QuirkProbeIsAccentBlue, NSZeroRect);
      [active deactivate];
      [[NSColorPanel sharedColorPanel] orderOut: nil];
      if (accentInk.count >= (NSUInteger)(100 * scale * scale) && accentInk.width >= [rep pixelsWide] - 4)
        {
          [self pass: @"colour-well-active" detail: [NSString stringWithFormat:
            @"with the colour panel attached, %lu px of accent chrome", (unsigned long)accentInk.count]];
        }
      else
        {
          [self fail: @"colour-well-active" detail: [NSString stringWithFormat:
            @"with the colour panel attached, %lu accent px across %ld of %ld px",
            (unsigned long)accentInk.count, (long)accentInk.width, (long)[rep pixelsWide]]];
        }
    }
  [window orderOut: nil];
}

/* The sum of a pixel's channels, or -1 outside the render. */
static NSInteger
QuirkProbeSumAt(NSBitmapImageRep *rep, NSInteger x, NSInteger y)
{
  NSUInteger red, green, blue;

  return QuirkProbePixel(rep, x, y, &red, &green, &blue) ? (NSInteger)(red + green + blue) : -1;
}

/* NSBox and NSForm as WinUI cards and TextBoxes (issue #27): a grooved box
   is a card with rounded corners, its title above it at its leading edge
   rather than centred in the groove; a separator box is a faint divider,
   not a dark line; a form's entry is a TextBox with rounded corners and a
   strong bottom border, not a bezel filled white. */
- (void) checkBoxes
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(220, 220, 300, 260)
                                     title: @"QuirkProbe Boxes"];
  NSView *content = [window contentView];
  NSBox *box = AUTORELEASE([[NSBox alloc] initWithFrame: NSMakeRect(20, 100, 260, 140)]);
  NSBox *separator = AUTORELEASE([[NSBox alloc] initWithFrame: NSMakeRect(20, 80, 260, 5)]);
  NSForm *form = AUTORELEASE([[NSForm alloc] initWithFrame: NSMakeRect(20, 20, 260, 32)]);
  BOOL highContrast = QuirkProbeHasArgument(@"--high-contrast", nil);
  NSBitmapImageRep *rep = nil;
  CGFloat scale;
  NSRect titleRect, cardRect, entryRect;
  NSInteger windowSum, cardTop, cardLeft, cardBottom, middleX;
  NSInteger cornerSum, edgeSum, insideSum;
  QuirkProbeInk title;

  [box setBoxType: NSBoxPrimary];
  [box setBorderType: NSGrooveBorder];
  [box setTitlePosition: NSAtTop];
  [box setTitle: @"Editor"];
  [content addSubview: box];
  [separator setBoxType: NSBoxSeparator];
  [content addSubview: separator];
  [form addEntry: @"Name:"];
  [form setFrameSize: NSMakeSize(260, 32)];
  [form setCellSize: NSMakeSize(260, 32)];
  [content addSubview: form];
  [window orderFront: nil];
  [window display];
  rep = QuirkProbeRender(content);
  scale = QuirkProbeScale(rep, content);
  [self saveView: content named: @"boxes"];
  windowSum = QuirkProbeSumAt(rep, 2, 2);
  QuirkProbeInkBackground = (NSUInteger)MAX(0, windowSum);

  /* The card: from the box's bottom to its title's bottom. */
  titleRect = [box convertRect: [box titleRect] toView: content];
  cardRect = [box convertRect: [box borderRect] toView: content];
  cardRect.size.height = NSMinY(titleRect) - NSMinY(cardRect);
  cardRect = QuirkProbePixelRect(content, cardRect, scale);
  cardTop = (NSInteger)NSMinY(cardRect);
  cardLeft = (NSInteger)NSMinX(cardRect);
  cardBottom = (NSInteger)NSMaxY(cardRect) - 1;
  middleX = (NSInteger)NSMidX(cardRect);
  cornerSum = QuirkProbeSumAt(rep, cardLeft, cardTop);
  edgeSum = QuirkProbeSumAt(rep, middleX, cardTop);
  insideSum = QuirkProbeSumAt(rep, middleX, (cardTop + cardBottom) / 2);
  if (ABS(cornerSum - windowSum) <= 30 && ABS(edgeSum - windowSum) > 12
      && (highContrast || ABS(insideSum - windowSum) > 6) && ABS(edgeSum - insideSum) > 6)
    {
      [self pass: @"box-card" detail: [NSString stringWithFormat:
        @"a card with rounded corners: corner %ld, edge %ld, fill %ld on a window of %ld",
        (long)cornerSum, (long)edgeSum, (long)insideSum, (long)windowSum]];
    }
  else
    {
      [self fail: @"box-card" detail: [NSString stringWithFormat:
        @"corner %ld, top edge %ld, fill %ld on a window of %ld: not a rounded card",
        (long)cornerSum, (long)edgeSum, (long)insideSum, (long)windowSum]];
    }

  /* The title: above the card, at its leading edge. libs-gui centred it
     across the groove, so its ink reached into the card. */
  title = QuirkProbeMeasureIn(rep, QuirkProbeIsInk,
                              NSMakeRect(cardLeft, cardTop - (NSInteger)(30 * scale),
                                         NSWidth(cardRect), (NSInteger)(30 * scale)));
  if (title.count > 0 && (title.minX - cardLeft) / scale <= 4.0
      && title.minX + title.width / 2 < cardLeft + NSWidth(cardRect) / 3
      && title.minY + title.height <= cardTop + 1)
    {
      [self pass: @"box-title" detail: [NSString stringWithFormat:
        @"the title starts %.0fpt from the card's edge and ends above it",
        (title.minX - cardLeft) / scale]];
    }
  else
    {
      [self fail: @"box-title" detail: [NSString stringWithFormat:
        @"the title starts %.0fpt in, is %.0fpt wide and ends %.0fpt below the card's top (%lu px of ink)",
        (title.minX - cardLeft) / scale, title.width / scale, (title.minY + title.height - cardTop) / scale,
        (unsigned long)title.count]];
    }

  /* The separator: DividerStrokeColorDefault, faint (libs-gui's
     controlShadowColor is twice as strong); the text colour in high
     contrast. */
  {
    NSRect line = QuirkProbePixelRect(content, [separator convertRect: [separator borderRect] toView: content], scale);
    NSInteger lineSum = QuirkProbeSumAt(rep, (NSInteger)NSMidX(line), (NSInteger)NSMinY(line));
    NSInteger difference = ABS(lineSum - windowSum);

    if (highContrast ? difference > 150 : (difference > 12 && difference < 90))
      {
        [self pass: @"box-separator" detail: [NSString stringWithFormat:
          @"the divider is %ld from the window's %ld", (long)lineSum, (long)windowSum]];
      }
    else
      {
        [self fail: @"box-separator" detail: [NSString stringWithFormat:
          @"the divider is %ld on a window of %ld", (long)lineSum, (long)windowSum]];
      }
  }

  /* The form's entry: a TextBox beside the title, rounded, its bottom
     border stronger than its top. */
  {
    NSFormCell *cell = [form cellAtIndex: 0];
    NSRect cellFrame = [form cellFrameAtRow: 0 column: 0];
    CGFloat titleWidth = [cell titleWidth];
    NSInteger left, top, bottom, x;
    NSInteger topSum, bottomSum, entryCorner;

    cellFrame.origin.x += titleWidth + 3.0;
    cellFrame.size.width -= titleWidth + 3.0;
    entryRect = QuirkProbePixelRect(content, [form convertRect: cellFrame toView: content], scale);
    left = (NSInteger)NSMinX(entryRect);
    top = (NSInteger)NSMinY(entryRect);
    bottom = (NSInteger)NSMaxY(entryRect) - 1;
    x = left + (NSInteger)(20 * scale);
    entryCorner = QuirkProbeSumAt(rep, left, top);
    topSum = QuirkProbeSumAt(rep, x, top);
    bottomSum = QuirkProbeSumAt(rep, x, bottom);
    if (ABS(entryCorner - windowSum) <= 30
        && (highContrast ? ABS(bottomSum - windowSum) > 150
            : ABS(bottomSum - windowSum) > ABS(topSum - windowSum) + 30))
      {
        [self pass: @"form-entry-textbox" detail: [NSString stringWithFormat:
          @"a rounded TextBox: corner %ld, top edge %ld, bottom edge %ld",
          (long)entryCorner, (long)topSum, (long)bottomSum]];
      }
    else
      {
        [self fail: @"form-entry-textbox" detail: [NSString stringWithFormat:
          @"corner %ld (window %ld), top edge %ld, bottom edge %ld: not a TextBox",
          (long)entryCorner, (long)windowSum, (long)topSum, (long)bottomSum]];
      }
  }
  [window orderOut: nil];
}

/* A contrast theme's colours, from Windows' own .theme files
   (Resources\Ease of Access Themes): Window, WindowText, Hilight,
   HilightText, GrayText, ButtonFace and ButtonText, as RGB triples. */
static const unsigned char *
QuirkProbeContrastTheme(NSString *name)
{
  static const unsigned char dusk[] = {
    45, 50, 54,  255, 255, 255,  161, 191, 222,  33, 45, 59,
    166, 166, 166,  45, 50, 54,  182, 246, 240
  };
  static const unsigned char desert[] = {
    255, 250, 239,  61, 61, 61,  144, 57, 9,  255, 245, 227,
    103, 103, 103,  255, 250, 239,  32, 32, 32
  };

  if ([name isEqualToString: @"dusk"])
    {
      return dusk;
    }
  if ([name isEqualToString: @"desert"])
    {
      return desert;
    }
  return NULL;
}

/* YES when `color` is within 2 of the triple at `rgb`. */
static BOOL
QuirkProbeColorMatches(NSColor *color, const unsigned char *rgb)
{
  NSColor *converted = [color colorUsingColorSpaceName: NSCalibratedRGBColorSpace];

  return converted != nil
    && fabs([converted redComponent] * 255.0 - rgb[0]) <= 2.0
    && fabs([converted greenComponent] * 255.0 - rgb[1]) <= 2.0
    && fabs([converted blueComponent] * 255.0 - rgb[2]) <= 2.0;
}

static const unsigned char *QuirkProbeWantedRGB = NULL;

/* Pixels within 24 of QuirkProbeWantedRGB in each channel. */
static BOOL
QuirkProbeIsWantedColor(NSUInteger red, NSUInteger green, NSUInteger blue)
{
  return labs((long)red - QuirkProbeWantedRGB[0]) <= 24
    && labs((long)green - QuirkProbeWantedRGB[1]) <= 24
    && labs((long)blue - QuirkProbeWantedRGB[2]) <= 24;
}

/* High contrast in the active contrast theme's colours (issue #45): the
   probe runs with --contrast-theme dusk or desert, Windows' own themes,
   and the palette must be theirs, not black and white. A button is
   ButtonFace with ButtonText, which in Dusk differs from WindowText. */
- (void) checkContrastTheme
{
  NSArray *arguments = [[NSProcessInfo processInfo] arguments];
  NSUInteger index = [arguments indexOfObject: @"--contrast-theme"];
  NSString *name = (index != NSNotFound && index + 1 < [arguments count])
    ? [[arguments objectAtIndex: index + 1] lowercaseString] : nil;
  const unsigned char *rgb = QuirkProbeContrastTheme(name);
  NSArray *colors = nil;
  NSArray *names = [NSArray arrayWithObjects: @"Window", @"WindowText", @"Hilight", @"HilightText",
                                              @"GrayText", nil];
  NSMutableArray *wrong = [NSMutableArray array];
  NSUInteger i;

  if (rgb == NULL)
    {
      [self skip: @"contrast-colours" detail: @"no contrast theme (--contrast-theme dusk or desert)"];
      [self skip: @"contrast-button" detail: @"no contrast theme (--contrast-theme dusk or desert)"];
      return;
    }

  colors = [NSArray arrayWithObjects: [NSColor windowBackgroundColor], [NSColor controlTextColor],
                                      [NSColor selectedControlColor], [NSColor selectedControlTextColor],
                                      [NSColor disabledControlTextColor], nil];
  for (i = 0; i < [names count]; i++)
    {
      if (QuirkProbeColorMatches([colors objectAtIndex: i], rgb + 3 * i) == NO)
        {
          [wrong addObject: [names objectAtIndex: i]];
        }
    }
  if ([wrong count] == 0)
    {
      [self pass: @"contrast-colours" detail: [NSString stringWithFormat:
        @"the window, text, highlight and disabled colours are %@'s", name]];
    }
  else
    {
      [self fail: @"contrast-colours" detail: [NSString stringWithFormat:
        @"not %@'s: %@", name, [wrong componentsJoinedByString: @", "]]];
    }

  /* The button: a ButtonFace fill beside its ButtonText title. */
  {
    NSWindow *window = [self windowWithFrame: NSMakeRect(240, 240, 200, 80)
                                       title: @"QuirkProbe Contrast"];
    NSButton *button = AUTORELEASE([[NSButton alloc] initWithFrame: NSMakeRect(20, 24, 140, 32)]);
    NSBitmapImageRep *rep = nil;
    CGFloat scale;
    NSUInteger red = 0, green = 0, blue = 0;
    QuirkProbeInk title;
    BOOL face;

    [button setButtonType: NSMomentaryPushInButton];
    [button setBezelStyle: NSRoundedBezelStyle];
    [button setTitle: @"Apply"];
    [[window contentView] addSubview: button];
    [window orderFront: nil];
    [window display];
    rep = QuirkProbeRender(button);
    scale = QuirkProbeScale(rep, button);
    [self saveView: button named: @"contrast-button"];
    QuirkProbePixel(rep, (NSInteger)(10 * scale), [rep pixelsHigh] / 2, &red, &green, &blue);
    QuirkProbeWantedRGB = rgb + 15;
    face = QuirkProbeIsWantedColor(red, green, blue);
    QuirkProbeWantedRGB = rgb + 18;
    title = QuirkProbeMeasureIn(rep, QuirkProbeIsWantedColor,
                                NSMakeRect(20 * scale, 4 * scale, [rep pixelsWide] - 40 * scale,
                                           [rep pixelsHigh] - 8 * scale));
    if (face && title.count >= (NSUInteger)(20 * scale * scale))
      {
        [self pass: @"contrast-button" detail: [NSString stringWithFormat:
          @"ButtonFace with %lu px of ButtonText", (unsigned long)title.count]];
      }
    else
      {
        [self fail: @"contrast-button" detail: [NSString stringWithFormat:
          @"the fill is %lu,%lu,%lu (ButtonFace %@), %lu px of ButtonText",
          (unsigned long)red, (unsigned long)green, (unsigned long)blue, face ? @"yes" : @"no",
          (unsigned long)title.count]];
      }
    [window orderOut: nil];
  }
}

static NSSegmentedControl *
QuirkProbeSegments(NSView *content, NSRect frame, NSInteger mode)
{
  NSSegmentedControl *control = AUTORELEASE([[NSSegmentedControl alloc] initWithFrame: frame]);
  NSArray *labels = [NSArray arrayWithObjects: @"Write", @"Preview", @"Split", nil];
  NSUInteger index;

  [control setSegmentCount: 3];
  [[control cell] setTrackingMode: mode];
  for (index = 0; index < 3; index++)
    {
      [control setLabel: [labels objectAtIndex: index] forSegment: index];
      [control setWidth: 100 forSegment: index];
    }
  [content addSubview: control];
  return control;
}

/* Accent runs along one pixel row: their count and the first one's centre
   and length in points. */
static NSUInteger
QuirkProbeAccentRuns(NSBitmapImageRep *rep, NSInteger y, CGFloat scale, CGFloat *firstCentre, CGFloat *firstLength)
{
  NSUInteger runs = 0;
  NSInteger x, start = -1;
  BOOL inRun = NO;

  for (x = 0; x <= [rep pixelsWide]; x++)
    {
      NSUInteger r = 0, g = 0, b = 0;
      BOOL hit = (x < [rep pixelsWide]) && QuirkProbePixel(rep, x, y, &r, &g, &b) && QuirkProbeIsAccentBlue(r, g, b);

      if (hit && inRun == NO)
        {
          start = x;
        }
      if (hit == NO && inRun)
        {
          if (runs == 0)
            {
              *firstCentre = (start + x) / 2.0 / scale;
              *firstLength = (x - start) / scale;
            }
          runs++;
        }
      inRun = hit;
    }
  return runs;
}

/* NSSegmentedControl as WinUI's Segmented control (issue #48): one rounded
   container with no dividers; the selected segment raised, with a 3x16pt
   accent pill under its label; in multiple selection, a pill under each
   selected segment. The theme drew dividers between segments and tinted
   the selected one. */
- (void) checkSegmentedControl
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(220, 160, 360, 140)
                                     title: @"QuirkProbe Segments"];
  NSView *content = [window contentView];
  NSSegmentedControl *one = QuirkProbeSegments(content, NSMakeRect(20, 90, 300, 32), NSSegmentSwitchTrackingSelectOne);
  NSSegmentedControl *any = QuirkProbeSegments(content, NSMakeRect(20, 30, 300, 32), NSSegmentSwitchTrackingSelectAny);
  NSBitmapImageRep *rep = nil;
  CGFloat scale, centre = 0.0, length = 0.0;
  NSUInteger red, green, blue;
  QuirkProbeInk pill;

  if (QuirkProbeHasArgument(@"--high-contrast", nil))
    {
      [self skip: @"segmented-pill" detail: @"high contrast draws the selection as the highlight"];
      [self skip: @"segmented-no-dividers" detail: @"high contrast draws the selection as the highlight"];
      [self skip: @"segmented-multiple" detail: @"high contrast draws the selection as the highlight"];
      return;
    }
  [one setSelectedSegment: 0];
  [any setSelected: YES forSegment: 0];
  [any setSelected: YES forSegment: 2];
  [window orderFront: nil];
  [window display];

  rep = QuirkProbeRender(one);
  scale = QuirkProbeScale(rep, one);
  [self saveView: one named: @"segmented"];
  pill = QuirkProbeMeasureIn(rep, QuirkProbeIsAccentBlue, NSZeroRect);
  if (pill.count > 0 && fabs(pill.width / scale - 16.0) <= 1.5 && fabs(pill.height / scale - 3.0) <= 1.0
      && fabs((pill.minX + pill.width / 2.0) / scale - 50.0) <= 2.0)
    {
      [self pass: @"segmented-pill" detail: [NSString stringWithFormat:
        @"a %.0fx%.0fpt accent pill under the selected segment", pill.width / scale, pill.height / scale]];
    }
  else
    {
      [self fail: @"segmented-pill" detail: [NSString stringWithFormat:
        @"accent %.0fx%.0fpt centred at %.0fpt (expected 16x3 at 50)",
        pill.width / scale, pill.height / scale,
        pill.count ? (pill.minX + pill.width / 2.0) / scale : -1.0]];
    }

  /* Between the two unselected segments, at mid-height: the container's
     fill, as 10pt to either side. */
  {
    NSInteger y = [rep pixelsHigh] / 2;
    NSUInteger at, left;
    NSInteger x, worst = 0;

    QuirkProbePixel(rep, (NSInteger)(190 * scale), y, &red, &green, &blue);
    left = red + green + blue;
    for (x = (NSInteger)(197 * scale); x <= (NSInteger)(203 * scale); x++)
      {
        QuirkProbePixel(rep, x, y, &red, &green, &blue);
        at = red + green + blue;
        worst = MAX(worst, (NSInteger)llabs((long long)at - (long long)left));
      }
    if (worst <= 12)
      {
        [self pass: @"segmented-no-dividers" detail: [NSString stringWithFormat:
          @"no divider between unselected segments (%ld of 765 from the fill)", (long)worst]];
      }
    else
      {
        [self fail: @"segmented-no-dividers" detail: [NSString stringWithFormat:
          @"a mark %ld of 765 from the fill between unselected segments", (long)worst]];
      }
  }

  /* Multiple selection: a pill under the first and the last. */
  rep = QuirkProbeRender(any);
  [self saveView: any named: @"segmented-multiple"];
  pill = QuirkProbeMeasureIn(rep, QuirkProbeIsAccentBlue, NSZeroRect);
  {
    NSUInteger runs = pill.count ? QuirkProbeAccentRuns(rep, pill.minY + pill.height / 2, scale, &centre, &length) : 0;

    if (runs == 2 && fabs(centre - 50.0) <= 2.0)
      {
        [self pass: @"segmented-multiple" detail: @"two selected segments, two pills"];
      }
    else
      {
        [self fail: @"segmented-multiple" detail: [NSString stringWithFormat:
          @"%lu accent runs, the first centred at %.0fpt", (unsigned long)runs, centre]];
      }
  }
  [window orderOut: nil];
}

/* -cellSize gives the height the theme draws a control at (issue #86). An
   app that sizes its controls from -cellSize got WinUI's 32pt push
   buttons, but segmented controls, sliders and TextBoxes only as tall as
   their text: the selected segment's pill and the slider's thumb were
   clipped, and a text field sat shorter than the button beside it. WinUI's
   Segmented, Slider (its touch target) and TextBox are as tall as a
   Button, 32px (24px compact). */
- (void) checkCellSizes
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(240, 200, 420, 260)
                                     title: @"QuirkProbe Cell Sizes"];
  NSView *content = [window contentView];
  NSButton *button = AUTORELEASE([[NSButton alloc] initWithFrame: NSMakeRect(20, 210, 100, 32)]);
  NSSegmentedControl *segments = QuirkProbeSegments(content, NSMakeRect(20, 160, 300, 20),
                                                    NSSegmentSwitchTrackingSelectOne);
  NSSlider *slider = AUTORELEASE([[NSSlider alloc] initWithFrame: NSMakeRect(20, 110, 240, 20)]);
  NSTextField *field = AUTORELEASE([[NSTextField alloc] initWithFrame: NSMakeRect(20, 60, 200, 20)]);
  NSTextField *readOnly = AUTORELEASE([[NSTextField alloc] initWithFrame: NSMakeRect(20, 10, 200, 20)]);
  NSControl *controls[4];
  NSString *names[4] = { @"cell-size-segmented", @"cell-size-slider",
                         @"cell-size-text-field", @"cell-size-read-only-field" };
  CGFloat buttonHeight, desktop = QuirkProbeDesktopScale();
  CGFloat thumb = round(20.0 * desktop);
  NSUInteger index;

  [button setTitle: @"OK"];
  [button setBezelStyle: NSRoundedBezelStyle];
  [content addSubview: button];
  [segments setSelectedSegment: 0];
  [slider setMinValue: 0.0];
  [slider setMaxValue: 100.0];
  [slider setDoubleValue: 50.0];
  [content addSubview: slider];
  [field setStringValue: @"Text"];
  [content addSubview: field];
  [readOnly setStringValue: @"Read only"];
  [readOnly setEditable: NO];
  [readOnly setBezeled: YES];
  [content addSubview: readOnly];
  controls[0] = segments;
  controls[1] = slider;
  controls[2] = field;
  controls[3] = readOnly;

  buttonHeight = [[button cell] cellSize].height;
  for (index = 0; index < 4; index++)
    {
      CGFloat height = [[controls[index] cell] cellSize].height;
      NSString *detail = [NSString stringWithFormat: @"%.0fpt tall, a push button %.0fpt",
                                                     height, buttonHeight];

      [controls[index] setFrameSize: NSMakeSize(NSWidth([controls[index] frame]), height)];
      if (fabs(height - buttonHeight) <= 0.5)
        {
          [self pass: names[index] detail: detail];
        }
      else
        {
          [self fail: names[index] detail: detail];
        }
    }

  /* Drawn in a frame of that height, nothing is clipped: the selected
     segment's 3x16pt pill and the slider's whole thumb show. */
  [window orderFront: nil];
  [window display];
  if (QuirkProbeHasArgument(@"--high-contrast", nil))
    {
      [self skip: @"cell-size-segmented-unclipped" detail: @"high contrast draws the selection as the highlight"];
    }
  else
    {
      NSBitmapImageRep *rep = QuirkProbeRender(segments);
      CGFloat scale = QuirkProbeScale(rep, segments);
      QuirkProbeInk pill = QuirkProbeMeasureIn(rep, QuirkProbeIsAccentBlue, NSZeroRect);
      NSString *detail = [NSString stringWithFormat: @"in %.0fpt: a %.0fx%.0fpt accent pill",
                                                     NSHeight([segments frame]),
                                                     pill.width / scale, pill.height / scale];

      [self saveView: segments named: @"cell-size-segmented"];
      if (pill.count > 0 && fabs(pill.width / scale - 16.0) <= 1.5 && fabs(pill.height / scale - 3.0) <= 1.0
          && pill.minY + pill.height < [rep pixelsHigh] - 1)
        {
          [self pass: @"cell-size-segmented-unclipped" detail: detail];
        }
      else
        {
          [self fail: @"cell-size-segmented-unclipped" detail: [detail stringByAppendingString: @", expected 16x3"]];
        }
    }
  {
    NSBitmapImageRep *rep = QuirkProbeRender(slider);
    CGFloat scale = QuirkProbeScale(rep, slider);
    NSInteger x = (NSInteger)(NSWidth([slider bounds]) / 2.0 * scale);
    NSInteger y, top = -1, bottom = -1;
    NSUInteger red, green, blue;
    NSString *detail = nil;

    [self saveView: slider named: @"cell-size-slider"];
    QuirkProbePixel(rep, 1, 1, &red, &green, &blue);
    QuirkProbeInkBackground = red + green + blue;
    /* The thumb's edge in light mode is a stroke only a few levels from
       the window: anything off the background counts. */
    for (y = 0; y < [rep pixelsHigh]; y++)
      {
        QuirkProbePixel(rep, x, y, &red, &green, &blue);
        if (llabs((long long)(red + green + blue) - (long long)QuirkProbeInkBackground) > 12)
          {
            if (top < 0)
              {
                top = y;
              }
            bottom = y;
          }
      }
    detail = [NSString stringWithFormat: @"in %.0fpt: the thumb is %.0fpt tall (%.0fpt expected)",
                                         NSHeight([slider frame]),
                                         (top >= 0) ? (bottom - top + 1) / scale : 0.0, thumb];
    if (top > 0 && bottom < [rep pixelsHigh] - 1 && (bottom - top + 1) >= (thumb - 1.5) * scale)
      {
        [self pass: @"cell-size-slider-unclipped" detail: detail];
      }
    else
      {
        [self fail: @"cell-size-slider-unclipped" detail: detail];
      }
  }
  [segments removeFromSuperview];
  [window orderOut: nil];
}

/* NSTabView's top tabs as WinUI's SelectorBar (issue #49): text items, the
   selected one over a 3x16pt accent pill. A click on a tab has to find it:
   the theme drew tabs without recording their rects, so
   -tabViewItemAtPoint: found none. */
- (void) checkTabView
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(240, 180, 420, 220)
                                     title: @"QuirkProbe Tabs"];
  NSTabView *tabView = AUTORELEASE([[NSTabView alloc] initWithFrame: NSMakeRect(20, 20, 380, 180)]);
  NSArray *labels = [NSArray arrayWithObjects: @"Write", @"Preview", @"History", nil];
  NSBitmapImageRep *rep = nil;
  CGFloat scale;
  NSUInteger index, found = 0;
  NSMutableString *misses = [NSMutableString string];

  for (index = 0; index < [labels count]; index++)
    {
      NSTabViewItem *item = AUTORELEASE([[NSTabViewItem alloc] initWithIdentifier: [labels objectAtIndex: index]]);

      [item setLabel: [labels objectAtIndex: index]];
      [item setView: AUTORELEASE([[NSView alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)])];
      [tabView addTabViewItem: item];
    }
  [[window contentView] addSubview: tabView];
  [tabView selectTabViewItemAtIndex: 0];
  [window orderFront: nil];
  [window display];

  /* Each tab's label, found by its ink in the strip, finds its item. */
  rep = QuirkProbeRender(tabView);
  scale = QuirkProbeScale(rep, tabView);
  [self saveView: tabView named: @"tab-view"];
  {
    NSInteger x, y = (NSInteger)(14 * scale);
    NSUInteger r, g, b, background;
    NSInteger starts[8], ends[8];
    NSUInteger labelsSeen = 0;
    BOOL inInk = NO;
    NSInteger gap = 0;

    QuirkProbePixel(rep, [rep pixelsWide] - 4, y, &r, &g, &b);
    background = r + g + b;
    for (x = 0; x < [rep pixelsWide] && labelsSeen < 8; x++)
      {
        NSInteger yy;
        BOOL ink = NO;

        for (yy = (NSInteger)(4 * scale); yy < (NSInteger)(24 * scale); yy++)
          {
            QuirkProbePixel(rep, x, yy, &r, &g, &b);
            if (llabs((long long)(r + g + b) - (long long)background) > 120)
              {
                ink = YES;
              }
          }
        if (ink)
          {
            if (inInk == NO && (labelsSeen == 0 || gap > 8 * scale))
              {
                starts[labelsSeen] = x;
                labelsSeen++;
              }
            ends[labelsSeen - 1] = x;
            inInk = YES;
            gap = 0;
          }
        else
          {
            inInk = NO;
            gap++;
          }
      }
    for (index = 0; index < [labels count] && index < labelsSeen; index++)
      {
        CGFloat px = (starts[index] + ends[index]) / 2.0 / scale;
        CGFloat py = 14.0;
        NSPoint point = NSMakePoint(px, [tabView isFlipped] ? py : NSHeight([tabView bounds]) - py);
        NSTabViewItem *hit = [tabView tabViewItemAtPoint: point];

        if (hit == [tabView tabViewItemAtIndex: index])
          {
            found++;
          }
        else
          {
            [misses appendFormat: @" %@ at %.0f,%.0f found %@;", [labels objectAtIndex: index], point.x, point.y,
                                  hit ? [hit label] : @"nothing"];
          }
      }
    if (labelsSeen >= [labels count] && found == [labels count])
      {
        [self pass: @"tab-click-target" detail: @"a click on each tab's label finds that tab"];
      }
    else
      {
        [self fail: @"tab-click-target" detail: [NSString stringWithFormat:
          @"%lu labels seen, %lu found by a click:%@", (unsigned long)labelsSeen, (unsigned long)found, misses]];
      }
  }

  if (QuirkProbeHasArgument(@"--high-contrast", nil))
    {
      [self skip: @"tab-selected-pill" detail: @"high contrast's highlight may not be blue"];
    }
  else
    {
      QuirkProbeInk pill = QuirkProbeMeasureIn(rep, QuirkProbeIsAccentBlue, NSMakeRect(0, 0, [rep pixelsWide], 60 * scale));

      if (pill.count > 0 && fabs(pill.width / scale - 16.0) <= 1.5 && fabs(pill.height / scale - 3.0) <= 1.0
          && pill.minX / scale < 60.0)
        {
          [self pass: @"tab-selected-pill" detail: [NSString stringWithFormat:
            @"a %.0fx%.0fpt accent pill under the selected tab", pill.width / scale, pill.height / scale]];
        }
      else
        {
          [self fail: @"tab-selected-pill" detail: [NSString stringWithFormat:
            @"the selected tab's accent is %.0fx%.0fpt at %.0fpt (expected 16x3 under the first tab)",
            pill.width / scale, pill.height / scale, pill.count ? pill.minX / scale : -1.0]];
        }
    }
  [window orderOut: nil];
}

/* Compact metrics (issue #31): the probe builds its windows in code, so it
   gets WinUI's metrics unless run with -WinUIThemeMetrics compact. WinUI's:
   14pt text, 32pt tabs and WinUI's button margins; compact: GNUstep's 12pt,
   no minimum tab height and GNUstep's button margins, so 22pt nib and Gorm
   controls fit their titles. */
- (void) checkMetricsChoice
{
  GSTheme *theme = [GSTheme theme];
  BOOL compact = QuirkProbeCompactMetrics();
  CGFloat textScale = [[NSUserDefaults standardUserDefaults] floatForKey: @"WinUIThemeTextScaleFactor"];
  CGFloat expectedFont = round((compact ? 12.0 : 14.0) * ((textScale >= 100.0) ? textScale / 100.0 : 1.0));
  CGFloat font = [[NSFont systemFontOfSize: 0.0] pointSize];
  CGFloat tab = [theme tabHeightForType: NSTopTabsBezelBorder];
  NSButtonCell *cell = AUTORELEASE([[NSButtonCell alloc] initTextCell: @"Miniaturize"]);
  GSThemeMargins margins;
  BOOL ok;

  [cell setBezelStyle: NSRoundedBezelStyle];
  margins = [theme buttonMarginsForCell: cell style: NSRoundedBezelStyle state: GSThemeNormalState];
  if (compact)
    {
      ok = (fabs(font - expectedFont) < 0.5 && tab < 32.0 && margins.left < 8.0);
    }
  else
    {
      ok = (fabs(font - expectedFont) < 0.5 && tab >= 32.0 && margins.left >= 8.0);
    }
  if (ok)
    {
      [self pass: @"metrics-choice" detail: [NSString stringWithFormat:
        @"%@ metrics: %.0fpt text, %.0fpt tabs, %.0fpt button margins",
        compact ? @"compact" : @"WinUI", font, tab, margins.left]];
    }
  else
    {
      [self fail: @"metrics-choice" detail: [NSString stringWithFormat:
        @"expected %@ metrics; got %.0fpt text (expected %.0f), %.0fpt tabs, %.0fpt button margins",
        compact ? @"compact" : @"WinUI", font, expectedFont, tab, margins.left]];
    }

  /* A button laid out at GNUstep's metrics, as in a nib: "Miniaturize" in
     72x22pt. Compact metrics show the whole title (Adwaita's showed
     "Miniatur" before its compact metrics). */
  if (compact == NO)
    {
      [self skip: @"compact-nib-button" detail: @"needs -WinUIThemeMetrics compact"];
    }
  else
    {
      NSWindow *window = [self windowWithFrame: NSMakeRect(260, 260, 160, 60)
                                         title: @"QuirkProbe Compact"];
      NSButton *button = AUTORELEASE([[NSButton alloc] initWithFrame: NSMakeRect(20, 20, 72, 22)]);
      NSBitmapImageRep *rep = nil;
      CGFloat scale, titleWidth;
      NSUInteger red, green, blue;
      QuirkProbeInk ink;

      [button setTitle: @"Miniaturize"];
      [button setBezelStyle: NSRoundedBezelStyle];
      [[window contentView] addSubview: button];
      [window orderFront: nil];
      [window display];
      rep = QuirkProbeRender(button);
      scale = QuirkProbeScale(rep, button);
      [self saveView: button named: @"compact-nib-button"];
      QuirkProbePixel(rep, [rep pixelsWide] / 2, 3 * scale, &red, &green, &blue);
      QuirkProbeInkBackground = red + green + blue;
      ink = QuirkProbeMeasureIn(rep, QuirkProbeIsInk,
                                NSMakeRect(2 * scale, 3 * scale, [rep pixelsWide] - 4 * scale, [rep pixelsHigh] - 6 * scale));
      titleWidth = [@"Miniaturize" sizeWithAttributes:
        [NSDictionary dictionaryWithObject: [button font] forKey: NSFontAttributeName]].width;
      if (ink.count > 0 && ink.width / scale >= titleWidth - 3.0)
        {
          [self pass: @"compact-nib-button" detail: [NSString stringWithFormat:
            @"the whole title shows in a 72x22pt button (%.0fpt of ink, the title %.0fpt)",
            ink.width / scale, titleWidth]];
        }
      else
        {
          [self fail: @"compact-nib-button" detail: [NSString stringWithFormat:
            @"%.0fpt of title ink in a 72x22pt button; the title is %.0fpt", ink.width / scale, titleWidth]];
        }
      [window orderOut: nil];
    }

  /* A label laid out at GNUstep's 12pt, as in a nib: buttons give up their
     padding before their title (#14), but a label can't, so at WinUI's 14pt
     its text runs past the frame. 107pt is what GNUstep's own layout gives
     "Miniaturize window": 103pt of Tahoma 12 (its default font on Windows)
     and the cell's 4pt. */
  if (compact == NO)
    {
      [self skip: @"compact-nib-label" detail: @"needs -WinUIThemeMetrics compact"];
    }
  else
    {
      NSTextField *label = AUTORELEASE([[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 107, 17)]);
      NSSize needed;

      [label setStringValue: @"Miniaturize window"];
      [label setBezeled: NO];
      [label setBordered: NO];
      [label setEditable: NO];
      [label setDrawsBackground: NO];
      needed = [[label cell] cellSize];
      if (needed.width <= 107.5)
        {
          [self pass: @"compact-nib-label" detail: [NSString stringWithFormat:
            @"\"Miniaturize window\" needs %.0fpt of a 107pt nib label", needed.width]];
        }
      else
        {
          [self fail: @"compact-nib-label" detail: [NSString stringWithFormat:
            @"\"Miniaturize window\" needs %.0fpt; a nib made at GNUstep's 12pt gives it 107", needed.width]];
        }
    }
}

/* A table built in code looks like a WinUI list (issue #28): libs-gui's
   16pt rows, grid and 5x2pt spacing become 32pt rows, no grid and none;
   the header shows column dividers only under the pointer; and a row under
   the pointer gets a hover fill (issue #43's gap; only with
   -ProbeMovesPointer YES). */
- (void) checkTableDefaults
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(440, 380, 340, 240)
                                     title: @"QuirkProbe Table Defaults"];
  QuirkProbeRows *rows = AUTORELEASE([QuirkProbeRows new]);
  NSScrollView *scrollView = AUTORELEASE([[NSScrollView alloc] initWithFrame: NSMakeRect(10, 10, 320, 220)]);
  NSTableView *table = AUTORELEASE([[NSTableView alloc] initWithFrame: NSMakeRect(0, 0, 300, 200)]);
  NSTableColumn *name = AUTORELEASE([[NSTableColumn alloc] initWithIdentifier: @"name"]);
  NSTableColumn *size = AUTORELEASE([[NSTableColumn alloc] initWithIdentifier: @"size"]);
  CGFloat desktop = QuirkProbeDesktopScale();
  CGFloat expectedHeight = MAX(30.0, ceil(32.0 * desktop));
  NSBitmapImageRep *rep = nil;
  CGFloat scale;
  NSString *detail = nil;

  detail = [NSString stringWithFormat: @"rows %.0fpt, grid mask %lu, spacing %.0fx%.0f",
                     [table rowHeight], (unsigned long)[table gridStyleMask],
                     [table intercellSpacing].width, [table intercellSpacing].height];
  if (fabs([table rowHeight] - expectedHeight) < 0.01
      && [table gridStyleMask] == NSTableViewGridNone
      && NSEqualSizes([table intercellSpacing], NSZeroSize))
    {
      [self pass: @"table-code-defaults" detail: detail];
    }
  else
    {
      [self fail: @"table-code-defaults" detail: [detail stringByAppendingFormat:
        @"; expected %.0fpt rows, no grid, no spacing", expectedHeight]];
    }

  [[name headerCell] setStringValue: @"Name"];
  [[size headerCell] setStringValue: @"Size"];
  [name setWidth: 150];
  [size setWidth: 150];
  [table addTableColumn: name];
  [table addTableColumn: size];
  [table setDataSource: rows];
  [table setUsesAlternatingRowBackgroundColors: NO];
  [scrollView setDocumentView: table];
  [[window contentView] addSubview: scrollView];
  [window makeKeyAndOrderFront: nil];
  [table reloadData];
  [window display];

  /* The header between the columns, mid-height, against its background. */
  {
    NSTableHeaderView *header = [table headerView];
    NSInteger divider, plain;

    rep = QuirkProbeRender(header);
    scale = QuirkProbeScale(rep, header);
    [self saveView: header named: @"table-header-dividers"];
    divider = QuirkProbeBrightnessAt(rep, scale, NSMaxX([table rectOfColumn: 0]) - 0.5,
                                     NSHeight([header bounds]) / 2.0);
    plain = QuirkProbeBrightnessAt(rep, scale, NSMaxX([table rectOfColumn: 0]) - 20.0,
                                   NSHeight([header bounds]) / 2.0);
    if (QuirkProbeHasArgument(@"--high-contrast", nil))
      {
        [self skip: @"table-header-dividers" detail: @"high contrast keeps the dividers"];
      }
    else if (llabs((long long)(divider - plain)) <= 6)
      {
        [self pass: @"table-header-dividers" detail: @"no column divider at rest"];
      }
    else
      {
        [self fail: @"table-header-dividers" detail: [NSString stringWithFormat:
          @"a divider between the columns at rest: %ld against %ld (of 765)", (long)divider, (long)plain]];
      }
  }

  if ([[NSUserDefaults standardUserDefaults] boolForKey: @"ProbeMovesPointer"] == NO)
    {
      [self skip: @"table-row-hover" detail: @"moves the pointer: needs -ProbeMovesPointer YES"];
    }
  else if (QuirkProbeHasArgument(@"--high-contrast", nil))
    {
      [self skip: @"table-row-hover" detail: @"high contrast has no hover fill"];
    }
  else
    {
      NSRect first = [table rectOfRow: 0];
      NSRect third = [table rectOfRow: 2];
      NSInteger over, rest, after;

      QuirkProbeSetPointer([window convertBaseToScreen:
        [table convertPoint: NSMakePoint(120, NSMidY(first)) toView: nil]]);
      QuirkProbeDispatchEvents(0.4);
      [window display];
      rep = QuirkProbeRender(table);
      scale = QuirkProbeScale(rep, table);
      [self saveView: table named: @"table-row-hover"];
      over = QuirkProbeBrightnessAt(rep, scale, 120, NSMidY(first));
      rest = QuirkProbeBrightnessAt(rep, scale, 120, NSMidY(third));
      QuirkProbeSetPointer([window convertBaseToScreen:
        [table convertPoint: NSMakePoint(120, NSMidY(third)) toView: nil]]);
      QuirkProbeDispatchEvents(0.4);
      [window display];
      rep = QuirkProbeRender(table);
      after = QuirkProbeBrightnessAt(rep, scale, 120, NSMidY(first));
      QuirkProbeSetPointer([window convertBaseToScreen: NSMakePoint(-40, -40)]);
      QuirkProbeDispatchEvents(0.3);
      if (llabs((long long)(over - rest)) >= 9 && llabs((long long)(after - rest)) <= 3)
        {
          [self pass: @"table-row-hover" detail: [NSString stringWithFormat:
            @"the row under the pointer is %ld, others %ld (of 765), and it clears", (long)over, (long)rest]];
        }
      else
        {
          [self fail: @"table-row-hover" detail: [NSString stringWithFormat:
            @"under the pointer %ld, another row %ld, the first row after leaving %ld (of 765)",
            (long)over, (long)rest, (long)after]];
        }
    }
  [table setDataSource: nil];
  [window orderOut: nil];
}

#ifdef _WIN32
static WINBOOL CALLBACK
QuirkProbeFindListener(HWND hwnd, LPARAM found)
{
  wchar_t name[64];

  if (GetClassNameW(hwnd, name, 64) > 0 && wcscmp(name, L"WinUIThemeSettingsListener") == 0)
    {
      *(HWND *)found = hwnd;
      return FALSE;
    }
  return TRUE;
}
#endif

/* Live settings changes (issue #46): the theme hears Windows' broadcasts
   through a hidden window, and on "ImmersiveColorSet" (a theme or accent
   change) reloads, and AppKit's system colours follow. The probe stands
   in an accent (WinUIThemeAccentColorHex, red) for Settings' and sends
   the message to this thread's listener. */
- (void) checkLiveSettings
{
#ifdef _WIN32
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableArray *searchList = nil;
  HWND listener = NULL;
  NSColor *changed = nil;
  NSColor *restored = nil;

  EnumThreadWindows(GetCurrentThreadId(), QuirkProbeFindListener, (LPARAM)&listener);
  if (listener == NULL)
    {
      [self fail: @"live-accent-change" detail: @"the theme has no settings listener window"];
      return;
    }
  if (QuirkProbeHasArgument(@"--high-contrast", nil))
    {
      [self skip: @"live-accent-change" detail: @"high contrast uses the contrast theme's colours"];
      return;
    }

  [defaults setVolatileDomain: [NSDictionary dictionaryWithObject: @"C42B1C"
                                                           forKey: @"WinUIThemeAccentColorHex"]
                      forName: @"QuirkProbeLive"];
  searchList = AUTORELEASE([[defaults searchList] mutableCopy]);
  [searchList insertObject: @"QuirkProbeLive" atIndex: 0];
  [defaults setSearchList: searchList];
  SendMessageW(listener, WM_SETTINGCHANGE, 0, (LPARAM)L"ImmersiveColorSet");
  QuirkProbeDispatchEvents(0.6);
  changed = [[NSColor selectedControlColor] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];

  [searchList removeObject: @"QuirkProbeLive"];
  [defaults setSearchList: searchList];
  [defaults removeVolatileDomainForName: @"QuirkProbeLive"];
  SendMessageW(listener, WM_SETTINGCHANGE, 0, (LPARAM)L"ImmersiveColorSet");
  QuirkProbeDispatchEvents(0.6);
  restored = [[NSColor selectedControlColor] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];

  if ([changed redComponent] > [changed blueComponent] + 0.25
      && QuirkProbeIsAccentBlue([restored redComponent] * 255, [restored greenComponent] * 255,
                                [restored blueComponent] * 255))
    {
      [self pass: @"live-accent-change" detail: [NSString stringWithFormat:
        @"the accent followed the change (%.2f,%.2f,%.2f) and came back",
        [changed redComponent], [changed greenComponent], [changed blueComponent]]];
    }
  else
    {
      [self fail: @"live-accent-change" detail: [NSString stringWithFormat:
        @"after the change the accent was %.2f,%.2f,%.2f, after restoring %.2f,%.2f,%.2f",
        [changed redComponent], [changed greenComponent], [changed blueComponent],
        [restored redComponent], [restored greenComponent], [restored blueComponent]]];
    }
#else
  [self skip: @"live-accent-change" detail: @"Windows only"];
#endif
}

/* WinUI's CheckBox and RadioButton (issue #5): a 20px indicator, and a
   checked radio's accent ring around a 12px centre dot. The theme drew
   18px indicators and an 8px dot. */
- (void) checkIndicators
{
  CGFloat desktop = QuirkProbeDesktopScale();
  /* Frames with room for the indicator at the desktop's scale: a shorter
     one gets a smaller indicator. */
  NSWindow *window = [self windowWithFrame: NSMakeRect(440, 300, 220, 120)
                                     title: @"QuirkProbe Indicators"];
  NSButton *checkbox = AUTORELEASE([[NSButton alloc] initWithFrame:
    NSMakeRect(20, 64, 160, 24 * desktop)]);
  NSButton *radio = AUTORELEASE([[NSButton alloc] initWithFrame:
    NSMakeRect(20, 16, 160, 24 * desktop)]);
  NSBitmapImageRep *rep = nil;
  CGFloat scale;
  QuirkProbeInk box, ring;
  NSInteger centreY, x, dot = 0;

  if (QuirkProbeHasArgument(@"--high-contrast", nil))
    {
      [self skip: @"checkbox-indicator-size" detail: @"high contrast's highlight may not be blue"];
      [self skip: @"radio-centre-dot" detail: @"high contrast's highlight may not be blue"];
      return;
    }
  [checkbox setButtonType: NSSwitchButton];
  [checkbox setTitle: @"Checked"];
  [checkbox setState: NSOnState];
  [radio setButtonType: NSRadioButton];
  [radio setTitle: @"Selected"];
  [radio setState: NSOnState];
  [[window contentView] addSubview: checkbox];
  [[window contentView] addSubview: radio];
  [window orderFront: nil];
  [window display];

  rep = QuirkProbeRender(checkbox);
  scale = QuirkProbeScale(rep, checkbox);
  [self saveView: checkbox named: @"checkbox-indicator"];
  box = QuirkProbeMeasureIn(rep, QuirkProbeIsAccentBlue, NSMakeRect(0, 0, 40 * desktop * scale, [rep pixelsHigh]));
  if (llabs((long long)box.width - (long long)round(20.0 * desktop * scale)) <= 1
      && llabs((long long)box.height - (long long)round(20.0 * desktop * scale)) <= 1)
    {
      [self pass: @"checkbox-indicator-size" detail: [NSString stringWithFormat:
        @"a %ldx%ld px accent box", (long)box.width, (long)box.height]];
    }
  else
    {
      [self fail: @"checkbox-indicator-size" detail: [NSString stringWithFormat:
        @"the accent box is %ldx%ld px, expected %.0f", (long)box.width, (long)box.height,
        round(20.0 * desktop * scale)]];
    }

  rep = QuirkProbeRender(radio);
  [self saveView: radio named: @"radio-indicator"];
  ring = QuirkProbeMeasureIn(rep, QuirkProbeIsAccentBlue, NSMakeRect(0, 0, 40 * desktop * scale, [rep pixelsHigh]));
  centreY = ring.minY + ring.height / 2;
  for (x = ring.minX; x < ring.minX + ring.width; x++)
    {
      NSUInteger red, green, blue;

      if (QuirkProbePixel(rep, x, centreY, &red, &green, &blue)
          && QuirkProbeIsAccentBlue(red, green, blue) == NO)
        {
          dot++;
        }
    }
  if (llabs((long long)ring.width - (long long)round(20.0 * desktop * scale)) <= 1
      && fabs(dot - 12.0 * desktop * scale) <= 2.0)
    {
      [self pass: @"radio-centre-dot" detail: [NSString stringWithFormat:
        @"a %ld px ring around a %ld px dot", (long)ring.width, (long)dot]];
    }
  else
    {
      [self fail: @"radio-centre-dot" detail: [NSString stringWithFormat:
        @"a %ld px ring around a %ld px dot; expected %.0f and %.0f", (long)ring.width, (long)dot,
        round(20.0 * desktop * scale), 12.0 * desktop * scale]];
    }
  [window orderOut: nil];
}

/* WinUI's type ramp (issue #44): the interface font is Segoe UI Variable
   (Segoe UI without it, as on Windows 10) at Body's 14px, scaled by
   Windows' text size (-WinUIThemeTextScaleFactor stands in for it); bold
   is the family's Semibold, not another face; a default button's title
   is regular weight. */
- (void) checkTypography
{
  NSFontManager *manager = [NSFontManager sharedFontManager];
  NSFont *body = [NSFont systemFontOfSize: 0];
  NSFont *bold = [NSFont boldSystemFontOfSize: 0];
  NSString *family = [[manager availableFontFamilies] containsObject: @"Segoe UI Variable"]
    ? @"Segoe UI Variable" : @"Segoe UI";
  CGFloat textScale = [[NSUserDefaults standardUserDefaults] floatForKey: @"WinUIThemeTextScaleFactor"];
  /* Compact metrics (#31) use GNUstep's 12pt. */
  CGFloat base = QuirkProbeCompactMetrics() ? 12.0 : 14.0;
  CGFloat size = round(base * ((textScale >= 100.0) ? textScale / 100.0 : 1.0));
  NSString *detail = nil;

  detail = [NSString stringWithFormat: @"the system font is %@ (%@) at %.1f; expected %@ at %.0f",
                     [body fontName], [body familyName], [body pointSize], family, size];
  if ([[body familyName] isEqualToString: family] && fabs([body pointSize] - size) < 0.01)
    {
      [self pass: @"typography-body" detail: detail];
    }
  else
    {
      [self fail: @"typography-body" detail: detail];
    }

  detail = [NSString stringWithFormat: @"the bold system font is %@ (%@), weight %ld",
                     [bold fontName], [bold familyName], (long)[manager weightOfFont: bold]];
  if ([[bold familyName] isEqualToString: [body familyName]] && [manager weightOfFont: bold] == 7)
    {
      [self pass: @"typography-bold-semibold" detail: detail];
    }
  else
    {
      [self fail: @"typography-bold-semibold" detail:
        [detail stringByAppendingString: @"; expected the body's family at Semibold (7)"]];
    }

  {
    NSWindow *window = [self windowWithFrame: NSMakeRect(420, 360, 200, 80)
                                       title: @"QuirkProbe Typography"];
    NSButton *button = AUTORELEASE([[NSButton alloc] initWithFrame: NSMakeRect(20, 20, 120, 32)]);
    NSFont *titleFont = nil;

    [button setButtonType: NSMomentaryPushInButton];
    [button setBezelStyle: NSRoundedBezelStyle];
    [button setTitle: @"OK"];
    [button setKeyEquivalent: @"\r"];
    [[window contentView] addSubview: button];
    [window orderFront: nil];
    [window display];
    titleFont = [[[button cell] attributedTitle] attribute: NSFontAttributeName
                                                   atIndex: 0
                                            effectiveRange: NULL];
    detail = [NSString stringWithFormat: @"the default button's title is %@, weight %ld",
                       [titleFont fontName], (long)[manager weightOfFont: titleFont]];
    if (titleFont != nil && [manager weightOfFont: titleFont] <= 5)
      {
        [self pass: @"typography-default-button-regular" detail: detail];
      }
    else
      {
        [self fail: @"typography-default-button-regular" detail: detail];
      }
    [window orderOut: nil];
  }
}

/* The title's ink in `frame` of `content` (a render `rep`), between
   `leading` and `trailing` points in from its sides, on the background at
   `sample` points in from the frame's top left. */
static QuirkProbeInk
QuirkProbeTitleInk(NSBitmapImageRep *rep, NSView *content, NSRect frame,
                   CGFloat leading, CGFloat trailing, NSPoint sample)
{
  CGFloat scale = QuirkProbeScale(rep, content);
  NSRect area = QuirkProbePixelRect(content, frame, scale);

  QuirkProbeInkBackground = QuirkProbeBrightnessAt(rep, 1.0,
                                                   NSMinX(area) + sample.x * scale,
                                                   NSMinY(area) + sample.y * scale);
  area.origin.x += leading * scale;
  area.size.width -= (leading + trailing) * scale;
  area.origin.y += 3 * scale;
  area.size.height -= 6 * scale;
  return QuirkProbeMeasureIn(rep, QuirkProbeIsInk, area);
}

/* -sizeToFit and -cellSize measure with the theme's drawing geometry
   (issue #14): a control sized to fit shows as much of its title as one
   200pt wider, and a narrow button's padding gives way before its title.
   Under Adwaita "Sign In" became "Sign", and a 44pt "20" drew nothing. */
- (void) checkSizeToFit
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(300, 120, 640, 260)
                                     title: @"QuirkProbe Size To Fit"];
  NSView *content = [window contentView];
  NSString *names[5] = { @"button", @"narrow-button", @"checkbox", @"radio", @"popup" };
  NSControl *fitted[5];
  NSControl *wide[5];
  NSBitmapImageRep *rep = nil;
  NSUInteger index;

  for (index = 0; index < 5; index++)
    {
      NSInteger pass;

      for (pass = 0; pass < 2; pass++)
        {
          NSRect frame = NSMakeRect(20, 210 - 45 * index, 100, 32);
          NSControl *control = nil;

          if (index == 4)
            {
              NSPopUpButton *popup = AUTORELEASE([[NSPopUpButton alloc] initWithFrame: frame
                                                                              pullsDown: NO]);

              [popup addItemWithTitle: @"Errors only"];
              [popup addItemWithTitle: @"All"];
              control = popup;
            }
          else
            {
              NSButton *button = AUTORELEASE([[NSButton alloc] initWithFrame: frame]);

              if (index <= 1)
                {
                  [button setButtonType: NSMomentaryPushInButton];
                  [button setBezelStyle: NSRoundedBezelStyle];
                  [button setTitle: (index == 0) ? @"Sign In" : @"20"];
                }
              else
                {
                  [button setButtonType: (index == 2) ? NSSwitchButton : NSRadioButton];
                  [button setTitle: @"Errors only"];
                }
              control = button;
            }
          [content addSubview: control];
          if (index == 1)
            {
              [control setFrameSize: NSMakeSize(44, 32)];
            }
          else
            {
              [control sizeToFit];
            }
          if (pass == 1)
            {
              NSSize size = [fitted[index] frame].size;

              [control setFrame: NSMakeRect(300, NSMinY(frame), size.width + 200, size.height)];
              wide[index] = control;
            }
          else
            {
              fitted[index] = control;
            }
        }
    }
  [window orderFront: nil];
  [window display];
  rep = QuirkProbeRender(content);
  [self saveView: content named: @"size-to-fit"];

  for (index = 0; index < 5; index++)
    {
      /* Buttons: all of the interior, on the fill. Checkboxes and radios:
         right of the indicator, on the window. Pop-ups: left of the
         chevron, on the fill. A checkbox's title runs to its frame's edge. */
      CGFloat leading = (index == 2 || index == 3) ? 24 : 3;
      CGFloat trailing = (index == 4) ? 30 : ((index == 2 || index == 3) ? 0 : 3);
      NSPoint sample = (index == 2 || index == 3) ? NSMakePoint(-2, 2)
        : NSMakePoint(4, NSHeight([fitted[index] frame]) / 2.0);
      QuirkProbeInk fittedInk = QuirkProbeTitleInk(rep, content, [fitted[index] frame],
                                                   leading, trailing, sample);
      QuirkProbeInk wideInk = QuirkProbeTitleInk(rep, content, [wide[index] frame],
                                                 leading, trailing, sample);
      NSString *check = [@"size-to-fit-" stringByAppendingString: names[index]];
      NSString *detail = [NSString stringWithFormat:
        @"%.0fpt wide: title ink %ld px wide (%lu px), %ld px (%lu px) with 200pt more",
        NSWidth([fitted[index] frame]), (long)fittedInk.width, (unsigned long)fittedInk.count,
        (long)wideInk.width, (unsigned long)wideInk.count];

      if (wideInk.count > 20
          && llabs((long long)(fittedInk.width - wideInk.width)) <= 1
          && fittedInk.count * 20 >= wideInk.count * 19)
        {
          [self pass: check detail: detail];
        }
      else
        {
          [self fail: check detail: [detail stringByAppendingString: @": the title is cut"]];
        }
    }
  for (index = 0; index < 5; index++)
    {
      [fitted[index] removeFromSuperview];
      [wide[index] removeFromSuperview];
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

      /* Shortcuts are right-aligned (issue #13: with libs-gui after 0.32,
         0.32's NSRightTextAlignment centred them). */
      {
        CGFloat trailing = (width - 1 - lastInk) / scale;

        /* WinUI's 12pt padding, and the side bearing. */
        if (trailing <= 18.0)
          {
            [self pass: @"menu-shortcut-trailing" detail: [NSString stringWithFormat:
              @"the shortcut ends %.0fpt from the flyout's edge", trailing]];
          }
        else
          {
            [self fail: @"menu-shortcut-trailing" detail: [NSString stringWithFormat:
              @"the shortcut ends %.0fpt from the flyout's edge: not right-aligned", trailing]];
          }
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
/* Window tabs (#72): the theme installs Apple's tabbing API (the shared
   gnustep-window-tabbing code) and draws the bar as WinUI's TabView: a
   40pt strip above the content, the selected tab in the content's colour
   with no line under it, a 32x24 close button on every tab, titles cut
   short with an ellipsis, and a "+" right after the last tab only when
   something answers -newWindowForTab:. Before, NSWindow had no tabbing at
   all. */

/* A key press with the Ctrl key, as `window` gets it. */
static NSEvent *
QuirkProbeTabKey(NSWindow *window, NSString *characters, NSUInteger modifiers)
{
  return [NSEvent keyEventWithType: NSKeyDown
                          location: NSZeroPoint
                     modifierFlags: modifiers
                         timestamp: 0
                      windowNumber: [window windowNumber]
                           context: nil
                        characters: characters
       charactersIgnoringModifiers: characters
                         isARepeat: NO
                           keyCode: 0];
}

- (void) checkWindowTabs
{
  BOOL highContrast = QuirkProbeHasArgument(@"--high-contrast", @"yes");
  CGFloat desktop = QuirkProbeDesktopScale();
  NSString *missing = @"no tab bar: NSWindow lacks -addTabbedWindow:ordered: (the theme doesn't install window tabbing)";
  NSWindow *first = nil;
  NSWindow *second = nil;
  NSView *decoration = nil;
  NSView *content = nil;
  NSView *bar = nil;
  NSBitmapImageRep *rep = nil;
  NSRect barFrame;
  NSRect selectedTab;
  NSRect otherTab;
  NSRect closeRect;
  NSRect otherClose;
  NSRect newTab;
  NSUInteger selectedLow[3], selectedFoot[3], contentTop[3], otherLow[3], otherFoot[3];
  NSUInteger strip[3];
  QuirkProbeInk ink;
  CGFloat x;

  if ([NSWindow instancesRespondToSelector: @selector(addTabbedWindow:ordered:)] == NO)
    {
      [self fail: @"window-tabs-api" detail: @"NSWindow lacks Apple's tabbing API"];
      [self fail: @"window-tab-bar" detail: missing];
      [self fail: @"window-tab-joined" detail: missing];
      [self fail: @"window-tab-close-button" detail: missing];
      [self fail: @"window-tab-title-fitted" detail: missing];
      [self fail: @"window-tab-new-button" detail: missing];
      [self fail: @"window-tab-shortcut-over-text-view" detail: missing];
      [self fail: @"window-tab-takes-placement" detail: missing];
      [self fail: @"window-tab-keeps-group-frame" detail: missing];
      [self fail: @"window-tab-close-shows-neighbour" detail: missing];
      return;
    }
  [self pass: @"window-tabs-api" detail: @"NSWindow has -addTabbedWindow:ordered:"];

  first = [self windowWithFrame: NSMakeRect(120, 220, 480, 220) title: @"QuirkProbe Tab One"];
  second = [self windowWithFrame: NSMakeRect(120, 220, 480, 220) title: @"QuirkProbe Tab Two"];
  [first orderFront: nil];
  [first addTabbedWindow: second ordered: NSWindowAbove];
  [second display];

  content = [second contentView];
  decoration = [content superview];
  bar = QuirkProbeFindTabBar(decoration);
  if (bar == nil || [bar window] != second || [bar numberOfTabs] != 2)
    {
      NSString *detail = [NSString stringWithFormat: @"two tabbed windows show no bar with two tabs (bar %@, %lu tabs)",
                                   bar, (unsigned long)[bar numberOfTabs]];

      [self fail: @"window-tab-bar" detail: detail];
      [self fail: @"window-tab-joined" detail: detail];
      [self fail: @"window-tab-close-button" detail: detail];
      [self fail: @"window-tab-title-fitted" detail: detail];
      [self fail: @"window-tab-new-button" detail: detail];
      [self fail: @"window-tab-shortcut-over-text-view" detail: detail];
      [self fail: @"window-tab-takes-placement" detail: detail];
      [self fail: @"window-tab-keeps-group-frame" detail: detail];
      [self fail: @"window-tab-close-shows-neighbour" detail: detail];
      [second close];
      [first close];
      return;
    }

  /* A strip of 40pt (scaled with the desktop), right above the content. */
  barFrame = [bar frame];
  if (fabs(NSHeight(barFrame) - round(40.0 * desktop)) < 0.5
      && fabs(NSMinY(barFrame) - NSMaxY([content frame])) < 0.5
      && fabs(NSWidth(barFrame) - NSWidth([content frame])) < 0.5)
    {
      [self pass: @"window-tab-bar" detail:
        [NSString stringWithFormat: @"%.0fpt bar above the content", NSHeight(barFrame)]];
    }
  else
    {
      [self fail: @"window-tab-bar" detail:
        [NSString stringWithFormat: @"bar %@, content %@ (want a %.0fpt bar right above the content)",
                  NSStringFromRect(barFrame), NSStringFromRect([content frame]), round(40.0 * desktop)]];
    }

  /* The selected tab (the second) is the content's colour down to the
     content, while a line runs under the other tab and the strip behind
     it is a step darker. */
  selectedTab = [bar rectForTabAtIndex: 1];
  otherTab = [bar rectForTabAtIndex: 0];
  rep = QuirkProbeRender(decoration);
  x = NSMinX(selectedTab) + 20.0;
  if (QuirkProbeTabPixel(rep, decoration, bar, NSMakePoint(x, 3.0), selectedLow)
      && QuirkProbeTabPixel(rep, decoration, bar, NSMakePoint(x, 0.0), selectedFoot)
      && QuirkProbeTabPixel(rep, decoration, bar, NSMakePoint(x, -3.0), contentTop)
      && QuirkProbeTabPixel(rep, decoration, bar, NSMakePoint(NSMinX(otherTab) + 20.0, 3.0), otherLow)
      && QuirkProbeTabPixel(rep, decoration, bar, NSMakePoint(NSMinX(otherTab) + 20.0, 0.0), otherFoot))
    {
      BOOL joined = QuirkProbeTabColorDistance(selectedLow, contentTop) <= 6
        && QuirkProbeTabColorDistance(selectedFoot, contentTop) <= 6;
      BOOL lineUnderOther = QuirkProbeTabColorDistance(otherFoot, contentTop) > 4;
      BOOL stripDiffers = QuirkProbeTabColorDistance(otherLow, contentTop) > 3;
      NSString *detail = [NSString stringWithFormat:
        @"selected tab %@ (foot %@), content %@, other tab %@ (foot %@)",
        QuirkProbeTabHex(selectedLow), QuirkProbeTabHex(selectedFoot), QuirkProbeTabHex(contentTop),
        QuirkProbeTabHex(otherLow), QuirkProbeTabHex(otherFoot)];

      /* Contrast themes may give ButtonFace (the strip) Window's colour. */
      if (joined && lineUnderOther && (stripDiffers || highContrast))
        {
          [self pass: @"window-tab-joined" detail: detail];
        }
      else
        {
          [self fail: @"window-tab-joined" detail: detail];
        }
    }
  else
    {
      [self fail: @"window-tab-joined" detail: @"couldn't read the render"];
    }
  [self saveView: decoration named: @"window-tabs"];

  /* A close button (32x24, 4pt from the trailing edge) on the selected tab
     and on the other one (WinUI's CloseButtonOverlayMode Auto is Always),
     with a cross in it. */
  closeRect = [bar closeButtonRectForTabAtIndex: 1];
  otherClose = [bar closeButtonRectForTabAtIndex: 0];
  QuirkProbeInkBackground = selectedLow[0] + selectedLow[1] + selectedLow[2];
  ink = QuirkProbeTabInk(rep, decoration, bar, closeRect, QuirkProbeIsInk);
  if (NSIsEmptyRect(closeRect) == NO && NSIsEmptyRect(otherClose) == NO
      && NSContainsRect(selectedTab, closeRect)
      && fabs(NSWidth(closeRect) - round(32.0 * desktop)) < 0.5
      && fabs(NSHeight(closeRect) - round(24.0 * desktop)) < 0.5
      && NSMaxX(selectedTab) - NSMaxX(closeRect) <= round(6.0 * desktop)
      && ink.count > 0)
    {
      [self pass: @"window-tab-close-button" detail:
        [NSString stringWithFormat: @"%@ in tab %@, cross of %lu pixels",
                  NSStringFromRect(closeRect), NSStringFromRect(selectedTab), (unsigned long)ink.count]];
    }
  else
    {
      [self fail: @"window-tab-close-button" detail:
        [NSString stringWithFormat: @"selected tab %@: close %@ (%lu ink pixels); other tab's close %@",
                  NSStringFromRect(selectedTab), NSStringFromRect(closeRect),
                  (unsigned long)ink.count, NSStringFromRect(otherClose)]];
    }

  /* A long title ends in an ellipsis before the close button: nothing in
     the gap between the title's area and the cross. */
  [first setTitle: @"QuirkProbe tab whose title is much too long to fit in its tab"];
  [second display];
  rep = QuirkProbeRender(decoration);
  otherClose = [bar closeButtonRectForTabAtIndex: 0];
  if (QuirkProbeTabPixel(rep, decoration, bar, NSMakePoint(NSMinX(otherTab) + 4.0, 3.0), strip))
    {
      QuirkProbeInk title;
      NSRect body = NSMakeRect(NSMinX(otherTab), 4.0 * desktop, NSWidth(otherTab), 24.0 * desktop);
      NSRect gap = NSMakeRect(NSMinX(otherClose) - 4.0 * desktop, NSMinY(body),
                              10.0 * desktop, NSHeight(body));
      NSRect titleArea = NSMakeRect(NSMinX(otherTab) + 6.0 * desktop, NSMinY(body),
                                    NSMinX(gap) - NSMinX(otherTab) - 6.0 * desktop, NSHeight(body));

      QuirkProbeInkBackground = strip[0] + strip[1] + strip[2];
      title = QuirkProbeTabInk(rep, decoration, bar, titleArea, QuirkProbeIsInk);
      ink = QuirkProbeTabInk(rep, decoration, bar, gap, QuirkProbeIsFaintInk);
      if (title.count > 20 && ink.count == 0)
        {
          [self pass: @"window-tab-title-fitted" detail:
            [NSString stringWithFormat: @"title of %lu pixels, the gap before the close button clear",
                      (unsigned long)title.count]];
        }
      else
        {
          [self fail: @"window-tab-title-fitted" detail:
            [NSString stringWithFormat: @"title %lu pixels, %lu in the gap before the close button %@",
                      (unsigned long)title.count, (unsigned long)ink.count, NSStringFromRect(otherClose)]];
        }
    }
  else
    {
      [self fail: @"window-tab-title-fitted" detail: @"couldn't read the render"];
    }

  /* The "+": none while nothing answers -newWindowForTab:, then right
     after the last tab, with a plus in it. */
  _offersNewTab = NO;
  newTab = [bar newTabButtonRect];
  if (NSIsEmptyRect(newTab) == NO)
    {
      [self fail: @"window-tab-new-button" detail:
        [NSString stringWithFormat: @"a \"+\" at %@ though nothing answers -newWindowForTab:",
                  NSStringFromRect(newTab)]];
    }
  else
    {
      _offersNewTab = YES;
      [bar setNeedsDisplay: YES];
      [second display];
      newTab = [bar newTabButtonRect];
      rep = QuirkProbeRender(decoration);
      QuirkProbeInkBackground = strip[0] + strip[1] + strip[2];
      ink = QuirkProbeTabInk(rep, decoration, bar,
                             NSMakeRect(NSMinX(newTab) + 8.0 * desktop, 6.0 * desktop,
                                        24.0 * desktop, 20.0 * desktop),
                             QuirkProbeIsInk);
      if (NSIsEmptyRect(newTab) == NO
          && fabs(NSMinX(newTab) - NSMaxX([bar rectForTabAtIndex: 1])) <= 1.0
          && ink.count > 0)
        {
          [self pass: @"window-tab-new-button" detail:
            [NSString stringWithFormat: @"none without a responder; with one at %@ after the last tab %@",
                      NSStringFromRect(newTab), NSStringFromRect([bar rectForTabAtIndex: 1])]];
        }
      else
        {
          [self fail: @"window-tab-new-button" detail:
            [NSString stringWithFormat: @"with a responder: \"+\" %@ (%lu ink pixels), last tab %@",
                      NSStringFromRect(newTab), (unsigned long)ink.count,
                      NSStringFromRect([bar rectForTabAtIndex: 1])]];
        }
      _offersNewTab = NO;
    }

  /* Ctrl+Tab and Ctrl+Page Down select the next tab ahead of a text view
     with focus, whichever modifier the Ctrl key arrives as: Command under
     GNUstep's default key mapping (the theme's), Control otherwise. The
     shared code before 4cb1b63 let the text view take them (a tab
     inserted, a page scrolled). */
  {
    NSTextView *secondText = AUTORELEASE([[NSTextView alloc] initWithFrame: NSMakeRect(10, 10, 200, 60)]);
    NSTextView *firstText = AUTORELEASE([[NSTextView alloc] initWithFrame: NSMakeRect(10, 10, 200, 60)]);
    BOOL byTab;
    BOOL byPage;
    NSString *typed;

    [content addSubview: secondText];
    [second makeFirstResponder: secondText];
    [[first contentView] addSubview: firstText];
    [first makeFirstResponder: firstText];
    [second sendEvent: QuirkProbeTabKey(second, @"\t", NSCommandKeyMask)];
    byTab = [first isVisible] && [second isVisible] == NO;
    [first sendEvent: QuirkProbeTabKey(first, [NSString stringWithFormat: @"%C", (unichar)NSPageDownFunctionKey],
                                       NSControlKeyMask)];
    byPage = [second isVisible] && [first isVisible] == NO;
    typed = [[secondText string] stringByAppendingString: [firstText string]];
    if (byTab && byPage && [typed length] == 0)
      {
        [self pass: @"window-tab-shortcut-over-text-view" detail:
          @"Command+Tab and Control+Page Down selected the next tab; the text views got nothing"];
      }
    else
      {
        [self fail: @"window-tab-shortcut-over-text-view" detail:
          [NSString stringWithFormat: @"Ctrl+Tab selected the next tab %d, Ctrl+Page Down %d, the text views got %lu characters",
                    (int)byTab, (int)byPage, (unsigned long)[typed length]]];
      }
    if ([second isVisible] == NO)
      {
        [second makeKeyAndOrderFront: nil];
      }
    [second makeFirstResponder: nil];
    [first makeFirstResponder: nil];
    [secondText removeFromSuperview];
    [firstText removeFromSuperview];
  }

  /* Windows keeps maximized per window: a tab selected while its group
     was maximized took the group's frame but wasn't maximized (the caption
     button and a double-click didn't restore it), and one maximized
     before came back maximized in a restored group. The selected tab now
     takes the previous one's placement. */
#ifdef _WIN32
  {
    HWND firstHandle = (HWND)(intptr_t)[first windowNumber];
    HWND secondHandle = (HWND)(intptr_t)[second windowNumber];
    BOOL tookMaximized;
    BOOL tookRestored;

    [second makeKeyAndOrderFront: nil];
    QuirkProbeDispatchEvents(0.2);
    ShowWindow(secondHandle, SW_MAXIMIZE);
    QuirkProbeDispatchEvents(0.4);
    [second selectNextTab: nil];
    QuirkProbeDispatchEvents(0.4);
    tookMaximized = [first isVisible] && IsZoomed(firstHandle);
    ShowWindow(firstHandle, SW_RESTORE);
    QuirkProbeDispatchEvents(0.4);
    [first selectNextTab: nil];
    QuirkProbeDispatchEvents(0.4);
    tookRestored = [second isVisible] && IsZoomed(secondHandle) == 0;
    if (tookMaximized && tookRestored)
      {
        [self pass: @"window-tab-takes-placement" detail:
          @"a tab selected in a maximized group is maximized, and one maximized before is restored in a restored group"];
      }
    else
      {
        [self fail: @"window-tab-takes-placement" detail:
          [NSString stringWithFormat: @"selected in a maximized group: maximized %d; selected in a restored group: restored %d",
                    (int)tookMaximized, (int)tookRestored]];
      }
    /* Only the tab on screen: restoring a hidden one would show it. */
    if ([second isVisible] == NO)
      {
        [second makeKeyAndOrderFront: nil];
        QuirkProbeDispatchEvents(0.3);
      }
    if (IsZoomed(secondHandle))
      {
        ShowWindow(secondHandle, SW_RESTORE);
      }
    QuirkProbeDispatchEvents(0.3);
  }
#endif

  /* A new tab takes its group's frame. The theme gives a window made
     after launch the main menu's bar when it becomes main, which made it
     taller: each new tab grew the group by a menu bar. */
  {
    NSWindow *third = [self windowWithFrame: NSMakeRect(160, 160, 300, 120)
                                      title: @"QuirkProbe Tab Three"];
    NSRect groupFrame = [second frame];

    [second addTabbedWindow: third ordered: NSWindowAbove];
    [third makeMainWindow];
    if ([third menu] == nil)
      {
        [self skip: @"window-tab-keeps-group-frame" detail: @"the new tab got no menu bar"];
      }
    else if (NSEqualRects([third frame], groupFrame))
      {
        [self pass: @"window-tab-keeps-group-frame" detail:
          [NSString stringWithFormat: @"%@ with its menu bar", NSStringFromRect(groupFrame)]];
      }
    else
      {
        [self fail: @"window-tab-keeps-group-frame" detail:
          [NSString stringWithFormat: @"the group's frame %@, the new tab's %@ once it has the menu bar",
                    NSStringFromRect(groupFrame), NSStringFromRect([third frame])]];
      }
    [third close];
  }

  /* Closing the selected tab: its neighbour is on screen by the time the
     window says it will close. NSApplication counts the windows on screen
     then, and took the selected tab for the app's last window, quitting
     the app under Windows-style menus. */
  {
    QuirkProbeCloseWatcher *watcher = [QuirkProbeCloseWatcher new];
    NSWindow *selected = [[second tabbedWindows] count] > 1 ? second : nil;

    watcher->_closing = second;
    watcher->_other = first;
    [[NSNotificationCenter defaultCenter] addObserver: watcher
                                             selector: @selector(windowWillClose:)
                                                 name: NSWindowWillCloseNotification
                                               object: nil];
    [second close];
    [[NSNotificationCenter defaultCenter] removeObserver: watcher];
    if (selected == nil)
      {
        [self fail: @"window-tab-close-shows-neighbour" detail: @"the second window wasn't in a group"];
      }
    else if (watcher->_heard && watcher->_otherVisible && [first isVisible])
      {
        [self pass: @"window-tab-close-shows-neighbour" detail:
          @"the neighbour was on screen when the selected tab began to close"];
      }
    else
      {
        [self fail: @"window-tab-close-shows-neighbour" detail:
          [NSString stringWithFormat: @"heard %d, neighbour on screen then %d, after %d",
                    (int)watcher->_heard, (int)watcher->_otherVisible, (int)[first isVisible]]];
      }
    RELEASE(watcher);
  }
  [first close];
}

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

/* The overlay indicator over content that redraws itself as it scrolls,
   as MarkdownViewer's preview does (auto-hiding scrollers, its own
   background, a document that marks itself dirty). libs-gui drew the
   dirty document after the scroll bar, over it, so the bar never
   showed, though the content scrolled. */
- (void) checkOverlayAutohide
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSWindow *window = nil;
  NSScrollView *scrollView = nil;
  QuirkProbeFillView *document = nil;
  NSTextView *text = nil;
  NSUInteger fill = 3 * 128;
  NSUInteger ink;

  if (QuirkProbeHasArgument(@"--high-contrast", nil))
    {
      [self skip: @"scroller-over-redrawn-content" detail: @"high contrast keeps classic scroll bars"];
      return;
    }
  [defaults setBool: YES forKey: @"WinUIThemeOverlayScrollbars"];
  window = [self windowWithFrame: NSMakeRect(360, 360, 260, 200) title: @"QuirkProbe Autohide"];
  scrollView = AUTORELEASE([[NSScrollView alloc] initWithFrame: NSMakeRect(20, 20, 200, 150)]);
  document = AUTORELEASE([[QuirkProbeFillView alloc] initWithFrame: NSMakeRect(0, 0, 200, 600)]);
  [document setAutoresizingMask: NSViewWidthSizable];
  /* A text view inside it, as MarkdownViewer's preview has, drawing
     nothing of its own here but marking itself dirty. */
  text = AUTORELEASE([[NSTextView alloc] initWithFrame: NSMakeRect(0, 0, 200, 600)]);
  [text setDrawsBackground: NO];
  [text setAutoresizingMask: NSViewWidthSizable];
  [document addSubview: text];
  /* As MarkdownViewer's preview: both scrollers asked for, auto-hidden,
     its own background. */
  [scrollView setHasVerticalScroller: YES];
  [scrollView setHasHorizontalScroller: YES];
  [scrollView setAutohidesScrollers: YES];
  [scrollView setDrawsBackground: YES];
  [scrollView setBackgroundColor: [NSColor whiteColor]];
  [scrollView setBorderType: NSNoBorder];
  [scrollView setDocumentView: document];
  [[window contentView] addSubview: scrollView];
  [window orderFront: nil];
  [window display];

  /* Scrolled as the wheel scrolls it, and redrawn as an app's window is,
     by the run loop: -display would redraw everything. */
  [[scrollView contentView] scrollToPoint: NSMakePoint(0, 200)];
  [scrollView reflectScrolledClipView: [scrollView contentView]];
  [document setNeedsDisplay: YES];
  [text setNeedsDisplay: YES];
  QuirkProbeDispatchEvents(0.15);
  [self saveView: scrollView named: @"scroller-autohide"];
  /* What the window shows, not a fresh drawing of the views, which would
     draw them in order and hide the fault. */
  {
    NSRect strip = [[scrollView verticalScroller] frame];
    NSBitmapImageRep *shown;
    NSInteger x, y;
    CGFloat scale;

    [scrollView lockFocus];
    shown = AUTORELEASE([[NSBitmapImageRep alloc] initWithFocusedViewRect: [scrollView bounds]]);
    [scrollView unlockFocus];
    scale = QuirkProbeScale(shown, scrollView);
    x = (NSInteger)((NSMaxX(strip) - 4.0) * scale);
    ink = 0;
    for (y = [shown pixelsHigh] / 4; y < 3 * [shown pixelsHigh] / 4; y++)
      {
        NSUInteger red, green, blue;

        if (QuirkProbePixel(shown, x, y, &red, &green, &blue)
            && llabs((long long)(red + green + blue) - (long long)fill) > 30)
          {
            ink++;
          }
      }
  }
  if (ink > 0)
    {
      [self pass: @"scroller-over-redrawn-content" detail: [NSString stringWithFormat:
        @"scrolling shows %lu px of indicator", (unsigned long)ink]];
    }
  else
    {
      NSScroller *scroller = [scrollView verticalScroller];

      [self fail: @"scroller-over-redrawn-content" detail: [NSString stringWithFormat:
        @"no indicator while scrolling (scroller %@, in the scroll view: %@, hidden: %@, has: %@, frame %@)",
        scroller != nil ? @"present" : @"nil",
        [scroller superview] == scrollView ? @"yes" : @"no",
        [scroller isHidden] ? @"yes" : @"no",
        [scrollView hasVerticalScroller] ? @"yes" : @"no",
        NSStringFromRect([scroller frame])]];
    }
  QuirkProbeDispatchEvents(1.4);
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
      [self skip: @"scroller-hover-expands" detail: @"high contrast keeps classic scroll bars"];
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

  /* The pointer over the strip reveals the bar, expanded: a 6pt thumb
     down the strip's middle, where the 2pt indicator never reaches. */
  if ([defaults boolForKey: @"ProbeMovesPointer"] == NO)
    {
      [self skip: @"scroller-hover-expands" detail: @"moves the pointer: needs -ProbeMovesPointer YES"];
    }
  else
    {
      NSRect frame = [[scrollView verticalScroller] convertRect: [[scrollView verticalScroller] bounds]
                                                         toView: nil];
      NSUInteger middle, beside;

      [document scrollPoint: NSMakePoint(0, 0)];
      [window makeKeyAndOrderFront: nil];
      QuirkProbeSetPointer([window convertBaseToScreen: NSMakePoint(-40, -40)]);
      QuirkProbeDispatchEvents(0.2);
      QuirkProbeSetPointer([window convertBaseToScreen: NSMakePoint(NSMidX(frame), NSMidY(frame) + 30)]);
      QuirkProbeDispatchEvents(0.4);
      [window display];
      [self saveView: scrollView named: @"scroller-hover"];
      middle = QuirkProbeStripInk(scrollView, fill, NSWidth(strip) / 2.0);
      beside = QuirkProbeStripInk(scrollView, fill, NSWidth(strip) / 2.0 + 2.0);
      QuirkProbeSetPointer([window convertBaseToScreen: NSMakePoint(-40, -40)]);
      QuirkProbeDispatchEvents(1.6);
      [window display];
      if (middle > 0 && beside > 0)
        {
          [self pass: @"scroller-hover-expands" detail: [NSString stringWithFormat:
            @"under the pointer, %lu px of thumb down the strip's middle", (unsigned long)middle]];
        }
      else
        {
          [self fail: @"scroller-hover-expands" detail: [NSString stringWithFormat:
            @"under the pointer, %lu px down the strip's middle and %lu beside it: not expanded",
            (unsigned long)middle, (unsigned long)beside]];
        }
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

  /* Editable, while editing: the value in the editor, a chevron the
     editor doesn't cover, and (but in high contrast) the focus underline
     in the accent along the bottom. */
  [window makeFirstResponder: window];
  [combo setEditable: YES];
  [combo setStringValue: @"Value"];
  [window makeFirstResponder: combo];
  [window display];
  rep = QuirkProbeRender(combo);
  [self saveView: combo named: @"combobox-editing"];
  {
    NSInteger height = [rep pixelsHigh];
    NSInteger width = [rep pixelsWide];
    NSInteger chevron;

    QuirkProbeInkBackground = QuirkProbeBrightnessAt(rep, scale, NSWidth([combo bounds]) - 4.0,
                                                     NSHeight([combo bounds]) / 2.0);
    chevron = QuirkProbeChevronDirection(rep, NSMakeRect(width - 30 * scale, height * 0.25,
                                                         24 * scale, height * 0.5));
    NSUInteger underline = QuirkProbeRowCount(rep, QuirkProbeIsAccentBlue, height - 1,
                                              width / 4, 3 * width / 4);
    NSInteger editorFill = QuirkProbeBrightnessAt(rep, scale, NSWidth([combo bounds]) / 2.0,
                                                  NSHeight([combo bounds]) / 2.0);
    NSUInteger value = QuirkProbeInkIn(rep, NSMakeRect(4 * scale, height * 0.2, 60 * scale, height * 0.6),
                                       editorFill, 150, NULL);
    BOOL underlined = highContrast || underline >= (NSUInteger)(width / 2 - 4);

    if ([combo currentEditor] != nil && value > 10 && chevron == -1 && underlined)
      {
        [self pass: @"combobox-editing" detail: [NSString stringWithFormat:
          @"editing: %lu px of value, a down chevron, %lu px of underline",
          (unsigned long)value, (unsigned long)underline]];
      }
    else
      {
        [self fail: @"combobox-editing" detail: [NSString stringWithFormat:
          @"editing: %@ editor, %lu px of value, chevron %ld (want -1), %lu px of underline",
          [combo currentEditor] != nil ? @"an" : @"no", (unsigned long)value, (long)chevron,
          (unsigned long)underline]];
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

/* A selected row's text is readable whatever colour the app gives it
   (issue #66). In light and dark the app uses selectedControlTextColor,
   which was white over WinUI's near-white selection; in high contrast it
   keeps controlTextColor, which was black on the black highlight. A table
   gets its colours from attributed strings, an outline from
   -willDisplayCell:. */
- (void) checkSelectedRowText
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(100, 600, 320, 220)
                                     title: @"QuirkProbe Row Text"];
  BOOL highContrast = QuirkProbeHasArgument(@"--high-contrast", nil);
  NSColor *color = highContrast ? [NSColor controlTextColor] : [NSColor selectedControlTextColor];
  QuirkProbeColouredRows *rows = AUTORELEASE([[QuirkProbeColouredRows alloc] initWithColor: color]);
  NSTableView *table = AUTORELEASE([[NSTableView alloc] initWithFrame: NSMakeRect(10, 120, 300, 90)]);
  NSOutlineView *outline = AUTORELEASE([[NSOutlineView alloc] initWithFrame: NSMakeRect(10, 10, 300, 100)]);
  NSTableColumn *column = AUTORELEASE([[NSTableColumn alloc] initWithIdentifier: @"name"]);
  NSTableColumn *outlineColumn = AUTORELEASE([[NSTableColumn alloc] initWithIdentifier: @"name"]);
  NSArray *views = [NSArray arrayWithObjects: table, outline, nil];
  NSArray *names = [NSArray arrayWithObjects: @"selected-row-text-table", @"selected-row-text-outline", nil];
  NSUInteger i;

  [column setWidth: 280];
  [table addTableColumn: column];
  [table setHeaderView: nil];
  [table setDataSource: rows];
  [outlineColumn setWidth: 280];
  [outline addTableColumn: outlineColumn];
  [outline setOutlineTableColumn: outlineColumn];
  [outline setHeaderView: nil];
  [outline setDataSource: rows];
  [outline setDelegate: (id)rows];
  [[window contentView] addSubview: table];
  [[window contentView] addSubview: outline];
  [window makeKeyAndOrderFront: nil];
  [table reloadData];
  [outline reloadData];
  [table selectRowIndexes: [NSIndexSet indexSetWithIndex: 1] byExtendingSelection: NO];
  [outline selectRowIndexes: [NSIndexSet indexSetWithIndex: 1] byExtendingSelection: NO];
  [window makeFirstResponder: table];
  [window display];

  for (i = 0; i < [views count]; i++)
    {
      NSTableView *view = [views objectAtIndex: i];
      NSBitmapImageRep *rep = QuirkProbeRender(view);
      CGFloat scale = QuirkProbeScale(rep, view);
      NSUInteger ink = QuirkProbeSelectedRowInk(view, 1, rep, scale);

      [self saveView: view named: [names objectAtIndex: i]];
      if (ink >= (NSUInteger)(20 * scale * scale))
        {
          [self pass: [names objectAtIndex: i] detail: [NSString stringWithFormat:
            @"%lu px of text stand out from the selection", (unsigned long)ink]];
        }
      else
        {
          [self fail: [names objectAtIndex: i] detail: [NSString stringWithFormat:
            @"only %lu px of the selected row's text stand out from its fill: unreadable",
            (unsigned long)ink]];
        }
    }
  [table setDataSource: nil];
  [outline setDataSource: nil];
  [outline setDelegate: nil];
  [window orderOut: nil];
}

/* WinUI's ToolTip (issue #22): Caption text (12px times the text size)
   inside ToolTipBorderPadding, 9pt from the left and 6pt from the top,
   rather than libs-gui's 2pt round the text at the body size. The tip is
   shown as GSToolTips shows it when its timer fires, and stays where
   libs-gui put its top edge. */
- (void) checkToolTip
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(300, 400, 240, 100)
                                     title: @"QuirkProbe Tool Tip"];
  NSView *anchor = [window contentView];
  NSString *tip = @"Zoom: Fit to Window";
  NSTimer *fake = [NSTimer timerWithTimeInterval: 1000 target: self selector: @selector(description)
                                        userInfo: tip repeats: NO];
  id tips = nil;
  NSWindow *panel = nil;
  NSEnumerator *enumerator;
  NSWindow *each;
  CGFloat textScale = [[NSUserDefaults standardUserDefaults] floatForKey: @"WinUIThemeTextScaleFactor"];
  CGFloat expectedSize;

  textScale = (textScale >= 100.0) ? textScale / 100.0 : 1.0;
  expectedSize = round(12.0 * textScale);
  [window orderFront: nil];
  [anchor setToolTip: tip];
  tips = [NSClassFromString(@"GSToolTips") performSelector: @selector(tipsForView:) withObject: anchor];
  if (tips == nil || [tips respondsToSelector: @selector(_timedOut:)] == NO)
    {
      [self skip: @"tooltip-padding" detail: @"libs-gui's GSToolTips has no _timedOut:"];
      [self skip: @"tooltip-font" detail: @"libs-gui's GSToolTips has no _timedOut:"];
      [window orderOut: nil];
      return;
    }
  [tips performSelector: @selector(_timedOut:) withObject: fake];
  enumerator = [[NSApp windows] objectEnumerator];
  while ((each = [enumerator nextObject]) != nil)
    {
      if ([each isKindOfClass: NSClassFromString(@"GSTTPanel")] && [each isVisible])
        {
          panel = each;
        }
    }
  if (panel == nil)
    {
      [self fail: @"tooltip-padding" detail: @"no tool tip window appeared"];
      [self fail: @"tooltip-font" detail: @"no tool tip window appeared"];
    }
  else
    {
      NSView *content = [panel contentView];
      NSAttributedString *text = [content valueForKey: @"text"];
      NSFont *font = ([text length] > 0) ? [text attribute: NSFontAttributeName atIndex: 0 effectiveRange: NULL] : nil;
      NSBitmapImageRep *rep;
      CGFloat scale;
      NSUInteger red = 0, green = 0, blue = 0;
      QuirkProbeInk ink;
      CGFloat left, top;

      [content display];
      rep = QuirkProbeRender(content);
      scale = QuirkProbeScale(rep, content);
      [self saveView: content named: @"tooltip"];
      QuirkProbePixel(rep, [rep pixelsWide] / 2, (NSInteger)(2 * scale), &red, &green, &blue);
      QuirkProbeInkBackground = red + green + blue;
      ink = QuirkProbeMeasureIn(rep, QuirkProbeIsInk,
                                NSMakeRect(2 * scale, 2 * scale, [rep pixelsWide] - 4 * scale,
                                           [rep pixelsHigh] - 4 * scale));
      left = ink.minX / scale;
      top = ink.minY / scale;
      /* The ink starts a little inside the text's own box: a glyph's side
         bearing, and above the capitals the line's leading, which grows
         with the font. */
      if (ink.count > 0 && left >= 8.0 && left <= 11.5 && top >= 6.0 && top <= 6.0 + 0.4 * expectedSize)
        {
          [self pass: @"tooltip-padding" detail: [NSString stringWithFormat:
            @"the text starts %.1fpt from the left and %.1fpt from the top of a %.0fx%.0fpt tip",
            left, top, NSWidth([content bounds]), NSHeight([content bounds])]];
        }
      else
        {
          [self fail: @"tooltip-padding" detail: [NSString stringWithFormat:
            @"the text starts %.1fpt from the left and %.1fpt from the top (%lu px of ink): not WinUI's padding",
            left, top, (unsigned long)ink.count]];
        }
      if (font != nil && fabs([font pointSize] - expectedSize) < 0.5)
        {
          [self pass: @"tooltip-font" detail: [NSString stringWithFormat:
            @"%@ at %.0fpt, Caption", [font fontName], [font pointSize]]];
        }
      else
        {
          [self fail: @"tooltip-font" detail: [NSString stringWithFormat:
            @"%@ at %.1fpt, expected Caption at %.0fpt", [font fontName], [font pointSize], expectedSize]];
        }
    }
  if ([tips respondsToSelector: @selector(_endDisplay)])
    {
      [tips performSelector: @selector(_endDisplay)];
    }
  [anchor setToolTip: nil];
  [window orderOut: nil];
}

/* Checkboxes and radios as Gorm's inspectors have them (issues #80 and
   #81): a switch with its box after the title (NSImageRight) has the box
   at the trailing edge, not first with the title right-aligned away from
   it; and a checked radio smaller than WinUI's 20px keeps an accent ring
   round its dot (the dot was a fixed 12px, which filled a compact radio). */
- (void) checkInspectorIndicators
{
  NSWindow *window = [self windowWithFrame: NSMakeRect(420, 300, 260, 100)
                                     title: @"QuirkProbe Indicators"];
  NSButton *trailing = AUTORELEASE([[NSButton alloc] initWithFrame: NSMakeRect(20, 60, 220, 22)]);
  NSButton *radio = AUTORELEASE([[NSButton alloc] initWithFrame: NSMakeRect(20, 20, 120, 16)]);
  NSBitmapImageRep *rep;
  QuirkProbeInk accent;
  CGFloat scale;

  QuirkProbeLoadAccent();
  [trailing setButtonType: NSSwitchButton];
  [trailing setTitle: @"Release when closed"];
  [trailing setImagePosition: NSImageRight];
  [trailing setAlignment: NSRightTextAlignment];
  [trailing setState: NSOnState];
  [radio setButtonType: NSRadioButton];
  [radio setTitle: @"Buffered"];
  [radio setState: NSOnState];
  [[window contentView] addSubview: trailing];
  [[window contentView] addSubview: radio];
  [window orderFront: nil];
  [window display];

  rep = QuirkProbeRender(trailing);
  scale = QuirkProbeScale(rep, trailing);
  [self saveView: trailing named: @"switch-image-right"];
  /* The checked box's accent in the leading and trailing 30pt (the
     title, in the middle, may share the accent's colour in high
     contrast). */
  {
    NSInteger edge = (NSInteger)(30 * scale);
    QuirkProbeInk leading = QuirkProbeMeasureIn(rep, QuirkProbeIsPaletteAccent,
                                                NSMakeRect(0, 0, edge, [rep pixelsHigh]));
    QuirkProbeInk end = QuirkProbeMeasureIn(rep, QuirkProbeIsPaletteAccent,
                                            NSMakeRect([rep pixelsWide] - edge, 0, edge, [rep pixelsHigh]));

    if (end.count >= (NSUInteger)(40 * scale * scale) && leading.count < (NSUInteger)(10 * scale * scale))
      {
        [self pass: @"switch-image-right" detail: [NSString stringWithFormat:
          @"the box is at the trailing edge of a %.0fpt switch (%lu accent px there, %lu at the start)",
          NSWidth([trailing bounds]), (unsigned long)end.count, (unsigned long)leading.count]];
      }
    else
      {
        [self fail: @"switch-image-right" detail: [NSString stringWithFormat:
          @"%lu accent px at the start of the switch, %lu at its end: the box is drawn first",
          (unsigned long)leading.count, (unsigned long)end.count]];
      }
  }

  /* The ring: accent from the indicator's edge to the dot, along its
     middle row. */
  rep = QuirkProbeRender(radio);
  scale = QuirkProbeScale(rep, radio);
  [self saveView: radio named: @"radio-dot-small"];
  accent = QuirkProbeMeasureIn(rep, QuirkProbeIsPaletteAccent, NSMakeRect(0, 0, 30 * scale, [rep pixelsHigh]));
  if (accent.count == 0)
    {
      [self fail: @"radio-ring-small" detail: @"no accent: the checked radio isn't drawn"];
    }
  else
    {
      NSInteger y = accent.minY + accent.height / 2;
      NSInteger x = accent.minX;
      NSInteger run = 0;
      NSUInteger red, green, blue;

      while (x < accent.minX + accent.width && QuirkProbePixel(rep, x, y, &red, &green, &blue)
             && QuirkProbeIsPaletteAccent(red, green, blue))
        {
          run++;
          x++;
        }
      if (run >= 2.5 * scale && run < accent.width / 2)
        {
          [self pass: @"radio-ring-small" detail: [NSString stringWithFormat:
            @"a %.0fpt radio keeps a %.1fpt accent ring round its dot",
            accent.width / scale, run / scale]];
        }
      else
        {
          [self fail: @"radio-ring-small" detail: [NSString stringWithFormat:
            @"a %.0fpt radio's accent ring is %.1fpt: it reads as unchecked",
            accent.width / scale, run / scale]];
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

  /* Pressed, the delete button sits on SubtleFillColorTertiary: a faint
     square around the cross, 9pt from its centre (the cross is 10pt). */
  {
    NSButtonCell *cancel = [[search cell] cancelButtonCell];
    NSRect button = [[search cell] cancelButtonRectForBounds: [search bounds]];
    CGFloat x = NSMidX(button) - 9.0;
    CGFloat y = [search isFlipped] ? NSMidY(button) : NSHeight([search bounds]) - NSMidY(button);
    NSInteger resting, pressed;

    resting = QuirkProbeBrightnessAt(rep, scale, x, y);
    [cancel setHighlighted: YES];
    [search display];
    rep = QuirkProbeRender(search);
    [self saveView: search named: @"search-delete-pressed"];
    pressed = QuirkProbeBrightnessAt(rep, scale, x, y);
    [cancel setHighlighted: NO];
    [search display];
    if (QuirkProbeHasArgument(@"--high-contrast", nil))
      {
        [self skip: @"search-delete-pressed" detail: @"high contrast draws no subtle fill"];
      }
    else if (llabs((long long)(pressed - resting)) >= 6)
      {
        [self pass: @"search-delete-pressed" detail: [NSString stringWithFormat:
          @"beside the cross: %ld at rest, %ld pressed (of 765)", (long)resting, (long)pressed]];
      }
    else
      {
        [self fail: @"search-delete-pressed" detail: [NSString stringWithFormat:
          @"beside the cross: %ld at rest, %ld pressed (of 765): no pressed fill",
          (long)resting, (long)pressed]];
      }
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

/* Windows' name for an extension's files, as the theme asks for it, or
   nil. */
static NSString *
QuirkProbeRegisteredTypeName(NSString *extension)
{
  typedef HRESULT (WINAPI *AssocQueryStringWFunc)(DWORD, int, LPCWSTR, LPCWSTR, LPWSTR, DWORD *);
  HMODULE module = LoadLibraryW(L"shlwapi.dll");
  AssocQueryStringWFunc function = (module != NULL)
    ? (AssocQueryStringWFunc)GetProcAddress(module, "AssocQueryStringW") : NULL;
  NSString *dotted = [@"." stringByAppendingString: extension];
  WCHAR association[64];
  WCHAR buffer[260];
  DWORD length = 260;
  HRESULT result;

  if (function == NULL || [dotted length] >= 64)
    {
      return nil;
    }
  [dotted getCharacters: (unichar *)association];
  association[[dotted length]] = 0;
  buffer[0] = 0;
  result = function(0, 3 /* ASSOCSTR_FRIENDLYDOCNAME */, association, NULL, buffer, &length);
  if (FAILED(result) || result == S_FALSE || buffer[0] == 0)
    {
      return nil;
    }
  buffer[259] = 0;
  return [[NSString stringWithCharacters: (const unichar *)buffer length: wcslen(buffer)]
           stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *
QuirkProbeFilterList(NSArray *filters)
{
  NSMutableArray *names = [NSMutableArray array];
  NSUInteger index;

  for (index = 0; index < [filters count]; index++)
    {
      [names addObject: [[filters objectAtIndex: index] objectForKey: @"name"]];
    }
  return [NSString stringWithFormat: @"[%@]", [names componentsJoinedByString: @" | "]];
}

static NSArray *
QuirkProbeFilterPatterns(NSArray *filters)
{
  NSMutableArray *patterns = [NSMutableArray array];
  NSUInteger index;

  for (index = 0; index < [filters count]; index++)
    {
      [patterns addObject: [[filters objectAtIndex: index] objectForKey: @"pattern"]];
    }
  return patterns;
}

/* The native Open and Save dialogs' type filters (#76). An Open panel that
   allows several types showed one type at a time, the first selected:
   ScreenshotTool's Open hid every file but PNGs. The dialogs are modal and
   Windows' own, so the probe asks the theme for the filters it gives them
   (+[WinUITheme fileDialogFilters:]); a theme without it fails. */
- (void) checkFileDialogFilters
{
  Class themeClass = NSClassFromString(@"WinUITheme");
  SEL selector = NSSelectorFromString(@"fileDialogFilters:");
  NSArray *ids = [NSArray arrayWithObjects: @"file-dialog-open-all-supported",
                          @"file-dialog-aliases-merged", @"file-dialog-type-names",
                          @"file-dialog-save-selects-name-type", @"file-dialog-other-types", nil];
  NSArray *images = [NSArray arrayWithObjects: @"png", @"jpg", @"jpeg", @"tif", @"tiff", nil];
  NSDictionary *reply;
  NSArray *filters;
  NSArray *patterns;
  NSArray *expected;
  NSString *pngName;
  NSString *expectedName;
  NSUInteger selected;
  NSUInteger index;

  if (themeClass == Nil || [themeClass respondsToSelector: selector] == NO)
    {
      for (index = 0; index < [ids count]; index++)
        {
          [self fail: [ids objectAtIndex: index] detail:
            @"the theme has no +fileDialogFilters: (before #76, an Open dialog showed one type at a time)"];
        }
      return;
    }

  /* Open, ScreenshotTool's image types: everything at once, selected. */
  reply = [themeClass performSelector: selector withObject:
    [NSDictionary dictionaryWithObjectsAndKeys: images, @"types", nil]];
  filters = [reply objectForKey: @"filters"];
  patterns = QuirkProbeFilterPatterns(filters);
  selected = [[reply objectForKey: @"selectedIndex"] unsignedIntegerValue];
  if ([filters count] > 0
      && [[patterns objectAtIndex: 0] isEqualToString: @"*.png;*.jpg;*.jpeg;*.tif;*.tiff"]
      && [[[filters objectAtIndex: 0] objectForKey: @"name"]
           hasSuffix: @" (*.png;*.jpg;*.jpeg;*.tif;*.tiff)"]
      && selected == 0)
    {
      [self pass: @"file-dialog-open-all-supported" detail:
        [NSString stringWithFormat: @"selected first of %@", QuirkProbeFilterList(filters)]];
    }
  else
    {
      [self fail: @"file-dialog-open-all-supported" detail:
        [NSString stringWithFormat: @"selected %lu of %@; want a first filter of every type, selected",
                                    (unsigned long)selected, QuirkProbeFilterList(filters)]];
    }

  /* jpg/jpeg and tif/tiff are one format each; htm/html share a name. */
  expected = [NSArray arrayWithObjects: @"*.png;*.jpg;*.jpeg;*.tif;*.tiff", @"*.png",
                      @"*.jpg;*.jpeg", @"*.tif;*.tiff", nil];
  {
    NSDictionary *web = [themeClass performSelector: selector withObject:
      [NSDictionary dictionaryWithObjectsAndKeys:
        [NSArray arrayWithObjects: @"html", @"htm", @"rtf", nil], @"types", nil]];
    NSArray *webPatterns = QuirkProbeFilterPatterns([web objectForKey: @"filters"]);
    NSArray *webExpected = [NSArray arrayWithObjects: @"*.html;*.htm;*.rtf",
                                    @"*.html;*.htm", @"*.rtf", nil];

    if ([patterns isEqualToArray: expected] && [webPatterns isEqualToArray: webExpected])
      {
        [self pass: @"file-dialog-aliases-merged" detail:
          [NSString stringWithFormat: @"%@; %@", [patterns componentsJoinedByString: @" | "],
                                      [webPatterns componentsJoinedByString: @" | "]]];
      }
    else
      {
        [self fail: @"file-dialog-aliases-merged" detail:
          [NSString stringWithFormat: @"patterns %@ and %@; want %@ and %@",
                                      [patterns componentsJoinedByString: @" | "],
                                      [webPatterns componentsJoinedByString: @" | "],
                                      [expected componentsJoinedByString: @" | "],
                                      [webExpected componentsJoinedByString: @" | "]]];
      }
  }

  /* Each type carries Windows' name for it, else "PNG files". */
  pngName = ([filters count] > 1) ? [[filters objectAtIndex: 1] objectForKey: @"name"] : nil;
  expectedName = QuirkProbeRegisteredTypeName(@"png");
  expectedName = [NSString stringWithFormat: @"%@ (*.png)",
                           expectedName != nil ? expectedName : @"PNG files"];
  if ([pngName isEqualToString: expectedName])
    {
      [self pass: @"file-dialog-type-names" detail: pngName];
    }
  else
    {
      [self fail: @"file-dialog-type-names" detail:
        [NSString stringWithFormat: @"the PNG filter is \"%@\"; want \"%@\"", pngName, expectedName]];
    }

  /* Save: one filter per type, the suggested name's selected. */
  {
    NSDictionary *named = [themeClass performSelector: selector withObject:
      [NSDictionary dictionaryWithObjectsAndKeys: images, @"types",
                    [NSNumber numberWithBool: YES], @"saving", @"photo.JPEG", @"fileName", nil]];
    NSDictionary *bare = [themeClass performSelector: selector withObject:
      [NSDictionary dictionaryWithObjectsAndKeys: images, @"types",
                    [NSNumber numberWithBool: YES], @"saving", @"Untitled", @"fileName", nil]];
    NSArray *savePatterns = QuirkProbeFilterPatterns([named objectForKey: @"filters"]);
    NSArray *saveExpected = [NSArray arrayWithObjects: @"*.png", @"*.jpg;*.jpeg",
                                     @"*.tif;*.tiff", nil];
    NSUInteger namedIndex = [[named objectForKey: @"selectedIndex"] unsignedIntegerValue];
    NSUInteger bareIndex = [[bare objectForKey: @"selectedIndex"] unsignedIntegerValue];

    if ([savePatterns isEqualToArray: saveExpected] && namedIndex == 1 && bareIndex == 0)
      {
        [self pass: @"file-dialog-save-selects-name-type" detail:
          [NSString stringWithFormat: @"%@; photo.JPEG selects %lu, Untitled %lu",
                                      [savePatterns componentsJoinedByString: @" | "],
                                      (unsigned long)namedIndex, (unsigned long)bareIndex]];
      }
    else
      {
        [self fail: @"file-dialog-save-selects-name-type" detail:
          [NSString stringWithFormat: @"%@; photo.JPEG selects %lu, Untitled %lu; want %@, 1 and 0",
                                      [savePatterns componentsJoinedByString: @" | "],
                                      (unsigned long)namedIndex, (unsigned long)bareIndex,
                                      [saveExpected componentsJoinedByString: @" | "]]];
      }
  }

  /* "All files" only when the panel allows other types; no types, no
     filters (every file shows). */
  {
    NSDictionary *other = [themeClass performSelector: selector withObject:
      [NSDictionary dictionaryWithObjectsAndKeys: [NSArray arrayWithObject: @"png"], @"types",
                    [NSNumber numberWithBool: YES], @"allowsOtherFileTypes", nil]];
    NSDictionary *none = [themeClass performSelector: selector withObject:
      [NSDictionary dictionary]];
    NSArray *otherPatterns = QuirkProbeFilterPatterns([other objectForKey: @"filters"]);

    if ([otherPatterns isEqualToArray: [NSArray arrayWithObjects: @"*.png", @"*.*", nil]]
        && [patterns containsObject: @"*.*"] == NO
        && [[none objectForKey: @"filters"] count] == 0)
      {
        [self pass: @"file-dialog-other-types" detail:
          [NSString stringWithFormat: @"%@; without types none",
                                      QuirkProbeFilterList([other objectForKey: @"filters"])]];
      }
    else
      {
        [self fail: @"file-dialog-other-types" detail:
          [NSString stringWithFormat: @"allowing other types %@, not %@, without types %lu filters",
                                      [otherPatterns componentsJoinedByString: @" | "],
                                      [patterns componentsJoinedByString: @" | "],
                                      (unsigned long)[[none objectForKey: @"filters"] count]]];
      }
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
  [self checkToolbarIconSize];
  [self checkScrollerEdge];
  [self checkTableHeader];
  [self checkTextAlignment];
  [self checkMultilineLabels];
  [self checkSwitches];
  [self checkStepper];
  [self checkDefaultButtons];
  [self checkAlertLayout];
  [self checkTemplateImages];
  [self checkEarlyTemplateImages];
  [self checkButtonChrome];
  [self checkSizeToFit];
  [self checkTypography];
  [self checkSlider];
  [self checkProgress];
  [self checkLevelIndicator];
  [self checkDatePicker];
  [self checkBrowser];
  [self checkBrowserTitles];
  [self checkColorWell];
  [self checkBoxes];
  [self checkContrastTheme];
  [self checkSegmentedControl];
  [self checkCellSizes];
  [self checkTabView];
  [self checkMetricsChoice];
  [self checkTableDefaults];
  [self checkLiveSettings];
  [self checkIndicators];
  [self checkMenuFlyout];
  [self checkOverlayScrollers];
  [self checkOverlayAutohide];
  [self checkFocusVisual];
  [self checkTextBox];
  [self checkComboBoxes];
  [self checkListSelection];
  [self checkSelectedRowText];
  [self checkToolTip];
  [self checkInspectorIndicators];
  [self checkSearchField];
  [self checkHorizontalOnlyScroller];
  [self checkWindowTabs];
  [self checkPopUpClick];
  [self checkFileDialogFilters];
  [self after: QuirkProbeSettleDelay perform: @selector(createLateWindow:)];
}

@end
