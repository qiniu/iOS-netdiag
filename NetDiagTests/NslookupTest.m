//
//  NslookupTest.m
//  NetDiag
//
//  Created by bailong on 16/2/12.
//  Copyright © 2016年 Qiniu Cloud Storage. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <AGAsyncTestHelper.h>

#import "QNNNslookup.h"
#import "QNNTestLogger.h"

@interface NslookupTest : XCTestCase

@end

@implementation NslookupTest

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
    id<QNNStopDelegate> h = [QNNNslookup start:@"www.baidu.com" output:[[QNNTestLogger alloc]init] complete:^(NSArray * records) {
        XCTAssertNotNil(records, @"need result");
        XCTAssert(records.count>= 2, @"max record >= 2");
        run = YES;
    }];
    
    AGWW_WAIT_WHILE(!run, 30.0);
    XCTAssert(run, @"PASS");
}

@end
