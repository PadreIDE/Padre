package Padre::Wx::Dialog::ModuleStart;

use 5.008;
use strict;
use warnings;
use Data::Dumper qw(Dumper);
use Cwd          ();

# Module::Start widget of Padre

use Padre::Wx         ();
use Padre::Wx::Dialog ();
use Wx::Locale        qw(:default);
use File::Spec        ();

our $VERSION = '0.20';

sub get_layout {
	my ($config) = @_;

	my @builders = ('Module::Build', 'ExtUtils::MakeMaker'); #, 'Module::Install');
	my @licenses = qw(apache artistic artistic_2 bsd gpl lgpl mit mozilla open_source perl restrictive unrestricted);
	# licenses list taken from 
	# http://search.cpan.org/dist/Module-Build/lib/Module/Build/API.pod
	# even though it should be in http://module-build.sourceforge.net/META-spec.html
	# and we should fetch it from Module::Start or maybe Software::License

	my @layout = (
		[
			[ 'Wx::StaticText', undef,              gettext('Module Name:')],
			[ 'Wx::TextCtrl',   '_module_name_',    ''],
		],
		[
			[ 'Wx::StaticText', undef,              gettext('Author:')],
			[ 'Wx::TextCtrl',   '_author_name_',    ($config->{module_start}{author_name} || '') ],
		],
		[
			[ 'Wx::StaticText', undef,              gettext('Email:')],
			[ 'Wx::TextCtrl',   '_email_',          ($config->{module_start}{email} || '') ],
		],
		[
			[ 'Wx::StaticText', undef,              gettext('Builder:')],
			[ 'Wx::ComboBox',   '_builder_choice_',
				($config->{module_start}{builder_choice} || ''), \@builders],
		],
		[
			[ 'Wx::StaticText', undef,              gettext('License:')],
			[ 'Wx::ComboBox',   '_license_choice_',
				($config->{module_start}{license_choice} || ''), \@licenses],
		],
		[
			[ 'Wx::StaticText',      undef,         gettext('Parent Directory:')],
			[ 'Wx::DirPickerCtrl',   '_directory_', '',   gettext('Pick parent directory')],
		],
		[
			[ 'Wx::Button',     '_ok_',           Wx::wxID_OK     ],
			[ 'Wx::Button',     '_cancel_',       Wx::wxID_CANCEL ],
		],
	);
	return \@layout;
}



sub start {
	my ($class, $main) = @_;
	
	my $dialog = $class->dialog( $main );
	$dialog->Show(1);

	return;
}

sub dialog {
	my ( $class, $win ) = @_;

	my $config = Padre->ide->config;

	my $layout = get_layout($config);
	my $dialog = Padre::Wx::Dialog->new(
		parent          => $win,
		title           => gettext("Module Start"),
		layout          => $layout,
		width           => [100, 200],
                bottom => 20,
	);

	$dialog->{_widgets_}{_ok_}->SetDefault;
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}{_ok_},      \&ok_clicked      );
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}{_cancel_},  \&cancel_clicked  );

	$dialog->{_widgets_}{_module_name_}->SetFocus;

	return $dialog;
}


sub cancel_clicked {
	my ($dialog, $event) = @_;

	$dialog->Destroy;

	return;
}

sub ok_clicked {
	my ($dialog, $event) = @_;

	my $data = $dialog->get_data;
	$dialog->Destroy;
	#print Dumper $data;

	my $config = Padre->ide->config;
	$config->{module_start}{author_name} = $data->{_author_name_};
	$config->{module_start}{email}       = $data->{_email_};
	$config->{module_start}{builder_choice} = $data->{_builder_choice_};
	$config->{module_start}{license_choice} = $data->{_license_choice_};

	my $main_window = Padre->ide->wx->main_window;

	# TODO improve input validation !
	my @fields = qw(_module_name_ _author_name_ _email_ _builder_choice_ _license_choice_);
	foreach my $f (@fields) {
		if (not $data->{$f}) {
			Wx::MessageBox(sprintf(gettext("Field %s was missing. Module not created."), $f), gettext("missing field"), Wx::wxOK, $main_window);
			return;
		}
	}

	my $pwd = Cwd::cwd();
	chdir $data->{_directory_};
	require Module::Starter::App;
	@ARGV = ('--module',   $data->{_module_name_},
	         '--author',   $data->{_author_name_},
	         '--email',    $data->{_email_},
	         '--builder',  $data->{_builder_choice_},
	         '--license',  $data->{_license_choice_},
	        );
	Module::Starter::App->run;
	@ARGV = ();
	chdir $pwd;

	my $ret = Wx::MessageBox(
		sprintf(gettext("%s apparantly created. Do you want to open it now?"), $data->{_module_name_}),
		gettext("Done"),
		Wx::wxYES_NO|Wx::wxCENTRE,
		$main_window,
	);
	if ( $ret == Wx::wxYES ) {
		my $module_name = $data->{_module_name_};
		($module_name)  = split(',', $module_name); # for Foo::Bar,Foo::Bat
		# prepare Foo-Bar/lib/Foo/Bar.pm
		my @parts = split('::', $module_name);
		my $dir_name = join('-', @parts);
		$parts[-1] .= '.pm';
		my $file = File::Spec->catfile( $data->{_directory_}, $dir_name, 'lib', @parts);
		Padre::DB->add_recent_files($file);
		$main_window->setup_editor($file);
		$main_window->refresh_all;
	}

	return;
}


1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

