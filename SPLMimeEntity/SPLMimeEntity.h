//
//  SPLMimeEntity.h
//  cashier
//
//  Created by Oliver Letterer on 17.03.14.
//  Copyright 2014 Sparrowlabs. All rights reserved.
//

/**
 OliverLetterer (oliver.letterer@gmail.com)
 ^               ^               ^
 label           mailbox         domain
 */

#import <Foundation/Foundation.h>
#import "EMWMimeConvert.h"

@interface SPLMailbox : NSObject <NSCoding>

@property (nonatomic, copy) NSString *mailbox;
@property (nonatomic, copy) NSString *domain;
@property (nonatomic, copy) NSString *label;

@end



/**
 @abstract  <#abstract comment#>
 */
@interface SPLMimeEntity : NSObject <NSCoding>

- (NSString *)valueForHeaderKey:(NSString *)headerKey InUtf8:(BOOL)inUtf8;

- (instancetype)initWithString:(NSString *)string;

// EML properties
@property (nonatomic, retain) SPLMailbox *sender;
@property (nonatomic, copy) NSArray *from;
@property (nonatomic, copy) NSArray *to;

@property (nonatomic, copy) NSString *subject;
@property (nonatomic, copy) NSString *timeStamp;
@property (nonatomic, copy) NSString *contentType;
@property (nonatomic, copy) NSString *contentId;
@property (nonatomic, copy) NSString *importance;

@property (nonatomic, copy) NSArray *replyTo;
@property (nonatomic, copy) NSArray *cc;
@property (nonatomic, copy) NSArray *bcc;

@property (nonatomic, copy) NSString *messageId;

@property (nonatomic, copy) NSArray *bodyParts;

- (NSArray *)inlineBodyParts;
- (NSArray *)attachmentBodyParts;

// body part
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSString *base64BodyDataString;
@property (nonatomic, copy) NSString *bodyDataString;

@end
