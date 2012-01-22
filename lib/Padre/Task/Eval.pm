package Padre::Task::Eval;

=pod

=head1 NAME

Padre::Task::Eval - Task for executing arbitrary code via a string eval

=head1 SYNOPSIS

  my $task = Padre::Task::Eval->new(
      prepare => '1 + 1',
      run     => 'my $foo = sub { 2 + 3 }; $foo->();',
      finish  => '$_[0]->{prepare}',
  );
  
  $task->prepare;
  $task->run;
  $task->finish;

=head1 DESCRIPTION

B<Padre::Task::Eval> is a stub class used to implement testing and other
miscellaneous functionality.

It takes three named string parameters matching each of the three execution
phases. When each phase of the task is run, the string will be eval'ed and
the result will be stored in the same has key as the source string.

If the key does not exist at all, nothing will be executed for that phase.

Regardless of the execution result (or the non-execution of the phase) each
phase will always return true. However, if the string eval throws an
exception it will escape the task object (although when run properly inside
of a task handle it should be caught by the handle).

=head1 METHODS

This class contains now additional methods beyond the defaults provided by
the L<Padre::Task> API.

=cut

use 5.008005;
use strict;
use warnings;
use Padre::Task ();

our $VERSION  = '0.94';
our @ISA      = 'Padre::Task';
our $AUTOLOAD = undef;

sub prepare {

	# Only optionally override
	unless ( exists $_[0]->{prepare} ) {
		return shift->SUPER::prepare(@_);
	}

	$_[0]->{prepare} = eval $_[0]->{prepare};
	die $@ if $@;

	return 1;
}

sub run {

	# Only optionally override
	unless ( exists $_[0]->{run} ) {
		return shift->SUPER::run(@_);
	}

	$_[0]->{run} = eval $_[0]->{run};
	die $@ if $@;

	return 1;
}

sub finish {

	# Only optionally override
	unless ( exists $_[0]->{run} ) {
		return shift->SUPER::finish(@_);
	}

	$_[0]->{finish} = eval $_[0]->{finish};
	die $@ if $@;

	return 1;
}

sub AUTOLOAD {
	my $self = shift;
	my $slot = $AUTOLOAD =~ m/^.*::(.*)\z/s;
	if ( exists $self->{$slot} ) {
		$self->{$slot} = eval $_[0]->{$slot};
		die $@ if $@;
	} else {
		die("No such handler '$slot'");
	}
	return 1;
}

sub DESTROY { }

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
