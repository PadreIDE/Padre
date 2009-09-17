use strict;
use warnings;
use Test::More;
BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}

# Checks for UNIX end of lines (aka newlines)
use File::Find::Rule;
use t::lib::Padre;
use Padre::Util qw(newline_type);

my @files = File::Find::Rule
	->file
	->name('*.pm', '*.pod', '*.pl', '*.p6', '*.t', '*.yml', '*.txt')
	->in('lib', 't', 'share');

plan( tests => scalar @files + 5);
foreach my $file ( @files ) {
	is(newline_type(slurp($file)), "UNIX");
}

is(newline_type(slurp('Artistic')), "UNIX");
is(newline_type(slurp('COPYING')), "UNIX");
is(newline_type(slurp('Makefile.PL')), "UNIX");
is(newline_type(slurp('Changes')), "UNIX");
is(newline_type(slurp('padre.yml')), "UNIX");

######################################################################
# Support Functions

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die $!;
	binmode $fh;
	local $/ = undef;
	return <$fh>;
}
