package Padre::Wx::Dialog::WhereFrom;

use 5.008;
use strict;
use warnings;
use Padre::Role::Task         ();
use Padre::Wx::FBP::WhereFrom ();

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::FBP::WhereFrom
};

use constant SERVER => 'http://perlide.org/popularity/v1/wherefrom.html';

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	# Fill options
	my $choices = [
		'Google',
		Wx::gettext('Other search engine'),
		'FOSDEM',
		'CeBit',
		Wx::gettext('Other event'),
		Wx::gettext('Friend'),
		Wx::gettext('Reinstalling/installing on other computer'),
		Wx::gettext('Padre Developer'),
		Wx::gettext('Other (Please fill in here)'),
	];
	$self->{from}->Append($choices);

	# Prepare to be shown
	$self->CenterOnParent;
	$self->Fit;

	return $self;
}

sub run {
	my $self   = shift;
	my $config = $self->config;

	# Show the dialog
	if ( $self->ShowModal == Wx::ID_OK ) {

		# Fire and forget the HTTP request to the server
		$self->task_request(
			task  => 'Padre::Task::LWP',
			url   => SERVER,
			query => {
				from => $self->{from}->GetValue,
			},
		);
	}

	# Don't ask again
	$config->set( nth_feedback => 1 );
	$config->write;

	return 1;
}

1;


# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
