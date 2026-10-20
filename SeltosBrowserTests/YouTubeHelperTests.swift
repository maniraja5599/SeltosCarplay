import XCTest
@testable import SeltosBrowser

final class YouTubeHelperTests: XCTestCase {

    func testDetectsYouTubeURLs() {
        let urls = [
            URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
            URL(string: "https://m.youtube.com"),
            URL(string: "https://youtu.be/dQw4w9WgXcQ")
        ]

        for url in urls {
            XCTAssertTrue(YouTubeHelper.isYouTubeURL(url))
        }
    }

    func testRejectsNonYouTubeURLs() {
        let nonYouTube = [
            URL(string: "https://www.google.com"),
            URL(string: "https://vimeo.com/123456"),
            URL(string: "https://apple.com")
        ]

        for url in nonYouTube {
            XCTAssertFalse(YouTubeHelper.isYouTubeURL(url))
        }
    }

    func testSeekScriptFormatting() {
        let forwardScript = YouTubeHelper.seekScript(delta: 15)
        XCTAssertTrue(forwardScript.contains("+ (15.0)"))

        let backwardScript = YouTubeHelper.seekScript(delta: -15)
        XCTAssertTrue(backwardScript.contains("+ (-15.0)"))
    }
}
