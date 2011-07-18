package Padre::DB::Migrate::Patch1;

use strict;
use Padre::DB::Migrate::Patch ();

our $VERSION = '0.85';
our @ISA     = 'Padre::DB::Migrate::Patch';

sub run {
	my $self = shift;

	# Create the host settings table
	$self->do(<<'END_SQL') unless $self->table_exists('hostconf');
	CREATE TABLE hostconf (
		name VARCHAR(255) PRIMARY KEY,
		value VARCHAR(255)
	)
END_SQL

	# Create the modules table
	$self->do(<<'END_SQL') unless $self->table_exists('modules');
	CREATE TABLE modules (
		id INTEGER PRIMARY KEY,
		name VARCHAR(255)
	)
END_SQL

	# Create the history table
	$self->do(<<'END_SQL') unless $self->table_exists('history');
	CREATE TABLE history (
		id INTEGER PRIMARY KEY,
		type VARCHAR(255),
		name VARCHAR(255)
	)
END_SQL

	# Drop old version of the table
	if (
		$self->table_exists('snippets')
		and not
		$self->column_exists('snippets', 'mimetype')
	) {
		$self->do('DROP TABLE snippets');
	}

	# Create the snippets table
	$self->do(<<'END_SQL') unless $self->table_exists('snippets');
	CREATE TABLE snippets (
		id INTEGER PRIMARY KEY,
		mimetype VARCHAR(255),
		category VARCHAR(255),
		name VARCHAR(255), 
		snippet TEXT
	)
END_SQL

	# Populate the snippit table
	my @prepsnips = (
		[ 'Char class', '[:alnum:]',  '[:alnum:]'  ],
		[ 'Char class', '[:alpha:]',  '[:alpha:]'  ],
		[ 'Char class', '[:ascii:]',  '[:ascii:]'  ],
		[ 'Char class', '[:blank:]',  '[:blank:]'  ],
		[ 'Char class', '[:cntrl:]',  '[:cntrl:]'  ],
		[ 'Char class', '[:digit:]',  '[:digit:]'  ],
		[ 'Char class', '[:graph:]',  '[:graph:]'  ],
		[ 'Char class', '[:lower:]',  '[:lower:]'  ],
		[ 'Char class', '[:print:]',  '[:print:]'  ],
		[ 'Char class', '[:punct:]',  '[:punct:]'  ],
		[ 'Char class', '[:space:]',  '[:space:]'  ],
		[ 'Char class', '[:upper:]',  '[:upper:]'  ],
		[ 'Char class', '[:word:]',   '[:word:]'   ],
		[ 'Char class', '[:xdigit:]', '[:xdigit:]' ],
		[ 'File test',  'age since inode change', '-C'],
		[ 'File test',  'age since last access',  '-A'],
		[ 'File test',  'age since modification', '-M'],
		[ 'File test',  'binary file', '-B'],
		[ 'File test',  'block special file', '-b'],
		[ 'File test',  'character special file', '-c'],
		[ 'File test',  'directory', '-d'],
		[ 'File test',  'executable by eff. UID/GID', '-x'],
		[ 'File test',  'executable by real UID/GID', '-X'],
		[ 'File test',  'exists', '-e'],
		[ 'File test',  'handle opened to a tty', '-t'],
		[ 'File test',  'named pipe', '-p'],
		[ 'File test',  'nonzero size', '-s'],
		[ 'File test',  'owned by eff. UID', '-o'],
		[ 'File test',  'owned by real UID', '-O'],
		[ 'File test',  'plain file', '-f'],
		[ 'File test',  'readable by eff. UID/GID', '-r'],
		[ 'File test',  'readable by real UID/GID', '-R'],
		[ 'File test',  'setgid bit set', '-g'],
		[ 'File test',  'setuid bit set', '-u'],
		[ 'File test',  'socket', '-S'],
		[ 'File test',  'sticky bit set', '-k'],
		[ 'File test',  'symbolic link', '-l'],
		[ 'File test',  'text file', '-T'],
		[ 'File test',  'writable by eff. UID/GID', '-w'],
		[ 'File test',  'writable by real UID/GID', '-W'],
		[ 'File test',  'zero size', '-z'],
		[ 'Pod',        'pod/cut', "=pod\n\n\n\n=cut\n"],
		[ 'Regex',      'grouping', '()'],
		[ 'Statement',  'foreach',"foreach my \$ (  ) {\n}\n"],
		[ 'Statement',  'if',"if (  ) {\n}\n"],
		[ 'Statement',  'do while',"do {\n\n	    }\n	    while (  );\n"],
		[ 'Statement',  'for',"for ( ; ; ) {\n}\n"],
		[ 'Statement',  'foreach',"foreach my $ (  ) {\n}\n"],
		[ 'Statement',  'if',"if (  ) {\n}\n"],
		[ 'Statement',  'if else { }',"if (  ) {\n} else {\n}\n"],
		[ 'Statement',  'unless ',"unless (  ) {\n}\n"],
		[ 'Statement',  'unless else',"unless (  ) {\n} else {\n}\n"],
		[ 'Statement',  'until',"until (  ) {\n}\n"],
		[ 'Statement',  'while',"while (  ) {\n}\n"],
	);

	SCOPE: {
		my $dbh = $self->dbh;
		$dbh->begin_work;
		my $sth = $dbh->prepare(
			'INSERT INTO snippets ( mimetype, category, name, snippet ) VALUES (?, ?, ?, ?)'
		);
		foreach ( @presnips ) {
			$sth->execute( 'application/x-perl', $_->[1], $_->[2], $_->[3]);
		}
		$sth->finish;
		$dbh->commit;
	}

	return 1;
}

1;
