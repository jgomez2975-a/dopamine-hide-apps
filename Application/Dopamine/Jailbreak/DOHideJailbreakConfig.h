//
//  DOHideJailbreakConfig.h
//  Dopamine
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DOHideJailbreakAppItem : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *executablePath;
@property (nonatomic, assign) BOOL hidden;
@end

@interface DOHideJailbreakConfig : NSObject
+ (instancetype)sharedConfig;
- (NSArray<DOHideJailbreakAppItem *> *)installedUserApps;
- (NSSet<NSString *> *)hiddenBundleIDs;
- (NSSet<NSString *> *)hiddenPaths;
- (BOOL)isBundleHidden:(NSString *)bundleID;
- (void)setBundle:(NSString *)bundleID hidden:(BOOL)hidden executablePath:(NSString *)executablePath;
- (void)applyDefaultBankListIfNeeded;
@end

NS_ASSUME_NONNULL_END
