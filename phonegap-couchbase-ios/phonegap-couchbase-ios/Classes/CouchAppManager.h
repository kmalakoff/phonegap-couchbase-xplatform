//
//  CouchAppManager.h
//  None
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

#import <Foundation/Foundation.h>

@interface CouchAppManager : NSObject {
	NSURL* couchbaseServerURL;                      // pass the URL from "CouchbaseDelegate couchbaseDidStart"
    NSURLCredential *couchappServerCredential;      // required for authorization
    NSString* couchappDatabaseName;                 // should be in the form of "mydatabase"
    NSString* couchappDocumentName;                 // should be in the form of "myapp"
    
    NSString* _credentialString;
}

@property (copy, readwrite) NSURL* couchbaseServerURL;
@property (copy, readwrite) NSURLCredential *couchappServerCredential;
@property (copy, readwrite) NSString* couchappDatabaseName;
@property (copy, readwrite) NSString* couchappDocumentName;

@property (copy, readonly) NSString* _credentialString;

///////////////////////
// Public Interface
///////////////////////
-(CouchAppManager*)init:(NSURL*)serverURL serverCredential:(NSURLCredential*)serverCredential databaseName:(NSString*)databaseName documentName:(NSString*)documentName; 
-(void)loadNewAppVersion:(NSString*)newVersion getAppAsJSONDataBlock:(NSData* (^)())getAppAsJSONDataBlock; // newVersionOverride allows for an optimization by the caller supplying a version string rather than parsing the appAsJSONString and using the _rev field (which is the default if newVersion is not supplied) 
-(void)gotoAppPage:(UIWebView*)webView page:(NSString*)page; 

///////////////////////
// Internal Flow
///////////////////////
-(BOOL)ensureAppDatabaseExists;
-(NSString*)getCurrentAppVersion;
-(void)setCurrentAppVersion:(NSString*)version;

///////////////////////
// URL Helpers
///////////////////////
-(NSString*)urlToAppDatabase;
-(NSString*)urlToAppDocument;
-(NSString*)urlToAppLoadedVerionDocument;

///////////////////////
// HTTP Helpers
///////////////////////
-(NSData*)serverHTTPRequest:(NSString*)urlString httpMethod:(NSString*)httpMethod response:(NSHTTPURLResponse**)response;
-(NSData*)serverHTTPRequest:(NSString*)urlString httpMethod:(NSString*)httpMethod data:(NSData*)data contentType:(NSString*)contentType response:(NSHTTPURLResponse**)response;
-(BOOL)serverHTTPRequest_DeleteDocument:(NSString*)urlString _revCurrent:(NSString*)_revCurrent;

-(void)requestAddURLString:(NSMutableURLRequest*)request urlString:(NSString*)urlString;
-(void)requestAddCredential:(NSMutableURLRequest*)request;

-(BOOL)responseDataHasFieldAndValue:(NSData*)responseData field:(NSString*)field value:(NSString*)value;
-(BOOL)responseDataHasField:(NSData*)responseData field:(NSString*)field;
-(NSString*)responseDataExtractSimpleValue:(NSData*)responseData field:(NSString*)field;     // this is not robust -> the "field" should only occur once and the value should be a simple value (',' or '}')

///////////////////////
// Misc Helpers
///////////////////////
-(NSRange)valueClean:(NSString*)valueString range:(NSRange)range;

@end
