//
//  SPLMimeEntity.m
//  cashier
//
//  Created by Oliver Letterer on 17.03.14.
//  Copyright 2014 Sparrowlabs. All rights reserved.
//

#import "SPLMimeEntity.h"
#import "Base64.h"

#include <iostream>
#include <algorithm>
#include <mimetic/mimetic.h>

using namespace std;
using namespace mimetic;

static NSString *dataFromStringWithEncodingBase64(NSString *bodyString, NSString *encoding)
{
    if ([encoding.lowercaseString isEqualToString:@"base64"])
    {
        return bodyString;
    } else {
        return nil;
    }
}

@implementation SPLMailbox
@synthesize mailbox = _mailbox;
@synthesize domain = _domain;
@synthesize label = _label;

- (instancetype)initWithMailbox:(const Mailbox &)mailbox
{
    if (self = [super init]) {
        if (mailbox.mailbox(0).length() > 0) {
            _mailbox = [MimeConvert ConvertHeader:mailbox.mailbox(0).c_str()];
        }
        
        if (mailbox.domain(0).length() > 0) {
            _domain = [NSString stringWithFormat:@"%s", mailbox.domain(0).c_str()];
        }
        
        if (mailbox.label(0).length() > 0) {
            _label = [MimeConvert ConvertHeader:mailbox.label(0).c_str()];
        }
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@: mailbox = %@, domain = %@, label = %@", [super description], self.mailbox, self.domain, self.label];
}

#pragma mark - NSCoding protocol ()

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder
{
    [aCoder encodeObject:_mailbox forKey:@"mailbox"];
    [aCoder encodeObject:_domain forKey:@"domain"];
    [aCoder encodeObject:_label forKey:@"label"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder
{
    if (self = [super init]) {
        self.mailbox = [aDecoder decodeObjectForKey:@"mailbox"];
        self.domain = [aDecoder decodeObjectForKey:@"domain"];
        self.label = [aDecoder decodeObjectForKey:@"label"];
    }
    return self;
}

@end



@interface SPLMimeEntity ()

@property (nonatomic, assign) MimeEntity *mimeEntity;
@property (nonatomic, copy) NSString *string;
@property (nonatomic, assign) BOOL retainsOwnership;

@end



@implementation SPLMimeEntity
@synthesize sender = _sender;
@synthesize from = _from;
@synthesize to = _to;
@synthesize subject = _subject;
@synthesize timeStamp = _timeStamp;
@synthesize contentType = _contentType;
@synthesize contentId = _contentId;
@synthesize importance = _importance;
@synthesize replyTo = _replyTo;
@synthesize cc = _cc;
@synthesize bcc = _bcc;
@synthesize messageId = _messageId;
@synthesize bodyParts = _bodyParts;
@synthesize base64BodyDataString = _base64BodyDataString;
@synthesize string = _string;
@synthesize fileName = _fileName;
@synthesize bodyDataString = _bodyDataString;

#pragma mark - Initialization

- (NSArray *)inlineBodyParts
{
    NSMutableArray *inlineBodyParts = [NSMutableArray array];
    
    for (SPLMimeEntity *bodyPart in self.bodyParts)
    {
        if (bodyPart.bodyParts.count > 0) {
            [inlineBodyParts addObjectsFromArray:bodyPart.inlineBodyParts];
        } else if ([[bodyPart valueForHeaderKey:@"Content-Disposition" InUtf8:YES].lowercaseString rangeOfString:@"attachment"].length == 0)
        {
            [inlineBodyParts addObject:bodyPart];
        }
    }
    
    return [inlineBodyParts copy];
}

- (NSArray *)attachmentBodyParts
{
    NSMutableArray *attachmentBodyParts = [NSMutableArray array];
    
    for (SPLMimeEntity *bodyPart in self.bodyParts)
    {
        if (bodyPart.bodyParts.count > 0) {
            [attachmentBodyParts addObjectsFromArray:bodyPart.attachmentBodyParts];
        } else if ([[bodyPart valueForHeaderKey:@"Content-Disposition" InUtf8:YES].lowercaseString rangeOfString:@"attachment"].length > 0)
        {
            [attachmentBodyParts addObject:bodyPart];
        }
    }
    
    return [attachmentBodyParts copy];
}

- (NSString *)filename
{
    NSString *headerKey = @"Content-Disposition";
    NSString *contentDisposition = [NSString stringWithUTF8String:_mimeEntity->header().field(headerKey.UTF8String).value().c_str()];
    if ([contentDisposition.lowercaseString rangeOfString:@"attachment"].length > 0)
    {
        for (__strong NSString *keyValuePairString in [contentDisposition componentsSeparatedByString:@";"])
        {
            keyValuePairString = [keyValuePairString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *separatedString = @"=";
            if ([keyValuePairString containsString:@"=\""]) {
                separatedString = @"=\"";
            }
            NSArray *keyValuePair = [keyValuePairString componentsSeparatedByString:separatedString];
            
            if (keyValuePair.count >= 2)
            {
                NSString *key = keyValuePair[0];
                NSString *value = keyValuePair[1];
                
                if ([key containsString:@"filename"] || [key isEqual:@"name"])
                {
                    value = [MimeConvert ConvertHeader:[value UTF8String]]; //ConvertHeader([value UTF8String]);
                    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
                    [characterSet addCharactersInString:@"\""];
                    return [value stringByTrimmingCharactersInSet:characterSet];
                }
            }
        }
    }
    
    return nil;
}

- (instancetype)initWithMimeEntitiy:(MimeEntity *)mimeEntitiy retainOwnership:(BOOL)retainOwnership
{
    if (self = [super init])
    {
        _mimeEntity = mimeEntitiy;
        _retainsOwnership = retainOwnership;
        
        _sender = [[SPLMailbox alloc] initWithMailbox:_mimeEntity->header().sender()];
        
        _subject = [self valueForHeaderKey:@"Subject" InUtf8:NO];
        _timeStamp = [self valueForHeaderKey:@"Date" InUtf8:YES];
        _messageId = [self valueForHeaderKey:@"Message-ID" InUtf8:YES];
        _contentType = [self valueForHeaderKey:@"Content-Type" InUtf8:YES];
        _contentId = [self valueForHeaderKey:@"Content-ID" InUtf8:YES];
        _importance = [self valueForHeaderKey:@"Importance" InUtf8:YES];
        _fileName = [self filename];
        
        {
            NSMutableArray *array = [NSMutableArray array];
            auto i = _mimeEntity->header().from().begin();
            while (i != _mimeEntity->header().from().end()) {
                [array addObject:[[SPLMailbox alloc] initWithMailbox:*i] ];
                ++i;
            }
            _from = [array copy];
        }
        
        {
            NSMutableArray *array = [NSMutableArray array];
            auto i = _mimeEntity->header().to().begin();
            while (i != _mimeEntity->header().to().end()) {
                [array addObject:[[SPLMailbox alloc] initWithMailbox:i->mailbox()] ];
                ++i;
            }
            _to = [array copy];
        }
        
        {
            NSMutableArray *array = [NSMutableArray array];
            auto i = _mimeEntity->header().replyto().begin();
            while (i != _mimeEntity->header().replyto().end()) {
                [array addObject:[[SPLMailbox alloc] initWithMailbox:i->mailbox()] ];
                ++i;
            }
            _replyTo = [array copy];
        }
        
        {
            NSMutableArray *array = [NSMutableArray array];
            auto i = _mimeEntity->header().cc().begin();
            while (i != _mimeEntity->header().cc().end()) {
                [array addObject:[[SPLMailbox alloc] initWithMailbox:i->mailbox()] ];
                ++i;
            }
            _cc = [array copy];
        }
        
        {
            NSMutableArray *array = [NSMutableArray array];
            auto i = _mimeEntity->header().bcc().begin();
            while (i != _mimeEntity->header().bcc().end()) {
                [array addObject:[[SPLMailbox alloc] initWithMailbox:i->mailbox()] ];
                ++i;
            }
            _bcc = [array copy];
        }
        
        _bodyDataString = bodyDataFromStringWithEncoding(_mimeEntity->body().c_str(), [self valueForHeaderKey:@"Content-Type" InUtf8:YES], [self valueForHeaderKey:@"Content-Transfer-Encoding" InUtf8:YES]);
        _base64BodyDataString = dataFromStringWithEncodingBase64([NSString stringWithUTF8String:_mimeEntity->body().c_str()], [self valueForHeaderKey:@"Content-Transfer-Encoding" InUtf8:YES]);
        
        {
            NSMutableArray *bodyParts = [NSMutableArray array];
            
            auto i = _mimeEntity->body().parts().begin();
            while (i != _mimeEntity->body().parts().end()) {
                [bodyParts addObject:[[SPLMimeEntity alloc] initWithMimeEntitiy:*i retainOwnership:NO] ];
                ++i;
            }
            
            _bodyParts = [bodyParts copy];
        }
    }
    
    return self;
}

- (instancetype)initWithString:(NSString *)string
{
    if (!string) {
        return nil;
    }
    
    istringstream str(string.UTF8String);
    istreambuf_iterator<char> bit(str), eit;
    
    return [self initWithMimeEntitiy:new MimeEntity(bit,eit) retainOwnership:YES];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@: %@\n"
            "\t sender: %@\n"
            "\t from: %@\n"
            "\t to: %@\n"
            "\t replyTo: %@\n"
            "\t cc: %@\n"
            "\t bcc: %@\n\n"
            "\t bodyParts: %@"
            , [super description], self.subject, self.sender, self.from, self.to, self.replyTo, self.cc, self.bcc, self.bodyParts];
}

- (NSString *)valueForHeaderKey:(NSString *)headerKey InUtf8:(BOOL)inUtf8
{
    return  MimeEntityGetHeaderValue(_mimeEntity, headerKey, inUtf8);
}


#pragma mark - Memory management

- (void)dealloc
{
    if (_mimeEntity && _retainsOwnership)
    {
        delete _mimeEntity, _mimeEntity = NULL;
    }
}

#pragma mark - NSCoding protocol ()

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder
{
    [aCoder encodeObject:_sender forKey:@"sender"];
    [aCoder encodeObject:_from forKey:@"from"];
    [aCoder encodeObject:_to forKey:@"to"];
    [aCoder encodeObject:_subject forKey:@"subject"];
    [aCoder encodeObject:_timeStamp forKey:@"timeStamp"];
    [aCoder encodeObject:_contentType forKey:@"contentType"];
    [aCoder encodeObject:_contentId forKey:@"contentId"];
    [aCoder encodeObject:_importance forKey:@"importance"];
    [aCoder encodeObject:_replyTo forKey:@"replyTo"];
    [aCoder encodeObject:_cc forKey:@"cc"];
    [aCoder encodeObject:_bcc forKey:@"bcc"];
    [aCoder encodeObject:_messageId forKey:@"messageId"];
    [aCoder encodeObject:_bodyParts forKey:@"bodyParts"];
    [aCoder encodeObject:_base64BodyDataString forKey:@"base64BodyDataString"];
    [aCoder encodeObject:_bodyDataString forKey:@"bodyDataString"];
    [aCoder encodeObject:_string forKey:@"string"];
    [aCoder encodeObject:_fileName forKey:@"fileName"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder
{
    if (self = [super init]) {
        self.sender = [aDecoder decodeObjectForKey:@"sender"];
        self.from = [aDecoder decodeObjectForKey:@"from"];
        self.to = [aDecoder decodeObjectForKey:@"to"];
        self.subject = [aDecoder decodeObjectForKey:@"subject"];
        self.timeStamp = [aDecoder decodeObjectForKey:@"timeStamp"];
        self.contentType = [aDecoder decodeObjectForKey:@"contentType"];
        self.contentId = [aDecoder decodeObjectForKey:@"contentId"];
        self.importance = [aDecoder decodeObjectForKey:@"importance"];
        self.replyTo = [aDecoder decodeObjectForKey:@"replyTo"];
        self.cc = [aDecoder decodeObjectForKey:@"cc"];
        self.bcc = [aDecoder decodeObjectForKey:@"bcc"];
        self.messageId = [aDecoder decodeObjectForKey:@"messageId"];
        self.bodyParts = [aDecoder decodeObjectForKey:@"bodyParts"];
        self.base64BodyDataString = [aDecoder decodeObjectForKey:@"base64BodyDataString"];
        self.bodyDataString = [aDecoder decodeObjectForKey:@"bodyDataString"];
        self.string = [aDecoder decodeObjectForKey:@"string"];
        self.fileName = [aDecoder decodeObjectForKey:@"fileName"];
    }
    return self;
}

NSString *bodyDataFromStringWithEncoding(const char *bodyData, NSString *contentType, NSString *encoding)
{
    Mime_Content_Type contenttype = MimeContentType_Other;
    Mime_Encoding encode = MimeEncoding_Other;
    if ([contentType.lowercaseString containsString:@"text/html; charset=\"koi8-r\""] || [contentType.lowercaseString containsString:@"text/plain; charset=\"koi8-r\""] )
    {
        contenttype = MimeContentType_KOI8_R;
    }
    if ([contentType.lowercaseString containsString:@"text/plain; charset=\"windows-1251\""] || [contentType.lowercaseString containsString:@"text/html; charset=\"windows-1251\""] )
    {
        contenttype = MimeContentType_Windows_1251;
    }
    if ([contentType.lowercaseString containsString:@"text/plain; charset=\"iso-8859-5\""] || [contentType.lowercaseString containsString:@"text/html; charset=\"iso-8859-5\""] )
    {
        contenttype = MimeContentType_ISO_8859_5;
    }
    if ([encoding containsString:@"quoted-printable"])
    {
        encode = MimeEncoding_Quoted_printable;
    }
    if ([encoding.lowercaseString containsString:@"base64"])
    {
        encode = MimeEncoding_Base64;
    }
    
    if ((contenttype == MimeContentType_KOI8_R || contenttype == MimeContentType_Windows_1251 || contenttype == MimeContentType_ISO_8859_5)  && (encode == MimeEncoding_Quoted_printable || encode == MimeEncoding_Base64))
    {
        return [MimeConvert ConvertFrom:bodyData MimeEncoding:contenttype MimeEncoding:encode];
    }
    NSString *bodyDataString = [NSString stringWithUTF8String:bodyData];
    if (encode == MimeEncoding_Quoted_printable)
    {
        bodyDataString = [bodyDataString stringByReplacingOccurrencesOfString:@"=\r\n" withString:@""];
        bodyDataString = [bodyDataString stringByReplacingOccurrencesOfString:@"=" withString:@"%"];
        bodyDataString = [bodyDataString stringByRemovingPercentEncoding];
        return bodyDataString;
    }
    if (encode == MimeEncoding_Base64)
    {
        return nil;
    }
    return bodyDataString;
}

NSString *MimeEntityGetHeaderValue(MimeEntity *mimeEntity, NSString *headerKey, BOOL inUtf8)
{
    if (!(mimeEntity->header().hasField(headerKey.UTF8String)))
    {
        return nil;
    }
    return inUtf8 ? [NSString stringWithUTF8String:mimeEntity->header().field(headerKey.UTF8String).value().c_str()] : [MimeConvert ConvertHeader:mimeEntity->header().field(headerKey.UTF8String).value().c_str()];
}

@end
