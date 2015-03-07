//
//  StreamController.h
//  MultiMeer
//
//  Created by PJ Gray on 3/7/15.
//  Copyright (c) 2015 Say Goodnight Software. All rights reserved.
//

#import <UIKit/UIKit.h>

@class StreamController;

@protocol StreamControllerDelegate <NSObject>
- (void)didBecomeReadyToPlayWithStream:(StreamController*)stream;
- (void)didFinishPlayingWithStream:(StreamController*)stream;
@end

@interface StreamController : NSObject

- (instancetype)initWithURL:(NSURL*)url withId:(NSString*)streamId;
- (void)playStreamOnLayer:(CALayer*)layer;

- (BOOL)isMuted;
- (void)muteVolume;
- (void)unmuteVolume;

@property (nonatomic, weak) id delegate;
@property (nonatomic, strong) NSString* streamId;

@end
