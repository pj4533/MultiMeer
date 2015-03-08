//
//  Stream.m
//  MultiMeer
//
//  Created by PJ Gray on 3/8/15.
//  Copyright (c) 2015 Say Goodnight Software. All rights reserved.
//

#import "StreamSummary.h"

@implementation StreamSummary

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{
             @"streamId": @"result.id",
             @"status": @"result.status",
             @"caption": @"result.caption",
             @"location": @"result.location",
             @"coverURL": @"result.cover",
             @"watchersCount": @"result.watchersCount",
             @"likesCount": @"result.likesCount",
             @"restreamsCount": @"result.restreamsCount",
             @"commentsCount": @"result.commentsCount",
             @"playlistURL": @"followupActions.playlist"
             };
}

+ (NSValueTransformer *)coverURLJSONTransformer {
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

+ (NSValueTransformer *)playlistURLJSONTransformer {
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

@end
