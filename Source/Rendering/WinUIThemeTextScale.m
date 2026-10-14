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
#import "../Settings/WinUIThemeSettings.h"
#import "../Settings/WinUIThemeMetrics.h"

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>

/* Windows' text size reaching windows that are already open (#105). The
   theme's fonts and metrics follow the text size, but libs-gui's cells
   keep the font they were made with, so after a change only controls made
   afterwards had the new size. WinUI relayouts every window. Here each
   font a control, cell, table, box, tab view or plain text view has at
   one of the theme's sizes, in one of its families, moves to the
   matching new size, keeping its face; a table at the theme's row height
   takes the new one, and menus resize. A size the app chose itself, or a
   font of its own, stays. Frames stay as the app laid them out. */

@interface WinUIThemeTextScaleSnapshot : NSObject
{
@public
  NSArray *sizes;
  NSSet *families;
  CGFloat rowHeight;
}
@end

@implementation WinUIThemeTextScaleSnapshot

- (void) dealloc
{
  RELEASE(sizes);
  RELEASE(families);
  [super dealloc];
}

@end

/* The theme's font sizes, in a fixed order: the interface font, small and
   mini (as -runtimeDefaultsDictionary sets them), Caption (tool tips),
   the menu font, the menu bar's, and the fixed-pitch font. */
static NSArray *
WinUIThemeTextSizes(WinUITheme *theme)
{
  WinUIThemeSettings *settings = [theme settings];
  CGFloat base = [settings interfaceFontSize];

  return [NSArray arrayWithObjects:
                    [NSNumber numberWithDouble: base],
                    [NSNumber numberWithDouble: MAX(9.0, base - 2.0)],
                    [NSNumber numberWithDouble: MAX(8.0, base - 3.0)],
                    [NSNumber numberWithDouble: round(12.0 * [settings textScaleFactor])],
                    [NSNumber numberWithDouble: [[settings menuFont] pointSize]],
                    [NSNumber numberWithDouble: [[settings menuBarFont] pointSize]],
                    [NSNumber numberWithDouble: [[settings fixedPitchFont] pointSize]],
                    nil];
}

static NSSet *
WinUIThemeTextFamilies(WinUITheme *theme)
{
  NSMutableSet *families = [NSMutableSet set];
  NSString *family = [[[theme settings] interfaceFont] familyName];

  if (family != nil)
    {
      [families addObject: family];
    }
  family = [[[theme settings] fixedPitchFont] familyName];
  if (family != nil)
    {
      [families addObject: family];
    }
  return families;
}

id
WinUIThemeTextScaleSnapshotTake(WinUITheme *theme)
{
  WinUIThemeTextScaleSnapshot *snapshot = AUTORELEASE([WinUIThemeTextScaleSnapshot new]);

  snapshot->sizes = RETAIN(WinUIThemeTextSizes(theme));
  snapshot->families = RETAIN(WinUIThemeTextFamilies(theme));
  snapshot->rowHeight = [[theme metrics] tableRowHeight];
  return snapshot;
}

/* What the walk needs: the old sizes to the new, the families, and the
   row heights. */
typedef struct
{
  NSMapTable *sizes;
  NSSet *families;
  CGFloat oldRowHeight;
  CGFloat newRowHeight;
} WinUIThemeTextScaleChange;

/* `font` at its new size, or nil when it isn't one of the theme's. */
static NSFont *
WinUIThemeRescaledFont(NSFont *font, WinUIThemeTextScaleChange *change)
{
  NSNumber *size = nil;

  if (font == nil || [change->families containsObject: [font familyName]] == NO)
    {
      return nil;
    }
  size = NSMapGet(change->sizes, (void *)(intptr_t)lround([font pointSize] * 100.0));
  if (size == nil)
    {
      return nil;
    }
  return [NSFont fontWithName: [font fontName] size: [size doubleValue]];
}

static BOOL
WinUIThemeRescaleCell(NSCell *cell, WinUIThemeTextScaleChange *change)
{
  NSFont *font = nil;

  if ([cell isKindOfClass: [NSCell class]] == NO)
    {
      return NO;
    }
  font = WinUIThemeRescaledFont([cell font], change);
  if (font == nil)
    {
      return NO;
    }
  [cell setFont: font];
  return YES;
}

static void
WinUIThemeRescaleView(NSView *view, WinUIThemeTextScaleChange *change)
{
  NSEnumerator *enumerator = nil;
  NSView *subview = nil;
  BOOL changed = NO;

  if ([view isKindOfClass: [NSTableView class]])
    {
      NSTableView *table = (NSTableView *)view;
      NSEnumerator *columns = [[table tableColumns] objectEnumerator];
      NSTableColumn *column = nil;

      while ((column = [columns nextObject]) != nil)
        {
          changed |= WinUIThemeRescaleCell([column dataCell], change);
          changed |= WinUIThemeRescaleCell([column headerCell], change);
        }
      if (change->oldRowHeight > 0.0 && fabs([table rowHeight] - change->oldRowHeight) < 0.5
          && change->newRowHeight > 0.0)
        {
          [table setRowHeight: change->newRowHeight];
          changed = YES;
        }
      if (changed)
        {
          [table tile];
          [[table headerView] setNeedsDisplay: YES];
        }
    }
  else if ([view isKindOfClass: [NSMatrix class]])
    {
      NSEnumerator *cells = [[(NSMatrix *)view cells] objectEnumerator];
      NSCell *cell = nil;

      while ((cell = [cells nextObject]) != nil)
        {
          changed |= WinUIThemeRescaleCell(cell, change);
        }
    }
  else if ([view isKindOfClass: [NSControl class]])
    {
      changed = WinUIThemeRescaleCell([(NSControl *)view cell], change);
    }
  else if ([view isKindOfClass: [NSBox class]])
    {
      NSFont *font = WinUIThemeRescaledFont([(NSBox *)view titleFont], change);

      if (font != nil)
        {
          [(NSBox *)view setTitleFont: font];
          changed = YES;
        }
    }
  else if ([view isKindOfClass: [NSTabView class]])
    {
      NSFont *font = WinUIThemeRescaledFont([(NSTabView *)view font], change);

      if (font != nil)
        {
          [(NSTabView *)view setFont: font];
          changed = YES;
        }
    }
  else if ([view isKindOfClass: [NSTextView class]] && [(NSTextView *)view isRichText] == NO)
    {
      NSTextView *textView = (NSTextView *)view;
      NSFont *font = WinUIThemeRescaledFont([textView font], change);

      /* Not a field editor: it takes the font of the field it edits. */
      if (font != nil && [textView isFieldEditor] == NO)
        {
          [textView setFont: font];
          changed = YES;
        }
    }
  if (changed)
    {
      [view setNeedsDisplay: YES];
    }

  enumerator = [[view subviews] objectEnumerator];
  while ((subview = [enumerator nextObject]) != nil)
    {
      WinUIThemeRescaleView(subview, change);
    }
}

static void
WinUIThemeRescaleMenu(NSMenu *menu, WinUIThemeTextScaleChange *change)
{
  NSEnumerator *enumerator = nil;
  NSMenuItem *item = nil;
  NSMenuView *menuView = nil;

  if (menu == nil)
    {
      return;
    }
  menuView = (NSMenuView *)[menu menuRepresentation];
  if ([menuView isKindOfClass: [NSMenuView class]])
    {
      NSFont *font = WinUIThemeRescaledFont([menuView font], change);

      if (font != nil)
        {
          [menuView setFont: font];
        }
      [menuView setNeedsSizing: YES];
      [menuView setNeedsDisplay: YES];
    }
  enumerator = [[menu itemArray] objectEnumerator];
  while ((item = [enumerator nextObject]) != nil)
    {
      if ([item hasSubmenu])
        {
          WinUIThemeRescaleMenu([item submenu], change);
        }
    }
}

/* After a reload: when the theme's sizes changed since `snapshot`, every
   open window's fonts move to the new ones. Returns YES when they did. */
BOOL
WinUIThemeTextScaleApply(WinUITheme *theme, id snapshotObject)
{
  WinUIThemeTextScaleSnapshot *snapshot = (WinUIThemeTextScaleSnapshot *)snapshotObject;
  NSArray *newSizes = WinUIThemeTextSizes(theme);
  NSMutableSet *families = nil;
  WinUIThemeTextScaleChange change;
  NSEnumerator *windows = nil;
  NSWindow *window = nil;
  NSUInteger i;
  BOOL any = NO;

  if (snapshot == nil || [snapshot->sizes count] != [newSizes count])
    {
      return NO;
    }
  change.sizes = NSCreateMapTable(NSIntegerMapKeyCallBacks, NSObjectMapValueCallBacks, 8);
  for (i = 0; i < [newSizes count]; i++)
    {
      double before = [[snapshot->sizes objectAtIndex: i] doubleValue];
      double after = [[newSizes objectAtIndex: i] doubleValue];
      void *key = (void *)(intptr_t)lround(before * 100.0);

      /* The first role at a size decides it. */
      if (before > 0.0 && after > 0.0 && NSMapGet(change.sizes, key) == nil)
        {
          NSMapInsert(change.sizes, key, [newSizes objectAtIndex: i]);
          any |= (fabs(before - after) > 0.01);
        }
    }
  if (any == NO)
    {
      NSFreeMapTable(change.sizes);
      return NO;
    }
  families = [NSMutableSet setWithSet: snapshot->families];
  [families unionSet: WinUIThemeTextFamilies(theme)];
  change.families = families;
  change.oldRowHeight = snapshot->rowHeight;
  change.newRowHeight = [[theme metrics] tableRowHeight];

  windows = [[NSApp windows] objectEnumerator];
  while ((window = [windows nextObject]) != nil)
    {
      NSView *frameView = [[window contentView] superview];

      WinUIThemeRescaleView(frameView != nil ? frameView : [window contentView], &change);
      [window setViewsNeedDisplay: YES];
    }
  WinUIThemeRescaleMenu([NSApp mainMenu], &change);
  NSFreeMapTable(change.sizes);
  return YES;
}
