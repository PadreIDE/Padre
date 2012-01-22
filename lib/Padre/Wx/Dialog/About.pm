package Padre::Wx::Dialog::About;

use 5.008;
use strict;
use warnings;
use utf8;
use Config;
use Padre::Wx               ();
use Wx::Perl::ProcessStream ();
use Padre::Util             ();
use PPI                     ();
use Padre::Wx::FBP::About   ();

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Wx::FBP::About
};

use constant {
	OFFSET => 24,
};

sub run {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	
	# Always show the first tab regardless of which one
	# was selected in wxFormBuilder.
	$self->notebook->ChangeSelection(0);

	# Load the platform-adaptive splash image
	$self->{splash}->SetBitmap( Wx::Bitmap->new( Padre::Util::splash, Wx::BITMAP_TYPE_PNG ) );
	# $self->creator->SetLabel("G\x{e1}bor Szab\x{f3}"); # don't work
	$self->creator->SetLabel('Created by Gábor Szabó'); # works
	
	# Set the system information
	$self->{output}->ChangeValue( $self->_information );

	# Set the translators
	$self->_translation;

	$self->CenterOnParent;
	
	# Show the dialog
	$self->ShowModal;

	# As we leave the About dialog, return the user to the current editor
	# window so they don't need to click it.
	$self->main->editor_focus;
	$self->Destroy;
}

sub _translation {
	my $self = shift;

	#TODO will all translators please add there name
	# in native language please and uncommet please

	$self->ahmad_zawawi->SetLabel('أحمد محمد زواوي');

	# $self->fayland_lam->SetLabel('');
	# $self->chuanren_wu->SetLabel('');
	$self->matthew_lien->SetLabel('練喆明');


	$self->marcela_maslanova->SetLabel('Marcela Mašláňová');

	# $self->dirk_de_nijs->SetLabel('');
	$self->jerome_quelin->SetLabel('Jérôme Quelin');
	$self->olivier_mengue->SetLabel('Olivier Mengué');


	# $self->heiko_jansen->SetLabel('');
	# $self->sebastian_willing->SetLabel('');
	# $self->zeno_gantner->SetLabel('');
	$self->omer_zak->SetLabel('עומר זק');
	$self->shlomi_fish->SetLabel('שלומי פיש');
	$self->amir_e_aharoni->SetLabel('אמיר א. אהרוני');
	$self->gyorgy_pasztor->SetLabel('György Pásztor');

	# $self->simone_blandino->SetLabel('');
	$self->kenichi_ishigaki->SetLabel('石垣憲');
	$self->keedi_kim->SetLabel('김도형');

	# $self->kjetil_skotheim->SetLabel('');
	# $self->cezary_morga->SetLabel('');
	# $self->breno_g_de_oliveira->SetLabel('');
	# $self->gabriel_vieira->SetLabel('');


	# $self->paco_alguacil->SetLabel('');
	# $self->enrique_nell->SetLabel('');
	# $self->andrew_shitov->SetLabel('');
	$self->burak_gursoy->SetLabel('Burak Gürsoy');

	return;
}

sub _information {
	my $self   = shift;
	my $output = "\n";
	$output .= sprintf "%*s %s\n", OFFSET, 'Padre', $VERSION;
	$output .= $self->_core_info;
	$output .= $self->_wx_info;
	$output .= "Other...\n";
	$output .= sprintf "%*s %s\n", OFFSET, 'PPI',   $PPI::VERSION;
	
	require Debug::Client;
	$output .= sprintf "%*s %s\n", OFFSET, 'Debug::Client', $Debug::Client::VERSION;
	
	$output .= sprintf "%*s %s\n", OFFSET, Wx::gettext('Config'), Padre::Constant::CONFIG_DIR;
	return $output;
}

sub _core_info {
	my $self = shift;

	my $output = "Core...\n";

	# Do not translate those labels
	$output .= sprintf "%*s %s\n", OFFSET, "osname",   $Config{osname};
	$output .= sprintf "%*s %s\n", OFFSET, "archname", $Config{archname};

	if ( $Config{osname} eq 'linux' ) {

		my $distro = qx{cat /etc/issue};
		chomp($distro);
		$distro =~ s/\\n \\l//g;
		$distro =~ s/\x0A//g;
		$output .= sprintf "%*s %s\n", OFFSET, Wx::gettext('Distribution'), $distro;

		# Do we really care for Padre?
		my $kernel = qx{uname -r};
		chomp($kernel);
		$output .= sprintf "%*s %s\n", OFFSET, Wx::gettext('Kernel'), $kernel;
	}

	# Yes, THIS variable should have this upper case char :-)
	my $perl_version = $^V || $];
	$perl_version =~ s/^v//;
	$output .= sprintf "%*s %s\n", OFFSET, 'Perl', $perl_version;

	# How many threads are running
	my $threads = $INC{'threads.pm'} ? scalar( threads->list ) : Wx::gettext('(disabled)');
	$output .= sprintf "%*s %s\n", OFFSET, Wx::gettext('Threads'), $threads;

	# Calculate the current memory in use across all threads
	my $ram = Padre::Util::process_memory();
	$ram = $ram ? Padre::Util::humanbytes($ram) : Wx::gettext('(unsupported)');
	$output .= sprintf "%*s %s\n", OFFSET, Wx::gettext("RAM"), $ram;

	return $output;
}

sub _wx_info {
	my $self = shift;

	my $output = "Wx...\n";
	$output .= sprintf "%*s %s\n", OFFSET, 'Wx', $Wx::VERSION;

	# Reformat the native wxWidgets version string slightly
	my $wx_widgets = Wx::wxVERSION_STRING();
	$wx_widgets =~ s/^wx\w+\s+//;
	$output .= sprintf "%*s %s\n", OFFSET, 'WxWidgets', $wx_widgets;
	$output .= sprintf "%*s %s\n", OFFSET, 'unicode',   Wx::wxUNICODE();

	require Alien::wxWidgets;
	$output .= sprintf "%*s %s\n", OFFSET, 'Alien::wxWidgets', $Alien::wxWidgets::VERSION;

	$output .= sprintf "%*s %s\n", OFFSET, 'Wx::Perl::ProcessStream', $Wx::Perl::ProcessStream::VERSION;

	require Wx::Scintilla;
	$output .= sprintf "%*s %s\n", OFFSET, 'Wx::Scintilla', $Wx::Scintilla::VERSION;

	return $output;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
