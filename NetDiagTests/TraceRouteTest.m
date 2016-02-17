//
//  TraceRouteTest.m
//  NetDiag
//
//  Created by bailong on 16/2/17.
//  Copyright © 2016年 Qiniu Cloud Storage. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <AGAsyncTestHelper.h>

#import "QNNTraceRoute.h"
#import "QNNTestLogger.h"

@interface TraceRouteTest : XCTestCase

@end

@implementation TraceRouteTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testOK {
    __block BOOL run = NO;
    [QNNTraceRoute start:@"www.akamai.com" output:[[QNNTestLogger alloc]init] complete:^(QNNTraceRouteResult* r) {
        XCTAssertNotNil(r, @"need result");
        XCTAssertEqual(0, r.code, @"normal code");
        run = YES;
    }];
    
    AGWW_WAIT_WHILE(!run, 500.0);
    XCTAssert(run, @"PASS");
}

@end
