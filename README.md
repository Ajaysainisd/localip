# 🌐 LocalIP (Multi-Platform)

A fully native, lightweight, zero-dependency system tray utility that gives you instant, icon-only access to your local IP address and network details, while dynamically exposing a system-wide `$LOCAL_IP` environment variable that updates in real-time as you switch networks.

**LocalIP is natively compiled and optimized for macOS, Windows, and Linux!**

---

## 🎨 Premium App Icon

A modern, glassmorphic squircle icon featuring a glowing globe network utility design, compiled natively for each platform (AppKit `.icns` for Mac, native resources for Windows and Linux).

![LocalIP App Icon](icon.png)

---

## ✨ Features by Platform

### 🍎 macOS Version (Swift / AppKit)
- **Status Bar Icon**: Clean, icon-only globe indicator `🌐` (or `⚠️` wifi-slash when offline).
- **Environment Variable**: Dynamically injects `LOCAL_IP` into the user's GUI session via `launchctl setenv` and automatically configures standard shells (`~/.zshrc`, `~/.bash_profile`, `~/.bashrc`, `~/.profile`).
- **Interactive Details**: Multi-interface IP scanning, Router Gateway, Subnet Mask, Public IP, and Latency (ping `1.1.1.1`). Click any item to copy with a visual `✓ Copied!` morph animation.
- **Zero-Dependency**: Programmed in Swift with AppKit and low-level BSD sockets.

### 🪟 Windows Version (C# / Native .NET)
- **System Tray Icon**: Quietly sits in the taskbar notification area (uses native System Shield/Network icons).
- **Environment Variable**: Dynamically sets the persistent User-level system environment variable `LOCAL_IP` using Registry APIs. Any new Command Prompt, PowerShell, IDE, or background process immediately inherits it!
- **Interactive Details**: Shows local IPv4 address, with copy-on-click visual feedback.
- **Hyper-Lightweight**: Natively compiled into a tiny `20KB` standalone `.exe` with zero dependencies, requiring no separate runtimes or virtual environments.

### 🐧 Linux/Ubuntu Version (Go / GTK / Ayatana)
- **System Tray Icon**: Self-contained system tray indicator using the embedded globe icon.
- **Environment Variable**: Dynamically writes the current IP to `~/.local_ip` and appends profile exports to `~/.bashrc`, `~/.zshrc`, and `~/.profile` automatically on launch.
- **Interactive Details**: System-wide IP detection and zero-dependency copy-to-clipboard using native Linux `xclip` or `xsel` commands.
- **Performance**: Natively compiled Go binary executing in milliseconds with virtually zero memory overhead.

---

## 📂 Project Architecture

- **`main.swift`** — The native AppKit Swift source code for macOS.
- **`windows/LocalIP.cs`** — The native C# tray application for Windows.
- **`linux/main.go`** — The native Go tray application for Linux.
- **`.github/workflows/release.yml`** — Unified CI/CD workflow that spins up macOS, Windows, and Ubuntu virtual runners to compile and publish releases.

---

## 💻 Environment Variable Verification

No matter what operating system you are running, you can easily use `$LOCAL_IP` (or `%LOCAL_IP%` on Windows) in any custom application, script, or server config:

### 🍎 macOS & 🐧 Linux
1. Open a new terminal window.
2. Run:
   ```bash
   echo $LOCAL_IP
   ```
3. It will return your active network IP (e.g. `192.168.1.35`). Swapping networks re-populates the variable automatically in milliseconds!

### 🪟 Windows
1. Open a new Command Prompt or PowerShell window.
2. Run:
   ```cmd
   echo %LOCAL_IP%      # Command Prompt
   $env:LOCAL_IP        # PowerShell
   ```
3. It returns your active IP! Swapping networks updates the Registry key in the background.

---

## ⚙️ How to Download and Run

### 📦 Pre-compiled Releases
You do not need to install compilers or build tools! Simply go to the **[GitHub Releases Page](https://github.com/Ajaysainisd/localip/releases)** and download the bundled zip for your operating system:
- **macOS**: Download `LocalIP-macOS.zip`, extract it, and double-click `LocalIP.app`.
- **Windows**: Download `LocalIP-Windows.zip`, extract it, and double-click `LocalIP.exe`.
- **Linux/Ubuntu**: Download `LocalIP-Linux.tar.gz`, extract it, and run `./LocalIP-linux`.

---

## 🛠️ How to Compile Manually

If you prefer building from source:

- **macOS**: Run `./build.sh` (requires Xcode Command Line Tools).
- **Windows**: Run `csc /target:winexe /out:LocalIP.exe windows\LocalIP.cs` in the Developer Command Prompt.
- **Linux**: Install development headers (`sudo apt install libgtk-3-dev libayatana-appindicator3-dev`) and run `cd linux && go mod init localip && go mod tidy && go build -o LocalIP-linux main.go`.
