package t::lib::Padre::Win32;

use strict;
use warnings;
use Padre::Perl ();

sub setup {
	require Win32::GuiTest;
	import Win32::GuiTest qw{
		FindWindowLike
		SetForegroundWindow
		GetForegroundWindow
	};

	my %existing_windows = map { $_ => 1 } FindWindowLike(0, "^Padre");

	# Find Perl (ideally the gui one)
	my $perl = Padre::Perl::wperl();
	my $cmd  = "start $perl script\\padre";
	#$t->diag($cmd);
	system $cmd;
	my $padre;

	# allow some time to launch Padre
	foreach ( 1 .. 10 ) {
		sleep(1);
		my @current_windows = FindWindowLike(0, "^Padre");
		my @wins = grep { ! $existing_windows{$_} } @current_windows;
		die "Too many Padres found '@wins'" if @wins > 1;
		$padre = shift @wins;
		last if $padre;
	}
	die "Could not find Padre" if not $padre;

	SetForegroundWindow($padre);
	sleep 3; # crap, we have to wait for Padre to come to the foreground
	my $fg = GetForegroundWindow();
	if ( $fg ne $padre ) {
		die "Padre is NOT in the foreground";
	}

	return $padre;
}

1;
