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

#import "TDCommandRunner.h"

#include <stdio.h>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN 1
#include <windows.h>
#include <dwmapi.h>
#else
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#endif

@interface NSComboBoxCell (TDCommandRunnerPrivate)
- (void) _didClickWithinButton: (id)sender;
@end

/* A name as commands give it: lower case, runs of anything but letters
   and digits as one hyphen ("Default button" is "default-button"). */
static NSString *
TDCommandName(NSString *string)
{
  NSMutableString *name = [NSMutableString string];
  NSCharacterSet *alphanumerics = [NSCharacterSet alphanumericCharacterSet];
  BOOL pendingHyphen = NO;
  NSUInteger i;

  string = [string lowercaseString];
  for (i = 0; i < [string length]; i++)
    {
      unichar c = [string characterAtIndex: i];

      if ([alphanumerics characterIsMember: c])
        {
          if (pendingHyphen && [name length] > 0)
            {
              [name appendString: @"-"];
            }
          pendingHyphen = NO;
          [name appendFormat: @"%C", c];
        }
      else
        {
          pendingHyphen = YES;
        }
    }
  return name;
}

/* A plain label: a text field that can't be edited, selected or bezelled. */
static BOOL
TDIsLabel(NSView *view)
{
  NSTextField *field = (NSTextField *)view;

  return [view isKindOfClass: [NSTextField class]]
    && [field isEditable] == NO && [field isSelectable] == NO
    && [field isBezeled] == NO && [field isBordered] == NO;
}

/* The texts a control can be named by: its title, value or placeholder. */
static NSArray *
TDControlNames(NSView *view)
{
  NSMutableArray *names = [NSMutableArray array];

  if ([view isKindOfClass: [NSPopUpButton class]])
    {
      NSString *title = [(NSPopUpButton *)view titleOfSelectedItem];

      if (title != nil)
        {
          [names addObject: title];
        }
    }
  else if ([view isKindOfClass: [NSButton class]])
    {
      [names addObject: [(NSButton *)view title]];
    }
  if ([view isKindOfClass: [NSControl class]]
      && [view isKindOfClass: [NSPopUpButton class]] == NO)
    {
      NSCell *cell = [(NSControl *)view cell];

      if ([cell isKindOfClass: [NSTextFieldCell class]]
          && [(NSTextFieldCell *)cell placeholderString] != nil)
        {
          [names addObject: [(NSTextFieldCell *)cell placeholderString]];
        }
      if ([cell type] == NSTextCellType && [view isKindOfClass: [NSButton class]] == NO)
        {
          [names addObject: [(NSControl *)view stringValue]];
        }
    }
  return names;
}

/* Every view under `view`, in the order they were added. */
static void
TDCollectViews(NSView *view, NSMutableArray *views)
{
  NSEnumerator *enumerator = [[view subviews] objectEnumerator];
  NSView *subview;

  while ((subview = [enumerator nextObject]) != nil)
    {
      [views addObject: subview];
      TDCollectViews(subview, views);
    }
}

#ifdef _WIN32
/* The pixels in `rect` (Windows screen coordinates, top left), as PNG
   data: the screen's, or with `hwnd`, that window's own drawing
   (PrintWindow), which neither a window over it nor the fade Windows gives
   a window it shows can spoil. */
static NSData *
TDCaptureRect(RECT rect, HWND hwnd)
{
  int width = rect.right - rect.left;
  int height = rect.bottom - rect.top;
  RECT source = rect;
  int sourceWidth;
  HDC screen = NULL;
  HDC memory = NULL;
  HBITMAP bitmap = NULL;
  HGDIOBJ previous = NULL;
  BITMAPINFO info;
  unsigned char *pixels = NULL;
  NSBitmapImageRep *rep = nil;
  NSData *png = nil;
  int x, y;

  if (width <= 0 || height <= 0)
    {
      return nil;
    }
  if (hwnd != NULL)
    {
      GetWindowRect(hwnd, &source);
    }
  sourceWidth = source.right - source.left;
  memset(&info, 0, sizeof(info));
  info.bmiHeader.biSize = sizeof(info.bmiHeader);
  info.bmiHeader.biWidth = sourceWidth;
  info.bmiHeader.biHeight = -(source.bottom - source.top);
  info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32;
  info.bmiHeader.biCompression = BI_RGB;
  screen = GetDC(NULL);
  memory = CreateCompatibleDC(screen);
  bitmap = CreateDIBSection(screen, &info, DIB_RGB_COLORS, (void **)&pixels, NULL, 0);
  if (memory != NULL && bitmap != NULL)
    {
      previous = SelectObject(memory, bitmap);
      if (hwnd != NULL
          ? PrintWindow(hwnd, memory, PW_RENDERFULLCONTENT)
          : BitBlt(memory, 0, 0, width, height, screen, rect.left, rect.top, SRCCOPY | CAPTUREBLT))
        {
          int left = rect.left - source.left;
          int top = rect.top - source.top;

          rep = AUTORELEASE([[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes: NULL pixelsWide: width pixelsHigh: height
                       bitsPerSample: 8 samplesPerPixel: 3 hasAlpha: NO isPlanar: NO
                      colorSpaceName: NSDeviceRGBColorSpace bytesPerRow: width * 3
                        bitsPerPixel: 24]);
          for (y = 0; y < height; y++)
            {
              unsigned char *from = pixels + ((size_t)(y + top) * sourceWidth + left) * 4;
              unsigned char *to = [rep bitmapData] + (size_t)y * width * 3;

              for (x = 0; x < width; x++)
                {
                  to[x * 3] = from[x * 4 + 2];
                  to[x * 3 + 1] = from[x * 4 + 1];
                  to[x * 3 + 2] = from[x * 4];
                }
            }
          png = [rep representationUsingType: NSPNGFileType properties: [NSDictionary dictionary]];
        }
      SelectObject(memory, previous);
    }
  if (bitmap != NULL)
    {
      DeleteObject(bitmap);
    }
  if (memory != NULL)
    {
      DeleteDC(memory);
    }
  ReleaseDC(NULL, screen);
  return png;
}

/* The app's visible top-level windows, front to back. */
static WINBOOL CALLBACK
TDCollectAppWindow(HWND hwnd, LPARAM parameter)
{
  DWORD process = 0;

  GetWindowThreadProcessId(hwnd, &process);
  if (process == GetCurrentProcessId() && IsWindowVisible(hwnd))
    {
      [(NSMutableArray *)parameter addObject: [NSValue valueWithPointer: hwnd]];
    }
  return TRUE;
}

/* Raises the app's windows over everything else for a capture, keeping
   their order (a menu over its window), or puts them back. Another app may
   be in front, and Windows won't let a background app take the foreground. */
static void
TDRaiseAppWindows(BOOL raise)
{
  NSMutableArray *windows = [NSMutableArray array];
  NSEnumerator *enumerator;
  NSValue *value;

  EnumWindows(TDCollectAppWindow, (LPARAM)windows);
  enumerator = [windows reverseObjectEnumerator];
  while ((value = [enumerator nextObject]) != nil)
    {
      SetWindowPos((HWND)[value pointerValue], raise ? HWND_TOPMOST : HWND_NOTOPMOST,
                   0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_NOOWNERZORDER);
    }
}

/* A window's visible frame on the screen: without the invisible resize
   border GetWindowRect includes. */
static RECT
TDWindowScreenRect(NSWindow *window)
{
  HWND hwnd = (HWND)(intptr_t)[window windowNumber];
  RECT rect;

  memset(&rect, 0, sizeof(rect));
  if (FAILED(DwmGetWindowAttribute(hwnd, DWMWA_EXTENDED_FRAME_BOUNDS, &rect, sizeof(rect))))
    {
      GetWindowRect(hwnd, &rect);
    }
  return rect;
}
#endif

/* Puts `event` on the queue, so whichever loop runs (the app's, a menu's,
   an alert's) takes it, as it would the user's. A loop waiting for events
   wakes only for a Windows message, so one follows. */
static void
TDPostEvent(NSEvent *event)
{
  [NSApp postEvent: event atStart: NO];
#ifdef _WIN32
  {
    NSWindow *window = [NSApp modalWindow] != nil ? [NSApp modalWindow] : [NSApp mainWindow];

    if (window == nil)
      {
        window = [[NSApp windows] lastObject];
      }
    if ([window windowNumber] > 0)
      {
        PostMessageW((HWND)(intptr_t)[window windowNumber], WM_NULL, 0, 0);
      }
  }
#endif
}

static BOOL
TDWriteData(NSData *data, NSString *path)
{
  NSString *directory = [path stringByDeletingLastPathComponent];

  if ([data length] == 0)
    {
      return NO;
    }
  if ([directory length] > 0)
    {
      [[NSFileManager defaultManager] createDirectoryAtPath: directory
                                withIntermediateDirectories: YES
                                                 attributes: nil
                                                      error: NULL];
    }
  return [data writeToFile: path atomically: YES];
}

@implementation TDCommandRunner

- (id) initWithTarget: (id<TDCommandTarget>)target
{
  self = [super init];
  if (self != nil)
    {
      _target = target;
      _queue = [NSMutableArray new];
      _pipeBuffer = [NSMutableData new];
#ifndef _WIN32
      _fifo = -1;
#endif
    }
  return self;
}

- (void) dealloc
{
  [_pipeTimer invalidate];
#ifdef _WIN32
  if (_pipe != NULL)
    {
      CloseHandle((HANDLE)_pipe);
    }
#else
  if (_fifo >= 0)
    {
      close(_fifo);
    }
#endif
  RELEASE(_queue);
  RELEASE(_pipeBuffer);
  [super dealloc];
}

#pragma mark Queue

- (void) report: (NSString *)message
{
  fprintf(stdout, "ThemeDemo: %s\n", [message UTF8String]);
  fflush(stdout);
}

/* The next command, after `delay` seconds, in every mode a menu or alert
   runs the loop in. */
- (void) scheduleNextAfter: (NSTimeInterval)delay
{
  NSTimer *timer;
  NSRunLoop *loop = [NSRunLoop currentRunLoop];

  if (_scheduled || [_queue count] == 0)
    {
      return;
    }
  _scheduled = YES;
  timer = [NSTimer timerWithTimeInterval: delay target: self selector: @selector(runNext:)
                                userInfo: nil repeats: NO];
  [loop addTimer: timer forMode: NSDefaultRunLoopMode];
  [loop addTimer: timer forMode: NSModalPanelRunLoopMode];
  [loop addTimer: timer forMode: NSEventTrackingRunLoopMode];
}

- (void) enqueueCommands: (NSString *)commands
{
  NSEnumerator *lines = [[commands componentsSeparatedByCharactersInSet:
                           [NSCharacterSet newlineCharacterSet]] objectEnumerator];
  NSString *line;

  while ((line = [lines nextObject]) != nil)
    {
      line = [line stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
      if ([line length] > 0 && [line hasPrefix: @"#"] == NO)
        {
          [_queue addObject: line];
        }
    }
  [self scheduleNextAfter: 0.0];
}

/* Commands that stand for several run in their place. */
- (void) insertCommands: (NSArray *)commands
{
  [_queue replaceObjectsInRange: NSMakeRange(0, 0) withObjectsFromArray: commands];
}

/* Runs one command. The next is scheduled first, so that a command which
   runs a loop of its own (an alert) doesn't hold the rest up. */
- (void) runNext: (NSTimer *)timer
{
  NSString *line;
  NSTimeInterval delay = 0.05;

  (void)timer;
  _scheduled = NO;
  if ([_queue count] == 0)
    {
      return;
    }
  line = RETAIN([_queue objectAtIndex: 0]);
  [_queue removeObjectAtIndex: 0];
  if ([line hasPrefix: @"wait "])
    {
      delay = MAX(0.0, [[line substringFromIndex: 5] doubleValue]);
      [self report: line];
    }
  else
    {
      [self scheduleNextAfter: delay];
      [self execute: line];
    }
  RELEASE(line);
  [self scheduleNextAfter: delay];
  if ([_queue count] == 0 && _scheduled == NO)
    {
      [self report: @"idle"];
    }
}

#pragma mark Targets

- (NSWindow *) window
{
  return [_target demoWindow];
}

/* A view by name: "page-selector"; a control by its title, value or
   placeholder; or the control a caption ("Text field") sits under. */
- (NSView *) viewNamed: (NSString *)name
{
  return [self viewNamed: name inWindow: [self window]];
}

- (NSView *) viewNamed: (NSString *)name inWindow: (NSWindow *)window
{
  NSMutableArray *views = [NSMutableArray array];
  NSEnumerator *enumerator;
  NSView *view;

  name = TDCommandName(name);
  if ([name isEqualToString: @"page-selector"])
    {
      return [_target pageSelector];
    }
  TDCollectViews([window contentView], views);
  enumerator = [views objectEnumerator];
  while ((view = [enumerator nextObject]) != nil)
    {
      NSEnumerator *names;
      NSString *candidate;

      if (TDIsLabel(view) || [view isKindOfClass: [NSControl class]] == NO || [view isHiddenOrHasHiddenAncestor])
        {
          continue;
        }
      names = [TDControlNames(view) objectEnumerator];
      while ((candidate = [names nextObject]) != nil)
        {
          if ([TDCommandName(candidate) isEqualToString: name])
            {
              return view;
            }
        }
    }

  /* A caption: the control just above it, overlapping it across. */
  enumerator = [views objectEnumerator];
  while ((view = [enumerator nextObject]) != nil)
    {
      NSRect label;
      NSEnumerator *others;
      NSView *other;

      if (TDIsLabel(view) == NO || [TDCommandName([(NSTextField *)view stringValue]) isEqualToString: name] == NO)
        {
          continue;
        }
      label = [view convertRect: [view bounds] toView: nil];
      others = [[[view superview] subviews] objectEnumerator];
      while ((other = [others nextObject]) != nil)
        {
          NSRect frame;
          CGFloat gap;

          if (other == view || TDIsLabel(other) || [other isKindOfClass: [NSControl class]] == NO)
            {
              continue;
            }
          frame = [other convertRect: [other bounds] toView: nil];
          gap = NSMinY(frame) - NSMaxY(label);
          if (gap >= -2.0 && gap <= 16.0
              && NSMaxX(frame) > NSMinX(label) && NSMinX(frame) < NSMaxX(label))
            {
              return other;
            }
        }
    }
  return nil;
}

#pragma mark Events

/* The point `x`, `y` points from the top left of the window's content, in
   its base coordinates. */
- (NSPoint) windowPointForX: (CGFloat)x y: (CGFloat)y
{
  NSView *content = [[self window] contentView];
  NSPoint point = NSMakePoint(x, [content isFlipped] ? y : NSHeight([content bounds]) - y);

  return [content convertPoint: point toView: nil];
}

- (void) postMouse: (NSEventType)type at: (NSPoint)point clickCount: (NSInteger)count
{
  NSEvent *event = [NSEvent mouseEventWithType: type location: point modifierFlags: 0
                                     timestamp: [[NSProcessInfo processInfo] systemUptime]
                                  windowNumber: [[self window] windowNumber] context: nil
                                   eventNumber: 0 clickCount: count
                                      pressure: (type == NSLeftMouseDown) ? 1.0 : 0.0];

  TDPostEvent(event);
}

- (void) clickAt: (NSPoint)point count: (NSInteger)count
{
  NSInteger i;

  for (i = 1; i <= count; i++)
    {
      [self postMouse: NSLeftMouseDown at: point clickCount: i];
      [self postMouse: NSLeftMouseUp at: point clickCount: i];
    }
}

- (void) postKey: (NSString *)characters modifiers: (NSUInteger)modifiers
{
  NSWindow *window = [NSApp keyWindow] != nil ? [NSApp keyWindow] : [self window];
  NSEventType types[2] = { NSKeyDown, NSKeyUp };
  NSUInteger i;

  for (i = 0; i < 2; i++)
    {
      NSEvent *event = [NSEvent keyEventWithType: types[i] location: NSZeroPoint
                                   modifierFlags: modifiers
                                       timestamp: [[NSProcessInfo processInfo] systemUptime]
                                    windowNumber: [window windowNumber] context: nil
                                      characters: characters
                     charactersIgnoringModifiers: [characters lowercaseString]
                                       isARepeat: NO keyCode: 0];

      TDPostEvent(event);
    }
}

/* "tab", "shift+tab", "ctrl+a" (GNUstep's Command, left Ctrl on Windows),
   "escape", "return", "space", arrows, or a character. */
- (BOOL) postKeyNamed: (NSString *)spec
{
  NSArray *parts = [[spec lowercaseString] componentsSeparatedByString: @"+"];
  NSString *key = [parts lastObject];
  NSUInteger modifiers = 0;
  NSUInteger i;
  unichar character = 0;
  NSDictionary *named = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSNumber numberWithInt: NSTabCharacter], @"tab",
    [NSNumber numberWithInt: NSCarriageReturnCharacter], @"return",
    [NSNumber numberWithInt: NSCarriageReturnCharacter], @"enter",
    [NSNumber numberWithInt: 0x1b], @"escape",
    [NSNumber numberWithInt: 0x1b], @"esc",
    [NSNumber numberWithInt: ' '], @"space",
    [NSNumber numberWithInt: NSBackspaceCharacter], @"backspace",
    [NSNumber numberWithInt: NSDeleteFunctionKey], @"delete",
    [NSNumber numberWithInt: NSUpArrowFunctionKey], @"up",
    [NSNumber numberWithInt: NSDownArrowFunctionKey], @"down",
    [NSNumber numberWithInt: NSLeftArrowFunctionKey], @"left",
    [NSNumber numberWithInt: NSRightArrowFunctionKey], @"right",
    [NSNumber numberWithInt: NSHomeFunctionKey], @"home",
    [NSNumber numberWithInt: NSEndFunctionKey], @"end",
    nil];

  for (i = 0; i + 1 < [parts count]; i++)
    {
      NSString *modifier = [parts objectAtIndex: i];

      if ([modifier isEqualToString: @"shift"])
        {
          modifiers |= NSShiftKeyMask;
        }
      else if ([modifier isEqualToString: @"ctrl"] || [modifier isEqualToString: @"cmd"])
        {
          modifiers |= NSCommandKeyMask;
        }
      else if ([modifier isEqualToString: @"alt"])
        {
          modifiers |= NSAlternateKeyMask;
        }
      else
        {
          return NO;
        }
    }
  if ([named objectForKey: key] != nil)
    {
      character = [[named objectForKey: key] intValue];
    }
  else if ([key length] == 1)
    {
      character = [key characterAtIndex: 0];
    }
  else
    {
      return NO;
    }
  if (character == NSTabCharacter && (modifiers & NSShiftKeyMask))
    {
      character = NSBackTabCharacter;
    }
  [self postKey: [NSString stringWithCharacters: &character length: 1] modifiers: modifiers];
  return YES;
}

#pragma mark Commands

/* The key window's focused view, for a driver to check: a field's own
   name rather than its field editor's. */
- (void) reportFocus
{
  NSWindow *window = [NSApp keyWindow];
  id responder = [window firstResponder];
  NSArray *names;

  if ([responder isKindOfClass: [NSText class]] && [(NSText *)responder delegate] != nil)
    {
      responder = [(NSText *)responder delegate];
    }
  names = [responder isKindOfClass: [NSView class]] ? TDControlNames(responder) : nil;
  [self report: [NSString stringWithFormat: @"focus %@ %@ in %@", NSStringFromClass([responder class]),
                   [names count] > 0 ? TDCommandName([names objectAtIndex: 0]) : @"-",
                   window != nil ? [window title] : @"no key window"]];
}

- (void) focusViewNamed: (NSString *)name
{
  NSView *view = [self viewNamed: name];
  NSWindow *window = [view window];

  if (view == nil)
    {
      [self report: [NSString stringWithFormat: @"no control named %@", name]];
      return;
    }
  [NSApp activateIgnoringOtherApps: YES];
  [window makeKeyAndOrderFront: nil];
  [view scrollRectToVisible: [view bounds]];
  if ([view isKindOfClass: [NSTextField class]] && [view isKindOfClass: [NSComboBox class]] == NO
      && [(NSTextField *)view isSelectable])
    {
      NSText *editor;

      [(NSTextField *)view selectText: nil];
      editor = [(NSTextField *)view currentEditor];
      [editor setSelectedRange: NSMakeRange([[editor string] length], 0)];
    }
  else
    {
      [window makeFirstResponder: view];
    }
  _focusedControl = view;
  [window displayIfNeeded];
}

- (void) selectAll
{
  id responder = [[NSApp keyWindow] firstResponder];

  if ([responder isKindOfClass: [NSText class]])
    {
      [(NSText *)responder selectAll: nil];
    }
  else if ([_focusedControl isKindOfClass: [NSTextField class]])
    {
      [(NSTextField *)_focusedControl selectText: nil];
    }
}

- (void) openDropdownNamed: (NSString *)name
{
  NSView *view = [self viewNamed: name];

  [[view window] makeKeyAndOrderFront: nil];
  if ([view isKindOfClass: [NSPopUpButton class]])
    {
      /* libs-gui attaches the menu without tracking: it stays open, and
         the commands after this one run. */
      [(NSPopUpButton *)view performClick: nil];
    }
  else if ([view isKindOfClass: [NSComboBox class]])
    {
      /* The list runs its own loop until it closes; the commands after
         this one run in it. */
      [(NSComboBoxCell *)[(NSComboBox *)view cell] _didClickWithinButton: view];
    }
  else
    {
      [self report: [NSString stringWithFormat: @"no pop-up or combo box named %@", name]];
    }
}

- (void) closeDropdowns
{
  NSEnumerator *enumerator = [[NSApp windows] objectEnumerator];
  NSWindow *window;

  while ((window = [enumerator nextObject]) != nil)
    {
      NSView *view = [window contentView];

      if ([view isKindOfClass: [NSMenuView class]] && [window isVisible])
        {
          NSMenu *menu = [(NSMenuView *)view menu];

          if ([menu respondsToSelector: @selector(cancelTracking)])
            {
              [menu performSelector: @selector(cancelTracking)];
            }
          [window orderOut: nil];
        }
    }
  [self postKeyNamed: @"escape"];
}

/* Presses the modal window's button named `name` (Cancel unless given),
   as a click would; without one, ends the loop. */
- (void) dismissAlert: (NSString *)name
{
  NSWindow *window = [NSApp modalWindow];
  NSView *button = (window != nil)
    ? [self viewNamed: ([name length] > 0 ? name : @"cancel") inWindow: window] : nil;

  if (window == nil)
    {
      return;
    }
  if ([button isKindOfClass: [NSButton class]])
    {
      [(NSButton *)button performClick: nil];
    }
  else
    {
      [NSApp stopModalWithCode: NSAlertSecondButtonReturn];
    }
  /* The modal loop ends on its next event for the alert (it discards
     others). */
  TDPostEvent([NSEvent otherEventWithType: NSApplicationDefined location: NSZeroPoint
                             modifierFlags: 0 timestamp: 0 windowNumber: [window windowNumber]
                                   context: nil subtype: 0 data1: 0 data2: 0]);
}

/* The content view, drawn offscreen: no title bar, menus or alerts. */
- (BOOL) writeContentTo: (NSString *)path
{
  NSView *content = [[self window] contentView];
  NSBitmapImageRep *rep;

  [[self window] displayIfNeeded];
  rep = [content bitmapImageRepForCachingDisplayInRect: [content bounds]];
  [content cacheDisplayInRect: [content bounds] toBitmapImageRep: rep];
  return TDWriteData([rep representationUsingType: NSPNGFileType properties: [NSDictionary dictionary]], path);
}

/* From the screen: the window with its title bar, the app's visible
   windows (menus and pop-ups too) together, or the whole screen, with
   whatever is open over it. */
- (BOOL) writeScreenOf: (NSWindow *)window app: (BOOL)app to: (NSString *)path
{
#ifdef _WIN32
  RECT rect;

  [window displayIfNeeded];
  if (app)
    {
      NSEnumerator *windows = [[NSApp windows] objectEnumerator];
      NSWindow *each;

      rect = TDWindowScreenRect([self window]);
      while ((each = [windows nextObject]) != nil)
        {
          RECT frame;

          if ([each isVisible] == NO || [each windowNumber] <= 0)
            {
              continue;
            }
          frame = TDWindowScreenRect(each);
          if (frame.right <= frame.left || frame.bottom <= frame.top)
            {
              continue;
            }
          rect.left = MIN(rect.left, frame.left);
          rect.top = MIN(rect.top, frame.top);
          rect.right = MAX(rect.right, frame.right);
          rect.bottom = MAX(rect.bottom, frame.bottom);
        }
    }
  else if (window != nil)
    {
      rect = TDWindowScreenRect(window);
    }
  else
    {
      rect.left = GetSystemMetrics(SM_XVIRTUALSCREEN);
      rect.top = GetSystemMetrics(SM_YVIRTUALSCREEN);
      rect.right = rect.left + GetSystemMetrics(SM_CXVIRTUALSCREEN);
      rect.bottom = rect.top + GetSystemMetrics(SM_CYVIRTUALSCREEN);
    }
  {
    NSData *png;

    if (app)
      {
        TDRaiseAppWindows(YES);
        /* Let DWM compose the raised windows, without running the loop:
           that would run the commands after this one first. */
        DwmFlush();
        DwmFlush();
      }
    GdiFlush();
    png = TDCaptureRect(rect, (window != nil && app == NO)
                                ? (HWND)(intptr_t)[window windowNumber] : NULL);
    if (app)
      {
        TDRaiseAppWindows(NO);
      }
    return TDWriteData(png, path);
  }
#else
  (void)window;
  (void)app;
  (void)path;
  return NO;
#endif
}

- (BOOL) writeScreenOf: (NSWindow *)window to: (NSString *)path
{
  return [self writeScreenOf: window app: NO to: path];
}

- (void) execute: (NSString *)line
{
  NSArray *parts = [line componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
  NSString *command = [parts objectAtIndex: 0];
  NSString *argument = ([parts count] >= 2) ? [parts objectAtIndex: 1] : nil;
  NSString *rest = nil;
  BOOL ok = YES;

  {
    NSRange space = [line rangeOfString: @" "];

    rest = (space.location != NSNotFound) ? [line substringFromIndex: NSMaxRange(space)] : @"";
  }
  [self report: line];

  if ([command isEqualToString: @"page"] && argument != nil)
    {
      ok = [_target selectPageWithID: argument];
      [[self window] displayIfNeeded];
    }
  else if (([command isEqualToString: @"click"] || [command isEqualToString: @"double-click"])
           && [parts count] >= 3)
    {
      [[self window] makeKeyAndOrderFront: nil];
      [self clickAt: [self windowPointForX: [argument doubleValue] y: [[parts objectAtIndex: 2] doubleValue]]
              count: [command isEqualToString: @"double-click"] ? 2 : 1];
    }
  else if ([command isEqualToString: @"click-control"] && argument != nil)
    {
      NSView *view = [self viewNamed: rest];

      ok = (view != nil);
      if (ok)
        {
          NSRect frame = [view convertRect: [view bounds] toView: nil];

          [[view window] makeKeyAndOrderFront: nil];
          [self clickAt: NSMakePoint(NSMidX(frame), NSMidY(frame)) count: 1];
        }
    }
  else if (([command isEqualToString: @"focus"] || [command isEqualToString: @"blur-to"]) && argument != nil)
    {
      [self focusViewNamed: rest];
      ok = (_focusedControl != nil && [[_focusedControl window] isKeyWindow]);
    }
  else if ([command isEqualToString: @"select-all"])
    {
      [self selectAll];
    }
  else if ([command isEqualToString: @"type"])
    {
      NSUInteger i;

      for (i = 0; i < [rest length]; i++)
        {
          [self postKey: [rest substringWithRange: NSMakeRange(i, 1)] modifiers: 0];
        }
    }
  else if ([command isEqualToString: @"key"] && argument != nil)
    {
      ok = [self postKeyNamed: argument];
    }
  else if ([command isEqualToString: @"open-dropdown"] && argument != nil)
    {
      [self openDropdownNamed: rest];
    }
  else if ([command isEqualToString: @"close-dropdown"])
    {
      [self closeDropdowns];
    }
  else if ([command isEqualToString: @"capture-dropdown"] && [parts count] >= 3)
    {
      [self insertCommands: [NSArray arrayWithObjects:
        [NSString stringWithFormat: @"open-dropdown %@", argument],
        @"wait 0.5",
        [NSString stringWithFormat: @"screenshot-app %@",
                  [[rest substringFromIndex: [argument length]] stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceCharacterSet]]],
        @"close-dropdown",
        nil]];
    }
  else if ([command isEqualToString: @"alert"])
    {
      NSInteger result = [_target runSaveChangesAlert];

      [self report: [NSString stringWithFormat: @"alert closed %ld", (long)result]];
    }
  else if ([command isEqualToString: @"dismiss-alert"])
    {
      [self dismissAlert: rest];
    }
  else if ([command isEqualToString: @"capture-alert"] && argument != nil)
    {
      [self insertCommands: [NSArray arrayWithObjects:
        @"alert",
        @"wait 0.6",
        [NSString stringWithFormat: @"screenshot-key-window %@", rest],
        @"dismiss-alert",
        nil]];
    }
  else if ([command isEqualToString: @"screenshot"] && argument != nil)
    {
      ok = [self writeContentTo: rest];
    }
  else if ([command isEqualToString: @"screenshot-window"] && argument != nil)
    {
      ok = [self writeScreenOf: [self window] to: rest];
    }
  else if ([command isEqualToString: @"screenshot-key-window"] && argument != nil)
    {
      NSWindow *window = [NSApp modalWindow] != nil ? [NSApp modalWindow]
        : ([NSApp keyWindow] != nil ? [NSApp keyWindow] : [self window]);

      ok = [self writeScreenOf: window to: rest];
    }
  else if ([command isEqualToString: @"screenshot-app"] && argument != nil)
    {
      ok = [self writeScreenOf: nil app: YES to: rest];
    }
  else if ([command isEqualToString: @"screenshot-screen"] && argument != nil)
    {
      ok = [self writeScreenOf: nil to: rest];
    }
  else if ([command isEqualToString: @"report-focus"])
    {
      [self reportFocus];
    }
  else if ([command isEqualToString: @"display"])
    {
      [[self window] display];
    }
  else if ([command isEqualToString: @"quit"])
    {
      [NSApp terminate: nil];
    }
  else
    {
      [self report: [NSString stringWithFormat: @"unknown command: %@", line]];
      return;
    }
  if (ok == NO)
    {
      [self report: [NSString stringWithFormat: @"failed: %@", line]];
    }
}

#pragma mark Script and pipe

- (void) takePipeLines
{
  while ([_pipeBuffer length] > 0)
    {
      const char *bytes = [_pipeBuffer bytes];
      const char *newline = memchr(bytes, '\n', [_pipeBuffer length]);
      NSString *line;

      if (newline == NULL)
        {
          return;
        }
      line = AUTORELEASE([[NSString alloc] initWithBytes: bytes length: newline - bytes
                                                encoding: NSUTF8StringEncoding]);
      [_pipeBuffer replaceBytesInRange: NSMakeRange(0, newline - bytes + 1) withBytes: NULL length: 0];
      if (line != nil)
        {
          [self enqueueCommands: line];
        }
    }
}

- (void) pollPipe: (NSTimer *)timer
{
  char buffer[4096];

  (void)timer;
#ifdef _WIN32
  {
    HANDLE pipe = (HANDLE)_pipe;
    DWORD count = 0;

    if (_pipeConnected == NO)
      {
        if (ConnectNamedPipe(pipe, NULL) || GetLastError() == ERROR_PIPE_CONNECTED)
          {
            _pipeConnected = YES;
          }
        else
          {
            return;
          }
      }
    while (ReadFile(pipe, buffer, sizeof(buffer), &count, NULL) && count > 0)
      {
        [_pipeBuffer appendBytes: buffer length: count];
      }
    if (GetLastError() == ERROR_BROKEN_PIPE || GetLastError() == ERROR_PIPE_NOT_CONNECTED)
      {
        /* The writer closed it: take what's left and wait for another. */
        [_pipeBuffer appendBytes: "\n" length: 1];
        DisconnectNamedPipe(pipe);
        _pipeConnected = NO;
      }
  }
#else
  {
    ssize_t count;

    while ((count = read(_fifo, buffer, sizeof(buffer))) > 0)
      {
        [_pipeBuffer appendBytes: buffer length: count];
      }
  }
#endif
  [self takePipeLines];
}

- (void) openPipe: (NSString *)name
{
#ifdef _WIN32
  NSString *path = [name hasPrefix: @"\\\\.\\pipe\\"] ? name
    : [@"\\\\.\\pipe\\" stringByAppendingString: name];
  HANDLE pipe = CreateNamedPipeW((const wchar_t *)[path cStringUsingEncoding: NSUnicodeStringEncoding],
                                 PIPE_ACCESS_INBOUND,
                                 PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_NOWAIT,
                                 1, 0, 4096, 0, NULL);

  if (pipe == INVALID_HANDLE_VALUE)
    {
      [self report: [NSString stringWithFormat: @"can't open the pipe %@ (%lu)", path,
                       (unsigned long)GetLastError()]];
      return;
    }
  _pipe = (void *)pipe;
  [self report: [NSString stringWithFormat: @"reading commands from %@", path]];
#else
  _fifo = open([name fileSystemRepresentation], O_RDONLY | O_NONBLOCK);
  if (_fifo < 0)
    {
      [self report: [NSString stringWithFormat: @"can't open the FIFO %@", name]];
      return;
    }
#endif
  _pipeTimer = [NSTimer timerWithTimeInterval: 0.05 target: self selector: @selector(pollPipe:)
                                     userInfo: nil repeats: YES];
  [[NSRunLoop currentRunLoop] addTimer: _pipeTimer forMode: NSDefaultRunLoopMode];
  [[NSRunLoop currentRunLoop] addTimer: _pipeTimer forMode: NSModalPanelRunLoopMode];
  [[NSRunLoop currentRunLoop] addTimer: _pipeTimer forMode: NSEventTrackingRunLoopMode];
}

- (void) startFromArguments: (NSArray *)arguments
{
  NSUInteger index;

  index = [arguments indexOfObject: @"--command-script"];
  if (index != NSNotFound && index + 1 < [arguments count])
    {
      NSString *path = [arguments objectAtIndex: index + 1];
      NSString *commands = [NSString stringWithContentsOfFile: path];

      if (commands == nil)
        {
          [self report: [NSString stringWithFormat: @"can't read the script %@", path]];
        }
      else
        {
          [self enqueueCommands: commands];
        }
    }
  index = [arguments indexOfObject: @"--command-fifo"];
  if (index != NSNotFound && index + 1 < [arguments count])
    {
      [self openPipe: [arguments objectAtIndex: index + 1]];
    }
}

@end
