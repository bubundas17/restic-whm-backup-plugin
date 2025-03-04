#!/bin/bash
# Restic Restore Script for cPanel accounts

# Check if username and snapshot ID are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <username> <snapshot_id>"
    exit 1
fi

USERNAME="$1"
SNAPSHOT_ID="$2"
CONFIG_DIR="/var/cpanel/restic_backup"
CONFIG_FILE="$CONFIG_DIR/config.json"
LOG_DIR="$CONFIG_DIR/logs"
LOG_FILE="$LOG_DIR/$USERNAME.log"
TEMP_RESTORE_DIR="/home/tmp_restore_$USERNAME"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if restic is installed
if ! command -v restic &> /dev/null; then
    log "ERROR: restic is not installed. Please install it first."
    exit 1
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    log "ERROR: Configuration file not found at $CONFIG_FILE"
    exit 1
fi

# Load configuration
REPOSITORY=$(grep -o '"repository":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
PASSWORD=$(grep -o '"password":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)

if [ -z "$REPOSITORY" ] || [ -z "$PASSWORD" ]; then
    log "ERROR: Repository or password not configured"
    exit 1
fi

# Check if user exists
if ! id -u "$USERNAME" &>/dev/null; then
    log "ERROR: User $USERNAME does not exist"
    exit 1
fi

# Get user's home directory
USER_HOME=$(eval echo ~"$USERNAME")
if [ ! -d "$USER_HOME" ]; then
    log "ERROR: Home directory for $USERNAME not found"
    exit 1
fi

# Set environment variables for restic
export RESTIC_REPOSITORY="$REPOSITORY"
export RESTIC_PASSWORD="$PASSWORD"

# Verify the snapshot exists
log "Verifying snapshot $SNAPSHOT_ID..."
if ! restic snapshots "$SNAPSHOT_ID" &>/dev/null; then
    log "ERROR: Snapshot $SNAPSHOT_ID not found"
    exit 1
fi

# Create temporary restore directory
log "Creating temporary restore directory..."
mkdir -p "$TEMP_RESTORE_DIR"

# Restore to temporary directory first
log "Restoring snapshot $SNAPSHOT_ID to temporary directory..."
if ! restic restore "$SNAPSHOT_ID" --target "$TEMP_RESTORE_DIR"; then
    log "ERROR: Failed to restore snapshot"
    rm -rf "$TEMP_RESTORE_DIR"
    exit 1
fi

# Check if user's home directory was restored
USER_HOME_RESTORED="$TEMP_RESTORE_DIR$(echo "$USER_HOME" | sed 's/^\///')"
if [ ! -d "$USER_HOME_RESTORED" ]; then
    log "ERROR: User home directory not found in restored data"
    rm -rf "$TEMP_RESTORE_DIR"
    exit 1
fi

# Backup current home directory
BACKUP_DIR="${USER_HOME}_backup_$(date +%Y%m%d%H%M%S)"
log "Backing up current home directory to $BACKUP_DIR..."
cp -a "$USER_HOME" "$BACKUP_DIR"

# Restore home directory
log "Restoring home directory..."
find "$USER_HOME" -mindepth 1 -delete
cp -a "$USER_HOME_RESTORED"/* "$USER_HOME"/
chown -R "$USERNAME:$USERNAME" "$USER_HOME"

# Check for database dumps
DB_DUMP_DIR="$TEMP_RESTORE_DIR/home/$USERNAME/tmp_db_backup"
if [ -d "$DB_DUMP_DIR" ]; then
    log "Found database dumps, restoring databases..."
    
    # Restore each database
    for SQL_FILE in "$DB_DUMP_DIR"/*.sql; do
        if [ -f "$SQL_FILE" ]; then
            DB_NAME=$(basename "$SQL_FILE" .sql)
            log "Restoring database $DB_NAME..."
            
            # Check if database exists
            if mysql -e "USE $DB_NAME" 2>/dev/null; then
                # Drop existing database
                mysql -e "DROP DATABASE $DB_NAME"
            fi
            
            # Create database
            mysql -e "CREATE DATABASE $DB_NAME"
            
            # Restore database
            mysql "$DB_NAME" < "$SQL_FILE"
            
            # Set permissions
            mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$USERNAME'@'localhost'"
        fi
    done
    
    mysql -e "FLUSH PRIVILEGES"
    log "Database restoration completed"
fi

# Clean up
log "Cleaning up temporary files..."
rm -rf "$TEMP_RESTORE_DIR"

log "Restore completed successfully"
log "A backup of the previous home directory is available at $BACKUP_DIR"

# Rebuild user's cPanel cache
if command -v /scripts/updateuserdatadb &>/dev/null; then
    log "Rebuilding cPanel cache for $USERNAME..."
    /scripts/updateuserdatadb --user="$USERNAME" --force
fi

exit 0