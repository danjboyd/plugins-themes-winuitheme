#import "WinUITheme.h"

#import "Settings/WinUIThemeSettings.h"
#import "Settings/WinUIThemeMetrics.h"
#import "Rendering/WinUIThemePalette.h"
#import "Native/WinUIThemeShellDialogs.h"
#import "Native/WinUIThemeWindowIntegration.h"

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>

static NSString *WinUIThemeRuntimeDefaultsDomain = @"WinUIThemeRuntimeDomain";

@interface WinUITheme ()
- (void) applyRuntimeDefaults;
- (void) removeRuntimeDefaults;
- (void) refreshRuntimeDefaultsIfNeeded;
- (NSDictionary *) runtimeDefaultsDictionary;
- (BOOL) shouldUseWindowIntegration;
- (void) addFont: (NSFont *)font
          forKey: (NSString *)key
     toDictionary: (NSMutableDictionary *)dictionary;
@end

IMP
WinUIThemeOriginalMethod(SEL selector, id receiver, Class baseClass)
{
  static NSMapTable *prototypes = nil;
  GSTheme *theme = [GSTheme theme];
  IMP imp = [theme overriddenMethod: selector for: receiver];
  id prototype;

  if (imp != NULL || baseClass == Nil)
    {
      return imp;
    }
  /* An instance of exactly `baseClass`, used only as a lookup key: it is never
     initialised, messaged, or freed. */
  if (prototypes == nil)
    {
      prototypes = [[NSMapTable alloc]
        initWithKeyOptions: NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality
              valueOptions: NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality
                  capacity: 16];
    }
  prototype = (id)NSMapGet(prototypes, (void *)baseClass);
  if (prototype == nil)
    {
      prototype = class_createInstance(baseClass, 0);
      NSMapInsert(prototypes, (void *)baseClass, (void *)prototype);
    }
  return [theme overriddenMethod: selector for: prototype];
}

@implementation WinUITheme

+ (NSString *) themeName
{
  return @"WinUI";
}

- (id) initWithBundle: (NSBundle *)bundle
{
  self = [super initWithBundle: bundle];
  if (self != nil)
    {
      _settings = [WinUIThemeSettings new];
      _metrics = [WinUIThemeMetrics new];
      _runtimeDefaultsApplied = NO;
      [self reloadConfiguration];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_settings);
  RELEASE(_metrics);
  RELEASE(_palette);
  [super dealloc];
}

- (void) reloadConfiguration
{
  [_settings reload];
  [_metrics reloadFromSettings: _settings];
  DESTROY(_palette);
  [self refreshRuntimeDefaultsIfNeeded];
  if ([self shouldUseWindowIntegration])
    {
      WinUIThemeWindowIntegrationReloadTheme(self);
    }
  else
    {
      WinUIThemeWindowIntegrationDeactivate();
    }
}

- (WinUIThemeSettings *) settings
{
  return _settings;
}

- (WinUIThemeMetrics *) metrics
{
  return _metrics;
}

- (void) activate
{
  [self reloadConfiguration];
  [self applyRuntimeDefaults];
  _runtimeDefaultsApplied = YES;
  [super activate];
  if ([self shouldUseWindowIntegration])
    {
      WinUIThemeWindowIntegrationActivate(self);
    }
  else
    {
      WinUIThemeWindowIntegrationDeactivate();
    }
}

- (void) deactivate
{
  WinUIThemeWindowIntegrationDeactivate();
  [self removeRuntimeDefaults];
  _runtimeDefaultsApplied = NO;
  [super deactivate];
}

- (NSColorList *) colors
{
  if (_palette == nil)
    {
      _palette = RETAIN([WinUIThemePalette colorListForSettings: _settings]);
    }
  return _palette;
}

- (NSColor *) colorNamed: (NSString *)aName
                   state: (GSThemeControlState)elementState
{
  NSColor *color = [super colorNamed: aName state: elementState];

  if (color == nil && [aName length] > 0)
    {
      color = [[self colors] colorWithKey: aName];
    }

  return color;
}

- (BOOL) menuShouldShowIcon
{
  return NO;
}

- (CGFloat) menuBarHeight
{
  return [_metrics menuBarHeight];
}

- (CGFloat) menuItemHeight
{
  return [_metrics menuItemHeight];
}

- (CGFloat) menuSeparatorHeight
{
  return [_metrics menuSeparatorHeight];
}

- (float) defaultScrollerWidth
{
  return [_metrics scrollerWidth];
}

- (CGFloat) tabHeightForType: (NSTabViewType)type
{
  CGFloat height = [super tabHeightForType: type];

  switch (type)
    {
      case NSTopTabsBezelBorder:
      case NSBottomTabsBezelBorder:
      case NSLeftTabsBezelBorder:
      case NSRightTabsBezelBorder:
        height = MAX(height, [_metrics minimumTabHeight]);
        break;

      default:
        break;
    }

  return height;
}

- (Class) openPanelClass
{
  return [WinUIThemeOpenPanel class];
}

- (Class) savePanelClass
{
  return [WinUIThemeSavePanel class];
}

- (Class) printPanelClass
{
  return [WinUIThemePrintPanel class];
}

- (Class) pageLayoutClass
{
  return [WinUIThemePageLayout class];
}

- (id<GSWindowDecorator>) windowDecorator
{
  if ([GSCurrentServer() handlesWindowDecorations])
    {
      return (id<GSWindowDecorator>)[WinUIThemeBackendWindowDecorationView class];
    }

  return (id<GSWindowDecorator>)[WinUIThemeStandardWindowDecorationView class];
}

- (void) addFont: (NSFont *)font
          forKey: (NSString *)key
     toDictionary: (NSMutableDictionary *)dictionary
{
  if (font == nil || key == nil || dictionary == nil)
    {
      return;
    }

  [dictionary setObject: [font fontName] forKey: key];
  [dictionary setObject: [NSNumber numberWithFloat: [font pointSize]]
                 forKey: [NSString stringWithFormat: @"%@Size", key]];
}

- (NSDictionary *) runtimeDefaultsDictionary
{
  NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
  NSFont *interfaceFont = [_settings interfaceFont];
  NSFont *menuFont = [_settings menuFont];
  NSFont *menuBarFont = [_settings menuBarFont];
  NSFont *fixedPitchFont = [_settings fixedPitchFont];
  CGFloat baseFontSize = [_settings interfaceFontSize];

  [self addFont: interfaceFont forKey: @"NSFont" toDictionary: dictionary];
  [self addFont: interfaceFont forKey: @"NSUserFont" toDictionary: dictionary];
  [self addFont: interfaceFont forKey: @"NSControlContentFont" toDictionary: dictionary];
  [self addFont: interfaceFont forKey: @"NSLabelFont" toDictionary: dictionary];
  [self addFont: interfaceFont forKey: @"NSMessageFont" toDictionary: dictionary];
  [self addFont: interfaceFont forKey: @"NSToolTipsFont" toDictionary: dictionary];
  [self addFont: menuFont forKey: @"NSMenuFont" toDictionary: dictionary];
  [self addFont: menuBarFont forKey: @"NSMenuBarFont" toDictionary: dictionary];
  [self addFont: fixedPitchFont forKey: @"NSUserFixedPitchFont" toDictionary: dictionary];

  [dictionary setObject: [NSNumber numberWithFloat: baseFontSize]
                 forKey: @"NSFontSize"];
  [dictionary setObject: [NSNumber numberWithFloat: MAX(9.0, baseFontSize - 1.0)]
                 forKey: @"NSSmallFontSize"];
  [dictionary setObject: [NSNumber numberWithFloat: MAX(8.0, baseFontSize - 2.0)]
                 forKey: @"NSMiniFontSize"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics menuBarHeight]]
                 forKey: @"GSMenuBarHeight"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics menuItemHeight]]
                 forKey: @"GSMenuItemHeight"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics menuSeparatorHeight]]
                 forKey: @"GSMenuSeparatorHeight"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics scrollerWidth]]
                 forKey: @"GSScrollerDefaultWidth"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics minimumTabHeight]]
                 forKey: @"GSMinimumTabHeight"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics maximumTabHeight]]
                 forKey: @"GSMaximumTabHeightPrivate"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics controlHeight]]
                 forKey: @"GSControlHeight"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics textFieldHeight]]
                 forKey: @"GSTextFieldHeightPrivate"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics popupControlHeight]]
                 forKey: @"GSPopupControlHeightPrivate"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics tableRowHeight]]
                 forKey: @"GSTableRowHeightPrivate"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics controlCornerRadius]]
                 forKey: @"GSControlCornerRadiusPrivate"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics windowCornerRadius]]
                 forKey: @"GSWindowCornerRadiusPrivate"];

  return dictionary;
}

- (BOOL) shouldUseWindowIntegration
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id disabledValue = [defaults objectForKey: @"WinUIThemeDisableWindowIntegration"];

  return (disabledValue == nil || [disabledValue boolValue] == NO);
}

- (void) applyRuntimeDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableArray *searchList = [[defaults searchList] mutableCopy];
  NSUInteger index = NSNotFound;

  [defaults setVolatileDomain: [self runtimeDefaultsDictionary]
                      forName: WinUIThemeRuntimeDefaultsDomain];

  if ([searchList containsObject: WinUIThemeRuntimeDefaultsDomain] == NO)
    {
      index = [searchList indexOfObject: @"GSThemeDomain"];
      if (index == NSNotFound)
        {
          index = [searchList indexOfObject: GSConfigDomain];
        }
      if (index == NSNotFound)
        {
          index = [searchList indexOfObject: NSRegistrationDomain];
        }
      if (index == NSNotFound)
        {
          index = [searchList count];
        }

      [searchList insertObject: WinUIThemeRuntimeDefaultsDomain atIndex: index];
      [defaults setSearchList: searchList];
    }

  [defaults synchronize];
  [[NSNotificationCenter defaultCenter]
    postNotificationName: NSUserDefaultsDidChangeNotification
                  object: defaults];
  RELEASE(searchList);
}

- (void) removeRuntimeDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableArray *searchList = [[defaults searchList] mutableCopy];

  [searchList removeObject: WinUIThemeRuntimeDefaultsDomain];
  [defaults setSearchList: searchList];
  [defaults removeVolatileDomainForName: WinUIThemeRuntimeDefaultsDomain];
  [defaults synchronize];
  [[NSNotificationCenter defaultCenter]
    postNotificationName: NSUserDefaultsDidChangeNotification
                  object: defaults];

  RELEASE(searchList);
}

- (void) refreshRuntimeDefaultsIfNeeded
{
  if (_runtimeDefaultsApplied == NO)
    {
      return;
    }

  [self removeRuntimeDefaults];
  [self applyRuntimeDefaults];
}

@end
