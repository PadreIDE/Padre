package Padre::Document::Perl::QuickFix::StrictWarnings;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.94';

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
sub apply {
	my ( $self, $doc, $document ) = @_;

	my @items = ();

	my $editor          = $document->editor;
	my $text            = $editor->GetText;
	my $current_line_no = $editor->GetCurrentLine;

	my ( $use_strict_include, $use_warnings_include );
	my $includes = $doc->find('PPI::Statement::Include');
	if ($includes) {
		foreach my $include ( @{$includes} ) {
			next if $include->type eq 'no';
			if ( $include->pragma ) {
				my $pragma = $include->pragma;
				if ( $pragma eq 'strict' ) {
					$use_strict_include = $include;
				} elsif ( $pragma eq 'warnings' ) {
					$use_warnings_include = $include;
				}
			}
		}
	}

	my ( $replace, $col, $row, $len );
	if ( $use_strict_include and not $use_warnings_include ) {

		# insert 'use warnings;' afterwards
		$replace = "use strict;\nuse warnings;";
		$row     = $use_strict_include->line_number - 1;
		$col     = $use_strict_include->column_number - 1;
		$len     = length $use_strict_include->content;
	} elsif ( not $use_strict_include and $use_warnings_include ) {

		# insert 'use strict';' before
		$replace = "use strict;\nuse warnings;";
		$row     = $use_warnings_include->line_number - 1;
		$col     = $use_warnings_include->column_number - 1;
		$len     = length $use_warnings_include->content;
	} elsif ( not $use_strict_include and not $use_warnings_include ) {

		# insert 'use strict; use warnings;' at the top
		my $first = $doc->find_first(
			sub {
				return $_[1]->isa('PPI::Statement')
					or $_[1]->isa('PPI::Structure');
			}
		);
		$replace = "use strict;\nuse warnings;\n";
		if ($first) {
			$row = $first->line_number - 1;
			$col = $first->column_number - 1;
			$len = 0;

		} else {
			$row = $current_line_no;
			$col = 0;
			$len = 0;
		}
	}

	if ($replace) {
		push @items, {
			text     => qq{Fix '$replace'},
			listener => sub {
				my $line_start = $editor->PositionFromLine($row) + $col;
				my $line_end   = $line_start + $len;
				my $line       = $editor->GetTextRange( $line_start, $line_end );
				$editor->SetSelection( $line_start, $line_end );
				$editor->ReplaceSelection($replace);
				}
		};
	}

	return @items;
}

1;

__END__

=head1 NAME

Padre::Document::Perl::QuickFix::StrictWarnings - Check for strict and warnings pragmas

=head1 DESCRIPTION

This ensures that you have the following in your script:

	use strict;
	use warnings;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
