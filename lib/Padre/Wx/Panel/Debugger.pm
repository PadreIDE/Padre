package Padre::Wx::Panel::Debugger;

use 5.008;
use strict;
use warnings;

use utf8;
use Padre::Util              ();
use Padre::Constant          ();
use Padre::Wx                ();
use Padre::Wx::Util          ();
use Padre::Wx::Icon          ();
use Padre::Wx::Role::View    ();
use Padre::Wx::FBP::Debugger ();
use Padre::Logger;
use Debug::Client 0.16 ();

our $VERSION = '0.94';
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

	$self->{client}           = undef;
	$self->{file}             = undef;
	$self->{save}             = {};
	$self->{trace_status}     = 'Trace = off';
	$self->{var_val}          = {};
	$self->{auto_var_val}     = {};
	$self->{auto_x_var}       = {};
	$self->{set_bp}           = 0;
	$self->{fudge}            = 0;
	$self->{local_variables}  = 0;
	$self->{global_variables} = 0;

	#turn off unless in project
	$self->{show_global_variables}->Disable;

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
	my $self             = shift;
	my $var_val_ref      = shift;
	my $auto_var_val_ref = shift;
	my $auto_x_var_ref   = shift;
	my $editor           = $self->current->editor;

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
		foreach my $var ( keys %{$auto_var_val_ref} ) {

			$item->SetId($index);
			$self->{variables}->InsertItem($item);
			$self->{variables}->SetItemTextColour( $index, BLUE );

			$self->{variables}->SetItem( $index,   0, $var );
			$self->{variables}->SetItem( $index++, 1, $auto_var_val_ref->{$var} );
		}
	}
	if ( $self->{global_variables} == 1 ) {
		foreach my $var ( keys %{$auto_x_var_ref} ) {

			$item->SetId($index);
			$self->{variables}->InsertItem($item);
			$self->{variables}->SetItemTextColour( $index, DARK_GRAY );

			$self->{variables}->SetItem( $index,   0, $var );
			$self->{variables}->SetItem( $index++, 1, $auto_x_var_ref->{$var} );
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
	my $self     = shift;
	my $main     = $self->main;
	my $current  = $self->current;
	my $document = $current->document;
	my $editor   = $current->editor;

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
	my $filename = defined( $document->{file} ) ? $document->{file}->filename : undef;

	# TODO: improve the message displayed to the user
	# If the document is not saved, simply return for now
	return unless $filename;

	#TODO how do we add debug options at startup such as threaded mode

	# Set up the debugger
	my $host = 'localhost';
	my $port = 24642 + int rand(1000); # TODO make this configurable?
	SCOPE: {
		local $ENV{PERLDB_OPTS} = "RemotePort=$host:$port";
		$main->run_command( $document->get_command( { debug => 1 } ) );
	}

	# Bootstrap the debugger
	# require Debug::Client;
	$self->{client} = Debug::Client->new(
		host => $host,
		port => $port,
	);
	$self->{client}->listener;

	$self->{file} = $filename;

	#Todo list request Ouch
	my ( $module, $file, $row, $content ) = $self->{client}->get;

	my $save = ( $self->{save}->{$filename} ||= {} );

	if ( $self->{set_bp} == 0 ) {

		# get bp's from db
		$self->_get_bp_db();
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

		# we only want to do this if we are loading other packages of ours
		# $self->_bp_autoload();
	}

	$editor->goto_line_centerize( $row - 1 );

	#### TODO this was taken from the Padre::Wx::Syntax::start() and  changed a bit.
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

	$self->{var_val}      = {};
	$self->{auto_var_val} = {};
	$self->{auto_x_var}   = {};
	$self->update_variables( $self->{var_val}, $self->{auto_var_val}, $self->{auto_x_var} );

	$self->{debug}->Show;

	# $self->show_debug_output(0);
	$main->show_debugoutput(0);
	return;
}

#######
# Method debug_step_in
#######
sub debug_step_in {
	my $self = shift;
	my $main = $self->main;

	#ToDo list request ouch
	my ( $module, $file, $row, $content ) = $self->{client}->step_in;
	if ( $module eq '<TERMINATED>' ) {
		TRACE('TERMINATED') if DEBUG;
		$self->{trace_status} = 'Trace = off';
		$main->{debugoutput}->debug_status( $self->{trace_status} );
		$self->debug_quit;
		return;
	}

	$main->{debugoutput}->debug_output( $self->{client}->buffer );
	$self->_set_debugger;

	return;
}

#######
# Method debug_step_over
#######
sub debug_step_over {
	my $self = shift;
	my $main = $self->main;

	#ToDo list request ouch
	my ( $module, $file, $row, $content ) = $self->{client}->step_over;
	if ( $module eq '<TERMINATED>' ) {
		TRACE('TERMINATED') if DEBUG;
		$self->{trace_status} = 'Trace = off';
		$main->{debugoutput}->debug_status( $self->{trace_status} );

		$self->debug_quit;
		return;
	}

	$main->{debugoutput}->debug_output( $self->{client}->buffer );
	$self->_set_debugger;

	return;
}

#######
# Method debug_step_out
#######
sub debug_step_out {
	my $self = shift;
	my $main = $self->main;

	#ToDo list request ouch
	my ( $module, $file, $row, $content ) = $self->{client}->step_out;
	if ( $module eq '<TERMINATED>' ) {
		TRACE('TERMINATED') if DEBUG;
		$self->{trace_status} = 'Trace = off';
		$main->{debugoutput}->debug_status( $self->{trace_status} );

		$self->debug_quit;
		return;
	}

	$main->{debugoutput}->debug_output( $self->{client}->buffer );
	$self->_set_debugger;

	return;
}

#######
# Method debug_run_till
#######
sub debug_run_till {
	my $self  = shift;
	my $param = shift;
	my $main  = $self->main;

	#ToDo list request ouch
	my ( $module, $file, $row, $content ) = $self->{client}->run($param);
	if ( $module eq '<TERMINATED>' ) {
		TRACE('TERMINATED') if DEBUG;
		$self->{trace_status} = 'Trace = off';
		$main->{debugoutput}->debug_status( $self->{trace_status} );
		$self->debug_quit;
		return;
	}

	$main->{debugoutput}->debug_output( $self->{client}->buffer );
	$self->_set_debugger;

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
	$self->update_variables( $self->{var_val} );

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
		$self->get_local_variables();
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
			$self->get_global_variables();

		} else {
			$self->{show_global_variables}->Disable;

			# get ride of stale values
			$self->{auto_x_var} = {};
		}
	}

	$self->update_variables( $self->{var_val}, $self->{auto_var_val}, $self->{auto_x_var} );

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
	$self->{auto_var_val} = {};

	foreach (@auto) {

		$_ =~ m/(.*) = (.*)/sm;

		if ( defined $1 ) {
			if ( defined $2 ) {
				$self->{auto_var_val}->{$1} = $2;
			} else {
				$self->{auto_var_val}->{$1} = BLANK;
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
	$self->{auto_x_var} = {};

	foreach (@auto) {

		$_ =~ m/(.*)(?: = | => )(.*)/sm;

		if ( defined $1 ) {
			if ( defined $2 ) {
				$self->{auto_x_var}->{$1} = $2;
			} else {
				$self->{auto_x_var}->{$1} = BLANK;
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
			if ( $self->{client}->set_breakpoint( $tuples[$_][1], $tuples[$_][2] ) ) {
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

	my $sql_select = "WHERE filename = \"$self->{current_file}\"";
	my @tuples     = $self->{debug_breakpoints}->select($sql_select);

	for ( 0 .. $#tuples ) {

		TRACE("show breakpoints autoload: self->{client}->set_breakpoint: $tuples[$_][1] => $tuples[$_][2]") if DEBUG;

		# autoload of breakpoints and mark file
		if ( $self->{client}->set_breakpoint( $tuples[$_][1], $tuples[$_][2] ) ) {
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

###############################################
# event handler top row
#######
# sub on_debug_clicked
#######
sub on_debug_clicked {
	my $self = shift;
	my $main = $self->main;

	$self->{quit_debugger}->Enable;

	# $self->show_debug_output(1);
	$main->show_debugoutput(1);
	$self->{step_in}->Show;
	$self->{step_over}->Show;
	$self->{step_out}->Show;
	$self->{run_till}->Show;
	$self->{display_value}->Show;

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
	$self->debug_perl;
	$main->aui->Update;
	if ( $main->{debugoutput} ) {
		$main->{debugoutput}->debug_output( $self->{client}->get_h_var('h') );
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
	my $self     = shift;
	my $main     = $self->main;
	my $editor   = $self->current->editor;
	my $document = $self->current->document;
	$self->{current_file} = $document->filename;

	my $bp_action_ref;
	if ( $self->main->{breakpoints} ) {
		$bp_action_ref = $self->main->{breakpoints}->on_set_breakpoints_clicked();
	} else {
		require Padre::Breakpoints;
		$bp_action_ref = Padre::Breakpoints->set_breakpoints_clicked();
	}

	my %bp_action = %{$bp_action_ref};

	if ( $bp_action{action} eq 'add' ) {
		my $result = $self->{client}->set_breakpoint( $self->{current_file}, $bp_action{line} );
		if ( $result == 0 ) {

			# print "not breakable\n";
			$editor->MarkerAdd( $bp_action{line} - 1, Padre::Constant::MARKER_NOT_BREAKABLE() );
			$self->_setup_db;
			Padre::DB->do(
				'update debug_breakpoints SET active = ? WHERE filename = ? AND line_number = ?', {}, 0,
				$self->{current_file}, $bp_action{line},
			);
			if ( $self->main->{breakpoints} ) {
				$self->main->{breakpoints}->on_refresh_click();
			}

		}
	}
	if ( $bp_action{action} eq 'delete' ) {
		$self->{client}->remove_breakpoint( $self->{current_file}, $bp_action{line} );
	}

	$main->{debugoutput}->debug_output( $self->{client}->__send('L b') );
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

	$main->{debugoutput}->debug_output( $self->{client}->get_stack_trace() );

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

	$main->{debugoutput}->debug_output( $self->{client}->get_options() );

	return;
}


#######
# Event handler on_evaluate_expression_clicked p|x
#######
sub on_evaluate_expression_clicked {
	my $self = shift;
	my $main = $self->main;

	if ( $self->{expression}->GetValue() eq "" ) {
		$main->{debugoutput}->debug_output( '$_ = ' . $self->{client}->get_value() );
	} else {
		$main->{debugoutput}->debug_output(
			$self->{expression}->GetValue() . " = " . $self->{client}->get_value( $self->{expression}->GetValue() ) );
	}

	return;
}
#######
# Event handler on_sub_names_clicked S
#######
sub on_sub_names_clicked {
	my $self = shift;
	my $main = $self->main;

	$main->{debugoutput}->debug_output( $self->{client}->list_subroutine_names( $self->{expression}->GetValue() ) );

	return;
}
#######
# Event handler on_watchpoints_clicked w|W
#######
sub on_watchpoints_clicked {
	my $self = shift;
	my $main = $self->main;

	if ( $self->{expression}->GetValue() ne "" ) {
		if ( $self->{expression}->GetValue() eq "*" ) {
			$main->{debugoutput}->debug_output( $self->{client}->__send( 'W ' . $self->{expression}->GetValue() ) );

			return;
		}

		# this is nasty, there must be a better way
		my $exp = "\\" . $self->{expression}->GetValue();

		if ( $self->{client}->__send('L w') =~ m/$exp/gm ) {
			my $del_watch = $self->{client}->__send( 'W ' . $self->{expression}->GetValue() );
			if ($del_watch) {
				$main->{debugoutput}->debug_output($del_watch);
			} else {
				$main->{debugoutput}->debug_output( $self->{client}->__send('L w') );
			}

			return;
		} else {

			$self->{client}->__send( 'w ' . $self->{expression}->GetValue() );
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

	if ( $self->{expression}->GetValue() =~ m/^h.?(\w*)/s ) {
		$main->{debugoutput}->debug_output( $self->{client}->get_h_var($1) );
	} else {

		$main->{debugoutput}->debug_output( $self->{client}->__send_np( $self->{expression}->GetValue() ) );
	}

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

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
