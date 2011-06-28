use 5.008005;
use strict;
use ExtUtils::MakeMaker qw( WriteMakefile WriteEmptyMakefile );
use Config;

if($^O =~ /^mswin/i) {
    my $libs = ( $Config{cc} =~ /cl/ ) ? 'psapi.lib' : '-lpsapi';
    
    WriteMakefile(
        NAME            => 'Padre::Util::Win32',
        VERSION_FROM    => '../lib/Padre/Util/Win32.pm',
        ABSTRACT        => 'Padre Win32 API XS Wrapper',
        AUTHOR          => 'Gabor Szabo', # Same as Padre
        LIBS            => [ $libs ],
        DEFINE          => '-DPSAPI_VERSION=1',
    
    );
    
}   else {
    # WriteEmptyMakefile seems to need params to avoid warnings
    WriteEmptyMakefile(
        NAME            => 'Padre::Util::Win32',
        VERSION_FROM    => '../lib/Padre/Util/Win32.pm',
        ABSTRACT        => 'Padre Win32 API XS Wrapper',
        AUTHOR          => 'Gabor Szabo', # Same as Padre
    );
    
}


1;
