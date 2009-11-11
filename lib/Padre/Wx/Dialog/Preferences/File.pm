package Padre::Wx::Dialog::Preferences::File;

use 5.008;
use strict;
use warnings;

use Padre::Wx::Dialog::Preferences ();

our $VERSION = '0.50';
our @ISA     = 'Padre::Wx::Dialog::Preferences';

=pod

=head1 NAME

Padre::Wx::Dialog::Preferences::File - Preferences for Padre::File modules

=head1 DESCRIPTION

This modules provides preference options for the Padre::File - modules.

It uses the Padre preferences panel.

=cut

sub panel {
	my $self     = shift;
	my $treebook = shift;
	my $parent   = shift;

	my $config = Padre->ide->config;

	my $table = [

		# Padre::File::HTTP
		[   [ 'Wx::StaticText', undef, Wx::gettext('File access via HTTP') ],
			[]
		],
		[   [ 'Wx::StaticText', undef, Wx::gettext('Timeout:') ],
			[ 'Wx::SpinCtrl', 'file_http_timeout', $config->file_http_timeout, 10, 900 ]
		],

		# Padre::File::FTP
		[   [ 'Wx::StaticText', undef, Wx::gettext('File access via FTP') ],
			[]
		],
		[   [ 'Wx::StaticText', undef, Wx::gettext('Timeout:') ],
			[ 'Wx::SpinCtrl', 'file_ftp_timeout', $config->file_ftp_timeout, 10, 900 ]
		],
		[   [   'Wx::CheckBox', 'file_ftp_passive', ( $config->file_ftp_passive ? 1 : 0 ),
				Wx::gettext('Use FTP passive mode')
			],
			[]
		],

		#		[   [ 'Wx::StaticText', undef,     Wx::gettext('Sample text input:') ],
		#			[ 'Wx::TextCtrl',   'text_sample', $config->text_sample ]
		#		],
	];

	my $panel = $self->_new_panel($treebook);
	$parent->fill_panel_by_table( $panel, $table );

	return $panel;
}

sub save {
	my $self = shift;
	my $data = shift;

	my $config = Padre->ide->config;

	# Padre::File::HTTP

	$config->set(
		'file_http_timeout',
		$data->{file_http_timeout}
	);

	# Padre::File::FTP

	$config->set(
		'file_ftp_timeout',
		$data->{file_ftp_timeout}
	);

	$config->set(
		'file_ftp_passive',
		$data->{file_ftp_passive}
	);

}



1;
__END__

=pod

=head1 NEW OPTIONS

Adding new options is done in three steps:

=over

=item 1.

Add a C<setting()> call for the new option to F<Config.pm>

=item 2.

Add the GUI part to the C<panel> method

=item 3.

Save the new value within the C<save> method

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
