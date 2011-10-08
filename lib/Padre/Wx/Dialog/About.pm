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

our $VERSION = '0.91';
our @ISA     = qw{
	Padre::Wx::FBP::About
};


#######
# new
#######
sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	# Always show the first tab regardless of which one
	# was selected in wxFormBuilder.
	$self->notebook->ChangeSelection(0);

	$self->CenterOnParent;

	$self->{action_request} = 'Patch';
	$self->{selection}      = 0;

	return $self;
}

#######
# Method run
#######
sub run {
	my $self    = shift;
	my $current = $self->current;

	# auto-fill dialogue
	$self->_set_up();

	# Show the dialog
	my $result = $self->ShowModal;

	if ( $result == Wx::ID_CANCEL ) {

		# As we leave the About dialog, return the user to the current editor
		# window so they don't need to click it.
		my $editor = $current->editor;
		$editor->SetFocus if $editor;

		# Clean up
		$self->Destroy;

		return;
	}

	return;
}

#######
# Method _set_up
#######
sub _set_up {
	my $self = shift;

	# load the image
	$self->{splash}->SetBitmap( Wx::Bitmap->new( Padre::Util::splash, Wx::BITMAP_TYPE_PNG ) );
	
	$self->creator->SetLabel(Wx::gettext('Gábor Szabó'));
	
	$self->_translation();
	
	$self->_system_info();

	return;
}

#######
# Composed Method _translation
#######
sub _translation {
	my $self = shift;
	
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

#######
# Composed Method _core_info
#######
sub _system_info {
	my $self = shift;
	
	$self->{off_set} = 24;

	$self->{output}->AppendText("\n");

	$self->{output}->AppendText( sprintf "%$self->{off_set}s %s\n", 'Padre', $VERSION );

	$self->_core_info();
	$self->_wx_info();

	$self->{output}->AppendText("Other...\n");

	$self->{output}->AppendText( sprintf "%$self->{off_set}s %s\n", 'PPI', $PPI::VERSION );

	my $config_dir_txt = Wx::gettext('Config:');
	my $config_dir     = Padre::Constant::CONFIG_DIR;
	$self->{output}->AppendText( sprintf "%$self->{off_set}s %s\n", $config_dir_txt, $config_dir );
	
	return;
}

#######
# Composed Method _core_info
#######
sub _core_info {
	my $self = shift;

	$self->{output}->AppendText("Core...\n");

	$self->{output}->AppendText( sprintf "%$self->{off_set}s %s\n", $Config{osname}, $Config{archname} );

	if ( $Config{osname} eq 'linux' ) {

		my $kernel = qx{uname -r};
		chomp($kernel);
		$self->{output}->AppendText( sprintf "%$self->{off_set}s %s\n", 'kernel', $kernel );

		my $description = qx{cat /etc/issue};
		chomp($description);
		$description =~ s/\\n \\l//;
		$self->{output}->AppendText( sprintf "%$self->{off_set}s %s", 'description', $description );
	}

	# Yes, THIS variable should have this upper case char :-)
	my $perl_version = $^V || $];

	# $perl_version = "$perl_version";
	$perl_version =~ s/^v//;
	$self->{output}->AppendText( sprintf "%$self->{off_set}s %s\n", 'Perl', $perl_version );

	# How many threads are running
	my $threads_text = Wx::gettext('Threads:');
	my $threads = $INC{'threads.pm'} ? scalar( threads->list ) : Wx::gettext('(disabled)');
	$self->{output}->AppendText( sprintf "%$self->{off_set}s %s\n", 'Threads', $threads );

	# Calculate the current memory in use across all threads
	my $RAM_text = Wx::gettext('RAM:');
	my $ram = Padre::Util::humanbytes( Padre::Util::process_memory() ) || '0';
	$ram = Wx::gettext('(unsupported)') if $ram eq '0';
	$self->{output}->AppendText( sprintf "%$self->{off_set}s %s\n", 'Ram', $ram );

	return;
}

#######
# Composed Method _wx_info
#######
sub _wx_info {
	my $self = shift;

	$self->{output}->AppendText("Wx...\n");

	$self->{output}->AppendText( sprintf "%$self->{off_set}s %s\n", 'Wx', $Wx::VERSION );


	# Reformat the native wxWidgets version string slightly
	my $wx_widgets = Wx::wxVERSION_STRING();
	$wx_widgets =~ s/^wx\w+\s+//;
	$self->{output}->AppendText( sprintf "%$self->{off_set}s %s\n", 'WxWidgets', $wx_widgets );

	$self->{output}->AppendText( sprintf "%$self->{off_set}s %s\n", 'unicode', Wx::wxUNICODE() );

	require Alien::wxWidgets;
	my $alien = $Alien::wxWidgets::VERSION;

	$self->{output}->AppendText( sprintf "%$self->{off_set}s %s\n", 'Alien::wxWidgets', $alien );

	$self->{output}
		->AppendText( sprintf "%$self->{off_set}s %s\n", 'Wx::Perl::ProcessStream', $Wx::Perl::ProcessStream::VERSION );

	$self->{output}->AppendText( sprintf "%$self->{off_set}s %s\n", 'Wx::Scintilla', $Wx::Scintilla::VERSION );

	return;
}




1;

__END__

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
