#import "TDContractLoader.h"

static NSError *
TDValidationError(NSInteger code, NSString *description)
{
  return [NSError errorWithDomain: @"ThemeDemoErrorDomain"
                             code: code
                         userInfo: [NSDictionary dictionaryWithObject: description
                                                              forKey: NSLocalizedDescriptionKey]];
}

static BOOL
TDIsNonEmptyString(id value)
{
  return ([value isKindOfClass: [NSString class]] && [(NSString *)value length] > 0);
}

static BOOL
TDValidateFixture(NSDictionary *fixture,
                  NSString *pageID,
                  NSString *sectionID,
                  NSMutableSet *fixtureIDs,
                  NSError **error)
{
  NSString *fixtureID = [fixture objectForKey: @"id"];
  NSString *kind = [fixture objectForKey: @"kind"];

  if (TDIsNonEmptyString(fixtureID) == NO)
    {
      if (error != NULL)
        {
          *error = TDValidationError(1,
                                     [NSString stringWithFormat: @"Section '%@' on page '%@' contains a fixture without a stable id.",
                                                                sectionID,
                                                                pageID]);
        }
      return NO;
    }
  if (TDIsNonEmptyString(kind) == NO)
    {
      if (error != NULL)
        {
          *error = TDValidationError(2,
                                     [NSString stringWithFormat: @"Fixture '%@' on page '%@' section '%@' is missing a kind.",
                                                                fixtureID,
                                                                pageID,
                                                                sectionID]);
        }
      return NO;
    }
  if ([fixtureIDs containsObject: fixtureID])
    {
      if (error != NULL)
        {
          *error = TDValidationError(3,
                                     [NSString stringWithFormat: @"Fixture id '%@' is duplicated inside page '%@' section '%@'.",
                                                                fixtureID,
                                                                pageID,
                                                                sectionID]);
        }
      return NO;
    }

  [fixtureIDs addObject: fixtureID];
  return YES;
}

static BOOL
TDValidateSection(NSDictionary *section,
                  NSString *pageID,
                  NSMutableSet *sectionIDs,
                  NSError **error)
{
  NSString *sectionID = [section objectForKey: @"id"];
  NSArray *fixtures = [section objectForKey: @"fixtures"];
  NSMutableSet *fixtureIDs = nil;
  NSUInteger i = 0;

  if (TDIsNonEmptyString(sectionID) == NO)
    {
      if (error != NULL)
        {
          *error = TDValidationError(4,
                                     [NSString stringWithFormat: @"Page '%@' contains a section without a stable id.",
                                                                pageID]);
        }
      return NO;
    }
  if ([sectionIDs containsObject: sectionID])
    {
      if (error != NULL)
        {
          *error = TDValidationError(5,
                                     [NSString stringWithFormat: @"Section id '%@' is duplicated inside page '%@'.",
                                                                sectionID,
                                                                pageID]);
        }
      return NO;
    }
  if ([fixtures isKindOfClass: [NSArray class]] == NO)
    {
      if (error != NULL)
        {
          *error = TDValidationError(6,
                                     [NSString stringWithFormat: @"Section '%@' on page '%@' is missing its fixtures array.",
                                                                sectionID,
                                                                pageID]);
        }
      return NO;
    }

  [sectionIDs addObject: sectionID];
  fixtureIDs = [NSMutableSet set];
  for (i = 0; i < [fixtures count]; i++)
    {
      id fixture = [fixtures objectAtIndex: i];

      if ([fixture isKindOfClass: [NSDictionary class]] == NO)
        {
          if (error != NULL)
            {
              *error = TDValidationError(7,
                                         [NSString stringWithFormat: @"Section '%@' on page '%@' contains a non-dictionary fixture.",
                                                                    sectionID,
                                                                    pageID]);
            }
          return NO;
        }

      if (TDValidateFixture(fixture, pageID, sectionID, fixtureIDs, error) == NO)
        {
          return NO;
        }
    }

  return YES;
}

static BOOL
TDValidateContract(NSDictionary *contract, NSError **error)
{
  id versionValue = [contract objectForKey: @"contractVersion"];
  NSArray *pages = [contract objectForKey: @"pages"];
  NSMutableSet *pageIDs = [NSMutableSet set];
  NSUInteger i = 0;

  if ([versionValue respondsToSelector: @selector(integerValue)] == NO ||
      [versionValue integerValue] < 1)
    {
      if (error != NULL)
        {
          *error = TDValidationError(8, @"The shared page contract must be version 1 or later.");
        }
      return NO;
    }
  if ([pages isKindOfClass: [NSArray class]] == NO)
    {
      if (error != NULL)
        {
          *error = TDValidationError(9, @"The shared page contract is missing its pages array.");
        }
      return NO;
    }

  for (i = 0; i < [pages count]; i++)
    {
      NSDictionary *page = [pages objectAtIndex: i];
      NSString *pageID = nil;
      NSArray *sections = nil;
      NSMutableSet *sectionIDs = nil;
      NSUInteger j = 0;

      if ([page isKindOfClass: [NSDictionary class]] == NO)
        {
          if (error != NULL)
            {
              *error = TDValidationError(10, @"The shared page contract contains a non-dictionary page.");
            }
          return NO;
        }

      pageID = [page objectForKey: @"id"];
      sections = [page objectForKey: @"sections"];
      if (TDIsNonEmptyString(pageID) == NO)
        {
          if (error != NULL)
            {
              *error = TDValidationError(11, @"The shared page contract contains a page without a stable id.");
            }
          return NO;
        }
      if ([pageIDs containsObject: pageID])
        {
          if (error != NULL)
            {
              *error = TDValidationError(12,
                                         [NSString stringWithFormat: @"Page id '%@' is duplicated in the shared contract.",
                                                                    pageID]);
            }
          return NO;
        }
      if ([sections isKindOfClass: [NSArray class]] == NO)
        {
          if (error != NULL)
            {
              *error = TDValidationError(13,
                                         [NSString stringWithFormat: @"Page '%@' is missing its sections array.",
                                                                    pageID]);
            }
          return NO;
        }

      [pageIDs addObject: pageID];
      sectionIDs = [NSMutableSet set];
      for (j = 0; j < [sections count]; j++)
        {
          id section = [sections objectAtIndex: j];

          if ([section isKindOfClass: [NSDictionary class]] == NO)
            {
              if (error != NULL)
                {
                  *error = TDValidationError(14,
                                             [NSString stringWithFormat: @"Page '%@' contains a non-dictionary section.",
                                                                        pageID]);
                }
              return NO;
            }
          if (TDValidateSection(section, pageID, sectionIDs, error) == NO)
            {
              return NO;
            }
        }
    }

  return YES;
}

@implementation TDContractLoader

+ (NSDictionary *) contractFromMainBundle: (NSError **)error
{
  NSString *path = [[NSBundle mainBundle] pathForResource: @"theme-demo-pages"
                                                   ofType: @"json"];
  NSData *data = nil;
  id object = nil;

  if (path == nil)
    {
      if (error != NULL)
        {
          *error = TDValidationError(15, @"Unable to find theme-demo-pages.json in the main bundle.");
        }
      return nil;
    }

  data = [NSData dataWithContentsOfFile: path];
  if (data == nil)
    {
      if (error != NULL)
        {
          *error = TDValidationError(16, @"Unable to read the shared page contract file.");
        }
      return nil;
    }

  object = [NSJSONSerialization JSONObjectWithData: data
                                           options: 0
                                             error: error];
  if ([object isKindOfClass: [NSDictionary class]] == NO)
    {
      if (error != NULL && *error == nil)
        {
          *error = TDValidationError(17, @"The shared page contract root must be a dictionary.");
        }
      return nil;
    }

  if (TDValidateContract((NSDictionary *)object, error) == NO)
    {
      return nil;
    }

  return (NSDictionary *)object;
}

@end

