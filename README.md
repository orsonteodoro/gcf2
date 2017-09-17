# gentoo-cflags

My per-package cflags for Gentoo Linux.

These cflags/cppflags are optimized for multi-core processor.  I used stable optimization flags, so I mostly rely on O2 and O3.

There are currently generally levels of optimizations (ranked most optimized to least):
* O3 - used for packages that process a lot of data.
* O2 - used for packages on default.  
* none - used for binary packages, code that doesn't need to be compiled, just scripts, or just content and data.

Reasons to use optimizations:
* O3 is used for 3D libraries and applications, packages that utilize cryptography, cpu bound applications and libraries, video/still-image/audio codecs, compression libraries, certain gaming servers.
* fast-math.conf is used for a few applications that use the CPU near full use more than 24/7.

Reasons to remove optimizations or not to use optimizations:
* Optimizations that causes memory leaks or runtime errors will be disabled.
* Suspected slow and not smooth performance.
* Newer optimizations will break because they are not feature complete or not debug enough.

Compiler used:
* gcc is the default compiler because it has more access to experimental optimizations.
* clang is forced if the package relies on it.

sync-package.env - This is used to discover missing packages in package.env.  You should chmod +x it.  It will list the packages that you don't have and then you add it manually to your package.env file.  It requires the eix package to use it.
make.conf - This contains the systemwide cflags used by default whenever there is no entry in the package.env.
sync-repository - keeps folders synced

----

Need more optimization?

For PGO see https://github.com/orsonteodoro/oiledmachine-overlay/tree/master/portage-bashrc/systemwide-pgo .  I currently do not use it, but I've used it for Firefox, Seti@Home, WebkitGTK+, BFGMiner.

PGO will optimize hot basic blocks and shrink cold basic blocks and push them out away from the hot code blocks.

----
References
* {1} https://gcc.gnu.org/projects/tree-ssa/vectorization.html
* {2} https://gcc.gnu.org/wiki/AutoParInGCC
* {3} https://gcc.gnu.org/wiki/Graphite/Parallelization
