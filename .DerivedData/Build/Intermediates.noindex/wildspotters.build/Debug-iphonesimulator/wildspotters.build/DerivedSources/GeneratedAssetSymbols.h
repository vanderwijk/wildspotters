#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"nl.wildspotters";

/// The "AccentColor" asset catalog color resource.
static NSString * const ACColorNameAccentColor AC_SWIFT_PRIVATE = @"AccentColor";

/// The "BrandBeige" asset catalog color resource.
static NSString * const ACColorNameBrandBeige AC_SWIFT_PRIVATE = @"BrandBeige";

/// The "BrandDarkGray" asset catalog color resource.
static NSString * const ACColorNameBrandDarkGray AC_SWIFT_PRIVATE = @"BrandDarkGray";

/// The "BrandDarkGreen" asset catalog color resource.
static NSString * const ACColorNameBrandDarkGreen AC_SWIFT_PRIVATE = @"BrandDarkGreen";

/// The "BrandGreen" asset catalog color resource.
static NSString * const ACColorNameBrandGreen AC_SWIFT_PRIVATE = @"BrandGreen";

/// The "BrandLightGreen" asset catalog color resource.
static NSString * const ACColorNameBrandLightGreen AC_SWIFT_PRIVATE = @"BrandLightGreen";

/// The "FooterGrass" asset catalog image resource.
static NSString * const ACImageNameFooterGrass AC_SWIFT_PRIVATE = @"FooterGrass";

/// The "LaunchImage" asset catalog image resource.
static NSString * const ACImageNameLaunchImage AC_SWIFT_PRIVATE = @"LaunchImage";

/// The "Logo" asset catalog image resource.
static NSString * const ACImageNameLogo AC_SWIFT_PRIVATE = @"Logo";

/// The "LogoutIcon" asset catalog image resource.
static NSString * const ACImageNameLogoutIcon AC_SWIFT_PRIVATE = @"LogoutIcon";

#undef AC_SWIFT_PRIVATE
