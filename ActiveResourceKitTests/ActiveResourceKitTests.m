// ActiveResourceKitTests ActiveResourceKitTests.m
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

#import "ActiveResourceKitTests.h"

#import <ActiveResourceKit/ActiveResourceKit.h>

#import "Person.h"

// for ARIDFromResponse
#import "Private.h"

NSURL *ActiveResourceKitTestsBaseURL()
{
	return [NSURL URLWithString:@RAILS_BASE_URL];
}

//------------------------------------------------------------------------------
#pragma mark                                                        Person Class
//------------------------------------------------------------------------------

@interface MyObject : ARService
@end

@implementation MyObject
@end

@interface Post : ARService
@end

@implementation Post
@end

@interface PostComment : ARService
@end

@implementation PostComment
@end

@implementation ActiveResourceKitTests

- (void)setUp
{
	post = [[Post alloc] initWithSite:ActiveResourceKitTestsBaseURL()];
	postComment = [[PostComment alloc] initWithSite:[NSURL URLWithString:@"/posts/:post_id" relativeToURL:ActiveResourceKitTestsBaseURL()]];
	
	// You cannot use Comment as a class name. The CarbonCore framework (a
	// CoreServices sub-framework) steals this symbol first. Apple has already
	// polluted the namespace with a Comment type definition. So we will call it
	// PostComment instead, meaning a comment on a post within a blog. However,
	// by default, ARService will translate PostComment to post_comment when
	// constructing the resource paths. There is an incongruence between
	// Objective-C and Rails, unless Rails uses the same name of course. But the
	// comments are just comments in the imaginary Rails application. Hence we
	// need now to override the element name. This makes use of the lazy-getter
	// approach to configuration. Setting it now overrides the default.
	[postComment setElementName:@"comment"];
}

- (void)testNewPerson
{
	Person *ryan = [[Person alloc] init];
	[ryan setAttributes:[NSDictionary dictionaryWithObjectsAndKeys:@"Ryan", @"first", @"Daigle", @"last", nil]];
	
	// At this point, service should be nil because nothing has as yet accessed the
	// service lazily! The resource only exists in memory; hence not persisted, a
	// new resource, a new record.
	STAssertNil([ryan service], nil);
	STAssertFalse([ryan persisted], nil);
	STAssertTrue([ryan isNew], nil);
	STAssertTrue([ryan isNewRecord], nil);
	
	// Use key-value coding to verify the contents of the active resource
	// instance, albeit not yet persisted.
	STAssertEqualObjects([ryan valueForKey:@"first"], @"Ryan", nil);
	STAssertEqualObjects([ryan valueForKey:@"last"], @"Daigle", nil);
}

- (void)testSetUpSite
{
	// Start off with a very simple test. Just set up a resource. Load it with
	// its site URL. Then ensure that the site property responds as it should,
	// i.e. as an URL. This test exercises NSURL more than
	// ARActiveResource. Never mind.
	//
	// Make sure that the site URL can accept “prefix parameters,” as Rails dubs
	// them. This term refers to path elements beginning with a colon and
	// followed by a regular-expression word. ActiveResourceKit substitutes
	// these for actual parameters.
	ARService *service = [[ARService alloc] init];
	[service setSite:[NSURL URLWithString:@"http://user:password@localhost:3000/resources/:resource_id?x=y;a=b"]];
	STAssertEqualObjects([[service site] scheme], @"http", nil);
	STAssertEqualObjects([[service site] user], @"user", nil);
	STAssertEqualObjects([[service site] password], @"password", nil);
	STAssertEqualObjects([[service site] host], @"localhost", nil);
	STAssertEqualObjects([[service site] port], [NSNumber numberWithInt:3000], nil);
	STAssertEqualObjects([[service site] path], @"/resources/:resource_id", nil);
	STAssertEqualObjects([[service site] query], @"x=y;a=b", nil);
}

- (void)testEmptyPath
{
	// Empty URL paths should become empty strings after parsing. This tests the
	// Foundation frameworks implementation of an URL.
	ARService *service = [[ARService alloc] init];
	[service setSite:[NSURL URLWithString:@"http://user:password@localhost:3000"]];
	STAssertEqualObjects([[service site] path], @"", nil);
}

- (void)testPrefixSource
{
	// Running the following piece of Ruby:
	//
	//	require 'active_resource'
	//	
	//	class Resource < ActiveResource::Base
	//	  self.prefix = '/resources/:resource_id'
	//	end
	//	
	//	p Resource.prefix(:resource_id => 1)
	//
	// gives you the following output:
	//
	//	"/resources/1"
	//
	// The following test performs the same thing but using Objective-C.
	//
	// Note that the options can contain numbers and other objects. Method
	// -[ARActiveResource prefixWithOptions:] places the “description” of the
	// object answering to the prefix-parameter key (resource_id in this test
	// case). Hence the options dictionary can contain various types answering
	// to -[NSObject description], not just strings.
	ARService *service = [[ARService alloc] init];
	[service setPrefixSource:@"/resources/:resource_id"];
	NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:@"resource_id"];
	NSString *prefix = [service prefixWithOptions:options];
	STAssertEqualObjects(prefix, @"/resources/1", nil);
}

- (void)testPrefixParameterWithPercentEscapes
{
	ARService *service = [[ARService alloc] init];
	[service setPrefixSource:@"/resources/:resource_id"];
	NSString *prefix = [service prefixWithOptions:[NSDictionary dictionaryWithObject:@"some text" forKey:@"resource_id"]];
	STAssertEqualObjects(prefix, @"/resources/some%20text", nil);
}

- (void)testElementName
{
	STAssertEqualObjects([[[[Person alloc] init] serviceLazily] elementNameLazily], @"person", nil);
}

- (void)testCollectionName
{
	STAssertEqualObjects([[[[Person alloc] init] serviceLazily] collectionNameLazily], @"people", nil);
}

- (void)testElementPath
{
	NSString *elementPath = [post elementPathForID:[NSNumber numberWithInt:1] prefixOptions:nil queryOptions:nil];
	STAssertEqualObjects(elementPath, @"/posts/1.json", nil);
}

- (void)testElementPathWithQuery
{
	NSDictionary *query = [NSDictionary dictionaryWithObject:@"value string" forKey:@"key string"];
	NSString *elementPath = [post elementPathForID:[NSNumber numberWithInt:1] prefixOptions:nil queryOptions:query];
	STAssertEqualObjects(elementPath, @"/posts/1.json?key%20string=value%20string", nil);
}

- (void)testNewElementPath
{
	NSString *newElementPath = [post newElementPathWithPrefixOptions:nil];
	STAssertEqualObjects(newElementPath, @"/posts/new.json", nil);
}

- (void)testCollectionPath
{
	NSString *collectionPath = [post collectionPathWithPrefixOptions:nil queryOptions:nil];
	STAssertEqualObjects(collectionPath, @"/posts.json", nil);
}

- (void)testJSONFormat
{
	ARJSONFormat *format = [ARJSONFormat JSONFormat];
	STAssertEqualObjects([format extension], @"json", nil);
	STAssertEqualObjects([format MIMEType], @"application/json", nil);
}

- (void)testNestedResources
{
	NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:5] forKey:@"post_id"];
	STAssertEqualObjects([postComment newElementPathWithPrefixOptions:options], @"/posts/5/comments/new.json", nil);
	STAssertEqualObjects([postComment collectionPathWithPrefixOptions:options queryOptions:nil], @"/posts/5/comments.json", nil);
}

- (void)testBuild
{
	// This test only succeeds when the server-side is up and running. It sends
	// a GET request to localhost, port 3000. The Test scheme launches a Rails
	// server temporarily, if necessary, in order to answer the requests. The
	// scheme pre-action comprises a shell script containing:
	//
	//	cd "$SRCROOT/active-resource-kit-tests"
	//	[ -f tmp/pids/server.pid ] || "$HOME/.rvm/bin/rvm-shell" -c "rake db:setup db:fixtures:load ; rails s -d -P `pwd`/tmp/pids/server-xcode.pid"
	//
	// The script launches a Rails server in the background using RVM, if and
	// only if the default server is not already running. It assumes that RVM is
	// installed and carries the necessary Ruby gems. The post-action for the
	// Test scheme contains the following shell script. It sends an interrupt
	// signal to the server to shut it down.
	//
	//	cd "$SRCROOT/active-resource-kit-tests"
	//	[ -f tmp/pids/server-xcode.pid ] && kill -INT `cat tmp/pids/server-xcode.pid`
	//
	[post buildWithAttributes:nil completionHandler:^(ARHTTPResponse *response, ARResource *resource, NSError *error) {
		STAssertNotNil(resource, nil);
		STAssertNil(error, nil);
		[self setStop:YES];
	}];
	[self runUntilStop];
}

- (void)testFindAll
{
	[post findAllWithOptions:nil completionHandler:^(ARHTTPResponse *response, NSArray *resources, NSError *error) {
		STAssertNotNil(resources, nil);
		STAssertNil(error, nil);
		// Without assuming exactly what the server-side records contain, just
		// assert that there are some then log their contents.
		for (ARResource *resource in resources)
		{
			NSLog(@"%@", [resource attributes]);
		}
		[self setStop:YES];
	}];
	[self runUntilStop];
}

- (void)testFindFirst
{
	[post findFirstWithOptions:nil completionHandler:^(ARHTTPResponse *response, ARResource *resource, NSError *error) {
		STAssertNotNil(resource, nil);
		STAssertNil(error, nil);
		NSLog(@"%@", [resource attributes]);
		[self setStop:YES];
	}];
	[self runUntilStop];
}

- (void)testCreate
{
	Person *person = [[Person alloc] init];
	[person saveWithCompletionHandler:^(ARHTTPResponse *response, NSError *error) {
		STAssertNil(error, nil);
		[self setStop:YES];
	}];
	[self runUntilStop];
}

- (void)testIDFromResponse
{
	NSDictionary *headerFields = [NSDictionary dictionaryWithObject:@"/foo/bar/1" forKey:@"Location"];
	ARHTTPResponse *response = [[ARHTTPResponse alloc] initWithURLResponse:[[NSHTTPURLResponse alloc] initWithURL:nil statusCode:0 HTTPVersion:nil headerFields:headerFields] body:nil];
	STAssertEqualObjects(ARIDFromResponse(response), [NSNumber numberWithInt:1], nil);
}

@end
