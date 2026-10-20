# Deliverable 7: Build, Signing, and Installation Guide

**Project:** Private CarPlay Browser for Kia Seltos (`SeltosBrowser`)  
**Workflows:** Windows Preparation (Workflow A) & Native iOS Deployment (Workflow B)  

---

## 1. Overview of Development Environments

Developing an iOS application with Apple CarPlay capabilities requires an explicit understanding of platform boundaries:

| Development Task | Windows PC (Current Machine) | macOS (Physical or Cloud Mac) |
| :--- | :---: | :---: |
| **Write & Edit Swift / SwiftUI Source Code** | ✅ Yes (VS Code) | ✅ Yes (Xcode / VS Code) |
| **Manage Git Repository & Architecture Docs** | ✅ Yes | ✅ Yes |
| **Maintain Project Structure (`project.yml`)** | ✅ Yes | ✅ Yes |
| **Generate `.xcodeproj` Project Files** | ❌ Requires Mac / Ruby / Go | ✅ Yes (`xcodegen generate`) |
| **Compile Swift & WebKit into ARM64 iOS Binary** | ❌ No native iOS SDK | ✅ Yes (`xcodebuild` / Xcode) |
| **Apply Apple Code Signing & Provisioning** | ❌ Requires Apple Security Framework | ✅ Yes (Xcode Automatic Signing) |
| **Deploy & Debug App on Physical iPhone (iOS 16+)** | ❌ Blocked by Apple Driver Stack | ✅ Yes (Xcode / `ios-deploy`) |
| **CarPlay Simulator Testing** | ❌ Not available | ✅ Yes (Xcode CarPlay Simulator) |

---

## 2. Workflow A: Windows Preparation & Management

You can complete all source authoring, code management, and automated verification on your Windows PC:

### Step A.1: Tooling Installation on Windows
1. **Git:** Verify Git is installed:
   ```powershell
   git --version
   ```
2. **Visual Studio Code:** Install VS Code with the following recommended extensions:
   - **Swift** (by Swift Server Workgroup)
   - **Prettier / Markdown All in One**
   - **Mermaid Preview** (to view architecture diagrams)

### Step A.2: Initialize Local Git Repository
From the project root (`c:\Moved_From_E\TEST\Apple CarPlay`):
```powershell
git init
git add .
git commit -m "Initial commit: SeltosBrowser architecture, source prototype, and CarPlay specs"
```

---

## 3. Workflow B: Native iOS Build, Signing & Deployment

To compile, sign, and install `SeltosBrowser` onto your iPhone, you will use a Mac (physical Mac, MacBook, Mac mini, or Cloud Mac such as MacinCloud / AWS EC2 Mac / GitHub Actions).

### Step B.1: Transfer Repository to Mac
Clone or copy the repository onto the Mac:
```bash
git clone <your-repo-url> SeltosBrowser
cd SeltosBrowser
```

### Step B.2: Generate the Xcode Project via XcodeGen
If `xcodegen` is not already installed on the Mac:
```bash
brew install xcodegen
```
Generate the complete `.xcodeproj` instantly:
```bash
xcodegen generate
```
*Output: `Generated SeltosBrowser.xcodeproj`*

### Step B.3: Configure Signing & Bundle Identifier
1. Double-click `SeltosBrowser.xcodeproj` to open it in **Xcode 15 or 16**.
2. Select the top-level **SeltosBrowser** project in the Project Navigator.
3. Select the **SeltosBrowser** Target -> **Signing & Capabilities** tab.
4. Under **Signing**, check **Automatically manage signing**.
5. Select your **Team** (your personal Apple ID or Paid Developer Account).
6. Change the **Bundle Identifier** to something unique to your account (e.g., `com.yourname.seltosbrowser`).
   > **Note on Free Apple ID vs Paid Developer Account:**
   > - **Free Apple ID:** Allows signing and installing onto your personal iPhone. Certificates last 7 days before needing a re-sign. Standard CarPlay Audio capabilities operate for development testing.
   > - **Paid Apple Developer Account ($99/year):** Certificates last 1 year. Enables official CarPlay entitlement provisioning profiles on device.

### Step B.4: Prepare iPhone for Sideloading
1. Connect your iPhone to the Mac using a USB-to-Lightning or USB-C cable.
2. On your iPhone, unlock the screen and tap **Trust This Computer**.
3. Enable **Developer Mode** on your iPhone (iOS 16+ requirement):
   - Open **Settings** > **Privacy & Security**.
   - Scroll to the bottom and tap **Developer Mode**.
   - Toggle **Developer Mode** ON and restart your iPhone when prompted.
   - After restart, unlock the phone and tap **Turn On** in the confirmation dialog.

### Step B.5: Build and Run on iPhone
1. In Xcode, set the run destination in the top toolbar to your connected **iPhone**.
2. Press **Cmd + R** (or click the **Play** button).
3. Xcode will compile Swift files, link WebKit and CarPlay frameworks, sign the `.app` bundle, and install it onto your device.
4. If your iPhone prompts that the developer certificate is untrusted:
   - On iPhone, open **Settings** > **General** > **VPN & Device Management**.
   - Tap your Apple ID under *Developer App*.
   - Tap **Trust "[Your Name / Apple ID]"** and confirm.
5. Tap the **Seltos Browser** icon on your iPhone home screen to launch.

---

## 4. Connecting and Testing with Kia Seltos USB CarPlay

### Step C.1: Physical In-Car Connection
1. Bring your iPhone and a **high-quality, MFi-certified USB data cable** to your Kia Seltos.
   > ⚠️ *Important:* Use the primary **multimedia USB data port** located in the front center console (next to the 12V socket / wireless charging pad). Do not use the rear seat or passenger USB charging-only ports.
2. Turn on the vehicle ignition (or start the engine).
3. Plug the USB cable into the Kia Seltos data port and into your iPhone.

### Step C.2: Initial CarPlay Handshake
1. The Kia Seltos infotainment screen will display: *"Apple CarPlay Connected. Tap to start."*
2. Your iPhone will display a prompt: *"Allow Seltos Browser with CarPlay while phone is locked?"* Tap **Allow**.
3. On the Kia Seltos display, navigate to the CarPlay app grid.
4. Locate and tap the **Seltos Browser** icon.

### Step C.3: In-Vehicle Operation
1. The Kia Seltos screen will present the **Seltos Browser** CarPlay interface with three tabs: **Favorites**, **Recents**, and **Safety**.
2. Tap **Favorites** > **YouTube** from the car screen.
3. On your iPhone (mounted in a dashboard cradle or resting in the console), the browser automatically opens YouTube.
4. Play any video. The audio streams with lossless clarity through the Kia Seltos speaker system.
5. The Kia Seltos display switches to the **Now Playing HUD**, showing the video title and playback scrubber.
6. Test your **steering wheel Seek Up / Seek Down and Mute/Pause buttons**; notice that YouTube playback responds instantaneously.
