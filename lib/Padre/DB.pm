package Padre::DB;

# Provide an ORLite-based API for the Padre database

use strict;
use File::Spec          ();
use Params::Util        ();
use Padre::Config       ();
use File::ShareDir::PAR ();
use ORLite 1.17         (); # Need truncate

use ORLite::Migrate 0.01 {
	create        => 1,
	tables        => [ 'Modules' ],
	file          => Padre::Config->default_db,
	user_revision => 2,
	timeline      => File::Spec->catdir(
		File::ShareDir::PAR::dist_dir('Padre'),
		'timeline',
	),
};

our $VERSION    = '0.23';
our $COMPATIBLE = '0.23';





#####################################################################
# Host Preference Methods

sub hostconf_read {
	return +{
		map { $_->name => $_->value }
		Padre::DB::Hostconf->select
	};
}

sub hostconf_write {
	my $class = shift;
	my $hash  = shift;
	$class->begin;
	Padre::DB::Hostconf->truncate;
	foreach my $name ( sort keys %$hash ) {
		Padre::DB::Hostconf->create(
			name  => $name,
			value => $hash->{$name},
		);
	}
	$class->commit;
	return 1;
}





#####################################################################
# Modules Methods

sub add_modules {
	my $class = shift;
	foreach my $module ( @_ ) {
		Padre::DB::Modules->create(
			name => $module,
		);
	}
	return;
}

sub delete_modules {
	Padre::DB::Modules->truncate;
}

sub find_modules {
	my $class = shift;
	my $where = '';
	my @bind  = ();
	if ( $_[0] ) {
		$where = 'where name like ?';
		push @bind, '%' . $_[0] . '%';
	}
	my @found = Padre::DB::Modules->select(
		"$where order by name", @bind,
	);
	return [ map { $_->name } @found ];
}





#####################################################################
# History

sub add_history {
	my $class = shift;
	Padre::DB::History->create(
		type => $_[0],
		name => $_[1],
	);
	return;
}

sub get_history {
	my $class = shift;
	my $type  = shift;
	die "CODE INCOMPLETE";
}

# ORLite can't handle "distinct", so don't convert this to the model
sub get_recent {
	my $class  = shift;
	my $type   = shift;
	my $limit  = Params::Util::_POSINT(shift) || 10;
	my $recent = $class->selectcol_arrayref(
		"select distinct name from history where type = ? order by id desc limit $limit",
		{}, $type,
	) or die "Failed to find revent files";
	return wantarray ? @$recent : $recent;
}

sub delete_recent {
	my $class = shift;
	Padre::DB::History->delete('where type = ?', shift);
	return 1;
}

sub get_last {
	my $class  = shift;
	my @recent = $class->get_recent(shift, 1);
	return $recent[0];
}

sub add_recent_files {
	$_[0]->add_history('files', $_[1]);
}

sub get_recent_files {
	$_[0]->get_recent('files');
}

sub add_recent_pod {
	$_[0]->add_history('pod', $_[1]);
}

sub get_recent_pod {
	$_[0]->get_recent('pod');
}

sub get_last_pod {
	$_[0]->get_last('pod');
}





#####################################################################
# Snippets

sub add_snippet {
	Padre::DB::Snippets->create(
		mimetype => Padre::Documents->current->guess_mimetype,
		category => $_[1],
		name     => $_[2],
		snippet  => $_[3],
	);
}

sub edit_snippet {
	$_[0]->do(
		"update snippets set category = ?, name = ?, snippet = ? where id = ?",
		{}, $_[2], $_[3], $_[4], $_[1],
	);
}

sub find_snipclasses {
	$_[0]->selectcol_arrayref(
		"select distinct category from snippets where mimetype = ? order by category",
		{}, Padre::Documents->current->guess_mimetype,
	);
}

sub find_snipnames {
	my $class = shift;
	my $sql   = "select name from snippets where mimetype = ?";
	my @bind  = ( Padre::Documents->current->guess_mimetype );
	if ( $_[0] ) {
		$sql .= " and category = ?";
		push @bind, $_[0];
	}
	$sql .= " order by name";
	return $class->selectcol_arrayref($sql, {}, @bind);
}

sub find_snippets {
	my $class = shift;
	my $sql   = "select id, category, name, snippet from snippets where mimetype = ?";
	my @bind  = ( Padre::Documents->current->guess_mimetype );
	if ( $_[0] ) {
		$sql .= " and category = ?";
		push @bind, $_[0];
	}
	$sql .= " order by name";
	return $class->selectall_arrayref($sql, {}, @bind);
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
