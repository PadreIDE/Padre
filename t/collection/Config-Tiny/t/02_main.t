#!/usr/bin/perl -w

# Main testing script for Config::Tiny

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use UNIVERSAL;
use Test::More tests => 33;

use vars qw{$VERSION};
BEGIN {
	$VERSION = '2.12';
}



# Check their perl version
BEGIN {
	ok( $] >= 5.004, "Your perl is new enough" );
	use_ok('Config::Tiny');
}
is( $Config::Tiny::VERSION, $VERSION, 'Loaded correct version of Config::Tiny' );

# Test trivial creation
my $Trivial = Config::Tiny->new();
ok( $Trivial, '->new returns true' );
ok( ref $Trivial, '->new returns a reference' );
# Legitimate use of UNIVERSAL::isa
ok( UNIVERSAL::isa( $Trivial, 'HASH' ), '->new returns a hash reference' );
isa_ok( $Trivial, 'Config::Tiny' );
ok( scalar keys %$Trivial == 0, '->new returns an empty object' );

# Try to read in a config
my $Config = Config::Tiny->read( 'test.conf' );
ok( $Config, '->read returns true' );
ok( ref $Config, '->read returns a reference' );
# Legitimate use of UNIVERSAL::isa
ok( UNIVERSAL::isa( $Config, 'HASH' ), '->read returns a hash reference' );
isa_ok( $Config, 'Config::Tiny' );

# Check the structure of the config
my $expected = {
	'_' => {
		root => 'something',
		},
	section => {
		one => 'two',
		Foo => 'Bar',
		this => 'Your Mother!',
		blank => '',
		},
	'Section Two' => {
		'something else' => 'blah',
		'remove' => 'whitespace',
		},
	};
bless $expected, 'Config::Tiny';
is_deeply( $Config, $expected, 'Config structure matches expected' );

# Add some stuff to the trivial config and check write_string() for it
$Trivial->{_} = { root1 => 'root2' };
$Trivial->{section} = {
	foo => 'bar',
	this => 'that',
	blank => '',
	};
$Trivial->{section2} = {
	'this little piggy' => 'went to market'
	};
my $string = <<END;
root1=root2

[section]
blank=
foo=bar
this=that

[section2]
this little piggy=went to market
END

# Test read_string
my $Read = Config::Tiny->read_string( $string );
ok( $Read, '->read_string returns true' );
is_deeply( $Read, $Trivial, '->read_string returns expected value' );

my $generated = $Trivial->write_string();
ok( length $generated, '->write_string returns something' );
ok( $generated eq $string, '->write_string returns the correct file contents' );

# Try to write a file
my $rv = $Trivial->write( 'test2.conf' );
ok( $rv, '->write returned true' );
ok( -e 'test2.conf', '->write actually created a file' );

# Try to read the config back in
$Read = Config::Tiny->read( 'test2.conf' );
ok( $Read, '->read of what we wrote returns true' );
ok( ref $Read, '->read of what we wrote returns a reference' );
# Legitimate use of UNIVERSAL::isa
ok( UNIVERSAL::isa( $Read, 'HASH' ), '->read of what we wrote returns a hash reference' );
isa_ok( $Read, 'Config::Tiny' );

# Check the structure of what we read back in
is_deeply( $Read, $Trivial, 'What we read matches what we wrote out' );

END {
	# Clean up
	unlink 'test2.conf';
}





#####################################################################
# Bugs that happened we don't want to happen again

{
# Reading in an empty file, or a defined but zero length string, should yield
# a valid, but empty, object.
my $Empty = Config::Tiny->read_string('');
isa_ok( $Empty, 'Config::Tiny' );
is( scalar(keys %$Empty), 0, 'Config::Tiny object from empty string, is empty' );
}



{
# A Section header like [ section ] doesn't end up at ->{' section '}.
# Trim off whitespace from the section header.
my $string = <<'END';
# The need to trim off whitespace makes a lot more sense
# when you are trying to maximise readability.
[ /path/to/file.txt ]
this=that

[ section2]
this=that

[section3 ]
this=that

END

my $Trim = Config::Tiny->read_string($string);
isa_ok( $Trim, 'Config::Tiny' );
ok( exists $Trim->{'/path/to/file.txt'}, 'First section created' );
is( $Trim->{'/path/to/file.txt'}->{this}, 'that', 'First section created properly' );
ok( exists $Trim->{section2}, 'Second section created' );
is( $Trim->{section2}->{this}, 'that', 'Second section created properly' );
ok( exists $Trim->{section3}, 'Third section created' );
is( $Trim->{section3}->{this}, 'that', 'Third section created properly' );
}
