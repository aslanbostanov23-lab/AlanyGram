#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// -----------------------------------------------------------------------------
// AlanyGram - Модификация Telegram iOS v12.9.2
// Автор: Aslan (https://vk.ru/aslanbostanov)
// -----------------------------------------------------------------------------

static void AGSwizzle(Class cls, SEL origSel, Class customCls, SEL newSel) {
    if (!cls || !customCls) return;
    Method orig = class_getInstanceMethod(cls, origSel);
    Method custom = class_getInstanceMethod(customCls, newSel);
    if (!orig || !custom) return;
    
    BOOL added = class_addMethod(cls, newSel, method_getImplementation(custom), method_getTypeEncoding(custom));
    if (added) {
        Method newlyAdded = class_getInstanceMethod(cls, newSel);
        method_exchangeImplementations(orig, newlyAdded);
    } else {
        method_exchangeImplementations(orig, custom);
    }
}

// -----------------------------------------------------------------------------
// 1. Отложенный Bundle ID Spoof — убирает плашку «неофициальный клиент»
//    Активируется ТОЛЬКО после того, как UIKit привязал окно к сцене,
//    чтобы не вызвать чёрный экран (как в Run #12–13).
// -----------------------------------------------------------------------------

static BOOL g_spoofBundleID = NO;

@interface NSBundle (AGDelayedSpoof)
@end

@implementation NSBundle (AGDelayedSpoof)

- (NSString *)ag_bundleIdentifier {
    if (self == [NSBundle mainBundle] && g_spoofBundleID) {
        return @"ph.telegra.Telegraph";
    }
    return [self ag_bundleIdentifier]; // вызывает оригинал (swizzled)
}

@end

// -----------------------------------------------------------------------------
// 2. Вкладка «Автор» на экране настроек AlanyGram
// -----------------------------------------------------------------------------

@interface UIViewController (AlanyGramAuthor)
@end

@implementation UIViewController (AlanyGramAuthor)

- (void)ag_viewWillAppear:(BOOL)animated {
    SEL sel = @selector(ag_viewWillAppear:);
    void (*orig)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[self methodForSelector:sel];
    if (orig) orig(self, sel, animated);

    // Добавляем кнопку "Автор" на экран настроек AlanyGram
    NSString *title = self.title ?: self.navigationItem.title;
    if ([title isEqualToString:@"Настройки AlanyGram"] || [title isEqualToString:@"AlanyGram"]) {
        if (!self.navigationItem.rightBarButtonItem) {
            UIBarButtonItem *authorItem = [[UIBarButtonItem alloc] initWithTitle:@"Автор"
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(ag_showAuthorSheet)];
            self.navigationItem.rightBarButtonItem = authorItem;
        }
    }
}

- (void)ag_showAuthorSheet {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"AlanyGram"
                                                                   message:@"Создатель: Aslan\nTelegram: @aslan060709\nVK: vk.ru/aslanbostanov"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Открыть ВКонтакте" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSURL *url = [NSURL URLWithString:@"https://vk.ru/aslanbostanov"];
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Написать в Telegram (@aslan060709)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSURL *url = [NSURL URLWithString:@"https://t.me/aslan060709"];
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Закрыть" style:UIAlertActionStyleCancel handler:nil]];

    sheet.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    sheet.popoverPresentationController.sourceView = self.view;

    [self presentViewController:sheet animated:YES completion:nil];
}

@end

// -----------------------------------------------------------------------------
// Точка входа
// -----------------------------------------------------------------------------

__attribute__((constructor))
static void AlanyGramInitialize(void) {
    NSLog(@"[AlanyGram] Initialized AlanyGram v12.9.2 by Aslan (vk.ru/aslanbostanov)");
    
    // Хук viewWillAppear для кнопки «Автор»
    AGSwizzle([UIViewController class], @selector(viewWillAppear:), [UIViewController class], @selector(ag_viewWillAppear:));
    
    // Хук bundleIdentifier (пока ещё выключен — g_spoofBundleID == NO)
    AGSwizzle([NSBundle class], @selector(bundleIdentifier), [NSBundle class], @selector(ag_bundleIdentifier));
    
    // Включить спуф ПОСЛЕ того как UIKit полностью привяжет окно к сцене.
    // UISceneDidActivateNotification = сцена уже живая, окно привязано.
    // Дополнительная задержка 1.5 сек для гарантии.
    [[NSNotificationCenter defaultCenter] addObserverForName:UISceneDidActivateNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!g_spoofBundleID) {
                g_spoofBundleID = YES;
                NSLog(@"[AlanyGram] Bundle ID spoof enabled → ph.telegra.Telegraph");
            }
        });
    }];
}
