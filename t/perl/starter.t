#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 5;
use Test::NoWarnings;

use Padre::Document::Perl::Starter ();

use constant {
	Starter => 'Padre::Document::Perl::Starter',
	Style   => 'Padre::Document::Perl::Starter::Style',
};





######################################################################
# Black Box Testing

SCOPE: {
	my $starter = Starter->new;
	isa_ok( $starter, Starter );
	isa_ok( $starter->style, Style );
}

# Default simple Perl files
SCOPE: {
	my $starter = Starter->new;

	my $script = $starter->generate_script;
	is( $script, <<'END_PERL', '->generate_script(default) ok' );
#!/usr/bin/perl

use strict;

END_PERL

	my $module  = $starter->generate_module( module => 'Foo::Bar' );
	is( $module, <<'END_PERL', '->generate_module(default) ok' );
package Foo::Bar;

use strict;

our $VERSION = '0.01';

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;

	return $self;
}

1;
END_PERL

	my $compile = $starter->generate_test_compile( module => 'Foo::Bar' );
	is( $compile, <<'END_PERL', '=>generate_test_compile(default) ok' );
#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 1;

use_ok( 'Foo::Bar' );

END_PERL
}
