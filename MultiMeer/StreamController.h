//
//  StreamController.h
//  MultiMeer
//
//  Created by PJ Gray on 3/7/15.
//  Copyright (c) 2015 Say Goodnight Software. All rights reserved.
//

#import <UIKit/UIKit.h>

@class StreamController;
@class StreamSummary;
@class StreamCell;
@protocol StreamControllerDelegate <NSObject>
- (void)didBecomeReadyToPlayWithStream:(StreamController*)stream;
- (void)didFinishPlayingWithStream:(StreamController*)stream;
@end

@interface StreamController : NSObject

- (instancetype)initWithSummary:(StreamSummary*)summary;
- (void)playStreamOnLayer:(CALayer*)layer;

- (BOOL)isMuted;
- (void)muteVolume;
- (void)unmuteVolume;

@property (nonatomic, weak) id delegate;
@property (nonatomic, strong) StreamSummary* summary;

// Storing the cell in here like this is suspect, but I can't figure a way to update the data inside the cell without messing with the video layer.  If I reload the cell, i might get a different dequed cell, which will cause a blip as the layer is removed/readded.  this way I can just update the data in the cell, but it makes it so i can NEVER reload the cells.  Weird.
@property (nonatomic, weak) StreamCell* cell;

@end
