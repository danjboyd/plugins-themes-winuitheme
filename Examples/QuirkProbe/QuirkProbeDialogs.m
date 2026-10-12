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

#import "QuirkProbe.h"

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN 1
#include <windows.h>
#include <wchar.h>
#endif

/* The native dialogs at run time (issues #20 and #69): Windows' print,
   page setup, open and save dialogs, run for real. A thread finds each
   dialog when it opens, reads what it was seeded with, fills it in as a
   user would and presses OK or Cancel, without the pointer; the checks
   then look at what came back. When the theme should leave a panel to
   GNUstep, a timer in the modal panel's run loop sees GNUstep's panel and
   stops it. */

@interface QuirkProbe (DialogResults)
- (void) pass: (NSString *)check detail: (NSString *)detail;
- (void) fail: (NSString *)check detail: (NSString *)detail;
- (void) skip: (NSString *)check detail: (NSString *)detail;
@end

#ifdef _WIN32

/* Control IDs from <dlgs.h>. */
enum
{
  QuirkProbeIDFromPage = 0x0480,     /* edt1 */
  QuirkProbeIDToPage = 0x0481,       /* edt2 */
  QuirkProbeIDCopies = 0x0482,       /* edt3 */
  QuirkProbeIDPagesRadio = 0x0422,   /* rad3 */
  QuirkProbeIDPrinter = 0x0473,      /* cmb4 */
  QuirkProbeIDPortrait = 0x0420,     /* rad1 */
  QuirkProbeIDLandscape = 0x0421,    /* rad2 */
  QuirkProbeIDLeftMargin = 0x0483,   /* edt4 */
  QuirkProbeIDOpenName = 0x047c,     /* cmb13: the Open dialog's name box */
  QuirkProbeIDSaveName = 0x03e9      /* the Save dialog's name box */
};

/* What the thread does in a dialog and what it saw there. */
typedef struct
{
  DWORD process;
  /* In: */
  int controls[4];
  const WCHAR *texts[4];
  int clickControl;
  BOOL cancel;
  int readControls[4];
  volatile LONG stop;
  /* Out: */
  volatile LONG done;
  BOOL found;
  HWND owner;
  WCHAR title[128];
  WCHAR read[4][260];
  BOOL readChecked[4];
} QuirkProbeDialogScript;

typedef struct
{
  DWORD process;
  HWND found;
} QuirkProbeDialogSearch;

static WINBOOL CALLBACK
QuirkProbeFindDialog(HWND window, LPARAM parameter)
{
  QuirkProbeDialogSearch *search = (QuirkProbeDialogSearch *)parameter;
  DWORD process = 0;
  WCHAR className[32];

  GetWindowThreadProcessId(window, &process);
  if (process == search->process && IsWindowVisible(window)
      && GetClassNameW(window, className, 32) > 0 && wcscmp(className, L"#32770") == 0)
    {
      search->found = window;
      return FALSE;
    }
  return TRUE;
}

typedef struct
{
  int identifier;
  HWND found;
} QuirkProbeControlSearch;

static WINBOOL CALLBACK
QuirkProbeFindControl(HWND window, LPARAM parameter)
{
  QuirkProbeControlSearch *search = (QuirkProbeControlSearch *)parameter;

  if (GetDlgCtrlID(window) == search->identifier && IsWindowVisible(window))
    {
      search->found = window;
      return FALSE;
    }
  return TRUE;
}

/* A control anywhere in the dialog: the Open and Save dialogs nest theirs. */
static HWND
QuirkProbeDialogControl(HWND dialog, int identifier)
{
  QuirkProbeControlSearch search = { identifier, NULL };

  EnumChildWindows(dialog, QuirkProbeFindControl, (LPARAM)&search);
  return search.found;
}

static DWORD WINAPI
QuirkProbeDialogThread(LPVOID parameter)
{
  QuirkProbeDialogScript *script = (QuirkProbeDialogScript *)parameter;
  QuirkProbeDialogSearch search = { script->process, NULL };
  int tries;
  int index;

  for (tries = 0; tries < 80 && search.found == NULL && script->stop == 0; tries++)
    {
      Sleep(100);
      EnumWindows(QuirkProbeFindDialog, (LPARAM)&search);
    }
  if (search.found != NULL)
    {
      HWND dialog = search.found;

      /* Let it finish setting itself up. */
      Sleep(700);
      script->found = YES;
      script->owner = GetWindow(dialog, GW_OWNER);
      GetWindowTextW(dialog, script->title, 128);
      for (index = 0; index < 4 && script->readControls[index] != 0; index++)
        {
          HWND control = QuirkProbeDialogControl(dialog, script->readControls[index]);

          if (control != NULL)
            {
              GetWindowTextW(control, script->read[index], 260);
              script->readChecked[index]
                = (SendMessageW(control, BM_GETCHECK, 0, 0) == BST_CHECKED);
            }
        }
      if (script->clickControl != 0)
        {
          HWND control = QuirkProbeDialogControl(dialog, script->clickControl);

          if (control != NULL)
            {
              SendMessageW(control, BM_CLICK, 0, 0);
              Sleep(200);
            }
        }
      for (index = 0; index < 4 && script->controls[index] != 0; index++)
        {
          HWND control = QuirkProbeDialogControl(dialog, script->controls[index]);

          if (control != NULL)
            {
              SendMessageW(control, WM_SETTEXT, 0, (LPARAM)script->texts[index]);
            }
        }
      Sleep(200);
      PostMessageW(dialog, WM_COMMAND,
                   MAKEWPARAM(script->cancel ? IDCANCEL : IDOK, BN_CLICKED),
                   (LPARAM)GetDlgItem(dialog, script->cancel ? IDCANCEL : IDOK));
    }
  InterlockedExchange(&script->done, 1);
  return 0;
}

static HANDLE
QuirkProbeStartDialogThread(QuirkProbeDialogScript *script)
{
  script->process = GetCurrentProcessId();
  return CreateThread(NULL, 0, QuirkProbeDialogThread, script, 0, NULL);
}

static void
QuirkProbeStopDialogThread(QuirkProbeDialogScript *script, HANDLE thread)
{
  InterlockedExchange(&script->stop, 1);
  if (thread != NULL)
    {
      WaitForSingleObject(thread, 15000);
      CloseHandle(thread);
    }
}

static void
QuirkProbeFinishDialogThread(HANDLE thread)
{
  if (thread != NULL)
    {
      WaitForSingleObject(thread, 15000);
      CloseHandle(thread);
    }
}

static NSString *
QuirkProbeWide(const WCHAR *string)
{
  return [NSString stringWithCharacters: (const unichar *)string length: wcslen(string)];
}

static NSString *
QuirkProbeComparablePath(NSString *path)
{
  return [[[path stringByReplacingOccurrencesOfString: @"\\" withString: @"/"]
            stringByStandardizingPath] lowercaseString];
}

static HWND
QuirkProbeWindowHandle(NSWindow *window)
{
  return [window respondsToSelector: @selector(windowHandle)] ? (HWND)[window windowHandle] : NULL;
}

/* Stops a GNUstep panel the theme left to GNUstep, from its modal loop. */
@interface QuirkProbeGNUstepPanelWatch : NSObject
{
@public
  NSWindow *panel;
  BOOL seen;
}
- (void) look: (NSTimer *)timer;
@end

@implementation QuirkProbeGNUstepPanelWatch
/* GNUstep's print panel can be a window of its own nib's, not the object
   +printPanel returns: any visible modal window is GNUstep's panel. */
- (void) look: (NSTimer *)timer
{
  if (seen == NO && ([panel isVisible] || [[NSApp modalWindow] isVisible]))
    {
      seen = YES;
      [NSApp stopModalWithCode: NSCancelButton];
      /* The modal loop sees the stop only after its next event. */
      [NSApp postEvent: [NSEvent otherEventWithType: NSApplicationDefined
                                           location: NSZeroPoint
                                      modifierFlags: 0
                                          timestamp: 0
                                       windowNumber: 0
                                            context: nil
                                            subtype: 0
                                              data1: 0
                                              data2: 0]
               atStart: NO];
    }
}
@end

/* A view that isn't a document's type pop-up. */
static NSView *
QuirkProbeAccessoryView(void)
{
  NSView *view = AUTORELEASE([[NSView alloc] initWithFrame: NSMakeRect(0, 0, 200, 30)]);
  NSButton *box = AUTORELEASE([[NSButton alloc] initWithFrame: NSMakeRect(0, 0, 200, 24)]);

  [box setButtonType: NSSwitchButton];
  [box setTitle: @"Probe option"];
  [view addSubview: box];
  return view;
}

/* NSDocument's save panel accessory: a "File Type" box with the pop-up
   that sends -changeSaveType: to the document. */
static NSView *
QuirkProbeDocumentTypeAccessory(NSDocument *document)
{
  NSBox *box = AUTORELEASE([[NSBox alloc] initWithFrame: NSMakeRect(0, 0, 380, 70)]);
  NSPopUpButton *button = AUTORELEASE([[NSPopUpButton alloc] initWithFrame: NSMakeRect(20, 10, 340, 24)]);

  [box setTitle: @"File Type"];
  [button addItemWithTitle: @"Text"];
  [button setTarget: document];
  [button setAction: @selector(changeSaveType:)];
  [box addSubview: button];
  return box;
}

@interface QuirkProbeFilteringDelegate : NSObject
@end

@implementation QuirkProbeFilteringDelegate
- (BOOL) panel: (id)sender shouldEnableURL: (NSURL *)url
{
  return YES;
}
@end

#endif

@implementation QuirkProbe (Dialogs)

#ifdef _WIN32
/* Runs `panel` with the GNUstep watch: YES when GNUstep's own panel came
   up (and was stopped), NO when the native dialog ran (the thread script
   cancels it). */
- (BOOL) runPanelExpectingGNUstep: (NSSavePanel *)panel script: (QuirkProbeDialogScript *)script
{
  QuirkProbeGNUstepPanelWatch *watch = AUTORELEASE([QuirkProbeGNUstepPanelWatch new]);
  NSTimer *timer = [NSTimer timerWithTimeInterval: 0.5
                                           target: watch
                                         selector: @selector(look:)
                                         userInfo: nil
                                          repeats: YES];
  HANDLE thread = NULL;

  watch->panel = panel;
  script->cancel = YES;
  thread = QuirkProbeStartDialogThread(script);
  [[NSRunLoop currentRunLoop] addTimer: timer forMode: NSModalPanelRunLoopMode];
  [panel runModal];
  [timer invalidate];
  [panel orderOut: nil];
  if (watch->seen == NO)
    {
      QuirkProbeFinishDialogThread(thread);
    }
  else
    {
      QuirkProbeStopDialogThread(script, thread);
    }
  return watch->seen;
}
#endif

- (void) checkPrintDialog
{
#ifdef _WIN32
  NSArray *ids = [NSArray arrayWithObjects: @"print-dialog-writes-back",
                          @"print-dialog-cancel", @"print-dialog-accessory-falls-back",
                          @"page-setup-round-trip", nil];
  NSString *printerName = @"Microsoft Print to PDF";
  NSPrinter *printer = [NSPrinter printerWithName: printerName];
  NSPrintPanel *panel = [NSPrintPanel printPanel];
  NSPrintInfo *info = nil;
  NSMutableDictionary *dict = nil;
  QuirkProbeDialogScript script;
  HANDLE thread = NULL;
  NSInteger result;
  NSEnumerator *enumerator = nil;
  NSString *check = nil;

  if ([NSStringFromClass([panel class]) isEqualToString: @"WinUIThemePrintPanel"] == NO || printer == nil)
    {
      enumerator = [ids objectEnumerator];
      while ((check = [enumerator nextObject]) != nil)
        {
          [self skip: check detail: (printer == nil)
                                      ? @"no \"Microsoft Print to PDF\" printer"
                                      : [NSString stringWithFormat: @"the print panel is %@", [panel class]]];
        }
      return;
    }

  /* Windows 11 shows its own print dialog in a process of its own, for
     PrintDlgW too, so Invoke-DialogCheck.ps1 drives it by UI Automation:
     it reports what the first dialog was seeded with
     (print-dialog-seeded), picks pages 2-4 in landscape and prints; it
     cancels the second. Here: seeded with pages 3-5 in portrait on Print
     to PDF. */
  info = AUTORELEASE([[NSPrintInfo sharedPrintInfo] copy]);
  [info setPrinter: printer];
  [info setOrientation: NSPortraitOrientation];
  dict = [info dictionary];
  [dict setObject: [NSNumber numberWithBool: NO] forKey: NSPrintAllPages];
  [dict setObject: [NSNumber numberWithInt: 3] forKey: NSPrintFirstPage];
  [dict setObject: [NSNumber numberWithInt: 5] forKey: NSPrintLastPage];
  if ([[NSUserDefaults standardUserDefaults] boolForKey: @"ProbeDrivesPrintDialog"] == NO)
    {
      [self skip: @"print-dialog-writes-back" detail: @"needs Invoke-DialogCheck.ps1's driver"];
      [self skip: @"print-dialog-cancel" detail: @"needs Invoke-DialogCheck.ps1's driver"];
    }
  else
    {
      result = [panel runModalWithPrintInfo: info];
      dict = [info dictionary];
      if (result == NSOKButton
          && [[dict objectForKey: NSPrintAllPages] boolValue] == NO
          && [[dict objectForKey: NSPrintFirstPage] intValue] == 2
          && [[dict objectForKey: NSPrintLastPage] intValue] == 4
          && [info orientation] == NSLandscapeOrientation
          && [[[info printer] name] isEqualToString: printerName])
        {
          [self pass: @"print-dialog-writes-back" detail:
            @"Print with pages 2-4 in landscape puts them in the print info"];
        }
      else
        {
          [self fail: @"print-dialog-writes-back" detail: [NSString stringWithFormat:
            @"returned %ld; print info: all pages %@, pages %@-%@, %@, printer %@",
            (long)result, [dict objectForKey: NSPrintAllPages],
            [dict objectForKey: NSPrintFirstPage], [dict objectForKey: NSPrintLastPage],
            [info orientation] == NSLandscapeOrientation ? @"landscape" : @"portrait",
            [[info printer] name]]];
        }

      /* Cancel: NSCancelButton, and not GNUstep's panel after it. */
      result = [panel runModalWithPrintInfo: info];
      if (result == NSCancelButton && [panel isVisible] == NO)
        {
          [self pass: @"print-dialog-cancel" detail: @"Cancel returns NSCancelButton"];
        }
      else
        {
          [self fail: @"print-dialog-cancel" detail: [NSString stringWithFormat:
            @"returned %ld, GNUstep's panel %@", (long)result,
            [panel isVisible] ? @"shown" : @"not shown"]];
        }
      [panel orderOut: nil];
    }

  /* An accessory view: GNUstep's panel, which can show it. */
  {
    QuirkProbeGNUstepPanelWatch *watch = AUTORELEASE([QuirkProbeGNUstepPanelWatch new]);
    NSTimer *timer = [NSTimer timerWithTimeInterval: 0.5 target: watch selector: @selector(look:)
                                           userInfo: nil repeats: YES];

    watch->panel = panel;
    memset(&script, 0, sizeof(script));
    script.cancel = YES;
    thread = QuirkProbeStartDialogThread(&script);
    [[NSRunLoop currentRunLoop] addTimer: timer forMode: NSModalPanelRunLoopMode];
    [panel setAccessoryView: QuirkProbeAccessoryView()];
    [panel runModalWithPrintInfo: info];
    [panel setAccessoryView: nil];
    [timer invalidate];
    [panel orderOut: nil];
    if (watch->seen)
      {
        QuirkProbeStopDialogThread(&script, thread);
        [self pass: @"print-dialog-accessory-falls-back" detail: @"with an accessory view GNUstep's panel runs"];
      }
    else
      {
        QuirkProbeFinishDialogThread(thread);
        [self fail: @"print-dialog-accessory-falls-back" detail: @"with an accessory view the Windows dialog ran"];
      }
  }

  /* Page setup: seeded with a 1in left margin, portrait; the user picks
     landscape and 1.5in. */
  {
    NSPrintInfo *shared = RETAIN([NSPrintInfo sharedPrintInfo]);
    double seen = 0.0;
    double unit = 1.0;

    [info setOrientation: NSPortraitOrientation];
    [info setLeftMargin: 72.0];
    memset(&script, 0, sizeof(script));
    script.readControls[0] = QuirkProbeIDLeftMargin;
    script.clickControl = QuirkProbeIDLandscape;
    script.controls[0] = QuirkProbeIDLeftMargin;
    /* Inches or millimetres, as the locale has it; set below once known. */
    script.texts[0] = L"1.5";
    thread = QuirkProbeStartDialogThread(&script);
    /* Through the menu's Page Setup: +[NSPageLayout pageLayout] can't
       load its panel on Windows (gui 0.32). */
    [NSPrintInfo setSharedPrintInfo: info];
    [NSApp runPageLayout: nil];
    [NSPrintInfo setSharedPrintInfo: shared];
    RELEASE(shared);
    result = ([info orientation] == NSLandscapeOrientation) ? NSOKButton : NSCancelButton;
    QuirkProbeFinishDialogThread(thread);
    seen = wcstod(script.read[0], NULL);
    if (seen > 10.0)
      {
        /* Millimetres: "1.5" was 1.5mm. */
        unit = 25.4;
      }
    if (script.found == NO)
      {
        [self fail: @"page-setup-round-trip" detail: @"no Windows page setup dialog opened"];
      }
    else if (result == NSOKButton && fabs(seen - unit) < 0.05 * unit
             && [info orientation] == NSLandscapeOrientation
             && fabs([info leftMargin] - 1.5 * 72.0 / unit) < 1.5
             && script.owner == QuirkProbeWindowHandle([NSApp keyWindow]))
      {
        [self pass: @"page-setup-round-trip" detail: [NSString stringWithFormat:
          @"owned by the key window, seeded with the 1in margin; landscape and a %.1fpt margin come back",
          [info leftMargin]]];
      }
    else
      {
        [self fail: @"page-setup-round-trip" detail: [NSString stringWithFormat:
          @"returned %ld; the dialog showed a %@ left margin%@; print info %@, left margin %.1fpt",
          (long)result, QuirkProbeWide(script.read[0]),
          (script.owner == QuirkProbeWindowHandle([NSApp keyWindow])) ? @"" : @" and isn't owned by the key window",
          [info orientation] == NSLandscapeOrientation ? @"landscape" : @"portrait", [info leftMargin]]];
      }
  }
#else
  [self skip: @"print-dialog-writes-back" detail: @"Windows only"];
#endif
}

- (void) checkFileDialogsAtRunTime
{
#ifdef _WIN32
  NSArray *ids = [NSArray arrayWithObjects: @"file-dialog-open-returns-path", @"file-dialog-open-multiple",
                          @"file-dialog-save-returns-path", @"file-dialog-accessory-falls-back",
                          @"file-dialog-delegate-falls-back", @"file-dialog-opt-out",
                          @"file-dialog-document-accessory-native", nil];
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
                          [NSString stringWithFormat: @"quirkprobe-dialogs-%d",
                                                      [[NSProcessInfo processInfo] processIdentifier]]];
  NSString *first = [directory stringByAppendingPathComponent: @"first.txt"];
  NSString *second = [directory stringByAppendingPathComponent: @"second.txt"];
  NSOpenPanel *open = nil;
  NSSavePanel *save = nil;
  QuirkProbeDialogScript script;
  HANDLE thread = NULL;
  NSInteger result;
  WCHAR wide[600];
  NSString *typed = nil;

  if ([NSStringFromClass([[NSOpenPanel openPanel] class]) isEqualToString: @"WinUIThemeOpenPanel"] == NO)
    {
      NSEnumerator *enumerator = [ids objectEnumerator];
      NSString *check = nil;

      while ((check = [enumerator nextObject]) != nil)
        {
          [self skip: check detail: @"the theme's panels aren't in use"];
        }
      return;
    }
  [manager createDirectoryAtPath: directory withIntermediateDirectories: YES attributes: nil error: NULL];
  [@"one" writeToFile: first atomically: NO];
  [@"two" writeToFile: second atomically: NO];

  /* Open: the name typed in comes back as the panel's file. */
  open = [NSOpenPanel openPanel];
  [open setDirectory: directory];
  [open setAllowsMultipleSelection: NO];
  memset(&script, 0, sizeof(script));
  typed = [first stringByReplacingOccurrencesOfString: @"/" withString: @"\\"];
  [typed getCharacters: (unichar *)wide];
  wide[[typed length]] = 0;
  script.controls[0] = QuirkProbeIDOpenName;
  script.texts[0] = wide;
  thread = QuirkProbeStartDialogThread(&script);
  result = [open runModal];
  QuirkProbeFinishDialogThread(thread);
  if (script.found && result == NSOKButton && [[open filenames] count] == 1
      && [QuirkProbeComparablePath([[open filenames] objectAtIndex: 0]) isEqualToString: QuirkProbeComparablePath(first)])
    {
      [self pass: @"file-dialog-open-returns-path" detail: @"the file picked in the Open dialog is the panel's"];
    }
  else
    {
      [self fail: @"file-dialog-open-returns-path" detail: [NSString stringWithFormat:
        @"dialog %@, returned %ld, files %@", script.found ? @"shown" : @"not shown",
        (long)result, [open filenames]]];
    }

  /* Open, several: two names typed in. */
  open = [NSOpenPanel openPanel];
  [open setDirectory: directory];
  [open setAllowsMultipleSelection: YES];
  memset(&script, 0, sizeof(script));
  script.controls[0] = QuirkProbeIDOpenName;
  script.texts[0] = L"\"first.txt\" \"second.txt\"";
  thread = QuirkProbeStartDialogThread(&script);
  result = [open runModal];
  QuirkProbeFinishDialogThread(thread);
  {
    NSMutableSet *names = [NSMutableSet set];
    NSEnumerator *enumerator = [[open filenames] objectEnumerator];
    NSString *path = nil;

    while ((path = [enumerator nextObject]) != nil)
      {
        [names addObject: QuirkProbeComparablePath(path)];
      }
    if (script.found && result == NSOKButton && [names count] == 2
        && [names containsObject: QuirkProbeComparablePath(first)]
        && [names containsObject: QuirkProbeComparablePath(second)])
      {
        [self pass: @"file-dialog-open-multiple" detail: @"both files picked come back"];
      }
    else
      {
        [self fail: @"file-dialog-open-multiple" detail: [NSString stringWithFormat:
          @"dialog %@, returned %ld, files %@", script.found ? @"shown" : @"not shown",
          (long)result, [open filenames]]];
      }
  }

  /* Save: the name typed in, in the panel's folder. */
  save = [NSSavePanel savePanel];
  [save setDirectory: directory];
  memset(&script, 0, sizeof(script));
  script.controls[0] = QuirkProbeIDSaveName;
  script.texts[0] = L"saved-by-probe.txt";
  thread = QuirkProbeStartDialogThread(&script);
  result = [save runModal];
  QuirkProbeFinishDialogThread(thread);
  if (script.found && result == NSOKButton
      && [QuirkProbeComparablePath([save filename])
           isEqualToString: QuirkProbeComparablePath([directory stringByAppendingPathComponent: @"saved-by-probe.txt"])])
    {
      [self pass: @"file-dialog-save-returns-path" detail: @"the name given in the Save dialog is the panel's file"];
    }
  else
    {
      [self fail: @"file-dialog-save-returns-path" detail: [NSString stringWithFormat:
        @"dialog %@, returned %ld, file %@", script.found ? @"shown" : @"not shown",
        (long)result, [save filename]]];
    }

  /* The fallbacks to GNUstep's panel. */
  open = [NSOpenPanel openPanel];
  [open setDirectory: directory];
  [open setAccessoryView: QuirkProbeAccessoryView()];
  memset(&script, 0, sizeof(script));
  if ([self runPanelExpectingGNUstep: open script: &script])
    {
      [self pass: @"file-dialog-accessory-falls-back" detail: @"with an accessory view GNUstep's panel runs"];
    }
  else
    {
      [self fail: @"file-dialog-accessory-falls-back" detail: @"with an accessory view the Windows dialog ran"];
    }
  [open setAccessoryView: nil];

  open = [NSOpenPanel openPanel];
  [open setDirectory: directory];
  [open setDelegate: AUTORELEASE([QuirkProbeFilteringDelegate new])];
  memset(&script, 0, sizeof(script));
  if ([self runPanelExpectingGNUstep: open script: &script])
    {
      [self pass: @"file-dialog-delegate-falls-back" detail: @"a delegate that filters gets GNUstep's panel"];
    }
  else
    {
      [self fail: @"file-dialog-delegate-falls-back" detail: @"a delegate that filters got the Windows dialog"];
    }
  [open setDelegate: nil];

  [[NSUserDefaults standardUserDefaults] setBool: NO forKey: @"WinUIThemeNativeFileDialogs"];
  open = [NSOpenPanel openPanel];
  [open setDirectory: directory];
  memset(&script, 0, sizeof(script));
  if ([self runPanelExpectingGNUstep: open script: &script])
    {
      [self pass: @"file-dialog-opt-out" detail: @"WinUIThemeNativeFileDialogs NO gives GNUstep's panel"];
    }
  else
    {
      [self fail: @"file-dialog-opt-out" detail: @"WinUIThemeNativeFileDialogs NO still ran the Windows dialog"];
    }
  [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"WinUIThemeNativeFileDialogs"];

  /* NSDocument's File Type accessory keeps the Windows dialog, whose type
     filters stand in for it; Cancel there is NSCancelButton. */
  {
    NSDocument *document = AUTORELEASE([NSDocument new]);

    save = [NSSavePanel savePanel];
    [save setDirectory: directory];
    [save setAccessoryView: QuirkProbeDocumentTypeAccessory(document)];
    memset(&script, 0, sizeof(script));
    if ([self runPanelExpectingGNUstep: save script: &script] == NO && script.found)
      {
        [self pass: @"file-dialog-document-accessory-native" detail:
          @"NSDocument's File Type box keeps the Windows dialog; Cancel cancels"];
      }
    else
      {
        [self fail: @"file-dialog-document-accessory-native" detail:
          @"NSDocument's File Type box sent the panel to GNUstep's"];
      }
    [save setAccessoryView: nil];
  }

  [manager removeFileAtPath: directory handler: nil];
#else
  [self skip: @"file-dialog-open-returns-path" detail: @"Windows only"];
#endif
}

@end
