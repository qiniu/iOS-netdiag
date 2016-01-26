//
//  QNNPing.h
//  NetDiag
//
//  Created by bailong on 15/12/30.
//  Copyright © 2015年 Qiniu Cloud Storage. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNNProtocols.h"

@interface QNNPing : NSObject

-(instancetype) init:(NSString*)dest;

-(instancetype) init:(NSString*)dest count:(int)count;

@end
