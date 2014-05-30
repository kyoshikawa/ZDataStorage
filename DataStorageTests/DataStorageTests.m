//
//  DataStorageTests.m
//  DataStorageTests
//
//  Created by kyoshikawa on 14/5/29.
//  Copyright (c) 2014 Electricwoods LLC. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ZDataStorage.h"
#import "NSData+SHA1.h"

#define TEST_FILE_0 @"test0.dat"
#define TEST_FILE_1 @"test1.dat"
#define TEST_FILE_2 @"test2.dat"
#define TEST_FILE_3 @"test3.dat"
#define TEST_FILE_4 @"test4.dat"
#define TEST_FILE_5 @"test5.dat"
#define TEST_FILE_6 @"test6.dat"
#define TEST_FILE_7 @"test7.dat"

#define MAX_THREADING 4


//
//	DataStorageTests : XCTestCase
//

@interface DataStorageTests : XCTestCase

@end

//
//	DataStorageTests
//

@implementation DataStorageTests

- (void)setUp
{
	[super setUp];

	[self cleanDocumentDirectory];
}

- (void)tearDown
{
	[super tearDown];

	[self cleanDocumentDirectory];
}

- (void)cleanDocumentDirectory
{
	NSError *error = nil;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *items = [fileManager contentsOfDirectoryAtPath:self.documentDirectory error:&error];
	if (error) NSLog(@"failed to obtain items under document directory: %@", error);
	for (NSString *item in items) {
		NSString *filepath = [self.documentDirectory stringByAppendingPathComponent:item];
		[fileManager removeItemAtPath:filepath error:&error];
		if (error) NSLog(@"failed to remove item %@: %@", filepath, error);
	}
}

- (NSString *)documentDirectory
{
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

- (NSDictionary *)sampleDictionary
{
	return  @{
		@"CA": @"Canada",
		@"GB": @"United Kingdom",
		@"US": @"United States",
		@"JP": @"Japan",
		@"FR": @"France",
		@"DE": @"Germany",
		@"IT": @"Italy",
		@"ES": @"Spain",
	};
}

- (void)writeSampleToStorage:(ZDataStorage *)dataStorage
{
	NSDictionary *sampleDictionary = self.sampleDictionary;
	for (NSString *key in sampleDictionary.allKeys) {
		NSString *value = [sampleDictionary valueForKey:key];
		[dataStorage setString:value forKey:key];
	}
}

- (uint64_t)fileSizeOfPath:(NSString *)path
{
	NSError *error = nil;
	NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
	return [attributes[NSFileSize] longLongValue];
}

#pragma mark -

- (void)testBasic
{
	NSDictionary *sampleDictionary = self.sampleDictionary;

	// save items
	NSString *testfile = [self.documentDirectory stringByAppendingString:TEST_FILE_1];
	ZDataStorage *dataStorage = [ZDataStorage dataStorageWithPath:testfile readonly:NO];
	[self writeSampleToStorage:dataStorage];

	// retrieve items
	NSMutableSet *originalKeys = [NSMutableSet setWithArray:sampleDictionary.allKeys];
	for (NSString *key in dataStorage.allKeys) {
		NSData *data = [dataStorage dataForKey:key];
		NSString *destinationString = [[NSString alloc] initWithBytes:data.bytes length:data.length encoding:NSUTF8StringEncoding];
		NSString *sourceString = [sampleDictionary valueForKey:key];
		XCTAssert([destinationString isEqualToString:sourceString], @"saved and load string aren't match.");
		[originalKeys removeObject:key];
	}

	// make sure it has exact items
	XCTAssert(originalKeys.count == 0, @"missing some key-value");
}

- (void)testSaveAndRetrieve
{
	NSDictionary *sampleDictionary = self.sampleDictionary;

	NSString *testfile = [self.documentDirectory stringByAppendingString:TEST_FILE_0];
	ZDataStorage *dataStorage1 = [[ZDataStorage alloc] initWithPath:testfile readonly:NO];
	[self writeSampleToStorage:dataStorage1];
	dataStorage1 = nil;

	ZDataStorage *dataStorage2 = [[ZDataStorage alloc] initWithPath:testfile readonly:NO];
	NSMutableSet *originalKeys = [NSMutableSet setWithArray:sampleDictionary.allKeys];
	for (NSString *key in sampleDictionary.allKeys) {
		NSString *sourceString = [sampleDictionary valueForKey:key];
		NSString *destinationString = [dataStorage2 stringForKey:key];
		NSLog(@"%@ | %@", sourceString, destinationString);
		XCTAssert([destinationString isEqualToString:sourceString], @"saved and load string should be match. %@:%@", sourceString, destinationString);
		[originalKeys removeObject:key];
	}

	// make sure it has exact items
	XCTAssert(originalKeys.count == 0, @"missing some key-value");
}

- (void)testAddAndDelete
{
	NSDictionary *sampleDictionary = self.sampleDictionary;
	NSMutableDictionary *sourceDictionary = [NSMutableDictionary dictionaryWithDictionary:sampleDictionary];

	// set items
	NSString *testfile = [self.documentDirectory stringByAppendingPathComponent:TEST_FILE_2];
	ZDataStorage *dataStorage = [ZDataStorage dataStorageWithPath:testfile readonly:NO];
	[self writeSampleToStorage:dataStorage];

	// try remove some items
	[dataStorage setData:nil forKey:@"DE"];
	[dataStorage setData:nil forKey:@"ES"];
	[sourceDictionary removeObjectForKey:@"DE"];
	[sourceDictionary removeObjectForKey:@"ES"];

	NSMutableSet *originalKeys = [NSMutableSet setWithArray:sourceDictionary.allKeys];
	for (NSString *key in dataStorage.allKeys) {
		NSString *sourceString = [sourceDictionary valueForKey:key];
		NSString *destinationString = [dataStorage stringForKey:key];
		NSLog(@"[%@] %@ | %@", key, sourceString, destinationString);
		XCTAssert([destinationString isEqualToString:sourceString], @"saved and load string aren't match.");
		[originalKeys removeObject:key];
	}

	// make sure it has exact items
	XCTAssert(originalKeys.count == 0, @"missing some key-value");
}

- (void)testAddAndReplace
{
	NSString *testfile = [self.documentDirectory stringByAppendingPathComponent:TEST_FILE_3];
	ZDataStorage *dataStorage = [ZDataStorage dataStorageWithPath:testfile readonly:NO];
	[self writeSampleToStorage:dataStorage];

	[dataStorage setString:@"日本" forKey:@"JP"];
	[dataStorage setString:@"Español" forKey:@"ES"];
	[dataStorage setString:@"Deutschland" forKey:@"DE"];
	[dataStorage setString:@"Italia" forKey:@"IT"];

	XCTAssertEqualObjects([dataStorage stringForKey:@"JP"], @"日本", @"failed replacement object for key");
	XCTAssertEqualObjects([dataStorage stringForKey:@"ES"], @"Español", @"failed replacement object for key");
	XCTAssertEqualObjects([dataStorage stringForKey:@"DE"], @"Deutschland", @"failed replacement object for key");
	XCTAssertEqualObjects([dataStorage stringForKey:@"IT"], @"Italia", @"failed replacement object for key");
	XCTAssertEqualObjects([dataStorage stringForKey:@"CA"], @"Canada", @"failed replacement object for key");
	XCTAssertEqualObjects([dataStorage stringForKey:@"FR"], @"France", @"failed replacement object for key");

}

- (void)testThousands
{
	CFAbsoluteTime t = CFAbsoluteTimeGetCurrent();

	const int count = 10000;
	NSString *testfile = [self.documentDirectory stringByAppendingPathComponent:TEST_FILE_4];
	ZDataStorage *dataStorage = [ZDataStorage dataStorageWithPath:testfile readonly:NO];

	// set: value = index * 2
	for (int index = 0 ; index < count ; index++) {
		NSNumber *number = [NSNumber numberWithInteger:index];
		NSNumber *value = [NSNumber numberWithInteger:index * 2];
		[dataStorage setObject:value forKey:[number stringValue]];
	}
	// set: value = index
	for (int index = 0 ; index < count ; index++ ) {
		NSNumber *number = [NSNumber numberWithInteger:index];
		NSNumber *value = [NSNumber numberWithInteger:index];
		[dataStorage setObject:value forKey:[number stringValue]];
	}
	// make sure: value == index
	for (int index = 0 ; index < count ; index++) {
		NSNumber *number = [NSNumber numberWithInteger:index];
		NSNumber *value = [dataStorage objectForKey:[number stringValue]];
		XCTAssert(value.integerValue == index, @"expected object value to be equal to index");
	}

	NSLog(@"time=%f", CFAbsoluteTimeGetCurrent() - t);
}

- (void)testMultithreading
{
	NSString *testfile = [self.documentDirectory stringByAppendingPathComponent:TEST_FILE_5];
	ZDataStorage *dataStorage = [ZDataStorage dataStorageWithPath:testfile readonly:NO];
	dispatch_apply(MAX_THREADING, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t index) {
		for (int i = 0 ; i < 10000 ; i++) {
			NSNumber *indexNumber = [NSNumber numberWithInteger:rand() % 1024];
			__unused NSNumber *valueNumber = [dataStorage objectForKey:[indexNumber stringValue]];
			[dataStorage setObject:[NSNumber numberWithInteger:rand()] forKey:[indexNumber stringValue]];
		}
	});
}

- (void)testPasswordProtection
{
	NSDictionary *sampleDictionary = self.sampleDictionary;
	NSString *password = @"some password";
	NSString *testfile = [self.documentDirectory stringByAppendingPathComponent:TEST_FILE_6];

	ZDataStorage *sourceDataStorage = [[ZDataStorage alloc] initWithPath:testfile readonly:NO];
	[sourceDataStorage setPassword:password];
	[self writeSampleToStorage:sourceDataStorage];
	[sourceDataStorage close];
	sourceDataStorage = nil;

	ZDataStorage *destinationDataStorage = [[ZDataStorage alloc] initWithPath:testfile readonly:NO];
	for (NSString *key in sampleDictionary.allKeys) {
		NSString *destinationString = [destinationDataStorage stringForKey:key];
		XCTAssertNotEqualObjects(self.sampleDictionary[key], destinationString, @"should be protected when no password");
	}
	destinationDataStorage = nil;

	ZDataStorage *targetDataStorage = [[ZDataStorage alloc] initWithPath:testfile readonly:NO];
	[targetDataStorage setPassword:password];
	for (NSString *key in sampleDictionary.allKeys) {
		NSString *targetString = [targetDataStorage stringForKey:key];
		XCTAssertEqualObjects(sampleDictionary[key], targetString, @"should be retrieved with password");
	}
	destinationDataStorage = nil;
}

- (void)testVacuum
{
	/*
	NSDictionary *sampleDictionary = self.sampleDictionary;

	NSString *testfile = [self.documentDirectory stringByAppendingPathComponent:TEST_FILE_7];
	ZDataStorage *dataStorage = [ZDataStorage dataStorageWithPath:testfile readonly:NO];
	[dataStorage setAppSignature:@"com.electricwoods.ZDataStorage"];
	[self writeSampleToStorage:dataStorage];
	[dataStorage commit];
	[dataStorage dump];

	[dataStorage setData:nil forKey:@"JP"];
	[dataStorage setData:nil forKey:@"ES"];
	[dataStorage commit];

	[dataStorage vacuum];
	[dataStorage dump];

	for (NSString *key in dataStorage.allKeys) {
		NSLog(@"[%@] %@", key, [dataStorage stringForKey:key]);
	}
	*/
}


@end
