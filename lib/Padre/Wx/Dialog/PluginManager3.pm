package Padre::Wx::Dialog::PluginManager3;

# Third-generation plugin manager

use strict;
use warnings;

use Carp                    qw{ croak };

use URI::file               ();
use Params::Util            qw{_INSTANCE};
use Padre::Util             ();
use Padre::Wx               ();
use Padre::Wx::Dialog::HTML ();

our $VERSION = '0.29';
use base 'Wx::Frame';

sub new {
	my ($class, $parent, $manager) = @_;

	croak "Missing or invalid Padre::PluginManager object"
		unless $manager->isa('Padre::PluginManager');

	# create object
	my $self = $class->SUPER::new(
		$parent,
		-1,
	Wx::gettext('Plugin Manager'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxDEFAULT_FRAME_STYLE,
	);

	# create list
	my $list = Wx::ListView->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_REPORT| Wx::wxLC_SINGLE_SEL
	);
	$list->InsertColumn( 0, Wx::gettext('Icon') );
	$list->InsertColumn( 1, Wx::gettext('Name') );
	$list->InsertColumn( 2, Wx::gettext('Version') );
	$list->InsertColumn( 3, Wx::gettext('Status') );
	$self->{list} = $list;

	$self->{manager} = $manager;

	return $self;
}


sub show {
	my $self = shift;
	$self->Show;
}

# Render the content of the dialog based on the plugins
sub html {
	my $self    = shift;
	my $manager = $self->{manager};
	return '' unless defined $manager;

	my @rows = ();
	my $file = Padre::Util::sharefile('plugin.png');
	unless ( -f $file ) {
		die "Failed to find $file";
	}
	my $icon = URI::file->new( $file )->as_string;
	foreach my $name ( $manager->plugin_names ) {
		my $plugin   = $manager->_plugin($name);
		my $namehtml = "<b>"  . $plugin->plugin_name . "</b>";
		my $version  = $plugin->version || '???';
		my $cellhtml = "<td bgcolor='#FFFFFF'>"
			. $namehtml
			. "&nbsp;&nbsp;&nbsp;"
			. $version
			. "</td>";
		my $rowhtml  = "<tr>"
			. "<td width='32'><img src='$icon' height='16' width='16'></td>"
			. $cellhtml
			. "</tr>";
		push @rows, $rowhtml;
	}

	# Wrap in the overall page
	my $rowshtml = join( "\n", @rows );
	return <<"END_HTML";
<html>
<head>
</head>
<body bgcolor="#CCCCCC">
<table border="1" cellpadding="10" cellspacing="0" width="100%">
$rowshtml
</table>
</body>
</html>
END_HTML
}

1;
# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
