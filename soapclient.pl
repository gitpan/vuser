#! /usr/bin/perl
use warnings;
use strict;

#use SOAP::Lite;

# Didn't work when I called a non-existant method.  Not sure why.
use SOAP::Lite 
#    on_fault => sub { die join ' ', @_; };
    on_fault => sub { my( $soap, $res ) = @_; die ref $res ? $res->faultstring : $soap->transport->status, "\n" };

# Connect to CGI server
# Doesn't handle errors.  If a fault occurs, it just prints empty string.
#print SOAP::Lite
#  -> uri( 'http://localhost/VUserSOAP/' )
#  -> proxy( 'http://localhost/soapdemo/soapcgi.pl' )
#  -> hi()
#  -> result;

# Connect to Daemon
# Doesn't handle errors.  If a fault occurs, it just prints empty string.
print SOAP::Lite
  -> uri( 'http://localhost:8001/VUser/SOAP' )
  -> proxy( 'http://localhost:8001/' )
  -> version()
  -> result;

print "\n";

my $data = SOAP::Lite
  -> uri( 'http://localhost:8001/VUser/SOAP' )
  -> proxy( 'http://localhost:8001/' )
  -> get_data('', '', 'VUser::Activation', 'soap_get_cust',
	      {customerid => '123456'})
  -> result;

#use Data::Dumper; print Dumper $data;

my $login = SOAP::Lite
    -> uri( 'http://localhost:8001/VUser/SOAP' )
    -> proxy( 'http://localhost:8001/' )
    -> authenticate('randys', 'foo')
    -> result;

print "Login: ($login) ";
if ($login) {
    print " Successful";
} else {
    print " Failed";
}
print "\n";
