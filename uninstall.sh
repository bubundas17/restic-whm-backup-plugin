#!/bin/bash
# Uninstallation script for Restic Backup WHM Plugin

# Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${GREEN}[*]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    print_error "This script must be run as root"
    exit 1
fi

# Define paths
PLUGIN_NAME="restic_backup"
WHM_ADDON_DIR="/usr/local/cpanel/whostmgr/docroot/cgi/addons/${PLUGIN_NAME}_plugin"
CPANEL_PLUGIN_DIR="/usr/local/cpanel/base/frontend/paper_lantern/restic_backup"
CONFIG_DIR="/var/cpanel/restic_backup"
CRON_FILE="/etc/cron.d/restic_backup"
WHM_ACLS_DIR="/usr/local/cpanel/whostmgr/docroot/cgi"

# Ask for confirmation
echo "This will uninstall the Restic Backup WHM Plugin."
echo "WARNING: This will remove all plugin files and configuration."
read -p "Are you sure you want to continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Uninstallation cancelled."
    exit 0
fi

# Ask about config directory
echo "Do you want to keep the configuration directory and backup logs?"
echo "This includes the repository configuration and all backup logs."
read -p "Keep configuration? (y/n): " -n 1 -r
echo
KEEP_CONFIG=0
if [[ $REPLY =~ ^[Yy]$ ]]; then
    KEEP_CONFIG=1
    print_status "Configuration will be preserved."
else
    print_status "Configuration will be removed."
fi

# Remove symlinks
print_status "Removing symlinks..."
rm -f "/usr/local/cpanel/whostmgr/docroot/cgi/restic_backup_admin.cgi"
rm -f "/usr/local/cpanel/base/frontend/paper_lantern/restic_backup.cgi"

# Remove cron job
print_status "Removing cron job..."
rm -f "$CRON_FILE"

# Remove acls file
print_status "Removing ACLs file..."
rm -f "$WHM_ACLS_DIR/acls"

# Unregister the plugin from WHM
print_status "Unregistering plugin from WHM..."
if [ -f "$WHM_ADDON_DIR/AppConfig" ] && [ -f "/usr/local/cpanel/bin/unregister_appconfig" ]; then
    /usr/local/cpanel/bin/unregister_appconfig "$WHM_ADDON_DIR/AppConfig"
else
    print_warning "unregister_appconfig command not found or AppConfig file missing."
    print_warning "Plugin may not be properly unregistered from WHM."
fi

# Remove plugin directories
print_status "Removing plugin files..."
rm -rf "$WHM_ADDON_DIR"
rm -rf "$CPANEL_PLUGIN_DIR"

# Remove configuration directory if not keeping it
if [ "$KEEP_CONFIG" -eq 0 ]; then
    print_status "Removing configuration directory..."
    rm -rf "$CONFIG_DIR"
else
    print_status "Keeping configuration directory at $CONFIG_DIR"
fi

# Rebuild WHM theme
print_status "Rebuilding WHM theme..."
if [ -f "/usr/local/cpanel/bin/build_whm_themes" ]; then
    /usr/local/cpanel/bin/build_whm_themes
else
    print_warning "build_whm_themes command not found. WHM theme may not be properly updated."
    print_warning "You may need to manually rebuild the WHM theme."
fi

print_status "Uninstallation completed successfully!"
if [ "$KEEP_CONFIG" -eq 1 ]; then
    print_status "Configuration directory was preserved at $CONFIG_DIR"
    print_status "You can manually remove it later with: rm -rf $CONFIG_DIR"
fi

exit 0