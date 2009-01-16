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
	user_revision => 3,
	timeline      => File::Spec->catdir(
		File::ShareDir::PAR::dist_dir('Padre'),
		'timeline',
	),
};

our $VERSION    = '0.25';
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

__END__

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

=pod

=head1 NAME

Padre::DB - An ORLite-based ORM Database API

=head1 SYNOPSIS

  TO BE COMPLETED

=head1 DESCRIPTION

TO BE COMPLETED

=head1 METHODS

=head2 dsn

  my $string = Foo::Bar->dsn;

The C<dsn> accessor returns the dbi connection string used to connect
to the SQLite database as a string.

=head2 dbh

  my $handle = Foo::Bar->dbh;

To reliably prevent potential SQLite deadlocks resulting from multiple
connections in a single process, each ORLite package will only ever
maintain a single connection to the database.

During a transaction, this will be the same (cached) database handle.

Although in most situations you should not need a direct DBI connection
handle, the C<dbh> method provides a method for getting a direct
connection in a way that is compatible with ORLite's connection
management.

Please note that these connections should be short-lived, you should
never hold onto a connection beyond the immediate scope.

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

  Foo::Bar->begin;

The C<begin> method indicates the start of a transaction.

In the same way that ORLite allows only a single connection, likewise
it allows only a single application-wide transaction.

No indication is given as to whether you are currently in a transaction
or not, all code should be written neutrally so that it works either way
or doesn't need to care.

Returns true or throws an exception on error.

=head2 commit

  Foo::Bar->commit;

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

  Foo::Bar->do('insert into table (foo, bar) values (?, ?)', {},
      $foo_value,
      $bar_value,
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
  my $version = Foo::Bar->pragma('user_version');

The C<pragma> method provides a convenient method for fetching a pragma
for a datase. See the SQLite documentation for more details.

=head1 SUPPORT

Padre::DB is based on L<ORLite> 1.18.

Documentation created by L<ORLite::Pod> 0.06.

For general support please see the support section of the main
project documentation.

=head1 AUTHOR

Adam Kennedy

=head1 COPYRIGHT

Copyright 2009 Adam Kennedy.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
