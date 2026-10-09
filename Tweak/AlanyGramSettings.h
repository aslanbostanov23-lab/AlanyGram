#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface AlanyGramSettings : NSObject

+ (instancetype)shared;

@property (nonatomic, assign) BOOL antiDeleteEnabled;
@property (nonatomic, assign) BOOL antiViewOnceEnabled;
@property (nonatomic, assign) BOOL chatGhostEnabled;
@property (nonatomic, assign) BOOL storyGhostEnabled;

@end

@interface AlanyGramSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@end
