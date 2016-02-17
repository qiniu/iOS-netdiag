//
//  ExternalIpTest.m
//  NetDiag
//
//  Created by bailong on 16/2/17.
//  Copyright © 2016年 Qiniu Cloud Storage. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "QNNExternalIp.h"

@interface ExternalIpTest : XCTestCase

@end

@implementation ExternalIpTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testIpOK {
    NSString* ip = [QNNExternalIp externalIp];
    XCTAssertNotNil(ip, @"null ip");
    XCTAssertNotEqualObjects(ip, @"", @"empty ip");
}

- (void)testCheckOK {
    NSString* data = [QNNExternalIp checkExternal];
    XCTAssertNotNil(data, @"null return");
    XCTAssertNotEqualObjects(data, @"", @"empty data");
    NSLog(@"%@", data);
}

@end
