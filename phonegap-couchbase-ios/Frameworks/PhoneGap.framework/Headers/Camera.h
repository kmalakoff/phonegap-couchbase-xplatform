/*
 * PhoneGap is available under *either* the terms of the modified BSD license *or* the
 * MIT License (2008). See http://opensource.org/licenses/alphabetical for full text.
 * 
 * Copyright (c) 2005-2010, Nitobi Software Inc.
 * Copyright (c) 2011, IBM Corporation
 * Copyright (c) 2011, Ambrose Software, Inc
 * 
 */

#import <Foundation/Foundation.h>
#import "PGPlugin.h"

enum DestinationType {
	DestinationTypeDataUrl = 0,
	DestinationTypeFileUri
};
typedef NSUInteger DestinationType;

enum EncodingType {
    EncodingTypeJPEG = 0,
    EncodingTypePNG
};
typedef NSUInteger EncodingType;


@interface CameraPicker : UIImagePickerController
{
	NSString* callbackid;
	NSInteger quality;
    CGSize targetSize;
	NSString* postUrl;
	enum DestinationType returnType;
    enum EncodingType encodingType;
	UIPopoverController* popoverController; 
}


@property (assign) NSInteger quality;
@property (copy)   NSString* callbackId;
@property (copy)   NSString* postUrl;
@property (nonatomic) enum DestinationType returnType;
@property (nonatomic) enum EncodingType encodingType;
@property (assign) UIPopoverController* popoverController; 
@property (assign) CGSize targetSize;

- (void) dealloc;

@end

// ======================================================================= //

@interface PGCamera : PGPlugin<UIImagePickerControllerDelegate, 
									UINavigationControllerDelegate,
									UIPopoverControllerDelegate>
{
	CameraPicker* pickerController;
}

@property (retain) CameraPicker* pickerController;

/*
 * getPicture
 *
 * arguments:
 *	1: this is the javascript function that will be called with the results, the first parameter passed to the
 *		javascript function is the picture as a Base64 encoded string
 *  2: this is the javascript function to be called if there was an error
 * options:
 *	quality: integer between 1 and 100
 */
- (void) getPicture:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void) postImage:(UIImage*)anImage withFilename:(NSString*)filename toUrl:(NSURL*)url;

- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary*)info;
- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingImage:(UIImage*)image editingInfo:(NSDictionary*)editingInfo;
- (void)imagePickerControllerDidCancel:(UIImagePickerController*)picker;
- (UIImage*)imageByScalingAndCroppingForSize:(UIImage*)anImage toSize:(CGSize)targetSize;
- (void) dealloc;

@end



