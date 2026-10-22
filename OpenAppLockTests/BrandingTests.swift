import UIKit
import Testing
@testable import OpenAppLock

@MainActor struct BrandingTests {
    @Test("The welcome screen's production logo is bundled at full resolution")
    func bundledLogo() throws {
        let logo = try #require(UIImage(named: "VolitionLogo"))
        #expect(logo.size.width * logo.scale >= 1024)
        #expect(logo.size.width == logo.size.height)
    }
}
