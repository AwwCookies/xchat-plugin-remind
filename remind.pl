#!/usr/bin/perl -w
use 5.018;
use strict;
use JSON;
use String::IRC;

use constant true => 1;
use constant false => 0;

Xchat::register('Remind', '0.0.1', 'Reminds you about stuff.');
Xchat::hook_timer(1000, \&remind);
Xchat::hook_command('remind->add'    => \&add);
Xchat::hook_command('remind->del'    => \&del);
Xchat::hook_command('remind->list'   => \&list);
Xchat::hook_command('remind->commit' => \&commit);

my $fp = Xchat::get_info("xchatdir") . '/' . 'remind.json';
my %reminders;
my $notify = true; # Uses notify-send to send a desktop notification *System must have `notify-send`*


if (-e $fp) { # If the file already exists load it
	open(FILE, '<', $fp);
	%reminders = %{decode_json(<FILE>)};
	close(FILE);
} else { # else Create it.
	%reminders = (
		LAST_KEY => 0,
	);
	&commit();
}

sub add {
	my $key = ++$reminders{LAST_KEY};
	my $seconds = $_[0][1];
	my $message = $_[1][2];
	unless ($seconds =~ /^[0-9\.]+$/) {
		if ($seconds =~ /d/) {
			m/[0-9\.]+/;
			$seconds = int($1) + 86400;
		} else {
			Xchat::print("Invaild time format.");
			return; # End sub
		}
	}
	$reminders{$key} = {
		Time => time + $seconds,
		Message => $message
	};
	&commit();
	Xchat::print("Reminder $key added.") if defined $reminders{$key}{Time};
}

sub del {
	if ($_[0][1] =~ /all/) {
		%reminders = (
		    LAST_KEY => 0,
		);
		&commit();
	} else {
		if (defined $reminders{$_[0][1]}) {
			delete $reminders{$_[0][1]};
			my @sorted = sort {$a <=> $b} keys %reminders;
			$reminders{LAST_KEY} = $sorted[-1];
			&commit();
		} else {
			Xchat::print("ERROR: $_[0][1], invalid key.");
		}
	}
}

sub list {
	foreach my $key (sort {$a <=> $b} keys %reminders) {
		unless ($key eq 'LAST_KEY') {
			Xchat::print("$key => $reminders{$key}->{Time}, $reminders{$key}->{Message}");
		}
	}
}

sub remind {
	while ((my $key, my $value) = each %reminders) {
		unless ($key eq 'LAST_KEY') {
			if ($value->{Time} < time) {
				Xchat::set_context(Xchat::find_context());
				if ($notify) {
					system("notify-send", "Reminder", "'$value->{Message}'");
				}
				Xchat::print(
					String::IRC->new("Reminder: $value->{Message}")->purple('white')
				);
				delete $reminders{$key};
			}
		}
	}
	&commit();
	return Xchat::KEEP;
}

sub commit {
	open(FILE, '>', $fp);
	print(FILE encode_json(\%reminders));
	close(FILE);
}

sub on_unload {
	&commit();
}
