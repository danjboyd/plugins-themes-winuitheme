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

#import "WinUIThemePalette.h"

#import "../Settings/WinUIThemeSettings.h"

static NSColor *
WinUIThemeRGB(CGFloat red, CGFloat green, CGFloat blue)
{
  return [NSColor colorWithCalibratedRed: red / 255.0
                                   green: green / 255.0
                                    blue: blue / 255.0
                                   alpha: 1.0];
}

@implementation WinUIThemePalette

+ (NSColorList *) colorListForSettings: (WinUIThemeSettings *)settings
{
  NSColorList *colors = [[NSColorList alloc] initWithName: @"System" fromFile: nil];
  BOOL dark = [settings prefersDarkAppearance];
  /* WinUI's AccentFillColorDefault: the accent's Dark1 shade in the light
     theme, Light2 in the dark one; text on it (TextOnAccentFillColorPrimary)
     is white, or black in the dark theme. Selected text keeps the accent
     itself with white text, as WinUI's text controls do. */
  NSColor *accent = [settings accentShade: dark ? 2 : -1];
  NSColor *textSelection = [settings accentColor];
  NSColor *textOnAccent = dark ? [NSColor blackColor] : [NSColor whiteColor];
  BOOL highContrast = [settings highContrastEnabled];
  BOOL reducedTransparency = [settings reducedTransparencyEnabled];
  NSColor *controlColor = nil;
  NSColor *windowBackground = nil;
  NSColor *controlBackground = nil;
  NSColor *surfaceColor = nil;
  NSColor *menuBarBackground = nil;
  NSColor *menuBarBorderColor = nil;
  NSColor *menuBackground = nil;
  NSColor *menuBorderColor = nil;
  NSColor *menuSelectionColor = nil;
  NSColor *menuSelectionTextColor = nil;
  NSColor *menuSeparatorColor = nil;
  NSColor *headerBackground = nil;
  NSColor *textColor = nil;
  NSColor *secondaryTextColor = nil;
  NSColor *disabledTextColor = nil;
  NSColor *shadowColor = nil;
  NSColor *darkShadowColor = nil;
  NSColor *separatorColor = nil;
  NSColor *selectedTextColor = nil;
  NSColor *selectedInactiveColor = nil;
  NSColor *gridColor = nil;
  NSColor *alternateRowBackground = nil;
  NSColor *rowBackground = nil;
  NSColor *highlightedRowBackground = nil;
  NSColor *highlightedRowTextColor = nil;

  if (dark)
    {
      controlColor = WinUIThemeRGB(45, 45, 45);
      windowBackground = WinUIThemeRGB(32, 32, 32);
      controlBackground = WinUIThemeRGB(38, 38, 38);
      surfaceColor = WinUIThemeRGB(42, 42, 42);
      menuBarBackground = WinUIThemeRGB(28, 28, 28);
      menuBarBorderColor = WinUIThemeRGB(58, 58, 58);
      menuBackground = WinUIThemeRGB(44, 44, 44);
      menuBorderColor = WinUIThemeRGB(35, 35, 35);
      menuSelectionColor = WinUIThemeRGB(40, 73, 110);
      menuSelectionTextColor = WinUIThemeRGB(245, 245, 245);
      menuSeparatorColor = WinUIThemeRGB(61, 61, 61);
      headerBackground = WinUIThemeRGB(36, 36, 36);
      textColor = WinUIThemeRGB(245, 245, 245);
      secondaryTextColor = WinUIThemeRGB(198, 198, 198);
      disabledTextColor = WinUIThemeRGB(155, 155, 155);
      shadowColor = WinUIThemeRGB(74, 74, 74);
      darkShadowColor = WinUIThemeRGB(16, 16, 16);
      separatorColor = WinUIThemeRGB(66, 66, 66);
      selectedTextColor = WinUIThemeRGB(255, 255, 255);
      rowBackground = WinUIThemeRGB(34, 34, 34);
      alternateRowBackground = WinUIThemeRGB(38, 38, 38);
      selectedInactiveColor = WinUIThemeRGB(74, 74, 74);
      gridColor = WinUIThemeRGB(67, 67, 67);
      highlightedRowBackground = WinUIThemeRGB(40, 73, 110);
      highlightedRowTextColor = WinUIThemeRGB(245, 245, 245);
    }
  else
    {
      controlColor = WinUIThemeRGB(243, 243, 243);
      windowBackground = WinUIThemeRGB(249, 249, 249);
      controlBackground = WinUIThemeRGB(255, 255, 255);
      surfaceColor = WinUIThemeRGB(250, 250, 251);
      menuBarBackground = WinUIThemeRGB(246, 246, 246);
      menuBarBorderColor = WinUIThemeRGB(229, 229, 231);
      menuBackground = WinUIThemeRGB(249, 249, 249);
      menuBorderColor = WinUIThemeRGB(234, 234, 234);
      menuSelectionColor = WinUIThemeRGB(232, 242, 255);
      menuSelectionTextColor = WinUIThemeRGB(22, 22, 22);
      menuSeparatorColor = WinUIThemeRGB(235, 235, 235);
      headerBackground = WinUIThemeRGB(247, 247, 248);
      textColor = WinUIThemeRGB(22, 22, 22);
      secondaryTextColor = WinUIThemeRGB(84, 84, 84);
      disabledTextColor = WinUIThemeRGB(118, 118, 118);
      shadowColor = WinUIThemeRGB(209, 209, 209);
      darkShadowColor = WinUIThemeRGB(168, 168, 168);
      separatorColor = WinUIThemeRGB(226, 226, 226);
      selectedTextColor = WinUIThemeRGB(255, 255, 255);
      rowBackground = WinUIThemeRGB(252, 252, 252);
      alternateRowBackground = WinUIThemeRGB(247, 248, 249);
      selectedInactiveColor = WinUIThemeRGB(230, 236, 242);
      gridColor = WinUIThemeRGB(223, 226, 229);
      highlightedRowBackground = WinUIThemeRGB(232, 242, 255);
      highlightedRowTextColor = WinUIThemeRGB(22, 22, 22);
    }

  if (highContrast)
    {
      controlColor = dark ? [NSColor blackColor] : [NSColor whiteColor];
      windowBackground = controlColor;
      controlBackground = controlColor;
      surfaceColor = controlColor;
      menuBarBackground = controlColor;
      menuBarBorderColor = dark ? [NSColor whiteColor] : [NSColor blackColor];
      menuBackground = controlColor;
      menuBorderColor = dark ? [NSColor whiteColor] : [NSColor blackColor];
      menuSelectionColor = dark ? [NSColor whiteColor] : [NSColor blackColor];
      menuSelectionTextColor = dark ? [NSColor blackColor] : [NSColor whiteColor];
      menuSeparatorColor = dark ? [NSColor whiteColor] : [NSColor blackColor];
      headerBackground = controlColor;
      textColor = dark ? [NSColor whiteColor] : [NSColor blackColor];
      secondaryTextColor = textColor;
      disabledTextColor = textColor;
      shadowColor = textColor;
      darkShadowColor = textColor;
      separatorColor = textColor;
      selectedTextColor = dark ? [NSColor blackColor] : [NSColor whiteColor];
      rowBackground = controlColor;
      alternateRowBackground = controlColor;
      selectedInactiveColor = textColor;
      gridColor = textColor;
      highlightedRowBackground = menuSelectionColor;
      highlightedRowTextColor = menuSelectionTextColor;
      accent = dark ? [NSColor whiteColor] : [NSColor blackColor];
    }
  else if (reducedTransparency)
    {
      if (dark)
        {
          controlColor = WinUIThemeRGB(38, 38, 38);
          windowBackground = WinUIThemeRGB(24, 24, 24);
          controlBackground = WinUIThemeRGB(31, 31, 31);
          surfaceColor = WinUIThemeRGB(35, 35, 35);
          menuBarBackground = WinUIThemeRGB(26, 26, 26);
          menuBarBorderColor = WinUIThemeRGB(72, 72, 72);
          menuBackground = WinUIThemeRGB(30, 30, 30);
          menuBorderColor = WinUIThemeRGB(76, 76, 76);
          headerBackground = WinUIThemeRGB(32, 32, 32);
          shadowColor = WinUIThemeRGB(90, 90, 90);
          separatorColor = WinUIThemeRGB(82, 82, 82);
          menuSeparatorColor = separatorColor;
          rowBackground = WinUIThemeRGB(29, 29, 29);
          alternateRowBackground = WinUIThemeRGB(34, 34, 34);
          gridColor = WinUIThemeRGB(78, 78, 78);
          selectedInactiveColor = WinUIThemeRGB(84, 84, 84);
        }
      else
        {
          controlColor = WinUIThemeRGB(236, 236, 237);
          windowBackground = WinUIThemeRGB(241, 241, 242);
          controlBackground = WinUIThemeRGB(246, 246, 247);
          surfaceColor = WinUIThemeRGB(244, 244, 245);
          menuBarBackground = WinUIThemeRGB(242, 242, 243);
          menuBarBorderColor = WinUIThemeRGB(214, 214, 216);
          menuBackground = WinUIThemeRGB(246, 246, 247);
          menuBorderColor = WinUIThemeRGB(212, 212, 214);
          headerBackground = WinUIThemeRGB(238, 238, 239);
          shadowColor = WinUIThemeRGB(188, 188, 190);
          darkShadowColor = WinUIThemeRGB(154, 154, 156);
          separatorColor = WinUIThemeRGB(210, 210, 212);
          menuSeparatorColor = separatorColor;
          rowBackground = WinUIThemeRGB(247, 247, 248);
          alternateRowBackground = WinUIThemeRGB(242, 242, 243);
          selectedInactiveColor = WinUIThemeRGB(222, 228, 234);
          gridColor = WinUIThemeRGB(205, 208, 212);
        }
    }

  [colors setColor: controlBackground forKey: @"controlBackgroundColor"];
  [colors setColor: controlColor forKey: @"controlColor"];
  [colors setColor: shadowColor forKey: @"controlShadowColor"];
  [colors setColor: darkShadowColor forKey: @"controlDarkShadowColor"];
  [colors setColor: textColor forKey: @"controlTextColor"];
  [colors setColor: disabledTextColor forKey: @"disabledControlTextColor"];
  [colors setColor: textColor forKey: @"labelColor"];
  [colors setColor: secondaryTextColor forKey: @"secondaryLabelColor"];
  [colors setColor: windowBackground forKey: @"textBackgroundColor"];
  [colors setColor: textColor forKey: @"textColor"];
  [colors setColor: windowBackground forKey: @"windowBackgroundColor"];
  [colors setColor: shadowColor forKey: @"windowFrameColor"];
  [colors setColor: textColor forKey: @"windowFrameTextColor"];
  [colors setColor: menuBarBackground forKey: @"menuBarBackgroundColor"];
  [colors setColor: menuBarBorderColor forKey: @"menuBarBorderColor"];
  [colors setColor: menuBackground forKey: @"menuBackgroundColor"];
  [colors setColor: menuBorderColor forKey: @"menuBorderColor"];
  [colors setColor: menuSeparatorColor forKey: @"menuSeparatorColor"];
  [colors setColor: headerBackground forKey: @"headerBackgroundColor"];
  [colors setColor: textColor forKey: @"headerTextColor"];
  [colors setColor: separatorColor forKey: @"separatorColor"];
  [colors setColor: surfaceColor forKey: @"surfaceColor"];
  [colors setColor: controlBackground forKey: @"fieldBackgroundColor"];
  [colors setColor: accent forKey: @"accentColor"];
  [colors setColor: accent forKey: @"highlightColor"];
  [colors setColor: accent forKey: @"selectedControlColor"];
  [colors setColor: highContrast ? selectedTextColor : textOnAccent forKey: @"selectedControlTextColor"];
  [colors setColor: menuSelectionColor forKey: @"menuSelectionColor"];
  [colors setColor: menuSelectionColor forKey: @"selectedMenuItemColor"];
  [colors setColor: menuSelectionTextColor forKey: @"selectedMenuItemTextColor"];
  [colors setColor: highContrast ? accent : textSelection forKey: @"selectedTextBackgroundColor"];
  [colors setColor: selectedTextColor forKey: @"selectedTextColor"];
  [colors setColor: gridColor forKey: @"gridColor"];
  [colors setColor: rowBackground forKey: @"rowBackgroundColor"];
  [colors setColor: alternateRowBackground forKey: @"alternateRowBackgroundColor"];
  [colors setColor: highlightedRowBackground forKey: @"highlightedTableRowBackgroundColor"];
  [colors setColor: highlightedRowTextColor forKey: @"highlightedTableRowTextColor"];
  [colors setColor: selectedInactiveColor forKey: @"selectedInactiveColor"];

  return AUTORELEASE(colors);
}

@end
