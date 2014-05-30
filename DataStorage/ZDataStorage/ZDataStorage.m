//
//  ZDataStorage.m
//  DataStorage
//
//  Created by kyoshikawa on 14/5/29.
//  Copyright (c) 2014 Electricwoods LLC. All rights reserved.
//

#import "ZDataStorage.h"
#import "NSFileHandle+Z.h"
#import "NSData+CRC32.h"
#import "NSData+SHA1.h"
#import <CommonCrypto/CommonDigest.h>
#include <uuid/uuid.h>


#if DEBUG && 0
	#define YLog(...) NSLog(__VA_ARGS__)
#else
	#define YLog(...)
#endif

#define SCRAMBLE_KEY	0x55

#define CFLog(format, ...) CFShow((__bridge void *)[NSString stringWithFormat:format, ## __VA_ARGS__])

//
//	struct ZDataStorageHeader
//

struct ZDataStorageHeader
{
	uint32_t file_signature;					// +0
	uint32_t file_format_version;
	uint32_t app_format_version;
	uint32_t app_tag;

	uint64_t directory_offset;					// +16
	uint64_t deleted_length;

	CFUUIDBytes uuid;							// +32
	uint32_t reserved1[4];						// +48

	ZDataStorageAppSignature app_signature;		// +64
};
typedef struct ZDataStorageHeader ZDataStorageHeader;

enum
{
	ZDataStorageChunkTypeDirectory = '{--}',
	ZDataStorageChunkTypeData = '<-->',
};

//
//	ZDataStorage ()
//

@interface ZDataStorage ()
{
	NSString *_path;
	BOOL _readonly;
	NSFileHandle *_fileHandle;
	BOOL _prepared;
	uint64_t _directoryOffset;
	NSMutableDictionary *_directory;
	BOOL _needsSave;
	uint8_t _keys[CC_SHA1_DIGEST_LENGTH];
}
@property (readonly) NSFileHandle *fileHandle;
@property (readonly) NSMutableDictionary *directory;
@property (assign) NSDictionary *directoryBackup;
@property (assign) uint64_t writingOffset;

@end


//
//	ZDataStorage
//

@implementation ZDataStorage

+ (NSMapTable *)cache
{
	static NSMapTable *_cache = nil;
	if (!_cache) {
		_cache = [NSMapTable strongToWeakObjectsMapTable];
	}
	return _cache;
}


+ (id)dataStorageWithPath:(NSString *)path readonly:(BOOL)readonly
{
	@synchronized(self) {
		NSString *key = [path stringByAbbreviatingWithTildeInPath];
		ZDataStorage *dataStorage = [self.cache objectForKey:key];
		if (!dataStorage) {
			dataStorage = [[ZDataStorage alloc] initWithPath:path readonly:readonly];
			[self.cache setObject:dataStorage forKey:key];
		}
		NSParameterAssert(dataStorage.readonly == readonly);
		return dataStorage;
	}
}

- (id)initWithPath:(NSString *)path readonly:(BOOL)readonly
{
	if (self = [super init]) {
		_path = path;
		_readonly = readonly;
		self.file_signature = 'ZDAT';
		self.file_format_version = 0x00010001;
	}
	return self;
}

- (void)dealloc
{
	[self close];
}

- (NSFileHandle *)fileHandle
{
	if (!_fileHandle) {
		NSError *error = nil;
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSString *directory = [_path stringByDeletingLastPathComponent];
		[fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error];
		if (error) NSLog(@"failed creating direcctory: %@", error);
		if (_readonly) {
			_fileHandle = [NSFileHandle fileHandleForReadingAtPath:_path];
		}
		else {
			if (![fileManager fileExistsAtPath:_path]) {
				YLog(@"creating file at %@", _path);
				[fileManager createFileAtPath:_path contents:nil attributes:nil];
			}
			_fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:_path];
		}
	}
	return _fileHandle;
}

#pragma mark -

- (void)setPassword:(NSString *)password
{
	bzero(_keys, sizeof(_keys));
	if (password) {
		NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
		NSData *sha1 = [passwordData SHA1];
		NSParameterAssert(sha1.length == CC_SHA1_DIGEST_LENGTH);
		uint8_t *bytes = (uint8_t *)sha1.bytes;
		for (int index = 0 ; index < CC_SHA1_DIGEST_LENGTH ; index++) {
			_keys[index] = bytes[index];
		}
	}
}

- (NSString *)directoryBackupPath
{
	return [_path stringByAppendingString:@"~"];
}

- (NSDictionary *)directoryBackup
{
	NSDictionary *dictionary = nil;
	NSString *directoryBackupPath = self.directoryBackupPath;
	if ([[NSFileManager defaultManager] fileExistsAtPath:directoryBackupPath]) {
		NSError *error = nil;
		NSMutableData *data = [NSMutableData dataWithContentsOfFile:directoryBackupPath];
		dictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
		if (error) NSLog(@"failed decoding catalog backup JSON: %@", error);
	}
	return dictionary;
}

- (void)setDirectoryBackup:(NSDictionary *)directoryBackup
{
	NSError *error = nil;
	NSString *directoryBackupPath = self.directoryBackupPath;
	if (directoryBackup) {
		NSData *data = [NSJSONSerialization dataWithJSONObject:directoryBackup options:0 error:&error];
		if (error) NSLog(@"failed encoding catalog backup JSON: %@", error);
		[data writeToFile:directoryBackupPath atomically:YES];
	}
	else {
		if ([[NSFileManager defaultManager] fileExistsAtPath:directoryBackupPath]) {
			[[NSFileManager defaultManager] removeItemAtPath:directoryBackupPath error:&error];
			if (error) NSLog(@"failed deleting catalog backup: %@", error);
		}
	}
}

- (NSMutableDictionary *)directory
{
	if (!_directory) {
		_directory = [NSMutableDictionary dictionary];

		[self readStorageHeader];

		NSDictionary *directoryBackup = self.directoryBackup;
		if (directoryBackup) {
			// likely crashed last time, then use backup
			[_directory setDictionary:directoryBackup];

			// so, anything after directoryOffset may be overwritten last time (equivalent to rollback)
			self.writingOffset = self.directoryOffset;
		}
		else {
			NSError *error = nil;
			uint64_t offset = self.directoryOffset;
			NSParameterAssert(offset > 0);
			[self.fileHandle seekToFileOffset:offset];

			uint32_t type;
			NSData *data = [self readChunkWithType:&type];
			NSParameterAssert(type == ZDataStorageChunkTypeDirectory);
			NSDictionary *directory = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
			if (error) NSLog(@"failed decoding directory JSON: %@", error);
			if (!_readonly) {
				// make a backup of directory
				self.directoryBackup = directory;
			}
			[_directory setDictionary:directory];
		}
	}
	return _directory;
}

- (NSArray *)allKeys
{
	return [self.directory.allKeys copy];
}

- (void)setAppSignature:(NSString *)appSignature
{
	ZDataStorageAppSignature signature;
	bzero(&signature, sizeof(signature));
	memcpy(&signature, [appSignature UTF8String], sizeof(signature));
	self.app_signature = signature;
}

#pragma mark -

- (void)readStorageHeader
{
	if (!_prepared) {
		ZDataStorageHeader header;
		bzero(&header, sizeof(ZDataStorageHeader));

		[self.fileHandle seekToEndOfFile];
		uint64_t fileLength = [self.fileHandle offsetInFile];

		// file length is longer than header size
		if (fileLength >= sizeof(ZDataStorageHeader)) {
			YLog(@"reading header");
			[self.fileHandle seekToFileOffset:0];
			NSData *headerData = [self.fileHandle readDataOfLength:sizeof(ZDataStorageHeader)];
			ZDataStorageHeader *headerPtr = (ZDataStorageHeader *)headerData.bytes;
			self.file_signature = CFSwapInt32BigToHost(headerPtr->file_signature);
			self.file_format_version = CFSwapInt32BigToHost(headerPtr->file_format_version);
			self.app_format_version = CFSwapInt32BigToHost(headerPtr->app_format_version);
			self.uuid = headerPtr->uuid;
			self.app_signature = headerPtr->app_signature;
			self.directoryOffset = CFSwapInt64BigToHost(headerPtr->directory_offset);
			self.deletedLength = CFSwapInt64BigToHost(headerPtr->deleted_length);
			self.writingOffset = _directoryOffset;
			_prepared = YES;
		}

		else if (!_readonly && fileLength == 0) {
			YLog(@"creating header size=%ld", sizeof(ZDataStorageHeader));
			CFUUIDRef uuidRef = CFUUIDCreate(NULL);
			self.uuid = CFUUIDGetUUIDBytes(uuidRef);
			if (uuidRef) CFRelease(uuidRef);

			[self.fileHandle seekToFileOffset:0];
			header.file_signature = CFSwapInt32HostToBig('ZDAT');
			header.file_format_version = CFSwapInt32HostToBig(0x00020001);
			header.app_format_version = CFSwapInt32HostToBig(header.app_format_version);
			header.directory_offset = CFSwapInt64HostToBig(sizeof(ZDataStorageHeader));
			header.deleted_length = CFSwapInt32HostToBig(0);
			header.uuid = self.uuid;
			header.app_signature = self.app_signature;
			[self.fileHandle writeBytes:&header length:sizeof(header)];
			self.directoryOffset = sizeof(ZDataStorageHeader);
			self.writingOffset = self.directoryOffset;
			self.deletedLength = header.deleted_length;

			NSError *error = nil;
			NSData *data = [NSJSONSerialization dataWithJSONObject:@{} options:0 error:&error];
			[self writeChunk:data type:ZDataStorageChunkTypeDirectory];
			_prepared = YES;
		}
	}
}

- (void)writeStorageHeader
{
	ZDataStorageHeader header;
	bzero(&header, sizeof(ZDataStorageHeader));
	header.file_signature = CFSwapInt32HostToBig(self.file_signature);
	header.file_format_version = CFSwapInt32HostToBig(self.file_format_version);
	header.app_format_version = CFSwapInt32HostToBig(self.app_format_version);
	header.app_tag = CFSwapInt32HostToBig(self.app_tag);
	header.directory_offset = CFSwapInt64HostToBig(self.directoryOffset);
	header.deleted_length = CFSwapInt64HostToBig(self.deletedLength);
	header.uuid = self.uuid;
	header.app_signature = self.app_signature;
	YLog(@"header: %@", [NSData dataWithBytes:&header length:sizeof(header)]);
	[self.fileHandle seekToFileOffset:0];
	[self.fileHandle writeBytes:&header length:sizeof(header)];
}


#pragma mark -

- (NSData *)readChunkWithType:(uint32_t *)type
{
	NSParameterAssert(type);
	*type = CFSwapInt32BigToHost([self.fileHandle readInt32]);
	uint32_t chunkLength = CFSwapInt32BigToHost([self.fileHandle readInt32]);
	uint32_t crc32 = CFSwapInt32BigToHost([self.fileHandle readInt32]);
	NSData *data = [self.fileHandle readDataOfLength:chunkLength];
	return (data.CRC32 == crc32) ? data : nil;
}

- (void)writeChunk:(NSData *)data type:(uint32_t)type
{
	NSParameterAssert(data);
	[self.fileHandle writeInt32:CFSwapInt32HostToBig(type)];
	[self.fileHandle writeInt32:CFSwapInt32HostToBig(data.length)];
	[self.fileHandle writeInt32:CFSwapInt32HostToBig(data.CRC32)];
	[self.fileHandle writeData:data];
}

- (void)peekChunkType:(uint32_t *)type length:(uint32_t *)length crc32:(uint32_t *)crc32
{
	*type = CFSwapInt32BigToHost([self.fileHandle readInt32]);
	*length = CFSwapInt32BigToHost([self.fileHandle readInt32]);
	*crc32 = CFSwapInt32BigToHost([self.fileHandle readInt32]);
}


#pragma mark -

- (NSData *)dataForKey:(NSString *)key
{
	@synchronized(self) {
		NSNumber *offset = [self.directory valueForKey:key];
		if (offset) {
			uint32_t type;
			[self.fileHandle seekToFileOffset:offset.longLongValue];
			NSData *data = [self readChunkWithType:&type];
			NSParameterAssert(type == ZDataStorageChunkTypeData);
			return [self decodedData:data];
		}
		return nil;
	}
}

- (void)setData:(NSData *)data forKey:(NSString *)key
{
	@synchronized(self) {
		NSParameterAssert(!_readonly);
		NSNumber *offset = [self.directory valueForKey:key];
		if (offset) { // to overwrite
			uint32_t chunkType;
			uint32_t chunkLength;
			uint32_t crc32;
			[self.fileHandle seekToFileOffset:offset.longLongValue];
			[self peekChunkType:&chunkType length:&chunkLength crc32:&crc32];
			if (data) { // about to override
				NSData *encodedData = [self encodedData:data];
				if (chunkLength == encodedData.length && crc32 == encodedData.CRC32) {
					NSData *chunkData = [self.fileHandle readDataOfLength:chunkLength];
					if ([encodedData isEqualToData:chunkData]) {
						return; // same data no need to write
					}
				}
				[self.fileHandle seekToFileOffset:self.writingOffset];
				[self writeChunk:encodedData type:ZDataStorageChunkTypeData];
				[self.directory setValue:[NSNumber numberWithLongLong:self.writingOffset] forKey:key];
				self.writingOffset = [self.fileHandle offsetInFile];
			}
			else { // to delete
				[self.directory removeObjectForKey:key];
			}
			uint32_t deletedBytes = chunkLength + sizeof(chunkType) + sizeof(chunkLength) + sizeof(crc32);
			self.deletedLength += deletedBytes;
		}
		else { // to append
			NSData *encodedData = [self encodedData:data];
			[self.fileHandle seekToFileOffset:self.writingOffset];
			[self writeChunk:encodedData type:ZDataStorageChunkTypeData];
			[self.directory setValue:[NSNumber numberWithLongLong:self.writingOffset] forKey:key];
			self.writingOffset = [self.fileHandle offsetInFile];
		}
		_needsSave = YES;
	}
}

- (void)removeDataForKey:(NSString *)key;
{
	[self setData:nil forKey:key];
}

#pragma mark -

- (NSString *)stringForKey:(NSString *)key
{
	NSData *data = [self dataForKey:key];
	return [[NSString alloc] initWithBytes:data.bytes length:data.length encoding:NSUTF8StringEncoding];
}

- (void)setString:(NSString *)string forKey:(NSString *)key
{
	NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
	[self setData:data forKey:key];
}

- (void)removeStringForKey:(NSString *)key;
{
	[self setData:nil forKey:key];
}

#pragma mark -

- (id)objectForKey:(NSString *)key
{
	NSError *error = nil;
	NSData *data = [self dataForKey:key];
	if (data) {
		id object = [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:&error];
		if (error) NSLog(@"failed decoding property list serialization: %@", error);
		return object;
	}
	return nil;
}

- (void)setObject:(id)object forKey:(NSString *)key
{
	if (object) {
		NSError *error = nil;
		NSData *data = [NSPropertyListSerialization dataWithPropertyList:object format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
		if (error) NSLog(@"failed encoding property list serialization: %@", error);
		[self setData:data forKey:key];
	}
	else {
		[self setData:nil forKey:key];
	}
}

- (void)removeObjectForKey:(NSString *)key;
{
	[self setData:nil forKey:key];
}

- (id)objectForKeyedSubscript:(id)key
{
	return [self objectForKey:key];
}

- (void)setObject:(id)object forKeyedSubscript:(id)key
{
	[self setObject:object forKey:key];
}

#pragma mark -

- (void)commit
{
	@synchronized(self) {
		NSError *error = nil;
		NSData *data = [NSJSONSerialization dataWithJSONObject:self.directory options:0 error:&error];
		if (error) NSLog(@"failed JSON serialization: %@", error);
		self.directoryOffset = self.writingOffset;
		[self.fileHandle seekToFileOffset:self.directoryOffset];
		[self writeChunk:data type:ZDataStorageChunkTypeDirectory];
		uint64_t offset = [self.fileHandle offsetInFile];
		[self.fileHandle truncateFileAtOffset:offset];

		[self writeStorageHeader];
		_needsSave = NO;
	}
}

- (void)rollback
{
	@synchronized(self) {
		NSDictionary *directory = self.directoryBackup;
		if (directory) {
			NSError *error = nil;
			NSData *data = [NSJSONSerialization dataWithJSONObject:directory options:0 error:&error];
			if (error) NSLog(@"failed JSON serialization: %@", error);
			[self.fileHandle seekToFileOffset:self.directoryOffset];
			[self writeChunk:data type:ZDataStorageChunkTypeDirectory];
			uint64_t offset = [self.fileHandle offsetInFile];
			[self.fileHandle truncateFileAtOffset:offset];
		}
		_needsSave = NO;
	}
}

- (void)close
{
	if (!_prepared) {
		[self readStorageHeader];
	}
	if (_needsSave) {
		[self commit];
	}

	[_fileHandle closeFile], _fileHandle = nil;
	self.directoryBackup = nil;
	_directory = nil;
	_prepared = NO;
}

#pragma mark -

- (void)archiveDirectoryAtPath:(NSString *)path
{
	BOOL isDir;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:path isDirectory:&isDir] && isDir) {
		NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:path];
		NSString *file = nil;
		while (file = [enumerator nextObject]) {
			NSString *filename = [file lastPathComponent];
			if (![filename hasPrefix:@"."]) {
				NSString *filepath = [path stringByAppendingPathComponent:file];
				if ([fileManager fileExistsAtPath:filepath isDirectory:&isDir] && !isDir) {
					NSError *error = nil;
					NSDictionary *attributes = [fileManager attributesOfItemAtPath:filepath error:&error];
					NSNumber *fileLength = attributes[NSFileSize];
					if (fileLength.longLongValue < LONG_MAX) {
						NSLog(@"saving file: %@", file);
						NSData *data = [NSData dataWithContentsOfFile:filepath];
						[self setData:data forKey:file];
					}
					else {
						NSLog(@"too large to save: %@", file);
					}
				}
			}
		}
	}
}

- (void)unarchiveDirectoryToPath:(NSString *)path
{
	NSError *error = nil;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	[fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
	if (error) NSLog(@"failed creating intermediate directories: %@", error);

	for (NSString *file in self.directory.allKeys) {
		if (![file hasPrefix:@"."]) {
			NSString *filepath = [path stringByAppendingPathComponent:file];
			NSString *directory = [filepath stringByDeletingLastPathComponent];
			[fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error];
			if (error) NSLog(@"failed creating intermediate directories: %@", error);
			NSData *data = [self dataForKey:file];
			[data writeToFile:filepath atomically:YES];
		}
	}
}

#pragma mark -

- (NSData *)encodedData:(NSData *)data
{
	int keyLength = CC_SHA1_DIGEST_LENGTH;
	NSMutableData *mutableData = [NSMutableData dataWithData:data];
	int length = mutableData.length;
	uint8_t *ptr = mutableData.mutableBytes;
	for (int index = 0 ; index < length ; index++, ptr++) {
		uint8_t key = _keys[index % keyLength];
		*ptr = *ptr ^ key ^ SCRAMBLE_KEY;
	}
	return mutableData;
}

- (NSData *)decodedData:(NSData *)data
{
	int keyLength = CC_SHA1_DIGEST_LENGTH;
	NSMutableData *mutableData = [NSMutableData dataWithData:data];
	int length = mutableData.length;
	uint8_t *ptr = mutableData.mutableBytes;
	for (int index = 0 ; index < length ; index++, ptr++) {
		uint8_t key = _keys[index % keyLength];
		*ptr = *ptr ^ key ^ SCRAMBLE_KEY;
	}
	return mutableData;
}

#pragma mark -

- (void)vacuum
{
	NSAssert(NO, @"%s: not implemented yet!", __FUNCTION__);

	/*
	NSString *filename = [_path lastPathComponent];
	NSString *extension = [_path pathExtension];
	NSString *temporaryFile = [NSTemporaryDirectory() stringByAppendingString:[[NSUUID UUID] UUIDString]];
	NSString *destinationPath = [temporaryFile stringByAppendingPathExtension:extension];
	[[NSFileManager defaultManager] createFileAtPath:destinationPath contents:nil attributes:nil];
	ZDataStorage *destinationStorage = [ZDataStorage dataStorageWithPath:destinationPath readonly:NO];
	destinationStorage.file_signature = self.file_signature;
	destinationStorage.file_format_version = self.file_format_version;
	destinationStorage.app_format_version = self.app_format_version;
	destinationStorage.app_tag = self.app_tag;
	destinationStorage.uuid = self.uuid;
	destinationStorage.app_signature = self.app_signature;

	for (int index = 0 ; index < CC_SHA1_DIGEST_LENGTH ; index++) {
		destinationStorage->_keys[index] = _keys[index];
	}
	for (NSString *key in self.directory.allKeys) {
		NSData *data = [self dataForKey:key];
		[destinationStorage setData:data forKey:key];
	}
	[self close];
	[destinationStorage close];

	NSURL *sourceURL = [NSURL fileURLWithPath:_path];
	NSURL *destinationURL = [NSURL fileURLWithPath:destinationPath];

	NSError *error = nil;
	NSURL *itemURL = nil;
	[[NSFileManager defaultManager] replaceItemAtURL:sourceURL withItemAtURL:destinationURL backupItemName:nil options:0 resultingItemURL:&itemURL error:&error];
	if (error) NSLog(@"failed replacing storage file %@: %@", filename, error);

	NSLog(@"%@", self.directory.allKeys);
	*/
}

#if DEBUG
- (void)dump
{
	NSError *error = nil;

	[self.fileHandle seekToFileOffset:0];
	NSData *headerData = [self.fileHandle readDataOfLength:sizeof(ZDataStorageHeader)];
	ZDataStorageHeader *headerPtr = (ZDataStorageHeader *)headerData.bytes;
	CFLog(@"file: %@", [_path stringByAbbreviatingWithTildeInPath]);
	CFLog(@"signature: %08x", CFSwapInt32BigToHost(headerPtr->file_signature));
	CFLog(@"file_format_version: %08x", CFSwapInt32BigToHost(headerPtr->file_format_version));
	CFLog(@"app_signature: %@", [NSData dataWithBytes:&headerPtr->app_signature length:sizeof(ZDataStorageAppSignature)]);
	CFLog(@"app_format_version: %08x", CFSwapInt32BigToHost(headerPtr->app_format_version));
	CFLog(@"bytes deleted: %lld", CFSwapInt64BigToHost(headerPtr->deleted_length));
	uint64_t directoryOffset = CFSwapInt64BigToHost(headerPtr->directory_offset);
	CFLog(@"directory offset: %08llx", directoryOffset);
	CFLog(@"uuid: %@", [NSData dataWithBytes:&headerPtr->uuid length:sizeof(CFUUIDBytes)]);
	[self.fileHandle seekToFileOffset:directoryOffset];
	uint32_t type;
	NSData *directoryData = [self readChunkWithType:&type];
	NSDictionary *directory = [NSJSONSerialization JSONObjectWithData:directoryData options:0 error:&error];
	CFLog(@"directory: %@", directory);
	for (NSString *key in directory.allKeys) {
		uint64_t offset = [[directory valueForKey:key] longLongValue];
		CFLog(@"[%@] %08llx", key, offset);
		[self.fileHandle seekToFileOffset:offset];
		NSData *data = [self readChunkWithType:&type];
		NSData *decoded = [self decodedData:data];
		CFLog(@"%@", decoded);
	}
}
#endif

@end

