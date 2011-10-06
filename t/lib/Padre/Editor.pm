package t::lib::Padre::Editor;

use strict;
use warnings;
use Padre::Wx::Editor ();

our @ISA = 'Padre::Wx::Editor';

sub new {
	my $self = bless {}, shift;
	return $self;
}

sub set_document {
	my ( $self, $doc ) = @_;

	if ( defined $doc->{original_content} ) {
		$self->SetText( $doc->{original_content} );
	}
}

sub main {
	undef;
}

sub SetEOLMode {

}

sub ConvertEOLs {

}

sub EmptyUndoBuffer {

}

sub SetText {
	my ($self, $text) = @_;
	$self->{text}            = $text;
	$self->{pos}             = 0;
	$self->{selection_start} = 0;
	$self->{selection_start} = 0;
	return;
}

sub LineFromPosition {
	my ($self, $pos) = @_;
	return 0 if $pos == 0;
	my $str = substr($self->{text}, 0, $pos);
	#warn "str $pos '$str'\n";
	my @lines = split /\n/, $str, -1;
	return @lines-1; 
}

sub GetLineEndPosition {
	my ($self, $line) = @_;
	my @lines = split(/\n/, $self->{text}, -1);
	my $str = join "\n", @lines[0..$line];
	return length($str)+1;
}

sub PositionFromLine {
	my ($self, $line) = @_;
	return 0 if $line == 0;
	my @lines = split(/\n/, $self->{text}, -1);
	my $str = join "\n", @lines[0..$line-1];
	return length($str)+1;
}

sub GetColumn {
	my ($self, $pos) = @_;
	my $line  = $self->LineFromPosition($pos);
	my $start = $self->PositionFromLine($line);
	return $pos - $start;
}

sub GetText {
	return $_[0]->{text}
}

sub GetCurrentPos {
	return $_[0]->{pos};
}

sub GetSelectionEnd {
	return $_->{selection_end};
}

sub SetSelectionStart {
	$_[0]->{selection_start} = $_[1]
}

sub GotoPos {
	$_[0]->{pos} = $_[1];
}

1;
