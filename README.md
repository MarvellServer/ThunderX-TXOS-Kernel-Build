# ThunderX-TXOS-Kernel-Build

To build the kernel RPM you have to clone the git repository and use
the build script.

 $ git clone https://github.com/MarvellServer/ThunderX-TXOS-Kernel-Build.git

 $ cd ThunderX-TXOS-Kernel-Build

 $ do_build=yes ./build.sh

This will generate the build log and also kernel RPMS.

To regenerate the the kernel source, remove the .tar.xz source file.

To build a release use:

 $ do_release=txos20.05 ./build.sh

The release string should have the following format:

 txos2\\d.\\d\\d

Note that there are no dashes allowed. If there are changes on top of
the latest release, the $do_release string should contain the next
TXOS version to be released, e.g. use txos20.05 for a package update
if txos20.04 is the latest release.

Building a release requires the 'next' branch of ThunderX-TXOS repo to
be tagged. There must exist an annotated tag of the kernel version in
the format:

 txos-<base>-<patchlevel>

Use something like the following to create one, e.g.:

 $ git tag -a txos-5.4.42-3 -m 'TXOS 5.4.42-3' origin/next

Other environment variables:

cid:

Using the $cid environment variable sets the kernel's commit id to be
used for packaging, e.g.

 $ do_build=yes cid=HEAD ./build.sh

This uses the local HEAD of the repo in SOURCES/linux-txos.

txos_base, txos_patchlevel, txos_release:

This specifies the package version, otherwise git is used to extract
the version number based on tags. 'txos_release' can be used to
specify the TXOS release as used with do_release. If not specified the
previous release is used followed by a '+' sign. Example:

 $ do_build=yes txos_release=txos20.04 ./build.sh

NOTE: We assume that you have installed all the required dependency
packages to compile kernel and generate RPM.

Architecture     : AArch64

Operating System : CentOS 8
