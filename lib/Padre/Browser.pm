package Padre::Browser;

use 5.008;
use strict;
use warnings;
use Carp                ();
use Scalar::Util        ();
use Padre::Browser::POD ();

our $VERSION = '0.94';

use Class::XSAccessor {
	getters => {
		get_providers => 'providers',
		get_viewers   => 'viewers',
		get_schemes   => 'schemes',
	},
	setters => {
		set_providers => 'providers',
		set_viewers   => 'viewers',
		set_schemes   => 'schemes',
	},
};

=pod

=head1 NAME

Padre::Browser -- documentation browser for Padre

=head1 DESCRIPTION

Provide an interface for retrieving / generating documentation, resolving terms
to documentation (search?) and formatting documentation.

Allow new packages to be loaded and interrogated for the MIME types they can
generate documentation for. Provide similar mechanism for registering new
documentation viewers and URI schemes accepted for resolving.

B<NOTE:> I think all the method names are wrong. Blast it.

=head1 SYNOPSIS

  # Does perlish things by default via 'Padre::Browser::POD'
  my $browser = Padre::Browser->new;
  my $source = Padre::Document->new( filename=>'source/Package.pm' );

  my $docs = $browser->docs( $source );
  # $docs provided by Browser::POD->generate
  #  should be Padre::Browser::Document , application/x-pod

  my $output = $browser->browse( $docs );
  # $output provided by Browser::POD->render
  #  should be Padre::Document , text/x-html

  $browser->load_viewer( 'Padre::Browser::PodAdvanced' );
  # PodAdvanced->render might add an html TOC in addition to
  #  just pod2html

  my $new_output = $browser->browse( $docs );
  # $new_output now with a table of contents

=head1 METHODS

=head2 new

Boring constructor, pass nothing. Yet.

=head2 load_provider

Accepts a single class name, will attempt to auto-L<use> the class and
interrogate its C<provider_for> method. Any MIME types returned will be
associated with the class for dispatch to C<generate>.

Additionally, interrogate class for C<accept_schemes> and associate the class
with URI schemes for dispatch to C<resolve>.

=head2 load_viewer

Accepts a single class name, will attempt to auto-L<use> the class and
interrogate its C<viewer_for> method. Any MIME types returned will be
associated with the class for dispatch to C<render>.

=head2 resolve

Accepts a URI or scalar

=head2 browse

=head2 accept

=head1 EXTENDING

  package My::Browser::Doxygen;

  # URI of doxygen:$string or doxygen://path?query
  sub accept_schemes {
      'doxygen',
  }

  sub provider_for {
      'text/x-c++src'
  }

  sub viewer_for {
      'text/x-doxygen',
  }

  sub generate {
      my ($self,$doc) = @_;
      # $doc will be Padre::Document of any type specified
      # by ->provider_for

      # push $doc through doxygen
      # ...
      # that was easy :)

      # You know your own output type, be explicit
      my $response = Padre::Document->new;
      $response->{original_content} = $doxygen->output;
      $response->set_mimetype( 'text/x-doxygen' );
      return $response;
  }

  sub render {
      my ($self,$docs) = @_;
      # $docs will be of any type specified
      # by ->viewer_for;

      ## turn $docs into doxygen(y) html document
      #  ...
      #

      my $response = Padre::Document->new;
      $response->{original_content} = $doxy2html->output;
      $response->set_mimetype( 'text/x-html' );
      return $response;

  }

=cut

sub new {
	my ( $class, %args ) = @_;

	my $self = bless \%args, ref($class) || $class;
	$self->set_providers( {} ) unless $args{providers};
	$self->set_viewers(   {} ) unless $args{viewers};
	$self->set_schemes(   {} ) unless $args{schemes};

	# Provides pod from perl, pod: perldoc: schemes
	$self->load_provider('Padre::Browser::POD');

	# Produces html view of POD
	$self->load_viewer('Padre::Browser::POD');

	return $self;
}

sub load_provider {
	my ( $self, $class ) = @_;

	unless ( $class->VERSION ) {
		eval "require $class;";
		die("Failed to load $class: $@") if $@;
	}
	if ( $class->can('provider_for') ) {
		$self->register_providers( $_ => $class ) for $class->provider_for;
	} else {
		Carp::confess("$class is not a provider for anything.");
	}

	if ( $class->can('accept_schemes') ) {
		$self->register_schemes( $_ => $class ) for $class->accept_schemes;
	} else {
		Carp::confess("$class accepts no uri schemes");
	}

	return $self;
}

sub load_viewer {
	my ( $self, $class ) = @_;
	unless ( $class->VERSION ) {
		eval "require $class;";
		die("Failed to load $class: $@") if $@;
	}
	if ( $class->can('viewer_for') ) {
		$self->register_viewers( $_ => $class ) for $class->viewer_for;
	}
	$self;
}

sub register_providers {
	my ( $self, %provides ) = @_;
	while ( my ( $type, $class ) = each %provides ) {

		# TO DO - handle collisions, ie multi providers

		# (Ticket #673)

		$self->get_providers->{$type} = $class;
	}
	$self;
}

sub register_viewers {
	my ( $self, %viewers ) = @_;
	while ( my ( $type, $class ) = each %viewers ) {
		$self->get_viewers->{$type} = $class;
		unless ( $class->VERSION ) {
			eval "require $class;";
			die("Failed to load $class: $@") if $@;
		}
	}
	$self;
}

sub register_schemes {
	my ( $self, %schemes ) = @_;
	while ( my ( $scheme, $class ) = each %schemes ) {
		$self->get_schemes->{$scheme} = $class;
	}
	$self;
}

sub provider_for {
	my ( $self, $type ) = @_;
	my $p;
	eval {
		if ( exists $self->get_providers->{$type} )
		{
			$p = $self->get_providers->{$type}->new;
		}
	};
	Carp::confess($@) if $@;
	return $p;
}

sub accept {
	my ( $self, $scheme ) = @_;
	if ( defined $self->get_schemes->{$scheme} ) {
		return $self->get_schemes->{$scheme};
	}
	return;
}

sub viewer_for {
	my ( $self, $type ) = @_;
	my $v;
	eval {
		if ( exists $self->get_viewers->{$type} )
		{
			$v = $self->get_viewers->{$type}->new;
		}
	};
	Carp::confess($@) if $@;
	return $v;
}

sub docs {
	my ( $self, $doc ) = @_;
	if ( my $provider = $self->provider_for( $doc->guess_mimetype ) ) {
		my $docs = $provider->generate($doc);
		return $docs;
	}
	return;
}

sub resolve {
	my ( $self, $ref, $hints ) = @_;
	my @refs;
	if ( Scalar::Util::blessed($ref) and $ref->isa('URI') ) {
		return $self->resolve_uri( $ref, $hints );
	}

	# TO DO this doubles up if a provider subscribes to multi
	# mimetypes .

	# (Ticket #674)

	foreach my $class ( values %{ $self->get_providers } ) {
		my $resp = $class->resolve( $ref, $hints );
		push @refs, $resp if $resp;
		last if $resp;
	}
	return $refs[0];
}

sub resolve_uri {
	my ( $self, $uri, $hints ) = @_;
	my $resolver = $self->accept( $uri->scheme );
	return unless $resolver;
	my $doc = $resolver->resolve( $uri, $hints );
	return $doc;
}

sub browse {
	my ( $self, $docs ) = @_;
	if ( my $viewer = $self->viewer_for( $docs->mimetype ) ) {
		return $viewer->render($docs);
	}
	return;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
