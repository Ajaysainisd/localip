# 🌐 LocalIP

A fully native, lightweight, zero-dependency macOS menu bar utility that gives you instant access to your local IP address and key network details, while dynamically exposing a system-wide `$LOCAL_IP` environment variable that updates in real-time as you switch networks.

---

## 🎨 Premium App Icon

We generated a beautiful, glassmorphic squircle icon for the application bundle. The icon has been compiled into the standard macOS native `.icns` format and embedded into the app.

![LocalIP App Icon](icon.png)

---

## ✨ Features and Highlights

- **Sleek Icon-Only Status Bar**: Your menu bar stays clean! It only displays the glowing network icon `🌐` (or `⚠️` wifi-slash when offline). Simply click the icon to see the IP address, subnet, gateway, public IP, and latency.
- **Dynamic `$LOCAL_IP` Environment Variable**: Exposes a real-time, system-wide variable that any application or process on your Mac can use:
  - **For GUI Applications (VS Code, Xcode, Docker, etc.)**: Set dynamically via `launchctl setenv LOCAL_IP <ip>`. Any editor or application launched in your user session inherits this variable automatically!
  - **For Terminal Sessions (`bash`, `zsh`, scripts)**: Sourced dynamically from `~/.local_ip`. Open a new terminal window at home or office, and typing `echo $LOCAL_IP` immediately returns your correct local network IP address!
- **Auto-Updates on Network Shift**: Seamlessly integrated with Apple's `NWPathMonitor` framework. When you wake your Mac up, switch networks, or move between home and office, the status bar app automatically triggers a background interface scan, writes the new IP to `~/.local_ip`, and updates the `launchctl` environment variable in **milliseconds**!
- **Interactive Copy-on-Click**: Clicking on any network detail (IP, subnet, gateway, public IP) instantly copies it to your system clipboard, with row titles morphing into `✓ Copied to Clipboard!` for satisfying, responsive micro-interaction feedback.
- **Zero Dependencies & Heavy Tooling**: Compiled using native `swiftc` into a standalone macOS background application (`LocalIP.app`) with no Electron, Node.js, or complex framework runtimes.

---

## 📂 Project Architecture

- **`main.swift`** — The native AppKit Swift source code, complete with POSIX scanning and environment variable injection.
- **`icon.png`** — High-res source PNG used for generating bundle assets.
- **`build.sh`** — Shell script automating stopping active app processes, swift compilation, plist generation, and `.icns` iconset conversion.
- **`LocalIP.app/`** — The finalized background application bundle.

---

## 💻 Terminal Integration & Verification

To make terminals pick up this environment variable automatically, the app has safely and automatically added the following lines to your shell profiles (`~/.bash_profile`, `~/.zshrc`, `~/.bashrc`, and `~/.profile` if they exist):
```bash
# Added by LocalIP app
export LOCAL_IP=$(cat ~/.local_ip 2>/dev/null || echo "127.0.0.1")
```
*(This is added once; the app detects it and will never add duplicate entries).*

### 🔍 How to Verify
To verify that everything is working perfectly:
1. **Open a new terminal window** (to let the shell source your profile).
2. Run the command:
   ```bash
   echo $LOCAL_IP
   ```
3. It will immediately output your current network IP (e.g., `192.168.1.35`)!
4. When you connect to another network, your app updates `~/.local_ip` instantly. Any new terminal window you open after the swap will print the *new* network IP!

---

## ⚙️ How to Manage and Rebuild

### 🏃‍♂️ Running the Application
The application runs as an accessory background process (no Dock icon).
- To launch the app:
  ```bash
  open LocalIP.app
  ```
- To quit the app: Click the `🌐` icon in your status bar and select **Quit LocalIP**.

### 🛠️ Rebuilding the App
If you make any modifications to `main.swift`, rebuild a fresh app bundle by running:
```bash
./build.sh
```
This script safely stops any active instances of the app, recompiles the Swift source, regenerates the plist metadata, and packages it in under 2 seconds!

### 🚀 Setting Up Auto-Launch at Startup
Because `LocalIP.app` is built as a standard macOS application bundle, you can set it to automatically run every time you log in to your Mac:

1. Open **System Settings** on your Mac.
2. Navigate to **General ➔ Login Items** (or search for *Login Items*).
3. Under the **Open at Login** section, click the **`+`** (Plus) button.
4. Select `LocalIP.app` from your project folder and click **Add**.
5. *Done!* The application will now run quietly in the background every time you boot your computer.

---

> **Pro-Tip**: You can move `LocalIP.app` to your system's `/Applications` directory if you prefer keeping it alongside your other programs. Just make sure to update your Login Items shortcut if you move it!
