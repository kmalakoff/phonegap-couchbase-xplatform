//
//  NSData_Base64Extensions.m
//  TouchCode
//
//  Created by Jonathan Wight on 5/10/06.
//  Copyright 2006 toxicsoftware.com. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//

#import "NSData_Base64Extensions.h"

#import "Base64Transcoder.h"

@implementation NSData (NSData_Base64Extensions)

+ (id)dataWithBase64EncodedString:(NSString *)inString
{
NSData *theEncodedData = [inString dataUsingEncoding:NSASCIIStringEncoding];
size_t theDecodedDataSize = EstimateBas64DecodedDataSize([theEncodedData length], Base64Flags_IncludeNewlines);
void *theDecodedData = malloc(theDecodedDataSize);
Base64DecodeData([theEncodedData bytes], [theEncodedData length], theDecodedData, &theDecodedDataSize, Base64Flags_IncludeNewlines);
theDecodedData = reallocf(theDecodedData, theDecodedDataSize);
if (theDecodedData == NULL)
	return(NULL);
id theData = [self dataWithBytesNoCopy:theDecodedData length:theDecodedDataSize freeWhenDone:YES];
return(theData);
}

- (NSString *)asBase64EncodedString;
{
return([self asBase64EncodedString:Base64Flags_IncludeNewlines]);
}

- (NSString *)asBase64EncodedString:(NSInteger)inFlags;
{
size_t theEncodedDataSize = EstimateBas64EncodedDataSize([self length], (int32_t)inFlags);
void *theEncodedData = malloc(theEncodedDataSize);
Base64EncodeData([self bytes], [self length], theEncodedData, &theEncodedDataSize, (int32_t)inFlags);
theEncodedData = reallocf(theEncodedData, theEncodedDataSize);
if (theEncodedData == NULL)
	return(NULL);
NSString *theString = [NSString stringWithUTF8String:theEncodedData];
free(theEncodedData);
return(theString);
}

@end
