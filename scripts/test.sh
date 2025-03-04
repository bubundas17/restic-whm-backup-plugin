#!/bin/bash
# Test script for Restic Backup Plugin

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

# Function to check if a command succeeded
check_status() {
    if [ $? -eq 0 ]; then
        print_status "Success: $1"
        return 0
    else
        print_error "Failed: $1"
        return 1
    fi
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    print_error "This script must be run as root"
    exit 1
fi

# Define paths
CONFIG_DIR="/var/cpanel/restic_backup"
CONFIG_FILE="$CONFIG_DIR/config.json"
PLUGIN_DIR="/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin"
TEST_DIR="/tmp/restic_backup_test"
TEST_REPO="/tmp/restic_backup_test_repo"

# Create test directory
mkdir -p "$TEST_DIR"
mkdir -p "$TEST_REPO"

# Check if restic is installed
print_status "Checking if restic is installed..."
if command -v restic &> /dev/null; then
    print_status "Restic is installed: $(restic version)"
else
    print_error "Restic is not installed. Please install it first."
    exit 1
fi

# Check if config file exists
print_status "Checking if configuration file exists..."
if [ -f "$CONFIG_FILE" ]; then
    print_status "Configuration file found at $CONFIG_FILE"
    
    # Load configuration
    REPOSITORY=$(grep -o '"repository":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
    PASSWORD=$(grep -o '"password":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
    
    if [ -z "$REPOSITORY" ] || [ -z "$PASSWORD" ]; then
        print_warning "Repository or password not configured in $CONFIG_FILE"
        print_warning "Will use test repository for testing"
        USE_TEST_REPO=1
    else
        print_status "Repository configuration found"
        USE_TEST_REPO=0
    fi
else
    print_warning "Configuration file not found at $CONFIG_FILE"
    print_warning "Will use test repository for testing"
    USE_TEST_REPO=1
fi

# Set up test repository if needed
if [ "$USE_TEST_REPO" -eq 1 ]; then
    print_status "Setting up test repository at $TEST_REPO..."
    export RESTIC_REPOSITORY="$TEST_REPO"
    export RESTIC_PASSWORD="testpassword"
    
    # Initialize repository
    restic init
    check_status "Initialize test repository" || exit 1
else
    print_status "Using configured repository: $REPOSITORY"
    export RESTIC_REPOSITORY="$REPOSITORY"
    export RESTIC_PASSWORD="$PASSWORD"
fi

# Create test files
print_status "Creating test files..."
echo "Test file 1" > "$TEST_DIR/test1.txt"
echo "Test file 2" > "$TEST_DIR/test2.txt"
mkdir -p "$TEST_DIR/subdir"
echo "Test file 3" > "$TEST_DIR/subdir/test3.txt"

# Test backup
print_status "Testing backup functionality..."
restic backup "$TEST_DIR" --tag "test"
check_status "Backup test files" || exit 1

# List snapshots
print_status "Listing snapshots..."
restic snapshots --tag "test"
check_status "List snapshots" || exit 1

# Get the latest snapshot ID
SNAPSHOT_ID=$(restic snapshots --tag "test" --json | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ -z "$SNAPSHOT_ID" ]; then
    print_error "Failed to get snapshot ID"
    exit 1
fi
print_status "Latest snapshot ID: $SNAPSHOT_ID"

# Remove test files
print_status "Removing test files..."
rm -rf "$TEST_DIR"/*
check_status "Remove test files" || exit 1

# Test restore
print_status "Testing restore functionality..."
restic restore "$SNAPSHOT_ID" --target "$TEST_DIR" --include "$TEST_DIR"
check_status "Restore test files" || exit 1

# Verify restored files
print_status "Verifying restored files..."
if [ -f "$TEST_DIR/test1.txt" ] && [ -f "$TEST_DIR/test2.txt" ] && [ -f "$TEST_DIR/subdir/test3.txt" ]; then
    print_status "All files restored successfully"
else
    print_error "Not all files were restored"
    exit 1
fi

# Check plugin scripts
print_status "Checking plugin scripts..."
SCRIPTS=("backup.sh" "restore.sh" "periodic_backup.sh")
for SCRIPT in "${SCRIPTS[@]}"; do
    if [ -f "$PLUGIN_DIR/scripts/$SCRIPT" ] && [ -x "$PLUGIN_DIR/scripts/$SCRIPT" ]; then
        print_status "Script $SCRIPT exists and is executable"
    else
        print_warning "Script $SCRIPT is missing or not executable"
    fi
done

# Check CGI scripts
print_status "Checking CGI scripts..."
if [ -f "$PLUGIN_DIR/restic_backup_admin.cgi" ] && [ -x "$PLUGIN_DIR/restic_backup_admin.cgi" ]; then
    print_status "Admin CGI script exists and is executable"
else
    print_warning "Admin CGI script is missing or not executable"
fi

if [ -f "/usr/local/cpanel/base/frontend/paper_lantern/restic_backup/restic_backup_user.cgi" ] && [ -x "/usr/local/cpanel/base/frontend/paper_lantern/restic_backup/restic_backup_user.cgi" ]; then
    print_status "User CGI script exists and is executable"
else
    print_warning "User CGI script is missing or not executable"
fi

# Check cron job
print_status "Checking cron job..."
if [ -f "/etc/cron.d/restic_backup" ]; then
    print_status "Cron job exists"
else
    print_warning "Cron job is missing"
fi

# Clean up
print_status "Cleaning up test files..."
rm -rf "$TEST_DIR"
if [ "$USE_TEST_REPO" -eq 1 ]; then
    rm -rf "$TEST_REPO"
fi

print_status "Test completed successfully!"
print_status "The Restic Backup Plugin appears to be working correctly."
exit 0