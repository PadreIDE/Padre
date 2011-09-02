#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Cwd qw(cwd);
use File::Spec ();

use t::lib::Padre;

# a few sample strings some of them disappeard from messages.pot during the release of 0.82
# See ticket #1132
my @strings = (
	q(msgid "Open in File Browser"),                # File/Open/
	q(msgid "&Clear Selection Marks"),              # Edit/Select/
	q(msgid "Full Sc&reen"),                        # View/
	q(msgid "&Quick Menu Access..."),               # Search/
	q(msgid "&Check for Common (Beginner) Errors"), # Perl/
	q(msgid "Find Unmatched &Brace"),               # Perl/
	q(msgid "&Move POD to __END__"),                # Refactor/
	q(msgid "&Run Script"),                         # Run/
	q(msgid "Dump the Padre object to STDOUT"),     # internal

	q("The file %s you are trying to open is %s bytes large. It is over the "), # Padre::Document
	q("arbitrary file size limit of Padre which is currently %s. Opening this file "),
	q("may reduce performance. Do you still want to open the file?"),

	q(msgid "%s - Crashed while instantiating: %s"),                            # Padre::PluginManager

	q(msgid "Default word wrap on for each file"),                              # Padre::Wx::Dialog::Preferences
	q(msgid "Any non-word character"),                                          #: lib/Padre/Wx/Dialog/RegexEditor.pm:78
);

plan tests => scalar @strings;

my $messages_pot = File::Spec->catfile( cwd(), 'share', 'locale', 'messages.pot' );
open my $fh, '<', $messages_pot or die "Could not open '$messages_pot' $!";
my @messages = <$fh>;
close $fh;
foreach my $str (@strings) {
	ok grep( { $_ =~ /\Q$str/ } @messages ), "messages.pot has entry '$str'";
}

