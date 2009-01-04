package Padre::Wx::Menu::Search;

# Fully encapsulated Search menu

use 5.008;
use strict;
use warnings;
use Padre::Wx          ();
use Padre::Wx::Submenu ();

our $VERSION = '0.23';
our @ISA     = 'Padre::Wx::Submenu';





#####################################################################
# Padre::Wx::Submenu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);





	# Search and Replace
	Wx::Event::EVT_MENU( $main,
		$self->Append(
			Wx::wxID_FIND,
			Wx::gettext("&Find\tCtrl-F")
		),
		sub {
			Padre::Wx::Dialog::Find->find(@_)
		},
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Find Next\tF3")
		),
		sub {
			Padre::Wx::Dialog::Find->find_next(@_);
		},
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Find Previous\tShift-F3")
		),
		sub {
			Padre::Wx::Dialog::Find->find_previous(@_);
		},
	);

	$self->AppendSeparator;

	# Quick Find: Press F3 to start search with selected text
	$self->{quick_find} = $self->AppendCheckItem( -1,
		Wx::gettext("Quick Find")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{quick_find},
		sub {
			Padre->ide->config->{is_quick_find} = $_[1]->IsChecked ? 1 : 0;
			return;
		},
	);
	$self->{quick_find}->Check( Padre->ide->config->{is_quick_find} ? 1 : 0 );

	# Incremental find (#60)
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext("Find Next\tF4") ),
		sub {
			$_[0]->find->search('next');
		},
	);
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext("Find Previous\tShift-F4") ),
		sub {
			$_[0]->find->search('previous');
		}
	);

	$self->AppendSeparator;

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Ac&k Search")
		),
		\&Padre::Wx::Ack::on_ack,
	);





	return $self;
}

1;
