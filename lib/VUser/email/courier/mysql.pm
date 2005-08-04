package VUser::email::courier::mysql;

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
    my $self = VUser::email::authlib::new( $class, $cfg{Extension_courier_mysql} );

    return $self;
}

sub add_domain
{
    my $self = shift;
    my $domain = shift;
}

sub domain_exists
{
    my $self = shift;
    my $domain = shift;
}


sub list_domains
{
    my $self = shift;

    my $sql = "select " . $self->cfg( "domain_field" ) . " from ". $self->cfg('transport_table');
    my $sth = $self->{_dbh}->prepare($sql) or die "Can't list domains: ".$self->{_dbh}->errstr()."\n";
    $sth->execute( ) or die "Can't list domains: ".$self->{_dbh}->errstr()."\n";

    my @result;

    while( my $row = $sth->fetchrow_hashref() )
    {
	push( @result, $row->{ $self->cfg( "domain_field" )  } );
    }
    
    return @result;
}

1;
