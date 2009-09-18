package Padre::Wx::About;

# New super-shiny About dialog

use 5.008;
use strict;
use warnings;
use utf8;
use Padre::Wx             ();
use Padre::Wx::HtmlWindow ();
use Padre::Wx::Icon       ();
use Padre::Util           ();

our $VERSION = '0.46';
our @ISA     = 'Wx::Dialog';

sub new {
	my $class = shift;
	my $main  = shift;
	my $self  = $class->SUPER::new(
		undef,
		-1,
		Wx::gettext('About'),
		Wx::wxDefaultPosition,
		[ 700, 530 ],
	);

	# Until we get a real icon use the same one as the others
	$self->SetIcon( Padre::Wx::Icon::PADRE );

	# Create the content for the About window
	my $splash = Padre::Util::sharefile('padre-splash.bmp');
	$self->{about} = Padre::Wx::HtmlWindow->new($self);
	$self->{about}->SetPage( $self->_rtl(<<"END_HTML") );
<html>
  <body bgcolor="#EEEEEE">
    <strong>
    <font size="+4">Padre $VERSION</font>
    <font size="+1">&nbsp;&nbsp;Perl Application Development and Refactoring Environment</font>
    </strong>
    <p>Created by Gábor Szabó</p>
    <p>Copyright 2008 - 2009 The Padre Development Team</p>
    <p>Splash image courtesy of Jerry Charlotte</p>
    <p>
    <center>
        <img src="$splash">
    </center>
    </p>
  </body>
</html>
END_HTML

	# Create the content for the Developer team
	$self->{developers} = Padre::Wx::HtmlWindow->new($self);
	my $padre_dev_team = Wx::gettext('The Padre Development Team');
	$self->{developers}->SetPage( $self->_rtl(<<"END_HTML") );
<html>
  <body bgcolor="#EEEEEE">
    <strong><font size="+4">$padre_dev_team</font></strong>
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
            Sebastian Willing<br>
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
	my $padre_translation_team = Wx::gettext('The Padre Translation Team');
	$self->{translators}->SetPage( $self->_rtl(<<"END_HTML") );
<html>
  <body bgcolor="#EEEEEE">
    <strong><font size="+4">$padre_translation_team</font></strong>
    <table width="100%">
      <tr>
        <td valign="top">
          <p>
            <b>Arabic</b><br>
            Ahmad Zawawi - أحمد محمد زواوي<br>
            <br>
            <b>Chinese (Simplified)</b><br>
            Fayland Lam<br>
            <br>
            <b>Chinese (Traditional)</b><br>
            Matthew Lien - 練喆明<br>
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
            Heiko Jansen<br>
            Sebastian Willing
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
		Wx::wxAUI_NB_TOP | Wx::wxBORDER_NONE
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

	# Hide the dialog when the user presses the ESCape key or clicks Close button
	# Please see ticket:573
	$self->{sizer}->Add(
		Wx::Button->new( $self, Wx::wxID_CANCEL, Wx::gettext('&Close') ),
		0,
		Wx::wxALIGN_CENTER,
		0
	);
	$self->{sizer}->AddSpacer(0);

	$self->SetSizer( $self->{sizer} );

	return $self;
}

#
# Arabic and Hebrew names are not showing up correctly
#
sub _rtl {
	my ( $self, $text ) = @_;
	$text =~ s/(\p{InArabic}+)\s+(\p{InArabic}+)\s+(\p{InArabic}+)/$3 $2 $1/g;
	$text =~ s/(\p{InHebrew}+)\s+(\p{InHebrew}+)/$2 $1/g;
	return $text;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
