package Padre::Wx::Directory;

use strict;
use warnings;
use Padre::Wx                        ();
use Padre::Wx::Directory::TreeCtrl   ();
use Padre::Wx::Directory::SearchCtrl ();

our $VERSION = '0.41';
our @ISA     = 'Wx::Panel';

######################################################################
# Creates Accessor
use Class::XSAccessor accessors => {
	_sizerv             => '_sizerv',
	_sizerh             => '_sizerh',
	_searcher           => '_searcher',
	_browser            => '_browser',
	_last_project       => '_last_project',
	_current_project    => '_current_project',
};

################################################################################
# new                                                                          #
#                                                                              #
# Creates the Directory Right Panel with a Search field and the Directory      #
# Browser                                                                      #
#                                                                              #
################################################################################
sub new {
	my ( $class , $main ) = @_;

	######################################################################
	# Creates the Panel where Search Field and Directory Browser will be
	# placed
	my $self = $class->SUPER::new(	$main->right,
					-1,
					Wx::wxDefaultPosition,
					Wx::wxDefaultSize,
	);

	######################################################################
	# BoxSizer to fill all the Panel space
	$self->_sizerv( Wx::BoxSizer->new( Wx::wxVERTICAL ) );
	$self->_sizerh( Wx::BoxSizer->new( Wx::wxHORIZONTAL ) );

	######################################################################
	# Creates the Search Field and the Directory Browser
	$self->_searcher( Padre::Wx::Directory::SearchCtrl->new($self) );
	$self->_browser( Padre::Wx::Directory::TreeCtrl->new($self) );

	######################################################################
	# Adds each component to the panel
	$self->_sizerv->Add( $self->_searcher, 0, Wx::wxALL|Wx::wxEXPAND, 0 );
	$self->_sizerv->Add( $self->_browser,  1, Wx::wxALL|Wx::wxEXPAND, 0 );
	$self->_sizerh->Add( $self->_sizerv,   1, Wx::wxALL|Wx::wxEXPAND, 0 );

	######################################################################
	# Fits panel layout
	$self->SetSizerAndFit($self->_sizerh);
	$self->_sizerh->SetSizeHints($self);

	return $self;
}

################################################################################
# right                                                                        #
#                                                                              #
# Returns the right object reference (where the Directory Browser is placed)   #
#                                                                              #
################################################################################
sub right {
	$_[0]->GetParent;
}

################################################################################
# main                                                                         #
#                                                                              #
# Returns the main object reference                                            #
#                                                                              #
################################################################################
sub main {
	$_[0]->GetGrandParent;
}

################################################################################
# current                                                                      #
#                                                                              #
#                                                                              #
################################################################################
sub current {
	Padre::Current->new( main => $_[0]->main );
}

################################################################################
# gettext_label                                                                #
#                                                                              #
# Returns the window label                                                     #
#                                                                              #
################################################################################
sub gettext_label {
	Wx::gettext('Directory');
}

################################################################################
# clear                                                                        #
#                                                                              #
# Sets the current_project to 'none', and calls Directory Searcher's and       #
# Browser clear functions                                                      #
#                                                                              #
################################################################################
sub clear {
	my $self = shift;
	unless ( $self->current->filename ) {
		$self->_searcher->clear;
		$self->_browser->clear;
		$self->_last_project(undef);
	}
	return;
}

################################################################################
# update_gui                                                                   #
#                                                                              #
# Updates the gui if needed, calling Searcher and Browser respectives          #
# update_gui function                                                          #
#                                                                              #
# Called outside Directory.pm, on directory browser focus and item dragging    #
#                                                                              #
################################################################################
sub update_gui {
	my $self    = shift;
	my $current = $self->current;
	$current->ide->wx or return;

	######################################################################
	# Finds project base
	my $filename = $current->filename or return;
	my $dir = Padre::Util::get_project_dir($filename)
		|| File::Basename::dirname($filename);

	return unless -e $dir;

	######################################################################
	# Updates the current_project to the current one
	$self->_current_project($dir);

	######################################################################
	# Calls Searcher and Browser update_gui
	$self->_browser->update_gui;
	$self->_searcher->update_gui;

	######################################################################
	# Sets the last project to the current one
	$self->_last_project($dir);
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
