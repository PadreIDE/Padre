package Padre::PPI::EndifyPod;

=pod

=head1 NAME

Padre::PPI::EndifyPod - Move fragmented POD to the end of a Perl document

=head1 SYNOPSIS

  my $transform = Padre::PPI::EndifyPod->new;
  $transform->apply( Padre::Current->document );

=cut

use 5.008;
use strict;
use warnings;
use Padre::PPI::Transform ();

our $VERSION = '0.94';
our @ISA     = 'Padre::PPI::Transform';





######################################################################
# Transform Methods

sub document {
	my $self     = shift;
	my $document = shift;

	# Find all the POD fragments
	my $pod = $document->find('PPI::Token::Pod');
	unless ( defined $pod ) {
		Padre::Current->main->error( Wx::gettext('Error while searching for POD') );
		return undef;
	}
	unless ($pod) {
		Padre::Current->main->error( Wx::gettext('This document does not contain any POD') );
		return 0;
	}
	unless ( @$pod > 1 ) {
		Padre::Current->main->error( Wx::gettext('Only one POD fragment, will not try to merge') );
		return 0;
	}

	# Create a single merged POD fragment
	my $merged = PPI::Token::Pod->merge(@$pod);
	unless ($merged) {
		Padre::Current->main->error( Wx::gettext('Failed to merge the POD fragments') );
		return undef;
	}

	# Strip all the fragments out of the document
	foreach my $element (@$pod) {
		next if $element->delete;
		$document->current->error( Wx::gettext('Failed to delete POD fragment') );
		return undef;
	}

	# Does the document already have an __END__ block?
	my $end = $document->child(-1);
	if ( $end and $end->isa('PPI::Statement::End') ) {

		# Make sure there's sufficient newlines at the end
		$end->last_element->content =~ /(\n*)\z/;
		my $newlines = length $1;
		my $needed   = 2 - $newlines;
		if ( $needed > 0 ) {
			$end->last_element->{content} .= join '', ("\n") x $needed;
		}

		# Append the merged Pod
		$end->add_element($merged);

	} else {

		# Generate the end block
		my $statement = PPI::Statement::End->new;
		$statement->add_element( PPI::Token::Separator->new("__END__") );
		$statement->add_element( PPI::Token::Whitespace->new("\n") );
		$statement->add_element( PPI::Token::End->new("\n") );
		$statement->add_element($merged);

		# Add it to the document
		$document->add_element( PPI::Token::Whitespace->new("\n") );
		$document->add_element($statement);
	}

	return 1;
}

1;

=pod

=head1 SEE ALSO

L<Padre::PPI::Transform>, L<PPI::Transform>

=head1 AUTHOR

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
