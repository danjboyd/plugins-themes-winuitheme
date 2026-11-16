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

#import "WinUIThemeNibWindows.h"
#import "../WinUITheme.h"
#import "../Settings/WinUIThemeMetrics.h"
#import "../Settings/WinUIThemeSettings.h"
#import <GNUstepGUI/GSTheme.h>
#import <objc/runtime.h>

/* GNUstep's NSFontSize, which nib and Gorm layouts were made at. */
static const CGFloat WinUIThemeNibFontSize = 12.0;

static char WinUIThemeCompactWindowKey;
static NSUInteger WinUIThemeCompactDrawingDepth = 0;
static IMP WinUIThemeWindowOwnAwakeFromNib = NULL;

static WinUITheme *
WinUIThemeNibActiveTheme(void)
{
  GSTheme *theme = [GSTheme theme];

  return [theme isKindOfClass: [WinUITheme class]] ? (WinUITheme *)theme : nil;
}

/* The controls a nib gave the system font (Interface Builder's "system",
   resolved at load to the theme's interface font) get it at GNUstep's
   size, scaled by the user's text size. Controls given another size keep
   it. */
static void
WinUIThemeCompactControlFonts(NSView *view, CGFloat interfaceSize, CGFloat compactSize)
{
  NSEnumerator *enumerator = nil;
  NSView *subview = nil;

  if ([view isKindOfClass: [NSControl class]])
    {
      NSFont *font = [(NSControl *)view font];

      if (font != nil && fabs([font pointSize] - interfaceSize) < 0.01)
        {
          NSFont *compact = [NSFont fontWithName: [font fontName] size: compactSize];

          if (compact != nil)
            {
              [(NSControl *)view setFont: compact];
            }
        }
    }
  enumerator = [[view subviews] objectEnumerator];
  while ((subview = [enumerator nextObject]) != nil)
    {
      WinUIThemeCompactControlFonts(subview, interfaceSize, compactSize);
    }
}

static void
WinUIThemeWindowAwakeFromNib(id self, SEL _cmd)
{
  WinUITheme *theme = WinUIThemeNibActiveTheme();
  IMP next = WinUIThemeWindowOwnAwakeFromNib;

  if (theme != nil && [[theme metrics] compact] == NO)
    {
      WinUIThemeSettings *settings = [theme settings];
      CGFloat scale = [settings textScaleFactor];
      CGFloat compactSize = round(WinUIThemeNibFontSize * (scale > 0.0 ? scale : 1.0));

      objc_setAssociatedObject(self, &WinUIThemeCompactWindowKey,
                               [NSNumber numberWithBool: YES],
                               OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      WinUIThemeCompactControlFonts([(NSWindow *)self contentView],
                                    [settings interfaceFontSize], compactSize);
    }

  if (next == NULL)
    {
      next = class_getMethodImplementation(class_getSuperclass([NSWindow class]), _cmd);
    }
  if (next != NULL)
    {
      ((void (*)(id, SEL))next)(self, _cmd);
    }
}

void
WinUIThemeNibWindowsInstall(void)
{
  static BOOL installed = NO;
  SEL selector = @selector(awakeFromNib);
  unsigned int count = 0;
  unsigned int i;
  Method *methods = NULL;

  if (installed)
    {
      return;
    }
  installed = YES;

  /* NSWindow inherits NSObject's -awakeFromNib in libs-gui; add one, or
     wrap its own if a later libs-gui has one. */
  methods = class_copyMethodList([NSWindow class], &count);
  for (i = 0; i < count; i++)
    {
      if (sel_isEqual(method_getName(methods[i]), selector))
        {
          WinUIThemeWindowOwnAwakeFromNib = method_setImplementation(methods[i],
                                                                      (IMP)WinUIThemeWindowAwakeFromNib);
          break;
        }
    }
  free(methods);
  if (WinUIThemeWindowOwnAwakeFromNib == NULL)
    {
      class_addMethod([NSWindow class], selector, (IMP)WinUIThemeWindowAwakeFromNib, "v@:");
    }
}

BOOL
WinUIThemeWindowUsesCompactMetrics(NSWindow *window)
{
  return window != nil
    && objc_getAssociatedObject(window, &WinUIThemeCompactWindowKey) != nil;
}

BOOL
WinUIThemeCompactMetricsInEffect(WinUITheme *theme)
{
  if (theme == nil)
    {
      return NO;
    }
  return [[theme metrics] compact] || WinUIThemeCompactDrawingDepth > 0;
}

void
WinUIThemeBeginDrawingInView(NSView *view)
{
  if (WinUIThemeCompactDrawingDepth > 0 || WinUIThemeWindowUsesCompactMetrics([view window]))
    {
      WinUIThemeCompactDrawingDepth++;
    }
}

void
WinUIThemeEndDrawingInView(NSView *view)
{
  (void)view;
  if (WinUIThemeCompactDrawingDepth > 0)
    {
      WinUIThemeCompactDrawingDepth--;
    }
}
