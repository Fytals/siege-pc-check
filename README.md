How to use
use this command in a powershell window thats run as admin 
command starts here -  iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/Fytals/siege-pc-check/main/pccheck.ps1')) ends here
1.
- Write-Log: Timestamps and logs messages
- Get-ColoredChoice: Creates colored Y/N prompts (Green/Red)
2. Security Status Checks
- Secure Boot status
- Virtualization status
- Kernel DMA Protection status
3. System Information
- OS Installation Date check
- Recent EXE Executions monitoring
- Running Applications check with:
- Application name
- Start time
- CPU usage
4. Browser Activity
- Chrome downloads history
- Firefox downloads history
- Edge downloads history
- Downloads folder monitoring
- Filters for suspicious file types (.exe, .zip, .rar, .7z, .dll)
5. R6S Specific Checks
- Installation path detection (multiple locations)
- BattlEye anti-cheat service status
- Suspicious DLL injection detection
- Common cheat location scanning
- Game file integrity verification
- Configuration file analysis
- Logitech G HUB macro detection
6. Report Generation
- Creates timestamped reports
- Lists downloaded EXE files
- Lists executed EXE files
- Auto-opens report in Notepad
3-month history tracking
7. Visual Elements
- ASCII art banner
- Color-coded status messages
- Green: Success/Enabled
- Red: Warning/Disabled
- Cyan: Information
- Yellow: Section headers
- Magenta: Process names
8. Error Handling
- Try-catch blocks for critical operations
- Administrator privilege checks
- File access error handling
- Service status verification
