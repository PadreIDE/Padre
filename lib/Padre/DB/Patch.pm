package Padre::DB::Patch;

# A convenience module for writing migration patches

use strict;
use DBI      ();
use Exporter ();

use vars qw{@EXPORT $FILE};
BEGIN {
	@EXPORT = ();
	$FILE   = undef;
}

sub file {
	unless ( $FILE ) {
		# The filename is passed on STDIN
		$FILE = <STDIN>;
		chomp($FILE);
		unless ( -f $FILE and -w $FILE ) {
			die "SQLite file $FILE does not exist";
		}
	}
	return $FILE;
}

sub connect {
	my $file = file();
	my $dbh  = DBI->connect("dbi:SQLite(RaiseError=>1):$file");
	unless ( $dbh ) {
		die "Failed to connect to $file";
	}
	return $dbh;
}

sub do {
	connect()->do(@_);
}

sub selectall_arrayref {
	connect()->selectall_arrayref(@_);
}

sub selectall_hashref {
	connect()->selectall_hashref(@_);
}

sub selectcol_arrayref {
	connect()->selectcol_arrayref(@_);
}

sub selectrow_array {
	connect()->selectrow_array(@_);
}

sub selectrow_arrayref {
	connect()->selectrow_arrayref(@_);
}

sub selectrow_hashref {
	connect()->selectrow_hashref(@_);
}

sub pragma {
	do("pragma $_[0] = $_[1]") if @_ > 2;
	selectrow_arrayref("pragma $_[0]")->[0];
}

sub table_exists {
	selectrow_array(
		"select count(*) from sqlite_master where type = 'table' and name = ?",
		{}, $_[0],
	);
}

sub column_exists {
	table_exists($_[0]) or
	selectrow_array("select count($_[1]) from $_[0]", {});
}

1;
