package Padre::DB;

# Provide an ORLite-based API for the Padre database

use strict;
use File::Spec          ();
use File::ShareDir::PAR ();
use Params::Util        ();
use Padre::Config       ();
use Padre::Current      ();

use ORLite 1.17 (); # Need truncate
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

our $VERSION    = '0.24';
our $COMPATIBLE = '0.23';





#####################################################################
# Host-Specific Configuration Methods

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
# History

sub add_history {
	my $class = shift;
	Padre::DB::History->create(
		type => $_[0],
		name => $_[1],
	);
	return;
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

sub get_last {
	my $class  = shift;
	my @recent = $class->get_recent(shift, 1);
	return $recent[0];
}

sub add_recent_files {
	Padre::DB::History->create(
		type => 'files',
		name => $_[1],
	);
	return;
}

sub get_recent_files {
	$_[0]->get_recent('files');
}

sub add_recent_pod {
	Padre::DB::History->create(
		type => 'pod',
		name => $_[1],
	);
	return;
}

sub get_recent_pod {
	$_[0]->get_recent('pod');
}

sub get_last_pod {
	$_[0]->get_last('pod');
}





#####################################################################
# Snippets

sub find_snipclasses {
	$_[0]->selectcol_arrayref(
		"select distinct category from snippets where mimetype = ? order by category",
		{}, Padre::Current->document->guess_mimetype,
	);
}

sub find_snipnames {
	my $class = shift;
	my $sql   = "select name from snippets where mimetype = ?";
	my @bind  = ( Padre::Current->document->guess_mimetype );
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
	my @bind  = ( Padre::Current->document->guess_mimetype );
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
