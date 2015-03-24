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
#import <AssetsLibrary/AssetsLibrary.h>
#import "MovieRecorder.h"

static void *PlayerStatusObservationContext = &PlayerStatusObservationContext;

@interface StreamController () <AVPlayerItemOutputPullDelegate, MovieRecorderDelegate> {
    AVPlayer* _player;
    AVPlayerItem* _playerItem;
    AVPlayerLayer* _playerLayer;
    BOOL _didFail;
    dispatch_queue_t _myVideoOutputQueue;
    NSURL* _recordingURL;
    CMFormatDescriptionRef _outputVideoFormatDescription;
}

@property AVPlayerItemVideoOutput *videoOutput;
@property CADisplayLink *displayLink;
@property MovieRecorder *recorder;

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

// step in getting rid of cacheing the cell?
- (void)addToLayer:(CALayer*)layer {
    [_playerLayer removeFromSuperlayer];
    [layer addSublayer:_playerLayer];
}

- (void)initializePlayerItem {
    
    _recordingURL = [[NSURL alloc] initFileURLWithPath:[NSString pathWithComponents:@[NSTemporaryDirectory(), @"Movie.MOV"]]];

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
    
    // Setup CADisplayLink which will callback displayPixelBuffer: at every vsync.
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
    [[self displayLink] addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [[self displayLink] setPaused:YES];
    
    // Setup AVPlayerItemVideoOutput with the required pixelbuffer attributes.
    NSDictionary *pixBuffAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};//@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
    self.videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];
    
    
    _myVideoOutputQueue = dispatch_queue_create("myVideoOutputQueue", DISPATCH_QUEUE_SERIAL);
    [[self videoOutput] setDelegate:self queue:_myVideoOutputQueue];
    
    [_playerItem addOutput:self.videoOutput];
    [self.videoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:0.03];
    
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
        _playerLayer.frame = CGRectMake(0, 0, 100, 100);
    } else {
        _playerLayer.frame = CGRectMake(0, 0, 200, 200);
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

- (void)startRecording {
    self.recording = YES;
}

- (void)stopRecording {
    [self.recorder finishRecording];
}

#pragma mark - CADisplayLink Callback

- (void)displayLinkCallback:(CADisplayLink *)sender
{
    
    if (self.recording) {
        if (!self.recorder) {
            MovieRecorder *recorder = [[MovieRecorder alloc] initWithURL:_recordingURL];
            
#if RECORD_AUDIO
            [recorder addAudioTrackWithSourceFormatDescription:self.outputAudioFormatDescription settings:_audioCompressionSettings];
#endif // RECORD_AUDIO
            
            
            //        AVAsset					*itemAsset = _playerItem.asset;
            //        NSArray					*vidTracks = [itemAsset tracksWithMediaType:AVMediaTypeVideo];
            
            NSArray* tracks = _playerItem.tracks;
            for (AVPlayerItemTrack *playerItemTrack in tracks)	{
                AVAssetTrack* trackPtr = playerItemTrack.assetTrack;
                if ([trackPtr.mediaType isEqualToString:AVMediaTypeVideo]) {
                    NSArray					*trackFormatDescs = [trackPtr formatDescriptions];
                    CMFormatDescriptionRef	desc = (trackFormatDescs==nil || [trackFormatDescs count]<1) ? nil : (__bridge CMFormatDescriptionRef)[trackFormatDescs objectAtIndex:0];
                    if (desc != nil)	{
                        
                        [recorder addVideoTrackWithSourceFormatDescription:desc transform:CGAffineTransformIdentity settings:nil];
                    }
                }
            }
            
            dispatch_queue_t callbackQueue = dispatch_queue_create( "com.apple.sample.capturepipeline.recordercallback", DISPATCH_QUEUE_SERIAL ); // guarantee ordering of callbacks with a serial queue
            [recorder setDelegate:self callbackQueue:callbackQueue];
            self.recorder = recorder;
            
            [recorder prepareToRecord]; // asynchronous, will call us back with recorderDidFinishPreparing: or recorder:didFailWithError: when done
        }
        
        
        
        
        /*
         The callback gets called once every Vsync.
         */
        CVPixelBufferRef pixelBuffer = NULL;
        pixelBuffer = [[self videoOutput] copyPixelBufferForItemTime:_playerItem.currentTime itemTimeForDisplay:nil];
        
        if (pixelBuffer) {
            [self.recorder appendVideoPixelBuffer:pixelBuffer withPresentationTime:_playerItem.currentTime];
            CVBufferRelease(pixelBuffer);
        }
    }
}

#pragma mark - AVPlayerItemOutputPullDelegate

- (void)outputMediaDataWillChange:(AVPlayerItemOutput *)sender
{
    // Restart display link.
    [[self displayLink] setPaused:NO];
}

#pragma mark MovieRecorder Delegate

- (void)movieRecorderDidFinishPreparing:(MovieRecorder *)recorder {
}

- (void)movieRecorder:(MovieRecorder *)recorder didFailWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate didGetRecordingError:error];
    });
}

- (void)movieRecorderDidFinishRecording:(MovieRecorder *)recorder {
    
    self.recording = NO;
    
    self.recorder = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate didStartSavingStream:self];
    });
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library writeVideoAtPathToSavedPhotosAlbum:_recordingURL completionBlock:^(NSURL *assetURL, NSError *error) {
        
        [[NSFileManager defaultManager] removeItemAtURL:_recordingURL error:NULL];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate didFinishSavingStream:self];
        });
        
    }];
}


@end
