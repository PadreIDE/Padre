package Padre::Wx::Dialog::Diff;

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.91';
our @ISA     = (
	'Padre::Wx::Role::Main',
	'Wx::PlPopupTransientWindow',
);

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	my $panel = Wx::Panel->new($self);

	$self->{prev_diff_button} = Wx::Button->new(
		$panel, -1, Wx::gettext('Previous'),
	);
	$self->{prev_diff_button}->SetToolTip( Wx::gettext('Previous difference') );
	$self->{next_diff_button} = Wx::Button->new(
		$panel, -1, Wx::gettext('Next'),
	);
	$self->{next_diff_button}->SetToolTip( Wx::gettext('Next difference') );

	$self->{revert_button} = Wx::Button->new(
		$panel, -1, Wx::gettext('Revert'),
	);
	$self->{close_button} = Wx::Button->new(
		$panel, Wx::ID_CANCEL, Wx::gettext('Close'),
	);

	$self->{status_label} = Wx::TextCtrl->new(
		$panel,
		-1,
		'',
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::TE_READONLY,
	);

	my $button_sizer = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$button_sizer->Add( $self->{prev_diff_button}, 0, 0, 0 );
	$button_sizer->Add( $self->{next_diff_button}, 0, 0, 0 );
	$button_sizer->Add( $self->{revert_button},    0, 0, 0 );
	$button_sizer->AddSpacer(10);
	$button_sizer->Add( $self->{close_button}, 0, 0, 0 );

	$self->{text_ctrl} = Wx::TextCtrl->new(
		$panel,
		-1,
		'',
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::TE_READONLY | Wx::wxTE_MULTILINE | Wx::wxTE_RICH,
	);

	my $vsizer = Wx::BoxSizer->new(Wx::VERTICAL);
	$vsizer->Add( $button_sizer,         0, Wx::ALL | Wx::EXPAND, 0 );
	$vsizer->Add( $self->{status_label}, 0, Wx::ALL | Wx::EXPAND, 0 );
	$vsizer->Add( $self->{text_ctrl},    1, Wx::ALL | Wx::EXPAND, 0 );

	# Previous difference button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{prev_diff_button},
		\&on_prev_diff_button,
	);

	# Next difference button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{next_diff_button},
		\&on_next_diff_button,
	);


	# Revert button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{revert_button},
		\&on_revert_button,
	);

	# Close button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{close_button},
		sub {
			$_[0]->Hide;
		}
	);

	$panel->SetSizer($vsizer);
	$panel->Fit;
	$self->Fit;

	return $self;
}

sub on_prev_diff_button {
	$_[0]->main->diff->select_previous_difference;
}

sub on_next_diff_button {
	$_[0]->main->diff->select_next_difference;
}

sub on_revert_button {
	my $self = shift;

	my $editor   = $self->{editor};
	my $line     = $self->{line};
	my $diff     = $self->{diff};
	my $old_text = $diff->{old_text};
	my $new_text = $diff->{new_text};

	my $start = $editor->PositionFromLine($line);
	my $end   = $editor->GetLineEndPosition( $line + $diff->{lines_added} ) + 1;
	$editor->SetTargetStart($start);
	$editor->SetTargetEnd( $start + length($new_text) );
	$editor->ReplaceTarget( $old_text ? $old_text : '' );

	$self->Hide;
}

sub show {

	my $self   = shift;
	my $editor = shift;
	my $line   = shift;
	my $diff   = shift;
	my $pt     = shift;

	# Store editor reference so we can access it in revert
	$self->{editor} = $editor;
	$self->{line}   = $line;
	$self->{diff}   = $diff;

	$self->Move($pt);

	my $style      = $self->{text_ctrl}->GetDefaultStyle;
	my $type = $diff->{type};
	if( $type eq 'A' ) {
		$style->SetTextColour( Wx::Colour->new("black") );
		$style->SetBackgroundColour( Padre::Wx::Editor::DARK_GREEN() );
	} elsif( $type eq 'D' ) {
		$style->SetTextColour( Wx::Colour->new("black") );
		$style->SetBackgroundColour( Padre::Wx::Editor::LIGHT_RED() );
	} elsif( $type eq 'C') {
		$style->SetTextColour( Wx::Colour->new("black") );
		$style->SetBackgroundColour( Padre::Wx::Editor::LIGHT_BLUE() );
	} else {
		#TODO what to do here?
	}
	$self->{text_ctrl}->SetDefaultStyle($style);

	$self->{status_label}->SetValue( $diff->{message} );
	if ( $diff->{old_text} ) {
		$self->{text_ctrl}->SetValue('');
		$self->{text_ctrl}->AppendText( $diff->{old_text} );
		$self->{text_ctrl}->Show(1);
	} else {
		$self->{text_ctrl}->Show(0);
	}
	

	# Hide when the editor loses focus
	my $popup = $self;
	Wx::Event::EVT_KILL_FOCUS(
		$editor,
		sub {
			$popup->Hide;
		}
	);

	my $panel = $self->{text_ctrl}->GetParent;
	$panel->Layout;
	$panel->Fit;
	$self->Fit;

	$self->Show(1);
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
