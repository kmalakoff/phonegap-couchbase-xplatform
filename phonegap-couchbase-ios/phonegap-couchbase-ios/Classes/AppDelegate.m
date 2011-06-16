//
//  AppDelegate.m
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

#import "AppDelegate.h"
#ifdef PHONEGAP_FRAMEWORK
	#import <PhoneGap/PhoneGapViewController.h>
#else
	#import "PhoneGapViewController.h"
#endif

@implementation AppDelegate

// Couchbase changes START
- (void)couchbaseDidStart:(NSURL *)serverURL { 
    NSLog(@"[INFO] CouchDB is ready at serverURL %@",serverURL); 
    
    // TODO: how should user name and password be handled properly? 
    // For example, using the default user and password at initialization, and switching to the user and password selected by the actual user, and handling remote server connections.
    NSURLCredential *credential = [NSURLCredential credentialWithUser:@"admin" password:@"admin" persistence:NSURLCredentialPersistenceForSession];
    CouchMover* couchMover = [[CouchMover alloc] init:serverURL serverCredential:credential databaseName:@"mycouchapp_db"];
    
    // put on a background thread because currently the manager uses async HTTP calls
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{

        // load the coachapp if needed from a bundle (you can create non-bundle loading options through loadDocument)
        [couchMover loadDocumentFromBundle:[NSBundle mainBundle] documentName:@"_design/mycouchapp" documentBundlePath:@"mycouchapp.json" versionBundlePath:@"mycouchapp.version"];
        
        // load the data if needed from a bundle (you can create non-bundle loading options through loadDocument)
        [couchMover loadDocumentFromBundle:[NSBundle mainBundle] documentName:@"mydata" documentBundlePath:@"mydata.json" versionBundlePath:@"mydata.version"];

        // go back to the main thread because that is where the webview is
        dispatch_async(dispatch_get_main_queue(), ^{
            [couchMover gotoAppPage:@"_design/mycouchapp" webView:self.webView page:@"index.html"];
            [couchMover release];
        });
    });
} 
// Couchbase changes END

@synthesize invokeString;

- (id) init
{	
	/** If you need to do any extra app-specific initialization, you can do it here
	 *  -jm
	 **/
    return [super init];
}

/**
 * This is main kick off after the app inits, the views and Settings are setup here. (preferred - iOS4 and up)
 */
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	
	NSArray *keyArray = [launchOptions allKeys];
	if ([launchOptions objectForKey:[keyArray objectAtIndex:0]]!=nil) 
	{
		NSURL *url = [launchOptions objectForKey:[keyArray objectAtIndex:0]];
		self.invokeString = [url absoluteString];
		NSLog(@"phonegap-couchbase-ios launchOptions = %@",url);
	}

    // Couchbase changes START
	[Couchbase startCouchbase:self]; 
    // Couchbase changes END
    
	return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

// this happens while we are running ( in the background, or from within our own app )
// only valid if phonegap-couchbase-ios.plist specifies a protocol to handle
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url 
{
	// Do something with the url here
	NSString* jsString = [NSString stringWithFormat:@"handleOpenURL(\"%@\");", url];
	[webView stringByEvaluatingJavaScriptFromString:jsString];
	
	return YES;
}

-(id) getCommandInstance:(NSString*)className
{
	/** You can catch your own commands here, if you wanted to extend the gap: protocol, or add your
	 *  own app specific protocol to it. -jm
	 **/
	return [super getCommandInstance:className];
}

/**
 Called when the webview finishes loading.  This stops the activity view and closes the imageview
 */
- (void)webViewDidFinishLoad:(UIWebView *)theWebView 
{
	// only valid if phonegap-couchbase-ios.plist specifies a protocol to handle
	if(self.invokeString)
	{
		// this is passed before the deviceready event is fired, so you can access it in js when you receive deviceready
		NSString* jsString = [NSString stringWithFormat:@"var invokeString = \"%@\";", self.invokeString];
		[theWebView stringByEvaluatingJavaScriptFromString:jsString];
	}
	return [ super webViewDidFinishLoad:theWebView ];
}

- (void)webViewDidStartLoad:(UIWebView *)theWebView 
{
	return [ super webViewDidStartLoad:theWebView ];
}

/**
 * Fail Loading With Error
 * Error - If the webpage failed to load display an error with the reason.
 */
- (void)webView:(UIWebView *)theWebView didFailLoadWithError:(NSError *)error 
{
	return [ super webView:theWebView didFailLoadWithError:error ];
}

/**
 * Start Loading Request
 * This is where most of the magic happens... We take the request(s) and process the response.
 * From here we can re direct links and other protocalls to different internal methods.
 */
- (BOOL)webView:(UIWebView *)theWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	return [ super webView:theWebView shouldStartLoadWithRequest:request navigationType:navigationType ];
}


- (BOOL) execute:(InvokedUrlCommand*)command
{
	return [ super execute:command];
}

- (void)dealloc
{
	[ super dealloc ];
}

@end
