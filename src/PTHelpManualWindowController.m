//
//  PTHelpManualWindowController.m
//  Protein
//
//  Created by Quentin Carnicelli on 10/5/11.
//  Copyright 2011 Rogue Amoeba Software, LLC. All rights reserved.
//

#import "PTHelpManualWindowController.h"

#if __PROTEIN__
#import "PTAppController.h"
#import "PTErrorAdditions.h"
#else
#define PTLogWarning NSLog
#endif


@interface PTHelpManualSearchResult : NSObject
{
	NSString *_firstResult;
	NSUInteger _hitCount;
	NSString *_title;
	NSString *_urlString;
}
@end

@implementation PTHelpManualSearchResult

- (void)dealloc
{
	[_firstResult release];
	[_title release];
	[_urlString release];
	[super dealloc];
}

- (id)initWithTitle: (NSString *)title URLString: (NSString *)url hitCount: (NSUInteger)hitCount firstResult: (NSString *)firstResult // Designated initializer
{
	self = [super init];
	if ( self != nil )
	{
		_firstResult = [firstResult copy];
		_hitCount = hitCount;
		_title = [title copy];
		_urlString = [url copy];
	}
	return self;
}

- (NSString *)firstResult
{
	return [[_firstResult retain] autorelease];
}

- (NSUInteger)hitCount
{
	return _hitCount;
}

- (NSString *)title
{
	return [[_title retain] autorelease];
}

- (NSString *)URLString
{
	return [[_urlString retain] autorelease];
}

@end

@interface PTHelpManualWindowController ()
- (void)cancelSearch;
- (void)loadNextHiddenPageWithSearchResult:(PTHelpManualSearchResult *)result;
- (NSString *)URLStringFromFilePath:(NSString *)path;
@end

@implementation PTHelpManualWindowController

#pragma mark NSObject

- (id)init
{
	self = [self initWithBundle: nil];
	return self;
}

- (void)dealloc
{
	[_helpManualFolderPath release];
	[_searchPages release];
	[_searchResults release];
	[_searchTemplate release];
	[_searchText release];
	[_temporaryPath release];
	
	[super dealloc];
}

#pragma mark NSWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	#if __PROTEIN__
	NSString* appName = [[PTAppController sharedController] productName];
	#else
	NSString* appName = [[NSProcessInfo processInfo] processName];
	#endif
	
	NSString *title = [NSString stringWithFormat: @"%@ Manual", appName];
	[[self window] setTitle: title];
	[_printWindow setTitle: title];
	
	WebPreferences *printPreferences = [_printWebView preferences];
	[printPreferences setShouldPrintBackgrounds: YES];
	[printPreferences setUsesPageCache: NO];
	[printPreferences setPrivateBrowsingEnabled: YES];
}

#pragma mark WebFrameLoadDelegate

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
	if ( frame == [sender mainFrame] )
	{
		if ( sender == _printWebView )
		{
			PTLogWarning( @"Error loading printable page: %@", error );
		}
		else
		{
			[self loadNextHiddenPageWithSearchResult: nil];
		}
	}
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
	if ( frame == [sender mainFrame] )
	{
		if ( sender == _printWebView )
		{
			PTLogWarning( @"Error loading printable page: %@", error );
		}
		else
		{
			[self loadNextHiddenPageWithSearchResult: nil];
		}
	}
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    //Disable elasticity to prevent stupid scroll bounce (2013-07)
    [frame.frameView.documentView.enclosingScrollView setVerticalScrollElasticity: NSScrollElasticityNone];
    [frame.frameView.documentView.enclosingScrollView setHorizontalScrollElasticity: NSScrollElasticityNone];
    
    if( sender == _webView ) //Don't do anything for our main view
        return;

    if ( frame != [sender mainFrame] )
		return;

	if ( sender == _printWebView )
	{
		[[[frame frameView] documentView] print: nil];
		return;
	}
	
    //Rest of this for for the HiddenWeb
	if ( _searchText == nil )
		return;
	
    DOMDocument* document = [sender mainFrameDocument];
	DOMElement *element = [document getElementById: @"main"];
	if ( element == nil )
	{
		element = [document body];
	}
	
	DOMRange *range;
	if ( element != nil )
	{
		range = [document createRange];
		[range selectNode: element];
		[range collapse: YES];
	}
	else
	{
		range = nil;
	}
	
    [sender setSelectedDOMRange:range affinity:NSSelectionAffinityDownstream];
	
	NSUInteger hitCount = 0u;
	NSString *firstResult = nil;
	while ( [_hiddenWebView searchFor: _searchText direction: YES caseSensitive: NO wrap: NO] )
	{
		if ( hitCount == 0u )
		{
			[sender selectSentence:nil];
			firstResult = [[sender selectedDOMRange] toString];
		}
		++hitCount;
	}
	
	PTHelpManualSearchResult *result;
	if ( hitCount > 0u )
	{
		result = [[[PTHelpManualSearchResult alloc] initWithTitle: [sender mainFrameTitle] URLString: [sender mainFrameURL] hitCount: hitCount firstResult: firstResult] autorelease];
	}
	else
	{
		result = nil;
	}
	
	[self loadNextHiddenPageWithSearchResult: result];
}

#pragma mark WebPolicyDelegate

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id < WebPolicyDecisionListener >)listener
{
	NSURL *url = [actionInformation objectForKey:WebActionOriginalURLKey];
	
	if( [url isFileURL] )
	{
		[listener use];
		return;
	}
	
	// We want to open web URLs in a browser, not in our WebView
	[listener ignore];
	
	[[NSWorkspace sharedWorkspace] openURL: url];
}

#pragma mark IBAction

- (IBAction)navigateInHistory:(id)sender
{
	NSInteger selectedSegment = [sender selectedSegment];
	if ( selectedSegment == 0 )
	{
		[_webView goBack:sender];
	}
	else if ( selectedSegment == 1 )
	{
		[_webView goForward:sender];
	}
}

- (IBAction)searchTheManual:(id)sender
{
	if ( _searchPages == nil )
	{
		NSError *error;
		NSArray *searchPages = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: _helpManualFolderPath error: &error];
		if ( searchPages == nil )
		{
			PTLogWarning( @"Error getting contents of %@: %@", _helpManualFolderPath, error );
			return;
		}
		
		NSString *searchTemplatePath = [_helpManualFolderPath stringByAppendingPathComponent:@"noindex-searchtemplate.html"];
		NSStringEncoding encoding;
		NSString *searchTemplate = [NSString stringWithContentsOfFile: searchTemplatePath usedEncoding: &encoding error: &error];
		if ( searchTemplate == nil )
		{
			PTLogWarning( @"Error getting contents of %@: %@", searchTemplatePath, error );
			return;
		}
		
		NSString *temporaryPath = [NSTemporaryDirectory() stringByAppendingPathComponent: [_helpManualFolderPath lastPathComponent]];
		if ( temporaryPath == nil )
		{
			PTLogWarning( @"Can't get temporary directory." );
			return;
		}
		
		// Make a copy of the help folder so that we can save temporary search results there and get the css and image relative references correct
		NSFileManager *fileManager = [NSFileManager defaultManager];
		[fileManager removeItemAtPath: temporaryPath error: &error]; // We don't care whether this succeeds
		if ( ![fileManager copyItemAtPath: _helpManualFolderPath toPath: temporaryPath error: &error] )
		{
			PTLogWarning( @"Error copying '%@' to '%@': %@", _helpManualFolderPath, temporaryPath, error );
			return;
		}
		
		_searchPages = [searchPages copy];
		_searchTemplate = [searchTemplate copy];
		_temporaryPath = [temporaryPath copy];
	}
	
	[self cancelSearch];
	
	NSString *searchText = [sender stringValue];
	if ( searchText == nil || [searchText length] == 0 )
		return;
	
	_searchText = [searchText copy];
	_searchResults = [[NSMutableArray alloc] initWithCapacity: [_searchPages count]];
	[self loadNextHiddenPageWithSearchResult: nil];
}

- (IBAction)printDocument:(id)sender
{
	NSString *printablePagePath = [_helpManualFolderPath stringByAppendingPathComponent: @"noindex-printable.html"];
	[_printWebView setMainFrameURL: [self URLStringFromFilePath: printablePagePath]];
}

#pragma mark Private

- (void)cancelSearch
{
	if ( _searchText != nil )
	{
		[_searchText release];
		_searchText = nil;
		_searchPageIndex = 0u;
		[_searchResults release];
		_searchResults = nil;
		[_hiddenWebView stopLoading: self];
	}
}

- (void)loadNextHiddenPageWithSearchResult:(PTHelpManualSearchResult *)result
{
	if ( _searchResults == nil )
		return;
	
	if ( result != nil )
	{
		[_searchResults addObject: result];
	}
	
	if ( [_searchPages count] == _searchPageIndex )
	{
		NSUInteger totalMatches = 0u;
		
		NSString *resultsString;
		if ( [_searchResults count] == 0u )
		{
			resultsString = @"<p>Sorry - this search returned no results.</p>";
		}
		else
		{
			resultsString = @"";
			
			for ( PTHelpManualSearchResult *result in _searchResults )
			{
				NSUInteger hitCount = [result hitCount];
				NSString *suffix = ( hitCount > 1u ) ? @"es" : @"";
				totalMatches += hitCount;
				
				NSString *resultString = [NSString stringWithFormat: @"<h2><a href=\"%@\">%@</a> (%lu match%@)</h2>", [result URLString], [result title], (unsigned long)hitCount, suffix];
				resultsString = [resultsString stringByAppendingString: resultString];
				NSString *firstResult = [result firstResult];
				if ( firstResult != nil )
				{
					firstResult = [firstResult stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
					if ( [firstResult length] > 0u )
					{
						resultsString = [resultsString stringByAppendingFormat: @"<div class=\"result\">%@</div>", firstResult];
					}
				}
			}
			
		}
		
		NSString *totalString = ( totalMatches == 1u ) ? @"" : @"s";
		resultsString = [NSString stringWithFormat: @"<h1>Search results for <span class=\"darker\">\"%@\" (%lu total result%@)</span></h1>%@", _searchText, (unsigned long)totalMatches, totalString, resultsString];
		
		NSString *htmlString = [_searchTemplate stringByReplacingOccurrencesOfString: @"$$$PlaceholderDoNotEdit$$$" withString: resultsString];
		
		// We need to save it to a file, otherwise WebView won't add it to the back-forward list.
		NSString *fileName = [[[NSProcessInfo processInfo] globallyUniqueString] stringByAppendingPathExtension: @"html"];
		NSString *temporaryPath = [_temporaryPath stringByAppendingPathComponent: fileName];
		NSError *error;
		[htmlString writeToFile: temporaryPath atomically: NO encoding: NSUTF8StringEncoding error: &error];
		
		[self cancelSearch];
		
		[_webView setMainFrameURL: [self URLStringFromFilePath: temporaryPath]];
	}
	else
	{
		NSString *page = [_searchPages objectAtIndex: _searchPageIndex];
		++_searchPageIndex;
		
		NSString *pathExtension = [page pathExtension];
		if ( [pathExtension caseInsensitiveCompare: @"html"] == NSOrderedSame && ![page hasPrefix: @"noindex-"] )
		{
			NSString *path = [_helpManualFolderPath stringByAppendingPathComponent: page];
			[_hiddenWebView setMainFrameURL: [self URLStringFromFilePath: path]];
		}
		else
		{
			[self loadNextHiddenPageWithSearchResult: nil];
		}
	}
}

- (NSString *)URLStringFromFilePath:(NSString *)path
{
	NSURL *fileURL = [NSURL fileURLWithPath: path];
	NSString *absoluteString = [fileURL absoluteString];
	return absoluteString;
}

#pragma mark Public

- (id) initWithBundle:(NSBundle *)bundle
{
	self = [super initWithWindowNibName: @"PTHelpManual"];
	if ( self != nil )
	{
		if ( bundle == nil )
			bundle = [NSBundle mainBundle];
		NSArray *helpManuals = [bundle pathsForResourcesOfType: @"manualFolder" inDirectory: nil];
		if ( helpManuals != nil && [helpManuals count] > 0 )
		{
			_helpManualFolderPath = [[helpManuals objectAtIndex: 0] copy];
		}
	}
	return self;
}

- (BOOL)canGoBack
{
	return [_webView canGoBack];
}

- (BOOL)canGoForward
{
	return [_webView canGoForward];
}

- (void)showPageNamed: (NSString*)name
{
	if ( _helpManualFolderPath == nil )
	{
		PTLogWarning( @"Help manual folder could not be found." );
		return;
	}
	
	[self showWindow: self]; // Do this first, otherwise _webView might be nil.
	
	[self cancelSearch];
	
	if ( name == nil )
		name = @"index";
	
	NSString *page = [name stringByAppendingPathExtension: @"html"];
	NSString *pagePath = [_helpManualFolderPath stringByAppendingPathComponent: page];
	
	[_webView setMainFrameURL: [self URLStringFromFilePath: pagePath]];
}

@end


@implementation PTHelpManualNavigateToolbarItem

#pragma mark NSToolbarItem

- (void)validate
{
	id target = [self target];
	BOOL canGoBack = [target canGoBack];
	BOOL canGoForward = [target canGoForward];
	
	NSSegmentedControl *view = (NSSegmentedControl *)[self view];
	[view setEnabled:canGoBack forSegment:0];
	[view setEnabled:canGoForward forSegment:1];
}

@end
