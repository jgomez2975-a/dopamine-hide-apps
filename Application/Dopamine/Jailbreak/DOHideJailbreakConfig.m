//
//  DOHideJailbreakConfig.m
//  Dopamine
//

#import "DOHideJailbreakConfig.h"
#import "DOEnvironmentManager.h"
#import <libjailbreak/libjailbreak.h>
#import <libjailbreak/jbroot.h>
#import <CoreServices/LSApplicationProxy.h>
#import <CoreServices/LSApplicationWorkspace.h>

@implementation DOHideJailbreakAppItem
@end

static NSArray *DODefaultBankBundleIDs(void)
{
    return @[
        @"com.apple.Passbook",
        @"com.apple.MobileStore",
        @"com.apple.AppStore",
        @"com.apple.MobileSMS",
        @"com.alipay.iphoneclient",
        @"com.alipay.iphoneclient.security",
        @"com.tencent.xin",
        @"com.tencent.mqq",
        @"com.tencent.qq",
        @"com.chinamworld.main",
        @"com.icbc.iphoneclient",
        @"com.abc.iphoneclient",
        @"cmb.pb",
        @"com.bankcomm.Bankcomm",
        @"com.spdb.spdbbank",
        @"com.cib.mobile.bank",
        @"com.cgbchina.mbank",
        @"com.pingan.pabank",
        @"com.cmbchina.ccd",
        @"com.unionpay.chsp",
        @"com.unionpay.mobilepay",
        @"com.icbc.im",
        @"com.ccb.CCBMobile",
        @"com.bankofbeijing.mobilebanking",
        @"com.citicbank.mobilebank",
        @"com.hsbc.hsbcnet",
        @"com.chase",
        @"com.bankofamerica.BankofAmerica",
        @"com.wellsfargo.wellsfargomobile",
        @"com.paypal.PPClient",
        @"com.venmo.touch.v2",
        @"com.squareup.cash",
        @"com.wise.ios",
        @"com.revolut.revolut",
        @"com.binance.BNB",
        @"ph.telegra.Telegraph",
        @"net.whatsapp.WhatsApp",
        @"com.google.Gmail",
        @"com.atebits.Tweetie2",
        @"com.burbn.instagram",
        @"com.zhiliaoapp.musically",
        @"com.ss.iphone.ugc.Aweme",
        @"com.kuaishou.nebula",
        @"com.sina.weibo",
        @"com.netease.news",
        @"tv.danmaku.bilianime",
        @"com.netease.cloudmusic",
        @"com.tencent.QQKSong",
        @"com.taobao.taobao4iphone",
        @"com.jingdong.app.mall",
        @"com.meituan.imeituan",
        @"com.dianping.dpscope",
        @"com.sankuai.meituan.takeoutnew",
        @"com.didapinche.booking",
        @"com.sdu.didi.psnger",
        @"com.ubercab.UberClient",
        @"com.didi.passenger",
        @"com.autonavi.amap",
        @"com.baidu.map",
        @"com.tencent.map",
        @"com.cmbchina.creditcard",
        @"com.icbc.elife",
        @"com.pingan.lifeinsurance",
        @"com.antgroup.mayibank",
    ];
}

@interface DOHideJailbreakConfig ()
@property (nonatomic, strong) NSMutableSet<NSString *> *hiddenIDs;
@property (nonatomic, strong) NSMutableSet<NSString *> *hiddenPaths;
@end

@implementation DOHideJailbreakConfig

+ (instancetype)sharedConfig
{
    static DOHideJailbreakConfig *cfg;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cfg = [DOHideJailbreakConfig new];
        [cfg reload];
    });
    return cfg;
}

- (NSString *)configPath
{
    NSString *jb = JBROOT_PATH(@"/basebin/config.plist");
    if (jb) return jb;
    return @"/var/jb/basebin/config.plist";
}

- (void)reload
{
    self.hiddenIDs = [NSMutableSet set];
    self.hiddenPaths = [NSMutableSet set];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:[self configPath]];
    NSArray *ids = dict[@"HideJailbreakBundleIDs"];
    NSArray *paths = dict[@"HideJailbreakApps"];
    if ([ids isKindOfClass:[NSArray class]]) [self.hiddenIDs addObjectsFromArray:ids];
    if ([paths isKindOfClass:[NSArray class]]) [self.hiddenPaths addObjectsFromArray:paths];
}

- (void)persist
{
    NSString *path = [self configPath];
    NSMutableDictionary *dict = [[NSDictionary dictionaryWithContentsOfFile:path] mutableCopy] ?: [NSMutableDictionary dictionary];
    dict[@"HideJailbreakBundleIDs"] = [self.hiddenIDs.allObjects sortedArrayUsingSelector:@selector(compare:)];
    dict[@"HideJailbreakApps"] = [self.hiddenPaths.allObjects sortedArrayUsingSelector:@selector(compare:)];
    void (^writeBlock)(void) = ^{
        [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        [dict writeToFile:path atomically:YES];
    };
    DOEnvironmentManager *env = [DOEnvironmentManager sharedManager];
    if (env.isJailbroken) {
        [env runAsRoot:^{
            [env runUnsandboxed:writeBlock];
        }];
    } else {
        writeBlock();
    }
    [self writeTweakFilter];
}

- (NSSet<NSString *> *)hiddenBundleIDs { return [self.hiddenIDs copy]; }
- (NSSet<NSString *> *)hiddenPaths { return [self.hiddenPaths copy]; }
- (BOOL)isBundleHidden:(NSString *)bundleID { return bundleID && [self.hiddenIDs containsObject:bundleID]; }

- (void)setBundle:(NSString *)bundleID hidden:(BOOL)hidden executablePath:(NSString *)executablePath
{
    if (bundleID.length == 0) return;
    if (hidden) {
        [self.hiddenIDs addObject:bundleID];
        if (executablePath.length) [self.hiddenPaths addObject:executablePath];
    } else {
        [self.hiddenIDs removeObject:bundleID];
        if (executablePath.length) [self.hiddenPaths removeObject:executablePath];
    }
    [self persist];
    [self writeTweakFilter];
}

- (void)applyDefaultBankListIfNeeded
{
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:[self configPath]];
    if ([dict[@"HideJailbreakDefaultsApplied"] boolValue]) return;
    NSArray *apps = [self installedUserApps];
    NSSet *defaults = [NSSet setWithArray:DODefaultBankBundleIDs()];
    for (DOHideJailbreakAppItem *app in apps) {
        if ([defaults containsObject:app.bundleID]) {
            [self.hiddenIDs addObject:app.bundleID];
            if (app.executablePath.length) [self.hiddenPaths addObject:app.executablePath];
        }
    }
    NSMutableDictionary *write = [dict mutableCopy] ?: [NSMutableDictionary dictionary];
    write[@"HideJailbreakDefaultsApplied"] = @YES;
    write[@"HideJailbreakBundleIDs"] = [self.hiddenIDs.allObjects sortedArrayUsingSelector:@selector(compare:)];
    write[@"HideJailbreakApps"] = [self.hiddenPaths.allObjects sortedArrayUsingSelector:@selector(compare:)];
    void (^block)(void) = ^{
        [[NSFileManager defaultManager] createDirectoryAtPath:[[self configPath] stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        [write writeToFile:[self configPath] atomically:YES];
    };
    DOEnvironmentManager *env = [DOEnvironmentManager sharedManager];
    if (env.isJailbroken) {
        [env runAsRoot:^{ [env runUnsandboxed:block]; }];
    } else {
        block();
    }
    [self writeTweakFilter];
}

- (void)writeTweakFilter
{
    NSString *filterDir = JBROOT_PATH(@"/Library/MobileSubstrate/DynamicLibraries");
    if (!filterDir) filterDir = @"/var/jb/Library/MobileSubstrate/DynamicLibraries";
    NSString *plistPath = [filterDir stringByAppendingPathComponent:@"HideJailbreak.plist"];
    NSDictionary *plist = @{
        @"Filter": @{
            @"Bundles": [self.hiddenIDs.allObjects sortedArrayUsingSelector:@selector(compare:)]
        }
    };
    void (^block)(void) = ^{
        [[NSFileManager defaultManager] createDirectoryAtPath:filterDir withIntermediateDirectories:YES attributes:nil error:nil];
        [plist writeToFile:plistPath atomically:YES];
    };
    DOEnvironmentManager *env = [DOEnvironmentManager sharedManager];
    if (env.isJailbroken) {
        [env runAsRoot:^{ [env runUnsandboxed:block]; }];
    } else {
        block();
    }
}

- (NSArray<DOHideJailbreakAppItem *> *)installedUserApps
{
    NSMutableArray *out = [NSMutableArray array];
    LSApplicationWorkspace *ws = [LSApplicationWorkspace defaultWorkspace];
    NSMutableArray *all = [NSMutableArray array];
    if ([ws respondsToSelector:@selector(enumerateApplicationsOfType:block:)]) {
        [ws enumerateApplicationsOfType:1 block:^(LSApplicationProxy *proxy) { if (proxy) [all addObject:proxy]; }];
        [ws enumerateApplicationsOfType:0 block:^(LSApplicationProxy *proxy) { if (proxy) [all addObject:proxy]; }];
    } else if ([ws respondsToSelector:@selector(allInstalledApplications)]) {
        NSArray *installed = [ws allInstalledApplications];
        if (installed) [all addObjectsFromArray:installed];
    }
    for (LSApplicationProxy *proxy in all) {
        NSString *bid = proxy.bundleIdentifier;
        if (bid.length == 0) continue;
        if ([bid hasPrefix:@"com.apple."] && ![bid isEqualToString:@"com.apple.Passbook"] && ![bid isEqualToString:@"com.apple.AppStore"] && ![bid isEqualToString:@"com.apple.MobileStore"] && ![bid isEqualToString:@"com.apple.MobileSMS"]) continue;
        if ([bid isEqualToString:@"com.opa334.Dopamine"]) continue;
        DOHideJailbreakAppItem *item = [DOHideJailbreakAppItem new];
        item.bundleID = bid;
        item.name = proxy.localizedName.length ? proxy.localizedName : bid;
        NSString *bundlePath = proxy.bundleURL.path;
        NSString *execName = proxy.bundleExecutable;
        if (bundlePath.length && execName.length) {
            item.executablePath = [bundlePath stringByAppendingPathComponent:execName];
        } else {
            item.executablePath = bundlePath ?: bid;
        }
        item.hidden = [self.hiddenIDs containsObject:bid] || [self.hiddenPaths containsObject:item.executablePath];
        [out addObject:item];
    }
    [out sortUsingComparator:^NSComparisonResult(DOHideJailbreakAppItem *a, DOHideJailbreakAppItem *b) {
        if (a.hidden != b.hidden) return a.hidden ? NSOrderedAscending : NSOrderedDescending;
        return [a.name localizedStandardCompare:b.name];
    }];
    return out;
}

@end
