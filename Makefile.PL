# NOTE: inc::Module::Install::PRIVATE::Padre needs Perl 5.8, so make sure
# that we force the Perl version check (and fail) early.
# Unicode is also considered to finally be "stable" at 5.8.5, so we will
# set our dependency on that.
use 5.010000;
use strict;
use lib 'privinc';
use inc::Module::Install 1.06;
use POSIX qw(locale_h);

# Workaround for the fact that Module::Install loads the modules
# into memory and when Test::NoWarnings is loaded it will hide
# the warnings generated from that point.
# Removed in r2208, added again in r9001
eval {
	require Test::NoWarnings;
	$SIG{__WARN__} = 'DEFAULT';
};

BEGIN {
	if ( author_context and not eval("use Locale::Msgfmt 0.15; 1;") ) {
		die("Install Locale::Msgfmt version 0.15 or higher to build from SVN");
	}
}

# Configure-time dependencies MUST be done first.
# This version ensures that we have a new MakeMaker that
# WON'T load modules to determine the version.
# This _SHOULD_ theoretically make the "require Test::NoWarnings".
# stuff above here no longer needed.
configure_requires 'ExtUtils::MakeMaker' => '6.52';

# Force an explicit configure_requires dependency on module that is
# SUPPOSED to be in the Perl core but that some Perl vendors seem to
# be splitting out into separate modules (spotted first on centos)
configure_requires 'ExtUtils::Embed' => '1.250601';

# the above line does not seem to force an upgrade
# the below code might work but not tested
#eval "use ExtUtils::MakeMaker ()"; # avoid importing prompt() and other subs
#if ($@) {
#	print STDERR "Warning: prerequisite ExtUtils::MakeMaker 6.52 not found.\n";
#	exit 0;
#} elsif ($ExtUtils::MakeMaker::VERSION <= 6.52) {
#	print STDERR "Warning: prerequisite ExtUtils::MakeMaker 6.52 not found. We have $ExtUtils::MakeMaker::VERSION.\n";
#	exit 0;
#}

# This makes sure that we didn't compile Alien::wxWidgets with the wrong options.
configure_requires 'Alien::wxWidgets' => '0.62';

my $wxw = eval { use Alien::wxWidgets; 1; };
if ( $@ or not $wxw ) {
	print STDERR "Warning: prerequisite Alien::wxWidgets not found.\n";
	exit 0;
}
if ( '2.009000' eq Alien::wxWidgets->version ) {
	print STDERR "Warning: Alien::wxWidgets was compiled with the development version of\n";
	print STDERR "wxWidgets. This is known to cause Padre to crash.\n";
	exit 0;
}





#####################################################################
# Normal Boring Commands

# NOTE: Core modules that aren't dual-life should always have a version of 0

name 'Padre';
license 'perl';
author 'Gabor Szabo';
all_from 'lib/Padre.pm';
requires 'perl' => '5.011000';

# General dependencies
requires 'Algorithm::Diff'          => '1.19';
requires 'App::cpanminus'           => '0.9923';
requires 'B::Deparse'               => 0;
requires 'Capture::Tiny'            => '0.06';
requires 'CGI'                      => '3.47';
requires 'Class::Adapter'           => '1.05';
requires 'Class::Inspector'         => '1.22';
requires 'Class::XSAccessor'        => '1.13';
requires 'Cwd'                      => '3.2701';
requires 'Data::Dumper'             => '2.101';
requires 'DBD::SQLite'              => '1.35';
requires 'DBI'                      => '1.58';
requires 'Debug::Client'            => '0.29';
requires 'Devel::Dumpvar'           => '0.04';
requires 'Devel::Refactor'          => '0.05';
requires 'Encode'                   => '2.26';
requires 'ExtUtils::MakeMaker'      => '6.56';
requires 'ExtUtils::Manifest'       => '1.56';
requires 'File::Basename'           => 0;
requires 'File::Glob'               => 0;
requires 'File::Glob::Windows'      => '0.1.3' if win32;
requires 'File::Copy::Recursive'    => '0.37';
requires 'File::Find::Rule'         => '0.30';
requires 'File::HomeDir'            => (win32) ? '0.98' : '0.91';
requires 'File::Path'               => '2.08';
requires 'File::Remove'             => (win32) ? '1.49' : '1.40';
requires 'File::ShareDir'           => '1.00';
requires 'File::Spec'               => '3.2701';
requires 'File::Spec::Functions'    => '3.2701';
requires 'File::Temp'               => '0.20';
requires 'File::Which'              => '1.08';
requires 'File::pushd'              => '1.00';
requires 'FindBin'                  => 0;
requires 'Getopt::Long'             => 0;
requires 'HTML::Entities'           => '3.57';
requires 'HTML::Parser'             => '3.58';
requires 'IO::Socket'               => '1.30';
requires 'IO::String'               => '1.08';
requires 'IPC::Run'                 => '0.83';
requires 'IPC::Open2'               => 0;
requires 'IPC::Open3'               => 0;
requires 'JSON::XS'                 => '2.29';
requires 'List::Util'               => '1.18';
requires 'List::MoreUtils'          => '0.22';
requires 'LWP'                      => '5.815';
requires 'LWP::UserAgent'           => '5.815';
requires 'Module::Build'            => '0.3603';
requires 'Module::CoreList'         => '2.22';
requires 'Module::Manifest'         => '0.07';
requires 'Module::Starter'          => '1.60';
requires 'ORLite'                   => '1.98';
requires 'ORLite::Migrate'          => '1.10';
requires 'Params::Util'             => '0.33';
requires 'Parse::ErrorString::Perl' => '0.18';
requires 'Parse::ExuberantCTags'    => '1.00';
requires 'Pod::Functions'           => 0;
requires 'Pod::POM'                 => '0.17';
requires 'Pod::Simple'              => '3.07';
requires 'Pod::Simple::XHTML'       => '3.04';
requires 'Pod::Abstract'            => '0.16';
requires 'Pod::Perldoc'             => '3.15';
requires 'POD2::Base'               => '0.043';
requires 'POSIX'                    => 0;
requires 'PPI'                      => '1.215';
requires 'PPIx::EditorTools'        => '0.18';
requires 'PPIx::Regexp'             => '0.011';
requires 'Probe::Perl'              => '0.01';
requires 'Storable'                 => '2.16';
requires 'Sort::Versions'           => '1.5';
requires 'Template::Tiny'           => '0.11';
requires 'Term::ReadLine'           => 0;
requires 'Text::Balanced'           => '2.01';
requires 'Text::Diff'               => '1.41';
requires 'Text::FindIndent'         => '0.10';
requires 'Time::HiRes'              => '1.9718';
requires 'Text::Patch'              => '1.8';
requires 'threads'                  => '1.71';
requires 'threads::shared'          => '1.33';
requires 'URI'                      => '0';
requires 'version'                  => '0.80';
requires 'Win32'              => '0.31' if win32;
requires 'Win32::Shortcut'    => '0.07' if win32;
requires 'Win32::TieRegistry' => '0.26' if win32;
requires 'Wx'                 => '0.9916';
requires 'Wx::Perl::ProcessStream' => '0.32';
requires 'Wx::Scintilla'           => '0.39';
requires 'YAML::Tiny'              => '1.32';
test_requires 'Test::More'         => '0.98';

# Ticket #1419: Padre and the soon to be Perl 5.16
test_requires 'Test::Warn'       => '0.24';
test_requires 'Test::MockObject' => '1.09';
test_requires 'Test::Script'     => '1.07';
test_requires 'Test::Exception'  => '0.27';
test_requires 'Test::NoWarnings' => '1.04';

# Special dependencies

# In the Padre.ppd file we need to list IO-stringy instead
requires 'IO::Scalar' => '2.110';

# Add later, once we native support portability
# requires 'Portable' => '0.12' if win32;

# PAR support disabled for now
# requires 'File::ShareDir::PAR' => '0.04';
# requires 'PAR'                 => '0.989';

my $locale = setlocale(LC_CTYPE);
print "Found locale    $locale\n";

# What tests should we run?
my @TESTS = (
	't/*.t',
	't/perl/*.t',
	't/python/*.t',
	't/ruby/*.t',
	't/java/*.t',
	't/csharp/*.t',
);
if ( win32 and $locale =~ /^English/ ) {
	if ( author_context or $ENV{RELEASE_TESTING} ) {
		push @TESTS, 't/win32/*.t';
	}
}
if ( author_context or $ENV{AUTOMATED_TESTING} or $ENV{RELEASE_TESTING} ) {
	push @TESTS, 'xt/*.t';
}
tests join ' ', @TESTS;

no_index 'directory' => qw{ t xt eg share inc privinc };
homepage 'http://padre.perlide.org/';
bugtracker 'http://padre.perlide.org/trac/';
repository 'http://svn.perlide.org/padre/trunk/Padre/';

Meta->add_metadata(
    x_contributors => [
        'Aaron Trevena (TEEJAY)',
        'Adam Kennedy (ADAMK) <adamk@cpan.org>',
        'Ahmad Zawawi أحمد محمد زواوي (AZAWAWI)',
        'Andrew Shitov',
        'Alexandr Ciornii (CHORNY)',
        'Amir E. Aharoni - אמיר א. אהרוני',
        'Blake Willmarth (BLAKEW)',
        'BlueT - Matthew Lien - 練喆明 (BLUET) <bluet@cpan.org>',
        'Breno G. de Oliveira (GARU)',
        'Brian Cassidy (BRICAS)',
        'Burak Gürsoy (BURAK) <burak@cpan.org>',
        'Cezary Morga (THEREK) <cm@therek.net>',
        'Chris Dolan (CHRISDOLAN)',
        'Claudio Ramirez (NXADM) <nxadm@cpan.org>',
        'Dirk De Nijs (ddn123456)',
        'Enrique Nell (ENELL)',
        'Fayland Lam (FAYLAND) <fayland@gmail.com>',
        'Gabriel Vieira (GABRIELMAD)',
        'Gábor Szabó - גאבור סבו (SZABGAB) <szabgab@cpan.org>',
        'György Pásztor (GYU)',
        'Heiko Jansen (HJANSEN) <heiko_jansen@web.de>',
        'Jérôme Quelin (JQUELIN) <jquelin@cpan.org>',
        'Kaare Rasmussen (KAARE) <kaare@cpan.org>',
        'Keedi Kim - 김도형 (KEEDI)',
        'Kenichi Ishigaki - 石垣憲一 (ISHIGAKI) <ishigaki@cpan.org>',
        'Kevin Dawson (BOWTIE) <bowtie@cpan.org>',
        'Kjetil Skotheim (KJETIL)',
        'Marcela Mašláňová (mmaslano)',
        'Marek Roszkowski (EviL) <evil@evil.devil.is-my.name>',
        'Mark Grimes <mgrimes@cpan.org>',
        'Max Maischein (CORION)',
        'Olivier MenguE<eacute> (DOLMEN)',
        'Omer Zak  - עומר זק',
        'Paco Alguacil (PacoLinux)',
        'Patrick Donelan (PDONELAN) <pat@patspam.com>',
        'Paweł Murias (PMURIAS)',
        'Petar Shangov (PSHANGOV)',
	'Peter Lavender (PLAVEN)',
        'Ryan Niebur (RSN) <rsn@cpan.org>',
        'Sebastian Willing (SEWI)',
        'Shlomi Fish  - שלומי פיש (SHLOMIF)',
        'Simone Blandino (SBLANDIN)',
        'Steffen Müller (TSEE) <smueller@cpan.org>',
        'Zeno Gantner (ZENOG)',
        'Chuanren Wu',
    ],
);

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
	"version control",
	"patch",
	"diff",
	"wx",
	"wxwidgets",
);

install_script 'script/padre';

build_padre_exe if win32;

install_share_with_mofiles;

auto_provides if -f 'MANIFEST';





#####################################################################
# Padre-Specific Oddities

# Padre requires threads
# First we should check if the perl is threaded so the users
# won't waste time installing modules on a perl without thread support.
use Config;
unless ( $Config{usethreads} ) {
	warn("Padre requires a perl built using threads\n");

	# Exit 0 without Makefile means "Not Applicable" (NA in CPAN Testers)
	exit(0);
}

# The check_wx_version command SHOULD (hopefully) now be able to verify the
# wxWidgets version WITHOUT having to have DISPLAY.
check_wx_version;

# Add the make exe target
setup_padre;

show_debuginfo;

WriteAll;
