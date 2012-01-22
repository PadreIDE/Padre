package Padre;

# See POD at end for documentation

use 5.008005;
use strict;
use warnings;
use utf8;

# Non-Padre modules we need in order to do the single-instance
# check should be loaded early to simplify the load order.
use Carp          ();
use Cwd           ();
use File::Spec    ();
use File::HomeDir ();
use Scalar::Util  ();
use List::Util    ();
use YAML::Tiny    ();
use DBI           ();
use DBD::SQLite   ();

# load this before things are messed up to produce versions like '0,76'!
# TO DO: Bug report dispatched. Likely to be fixed in 0.77.
use version ();

our $VERSION    = '0.94';
our $COMPATIBLE = '0.81';

# Since everything is used OO-style, we will be require'ing
# everything other than the bare essentials
use Padre::Constant ();
use Padre::Config   ();
use Padre::DB       ();
use Padre::Logger;

# Generate faster accessors
use Class::XSAccessor 1.05 {
	getters => {
		original_cwd    => 'original_cwd',
		opts            => 'opts',
		config          => 'config',
		task_manager    => 'task_manager',
		plugin_manager  => 'plugin_manager',
		project_manager => 'project_manager',
	},
	accessors => {
		actions     => 'actions',
		shortcuts   => 'shortcuts',
		instance_id => 'instance_id',
	},
};

sub import {
	unless ( $_[1] and $_[1] eq ':everything' ) {
		return;
	}

	# Find the location of Padre.pm
	my $padre = $INC{'Padre.pm'};
	my $parent = substr( $padre, 0, -3 );

	# Find everything under Padre:: with a matching version,
	# which almost certainly means it is part of the main Padre release.
	require File::Find::Rule;
	require Padre::Util;
	my @children = grep { not $INC{$_} }
		map {"Padre/$_->[0]"}
		grep { defined( $_->[1] ) and $_->[1] eq $VERSION }
		map { [ $_, Padre::Util::parse_variable( File::Spec->catfile( $parent, $_ ) ) ] }
		File::Find::Rule->name('*.pm')->file->relative->in($parent);

	# Load all of them (ignoring errors)
	my $loaded = 0;
	my %skip = map { $_ => 1 } qw{
		Padre/CPAN.pm
		Padre/Test.pm
	};
	if (Padre::Constant::WIN32) {
		$skip{'Padre/Util/Win32.pm'} = 1;
	}
	foreach my $child (@children) {

		# Evil modules we should avoid
		next if $skip{$child};

		# We are not permitted to tread in plugin territory
		next if $child =~ /^Padre\/Plugin\//;

		eval { require $child; };
		next if $@;
		$loaded++;
	}

	return $loaded;
}

my $SINGLETON = undef;

# Access to the Singleton post-construction
sub ide {
	$SINGLETON or Carp::croak('Padre->new has not been called yet');
}

# The order of initialisation here is VERY important
sub new {
	Carp::croak('Padre->new already called. Use Padre->ide') if $SINGLETON;
	my $class = shift;
	my %opts  = @_;

	# Create the empty object
	my $self = $SINGLETON = bless {

		# Parsed command-line options
		opts => \%opts,

		# Wx Attributes
		wx => undef,

		# Project Storage
		project_manager => undef,

		# Plugin Storage
		plugin_manager => undef,

	}, $class;

	# Create our instance ID:
	for ( 1 .. 64 ) {
		$self->{instance_id} .= chr( ( 48 .. 57, 65 .. 90, 97 .. 122 )[ int( rand(62) ) ] );
	}

	# Save the start-up dir before anyone can move us.
	$self->{original_cwd} = Cwd::cwd();

	# Set up a raw (non-Padre::Locker) transaction around the rest of the constructor.
	Padre::DB->begin;

	# Load (and sync if needed) the configuration
	$self->{config} = Padre::Config->read;

	# Initialise our registries
	$self->actions(   {} );
	$self->shortcuts( {} );

	# Create the project manager
	require Padre::ProjectManager;
	$self->{project_manager} = Padre::ProjectManager->new;

	# Create the plugin manager
	require Padre::PluginManager;
	$self->{plugin_manager} = Padre::PluginManager->new($self);

	# Create the main window
	require Padre::Wx::App;
	my $wx = Padre::Wx::App->create($self);

	# Create the task manager
	require Padre::TaskManager;
	$self->{task_manager} = Padre::TaskManager->new(
		threads => 1,
		maximum => $self->config->threads_maximum,
		conduit => $wx->conduit,
	);

	# Startup completed, let go of the database
	Padre::DB->commit;

	return $self;
}

sub wx {
	no warnings 'once';
	$Wx::wxTheApp;
}

sub run {
	my $self = shift;

	# If we are on Windows, disable Win32::SetChildShowWindow so that
	# calls to system() or qx() won't spawn visible command line windows.
	if (Padre::Constant::WIN32) {
		require Win32;
		Win32::SetChildShowWindow( Win32::SW_HIDE() );
	}

	# Allow scripts to detect that they are being executed within Padre
	local $ENV{PADRE_VERSION} = $VERSION;

	TRACE("Padre->run was called version $VERSION") if DEBUG;

	# Make WxWidgets translate the default buttons
	local $ENV{LANGUAGE} =
		Padre::Constant::UNIX
		? $self->config->locale
		: $ENV{LANGUAGE};

	# Clean arguments (with a bad patch for saving URLs)
	# Windows has trouble deleting the work directory of a process,
	# so reset file to full path
	if (Padre::Constant::WIN32) {
		$self->{ARGV} = [
			map {
				if (/\:/) { $_; }
				else {
					File::Spec->rel2abs( $_, $self->{original_cwd} );
				}
				} @ARGV
		];
	} else {
		$self->{ARGV} = \@ARGV;
	}

	# FIX ME: RT #1 This call should be delayed until after the
	# window was opened but my Wx skills do not exist. --Steffen
	SCOPE: {

		# Lock rendering and the database while the plugins are loading
		# to prevent them doing anything weird or slow.
		my $lock = $self->wx->main->lock('DB');
		$self->plugin_manager->load_plugins;
	}

	TRACE("Plugins loaded") if DEBUG;

	# Move our current dir to the user's documents directory by default
	if (Padre::Constant::WIN32) {

		# Windows has trouble deleting the work directory of a process,
		# so we change the working dir
		my $documents = File::HomeDir->my_documents;
		if ( defined $documents ) {
			chdir $documents;
		}
	}

	# HACK: Uncomment this to locate difficult-to-find crashes
	#       that are throw silent exceptions.
	# local $SIG{__DIE__} = sub { print @_; die $_[0] };

	TRACE("Killing the splash screen") if DEBUG;
	if ($Padre::Startup::VERSION) {
		require Padre::Unload;
		Padre::Startup->destroy_splash;
		Padre::Unload::unload('Padre::Startup');
	}

	TRACE("Processing the action queue") if DEBUG;
	if ( defined $self->opts->{actionqueue} ) {
		foreach my $action ( split( /\,/, $self->opts->{actionqueue} ) ) {
			next if $action eq ''; # Skip empty action names
			unless ( defined $self->actions->{$action} ) {
				warn 'Action "$action" queued from command line but does not exist';
				next;
			}

			# Add the action to the queue
			$self->wx->queue->add($action);
		}
	}

	TRACE("Switching into runtime mode") if DEBUG;
	$self->wx->MainLoop;
}

# Save the YAML configuration file
sub save_config {
	$_[0]->config->write;
}





#####################################################################
# Project Management

# Temporary pass-through
sub project {
	$_[0]->project_manager->project( $_[1] );
}

1;

__END__

=pod

=head1 NAME

Padre - Perl Application Development and Refactoring Environment

=head1 SYNOPSIS

Padre is a text editor aimed to be an IDE for Perl.

After installation you should be able to just type in

  padre

and get the editor working.

Padre development started in June 2008 and made a lot of progress but
there are still lots of missing features and the development is still
very fast.

=head1 Getting Started

After installing Padre you can start it by typing B<padre> on the command line.
On Windows that would be Start/Run padre.bat

You can start new files File/New (C<Ctrl+N>)
or open existing files File/Open (C<Ctrl+O>).

You can edit the file and save it using File/Save (C<Ctrl+S>).

You can run the script by pressing Run/Run Script (C<F5>)

By default Padre uses the same Perl interpreter for
executing code that it uses for itself but this will be configurable
later.

=head1 FEATURES

Instead of duplicating all the text here, let us point you to the
web site of Padre L<http://padre.perlide.org/> where we keep a list
of existing and planned features. We are creating detailed explanation
about every feature in our wiki: L<http://padre.perlide.org/trac/wiki/Features/>

=head1 DESCRIPTION

=head2 Configuration

The application maintains its configuration information in a
directory called F<.padre>.

=head2 Other

On Strawberry Perl you can associate .pl file extension with
F<C:\strawberry\perl\bin\wxperl> and then you can start double
clicking on the application. It should work...

Run This (C<F5>) - run the current buffer with the current Perl
this currently only works with files with F<.pl> extensions.

Run Any (C<Ctrl+F5>) - run any external application

First time it will prompt you to a command line that you have to
type in such as

  perl /full/path/to/my/script.pl

...then it will execute this every time you press C<Ctrl+F5> or the menu
option. Currently C<Ctrl+F5> does not save any file.
(This will be added later.)

You can edit the command line using the Run/Setup menu item.

Please Note that you can use C<$ENV{PADRE_VERSION}> to detect whether the script
is running inside Padre or not.

=head2 Navigation

  Ctrl+2          Quick Fix
  Ctrl+.          Next Problem
 
  Ctrl+H opens a help window where you can see the documentation of
  any Perl module. Just use open (in the help window) and type in the name
  of a module.

  Ctrl+Shift+H Highlight the name of a module in the editor and then
  press Ctrl+Shift+H. It will open the help window for the module
  whose name was highlighted.

  In the help window you can also start typing the name of a module. When the
  list of the matching possible modules is small enough you'll be able
  to open the drop-down list and select the name.
  The "small enough" is controlled by two configuration options in the
  Edit/Setup menu:

  Max Number of modules
  Min Number of modules

  This feature only works after you have indexed all the modules
  on your computer. Indexing is currently done by running the following command:

  padre --index


=head1 SQLite

Padre is using an SQLite database (F<~/.padre/config.db>) for two
things.
Part of the preferences/configuration information is kept there
and it is used for the POD reader.

=head1 Documentation POD reader

Padre currently can index (the names of) all the modules on
your system and it was planned to have a search capability for
modules/functions/etc.

=head1 Plug-ins

There is a highly experimental but quite simple plug-in system.

A plug-in is a module in the C<Padre::Plugin::*> namespace.

At start-up time Padre looks for all such modules in C<@INC> and
in its own private directory and loads them.

Every plug-in must be a subclass of L<Padre::Plugin> and follow the rules
defined in the L<Padre::Plugin> API documentation.

See also L<Padre::PluginManager> and L<Padre::PluginBuilder>

While Padre is running there is a menu option to show the plug-in configuration
window that shows the list of all the plug-ins.

TO DO: What to do if a newer version of the same plug-in was installed?

TO DO: What to do if a module was removed ? Shall we keep its data in
the configuration file or remove it?

TO DO: Padre should offer an easy but simple way for plug-in authors
to declare configuration variables and automatically generate both configuration
file and configuration dialog. Padre should also allow for full customization
of both for those more advanced in Wx.

=head2 Tab and space conversion

Tab to Space and Space to Tab conversions ask the number of spaces
each tab should substitute. It currently works everywhere.
We probably should add a mode to operate only at the beginning of
the lines or better yet only at the indentation levels.

Delete All Ending space does just what it says.

Delete Leading Space will ask How many leading spaces and act accordingly.

=head1 Code layout

=over 4

=item Padre.pm

is the main module.

=item L<Padre::Autosave>

describes some of our plans for an auto-save mechanism.
It is not implemented yet. (There is also some description elsewhere in this
document).

=item L<Padre::Config>

reads/writes the configuration files.

There is an SQLite database and a YAML file to keep various pieces of information.
The database holds host related configuration values while the YAML file holds
personal configuration options.

The SQLite database holds the list of modules available on the system.
It will also contain indexing of the documentation
Looking at the C<X<>> entries of modules
List of functions

=item L<Padre::DB>

The SQLite database abstraction for storing Padre's internal data.

=item L<Padre::Document>

is an abstraction class to deal with a single document.

=over 4

=item L<Padre::Document::PASM>

=item L<Padre::Document::PIR>

=item L<Padre::Document::Perl>

=back

=item L<Padre::PluginBuilder>

=item L<Padre::PluginManager>

locates and loads the plug-ins.

=item L<Padre::Plugin>

Should be the base class of all plug-ins.

=item L<Padre::Pod2HTML>

=item L<Padre::PPI>

=item L<Padre::Project>

Abstract class understanding what a project is.

=item L<Padre::Project::Perl>

Is a Perl specific project. These are work in process.
Not yet used.

=item L<Padre::TaskManager>

Managing background tasks.

=item L<Padre::Task>

Background tasks.

=item L<Padre::Util>

Various utility functions.

=back

=head2 Wx GUI

The C<Padre::Wx::*> namespace is supposed to deal with all the
Wx related code.

=over 4

=item L<Padre::Wx>

=item L<Padre::Wx::App>

is the L<Wx::App> subclass. Does not really do much.

=item L<Padre::Wx::Dialog::Bookmarks>

=item L<Padre::Wx::Dialog::Find>

This is the main Find dialog

=item L<Padre::Wx::Panel::FindFast>

This is the newer Firefox like inline search box.

=item L<Padre::Wx::Dialog::PluginManager>

=item L<Padre::Wx::Dialog::Preferences>

=item L<Padre::Wx::Dialog::Snippets>

=item L<Padre::Wx::FileDropTarget>

The code for drag and drop

=item L<Padre::Wx::Editor>

holds an editor text control instance (one for each buffer/file).
This is a subclass of L<Wx::Scintilla::TextCtrl> also known as Scintilla.

=item L<Padre::Wx::ComboBox::History>

=item L<Padre::Wx::TextEntryDialog::History>

=item L<Padre::Wx::Main>

This is the main window, most of the code is currently there.

=item L<Padre::Wx::Menu>

handles everything the menu should know and do.

=item L<Padre::Wx::Output>

the output window at the bottom of the editor displaying the output
of running code using C<F5>.

=item L<Padre::Wx::HtmlWindow>

=item L<Padre::Wx::Frame::POD>

=item L<Padre::Wx::Popup>

not in use.

=item L<Padre::Wx::Printout>

Implementing the printing capability of Padre.

=item L<Padre::Wx::SyntaxCheck>

Implementing the continuous syntax check of Perl code.

=item L<Padre::Wx::ToolBar>

handles everything the toolbar should know and do.

=back

=head1 BUGS

Before submitting a bug please talk to the Padre developers
on IRC: #padre on irc.perl.org. You can use this web based
IRC client: L<http://padre.perlide.org/irc.html?channel=padre>

Please submit your bugs at L<http://padre.perlide.org/trac/>

=head1 SUPPORT

See also L<http://padre.perlide.org/contact.html>

=head1 COPYRIGHT

Copyright 2008-2012 The Padre development team as listed in Padre.pm.
L<http://padre.perlide.org/>

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=head1 ACKNOWLEDGEMENTS

=encoding utf8

=head2 The Padre development team

The developers of Padre in alphabetical order:

Aaron Trevena (TEEJAY)

Ahmad Zawawi أحمد محمد زواوي (AZAWAWI)

Adam Kennedy (ADAMK) E<lt>adamk@cpan.orgE<gt>

Alexandr Ciornii (CHORNY)

Blake Willmarth (BLAKEW)

Breno G. de Oliveira (GARU)

Brian Cassidy (BRICAS)

Burak Gürsoy (BURAK) E<lt>burak@cpan.orgE<gt>

Cezary Morga (THEREK) E<lt>cm@therek.netE<gt>

Chris Dolan (CHRISDOLAN)

Claudio Ramirez (NXADM) E<lt>nxadm@cpan.orgE<gt>

Fayland Lam (FAYLAND) E<lt>fayland@gmail.comE<gt>

Gabriel Vieira (GABRIELMAD)

Gábor Szabó - גאבור סבו (SZABGAB) E<lt>szabgab@gmail.comE<gt>

Heiko Jansen (HJANSEN) E<lt>heiko_jansen@web.deE<gt>

Jérôme Quelin (JQUELIN) E<lt>jquelin@cpan.orgE<gt>

Kaare Rasmussen (KAARE) E<lt>kaare@cpan.orgE<gt>

Keedi Kim - 김도형 (KEEDI)

Kenichi Ishigaki - 石垣憲一 (ISHIGAKI) E<lt>ishigaki@cpan.orgE<gt>

Mark Grimes E<lt>mgrimes@cpan.orgE<gt>

Max Maischein (CORION)

Olivier MenguE<eacute> (DOLMEN)

Patrick Donelan (PDONELAN) E<lt>pat@patspam.comE<gt>

Paweł Murias (PMURIAS)

Petar Shangov (PSHANGOV)

Ryan Niebur (RSN) E<lt>rsn@cpan.orgE<gt>

Sebastian Willing (SEWI)

Steffen Müller (TSEE) E<lt>smueller@cpan.orgE<gt>

Zeno Gantner (ZENOG)

=head2 Translators

=head3 Arabic

Ahmad M. Zawawi - أحمد محمد زواوي (AZAWAWI)

=head3 Chinese (Simplified)

Fayland Lam (FAYLAND)

=head3 Chinese (Traditional)

BlueT - Matthew Lien - 練喆明 (BLUET) E<lt>bluet@cpan.orgE<gt>

Chuanren Wu

=head3 Dutch

Dirk De Nijs (ddn123456)

=head3 English

Everyone on the team

=head3 French

Jérôme Quelin (JQUELIN)

Olivier MenguE<eacute> (DOLMEN)

=head3 German

Heiko Jansen (HJANSEN)

Sebastian Willing (SEWI)

Zeno Gantner (ZENOG)

=head3 Hebrew

Omer Zak  - עומר זק

Shlomi Fish  - שלומי פיש (SHLOMIF)

Amir E. Aharoni - אמיר א. אהרוני

=head3 Hungarian

György Pásztor (GYU)

=head3 Italian

Simone Blandino (SBLANDIN)

=head3 Japanese

Kenichi Ishigaki - 石垣憲一 (ISHIGAKI)

=head3 Korean

Keedi Kim - 김도형 (KEEDI)

=head3 Russian

Andrew Shitov

=head3 Polish

Cezary Morga (THEREK)

=head3 Portuguese (Brazilian)

Breno G. de Oliveira (GARU)

=head3 Spanish

Paco Alguacil (PacoLinux)

Enrique Nell (ENELL)

=head3 Czech

Marcela Mašláňová (mmaslano)

=head3 Norwegian

Kjetil Skotheim (KJETIL)

=head3 Turkish

Burak Gürsoy (BURAK) E<lt>burak@cpan.orgE<gt>

=head2 Thanks

Mattia Barbon for providing wxPerl.
Part of the code was copied from his Wx::Demo application.

Herbert Breunung for letting me work on Kephra.

Octavian Rasnita for early testing and bug reports.

Tatsuhiko Miyagawa for consulting on our I18N and L10N support.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
