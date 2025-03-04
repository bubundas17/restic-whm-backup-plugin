#!/bin/bash
# Script to build RPM packages for Restic Backup WHM Plugin
# Supports RHEL/CentOS 8 and 9

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

# Check if rpmbuild is installed
if ! command -v rpmbuild &> /dev/null; then
    print_error "rpmbuild is not installed. Please install it first."
    print_status "For RHEL/CentOS 8/9: dnf install rpm-build rpmdevtools"
    exit 1
fi

# Define variables
PLUGIN_NAME="restic-backup-whm"
PLUGIN_VERSION="1.0.0"
PLUGIN_RELEASE="1"
PLUGIN_DIR="$(pwd)"
BUILD_DIR="$PLUGIN_DIR/rpmbuild"
SPEC_FILE="$BUILD_DIR/SPECS/$PLUGIN_NAME.spec"
OUTPUT_DIR="$PLUGIN_DIR/rpm_packages"
RHEL_VERSIONS=("8" "9")

# Create build directories
print_status "Creating build directories..."
mkdir -p "$BUILD_DIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
mkdir -p "$OUTPUT_DIR"

# Create tarball of the plugin
print_status "Creating source tarball..."
TARBALL_NAME="$PLUGIN_NAME-$PLUGIN_VERSION"
TARBALL_PATH="$BUILD_DIR/SOURCES/$TARBALL_NAME.tar.gz"

# Create a temporary directory for the tarball contents
TMP_DIR=$(mktemp -d)
mkdir -p "$TMP_DIR/$TARBALL_NAME"

# Copy plugin files to the temporary directory
cp -r "$PLUGIN_DIR"/* "$TMP_DIR/$TARBALL_NAME/"

# Create the tarball
(cd "$TMP_DIR" && tar -czf "$TARBALL_PATH" "$TARBALL_NAME")

# Clean up temporary directory
rm -rf "$TMP_DIR"

# Create spec file
print_status "Creating RPM spec file..."
cat > "$SPEC_FILE" << EOF
Name:           $PLUGIN_NAME
Version:        $PLUGIN_VERSION
Release:        $PLUGIN_RELEASE%{?dist}
Summary:        WHM/cPanel plugin for backing up accounts using restic

License:        MIT
URL:            https://github.com/bubundas17/restic-whm-backup-plugin
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
Requires:       restic
Requires:       perl
Requires:       perl(JSON)
Requires:       perl(CGI)
Requires:       whostmgr
Requires:       cpanel

%description
A WHM/cPanel plugin that enables efficient backups of cPanel accounts using restic,
a fast and secure backup program with built-in deduplication.

Features:
- Efficient backups using restic's deduplication technology
- Direct backups of cPanel account data (not compressed archives)
- Scheduled automatic backups (daily, weekly, or monthly)
- Configurable retention policies
- WHM admin interface for managing backups and restores
- cPanel user interface for self-service backups and restores
- Support for various repository backends (local, SFTP, S3, etc.)

%prep
%setup -q

%build
# Nothing to build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin
mkdir -p %{buildroot}/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/scripts
mkdir -p %{buildroot}/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/templates
mkdir -p %{buildroot}/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/ui/icons
mkdir -p %{buildroot}/usr/local/cpanel/base/frontend/paper_lantern/restic_backup
mkdir -p %{buildroot}/var/cpanel/restic_backup
mkdir -p %{buildroot}/var/cpanel/restic_backup/logs
mkdir -p %{buildroot}/etc/cron.d

# Copy files
cp -p plugin.conf %{buildroot}/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/
cp -p AppConfig %{buildroot}/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/
cp -p restic_backup_admin.cgi %{buildroot}/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/
cp -p restic_backup_user.cgi %{buildroot}/usr/local/cpanel/base/frontend/paper_lantern/restic_backup/
cp -p scripts/*.sh %{buildroot}/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/scripts/
cp -p templates/*.tmpl %{buildroot}/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/templates/
cp -p ui/icons/* %{buildroot}/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/ui/icons/

# Create symlinks
ln -sf /usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/restic_backup_admin.cgi %{buildroot}/usr/local/cpanel/whostmgr/docroot/cgi/restic_backup_admin.cgi
ln -sf /usr/local/cpanel/base/frontend/paper_lantern/restic_backup/restic_backup_user.cgi %{buildroot}/usr/local/cpanel/base/frontend/paper_lantern/restic_backup.cgi

# Create cron job
cat > %{buildroot}/etc/cron.d/restic_backup << 'CRON'
# Restic Backup cron job
0 2 * * * root /usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/scripts/periodic_backup.sh > /dev/null 2>&1
CRON

# Set permissions
chmod 700 %{buildroot}/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/scripts/*.sh
chmod 755 %{buildroot}/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/restic_backup_admin.cgi
chmod 755 %{buildroot}/usr/local/cpanel/base/frontend/paper_lantern/restic_backup/restic_backup_user.cgi
chmod 644 %{buildroot}/etc/cron.d/restic_backup

%post
# Register the plugin with WHM
/usr/local/cpanel/bin/register_appconfig /usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/AppConfig

# Rebuild WHM theme
/usr/local/cpanel/bin/build_whm_themes

# Create initial configuration file if it doesn't exist
if [ ! -f /var/cpanel/restic_backup/config.json ]; then
    cat > /var/cpanel/restic_backup/config.json << 'CONFIG'
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
CONFIG
    chmod 600 /var/cpanel/restic_backup/config.json
fi

%preun
# Only on uninstall, not on upgrade
if [ $1 -eq 0 ]; then
    # Unregister the plugin from WHM
    /usr/local/cpanel/bin/unregister_appconfig /usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/AppConfig
    
    # Rebuild WHM theme
    /usr/local/cpanel/bin/build_whm_themes
    
    # Remove symlinks
    rm -f /usr/local/cpanel/whostmgr/docroot/cgi/restic_backup_admin.cgi
    rm -f /usr/local/cpanel/base/frontend/paper_lantern/restic_backup.cgi
fi

%files
%defattr(-,root,root,-)
%doc README.md
%license LICENSE
/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/
/usr/local/cpanel/base/frontend/paper_lantern/restic_backup/
/usr/local/cpanel/whostmgr/docroot/cgi/restic_backup_admin.cgi
/usr/local/cpanel/base/frontend/paper_lantern/restic_backup.cgi
%config(noreplace) /etc/cron.d/restic_backup
%dir %attr(700,root,root) /var/cpanel/restic_backup
%dir %attr(700,root,root) /var/cpanel/restic_backup/logs

%changelog
* $(date +"%a %b %d %Y") <your-email@example.com> - $PLUGIN_VERSION-$PLUGIN_RELEASE
- Initial package
EOF

# Build RPM packages for each RHEL version
for RHEL_VERSION in "${RHEL_VERSIONS[@]}"; do
    print_status "Building RPM package for RHEL/CentOS $RHEL_VERSION..."
    
    # Define the dist tag based on RHEL version
    if [ "$RHEL_VERSION" == "8" ]; then
        DIST_TAG="el8"
    elif [ "$RHEL_VERSION" == "9" ]; then
        DIST_TAG="el9"
    else
        print_error "Unsupported RHEL version: $RHEL_VERSION"
        continue
    fi
    
    # Build the RPM package
    rpmbuild --define "_topdir $BUILD_DIR" --define "dist .$DIST_TAG" -bb "$SPEC_FILE"
    
    if [ $? -eq 0 ]; then
        # Copy the built RPM to the output directory
        find "$BUILD_DIR/RPMS" -name "*.rpm" -exec cp {} "$OUTPUT_DIR/" \;
        print_status "RPM package for RHEL/CentOS $RHEL_VERSION built successfully!"
    else
        print_error "Failed to build RPM package for RHEL/CentOS $RHEL_VERSION"
    fi
done

# List built packages
print_status "Built packages:"
ls -la "$OUTPUT_DIR"

print_status "RPM build process completed!"
print_status "Packages are available in: $OUTPUT_DIR"

exit 0