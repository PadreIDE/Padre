package Padre::Wx::Notebook;

use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.24';
our @ISA     = 'Wx::AuiNotebook';

sub new {
	my $class = shift;
	my $main  = shift;
	my $self  = $class->SUPER::new(
		$main,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxAUI_NB_TOP
		| Wx::wxBORDER_NONE
		| Wx::wxAUI_NB_SCROLL_BUTTONS
		| Wx::wxAUI_NB_CLOSE_ON_ACTIVE_TAB
		| Wx::wxAUI_NB_WINDOWLIST_BUTTON,
	);

	# Add ourself to the main window
	$main->aui->AddPane(
		$self,
		Wx::AuiPaneInfo->new
			->Name('editorpane')
 			->CenterPane
			->Resizable(1)
			->PaneBorder(0)
			->Movable(1)
			->CaptionVisible(0)
			->CloseButton(0)
			->MaximizeButton(0)
			->Floatable(1)
			->Dockable(1)
			->Layer(1)
	);
	$main->aui->caption_gettext('editorpane' => 'Files');

	Wx::Event::EVT_AUINOTEBOOK_PAGE_CHANGED(
		$main,
		$self,
		sub {
			shift->on_notebook_page_changed(@_);
		},
	);

	Wx::Event::EVT_AUINOTEBOOK_PAGE_CLOSE(
		$main,
		$self,
		sub {
			shift->on_close(@_);
		},
	);

	return $self;
}

sub main {
	$_[0]->GetParent;
}

1;
