#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AlanyGramSettings.h"

// -----------------------------------------------------------------------------
// Helper: Pure Objective-C Runtime Method Swizzling (No Substrate dependency!)
// -----------------------------------------------------------------------------

static void AGSwizzleInstanceMethod(Class targetClass, SEL originalSelector, Class customClass, SEL customSelector) {
    if (!targetClass || !customClass) return;
    
    Method originalMethod = class_getInstanceMethod(targetClass, originalSelector);
    Method customMethod = class_getInstanceMethod(customClass, customSelector);
    
    if (!originalMethod || !customMethod) return;
    
    // Add custom method implementation to target class
    BOOL added = class_addMethod(targetClass,
                                customSelector,
                                method_getImplementation(customMethod),
                                method_getTypeEncoding(customMethod));
    
    if (added) {
        Method newlyAddedMethod = class_getInstanceMethod(targetClass, customSelector);
        method_exchangeImplementations(originalMethod, newlyAddedMethod);
    } else {
        method_exchangeImplementations(originalMethod, customMethod);
    }
}

// -----------------------------------------------------------------------------
// 1. Settings Hook
// -----------------------------------------------------------------------------

@interface AGSettingsHookTarget : NSObject
@end

@implementation AGSettingsHookTarget

- (void)ag_viewWillAppear:(BOOL)animated {
    // Call original implementation
    SEL sel = @selector(ag_viewWillAppear:);
    if ([self respondsToSelector:sel]) {
        void (*orig)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[self methodForSelector:sel];
        orig(self, sel, animated);
    }
    
    UIViewController *vc = (UIViewController *)self;
    NSString *title = vc.title;
    if ([title isEqualToString:@"Settings"] || [title isEqualToString:@"Настройки"]) {
        UIBarButtonItem *btn = [[UIBarButtonItem alloc] initWithTitle:@"AlanyGram" 
                                                                style:UIBarButtonItemStylePlain 
                                                               target:self 
                                                               action:@selector(ag_openAlanyGramSettings)];
        vc.navigationItem.leftBarButtonItem = btn;
    }
}

- (void)ag_openAlanyGramSettings {
    UIViewController *vc = (UIViewController *)self;
    AlanyGramSettingsViewController *settingsVC = [[AlanyGramSettingsViewController alloc] init];
    [vc.navigationController pushViewController:settingsVC animated:YES];
}

@end

// -----------------------------------------------------------------------------
// 2. Ghost Mode (Чтение чатов и сторис)
// -----------------------------------------------------------------------------

@interface AGEngineHookTarget : NSObject
@end

@implementation AGEngineHookTarget

- (id)ag_readHistoryForPeerId:(int64_t)peerId maxMessageId:(int32_t)maxMessageId {
    if ([AlanyGramSettings shared].chatGhostEnabled) {
        // Suppress read receipt
        return nil;
    }
    
    SEL sel = @selector(ag_readHistoryForPeerId:maxMessageId:);
    id (*orig)(id, SEL, int64_t, int32_t) = (id (*)(id, SEL, int64_t, int32_t))[self methodForSelector:sel];
    return orig(self, sel, peerId, maxMessageId);
}

- (void)ag_markHistoryRead:(id)arg1 {
    if ([AlanyGramSettings shared].chatGhostEnabled) {
        return;
    }
    
    SEL sel = @selector(ag_markHistoryRead:);
    void (*orig)(id, SEL, id) = (void (*)(id, SEL, id))[self methodForSelector:sel];
    orig(self, sel, arg1);
}

- (void)ag_markStoryRead:(id)storyId {
    if ([AlanyGramSettings shared].storyGhostEnabled) {
        // Suppress story read receipt
        return;
    }
    
    SEL sel = @selector(ag_markStoryRead:);
    void (*orig)(id, SEL, id) = (void (*)(id, SEL, id))[self methodForSelector:sel];
    orig(self, sel, storyId);
}

@end

// -----------------------------------------------------------------------------
// 3. Secret Media Viewer (Одноразовые фото, видео, голосовые)
// -----------------------------------------------------------------------------

@interface AGSecretMediaHookTarget : NSObject
@end

@implementation AGSecretMediaHookTarget

- (void)ag_startTtlCountdown:(NSTimeInterval)duration {
    if ([AlanyGramSettings shared].antiViewOnceEnabled) {
        // Don't start burning timer
        return;
    }
    
    SEL sel = @selector(ag_startTtlCountdown:);
    void (*orig)(id, SEL, NSTimeInterval) = (void (*)(id, SEL, NSTimeInterval))[self methodForSelector:sel];
    orig(self, sel, duration);
}

- (BOOL)ag_isExpired {
    if ([AlanyGramSettings shared].antiViewOnceEnabled) {
        return NO;
    }
    
    SEL sel = @selector(ag_isExpired);
    BOOL (*orig)(id, SEL) = (BOOL (*)(id, SEL))[self methodForSelector:sel];
    return orig(self, sel);
}

- (BOOL)ag_allowSavingPhotos {
    if ([AlanyGramSettings shared].antiViewOnceEnabled) {
        return YES;
    }
    
    SEL sel = @selector(ag_allowSavingPhotos);
    BOOL (*orig)(id, SEL) = (BOOL (*)(id, SEL))[self methodForSelector:sel];
    return orig(self, sel);
}

- (BOOL)ag_canPerformSaveAction {
    if ([AlanyGramSettings shared].antiViewOnceEnabled) {
        return YES;
    }
    
    SEL sel = @selector(ag_canPerformSaveAction);
    BOOL (*orig)(id, SEL) = (BOOL (*)(id, SEL))[self methodForSelector:sel];
    return orig(self, sel);
}

- (void)ag_notifyServerMediaOpened:(id)messageId {
    if ([AlanyGramSettings shared].antiViewOnceEnabled) {
        // Don't tell the sender we opened it
        return;
    }
    
    SEL sel = @selector(ag_notifyServerMediaOpened:);
    void (*orig)(id, SEL, id) = (void (*)(id, SEL, id))[self methodForSelector:sel];
    orig(self, sel, messageId);
}

@end

// -----------------------------------------------------------------------------
// 4. Anti-Delete (Сохранение удалённых сообщений)
// -----------------------------------------------------------------------------

@interface AGMessageHistoryHookTarget : NSObject
@end

@implementation AGMessageHistoryHookTarget

- (void)ag_deleteMessagesByIds:(NSArray *)messageIds forPeerId:(int64_t)peerId {
    if ([AlanyGramSettings shared].antiDeleteEnabled) {
        return;
    }
    
    SEL sel = @selector(ag_deleteMessagesByIds:forPeerId:);
    void (*orig)(id, SEL, NSArray *, int64_t) = (void (*)(id, SEL, NSArray *, int64_t))[self methodForSelector:sel];
    orig(self, sel, messageIds, peerId);
}

- (void)ag_removeDeletedMessages:(id)deletedUpdates {
    if ([AlanyGramSettings shared].antiDeleteEnabled) {
        return;
    }
    
    SEL sel = @selector(ag_removeDeletedMessages:);
    void (*orig)(id, SEL, id) = (void (*)(id, SEL, id))[self methodForSelector:sel];
    orig(self, sel, deletedUpdates);
}

@end

// -----------------------------------------------------------------------------
// Initializer (Вызывается автоматически при запуске Telegram)
// -----------------------------------------------------------------------------

__attribute__((constructor))
static void AlanyGramInitialize(void) {
    NSLog(@"[AlanyGram] Tweak initialized with ZERO external dependencies!");
    
    // 1. Settings Hook
    Class itemListClass = objc_getClass("TGItemListController");
    if (!itemListClass) itemListClass = objc_getClass("UIViewController");
    
    Class settingsTarget = [AGSettingsHookTarget class];
    // Add ag_openAlanyGramSettings method to itemListClass
    Method openMethod = class_getInstanceMethod(settingsTarget, @selector(ag_openAlanyGramSettings));
    if (openMethod) {
        class_addMethod(itemListClass, @selector(ag_openAlanyGramSettings),
                        method_getImplementation(openMethod), method_getTypeEncoding(openMethod));
    }
    AGSwizzleInstanceMethod(itemListClass, @selector(viewWillAppear:), settingsTarget, @selector(ag_viewWillAppear:));
    
    // 2. Engine Hooks (Ghost Mode)
    Class engineClass = objc_getClass("TelegramEngine");
    if (engineClass) {
        Class engineTarget = [AGEngineHookTarget class];
        AGSwizzleInstanceMethod(engineClass, @selector(readHistoryForPeerId:maxMessageId:), engineTarget, @selector(ag_readHistoryForPeerId:maxMessageId:));
        AGSwizzleInstanceMethod(engineClass, @selector(markHistoryRead:), engineTarget, @selector(ag_markHistoryRead:));
    }
    
    Class storyClass = objc_getClass("EngineStoryPresentationInterface");
    if (storyClass) {
        Class engineTarget = [AGEngineHookTarget class];
        AGSwizzleInstanceMethod(storyClass, @selector(markStoryRead:), engineTarget, @selector(ag_markStoryRead:));
    }
    
    // 3. Secret Media Viewer (Anti View-Once)
    Class viewerClass = objc_getClass("TGSecretMediaViewer");
    if (viewerClass) {
        Class mediaTarget = [AGSecretMediaHookTarget class];
        AGSwizzleInstanceMethod(viewerClass, @selector(startTtlCountdown:), mediaTarget, @selector(ag_startTtlCountdown:));
        AGSwizzleInstanceMethod(viewerClass, @selector(isExpired), mediaTarget, @selector(ag_isExpired));
        AGSwizzleInstanceMethod(viewerClass, @selector(allowSavingPhotos), mediaTarget, @selector(ag_allowSavingPhotos));
        AGSwizzleInstanceMethod(viewerClass, @selector(canPerformSaveAction), mediaTarget, @selector(ag_canPerformSaveAction));
        AGSwizzleInstanceMethod(viewerClass, @selector(notifyServerMediaOpened:), mediaTarget, @selector(ag_notifyServerMediaOpened:));
    }
    
    // 4. Anti-Delete
    Class historyClass = objc_getClass("TGMessageHistory");
    if (historyClass) {
        Class historyTarget = [AGMessageHistoryHookTarget class];
        AGSwizzleInstanceMethod(historyClass, @selector(deleteMessagesByIds:forPeerId:), historyTarget, @selector(ag_deleteMessagesByIds:forPeerId:));
        AGSwizzleInstanceMethod(historyClass, @selector(removeDeletedMessages:), historyTarget, @selector(ag_removeDeletedMessages:));
    }
}
