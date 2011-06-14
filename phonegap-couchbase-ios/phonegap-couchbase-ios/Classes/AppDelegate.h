//
//  AppDelegate.h
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

#import <UIKit/UIKit.h>
#ifdef PHONEGAP_FRAMEWORK
	#import <PhoneGap/PhoneGapDelegate.h>
#else
	#import "PhoneGapDelegate.h"
#endif

// Couchbase changes START
#import "Couchbase.h" 
#import "CouchAppManager.h" 

@interface AppDelegate : PhoneGapDelegate<CouchbaseDelegate> {
// Couchbase changes END

	NSString* invokeString;
}

// invoke string is passed to your app on launch, this is only valid if you 
// edit phonegap-couchbase-ios.plist to add a protocol
// a simple tutorial can be found here : 
// http://iphonedevelopertips.com/cocoa/launching-your-own-application-via-a-custom-url-scheme.html

@property (copy)  NSString* invokeString;

// Couchbase changes START
-(void)couchbaseDidStart:(NSURL *)serverURL; 
// Couchbase changes END

@end

