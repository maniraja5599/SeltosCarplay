# Deliverable 5: YouTube Support & Playback Architecture

**Project:** Private CarPlay Browser for Kia Seltos  
**Target:** YouTube Mobile Web, Embedded Player, and CarPlay Audio/Video Integration  

---

## 1. iPhone Browser YouTube Implementation

The application delivers native-grade YouTube playback inside `WKWebView` by configuring modern WebKit media flags and an intelligent JavaScript media observation bridge.

### 1.1 WebKit Media Configuration
To achieve seamless playback identical to Safari and Chrome, `WKWebViewConfiguration` is parameterized with:
1. **`allowsInlineMediaPlayback = true`:** Prevents iOS from forcing the video into native fullscreen modal player upon tap. Videos play inline inside the webpage layout.
2. **`allowsPictureInPictureMediaPlayback = true`:** Enables the iOS system Picture-in-Picture (PiP) button, allowing the user to minimize the YouTube video into a floating window while navigating other tabs or apps on the iPhone.
3. **`mediaTypesRequiringUserActionForPlayback = []`:** Allows HTML5 autoplay and smooth transitions without requiring explicit repeated user taps.
4. **`preferences.isElementFullscreenEnabled = true`:** Enables HTML5 fullscreen API (`requestFullscreen()`), permitting YouTube’s fullscreen player button to expand smoothly.

### 1.2 YouTube Authentication & DRM Handling
- **Authentication:** Users can log in to their personal Google/YouTube accounts directly through the browser. All session cookies and tokens are persisted securely in the sandboxed `WKWebsiteDataStore.default()`.
- **DRM & Codecs:** YouTube serves H.264 / AAC streams (and VP9/AV1 where supported by Apple hardware) to iOS Safari/WebKit. Standard YouTube videos, live streams, and YouTube Music web clients operate without requiring proprietary plugins.
- **Terms of Service Compliance:** The application acts as a clean, compliant web browser. It does **not** scrape private APIs, strip advertisements, bypass age restrictions, or download copyrighted media offline.

---

## 2. In-Vehicle CarPlay Video Presentation: The Technical Reality

### 2.1 The Official Apple Route for CarPlay Video
Under Apple's architecture (WWDC22 / WWDC24), displaying video on a car dashboard requires:
1. **The Restricted Entitlement:** `com.apple.developer.carplay-video`.
   - Apple only grants this to established video streaming partners (e.g., major broadcast networks, licensed streaming platforms).
   - Apple does **not** grant this entitlement to general-purpose web browsers or personal development hobby projects.
2. **Infotainment Protocol Handshake:**
   - The vehicle head unit must run software implementing Apple’s **AirPlay Video CarPlay Receiver Profile**.
   - The head unit actively transmits vehicle telemetry (`CPPlaybackConfiguration.videoPlaybackSupported`).
   - The vehicle must be in **Park (P)**. If the gear shifts into Drive (D) or Reverse (R), the video pipeline immediately shuts down.
3. **YouTube Platform Restriction:**
   - Google does not offer an official YouTube app for Apple CarPlay.
   - YouTube's web player does not negotiate CarPlay AirPlay video handshakes natively inside third-party WebKit wrappers without specialized player architecture.

### 2.2 Kia Seltos Head Unit Hardware Limitations
- **Infotainment System:** Kia Seltos (standard 8-inch Display Audio or 10.25-inch / 12.3-inch Gen5W / ccNC).
- **USB CarPlay Interface:** Wired USB CarPlay transmits an H.264 encoded display feed from iOS to the car, but the head unit firmware **does not expose an AirPlay Video decoding endpoint**.
- **Result:** Even if an app were compiled with the `com.apple.developer.carplay-video` entitlement, the Kia Seltos head unit returns `videoPlaybackSupported == false`. Video frames cannot be rendered on the car display.

---

## 3. The Compliant & Seamless Alternative: Full CarPlay Audio & Metadata Integration

While direct video rendering on the Kia Seltos screen is prohibited by Apple safety rules and automotive firmware, our application implements the **highest-tier supported companion experience**:

```
+-------------------------------------------------------------+
|                     iPhone (In Dock or Console)             |
|  - Plays YouTube Video (Inline, Fullscreen, or PiP)         |
|  - WKWebView Media Observer tracks Title, Channel, & Time   |
+-------------------------------------------------------------+
                              |
                     Wired USB CarPlay
                              |
                              v
+-------------------------------------------------------------+
|                  Kia Seltos Dashboard & Speakers            |
|  - High-Fidelity Audio Stream over Car Speakers             |
|  - CarPlay "Now Playing" HUD shows Video Title & Channel    |
|  - Steering Wheel Controls: Play, Pause, Track Skip (+15s)  |
|  - Car Screen Menu: Launch Bookmarked Channels / Recents    |
+-------------------------------------------------------------+
```

### 3.1 Media State Observation Bridge
The app injects a lightweight, battery-efficient JavaScript mutation observer into every web page:
```javascript
// Listens for HTML5 <video> state changes
video.addEventListener('playing', () => notifyState(true));
video.addEventListener('pause', () => notifyState(false));
```
When a YouTube video plays, this bridge transmits:
- Video Title (e.g., *"Car Review: Kia Seltos 2024 Facelift"*)
- Channel / Host (`m.youtube.com`)
- Duration and Current Time
- Playback Status (Playing / Paused)

### 3.2 Now Playing & Steering Wheel Control Loop
1. `NowPlayingManager` feeds the metadata into `MPNowPlayingInfoCenter`.
2. When the Kia Seltos driver presses the **Steering Wheel Seek/Pause button** or taps the **CarPlay screen pause icon**, the command is captured by `MPRemoteCommandCenter`:
```swift
commandCenter.togglePlayPauseCommand.addTarget { _ in
    BrowserViewModel.shared.togglePlayPauseMedia()
    return .success
}
```
3. The ViewModel instantly executes JavaScript in the active YouTube tab:
```javascript
const v = document.querySelector('video');
if (v) v.paused ? v.play() : v.pause();
```
4. Playback state updates instantaneously on both the phone and the car screen without latency.

---

## 4. Summary Table of Capabilities

| Feature | Supported on iPhone | Supported on Kia Seltos CarPlay | Technical Justification |
| :--- | :--- | :--- | :--- |
| **YouTube Web Browsing** | ✅ Yes | ❌ No | Apple strictly disallows WebKit on CarPlay displays |
| **YouTube HTML5 Video Playback** | ✅ Yes | ❌ No | Head unit lacks AirPlay Video endpoint; restricted entitlement |
| **YouTube Picture-in-Picture (PiP)** | ✅ Yes | N/A | Supported natively by iOS AVKit / WebKit |
| **YouTube High-Fidelity Audio** | ✅ Yes | ✅ Yes (Car Speakers) | Wired USB lossless audio transmission via `AVAudioSession` |
| **CarPlay Now Playing Screen** | N/A | ✅ Yes | Full title, duration, scrubber via `MPNowPlayingInfoCenter` |
| **Steering Wheel Button Controls** | N/A | ✅ Yes | Hardware Play/Pause/Skip bound via `MPRemoteCommandCenter` |
| **One-Tap Channel Bookmarks** | ✅ Yes | ✅ Yes | Native `CPListTemplate` on Kia Seltos screen |
