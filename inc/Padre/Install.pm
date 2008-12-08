package Padre::Install;
use Module::Build;
@ISA = qw(Module::Build);

sub ACTION_code {
    my $self = shift;

    $self->SUPER::ACTION_code(@_);

    use FindBin               ();
    use File::Spec::Functions qw(catfile catdir);
    require File::Copy::Recursive;
    import  File::Copy::Recursive qw(dircopy);

    my $dir =  catdir($FindBin::Bin, 'blib', 'lib', 'auto', 'share', 'dist', $self->dist_name);
    dircopy(catfile($FindBin::Bin, 'share'), $dir);
    return;
}

sub ACTION_exe {
    my $self = shift;

    # temporary tool to create executable using PAR
    eval "use Module::ScanDeps 0.88; 1;" or die $@;


    my @libs    = libs();
    my @modules = modules();
    my $exe     = $^O =~ /win32/i ? 'padre.exe' : 'padre';
    if (-e $exe) {
        unlink $exe or die "Cannot remove '$exe' $!";
    }
    my @cmd     = ('pp', '-o', $exe, qw(-I lib script/padre));
    push @cmd, @modules, @libs;
    if ($^O =~ /win32/i) {
        push @cmd, '-M', 'Tie::Hash::NamedCapture';
    }

    print "@cmd\n";
    system(@cmd);

    return;
}

#
# ./Build pot
#
# update messages.pot file with new strings detected.
#
sub ACTION_pot {
	use FindBin               qw{ $Bin };
    use File::Spec::Functions qw{ catfile catdir };
    use File::Find;

	my $localedir = catdir ( $Bin, 'share', 'locale' );
	my $potfile   = catfile( $localedir, 'messages.pot' );
	my $pmfiles   = catfile( $Bin, 'files.txt' );

	# build list of perl modules from where to extract strings
	my @pmfiles;
	find( sub {
			return unless /\.pm$/;
			push @pmfiles, $File::Find::name;
		}, $Bin );
	open my $fh, '>', $pmfiles or die "cannot open '$pmfiles': $!\n";
	print $fh map { "$_$/" } @pmfiles;
	close $fh;

	# update pot file
	unlink $potfile;
	system("xgettext -o $potfile -f $pmfiles") == 0
		or die "xgettext exited with return code " . $? >> 8;

	# cleanup
	unlink $pmfiles;
}

sub libs {
    require Alien::wxWidgets;
    Alien::wxWidgets->import(); # needed to make it work
    require File::Find;
    my @libs = Alien::wxWidgets->shared_libraries(
      qw(stc xrc html adv core base) 
    );

# formerly, we needed to put the libs verbatim:
#    qw(
#                libwx_gtk2_adv-2.8.so.0
#                libwx_gtk2_core-2.8.so.0
#                libwx_base-2.8.so.0
#                libwx_base_net-2.8.so.0
#                libwx_gtk2_stc-2.8.so.0
#                libwx_gtk2_html-2.8.so.0
#    );

    my %libs = map {($_,0)} @libs;
    my $prefix = Alien::wxWidgets->prefix;
    
    File::Find::find(
      sub {
          if (exists $libs{$_}) {
            $libs{$_} = $File::Find::name;
          }
      },
      $prefix
    );

    my @missing = grep {!$libs{$_}} keys %libs;
    warn "Could not find shared library on disk for $_"
      for @missing;

    my @libs_args;
    push @libs_args, "-l", $_ for values %libs;

    return @libs_args;
}


sub modules {

    my @modules;
    my @files;

    open my $fh, '<', 'MANIFEST' or die $!;
    while (my $line = <$fh>) {
        chomp $line;
        if ($line =~ m{^lib/}) {
            $line = substr($line, 4, -3);
            $line =~ s{/}{::}g;
            push @modules, $line;
        }
        if ($line =~ m{^share/}) {
            push @files, $line;
        }
    }
    my @args;
    push @args, "-M", $_ for @modules;
    push @args, "-a", $_ for @files;

    return @args;
}



1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
