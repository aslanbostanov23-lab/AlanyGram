#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// -----------------------------------------------------------------------------
// AlanyGram - Модификация Telegram iOS v12.9.2
// Автор: Aslan (https://vk.ru/aslanbostanov)
// -----------------------------------------------------------------------------

__attribute__((constructor))
static void AlanyGramInitialize(void) {
    NSLog(@"[AlanyGram] Initialized AlanyGram v12.9.2 by Aslan (vk.ru/aslanbostanov)");
}
