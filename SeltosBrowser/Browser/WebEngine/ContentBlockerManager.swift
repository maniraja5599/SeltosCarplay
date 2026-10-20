import Foundation
import WebKit

/// Manages compilation and attachment of WebKit Content Blocking rules to prevent intrusive ads and trackers
public final class ContentBlockerManager {
    public static let shared = ContentBlockerManager()

    private let ruleListIdentifier = "SeltosContentBlockerRules"
    private var compiledRuleList: WKContentRuleList?

    private init() {
        prepareRuleList()
    }

    /// Compiles JSON-based content blocking rules into WebKit bytecode
    public func prepareRuleList() {
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: ruleListIdentifier,
            encodedContentRuleList: contentBlockerJSONRules
        ) { [weak self] ruleList, error in
            if let error = error {
                print("[ContentBlockerManager] Error compiling rules: \(error.localizedDescription)")
            } else if let ruleList = ruleList {
                self?.compiledRuleList = ruleList
                print("[ContentBlockerManager] Content rule list compiled successfully.")
            }
        }
    }

    /// Attaches or detaches the rule list to a WKWebView configuration based on user preference
    public func apply(to userContentController: WKUserContentController, enabled: Bool) {
        if enabled {
            if let ruleList = compiledRuleList {
                userContentController.add(ruleList)
            } else {
                // Compile on-demand if not ready yet
                WKContentRuleListStore.default().compileContentRuleList(
                    forIdentifier: ruleListIdentifier,
                    encodedContentRuleList: contentBlockerJSONRules
                ) { ruleList, _ in
                    if let ruleList = ruleList {
                        userContentController.add(ruleList)
                    }
                }
            }
        } else {
            if let ruleList = compiledRuleList {
                userContentController.remove(ruleList)
            }
        }
    }

    /// Declarative JSON rules for blocking trackers, popups, and intrusive ad elements
    private var contentBlockerJSONRules: String {
        """
        [
            {
                "trigger": {
                    "url-filter": ".*(doubleclick\\\\.net|googleadservices\\\\.com|googlesyndication\\\\.com|adnxs\\\\.com|scorecardresearch\\\\.com|taboola\\\\.com|outbrain\\\\.com).*"
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": ".*"
                },
                "action": {
                    "type": "css-display-none",
                    "selector": ".ytp-ad-module, .ytp-ad-overlay-container, .video-ads, .ad-container, #player-ads, .ad-showing"
                }
            }
        ]
        """
    }
}
