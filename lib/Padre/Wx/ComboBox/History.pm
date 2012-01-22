package Padre::Wx::ComboBox::History;

=pod

=head1 NAME

Padre::Wx::ComboBox::History - A history-enabled Wx combobox

=head1 SYNOPSIS

  $dialog->{search_text} = Padre::Wx::ComboBox::History->new(
      $self,
      -1,
      '', # Use the last history value
      Wx::DefaultPosition,
      Wx::DefaultSize,
      [ 'search' ], # The history queue to read from
  );

=head1 DESCRIPTION

Padre::Wx::ComboBox::History is a normal Wx ComboBox widget, but enhanced
with the ability to remember previously entered values and present the
previous values as options the next time it is used.

This type of input memory is fairly common in dialog boxes and other task
inputs. The parameters are provided to the history box in a form compatible
with an ordinary Wx::ComboBox to simplify integration with GUI generators
such as L<Padre::Plugin::FormBuilder>.

The "options" hash should contain exactly one value, which should be the
key string for the history table. This can be a simple name, allowing the
sharing of remembered history across several different dialogs.

The "value" can be defined literally, or will be pulled from the most
recent history entry if it set to the null string.

=cut

use 5.008;
use strict;
use warnings;
use Padre::Wx ();
use Padre::DB ();

our $VERSION = '0.94';
our @ISA     = 'Wx::ComboBox';

sub new {
	my $class  = shift;
	my @params = @_;

	# First key in the value list to overwrite with the history values.
	my $type = $params[5]->[0];
	if ($type) {
		$params[5] = [ Padre::DB::History->recent($type) ];

		# Initial text defaults to empty string
		$params[2] ||= '';
	}

	my $self = $class->SUPER::new(@params);

	# Save the type, we'll need it later.
	$self->{type} = $type;

	$self;
}

sub refresh {
	my $self = shift;
	my $text = shift;
	$text = '' unless defined $text;
	$text = '' if $text =~ /\n/;

	# Refresh the recent values
	my @recent = Padre::DB::History->recent( $self->{type} );

	# Update the Wx object from the list
	$self->Clear;
	if ( length $text ) {
		$self->SetValue($text);
		unless ( grep { $text eq $_ } @recent ) {
			$self->Append($text);
		}
	}
	foreach my $option (@recent) {
		$self->Append($option);
	}

	return 1;
}

# Save the current value of the combobox and return it as per GetValue
sub SaveValue {
	my $self  = shift;
	my $value = $self->GetValue;

	# If this is a value is not in our existing recent list, save it
	if ( length $value ) {
		if ( $self->FindString($value) == Wx::NOT_FOUND ) {
			Padre::DB::History->create(
				type => $self->{type},
				name => $value,
			);
		}
	}

	return $value;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
