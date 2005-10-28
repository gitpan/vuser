#!/usr/bin/perl
use warnings;
use strict;

# Copyright 2005 Randy Smith
# $Id: vsoapc.cgi,v 1.7 2005/10/28 04:27:29 perlstalker Exp $

# Called as:
#  vsoapc.cgi/keyword/action/
#  vsoapc.cgi/keyword/
#  vsoapc.cgi

use Config::IniFiles;
use Text::Template;
use SOAP::Lite on_fault => \&soap_error;
use FindBin;
use CGI;
use CGI::Carp qw/fatalsToBrowser/;

our $REVISION = (split (' ', '$Revision: 1.7 $'))[1];
our $VERSION = "0.2.0";

my $title = "vuser $VERSION - $REVISION";

our $DEBUG = 0;

BEGIN {

    our @etc_dirs = ('/usr/local/etc',
		     '/usr/local/etc/vuser',
		     '/etc',
		     '/etc/vuser',
		     "$FindBin::Bin/../etc",
		     "$FindBin::Bin",
		     "$FindBin::Bin/../",
                     "$FindBin::Bin/vuser",
                     "$FindBin::Bin/../etc/vuser"
                     );
}

use vars qw(@etc_dirs);

use lib (map { "$_/extensions" } @etc_dirs);
use lib (map { "$_/lib" } @etc_dirs);

use VUser::ExtLib;
use VUser::Widget;
use VUser::Meta;

my $config_file;
for my $etc_dir (@etc_dirs)
{
    if (-e "$etc_dir/vuser.conf") {
	$config_file = "$etc_dir/vuser.conf";
	last;
    }
}

if (not defined $config_file) {
    die "Unable to find a vuser.conf file in ".join (", ", @etc_dirs).".\n";
}

my %cfg;
tie %cfg, 'Config::IniFiles', (-file => $config_file);

my $template_dir = VUser::ExtLib::strip_ws($cfg{'vsoapc.cgi'}{'template dir'});
$template_dir = "$FindBin::Bin/templates" unless $template_dir;

my $session_dir = VUser::ExtLib::strip_ws($cfg{'vsoapc.cgi'}{'session dir'});
$session_dir = "$FindBin::Bin/sessions" unless $session_dir;

my $vuser_host = VUser::ExtLib::strip_ws($cfg{'vsoapc.cgi'}{'vsoap host'});
$vuser_host = 'http://localhost:8080/' unless $vuser_host;
$vuser_host .= '/' unless $vuser_host =~ m|/$|;

$DEBUG = VUser::ExtLib::strip_ws($cfg{'vuser'}{'debug'}) || 0;

my $q = new CGI;

# Commands:
#  Login
#  get actions
#  get options
#  do action
#  logout
my $cmd = $q->param('cmd') || '';

my $path_info = $q->path_info();
# $other should never be defined but I want to be sure that I can easily
# get $keyword and $action if someone does something stupid.
my ($null, $keyword, $action, $other) = split '/', $path_info;

if (not defined $keyword and $q->param('keyword')) {
    $keyword = $q->param('keyword');
}

if (not defined $action and $q->param('action')) {
    $action = $q->param('action');
}

# URL of this script. Suitable for use in <form action="$url">
my $url = $q->url('-path');
my $full_url = $q->url('-path' => 1, '-full' => 1);

#my $session = $q->param('session');
my $session = $q->cookie(-name => 'session');
$session = $q->param('session') unless $session;

if (not $session) {
    $session = VUser::ExtLib::generate_password(20, 'a' .. 'z',
						'A' .. 'Z',
						0 .. 9);
}

my $ses_cookie = $q->cookie(-name => 'session',
			    -value => $session,
			    -expires => '+1h',
			    );

print $q->header(-cookie => $ses_cookie);

my %sess = ();
if (not defined $session
    or not -e "$session_dir/$session") {
    # No session. User must log in again.
    exit unless login_page();
} elsif ($q->param('logout')) {
    logout();
} else {
    if (open (SESS, "$session_dir/$session")) {
	$sess{'ip'} = <SESS>;
	$sess{'user'} = <SESS>;
	$sess{'pass'} = <SESS>;
	close SESS;
	chomp @sess{qw(ip user pass)};
    } else {
	exit unless login_page("Unable to get session data: $!");
    }
}

#print "You are here. $keyword - $action ($path_info)";

# I should simplify this if.
if (not $keyword) {
    choose_keyword();
} elsif (not $action) {
    choose_keyword();
} else {
    #huh();
    run_tasks();
}

sub huh
{
    print $q->start_html;
    print $q->p("How did we get here? Key: $keyword, Act: $action ($path_info)");
    print $q->end_html;
}

sub login_page
{
    my $message = shift || '';

    my $user;
    if ($cmd eq 'Login') {
	$user = VUser::ExtLib::strip_ws($q->param('user'));
	my $pass = $q->param('password'); # password may start/end with ws
	my $ip = $ENV{REMOTE_ADDR};
	if ($user and $pass
	    and SOAP::Lite
	    -> uri($vuser_host.'VUser/SOAP')
	    -> proxy($vuser_host)
	    -> authenticate($user, $pass, $ip)
	    -> result) {
#	    $session = VUser::ExtLib::generate_password(20, 'a' .. 'z',
#	    						'A' .. 'Z',
#							0 .. 9);
	    $q->param('session', $session);
	    if (open (SESS, ">$session_dir/$session")) {
		print SESS "$ip\n";
		print SESS "$user\n";
		print SESS "$pass\n";
		close SESS;
		return 1;
	    } else {
		$message = 'Unable to write session data: $!';
	    }
	} else {
	    $message = 'Bad user name or password.';
	}
    }
    # Show the login page
    my $args = {user => $user,
		title => "Please log in - $title",
		url => $full_url,
		session => $session
		};

    my $template = Text::Template->new (TYPE => 'FILE',
					SOURCE => "$template_dir/login.html",
					DELIMITERS => ['{', '}']
					)
	or die "Template error: $Text::Template::ERROR";
    $template->fill_in(OUTPUT => \*STDOUT,
		       HASH => $args
		       )
	or die "Template error: $Text::Template::ERROR";
    return 0;
}

sub choose_keyword
{
    my $args = {user => $sess{user},
		title => "Choose keyword - $title",
		url => $url,
		session => $session
		};

    if ($keyword) {
	$args->{keyword} = $keyword;
	my $actions = SOAP::Lite
	    -> uri ($vuser_host.'VUser/SOAP')
	    -> proxy ($vuser_host)
	    -> get_actions ($sess{user}, $sess{pass}, $sess{ip}, $keyword)
	    -> result;
	$args->{actions} = $actions;

    } else {
	my $keywords = SOAP::Lite
	    -> uri($vuser_host.'VUser/SOAP')
	    -> proxy($vuser_host)
	    -> get_keywords ($sess{user}, $sess{pass})
	    -> result;

	$args->{keywords} = $keywords;
    }

    my $template = Text::Template->new (TYPE => 'FILE',
					SOURCE => "$template_dir/choose.html",
					DELIMITERS => ['{', '}']
					)
	or die "Template error: $Text::Template::ERROR";    $template->fill_in(OUTPUT => \*STDOUT,
		       HASH => $args
		       );
}

sub run_tasks
{
    my $options = SOAP::Lite
	-> uri ($vuser_host.'VUser/SOAP')
	-> proxy ($vuser_host)
	-> get_options ($sess{user}, $sess{pass}, $sess{ip},
			$keyword, $action)
	-> result;

    my @meta = ();
    foreach my $opt (@$options) {
	my $meta = SOAP::Lite
	    -> uri ($vuser_host.'VUser/SOAP')
	    -> proxy ($vuser_host)
	    -> get_meta ($sess{user}, $sess{pass}, $sess{ip},
			 $keyword, $opt->{option})
	    -> result;
	push @meta, $meta->[0] if defined $meta->[0];
    }

    my $args = {user => $sess{user},
		title => "$keyword | $action - $title",
		url => $url,
		session => $session,
		keyword => $keyword,
		action => $action,
		message => ''
		};

    $args->{meta} = \@meta;

    if ($q->param('cmd') eq 'do action') {
	$args->{message} = 'Action successful.';
	my %opts = ();
	foreach my $opt (@$options) {
	    if (defined ($q->param($opt->{option}))) {
		$opts{$opt->{option}} = $q->param($opt->{option});
	    }
	}

	my $rs = SOAP::Lite
	    -> uri ($vuser_host.'VUser/SOAP')
	    -> proxy ($vuser_host)
	    -> run_tasks($sess{user}, $sess{pass}, $sess{ip},
			 $keyword, $action, %opts)
	    -> result;

	$args->{rs} = $rs;
    }

    my $template = Text::Template->new (TYPE => 'FILE',
					SOURCE => "$template_dir/tasks.html",
					DELIMITERS => ['{', '}']
					)
	or die "Template error: $Text::Template::ERROR";
    $template->fill_in(OUTPUT => \*STDOUT, HASH => $args);
}

sub logout
{
    unlink ("$session_dir/$session") or die "Can't remove session.\n";
    login_page("You have been logged out.");
}

sub soap_error
{
    my ($soap, $res) = @_;

    error_page(ref $res ? $res->faultstring : $soap->transport->status);
}

sub error_page
{
    my $error = shift;

    my $args = {error => $error,
		title => "Error - $title"
		};

    my $template = Text::Template->new (TYPE => 'FILE',
					SOURCE => "$template_dir/error.html",
					DELIMITER => ['{', '}']
					)
	or die "Template error: $Text::Template::ERROR";
    $template->fill_in(OUTPUT => \*STDOUT, HASH => $args);
    exit;
}

__END__

=head1 NAME

vsoapc.cgi - Web interface for vuser that uses vsoapd.

=head1 SYNOPSIS

=head1 OPTIONS

=head1 DESCRIPTION

=head1 BUGS

=head1 SEE ALSO

=head1 AUTHOR

Randy Smith <perlstalker@gmail.com>

=head1 LICENSE
 
 This file is part of vuser.
 
 vuser is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 
 vuser is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with vuser; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

=cut
