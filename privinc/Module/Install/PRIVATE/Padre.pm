package Module::Install::PRIVATE::Padre;

use 5.008;
use strict;
use warnings;
use Module::Install::Base;

use FindBin    ();
use File::Find ();

# For building the Win32 launcher
use Config;
use ExtUtils::Embed;

our $VERSION = '0.94';
use base qw{ Module::Install::Base };

sub setup_padre {
	my $self      = shift;
	my $inc_class = join( '::', @{ $self->_top }{ qw(prefix name) } );
	my $class     = __PACKAGE__;

	$self->postamble(<<"END_MAKEFILE");
# --- Padre section:

exe :: all
\t\$(NOECHO) \$(PERL) -Iprivinc "-M$inc_class" -e "make_exe()"

ppm :: ppd all
\t\$(NOECHO) tar czf Padre.tar.gz blib/

END_MAKEFILE


}

sub check_wx_version {
	# Check if Alien is installed
	my $alien_file = _module_file('Alien::wxWidgets');
	my $alien_path = _file_path($alien_file);
	unless ( $alien_path ) {
		# Alien::wxWidgets.pm is not installed.
		# Allow EU:MM to do it's thing as normal
		# but give some extra hints to the user
		warn "** Could not locate Alien::wxWidgets\n";
		warn "** When installing it please make sure wxWidgets is compiled with Unicode enabled\n";
		warn "** Please use the latest version from CPAN\n";
		return;
	}

	# Do we have the alien package
	eval {
		require Alien::wxWidgets;
		Alien::wxWidgets->import;
	};
	if ( $@ ) {
		# If we don't have the alien package,
		# we should just pass through to EU:MM
		warn "** Could not locate Alien::wxWidgets\n";
		warn "** When installing it please make sure wxWidgets is compiled with Unicode enabled\n";
		warn "** Please use the latest version from CPAN\n";
		return;
	}

	# Find the wxWidgets version from the alien
	my $widgets = Alien::wxWidgets->version;
	unless ( $widgets ) {
		nono("Alien::wxWidgets was unable to determine the wxWidgets version");
	}
	my $widgets_human = $widgets;
	$widgets_human =~ s/^(\d\.\d\d\d)(\d\d\d)$/$1.$2/;
	$widgets_human =~ s/\.0*/./g;
	print "Found wxWidgets $widgets_human\n";
	unless ( $widgets >= 2.008008 or $ENV{SKIP_WXWIDGETS_VERSION_CHECK} ) {
		nono("Padre needs at least version 2.8.8 of wxWidgets. You have wxWidgets $widgets_human");
	}

	
	# Can we find Wx.pm
	my $wx_file = _module_file('Wx');
	my $wx_path = _file_path($wx_file);
	unless ( $wx_path ) {
		# Wx.pm is not installed.
		# Allow EU:MM to do it's thing as normal
		# but give extra hints to the user
		warn "** Could not locate Wx.pm\n";
		warn "** Please install the latest version from CPAN\n";
		return;
	}
	my $wx_pm = _path_version($wx_path);
	print "Found Wx.pm     $wx_pm\n";
	if ($wx_pm < 0.97 && $wx_pm > 0.94) {
		warn "** Wx.pm version $wx_pm has problems with HTML rendering\n";
		warn "** You can use it to run Padre, but the help documents may not be displayed correctly.\n";
		warn "** Consider installing the latest version from CPAN\n";
	}

	# this part still needs the DISPLAY 
	# so check only if there is one
	if ( $ENV{DISPLAY} or $^O =~ /win32/i ) {
		eval {
			require Wx;
			Wx->import;
		};
		if ($@) {
			# If we don't have the Wx installed,
			# we should just pass through to EU:MM
			warn "** Could not locate Wx.pm\n";
			warn "** Please install the latest version from CPAN\n";
			return;
		}
		unless ( Wx::wxUNICODE() ) {
			nono("Padre needs wxWidgest to be compiled with Unicode support (--enable-unicode)");
		}
	}

	return;
}

sub nono {
	my $msg = shift;
	print STDERR "$msg\n";
	exit(1);
}

sub make_exe {
	my $self = shift;

	# temporary tool to create executable using PAR
	eval "use Module::ScanDeps 0.93; 1;" or die $@;
	#eval "use PAR::Packer 0.993; 1;" or die $@;

	my @libs    = get_libs();
	my @modules = get_modules();
	my $exe	 = $^O =~ /win32/i ? 'padre.exe' : 'padre';
	if ( -e $exe ) {
		unlink $exe or die "Cannot remove '$exe' $!";
	}
	my @cmd	= ( 'pp', '--cachedeps', 'pp_cached_dependencies', '--reusable', '-o', $exe, qw{ -I lib script/padre } );
	push @cmd, @modules;
	push @cmd, @libs;
	if ( $^O =~ /win32/i ) {
		push @cmd, '-M', 'Tie::Hash::NamedCapture';
	}

	#TODO Padre::DB::Migrate was moved to ORLite::Migrate. Keep or remove? (AZAWAWI)
	## push @cmd, '-M', 'Padre::DB::Migrate::Patch';

	print join( ' ', @cmd ) . "\n";
	system(@cmd);

	return;
}

sub get_libs {
	# Run-time "use" the Alien module
	require Alien::wxWidgets;
	Alien::wxWidgets->import;

	# Extract the settings we need from the Alient
	my $prefix = Alien::wxWidgets->prefix;
	my %libs   = map { ($_, 0) } Alien::wxWidgets->shared_libraries(
		qw(stc xrc html adv core base) 
	);

	require File::Find;
	File::Find::find(
		sub {
			if ( exists $libs{$_} ) {
				$libs{$_} = $File::Find::name;
			}
		},
		$prefix
	);

	my @missing = grep { ! $libs{$_} } keys %libs;
	foreach ( @missing ) {
		warn("Could not find shared library on disk for $_");
	}

	return map { ('-l', $_) } values %libs;
}

sub get_modules {
	my @modules;
	my @files;
	open(my $fh, '<', 'MANIFEST') or
		die("Do you need to run 'make manifest'? Could not open MANIFEST for reading: $!");
	while ( my $line = <$fh> ) {
		chomp $line;
		if ( $line =~ m{^lib/.*\.pm$} ) {
			$line = substr($line, 4, -3);
			$line =~ s{/}{::}g;
			push @modules, $line;
		}
		if ( $line =~ m{^lib/.*\.pod$} ) {
			push @files, $line;
		}
		if ( $line =~ m{^share/} ) {
			(my $newpath = $line) =~ s{^share}{lib/auto/share/dist/Padre};
			push @files, "$line;$newpath";
		}
	}

	my @args;
	push @args, "-M", $_ for @modules;
	push @args, "-a", $_ for @files;
	return @args;
}

sub _module_file {
	my $module = shift;
	$module =~ s/::/\//g;
	$module .= '.pm';
	return $module;
}

sub _file_path {
	my $file  = shift;
	my @found = grep { -f $_ } map { "$_/$file" } @INC;
	return $found[0];
}

sub _path_version {
	require ExtUtils::MM_Unix;
	ExtUtils::MM_Unix->parse_version($_[0]);
}

sub show_debuginfo {
	my $self      = shift;

	$self->postamble(<<"END_MAKEFILE");
# --- Padre section:

versioninfo ::
\t\$(NOECHO) \$(PERL) -MWx -MWx::Perl::ProcessStream -le 'print "Perl \$\$^V"; print "Wx ".\$\$Wx::VERSION; print Wx::wxVERSION_STRING(); print "ProcessStream ".\$\$Wx::Perl::ProcessStream::VERSION;'

END_MAKEFILE

}

sub _slurp {
	my $file = shift;
	open my $fh, '<', $file or die "Could not slurp $file\n";
	binmode $fh;
	local $/ = undef;
	my $content = <$fh>;
	close $fh;
	return $content;
}

sub _patch_version {
	my ($self, $file) = @_;

	# Patch the Padre version and the win32-comma-separated version
	if(open my $fh, '>', $file) {
		my $output = _slurp("$file.in");
		my $version = $self->version;
		my $win32_version = $version;
		$win32_version =~ s/\./,/;
		$output =~ s/__PADRE_WIN32_VERSION__/$win32_version,0,0/g;
		$output =~ s/__PADRE_VERSION__/$version/g;
		print $fh $output;
		close $fh;
	} else {
		die "Could not open $file for writing\n";
	}
}

#
# Builds Padre.exe using gcc
#
sub build_padre_exe {
	my $self = shift;

	print "Building padre.exe\n";

	# source folder
	my $src = "win32";
	my $bin = "blib/bin";

	# Create the blib/bin folder
	system $^X , qw[-MExtUtils::Command -e mkpath --], $bin;

	# Step 1: Make sure we do not have old files
	my @temp_files = map {"$src/$_"} qw[ padre.exe.manifest padre-rc.rc padre-rc.res perlxsi.c ];
	map { unlink } (grep { -f } @temp_files);

	# Step 2: Patch the Padre version number in the win32 executable's manifest
	# and resource version info
	$self->_patch_version('win32/padre.exe.manifest');
	$self->_patch_version('win32/padre-rc.rc');

	# Step 3: Build Padre's win32 resource using windres
	system qq[cd $src && windres --input padre-rc.rc --output padre-rc.res --output-format=coff];

	# Step 4: Generate xs_init() function for static libraries
	xsinit("$src/perlxsi.c", 0);

	# Step 5: Build padre.exe using $Config{cc}
	system "cd $src && $Config{cc} -mwin32 -mwindows -Wl,-s padre.c perlxsi.c padre-rc.res -o ../$bin/padre.exe ".ccopts.ldopts;

	# Step 6: Remove temporary files
	map { unlink } (grep { -f } @temp_files);
}

1;
