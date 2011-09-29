package Padre::Wx::Dialog::About;

use 5.008;
use strict;
use warnings;
use Config;
use Padre::Wx               ();
use Wx::Perl::ProcessStream ();
use Padre::Config           ();
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
	$self->set_up();

	# TODO but I want nonModal, ie $self->Show;
	# Show the dialog
	my $result = $self->ShowModal;

	if ( $result == Wx::ID_CANCEL ) {

		# As we leave the Find dialog, return the user to the current editor
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
# Method set_up
#######
sub set_up {
	my $self = shift;
	
	# Set the bitmap button icons, o why are we using a 293kb bmp !!!!
	# $self->{splash}->SetBitmap( Wx::Bitmap->new(Padre::Util::sharefile('padre-splash-ccnc.bmp'), Wx::BITMAP_TYPE_BMP) );
	# create a png only 196kb te-he
	$self->{splash}->SetBitmap( Wx::Bitmap->new(Padre::Util::sharefile('padre-splash.png'), Wx::BITMAP_TYPE_PNG) );

	my $off_set = 24;
	$self->{output}->AppendText("\n");

	$self->{output}->AppendText( sprintf "%${off_set}s %s\n", 'Padre', $VERSION );

	$self->{output}->AppendText("Core...\n");

	$self->{output}->AppendText( sprintf "%${off_set}s %s\n", $Config{osname}, $Config{archname} );

	# Yes, THIS variable should have this upper case char :-)
	my $perl_version = $^V || $];
	# $perl_version = "$perl_version";
	$perl_version =~ s/^v//;
	$self->{output}->AppendText( sprintf "%${off_set}s %s\n", 'Perl', $perl_version );

	# How many threads are running
	my $threads_text = Wx::gettext('Threads:');
	my $threads = $INC{'threads.pm'} ? scalar( threads->list ) : Wx::gettext('(disabled)');
	$self->{output}->AppendText( sprintf "%${off_set}s %s\n", 'Threads', $threads );

	# Calculate the current memory in use across all threads
	my $RAM_text = Wx::gettext('RAM:');
	my $ram = Padre::Util::humanbytes( Padre::Util::process_memory() ) || '0';
	$ram = Wx::gettext('(unsupported)') if $ram eq '0';
	$self->{output}->AppendText( sprintf "%${off_set}s %s\n", 'Ram', $ram );


	$self->{output}->AppendText("Wx...\n");

	$self->{output}->AppendText( sprintf "%${off_set}s %s\n", 'Wx', $Wx::VERSION );

	# Reformat the native wxWidgets version string slightly
	my $wx_widgets = Wx::wxVERSION_STRING();
	$wx_widgets =~ s/^wx\w+\s+//;
	$self->{output}->AppendText( sprintf "%${off_set}s %s\n", 'WxWidgets', $wx_widgets );

	eval { require Alien::wxWidgets };
	my $alien = $Alien::wxWidgets::VERSION;

	$self->{output}->AppendText( sprintf "%${off_set}s %s\n", 'Alien::wxWidgets', $alien );

	$self->{output}
		->AppendText( sprintf "%${off_set}s %s\n", 'Wx::Perl::ProcessStream', $Wx::Perl::ProcessStream::VERSION );

	$self->{output}->AppendText( sprintf "%${off_set}s %s\n", 'Wx::Scintilla', $Wx::Scintilla::VERSION );

	$self->{output}->AppendText("Other...\n");

	$self->{output}->AppendText( sprintf "%${off_set}s %s\n", 'PPI', $PPI::VERSION );

	my $config_dir_txt = Wx::gettext('Config:');
	my $config_dir     = Padre::Constant::CONFIG_DIR;
	$self->{output}->AppendText( sprintf "%${off_set}s %s\n", $config_dir_txt, $config_dir );

	return;
}


1;

__END__

=head1 NAME

Padre::Wx::Dialog::Patch
You will find more infomation in our L<wiki|http://padre.perlide.org/trac/wiki/Features/EditPatch/> pages.


=head1 DESCRIPTION

A very simplistic tool, only works on open saved files, in the Padre editor.

Patch a single file, in the editor with a patch/diff file that is also open.

Diff between two open files, the resulting patch file will be in Unified form.

Diff a single file to svn, only display files that are part of an SVN already, the resulting patch file will be in Unified form.

All results will be a new Tab.

=head1 METHODS

=head2 new

Constructor. Should be called with C<$main> by C<Patch::load_dialog_main()>.

=head2 run

C<run> configures the dialogue for your environment

=head2 set_up

C<set_up> configures the dialogue for your environment

=head2 on_action

Event handler for action, adjust dialogue accordingly

=head2 on_against

Event handler for against, adjust dialogue accordingly

=head2 process_clicked

Event handler for process_clicked, perform your chosen action, all results go into a new tab in editor.

=head2 current_files

extracts file info from Padre about all open files in editor

=head2 apply_patch

A convenience method to apply patch to chosen file.

uses Text::Patch

=head2 make_patch_diff

A convenience method to generate a patch/diff file from two selected files.

uses Text::Diff

=head2 test_svn

test for a local copy of svn in Path and version greater than 1.6.2.

=head2 make_patch_svn

A convenience method to generate a patch/diff file from a selected file and svn if applicable,
ie file has been checked out.

=head2 file2_list_type

composed method

=head2 filename_url

composed method

=head2 set_selection_file1

composed method

=head2 set_selection_file2

composed method

=head2 file1_list_svn

composed method

=head2 file2_list_patch

composed method

=head2 file_lists_saved

composed method

=head1 BUGS AND LIMITATIONS 

List Order is that of load order, if you move your Tabs the List Order will not follow suite.

If you have multiple files open with same name but with different paths only the first will get matched. 

=head1 AUTHORS

BOWTIE E<lt>kevin.dawson@btclick.comE<gt>

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2008-2011 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl 5 itself.

The full text of the license can be found in the
LICENSE file included with this module.

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
