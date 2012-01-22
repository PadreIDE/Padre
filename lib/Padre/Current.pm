package Padre::Current;

=pod

=head1 NAME

Padre::Current - A context object, for centralising the concept of what is "current"

=head1 DESCRIPTION

The C<Padre::Current> detectes and returns whatever is current. Use it whenever you
need to do something with anything which might get a focus or be selectable otherwise

All methods could be called as functions, methods or class methods.

=head1 CLASS METHODS

=head2 C<config>

    my $config = Padre::Current->config;

Returns a Padre::Config object for the current document.

Padre has three types of configuration: User-specific, host-specific and project-specific,
this method returnsa config object which includes the current values - ne need to for you
to care about which config is active and which has priority.

=head2 C<document>

    my $document = Padre::Current->document;

Returns a Padre::Document object for the current document.

=head2 C<editor>

    my $editor = Padre::Current->editor;

Returns a Padre::Editor object for the current editor (containing the current document).

=head2 C<filename>

    my $filename = Padre::Current->filename;

Returns the filename of the current document.

=head2 C<ide>

    my $ide = Padre::Current->ide;

Returns a Padre::Wx object of the current ide.

=head2 C<main>

    my $main = Padre::Current->main;

Returns a Padre::Wx::Main object of the current ide.

=head2 C<notebook>

    my $main = Padre::Current->notebook;

Returns a Padre::Wx::Notebook object of the current notebook.

=head2 C<project>

    my $main = Padre::Current->project;

Returns a Padre::Project object of the current project.

=head2 C<text>

    my $main = Padre::Current->text;

Returns the current selection (selected text in the current document).

=head2 C<title>

    my $main = Padre::Current->title;

Returns the title of the current editor window.

=cut

use 5.008;
use strict;
use warnings;
use Carp         ();
use Exporter     ();
use Params::Util ();

our $VERSION   = '0.94';
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
	return Padre::Current->new unless defined $_[0];
	return shift if Params::Util::_INSTANCE( $_[0], 'Padre::Current' );

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
	my $self     = ref( $_[0] ) ? $_[0] : $_[0]->new;
	my $document = $self->document;
	if ( defined $document ) {
		return $document->project;
	} else {
		return;
	}
}

# Get the text from the editor (and don't cache)
sub text {
	my $self   = ref( $_[0] ) ? $_[0] : $_[0]->new;
	my $editor = $self->editor;
	if ( defined $editor ) {
		return $editor->GetSelectedText;
	} else {
		return '';
	}
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
		if ( defined $notebook ) {
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
		return unless defined $self->main;
		$self->{notebook} = $self->main->notebook;
	}
	return $self->{notebook};
}

# Get the current configuration from the main window (and don't cache).
sub config {
	my $self = ref( $_[0] ) ? $_[0] : $_[0]->new;

	# Fast shortcut from the main window
	return $self->{main}->config if defined $self->{main};

	# Get the config from the main window
	my $main = $self->main;
	return $main->config if defined $main;

	# Get the config from the IDE
	my $ide = $self->ide or return;
	return $ide->config;
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
	if ( defined $self->{main} ) {
		return $self->{main};
	}
	if ( defined $self->{ide} ) {
		return unless defined( $self->{ide}->wx );
		return $self->{main} = $self->{ide}->wx->main;
	}
	if ( defined $self->{editor} ) {
		return $self->{main} = $self->{editor}->main;
	}
	if ( defined $self->{document} ) {
		my $editor = $self->{document}->{editor};
		if ($editor) {
			my $main = $editor->main;
			return $self->{main} = $main if $main;
		}
	}

	# Last resort fallback
	require Padre;

	# Whe whole idea of loading Padre at this point does not look good.
	# It should have already be done in the padre script so loading here again seems incorrect
	# anyway. Does this only serve the testsing? ~ szabgab
	$self->{ide} = Padre->ide;
	return unless defined( $self->{ide}->wx );
	return $self->{main} = $self->{ide}->wx->main;
}

# Convenience method
sub ide {
	my $self = ref( $_[0] ) ? $_[0] : $_[0]->new;

	if ( defined $self->{ide} ) {
		return $self->{ide};
	}
	if ( defined $self->{main} ) {
		return $self->{ide} = $self->{main}->ide;
	}
	if (   defined $self->{document}
		or defined $self->{editor} )
	{
		return $self->{ide} = $self->main->ide;
	}

	# Last resort
	require Padre;
	return $self->{ide} = Padre->ide;
}

1;

__END__

=pod

=head1 NAME

Padre::Current - convenient access to current objects within Padre

=head1 SYNOPSIS

    my $main = Padre::Current->main;
    # ...

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
the last-resort C<< Padre->ide >> singleton-fetching method.

Many objects in L<Padre> that are considered to be part of them context
will have a C<current> method which automatically creates the context
object with it as a seed.

Returns a new B<Padre::Current> object.

=head2 C<ide>

Return the L<Padre> singleton for the IDE instance.

=head2 C<config>

Returns the current L<Padre::Config> configuration object for the IDE.

=head2 C<main>

Returns the L<Padre::Wx::Main> object for the main window.

=head2 C<notebook>

Returns the L<Padre::Wx::Notebook> object for the main window.

=head2 C<document>

Returns the active L<Padre::Document> document object.

=head2 C<editor>

Returns the L<Padre::Editor> editor object for the active document.

=head2 C<filename>

Returns the file name of the active document, if it has one.

=head2 C<title>

Return the title of current editor window.

=head2 C<project>

Return the C<Padre::Project> project object for the active document.

=head2 C<text>

Returns the selected text, or a null string if nothing is selected.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
