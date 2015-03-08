//
//  StreamHeader.h
//  MultiMeer
//
//  Created by PJ Gray on 3/8/15.
//  Copyright (c) 2015 Say Goodnight Software. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface StreamHeader : UICollectionReusableView
@property (weak, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (weak, nonatomic) IBOutlet UILabel *broadcasterNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *broadcasterDisplayNameLabel;

@end
