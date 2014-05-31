//
//  AppDelegate.m
//  HelpManualTest
//
//  Created by Quentin Carnicelli on 5/31/14.
//  Copyright (c) 2014 Rogue Amoeba Software, Inc. All rights reserved.
//

#import "AppDelegate.h"

#import "PTHelpManualWindowController.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	_helpWindow = [[PTHelpManualWindowController alloc] initWithBundle: nil];
	[_helpWindow showPageNamed: nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	[_helpWindow release];
}

@end
