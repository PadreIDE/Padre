package Padre::Locale::T;

# See POD at the end of the file for documentation

use 5.008;
use strict;
use warnings;
use Exporter ();

our $VERSION   = '0.94';
our @ISA       = 'Exporter';
our @EXPORT    = '_T';
our @EXPORT_OK = '_T';

# Pasting more background information for people that don't understand
# the POD docs, because at least one person has accidentally broken this
# by changing it (not cxreg, he actually asked first) :)
#15:31 cxreg Alias: er, how it's just "shift" ?
#15:31 Alias cxreg: Wx has a gettext implementation
#15:31 Alias Wx::gettext
#15:31 Alias That's the "translate right now" function
#15:31 Alias But we need a late-binding version, for things that need to be translated, but are kept in memory (for various reasons) as English and only get translated at the last second
#15:32 Alias So in that case, we do a Wx::gettext($string)
#15:32 Alias The problem is that the translation tools can't tell what $string is
#15:32 Alias The translation tools DO, however, recognise _T as a translatable string
#15:33 Alias So we use _T as a silent pass-through specifically to indicate to the translation tools that this string needs translating
#15:34 Alias If we did everything as an up-front translation we'd need to flush a crapton of stuff and re-initialise it every time someone changed languages
#15:35 Alias Instead, we flush the hidden dialogs and rebuild the entire menu
#15:35 Alias But most of the rest we do with the delayed _T strings
#15:37 cxreg i get the concept, it's just so magical
#15:38 Alias It works brilliantly :)
#15:38 cxreg do you replace the _T symbol at runtime?
#15:39 Alias symbol?
#15:39 Alias Why would we do that?
#15:40 cxreg in order to actually instrument the translation, i wasn't sure if you were swapping out the sub behind the _T symbol
#15:40 Alias oh, no
#15:40 Alias _T is ONLY there to hint to the translation tools
#15:40 Alias The PO editors etc
#15:40 Alias my $english = _T('Hello World!'); $gui->set_title( Wx::gettext($english) );
#15:41 Alias It does absolutely nothing inside the code itself
sub _T {
	shift;
}

1;

__END__

=pod

=head1 NAME

Padre::Locale::T - Provides _T for declaring translatable strings

=head1 SYNOPSIS

  use Padre::Locale::T;
  
  my $string = _T('This is a test');

=head1 DESCRIPTION

Padre uses a function called _T to declare strings which should be
translated by the translation team, but which should not be immediately
localised in memory.

This is done primarily because the active language may change between
when a string is initially stored in memory and when it is show to a user.

The reason we use _T is that most translation tools in the wild that scan
the code for a program detect the use of a C macro calls _T that does
immediate translation.

By creating a null pass through function called _T and the linguistic
similarity of Perl to C, we can take advantage of the way translation tools
detect translatable strings while keeping the proper Wx::gettext function
for strings which do need to be translated immediately.

The _T function used to live in L<Padre::Util>, but as that module gradually
bloated it was increasing the code of getting the _T function dramatically.

Padre::Locale::T declares only this one function, and will only ever do so.

Because of this, it also exports by default (although you are still welcome
to declare the import if you wish.

=head1 FUNCTIONS

=head2 C<_T>

The C<_T> function is used for strings that you do not want to translate
immediately, but you will be translating later (multiple times).

The only reason this function needs to exist at all is so that the
translation tools can identify the string it refers to as something that
needs to be translated.

Functionally, this function is just a direct pass-through with no effect.

=head1 COPYRIGHT

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
