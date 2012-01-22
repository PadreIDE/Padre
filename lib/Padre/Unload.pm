package Padre::Unload;

# Inlined version of Class::Unload with a few more tricks up its sleeve

use 5.008;
use strict;
use warnings;

our $VERSION    = '0.94';
our $COMPATIBLE = '0.91';

sub unload {
	my $module = shift;

	require Class::Inspector;
	return unless Class::Inspector->loaded($module);

	no strict 'refs';

	# Flush inheritance caches
	@{ $module . '::ISA' } = ();

	# Delete all symbols except other namespaces
	my $symtab = $module . '::';
	for my $symbol ( keys %$symtab ) {
		next if $symbol =~ /\A[^:]+::\z/;
		delete $symtab->{$symbol};
	}

	my $inc_file = join( '/', split /(?:'|::)/, $module ) . '.pm';
	delete $INC{$inc_file};

	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
