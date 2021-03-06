// ActiveResourceKit ARService.m
//
// Copyright © 2011, 2012, Roy Ratcliffe, Pioneering Software, United Kingdom
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the “Software”), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED “AS IS,” WITHOUT WARRANTY OF ANY KIND, EITHER
// EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "ARService.h"
#import "ARService+Private.h"

#import "ARURLConnection.h"
#import "ARHTTPResponse.h"
#import "ARResource.h"
#import "ARErrors.h"

#import <ActiveSupportKit/ActiveSupportKit.h>

Class ARServiceDefaultConnectionClass;

@implementation ARService

// Should this method exist at class-scope or instance-scope?
+ (Class)defaultConnectionClass
{
	if (ARServiceDefaultConnectionClass == NULL)
	{
		ARServiceDefaultConnectionClass = [ARURLConnection class];
	}
	return ARServiceDefaultConnectionClass;
}

+ (void)setDefaultConnectionClass:(Class)aClass
{
	ARServiceDefaultConnectionClass = aClass;
}

// designated initialiser
- (id)init
{
	self = [super init];
	if (self)
	{
		[self setTimeout:60.0];
	}
	return self;
}

// The following initialisers are not designated initialisers. Note the messages
// to -[self init] rather than -[super init], a small but important
// difference. These are just convenience initialisers: a way to initialise and
// assign the site URL at one and the same time, or site plus element name.

- (id)initWithSite:(NSURL *)site
{
	self = [self init];
	if (self)
	{
		[self setSite:site];
	}
	return self;
}

- (id)initWithSite:(NSURL *)site elementName:(NSString *)elementName
{
	self = [self initWithSite:site];
	if (self)
	{
		[self setElementName:elementName];
	}
	return self;
}

//------------------------------------------------------------------------------
#pragma mark                                         Schema and Known Attributes
//------------------------------------------------------------------------------

@synthesize schema = _schema;

- (NSArray *)knownAttributes
{
	return [[self schema] allKeys];
}

//------------------------------------------------------------------------------
#pragma mark                                                                Site
//------------------------------------------------------------------------------

@synthesize site = _site;

- (NSURL *)siteWithPrefixParameter
{
	return [NSURL URLWithString:[NSString stringWithFormat:@"%@/:%@", [self collectionNameLazily], [self foreignKey]] relativeToURL:[self site]];
}

//------------------------------------------------------------------------------
#pragma mark                                                              Format
//------------------------------------------------------------------------------

@synthesize format = _format;

// lazy getter
- (id<ARFormat>)formatLazily
{
	id<ARFormat> format = [self format];
	if (format == nil)
	{
		[self setFormat:format = [self defaultFormat]];
	}
	return format;
}

//------------------------------------------------------------------------------
#pragma mark                                                             Timeout
//------------------------------------------------------------------------------

@synthesize timeout = _timeout;

//------------------------------------------------------------------------------
#pragma mark                                                          Connection
//------------------------------------------------------------------------------

// Lazily constructs a connection using the default connection class.
- (ARConnection *)connectionLazily
{
	if (_connection == nil)
	{
		[self setConnection:[[[[self class] defaultConnectionClass] alloc] init]];
	}
	return _connection;
}

- (void)setConnection:(ARConnection *)connection
{
	[connection setSite:[self site]];
	[connection setFormat:[self formatLazily]];
	[connection setTimeout:[self timeout]];
	_connection = connection;
}

//------------------------------------------------------------------------------
#pragma mark                                                             Headers
//------------------------------------------------------------------------------

@synthesize headers = _headers;

- (NSMutableDictionary *)headersLazily
{
	NSMutableDictionary *headers = [self headers];
	if (headers == nil)
	{
		[self setHeaders:headers = [NSMutableDictionary dictionary]];
	}
	return headers;
}

//------------------------------------------------------------------------------
#pragma mark                                        Element and Collection Names
//------------------------------------------------------------------------------

@synthesize elementName = _elementName;

@synthesize collectionName = _collectionName;

// lazy getter
- (NSString *)elementNameLazily
{
	NSString *elementName = [self elementName];
	if (elementName == nil)
	{
		[self setElementName:elementName = [self defaultElementName]];
	}
	return elementName;
}

// lazy getter
- (NSString *)collectionNameLazily
{
	NSString *collectionName = [self collectionName];
	if (collectionName == nil)
	{
		[self setCollectionName:collectionName = [self defaultCollectionName]];
	}
	return collectionName;
}

//------------------------------------------------------------------------------
#pragma mark                                             Primary and Foreign Key
//------------------------------------------------------------------------------

@synthesize primaryKey = _primaryKey;

- (NSString *)primaryKeyLazily
{
	NSString *primaryKey = [self primaryKey];
	if (primaryKey == nil)
	{
		[self setPrimaryKey:primaryKey = [self defaultPrimaryKey]];
	}
	return primaryKey;
}

- (NSString *)foreignKey
{
	return [[ASInflector defaultInflector] foreignKey:[self elementNameLazily] separateClassNameAndIDWithUnderscore:YES];
}

//------------------------------------------------------------------------------
#pragma mark                                                              Prefix
//------------------------------------------------------------------------------

@synthesize prefixSource = _prefixSource;

// lazy getter
- (NSString *)prefixSourceLazily
{
	NSString *prefixSource = [self prefixSource];
	if (prefixSource == nil)
	{
		prefixSource = [self defaultPrefixSource];
		
		// Automatically append a trailing slash, but if and only if the prefix
		// source does not already terminate with a slash.
		if ([prefixSource length] == 0 || ![[prefixSource substringFromIndex:[prefixSource length] - 1] isEqualToString:@"/"])
		{
			prefixSource = [prefixSource stringByAppendingString:@"/"];
		}
		
		[self setPrefixSource:prefixSource];
	}
	return prefixSource;
}

- (NSString *)prefixWithOptions:(NSDictionary *)options
{
	// The following implementation duplicates some of the functionality
	// concerning extraction of prefix parameters from the prefix. See the
	// -prefixParameters method. Nevertheless, the replace-in-place approach
	// makes the string operations more convenient. The implementation does not
	// need to cut apart the colon from its parameter word. The regular
	// expression identifies the substitution on our behalf, making it easier to
	// remove the colon, access the prefix parameter minus its colon and replace
	// both; and all at the same time.
	if (options == nil)
	{
		return [self prefixSourceLazily];
	}
	return [[NSRegularExpression regularExpressionWithPattern:@":(\\w+)" options:0 error:NULL] stringByReplacingMatchesInString:[self prefixSourceLazily] replacementStringForResult:^NSString *(NSTextCheckingResult *result, NSString *inString, NSInteger offset) {
		return [[[options objectForKey:[[result regularExpression] replacementStringForResult:result inString:inString offset:offset template:@"$1"]] description] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	}];
}

//------------------------------------------------------------------------------
#pragma mark                                                               Paths
//------------------------------------------------------------------------------

- (NSString *)elementPathForID:(NSNumber *)ID prefixOptions:(NSDictionary *)prefixOptions queryOptions:(NSDictionary *)queryOptions
{
	if (queryOptions == nil)
	{
		[self splitOptions:prefixOptions prefixOptions:&prefixOptions queryOptions:&queryOptions];
	}
	NSString *IDString = [[ID stringValue] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	return [NSString stringWithFormat:@"%@%@/%@.%@%@", [self prefixWithOptions:prefixOptions], [self collectionNameLazily], IDString, [[self formatLazily] extension], ARQueryStringForOptions(queryOptions)];
}

// Answers the path for creating a new element. Note, the term “new” appearing
// at the start of the method name does not, in this case, signify a retained
// result.
- (NSString *)newElementPathWithPrefixOptions:(NSDictionary *)prefixOptions
{
	return [NSString stringWithFormat:@"%@%@/new.%@", [self prefixWithOptions:prefixOptions], [self collectionNameLazily], [[self formatLazily] extension]];
}

- (NSString *)collectionPathWithPrefixOptions:(NSDictionary *)prefixOptions queryOptions:(NSDictionary *)queryOptions
{
	if (queryOptions == nil)
	{
		[self splitOptions:prefixOptions prefixOptions:&prefixOptions queryOptions:&queryOptions];
	}
	return [NSString stringWithFormat:@"%@%@.%@%@", [self prefixWithOptions:prefixOptions], [self collectionNameLazily], [[self formatLazily] extension], ARQueryStringForOptions(queryOptions)];
}

//------------------------------------------------------------------------------
#pragma mark                                                    RESTful Services
//------------------------------------------------------------------------------

// Building with attributes. Should this be a class or instance method? Rails
// implements this as a class method, or to be more specific, a singleton
// method. Objective-C does not provide the singleton class
// paradigm. ActiveResourceKit folds the Rails singleton methods to instance
// methods.
- (void)buildWithAttributes:(NSDictionary *)attributes completionHandler:(ARResourceCompletionHandler)completionHandler
{
	// Use the new element path. Construct the request URL using this path but
	// make it relative to the site URL. The NSURL class combines the new
	// element path with the site, using the site's scheme, host and port.
	NSString *path = [self newElementPathWithPrefixOptions:nil];
	[self get:path completionHandler:^(ARHTTPResponse *response, id object, NSError *error) {
		if (object && error == nil)
		{
			if ([object isKindOfClass:[NSDictionary class]])
			{
				NSMutableDictionary *attrs = [NSMutableDictionary dictionaryWithDictionary:object];
				[attrs addEntriesFromDictionary:attributes];
				completionHandler(response, [[ARResource alloc] initWithService:self attributes:attrs], nil);
			}
			else
			{
				// The response body decodes successfully but it does not
				// decode to a dictionary. It must be something else, either
				// an array, a string or some other primitive type. In which
				// case, building with attributes must fail even though
				// ostensibly the operation has succeeded. Set up an error.
				completionHandler(response, nil, [NSError errorWithDomain:ARErrorDomain code:ARUnsupportedRootObjectTypeError userInfo:nil]);
			}
		}
		else
		{
			completionHandler(response, object, error);
		}
	}];
}

- (void)createWithAttributes:(NSDictionary *)attributes completionHandler:(ARResourceCompletionHandler)completionHandler
{
	ARResource *resource = [[ARResource alloc] initWithService:self attributes:attributes];
	[resource saveWithCompletionHandler:^(ARHTTPResponse *response, NSError *error) {
		completionHandler(response, error == nil ? resource : nil, error);
	}];
}

- (void)findAllWithOptions:(NSDictionary *)options completionHandler:(ARResourcesCompletionHandler)completionHandler
{
	return [self findEveryWithOptions:options completionHandler:completionHandler];
}

- (void)findFirstWithOptions:(NSDictionary *)options completionHandler:(ARResourceCompletionHandler)completionHandler
{
	return [self findEveryWithOptions:options completionHandler:^(ARHTTPResponse *response, NSArray *resources, NSError *error) {
		completionHandler(response, resources && [resources count] ? [resources objectAtIndex:0] : nil, error);
	}];
}

- (void)findLastWithOptions:(NSDictionary *)options completionHandler:(ARResourceCompletionHandler)completionHandler
{
	return [self findEveryWithOptions:options completionHandler:^(ARHTTPResponse *response, NSArray *resources, NSError *error) {
		completionHandler(response, resources && [resources count] ? [resources lastObject] : nil, error);
	}];
}

- (void)findSingleWithID:(NSNumber *)ID options:(NSDictionary *)options completionHandler:(ARResourceCompletionHandler)completionHandler
{
	NSDictionary *prefixOptions = nil;
	NSDictionary *queryOptions = nil;
	[self splitOptions:options prefixOptions:&prefixOptions queryOptions:&queryOptions];
	NSString *path = [self elementPathForID:ID prefixOptions:prefixOptions queryOptions:queryOptions];
	[self get:path completionHandler:^(ARHTTPResponse *response, id object, NSError *error) {
		if (object && error == nil)
		{
			if ([object isKindOfClass:[NSDictionary class]])
			{
				completionHandler(response, [self instantiateRecordWithAttributes:object prefixOptions:prefixOptions], nil);
			}
			else
			{
				completionHandler(response, nil, [NSError errorWithDomain:ARErrorDomain code:ARUnsupportedRootObjectTypeError userInfo:nil]);
			}
		}
		else
		{
			completionHandler(response, object, error);
		}
	}];
}

- (void)findOneWithOptions:(NSDictionary *)options completionHandler:(ARResourceCompletionHandler)completionHandler
{
	NSString *from = [options objectForKey:ARFromKey];
	if (from && [from isKindOfClass:[NSString class]])
	{
		NSString *path = [NSString stringWithFormat:@"%@%@", from, ARQueryStringForOptions([options objectForKey:ARParamsKey])];
		[self get:path completionHandler:^(ARHTTPResponse *response, id object, NSError *error) {
			if (object && error == nil)
			{
				if ([object isKindOfClass:[NSDictionary class]])
				{
					completionHandler(response, [self instantiateRecordWithAttributes:object prefixOptions:nil], nil);
				}
				else
				{
					completionHandler(response, nil, [NSError errorWithDomain:ARErrorDomain code:ARUnsupportedRootObjectTypeError userInfo:nil]);
				}
			}
			else
			{
				completionHandler(response, object, error);
			}
		}];
	}
}

- (void)deleteWithID:(NSNumber *)ID options:(NSDictionary *)options completionHandler:(void (^)(ARHTTPResponse *response, NSError *error))completionHandler
{
	NSString *path = [self elementPathForID:ID prefixOptions:options queryOptions:nil];
	[self delete:path completionHandler:^(ARHTTPResponse *response, id object, NSError *error) {
		completionHandler(response, error);
	}];
}

- (void)existsWithID:(NSNumber *)ID options:(NSDictionary *)options completionHandler:(void (^)(ARHTTPResponse *response, BOOL exists, NSError *error))completionHandler
{
	// This implementation looks a little strange. Why would you pass an ID of
	// nil? However, it fairly accurately mirrors the Rails implementation, to
	// the extent possible at least. ID is nil when the resource is new.
	if (ID)
	{
		NSDictionary *prefixOptions = nil;
		NSDictionary *queryOptions = nil;
		[self splitOptions:options prefixOptions:&prefixOptions queryOptions:&queryOptions];
		NSString *path = [self elementPathForID:ID prefixOptions:prefixOptions queryOptions:queryOptions];
		[self head:path completionHandler:^(ARHTTPResponse *response, id object, NSError *error) {
			completionHandler(response, [response code] == 200, error);
		}];
	}
	else
	{
		completionHandler(nil, NO, nil);
	}
}

@end
