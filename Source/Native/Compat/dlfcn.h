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

/* dladdr() for the shared window tabbing code (Source/WindowTabbing,
   GSWindowTabbingInstall.m), which includes <dlfcn.h> to tell whether the
   runtime kept its copy of the classes or an app's. MinGW has no
   <dlfcn.h>; that check needs only the loaded module an address is in
   (dli_fbase), which GetModuleHandleExW gives. Elsewhere this passes on
   to the system's header. */

#ifndef WINUITHEME_COMPAT_DLFCN_H
#define WINUITHEME_COMPAT_DLFCN_H

#if defined(_WIN32)

#include <stddef.h>

typedef struct
{
  const char *dli_fname;
  void *dli_fbase;
  const char *dli_sname;
  void *dli_saddr;
} Dl_info;

/* As <windows.h> declares it (HMODULE is struct HINSTANCE__ *), without
   including <windows.h>, whose BOOL clashes with Objective-C's. */
struct HINSTANCE__;
__declspec(dllimport) int __stdcall
GetModuleHandleExW(unsigned long flags, const wchar_t *name, struct HINSTANCE__ **module);

/* GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT | ..._FROM_ADDRESS */
#define WINUITHEME_MODULE_FROM_ADDRESS (0x2 | 0x4)

static inline int
dladdr(const void *address, Dl_info *info)
{
  struct HINSTANCE__ *module = NULL;

  if (info == NULL
    || GetModuleHandleExW(WINUITHEME_MODULE_FROM_ADDRESS,
                          (const wchar_t *)address, &module) == 0)
    {
      return 0;
    }
  info->dli_fname = NULL;
  info->dli_fbase = (void *)module;
  info->dli_sname = NULL;
  info->dli_saddr = NULL;
  return 1;
}

#else

#include_next <dlfcn.h>

#endif

#endif
