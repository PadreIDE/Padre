package Padre::Plugin::Devel;

use 5.008;
use strict;
use warnings;
use File::Spec     ();
use File::Basename ();
use Data::Dumper   ();
use Padre::Util    ();
use Padre::Wx      ();

use base 'Padre::Plugin';

our $VERSION = '0.20';

sub padre_interfaces {
	'Padre::Plugin' => 0.18,
}

sub plugin_name {
	return 'Development Tools';
}

sub menu_plugins_simple {
	my $self = shift;
	return $self->plugin_name => [
		'Show %INC' => sub { $self->show_inc },
		'Info'      => sub { $self->info     },
		'About'     => sub { $self->about    },
	];
}

sub show_inc {
	my $self = shift;
	my $main = Padre->ide->wx->main_window;
	Wx::MessageBox(
		Data::Dumper::Dumper(\%INC),
		'%INC',
		Wx::wxOK | Wx::wxCENTRE,
		$main,
	);
}

sub about {
	my $self = shift;

	my $about = Wx::AboutDialogInfo->new;
	$about->SetName("Padre::Plugin::Devel");
	$about->SetDescription(
		"A set of unrelated tools used by the Padre developers\n" .
		"Some of these might end up in core Padre or in oter plugins"
	);

	Wx::AboutBox( $about );
	return;
}

sub info {
	my $self = shift;
	my $main = Padre->ide->wx->main_window;
	my $doc  = Padre::Documents->current;
	if ( $doc ) {
		my $msg = '';
		$msg   .= "Doc object: $doc\n";
		$main->message( $msg, 'Info' );
	} else {
		$main->message( 'No file is open', 'Info' );
	}
	return;
}

1;

__END__

=pod

=head1 NAME

Padre::Plugin::Devel - tools used by the Padre developers

=head1 DESCRIPTION

=head2 Show %INC

Dumper %INC

=head2 Info

=head2 About

=head1 AUTHOR

Gabor Szabo

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
