package Padre::Task::OpenResource;

use 5.008;
use strict;
use warnings;

use Padre::Task ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Task';

sub run {
	my $self = shift;

	# Search and ignore version control and Dist::Zilla folders if the user wants
	require File::Find::Rule;
	my $rule = File::Find::Rule->new;
	if ( $self->{skip_vcs_files} ) {
		$rule->or(
			$rule->new->directory->name( 'CVS', '.svn', '.git', 'blib', '.build' )->prune->discard,
			$rule->new
		);
	}
	$rule->file;

	if ( $self->{skip_using_manifest_skip} ) {
		my $manifest_skip = File::Spec->catfile(
			$self->{directory},
			'MANIFEST.SKIP',
		);
		if ( -e $manifest_skip ) {
			require ExtUtils::Manifest;
			ExtUtils::Manifest->import('maniskip');
			my $maniskip = maniskip($manifest_skip);
			$rule->exec(
				sub {
					return not $maniskip->( $_[2] );
				}
			);
		}
	}

	# Generate a sorted file list based on filename
	$self->{matched} =
		[ sort { File::Basename::fileparse($a) cmp File::Basename::fileparse($b) } $rule->in( $self->{directory} ) ];

	return 1;
}

1;

__END__

=head1 AUTHOR

Ahmad M. Zawawi C<< <ahmad.zawawi at gmail.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
