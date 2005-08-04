package VUser::bind::namedparser;

use warnings;
use strict;
    
sub parse
{
    my $namedfile = shift;

    local( $/, *NDC ) ;
    open( NDC, "<$namedfile" ) || die( "couldn't open $namedfile" );

    my @lines;

    while( <NDC> )
    {
	s/\/\/.*//g;
	s/\#.*//g;
	s/\/\*.*?\*\///mg;
	push( @lines, $_ ); 
    }

    my $string = join( '', @lines );

    my $pos = 0;
    my @statements;
    while( my $s = statement( $string, \$pos ) )
    {
	push( @statements, $s );
    }
    close( NDC );
    
    return @statements;
}

sub statement
{
    my $string = shift;
    my $pos = shift;
    
    return 
	view( $string, $pos ) ||
	zone( $string, $pos ) ||
	somestatement( $string, $pos ) ||
	0;
}

sub view
{
    my $string = shift;
    my $pos = shift;
    pos( $string ) = $$pos;
    
    if( $string =~ m/\G\s*view/sigc )
    {
	$$pos = pos( $string );
	
	my $result = { };
	
	my $name = quotedString( $string, $pos );
	my $class = quotedString( $string, $pos );

	$result->{ name } = $name;
	$result->{ class } = $class if( $class );
	my @zones;
	foreach my $s (statementBlock( $string, $pos ) )
	{
	    if( $s->{statement} && ($s->{statement} eq "zone" ) )
	    {
		push( @zones, $s );
	    }
	}
	$result->{ zones } = \@zones;

	pos( $string ) = $$pos;
	$string =~ m/\G\s*;/sgc;
	$$pos = pos( $string );
	
	return $result;
    }
    
}
sub zone
{
    my $string = shift;
    my $pos = shift;
    pos( $string ) = $$pos;
    
    if( $string =~ m/\G\s*zone/sigc )
    {
	$$pos = pos( $string );

	my $name = quotedString( $string, $pos );
	my $class = unquotedString( $string, $pos );
	
	pos( $string ) = $$pos;
	$string =~ m/\G\s*\{/sgc;
	$$pos = pos( $string );

	my $result = { statement => 'zone' };
	$result ->{name} = $name;
	$result ->{class} = $class if( $class );
	
#	print( "zone: $name\n" );
	
	while( 1 )
	{
	    if( my $t = type( $string, $pos ) )
	    {
		$result->{type}=$t;
	    }
	    elsif( my $masters = masters( $string, $pos ) )
	    {
		$result->{masters}=$masters;
	    }
	    elsif( my $file = file( $string, $pos ) )
	    {
		$result->{file}=$file;
	    }
	    elsif( my $s = somestatement( $string, $pos ) )
	    {
		next;
	    }
	    else
	    {
		last;
	    }
	}

	pos( $string ) = $$pos;
	$string =~ m/\G\s*\}\s*;/sgc;
	$$pos = pos( $string );
	return $result;
    }
}

sub type
{
    my $string = shift;
    my $pos = shift;
    pos( $string ) = $$pos;
    
    if( $string =~ m/\G\s*type\s*(\w+)\s*;/sigc )
    {
	my $type = $1;
	$$pos = pos( $string );
	return $type;
    }
}
sub masters
{
    my $string = shift;
    my $pos = shift;
    pos( $string ) = $$pos;
    
    if( $string =~ m/\G\s*masters/sigc )
    {
	$string =~ m/\G\s*\{/sgc;
	my @results;
	
	while( $string =~ m/\G\s*([^\s;]+)\s*;/sgc )
	{
	    push( @results, $1 );
	}
	
	$string =~ m/\G\s*\}\s*;/sgc;
	$$pos = pos( $string );
	
	return @results;
    }
}

sub file
{
    my $string = shift;
    my $pos = shift;
    pos( $string ) = $$pos;
    
    if( $string =~ m/\G\s*file/sigc )
    {
	$$pos = pos( $string );
	my $file = quotedString( $string, $pos );
	pos( $string ) = $$pos;
	$string =~ m/\G\s*;/sigc;
	$$pos = pos( $string );
	
	return $file;
    }
}

sub quotedString
{
    my $string = shift;
    my $pos = shift;
    pos( $string ) = $$pos;

    if( $string =~ m/\G\s*\"([^\"]*)\"/sigc )
    {
	$$pos = pos( $string );
	return $1;
    }
}

sub unquotedString
{
    my $string = shift;
    my $pos = shift;
    pos( $string ) = $$pos;

    if( $string =~ m/\G\s+([^\s]+)\s+/sigc )
    {
	$$pos = pos( $string );
	return $1;
    }
}
sub somestatement
{
    my $string = shift;
    my $pos = shift;
    pos( $string ) = $$pos;
    
    if( $string =~ m/\G\s*([a-zA-Z0-9\-]+)/sgc )
    {
	my $name = $1;

	$$pos = pos( $string );
	restOfStaement( $string, $pos );
	statementBlock( $string, $pos );

	pos( $string ) = $$pos;
	$string =~ m/\G;/sgc;
	$$pos = pos( $string );

	return {};
    }
}

sub statementBlock
{
    my $string = shift;
    my $pos = shift;
    pos( $string ) = $$pos;
    
    if( $string =~ m/\G\s*\{/sgc )
    {
	$$pos = pos( $string );
	
	my @statements;

	while( my $s = statement( $string, $pos ) )
	{
	    push( @statements, $s );
	}
	pos( $string ) = $$pos;
	$string =~ m/\G\s*\}/sgc;
	$$pos = pos( $string );
	
	return @statements;
    }
}


sub restOfStaement
{
    my $string = shift;
    my $pos = shift;
    pos( $string ) = $$pos;
    
    $string =~ m/\G[^\{;]*/sigc;
    $$pos = pos( $string );
}


1;
