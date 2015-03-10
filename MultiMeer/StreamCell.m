//
//  StreamCell.m
//  MultiMeer
//
//  Created by PJ Gray on 3/8/15.
//  Copyright (c) 2015 Say Goodnight Software. All rights reserved.
//

#import "StreamCell.h"

@implementation StreamCell
- (IBAction)reportTapped:(id)sender {
    if (self.delegate) {
        [self.delegate didReportStream:self.stream];
    }
}

@end
