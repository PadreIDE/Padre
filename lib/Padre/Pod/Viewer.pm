package Padre::Pod::Viewer;

=pod

=head1 NAME

Padre::Pod::Viewer - class for viewing pod

=head1 METHODS

=cut

use strict;
use warnings;
use Config;
use File::Spec           ();
use Pod::Simple::HTML    ();
use Pod::POM             ();
use Pod::POM::View::HTML ();
use Padre::Wx            ();
use Wx::Html             ();

our $VERSION = '0.23';

use base 'Wx::HtmlWindow';

our @pages;

=pod

=head2 module_to_path

Given the name of a module (Module::Name) or a pod file without the
.pod extension will try to locate it in @INC and return the full path.

If no file found, returns undef.

=cut

sub module_to_path {
	my $self   = shift;
	my $module = shift;

	my $root = $module;
	my $file = $module;
	$file =~ s{::}{/}g;
	my $path;

	my $poddir = File::Spec->catdir($Config{privlib}, 'pod');
	foreach my $dir ( $poddir, @INC) {
		my $fpath = File::Spec->catfile($dir, $file);
		if ( -e "$fpath.pm" ) {
			$path = "$fpath.pm";
		} elsif ( -e "$fpath.pod" ) {
			$path = "$fpath.pod";
		}
	}

	return $path;
}

sub display {
	my $self   = shift;
	my $module = shift;
	my $path   = $self->module_to_path($module);
	my $html;
	if ($path) {
		my $parser = Padre::Pod::Viewer::POD->new;
		$parser->start_html;
		$parser->parse_from_file($path);
		$html = $parser->get_html;
	} else {
		$html = "No documentation found for <em>$module</em>.";
	}
	$self->SetPage($html);
	return $self;    
}

sub OnLinkClicked {
	my $self  = shift;
	my $event = shift;
	my $href = $event->GetHref;
	if ($href =~ m{^http://}) {
		# launch real web browser to new page
		return;
	}
	my $path = $self->module_to_path($href);
	if ($path) {
		Padre::DB->add_recent_pod( $href);
		$self->display($href);
	} 
	return;
}

package Padre::Pod::Viewer::View;

use base 'Pod::POM::View::HTML';

sub _view_l {
	my ($self, $item) = @_;
	return '<h1>',
		$item->title->present($self),
		"</h1>\n",
		$item->content->present($self);
}

package Padre::Pod::Viewer::POD;

use base 'Pod::Parser';

my $html;

sub command {
	my ($parser, $command, $paragraph, $line_num) = @_;
	my %h = (
		head1 => 'h1',
		head2 => 'h2',
	);
	$paragraph =~ s/^\s*\n$//gm;
	if ($h{$command}) {
		chomp $paragraph;
		$html .= "<$h{$command}>$paragraph</$h{$command}>\n";
	} elsif ($command eq 'over') {
		$html .= "<ul>\n";
	} elsif ($command eq 'item') {
		$paragraph = _internals($paragraph);
		$html .= "<li>$paragraph</li>\n";
	} elsif ($command eq 'back') {
		$html .= "</ul>\n";
	} else {
		#warn "Unhandled command: '$command'\n";
	}
	return;
}

sub verbatim {
	my ($parser, $paragraph, $line_num) = @_;
	$paragraph =~ s/^\s*\n$//gm;
	$html .= "<pre>\n$paragraph</pre>\n";
	return;
}

sub textblock {
	my ($parser, $paragraph, $line_num) = @_;
	$paragraph =~ s/^\s*\n$//gm;
	$paragraph = _internals($paragraph);
	$html .= "<p>\n$paragraph</p>\n";
	return;
}

sub _internals {
	my ($paragraph) = @_;
	$paragraph =~ s{B<([^>]*)>}{<b>$1</b>}g;
	$paragraph =~ s{C<([^>]*)>}{<b>$1</b>}g;
	$paragraph =~ s{I<([^>]*)>}{<i>$1</i>}g;
	$paragraph =~ s{L<([^>]*)>}{<a href="$1">$1</a>}g;
	return $paragraph;
}

sub start_html {
	$html = '';
}

sub get_html {
	return $html;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
