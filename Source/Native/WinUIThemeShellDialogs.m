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

#import "WinUIThemeShellDialogs.h"

#include <Foundation/Foundation.h>

#ifdef _WIN32
#ifndef WINVER
#define WINVER 0x0601
#endif
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0601
#endif
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#define COBJMACROS
#ifndef interface
#define interface struct
#define WINUITHEME_DEFINED_INTERFACE_MACRO 1
#endif
#include <windows.h>
#include <commdlg.h>
#include <shobjidl.h>
#include <wchar.h>
#ifdef WINUITHEME_DEFINED_INTERFACE_MACRO
#undef interface
#undef WINUITHEME_DEFINED_INTERFACE_MACRO
#endif
#endif

@interface WinUIThemeOpenPanel ()
{
  NSArray *_selectedFilenames;
}
@end

@interface WinUIThemeSavePanel (WinUIThemePrivateState)
- (void) _winUIThemeSetNativeSavePath: (NSString *)path;
@end

@interface WinUIThemeOpenPanel (WinUIThemePrivateState)
- (void) _winUIThemeSetNativeSelectedPaths: (NSArray *)paths;
@end

static void
WinUIThemeInvokeModalDelegate(id delegate,
                              SEL selector,
                              id panel,
                              NSInteger returnCode,
                              void *contextInfo)
{
  if (delegate != nil && selector != NULL && [delegate respondsToSelector: selector])
    {
      typedef void (*DidEndIMP)(id, SEL, id, NSInteger, void *);
      DidEndIMP implementation = (DidEndIMP)[delegate methodForSelector: selector];

      if (implementation != NULL)
        {
          implementation(delegate, selector, panel, returnCode, contextInfo);
        }
    }
}

#pragma mark File type filters (#76)

/* Extensions that name one format. Windows registers each apart, often
   with names of their own ("JPG File", "JPEG File"), so they're merged into
   one filter whatever the registry says. */
static BOOL
WinUIThemeExtensionsAreAliases(NSString *first, NSString *second)
{
  static NSArray *groups = nil;
  NSUInteger index = 0;

  if ([first caseInsensitiveCompare: second] == NSOrderedSame)
    {
      return YES;
    }
  if (groups == nil)
    {
      groups = [[NSArray alloc] initWithObjects:
        [NSArray arrayWithObjects: @"jpg", @"jpeg", @"jpe", @"jfif", nil],
        [NSArray arrayWithObjects: @"tif", @"tiff", nil],
        [NSArray arrayWithObjects: @"htm", @"html", nil],
        [NSArray arrayWithObjects: @"mpg", @"mpeg", nil],
        [NSArray arrayWithObjects: @"mid", @"midi", nil],
        [NSArray arrayWithObjects: @"aif", @"aiff", nil],
        [NSArray arrayWithObjects: @"yml", @"yaml", nil],
        nil];
    }

  for (index = 0; index < [groups count]; index++)
    {
      NSArray *group = [groups objectAtIndex: index];

      if ([group containsObject: [first lowercaseString]]
          && [group containsObject: [second lowercaseString]])
        {
          return YES;
        }
    }
  return NO;
}

/* The dialogs' own words, from the app's strings when it translates them,
   else English. */
static NSString *
WinUIThemeFileDialogString(NSString *english)
{
  NSString *string = [[NSBundle mainBundle] localizedStringForKey: english
                                                            value: english
                                                            table: nil];

  return ([string length] > 0) ? string : english;
}

/* Windows' name for files with this extension ("PNG File", "Rich Text
   Format"), as Explorer's Type column shows it, or nil. */
static NSString *
WinUIThemeRegisteredTypeName(NSString *extension)
{
#ifdef _WIN32
  typedef HRESULT (WINAPI *AssocQueryStringWFunc)(DWORD flags,
                                                  int string,
                                                  LPCWSTR association,
                                                  LPCWSTR extra,
                                                  LPWSTR output,
                                                  DWORD *length);
  static AssocQueryStringWFunc function = NULL;
  static BOOL looked = NO;
  const int friendlyDocName = 3; /* ASSOCSTR_FRIENDLYDOCNAME */
  NSString *dotted = [@"." stringByAppendingString: extension];
  NSUInteger dottedLength = [dotted length];
  WCHAR association[64];
  WCHAR buffer[260];
  DWORD length = 260;
  HRESULT result = E_FAIL;
  NSString *name = nil;

  if (looked == NO)
    {
      HMODULE module = GetModuleHandleW(L"shlwapi.dll");

      if (module == NULL)
        {
          module = LoadLibraryW(L"shlwapi.dll");
        }
      if (module != NULL)
        {
          function = (AssocQueryStringWFunc)GetProcAddress(module, "AssocQueryStringW");
        }
      looked = YES;
    }
  if (function == NULL)
    {
      return nil;
    }

  if (dottedLength >= 64)
    {
      return nil;
    }
  [dotted getCharacters: (unichar *)association];
  association[dottedLength] = 0;
  buffer[0] = 0;
  result = function(0, friendlyDocName, association, NULL, buffer, &length);
  if (SUCCEEDED(result) && result != S_FALSE)
    {
      buffer[259] = 0;
      name = [[NSString stringWithCharacters: (const unichar *)buffer
                                      length: wcslen(buffer)]
               stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
  return ([name length] > 0) ? name : nil;
#else
  (void)extension;
  return nil;
#endif
}

/* The extensions in an allowed-types list: "png", ".png" and "*.png" are
   the same; blanks, wildcards and repeats (in any case) are dropped. */
static NSArray *
WinUIThemeFilterExtensions(NSArray *types)
{
  NSMutableArray *extensions = [NSMutableArray array];
  NSCharacterSet *invalid = [NSCharacterSet characterSetWithCharactersInString: @"*?;/\\"];
  NSUInteger index = 0;

  for (index = 0; index < [types count]; index++)
    {
      id entry = [types objectAtIndex: index];
      NSString *extension = nil;
      NSUInteger existing = 0;
      BOOL repeated = NO;

      if ([entry isKindOfClass: [NSString class]] == NO)
        {
          continue;
        }

      extension = [(NSString *)entry stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
      if ([extension hasPrefix: @"*"])
        {
          extension = [extension substringFromIndex: 1];
        }
      if ([extension hasPrefix: @"."])
        {
          extension = [extension substringFromIndex: 1];
        }
      if ([extension length] == 0
          || [extension rangeOfCharacterFromSet: invalid].location != NSNotFound)
        {
          continue;
        }

      for (existing = 0; existing < [extensions count]; existing++)
        {
          if ([[extensions objectAtIndex: existing] caseInsensitiveCompare: extension]
              == NSOrderedSame)
            {
              repeated = YES;
              break;
            }
        }
      if (repeated == NO)
        {
          [extensions addObject: extension];
        }
    }

  return extensions;
}

static NSString *
WinUIThemeFilterPattern(NSArray *extensions)
{
  NSMutableArray *patterns = [NSMutableArray array];
  NSUInteger index = 0;

  for (index = 0; index < [extensions count]; index++)
    {
      [patterns addObject: [@"*." stringByAppendingString: [extensions objectAtIndex: index]]];
    }
  return [patterns componentsJoinedByString: @";"];
}

static NSDictionary *
WinUIThemeFilter(NSString *name, NSString *pattern)
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
    [NSString stringWithFormat: @"%@ (%@)", name, pattern], @"name",
    pattern, @"pattern",
    nil];
}

/* The filters a native Open or Save dialog offers for an allowed-types
   list (#76), as dictionaries of "name" (as the dialog lists it) and
   "pattern" ("*.jpg;*.jpeg"), with the one to select in *selectedIndex.

   - One filter per type, named from the registry ("PNG File (*.png)"), or
     "PNG files" when Windows has no name. Extensions of one format (jpg
     and jpeg) or with one registered name (htm and html) share a filter.
   - An Open dialog with more than one type starts with "All supported
     files", selected, so it shows everything the app can open, as
     NSOpenPanel does.
   - A Save dialog selects the type of the name it suggests, or the first.
   - "All files (*.*)" comes last when the panel allows other types.
   - No types, no filters: the dialog shows every file. */
static NSArray *
WinUIThemeFileDialogFilters(NSArray *types,
                            BOOL saving,
                            BOOL allowsOtherFileTypes,
                            NSString *fileName,
                            NSUInteger *selectedIndex)
{
  NSArray *extensions = WinUIThemeFilterExtensions(types);
  NSMutableArray *groupNames = [NSMutableArray array];
  NSMutableArray *groupExtensions = [NSMutableArray array];
  NSMutableArray *filters = [NSMutableArray array];
  NSString *nameExtension = [fileName pathExtension];
  NSUInteger selected = 0;
  BOOL nameMatched = NO;
  NSUInteger index = 0;

  if (selectedIndex != NULL)
    {
      *selectedIndex = 0;
    }
  if ([extensions count] == 0)
    {
      return filters;
    }

  for (index = 0; index < [extensions count]; index++)
    {
      NSString *extension = [extensions objectAtIndex: index];
      NSString *name = WinUIThemeRegisteredTypeName(extension);
      NSUInteger group = 0;
      BOOL merged = NO;

      for (group = 0; group < [groupExtensions count] && merged == NO; group++)
        {
          NSMutableArray *members = [groupExtensions objectAtIndex: group];
          NSUInteger member = 0;

          if (name != nil
              && [[groupNames objectAtIndex: group] caseInsensitiveCompare: name] == NSOrderedSame)
            {
              merged = YES;
            }
          for (member = 0; member < [members count] && merged == NO; member++)
            {
              merged = WinUIThemeExtensionsAreAliases([members objectAtIndex: member], extension);
            }
          if (merged)
            {
              [members addObject: extension];
            }
        }
      if (merged == NO)
        {
          if (name == nil)
            {
              name = [NSString stringWithFormat: WinUIThemeFileDialogString(@"%@ files"),
                               [extension uppercaseString]];
            }
          [groupNames addObject: name];
          [groupExtensions addObject: [NSMutableArray arrayWithObject: extension]];
        }
    }

  if (saving == NO && [groupExtensions count] > 1)
    {
      [filters addObject: WinUIThemeFilter(WinUIThemeFileDialogString(@"All supported files"),
                                           WinUIThemeFilterPattern(extensions))];
    }
  for (index = 0; index < [groupExtensions count]; index++)
    {
      NSArray *members = [groupExtensions objectAtIndex: index];
      NSUInteger member = 0;

      if (saving && nameMatched == NO && [nameExtension length] > 0)
        {
          for (member = 0; member < [members count]; member++)
            {
              if ([[members objectAtIndex: member] caseInsensitiveCompare: nameExtension]
                  == NSOrderedSame)
                {
                  selected = [filters count];
                  nameMatched = YES;
                }
            }
        }
      [filters addObject: WinUIThemeFilter([groupNames objectAtIndex: index],
                                           WinUIThemeFilterPattern(members))];
    }
  if (allowsOtherFileTypes)
    {
      /* A suggested name of another type keeps its extension. */
      if (saving && nameMatched == NO && [nameExtension length] > 0)
        {
          selected = [filters count];
        }
      [filters addObject: [NSDictionary dictionaryWithObjectsAndKeys:
        [NSString stringWithFormat: @"%@ (*.*)", WinUIThemeFileDialogString(@"All files")], @"name",
        @"*.*", @"pattern",
        nil]];
    }

  if (selectedIndex != NULL)
    {
      *selectedIndex = selected;
    }
  return filters;
}

#ifdef _WIN32
typedef HRESULT (WINAPI *WinUIThemeCoInitializeExFunc)(LPVOID reserved,
                                                       DWORD coInit);
typedef void (WINAPI *WinUIThemeCoUninitializeFunc)(void);
typedef HRESULT (WINAPI *WinUIThemeCoCreateInstanceFunc)(REFCLSID rclsid,
                                                         LPUNKNOWN outer,
                                                         DWORD classContext,
                                                         REFIID riid,
                                                         LPVOID *object);
typedef void (WINAPI *WinUIThemeCoTaskMemFreeFunc)(LPVOID memory);
typedef HRESULT (WINAPI *WinUIThemeSHCreateItemFromParsingNameFunc)(PCWSTR path,
                                                                    IBindCtx *bindContext,
                                                                    REFIID riid,
                                                                    void **item);
typedef BOOL (WINAPI *WinUIThemePrintDlgWFunc)(LPPRINTDLGW dialog);
typedef BOOL (WINAPI *WinUIThemePageSetupDlgWFunc)(LPPAGESETUPDLGW dialog);

static FARPROC
WinUIThemeGetOptionalSystemProcedure(const WCHAR *libraryName,
                                     const char *procedureName)
{
  HMODULE module = GetModuleHandleW(libraryName);

  if (module == NULL)
    {
      module = LoadLibraryW(libraryName);
    }
  if (module == NULL)
    {
      return NULL;
    }

  return GetProcAddress(module, procedureName);
}

static HRESULT
WinUIThemeCoInitializeEx(LPVOID reserved, DWORD coInit)
{
  WinUIThemeCoInitializeExFunc function
    = (WinUIThemeCoInitializeExFunc)WinUIThemeGetOptionalSystemProcedure(L"ole32.dll",
                                                                         "CoInitializeEx");

  if (function == NULL)
    {
      return HRESULT_FROM_WIN32(ERROR_PROC_NOT_FOUND);
    }

  return function(reserved, coInit);
}

static HRESULT
WinUIThemeCoCreateInstance(REFCLSID rclsid,
                           LPUNKNOWN outer,
                           DWORD classContext,
                           REFIID riid,
                           LPVOID *object)
{
  WinUIThemeCoCreateInstanceFunc function
    = (WinUIThemeCoCreateInstanceFunc)WinUIThemeGetOptionalSystemProcedure(L"ole32.dll",
                                                                           "CoCreateInstance");

  if (function == NULL)
    {
      return HRESULT_FROM_WIN32(ERROR_PROC_NOT_FOUND);
    }

  return function(rclsid, outer, classContext, riid, object);
}

static void
WinUIThemeCoTaskMemFree(LPVOID memory)
{
  WinUIThemeCoTaskMemFreeFunc function
    = (WinUIThemeCoTaskMemFreeFunc)WinUIThemeGetOptionalSystemProcedure(L"ole32.dll",
                                                                        "CoTaskMemFree");

  if (function != NULL)
    {
      function(memory);
    }
}

static void
WinUIThemeCoUninitialize(void)
{
  WinUIThemeCoUninitializeFunc function
    = (WinUIThemeCoUninitializeFunc)WinUIThemeGetOptionalSystemProcedure(L"ole32.dll",
                                                                         "CoUninitialize");

  if (function != NULL)
    {
      function();
    }
}

static HRESULT
WinUIThemeSHCreateItemFromParsingName(PCWSTR path,
                                      IBindCtx *bindContext,
                                      REFIID riid,
                                      void **item)
{
  WinUIThemeSHCreateItemFromParsingNameFunc function
    = (WinUIThemeSHCreateItemFromParsingNameFunc)WinUIThemeGetOptionalSystemProcedure(L"shell32.dll",
                                                                                       "SHCreateItemFromParsingName");

  if (function == NULL)
    {
      return HRESULT_FROM_WIN32(ERROR_PROC_NOT_FOUND);
    }

  return function(path, bindContext, riid, item);
}

static BOOL
WinUIThemePrintDlgW(LPPRINTDLGW dialog)
{
  WinUIThemePrintDlgWFunc function
    = (WinUIThemePrintDlgWFunc)WinUIThemeGetOptionalSystemProcedure(L"comdlg32.dll",
                                                                    "PrintDlgW");

  if (function == NULL)
    {
      SetLastError(ERROR_PROC_NOT_FOUND);
      return FALSE;
    }

  return function(dialog);
}

static BOOL
WinUIThemePageSetupDlgW(LPPAGESETUPDLGW dialog)
{
  WinUIThemePageSetupDlgWFunc function
    = (WinUIThemePageSetupDlgWFunc)WinUIThemeGetOptionalSystemProcedure(L"comdlg32.dll",
                                                                        "PageSetupDlgW");

  if (function == NULL)
    {
      SetLastError(ERROR_PROC_NOT_FOUND);
      return FALSE;
    }

  return function(dialog);
}

static NSString *
WinUIThemeNormalizedGNUstepPath(NSString *path)
{
  NSString *normalized = nil;

  if (path == nil || [path length] == 0)
    {
      return nil;
    }

  normalized = [path stringByReplacingOccurrencesOfString: @"\\"
                                               withString: @"/"];
  return [normalized stringByStandardizingPath];
}

static NSString *
WinUIThemeWindowsPathString(NSString *path)
{
  NSString *normalized = WinUIThemeNormalizedGNUstepPath(path);

  if (normalized == nil)
    {
      return nil;
    }

  return [normalized stringByReplacingOccurrencesOfString: @"/"
                                               withString: @"\\"];
}

static WCHAR *
WinUIThemeCopyWideString(NSString *string)
{
  NSUInteger length = 0;
  unichar *buffer = NULL;

  if (string == nil || [string length] == 0)
    {
      return NULL;
    }

  length = [string length];
  buffer = calloc(length + 1, sizeof(unichar));
  if (buffer == NULL)
    {
      return NULL;
    }

  [string getCharacters: buffer];
  buffer[length] = 0;
  return (WCHAR *)buffer;
}

static NSString *
WinUIThemeStringFromWideString(const WCHAR *string)
{
  size_t length = 0;

  if (string == NULL)
    {
      return nil;
    }

  length = wcslen(string);
  if (length == 0)
    {
      return @"";
    }

  return [NSString stringWithCharacters: (const unichar *)string
                                 length: (NSUInteger)length];
}

static HWND
WinUIThemeOwnerWindowHandle(NSWindow *window)
{
  if (window == nil)
    {
      window = [NSApp keyWindow];
    }
  if (window == nil)
    {
      window = [NSApp mainWindow];
    }
  if (window != nil && [window respondsToSelector: @selector(windowHandle)])
    {
      return (HWND)[window windowHandle];
    }

  return NULL;
}

static HRESULT
WinUIThemeCreateShellItemForPath(NSString *path, IShellItem **item)
{
  NSString *windowsPath = WinUIThemeWindowsPathString(path);
  WCHAR *widePath = NULL;
  HRESULT result = E_INVALIDARG;

  if (item != NULL)
    {
      *item = NULL;
    }
  if (windowsPath == nil || item == NULL)
    {
      return E_INVALIDARG;
    }

  widePath = WinUIThemeCopyWideString(windowsPath);
  if (widePath == NULL)
    {
      return E_OUTOFMEMORY;
    }

  result = WinUIThemeSHCreateItemFromParsingName(widePath,
                                                 NULL,
                                                 &IID_IShellItem,
                                                 (void **)item);
  free(widePath);
  return result;
}

static NSString *
WinUIThemePathFromShellItem(IShellItem *item)
{
  PWSTR nativePath = NULL;
  NSString *path = nil;

  if (item == NULL)
    {
      return nil;
    }

  if (FAILED(IShellItem_GetDisplayName(item, SIGDN_FILESYSPATH, &nativePath)))
    {
      return nil;
    }

  path = WinUIThemeNormalizedGNUstepPath(WinUIThemeStringFromWideString(nativePath));
  WinUIThemeCoTaskMemFree(nativePath);
  return path;
}

static COMDLG_FILTERSPEC *
WinUIThemeCreateFilterSpecs(NSArray *filters)
{
  COMDLG_FILTERSPEC *specs = NULL;
  NSUInteger index = 0;

  if ([filters count] == 0)
    {
      return NULL;
    }

  specs = calloc([filters count], sizeof(COMDLG_FILTERSPEC));
  if (specs == NULL)
    {
      return NULL;
    }

  for (index = 0; index < [filters count]; index++)
    {
      NSDictionary *filter = [filters objectAtIndex: index];

      specs[index].pszName = WinUIThemeCopyWideString([filter objectForKey: @"name"]);
      specs[index].pszSpec = WinUIThemeCopyWideString([filter objectForKey: @"pattern"]);
    }

  return specs;
}

static void
WinUIThemeDestroyFilterSpecs(COMDLG_FILTERSPEC *specs, UINT count)
{
  UINT index = 0;

  if (specs == NULL)
    {
      return;
    }

  for (index = 0; index < count; index++)
    {
      free((void *)specs[index].pszName);
      free((void *)specs[index].pszSpec);
    }
  free(specs);
}

static void
WinUIThemeConfigureDialogTitle(IFileDialog *dialog, NSString *title)
{
  WCHAR *wideTitle = NULL;

  if (dialog == NULL || [title length] == 0)
    {
      return;
    }

  wideTitle = WinUIThemeCopyWideString(title);
  if (wideTitle == NULL)
    {
      return;
    }

  IFileDialog_SetTitle(dialog, wideTitle);
  free(wideTitle);
}

static void
WinUIThemeConfigureDialogFolder(IFileDialog *dialog, NSString *directory)
{
  IShellItem *folderItem = NULL;

  if (dialog == NULL || [directory length] == 0)
    {
      return;
    }

  if (SUCCEEDED(WinUIThemeCreateShellItemForPath(directory, &folderItem)))
    {
      IFileDialog_SetFolder(dialog, folderItem);
      IFileDialog_SetDefaultFolder(dialog, folderItem);
      IShellItem_Release(folderItem);
    }
}

/* The name a save panel suggests, or nil. */
static NSString *
WinUIThemeSavePanelFileName(NSSavePanel *panel)
{
  NSString *filename = nil;

  if ([panel respondsToSelector: @selector(nameFieldStringValue)])
    {
      filename = [panel nameFieldStringValue];
    }
  if ([filename length] == 0)
    {
      filename = [[panel filename] lastPathComponent];
    }
  return ([filename length] > 0) ? filename : nil;
}

static void
WinUIThemeConfigureDialogFileTypes(IFileDialog *dialog,
                                   NSArray *types,
                                   BOOL saving,
                                   BOOL allowsOtherFileTypes,
                                   NSString *fileName)
{
  COMDLG_FILTERSPEC *specs = NULL;
  NSArray *filters = nil;
  NSUInteger selected = 0;
  UINT count = 0;

  if (dialog == NULL)
    {
      return;
    }

  filters = WinUIThemeFileDialogFilters(types, saving, allowsOtherFileTypes,
                                        fileName, &selected);
  specs = WinUIThemeCreateFilterSpecs(filters);
  count = (specs != NULL) ? (UINT)[filters count] : 0;
  if (specs != NULL && count > 0)
    {
      IFileDialog_SetFileTypes(dialog, count, specs);
      /* IFileDialog numbers the filters from 1. */
      IFileDialog_SetFileTypeIndex(dialog, (UINT)selected + 1);
      if (allowsOtherFileTypes == NO)
        {
          DWORD options = 0;

          if (SUCCEEDED(IFileDialog_GetOptions(dialog, &options)))
            {
              IFileDialog_SetOptions(dialog, options | FOS_STRICTFILETYPES);
            }
        }
    }

  WinUIThemeDestroyFilterSpecs(specs, count);
}

static void
WinUIThemeConfigureSaveDialogFilename(IFileSaveDialog *dialog,
                                      NSSavePanel *panel)
{
  NSString *filename = nil;
  NSString *requiredType = nil;
  WCHAR *wideString = NULL;

  if (dialog == NULL || panel == nil)
    {
      return;
    }

  filename = WinUIThemeSavePanelFileName(panel);
  if ([filename length] > 0)
    {
      wideString = WinUIThemeCopyWideString(filename);
      if (wideString != NULL)
        {
          IFileSaveDialog_SetFileName(dialog, wideString);
          free(wideString);
        }
    }

  requiredType = [panel requiredFileType];
  if ([requiredType length] > 0)
    {
      wideString = WinUIThemeCopyWideString(requiredType);
      if (wideString != NULL)
        {
          IFileSaveDialog_SetDefaultExtension(dialog, wideString);
          free(wideString);
        }
    }
}

static NSInteger
WinUIThemeUnavailableNativeDialogResult(void)
{
  return NSIntegerMin;
}

static BOOL WinUIThemeFilePanelNeedsGNUstep(NSSavePanel *panel);

static NSInteger
WinUIThemeRunNativeSaveDialog(WinUIThemeSavePanel *panel, NSWindow *ownerWindow)
{
  IFileSaveDialog *dialog = NULL;
  HRESULT result = S_OK;
  HRESULT initResult = S_OK;
  BOOL initializedCOM = NO;
  DWORD options = FOS_FORCEFILESYSTEM | FOS_PATHMUSTEXIST;
  IShellItem *item = NULL;
  NSString *path = nil;

  if (WinUIThemeFilePanelNeedsGNUstep(panel))
    {
      return WinUIThemeUnavailableNativeDialogResult();
    }
  initResult = WinUIThemeCoInitializeEx(NULL, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
  if (SUCCEEDED(initResult) || initResult == RPC_E_CHANGED_MODE)
    {
      initializedCOM = (SUCCEEDED(initResult) || initResult == S_FALSE);
    }

  result = WinUIThemeCoCreateInstance(&CLSID_FileSaveDialog,
                                      NULL,
                                      CLSCTX_INPROC_SERVER,
                                      &IID_IFileSaveDialog,
                                      (void **)&dialog);
  if (FAILED(result) || dialog == NULL)
    {
      if (initializedCOM)
        {
          WinUIThemeCoUninitialize();
        }
      return WinUIThemeUnavailableNativeDialogResult();
    }

  if ([panel canCreateDirectories] == NO)
    {
      options |= FOS_NOVALIDATE;
    }
  IFileSaveDialog_SetOptions(dialog, options);
  WinUIThemeConfigureDialogTitle((IFileDialog *)dialog, [panel title]);
  WinUIThemeConfigureDialogFolder((IFileDialog *)dialog, [panel directory]);
  WinUIThemeConfigureDialogFileTypes((IFileDialog *)dialog,
                                     [panel allowedFileTypes],
                                     YES,
                                     [panel allowsOtherFileTypes],
                                     WinUIThemeSavePanelFileName(panel));
  WinUIThemeConfigureSaveDialogFilename(dialog, panel);

  result = IFileDialog_Show((IFileDialog *)dialog, WinUIThemeOwnerWindowHandle(ownerWindow));
  if (result == HRESULT_FROM_WIN32(ERROR_CANCELLED))
    {
      IFileSaveDialog_Release(dialog);
      if (initializedCOM)
        {
          WinUIThemeCoUninitialize();
        }
      return NSCancelButton;
    }
  if (FAILED(result))
    {
      IFileSaveDialog_Release(dialog);
      if (initializedCOM)
        {
          WinUIThemeCoUninitialize();
        }
      return WinUIThemeUnavailableNativeDialogResult();
    }

  result = IFileSaveDialog_GetResult(dialog, &item);
  if (SUCCEEDED(result))
    {
      path = WinUIThemePathFromShellItem(item);
      IShellItem_Release(item);
    }

  if ([path length] > 0)
    {
      [panel _winUIThemeSetNativeSavePath: path];
    }

  IFileSaveDialog_Release(dialog);
  if (initializedCOM)
    {
      WinUIThemeCoUninitialize();
    }

  return ([path length] > 0) ? NSOKButton : NSCancelButton;
}

static NSInteger
WinUIThemeRunNativeOpenDialog(WinUIThemeOpenPanel *panel, NSWindow *ownerWindow)
{
  IFileOpenDialog *dialog = NULL;
  HRESULT result = S_OK;
  HRESULT initResult = S_OK;
  BOOL initializedCOM = NO;
  DWORD options = FOS_FORCEFILESYSTEM | FOS_PATHMUSTEXIST;
  NSMutableArray *selectedPaths = nil;

  /* GNUstep's panel answers -filenames itself after a run of its own. */
  [panel _winUIThemeSetNativeSelectedPaths: nil];
  if (WinUIThemeFilePanelNeedsGNUstep(panel))
    {
      return WinUIThemeUnavailableNativeDialogResult();
    }
  initResult = WinUIThemeCoInitializeEx(NULL, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
  if (SUCCEEDED(initResult) || initResult == RPC_E_CHANGED_MODE)
    {
      initializedCOM = (SUCCEEDED(initResult) || initResult == S_FALSE);
    }

  result = WinUIThemeCoCreateInstance(&CLSID_FileOpenDialog,
                                      NULL,
                                      CLSCTX_INPROC_SERVER,
                                      &IID_IFileOpenDialog,
                                      (void **)&dialog);
  if (FAILED(result) || dialog == NULL)
    {
      if (initializedCOM)
        {
          WinUIThemeCoUninitialize();
        }
      return WinUIThemeUnavailableNativeDialogResult();
    }

  if ([panel allowsMultipleSelection])
    {
      options |= FOS_ALLOWMULTISELECT;
    }
  if ([panel canChooseDirectories] && [panel canChooseFiles] == NO)
    {
      options |= FOS_PICKFOLDERS;
    }
  else
    {
      options |= FOS_FILEMUSTEXIST;
    }

  IFileOpenDialog_SetOptions(dialog, options);
  WinUIThemeConfigureDialogTitle((IFileDialog *)dialog, [panel title]);
  WinUIThemeConfigureDialogFolder((IFileDialog *)dialog, [panel directory]);
  WinUIThemeConfigureDialogFileTypes((IFileDialog *)dialog,
                                     [panel allowedFileTypes],
                                     NO,
                                     [panel allowsOtherFileTypes],
                                     nil);

  result = IFileDialog_Show((IFileDialog *)dialog, WinUIThemeOwnerWindowHandle(ownerWindow));
  if (result == HRESULT_FROM_WIN32(ERROR_CANCELLED))
    {
      IFileOpenDialog_Release(dialog);
      if (initializedCOM)
        {
          WinUIThemeCoUninitialize();
        }
      return NSCancelButton;
    }
  if (FAILED(result))
    {
      IFileOpenDialog_Release(dialog);
      if (initializedCOM)
        {
          WinUIThemeCoUninitialize();
        }
      return WinUIThemeUnavailableNativeDialogResult();
    }

  selectedPaths = [NSMutableArray array];
  if ([panel allowsMultipleSelection])
    {
      IShellItemArray *items = NULL;
      DWORD count = 0;
      DWORD index = 0;

      if (SUCCEEDED(IFileOpenDialog_GetResults(dialog, &items)) && items != NULL)
        {
          IShellItemArray_GetCount(items, &count);
          for (index = 0; index < count; index++)
            {
              IShellItem *item = NULL;
              NSString *path = nil;

              if (SUCCEEDED(IShellItemArray_GetItemAt(items, index, &item)) && item != NULL)
                {
                  path = WinUIThemePathFromShellItem(item);
                  if ([path length] > 0)
                    {
                      [selectedPaths addObject: path];
                    }
                  IShellItem_Release(item);
                }
            }
          IShellItemArray_Release(items);
        }
    }
  else
    {
      IShellItem *item = NULL;
      NSString *path = nil;

      if (SUCCEEDED(IFileOpenDialog_GetResult(dialog, &item)) && item != NULL)
        {
          path = WinUIThemePathFromShellItem(item);
          if ([path length] > 0)
            {
              [selectedPaths addObject: path];
            }
          IShellItem_Release(item);
        }
    }

  [panel _winUIThemeSetNativeSelectedPaths: selectedPaths];

  IFileOpenDialog_Release(dialog);
  if (initializedCOM)
    {
      WinUIThemeCoUninitialize();
    }

  return ([selectedPaths count] > 0) ? NSOKButton : NSCancelButton;
}

#pragma mark Print and page setup dialogs (#69)

/* winspool.drv, loaded when a dialog is seeded. */
typedef BOOL (WINAPI *WinUIThemeOpenPrinterWFunc)(LPWSTR name, LPHANDLE printer, LPVOID defaults);
typedef BOOL (WINAPI *WinUIThemeClosePrinterFunc)(HANDLE printer);
typedef LONG (WINAPI *WinUIThemeDocumentPropertiesWFunc)(HWND window, HANDLE printer, LPWSTR name,
                                                         PDEVMODEW output, PDEVMODEW input, DWORD mode);

/* Paper both Windows and GNUstep name, with its portrait size in points. */
typedef struct
{
  NSString *name;
  short paper;
  CGFloat width;
  CGFloat height;
} WinUIThemePaper;

static const WinUIThemePaper *
WinUIThemePapers(NSUInteger *count)
{
  static WinUIThemePaper papers[8];
  static BOOL ready = NO;

  if (ready == NO)
    {
      WinUIThemePaper list[8] = {
        { @"Letter", DMPAPER_LETTER, 612.0, 792.0 },
        { @"Legal", DMPAPER_LEGAL, 612.0, 1008.0 },
        { @"Executive", DMPAPER_EXECUTIVE, 522.0, 756.0 },
        { @"Tabloid", DMPAPER_TABLOID, 792.0, 1224.0 },
        { @"A3", DMPAPER_A3, 842.0, 1191.0 },
        { @"A4", DMPAPER_A4, 595.0, 842.0 },
        { @"A5", DMPAPER_A5, 420.0, 595.0 },
        { @"B5", DMPAPER_B5, 516.0, 729.0 },
      };

      memcpy(papers, list, sizeof(papers));
      ready = YES;
    }
  *count = sizeof(papers) / sizeof(papers[0]);
  return papers;
}

/* The owner's choice: GNUstep's own panels with `key` set to NO. */
static BOOL
WinUIThemeNativeDialogsEnabled(NSString *key)
{
  id value = [[NSUserDefaults standardUserDefaults] objectForKey: key];

  return (value == nil || [value boolValue]);
}

/* The print info's copies, collation, orientation and paper, in a DEVMODE
   the printer filled in. */
static void
WinUIThemeApplyPrintInfoToDevMode(NSPrintInfo *info, DEVMODEW *mode)
{
  NSDictionary *dict = [info dictionary];
  NSInteger copies = [[dict objectForKey: NSPrintCopies] integerValue];
  NSString *paperName = [info paperName];
  NSUInteger count = 0;
  const WinUIThemePaper *papers = WinUIThemePapers(&count);
  NSUInteger index;

  if (copies > 0)
    {
      mode->dmCopies = (short)MIN(copies, 9999);
      mode->dmFields |= DM_COPIES;
    }
  if ([dict objectForKey: NSPrintMustCollate] != nil)
    {
      mode->dmCollate = [[dict objectForKey: NSPrintMustCollate] boolValue] ? DMCOLLATE_TRUE : DMCOLLATE_FALSE;
      mode->dmFields |= DM_COLLATE;
    }
  mode->dmOrientation = ([info orientation] == NSLandscapeOrientation) ? DMORIENT_LANDSCAPE : DMORIENT_PORTRAIT;
  mode->dmFields |= DM_ORIENTATION;
  for (index = 0; [paperName length] > 0 && index < count; index++)
    {
      if ([paperName caseInsensitiveCompare: papers[index].name] == NSOrderedSame)
        {
          mode->dmPaperSize = papers[index].paper;
          mode->dmFields |= DM_PAPERSIZE;
          break;
        }
    }
}

/* What the dialog chose, back in the print info: paper, orientation and,
   from the print dialog, copies and collation. */
static void
WinUIThemeApplyDevModeToPrintInfo(HGLOBAL memory, NSPrintInfo *info, BOOL copies)
{
  DEVMODEW *mode = (memory != NULL) ? (DEVMODEW *)GlobalLock(memory) : NULL;
  NSMutableDictionary *dict = [info dictionary];
  NSUInteger count = 0;
  const WinUIThemePaper *papers = WinUIThemePapers(&count);
  NSUInteger index;

  if (mode == NULL)
    {
      return;
    }
  if (mode->dmFields & DM_PAPERSIZE)
    {
      for (index = 0; index < count; index++)
        {
          if (papers[index].paper == mode->dmPaperSize)
            {
              [info setPaperName: papers[index].name];
              [info setPaperSize: NSMakeSize(papers[index].width, papers[index].height)];
              break;
            }
        }
    }
  if (mode->dmFields & DM_ORIENTATION)
    {
      [info setOrientation: (mode->dmOrientation == DMORIENT_LANDSCAPE)
                              ? NSLandscapeOrientation : NSPortraitOrientation];
    }
  if (copies && (mode->dmFields & DM_COPIES))
    {
      [dict setObject: [NSNumber numberWithInt: MAX(1, mode->dmCopies)] forKey: NSPrintCopies];
    }
  if (copies && (mode->dmFields & DM_COLLATE))
    {
      [dict setObject: [NSNumber numberWithBool: (mode->dmCollate == DMCOLLATE_TRUE)]
               forKey: NSPrintMustCollate];
    }
  GlobalUnlock(memory);
}

/* A DEVMODE for the printer named `name`, seeded from `info`; NULL when
   Windows doesn't know the printer. */
static HGLOBAL
WinUIThemeDevModeForPrinter(NSString *name, NSPrintInfo *info)
{
  WinUIThemeOpenPrinterWFunc openPrinter
    = (WinUIThemeOpenPrinterWFunc)WinUIThemeGetOptionalSystemProcedure(L"winspool.drv", "OpenPrinterW");
  WinUIThemeClosePrinterFunc closePrinter
    = (WinUIThemeClosePrinterFunc)WinUIThemeGetOptionalSystemProcedure(L"winspool.drv", "ClosePrinter");
  WinUIThemeDocumentPropertiesWFunc documentProperties
    = (WinUIThemeDocumentPropertiesWFunc)WinUIThemeGetOptionalSystemProcedure(L"winspool.drv",
                                                                              "DocumentPropertiesW");
  WCHAR *wideName = WinUIThemeCopyWideString(name);
  HANDLE printer = NULL;
  HGLOBAL memory = NULL;
  LONG size = 0;

  if (wideName == NULL || openPrinter == NULL || closePrinter == NULL || documentProperties == NULL
      || openPrinter(wideName, &printer, NULL) == FALSE)
    {
      free(wideName);
      return NULL;
    }
  size = documentProperties(NULL, printer, wideName, NULL, NULL, 0);
  if (size > 0)
    {
      memory = GlobalAlloc(GHND, (SIZE_T)size);
    }
  if (memory != NULL)
    {
      DEVMODEW *mode = (DEVMODEW *)GlobalLock(memory);

      if (documentProperties(NULL, printer, wideName, mode, NULL, DM_OUT_BUFFER) == IDOK)
        {
          WinUIThemeApplyPrintInfoToDevMode(info, mode);
          GlobalUnlock(memory);
        }
      else
        {
          GlobalUnlock(memory);
          GlobalFree(memory);
          memory = NULL;
        }
    }
  closePrinter(printer);
  free(wideName);
  return memory;
}

/* A DEVNAMES naming the printer `name`. */
static HGLOBAL
WinUIThemeDevNamesForPrinter(NSString *name)
{
  NSUInteger length = [name length];
  NSUInteger header = sizeof(DEVNAMES) / sizeof(WCHAR);
  HGLOBAL memory = NULL;
  DEVNAMES *names = NULL;
  WCHAR *characters = NULL;

  if (length == 0)
    {
      return NULL;
    }
  memory = GlobalAlloc(GHND, sizeof(DEVNAMES) + (length + 3) * sizeof(WCHAR));
  if (memory == NULL)
    {
      return NULL;
    }
  names = (DEVNAMES *)GlobalLock(memory);
  characters = (WCHAR *)names;
  /* An empty driver, the device, an empty port. */
  names->wDriverOffset = (WORD)header;
  names->wDeviceOffset = (WORD)(header + 1);
  names->wOutputOffset = (WORD)(header + 1 + length + 1);
  names->wDefault = 0;
  characters[header] = 0;
  [name getCharacters: (unichar *)(characters + header + 1)];
  characters[header + 1 + length] = 0;
  characters[header + 1 + length + 1] = 0;
  GlobalUnlock(memory);
  return memory;
}

static NSString *
WinUIThemePrinterNameFromDevNames(HGLOBAL memory)
{
  DEVNAMES *names = (memory != NULL) ? (DEVNAMES *)GlobalLock(memory) : NULL;
  NSString *name = nil;

  if (names == NULL)
    {
      return nil;
    }
  name = WinUIThemeStringFromWideString((WCHAR *)names + names->wDeviceOffset);
  GlobalUnlock(memory);
  return name;
}

/* The printer the dialog chose, in the print info, when GNUstep knows it
   (its Windows printing bundle names printers as Windows does). */
static void
WinUIThemeApplyPrinter(HGLOBAL devNames, NSPrintInfo *info)
{
  NSString *name = WinUIThemePrinterNameFromDevNames(devNames);
  NSPrinter *printer = ([name length] > 0) ? [NSPrinter printerWithName: name] : nil;

  if (printer != nil && [[[info printer] name] isEqualToString: name] == NO)
    {
      [info setPrinter: printer];
    }
}

/* Seeds the dialog's printer and settings from the print info. */
static void
WinUIThemeSeedPrinter(NSPrintInfo *info, HGLOBAL *devNames, HGLOBAL *devMode)
{
  NSString *name = [[info printer] name];

  *devNames = WinUIThemeDevNamesForPrinter(name);
  *devMode = (*devNames != NULL) ? WinUIThemeDevModeForPrinter(name, info) : NULL;
  if (*devMode == NULL && *devNames != NULL)
    {
      /* A printer Windows doesn't know: its default instead. */
      GlobalFree(*devNames);
      *devNames = NULL;
    }
}

static void
WinUIThemeFreeGlobal(HGLOBAL memory)
{
  if (memory != NULL)
    {
      GlobalFree(memory);
    }
}

/* Windows' print dialog for a print operation (#69): seeded from the print
   info, and on OK the printer, copies, collation, page range, paper and
   orientation go back into it. Cancel is NSCancelButton. GNUstep's panel
   stays for an accessory view (which the dialog can't show) and with
   WinUIThemeNativePrintDialogs NO. */
static NSInteger
WinUIThemeRunNativePrintDialog(NSPrintPanel *panel, NSPrintInfo *info, NSWindow *ownerWindow)
{
  PRINTDLGW dialog;
  NSMutableDictionary *dict = nil;
  NSInteger first = 0;
  NSInteger last = 0;
  BOOL allPages = YES;
  BOOL shown = NO;
  DWORD error = 0;

  if (info == nil || WinUIThemeNativeDialogsEnabled(@"WinUIThemeNativePrintDialogs") == NO
      || [panel accessoryView] != nil || [[panel accessoryControllers] count] > 0)
    {
      return WinUIThemeUnavailableNativeDialogResult();
    }

  dict = [info dictionary];
  if ([dict objectForKey: NSPrintAllPages] != nil)
    {
      allPages = [[dict objectForKey: NSPrintAllPages] boolValue];
    }
  first = [[dict objectForKey: NSPrintFirstPage] integerValue];
  last = [[dict objectForKey: NSPrintLastPage] integerValue];

  memset(&dialog, 0, sizeof(dialog));
  dialog.lStructSize = sizeof(dialog);
  dialog.hwndOwner = WinUIThemeOwnerWindowHandle(ownerWindow);
  /* No selection or current page (GNUstep prints page ranges), and no
     print to file, which would leave the app to ask for the file. */
  dialog.Flags = PD_USEDEVMODECOPIESANDCOLLATE | PD_NOSELECTION | PD_NOCURRENTPAGE | PD_HIDEPRINTTOFILE;
  dialog.nMinPage = 1;
  dialog.nMaxPage = 9999;
  dialog.nFromPage = 1;
  dialog.nToPage = 1;
  if (allPages == NO && first > 0)
    {
      dialog.Flags |= PD_PAGENUMS;
      dialog.nFromPage = (WORD)MIN(first, 9999);
      dialog.nToPage = (WORD)MIN(MAX(first, last), 9999);
    }
  WinUIThemeSeedPrinter(info, &dialog.hDevNames, &dialog.hDevMode);

  shown = WinUIThemePrintDlgW(&dialog);
  error = shown ? 0 : CommDlgExtendedError();
  if (shown == NO && error != 0 && (dialog.hDevNames != NULL || dialog.hDevMode != NULL))
    {
      /* The seed didn't suit the printer: Windows' defaults. */
      WinUIThemeFreeGlobal(dialog.hDevNames);
      WinUIThemeFreeGlobal(dialog.hDevMode);
      dialog.hDevNames = NULL;
      dialog.hDevMode = NULL;
      shown = WinUIThemePrintDlgW(&dialog);
      error = shown ? 0 : CommDlgExtendedError();
    }
  if (shown == NO)
    {
      WinUIThemeFreeGlobal(dialog.hDevNames);
      WinUIThemeFreeGlobal(dialog.hDevMode);
      /* Cancelled; otherwise no dialog (no printers, no comdlg32). */
      return (error == 0) ? NSCancelButton : WinUIThemeUnavailableNativeDialogResult();
    }

  WinUIThemeApplyPrinter(dialog.hDevNames, info);
  WinUIThemeApplyDevModeToPrintInfo(dialog.hDevMode, info, YES);
  dict = [info dictionary];
  if (dialog.Flags & PD_PAGENUMS)
    {
      [dict setObject: [NSNumber numberWithBool: NO] forKey: NSPrintAllPages];
      [dict setObject: [NSNumber numberWithInt: dialog.nFromPage] forKey: NSPrintFirstPage];
      [dict setObject: [NSNumber numberWithInt: MAX(dialog.nFromPage, dialog.nToPage)]
               forKey: NSPrintLastPage];
    }
  else
    {
      [dict setObject: [NSNumber numberWithBool: YES] forKey: NSPrintAllPages];
    }
  WinUIThemeFreeGlobal(dialog.hDevNames);
  WinUIThemeFreeGlobal(dialog.hDevMode);
  return NSOKButton;
}

/* Windows' page setup dialog: paper, orientation, margins and printer,
   seeded from the print info and written back on OK. */
static NSInteger
WinUIThemeRunNativePageSetupDialog(NSPageLayout *layout, NSPrintInfo *info, NSWindow *ownerWindow)
{
  PAGESETUPDLGW dialog;
  BOOL shown = NO;
  DWORD error = 0;

  if (info == nil || WinUIThemeNativeDialogsEnabled(@"WinUIThemeNativePrintDialogs") == NO
      || [layout accessoryView] != nil)
    {
      return WinUIThemeUnavailableNativeDialogResult();
    }

  memset(&dialog, 0, sizeof(dialog));
  dialog.lStructSize = sizeof(dialog);
  dialog.hwndOwner = WinUIThemeOwnerWindowHandle(ownerWindow);
  dialog.Flags = PSD_INTHOUSANDTHSOFINCHES | PSD_MARGINS;
  /* Points to thousandths of an inch. */
  dialog.rtMargin.left = (LONG)lround([info leftMargin] * 1000.0 / 72.0);
  dialog.rtMargin.top = (LONG)lround([info topMargin] * 1000.0 / 72.0);
  dialog.rtMargin.right = (LONG)lround([info rightMargin] * 1000.0 / 72.0);
  dialog.rtMargin.bottom = (LONG)lround([info bottomMargin] * 1000.0 / 72.0);
  WinUIThemeSeedPrinter(info, &dialog.hDevNames, &dialog.hDevMode);

  shown = WinUIThemePageSetupDlgW(&dialog);
  error = shown ? 0 : CommDlgExtendedError();
  if (shown == NO && error != 0 && (dialog.hDevNames != NULL || dialog.hDevMode != NULL))
    {
      WinUIThemeFreeGlobal(dialog.hDevNames);
      WinUIThemeFreeGlobal(dialog.hDevMode);
      dialog.hDevNames = NULL;
      dialog.hDevMode = NULL;
      shown = WinUIThemePageSetupDlgW(&dialog);
      error = shown ? 0 : CommDlgExtendedError();
    }
  if (shown == NO)
    {
      WinUIThemeFreeGlobal(dialog.hDevNames);
      WinUIThemeFreeGlobal(dialog.hDevMode);
      return (error == 0) ? NSCancelButton : WinUIThemeUnavailableNativeDialogResult();
    }

  WinUIThemeApplyPrinter(dialog.hDevNames, info);
  WinUIThemeApplyDevModeToPrintInfo(dialog.hDevMode, info, NO);
  [info setLeftMargin: dialog.rtMargin.left * 72.0 / 1000.0];
  [info setTopMargin: dialog.rtMargin.top * 72.0 / 1000.0];
  [info setRightMargin: dialog.rtMargin.right * 72.0 / 1000.0];
  [info setBottomMargin: dialog.rtMargin.bottom * 72.0 / 1000.0];
  WinUIThemeFreeGlobal(dialog.hDevNames);
  WinUIThemeFreeGlobal(dialog.hDevMode);
  return NSOKButton;
}

#pragma mark When GNUstep's file panels stay (#20)

/* NSDocument's save panel accessory: a "File Type" box holding only the
   pop-up whose action is -changeSaveType:. The dialog's own type filters
   stand in for it (#76). */
static BOOL
WinUIThemeIsDocumentTypeAccessory(NSView *view, NSUInteger *controls)
{
  NSEnumerator *enumerator = [[view subviews] objectEnumerator];
  NSView *subview = nil;
  BOOL found = NO;

  if ([view isKindOfClass: [NSPopUpButton class]])
    {
      (*controls)++;
      return (sel_isEqual([(NSPopUpButton *)view action], @selector(changeSaveType:))
              && [[(NSPopUpButton *)view target] isKindOfClass: [NSDocument class]]);
    }
  if ([view isKindOfClass: [NSControl class]]
      && ([view isKindOfClass: [NSTextField class]] == NO || [(NSTextField *)view isEditable]))
    {
      (*controls)++;
      return NO;
    }
  while ((subview = [enumerator nextObject]) != nil)
    {
      if (WinUIThemeIsDocumentTypeAccessory(subview, controls))
        {
          found = YES;
        }
    }
  return found;
}

/* Whether a file panel needs GNUstep's own: the owner opted out
   (WinUIThemeNativeFileDialogs NO), it has an accessory view the dialog
   can't show, or its delegate filters or checks names, which the dialog
   can't ask it. */
static BOOL
WinUIThemeFilePanelNeedsGNUstep(NSSavePanel *panel)
{
  static const char *delegateSelectors[] = {
    "panel:shouldShowFilename:",
    "panel:shouldEnableURL:",
    "panel:isValidFilename:",
    "panel:validateURL:error:",
    "panel:userEnteredFilename:confirmed:",
    NULL
  };
  NSView *accessory = [panel accessoryView];
  id delegate = [panel delegate];
  NSUInteger index;

  if (WinUIThemeNativeDialogsEnabled(@"WinUIThemeNativeFileDialogs") == NO)
    {
      return YES;
    }
  if (accessory != nil)
    {
      NSUInteger controls = 0;

      if (WinUIThemeIsDocumentTypeAccessory(accessory, &controls) == NO || controls != 1)
        {
          return YES;
        }
    }
  for (index = 0; delegate != nil && delegateSelectors[index] != NULL; index++)
    {
      if ([delegate respondsToSelector: sel_registerName(delegateSelectors[index])])
        {
          return YES;
        }
    }
  return NO;
}
#endif

@implementation WinUIThemeSavePanel

- (void) _winUIThemeSetNativeSavePath: (NSString *)path
{
  if ([path length] > 0)
    {
      ASSIGN(_directory, [path stringByDeletingLastPathComponent]);
      ASSIGN(_fullFileName, path);
    }
}

- (NSInteger) runModal
{
#ifdef _WIN32
  NSInteger result = WinUIThemeRunNativeSaveDialog(self, nil);

  if (result != WinUIThemeUnavailableNativeDialogResult())
    {
      return result;
    }
#endif
  return [super runModal];
}

- (NSInteger) runModalForDirectory: (NSString *)path file: (NSString *)filename
{
  if ([path length] > 0)
    {
      [self setDirectory: path];
    }
  if ([filename length] > 0 && [self respondsToSelector: @selector(setNameFieldStringValue:)])
    {
      [self setNameFieldStringValue: filename];
    }

#ifdef _WIN32
  {
    NSInteger result = WinUIThemeRunNativeSaveDialog(self, nil);

    if (result != WinUIThemeUnavailableNativeDialogResult())
      {
        return result;
      }
  }
#endif
  /* GNUstep's -runModal comes here: its own panel, not -runModal again. */
  return [super runModalForDirectory: path file: filename];
}

- (void) beginSheetModalForWindow: (NSWindow *)window
                completionHandler: (GSSavePanelCompletionHandler)handler
{
#ifdef _WIN32
  NSInteger result = WinUIThemeRunNativeSaveDialog(self, window);

  if (result != WinUIThemeUnavailableNativeDialogResult())
    {
      if (handler != NULL)
        {
          handler(result);
        }
      return;
    }
#endif
  [super beginSheetModalForWindow: window completionHandler: handler];
}

- (void) beginSheetForDirectory: (NSString *)path
                           file: (NSString *)filename
                 modalForWindow: (NSWindow *)docWindow
                  modalDelegate: (id)delegate
                 didEndSelector: (SEL)didEndSelector
                    contextInfo: (void *)contextInfo
{
  NSInteger result = NSCancelButton;

  if ([path length] > 0)
    {
      [self setDirectory: path];
    }
  if ([filename length] > 0 && [self respondsToSelector: @selector(setNameFieldStringValue:)])
    {
      [self setNameFieldStringValue: filename];
    }

#ifdef _WIN32
  result = WinUIThemeRunNativeSaveDialog(self, docWindow);
  if (result != WinUIThemeUnavailableNativeDialogResult())
    {
      WinUIThemeInvokeModalDelegate(delegate, didEndSelector, self, result, contextInfo);
      return;
    }
#endif

  [super beginSheetForDirectory: path
                           file: filename
                 modalForWindow: docWindow
                  modalDelegate: delegate
                 didEndSelector: didEndSelector
                    contextInfo: contextInfo];
}

@end

@implementation WinUIThemeOpenPanel

- (void) dealloc
{
  RELEASE(_selectedFilenames);
  [super dealloc];
}

- (void) _winUIThemeSetNativeSelectedPaths: (NSArray *)paths
{
  ASSIGN(_selectedFilenames, paths);
  if ([paths count] > 0)
    {
      NSString *firstPath = [paths objectAtIndex: 0];

      ASSIGN(_directory, [firstPath stringByDeletingLastPathComponent]);
      ASSIGN(_fullFileName, firstPath);
    }
}

- (NSArray *) filenames
{
  if (_selectedFilenames != nil)
    {
      return [[_selectedFilenames retain] autorelease];
    }

  return [super filenames];
}

- (NSInteger) runModal
{
#ifdef _WIN32
  NSInteger result = WinUIThemeRunNativeOpenDialog(self, nil);

  if (result != WinUIThemeUnavailableNativeDialogResult())
    {
      return result;
    }
#endif
  return [super runModal];
}

- (NSInteger) runModalForTypes: (NSArray *)fileTypes
{
  return [self runModalForDirectory: [self directory] file: nil types: fileTypes];
}

- (NSInteger) runModalForDirectory: (NSString *)path
                              file: (NSString *)name
                             types: (NSArray *)fileTypes
{
  if ([path length] > 0)
    {
      [self setDirectory: path];
    }
  [self setAllowedFileTypes: fileTypes];

#ifdef _WIN32
  {
    NSInteger result = WinUIThemeRunNativeOpenDialog(self, nil);

    if (result != WinUIThemeUnavailableNativeDialogResult())
      {
        return result;
      }
  }
#endif
  /* GNUstep's -runModal comes here: its own panel, not -runModal again. */
  return [super runModalForDirectory: path file: name types: fileTypes];
}

- (void) beginSheetModalForWindow: (NSWindow *)window
                completionHandler: (GSSavePanelCompletionHandler)handler
{
#ifdef _WIN32
  NSInteger result = WinUIThemeRunNativeOpenDialog(self, window);

  if (result != WinUIThemeUnavailableNativeDialogResult())
    {
      if (handler != NULL)
        {
          handler(result);
        }
      return;
    }
#endif
  [super beginSheetModalForWindow: window completionHandler: handler];
}

- (void) beginSheetForDirectory: (NSString *)path
                           file: (NSString *)name
                          types: (NSArray *)fileTypes
                 modalForWindow: (NSWindow *)docWindow
                  modalDelegate: (id)delegate
                 didEndSelector: (SEL)didEndSelector
                    contextInfo: (void *)contextInfo
{
  NSInteger result = NSCancelButton;

  if ([path length] > 0)
    {
      [self setDirectory: path];
    }
  [self setAllowedFileTypes: fileTypes];
  (void)name;

#ifdef _WIN32
  result = WinUIThemeRunNativeOpenDialog(self, docWindow);
  if (result != WinUIThemeUnavailableNativeDialogResult())
    {
      WinUIThemeInvokeModalDelegate(delegate, didEndSelector, self, result, contextInfo);
      return;
    }
#endif

  [super beginSheetForDirectory: path
                           file: name
                          types: fileTypes
                 modalForWindow: docWindow
                  modalDelegate: delegate
                 didEndSelector: didEndSelector
                    contextInfo: contextInfo];
}

@end

@implementation WinUIThemePrintPanel

/* As GNUstep's panel: the current operation's print info. */
- (NSInteger) runModal
{
  NSPrintInfo *info = [[NSPrintOperation currentOperation] printInfo];

  return [self runModalWithPrintInfo: (info != nil) ? info : [NSPrintInfo sharedPrintInfo]];
}

- (NSInteger) runModalWithPrintInfo: (NSPrintInfo *)printInfo
{
#ifdef _WIN32
  NSInteger result = WinUIThemeRunNativePrintDialog(self, printInfo, nil);

  if (result != WinUIThemeUnavailableNativeDialogResult())
    {
      return result;
    }
#endif
  return [super runModalWithPrintInfo: printInfo];
}

- (void) beginSheetWithPrintInfo: (NSPrintInfo *)printInfo
                  modalForWindow: (NSWindow *)docWindow
                        delegate: (id)delegate
                  didEndSelector: (SEL)didEndSelector
                     contextInfo: (void *)contextInfo
{
#ifdef _WIN32
  NSInteger result = WinUIThemeRunNativePrintDialog(self, printInfo, docWindow);

  if (result != WinUIThemeUnavailableNativeDialogResult())
    {
      WinUIThemeInvokeModalDelegate(delegate, didEndSelector, self, result, contextInfo);
      return;
    }
#endif
  [super beginSheetWithPrintInfo: printInfo
                  modalForWindow: docWindow
                        delegate: delegate
                  didEndSelector: didEndSelector
                     contextInfo: contextInfo];
}

@end

@implementation WinUIThemePageLayout

/* As GNUstep's panel: the shared print info. */
- (NSInteger) runModal
{
  return [self runModalWithPrintInfo: [NSPrintInfo sharedPrintInfo]];
}

- (NSInteger) runModalWithPrintInfo: (NSPrintInfo *)printInfo
{
#ifdef _WIN32
  NSInteger result = WinUIThemeRunNativePageSetupDialog(self, printInfo, nil);

  if (result != WinUIThemeUnavailableNativeDialogResult())
    {
      return result;
    }
#endif
  return [super runModalWithPrintInfo: printInfo];
}

- (void) beginSheetWithPrintInfo: (NSPrintInfo *)printInfo
                  modalForWindow: (NSWindow *)docWindow
                        delegate: (id)delegate
                  didEndSelector: (SEL)didEndSelector
                     contextInfo: (void *)contextInfo
{
#ifdef _WIN32
  NSInteger result = WinUIThemeRunNativePageSetupDialog(self, printInfo, docWindow);

  if (result != WinUIThemeUnavailableNativeDialogResult())
    {
      WinUIThemeInvokeModalDelegate(delegate, didEndSelector, self, result, contextInfo);
      return;
    }
#endif
  [super beginSheetWithPrintInfo: printInfo
                  modalForWindow: docWindow
                        delegate: delegate
                  didEndSelector: didEndSelector
                     contextInfo: contextInfo];
}

@end

/* Page setup without GNUstep's panel: +[NSPageLayout pageLayout] loads
   GSPageLayout.gorm, which fails on Windows with gui 0.32 ("Could not
   load page layout panel resource") whatever the theme, so the menu's Page
   Setup goes straight to Windows' dialog. A document that prepares the
   panel itself (-preparePageLayout:, for an accessory view) keeps
   GNUstep's. */
@implementation WinUITheme (PageSetup)

- (void) _overrideNSApplicationMethod_runPageLayout: (id)sender
{
  typedef void (*RunIMP)(id, SEL, id);
  RunIMP originalIMP = (RunIMP)WinUIThemeOriginalMethod(_cmd, self, [NSApplication class]);

#ifdef _WIN32
  if (WinUIThemeRunNativePageSetupDialog(nil, [NSPrintInfo sharedPrintInfo], nil)
      != WinUIThemeUnavailableNativeDialogResult())
    {
      return;
    }
#endif
  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, sender);
    }
}

- (void) _overrideNSDocumentMethod_runModalPageLayoutWithPrintInfo: (NSPrintInfo *)info
                                                          delegate: (id)delegate
                                                    didRunSelector: (SEL)selector
                                                       contextInfo: (void *)context
{
  typedef void (*RunIMP)(id, SEL, NSPrintInfo *, id, SEL, void *);
  RunIMP originalIMP = (RunIMP)WinUIThemeOriginalMethod(_cmd, self, [NSDocument class]);
  SEL prepare = @selector(preparePageLayout:);

#ifdef _WIN32
  if ([self methodForSelector: prepare] == [NSDocument instanceMethodForSelector: prepare])
    {
      NSInteger result = WinUIThemeRunNativePageSetupDialog(nil, info, [(NSDocument *)self windowForSheet]);

      if (result != WinUIThemeUnavailableNativeDialogResult())
        {
          /* As NSDocument's delegate: the document, whether it was
             accepted, the context. */
          if (delegate != nil && selector != NULL && [delegate respondsToSelector: selector])
            {
              typedef void (*DidRunIMP)(id, SEL, id, BOOL, void *);
              DidRunIMP didRun = (DidRunIMP)[delegate methodForSelector: selector];

              didRun(delegate, selector, self, (result == NSOKButton), context);
            }
          return;
        }
    }
#endif
  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, info, delegate, selector, context);
    }
}

@end

@implementation WinUITheme (FileDialogFilters)

+ (NSDictionary *) fileDialogFilters: (NSDictionary *)request
{
  NSUInteger selected = 0;
  NSArray *filters = nil;
  NSArray *types = [request objectForKey: @"types"];
  NSString *fileName = [request objectForKey: @"fileName"];

  if ([types isKindOfClass: [NSArray class]] == NO)
    {
      types = nil;
    }
  if ([fileName isKindOfClass: [NSString class]] == NO)
    {
      fileName = nil;
    }
  filters = WinUIThemeFileDialogFilters(types,
                                        [[request objectForKey: @"saving"] boolValue],
                                        [[request objectForKey: @"allowsOtherFileTypes"] boolValue],
                                        fileName,
                                        &selected);
  return [NSDictionary dictionaryWithObjectsAndKeys:
    filters, @"filters",
    [NSNumber numberWithUnsignedInteger: selected], @"selectedIndex",
    nil];
}

@end
