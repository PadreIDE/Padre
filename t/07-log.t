#!/usr/bin/perl

use 5.006;
use strict;
use warnings;
use Test::More tests => 145;
use Padre::Log;

can_ok( 'Padre::Log', qw(debug info warn error fatal) );
can_ok( 'Padre::Log', qw(is_debug is_info is_warn is_error is_fatal) );

my $log = Padre::Log->new();
isa_ok( $log, 'Padre::Log' );
ok( !$log->is_debug, 'default log level should be "warn"' );
ok( !$log->is_info,  'default log level should be "warn"' );
ok( $log->is_warn,   'default log level should be "warn"' );
ok( $log->is_error,  'default log level should be "warn"' );
ok( $log->is_fatal,  'default log level should be "warn"' );


$log = Padre::Log->new( level => 'debug' );
ok( $log->is_debug, '"debug" should be defined under log level "debug"' );
ok( $log->is_info,  '"info" should be defined under log level "debug"' );
ok( $log->is_warn,  '"warn" should be defined under log level "debug"' );
ok( $log->is_error, '"error" should be defined under log level "debug"' );
ok( $log->is_fatal, '"fatal" should be defined under log level "debug"' );

$log = Padre::Log->new( level => 'info' );
ok( !$log->is_debug, '"debug" should *not* be defined under log level "info"' );
ok( $log->is_info,   '"info" should be defined under log level "info"' );
ok( $log->is_warn,   '"warn" should be defined under log level "info"' );
ok( $log->is_error,  '"error" should be defined under log level "info"' );
ok( $log->is_fatal,  '"fatal" should be defined under log level "info"' );

$log = Padre::Log->new( level => 'warn' );
ok( !$log->is_debug, '"debug" should *not* be defined under log level "warn"' );
ok( !$log->is_info,  '"info" should *not* be defined under log level "warn"' );
ok( $log->is_warn,   '"warn" should be defined under log level "warn"' );
ok( $log->is_error,  '"error" should be defined under log level "warn"' );
ok( $log->is_fatal,  '"fatal" should be defined under log level "warn"' );

$log = Padre::Log->new( level => 'error' );
ok( !$log->is_debug, '"debug" should *not* be defined under log level "error"' );
ok( !$log->is_info,  '"info" should *not* be defined under log level "error"' );
ok( !$log->is_warn,  '"warn" should *not* be defined under log level "error"' );
ok( $log->is_error,  '"error" should be defined under log level "error"' );
ok( $log->is_fatal,  '"fatal" should be defined under log level "error"' );

$log = Padre::Log->new( level => 'fatal' );
ok( !$log->is_debug, '"debug" should *not* be defined under log level "fatal"' );
ok( !$log->is_info,  '"info" should *not* be defined under log level "fatal"' );
ok( !$log->is_warn,  '"warn" should *not* be defined under log level "fatal"' );
ok( !$log->is_error, '"error" should *not* be defined under log level "fatal"' );
ok( $log->is_fatal,  '"fatal" should be defined under log level "fatal"' );

$log = Padre::Log->new( level => 'off' );
ok( !$log->is_debug, '"debug" should *not* be defined under log level "off"' );
ok( !$log->is_info,  '"info" should *not* be defined under log level "off"' );
ok( !$log->is_warn,  '"warn" should *not* be defined under log level "off"' );
ok( !$log->is_error, '"error" should *not* be defined under log level "off"' );
ok( !$log->is_fatal, '"fatal" should *not* be defined under log level "off"' );


# tests to ensure case-insensitiveness
$log = Padre::Log->new( level => 'DeBUg' );
ok( $log->is_debug, '"debug" should be defined under log level "debug"' );
ok( $log->is_info,  '"info" should be defined under log level "debug"' );
ok( $log->is_warn,  '"warn" should be defined under log level "debug"' );
ok( $log->is_error, '"error" should be defined under log level "debug"' );
ok( $log->is_fatal, '"fatal" should be defined under log level "debug"' );

$log = Padre::Log->new( level => 'InFo' );
ok( !$log->is_debug, '"debug" should *not* be defined under log level "info"' );
ok( $log->is_info,   '"info" should be defined under log level "info"' );
ok( $log->is_warn,   '"warn" should be defined under log level "info"' );
ok( $log->is_error,  '"error" should be defined under log level "info"' );
ok( $log->is_fatal,  '"fatal" should be defined under log level "info"' );

$log = Padre::Log->new( level => 'WaRn' );
ok( !$log->is_debug, '"debug" should *not* be defined under log level "warn"' );
ok( !$log->is_info,  '"info" should *not* be defined under log level "warn"' );
ok( $log->is_warn,   '"warn" should be defined under log level "warn"' );
ok( $log->is_error,  '"error" should be defined under log level "warn"' );
ok( $log->is_fatal,  '"fatal" should be defined under log level "warn"' );

$log = Padre::Log->new( level => 'ErROr' );
ok( !$log->is_debug, '"debug" should *not* be defined under log level "error"' );
ok( !$log->is_info,  '"info" should *not* be defined under log level "error"' );
ok( !$log->is_warn,  '"warn" should *not* be defined under log level "error"' );
ok( $log->is_error,  '"error" should be defined under log level "error"' );
ok( $log->is_fatal,  '"fatal" should be defined under log level "error"' );

$log = Padre::Log->new( level => 'FaTAl' );
ok( !$log->is_debug, '"debug" should *not* be defined under log level "fatal"' );
ok( !$log->is_info,  '"info" should *not* be defined under log level "fatal"' );
ok( !$log->is_warn,  '"warn" should *not* be defined under log level "fatal"' );
ok( !$log->is_error, '"error" should *not* be defined under log level "fatal"' );
ok( $log->is_fatal,  '"fatal" should be defined under log level "fatal"' );

$log = Padre::Log->new( level => 'oFf' );
ok( !$log->is_debug, '"debug" should *not* be defined under log level "off"' );
ok( !$log->is_info,  '"info" should *not* be defined under log level "off"' );
ok( !$log->is_warn,  '"warn" should *not* be defined under log level "off"' );
ok( !$log->is_error, '"error" should *not* be defined under log level "off"' );
ok( !$log->is_fatal, '"fatal" should *not* be defined under log level "off"' );


# tests to ensure logger's live switching feature:
$log = Padre::Log->new( level => 'debug' );
ok( $log->is_debug, '"debug" should be defined under log level "debug"' );
ok( $log->is_info,  '"info" should be defined under log level "debug"' );
ok( $log->is_warn,  '"warn" should be defined under log level "debug"' );
ok( $log->is_error, '"error" should be defined under log level "debug"' );
ok( $log->is_fatal, '"fatal" should be defined under log level "debug"' );

$log->set_log_level('info');
ok( !$log->is_debug, '"debug" should *not* be defined under log level "info"' );
ok( $log->is_info,   '"info" should be defined under log level "info"' );
ok( $log->is_warn,   '"warn" should be defined under log level "info"' );
ok( $log->is_error,  '"error" should be defined under log level "info"' );
ok( $log->is_fatal,  '"fatal" should be defined under log level "info"' );

$log->set_log_level('warn');
ok( !$log->is_debug, '"debug" should *not* be defined under log level "warn"' );
ok( !$log->is_info,  '"info" should *not* be defined under log level "warn"' );
ok( $log->is_warn,   '"warn" should be defined under log level "warn"' );
ok( $log->is_error,  '"error" should be defined under log level "warn"' );
ok( $log->is_fatal,  '"fatal" should be defined under log level "warn"' );

$log->set_log_level('error');
ok( !$log->is_debug, '"debug" should *not* be defined under log level "error"' );
ok( !$log->is_info,  '"info" should *not* be defined under log level "error"' );
ok( !$log->is_warn,  '"warn" should *not* be defined under log level "error"' );
ok( $log->is_error,  '"error" should be defined under log level "error"' );
ok( $log->is_fatal,  '"fatal" should be defined under log level "error"' );

$log->set_log_level('fatal');
ok( !$log->is_debug, '"debug" should *not* be defined under log level "fatal"' );
ok( !$log->is_info,  '"info" should *not* be defined under log level "fatal"' );
ok( !$log->is_warn,  '"warn" should *not* be defined under log level "fatal"' );
ok( !$log->is_error, '"error" should *not* be defined under log level "fatal"' );
ok( $log->is_fatal,  '"fatal" should be defined under log level "fatal"' );

$log->set_log_level('debug');
ok( $log->is_debug, '"debug" should be defined under log level "debug"' );
ok( $log->is_info,  '"info" should be defined under log level "debug"' );
ok( $log->is_warn,  '"warn" should be defined under log level "debug"' );
ok( $log->is_error, '"error" should be defined under log level "debug"' );
ok( $log->is_fatal, '"fatal" should be defined under log level "debug"' );

$log->set_log_level('off');
ok( !$log->is_debug, '"debug" should *not* be defined under log level "off"' );
ok( !$log->is_info,  '"info" should *not* be defined under log level "off"' );
ok( !$log->is_warn,  '"warn" should *not* be defined under log level "off"' );
ok( !$log->is_error, '"error" should *not* be defined under log level "off"' );
ok( !$log->is_fatal, '"fatal" should *not* be defined under log level "off"' );

# tests to ensure logger's live switching feature (same, with case insensitiveness):
$log = Padre::Log->new( level => 'DEbUg' );
ok( $log->is_debug, '"debug" should be defined under log level "debug"' );
ok( $log->is_info,  '"info" should be defined under log level "debug"' );
ok( $log->is_warn,  '"warn" should be defined under log level "debug"' );
ok( $log->is_error, '"error" should be defined under log level "debug"' );
ok( $log->is_fatal, '"fatal" should be defined under log level "debug"' );

$log->set_log_level('Info');
ok( !$log->is_debug, '"debug" should *not* be defined under log level "info"' );
ok( $log->is_info,   '"info" should be defined under log level "info"' );
ok( $log->is_warn,   '"warn" should be defined under log level "info"' );
ok( $log->is_error,  '"error" should be defined under log level "info"' );
ok( $log->is_fatal,  '"fatal" should be defined under log level "info"' );

$log->set_log_level('waRN');
ok( !$log->is_debug, '"debug" should *not* be defined under log level "warn"' );
ok( !$log->is_info,  '"info" should *not* be defined under log level "warn"' );
ok( $log->is_warn,   '"warn" should be defined under log level "warn"' );
ok( $log->is_error,  '"error" should be defined under log level "warn"' );
ok( $log->is_fatal,  '"fatal" should be defined under log level "warn"' );

$log->set_log_level('eRrOr');
ok( !$log->is_debug, '"debug" should *not* be defined under log level "error"' );
ok( !$log->is_info,  '"info" should *not* be defined under log level "error"' );
ok( !$log->is_warn,  '"warn" should *not* be defined under log level "error"' );
ok( $log->is_error,  '"error" should be defined under log level "error"' );
ok( $log->is_fatal,  '"fatal" should be defined under log level "error"' );

$log->set_log_level('FATAL');
ok( !$log->is_debug, '"debug" should *not* be defined under log level "fatal"' );
ok( !$log->is_info,  '"info" should *not* be defined under log level "fatal"' );
ok( !$log->is_warn,  '"warn" should *not* be defined under log level "fatal"' );
ok( !$log->is_error, '"error" should *not* be defined under log level "fatal"' );
ok( $log->is_fatal,  '"fatal" should be defined under log level "fatal"' );

$log->set_log_level('DEBug');
ok( $log->is_debug, '"debug" should be defined under log level "debug"' );
ok( $log->is_info,  '"info" should be defined under log level "debug"' );
ok( $log->is_warn,  '"warn" should be defined under log level "debug"' );
ok( $log->is_error, '"error" should be defined under log level "debug"' );
ok( $log->is_fatal, '"fatal" should be defined under log level "debug"' );

$log->set_log_level('OFf');
ok( !$log->is_debug, '"debug" should *not* be defined under log level "off"' );
ok( !$log->is_info,  '"info" should *not* be defined under log level "off"' );
ok( !$log->is_warn,  '"warn" should *not* be defined under log level "off"' );
ok( !$log->is_error, '"error" should *not* be defined under log level "off"' );
ok( !$log->is_fatal, '"fatal" should *not* be defined under log level "off"' );

# testing all other new() parameters
$log = Padre::Log->new();
is( $log->get_filename, undef, 'new() method should have set default filename properly' );
ok( !$log->is_trace, 'new() method should have set default trace mode properly' );

$log = Padre::Log->new(
	trace    => 1,
	filename => '/some/file',
);

is( $log->get_filename, '/some/file', 'new() method should have set the proper filename' );
ok( $log->is_trace, 'new() method should have set trace mode on' );

# test tracing methods
$log->disable_trace;
ok( !$log->is_trace, 'disable_trace() method should have disabled trace output' );
$log->enable_trace;
ok( $log->is_trace, 'enable_trace() method should have enabled trace output' );

# test filename methods
$log->set_filename('/yet/another/file');
is( $log->get_filename, '/yet/another/file', 'set_filename() method should have set the proper filename' );

note('logging into files is not currently tested on all plattforms, so, use with caution');
