package Padre::Wx::Menu::Perl;

# Fully encapsulated Run menu

use 5.008;
use strict;
use warnings;
use Params::Util       ();
use Padre::Wx          ();
use Padre::Wx::Menu ();

our $VERSION = '0.24';
our @ISA     = 'Padre::Wx::Menu';





#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Perl-Specific Searches
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext("Find Unmatched Brace") ),
		sub {
			my $doc = $_[0]->current->document;
			return unless Params::Util::_INSTANCE($doc, 'Padre::Document::Perl');
			$doc->find_unmatched_brace;
		},
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext("Find variable declaration") ),
		sub {
			my $doc = $_[0]->current->document;
			return unless Params::Util::_INSTANCE($doc, 'Padre::Document::Perl');
			$doc->find_variable_declaration;
		},
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext("Lexically replace variable") ),
		sub {
			my $doc = $_[0]->current->document;
			return unless Params::Util::_INSTANCE($doc, 'Padre::Document::Perl');
			my $dialog = Padre::Wx::History::TextDialog->new(
				$_[0],
				Wx::gettext("Replacement"),
				Wx::gettext("Replacement"),
				'$foo',
			);
			if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
				return;
			}
			my $replacement = $dialog->GetValue;
			$dialog->Destroy;
			return unless defined $replacement;

			$doc->lexical_variable_replacement($replacement);
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
			# TODO try to delay the actual color updating for the
			# pages that are not in focus till they get in focus
			foreach my $editor ( $_[0]->pages ) {
				my $doc = $editor->{Document};
				next unless $doc->isa('Padre::Document::Perl');
				$editor->SetLexer( $doc->lexer );
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
	
	# Make it easier to access stack traces
	$self->{run_with_stack_trace} = $self->AppendCheckItem( -1,
		Wx::gettext("Run perl scripts with stack trace")
	);	
	Wx::Event::EVT_MENU( $main, $self->{run_with_stack_trace},
		sub {
			# Update the saved config setting
			my $config = Padre->ide->config;
			$config->{run_with_stack_trace} = $_[1]->IsChecked ? 1 : 0;
			$self->refresh;
		}
	);


	return $self;
}

sub refresh {
	my $self     = shift;
	my $config   = Padre->ide->config;

	$self->{ppi_highlight}->Check( $config->{ppi_highlight} ? 1 : 0 );
	$self->{run_with_stack_trace}->Check( $config->{run_with_stack_trace} ? 1 : 0 );
	$Padre::Document::MIME_LEXER{'application/x-perl'} = 
		$config->{ppi_highlight}
			? Wx::wxSTC_LEX_CONTAINER
			: Wx::wxSTC_LEX_PERL;
}

1;
