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
/* On a sized copy: the image it was made from, whose name says whether
   it's a template (a copy has no name). */
static char WinUIThemeSizedImageSourceKey;

BOOL
WinUIThemeImageIsTemplate(NSImage *image)
{
  NSString *name = nil;
  NSImage *source = nil;

  if (image == nil)
    {
      return NO;
    }
  source = objc_getAssociatedObject(image, &WinUIThemeSizedImageSourceKey);
  if (source != nil)
    {
      return WinUIThemeImageIsTemplate(source);
    }
  if ([image respondsToSelector: @selector(isTemplate)] && [image isTemplate])
    {
      return YES;
    }
  name = [image name];
  return [name hasSuffix: @"Template"] || [name hasSuffix: @"-symbolic"];
}

/* An app's image drawn at another size, for a control that sizes what it
   draws from -[NSImage size] (#89). It has no representations of its own:
   it lists the source's, for tinting, and draws the source scaled. A copy
   ([image copy] and -setSize:) would lose an image drawn with -lockFocus,
   whose cached representation NSImage doesn't copy. */
@interface WinUIThemeSizedImage : NSImage
{
  NSImage *_source;
}
- (id) initWithImage: (NSImage *)source size: (NSSize)size;
@end

@implementation WinUIThemeSizedImage

- (id) initWithImage: (NSImage *)source size: (NSSize)size
{
  self = [super initWithSize: size];
  if (self != nil)
    {
      ASSIGN(_source, source);
      objc_setAssociatedObject(self, &WinUIThemeSizedImageSourceKey, source,
                               OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_source);
  [super dealloc];
}

- (id) copyWithZone: (NSZone *)zone
{
  return [[WinUIThemeSizedImage allocWithZone: zone] initWithImage: _source size: [self size]];
}

- (NSArray *) representations
{
  return [_source representations];
}

- (NSImageRep *) bestRepresentationForDevice: (NSDictionary *)deviceDescription
{
  return [_source bestRepresentationForDevice: deviceDescription];
}

- (BOOL) isValid
{
  return [_source isValid];
}

- (BOOL) isTemplate
{
  return [_source respondsToSelector: @selector(isTemplate)] && [_source isTemplate];
}

/* `rect` of this image in the source's coordinates. */
- (NSRect) sourceRectFor: (NSRect)rect
{
  NSSize own = [self size];
  NSSize source = [_source size];

  if (NSIsEmptyRect(rect) || own.width <= 0.0 || own.height <= 0.0)
    {
      return NSZeroRect;
    }
  return NSMakeRect(rect.origin.x * source.width / own.width,
                    rect.origin.y * source.height / own.height,
                    rect.size.width * source.width / own.width,
                    rect.size.height * source.height / own.height);
}

- (void) drawInRect: (NSRect)dstRect
           fromRect: (NSRect)srcRect
          operation: (NSCompositingOperation)op
           fraction: (CGFloat)delta
     respectFlipped: (BOOL)respectFlipped
              hints: (NSDictionary *)hints
{
  [_source drawInRect: dstRect
             fromRect: [self sourceRectFor: srcRect]
            operation: op
             fraction: delta
       respectFlipped: respectFlipped
                hints: hints];
}

- (void) drawInRect: (NSRect)dstRect
           fromRect: (NSRect)srcRect
          operation: (NSCompositingOperation)op
           fraction: (CGFloat)delta
{
  [_source drawInRect: dstRect
             fromRect: [self sourceRectFor: srcRect]
            operation: op
             fraction: delta];
}

- (void) drawAtPoint: (NSPoint)point
            fromRect: (NSRect)srcRect
           operation: (NSCompositingOperation)op
            fraction: (CGFloat)delta
{
  NSRect rect = NSIsEmptyRect(srcRect)
    ? NSMakeRect(0.0, 0.0, [self size].width, [self size].height) : srcRect;

  [self drawInRect: NSMakeRect(point.x, point.y, rect.size.width, rect.size.height)
          fromRect: srcRect
         operation: op
          fraction: delta];
}

@end

NSImage *
WinUIThemeSizedImageCopy(NSImage *image, NSSize size)
{
  if (image == nil || NSEqualSizes([image size], size))
    {
      return image;
    }
  return AUTORELEASE([[WinUIThemeSizedImage alloc] initWithImage: image size: size]);
}

NSImage *
WinUIThemeSizedImageSource(NSImage *image)
{
  return (image != nil) ? objc_getAssociatedObject(image, &WinUIThemeSizedImageSourceKey) : nil;
}

/* The image's largest bitmap, as its PNG loads, or nil. */
static NSBitmapImageRep *
WinUIThemeLargestBitmap(NSImage *image)
{
  NSEnumerator *enumerator = [[image representations] objectEnumerator];
  NSImageRep *rep = nil;
  NSBitmapImageRep *largest = nil;

  while ((rep = [enumerator nextObject]) != nil)
    {
      if ([rep isKindOfClass: [NSBitmapImageRep class]]
          && [rep pixelsWide] > 0 && [rep pixelsHigh] > 0
          && (largest == nil || [rep pixelsWide] > [largest pixelsWide]))
        {
          largest = (NSBitmapImageRep *)rep;
        }
    }
  return largest;
}

/* `source`'s alpha in `rgb`, as a new image of `size`: its pixels
   recoloured, without drawing. An image drawn into with -lockFocus before
   any window is on screen comes out blank on Windows (issue #64). */
static NSImage *
WinUIThemeRecolouredBitmap(NSBitmapImageRep *source, NSColor *rgb, NSSize size)
{
  NSInteger width = [source pixelsWide];
  NSInteger height = [source pixelsHigh];
  CGFloat red = [rgb redComponent];
  CGFloat green = [rgb greenComponent];
  CGFloat blue = [rgb blueComponent];
  CGFloat alpha = [rgb alphaComponent];
  NSBitmapImageRep *rep = nil;
  NSImage *result = nil;
  unsigned char *data = NULL;
  NSInteger bytesPerRow, x, y;

  rep = AUTORELEASE([[NSBitmapImageRep alloc]
                      initWithBitmapDataPlanes: NULL
                                    pixelsWide: width
                                    pixelsHigh: height
                                 bitsPerSample: 8
                               samplesPerPixel: 4
                                      hasAlpha: YES
                                      isPlanar: NO
                                colorSpaceName: NSCalibratedRGBColorSpace
                                   bytesPerRow: 0
                                  bitsPerPixel: 0]);
  data = [rep bitmapData];
  if (data == NULL)
    {
      return nil;
    }
  bytesPerRow = [rep bytesPerRow];
  for (y = 0; y < height; y++)
    {
      CREATE_AUTORELEASE_POOL(pool);

      for (x = 0; x < width; x++)
        {
          /* Premultiplied, as a rep without NSAlphaNonpremultipliedBitmapFormat is. */
          CGFloat a = [[source colorAtX: x y: y] alphaComponent] * alpha;
          unsigned char *pixel = data + y * bytesPerRow + x * 4;

          pixel[0] = (unsigned char)lround(red * a * 255.0);
          pixel[1] = (unsigned char)lround(green * a * 255.0);
          pixel[2] = (unsigned char)lround(blue * a * 255.0);
          pixel[3] = (unsigned char)lround(a * 255.0);
        }
      RELEASE(pool);
    }
  [rep setSize: size];
  result = AUTORELEASE([[NSImage alloc] initWithSize: size]);
  [result addRepresentation: rep];
  /* Drawn from the bitmap, not a copy GNUstep caches in a window. */
  [result setCacheMode: NSImageCacheNever];
  return result;
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
  NSBitmapImageRep *bitmap = nil;
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
  bitmap = WinUIThemeLargestBitmap(image);
  if (bitmap != nil)
    {
      result = WinUIThemeRecolouredBitmap(bitmap, rgb, size);
    }
  if (result != nil)
    {
      [tinted setObject: result forKey: key];
      return result;
    }
  /* An image with no bitmap (drawn, or vector) is drawn into a copy, which
     isn't kept: one made before a window is on screen may be blank. */
  result = AUTORELEASE([[NSImage alloc] initWithSize: size]);
  [result lockFocus];
  [image drawInRect: rect fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1.0];
  [rgb set];
  NSRectFillUsingOperation(rect, NSCompositeSourceIn);
  [result unlockFocus];
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
      return WinUIThemeColorFromTheme(theme, @"accentTextColor",
                                      [NSColor selectedControlTextColor]);
    }
  (void)controlView;
  return WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor]);
}
