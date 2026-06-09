import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "AccentColor" asset catalog color resource.
    static let accent = DeveloperToolsSupport.ColorResource(name: "AccentColor", bundle: resourceBundle)

    /// The "BrandBeige" asset catalog color resource.
    static let brandBeige = DeveloperToolsSupport.ColorResource(name: "BrandBeige", bundle: resourceBundle)

    /// The "BrandDarkGray" asset catalog color resource.
    static let brandDarkGray = DeveloperToolsSupport.ColorResource(name: "BrandDarkGray", bundle: resourceBundle)

    /// The "BrandDarkGreen" asset catalog color resource.
    static let brandDarkGreen = DeveloperToolsSupport.ColorResource(name: "BrandDarkGreen", bundle: resourceBundle)

    /// The "BrandGreen" asset catalog color resource.
    static let brandGreen = DeveloperToolsSupport.ColorResource(name: "BrandGreen", bundle: resourceBundle)

    /// The "BrandLightGreen" asset catalog color resource.
    static let brandLightGreen = DeveloperToolsSupport.ColorResource(name: "BrandLightGreen", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "FooterGrass" asset catalog image resource.
    static let footerGrass = DeveloperToolsSupport.ImageResource(name: "FooterGrass", bundle: resourceBundle)

    /// The "LaunchImage" asset catalog image resource.
    static let launch = DeveloperToolsSupport.ImageResource(name: "LaunchImage", bundle: resourceBundle)

    /// The "Logo" asset catalog image resource.
    static let logo = DeveloperToolsSupport.ImageResource(name: "Logo", bundle: resourceBundle)

    /// The "LogoutIcon" asset catalog image resource.
    static let logoutIcon = DeveloperToolsSupport.ImageResource(name: "LogoutIcon", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// The "AccentColor" asset catalog color.
    static var accent: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .accent)
#else
        .init()
#endif
    }

    /// The "BrandBeige" asset catalog color.
    static var brandBeige: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .brandBeige)
#else
        .init()
#endif
    }

    /// The "BrandDarkGray" asset catalog color.
    static var brandDarkGray: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .brandDarkGray)
#else
        .init()
#endif
    }

    /// The "BrandDarkGreen" asset catalog color.
    static var brandDarkGreen: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .brandDarkGreen)
#else
        .init()
#endif
    }

    /// The "BrandGreen" asset catalog color.
    static var brandGreen: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .brandGreen)
#else
        .init()
#endif
    }

    /// The "BrandLightGreen" asset catalog color.
    static var brandLightGreen: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .brandLightGreen)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// The "AccentColor" asset catalog color.
    static var accent: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .accent)
#else
        .init()
#endif
    }

    /// The "BrandBeige" asset catalog color.
    static var brandBeige: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .brandBeige)
#else
        .init()
#endif
    }

    /// The "BrandDarkGray" asset catalog color.
    static var brandDarkGray: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .brandDarkGray)
#else
        .init()
#endif
    }

    /// The "BrandDarkGreen" asset catalog color.
    static var brandDarkGreen: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .brandDarkGreen)
#else
        .init()
#endif
    }

    /// The "BrandGreen" asset catalog color.
    static var brandGreen: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .brandGreen)
#else
        .init()
#endif
    }

    /// The "BrandLightGreen" asset catalog color.
    static var brandLightGreen: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .brandLightGreen)
#else
        .init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    /// The "AccentColor" asset catalog color.
    static var accent: SwiftUI.Color { .init(.accent) }

    /// The "BrandBeige" asset catalog color.
    static var brandBeige: SwiftUI.Color { .init(.brandBeige) }

    /// The "BrandDarkGray" asset catalog color.
    static var brandDarkGray: SwiftUI.Color { .init(.brandDarkGray) }

    /// The "BrandDarkGreen" asset catalog color.
    static var brandDarkGreen: SwiftUI.Color { .init(.brandDarkGreen) }

    /// The "BrandGreen" asset catalog color.
    static var brandGreen: SwiftUI.Color { .init(.brandGreen) }

    /// The "BrandLightGreen" asset catalog color.
    static var brandLightGreen: SwiftUI.Color { .init(.brandLightGreen) }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    /// The "AccentColor" asset catalog color.
    static var accent: SwiftUI.Color { .init(.accent) }

    /// The "BrandBeige" asset catalog color.
    static var brandBeige: SwiftUI.Color { .init(.brandBeige) }

    /// The "BrandDarkGray" asset catalog color.
    static var brandDarkGray: SwiftUI.Color { .init(.brandDarkGray) }

    /// The "BrandDarkGreen" asset catalog color.
    static var brandDarkGreen: SwiftUI.Color { .init(.brandDarkGreen) }

    /// The "BrandGreen" asset catalog color.
    static var brandGreen: SwiftUI.Color { .init(.brandGreen) }

    /// The "BrandLightGreen" asset catalog color.
    static var brandLightGreen: SwiftUI.Color { .init(.brandLightGreen) }

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "FooterGrass" asset catalog image.
    static var footerGrass: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .footerGrass)
#else
        .init()
#endif
    }

    /// The "LaunchImage" asset catalog image.
    static var launch: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .launch)
#else
        .init()
#endif
    }

    /// The "Logo" asset catalog image.
    static var logo: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .logo)
#else
        .init()
#endif
    }

    /// The "LogoutIcon" asset catalog image.
    static var logoutIcon: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .logoutIcon)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "FooterGrass" asset catalog image.
    static var footerGrass: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .footerGrass)
#else
        .init()
#endif
    }

    /// The "LaunchImage" asset catalog image.
    static var launch: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .launch)
#else
        .init()
#endif
    }

    /// The "Logo" asset catalog image.
    static var logo: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .logo)
#else
        .init()
#endif
    }

    /// The "LogoutIcon" asset catalog image.
    static var logoutIcon: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .logoutIcon)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

