# NOTE: inc::Module::Install::PRIVATE::Padre needs Perl 5.8, so make sure
# that we force the Perl version check (and fail) early.
# Unicode is also considered to finally be "stable" at 5.8.5, so we will
# set our dependency on that.
use 5.008005;
use strict;
use lib 'privinc';
use inc::Module::Install 0.91;
use POSIX qw(locale_h);

BEGIN {
	if ( author_context and not eval("use Locale::Msgfmt 0.14; 1;") ) {
		die("Install Locale::Msgfmt version 0.14 or higher to build from SVN");
	}
}

# Configure-time dependencies MUST be done first
configure_requires 'ExtUtils::MakeMaker' => '6.52';





#####################################################################
# Normal Boring Commands

# NOTE: Core modules that aren't dual-life should always have a version of 0

name           'Padre';
license        'perl';
author         'Gabor Szabo';
all_from       'lib/Padre.pm';
requires       'perl'                     => '5.008005';
requires       'App::Ack'                 => '1.86';
requires       'Capture::Tiny'            => '0.06';
requires       'Carp'                     => 0;
requires       'Class::Adapter'           => '1.05';
requires       'Class::Unload'            => '0.03';
requires       'Class::XSAccessor'        => '1.02';
requires       'Class::XSAccessor::Array' => '1.02';
requires       'Cwd'                      => '3.2701';
requires       'Data::Dumper'             => 0;
requires       'DBD::SQLite'              => '1.10';
requires       'DBI'                      => '1.58';
requires       'Devel::Dumpvar'           => '0.04';
requires       'Devel::Refactor'          => '0.05';
requires       'Digest::MD5'              => 0;
requires       'Encode'                   => '2.26';
requires       'File::Basename'           => 0;
requires       'File::Glob'               => 0;
requires       'File::Glob::Windows'      => '0.1.3' if win32;
requires       'File::Copy::Recursive'    => '0.37';
requires       'File::Find::Rule'         => '0.30';
requires       'File::HomeDir'            => '0.84';
requires       'File::Next'               => '1.06'; # Force-bump ack dep
requires       'File::Path'               => 0;
requires       'File::Remove'             => '1.42';
requires       'File::ShareDir'           => '1.00';
#requires      'File::ShareDir::PAR'      => '0.04';
requires       'File::Spec'               => '3.2701';
requires       'File::Spec::Functions'    => '3.2701';
requires       'File::Which'              => '1.08';
requires       'FindBin'                  => 0;
requires       'Getopt::Long'             => 0;
requires       'HTML::Entities'           => '3.57';
requires       'HTML::Parser'             => '3.58';
# In the Padre.ppd file we need to list IO-stringy instead
requires       'IO::Scalar'               => '2.110';
requires       'IO::Socket'               => '1.30';
requires       'IO::String'               => '1.08';
requires       'List::Util'               => '1.18';
requires       'List::MoreUtils'          => '0.22';
requires       'Module::Refresh'          => '0.13';
requires       'Module::Starter'          => '1.50';
requires       'ORLite'                   => '1.20';
requires       'ORLite::Migrate'          => '0.03';
#requires      'PAR'                      => '0.989';
requires       'Params::Util'             => '0.33';
requires       'Parse::ErrorString::Perl' => '0.11';
requires       'Parse::ExuberantCTags'    => '1.00';
requires       'pip'                      => '0.13';
requires       'Pod::POM'                 => '0.17';
requires       'Pod::Simple'              => '3.07';
requires       'Pod::Simple::XHTML'       => '3.04';
requires       'Pod::Abstract'            => '0.16';
requires       'Pod::Perldoc'             => '3.15';
#requires       'Portable'                 => '0.12' if win32;
requires       'POSIX'                    => 0;
requires       'PPI'                      => '1.205';
requires       'PPIx::EditorTools'        => '0.09';
requires       'Probe::Perl'              => '0.01';
requires       'Storable'                 => '2.15';
requires       'Term::ReadLine'           => 0;
requires       'Text::Balanced'           => 0;
requires       'Text::Diff'               => '0.35';
requires       'Text::FindIndent'         => '0.03';
requires       'Thread::Queue'            => '2.11';
requires       'threads'                  => '1.71';
requires       'threads::shared'          => '1.26';
requires       'URI'                      => '0';
requires       'version'                  => 0;
requires       'Win32::API'               => '0.58' if win32;
requires       'Wx'                       => '0.91';
requires       'Wx::Perl::ProcessStream'  => '0.11';
requires       'YAML::Tiny'               => '1.32';
requires       'ExtUtils::Manifest'       => '1.56';
requires       'Pod::Functions'           => 0;
requires       'Module::CoreList'         => 0;
test_requires  'Test::More'               => '0.88';
test_requires  'Test::Script'             => '1.05';
test_requires  'Test::Exception'          => '0.27';
test_requires  'Test::NoWarnings'         => '0.084';

my $locale = setlocale(LC_CTYPE);
print "Found locale    $locale\n";
if ( win32 and $locale =~ /^English/ ) {
	tests 't/*.t t/win32/*.t';
}

no_index   'directory' => qw{ t xt eg share inc privinc };
homepage   'http://padre.perlide.org/';
bugtracker 'http://padre.perlide.org/trac/';
repository 'http://svn.perlide.org/padre/trunk/Padre/';

keywords(
	"auto-completion",
	"code",
	"coding",
	"completion",
	"context",
	"cross-platform",
	"development",
	"editor",
	"environment",
	"find",
	"function list",
	"gui",
	"help",
	"highlight",
	"hightlighting",
	"ide",
	"linux",
	"mac os",
	"mac os x",
	"padre",
	"perl",
	"portable",
	"refactoring",
	"replace",
	"syntax",
	"windows",
	"wx",
	"wxwidgets",
);

install_script 'script/padre';
install_script 'script/wpadre.vbs' if win32;
install_script 'script/padre.exe' if win32;
install_share_with_mofiles;





#####################################################################
# Padre-Specific Oddities

# Padre requires threads
# First we should check if the perl is threaded so the users 
# won't waste time installing modules on a perl without thread support.
use Config;
unless ( $Config{usethreads} ) {
	warn("Padre requires a perl built using threads\n");
	exit(0);
}

# The check_wx_version command SHOULD (hopefully) now be able to verify the
# wxWidgets version WITHOUT having to have DISPLAY.
check_wx_version;

# Add the make exe target
setup_padre;

WriteAll;
