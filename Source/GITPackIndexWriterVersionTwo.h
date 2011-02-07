//
//  GITPackIndexWriterVersionTwo.h
//  Git.framework
//
//  Created by Geoff Garside on 05/02/2011.
//  Copyright 2011 Geoff Garside. All rights reserved.
//

#import "GITPackIndexWriter.h"
#import <CommonCrypto/CommonDigest.h>


@interface GITPackIndexWriterVersionTwo : GITPackIndexWriter {
    CC_SHA1_CTX ctx;
    uint32_t fanoutTable[256];      //!< Differs from GITPackIndex fanoutTable in that it isn't an increasing counter
    NSMutableArray *objects;
    NSInteger objectsWritten;
    NSMutableData *extOffsets;
    NSData *packChecksum;
}

@end
