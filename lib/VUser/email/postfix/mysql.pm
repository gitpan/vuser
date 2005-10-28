package VUser::email::postfix::mysql;

use warnings;
use strict;
use Pod::Usage;
use VUser::ExtLib qw( mkdir_p rm_r );

use vars qw(@ISA);

our $REVISION = (split (' ', '$Revision: 1.6 $'))[1];
our $VERSION = "0.2.0";

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
	mkdir_p( $domaindir, 0775, $self->cfg("daemon_uid"),
		 $self->cfg("daemon_gid"));

    my $sql = "INSERT INTO ". $self->cfg('transport_table')
			  . "(". $self->cfg( "domain_field" ) . ", " . $self->cfg( "transport_field" ) . ") VALUES(?,'maildrop')";

    my $sth = $self->{_dbh}->prepare($sql) or die "Can't insert domain: ".$self->{_dbh}->errstr()."\n";
    $sth->execute( $domain ) or die "Can't insert domain: ".$sth->errstr()."\n";
}

sub list_domains
{
    my $self = shift;

    my $sql = sprintf("SELECT %s from %s",
		      $self->cfg('domain_field'),
		      $self->cfg('transport_table')
		      );

    my @domains = ();

    my $sth = $self->{_dbh}->prepare( $sql )
	or die "Can't select account: ".$self->{_dbh}->errstr()."\n";

    $sth->execute() or die "Can't select account: ".$self->{_dbh}->errstr()."\n";

    my $res;
    while (defined ($res = $sth->fetchrow_hashref)) {
	push @domains, $res->{$self->cfg('domain_field')};
    }

    return @domains;
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

sub domain_del
{
    my $self = shift;
    my $domain = shift;
    my $domaindir = shift;

    my $sql = "DELETE from ".$self->cfg('transport_table')
	.' WHERE '.$self->cfg('domain_field').' = ?';
    my $sth = $self->{_dbh}->prepare($sql)
	or die "Can't delete domain: $domain: ".$self->{_dbh}->errstr()."\n";
    $sth->execute($domain)
	or die "Can't delete domain: $domain: ".$sth->errstr()."\n";

    die "Unable to delete the domain directory: $domaindir\n"
	unless rm_r($domaindir);
}

1;
