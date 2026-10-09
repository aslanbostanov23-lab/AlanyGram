#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AlanyGramSettings.h"

// Forward declarations of Telegram internal classes & interfaces
@interface TGNavigationController : UINavigationController
@end

@interface TGItemListController : UIViewController
@end

// Hooking Telegram Settings to insert AlanyGram Settings menu
%hook TGItemListController

- (void)viewWillAppear:(BOOL)animated {
    %orig;

    // Check if current controller is the Settings root controller
    NSString *title = self.title;
    if ([title isEqualToString:@"Settings"] || [title isEqualToString:@"Настройки"]) {
        // Add a navigation bar button or ensure menu item is available
        UIBarButtonItem *alanyGramBtn = [[UIBarButtonItem alloc] initWithTitle:@"AlanyGram" 
                                                                         style:UIBarButtonItemStylePlain 
                                                                        target:self 
                                                                        action:@selector(openAlanyGramSettings)];
        self.navigationItem.leftBarButtonItem = alanyGramBtn;
    }
}

%new
- (void)openAlanyGramSettings {
    AlanyGramSettingsViewController *vc = [[AlanyGramSettingsViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

%end

// -----------------------------------------------------------------------------
// 1. GHOST MODE (НЕВИДИМКА В ЧАТАХ - Блокировка отправки отчетов о прочтении)
// -----------------------------------------------------------------------------

// Hook MTProto Network Requests / Message Read API
%hook TelegramEngine

// In Telegram iOS Swift/ObjC bridge: readHistory(peerId:messageId:)
- (id)readHistoryForPeerId:(int64_t)peerId maxMessageId:(int32_t)maxMessageId {
    if ([AlanyGramSettings shared].chatGhostEnabled) {
        // Ghost mode active: suppress sending read status to server
        return nil;
    }
    return %orig;
}

- (void)markHistoryRead:(id)arg1 {
    if ([AlanyGramSettings shared].chatGhostEnabled) {
        return;
    }
    %orig;
}

%end

// -----------------------------------------------------------------------------
// 2. STORY GHOST (НЕВИДИМКА В ИСТОРИЯХ - Анонимный просмотр сторис)
// -----------------------------------------------------------------------------

%hook EngineStoryPresentationInterface

- (void)markStoryRead:(id)storyId {
    if ([AlanyGramSettings shared].storyGhostEnabled) {
        // Prevent sending markRead API request for stories
        return;
    }
    %orig;
}

%end

// -----------------------------------------------------------------------------
// 3. ANTI VIEW-ONCE & SAVE SECRET MEDIA (Одноразовые фото, видео, голосовые)
// -----------------------------------------------------------------------------

// Prevent secret media from burning / expiring
%hook TGSecretMediaViewer

- (void)startTtlCountdown:(NSTimeInterval)duration {
    if ([AlanyGramSettings shared].antiViewOnceEnabled) {
        // Stop countdown so the media never expires
        return;
    }
    %orig;
}

- (BOOL)isExpired {
    if ([AlanyGramSettings shared].antiViewOnceEnabled) {
        return NO;
    }
    return %orig;
}

// Ensure the action sheet / save button is always enabled and visible for secret media
- (BOOL)allowSavingPhotos {
    if ([AlanyGramSettings shared].antiViewOnceEnabled) {
        return YES;
    }
    return %orig;
}

- (BOOL)canPerformSaveAction {
    if ([AlanyGramSettings shared].antiViewOnceEnabled) {
        return YES;
    }
    return %orig;
}

// Prevent sending "Opened view-once media" notice to the sender
- (void)notifyServerMediaOpened:(id)messageId {
    if ([AlanyGramSettings shared].antiViewOnceEnabled) {
        return;
    }
    %orig;
}

%end

// -----------------------------------------------------------------------------
// 4. ANTI-DELETE (СОХРАНЕНИЕ УДАЛЕННЫХ СООБЩЕНИЙ)
// -----------------------------------------------------------------------------

// Telegram handles message deletions through Postbox / SQLite updates
%hook TGMessageHistory

- (void)deleteMessagesByIds:(NSArray *)messageIds forPeerId:(int64_t)peerId {
    if ([AlanyGramSettings shared].antiDeleteEnabled) {
        // Instead of hard deleting, we ignore the deletion command from server
        // (Optionally can mark the message locally as [Удалено])
        return;
    }
    %orig;
}

- (void)removeDeletedMessages:(id)deletedUpdates {
    if ([AlanyGramSettings shared].antiDeleteEnabled) {
        return;
    }
    %orig;
}

%end

%ctor {
    NSLog(@"[AlanyGram] Tweak successfully loaded into Telegram iOS!");
}
