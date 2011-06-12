//
//  CouchAppManager.m
//  None
//
//  Created by XMann on 6/11/11.
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
#import "CJSONDeserializer.h"                   // for parsing server responses
#import "CJSONSerializer.h"                     // for cleaning up the couch app fields for PUT

NSString * const CONTENT_TYPE_JSON              = @"application/json";
NSString * const CONTENT_TYPE_FORM              = @"multipart/form-data";
NSString * const COUCHAPP_LOADED_VERSION_DOC    = @"loaded_couchapp_version";
NSString * const COUCHAPP_LOADED_VERSION_FIELD  = @"loaded_rev";
#define RESPONSE_DICTIONARY_DB_EXISTS(dict)     ([dict objectForKey:@"db_name"] != nil)
#define RESPONSE_DICTIONARY_DOC_EXISTS(dict)    ([dict objectForKey:@"_id"] != nil)
#define RESPONSE_DICTIONARY_OK(dict)            ([dict objectForKey:@"ok"] != nil)

@implementation CouchAppManager

@synthesize couchbaseServerURL;
@synthesize couchappServerCredential;
@synthesize couchappDatabaseName;
@synthesize couchappDocumentName;

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

-(void)loadNewAppVersion:(NSString*)newVersionOverride getAppAsJSONStringBlock:(NSString* (^)())getAppAsJSONStringBlock
{
    [self ensureAppDatabaseExists];

    NSDictionary *appJSONDictionary = nil;
    NSString *newVersion = newVersionOverride;
    
    // the app should exist
    NSString *currentVersion = [self getCurrentAppVersion];
    if(currentVersion)
    {
        // no version supplied, use the _rev field
        if(!newVersion)
        {
            appJSONDictionary = [self getAppAsJSONDictionary:getAppAsJSONStringBlock()];
            newVersion = [appJSONDictionary valueForKey:@"_rev"];
            if(!newVersion)
                NSLog(@"Missing _rev parameter on the app being loaded");
        }
        
        // check for a change in the rev
        if(currentVersion && newVersion && ([currentVersion compare:newVersion] == NSOrderedSame) )
        {
            // no change so do not upload
            return;
        }
    }
    
    NSString *documentURL = [self urlToAppDocument];
    BOOL appExists;
    BOOL success = NO;
    NSDictionary *responseJSONDictionary;
    
    /////////////////////////
    // check existence of app - GET
    /////////////////////////
    
    // we call this in case the version document exists, but the app was deleted
    responseJSONDictionary = [self serverHTTPRequestWithJSONResponse:documentURL httpMethod:@"GET"];
    appExists = RESPONSE_DICTIONARY_DOC_EXISTS(responseJSONDictionary);

    // get the data if haven't already
    if(!appJSONDictionary)
        appJSONDictionary = [self getAppAsJSONDictionary:getAppAsJSONStringBlock()];
    
    // update the app
    if(appExists)
    {
        // update
        NSString *_revCurrent = [responseJSONDictionary valueForKey:@"_rev"];
        responseJSONDictionary = [self serverHTTPRequestWithJSONResponse_UpdateDocument:documentURL dataJSONDictionary:appJSONDictionary _revCurrent:_revCurrent];
        success = RESPONSE_DICTIONARY_OK(responseJSONDictionary);
        if(!success)
            NSLog(@"Failed to update the couch app at URL: %@", documentURL);
    }
    
    // create the app
    else
    {
        // create
        responseJSONDictionary = [self serverHTTPRequestWithJSONResponse_CreateDocument:documentURL dataJSONDictionary:appJSONDictionary];
        success = RESPONSE_DICTIONARY_OK(responseJSONDictionary);
        if(!success)
            NSLog(@"Failed to create the couch app at URL: %@", documentURL);
   }
    
    // update the version -> if there is no revision, skip and it will be loaded again next time
    if(success)
    {
        if(!newVersion)
        {
            newVersion = [appJSONDictionary valueForKey:@"_rev"];
            if(!newVersion)
                NSLog(@"Missing _rev parameter on the app being loaded");
        }
        [self setCurrentAppVersion:newVersion];
    }
}

-(void)gotoAppPage:(UIWebView*)webView page:(NSString*)page
{
    NSString *couchappApgeURL = [[NSString alloc] initWithFormat:@"window.location.href = \"%@/%@\"", [self urlToAppDocument], page];
    [webView stringByEvaluatingJavaScriptFromString:couchappApgeURL];
    [couchappApgeURL release];
}

///////////////////////
// Internal Flow
///////////////////////
-(BOOL)ensureAppDatabaseExists
{
    NSString *databaseURL = [self urlToAppDatabase];
    NSDictionary *responseJSONDictionary;
    
    /////////////////////////
    // check existence - GET
    /////////////////////////
    responseJSONDictionary = [self serverHTTPRequestWithJSONResponse:databaseURL httpMethod:@"GET"];
    
    // failed to connect to server or parse response
    if(!responseJSONDictionary) 
        return NO;
    
    // the DB exists
    if(RESPONSE_DICTIONARY_DB_EXISTS(responseJSONDictionary))
        return YES;
    
    /////////////////////////
    // doesn't exist so create - PUT
    /////////////////////////
    responseJSONDictionary = [self serverHTTPRequestWithJSONResponse:databaseURL httpMethod:@"PUT"];
    return RESPONSE_DICTIONARY_OK(responseJSONDictionary);
}

-(NSDictionary*)getAppAsJSONDictionary:(NSString*)appAsJSONString
{
    NSError *error;
    NSData *appData = [NSData dataWithBytes:[appAsJSONString UTF8String] length:[appAsJSONString length]];
    return [[CJSONDeserializer deserializer] deserializeAsDictionary:appData error:&error];
}

-(NSString*)getCurrentAppVersion
{
    NSString *documentURL = [self urlToAppLoadedVerionDocument];
    NSDictionary *responseJSONDictionary;
    
    /////////////////////////
    // check existence - GET
    /////////////////////////
    responseJSONDictionary = [self serverHTTPRequestWithJSONResponse:documentURL httpMethod:@"GET"];
    
    // failed to connect to server or parse response
    if(!responseJSONDictionary) 
        return nil;
    
    // get the key field key
    return RESPONSE_DICTIONARY_DOC_EXISTS(responseJSONDictionary)? [responseJSONDictionary valueForKey:COUCHAPP_LOADED_VERSION_FIELD] : nil;
}

-(void)setCurrentAppVersion:(NSString*)version
{
    NSString *documentURL = [self urlToAppLoadedVerionDocument];
    NSDictionary *responseJSONDictionary;
    
    /////////////////////////
    // check existence - GET
    /////////////////////////
    responseJSONDictionary = [self serverHTTPRequestWithJSONResponse:documentURL httpMethod:@"GET"];
    BOOL versionExists = RESPONSE_DICTIONARY_DOC_EXISTS(responseJSONDictionary);
    
    // exists, update
    if(versionExists)
    {
        NSString *_revCurrent = [responseJSONDictionary valueForKey:@"_rev"];
        NSMutableDictionary *dataJSONMutableDictionary = [responseJSONDictionary mutableCopy];
        
        // update the version
        [dataJSONMutableDictionary setValue:version forKey:COUCHAPP_LOADED_VERSION_FIELD];
        
        // update
        responseJSONDictionary = [self serverHTTPRequestWithJSONResponse_UpdateDocument:documentURL dataJSONMutableDictionary:dataJSONMutableDictionary _revCurrent:_revCurrent];
        if(!RESPONSE_DICTIONARY_OK(responseJSONDictionary))
            NSLog(@"Failed to update the couch app version document at URL: %@", documentURL);
    }
    
    // doesn't exist, create
    else
    {
        NSDictionary *dataJSONDictionary = [NSDictionary dictionaryWithObject:version forKey:COUCHAPP_LOADED_VERSION_FIELD];
        
        // create
        responseJSONDictionary = [self serverHTTPRequestWithJSONResponse_CreateDocument:documentURL dataJSONDictionary:dataJSONDictionary];
        if(!RESPONSE_DICTIONARY_OK(responseJSONDictionary))
            NSLog(@"Failed to create the couch app version document at URL: %@", documentURL);
    }
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
-(NSDictionary*)serverHTTPRequestWithJSONResponse:(NSString*)urlString httpMethod:(NSString*)httpMethod
{
    return [self serverHTTPRequestWithJSONResponse:urlString httpMethod:httpMethod data:nil contentType:nil];
}

-(NSDictionary*)serverHTTPRequestWithJSONResponse:(NSString*)urlString httpMethod:(NSString*)httpMethod data:(NSData*)data contentType:(NSString*)contentType
{
    NSMutableURLRequest *    request = [[NSMutableURLRequest alloc] init];
    [request setHTTPMethod:httpMethod];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
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
    
    NSError *error;
    NSURLResponse *response;
    NSData *responseData;
    NSDictionary *responseJSONDictionary;
    
    // check the couch server for the database
    error = nil;
    responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    //    [request release];
    if (error)
    {
        NSLog(@"Error: %@ \nFor request: %@",[error localizedDescription], [[request URL] absoluteString]);
        return nil;
    }
    
    // parse the response
    error = nil;
    responseJSONDictionary = [[CJSONDeserializer deserializer] deserializeAsDictionary:responseData error:&error];
    if (error || [responseJSONDictionary isKindOfClass: [NSDictionary class]] == NO )
    {
        NSLog(@"Error: %@ \nFor server response: %@",[error localizedDescription], [NSString stringWithUTF8String:[responseData bytes]]);
        return nil;
    }
    
    return responseJSONDictionary;
}

-(NSDictionary*)serverHTTPRequestWithJSONResponse_CreateDocument:(NSString*)urlString dataJSONDictionary:(NSDictionary*)dataJSONDictionary
{
    // remove _id and _rev fields
    NSMutableDictionary *dataJSONMutableDictionary = [dataJSONDictionary mutableCopy];
    [dataJSONMutableDictionary removeObjectsForKeys:[NSArray arrayWithObjects:@"_id", @"_rev", nil]];
    
    // PUT to create
    NSError *error;
    NSData *data = [[CJSONSerializer serializer] serializeDictionary:dataJSONMutableDictionary error:&error];
    [dataJSONMutableDictionary release]; dataJSONMutableDictionary = nil;
    return [self serverHTTPRequestWithJSONResponse:urlString httpMethod:@"PUT" data:data contentType:CONTENT_TYPE_FORM];
}

-(NSDictionary*)serverHTTPRequestWithJSONResponse_UpdateDocument:(NSString*)urlString dataJSONDictionary:(NSDictionary*)dataJSONDictionary _revCurrent:(NSString*)_revCurrent
{
    NSMutableDictionary *dataJSONMutableDictionary = [dataJSONDictionary mutableCopy];
    return [self serverHTTPRequestWithJSONResponse_UpdateDocument:urlString dataJSONMutableDictionary:dataJSONMutableDictionary _revCurrent:_revCurrent];
}

-(NSDictionary*)serverHTTPRequestWithJSONResponse_UpdateDocument:(NSString*)urlString dataJSONMutableDictionary:(NSMutableDictionary*)dataJSONMutableDictionary _revCurrent:(NSString*)_revCurrent
{
    // remove _id and _rev fields
    [dataJSONMutableDictionary removeObjectsForKeys:[NSArray arrayWithObjects:@"_id", @"_rev", nil]];
    
    // add the previous _rev field -> when updating, you need to send what should be the current _rev
    [dataJSONMutableDictionary setValue:_revCurrent forKey:@"_rev"];
    
    // PUT to update
    NSError *error;
    NSData *data = [[CJSONSerializer serializer] serializeDictionary:dataJSONMutableDictionary error:&error];
    [dataJSONMutableDictionary release]; dataJSONMutableDictionary = nil;
    return [self serverHTTPRequestWithJSONResponse:urlString httpMethod:@"PUT" data:data contentType:CONTENT_TYPE_JSON];
}

-(void)requestAddURLString:(NSMutableURLRequest*)request urlString:(NSString*)urlString
{
    NSURL *url = [NSURL URLWithString:urlString];
    [request setURL:url];
}

-(void)requestAddCredential:(NSMutableURLRequest*)request
{
    NSString *theValue = [NSString stringWithFormat:@"%@:%@", self.couchappServerCredential.user, self.couchappServerCredential.password];
    NSData *theData = [theValue dataUsingEncoding:NSUTF8StringEncoding];
    theValue = [theData asBase64EncodedString:0];
    theValue = [NSString stringWithFormat:@"Basic %@", theValue];
    [request setValue:theValue forHTTPHeaderField:@"Authorization"];
}

- (void)dealloc
{
	[couchbaseServerURL release];
	[couchappServerCredential release];
	[couchappDatabaseName release];
	[couchappDocumentName release];
	[super dealloc];
}

@end
