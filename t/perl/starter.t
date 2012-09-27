#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 8;
use Test::NoWarnings;

use Padre::Document::Perl::Starter ();

use constant {
	Starter => 'Padre::Document::Perl::Starter',
	Style   => 'Padre::Document::Perl::Starter::Style',
};





######################################################################
# Constructor

SCOPE: {
	my $starter = new_ok(Starter);
	isa_ok( $starter->style, Style );
}





######################################################################
# Simple Perl files with default settings

SCOPE: {
	my $starter = new_ok(Starter);

	my $script = $starter->generate_script;
	is( $script, <<'END_PERL', '->generate_script(default) ok' );
#!/usr/bin/perl

use strict;
use warnings;

END_PERL

	my $module  = $starter->generate_module( module => 'Foo::Bar' );
	is( $module, <<'END_PERL', '->generate_module(default) ok' );
package Foo::Bar;

use strict;
use warnings;

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

require_ok('Foo::Bar');
END_PERL

	my $test = $starter->generate_test;
	is( $test, <<'END_PERL', '=>generate_test ok' );
#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 1;

ok( 0, 'Dummy Test' );
END_PERL
}
