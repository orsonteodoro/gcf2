## Production status

The semi-production ready image may need to be modified a bit on your side due
to differences in package versions or hardware configuration.

### Development mode progress

Plans for June 2022 and beyond:  Currently this project repo is on freeze,
but will be continue as new project(s).  The plan is to keep this one
around for users still interested in CFI and systemwide LTO but new repo(s)
may be made based partly on the Aug 26, 2021 design with more simpler
package.env.

The new repo will continuation of Aug 26, 2021 design and will have a
new package.env will be more simple.  The project URL will be announced
later.  There will be more emphasis on build time (-O0) and sparing use of
-O{1,2,3} optimization compiler flags based on observed severe dips on
performance.  This new project may be named gcf-game-perf and be more gamer and
content creator centered as in again fast installs and performance required in
observed execution performance degration scenarios or heavy time cost scenarios.
There will be no LTO/CFI in this new project.  This new primary project will
de-emphasize premature optimization and so the package.env will be more
selective and dramatically small.

Another project may be spawned called gcf-infer.  This will use generator
scripts to generate a package.env based on ebuild contents.  This will be more
secondary since it is premature optimization.  The scripts will guess the
packages to optimize based on keyword search on DESCRIPTION and with *DEPENDs.
No LTO/CFI again this time.

This current repo state is more focused on both security and stable
performance flags.  It may be renamed gcf-adv.

Gist of pre June 2022:

LTO with CFI is mostly working and on par with a basic www setup.  Current
development is focused on systemwide CFI.  Performance degration with CFI is
indiscernible mostly maybe except for loading times and build times.  CFI
coverage is not complete which is why it is not recommended for use
from this repo.  With a disabled CFI @system, the benefits also diminish
by maybe 15% around 8% required CFI disabled due to noreserve bug so
around 23% unprotected for production safe configuration.

* CFIing @world excluding @system should be safe and easy to recover if
problematic.
* CFIing @system is not safe due to KEYWORD and slot issues that can break
the entire @system set with minor gcc updates.  It is not recommeded to CFI
@system.
* Souper flags support has been added, but currently disabled until it passes
unit testing.  It not recommended since upstream claims research grade
quality and the file sizes were more or less the same with much worst
compile time from my own initial testing.
