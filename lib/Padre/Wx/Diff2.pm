package Padre::Wx::Diff2;

use 5.008;
use strict;
use warnings;
use Padre::Wx                ();
use Padre::Wx::FBP::Diff     ();
use Wx::Scintilla::Constant ();
use Padre::Logger qw(TRACE);


our $VERSION = '0.91';
our @ISA     = qw{
	Padre::Wx
	Padre::Wx::FBP::Diff
};

# Constructor
sub new {
	my $class = shift;
	my $main  = shift;
	my $self  = $class->SUPER::new($main);

	# Bitmap tooltips and icons
	$self->{prev_diff}->SetBitmapLabel( Padre::Wx::Icon::find("actions/go-up") );
	$self->{prev_diff}->SetToolTip( Wx::gettext('Previous difference') );
	$self->{next_diff}->SetBitmapLabel( Padre::Wx::Icon::find("actions/go-down") );
	$self->{next_diff}->SetToolTip( Wx::gettext('Next difference') );

	# Readonly!
	$self->{left_editor}->SetReadOnly(1);
	$self->{right_editor}->SetReadOnly(1);

	return $self;
}

sub show {
	my $self = shift;

	# TODO replace these with parameter-based stuff once it is working
	my $left_text = <<'CODE';
1
2
3
4
CODE
	my $right_text = <<'CODE';
1
2
3
4
CODE

	# Set the left side text
	my $left_editor = $self->{left_editor};
	$self->show_line_numbers($left_editor);
	$left_editor->SetReadOnly(0);
	$left_editor->SetText($left_text);
	$left_editor->SetReadOnly(1);

	# Set the right side text
	my $right_editor = $self->{right_editor};
	$self->show_line_numbers($right_editor);
	$right_editor->SetReadOnly(0);
	$right_editor->SetText($right_text);
	$right_editor->SetReadOnly(1);

	$self->Show;

	return;
}

sub show_line_numbers {
	my $self   = shift;
	my $editor = shift;

	my $width = $editor->TextWidth(
		Wx::Scintilla::Constant::STYLE_LINENUMBER,
		"m" x List::Util::max( 2, length $editor->GetLineCount )
	) + 5; # 5 pixel left "margin of the margin

	$editor->SetMarginWidth(
		Padre::Constant::MARGIN_LINE,
		$width,
	);
	return;
}

sub on_prev_diff_click {
	$_[0]->main->error('on_prev_diff_click');
}

sub on_next_diff_click {
	$_[0]->main->error('on_next_diff_click');
}

sub on_close_click {
	$_[0]->Destroy;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
