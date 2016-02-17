//
//  QNNTcpPing.m
//  NetDiag
//
//  Created by bailong on 16/1/26.
//  Copyright © 2016年 Qiniu Cloud Storage. All rights reserved.
//

#import <arpa/inet.h>
#import <netdb.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <unistd.h>

#include <netinet/in.h>
#include <netinet/tcp.h>

#import "QNNTcpPing.h"

@interface QNNTcpPingResult ()

- (instancetype)init:(NSInteger)code
                 max:(NSTimeInterval)maxTime
                 min:(NSTimeInterval)minTime
                 avg:(NSTimeInterval)avgTime
               count:(NSInteger)count;
@end

@implementation QNNTcpPingResult

- (NSString *)description {
    if (_code == 0 || _code == kQNNRequestStoped) {
        return [NSString stringWithFormat:@"tcp connect min/avg/max = %.3f/%.3f/%.3fms", _minTime, _avgTime, _maxTime];
    }
    return [NSString stringWithFormat:@"tcp connect failed %ld", (long)_code];
}

- (instancetype)init:(NSInteger)code
                 max:(NSTimeInterval)maxTime
                 min:(NSTimeInterval)minTime
                 avg:(NSTimeInterval)avgTime
               count:(NSInteger)count {
    if (self = [super init]) {
        _code = code;
        _minTime = minTime;
        _avgTime = avgTime;
        _maxTime = maxTime;
        _count = count;
    }
    return self;
}

@end

@interface QNNTcpPing ()

@property (readonly) NSString *host;
@property (readonly) NSUInteger port;
@property (readonly) id<QNNOutputDelegate> output;
@property (readonly) QNNTcpPingCompleteHandler complete;
@property (readonly) NSInteger interval;
@property (readonly) NSInteger count;
@property (atomic) BOOL stopped;
@end

@implementation QNNTcpPing

- (instancetype)init:(NSString *)host
                port:(NSInteger)port
              output:(id<QNNOutputDelegate>)output
            complete:(QNNTcpPingCompleteHandler)complete
               count:(NSInteger)count {
    if (self = [super init]) {
        _host = host;
        _port = port;
        _output = output;
        _complete = complete;
        _count = count;
        _stopped = NO;
    }
    return self;
}

- (void)run {
    [self.output write:[NSString stringWithFormat:@"connect to host %@:%lu ...\n", _host, (unsigned long)_port]];
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(_port);
    addr.sin_addr.s_addr = inet_addr([_host UTF8String]);
    if (addr.sin_addr.s_addr == INADDR_NONE) {
        struct hostent *host = gethostbyname([_host UTF8String]);
        if (host == NULL || host->h_addr == NULL) {
            [self.output write:@"Problem accessing the DNS"];
            if (_complete != nil) {
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    _complete([self buildResult:-1006 durations:nil count:0]);
                });
            }
            return;
        }
        addr.sin_addr = *(struct in_addr *)host->h_addr;
        [self.output write:[NSString stringWithFormat:@"connect to ip %s:%lu ...\n", inet_ntoa(addr.sin_addr), (unsigned long)_port]];
    }

    NSTimeInterval *intervals = (NSTimeInterval *)malloc(sizeof(NSTimeInterval) * _count);
    int index = 0;
    int r = 0;
    do {
        NSDate *t1 = [NSDate date];
        r = [self connect:&addr];
        NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:t1];
        intervals[index] = duration * 1000;
        if (r == 0) {
            [self.output write:[NSString stringWithFormat:@"connected to %s:%lu, %f ms\n", inet_ntoa(addr.sin_addr), (unsigned long)_port, duration * 1000]];
        } else {
            [self.output write:[NSString stringWithFormat:@"connect failed to %s:%lu, %f ms, error %d\n", inet_ntoa(addr.sin_addr), (unsigned long)_port, duration * 1000, r]];
        }

        if (index < _count && !_stopped && r == 0) {
            [NSThread sleepForTimeInterval:0.1];
        }
    } while (++index < _count && !_stopped && r == 0);

    if (_complete) {
        NSInteger code = r;
        if (_stopped) {
            code = kQNNRequestStoped;
        }
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            _complete([self buildResult:code durations:intervals count:index]);
        });
    }
    free(intervals);
}

- (QNNTcpPingResult *)buildResult:(NSInteger)code
                        durations:(NSTimeInterval *)durations
                            count:(NSInteger)count {
    if (code != 0 && code != kQNNRequestStoped) {
        return [[QNNTcpPingResult alloc] init:code max:0 min:0 avg:0 count:1];
    }
    NSTimeInterval max = 0;
    NSTimeInterval min = 10000000;
    NSTimeInterval sum = 0;
    for (int i = 0; i < count; i++) {
        if (durations[i] > max) {
            max = durations[i];
        }
        if (durations[i] < min) {
            min = durations[i];
        }
        sum += durations[i];
    }
    NSTimeInterval avg = sum / count;
    return [[QNNTcpPingResult alloc] init:code max:max min:min avg:avg count:count];
}

- (int)connect:(struct sockaddr_in *)addr {
    int sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (sock == -1) {
        return errno;
    }
    int on = 1;
    setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &on, sizeof(on));
    setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, (char *)&on, sizeof(on));

    struct timeval timeout;
    timeout.tv_sec = 10;
    timeout.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (char *)&timeout, sizeof(timeout));
    setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, (char *)&timeout, sizeof(timeout));

    if (connect(sock, (struct sockaddr *)addr, sizeof(struct sockaddr)) < 0) {
        int err = errno;
        close(sock);
        return err;
    }
    close(sock);
    return 0;
}

+ (instancetype)start:(NSString *)host
               output:(id<QNNOutputDelegate>)output
             complete:(QNNTcpPingCompleteHandler)complete {
    return [QNNTcpPing start:host port:80 count:3 output:output complete:complete];
}

+ (instancetype)start:(NSString *)host
                 port:(NSUInteger)port
                count:(NSInteger)count
               output:(id<QNNOutputDelegate>)output
             complete:(QNNTcpPingCompleteHandler)complete;
{
    QNNTcpPing *t = [[QNNTcpPing alloc] init:host
                                        port:port
                                      output:output
                                    complete:complete
                                       count:count];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        [t run];
    });
    return t;
}

- (void)stop {
    _stopped = YES;
}

@end
