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

#import "WinUIThemeCaption.h"
#import "WinUIThemeWindowIntegration.h"
#import "../WinUITheme.h"
#import "../Rendering/WinUIThemeDrawing.h"
#import "../Settings/WinUIThemeSettings.h"

#import <GNUstepGUI/GSDisplayServer.h>
#import <GNUstepGUI/GSWindowDecorationView.h>

#include <windows.h>

/* What danjboyd/libs-back's WIN32Server adds (win32-client-caption); asked
   for with -respondsToSelector:, so a stock backend keeps Windows' caption. */
@interface GSDisplayServer (WinUIThemeClientCaption)
- (BOOL) clientDrawsCaptions;
- (void) setCaptionRegionRects: (const NSRect *)rects
                         kinds: (const int *)kinds
                         count: (unsigned)count
                     forWindow: (int)win;
@end

/* GSCaptionRegionKind */
enum
{
  WinUIThemeCaptionRegionDrag = 1,
  WinUIThemeCaptionRegionMinimize = 2,
  WinUIThemeCaptionRegionZoom = 3,
  WinUIThemeCaptionRegionClose = 4
};

typedef enum
{
  WinUIThemeCaptionMinimize,
  WinUIThemeCaptionZoom,
  WinUIThemeCaptionClose
} WinUIThemeCaptionButtonKind;

static WinUITheme *
WinUIThemeCaptionTheme(void)
{
  GSTheme *theme = [GSTheme theme];

  return [theme isKindOfClass: [WinUITheme class]] ? (WinUITheme *)theme : nil;
}

static CGFloat
WinUIThemeCaptionDensity(void)
{
  CGFloat scale = [[WinUIThemeCaptionTheme() settings] desktopScaleFactor];

  return (scale > 0.0) ? scale : 1.0;
}

static BOOL
WinUIThemeCaptionHighContrast(void)
{
  return [[WinUIThemeCaptionTheme() settings] highContrastEnabled];
}

static BOOL
WinUIThemeCaptionDark(void)
{
  WinUIThemeSettings *settings = [WinUIThemeCaptionTheme() settings];

  return [settings highContrastEnabled] == NO && [settings prefersDarkAppearance];
}

static NSColor *
WinUIThemeCaptionContrast(NSString *name, NSColor *fallback)
{
  NSColor *color = [[WinUIThemeCaptionTheme() settings] contrastColor: name];

  return (color != nil) ? color : fallback;
}

static NSColor *
WinUIThemeCaptionBackground(void)
{
  NSColor *window = WinUIThemeColorFromTheme(WinUIThemeCaptionTheme(), @"windowBackgroundColor",
                                             [NSColor windowBackgroundColor]);

  if (WinUIThemeCaptionHighContrast())
    {
      return WinUIThemeCaptionContrast(@"Window", window);
    }
  return window;
}

/* TextFillColorPrimary, and TextFillColorDisabled for an inactive window
   (as Windows' own caption dims). */
static NSColor *
WinUIThemeCaptionTextColor(BOOL active)
{
  NSColor *text = WinUIThemeColorFromTheme(WinUIThemeCaptionTheme(), @"labelColor",
                                           [NSColor controlTextColor]);

  if (WinUIThemeCaptionHighContrast())
    {
      return active ? WinUIThemeCaptionContrast(@"WindowText", text)
                    : WinUIThemeCaptionContrast(@"GrayText", text);
    }
  if (active)
    {
      return text;
    }
  return WinUIThemeBlendColor(WinUIThemeCaptionBackground(), text, 0.36);
}

BOOL
WinUIThemeDrawsCaptionForStyle(NSUInteger style)
{
  static int clientDrawsCaptions = -1;

  if ((style & (NSTitledWindowMask | NSClosableWindowMask)) == 0)
    {
      return NO;
    }
  if (clientDrawsCaptions < 0)
    {
      GSDisplayServer *server = GSCurrentServer();

      if (server == nil)
        {
          return NO;
        }
      clientDrawsCaptions = [server respondsToSelector: @selector(clientDrawsCaptions)]
        && [server respondsToSelector:
             @selector(setCaptionRegionRects:kinds:count:forWindow:)]
        && [server handlesWindowDecorations]
        && [server clientDrawsCaptions];
    }
  return clientDrawsCaptions;
}

CGFloat
WinUIThemeCaptionHeight(void)
{
  /* The height of Windows' caption buttons, which WinUI's title bar keeps
     (TitleBar's standard height without a search box or tabs). */
  return round(32.0 * WinUIThemeCaptionDensity());
}

static HWND
WinUIThemeCaptionWindowHandle(NSWindow *window)
{
  if (window == nil || [window respondsToSelector: @selector(windowHandle)] == NO)
    {
      return NULL;
    }
  return (HWND)[window windowHandle];
}

/* A maximized window's top lies off the screen by its frame's depth (the
   backend starts the client area below it, so the gui's top rows are out of
   sight): the caption's visible part is that much shorter. */
static CGFloat
WinUIThemeCaptionHiddenTop(NSWindow *window)
{
  HWND hwnd = WinUIThemeCaptionWindowHandle(window);
  RECT windowRect;
  POINT origin = {0, 0};

  if (hwnd == NULL || IsZoomed(hwnd) == FALSE)
    {
      return 0.0;
    }
  GetWindowRect(hwnd, &windowRect);
  ClientToScreen(hwnd, &origin);
  return MAX(0, origin.y - windowRect.top);
}

/* Key or main, or Windows' active window (a modal panel GNUstep hasn't
   made key yet: Windows' own caption is drawn active then). */
static BOOL
WinUIThemeCaptionWindowIsActive(NSWindow *window)
{
  HWND hwnd = WinUIThemeCaptionWindowHandle(window);

  return [window isKeyWindow] || [window isMainWindow]
    || (hwnd != NULL && GetActiveWindow() == hwnd);
}

/* Windows gives a window caption buttons (and an icon) only with a system
   menu, which the backend gives a closable window. */
static BOOL
WinUIThemeCaptionHasSystemMenu(NSWindow *window)
{
  return ([window styleMask] & NSClosableWindowMask) != 0;
}

@interface WinUIThemeCaptionButton : NSView
{
  WinUIThemeCaptionButtonKind _kind;
  BOOL _pressed;
}
- (id) initWithKind: (WinUIThemeCaptionButtonKind)kind;
- (WinUIThemeCaptionButtonKind) kind;
@end

@interface WinUIThemeCaptionView : NSView
{
  WinUIThemeCaptionButton *_minimize;
  WinUIThemeCaptionButton *_zoom;
  WinUIThemeCaptionButton *_close;
}
- (void) layoutButtons;
- (void) declareRegions: (int)windowNumber;
@end

@implementation WinUIThemeCaptionButton

- (id) initWithKind: (WinUIThemeCaptionButtonKind)kind
{
  self = [super initWithFrame: NSZeroRect];
  if (self != nil)
    {
      _kind = kind;
    }
  return self;
}

- (WinUIThemeCaptionButtonKind) kind
{
  return _kind;
}

- (BOOL) acceptsFirstMouse: (NSEvent *)event
{
  return YES;
}

- (BOOL) isEnabled
{
  NSUInteger style = [[self window] styleMask];

  switch (_kind)
    {
      case WinUIThemeCaptionMinimize:
        return (style & NSMiniaturizableWindowMask) != 0;
      case WinUIThemeCaptionZoom:
        return (style & NSResizableWindowMask) != 0;
      case WinUIThemeCaptionClose:
        return (style & NSClosableWindowMask) != 0;
    }
  return NO;
}

/* Through the window's system menu, as Windows' own caption buttons:
   minimizing and maximizing are Windows' (Snap and the restore size). */
- (void) perform
{
  HWND hwnd = WinUIThemeCaptionWindowHandle([self window]);
  WPARAM command;

  if (hwnd == NULL)
    {
      return;
    }
  switch (_kind)
    {
      case WinUIThemeCaptionMinimize:
        command = SC_MINIMIZE;
        break;
      case WinUIThemeCaptionZoom:
        command = IsZoomed(hwnd) ? SC_RESTORE : SC_MAXIMIZE;
        break;
      default:
        command = SC_CLOSE;
        break;
    }
  PostMessageW(hwnd, WM_SYSCOMMAND, command, 0);
}

- (void) mouseDown: (NSEvent *)event
{
  NSEvent *current = event;
  BOOL inside = YES;

  if ([self isEnabled] == NO)
    {
      return;
    }
  _pressed = YES;
  [self setNeedsDisplay: YES];
  while ([current type] != NSLeftMouseUp)
    {
      current = [NSApp nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask
                                   untilDate: [NSDate distantFuture]
                                      inMode: NSEventTrackingRunLoopMode
                                     dequeue: YES];
      inside = NSMouseInRect([self convertPoint: [current locationInWindow] fromView: nil],
                             [self bounds], [self isFlipped]);
      if (inside != _pressed)
        {
          _pressed = inside;
          [self setNeedsDisplay: YES];
        }
    }
  _pressed = NO;
  WinUIThemeSetViewHovered(self, inside);
  [self setNeedsDisplay: YES];
  if (inside)
    {
      [self perform];
    }
}

/* Segoe Fluent Icons' caption glyphs (ChromeMinimize, ChromeMaximize,
   ChromeRestore, ChromeClose) drawn as 10px outlines with 1px lines. */
- (void) drawGlyphInRect: (NSRect)rect color: (NSColor *)color
{
  CGFloat density = WinUIThemeCaptionDensity();
  CGFloat size = round(10.0 * density);
  CGFloat line = MAX(1.0, round(density));
  NSRect glyph = NSMakeRect(floor(NSMidX(rect) - size / 2.0),
                            floor(NSMidY(rect) - size / 2.0), size, size);
  NSBezierPath *path = [NSBezierPath bezierPath];
  CGFloat inset = line / 2.0;

  [color set];
  [path setLineWidth: line];
  switch (_kind)
    {
      case WinUIThemeCaptionMinimize:
        [path moveToPoint: NSMakePoint(NSMinX(glyph), floor(NSMidY(glyph)) + inset)];
        [path lineToPoint: NSMakePoint(NSMaxX(glyph), floor(NSMidY(glyph)) + inset)];
        break;
      case WinUIThemeCaptionZoom:
        if (IsZoomed(WinUIThemeCaptionWindowHandle([self window])))
          {
            CGFloat step = round(2.0 * density);
            NSRect front = NSMakeRect(NSMinX(glyph), NSMinY(glyph),
                                      size - step, size - step);

            [path appendBezierPath:
              WinUIThemeRoundedPath(NSInsetRect(front, inset, inset), 1.0 * density)];
            [path moveToPoint: NSMakePoint(NSMinX(glyph) + step + inset, NSMaxY(front) + inset)];
            [path lineToPoint: NSMakePoint(NSMinX(glyph) + step + inset, NSMaxY(glyph) - inset)];
            [path lineToPoint: NSMakePoint(NSMaxX(glyph) - inset, NSMaxY(glyph) - inset)];
            [path lineToPoint: NSMakePoint(NSMaxX(glyph) - inset, NSMinY(glyph) + step + inset)];
            [path lineToPoint: NSMakePoint(NSMaxX(front) + inset, NSMinY(glyph) + step + inset)];
          }
        else
          {
            [path appendBezierPath:
              WinUIThemeRoundedPath(NSInsetRect(glyph, inset, inset), 1.0 * density)];
          }
        break;
      case WinUIThemeCaptionClose:
        [path moveToPoint: NSMakePoint(NSMinX(glyph), NSMinY(glyph))];
        [path lineToPoint: NSMakePoint(NSMaxX(glyph), NSMaxY(glyph))];
        [path moveToPoint: NSMakePoint(NSMinX(glyph), NSMaxY(glyph))];
        [path lineToPoint: NSMakePoint(NSMaxX(glyph), NSMinY(glyph))];
        break;
    }
  [path stroke];
}

- (void) drawRect: (NSRect)dirtyRect
{
  NSWindow *window = [self window];
  BOOL active = WinUIThemeCaptionWindowIsActive(window);
  BOOL enabled = [self isEnabled];
  CGFloat hovered;
  NSColor *fill = nil;
  NSColor *glyph = WinUIThemeCaptionTextColor(active);

  /* The pointer-over fill fades in and out (#105). */
  WinUIThemeTrackHover(self);
  hovered = WinUIThemeHoverAmount(self, enabled && WinUIThemeViewIsHovered(self));
  if (WinUIThemeCaptionHighContrast())
    {
      if (_pressed || hovered >= 0.5)
        {
          fill = WinUIThemeCaptionContrast(@"Hilight", glyph);
          glyph = WinUIThemeCaptionContrast(@"HilightText", WinUIThemeCaptionBackground());
        }
    }
  else if (_kind == WinUIThemeCaptionClose && (_pressed || hovered > 0.0))
    {
      /* CloseButtonBackgroundPointerOver (#C42B1C), at 90% pressed */
      NSColor *red = [NSColor colorWithCalibratedRed: 196.0 / 255.0 green: 43.0 / 255.0
                                                blue: 28.0 / 255.0 alpha: 1.0];

      fill = WinUIThemeWindowShowsMica(window)
        ? [red colorWithAlphaComponent: _pressed ? 0.9 : hovered]
        : WinUIThemeBlendColor(WinUIThemeCaptionBackground(), red, _pressed ? 0.9 : hovered);
      glyph = _pressed ? [NSColor colorWithCalibratedWhite: 1.0 alpha: 0.7]
                       : WinUIThemeBlendColor(glyph, [NSColor whiteColor], hovered);
    }
  else if (_pressed || hovered > 0.0)
    {
      /* SubtleFillColorSecondary under the pointer, Tertiary pressed */
      BOOL dark = WinUIThemeCaptionDark();
      NSColor *ink = dark ? [NSColor whiteColor] : [NSColor blackColor];

      CGFloat amount = _pressed ? (dark ? 0.042 : 0.024) : (dark ? 0.061 : 0.037) * hovered;

      /* Over Mica the fill is WinUI's own, translucent. */
      fill = WinUIThemeWindowShowsMica(window)
        ? [ink colorWithAlphaComponent: amount]
        : WinUIThemeBlendColor(WinUIThemeCaptionBackground(), ink, amount);
      if (_pressed)
        {
          glyph = WinUIThemeBlendColor(WinUIThemeCaptionBackground(), glyph, 0.62);
        }
    }
  if (enabled == NO)
    {
      glyph = WinUIThemeBlendColor(WinUIThemeCaptionBackground(), glyph, 0.36);
    }
  if (fill != nil)
    {
      [fill set];
      NSRectFill([self bounds]);
    }
  [self drawGlyphInRect: [self bounds] color: glyph];
}

@end

@implementation WinUIThemeCaptionView

- (id) initWithFrame: (NSRect)frame
{
  self = [super initWithFrame: frame];
  if (self != nil)
    {
      _minimize = [[WinUIThemeCaptionButton alloc] initWithKind: WinUIThemeCaptionMinimize];
      _zoom = [[WinUIThemeCaptionButton alloc] initWithKind: WinUIThemeCaptionZoom];
      _close = [[WinUIThemeCaptionButton alloc] initWithKind: WinUIThemeCaptionClose];
      [self addSubview: _minimize];
      [self addSubview: _zoom];
      [self addSubview: _close];
      [self setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_minimize);
  RELEASE(_zoom);
  RELEASE(_close);
  [super dealloc];
}

- (BOOL) isOpaque
{
  return YES;
}

- (CGFloat) visibleHeight
{
  return MAX(0.0, NSHeight([self bounds]) - WinUIThemeCaptionHiddenTop([self window]));
}

/* Windows' rule: a window with a system menu has a close button, and one
   that can be minimized or maximized shows both of those buttons (the one
   it can't use disabled); a window without one has no buttons. */
- (void) layoutButtons
{
  NSUInteger style = [[self window] styleMask];
  CGFloat width = round(46.0 * WinUIThemeCaptionDensity());
  CGFloat height = [self visibleHeight];
  CGFloat x = NSMaxX([self bounds]);
  BOOL buttons = WinUIThemeCaptionHasSystemMenu([self window]);
  BOOL sizes = buttons
    && (style & (NSMiniaturizableWindowMask | NSResizableWindowMask)) != 0;

  x -= width;
  [_close setFrame: NSMakeRect(x, 0, width, height)];
  [_close setHidden: buttons == NO];
  [_zoom setHidden: sizes == NO];
  [_minimize setHidden: sizes == NO];
  if (sizes)
    {
      x -= width;
      [_zoom setFrame: NSMakeRect(x, 0, width, height)];
      x -= width;
      [_minimize setFrame: NSMakeRect(x, 0, width, height)];
    }
}

- (void) declareRegions: (int)windowNumber
{
  GSDisplayServer *server = GSCurrentServer();
  NSRect rects[4];
  int kinds[4];
  unsigned count = 0;

  if (windowNumber == 0
      || [server respondsToSelector: @selector(setCaptionRegionRects:kinds:count:forWindow:)] == NO)
    {
      return;
    }
  rects[count] = [self convertRect: [self bounds] toView: nil];
  kinds[count++] = WinUIThemeCaptionRegionDrag;
  if ([_minimize isHidden] == NO)
    {
      rects[count] = [_minimize convertRect: [_minimize bounds] toView: nil];
      kinds[count++] = WinUIThemeCaptionRegionMinimize;
      rects[count] = [_zoom convertRect: [_zoom bounds] toView: nil];
      kinds[count++] = WinUIThemeCaptionRegionZoom;
    }
  if ([_close isHidden] == NO)
    {
      rects[count] = [_close convertRect: [_close bounds] toView: nil];
      kinds[count++] = WinUIThemeCaptionRegionClose;
    }
  [server setCaptionRegionRects: rects kinds: kinds count: count forWindow: windowNumber];
}

- (void) drawRect: (NSRect)dirtyRect
{
  NSWindow *window = [self window];
  BOOL active = WinUIThemeCaptionWindowIsActive(window);
  CGFloat density = WinUIThemeCaptionDensity();
  CGFloat height = [self visibleHeight];
  CGFloat x = round(16.0 * density);
  NSImage *icon = [NSApp applicationIconImage];
  NSString *title = WinUIThemeDisplayTitle(window);

  if (WinUIThemeWindowShowsMica(window))
    {
      NSRectFillUsingOperation([self bounds], NSCompositeClear);
    }
  else
    {
      [WinUIThemeCaptionBackground() set];
      NSRectFill([self bounds]);
    }

  if (icon != nil && WinUIThemeCaptionHasSystemMenu(window))
    {
      CGFloat size = round(16.0 * density);
      NSRect iconRect = NSMakeRect(x, floor((height - size) / 2.0), size, size);

      [icon drawInRect: iconRect
              fromRect: NSZeroRect
             operation: NSCompositeSourceOver
              fraction: active ? 1.0 : 0.6];
      x = NSMaxX(iconRect) + round(16.0 * density);
    }
  if ([title length] > 0)
    {
      WinUITheme *theme = WinUIThemeCaptionTheme();
      NSFont *base = [[theme settings] interfaceFont];
      CGFloat size = round(12.0 * MAX(1.0, [[theme settings] textScaleFactor]));
      NSFont *font = (base != nil) ? [NSFont fontWithName: [base fontName] size: size] : nil;
      NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
      NSDictionary *attributes;
      NSRect buttons = NSMakeRect(NSMaxX([self bounds]), 0, 0, 0);
      NSSize textSize;
      NSEnumerator *e = [[self subviews] objectEnumerator];
      NSView *button;

      if (font == nil)
        {
          font = [NSFont systemFontOfSize: size];
        }
      [paragraph setLineBreakMode: NSLineBreakByTruncatingTail];
      attributes = [NSDictionary dictionaryWithObjectsAndKeys:
        font, NSFontAttributeName,
        WinUIThemeCaptionTextColor(active), NSForegroundColorAttributeName,
        paragraph, NSParagraphStyleAttributeName, nil];
      RELEASE(paragraph);
      while ((button = [e nextObject]) != nil)
        {
          if ([button isHidden] == NO)
            {
              buttons.origin.x = MIN(NSMinX(buttons), NSMinX([button frame]));
            }
        }
      textSize = [title sizeWithAttributes: attributes];
      [title drawInRect: NSMakeRect(x, floor((height - textSize.height) / 2.0),
                                    MAX(0.0, NSMinX(buttons) - x - round(8.0 * density)),
                                    textSize.height)
         withAttributes: attributes];
    }
}

@end

static WinUIThemeCaptionView *
WinUIThemeCaptionViewOf(GSWindowDecorationView *decoration)
{
  NSEnumerator *e = [[decoration subviews] objectEnumerator];
  NSView *view;

  while ((view = [e nextObject]) != nil)
    {
      if ([view isKindOfClass: [WinUIThemeCaptionView class]])
        {
          return (WinUIThemeCaptionView *)view;
        }
    }
  return nil;
}

void
WinUIThemeCaptionLayout(GSWindowDecorationView *decoration, NSWindow *window, int windowNumber)
{
  WinUIThemeCaptionView *caption = WinUIThemeCaptionViewOf(decoration);
  float l = 0.0, r = 0.0, t = 0.0, b = 0.0;
  NSRect bounds = [decoration bounds];
  CGFloat height = WinUIThemeCaptionHeight();
  NSRect frame;

  if (window == nil || WinUIThemeDrawsCaptionForStyle([window styleMask]) == NO)
    {
      [caption removeFromSuperview];
      return;
    }
  [GSCurrentServer() styleoffsets: &l : &r : &t : &b : [window styleMask]];
  frame = NSMakeRect(l, NSMaxY(bounds) - t - height, NSWidth(bounds) - l - r, height);
  if (caption == nil)
    {
      caption = [[WinUIThemeCaptionView alloc] initWithFrame: frame];
      [decoration addSubview: caption];
      RELEASE(caption);
    }
  else
    {
      [caption setFrame: frame];
    }
  [caption layoutButtons];
  [caption setNeedsDisplay: YES];
  [caption declareRegions: windowNumber];
}

void
WinUIThemeCaptionSetNeedsDisplay(GSWindowDecorationView *decoration)
{
  WinUIThemeCaptionView *caption = WinUIThemeCaptionViewOf(decoration);
  NSEnumerator *e = [[caption subviews] objectEnumerator];
  NSView *button;

  [caption setNeedsDisplay: YES];
  while ((button = [e nextObject]) != nil)
    {
      [button setNeedsDisplay: YES];
    }
}
