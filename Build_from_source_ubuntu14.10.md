Work in progress...

This instructions reflect and installation using perlbrew (http://perlbrew.pl/).

Get the OS dependencies
$ sudo apt-get install libgtk-3-dev libwxgtk3.0-dev

Install CPAN modules needed for development
$ cpanm Module::Install Locale::Msgfmt

Install "tricky" modules: Alien::wxWidgets and Wx
Alien::wxWidgets does not build with wxWidgets 3.0.0. We need version 3.0.1, so we need to patch Alien::wxWidgets.
$ mkdir -p ~/tmp/ && cd ~/tmp && cpan -g Alien::wxWidgets && tar xvzf Alien-wxWidgets-*.tar.gz && cd Alien-wxWidgets-*
$ cp patches/data-3.0.0 patches/data-3.0.1
$ perl -pi -e 's/3\.0\.0/3.0.1/g' Build.PL patches/data-3.0.1
$ export CXXFLAGS="-std=gnu++11"
(Accept all the defaults)
$ perl Build.PL
$ perl Build
$ perl Build test
$ perl Build install
$ cd ~/tmp
$ cpan -q Wx && tar xvzf Wx-*.tar.gz && cd Wx*
$ perl Makefile.PL
# This is UGLY:
$ find . -name Makefile -exec perl -pi -e 's/(g\+\+ -pthread)/$1 -std=gnu++11/g' {} \;
$ make


