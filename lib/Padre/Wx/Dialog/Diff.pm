package Padre::Wx::Dialog::Diff;

use 5.008;
use strict;
use warnings;
use Padre::Constant ();
use Padre::Wx       ();

our $VERSION = '0.94';
our @ISA     = (
	'Padre::Wx::Role::Main',
	'Wx::PopupWindow',
);

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	my $panel = Wx::Panel->new($self);

	$self->{prev_diff_button} = Wx::BitmapButton->new(
		$panel,
		-1,
		Padre::Wx::Icon::find("actions/go-up"),
	);
	$self->{prev_diff_button}->SetToolTip( Wx::gettext('Previous difference') );
	$self->{next_diff_button} = Wx::BitmapButton->new(
		$panel,
		-1,
		Padre::Wx::Icon::find("actions/go-down"),
	);
	$self->{next_diff_button}->SetToolTip( Wx::gettext('Next difference') );

	$self->{revert_button} = Wx::BitmapButton->new(
		$panel,
		-1,
		Padre::Wx::Icon::find("actions/edit-undo"),
	);
	$self->{revert_button}->SetToolTip( Wx::gettext('Revert this change') );

	$self->{close_button} = Wx::BitmapButton->new(
		$panel,
		-1,
		Padre::Wx::Icon::find("actions/window-close"),
	);
	$self->{close_button}->SetToolTip( Wx::gettext('Close this window') );

	$self->{status_label} = Wx::TextCtrl->new(
		$panel,
		-1,
		'',
		Wx::DefaultPosition,
		[ 130, -1 ],
		Wx::TE_READONLY,
	);

	$self->{text_ctrl} = Wx::TextCtrl->new(
		$panel,
		-1,
		'',
		Wx::DefaultPosition,

		# (pbp line = 78 chrs) *2/3=52
		# (9/16) 52 chrs plus a half; (52*9)+4 = 472
		# 4 lines plus a half: (4*16)+8= 72
		[ 472, 72 ],
		Wx::TE_READONLY | Wx::TE_MULTILINE | Wx::TE_DONTWRAP,
	);

	my $button_sizer = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$button_sizer->Add( $self->{prev_diff_button}, 0, 0, 0 );
	$button_sizer->Add( $self->{next_diff_button}, 0, 0, 0 );
	$button_sizer->Add( $self->{revert_button},    0, 0, 0 );
	$button_sizer->AddSpacer(10);
	$button_sizer->Add( $self->{status_label}, 0, Wx::ALL, 0 );
	$button_sizer->AddStretchSpacer;
	$button_sizer->Add( $self->{close_button}, 0, 0, 0 );

	my $vsizer = Wx::BoxSizer->new(Wx::VERTICAL);
	$vsizer->AddSpacer(1);
	$vsizer->Add( $button_sizer,      0, Wx::ALL | Wx::EXPAND, 1 );
	$vsizer->Add( $self->{text_ctrl}, 0, Wx::ALL | Wx::EXPAND, 1 );

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

	my $type = $diff->{type} or return;

	# Store editor reference so we can access it in revert
	$self->{editor} = $editor;
	$self->{line}   = $line;
	$self->{diff}   = $diff;

	# Inherit font from current editor
	my $font = $editor->GetFont;
	$self->{status_label}->SetFont($font);
	$self->{text_ctrl}->SetFont($font);

	# Hack to workaround Wx::PopupWindow relative positioning bug
	if (Padre::Constant::WIN32) {
		$self->Move( $self->main->ScreenToClient( $editor->ClientToScreen($pt) ) );
	} else {
		$self->Move( $editor->ClientToScreen($pt) );
	}

	my $color;
	if ( $type eq 'A' ) {
		$color = Padre::Wx::Editor::DARK_GREEN();
	} elsif ( $type eq 'D' ) {
		$color = Padre::Wx::Editor::LIGHT_RED();
	} elsif ( $type eq 'C' ) {
		$color = Padre::Wx::Editor::LIGHT_BLUE();
	} else {
		$color = Wx::Colour->new("black");
	}
	$self->{text_ctrl}->SetBackgroundColour($color);

	$self->{status_label}->SetValue( $diff->{message} );
	if ( $diff->{old_text} ) {
		$self->{text_ctrl}->SetValue( $diff->{old_text} );
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

	Wx::Event::EVT_KEY_UP(
		$editor,
		sub {
			my ( $self, $event ) = @_;
			if ( $event->GetKeyCode == Wx::WXK_ESCAPE ) {

				# Escape hides the diff box
				$popup->Hide;
			}
			$event->Skip;
		}
	);

	my $panel = $self->{text_ctrl}->GetParent;
	$panel->Layout;
	$panel->Fit;
	$self->Fit;

	$self->Show(1);
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
