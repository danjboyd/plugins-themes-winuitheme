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
WinUIThemeCreateFilterSpecs(NSArray *types, UINT *countOut)
{
  NSMutableArray *extensions = [NSMutableArray array];
  COMDLG_FILTERSPEC *specs = NULL;
  NSUInteger index = 0;

  if (countOut != NULL)
    {
      *countOut = 0;
    }
  if ([types count] == 0)
    {
      return NULL;
    }

  for (index = 0; index < [types count]; index++)
    {
      NSString *entry = [types objectAtIndex: index];
      NSString *extension = nil;

      if ([entry isKindOfClass: [NSString class]] == NO)
        {
          continue;
        }

      extension = [(NSString *)entry stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
      extension = [extension stringByReplacingOccurrencesOfString: @"*."
                                                       withString: @""];
      extension = [extension stringByReplacingOccurrencesOfString: @"."
                                                       withString: @""];
      if ([extension length] == 0)
        {
          continue;
        }
      [extensions addObject: extension];
    }

  if ([extensions count] == 0)
    {
      return NULL;
    }

  specs = calloc([extensions count], sizeof(COMDLG_FILTERSPEC));
  if (specs == NULL)
    {
      return NULL;
    }

  for (index = 0; index < [extensions count]; index++)
    {
      NSString *extension = [extensions objectAtIndex: index];
      NSString *name = [NSString stringWithFormat: @"%@ files", [extension uppercaseString]];
      NSString *pattern = [NSString stringWithFormat: @"*.%@", extension];

      specs[index].pszName = WinUIThemeCopyWideString(name);
      specs[index].pszSpec = WinUIThemeCopyWideString(pattern);
    }

  if (countOut != NULL)
    {
      *countOut = (UINT)[extensions count];
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

static void
WinUIThemeConfigureDialogFileTypes(IFileDialog *dialog,
                                   NSArray *types,
                                   BOOL allowsOtherFileTypes)
{
  COMDLG_FILTERSPEC *specs = NULL;
  UINT count = 0;

  if (dialog == NULL)
    {
      return;
    }

  specs = WinUIThemeCreateFilterSpecs(types, &count);
  if (specs != NULL && count > 0)
    {
      IFileDialog_SetFileTypes(dialog, count, specs);
      IFileDialog_SetFileTypeIndex(dialog, 1);
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

  if ([panel respondsToSelector: @selector(nameFieldStringValue)])
    {
      filename = [panel nameFieldStringValue];
    }
  if ([filename length] == 0)
    {
      filename = [[panel filename] lastPathComponent];
    }

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
                                     [panel allowsOtherFileTypes]);
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
                                     [panel allowsOtherFileTypes]);

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

  return [self runModal];
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
  [self setAllowedFileTypes: fileTypes];
  return [self runModal];
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
  (void)name;
  return [self runModal];
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

- (NSInteger) runModal
{
#ifdef _WIN32
  PRINTDLGW dialog;

  memset(&dialog, 0, sizeof(dialog));
  dialog.lStructSize = sizeof(dialog);
  dialog.hwndOwner = WinUIThemeOwnerWindowHandle(nil);
  dialog.Flags = PD_RETURNDC | PD_USEDEVMODECOPIESANDCOLLATE;
  if (WinUIThemePrintDlgW(&dialog))
    {
      if (dialog.hDevMode != NULL) GlobalFree(dialog.hDevMode);
      if (dialog.hDevNames != NULL) GlobalFree(dialog.hDevNames);
      if (dialog.hDC != NULL) DeleteDC(dialog.hDC);
      return NSOKButton;
    }
#endif
  return [super runModal];
}

- (NSInteger) runModalWithPrintInfo: (NSPrintInfo *)printInfo
{
  (void)printInfo;
  return [self runModal];
}

- (void) beginSheetWithPrintInfo: (NSPrintInfo *)printInfo
                  modalForWindow: (NSWindow *)docWindow
                        delegate: (id)delegate
                  didEndSelector: (SEL)didEndSelector
                     contextInfo: (void *)contextInfo
{
  NSInteger result = [self runModalWithPrintInfo: printInfo];

  WinUIThemeInvokeModalDelegate(delegate, didEndSelector, self, result, contextInfo);
  (void)docWindow;
}

@end

@implementation WinUIThemePageLayout

- (NSInteger) runModal
{
#ifdef _WIN32
  PAGESETUPDLGW dialog;

  memset(&dialog, 0, sizeof(dialog));
  dialog.lStructSize = sizeof(dialog);
  dialog.hwndOwner = WinUIThemeOwnerWindowHandle(nil);
  dialog.Flags = PSD_DEFAULTMINMARGINS | PSD_MARGINS;
  if (WinUIThemePageSetupDlgW(&dialog))
    {
      if (dialog.hDevMode != NULL) GlobalFree(dialog.hDevMode);
      if (dialog.hDevNames != NULL) GlobalFree(dialog.hDevNames);
      return NSOKButton;
    }
#endif
  return [super runModal];
}

- (NSInteger) runModalWithPrintInfo: (NSPrintInfo *)printInfo
{
  (void)printInfo;
  return [self runModal];
}

- (void) beginSheetWithPrintInfo: (NSPrintInfo *)printInfo
                  modalForWindow: (NSWindow *)docWindow
                        delegate: (id)delegate
                  didEndSelector: (SEL)didEndSelector
                     contextInfo: (void *)contextInfo
{
  NSInteger result = [self runModalWithPrintInfo: printInfo];

  WinUIThemeInvokeModalDelegate(delegate, didEndSelector, self, result, contextInfo);
  (void)docWindow;
}

@end
