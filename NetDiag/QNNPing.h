//
//  QNNPing.h
//  NetDiag
//
//  Created by bailong on 15/12/30.
//  Copyright © 2015年 Qiniu Cloud Storage. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNNProtocols.h"

@interface QNNPingResult : NSObject

@property (readonly) NSInteger code;
@property (readonly) NSTimeInterval maxRtt;
@property (readonly) NSTimeInterval minRtt;
@property (readonly) NSTimeInterval avgRtt;
@property (readonly) double lossRate;
@property (readonly) NSInteger count;
@property (readonly) NSInteger interval;

-(NSString*) description;

@end

typedef void (^QNNPingCompleteHandler)(QNNPingResult*) ;

@interface QNNPing : NSObject<QNNStopDelegate>

+(instancetype) start:(NSString*)host
               output:(id<QNNOutputDelegate>)output
             complete:(QNNPingCompleteHandler)complete;

+(instancetype) start:(NSString*)host
               output:(id<QNNOutputDelegate>)output
             complete:(QNNPingCompleteHandler)complete
             interval:(NSInteger)interval
                count:(NSInteger)count;

@end
