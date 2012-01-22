package Padre::Wx::Theme;

use 5.008;
use strict;
use warnings;
use Storable         ();
use IO::File         ();
use File::Spec       ();
use Scalar::Util     ();
use Params::Util     ();
use Padre::Constant  ();
use Padre::Util      ();
use Padre::Wx        ();
use Padre::Wx::Style ();
use Wx::Scintilla    ();

our $VERSION = '0.94';

# Locate the directories containing styles
use constant {
	CORE_DIRECTORY => Padre::Util::sharedir('themes'),
	USER_DIRECTORY => File::Spec->catdir(
		Padre::Constant::CONFIG_DIR,
		'themes',
	),
};





######################################################################
# Configuration

# Commands allowed in the style
my %PARAM = (
	name                    => [ 2, 'name' ],
	gui                     => [ 1, 'class' ],
	style                   => [ 1, 'mime' ],
	include                 => [ 1, 'mime' ],
	SetForegroundColour     => [ 1, 'color' ],
	SetBackgroundColour     => [ 1, 'color' ],
	SetCaretLineBackground  => [ 1, 'color' ],
	SetCaretForeground      => [ 1, 'color' ],
	CallTipSetBackground    => [ 1, 'color' ],
	SetWhitespaceBackground => [ 2, 'boolean,color' ],
	SetWhitespaceForeground => [ 2, 'boolean,color' ],
	SetSelBackground        => [ 2, 'style,color' ],
	SetSelForeground        => [ 1, 'style,color' ],
	StyleAllBackground      => [ 1, 'color' ],
	StyleAllForeground      => [ 1, 'color' ],
	StyleSetBackground      => [ 2, 'style,color' ],
	StyleSetForeground      => [ 2, 'style,color' ],
	StyleSetBold            => [ 2, 'style,boolean' ],
	StyleSetItalic          => [ 2, 'style,boolean' ],
	StyleSetEOLFilled       => [ 2, 'style,boolean' ],
	StyleSetUnderline       => [ 2, 'style,boolean' ],
	StyleSetSpec            => [ 2, 'style,spec' ],
	SetFoldMarginColour     => [ 2, 'boolean,color' ],
	SetFoldMarginHiColour   => [ 2, 'boolean,color' ],
	MarkerSetForeground     => [ 2, 'style,color' ],
	MarkerSetBackground     => [ 2, 'style,color' ],
);

# Fallback path of next best styles if no style exists.
# The fallback of last resort is automatically to text/plain
my %FALLBACK = (
	'application/x-psgi'     => 'application/x-perl',
	'application/x-php'      => 'application/perl',      # Temporary solution
	'application/json'       => 'application/javascript',
	'application/javascript' => 'text/x-csrc',
	'text/x-java'            => 'text/x-csrc',
	'text/x-c++src'          => 'text/x-csrc',
	'text/x-csharp'          => 'text/x-csrc',
);





######################################################################
# Style Repository

sub files {
	my $class  = shift;
	my %styles = ();

	# Scan style directories
	foreach my $directory ( USER_DIRECTORY, CORE_DIRECTORY ) {
		next unless -d $directory;

		# Search the directory
		local *STYLEDIR;
		unless ( opendir( STYLEDIR, $directory ) ) {
			die "Failed to read '$directory'";
		}
		foreach my $file ( readdir STYLEDIR ) {
			next unless $file =~ s/\.txt\z//;
			next unless Params::Util::_IDENTIFIER($file);
			next if $styles{$file};
			$styles{$file} = File::Spec->catfile(
				$directory,
				"$file.txt"
			);
		}
		closedir STYLEDIR;
	}

	return \%styles;
}

# Get the file name for a named style
sub file {
	my $class = shift;
	my $name  = shift;
	foreach my $directory ( USER_DIRECTORY, CORE_DIRECTORY ) {
		my $file = File::Spec->catfile(
			$directory,
			"$name.txt",
		);
		return $file if -f $file;
	}
	return undef;
}

sub labels {
	my $class  = shift;
	my $locale = shift;
	my $files  = $class->files;

	# Load the label for each file.
	# Because we resolve the filename again this is slower than
	# it could be, but the code is simple and easy and will do for now.
	my %labels = ();
	foreach my $name ( keys %$files ) {
		$labels{$name} = $class->label( $name, $locale );
	}

	return \%labels;
}

sub label {
	my $class  = shift;
	my $name   = shift;
	my $locale = shift;
	my $file   = $class->file($name);
	unless ($file) {
		die "The style '$name' does not exist";
	}

	# Parse the file for name statements
	my $line   = 0;
	my %label  = ();
	my $handle = IO::File->new( $file, 'r' ) or return;
	while ( defined( my $string = <$handle> ) ) {
		$line++;

		# Clean the line
		$string =~ s/^\s*//s;
		$string =~ s/\s*\z//s;

		# Skip blanks and comments
		next unless $string =~ /^\s*[^#]/;

		# Split the line into a command and params
		my @list = split /\s+/, $string;
		my $cmd = shift @list;

		# We only care about name
		next unless defined $cmd;
		last unless $cmd eq 'name';

		# Save the name
		my $lang = shift @list;
		$label{$lang} = join ' ', @list;
	}
	$handle->close;

	# Try to find a usable label
	return $label{$locale} || $label{'en-gb'} || $name;
}

sub options {
	$_[0]->labels('en-gb');
}

sub find {
	my $class = shift;
	my $name  = shift;
	my $file  = $class->file($name);
	unless ($file) {
		die "The style '$name' does not exist";
	}
	return $class->load($file);
}





######################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $self  = bless { @_, code => {} }, $class;
	unless ( defined $self->name ) {
		die "No default en-gb name for style";
	}
	unless ( defined $self->mime ) {
		die "No default text/plain style";
	}

	return $self;
}

sub clone {
	my $self  = shift;
	my $class = Scalar::Util::blessed($self);
	return bless { %$self }, $class;
}

sub load {
	my $class = shift;
	my $file  = shift;
	unless ( -f $file ) {
		die "Missing or invalid style file '$file'";
	}

	# Open the file
	my $handle = IO::File->new( $file, 'r' ) or return;
	my $self = $class->parse($handle);
	$handle->close;

	return $self;
}

sub name {
	my $self = shift;
	my $lang = shift || 'en-gb';
	return $self->{name}->{$lang};
}

sub mime {
	my $self = shift;
	my $mime = shift || 'text/plain';
	while ( not $self->{mime}->{$mime} ) {
		if ( $mime eq 'text/plain' ) {

			# A null seqeunce... I guess...
			return [];
		} else {
			$mime = $FALLBACK{$mime} || 'text/plain';
		}
	}
	return $self->{mime}->{$mime};
}





######################################################################
# Style Parser

sub parse {
	my $class = shift;
	my $handle = Params::Util::_HANDLE(shift) or die "Not a file handle";

	# Load the delayed modules
	require Padre::Wx;
	require Padre::Locale;

	# Parse the file
	my %name   = ();
	my %styles = ();
	my $style  = undef;
	my $line   = 0;
	while ( defined( my $string = <$handle> ) ) {
		$line++;

		# Clean the line
		$string =~ s/^\s*//s;
		$string =~ s/\s*\z//s;

		# Skip blanks and comments
		next unless $string =~ /^\s*[^#]/;

		# Split the line into a command and params
		my @list = split /\s+/, $string;
		my $cmd = shift @list;
		unless ( defined $PARAM{$cmd} ) {
			die "Line $line: Unsupported style command '$string'";
		}
		unless ( @list >= $PARAM{$cmd}->[0] ) {
			die "Line $line: Insufficient parameters in command '$string'";
		}

		# Handle special commands
		if ( $cmd eq 'name' ) {

			# Does the language exist
			my $lang = shift @list;
			unless ( Padre::Locale::rfc4646_exists($lang) ) {
				die "Line $line: Unknown language in command '$string'";
			}

			# Save the name
			$name{$lang} = join ' ', @list;

		} elsif ( $cmd eq 'style' or $cmd eq 'gui' ) {

			# Switch to the new mime type
			$style = $styles{ $list[0] } = Padre::Wx::Style->new;

		} elsif ( $cmd eq 'include' ) {

			# Copy another style as a starting point
			my $copy = $styles{ $list[0] };
			unless ($copy) {
				die "Line $line: Style '$list[0]' is not defined (yet)";
			}
			$style->include($copy);

		} elsif ( $PARAM{$cmd}->[1] eq 'color' ) {

			# General commands that are passed a single colour
			my $color = Padre::Wx::color( shift @list );
			$style->add( $cmd => [ $color ] );

		} elsif ( $PARAM{$cmd}->[1] eq 'style,color' ) {

			# Style specific commands that are passed a single color
			my $id = $class->parse_style( $line, shift @list );
			my $color = Padre::Wx::color( shift @list );
			$style->add( $cmd => [ $id, $color ] );

		} elsif ( $PARAM{$cmd}->[1] eq 'style,boolean' ) {

			# Style specific commands that are passed a boolean value
			my $id = $class->parse_style( $line, shift @list );
			my $boolean = $class->parse_boolean( $line, shift @list );
			$style->add( $cmd => [ $id, $boolean ] );

		} elsif ( $PARAM{$cmd}->[1] eq 'style,spec' ) {

			# Style command that is passed a spec string
			my $style = $class->parse_style( $line, shift @list );
			my $spec = shift @list;

		} elsif ( $PARAM{$cmd}->[1] eq 'boolean,color' ) {
			my $boolean = $class->parse_boolean( $line, shift @list );
			my $color = Padre::Wx::color( shift @list );
			$style->add( $cmd => [ $boolean, $color ] );

		} else {
			die "Line $line: Unsupported style command '$string'";
		}
	}

	return $class->new(
		name => \%name,
		mime => \%styles,
	);
}

sub parse_style {
	my $class  = shift;
	my $line   = shift;
	my $string = shift;
	my $copy   = $string;
	if ( defined Params::Util::_NONNEGINT($string) ) {
		return $string;
	} elsif ( $string =~ /^PADRE_\w+\z/ ) {
		unless ( Padre::Constant->can($string) ) {
			die "Line $line: Unknown or unsupported style '$copy'";
		}
		$string = "Padre::Constant::$string";
	} elsif ( $string =~ /^\w+\z/ ) {
		unless ( Wx::Scintilla->can($string) ) {
			die "Line $line: Unknown or unsupported style '$copy'";
		}
		$string = "Wx::Scintilla::$string";
	} else {
		die "Line $line: Unknown or unsupported style '$copy'";
	}

	# Capture the numeric form of the constant
	no strict 'refs';
	$string = eval { $string->() };
	if ($@) {
		die "Line $line: Unknown or unsupported style '$copy'";
	}

	return $string;
}

sub parse_boolean {
	my $class  = shift;
	my $line   = shift;
	my $string = shift;
	unless ( $string eq '0' or $string eq '1' ) {
		die "Line $line: Boolean value '$string' is not 0 or 1";
	}
	return $string;
}





######################################################################
# Compilation and Application

sub apply {
	my $self   = shift;
	my $object = shift;

	# Clear any previous style
	$self->clear($object);

	if ( Params::Util::_INSTANCE( $object, 'Padre::Wx::Editor' ) ) {
		# This is an editor style
		my $document = $object->document   or return;
		my $mimetype = $document->mimetype or return;
		$self->mime($mimetype)->apply($object);

		# Apply custom caret line background color
		my $bg = $self->{editor_currentline_color};
		unless ( defined $bg ) {
			$bg = $object->config->editor_currentline_color;
		}
		$object->SetCaretLineBackground( Padre::Wx::color($bg) );

		# Refresh the line numbers in case the font has changed
		$object->refresh_line_numbers;

	} else {
		# This is a GUI style, chase the inheritance tree.
		# Uses inlined Class::ISA algorithm as in Class::Inspector
		my $class = Scalar::Util::blessed($object);
		my @queue = ( $class );
		my %seen  = ( $class => 1 );
		while ( my $package = shift @queue ) {
			no strict 'refs';
			unshift @queue, grep { ! $seen{$_}++ }
				map { s/^::/main::/; s/\'/::/g; $_ }
				( @{"${package}::ISA"} );

			# Apply the first style that patches
			my $style = $self->{mime}->{$package} or next;
			$style->apply($object);
			return 1;
		}
	}

	return 1;
}

sub clear {
	my $self   = shift;
	my $object = shift;

	if ( Params::Util::_INSTANCE( $object, 'Padre::Wx::Editor' ) ) {

		# Clears settings back to the editor configuration defaults
		# To do this we flush absolutely everything and then apply
		# the basic font settings.
		$object->StyleResetDefault;

		# Find the font to initialise with
		my $editor_font = $self->{editor_font};
		unless ( defined $editor_font ) {
			$editor_font = $object->config->editor_font;
		}

		# Reset the font, which Scintilla considers part of the
		# "style" but Padre doesn't allow to be changed as a "style"
		require Padre::Wx;
		my $font = Padre::Wx::editor_font($editor_font);
		$object->SetFont($font);
		$object->StyleSetFont( Wx::Scintilla::STYLE_DEFAULT, $font );

		# Reset all styles to the recently set default
		$object->StyleClearAll;

	} else {
		# Reset the GUI element colours back to defaults
		### Disabled as it blacks the directory tree for some reason
		# $object->SetForegroundColour( Wx::NullColour );
		# $object->SetBackgroundColour( Wx::NullColour );
	}

	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
