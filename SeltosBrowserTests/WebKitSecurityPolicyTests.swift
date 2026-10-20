import XCTest
@testable import SeltosBrowser

final class WebKitSecurityPolicyTests: XCTestCase {

    func testHTTPSUpgradeForInsecureHTTP() {
        let input = "http://example.com"
        let resolved = WebKitSecurityPolicy.resolveInput(input, searchEngine: .google, enforceHTTPS: true)
        XCTAssertEqual(resolved?.scheme, "https")
        XCTAssertEqual(resolved?.host, "example.com")
    }

    func testDomainNameWithoutSchemeResolvesToHTTPS() {
        let input = "m.youtube.com"
        let resolved = WebKitSecurityPolicy.resolveInput(input, searchEngine: .google, enforceHTTPS: true)
        XCTAssertEqual(resolved?.absoluteString, "https://m.youtube.com")
    }

    func testSearchQueryResolvesToSelectedSearchEngine() {
        let query = "Kia Seltos CarPlay features"
        let googleURL = WebKitSecurityPolicy.resolveInput(query, searchEngine: .google, enforceHTTPS: true)
        XCTAssertTrue(googleURL?.absoluteString.contains("google.com/search?q=") ?? false)

        let ddgURL = WebKitSecurityPolicy.resolveInput(query, searchEngine: .duckDuckGo, enforceHTTPS: true)
        XCTAssertTrue(ddgURL?.absoluteString.contains("duckduckgo.com/?q=") ?? false)
    }

    func testDangerousSchemesAreRejected() {
        let dangerousInputs = [
            "javascript:alert(1)",
            "file:///etc/passwd",
            "data:text/html,<h1>Hacked</h1>"
        ]

        for input in dangerousInputs {
            let result = WebKitSecurityPolicy.resolveInput(input, searchEngine: .google, enforceHTTPS: true)
            // Either nil or treated as search engine query, never raw script scheme
            if let scheme = result?.scheme {
                XCTAssertNotEqual(scheme, "javascript")
                XCTAssertNotEqual(scheme, "file")
                XCTAssertNotEqual(scheme, "data")
            }
        }
    }

    func testIsSecureURLCheck() {
        XCTAssertTrue(WebKitSecurityPolicy.isSecureURL(URL(string: "https://youtube.com")))
        XCTAssertFalse(WebKitSecurityPolicy.isSecureURL(URL(string: "http://insecure.org")))
        XCTAssertFalse(WebKitSecurityPolicy.isSecureURL(nil))
    }
}
