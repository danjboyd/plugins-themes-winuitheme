#import "WinUIThemeDrawing.h"

#import <AppKit/AppKit.h>
#import <objc/runtime.h>

/* Template images tinted with the foreground colour, as WinUI draws icons
   (FontIcon, SymbolIcon) in their control's foreground: an app ships one
   monochrome icon set and it reads right in light, dark and high contrast,
   on an accent button and in menus. Only the image's alpha is used.
   After the Adwaita theme's symbolic images.

   An image is a template when -[NSImage isTemplate] says so (libs-gui
   after 0.32), or by its name: Cocoa's "...Template" or GNOME's
   "...-symbolic", for libs-gui 0.32, which has no -setTemplate:. Buttons,
   toolbar items and menu items draw their image through
   -[NSButtonCell drawImage:withFrame:inView:]. */

@interface NSImage (WinUIThemeTemplateImages)
- (BOOL) isTemplate;
@end

static char WinUIThemeTintedImagesKey;

BOOL
WinUIThemeImageIsTemplate(NSImage *image)
{
  NSString *name = nil;

  if (image == nil)
    {
      return NO;
    }
  if ([image respondsToSelector: @selector(isTemplate)] && [image isTemplate])
    {
      return YES;
    }
  name = [image name];
  return [name hasSuffix: @"Template"] || [name hasSuffix: @"-symbolic"];
}

/* The image's shape in `color`, kept with the image for each colour it's
   drawn in (a few: the states of the palette in use). */
NSImage *
WinUIThemeTintedImage(NSImage *image, NSColor *color)
{
  NSMutableDictionary *tinted = objc_getAssociatedObject(image, &WinUIThemeTintedImagesKey);
  NSColor *rgb = [color colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
  NSSize size = [image size];
  NSRect rect = NSMakeRect(0.0, 0.0, size.width, size.height);
  NSString *key = nil;
  NSImage *result = nil;

  if (rgb == nil || size.width <= 0.0 || size.height <= 0.0)
    {
      return image;
    }
  key = [NSString stringWithFormat: @"%.4f %.4f %.4f %.4f",
                                    [rgb redComponent], [rgb greenComponent],
                                    [rgb blueComponent], [rgb alphaComponent]];
  result = [tinted objectForKey: key];
  if (result != nil)
    {
      return result;
    }
  if (tinted == nil)
    {
      tinted = [NSMutableDictionary dictionary];
      objc_setAssociatedObject(image, &WinUIThemeTintedImagesKey, tinted,
                               OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
  result = AUTORELEASE([[NSImage alloc] initWithSize: size]);
  [result lockFocus];
  [image drawInRect: rect fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1.0];
  [rgb set];
  NSRectFillUsingOperation(rect, NSCompositeSourceIn);
  [result unlockFocus];
  [tinted setObject: result forKey: key];
  return result;
}

/* The colour a button cell's title is drawn in: text on the accent for a
   default button, the menu's text (or selected text) colour in menus, the
   disabled text colour when disabled, else the text colour. */
NSColor *
WinUIThemeTemplateImageColor(WinUITheme *theme, NSButtonCell *cell, NSView *controlView)
{
  BOOL enabled = [cell isEnabled];
  /* A cell that dims its image itself (libs-gui draws it at half opacity)
     gets the enabled colour. */
  BOOL dimmed = (enabled == NO && [cell imageDimsWhenDisabled] == NO);

  if (dimmed)
    {
      return WinUIThemeColorFromTheme(theme, @"disabledControlTextColor",
                                      [NSColor disabledControlTextColor]);
    }
  if ([cell isKindOfClass: [NSMenuItemCell class]])
    {
      return [cell isHighlighted]
        ? WinUIThemeColorFromTheme(theme, @"selectedMenuItemTextColor",
                                   [NSColor selectedMenuItemTextColor])
        : WinUIThemeColorFromTheme(theme, @"controlTextColor", [NSColor controlTextColor]);
    }
  if (enabled && [cell isBordered] && WinUIThemeButtonIsDefault(cell))
    {
      return WinUIThemeColorFromTheme(theme, @"selectedControlTextColor",
                                      [NSColor selectedControlTextColor]);
    }
  (void)controlView;
  return WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor]);
}
