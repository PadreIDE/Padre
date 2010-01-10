use strict;
use Padre::DB::Migrate::Patch;

# Create the host settings table
do(<<'END_SQL') unless table_exists('hostconf');
CREATE TABLE hostconf (
	name VARCHAR(255) PRIMARY KEY,
	value VARCHAR(255)
)
END_SQL

# Create the modules table
do(<<'END_SQL') unless table_exists('modules');
CREATE TABLE modules (
	id INTEGER PRIMARY KEY,
	name VARCHAR(255)
)
END_SQL

# Create the history table
do(<<'END_SQL') unless table_exists('history');
CREATE TABLE history (
	id INTEGER PRIMARY KEY,
	type VARCHAR(255),
	name VARCHAR(255)
)
END_SQL

# Drop old version of the table
if ( table_exists('snippets') and not column_exists('snippets', 'mimetype') ) {
	do('DROP TABLE snippets');
}

# Create the snippets table
do(<<'END_SQL') unless table_exists('snippets');
CREATE TABLE snippets (
	id INTEGER PRIMARY KEY,
	mimetype VARCHAR(255),
	category VARCHAR(255),
	name VARCHAR(255), 
	snippet TEXT
);
END_SQL

# Populate the snippit table
my @prepsnips = (
	[ 'application/x-perl', 'Char class', '[:alnum:]',  '[:alnum:]'  ],
	[ 'application/x-perl', 'Char class', '[:alpha:]',  '[:alpha:]'  ],
	[ 'application/x-perl', 'Char class', '[:ascii:]',  '[:ascii:]'  ],
	[ 'application/x-perl', 'Char class', '[:blank:]',  '[:blank:]'  ],
	[ 'application/x-perl', 'Char class', '[:cntrl:]',  '[:cntrl:]'  ],
	[ 'application/x-perl', 'Char class', '[:digit:]',  '[:digit:]'  ],
	[ 'application/x-perl', 'Char class', '[:graph:]',  '[:graph:]'  ],
	[ 'application/x-perl', 'Char class', '[:lower:]',  '[:lower:]'  ],
	[ 'application/x-perl', 'Char class', '[:print:]',  '[:print:]'  ],
	[ 'application/x-perl', 'Char class', '[:punct:]',  '[:punct:]'  ],
	[ 'application/x-perl', 'Char class', '[:space:]',  '[:space:]'  ],
	[ 'application/x-perl', 'Char class', '[:upper:]',  '[:upper:]'  ],
	[ 'application/x-perl', 'Char class', '[:word:]',   '[:word:]'   ],
	[ 'application/x-perl', 'Char class', '[:xdigit:]', '[:xdigit:]' ],
	[ 'application/x-perl', 'File test',  'age since inode change', '-C'],
	[ 'application/x-perl', 'File test',  'age since last access',  '-A'],
	[ 'application/x-perl', 'File test',  'age since modification', '-M'],
	[ 'application/x-perl', 'File test',  'binary file', '-B'],
	[ 'application/x-perl', 'File test',  'block special file', '-b'],
	[ 'application/x-perl', 'File test',  'character special file', '-c'],
	[ 'application/x-perl', 'File test',  'directory', '-d'],
	[ 'application/x-perl', 'File test',  'executable by eff. UID/GID', '-x'],
	[ 'application/x-perl', 'File test',  'executable by real UID/GID', '-X'],
	[ 'application/x-perl', 'File test',  'exists', '-e'],
	[ 'application/x-perl', 'File test',  'handle opened to a tty', '-t'],
	[ 'application/x-perl', 'File test',  'named pipe', '-p'],
	[ 'application/x-perl', 'File test',  'nonzero size', '-s'],
	[ 'application/x-perl', 'File test',  'owned by eff. UID', '-o'],
	[ 'application/x-perl', 'File test',  'owned by real UID', '-O'],
	[ 'application/x-perl', 'File test',  'plain file', '-f'],
	[ 'application/x-perl', 'File test',  'readable by eff. UID/GID', '-r'],
	[ 'application/x-perl', 'File test',  'readable by real UID/GID', '-R'],
	[ 'application/x-perl', 'File test',  'setgid bit set', '-g'],
	[ 'application/x-perl', 'File test',  'setuid bit set', '-u'],
	[ 'application/x-perl', 'File test',  'socket', '-S'],
	[ 'application/x-perl', 'File test',  'sticky bit set', '-k'],
	[ 'application/x-perl', 'File test',  'symbolic link', '-l'],
	[ 'application/x-perl', 'File test',  'text file', '-T'],
	[ 'application/x-perl', 'File test',  'writable by eff. UID/GID', '-w'],
	[ 'application/x-perl', 'File test',  'writable by real UID/GID', '-W'],
	[ 'application/x-perl', 'File test',  'zero size', '-z'],
	[ 'application/x-perl', 'Pod',        'pod/cut', "=pod\n\n\n\n=cut\n"],
	[ 'application/x-perl', 'Regex',      'grouping', '()'],
	[ 'application/x-perl', 'Statement',  'foreach',"foreach my \$ (  ) {\n}\n"],
	[ 'application/x-perl', 'Statement',  'if',"if (  ) {\n}\n"],
	[ 'application/x-perl', 'Statement',  'do while',"do {\n\n	    }\n	    while (  );\n"],
	[ 'application/x-perl', 'Statement',  'for',"for ( ; ; ) {\n}\n"],
	[ 'application/x-perl', 'Statement',  'foreach',"foreach my $ (  ) {\n}\n"],
	[ 'application/x-perl', 'Statement',  'if',"if (  ) {\n}\n"],
	[ 'application/x-perl', 'Statement',  'if else { }',"if (  ) {\n} else {\n}\n"],
	[ 'application/x-perl', 'Statement',  'unless ',"unless (  ) {\n}\n"],
	[ 'application/x-perl', 'Statement',  'unless else',"unless (  ) {\n} else {\n}\n"],
	[ 'application/x-perl', 'Statement',  'until',"until (  ) {\n}\n"],
	[ 'application/x-perl', 'Statement',  'while',"while (  ) {\n}\n"],
);

SCOPE: {
	my $dbh = dbh();
	$dbh->begin_work;
	my $sth = $dbh->prepare(
		'INSERT INTO snippets ( mimetype, category, name, snippet ) VALUES (?, ?, ?, ?)'
	);
	$sth->execute($_->[0], $_->[1], $_->[2], $_->[3]) for @prepsnips;
	$sth->finish;
	$dbh->commit;
}
