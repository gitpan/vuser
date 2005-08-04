package VUser::email::postfix;

# Copyright 2005 Michael O'Connor <stew@vireo.org>
# $Id: postfix.pm,v 1.2 2005/07/02 21:04:06 perlstalker Exp $

use warnings;
use strict;
use Pod::Usage;

use vars qw(@ISA);

our $REVISION = (split (' ', '$Revision: 1.2 $'))[1];
our $VERSION = "0.1.0";

use VUser::email::authlib;
use VUser::email::driver;
push @ISA, 'VUser::email::driver';

sub new
{
    my $class = shift;
    my %cfg = @_;

    my $self = { _conf => undef, _authlib => undef };

    bless $self, $class;
    $self->init(%cfg);

    return $self;
}

sub init
{
    my $self = shift;
    my %cfg = @_;
    $self->{_conf} = $cfg{Extension_postfix};

    my $whichauthlib = $self->cfg( "authlib" );
    
    die "required option \"authlib\" unset for Extension_postfix.  Please fix your vuser.conf" unless $whichauthlib;
    
    if( $whichauthlib =~ /mysql/ )
    {
	use VUser::email::postfix::mysql;
	eval( "require VUser::email::postfix::mysql;" );
	die $@ if $@;
	$self->{_authlib} = new VUser::email::postfix::mysql(%cfg);
    }
    else
    {
	die "unsupported authlib for Extension_postfix"
    }
}

sub cfg
{
    my $self = shift;
    my $option = shift;

    return $self->{_conf}{ $option };
}

sub list_domains
{
    my $self = shift;
    
    return $self->{_authlib}->list_domains();
}

sub domain_exists
{
    my $self = shift;
    my $domain = shift;
    
    return $self->{_authlib}->domain_exists( $domain );
}

sub user_exists
{
    my $self = shift;
    my $user = shift;

    return $self->{_authlib}->user_exists( $user );
}

sub get_user_info
{
    my $self = shift;
    my $account = shift;
    my $user = shift;
    
    $self->{_authlib}->get_user_info( $account, $user );
}

sub domain_add
{
    my $self = shift;
    my $domain = shift;
    my $domaindir = shift;
    
    return $self->{_authlib}->domain_add( $domain, $domaindir );
}

sub add_user
{
    my $self = shift;
    my $account = shift;
    my $password = shift;
    my $userdir = shift;
    my $name = shift || '';
    

    $self->{_authlib}->add_user( $account, $password, $userdir, $name );
}