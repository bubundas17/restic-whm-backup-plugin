# Restic Backup Plugin for WHM/cPanel

A WHM/cPanel plugin that enables efficient backups of cPanel accounts using [restic](https://restic.net/), a fast and secure backup program with built-in deduplication.

## Features

- Efficient backups using restic's deduplication technology
- Direct backups of cPanel account data (not compressed archives)
- Scheduled automatic backups (daily, weekly, or monthly)
- Configurable retention policies
- WHM admin interface for managing backups and restores
- cPanel user interface for self-service backups and restores
- Support for various repository backends (local, SFTP, S3, etc.)

## Why Restic?

Unlike WHM's built-in backup system which creates compressed archives, this plugin uses restic to back up the raw files. This approach offers several advantages:

- **Efficient deduplication**: Only new or changed data is stored
- **Faster backups**: No need to compress/decompress large archives
- **Incremental backups**: Only changes are transferred
- **Flexible storage options**: Store backups locally, on remote servers, or in the cloud
- **Encryption**: All data is encrypted before leaving the server

## Requirements

- WHM/cPanel server
- Root access to the server
- restic (automatically installed by the installation script)

## Installation

1. Download the plugin:
   ```
   cd /root
   git clone https://github.com/bubundas17/restic-whm-backup-plugin.git
   cd restic-whm-backup-plugin
   ```

2. Run the installation script:
   ```
   bash install.sh
   ```

3. The installation script will:
   - Install restic if it's not already installed
   - Copy the plugin files to the appropriate locations
   - Set up the necessary permissions
   - Create a cron job for scheduled backups
   - Register the plugin with WHM

4. After installation, access the plugin in WHM at:
   ```
   WHM > Plugins > Restic Backup
   ```

## Configuration

### Setting Up a Repository

Before using the plugin, you need to configure a restic repository:

1. Log in to WHM
2. Navigate to "Plugins > Restic Backup"
3. Enter the repository location in one of the following formats:
   - Local directory: `/path/to/backup`
   - SFTP: `sftp:user@host:/path/to/backup`
   - S3: `s3:s3.amazonaws.com/bucket_name`
   - See [restic documentation](https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html) for more options
4. Enter a strong password for the repository (this will encrypt all your backups)
5. Configure the backup schedule and retention policy
6. Click "Save Configuration"

### Backup Schedule

You can configure backups to run:
- Daily (default)
- Weekly (Sundays)
- Monthly (1st of the month)

### Retention Policy

Configure how long backups are kept:
- Daily backups: Number of daily backups to keep
- Weekly backups: Number of weekly backups to keep
- Monthly backups: Number of monthly backups to keep

## Usage

### For Administrators

#### Manual Backups

1. Log in to WHM
2. Navigate to "Plugins > Restic Backup"
3. Find the account you want to back up in the list
4. Click "Backup Now"

#### Viewing Snapshots

1. Log in to WHM
2. Navigate to "Plugins > Restic Backup"
3. Find the account you want to view
4. Click "View Snapshots"

#### Restoring an Account

1. Log in to WHM
2. Navigate to "Plugins > Restic Backup"
3. Find the account you want to restore
4. Click "View Snapshots"
5. Find the snapshot you want to restore from
6. Click "Restore"

#### Viewing Logs

1. Log in to WHM
2. Navigate to "Plugins > Restic Backup"
3. Find the account you want to view logs for
4. Click "View Logs"

### For Users

#### Backing Up Your Account

1. Log in to cPanel
2. Navigate to "Restic Backup"
3. Click "Backup Now"

#### Viewing Your Backups

1. Log in to cPanel
2. Navigate to "Restic Backup"
3. Your backup history will be displayed

#### Restoring Your Account

1. Log in to cPanel
2. Navigate to "Restic Backup"
3. Find the backup you want to restore from
4. Click "Restore"
5. Confirm the restoration

## Updating the Plugin

If you've made changes to the plugin source code or want to update to a newer version, you can use the update script:

```
cd /root/restic-whm-backup-plugin
bash update.sh
```

The update script will:
- Backup your existing configuration
- Update all plugin files
- Set the correct permissions
- Re-register the plugin with WHM
- Rebuild WHM themes

## Building RPM Packages

For RHEL/CentOS 8 and 9 systems, you can build RPM packages for easier distribution and installation:

### Prerequisites

- rpm-build and rpmdevtools packages:
  ```
  dnf install rpm-build rpmdevtools
  ```

### Building the RPMs

```
cd /root/restic-whm-backup-plugin
bash build_rpm.sh
```

The script will:
- Create a spec file for the RPM package
- Build packages for both RHEL/CentOS 8 and 9
- Output the packages to the `rpm_packages` directory

### Installing from RPM

Once built, you can install the plugin using:

```
rpm -ivh rpm_packages/restic-backup-whm-1.0.0-1.el8.noarch.rpm  # For RHEL/CentOS 8
rpm -ivh rpm_packages/restic-backup-whm-1.0.0-1.el9.noarch.rpm  # For RHEL/CentOS 9
```

## Troubleshooting

### Backup Fails

1. Check the logs in WHM > Plugins > Restic Backup > View Logs
2. Verify that restic is installed: `which restic`
3. Ensure the repository is accessible
4. Check disk space on both the server and the backup destination

### Restore Fails

1. Check the logs in WHM > Plugins > Restic Backup > View Logs
2. Verify that the snapshot exists: `restic -r [repository] snapshots`
3. Ensure there is enough disk space for the restore

### Plugin Not Appearing in WHM

1. Rebuild WHM themes: `/usr/local/cpanel/bin/build_whm_themes`
2. Verify the plugin is registered: `grep restic_backup /usr/local/cpanel/whostmgr/addonfeatures`
3. Check permissions on plugin files

## Uninstallation

To uninstall the plugin:

```
cd /root/restic-whm-backup-plugin
bash uninstall.sh
```

The uninstallation script will ask if you want to keep the configuration directory and backup logs.

## License

This plugin is released under the MIT License. See the LICENSE file for details.

## Support

For support, please open an issue on the GitHub repository or contact the author.