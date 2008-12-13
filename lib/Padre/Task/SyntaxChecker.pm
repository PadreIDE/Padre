
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
  # will be fetched.
  my $task = Padre::Task::SyntaxChecker::MyLanguage->new();
  $task->schedule;
  
  my $task2 = Padre::Task::SyntaxChecker::MyLanguage->new(
    text => 'check-this!',
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
	return 1;
}

sub finish {
	my $self = shift;
	my $syn_check = $self->{syntax_check};
	# TODO GUI update here!
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
