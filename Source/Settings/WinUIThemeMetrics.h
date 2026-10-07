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

