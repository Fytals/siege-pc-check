# PowerShell Script Template

# Script Parameters
param(
    [string]$Name = "User",    # Added quotes around default value
    [switch]$Verbose
)

# Function to write log messages
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
}

# Function to create colored Y/N prompt
function Get-ColoredChoice {
    param(
        [string]$promptText
    )
    Write-Host $promptText -NoNewline
    Write-Host "(" -NoNewline
    Write-Host "Y" -ForegroundColor Green -NoNewline
    Write-Host "/" -NoNewline
    Write-Host "N" -ForegroundColor Red -NoNewline
    Write-Host ")? " -NoNewline
    return Read-Host
}

# Display ASCII Art Banner and Security Status
$banner = @"
++--------------------------------------------------------++
++--------------------------------------------------------++
|| _____      _        _        ____ _               _    ||
|||  ___|   _| |_ __ _| |___   / ___| |__   ___  ___| | __||
||| |_ | | | | __/ _` | / __| | |   | '_ \ / _ \/ __| |/ /||
|||  _|| |_| | || (_| | \__ \ | |___| | | |  __/ (__|   < ||
|||_|   \__, |\__\__,_|_|___/  \____|_| |_|\___|\___|_|\_\||
||      |___/                                             ||
++--------------------------------------------------------++
++--------------------------------------------------------++
"@

Clear-Host
Write-Host $banner -ForegroundColor Cyan

# Check security features and display status
Write-Host "`nSecurity Status:" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Yellow

$secureBoot = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
$virtualization = (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
$kernelDMA = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard

Write-Host "Checking Security Features" -ForegroundColor Cyan
Write-Host "`nSecurity Status:" -NoNewline
Write-Host " [SecureBoot: " -NoNewline
Write-Host "$(if ($secureBoot) { 'ON' } else { 'OFF' })" -ForegroundColor $(if ($secureBoot) { 'Green' } else { 'Red' }) -NoNewline
Write-Host "] [Virtualization: " -NoNewline
Write-Host "$(if ($virtualization) { 'ON' } else { 'OFF' })" -ForegroundColor $(if ($virtualization) { 'Green' } else { 'Red' }) -NoNewline
Write-Host "] [KernelDMA: " -NoNewline
Write-Host "$(if ($kernelDMA.SecurityServicesConfigured -contains 1) { 'ON' } else { 'OFF' })" -ForegroundColor $(if ($kernelDMA.SecurityServicesConfigured -contains 1) { 'Green' } else { 'Red' }) -NoNewline
Write-Host "]"

Start-Sleep -Seconds 2

# Main script block
try {
    # Display loading message in pink
    Write-Host "`nInitializing System Security Check..." -ForegroundColor Magenta
    Write-Log "Script started"
    
    # Security Features Check
    Write-Host "`nChecking Security Features:" -ForegroundColor Yellow
    
    # Check Secure Boot
    if ($secureBoot) { 
        Write-Host "Secure Boot: Enabled" -ForegroundColor Green
    } else {
        Write-Host "Secure Boot: Disabled" -ForegroundColor Red
    }

    # Check Virtualization
    if ($virtualization) {
        Write-Host "Virtualization: Enabled" -ForegroundColor Green
    } else {
        Write-Host "Virtualization: Disabled" -ForegroundColor Red
    }

    # Check Kernel DMA Protection
    if ($kernelDMA.SecurityServicesConfigured -contains 1) {
        Write-Host "Kernel DMA Protection: Enabled" -ForegroundColor Green
    } else {
        Write-Host "Kernel DMA Protection: Disabled" -ForegroundColor Red
    }

    # OS Installation Date Check
    if ((Get-ColoredChoice "`nCheck OS Installation Date") -eq 'Y') {
        Write-Host "`nChecking OS Installation Date..." -ForegroundColor Cyan
        $OSInstallDate = (Get-CimInstance Win32_OperatingSystem).InstallDate
        Write-Host "`nOS Installation Date:" -ForegroundColor Cyan
        Write-Host $OSInstallDate.ToString('yyyy-MM-dd HH:mm:ss') -ForegroundColor Cyan
    }

    # Recent EXE Executions Check
    if ((Get-ColoredChoice "`nCheck Recent EXE Executions") -eq 'Y') {
        Write-Host "`nChecking Recent EXE Executions..." -ForegroundColor Cyan
        Write-Host "`nRecent EXE Executions:" -ForegroundColor Yellow
        Write-Host "----------------------------------------" -ForegroundColor Yellow
        try {
            Get-WinEvent -FilterHashtable @{
                LogName = 'Security'
                Id = 4688
                StartTime = (Get-Date).AddDays(-1)  # Changed to last 24 hours for better results
            } -MaxEvents 50 -ErrorAction Stop | 
            Where-Object { 
                $_.Properties[5].Value -like "*.exe" -and 
                $_.Properties[5].Value -notlike "*\Windows\*" -and
                $_.Properties[5].Value -notlike "*\SystemApps\*" -and
                $_.Properties[5].Value -notlike "*\System32\*" -and
                $_.Properties[5].Value -notlike "*\WinSxS\*"
            } |
            Select-Object TimeCreated, 
                        @{Name='ProcessName';Expression={Split-Path $_.Properties[5].Value -Leaf}} |
            Sort-Object TimeCreated -Descending |
            Select-Object -First 20 |
            ForEach-Object {
                Write-Host $_.ProcessName -ForegroundColor Magenta -NoNewline
                Write-Host " - " -NoNewline
                Write-Host $_.TimeCreated.ToString('HH:mm:ss') -ForegroundColor Cyan
            }
        } 
        catch {
            Write-Host "Unable to retrieve event logs. Try running as Administrator." -ForegroundColor Red
        }
        Write-Host "----------------------------------------" -ForegroundColor Yellow
    }

    # Export EXE Report
    if ((Get-ColoredChoice "`nExport EXE Report to File") -eq 'Y') {
        Write-Host "`nGenerating EXE Report..." -ForegroundColor Cyan
        
        $reportPath = Join-Path $PWD "exe_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        
        try {
            # Create report header
            @"
============================================
    EXE Activity Report (Last 3 Months)
    Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
============================================

DOWNLOADED EXE FILES:
--------------------------------------------
"@ | Out-File -FilePath $reportPath

            # Get Downloads from Downloads folder
            Get-ChildItem -Path (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path -File -Recurse |
            Where-Object { 
                $_.Extension -eq '.exe' -and 
                $_.LastWriteTime -gt (Get-Date).AddMonths(-3) 
            } |
            ForEach-Object {
                "Downloaded: $($_.LastWriteTime) - $($_.Name)" | Add-Content -Path $reportPath
            }

            # Add executed files section
            @"
EXECUTED EXE FILES:
--------------------------------------------
"@ | Add-Content -Path $reportPath

            # Get executed EXE files from Event Log
            Get-WinEvent -FilterHashtable @{
                LogName = 'Security'
                Id = 4688
                StartTime = (Get-Date).AddMonths(-3)
            } -ErrorAction Stop | 
            Where-Object { 
                $_.Properties[5].Value -like "*.exe" -and 
                $_.Properties[5].Value -notlike "*\Windows\*" -and
                $_.Properties[5].Value -notlike "*\SystemApps\*" -and
                $_.Properties[5].Value -notlike "*\System32\*" -and
                $_.Properties[5].Value -notlike "*\WinSxS\*"
            } |
            Select-Object TimeCreated, @{Name='ProcessName';Expression={Split-Path $_.Properties[5].Value -Leaf}} |
            Sort-Object TimeCreated -Descending |
            ForEach-Object {
                "Executed: $($_.TimeCreated) - $($_.ProcessName)" | Add-Content -Path $reportPath
            }

            Write-Host "Report generated successfully at:" -ForegroundColor Green
            Write-Host $reportPath -ForegroundColor Cyan

            # Automatically open the report in Notepad
            Start-Process notepad.exe -ArgumentList $reportPath

        }
        catch {
            Write-Host "Error generating report: $_" -ForegroundColor Red
        }
    }

    # Browser Downloads Check
    if ((Get-ColoredChoice "`nCheck Recent Browser Downloads") -eq 'Y') {
        Write-Host "`nChecking Browser Downloads..." -ForegroundColor Cyan
        Write-Host "`nChecking Recent Browser Downloads:" -ForegroundColor Yellow
        Write-Host "----------------------------------------" -ForegroundColor Yellow

        # Chrome Downloads
        $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History"
        if (Test-Path $chromePath) {
            Write-Host "`nChrome Downloads:" -ForegroundColor Cyan
            $tempFile = "$env:TEMP\chrome_history"
            Copy-Item -Path $chromePath -Destination $tempFile -Force
            Get-Content $tempFile -Raw | 
            Select-String -Pattern '(https?:\/\/[^:]*?)\.(?:exe|zip|rar|7z|dll)' -AllMatches |
            Select-Object -ExpandProperty Matches | 
            ForEach-Object {
                Write-Host $_.Groups[1].Value -ForegroundColor Magenta
            }
            Remove-Item $tempFile -Force
        }

        # Firefox Downloads
        $firefoxPath = "$env:APPDATA\Mozilla\Firefox\Profiles\*.default*\downloads.sqlite"
        $firefoxProfiles = Get-ChildItem $firefoxPath -ErrorAction SilentlyContinue
        if ($firefoxProfiles) {
            Write-Host "`nFirefox Downloads:" -ForegroundColor Cyan
            foreach ($profile in $firefoxProfiles) {
                Get-Content $profile.FullName -Raw | 
                Select-String -Pattern '(https?:\/\/[^:]*?)\.(?:exe|zip|rar|7z|dll)' -AllMatches |
                Select-Object -ExpandProperty Matches | 
                ForEach-Object {
                    Write-Host $_.Groups[1].Value -ForegroundColor Magenta
                }
            }
        }

        # Edge Downloads
        $edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History"
        if (Test-Path $edgePath) {
            Write-Host "`nEdge Downloads:" -ForegroundColor Cyan
            $tempFile = "$env:TEMP\edge_history"
            Copy-Item -Path $edgePath -Destination $tempFile -Force
            Get-Content $tempFile -Raw | 
            Select-String -Pattern '(https?:\/\/[^:]*?)\.(?:exe|zip|rar|7z|dll)' -AllMatches |
            Select-Object -ExpandProperty Matches | 
            ForEach-Object {
                Write-Host $_.Groups[1].Value -ForegroundColor Magenta
            }
            Remove-Item $tempFile -Force
        }

        # Downloads Folder Check
        $downloadsPath = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
        Write-Host "`nRecent Downloads Folder:" -ForegroundColor Cyan
        Get-ChildItem -Path $downloadsPath -File |
        Where-Object { $_.Extension -match '\.(exe|zip|rar|7z|dll)$' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 10 |
        ForEach-Object {
            Write-Host $_.Name -ForegroundColor Magenta -NoNewline
            Write-Host " - " -NoNewline
            Write-Host $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor Cyan
        }

        Write-Host "----------------------------------------" -ForegroundColor Yellow
    }

    # Running Applications Check
    if ((Get-ColoredChoice "`nCheck Currently Running Applications") -eq 'Y') {
        Write-Host "`nChecking Running Applications..." -ForegroundColor Cyan
        Write-Host "`nCurrently Running Applications:" -ForegroundColor Yellow
        Write-Host "----------------------------------------" -ForegroundColor Yellow
        Get-Process | 
        Where-Object {$_.MainWindowTitle -ne ""} |
        Select-Object @{
            Name='Application';
            Expression={$_.Name}
        },
        @{
            Name='Running Since';
            Expression={
                if ($_.StartTime) {
                    $_.StartTime.ToString("HH:mm:ss")
                } else {
                    "Unknown"
                }
            }
        },
        @{
            Name='CPU Usage';
            Expression={"{0:N1}%" -f $_.CPU}
        } |
        Sort-Object 'Running Since' |
        ForEach-Object {
            Write-Host $_.Application -ForegroundColor Magenta -NoNewline
            Write-Host " - Started: " -NoNewline
            Write-Host $_.('Running Since') -ForegroundColor Cyan -NoNewline
            Write-Host " - CPU: " -NoNewline
            Write-Host $_.('CPU Usage') -ForegroundColor Green
        }
        Write-Host "----------------------------------------" -ForegroundColor Yellow
    }

    # R6S Specific Checks
    if ((Get-ColoredChoice "`nPerform Rainbow Six Siege Specific Checks") -eq 'Y') {
        Write-Host "`nInitiating R6S Specific Checks..." -ForegroundColor Cyan

        # Check for R6S installation in multiple possible locations
        $r6Paths = @(
            "$env:PROGRAMFILES\Ubisoft\Ubisoft Game Launcher\games\Tom Clancy's Rainbow Six Siege",
            "${env:ProgramFiles(x86)}\Ubisoft\Ubisoft Game Launcher\games\Tom Clancy's Rainbow Six Siege",
            "$env:PROGRAMFILES\Steam\steamapps\common\Tom Clancy's Rainbow Six Siege",
            "${env:ProgramFiles(x86)}\Steam\steamapps\common\Tom Clancy's Rainbow Six Siege",
            "D:\Program Files\Ubisoft\Ubisoft Game Launcher\games\Tom Clancy's Rainbow Six Siege",
            "D:\Program Files (x86)\Steam\steamapps\common\Tom Clancy's Rainbow Six Siege"
        )

        $r6Path = $null
        foreach ($path in $r6Paths) {
            if (Test-Path $path) {
                $r6Path = $path
                Write-Host "Rainbow Six Siege installation found at:" -ForegroundColor Green
                Write-Host $r6Path -ForegroundColor Cyan
                break
            }
        }

        if (-not $r6Path) {
            Write-Host "`nRainbow Six Siege installation not found in common locations." -ForegroundColor Red
            Write-Host "Please enter the custom installation path or press Enter to exit:" -ForegroundColor Yellow
            $customPath = Read-Host
            
            if ($customPath -and (Test-Path $customPath)) {
                $r6Path = $customPath
                Write-Host "Installation found at custom path:" -ForegroundColor Green
                Write-Host $r6Path -ForegroundColor Cyan
            } else {
                Write-Host "No valid installation path provided. Exiting R6S checks." -ForegroundColor Red
                return
            }
        }

        # Check Battle Eye Service
        if ((Get-ColoredChoice "`nCheck BattlEye Anti-Cheat Status") -eq 'Y') {
            Write-Host "`nChecking BattlEye Status..." -ForegroundColor Cyan
            $battleEye = Get-Service -Name "BEService" -ErrorAction SilentlyContinue
            Write-Host "BattlEye Anti-Cheat Status: " -NoNewline
            if ($battleEye) {
                Write-Host $battleEye.Status -ForegroundColor $(if ($battleEye.Status -eq 'Running') { 'Green' } else { 'Red' })
            } else {
                Write-Host "Not Installed" -ForegroundColor Red
            }
        }

        # Check for suspicious DLL injections
        if ((Get-ColoredChoice "`nCheck for suspicious DLL injections") -eq 'Y') {
            Write-Host "`nScanning for Suspicious DLLs..." -ForegroundColor Cyan
            Write-Host "`nChecking for suspicious DLLs:" -ForegroundColor Yellow
            $r6Process = Get-Process -Name "RainbowSix" -ErrorAction SilentlyContinue
            if ($r6Process) {
                $r6Process.Modules | Where-Object { 
                    $_.FileName -notlike "*\Windows\*" -and 
                    $_.FileName -notlike "*\Steam\*" -and
                    $_.FileName -notlike "*\Ubisoft\*"
                } | ForEach-Object {
                    Write-Host "WARNING: Non-standard DLL loaded: " -ForegroundColor Red -NoNewline
                    Write-Host $_.FileName -ForegroundColor Red
                }
            }
        }

        # Check common cheat locations
        if ((Get-ColoredChoice "`nCheck common cheat locations") -eq 'Y') {
            Write-Host "`nScanning Common Cheat Locations..." -ForegroundColor Cyan
            Write-Host "`nChecking common cheat locations:" -ForegroundColor Yellow
            $suspiciousLocations = @(
                "$env:TEMP\*.dll",
                "$env:APPDATA\*.dll",
                "$env:LOCALAPPDATA\Temp\*.dll",
                "C:\Users\Public\*.dll"
            )

            foreach ($location in $suspiciousLocations) {
                Get-ChildItem -Path $location -ErrorAction SilentlyContinue | ForEach-Object {
                    Write-Host "WARNING: Suspicious file found: " -ForegroundColor Red -NoNewline
                    Write-Host $_.FullName -ForegroundColor Red
                }
            }
        }

        # Check game integrity
        if ((Get-ColoredChoice "`nCheck game file integrity") -eq 'Y') {
            Write-Host "`nVerifying Game File Integrity..." -ForegroundColor Cyan
            Write-Host "`nChecking game file integrity:" -ForegroundColor Yellow
            $gameFiles = @(
                "RainbowSix.exe",
                "RainbowSix_BE.exe",
                "BEService.exe"
            )
            foreach ($file in $gameFiles) {
                $filePath = Join-Path $r6Path $file
                if (Test-Path $filePath) {
                    $hash = Get-FileHash $filePath -Algorithm SHA256
                    Write-Host "$file hash: " -NoNewline
                    Write-Host $hash.Hash -ForegroundColor Cyan
                } else {
                    Write-Host "WARNING: Missing game file: $file" -ForegroundColor Red
                }
            }
        }

        # Check game config for modifications
        if ((Get-ColoredChoice "`nCheck game configuration for modifications") -eq 'Y') {
            Write-Host "`nAnalyzing Game Configuration..." -ForegroundColor Cyan
            Write-Host "`nChecking game configuration:" -ForegroundColor Yellow
            $configPath = "$env:USERPROFILE\Documents\My Games\Rainbow Six - Siege"
            if (Test-Path $configPath) {
                Get-ChildItem -Path $configPath -Recurse -Include "*.ini" | ForEach-Object {
                    $content = Get-Content $_.FullName -Raw
                    if ($content -match "(AimAssist|RecoilReduction|NoSpread|RapidFire)=") {
                        Write-Host "WARNING: Suspicious game settings in: " -ForegroundColor Red -NoNewline
                        Write-Host $_.Name -ForegroundColor Red
                    }
                }
            }
        }

        # Check for Logitech G HUB macros
        if ((Get-ColoredChoice "`nCheck Logitech G HUB for macros") -eq 'Y') {
            Write-Host "`nScanning Logitech G HUB..." -ForegroundColor Cyan
            
            $ghubPaths = @(
                "$env:LOCALAPPDATA\LGHUB\settings.db",
                "$env:PROGRAMDATA\LGHUB\settings.db"
            )

            $macroFound = $false
            foreach ($path in $ghubPaths) {
                if (Test-Path $path) {
                    Write-Host "Analyzing G HUB settings at: $path" -ForegroundColor Yellow
                    try {
                        $content = Get-Content $path -Raw -ErrorAction SilentlyContinue
                        
                        # Suspicious macro patterns
                        $macroPatterns = @(
                            'mouseDown',           # Mouse click automation
                            'mouseUp',             # Mouse release automation
                            'keyDown',             # Key press automation
                            'keyUp',               # Key release automation
                            'delay',               # Timing delays
                            'repeat',              # Repeat actions
                            'rainbow.*six',        # Game specific macros
                            'r6.*siege',           # Game specific macros
                            'recoil',              # Recoil control
                            'rapid.*fire',         # Rapid fire macros
                            'auto.*fire'           # Auto fire macros
                        )

                        foreach ($pattern in $macroPatterns) {
                            if ($content -match $pattern) {
                                $macroFound = $true
                                Write-Host "WARNING: Potential macro detected - Pattern: '$pattern'" -ForegroundColor Red
                                
                                # Get surrounding context
                                $matches = [regex]::Matches($content, ".{0,50}$pattern.{0,50}")
                                foreach ($match in $matches) {
                                    Write-Host "Context: ...${match}..." -ForegroundColor Yellow
                                }
                            }
                        }

                        # Check file modification time
                        $fileInfo = Get-Item $path
                        Write-Host "`nG HUB settings last modified: " -NoNewline
                        Write-Host $fileInfo.LastWriteTime -ForegroundColor Cyan
                        
                        if (-not $macroFound) {
                            Write-Host "No suspicious macros detected" -ForegroundColor Green
                        }

                    } catch {
                        Write-Host "Error accessing G HUB settings: $_" -ForegroundColor Red
                    }
                }
            }
            
            # Check for G HUB process
            $ghubProcess = Get-Process "lghub" -ErrorAction SilentlyContinue
            if ($ghubProcess) {
                Write-Host "`nG HUB Process Information:" -ForegroundColor Yellow
                Write-Host "Status: Running" -ForegroundColor Green
                Write-Host "CPU Usage: $([math]::Round($ghubProcess.CPU, 2))%" -ForegroundColor Cyan
                Write-Host "Memory Usage: $([math]::Round($ghubProcess.WorkingSet64 / 1MB, 2)) MB" -ForegroundColor Cyan
                Write-Host "Start Time: $($ghubProcess.StartTime)" -ForegroundColor Cyan
            } else {
                Write-Host "`nG HUB is not currently running" -ForegroundColor Yellow
            }
        }

        Write-Host "----------------------------------------" -ForegroundColor Yellow
    }

    Write-Log "Script completed successfully"
}
catch {
    Write-Log "Error occurred: $($_.Exception.Message)"
    exit 1
}
