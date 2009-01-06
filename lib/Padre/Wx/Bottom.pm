package Padre::Wx::Bottom;

# The bottom notebook

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
		Wx::Size->new(350, 300), # used when pane is floated
		Wx::wxAUI_NB_SCROLL_BUTTONS
		| Wx::wxAUI_NB_WINDOWLIST_BUTTON
		| Wx::wxAUI_NB_TOP
		# |Wx::wxAUI_NB_TAB_EXTERNAL_MOVE crashes on Linux/GTK
		# TODO: Should we still use it for non-Linux?
	);

	# Add ourself to the window manager
	$main->manager->AddPane(
		$self,
		Wx::AuiPaneInfo->new
			->Name('bottompane')
			->CenterPane
			->Resizable(1)
			->PaneBorder(0)
			->Movable(1)
			->CaptionVisible(1)
			->CloseButton(0)
			->DestroyOnClose(0)
			->MaximizeButton(1)
			->Floatable(1)
			->Dockable(1)
			->Position(2)
			->Bottom
			->Layer(4)
			->Hide
	);

	# Set the locale-aware caption
	$main->manager->caption_gettext('bottompane' => 'Output View');

	return $self;
}

1;
