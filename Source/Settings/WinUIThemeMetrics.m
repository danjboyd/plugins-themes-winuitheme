#import "WinUIThemeMetrics.h"

#import "WinUIThemeSettings.h"

@implementation WinUIThemeMetrics

- (void) reloadFromSettings: (WinUIThemeSettings *)settings
{
  CGFloat baseFontSize = [settings interfaceFontSize];
  CGFloat scaleFactor = [settings desktopScaleFactor];
  CGFloat density = scaleFactor > 0.0 ? scaleFactor : 1.0;
  CGFloat scaledBase = MAX(baseFontSize, 9.0) * density;

  _menuBarHeight = MAX(32.0, ceil(scaledBase * 2.40));
  _menuItemHeight = MAX(32.0, ceil(scaledBase * 2.40));
  _menuSeparatorHeight = MAX(8.0, ceil(7.0 * density));
  _scrollerWidth = MAX(14.0, ceil(14.0 * density));
  _buttonHorizontalPadding = MAX(14.0, ceil(13.0 * density));
  _buttonVerticalPadding = MAX(6.0, ceil(6.0 * density));
  _minimumTabHeight = MAX(32.0, ceil(32.0 * density));
  _maximumTabHeight = MAX(_minimumTabHeight + 6.0, ceil(40.0 * density));
  _controlHeight = MAX(32.0, ceil(34.0 * density));
  _textFieldHeight = _controlHeight;
  _popupControlHeight = _controlHeight;
  _tableRowHeight = MAX(30.0, ceil(32.0 * density));
  _controlCornerRadius = MAX(4.0, ceil(4.0 * density));
  _windowCornerRadius = MAX(8.0, ceil(8.0 * density));
}

- (CGFloat) menuBarHeight
{
  return _menuBarHeight;
}

- (CGFloat) menuItemHeight
{
  return _menuItemHeight;
}

- (CGFloat) menuSeparatorHeight
{
  return _menuSeparatorHeight;
}

- (CGFloat) scrollerWidth
{
  return _scrollerWidth;
}

- (CGFloat) buttonHorizontalPadding
{
  return _buttonHorizontalPadding;
}

- (CGFloat) buttonVerticalPadding
{
  return _buttonVerticalPadding;
}

- (CGFloat) minimumTabHeight
{
  return _minimumTabHeight;
}

- (CGFloat) maximumTabHeight
{
  return _maximumTabHeight;
}

- (CGFloat) controlHeight
{
  return _controlHeight;
}

- (CGFloat) textFieldHeight
{
  return _textFieldHeight;
}

- (CGFloat) popupControlHeight
{
  return _popupControlHeight;
}

- (CGFloat) tableRowHeight
{
  return _tableRowHeight;
}

- (CGFloat) controlCornerRadius
{
  return _controlCornerRadius;
}

- (CGFloat) windowCornerRadius
{
  return _windowCornerRadius;
}

@end
