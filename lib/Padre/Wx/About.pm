package Padre::Wx::About;

# New super-shiny About dialog

use 5.008;
use strict;
use warnings;
use utf8;
use Padre::Wx               ();
use Padre::Wx::HtmlWindow   ();
use Padre::Wx::Icon         ();
use Padre::Config           ();
use Padre::Util             ();
use Wx::Perl::ProcessStream ();
use PPI                     ();

our $VERSION = '0.90';
our @ISA     = 'Wx::Dialog';

sub new {
	my $class = shift;
	my $main  = shift;
	my $self  = $class->SUPER::new(
		undef,
		-1,
		Wx::gettext('About Padre'),
		Wx::wxDefaultPosition,
		[ 700, 600 ],
	);

	# Until we get a real icon use the same one as the others
	$self->SetIcon(Padre::Wx::Icon::PADRE);

	# Create the content for the About window
	$self->{about} = Padre::Wx::HtmlWindow->new($self);
	$self->_content_about;

	# Create the content for the Developer team
	$self->{developers} = Padre::Wx::HtmlWindow->new($self);
	$self->_content_developers;

	# Create the content for the Translation team
	$self->{translators} = Padre::Wx::HtmlWindow->new($self);
	$self->_content_translators;

	# Create the content for the Info page
	$self->{info} = Padre::Wx::HtmlWindow->new($self);

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
	$self->{notebook}->AddPage(
		$self->{info},
		'  ' . Wx::gettext('System Info') . '  ',
		1,
	);
	$self->{notebook}->SetSelection(0);

	$self->{sizer} = Wx::FlexGridSizer->new( 1, 1, 10, 10 );
	$self->{sizer}->AddGrowableCol(0);
	$self->{sizer}->AddGrowableRow(0);
	$self->{sizer}->Add( $self->{notebook}, 0, Wx::wxGROW | Wx::wxEXPAND, 0 );

	# Hide the dialog when the user presses the ESCape key or clicks Close button
	# Please see ticket:573
	my $button = Wx::Button->new( $self, Wx::wxID_CANCEL, Wx::gettext('&Close') );
	$self->{sizer}->Add( $button, 0, Wx::wxALIGN_CENTER, 0 );
	$self->{sizer}->AddSpacer(0);
	$self->SetSizer( $self->{sizer} );

	# The close button is focused in case the user presses an ENTER
	$button->SetFocus;

	return $self;
}

sub _content_about {

	# Create the content for the About window
	my $self           = shift;
	my $splash         = Padre::Util::splash();
	my $created_by     = Wx::gettext('Created by');
	my $padre_dev_team = Wx::gettext('The Padre Development Team');
	my $license_info =
		Wx::gettext('Padre is free software; you can redistribute it and/or modify it under the same terms as Perl 5.');
	my $splash_name        = Wx::gettext('Blue butterfly on a green leaf');
	my $splash_description = Wx::gettext('splash image is based on work by');
	$self->{about}->SetPage( $self->_rtl(<<"END_HTML") );
<html>
  <body bgcolor="#EEEEEE">
    <strong>
    <font size="+4">Padre $VERSION</font>
    <font size="+1">&nbsp;&nbsp;Perl Application Development and Refactoring Environment</font>
    </strong>
    <p>$created_by Gábor Szabó</p>
    <p>
    <center>
        <img src="$splash">
    </center>
    </p>
    <p><small>"$splash_name" - $splash_description Jerry Charlotte (blackbutterfly)</small></p>
    <p>
      Copyright 2008&ndash;2011 $padre_dev_team<br>
      $license_info
    </p>
  </body>
</html>
END_HTML
}

sub _content_developers {

	# Create the content for the Developer team
	my $self           = shift;
	my $padre_dev_team = Wx::gettext('The Padre Development Team');
	$self->{developers}->SetPage( $self->_rtl(<<"END_HTML") );
<html>
  <body bgcolor="#EEEEEE">
    <strong><font size="+4">$padre_dev_team</font></strong>
    <table width="100%" cellpadding="0" cellspacing="0">
      <tr>
        <td valign="top">
          <p>
            <br>
            <br>
            Aaron Trevena<br>
            <br>
            Adam Kennedy<br>
            <br>
            Ahmad Zawawi - أحمد محمد زواوي<br>
            <br>
            Alexandr Ciornii<br>
            <br>
            Blake Willmarth<br>
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
            Tom Eliaz<br>
          </p>
        </td>
        <td valign="top">
          <p>
            <br>
            <br>
            code4pay (pseudonym only)<br>
            <br>
            Fayland Lam<br>
            <br>
            Gabriel Vieira<br>
            <br>
            Gábor Szabó - גאבור סבו <br>
            <br>
            Heiko Jansen<br>
            <br>
            Jérôme Quelin<br>
            <br>
            Kaare Rasmussen<br>
            <br>
            Kartik Thakore<br>
            <br>
            Keedi Kim - 김도형<br>
            <br>
            Kenichi Ishigaki - 石垣憲一<br>
          </p>
        </td>
        <td valign="top">
          <p>
            <br>
            <br>
            Max Maischein<br>
            <br>
            Olivier Mengué<br>
            <br>
            Patrick Donelan<br>
            <br>
            Paweł Murias<br>
            <br>
            Petar Shangov<br>
            <br>
            Peter Lavender<br>
            <br>
            Ryan Niebur<br>
            <br>
            Sebastian Willing<br>
            <br>
            Steffen Müller<br>
            <br>
            Zeno Gantner<br>
          </p>
        </td>
      </td>
    </table>
</html>
END_HTML
}

sub _content_translators {

	# Create the content for the Translation team
	my $self                   = shift;
	my $padre_translation_team = Wx::gettext('The Padre Translation Team');
	my %language               = Padre::Locale::menu_view_languages();
	$self->{translators}->SetPage( $self->_rtl(<<"END_HTML") );
<html>
  <body bgcolor="#EEEEEE">
    <strong><font size="+4">$padre_translation_team</font></strong>
    <table width="100%">
      <tr>
        <td valign="top">
          <p>
            <b>$language{'ar'}</b><br>
            Ahmad Zawawi - أحمد محمد زواوي<br>
            <br>
            <b>$language{'zh-cn'}</b><br>
            Fayland Lam<br>
            Chuanren Wu<br>
            <br>
            <b>$language{'zh-tw'}</b><br>
            BlueT - Matthew Lien - 練喆明<br>
            <br>
            <b>$language{'cz'}</b><br>
            Marcela Mašláňová<br>
            <br>
            <b>$language{'nl-nl'}</b><br>
            Dirk De Nijs<br>
            <br>
            <b>$language{'fr-fr'}</b><br>
            Jérôme Quelin<br>
            Olivier Mengué<br>
          </p>
        </td>
        <td valign="top">
          <p>
            <b>$language{'de'}</b><br>
            Heiko Jansen<br>
            Sebastian Willing<br>
            Zeno Gantner<br>
            <br>
            <b>$language{'he'}</b><br>
            Omer Zak - עומר זק<br>
            Shlomi Fish - שלומי פיש<br>
            Amir E. Aharoni - אמיר א. אהרוני<br>
            <br>
            <b>$language{'hu'}</b><br>
            György Pásztor<br>
            <br>
            <b>$language{'it-it'}</b><br>
            Simone Blandino<br>
            <br>
            <b>$language{'ja'}</b><br>
            Kenichi Ishigaki - 石垣憲一<br>
          </p>
        </td>
        <td valign="top">
          <p>
            <b>$language{'ko'}</b><br>
            Keedi Kim - 김도형<br>
            <br>
            <b>$language{'no'}</b><br>
            Kjetil Skotheim<br>
            <br>
            <b>$language{'pl'}</b><br>
            Cezary Morga<br>
            <br>
            <b>$language{'pt-br'}</b><br>
            Breno G. de Oliveira<br>
            Gabriel Vieira<br>
            <br>
            <b>$language{'es-es'}</b><br>
            Paco Alguacil<br>
            Enrique Nell<br>
            <br>
            <b>$language{'ru'}</b><br>
            Andrew Shitov<br>
            <br>
            <b>$language{'tr'}</b><br>
            Burak Gürsoy
          </p>
        </td>
      </td>
    </table>
  </body>
</html>

END_HTML
}

# Create the content for the Info page
sub _content_info {
	my $self           = shift;
	my $padre_info     = Wx::gettext('System Info');
	my $config_dir_txt = Wx::gettext('Config:');
	my $config_dir     = Padre::Constant::CONFIG_DIR;

	# Reformat the native wxWidgets version string slightly
	my $wx_widgets = Wx::wxVERSION_STRING();
	$wx_widgets =~ s/^wx\w+\s+//;

	# Calculate the process uptime
	my $uptime = time - $^T;
	my @uptime_parts = ( 0, 0, 0 );
	if ( $uptime > 3600 ) {
		$uptime_parts[0] = int( $uptime / 3600 );
		$uptime -= $uptime_parts[0] * 3600;
	}
	if ( $uptime > 60 ) {
		$uptime_parts[1] = int( $uptime / 60 );
		$uptime -= $uptime_parts[1] * 60;
	}
	$uptime_parts[2] = $uptime;
	my $uptime_text = Wx::gettext('Uptime');
	$uptime = sprintf( '%d:%02d:%02d', @uptime_parts );

	# Calculate the current memory in use across all threads
	my $ram = Padre::Util::humanbytes( Padre::Util::process_memory() ) || '0';
	$ram = '(' . Wx::gettext('unsupported') . ')' if $ram eq '0';

	# Yes, THIS variable should have this upper case char :-)
	my $Perl_version = $^V || $];
	$Perl_version = "$Perl_version";
	$Perl_version =~ s/^v//;

	# How many threads are running
	my $threads = $INC{'threads.pm'} ? scalar( threads->list ) : 'disabled';

	eval { require Alien::wxWidgets };
	my $alien = $Alien::wxWidgets::VERSION;

	my $wx_scintilla_html = '';
	if ( Padre::Config::wx_scintilla_ready() ) {
		$wx_scintilla_html = <<"END_HTML";
      <tr>
        <td valign="top">Wx::Scintilla</td>
        <td>$Wx::Scintilla::VERSION</td>
      </tr>
END_HTML
	}

	$self->{info}->SetPage( $self->_rtl(<<"END_HTML") );
<html>
  <body bgcolor="#EEEEEE">
    <strong><font size="+4">$padre_info</font></strong>
    <table width="100%">
      <tr>
        <td valign="top">
        Perl
        </td>
        <td>
        $Perl_version
        </td>
      </tr>
      <tr>
        <td valign="top">
        Wx
        </td>
        <td>
        $Wx::VERSION
        </td>
      </tr>
      <tr>
        <td valign="top">wxWidgets</td>
        <td>$wx_widgets</td>
      </tr>
      <tr>
        <td valign="top">Alien::wxWidgets</td>
        <td>$alien</td>
      </tr>
      <tr>
        <td valign="top">
        Wx::Perl::ProcessStream
        </td>
        <td>
        $Wx::Perl::ProcessStream::VERSION
        </td>
      </tr>
      $wx_scintilla_html
      <tr>
        <td valign="top">
        PPI
        </td>
        <td>
        $PPI::VERSION
        </td>
      </tr>
      <tr>
        <td valign="top">$config_dir_txt</td><td>$config_dir</td>
      </tr>
      <tr>
        <td valign="top">
        $uptime_text:
        </td>
        <td>
        $uptime
        </td>
      </tr>
      <tr>
        <td valign="top">
        RAM:
        </td>
        <td>
        $ram
        </td>
      </tr>
      <tr>
        <td valign="top">
        Threads:
        </td>
        <td>
        $threads
        </td>
      </tr>
    </table>
  </body>
</html>
END_HTML

}

sub ShowModal {
	my $self = shift;
	$self->_content_info;
	return $self->SUPER::ShowModal;
}

# Arabic and Hebrew names are not showing up correctly
sub _rtl {
	my $text = $_[1];
	$text =~ s/(\p{InArabic}+)\s+(\p{InArabic}+)\s+(\p{InArabic}+)/$3 $2 $1/g;
	$text =~ s/(\p{InHebrew}+)\s+(\p{InHebrew}+)/$2 $1/g;
	return $text;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
