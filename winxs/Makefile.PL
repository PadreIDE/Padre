# -*- mode: perl; c-basic-offset: 4; indent-tabs-mode: nil; -*-
use strict;
use ExtUtils::MakeMaker;
use Config;

my $libs = ( $Config{cc} =~ /cl/ ) ? 'psapi.lib' : '-lpsapi';

$libs = '' if $^O !~ /^mswin/i;

WriteMakefile(
    NAME            => 'Padre::Util::Win32',
    VERSION_FROM    => '../lib/Padre/Util/Win32.pm',
    ABSTRACT_FROM   => '../lib/Padre/Util/Win32.pm',
    AUTHOR          => 'Gabor Szabo', # Same as Padre
    LIBS            => $libs,
    DEFINE          => '-DPSAPI_VERSION=1',
);
