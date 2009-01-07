package Padre::Wx::Menu::Perl;

# Fully encapsulated Run menu

use 5.008;
use strict;
use warnings;
use Params::Util    ();
use Padre::Wx       ();
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

	# Module-Related Functions
	$self->{module} = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("Install Module..."),
		$self->{module}
	);

	# Install modules from CPAN
	$self->{module_install_cpan} = $self->{module}->Append( -1,
		Wx::gettext("Install CPAN Module"),
	);
	Wx::Event::EVT_MENU( $main,
		$self->{module_install_cpan},
		sub {
			$self->install_cpan($_[0]);
		},
	);

	$self->{module}->AppendSeparator;

	# Install from other places
	$self->{module_install_file} = $self->{module}->Append( -1,
		Wx::gettext("Install Local Distribution"),
	);
	Wx::Event::EVT_MENU( $main,
		$self->{module_install_file},
		sub {
			$self->install_file($_[0]);
		},
	);

	$self->{module_install_url} = $self->{module}->Append( -1,
		Wx::gettext("Install Remote Distribution"),
	);
	Wx::Event::EVT_MENU( $main,
		$self->{module_install_url},
		sub {
			$self->install_url($_[0]);
		},
	);

	$self->{module}->AppendSeparator;

	# Utility Operations
	$self->{module_edit_cpan} = $self->{module}->Append( -1,
		Wx::gettext("Open CPAN::Config"),
	);
	Wx::Event::EVT_MENU( $main,
		$self->{module_edit_cpan},
		sub {
			$self->edit_config($_[0]);
		},
	);

	$self->AppendSeparator;





	# Perl-Specific Searches
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Find Unmatched Brace")
		),
		sub {
			my $doc = $_[0]->current->document;
			return unless Params::Util::_INSTANCE($doc, 'Padre::Document::Perl');
			$doc->find_unmatched_brace;
		},
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext("Find Variable Declaration") ),
		sub {
			my $doc = $_[0]->current->document;
			return unless Params::Util::_INSTANCE($doc, 'Padre::Document::Perl');
			$doc->find_variable_declaration;
		},
	);

	$self->AppendSeparator;





	# Perl-Specific Refactoring
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext("Lexically Rename Variable") ),
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

	$self->AppendSeparator;





	# Perl-Specific Options
	$self->{ppi_highlight} = $self->AppendCheckItem( -1,
		Wx::gettext("Use PPI Syntax Highlighting")
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
		Wx::gettext("Run Scripts with Stack Trace")
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
	my $self   = shift;
	my $config = Padre->ide->config;

	$self->{ppi_highlight}->Check( $config->{ppi_highlight} ? 1 : 0 );
	$self->{run_with_stack_trace}->Check( $config->{run_with_stack_trace} ? 1 : 0 );
	$Padre::Document::MIME_LEXER{'application/x-perl'} = 
		$config->{ppi_highlight}
			? Wx::wxSTC_LEX_CONTAINER
			: Wx::wxSTC_LEX_PERL;
}





#####################################################################
# Menu Event Methods

sub install_file {
	my $self = shift;
	my $main = shift;
	$main->error("TO BE COMPLETED");
}

sub install_url {
	my $self = shift;
	my $main = shift;
	$main->error("TO BE COMPLETED");
}

sub install_cpan {
	my $self = shift;
	my $main = shift;
	$main->error("TO BE COMPLETED");
}

sub edit_config {
	my $self = shift;
	my $main = shift;
	$main->error("TO BE COMPLETED");
}

1;
