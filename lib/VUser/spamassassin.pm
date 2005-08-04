package VUser::spamassassin.pm;
use warnings;
use strict;

# Copyright 2004 Randy Smith
# $Id: spamassassin.pm,v 1.2 2005/07/02 21:04:05 perlstalker Exp $

use vars qw(@ISA);

our $REVISION = (split (' ', '$Revision: 1.2 $'))[1];
our $VERSION = "0.1.0";

use VUser::Extension;
push @ISA, 'VUser::Extension';

my %dbs = ('scores' => undef,
	   'awl' => undef,
	   'bayes' => undef);

sub config_sample
{
    my $fh;
    my $cfg = shift;
    my $opts = shift;

    if (defined $opts->{file}) {
	open ($fh, ">".$opts->{file})
	    or die "Can't open '".$opts->{file}."': $!\n";
    } else {
	$fh = \*STDOUT;
    }

    print $fh <<'CONFIG';
[Extension_spamassassin]
# User scores database username and password.
# The DSN's here are in the same format as defined in the sql/README*
# files in the SpamAssassin package.
# This user needs select, insert and delete permissions.
user_scores_dsn=
user_scores_username=
user_scores_password=

# The name of the table being used for user preferences.
user_scores_table=userprefs

# AWL database username and password.
# This user needs select, insert and delete permissions.
user_awl_dsn=
user_awl_username=
user_awl_password=

# Auto whitelist table
user_awl_table=awl

# Bayes database username and password.
# This user needs select, insert and delete permissions.
bayes_dsn=
bayes_username=
bayes_password=

CONFIG
    if (defined $opts->{file}) {
	close CONF;
    }

}

sub init
{
    my $eh = shift;
    my %cfg = @_;

#    return unless VUser::ExtLib::check_bool($cfg{Extension_spamassassin}{enable});

    # Connect to the database(s)
    my $scores_dsn = VUser::ExtLib::strip_ws($cfg{Extension_spamassassin}{user_scores_dsn});

    if ($scores_dsn) {
	require DBI;
	my $scores_user = VUser::ExtLib::strip_ws($cfg{Extension_spamassassin}{user_scores_username});
	my $scores_pass = VUser::ExtLib::strip_ws($cfg{Extension_spamassassin}{user_scores_password});
	$dbs{scores} = DBI->connect($scores_dsn, $scores_user, $scores_pass);
	die "Unable connect to database: ".DBI->errstr."\n" unless $dbs{scores};
    }

    my $awl_dsn = VUser::ExtLib::strip_ws($cfg{Extension_spamassassin}{user_awl_dsn});
    if ($awl_dsn) {
	require DBI;
	my $awl_user = VUser::ExtLib::strip_ws($cfg{Extension_spamassassin}{user_awl_username});
	my $awl_pass = VUser::ExtLib::strip_ws($cfg{Extension_spamassassin}{user_awl_password});
	$dbs{awl} = DBI->connect($scores_dsn, $scores_user, $scores_pass);
	die "Unable connect to database: ".DBI->errstr."\n" unless $dbs{awl};
    }

    my $bayes_dns = VUser::ExtLib::strip_ws($cfg{Extension_spamassassin}{bayes_dsn});
    if ($bayes_dsn) {
	require DBI;
	my $bayes_user = VUser::ExtLib::strip_ws($cfg{Extension_spamassassin}{bayes_username});
	my $bayes_pass = VUser::ExtLib::strip_ws($cfg{Extension_spamassassin}{bayes_password});
	$dbs{bayes} = DBI->connect($scores_dsn, $scores_user, $scores_pass);
	die "Unable connect to database: ".DBI->errstr."\n" unless $dbs{bayes};
    }

    # SA
    $eh->register_keyword('sa');
    
    # SA-delall: Delete all options for a user.
    $eh->register_action('sa', 'delall');
    $eh->register_option('sa',' delall', 'username', '=s', 1);
    $eh->register_task('sa', 'delall', \&sa_delall);

    # SA-add: add an option for a user.
    $eh->register_action('sa', 'add');
    $eh->register_option('sa', 'add', 'username', '=s', 1);
    $eh->register_option('sa', 'add', 'option', '=s', 1);
    $eh->register_option('sa', 'add', 'value', '=s', 1);
    $eh->register_task('sa', 'add', \&sa_add);

    # SA-mod: modify a user's options
    $eh->register_action('sa', 'mod');
    $eh->register_option('sa', 'mod', 'username', '=s', 1);
    $eh->register_option('sa', 'mod', 'option', '=s', 1);
    $eh->register_option('sa', 'mod', 'value', '=s');
    $eh->register_option('sa', 'mod', 'delete');
    $eh->register_option('sa', 'mod', \&sa_mod);

    # SA-mod: delete an option for a user.
    $eh->register_action('sa', 'del');
    $eh->register_option('sa',' del', 'username', '=s', 1);
    $eh->register_option('sa', 'del', 'option', '=s', 1);
    $eh->register_task('sa', 'del', \&sa_del);

    # SA-show: Show user settings
    $eh->register_action('sa', 'show');
    $eh->register_option('sa', 'show', 'username', '=s');
    $eh->register_option('sa', 'show', 'option', '=s');
    $eh->register_task('sa', 'show', \&sa_show);

    # Email
    $eh->register_keyword('email');

    # Email-del: When an email is deleted, we need to remove all their
    # settings as well.
    $eh->register_action('email', 'del');
    $eh->register_task('email', 'del', \&sa_delall);
}

sub unload {};

sub sa_add
{
    my $cfg = shift;
    my $opts = shift;

    my $user = $opts->{username};
    my $option = $opts->{option};
    my $value = $opts->{value};

    if ($dbs{scores}) {
	my $table = VUser::ExtLib::strip_ws($cfg->{Extension_spamassassin}{user_scores_table});
	my $sql = "Insert into $table set username=?, preference=?, value=?";
	my $sth = $dbs{scores}->prepare($sql)
	    or die "Database error: ".$dbs{scores}->errstr."\n";
	$sth->execute($user, $option, $value)
	    or die "Database error: ".$sth->errstr."\n";
    } else {
	# In the future we'll screw with text files here.
    }
}

sub sa_mod {}
sub sa_del {}
sub sa_show {}
sub sa_delall {}

1;

__END__

=head1 NAME

spamassassin - vuser spamassassin support extension

=head1 DESCRIPTION

It is assumed that this module will be used primarily when using a database
to store SpamAssassin settings. File based configuration is not supported
at this time but will probably be added at some point in the future.

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
