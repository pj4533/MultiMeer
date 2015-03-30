//
//  cplpARLDelegate.m
//  Meerless
//
//  Created by Wesley Crozier on 24/03/2015.
//  Copyright (c) 2015 Wesley Crozier. All rights reserved.
//

#import "MeerkatARLDelegate.h"
#import "KMMedia.h"
#import "StreamController.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface MeerkatARLDelegate () {
    BOOL _recording;
    NSMutableArray* _tsFilesOnDisk;
    NSMutableArray* _tsFilesNotSaved;
}

@end

@implementation MeerkatARLDelegate

-(MeerkatARLDelegate *) init {

    self = [super init];
    if (self) {
        _tsFilesNotSaved = @[].mutableCopy;
    }
    return self;
}

// This is mad hackery. At first I was listening for this delegate method and it never fired, yeah even after
// I put everything all on the same thread. This is because http links are passed right to the AVAssetLoader.
// So in order to do stuff with the files you need fake schemes.
- (BOOL) resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    
    NSString *scheme = [[[loadingRequest request] URL] scheme];
    
    // rdtp is used for the redirected .ts chunks
    if ([@"rdtp" isEqualToString:scheme]) {
        
        return [self handleTSRequest:loadingRequest];
    }
    
    // mrkt is used for the actual .m3u8 requests
    if ([@"mrkt" isEqualToString:scheme]) {
        
        dispatch_async (dispatch_get_main_queue(), ^{
            [self handlePlaylistRequest:loadingRequest];
        });
        return YES;
    }
    
    return NO;
}


// Maps mrkt to http
- (BOOL) handlePlaylistRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    
    // Ok, get ready for mad hackery. But whatever, it works.
    // First we
    NSString *url = [[[[loadingRequest request] URL] absoluteString] stringByReplacingOccurrencesOfString:@"mrkt" withString:@"http"];
    NSString *prefix = [[[[loadingRequest request] URL] absoluteString] stringByReplacingOccurrencesOfString:@"mrkt" withString:@"rdtp"];
    
    // Then make the request for the live.m3u8 file.
    NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:url] options:NSDataReadingUncached error:nil];
    if (data) {
        NSString *meerkatM3U8 = [NSString stringWithUTF8String:[data bytes]];
        if (meerkatM3U8) {
            NSRange range = [prefix rangeOfString:@"/" options:NSBackwardsSearch];
            prefix = [prefix substringToIndex:range.location];
            
            // Next we modify meerkats .m3u8 by replacing the .ts files with a absolute prefix and then we pass that data back
            // up to AVAssetLoader, which in turns makes several new .ts requests with the "rdtp" fake URL Scheme.
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern: @"\\S+\\.ts" options:0 error:nil];
            NSString *hackedM3u8 = [regex stringByReplacingMatchesInString:meerkatM3U8 options:0 range:NSMakeRange(0, [meerkatM3U8 length]) withTemplate:[NSString stringWithFormat:@"%@/$0",prefix]];
            
            data = [hackedM3u8 dataUsingEncoding:NSUTF8StringEncoding];
            
            if (data) {
                
                [loadingRequest.dataRequest respondWithData:data];
                [loadingRequest finishLoading];
                
            } else {
                
                [loadingRequest finishLoadingWithError:[NSError errorWithDomain: NSURLErrorDomain code:400 userInfo: nil]];
            }
        }
    }
    
    return YES;
}


- (BOOL)recording {
    return _recording;
}

- (void)setRecording:(BOOL)recording {
    _recording = recording;
    if (!_recording) {
        
        NSLog(@"EXPORTING...");
        NSError *error;
        if(!error)
        {
            __block NSUInteger tsFileCount = [_tsFilesOnDisk count];
            if (tsFileCount > 0)
            {
                NSMutableArray *tsAssetList = [NSMutableArray arrayWithCapacity:tsFileCount];
                for(NSString *tsFileName in _tsFilesOnDisk)
                {
                    NSURL *tsFileURL = [NSURL URLWithString:tsFileName];
                    [tsAssetList addObject:[KMMediaAsset assetWithURL:tsFileURL withFormat:KMMediaFormatTS]];
                }
                
                NSString* mp4FileURLString = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Result.mp4"];

                NSURL *mp4FileURL = [NSURL URLWithString:mp4FileURLString];
                KMMediaAsset *mp4Asset = [KMMediaAsset assetWithURL:mp4FileURL withFormat:KMMediaFormatMP4];
                
                KMMediaAssetExportSession *tsToMP4ExportSession = [[KMMediaAssetExportSession alloc] initWithInputAssets:tsAssetList];
                tsToMP4ExportSession.outputAssets = @[mp4Asset];
                
                [tsToMP4ExportSession exportAsynchronouslyWithCompletionHandler:^{
                    _tsFilesNotSaved = @[].mutableCopy;
                    if (tsToMP4ExportSession.status == KMMediaAssetExportSessionStatusCompleted) {
                        NSLog(@"COMPLETED EXPORT");
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate didStartSavingStream:nil];
                        });
                        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
                        [library writeVideoAtPathToSavedPhotosAlbum:mp4FileURL completionBlock:^(NSURL *assetURL, NSError *error) {
                            
                            [[NSFileManager defaultManager] removeItemAtPath:mp4FileURLString error:nil];
                            for(NSString *tsFileName in _tsFilesOnDisk) {
                                [[NSFileManager defaultManager] removeItemAtPath:tsFileName error:nil];
                            }

                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.delegate didFinishSavingStream:nil];
                            });
                            
                        }];

                    }
                    else {
                        NSLog(@"EXPORT FAILED");
                    }
                }];
            }
        }
    } else {
        _tsFilesOnDisk = @[].mutableCopy;
        
        for (NSURL* url in _tsFilesNotSaved) {
            // abstract this
            NSLog(@"Adding unsaved:  %@", url);
            NSString* tsDataPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:url.lastPathComponent];
            NSData *tsData = [NSData dataWithContentsOfURL:url];
            [tsData writeToFile:tsDataPath atomically:YES];
            [_tsFilesOnDisk addObject:tsDataPath];
        }
    }
}



// Maps rdtp to http
- (BOOL) handleTSRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    
    // We can now remap meerkat .ts requests back to http and then decide what we
    // want to do with the files.
    NSURLRequest *redirect = nil;
    redirect = [NSURLRequest requestWithURL:[NSURL URLWithString:[[[(NSURLRequest *)[loadingRequest request] URL] absoluteString] stringByReplacingOccurrencesOfString:@"rdtp" withString:@"http"]]];
    
    if (redirect) {
        
        
        // HACK ALERT
        NSString* tsDataPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:redirect.URL.lastPathComponent];
        if (self.recording) {
            // TODO: PJ, you can start to download the chunks by implementing a simple
            // download queue system here.
            NSLog(@"SAVED TO FILE: %@", tsDataPath);
            NSData *tsData = [NSData dataWithContentsOfURL:[redirect URL]];
            [tsData writeToFile:tsDataPath atomically:YES];
            
            [_tsFilesOnDisk addObject:tsDataPath];
        } else {
            [_tsFilesNotSaved addObject:redirect.URL];
        }
        
        // NOTE: After several hours of digging I found that you CANNOT pass HLS chunks directly
        // to the player. It would be great *if* this was possible because after we download the file
        // we could save it to disk and pass it via respondWithData thus only using one network
        // call per chunk. =(
        [loadingRequest setRedirect:redirect];
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[redirect URL] statusCode:302 HTTPVersion:nil headerFields:nil];
        [loadingRequest setResponse:response];
        [loadingRequest finishLoading];
        
    } else {

        [loadingRequest finishLoadingWithError:[NSError errorWithDomain: NSURLErrorDomain code:400 userInfo: nil]];
    }
	return YES;
}




@end

