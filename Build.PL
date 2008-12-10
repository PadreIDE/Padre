use strict;
use warnings;

use lib 'inc';
use Padre::Install;
use Config;

unless ( $Config{usethreads} ) {
	warn "Padre requires a perl built using threads\n";
	exit 0;
}

check_wx_version();

my %prereqs = (
	'perl'                    => '5.008001',
	'Carp'                    => 0,
	'Class::Adapter'          => '1.05',
	'Class::XSAccessor'       => '0.09',
	'Cwd'                     => '3.2701',
	'Data::Dumper'            => 0,
	'Encode'                  => '2.12',
	'File::Spec'              => '3.2701',
	'File::Spec::Functions'   => '3.2701',
	'File::Basename'          => 0,
	'FindBin'                 => 0,
	'Getopt::Long'            => 0,
	'HTML::Parser'            => '3.58',
	'HTML::Entities'          => '3.57',
	'List::Util'              => '1.18',
	'IO::Socket'              => '1.30',
	'Term::ReadLine'          => 0,
	'Module::Refresh'         => '0.13',
	'App::Ack'                => '1.86',
	'Class::Autouse'          => '1.26',
	'Class::Unload'           => '0.03',
	'DBD::SQLite'             => '1.10',
	'DBI'                     => '1.58',
	'File::Copy::Recursive'   => '0.37',
	'File::Find::Rule'        => '0.30',
	'File::HomeDir'           => '0.82',
#	'File::LocalizeNewlines'  => '1.10',
	'File::ShareDir'          => '1.00',
	'File::ShareDir::PAR'     => '0.03',
	'File::Which'             => '0.05',
	'IO::String'              => '1.08',
	'Module::Inspector'       => '0.04',
	'Module::Starter'         => '1.50',
	'ORLite'                  => '0.15',
	'Params::Util'            => '0.33',
	'PAR'                     => '0.970',
	'Pod::POM'                => '0.17',
	'Pod::Simple'             => '3.07',
	'Pod::Simple::XHTML'      => '3.04',
	'Probe::Perl'             => '0.01',
	'PPI'                     => '1.203',
	'Storable'                => '2.15',
	'Text::Diff'              => '0.35',
	'Text::FindIndent'        => '0.03',
	'threads'                 => '1.71',
	'threads::shared'         => '1.26',
	'Thread::Queue'           => '2.11',
	'YAML::Tiny'              => '1.32',
	'Wx'                      => '0.89',
	'Wx::Perl::Dialog'        => '0.03',
	'Wx::Perl::ProcessStream' => '0.11',
);

my $builder = Padre::Install->new(
	module_name           => 'Padre',
	license               => 'perl',
	dist_author           => 'Gabor Szabo',
	create_makefile_pl    => 0,
	create_readme         => 0,
	recursive_test_files  => 0,

	script_files          => [ 'script/padre' ],
	requires              => \%prereqs,
	build_requires        => {
#		'Test::Compile'             => '0.08', # does not work on Windows
		'Test::More'                => '0.47',
		'Test::Exception'           => '0.27',
		'Test::NoWarnings'          => '0.084',
		'Test::NeedsDisplay'        => '1.05',
	},
	meta_merge => {
		resources => {
			homepage    => 'http://padre.perlide.org/',
			bugtracker  => 'http://padre.perlide.org/',
			Repository  => 'http://svn.perlide.org/padre',
			MailingList => 'http://mail.perlide.org/mailman/listinfo/padre-dev',
		},
		no_index => {
			directory => [ qw{ t xt eg share inc} ],
		},
	},
);

$builder->config('usethreads');
$builder->create_build_script();

sub check_wx_version {
	eval { require Wx };

	# Missing Wx should be dealt by the standard prereq system
	return if $@;

	my $version = Wx::wxVERSION_STRING();
	nono("Could not find Wx::wxVERSION_STRING") if not defined $version;

	print "Found $version\n";
	print "Found Wx.pm     $Wx::VERSION\n";
	$version =~ s/wxWidgets\s+//;
	if ( $version !~ /^\d+\.\d+(\.\d+)?$/ ) {
		nono("Sorry we don't known this wxWidgets version format: '$version'");
	}
	my ($major, $minor, $way_too_minor) = split /\./, $version;
	if ( $major < 2 or $minor < 8 ) {
		nono("Padre needs at least version 2.8.8 of wxWidgets. this is version $version");
	}

	return;
}

sub nono {
	my $msg = shift;
	print STDERR "$msg\n";
	exit 0;
}
