#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AlanyGramSettings.h"

// -----------------------------------------------------------------------------
// Helper: Pure Objective-C Runtime Method Swizzling
// -----------------------------------------------------------------------------

static void AGSwizzleInstanceMethod(Class targetClass, SEL originalSelector, Class customClass, SEL customSelector) {
    if (!targetClass || !customClass) return;
    
    Method originalMethod = class_getInstanceMethod(targetClass, originalSelector);
    Method customMethod = class_getInstanceMethod(customClass, customSelector);
    
    if (!originalMethod || !customMethod) return;
    
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
// 1. App Group Sandbox Fallback (Устраняет черный экран при установке второй телеги)
// -----------------------------------------------------------------------------

@interface NSFileManager (AGAppGroupFix)
@end

@implementation NSFileManager (AGAppGroupFix)

- (NSURL *)ag_containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier {
    NSURL *url = [self ag_containerURLForSecurityApplicationGroupIdentifier:groupIdentifier];
    if (!url) {
        // Если App Group недоступен (бесплатный Apple ID или стоит официальная телега),
        // перенаправляем базу данных в личную папку Documents приложения!
        url = [[self URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
        NSLog(@"[AlanyGram] Redirected App Group '%@' to private sandbox: %@", groupIdentifier, url);
    }
    return url;
}

@end

// -----------------------------------------------------------------------------
// 2. Ghost Mode & Anti-Delete Hooks
// -----------------------------------------------------------------------------

@interface AGEngineHookTarget : NSObject
@end

@implementation AGEngineHookTarget

- (id)ag_readHistoryForPeerId:(int64_t)peerId maxMessageId:(int32_t)maxMessageId {
    if ([AlanyGramSettings shared].chatGhostEnabled) {
        return nil;
    }
    SEL sel = @selector(ag_readHistoryForPeerId:maxMessageId:);
    id (*orig)(id, SEL, int64_t, int32_t) = (id (*)(id, SEL, int64_t, int32_t))[self methodForSelector:sel];
    return orig ? orig(self, sel, peerId, maxMessageId) : nil;
}

- (void)ag_markHistoryRead:(id)arg1 {
    if ([AlanyGramSettings shared].chatGhostEnabled) {
        return;
    }
    SEL sel = @selector(ag_markHistoryRead:);
    void (*orig)(id, SEL, id) = (void (*)(id, SEL, id))[self methodForSelector:sel];
    if (orig) orig(self, sel, arg1);
}

- (void)ag_markStoryRead:(id)storyId {
    if ([AlanyGramSettings shared].storyGhostEnabled) {
        return;
    }
    SEL sel = @selector(ag_markStoryRead:);
    void (*orig)(id, SEL, id) = (void (*)(id, SEL, id))[self methodForSelector:sel];
    if (orig) orig(self, sel, storyId);
}

@end

// -----------------------------------------------------------------------------
// 3. Secret Media Viewer (Одноразовые фото, видео, аудио)
// -----------------------------------------------------------------------------

@interface AGSecretMediaHookTarget : NSObject
@end

@implementation AGSecretMediaHookTarget

- (void)ag_startTtlCountdown:(NSTimeInterval)duration {
    if ([AlanyGramSettings shared].antiViewOnceEnabled) {
        return;
    }
    SEL sel = @selector(ag_startTtlCountdown:);
    void (*orig)(id, SEL, NSTimeInterval) = (void (*)(id, SEL, NSTimeInterval))[self methodForSelector:sel];
    if (orig) orig(self, sel, duration);
}

- (BOOL)ag_isExpired {
    if ([AlanyGramSettings shared].antiViewOnceEnabled) {
        return NO;
    }
    SEL sel = @selector(ag_isExpired);
    BOOL (*orig)(id, SEL) = (BOOL (*)(id, SEL))[self methodForSelector:sel];
    return orig ? orig(self, sel) : NO;
}

- (BOOL)ag_allowSavingPhotos {
    if ([AlanyGramSettings shared].antiViewOnceEnabled) {
        return YES;
    }
    SEL sel = @selector(ag_allowSavingPhotos);
    BOOL (*orig)(id, SEL) = (BOOL (*)(id, SEL))[self methodForSelector:sel];
    return orig ? orig(self, sel) : YES;
}

- (BOOL)ag_canPerformSaveAction {
    if ([AlanyGramSettings shared].antiViewOnceEnabled) {
        return YES;
    }
    SEL sel = @selector(ag_canPerformSaveAction);
    BOOL (*orig)(id, SEL) = (BOOL (*)(id, SEL))[self methodForSelector:sel];
    return orig ? orig(self, sel) : YES;
}

- (void)ag_notifyServerMediaOpened:(id)messageId {
    if ([AlanyGramSettings shared].antiViewOnceEnabled) {
        return;
    }
    SEL sel = @selector(ag_notifyServerMediaOpened:);
    void (*orig)(id, SEL, id) = (void (*)(id, SEL, id))[self methodForSelector:sel];
    if (orig) orig(self, sel, messageId);
}

@end

// -----------------------------------------------------------------------------
// 4. Плавающая кнопка настроек AlanyGram
// -----------------------------------------------------------------------------

@interface AGFloatingButtonManager : NSObject
+ (instancetype)shared;
- (void)setupFloatingButton;
@end

@implementation AGFloatingButtonManager {
    UIButton *_floatingButton;
}

+ (instancetype)shared {
    static AGFloatingButtonManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AGFloatingButtonManager alloc] init];
    });
    return instance;
}

- (void)setupFloatingButton {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *w in scene.windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
            }
        }
        if (!window) window = [UIApplication sharedApplication].windows.firstObject;
        if (!window || self->_floatingButton) return;

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(window.bounds.size.width - 65, window.bounds.size.height - 150, 48, 48);
        btn.layer.cornerRadius = 24;
        btn.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:0.9];
        [btn setTitle:@"AG" forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        
        btn.layer.shadowColor = [UIColor blackColor].CGColor;
        btn.layer.shadowOffset = CGSizeMake(0, 3);
        btn.layer.shadowOpacity = 0.3;
        btn.layer.shadowRadius = 4;
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [btn addGestureRecognizer:pan];
        
        [btn addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
        
        [window addSubview:btn];
        self->_floatingButton = btn;
    });
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIView *btn = pan.view;
    CGPoint translation = [pan translationInView:btn.superview];
    btn.center = CGPointMake(btn.center.x + translation.x, btn.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:btn.superview];
}

- (void)openSettings {
    UIViewController *topVC = [UIApplication sharedApplication].windows.firstObject.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    
    AlanyGramSettingsViewController *vc = [[AlanyGramSettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    
    UIBarButtonItem *closeBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
                                                                              target:self 
                                                                              action:@selector(dismissSettings:)];
    vc.navigationItem.rightBarButtonItem = closeBtn;
    
    [topVC presentViewController:nav animated:YES completion:nil];
}

- (void)dismissSettings:(UIBarButtonItem *)sender {
    UIViewController *topVC = [UIApplication sharedApplication].windows.firstObject.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    [topVC dismissViewControllerAnimated:YES completion:nil];
}

@end

// -----------------------------------------------------------------------------
// Точка входа в библиотеку
// -----------------------------------------------------------------------------

__attribute__((constructor))
static void AlanyGramInitialize(void) {
    NSLog(@"[AlanyGram] Initializing AlanyGram with App Group Fallback...");
    
    // 1. Фикс черного экрана: перенаправление App Group в личный Documents, если группы недоступны
    AGSwizzleInstanceMethod([NSFileManager class], 
                            @selector(containerURLForSecurityApplicationGroupIdentifier:), 
                            [NSFileManager class], 
                            @selector(ag_containerURLForSecurityApplicationGroupIdentifier:));
    
    // 2. Engine Hooks
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
    
    // 3. Secret Media Viewer Hooks
    Class viewerClass = objc_getClass("TGSecretMediaViewer");
    if (viewerClass) {
        Class mediaTarget = [AGSecretMediaHookTarget class];
        AGSwizzleInstanceMethod(viewerClass, @selector(startTtlCountdown:), mediaTarget, @selector(ag_startTtlCountdown:));
        AGSwizzleInstanceMethod(viewerClass, @selector(isExpired), mediaTarget, @selector(ag_isExpired));
        AGSwizzleInstanceMethod(viewerClass, @selector(allowSavingPhotos), mediaTarget, @selector(ag_allowSavingPhotos));
        AGSwizzleInstanceMethod(viewerClass, @selector(canPerformSaveAction), mediaTarget, @selector(ag_canPerformSaveAction));
        AGSwizzleInstanceMethod(viewerClass, @selector(notifyServerMediaOpened:), mediaTarget, @selector(ag_notifyServerMediaOpened:));
    }
    
    // 4. Плавающая кнопка настроек после запуска приложения
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [[AGFloatingButtonManager shared] setupFloatingButton];
    }];
}
