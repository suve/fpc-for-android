# fpc-for-android

An example repository showing how to use the build the Free Pascal Compiler
to allow cross-compilation for Android. It constists of a Containerfile,
used to build the Android cross-compiler, and some helper scripts.

## Requirements

To build the container, you'll need the following:
- Android Native Development Kit r21d
- Buildah (or Docker)
- Free Pascal Compiler v3.2.2 sources


### Android tools

You can download the Android Native Development Kit from the 
[Android developer portal](https://developer.android.com/ndk/downloads/). 


### Free Pascal Compiler source code

You can download the FPC source code from the
[FPC downloads page](https://www.freepascal.org/down/source/sources.html).
Make sure to grab the `fpcbuild-X.Y.Z` archive, **not** `fpc-source`.


## Building the container image

Assuming you've downloaded both the Android NDK and FPC sources
and placed them in the same directory as the `Containerfile`,
all that's left to do now is:
```
$ buildah bud -t fpc-android ./
```
Or, if you're using Docker:
```
$ docker build -t fpc-android ./
```

The build process can be rather lengthy,
as it builds the Free Pascal Compiler four times over:

1. First, it builds an `x86_64-linux` compiler.
This is used to ensure that you'll be using the downloaded version,
with any patches bundled within this repository applied,
and not the version found in the Ubuntu repository (which may be older).

2. Second, a cross-compiler for `aarch64-android` (64-bit ARM) is built.
This step also compiles all the
[Run-Time Library](https://www.freepascal.org/docs-html/current/rtl/index.html)
and [Free Component Library](https://www.freepascal.org/docs-html/current/fcl/index.html)
units redistributed along with the compiler.

3. Third, a compiler for `arm-android` (32-bit ARM) is built.

4. Fourth, a compiler for `x86_64-android` is built. The x86_64 Android target
is mostly useful for debugging your apps in the Android Simulator.


## Licensing

The contents of this repository are subject to the zlib licence.
For the full text of the licence, consult the `LICENCE` file.
