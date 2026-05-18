package main

import (
	_ "embed"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/getlantern/systray"
)

//go:embed icon.png
var iconBytes []byte

func main() {
	systray.Run(onReady, onExit)
}

func onReady() {
	systray.SetIcon(iconBytes)
	systray.SetTooltip("LocalIP Utility")

	mHeader := systray.AddMenuItem("LOCAL NETWORK", "")
	mHeader.Disable()

	mIP := systray.AddMenuItem("IP Address: Checking...", "Click to copy local IP")
	systray.AddSeparator()
	mQuit := systray.AddMenuItem("Quit", "Quit LocalIP")

	go func() {
		for {
			ip := getLocalIP()
			mIP.SetTitle("IP Address: " + ip)
			
			// Dynamic environment variable injection (System-wide and file-backed)
			setLinuxEnv(ip)

			select {
			case <-mQuit.ClickedCh:
				systray.Quit()
				return
			case <-mIP.ClickedCh:
				copyToClipboard(ip)
				mIP.SetTitle("✓ Copied!")
				time.Sleep(1500 * time.Millisecond)
				mIP.SetTitle("IP Address: " + ip)
			case <-time.After(15 * time.Second):
				// Poll for IP shifts every 15s
			}
		}
	}()
}

func onExit() {
	// Clean up if needed
}

func getLocalIP() string {
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return "127.0.0.1"
	}
	for _, address := range addrs {
		if ipnet, ok := address.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
			if ipnet.IP.To4() != nil {
				return ipnet.IP.String()
			}
		}
	}
	return "127.0.0.1"
}

func copyToClipboard(text string) {
	// Try xclip (standard Linux clipboard tool)
	cmd := exec.Command("xclip", "-selection", "clipboard")
	cmd.Stdin = strings.NewReader(text)
	if err := cmd.Run(); err == nil {
		return
	}
	
	// Try xsel as fallback
	cmd = exec.Command("xsel", "--clipboard", "--input")
	cmd.Stdin = strings.NewReader(text)
	_ = cmd.Run()
}

func setLinuxEnv(ip string) {
	home, err := os.UserHomeDir()
	if err != nil {
		return
	}
	
	// 1. Write to ~/.local_ip for quick script access
	_ = os.WriteFile(filepath.Join(home, ".local_ip"), []byte(ip), 0644)

	// 2. Append profile exports for terminal sessions
	configureShell(filepath.Join(home, ".bashrc"))
	configureShell(filepath.Join(home, ".zshrc"))
	configureShell(filepath.Join(home, ".profile"))
}

func configureShell(path string) {
	content, err := os.ReadFile(path)
	if err != nil {
		// Create file if it's primary shell targets (.bashrc/.zshrc)
		if strings.HasSuffix(path, ".bashrc") || strings.HasSuffix(path, ".zshrc") {
			_ = os.WriteFile(path, []byte(""), 0644)
		} else {
			return
		}
	}
	
	if !strings.Contains(string(content), "LOCAL_IP=") {
		f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0644)
		if err == nil {
			defer f.Close()
			_, _ = f.WriteString("\n# Added by LocalIP app\nexport LOCAL_IP=$(cat ~/.local_ip 2>/dev/null || echo \"127.0.0.1\")\n")
		}
	}
}
