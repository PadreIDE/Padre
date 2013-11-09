package Padre::Cache;

=pod

=head1 NAME

Padre::Cache - The Padre Temporary Data Cache API

=head1 DESCRIPTION

B<Padre::Cache> implements a light memory only caching mechanism which is
designed to support GUI objects that need to temporarily store state data.

By providing this caching in a neutral location that is not directly bound
to the user interface objects, the cached data can survive destruction and
recreation of those interface objects.

This is particularly valuable for situations such as a shift in the active
language or the relocation of a tool that would result in interface objects
being rebuilt.

Cache data is stored in a "Stash", which is a C<HASH> reference containing
arbitrary content, and is keyed off a project or document.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Params::Util ();

our $VERSION    = '1.00';
our $COMPATIBLE = '0.70';

my %DATA = ();

=pod

=head2 stash

  my $stash = Padre::Cache->stash( 'Padre::Wx::MyClass' => $project );

The C<stash> method fetches the C<HASH> reference stash for a particular key
pair, which consists of a GUI class name and a project or document.

The C<HASH> reference returned can be used directly withouth the need to do
any kind of C<get> or C<set> call to the stash.

Calling C<stash> multiple times is guarenteed to fetch the same C<HASH>
reference.

=cut

sub stash {
	my $class = shift;
	my $owner = shift;
	my $key   = shift;

	# We need an instantiated cache target
	# NOTE: The defined is needed because Padre::Project::Null
	# boolifies to false. In retrospect, that may have been a bad idea.
	if ( defined Params::Util::_INSTANCE( $key, 'Padre::Project' ) ) {
		$key = $key->root;
	} elsif ( Params::Util::_INSTANCE( $key, 'Padre::Document' ) ) {
		$key = $key->filename;
	} else {
		die "Missing or invalid cache key";
	}

	$DATA{$key}->{$owner}
		or $DATA{$key}->{$owner} = {};
}

=pod

=head2 release

    Padre::Cache->release( $project->root );

The C<release> method is used to flush all of the stash data related to a
particular project root or file name for all of the GUI elements that make
use of stash objects from L<Padre::Cache>.

Although this method is available for use, it should generally not be called
directly. The built in C<DESTROY> for both project and document objects will
call this method for you, automatically cleaning up the stash data when the
project or document itself is destroyed.

=cut

sub release {
	delete $DATA{ $_[1] };
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2013 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl 5 itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
