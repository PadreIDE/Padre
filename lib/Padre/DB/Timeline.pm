package Padre::DB::Timeline;

# A convenience module for writing migration patches.

use 5.008005;
use strict;
use warnings;
use ORLite::Migrate::Timeline ();

our $VERSION = '0.94';
our @ISA     = 'ORLite::Migrate::Timeline';





######################################################################
# Schema Migration (reverse chronological for readability)

sub upgrade13 {
	my $self = shift;

	# Drop the syntax highlight table as we now have current
	# Scintilla and the pressure to have highlighter plugins
	# is greatly reduced.
	$self->do('DROP TABLE syntax_highlight');

	# Reindex to take advantage of SQLite 3.7.8 improvements
	# to indexing speed and layout that arrived between the
	# release of Padre 0.92 and 0.94
	$self->do('REINDEX');

	return 1;
}

sub upgrade12 {
	my $self = shift;

	# Create the debug breakpoints table
	$self->do(<<'END_SQL');
CREATE TABLE debug_breakpoints (
	id INTEGER NOT NULL PRIMARY KEY,
	filename VARCHAR(255) NOT NULL,
	line_number INTEGER NOT NULL,
	active BOOLEAN NOT NULL,
	last_used DATE
)
END_SQL

	return 1;
}

sub upgrade11 {
	my $self = shift;

	# Create the recently used table
	$self->do(<<'END_SQL');
CREATE TABLE recently_used (
	name      VARCHAR(255) PRIMARY KEY,
	value     VARCHAR(255) NOT NULL,
	type      VARCHAR(255) NOT NULL,
	last_used DATE
)
END_SQL

	return 1;
}

sub upgrade10 {
	my $self = shift;

	# Normalize all plugin names to classes
	$self->do("UPDATE plugin SET name = 'Padre::Plugin::' || name");
	$self->do("DELETE FROM plugin WHERE name LIKE 'Padre::Plugin::%'");

	return 1;
}

sub upgrade9 {
	my $self = shift;

	# Syntax highlighter preferences
	$self->do(<<'END_SQL');
CREATE TABLE syntax_highlight (
	mime_type VARCHAR(255) PRIMARY KEY,
	value VARCHAR(255)
)
END_SQL

	return 1;
}

sub upgrade8 {
	my $self = shift;

	# Remove the session table created in migrate-5
	$self->do(<<'END_SQL');
DROP TABLE session
END_SQL

	# Create the new session table
	$self->do(<<'END_SQL');
CREATE TABLE session (
	id INTEGER NOT NULL PRIMARY KEY,
	name VARCHAR(255) UNIQUE NOT NULL,
	description VARCHAR(255),
	last_update DATE
)
END_SQL

	# Create the table containing the session files
	$self->do(<<'END_SQL');
CREATE TABLE session_file (
	id INTEGER NOT NULL PRIMARY KEY,
	file VARCHAR(255) NOT NULL,
	position INTEGER NOT NULL,
	focus BOOLEAN NOT NULL,
	session INTEGER NOT NULL,
	FOREIGN KEY (session) REFERENCES session ( id )
)
END_SQL

	return 1;
}

sub upgrade7 {
	my $self = shift;

	$self->do(<<'END_SQL');
create table last_position_in_file (
	name varchar(255) not null primary key,
	position integer not null
)
END_SQL

	return 1;
}

sub upgrade6 {
	my $self = shift;

	# This should get rid of the old config settings :)
	$self->do('DROP TABLE hostconf');

	# Since we have to create a new version, use a slightly better table name
	$self->do(<<'END_SQL');
CREATE TABLE host_config (
	name VARCHAR(255) NOT NULL PRIMARY KEY,
	value VARCHAR(255) NOT NULL
)
END_SQL

	return 1;
}

sub upgrade5 {
	my $self = shift;

	# Create the session table
	$self->do(<<'END_SQL');
CREATE TABLE session (
	id INTEGER NOT NULL PRIMARY KEY,
	file VARCHAR(255) UNIQUE NOT NULL,
	line INTEGER NOT NULL,
	character INTEGER NOT NULL,
	clue VARCHAR(255),
	focus BOOLEAN NOT NULL
)
END_SQL

	return 1;
}

sub upgrade4 {
	my $self = shift;

	# Create the bookmark table
	$self->do(<<'END_SQL');
CREATE TABLE bookmark (
	id   INTEGER NOT NULL PRIMARY KEY,
	name VARCHAR(255) UNIQUE NOT NULL,
	file VARCHAR(255) NOT NULL,
	line INTEGER NOT NULL
)
END_SQL

	return 1;
}

sub upgrade3 {
	my $self = shift;

	# Remove the dedundant modules table
	$self->do('DROP TABLE modules');

	return 1;
}

sub upgrade2 {
	my $self = shift;

	# Create the host settings table
	$self->do(<<'END_SQL');
CREATE TABLE plugin (
	name VARCHAR(255) PRIMARY KEY,
	version VARCHAR(255),
	enabled BOOLEAN,
	config TEXT
)
END_SQL

	return 1;
}

sub upgrade1 {
	my $self = shift;

	# Create the host settings table
	$self->do(<<'END_SQL');
CREATE TABLE hostconf (
	name VARCHAR(255) PRIMARY KEY,
	value VARCHAR(255)
)
END_SQL

	# Create the modules table
	$self->do(<<'END_SQL');
CREATE TABLE modules (
	id INTEGER PRIMARY KEY,
	name VARCHAR(255)
)
END_SQL

	# Create the history table
	$self->do(<<'END_SQL');
CREATE TABLE history (
	id INTEGER PRIMARY KEY,
	type VARCHAR(255),
	name VARCHAR(255)
)
END_SQL

	# Create the snippets table
	$self->do(<<'END_SQL');
CREATE TABLE snippets (
	id INTEGER PRIMARY KEY,
	mimetype VARCHAR(255),
	category VARCHAR(255),
	name VARCHAR(255), 
	snippet TEXT
)
END_SQL

	# Populate the snippet table
	my @snippets = (
		[ 'Char class', '[:alnum:]',                  '[:alnum:]' ],
		[ 'Char class', '[:alpha:]',                  '[:alpha:]' ],
		[ 'Char class', '[:ascii:]',                  '[:ascii:]' ],
		[ 'Char class', '[:blank:]',                  '[:blank:]' ],
		[ 'Char class', '[:cntrl:]',                  '[:cntrl:]' ],
		[ 'Char class', '[:digit:]',                  '[:digit:]' ],
		[ 'Char class', '[:graph:]',                  '[:graph:]' ],
		[ 'Char class', '[:lower:]',                  '[:lower:]' ],
		[ 'Char class', '[:print:]',                  '[:print:]' ],
		[ 'Char class', '[:punct:]',                  '[:punct:]' ],
		[ 'Char class', '[:space:]',                  '[:space:]' ],
		[ 'Char class', '[:upper:]',                  '[:upper:]' ],
		[ 'Char class', '[:word:]',                   '[:word:]' ],
		[ 'Char class', '[:xdigit:]',                 '[:xdigit:]' ],
		[ 'File test',  'age since inode change',     '-C' ],
		[ 'File test',  'age since last access',      '-A' ],
		[ 'File test',  'age since modification',     '-M' ],
		[ 'File test',  'binary file',                '-B' ],
		[ 'File test',  'block special file',         '-b' ],
		[ 'File test',  'character special file',     '-c' ],
		[ 'File test',  'directory',                  '-d' ],
		[ 'File test',  'executable by eff. UID/GID', '-x' ],
		[ 'File test',  'executable by real UID/GID', '-X' ],
		[ 'File test',  'exists',                     '-e' ],
		[ 'File test',  'handle opened to a tty',     '-t' ],
		[ 'File test',  'named pipe',                 '-p' ],
		[ 'File test',  'nonzero size',               '-s' ],
		[ 'File test',  'owned by eff. UID',          '-o' ],
		[ 'File test',  'owned by real UID',          '-O' ],
		[ 'File test',  'plain file',                 '-f' ],
		[ 'File test',  'readable by eff. UID/GID',   '-r' ],
		[ 'File test',  'readable by real UID/GID',   '-R' ],
		[ 'File test',  'setgid bit set',             '-g' ],
		[ 'File test',  'setuid bit set',             '-u' ],
		[ 'File test',  'socket',                     '-S' ],
		[ 'File test',  'sticky bit set',             '-k' ],
		[ 'File test',  'symbolic link',              '-l' ],
		[ 'File test',  'text file',                  '-T' ],
		[ 'File test',  'writable by eff. UID/GID',   '-w' ],
		[ 'File test',  'writable by real UID/GID',   '-W' ],
		[ 'File test',  'zero size',                  '-z' ],
		[ 'Pod',        'pod/cut',                    "=pod\n\n\n\n=cut\n" ],
		[ 'Regex',      'grouping',                   '()' ],
		[ 'Statement',  'foreach',                    "foreach my \$ (  ) {\n}\n" ],
		[ 'Statement',  'if',                         "if (  ) {\n}\n" ],
		[ 'Statement',  'do while',                   "do {\n\n	    }\n	    while (  );\n" ],
		[ 'Statement',  'for',                        "for ( ; ; ) {\n}\n" ],
		[ 'Statement',  'foreach',                    "foreach my $ (  ) {\n}\n" ],
		[ 'Statement',  'if',                         "if (  ) {\n}\n" ],
		[ 'Statement',  'if else { }',                "if (  ) {\n} else {\n}\n" ],
		[ 'Statement',  'unless ',                    "unless (  ) {\n}\n" ],
		[ 'Statement',  'unless else',                "unless (  ) {\n} else {\n}\n" ],
		[ 'Statement',  'until',                      "until (  ) {\n}\n" ],
		[ 'Statement',  'while',                      "while (  ) {\n}\n" ],
	);

	SCOPE: {
		my $dbh = $self->dbh;
		$dbh->begin_work;
		my $sth = $dbh->prepare('INSERT INTO snippets ( mimetype, category, name, snippet ) VALUES (?, ?, ?, ?)');
		foreach (@snippets) {
			$sth->execute( 'application/x-perl', $_->[0], $_->[1], $_->[2] );
		}
		$sth->finish;
		$dbh->commit;
	}

	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

