//
//  PlayerCollectionViewController.m
//  MultiMeer
//
//  Created by PJ Gray on 3/7/15.
//  Copyright (c) 2015 Say Goodnight Software. All rights reserved.
//

#import "PlayerCollectionViewController.h"
#import <AFNetworking/AFNetworking.h>
#import "StreamController.h"

@interface PlayerCollectionViewController () <StreamControllerDelegate> {
    NSMutableArray* _streams;
}

@end

@implementation PlayerCollectionViewController

static NSString * const reuseIdentifier = @"Cell";

- (void)viewDidLoad {
    [super viewDidLoad];
    _streams = @[].mutableCopy;
    
    // Uncomment the following line to preserve selection between presentations
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Register cell classes
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:reuseIdentifier];
    
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
            
            if (![self streamsContainsId:stream[@"id"]]) {
                dispatch_group_enter(group);
                [manager GET:stream[@"broadcast"] parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
                    NSURL* url = [NSURL URLWithString:responseObject[@"followupActions"][@"playlist"]];
                    
                    NSInteger itemIndex = _streams.count;
                    StreamController* streamController = [[StreamController alloc] initWithURL:url withId:stream[@"id"]];
                    streamController.delegate = self;
                    
                    [addedIndexPaths addObject:[NSIndexPath indexPathForItem:itemIndex inSection:0]];
                    [_streams addObject:streamController];
                    dispatch_group_leave(group);
                } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                    dispatch_group_leave(group);
                }];
            }
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

- (NSInteger)indexForStream:(StreamController*)stream {
    NSInteger index = 0;
    for (StreamController* thisStream in _streams) {
        if ([stream.streamId isEqualToString:thisStream.streamId]) {
            return index;
        }
        index++;
    }
    return -1;
}

- (BOOL)streamsContainsId:(NSString*)streamId {
    for (StreamController* stream in _streams) {
        if ([stream.streamId isEqualToString:streamId]) {
            return YES;
        }
    }
    return NO;
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
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    
    StreamController* streamController = _streams[indexPath.item];
    [streamController playStreamOnLayer:cell.contentView.layer];
    
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

- (BOOL)isAllPlaying {
    for (StreamController* stream in _streams) {
        if ([stream isMuted]) {
            return NO;
        }
    }
    return YES;
}

#pragma mark <UICollectionViewDelegate>

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    StreamController* stream = _streams[indexPath.item];

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
    
    NSInteger itemIndex = [self indexForStream:stream];
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
    NSInteger itemIndex = [self indexForStream:stream];
    if (itemIndex != -1) {
        [self.collectionView reloadItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:itemIndex inSection:0]]];
    }
}

@end
