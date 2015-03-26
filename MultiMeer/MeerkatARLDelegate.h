//
//  MeerkatARLDelegate.h
//  Meerless
//
//  Created by Wesley Crozier on 24/03/2015.
//  Copyright (c) 2015 Wesley Crozier. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVAssetResourceLoader.h>


@interface MeerkatARLDelegate : NSObject <AVAssetResourceLoaderDelegate> 

@property BOOL recording;
@property (nonatomic, weak) id delegate;

@end
