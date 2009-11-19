package Padre::Wx::Dialog::Preferences::PerlAutoComplete;

use warnings;
use strict;
use 5.008;

use Padre::Wx::Dialog::Preferences ();

our $VERSION = '0.03';
our @ISA     = 'Padre::Wx::Dialog::Preferences';

sub panel {
	my $self     = shift;
	my $treebook = shift;
	my $parent   = shift;

	my $config = Padre->ide->config;

	my $table = [

		#		[   [   'Wx::CheckBox', 'editor_wordwrap', ( $config->editor_wordwrap ? 1 : 0 ),
		#				Wx::gettext('Default word wrap on for each file')
		#			],
		#			[]
		#		],
#		[   [ 'Wx::StaticText', undef,     Wx::gettext('Perl interpreter:') ],
#			[ 'Wx::TextCtrl',   'Perl_cmd', $config->Perl_cmd ]
#		],
#		[   [ 'Wx::StaticText', undef,                          Wx::gettext('Perl interpreter arguments:') ],
#			[ 'Wx::TextCtrl',   'Perl_interpreter_args_default', $config->Perl_interpreter_args_default ]
#		],
		[   [   'Wx::CheckBox',
				'autocomplete_always',
				( $config->autocomplete_always ? 1 : 0 ),
				Wx::gettext("Autocomplete always while typing")
			],
			[]
		],
		[   [   'Wx::CheckBox',
				'autocomplete_method',
				( $config->autocomplete_method ? 1 : 0 ),
				Wx::gettext("Autocomplete new methods in packages")
			],
			[]
		],
		[   [ 'Wx::StaticText', undef, Wx::gettext('Max. number of suggestions:') ],
			[ 'Wx::SpinCtrl', 'perl_autocomplete_max_suggestions', $config->perl_autocomplete_max_suggestions, 5, 255 ]
		],
	];

	my $panel = $self->_new_panel($treebook);
	$parent->fill_panel_by_table( $panel, $table );

	return $panel;
}

sub save {
	my $self = shift;
	my $data = shift;

	my $config = Padre->ide->config;

	$config->set(
		'autocomplete_always',
		$data->{autocomplete_always} ? 1 : 0
	);

	$config->set(
		'autocomplete_method',
		$data->{autocomplete_method} ? 1 : 0
	);

	$config->set(
		'perl_autocomplete_max_suggestions',
		$data->{perl_autocomplete_max_suggestions}
		);

}



1;
__END__

=head1 NAME

Padre::Wx::Dialog::Preferences::PerlAutoComplete
 - L<Padre> config options for the Perl autocomplete feature

=head1 DESCRIPTION

Show user-configurable options for autocomplete in Perl scripts.

It uses the Padre preferences panel.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it under the
same terms as Perl 5 itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
