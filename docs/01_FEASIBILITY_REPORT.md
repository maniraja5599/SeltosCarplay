# Deliverable 1: Feasibility Report

**Project:** Private CarPlay Browser for Kia Seltos  
**Author:** Senior iOS Engineer & Security Specialist  
**Target Vehicle:** Kia Seltos (Infotainment: Gen5W / ccNC Display Audio)  
**Host Devices:** Apple iPhone (iOS 16+), Windows Development PC  

---

## 1. Executive Summary

This feasibility report examines the technical, legal, and architectural realities of building a private iPhone web browser capable of navigating websites (including YouTube) and presenting content on a vehicle head unit via Apple CarPlay.

### Summary of Verdicts:
1. **iPhone Browser Application:** **100% Feasible.** A full-featured, Chrome-like browser with tabs, bookmarks, local history persistence, customizable search engines, HTTPS enforcement, and inline YouTube playback can be completely implemented using Swift, SwiftUI, and WebKit (`WKWebView`).
2. **CarPlay Web Browser Display:** **Restricted by Apple Platform Architecture.** Apple does **not** provide a web browser category or a public WebKit canvas API for Apple CarPlay. All CarPlay third-party UI must be rendered via strict, standardized `CPTemplate` interfaces (`CPListTemplate`, `CPGridTemplate`, `CPTabBarTemplate`, `CPInformationTemplate`, `CPNowPlayingTemplate`). Arbitrary `UIView` hierarchies and `WKWebView` cannot be instantiated on standard CarPlay template scenes.
3. **CarPlay Video Playback:** **Severely Restricted & Hardware-Dependent.** 
   - Apple introduced a restricted entitlement (`com.apple.developer.carplay-video`) allowing parked-only video playback via vehicle AirPlay video streaming protocols.
   - This entitlement requires formal business application and explicit manual approval from Apple's CarPlay partnership team.
   - Furthermore, the vehicle's infotainment system (e.g., Kia Seltos Gen5W) must explicitly implement Apple's AirPlay Video endpoint protocol. Factory Kia Seltos head units support standard CarPlay (Audio, Navigation, Messaging, POI), but do **not** support AirPlay Video receiver endpoints.
4. **YouTube Playback on CarPlay:**
   - **Video on CarPlay:** Blocked by both lack of video entitlement and vehicle head unit firmware limitations.
   - **Audio Stream & Metadata on CarPlay:** **100% Feasible.** The application can extract and play audio streams or background web audio through `AVPlayer` / `AVAudioSession`, relay metadata and artwork to `MPNowPlayingInfoCenter`, and offer full steering-wheel and head-unit playback controls via `MPRemoteCommandCenter` and `CPNowPlayingTemplate`.

---

## 2. Forensic Analysis of APTV and Third-Party Solutions

### 2.1 What APTV Officially Advertises
APTV (*APTV - M3U Player & Streamer*) is marketed on the iOS App Store as an IPTV/M3U playlist player and casting client. In recent versions, user communities (e.g., Reddit `r/CarPlay`, YouTube) noted features labeled **"Quick > Browser"** and video casting.

### 2.2 How APTV Functions Under the Hood
Forensic analysis of APTV's behavior and public technical disclosures reveals the following:
1. **Category Disguise:** APTV is registered under the App Store as an Audio/Media player or utility app. It requests audio background modes (`audio` in `UIBackgroundModes`) to sustain process life.
2. **CarPlay Template Navigation:** On CarPlay, APTV renders standard `CPListTemplate` and `CPGridTemplate` menus containing predefined shortcuts ("Quick", "Favorites", "Web Links").
3. **Video / Browser Workarounds:**
   - When users tap web links or "Browser" inside APTV on CarPlay, early versions attempted to hook into private screen mirroring sessions or second-window display contexts (`UIScreenDidConnectNotification` / `UIWindowScene`), which Apple began blocking in modern iOS versions.
   - Recent versions of APTV on the App Store that advertise CarPlay video rely on **AirPlay mirroring / DLNA streaming**, or prompt the user to interact with the phone directly while piping audio over CarPlay.
   - Applications that bypass Apple's template restrictions by injecting video into unauthorized CarPlay buffers are routinely identified by automated App Store Review scanners and removed or forced to strip the feature.

### 2.3 App Store vs. Private Sideloading vs. Jailbreak

| Distribution Channel | CarPlay Browser Possibility | CarPlay Video Possibility | Stability & Legality |
| :--- | :--- | :--- | :--- |
| **App Store (Public)** | ❌ Strictly Prohibited (Guidelines 2.5.1, 1.4.2) | ⚠️ Requires Apple `carplay-video` entitlement + Automaker AirPlay video support | 100% Legal, high scrutiny |
| **Private Dev / Ad-Hoc Signing** | ❌ Blocked by OS Sandbox (iOS enforces `CPTemplate` on CarPlay display) | ⚠️ Blocked if Head Unit lacks AirPlay Video endpoint | 100% Private, requires 7-day or 1-year developer cert |
| **Jailbreak (e.g., CarBridge / NGXPlay)** | ✅ Injects raw SpringBoard window onto CarPlay screen | ✅ Injects arbitrary `UIView` / `WKWebView` | ❌ Requires iOS kernel exploit; unstable, voids security posture |
| **Aftermarket Hardware (AI Boxes)** | ✅ Android OS runs on dongle; projects video over CarPlay video feed | ✅ Native Android apps (YouTube/Chrome) | Third-party USB dongle ($80–$150) |

---

## 3. Apple CarPlay Framework & Entitlement Rules

Apple restricts CarPlay to specific app categories to prevent driver distraction (NHTSA / UNECE vehicle safety compliance).

### 3.1 Documented CarPlay App Categories

| Category | Entitlement Key | Permitted UI Elements |
| :--- | :--- | :--- |
| **Audio** | `com.apple.developer.carplay-audio` | `CPListTemplate`, `CPTabBarTemplate`, `CPNowPlayingTemplate`, `CPSearchTemplate` |
| **Communication / Messaging** | `com.apple.developer.carplay-messaging` | Voice-driven messaging (SiriKit / `INSendMessageIntent`), contact lists |
| **Navigation** | `com.apple.developer.carplay-maps` | `CPMapTemplate`, custom map rendering via `CPMapContentWindow` |
| **Parking** | `com.apple.developer.carplay-parking` | `CPPointOfInterestTemplate`, `CPListTemplate` |
| **EV Charging** | `com.apple.developer.carplay-charging` | `CPPointOfInterestTemplate`, charging station lists |
| **Quick Ordering** | `com.apple.developer.carplay-quick-ordering` | Order history list, simple confirm buttons |
| **Video (Parked Only)** | `com.apple.developer.carplay-video` | `CPTemplateApplicationScene` with AirPlay Video receiver handshake |

### 3.2 The Strict Absence of a "Browser" Category
Apple provides **zero public APIs** to render HTML, WebKit, or Safari view controllers on CarPlay.
- `WKWebView` cannot be embedded inside any `CPTemplate`.
- `SFSafariViewController` is unavailable on CarPlay scenes.
- Attempting to add a custom `UIView` to `CPTemplateApplicationScene.carWindow` triggers an immediate runtime exception or renders a black surface.

### 3.3 The `com.apple.developer.carplay-video` Entitlement
- Introduced for parked-vehicle entertainment (e.g., watching while charging an EV).
- **Condition 1:** The app must hold the explicit profile entitlement granted by Apple Developer Relations.
- **Condition 2:** The vehicle head unit must signal `videoPlaybackSupported == true` via `CPPlaybackConfiguration`.
- **Condition 3:** Vehicle must be in **Park (P)**. As soon as the parking brake is disengaged or gear shifts to Drive (D) / Reverse (R), the system cuts video transmission.

---

## 4. Kia Seltos Infotainment System Analysis

### 4.1 Head Unit Hardware & Software Stack
Kia Seltos models (2020–present) are equipped with either:
1. **8.0-inch Display Audio (Standard):** Powered by an embedded Linux / QNX microkernel system. Supports wired Apple CarPlay and Android Auto.
2. **10.25-inch / 12.3-inch Navigation (Gen5W / ccNC):** Hyundai/Kia Mobis infotainment platform running on embedded automotive Linux with navigation maps and Kia Connect telematics.

### 4.2 CarPlay Capabilities on Kia Seltos
- **Protocol:** Standard Apple CarPlay over USB (Lightning / USB-C data port).
- **Display Resolution:** Typically $1280 \times 720$ (8-inch) or $1920 \times 720$ split-screen (10.25-inch/12.3-inch).
- **Supported Profiles:**
  - Audio: AAC-LC, PCM stereo stream.
  - Video Feed from iPhone: H.264 UI stream of the CarPlay interface.
  - Input: Capacitive touch events, physical rotary dial / track seek buttons, steering wheel controls.
- **AirPlay Video Endpoint:** **Not implemented.** Kia Mobis firmware does not contain the Apple AirPlay Video receiver profile required to negotiate the `carplay-video` playback pipeline.

---

## 5. Legitimate & Compliant Architecture Solution

To deliver the best possible user experience without violating safety regulations or relying on fragile exploits, our application will adopt a **Dual-Mode Architectural Model**:

```
+-----------------------------------------------------------------------------------+
|                              SeltosBrowser Application                            |
+---------------------------------------------------------+-------------------------+
|                    iPhone Interface                     |     CarPlay Interface   |
|                 (Full Browser Experience)               |   (Audio & Navigation)  |
+---------------------------------------------------------+-------------------------+
| - Multi-Tab Browser with Address Bar & HTTPS Lock       | - CarPlay Scene Delegate|
| - Custom WebKit Engine with Privacy & Error Handling    | - Bookmarks Browser     |
| - Full YouTube Website & HTML5 Embedded Player          | - Media Queue & Recents |
| - Picture-in-Picture (PiP) and Background Media Playback| - Now Playing Template  |
| - Bookmark & History Manager (Local JSON Persistence)   | - Steering Wheel Remote |
| - Vehicle Safety State Monitor                          | - Safety Park Indicator |
+---------------------------------------------------------+-------------------------+
                               |                                       |
                               +-------------------+-------------------+
                                                   |
                                       +-----------------------+
                                       | Shared Data & Media   |
                                       | - Local Store (JSON)  |
                                       | - AudioSessionManager |
                                       | - NowPlayingManager   |
                                       +-----------------------+
```

1. **On iPhone:**
   - Chrome-like browsing interface with address bar, search engine selector, back/forward/reload, multiple tabs, bookmarks, history, and privacy controls.
   - Rich YouTube web playback with HTML5 inline controls and Picture-in-Picture (PiP).
   - Audio extraction/playback coordination to keep media playing when the phone screen is locked or docked in the car.
2. **On Kia Seltos CarPlay Display:**
   - Registers as an official CarPlay Audio/Media application (`com.apple.developer.carplay-audio`).
   - Renders a clean `CPTabBarTemplate` featuring:
     - **Bookmarks / Web Links:** Allows one-tap launching of saved sites/audio streams from the car screen.
     - **Recent History:** Browse recently visited multimedia sites.
     - **Now Playing:** Displays current YouTube/Web media title, channel/artist, playback scrubber, and play/pause/skip buttons integrated directly with the Kia Seltos steering wheel and touchscreen controls.
   - Includes safety architecture checking vehicle movement status.
