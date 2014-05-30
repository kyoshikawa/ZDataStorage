//
//  NSData+CRC32.m
//  ZKit
//
//  Created by Kaz Yoshikawa on 14/5/27.
//  Copyright (c) 2014 Electricwoods LLC. All rights reserved.
//

#import "NSData+CRC32.h"
#import <zlib.h>

//
//	NSData (CRC32)
//

@implementation NSData (CRC32)

- (uint32_t)CRC32
{
	uLong crc = crc32(0L, Z_NULL, 0);
	crc = crc32(crc, [self bytes], [self length]);
	return crc;
}

@end
