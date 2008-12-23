package Padre::DB;

# Provide an ORLite-based API for the Padre database

use strict;
use File::Spec          ();
use Params::Util        ();
use Padre::Config       ();
use File::ShareDir::PAR ();

use ORLite::Migrate 0.01 {
	create   => 1,
	tables   => [ 'Modules' ],
	file     => Padre::Config->default_db,
	timeline => File::Spec->catdir(
		File::ShareDir::PAR::dist_dir('Padre'),
		'timeline',
	),
};

our $VERSION    = '0.22';
our $COMPATIBLE = '0.21';





#####################################################################
# Host Preference Methods

sub hostconf_read {
	my $class = shift;
	my $rows  = $class->selectall_arrayref('select name, value from hostconf');
	return { map { @$_ } @$rows };
}

sub hostconf_write {
	my $class = shift;
	my $hash  = shift;
	$class->begin;
	$class->do('delete from hostconf');
	foreach my $key ( sort keys %$hash ) {
		$class->do(
			'insert into hostconf ( name, value ) values ( ?, ? )',
			{}, $key => $hash->{$key},
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
		$class->do(
			"INSERT INTO modules ( name ) VALUES ( ? )",
			{}, $module,
		);
	}
	return;
}

sub delete_modules {
	shift->do("DELETE FROM modules");
}

sub find_modules {
	my $class = shift;
	my $part  = shift;
	my $sql   = "SELECT name FROM modules";
	my @bind_values;
	if ( $part ) {
		$sql .= " WHERE name LIKE ?";
		push @bind_values, '%' . $part .  '%';
	}
	$sql .= " ORDER BY name";
	return $class->selectcol_arrayref($sql, {}, @bind_values);
}





#####################################################################
# History

sub add_history {
	my $class = shift;
	my $type  = shift;
	my $value = shift;
	$class->do(
		"insert into history ( type, name ) values ( ?, ? )",
		{}, $type, $value,
	);
	return;
}

sub get_history {
	my $class = shift;
	my $type  = shift;
	die "CODE INCOMPLETE";
}

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
	my ( $class, $type ) = @_;
	
	$class->do(
		"DELETE FROM history WHERE type = ?",
		{}, $type
	);
	
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
	my ($class, $category, $name, $snippet) = @_;

	my $mimetype = Padre::Documents->current->guess_mimetype;
	$class->do(
		"INSERT INTO snippets ( mimetype, category, name, snippet ) VALUES ( ?, ?, ?, ? )",
		{}, $mimetype, $category, $name, $snippet,
	);

	return;
}

sub edit_snippet {
	my ($class, $id, $category, $name, $snippet) = @_;

	$class->do(
		"UPDATE snippets SET category=?, name=?, snippet=? WHERE id=?",
		{}, $category, $name, $snippet, $id,
	);

	return;
}

sub find_snipclasses {
	my ($class) = @_;

	my $mimetype = Padre::Documents->current->guess_mimetype;
	my $sql   = "SELECT distinct category FROM snippets WHERE mimetype=? ORDER BY category";

	return $class->selectcol_arrayref($sql, {}, $mimetype);
}

sub find_snipnames {
	my ($class, $part) = @_;

	my $sql   = "SELECT name FROM snippets WHERE mimetype=?";
	my $mimetype = Padre::Documents->current->guess_mimetype;
	my @bind_values = ($mimetype);
	if ( $part ) {
		$sql .= " AND category = ?";
		push @bind_values, $part;
	}
	$sql .= " ORDER BY name";

	return $class->selectcol_arrayref($sql, {}, @bind_values);
}

sub find_snippets {
	my ($class, $part) = @_;

	my $sql   = "SELECT id,category,name,snippet FROM snippets WHERE mimetype=? ";
	my $mimetype = Padre::Documents->current->guess_mimetype;
	my @bind_values = ($mimetype);
	if ( $part ) {
		$sql .= " AND category = ?";
		push @bind_values, $part;
	}
	$sql .= " ORDER BY name";

	return $class->selectall_arrayref($sql, {}, @bind_values);
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
