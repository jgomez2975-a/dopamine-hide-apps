//
//  DOHideJailbreakAppsController.m
//  Dopamine
//

#import "DOHideJailbreakAppsController.h"
#import "DOHideJailbreakConfig.h"
#import "DOEnvironmentManager.h"
#import "DOUIManager.h"
#import "DOButtonCell.h"
#import "DOPSListItemsController.h"

@interface DOHideJailbreakAppsController ()
@property (nonatomic, copy) NSArray<DOHideJailbreakAppItem *> *apps;
@end

@implementation DOHideJailbreakAppsController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[DOHideJailbreakConfig sharedConfig] applyDefaultBankListIfNeeded];
    [self reloadAppList];
}

- (void)reloadAppList
{
    self.apps = [[DOHideJailbreakConfig sharedConfig] installedUserApps];
}

- (id)specifiers
{
    if (_specifiers) return _specifiers;

    [self reloadAppList];
    NSMutableArray *specifiers = [NSMutableArray array];
    SEL defSetter = @selector(setPreferenceValue:specifier:);
    SEL defGetter = @selector(readPreferenceValue:);

    PSSpecifier *hint = [PSSpecifier emptyGroupSpecifier];
    [hint setProperty:DOLocalizedString(@"Hint_Hide_Jailbreak_Apps") forKey:@"footerText"];
    hint.name = DOLocalizedString(@"Section_Hide_Jailbreak_Apps");
    [specifiers addObject:hint];

    PSSpecifier *preset = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:defSetter get:defGetter detail:nil cell:PSStaticTextCell edit:nil];
    [preset setProperty:[DOButtonCell class] forKey:@"cellClass"];
    [preset setProperty:@60 forKey:@"height"];
    [preset setProperty:@"Button_Hide_Bank_Apps" forKey:@"title"];
    [preset setProperty:@"building.columns.fill" forKey:@"image"];
    [preset setProperty:@"applyBankPresetPressed" forKey:@"action"];
    [specifiers addObject:preset];

    PSSpecifier *clear = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:defSetter get:defGetter detail:nil cell:PSStaticTextCell edit:nil];
    [clear setProperty:[DOButtonCell class] forKey:@"cellClass"];
    [clear setProperty:@60 forKey:@"height"];
    [clear setProperty:@"Button_Clear_Hidden_Apps" forKey:@"title"];
    [clear setProperty:@"eye" forKey:@"image"];
    [clear setProperty:@"clearHiddenAppsPressed" forKey:@"action"];
    [specifiers addObject:clear];

    PSSpecifier *listGroup = [PSSpecifier emptyGroupSpecifier];
    listGroup.name = DOLocalizedString(@"Section_Installed_Apps");
    NSUInteger hiddenCount = 0;
    for (DOHideJailbreakAppItem *app in self.apps) if (app.hidden) hiddenCount++;
    [listGroup setProperty:[NSString stringWithFormat:DOLocalizedString(@"Hint_Hidden_App_Count"), @(hiddenCount)] forKey:@"footerText"];
    [specifiers addObject:listGroup];

    for (NSUInteger i = 0; i < self.apps.count; i++) {
        DOHideJailbreakAppItem *app = self.apps[i];
        NSString *title = [NSString stringWithFormat:@"%@ (%@)", app.name, app.bundleID];
        PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:title target:self set:@selector(setAppHidden:specifier:) get:@selector(readAppHidden:) detail:nil cell:PSSwitchCell edit:nil];
        [spec setProperty:@YES forKey:@"enabled"];
        [spec setProperty:app.bundleID forKey:@"key"];
        [spec setProperty:@(i) forKey:@"appIndex"];
        [spec setProperty:@NO forKey:@"default"];
        [specifiers addObject:spec];
    }

    _specifiers = specifiers;
    return _specifiers;
}

- (id)readAppHidden:(PSSpecifier *)specifier
{
    NSNumber *idx = [specifier propertyForKey:@"appIndex"];
    if (!idx || idx.unsignedIntegerValue >= self.apps.count) return @NO;
    return @(self.apps[idx.unsignedIntegerValue].hidden);
}

- (void)setAppHidden:(id)value specifier:(PSSpecifier *)specifier
{
    NSNumber *idx = [specifier propertyForKey:@"appIndex"];
    if (!idx || idx.unsignedIntegerValue >= self.apps.count) return;
    DOHideJailbreakAppItem *app = self.apps[idx.unsignedIntegerValue];
    BOOL hidden = [value boolValue];
    [[DOHideJailbreakConfig sharedConfig] setBundle:app.bundleID hidden:hidden executablePath:app.executablePath];
    app.hidden = hidden;
}

- (void)applyBankPresetPressed
{
    DOHideJailbreakConfig *cfg = [DOHideJailbreakConfig sharedConfig];
    for (DOHideJailbreakAppItem *app in self.apps) {
        NSString *bid = app.bundleID.lowercaseString;
        BOOL looksSensitive = [bid containsString:@"bank"] ||
            [bid containsString:@"pay"] ||
            [bid containsString:@"wallet"] ||
            [bid containsString:@"alipay"] ||
            [bid containsString:@"unionpay"] ||
            [bid containsString:@"wechat"] ||
            [bid containsString:@"tencent.xin"] ||
            [bid containsString:@"cmb"] ||
            [bid containsString:@"icbc"] ||
            [bid containsString:@"ccb"] ||
            [bid containsString:@"abc."] ||
            [bid containsString:@"spdb"] ||
            [bid containsString:@"citic"] ||
            [bid containsString:@"hsbc"] ||
            [bid containsString:@"chase"] ||
            [bid containsString:@"paypal"] ||
            [bid containsString:@"venmo"] ||
            [bid containsString:@"binance"] ||
            [bid containsString:@"passbook"];
        if (looksSensitive) {
            [cfg setBundle:app.bundleID hidden:YES executablePath:app.executablePath];
            app.hidden = YES;
        }
    }
    [self reloadSpecifiers];
}

- (void)clearHiddenAppsPressed
{
    DOHideJailbreakConfig *cfg = [DOHideJailbreakConfig sharedConfig];
    for (DOHideJailbreakAppItem *app in self.apps) {
        if (app.hidden) {
            [cfg setBundle:app.bundleID hidden:NO executablePath:app.executablePath];
            app.hidden = NO;
        }
    }
    [self reloadSpecifiers];
}

@end
