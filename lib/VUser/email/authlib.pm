package VUser::email::authlib;

use DBI;
use warnings;
use strict;

sub new
{
    my $class = shift;
    my $cfg = shift;

    my $self = { _dbh => undef, _conf => $cfg };

    bless $self, $class;
    $self->init();

    return $self;
}

sub init
{
    my $self = shift;

    my $connStr = "DBI:mysql:";
    $connStr .= $self->cfg( 'database' ) . ":";
    $connStr .= $self->cfg( 'server' ) . ":";
    $connStr .= $self->cfg( 'port' );
    
    $self->{_dbh} = DBI->connect( $connStr, $self->cfg('username'), $self->cfg('password') );
}

sub cfg
{
    my $self = shift;
    my $option = shift;

    return $self->{_conf}{ $option };
}

sub user_exists
{
    my $self = shift;
    my $user = shift;

    my $sql = "SELECT count(*)" .
	" from ".$self->cfg('user_table'). 
	" where ". $self->cfg( 'login_field' ) ."=?";

    my $sth = $self->{_dbh}->prepare($sql) or die "Can't add account: ".$self->{_dbh}->errstr()."\n";
    $sth->execute( $user );
    return $sth->fetchrow_array();
}

# # Add user to DB
sub add_user
{
    my $self = shift;
    my $account = shift;
    my $password = shift;
    my $userdir = shift;
    my $name = shift || '';
    
    my $sql = "INSERT into ".$self->cfg( 'user_table' )." set ";

    $sql .= "  ". $self->cfg( 'login_field' ) ." = " . $self->{_dbh}->quote($account);
    $sql .= ", ". $self->cfg( 'uid_field' ) ." = " . $self->{_dbh}->quote($self->cfg('daemon_uid'));
    $sql .= ", ". $self->cfg( 'gid_field' ) ." = " . $self->{_dbh}->quote($self->cfg('daemon_gid'));
    $sql .= ", ". $self->cfg( 'crypt_pwfield' ) ." = " . $self->{_dbh}->quote(crypt($password, $password)) if $self->cfg('CRYPT_PWFIELD');
    $sql .= ", ". $self->cfg( 'clear_pwfield' ) ." = " . $self->{_dbh}->quote($password) if $self->cfg('CLEAR_PWFIELD');
    $sql .= ", ". $self->cfg( 'home_field' ) ." = " . $self->{_dbh}->quote("$userdir");
    $sql .= ", ". $self->cfg( 'name_field' ) ." = " . $self->{_dbh}->quote($name);
    $sql .= ", ". $self->cfg( 'quota_field' ) ." = " . $self->{_dbh}->quote($self->cfg( 'quota' ));
    $sql .= ";";

    $self->{_dbh}->do($sql) or die "Can't add account: ".$self->{_dbh}->errstr()."\n";
}

# # Modify user in the DB
# sub mod_user
# {
# }

#Delete user from DB
sub del_user
{
    my $self = shift;
    my $account = $self->{_dbh}->quote(shift);
    
    $self->{_dbh}->do( "DELETE from ".$self->cfg( 'user_table' ). " where ".$self->cfg( 'login_field' )."=$account;" )
	or die "Can't delete account: ".$self->{_dbh}->errstr()."\n";
}

#
# returns a hashref of the data for a particular user
# 
sub get_user_info
{
    my $self = shift;
    my $account = $self->{_dbh}->quote(shift);
    my $user = shift;

    my $sql = "select * from ".$self->cfg( 'user_table' ). " where ".$self->cfg( 'login_field' )."=$account;";

    print( "$sql\n" );

    my $sth = $self->{_dbh}->prepare( $sql )
	or die "Can't select account: ".$self->{_dbh}->errstr()."\n";

    $sth->execute() or die "Can't select account: ".$self->{_dbh}->errstr()."\n";

    if( my $uservals = $sth->fetchrow_hashref() )
    {
	$self->get_user_from_row( $uservals, $user )
    }

}

sub get_user_by_homedir
{
    my $self = shift;
    my $account = shift;
    my $user = shift;

    $account =~ s/\/?$//;
    my $account2 = $account."/";

    $account = $self->{_dbh}->quote($account);
    $account2 = $self->{_dbh}->quote($account2);

    my $sth = $self->{_dbh}->prepare( "select * from ".$self->cfg( 'user_table' ). " where " .
				      $self->cfg( 'home_field' )."=$account or " .
				      $self->cfg( 'home_field' )."=$account2;" )
	or die "Can't select account: ".$self->{_dbh}->errstr()."\n";

    
    $sth->execute() or die "Can't select account: ".$self->{_dbh}->errstr()."\n";

    if( my $uservals = $sth->fetchrow_hashref() )
    {
	$self->get_user_from_row( $uservals, $user )
    }
}

sub get_user_from_row
{
    my $self = shift;
    my $row = shift;
    my $user = shift;

    $user->{ id } = $row->{ $self->cfg( 'login_field' ) };
    $user->{ home } = $row->{ $self->cfg( 'home_field' ) };
    $user->{ maildir } = $row->{ $self->cfg( 'maildir_field' ) } if( $self->cfg( 'clear_field' ) );
    $user->{ clear } = $row->{ $self->cfg( 'clear_field' ) } if( $self->cfg( 'clear_field' ) );
    $user->{ crypt } = $row->{ $self->cfg( 'crypt_field' ) } if( $self->cfg( 'crypt_field' ) );
    $user->{ quota } = $row->{ $self->cfg( 'quota_field' ) };
    $user->{ aliasfor } = $row->{ $self->cfg( 'alias_field' ) };
    $user->{ uid } = $row->{ $self->cfg( 'uid_field' ) };
    $user->{ gid } = $row->{ $self->cfg( 'gid_field' ) };
}


1;

__END__

=head1 NAME

courier::mysql - MySQL backend for courier extension.

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
