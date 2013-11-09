package Padre::Comment;

=pod

=head1 NAME

Padre::Comment - Padre Comment Support Library

=head1 DESCRIPTION

This module provides objects which represent a logical comment style for
a programming language and implements a range of logic to assist in
locating, counting, filtering, adding and removing comments in a document.

Initially, however, it only acts as a central storage location for the
comment styles of supported mime types.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use List::Util   ();
use Params::Util ();
use Padre::MIME  ();

our $VERSION    = '1.00';
our $COMPATIBLE = '0.95';

my %MIME = ();
my %KEYS = ();





######################################################################
# Static Methods

sub register {
	my $class = shift;
	while (@_) {
		my $type = shift;
		my $key  = shift;
		unless ( $MIME{$type} = $KEYS{$key} ) {
			die "$type: Comment style '$key' does not exist";
		}
	}
	return 1;
}

=pod

=head2 registered

  my @registered = Padre::Comment->registered;

The C<registered> method returns the list of all registered MIME types
that have a comment style distinct from their parent supertype.

=cut

sub registered {
	keys %MIME;
}

=pod

=head2 get

  my $comment = Padre::Comment->get('application/x-perl');

The C<get> method finds a comment for a specific MIME type. This method
checks only the specific string and does not follow the superpath of the
mime type. For a full powered lookup, use the C<find> method.

Returns a L<Padre::Comment> object or C<undef> if the mime type does not
have a distinct comment string.

=cut

sub get {
	$MIME{ $_[1] || '' };
}

sub find {
	my $class = shift;
	my $mime = Params::Util::_INSTANCE( $_[0], 'Padre::MIME' ) || Padre::MIME->find( $_[0] )
		or return undef;
	foreach my $type ( $mime->superpath ) {
		return $MIME{$type} if $MIME{$type};
	}
	return undef;
}





######################################################################
# Constructors and Accessors

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;

	# Check params
	unless ( defined $self->{key} ) {
		die "Missing or invalid 'key' param";
	}
	unless ( defined $self->{left} ) {
		die "Missing or invalid 'left' param";
	}
	unless ( defined $self->{right} ) {
		die "Missing or invalid 'right' param";
	}

	return $self;
}

sub create {
	my $class = shift;
	my $self  = $class->new(@_);
	my $key   = $self->key;
	if ( $KEYS{$key} ) {
		die "Attempted to create duplicate comment style '$key'";
	}
	$KEYS{$key} = $self;
}

sub key {
	$_[0]->{key};
}

sub left {
	$_[0]->{left};
}

sub right {
	$_[0]->{right};
}





######################################################################
# Regex Generators

sub line_match {
	my $self = shift;
	unless ( defined $self->{line_match} ) {
		my $left  = $self->left;
		my $right = $self->right;
		if ($right) {
			$self->{line_match} = qr/^\s*\Q$left\E.*\Q$right\E$/;
		} elsif ( $left =~ /^\s/ ) {
			$self->{line_match} = qr/^\Q$left/;
		} else {
			$self->{line_match} = qr/^\s*\Q$left/;
		}
	}
	return $self->{line_match};
}





######################################################################
# Comment Registry

Padre::Comment->create(
	key   => '#',
	left  => '#',
	right => '',
);

Padre::Comment->create(
	key   => '\\',
	left  => '\\',
	right => '',
);

Padre::Comment->create(
	key   => '//',
	left  => '//',
	right => '',
);

Padre::Comment->create(
	key   => '--',
	left  => '--',
	right => '',
);

Padre::Comment->create(
	key   => 'REM',
	left  => 'REM',
	right => '',
);

Padre::Comment->create(
	key   => '%',
	left  => '%',
	right => '',
);

Padre::Comment->create(
	key   => '      *',
	left  => '      *',
	right => '',
);

Padre::Comment->create(
	key   => '/* */',
	left  => '/*',
	right => '*/',
);

Padre::Comment->create(
	key   => '!',
	left  => '!',
	right => '',
);

Padre::Comment->create(
	key   => ';',
	left  => ';',
	right => '',
);

Padre::Comment->create(
	key   => '{ }',
	left  => '{',
	right => '}',
);

Padre::Comment->create(
	key   => "'",
	left  => "'",
	right => '',
);

Padre::Comment->create(
	key   => '<!-- -->',
	left  => '<!--',
	right => '-->',
);

Padre::Comment->create(
	key   => '<?_c _c?>',
	left  => '<?_c',
	right => '_c?>',
);

Padre::Comment->create(
	key   => 'if 0 { }',
	left  => 'if 0 {',
	right => '}',
);

Padre::Comment->register(
	'text/x-abc'                => '\\',
	'text/x-actionscript'       => '//',
	'text/x-adasrc'             => '--',
	'text/x-asm'                => '#',
	'text/x-bat'                => 'REM',
	'application/x-bibtex'      => '%',
	'application/x-bml'         => '<?_c _c?>',
	'text/x-csrc'               => '//',
	'text/x-cobol'              => '      *',
	'text/x-config'             => '#',
	'text/css'                  => '/* */',
	'text/x-eiffel'             => '--',
	'text/x-forth'              => '\\',
	'text/x-fortran'            => '!',
	'text/x-haskell'            => '--',
	'application/x-latex'       => '%',
	'application/x-lisp'        => ';',
	'text/x-lua'                => '--',
	'text/x-makefile'           => '#',
	'text/x-matlab'             => '%',
	'text/x-pascal'             => '{ }',
	'application/x-pasm'        => '#',
	'application/x-perl'        => '#',
	'application/x-perl6'       => '#',
	'application/x-pir'         => '#',
	'text/x-perltt'             => '<!-- -->',
	'application/x-php'         => '#',
	'text/x-perlxs'             => '#',   # Define our own MIME type
	'text/x-pod'                => '#',
	'text/x-povray'             => '//',
	'text/x-python'             => '#',
	'text/x-r'                  => '#',
	'application/x-ruby'        => '#',
	'text/sgml'                 => '<!-- -->',
	'application/x-shellscript' => '#',
	'text/x-sql'                => '--',
	'application/x-tcl'         => 'if 0 { }',
	'text/vbscript'             => "'",
	'text/xml'                  => '<!-- -->',
	'text/x-yaml'               => '#',
);

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2013 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5 itself.

=cut
