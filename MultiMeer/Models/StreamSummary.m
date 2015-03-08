//
//  Stream.m
//  MultiMeer
//
//  Created by PJ Gray on 3/8/15.
//  Copyright (c) 2015 Say Goodnight Software. All rights reserved.
//

#import "StreamSummary.h"
#import "Broadcaster.h"

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
             @"broadcaster": @"result.broadcaster",
             @"playlistURL": @"followupActions.playlist"
             };
}

+ (NSValueTransformer *)coverURLJSONTransformer {
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

+ (NSValueTransformer *)playlistURLJSONTransformer {
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

+ (NSValueTransformer *)broadcasterJSONTransformer {
    return [MTLValueTransformer
            reversibleTransformerWithForwardBlock:^ id (id JSONDictionary) {
                if ((JSONDictionary == nil) || ![JSONDictionary isKindOfClass:NSDictionary.class]) return nil;
                return [MTLJSONAdapter modelOfClass:Broadcaster.class fromJSONDictionary:JSONDictionary error:NULL];
            }
            reverseBlock:^ id (id model) {
                if (model == nil) return nil;
                return [MTLJSONAdapter JSONDictionaryFromModel:model];
            }];
}

@end
