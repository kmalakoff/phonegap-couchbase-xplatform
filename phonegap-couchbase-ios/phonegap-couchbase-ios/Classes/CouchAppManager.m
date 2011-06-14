//
//  CouchAppManager.m
//  CouchAppManager
//
//  Created by Kevin Malakoff on 6/11/11.
//  Copyright 2011 None.
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License. You may obtain a copy of
// the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations under
// the License.

#import "CouchAppManager.h"
#import "NSData_Base64Extensions.h"             // for asBase64EncodedString for authenticaton

NSString * const CONTENT_TYPE_JSON              = @"application/json";
NSString * const CONTENT_TYPE_FORM              = @"multipart/form-data";
NSString * const COUCHAPP_LOADED_VERSION_DOC    = @"loaded_couchapp_version";
NSString * const COUCHAPP_LOADED_VERSION_FIELD  = @"loaded_rev";
#define RESPONSE_DATA_OK(data)                  ([self responseDataHasFieldAndValue:data field:@"ok" value:@"true"])
#define RESPONSE_DATA_DB_EXISTS(data)           ([self responseDataHasField:data field:@"db_name"])
#define RESPONSE_DATA_DOC_EXISTS(data)          ([self responseDataHasField:data field:@"_id"])

@implementation CouchAppManager

@synthesize couchbaseServerURL;
@synthesize couchappDatabaseName;
@synthesize couchappDocumentName;

@synthesize _credentialString;

///////////////////////
// Public Interface
///////////////////////
-(CouchAppManager*)init:(NSURL*)serverURL serverCredential:(NSURLCredential*)serverCredential databaseName:(NSString*)databaseName documentName:(NSString*)documentName 
{
    self = [super init];
    if (self == nil)
        return nil;
    
    self.couchbaseServerURL = serverURL;
    self.couchappServerCredential = serverCredential;
    self.couchappDatabaseName = databaseName;
    self.couchappDocumentName = documentName;
    
    return self;
}

-(void)loadNewAppVersion:(NSString*)newVersion getAppAsJSONDataBlock:(NSData* (^)())getAppAsJSONDataBlock
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [self ensureAppDatabaseExists];

    // no change so do not upload
    NSString *currentVersion = [self getCurrentAppVersion];
    if(currentVersion && newVersion && ([currentVersion compare:newVersion] == NSOrderedSame))
    {
        // no change so do not upload
        [pool release];
        return;
    }
    
    NSString *documentURL = [self urlToAppDocument];
    NSData *responseData;
    
    /////////////////////////
    // check existence of app - HEAD and if it does, DELETE it before update
    // NOTE: this is to avoid having to update the provided couchapp with the _rev parameter from the existing app 
    /////////////////////////

    // get the current revision if app exists
    NSHTTPURLResponse *response = nil;
    [self serverHTTPRequest:documentURL httpMethod:@"HEAD" response:&response];
    NSString *_revCurrent = response ? [[response allHeaderFields] valueForKey:@"Etag"] : nil; 

    // delete the current app
    if(_revCurrent)
        [self serverHTTPRequest_DeleteDocument:documentURL _revCurrent:_revCurrent];
    
    // create
    responseData = [self serverHTTPRequest:documentURL httpMethod:@"PUT" data:getAppAsJSONDataBlock() contentType:CONTENT_TYPE_FORM response:nil];
    if(!RESPONSE_DATA_OK(responseData))
        NSLog(@"Failed to create the couch app at URL: %@", documentURL);

    // update the version -> if there is no revision, skip and it will be loaded again next time
    else
        [self setCurrentAppVersion:newVersion];
    [pool release];
}

-(void)gotoAppPage:(UIWebView*)webView page:(NSString*)page
{
    NSString *couchappApgeURL = [[NSString alloc] initWithFormat:@"window.location.href = \"%@/%@\"", [self urlToAppDocument], page];
    [webView stringByEvaluatingJavaScriptFromString:couchappApgeURL];
    [couchappApgeURL release];
}

-(NSURLCredential*)couchappServerCredential
{
    return couchappServerCredential;
}

-(void)setCouchappServerCredential:(NSURLCredential*)inCredential
{
    [inCredential retain];
    
    if(couchappServerCredential)
        [couchappServerCredential release];
    
    couchappServerCredential = inCredential;

    if(couchappServerCredential)
    {
        NSString *tempString = [[NSString alloc] initWithFormat:@"%@:%@", couchappServerCredential.user, couchappServerCredential.password];
        NSData *credentialData = [tempString dataUsingEncoding:NSUTF8StringEncoding];
        [tempString release];
        tempString = [credentialData asBase64EncodedString:0];
        _credentialString = [[NSString alloc] initWithFormat:@"Basic %@", tempString];
    }
    else
    {
        [_credentialString release];
        _credentialString = nil;
    }
}


///////////////////////
// Internal Flow
///////////////////////
-(BOOL)ensureAppDatabaseExists
{
    NSString *databaseURL = [self urlToAppDatabase];
    NSData *responseData;
    
    /////////////////////////
    // check existence - GET
    /////////////////////////
    responseData = [self serverHTTPRequest:databaseURL httpMethod:@"GET" response:nil];
    
    // failed to connect to server or parse response
    if(!responseData) 
    {
        NSLog(@"Failed to connect to the server at: %@", databaseURL);
        return NO;
    }
    
    // the DB exists
    if(RESPONSE_DATA_DB_EXISTS(responseData))
        return YES;
    
    /////////////////////////
    // doesn't exist so create - PUT
    /////////////////////////
    responseData = [self serverHTTPRequest:databaseURL httpMethod:@"PUT" response:nil];
    return RESPONSE_DATA_OK(responseData);
}

-(NSString*)getCurrentAppVersion
{
    NSString *documentURL = [self urlToAppLoadedVerionDocument];
    NSData *responseData;
    
    /////////////////////////
    // check existence - GET
    /////////////////////////
    responseData = [self serverHTTPRequest:documentURL httpMethod:@"GET" response:nil];
    
    // failed to connect to server or parse response
    if(!responseData) 
        return nil;

    // get the key field key
    return RESPONSE_DATA_DOC_EXISTS(responseData)? [self responseDataExtractSimpleValue:responseData field:COUCHAPP_LOADED_VERSION_FIELD] : nil;
}

-(void)setCurrentAppVersion:(NSString*)version
{
    NSString *documentURL = [self urlToAppLoadedVerionDocument];
    NSData *responseData;
    
    /////////////////////////
    // check existence - GET
    /////////////////////////
    responseData = [self serverHTTPRequest:documentURL httpMethod:@"GET" response:nil];
    
    // exists, delete
    if(RESPONSE_DATA_DOC_EXISTS(responseData))
    {
        NSString *_revCurrent = [self responseDataExtractSimpleValue:responseData field:@"_rev"];
        [self serverHTTPRequest_DeleteDocument:documentURL _revCurrent:_revCurrent];
    }
    
    NSString *versionDocument = [[NSString alloc] initWithFormat:@"{\"%@\":\"%@\"}", COUCHAPP_LOADED_VERSION_FIELD, version];
    NSData *versionData = [versionDocument dataUsingEncoding:NSUTF8StringEncoding];
    
    // create
    responseData = [self serverHTTPRequest:documentURL httpMethod:@"PUT" data:versionData contentType:CONTENT_TYPE_FORM response:nil];
    if(!RESPONSE_DATA_OK(responseData))
        NSLog(@"Failed to create the couch app version document at URL: %@", documentURL);
    
    [versionDocument release];
}

///////////////////////
// URL Helpers
///////////////////////
-(NSString*)urlToAppDatabase
{
    return [NSString stringWithFormat:@"%@%@", [self.couchbaseServerURL absoluteString], self.couchappDatabaseName];
}

-(NSString*)urlToAppDocument
{
    return [NSString stringWithFormat:@"%@%@/_design/%@", [self.couchbaseServerURL absoluteString], self.couchappDatabaseName, self.couchappDocumentName];
}

-(NSString*)urlToAppLoadedVerionDocument
{
    return [NSString stringWithFormat:@"%@%@/_design/%@", [self.couchbaseServerURL absoluteString], self.couchappDatabaseName, COUCHAPP_LOADED_VERSION_DOC];
}

///////////////////////
// HTTP Helpers
///////////////////////
-(NSData*)serverHTTPRequest:(NSString*)urlString httpMethod:(NSString*)httpMethod response:(NSHTTPURLResponse**)response;
{
    return [self serverHTTPRequest:urlString httpMethod:httpMethod data:nil contentType:nil response:response];
}

-(NSData*)serverHTTPRequest:(NSString*)urlString httpMethod:(NSString*)httpMethod data:(NSData*)data contentType:(NSString*)contentType response:(NSHTTPURLResponse**)response
{
    NSMutableURLRequest *    request = [[NSMutableURLRequest alloc] init];
    [request setHTTPMethod:httpMethod];
    [request setValue:CONTENT_TYPE_JSON forHTTPHeaderField:@"Accept"];
    [self requestAddURLString:request urlString:urlString];
    [self requestAddCredential:request];
    
    if(data && contentType)
    {
        // TODO: add a proper referer header
        [request setValue:[[request URL] absoluteString] forHTTPHeaderField:@"Referer"];
        [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
        [request setValue:[NSString stringWithFormat:@"%d", [data length]] forHTTPHeaderField:@"Content-Length"];
        [request setHTTPBody:data];
    }

    // check the couch server for the database
    NSError *error = nil;
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:response error:&error];
    //    [request release];
    if (error)
    {
        NSLog(@"Error: %@ \nFor request: %@",[error localizedDescription], [[request URL] absoluteString]);
        return nil;
    }
    
    return responseData;
}
-(BOOL)serverHTTPRequest_DeleteDocument:(NSString*)urlString _revCurrent:(NSString*)_revCurrent
{
    // generate the URL including the rev parameter (removing the quotes)
    NSString *documentURLDelete = [NSString stringWithFormat:@"%@?rev=%@", urlString, [_revCurrent stringByReplacingOccurrencesOfString:@"\"" withString: @""]];
    NSData *responseData = [self serverHTTPRequest:documentURLDelete httpMethod:@"DELETE" response:nil];
    if(!RESPONSE_DATA_OK(responseData))
    {
        NSLog(@"Failed to delete the at URL: %@", documentURLDelete);
        return NO;
    }
    
    return YES;
}

-(void)requestAddURLString:(NSMutableURLRequest*)request urlString:(NSString*)urlString
{
    NSURL *url = [NSURL URLWithString:urlString];
    [request setURL:url];
}

-(void)requestAddCredential:(NSMutableURLRequest*)request
{
    if(_credentialString)
        [request setValue:_credentialString forHTTPHeaderField:@"Authorization"];
}

-(BOOL)responseDataHasFieldAndValue:(NSData*)responseData field:(NSString*)field value:(NSString*)value
{
    NSString *valueString = [self responseDataExtractSimpleValue:responseData field:field];
    return (valueString && ([valueString compare:value] == NSOrderedSame));
}

-(BOOL)responseDataHasField:(NSData*)responseData field:(NSString*)field
{
    NSString *responseDataAsString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    NSUInteger responseDataAsStringLength = [responseDataAsString length];
    
    NSString *regexPattern = [[NSString alloc] initWithFormat:@"\"%@\"( )*:", field];
    NSRegularExpression *fieldRegex = [[NSRegularExpression alloc] initWithPattern:regexPattern options:0 error:nil];
    [regexPattern release];
    NSTextCheckingResult *fieldMatch = [fieldRegex firstMatchInString:responseDataAsString options:0 range:NSMakeRange(0, responseDataAsStringLength)];
    [fieldRegex release];

    [responseDataAsString release];
    return (fieldMatch != nil);
}

// this is not robust -> the "field" should only occur once and the value should be a simple value (',' or '}')
-(NSString*)responseDataExtractSimpleValue:(NSData*)responseData field:(NSString*)field
{
    NSString *valueString = nil;
    NSString *responseDataAsString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    NSUInteger responseDataAsStringLength = [responseDataAsString length];
    
    NSString *regexPattern = [[NSString alloc] initWithFormat:@"\"%@\"( )*:", field];
    NSRegularExpression *fieldRegex = [[NSRegularExpression alloc] initWithPattern:regexPattern options:0 error:nil];
    [regexPattern release];
    NSTextCheckingResult *fieldMatch = [fieldRegex firstMatchInString:responseDataAsString options:0 range:NSMakeRange(0, responseDataAsStringLength)];
    [fieldRegex release];
    
    // found the field
    if(fieldMatch)
    {
        NSRange fieldMatchRange = [fieldMatch range];
        NSUInteger fieldColonOffset = fieldMatchRange.location + fieldMatchRange.length;
        
        NSCharacterSet *fieldEndDelimiters = [NSCharacterSet characterSetWithCharactersInString:@"\\},"]; 
        NSRange valueMatchRange = [responseDataAsString rangeOfCharacterFromSet:fieldEndDelimiters options:0 range:NSMakeRange(fieldColonOffset, responseDataAsStringLength - fieldColonOffset)];

        // found the value
        if(valueMatchRange.length>0)
        {
            valueMatchRange.length = valueMatchRange.location - fieldColonOffset;       // drop the , or }
            valueMatchRange.location = fieldColonOffset;
            valueMatchRange = [self valueClean:responseDataAsString range:valueMatchRange];
            
            valueString = [responseDataAsString substringWithRange:valueMatchRange];
        }
    }

    [responseDataAsString release];
    return valueString;
}

///////////////////////
// Misc Helpers
///////////////////////
-(NSRange)valueClean:(NSString*)valueString range:(NSRange)range
{
    NSRange cleanRange = range;
    
    // remove leading space
    while([valueString characterAtIndex:cleanRange.location]==' ')
    {
        cleanRange.location++;
        cleanRange.length--;
    }
    
    // remove leading quote
    if([valueString characterAtIndex:cleanRange.location]=='"')
    {
        cleanRange.location++;
        cleanRange.length--;
    }

    // remove trailling space
    while([valueString characterAtIndex:cleanRange.location+cleanRange.length-1]==' ')
        cleanRange.length--;
    
    // remove trailing quote
    if([valueString characterAtIndex:cleanRange.location+cleanRange.length-1]=='"')
        cleanRange.length--;
    
    return cleanRange;
}

- (void)dealloc
{
    [_credentialString release];

	[couchbaseServerURL release];
	[couchappServerCredential release];
	[couchappDatabaseName release];
	[couchappDocumentName release];
	[super dealloc];
}

@end
