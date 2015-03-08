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

@interface PlayerCollectionViewController () <StreamControllerDelegate> {
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
        
    [NSTimer scheduledTimerWithTimeInterval:5.0
                                     target:self
                                   selector:@selector(checkForNewStreams)
                                   userInfo:nil
                                    repeats:YES];
    [self checkForNewStreams];
}

- (void)checkForNewStreams {
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    AFJSONResponseSerializer* responseSerializer = [AFJSONResponseSerializer serializer];
    responseSerializer.acceptableContentTypes = [responseSerializer.acceptableContentTypes setByAddingObject:@"text/html"];
    [manager setResponseSerializer:responseSerializer];
    [manager GET:@"https://resources.meerkatapp.co/broadcasts" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSArray* results = responseObject[@"result"];
        dispatch_group_t group = dispatch_group_create();
        NSMutableArray* addedIndexPaths = @[].mutableCopy;
        
        for (NSDictionary* stream in results) {
            
            dispatch_group_enter(group);
            [manager GET:stream[@"broadcast"] parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
                StreamSummary* summary = [MTLJSONAdapter modelOfClass:StreamSummary.class fromJSONDictionary:responseObject error:nil];
                
                NSInteger streamIndex = [self indexForStreamId:stream[@"id"]];
                if (streamIndex == -1) {
                    if ([summary.status isEqualToString:@"live"]) {
                        NSInteger itemIndex = _streams.count;
                        StreamController* streamController = [[StreamController alloc] initWithSummary:summary];
                        streamController.delegate = self;
                        if ((_streams.count > 1) && ([self isSingleStreamPlaying])) {
                            [streamController muteVolume];
                        }
                        
                        [addedIndexPaths addObject:[NSIndexPath indexPathForItem:itemIndex inSection:0]];
                        [_streams addObject:streamController];
                    }
                } else {
                    StreamController* stream = _streams[streamIndex];
                    stream.summary = summary;
                    stream.cell.watchersLabel.text = [NSString stringWithFormat:@"%@", stream.summary.watchersCount];
                }
                
                dispatch_group_leave(group);
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                dispatch_group_leave(group);
            }];
        }
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            [self.collectionView performBatchUpdates:^{
                [self.collectionView insertItemsAtIndexPaths:addedIndexPaths];
            } completion:nil];
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

#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _streams.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    StreamCell *cell = (StreamCell*)[collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    
    
    StreamController* streamController = _streams[indexPath.item];
    streamController.cell = cell;
    [streamController playStreamOnLayer:cell.streamPlaybackView.layer];

    cell.watchersLabel.text = [NSString stringWithFormat:@"%@", streamController.summary.watchersCount];
    
    return cell;
}

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
        if ([stream isMuted]) {
            return NO;
        }
    }
    return YES;
}

#pragma mark <UICollectionViewDelegate>
- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    UICollectionReusableView *reusableview = nil;
    
    if (kind == UICollectionElementKindSectionHeader) {
        _currentHeader = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"StreamHeader" forIndexPath:indexPath];
        reusableview = _currentHeader;
    }
    
    return reusableview;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    StreamController* stream = _streams[indexPath.item];
    
    _currentHeader.broadcasterDisplayNameLabel.text = stream.summary.broadcaster.displayName;
    _currentHeader.broadcasterNameLabel.text = [NSString stringWithFormat:@"@%@", stream.summary.broadcaster.name];
    [_currentHeader.avatarImageView setImageWithURL:stream.summary.broadcaster.imageURL];

    if ([self isAllPlaying]) {
        [self muteAll];
        [stream unmuteVolume];
    } else {
        if ([stream isMuted]) {
            [self muteAll];
            [stream unmuteVolume];
        } else {
            [self unmuteAll];
        }
    }
}
/*
// Uncomment this method to specify if the specified item should be highlighted during tracking
- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}
*/

/*
// Uncomment this method to specify if the specified item should be selected
- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}
*/

/*
// Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
- (BOOL)collectionView:(UICollectionView *)collectionView shouldShowMenuForItemAtIndexPath:(NSIndexPath *)indexPath {
	return NO;
}

- (BOOL)collectionView:(UICollectionView *)collectionView canPerformAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
	return NO;
}

- (void)collectionView:(UICollectionView *)collectionView performAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
	
}
*/

#pragma mark - StreamControllerDelegate

- (void)didFinishPlayingWithStream:(StreamController *)stream {
    
    NSInteger itemIndex = [self indexForStreamId:stream.summary.streamId];
    if (itemIndex != -1) {
        [self.collectionView performBatchUpdates:^{
            
            NSArray *selectedItemsIndexPaths = @[[NSIndexPath indexPathForItem:itemIndex inSection:0]];
            
            // Delete the items from the data source.
            NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
            for (NSIndexPath *itemPath  in selectedItemsIndexPaths) {
                [indexSet addIndex:itemPath.row];
                
            }
            [_streams removeObjectsAtIndexes:indexSet];
            
            // Now delete the items from the collection view.
            [self.collectionView deleteItemsAtIndexPaths:selectedItemsIndexPaths];
            
        } completion:nil];
    }
}

- (void)didBecomeReadyToPlayWithStream:(StreamController *)stream {
    NSInteger itemIndex = [self indexForStreamId:stream.summary.streamId];
    if (itemIndex != -1) {
        [self.collectionView reloadItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:itemIndex inSection:0]]];
    }
}

@end
