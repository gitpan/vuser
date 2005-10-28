package VUser::spamassassin;
use warnings;
use strict;

# Copyright 2004 Randy Smith
# $Id: spamassassin.pm,v 1.5 2005/10/28 04:27:29 perlstalker Exp $

use vars qw(@ISA);

our $REVISION = (split (' ', '$Revision: 1.5 $'))[1];
our $VERSION = "0.2.0";

use VUser::Meta;
use VUser::ResultSet;
use VUser::Extension;
push @ISA, 'VUser::Extension';

my %dbs = ('scores' => undef,
	   'awl' => undef,
	   'bayes' => undef);

my %meta = ('username' => VUser::Meta->new(name => 'username',
					   type => 'string',
					   description => 'User name'),
	    'option' => VUser::Meta->new (name => 'option',
					  type => 'string',
					  description => 'SA option'),
	    'value' => VUser::Meta->new (name => 'value',
					 type => 'string',
					 description => 'Value for option')
	    );

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
	close $fh;
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
	$dbs{awl} = DBI->connect($awl_dsn, $awl_user, $awl_pass);
	die "Unable connect to database: ".DBI->errstr."\n" unless $dbs{awl};
    }

    my $bayes_dsn = VUser::ExtLib::strip_ws($cfg{Extension_spamassassin}{bayes_dsn});
    if ($bayes_dsn) {
	require DBI;
	my $bayes_user = VUser::ExtLib::strip_ws($cfg{Extension_spamassassin}{bayes_username});
	my $bayes_pass = VUser::ExtLib::strip_ws($cfg{Extension_spamassassin}{bayes_password});
	$dbs{bayes} = DBI->connect($bayes_dsn, $bayes_user, $bayes_pass);
	die "Unable connect to database: ".DBI->errstr."\n" unless $dbs{bayes};
    }

    # SA
    $eh->register_keyword('sa');
    
    # SA-delall: Delete all options for a user.
    $eh->register_action('sa', 'delall');
    $eh->register_option('sa',' delall', $meta{'username'}, 1);
    $eh->register_task('sa', 'delall', \&sa_delall);

    # SA-add: add an option for a user.
    $eh->register_action('sa', 'add');
    $eh->register_option('sa', 'add', $meta{'username'}, 1);
    $eh->register_option('sa', 'add', $meta{'option'}, 1);
    $eh->register_option('sa', 'add', $meta{'value'}, 1);
    $eh->register_task('sa', 'add', \&sa_add);

    # SA-mod: modify a user's options
    $eh->register_action('sa', 'mod');
    $eh->register_option('sa', 'mod', $meta{'username'}, 1);
    $eh->register_option('sa', 'mod', $meta{'option'}, 1);
    $eh->register_option('sa', 'mod', $meta{'value'});
    $eh->register_option('sa', 'mod',
			 VUser::Meta->new(name => 'delete',
					  type => 'boolean',
					  description => 'Delete the option')
			 );
    $eh->register_option('sa', 'mod', \&sa_mod);

    # SA-mod: delete an option for a user.
    $eh->register_action('sa', 'del');
    $eh->register_option('sa',' del', $meta{'username'}, 1);
    $eh->register_option('sa', 'del', $meta{'option'}, 1);
    $eh->register_task('sa', 'del', \&sa_del);

    # SA-show: Show user settings
    $eh->register_action('sa', 'show');
    $eh->register_option('sa', 'show', $meta{'username'});
    $eh->register_option('sa', 'show', $meta{'option'});
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

sub sa_mod
{
    my $cfg = shift;
    my $opts = shift;

    my $user = $opts->{username};
    my $option = $opts->{option};
    my $value = $opts->{value};
    my $delete = $opts->{delete};

    if ($delete) {
	return sa_del($cfg, $opts, @_);
    } else {
	if ($dbs{scores}) {
	    my $table = VUser::ExtLib::strip_ws($cfg->{Extension_spamassassin}{user_scores_table});
	    my $sql = "update $table set value=? where username=? and preference = ?";
	    my $sth = $dbs{scores}->prepare($sql)
		or die "Database error: ".$dbs{scores}->errstr."\n";
	    $sth->execute($value, $user, $option)
		or die "Database error: ".$sth->errstr."\n";
	} else {
	    # File-based stuff
	}
    }
}

sub sa_del
{
    my $cfg = shift;
    my $opts = shift;

    my $user = $opts->{username};
    my $option = $opts->{option};

    if ($dbs{scores}) {
	my $table = VUser::ExtLib::strip_ws($cfg->{Extension_spamassassin}{user_scores_table});
	my $sql = "delete from $table where username=? and preference = ?";
	my $sth = $dbs{scores}->prepare($sql)
	    or die "Database error: ".$dbs{scores}->errstr."\n";
	$sth->execute($user, $option)
	    or die "Database error: ".$sth->errstr."\n";
    } else {
	# File-based stuff here.
    }
}

sub sa_delall
{
    my $cfg = shift;
    my $opts = shift;

    my $user = $opts->{username};

    # The email extension uses 'account' instead of 'username'
    $user = $opts->{account} if not $user;

    # Delete the preferences
    if ($dbs{scores}) {
	my $table = VUser::ExtLib::strip_ws($cfg->{Extension_spamassassin}{user_scores_table});
	my $sql = "delete from $table where username=?";
	my $sth = $dbs{scores}->prepare($sql)
	    or die "Database error: ".$dbs{scores}->errstr."\n";
	$sth->execute($user)
	    or die "Database error: ".$sth->errstr."\n";
    } else {
	# file-based
    }

    # Delete the AWL entries
    if ($dbs{awl}) {
	my $table = VUser::ExtLib::strip_ws($cfg->{Extension_spamassassin}{user_awl_table});
	my $sql = "delete from $table where username=?";
	my $sth = $dbs{scores}->prepare($sql)
	    or die "Database error: ".$dbs{scores}->errstr."\n";
	$sth->execute($user)
	    or die "Database error: ".$sth->errstr."\n";
    } else {
    }

    # Delete Baysian DB
    if ($dbs{bayes}) {
	# There are quite a few tables we need to delete from.
	# To start, we need to grab the id for the user.
	my $sql = 'select id from bayes_vars where username = ?';
	my $sth = $dbs{scores}->prepare($sql)
	    or die "Database error: ".$dbs{scores}->errstr."\n";
	$sth->execute($user)
	    or die "Database error: ".$sth->errstr."\n";
	my $res = $sth->fetchrow_hashref;
	
	if (defined $res) {
	    my $id = $res->{id};

	    # Delete everything for this user in each table.
	    foreach my $table (qw(bayes_vars bayes_tokens bayes_seen
				 bayes_expire)) {
		$sql = "delete from $table where id=?";
		my $sth = $dbs{scores}->prepare($sql)
		    or die "Database error: ".$dbs{scores}->errstr."\n";
		$sth->execute($user)
		    or die "Database error: ".$sth->errstr."\n";
	    }
	}
    } else {
	# file-based stuff here.
    }
}

sub sa_show
{
    my $cfg = shift;
    my $opts = shift;

    my $user = $opts->{username};
    my $option = $opts->{option};

    my $rs = VUser::ResultSet->new;
    foreach my $meta_name (qw[username option value]) {
	$rs->add_meta($meta{$meta_name});
    }
    
    if ($dbs{'scores'}) {
	$user = '%' unless $user;
	$option = '%' unless $user;

	my $table = VUser::ExtLib::strip_ws($cfg->{Extension_spamassassin}{user_scores_table});
	my $sql = "select * from $table where username like ? and preference like ? order by username,preference";
	my $sth = $dbs{scores}->prepare($sql)
	    or die "Database error: ".$dbs{scores}->errstr."\n";
	$sth->execute($user, $option)
	    or die "Database error: ".$sth->errstr."\n";

	my $res;
	while (defined ($res = $sth->fetchrow_hashref)) {
	    print join (':', $res->{username}, $res->{option}, $res->{value});
	    print "\n";
	    $rs->add_data([$res->{username}, $res->{option}, $res->{value}]);
	}
    }
    return $rs;
}

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
