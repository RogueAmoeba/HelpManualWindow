//
//  AppDelegate.h
//  HelpManualTest
//
//  Created by Quentin Carnicelli on 5/31/14.
//  Copyright (c) 2014 Rogue Amoeba Software, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PTHelpManualWindowController;

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
	PTHelpManualWindowController* _helpWindow;
}

@end
