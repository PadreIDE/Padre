package Padre::Wx::Dialog::ModuleStart;

# Module::Start widget of Padre

use 5.008;
use strict;
use warnings;
use Cwd               ();
use File::Spec        ();
use Padre::Wx         ();
use Padre::Wx::Dialog ();

our $VERSION = '0.50';

sub get_layout {

	my @builders = ( 'Module::Build', 'ExtUtils::MakeMaker', 'Module::Install' );
	my @licenses = qw(apache artistic artistic_2 bsd gpl lgpl mit mozilla open_source perl restrictive unrestricted);

	# licenses list taken from
	# http://search.cpan.org/dist/Module-Build/lib/Module/Build/API.pod
	# even though it should be in http://module-build.sourceforge.net/META-spec.html
	# and we should fetch it from Module::Start or maybe Software::License

	my @layout = (
		[   [ 'Wx::StaticText', undef,           Wx::gettext('Module Name:') ],
			[ 'Wx::TextCtrl',   '_module_name_', '' ],
		],
		[   [ 'Wx::StaticText', undef,           Wx::gettext('Author:') ],
			[ 'Wx::TextCtrl',   '_author_name_', '' ],
		],
		[   [ 'Wx::StaticText', undef,     Wx::gettext('Email:') ],
			[ 'Wx::TextCtrl',   '_email_', '' ],
		],
		[   [ 'Wx::StaticText', undef, Wx::gettext('Builder:') ],
			[ 'Wx::ComboBox', '_builder_choice_', '', \@builders ],
		],
		[   [ 'Wx::StaticText', undef, Wx::gettext('License:') ],
			[ 'Wx::ComboBox', '_license_choice_', '', \@licenses ],
		],
		[   [ 'Wx::StaticText', undef, Wx::gettext('Parent Directory:') ],
			[ 'Wx::DirPickerCtrl', '_directory_', '', Wx::gettext('Pick parent directory') ],
		],
		[   [ 'Wx::Button', '_ok_',     Wx::wxID_OK ],
			[ 'Wx::Button', '_cancel_', Wx::wxID_CANCEL ],
		],
	);
	return \@layout;
}

sub start {
	my ( $class, $main ) = @_;

	my $dialog = $class->dialog($main);
	$dialog->Show(1);

	return;
}

sub dialog {
	my ( $class, $parent ) = @_;

	my $config = Padre->ide->config;

	my $layout = get_layout();
	my $dialog = Padre::Wx::Dialog->new(
		parent => $parent,
		title  => Wx::gettext("Module Start"),
		layout => $layout,
		width  => [ 100, 200 ],
		bottom => 20,
	);

	$dialog->{_widgets_}->{_author_name_}->SetValue( $config->identity_name );
	$dialog->{_widgets_}->{_email_}->SetValue( $config->identity_email );
	if ( $config->builder ) {
		$dialog->{_widgets_}->{_builder_choice_}->SetValue( $config->builder );
	} else {
		$dialog->{_widgets_}->{_builder_choice_}->SetValue('ExtUtils::MakeMaker');
	}
	if ( $config->license ) {
		$dialog->{_widgets_}->{_license_choice_}->SetValue( $config->license );
	} else {
		$dialog->{_widgets_}->{_license_choice_}->SetValue('restrictive');
	}
	$dialog->{_widgets_}->{_directory_}->SetPath( $config->module_start_directory );

	$dialog->{_widgets_}->{_ok_}->SetDefault;
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}->{_ok_},     \&ok_clicked );
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}->{_cancel_}, \&cancel_clicked );

	$dialog->{_widgets_}->{_module_name_}->SetFocus;

	return $dialog;
}

sub cancel_clicked {
	my ( $dialog, $event ) = @_;

	$dialog->Destroy;

	return;
}

sub ok_clicked {
	my ( $dialog, $event ) = @_;

	my $data = $dialog->get_data;
	$dialog->Destroy;

	my $main = Padre->ide->wx->main;

	# TODO improve input validation !
	my @fields = qw(_module_name_ _author_name_ _email_ _builder_choice_ _license_choice_);
	foreach my $f (@fields) {
		if ( not $data->{$f} ) {
			Wx::MessageBox(
				sprintf( Wx::gettext("Field %s was missing. Module not created."), $f ),
				Wx::gettext("missing field"), Wx::wxOK, $main
			);
			return;
		}
	}

	my $config = Padre->ide->config;
	$config->set( 'identity_name',          $data->{_author_name_} );
	$config->set( 'identity_email',         $data->{_email_} );
	$config->set( 'builder',                $data->{_builder_choice_} );
	$config->set( 'license',                $data->{_license_choice_} );
	$config->set( 'module_start_directory', $data->{_directory_} );

	my $pwd = Cwd::cwd();
	chdir $data->{_directory_};
	eval {
		require Module::Starter::App;
		@ARGV = (
			'--module',  $data->{_module_name_},
			'--author',  $data->{_author_name_},
			'--email',   $data->{_email_},
			'--builder', $data->{_builder_choice_},
			'--license', $data->{_license_choice_},
		);
		Module::Starter::App->run;
		@ARGV = ();
	};
	chdir $pwd;

	if ($@) {
		Wx::MessageBox(
			sprintf(
				Wx::gettext("An error has occured while generating '%s':\n%s"),
				$data->{_module_name_}, $@
			),
			Wx::gettext("Error"),
			Wx::wxOK | Wx::wxCENTRE,
			$main
		);
		return;
	}

	my $ret = Wx::MessageBox(
		sprintf( Wx::gettext("%s apparently created. Do you want to open it now?"), $data->{_module_name_} ),
		Wx::gettext("Done"),
		Wx::wxYES_NO | Wx::wxCENTRE,
		$main,
	);
	if ( $ret == Wx::wxYES ) {
		my $module_name = $data->{_module_name_};
		($module_name) = split( ',', $module_name ); # for Foo::Bar,Foo::Bat
		                                             # prepare Foo-Bar/lib/Foo/Bar.pm
		my @parts = split( '::', $module_name );
		my $dir_name = join( '-', @parts );
		$parts[-1] .= '.pm';
		my $file = File::Spec->catfile( $data->{_directory_}, $dir_name, 'lib', @parts );
		Padre::DB::History->create(
			type => 'files',
			name => $file,
		);
		$main->setup_editor($file);
		$main->refresh;
	}

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

