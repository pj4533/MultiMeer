//
//  Broadcaster.h
//  MultiMeer
//
//  Created by PJ Gray on 3/8/15.
//  Copyright (c) 2015 Say Goodnight Software. All rights reserved.
//

#import <Mantle/Mantle.h>

@interface Broadcaster : MTLModel <MTLJSONSerializing>

@property (nonatomic, copy, readonly) NSString* broadcasterId;
@property (nonatomic, copy, readonly) NSString* name;
@property (nonatomic, copy, readonly) NSString* displayName;

@property (nonatomic, copy, readonly) NSURL *profileURL;
@property (nonatomic, copy, readonly) NSURL *imageURL;

@end
