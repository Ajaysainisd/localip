import AppKit
import Foundation
import Network
import SystemConfiguration
import Darwin

// MARK: - Core Models

struct InterfaceAddress {
    var interface: String
    var ip: String
    var netmask: String
}

struct DefaultRouteInfo {
    var gateway: String?
    var interface: String?
}

// MARK: - Custom UI Component for Clipboard Copying

class CopyableMenuItem: NSMenuItem {
    var textToCopy: String = ""
    var originalTitle: String = ""
    
    init(title: String, textToCopy: String, keyEquivalent: String = "") {
        self.textToCopy = textToCopy
        self.originalTitle = title
        super.init(title: title, action: #selector(menuItemClicked(_:)), keyEquivalent: keyEquivalent)
        self.target = self
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @objc func menuItemClicked(_ sender: NSMenuItem) {
        guard !textToCopy.isEmpty else { return }
        
        // Copy to system pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(textToCopy, forType: .string)
        
        // Provide micro-interaction feedback
        self.title = "✓ Copied to Clipboard!"
        
        // Revert back after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            self.title = self.originalTitle
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    let pathMonitor = NWPathMonitor()
    
    // Dynamic network values
    var localInterfaces: [InterfaceAddress] = []
    var defaultRoute = DefaultRouteInfo()
    var publicIP: String? = nil
    var latency: String? = nil
    
    // Menu item references for in-place live updates
    var publicIPMenuItem: NSMenuItem?
    var latencyMenuItem: NSMenuItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory agent (hides Dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Create the system status bar item (icon only)
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusBarItem.button {
            button.title = "" // Icon only! No text on the status bar
            
            // Set standard modern SF Symbol for network
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "network", accessibilityDescription: "Local IP Utility") {
                    button.image = image
                }
            }
        }
        
        // Automatically and safely configure all available shell profiles (bash, zsh, etc.)
        setupShellConfig()
        
        // Listen for system network changes (Wi-Fi toggle, Ethernet plug/unplug, etc.)
        pathMonitor.pathUpdateHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshNetworkDetails()
            }
        }
        let queue = DispatchQueue(label: "com.ajaysaini.localip.monitor")
        pathMonitor.start(queue: queue)
        
        // Initial load
        refreshNetworkDetails()
    }
    
    // MARK: - Network Queries
    
    func refreshNetworkDetails() {
        // 1. Scan network interfaces
        self.localInterfaces = getLocalIPv4Addresses()
        
        // 2. Fetch routing gateway
        self.defaultRoute = getDefaultRouteInfo()
        
        // 3. Resolve active primary details
        var primaryIP = ""
        var primaryInterface = ""
        
        if let gatewayIntf = defaultRoute.interface {
            primaryInterface = gatewayIntf
            if let match = localInterfaces.first(where: { $0.interface == gatewayIntf }) {
                primaryIP = match.ip
            }
        }
        
        // Fallback if no default route matches
        if primaryIP.isEmpty && !localInterfaces.isEmpty {
            primaryIP = localInterfaces[0].ip
            primaryInterface = localInterfaces[0].interface
        }
        
        let activeIP = primaryIP.isEmpty ? "127.0.0.1" : primaryIP
        
        // 4. Update the menu bar button icon dynamically based on connectivity
        if let button = statusBarItem.button {
            if primaryIP.isEmpty {
                if #available(macOS 11.0, *) {
                    button.image = NSImage(systemSymbolName: "wifi.slash", accessibilityDescription: "Offline")
                }
            } else {
                if #available(macOS 11.0, *) {
                    button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Connected")
                }
            }
        }
        
        // 5. Dynamic environment variable injection (System-wide and file-backed)
        setSystemEnvironmentVariable(ip: activeIP)
        
        // 6. Reset background variables
        self.publicIP = nil
        self.latency = nil
        
        // 7. Build the menu
        constructMenu(primaryInterface: primaryInterface, primaryIP: primaryIP)
        
        // 8. Fire off background async details
        if !primaryIP.isEmpty {
            fetchPublicIPAddress()
            fetchLatency()
        }
    }
    
    func constructMenu(primaryInterface: String, primaryIP: String) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // SECTION: Local IP Details
        let localHeader = NSMenuItem(title: "LOCAL NETWORK", action: nil, keyEquivalent: "")
        localHeader.isEnabled = false
        localHeader.attributedTitle = NSAttributedString(
            string: "LOCAL NETWORK",
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 10),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        menu.addItem(localHeader)
        
        if primaryIP.isEmpty {
            let offlineItem = NSMenuItem(title: "Status: Disconnected", action: nil, keyEquivalent: "")
            offlineItem.isEnabled = false
            menu.addItem(offlineItem)
        } else {
            // Status and interface info
            let activeInterfaceItem = NSMenuItem(title: "Active Interface: \(primaryInterface)", action: nil, keyEquivalent: "")
            activeInterfaceItem.isEnabled = false
            menu.addItem(activeInterfaceItem)
            
            // IP Address
            let ipItem = CopyableMenuItem(title: "IP Address: \(primaryIP)", textToCopy: primaryIP)
            menu.addItem(ipItem)
            
            // Subnet mask
            if let matchedIntf = localInterfaces.first(where: { $0.interface == primaryInterface }) {
                let maskItem = CopyableMenuItem(title: "Subnet Mask: \(matchedIntf.netmask)", textToCopy: matchedIntf.netmask)
                menu.addItem(maskItem)
            }
            
            // Gateway
            if let gateway = defaultRoute.gateway {
                let gatewayItem = CopyableMenuItem(title: "Router Gateway: \(gateway)", textToCopy: gateway)
                menu.addItem(gatewayItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // SECTION: External / WAN Status
        let externalHeader = NSMenuItem(title: "EXTERNAL STATUS", action: nil, keyEquivalent: "")
        externalHeader.isEnabled = false
        externalHeader.attributedTitle = NSAttributedString(
            string: "EXTERNAL STATUS",
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 10),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        menu.addItem(externalHeader)
        
        // Public IP (Filled in background)
        let publicIPItem = CopyableMenuItem(title: "Public IP: Fetching...", textToCopy: "")
        publicIPItem.isEnabled = false
        menu.addItem(publicIPItem)
        self.publicIPMenuItem = publicIPItem
        
        // Latency / Ping (Filled in background)
        let latencyItem = NSMenuItem(title: "Ping (1.1.1.1): Checking...", action: nil, keyEquivalent: "")
        latencyItem.isEnabled = false
        menu.addItem(latencyItem)
        self.latencyMenuItem = latencyItem
        
        // SECTION: Other active interfaces
        let otherInterfaces = localInterfaces.filter { $0.interface != primaryInterface }
        if !otherInterfaces.isEmpty {
            menu.addItem(NSMenuItem.separator())
            
            let otherHeader = NSMenuItem(title: "OTHER INTERFACES", action: nil, keyEquivalent: "")
            otherHeader.isEnabled = false
            otherHeader.attributedTitle = NSAttributedString(
                string: "OTHER INTERFACES",
                attributes: [
                    .font: NSFont.boldSystemFont(ofSize: 10),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
            menu.addItem(otherHeader)
            
            for intf in otherInterfaces {
                let otherItem = CopyableMenuItem(title: "\(intf.interface): \(intf.ip)", textToCopy: intf.ip)
                menu.addItem(otherItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // SECTION: Actions
        let copyAllItem = NSMenuItem(title: "Copy All Details", action: #selector(copyAllClicked(_:)), keyEquivalent: "c")
        copyAllItem.target = self
        menu.addItem(copyAllItem)
        
        let refreshItem = NSMenuItem(title: "Refresh Network Info", action: #selector(refreshMenuClicked(_:)), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit LocalIP", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)
        
        statusBarItem.menu = menu
        
        // Restore items if already loaded
        updatePublicIPMenuItem()
        updateLatencyMenuItem()
    }
    
    // MARK: - In-place updates
    
    func updatePublicIPMenuItem() {
        guard let item = publicIPMenuItem as? CopyableMenuItem else { return }
        if let ip = publicIP {
            item.textToCopy = ip
            item.originalTitle = "Public IP: \(ip)"
            item.title = item.originalTitle
            item.isEnabled = true
        } else {
            item.title = "Public IP: Fetching..."
            item.textToCopy = ""
            item.isEnabled = false
        }
    }
    
    func updateLatencyMenuItem() {
        guard let item = latencyMenuItem else { return }
        if let lat = latency {
            item.title = "Ping (1.1.1.1): \(lat)"
        } else {
            item.title = "Ping (1.1.1.1): Checking..."
        }
    }
    
    // MARK: - Dynamic Environment Setup
    
    func setSystemEnvironmentVariable(ip: String) {
        // 1. Expose to all GUI session applications spawned under launchd (IDE, GUI apps, VS Code, Alfred, etc.)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["setenv", "LOCAL_IP", ip]
        try? process.run()
        
        // 2. Persist to a small text file for terminal integrations
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let localIPFile = homeDir.appendingPathComponent(".local_ip")
        try? ip.write(to: localIPFile, atomically: true, encoding: .utf8)
    }
    
    func setupShellConfig() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        // Shell profile targets to configure
        let profiles = [".zshrc", ".bash_profile", ".bashrc", ".profile"]
        
        let commentLine = "# Added by LocalIP app"
        let exportLine = "export LOCAL_IP=$(cat ~/.local_ip 2>/dev/null || echo \"127.0.0.1\")"
        
        for profile in profiles {
            let profileURL = homeDir.appendingPathComponent(profile)
            
            // Only update/create .zshrc and .bash_profile by default; other profiles only if they already exist
            let fileExists = FileManager.default.fileExists(atPath: profileURL.path)
            if !fileExists {
                if profile != ".zshrc" && profile != ".bash_profile" {
                    continue
                }
            }
            
            var content = ""
            if fileExists {
                if let currentContent = try? String(contentsOf: profileURL, encoding: .utf8) {
                    content = currentContent
                }
            }
            
            // Inject export rule if not already present
            if !content.contains("LOCAL_IP=") {
                let delimiter = content.isEmpty || content.hasSuffix("\n") ? "" : "\n"
                let appendText = "\(delimiter)\n\(commentLine)\n\(exportLine)\n"
                
                if content.isEmpty {
                    try? appendText.write(to: profileURL, atomically: true, encoding: .utf8)
                } else {
                    if let fileHandle = try? FileHandle(forWritingTo: profileURL) {
                        fileHandle.seekToEndOfFile()
                        if let data = appendText.data(using: .utf8) {
                            fileHandle.write(data)
                        }
                        fileHandle.closeFile()
                    }
                }
            }
        }
    }
    
    // MARK: - Async Background Fetchers
    
    func fetchPublicIPAddress() {
        guard let url = URL(string: "https://api.ipify.org") else { return }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard error == nil,
                  let data = data,
                  let ipString = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) else {
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.publicIP = ipString
                self.updatePublicIPMenuItem()
            }
        }
        task.resume()
    }
    
    func fetchLatency() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "1", "-t", "2", "1.1.1.1"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            let queue = DispatchQueue.global(qos: .background)
            queue.async { [weak self] in
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8) else { return }
                
                var result: String? = nil
                if let timeRange = output.range(of: "time=") {
                    let sub = output[timeRange.upperBound...]
                    if let spaceRange = sub.range(of: " ") {
                        let msValue = sub[..<spaceRange.lowerBound]
                        result = "\(msValue) ms"
                    }
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.latency = result ?? "Timeout"
                    self.updateLatencyMenuItem()
                }
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.latency = "Failed to run ping"
                self?.updateLatencyMenuItem()
            }
        }
    }
    
    // MARK: - Actions
    
    @objc func refreshMenuClicked(_ sender: NSMenuItem) {
        refreshNetworkDetails()
    }
    
    @objc func copyAllClicked(_ sender: NSMenuItem) {
        var summary = "=== NETWORK UTILITY DETAILS ===\n"
        
        summary += "Local Interfaces:\n"
        for intf in localInterfaces {
            summary += " - \(intf.interface): \(intf.ip) (Netmask: \(intf.netmask))\n"
        }
        
        if let gateway = defaultRoute.gateway {
            summary += "Gateway Router: \(gateway)\n"
        }
        
        if let extIP = publicIP {
            summary += "Public IP: \(extIP)\n"
        }
        
        if let latVal = latency {
            summary += "Latency (1.1.1.1): \(latVal)\n"
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(summary, forType: .string)
        
        // Interactive visual feedback
        sender.title = "✓ Copied All Details!"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            sender.title = "Copy All Details"
        }
    }
}

// MARK: - Network Resolvers (Low level)

func getLocalIPv4Addresses() -> [InterfaceAddress] {
    var addresses = [InterfaceAddress]()
    
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0 else { return addresses }
    guard let firstAddr = ifaddr else { return addresses }
    
    let NI_MAXHOST = 1025
    
    for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
        let flags = Int32(ptr.pointee.ifa_flags)
        guard let addrPtr = ptr.pointee.ifa_addr else { continue }
        let addr = addrPtr.pointee
        
        // Active interfaces, skip loopback
        if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
            if addr.sa_family == UInt8(AF_INET) {
                let name = String(cString: ptr.pointee.ifa_name)
                
                // IP Address Conversion
                var ipBuffer = [CChar](repeating: 0, count: NI_MAXHOST)
                let ipSuccess = getnameinfo(
                    addrPtr,
                    socklen_t(addr.sa_len),
                    &ipBuffer,
                    socklen_t(ipBuffer.count),
                    nil, 0,
                    NI_NUMERICHOST
                ) == 0
                
                // Subnet Mask Conversion
                var netmask = ""
                if let netmaskPtr = ptr.pointee.ifa_netmask {
                    var netmaskBuffer = [CChar](repeating: 0, count: NI_MAXHOST)
                    let netmaskSuccess = getnameinfo(
                        netmaskPtr,
                        socklen_t(netmaskPtr.pointee.sa_len),
                        &netmaskBuffer,
                        socklen_t(netmaskBuffer.count),
                        nil, 0,
                        NI_NUMERICHOST
                    ) == 0
                    if netmaskSuccess {
                        netmask = String(cString: netmaskBuffer)
                    }
                }
                
                if ipSuccess {
                    let ip = String(cString: ipBuffer)
                    addresses.append(InterfaceAddress(interface: name, ip: ip, netmask: netmask))
                }
            }
        }
    }
    freeifaddrs(ifaddr)
    return addresses
}

func getDefaultRouteInfo() -> DefaultRouteInfo {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/sbin/route")
    process.arguments = ["-n", "get", "default"]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    var info = DefaultRouteInfo()
    
    do {
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            for line in output.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.starts(with: "gateway:") {
                    let parts = trimmed.components(separatedBy: ":")
                    if parts.count > 1 {
                        info.gateway = parts[1].trimmingCharacters(in: .whitespaces)
                    }
                } else if trimmed.starts(with: "interface:") {
                    let parts = trimmed.components(separatedBy: ":")
                    if parts.count > 1 {
                        info.interface = parts[1].trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }
    } catch {
        // Fallback
    }
    
    return info
}

// MARK: - Bootstrapping

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
