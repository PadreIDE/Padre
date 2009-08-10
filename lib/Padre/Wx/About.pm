package Padre::Wx::About;

# New super-shiny About dialog

use 5.008;
use strict;
use warnings;
use utf8;
use Padre::Wx             ();
use Padre::Wx::HtmlWindow ();

our $VERSION = '0.43';
our @ISA     = 'Wx::Dialog';

sub new {
	my $class = shift;
	my $main  = shift;
	my $self  = $class->SUPER::new(
		undef,
		-1,
		Wx::gettext('About'),
		Wx::wxDefaultPosition,
		[ 700, 500 ],
	);

	# Until we get a real icon use the same one as the others
	$self->SetIcon( Wx::GetWxPerlIcon() );

	# Create the content for the About window
	$self->{about} = Padre::Wx::HtmlWindow->new($self);
	$self->{about}->SetPage(<<"END_HTML");
<html>
  <body bgcolor="#EEEEEE">
    <h1>Padre $VERSION</h1>
    <p>Perl Application Development and Refactoring Environment</p>
    <p>Created by Gábor Szabó</p>
    <p>Copyright 2008 - 2009 The Padre Development Team</p>
    <p>Splash image courtesy XYZ</p>
  </body>
</html>
END_HTML

	# Create the content for the Developer team
	$self->{developers} = Padre::Wx::HtmlWindow->new($self);
	$self->{developers}->SetPage(<<'END_HTML');
<html>
  <body bgcolor="#EEEEEE">
    <h1>The Padre Development Team</h1>
    <table width="100%" cellpadding="0" cellspacing="0">
      <tr>
        <td valign="top">
          <p>
            Adam Kennedy<br>
            <br>
            Ahmad Zawawi - أحمد محمد زواوي<br>
            <br>
            Breno G. de Oliveira<br>
            <br>
            Brian Cassidy<br>
            <br>
            Cezary Morga<br>
            <br>
            Chris Dolan<br>
            <br>
            Claudio Ramirez<br>
            <br>
            Fayland Lam<br>
            <br>
            Gábor Szabó - גאבור סבו <br>
            <br>
            Heiko Jansen<br>
          </p>
        </td>
        <td valign="top">
          <p>
            Jérôme Quelin<br>
            <br>
            Kaare Rasmussen<br>
            <br>
            Keedi Kim - 김도형<br>
            <br>
            Kenichi Ishigaki - 石垣憲一<br>
            <br>
            Max Maischein<br>
            <br>
            Patrick Donelan<br>
            <br>
            Paweł Murias<br>
            <br>
            Petar Shangov<br>
            <br>
            Steffen Müller<br>
          </p>
        </td>
      </td>
    </table>
</html>
END_HTML

	# Create the content for the Translation team
	$self->{translators} = Padre::Wx::HtmlWindow->new($self);
	$self->{translators}->SetPage(<<'END_HTML');
<html>
  <body bgcolor="#EEEEEE">
    <h1>The Padre Translation Team</h1>
    <table width="100%">
      <tr>
        <td valign="top">
          <p>
            <b>Arabic</b><br>
            Ahmad Zawawi - أحمد محمد زواوي<br>
            <br>
            <b>Chinese (Traditional)</b><br>
            Matthew Lien - 練喆明</b><br>
            <br>
            <b>Czech</b><br>
            Marcela Mašláňová<br>
            <br>
            <b>Dutch</b><br>
            Dirk De Nijs<br>
            <br>
            <b>French</b><br>
            Jérôme Quelin<br>
            <br>
            <b>German</b><br>
            Heiko Jansen
          </p>
        </td>
        <td valign="top">
          <p>
            <b>Hebrew</b><br>
            Omer Zak - עומר זק<br>
            Shlomi Fish - שלומי פיש<br>
            Amir E. Aharoni - אמיר א. אהרוני<br>
            <br>
            <b>Hungarian</b><br>
            György Pásztor<br>
            <br>
            <b>Italian</b><br>
            Simone Blandino<br>
            <br>
            <b>Japanese</b><br>
            Kenichi Ishigaki - 石垣憲一<br>
            <br>
            <b>Korean</b><br>
            Keedi Kim - 김도형
          </p>
        </td>
        <td valign="top">
          <p>
            <b>Norwegian</b><br>
            Kjetil Skotheim<br>
            <br>
            <b>Polish</b><br>
            Cezary Morga<br>
            <br>
            <b>Portuguese (Brazil)</b><br>
            Breno G. de Oliveira<br>
            <br>
            <b>Spanish</b><br>
            Paco Alguacil<br>
            Enrique Nell<br>
            <br>
            <b>Russian</b><br>
            Andrew Shitov
          </p>
        </td>
      </td>
    </table>
  </body>
</html>

END_HTML

	# Layout for the About dialog
	$self->{notebook} = Wx::AuiNotebook->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxAUI_NB_TOP
		| Wx::wxBORDER_NONE
	);
	$self->{notebook}->AddPage(
		$self->{about},
		'  ' . Wx::gettext('Padre') . '  ',
		1,
	);
	$self->{notebook}->AddPage(
		$self->{developers},
		'  ' . Wx::gettext('Development') . '  ',
		1,
	);
	$self->{notebook}->AddPage(
		$self->{translators},
		'  ' . Wx::gettext('Translation') . '  ',
		1,
	);
	$self->{notebook}->SetSelection(0);

	$self->{sizer} = Wx::FlexGridSizer->new( 1, 1, 10, 10 );
	$self->{sizer}->AddGrowableCol(0);
	$self->{sizer}->AddGrowableRow(0);
	$self->{sizer}->Add( $self->{notebook}, 0, Wx::wxGROW | Wx::wxEXPAND, 0 );
	# $self->{sizer}->Fit($self);
	# $self->{sizer}->SetSizeHints($self);
	$self->SetSizer($self->{sizer});
	# $self->SetAutoLayout(1);

	return $self;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
