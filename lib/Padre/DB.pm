package Padre::DB;

# Provide an ORLite-based API for the Padre database

use strict;
use Params::Util  ();
use Padre::Config ();
use ORLite 0.15 {
	file   => Padre::Config->default_db,
	create => 1,
	tables => 0,
};

our $VERSION    = '0.20';
our $COMPATIBLE = '0.17';

# At load time, autocreate if needed
unless ( Padre::DB->pragma('user_version') == 2 ) {
	Padre::DB->setup;
}






#####################################################################
# General Methods

sub table_exists {
	$_[0]->selectrow_array(
		"select count(*) from sqlite_master where type = 'table' and name = ?",
		{}, $_[1],
	);
}

sub column_exists {
	my ($class, $table, $column) = @_;

	return unless $class->table_exists($table);
	return $class->selectrow_array("select count($column) from $table", {});
}

sub setup {
	my $class = shift;

	# Create the host settings table
	$class->do(<<'END_SQL') unless $class->table_exists('hostconf');
CREATE TABLE hostconf (
	name VARCHAR(255) PRIMARY KEY,
	value VARCHAR(255)
)
END_SQL

	# Create the modules table
	$class->do(<<'END_SQL') unless $class->table_exists('modules');
CREATE TABLE modules (
	id INTEGER PRIMARY KEY,
	name VARCHAR(255)
)
END_SQL

	# Create the history table
	$class->do(<<'END_SQL') unless $class->table_exists('history');
CREATE TABLE history (
	id INTEGER PRIMARY KEY,
	type VARCHAR(255),
	name VARCHAR(255)
)
END_SQL

	# Drop old version of the table
	if ( $class->table_exists('snippets') and not $class->column_exists('snippets', 'mimetype') ) {
		$class->do('DROP TABLE snippets');
	}

	# Create the snippets table
	unless ( $class->table_exists('snippets') ) {
		$class->do(<<'END_SQL');
CREATE TABLE snippets (
	id INTEGER PRIMARY KEY,
	mimetype VARCHAR(255),
	category VARCHAR(255),
	name VARCHAR(255), 
	snippet TEXT
);
END_SQL

		my @prepsnips = (
			['application/x-perl','Char class', '[:alnum:]','[:alnum:]'],
			['application/x-perl','Char class', '[:alpha:]','[:alpha:]'],
			['application/x-perl','Char class', '[:ascii:]','[:ascii:]'],
			['application/x-perl','Char class', '[:blank:]','[:blank:]'],
			['application/x-perl','Char class', '[:cntrl:]','[:cntrl:]'],
			['application/x-perl','Char class', '[:digit:]','[:digit:]'],
			['application/x-perl','Char class', '[:graph:]','[:graph:]'],
			['application/x-perl','Char class', '[:lower:]','[:lower:]'],
			['application/x-perl','Char class', '[:print:]','[:print:]'],
			['application/x-perl','Char class', '[:punct:]','[:punct:]'],
			['application/x-perl','Char class', '[:space:]','[:space:]'],
			['application/x-perl','Char class', '[:upper:]','[:upper:]'],
			['application/x-perl','Char class', '[:word:]','[:word:]'],
			['application/x-perl','Char class', '[:xdigit:]','[:xdigit:]'],
			['application/x-perl','File test', 'age since inode change', '-C'],
			['application/x-perl','File test', 'age since last access', '-A'],
			['application/x-perl','File test', 'age since modification', '-M'],
			['application/x-perl','File test', 'binary file', '-B'],
			['application/x-perl','File test', 'block special file', '-b'],
			['application/x-perl','File test', 'character special file', '-c'],
			['application/x-perl','File test', 'directory', '-d'],
			['application/x-perl','File test', 'executable by eff. UID/GID', '-x'],
			['application/x-perl','File test', 'executable by real UID/GID', '-X'],
			['application/x-perl','File test', 'exists', '-e'],
			['application/x-perl','File test', 'handle opened to a tty', '-t'],
			['application/x-perl','File test', 'named pipe', '-p'],
			['application/x-perl','File test', 'nonzero size', '-s'],
			['application/x-perl','File test', 'owned by eff. UID', '-o'],
			['application/x-perl','File test', 'owned by real UID', '-O'],
			['application/x-perl','File test', 'plain file', '-f'],
			['application/x-perl','File test', 'readable by eff. UID/GID', '-r'],
			['application/x-perl','File test', 'readable by real UID/GID', '-R'],
			['application/x-perl','File test', 'setgid bit set', '-g'],
			['application/x-perl','File test', 'setuid bit set', '-u'],
			['application/x-perl','File test', 'socket', '-S'],
			['application/x-perl','File test', 'sticky bit set', '-k'],
			['application/x-perl','File test', 'symbolic link', '-l'],
			['application/x-perl','File test', 'text file', '-T'],
			['application/x-perl','File test', 'writable by eff. UID/GID', '-w'],
			['application/x-perl','File test', 'writable by real UID/GID', '-W'],
			['application/x-perl','File test', 'zero size', '-z'],
			['application/x-perl','Pod', 'pod/cut', "=pod\n\n\n\n=cut\n"],
			['application/x-perl','Regex','grouping','()'],
			['application/x-perl','Statement','foreach',"foreach my \$ (  ) {\n}\n"],
			['application/x-perl','Statement','if',"if (  ) {\n}\n"],
			['application/x-perl','Statement','do while',"do {\n\n	    }\n	    while (  );\n"],
			['application/x-perl','Statement','for',"for ( ; ; ) {\n}\n"],
			['application/x-perl','Statement','foreach',"foreach my $ (  ) {\n}\n"],
			['application/x-perl','Statement','if',"if (  ) {\n}\n"],
			['application/x-perl','Statement','if else { }',"if (  ) {\n} else {\n}\n"],
			['application/x-perl','Statement','unless ',"unless (  ) {\n}\n"],
			['application/x-perl','Statement','unless else',"unless (  ) {\n} else {\n}\n"],
			['application/x-perl','Statement','until',"until (  ) {\n}\n"],
			['application/x-perl','Statement','while',"while (  ) {\n}\n"],
		);
		Padre::DB->begin;
		SCOPE: {
			my $sth = $class->prepare(
				'INSERT INTO snippets ( mimetype, category, name, snippet ) VALUES (?, ?, ?, ?)'
			);
			$sth->execute($_->[0], $_->[1], $_->[2], $_->[3]) for @prepsnips;
			$sth->finish;
		}
		Padre::DB->commit;
	}

	$class->pragma('user_version', 1);
}





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
