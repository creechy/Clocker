//  Created by Abhishek Banthia on 11/4/15.
//  Copyright (c) 2015 Abhishek Banthia All rights reserved.
//

// Copyright (c) 2015, Abhishek Banthia
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
//
// Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
// INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
// EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


#import "PanelController.h"
#import "BackgroundView.h"
#import "StatusItemView.h"
#import "MenubarController.h"
#import <Crashlytics/Crashlytics.h>
#import "CLRatingCellView.h"
#import "CommonStrings.h"

#define OPEN_DURATION .15
#define CLOSE_DURATION .1

#define SEARCH_INSET 17

#define POPUP_HEIGHT 300
#define PANEL_WIDTH 280
#define MENU_ANIMATION_DURATION .1

#define BUFFER 2
#define MAX_TALL 15

#pragma mark -

#import "PreferencesWindowController.h"
#import "CommonStrings.h"

NSString *const CLPanelNibIdentifier = @"Panel";
NSString *const CLRatingCellViewIdentifier = @"ratingCellView";
NSString *const CLTimezoneCellViewIdentifier = @"timeZoneCell";


@implementation PanelController



#pragma mark -

- (id)initWithDelegate:(id<PanelControllerDelegate>)delegate
{
    self = [super initWithWindowNibName:CLPanelNibIdentifier];
    if (self != nil)
    {
        _delegate = delegate;
        self.window.backgroundColor = [NSColor whiteColor];
    }
    return self;
}

#pragma mark -

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    [self updateDefaultPreferences];
    
    // Make a fully skinned panel
    NSPanel *panel = (id)[self window];
    [panel setAcceptsMouseMovedEvents:YES];
    [panel setLevel:NSPopUpMenuWindowLevel];
    [panel setOpaque:NO];
    [panel setBackgroundColor:[NSColor clearColor]];
    
    //Register for drag and drop
    [self.mainTableview registerForDraggedTypes: [NSArray arrayWithObject:CLDragSessionKey]];

}

#pragma mark -
#pragma mark Updating Timezones
#pragma mark -

- (void) updateDefaultPreferences
{
    
    NSArray *defaultZones = [[NSUserDefaults standardUserDefaults] objectForKey:CLDefaultPreferenceKey];
    
    self.defaultPreferences = self.defaultPreferences == nil ? [[NSMutableArray alloc] initWithArray:defaultZones] : [NSMutableArray arrayWithArray:defaultZones];
       
    self.scrollViewHeight.constant = self.showReviewCell ? (self.defaultPreferences.count+1)*55+30 : self.defaultPreferences.count*55 + 30;

}

#pragma mark - Public accessors

- (BOOL)hasActivePanel
{
    return _hasActivePanel;
}

- (void)setHasActivePanel:(BOOL)flag
{
    if (_hasActivePanel != flag)
    {
        _hasActivePanel = flag;
        
        _hasActivePanel ? [self openPanel] : [self closePanel];
    }
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification
{
    self.hasActivePanel = NO;
}

- (void)windowDidResignKey:(NSNotification *)notification;
{
    if ([[self window] isVisible])
    {
        self.hasActivePanel = NO;
    }
}

- (void)windowDidResize:(NSNotification *)notification
{
    NSWindow *panel = [self window];
    NSRect statusRect = [self statusRectForWindow:panel];
    NSRect panelRect = [panel frame];
    
    CGFloat statusX = roundf(NSMidX(statusRect));
    CGFloat panelX = statusX - NSMinX(panelRect);
    
    self.backgroundView.arrowX = panelX;
    
}

#pragma mark - Keyboard

- (void)cancelOperation:(id)sender
{
    self.hasActivePanel = NO;
}

#pragma mark - Public methods

- (NSRect)statusRectForWindow:(NSWindow *)window
{
    NSRect screenRect = [[[NSScreen screens] objectAtIndex:0] frame];
    NSRect statusRect = NSZeroRect;
    
    StatusItemView *statusItemView = nil;
    if ([self.delegate respondsToSelector:@selector(statusItemViewForPanelController:)])
    {
        statusItemView = [self.delegate statusItemViewForPanelController:self];
    }
    
    if (statusItemView)
    {
        statusRect = statusItemView.globalRect;
        statusRect.origin.y = NSMinY(statusRect) - NSHeight(statusRect);
    }
    else
    {
        statusRect.size = NSMakeSize(STATUS_ITEM_VIEW_WIDTH, [[NSStatusBar systemStatusBar] thickness]);
        statusRect.origin.x = roundf((NSWidth(screenRect) - NSWidth(statusRect)) / 2);
        statusRect.origin.y = NSHeight(screenRect) - NSHeight(statusRect) * 2;
    }
    return statusRect;
}

- (void)openPanel
{
    NSWindow *panel = [self window];
    
    NSRect screenRect = [[[NSScreen screens] objectAtIndex:0] frame];
    NSRect statusRect = [self statusRectForWindow:panel];
    
    NSRect panelRect = [panel frame];
    panelRect.size.width = PANEL_WIDTH;
    
    panelRect.size.height = self.showReviewCell ? (self.defaultPreferences.count+1)*55+30: self.defaultPreferences.count*55 + 30;

    panelRect.origin.x = roundf(NSMidX(statusRect) - NSWidth(panelRect) / 2);
    panelRect.origin.y = NSMaxY(statusRect) - NSHeight(panelRect);
    
    if (NSMaxX(panelRect) > (NSMaxX(screenRect) - ARROW_HEIGHT))
        panelRect.origin.x -= NSMaxX(panelRect) - (NSMaxX(screenRect) - ARROW_HEIGHT);
    
    [NSApp activateIgnoringOtherApps:NO];
    [panel setAlphaValue:0];
    [panel setFrame:statusRect display:YES];
    [panel makeKeyAndOrderFront:nil];
    
    NSTimeInterval openDuration = OPEN_DURATION;
    
    NSEvent *currentEvent = [NSApp currentEvent];
    if ([currentEvent type] == NSLeftMouseDown)
    {
        NSUInteger clearFlags = ([currentEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask);
        BOOL shiftPressed = (clearFlags == NSShiftKeyMask);
        BOOL shiftOptionPressed = (clearFlags == (NSShiftKeyMask | NSAlternateKeyMask));
        if (shiftPressed || shiftOptionPressed)
        {
            openDuration *= 5;
            
            if (shiftOptionPressed)
                NSLog(@"Icon is at %@\n\tMenu is on screen %@\n\tWill be animated to %@",
                      NSStringFromRect(statusRect), NSStringFromRect(screenRect), NSStringFromRect(panelRect));
        }
    }
    
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:openDuration];
    [[panel animator] setFrame:panelRect display:YES];
    [[panel animator] setAlphaValue:1];
    [NSAnimationContext endGrouping];
    
    [self.mainTableview reloadData];
    
}

- (void)closePanel
{
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:CLOSE_DURATION];
    [[[self window] animator] setAlphaValue:0];
    [NSAnimationContext endGrouping];
    
    dispatch_after(dispatch_walltime(NULL, NSEC_PER_SEC * CLOSE_DURATION * 2), dispatch_get_main_queue(), ^{
        
        [self.window orderOut:nil];
    });
}

#pragma mark -
#pragma mark NSTableview Datasource
#pragma mark -

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if (self.showReviewCell) {
        return self.defaultPreferences.count+1;
    }
    return self.defaultPreferences.count;
}

-(NSView*)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (self.showReviewCell && row == self.defaultPreferences.count) {
        CLRatingCellView *cellView = [self.mainTableview makeViewWithIdentifier:CLRatingCellViewIdentifier owner:self];
        return cellView;
    }

    
    NSTableCellView *cell = [tableView makeViewWithIdentifier:CLTimezoneCellViewIdentifier owner:self];
    
    NSTextField *cellText = [cell viewWithTag:100];
    
    NSTextField *timeCell = [cell viewWithTag:101];
    
    NSTextField *dateCell = [cell viewWithTag:102];
    
    dateCell.stringValue = [self getDateForTimeZone:self.defaultPreferences[row][CLTimezoneName]];
    
    timeCell.stringValue = [self getTimeForTimeZone:self.defaultPreferences[row][CLTimezoneName]];
    
  
    cellText.stringValue = [self formatStringShouldContainCity:YES
                                              withTimezoneName:self.defaultPreferences[row]];
    
    return cell;
}

#pragma mark -
#pragma mark Datasource formatting
#pragma mark -

- (NSString *)formatStringShouldContainCity:(BOOL)value withTimezoneName:(NSDictionary *)timeZoneDictionary
{
    if (timeZoneDictionary[CLCustomLabel]) {
        NSString *customLabel = timeZoneDictionary[CLCustomLabel];
        if (customLabel.length > 0) {
            return customLabel;
        }
    }
    
    NSString *timezoneName = timeZoneDictionary[CLTimezoneName];
    
    if (value) {
        NSRange range = [timezoneName rangeOfString:@"/"];
        NSRange underscoreRange = [timezoneName rangeOfString:@"_"];
        if (range.location != NSNotFound)
        {
            timezoneName = [timezoneName substringFromIndex:range.location+1];
        }
        if (underscoreRange.location != NSNotFound)
        {
            timezoneName = [timezoneName stringByReplacingOccurrencesOfString:@"_"
                                                                   withString:@" "];
        }
    }
    
    return timezoneName;
}

- (NSString *)getTimeForTimeZone:(NSString *)timezoneName
{
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = kCFDateFormatterNoStyle;
    
    NSNumber *is24HourFormatSelected = [[NSUserDefaults standardUserDefaults] objectForKey:CLC24hourFormatSelectedKey];
    
    is24HourFormatSelected.boolValue ? [dateFormatter setDateFormat:@"HH:mm"] : [dateFormatter setDateFormat:@"hh:mm a"];
    
    dateFormatter.timeZone = [NSTimeZone timeZoneWithName:timezoneName];
    //In the format 22:10
    
    return [dateFormatter stringFromDate:currentDate];
}

- (NSString *)getLocalCurrentDate
{
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = kCFDateFormatterShortStyle;
    dateFormatter.timeStyle = kCFDateFormatterNoStyle;
    dateFormatter.timeZone = [NSTimeZone systemTimeZone];
    
    return [NSDateFormatter localizedStringFromDate:currentDate dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle];
//    return [dateFormatter stringFromDate:currentDate];

}

- (NSString *)compareSystemDate:(NSString *)systemDate toTimezoneDate:(NSString *)date
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"MM/dd/yyyy" options:0 locale:[NSLocale currentLocale]];
    
    NSDate *localDate = [formatter dateFromString:systemDate];
    NSDate *timezoneDate = [formatter dateFromString:date];
    
    if (localDate == nil || timezoneDate == nil) {
        [CrashlyticsKit setUserEmail:systemDate];
        [CrashlyticsKit setUserIdentifier:date];
        return @"Today";
    }
    
    // Specify which units we would like to use
    unsigned units = NSCalendarUnitDay;
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSInteger systemDay = [calendar component:units fromDate:localDate];
    NSInteger timezoneDay = [calendar component:units fromDate:timezoneDate];
    
    if (systemDay == timezoneDay) {
        return NSLocalizedString(@"Today", @"Today");;
    }
    else if (systemDay > timezoneDay)
    {
        return NSLocalizedString(@"Yesterday", @"Yesterday");
    }
    else
    {
        return NSLocalizedString(@"Tomorrow", @"Tomorrow");;
    }
}

- (NSString *)getDateForTimeZone:(NSString *)timezoneName
{
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = kCFDateFormatterShortStyle;
    dateFormatter.timeStyle = kCFDateFormatterNoStyle;
    
    dateFormatter.timeZone = [NSTimeZone timeZoneWithName:timezoneName];
    //In the format 22:10
    
    return [self compareSystemDate:[self getLocalCurrentDate] toTimezoneDate:[dateFormatter stringFromDate:currentDate]];;
}

#pragma mark -
#pragma mark NSTableview Minor Customization when selecting rows
#pragma mark -

-(void)tableViewSelectionDidChange:(NSNotification *)notification
{
    if (self.mainTableview.selectedRow != -1) {
        [self updateCellForOldSelection:self.mainTableview.selectedRow andColor:[NSColor whiteColor]];
    }
    if (self.previousSelectedRow != -1) {
        [self updateCellForOldSelection:self.previousSelectedRow andColor:[NSColor blackColor]];
    }
    
    self.previousSelectedRow = self.mainTableview.selectedRow;
}

- (void)updateCellForOldSelection:(NSInteger)rowNumber andColor:(NSColor *)colorName
{
    NSTableCellView *cellView = [self.mainTableview viewAtColumn:self.mainTableview.selectedColumn
                                                             row:rowNumber
                                                 makeIfNecessary:NO];
    
    NSTextField *cellText = [cellView viewWithTag:100];
    NSTextField *timeCell = [cellView viewWithTag:101];
    NSTextField *dateCell = [cellView viewWithTag:102];
    
    cellText.textColor = colorName;
    timeCell.textColor = colorName;
    dateCell.textColor = colorName;
}


#pragma mark -
#pragma mark NSTableview Drag and Drop
#pragma mark -

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    
    [pboard declareTypes:[NSArray arrayWithObject:CLDragSessionKey] owner:self];
    
    [pboard setData:data forType:CLDragSessionKey];
    
    [self updateCellForOldSelection:rowIndexes.firstIndex andColor:[NSColor blackColor]];
    return YES;
}


-(BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation
{
    NSPasteboard *pBoard = [info draggingPasteboard];
    
    NSData *data = [pBoard dataForType:CLDragSessionKey];
    
    NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    [self.defaultPreferences exchangeObjectAtIndex:rowIndexes.firstIndex withObjectAtIndex:row];
    
    [[NSUserDefaults standardUserDefaults] setObject:self.defaultPreferences forKey:CLDefaultPreferenceKey];
    
    [self.mainTableview reloadData];
    
    return YES;
}

-(NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
    return NSDragOperationEvery;
}

#pragma mark -
#pragma mark Preferences Target-Action
#pragma mark -

- (IBAction)openPreferences:(id)sender
{
    self.preferencesWindow = [PreferencesWindowController sharedPreferences];
    [self.preferencesWindow showWindow:nil];
    [NSApp activateIgnoringOtherApps:YES];

}

#pragma mark -
#pragma mark Hiding Buttons on Mouse Exit
#pragma mark -

- (void)showOptions:(BOOL)value
{
    if (self.defaultPreferences.count == 0)
    {
        value = YES;
    }
   
    self.shutdownButton.hidden = !value;
    self.preferencesButton.hidden = !value;
    
}

@end
