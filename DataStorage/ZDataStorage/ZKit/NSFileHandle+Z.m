//
//  NSFileHandle+Z.m
//  ZKit
//
//  Created by Kaz Yoshikawa on 11/02/12.
//  Copyright 2011 Electricwoods LLC. All rights reserved.
//

#import "NSFileHandle+Z.h"


//
//	NSFileHandle (Z)
//

@implementation NSFileHandle (Z)

- (void)readBytes:(void *)buffer length:(NSUInteger)length
{
	NSData *data = [self readDataOfLength:length];
	if (data.length != length) {
		[NSException raise:@"NSFileHandleReadException" format:@"Unexpected out of data"];
	}
	[data getBytes:buffer length:length];
}

- (void)writeBytes:(void *)buffer length:(NSUInteger)length
{
	[self writeData:[NSData dataWithBytes:buffer length:length]];
}

#pragma mark -

- (uint16_t)readInt16
{
	int16_t value;
	[self readBytes:&value length:sizeof(value)];
	value = (int16_t)CFSwapInt16BigToHost(value);
	return value;
}

- (uint32_t)readInt32
{
	int32_t value;
	[self readBytes:&value length:sizeof(value)];
	value = (int32_t)CFSwapInt32BigToHost(value);
	return value;
}

- (uint64_t)readInt64
{
	int64_t value = 0;
	[self readBytes:&value length:sizeof(value)];
	value = CFSwapInt64BigToHost(value);
	return value;
}

#pragma mark -

- (void)writeInt16:(uint16_t)value
{
	int16_t value16 = CFSwapInt16HostToBig(value);
	[self writeBytes:&value16 length:sizeof(value16)];
}

- (void)writeInt32:(uint32_t)value
{
	int32_t value32 = CFSwapInt32HostToBig(value);
	[self writeBytes:&value32 length:sizeof(value32)];
}

- (void)writeInt64:(uint64_t)value
{
	int64_t value64 = CFSwapInt64HostToBig(value);
	[self writeBytes:&value64 length:sizeof(value64)];
}

@end
