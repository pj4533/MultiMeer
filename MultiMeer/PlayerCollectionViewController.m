//
//  PlayerCollectionViewController.m
//  MultiMeer
//
//  Created by PJ Gray on 3/7/15.
//  Copyright (c) 2015 Say Goodnight Software. All rights reserved.
//

#import "PlayerCollectionViewController.h"
#import <AFNetworking/AFNetworking.h>
#import <AFNetworking/UIImageView+AFNetworking.h>

#import "StreamController.h"
#import "StreamSummary.h"
#import "StreamCell.h"
#import "StreamHeader.h"
#import "Broadcaster.h"

@interface PlayerCollectionViewController () <StreamControllerDelegate,StreamCellDelegate> {
    NSMutableArray* _streams;
    StreamHeader* _currentHeader;
}

@end

@implementation PlayerCollectionViewController

static NSString * const reuseIdentifier = @"Cell";

- (void)viewDidLoad {
    [super viewDidLoad];
    _streams = @[].mutableCopy;
    
    // Uncomment the following line to preserve selection between presentations
    // self.clearsSelectionOnViewWillAppear = NO;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        ((UICollectionViewFlowLayout*)self.collectionView.collectionViewLayout).itemSize = CGSizeMake(115.0f, 100.0f);
    }
    
    self.title = @"MultiMeer";
    
    [NSTimer scheduledTimerWithTimeInterval:5.0
                                     target:self
                                   selector:@selector(streamUpdateTick)
                                   userInfo:nil
                                    repeats:YES];
    [self streamUpdateTick];
}

- (void)streamUpdateTick {
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    AFJSONResponseSerializer* responseSerializer = [AFJSONResponseSerializer serializer];
    responseSerializer.acceptableContentTypes = [responseSerializer.acceptableContentTypes setByAddingObject:@"text/html"];
    [manager setResponseSerializer:responseSerializer];
    [manager GET:@"https://resources.meerkatapp.co/broadcasts" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSArray* results = responseObject[@"result"];
        self.title = [NSString stringWithFormat:@"MultiMeer (%@ streams)", @(results.count)];
        dispatch_group_t group = dispatch_group_create();
        for (NSDictionary* stream in results) {
            
            dispatch_group_enter(group);
            [manager GET:stream[@"broadcast"] parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
                StreamSummary* summary = [MTLJSONAdapter modelOfClass:StreamSummary.class fromJSONDictionary:responseObject error:nil];
                
                NSInteger streamIndex = [self indexForStreamId:stream[@"id"]];
                if (streamIndex == -1) {
                    if ([summary.status isEqualToString:@"live"]) {
                        [self.collectionView performBatchUpdates:^{
                            NSInteger itemIndex = _streams.count;
                            StreamController* streamController = [[StreamController alloc] initWithSummary:summary];
                            streamController.delegate = self;
                            if ((_streams.count > 1) && ([self isSingleStreamPlaying])) {
                                [streamController muteVolume];
                            }
                            
                            [_streams addObject:streamController];
                            [self.collectionView insertItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:itemIndex inSection:0]]];
                        } completion:^(BOOL finished) {
                            dispatch_group_leave(group);
                        }];
                    } else {
                        dispatch_group_leave(group);
                    }
                } else {
                    StreamController* stream = _streams[streamIndex];
                    stream.summary = summary;
                    stream.cell.watchersLabel.text = [NSString stringWithFormat:@"%@", stream.summary.watchersCount];
                    
                    if (self.collectionView.indexPathsForSelectedItems.count == 1) {
                        NSIndexPath* selectedIndexPath = self.collectionView.indexPathsForSelectedItems[0];
                        if (streamIndex == selectedIndexPath.item) {
                            _currentHeader.watchersLabel.text = [NSString stringWithFormat:@"%@ now watching", stream.summary.watchersCount];
                        }
                    }
                    dispatch_group_leave(group);
                }
                
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                dispatch_group_leave(group);
            }];
        }
        
        NSArray* liveStreamIds = [results valueForKeyPath:@"id"];
        NSArray* currentStreams = _streams.copy;
        for (StreamController* stream in currentStreams) {
            if (![liveStreamIds containsObject:stream.summary.streamId]) {
                dispatch_group_enter(group);
                [self.collectionView performBatchUpdates:^{
                    NSInteger itemIndex = [self indexForStreamId:stream.summary.streamId];
                    NSArray *selectedItemsIndexPaths = @[[NSIndexPath indexPathForItem:itemIndex inSection:0]];
                    NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:itemIndex];
                    [stream uninitializePlayerWithCompletion:nil];
                    [_streams removeObjectsAtIndexes:indexSet];
                    // Now delete the items from the collection view.
                    [self.collectionView deleteItemsAtIndexPaths:selectedItemsIndexPaths];
                    
                } completion:^(BOOL finished) {
                    dispatch_group_leave(group);
                }];
            }
        }
        
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"summary.watchersCount"  ascending:NO];
            NSArray* sortedArray = [_streams sortedArrayUsingDescriptors:@[descriptor]];
            [self.collectionView performBatchUpdates:^{
                for (NSInteger sortedIndex = 0; sortedIndex < sortedArray.count; sortedIndex++) {
                    StreamController* stream = sortedArray[sortedIndex];
                    NSInteger currentIndex = [self indexForStreamId:stream.summary.streamId];
                    if (currentIndex != sortedIndex) {
                        [self.collectionView moveItemAtIndexPath:[NSIndexPath indexPathForItem:currentIndex inSection:0] toIndexPath:[NSIndexPath indexPathForItem:sortedIndex inSection:0]];
                    }                    
                }
                _streams = sortedArray.mutableCopy;
            } completion:^(BOOL finished) {
                
                NSNumber* liveStreams = [[NSUserDefaults standardUserDefaults] objectForKey:@"livestreams"];
                NSInteger maxPlayingStreams = liveStreams.integerValue;
                if (maxPlayingStreams > _streams.count) {
                    maxPlayingStreams = _streams.count;
                }
                
                for (NSInteger i = 0; i < maxPlayingStreams; i++) {
                    StreamController* stream = _streams[i];
                    [stream initializePlayer];
                }
                
                for (NSInteger i = maxPlayingStreams; i < _streams.count; i++) {
                    StreamController* stream = _streams[i];
                    [stream uninitializePlayerWithCompletion:^(BOOL completed) {
                        if (completed) {
                            [self fadeInCoverToImageView:stream.cell.coverImageView withStream:stream];
                        }
                    }];
                }
            }];
        });
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
}

- (NSInteger)indexForStreamId:(NSString*)streamId {
    NSInteger index = 0;
    for (StreamController* thisStream in _streams) {
        if ([streamId isEqualToString:thisStream.summary.streamId]) {
            return index;
        }
        index++;
    }
    return -1;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark Image Control

- (void)fadeInCoverToImageView:(UIImageView*)imageView withStream:(StreamController*)stream {
    imageView.alpha = 0.0f;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:stream.summary.coverURL];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];
    
    __weak UIImageView* weakImageView = imageView;
    [imageView setImageWithURLRequest:request placeholderImage:nil success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
        __strong UIImageView* strongImageView = weakImageView;
        strongImageView.image = image;
        [UIView animateWithDuration:0.3 animations:^{
            strongImageView.alpha = 1.0f;
        }];
    } failure:nil];
}

- (void)fadeOutCoverToImageView:(UIImageView*)imageView {
    [UIView animateWithDuration:1 animations:^{
        imageView.alpha = 0.0f;
    }];
}

#pragma mark Audio Control

- (void)muteAll {
    for (StreamController* stream in _streams) {
        [stream muteVolume];
    }
}

- (void)unmuteAll {
    for (StreamController* stream in _streams) {
        [stream unmuteVolume];
    }
}

- (BOOL)isSingleStreamPlaying {
    NSInteger numberPlaying = 0;
    for (StreamController* stream in _streams) {
        if (![stream isMuted]) {
            numberPlaying++;
        }
    }
    
    if (numberPlaying == 1) {
        return YES;
    }
    
    return NO;
    
}
- (BOOL)isAllPlaying {
    for (StreamController* stream in _streams) {
        if ([stream isMuted] && [stream playing]) {
            return NO;
        }
    }
    return YES;
}

#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _streams.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    StreamCell *cell = (StreamCell*)[collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    cell.streamPlaybackView.layer.sublayers = @[];
    cell.coverImageView.image = nil;
    cell.watchersLabel.text = @"";
    
    cell.coverImageView.contentMode = UIViewContentModeScaleAspectFill;

    StreamController* streamController = _streams[indexPath.item];
    

    // This is kind of gross
    streamController.cell = cell;

    [streamController addToLayer:cell.streamPlaybackView.layer];

    if (![streamController playing]) {
        [self fadeInCoverToImageView:cell.coverImageView withStream:streamController];
    }
    
    cell.delegate = self;
    cell.stream = streamController;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        cell.watchersLabel.font = [UIFont systemFontOfSize:12.0];
    }
    
    cell.watchersLabel.text = [NSString stringWithFormat:@"%@", streamController.summary.watchersCount];
    cell.contentView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];

    return cell;
}

#pragma mark <UICollectionViewDelegate>

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    StreamController* stream = _streams[indexPath.item];
    stream.cell = nil;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    UICollectionReusableView *reusableview = nil;
    
    if (kind == UICollectionElementKindSectionHeader) {
        _currentHeader = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"StreamHeader" forIndexPath:indexPath];
        reusableview = _currentHeader;
    }
    
    return reusableview;
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    StreamController* stream = _streams[indexPath.item];
    stream.cell.contentView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
}
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    StreamController* stream = _streams[indexPath.item];

    _currentHeader.stream = stream;
    _currentHeader.broadcasterDisplayNameLabel.text = stream.summary.broadcaster.displayName;
    _currentHeader.broadcasterNameLabel.text = [NSString stringWithFormat:@"@%@", stream.summary.broadcaster.name];
    [_currentHeader.avatarImageView setImageWithURL:stream.summary.broadcaster.imageURL];
    _currentHeader.captionLabel.text = stream.summary.caption;
    _currentHeader.locationLabel.text = stream.summary.location;
    _currentHeader.watchersLabel.text = [NSString stringWithFormat:@"%@ now watching", stream.summary.watchersCount];
    
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"meerkat://live/%@", stream.summary.streamId]];

    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(tappedActionButton)];
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }

    
    stream.cell.contentView.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    
    if ([self isAllPlaying]) {
        [self muteAll];
        [stream unmuteVolume];
    } else {
        if ([stream isMuted]) {
            [self muteAll];
            [stream unmuteVolume];
        } else {
            stream.cell.contentView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
            [self unmuteAll];
        }
    }
}


#pragma mark - StreamControllerDelegate

- (void)didBecomeLikelyToKeepUp:(StreamController *)stream {
    [self fadeOutCoverToImageView:stream.cell.coverImageView];
}

- (void)didBecomeUnlikelyToKeepUp:(StreamController *)stream {
    [self fadeInCoverToImageView:stream.cell.coverImageView withStream:stream];
}

#pragma mark - StreamCellDelegate

- (void)didReportStream:(StreamController *)stream {
    
    UIAlertController * alert=   [UIAlertController
                                  alertControllerWithTitle:@"Report"
                                  message:@"Report this stream?"
                                  preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* ok = [UIAlertAction
                         actionWithTitle:@"OK"
                         style:UIAlertActionStyleDefault
                         handler:^(UIAlertAction * action) {
                             [alert dismissViewControllerAnimated:YES completion:nil];
                             
                             NSString* urlString = [NSString stringWithFormat:@"https://channels.meerkatapp.co/broadcasts/%@/reports", stream.summary.streamId];
                             NSDictionary* params = @{@"auth":stream.summary.streamId};
                             
                             AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
                             AFJSONResponseSerializer* responseSerializer = [AFJSONResponseSerializer serializer];
                             responseSerializer.acceptableContentTypes = [responseSerializer.acceptableContentTypes setByAddingObject:@"text/html"];
                             [manager setResponseSerializer:responseSerializer];
                             [manager POST:urlString parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                 NSLog(@"%@", responseObject);
                             } failure:nil];
                         }];
    UIAlertAction* cancel = [UIAlertAction
                             actionWithTitle:@"Cancel"
                             style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction * action) {
                                 [alert dismissViewControllerAnimated:YES completion:nil];
                                 
                             }];
    
    [alert addAction:ok];
    [alert addAction:cancel];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)tappedActionButton {
    UIAlertController * alert=   [UIAlertController
                                  alertControllerWithTitle:@"Open"
                                  message:@"Goto this stream in Meerkat?"
                                  preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* ok = [UIAlertAction
                         actionWithTitle:@"OK"
                         style:UIAlertActionStyleDefault
                         handler:^(UIAlertAction * action) {
                             [alert dismissViewControllerAnimated:YES completion:nil];
                             NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"meerkat://live/%@", _currentHeader.stream.summary.streamId]];
                             
                             [[UIApplication sharedApplication] openURL:url];
                         }];
    UIAlertAction* cancel = [UIAlertAction
                             actionWithTitle:@"Cancel"
                             style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction * action) {
                                 [alert dismissViewControllerAnimated:YES completion:nil];
                                 
                             }];
    
    [alert addAction:ok];
    [alert addAction:cancel];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end
