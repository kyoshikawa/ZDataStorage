//
//  NSFileHandle+Z.h
//  ZKit
//
//  Created by Kaz Yoshikawa on 11/02/12.
//  Copyright 2011 Electricwoods LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


//
//	NSFileHandle (Z)
//

@interface NSFileHandle (Z)

- (void)readBytes:(void *)buffer length:(NSUInteger)length;
- (void)writeBytes:(void *)buffer length:(NSUInteger)length;

- (uint16_t)readInt16;
- (uint32_t)readInt32;
- (uint64_t)readInt64;
- (void)writeInt16:(uint16_t)value;
- (void)writeInt32:(uint32_t)value;
- (void)writeInt64:(uint64_t)value;

@end
