package Padre::Wx::FunctionList;

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.24';
our @ISA     = 'Wx::ListCtrl';





#####################################################################
# Constructor

sub new {
	my $class  = shift;
	my $parent = shift;

	# Create the underlying object
	my $self = $class->SUPER::new(
		$parent,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_SINGLE_SEL
		| Wx::wxLC_NO_HEADER
		| Wx::wxLC_REPORT
	);

	# TODO: What does this do?
	Wx::Event::EVT_KILL_FOCUS(
		$self,
		sub {
			Padre::Current->_main->on_subs_panel_left,
		},
	);

	# Find-as-you-type in functions tab
	Wx::Event::EVT_CHAR( $self,
		sub {
			$self->on_char($_[1])
		},
	);

	# Set up the (only) column
	$self->InsertColumn(0, Wx::gettext('Subs'));
	$self->SetColumnWidth(0, Wx::wxLIST_AUTOSIZE);

	Wx::Event::EVT_LIST_ITEM_ACTIVATED( $self,
		$self,
		sub {
			Padre::Current->_main->on_function_selected( $_[1] );
		}
	);

	return $self;
}





#####################################################################
# Event Handlers

sub on_char {
	my $self  = shift;
	my $event = shift;
	my $mod   = $event->GetModifiers || 0;
	my $code  = $event->GetKeyCode;
	
	# Remove the bit ( Wx::wxMOD_META) set by Num Lock being pressed on Linux
	# TODO: This is cargo-cult
	$mod = $mod & (Wx::wxMOD_ALT + Wx::wxMOD_CMD + Wx::wxMOD_SHIFT);

	unless ( $mod ) {
		# TODO is there a better way? use ==?
		if ( $code <= 255 and $code > 0 and chr($code) =~ /^[\w_:-]$/ ) {
			# transform - => _ for convenience
			$code = 95 if $code == 45;
			$self->{function_find_string} .= chr($code);

			# This does a partial match starting at the beginning of the function name
			my $position = $self->FindItem( 0, $self->{function_find_string}, 1 );
			if ( defined $position ) {
				$self->SetItemState(
					$position,
					Wx::wxLIST_STATE_SELECTED,
					Wx::wxLIST_STATE_SELECTED,
				);
			}
		} else {
			# Reset the find string
			$self->{function_find_string} = undef;
		}
	}

	$event->Skip(1);
	return;
}

1;
