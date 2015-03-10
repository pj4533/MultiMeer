//
//  StreamCell.h
//  MultiMeer
//
//  Created by PJ Gray on 3/8/15.
//  Copyright (c) 2015 Say Goodnight Software. All rights reserved.
//

#import <UIKit/UIKit.h>

@class StreamController;
@protocol StreamCellDelegate <NSObject>

- (void)didReportStream:(StreamController*)stream;

@end

@interface StreamCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UILabel *watchersLabel;
@property (weak, nonatomic) IBOutlet UILabel *captionLabel;
@property (weak, nonatomic) IBOutlet UILabel *locationLabel;
@property (weak, nonatomic) IBOutlet UIView *streamPlaybackView;

@property (weak, nonatomic) id delegate;
@property (weak, nonatomic) StreamController* stream;

@end
