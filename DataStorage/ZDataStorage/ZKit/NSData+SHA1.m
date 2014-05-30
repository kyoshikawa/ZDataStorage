//
//  NSData+SHA1.m
//  DataStorage
//
//  Created by kyoshikawa on 14/5/29.
//  Copyright (c) 2014 Electricwoods LLC. All rights reserved.
//

#import "NSData+SHA1.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSData (SHA1)

- (NSData *)SHA1
{
    unsigned char result[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1([self bytes], [self length], result);
    return [NSData dataWithBytes:result length:CC_SHA1_DIGEST_LENGTH];
}

@end
