# gentoo-cflags

My per-package cflags for Gentoo Linux.

These cflags/cppflags are optimized for 4-core processor.  You can change this number by editing -ftree-parallelize-loops=4 and -flto=5 to fit your own needs.

There are currently generally levels of optimizations (ranked most optimized to least):
* O3 - used for heavly optimized code or packages that process a lot of data.
* O2 - used for average case whenever the package relies on searching but not very CPU intensive.  
* Os - used for packages that are not important.
* none - used for binary packages, code that doesn't need to be compiled, or just scripts.

There are two classes of code:
* FPU code - used for packages that are suspected of using floating point units
Software that may use FPU code: audio codecs, lossy color image compression libraries, 3D libraries

* ALU code - code that relies on just logic but not much floating point unit
Lossless compression libraries, cryptography libraries

Reasons to apply specific optimizations:
* maximize-fpu and maximize-alu apply auto-vectorization whenever possible.  This takes advantage of the multicore processor.
* maximize-fpu-throughput-fm vs maximize-fpu-throughput-am - the fm variation uses fast-math but the am code uses associative math.  Not all packages can use fast math.  Fast math or associated math is required "to enable vectorization of floating point reductions."{1}
* minimize-random-access-latency.conf - is used for GUI widgets like viewports, packages with array data structure traversal.
* Wrapper packages get Os but the core library that it wraps around may get heavier optimizations.
* Frontend GUIs generally get Os.  Frontends GUIs will get O2 if there is a slow down in scrolling.
* Unpopular or infrequently used software get Os.
* Packages that are IO bound get Os.
* Most parser packages and non IO bounded searching get O2.
* IO bounded searching like databases gets Os.
* Programming languages will generally get O2.  Programming languages packages will get O3 when it carries its own crypto libraries.
* Build development tools generally get O2.
* CPU bounded code and FPS (Frames Per Second) bounded code will get O3.
* LTO is used to reduce code size.

Reasons to remove optimizations:
Optimizatoins that causes memory leaks or runtime errors will be disabled.

Compiler used:
* gcc is forced whenever O3 is present to take advantage of auto parallelization with graphite,{2}{3} and auto vectorization{1} which clang doesn't support.
* clang is used for Os.

sync-package.env - This is used to discover missing packages in package.env.  You should chmod +x it.  It will list the packages that you don't have and then you add it to your package.env file.

----
References
* {1} https://gcc.gnu.org/projects/tree-ssa/vectorization.html
* {2} https://gcc.gnu.org/wiki/AutoParInGCC
* {3} https://gcc.gnu.org/wiki/Graphite/Parallelization
