package Padre::Document::PASM;

use 5.008;
use strict;
use warnings;
use Padre::Document ();
use Padre::Util     ();

our $VERSION = '0.21';
our @ISA     = 'Padre::Document';

# Slightly less naive way to parse and colorize pasm files

# still not working:
#  eq	I1,31,done
#	lt	P0,2,is_one
#	mul	P0,P0,I2


sub colorize {
	my ($self, $first) = @_;

	$self->remove_color;

	my $editor   = $self->editor;
	my $text     = $self->text_get;
	
	my @keywords = qw(substr save print branch new set end 
	                 sub abs gt lt eq shift get_params if 
	                 getstdin getstdout readline bsr inc 
	                 push dec mul pop ret sweepoff trace 
	                 restore ge le);
	my $keywords = join '|', sort {length $b <=> length $a} @keywords;

#	my %regex_of = (
#		PASM_KEYWORD  => qr/$keywords/,
#		PASM_REGISTER => qr/\$?[ISPN]\d+/,
#		PASM_LABEL    => qr/^\s*\w*:/m,
#		PASM_STRING   => qr/(['"]).*\1/,
#		PASM_COMMENT  => qr/#.*/,
#	);

	my $in_pod;
	my @lines = split /\n/, $text;
	foreach my $i (0..@lines-1) {
		next if $lines[$i] =~ /^\s$/;
		if ($lines[$i] =~ /^\s*#/) {
			_color($editor, 'Px::PASM_COMMENT', $i, 0);
			next;
		}
		if ($lines[$i] =~ /^=/ or $in_pod) {
			_color($editor, 'Px::PASM_POD', $i, 0);
			if ($lines[$i] =~ /^=cut/) {
				$in_pod = 0;
			} else {
				$in_pod = 1;
			}
			next;
		}
		if ($lines[$i] =~ /^\s*\w*:/m) {
			_color($editor, 'Px::PASM_LABEL', $i, 0);
			next;
		}
		if ($lines[$i] =~ /^\s*($keywords)\s*$/) { #   end
			_color($editor, 'Px::PASM_KEYWORD', $i, 0);
			next;
		}
		if ($lines[$i] =~ /^\s*($keywords)\s*(([\'\"])[^\3]*\3|\$?[ISPN]\d+)\s*$/) { #   print "abc"
			my $keyword = $1;
			my $string = $2;
			my $loc = index($lines[$i], $keyword);
			_color($editor, 'Px::PASM_KEYWORD', $i, $loc, length($keyword));
			my $loc2 = index($lines[$i], $string, $loc+length($keyword));
			if ($string =~ /[\'\"]/) {
				_color($editor, 'Px::PASM_STRING', $i, $loc2, length($string));
			} else {
				_color($editor, 'Px::PASM_REGISTER', $i, $loc2, length($string));
			}
			next;
		}
		if ($lines[$i] =~ /^\s*($keywords)\s*(.*)$/) { # get_params "0", P0
			my $keyword = $1;
			my $other   = $2;
			
			my $loc = index($lines[$i], $keyword);
			_color($editor, 'Px::PASM_KEYWORD', $i, $loc, length($keyword));

			my ($first, $second) = split /,/, $other, 2;    # breaks if string is the first element
			my $endloc2 = gg($editor, $first, $i, $lines[$i], $loc+length($keyword));
			if (not defined $endloc2) {
				# warn
				next;
			}
			gg($editor, $second, $i, $lines[$i], $endloc2);
		
			next;
		}
		
	}

}


sub gg {
	my ($editor, $str, $i, $line, $loc) = @_;
	if (not defined $str) {
		#warn $line;
		return;
	}
	if ($str =~ /^\s*(\$?[ISPN]\d+)\s*$/) {
		my $substr = $1;
		my $loc2 = index($line, $substr, $loc);
		_color($editor, 'Px::PASM_REGISTER', $i, $loc2, length($substr));
		return $loc2 + length($substr);
	} elsif ($str =~ /^\s*(([\'\"])[^\2]*\2)\s*$/) {
		my $substr = $1;
		my $loc2 = index($line, $substr, $loc);
		_color($editor, 'Px::PASM_STRING', $i, $loc2, length($substr));
		return $loc2 + length($substr);
	} elsif ($str =~ /^\s*(\w\w*)\s*$/) {
		my $substr = $1;
		my $loc2 = index($line, $substr, $loc);
		_color($editor, 'Px::PASM_LABEL', $i, $loc2, length($substr));
		return $loc2 + length($substr);
	}
	return;
}

sub _color {
	my ($editor, $color, $line, $offset, $length) = @_;
	#print "C: $color\n";
	my $start  = $editor->PositionFromLine($line) + $offset;
	if (not defined $length) {
		$length = $editor->GetLineEndPosition($line) - $start;
	}

	no strict "refs"; ## no critic
	$editor->StartStyling($start,  $color->());
	$editor->SetStyling(  $length, $color->());
	return;
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

	return qq{"$parrot" "$filename"};

}

sub comment_lines_str {
	return '#';
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
