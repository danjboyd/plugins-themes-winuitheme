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

#import "WinUIThemeDrawing.h"
#import "../Native/WinUIThemeWindowIntegration.h"
#import "../Settings/WinUIThemeSettings.h"

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>

/* Popover panels as WinUI flyouts (ScreenshotTool #67, #164). GNUstep's
   NSPopover can't become key and draws a fixed panel (libs-gui#988), so
   apps show their popovers in a borderless panel of their own. A panel
   whose class adopts the empty protocol GSThemePopoverPanel asks the theme
   to draw it; the theme says it does with GSThemeDrawsPopoverPanels in its
   Info-gnustep.plist, and the app then leaves the panel's background to
   it. Only marked panels: other borderless windows (lists, drag images,
   notices) keep their own look.

   The flyout is the MenuFlyout's: its layer fill and 1px stroke, 8px
   corners and the shadow from DWM (as the menus, #39), no arrow. On
   Windows it is owned by the main window and kept out of the taskbar and
   Alt+Tab (#30), and it can still become key. */

BOOL
WinUIThemeWindowIsFlyout(NSWindow *window)
{
  /* libobjc2 registers a protocol once something adopts it: apps that
     don't have none to find. */
  Protocol *mark = NSProtocolFromString(@"GSThemePopoverPanel");

  return (window != nil && mark != nil && [window conformsToProtocol: mark]);
}

/* A combo box's list (libs-gui's GSComboWindow). */
static BOOL
WinUIThemeWindowIsComboList(NSWindow *window)
{
  static Class comboWindowClass = Nil;

  if (comboWindowClass == Nil)
    {
      comboWindowClass = NSClassFromString(@"GSComboWindow");
    }
  return comboWindowClass != Nil && [window isKindOfClass: comboWindowClass];
}

@implementation WinUITheme (Flyouts)

/* The list's text 12px in, past the selected item's accent pill, as
   WinUI's ComboBoxItem pads it. */
- (NSRect) _overrideGSComboBoxTableViewMethod_frameOfCellAtColumn: (NSInteger)column
                                                              row: (NSInteger)row
{
  typedef NSRect (*FrameIMP)(id, SEL, NSInteger, NSInteger);
  FrameIMP originalIMP = (FrameIMP)WinUIThemeOriginalMethod(_cmd, self, [NSTableView class]);
  NSRect frame = (originalIMP != NULL) ? originalIMP(self, _cmd, column, row) : NSZeroRect;
  GSTheme *current = [GSTheme theme];

  if ([current isKindOfClass: [WinUITheme class]])
    {
      CGFloat inset = round(12.0 * MAX(1.0, [[(WinUITheme *)current settings] desktopScaleFactor]));

      frame.origin.x += inset;
      frame.size.width = MAX(0.0, NSWidth(frame) - 2.0 * inset);
    }
  return frame;
}

/* A combo box's list as WinUI's ComboBox drop-down (#105): a flyout (the
   menu's fill and 1px stroke, 8px corners and a shadow from DWM) as wide
   as the combo box, with 32px rows 4px in from its ends, where libs-gui
   has a box with a line border round a table of its own row height, as
   wide as the text. It keeps the side of the field libs-gui put it on. */
- (void) _overrideGSComboWindowMethod_positionWithComboBoxCell: (NSComboBoxCell *)comboBoxCell
{
  typedef void (*PositionIMP)(id, SEL, NSComboBoxCell *);
  PositionIMP originalIMP = (PositionIMP)WinUIThemeOriginalMethod(_cmd, self,
                                                                  NSClassFromString(@"GSComboWindow"));
  NSWindow *window = (NSWindow *)self;
  GSTheme *current = [GSTheme theme];
  WinUITheme *theme = [current isKindOfClass: [WinUITheme class]] ? (WinUITheme *)current : nil;
  NSView *control = [comboBoxCell controlView];
  NSBox *box = nil;
  NSScrollView *scrollView = nil;
  NSTableView *table = nil;
  NSRect frame, field;
  CGFloat scale, rowHeight, inset, height;
  NSInteger rows;
  BOOL below;

  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, comboBoxCell);
    }
  box = [window contentView];
  if (theme == nil || control == nil || [box isKindOfClass: [NSBox class]] == NO
      || [[box contentView] isKindOfClass: [NSScrollView class]] == NO)
    {
      return;
    }
  scrollView = (NSScrollView *)[box contentView];
  table = [scrollView documentView];
  scale = MAX(1.0, [[theme settings] desktopScaleFactor]);
  rowHeight = round(32.0 * scale);
  inset = round(4.0 * scale);
  rows = MAX(1, MIN([comboBoxCell numberOfItems], [comboBoxCell numberOfVisibleItems]));

  [box setBorderType: NSNoBorder];
  [box setContentViewMargins: NSMakeSize(1.0, inset)];
  [scrollView setBorderType: NSNoBorder];
  [scrollView setDrawsBackground: NO];
  if ([table isKindOfClass: [NSTableView class]])
    {
      NSCell *cell = [[[table tableColumns] lastObject] dataCell];

      [table setBackgroundColor: WinUIThemeColorFromTheme(theme, @"menuBackgroundColor",
                                                          [NSColor controlBackgroundColor])];
      [table setRowHeight: rowHeight];
      [table setIntercellSpacing: NSZeroSize];
      if ([[theme settings] interfaceFont] != nil)
        {
          [cell setFont: [[theme settings] interfaceFont]];
        }
    }

  /* As wide as the combo box, from its leading edge, on the side of the
     field libs-gui chose. The frame is in device pixels and the rows in
     points: on a scaled display the list is that many points tall times
     the main screen's factor, or its last row fell off. */
  frame = [window frame];
  field = [control convertRect: [control bounds] toView: nil];
  field.origin = [[control window] convertBaseToScreen: field.origin];
  below = (NSMaxY(frame) <= NSMidY(field));
  height = (rows * rowHeight + 2.0 * inset + 2.0)
    * MAX(1.0, [[NSScreen mainScreen] userSpaceScaleFactor]);
  frame = NSMakeRect(NSMinX(field),
                     below ? NSMinY(field) - 1.0 - height : NSMaxY(field) + 1.0,
                     NSWidth(field), height);
  [window setFrame: frame display: NO];
}


- (void) drawWindowBackground: (NSRect)frame view: (NSView *)view
{
  NSWindow *window = [view window];
  NSColor *fill = nil;
  NSColor *border = nil;
  NSBezierPath *path = nil;

  if (WinUIThemeWindowShowsMica(window))
    {
      /* Mica (#47) shows through the title bar, menu bar and toolbar,
         which leave their background transparent; the window's content
         has its background, under the lowest of them. */
      NSArray *subviews = [view subviews];
      CGFloat chromeBottom = NSMaxY(frame);
      BOOL grew = YES;

      /* The chrome stacks down from the top, each piece meeting the one
         above it. */
      while (grew)
        {
          NSEnumerator *enumerator = [subviews objectEnumerator];
          NSView *subview;

          grew = NO;
          while ((subview = [enumerator nextObject]) != nil)
            {
              NSRect piece = [subview frame];

              if (subview != [window contentView] && [subview isHidden] == NO
                  && NSMaxY(piece) >= chromeBottom - 1.0 && NSMinY(piece) < chromeBottom)
                {
                  chromeBottom = NSMinY(piece);
                  grew = YES;
                }
            }
        }
      [[window backgroundColor] set];
      NSRectFill(NSMakeRect(NSMinX(frame), NSMinY(frame), NSWidth(frame),
                            MAX(0.0, chromeBottom - NSMinY(frame))));
      return;
    }
  if (WinUIThemeWindowIsFlyout(window) == NO && WinUIThemeWindowIsComboList(window) == NO)
    {
      [super drawWindowBackground: frame view: view];
      return;
    }

  fill = WinUIThemeColorFromTheme(self, @"menuBackgroundColor", [NSColor controlBackgroundColor]);
  border = WinUIThemeColorFromTheme(self, @"menuBorderColor", [NSColor controlShadowColor]);
  WinUIThemeWindowIntegrationMakeFlyout(window, border);

  /* The whole window: DWM rounds it, as it does the menus' windows. */
  [fill set];
  NSRectFill(frame);
  path = [NSBezierPath bezierPathWithRect: NSInsetRect(NSIntegralRect(frame), 0.5, 0.5)];
  [path setLineWidth: 1.0];
  [border set];
  [path stroke];
}

@end
