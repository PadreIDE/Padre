package Padre::Document::Perl6;

use 5.008;
use strict;
use warnings;
use Padre::Document ();

our $VERSION = '0.21';
our @ISA     = 'Padre::Document';

# Naive way to parse and colorize perl6 files
sub colorize {
	my ($self, $first) = @_;

	$self->remove_color;

	my $editor = $self->editor;
	my $text   = $self->text_get;

	my ($KEYWORD, $STRING, $COMMENT) = (1 .. 5);
	my %regex_of = (
		$KEYWORD  => qr/print|else|say|sub|gt|lt|eq|if/,
		$STRING   => qr/(['"]).*\1/,
		$COMMENT  => qr/#.*/,
	);
	foreach my $color (keys %regex_of) {
		while ($text =~ /$regex_of{$color}/g) {
			my $end    = pos($text);
			my $length = length($&);
			my $start  = $end - $length;
			$editor->StartStyling($start, $color);
			$editor->SetStyling($length, $color);
		}
	}
}

sub get_command {
	my $self     = shift;
	
	my $filename = $self->filename;

	if (not $ENV{PARROT_PATH}) {
		die "PARROT_PATH is not defined. Need to point to trunk of Parrot SVN checkout.\n";
	}
	my $parrot = File::Spec->catfile($ENV{PARROT_PATH}, 'parrot');
	if (not -x $parrot) {
		die "$parrot is not an executable.\n";
	}
	my $rakudo = File::Spec->catfile($ENV{PARROT_PATH}, 'languages', 'perl6', 'perl6.pbc');
	if (not -e $rakudo) {
		die "Cannot find Rakudo ($rakudo)\n";
	}

	return qq{"$parrot" "$rakudo" "$filename"};

}

sub comment_lines_str { return '#' }

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
