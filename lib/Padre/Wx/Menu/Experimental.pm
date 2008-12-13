package Padre::Wx::Menu::Experimental;

use 5.008;
use strict;
use warnings;
use Padre::Wx          ();
use Padre::Wx::Submenu ();
use Padre::Documents   ();

our $VERSION = '0.20';
our @ISA     = 'Padre::Wx::Submenu';





#####################################################################
# Padre::Wx::Submenu Methods

sub new {
	my $class  = shift;
	my $main   = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Disable experimental mode
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext('Disable Experimental Mode') ),
		sub {
			Padre->ide->config->{experimental} = 0;
			$_[0]->menu->refresh;
			return;
		},
	);

	$self->AppendSeparator;

	# Force-refresh the menu
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext('Refresh Menu') ),
		sub {
			$_[0]->menu->refresh;
			return;
		},
	);

	# Force-refresh the menu
	$self->{refresh_counter} = 0;
	$self->{refresh_count}   = $self->Append( -1,
		Wx::gettext('Refresh Counter: ') . $self->{refresh_count}
	);
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, $self->{refresh_count} ),
		sub {
			return;
		},
	);

	$self->AppendSeparator;

	# Recent projects
	$self->{recent_projects} = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("Recent Projects") . '...',
		$self->{recent_projects},
	);

	# Launch a script INSIDE the running Padre instance
	Wx::Event::EVT_MENU(
		$main,
		$self->Append( -1, Wx::gettext('Run in &Padre') ),
		sub {
			my $self = shift;
			my $code = Padre::Documents->current->text_get;
			eval $code; ## no critic
			Wx::MessageBox(
				Wx::gettext("Error: ") . "$@",
				Wx::gettext("Self error"),
				Wx::wxOK,
				$main,
			) if $@;
			return;
		},
	);

	# Experimental PPI-based highlighting
	$self->{ppi_highlight} = $self->AppendCheckItem( -1,
		Wx::gettext("Use PPI for Perl5 syntax highlighting")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{ppi_highlight},
		sub {
			# Update the saved config setting
			my $config = Padre->ide->config;
			$config->{ppi_highlight} = $_[1]->IsChecked ? 1 : 0;

			# Refresh the menu (and MIME_LEXER hook)
			$self->refresh;

			# Update the colourise for each Perl editor
			foreach my $editor ( $_[0]->pages ) {
				my $doc = $editor->{Document};
				next unless $doc->isa('Padre::Document::Perl');
				if ( $config->{ppi_highlight} ) {
					$doc->colorize;
				} else {
					$doc->remove_color;
					$editor->Colourise( 0, $editor->GetLength );
				}
			}

			return;
		}
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

	return $self;
}

# Update the checkstate for several menu items
sub refresh {
	my $self   = shift;
	my $config = Padre->ide->config;

	# Update the refresh counter
	$self->{refresh_counter}++;
	$self->{refresh_count}->SetText( 
		Wx::gettext('Refresh Counter: ') . $self->{refresh_count}
	);

	# Simple QuickFind check update
	$self->{quick_find}->Check( $config->{is_quick_find} ? 1 : 0 );

	# Check update and enable/disable the PPI lexer hook
	$self->{ppi_highlight}->Check( $config->{ppi_highlight} ? 1 : 0 );
	$Padre::Document::MIME_LEXER{'application/x-perl'} = 
		$config->{ppi_highlight}
			? Wx::wxSTC_LEX_CONTAINER
			: Wx::wxSTC_LEX_PERL;

	return;
}

1;
