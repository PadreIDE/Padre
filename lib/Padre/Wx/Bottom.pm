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

	# Create the platform-sensitive style
	my $style = Wx::wxAUI_NB_SCROLL_BUTTONS
	          | Wx::wxAUI_NB_TOP;
	unless ( Padre::Util::WXGTK ) {
		# Crashes on Linux/GTK
		# Doesn't seem to work right on Win32...
		# $style = $style | Wx::wxAUI_NB_TAB_EXTERNAL_MOVE;
	}

	my $self  = $class->SUPER::new(
		$main,
		-1,
		Wx::wxDefaultPosition,
		Wx::Size->new(350, 300), # used when pane is floated
		$style,
	);

	# Add ourself to the window manager
	$main->aui->AddPane(
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
	$main->aui->caption_gettext('bottompane' => 'Output View');

	return $self;
}

1;
