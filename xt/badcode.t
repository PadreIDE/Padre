#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {

	# Don't run tests for installs
	unless ( $ENV{AUTOMATED_TESTING} or $ENV{RELEASE_TESTING} ) {
		plan( skip_all => "Author tests not required for installation" );
	}

	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan( skip_all => 'Needs DISPLAY' );
		exit(0);
	}
}

use Params::Util ':ALL';
use File::Find::Rule;
use PPI::Document;

# Calculate the plan
my %modules = map {
	my $class = $_;
	$class =~ s/\//::/g;
	$class =~ s/\.pm$//;
	$class => "lib/$_"
} File::Find::Rule->relative->name('*.pm')->file->in('lib');
my @t_files = glob "t/*.t";

#map {"t/$_"} File::Find::Rule->relative->name('*.t')->file->in('t');
plan( tests => scalar( keys %modules ) * 12 + scalar(@t_files) );

my %SKIP = map { ( "t/$_" => 1 ) } qw(
	01_compile.t
	06_utils.t
	07_version.t
	08_style.t
	14_warnings.t
	21_task_thread.t
	22_task_worker.t
	23_task_chain.t
	24_task_master.t
	25_task_handle.t
	26_task_eval.t
	41_perl_project.t
	42_perl_project_temp.t
	61_directory_path.t
	62_directory_task.t
	63_directory_project.t
	83_autosave.t
	85_commandline.t
	92_padre_file.t
	93_padre_filename_win.t
	94_padre_file_remote.t
);

# A pathetic way to try to avoid tests that would use the real ~/.padre of the user
# that would be especially problematic if ran under root
foreach my $t_file (@t_files) {
	if ( $SKIP{$t_file} ) {
		my $Test = Test::Builder->new;
		$Test->skip($t_file);
	} else {
		my $content = read_file($t_file);
		ok $content =~ qr/PADRE_HOME|use\s+t::lib::Padre/, "Having PADRE_HOME or use t::lib::Padre $t_file";
	}
}

# Compile all of Padre
use File::Temp;
use POSIX qw(locale_h);
$ENV{PADRE_HOME} = File::Temp::tempdir( CLEANUP => 1 );
foreach my $module ( sort keys %modules ) {
	require_ok($module);

	ok( $module->VERSION, "$module: Found \$VERSION" );
}

# List of non-Wx modules still having Wx code.
# This list is way-the-hell too long, stop putting stuff in here just
# to prevent failing the test. It should be an absolute last resort.
# Go away and try to find a way to not have Wx stuff in your code first.
my %TODO = map { $_ => 1 } qw(
	Padre::CPAN
	Padre::Document
	Padre::File::FTP
	Padre::Locale
	Padre::MIME
	Padre::Plugin
	Padre::Plugin::Devel
	Padre::Plugin::My
	Padre::PluginManager
	Padre::Task::LaunchDefaultBrowser
	Padre::TaskHandle
);

foreach my $module ( sort keys %modules ) {
	my $content = read_file( $modules{$module} );

	# Checking if only modules with Wx in their name depend on Wx
	if ( $module =~ /^Padre::Wx/ or $module =~ /^Wx::/ ) {
		my $Test = Test::Builder->new;
		$Test->skip("$module is a Wx module");
	} elsif ( $module =~ /^Padre::Plugin::/ ) {

		# Plugins are exempt from this rule.
		my $Test = Test::Builder->new;
		$Test->skip("$module is a Wx module");
	} else {
		my ($error) = $content =~ m/^use\s+.*Wx.*;/gmx;
		my $Test = Test::Builder->new;
		if ( $TODO{$module} ) {
			$Test->todo_start("$module should not contain Wx but it still does");
		}
		ok( !$error, "'$module' does not use Wx" ) or diag $error;
		if ( $TODO{$module} ) {
			$Test->todo_end;
		}
	}

	ok( $content !~ /\$DB\:\:single/,
		$module . ' uses $DB::single - please remove before release',
	);

	# Load the document
	my $document = PPI::Document->new(
		$modules{$module},
		readonly => 1,
	);
	ok( $document, "$module: Parsable by PPI" );
	unless ($document) {
		diag( PPI::Document->errstr );
	}

	# If a class has a current method, never use Padre::Current directly
	SKIP: {
		unless (eval { $module->can('current') }
			and $module ne 'Padre::Current'
			and $module ne 'Padre::Wx::Role::Main' )
		{
			skip( "No ->current method", 1 );
		}
		my $good = !$document->find_any(
			sub {
				$_[1]->isa('PPI::Token::Word') or return '';
				$_[1]->content eq 'Padre::Current' or return '';
				my $arrow = $_[1]->snext_sibling or return '';
				$arrow->isa('PPI::Token::Operator') or return '';
				$arrow->content eq '->' or return '';
				my $method = $arrow->snext_sibling or return '';
				$method->isa('PPI::Token::Word') or return '';
				$method->content ne 'new' or return '';
				return 1;
			}
		);
		ok( $good, "$module: Don't use Padre::Current when ->current is possible" );
	}

	# If a class has an ide or main method, never use Padre->ide directly
	SKIP: {
		unless (
			eval { $module->can('ide') or $module->can('main') }

			# and $module ne 'Padre::Wx::Dialog::RegexEditor'
			and $module ne 'Padre::Current'
			)
		{
			skip( "$module: No ->ide or ->main method", 1 );
		}
		my $good = !$document->find_any(
			sub {
				$_[1]->isa('PPI::Token::Word') or return '';
				$_[1]->content eq 'Padre' or return '';
				my $arrow = $_[1]->snext_sibling or return '';
				$arrow->isa('PPI::Token::Operator') or return '';
				$arrow->content eq '->' or return '';
				my $method = $arrow->snext_sibling or return '';
				$method->isa('PPI::Token::Word') or return '';
				$method->content eq 'ide' or return '';
				return 1;
			}
		);
		ok( $good, "$module: Don't use Padre->ide when ->ide or ->main is possible" );
	}

	# Method names with :: in them can only be to SUPER::method
	SCOPE: {
		my $good = !$document->find_any(
			sub {
				$_[1]->isa('PPI::Token::Operator') or return '';
				$_[1]->content eq '->' or return '';

				# Get the method name
				my $name = $_[1]->snext_sibling or return '';
				$name->isa('PPI::Token::Word') or return '';
				$name->content =~ /::/ or return '';
				$name->content !~ /^SUPER::\w+$/ or return '';

				# Naughty naughty
				diag(
					"$module: Evil method name '$name', it should probably be a function call... maybe. Change it, but be careful."
				);
				return 1;
			}
		);
		ok( $good, "$module: Don't use extended Method::name other than SUPER::name" );
	}

	# Avoid expensive regexp result variables
	SKIP: {
		if ( $module eq 'Padre::Wx::Dialog::RegexEditor' ) {
			skip( 'Ignoring RegexEditor', 1 );
		}
		my $good = !$document->find_any(
			sub {
				$_[1]->isa('PPI::Token') or return '';
				$_[1]->significant or return '';
				$_[1]->content =~ /[^\$\'\"]\$[\&\'\`]/ or return '';
				return 1;
			}
		);
		ok( $good, "$module: Uses expensive regexp-variable \$&, \$\' or \$`" );
	}

	# Check for method calls that don't exist
	SKIP: {
		if ( $module =~ /\bRole\b/ ) {
			skip( "Ignoring module $module", 1 );
		}
		if ( $module eq 'Padre::Autosave' ) {
			skip( 'Ignoring flaky ORLite usage in Padre::Autosave', 1 );
		}

		my $tokens = $document->find(
			sub {
				$_[1]->isa('PPI::Token::Word') or return '';
				_IDENTIFIER( $_[1]->content )  or return '';

				# Is it a method
				my $operator = $_[1]->sprevious_sibling or return '';
				$operator->isa('PPI::Token::Operator') or return '';
				$operator->content eq '->' or return '';

				# Get the method name
				my $object = $operator->sprevious_sibling or return '';
				$object->isa('PPI::Token::Symbol') or return '';
				$object->content eq '$self' or return '';

				return 1;
			}
		);

		# Filter the tokens to get the method list
		my %seen = ();
		my @bad  = ();
		if ($tokens) {
			@bad = grep { not $module->can($_) } grep { not $seen{$_} } map { $_->content } @$tokens;
		}

		# There should be no missing methods
		is( scalar(@bad), 0, 'No missing methods' );
		foreach my $method (@bad) {
			diag("$module: Cannot resolve method \$self->$method");
		}
	}

	# Check for superfluous $self->current->foo that could be $self->foo
	SKIP: {
		my %seen   = ();
		my $tokens = $document->find(
			sub {
				# Start with a candidate foo method name
				$_[1]->isa('PPI::Token::Word') or return '';
				my $method = $_[1]->content    or return '';
				_IDENTIFIER($method)           or return '';
				$seen{$method}++              and return '';
				Padre::Current->can($method)   or return '';
				$module->can($method)          or return '';

				# First method to the left
				my $rightop = $_[1]->sprevious_sibling or return '';
				$rightop->isa('PPI::Token::Operator')  or return '';
				$rightop->content eq '->'              or return '';

				# The ->current method call
				my $current = $rightop->sprevious_sibling or return '';
				$current->isa('PPI::Token::Word')      or return '';
				$current->content eq 'current'         or return '';

				# Second method to the left
				my $leftop = $current->sprevious_sibling or return '';
				$leftop->isa('PPI::Token::Operator')  or return '';
				$leftop->content eq '->'              or return '';

				# $self on the far left
				my $variable = $leftop->sprevious_sibling or return '';
				if ( $variable->isa('PPI::Token::Symbol') ) {
					$variable->content eq '$self' and return 1;
				}

				# Alternatively, $_[0] on the far left
				$variable->isa('PPI::Structure::Subscript') or return '';
				my $subscript = $variable;
				$subscript->content eq '[0]'                or return '';
				$variable  = $subscript->sprevious_sibling  or return '';
				$variable->isa('PPI::Token::Magic')         or return '';
				$variable->content eq '$_'                  or return '';
				$variable->sprevious_sibling               and return '';

				# In the form sub foo { $_[0]...
				my $statement = $variable->parent    or return '';
				$statement->isa('PPI::Statement')    or return '';
				my $block = $statement->parent       or return '';
				$block->isa('PPI::Structure::Block') or return '';
				my $sub = $block->parent             or return '';
				$sub->isa('PPI::Statement::Sub')     or return '';

				return 1;
			}
		);

		# Filter the tokens to get the method list
		my @bad = ();
		if ( $tokens ) {
			@bad = map { $_->content } @$tokens;
		}

		# There should be no superfluous methods
		is( scalar(@bad), 0, 'No ->current->superfluous methods' );
		foreach my $method (@bad) {
			diag("$module: Superfluous ->current->$method, use ->$method");
		}
	}

	# Check for Wx::wxFOO constants that should be Wx::FOO
	SKIP: {
		if ( $module eq 'Padre::Wx::Constant' ) {
			skip( "Ignoring module $module", 1 );
		}
		if ( $module eq 'Padre::Startup' ) {
			skip( "Ignoring module $module", 1 );
		}

		my %seen   = ();
		my $tokens = $document->find(
			sub {
				$_[1]->isa('PPI::Token::Word') or return '';
				$_[1]->content =~ /^Wx::wx([A-Z].+)/ or return '';

				# Is this a new one?
				my $name = $1;
				return '' if $seen{$name}++;

				# Does the original and shortened forms of the
				# constant actually exist?
				Wx->can("wx$name") or return '';
				Wx->can($name) or return '';

				# wxVERSION is a special case
				$name eq 'VERSION' and return '';

				return 1;
			}
		);

		# Filter for the constant list
		my @bad = ();
		if ($tokens) {
			@bad = map { $_->content } @$tokens;
		}

		# There should be no unconverted wxCONSTANTS
		is( scalar(@bad), 0, 'No uncoverted wxCONSTANTS' );
		foreach my $name (@bad) {
			diag("$module: Unconverted constant $name");
		}
	}

	# Don't make direct system calls, use a Padre API instead
	# SKIP: {
	# my $good = !$document->find_any('PPI::Token::QuoteLike::Command');
	# ok( $good, "$module: Makes direct system calls with qx" );
	# }
}

sub read_file {
	my $file = shift;
	open my $fh, '<', $file or die "Could not read '$file': $!";
	local $/ = undef;
	return <$fh>;
}

1;
