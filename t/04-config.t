#!/usr/bin/perl

use strict;
use warnings;
use constant NUMBER_OF_CONFIG_OPTIONS => 127;

# Move of Debug to Run Menu
use Test::More tests => NUMBER_OF_CONFIG_OPTIONS * 3 + 21;
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
	open( my $fh, '<', 'lib/Padre/Wx/Dialog/Preferences.pm' ) or die;
	local $/ = undef;
	my $line = <$fh>;
	close $fh;
	$line;
};

# szabgab:
# We check each configuration option if it is also visible on
# the Preference window. As some of them don't yet appear there
# we have a list of config options here that are known to NOT appear
# in the Preference window.
# We don't have to put every option in the Preference window, after
# all the Advanced window should be also used for something
# but at least it can be useful to know which one don't have such view.
# Probably it would be even better if we had a mapping of each config option
# and the subwindow it appears in.
my %NOT_IN_PREFERENCES = map { $_ => 1 } qw(
	autocomplete_always
	autocomplete_method
	autocomplete_subroutine

	begerror_DB
	begerror_map
	begerror_map2
	begerror_chomp
	begerror_close
	begerror_perl6
	begerror_split
	begerror_elseif
	begerror_regexq
	begerror_pipe2open
	begerror_warning
	begerror_ifsetvar
	begerror_pipeopen
	builder

	config_perlcritic
	config_sync_server
	config_perltidy
	config_sync_username
	config_sync_password

	editor_eol
	editor_style
	editor_folding
	editor_file_size_limit
	editor_linenumbers
	editor_calltips
	editor_whitespace
	editor_brace_expression_highlighting
	editor_indentationguides

	feature_wizard_selector
	feature_restart_hung_task_manager
	feature_session
	feature_bookmark
	feature_debugger
	feature_fontsize
	file_ftp_passive
	file_ftp_timeout
	feature_cursormemory
	feedback_done
	find_nohidden
	find_case
	find_first
	find_regex
	find_nomatch
	find_reverse
	feature_quick_fix
	file_http_timeout

	identity_name
	identity_email
	identity_nickname

	license

	main_directory_order
	main_top
	main_left
	main_todo
	main_width
	main_height
	main_outline
	main_toolbar
	main_directory
	main_maximized
	main_statusbar
	main_directory_order
	main_directory_root
	main_directory_panel
	main_command_line
	main_lockinterface
	main_toolbar_items
	module_start_directory
	main_syntaxcheck
	main_singleinstance_port

	perl_ppi_lexer_limit
	perl_autocomplete_min_chars
	perl_autocomplete_max_suggestions
	perl_autocomplete_min_suggestion_len

	run_save
	run_stacktrace

	startup_count
	session_autosave
	sessionmanager_sortorder

	threads

	xs_calltips_perlapi_version
);

# Check that the defaults work
my @names =
	sort { length($a) <=> length($b) or $a cmp $b } keys %Padre::Config::SETTING;
is( scalar(@names), NUMBER_OF_CONFIG_OPTIONS, 'Expected number of config options' );
foreach my $name (@names) {

	# simple way to check if config option is in the preferences window
	SKIP: {
		skip "'$name' is known to be missing from the preferences window", 1 if $NOT_IN_PREFERENCES{$name};
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
