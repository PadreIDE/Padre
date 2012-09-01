package Padre::Wx::Dialog::ModuleStarter;

use v5.10;
use strict;
use warnings;
use Padre::Wx::Role::Config       ();
use Padre::Wx::FBP::ModuleStarter ();
use Try::Tiny;

our $VERSION = '0.89';
our @ISA     = qw{
	Padre::Wx::Role::Config
	Padre::Wx::FBP::ModuleStarter
};


#######
# new
#######
sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	# Focus on the module name
	$self->module->SetFocus;

	return $self;
}

#######
# Method run
#######
sub run {
	my $class  = shift;
	my $main   = shift;
	my $self   = $class->new($main);
	my $config = $main->config;

	# Load preferences
	$self->config_load(
		$config, qw{
			identity_name
			identity_email
			module_starter_directory
			module_starter_builder
			module_starter_license
			}
	);

	# Show the dialog
	$self->Fit;
	$self->CentreOnParent;
	if ( $self->ShowModal == Wx::wxID_CANCEL ) {
		$self->main->editor_focus;
		$self->Destroy;
		return;
	}

	# Save preferences
	$self->config_save(
		$config, qw{
			module_starter_directory
			module_starter_builder
			module_starter_license
			}
	);

	# Generate the distribution
	### TO BE COMPLETED

	# Clean up
	# $self->Destroy;
	return 1;
}

#######
# event handeler for ok_clicked
#######
sub ok_clicked {
	my ( $self, $event ) = @_;
	my $main = $self->main;
	my $data;

	$data->{module_name} = $self->module->GetValue();

	$data->{author_name} = $self->config_get( Padre::Current->config->meta('identity_name') );
	$data->{email}       = $self->config_get( Padre::Current->config->meta('identity_email') );

	$data->{builder_choice} = $self->config_get( Padre::Current->config->meta('module_starter_builder') );
	$data->{license_choice} = $self->config_get( Padre::Current->config->meta('module_starter_license') );

	$data->{directory} = $self->config_get( Padre::Current->config->meta('module_starter_directory') );

	# # TODO improve input validation !
	my @fields = qw( module_name author_name email builder_choice license_choice );
	foreach my $f (@fields) {
		if ( not $data->{$f} ) {
			Wx::MessageBox(
				sprintf( Wx::gettext('Field %s was missing. Module not created.'), $f ),
				Wx::gettext('missing field'), Wx::wxOK, $main
			);
			return;
		}
	}
	
	# given ( $data->{builder_choice} ) {
		
		# when ('Module::Install') { ... }
		
		# }
	

	my $config = Padre->ide->config;
	$config->set( 'identity_name',            $data->{author_name} );
	$config->set( 'identity_email',           $data->{email} );
	$config->set( 'module_starter_builder',   $data->{builder_choice} );
	$config->set( 'module_starter_license',   $data->{license_choice} );
	$config->set( 'module_starter_directory', $data->{directory} );

	my $pwd = Cwd::cwd();
	my $parent_dir = $data->{directory} || './';
	chdir $parent_dir;

	try {
		require Module::Starter::App;
		local @ARGV = (
			'--module',  $data->{module_name},
			'--author',  $data->{author_name},
			'--email',   $data->{email},
			'--builder', $data->{builder_choice},
			'--license', $data->{license_choice},
		);
		Module::Starter::App->run;
	}
	catch {
		Wx::MessageBox(
			sprintf(
				Wx::gettext("An error has occured while generating '%s':\n%s"),
				$data->{module_name}, $_
			),
			Wx::gettext('Error'),
			Wx::wxOK | Wx::wxCENTRE,
			$main
		);
		return;
	};
	chdir $pwd;


	#Create dir structure
	my $module_name = $data->{module_name};
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

	# Clean up
	$self->Destroy;
	return;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

__END__

#ToDo Dialog needs to support the following table

licence list from Module::Build::API

'apache',       ms		# does not work w/ Module::Build
'artistic',				# does not work w/ Module::Build
'artistic_2',			# does not work w/ Module::Build
'bsd',			ms	
'gpl',			ms	
'lgpl',			ms	
'mit',			ms
'mozilla',				# does not work w/ Module::Build
'open_source',			# does not work w/ Module::Build
'perl',			ms
'restrictive',			# does not work w/ Module::Build
'unrestricted',			# does not work w/ Module::Build

ms from module::starter::simple
the previous comment # does not work w/ Module::Build dose not make sense
