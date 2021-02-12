# Padre [![Build Status](https://travis-ci.org/PadreIDE/Padre.png?branch=master)](https://travis-ci.org/PadreIDE/Padre)[![Coverage Status](https://coveralls.io/repos/github/PadreIDE/Padre/badge.svg?branch=master)](https://coveralls.io/github/PadreIDE/Padre?branch=master)

### Perl Application Development and Refactoring Environment

A Perl IDE and general-purpose editor using WxWidgets.

## Installation

* Alien::wxWidgets
* Wx
* Padre

For detailed installation instructions look at 

http://padre.perlide.org/wiki/Download

## ToDo

- [x] convert from svn to github kaare++
- [x] travis intergration alias++ bowtie++
- [ ] contributors guide
  - [ ] use of tools perltidyrc
  - [ ] spell checking
  - [ ] use of [skip ci](http://docs.travis-ci.com/user/how-to-skip-a-build/) for \*.mb and pod files
  - [ ] use of gists
- [ ] conversion of trac features szabgab++
- [ ] conversion of RT to issues karre++
- [x] irc info bowtie++
- [ ] #padre notifications
- [ ] padre developers wiki

## License

The Padre source code is distributed under the same terms as Perl itself. 
Namely:

1. The GNU General Public License, either version 1 or at your option,
any later version. (see the file "COPYING").

2. The Artistic License of Perl. (see the file "Artistic").


--------------------------------------------------------
For other Copyrights and Licenses see also

share/icons/padre/README.txt
share/icons/gnome218/README.txt

## Development

In order to develop Padre on Ubuntu we will use the system-perl.
Install the available packages using

```
./install_on_ubuntu
```

Then install the remaining missing packages that are not distributed by Ubuntu:

```
curl -L https://cpanmin.us | perl - App::cpanminus
~/perl5/bin/cpanm --local-lib=~/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
```

Add the following line to ~/.bashrc (or similar file that is loaded when you open a terminal)

```
eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
```

Then open a new terminal and type in

```
perl Makefile.PL
```

Install the missing modules:

```
cpanm Parse::Functions Debug::Client
```

```
perl Makefile.PL
make
./dev
```


