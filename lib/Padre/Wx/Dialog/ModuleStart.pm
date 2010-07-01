package Padre::Wx::Dialog::ModuleStart;

# Module::Start widget of Padre

use 5.008;
use strict;
use warnings;
use Cwd               ();
use File::Spec        ();
use Padre::Wx         ();
use Padre::Wx::Dialog ();

our $VERSION = '0.65';

our %license_id = ( # TODO: check for other module builders as well
	Wx::gettext('Apache License')         => 'apache',       ## TODO: does not work w/ Module::Build
	Wx::gettext('Artistic License 1.0')   => 'artistic',     ## TODO: does not work w/ Module::Build
	Wx::gettext('Artistic License 2.0')   => 'artistic_2',   ## TODO: does not work w/ Module::Build
	Wx::gettext('Revised BSD License')    => 'bsd',
	Wx::gettext('GPL 2 or later')         => 'gpl',
	Wx::gettext('LGPL 2.1 or later')      => 'lgpl',
	Wx::gettext('MIT License')            => 'mit',
	Wx::gettext('Mozilla Public License') => 'mozilla',      ## TODO: does not work w/ Module::Build
	Wx::gettext('Open Source')            => 'open_source',  ## TODO: does not work w/ Module::Build
	Wx::gettext('Perl licensing terms')   => 'perl',
	Wx::gettext('restrictive')            => 'restrictive',  ## TODO: does not work w/ Module::Build
	Wx::gettext('unrestricted')           => 'unrestricted', ## TODO: does not work w/ Module::Build
);

# licenses list taken from
# http://search.cpan.org/dist/Module-Build/lib/Module/Build/API.pod
# even though it should be in http://module-build.sourceforge.net/META-spec.html
# and we should fetch it from Module::Start or maybe Software::License


sub get_layout {
	my @builders = ( 'Module::Build', 'ExtUtils::MakeMaker', 'Module::Install' ); # TODO: what about Module::Starter?

	my @layout = (
		[   [ 'Wx::StaticText', undef,           Wx::gettext('Module Name:') ],
			[ 'Wx::TextCtrl',   '_module_name_', '' ],
		],
		[   [ 'Wx::StaticText', undef,           Wx::gettext('Author:') ],
			[ 'Wx::TextCtrl',   '_author_name_', '' ],
		],
		[   [ 'Wx::StaticText', undef,     Wx::gettext('Email Address:') ],
			[ 'Wx::TextCtrl',   '_email_', '' ],
		],
		[   [ 'Wx::StaticText', undef, Wx::gettext('Builder:') ],
			[ 'Wx::ComboBox', '_builder_choice_', '', \@builders, Wx::wxCB_READONLY ],
		],
		[   [ 'Wx::StaticText', undef,              Wx::gettext('License:') ],
			[ 'Wx::ComboBox',   '_license_choice_', '', [ keys %license_id ], Wx::wxCB_SORT ],

			# TODO: SORT does not seem to work on Linux
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
		title  => Wx::gettext('Module Start'),
		layout => $layout,
		width  => [ 200, 300 ],
		bottom => 10,
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
		$dialog->{_widgets_}->{_license_choice_}->SetValue( Wx::gettext('Perl licensing terms') );
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
				sprintf( Wx::gettext('Field %s was missing. Module not created.'), $f ),
				Wx::gettext('missing field'), Wx::wxOK, $main
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
	my $parent_dir = $data->{_directory_} eq '' ? './' : $data->{_directory_};
	chdir $parent_dir;
	eval {
		require Module::Starter::App;
		local @ARGV = (
			'--module',  $data->{_module_name_},
			'--author',  $data->{_author_name_},
			'--email',   $data->{_email_},
			'--builder', $data->{_builder_choice_},
			'--license', exists $license_id{ $data->{_license_choice_} }
			? $license_id{ $data->{_license_choice_} }
			: $data->{_license_choice_},
		);
		Module::Starter::App->run;
	};
	chdir $pwd;

	if ($@) {
		Wx::MessageBox(
			sprintf(
				Wx::gettext("An error has occured while generating '%s':\n%s"),
				$data->{_module_name_}, $@
			),
			Wx::gettext('Error'),
			Wx::wxOK | Wx::wxCENTRE,
			$main
		);
		return;
	}

	my $module_name = $data->{_module_name_};
	($module_name) = split( ',', $module_name ); # for Foo::Bar,Foo::Bat
	                                             # prepare Foo-Bar/lib/Foo/Bar.pm
	my @parts = split( '::', $module_name );
	my $dir_name = join( '-', @parts );
	$parts[-1] .= '.pm';
	my $file = File::Spec->catfile( $parent_dir, $dir_name, 'lib', @parts );
	Padre::DB::History->create(
		type => 'files',
		name => $file,
	);
	$main->setup_editor($file);
	$main->refresh;

	return;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

