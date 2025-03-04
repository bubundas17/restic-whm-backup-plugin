#!/usr/bin/perl
# Restic Backup User CGI Script

use strict;
use warnings;
use CGI;
use JSON;
use Cpanel::Template;
use Cpanel::Logger;
use File::Path qw(make_path);

# Configuration paths
my $config_dir = "/var/cpanel/restic_backup";
my $config_file = "$config_dir/config.json";
my $template_dir = "/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/templates";

# Initialize CGI
my $cgi = CGI->new();
my $action = $cgi->param('action') || 'show';

# Get current username
my $username = $ENV{'REMOTE_USER'} || '';
if (!$username) {
    print $cgi->header();
    print "Error: Could not determine username";
    exit 1;
}

# Load configuration
my $config = {};
if (-f $config_file) {
    open my $fh, '<', $config_file or die "Cannot open config file: $!";
    local $/;
    my $json = <$fh>;
    close $fh;
    $config = decode_json($json) if $json;
}

# Initialize logger
my $logger = Cpanel::Logger->new();

# Handle form submissions
if ($action eq 'backup') {
    # Execute backup script
    my $result = system("/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/scripts/backup.sh", $username);
    
    # Log the backup attempt
    if ($result == 0) {
        $logger->info("Restic backup initiated for $username");
    } else {
        $logger->error("Restic backup failed for $username");
    }
    
    # Redirect to show page
    print $cgi->redirect({-uri => 'restic_backup_user.cgi?action=show_logs'});
    exit;
}
elsif ($action eq 'restore') {
    my $snapshot = $cgi->param('snapshot');
    if ($snapshot) {
        # Execute restore script
        my $result = system("/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/scripts/restore.sh", $username, $snapshot);
        
        # Log the restore attempt
        if ($result == 0) {
            $logger->info("Restic restore initiated for $username from snapshot $snapshot");
        } else {
            $logger->error("Restic restore failed for $username from snapshot $snapshot");
        }
        
        # Redirect to show page
        print $cgi->redirect({-uri => 'restic_backup_user.cgi?action=show_logs'});
        exit;
    }
}
elsif ($action eq 'show_logs') {
    my $logs = "No logs available";
    
    if (-f "$config_dir/logs/$username.log") {
        open my $fh, '<', "$config_dir/logs/$username.log" or die "Cannot open log file: $!";
        local $/;
        $logs = <$fh>;
        close $fh;
    }
    
    # Display logs
    print $cgi->header();
    print Cpanel::Template::process_template(
        'restic_backup',
        {
            'logs' => $logs,
            'username' => $username,
            'page_title' => 'Backup Logs',
        }
    );
    exit;
}

# Get snapshots for user
my $snapshots = [];
if ($config->{repository}) {
    my $output = `RESTIC_PASSWORD='$config->{password}' restic -r '$config->{repository}' snapshots --tag '$username' --json 2>/dev/null`;
    if ($output) {
        eval {
            $snapshots = decode_json($output);
        };
        if ($@) {
            $logger->error("Failed to parse snapshots JSON: $@");
        }
    }
}

# Display user interface
print $cgi->header();
print <<HTML;
<!DOCTYPE html>
<html>
<head>
    <title>Restic Backup</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
        }
        h1, h2 {
            color: #333;
        }
        .button {
            display: inline-block;
            padding: 8px 16px;
            background-color: #0078d7;
            color: white;
            text-decoration: none;
            border-radius: 4px;
            margin-right: 10px;
        }
        .button:hover {
            background-color: #0056b3;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin-top: 20px;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 8px;
            text-align: left;
        }
        th {
            background-color: #f2f2f2;
        }
        tr:nth-child(even) {
            background-color: #f9f9f9;
        }
    </style>
</head>
<body>
    <h1>Restic Backup</h1>
    
    <div>
        <a href="restic_backup_user.cgi?action=backup" class="button">Backup Now</a>
        <a href="restic_backup_user.cgi?action=show_logs" class="button">View Logs</a>
    </div>
    
    <h2>Backup History</h2>
HTML

if (@$snapshots) {
    print <<HTML;
    <table>
        <tr>
            <th>ID</th>
            <th>Date</th>
            <th>Actions</th>
        </tr>
HTML

    foreach my $snapshot (@$snapshots) {
        print "<tr>";
        print "<td>" . substr($snapshot->{id}, 0, 8) . "</td>";
        print "<td>" . $snapshot->{time} . "</td>";
        print "<td><a href='restic_backup_user.cgi?action=restore&snapshot=" . $snapshot->{id} . "' class='button' onclick='return confirm(\"Are you sure you want to restore from this backup? This will overwrite your current account data.\")'>Restore</a></td>";
        print "</tr>";
    }
    
    print "</table>";
}
else {
    print "<p>No backups found for your account.</p>";
}

print <<HTML;
    <h2>About Restic Backup</h2>
    <p>
        This tool allows you to backup and restore your cPanel account using Restic, 
        a fast and secure backup program that provides efficient deduplication.
    </p>
    <p>
        <strong>Backup Now</strong>: Creates a new backup of your account.<br>
        <strong>Restore</strong>: Restores your account from a previous backup.<br>
        <strong>View Logs</strong>: Shows the logs of backup and restore operations.
    </p>
</body>
</html>
HTML