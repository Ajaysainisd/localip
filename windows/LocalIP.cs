using System;
using System.Drawing;
using System.Windows.Forms;
using System.Net;
using System.Net.NetworkInformation;
using System.Diagnostics;
using System.IO;

public class LocalIPApp : ApplicationContext
{
    private NotifyIcon trayIcon;
    private ContextMenuStrip trayMenu;
    private string localIP = "127.0.0.1";
    
    [STAThread]
    public static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new LocalIPApp());
    }
    
    public LocalIPApp()
    {
        trayMenu = new ContextMenuStrip();
        
        // Use standard system network shield/globe icon as default tray icon
        trayIcon = new NotifyIcon()
        {
            Icon = SystemIcons.Shield,
            ContextMenuStrip = trayMenu,
            Visible = true,
            Text = "LocalIP Utility"
        };
        
        RefreshDetails();
        
        // Refresh every 15 seconds to monitor network changes
        var timer = new Timer();
        timer.Interval = 15000;
        timer.Tick += (s, e) => RefreshDetails();
        timer.Start();
    }
    
    private void RefreshDetails()
    {
        localIP = GetLocalIP();
        
        // Dynamically expose the user-level system-wide environment variable LOCAL_IP
        try
        {
            Environment.SetEnvironmentVariable("LOCAL_IP", localIP, EnvironmentVariableTarget.User);
        }
        catch { }
        
        trayMenu.Items.Clear();
        
        var header = new ToolStripMenuItem("LOCAL NETWORK") { Enabled = false };
        header.Font = new Font(header.Font, FontStyle.Bold);
        trayMenu.Items.Add(header);
        
        var ipItem = new ToolStripMenuItem("IP Address: " + localIP);
        ipItem.Click += (s, e) => {
            Clipboard.SetText(localIP);
            ipItem.Text = "✓ Copied to Clipboard!";
            
            var t = new Timer { Interval = 1500 };
            t.Tick += (sender, args) => { 
                ipItem.Text = "IP Address: " + localIP; 
                t.Stop(); 
                t.Dispose();
            };
            t.Start();
        };
        trayMenu.Items.Add(ipItem);
        
        trayMenu.Items.Add("-");
        
        var quitItem = new ToolStripMenuItem("Quit", null, (s, e) => {
            trayIcon.Visible = false;
            Application.Exit();
        });
        trayMenu.Items.Add(quitItem);
    }
    
    private string GetLocalIP()
    {
        try
        {
            foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (ni.OperationalStatus == OperationalStatus.Up && 
                    ni.NetworkInterfaceType != NetworkInterfaceType.Loopback)
                {
                    foreach (var ip in ni.GetIPProperties().UnicastAddresses)
                    {
                        if (ip.Address.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork)
                        {
                            return ip.Address.ToString();
                        }
                    }
                }
            }
        }
        catch { }
        return "127.0.0.1";
    }
}
