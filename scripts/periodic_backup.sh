#!/bin/bash
# Periodic Backup Script for cPanel accounts using restic

CONFIG_DIR="/var/cpanel/restic_backup"
CONFIG_FILE="$CONFIG_DIR/config.json"
LOG_DIR="$CONFIG_DIR/logs"
MAIN_LOG_FILE="$LOG_DIR/periodic_backup.log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$MAIN_LOG_FILE"
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
SCHEDULE=$(grep -o '"schedule":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)

if [ -z "$REPOSITORY" ] || [ -z "$PASSWORD" ]; then
    log "ERROR: Repository or password not configured"
    exit 1
fi

# Determine if backup should run today based on schedule
RUN_BACKUP=0
CURRENT_DAY=$(date +%u)  # 1-7, 1 is Monday
CURRENT_DATE=$(date +%d) # Day of month

case "$SCHEDULE" in
    "daily")
        RUN_BACKUP=1
        ;;
    "weekly")
        # Run on Sundays (day 7)
        if [ "$CURRENT_DAY" -eq 7 ]; then
            RUN_BACKUP=1
        fi
        ;;
    "monthly")
        # Run on the 1st of the month
        if [ "$CURRENT_DATE" -eq 1 ]; then
            RUN_BACKUP=1
        fi
        ;;
    *)
        log "Unknown schedule: $SCHEDULE. Defaulting to daily."
        RUN_BACKUP=1
        ;;
esac

if [ "$RUN_BACKUP" -eq 0 ]; then
    log "Skipping backup based on schedule: $SCHEDULE"
    exit 0
fi

# Get list of cPanel accounts
log "Getting list of cPanel accounts..."
ACCOUNTS=$(cut -d: -f1 /etc/passwd | grep -v "nobody" | grep -v "mysql" | grep -v "root" | grep -v "cpanel" | grep -v "system")

# Count total accounts
TOTAL_ACCOUNTS=$(echo "$ACCOUNTS" | wc -l)
log "Found $TOTAL_ACCOUNTS cPanel accounts to backup"

# Initialize counters
SUCCESS_COUNT=0
FAIL_COUNT=0

# Backup each account
for USERNAME in $ACCOUNTS; do
    log "Processing account: $USERNAME"
    
    # Run backup script
    if /usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/scripts/backup.sh "$USERNAME"; then
        log "Backup successful for $USERNAME"
        ((SUCCESS_COUNT++))
    else
        log "Backup failed for $USERNAME"
        ((FAIL_COUNT++))
    fi
done

# Log summary
log "Backup job completed. Success: $SUCCESS_COUNT, Failed: $FAIL_COUNT, Total: $TOTAL_ACCOUNTS"

# Apply global retention policy
log "Applying global retention policy..."
export RESTIC_REPOSITORY="$REPOSITORY"
export RESTIC_PASSWORD="$PASSWORD"

# Get retention values from config
RETENTION_DAILY=$(grep -o '"daily":[0-9]*' "$CONFIG_FILE" | cut -d: -f2)
RETENTION_WEEKLY=$(grep -o '"weekly":[0-9]*' "$CONFIG_FILE" | cut -d: -f2)
RETENTION_MONTHLY=$(grep -o '"monthly":[0-9]*' "$CONFIG_FILE" | cut -d: -f2)

# Set defaults if not found
RETENTION_DAILY=${RETENTION_DAILY:-7}
RETENTION_WEEKLY=${RETENTION_WEEKLY:-4}
RETENTION_MONTHLY=${RETENTION_MONTHLY:-6}

# Run forget command
log "Running retention policy: keep-daily $RETENTION_DAILY, keep-weekly $RETENTION_WEEKLY, keep-monthly $RETENTION_MONTHLY"
if restic forget --tag "cpanel" --keep-daily "$RETENTION_DAILY" --keep-weekly "$RETENTION_WEEKLY" --keep-monthly "$RETENTION_MONTHLY" --prune; then
    log "Retention policy applied successfully"
else
    log "ERROR: Failed to apply retention policy"
fi

exit 0