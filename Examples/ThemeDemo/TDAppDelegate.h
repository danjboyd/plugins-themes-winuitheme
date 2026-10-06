#ifndef THEMEDEMO_APPDELEGATE_H
#define THEMEDEMO_APPDELEGATE_H

#import <AppKit/AppKit.h>

@interface TDAppDelegate : NSObject <NSApplicationDelegate, NSToolbarDelegate, NSBrowserDelegate>
{
  NSDictionary *_contract;
  NSArray *_pages;
  NSArray *_tableRows;
  NSArray *_outlineRows;
  NSWindow *_window;
  NSPopUpButton *_pageSelector;
  NSScrollView *_scrollView;
  NSTextField *_pageTitleLabel;
  NSTextField *_pageDescriptionLabel;
  NSString *_requestedPageID;
  NSString *_requestedCapturePath;
  NSString *_lastOpenPanelResult;
  NSString *_lastSavePanelResult;
  NSString *_lastPrintPanelResult;
  NSString *_lastPageLayoutResult;
  NSString *_lastAlertResult;
}

@end

#endif
