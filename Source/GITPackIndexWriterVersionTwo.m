//
//  GITPackIndexWriterVersionTwo.m
//  Git.framework
//
//  Created by Geoff Garside on 05/02/2011.
//  Copyright 2011 Geoff Garside. All rights reserved.
//

#import "GITPackIndexWriterVersionTwo.h"
#import "GITPackIndexWriter+Shared.h"
#import "GITPackIndexWriterObject.h"
#import "GITPackIndexVersionTwo.h"
#import "GITObjectHash.h"
#import "NSData+CRC32.h"


@interface GITPackIndexWriterVersionTwo ()
@property (retain) NSMutableArray *objects;
@property (retain) NSMutableData *extOffsets;
@property (copy) NSData *packChecksum;
@end

@implementation GITPackIndexWriterVersionTwo
@synthesize objects, extOffsets, packChecksum;

- (id)init {
    if ( ![super init] )
        return nil;

    objectsWritten = 0;
    CC_SHA1_Init(&ctx);
    memset(fanoutTable, 0, sizeof(fanoutTable));

    self.objects = [NSMutableArray array];
    self.extOffsets = [NSMutableData data];

    return self;
}

- (void)dealloc {
    self.objects = nil;
    self.extOffsets = nil;
    self.packChecksum = nil;
    [super dealloc];
}

- (uint32_t *)fanoutTable {
    return fanoutTable;
}

#pragma mark Checksumming writer methods
- (NSInteger)stream: (NSOutputStream *)stream write: (const uint8_t *)buffer maxLength: (NSUInteger)length {
    CC_SHA1_Update(&ctx, buffer, length);
    return [stream write:buffer maxLength:length];
}

- (NSInteger)stream: (NSOutputStream *)stream writeData: (NSData *)data {
    return [self stream:stream write:(uint8_t *)[data bytes] maxLength:[data length]];
}

- (NSInteger)writeChecksumToStream: (NSOutputStream *)stream {
    unsigned char checksum[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1_Final(checksum, &ctx);

    return [stream write:(uint8_t *)checksum maxLength:CC_SHA1_DIGEST_LENGTH];
}

#pragma mark Object Addition Methods
- (void)addObjectWithName: (GITObjectHash *)sha1 andData: (NSData *)data atOffset: (NSUInteger)offset {
    [self addObjectHashToFanoutTable:sha1];

    GITPackIndexWriterObject *obj = [GITPackIndexWriterObject indexWriterObjectWithName:sha1 atOffset:offset];
    [obj setCRC32:[data crc32]];
    [objects addObject:obj];
}

- (void)addPackChecksum: (NSData *)packChecksumData {
    self.packChecksum = packChecksumData;
}

#pragma mark Helper Methods
- (NSData *)indexHeaderData {
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:8];
    [data appendBytes:(void *)GITPackIndexVersionDiscriminator length:4];
    [data appendBytes:(void *)GITPackIndexVersionTwoVersionBytes length:4];

    NSData *d = [[data copy] autorelease];
    [data release];
    return d;
}

#pragma mark Writer Methods
- (NSInteger)writeHeaderToStream: (NSOutputStream *)stream {
    return [self stream:stream writeData:[self indexHeaderData]];
}

- (NSInteger)writeObjectNameToStream: (NSOutputStream *)stream {
    GITPackIndexWriterObject *obj = [objects objectAtIndex:objectsWritten++];
    return [self stream:stream writeData:[[obj sha1] packedData]];
}

- (NSInteger)writeCRC32ValueToStream: (NSOutputStream *)stream {
    GITPackIndexWriterObject *obj = [objects objectAtIndex:objectsWritten++];

    uint32_t crc32 = CFSwapInt32HostToBig([obj crc32]);
    return [self stream:stream write:(uint8_t *)&crc32 maxLength:sizeof(crc32)];
}

- (NSInteger)writeOffsetValueToStream: (NSOutputStream *)stream {
    GITPackIndexWriterObject *obj = [objects objectAtIndex:objectsWritten++];

    if ( [obj offset] > (1 << 31) ) {       // extended offset
        uint64_t v = CFSwapInt64HostToBig((uint64_t)[obj offset]);
        uint32_t o = [extOffsets length] / 8.0;
        [extOffsets appendBytes:(void *)&v length:sizeof(v)];
        return [self stream:stream write:(uint8_t *)&o maxLength:sizeof(o)];
    }

    uint32_t v = CFSwapInt32HostToBig((uint32_t)[obj offset]);
    return [self stream:stream write:(uint8_t *)&v maxLength:sizeof(v)];
}

- (NSInteger)writeExtendedOffsetsToStream: (NSOutputStream *)stream {
    return [self stream:stream writeData:extOffsets];
}

- (NSInteger)writePackChecksumToStream: (NSOutputStream *)stream {
    return [self stream:stream writeData:packChecksum];
}

@end
