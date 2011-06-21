//
//  CouchMover.m
//  CouchMover
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

#import "CouchMover.h"
#import "NSData_Base64Extensions.h"             // for asBase64EncodedString for authenticaton

NSString * const CONTENT_TYPE_JSON              = @"application/json";
NSString * const CONTENT_TYPE_FORM              = @"multipart/form-data";
NSString * const COUCHAPP_LOADED_VERSION_DOC    = @"loaded_version";
NSString * const COUCHAPP_LOADED_VERSION_FIELD  = @"loaded_rev";
#define RESPONSE_DATA_OK(data)                  ([self responseDataHasFieldAndValue:data field:@"ok" value:@"true"])
#define RESPONSE_DATA_DB_EXISTS(data)           ([self responseDataHasField:data field:@"db_name"])
#define RESPONSE_DATA_DOC_EXISTS(data)          ([self responseDataHasField:data field:@"_id"])

@implementation CouchMover

@synthesize serverURL;
@synthesize databaseName;

@synthesize _credentialString;

///////////////////////
// Public Interface
///////////////////////
-(CouchMover*)init:(NSURL*)inServerURL serverCredential:(NSURLCredential*)inServerCredential databaseName:(NSString*)inDatabaseName; 
{
    self = [super init];
    if (self == nil)
        return nil;
    
    self.serverURL = inServerURL;
    self.couchappServerCredential = inServerCredential;
    self.databaseName = inDatabaseName;
    
    return self;
}

-(BOOL)ensureDatabaseExists
{
    NSString *databaseURL = [self urlToDatabase];
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

-(BOOL)documentHasChanged:(NSString*)documentName version:(NSString*)version
{
    // call this first because loadDocument calls this
    [self ensureDatabaseExists];

    // no version so always load
    if(!version)
        return TRUE;
    
    // no change so do not upload
    NSString *currentVersion = [self getCurrentDocumentVersion:documentName];
    return(!currentVersion || ([currentVersion compare:version] != NSOrderedSame));
}

-(BOOL)loadDocument:(NSString*)documentName version:(NSString*)version getAppAsJSONDataBlock:(NSData* (^)())getAppAsJSONDataBlock
{
    // no change in the document
    if(![self documentHasChanged:documentName version:version])
        return YES;
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSString *documentURL = [self urlToDocument:documentName];
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

    BOOL success = RESPONSE_DATA_OK(responseData);
    if(!success)
        NSLog(@"Failed to create the couch app at URL: %@", documentURL);

    // update the version -> if there is no revision, skip and it will be loaded again next time
    else
        [self setCurrentDocumentVersion:documentName version:version];
    [pool release];
    
    return success;
}

-(BOOL)loadDocumentFromBundle:(NSBundle*)bundle documentName:(NSString*)documentName documentBundlePath:(NSString*)documentBundlePath versionBundlePath:(NSString*)versionBundlePath
{
    NSString *versionAbsolutePath = [[bundle resourcePath] stringByAppendingPathComponent:versionBundlePath];
    NSString *version = [NSString stringWithContentsOfFile:versionAbsolutePath usedEncoding:nil error:nil];
    
    if(!version)
    {
        NSLog(@"Failed to find the bundle resource: %@", versionAbsolutePath);
        return NO;
    }
    
    // load the coachapp if needed
    return [self loadDocument:documentName version:version getAppAsJSONDataBlock:^(){
        NSString *documentAbsolutePath = [[bundle resourcePath] stringByAppendingPathComponent:documentBundlePath];
        return (NSData*) [NSData dataWithContentsOfFile:documentAbsolutePath];
    }];
}

-(void)gotoAppPage:(NSString*)appDocumentName webView:(UIWebView*)webView page:(NSString*)page
{
    NSString *couchappApgeURL = [[NSString alloc] initWithFormat:@"window.location.href = \"%@/%@\"", [self urlToDocument:appDocumentName], page];
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
-(NSString*)getCurrentDocumentVersion:(NSString*)documentName
{
    NSString *documentURL = [self urlToLoadedDocumentVerionDocument:documentName];
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

-(void)setCurrentDocumentVersion:(NSString*)documentName version:(NSString*)version
{
    NSString *documentURL = [self urlToLoadedDocumentVerionDocument:documentName];
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
-(NSString*)urlToDatabase
{
    return [NSString stringWithFormat:@"%@%@", [self.serverURL absoluteString], self.databaseName];
}

-(NSString*)urlToDocument:(NSString*)documentName
{
    return [NSString stringWithFormat:@"%@%@/%@", [self.serverURL absoluteString], self.databaseName, documentName];
}

-(NSString*)urlToLoadedDocumentVerionDocument:(NSString*)documentName
{
    if([documentName hasPrefix:@"_design"])
        return [NSString stringWithFormat:@"%@%@/%@_%@", [self.serverURL absoluteString], self.databaseName, documentName, COUCHAPP_LOADED_VERSION_DOC];

    // make sure _design starts with _design so it is skipped in view generation
    else
        return [NSString stringWithFormat:@"%@%@/_design/%@_%@", [self.serverURL absoluteString], self.databaseName, documentName, COUCHAPP_LOADED_VERSION_DOC];
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

	[serverURL release];
	[couchappServerCredential release];
	[databaseName release];
	[super dealloc];
}

@end
