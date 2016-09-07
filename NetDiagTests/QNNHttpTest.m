//
//  QNNHttpTest.m
//  NetDiag
//
//  Created by bailong on 16/2/14.
//  Copyright © 2016年 Qiniu Cloud Storage. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <AGAsyncTestHelper.h>

#import "QNNHttp.h"
#import "QNNTestLogger.h"

@interface QNNHttpTest : XCTestCase

@end

@implementation QNNHttpTest

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
    [QNNHttp start:@"http://www.baidu.com" output:[[QNNTestLogger alloc] init] complete:^(QNNHttpResult* r) {
        XCTAssertNotNil(r, @"need result");
        XCTAssertNotNil(r.ip, @"need ip");
        XCTAssertNotNil(r.headers, @"need headers");
        XCTAssertNotNil(r.body, @"need body");
        XCTAssertEqual(200, r.code, @"normal code");
        XCTAssert(r.duration > 0, @"duration > 0");
        run = YES;
    }];

    AGWW_WAIT_WHILE(!run, 30.0);
    XCTAssert(run, @"PASS");
}

@end
