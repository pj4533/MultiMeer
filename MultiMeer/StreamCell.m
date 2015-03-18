//
//  StreamCell.m
//  MultiMeer
//
//  Created by PJ Gray on 3/8/15.
//  Copyright (c) 2015 Say Goodnight Software. All rights reserved.
//

#import "StreamCell.h"

@implementation StreamCell

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        UITapGestureRecognizer *doubleTapFolderGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(processDoubleTap:)];
        [doubleTapFolderGesture setNumberOfTapsRequired:2];
        [doubleTapFolderGesture setNumberOfTouchesRequired:1];
        [self.contentView addGestureRecognizer:doubleTapFolderGesture];
    }
    return self;
}

- (IBAction)reportTapped:(id)sender {
    if (self.delegate) {
        [self.delegate didReportStream:self.stream];
    }
}

- (void)processDoubleTap:(UITapGestureRecognizer*)gestureRecognizer {
    if (self.delegate) {
        [self.delegate didDoubleTapStream:self.stream];
    }
}

@end
