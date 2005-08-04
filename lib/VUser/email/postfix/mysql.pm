package VUser::email::postfix::mysql;

use warnings;
use strict;
use Pod::Usage;
use VUser::ExtLib qw( mkdir_p );

use vars qw(@ISA);

our $REVISION = (split (' ', '$Revision: 1.3 $'))[1];
our $VERSION = "0.1.0";

use VUser::email::authlib;
push @ISA, 'VUser::email::authlib';

sub new
{
    my $class = shift;
    my %cfg = @_;
    my $self = VUser::email::authlib::new( $class, $cfg{Extension_postfix_mysql} );

    return $self;
}

sub domain_add
{
    my $self = shift;
    my $domain = shift;
    my $domaindir = shift;

    die "unable to make domain directory: $domaindir\n"
	unless
	mkdir_p( $domaindir, 0775, (getpwnam($self->cfg("daemon_uid")))[2], (getpwnam($self->cfg("daemon_gid")))[2]  );

    my $sql = "INSERT INTO ". $self->cfg('transport_table')
			  . "(". $self->cfg( "domain_field" ) . ", " . $self->cfg( "transport_field" ) . ") VALUES(?,'maildrop')";

    my $sth = $self->{_dbh}->prepare($sql) or die "Can't insert domain: ".$self->{_dbh}->errstr()."\n";
    $sth->execute( $domain ) or die "Can't insert domain: ".$self->{_dbh}->errstr()."\n";
}

sub domain_exists
{
    my $self = shift;
    my $domain = shift;

    my $sql = "SELECT count(*) from ".$self->cfg('transport_table'). 
	" where ". $self->cfg( 'domain_field' ) ."=?";

    my $sth = $self->{_dbh}->prepare($sql) or die "Can't select domain: ".$self->{_dbh}->errstr()."\n";
    $sth->execute( $domain );
    return $sth->fetchrow_array();
}

1;
