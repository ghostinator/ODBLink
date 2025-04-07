# ODBLink

A modern, cross-platform GUI application built with PyQt5 to simplify the configuration and mounting of OneDrive for Business/SharePoint using rclone.

## Features

- Clean, modern interface built with PyQt5
- Platform-aware functionality:
  - Windows: Support for both drive letter and folder mounting
  - macOS/Linux: Folder mounting support
- Automated rclone configuration for OneDrive Business
- Real-time status feedback
- Configurable VFS cache modes
- Error handling and input validation

## Prerequisites

- Python 3.x
- PyQt5
- Rclone (must be installed and available in system PATH)

## Installation

1. Clone this repository:
   ```bash
   git clone [repository-url]
   cd [repository-name]
Copy
Insert
Apply
Install PyQt5:

pip install PyQt5
Copy
Insert
Apply
Install Rclone:

Windows: Download from Rclone.org
macOS: brew install rclone
Linux: sudo apt install rclone (or your distribution's package manager)
Usage
Start the application:

python main.py
Copy
Insert
Apply
Basic Configuration:

Enter a name for your remote
Input your SharePoint URL
Click "Check Rclone Installation" to verify rclone setup
Mount Configuration:

Windows users:
Choose between folder or drive letter mounting
For drive letter: Enter desired letter (e.g., "O:")
For folder: Select or enter mount path
macOS/Linux users:
Select desired mount folder location
Advanced Options:

Select VFS cache mode:
off: No caching
minimal: Minimal caching
writes: Cache writes (recommended)
full: Full file caching
Operations:

"Configure Remote": Sets up the rclone remote
"Mount Remote": Mounts the configured remote
Configuration Options
Remote Settings
Remote Name: Unique identifier for your rclone configuration
SharePoint URL: Your OneDrive for Business SharePoint URL
Mount Settings
Mount Type (Windows only):
Folder: Mount to a directory
Drive Letter: Mount as a Windows drive
Mount Path: Directory where OneDrive will be mounted
Cache Mode: Controls how rclone caches files locally
Troubleshooting
Verify Rclone Installation:

Use the "Check Rclone Installation" button
Ensure rclone is in your system PATH
Common Issues:

Mount failures: Check permissions and existing mounts
Configuration errors: Verify SharePoint URL format
Path issues: Ensure mount locations are accessible
Status Feedback:

Check the status area for detailed error messages
Look for ✓ (success) or ❌ (error) indicators
Notes
Windows users may need administrator privileges for drive letter mounting
For persistent mounts, consider setting up a system service
The application creates necessary directories if they don't exist
Configuration is stored in the standard rclone config location
Contributing
Contributions are welcome! Please feel free to submit issues or pull requests.

License
[Your License Here]


This README provides:
- Clear installation instructions
- Detailed usage guidelines
- Platform-specific considerations
- Troubleshooting help
- Configuration options
- All based on the actual implementation in the code

The documentation is structured to help both new and experienced users understand and use the application effectively.
