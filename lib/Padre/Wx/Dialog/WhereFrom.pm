package Padre::Wx::Dialog::WhereFrom;

use 5.008;
use strict;
use warnings;
use Padre::Wx               ();
use Padre::Wx::Dialog       ();
use Padre::Task::HTTPClient ();

our $VERSION = '0.58';

sub new {
	my ( $class, $window ) = @_;

	my $config = Padre->ide->config;
	return if $config->feedback_done;

	my @layout = (
		[   [ 'Wx::StaticText', undef, Wx::gettext('Where did you hear about Padre?') ],
			[   'Wx::ComboBox',
				'_referer_',
				'',
				[   'Google',
					Wx::gettext('Other searchengine'),
					'FOSDEM',
					'CeBit',
					Wx::gettext('Other event'),
					Wx::gettext('Friend'),
					Wx::gettext('Reinstalling/Installing on other computer'),
					Wx::gettext('Other (Please fill in here)'),
				]
			],
		],
		[   [ 'Wx::Button', '_ok_', Wx::wxID_OK ], [],
			[ 'Wx::Button', '_cancel_', Wx::gettext("Skip feedback") ],
		],
	);

	my $dialog = Padre::Wx::Dialog->new(
		parent => $window,
		title  => Wx::gettext("New installation survey"),
		layout => \@layout,
		width  => [ 200, 300 ],
		bottom => 20,
	);
	$dialog->{_widgets_}{_ok_}->SetDefault;
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}{_ok_},     \&WhereFrom_ok_clicked );
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}{_cancel_}, \&WhereFrom_cancel_clicked );

	$dialog->{_widgets_}{_referer_}->SetFocus;
	$dialog->Show(1);

	return 1;
}

sub WhereFrom_cancel_clicked {
	my ( $dialog, $event ) = @_;

	my $config = Padre->ide->config;

	if ( !$config->feedback_done ) {
		$config->set( 'feedback_done', 1 );
		$config->write;
	}

	$dialog->Destroy;
}

sub WhereFrom_ok_clicked {
	my ( $dialog, $event ) = @_;

	my $config = Padre->ide->config;

	my $window = $dialog->GetParent;
	my $data   = $dialog->get_data;
	$dialog->Destroy;

	if ( !$config->feedback_done ) {

		my $url  = 'http://padre.perlide.org/wherefrom.cgi';
		my $args = { from => $data->{_referer_} };
		my $http = Padre::Task::HTTPClient->new(
			URL   => $url,
			query => $args,
		)->run;

		$config->set( 'feedback_done', 1 );
		$config->write;

	}

	return;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
