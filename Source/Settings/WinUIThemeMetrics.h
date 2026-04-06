#ifndef GNUstep_WINUITHEMEMETRICS_H
#define GNUstep_WINUITHEMEMETRICS_H

#import <AppKit/AppKit.h>

@class WinUIThemeSettings;

@interface WinUIThemeMetrics : NSObject
{
  CGFloat _menuBarHeight;
  CGFloat _menuItemHeight;
  CGFloat _menuSeparatorHeight;
  CGFloat _scrollerWidth;
  CGFloat _buttonHorizontalPadding;
  CGFloat _buttonVerticalPadding;
  CGFloat _minimumTabHeight;
  CGFloat _maximumTabHeight;
  CGFloat _controlHeight;
  CGFloat _textFieldHeight;
  CGFloat _popupControlHeight;
  CGFloat _tableRowHeight;
  CGFloat _controlCornerRadius;
  CGFloat _windowCornerRadius;
}

- (void) reloadFromSettings: (WinUIThemeSettings *)settings;

- (CGFloat) menuBarHeight;
- (CGFloat) menuItemHeight;
- (CGFloat) menuSeparatorHeight;
- (CGFloat) scrollerWidth;
- (CGFloat) buttonHorizontalPadding;
- (CGFloat) buttonVerticalPadding;
- (CGFloat) minimumTabHeight;
- (CGFloat) maximumTabHeight;
- (CGFloat) controlHeight;
- (CGFloat) textFieldHeight;
- (CGFloat) popupControlHeight;
- (CGFloat) tableRowHeight;
- (CGFloat) controlCornerRadius;
- (CGFloat) windowCornerRadius;

@end

#endif

