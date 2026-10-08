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

/* A Gorm palette of controls at WinUI's sizes: 32px Button and
   AccentButton (the default button), TextBox, ComboBox (a pop-up, and an
   editable combo box), AutoSuggestBox (a search field), CheckBox,
   RadioButton, ToggleSwitch, and labels in WinUI's type ramp. Gorm's own
   palettes make 22pt controls, sized for GNUstep's metrics; these are for
   apps that run with the theme's WinUI metrics (WinUIThemeMetrics = winui
   in their Info.plist).

   Fonts are left at the system font's default size where the ramp allows,
   which Gorm archives as "the system font" with no size, so they follow the
   metrics the app runs with: Body is the system font, BodyStrong the bold
   system font (the theme's Semibold). Caption, Subtitle and Title have
   sizes of their own (12, 20 and 28px); they're archived as the system and
   bold system fonts at that size, so they keep the theme's face and their
   size. The controls are built here rather than in a Gorm file, so their
   sizes are plain to read and change. */

#import <AppKit/AppKit.h>
#import <InterfaceBuilder/InterfaceBuilder.h>

/* WinUI's control height (Button, TextBox, ComboBox, AutoSuggestBox, and
   the minimum for CheckBox, RadioButton and ToggleSwitch). */
static const CGFloat WinUIControlHeight = 32.0;
/* ToggleSwitch's 40x20 track; the control is as tall as the others. */
static const CGFloat WinUISwitchWidth = 40.0;
/* Gorm's palette area. */
static const NSSize WinUIPaletteSize = {272.0, 192.0};
static const CGFloat WinUIMargin = 8.0;
static const CGFloat WinUIGap = 4.0;
/* A column of the two-column rows. */
static const CGFloat WinUIColumnWidth = 126.0;

@interface WinUIPalette : IBPalette
@end

@implementation WinUIPalette

/* A frame `top` points below the palette's top edge. */
static NSRect
WinUIFrame(CGFloat x, CGFloat top, CGFloat width, CGFloat height)
{
  return NSMakeRect(x, WinUIPaletteSize.height - top - height, width, height);
}

static NSButton *
WinUIButton(NSString *title, NSRect frame, NSButtonType type)
{
  NSButton *button = [[NSButton alloc] initWithFrame: frame];

  [button setButtonType: type];
  if (type == NSMomentaryPushInButton)
    {
      [button setBezelStyle: NSRoundedBezelStyle];
    }
  [button setTitle: title];
  return AUTORELEASE(button);
}

/* A label in `font` (nil for the system font at its default size), as
   tall as the font's line. */
static NSTextField *
WinUILabel(NSString *text, CGFloat x, CGFloat top, CGFloat width, CGFloat height,
           NSFont *font)
{
  NSTextField *label = [[NSTextField alloc] initWithFrame: WinUIFrame(x, top, width, height)];

  [label setStringValue: text];
  [label setBezeled: NO];
  [label setBordered: NO];
  [label setDrawsBackground: NO];
  [label setEditable: NO];
  [label setSelectable: NO];
  if (font != nil)
    {
      [label setFont: font];
    }
  return AUTORELEASE(label);
}

- (void) finishInstantiate
{
  NSWindow *window;
  NSView *content;
  NSButton *accent;
  NSSwitch *toggle;
  NSTextField *textBox;
  NSPopUpButton *popUp;
  NSSearchField *search;
  NSComboBox *comboBox;
  /* Gorm edits pop-up items only in its own subclass (saved as an
     NSPopUpButton); its Controls palette, loaded first, provides it. */
  Class popUpClass = NSClassFromString(@"GormNSPopUpButton");
  CGFloat secondColumn = WinUIMargin + WinUIColumnWidth + WinUIGap;
  CGFloat top = WinUIMargin;
  CGFloat bottom;

  window = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, WinUIPaletteSize.width,
                                                             WinUIPaletteSize.height)
                                       styleMask: NSBorderlessWindowMask
                                         backing: NSBackingStoreRetained
                                           defer: YES];
  [window setTitle: @"WinUI"];
  content = [window contentView];

  /* Button, AccentButton (the default button, which the theme fills with
     the accent colour) and ToggleSwitch (NSSwitch). */
  [content addSubview: WinUIButton(@"Button", WinUIFrame(WinUIMargin, top, 88, WinUIControlHeight),
                                   NSMomentaryPushInButton)];
  accent = WinUIButton(@"Accent", WinUIFrame(WinUIMargin + 92, top, 88, WinUIControlHeight),
                       NSMomentaryPushInButton);
  [accent setKeyEquivalent: @"\r"];
  [content addSubview: accent];
  toggle = AUTORELEASE([[NSSwitch alloc] initWithFrame:
                         WinUIFrame(WinUIPaletteSize.width - WinUIMargin - WinUISwitchWidth, top,
                                    WinUISwitchWidth, WinUIControlHeight)]);
  /* libs-gui 0.32 makes switches disabled; the theme enables them, but the
     palette may run under another. */
  [toggle setEnabled: YES];
  [toggle setState: NSControlStateValueOn];
  [content addSubview: toggle];
  top += WinUIControlHeight + WinUIGap;

  /* TextBox and ComboBox (a pop-up button). */
  textBox = AUTORELEASE([[NSTextField alloc] initWithFrame:
                          WinUIFrame(WinUIMargin, top, WinUIColumnWidth, WinUIControlHeight)]);
  [textBox setBezeled: YES];
  [textBox setEditable: YES];
  [textBox setSelectable: YES];
  [[textBox cell] setPlaceholderString: @"TextBox"];
  [content addSubview: textBox];
  popUp = AUTORELEASE([[(popUpClass != Nil ? popUpClass : [NSPopUpButton class]) alloc]
                        initWithFrame: WinUIFrame(secondColumn, top, WinUIColumnWidth, WinUIControlHeight)
                            pullsDown: NO]);
  [popUp addItemsWithTitles: [NSArray arrayWithObjects: @"Item 1", @"Item 2", @"Item 3", nil]];
  [content addSubview: popUp];
  top += WinUIControlHeight + WinUIGap;

  /* AutoSuggestBox (a search field) and an editable ComboBox. */
  search = AUTORELEASE([[NSSearchField alloc] initWithFrame:
                         WinUIFrame(WinUIMargin, top, WinUIColumnWidth, WinUIControlHeight)]);
  [[search cell] setPlaceholderString: @"Search"];
  [content addSubview: search];
  comboBox = AUTORELEASE([[NSComboBox alloc] initWithFrame:
                           WinUIFrame(secondColumn, top, WinUIColumnWidth, WinUIControlHeight)]);
  [comboBox addItemsWithObjectValues: [NSArray arrayWithObjects: @"Item 1", @"Item 2", @"Item 3", nil]];
  [comboBox setEditable: YES];
  /* Its text, not a placeholder: a combo box draws no placeholder, and
     Gorm's archives drop them (the TextBox and search field are empty once
     dropped in a window). */
  [comboBox setStringValue: @"Editable"];
  [content addSubview: comboBox];
  top += WinUIControlHeight + WinUIGap;

  /* CheckBox and RadioButton, then Caption (12px) and Body (the system
     font, 14px under WinUI's metrics) labels. */
  [content addSubview: WinUIButton(@"Check", WinUIFrame(WinUIMargin, top, 76, WinUIControlHeight),
                                   NSSwitchButton)];
  [content addSubview: WinUIButton(@"Option", WinUIFrame(WinUIMargin + 80, top, 80, WinUIControlHeight),
                                   NSRadioButton)];
  [content addSubview: WinUILabel(@"Caption", WinUIMargin + 164, top + 8, 52, 16,
                                  [NSFont systemFontOfSize: 12.0])];
  [content addSubview: WinUILabel(@"Body", WinUIMargin + 216, top + 6, 40, 20, nil)];

  /* Title (28px Semibold), Subtitle (20px Semibold) and BodyStrong (the
     bold system font, Semibold at the body size), on one baseline: each
     label is as tall as its line, bottoms aligned. */
  bottom = WinUIPaletteSize.height;
  [content addSubview: WinUILabel(@"Title", WinUIMargin, bottom - 38 - 2, 72, 38,
                                  [NSFont boldSystemFontOfSize: 28.0])];
  [content addSubview: WinUILabel(@"Subtitle", WinUIMargin + 76, bottom - 28 - 4, 84, 28,
                                  [NSFont boldSystemFontOfSize: 20.0])];
  [content addSubview: WinUILabel(@"BodyStrong", WinUIMargin + 164, bottom - 20 - 6, 92, 20,
                                  [NSFont boldSystemFontOfSize: 0.0])];

  originalWindow = window;
}

@end
