#!/usr/local/cpanel/3rdparty/bin/perl
#WHMADDON:restic_backup:Restic Backup:restic_backup.png
#ACLS:restic_backup_admin

use strict;
use warnings;
use Cpanel::Template ();
use CGI qw(:standard);
use JSON;
use File::Path qw(make_path);

# Configuration paths
my $config_dir = "/var/cpanel/restic_backup";
my $config_file = "$config_dir/config.json";
my $template_dir = "/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/templates";

# Create config directory if it doesn't exist
if (!-d $config_dir) {
    make_path($config_dir);
}

# Initialize CGI
my $query = new CGI;
my $action = $query->param('action') || 'show';

# Load configuration
my $config = {};
if (-f $config_file) {
    open my $fh, '<', $config_file or die "Cannot open config file: $!";
    local $/;
    my $json = <$fh>;
    close $fh;
    $config = decode_json($json) if $json;
}

# Set default values if not set
$config->{repository} ||= '';
$config->{password} ||= '';
$config->{schedule} ||= 'daily';
$config->{retention} ||= {};
$config->{retention}{daily} ||= 7;
$config->{retention}{weekly} ||= 4;
$config->{retention}{monthly} ||= 6;

# Handle form submissions
if ($action eq 'save_config') {
    # Update configuration
    $config->{repository} = $query->param('repository') || '';
    $config->{password} = $query->param('password') || '';
    $config->{schedule} = $query->param('schedule') || 'daily';
    $config->{retention} = {
        daily => $query->param('retention_daily') || 7,
        weekly => $query->param('retention_weekly') || 4,
        monthly => $query->param('retention_monthly') || 6,
    };
    
    # Save configuration
    open my $fh, '>', $config_file or die "Cannot write config file: $!";
    print $fh encode_json($config);
    close $fh;
    
    # Set file permissions
    chmod 0600, $config_file;
    
    # Redirect to show page
    print $query->redirect('restic_backup_admin.cgi');
    exit;
}
elsif ($action eq 'backup_account') {
    my $username = $query->param('username');
    if ($username) {
        # Execute backup script
        system("/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/scripts/backup.sh", $username);
        print $query->redirect('restic_backup_admin.cgi?action=show_logs&username=' . $username);
        exit;
    }
}
elsif ($action eq 'restore_account') {
    my $username = $query->param('username');
    my $snapshot = $query->param('snapshot');
    if ($username && $snapshot) {
        # Execute restore script
        system("/usr/local/cpanel/whostmgr/docroot/cgi/addons/restic_backup_plugin/scripts/restore.sh", $username, $snapshot);
        print $query->redirect('restic_backup_admin.cgi?action=show_logs&username=' . $username);
        exit;
    }
}
elsif ($action eq 'show_logs') {
    my $username = $query->param('username');
    my $logs = "No logs available";
    
    if ($username && -f "$config_dir/logs/$username.log") {
        open my $fh, '<', "$config_dir/logs/$username.log" or die "Cannot open log file: $!";
        local $/;
        $logs = <$fh>;
        close $fh;
    }
    
    # Display logs using WHM template
    print "Content-type: text/html\r\n\r\n";
    Cpanel::Template::process_template(
        'whostmgr',
        {
            'template_file' => 'restic_backup_plugin/templates/logs.tmpl',
            'print' => 1,
            'data' => {
                'username' => $username,
                'logs' => $logs,
            },
        }
    );
    exit;
}
elsif ($action eq 'list_snapshots') {
    my $username = $query->param('username');
    my $snapshots = [];
    
    if ($username && $config->{repository}) {
        # Get snapshots for user
        my $output = `RESTIC_PASSWORD='$config->{password}' restic -r '$config->{repository}' snapshots --tag '$username' --json 2>/dev/null`;
        if ($output) {
            eval {
                $snapshots = decode_json($output);
            };
            if ($@) {
                print "Error decoding JSON: $@";
            }
        }
    }
    
    # Display snapshots using WHM template
    print "Content-type: text/html\r\n\r\n";
    Cpanel::Template::process_template(
        'whostmgr',
        {
            'template_file' => 'restic_backup_plugin/templates/snapshots.tmpl',
            'print' => 1,
            'data' => {
                'username' => $username,
                'snapshots' => $snapshots,
            },
        }
    );
    exit;
}

# Get list of cPanel accounts
my @accounts = ();
if (-f '/etc/trueuserdomains') {
    open my $fh, '<', '/etc/trueuserdomains' or die "Cannot open trueuserdomains: $!";
    while (my $line = <$fh>) {
        if ($line =~ /^([^:]+):\s*(\S+)/) {
            push @accounts, $2;
        }
    }
    close $fh;
}

# Display main admin interface using WHM template
print "Content-type: text/html\r\n\r\n";
Cpanel::Template::process_template(
    'whostmgr',
    {
        'template_file' => 'restic_backup_plugin/templates/admin.tmpl',
        'print' => 1,
        'data' => {
            'config' => $config,
            'accounts' => \@accounts,
        },
    }
);

exit;