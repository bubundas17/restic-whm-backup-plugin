#!/usr/bin/perl
# Restic Backup Admin CGI Script

use strict;
use warnings;
use CGI;
use JSON;
use Cpanel::Template;
use Whostmgr::ACLS ();
use Whostmgr::HTMLInterface ();
use File::Path qw(make_path);

# Check if user has permission to access this page
Whostmgr::ACLS::init_acls();
if (!Whostmgr::ACLS::hasroot()) {
    print "Access denied\n";
    exit 1;
}

# Configuration paths
my $config_dir = "/var/cpanel/restic_backup";
my $config_file = "$config_dir/config.json";
my $template_dir = "/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/templates";

# Create config directory if it doesn't exist
if (!-d $config_dir) {
    make_path($config_dir);
}

# Initialize CGI
my $cgi = CGI->new();
my $action = $cgi->param('action') || 'show';

# Load configuration
my $config = {};
if (-f $config_file) {
    open my $fh, '<', $config_file or die "Cannot open config file: $!";
    local $/;
    my $json = <$fh>;
    close $fh;
    $config = decode_json($json) if $json;
}

# Handle form submissions
if ($action eq 'save_config') {
    # Update configuration
    $config->{repository} = $cgi->param('repository') || '';
    $config->{password} = $cgi->param('password') || '';
    $config->{schedule} = $cgi->param('schedule') || 'daily';
    $config->{retention} = {
        daily => $cgi->param('retention_daily') || 7,
        weekly => $cgi->param('retention_weekly') || 4,
        monthly => $cgi->param('retention_monthly') || 6,
    };
    
    # Save configuration
    open my $fh, '>', $config_file or die "Cannot write config file: $!";
    print $fh encode_json($config);
    close $fh;
    
    # Set file permissions
    chmod 0600, $config_file;
    
    # Redirect to show page
    print $cgi->redirect({-uri => 'restic_backup_admin.cgi'});
    exit;
}
elsif ($action eq 'backup_account') {
    my $username = $cgi->param('username');
    if ($username) {
        # Execute backup script
        system("/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/scripts/backup.sh", $username);
        print $cgi->redirect({-uri => 'restic_backup_admin.cgi?action=show_logs&username=' . $username});
        exit;
    }
}
elsif ($action eq 'restore_account') {
    my $username = $cgi->param('username');
    my $snapshot = $cgi->param('snapshot');
    if ($username && $snapshot) {
        # Execute restore script
        system("/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/scripts/restore.sh", $username, $snapshot);
        print $cgi->redirect({-uri => 'restic_backup_admin.cgi?action=show_logs&username=' . $username});
        exit;
    }
}
elsif ($action eq 'show_logs') {
    my $username = $cgi->param('username');
    my $logs = "No logs available";
    
    if ($username && -f "$config_dir/logs/$username.log") {
        open my $fh, '<', "$config_dir/logs/$username.log" or die "Cannot open log file: $!";
        local $/;
        $logs = <$fh>;
        close $fh;
    }
    
    # Display logs
    Whostmgr::HTMLInterface::defheader("Restic Backup Logs for $username", "Restic Backup");
    print "<h2>Backup Logs for $username</h2>";
    print "<pre>$logs</pre>";
    print "<p><a href='restic_backup_admin.cgi'>Back to Admin Panel</a></p>";
    Whostmgr::HTMLInterface::footer();
    exit;
}
elsif ($action eq 'list_snapshots') {
    my $username = $cgi->param('username');
    my $snapshots = [];
    
    if ($username && $config->{repository}) {
        # Get snapshots for user
        my $output = `RESTIC_PASSWORD='$config->{password}' restic -r '$config->{repository}' snapshots --tag '$username' --json 2>/dev/null`;
        if ($output) {
            $snapshots = decode_json($output);
        }
    }
    
    # Display snapshots
    Whostmgr::HTMLInterface::defheader("Restic Snapshots for $username", "Restic Backup");
    print "<h2>Snapshots for $username</h2>";
    
    if (@$snapshots) {
        print "<table border='1' cellpadding='5'>";
        print "<tr><th>ID</th><th>Date</th><th>Actions</th></tr>";
        
        foreach my $snapshot (@$snapshots) {
            print "<tr>";
            print "<td>" . substr($snapshot->{id}, 0, 8) . "</td>";
            print "<td>" . $snapshot->{time} . "</td>";
            print "<td><a href='restic_backup_admin.cgi?action=restore_account&username=$username&snapshot=" . $snapshot->{id} . "'>Restore</a></td>";
            print "</tr>";
        }
        
        print "</table>";
    }
    else {
        print "<p>No snapshots found for this user.</p>";
    }
    
    print "<p><a href='restic_backup_admin.cgi'>Back to Admin Panel</a></p>";
    Whostmgr::HTMLInterface::footer();
    exit;
}

# Get list of cPanel accounts
my @accounts = ();
open my $fh, '<', '/etc/trueuserdomains' or die "Cannot open trueuserdomains: $!";
while (my $line = <$fh>) {
    if ($line =~ /^([^:]+):\s*(\S+)/) {
        push @accounts, $2;
    }
}
close $fh;

# Display admin interface
Whostmgr::HTMLInterface::defheader("Restic Backup Admin", "Restic Backup");

print <<HTML;
<h2>Restic Backup Configuration</h2>

<form method="post" action="restic_backup_admin.cgi">
    <input type="hidden" name="action" value="save_config">
    
    <h3>Repository Settings</h3>
    <p>
        <label for="repository">Restic Repository:</label><br>
        <input type="text" id="repository" name="repository" size="50" value="$config->{repository}">
        <br><small>Examples: /backup/restic, sftp:user@host:/path, s3:s3.amazonaws.com/bucket_name</small>
    </p>
    
    <p>
        <label for="password">Repository Password:</label><br>
        <input type="password" id="password" name="password" size="30" value="$config->{password}">
    </p>
    
    <h3>Backup Schedule</h3>
    <p>
        <label for="schedule">Schedule:</label><br>
        <select id="schedule" name="schedule">
            <option value="daily" @{[$config->{schedule} eq 'daily' ? 'selected' : '']}>Daily</option>
            <option value="weekly" @{[$config->{schedule} eq 'weekly' ? 'selected' : '']}>Weekly</option>
            <option value="monthly" @{[$config->{schedule} eq 'monthly' ? 'selected' : '']}>Monthly</option>
        </select>
    </p>
    
    <h3>Retention Policy</h3>
    <p>
        <label for="retention_daily">Keep daily backups:</label>
        <input type="number" id="retention_daily" name="retention_daily" min="1" max="90" value="$config->{retention}{daily}"> days
    </p>
    
    <p>
        <label for="retention_weekly">Keep weekly backups:</label>
        <input type="number" id="retention_weekly" name="retention_weekly" min="1" max="52" value="$config->{retention}{weekly}"> weeks
    </p>
    
    <p>
        <label for="retention_monthly">Keep monthly backups:</label>
        <input type="number" id="retention_monthly" name="retention_monthly" min="1" max="24" value="$config->{retention}{monthly}"> months
    </p>
    
    <p>
        <input type="submit" value="Save Configuration">
    </p>
</form>

<h2>Account Management</h2>

<table border="1" cellpadding="5">
    <tr>
        <th>Username</th>
        <th>Actions</th>
    </tr>
HTML

foreach my $username (sort @accounts) {
    print "<tr>";
    print "<td>$username</td>";
    print "<td>";
    print "<a href='restic_backup_admin.cgi?action=backup_account&username=$username'>Backup Now</a> | ";
    print "<a href='restic_backup_admin.cgi?action=list_snapshots&username=$username'>View Snapshots</a> | ";
    print "<a href='restic_backup_admin.cgi?action=show_logs&username=$username'>View Logs</a>";
    print "</td>";
    print "</tr>";
}

print <<HTML;
</table>

<script>
// JavaScript for the admin interface
document.addEventListener('DOMContentLoaded', function() {
    // Add any JavaScript functionality here
});
</script>
HTML

Whostmgr::HTMLInterface::footer();