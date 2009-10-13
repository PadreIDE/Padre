package Padre::Current;

# A context object, for centralising the concept of what is "current"

use 5.008;
use strict;
use warnings;
use Carp         ();
use Exporter     ();
use Params::Util ();

our $VERSION   = '0.48';
our @ISA       = 'Exporter';
our @EXPORT_OK = '_CURRENT';





#####################################################################
# Exportable Functions

# This is an importable convenience function.
# It's current not as efficient as it should be, but once the majority
# of the context-sensitive code has been migrated over, we should be
# able to simplify it quite a bit.
sub _CURRENT {

	# Most likely options
	unless ( defined $_[0] ) {
		return Padre::Current->new;
	}
	if ( Params::Util::_INSTANCE( $_[0], 'Padre::Current' ) ) {
		return shift;
	}

	# Fallback options
	if ( Params::Util::_INSTANCE( $_[0], 'Padre::Document' ) ) {
		return Padre::Current->new( document => shift );
	}

	return Padre::Current->new;
}





#####################################################################
# Constructor

sub new {
	my $class = shift;
	bless {@_}, $class;
}





#####################################################################
# Context Methods

# Get the project from the document (and don't cache)
sub project {
	my $self = ref( $_[0] ) ? $_[0] : $_[0]->new;
	my $document = $self->document;
	if ( defined $document ) {
		return $document->project;
	} else {
		return;
	}
}

# Get the text from the editor (and don't cache)
sub text {
	my $self = ref( $_[0] ) ? $_[0] : $_[0]->new;
	my $editor = $self->editor;
	return '' unless defined $editor;
	return $editor->GetSelectedText;
}

# Get the title of the current editor window (and don't cache)
sub title {
	my $self     = ref( $_[0] ) ? $_[0] : $_[0]->new;
	my $notebook = $self->notebook;
	my $selected = $notebook->GetSelection;
	if ( $selected >= 0 ) {
		return $notebook->GetPageText($selected);
	} else {
		return;
	}
}

# Get the filename from the document
sub filename {
	my $self = ref( $_[0] ) ? $_[0] : $_[0]->new;
	unless ( exists $self->{filename} ) {
		my $document = $self->document;
		if ( defined $document ) {
			$self->{filename} = $document->filename;
		} else {
			$self->{filename} = undef;
		}
	}
	return $self->{filename};
}

# Get the document from the editor
sub document {
	my $self = ref( $_[0] ) ? $_[0] : $_[0]->new;
	unless ( exists $self->{document} ) {
		my $editor = $self->editor;
		if ( defined $editor ) {
			$self->{document} = $editor->{Document};
		} else {
			$self->{document} = undef;
		}
	}
	return $self->{document};
}

# Derive the editor from the document
sub editor {
	my $self = ref( $_[0] ) ? $_[0] : $_[0]->new;
	unless ( exists $self->{editor} ) {
		my $notebook = $self->notebook;
		if ( defined($notebook) ) {
			my $selected = $notebook->GetSelection;
			if ( $selected == -1 ) {
				$self->{editor} = undef;
			} elsif ( $selected >= $notebook->GetPageCount ) {
				$self->{editor} = undef;
			} else {
				$self->{editor} = $notebook->GetPage($selected);
				unless ( $self->{editor} ) {
					Carp::croak("Failed to find page");
				}
			}
		}
	}
	return $self->{editor};
}

# Convenience method
sub notebook {
	my $self = ref( $_[0] ) ? $_[0] : $_[0]->new;
	unless ( defined $self->{notebook} ) {
		$self->{notebook} = $self->main->notebook;
	}
	return $self->{notebook};
}

# Get the project from the main window (and don't cache)
sub config {
	my $self = ref( $_[0] ) ? $_[0] : $_[0]->new;
	$self->main->config;
}

# Convenience method
sub main {
	my $self = ref( $_[0] ) ? $_[0] : $_[0]->new;

	# floating windows (Wx::AuiFloatingFrame) may
	# call us passing $self as an argument, so
	# we short-circuit them if they're docked
	if ( $_[1] ) {
		my $parent = $_[1]->main;
		return $parent if ref $parent eq 'Padre::Wx::Main';
	}
	unless ( defined $self->{main} ) {
		if ( defined $self->{ide} ) {
			$self->{main} = $self->{ide}->wx->main;
		} else {
			require Padre;
			$self->{ide}  = Padre->ide;
			$self->{main} = $self->{ide}->wx->main;
		}
		return $self->{main};
	}
	return $self->{main};
}

# Convenience method
sub ide {
	my $self = ref( $_[0] ) ? $_[0] : $_[0]->new;
	unless ( defined $self->{ide} ) {
		if ( defined $self->{main} ) {
			$self->{ide} = $self->{main}->ide;
		} else {
			require Padre;
			$self->{ide} = Padre->ide;
		}
	}
	return $self->{ide};
}

1;

__END__

=pod

=head1 NAME

Padre::Current - convenient access to current objects within Padre

=head1 SYNOPSIS

	my $main = Padre::Current->main;
	...

=head1 DESCRIPTION

Padre uses lots of objects from different classes. And one needs to
have access to the current object of this sort or this other to do
whatever is need at the time.

Instead of poking directly with the various classes to find the object
you need, C<Padre::Current> provides a bunch of handy methods to
retrieve whatever current object you need.

=head1 METHODS

=head2 new

  # Vanilla constructor
  Padre::Current->new;
  
  # Seed the object with some context
  Padre::Current->new( document => $document );

The C<new> constructor creates a new context object, it optionally takes
one or more named parameters which should be any context the caller is
aware of before he calls the constructor.

Providing this seed context allows the context object to derive parts of
the current context from other parts, without the need to fall back to
the last-resort C<Padre-E<gt>ide> singleton-fetching method.

Many objects in L<Padre> that are considered to be part of them context
will have a C<current> method which automatically creates the context
object with it as a seed.

Returns a new B<Padre::Current> object.

=head2 ide

Return the L<Padre> singleton for the IDE instance.

=head2 config

Returns the current L<Padre::Config> configuration object for the IDE.

=head2 main

Returns the L<Padre::Wx::Main> object for the main window.

=head2 notebook

Returns the L<Padre::Wx::Notebook> object for the main window.

=head2 document

Returns the active L<Padre::Document> document object.

=head2 editor

Returns the L<Padre::Editor> editor object for the active document.

=head2 filename

Returns the filename of the active document, if it has one.

=head2 title

Return the title of current editor window.

=head2 project

Return the C<Padre::Project> project object for the active document.

=head2 text

Returns the selected text, or a null string if nothing is selected.

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
