These instructions use local::lib (https://metacpan.org/pod/local::lib) to build the padre sources. Ubuntu 14.10 has a recent perl (5.20.1) and padre (1.00). This is also the case for Debian testing and unstable. Kudos to the Debian Perl Group (https://pkg-perl.alioth.debian.org/).

* Get the OS dependencies. The easieast way is just to install the packaged padre. Its dependencies include local::lib:
```
$ sudo apt-get install padre
```
This padre can of course be starting by just typing:
`$ padre`

* Get development dependencies for Padre:
`$ cpanm -l ~/perl5 Module::Install` 

* Clone Padre (use ssh if you have a github account):
```
$ mkdir -p ~/Code && cd ~/Code
$ git clone https://github.com/PadreIDE/Padre.git
```
* Install Padre and dependencies:
`$ cpanm -l ~/perl5 .`

* Run Padre:
  * in dev mode:
`$ ./dev` 
  * or installed app:
`$ ~/perl5/bin/padre`







