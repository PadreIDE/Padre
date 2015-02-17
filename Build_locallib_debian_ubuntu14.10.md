Work in progress...

These instructions use local::lib (https://metacpan.org/pod/local::lib) to set up the padre sources. Ubuntu 14.10 has a recent perl (5.20.1) and padre (1.00). This is also the case for Debian testing and unstable. Kudos to the Debian Perl Group (https://pkg-perl.alioth.debian.org/).

1. Get the OS dependencies. The easieast way is just to install the packaged padre. Its dependencies include local::lib.
$ sudo apt-get install padre

2. Get development dependencies for Padre.
$ cpanm -l ~/perl5 Module::Install 

3. Clone Padre (use ssh if you have a github account).
$ mkdir -p ~/Code && cd ~/Code
$ git clone https://github.com/PadreIDE/Padre.git

4. Install Padre and dependencies.
$ cpanm -l ~/perl5 .

5. Run Padre 
a. in dev mode:
$ ./dev 
b. or installed app:
$ ~/perl5/bin/padre
(or as the one supplied in Ubuntu: $ padre)




