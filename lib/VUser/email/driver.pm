package VUser::email::driver;

# Copyright 2005 Michael O'Connor <stew@vireo.org>
# $Id: driver.pm,v 1.2 2005/07/02 21:04:06 perlstalker Exp $

use warnings;
use strict;

our $REVISION = (split (' ', '$Revision: 1.2 $'))[1];
our $VERSION = "0.1.0";

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

