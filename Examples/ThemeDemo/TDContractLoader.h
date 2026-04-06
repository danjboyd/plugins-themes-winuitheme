#ifndef THEMEDEMO_CONTRACTLOADER_H
#define THEMEDEMO_CONTRACTLOADER_H

#import <Foundation/Foundation.h>

@interface TDContractLoader : NSObject

+ (NSDictionary *) contractFromMainBundle: (NSError **)error;

@end

#endif

