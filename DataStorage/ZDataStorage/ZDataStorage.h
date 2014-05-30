//
//  ZDataStorage.h
//  DataStorage
//
//  Created by kyoshikawa on 14/5/29.
//  Copyright (c) 2014 Electricwoods LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


//
//	ZDataStorageAppSignature
//

struct ZDataStorageAppSignature
{
	uint8_t signature[64];
};
typedef struct ZDataStorageAppSignature ZDataStorageAppSignature;


//
//	ZDataStorage
//

@interface ZDataStorage : NSObject

@property (assign) uint32_t file_signature;
@property (assign) uint32_t file_format_version;
@property (assign) uint32_t app_format_version;
@property (assign) uint32_t app_tag;
@property (assign) uint64_t directoryOffset;
@property (assign) uint64_t deletedLength;
@property (assign) CFUUIDBytes uuid;
@property (assign) ZDataStorageAppSignature app_signature;
@property (readonly) BOOL readonly;
@property (readonly) NSArray *allKeys;

+ (id)dataStorageWithPath:(NSString *)path readonly:(BOOL)readonly;
- (id)initWithPath:(NSString *)path readonly:(BOOL)readonly;

- (void)setAppSignature:(NSString *)appSignature;
- (void)setPassword:(NSString *)password;

- (NSData *)dataForKey:(NSString *)key;
- (void)setData:(NSData *)data forKey:(NSString *)key;
- (void)removeDataForKey:(NSString *)key;

- (NSString *)stringForKey:(NSString *)key;
- (void)setString:(NSString *)string forKey:(NSString *)key;
- (void)removeStringForKey:(NSString *)key;

- (id)objectForKey:(NSString *)key;
- (void)setObject:(id)object forKey:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key;

- (id)objectForKeyedSubscript:(id)key;
- (void)setObject:(id)object forKeyedSubscript:(id)key;

- (void)close;
- (void)commit;
- (void)rollback;
- (void)vacuum;

- (void)archiveDirectoryAtPath:(NSString *)path;
- (void)unarchiveDirectoryToPath:(NSString *)path;

#if DEBUG
- (void)dump;
#endif

@end
