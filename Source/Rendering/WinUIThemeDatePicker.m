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

#import "WinUIThemeDrawing.h"
#import "../Settings/WinUIThemeSettings.h"
#import "../Native/WinUIThemeWindowIntegration.h"

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>
#import <objc/runtime.h>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN 1
#include <windows.h>
#endif

/* NSDatePicker as WinUI's DatePicker, TimePicker and CalendarView (#56).
   gui 0.32 draws the date as plain text, time zone offset and all
   ("2026-10-05 19:00:00 -0500"), with no chrome and no way to edit it.

   - The text styles draw a DatePicker field: a button with Month, Day and
     Year parts (in the order Windows' regional settings write them)
     between hairline dividers. Time elements add a TimePicker field
     beside it: Hour, Minute and, on a 12-hour clock, AM/PM. No time zone.
   - Clicking a field opens WinUI's picker flyout over it: a looping
     column per part, the value in an accent band across the middle, and
     accept and dismiss buttons.
   - The calendar style draws a CalendarView: the month with previous and
     next buttons, the weekdays, and a grid of days; today is filled with
     the accent, the picked day outlined. Clicking a day picks it.

   The theme handles the clicks on gui 0.32, which has no editing, and on
   later libs-gui, whose own field selection and stepper wouldn't line up
   with the parts drawn here. */

typedef enum
{
  WinUIThemeDatePartMonth,
  WinUIThemeDatePartDay,
  WinUIThemeDatePartYear,
  WinUIThemeDatePartHour,
  WinUIThemeDatePartMinute,
  WinUIThemeDatePartPeriod
} WinUIThemeDatePart;

typedef struct
{
  WinUIThemeDatePart parts[3];
  NSUInteger count;
} WinUIThemeDatePartList;

/* DatePicker's columns at its 296px minimum width: the month takes what
   the day and year leave. TimePicker is 242px, its columns equal. */
static const CGFloat WinUIThemeDatePickerWidth = 296.0;
static const CGFloat WinUIThemeDatePickerFixedColumn = 80.0;
static const CGFloat WinUIThemeTimePickerWidth = 242.0;
static const CGFloat WinUIThemeDatePickerHeight = 32.0;
/* Between a DatePicker and a TimePicker sharing one control. */
static const CGFloat WinUIThemeDatePickerGap = 8.0;
static const CGFloat WinUIThemeDatePickerTextInset = 12.0;
/* The flyout: 40px rows, nine showing, over a 40px button bar. */
static const CGFloat WinUIThemePickerRowHeight = 40.0;
static const NSInteger WinUIThemePickerVisibleRows = 9;
static const CGFloat WinUIThemePickerFooterHeight = 40.0;
/* CalendarView: 300x360, a 40px header and a 32px weekday row. */
static const CGFloat WinUIThemeCalendarWidth = 300.0;
static const CGFloat WinUIThemeCalendarHeight = 360.0;
static const CGFloat WinUIThemeCalendarHeaderHeight = 40.0;
static const CGFloat WinUIThemeCalendarWeekdayHeight = 32.0;
static const CGFloat WinUIThemeCalendarPadding = 4.0;

static char WinUIThemeCalendarMonthKey;

static WinUITheme *
WinUIThemeDatePickerTheme(void)
{
  GSTheme *theme = [GSTheme theme];

  return [theme isKindOfClass: [WinUITheme class]] ? (WinUITheme *)theme : nil;
}

#pragma mark Elements and calendar

/* gui 0.32 leaves the elements at 0; later libs-gui, like AppKit, starts
   with the date and the time. */
static NSDatePickerElementFlags
WinUIThemeDatePickerElements(NSDatePickerCell *cell)
{
  NSDatePickerElementFlags flags = [cell datePickerElements];

  if ((flags & (NSYearMonthDatePickerElementFlag | NSHourMinuteDatePickerElementFlag)) == 0)
    {
      flags = NSYearMonthDayDatePickerElementFlag | NSHourMinuteSecondDatePickerElementFlag;
    }
  return flags;
}

static BOOL
WinUIThemeDatePickerShowsDate(NSDatePickerCell *cell)
{
  return (WinUIThemeDatePickerElements(cell) & NSYearMonthDatePickerElementFlag) != 0;
}

static BOOL
WinUIThemeDatePickerShowsDay(NSDatePickerCell *cell)
{
  return (WinUIThemeDatePickerElements(cell) & NSYearMonthDayDatePickerElementFlag)
    == NSYearMonthDayDatePickerElementFlag;
}

static BOOL
WinUIThemeDatePickerShowsTime(NSDatePickerCell *cell)
{
  return (WinUIThemeDatePickerElements(cell) & NSHourMinuteDatePickerElementFlag) != 0;
}

static BOOL
WinUIThemeDatePickerShowsCalendar(NSDatePickerCell *cell)
{
  return [cell datePickerStyle] == NSClockAndCalendarDatePickerStyle
    && WinUIThemeDatePickerShowsDate(cell);
}

static NSTimeZone *
WinUIThemeDatePickerTimeZone(NSDatePickerCell *cell)
{
  NSTimeZone *zone = [cell timeZone];

  return (zone != nil) ? zone : [NSTimeZone defaultTimeZone];
}

/* The theme works in the picker's wall-clock time: a date moved by its
   time zone's offset, taken apart and put together by a Gregorian
   calendar (or a copy of the picker's) in GMT. Base's NSCalendar on
   Windows ignored the time zone set on it, so October 5, 19:00 in
   Chicago showed as October 6, 00:00. */
static NSCalendar *
WinUIThemeDatePickerCalendar(NSDatePickerCell *cell)
{
  NSCalendar *calendar = [cell calendar];

  calendar = (calendar != nil)
    ? AUTORELEASE([calendar copy])
    : AUTORELEASE([[NSCalendar alloc] initWithCalendarIdentifier: NSGregorianCalendar]);
  [calendar setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];
  return calendar;
}

static NSDate *
WinUIThemeWallClockDate(NSDatePickerCell *cell, NSDate *date)
{
  return [date addTimeInterval: [WinUIThemeDatePickerTimeZone(cell) secondsFromGMTForDate: date]];
}

/* The moment a wall-clock date stands for. The offset is the one in force
   then, found from a first guess. */
static NSDate *
WinUIThemeRealDate(NSDatePickerCell *cell, NSDate *wallClock)
{
  NSTimeZone *zone = WinUIThemeDatePickerTimeZone(cell);
  NSDate *guess = nil;

  if (wallClock == nil)
    {
      return nil;
    }
  guess = [wallClock addTimeInterval: -[zone secondsFromGMTForDate: wallClock]];
  return [wallClock addTimeInterval: -[zone secondsFromGMTForDate: guess]];
}

/* The picked date, in wall-clock time. */
static NSDate *
WinUIThemeDatePickerDate(NSDatePickerCell *cell)
{
  id value = [cell objectValue];

  return WinUIThemeWallClockDate(cell, [value isKindOfClass: [NSDate class]] ? (NSDate *)value
                                                                             : [NSDate date]);
}

static const NSUInteger WinUIThemeDateUnits = NSYearCalendarUnit | NSMonthCalendarUnit
  | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;

/* Gregorian: base's -rangeOfUnit:inUnit:forDate: answers an empty range. */
static NSInteger
WinUIThemeDaysInMonth(NSCalendar *calendar, NSInteger year, NSInteger month)
{
  static const NSInteger days[12] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
  BOOL leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  (void)calendar;
  if (month < 1 || month > 12)
    {
      return 31;
    }
  return (month == 2 && leap) ? 29 : days[month - 1];
}

#pragma mark Regional settings

#ifdef _WIN32
static NSString *
WinUIThemeStringFromWide(const wchar_t *buffer, int length)
{
  return (length > 1) ? [NSString stringWithCharacters: (const unichar *)buffer length: length - 1] : nil;
}

static NSString *
WinUIThemeLocaleInfo(LCTYPE type)
{
  wchar_t buffer[128];

  return WinUIThemeStringFromWide(buffer, GetLocaleInfoEx(LOCALE_NAME_USER_DEFAULT, type, buffer, 128));
}

/* Formats a date or time with a Windows picture ("MMMM", "h", "tt"), in
   the user's language, or with a flag (DATE_YEARMONTH) when `picture` is
   NULL. */
static NSString *
WinUIThemeFormatSystemTime(NSInteger year, NSInteger month, NSInteger day,
                           NSInteger hour, NSInteger minute,
                           const wchar_t *picture, DWORD flags, BOOL time)
{
  SYSTEMTIME systemTime;
  wchar_t buffer[128];
  int length;

  if (year < 1601 || year > 30827)
    {
      return nil;
    }
  memset(&systemTime, 0, sizeof(systemTime));
  systemTime.wYear = (WORD)year;
  systemTime.wMonth = (WORD)month;
  systemTime.wDay = (WORD)day;
  systemTime.wHour = (WORD)hour;
  systemTime.wMinute = (WORD)minute;
  length = time ? GetTimeFormatEx(LOCALE_NAME_USER_DEFAULT, flags, &systemTime, picture, buffer, 128)
                : GetDateFormatEx(LOCALE_NAME_USER_DEFAULT, flags, &systemTime, picture, buffer, 128, NULL);
  return WinUIThemeStringFromWide(buffer, length);
}
#endif

/* The order of the first of each pattern letter in `letters`, ignoring
   quoted text: "d/MM/yyyy" with "Mdy" gives d, M, y. Letters missing from
   the pattern keep their place in `letters`. */
static void
WinUIThemePatternOrder(NSString *pattern, const char *letters, NSUInteger count, char *order)
{
  NSUInteger found = 0, index, length = [pattern length];
  BOOL quoted = NO;

  for (index = 0; index < length && found < count; index++)
    {
      unichar c = [pattern characterAtIndex: index];
      NSUInteger letter, seen;
      BOOL already = NO;

      if (c == '\'')
        {
          quoted = !quoted;
          continue;
        }
      if (quoted)
        {
          continue;
        }
      for (letter = 0; letter < count; letter++)
        {
          if (c != (unichar)letters[letter])
            {
              continue;
            }
          for (seen = 0; seen < found; seen++)
            {
              already = already || (order[seen] == letters[letter]);
            }
          if (already == NO)
            {
              order[found++] = letters[letter];
            }
        }
    }
  for (index = 0; index < count && found < count; index++)
    {
      NSUInteger seen;
      BOOL already = NO;

      for (seen = 0; seen < found; seen++)
        {
          already = already || (order[seen] == letters[index]);
        }
      if (already == NO)
        {
          order[found++] = letters[index];
        }
    }
}

/* The month, day and year in the order of the user's short date. */
static void
WinUIThemeDateOrder(char order[3])
{
  NSString *pattern = @"M/d/yyyy";

#ifdef _WIN32
  NSString *system = WinUIThemeLocaleInfo(LOCALE_SSHORTDATE);

  if (system != nil)
    {
      pattern = system;
    }
#endif
  WinUIThemePatternOrder(pattern, "Mdy", 3, order);
}

/* YES for a 12-hour clock; `periodFirst` when AM/PM comes before the hour. */
static BOOL
WinUIThemeUsesTwelveHourClock(BOOL *periodFirst)
{
  NSString *pattern = @"h:mm:ss tt";
  char order[2];

#ifdef _WIN32
  NSString *system = WinUIThemeLocaleInfo(LOCALE_STIMEFORMAT);

  if (system != nil)
    {
      pattern = system;
    }
#endif
  WinUIThemePatternOrder([pattern lowercaseString], "ht", 2, order);
  if (periodFirst != NULL)
    {
      *periodFirst = (order[0] == 't');
    }
  /* "H" is the 24-hour clock; "h" with no designator is 12-hour too. */
  return [pattern rangeOfString: @"H"].location == NSNotFound;
}

static NSString *
WinUIThemeMonthName(NSInteger month)
{
  NSString *name = nil;

#ifdef _WIN32
  name = WinUIThemeFormatSystemTime(2000, month, 1, 0, 0, L"MMMM", 0, NO);
#endif
  if (name == nil)
    {
      NSArray *names = [[[NSDateFormatter new] autorelease] standaloneMonthSymbols];

      name = (month >= 1 && (NSUInteger)month <= [names count])
        ? [names objectAtIndex: month - 1]
        : [NSString stringWithFormat: @"%ld", (long)month];
    }
  return name;
}

static NSString *
WinUIThemePeriodName(BOOL afternoon)
{
  NSString *name = nil;

#ifdef _WIN32
  name = WinUIThemeLocaleInfo(afternoon ? LOCALE_S2359 : LOCALE_S1159);
#endif
  return ([name length] > 0) ? name : (afternoon ? @"PM" : @"AM");
}

/* Calendar weekday (1 for Sunday) the week starts on. */
static NSInteger
WinUIThemeFirstWeekday(void)
{
#ifdef _WIN32
  NSString *first = WinUIThemeLocaleInfo(LOCALE_IFIRSTDAYOFWEEK);

  if (first != nil)
    {
      /* Windows counts from Monday, 0. */
      return (([first intValue] + 1) % 7) + 1;
    }
#endif
  return 1;
}

/* "Su", "Mo"...: the shortest name of calendar weekday `weekday`. */
static NSString *
WinUIThemeWeekdayName(NSInteger weekday)
{
  NSString *name = nil;

#ifdef _WIN32
  wchar_t buffer[32];
  /* CAL_SSHORTESTDAYNAME1 is Monday. */
  CALTYPE type = CAL_SSHORTESTDAYNAME1 + (CALTYPE)((weekday + 5) % 7);

  name = WinUIThemeStringFromWide(buffer, GetCalendarInfoEx(LOCALE_NAME_USER_DEFAULT, CAL_GREGORIAN,
                                                             NULL, type, buffer, 32, NULL));
#endif
  if (name == nil)
    {
      static NSString *names[7] = { @"Su", @"Mo", @"Tu", @"We", @"Th", @"Fr", @"Sa" };

      name = names[(weekday - 1) % 7];
    }
  return name;
}

static NSString *
WinUIThemeYearMonthTitle(NSInteger year, NSInteger month)
{
  NSString *title = nil;

#ifdef _WIN32
  title = WinUIThemeFormatSystemTime(year, month, 1, 0, 0, NULL, DATE_YEARMONTH, NO);
#endif
  return (title != nil) ? title
    : [NSString stringWithFormat: @"%@ %ld", WinUIThemeMonthName(month), (long)year];
}

#pragma mark Parts

static WinUIThemeDatePartList
WinUIThemeDateParts(NSDatePickerCell *cell)
{
  WinUIThemeDatePartList list;
  char order[3];
  NSUInteger index;

  list.count = 0;
  WinUIThemeDateOrder(order);
  for (index = 0; index < 3; index++)
    {
      if (order[index] == 'M')
        {
          list.parts[list.count++] = WinUIThemeDatePartMonth;
        }
      else if (order[index] == 'd' && WinUIThemeDatePickerShowsDay(cell))
        {
          list.parts[list.count++] = WinUIThemeDatePartDay;
        }
      else if (order[index] == 'y')
        {
          list.parts[list.count++] = WinUIThemeDatePartYear;
        }
    }
  return list;
}

static WinUIThemeDatePartList
WinUIThemeTimeParts(void)
{
  WinUIThemeDatePartList list;
  BOOL periodFirst = NO;
  BOOL twelve = WinUIThemeUsesTwelveHourClock(&periodFirst);

  list.count = 0;
  if (twelve && periodFirst)
    {
      list.parts[list.count++] = WinUIThemeDatePartPeriod;
    }
  list.parts[list.count++] = WinUIThemeDatePartHour;
  list.parts[list.count++] = WinUIThemeDatePartMinute;
  if (twelve && periodFirst == NO)
    {
      list.parts[list.count++] = WinUIThemeDatePartPeriod;
    }
  return list;
}

static NSString *
WinUIThemeDatePartString(WinUIThemeDatePart part, NSInteger value)
{
  switch (part)
    {
      case WinUIThemeDatePartMonth:
        return WinUIThemeMonthName(value);
      case WinUIThemeDatePartMinute:
        return [NSString stringWithFormat: @"%02ld", (long)value];
      case WinUIThemeDatePartPeriod:
        return WinUIThemePeriodName(value != 0);
      case WinUIThemeDatePartHour:
        {
          BOOL twelve = WinUIThemeUsesTwelveHourClock(NULL);

          if (twelve)
            {
              return [NSString stringWithFormat: @"%ld", (long)((value % 12 == 0) ? 12 : value % 12)];
            }
          return [NSString stringWithFormat: @"%02ld", (long)value];
        }
      default:
        return [NSString stringWithFormat: @"%ld", (long)value];
    }
}

static NSInteger
WinUIThemeDatePartValue(WinUIThemeDatePart part, NSDateComponents *components)
{
  switch (part)
    {
      case WinUIThemeDatePartMonth: return [components month];
      case WinUIThemeDatePartDay: return [components day];
      case WinUIThemeDatePartYear: return [components year];
      case WinUIThemeDatePartHour: return [components hour];
      case WinUIThemeDatePartMinute: return [components minute];
      case WinUIThemeDatePartPeriod: return ([components hour] >= 12) ? 1 : 0;
    }
  return 0;
}

/* The width of each part's column in a field `width` wide. The month
   takes what the fixed columns leave; time columns share it equally. */
static void
WinUIThemeDatePartWidths(WinUIThemeDatePartList list, CGFloat width, CGFloat *widths)
{
  NSUInteger index, flexible = NSNotFound;
  CGFloat fixed = MIN(WinUIThemeDatePickerFixedColumn,
                      floor(width * WinUIThemeDatePickerFixedColumn / WinUIThemeDatePickerWidth));
  CGFloat used = 0.0;

  for (index = 0; index < list.count; index++)
    {
      if (list.parts[index] == WinUIThemeDatePartMonth)
        {
          flexible = index;
        }
    }
  for (index = 0; index < list.count; index++)
    {
      if (flexible == NSNotFound)
        {
          widths[index] = (index + 1 == list.count) ? width - used : floor(width / list.count);
        }
      else
        {
          widths[index] = (index == flexible) ? 0.0 : fixed;
        }
      used += widths[index];
    }
  if (flexible != NSNotFound)
    {
      widths[flexible] = width - used;
    }
}

/* The DatePicker and TimePicker fields in `frame`; either may be empty. */
static void
WinUIThemeDatePickerFields(NSDatePickerCell *cell, NSRect frame, NSRect *dateField, NSRect *timeField)
{
  BOOL date = WinUIThemeDatePickerShowsDate(cell);
  BOOL time = WinUIThemeDatePickerShowsTime(cell);

  *dateField = NSZeroRect;
  *timeField = NSZeroRect;
  if (date && time)
    {
      CGFloat dateWidth = floor((NSWidth(frame) - WinUIThemeDatePickerGap) * WinUIThemeDatePickerWidth
                                / (WinUIThemeDatePickerWidth + WinUIThemeTimePickerWidth));

      *dateField = NSMakeRect(NSMinX(frame), NSMinY(frame), dateWidth, NSHeight(frame));
      *timeField = NSMakeRect(NSMaxX(*dateField) + WinUIThemeDatePickerGap, NSMinY(frame),
                              NSMaxX(frame) - NSMaxX(*dateField) - WinUIThemeDatePickerGap,
                              NSHeight(frame));
    }
  else if (time)
    {
      *timeField = frame;
    }
  else
    {
      *dateField = frame;
    }
}

#pragma mark Colours

/* The dividers: ControlStrokeColorDefault, which over the field's fill
   is near invisible in the dark palette, so stronger there. */
static NSColor *
WinUIThemeDatePickerDividerColor(WinUITheme *theme, BOOL enabled)
{
  BOOL dark = [[theme settings] prefersDarkAppearance];
  NSColor *window = WinUIThemeColorFromTheme(theme, @"windowBackgroundColor",
                                             [NSColor windowBackgroundColor]);

  if ([[theme settings] highContrastEnabled])
    {
      return enabled ? WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor])
                     : WinUIThemeColorFromTheme(theme, @"disabledControlTextColor",
                                                [NSColor disabledControlTextColor]);
    }
  return WinUIThemeBlendColor(window, dark ? [NSColor whiteColor] : [NSColor blackColor],
                              dark ? 0.18 : 0.10);
}

static NSColor *
WinUIThemeDatePickerAccent(WinUITheme *theme)
{
  return WinUIThemeColorFromTheme(theme, @"accentColor", [NSColor selectedControlColor]);
}

static NSColor *
WinUIThemeDatePickerOnAccent(WinUITheme *theme)
{
  return WinUIThemeColorFromTheme(theme, @"selectedControlTextColor", [NSColor selectedControlTextColor]);
}

static NSDictionary *
WinUIThemeDatePickerTextAttributes(NSFont *font, NSColor *color)
{
  NSMutableParagraphStyle *style = AUTORELEASE([[NSMutableParagraphStyle alloc] init]);

  [style setLineBreakMode: NSLineBreakByClipping];
  return [NSDictionary dictionaryWithObjectsAndKeys:
                         font, NSFontAttributeName,
                         color, NSForegroundColorAttributeName,
                         style, NSParagraphStyleAttributeName, nil];
}

/* Draws `string` in `column`: from the leading inset, or centred. */
static void
WinUIThemeDrawColumnString(NSString *string, NSRect column, BOOL leading, NSDictionary *attributes)
{
  NSSize size = [string sizeWithAttributes: attributes];
  NSRect textRect;

  textRect.size = NSMakeSize(MIN(size.width, NSWidth(column) - 4.0), size.height);
  textRect.origin.x = leading ? NSMinX(column) + WinUIThemeDatePickerTextInset
                              : floor(NSMidX(column) - NSWidth(textRect) / 2.0);
  textRect.origin.y = floor(NSMidY(column) - size.height / 2.0);
  if (leading)
    {
      textRect.size.width = MIN(size.width, NSMaxX(column) - NSMinX(textRect) - 2.0);
    }
  if (NSWidth(textRect) > 0.0)
    {
      [string drawInRect: textRect withAttributes: attributes];
    }
}

#pragma mark Field

static void
WinUIThemeDrawPickerField(WinUITheme *theme, NSView *view, NSRect field, WinUIThemeDatePartList list,
                          NSDateComponents *components, NSFont *font,
                          BOOL enabled, BOOL pressed, BOOL hover)
{
  NSColor *textColor = nil;
  NSColor *divider = WinUIThemeDatePickerDividerColor(theme, enabled);
  NSDictionary *attributes = nil;
  CGFloat widths[3];
  CGFloat x = NSMinX(field);
  NSUInteger index;

  if (NSWidth(field) < 4.0 || list.count == 0)
    {
      return;
    }
  textColor = WinUIThemeDrawButtonChrome(theme, field, view, enabled, NO, pressed, hover);
  attributes = WinUIThemeDatePickerTextAttributes(font, textColor);
  WinUIThemeDatePartWidths(list, NSWidth(field), widths);
  for (index = 0; index < list.count; index++)
    {
      WinUIThemeDatePart part = list.parts[index];
      NSRect column = NSMakeRect(x, NSMinY(field), widths[index], NSHeight(field));

      if (index > 0)
        {
          [divider set];
          NSRectFill(NSMakeRect(floor(x), NSMinY(field) + 1.0, 1.0, NSHeight(field) - 2.0));
        }
      [NSGraphicsContext saveGraphicsState];
      NSRectClip(NSInsetRect(column, 1.0, 1.0));
      WinUIThemeDrawColumnString(WinUIThemeDatePartString(part, WinUIThemeDatePartValue(part, components)),
                                 column, part == WinUIThemeDatePartMonth, attributes);
      [NSGraphicsContext restoreGraphicsState];
      x += widths[index];
    }
}

#pragma mark CalendarView

/* The first day of the month the calendar shows: the picked date's, until
   the previous and next buttons move it. */
static NSDateComponents *
WinUIThemeCalendarShownMonth(NSDatePickerCell *cell, NSCalendar *calendar)
{
  NSDateComponents *shown = objc_getAssociatedObject(cell, &WinUIThemeCalendarMonthKey);
  NSDateComponents *components = nil;

  if (shown != nil)
    {
      return shown;
    }
  components = [calendar components: NSYearCalendarUnit | NSMonthCalendarUnit
                           fromDate: WinUIThemeDatePickerDate(cell)];
  [components setDay: 1];
  [components setHour: 12];
  return components;
}

static void
WinUIThemeCalendarShowMonth(NSDatePickerCell *cell, NSInteger year, NSInteger month)
{
  NSDateComponents *components = AUTORELEASE([NSDateComponents new]);

  while (month < 1)
    {
      month += 12;
      year--;
    }
  while (month > 12)
    {
      month -= 12;
      year++;
    }
  [components setYear: year];
  [components setMonth: month];
  [components setDay: 1];
  [components setHour: 12];
  objc_setAssociatedObject(cell, &WinUIThemeCalendarMonthKey, components, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

typedef struct
{
  NSRect header;
  NSRect previous;
  NSRect next;
  NSRect weekdays;
  NSRect grid;
  CGFloat cellWidth;
  CGFloat cellHeight;
} WinUIThemeCalendarLayout;

/* `frame`'s layout, top down whichever way the view is flipped. */
static WinUIThemeCalendarLayout
WinUIThemeCalendarLayoutForFrame(NSRect frame, BOOL flipped)
{
  WinUIThemeCalendarLayout layout;
  NSRect inner = NSInsetRect(frame, WinUIThemeCalendarPadding, WinUIThemeCalendarPadding);
  NSRect rest;

  NSDivideRect(inner, &layout.header, &rest, WinUIThemeCalendarHeaderHeight, flipped ? NSMinYEdge : NSMaxYEdge);
  NSDivideRect(rest, &layout.weekdays, &layout.grid, WinUIThemeCalendarWeekdayHeight,
               flipped ? NSMinYEdge : NSMaxYEdge);
  layout.next = NSMakeRect(NSMaxX(layout.header) - 40.0, NSMinY(layout.header), 40.0, NSHeight(layout.header));
  layout.previous = NSOffsetRect(layout.next, -40.0, 0.0);
  layout.cellWidth = floor(NSWidth(layout.grid) / 7.0);
  layout.cellHeight = floor(NSHeight(layout.grid) / 6.0);
  return layout;
}

/* Grid cell `index` (0 top left, row by row). */
static NSRect
WinUIThemeCalendarCellRect(WinUIThemeCalendarLayout layout, NSInteger index, BOOL flipped)
{
  NSInteger row = index / 7, column = index % 7;
  CGFloat x = NSMinX(layout.grid) + floor((NSWidth(layout.grid) - 7.0 * layout.cellWidth) / 2.0)
    + column * layout.cellWidth;
  CGFloat y = flipped ? NSMinY(layout.grid) + row * layout.cellHeight
                      : NSMaxY(layout.grid) - (row + 1) * layout.cellHeight;

  return NSMakeRect(x, y, layout.cellWidth, layout.cellHeight);
}

/* The date in grid cell 0, which may be in the month before. */
static NSDate *
WinUIThemeCalendarFirstCellDate(NSCalendar *calendar, NSDateComponents *month)
{
  NSDate *first = [calendar dateFromComponents: month];
  NSInteger weekday = [[calendar components: NSWeekdayCalendarUnit fromDate: first] weekday];
  NSInteger lead = (weekday - WinUIThemeFirstWeekday() + 7) % 7;
  NSDateComponents *back = AUTORELEASE([NSDateComponents new]);

  [back setDay: -lead];
  return [calendar dateByAddingComponents: back toDate: first options: 0];
}

static NSDate *
WinUIThemeCalendarCellDate(NSCalendar *calendar, NSDate *firstCell, NSInteger index)
{
  NSDateComponents *step = AUTORELEASE([NSDateComponents new]);

  [step setDay: index];
  return [calendar dateByAddingComponents: step toDate: firstCell options: 0];
}

static BOOL
WinUIThemeSameDay(NSCalendar *calendar, NSDate *a, NSDate *b)
{
  NSUInteger units = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit;
  NSDateComponents *one = [calendar components: units fromDate: a];
  NSDateComponents *two = [calendar components: units fromDate: b];

  return [one year] == [two year] && [one month] == [two month] && [one day] == [two day];
}

static void
WinUIThemeDrawCalendar(WinUITheme *theme, NSDatePickerCell *cell, NSRect frame, NSView *view)
{
  BOOL flipped = [view isFlipped];
  BOOL enabled = [cell isEnabled];
  NSCalendar *calendar = WinUIThemeDatePickerCalendar(cell);
  NSDateComponents *month = WinUIThemeCalendarShownMonth(cell, calendar);
  WinUIThemeCalendarLayout layout = WinUIThemeCalendarLayoutForFrame(frame, flipped);
  NSDate *firstCell = WinUIThemeCalendarFirstCellDate(calendar, month);
  NSDate *picked = WinUIThemeDatePickerDate(cell);
  NSDate *today = WinUIThemeWallClockDate(cell, [NSDate date]);
  NSColor *text = enabled ? WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor])
                          : WinUIThemeColorFromTheme(theme, @"disabledControlTextColor",
                                                     [NSColor disabledControlTextColor]);
  NSColor *secondary = enabled ? WinUIThemeColorFromTheme(theme, @"secondaryLabelColor", text) : text;
  NSColor *accent = enabled ? WinUIThemeDatePickerAccent(theme) : text;
  NSFont *font = WinUIThemePreferredControlFont(theme, [cell font], NO);
  NSFont *small = [NSFont systemFontOfSize: MAX(9.0, [font pointSize] - 2.0)];
  NSFont *bold = WinUIThemePreferredControlFont(theme, [cell font], YES);
  NSDictionary *attributes = nil;
  NSInteger index;

  /* The card: a 1px stroke around the control fill, 8px corners. */
  WinUIThemeFillAndStrokeRoundedRect(NSInsetRect(NSIntegralRect(frame), 0.5, 0.5),
                                     WinUIThemeOverlayCornerRadius(theme),
                                     WinUIThemeTextBoxFillColor(theme, enabled, NO, NO),
                                     WinUIThemeDatePickerDividerColor(theme, enabled), 1.0);

  /* The month, and the previous and next buttons. */
  attributes = WinUIThemeDatePickerTextAttributes(bold, text);
  {
    NSRect title = layout.header;

    title.size.width = NSMinX(layout.previous) - NSMinX(title);
    WinUIThemeDrawColumnString(WinUIThemeYearMonthTitle([month year], [month month]), title, YES, attributes);
  }
  WinUIThemeDrawChevron(NSMakePoint(NSMidX(layout.previous), NSMidY(layout.previous)), flipped == NO, text);
  WinUIThemeDrawChevron(NSMakePoint(NSMidX(layout.next), NSMidY(layout.next)), flipped, text);

  /* The weekdays, from the one the week starts on. */
  attributes = WinUIThemeDatePickerTextAttributes(small, text);
  for (index = 0; index < 7; index++)
    {
      NSRect column = WinUIThemeCalendarCellRect(layout, index, flipped);

      column.origin.y = NSMinY(layout.weekdays);
      column.size.height = NSHeight(layout.weekdays);
      WinUIThemeDrawColumnString(WinUIThemeWeekdayName((WinUIThemeFirstWeekday() - 1 + index) % 7 + 1),
                                 column, NO, attributes);
    }

  /* Six weeks of days. Today is filled with the accent, the picked day
     outlined in it; days of the months either side are secondary. */
  for (index = 0; index < 42; index++)
    {
      NSDate *day = WinUIThemeCalendarCellDate(calendar, firstCell, index);
      NSDateComponents *parts = [calendar components: NSMonthCalendarUnit | NSDayCalendarUnit fromDate: day];
      NSRect cellRect = WinUIThemeCalendarCellRect(layout, index, flipped);
      CGFloat diameter = MIN(MIN(NSWidth(cellRect), NSHeight(cellRect)) - 4.0, 36.0);
      NSRect circle = WinUIThemeCenteredRect(cellRect, diameter, diameter);
      BOOL isToday = WinUIThemeSameDay(calendar, day, today);
      BOOL isPicked = WinUIThemeSameDay(calendar, day, picked);
      NSColor *color = ([parts month] == [month month]) ? text : secondary;

      if (isToday)
        {
          [accent set];
          [[NSBezierPath bezierPathWithOvalInRect: circle] fill];
          color = enabled ? WinUIThemeDatePickerOnAccent(theme) : [NSColor whiteColor];
        }
      if (isPicked)
        {
          NSBezierPath *ring = [NSBezierPath bezierPathWithOvalInRect: NSInsetRect(circle, isToday ? -2.5 : 0.5,
                                                                                   isToday ? -2.5 : 0.5)];

          [accent set];
          [ring setLineWidth: 1.0];
          [ring stroke];
        }
      WinUIThemeDrawColumnString([NSString stringWithFormat: @"%ld", (long)[parts day]], cellRect, NO,
                                 WinUIThemeDatePickerTextAttributes(font, color));
    }
}

#pragma mark Picker flyout

/* One looping column of the flyout. */
@interface WinUIThemePickerColumn : NSObject
{
@public
  WinUIThemeDatePart part;
  NSInteger minimum;
  NSInteger count;
  NSInteger selected;
  BOOL loops;
  CGFloat width;
}
@end

@implementation WinUIThemePickerColumn
@end

/* WinUI's DatePickerFlyout and TimePickerFlyout: a column per part, nine
   40px rows of each, the value in an accent band across the middle, and
   accept and dismiss buttons under them. Run by
   WinUIThemeRunPickerFlyout(). */
@interface WinUIThemeDatePickerFlyoutView : NSView
{
  WinUITheme *_theme;
  NSMutableArray *_columns;
  NSCalendar *_calendar;
  NSDateComponents *_components;
  NSFont *_font;
  NSInteger _focused;
  NSInteger _result;
  NSInteger _hoverButton;
}
- (id) initWithTheme: (WinUITheme *)theme
               parts: (WinUIThemeDatePartList)list
              widths: (CGFloat *)widths
          components: (NSDateComponents *)components
            calendar: (NSCalendar *)calendar
                font: (NSFont *)font
           yearRange: (NSRange)years;
/* 0 while open, 1 accepted, -1 dismissed. */
- (NSInteger) result;
- (void) setResult: (NSInteger)result;
/* The parts picked, over the date's. */
- (NSDateComponents *) components;
/* From the top of the view to the middle of the band. */
+ (CGFloat) bandCentre;
+ (CGFloat) heightOfFlyout;
@end

@implementation WinUIThemeDatePickerFlyoutView

+ (CGFloat) bandCentre
{
  return WinUIThemePickerRowHeight * (WinUIThemePickerVisibleRows / 2 + 0.5);
}

+ (CGFloat) heightOfFlyout
{
  return WinUIThemePickerRowHeight * WinUIThemePickerVisibleRows + 1.0 + WinUIThemePickerFooterHeight;
}

- (id) initWithTheme: (WinUITheme *)theme
               parts: (WinUIThemeDatePartList)list
              widths: (CGFloat *)widths
          components: (NSDateComponents *)components
            calendar: (NSCalendar *)calendar
                font: (NSFont *)font
           yearRange: (NSRange)years
{
  CGFloat width = 0.0;
  NSUInteger index;

  for (index = 0; index < list.count; index++)
    {
      width += widths[index];
    }
  self = [super initWithFrame: NSMakeRect(0.0, 0.0, width, [[self class] heightOfFlyout])];
  if (self == nil)
    {
      return nil;
    }
  ASSIGN(_theme, theme);
  ASSIGN(_calendar, calendar);
  _components = [components copy];
  ASSIGN(_font, font);
  _columns = [NSMutableArray new];
  _hoverButton = -1;
  for (index = 0; index < list.count; index++)
    {
      WinUIThemePickerColumn *column = AUTORELEASE([WinUIThemePickerColumn new]);
      NSInteger value = WinUIThemeDatePartValue(list.parts[index], components);

      column->part = list.parts[index];
      column->width = widths[index];
      column->loops = YES;
      switch (column->part)
        {
          case WinUIThemeDatePartMonth:
            column->minimum = 1;
            column->count = 12;
            break;
          case WinUIThemeDatePartDay:
            column->minimum = 1;
            column->count = WinUIThemeDaysInMonth(calendar, [components year], [components month]);
            break;
          case WinUIThemeDatePartYear:
            column->minimum = years.location;
            column->count = years.length;
            column->loops = NO;
            break;
          case WinUIThemeDatePartHour:
            column->minimum = WinUIThemeUsesTwelveHourClock(NULL) ? 1 : 0;
            column->count = WinUIThemeUsesTwelveHourClock(NULL) ? 12 : 24;
            if (column->minimum == 1)
              {
                value = (value % 12 == 0) ? 12 : value % 12;
              }
            break;
          case WinUIThemeDatePartMinute:
            column->minimum = 0;
            column->count = 60;
            break;
          case WinUIThemeDatePartPeriod:
            column->minimum = 0;
            column->count = 2;
            column->loops = NO;
            break;
        }
      column->count = MAX(1, column->count);
      column->selected = MAX(0, MIN(column->count - 1, value - column->minimum));
      [_columns addObject: column];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_theme);
  RELEASE(_columns);
  RELEASE(_calendar);
  RELEASE(_components);
  RELEASE(_font);
  [super dealloc];
}

- (BOOL) isFlipped
{
  return YES;
}

- (BOOL) acceptsFirstMouse: (NSEvent *)event
{
  return YES;
}

- (NSInteger) result
{
  return _result;
}

- (void) setResult: (NSInteger)result
{
  _result = result;
}

- (WinUIThemePickerColumn *) columnOfPart: (WinUIThemeDatePart)part
{
  NSEnumerator *enumerator = [_columns objectEnumerator];
  WinUIThemePickerColumn *column = nil;

  while ((column = [enumerator nextObject]) != nil)
    {
      if (column->part == part)
        {
          return column;
        }
    }
  return nil;
}

- (NSInteger) valueOfColumn: (WinUIThemePickerColumn *)column
{
  return column->minimum + column->selected;
}

/* The day column follows the month and year: 28 to 31 days. */
- (void) updateDays
{
  WinUIThemePickerColumn *day = [self columnOfPart: WinUIThemeDatePartDay];
  WinUIThemePickerColumn *month = [self columnOfPart: WinUIThemeDatePartMonth];
  WinUIThemePickerColumn *year = [self columnOfPart: WinUIThemeDatePartYear];

  if (day == nil)
    {
      return;
    }
  day->count = WinUIThemeDaysInMonth(_calendar,
                                     (year != nil) ? [self valueOfColumn: year] : [_components year],
                                     (month != nil) ? [self valueOfColumn: month] : [_components month]);
  day->count = MAX(1, day->count);
  day->selected = MIN(day->selected, day->count - 1);
}

- (void) moveColumn: (NSUInteger)index by: (NSInteger)delta
{
  WinUIThemePickerColumn *column = nil;

  if (index >= [_columns count] || delta == 0)
    {
      return;
    }
  column = [_columns objectAtIndex: index];
  if (column->loops)
    {
      column->selected = ((column->selected + delta) % column->count + column->count) % column->count;
    }
  else
    {
      column->selected = MAX(0, MIN(column->count - 1, column->selected + delta));
    }
  [self updateDays];
  [self setNeedsDisplay: YES];
}

- (NSDateComponents *) components
{
  NSDateComponents *components = AUTORELEASE([_components copy]);
  NSEnumerator *enumerator = [_columns objectEnumerator];
  WinUIThemePickerColumn *column = nil;
  NSInteger hour = [_components hour];
  BOOL afternoon = (hour >= 12);
  WinUIThemePickerColumn *hourColumn = [self columnOfPart: WinUIThemeDatePartHour];

  while ((column = [enumerator nextObject]) != nil)
    {
      NSInteger value = [self valueOfColumn: column];

      switch (column->part)
        {
          case WinUIThemeDatePartMonth: [components setMonth: value]; break;
          case WinUIThemeDatePartDay: [components setDay: value]; break;
          case WinUIThemeDatePartYear: [components setYear: value]; break;
          case WinUIThemeDatePartMinute: [components setMinute: value]; break;
          case WinUIThemeDatePartHour: hour = value; break;
          case WinUIThemeDatePartPeriod: afternoon = (value != 0); break;
        }
    }
  if (hourColumn != nil)
    {
      if (hourColumn->minimum == 1)
        {
          hour = (hour % 12) + (afternoon ? 12 : 0);
        }
      [components setHour: hour];
    }
  else if ([self columnOfPart: WinUIThemeDatePartPeriod] != nil)
    {
      [components setHour: (hour % 12) + (afternoon ? 12 : 0)];
    }
  return components;
}

- (NSRect) rowsRect
{
  return NSMakeRect(0.0, 0.0, NSWidth([self bounds]), WinUIThemePickerRowHeight * WinUIThemePickerVisibleRows);
}

- (NSRect) bandRect
{
  return NSMakeRect(4.0, WinUIThemePickerRowHeight * (WinUIThemePickerVisibleRows / 2) + 2.0,
                    NSWidth([self bounds]) - 8.0, WinUIThemePickerRowHeight - 4.0);
}

/* The accept (0) and dismiss (1) buttons. */
- (NSRect) buttonRect: (NSInteger)button
{
  CGFloat top = NSMaxY([self rowsRect]) + 1.0;
  CGFloat half = floor(NSWidth([self bounds]) / 2.0);

  return NSMakeRect(button == 0 ? 0.0 : half, top,
                    button == 0 ? half : NSWidth([self bounds]) - half, WinUIThemePickerFooterHeight);
}

- (void) drawRect: (NSRect)rect
{
  WinUITheme *theme = _theme;
  NSColor *background = WinUIThemeColorFromTheme(theme, @"menuBackgroundColor", [NSColor controlBackgroundColor]);
  NSColor *border = WinUIThemeColorFromTheme(theme, @"menuBorderColor", [NSColor gridColor]);
  NSColor *text = WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor]);
  NSColor *accent = WinUIThemeDatePickerAccent(theme);
  NSColor *onAccent = WinUIThemeDatePickerOnAccent(theme);
  NSDictionary *plain = WinUIThemeDatePickerTextAttributes(_font, text);
  NSDictionary *picked = WinUIThemeDatePickerTextAttributes(_font, onAccent);
  NSRect bounds = [self bounds];
  NSRect band = [self bandRect];
  NSInteger middle = WinUIThemePickerVisibleRows / 2;
  CGFloat x = 0.0;
  NSUInteger index;

  /* Square, with a hairline border: DWM rounds and shadows the window
     where it can, as it does menus. */
  [background set];
  NSRectFill(bounds);
  [border set];
  NSFrameRect(bounds);
  WinUIThemeFillAndStrokeRoundedRect(band, WinUIThemeControlCornerRadius(theme), accent, nil, 0.0);

  for (index = 0; index < [_columns count]; index++)
    {
      WinUIThemePickerColumn *column = [_columns objectAtIndex: index];
      NSInteger row;

      for (row = 0; row < WinUIThemePickerVisibleRows; row++)
        {
          NSInteger item = column->selected + (row - middle);
          NSRect cell = NSMakeRect(x, row * WinUIThemePickerRowHeight, column->width, WinUIThemePickerRowHeight);

          if (column->loops)
            {
              item = (item % column->count + column->count) % column->count;
            }
          else if (item < 0 || item >= column->count)
            {
              continue;
            }
          WinUIThemeDrawColumnString(WinUIThemeDatePartString(column->part, column->minimum + item),
                                     NSInsetRect(cell, 4.0, 0.0),
                                     column->part == WinUIThemeDatePartMonth,
                                     (row == middle) ? picked : plain);
        }
      x += column->width;
    }

  /* The button bar, under a divider. */
  [border set];
  NSRectFill(NSMakeRect(0.0, NSMaxY([self rowsRect]), NSWidth(bounds), 1.0));
  for (index = 0; index < 2; index++)
    {
      NSRect button = [self buttonRect: index];

      if ((NSInteger)index == _hoverButton)
        {
          WinUIThemeFillAndStrokeRoundedRect(NSInsetRect(button, 4.0, 4.0), WinUIThemeControlCornerRadius(theme),
                                             WinUIThemeColorWithAlpha(text, 0.06), nil, 0.0);
        }
      if (index == 0)
        {
          /* Segoe's Accept: a thin 16x12 tick. */
          NSRect glyph = WinUIThemeCenteredRect(button, 16.0, 12.0);
          NSBezierPath *tick = [NSBezierPath bezierPath];

          [tick moveToPoint: NSMakePoint(NSMinX(glyph), NSMinY(glyph) + 0.5 * NSHeight(glyph))];
          [tick lineToPoint: NSMakePoint(NSMinX(glyph) + 0.35 * NSWidth(glyph), NSMaxY(glyph))];
          [tick lineToPoint: NSMakePoint(NSMaxX(glyph), NSMinY(glyph))];
          [tick setLineWidth: 1.3];
          [tick setLineCapStyle: NSRoundLineCapStyle];
          [tick setLineJoinStyle: NSRoundLineJoinStyle];
          [text set];
          [tick stroke];
        }
      else
        {
          WinUIThemeDrawCrossGlyph(WinUIThemeCenteredRect(button, 12.0, 12.0), text);
        }
    }
}

- (NSInteger) columnAtX: (CGFloat)x
{
  CGFloat start = 0.0;
  NSUInteger index;

  for (index = 0; index < [_columns count]; index++)
    {
      WinUIThemePickerColumn *column = [_columns objectAtIndex: index];

      if (x >= start && x < start + column->width)
        {
          return index;
        }
      start += column->width;
    }
  return -1;
}

- (void) mouseDown: (NSEvent *)event
{
  NSPoint point = [self convertPoint: [event locationInWindow] fromView: nil];
  NSInteger column = [self columnAtX: point.x];

  if (NSPointInRect(point, [self buttonRect: 0]))
    {
      _result = 1;
      return;
    }
  if (NSPointInRect(point, [self buttonRect: 1]))
    {
      _result = -1;
      return;
    }
  if (column >= 0 && NSPointInRect(point, [self rowsRect]))
    {
      NSInteger row = (NSInteger)floor(point.y / WinUIThemePickerRowHeight);

      _focused = column;
      [self moveColumn: column by: row - WinUIThemePickerVisibleRows / 2];
    }
}

- (void) mouseMoved: (NSEvent *)event
{
  NSPoint point = [self convertPoint: [event locationInWindow] fromView: nil];
  NSInteger hover = NSPointInRect(point, [self buttonRect: 0]) ? 0
    : (NSPointInRect(point, [self buttonRect: 1]) ? 1 : -1);

  if (hover != _hoverButton)
    {
      _hoverButton = hover;
      [self setNeedsDisplay: YES];
    }
}

- (void) scrollWheel: (NSEvent *)event
{
  NSPoint point = [self convertPoint: [event locationInWindow] fromView: nil];
  NSInteger column = [self columnAtX: point.x];
  CGFloat delta = [event deltaY];

  if (column >= 0 && delta != 0.0)
    {
      _focused = column;
      [self moveColumn: column by: (delta > 0.0) ? -1 : 1];
    }
}

/* Up and down change the focused column, left, right and tab move
   between columns, Enter accepts and Escape dismisses. */
- (void) keyDown: (NSEvent *)event
{
  NSString *characters = [event charactersIgnoringModifiers];
  unichar key = ([characters length] > 0) ? [characters characterAtIndex: 0] : 0;
  NSInteger count = [_columns count];

  switch (key)
    {
      case NSUpArrowFunctionKey:
        [self moveColumn: _focused by: -1];
        break;
      case NSDownArrowFunctionKey:
        [self moveColumn: _focused by: 1];
        break;
      case NSLeftArrowFunctionKey:
      case NSBackTabCharacter:
        _focused = (_focused + count - 1) % count;
        break;
      case NSRightArrowFunctionKey:
      case NSTabCharacter:
        _focused = (_focused + 1) % count;
        break;
      case NSCarriageReturnCharacter:
      case NSEnterCharacter:
      case NSNewlineCharacter:
      case ' ':
        _result = 1;
        break;
      case 0x1b:
        _result = -1;
        break;
      default:
        break;
    }
}

@end

/* Opens the flyout for `list` over `field` (in `picker`'s coordinates)
   and runs it until a button, Enter, Escape or a click elsewhere closes
   it. Returns the parts picked, or nil when dismissed. */
static NSDateComponents *
WinUIThemeRunPickerFlyout(WinUITheme *theme, NSDatePicker *picker, NSRect field,
                          WinUIThemeDatePartList list, NSDateComponents *components,
                          NSCalendar *calendar)
{
  NSDatePickerCell *cell = [picker cell];
  NSFont *font = WinUIThemePreferredControlFont(theme, [cell font], NO);
  BOOL date = (list.parts[0] == WinUIThemeDatePartMonth || list.parts[1] == WinUIThemeDatePartMonth
               || list.parts[list.count - 1] == WinUIThemeDatePartMonth);
  CGFloat width = MAX(NSWidth(field), date ? WinUIThemeDatePickerWidth : WinUIThemeTimePickerWidth);
  CGFloat widths[3];
  NSInteger year = [components year];
  NSInteger firstYear = year - 100, lastYear = year + 100;
  WinUIThemeDatePickerFlyoutView *view = nil;
  NSPanel *panel = nil;
  NSRect screenField, frame, visible;
  NSDateComponents *picked = nil;
  BOOL wasActive = [NSApp isActive];

  if ([cell minDate] != nil)
    {
      firstYear = MAX(firstYear, [[calendar components: NSYearCalendarUnit
                                              fromDate: WinUIThemeWallClockDate(cell, [cell minDate])] year]);
    }
  if ([cell maxDate] != nil)
    {
      lastYear = MIN(lastYear, [[calendar components: NSYearCalendarUnit
                                             fromDate: WinUIThemeWallClockDate(cell, [cell maxDate])] year]);
    }
  if (lastYear < firstYear)
    {
      firstYear = lastYear = year;
    }
  WinUIThemeDatePartWidths(list, width, widths);
  view = AUTORELEASE([[WinUIThemeDatePickerFlyoutView alloc]
    initWithTheme: theme
            parts: list
           widths: widths
       components: components
         calendar: calendar
             font: font
        yearRange: NSMakeRange(firstYear, lastYear - firstYear + 1)]);

  /* Over the field, its value level with the band. */
  screenField = [picker convertRect: field toView: nil];
  screenField.origin = [[picker window] convertBaseToScreen: screenField.origin];
  frame.size = [view frame].size;
  frame.origin.x = NSMinX(screenField);
  frame.origin.y = NSMidY(screenField) + [WinUIThemeDatePickerFlyoutView bandCentre] - NSHeight(frame);
  visible = [[[picker window] screen] visibleFrame];
  if (NSIsEmptyRect(visible) == NO)
    {
      frame.origin.x = MAX(NSMinX(visible), MIN(NSMinX(frame), NSMaxX(visible) - NSWidth(frame)));
      frame.origin.y = MAX(NSMinY(visible), MIN(NSMinY(frame), NSMaxY(visible) - NSHeight(frame)));
    }

  panel = [[NSPanel alloc] initWithContentRect: frame
                                     styleMask: NSBorderlessWindowMask
                                       backing: NSBackingStoreBuffered
                                         defer: NO];
  [panel setReleasedWhenClosed: NO];
  [panel setLevel: NSPopUpMenuWindowLevel];
  [panel setHasShadow: YES];
  [panel setContentView: view];
  [panel setAcceptsMouseMovedEvents: YES];
  [panel orderFront: nil];
  WinUIThemeWindowIntegrationRoundPopupWindow(panel, NO,
    WinUIThemeColorFromTheme(theme, @"menuBorderColor", [NSColor gridColor]));
  [panel display];

  while ([view result] == 0)
    {
      NSAutoreleasePool *pool = [NSAutoreleasePool new];
      NSEvent *event = [NSApp nextEventMatchingMask: NSAnyEventMask
                                          untilDate: [NSDate distantFuture]
                                             inMode: NSEventTrackingRunLoopMode
                                            dequeue: YES];

      switch ([event type])
        {
          case NSLeftMouseDown:
          case NSRightMouseDown:
          case NSOtherMouseDown:
            if ([event window] == panel)
              {
                [view mouseDown: event];
              }
            else
              {
                /* A click elsewhere dismisses the flyout, and goes no
                   further, as WinUI's light dismiss. */
                [view setResult: -1];
              }
            break;
          case NSScrollWheel:
            if ([event window] == panel)
              {
                [view scrollWheel: event];
              }
            break;
          case NSMouseMoved:
          case NSLeftMouseDragged:
            if ([event window] == panel)
              {
                [view mouseMoved: event];
              }
            break;
          case NSKeyDown:
            [view keyDown: event];
            break;
          case NSLeftMouseUp:
          case NSRightMouseUp:
          case NSOtherMouseUp:
          case NSKeyUp:
          case NSFlagsChanged:
          case NSMouseEntered:
          case NSMouseExited:
            break;
          default:
            [NSApp sendEvent: event];
            break;
        }
      /* Switching to another app dismisses it too. */
      if ((wasActive && [NSApp isActive] == NO) || [[picker window] isVisible] == NO)
        {
          [view setResult: -1];
        }
      [panel displayIfNeeded];
      [pool release];
    }

  if ([view result] > 0)
    {
      picked = RETAIN([view components]);
    }
  [panel orderOut: nil];
  [panel close];
  RELEASE(panel);
  return AUTORELEASE(picked);
}

/* Sets the picker to `date`, through its delegate's validation and the
   minimum and maximum, and sends its action. */
static void
WinUIThemeDatePickerCommit(NSDatePicker *picker, NSDate *date)
{
  NSDatePickerCell *cell = [picker cell];
  id delegate = [cell delegate];
  NSTimeInterval interval = 0.0;

  if (date == nil)
    {
      return;
    }
  if (delegate != nil
      && [delegate respondsToSelector: @selector(datePickerCell:validateProposedDateValue:timeInterval:)])
    {
      [delegate datePickerCell: cell validateProposedDateValue: &date timeInterval: &interval];
    }
  if ([cell minDate] != nil && [date compare: [cell minDate]] == NSOrderedAscending)
    {
      date = [cell minDate];
    }
  if ([cell maxDate] != nil && [date compare: [cell maxDate]] == NSOrderedDescending)
    {
      date = [cell maxDate];
    }
  if (date == nil || [date isEqual: [cell objectValue]])
    {
      return;
    }
  [cell setDateValue: date];
  [picker setNeedsDisplay: YES];
  if ([picker action] != NULL)
    {
      [picker sendAction: [picker action] to: [picker target]];
    }
}

static void
WinUIThemeDatePickerOpenField(WinUITheme *theme, NSDatePicker *picker, BOOL wantsTime)
{
  NSDatePickerCell *cell = [picker cell];
  NSCalendar *calendar = WinUIThemeDatePickerCalendar(cell);
  NSDateComponents *components = [calendar components: WinUIThemeDateUnits
                                             fromDate: WinUIThemeDatePickerDate(cell)];
  NSRect dateField, timeField;
  NSDateComponents *picked = nil;

  WinUIThemeDatePickerFields(cell, [picker bounds], &dateField, &timeField);
  picked = WinUIThemeRunPickerFlyout(theme, picker, wantsTime ? timeField : dateField,
                                     wantsTime ? WinUIThemeTimeParts() : WinUIThemeDateParts(cell),
                                     components, calendar);
  if (picked != nil)
    {
      /* A day past the end of the picked month becomes its last day. */
      [picked setDay: MIN([picked day], WinUIThemeDaysInMonth(calendar, [picked year], [picked month]))];
      WinUIThemeDatePickerCommit(picker, WinUIThemeRealDate(cell, [calendar dateFromComponents: picked]));
    }
}

/* A click in the calendar: the previous and next buttons change the month
   shown, a day picks it, keeping the time of day. */
static void
WinUIThemeCalendarClick(NSDatePicker *picker, NSPoint point)
{
  NSDatePickerCell *cell = [picker cell];
  BOOL flipped = [picker isFlipped];
  NSCalendar *calendar = WinUIThemeDatePickerCalendar(cell);
  NSDateComponents *month = WinUIThemeCalendarShownMonth(cell, calendar);
  WinUIThemeCalendarLayout layout = WinUIThemeCalendarLayoutForFrame([picker bounds], flipped);
  NSDate *firstCell = WinUIThemeCalendarFirstCellDate(calendar, month);
  NSInteger index;

  if (NSPointInRect(point, layout.previous) || NSPointInRect(point, layout.next))
    {
      WinUIThemeCalendarShowMonth(cell, [month year],
                                  [month month] + (NSPointInRect(point, layout.next) ? 1 : -1));
      [picker setNeedsDisplay: YES];
      return;
    }
  for (index = 0; index < 42; index++)
    {
      if (NSPointInRect(point, WinUIThemeCalendarCellRect(layout, index, flipped)))
        {
          NSDate *day = WinUIThemeCalendarCellDate(calendar, firstCell, index);
          NSDateComponents *date = [calendar components: NSYearCalendarUnit | NSMonthCalendarUnit
                                                         | NSDayCalendarUnit fromDate: day];
          NSDateComponents *time = [calendar components: NSHourCalendarUnit | NSMinuteCalendarUnit
                                                         | NSSecondCalendarUnit
                                               fromDate: WinUIThemeDatePickerDate(cell)];

          [date setHour: [time hour]];
          [date setMinute: [time minute]];
          [date setSecond: [time second]];
          WinUIThemeCalendarShowMonth(cell, [date year], [date month]);
          WinUIThemeDatePickerCommit(picker, WinUIThemeRealDate(cell, [calendar dateFromComponents: date]));
          [picker setNeedsDisplay: YES];
          return;
        }
    }
}

#pragma mark Overrides

@implementation WinUITheme (DatePicker)

- (void) _overrideNSDatePickerCellMethod_drawWithFrame: (NSRect)cellFrame
                                                inView: (NSView *)controlView
{
  typedef void (*DrawIMP)(id, SEL, NSRect, NSView *);
  DrawIMP originalIMP = (DrawIMP)WinUIThemeOriginalMethod(_cmd, self, [NSDatePickerCell class]);
  WinUITheme *theme = WinUIThemeDatePickerTheme();
  NSDatePickerCell *cell = (NSDatePickerCell *)self;
  NSCalendar *calendar = nil;
  NSDateComponents *components = nil;
  NSRect dateField, timeField;
  NSFont *font = nil;
  BOOL enabled, hover = NO;

  if (theme == nil)
    {
      if (originalIMP != NULL)
        {
          originalIMP(self, _cmd, cellFrame, controlView);
        }
      return;
    }
  if (WinUIThemeDatePickerShowsCalendar(cell))
    {
      WinUIThemeDrawCalendar(theme, cell, cellFrame, controlView);
      return;
    }

  enabled = [cell isEnabled];
  if (enabled && controlView != nil)
    {
      WinUIThemeTrackHover(controlView);
      hover = WinUIThemeViewIsHovered(controlView);
    }
  calendar = WinUIThemeDatePickerCalendar(cell);
  components = [calendar components: WinUIThemeDateUnits fromDate: WinUIThemeDatePickerDate(cell)];
  font = WinUIThemePreferredControlFont(theme, [cell font], NO);
  WinUIThemeDatePickerFields(cell, cellFrame, &dateField, &timeField);
  WinUIThemeDrawPickerField(theme, controlView, dateField, WinUIThemeDateParts(cell), components, font,
                            enabled, [cell isHighlighted], hover);
  WinUIThemeDrawPickerField(theme, controlView, timeField, WinUIThemeTimeParts(), components, font,
                            enabled, [cell isHighlighted], hover);
}

- (NSSize) _overrideNSDatePickerCellMethod_cellSize
{
  typedef NSSize (*SizeIMP)(id, SEL);
  SizeIMP originalIMP = (SizeIMP)WinUIThemeOriginalMethod(_cmd, self, [NSDatePickerCell class]);
  NSDatePickerCell *cell = (NSDatePickerCell *)self;
  CGFloat width = 0.0;

  if (WinUIThemeDatePickerTheme() == nil)
    {
      return (originalIMP != NULL) ? originalIMP(self, _cmd) : NSZeroSize;
    }
  if (WinUIThemeDatePickerShowsCalendar(cell))
    {
      return NSMakeSize(WinUIThemeCalendarWidth, WinUIThemeCalendarHeight);
    }
  if (WinUIThemeDatePickerShowsDate(cell))
    {
      width += WinUIThemeDatePickerWidth;
    }
  if (WinUIThemeDatePickerShowsTime(cell))
    {
      width += ((width > 0.0) ? WinUIThemeDatePickerGap : 0.0) + WinUIThemeTimePickerWidth;
    }
  return NSMakeSize(width, WinUIThemeDatePickerHeight);
}

- (void) _overrideNSDatePickerMethod_mouseDown: (NSEvent *)event
{
  typedef void (*MouseIMP)(id, SEL, NSEvent *);
  MouseIMP originalIMP = (MouseIMP)WinUIThemeOriginalMethod(_cmd, self, [NSDatePicker class]);
  WinUITheme *theme = WinUIThemeDatePickerTheme();
  NSDatePicker *picker = (NSDatePicker *)self;
  NSDatePickerCell *cell = [picker cell];
  NSPoint point = [picker convertPoint: [event locationInWindow] fromView: nil];
  NSRect dateField, timeField;

  if (theme == nil || [cell isKindOfClass: [NSDatePickerCell class]] == NO)
    {
      if (originalIMP != NULL)
        {
          originalIMP(self, _cmd, event);
        }
      return;
    }
  if ([picker isEnabled] == NO)
    {
      return;
    }
  if ([picker acceptsFirstResponder])
    {
      [[picker window] makeFirstResponder: picker];
    }
  if (WinUIThemeDatePickerShowsCalendar(cell))
    {
      WinUIThemeCalendarClick(picker, point);
      return;
    }

  WinUIThemeDatePickerFields(cell, [picker bounds], &dateField, &timeField);
  if (NSPointInRect(point, dateField) == NO && NSPointInRect(point, timeField) == NO)
    {
      return;
    }
  /* Pressed until the flyout opens. */
  [cell setHighlighted: YES];
  [picker display];
  [cell setHighlighted: NO];
  [picker setNeedsDisplay: YES];
  WinUIThemeDatePickerOpenField(theme, picker, NSPointInRect(point, timeField));
  [picker setNeedsDisplay: YES];
}

/* Space and Enter open the flyout, as on a WinUI DatePicker with focus. */
- (void) _overrideNSDatePickerMethod_keyDown: (NSEvent *)event
{
  typedef void (*KeyIMP)(id, SEL, NSEvent *);
  KeyIMP originalIMP = (KeyIMP)WinUIThemeOriginalMethod(_cmd, self, [NSDatePicker class]);
  WinUITheme *theme = WinUIThemeDatePickerTheme();
  NSDatePicker *picker = (NSDatePicker *)self;
  NSString *characters = [event charactersIgnoringModifiers];
  unichar key = ([characters length] > 0) ? [characters characterAtIndex: 0] : 0;

  if (theme != nil && [picker isEnabled] && [[picker cell] isKindOfClass: [NSDatePickerCell class]]
      && WinUIThemeDatePickerShowsCalendar([picker cell]) == NO
      && (key == ' ' || key == NSCarriageReturnCharacter || key == NSEnterCharacter))
    {
      WinUIThemeDatePickerOpenField(theme, picker,
                                    WinUIThemeDatePickerShowsDate([picker cell]) == NO);
      return;
    }
  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, event);
    }
}

@end
