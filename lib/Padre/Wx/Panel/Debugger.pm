package Padre::Wx::Panel::Debugger;

use 5.010;
use strict;
use warnings;
no if $] > 5.017010, warnings => 'experimental::smartmatch';

use utf8;
use Padre::Util              ();
use Padre::Constant          ();
use Padre::Wx                ();
use Padre::Wx::Util          ();
use Padre::Wx::Icon          ();
use Padre::Wx::Role::View    ();
use Padre::Wx::FBP::Debugger ();
use Padre::Breakpoints       ();
use Padre::Logger;
use Debug::Client 0.20 ();

our $VERSION = '1.00';
our @ISA     = qw{
	Padre::Wx::Role::View
	Padre::Wx::FBP::Debugger
};

use constant {
	BLANK      => qq{},
	RED        => Wx::Colour->new('red'),
	DARK_GREEN => Wx::Colour->new( 0x00, 0x90, 0x00 ),
	BLUE       => Wx::Colour->new('blue'),
	GRAY       => Wx::Colour->new('gray'),
	DARK_GRAY  => Wx::Colour->new( 0x7f, 0x7f, 0x7f ),
	BLACK      => Wx::Colour->new('black'),
};


#######
# new
#######
sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->right;

	# Create the panel
	my $self = $class->SUPER::new($panel);

	$self->set_up;

	return $self;
}

###############
# Make Padre::Wx::Role::View happy
###############

sub view_panel {
	'right';
}

sub view_label {
	Wx::gettext('Debugger');
}


sub view_close {
	$_[0]->main->show_debugger(0);
}

sub view_icon {
	Padre::Wx::Icon::find('actions/morpho3');
}

###############
# Make Padre::Wx::Role::View happy end
###############


#######
# Method set_up
#######
sub set_up {
	my $self = shift;
	my $main = $self->main;

	$self->{debug_client_version} = $Debug::Client::VERSION;
	$self->{debug_client_version} =~ s/^(\d.\d{2}).*/$1/;

	$self->{client}           = undef;
	$self->{file}             = undef;
	$self->{save}             = {};
	$self->{trace_status}     = 'Trace = off';
	$self->{var_val}          = {};
	$self->{local_values}     = {};
	$self->{global_values}    = {};
	$self->{set_bp}           = 0;
	$self->{fudge}            = 0;
	$self->{local_variables}  = 0;
	$self->{global_variables} = 0;

	#turn off unless in project
	$self->{show_global_variables}->Disable;
	$self->{show_local_variables}->Disable;

	# $self->{show_local_variables}->SetValue(1);
	# $self->{local_variables} = 1;
	$self->{show_local_variables}->SetValue(0);
	$self->{local_variables} = 0;

	# Setup the debug button icons
	$self->{debug}->SetBitmapLabel( Padre::Wx::Icon::find('actions/morpho2') );
	$self->{debug}->Enable;

	$self->{step_in}->SetBitmapLabel( Padre::Wx::Icon::find('actions/step_in') );
	$self->{step_in}->Hide;

	$self->{step_over}->SetBitmapLabel( Padre::Wx::Icon::find('actions/step_over') );
	$self->{step_over}->Hide;

	$self->{step_out}->SetBitmapLabel( Padre::Wx::Icon::find('actions/step_out') );
	$self->{step_out}->Hide;

	$self->{run_till}->SetBitmapLabel( Padre::Wx::Icon::find('actions/run_till') );
	$self->{run_till}->Hide;

	$self->{display_value}->SetBitmapLabel( Padre::Wx::Icon::find('stock/code/stock_macro-watch-variable') );
	$self->{display_value}->Hide;

	$self->{quit_debugger}->SetBitmapLabel( Padre::Wx::Icon::find('actions/red_cross') );
	$self->{quit_debugger}->Enable;

	$self->{list_action}->SetBitmapLabel( Padre::Wx::Icon::find('actions/4c-l') );
	$self->{list_action}->Disable;

	$self->{dot}->SetBitmapLabel( Padre::Wx::Icon::find('actions/dot') );
	$self->{dot}->Disable;

	$self->{view_around}->SetBitmapLabel( Padre::Wx::Icon::find('actions/76-v') );
	$self->{view_around}->Disable;

	$self->{stacktrace}->SetBitmapLabel( Padre::Wx::Icon::find('actions/54-t') );
	$self->{stacktrace}->Disable;

	$self->{module_versions}->SetBitmapLabel( Padre::Wx::Icon::find('actions/4d-m') );
	$self->{module_versions}->Disable;

	$self->{all_threads}->SetBitmapLabel( Padre::Wx::Icon::find('actions/45-e') );
	$self->{all_threads}->Disable;

	$self->{trace}->Disable;
	$self->{evaluate_expression}->SetBitmapLabel( Padre::Wx::Icon::find('actions/pux') );
	$self->{evaluate_expression}->Disable;
	$self->{expression}->SetValue(BLANK);
	$self->{expression}->Disable;

	$self->{running_bp}->SetBitmapLabel( Padre::Wx::Icon::find('actions/bub') );
	$self->{running_bp}->Disable;

	$self->{sub_names}->SetBitmapLabel( Padre::Wx::Icon::find('actions/53-s') );
	$self->{sub_names}->Disable;

	$self->{display_options}->SetBitmapLabel( Padre::Wx::Icon::find('actions/6f-o') );
	$self->{display_options}->Disable;

	$self->{watchpoints}->SetBitmapLabel( Padre::Wx::Icon::find('actions/wuw') );
	$self->{watchpoints}->Disable;
	$self->{raw}->SetBitmapLabel( Padre::Wx::Icon::find('actions/raw') );
	$self->{raw}->Disable;

	# Setup columns names and order here
	my @column_headers = qw( Variable Value );
	my $index          = 0;
	for my $column_header (@column_headers) {
		$self->{variables}->InsertColumn( $index++, Wx::gettext($column_header) );
	}

	# Tidy the list
	Padre::Wx::Util::tidy_list( $self->{variables} );

	return;
}

#######
# Composed Method,
# display any relation db
#######
sub update_variables {
	my $self              = shift;
	my $var_val_ref       = shift;
	my $local_values_ref  = shift;
	my $global_values_ref = shift;
	my $editor            = $self->current->editor;

	# clear ListCtrl items
	$self->{variables}->DeleteAllItems;

	my $index = 0;
	my $item  = Wx::ListItem->new;
	foreach my $var ( keys %{$var_val_ref} ) {

		$item->SetId($index);
		$self->{variables}->InsertItem($item);
		$self->{variables}->SetItemTextColour( $index, BLACK );

		$self->{variables}->SetItem( $index,   0, $var );
		$self->{variables}->SetItem( $index++, 1, $var_val_ref->{$var} );
	}

	if ( $self->{local_variables} == 1 ) {
		foreach my $var ( keys %{$local_values_ref} ) {

			$item->SetId($index);
			$self->{variables}->InsertItem($item);
			$self->{variables}->SetItemTextColour( $index, BLUE );

			$self->{variables}->SetItem( $index,   0, $var );
			$self->{variables}->SetItem( $index++, 1, $local_values_ref->{$var} );
		}
	}
	if ( $self->{global_variables} == 1 ) {
		foreach my $var ( keys %{$global_values_ref} ) {

			$item->SetId($index);
			$self->{variables}->InsertItem($item);
			$self->{variables}->SetItemTextColour( $index, DARK_GRAY );

			$self->{variables}->SetItem( $index,   0, $var );
			$self->{variables}->SetItem( $index++, 1, $global_values_ref->{$var} );
		}
	}

	# Tidy the list
	Padre::Wx::Util::tidy_list( $self->{variables} );

	return;
}


#######
# sub debug_perl
#######
sub debug_perl {
	my $self = shift;
	my $arg_ref = shift || { debug => 1 };

	my $main     = $self->main;
	my $current  = $self->current;
	my $document = $current->document;
	my $editor   = $current->editor;

	# test for valid perl document
	if ( !$document || $document->mimetype !~ m/perl/ ) {
		return;
	}

	# display panels
	$main->show_debugoutput(1);

	if ( $self->{client} ) {
		$main->error( Wx::gettext('Debugger is already running') );
		return;
	}
	unless ( $document->isa('Padre::Document::Perl') ) {
		$main->error( Wx::gettext('Not a Perl document') );
		return;
	}

	# Apply the user's save-on-run policy
	# TO DO: Make this code suck less
	my $config = $main->config;
	if ( $config->run_save eq 'same' ) {
		$main->on_save;
	} elsif ( $config->run_save eq 'all_files' ) {
		$main->on_save_all;
	} elsif ( $config->run_save eq 'all_buffer' ) {
		$main->on_save_all;
	}

	#TODO I think this is where the Fup filenames are comming from, see POD in main
	# Get the filename
	# my $filename = defined( $document->{file} ) ? $document->{file}->filename : undef;

	#changed due to define is deprecated in perl 5.15.7
	my $filename;
	if ( defined $document->{file} ) {
		$filename = $document->{file}->filename;
	} else {
		$filename = undef;
	}

	# TODO: improve the message displayed to the user
	# If the document is not saved, simply return for now
	return unless $filename;

	#TODO how do we add debug options at startup such as threaded mode

	# Set up the debugger
	my $host = '127.0.0.1';
	my $port = 24642 + int rand(1000); # TODO make this configurable?
	SCOPE: {
		local $ENV{PERLDB_OPTS} = "RemotePort=$host:$port";
		my ( $cmd, $ref ) = $document->get_command($arg_ref);

		#TODO: consider pushing the chdir into run_command (as there is a hidden 'cd' in it)
		my $dir = Cwd::cwd;
		chdir $arg_ref->{run_directory} if ( exists( $arg_ref->{run_directory} ) );
		$main->run_command($cmd);
		chdir $dir;
	}

	# Bootstrap the debugger
	# require Debug::Client;
	$self->{client} = Debug::Client->new(
		host => $host,
		port => $port,
	);

	#ToDo remove when Debug::Client 0.22 is released.
	if ( $self->{debug_client_version} eq '0.20' ) {
		$self->{client}->listener;
	}
	$self->{file} = $filename;

	#Now we ask where are we
	#ToDo remove when Debug::Client 0.22 is released.
	if ( $self->{debug_client_version} eq '0.20' ) {
		$self->{client}->get;
	}
	$self->{client}->get_lineinfo;

	my $save = ( $self->{save}->{$filename} ||= {} );

	if ( $self->{set_bp} == 0 ) {

		# get bp's from db and set b|B (remember it's a toggle) hence we do this only once
		$self->_get_bp_db;
		$self->{set_bp} = 1;
	}

	unless ( $self->_set_debugger ) {
		$main->error( Wx::gettext('Debugging failed. Did you check your program for syntax errors?') );
		$self->debug_quit;
		return;
	}

	return 1;
}

#######
# sub _set_debugger
#######
sub _set_debugger {
	my $self    = shift;
	my $main    = $self->main;
	my $current = $self->current;
	my $editor  = $current->editor or return;
	my $file    = $self->{client}->{filename} or return;
	my $row     = $self->{client}->{row} or return;

	# Open the file if needed
	if ( $editor->{Document}->filename ne $file ) {
		$main->setup_editor($file);
		$editor = $main->current->editor;
		if ( $self->main->{breakpoints} ) {
			$self->main->{breakpoints}->on_refresh_click;
		}

		# we only want to do this if we are loading other files in this packages of ours
		$self->_bp_autoload();
	}

	$editor->goto_line_centerize( $row - 1 );

	#### TODO this was taken from the Padre::Wx::Syntax::start() and changed a bit.
	# They should be reunited soon !!!! (or not)

	$editor->MarkerDeleteAll(Padre::Constant::MARKER_LOCATION);
	$editor->MarkerAdd( $row - 1, Padre::Constant::MARKER_LOCATION );

	# update variables and output
	$self->_output_variables;

	return 1;
}

#######
# sub running
#######
sub running {
	my $self = shift;
	my $main = $self->main;

	unless ( $self->{client} ) {

		return;
	}

	return !!$self->current->editor;
}

#######
# sub debug_quit
#######
sub debug_quit {
	my $self = shift;
	my $main = $self->main;
	$self->running or return;

	# Clean up the GUI artifacts
	$self->current->editor->MarkerDeleteAll( Padre::Constant::MARKER_LOCATION() );

	# Detach the debugger
	$self->{client}->quit;
	delete $self->{client};

	$self->{trace_status} = 'Trace = off';
	$self->{trace}->SetValue(0);
	$self->{trace}->Disable;
	$self->{evaluate_expression}->Disable;
	$self->{expression}->Disable;
	$self->{stacktrace}->Disable;

	$self->{module_versions}->Disable;
	$self->{all_threads}->Disable;
	$self->{list_action}->Disable;
	$self->{dot}->Disable;
	$self->{view_around}->Disable;

	$self->{running_bp}->Disable;

	# $self->{add_watch}->Disable;
	# $self->{delete_watch}->Disable;
	$self->{raw}->Disable;
	$self->{watchpoints}->Disable;
	$self->{sub_names}->Disable;
	$self->{display_options}->Disable;

	$self->{step_in}->Hide;
	$self->{step_over}->Hide;
	$self->{step_out}->Hide;
	$self->{run_till}->Hide;
	$self->{display_value}->Hide;

	$self->{show_global_variables}->Disable;
	$self->{show_local_variables}->Disable;

	$self->{var_val}       = {};
	$self->{local_values}  = {};
	$self->{global_values} = {};
	$self->update_variables( $self->{var_val}, $self->{local_values}, $self->{global_values} );

	$self->{debug}->Show;

	# $self->show_debug_output(0);
	$main->show_debugoutput(0);
	return;
}

sub update_debug_user_interface {
	my $self = shift;
	my $output = shift;
	my $main = $self->main;

	my $module = $self->{client}->module || BLANK;
	$self->{client}->get_lineinfo;

	if ( $module eq '<TERMINATED>' ) {
		TRACE('TERMINATED') if DEBUG;
		$self->{trace_status} = 'Trace = off';
		$main->{debugoutput}->debug_status( $self->{trace_status} );
		$self->debug_quit;
		return;
	}

	if ( ! $output ) {
		#ToDo remove when Debug::Client 0.22 is released.
		if ( $self->{debug_client_version} eq '0.20' ) {
			$output = $self->{client}->buffer;
		} else {
			 $output = $self->{client}->get_buffer;
		}
	}
	$main->{debugoutput}->debug_output( $output );
	$self->_set_debugger;
}

#######
# Method debug_step_in
#######
sub debug_step_in {
	my $self = shift;

	my @list_request;
	eval { @list_request = $self->{client}->step_in(); };
	$self->update_debug_user_interface;

	return;
}

#######
# Method debug_step_over
#######
sub debug_step_over {
	my $self = shift;
	my $main = $self->main;

	my @list_request;
	eval { @list_request = $self->{client}->step_over(); };
	$self->update_debug_user_interface;

	return;
}

#######
# Method debug_step_out
#######
sub debug_step_out {
	my $self = shift;
	my $main = $self->main;

	my @list_request;
	eval { @list_request = $self->{client}->step_out(); };
	$self->update_debug_user_interface;

	return;
}

#######
# Method debug_run_till
#######
sub debug_run_till {
	my $self  = shift;
	my $param = shift;
	my $main  = $self->main;

	my @list_request;
	eval { @list_request = $self->{client}->run($param); };
	$self->update_debug_user_interface;

	return;
}

#######
# sub display_trace
# TODO this is yuck!
#######
sub _display_trace {
	my $self = shift;
	my $main = $self->main;

	$self->running or return;
	my $trace_on = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );

	if ( $trace_on == 1 && $self->{trace_status} eq 'Trace = on' ) {
		return;
	}

	if ( $trace_on == 1 && $self->{trace_status} eq 'Trace = off' ) {

		# $self->{trace_status} = $self->{client}->_set_option('frame=6');
		$self->{trace_status} = $self->{client}->toggle_trace();
		$main->{debugoutput}->debug_status( $self->{trace_status} );
		return;
	}

	if ( $trace_on == 0 && $self->{trace_status} eq 'Trace = off' ) {
		return;
	}

	if ( $trace_on == 0 && $self->{trace_status} eq 'Trace = on' ) {

		# $self->{trace_status} = $self->{client}->_set_option('frame=1');
		$self->{trace_status} = $self->{client}->toggle_trace();
		$main->{debugoutput}->debug_status( $self->{trace_status} );
		return;
	}

	return;
}


####### v1
#TODO Debug -> menu when in trunk
#######
sub debug_perl_show_value {
	my $self = shift;
	my $main = $self->main;
	$self->running or return;

	my $text = $self->_debug_get_variable or return;

	my $value = eval { $self->{client}->get_value($text) };
	if ($@) {
		$main->error( sprintf( Wx::gettext("Could not evaluate '%s'"), $text ) );
		return;
	}

	$self->main->message("$text = $value");

	return;
}

####### v1
# sub _debug_get_variable $line
#######
sub _debug_get_variable {
	my $self = shift;
	my $document = $self->current->document or return;

	my ( $location, $text ) = $document->get_current_symbol;

	if ( not $text or $text !~ m/^[\$@%\\]/smx ) {
		$self->main->error(
			sprintf(
				Wx::gettext(
					"'%s' does not look like a variable. First select a variable in the code and then try again."),
				$text
			)
		);
		return;
	}
	return $text;
}

####### v1
# Method display_value
#######
sub display_value {
	my $self = shift;
	$self->running or return;

	my $variable = $self->_debug_get_variable or return;

	$self->{var_val}{$variable} = BLANK;

	# $self->update_variables( $self->{var_val} );
	$self->_output_variables;

	return;
}

#######
# Method quit
#######
sub quit {
	my $self = shift;
	if ( $self->{client} ) {
		$self->debug_quit;
	}
	return;
}

#######
# Composed Method _output_variables
#######
sub _output_variables {
	my $self     = shift;
	my $document = $self->current->document;
	$self->{current_file} = $document->filename;

	foreach my $variable ( keys %{ $self->{var_val} } ) {
		my $value;
		eval { $value = $self->{client}->get_value($variable); };
		if ($@) {

			#ignore error
		} else {
			my $search_text = 'Use of uninitialized value';
			unless ( $value =~ m/$search_text/ ) {
				$self->{var_val}{$variable} = $value;
			}
		}
	}

	# only get local variables if required
	if ( $self->{local_variables} == 1 ) {
		$self->get_local_variables;
	}

	# Only enable global variables if we are debuging in a project
	# why dose $self->{project_dir} contain the root when no magic file present
	#TODO trying to stop debug X & V from crashing
	my @magic_files = qw { Makefile.PL Build.PL dist.ini };
	my $in_project  = 0;
	require File::Spec;
	foreach (@magic_files) {
		if ( -e File::Spec->catfile( $self->{project_dir}, $_ ) ) {
			$in_project = 1;
		}
	}
	if ($in_project) {

		$self->{show_global_variables}->Enable;

		if ( $self->{current_file} =~ m/pm$/ ) {
			$self->get_global_variables;

		} else {
			$self->{show_global_variables}->Disable;

			# get ride of stale values
			$self->{global_values} = {};
		}
	}

	$self->update_variables( $self->{var_val}, $self->{local_values}, $self->{global_values} );

	return;
}

#######
# Composed Method get_variables
#######
sub get_local_variables {
	my $self = shift;

	my $auto_values = $self->{client}->get_y_zero;

	$auto_values =~ s/^([\$\@\%]\w+)/:;$1/xmg;

	my @auto = split m/^:;/xm, $auto_values;

	#remove ghost at begining
	shift @auto;

	# This is better I think, it's quicker
	$self->{local_values} = {};

	foreach (@auto) {

		$_ =~ m/(.*) = (.*)/sm;

		if ( defined $1 ) {
			if ( defined $2 ) {
				$self->{local_values}->{$1} = $2;
			} else {
				$self->{local_values}->{$1} = BLANK;
			}
		}
	}

	return;
}

#######
# Composed Method get_variables
#######
sub get_global_variables {
	my $self = shift;

	my $var_regex   = '!(INC|ENV|SIG)';
	my $auto_values = $self->{client}->get_x_vars($var_regex);

	$auto_values =~ s/^((?:[\$\@\%]\w+)|(?:[\$\@\%]\S+)|(?:File\w+))/:;$1/xmg;

	my @auto = split m/^:;/xm, $auto_values;

	#remove ghost at begining
	shift @auto;

	# This is better I think, it's quicker
	$self->{global_values} = {};

	foreach (@auto) {

		$_ =~ m/(.*)(?: = | => )(.*)/sm;

		if ( defined $1 ) {
			if ( defined $2 ) {
				$self->{global_values}->{$1} = $2;
			} else {
				$self->{global_values}->{$1} = BLANK;
			}
		}
	}

	return;
}

#######
# Internal method _setup_db connector
#######
sub _setup_db {
	my $self = shift;

	# set padre db relation
	$self->{debug_breakpoints} = ('Padre::DB::DebugBreakpoints');

	return;
}

#######
# Internal Method _get_bp_db
# display relation db
#######
sub _get_bp_db {
	my $self     = shift;
	my $editor   = $self->current->editor;
	my $document = $self->current->document;

	$self->_setup_db();

	$self->{project_dir}  = $document->project_dir;
	$self->{current_file} = $document->filename;

	TRACE("current file from _get_bp_db: $self->{current_file}") if DEBUG;

	my $sql_select = 'ORDER BY filename ASC, line_number ASC';
	my @tuples     = $self->{debug_breakpoints}->select($sql_select);

	for ( 0 .. $#tuples ) {

		# if ( $tuples[$_][1] =~ m/^$self->{current_file}$/ ) {
		if ( $tuples[$_][1] eq $self->{current_file} ) {

			if ( $self->{client}->set_breakpoint( $tuples[$_][1], $tuples[$_][2] ) == 1 ) {
				$editor->MarkerAdd( $tuples[$_][2] - 1, Padre::Constant::MARKER_BREAKPOINT() );
			} else {
				$editor->MarkerAdd( $tuples[$_][2] - 1, Padre::Constant::MARKER_NOT_BREAKABLE() );

				#wright $tuples[$_][3] = 0
				Padre::DB->do( 'update debug_breakpoints SET active = ? WHERE id = ?', {}, 0, $tuples[$_][0], );
			}

		}

	}

	#TODO tidy up
	# no more bleading BP's
	for ( 0 .. $#tuples ) {

		if ( $tuples[$_][1] =~ m/^$self->{project_dir}/ ) {
			if ( $tuples[$_][1] ne $self->{current_file} ) {
				if ( $self->{client}->__send("f $tuples[$_][1]") !~ m/^No file matching/ ) {
					unless ( $self->{client}->set_breakpoint( $tuples[$_][1], $tuples[$_][2] ) ) {
						Padre::DB->do( 'update debug_breakpoints SET active = ? WHERE id = ?', {}, 0, $tuples[$_][0], );
					}
				}
			}
		}
	}
	if ( $self->main->{breakpoints} ) {
		$self->main->{breakpoints}->on_refresh_click();
	}

	#let's do some boot n braces
	$self->{client}->__send("f $self->{current_file}");
	return;
}

#######
# Composed Method, _bp_autoload
# for an autoloaded file (current) display breakpoints in editor if any
#######
sub _bp_autoload {
	my $self     = shift;
	my $current  = $self->current;
	my $editor   = $current->editor;
	my $document = $current->document;

	$self->_setup_db;

	#TODO is there a better way
	$self->{current_file} = $document->filename;
	my $sql_select = "WHERE filename = ?";
	my @tuples = $self->{debug_breakpoints}->select( $sql_select, $self->{current_file} );

	for ( 0 .. $#tuples ) {

		TRACE("show breakpoints autoload: self->{client}->set_breakpoint: $tuples[$_][1] => $tuples[$_][2]") if DEBUG;

		# autoload of breakpoints and mark file
		if ( $self->{client}->set_breakpoint( $tuples[$_][1], $tuples[$_][2] ) == 1 ) {
			$editor->MarkerAdd( $tuples[$_][2] - 1, Padre::Constant::MARKER_BREAKPOINT() );
		} else {
			$editor->MarkerAdd( $tuples[$_][2] - 1, Padre::Constant::MARKER_NOT_BREAKABLE() );

			#wright $tuples[$_][3] = 0
			Padre::DB->do( 'update debug_breakpoints SET active = ? WHERE id = ?', {}, 0, $tuples[$_][0], );
			if ( $self->main->{breakpoints} ) {
				$self->main->{breakpoints}->on_refresh_click();
			}
		}

	}

	return;
}

#######
# Event Handler _on_list_item_selected
# equivalent to p|x the varaible
#######
sub _on_list_item_selected {
	my $self          = shift;
	my $event         = shift;
	my $main          = $self->main;
	my $index         = $event->GetIndex + 1;
	my $variable_name = $event->GetText;

	#ToDo Changed to use current internal hashes instead of asking perl5db for value, this also gets around a bug with 'File::HomeDir has tied variables' clobbering x @rray giving an empty array
	my $variable_value;
	my $black_size = keys %{ $self->{var_val} };
	my $blue_size  = keys %{ $self->{local_values} };

	given ($index) {
		when ( $_ <= $black_size ) {
			$variable_value = $self->{var_val}->{$variable_name};
			chomp $variable_value;
			$main->{debugoutput}->debug_output_black( $variable_name . ' = ' . $variable_value );
		}
		when ( $_ <= ( $black_size + $blue_size ) ) {
			$variable_value = $self->{local_values}->{$variable_name};
			chomp $variable_value;
			$main->{debugoutput}->debug_output_blue( $variable_name . ' = ' . $variable_value );
		}
		default {
			$variable_value = $self->{global_values}->{$variable_name};
			chomp $variable_value;
			$main->{debugoutput}->debug_output_dark_gray( $variable_name . ' = ' . $variable_value );
		}
	}

	return;
}


###############################################
# event handler top row
#######
# sub on_debug_clicked
#######
sub on_debug_clicked {
	my $self = shift;

	$self->debug_perl;
	$self->update_debugger_buttons_on;
}

#######
# sub update_debugger_buttons_on
#######
sub update_debugger_buttons_on {
	my $self    = shift;
	my $arg_ref = shift;

	my $main = $self->main;

	return unless $self->{client};

	$self->{quit_debugger}->Enable;

	# $self->show_debug_output(1);
	$main->show_debugoutput(1);
	$self->{step_in}->Show;
	$self->{step_over}->Show;
	$self->{step_out}->Show;
	$self->{run_till}->Show;
	$self->{display_value}->Show;

	$self->{show_local_variables}->Enable;

	$self->{trace}->Enable;
	$self->{evaluate_expression}->Enable;
	$self->{expression}->Enable;
	$self->{stacktrace}->Enable;

	$self->{module_versions}->Enable;
	$self->{all_threads}->Enable;
	$self->{list_action}->Enable;
	$self->{dot}->Enable;
	$self->{view_around}->Enable;

	$self->{running_bp}->Enable;

	# $self->{add_watch}->Enable;
	# $self->{delete_watch}->Enable;
	$self->{raw}->Enable;
	$self->{watchpoints}->Enable;
	$self->{sub_names}->Enable;
	$self->{display_options}->Enable;

	$self->{debug}->Hide;
	$main->aui->Update;
	if ( $main->{debugoutput} ) {
		$main->{debugoutput}->debug_output( $self->{client}->get_h_var('h') );
		if ($arg_ref) {
			$main->{debugoutput}->debug_launch_options('To see all Debug Launch Parameters see menu');
		}
	}

	#let's reload our breakpoints
	# $self->_get_bp_db();
	$self->{set_bp} = 0;

	return;
}
#######
# sub step_in_clicked
#######
sub on_step_in_clicked {
	my $self = shift;

	TRACE('step_in_clicked') if DEBUG;
	$self->debug_step_in();

	return;
}
#######
# sub step_over_clicked
#######
sub on_step_over_clicked {
	my $self = shift;

	TRACE('step_over_clicked') if DEBUG;
	$self->debug_step_over();

	return;
}
#######
# sub step_out_clicked
#######
sub on_step_out_clicked {
	my $self = shift;

	TRACE('step_out_clicked') if DEBUG;
	$self->debug_step_out();

	return;
}
#######
# sub run_till_clicked
#######
sub on_run_till_clicked {
	my $self = shift;

	TRACE('run_till_clicked') if DEBUG;
	$self->debug_run_till();

	return;
}
#######
# sub display_value
#######
sub on_display_value_clicked {
	my $self = shift;

	TRACE('display_value') if DEBUG;
	$self->display_value();

	return;
}
#######
# sub quit_debugger_clicked
#######
sub on_quit_debugger_clicked {
	my $self = shift;
	my $main = $self->main;

	TRACE('quit_debugger_clicked') if DEBUG;
	$self->debug_quit;

	$main->show_debugoutput(0);

	return;
}


###############################################
# show
#######
# event on_show_local_variables_checked
#######
sub on_show_local_variables_checked {
	my ( $self, $event ) = @_;

	if ( $event->IsChecked ) {
		$self->{local_variables} = 1;
	} else {
		$self->{local_variables} = 0;
	}
	$self->_output_variables;
	return;
}
#######
# event on_show_global_variables_checked
#######
sub on_show_global_variables_checked {
	my ( $self, $event ) = @_;

	if ( $event->IsChecked ) {
		$self->{global_variables} = 1;
	} else {
		$self->{global_variables} = 0;
	}
	$self->_output_variables;
	return;
}


#################################################
# Output Options
#######
# sub trace_clicked
#######
sub on_trace_checked {
	my ( $self, $event ) = @_;

	if ( $event->IsChecked ) {
		$self->_display_trace(1);
	} else {
		$self->_display_trace(0);
	}

	return;
}
#######
# Event on_dot_clicked .
#######
sub on_dot_clicked {
	my $self = shift;
	my $main = $self->main;

	$main->{debugoutput}->debug_output( $self->{client}->show_line() );

	#reset editor to dot location
	$self->_set_debugger;

	return;
}
#######
# Event on_view_around_clicked v
#######
sub on_view_around_clicked {
	my $self = shift;
	my $main = $self->main;

	$main->{debugoutput}->debug_output( $self->{client}->show_view() );

	return;
}
#######
# Event handler on_list_action_clicked L
#######
sub on_list_action_clicked {
	my $self = shift;
	my $main = $self->main;

	$main->{debugoutput}->debug_output( $self->{client}->show_breakpoints() );

	return;
}

#######
# Event handler on_running_bp_set_clicked b|B
#######
sub on_running_bp_clicked {
	my $bp_action_ref = Padre::Breakpoints->set_breakpoints_clicked;

	return;
}
sub update_debugger_breakpoint {
	my $self     = shift;
	my $bp_action_ref = shift;
	my $main     = $self->main;
	my $editor   = $self->current->editor;
	my $document = $self->current->document;
	$self->{current_file} = $document->filename;
	
	if ( $self->{client} ) {
		if ( $bp_action_ref->{action} eq 'add' ) {
			my $result = $self->{client}->set_breakpoint( $self->{current_file}, $bp_action_ref->{line} );
			if ( $result == 0 ) {

				# print "not breakable\n";
				$editor->MarkerAdd( $bp_action_ref->{line} - 1, Padre::Constant::MARKER_NOT_BREAKABLE() );
				$self->_setup_db;
				Padre::DB->do(
					'update debug_breakpoints SET active = ? WHERE filename = ? AND line_number = ?', {}, 0,
					$self->{current_file}, $bp_action_ref->{line},
				);
				if ( $self->main->{breakpoints} ) {
					$self->main->{breakpoints}->on_refresh_click();
				}

			}
		}
		if ( $bp_action_ref->{action} eq 'delete' ) {
			$self->{client}->remove_breakpoint( $self->{current_file}, $bp_action_ref->{line} );
		}
		$main->{debugoutput}->debug_output( $self->{client}->__send('L b') );
	}

	return;
}
#######
# Event handler on_module_versions_clicked M
#######
sub on_module_versions_clicked {
	my $self = shift;
	my $main = $self->main;

	$main->{debugoutput}->debug_output( $self->{client}->__send('M') );

	return;
}
#######
# Event handler on_stacktrace_clicked T
#######
sub on_stacktrace_clicked {
	my $self = shift;
	my $main = $self->main;

	$main->{debugoutput}->debug_output( $self->{client}->get_stack_trace );

	return;
}
#######
# Event handler on_all_threads_clicked E
#######
sub on_all_threads_clicked {
	my $self = shift;
	my $main = $self->main;

	$main->{debugoutput}->debug_output( $self->{client}->__send_np('E') );

	return;
}
#######
# Event handler on_display_options_clicked o
#######
sub on_display_options_clicked {
	my $self = shift;
	my $main = $self->main;

	$main->{debugoutput}->debug_output( $self->{client}->get_options );

	return;
}


#######
# Event handler on_evaluate_expression_clicked p|x
#######
sub on_evaluate_expression_clicked {
	my $self = shift;
	my $main = $self->main;

	if ( $self->{client}->get_stack_trace =~ /ANON/ ) {
		$main->{debugoutput}->debug_output(
			' You appear to be inside an __ANON__, suggest you use "Show Local Variables" to view contents');
		return;
	}

	if ( $self->{expression}->GetValue() eq "" ) {
		$main->{debugoutput}->debug_output( '$_ = ' . $self->{client}->get_value );
	} else {
		$main->{debugoutput}->debug_output(
			$self->{expression}->GetValue . " = " . $self->{client}->get_value( $self->{expression}->GetValue ) );
	}

	return;
}
#######
# Event handler on_sub_names_clicked S
#######
sub on_sub_names_clicked {
	my $self = shift;
	my $main = $self->main;

	$main->{debugoutput}->debug_output( $self->{client}->list_subroutine_names( $self->{expression}->GetValue ) );

	return;
}
#######
# Event handler on_watchpoints_clicked w|W
#######
sub on_watchpoints_clicked {
	my $self = shift;
	my $main = $self->main;

	if ( $self->{expression}->GetValue ne "" ) {
		if ( $self->{expression}->GetValue eq "*" ) {
			$main->{debugoutput}->debug_output( $self->{client}->__send( 'W ' . $self->{expression}->GetValue ) );

			return;
		}

		# this is nasty, there must be a better way
		my $exp = "\\" . $self->{expression}->GetValue;

		if ( $self->{client}->__send('L w') =~ m/$exp/gm ) {
			my $del_watch = $self->{client}->__send( 'W ' . $self->{expression}->GetValue );
			if ($del_watch) {
				$main->{debugoutput}->debug_output($del_watch);
			} else {
				$main->{debugoutput}->debug_output( $self->{client}->__send('L w') );
			}

			return;
		} else {

			$self->{client}->__send( 'w ' . $self->{expression}->GetValue );
			$main->{debugoutput}->debug_output( $self->{client}->__send('L w') );

			return;
		}
	} else {
		$main->{debugoutput}->debug_output( $self->{client}->__send('L w') );
	}

	return;
}

#######
# Event handler on_raw_clicked raw
#######
sub on_raw_clicked {
	my $self = shift;
	my $main = $self->main;

	my $output;
	if ( $self->{expression}->GetValue =~ m/^h.?(\w*)/s ) {
		$output = $self->{client}->get_h_var($1) ;
	} else {

		$output = $self->{client}->__send_np( $self->{expression}->GetValue );
	}
	$self->update_debug_user_interface($output);

	return;
}

#######
# Event handler on_stacktrace_clicked i
#######
# sub on_nested_parents_clicked {
# my $self = shift;
# my $main = $self->main;

# # 	$main->{debugoutput}->debug_output( $self->{client}->__send('i') );

# # 	return;
# }
#######
# Event handler on_running_bp_delete_clicked B
#######
# sub on_running_bp_delete_clicked {
# my $self = shift;

# # 	return;
# }
#######
# Event handler on_add_watch_clicked w
#######
# sub on_add_watch_clicked {
# my $self = shift;
# my $main = $self->main;

# # 	if ( $self->{expression}->GetValue() ne "" ) {

# # 		$main->{debugoutput}->debug_output( $self->{client}->__send( 'w ' . $self->{expression}->GetValue() ) );
# }

# # 	#reset expression
# $self->expression->SetValue(BLANK);
# return;
# }
#######
# Event handler on_delete_watch_clicked W
#######
# sub on_delete_watch_clicked {
# my $self = shift;
# my $main = $self->main;

# # 	if ( $self->{expression}->GetValue() ne "" ) {

# # 		$main->{debugoutput}->debug_output( $self->{client}->__send( 'W ' . $self->{expression}->GetValue() ) );
# }

# # 	#reset expression
# $self->expression->SetValue(BLANK);
# return;
# }

#######
# Event handler on_launch_options - launch the debugger over-riding its auto-choices
#######
sub on_launch_options {
	my $self     = shift;
	my $main     = $self->main;
	my $current  = $self->current;
	my $document = $current->document;
	my $editor   = $current->editor;

	my $filename;
	if ( defined $document->{file} ) {
		$filename = $document->{file}->filename;
	}

	# TODO: improve the message displayed to the user
	# If the document is not saved, simply return for now
	return unless $filename;

	my ( $cmd, $arg_ref ) = $document->get_command( { debug => 1 } );

	require Padre::Wx::Dialog::DebugOptions;
	my $dialog = Padre::Wx::Dialog::DebugOptions->new(
		$main,
	);

	$dialog->perl_interpreter->SetValue( $arg_ref->{perl} );
	$dialog->perl_args->SetValue( $arg_ref->{perl_args} );
	$dialog->find_script->SetValue( $arg_ref->{script} );
	$dialog->run_directory->SetValue( $arg_ref->{run_directory} );
	$dialog->script_options->SetValue( $arg_ref->{script_args} );

	$dialog->find_script->SetFocus;

	if ( $dialog->ShowModal == Wx::ID_CANCEL ) {
		return;
	}
	$arg_ref->{perl}          = $dialog->perl_interpreter->GetValue();
	$arg_ref->{perl_args}     = $dialog->perl_args->GetValue();
	$arg_ref->{script}        = $dialog->find_script->GetValue();
	$arg_ref->{run_directory} = $dialog->run_directory->GetValue();
	$arg_ref->{script_args}   = $dialog->script_options->GetValue();
	$dialog->Destroy;

	#save history for next time (when we might just hit run!
	{
		my $history = $main->lock( 'DB', 'refresh_recent' );

		#save which script the user selected to run for this document
		Padre::DB::History->create(
			type => "run_script_" . File::Basename::fileparse($filename),
			name => $arg_ref->{script},
		);
		my $script_base = File::Basename::fileparse( $arg_ref->{script} );

		Padre::DB::History->create(
			type => 'run_directory_' . $script_base,
			name => $arg_ref->{run_directory},
		);
		Padre::DB::History->create(
			type => "run_script_args_" . $script_base,
			name => $arg_ref->{script_args},
		);
		Padre::DB::History->create(
			type => "run_perl_" . $script_base,
			name => $arg_ref->{perl},
		);
		Padre::DB::History->create(
			type => "run_perl_args_" . $script_base,
			name => $arg_ref->{perl_args},
		);
	}

	#now run the debugger with the new command
	$self->debug_perl($arg_ref);

	# p $arg_ref;
	$self->update_debugger_buttons_on($arg_ref);

	return;
}


1;

__END__

=pod

=head1 NAME

Padre::Plugin::Debug::Panel::Debugger - Interface to the Perl debugger.

=head1 DESCRIPTION

Padre::Wx::Debugger provides a wrapper for the generalised L<Debug::Client>.

It should really live at Padre::Debugger, but does not currently have
sufficient abstraction from L<Wx>.

=head1 METHODS

=head2 new

Simple constructor.

=head2 debug_perl

  $main->debug_perl;

Run current document under Perl debugger. An error is reported if
current is not a Perl document.

Returns true if debugger successfully started.

=cut

# Copyright 2008-2013 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
