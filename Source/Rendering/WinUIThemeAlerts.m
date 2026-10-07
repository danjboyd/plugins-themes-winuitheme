#import "WinUIThemeDrawing.h"
#import "../Settings/WinUIThemeSettings.h"

#import <AppKit/AppKit.h>
#import <objc/runtime.h>

/* Alerts laid out as WinUI's ContentDialog: the title in the Subtitle
   style over the body text, both left-aligned in 24pt of padding, on the
   dialog's layer colour; below a hairline, a footer band in the base
   background colour holding the buttons, equal widths in a row, the
   primary (default, accent) one first. After the Adwaita theme's
   re-layout of GSAlertPanel. */

/* ContentDialog's geometry (WinUI 3 defaults). */
static const CGFloat WinUIThemeDialogMinWidth = 320.0;
static const CGFloat WinUIThemeDialogMaxWidth = 548.0;
static const CGFloat WinUIThemeDialogPadding = 24.0;
static const CGFloat WinUIThemeDialogTitleGap = 12.0;
static const CGFloat WinUIThemeDialogButtonHeight = 32.0;
static const CGFloat WinUIThemeDialogButtonGap = 8.0;
static const CGFloat WinUIThemeDialogTitleSize = 20.0;
/* A text field's cell insets its text this much on each side. */
static const CGFloat WinUIThemeDialogCellInset = 2.0;
/* GNUstep's limit: an alert takes at most this much of the screen. */
static const CGFloat WinUIThemeDialogScreenFraction = 0.6;

/* Draws the dialog's two areas: the content's layer colour and, below a
   hairline, the footer's base colour. Sits behind the panel's views. */
@interface WinUIThemeDialogBackgroundView : NSView
{
  CGFloat _footerHeight;
}
- (void) setFooterHeight: (CGFloat)height;
@end

@implementation WinUIThemeDialogBackgroundView

- (void) setFooterHeight: (CGFloat)height
{
  _footerHeight = height;
  [self setNeedsDisplay: YES];
}

- (BOOL) isOpaque
{
  return YES;
}

- (void) drawRect: (NSRect)rect
{
  WinUITheme *theme = (WinUITheme *)[GSTheme theme];
  BOOL winui = [theme isKindOfClass: [WinUITheme class]];
  WinUIThemeSettings *settings = winui ? [theme settings] : nil;
  BOOL dark = [settings prefersDarkAppearance];
  BOOL highContrast = [settings highContrastEnabled];
  NSColor *window = WinUIThemeColorFromTheme(theme, @"windowBackgroundColor",
                                             [NSColor windowBackgroundColor]);
  NSColor *text = WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor]);
  NSRect bounds = [self bounds];
  NSRect footer = NSMakeRect(0.0, 0.0, NSWidth(bounds), _footerHeight);
  NSRect content = NSMakeRect(0.0, _footerHeight, NSWidth(bounds),
                              NSHeight(bounds) - _footerHeight);
  /* SolidBackgroundFillColorBase under LayerFillColorAlt; the hairline is
     CardStrokeColorDefault. */
  NSColor *footerColor = highContrast ? window
    : (dark ? [NSColor colorWithCalibratedWhite: 32.0 / 255.0 alpha: 1.0]
            : [NSColor colorWithCalibratedWhite: 243.0 / 255.0 alpha: 1.0]);
  NSColor *contentColor = highContrast ? window
    : (dark ? [NSColor colorWithCalibratedWhite: 43.0 / 255.0 alpha: 1.0]
            : [NSColor colorWithCalibratedWhite: 251.0 / 255.0 alpha: 1.0]);
  NSColor *lineColor = WinUIThemeBlendColor(footerColor, text, highContrast ? 1.0 : 0.10);

  [contentColor set];
  NSRectFill(NSIntersectionRect(content, rect));
  [footerColor set];
  NSRectFill(NSIntersectionRect(footer, rect));
  if (_footerHeight > 0.0)
    {
      [lineColor set];
      NSRectFill(NSIntersectionRect(NSMakeRect(0.0, _footerHeight - 1.0, NSWidth(bounds), 1.0),
                                    rect));
    }
}

@end

static id
WinUIThemeAlertIvar(id panel, const char *name)
{
  Ivar ivar = class_getInstanceVariable([panel class], name);

  return (ivar != NULL) ? object_getIvar(panel, ivar) : nil;
}

static BOOL
WinUIThemeAlertUses(NSView *control)
{
  return control != nil && [control superview] != nil;
}

static CGFloat
WinUIThemeAlertTextHeight(NSTextField *field, CGFloat width)
{
  if (WinUIThemeAlertUses(field) == NO || [[field stringValue] length] == 0)
    {
      return 0.0;
    }
  return ceil([[field attributedStringValue] boundingRectWithSize: NSMakeSize(width, 1e6)
                                                           options: 0].size.height);
}

static CGFloat
WinUIThemeAlertTextWidth(NSTextField *field)
{
  if (WinUIThemeAlertUses(field) == NO)
    {
      return 0.0;
    }
  return ceil([[field attributedStringValue] size].width);
}

static void
WinUIThemeAlertStyleText(NSTextField *field, NSFont *font, NSColor *color)
{
  [field setFont: font];
  [field setTextColor: color];
  [field setAlignment: NSLeftTextAlignment];
  [field setDrawsBackground: NO];
  [[field cell] setWraps: YES];
  [[field cell] setLineBreakMode: NSLineBreakByWordWrapping];
}

/* The Subtitle style: 20pt Semibold in the interface font's family. */
static NSFont *
WinUIThemeDialogTitleFont(NSFont *bodyFont)
{
  return WinUIThemeSemiboldFont(bodyFont, WinUIThemeDialogTitleSize);
}

@implementation WinUITheme (Alerts)

- (void) _overrideGSAlertPanelMethod_sizePanelToFit
{
  typedef void (*SizeIMP)(id, SEL);
  NSPanel *panel = (NSPanel *)self;
  NSView *content = [panel contentView];
  NSTextField *titleField = WinUIThemeAlertIvar(panel, "titleField");
  NSTextField *messageField = WinUIThemeAlertIvar(panel, "messageField");
  NSScrollView *scroll = WinUIThemeAlertIvar(panel, "scroll");
  NSButton *icon = WinUIThemeAlertIvar(panel, "icoButton");
  WinUITheme *theme = (WinUITheme *)[GSTheme theme];
  NSFont *bodyFont = [[theme settings] interfaceFont];
  NSFont *titleFont = nil;
  NSColor *textColor = WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor]);
  NSMutableArray *buttons = [NSMutableArray array];
  NSArray *candidates = nil;
  NSEnumerator *enumerator = nil;
  NSView *subview = nil;
  NSButton *button = nil;
  WinUIThemeDialogBackgroundView *background = nil;
  NSScreen *screen = [panel screen];
  NSUInteger mask = [panel styleMask];
  CGFloat width, textWidth, rowWidth, buttonWidth = 0.0, buttonsHeight = 0.0, footerHeight;
  CGFloat titleHeight, bodyHeight, bodyShown, height, maxHeight, y;
  BOOL stacked = NO;
  BOOL needsScroll = NO;
  Ivar isGreen = NULL;
  NSRect frame;

  if (titleField == nil || messageField == nil || scroll == nil
      || [theme isKindOfClass: [WinUITheme class]] == NO)
    {
      SizeIMP originalIMP = (SizeIMP)WinUIThemeOriginalMethod(_cmd, self, NSClassFromString(@"GSAlertPanel"));

      if (originalIMP != NULL)
        {
          originalIMP(self, _cmd);
        }
      return;
    }

  if (bodyFont == nil)
    {
      bodyFont = [NSFont systemFontOfSize: 0];
    }
  titleFont = WinUIThemeDialogTitleFont(bodyFont);

  /* No icon and no groove line: WinUI dialogs have neither. */
  [icon setHidden: YES];
  enumerator = [[content subviews] objectEnumerator];
  while ((subview = [enumerator nextObject]) != nil)
    {
      if ([subview isKindOfClass: [NSBox class]])
        {
          [subview setHidden: YES];
        }
      if ([subview isKindOfClass: [WinUIThemeDialogBackgroundView class]])
        {
          background = (WinUIThemeDialogBackgroundView *)subview;
        }
    }
  WinUIThemeAlertStyleText(titleField, titleFont, textColor);
  WinUIThemeAlertStyleText(messageField, bodyFont, textColor);

  /* Left to right as WinUI orders Primary, Secondary and Close: the
     default button, the other button, then the alternate (usually
     Cancel). */
  candidates = [NSArray arrayWithObjects: WinUIThemeAlertIvar(panel, "defButton"),
                                          WinUIThemeAlertIvar(panel, "othButton"),
                                          WinUIThemeAlertIvar(panel, "altButton"),
                                          nil];
  enumerator = [candidates objectEnumerator];
  while ((button = [enumerator nextObject]) != nil)
    {
      if (WinUIThemeAlertUses(button))
        {
          [buttons addObject: button];
        }
    }

  /* As wide as the text, or the buttons at equal widths, want, within
     ContentDialog's limits. */
  width = MAX(WinUIThemeAlertTextWidth(titleField), WinUIThemeAlertTextWidth(messageField))
    + 2.0 * (WinUIThemeDialogPadding + WinUIThemeDialogCellInset);
  if ([buttons count] > 0)
    {
      NSUInteger columns = MAX((NSUInteger)2, [buttons count]);
      CGFloat widest = 0.0;

      enumerator = [buttons objectEnumerator];
      while ((button = [enumerator nextObject]) != nil)
        {
          [button sizeToFit];
          widest = MAX(widest, NSWidth([button frame]));
        }
      width = MAX(width, columns * widest + (columns - 1) * WinUIThemeDialogButtonGap
                         + 2.0 * WinUIThemeDialogPadding);
    }
  width = MAX(WinUIThemeDialogMinWidth, MIN(WinUIThemeDialogMaxWidth, ceil(width)));
  textWidth = width - 2.0 * WinUIThemeDialogPadding;
  rowWidth = width - 2.0 * WinUIThemeDialogPadding;

  if ([buttons count] > 0)
    {
      /* ContentDialog's footer has two columns at least: a lone button
         takes the right one. */
      NSUInteger columns = MAX((NSUInteger)2, [buttons count]);

      buttonWidth = floor((rowWidth - WinUIThemeDialogButtonGap * (columns - 1)) / columns);
      enumerator = [buttons objectEnumerator];
      while ((button = [enumerator nextObject]) != nil)
        {
          [button sizeToFit];
          if (NSWidth([button frame]) > buttonWidth)
            {
              stacked = YES;
            }
        }
      buttonsHeight = stacked
        ? [buttons count] * (WinUIThemeDialogButtonHeight + WinUIThemeDialogButtonGap)
          - WinUIThemeDialogButtonGap
        : WinUIThemeDialogButtonHeight;
    }
  footerHeight = ([buttons count] > 0) ? buttonsHeight + 2.0 * WinUIThemeDialogPadding : 0.0;

  titleHeight = WinUIThemeAlertTextHeight(titleField, textWidth);
  bodyHeight = WinUIThemeAlertTextHeight(messageField, textWidth);
  height = WinUIThemeDialogPadding + titleHeight
    + (bodyHeight > 0.0 ? WinUIThemeDialogTitleGap + bodyHeight : 0.0)
    + WinUIThemeDialogPadding + footerHeight;

  /* Too tall for the screen: the body scrolls. */
  if (screen == nil)
    {
      screen = [NSScreen mainScreen];
    }
  maxHeight = WinUIThemeDialogScreenFraction
    * [NSWindow contentRectForFrameRect: [screen frame] styleMask: mask].size.height;
  bodyShown = bodyHeight;
  if (height > maxHeight && bodyHeight > 0.0)
    {
      bodyShown = MAX(bodyHeight - (height - maxHeight), 3.0 * [bodyFont defaultLineHeightForFont]);
      height -= bodyHeight - bodyShown;
      needsScroll = YES;
    }

  frame = [NSWindow frameRectForContentRect: NSMakeRect(0.0, 0.0, width, height)
                                  styleMask: mask];
  [panel setMinSize: frame.size];
  [panel setMaxSize: frame.size];
  [panel setContentSize: NSMakeSize(width, height)];

  if (background == nil)
    {
      background = AUTORELEASE([[WinUIThemeDialogBackgroundView alloc] initWithFrame: [content bounds]]);
      [background setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
      [content addSubview: background positioned: NSWindowBelow relativeTo: nil];
    }
  [background setFrame: [content bounds]];
  [background setFooterHeight: footerHeight];

  /* Bottom up: the buttons in the footer, then the body, then the title. */
  y = WinUIThemeDialogPadding;
  if (stacked)
    {
      /* The primary button on top. */
      enumerator = [buttons reverseObjectEnumerator];
      while ((button = [enumerator nextObject]) != nil)
        {
          [button setFrame: NSMakeRect(WinUIThemeDialogPadding, y,
                                       rowWidth, WinUIThemeDialogButtonHeight)];
          y += WinUIThemeDialogButtonHeight + WinUIThemeDialogButtonGap;
        }
    }
  else
    {
      CGFloat x = WinUIThemeDialogPadding;

      if ([buttons count] == 1)
        {
          x = width - WinUIThemeDialogPadding - buttonWidth;
        }
      enumerator = [buttons objectEnumerator];
      while ((button = [enumerator nextObject]) != nil)
        {
          /* The last button takes what rounding left over. */
          CGFloat buttonSlot = (button == [buttons lastObject])
            ? width - WinUIThemeDialogPadding - x
            : buttonWidth;

          [button setFrame: NSMakeRect(x, y, buttonSlot, WinUIThemeDialogButtonHeight)];
          x += buttonSlot + WinUIThemeDialogButtonGap;
        }
    }
  y = footerHeight + WinUIThemeDialogPadding;

  if (bodyHeight > 0.0)
    {
      NSRect bodyRect = NSMakeRect(WinUIThemeDialogPadding - WinUIThemeDialogCellInset, y,
                                   textWidth + 2.0 * WinUIThemeDialogCellInset, bodyShown);

      if (needsScroll)
        {
          NSSize inner;

          [messageField removeFromSuperview];
          [scroll setFrame: bodyRect];
          [scroll setDrawsBackground: NO];
          inner = [NSScrollView contentSizeForFrameSize: bodyRect.size
                                  hasHorizontalScroller: NO
                                    hasVerticalScroller: YES
                                             borderType: [scroll borderType]];
          [messageField setFrame: NSMakeRect(0.0, 0.0, inner.width,
                                             WinUIThemeAlertTextHeight(messageField, inner.width))];
          [scroll setDocumentView: messageField];
          if (WinUIThemeAlertUses(scroll) == NO)
            {
              [content addSubview: scroll];
            }
        }
      else
        {
          [messageField setFrame: bodyRect];
        }
      y += bodyShown + WinUIThemeDialogTitleGap;
    }
  [titleField setFrame: NSMakeRect(WinUIThemeDialogPadding - WinUIThemeDialogCellInset, y,
                                   textWidth + 2.0 * WinUIThemeDialogCellInset, titleHeight)];

  isGreen = class_getInstanceVariable([panel class], "isGreen");
  if (isGreen != NULL)
    {
      *(BOOL *)((char *)panel + ivar_getOffset(isGreen)) = NO;
    }
  [content setNeedsDisplay: YES];
}

/* A ContentDialog sits over the window it belongs to. GNUstep centres an
   alert on the screen when its modal session begins; centre it on the
   app's main (or key) window instead, when one is showing. */
- (void) _overrideGSAlertPanelMethod_center
{
  typedef void (*CenterIMP)(id, SEL);
  NSWindow *panel = (NSWindow *)self;
  NSWindow *parent = [NSApp mainWindow];
  NSRect parentFrame;
  NSRect frame;

  if (parent == nil || parent == panel || [parent isVisible] == NO)
    {
      parent = [NSApp keyWindow];
    }
  if (parent == nil || parent == panel || [parent isVisible] == NO
      || [parent isMiniaturized])
    {
      CenterIMP originalIMP = (CenterIMP)WinUIThemeOriginalMethod(_cmd, self, NSClassFromString(@"GSAlertPanel"));

      if (originalIMP != NULL)
        {
          originalIMP(self, _cmd);
        }
      return;
    }

  parentFrame = [parent frame];
  frame = [panel frame];
  frame.origin.x = floor(NSMidX(parentFrame) - NSWidth(frame) / 2.0);
  frame.origin.y = floor(NSMidY(parentFrame) - NSHeight(frame) / 2.0);
  [panel setFrameOrigin: frame.origin];
}

@end
