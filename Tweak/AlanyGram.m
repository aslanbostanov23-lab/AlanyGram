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
// 5. Плавающая кнопка и окно настроек AlanyGram
// -----------------------------------------------------------------------------

@interface AGFloatingButton : UIButton
@end

@implementation AGFloatingButton {
    CGPoint _beginPoint;
    BOOL _isDragging;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.cornerRadius = frame.size.width / 2.0;
        self.clipsToBounds = NO;
        self.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:0.95];
        [self setTitle:@"AG" forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:17];
        [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 3);
        self.layer.shadowOpacity = 0.35;
        self.layer.shadowRadius = 5;
        self.layer.borderWidth = 1.5;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.4].CGColor;
    }
    return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    UITouch *t = [touches anyObject];
    _beginPoint = [t locationInView:self.superview];
    _isDragging = NO;
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformMakeScale(0.90, 0.90);
        self.alpha = 0.85;
    }];
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    UITouch *t = [touches anyObject];
    CGPoint currentPoint = [t locationInView:self.superview];
    CGFloat dx = currentPoint.x - _beginPoint.x;
    CGFloat dy = currentPoint.y - _beginPoint.y;
    if (hypot(dx, dy) > 6.0) {
        _isDragging = YES;
        self.center = CGPointMake(self.center.x + dx, self.center.y + dy);
        _beginPoint = currentPoint;
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
    }];
    if (!_isDragging) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback impactOccurred];
        [[objc_getClass("AGFloatingButtonManager") performSelector:@selector(shared)] performSelector:@selector(openSettings)];
    } else {
        CGRect bounds = self.superview ? self.superview.bounds : [UIScreen mainScreen].bounds;
        CGFloat targetX = (self.center.x > bounds.size.width / 2.0) ? (bounds.size.width - self.bounds.size.width / 2.0 - 15) : (self.bounds.size.width / 2.0 + 15);
        CGFloat targetY = MIN(MAX(self.center.y, 80), bounds.size.height - 100);
        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.center = CGPointMake(targetX, targetY);
        } completion:nil];
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
    }];
}

@end

@interface AGFloatingButtonManager : NSObject
+ (instancetype)shared;
- (void)setupFloatingButton;
- (void)openSettings;
@end

@implementation AGFloatingButtonManager {
    AGFloatingButton *_floatingButton;
    UIWindow *_settingsWindow;
}

+ (instancetype)shared {
    static AGFloatingButtonManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AGFloatingButtonManager alloc] init];
    });
    return instance;
}

- (UIWindow *)findActiveKeyWindow {
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in scene.windows) {
                if (w.isKeyWindow || [NSStringFromClass([w class]) containsString:@"Main"]) {
                    return w;
                }
            }
            if (scene.windows.count > 0) {
                return scene.windows.firstObject;
            }
        }
    }
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow) return w;
    }
    return [UIApplication sharedApplication].windows.firstObject;
}

- (void)setupFloatingButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [self findActiveKeyWindow];
        if (!window) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self setupFloatingButton];
            });
            return;
        }

        if (!self->_floatingButton) {
            self->_floatingButton = [[AGFloatingButton alloc] initWithFrame:CGRectMake(window.bounds.size.width - 65, window.bounds.size.height - 150, 50, 50)];
        }

        if (self->_floatingButton.superview != window) {
            [window addSubview:self->_floatingButton];
        }
        [window bringSubviewToFront:self->_floatingButton];
    });
}

- (void)openSettings {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_settingsWindow) return;

        UIWindowScene *activeScene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
                activeScene = (UIWindowScene *)s;
                break;
            }
        }
        if (!activeScene) {
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]]) {
                    activeScene = (UIWindowScene *)s;
                    break;
                }
            }
        }

        UIWindow *win = nil;
        if (activeScene) {
            win = [[UIWindow alloc] initWithWindowScene:activeScene];
        } else {
            win = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        }
        win.windowLevel = UIWindowLevelAlert + 100;

        AlanyGramSettingsViewController *vc = [[AlanyGramSettingsViewController alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];

        UIBarButtonItem *closeBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
                                                                                  target:self 
                                                                                  action:@selector(dismissSettings:)];
        vc.navigationItem.rightBarButtonItem = closeBtn;

        win.rootViewController = nav;
        self->_settingsWindow = win;
        [win makeKeyAndVisible];

        win.alpha = 0.0;
        win.transform = CGAffineTransformMakeScale(0.92, 0.92);
        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            win.alpha = 1.0;
            win.transform = CGAffineTransformIdentity;
        } completion:nil];
    });
}

- (void)dismissSettings:(id)sender {
    if (!self->_settingsWindow) return;
    [UIView animateWithDuration:0.2 animations:^{
        self->_settingsWindow.alpha = 0.0;
        self->_settingsWindow.transform = CGAffineTransformMakeScale(0.92, 0.92);
    } completion:^(BOOL finished) {
        self->_settingsWindow.hidden = YES;
        self->_settingsWindow.rootViewController = nil;
        self->_settingsWindow = nil;

        UIWindow *activeWin = [self findActiveKeyWindow];
        [activeWin makeKeyWindow];
    }];
}

@end

@interface UIWindow (AGShakeHook)
@end

@implementation UIWindow (AGShakeHook)

- (void)ag_motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (motion == UIEventSubtypeMotionShake) {
        [[AGFloatingButtonManager shared] openSettings];
    }
    SEL sel = @selector(ag_motionEnded:withEvent:);
    void (*orig)(id, SEL, UIEventSubtype, UIEvent *) = (void (*)(id, SEL, UIEventSubtype, UIEvent *))[self methodForSelector:sel];
    if (orig) orig(self, sel, motion, event);
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
    
    // 5. Встряхивание устройства (Shake to Open Settings)
    AGSwizzleInstanceMethod([UIWindow class], 
                            @selector(motionEnded:withEvent:), 
                            [UIWindow class], 
                            @selector(ag_motionEnded:withEvent:));

    // 6. Плавающая кнопка настроек после запуска приложения и активации сцены
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserverForName:UIApplicationDidFinishLaunchingNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification * _Nonnull note) {
        [[AGFloatingButtonManager shared] setupFloatingButton];
    }];

    [nc addObserverForName:UIApplicationDidBecomeActiveNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification * _Nonnull note) {
        [[AGFloatingButtonManager shared] setupFloatingButton];
    }];

    if (@available(iOS 13.0, *)) {
        [nc addObserverForName:UISceneDidActivateNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification * _Nonnull note) {
            [[AGFloatingButtonManager shared] setupFloatingButton];
        }];
    }

    // Запускаем немедленно (если конструктор выполнился уже после запуска окна)
    [[AGFloatingButtonManager shared] setupFloatingButton];
}
