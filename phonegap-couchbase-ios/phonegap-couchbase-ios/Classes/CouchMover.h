//
//  CouchMover.h
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

#import <Foundation/Foundation.h>

@interface CouchMover : NSObject {
	NSURL* serverURL;                      // pass the URL from "CouchbaseDelegate couchbaseDidStart"
    NSURLCredential *couchappServerCredential;      // required for authorization
    NSString* databaseName;                 // should be in the form of "mydatabase"
    
    NSString* _credentialString;
}

@property (copy, readwrite) NSURL* serverURL;
@property (copy, readwrite) NSURLCredential *couchappServerCredential;
@property (copy, readwrite) NSString* databaseName;

@property (copy, readonly) NSString* _credentialString;

///////////////////////
// Public Interface
///////////////////////
-(CouchMover*)init:(NSURL*)inServerURL serverCredential:(NSURLCredential*)inServerCredential databaseName:(NSString*)inDatabaseName; 
-(BOOL)documentHasChanged:(NSString*)documentName version:(NSString*)version;           // for a couch app, pass the documentName in the format of @"_design/appname"
-(BOOL)loadDocument:(NSString*)documentName version:(NSString*)version getAppAsJSONDataBlock:(NSData* (^)())getAppAsJSONDataBlock;      // for a couch app, pass the documentName in the format of @"_design/appname"
-(BOOL)loadDocumentFromBundle:(NSBundle*)bundle documentName:(NSString*)documentName documentBundlePath:(NSString*)documentBundlePath versionBundlePath:(NSString*)versionBundlePath;
-(void)gotoAppPage:(NSString*)appDocumentName webView:(UIWebView*)webView page:(NSString*)page; 

///////////////////////
// Internal Flow
///////////////////////
-(BOOL)ensureAppDatabaseExists;
-(NSString*)getCurrentAppVersion:(NSString*)documentName;
-(void)setCurrentAppVersion:(NSString*)documentName version:(NSString*)version;

///////////////////////
// URL Helpers
///////////////////////
-(NSString*)urlToAppDatabase;
-(NSString*)urlToAppDocument:(NSString*)documentName;
-(NSString*)urlToLoadedDocumentVerionDocument:(NSString*)documentName;

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
