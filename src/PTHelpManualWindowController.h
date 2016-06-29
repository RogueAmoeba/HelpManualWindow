//
//  PTHelpManualWindowController.h
//  Protein
//
//  Created by Quentin Carnicelli on 10/5/11.
//			   Jeff Johnson - 11/17/11
//  Copyright 2011-2014 Rogue Amoeba Software, LLC. All rights reserved.
//

#import <WebKit/WebKit.h>


@interface PTHelpManualWindowController : NSWindowController 
{
	IBOutlet WebView *_webView;
	IBOutlet WebView *_hiddenWebView;
	IBOutlet WebView *_printWebView;
	IBOutlet NSWindow *_printWindow;
	
	NSString *_helpManualFolderPath;
	NSString *_temporaryPath;
	NSString *_searchTemplate;
	NSString *_searchText;
	NSArray *_searchPages;
	NSUInteger _searchPageIndex;
	NSMutableArray *_searchResults;
}

- (id) initWithBundle:(NSBundle *)bundle;

- (BOOL)canGoBack;
- (BOOL)canGoForward;
- (IBAction)navigateInHistory:(id)sender;

- (IBAction)searchTheManual:(id)sender;

- (IBAction)printDocument:(id)sender;

- (void)showPageNamed: (NSString*)name;

@end


@interface PTHelpManualWindowController ( PTHelpManualTester )
- (id) initWithHelpManualFolderPath:(NSString *)path;
@end


@interface PTHelpManualNavigateToolbarItem : NSToolbarItem
{}
@end
