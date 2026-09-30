import Foundation
import Testing
@testable import MDReaderApp

@Test(arguments: ["/Users/me/My Pics/фото 1.png", "/tmp/C# notes?v=2 100%.png"])
func assetURLRoundTripsToSamePath(_ path: String) {
    #expect(LocalAssetSchemeHandler.url(for: URL(fileURLWithPath: path))?.path == path)
}
