package Padre::Wx::Dialog::Patch;

use 5.008;
use strict;
use warnings;
use Padre::Util           ();
use Padre::Wx             ();
use Padre::Wx::FBP::Patch ();
use Padre::Logger;

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Wx::FBP::Patch
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
	my $self = shift;

	# auto-fill dialogue
	$self->set_up;

	# TODO but I want nonModal, ie $self->Show;
	# Show the dialog
	my $result = $self->ShowModal;
	if ( $result == Wx::ID_CANCEL ) {

		# As we leave the Find dialog, return the user to the current editor
		# window so they don't need to click it.
		$self->main->editor_focus;
		$self->Destroy;
	}

	return;
}

#######
# Method set_up
#######
sub set_up {
	my $self = shift;

	# test for local svn_local
	$self->test_svn();

	# generate open file bucket
	$self->current_files();

	# display default saved file lists
	$self->file_lists_saved();

	# display correct file-2 list
	$self->file2_list_type();

	$self->against->SetSelection(0);

	return;
}

#######
# Event Handler process_clicked
#######
sub process_clicked {
	my $self = shift;

	my $file1 = @{ $self->{file1_list_ref} }[ $self->file1->GetSelection() ];
	my $file2 = @{ $self->{file2_list_ref} }[ $self->file2->GetCurrentSelection() ];

	TRACE( '$self->file1->GetSelection(): ' . $self->file1->GetSelection() )               if DEBUG;
	TRACE( '$file1: ' . $file1 )                                                           if DEBUG;
	TRACE( '$self->file2->GetCurrentSelection(): ' . $self->file2->GetCurrentSelection() ) if DEBUG;
	TRACE( '$file2: ' . $file2 )                                                           if DEBUG;
	TRACE( $self->action->GetStringSelection() )                                           if DEBUG;

	if ( $self->action->GetStringSelection() eq 'Patch' ) {
		$self->apply_patch( $file1, $file2 );
	}

	if ( $self->action->GetStringSelection() eq 'Diff' ) {
		if ( $self->against->GetStringSelection() eq 'File-2' ) {
			$self->make_patch_diff( $file1, $file2 );
		} elsif ( $self->against->GetStringSelection() eq 'SVN' ) {
			$self->make_patch_svn($file1);
		}
	}

	# reset dialogue's display information
	$self->set_up;

	return;
}

#######
# Event Handler on_action
#######
sub on_action {
	my $self = shift;

	# re-generate open file bucket
	$self->current_files();

	if ( $self->action->GetStringSelection() eq 'Patch' ) {

		$self->{action_request} = 'Patch';
		$self->set_up;
		$self->against->Enable(0);
		$self->file2->Enable(1);
	} else {

		$self->{action_request} = 'Diff';
		$self->set_up;
		$self->against->Enable(1);
		$self->file2->Enable(1);

		# as we can not added items to a radio-box,
		# we can only enable & disable when radio-box enabled
		unless ( $self->{svn_local} ) {
			$self->against->EnableItem( 1, 0 );
		}
		$self->against->SetSelection(0);

	}
	return;
}

#######
# Event Handler on_against
#######
sub on_against {
	my $self = shift;

	if ( $self->against->GetStringSelection() eq 'File-2' ) {

		# show saved files only
		$self->file2->Enable(1);
		$self->file_lists_saved();

	} elsif ( $self->against->GetStringSelection() eq 'SVN' ) {

		# SVN only display files that are part of a SVN
		$self->file2->Enable(0);
		$self->file1_list_svn();
	}

	return;
}

#######
# Method current_files
#######
sub current_files {
	my $self     = shift;
	my $main     = $self->main;
	my $current  = $main->current;
	my $notebook = $current->notebook;
	my @label    = $notebook->labels;

	# get last element # not size
	$self->{tab_cardinality} = $#label;

	# thanks Alias
	my @file_vcs = map { $_->project->vcs } $self->main->documents;

	# create a bucket for open file info, as only a current file bucket exist
	for ( 0 .. $self->{tab_cardinality} ) {
		$self->{open_file_info}->{$_} = (
			{   'index'    => $_,
				'URL'      => $label[$_][1],
				'filename' => $notebook->GetPageText($_),
				'changed'  => 0,
				'vcs'      => $file_vcs[$_],
			},
		);

		if ( $notebook->GetPageText($_) =~ /^\*/sxm ) {
			TRACE("Found an unsaved file, will ignore: $notebook->GetPageText($_)") if DEBUG;
			$self->{open_file_info}->{$_}->{'changed'} = 1;
		}
	}

	return;
}

#######
# Composed Method file2_list_type
#######
sub file2_list_type {
	my $self = shift;

	if ( $self->{action_request} eq 'Patch' ) {

		# update File-2 = *.patch
		$self->file2_list_patch();
	} else {

		# File-1 = File-2 = saved files
		$self->file_lists_saved();
	}

	return;
}

#######
# Composed Method file_lists_saved
#######
sub file_lists_saved {
	my $self = shift;
	my @file_lists_saved;
	for ( 0 .. $self->{tab_cardinality} ) {
		unless ( $self->{open_file_info}->{$_}->{'changed'}
			|| $self->{open_file_info}->{$_}->{'filename'} =~ /(patch|diff)$/sxm )
		{
			push @file_lists_saved, $self->{open_file_info}->{$_}->{'filename'};
		}
	}

	TRACE("file_lists_saved: @file_lists_saved") if DEBUG;

	$self->file1->Clear;
	$self->file1->Append( \@file_lists_saved );
	$self->{file1_list_ref} = \@file_lists_saved;
	$self->set_selection_file1();
	$self->file1->SetSelection( $self->{selection} );

	$self->file2->Clear;
	$self->file2->Append( \@file_lists_saved );
	$self->{file2_list_ref} = \@file_lists_saved;
	$self->set_selection_file2();
	$self->file2->SetSelection( $self->{selection} );

	return;
}

#######
# Composed Method file2_list_patch
#######
sub file2_list_patch {
	my $self = shift;

	my @file2_list_patch;
	for ( 0 .. $self->{tab_cardinality} ) {
		if ( $self->{open_file_info}->{$_}->{'filename'} =~ /(patch|diff)$/sxm ) {
			push @file2_list_patch, $self->{open_file_info}->{$_}->{'filename'};
		}
	}

	TRACE("file2_list_patch: @file2_list_patch") if DEBUG;

	$self->file2->Clear;
	$self->file2->Append( \@file2_list_patch );
	$self->{file2_list_ref} = \@file2_list_patch;
	$self->set_selection_file2();
	$self->file2->SetSelection( $self->{selection} );

	return;
}

#######
# Composed Method file1_list_svn
#######
sub file1_list_svn {
	my $self = shift;

	@{ $self->{file1_list_ref} } = ();
	for ( 0 .. $self->{tab_cardinality} ) {
		if (   ( $self->{open_file_info}->{$_}->{'vcs'} eq 'SVN' )
			&& !( $self->{open_file_info}->{$_}->{'changed'} )
			&& !( $self->{open_file_info}->{$_}->{'filename'} =~ /(patch|diff)$/sxm ) )
		{
			push @{ $self->{file1_list_ref} }, $self->{open_file_info}->{$_}->{'filename'};
		}
	}

	TRACE("file1_list_svn: @{ $self->{file1_list_ref} }") if DEBUG;

	$self->file1->Clear;
	$self->file1->Append( $self->{file1_list_ref} );
	$self->set_selection_file1();
	$self->file1->SetSelection( $self->{selection} );

	return;
}

#######
# Composed Method set_selection_file1
#######
sub set_selection_file1 {
	my $self = shift;
	my $main = $self->main;

	$self->{selection} = 0;
	if ( $main->current->title =~ /(patch|diff)$/sxm ) {

		my @pathch_target = split( /\./, $main->current->title, 2 );

		# TODO this is a padre internal issue
		# remove obtuse leading space if exists
		$pathch_target[0] =~ s/^\p{Space}{1}//;
		TRACE("Looking for File-1 to apply a patch to: $pathch_target[0]") if DEBUG;

		# SetSelection should be Patch target file
		foreach ( 0 .. $#{ $self->{file1_list_ref} } ) {

			# add optional leading space \p{Space}?
			if ( @{ $self->{file1_list_ref} }[$_] =~ /^\p{Space}?$pathch_target[0]/ ) {
				$self->{selection} = $_;
				return;
			}
		}
	} else {

		# SetSelection should be current file
		foreach ( 0 .. $#{ $self->{file1_list_ref} } ) {

			if ( @{ $self->{file1_list_ref} }[$_] eq $main->current->title ) {
				$self->{selection} = $_;
				return;
			}
		}
	}

	return;
}

#######
# Composed Method set_selection_file2
#######
sub set_selection_file2 {
	my $self = shift;
	my $main = $self->main;

	$self->{selection} = 0;

	# SetSelection should be current file
	foreach ( 0 .. $#{ $self->{file2_list_ref} } ) {

		if ( @{ $self->{file2_list_ref} }[$_] eq $main->current->title ) {
			$self->{selection} = $_;
			return;
		}
	}

	return;
}

#######
# Composed Method filename_url
#######
sub filename_url {
	my $self     = shift;
	my $filename = shift;

	# given tab name get url of file
	for ( 0 .. $self->{tab_cardinality} ) {
		if ( $self->{open_file_info}->{$_}->{'filename'} eq $filename ) {
			return $self->{open_file_info}->{$_}->{'URL'};
		}
	}
	return;
}

########
# Method apply_patch
########
sub apply_patch {
	my $self       = shift;
	my $file1_name = shift;
	my $file2_name = shift;
	my $main       = $self->main;

	$main->show_output(1);
	my $output = $main->output;
	$output->clear;

	my ( $source, $diff );

	my $file1_url = $self->filename_url($file1_name);
	my $file2_url = $self->filename_url($file2_name);

	if ( -e $file1_url ) {
		TRACE("found file1 => $file1_name: $file1_url") if DEBUG;
		$source = Padre::Util::slurp($file1_url);
	}

	if ( -e $file2_url ) {
		TRACE("found file2 => $file2_name: $file2_url") if DEBUG;
		$diff = Padre::Util::slurp($file2_url);
		unless ( $file2_url =~ /(patch|diff)$/sxm ) {
			$main->info( Wx::gettext('Patch file should end in .patch or .diff, you should reselect & try again') );
			return;
		}
	}

	if ( -e $file1_url && -e $file2_url ) {

		require Text::Patch;
		my $our_patch;
		if ( eval { $our_patch = Text::Patch::patch( $source, $diff, { STYLE => 'Unified' } ) } ) {

			TRACE($our_patch) if DEBUG;

			# Open the patched file as a new file
			$main->new_document_from_string( $our_patch => 'application/x-perl', );
			$main->info( Wx::gettext('Patch successful, you should see a new tab in editor called Unsaved #') );
		} else {
			TRACE("error trying to patch: $@") if DEBUG;

			$output->AppendText("Patch Dialog failed to Complete.\n");
			$output->AppendText("Your requested Action Patch, with following parameters.\n");
			$output->AppendText("File-1: $file1_url \n");
			$output->AppendText("File-2: $file2_url \n");
			$output->AppendText("What follows is the error I received from Text::Patch::patch, if any: \n");
			$output->AppendText($@);

			$main->info(
				Wx::gettext('Sorry, patch failed, are you sure your choice of files was correct for this action') );
			return;
		}
	}

	return;
}

#######
# Method make_patch_diff
#######
sub make_patch_diff {
	my $self       = shift;
	my $file1_name = shift;
	my $file2_name = shift;
	my $main       = $self->main;

	$main->show_output(1);
	my $output = $main->output;
	$output->clear;

	my $file1_url = $self->filename_url($file1_name);
	my $file2_url = $self->filename_url($file2_name);

	if ( -e $file1_url ) {
		TRACE("found file1 => $file1_name: $file1_url") if DEBUG;
	}

	if ( -e $file2_url ) {
		TRACE("found file2 => $file2_name: $file2_url") if DEBUG;
	}

	if ( -e $file1_url && -e $file2_url ) {
		require Text::Diff;
		my $our_diff;
		if ( eval { $our_diff = Text::Diff::diff( $file1_url, $file2_url, { STYLE => 'Unified' } ) } ) {
			TRACE($our_diff) if DEBUG;

			my $patch_file = $file1_url . '.patch';
			open( my $fh, '>', $patch_file ) or die "open: $!";
			print $fh $our_diff;
			close $fh;
			TRACE("writing file: $patch_file") if DEBUG;

			$main->setup_editor($patch_file);
			$main->info( sprintf(Wx::gettext('Diff successful, you should see a new tab in editor called %s'), $patch_file) );
		} else {
			TRACE("error trying to patch: $@") if DEBUG;

			$output->AppendText("Patch Dialog failed to Complete.\n");
			$output->AppendText("Your requested Action Diff, with following parameters.\n");
			$output->AppendText("File-1: $file1_url \n");
			$output->AppendText("File-2: $file2_url \n");
			$output->AppendText("What follows is the error I received from Text::Diff::diff, if any: \n");
			$output->AppendText($@);

			$main->info(
				Wx::gettext('Sorry Diff Failed, are you sure your choice of files was correct for this action') );
			return;
		}
	}

	return;
}

#######
# Composed Method test_svn
#######
sub test_svn {
	my $self = shift;
	my $main = $self->main;

	$self->{svn_local} = 0;

	my $svn_client_version   = 0;
	my $required_svn_version = '1.6.2';

	if ( File::Which::which('svn') ) {

		# test svn version
		$svn_client_version = Padre::Util::run_in_directory_two('svn --version --quiet');
		if ( $svn_client_version ) {
			chomp $svn_client_version;

			require Sort::Versions;

			# This is so much better, now we are testing for version as well
			if ( Sort::Versions::versioncmp( $required_svn_version, $svn_client_version, ) == -1 ) {
				TRACE("Found local SVN v$svn_client_version, good to go.") if DEBUG;
				$self->{svn_local} = 1;
				return;
			} else {
				TRACE("Found SVN v$svn_client_version but require v$required_svn_version") if DEBUG;
				$main->info(
					sprintf(
						Wx::gettext('Warning: found SVN v%s but we require SVN v%s and it is now called "Apache Subversion"'),
						$svn_client_version,
						$required_svn_version
					)
				);
			}
		}
	}
	return;
}

#######
# Method make_patch_svn
# inspired by P-P-SVN
#######
sub make_patch_svn {
	my $self       = shift;
	my $file1_name = shift;
	my $main       = $self->main;

	$main->show_output(1);
	my $output = $main->output;
	$output->clear;

	my $file1_url = $self->filename_url($file1_name);

	TRACE("file1_url to svn: $file1_url") if DEBUG;

	# if (test_svn) {
	if ( $self->{svn_local} ) {
		TRACE('found local SVN, Good to go') if DEBUG;
		my $diff_str;
		if ( eval { $diff_str = qx{ svn diff $file1_url} } ) {

			TRACE($diff_str) if DEBUG;

			my $patch_file = $file1_url . '.patch';
			open( my $fh, '>', $patch_file ) or die "open: $!";
			print $fh $diff_str;
			close $fh;
			TRACE("writing file: $patch_file") if DEBUG;

			$main->setup_editor($patch_file);
			$main->info( sprintf(Wx::gettext('SVN Diff successful. You should see a new tab in editor called %s.'), $patch_file) );
		} else {
			TRACE("Error trying to get an SVN Diff: $@") if DEBUG;

			$output->AppendText("Patch Dialog failed to Complete.\n");
			$output->AppendText("Your requested Action Diff against SVN, with following parameters.\n");
			$output->AppendText("File-1: $file1_url \n");
			$output->AppendText("What follows is the error I received from SVN, if any: \n");
			if ($@) {
				$output->AppendText($@);
			} else {
				$output->AppendText(
					"Sorry, Diff to SVN failed. There are any diffrences in this file: $file1_name");
			}

			$main->info(
				Wx::gettext('Sorry, Diff failed. Are you sure your have access to the repository for this action') );
			return;
		}
	}
	return;
}

1;

__END__

=head1 NAME

Padre::Wx::Dialog::Patch - The Padre Patch dialog

=head1 DESCRIPTION

You will find more infomation in our L<wiki|http://padre.perlide.org/trac/wiki/Features/EditPatch/> pages.

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

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl 5 itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
