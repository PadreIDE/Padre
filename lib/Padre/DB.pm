package Padre::DB;

# Provide an ORLite-based API for the Padre database
use 5.008;
use strict;
use warnings;
use Params::Util    ();
use Padre::Constant ();
use Padre::Current  ();
use Padre::Logger;

BEGIN {

	# Trap and warn in any situations where the database API is
	# loaded in a background thread. This should never happen.
	if ( $threads::threads and threads->tid ) {
		warn "Padre::DB illegally loaded in background thread";
	}
}

# Force newer ORLite and SQLite for performance improvements
use DBD::SQLite 1.35 ();
use ORLite      1.51 ();

# Remove the trailing -DEBUG to get debugging info on ORLite magic
use ORLite::Migrate 1.08 {
	create       => 1,
	file         => Padre::Constant::CONFIG_HOST,
	timeline     => 'Padre::DB::Timeline',
	tables       => [ 'Modules' ],
	user_version => 13, # Confirm we have the correct schema version
	array        => 1,  # Smaller faster array objects
	xsaccessor   => 0,  # XS acceleration for the generated code
	shim         => 1,  # Overlay classes can fully override methods
	x_update     => 1,  # Experimental ->update support
}; #, '-DEBUG';

# Free the timeline modules if we used them
BEGIN {
	if ( $Padre::DB::Timeline::VERSION ) {
		require Padre::Unload;
		Padre::Unload::unload('Padre::DB::Timeline');
		Padre::Unload::unload('ORLite::Migrate::Timeline');
	}
}

our $VERSION    = '0.94';
our $COMPATIBLE = '0.26';





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
	return $class->selectcol_arrayref( $sql, {}, @bind );
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
	return $class->selectall_arrayref( $sql, {}, @bind );
}

# Vacuum database to keep it small and fast.
# This will generally be run every time Padre shuts down, so may
# contains bits and pieces of things other than the actual VACUUM.
sub vacuum {
	if ( DEBUG ) {
		TRACE("VACUUM ANALYZE database");
		my $page_size = Padre::DB->pragma("page_size");
		Padre::DB->do('VACUUM');
		Padre::DB->do('ANALYZE');
		my $diff = Padre::DB->pragma('page_size') - $page_size;
		TRACE("Page count difference after VACUUM ANALYZE: $diff");
	} else {
		Padre::DB->do('VACUUM');
		Padre::DB->do('ANALYZE');
	}
	return;
}

1;

__END__

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

=pod

=head1 NAME

Padre::DB - An ORLite-based ORM Database API

=head1 SYNOPSIS

TO BE COMPLETED

=head1 DESCRIPTION

This module implements access to the database that Padre is using to
store bits & pieces. It is using C<ORLite> underneath, for an easy table
scheme discovery at runtime. See below to learn about how to update the
database scheme.

=head2 Updating database scheme

The database is created at runtime if it does not exist, but we are
relying on C<Padre::DB::Migrate>. To summarize C<Padre::DB::Migrate>:

=over 4

=item * We provide scripts to update the database from one revision to
another.

=item * C<Padre::DB> calls C<Padre::DB::Migrate> to apply them in order,
starting from the current database revision.

=back

Therefore, in order to update the database, you need to do the
following:

=over 4

=item *

Create a script F<share/timeline/migrate-$i.pl> with C<$i> the next
available integer. This script will look like this:

        use strict;
        use Padre::DB::Migrate::Patch;

        # do some stuff on the base
        do(<<'END_SQL');
        <insert your sql statement here>
        END_SQL

Of course, in case of dropping an existing table, you should make sure
that you don't loose data - that is, your script should migrate existing
data to the new scheme (unless the whole feature is deprecated, of
course).

=item *

Update the user_revision in C<Padre::DB>'s call to C<Padre::DB::Migrate> to
read the new script number (i.e., the C<$i> that you have used to name your
script in the F<timeline> directory).

        use Padre::DB::Migrate 0.01 {
            [...]
	        user_revision => <your-revision-number>,
            [...]
        };

=item *

Once this is done, you can try to load Padre's development and check
whether the table is updated correctly. Once again, check whether data
is correctly migrated from old scheme to new scheme (if applicable).

Note that C<Padre::DB::Migrate> is quiet by default. And if your SQL
statements are buggy, you will not see anything but the database not
being updated. Therefore, to debug what's going on, add the C<-DEBUG>
flag to C<Padre::DB::Migrate> call (add it as the B<last> parameter):

        use Padre::DB::Migrate 0.01 {
            [...]
        }, '-DEBUG'

=back

Congratulations! The database has been updated, and will be updated
automatically when users will run the new Padre version...

=head2 Accessing and using the database

Now that the database has been updated, you can start using it. Each new
table will have a C<Padre::DB::YourTable> module created automatically
at runtime by C<ORLite>, providing you with the standard methods
described below (see METHODS).

Note: we prefer using underscore for table names instead of camel case.
C<ORLite> is smart enough to convert underscore names to camel case
module names.

But what if you want to provide some particular methods? For example,
one can imagine that if you create a table C<accessed_files> retaining
the path and the opening timestamp, you want to create a method
C<most_recent()> that will return the last opened file.

In that case, that's quite easy, too:

=over 4

=item *

Create a standard C<Padre::DB::YourTable> module where you will put your
method. Note that all standard methods described above will B<still> be
available.

=item *

Don't forget to C<use Padre::DB::YourTable> in C<Padre::DB>, so that
other Padre modules will get access to all db tables by just using
C<Padre::DB>.

=back

=head1 METHODS

Those methods are automatically created for each of the tables (see
above). Note that the modules automatically created provide both class
methods and instance methods, where the object instances each represent
a table record.

=head2 dsn

  my $string = Padre::DB->dsn;

The C<dsn> accessor returns the L<DBI> connection string used to connect
to the SQLite database as a string.

=head2 dbh

  my $handle = Padre::DB->dbh;

To reliably prevent potential L<SQLite> deadlocks resulting from multiple
connections in a single process, each ORLite package will only ever
maintain a single connection to the database.

During a transaction, this will be the same (cached) database handle.

Although in most situations you should not need a direct DBI connection
handle, the C<dbh> method provides a method for getting a direct
connection in a way that is compatible with connection management in
L<ORLite>.

Please note that these connections should be short-lived, you should
never hold onto a connection beyond your immediate scope.

The transaction system in ORLite is specifically designed so that code
using the database should never have to know whether or not it is in a
transation.

Because of this, you should B<never> call the -E<gt>disconnect method
on the database handles yourself, as the handle may be that of a
currently running transaction.

Further, you should do your own transaction management on a handle
provided by the <dbh> method.

In cases where there are extreme needs, and you B<absolutely> have to
violate these connection handling rules, you should create your own
completely manual DBI-E<gt>connect call to the database, using the connect
string provided by the C<dsn> method.

The C<dbh> method returns a L<DBI::db> object, or throws an exception on
error.

=head2 begin

  Padre::DB->begin;

The C<begin> method indicates the start of a transaction.

In the same way that ORLite allows only a single connection, likewise
it allows only a single application-wide transaction.

No indication is given as to whether you are currently in a transaction
or not, all code should be written neutrally so that it works either way
or doesn't need to care.

Returns true or throws an exception on error.

=head2 commit

  Padre::DB->commit;

The C<commit> method commits the current transaction. If called outside
of a current transaction, it is accepted and treated as a null operation.

Once the commit has been completed, the database connection falls back
into auto-commit state. If you wish to immediately start another
transaction, you will need to issue a separate -E<gt>begin call.

Returns true or throws an exception on error.

=head2 rollback

The C<rollback> method rolls back the current transaction. If called outside
of a current transaction, it is accepted and treated as a null operation.

Once the rollback has been completed, the database connection falls back
into auto-commit state. If you wish to immediately start another
transaction, you will need to issue a separate -E<gt>begin call.

If a transaction exists at END-time as the process exits, it will be
automatically rolled back.

Returns true or throws an exception on error.

=head2 do

  Padre::DB->do(
      'insert into table ( foo, bar ) values ( ?, ? )', {},
      \$foo_value,
      \$bar_value,
  );

The C<do> method is a direct wrapper around the equivalent L<DBI> method,
but applied to the appropriate locally-provided connection or transaction.

It takes the same parameters and has the same return values and error
behaviour.

=head2 selectall_arrayref

The C<selectall_arrayref> method is a direct wrapper around the equivalent
L<DBI> method, but applied to the appropriate locally-provided connection
or transaction.

It takes the same parameters and has the same return values and error
behaviour.

=head2 selectall_hashref

The C<selectall_hashref> method is a direct wrapper around the equivalent
L<DBI> method, but applied to the appropriate locally-provided connection
or transaction.

It takes the same parameters and has the same return values and error
behaviour.

=head2 selectcol_arrayref

The C<selectcol_arrayref> method is a direct wrapper around the equivalent
L<DBI> method, but applied to the appropriate locally-provided connection
or transaction.

It takes the same parameters and has the same return values and error
behaviour.

=head2 selectrow_array

The C<selectrow_array> method is a direct wrapper around the equivalent
L<DBI> method, but applied to the appropriate locally-provided connection
or transaction.

It takes the same parameters and has the same return values and error
behaviour.

=head2 selectrow_arrayref

The C<selectrow_arrayref> method is a direct wrapper around the equivalent
L<DBI> method, but applied to the appropriate locally-provided connection
or transaction.

It takes the same parameters and has the same return values and error
behaviour.

=head2 selectrow_hashref

The C<selectrow_hashref> method is a direct wrapper around the equivalent
L<DBI> method, but applied to the appropriate locally-provided connection
or transaction.

It takes the same parameters and has the same return values and error
behaviour.

=head2 prepare

The C<prepare> method is a direct wrapper around the equivalent
L<DBI> method, but applied to the appropriate locally-provided connection
or transaction

It takes the same parameters and has the same return values and error
behaviour.

In general though, you should try to avoid the use of your own prepared
statements if possible, although this is only a recommendation and by
no means prohibited.

=head2 pragma

  # Get the user_version for the schema
  my $version = Padre::DB->pragma('user_version');

The C<pragma> method provides a convenient method for fetching a pragma
for a database. See the L<SQLite> documentation for more details.

=head1 SUPPORT

B<Padre::DB> is based on L<ORLite>.

Documentation created by L<ORLite::Pod> 0.10.

For general support please see the support section of the main
project documentation.

=head1 AUTHOR

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
