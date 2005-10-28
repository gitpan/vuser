package VUser::email::driver;

# Copyright 2005 Michael O'Connor <stew@vireo.org>
# $Id: driver.pm,v 1.3 2005/10/28 04:27:30 perlstalker Exp $

use warnings;
use strict;

our $REVISION = (split (' ', '$Revision: 1.3 $'))[1];
our $VERSION = "0.2.0";

use Pod::Usage;

sub new
{
    my $class = shift;
    my %cfg = @_;

    my $self = { _dbh => undef, _conf =>undef };

    bless $self, $class;
    $self->init(%cfg);

    return $self;
}

sub init
{
    
}

sub cfg
{
    my $self = shift;
    my $option = shift;

    return $self->{_conf}{ $option };
}

