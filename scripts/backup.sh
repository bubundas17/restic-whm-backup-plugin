#!/bin/bash
# Restic Backup Script for cPanel accounts

# Check if username is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

USERNAME="$1"
CONFIG_DIR="/var/cpanel/restic_backup"
CONFIG_FILE="$CONFIG_DIR/config.json"
LOG_DIR="$CONFIG_DIR/logs"
LOG_FILE="$LOG_DIR/$USERNAME.log"

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

# Initialize repository if needed
log "Checking repository..."
if ! restic snapshots &>/dev/null; then
    log "Initializing repository..."
    if ! restic init; then
        log "ERROR: Failed to initialize repository"
        exit 1
    fi
    log "Repository initialized successfully"
fi

# Create a list of directories to backup
# We'll backup the user's home directory and any databases
BACKUP_DIRS="$USER_HOME"

# Get user's databases
log "Finding databases for $USERNAME..."
MYSQL_DBS=$(mysql -N -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME LIKE '${USERNAME}\_%' OR SCHEMA_NAME = '${USERNAME}';" 2>/dev/null)

if [ -n "$MYSQL_DBS" ]; then
    # Create a temporary directory for database dumps
    DB_DUMP_DIR="$USER_HOME/tmp_db_backup"
    mkdir -p "$DB_DUMP_DIR"
    
    # Dump each database
    for DB in $MYSQL_DBS; do
        log "Dumping database $DB..."
        mysqldump "$DB" > "$DB_DUMP_DIR/$DB.sql"
    done
    
    # Add the database dump directory to backup dirs
    BACKUP_DIRS="$BACKUP_DIRS $DB_DUMP_DIR"
fi

# Start backup
log "Starting backup for user $USERNAME..."
log "Backing up: $BACKUP_DIRS"

# Run the backup
if restic backup $BACKUP_DIRS --tag "$USERNAME" --tag "cpanel" --tag "$(date +%Y-%m-%d)" --exclude="*/cache/*" --exclude="*/tmp/*" --exclude="*/logs/*"; then
    log "Backup completed successfully"
    
    # Apply retention policy
    log "Applying retention policy..."
    restic forget --tag "$USERNAME" --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
    
    # Cleanup
    if [ -d "$DB_DUMP_DIR" ]; then
        log "Cleaning up database dumps..."
        rm -rf "$DB_DUMP_DIR"
    fi
    
    exit 0
else
    log "ERROR: Backup failed"
    
    # Cleanup
    if [ -d "$DB_DUMP_DIR" ]; then
        log "Cleaning up database dumps..."
        rm -rf "$DB_DUMP_DIR"
    fi
    
    exit 1
fi