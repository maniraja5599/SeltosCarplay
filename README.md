# Private CarPlay Browser for Kia Seltos (`SeltosBrowser`)

A secure, private iPhone web browser built with **SwiftUI**, **WebKit**, and **Apple CarPlay** (`CPTemplateApplicationScene`), engineered specifically for personal use with a **Kia Seltos** infotainment system over wired USB CarPlay.

---

## Project Structure

```
.
├── project.yml                       # XcodeGen project specification
├── .gitignore                        # Git exclusion rules
├── README.md                         # Project overview and navigation
├── SeltosBrowser/
│   ├── App/
│   │   ├── SeltosBrowserApp.swift     # SwiftUI app lifecycle entry point
│   │   ├── AppDelegate.swift          # Multi-scene lifecycle delegate
│   │   └── Info.plist                 # CarPlay scene manifest & background audio config
│   ├── Entitlements/
│   │   └── SeltosBrowser.entitlements # CarPlay Audio & Video entitlement keys
│   ├── Browser/
│   │   ├── Models/
│   │   │   ├── BrowserTab.swift       # Tab state model
│   │   │   ├── Bookmark.swift         # Bookmark & Favorite model
│   │   │   ├── HistoryItem.swift      # Browsing history entry model
│   │   │   └── SearchEngine.swift     # Search engine query formatters
│   │   ├── ViewModels/
│   │   │   ├── BrowserViewModel.swift # Primary browser coordinator & media controller
│   │   │   ├── TabManager.swift       # Multi-tab session manager
│   │   │   ├── BookmarkManager.swift  # Local JSON persistence for bookmarks
│   │   │   ├── HistoryManager.swift   # Local JSON persistence for history
│   │   │   └── SettingsManager.swift  # User preferences manager
│   │   ├── WebEngine/
│   │   │   ├── WebViewContainer.swift # UIViewRepresentable wrapping WKWebView
│   │   │   ├── WebKitSecurityPolicy.swift # HTTPS normalization & security checks
│   │   │   └── WebNavigationDelegate.swift # WKNavigationDelegate & progress tracker
│   │   └── Views/
│   │       ├── BrowserContainerView.swift # Full-screen iPhone browser container
│   │       ├── AddressBarView.swift   # URL bar, search, and HTTPS indicators
│   │       ├── HomeFavoritesView.swift# Quick launch dashboard with favorites grid
│   │       ├── TabSwitcherView.swift  # Grid tab switcher
│   │       ├── BookmarksSheetView.swift # Bookmarks management sheet
│   │       ├── HistorySheetView.swift # Browsing history sheet
│   │       ├── SettingsSheetView.swift# Search engine & privacy wipe settings
│   │       └── WebErrorView.swift     # User-friendly connection error screen
│   ├── Media/
│   │   ├── AudioSessionManager.swift  # AVAudioSession (.playback / .moviePlayback)
│   │   ├── NowPlayingManager.swift    # MPNowPlayingInfoCenter & MPRemoteCommandCenter
│   │   └── YouTubeHelper.swift        # JavaScript media state observer & remote controls
│   ├── CarPlay/
│   │   ├── CarPlaySceneDelegate.swift # CPTemplateApplicationSceneDelegate
│   │   ├── CarPlayTemplateManager.swift # CPTabBarTemplate, CPListTemplate, CPNowPlaying
│   │   └── CarPlaySafetyMonitor.swift # CoreLocation vehicle velocity safety checker
│   └── Resources/
│       └── Assets.xcassets/           # App icon and accent color catalogs
└── docs/
    ├── 01_FEASIBILITY_REPORT.md       # APTV analysis, CarPlay categories, vehicle checks
    ├── 02_TECHNICAL_ARCHITECTURE.md    # System architecture, Mermaid diagrams, data flows
    ├── 05_YOUTUBE_SUPPORT_ANALYSIS.md # YouTube WebKit integration & CarPlay reality
    ├── 06_CARPLAY_INTEGRATION_SPEC.md # CarPlay framework specs & blocker report
    ├── 07_BUILD_AND_INSTALLATION_GUIDE.md # Windows & Mac build/signing instructions
    ├── 08_TEST_PLAN.md                # 25-point comprehensive verification plan
    └── 09_FINAL_REPORT.md             # Status summary, blocker review, and next steps
```

---

## Key Documentation Links

- [Deliverable 1: Feasibility Report](file:///c:/Moved_From_E/TEST/Apple%20CarPlay/docs/01_FEASIBILITY_REPORT.md)
- [Deliverable 2: Technical Architecture](file:///c:/Moved_From_E/TEST/Apple%20CarPlay/docs/02_TECHNICAL_ARCHITECTURE.md)
- [Deliverable 5: YouTube Support & Playback Analysis](file:///c:/Moved_From_E/TEST/Apple%20CarPlay/docs/05_YOUTUBE_SUPPORT_ANALYSIS.md)
- [Deliverable 6: CarPlay Integration Specification & Blocker Report](file:///c:/Moved_From_E/TEST/Apple%20CarPlay/docs/06_CARPLAY_INTEGRATION_SPEC.md)
- [Deliverable 7: Build, Signing, and Installation Guide](file:///c:/Moved_From_E/TEST/Apple%20CarPlay/docs/07_BUILD_AND_INSTALLATION_GUIDE.md)
- [Deliverable 8: Comprehensive Test Plan](file:///c:/Moved_From_E/TEST/Apple%20CarPlay/docs/08_TEST_PLAN.md)
- [Deliverable 9: Final Engineering Report](file:///c:/Moved_From_E/TEST/Apple%20CarPlay/docs/09_FINAL_REPORT.md)

---

## Quick Start on macOS / Cloud Mac

```bash
# 1. Install XcodeGen if needed
brew install xcodegen

# 2. Generate the .xcodeproj
xcodegen generate

# 3. Open in Xcode
open SeltosBrowser.xcodeproj

# 4. Select your Development Team under Signing & Capabilities, connect your iPhone, and run!
```
