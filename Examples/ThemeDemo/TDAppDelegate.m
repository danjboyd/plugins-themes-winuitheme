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

#import "TDAppDelegate.h"

#import "TDContractLoader.h"

#import <GNUstepGUI/GSTheme.h>

/* -[NSImage setTemplate:] exists in libs-gui after 0.32; called only when
   the running libs-gui has it. */
@interface NSImage (TDTemplateImages)
- (void) setTemplate: (BOOL)flag;
@end

static NSString *TDToolbarNew = @"TDToolbarNew";
static NSString *TDToolbarOpen = @"TDToolbarOpen";
static NSString *TDToolbarSave = @"TDToolbarSave";
static NSString *TDToolbarShare = @"TDToolbarShare";
static NSString *TDToolbarSearch = @"TDToolbarSearch";

@interface TDFlippedView : NSView
@end

@implementation TDFlippedView

- (BOOL) isFlipped
{
  return YES;
}

@end

@interface TDMenuBarFixtureView : NSView
{
  NSMutableArray *_cells;
  NSMenu *_fileMenu;
  NSMenu *_editMenu;
}
@end

@implementation TDMenuBarFixtureView

- (id) initWithFrame: (NSRect)frame
{
  self = [super initWithFrame: frame];
  if (self != nil)
    {
      NSMenuItem *fileItem = [[[NSMenuItem alloc] initWithTitle: @"File" action: NULL keyEquivalent: @""] autorelease];
      NSMenuItem *editItem = [[[NSMenuItem alloc] initWithTitle: @"Edit" action: NULL keyEquivalent: @""] autorelease];
      NSMenuItemCell *cell = nil;

      _cells = [[NSMutableArray alloc] init];
      _fileMenu = [[NSMenu alloc] initWithTitle: @"File"];
      _editMenu = [[NSMenu alloc] initWithTitle: @"Edit"];

      [_fileMenu addItemWithTitle: @"New" action: NULL keyEquivalent: @"n"];
      [_fileMenu addItemWithTitle: @"Open" action: NULL keyEquivalent: @"o"];
      [_fileMenu addItem: [NSMenuItem separatorItem]];
      [_fileMenu addItemWithTitle: @"Export" action: NULL keyEquivalent: @""];

      [_editMenu addItemWithTitle: @"Undo" action: NULL keyEquivalent: @"z"];
      [_editMenu addItemWithTitle: @"Redo" action: NULL keyEquivalent: @"Z"];
      [_editMenu addItem: [NSMenuItem separatorItem]];
      [_editMenu addItemWithTitle: @"Find" action: NULL keyEquivalent: @"f"];

      [fileItem setSubmenu: _fileMenu];
      [editItem setSubmenu: _editMenu];

      cell = [[[NSMenuItemCell alloc] initTextCell: @""] autorelease];
      [cell setMenuItem: fileItem];
      [cell setFont: [NSFont systemFontOfSize: 13.0]];
      [_cells addObject: cell];

      cell = [[[NSMenuItemCell alloc] initTextCell: @""] autorelease];
      [cell setMenuItem: editItem];
      [cell setFont: [NSFont systemFontOfSize: 13.0]];
      [_cells addObject: cell];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_cells);
  RELEASE(_fileMenu);
  RELEASE(_editMenu);
  [super dealloc];
}

- (BOOL) isFlipped
{
  return YES;
}

- (NSRect) rectForMenuItemAtIndex: (NSUInteger)index
{
  CGFloat x = 18.0;
  NSUInteger current = 0;

  for (current = 0; current < index; current++)
    {
      x += 52.0;
    }

  return NSMakeRect(x, 16.0, 52.0, 30.0);
}

- (NSUInteger) menuItemIndexAtPoint: (NSPoint)point
{
  NSUInteger index = 0;

  for (index = 0; index < [_cells count]; index++)
    {
      if (NSMouseInRect(point, [self rectForMenuItemAtIndex: index], [self isFlipped]))
        {
          return index;
        }
    }

  return NSNotFound;
}

- (void) drawRect: (NSRect)dirtyRect
{
  GSTheme *theme = [GSTheme theme];
  NSUInteger index = 0;

  (void)dirtyRect;

  for (index = 0; index < [_cells count]; index++)
    {
      NSMenuItemCell *cell = [_cells objectAtIndex: index];
      NSRect itemRect = [self rectForMenuItemAtIndex: index];

      [theme drawBorderAndBackgroundForMenuItemCell: cell
                                          withFrame: itemRect
                                             inView: self
                                              state: GSThemeNormalState
                                       isHorizontal: YES];
      [theme drawTitleForMenuItemCell: cell
                             withFrame: itemRect
                                inView: self
                                 state: GSThemeNormalState
                          isHorizontal: YES];
    }
}

- (void) mouseDown: (NSEvent *)event
{
  NSPoint point = [self convertPoint: [event locationInWindow] fromView: nil];
  NSUInteger index = [self menuItemIndexAtPoint: point];
  NSMenu *menu = nil;

  if (index == NSNotFound)
    {
      [super mouseDown: event];
      return;
    }

  menu = (index == 0) ? _fileMenu : _editMenu;
  [NSMenu popUpContextMenu: menu withEvent: event forView: self];
}

@end

static NSString *
TDStringOrEmpty(id value)
{
  if ([value isKindOfClass: [NSString class]])
    {
      return (NSString *)value;
    }
  return @"";
}

static NSTextField *
TDLabel(NSString *string, NSRect frame, NSFont *font, NSColor *color)
{
  NSTextField *label = [[[NSTextField alloc] initWithFrame: frame] autorelease];

  [label setEditable: NO];
  [label setSelectable: NO];
  /* NSTextField is bezeled by default: without this every label drew as
     an empty text field. */
  [label setBezeled: NO];
  [label setBordered: NO];
  [label setDrawsBackground: NO];
  [label setStringValue: string != nil ? string : @""];
  if (font != nil)
    {
      [label setFont: font];
    }
  if (color != nil)
    {
      [label setTextColor: color];
    }

  return label;
}

static NSButton *
TDButton(NSString *title, NSRect frame, NSButtonType type, int bezelStyle)
{
  NSButton *button = [[[NSButton alloc] initWithFrame: frame] autorelease];

  [button setTitle: title];
  [button setButtonType: type];
  [button setBezelStyle: bezelStyle];

  return button;
}

static NSTextField *
TDTextField(NSString *value, NSRect frame)
{
  NSTextField *field = [[[NSTextField alloc] initWithFrame: frame] autorelease];

  [field setStringValue: value != nil ? value : @""];
  [field setBezeled: YES];
  [field setBordered: YES];

  return field;
}

static NSTextField *
TDReadOnlyField(NSString *value, NSRect frame)
{
  NSTextField *field = TDTextField(value, frame);

  [field setEditable: NO];
  [field setSelectable: NO];
  return field;
}

static NSSearchField *
TDSearchField(NSString *value, NSRect frame)
{
  NSSearchField *field = [[[NSSearchField alloc] initWithFrame: frame] autorelease];

  [field setStringValue: value != nil ? value : @""];
  return field;
}

static NSPopUpButton *
TDPopup(NSRect frame, NSArray *items)
{
  NSPopUpButton *button = [[[NSPopUpButton alloc] initWithFrame: frame pullsDown: NO] autorelease];
  NSEnumerator *enumerator = [items objectEnumerator];
  NSString *title = nil;

  while ((title = [enumerator nextObject]) != nil)
    {
      [button addItemWithTitle: title];
    }

  return button;
}

static NSComboBox *
TDComboBox(NSRect frame, NSArray *items, BOOL editable)
{
  NSComboBox *combo = [[[NSComboBox alloc] initWithFrame: frame] autorelease];

  [combo addItemsWithObjectValues: items];
  [combo setEditable: editable];
  if ([items count] > 0)
    {
      [combo selectItemAtIndex: 0];
    }

  return combo;
}

static NSSegmentedControl *
TDSegmentedControl(NSRect frame, NSArray *labels)
{
  NSSegmentedControl *control = [[[NSSegmentedControl alloc] initWithFrame: frame] autorelease];
  NSUInteger index = 0;

  [control setSegmentCount: [labels count]];
  if ([control respondsToSelector: @selector(setTrackingMode:)])
    {
      [(id)control setTrackingMode: NSSegmentSwitchTrackingSelectOne];
    }
  else if ([[control cell] respondsToSelector: @selector(setTrackingMode:)])
    {
      [(id)[control cell] setTrackingMode: NSSegmentSwitchTrackingSelectOne];
    }
  for (index = 0; index < [labels count]; index++)
    {
      [control setLabel: [labels objectAtIndex: index] forSegment: index];
    }
  [control setSelectedSegment: 0];

  return control;
}

/* A 20x20 monochrome glyph, drawn in black as an app's template icons
   are, and named "...Template" (Cocoa's convention) so a theme can tint
   it: "plus", "folder", "disk", "share", "gear". */
static NSImage *
TDGlyphImage(NSString *glyph)
{
  NSString *name = [NSString stringWithFormat: @"TD%@Template", [glyph capitalizedString]];
  NSImage *image = [NSImage imageNamed: name];
  NSBezierPath *path = nil;

  if (image != nil)
    {
      return image;
    }
  image = [[[NSImage alloc] initWithSize: NSMakeSize(20.0, 20.0)] autorelease];
  [image lockFocus];
  [[NSColor blackColor] set];
  path = [NSBezierPath bezierPath];
  [path setLineWidth: 1.6];
  [path setLineCapStyle: NSRoundLineCapStyle];
  [path setLineJoinStyle: NSRoundLineJoinStyle];
  if ([glyph isEqualToString: @"plus"])
    {
      [path moveToPoint: NSMakePoint(10.0, 3.0)];
      [path lineToPoint: NSMakePoint(10.0, 17.0)];
      [path moveToPoint: NSMakePoint(3.0, 10.0)];
      [path lineToPoint: NSMakePoint(17.0, 10.0)];
    }
  else if ([glyph isEqualToString: @"folder"])
    {
      [path moveToPoint: NSMakePoint(2.5, 4.0)];
      [path lineToPoint: NSMakePoint(2.5, 16.0)];
      [path lineToPoint: NSMakePoint(8.0, 16.0)];
      [path lineToPoint: NSMakePoint(10.0, 14.0)];
      [path lineToPoint: NSMakePoint(17.5, 14.0)];
      [path lineToPoint: NSMakePoint(17.5, 4.0)];
      [path closePath];
    }
  else if ([glyph isEqualToString: @"disk"])
    {
      [path appendBezierPathWithRect: NSMakeRect(3.0, 3.0, 14.0, 14.0)];
      [path appendBezierPathWithRect: NSMakeRect(6.0, 11.0, 8.0, 6.0)];
      [path appendBezierPathWithRect: NSMakeRect(6.0, 3.0, 8.0, 4.5)];
    }
  else if ([glyph isEqualToString: @"share"])
    {
      [path moveToPoint: NSMakePoint(10.0, 4.0)];
      [path lineToPoint: NSMakePoint(10.0, 16.0)];
      [path moveToPoint: NSMakePoint(6.0, 12.5)];
      [path lineToPoint: NSMakePoint(10.0, 16.5)];
      [path lineToPoint: NSMakePoint(14.0, 12.5)];
      [path moveToPoint: NSMakePoint(4.0, 8.0)];
      [path lineToPoint: NSMakePoint(4.0, 3.0)];
      [path lineToPoint: NSMakePoint(16.0, 3.0)];
      [path lineToPoint: NSMakePoint(16.0, 8.0)];
    }
  else
    {
      [path appendBezierPathWithOvalInRect: NSMakeRect(6.5, 6.5, 7.0, 7.0)];
      [path appendBezierPathWithOvalInRect: NSMakeRect(3.0, 3.0, 14.0, 14.0)];
    }
  [path stroke];
  [image unlockFocus];
  [image setName: name];
  if ([image respondsToSelector: @selector(setTemplate:)])
    {
      [(id)image setTemplate: YES];
    }
  return image;
}

static NSView *
TDMenuBarFixture(NSRect frame)
{
  NSBox *box = [[[NSBox alloc] initWithFrame: frame] autorelease];
  NSView *menuView = nil;

  [box setTitlePosition: NSNoTitle];

  menuView = [[[TDMenuBarFixtureView alloc] initWithFrame: NSMakeRect(18.0, 8.0, 260.0, 62.0)] autorelease];
  [[box contentView] addSubview: menuView];

  return box;
}

@interface TDAppDelegate ()
- (void) installMainMenu;
- (void) buildWindow;
- (void) populatePageSelector;
- (NSString *) requestedPageIDFromArguments;
- (NSString *) requestedCapturePathFromArguments;
- (void) applyRequestedPageSelectionIfNeeded;
- (void) captureAndTerminateIfRequested;
- (NSDictionary *) selectedPage;
- (void) updateDisplayedPage;
- (NSView *) documentViewForPage: (NSDictionary *)page;
- (NSView *) controlsPageViewForPage: (NSDictionary *)page;
- (NSView *) textInputPageViewForPage: (NSDictionary *)page;
- (NSView *) commandsPageViewForPage: (NSDictionary *)page;
- (NSView *) dataViewsPageViewForPage: (NSDictionary *)page;
- (NSView *) dialogsPageViewForPage: (NSDictionary *)page;
- (NSView *) stressPageViewForPage: (NSDictionary *)page;
- (NSView *) realAppPageViewForPage: (NSDictionary *)page;
- (NSView *) surfacesPageViewForPage: (NSDictionary *)page;
- (NSView *) placeholderPageViewForPage: (NSDictionary *)page;
- (NSToolbar *) windowToolbar;
- (void) showAlertDemo: (id)sender;
- (void) showAlertSheetDemo: (id)sender;
- (void) alertSheetDidEnd: (NSAlert *)alert
               returnCode: (NSInteger)returnCode
              contextInfo: (void *)contextInfo;
- (void) showSampleContextMenu: (id)sender;
- (void) openPanelDemo: (id)sender;
- (void) savePanelDemo: (id)sender;
- (void) printPanelDemo: (id)sender;
- (void) pageLayoutDemo: (id)sender;
@end

@implementation TDAppDelegate

- (void) dealloc
{
  RELEASE(_contract);
  RELEASE(_pages);
  RELEASE(_tableRows);
  RELEASE(_outlineRows);
  RELEASE(_pageTitleLabel);
  RELEASE(_pageDescriptionLabel);
  RELEASE(_requestedPageID);
  RELEASE(_requestedCapturePath);
  RELEASE(_lastOpenPanelResult);
  RELEASE(_lastSavePanelResult);
  RELEASE(_lastPrintPanelResult);
  RELEASE(_lastPageLayoutResult);
  RELEASE(_lastAlertResult);
  RELEASE(_window);
  [super dealloc];
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)sender
{
  (void)sender;
  return YES;
}

- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
  NSError *error = nil;

  (void)notification;

  _contract = [[TDContractLoader contractFromMainBundle: &error] retain];
  if (_contract == nil)
    {
      NSRunAlertPanel(@"ThemeDemo Error",
                      [error localizedDescription],
                      @"Quit",
                      nil,
                      nil);
      [NSApp terminate: self];
      return;
    }

  _pages = [[_contract objectForKey: @"pages"] retain];
  ASSIGNCOPY(_requestedPageID, [self requestedPageIDFromArguments]);
  ASSIGNCOPY(_requestedCapturePath, [self requestedCapturePathFromArguments]);
  _tableRows = [[NSArray alloc] initWithObjects:
                 [NSDictionary dictionaryWithObjectsAndKeys:
                   @"README.md", @"name",
                   @"1.4 KB", @"size",
                   @"Modified 8 min ago", @"status",
                   nil],
                 [NSDictionary dictionaryWithObjectsAndKeys:
                   @"docs/roadmap.md", @"name",
                   @"7.2 KB", @"size",
                   @"Modified 23 min ago", @"status",
                   nil],
                 [NSDictionary dictionaryWithObjectsAndKeys:
                   @"Sources/AppController.m", @"name",
                   @"12.8 KB", @"size",
                   @"Active selection", @"status",
                   nil],
                 [NSDictionary dictionaryWithObjectsAndKeys:
                   @"Examples/ThemeDemo", @"name",
                   @"Folder", @"size",
                   @"Pending review", @"status",
                   nil],
                 nil];
  _outlineRows = [[NSArray alloc] initWithObjects:
                   [NSDictionary dictionaryWithObjectsAndKeys:
                     @"Workspace", @"title",
                     [NSArray arrayWithObjects:
                       [NSDictionary dictionaryWithObjectsAndKeys:
                         @"Sources", @"title",
                         [NSArray arrayWithObjects:
                           [NSDictionary dictionaryWithObjectsAndKeys: @"AppController.m", @"title", nil],
                           [NSDictionary dictionaryWithObjectsAndKeys: @"PreviewController.m", @"title", nil],
                           nil],
                         @"children",
                         nil],
                       [NSDictionary dictionaryWithObjectsAndKeys:
                         @"Documentation", @"title",
                         [NSArray arrayWithObjects:
                           [NSDictionary dictionaryWithObjectsAndKeys: @"IMPLEMENTATION_ROADMAP.md", @"title", nil],
                           [NSDictionary dictionaryWithObjectsAndKeys: @"NATIVE_INTEGRATION_AND_BOUNDARIES.md", @"title", nil],
                           nil],
                         @"children",
                         nil],
                       nil],
                     @"children",
                     nil],
                   [NSDictionary dictionaryWithObjectsAndKeys:
                     @"Recent Files", @"title",
                     [NSArray arrayWithObjects:
                       [NSDictionary dictionaryWithObjectsAndKeys: @"Quarterly Plan.md", @"title", nil],
                       [NSDictionary dictionaryWithObjectsAndKeys: @"Release Notes.txt", @"title", nil],
                       nil],
                     @"children",
                     nil],
                   nil];
  ASSIGN(_lastOpenPanelResult, @"No selection yet");
  ASSIGN(_lastSavePanelResult, @"No path chosen yet");
  ASSIGN(_lastPrintPanelResult, @"Dialog not shown yet");
  ASSIGN(_lastPageLayoutResult, @"Dialog not shown yet");
  ASSIGN(_lastAlertResult, @"No alert shown yet");
  [self installMainMenu];
  [self buildWindow];
  [self populatePageSelector];
  [self applyRequestedPageSelectionIfNeeded];
  [self updateDisplayedPage];
  [_window makeKeyAndOrderFront: nil];
  [_window display];
  if ([_requestedCapturePath length] > 0)
    {
      [self captureAndTerminateIfRequested];
    }
}

- (void) installMainMenu
{
  NSMenu *mainMenu = [[[NSMenu alloc] initWithTitle: @"MainMenu"] autorelease];
  NSMenu *fileMenu = [[[NSMenu alloc] initWithTitle: @"File"] autorelease];
  NSMenu *editMenu = [[[NSMenu alloc] initWithTitle: @"Edit"] autorelease];
  NSMenu *viewMenu = [[[NSMenu alloc] initWithTitle: @"View"] autorelease];
  NSMenu *helpMenu = [[[NSMenu alloc] initWithTitle: @"Help"] autorelease];
  NSMenuItem *rootItem = nil;
  NSMenuItem *item = nil;

  rootItem = [[[NSMenuItem alloc] initWithTitle: @"File" action: NULL keyEquivalent: @""] autorelease];
  [rootItem setSubmenu: fileMenu];
  [mainMenu addItem: rootItem];

  item = [[[NSMenuItem alloc] initWithTitle: @"Open..." action: NULL keyEquivalent: @"o"] autorelease];
  [item setKeyEquivalentModifierMask: NSCommandKeyMask];
  [fileMenu addItem: item];
  item = [[[NSMenuItem alloc] initWithTitle: @"Save" action: NULL keyEquivalent: @"s"] autorelease];
  [item setKeyEquivalentModifierMask: NSCommandKeyMask];
  [fileMenu addItem: item];
  [fileMenu addItem: [NSMenuItem separatorItem]];
  item = [[[NSMenuItem alloc] initWithTitle: @"Export" action: NULL keyEquivalent: @""] autorelease];
  [item setState: NSOnState];
  [fileMenu addItem: item];

  rootItem = [[[NSMenuItem alloc] initWithTitle: @"Edit" action: NULL keyEquivalent: @""] autorelease];
  [rootItem setSubmenu: editMenu];
  [mainMenu addItem: rootItem];

  item = [[[NSMenuItem alloc] initWithTitle: @"Undo" action: NULL keyEquivalent: @"z"] autorelease];
  [item setKeyEquivalentModifierMask: NSCommandKeyMask];
  [editMenu addItem: item];
  item = [[[NSMenuItem alloc] initWithTitle: @"Find in Document" action: NULL keyEquivalent: @"f"] autorelease];
  [item setKeyEquivalentModifierMask: NSCommandKeyMask];
  [editMenu addItem: item];

  rootItem = [[[NSMenuItem alloc] initWithTitle: @"View" action: NULL keyEquivalent: @""] autorelease];
  [rootItem setSubmenu: viewMenu];
  [mainMenu addItem: rootItem];

  item = [[[NSMenuItem alloc] initWithTitle: @"Preview Mode" action: NULL keyEquivalent: @"1"] autorelease];
  [item setKeyEquivalentModifierMask: NSCommandKeyMask];
  [viewMenu addItem: item];
  item = [[[NSMenuItem alloc] initWithTitle: @"Inspector" action: NULL keyEquivalent: @""] autorelease];
  [item setState: NSMixedState];
  [viewMenu addItem: item];

  rootItem = [[[NSMenuItem alloc] initWithTitle: @"Help" action: NULL keyEquivalent: @""] autorelease];
  [rootItem setSubmenu: helpMenu];
  [mainMenu addItem: rootItem];
  [helpMenu addItemWithTitle: @"Theme Review Notes" action: NULL keyEquivalent: @"?"];

  [NSApp setMainMenu: mainMenu];
}

- (void) buildWindow
{
  NSRect frame = NSMakeRect(0.0, 0.0, 1120.0, 840.0);
  NSView *contentView = nil;

  _window = [[NSWindow alloc]
    initWithContentRect: frame
              styleMask: (NSTitledWindowMask
                          | NSClosableWindowMask
                          | NSMiniaturizableWindowMask
                          | NSResizableWindowMask)
                backing: NSBackingStoreBuffered
                  defer: NO];
  [_window setTitle: @"ThemeDemo"];
  [_window setToolbar: [self windowToolbar]];
  [_window center];
  [_window setMinSize: NSMakeSize(860.0, 640.0)];

  contentView = [_window contentView];

  [contentView addSubview: TDLabel(@"Review Page:",
                                   NSMakeRect(20.0, 794.0, 110.0, 24.0),
                                   [NSFont boldSystemFontOfSize: 13.0],
                                   [NSColor controlTextColor])];

  _pageSelector = [[[NSPopUpButton alloc] initWithFrame: NSMakeRect(128.0, 790.0, 320.0, 30.0)
                                               pullsDown: NO] autorelease];
  [_pageSelector setTarget: self];
  [_pageSelector setAction: @selector(pageSelectionDidChange:)];
  [_pageSelector setAutoresizingMask: NSViewMinYMargin];
  [contentView addSubview: _pageSelector];

  _pageTitleLabel = [TDLabel(@"",
                             NSMakeRect(20.0, 754.0, 640.0, 28.0),
                             [NSFont boldSystemFontOfSize: 22.0],
                             [NSColor controlTextColor]) retain];
  [_pageTitleLabel setAutoresizingMask: (NSViewWidthSizable | NSViewMinYMargin)];
  [contentView addSubview: _pageTitleLabel];

  _pageDescriptionLabel = [TDLabel(@"",
                                   NSMakeRect(20.0, 730.0, 960.0, 20.0),
                                   [NSFont systemFontOfSize: 13.0],
                                   [NSColor secondaryLabelColor]) retain];
  [_pageDescriptionLabel setAutoresizingMask: (NSViewWidthSizable | NSViewMinYMargin)];
  [contentView addSubview: _pageDescriptionLabel];

  _scrollView = [[[NSScrollView alloc] initWithFrame: NSMakeRect(20.0, 20.0, 1080.0, 694.0)] autorelease];
  [_scrollView setHasVerticalScroller: YES];
  [_scrollView setHasHorizontalScroller: NO];
  [_scrollView setBorderType: NSNoBorder];
  [_scrollView setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];
  [contentView addSubview: _scrollView];
}

- (void) populatePageSelector
{
  NSUInteger i = 0;

  [_pageSelector removeAllItems];
  for (i = 0; i < [_pages count]; i++)
    {
      NSDictionary *page = [_pages objectAtIndex: i];
      NSString *title = TDStringOrEmpty([page objectForKey: @"title"]);
      NSString *pageID = TDStringOrEmpty([page objectForKey: @"id"]);

      if ([title length] == 0)
        {
          title = pageID;
        }

      [_pageSelector addItemWithTitle: title];
      [[_pageSelector lastItem] setRepresentedObject: pageID];
    }
}

- (NSString *) requestedPageIDFromArguments
{
  NSArray *arguments = [[NSProcessInfo processInfo] arguments];
  NSUInteger i = 1;

  while (i < [arguments count])
    {
      NSString *argument = [arguments objectAtIndex: i];
      NSString *nextValue = (i + 1 < [arguments count])
        ? [arguments objectAtIndex: i + 1]
        : nil;

      if ([argument isEqualToString: @"--page"] && [nextValue length] > 0)
        {
          return nextValue;
        }

      i += 1;
    }

  return nil;
}

- (NSString *) requestedCapturePathFromArguments
{
  NSArray *arguments = [[NSProcessInfo processInfo] arguments];
  NSUInteger i = 1;

  while (i < [arguments count])
    {
      NSString *argument = [arguments objectAtIndex: i];
      NSString *nextValue = (i + 1 < [arguments count])
        ? [arguments objectAtIndex: i + 1]
        : nil;

      if ([argument isEqualToString: @"--capture-path"] && [nextValue length] > 0)
        {
          return nextValue;
        }

      i += 1;
    }

  return nil;
}

- (void) applyRequestedPageSelectionIfNeeded
{
  NSInteger itemCount = [_pageSelector numberOfItems];
  NSInteger index = 0;

  if ([_requestedPageID length] == 0)
    {
      return;
    }

  for (index = 0; index < itemCount; index++)
    {
      id item = [_pageSelector itemAtIndex: index];
      NSString *pageID = TDStringOrEmpty([item representedObject]);

      if ([pageID isEqualToString: _requestedPageID])
        {
          [_pageSelector selectItemAtIndex: index];
          return;
        }
    }
}

- (void) captureAndTerminateIfRequested
{
  NSView *contentView = [_window contentView];
  NSRect bounds = [contentView bounds];
  NSBitmapImageRep *bitmap = nil;
  NSData *pngData = nil;
  NSString *directory = nil;
  NSString *failurePath = nil;
  NSString *failureMessage = nil;

  if ([_requestedCapturePath length] == 0 || contentView == nil)
    {
      return;
    }

  [contentView lockFocus];
  bitmap = [[[NSBitmapImageRep alloc] initWithFocusedViewRect: bounds] autorelease];
  [contentView unlockFocus];
  if (bitmap != nil)
    {
      pngData = [bitmap representationUsingType: NSPNGFileType
                                     properties: [NSDictionary dictionary]];
    }

  directory = [_requestedCapturePath stringByDeletingLastPathComponent];
  if ([directory length] > 0)
    {
      [[NSFileManager defaultManager] createDirectoryAtPath: directory
                                withIntermediateDirectories: YES
                                                 attributes: nil
                                                      error: NULL];
    }

  if ([pngData length] > 0)
    {
      [pngData writeToFile: _requestedCapturePath atomically: YES];
    }
  else
    {
      failurePath = [[_requestedCapturePath stringByDeletingPathExtension]
        stringByAppendingString: @"-capture-error.txt"];
      failureMessage = @"ThemeDemo capture failed to produce PNG data.";
      [failureMessage writeToFile: failurePath
                       atomically: YES
                         encoding: NSUTF8StringEncoding
                            error: NULL];
    }

  [NSApp terminate: self];
}

- (NSDictionary *) selectedPage
{
  NSString *pageID = [[[_pageSelector selectedItem] representedObject] description];
  NSUInteger i = 0;

  for (i = 0; i < [_pages count]; i++)
    {
      NSDictionary *page = [_pages objectAtIndex: i];

      if ([[page objectForKey: @"id"] isEqual: pageID])
        {
          return page;
        }
    }

  return ([_pages count] > 0) ? [_pages objectAtIndex: 0] : nil;
}

- (NSView *) controlsPageViewForPage: (NSDictionary *)page
{
  TDFlippedView *view = [[[TDFlippedView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 1040.0, 820.0)] autorelease];
  NSFont *sectionFont = [NSFont boldSystemFontOfSize: 15.0];
  NSFont *captionFont = [NSFont systemFontOfSize: 12.0];
  NSButton *button = nil;
  NSButton *radio = nil;
  NSSlider *slider = nil;
  NSProgressIndicator *progress = nil;
  NSStepper *stepper = nil;
  NSSwitch *toggle = nil;

  [view addSubview: TDLabel(TDStringOrEmpty([page objectForKey: @"title"]),
                            NSMakeRect(20.0, 12.0, 320.0, 22.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  [view addSubview: TDLabel(@"Buttons",
                            NSMakeRect(20.0, 58.0, 240.0, 20.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  button = TDButton(@"Save", NSMakeRect(20.0, 88.0, 120.0, 34.0), NSMomentaryPushInButton, NSRoundedBezelStyle);
  [button setKeyEquivalent: @"\r"];
  [view addSubview: button];
  [view addSubview: TDLabel(@"Default button", NSMakeRect(20.0, 126.0, 120.0, 18.0), captionFont, [NSColor secondaryLabelColor])];

  button = TDButton(@"Cancel", NSMakeRect(164.0, 88.0, 120.0, 34.0), NSMomentaryPushInButton, NSRoundedBezelStyle);
  [view addSubview: button];
  [view addSubview: TDLabel(@"Normal button", NSMakeRect(164.0, 126.0, 120.0, 18.0), captionFont, [NSColor secondaryLabelColor])];

  button = TDButton(@"Disabled", NSMakeRect(308.0, 88.0, 120.0, 34.0), NSMomentaryPushInButton, NSRoundedBezelStyle);
  [button setEnabled: NO];
  [view addSubview: button];
  [view addSubview: TDLabel(@"Disabled button", NSMakeRect(308.0, 126.0, 120.0, 18.0), captionFont, [NSColor secondaryLabelColor])];

  [view addSubview: TDLabel(@"Selection Controls",
                            NSMakeRect(20.0, 176.0, 240.0, 20.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  button = TDButton(@"Checked", NSMakeRect(20.0, 206.0, 180.0, 24.0), NSSwitchButton, NSRoundedBezelStyle);
  [button setState: NSOnState];
  [view addSubview: button];
  button = TDButton(@"Mixed", NSMakeRect(20.0, 236.0, 180.0, 24.0), NSSwitchButton, NSRoundedBezelStyle);
  [button setAllowsMixedState: YES];
  [button setState: NSMixedState];
  [view addSubview: button];
  button = TDButton(@"Disabled", NSMakeRect(20.0, 266.0, 180.0, 24.0), NSSwitchButton, NSRoundedBezelStyle);
  [button setEnabled: NO];
  [view addSubview: button];

  radio = TDButton(@"Option A", NSMakeRect(250.0, 206.0, 180.0, 24.0), NSRadioButton, NSRoundedBezelStyle);
  [radio setState: NSOnState];
  [view addSubview: radio];
  radio = TDButton(@"Option B", NSMakeRect(250.0, 236.0, 180.0, 24.0), NSRadioButton, NSRoundedBezelStyle);
  [view addSubview: radio];
  radio = TDButton(@"Disabled", NSMakeRect(250.0, 266.0, 180.0, 24.0), NSRadioButton, NSRoundedBezelStyle);
  [radio setEnabled: NO];
  [view addSubview: radio];

  toggle = [[[NSSwitch alloc] initWithFrame: NSMakeRect(500.0, 204.0, 44.0, 28.0)] autorelease];
  [toggle setState: NSControlStateValueOn];
  [view addSubview: toggle];
  [view addSubview: TDLabel(@"On", NSMakeRect(552.0, 208.0, 80.0, 20.0), nil, [NSColor controlTextColor])];

  toggle = [[[NSSwitch alloc] initWithFrame: NSMakeRect(500.0, 236.0, 44.0, 28.0)] autorelease];
  [view addSubview: toggle];
  [view addSubview: TDLabel(@"Off", NSMakeRect(552.0, 240.0, 80.0, 20.0), nil, [NSColor controlTextColor])];

  toggle = [[[NSSwitch alloc] initWithFrame: NSMakeRect(500.0, 268.0, 44.0, 28.0)] autorelease];
  [toggle setEnabled: NO];
  [view addSubview: toggle];
  [view addSubview: TDLabel(@"Disabled", NSMakeRect(552.0, 272.0, 80.0, 20.0), nil, [NSColor secondaryLabelColor])];

  [view addSubview: TDLabel(@"Range Controls",
                            NSMakeRect(20.0, 336.0, 240.0, 20.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  slider = [[[NSSlider alloc] initWithFrame: NSMakeRect(20.0, 368.0, 340.0, 24.0)] autorelease];
  [slider setMinValue: 0.0];
  [slider setMaxValue: 100.0];
  [slider setDoubleValue: 64.0];
  [view addSubview: slider];
  [view addSubview: TDLabel(@"Slider", NSMakeRect(20.0, 394.0, 180.0, 18.0), captionFont, [NSColor secondaryLabelColor])];

  progress = [[[NSProgressIndicator alloc] initWithFrame: NSMakeRect(20.0, 436.0, 340.0, 18.0)] autorelease];
  [progress setIndeterminate: NO];
  [progress setDoubleValue: 68.0];
  [progress setMaxValue: 100.0];
  [progress setBezeled: YES];
  [view addSubview: progress];
  [view addSubview: TDLabel(@"Determinate progress", NSMakeRect(20.0, 458.0, 180.0, 18.0), captionFont, [NSColor secondaryLabelColor])];

  progress = [[[NSProgressIndicator alloc] initWithFrame: NSMakeRect(20.0, 496.0, 340.0, 18.0)] autorelease];
  [progress setIndeterminate: YES];
  [progress setStyle: NSProgressIndicatorBarStyle];
  [progress setUsesThreadedAnimation: NO];
  [progress startAnimation: nil];
  [view addSubview: progress];
  [view addSubview: TDLabel(@"Indeterminate progress", NSMakeRect(20.0, 518.0, 180.0, 18.0), captionFont, [NSColor secondaryLabelColor])];

  stepper = [[[NSStepper alloc] initWithFrame: NSMakeRect(420.0, 366.0, 22.0, 42.0)] autorelease];
  [stepper setMinValue: 0.0];
  [stepper setMaxValue: 10.0];
  [stepper setDoubleValue: 4.0];
  [view addSubview: stepper];
  [view addSubview: TDLabel(@"Stepper", NSMakeRect(456.0, 378.0, 120.0, 18.0), captionFont, [NSColor secondaryLabelColor])];

  return view;
}

- (NSView *) textInputPageViewForPage: (NSDictionary *)page
{
  TDFlippedView *view = [[[TDFlippedView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 1040.0, 760.0)] autorelease];
  NSFont *sectionFont = [NSFont boldSystemFontOfSize: 15.0];
  NSFont *captionFont = [NSFont systemFontOfSize: 12.0];
  NSTextField *field = nil;
  NSSearchField *search = nil;
  NSPopUpButton *popup = nil;
  NSComboBox *combo = nil;
  NSSegmentedControl *segments = nil;

  [view addSubview: TDLabel(TDStringOrEmpty([page objectForKey: @"title"]),
                            NSMakeRect(20.0, 12.0, 320.0, 22.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  [view addSubview: TDLabel(@"Fields",
                            NSMakeRect(20.0, 58.0, 240.0, 20.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  field = TDTextField(@"Quarterly planning memo.md", NSMakeRect(20.0, 90.0, 360.0, 30.0));
  [view addSubview: field];
  [view addSubview: TDLabel(@"Text field", NSMakeRect(20.0, 124.0, 120.0, 18.0), captionFont, [NSColor secondaryLabelColor])];

  search = TDSearchField(@"Find in document", NSMakeRect(20.0, 166.0, 360.0, 30.0));
  [view addSubview: search];
  [view addSubview: TDLabel(@"Search field", NSMakeRect(20.0, 200.0, 120.0, 18.0), captionFont, [NSColor secondaryLabelColor])];

  field = TDTextField(@"Read-only diagnostics", NSMakeRect(20.0, 242.0, 360.0, 30.0));
  [field setEditable: NO];
  [field setSelectable: NO];
  [field setEnabled: NO];
  [view addSubview: field];
  [view addSubview: TDLabel(@"Disabled field", NSMakeRect(20.0, 276.0, 120.0, 18.0), captionFont, [NSColor secondaryLabelColor])];

  [view addSubview: TDLabel(@"Compound Inputs",
                            NSMakeRect(20.0, 336.0, 240.0, 20.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  popup = TDPopup(NSMakeRect(20.0, 368.0, 240.0, 30.0),
                  [NSArray arrayWithObjects: @"Heading 1", @"Heading 2", @"Heading 3", nil]);
  [view addSubview: popup];
  [view addSubview: TDLabel(@"Popup button", NSMakeRect(20.0, 402.0, 120.0, 18.0), captionFont, [NSColor secondaryLabelColor])];

  combo = TDComboBox(NSMakeRect(20.0, 442.0, 240.0, 30.0),
                     [NSArray arrayWithObjects: @"CommonMark", @"GitHub Flavored", @"Pandoc", nil],
                     NO);
  [view addSubview: combo];
  [view addSubview: TDLabel(@"Combo box", NSMakeRect(20.0, 476.0, 120.0, 18.0), captionFont, [NSColor secondaryLabelColor])];

  segments = TDSegmentedControl(NSMakeRect(20.0, 520.0, 300.0, 30.0),
                                [NSArray arrayWithObjects: @"Write", @"Preview", @"Split", nil]);
  [view addSubview: segments];
  [view addSubview: TDLabel(@"Segmented control", NSMakeRect(20.0, 554.0, 140.0, 18.0), captionFont, [NSColor secondaryLabelColor])];

  return view;
}

- (NSView *) commandsPageViewForPage: (NSDictionary *)page
{
  TDFlippedView *view = [[[TDFlippedView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 1040.0, 760.0)] autorelease];
  NSFont *sectionFont = [NSFont boldSystemFontOfSize: 15.0];
  NSView *menuFixture = nil;
  NSBox *toolbarBox = nil;
  NSButton *button = nil;
  NSPopUpButton *popup = nil;
  NSSegmentedControl *segments = nil;

  [view addSubview: TDLabel(TDStringOrEmpty([page objectForKey: @"title"]),
                            NSMakeRect(20.0, 12.0, 320.0, 22.0),
                            sectionFont,
                            [NSColor controlTextColor])];
  [view addSubview: TDLabel(@"The application menu bar is live. Open File/Edit/View above to review top-level menu spacing, states, and key equivalents.",
                            NSMakeRect(20.0, 44.0, 920.0, 20.0),
                            [NSFont systemFontOfSize: 13.0],
                            [NSColor secondaryLabelColor])];

  [view addSubview: TDLabel(@"Menu Bar",
                            NSMakeRect(20.0, 92.0, 320.0, 20.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  menuFixture = TDMenuBarFixture(NSMakeRect(20.0, 122.0, 820.0, 78.0));
  [view addSubview: menuFixture];

  [view addSubview: TDLabel(@"Toolbar-Like Command Surfaces",
                            NSMakeRect(20.0, 240.0, 320.0, 20.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  toolbarBox = [[[NSBox alloc] initWithFrame: NSMakeRect(20.0, 270.0, 820.0, 78.0)] autorelease];
  [toolbarBox setTitlePosition: NSNoTitle];
  [view addSubview: toolbarBox];

  button = TDButton(@"New", NSMakeRect(18.0, 22.0, 92.0, 32.0), NSMomentaryPushInButton, NSRoundedBezelStyle);
  [[toolbarBox contentView] addSubview: button];
  button = TDButton(@"Save", NSMakeRect(120.0, 22.0, 92.0, 32.0), NSMomentaryPushInButton, NSRoundedBezelStyle);
  [[toolbarBox contentView] addSubview: button];
  button = TDButton(@"Share", NSMakeRect(222.0, 22.0, 92.0, 32.0), NSMomentaryPushInButton, NSRoundedBezelStyle);
  [[toolbarBox contentView] addSubview: button];

  segments = TDSegmentedControl(NSMakeRect(332.0, 22.0, 220.0, 32.0),
                                [NSArray arrayWithObjects: @"Write", @"Preview", @"Split", nil]);
  [[toolbarBox contentView] addSubview: segments];

  popup = TDPopup(NSMakeRect(570.0, 22.0, 210.0, 32.0),
                  [NSArray arrayWithObjects: @"Heading 1", @"Heading 2", @"Block Quote", nil]);
  [[toolbarBox contentView] addSubview: popup];

  [view addSubview: TDLabel(@"Menus",
                            NSMakeRect(20.0, 388.0, 240.0, 20.0),
                            sectionFont,
                            [NSColor controlTextColor])];
  [view addSubview: TDLabel(@"Use the button below to open a themed context menu with a checked item, submenu, disabled item, and visible shortcuts.",
                            NSMakeRect(20.0, 418.0, 860.0, 20.0),
                            [NSFont systemFontOfSize: 13.0],
                            [NSColor secondaryLabelColor])];

  button = TDButton(@"Show Context Menu",
                    NSMakeRect(20.0, 452.0, 180.0, 34.0),
                    NSMomentaryPushInButton,
                    NSRoundedBezelStyle);
  [button setTarget: self];
  [button setAction: @selector(showSampleContextMenu:)];
  [view addSubview: button];

  [view addSubview: TDLabel(@"Expected review points: menu bar density, menu row selection, separator weight, submenu arrow placement, and shortcut alignment.",
                            NSMakeRect(20.0, 504.0, 900.0, 20.0),
                            [NSFont systemFontOfSize: 13.0],
                            [NSColor secondaryLabelColor])];

  return view;
}

- (NSView *) dataViewsPageViewForPage: (NSDictionary *)page
{
  TDFlippedView *view = [[[TDFlippedView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 1040.0, 1060.0)] autorelease];
  NSFont *sectionFont = [NSFont boldSystemFontOfSize: 15.0];
  NSScrollView *scrollView = nil;
  NSTableView *tableView = nil;
  NSOutlineView *outlineView = nil;
  NSTableColumn *column = nil;
  NSTabView *tabView = nil;
  NSTabViewItem *tabItem = nil;
  NSTextView *textView = nil;
  NSSplitView *splitView = nil;
  NSBox *leftPane = nil;
  NSBox *rightPane = nil;

  [view addSubview: TDLabel(TDStringOrEmpty([page objectForKey: @"title"]),
                            NSMakeRect(20.0, 12.0, 320.0, 22.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  [view addSubview: TDLabel(@"Table View",
                            NSMakeRect(20.0, 58.0, 240.0, 20.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  scrollView = [[[NSScrollView alloc] initWithFrame: NSMakeRect(20.0, 88.0, 470.0, 238.0)] autorelease];
  [scrollView setBorderType: NSBezelBorder];
  [scrollView setHasVerticalScroller: YES];
  [scrollView setHasHorizontalScroller: NO];
  tableView = [[[NSTableView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 450.0, 220.0)] autorelease];
  [tableView setUsesAlternatingRowBackgroundColors: YES];
  [tableView setRowHeight: 30.0];
  [tableView setDelegate: self];
  [tableView setDataSource: self];

  column = [[[NSTableColumn alloc] initWithIdentifier: @"name"] autorelease];
  [[column headerCell] setStringValue: @"Name"];
  [column setWidth: 220.0];
  [tableView addTableColumn: column];
  column = [[[NSTableColumn alloc] initWithIdentifier: @"size"] autorelease];
  [[column headerCell] setStringValue: @"Size"];
  [column setWidth: 90.0];
  [tableView addTableColumn: column];
  column = [[[NSTableColumn alloc] initWithIdentifier: @"status"] autorelease];
  [[column headerCell] setStringValue: @"Status"];
  [column setWidth: 160.0];
  [tableView addTableColumn: column];

  [tableView reloadData];
  [tableView selectRowIndexes: [NSIndexSet indexSetWithIndex: 2] byExtendingSelection: NO];
  [scrollView setDocumentView: tableView];
  [view addSubview: scrollView];

  [view addSubview: TDLabel(@"Outline View",
                            NSMakeRect(540.0, 58.0, 240.0, 20.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  scrollView = [[[NSScrollView alloc] initWithFrame: NSMakeRect(540.0, 88.0, 420.0, 238.0)] autorelease];
  [scrollView setBorderType: NSBezelBorder];
  [scrollView setHasVerticalScroller: YES];
  outlineView = [[[NSOutlineView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 400.0, 220.0)] autorelease];
  [outlineView setUsesAlternatingRowBackgroundColors: YES];
  [outlineView setRowHeight: 30.0];
  [outlineView setDelegate: self];
  [outlineView setDataSource: self];
  column = [[[NSTableColumn alloc] initWithIdentifier: @"title"] autorelease];
  [[column headerCell] setStringValue: @"Project"];
  [column setWidth: 380.0];
  [outlineView addTableColumn: column];
  [outlineView setOutlineTableColumn: column];
  [outlineView reloadData];
  [outlineView expandItem: [_outlineRows objectAtIndex: 0]];
  [outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: 1] byExtendingSelection: NO];
  [scrollView setDocumentView: outlineView];
  [view addSubview: scrollView];

  [view addSubview: TDLabel(@"Tabs",
                            NSMakeRect(20.0, 366.0, 240.0, 20.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  tabView = [[[NSTabView alloc] initWithFrame: NSMakeRect(20.0, 396.0, 940.0, 240.0)] autorelease];
  tabItem = [[[NSTabViewItem alloc] initWithIdentifier: @"write"] autorelease];
  [tabItem setLabel: @"Write"];
  [tabItem setView: TDReadOnlyField(@"Markdown authoring surface", NSMakeRect(26.0, 28.0, 280.0, 28.0))];
  [tabView addTabViewItem: tabItem];
  tabItem = [[[NSTabViewItem alloc] initWithIdentifier: @"preview"] autorelease];
  [tabItem setLabel: @"Preview"];
  [tabItem setView: TDReadOnlyField(@"Rendered preview surface", NSMakeRect(26.0, 28.0, 280.0, 28.0))];
  [tabView addTabViewItem: tabItem];
  tabItem = [[[NSTabViewItem alloc] initWithIdentifier: @"history"] autorelease];
  [tabItem setLabel: @"History"];
  [tabItem setView: TDReadOnlyField(@"Revision timeline", NSMakeRect(26.0, 28.0, 280.0, 28.0))];
  [tabView addTabViewItem: tabItem];
  [view addSubview: tabView];

  [view addSubview: TDLabel(@"Split View And Scroll Surfaces",
                            NSMakeRect(20.0, 676.0, 320.0, 20.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  splitView = [[[NSSplitView alloc] initWithFrame: NSMakeRect(20.0, 706.0, 940.0, 280.0)] autorelease];
  [splitView setVertical: YES];
  [splitView setDividerStyle: NSSplitViewDividerStyleThin];

  leftPane = [[[NSBox alloc] initWithFrame: NSMakeRect(0.0, 0.0, 280.0, 280.0)] autorelease];
  [leftPane setTitlePosition: NSNoTitle];
  [[leftPane contentView] addSubview: TDLabel(@"Inspector", NSMakeRect(16.0, 16.0, 120.0, 20.0), sectionFont, [NSColor controlTextColor])];
  [[leftPane contentView] addSubview: TDReadOnlyField(@"Document statistics", NSMakeRect(16.0, 56.0, 220.0, 28.0))];
  [[leftPane contentView] addSubview: TDReadOnlyField(@"Theme acceptance notes", NSMakeRect(16.0, 92.0, 220.0, 28.0))];
  [splitView addSubview: leftPane];

  rightPane = [[[NSBox alloc] initWithFrame: NSMakeRect(280.0, 0.0, 660.0, 280.0)] autorelease];
  [rightPane setTitlePosition: NSNoTitle];
  scrollView = [[[NSScrollView alloc] initWithFrame: NSMakeRect(16.0, 16.0, 620.0, 248.0)] autorelease];
  [scrollView setBorderType: NSBezelBorder];
  [scrollView setHasVerticalScroller: YES];
  [scrollView setHasHorizontalScroller: YES];
  textView = [[[NSTextView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 980.0, 420.0)] autorelease];
  [textView setString: @"# WinUI 3 Parity Review\n\nThis oversized editor surface exists to exercise scroll rails, split view dividers, and content-area framing inside a real document-style window.\n\n- Review table selection states\n- Review outline disclosure glyphs\n- Review tab strip density\n- Review split-view divider balance\n"];
  [scrollView setDocumentView: textView];
  [[rightPane contentView] addSubview: scrollView];
  [splitView addSubview: rightPane];
  [view addSubview: splitView];

  return view;
}

- (NSView *) dialogsPageViewForPage: (NSDictionary *)page
{
  TDFlippedView *view = [[[TDFlippedView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 1040.0, 620.0)] autorelease];
  NSFont *sectionFont = [NSFont boldSystemFontOfSize: 15.0];
  NSButton *button = nil;

  [view addSubview: TDLabel(TDStringOrEmpty([page objectForKey: @"title"]),
                            NSMakeRect(20.0, 12.0, 320.0, 22.0),
                            sectionFont,
                            [NSColor controlTextColor])];
  [view addSubview: TDLabel(@"These buttons are phase 9 review points. With the theme active, file, print, and page setup surfaces should hand off to native Windows dialogs.",
                            NSMakeRect(20.0, 44.0, 920.0, 20.0),
                            [NSFont systemFontOfSize: 13.0],
                            [NSColor secondaryLabelColor])];

  button = TDButton(@"Open Panel", NSMakeRect(20.0, 94.0, 150.0, 34.0), NSMomentaryPushInButton, NSRoundedBezelStyle);
  [button setTarget: self];
  [button setAction: @selector(openPanelDemo:)];
  [view addSubview: button];
  [view addSubview: TDReadOnlyField(_lastOpenPanelResult, NSMakeRect(190.0, 96.0, 600.0, 30.0))];

  button = TDButton(@"Save Panel", NSMakeRect(20.0, 146.0, 150.0, 34.0), NSMomentaryPushInButton, NSRoundedBezelStyle);
  [button setTarget: self];
  [button setAction: @selector(savePanelDemo:)];
  [view addSubview: button];
  [view addSubview: TDReadOnlyField(_lastSavePanelResult, NSMakeRect(190.0, 148.0, 600.0, 30.0))];

  button = TDButton(@"Print Panel", NSMakeRect(20.0, 198.0, 150.0, 34.0), NSMomentaryPushInButton, NSRoundedBezelStyle);
  [button setTarget: self];
  [button setAction: @selector(printPanelDemo:)];
  [view addSubview: button];
  [view addSubview: TDReadOnlyField(_lastPrintPanelResult, NSMakeRect(190.0, 200.0, 600.0, 30.0))];

  button = TDButton(@"Page Setup", NSMakeRect(20.0, 250.0, 150.0, 34.0), NSMomentaryPushInButton, NSRoundedBezelStyle);
  [button setTarget: self];
  [button setAction: @selector(pageLayoutDemo:)];
  [view addSubview: button];
  [view addSubview: TDReadOnlyField(_lastPageLayoutResult, NSMakeRect(190.0, 252.0, 600.0, 30.0))];

  /* A stock NSAlert, modal and as a sheet: the theme lays it out as a
     WinUI ContentDialog. */
  button = TDButton(@"Show Alert", NSMakeRect(20.0, 302.0, 150.0, 34.0), NSMomentaryPushInButton, NSRoundedBezelStyle);
  [button setTarget: self];
  [button setAction: @selector(showAlertDemo:)];
  [view addSubview: button];
  button = TDButton(@"Alert Sheet", NSMakeRect(20.0, 354.0, 150.0, 34.0), NSMomentaryPushInButton, NSRoundedBezelStyle);
  [button setTarget: self];
  [button setAction: @selector(showAlertSheetDemo:)];
  [view addSubview: button];
  [view addSubview: TDReadOnlyField(_lastAlertResult, NSMakeRect(190.0, 304.0, 600.0, 30.0))];

  [view addSubview: TDLabel(@"Expected review points: native title bars, native file pickers, modern print/page setup chrome, and safe fallback when native integration is unavailable.",
                            NSMakeRect(20.0, 420.0, 900.0, 20.0),
                            [NSFont systemFontOfSize: 13.0],
                            [NSColor secondaryLabelColor])];

  return view;
}

- (NSView *) stressPageViewForPage: (NSDictionary *)page
{
  TDFlippedView *view = [[[TDFlippedView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 1040.0, 720.0)] autorelease];
  NSFont *sectionFont = [NSFont boldSystemFontOfSize: 15.0];
  NSFont *captionFont = [NSFont systemFontOfSize: 12.0];
  NSTextField *field = nil;
  NSPopUpButton *popup = nil;
  NSButton *button = nil;

  [view addSubview: TDLabel(TDStringOrEmpty([page objectForKey: @"title"]),
                            NSMakeRect(20.0, 12.0, 320.0, 22.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  [view addSubview: TDLabel(@"Density",
                            NSMakeRect(20.0, 58.0, 240.0, 20.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  [view addSubview: TDLabel(@"Title", NSMakeRect(20.0, 92.0, 80.0, 18.0), nil, [NSColor secondaryLabelColor])];
  field = TDTextField(@"WinUI 3 parity review checklist", NSMakeRect(110.0, 88.0, 320.0, 28.0));
  [view addSubview: field];

  [view addSubview: TDLabel(@"Layout", NSMakeRect(20.0, 124.0, 80.0, 18.0), nil, [NSColor secondaryLabelColor])];
  popup = TDPopup(NSMakeRect(110.0, 120.0, 220.0, 28.0),
                  [NSArray arrayWithObjects: @"Document", @"Inspector", @"Split Preview", nil]);
  [view addSubview: popup];

  [view addSubview: TDLabel(@"Accent", NSMakeRect(20.0, 156.0, 80.0, 18.0), nil, [NSColor secondaryLabelColor])];
  field = TDTextField(@"0F6CBD", NSMakeRect(110.0, 152.0, 120.0, 28.0));
  [view addSubview: field];

  button = TDButton(@"Apply Compact WinUI-like Density", NSMakeRect(20.0, 202.0, 260.0, 32.0), NSMomentaryPushInButton, NSRoundedBezelStyle);
  [view addSubview: button];
  [view addSubview: TDLabel(@"Dense form", NSMakeRect(20.0, 238.0, 140.0, 18.0), captionFont, [NSColor secondaryLabelColor])];

  [view addSubview: TDLabel(@"Long Labels",
                            NSMakeRect(20.0, 304.0, 240.0, 20.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  button = TDButton(@"Save the current workspace snapshot with diagnostics included",
                    NSMakeRect(20.0, 338.0, 360.0, 34.0),
                    NSMomentaryPushInButton,
                    NSRoundedBezelStyle);
  [view addSubview: button];

  popup = TDPopup(NSMakeRect(20.0, 392.0, 420.0, 30.0),
                  [NSArray arrayWithObjects:
                    @"A very long menu title intended to test clipping and optical centering",
                    @"Short title",
                    nil]);
  [view addSubview: popup];

  field = TDTextField(@"This placeholder intentionally stretches to see whether centered text and borders still look composed",
                      NSMakeRect(20.0, 446.0, 560.0, 30.0));
  [view addSubview: field];
  [view addSubview: TDLabel(@"Long labels and placeholders", NSMakeRect(20.0, 480.0, 220.0, 18.0), captionFont, [NSColor secondaryLabelColor])];

  return view;
}

- (NSView *) realAppPageViewForPage: (NSDictionary *)page
{
  TDFlippedView *view = [[[TDFlippedView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 1040.0, 1020.0)] autorelease];
  NSFont *sectionFont = [NSFont boldSystemFontOfSize: 15.0];
  NSBox *toolbarBox = nil;
  NSSplitView *documentSplit = nil;
  NSBox *sidebarBox = nil;
  TDFlippedView *sidebarList = nil;
  TDFlippedView *previewPane = nil;
  NSBox *documentsBox = nil;
  NSBox *previewBox = nil;
  NSScrollView *scrollView = nil;
  NSTableView *tableView = nil;
  NSTableColumn *column = nil;
  NSTextView *textView = nil;
  NSSplitView *editorSplit = nil;
  NSBox *editorBox = nil;
  NSBox *renderedBox = nil;

  [view addSubview: TDLabel(TDStringOrEmpty([page objectForKey: @"title"]),
                            NSMakeRect(20.0, 12.0, 320.0, 22.0),
                            sectionFont,
                            [NSColor controlTextColor])];
  [view addSubview: TDLabel(@"This page approximates the `ObjcMarkdown` acceptance surface: menu bar, toolbar density, sidebar, document list, editor, and rendered preview under one theme.",
                            NSMakeRect(20.0, 44.0, 940.0, 20.0),
                            [NSFont systemFontOfSize: 13.0],
                            [NSColor secondaryLabelColor])];

  toolbarBox = [[[NSBox alloc] initWithFrame: NSMakeRect(20.0, 86.0, 960.0, 66.0)] autorelease];
  [toolbarBox setTitlePosition: NSNoTitle];
  [[toolbarBox contentView] addSubview: TDButton(@"New", NSMakeRect(16.0, 18.0, 92.0, 30.0), NSMomentaryPushInButton, NSRoundedBezelStyle)];
  [[toolbarBox contentView] addSubview: TDButton(@"Save", NSMakeRect(118.0, 18.0, 92.0, 30.0), NSMomentaryPushInButton, NSRoundedBezelStyle)];
  [[toolbarBox contentView] addSubview: TDSearchField(@"release notes", NSMakeRect(242.0, 18.0, 270.0, 30.0))];
  [[toolbarBox contentView] addSubview: TDPopup(NSMakeRect(760.0, 18.0, 180.0, 30.0),
                                                [NSArray arrayWithObjects: @"Comfortable density", @"Compact density", nil])];
  [view addSubview: toolbarBox];

  [view addSubview: TDLabel(@"Document Shell",
                            NSMakeRect(20.0, 182.0, 240.0, 20.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  documentSplit = [[[NSSplitView alloc] initWithFrame: NSMakeRect(20.0, 214.0, 960.0, 320.0)] autorelease];
  [documentSplit setVertical: YES];
  [documentSplit setDividerStyle: NSSplitViewDividerStyleThin];

  sidebarBox = [[[NSBox alloc] initWithFrame: NSMakeRect(0.0, 0.0, 180.0, 320.0)] autorelease];
  [sidebarBox setTitlePosition: NSNoTitle];
  /* An NSBox's content view isn't flipped: lay the list out top-down in a
     flipped view, or it reads bottom-up. */
  sidebarList = [[[TDFlippedView alloc] initWithFrame: [[sidebarBox contentView] bounds]] autorelease];
  [sidebarList setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];
  [sidebarList addSubview: TDLabel(@"Workspaces", NSMakeRect(14.0, 14.0, 120.0, 20.0), sectionFont, [NSColor controlTextColor])];
  [sidebarList addSubview: TDLabel(@"Inbox", NSMakeRect(14.0, 46.0, 120.0, 20.0), nil, [NSColor controlTextColor])];
  [sidebarList addSubview: TDLabel(@"Drafts", NSMakeRect(14.0, 72.0, 120.0, 20.0), nil, [NSColor controlTextColor])];
  [sidebarList addSubview: TDLabel(@"Published", NSMakeRect(14.0, 98.0, 120.0, 20.0), nil, [NSColor controlTextColor])];
  [sidebarList addSubview: TDLabel(@"Archives", NSMakeRect(14.0, 124.0, 120.0, 20.0), nil, [NSColor secondaryLabelColor])];
  [[sidebarBox contentView] addSubview: sidebarList];
  [documentSplit addSubview: sidebarBox];

  documentsBox = [[[NSBox alloc] initWithFrame: NSMakeRect(180.0, 0.0, 260.0, 320.0)] autorelease];
  [documentsBox setTitlePosition: NSNoTitle];
  scrollView = [[[NSScrollView alloc] initWithFrame: NSMakeRect(12.0, 12.0, 236.0, 296.0)] autorelease];
  [scrollView setBorderType: NSBezelBorder];
  [scrollView setHasVerticalScroller: YES];
  tableView = [[[NSTableView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 216.0, 280.0)] autorelease];
  [tableView setUsesAlternatingRowBackgroundColors: YES];
  [tableView setRowHeight: 30.0];
  [tableView setDelegate: self];
  [tableView setDataSource: self];
  column = [[[NSTableColumn alloc] initWithIdentifier: @"name"] autorelease];
  [[column headerCell] setStringValue: @"Documents"];
  [column setWidth: 210.0];
  [tableView addTableColumn: column];
  [tableView reloadData];
  [tableView selectRowIndexes: [NSIndexSet indexSetWithIndex: 0] byExtendingSelection: NO];
  [scrollView setDocumentView: tableView];
  [[documentsBox contentView] addSubview: scrollView];
  [documentSplit addSubview: documentsBox];

  previewBox = [[[NSBox alloc] initWithFrame: NSMakeRect(440.0, 0.0, 520.0, 320.0)] autorelease];
  [previewBox setTitlePosition: NSNoTitle];
  /* Top-down, as the sidebar. */
  previewPane = [[[TDFlippedView alloc] initWithFrame: [[previewBox contentView] bounds]] autorelease];
  [previewPane setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];
  [[previewBox contentView] addSubview: previewPane];
  [previewPane addSubview: TDLabel(@"Release notes draft", NSMakeRect(16.0, 16.0, 260.0, 26.0), [NSFont boldSystemFontOfSize: 20.0], [NSColor controlTextColor])];
  [previewPane addSubview: TDLabel(@"Updated 3 minutes ago", NSMakeRect(16.0, 46.0, 180.0, 18.0), [NSFont systemFontOfSize: 12.0], [NSColor secondaryLabelColor])];
  textView = [[[NSTextView alloc] initWithFrame: NSMakeRect(16.0, 80.0, 480.0, 208.0)] autorelease];
  [textView setEditable: NO];
  [textView setSelectable: YES];
  [textView setString: @"This document-shell surface is the acceptance target for ObjcMarkdown-like windows.\n\nReview points:\n- toolbar density\n- sidebar contrast\n- document list selection\n- content surface framing\n- inactive-state clarity\n"];
  [previewPane addSubview: textView];
  [documentSplit addSubview: previewBox];
  [view addSubview: documentSplit];

  [view addSubview: TDLabel(@"Editor And Preview",
                            NSMakeRect(20.0, 572.0, 260.0, 20.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  editorSplit = [[[NSSplitView alloc] initWithFrame: NSMakeRect(20.0, 604.0, 960.0, 360.0)] autorelease];
  [editorSplit setVertical: YES];
  [editorSplit setDividerStyle: NSSplitViewDividerStyleThin];

  editorBox = [[[NSBox alloc] initWithFrame: NSMakeRect(0.0, 0.0, 470.0, 360.0)] autorelease];
  [editorBox setTitlePosition: NSAtTop];
  [editorBox setTitle: @"Editor"];
  scrollView = [[[NSScrollView alloc] initWithFrame: NSMakeRect(14.0, 30.0, 442.0, 314.0)] autorelease];
  [scrollView setBorderType: NSBezelBorder];
  [scrollView setHasVerticalScroller: YES];
  textView = [[[NSTextView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 420.0, 560.0)] autorelease];
  [textView setString: @"# Heading\n\n- item one\n- item two\n\nThis editor pane exists to validate text rhythm, inset balance, scrollers, and split-view divider weight in a real document layout."];
  [scrollView setDocumentView: textView];
  [[editorBox contentView] addSubview: scrollView];
  [editorSplit addSubview: editorBox];

  renderedBox = [[[NSBox alloc] initWithFrame: NSMakeRect(470.0, 0.0, 490.0, 360.0)] autorelease];
  [renderedBox setTitlePosition: NSAtTop];
  [renderedBox setTitle: @"Preview"];
  scrollView = [[[NSScrollView alloc] initWithFrame: NSMakeRect(14.0, 30.0, 462.0, 314.0)] autorelease];
  [scrollView setBorderType: NSBezelBorder];
  [scrollView setHasVerticalScroller: YES];
  textView = [[[NSTextView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 438.0, 560.0)] autorelease];
  [textView setEditable: NO];
  [textView setString: @"Heading\n\nitem one\nitem two\n\nThe preview pane stands in for ObjcMarkdown's rendered view so the theme can be checked on both source and rendered surfaces at once."];
  [scrollView setDocumentView: textView];
  [[renderedBox contentView] addSubview: scrollView];
  [editorSplit addSubview: renderedBox];
  [view addSubview: editorSplit];

  return view;
}

- (void) showSampleContextMenu: (id)sender
{
  NSMenu *menu = [[[NSMenu alloc] initWithTitle: @"Context"] autorelease];
  NSMenu *submenu = [[[NSMenu alloc] initWithTitle: @"Export"] autorelease];
  NSMenuItem *item = nil;

  item = [[[NSMenuItem alloc] initWithTitle: @"Copy as Markdown" action: NULL keyEquivalent: @"c"] autorelease];
  [item setKeyEquivalentModifierMask: NSCommandKeyMask];
  [menu addItem: item];

  item = [[[NSMenuItem alloc] initWithTitle: @"Pin Selection" action: NULL keyEquivalent: @"p"] autorelease];
  [item setState: NSOnState];
  [menu addItem: item];

  item = [[[NSMenuItem alloc] initWithTitle: @"Export" action: NULL keyEquivalent: @""] autorelease];
  [item setSubmenu: submenu];
  [menu addItem: item];
  [submenu addItemWithTitle: @"HTML Preview" action: NULL keyEquivalent: @""];
  [submenu addItemWithTitle: @"PDF Snapshot" action: NULL keyEquivalent: @""];

  [menu addItem: [NSMenuItem separatorItem]];
  item = [[[NSMenuItem alloc] initWithTitle: @"Unavailable Action" action: NULL keyEquivalent: @""] autorelease];
  [item setEnabled: NO];
  [menu addItem: item];

  [NSMenu popUpContextMenu: menu
                 withEvent: [NSApp currentEvent]
                   forView: sender];
}

- (void) openPanelDemo: (id)sender
{
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  NSInteger result = NSCancelButton;

  [panel setCanChooseFiles: YES];
  [panel setCanChooseDirectories: NO];
  [panel setAllowsMultipleSelection: YES];
  [panel setAllowedFileTypes: [NSArray arrayWithObjects: @"md", @"markdown", @"txt", nil]];
  result = [panel runModal];

  if (result == NSOKButton)
    {
      ASSIGN(_lastOpenPanelResult, [[panel filenames] componentsJoinedByString: @"; "]);
    }
  else
    {
      ASSIGN(_lastOpenPanelResult, @"Open panel cancelled");
    }

  [self updateDisplayedPage];
  (void)sender;
}

- (void) savePanelDemo: (id)sender
{
  NSSavePanel *panel = [NSSavePanel savePanel];
  NSInteger result = NSCancelButton;

  [panel setAllowedFileTypes: [NSArray arrayWithObjects: @"md", @"txt", nil]];
  [panel setCanCreateDirectories: YES];
  if ([panel respondsToSelector: @selector(setNameFieldStringValue:)])
    {
      [panel setNameFieldStringValue: @"ThemeReview.md"];
    }
  result = [panel runModal];

  if (result == NSOKButton)
    {
      ASSIGN(_lastSavePanelResult, [panel filename]);
    }
  else
    {
      ASSIGN(_lastSavePanelResult, @"Save panel cancelled");
    }

  [self updateDisplayedPage];
  (void)sender;
}

- (void) printPanelDemo: (id)sender
{
  NSPrintPanel *panel = [NSPrintPanel printPanel];
  NSInteger result = [panel runModal];

  ASSIGN(_lastPrintPanelResult,
         (result == NSOKButton) ? @"Print panel accepted" : @"Print panel cancelled");
  [self updateDisplayedPage];
  (void)sender;
}

static NSAlert *
TDSaveChangesAlert(void)
{
  NSAlert *alert = [[[NSAlert alloc] init] autorelease];

  [alert setMessageText: @"Save changes to \"Release notes\"?"];
  [alert setInformativeText: @"Your changes will be lost if you don't save them."];
  [alert addButtonWithTitle: @"Save"];
  [alert addButtonWithTitle: @"Cancel"];
  [alert addButtonWithTitle: @"Don't Save"];
  return alert;
}

static NSString *
TDAlertResultString(NSInteger result)
{
  switch (result)
    {
      case NSAlertFirstButtonReturn:
        return @"Save";
      case NSAlertSecondButtonReturn:
        return @"Cancel";
      case NSAlertThirdButtonReturn:
        return @"Don't Save";
      default:
        return [NSString stringWithFormat: @"Result %ld", (long)result];
    }
}

- (void) showAlertDemo: (id)sender
{
  NSInteger result = [TDSaveChangesAlert() runModal];

  ASSIGN(_lastAlertResult, [@"Modal alert: " stringByAppendingString: TDAlertResultString(result)]);
  [self updateDisplayedPage];
  (void)sender;
}

- (void) showAlertSheetDemo: (id)sender
{
  [TDSaveChangesAlert() beginSheetModalForWindow: _window
                                   modalDelegate: self
                                  didEndSelector: @selector(alertSheetDidEnd:returnCode:contextInfo:)
                                     contextInfo: NULL];
  (void)sender;
}

- (void) alertSheetDidEnd: (NSAlert *)alert
               returnCode: (NSInteger)returnCode
              contextInfo: (void *)contextInfo
{
  ASSIGN(_lastAlertResult, [@"Alert sheet: " stringByAppendingString: TDAlertResultString(returnCode)]);
  [self performSelector: @selector(updateDisplayedPage) withObject: nil afterDelay: 0.0];
  (void)alert;
  (void)contextInfo;
}

- (void) pageLayoutDemo: (id)sender
{
  NSPageLayout *panel = [NSPageLayout pageLayout];
  NSInteger result = [panel runModal];

  ASSIGN(_lastPageLayoutResult,
         (result == NSOKButton) ? @"Page setup accepted" : @"Page setup cancelled");
  [self updateDisplayedPage];
  (void)sender;
}

#pragma mark Toolbar

/* A real NSToolbar, as a document app has: image and label items, a
   search field as a view item after a flexible space, tool tips. */
- (NSToolbar *) windowToolbar
{
  NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier: @"ThemeDemoToolbar"] autorelease];

  [toolbar setDelegate: self];
  [toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
  [toolbar setAllowsUserCustomization: NO];
  return toolbar;
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *)toolbar
{
  return [NSArray arrayWithObjects: TDToolbarNew, TDToolbarOpen, TDToolbarSave,
                                    NSToolbarSeparatorItemIdentifier, TDToolbarShare,
                                    NSToolbarFlexibleSpaceItemIdentifier, TDToolbarSearch, nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *)toolbar
{
  return [self toolbarDefaultItemIdentifiers: toolbar];
}

- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar
      itemForItemIdentifier: (NSString *)identifier
  willBeInsertedIntoToolbar: (BOOL)flag
{
  NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier: identifier] autorelease];

  if ([identifier isEqualToString: TDToolbarSearch])
    {
      NSSearchField *field = TDSearchField(@"", NSMakeRect(0.0, 0.0, 200.0, 30.0));

      [item setLabel: @"Search"];
      [item setView: field];
      [item setMinSize: NSMakeSize(140.0, 30.0)];
      [item setMaxSize: NSMakeSize(260.0, 30.0)];
      [item setToolTip: @"Search the review pages"];
      return item;
    }

  if ([identifier isEqualToString: TDToolbarNew])
    {
      [item setLabel: @"New"];
      [item setImage: TDGlyphImage(@"plus")];
      [item setToolTip: @"New document (Ctrl+N)"];
    }
  else if ([identifier isEqualToString: TDToolbarOpen])
    {
      [item setLabel: @"Open"];
      [item setImage: TDGlyphImage(@"folder")];
      [item setToolTip: @"Open a document (Ctrl+O)"];
    }
  else if ([identifier isEqualToString: TDToolbarSave])
    {
      [item setLabel: @"Save"];
      [item setImage: TDGlyphImage(@"disk")];
      [item setToolTip: @"Save the document (Ctrl+S)"];
    }
  else
    {
      [item setLabel: @"Share"];
      [item setImage: TDGlyphImage(@"share")];
      [item setToolTip: @"Share the document"];
    }
  [item setTarget: self];
  [item setAction: @selector(toolbarItemClicked:)];
  return item;
}

- (void) toolbarItemClicked: (id)sender
{
  (void)sender;
}

#pragma mark Browser

- (NSInteger) browser: (NSBrowser *)browser numberOfRowsInColumn: (NSInteger)column
{
  return (column < 2) ? 4 : 3;
}

- (void) browser: (NSBrowser *)browser
 willDisplayCell: (id)cell
           atRow: (NSInteger)row
          column: (NSInteger)column
{
  static NSString *names[3][4] = {
    { @"Documents", @"Pictures", @"Projects", @"Downloads" },
    { @"Notes", @"Release notes", @"Roadmap", @"Archive" },
    { @"draft.md", @"final.md", @"review.md", nil }
  };
  NSString *name = names[MIN(column, 2)][MIN(row, 3)];

  [cell setStringValue: (name != nil) ? name : @""];
  [cell setLeaf: (column >= 2)];
}

#pragma mark More surfaces

/* AppKit surfaces the other pages don't show: colour well, date picker,
   level indicator, a titled grooved box, NSForm, NSBrowser, tool tips and
   template images. */
- (NSView *) surfacesPageViewForPage: (NSDictionary *)page
{
  TDFlippedView *view = [[[TDFlippedView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 1040.0, 760.0)] autorelease];
  NSFont *sectionFont = [NSFont boldSystemFontOfSize: 15.0];
  NSColorWell *well = nil;
  NSDatePicker *datePicker = nil;
  NSLevelIndicator *level = nil;
  NSBox *box = nil;
  NSForm *form = nil;
  NSBrowser *browser = nil;
  NSButton *button = nil;
  NSSegmentedControl *segments = nil;

  [view addSubview: TDLabel(TDStringOrEmpty([page objectForKey: @"title"]),
                            NSMakeRect(20.0, 12.0, 320.0, 22.0),
                            sectionFont,
                            [NSColor controlTextColor])];

  [view addSubview: TDLabel(@"Pickers And Indicators", NSMakeRect(20.0, 52.0, 300.0, 20.0),
                            sectionFont, [NSColor controlTextColor])];
  well = [[[NSColorWell alloc] initWithFrame: NSMakeRect(20.0, 84.0, 64.0, 32.0)] autorelease];
  [well setColor: [NSColor colorWithCalibratedRed: 0.0 green: 0.47 blue: 0.83 alpha: 1.0]];
  [view addSubview: well];
  [view addSubview: TDLabel(@"Colour well", NSMakeRect(20.0, 122.0, 120.0, 18.0),
                            [NSFont systemFontOfSize: 12.0], [NSColor secondaryLabelColor])];
  datePicker = [[[NSDatePicker alloc] initWithFrame: NSMakeRect(160.0, 84.0, 200.0, 32.0)] autorelease];
  [datePicker setDateValue: [NSDate dateWithTimeIntervalSince1970: 1791244800.0]];
  [view addSubview: datePicker];
  [view addSubview: TDLabel(@"Date picker", NSMakeRect(160.0, 122.0, 120.0, 18.0),
                            [NSFont systemFontOfSize: 12.0], [NSColor secondaryLabelColor])];
  level = [[[NSLevelIndicator alloc] initWithFrame: NSMakeRect(400.0, 90.0, 200.0, 20.0)] autorelease];
  [level setMinValue: 0.0];
  [level setMaxValue: 10.0];
  [level setDoubleValue: 6.0];
  [[level cell] setLevelIndicatorStyle: NSContinuousCapacityLevelIndicatorStyle];
  [view addSubview: level];
  [view addSubview: TDLabel(@"Level indicator", NSMakeRect(400.0, 122.0, 140.0, 18.0),
                            [NSFont systemFontOfSize: 12.0], [NSColor secondaryLabelColor])];

  [view addSubview: TDLabel(@"Groups And Forms", NSMakeRect(20.0, 168.0, 300.0, 20.0),
                            sectionFont, [NSColor controlTextColor])];
  box = [[[NSBox alloc] initWithFrame: NSMakeRect(20.0, 198.0, 360.0, 170.0)] autorelease];
  [box setTitle: @"Export Options"];
  [box setTitlePosition: NSAtTop];
  [box setBoxType: NSBoxPrimary];
  [box setBorderType: NSGrooveBorder];
  form = [[[NSForm alloc] initWithFrame: NSMakeRect(12.0, 30.0, 320.0, 80.0)] autorelease];
  [form addEntry: @"Title:"];
  [form addEntry: @"Author:"];
  [[form cellAtIndex: 0] setStringValue: @"Release notes"];
  [[form cellAtIndex: 1] setStringValue: @"Docs team"];
  [form setInterlineSpacing: 10.0];
  [form sizeToCells];
  [[box contentView] addSubview: form];
  [view addSubview: box];

  browser = [[[NSBrowser alloc] initWithFrame: NSMakeRect(420.0, 198.0, 540.0, 170.0)] autorelease];
  [browser setDelegate: self];
  [browser setMaxVisibleColumns: 3];
  [browser setTitled: NO];
  [browser loadColumnZero];
  [browser selectRow: 2 inColumn: 0];
  [browser selectRow: 1 inColumn: 1];
  [view addSubview: browser];

  [view addSubview: TDLabel(@"Tool Tips And Icons", NSMakeRect(20.0, 404.0, 300.0, 20.0),
                            sectionFont, [NSColor controlTextColor])];
  button = TDButton(@"Hover for a tip", NSMakeRect(20.0, 436.0, 160.0, 34.0),
                    NSMomentaryPushInButton, NSRoundedBezelStyle);
  [button setToolTip: @"A tool tip, as WinUI's ToolTip shows it"];
  [view addSubview: button];
  button = TDButton(@"", NSMakeRect(200.0, 436.0, 44.0, 34.0), NSMomentaryPushInButton, NSRoundedBezelStyle);
  [button setImage: TDGlyphImage(@"gear")];
  [button setImagePosition: NSImageOnly];
  [button setToolTip: @"Settings (a template image)"];
  [view addSubview: button];
  button = TDButton(@"Share", NSMakeRect(260.0, 436.0, 120.0, 34.0), NSMomentaryPushInButton, NSRoundedBezelStyle);
  [button setImage: TDGlyphImage(@"share")];
  [button setImagePosition: NSImageLeft];
  [view addSubview: button];
  segments = TDSegmentedControl(NSMakeRect(400.0, 436.0, 180.0, 34.0),
                                [NSArray arrayWithObjects: @"", @"", @"", nil]);
  [segments setImage: TDGlyphImage(@"plus") forSegment: 0];
  [segments setImage: TDGlyphImage(@"folder") forSegment: 1];
  [segments setImage: TDGlyphImage(@"disk") forSegment: 2];
  [view addSubview: segments];
  [view addSubview: TDLabel(@"Template images: an icon button, an icon and label button, and a segmented control. They should follow the text colour in every palette (#25).",
                            NSMakeRect(20.0, 482.0, 920.0, 20.0),
                            [NSFont systemFontOfSize: 13.0], [NSColor secondaryLabelColor])];

  return view;
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *)tableView
{
  if ([tableView isKindOfClass: [NSOutlineView class]])
    {
      return 0;
    }

  return [_tableRows count];
}

- (id) tableView: (NSTableView *)tableView
objectValueForTableColumn: (NSTableColumn *)tableColumn
             row: (NSInteger)row
{
  NSDictionary *item = nil;

  if ([tableView isKindOfClass: [NSOutlineView class]] || row < 0 || row >= (NSInteger)[_tableRows count])
    {
      return @"";
    }

  item = [_tableRows objectAtIndex: row];
  return TDStringOrEmpty([item objectForKey: [tableColumn identifier]]);
}

- (NSInteger) outlineView: (NSOutlineView *)outlineView
 numberOfChildrenOfItem: (id)item
{
  NSArray *children = (item == nil) ? _outlineRows : [item objectForKey: @"children"];

  (void)outlineView;
  return [children count];
}

- (id) outlineView: (NSOutlineView *)outlineView
              child: (NSInteger)index
             ofItem: (id)item
{
  NSArray *children = (item == nil) ? _outlineRows : [item objectForKey: @"children"];

  (void)outlineView;
  return [children objectAtIndex: index];
}

- (BOOL) outlineView: (NSOutlineView *)outlineView
     isItemExpandable: (id)item
{
  NSArray *children = [item objectForKey: @"children"];

  (void)outlineView;
  return ([children count] > 0);
}

- (id) outlineView: (NSOutlineView *)outlineView
objectValueForTableColumn: (NSTableColumn *)tableColumn
             byItem: (id)item
{
  (void)outlineView;
  (void)tableColumn;
  return TDStringOrEmpty([item objectForKey: @"title"]);
}

- (NSView *) placeholderPageViewForPage: (NSDictionary *)page
{
  TDFlippedView *view = [[[TDFlippedView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 1040.0, 240.0)] autorelease];
  NSString *message = @"This page is reserved for a later roadmap phase. The real widget harness is now complete through command surfaces, data views, and native-dialog review.";

  [view addSubview: TDLabel(TDStringOrEmpty([page objectForKey: @"title"]),
                            NSMakeRect(20.0, 12.0, 320.0, 22.0),
                            [NSFont boldSystemFontOfSize: 15.0],
                            [NSColor controlTextColor])];
  [view addSubview: TDLabel(message,
                            NSMakeRect(20.0, 56.0, 900.0, 20.0),
                            [NSFont systemFontOfSize: 13.0],
                            [NSColor secondaryLabelColor])];

  return view;
}

- (NSView *) documentViewForPage: (NSDictionary *)page
{
  NSString *pageID = TDStringOrEmpty([page objectForKey: @"id"]);

  if ([pageID isEqualToString: @"controls"])
    {
      return [self controlsPageViewForPage: page];
    }
  if ([pageID isEqualToString: @"text-input"])
    {
      return [self textInputPageViewForPage: page];
    }
  if ([pageID isEqualToString: @"commands"])
    {
      return [self commandsPageViewForPage: page];
    }
  if ([pageID isEqualToString: @"data-views"])
    {
      return [self dataViewsPageViewForPage: page];
    }
  if ([pageID isEqualToString: @"dialogs"])
    {
      return [self dialogsPageViewForPage: page];
    }
  if ([pageID isEqualToString: @"stress"])
    {
      return [self stressPageViewForPage: page];
    }
  if ([pageID isEqualToString: @"real-app"])
    {
      return [self realAppPageViewForPage: page];
    }
  if ([pageID isEqualToString: @"surfaces"])
    {
      return [self surfacesPageViewForPage: page];
    }

  return [self placeholderPageViewForPage: page];
}

- (void) updateDisplayedPage
{
  NSDictionary *page = [self selectedPage];
  NSView *documentView = nil;

  if (page == nil)
    {
      return;
    }

  [_pageTitleLabel setStringValue: TDStringOrEmpty([page objectForKey: @"title"])];
  [_pageDescriptionLabel setStringValue: TDStringOrEmpty([page objectForKey: @"description"])];

  documentView = [self documentViewForPage: page];
  [_scrollView setDocumentView: documentView];
  [_window setTitle: [NSString stringWithFormat: @"ThemeDemo - %@", TDStringOrEmpty([page objectForKey: @"title"])]];
}

- (void) pageSelectionDidChange: (id)sender
{
  (void)sender;
  [self updateDisplayedPage];
}

@end
