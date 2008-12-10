package Module::Install::PRIVATE::Padre;
use strict;
use warnings;
use Module::Install::Base;

use FindBin ();
use File::Spec;
use File::Find ();

our @ISA = qw(Module::Install::Base);
our $VERSION = '0.20';

sub setup_padre {
	my $self = shift;
	my $inc_class = join('::', @{$self->_top}{qw(prefix name)});
	my $class = __PACKAGE__;

	$self->postamble(<<"END_MAKEFILE");
# --- Padre section:

exe :: all
\t\$(NOECHO) \$(PERL) -Iprivinc "-M$inc_class" -e "make_exe()"

END_MAKEFILE

}

sub check_wx_version {
	# Missing Wx should be dealt by the standard prereq system
	eval { require Wx };
	return if $@;

	my $version = Wx::wxVERSION_STRING();
	nono("Could not find Wx::wxVERSION_STRING") if not defined $version;

	print "Found $version\n";
	print "Found Wx.pm     $Wx::VERSION\n";
	$version =~ s/wxWidgets\s+//;
	nono("Sorry we don't known this wxWidgets version format: '$version'")
	  if $version !~ /^\d+\.\d+(\.\d+)?$/;
	my ($major, $minor, $way_too_minor) = split /\./, $version;
	nono("Padre needs at least version 2.8.8 of wxWidgets. this is version $version")
	  if $major < 2 or $minor < 8;

	return;
}

sub nono {
	my $msg = shift;
	print STDERR "$msg\n";
	exit 0;
}


sub make_exe {
	my $self = shift;

	# temporary tool to create executable using PAR
	eval "use Module::ScanDeps 0.88; 1;" or die $@;

	my @libs	= get_libs();
	my @modules = get_modules();
	my $exe	 = $^O =~ /win32/i ? 'padre.exe' : 'padre';
	if (-e $exe) {
		unlink $exe or die "Cannot remove '$exe' $!";
	}
	my @cmd	 = ('pp', '-o', $exe, qw(-I lib script/padre));
	push @cmd, @modules, @libs;
	if ($^O =~ /win32/i) {
		push @cmd, '-M', 'Tie::Hash::NamedCapture';
	}

	print "@cmd\n";
	system(@cmd);

	return;
}


sub get_libs {
	require Alien::wxWidgets;
	Alien::wxWidgets->import(); # needed to make it work
	require File::Find;
	my @libs = Alien::wxWidgets->shared_libraries(
	  qw(stc xrc html adv core base) 
	);

# formerly, we needed to put the libs verbatim:
#	qw(
#				libwx_gtk2_adv-2.8.so.0
#				libwx_gtk2_core-2.8.so.0
#				libwx_base-2.8.so.0
#				libwx_base_net-2.8.so.0
#				libwx_gtk2_stc-2.8.so.0
#				libwx_gtk2_html-2.8.so.0
#	);

	my %libs = map {($_,0)} @libs;
	my $prefix = Alien::wxWidgets->prefix;
	
	File::Find::find(
	  sub {
		  if (exists $libs{$_}) {
			$libs{$_} = $File::Find::name;
		  }
	  },
	  $prefix
	);

	my @missing = grep {!$libs{$_}} keys %libs;
	warn "Could not find shared library on disk for $_"
	  for @missing;

	my @libs_args;
	push @libs_args, "-l", $_ for values %libs;

	return @libs_args;
}


sub get_modules {

	my @modules;
	my @files;

	open my $fh, '<', 'MANIFEST' or die "Do you need to run 'make manifest'? Could not open MANIFEST for reading: $!";
	while (my $line = <$fh>) {
		chomp $line;
		if ($line =~ m{^lib/}) {
			$line = substr($line, 4, -3);
			$line =~ s{/}{::}g;
			push @modules, $line;
		}
		if ($line =~ m{^share/}) {
			push @files, $line;
		}
	}
	my @args;
	push @args, "-M", $_ for @modules;
	push @args, "-a", $_ for @files;

	return @args;
}





1;
