//
//  Stream.h
//  MultiMeer
//
//  Created by PJ Gray on 3/8/15.
//  Copyright (c) 2015 Say Goodnight Software. All rights reserved.
//

#import <Mantle/Mantle.h>

@interface StreamSummary : MTLModel <MTLJSONSerializing>

@property (nonatomic, copy, readonly) NSString* streamId;
@property (nonatomic, copy, readonly) NSString* status;
@property (nonatomic, copy, readonly) NSString* caption;
@property (nonatomic, copy, readonly) NSString* location;

@property (nonatomic, copy, readonly) NSNumber* watchersCount;
@property (nonatomic, copy, readonly) NSNumber* commentsCount;
@property (nonatomic, copy, readonly) NSNumber* restreamsCount;
@property (nonatomic, copy, readonly) NSNumber* likesCount;

@property (nonatomic, copy, readonly) NSURL *coverURL;
@property (nonatomic, copy, readonly) NSURL *playlistURL;

@end
