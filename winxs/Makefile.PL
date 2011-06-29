use 5.008005;
use strict;
use ExtUtils::MakeMaker qw( WriteMakefile WriteEmptyMakefile );
use Config;

my %params = (
    NAME            => 'Padre::Util::Win32',
    VERSION_FROM    => '../lib/Padre/Util/Win32.pm',
    ABSTRACT        => 'Padre Win32 API XS Wrapper',
    SKIP            => [ qw( test ) ],
);

if($^O =~ /^mswin/i) {
    my $libs = ( $Config{cc} =~ /cl/ ) ? 'psapi.lib' : '-lpsapi';
    $params{LIBS} = [ $libs ];
    $params{DEFINE} = '-DPSAPI_VERSION=1';
    WriteMakefile(%params);
}   else {
    # WriteEmptyMakefile seems to need params to avoid warnings
    WriteEmptyMakefile(%params);
}

sub MY::postamble {
    return qq(\n) . 'test :' . qq(\n);
}

1;
