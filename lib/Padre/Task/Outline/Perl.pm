package Padre::Task::Outline::Perl;

use strict;
use warnings;

our $VERSION = '0.26';

use base 'Padre::Task::Outline';

use version;

=pod

=head1 NAME

Padre::Task::Outline::Perl - Perl document outline structure info 
gathering in the background

=head1 SYNOPSIS

  # by default, the text of the current document
  # will be fetched as will the document's notebook page.
  my $task = Padre::Task::Outline::Perl->new;
  $task->schedule;
  
  my $task2 = Padre::Task::Outline::Perl->new(
    text          => Padre::Current->document->text_get,
    editor => Padre::Current->editor,
    on_finish     => sub { my $task = shift; ... },
  );
  $task2->schedule;

=head1 DESCRIPTION

This class implements structure info gathering of Perl documents in
the background. It inherits from L<Padre::Task::Outline>.
Please read its documentation!

=cut

sub run {
	my $self = shift;
	$self->_get_outline;
	return 1;
}

sub _get_outline {
	my $self = shift;

	my $outline = [];

	require PPI::Find;
	require PPI::Document;

	my $ppi_doc = PPI::Document->new( \$self->{text} );

	return {} unless defined($ppi_doc);

	$ppi_doc->index_locations;

	my $find = PPI::Find->new(
		sub {
			return 1 if
				   ref $_[0] eq 'PPI::Statement::Package'
				or ref $_[0] eq 'PPI::Statement::Include'
				or ref $_[0] eq 'PPI::Statement::Sub'
		}
	);

	my @things = $find->in($ppi_doc);
	my $cur_pkg = {};
	my $not_first_one = 0;
	foreach my $thing (@things) {
		if ( ref $thing eq 'PPI::Statement::Package' ) {
			if ( $not_first_one ) {
				if ( not $cur_pkg->{name} ) {
					$cur_pkg->{name} = 'main';
				}
				push @{$outline}, $cur_pkg;
				$cur_pkg = {};
			}
			$not_first_one = 1;
			$cur_pkg->{name} = $thing->namespace;
			$cur_pkg->{line} = $thing->location->[0];
		}
		elsif ( ref $thing eq 'PPI::Statement::Include' ) {
			next if $thing->type eq 'no';
			if ( $thing->pragma ) {
				push @{ $cur_pkg->{pragmata} }, { name => $thing->pragma, line => $thing->location->[0] };
			}
			elsif ( $thing->module ) {
				push @{ $cur_pkg->{modules} }, { name => $thing->module, line => $thing->location->[0] };
			}
		}
		elsif ( ref $thing eq 'PPI::Statement::Sub' ) {
			push @{ $cur_pkg->{methods} }, { name => $thing->name, line => $thing->location->[0] };
		}
	}

	if ( not $cur_pkg->{name} ) {
		$cur_pkg->{name} = 'main';
	}
	push @{$outline}, $cur_pkg;

	$self->{outline} = $outline;
	return;
}

1;

__END__

=head1 SEE ALSO

This class inherits from L<Padre::Task::SyntaxChecker> which
in turn is a L<Padre::Task> and its instances can be scheduled
using L<Padre::TaskManager>.

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
