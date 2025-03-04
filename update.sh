#!/bin/bash
# Update script for Restic Backup WHM Plugin

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
PLUGIN_DIR="$(pwd)"
WHM_ADDON_DIR="/usr/local/cpanel/whostmgr/docroot/cgi/addons/${PLUGIN_NAME}_plugin"
CPANEL_PLUGIN_DIR="/usr/local/cpanel/base/frontend/paper_lantern/restic_backup"
CONFIG_DIR="/var/cpanel/restic_backup"

# Check if the plugin is already installed
if [ ! -d "$WHM_ADDON_DIR" ]; then
    print_error "Plugin is not installed. Please run install.sh first."
    exit 1
fi

# Backup existing configuration
if [ -f "$CONFIG_DIR/config.json" ]; then
    print_status "Backing up existing configuration..."
    cp -f "$CONFIG_DIR/config.json" "$CONFIG_DIR/config.json.bak"
    print_status "Configuration backed up to $CONFIG_DIR/config.json.bak"
fi

# Update plugin files
print_status "Updating plugin files..."

# Update WHM addon files
print_status "Updating WHM addon files..."
cp -f "$PLUGIN_DIR/plugin.conf" "$WHM_ADDON_DIR/"
cp -f "$PLUGIN_DIR/AppConfig" "$WHM_ADDON_DIR/"
cp -f "$PLUGIN_DIR/restic_backup_admin.cgi" "$WHM_ADDON_DIR/"
cp -f "$PLUGIN_DIR/scripts/"* "$WHM_ADDON_DIR/scripts/"
cp -f "$PLUGIN_DIR/templates/"* "$WHM_ADDON_DIR/templates/"
cp -f "$PLUGIN_DIR/ui/icons/"* "$WHM_ADDON_DIR/ui/icons/" 2>/dev/null || mkdir -p "$WHM_ADDON_DIR/ui/icons/"

# Update cPanel plugin files
print_status "Updating cPanel plugin files..."
cp -f "$PLUGIN_DIR/restic_backup_user.cgi" "$CPANEL_PLUGIN_DIR/"

# Set permissions
print_status "Setting file permissions..."
chmod 700 "$WHM_ADDON_DIR/scripts/"*
chmod 755 "$WHM_ADDON_DIR/restic_backup_admin.cgi"
chmod 755 "$CPANEL_PLUGIN_DIR/restic_backup_user.cgi"

# Update symlinks
print_status "Updating symlinks..."
ln -sf "$WHM_ADDON_DIR/restic_backup_admin.cgi" "/usr/local/cpanel/whostmgr/docroot/cgi/restic_backup_admin.cgi"
ln -sf "$CPANEL_PLUGIN_DIR/restic_backup_user.cgi" "/usr/local/cpanel/base/frontend/paper_lantern/restic_backup.cgi"

# Update cron job
print_status "Updating cron job..."
CRON_FILE="/etc/cron.d/restic_backup"
cat > "$CRON_FILE" << EOF
# Restic Backup cron job
0 2 * * * root $WHM_ADDON_DIR/scripts/periodic_backup.sh > /dev/null 2>&1
EOF
chmod 644 "$CRON_FILE"

# Re-register the plugin with WHM
print_status "Re-registering plugin with WHM..."
/usr/local/cpanel/bin/register_appconfig "$WHM_ADDON_DIR/AppConfig"

# Rebuild WHM theme
print_status "Rebuilding WHM theme..."
/usr/local/cpanel/bin/build_whm_themes

print_status "Update completed successfully!"
print_status "Please visit WHM > Plugins > Restic Backup to verify the plugin is working correctly."

exit 0