//
//  RtmpTest.m
//  NetDiag
//
//  Created by bailong on 16/2/11.
//  Copyright © 2016年 Qiniu Cloud Storage. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "QNNRtmp.h"

#import "QNNTestLogger.h"

#import <AGAsyncTestHelper.h>

@interface RtmpTest : XCTestCase

@end

@implementation RtmpTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

//- (void)testTimeout {
//    __block BOOL run = NO;
//    [QNNRtmpHandshake start:@"up.qiniu.com" output:[[QNNTestLogger alloc] init] complete:^(QNNRtmpHandshakeResult* r) {
//        XCTAssertNotNil(r, @"need result");
//        XCTAssertEqual(ETIMEDOUT, r.code, @"timeout code");
//        run = YES;
//    }];
//    AGWW_WAIT_WHILE(!run, 100.0);
//    XCTAssert(run, @"PASS");
//}

- (void)testStop {
    __block BOOL run = NO;
    id<QNNStopDelegate> h = [QNNRtmpHandshake start:@"www.qiniu.com" output:[[QNNTestLogger alloc] init] complete:^(QNNRtmpHandshakeResult* r) {
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
    [QNNRtmpHandshake start:@"live-rtmp.live.miclle.com" output:[[QNNTestLogger alloc] init] complete:^(QNNRtmpHandshakeResult* r) {
        XCTAssertNotNil(r, @"need result");
        XCTAssertEqual(0, r.code, @"normal code");
        XCTAssert(r.maxTime >= r.avgTime, @"max time >= avg time");
        XCTAssert(r.minTime <= r.avgTime, @"min time =< avg time");
        run = YES;
    }];

    AGWW_WAIT_WHILE(!run, 30.0);
    XCTAssert(run, @"PASS");
}

@end
