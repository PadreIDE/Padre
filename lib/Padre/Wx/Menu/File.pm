package Padre::Wx::Menu::File;

# Fully encapsulated File menu

use 5.008;
use strict;
use warnings;
use Padre::Wx          ();
use Padre::Wx::Menu ();
use Padre::Current     qw{_CURRENT};

our $VERSION = '0.25';
our @ISA     = 'Padre::Wx::Menu';





#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);





	# Create new things
	$self->{new} = $self->Append(
		Wx::wxID_NEW,
		Wx::gettext("&New\tCtrl-N"),
	);
	#$self->{new}->SetBitmap(
	#	Padre::Wx::gnome('actions', 'document-new.png')
	#);
	Wx::Event::EVT_MENU( $main,
		$self->{new},
		sub {
			$_[0]->on_new;
		},
	);

	my $file_new = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("New..."),
		$file_new,
	);
	Wx::Event::EVT_MENU( $main,
		$file_new->Append( -1,
			Wx::gettext('Perl Distribution (Module::Starter)')
		),
		sub {
			require Padre::Wx::Dialog::ModuleStart;
			Padre::Wx::Dialog::ModuleStart->start($_[0]);
		},
	);





	# Open and close files
	Wx::Event::EVT_MENU( $main,
		$self->Append(
			Wx::wxID_OPEN,
			Wx::gettext("&Open...\tCtrl-O")
		),
		sub {
			$_[0]->on_open;
		},
	);

	$self->{open_selection} = $self->Append( -1,
		Wx::gettext("Open Selection\tCtrl-Shift-O")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{open_selection},
		sub {
			$_[0]->on_open_selection;
		},
	);

	$self->{close} = $self->Append(
		Wx::wxID_CLOSE,
		Wx::gettext("&Close\tCtrl-W"),
	);
	Wx::Event::EVT_MENU( $main,
		$self->{close},
		sub {
			$_[0]->on_close;
		},
	);

	$self->{close_all} = $self->Append( -1,
		Wx::gettext('Close All')
	);
	Wx::Event::EVT_MENU( $main,
		$self->{close_all},
		sub {
			$_[0]->on_close_all;
		},
	);
	$self->{close_all_but_current} = $self->Append( -1,
		Wx::gettext('Close All but Current')
	);
	Wx::Event::EVT_MENU( $main,
		$self->{close_all_but_current},
		sub {
			$_[0]->on_close_all_but_current;
		},
	);
	$self->{reload_file} = $self->Append( -1,
		Wx::gettext('Reload file')
	);
	Wx::Event::EVT_MENU( $main,
		$self->{reload_file},
		sub {
			$_[0]->on_reload_file;
		},
	);

	$self->AppendSeparator;





	# Save files
	$self->{save} = $self->Append(
		Wx::wxID_SAVE,
		Wx::gettext("&Save\tCtrl-S")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{save},
		sub {
			$_[0]->on_save;
		},
	);
	$self->{save_as} = $self->Append(
		Wx::wxID_SAVEAS,
		Wx::gettext("Save &As...\tF12")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{save_as},
		sub {
			$_[0]->on_save_as;
		},
	);
	$self->{save_all} = $self->Append( -1,
		Wx::gettext('Save All')
	);
	Wx::Event::EVT_MENU( $main,
		$self->{save_all},
		sub {
			$_[0]->on_save_all;
		},
	);

	$self->AppendSeparator;





	# Print files
	$self->{print} = $self->Append(
		Wx::wxID_PRINT,
		Wx::gettext('&Print...'),
	);
	Wx::Event::EVT_MENU( $main,
		$self->{print},
		sub {
			require Wx::Print;
			require Padre::Wx::Printout;
			my $printer  = Wx::Printer->new;
			my $printout = Padre::Wx::Printout->new(
				$_[0]->current->editor, "Print",
			);
			$printer->Print( $_[0], $printout, 1 );
			$printout->Destroy;
			return;
		},
	);

	$self->AppendSeparator;





	# Conversions and Transforms
	$self->{convert_nl} = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("Convert..."),
		$self->{convert_nl}
	);

	$self->{convert_nl_windows} = $self->{convert_nl}->Append( -1,
		Wx::gettext("EOL to Windows")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{convert_nl_windows},
		sub {
			$_[0]->convert_to("WIN");
		},
	);

	$self->{convert_nl_unix} = $self->{convert_nl}->Append(-1,
		Wx::gettext("EOL to Unix")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{convert_nl_unix},
		sub {
			$_[0]->convert_to("UNIX");
		},
	);

	$self->{convert_nl_mac} = $self->{convert_nl}->Append(-1,
		Wx::gettext("EOL to Mac Classic")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{convert_nl_mac},
		sub {
			$_[0]->convert_to("MAC");
		},
	);

	$self->AppendSeparator;





	# Recent things
	$self->{recentfiles} = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("&Recent Files"),
		$self->{recentfiles}
	);
	Wx::Event::EVT_MENU( $main,
		$self->{recentfiles}->Append(-1,
			Wx::gettext("Open All Recent Files")
		),
		sub {
			$_[0]->on_open_all_recent_files;
		},
	);
	Wx::Event::EVT_MENU( $main,
		$self->{recentfiles}->Append( -1,
			Wx::gettext("Clean Recent Files List")
		),
		sub {
			Padre::DB::History->delete('where type = ?', 'files');

			# Replace the whole File menu
			my $menu       = Padre::Wx::Menu::File->new($_[0]);
			my $menu_place = $_[0]->menu->wx->FindMenu(
				Wx::gettext("&File")
			);
			$_[0]->menu->wx->Replace(
				$menu_place => $menu->wx,
				Wx::gettext("&File")
			);
		},
	);

	$self->{recentfiles}->AppendSeparator;

	my $idx = 0;
	foreach my $file ( grep { -f } Padre::DB->get_recent_files ) {
		Wx::Event::EVT_MENU( $main,
			$self->{recentfiles}->Append( -1,
				++$idx < 10 ? "&$idx. $file" : "$idx. $file"
			),
			sub {
				$_[0]->setup_editors($file);
			},
		);
	}

	$self->AppendSeparator;





	# Word Stats
	$self->{docstat} = $self->Append( -1,
		Wx::gettext('Doc Stats')
	);
	Wx::Event::EVT_MENU( $main,
		$self->{docstat},
		sub {
			$_[0]->on_doc_stats;
		},
	);

	$self->AppendSeparator;





	# Exiting
	Wx::Event::EVT_MENU( $main,
		$self->Append(
			Wx::wxID_EXIT,
			Wx::gettext("&Quit\tCtrl-Q")
		),
		sub {
			$_[0]->Close;
		},
	);





	return $self;
}

sub refresh {
	my $self     = shift;
	my $current  = _CURRENT(@_);
	my $doc      = $current->document ? 1 : 0;

	$self->{ open_selection        }->Enable($doc);
	$self->{ close                 }->Enable($doc);
	$self->{ close_all             }->Enable($doc);
	$self->{ close_all_but_current }->Enable($doc);
	$self->{ reload_file           }->Enable($doc);
	$self->{ save                  }->Enable($doc);
	$self->{ save_as               }->Enable($doc);
	$self->{ save_all              }->Enable($doc);
	$self->{ print                 }->Enable($doc);
	$self->{ convert_nl_windows    }->Enable($doc);
	$self->{ convert_nl_unix       }->Enable($doc);
	$self->{ convert_nl_mac        }->Enable($doc);
	$self->{ docstat               }->Enable($doc);

	return 1;
}

1;
