package Padre::Wx::HtmlWindow;

=pod

=head1 NAME

Padre::Wx::HtmlWindow - Padre-enhanced version of L<Wx::HtmlWindow>

=head1 DESCRIPTION

C<Padre::Wx::HtmlWindow> provides a Padre-specific subclass of
L<Wx::HtmlWindow> that adds some additional features, primarily
default support for L<pod2html> functionality.

=head1 METHODS

C<Padre::Wx::HtmlWindow> implements all the methods described in
the documentation for L<Wx::HtmlWindow>, and adds some additional
methods.

=cut

use 5.008;
use strict;
use warnings;
use Params::Util ();
use Padre::Wx ();
use Padre::Wx 'Html';
use Padre::Role::Task ();

our $VERSION    = '0.94';
our $COMPATIBLE = '0.93';
our @ISA        = qw{
	Padre::Role::Task
	Wx::HtmlWindow
};

use constant LOADING => <<'END_HTML';
<html>
<body>
Loading...
</body>
</html>
END_HTML

use constant ERROR => <<'END_HTML';
<html>
<body>
Failed to render page
</body>
</html>
END_HTML





#####################################################################
# Foreground Loader Methods

=pod

=head2 load_file

  $html_window->load_file('my.pod');

The C<load_file> method takes a file name, loads the file, transforms
it to HTML via the default Padre::Pod2HTML processor, and then loads
the HTML into the window.

Returns true on success, or throws an exception on error.

=cut

sub load_file {
	my $self = shift;
	my $file = shift;

	# Spawn the rendering task
	$self->task_reset;
	$self->task_request(
		task      => 'Padre::Task::Pod2HTML',
		on_finish => '_finish',
		file      => $file,
	);

	# Place a temporary message in the HTML window
	$self->SetPage( LOADING );
}

=pod

=head2 load_file

  $html_window->load_pod( "=head1 NAME\n" );

The C<load_file> method takes a string of POD content, transforms
it to HTML via the default Padre::Pod2HTML processor, and then loads
the HTML into the window.

Returns true on success, or throws an exception on error.

=cut

sub load_pod {
	my $self = shift;
	my $text = shift;

	# Spawn the rendering task
	$self->task_reset;
	$self->task_request(
		task      => 'Padre::Task::Pod2HTML',
		on_finish => '_finish',
		text      => $text,
	);

	# Place a temporary message in the HTML window
	$self->SetPage( LOADING );
}

=pod

=head2 load_html

  $html_window->load_html( "<head><body>Hello World!</body></html>" );

The C<load_html> method takes a string of HTML content, and loads the
HTML into the window.

The method is provided mainly as a convenience, it's main role is to act
as the callback handler for background rendering tasks.

=cut

sub load_html {
	my $self = shift;
	my $html = shift;

	# Handle task callback events
	if ( Params::Util::_INSTANCE($html, 'Padre::Task::Pod2HTML') ) {
		if ( $html->errstr ) {
			$html = $html->errstr;
		} elsif ( $html->html ) {
			$html = $html->html;
		} else {
			$html = ERROR;
		}
	}

	# Render the HTML document
	if ( defined Params::Util::_STRING($html) ) {
		$self->SetPage($html);
		return 1;
	}

	# No idea what this is
	return;
}

1;

__END__

=pod

=head1 SUPPORT

See the main L<Padre> documentation.

=head1 AUTHOR

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 COPYRIGHT

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
