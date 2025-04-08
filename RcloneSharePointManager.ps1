#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Sites, Microsoft.Graph.Files

# ANSI escape codes for colors and formatting
$script:ANSI = @{
    Reset = "`e[0m"
    Bold = "`e[1m"
    Underline = "`e[4m"
    Green = "`e[32m"
    Yellow = "`e[33m"
    Blue = "`e[34m"
    Magenta = "`e[35m"
    Cyan = "`e[36m"
    White = "`e[37m"
    BgBlue = "`e[44m"
}

# Global variables
$script:CurrentUser = $null
$script:SelectedSite = $null
$script:MountPoints = @{}

# Function to write logs
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Level = 'Information'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    
    # Write to console with color
    switch ($Level) {
        'Information' { Write-Host $logEntry -ForegroundColor Green }
        'Warning' { Write-Host $logEntry -ForegroundColor Yellow }
        'Error' { Write-Host $logEntry -ForegroundColor Red }
    }
}

# Function to test Rclone installation
function Test-RcloneInstallation {
    Write-Log "Checking Rclone installation..."
    
    try {
        $rclone = Get-Command rclone -ErrorAction Stop
        $version = & rclone version
        Write-Log "Rclone found: $version"
        return $true
    }
    catch {
        Write-Log "Rclone not found. Please install Rclone from https://rclone.org/downloads/" -Level Warning
        Start-Process "https://rclone.org/downloads/"
        return $false
    }
}

# Function to register Azure AD application
function Register-AzureApplication {
    param(
        [Parameter(Mandatory)]
        [string]$ApplicationName
    )
    
    try {
        Write-Log "Connecting to Microsoft Graph..."
        Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All" -ErrorAction Stop
        
        # Verify connection
        $context = Get-MgContext
        if (-not $context) {
            throw "Failed to connect to Microsoft Graph. Please ensure you have the correct permissions."
        }
        $script:CurrentUser = $context.Account
        Write-Log "Connected as: $($context.Account)" -Level Information
        
        Write-Log "Creating Azure AD application: $ApplicationName"
        
        # Required permissions for SharePoint
        $requiredResourceAccess = @{
            ResourceAppId = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
            ResourceAccess = @(
                @{
                    Id = "ef54d2bf-783f-4e0f-bca1-3210c0444d99" # Sites.ReadWrite.All
                    Type = "Role"
                },
                @{
                    Id = "41ec2507-e14b-4fee-b1e0-3a1537ef3e1f" # Files.ReadWrite.All
                    Type = "Role"
                }
            )
        }

        # Create the application
        $app = New-MgApplication -DisplayName $ApplicationName `
            -SignInAudience "AzureADMyOrg" `
            -RequiredResourceAccess @{
                ResourceAppId = $requiredResourceAccess.ResourceAppId
                ResourceAccess = $requiredResourceAccess.ResourceAccess
            } `
            -Web @{ 
                RedirectUris = @("http://localhost")
                ImplicitGrantSettings = @{
                    EnableIdTokenIssuance = $true
                    EnableAccessTokenIssuance = $true
                }
            }
        
        # Create client secret
        $endDate = (Get-Date).AddYears(1)
        $pwd = Add-MgApplicationPassword -ApplicationId $app.Id `
            -PasswordCredential @{
                DisplayName = "Auto-generated secret"
                EndDateTime = $endDate
            }
        
        # Output the details
        Write-Log "Application registered successfully!"
        Write-Log "Application (Client) ID: $($app.AppId)"
        Write-Log "Client Secret: $($pwd.SecretText)"
        Write-Log "Secret Expiration: $($endDate)"
        
        # Create Rclone config
        $rcloneConfig = @"
[SharePoint]
type = onedrive
client_id = $($app.AppId)
client_secret = $($pwd.SecretText)
region = global
drive_type = site
"@
        
        # Save Rclone config
        $configPath = "$HOME/.config/rclone/rclone.conf"
        if (-not (Test-Path (Split-Path $configPath))) {
            New-Item -ItemType Directory -Path (Split-Path $configPath) -Force | Out-Null
        }
        Add-Content -Path $configPath -Value $rcloneConfig
        
        Write-Log "Rclone configuration has been updated"
        return $app
    }
    catch {
        Write-Log "Error registering application: $_" -Level Error
        throw $_
    }
}

# Function to get SharePoint sites
function Get-SharePointSites {
    try {
        Write-Log "Connecting to Microsoft Graph..." -Level Information
        
        # Connect with the required permissions
        Connect-MgGraph -Scopes @(
            "Sites.Read.All",
            "Sites.ReadWrite.All",
            "User.Read.All",
            "Group.Read.All",
            "Group.ReadWrite.All"
        ) -ErrorAction Stop
        
        # Get current user context
        $context = Get-MgContext
        $script:CurrentUser = $context.Account
        Write-Log "Connected as: $($context.Account)" -Level Information
        
        Write-Log "Retrieving SharePoint sites..." -Level Information
        
        # Initialize sites array
        $allSites = @()
        
        # Method 1: Get sites by searching
        Write-Log "Searching for SharePoint sites..." -Level Information
        try {
            $searchSites = Get-MgSite -Search "*" -All -ErrorAction Stop
            if ($searchSites) {
                $allSites += $searchSites
                Write-Log "Found $(($searchSites | Measure-Object).Count) sites via search" -Level Information
            }
        }
        catch {
            Write-Log "Search method failed: $_" -Level Warning
        }

        # Method 2: Get sites through groups
        Write-Log "Getting sites through Microsoft 365 Groups..." -Level Information
        try {
            $groups = Get-MgGroup -All -Filter "groupTypes/any(c:c eq 'Unified')" -ErrorAction Stop
            foreach ($group in $groups) {
                try {
                    $site = Get-MgGroup -GroupId $group.Id -Property "sites" -ErrorAction Stop
                    if ($site.Sites) {
                        $allSites += $site.Sites
                        Write-Log "Found site for group: $($group.DisplayName)" -Level Information
                    }
                }
                catch {
                    Write-Log "Failed to get site for group $($group.DisplayName): $_" -Level Warning
                }
            }
        }
        catch {
            Write-Log "Group method failed: $_" -Level Warning
        }

        # Method 3: Get followed sites
        Write-Log "Getting user's followed sites..." -Level Information
        try {
            $userId = $context.Account
            $followedSites = Get-MgUserFollowedSite -UserId $userId -ErrorAction Stop
            if ($followedSites) {
                $allSites += $followedSites
                Write-Log "Found $(($followedSites | Measure-Object).Count) followed sites" -Level Information
            }
        }
        catch {
            Write-Log "Followed sites method failed: $_" -Level Warning
        }

        # Remove duplicates and sort
        $uniqueSites = $allSites | Sort-Object -Property WebUrl -Unique
        return $uniqueSites
    }
    catch {
        Write-Log "Error retrieving SharePoint sites: $_" -Level Error
        throw $_
    }
}

# Function to mount SharePoint site
function Mount-SharePointSite {
    param(
        [Parameter(Mandatory)]
        [string]$SiteUrl,
        [Parameter(Mandatory)]
        [string]$MountPoint
    )
    
    try {
        # Create mount point if it doesn't exist
        if (-not (Test-Path $MountPoint)) {
            New-Item -ItemType Directory -Path $MountPoint -Force | Out-Null
        }
        
        # Mount the site using rclone
        Write-Log "Mounting SharePoint site to $MountPoint..."
        $mountCmd = "rclone mount SharePoint:$SiteUrl $MountPoint --vfs-cache-mode full --daemon"
        Invoke-Expression $mountCmd
        
        # Store mount point information
        $script:MountPoints[$SiteUrl] = $MountPoint
        Write-Log "SharePoint site mounted successfully at $MountPoint" -Level Information
    }
    catch {
        Write-Log "Error mounting SharePoint site: $_" -Level Error
        throw $_
    }
}

# Function to show sites and select one
function Select-SharePointSite {
    param(
        [Parameter(Mandatory)]
        [array]$Sites
    )
    
    Clear-Host
    Write-Host "$($ANSI.BgBlue)$($ANSI.White)SharePoint Sites$($ANSI.Reset)`n"
    
    for ($i = 0; $i -lt $Sites.Count; $i++) {
        Write-Host "$($ANSI.Cyan)[$($i + 1)]$($ANSI.Reset) $($Sites[$i].DisplayName)"
        Write-Host "    URL: $($Sites[$i].WebUrl)"
    }
    
    Write-Host "`nEnter the number of the site to select (or 0 to cancel):"
    $selection = Read-Host
    
    if ($selection -match '^\d+$' -and [int]$selection -gt 0 -and [int]$selection -le $Sites.Count) {
        return $Sites[[int]$selection - 1]
    }
    return $null
}

# Function to show menu and get user choice
function Show-Menu {
    Clear-Host
    Write-Host "$($ANSI.BgBlue)$($ANSI.White) RcloneSharePoint Manager $($ANSI.Reset)"
    
    # Always show user status
    if ($script:CurrentUser) {
        Write-Host "$($ANSI.Green)Logged in as:$($ANSI.Reset) $script:CurrentUser`n"
    }
    else {
        Write-Host "$($ANSI.Yellow)Not logged in$($ANSI.Reset)`n"
        
        # Try to connect if not logged in
        try {
            Connect-MgGraph -Scopes @(
                "Sites.Read.All",
                "Sites.ReadWrite.All",
                "User.Read.All",
                "Group.Read.All",
                "Group.ReadWrite.All"
            ) -ErrorAction Stop
            $context = Get-MgContext
            if ($context) {
                $script:CurrentUser = $context.Account
                Write-Host "$($ANSI.Green)Successfully connected as:$($ANSI.Reset) $script:CurrentUser`n"
            }
        }
        catch {
            Write-Host "$($ANSI.Yellow)Failed to connect automatically. Please use options to connect manually.$($ANSI.Reset)`n"
        }
    }
    
    Write-Host "$($ANSI.Yellow)Current Status:$($ANSI.Reset)"
    Write-Host "Selected Site: $(if ($script:SelectedSite) { $script:SelectedSite.DisplayName } else { 'None' })"
    Write-Host "Mounted Sites: $(if ($script:MountPoints.Count -gt 0) { $script:MountPoints.Keys -join ', ' } else { 'None' })`n"
    
    Write-Host "$($ANSI.Cyan)1$($ANSI.Reset): Check Rclone Installation"
    Write-Host "$($ANSI.Cyan)2$($ANSI.Reset): Register Azure Application"
    Write-Host "$($ANSI.Cyan)3$($ANSI.Reset): List SharePoint Sites"
    Write-Host "$($ANSI.Cyan)4$($ANSI.Reset): Select SharePoint Site"
    Write-Host "$($ANSI.Cyan)5$($ANSI.Reset): Mount Selected Site"
    Write-Host "$($ANSI.Cyan)Q$($ANSI.Reset): Quit"
    Write-Host
    
    $choice = Read-Host "Please enter your choice"
    return $choice
}

# Initialize connection at startup
try {
    Write-Host "Checking Microsoft Graph connection..."
    $context = Get-MgContext
    if ($context) {
        $script:CurrentUser = $context.Account
        Write-Host "$($ANSI.Green)Already connected as:$($ANSI.Reset) $script:CurrentUser"
    }
    else {
        Write-Host "Not connected. Attempting to connect to Microsoft Graph..."
        Connect-MgGraph -Scopes @(
            "Sites.Read.All",
            "Sites.ReadWrite.All",
            "User.Read.All",
            "Group.Read.All",
            "Group.ReadWrite.All"
        ) -ErrorAction Stop
        $context = Get-MgContext
        $script:CurrentUser = $context.Account
        Write-Host "$($ANSI.Green)Successfully connected as:$($ANSI.Reset) $script:CurrentUser"
    }
    Start-Sleep -Seconds 2
}
catch {
    Write-Host "$($ANSI.Yellow)Not connected to Microsoft Graph. Please use the menu options to connect.$($ANSI.Reset)"
    Start-Sleep -Seconds 2
}

# Main program loop
do {
    $choice = Show-Menu
    
    switch ($choice) {
        "1" {
            Test-RcloneInstallation
            Write-Host "`nPress Enter to continue..."
            Read-Host
        }
        "2" {
            $appName = Read-Host "Enter the application name (default: RcloneSharePointApp)"
            if ([string]::IsNullOrWhiteSpace($appName)) {
                $appName = "RcloneSharePointApp"
            }
            Register-AzureApplication -ApplicationName $appName
            Write-Host "`nPress Enter to continue..."
            Read-Host
        }
        "3" {
            $sites = Get-SharePointSites
            $sites | Format-Table -Property DisplayName, WebUrl, Id -AutoSize -Wrap
            Write-Host "`nPress Enter to continue..."
            Read-Host
        }
        "4" {
            $sites = Get-SharePointSites
            $script:SelectedSite = Select-SharePointSite -Sites $sites
            if ($script:SelectedSite) {
                Write-Host "`nSelected site: $($script:SelectedSite.DisplayName)"
            }
            Write-Host "`nPress Enter to continue..."
            Read-Host
        }
        "5" {
            if (-not $script:SelectedSite) {
                Write-Host "`n$($ANSI.Yellow)Please select a SharePoint site first (Option 4)$($ANSI.Reset)"
            }
            else {
                $mountPoint = Read-Host "Enter the mount point path"
                if ([string]::IsNullOrWhiteSpace($mountPoint)) {
                    $mountPoint = Join-Path $HOME "SharePoint/$($script:SelectedSite.DisplayName)"
                }
                Mount-SharePointSite -SiteUrl $script:SelectedSite.WebUrl -MountPoint $mountPoint
            }
            Write-Host "`nPress Enter to continue..."
            Read-Host
        }
        "Q" { 
            Write-Host "Exiting..."
            return
        }
        "q" { 
            Write-Host "Exiting..."
            return
        }
        default {
            Write-Host "$($ANSI.Yellow)Invalid choice. Please try again.$($ANSI.Reset)"
            Start-Sleep -Seconds 2
        }
    }
} while ($true)