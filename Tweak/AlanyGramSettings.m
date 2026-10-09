#import "AlanyGramSettings.h"

static NSString *const kPrefAntiDeleteKey   = @"AlanyGram_AntiDelete";
static NSString *const kPrefAntiViewOnceKey = @"AlanyGram_AntiViewOnce";
static NSString *const kPrefChatGhostKey    = @"AlanyGram_ChatGhost";
static NSString *const kPrefStoryGhostKey   = @"AlanyGram_StoryGhost";

@implementation AlanyGramSettings

+ (instancetype)shared {
    static AlanyGramSettings *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AlanyGramSettings alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults registerDefaults:@{
            kPrefAntiDeleteKey: @YES,
            kPrefAntiViewOnceKey: @YES,
            kPrefChatGhostKey: @YES,
            kPrefStoryGhostKey: @YES
        }];
    }
    return self;
}

- (BOOL)antiDeleteEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kPrefAntiDeleteKey];
}

- (void)setAntiDeleteEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kPrefAntiDeleteKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)antiViewOnceEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kPrefAntiViewOnceKey];
}

- (void)setAntiViewOnceEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kPrefAntiViewOnceKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)chatGhostEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kPrefChatGhostKey];
}

- (void)setChatGhostEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kPrefChatGhostKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)storyGhostEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kPrefStoryGhostKey];
}

- (void)setStoryGhostEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kPrefStoryGhostKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

@implementation AlanyGramSettingsViewController {
    UITableView *_tableView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Настройки AlanyGram";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2; // Приватность / Невидимка
    if (section == 1) return 2; // Медиа и Сообщения
    if (section == 2) return 2; // О разработчике
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"РЕЖИМ НЕВИДИМКИ (GHOST)";
    if (section == 1) return @"МЕДИА И УДАЛЕННЫЕ СООБЩЕНИЯ";
    if (section == 2) return @"О РАЗРАБОТЧИКЕ";
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"Невидимка блокирует отправку статуса прочтения собеседнику. Просмотр сторис также останется анонимным.";
    }
    if (section == 1) {
        return @"Одноразовые фото/видео не сгорают, не отправляют статус открытия таймера и могут быть сохранены в галерею.";
    }
    if (section == 2) {
        return @"AlanyGram Mod v1.0 • Сделано для души.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"AlanyGramCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;

    if (indexPath.section == 0) {
        UISwitch *toggle = [[UISwitch alloc] init];
        cell.accessoryView = toggle;

        if (indexPath.row == 0) {
            cell.textLabel.text = @"Невидимка в чатах";
            cell.detailTextLabel.text = @"Не помечать входящие сообщения прочитанными";
            toggle.on = [AlanyGramSettings shared].chatGhostEnabled;
            [toggle addTarget:self action:@selector(chatGhostToggled:) forControlEvents:UIControlEventValueChanged];
        } else {
            cell.textLabel.text = @"Невидимка в историях";
            cell.detailTextLabel.text = @"Анонимный просмотр чужих сторис";
            toggle.on = [AlanyGramSettings shared].storyGhostEnabled;
            [toggle addTarget:self action:@selector(storyGhostToggled:) forControlEvents:UIControlEventValueChanged];
        }
    } else if (indexPath.section == 1) {
        UISwitch *toggle = [[UISwitch alloc] init];
        cell.accessoryView = toggle;

        if (indexPath.row == 0) {
            cell.textLabel.text = @"Сохранять одноразовые медиа";
            cell.detailTextLabel.text = @"Открытие без сгорания и кнопка сохранения";
            toggle.on = [AlanyGramSettings shared].antiViewOnceEnabled;
            [toggle addTarget:self action:@selector(antiViewOnceToggled:) forControlEvents:UIControlEventValueChanged];
        } else {
            cell.textLabel.text = @"Анти-удаление сообщений";
            cell.detailTextLabel.text = @"Сохранять сообщения, если собеседник их удалил";
            toggle.on = [AlanyGramSettings shared].antiDeleteEnabled;
            [toggle addTarget:self action:@selector(antiDeleteToggled:) forControlEvents:UIControlEventValueChanged];
        }
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Создатель";
            cell.detailTextLabel.text = @"Aslan";
            cell.accessoryType = UITableViewCellAccessoryNone;
        } else {
            cell.textLabel.text = @"ВКонтакте";
            cell.detailTextLabel.text = @"vk.ru/aslanbostanov (нажмите, чтобы открыть)";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 2 && indexPath.row == 1) {
        NSURL *url = [NSURL URLWithString:@"https://vk.ru/aslanbostanov"];
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
    }
}

#pragma mark - Actions

- (void)chatGhostToggled:(UISwitch *)sender {
    [AlanyGramSettings shared].chatGhostEnabled = sender.isOn;
}

- (void)storyGhostToggled:(UISwitch *)sender {
    [AlanyGramSettings shared].storyGhostEnabled = sender.isOn;
}

- (void)antiViewOnceToggled:(UISwitch *)sender {
    [AlanyGramSettings shared].antiViewOnceEnabled = sender.isOn;
}

- (void)antiDeleteToggled:(UISwitch *)sender {
    [AlanyGramSettings shared].antiDeleteEnabled = sender.isOn;
}

@end
