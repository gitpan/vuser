package VUser::asterisk::mysql;
use warnings;
use strict;

# Copyright 2004 Randy Smith
# $Id: mysql.pm,v 1.3 2005/02/14 16:58:45 perlstalker Exp $

use DBI;

use lib('../..');
use VUser::ExtLib;

sub new
{
    my $class = shift;
    my $service = shift;
    my %cfg = @_;

    my $self = {_dbh => undef};

    bless $self, $class;
    $self->init($service, %cfg);

    return $self;
}

sub init
{
    my $self = shift;
    my $service = shift;
    my %cfg = @_;

    # Connect to DB here
    my $dsn = 'DBI:mysql:';
    $dsn .= 'database='.VUser::ExtLib::strip_ws($cfg{Extension_asterisk}{$service.'_dbname'});

    my $host = defined $cfg{Extension_asterisk}{$service.'_dbhost'} ?
	$cfg{Extension_asterisk}{$service.'_dbhost'} : 'localhost';
    $host = VUser::ExtLib::strip_ws($host);
    $dsn .= ";host=$host";

    my $port = defined $cfg{Extension_asterisk}{$service.'_dbport'} ?
	$cfg{Extension_asterisk}{$service.'_dbport'} : 3306;
    $dsn .= ";port=$port";
    
    my $user = defined $cfg{Extension_asterisk}{$service.'_dbuser'} ?
	$cfg{Extension_asterisk}{$service.'_dbuser'} : '';
    $user = VUser::ExtLib::strip_ws($user);

    my $pass = defined $cfg{Extension_asterisk}{$service.'_dbpass'} ?
	$cfg{Extension_asterisk}{$service.'_dbpass'} : '';
    $pass = VUser::ExtLib::strip_ws($pass);

    $self->{_dbh} = DBI->connect($dsn, $user, $pass);
    die "Unable to connect to database: ".DBI->errstr."\n" unless $self->{_dbh};
}

# Takes a hash with the following keys:
#  name username secret context ipaddr port regseconds callerid
#  restrictcid mailbox
sub sip_add
{
    my $self = shift;
    my %user = @_;

    my @fields = keys %user; # to keep keys in same order.

    my $sql = "insert into sipfriends set ";
    #$sql = join ', ', map { "$_ = ?"; } grep { defined $user{$_}; } @fields;
    $sql .= join ', ', map { "$_ = ?"; } @fields;

    my $sth = $self->{_dbh}->prepare($sql)
	or die "Can't add SIP user: ".$self->{_dbh}->errstr."\n";

    $sth->execute(@user{@fields})
	or die "Can't add SIP user: ".$self->{_dbh}->errstr."\n";

    $sth->finish;
}

# Takes a hash with the following keys:
#  name context
sub sip_del
{
    my $self = shift;
    my %user = @_;

    my $sql = 'delete from sipfriends where name = ? and context = ?';
    my $sth = $self->{_dbh}->prepare($sql)
	or die "Can't delete SIP user: ".$self->{_dbh}->errstr."\n";
    $sth->execute($user{name}, $user{context})
	or die "Can't delete SIP user: ".$self->{_dbh}->errstr."\n";

    $sth->finish;
}

# Takes a hash with the following keys:
#  name username secret context ipaddr port regseconds callerid
#  restrictcid mailbox newname newcontext
sub sip_mod
{
    my $self = shift;
    my %user = @_;

    my @fields = grep { ! /^new/; } keys %user; # to keep keys in same order.

    my $sql = "update sipfriends set ";
    $sql .= " name = ".$self->{_dbh}->quote($user{newname}? $user{newname}:$user{name});
    $sql .= ", context = ".$self->{_dbh}->quote($user{newcontext}? $user{newcontext}:$user{context});
    foreach my $opt qw(username secret ipaddr port regseconds callerid restrictcid mailbox) {
	$sql .= ", $opt = ".$self->{_dbh}->quote($user{$opt}) if defined $user{$opt};
    }
    $sql .= ' where name = ? and context = ?';

    my $sth = $self->{_dbh}->prepare($sql)
	or die "Can't change SIP user: ".$self->{_dbh}->errstr."\n";

    $sth->execute($user{name}, $user{context})
	or die "Can't change SIP user: ".$self->{_dbh}->errstr."\n";

    $sth->finish;
}

sub sip_exists
{ 
    my $self = shift;
    my $name = shift;
    my $context = shift;

    my $sql = 'select name, context from sipfriends where name = ? and context = ?';
    my $sth = $self->{_dbh}->prepare($sql)
	or die "Can't find SIP user: ".$self->{_dbh}->errstr."\n";

    $sth->execute($name, $context)
	or die "Can't find SIP user: ".$self->{_dbh}->errstr."\n";

    if ($sth->fetchrow) {
	return 1;
    } else {
	return 0;
    }
}

# $user and $context can take SQL wild cards
sub sip_get
{
    my $self = shift;
    my $user = shift;
    my $context = shift;

    my $sql = 'select * from sipfriends where name like ? and context like ? order by context, name';
    my $sth = $self->{_dbh}->prepare($sql)
	or die "Can't get SIP user: ".$self->{_dbh}->errstr."\n";

    $sth->execute ($user, $context)
	or die "Can't get SIP user: ".$sth->errstr."\n";

    my @users = ();
    my $res;
    while (defined ($res = $sth->fetchrow_hashref())) {
	push @users, $res;
    }

    $sth->finish;

    return @users;
}

# name, secret, context, ipaddr, port, regseconds (mailbox)
sub iax_add {}
sub iax_del {}
sub iax_mod {}
sub iax_exists { 1; }

# context, extension, priority, application, args, descr, flags
sub ext_add
{
    my $self = shift;
    my %ext = @_;

    my @fields = keys %ext; # to keep keys in same order.

    my $sql = "insert into extensions set ";
    $sql .= join ', ', map { "$_ = ?"; } @fields;

    my $sth = $self->{_dbh}->prepare($sql)
	or die "Can't add extension: ".$self->{_dbh}->errstr."\n";

    $sth->execute(@ext{@fields})
	or die "Can't add extension: ".$self->{_dbh}->errstr."\n";

    $sth->finish;
}

sub ext_del
{
    my $self = shift;
    my %ext = @_;

    my $sql = "delete from extensions where extension = ? and context = ? and priority = ?";

    my $sth = $self->{_dbh}->prepare($sql)
	or die "Can't delete extension: ".$self->{_dbh}->errstr."\n";

    $sth->execute($ext{extension}, $ext{context}, $ext{priority})
	or die "Can't delete extension: ".$self->{_dbh}->errstr."\n";

    $sth->finish;
}

sub ext_mod
{
    my $self = shift;
    my %ext = @_;

    my @fields = grep { ! /^new/; } keys %ext; # to keep keys in same order.

    my $sql = "update extensions set ";
    $sql .= " extension = ".$self->{_dbh}->quote($ext{newextension}? $ext{newextension}:$ext{extension});
    $sql .= ", context = ".$self->{_dbh}->quote($ext{newcontext}? $ext{newcontext}:$ext{context});
    $sql .= ", priority = ".$self->{_dbh}->quote($ext{newpriority}? $ext{newpriority}:$ext{priority});

    foreach my $opt qw(application args descr flags) {
	$sql .= ", $opt = ".$self->{_dbh}->quote($ext{$opt}) if defined $ext{$opt};
    }
    $sql .= ' where extension = ? and context = ? and priority = ?';

    my $sth = $self->{_dbh}->prepare($sql)
	or die "Can't change extension: ".$self->{_dbh}->errstr."\n";

    $sth->execute($ext{extension}, $ext{context}, $ext{priority})
	or die "Can't change extension: ".$self->{_dbh}->errstr."\n";

    $sth->finish;
}

sub ext_exists
{
    my $self = shift;
    my $ext = shift;
    my $context = shift;
    my $priority = shift;

    my $sql = 'select extension, context, priority from extensions where extension = ? and context = ? and priority = ?';
    my $sth = $self->{_dbh}->prepare($sql)
	or die "Can't find extension: ".$self->{_dbh}->errstr."\n";

    $sth->execute($ext, $context, $priority)
	or die "Can't find extension: ".$self->{_dbh}->errstr."\n";

    if ($sth->fetchrow) {
	return 1;
    } else {
	return 0;
    }
    1;
}

sub ext_get
{
    my $self = shift;
    my $ext = shift;
    my $context = shift;
    my $priority = shift;

    my $sql = 'select * from extensions where extension like ? and context like ? and priority like ? order by context,extension,priority';
    my $sth = $self->{_dbh}->prepare($sql)
	or die "Can't get extension: ".$self->{_dbh}->errstr."\n";

    $sth->execute ($ext, $context, $priority)
	or die "Can't get extension: ".$sth->errstr."\n";

    my @exts = ();
    my $res;
    while (defined ($res = $sth->fetchrow_hashref())) {
	push @exts, $res;
    }

    $sth->finish;

    return @exts;
}

sub vm_add
{
    my $self = shift;
    my %box = @_;

    my @fields = keys %box;

    my $sql = "insert into users set ";
    $sql .= join ', ', map { "$_ = ?"; } @fields;

    my $sth = $self->{_dbh}->prepare($sql)
	or die "Can't add voice mail box: ".$self->{_dbh}->errstr."\n";

    $sth->execute(@box{@fields})
	or die "Can't add voice mail box: ".$self->{_dbh}->errstr."\n";

    $sth->finish;
}

sub vm_del
{
    my $self = shift;
    my %box = @_;

    my $sql = "delete from users where mailbox = ? and context = ?";

    my $sth = $self->{_dbh}->prepare($sql)
	or die "Can't delete voice mail box: ".$self->{_dbh}->errstr."\n";

    $sth->execute($box{mailbox}, $box{context})
	or die "Can't delete voice mail box: ".$self->{_dbh}->errstr."\n";

    $sth->finish;

}

sub vm_mod
{
    my $self = shift;
    my %box = @_;

    my @fields = grep { ! /^new/; } keys %box; # to keep keys in same order.

    my $sql = "update users set ";

    $sql .= " mailbox = ".$self->{_dbh}->quote($box{newmailbox}?$box{newmailbox}:$box{mailbox});
    $sql .= ", context = ".$self->{_dbh}->quote($box{newcontext}?$box{newcontext}:$box{context});

    foreach my $opt qw(password fullname email pager options) {
	$sql .= ", $opt = ".$self->{_dbh}->quote($box{$opt}) if defined $box{$opt};
    }

    $sql .= ' where mailbox = ? and context = ?';

    my $sth = $self->{_dbh}->prepare($sql)
	or die "Can't change VM box: ".$self->{_dbh}->errstr."\n";

    $sth->execute($box{mailbox}, $box{context})
	or die "Can't change VM box: ".$self->{_dbh}->errstr."\n";

    $sth->finish;
}

sub vm_exists
{
    my $self = shift;
    my $box = shift;
    my $context = shift;

    my $sql = 'select mailbox, context from users where mailbox = ? and context = ? order by context, mailbox';

    my $sth = $self->{_dbh}->prepare($sql)
	or die "Can't find voice mail box: ".$self->{_dbh}->errstr."\n";

    $sth->execute($box, $context)
	or die "Can't find voice mail box: ".$self->{_dbh}->errstr."\n";

    if ($sth->fetchrow) {
	return 1;
    } else {
	return 0;
    }
    1;
}

sub vm_get
{
    my $self = shift;
    my $box = shift;
    my $context = shift;

    my $sql = 'select * from users where mailbox like ? and context like ?';
    my $sth = $self->{_dbh}->prepare($sql)
	or die "Can't get voice mail box: ".$self->{_dbh}->errstr."\n";

    $sth->execute ($box, $context)
	or die "Can't get voice mail box: ".$sth->errstr."\n";

    my @boxes = ();
    my $res;
    while (defined ($res = $sth->fetchrow_hashref())) {
	push @boxes, $res;
    }

    $sth->finish;

    return @boxes;
}

1;

__END__

=head1 NAME

asterisk::mysql - asterisk mysql support

=head1 DESCRIPTION

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
