#import "LSBundleProxy.h"
@interface LSApplicationProxy : LSBundleProxy
@property (getter=isInstalled,nonatomic,readonly) BOOL installed;
@property (nonatomic,readonly) NSString *bundleIdentifier;
@property (nonatomic,readonly) NSString *localizedName;
@property (nonatomic,readonly) NSString *applicationIdentifier;
+ (instancetype)applicationProxyForIdentifier:(NSString *)identifier;
@property (nonatomic,readonly) NSSet * claimedURLSchemes;
@end
