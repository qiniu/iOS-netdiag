//
//  PingTest.m
//  NetDiag
//
//  Created by bailong on 16/2/17.
//  Copyright © 2016年 Qiniu Cloud Storage. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <AGAsyncTestHelper.h>

#import "QNNPing.h"
#import "QNNTestLogger.h"
#import "QNNTraceRoute.h"

@interface PingTest : XCTestCase

@end

@implementation PingTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testTimeout {
    __block BOOL run = NO;
    [QNNPing start:@"1.1.1.1" size:100 output:[[QNNTestLogger alloc] init] complete:^(QNNPingResult* r) {
        XCTAssertNotNil(r, @"need result");
        run = YES;
    }];
    AGWW_WAIT_WHILE(!run, 100.0);
    XCTAssert(run, @"PASS");
}

- (void)testStop {
    __block BOOL run = NO;
    id<QNNStopDelegate> h = [QNNPing start:@"www.qiniu.com" size:100 output:[[QNNTestLogger alloc] init] complete:^(QNNPingResult* r) {
        XCTAssertNotNil(r, @"need result");
        XCTAssertEqual(kQNNRequestStoped, r.code, @"stop code");
        run = YES;
    }];
    [h stop];
    AGWW_WAIT_WHILE(!run, 30.0);
    XCTAssert(run, @"PASS");
}

- (void)testOK {
    __block BOOL run = NO;
    [QNNPing start:@"www.baidu.com" size:100 output:[[QNNTestLogger alloc] init] complete:^(QNNPingResult* r) {
        XCTAssertNotNil(r, @"need result");
        XCTAssertNotNil(r.ip, @"need ip");
        XCTAssertEqual(0, r.code, @"normal code");
        XCTAssert(r.maxRtt >= r.avgRtt, @"max time >= avg time");
        XCTAssert(r.minRtt <= r.avgRtt, @"min time =< avg time");
        run = YES;
    }];

    AGWW_WAIT_WHILE(!run, 30.0);
    XCTAssert(run, @"PASS");
}

@end
