package Padre::Task::PPI;

use 5.008;
use strict;
use warnings;
use Padre::Task    ();
use Padre::Current ();

our $VERSION = '0.45';
our @ISA     = 'Padre::Task';

=pod

=head1 NAME

Padre::Task::PPI - Generic PPI background processing task

=head1 SYNOPSIS

  package Padre::Task::PPI::MyFancyTest;
  use base 'Padre::Task::PPI';
  
  # will be called after ppi-parsing:
  sub process_ppi  {
          my $self = shift;
          my $ppi  = shift or return;
          my $result = ...expensive_calculation_using_ppi...
          $self->{result} = $result;
          return();
  },
  
  sub finish {
          my $self = shift;
          my $result = $self->{result};
          # update GUI here...
  };
  
  1;
  
  # elsewhere:
  
  # by default, the text of the current document
  # will be fetched.
  my $task = Padre::Task::PPI::MyFancyTest->new();
  $task->schedule;
  
  my $task2 = Padre::Task::PPI::MyFancyTest->new(
    text => 'parse-this!',
  );
  $task2->schedule;

=head1 DESCRIPTION

This is a base class for all tasks that need to do
expensive calculations using PPI. The class will
setup a L<PPI::Document> object from a given piece of
code and then call the C<process_ppi> method on
the task object and pass the PPI::Document as
first argument. 

You can either let C<Padre::Task::PPI> fetch the
Perl code for parsing from the current document
or specify it as the "C<text>" parameter to
the constructor.

Note: If you don't supply the document text and
there is no currently open document to fetch it from,
C<new()> will simply return the empty list instead
of a Padre::Task::PPI object.

=cut

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	unless ( defined $self->{text} ) {
		my $doc = Padre::Current->document;
		return () if not defined $doc;
		$self->{text} = $doc->text_get;
	}
	return bless $self => $class;
}

sub run {
	my $self = shift;
	require PPI;
	require PPI::Document;
	my $ppi = PPI::Document->new( \( $self->{text} ) );
	delete $self->{text};
	$self->process_ppi($ppi) if $self->can('process_ppi');
	return 1;
}

sub prepare {
	my $self = shift;
	unless ( defined $self->{text} ) {
		require Carp;
		Carp::croak("Could not find the document's text for PPI parsing.");
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

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
