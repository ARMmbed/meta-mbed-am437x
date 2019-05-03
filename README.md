# meta-mbed-am437x

This README file contains information on the contents of the
`meta-mbed-am437x` layer.

The `meta-mbed-am437x` layer can be used to build an SD-card image for TI 
AM437x EVM with partitioning capable of firmware update through the Mbed 
Cloud Client. 


# Dependencies

The Mbed Edge on TI AM437x EVM is currently built and tested on top of 
`Arago`-distribution found with TI processor SDK version 05_02_00_10. 
`am437x-mbed-image` build target extends `arago-base-tisdk-image` from 
this TI processor SDK.

See the following link for details on how to set up your Arago build.
Use `processor-sdk-05.02.00.10-config.txt` configuration.

[Build SDK](http://software-dl.ti.com/processor-sdk-linux/esd/docs/05_02_00_10/linux/Overview_Building_the_SDK.html)


# Adding the `meta-mbed-am437x` layer to your build

In order to use this layer, you need to make the build system aware of
it.

Assuming the `meta-mbed-am437x` layer exists at the top-level of your
Arago Yocto build tree, you can add it to the build system by adding the
location of the `meta-mbed-am437x` layer to `bblayers.conf`,
along with any other layers needed. e.g.:

```
BBLAYERS += " \
    ../tisdk/sources/meta-processor-sdk \
    ../tisdk/sources/meta-ros \
    ../tisdk/sources/meta-arago/meta-arago-distro \
    ../tisdk/sources/meta-arago/meta-arago-extras \
    ../tisdk/sources/meta-openembedded/meta-oe \
    ../tisdk/sources/meta-ti \
    ../tisdk/sources/meta-mbed-am437x \
    "
```

# Build

To use this layer set your `MACHINE` variable on your bitbake build command
along with your build target as follows:

```
$ MACHINE=mbed-am437x bitbake am437x-mbed-image
```
