use 5.008005;
use strict;
use ExtUtils::MakeMaker;
use Config;

my %mparams = (
    NAME            => 'Padre::Util::Win32',
    VERSION_FROM    => '../lib/Padre/Util/Win32.pm',
    ABSTRACT        => 'Padre Win32 API XS Wrapper',
    AUTHOR          => 'Gabor Szabo', # Same as Padre
);

if($^O =~ /^mswin/i) {
    my $libs = ( $Config{cc} =~ /cl/ ) ? 'psapi.lib' : '-lpsapi';
    $mparams{LIBS}   = [ $libs ];
    $mparams{DEFINE} = '-DPSAPI_VERSION=1';
}

WriteMakefile(%mparams);

1;
