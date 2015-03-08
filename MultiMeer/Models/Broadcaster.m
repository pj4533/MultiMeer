//
//  Broadcaster.m
//  MultiMeer
//
//  Created by PJ Gray on 3/8/15.
//  Copyright (c) 2015 Say Goodnight Software. All rights reserved.
//

#import "Broadcaster.h"

@implementation Broadcaster

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{
             @"broadcasterId": @"id",
             @"profileURL": @"profile",
             @"imageURL": @"image"
             };
}

+ (NSValueTransformer *)profileURLJSONTransformer {
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

+ (NSValueTransformer *)imageURLJSONTransformer {
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

@end
