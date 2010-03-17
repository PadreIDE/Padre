 #!/usr/bin/perl

###
# This is mostly a demo test script for using the action queue for testing
###

use strict;
use warnings;

# The real test...
package main;
use Test::More;

#use Test::NoWarnings;
use File::Temp ();
use File::Spec();

plan skip_all => 'DISPLAY not set'
 unless  $ENV{DISPLAY} or ($^O eq 'MSWin32');

# Don't run tests for installs
unless ( $ENV{AUTOMATED_TESTING} or $ENV{RELEASE_TESTING} ) {
	plan( skip_all => "Author tests not required for installation" );
}

my $devpl;
# Search for dev.pl
for ('.','blib/lib','lib') {
 if ($^O eq 'MSWin32') {
  next if ! -e File::Spec->catfile($_,'dev.pl');
 } else {
  next if ! -x File::Spec->catfile($_,'dev.pl');
 }
 $devpl = File::Spec->catfile($_,'dev.pl');
 last;
}

use_ok('Padre::Perl');

my $cmd;
for my $prefix ('',Padre::Perl::cperl().' ','"'.$^X.'" ','perl ','wperl ','/usr/bin/perl ','C:\\strawberry\\perl\\bin\\perl.exe ','/usr/pkg/bin/perl ') {
 next unless `$prefix$devpl --help` =~ /(run Padre in the command line|\-\-fulltrace|\-\-actionqueue)/;
 $cmd = $prefix;
 last;
}

plan skip_all => 'Need some Perl for this test' unless defined($cmd);

ok(1,'Using Perl: '.$cmd);

#plan( tests => scalar( keys %TEST ) * 2 + 20 );

# Create temp dir
my $dir = File::Temp->newdir;
$ENV{PADRE_HOME} = $dir->dirname;

# Complete the dev.pl - command
$cmd .= $devpl . ' --invisible -- --home=' . $dir->dirname;
$cmd .= ' ' . File::Spec->catfile($dir->dirname,'newfile.txt');
$cmd .= ' --actionqueue=internal.dump_padre,file.quit';

system $cmd;

my $dump_fn = File::Spec->catfile($dir->dirname,'padre.dump');

ok(-e $dump_fn,'Dump file exists');

our $VAR1;
# Read dump file into $VAR1
require_ok($dump_fn);

# Run the action checks...
foreach my $action (sort(keys(%{$VAR1->{actions}}))) {

 if ($action =~ /^run\./) {
  # All run actions need a open editor window and a saved file
  if ($action !~ /^run\.(stop|run_command)/) {
   ok($VAR1->{actions}->{$action}->{need_editor},$action.' requires a editor');
   ok($VAR1->{actions}->{$action}->{need_file},$action.' requires a filename');
  }
 }

 if ($action =~ /^perl\./) {
  # All perl actions need a open editor window
  ok($VAR1->{actions}->{$action}->{need_editor},$action.' requires a editor');
 }

}

done_testing();
