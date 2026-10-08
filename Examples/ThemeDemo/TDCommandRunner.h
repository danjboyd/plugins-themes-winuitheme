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

#ifndef THEMEDEMO_COMMANDRUNNER_H
#define THEMEDEMO_COMMANDRUNNER_H

#import <AppKit/AppKit.h>

/* What the command runner needs from the app. */
@protocol TDCommandTarget
- (NSWindow *) demoWindow;
- (NSPopUpButton *) pageSelector;
- (BOOL) selectPageWithID: (NSString *)pageID;
/* Runs the demo's stock "save changes" NSAlert modally. */
- (NSInteger) runSaveChangesAlert;
@end

/* Scripted commands for ThemeDemo (#17), after the Adwaita theme's
   ThemeDemo: --command-script PATH runs a file of commands, one a line;
   --command-fifo NAME reads more as they come, from a named pipe
   (\\.\pipe\NAME on Windows, a FIFO elsewhere). Commands run one per
   run-loop turn, in the default, modal and event-tracking modes, so they
   go on while a pop-up menu is open or an alert runs: open it, wait,
   capture, close. See Examples/ThemeDemo/README.md for the commands. */
@interface TDCommandRunner : NSObject
{
  id<TDCommandTarget> _target;
  NSMutableArray *_queue;
  BOOL _scheduled;
  NSView *_focusedControl;
  id _toolTips;
  NSTimer *_pipeTimer;
  NSMutableData *_pipeBuffer;
#ifdef _WIN32
  void *_pipe;
  BOOL _pipeConnected;
#else
  int _fifo;
#endif
}

- (id) initWithTarget: (id<TDCommandTarget>)target;

/* Starts from --command-script and --command-fifo, if given. */
- (void) startFromArguments: (NSArray *)arguments;

/* Queues commands, one a line; blank lines and # comments are skipped. */
- (void) enqueueCommands: (NSString *)commands;

@end

#endif
