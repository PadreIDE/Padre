use strict;
use lib 'privinc';
use inc::Module::Install;

use Config;
unless ( $Config{usethreads} ) {
	warn "Padre requires a perl built using threads\n";
	exit 0;
}

# Fedora and other rpm based build systems remove the DISPLAY by default
# which blows up when checking the Wx version. So we disable it.
# See  #170
if ($^O eq 'Win32' or $ENV{DISPLAY}) {
	check_wx_version;
}

name           'Padre';
license        'perl';
author         'Gabor Szabo';
all_from       'lib/Padre.pm';
requires       'perl'                    => '5.008001';
requires       'Carp'                    => 0;
requires       'Class::Adapter'          => '1.05';
requires       'Class::XSAccessor'       => '0.09';
requires       'Cwd'                     => '3.2701';
requires       'Data::Dumper'            => 0;
requires       'Encode'                  => '2.12';
requires       'File::Spec'              => '3.2701';
requires       'File::Spec::Functions'   => '3.2701';
requires       'File::Basename'          => 0;
requires       'FindBin'                 => 0;
requires       'Getopt::Long'            => 0;
requires       'HTML::Parser'            => '3.58';
requires       'HTML::Entities'          => '3.57';
requires       'List::Util'              => '1.18';
requires       'IO::Socket'              => '1.30';
requires       'IPC::Run3'               => '0.035';
requires       'Term::ReadLine'          => 0;
requires       'Module::Refresh'         => '0.13';
requires       'App::Ack'                => '1.86';
requires       'Class::Autouse'          => '1.26';
requires       'Class::Unload'           => '0.03';
requires       'DBD::SQLite'             => '1.10';
requires       'DBI'                     => '1.58';
requires       'File::Copy::Recursive'   => '0.37';
requires       'File::Find::Rule'        => '0.30';
requires       'File::HomeDir'           => '0.82';
requires       'File::ShareDir'          => '1.00';
requires       'File::ShareDir::PAR'     => '0.03';
requires       'File::Which'             => '0.05';
requires       'IO::String'              => '1.08';
requires       'Module::Inspector'       => '0.04';
requires       'Module::Starter'         => '1.50';
requires       'ORLite'                  => '0.15';
requires       'Params::Util'            => '0.33';
requires       'PAR'                     => '0.970';
requires       'Pod::POM'                => '0.17';
requires       'Pod::Simple'             => '3.07';
requires       'Pod::Simple::XHTML'      => '3.04';
requires       'Probe::Perl'             => '0.01';
requires       'PPI'                     => '1.203';
requires       'Storable'                => '2.15';
requires       'Text::Diff'              => '0.35';
requires       'Text::FindIndent'        => '0.03';
requires       'threads'                 => '1.71';
requires       'threads::shared'         => '1.26';
requires       'Thread::Queue'           => '2.11';
requires       'YAML::Tiny'              => '1.32';
requires       'Wx'                      => '0.89';
requires       'Wx::Perl::Dialog'        => '0.03';
requires       'Wx::Perl::ProcessStream' => '0.11';
test_requires  'Test::Compile'           => '0.08' unless win32;
test_requires  'Test::More'              => '0.47';
test_requires  'Test::Exception'         => '0.27';
test_requires  'Test::NoWarnings'        => '0.084';
test_requires  'Test::NeedsDisplay'      => '1.05';
no_index       'directory' => [ qw{ t xt eg share inc privinc} ];
install_script 'script/padre';
install_share;

#	meta_merge => {
#		resources => {
#			homepage    => 'http://padre.perlide.org/',
#			bugtracker  => 'http://padre.perlide.org/',
#			Repository  => 'http://svn.perlide.org/padre',
#			MailingList => 'http://mail.perlide.org/mailman/listinfo/padre-dev',
#		},

setup_padre;

WriteAll;
