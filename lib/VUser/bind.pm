package VUser::bind;

use warnings;
use strict;

# Copyright 2004 Mike O'Connor <stew@vireo.org>
# $Id: bind.pm,v 1.4 2005/10/28 04:27:29 perlstalker Exp $

use vars qw(@ISA);

our $REVISION = (split (' ', '$Revision: 1.4 $'))[1];
our $VERSION = "0.2.0";

use Pod::Usage;

use VUser::Extension;
push @ISA, 'VUser::Extension';

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
[Extension_bind]

namedconf=/tmp/named.conf
masterdir=/etc/bind/master
slavedir=/etc/bind/slave
internaldir=/etc/bind/internal
mastertemplate=/etc/bind/master/TEMPLATE
slavetemplate=/etc/bind/master/TEMPLATE
masterzonetemplate=/etc/bind/master/TEMPLATE

CONFIG

    if (defined $opts->{file}) {
	close CONF;
    }
}

sub init
{
    my $eh = shift;
    my %cfg = @_;

    # Config
    $eh->regiter_task('config', 'sample', \&config_sample);

    # email
    $eh->register_keyword('dns');
    
    $eh->register_action('dns', 'listdomains');
    $eh->register_task('dns', 'listdomains', \&dns_listdomains, 0);
    $eh->register_option('dns', 'listdomains', 'view', '=s');
    $eh->register_action('dns', 'listviews');
    $eh->register_task('dns', 'listviews', \&dns_listviews, 0);
    $eh->register_action('dns', 'show');
    $eh->register_task('dns', 'show', \&dns_show, 0);
}

sub dns_listdomains
{
    my $cfg = shift;
    my $opts = shift;

    my $view = $opts->{view};

    
    get_zones( $cfg, $view );
}

sub dns_listviews
{
    my $cfg = shift;
    my $opts = shift;

    get_views( $cfg );
}

sub dns_show
{
    my $cfg = shift;
    my $opts = shift;

    # ... other stuff?

    my $account = $opts->{account};
}

sub get_zones
{
    my $cfg = shift;
    my $v = shift;
	
    require VUser::bind::namedparser;

    my $namedfile = $cfg->{Extension_bind}{namedconf};

    foreach my $view ( VUser::bind::namedparser::parse( $namedfile ) )
    {
	if( $v )
	{
	    if( !($view->{name}) || (  !($v eq $view->{name} ) ))
	    {
		next;
	    }
	}
	my $zones = $view->{zones};
	foreach my $zone ( @$zones)
	{
	    print( $view->{name}.":".$zone->{name}."\n" );
	}
    }
}

sub get_views
{
    require VUser::bind::namedparser;

    my $cfg = shift;
    my $namedfile = $cfg->{Extension_bind}{namedconf};

    foreach my $zone ( VUser::bind::namedparser::parse( $namedfile ) )
    {
	print( $zone->{name }."\n" )
    }
}

