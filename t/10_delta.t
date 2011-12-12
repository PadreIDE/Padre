#!/usr/bin/perl

# Tests for the Padre::Delta module

use strict;
use warnings;
use Test::More tests => 10;
use Test::NoWarnings;
use t::lib::Padre;
use Padre;
use Padre::Delta;





######################################################################
# Null Delta

SCOPE: {
	my $null = Padre::Delta->new;
	isa_ok( $null, 'Padre::Delta' );
	ok( $null->null, '->null ok' );
}





######################################################################
# Creation from typical Algorithm::Diff output

SCOPE: {
	my $delta = Padre::Delta->from_diff(
		[
			[ '-', 8, 'use 5.008;' ],
			[ '+', 8, 'use 5.008005;' ],
			[ '+', 9, 'use utf8;' ],
		],
		[
			[ '-', 36, "\t\tWx::gettext(\"Set Bookmark\") . \":\"," ],
			[ '+', 37, "\t\tWx::gettext(\"Set Bookmark:\")," ],
		],
		[
			[ '-', 36, "\t\tWx::gettext(\"Existing Bookmark\") . \":\"," ],
			[ '+', 37, "\t\tWx::gettext(\"Existing Bookmark:\")," ],
		],
	);
	isa_ok( $delta, 'Padre::Delta' );
	ok( ! $delta->null, '->null false' );
}





######################################################################
# Functional Test

my $FROM = <<'END_TEXT';
a
b
c
d
e
f
g
h
i
j
k
END_TEXT

my $TO = <<'END_TEXT';
a
c
d
e
f2
f3
g
h
i
i2
j
k
END_TEXT

# Create the FROM-->TO delta and see if it actually changes FROM to TO
SCOPE: {
	# Create the delta
	my $delta = Padre::Delta->from_scalars( \$FROM => \$TO );
	isa_ok( $delta, 'Padre::Delta' );

	# Create an IDE editor to apply it to
	my $padre = Padre->new;
	isa_ok( $padre, 'Padre' );
	my $main = $padre->wx->main;
	isa_ok( $main, 'Padre::Wx::Main' );
	$main->setup_editor;
	my $editor = $main->current->editor;
	isa_ok( $editor, 'Padre::Wx::Editor' );

	# Apply the delta to the FROM text
	$editor->SetText($FROM);
	$delta->to_editor($editor);

	# Do we get the TO text
	my $result = $editor->GetText;
	is( $result, $TO, 'Padre::Delta applies to editor correctly' );
}
