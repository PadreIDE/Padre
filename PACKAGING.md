Packaging Padre
===============

Arch Linux
----------
  https://aur.archlinux.org/packages.php?ID=31057

Debian
-------
The latest information about the Debian package is available at http://packages.debian.org/sid/main/padre

The package maintainers are Damyan Ivanov and Ryan Niebur.

Padre in the Debian QA package tracking system: http://packages.qa.debian.org/p/padre.html

Some usage statistics collected by Debian's popularity-contest program can be found on this page: http://qa.debian.org/popcon.php?package=padre
As of September 2010, Padre is installed on at least 121 computers running Debian, and is in regular use on at least 21 of them.

See also the Debian installation instructions.

List of Padre related packages in Debian: http://packages.debian.org/search?keywords=padre&searchon=names&suite=testing&section=all

Plugins packaging needs some help. See http://www.debian.org/devel/wnpp/prospective and search for "libpadre-"
for a list of packages that have been started but aren't yet done. If you want to help, please
contact debian-perl@lists.debian.org or come to the #debian-perl IRC channel on irc.debian.org (OFTC network).



Fedora
-------
Marcela Maslanova (marcela) keeps Padre up to date in Fedora.

https://admin.fedoraproject.org/pkgdb/acls/name/perl-Padre

Unofficial (s)rpms for 0.42 with requirements: http://mmaslano.fedorapeople.org/padre/

FreeBSD
-------

Gentoo
------
Torsten Veller (tove) is the maintainer of Gentoo's Padre package.

http://packages.gentoo.org/package/app-editors/padre

Mac OSX
--------

Mandriva
--------

Jerome Quelin (jq on IRC, jquelin) who is both a Padre developer and a Mandriva maintainer keeps Padre up to date in Mandriva.

NetBSD
------

OpenBSD
-------


Ubuntu
-------

Ubuntu is synchronizing Padre from Debian. See the launchpad for details:

https://launchpad.net/ubuntu/+source/padre
Its page in Launchpad is https://launchpad.net/padre
link to where they import our SVN repository https://code.launchpad.net/~vcs-imports/padre/trunk
See also #ubuntu-motu on Freenode
https://edge.launchpad.net/~perl seems to be the group dealing with perl stuff, I sent them a message on 2009.02.06 asking for help
https://edge.launchpad.net/~perl-jam might also help but that is a one man group so I left it alone for now.
Some more useful links

https://wiki.ubuntu.com/UbuntuDevelopment/NewPackages
https://wiki.ubuntu.com/MOTU
https://wiki.ubuntu.com/FAQ
The request: https://bugs.launchpad.net/ubuntu/+bug/326353
Popularity contest statistics

According to http://popcon.ubuntu.com/by_vote, Padre is installed on 998 computers running Ubuntu, and is regularly used on 106 (as of September 2010).


MS Windows
-----------

*Padre Standalone*

This packaging is for people who already have Perl installed either locally or are working on a remote perl (via ssh or ftp) or later for people who do not even work on Perl code.

It is packaged as an .msi installer available on the official padre download page (http://padre.perlide.org/download.html).
Installation notes are shown on the howto page. (http://padre.perlide.org/howto.html)

The 0.56 MSI package still requires installation to c:\strawberry, but there are plans to make it portable (installable everywhere) but it doesn't need to be truly portable (that is movable after installation).

Improvements listed here are expected to appear in the Q2/2010 packages.

See details on PadreStandalone

*Padre Standalone Portable*

This distribution should contain the same as the Stand alone Padre above but it should be packaged as zip file and it should be relocatable. The user can unzip it anywhere (including a disk-on key) and move it to any other place. It does not create a shortcut for itself nor does it make any change to the system. (Maybe we can include a utility that does it)

Actually I am not sure how important is this version.

There is a Perl::Dist::Padre module that will allow us to create a Perl distribution that has Padre already installed. At one point we might be able to install this distribution independently from any other perl installation on the same machine. That will mean the 'production perl' of the user and the perl needed by Padre does not need to be the same. Padre already supports a different Perl interpreter for running and checking files than the version running Padre. Enter the path+filename of your Perl binary in the preferences dialog.

*Almost Six*

Almost Six is an experimental package that contains Strawberry Perl 5 + a recent release of Rakudo Perl 6 + Padre + the Perl 6 plugin of Padre. It is release about once a month after Rakudo is released and it includes the latest Padre release from CPAN.

Later maybe also include the Parrot plugin along with Cardinal, Pipp, Pynie and other languages running on Parrot. In time this can become an IDE-for-Parrot release instead of the Almost Six release.

See BuildingOnPortableStrawberry on how to build and include Rakudo

*Strawberry Professional*

This is a package the Strawberry developers will create that will also include Padre and a lot of other things. Talk to Alias or CSJewell regarding this.

*ActivePerl*

Mark Dootson provides PPMs for Padre. They are available from http://www.wxperl.co.uk/repository/ppm-repository.html



