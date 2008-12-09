package Padre::Wx::Menu::Experimental;

use 5.008;
use strict;
use warnings;
use Padre::Wx        ();
use Padre::Documents ();

use base 'Padre::Wx::Submenu';

our $VERSION = '0.20';

sub new {
	my $class  = shift;
	my $main   = shift;
	my $config = Padre->ide->config;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Force-refresh the menu
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext('Reflow Menu/Toolbar') ),
		sub {
			$_[0]->menu->refresh;
			$_[0]->SetMenuBar( $_[0]->menu->wx );
			$_[0]->GetToolBar->refresh;
			return;
		},
	);

	# Recent projects
	$self->{recent_projects} = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("Recent Projects") . '...',
		$self->{recent_projects},
	);

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
			my $config = Padre->ide->config;
			$config->{ppi_highlight} = $_[1]->IsChecked ? 1 : 0;
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

	# Quick Find: Press F3 to start search with selected text
	$self->{quick_find} = $self->AppendCheckItem( -1, Wx::gettext("Quick Find") );
	Wx::Event::EVT_MENU( $main,
		$self->{quick_find},
		sub {
			$_[0]->on_quick_find(
				$self->{quick_find}->IsChecked
			),
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

	# Do an initial refresh
	$self->refresh;

	return $self;
}

# Update the checkstate for several menu items
sub refresh {
	my $self   = shift;
	my $config = Padre->ide->config;

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
