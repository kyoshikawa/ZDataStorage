ZDataStorage
============

Kaz Yoshikawa

ZDataStorage manages large number of pieces of small data.  it works like the
similar way as NSDictionary, but it is file backed and all pieces of data will be saved or loaded as demand.

USAGE
=====
ZDataStorage provides key-value coding access to store and retreive data.

Setup
-----
```
NSString *filepath = ...
ZDataStorage *dataStorage = [ZDataStorage dataStorageWithPath:filepath readonly:NO];

// read and write

[dataStorage close]; // optional
```

Store
-----
```
[dataStorage setData:someData forKey:@"JP"];
[dataStorage setData:otherData forKey:@"US"];
[dataStorage setData:anotherData forKey:@"CA"];
```

Retreive
--------
```
NSData *data1 = [dataStorage dataForKey:@"JP"];
NSData *data2 = [dataStorage dataForKey:@"US"];
NSData *data3 = [dataStorage dataForKey:@"CA"];

```

String
------
```
[dataStorage setString:@"Japan" forKey:@"JP"];
NSString *string = [dataStorage stringForKey:@"JP"];
```

Property List Objects
---------------------
It provides convenient methods to store and retrieve property list object such as NSData, NSString, NSArray, NSDictionary, NSDate and NSNumber.


```
id object = ... // either NSDictionary, NSArray, and other plist object
[dataStorage setObject:object forKey:@"JP"];
id object = [dataStorage objectForKey:@"JP"];
```

Password Protection
-------------------
ZDataStorage supports password based data scrabble feature, but this is not suitable for managing sensitive information.

```
ZDataStorage *dataStorage = [ZDataStorage dataStorageWithPath:filepath readonly:NO];
[dataStorage setPassword:@"your password"];
[dataStorage setData:data1 forKey:@"key1"];
[dataStorage setData:data2 forKey:@"key2"];

```

Password protected data can be accessed by setting password to ZDataStorage before accessing it.  By giving wrong password, end up simply retreiving corrupt data.

```
ZDataStorage *dataStorage = [ZDataStorage dataStorageWithPath:filepath readonly:NO];
[dataStorage setPassword:@"your password"];
NSData *data1 = [dataStorage dataForKey:@"key1"];
NSData *data2 = [dataStorage dataForKey:@"key2"];
```

LICENSE
=======
The MIT License (MIT)

Copyright (c) 2014 Electricwoods LLC.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

