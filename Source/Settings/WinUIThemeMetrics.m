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

#import "WinUIThemeMetrics.h"

#import "WinUIThemeSettings.h"

@implementation WinUIThemeMetrics

- (void) reloadFromSettings: (WinUIThemeSettings *)settings
{
  CGFloat scaleFactor = [settings desktopScaleFactor];
  CGFloat density = scaleFactor > 0.0 ? scaleFactor : 1.0;
  /* Menu rows: WinUI's 32px at 100% text size, taller with larger text. */
  CGFloat scaledBase = 13.0 * [settings textScaleFactor] * density;

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

  /* WinUI's compact density (#31), for layouts made at GNUstep's sizes:
     24px controls, no minimum tab height (GSTheme's own), and GNUstep's
     button margins, so 22pt nib and Gorm controls fit their titles. */
  _compact = [settings compactMetrics];
  if (_compact)
    {
      _minimumTabHeight = 0.0;
      _maximumTabHeight = 0.0;
      _buttonHorizontalPadding = 0.0;
      _buttonVerticalPadding = 0.0;
      _controlHeight = MAX(24.0, ceil(24.0 * density));
      _textFieldHeight = _controlHeight;
      _popupControlHeight = _controlHeight;
    }
}

- (BOOL) compact
{
  return _compact;
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
