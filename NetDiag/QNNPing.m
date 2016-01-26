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

-(instancetype) init:(NSString*)dest{
    return [self init:dest count:10];
}

-(instancetype) init:(NSString*)dest count:(int)count{
    
    return self;
}

-(void)setOutput:(id<QNNOutputDelegate>)output{
    _output = output;
}

-(void)start{
    if (_output == nil) {
        return;
    }
}

-(void)stop{
    
}

@end
