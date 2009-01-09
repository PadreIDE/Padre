package Padre::Current;

# A context object, for centralising the concept of what is "current"

use strict;
use warnings;
use Carp         ();
use Exporter     ();
use Params::Util qw{_INSTANCE};

our $VERSION   = '0.25';
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
	if ( _INSTANCE($_[0], 'Padre::Current') ) {
		return shift;
	}

	# Fallback options
	if ( _INSTANCE($_[0], 'Padre::Document') ) {
		return Padre::Current->new( document => shift );
	}
	return Padre::Current->new;
}





#####################################################################
# Constructor

sub new {
	my $class = shift;
	bless { @_ }, $class;
}





#####################################################################
# Context Methods

# Get the project from the document (and don't cache)
sub project {
	my $self     = ref($_[0]) ? $_[0] : $_[0]->new;
	my $document = $self->document;
	if ( defined $document ) {
		return $document->project;
	} else {
		return undef;
	}
}
	
# Get the text from the editor (and don't cache)
sub text {
	my $self   = ref($_[0]) ? $_[0] : $_[0]->new;
	my $editor = $self->editor;
	if ( defined $editor ) {
		return $editor->GetSelectedText;
	} else {
		return undef;
	}
}

# Get the title of the current editor window (and don't cache)
sub title {
	my $self     = ref($_[0]) ? $_[0] : $_[0]->new;
	my $notebook = $self->_notebook;
	my $selected = $notebook->GetSelection;
	if ( $selected >= 0 ) {
		return $notebook->getPageText($selected);
	} else {
		return undef;
	}
}

# Get the filename from the document
sub filename {
	my $self = ref($_[0]) ? $_[0] : $_[0]->new;
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
	my $self = ref($_[0]) ? $_[0] : $_[0]->new;
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
	my $self = ref($_[0]) ? $_[0] : $_[0]->new;
	unless ( exists $self->{editor} ) {
		my $notebook = $self->_notebook;
		my $selected = $notebook->GetSelection;
		if ( $selected == -1 ) {
			$self->{editor} = undef;
		} elsif ( $selected >= $notebook->GetPageCount ) {
			$self->{editor} = undef;
		} else {
			$self->{editor} = $notebook->GetPage( $selected );
			unless ( $self->{editor} ) {
				Carp::croak("Failed to find page");
			}
		}
	}
	return $self->{editor};
}

# Convenience method
sub _notebook {
	my $self = ref($_[0]) ? $_[0] : $_[0]->new;
	unless ( defined $self->{notebook} ) {
		$self->{notebook} = $self->_main->notebook;
	}
	return $self->{notebook};
}

# Get the project from the main_window (and don't cache)
sub config {
	my $self = ref($_[0]) ? $_[0] : $_[0]->new;
	$self->_main->config;
}

# Convenience method
sub _main {
	my $self = ref($_[0]) ? $_[0] : $_[0]->new;
	unless ( defined $self->{main} ) {
		require Padre;
		$self->{main} = Padre->ide->wx->main_window;
	}
	return $self->{main};
}

1;
