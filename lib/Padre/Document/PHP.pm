package Padre::Document::PHP;

use 5.008;
use strict;
use warnings;
use Padre::Document ();

our $VERSION = '0.91';
our @ISA     = 'Padre::Document';

# PHP Keywords
# The list is obtained from src/scite/src/html.properties
sub scintilla_key_words {
	return [
		[   qw(and array as bool boolean break case cfunction class const continue declare
default die directory do double echo else elseif empty enddeclare endfor
endforeach endif endswitch endwhile eval exit extends false float for
foreach function global goto if include include_once int integer isset list namespace
new null object old_function or parent print real require require_once resource
return static stdclass string switch true unset use var while xor
abstract catch clone exception final implements interface php_user_filter
private protected public this throw try
__class__ __dir__ __file__ __function__ __line__ __method__
__namespace__ __sleep __wakeup
)
		],
	];
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
