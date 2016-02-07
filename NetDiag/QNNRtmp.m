//
//  QNNRtmp.m
//  NetDiag
//
//  Created by bailong on 16/1/26.
//  Copyright © 2016年 Qiniu Cloud Storage. All rights reserved.
//

#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <netdb.h>

#include <netinet/tcp.h>
#include <netinet/in.h>

#import "QNNRtmp.h"

#define RTMP_SIG_SIZE 1536

int PILI_RTMPSockBuf_Fill(PILI_RTMPSockBuf *sb)
{
    int nBytes;
    
    if (!sb->sb_size){
        sb->sb_start = sb->sb_buf;
    }
    
    while (1)
    {
        nBytes = sizeof(sb->sb_buf) - sb->sb_size - (sb->sb_start - sb->sb_buf);
        {
            nBytes = recv(sb->sb_socket, sb->sb_start + sb->sb_size, nBytes, 0);
        }
        if (nBytes != -1)
        {
            sb->sb_size += nBytes;
        }else{
            int sockerr = errno;
            RTMP_Log(RTMP_LOGDEBUG, "%s, recv returned %d. GetSockError(): %d (%s)",
                     __FUNCTION__, nBytes, sockerr, strerror(sockerr));
            if (sockerr == EINTR){
                continue;
            }
            
            if (sockerr == EWOULDBLOCK || sockerr == EAGAIN){
                sb->sb_timedout = TRUE;
                nBytes = 0;
            }
        }
        break;
    }
    
    return nBytes;
}

static int readAll(int sock, char *buffer, int n){
    int nOriginalSize = n;
    int avail;
    char *ptr;
    
    ptr = buffer;
    while (n > 0){
        int nBytes = 0, nRead;
        avail = r->m_sb.sb_size;
        if (avail == 0){
            if (PILI_RTMPSockBuf_Fill(&r->m_sb) < 1){
                if (!r->m_sb.sb_timedout) {
                    PILI_RTMP_Close(r, NULL);
                } else {
                    RTMPError error = {0};
                    
                    char msg[100];
                    memset(msg, 0, 100);
                    strcat(msg, "PILI_RTMP socket timeout");
                    RTMPError_Alloc(&error, strlen(msg));
                    error.code = RTMPErrorSocketTimeout;
                    strcpy(error.message, msg);
                    
                    PILI_RTMP_Close(r, &error);
                    
                    RTMPError_Free(&error);
                }
                
                return 0;
            }
            avail = r->m_sb.sb_size;
        }
        nRead = ((n < avail) ? n : avail);
        if (nRead > 0)
        {
            memcpy(ptr, r->m_sb.sb_start, nRead);
            r->m_sb.sb_start += nRead;
            r->m_sb.sb_size -= nRead;
            nBytes = nRead;
            r->m_nBytesIn += nRead;
            if (r->m_bSendCounter && r->m_nBytesIn > r->m_nBytesInSent + r->m_nClientBW / 2){
                SendBytesReceived(r, NULL);
            }
        }
        /*RTMP_Log(RTMP_LOGDEBUG, "%s: %d bytes\n", __FUNCTION__, nBytes); */
        
        if (nBytes == 0)
        {
            RTMP_Log(RTMP_LOGDEBUG, "%s, PILI_RTMP socket closed by peer", __FUNCTION__);
            /*goto again; */
            RTMPError error = {0};
            
            char msg[100];
            memset(msg, 0, 100);
            strcat(msg, "PILI_RTMP socket closed by peer. ");
            RTMPError_Alloc(&error, strlen(msg));
            error.code = RTMPErrorSocketClosedByPeer;
            strcpy(error.message, msg);
            
            PILI_RTMP_Close(r, &error);
            
            RTMPError_Free(&error);
            break;
        }
        
        n -= nBytes;
        ptr += nBytes;
    }
    
    return nOriginalSize - n;
}

static int writeAll(int sock, const char *buffer, int n){
    const char *ptr = buffer;
    
    while (n > 0){
        int nBytes = send(sock, buffer, len, 0);
        if (nBytes < 0)
        {
            int sockerr = errno;
            if (sockerr == EINTR ){
                continue;
            }
            return sockerr;
        }
        
        if (nBytes == 0){
            break;
        }
        
        n -= nBytes;
        ptr += nBytes;
    }
    
    return ptr-buffer;
}

static int HandShake(int sock){
    int i;
    uint32_t uptime, suptime;
    int bMatch;
    char type;
    char clientbuf[RTMP_SIG_SIZE + 1], *clientsig = clientbuf + 1;
    char serversig[RTMP_SIG_SIZE];
    
    clientbuf[0] = 0x03;		/* not encrypted */
    
    uptime = htonl(PILI_RTMP_GetTime());
    memcpy(clientsig, &uptime, 4);
    
    memset(&clientsig[4], 0, 4);
    
    for (i = 8; i < RTMP_SIG_SIZE; i++){
        clientsig[i] = (char)(rand() % 256);
    }
    int code = writeAll(r, clientbuf, RTMP_SIG_SIZE + 1)<0;
    if (code < 0){
        return code;
    }
    
    if (ReadN(r, &type, 1) != 1)	/* 0x03 or 0x06 */{
        return FALSE;
    }
    
    
    RTMP_Log(RTMP_LOGDEBUG, "%s: Type Answer   : %02X", __FUNCTION__, type);
    
    if (type != clientbuf[0]){
        RTMP_Log(RTMP_LOGWARNING, "%s: Type mismatch: client sent %d, server answered %d",
                 __FUNCTION__, clientbuf[0], type);
    }

    
    if (ReadN(r, serversig, RTMP_SIG_SIZE) != RTMP_SIG_SIZE){
        return FALSE;
    }
    
    /* decode server response */
    
    memcpy(&suptime, serversig, 4);
    suptime = ntohl(suptime);
    
    RTMP_Log(RTMP_LOGDEBUG, "%s: Server Uptime : %d", __FUNCTION__, suptime);
    RTMP_Log(RTMP_LOGDEBUG, "%s: FMS Version   : %d.%d.%d.%d", __FUNCTION__,
             serversig[4], serversig[5], serversig[6], serversig[7]);
    
    /* 2nd part of handshake */
    if (!WriteN(r, serversig, RTMP_SIG_SIZE, error)){
        return FALSE;
    }
    
    if (ReadN(r, serversig, RTMP_SIG_SIZE) != RTMP_SIG_SIZE){
        return FALSE;
    }
    
    bMatch = (memcmp(serversig, clientsig, RTMP_SIG_SIZE) == 0);
    if (!bMatch){
        RTMP_Log(RTMP_LOGWARNING, "%s, client signature does not match!", __FUNCTION__);
    }
    return TRUE;
}

@interface QNNRtmpHandshakeResult()

-(instancetype)init:(NSInteger)code
                max:(NSTimeInterval)maxTime
                min:(NSTimeInterval)minTime
                avg:(NSTimeInterval)avgTime
              count:(NSInteger)count;
@end

@implementation QNNRtmpHandshakeResult


-(NSString*) description{
    if (_code == 0) {
        return [NSString stringWithFormat:@"tcp connect min/avg/max = %f/%f/%fms", _minTime, _avgTime, _maxTime];
    }
    return [NSString stringWithFormat:@"tcp connect failed %d", _code];
}

-(instancetype)init:(NSInteger)code
                max:(NSTimeInterval)maxTime
                min:(NSTimeInterval)minTime
                avg:(NSTimeInterval)avgTime
              count:(NSInteger)count{
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

@interface QNNRtmpHandshake ()

@property (readonly) NSString* host;
@property (readonly) NSUInteger port;
@property (readonly) id<QNNOutputDelegate> output;
@property (readonly) QNNRtmpHandshakeCompleteHandler complete;
@property (readonly) NSInteger interval;
@property (readonly) NSInteger count;
@property (atomic) BOOL stopped;
@property NSUInteger index;
@end

@implementation QNNRtmpHandshake

-(instancetype) init:(NSString*)host
                port:(NSInteger)port
              output:(id<QNNOutputDelegate>)output
            complete:(QNNRtmpHandshakeCompleteHandler)complete
               count:(NSInteger)count{
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

-(void) run{
    [self.output write:[NSString stringWithFormat:@"connect to host %@:%d ...\n", _host, _port]];
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
        [self.output write:[NSString stringWithFormat:@"connect to ip %s:%d ...\n", inet_ntoa(addr.sin_addr), _port]];
    }
    
    NSTimeInterval* intervals = (NSTimeInterval*)malloc(sizeof(NSTimeInterval)*_count);
    NSInteger index = 0;
    int r = 0;
    do {
        NSDate* t1 = [NSDate date];
        r = [self connect:&addr];
        NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:t1];
        intervals[_index] = duration;
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
            _complete([self buildResult:code durations:intervals count:index]);
        });
    }
    free(intervals);
}

-(QNNRtmpHandshakeResult*)buildResult:(NSInteger)code
                      durations:(NSTimeInterval*)durations
                          count:(NSInteger)count{
    if (code < 0) {
        return [[QNNRtmpHandshakeResult alloc] init:code max:0 min:0 avg:0 count:1];
    }
    NSTimeInterval max = 0;
    NSTimeInterval min = 10000000;
    NSTimeInterval sum = 0;
    for (int i = 0; i<count; i++) {
        if (durations[i]>max) {
            max = durations[i];
        }
        if (durations[i]<min) {
            min = durations[i];
        }
        sum += durations[i];
    }
    NSTimeInterval avg = sum/count;
    return [[QNNRtmpHandshakeResult alloc]init:0 max:max min:min avg:avg count:count];
}

-(NSInteger) connect:(struct sockaddr_in*) addr{
    int sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (sock == -1) {
        return errno;
    }
    int on = 1;
    setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &on, sizeof(on));
    setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, (char *) &on, sizeof(on));
    
    struct timeval timeout;
    timeout.tv_sec = 10;
    timeout.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (char *)&timeout, sizeof(timeout));
    setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, (char *)&timeout, sizeof(timeout));
    
    if (connect(sock, (struct sockaddr *)addr, sizeof(struct sockaddr)) < 0){
        int err =errno;
        close(sock);
        return err;
    }
    return 0;
}

-(NSInteger)handshake:(struct sockaddr_in*) addr{
    NSInteger err = [self connect:addr];
    if (err != 0) {
        return err;
    }
    
    
}

+(instancetype) start:(NSString*)host
               output:(id<QNNOutputDelegate>)output
             complete:(QNNRtmpHandshakeCompleteHandler)complete{
    return  [QNNRtmpHandshake start:host port:80  count:3 output:output complete:complete];
}

+(instancetype) start:(NSString*)host
                 port:(NSUInteger)port
                count:(NSInteger)count
               output:(id<QNNOutputDelegate>)output
             complete:(QNNRtmpHandshakeCompleteHandler)complete;{
    QNNRtmpHandshake* t = [[QNNRtmpHandshake alloc] init:host
                                        port:port
                                      output:output
                                    complete:complete
                                       count:count];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        [t run];
    });
    return t;
}

-(void)stop{
    _stopped = YES;
}

@end