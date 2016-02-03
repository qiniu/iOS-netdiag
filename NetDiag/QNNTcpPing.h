//
//  QNNTcpPing.h
//  NetDiag
//
//  Created by bailong on 16/1/26.
//  Copyright © 2016年 Qiniu Cloud Storage. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNNProtocols.h"

@interface QNNTcpPingResult : NSObject

@property (readonly) NSInteger code;
@property (readonly) NSInteger maxRtt;
@property (readonly) NSInteger minRtt;
@property (readonly) NSInteger avgRtt;
@property (readonly) NSInteger count;

-(NSString*) description;

@end

typedef void (^QNNTcpPingCompleteHandler)(QNNTcpPingResult*);

@interface QNNTcpPing : NSObject<QNNStopDelegate>

/**
 *    default port is 80
 *
 *    @param host     domain or ip
 *    @param output   output logger
 *    @param complete complete callback, maybe null
 *
 *    @return QNNTcpping instance, could be stop
 */
+(instancetype) start:(NSString*)host
               output:(id<QNNOutputDelegate>)output
             complete:(QNNTcpPingCompleteHandler)complete;

+(instancetype) start:(NSString*)host
                 port:(NSUInteger)port
               output:(id<QNNOutputDelegate>)output
             complete:(QNNTcpPingCompleteHandler)complete
                count:(NSInteger)count;

@end