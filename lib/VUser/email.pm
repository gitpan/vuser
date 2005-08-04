package VUser::email;

use warnings;
use strict;

# Copyright 2005 Michael O'Connor <stew@vireo.org>
# Copyright 2004 Randy Smith
# $Id: email.pm,v 1.3 2005/07/02 21:04:05 perlstalker Exp $

use vars qw(@ISA);

our $REVISION = (split (' ', '$Revision: 1.3 $'))[1];
our $VERSION = "0.1.0";

use VUser::ExtLib qw( mkdir_p );

use Pod::Usage;

use VUser::Extension;
push @ISA, 'VUser::Extension';

my $driver;

sub config_sample
{
    my $cfg = shift;
    my $opts = shift;

    my $fh;
    if (defined $opts->{file}) {
	open ($fh, ">".$opts->{file})
	    or die "Can't open '".$opts->{file}."': $!\n";
    } else {
	$fh = \*STDOUT;
    }

    print $fh <<'CONFIG';
[Extension_email]
# the location of the courier configuration
driver=courier

# stew's scheme
domaindir="/home/virtual/$domain"
userhomedir="/home/virtual/$domain/var/mail/$user"


# The location of the files which are copies into a brand new home dir
skeldir=/usr/local/etc/courier/skel

# Set to 1 to force user names to lower case
lc_user = 0

# the domain to use if the account doesn't have one
default domain=example.com

# Given $user and $domain, where will the user's home directory be located?
# This may be a valid perl expression.

# PerlStalker's scheme:
#domaindir="/var/mail/virtual/$domain"
#userhomedir="/var/mail/virtual/$domain/".substr($user, 0, 2)."/$user"

# stew's scheme:
domaindir="/home/virtual/$domain"
userhomedir="/home/virtual/$domain/var/mail/$user"

# which authentication system to use
# Only 'mysql' is supported currently.
driver=courier
list_prefix=list

CONFIG

    if (defined $opts->{file}) {
	close CONF;
    }
}

sub init
{
    my $eh = shift;
    my %cfg = @_;

    if ($cfg{Extension_email}{driver} =~ /courier/) {

	eval( "require VUser::email::courier;" );
	die $@ if $@;

	$driver = new VUser::email::courier(%cfg);
    } elsif ($cfg{Extension_email}{driver} =~ /postfix/) { 
	
	eval( "require VUser::email::postfix;" );
	die $@ if $@;

	$driver = new VUser::email::postfix(%cfg);

    } else {
	die "Unsupported email driver '$cfg{Extension_email}{driver}'\n";
    }

#     Config
    $eh->register_task('config', 'sample', \&config_sample);

#     email
    $eh->register_keyword('email');
    $eh->register_action('email', 'add');
    $eh->register_task('email', 'add', \&email_add, 0);
    $eh->register_option('email', 'add', 'account', '=s', "required" );

    $eh->register_action('email', 'del');
    $eh->register_task('email', 'del', \&email_del, 0);
    $eh->register_option('email', 'del', 'account', '=s', "required" );
    
    $eh->register_action('email', 'info');
    $eh->register_task('email', 'info', \&email_info, 0);
    $eh->register_option('email', 'info', 'account', '=s', "required" );

    $eh->register_action('email', 'adddomain');
    $eh->register_task('email', 'adddomain', \&domain_add, 0);
    $eh->register_option( 'email', 'adddomain', 'domain', '=s', 'required' );

    $eh->register_action('email', 'listdomains');
    $eh->register_task('email', 'listdomains', \&list_domains, 0);
}

sub get_home_directory
{
    my $cfg = shift;
    my $user = shift;
    my $domain = shift;

    return eval( $cfg->{Extension_email}{userhomedir} );
}
sub get_domain_directory
{
    my $cfg = shift;
    my $domain = shift;
    return eval( $cfg->{Extension_email}{domaindir} );
}

sub split_address
{
    my $cfg = shift;
    my $account = shift;
    my $username = shift;
    my $domain = shift;

    if ($account =~ /^(\S+)\@(\S+)$/) {
	$$username = $1;
	$$domain = $2;
    } else {
	$$username = $account;
 	$$domain = $cfg->{Extension_email}{defaultdomain};
	$$domain =~ s/^\s*(\S+)\s*/$1/;
    }
##    $$user = lc($$username) if 0+$cfg->{Extension_email}{'lc_user'};
    $$domain = lc($$domain);
}

sub domain_add
{
    my $cfg = shift;
    my $opts = shift;

    my $domain = $opts->{domain};

    die "domain already exists: $domain" if( $driver->domain_exists($domain) );

    $driver->domain_add( $domain, get_domain_directory( $cfg, $domain ) );
}

sub list_domains
{
    my $cfg = shift;
    my $opts = shift;

    my @domains = $driver->list_domains();

    print( join( "\n", @domains )."\n" );
}

sub email_info
{
    my $cfg = shift;
    my $opts = shift;

    my $account = $opts->{account};
    my $user = {};
    $driver->get_user_info( $account, $user );

    for my $key (keys(%$user))
    {
	if( $user->{$key} )
	{
	    print( "$key: " . $user->{$key}. "\n" );
	}
    }
}

sub email_add
{
    my $cfg = shift;
    my $opts = shift;

    # ... other stuff?

    my $account = $opts->{account};
    my $user;
    my $domain;
    
    split_address( $cfg, $account, \$user, \$domain );
    
    die "account must be in form user\@domain" if( !$user );
    die "account must be in form user\@domain" if( !$domain );

    die "Unable to add email: address exists\n" if ($driver->user_exists($account));

    my $userdir = get_home_directory( $cfg, $user, $domain );
    
    my $user_parentdir = $userdir;
    $user_parentdir =~ s/\/[^\/]*$//;

    if( not -e "$user_parentdir" )
    {
	mkdir_p( "$user_parentdir", 
		 0775, 
		 (getpwnam($cfg->{Extension_email}{courier_user}))[2],  		
		 (getgrnam($cfg->{Extension_email}{courier_group}))[2] )
	    || die "could not create user directory: $user_parentdir";
    }

    my $rc = 0xffff & system ('cp', '-R', $cfg->{Extension_email}{skeldir}, "$userdir");
    
    $rc <<= 8;
    die "Can't copy skel dir $cfg->{Extension_email}{skeldir} to $userdir: $!\n"
	if $rc != 0;
    system('chown', '-R', "$cfg->{Extension_email}{daemon_uid}:$cfg->{Extension_email}{daemon_gid}", "$userdir");

    $driver->add_user( $opts->{account},
		       $opts->{password},
		       get_home_directory( $cfg, $user, $domain ),
		       $opts->{name} );

}

sub email_del
{
    my $cfg = shift;
    my $opts = shift;

    # ... other stuff?

    my $account = $opts->{account};
    my $user;
    my $domain;
    
    split_address( $cfg, $account, \$user, \$domain );
    
    die "account must be in form user\@domain" if( !$user );
    die "account must be in form user\@domain" if( !$domain );

    my $userdir = get_home_directory( $cfg, $user, $domain );
    system ('rm', '-r', "$userdir");

    $driver->del_user( $opts->{$account} )

}

sub is_domain_hosted
{
    my $cfg = shift;
    my $domain = shift;

    my $hosteddomainsfile = $cfg->{Extension_email}{etc} . "/hosteddomains";
    
    open( HD, "<$hosteddomainsfile" ) || die "couldnt' open $hosteddomainsfile";
    while( <HD> )
    {
	if( /^$domain$/ )
	{
	    close( HD );
	    return 1;
	}
    }
    
    close( HD );
    return 0;
}

sub generate_password
{
    my $len = shift || 10;
    my @valid = (0..9, 'a'..'z', 'A'..'Z', '@', '#', '%', '^', '*');
    my $password = '';
    for (1 .. $len)
    {
        $password .= $valid[int (rand $#valid)];
    }
    return $password;
}

sub unload { }

1;

__END__

=head1 NAME

email - vuser email support extension

=head1 DESCRIPTION

=head1 AUTHOR

Mike O'Connor <stew@vireo.org>

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
