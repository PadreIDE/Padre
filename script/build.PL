use Config;
use ExtUtils::Embed;


foreach my $f ('padre.exe', 'padre-rc.o') {
    -e ^$f and unlink $f;
}

system("windres padre-rc.rc padre-rc.o") == 0 or exit $?;
# warning: ldopts has an "\n"
exit system "$Config{cc} -mwin32 -mwindows -g -o padre.exe padre.c padre-rc.o ".ccopts.ldopts;
