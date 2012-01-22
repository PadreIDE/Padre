package Padre::Task::PPI;

use 5.008;
use strict;
use warnings;
use Padre::Task ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Task';

=pod

=head1 NAME

Padre::Task::PPI - Generic L<PPI> background processing task

=head1 SYNOPSIS

  package Padre::Task::MyFancyTest;
  
  use strict;
  use base 'Padre::Task::PPI';
  
  # Will be called after ppi-parsing:
  sub process {
      my $self   = shift;
      my $ppi    = shift or return;
      my $result = ...expensive_calculation_using_ppi...
      $self->{result} = $result;
      return;
  }
  
  1;
  
  # elsewhere:
  
  Padre::Task::MyFancyTest->new(
      text => 'parse-this!',
  )->schedule;

=head1 DESCRIPTION

This is a base class for all tasks that need to do
expensive calculations using L<PPI>. The class will
setup a L<PPI::Document> object from a given piece of
code and then call the C<process_ppi> method on
the task object and pass the L<PPI::Document> as
first argument.

You can either let C<Padre::Task::PPI> fetch the
Perl code for parsing from the current document
or specify it as the "C<text>" parameter to
the constructor.

Note: If you don't supply the document text and
there is no currently open document to fetch it from,
C<new()> will simply return the empty list instead
of a C<Padre::Task::PPI> object.

=cut

sub new {
	my $self = shift->SUPER::new(@_);
	if ( $self->{document} ) {
		$self->{text} = delete( $self->{document} )->text_get;
	}
	return $self;
}

sub run {
	my $self = shift;
	my $text = delete $self->{text};

	# Parse the document and hand off to the task
	require PPI::Document;
	$self->process( PPI::Document->new( \$text ) );

	return 1;
}

# Default null processing
sub process {
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

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
