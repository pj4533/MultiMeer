//
//  StreamHeader.h
//  MultiMeer
//
//  Created by PJ Gray on 3/8/15.
//  Copyright (c) 2015 Say Goodnight Software. All rights reserved.
//

#import <UIKit/UIKit.h>

@class StreamController;
@interface StreamHeader : UICollectionReusableView
@property (weak, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (weak, nonatomic) IBOutlet UILabel *broadcasterNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *broadcasterDisplayNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *captionLabel;
@property (weak, nonatomic) IBOutlet UILabel *watchersLabel;
@property (weak, nonatomic) IBOutlet UILabel *locationLabel;

// Dont like this -- hack
@property (weak, nonatomic) StreamController* stream;


@end
