#!/bin/bash
# Installation script for Restic Backup WHM Plugin

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
CRON_FILE="/etc/cron.d/restic_backup"

# Create directories
print_status "Creating plugin directories..."
mkdir -p "$WHM_ADDON_DIR/scripts"
mkdir -p "$WHM_ADDON_DIR/templates"
mkdir -p "$WHM_ADDON_DIR/ui/icons"
mkdir -p "$CPANEL_PLUGIN_DIR"
mkdir -p "$CONFIG_DIR/logs"

# Copy files
print_status "Copying plugin files..."
cp -f "$PLUGIN_DIR/plugin.conf" "$WHM_ADDON_DIR/"
cp -f "$PLUGIN_DIR/AppConfig" "$WHM_ADDON_DIR/"
cp -f "$PLUGIN_DIR/restic_backup_admin.cgi" "$WHM_ADDON_DIR/"
cp -f "$PLUGIN_DIR/restic_backup_user.cgi" "$CPANEL_PLUGIN_DIR/"
cp -f "$PLUGIN_DIR/scripts/"* "$WHM_ADDON_DIR/scripts/"
cp -f "$PLUGIN_DIR/templates/"* "$WHM_ADDON_DIR/templates/" 2>/dev/null || mkdir -p "$WHM_ADDON_DIR/templates/"
cp -f "$PLUGIN_DIR/ui/icons/"* "$WHM_ADDON_DIR/ui/icons/" 2>/dev/null || true

# Set permissions
print_status "Setting file permissions..."
chmod 700 "$WHM_ADDON_DIR/scripts/"*
chmod 755 "$WHM_ADDON_DIR/restic_backup_admin.cgi"
chmod 755 "$CPANEL_PLUGIN_DIR/restic_backup_user.cgi"
chmod 700 "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR/logs"

# Create symlinks
print_status "Creating symlinks..."
ln -sf "$WHM_ADDON_DIR/restic_backup_admin.cgi" "/usr/local/cpanel/whostmgr/docroot/cgi/restic_backup_admin.cgi"
ln -sf "$CPANEL_PLUGIN_DIR/restic_backup_user.cgi" "/usr/local/cpanel/base/frontend/paper_lantern/restic_backup.cgi"

# Create cron job for periodic backups
print_status "Creating cron job for periodic backups..."
cat > "$CRON_FILE" << EOF
# Restic Backup cron job
0 2 * * * root $WHM_ADDON_DIR/scripts/periodic_backup.sh > /dev/null 2>&1
EOF

chmod 644 "$CRON_FILE"

# Check if restic is installed
if ! command -v restic &> /dev/null; then
    print_warning "Restic is not installed. Installing now..."
    
    # Determine OS and install restic
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        apt-get update
        apt-get install -y restic
    elif [ -f /etc/redhat-release ]; then
        # CentOS/RHEL
        if command -v dnf &> /dev/null; then
            dnf install -y restic
        else
            yum install -y restic
        fi
    else
        print_warning "Could not determine OS type. Please install restic manually."
        print_warning "Visit https://restic.net for installation instructions."
    fi
    
    # Check if installation was successful
    if command -v restic &> /dev/null; then
        print_status "Restic installed successfully."
    else
        print_error "Failed to install restic. Please install it manually."
        print_error "Visit https://restic.net for installation instructions."
    fi
fi

# Create initial configuration file if it doesn't exist
if [ ! -f "$CONFIG_DIR/config.json" ]; then
    print_status "Creating initial configuration file..."
    cat > "$CONFIG_DIR/config.json" << EOF
{
    "repository": "",
    "password": "",
    "schedule": "daily",
    "retention": {
        "daily": 7,
        "weekly": 4,
        "monthly": 6
    }
}
EOF
    chmod 600 "$CONFIG_DIR/config.json"
fi

# Register the plugin with WHM
print_status "Registering plugin with WHM..."
if [ -f "/usr/local/cpanel/bin/register_appconfig" ]; then
    /usr/local/cpanel/bin/register_appconfig "$WHM_ADDON_DIR/AppConfig"
else
    print_warning "register_appconfig command not found. Plugin may not be properly registered with WHM."
    print_warning "You may need to manually register the plugin."
fi

# Rebuild WHM theme
print_status "Rebuilding WHM theme..."
if [ -f "/usr/local/cpanel/bin/build_whm_themes" ]; then
    /usr/local/cpanel/bin/build_whm_themes
else
    print_warning "build_whm_themes command not found. WHM theme may not be properly updated."
    print_warning "You may need to manually rebuild the WHM theme."
fi

print_status "Installation completed successfully!"
print_status "Please visit WHM > Plugins > Restic Backup to configure the plugin."
print_status "You will need to set up a restic repository and password before using the plugin."

exit 0