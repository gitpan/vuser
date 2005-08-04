package VUser::Test;
use warnings;
use strict;

# Copyright 2004 Randy Smith
# $Id: Test.pm,v 1.2 2005/07/02 21:04:04 perlstalker Exp $

our $REVISION = (split (' ', '$Revision: 1.2 $'))[1];
our $VERSION = "0.1.0";

use vars qw(@ISA);
use VUser::Extension;
push @ISA, 'VUser::Extension';

sub revision
{
    my $self = shift;
    my $type = ref($self) || $self;
    no strict 'refs';
    return ${$type."::REVISION"};
}

sub version
{
    my $self = shift;
    my $type = ref($self) || $self;
    no strict 'refs';
    return ${$type."::VERSION"};
}

sub init
{
    my $eh = shift;
    my %cfg = @_;

    my %meta = ('foo', VUser::Meta->new(name => 'foo',
					description => 'Random option',
					type => 'string')
		);

    $eh->register_keyword('test', 'Test keyword. Don\'t use in production.');

    $eh->register_action('test', '*');
    $eh->register_option('test', '*', $meta{foo});
    $eh->register_task('test', '*', \&test_task);

    $eh->register_action('test', 'meta', 'Dump meta data');
    $eh->register_option('test', 'meta', $meta{foo});
    $eh->register_option('test', 'meta', VUser::Meta->new(name => 'keyword',
							  description => "See meta data for this keyword",
							  type => 'string'));
    $eh->register_task('test', 'meta', \&dump_meta);
}

sub unload { return; }

sub test_task
{
    my ($cfg, $opts, $action, $eh) = @_;

    print "This is only a test. action $action\n";
    use Data::Dumper; print Dumper $opts;
}

sub dump_meta
{
    my ($cfg, $opts, $action, $eh) = @_;

    my $key = $opts->{keyword} || 'test';
    
    print "Dumping meta data for keyword '$key':\n";

    my @meta = $eh->get_meta($key);
    use Data::Dumper; print Dumper \@meta;
}

1;

__END__

=head1 NAME

VUser::Test - A test extension.

=head1 DESCRIPTION

=head1 METHODS

=head2 init

Called when an extension is loaded when vuser starts.

init() will be passed an reference to an ExtHandler object which may be
used to register keywords, actions, etc. and the tied config object.

=head2 unload

Called when an extension is unloaded when vuser exits.

=head2 revision

Returns the extension's revision. This is may return an empty string;

=head2 version

Returns the extensions official version. This man not return an empty string.

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
