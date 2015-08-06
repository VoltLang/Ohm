===
Ohm
===

Getting started
===============

Dependencies
------------

Ohm shares the dependencies of `Volta <https://github.com/VoltLang/Volta/>`_.
Ohm additionally requires libreadline.


Linux
*****

On Linux installing libreadline with your packagemanager is enough:

::

  $ sudo apt-get install libreadline-dev


Building
--------

The makefile expects Volta:ohm in the src/Volta directory,
you can use the following command to set it up:

::

  $ make init


To build Ohm:

::

  $ make


Running
-------

Ohm requires a few commandline arguments to hint it where the runtime
and the gc library is located:

::

  $ ./ohm --stdlib-file ../Volta/rt/libvrt-host.bc --stdlib-I ../Volta/rt/src -l /usr/lib/libgc.so


You can also store this information in a file called `ohm.conf`:

::

  --stdlib-file
  ../Volta/rt/libvrt-%@arch%-%@platform%.bc
  --stdlib-I
  ../Volta/rt/src
  -l
  /usr/lib/libgc.so


The makefile tries to be smart about these values,
the following command is most likely all you need:

::

  make run
