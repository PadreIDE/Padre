#!/usr/bin/perl

use strict;
use warnings;
use constant CONFIG_OPTIONS => 126;

# Move of Debug to Run Menu
# TODO can someone who knows what *2 + 21 means explain it in a comment please.
use Test::More tests => CONFIG_OPTIONS * 3 + 21;
use Test::NoWarnings;
use File::Spec::Functions ':ALL';
use File::Temp ();

BEGIN {
	$ENV{PADRE_HOME} = File::Temp::tempdir( CLEANUP => 1 );
}
use Padre::Constant ();
use Padre::Config   ();

# Loading the configuration subsystem should NOT result in loading Wx
is( $Wx::VERSION, undef, 'Wx was not loaded during config load' );

# Create the empty config file
my $empty = Padre::Constant::CONFIG_HUMAN;
open( my $FILE, '>', $empty ) or die "Failed to open $empty";
print $FILE "--- {}\n";
close($FILE);

# Load the config
my $config = Padre::Config->read;
isa_ok( $config,        'Padre::Config' );
isa_ok( $config->host,  'Padre::Config::Host' );
isa_ok( $config->human, 'Padre::Config::Human' );
is( $config->project,        undef, '->project is undef' );
is( $config->host->version,  undef, '->host->version is undef' );
is( $config->human->version, undef, '->human->version is undef' );

# Loading the config file should not result in Wx loading
is( $Wx::VERSION, undef, 'Wx was not loaded during config read' );

my $preferences = do {
	open my $fh, 'lib/Padre/Wx/Dialog/Preferences.pm' or die;
	local $/ = undef;
	<$fh>;
};

my %SKIP = map { $_ => 1 } qw(
	builder
	license
	threads
	config_sync_username
	config_sync_password
	main_directory_order
	main_top
	run_save
	find_case
	main_left
	main_todo
	editor_eol
	find_first
	find_regex
	main_width
	begerror_DB
	main_height
	begerror_map
	editor_style
	find_nomatch
	find_reverse
	main_outline
	main_toolbar
	begerror_map2
	feedback_done
	find_nohidden
	identity_name
	startup_count
	begerror_chomp
	begerror_close
	begerror_perl6
	begerror_split
	editor_folding
	identity_email
	main_directory
	main_maximized
	main_statusbar
	run_stacktrace
	begerror_elseif
	begerror_regexq
	feature_cursormemory
	main_directory_order
	main_directory_root
	main_directory_panel
	perl_ppi_lexer_limit
	editor_file_size_limit
	feature_quick_fix
	file_http_timeout
	identity_nickname
	main_command_line
	begerror_pipe2open
	config_sync_server
	editor_linenumbers
	main_lockinterface
	main_toolbar_items
	autocomplete_always
	autocomplete_method
	module_start_directory
	autocomplete_subroutine
	config_perltidy
	editor_calltips
	feature_session
	begerror_warning
	feature_bookmark
	feature_debugger
	feature_fontsize
	file_ftp_passive
	file_ftp_timeout
	main_syntaxcheck
	session_autosave
	begerror_ifsetvar
	begerror_pipeopen
	config_perlcritic
	editor_whitespace
	feature_wizard_selector
	editor_indentationguides
	main_singleinstance_port
	sessionmanager_sortorder
	perl_autocomplete_min_chars
	xs_calltips_perlapi_version
	feature_restart_hung_task_manager
	perl_autocomplete_max_suggestions
	editor_brace_expression_highlighting
	perl_autocomplete_min_suggestion_len
);

# Check that the defaults work
my @names =
	sort { length($a) <=> length($b) or $a cmp $b } keys %Padre::Config::SETTING;
is( scalar(@names), CONFIG_OPTIONS, 'Expected number of config options' );
foreach my $name (@names) {
	SKIP: {
		skip "'$name' is known to be missing from the preferences window", 1 if $SKIP{$name};
		ok $preferences =~ m/$name/, "'$name' is in the preferences window";
	}
	ok( defined( $config->$name() ), "->$name is defined" );
	is( $config->$name(),
		$Padre::Config::DEFAULT{$name},
		"->$name defaults ok",
	);
}

# The config version number is a requirement for every config and
# the only key which is allowed to live in an empty config.
my %test_config = ( Version => $Padre::Config::VERSION );

# ... and that they don't leave a permanent state.
is_deeply(
	+{ %{ $config->human } }, \%test_config,
	'Defaults do not leave permanent state (human)',
);
is_deeply(
	+{ %{ $config->host } }, \%test_config,
	'Defaults do not leave permanent state (host)',
);

# Store the config again
ok( $config->write, '->write ok' );

# Saving the config file should not result in Wx loading
is( $Wx::VERSION, undef, 'Wx was not loaded during config write' );

# Check that we have a version for the parts now
is( $config->host->version,  1, '->host->version is set' );
is( $config->human->version, 1, '->human->version is set' );

# Set values on both the human and host sides
ok( $config->set( main_lockinterface => 0 ),
	'->set(human) ok',
);
ok( $config->set( main_maximized => 1 ),
	'->set(host) ok',
);

# Save the config again
ok( $config->write, '->write ok' );

# Read in a fresh version of the config
my $config2 = Padre::Config->read;

# Confirm the config is round-trip safe
is_deeply( $config2, $config, 'Config round-trips ok' );

# No configuration operations require loading Wx
is( $Wx::VERSION, undef, 'Wx is never loaded during config operations' );
