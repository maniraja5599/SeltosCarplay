# Deliverable 8: Verification & Comprehensive Test Plan

**Project:** Private CarPlay Browser for Kia Seltos (`SeltosBrowser`)  
**Target Hardware:** iPhone (iOS 16+), Kia Seltos (Wired USB CarPlay)  

---

## 1. Test Suite Matrix

This test plan defines explicit pass/fail criteria across all functional subsystems, platform boundaries, and automotive safety requirements.

---

## 2. Test Category A: iPhone Browser Core Navigation

| Test ID | Test Scenario | Execution Steps | Expected Outcome | Pass/Fail Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **TC-A01** | **Direct HTTPS URL Entry** | 1. Enter `https://apple.com` in address bar.<br>2. Tap Go/Return. | Web page loads smoothly; lock icon turns green; title updates to Apple. | Page renders without errors; progress bar completes. |
| **TC-A02** | **Domain Auto-Prefix** | 1. Enter `wikipedia.org` without scheme.<br>2. Tap Go. | Address bar normalizes input to `https://wikipedia.org`. | Navigation succeeds over encrypted HTTPS. |
| **TC-A03** | **Search Engine Query** | 1. Enter `Kia Seltos specifications 2024`.<br>2. Tap Go. | Input is detected as search query; routes to active default search engine. | Search results page renders correctly. |
| **TC-A04** | **Search Engine Switch** | 1. Open Settings Sheet.<br>2. Change engine to DuckDuckGo.<br>3. Search `CarPlay privacy`. | Query routes to `duckduckgo.com/?q=CarPlay+privacy`. | Verified engine URL template is applied. |
| **TC-A05** | **Back / Forward History** | 1. Visit Site A, then Site B.<br>2. Tap Back.<br>3. Tap Forward. | Back button navigates to Site A; Forward returns to Site B; buttons enable/disable correctly. | Back/Forward state reflects stack depth accurately. |
| **TC-A06** | **Reload & Stop Actions** | 1. Start loading heavy site.<br>2. Tap Stop (X).<br>3. Tap Reload (clockwise arrow). | Stop immediately cancels network request; reload restarts request. | WebKit loading lifecycle responds instantly. |

---

## 3. Test Category B: Security, HTTPS & Privacy Verification

| Test ID | Test Scenario | Execution Steps | Expected Outcome | Pass/Fail Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **TC-B01** | **HTTP to HTTPS Upgrade** | 1. Enter `http://example.com` with `enforceHTTPSOnly = true`. | System automatically upgrades request to `https://example.com`. | No unencrypted plaintext packets transmitted. |
| **TC-B02** | **Untrusted SSL Handling** | 1. Navigate to `https://self-signed.badssl.com`. | System trust evaluation rejects connection; `WebErrorView` displays security warning. | App refuses to bypass certificate validation. |
| **TC-B03** | **Host Resolution Failure** | 1. Enter `https://nonexistent-domain-xyz1234.org`. | `WebErrorView` displays *"Server not found"* with retry and home buttons. | Friendly error replaces raw WebKit crash. |
| **TC-B04** | **Privacy Data Wipe** | 1. Log in to a website (cookie set).<br>2. Open Settings -> tap *Clear All Browsing Data*.<br>3. Confirm wipe.<br>4. Revisit website. | `WKWebsiteDataStore` removes all cookies, cache, and IndexedDB; history is cleared. | User is logged out; history list is empty. |

---

## 4. Test Category C: YouTube Integration & Media Handling

| Test ID | Test Scenario | Execution Steps | Expected Outcome | Pass/Fail Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **TC-C01** | **YouTube Mobile Web** | 1. Tap YouTube favorite icon on Home screen. | Navigates directly to `https://m.youtube.com`. | Video feed renders properly with thumbnails. |
| **TC-C02** | **Inline Video Playback** | 1. Tap any YouTube video. | Video plays inline inside the webpage without forcing fullscreen modal. | `allowsInlineMediaPlayback` confirmed functional. |
| **TC-C03** | **Picture-in-Picture (PiP)** | 1. Tap YouTube player PiP icon (or swipe to home). | Video minimizes to native iOS PiP floating window. | Video continues playing smoothly in floating overlay. |
| **TC-C04** | **Media Bridge State Sync** | 1. Start video playback.<br>2. Check `NowPlayingManager` output in console. | JavaScript observer extracts Title, Channel, Duration, and Play status. | `MPNowPlayingInfoCenter` receives accurate metadata. |
| **TC-C05** | **Background Audio Session** | 1. Play video audio.<br>2. Lock iPhone display. | Audio continues playing uninterrupted through car/headphones. | `AVAudioSessionCategoryPlayback` prevents sleep cut. |

---

## 5. Test Category D: Multi-Tab & Local Storage Persistence

| Test ID | Test Scenario | Execution Steps | Expected Outcome | Pass/Fail Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **TC-D01** | **New Tab Creation** | 1. Tap Tabs button -> tap *New Tab*. | New isolated tab opens showing Home screen; tab count increments. | Tab count badge updates on toolbar. |
| **TC-D02** | **Tab Switching** | 1. Open Site A in Tab 1, Site B in Tab 2.<br>2. Switch between them in Tab Switcher. | Active web session and scroll position of each tab is preserved. | Tabs maintain isolated navigation states. |
| **TC-D03** | **Tab Closure** | 1. Close active tab via (X) button. | Tab removes cleanly; adjacent tab becomes active; memory freed. | If last tab closed, resets cleanly to Home. |
| **TC-D04** | **Bookmark Persistence** | 1. Bookmark a custom website.<br>2. Force quit app.<br>3. Relaunch app. | Bookmark persists in `bookmarks.json` and appears in Bookmarks list. | Local file serialization verified. |
| **TC-D05** | **History Logging** | 1. Visit 3 different web pages.<br>2. Open History Sheet. | All 3 pages listed chronologically with accurate timestamps and hosts. | History entries logged correctly. |

---

## 6. Test Category E: Kia Seltos USB CarPlay Integration

| Test ID | Test Scenario | Execution Steps | Expected Outcome | Pass/Fail Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **TC-E01** | **USB Connection Handshake** | 1. Connect iPhone to Kia Seltos center console USB port with MFi cable. | Kia head unit detects Apple CarPlay; iPhone prompts to allow connection. | CarPlay launcher surfaces on car screen. |
| **TC-E02** | **App Icon & Template Launch** | 1. Tap **Seltos Browser** on Kia Seltos screen. | `CarPlaySceneDelegate` launches `CPTabBarTemplate` with Favorites, Recents, Safety tabs. | Car screen renders native CarPlay UI with zero distortion. |
| **TC-E03** | **CarPlay Favorites Selection** | 1. Tap *Favorites* tab on car screen.<br>2. Tap *YouTube*. | iPhone browser navigates to YouTube; car display transitions to Now Playing HUD. | Seamless cross-screen coordination verified. |
| **TC-E04** | **Steering Wheel Transport Control** | 1. Play media.<br>2. Press Steering Wheel Pause/Mute.<br>3. Press Steering Wheel Track Skip. | Media pauses; next press resumes; skip jumps +15 seconds via JavaScript injection. | Physical car controls interact with web player. |
| **TC-E05** | **Parked vs Driving Safety State** | 1. Vehicle parked ($\le 0.5\text{ m/s}$).<br>2. Drive vehicle ($> 1.5\text{ m/s}$).<br>3. Check Safety tab. | Safety tab reflects state transition; audio remains uninterrupted; visual alerts enforce driving rules. | Complies with automotive safety policies. |
