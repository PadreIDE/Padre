package Padre::Wx::Dialog::Special;

use 5.008;
use strict;
use warnings;
use Padre::Wx::FBP::Special ();

our $VERSION = '0.89';
our @ISA     = 'Padre::Wx::FBP::Special';





######################################################################
# Constructor

sub new {
	my $class  = shift;
	my $self   = $class->SUPER::new(@_);
	my $select = $self->select;

	# Fill the dropbox
	$select->Clear;
	foreach my $special ( $self->catalogue ) {
		$select->Append( $special->[1], $special->[0] );
	}
	$select->SetSelection(0);

	# Set the initial preview
	$self->refresh;

	return $self;
}





######################################################################
# Event Handlers

sub refresh {
	my $self  = shift;
	my $value = $self->value;
	$self->preview->SetValue($value);
}

sub insert_preview {
	my $self   = shift;
	my $editor = $self->current->editor or return;
	$editor->insert_text( $self->value );
}





######################################################################
# Special Value Catalogue

sub catalogue {
	my $date = Wx::gettext('Date/Time');
	my $file = Wx::gettext('File');
	return (
		[ time_now   => "$date - " . Wx::gettext('Now')   ],
		[ time_today => "$date - " . Wx::gettext('Today') ],
		[ time_year  => "$date - " . Wx::gettext('Year')  ],
		[ time_epoch => "$date - " . Wx::gettext('Epoch') ],
		[ file_name  => "$file - " . Wx::gettext('Name')  ],
		[ file_size  => "$file - " . Wx::gettext('Size')  ],
		[ file_lines => "$file - " . Wx::gettext('Lines') ],
	);
}

sub value {
	my $self   = shift;
	my @list   = $self->catalogue;
	my $method = $list[ $self->select->GetSelection ]->[0];
	return $self->$method;
}

sub time_now {
	return scalar localtime;
}

sub time_today {
	my @t = localtime;
	return sprintf( "%s-%02s-%02s", $t[5] + 1900, $t[4], $t[3] );
}

sub time_year {
	my @t = localtime;
	return $t[5] + 1900;
}

sub time_epoch {
	return time;
}

sub file_name {
	my $self     = shift;
	my $document = $self->current->document or return '';
	if ( $document->file ) {
		return $document->{file}->filename;
	}

	# Use the title instead
	my $title = $document->get_title;
	$title =~ s/^\s+//;
	return $title;
}

sub file_size {
	my $self     = shift;
	my $document = $self->current->document                   or return 0;
	my $filename = $document->filename || $document->tempfile or return 0;
	return -s $filename;
}

sub file_lines {
	my $self = shift;
	my $editor = $self->current->editor or return 0;
	return $editor->GetLineCount;
}

1;
