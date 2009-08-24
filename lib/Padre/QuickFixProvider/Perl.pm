package Padre::QuickFixProvider::Perl;

use 5.008;
use strict;
use warnings;

use Padre::QuickFixProvider ();

our $VERSION = '0.43';
our @ISA     = 'Padre::QuickFixProvider';

#
# Constructor.
# No need to override this
#
sub new {
	my ($class) = @_;

	# Create myself :)
	my $self = bless {}, $class;

	return $self;
}

#
# Returns the quick fix list
#
sub quick_fix_list {
	my ( $self, $doc, $editor ) = @_;

	my @items           = ();
	my $text            = $editor->GetText;
	my $current_line_no = $editor->GetCurrentLine;

	if ( $text !~ /\s*use\s+strict/msx ) {
		push @items, {
			text     => qq{Add 'use strict;'},
			listener => sub {
				my $line_start = $editor->PositionFromLine($current_line_no);
				my $line_end   = $editor->GetLineEndPosition($current_line_no);
				my $line       = $editor->GetTextRange( $line_start, $line_end );
				$line = qq{use strict;$line\n};
				$editor->SetSelection( $line_start, $line_end );
				$editor->ReplaceSelection($line);
				}
		};
	}
	if ( $text !~ /\s*use\s+warnings/msx ) {
		push @items, {
			text     => qq{Add 'use warnings;'},
			listener => sub {
				my $line_start = $editor->PositionFromLine($current_line_no);
				my $line_end   = $editor->GetLineEndPosition($current_line_no);
				my $line       = $editor->GetTextRange( $line_start, $line_end );
				$line = qq{use warnings;$line\n};
				$editor->SetSelection( $line_start, $line_end );
				$editor->ReplaceSelection($line);
				}
		};
	}

	return @items;
}

1;

__END__

=head1 NAME

Padre::QuickFixProvider::Perl - Padre Perl 5 Quick Fix Provider

=head1 DESCRIPTION

Perl 5 quick fix feature is implemented here

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
