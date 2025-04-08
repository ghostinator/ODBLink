# RcloneSharePoint Manager

A PowerShell script for managing SharePoint sites using Rclone. This tool provides an interactive terminal interface for connecting to SharePoint, managing sites, and mounting them as local drives.

## Prerequisites

- PowerShell 7.0 or later
- Rclone installed and available in PATH
- Microsoft Graph PowerShell SDK modules:
  - Microsoft.Graph.Authentication
  - Microsoft.Graph.Sites
  - Microsoft.Graph.Files

## Installation

1. Install the required PowerShell modules:
```powershell
Install-Module Microsoft.Graph.Authentication
Install-Module Microsoft.Graph.Sites
Install-Module Microsoft.Graph.Files
```

2. Install Rclone from [https://rclone.org/downloads/](https://rclone.org/downloads/)

3. Download the `RcloneSharePointManager.ps1` script to your preferred location

## Features

- Automatic Microsoft Graph authentication
- SharePoint site discovery and management
- Azure Application registration for Rclone
- Local mounting of SharePoint sites
- Interactive terminal interface with color coding
- Persistent session state
- Comprehensive logging

## Usage

1. Run the script:
```powershell
./RcloneSharePointManager.ps1
```

2. The script will automatically attempt to connect to Microsoft Graph
3. Use the interactive menu to:
   - Check Rclone installation
   - Register Azure applications
   - List available SharePoint sites
   - Select sites for mounting
   - Mount sites to local directories

## Menu Options

1. **Check Rclone Installation**
   - Verifies Rclone is properly installed
   - Displays version information

2. **Register Azure Application**
   - Creates a new Azure AD application
   - Configures necessary permissions
   - Generates and saves Rclone configuration

3. **List SharePoint Sites**
   - Displays all accessible SharePoint sites
   - Shows site names, URLs, and IDs

4. **Select SharePoint Site**
   - Interactive site selection
   - Required before mounting

5. **Mount Selected Site**
   - Mounts selected SharePoint site locally
   - Creates mount point if needed
   - Uses Rclone daemon mode

## Status Information

The interface shows:
- Currently logged-in user
- Selected SharePoint site
- Currently mounted sites
- Operation status and logs

## Permissions

The script requires the following Microsoft Graph permissions:
- Sites.Read.All
- Sites.ReadWrite.All
- User.Read.All
- Group.Read.All
- Group.ReadWrite.All
- Application.ReadWrite.All
- Directory.ReadWrite.All

## Notes

- The script maintains state during execution
- Mount points are tracked between operations
- Color coding indicates status and warnings
- Automatic error handling and recovery
- Cross-platform compatible (Windows, macOS, Linux)

## Error Handling

- Automatic connection retry
- Clear error messages
- Graceful failure recovery
- Detailed logging

## Support

For issues, questions, or contributions, please:
1. Check the prerequisites are installed
2. Verify Rclone is properly configured
3. Ensure you have the necessary permissions
4. Check the logs for detailed error information