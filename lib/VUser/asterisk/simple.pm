package VUser::asterisk::simple;
use warnings;
use strict;

# Copyright 2004 Randy Smith
# $Id: simple.pm,v 1.6 2005/10/28 04:27:30 perlstalker Exp $

use vars qw(@ISA);

our $REVISION = (split (' ', '$Revision: 1.6 $'))[1];
our $VERSION = "0.2.0";

use VUser::Extension;
push @ISA, 'VUser::Extension';

sub init
{
    my $eh = shift;
    my %cfg = @_;

    $eh->register_keyword('voip');

    # voip-add
    $eh->register_action('voip', 'add');
    $eh->register_option('voip', 'add', 'extension', '=s', 1);
    $eh->register_option('voip', 'add', 'username', '=s');
    $eh->register_option('voip', 'add', 'context', '=s');
    $eh->register_option('voip', 'add', 'password', '=s');
    $eh->register_option('voip', 'add', 'vmpassword', '=i');
    $eh->register_option('voip', 'add', 'email', '=s');
    $eh->register_option('voip', 'add', 'name', '=s');
    $eh->register_task('voip', 'add', \&voip_add);

    # voip-del
    $eh->register_action('voip', 'del');
    $eh->register_option('voip', 'del', 'extension', '=s', 1);
    $eh->register_option('voip', 'del', 'context', '=s');
    $eh->register_task('voip', 'del', \&voip_del);

    # voip-mod
    $eh->register_action('voip', 'mod');
    $eh->register_option('voip', 'mod', 'extension', '=s', 1);
    $eh->register_option('voip', 'mod', 'context', '=s');
    $eh->register_option('voip', 'mod', 'username', '=s');
    $eh->register_option('voip', 'mod', 'password', '=s');
    $eh->register_option('voip', 'mod', 'vmpassword', '=s');
    $eh->register_option('voip', 'mod', 'email', '=s');
    $eh->register_option('voip', 'mod', 'name', '=s');
    $eh->register_option('voip', 'mod', 'newextension', '=s');
    $eh->register_option('voip', 'mod', 'newcontext', '=s');
    $eh->register_task('voip', 'mod', \&voip_mod);

    # voip-show
    $eh->register_action('voip', 'show');
    $eh->register_option('voip', 'show', 'extension', '=s', 1);
    $eh->register_option('voip', 'show', 'context', '=s');
    $eh->register_task('voip', 'show', \&voip_show);
}

sub unload {}

sub voip_add
{
    my $cfg = shift;
    my $opts = shift;
    my $action = shift;
    my $eh = shift;

    my %user = ();
    for my $item qw(extension username context
		    password vmpassword email name) {
	$user{$item} = $opts->{$item};
    }

    $user{extension} =~ s/\D//g;

    $user{context} = VUser::ExtLib::strip_ws($cfg->{Extension_asterisk}{'default context'}) unless $user{context};
    $user{password} = VUser::ExtLib::generate_password unless $user{password};
    $user{vmpassword} = VUser::ExtLib::generate_password(4, (0..9))
	unless $user{vmpassword};
    $user{username} = $user{extension} unless $user{username};
    $user{email} = '' unless $user{email};
    $user{name} = '' unless $user{name};

    eval {
	$eh->run_tasks('sip', 'add', $cfg,
		       (name => $user{extension},
			username => $user{username},
			secret => $user{password},
			context => $user{context},
			mailbox => "$user{extension}\@$user{context}",
			callerid => $user{name}
			)
		       );
	$eh->run_tasks('ext', 'add', $cfg, (extension => $user{extension},
					    context => $user{context},
					    priority => 1,
					    application => 'Dial',
					    args => "SIP/$user{extension},30,4",
					    flags => 1
					    )
		       );
	$eh->run_tasks('ext', 'add', $cfg, (extension => $user{extension},
					    context => $user{context},
					    priority => 2,
					    application => 'Voicemail',
					    args => "su$user{extension}\@$user{context}",
					    flags => 1
					    )
		       );
	$eh->run_tasks('ext', 'add', $cfg, (extension => $user{extension},
					    context => $user{context},
					    priority => 3,
					    application => 'Hangup',
					    flags => 1
					    )
		       );
	$eh->run_tasks('ext', 'add', $cfg,
		       (extension => "$user{extension}/$user{extension}",
			context => $user{context},
			priority => 1,
			application => 'VoicemailMain',
			args => "$user{extension}\@$user{context}",
			flags => 1
			)
		       );
	$eh->run_tasks('ext', 'add', $cfg,
		       (extension => "$user{extension}/$user{extension}",
			context => $user{context},
			priority => 2,
			application => 'Hangup',
			flags => 1
			)
		       );
	$eh->run_tasks('vm', 'add', $cfg, (mailbox => $user{extension},
					   context => $user{context},
					   password => $user{vmpassword},
					   fullname => $user{name},
					   email => $user{email}
					   )
		       );
    };
    die "$@" if $@;
}

sub voip_del
{
    my $cfg = shift;
    my $opts = shift;
    my $action = shift;
    my $eh = shift;

    my %user = ();
    for my $item qw(extension context) {
	$user{$item} = $opts->{$item};
    }

    $user{context} = VUser::ExtLib::strip_ws($cfg->{Extension_asterisk}{'default context'}) unless $user{context};

    $user{extension} =~ s/\D//g;

    eval {
	$eh->run_tasks('sip', 'del', $cfg, (name => $user{extension},
					    context => $user{context}
					    )
		       );
	for my $pri (1..3) {
	    $eh->run_tasks('ext', 'del', $cfg, (extension => $user{extension},
						context => $user{context},
						priority => $pri
						)
			   );
	}
	
	for my $pri (1..2) {
	    $eh->run_tasks('ext', 'del', $cfg,
			   (extension => "$user{extension}/$user{extension}",
			    context => $user{context},
			    priority => $pri
			    )
			   );
	}
	
	$eh->run_tasks('vm', 'del', $cfg, (mailbox => $user{extension},
					   context => $user{context}
					   )
		       );
    };
    die "$@" if $@;
}

sub voip_mod
{
    my $cfg = shift;
    my $opts = shift;
    my $action = shift;
    my $eh = shift;

    my %user = ();
    for my $item qw(extension username context
		    password vmpassword email name
		    newextension newcontext) {
	$user{$item} = $opts->{$item};
    }

    $user{extension} =~ s/\D//g;

    $user{context} = VUser::ExtLib::strip_ws($cfg->{Extension_asterisk}{'default context'}) unless $user{context};
    $user{password} = VUser::ExtLib::generate_password unless $user{password};
    $user{vmpassword} = VUser::ExtLib::generate_password(4, (0..9))
	unless $user{vmpassword};
    $user{username} = $user{extension} unless $user{username};
    $user{email} = '' unless $user{email};
    $user{name} = '' unless $user{name};

    $user{newextension} =~ s/\D//g if defined $user{newextension};

    my ($next, $ncontext) = ($user{name}, $user{context});
    if ($user{newcontext} or $user{newextension}) {
	$next = $user{newextension} if $user{newextension};
	$ncontext = $user{newcontext} if $user{newcontext};
    }

    eval {
	my %opts =  (name => $user{extension},
		     context => $user{context},
		     newname => $next,
		     newcontext => $ncontext
		     );
	$opts{secret} = $user{password} if $user{password};
	$opts{callerid} = $user{name} if $user{callerid};
	$opts{mailbox} = "$next\@$ncontext";
	$opts{username} = $user{username} if $user{username};
	$eh->run_tasks('sip', 'mod', $cfg, %opts);

	%opts = (extension => $user{extension},
		 context => $user{context},
		 newextension => $next,
		 newcontext => $ncontext
		 );
	foreach my $pri (1..3) {
	    $eh->run_tasks('ext', 'mod', $cfg, %opts, 'priority' => $pri);
	}

	%opts = (extension => "$user{extension}/$user{extension}",
		 context => $user{context},
		 newextension => "$next/$next",
		 newcontext => $ncontext
		 );
	foreach my $pri (1..2) {
	    $eh->run_tasks('ext', 'mod', $cfg, %opts, 'priority' => $pri);
	}

	%opts = (mailbox => $user{extension},
		 context => $user{context},
		 newmailbox => $next,
		 newcontext => $ncontext
		 );
	$opts{email} = $user{email} if $user{email};
	$opts{password} = $user{vmpassword} if $user{vmpassword};
	$opts{fullname} = $user{name} if $user{name};
	$eh->run_tasks('vm', 'mod', $cfg, %opts);
    };
    die $@ if $@;
}

sub voip_show
{
    my $cfg = shift;
    my $opts = shift;
    my $action = shift;
    my $eh = shift;

    my %user = ();
    for my $item qw(extension context) {
	$user{$item} = $opts->{$item};
    }

    $user{context} = VUser::ExtLib::strip_ws($cfg->{Extension_asterisk}{'default context'}) unless $user{context};

    $user{extension} =~ s/\D//g;

    eval {
	print "*** SIP\n";
	$eh->run_tasks('sip', 'show', $cfg, (name => $user{extension},
					     context => $user{context})
		       );
	print "\n*** Extensions\n";
	$eh->run_tasks('ext', 'show', $cfg, (extension => $user{extension},
					     context => $user{context})
		       );
	$eh->run_tasks('ext', 'show', $cfg,
		       (extension => "$user{extension}/$user{extension}",
			context => $user{context}
			)
		       );
	print "\n*** Voicemail\n";
	$eh->run_tasks('vm', 'show', $cfg, (mailbox => $user{extension},
					    context => $user{context})
		       );
    };
    die $@ if $@;
}

1;

__END__

=head1 NAME

asterisk::simple - A "simple" interface for adding asterisk users.

=head1 DESCRIPTION

I<asterisk::simple> provides a "simple" interface for adding users to asterisk.
It's designed to streamline the process of creating a SIP/IAX user, their
voicemail box and the extensions needed to make send calls to the user.

B<Note:> You must also load the asterisk extension to use this extension.

This extension is also included as an example of how to create your own
action concentrator to simplfy adding users and things that use multiple
extentions and/or actions.

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

