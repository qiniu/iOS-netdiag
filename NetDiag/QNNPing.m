//
//  QNNPing.m
//  NetDiag
//
//  Created by bailong on 15/12/30.
//  Copyright © 2015年 Qiniu Cloud Storage. All rights reserved.
//

#import "QNNPing.h"

@interface QNNPing ()
@property (nonatomic, strong) id<QNNOutputDelegate> output;
@end

@implementation QNNPing

+(instancetype) start:(NSString*)host
               output:(id<QNNOutputDelegate>)output
             complete:(QNNPingCompleteHandler)complete{
    return [QNNPing start:host output:output complete:complete interval:200 count:10];
}

+(instancetype) start:(NSString*)host
               output:(id<QNNOutputDelegate>)output
             complete:(QNNPingCompleteHandler)complete
             interval:(NSInteger)interval
                count:(NSInteger)count{
    return nil;
}

-(void)stop{
    return;
}

@end
