Work in progress...

This instructions are meant to run a development release of padre using perlbrew (http://perlbrew.pl/). As such it uses a perl installation completely apart from the install system perl and modules.

1. Set up perlbrew. Follow the instructions here.

2. Get the OS dependencies for building Padre.
$ sudo apt-get install libgtk-3-dev libwxgtk3.0-dev

3. Install CPAN modules needed for development
$ cpanm Module::Install Locale::Msgfmt

4. Build the"tricky" modules: Alien::wxWidgets and Wx
a. Alien::wxWidgets does not build with wxWidgets 3.0.0. We need version 3.0.1, so we need to patch Alien::wxWidgets (https://rt.perl.org/Ticket/Display.html?id=121930)
$ cpanm Module::Pluggable # needed for module test
$ mkdir -p ~/tmp/ && cd ~/tmp && cpan -g Alien::wxWidgets && tar xvzf Alien-wxWidgets-*.tar.gz && cd Alien-wxWidgets-*
$ wget https://rt.cpan.org/Ticket/Attachment/1400329/743429/wx-config-version-and-env.patch
$ patch < wx-config-version-and-env.patch
# Accept all the defaults: choose 'no' and use the wxWidgets 3.0.1 libs from /usr)
$ perl Build.PL
$ perl Build
$ perl Build test
$ perl Build install
b. Build Wx.pm (does not work yet,see https://rt.cpan.org/Ticket/Display.html?id=102135)
# Get test dependency
$ cpanm ExtUtils::XSpp
$ cd ~/tmp
$ /usr/bin/cpan -g Wx
$ tar xvzf Wx-*.tar.gz && cd Wx*
$ perl Makefile.PL --extra-cflags='-std=gnu++11'
$ make
$ make test
$ make install


