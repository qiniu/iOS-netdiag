//
//  QNNProtocols.h
//  NetDiag
//
//  Created by bailong on 15/12/30.
//  Copyright © 2015年 Qiniu Cloud Storage. All rights reserved.
//


#import <Foundation/Foundation.h>

@protocol QNNOutputDelegate <NSObject>

-(void) Write:(NSString*)line;

@optional
-(void) setMaxLine:(int)number;
-(void) end;

@end
