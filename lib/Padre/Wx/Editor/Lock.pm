package Padre::Wx::Editor::Lock;

# A read-only lock for Padre::Wx::Editor objects

use 5.008;
use strict;
use warnings;

our $VERSION = '0.94';

sub new {
	my $class  = shift;
	my $editor = shift;

	# We do not initially support nested locking
	return if $editor->GetReadOnly;

	# Lock the editor
	$editor->SetReadOnly(1);

	# Return the lock object
	return bless {
		editor => $editor,
	}, $class;
}

sub DESTROY {
	$_[0]->{editor} or return;
	$_[0]->{editor}->SetReadOnly(0);
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
