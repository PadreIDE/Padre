package Padre::Wx::Style2;

use 5.008;
use strict;
use warnings;
use Params::Util    ();
use Padre::Constant ();
use Padre::Wx       ();
use Padre::Locale   ();

our $VERSION = '0.91';





######################################################################
# Style Language Parser Configuration

my %PARAM = (
	name               => [ 2, 'name'          ],
	style              => [ 1, 'mime'          ],
	SetSelBackground   => [ 2, 'style,color'   ],
	SetSelForeground   => [ 1, 'style,color'   ],
	SetCaretLineBack   => [ 1, 'color'         ],
	SetCaretForeground => [ 1, 'color'         ],
	StyleSetBackground => [ 2, 'style,color'   ],
	StyleSetForeground => [ 2, 'style,color'   ],
	StyleSetBold       => [ 2, 'style,boolean' ],
	StyleSetItalic     => [ 2, 'style,boolean' ],
	StyleSetEOLFilled  => [ 2, 'style,boolean' ],
	StyleSetUnderline  => [ 2, 'style,boolean' ],
);






######################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $self  = bless { @_, code => { } }, $class;
	unless ( defined $self->name ) {
		die "No default en-gb name for style";
	}
	unless ( defined $self->mime ) {
		die "No default text/plain style";
	}

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
	return $self->{mime}->{$mime};
}





######################################################################
# Style Parser

sub load {
	my $class = shift;
	my $file  = shift;
	unless ( -f $file ) {
		die "Missing or invalid style file '$file'";
	}

	# Open the file
	open( CONFIG, '<', $file ) or return;

	# Parse the file
	my $line   = 0;
	my %name   = 0;
	my $style  = undef;
	my %styles = ();
	while ( defined(my $string = <CONFIG>) ) {
		$line++;

		# Clean the line
		$string =~ s/^\s*//s;
		$string =~ s/\s*\z//s;

		# Skip blanks and comments
		next unless /^\s*[^#]/;

		# Split the line into a command and params
		my @list = split /\s+/, $string;
		my $cmd  = shift @list;
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

		} elsif ( $cmd eq 'style' ) {

			# Switch to the new mime type
			my $style = $styles{$list[0]} ||= [ ];

		} elsif ( $PARAM{$cmd}->[1] eq 'color' ) {
			# General commands that are passed a single colour
			my $color = $class->load_color( $line, shift @list );
			push @$style, [ $cmd, $color ];

		} elsif ( $PARAM{$cmd}->[1] eq 'style-color' ) {
			# Style specific commands that are passed a single color
			my $style = $class->load_style( $line, shift @list );
			my $color = $class->load_color( $line, shift @list );
			push @$style, [ $cmd, $style, $color ];

		} elsif ( $PARAM{$cmd}->[1] eq 'style-boolean' ) {
			# Style specific commands that are passed a boolean value
			my $style   = $class->load_style( $line, shift @list );
			my $boolean = $class->load_boolean( $line, shift @list );
			push @$style, [ $cmd, $style, $boolean ];

		} else {
			die "Line $line: Unsupported style command '$string'";
		}
	}

	return $class->new(
		name => \%name,
		mime => \%styles,
	);
}

sub load_color {
	my $self   = shift;
	my $line   = shift;
	my $string = shift;
	return Padre::Wx::color($string);
}

sub load_style {
	my $self   = shift;
	my $line   = shift;
	my $string = shift;
	my $copy = $string;
	if ( defined Params::Util::_NONNEGINT($string) ) {
		return $string;
	} elsif ( $string =~ /^PADRE_\w+\z/ ) {
		unless ( Padre::Constant->can($string) ) {
			die "Line $line: Unknown or unsupported style '$copy'";
		}
		$string = "Padre::Constant::$string";
	} elsif ( $string =~ /^wxSTC_\w+\z/ ) {
		unless ( Wx::->can($string) ) {
			die "Line $line: Unknown or unsupported style '$copy'";
		}
		$string = "Wx::$string";
	} else {
		die "Line $line: Unknown or unsupported style '$copy'";
	}

	# Capture the numeric form of the constant
	no strict 'refs';
	$string = eval { $string->() };
	if ( $@ ) {
		die "Line $line: Unknown or unsupported style '$copy'";
	}

	return $string;
}

sub load_boolean {
	my $self   = shift;
	my $line   = shift;
	my $string = shift;
	unless ( $string eq '0' or $string eq '1' ) {
		die "Line $line: Boolean value '$string' is not 0 or 1";
	}
	return $string;
}





######################################################################
# Compilation and Application

sub code {
	$_[0]->{code} or
	$_[0]->{code} = $_[0]->compile;
}

sub compile {
	my $self = shift;
}

1;
