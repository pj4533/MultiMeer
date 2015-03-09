//
//  StreamController.m
//  MultiMeer
//
//  Created by PJ Gray on 3/7/15.
//  Copyright (c) 2015 Say Goodnight Software. All rights reserved.
//

#import "StreamController.h"
#import "StreamSummary.h"
#import <AVFoundation/AVFoundation.h>

static void *PlayerStatusObservationContext = &PlayerStatusObservationContext;

@interface StreamController () {
    AVPlayer* _player;
    AVPlayerItem* _playerItem;
    AVPlayerLayer* _playerLayer;
    BOOL _didRetry;
}

@end

@implementation StreamController

- (instancetype)initWithSummary:(StreamSummary*)summary {
    self = [super init];
    if (self) {
        _summary = summary;
        [self initializePlayer];
    }
    return self;
}

- (void)playStreamOnLayer:(CALayer*)layer {

    if (_playerLayer) {
        _playerLayer = nil;
    }
    
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        _playerLayer.frame = CGRectMake(0, 0, 75, 75);
    } else {
        _playerLayer.frame = CGRectMake(0, 0, 150, 150);
    }

    
    [layer addSublayer:_playerLayer];
}

#pragma mark - NOtification

- (void)observeValueForKeyPath:(NSString*) path
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context
{
    /* AVPlayerItem "status" property value observer. */
    if (context == PlayerStatusObservationContext)
    {
        AVPlayerItemStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        switch (status)
        {
                /* Indicates that the status of the player is not yet known because
                 it has not tried to load new media resources for playback */
            case AVPlayerItemStatusUnknown:
            {
                NSLog(@"UNKNOWN: %@", self.summary.playlistURL);
            }
                break;
                
            case AVPlayerItemStatusReadyToPlay:
            {
                /* Once the AVPlayerItem becomes ready to play, i.e.
                 [playerItem status] == AVPlayerItemStatusReadyToPlay,
                 its duration can be fetched from the item. */
                
                if (self.delegate && !_playerLayer) {
                    NSLog(@"READY BECOME READY: %@", self.summary.playlistURL);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate didBecomeReadyToPlayWithStream:self];
                    });
                }
            }
                break;
                
            case AVPlayerItemStatusFailed:
            {
                NSLog(@"AVPlayerItemStatusFailed");
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                    sleep(5);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (!_didRetry) {
                            [self uninitializePlayerItem];
                            [self initializePlayerItem];
                            [_player replaceCurrentItemWithPlayerItem:_playerItem];
                            _didRetry = YES;
                        }
                    });
                });
            }
                break;
        }
    }
    else {
        if (_playerItem.playbackLikelyToKeepUp ) {
            [self prerollAndPlay];
        }
    }
}

- (void)initializePlayerItem {
    _playerItem = [AVPlayerItem playerItemWithURL:self.summary.playlistURL];
    _playerItem.preferredPeakBitRate = 10;
    
    [_playerItem addObserver:self
                  forKeyPath:@"status"
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:PlayerStatusObservationContext];
    [_playerItem addObserver:self
                  forKeyPath:@"playbackLikelyToKeepUp"
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:nil];
}

- (void)uninitializePlayerItem {
    [_playerItem removeObserver:self forKeyPath:@"status" context:PlayerStatusObservationContext];
    [_playerItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp" context:nil];
    
}

- (void)uninitializePlayer {
    [self uninitializePlayerItem];
    [_playerLayer removeFromSuperlayer];
}

- (void)initializePlayer {
    [self initializePlayerItem];
    _player = [[AVPlayer alloc] initWithPlayerItem:_playerItem];
}

- (void)prerollAndPlay {
    [_player prerollAtRate:1 completionHandler:^(BOOL finished){
        if (finished) {
            [_player play];
        }
    }];
}

- (BOOL)isMuted {
    if (_player.volume == 0.0) {
        return YES;
    }
    return NO;
}

- (void)muteVolume {
    [_player setVolume:0.0];
}

- (void)unmuteVolume {
    [_player setVolume:1.0];
}

@end
