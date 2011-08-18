#!/usr/bin/perl

use strict;
use warnings;

#############################################################################
##
##
## Copyright:   (c) The Padre development team
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

my $app = Demo::ListView->new;
$app->MainLoop;

#####################

package Demo::ListView;

use strict;
use warnings;

use base 'Wx::App';

sub OnInit {
	my $frame = Demo::Frame->new;
	$frame->Show(1);
}

#####################

package Demo::Frame;

use strict;
use warnings;

use Wx ':everything';
use Wx::Event ':everything';

use base 'Wx::Frame';

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(
		undef,
		-1,
		'Notebook ',
		[ -1,  -1 ],
		[ 750, 700 ],
	);

	# Creating the notebook with tabs (also called panes)
	my $nb = Wx::Notebook->new(
		$self, -1, wxDefaultPosition, wxDefaultSize,
		wxNO_FULL_REPAINT_ON_RESIZE | wxCLIP_CHILDREN
	);

	# creating the content of the first tab
	my $editor = Wx::TextCtrl->new(
		$nb, -1, '', Wx::wxDefaultPosition, Wx::wxDefaultSize,
		wxTE_MULTILINE | wxNO_FULL_REPAINT_ON_RESIZE
	);

	# add first tab
	$nb->AddPage( $editor, 'Editor', 1 );

	my $choices = [
		'This example', 'was borrowed',
		'from an example', 'of the Wx::Demo', 'written by Mattia Barbon'
	];
	my $listbox = Wx::ListBox->new( $nb, -1, Wx::wxDefaultPosition, Wx::wxDefaultSize, $choices );
	$nb->AddPage( $listbox, 'Listbox', 1 );
	EVT_LISTBOX_DCLICK( $self, $listbox, \&on_listbox_double_click );

	return $self;
}

sub on_listbox_double_click {
	my $self  = shift;
	my $event = shift;
	Wx::MessageBox(
		"Double clicked: '" . $event->GetString . "'",
		'',
		Wx::wxOK | Wx::wxCENTRE,
		$self,
	);
}
