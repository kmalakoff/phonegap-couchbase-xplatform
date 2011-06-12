//
//  CouchAppManager.h
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

#import <Foundation/Foundation.h>

@interface CouchAppManager : NSObject {
	NSURL* couchbaseServerURL;                      // pass the URL from "CouchbaseDelegate couchbaseDidStart"
    NSURLCredential *couchappServerCredential;      // required for authorization
    NSString* couchappDatabaseName;                 // should be in the form of "mydatabase"
    NSString* couchappDocumentName;                 // should be in the form of "myapp"
}

@property (copy) NSURL* couchbaseServerURL;
@property (copy) NSURLCredential *couchappServerCredential;
@property (copy) NSString* couchappDatabaseName;
@property (copy) NSString* couchappDocumentName;

///////////////////////
// Public Interface
///////////////////////
-(CouchAppManager*)init:(NSURL*)serverURL serverCredential:(NSURLCredential*)serverCredential databaseName:(NSString*)databaseName documentName:(NSString*)documentName; 
-(void)loadNewAppVersion:(NSString*)newVersionOverride getAppAsJSONStringBlock:(NSString* (^)())getAppAsJSONStringBlock; // newVersionOverride allows for an optimization by the caller supplying a version string rather than parsing the appAsJSONString and using the _rev field (which is the default if newVersion is not supplied) 
-(void)gotoAppPage:(UIWebView*)webView page:(NSString*)page; 

///////////////////////
// Internal Flow
///////////////////////
-(BOOL)ensureAppDatabaseExists;
-(NSDictionary*)getAppAsJSONDictionary:(NSString*)appAsJSONString;
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
-(NSDictionary*)serverHTTPRequestWithJSONResponse:(NSString*)urlString httpMethod:(NSString*)httpMethod;
-(NSDictionary*)serverHTTPRequestWithJSONResponse:(NSString*)urlString httpMethod:(NSString*)httpMethod data:(NSData*)data contentType:(NSString*)contentType;
-(NSDictionary*)serverHTTPRequestWithJSONResponse_CreateDocument:(NSString*)urlString dataJSONDictionary:(NSDictionary*)dataJSONDictionary;
-(NSDictionary*)serverHTTPRequestWithJSONResponse_UpdateDocument:(NSString*)urlString dataJSONDictionary:(NSDictionary*)dataJSONDictionary _revCurrent:(NSString*)_revCurrent;
-(NSDictionary*)serverHTTPRequestWithJSONResponse_UpdateDocument:(NSString*)urlString dataJSONMutableDictionary:(NSMutableDictionary*)dataJSONMutableDictionary _revCurrent:(NSString*)_revCurrent;

-(void)requestAddURLString:(NSMutableURLRequest*)request urlString:(NSString*)urlString;
-(void)requestAddCredential:(NSMutableURLRequest*)request;

@end
