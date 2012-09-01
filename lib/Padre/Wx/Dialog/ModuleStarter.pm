package Padre::Wx::Dialog::ModuleStarter;

use v5.10;
use strict;
use warnings;
use Padre::Wx::Role::Config       ();
use Padre::Wx::FBP::ModuleStarter ();

our $VERSION = '0.89';
our @ISA     = qw{
	Padre::Wx::Role::Config
	Padre::Wx::FBP::ModuleStarter
};





######################################################################
# Class Methods

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
	$self->Destroy;
	return 1;
}


sub ok_clicked {
	my ( $self, $event ) = @_;
	
	say 'we clicked OK';

	# my $data = $dialog->get_data;
	# $dialog->Destroy;

	# my $main = Padre->ide->wx->main;

	# # TODO improve input validation !
	# my @fields = qw(_module_name_ _author_name_ _email_ _builder_choice_ _license_choice_);
	# foreach my $f (@fields) {
		# if ( not $data->{$f} ) {
			# Wx::MessageBox(
				# sprintf( Wx::gettext('Field %s was missing. Module not created.'), $f ),
				# Wx::gettext('missing field'), Wx::wxOK, $main
			# );
			# return;
		# }
	# }

	# my $config = Padre->ide->config;
	# $config->set( 'identity_name',            $data->{_author_name_} );
	# $config->set( 'identity_email',           $data->{_email_} );
	# $config->set( 'module_starter_builder',   $data->{_builder_choice_} );
	# $config->set( 'module_starter_license',   $license_id{ $data->{_license_choice_} } );
	# $config->set( 'module_starter_directory', $data->{_directory_} );

	# my $pwd = Cwd::cwd();
	# my $parent_dir = $data->{_directory_} eq '' ? './' : $data->{_directory_};
	# chdir $parent_dir;
	# eval {
		# require Module::Starter::App;
		# local @ARGV = (
			# '--module',  $data->{_module_name_},
			# '--author',  $data->{_author_name_},
			# '--email',   $data->{_email_},
			# '--builder', $data->{_builder_choice_},
			# '--license', exists $license_id{ $data->{_license_choice_} }
			# ? $license_id{ $data->{_license_choice_} }
			# : $data->{_license_choice_},
		# );
		# Module::Starter::App->run;
	# };
	# chdir $pwd;

	# if ($@) {
		# Wx::MessageBox(
			# sprintf(
				# Wx::gettext("An error has occured while generating '%s':\n%s"),
				# $data->{_module_name_}, $@
			# ),
			# Wx::gettext('Error'),
			# Wx::wxOK | Wx::wxCENTRE,
			# $main
		# );
		# return;
	# }

	# my $module_name = $data->{_module_name_};
	# ($module_name) = split( ',', $module_name ); # for Foo::Bar,Foo::Bat
	                                             # # prepare Foo-Bar/lib/Foo/Bar.pm
	# my @parts = split( '::', $module_name );
	# my $dir_name = join( '-', @parts );
	# $parts[-1] .= '.pm';
	# my $file = File::Spec->catfile( $parent_dir, $dir_name, 'lib', @parts );
	# Padre::DB::History->create(
		# type => 'files',
		# name => $file,
	# );
	# $main->setup_editor($file);
	# $main->refresh;

	return;
}


######################################################################
# Constructor and Accessors

sub new {
	my $self = shift->SUPER::new(@_);

	# Focus on the module name
	$self->module->SetFocus;

	return $self;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

