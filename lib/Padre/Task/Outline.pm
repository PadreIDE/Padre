package Padre::Task::Outline;

use strict;
use warnings;
use Params::Util qw{_CODE _INSTANCE};
use Padre::Task    ();
use Padre::Current ();
use Padre::Wx      ();

our $VERSION = '0.43';
our @ISA     = 'Padre::Task';

=pod

=head1 NAME

Padre::Task::Outline - Generic background processing task to
gather structure info on the current document

=head1 SYNOPSIS

  package Padre::Task::Outline::MyLanguage;
  
  use base 'Padre::Task::Outline';
  
  sub run {
          my $self = shift;
          my $doc_text = $self->{text};
          # black magic here
          $self->{outline} = ...;
          return 1;
  };
  
  1;
  
  # elsewhere:
  
  # by default, the text of the current document
  # will be fetched as will the document's notebook page.
  my $task = Padre::Task::Outline::MyLanguage->new();
  $task->schedule;
  
  my $task2 = Padre::Task::Outline::MyLanguage->new(
      text   => Padre::Current->document->text_get,
      editor => Padre::Current->editor,
  );
  $task2->schedule;

=head1 DESCRIPTION

This is a base class for all tasks that need to do
expensive structure info gathering in a background task.

You can either let C<Padre::Task::Outline> fetch the
Perl code for parsing from the current document
or specify it as the "C<text>" parameter to
the constructor.

To create a outline gatherer for a given document type C<Foo>,
you create a subclass C<Padre::Task::Outline::Foo> and
implement the C<run> method which uses the C<$self-E<gt>{text}>
attribute of the task object for its nefarious structure info gathering
purposes and then stores the result in the C<$self-E<gt>{outline}>
attribute of the object. The result should be a data structure of the
form defined in the documentation of the C<Padre::Document::get_outline>
method. See L<Padre::Document>.

This base class requires all logic necessary to update the GUI
with the structure info in a method C<update_gui> of the derived
class. That method is called in the C<finish()> hook.

=cut

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	unless ( defined $self->{text} ) {
		$self->{text} = Padre::Current->document->text_get;
	}

	# put notebook page and callback into main-thread-only storage
	$self->{main_thread_only} ||= {};

	my $editor = $self->{editor}
		|| $self->{main_thread_only}->{editor};
	delete $self->{editor};
	unless ( defined $editor ) {
		$editor = Padre::Current->editor;
	}
	return if not defined $editor;

	$self->{main_thread_only}->{editor} = $editor;

	return $self;
}

sub run {
	my $self = shift;
	return 1;
}

sub prepare {
	my $self = shift;
	unless ( defined $self->{text} ) {
		require Carp;
		Carp::croak("Could not find the document's text.");
	}
	unless ( defined $self->{main_thread_only}->{editor} ) {
		require Carp;
		Carp::croak("Could not find the reference to the notebook page for GUI updating.");
	}
	return 1;
}

sub finish {
	$_[0]->update_gui;
	return;
}

1;

__END__

=pod

=head1 SEE ALSO

This class inherits from C<Padre::Task> and its instances can be scheduled
using C<Padre::TaskManager>.

The transfer of the objects to and from the worker threads is implemented
with L<Storable>.

=head1 AUTHOR

Steffen Mueller E<lt>smueller@cpan.orgE<gt>

Heiko Jansen E<lt>heiko_jansen@web.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
