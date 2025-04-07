import sys
import os
import subprocess
from pathlib import Path
from PyQt5.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout,
                           QHBoxLayout, QLabel, QLineEdit, QRadioButton,
                           QPushButton, QComboBox, QTextEdit, QFileDialog,
                           QMessageBox, QButtonGroup, QFrame)
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QFont

class RcloneGUI(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("OneDrive Business Rclone Setup")
        self.setMinimumSize(700, 600)

        # Determine platform
        self.is_windows = sys.platform.startswith('win')

        # Configuration variables
        self.config_path = str(Path.home() / '.config' / 'rclone' / 'rclone.conf')

        # Create central widget and main layout
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        self.main_layout = QVBoxLayout(central_widget)

        self.create_gui()

    def create_gui(self):
        # Title
        title_label = QLabel("OneDrive Business Rclone Configuration")
        title_label.setFont(QFont('Arial', 12, QFont.Bold))
        self.main_layout.addWidget(title_label, alignment=Qt.AlignCenter)

        # Basic Configuration Section
        self.remote_name = QLineEdit()
        self.sharepoint_url = QLineEdit()

        basic_config = QFrame()
        basic_layout = QVBoxLayout(basic_config)

        remote_layout = QHBoxLayout()
        remote_layout.addWidget(QLabel("Remote Name:"))
        remote_layout.addWidget(self.remote_name)

        url_layout = QHBoxLayout()
        url_layout.addWidget(QLabel("SharePoint URL:"))
        url_layout.addWidget(self.sharepoint_url)

        basic_layout.addLayout(remote_layout)
        basic_layout.addLayout(url_layout)

        self.main_layout.addWidget(basic_config)

        # Mount Configuration Section
        mount_label = QLabel("Mount Configuration")
        mount_label.setFont(QFont('Arial', 10, QFont.Bold))
        self.main_layout.addWidget(mount_label)

        mount_frame = QFrame()
        mount_layout = QVBoxLayout(mount_frame)

        # Mount Type Selection (Windows Only)
        if self.is_windows:
            self.mount_type_group = QButtonGroup()
            folder_radio = QRadioButton("Folder")
            drive_radio = QRadioButton("Drive Letter")
            folder_radio.setChecked(True)

            self.mount_type_group.addButton(folder_radio)
            self.mount_type_group.addButton(drive_radio)

            radio_layout = QHBoxLayout()
            radio_layout.addWidget(QLabel("Mount Type:"))
            radio_layout.addWidget(folder_radio)
            radio_layout.addWidget(drive_radio)
            radio_layout.addStretch()
            mount_layout.addLayout(radio_layout)

            # Drive Letter Input
            self.drive_letter = QLineEdit("O:")
            self.drive_letter.setMaximumWidth(50)
            drive_layout = QHBoxLayout()
            drive_layout.addWidget(QLabel("Drive Letter:"))
            drive_layout.addWidget(self.drive_letter)
            drive_layout.addStretch()
            mount_layout.addLayout(drive_layout)

            folder_radio.toggled.connect(self.update_mount_options)

        # Folder Path Selection
        self.mount_path = QLineEdit()
        browse_button = QPushButton("Browse")
        browse_button.clicked.connect(self.browse_mount_path)

        path_layout = QHBoxLayout()
        path_layout.addWidget(QLabel("Mount Path:"))
        path_layout.addWidget(self.mount_path)
        path_layout.addWidget(browse_button)
        mount_layout.addLayout(path_layout)

        # Cache Configuration
        self.cache_mode = QComboBox()
        self.cache_mode.addItems(['off', 'minimal', 'writes', 'full'])
        self.cache_mode.setCurrentText('writes')

        cache_layout = QHBoxLayout()
        cache_layout.addWidget(QLabel("Cache Mode:"))
        cache_layout.addWidget(self.cache_mode)
        cache_layout.addStretch()
        mount_layout.addLayout(cache_layout)

        self.main_layout.addWidget(mount_frame)

        # Action Buttons
        check_button = QPushButton("Check Rclone Installation")
        check_button.clicked.connect(self.check_rclone)
        self.main_layout.addWidget(check_button)

        config_button = QPushButton("Configure Remote")
        config_button.clicked.connect(self.configure_remote)
        self.main_layout.addWidget(config_button)

        mount_button = QPushButton("Mount Remote")
        mount_button.clicked.connect(self.mount_remote)
        self.main_layout.addWidget(mount_button)

        # Status Area
        self.status_text = QTextEdit()
        self.status_text.setReadOnly(True)
        self.status_text.setMinimumHeight(100)
        self.main_layout.addWidget(self.status_text)

    def update_mount_options(self):
        """Update mount options visibility based on selected mount type"""
        is_folder = self.mount_type_group.checkedButton().text() == "Folder"
        self.mount_path.setEnabled(is_folder)
        self.drive_letter.setEnabled(not is_folder)

    def browse_mount_path(self):
        """Open folder browser dialog"""
        path = QFileDialog.getExistingDirectory(self, "Select Mount Directory")
        if path:
            self.mount_path.setText(path)

    def check_rclone(self):
        """Verify rclone installation and version"""
        try:
            result = subprocess.run(['rclone', 'version'],
                                capture_output=True, text=True)
            if result.returncode == 0:
                self.log_status("✓ Rclone is installed\n" + result.stdout.split('\n')[0])
            else:
                self.log_status("❌ Error checking rclone: " + result.stderr)
        except FileNotFoundError:
            self.log_status("❌ Rclone not found. Please install rclone first.")
            QMessageBox.critical(self, "Error", "Rclone not found. Please install rclone first.")

    def configure_remote(self):
        """Configure OneDrive Business remote"""
        if not self.validate_inputs():
            return

        config_cmd = [
            'rclone', 'config', 'create',
            self.remote_name.text(),
            'onedrive',
            f'url={self.sharepoint_url.text()}',
            'region=global',
            'drive_type=business'
        ]

        try:
            result = subprocess.run(config_cmd, capture_output=True, text=True)

            if result.returncode == 0:
                self.log_status("✓ Remote configured successfully!")
                QMessageBox.information(self, "Success", "Remote configured successfully!")
            else:
                self.log_status(f"❌ Configuration failed:\n{result.stderr}")
                QMessageBox.critical(self, "Error", "Failed to configure remote")

        except Exception as e:
            self.log_status(f"❌ Error: {str(e)}")
            QMessageBox.critical(self, "Error", f"An error occurred: {str(e)}")

    def mount_remote(self):
        """Mount the configured remote"""
        if not self.validate_mount_inputs():
            return

        # Determine mount point
        if self.is_windows and not self.mount_type_group.checkedButton().text() == "Folder":
            mount_point = self.drive_letter.text()
        else:
            mount_point = self.mount_path.text()

        mount_cmd = [
            'rclone', 'mount',
            f'{self.remote_name.text()}:',
            mount_point,
            f'--vfs-cache-mode', self.cache_mode.currentText(),
            '--daemon'
        ]

        try:
            result = subprocess.run(mount_cmd, capture_output=True, text=True)

            if result.returncode == 0:
                self.log_status("✓ Remote mounted successfully!")
                QMessageBox.information(self, "Success", "Remote mounted successfully!")
            else:
                self.log_status(f"❌ Mount failed:\n{result.stderr}")
                QMessageBox.critical(self, "Error", "Failed to mount remote")

        except Exception as e:
            self.log_status(f"❌ Mount error: {str(e)}")
            QMessageBox.critical(self, "Error", f"An error occurred while mounting: {str(e)}")

    def validate_inputs(self):
        """Validate user inputs"""
        if not self.remote_name.text().strip():
            QMessageBox.critical(self, "Error", "Please enter a remote name")
            return False

        if not self.sharepoint_url.text().strip():
            QMessageBox.critical(self, "Error", "Please enter SharePoint URL")
            return False

        return True

    def validate_mount_inputs(self):
        """Validate mount configuration inputs"""
        if self.is_windows and not self.mount_type_group.checkedButton().text() == "Folder":
            if not self.drive_letter.text().strip():
                QMessageBox.critical(self, "Error", "Please specify a drive letter")
                return False
            if not self.drive_letter.text().endswith(':'):
                QMessageBox.critical(self, "Error", "Drive letter must end with ':'")
                return False
        else:
            if not self.mount_path.text().strip():
                QMessageBox.critical(self, "Error", "Please specify a mount path")
                return False
            if not os.path.exists(self.mount_path.text()):
                try:
                    os.makedirs(self.mount_path.text())
                except Exception as e:
                    QMessageBox.critical(self, "Error", f"Cannot create mount path: {str(e)}")
                    return False
        return True

    def log_status(self, message):
        """Update status text area"""
        self.status_text.setText(message)

def main():
    app = QApplication(sys.argv)
    window = RcloneGUI()
    window.show()
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()