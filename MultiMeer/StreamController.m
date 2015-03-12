//
//  StreamController.m
//  MultiMeer
//
//  Created by PJ Gray on 3/7/15.
//  Copyright (c) 2015 Say Goodnight Software. All rights reserved.
//

#import "StreamController.h"
#import "StreamSummary.h"

// Dont like the dependency here...
#import "StreamCell.h"

#import <AVFoundation/AVFoundation.h>

static void *PlayerStatusObservationContext = &PlayerStatusObservationContext;

@interface StreamController () {
    AVPlayer* _player;
    AVPlayerItem* _playerItem;
    AVPlayerLayer* _playerLayer;
    BOOL _didFail;
}

@end

@implementation StreamController

- (instancetype)initWithSummary:(StreamSummary*)summary {
    self = [super init];
    if (self) {
        _summary = summary;
    }
    return self;
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
                NSLog(@"READY BECOME READY: %@", self.summary.playlistURL);
            }
                break;
                
            case AVPlayerItemStatusFailed:
            {
                NSLog(@"AVPlayerItemStatusFailed");
                _didFail = YES;
            }
                break;
        }
    }
    else {
        if (_playerItem.playbackLikelyToKeepUp ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate didBecomeLikelyToKeepUp:self];
            });
            [self.cell.streamPlaybackView.layer addSublayer:_playerLayer];
            [_player play];
        } else {
            [_playerLayer removeFromSuperlayer];
            [_player pause];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate didBecomeUnlikelyToKeepUp:self];
            });
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

- (void)uninitializePlayerWithCompletion:(void (^)(BOOL completed))completion {
    if (!_player) {
        if (completion) {
            completion(NO);
        }
    } else {
        [_player pause];
        [self uninitializePlayerItem];
        [_playerLayer removeFromSuperlayer];
        _player = nil;
        if (completion) {
            completion(YES);
        }
    }
}

- (void)initializePlayer {
    if (_player) {
        return;
    }
    
    [self initializePlayerItem];
    _player = [[AVPlayer alloc] initWithPlayerItem:_playerItem];
    
    if (_playerLayer) {
        _playerLayer = nil;
    }
    
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        _playerLayer.frame = CGRectMake(0, 0, 75, 75);
    } else {
        _playerLayer.frame = CGRectMake(0, 0, 150, 150);
    }

}

- (BOOL)playing {
    if (_player) {
        return YES;
    }
    
    return NO;
}

- (BOOL)isMuted {
    if (!_player) {
        return YES;
    }
    
    if (_player.volume == 0.0) {
        return YES;
    }
    return NO;
}

- (void)muteVolume {
    if (!_player) {
        return;
    }
    
    [_player setVolume:0.0];
}

- (void)unmuteVolume {
    if (!_player) {
        return;
    }

    [_player setVolume:1.0];
}

@end
