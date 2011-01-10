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
	my ($class) = @_;

	my $self = $class->SUPER::new(
		undef,
		-1,
		'Wx::TextCtrl',
		[ -1,  -1 ],
		[ 750, 700 ],
	);

	my $box = Wx::BoxSizer->new(wxVERTICAL);

	my $editor = Wx::TextCtrl->new(
		$self, -1, '', Wx::wxDefaultPosition, Wx::wxDefaultSize,
		wxTE_MULTILINE | wxNO_FULL_REPAINT_ON_RESIZE | wxTE_READONLY
	);

	# http://docs.wxwidgets.org/2.8.10/wx_wxtextctrl.html

	my $content = '';
	if ( open my $in, '<', $0 ) {
		local $/ = undef;
		$content = <$in>;
	}
	$editor->SetValue($content);


	$box->Add( $editor, 1, wxGROW );

	my $close = Wx::Button->new( $self, -1, '&Close' );
	$box->Add( $close, 0, wxALIGN_CENTER_HORIZONTAL ); # http://docs.wxwidgets.org/2.8.10/wx_sizeroverview.html
	EVT_BUTTON( $self, $close, \&on_exit );

	$self->SetAutoLayout(1);
	$self->SetSizer($box);

	# $box->Fit( $self );
	# $box->SetSizeHints( $self );

	return $self;
}

sub on_exit {
	my ($self) = @_;
	$self->Close;
}


