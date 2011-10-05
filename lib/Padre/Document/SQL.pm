package Padre::Document::SQL;

use 5.008;
use strict;
use warnings;
use Padre::Document::DoubleDashComment ();

our $VERSION = '0.91';
our @ISA     = qw{
	Padre::Document::DoubleDashComment
};

# SQL Keywords
# The list is obtained from src/scite/src/sql.properties
sub lexer_keywords {
	return [
		[   qw(absolute action add admin after aggregate
				alias all allocate alter and any are array as asc
				assertion at authorization
				before begin binary bit blob body boolean both breadth by
				call cascade cascaded case cast catalog char character
				check class clob close collate collation column commit
				completion connect connection constraint constraints
				constructor continue corresponding create cross cube current
				current_date current_path current_role current_time current_timestamp
				current_user cursor cycle
				data date day deallocate dec decimal declare default
				deferrable deferred delete depth deref desc describe descriptor
				destroy destructor deterministic dictionary diagnostics disconnect
				distinct domain double drop dynamic
				each else end end-exec equals escape every except
				exception exec execute exists exit external
				false fetch first float for foreign found from free full
				function
				general get global go goto grant group grouping
				having host hour
				identity if ignore immediate in indicator initialize initially
				inner inout input insert int integer intersect interval
				into is isolation iterate
				join
				key
				language large last lateral leading left less level like
				limit local localtime localtimestamp locator
				map match minute modifies modify module month
				names national natural nchar nclob new next no none
				not null numeric
				object of off old on only open operation option
				or order ordinality out outer output
				package pad parameter parameters partial path postfix precision prefix
				preorder prepare preserve primary
				prior privileges procedure public
				read reads real recursive ref references referencing relative
				restrict result return returns revoke right
				role rollback rollup routine row rows
				savepoint schema scroll scope search second section select
				sequence session session_user set sets size smallint some| space
				specific specifictype sql sqlexception sqlstate sqlwarning start
				state statement static structure system_user
				table temporary terminate than then time timestamp
				timezone_hour timezone_minute to trailing transaction translation
				treat trigger true
				under union unique unknown
				unnest update usage user using
				value values varchar variable varying view
				when whenever where with without work write
				year
				zone)
		],
	];
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
