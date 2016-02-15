//
//  QNNPing.m
//  NetDiag
//
//  Created by bailong on 15/12/30.
//  Copyright © 2015年 Qiniu Cloud Storage. All rights reserved.
//

#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <netdb.h>

#import <netinet/tcp.h>
#import <netinet/in.h>

#include <AssertMacros.h>

#import "QNNPing.h"

@interface QNNPingResult()

-(instancetype)init:(NSInteger)code
                max:(NSTimeInterval)maxRtt
                min:(NSTimeInterval)minRtt
                avg:(NSTimeInterval)avgRtt
               loss:(double)lossRate
           interval:(NSInteger)interval
              count:(NSInteger)count;
@end

@implementation QNNPingResult

-(NSString*) description{
    if (_code == 0) {
        return [NSString stringWithFormat:@"ping %d times, min/avg/max = %f/%f/%fms loss %f", _count, _minRtt, _avgRtt, _maxRtt, _lossRate];
    }
    return [NSString stringWithFormat:@"ping failed %d", _code];
}

-(instancetype)init:(NSInteger)code
                max:(NSTimeInterval)maxRtt
                min:(NSTimeInterval)minRtt
                avg:(NSTimeInterval)avgRtt
               loss:(double)lossRate
           interval:(NSInteger)interval
              count:(NSInteger)count{
    if (self = [super init]) {
        _code = code;
        _minRtt = minRtt;
        _avgRtt = avgRtt;
        _maxRtt = maxRtt;
        _lossRate = lossRate;
        _interval = interval;
        _count = count;
    }
    return self;
}

@end

// IP header structure:

struct IPHeader {
    uint8_t versionAndHeaderLength;
    uint8_t differentiatedServices;
    uint16_t totalLength;
    uint16_t identification;
    uint16_t flagsAndFragmentOffset;
    uint8_t timeToLive;
    uint8_t protocol;
    uint16_t headerChecksum;
    uint8_t sourceAddress[4];
    uint8_t destinationAddress[4];
    // options...
    // data...
};
typedef struct IPHeader IPHeader;

check_compile_time(sizeof(IPHeader) == 20);
check_compile_time(offsetof(IPHeader, versionAndHeaderLength) == 0);
check_compile_time(offsetof(IPHeader, differentiatedServices) == 1);
check_compile_time(offsetof(IPHeader, totalLength) == 2);
check_compile_time(offsetof(IPHeader, identification) == 4);
check_compile_time(offsetof(IPHeader, flagsAndFragmentOffset) == 6);
check_compile_time(offsetof(IPHeader, timeToLive) == 8);
check_compile_time(offsetof(IPHeader, protocol) == 9);
check_compile_time(offsetof(IPHeader, headerChecksum) == 10);
check_compile_time(offsetof(IPHeader, sourceAddress) == 12);
check_compile_time(offsetof(IPHeader, destinationAddress) == 16);

typedef struct ICMPPacket{
    uint8_t     type;
    uint8_t     code;
    uint16_t    checksum;
    uint16_t    identifier;
    uint16_t    sequenceNumber;
    uint8_t     payload[0]; // data, variable length
}ICMPPacket;

enum {
    kQNNICMPTypeEchoReply   = 0,           // code is always 0
    kQNNICMPTypeEchoRequest = 8            // code is always 0
};

check_compile_time(sizeof(ICMPPacket) == 8);
check_compile_time(offsetof(ICMPPacket, type) == 0);
check_compile_time(offsetof(ICMPPacket, code) == 1);
check_compile_time(offsetof(ICMPPacket, checksum) == 2);
check_compile_time(offsetof(ICMPPacket, identifier) == 4);
check_compile_time(offsetof(ICMPPacket, sequenceNumber) == 6);

const int kQNNPacketSize = sizeof(ICMPPacket) + 100;

static uint16_t in_cksum(const void *buffer, size_t bufferLen)
// This is the standard BSD checksum code, modified to use modern types.
{
    size_t bytesLeft;
    int32_t sum;
    const uint16_t *cursor;
    union {
        uint16_t us;
        uint8_t uc[2];
    } last;
    uint16_t answer;
    
    bytesLeft = bufferLen;
    sum = 0;
    cursor = buffer;
    
    /*
     * Our algorithm is simple, using a 32 bit accumulator (sum), we add
     * sequential 16 bit words to it, and at the end, fold back all the
     * carry bits from the top 16 bits into the lower 16 bits.
     */
    while (bytesLeft > 1) {
        sum += *cursor;
        cursor += 1;
        bytesLeft -= 2;
    }
    
    /* mop up an odd byte, if necessary */
    if (bytesLeft == 1) {
        last.uc[0] = *(const uint8_t *)cursor;
        last.uc[1] = 0;
        sum += last.us;
    }
    
    /* add back carry outs from top 16 bits to low 16 bits */
    sum = (sum >> 16) + (sum & 0xffff); /* add hi 16 to low 16 */
    sum += (sum >> 16);                 /* add carry */
    answer = (uint16_t)~sum;            /* truncate to 16 bits */
    
    return answer;
}

static ICMPPacket* build_packet(uint16_t seq, uint16_t identifier){
    ICMPPacket* packet = (ICMPPacket*)calloc(kQNNPacketSize, 1);
    
    packet->type = kQNNICMPTypeEchoRequest;
    packet->code = 0;
    packet->checksum = 0;
    packet->identifier     = OSSwapHostToBigInt16(identifier);
    packet->sequenceNumber = OSSwapHostToBigInt16(seq);
    snprintf((char*)packet->payload, kQNNPacketSize - sizeof(ICMPPacket), "qiniu ping test %d", (int)seq);
    packet->checksum = in_cksum(packet, kQNNPacketSize);
    return packet;
}

@interface QNNPing ()
@property (readonly) NSString* host;
@property (nonatomic, strong) id<QNNOutputDelegate> output;
@property (readonly) QNNPingCompleteHandler complete;

@property (readonly) NSInteger interval;
@property (readonly) NSInteger count;
@property (atomic) BOOL stopped;
@end

@implementation QNNPing

-(NSInteger)sendPacket:(ICMPPacket*)packet
                  sock:(int)sock
                target:(struct sockaddr *)addr{
    int sent = sendto(sock, packet, (size_t)kQNNPacketSize, 0, addr, (socklen_t)sizeof(struct sockaddr));
    if (sent < 0) {
        return errno;
    }
    return 0;
}

-(void)run{
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = inet_addr([_host UTF8String]);
    if (addr.sin_addr.s_addr == INADDR_NONE) {
        struct hostent *host = gethostbyname([_host UTF8String]);
        if (host == NULL || host->h_addr == NULL) {
            [self.output write:@"Problem accessing the DNS"];
            if (_complete != nil) {
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    QNNPingResult* result = [[QNNPingResult alloc] init:-1006 max:0 min:0 avg:0 loss:0 interval:0 count:0];
                    _complete(result);
                });
            }
            return;
        }
        addr.sin_addr = *(struct in_addr *)host->h_addr;
        [self.output write:[NSString stringWithFormat:@"ping to ip %s ...\n", inet_ntoa(addr.sin_addr)]];
    }
    
    NSTimeInterval* durations = (NSTimeInterval*)malloc(sizeof(NSTimeInterval)*_count);
    NSInteger index = 0;
    int r = 0;
    do {
        NSDate* t1 = [NSDate date];
        r = [self connect:&addr];
        NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:t1];
        intervals[index] = duration;
        if (r == 0) {
            [self.output write:[NSString stringWithFormat:@"connected to %s:%d, %f ms\n", inet_ntoa(addr.sin_addr), _port, duration*1000]];
        }else{
            [self.output write:[NSString stringWithFormat:@"connect failed to %s:%d, %f ms, error %d\n", inet_ntoa(addr.sin_addr), _port, duration*1000, r]];
        }
        
        if (index < _count && !_stopped && r == 0) {
            [NSThread sleepForTimeInterval:0.1];
        }
    } while (++index < _count && !_stopped && r == 0);
    
    if (_complete) {
        NSInteger code = r;
        if(_stopped){
            code = kQNNRequestStoped;
        }
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            QNNPingResult result =
            _complete([self buildResult:code durations:intervals count:index]);
        });
    }
    free(durations);
}

+(instancetype) start:(NSString*)host
               output:(id<QNNOutputDelegate>)output
             complete:(QNNPingCompleteHandler)complete{
    return [QNNPing start:host output:output complete:complete interval:200 count:10];
}

+(instancetype) start:(NSString*)host
               output:(id<QNNOutputDelegate>)output
             complete:(QNNPingCompleteHandler)complete
             interval:(NSInteger)interval
                count:(NSInteger)count{
    return nil;
}

-(void)stop{
    _stopped = YES;
    return;
}

@end
