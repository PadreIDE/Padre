package Padre::Wx::Dialog::FilterTool;

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Icon ();

our $VERSION = '0.94';
our @ISA     = 'Wx::Dialog';

use Class::XSAccessor {
	accessors => {
		_butrun => '_butrun', # run button
		_combo  => '_combo',  # combo box
		_names  => '_names',  # list of all recent commands
		_sizer  => '_sizer',  # the window sizer
	}
};

# -- constructor

sub new {
	my ( $class, $parent ) = @_;

	# create object
	my $self = $class->SUPER::new(
		$parent,
		-1,
		Wx::gettext('Filter through tool'),
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::DEFAULT_FRAME_STYLE | Wx::TAB_TRAVERSAL,
	);
	$self->SetIcon(Padre::Wx::Icon::PADRE);

	# create dialog
	$self->_create;

	return $self;
}

# -- public methods

sub show {
	my $self = shift;
	$self->_refresh_combo;
	$self->Show;
}

# -- gui handlers

#
# $self->_on_butclose_clicked;
#
# handler called when the close button has been clicked.
#
sub _on_butclose_clicked {
	my $self = shift;
	$self->Destroy;
}

#
# $self->_on_butrun_clicked;
#
# handler called when the run button has been clicked.
#
sub _on_butrun_clicked {
	my $self = shift;

	my $main = $self->GetParent;

	my $tool = $self->_combo->GetValue;

	if ( defined($tool) and ( $tool ne '' ) ) {

		#		$filtertool = Padre::DB::FilterTool->new(
		#			name        => $self->_combo->GetValue,
		#			last_update => time,
		#		);
		#		$filtertool->insert;

		$main->filter_tool($tool);

	}

	# close dialog
	$self->Destroy;
}

# -- private methods

#
# $self->_create;
#
# create the dialog itself.
#
# no params, no return values.
#
sub _create {
	my $self = shift;

	# create sizer that will host all controls
	my $box = Wx::BoxSizer->new(Wx::VERTICAL);
	my $sizer = Wx::GridBagSizer->new( 5, 5 );
	$sizer->AddGrowableCol(1);
	$box->Add( $sizer, 1, Wx::EXPAND | Wx::ALL, 5 );
	$self->_sizer($sizer);

	$self->_create_fields;
	$self->_create_buttons;
	$self->SetSizer($box);
	$box->SetSizeHints($self);
	$self->CenterOnParent;
	$self->_combo->SetFocus;

}

#
# $dialog->_create_fields;
#
# create the combo box with the recent commands.
#
# no params. no return values.
#
sub _create_fields {
	my $self  = shift;
	my $sizer = $self->_sizer;

	my $lab1 = Wx::StaticText->new( $self, -1, Wx::gettext('Filter command:') );
	my $combo = Wx::ComboBox->new( $self, -1, '' );
	$sizer->Add( $lab1, Wx::GBPosition->new( 0, 0 ) );
	$sizer->Add( $combo, Wx::GBPosition->new( 0, 1 ), Wx::GBSpan->new( 1, 3 ), Wx::EXPAND );
	$self->_combo($combo);

}

#
# $dialog->_create_buttons;
#
# create the buttons pane.
#
# no params. no return values.
#
sub _create_buttons {
	my $self = shift;

	my $sizer = $self->_sizer;

	# the buttons
	my $bs = Wx::Button->new( $self, Wx::ID_OK,     Wx::gettext('Run') );
	my $bc = Wx::Button->new( $self, Wx::ID_CANCEL, Wx::gettext('Close') );
	Wx::Event::EVT_BUTTON( $self, $bs, \&_on_butrun_clicked );
	Wx::Event::EVT_BUTTON( $self, $bc, \&_on_butclose_clicked );
	$sizer->Add( $bs, Wx::GBPosition->new( 2, 2 ) );
	$sizer->Add( $bc, Wx::GBPosition->new( 2, 3 ) );

	$bs->SetDefault;

	$self->_butrun($bs);
}

#
# $dialog->_refresh_combo;
#
# refresh combo box
#
sub _refresh_combo {
	my ( $self, $column, $reverse ) = @_;

	# get list of recent commands, sorted.
	#	my @names = map { $_->name } Padre::DB::FilterTool->select('ORDER BY name');
	#	$self->_names( \@names );

	# clear list & fill it again
	my $combo = $self->_combo;
	$combo->Clear;

	#	$combo->Append($_) foreach @names;
}


1;

__END__


=head1 NAME

Padre::Wx::Dialog::FilterTool - dialog to filter selection or document through an external tool



=head1 DESCRIPTION

This dialog asks for the tool which should be used to filter the current
selection or the whole document.


=head1 PUBLIC API

=head2 Constructor

=head3 C<new>

    my $dialog = Padre::Wx::Dialog::FilterTool->new( $parent )

Create and return a new Wx dialog allowing to select a filter tool. It needs a
C<$parent> window (usually Padre's main window).

=head2 Public methods

=head3 C<show>

    $dialog->show;

Request the dialog to be shown.


=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5 itself.


=cut


# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
