//
//  StreamCell.h
//  MultiMeer
//
//  Created by PJ Gray on 3/8/15.
//  Copyright (c) 2015 Say Goodnight Software. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface StreamCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UILabel *watchersLabel;
@property (weak, nonatomic) IBOutlet UILabel *captionLabel;
@property (weak, nonatomic) IBOutlet UILabel *locationLabel;

@end
