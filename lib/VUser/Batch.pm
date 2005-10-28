package VUser::Batch;
use warnings;
use strict;

# Copyright 2004 Randy Smith
# $Id: Batch.pm,v 1.2 2005/10/28 04:27:29 perlstalker Exp $

use vars qw(@ISA);

our $REVISION = (split (' ', '$Revision: 1.2 $'))[1];
our $VERSION = "0.2.0";

use Pod::Usage;

use VUser::Extension;
push @ISA, 'VUser::Extension';

sub config_file
{
    my $cfg = shift;
    my $opts = shift;

    print ("Current config file: ", tied (%$cfg)->GetFileName, "\n");
}


sub config_sample
{
    my $cfg = shift;
    my $opts = shift;

    my $fh;
    if (defined $opts->{file}) {
	open ($fh, ">".$opts->{file})
	    or die "Can't open '".$opts->{file}."': $!\n";
    } else {
	$fh = \*STDOUT;
    }

    print $fh <<'CONFIG';
[vuser]
# To enable batch mode
extensions = Batch

CONFIG

    if (defined $opts->{file}) {
	close $fh;
    }
}

sub version
{
    my $cfg = shift;
    my $opts = shift;

    print ("Version: $VERSION\n");
    return $VERSION;
}

sub revision
{
    my $cfg = shift;
    my $opts = shift;

    print ("Revision: $main::REVISION\n");
    return $REVISION;
}

sub init
{
    my $eh = shift; # ExtHandler
    my %cfg = @_;


    # Batch
    $eh->register_keyword('batch', 'Run in batch mode.');
    $eh->register_action('batch', '*', '');
    $eh->register_option('batch', '*', 'flag', '=s', 0, 'touch this file when finished with the batch.');
    $eh->register_task('batch', '*', \&batch_mode); 

}

sub process_event_dir
{
    my $cfg = shift;
    my $opts = shift;
    my $eh = shift;
    my $dir = shift;

    opendir DIR, $dir or die "Unable to open $dir: $!\n";
    my @files = grep { ! (/^\.\.?$/
			  or /^error-/
			  or /^new-/
			  )
		      } readdir DIR;
    closedir DIR;

    foreach my $file (sort {
	my @astat = stat("$dir/$a");
	my @bstat = stat("$dir/$b");
	$astat[9] <=> $bstat[9]; # Sort on mtime
	} @files) {
	if (-d "$dir/$file") {
	    eval { process_event_dir($cfg, $opts, $eh, "$dir/$file"); };
	    die $@ if $@;
	} elsif (-f "$dir/$file") {
	    eval { process_event_file($cfg, $opts, $eh, $dir, $file); };
	    if ($@) {
		warn $@;
		rename "$dir/$file", "$dir/error-$file"
		    or warn "Can't rename $dir/$file to error-$file: $!";
	    }
	} else {
	    warn "File $dir/$file is not a plain file. Skipping.\n";
	}
    }
}

sub process_event_file
{
    my $cfg = shift;
    my $opts = shift;
    my $eh = shift;
    my $dir = shift;
    my $file = shift;

    my ($keyword, $action, $garbage) = split ('-', $file);

    my %opts = ();
    open FILE, "$dir/$file" or die "Unable to open $dir/$file: $!";
    while (<FILE>) {
	chomp;
	next unless /^\s*(\S+)\s*=>\s*(.*?)\s*$/;
	my $key = $1;
	my $val = $2;

	if (not defined $opts{$key}) {
	    $opts{$key} = $val;
	} elsif (ref $opts{$key} eq 'SCALAR') {
	    # We have hit a second option for this key.
	    # Convert the value into a list
	    $opts{$key} = [$opts{$key}, $val];
	} elsif (ref $opts{$key} eq 'ARRAY') {
	    # We have hit an Nth (N > 2) value for this key.
	    # Add it to the list.
	    push (@{$opts{$key}}, $val);
	} else {
	    # This should never happen.
	    warn "Unknown error processing $file: We should never get here.";
	    next;
	}
    }
    close FILE;

#    print STDERR "Keyword: $keyword; Action: $action; File: $file\n";
#    use Data::Dumper; print Dumper \%opts;

    # All the data has been read, time to run the task.
    eval { $eh->run_tasks($keyword, $action, $cfg, %opts); };
    die "$file: ".$@ if $@;

    if ($opts->{flag}) {
	eval { VUser::ExtLib::touch($opts->{flag}); };
	die "$@\n" if $@;
    }

    unlink "$dir/$file";
}

sub batch_mode
{
    my $cfg = shift;
    my $opts = shift;
    my $directory = shift; # The 'action' for batch is the dir/file to process
    my $eh = shift;

    eval { process_event_dir($cfg, $opts, $eh, $directory); };
    die $@ if $@;
}

sub unload { }

1;

__END__

=head1 NAME

Batch - vuser batch mode

=head1 DESCRIPTION

Enables batch mode for vuser. When run as C<vuser batch <dir>>, the files in
<dir> will be read and the tasks described there will be run. vuser will
descend into sub-directories, if they exist.

The files are named keyword-action-unique where keyword and action are the
same as if you had run C<vuser keyword action>. The options for the action
are listed, one per line, in the file as:

 option1 => value
 option2 => value2

File with names starting with I<new-> or I<error-> will be ignored.

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
