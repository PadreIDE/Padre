#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Cwd qw(cwd);
use File::Spec ();

# a few sample strings some of them disappeard from messages.pot during the release of 0.82
# See ticket #1132
my @strings = (
	'Dump the Padre object to STDOUT',
	'Full Screen',
	'Check for Common (Beginner) Errors',
	'Run Script',
);

plan tests => scalar @strings;

my $messages_pot = File::Spec->catfile(cwd(), 'share', 'locale', 'messages.pot');
open my $fh, '<', $messages_pot or die "Could not open '$messages_pot' $!";
my @messages = <$fh>;
foreach my $str (@strings) {
	ok grep({$_ =~ /\Q$str/} @messages), "messages.pot has entry '$str'";
}

