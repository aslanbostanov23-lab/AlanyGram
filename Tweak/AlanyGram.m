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
// 1. CloudKit Mock (Предотвращает SIGTRAP / EXC_BREAKPOINT и переполнение стека)
// -----------------------------------------------------------------------------

@interface AGMockCKDatabase : NSObject
@end

@implementation AGMockCKDatabase

- (void)fetchRecordWithID:(id)recordID completionHandler:(void (^)(id, NSError *))handler {
    // Вызываем асинхронно с ошибкой отсутствия аккаунта (CKErrorNotAuthenticated = 9),
    // чтобы сигнал сети Telegram не зависал в ожидании ответа и не вызывал синхронную рекурсию
    if (handler) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *error = [NSError errorWithDomain:@"CKErrorDomain" code:9 userInfo:@{NSLocalizedDescriptionKey: @"iCloud not available"}];
            handler(nil, error);
        });
    }
}

- (void)performQuery:(id)query inZoneWithID:(id)zoneID completionHandler:(void (^)(id, NSError *))handler {
}

- (void)addOperation:(id)operation {
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return nil;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    NSMethodSignature *sig = [super methodSignatureForSelector:aSelector];
    if (!sig) {
        sig = [NSMethodSignature signatureWithObjCTypes:"v@:@"];
    }
    return sig;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
}

@end

@interface AGMockCKContainer : NSObject
@end

@implementation AGMockCKContainer

+ (id)ag_defaultContainer {
    static AGMockCKContainer *dummy = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dummy = [[AGMockCKContainer alloc] init];
    });
    return dummy;
}

+ (id)ag_containerWithIdentifier:(id)identifier {
    return [self ag_defaultContainer];
}

- (id)databaseWithDatabaseScope:(NSInteger)scope {
    static AGMockCKDatabase *db = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        db = [[AGMockCKDatabase alloc] init];
    });
    return db;
}

- (id)privateCloudDatabase {
    return [self databaseWithDatabaseScope:1];
}

- (id)publicCloudDatabase {
    return [self databaseWithDatabaseScope:2];
}

- (id)sharedCloudDatabase {
    return [self databaseWithDatabaseScope:3];
}

- (void)accountStatusWithCompletionHandler:(void (^)(NSInteger accountStatus, NSError *error))completionHandler {
    if (completionHandler) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // 3 = CKAccountStatusNoAccount (сообщаем, что iCloud аккаунт не настроен)
            completionHandler(3, nil);
        });
    }
}

- (void)addOperation:(id)operation {
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return nil;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    NSMethodSignature *sig = [super methodSignatureForSelector:aSelector];
    if (!sig) {
        sig = [NSMethodSignature signatureWithObjCTypes:"v@:@"];
    }
    return sig;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
}

@end

// -----------------------------------------------------------------------------
// 2. Siri & Intents Mock (Предотвращает SIGABRT на бесплатном Apple ID)
// -----------------------------------------------------------------------------

@interface AGMockINPreferences : NSObject
@end

@implementation AGMockINPreferences

+ (NSInteger)ag_siriAuthorizationStatus {
    // 2 = INSiriAuthorizationStatusDenied (сообщаем, что Siri отключена)
    return 2;
}

+ (void)ag_requestSiriAuthorization:(void (^)(NSInteger))handler {
    if (handler) {
        handler(2);
    }
}

@end

@interface AGMockINInteraction : NSObject
@end

@implementation AGMockINInteraction

- (void)ag_donateInteractionWithCompletion:(void (^)(NSError *))completion {
    if (completion) {
        completion(nil);
    }
}

- (void)ag_deleteAllInteractionsWithCompletion:(void (^)(NSError *))completion {
    if (completion) {
        completion(nil);
    }
}

- (void)ag_deleteInteractionsWithIdentifiers:(NSArray *)identifiers completion:(void (^)(NSError *))completion {
    if (completion) {
        completion(nil);
    }
}

@end

@interface AGMockINVoiceShortcutCenter : NSObject
@end

@implementation AGMockINVoiceShortcutCenter

+ (id)ag_sharedCenter {
    static AGMockINVoiceShortcutCenter *center = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        center = [[AGMockINVoiceShortcutCenter alloc] init];
    });
    return center;
}

- (void)getAllVoiceShortcutsWithCompletion:(void (^)(NSArray *, NSError *))completion {
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(@[], nil);
        });
    }
}

- (void)getVoiceShortcutWithIdentifier:(id)identifier completion:(void (^)(id, NSError *))completion {
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, nil);
        });
    }
}

- (void)setShortcutSuggestions:(NSArray *)suggestions {
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return nil;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    NSMethodSignature *sig = [super methodSignatureForSelector:aSelector];
    if (!sig) {
        sig = [NSMethodSignature signatureWithObjCTypes:"v@:@"];
    }
    return sig;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
}

@end

// -----------------------------------------------------------------------------
// 3. App Group Sandbox Fallback
// -----------------------------------------------------------------------------

@interface NSFileManager (AGAppGroupFix)
@end

@implementation NSFileManager (AGAppGroupFix)

- (NSURL *)ag_containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier {
    NSURL *url = [self ag_containerURLForSecurityApplicationGroupIdentifier:groupIdentifier];
    if (!url) {
        url = [[self URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
        NSLog(@"[AlanyGram] Redirected App Group '%@' to private sandbox: %@", groupIdentifier, url);
    }
    return url;
}

@end

// -----------------------------------------------------------------------------
// 4. Ghost Mode & Anti-Delete Hooks
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
// 4. Secret Media Viewer (Одноразовые фото, видео, аудио)
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

- (BOOL)canPerformSaveAction {
    if ([AlanyGramSettings shared].antiViewOnceEnabled) {
        return YES;
    }
    SEL sel = @selector(canPerformSaveAction);
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
// 5. Плавающая кнопка настроек AlanyGram
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
    NSLog(@"[AlanyGram] Initializing AlanyGram with CloudKit Bypass & App Group Fallback...");
    
    // 1. Фикс CloudKit краша: глушим вызовы [CKContainer defaultContainer], чтобы не падать на SIGTRAP
    Class ckClass = objc_getClass("CKContainer");
    if (ckClass) {
        Class mockClass = [AGMockCKContainer class];
        Class metaClass = object_getClass((id)ckClass);
        Class mockMetaClass = object_getClass((id)mockClass);
        AGSwizzleInstanceMethod(metaClass, @selector(defaultContainer), mockMetaClass, @selector(ag_defaultContainer));
        AGSwizzleInstanceMethod(metaClass, @selector(containerWithIdentifier:), mockMetaClass, @selector(ag_containerWithIdentifier:));
    }
    
    Class ckDbClass = objc_getClass("CKDatabase");
    if (ckDbClass) {
        Class mockDbClass = [AGMockCKDatabase class];
        AGSwizzleInstanceMethod(ckDbClass, @selector(fetchRecordWithID:completionHandler:), mockDbClass, @selector(fetchRecordWithID:completionHandler:));
    }
    
    // 2. Фикс Siri / Intents краша: глушим запросы к Siri, так как на бесплатном Apple ID нет прав com.apple.developer.siri
    Class inPrefsClass = objc_getClass("INPreferences");
    if (inPrefsClass) {
        Class mockClass = [AGMockINPreferences class];
        Class metaClass = object_getClass((id)inPrefsClass);
        Class mockMetaClass = object_getClass((id)mockClass);
        AGSwizzleInstanceMethod(metaClass, @selector(siriAuthorizationStatus), mockMetaClass, @selector(ag_siriAuthorizationStatus));
        AGSwizzleInstanceMethod(metaClass, @selector(requestSiriAuthorization:), mockMetaClass, @selector(ag_requestSiriAuthorization:));
    }
    
    Class inInteractionClass = objc_getClass("INInteraction");
    if (inInteractionClass) {
        Class mockClass = [AGMockINInteraction class];
        AGSwizzleInstanceMethod(inInteractionClass, @selector(donateInteractionWithCompletion:), mockClass, @selector(ag_donateInteractionWithCompletion:));
        AGSwizzleInstanceMethod(inInteractionClass, @selector(deleteAllInteractionsWithCompletion:), mockClass, @selector(ag_deleteAllInteractionsWithCompletion:));
        AGSwizzleInstanceMethod(inInteractionClass, @selector(deleteInteractionsWithIdentifiers:completion:), mockClass, @selector(ag_deleteInteractionsWithIdentifiers:completion:));
    }
    
    Class inVoiceClass = objc_getClass("INVoiceShortcutCenter");
    if (inVoiceClass) {
        Class mockClass = [AGMockINVoiceShortcutCenter class];
        Class metaClass = object_getClass((id)inVoiceClass);
        Class mockMetaClass = object_getClass((id)mockClass);
        AGSwizzleInstanceMethod(metaClass, @selector(sharedCenter), mockMetaClass, @selector(ag_sharedCenter));
    }

    // 3. Фикс App Group: перенаправление в личный Documents приложения
    AGSwizzleInstanceMethod([NSFileManager class], 
                            @selector(containerURLForSecurityApplicationGroupIdentifier:), 
                            [NSFileManager class], 
                            @selector(ag_containerURLForSecurityApplicationGroupIdentifier:));
    
    // 4. Engine Hooks
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
    
    // 4. Secret Media Viewer Hooks
    Class viewerClass = objc_getClass("TGSecretMediaViewer");
    if (viewerClass) {
        Class mediaTarget = [AGSecretMediaHookTarget class];
        AGSwizzleInstanceMethod(viewerClass, @selector(startTtlCountdown:), mediaTarget, @selector(ag_startTtlCountdown:));
        AGSwizzleInstanceMethod(viewerClass, @selector(isExpired), mediaTarget, @selector(ag_isExpired));
        AGSwizzleInstanceMethod(viewerClass, @selector(allowSavingPhotos), mediaTarget, @selector(ag_allowSavingPhotos));
        AGSwizzleInstanceMethod(viewerClass, @selector(notifyServerMediaOpened:), mediaTarget, @selector(ag_notifyServerMediaOpened:));
    }
    
    // 5. Плавающая кнопка настроек после запуска приложения
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [[AGFloatingButtonManager shared] setupFloatingButton];
    }];
}
