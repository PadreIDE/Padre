
package Padre::Task::SyntaxChecker;
use strict;
use warnings;

our $VERSION = '0.20';

use base 'Padre::Task';

=pod

=head1 NAME

Padre::Task::SyntaxChecker - Generic syntax-checking background processing task

=head1 SYNOPSIS

  package Padre::Task::SyntaxChecker::MyLanguage;
  use base 'Padre::Task::SyntaxChecker';
  
  sub run {
          my $self = shift;
          my $doc_text = $self->{text};
          # black magic here
          $self->{syntax_check} = ...;
          return 1;
  };
  
  1;
  
  # elsewhere:
  
  # by default, the text of the current document
  # will be fetched as will the document's notebook page.
  my $task = Padre::Task::SyntaxChecker::MyLanguage->new();
  $task->schedule;
  
  my $task2 = Padre::Task::SyntaxChecker::MyLanguage->new(
    text => Padre::Documents->current->text_get,
    notebook_page => Padre::Documents->current->editor,
  );
  $task2->schedule;

=head1 DESCRIPTION

This is a base class for all tasks that need to do
expensive syntax checking in a background task.

You can either let C<Padre::Task::SyntaxChecker> fetch the
Perl code for parsing from the current document
or specify it as the "C<text>" parameter to
the constructor.

To create a syntax checker for a given document type C<Foo>,
you create a subclass C<Padre::Task::SyntaxChecker::Foo> and
implement the C<run> method which uses the C<$self-E<gt>{text}>
attribute of the task object for its nefarious syntax checking
purposes and then stores the result in the C<$self-E<gt>{syntax_check}>
attribute of the object. The result should be a data structure of the
form defined in the documentation of the C<Padre::Document::check_syntax>
method. See L<Padre::Document>.

This base class implements all logic necessary to update the GUI
with the syntax check results in a C<finish()> hook. If you want
to implement your own C<finish()>, make sure to call C<$self-E<gt>SUPER::finish>
for this reason.

=cut

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	if (not defined $self->{text}) {
		$self->{text} = Padre::Documents->current->text_get();
	}
	
	# put notebook page and callback into main-thread-only storage
	$self->{main_thread_only} ||= {};
	my $notebook_page = $self->{notebook_page} || $self->{main_thread_only}{notebook_page};
	my $on_finish     = $self->{on_finish}     || $self->{main_thread_only}{on_finish};
	delete $self->{notebook_page};
	delete $self->{on_finish};
	if (not defined $notebook_page) {
		$notebook_page = Padre::Documents->current->editor;
	}
	return() if not defined $notebook_page;
	$self->{main_thread_only}{on_finish} = $on_finish if $on_finish;
	$self->{main_thread_only}{notebook_page} = $notebook_page;
	return $self;
}

sub run {
	my $self = shift;
	return 1;
}

sub prepare {
	my $self = shift;
	if (not defined $self->{text}) {
		require Carp;
		Carp::croak("Could not find the document's text for syntax checking.");
	}
	if (not defined $self->{main_thread_only}{notebook_page}) {
		require Carp;
		Carp::croak("Could not find the reference to the notebook page for GUI updating.");
	}
	return 1;
}

sub finish {
	my $self = shift;

	my $callback = $self->{main_thread_only}{on_finish};
	if (defined $callback and ref($callback) eq 'CODE') {
		$callback->($self);
	}
	else {
		$self->update_gui();
	}
}

sub update_gui {
	my $self = shift;
	my $messages = $self->{syntax_check};
	
	my $syntax_checker = Padre->ide->wx->main_window->syntax_checker;
	my $syntax_bar     = $syntax_checker->syntax_bar;
	my $notebook_page  = $self->{main_thread_only}{notebook_page};
	my $document       = $notebook_page->{Document};
	
	require Padre::Wx;
	# If there are no errors, clear the synax checker pane and return.
	unless ( $messages ) {
		if ( defined $notebook_page and $notebook_page->isa('Padre::Wx::Editor') ) {
			$notebook_page->MarkerDeleteAll(Padre::Wx::MarkError());
			$notebook_page->MarkerDeleteAll(Padre::Wx::MarkWarn());
		}
		$syntax_bar->DeleteAllItems;
		return;
	}
	
	# update the syntax checker pane
	if ( scalar(@{$messages}) > 0 ) {
		$notebook_page->MarkerDeleteAll(Padre::Wx::MarkError());
		$notebook_page->MarkerDeleteAll(Padre::Wx::MarkWarn());

		my $red = Wx::Colour->new("red");
		my $orange = Wx::Colour->new("orange");
		$notebook_page->MarkerDefine(Padre::Wx::MarkError(), Wx::wxSTC_MARK_SMALLRECT(), $red, $red);
		$notebook_page->MarkerDefine(Padre::Wx::MarkWarn(),  Wx::wxSTC_MARK_SMALLRECT(), $orange, $orange);

		my $i = 0;
		$syntax_bar->DeleteAllItems;
		delete $notebook_page->{synchk_calltips};
		my $last_hint = '';
		
		# eliminate some warnings
		foreach my $m (@{$messages}) {
			$m->{line} = 0  unless defined $m->{line};
			$m->{msg}  = '' unless defined $m->{msg};
		}
		foreach my $hint ( sort { $a->{line} <=> $b->{line} } @{$messages} ) {
			my $l = $hint->{line} - 1;
			if ( $hint->{severity} eq 'W' ) {
				$notebook_page->MarkerAdd( $l, 2);
			}
			else {
				$notebook_page->MarkerAdd( $l, 1);
			}
			my $idx = $syntax_bar->InsertStringItem( $i++, $l + 1 );
			$syntax_bar->SetItem( $idx, 1, ( $hint->{severity} eq 'W' ? Wx::gettext('Warning') : Wx::gettext('Error') ) );
			$syntax_bar->SetItem( $idx, 2, $hint->{msg} );

			if ( exists $notebook_page->{synchk_calltips}->{$l} ) {
				$notebook_page->{synchk_calltips}->{$l} .= "\n--\n" . $hint->{msg};
			}
			else {
				$notebook_page->{synchk_calltips}->{$l} = $hint->{msg};
			}
			$last_hint = $hint;
		}

		my $width0_default = $notebook_page->TextWidth( Wx::wxSTC_STYLE_DEFAULT(), Wx::gettext("Line") . ' ' );
		my $width0 = $notebook_page->TextWidth( Wx::wxSTC_STYLE_DEFAULT(), $last_hint->{line} x 2 );
		my $refStr = '';
		if ( length( Wx::gettext('Warning') ) > length( Wx::gettext('Error') ) ) {
			$refStr = Wx::gettext('Warning');
		}
		else {
			$refStr = Wx::gettext('Error');
		}
		my $width1 = $notebook_page->TextWidth( Wx::wxSTC_STYLE_DEFAULT(), $refStr . ' ' );
		my $width2 = $syntax_bar->GetSize->GetWidth - $width0 - $width1 - $syntax_bar->GetCharWidth * 2;
		$syntax_bar->SetColumnWidth( 0, ( $width0_default > $width0 ? $width0_default : $width0 ) );
		$syntax_bar->SetColumnWidth( 1, $width1 );
		$syntax_bar->SetColumnWidth( 2, $width2 );
	}
	else {
		$notebook_page->MarkerDeleteAll(Padre::Wx::MarkError());
		$notebook_page->MarkerDeleteAll(Padre::Wx::MarkWarn());
		$syntax_bar->DeleteAllItems;
	}

	return 1;
}

1;

__END__

=head1 SEE ALSO

This class inherits from C<Padre::Task> and its instances can be scheduled
using C<Padre::TaskManager>.

The transfer of the objects to and from the worker threads is implemented
with L<Storable>.

=head1 AUTHOR

Steffen Mueller C<smueller@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 Gabor Szabo.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
