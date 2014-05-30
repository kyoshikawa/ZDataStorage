//
//	ELViewController.m
//	DataStorage
//
//	Created by kyoshikawa on 14/5/29.
//	Copyright (c) 2014 Electricwoods LLC. All rights reserved.
//

#import "ELViewController.h"
#import "ZDataStorage.h"

@interface ELViewController ()

@end

@implementation ELViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}

- (NSString *)documentDirectory
{
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

@end
