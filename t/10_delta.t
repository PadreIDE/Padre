#!/usr/bin/perl

# Tests for the Padre::Delta module

use strict;
use warnings;
use Test::More;


BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan( tests => 14 );
}

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
# Test the tidy method

SCOPE: {
	my $delta = Padre::Delta->new(
		'position',
		[ 1, 2, 'foo' ],
		[ 8, 9, 'bar' ],
		[ 6, 3, ''    ],
	)->tidy;
	isa_ok( $delta, 'Padre::Delta' );
	is_deeply(
		$delta->{targets},
		[
			[ 8, 9, 'bar' ],
			[ 3, 6, ''    ],
			[ 1, 2, 'foo' ],
		],
		'Targets are tidied correctly',
	);
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

# Set up for the functional tests
my $padre = Padre->new;
isa_ok( $padre, 'Padre' );
my $main = $padre->wx->main;
isa_ok( $main, 'Padre::Wx::Main' );
$main->setup_editor;
my $editor = $main->current->editor;
isa_ok( $editor, 'Padre::Wx::Editor' );

my $FROM1 = <<'END_TEXT';
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

my $TO1 = <<'END_TEXT';
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
	my $delta = Padre::Delta->from_scalars( \$FROM1 => \$TO1 );
	isa_ok( $delta, 'Padre::Delta' );

	# Apply the delta to the FROM text
	$editor->SetText($FROM1);
	$delta->to_editor($editor);

	# Do we get the TO text
	my $result = $editor->GetText;
	is( $result, $TO1, 'Delta applied ok' );
}





######################################################################
# Regression Test

my $FROM2 = <<'END_TEXT';
	my $close_button = Wx::Button->new(
		$self,
		Wx::ID_CANCEL,
		Wx::gettext("Close"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	$close_button->SetDefault;

	my $bSizer471 = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$bSizer471->Add( $self->{m_staticText6511}, 0, Wx::LEFT | Wx::RIGHT | Wx::TOP, 5 );

	my $bSizer4711 = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$bSizer4711->Add( $self->{m_staticText65111}, 0, Wx::ALL, 5 );
	$bSizer4711->Add( $self->{creator}, 0, Wx::ALL, 5 );

	my $bSizer81 = Wx::BoxSizer->new(Wx::VERTICAL);
	$bSizer81->Add( $self->{m_staticline271}, 0, Wx::EXPAND | Wx::ALL, 5 );
	$bSizer81->Add( $self->{m_staticText34}, 0, Wx::ALL, 5 );
	$bSizer81->Add( $self->{m_staticText67}, 0, Wx::ALL, 5 );
	$bSizer81->Add( $self->{m_staticText35}, 0, Wx::ALL, 5 );

	my $bSizer17 = Wx::BoxSizer->new(Wx::VERTICAL);
	$bSizer17->Add( $self->{splash}, 0, Wx::ALIGN_CENTER | Wx::TOP, 5 );
	$bSizer17->Add( $bSizer471, 0, Wx::EXPAND, 5 );
	$bSizer17->Add( $bSizer4711, 0, Wx::EXPAND, 5 );
	$bSizer17->Add( $bSizer81, 1, Wx::EXPAND, 5 );

	$self->{padre}->SetSizerAndFit($bSizer17);
	$self->{padre}->Layout;
END_TEXT

my $TO2 = <<'END_TEXT';
	my $close_button = Wx::Button->new(
		$self,
		Wx::ID_CANCEL,
		Wx::gettext("Close"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	$close_button->SetDefault;

	my $bSizer81 = Wx::BoxSizer->new(Wx::VERTICAL);
	$bSizer81->Add( $self->{m_staticText34}, 0, Wx::ALL, 5 );
	$bSizer81->Add( $self->{m_staticText67}, 0, Wx::ALL, 5 );
	$bSizer81->Add( $self->{m_staticText35}, 0, Wx::ALL, 5 );

	my $bSizer17 = Wx::BoxSizer->new(Wx::VERTICAL);
	$bSizer17->Add( $self->{splash}, 0, Wx::ALIGN_CENTER | Wx::TOP, 5 );
	$bSizer17->Add( $self->{m_staticText6511}, 0, Wx::LEFT | Wx::RIGHT | Wx::TOP, 5 );
	$bSizer17->Add( $self->{creator}, 0, Wx::ALL, 5 );
	$bSizer17->Add( $self->{m_staticline271}, 0, Wx::EXPAND | Wx::ALL, 0 );
	$bSizer17->Add( $bSizer81, 1, Wx::EXPAND, 5 );

	$self->{padre}->SetSizerAndFit($bSizer17);
	$self->{padre}->Layout;
END_TEXT

# Create the FROM-->TO delta and see if it actually changes FROM to TO
SCOPE: {
	# Create the delta
	my $delta = Padre::Delta->from_scalars( \$FROM2 => \$TO2 );
	isa_ok( $delta, 'Padre::Delta' );

	# Apply the delta to the FROM text
	$editor->SetText($FROM2);
	$delta->to_editor($editor);

	# Do we get the TO text
	my $result = $editor->GetText;
	is( $result, $TO2, 'Delta applied correctly' );
}
