# Gaming profile

## Summary

The gaming profile is designed for a basic gaming system.

## Requirements

* No visual or auditory studdering
* &gt;= 25 FPS for video playback with no noticible slow down
* &gt;= 30 FPS for old school games with lowest settings with no noticible FPS
  lag or annoying glitches that that will produce unfair play.
* &gt;= 57 FPS for high motion gaming with newer games.
* The fast install is a necessary requirement to maximize play time over build
  time, but at the same time the gameplay should not be unfair.
* Mold linker for heavy packages like web browsers
* Stable profile, stable keywords, stable release branches are preferred

## Tradeoffs / performance

* Modest runtime performance (or perceived B+ grade) is top priority
* Security is optional but deferred to the oiledmachine-overlay for eclasses and
  hardened ebuilds on the security perimeter
* Decent install time
* Stable
* High uptime for hardcore mode or grinding competition
* ~90% runtime performance systemwide without hardening
* No LTO
* No bashrc time cost
* Multitasking during build is smooth
* GCC first policy

## Details

* {C,CXX}FLAGS = -O2 pipe (implied -march=generic)
* -Oflag bumps based on unacceptable runtime duration, studder, or under FPS
minimums.
* The PGO USE flag is disabled by default, but enabled for select small
packages (&lt; 2 MLOC) with severe long run (3+ min) performance
* Curated lists
* No premature optimization
* Reactive optimization
* Development is active at this time
* Use of the mold linker for codebases that are &ge; 20 MLOC or &ge; 1 hr link
  time. (WIP)
* For competitive gaming, hardening is not recommended, but it is manageable in
  several ways.  Possibilities:

  - Two partitions and two kernels - 1 partition for gaming without userland
    hardening and without kernel hardening, 1 partition for general use with
    userland hardening and with kernel hardening.  This is uncommon.

  - Unhardened whole drive for gaming, hardened USB stick or separate drive
    for general use and paying bills.  This is uncommon, but helps isolation,
    but doesn't secure if firmware has vulnerabilities or is compromised.

  - Unhardened desktop for gaming.  A separate device like a smartphone to pay bills or shopping.

  - Unhardened mostly everything.  This was a common practice in 1990s to 2000s decade.

  - Selective per-project hardening.  This was a common practice in 2010s decade.

  - Harden everything on by default.  This is the distro default today (2020s) and
    common practice in rolling distros, but it then as we discuss later
    eliminates competitive play performance possibility.  It also creates a
    false sense of security or a fake facade of comprehensive security because
    there are security holes that are left open because the performance of the
    fix is unacceptable, insecure design flaws in silicon, vendors are
    unwilling to fix vulnerabilities because of greed or technical limitations,
    because of Godel's Incompleteness Theorem implications/metaphors, 
    misconfiguration, and many more.

  - Harden the whole disk and keep 2-3 kernels but limit the worst case
    penalty based on needs.

    | Kernel flavor   | Criticality          | Use case examples                                                                 |
    | ---             | ---                  | ---                                                                               |
    | Gaming [1]      | Performance-critical | Esports/competitive gaming, live streamer, music production                       |
    | Builder         | Balanced             | System upgrade, social media, casual messaging                                    |
    | Hardened        | Security-critical    | Online banking, jury duty affidavit, legal documents, shopping, secure messaging  |

    [1] While this profile focuses on gaming, it can be recontexutalized or
        modded for other performance sensitive scenarios like for example
        HFT (High Frequency Trading).

  - For example, one may set hardening at -10%
    with oiledmachine-overlay and set CFLAGS_HARDENED_TOLERANCE_USER="1.10" in
    /etc/portage/make.conf.  The tolerance manages and limits the worst case
    performance penalty for hardening.

    In layman's terms this means the following:

    - 0.97 - is equivalent to -Ofast or -O3 + -march=native.
    - 1.00 - is equivalent to -O3 baseline performance.
    - 1.09 - is equivalent to -O2 worst case.
    - 1.25 - is equivalent to -Os worst case.
    - 1.32 - is equivalent to -O1 worst case.
    - 1.55 - is equivalent to -O0 best case.
    - 1.95 - is equivalent to -O0 worst case.
    - 0.90 - 1.10 is A grade performance.
    - 1.11 - 1.20 is B grade performance.
    - 1.21 - 1.30 is C grade performance.
    - 1.31 - 1.40 is D grade performance.
    - 1.41 - infinity is F grade performance.

    What this means is that if the task is 24 hours unhardened at -O3, the task
    will take 48 hours if the performance impact is 2.00.

    - 1.10 keeps SSP on, _FORITIFY_SOURCE (a poor man's ASan) on, Retpoline off.
    - 1.35 keeps SSP on, _FORITIFY_SOURCE on, Retpoline on and is the overlay
      default.  Prioritizes confidentiality protection and neutralization of a
      vulnerability over the performance benefit.
    - For performance-critical competitive gaming, you can set

      ```
      CFLAGS_HARDENED_DISABLED=1
      RUSTFLAGS_HARDENED_DISABLED=1
      ```

      to disable userland hardening, or set

      ```
      CFLAGS_HARDENED_TOLERANCE_USER="1.09"
      RUSTFLAGS_HARDENED_TOLERANCE_USER="1.09"
      ```

      to limit dropping frames and to avoid affecting gameplay outcome
      possibility.  You can also apply it per-package with per-package
      env files (aka .conf files).  The hardened eclasses has the details of
      which hardening flags are activiated based on the tolerance level.

  - Pairing consistency

    In computer performance, the slowest component is the bottleneck and the
    reason why the performance system is slow.  The bottleneck interaction
    should be avoided or the component replaced/removed in performance-critical
    configs.

    In computer security, consistency is sometimes sacrificed for stability and
    progress.

    | Kernel flavor [8]  | Recommended CFLAGS_HARDENED_TOLERANCE_USER [3][9] | Userland hardening production readiness | Kernel hardening production readiness |
    | ---                | ---                                               | ---                                     | ---                                   |
    | Gaming             | 1.00 for competitive gaming [2]                   | Yes but preferred off                   | Yes but preferred off                 |
    | Gaming             | 1.09 for casual gaming [4]                        | Yes but cap it at 10% [4]               | Yes but cap it at 10% [4]             |
    | Builder [5]        | 1.35 [5]                                          | Yes but cap it at 40% [5][6]            | Yes but cap it at 40% [5][6][7][12]   |
    | Hardened           | 1.35 (actual) / 4.00 (ideal) [1]                  | Yes (actual) / No (ideal) [10]          | Yes [11]                              |

    [1] UBsan gets activated at 2.00.  ASan gets activated at 4.00, but ebuilds
        still need integration testing for systemwide sanitizing.  It is not
        ready yet at 2.00 or 4.00.  Integration testing is used to determine if
        two or more packages do not break when combined.  There is a high chance
        that integration testing fails with a sanitized build.  Any attempt to
        force merge a failed integration test package with sanitizers can result
        in breaking of compiler toolchains, irreversal damage or broken undoing
        because of broken @system, hidden runtime failures, broken login.   It
        is recommended to leave it at 1.35 at this time because of the high
        likelihood of runtime failure.  The 4.00 tolerance represents the
        idealistic value but currently not easily attainable.   Instead of
        applying it systemwide, it is preferred to apply it per-package and
        importantly have and prepare plan B and plan C backup plans to undo the
        damage, then do manual integration testing.  If no integration testing
        in the test suite, testing has to be performed on the live system.  The
        sanitized package should pass both unit testing and integration testing
        before adding the next sanitized package to minimize the distance of
        hidden runtime failure backtracking and to reduce the amount/time of
        guessing.  There is also the possiblity that the person that wrote the
        integrated test did not do a thorough job, and it still fails on the
        live system.  The quality standards or user experience should have no
        problems on the live system.  If the problem caused by sanitizers is
        not a problem for the needed package set but is a problem with the
        unused package set, the sanitizer should still be disabled.  The
        problem can manifest in an overlooked or unrevisited use case.

    [2] It is recommended to set CFLAGS_HARDENED_DISABLED=1 and
        RUSTFLAGS_HARDENED_DISABLED=1 instead.

    [3] The values that do not trigger sanitizers enablement is recommended
        systemwide.  The 2.00 or above values should only be applied on a
        per-package basis.


    [4] Cap the worst case penalty at 10% for resilient performance and gameplay.
        Keep the best case B grade and worst case C grade.  If 20%, then the
        best case is C grade and worst case is D grade.  Avoid F grade best case
        and F grade worst case.  Avoid D grade best case and F grade worst case.

    [5] Under real world testing the builder row has acceptable performance for
        some web games.  Some web games have unstable FPS at 24 FPS and above.
        Other games are smooth at near 30 FPS.  Testing done at 1.35 tolerance,
        UBSAN, KFENCE, KCFI, Retpoline.  You can set CET with
        CFLAGS_HARDENED_CF_PROTECTION_USER=1 systemwide or per-package.  CET
        is default off in the oiledmachine-overlay.  Variables are marked
        @USER_VARIABLE in the
        [cflags-hardened.eclass](https://github.com/orsonteodoro/oiledmachine-overlay/blob/master/eclass/cflags-hardened.eclass) or
        [rustflags-hardened.eclass](https://github.com/orsonteodoro/oiledmachine-overlay/blob/master/eclass/rustflags-hardened.eclass)
        which allow users to control microarchitecture specific hardening.

    [6] The builder profile was designed to increase throughput.  The 40%
        maximum allows us to have non detrimental throughput.

    [7] In some kernel options, low latency is mutually exclusive with
        throughput.  Hardening also increases overhead and increases
        completion time.

    [8] The kernel flavor is set with the EXTRAVERSION variable in
        /usr/src/linux/Makefile and a different kernel sources folder
        name per release to isolate patching.  The hardened kernel
        flavor has patching restriction on custom patches because of
        auditors, patch/developer trust.  The gaming has patching
        restrictions on patches that decrease performance or decrease
        availability.  The ot-kernel makes it easy to have and build
        different kernel flavors per release.  For other kernel
        source ebuilds, you need to copy and paste the folder source,
        change the flavor suffix and EXTRAVERSION, and build each
        kernel manually or build each through custom scripting.

    [9] In the
        [cflags-hardened.eclass](https://github.com/orsonteodoro/oiledmachine-overlay/blob/master/eclass/cflags-hardened.eclass) or
        [rustflags-hardened.eclass](https://github.com/orsonteodoro/oiledmachine-overlay/blob/master/eclass/rustflags-hardened.eclass)
        under the comments of tolerance section, you will see a list of hardened
        flags.  The second right column of numbers has the worst case performance
        impact.  If the CFLAGS_HARDENED_TOLERANCE_USER is set to >= of that
        number then that particular hardening flag gets applied.  For some
        hardening flags that introduce instability or have unknown availability
        quality, you need to whitelist the flag.  For example, one may apply
        CFLAGS_HARDENED_AUTO_SANITIZE_USER="asan ubsan" sparingly on a per-package
        basis.  The @USER_VARIABLE has some flags that are considered whitelist
        flags.

    [10] The recommended ideal level is architecture dependent.
      * arm64 - 2.00 - UBSan, HWASan, PAC+BTI
      * amd64 - 4.00 - UBSan, ASan, either CFI or CET
      * others - 4.00 - UBSan, ASan
      * Assumes sanitizers do fatal error on violation
      * Requires explicitly silent sanitizer logging to mitigate critical vulnerability

    [11] The recommended ideal level is architecture dependent.
      * arm64 - 2.00 - UBSAN, HW_TAGS KASAN, PTR_AUTH, BTI
      * amd64 - 4.00 - UBSAN, Generic KASAN, either KCFI or CET
      * others - 4.00 - UBSAN and Generic KASAN
      * Assumes explicit add of panic_on_warn=1 or equivalent custom sanitizers panic only patch

    [12] KFENCE is recommended as mitigation against zero-click UAF.  In real
         world testing, using 2.00 has acceptable performance with KFENCE,
         UBSAN, KCFI.

  - General kernel configuration policy

    - Gaming kernel config:  SSP on, _FORTIFY_SOURCE on, KFENCE off,
      UBSan off, KCFI off, swap off, CPU frequency set to performance, 1000 HZ, power
      management off.

    - General use kernel and builder kernel with full hardening config:  SSP on,
      _FORTIFY_SOURCE on, KFENCE on, UBSan on, KCFI on, swap on, CPU frequency set
      to schedutil or ondemand, 250 HZ for throughput in builder kernel.

    - For both types of kernel, security defaults should be mostly default because
      too much hardening overheats or touches untested buggy code.  Too little
      hardening can run into untested buggy code.  Settings closer to defaults
      are preferred for stability and uptime since the heavy lifting for testing
      has already been done.

    - For the gaming kernel, disruptive options like power management or
      allow for studder like swap should be disabled.  Options that degrade
      availability should be disabled or changed to the higher availability
      alternative.

    - If just casual gaming, then full hardening is acceptable so only one
      partition and one kernel.

    - For the hardened kernel, options that improve CIA - Confidentiality,
      Integrity, Availability - should all be increased or enabled.

    - Sometimes the choice between integrity improvement and availability
      improvement is mutually exclusive.

    - We prioritize availability over integrity for gaming kernels.

    - We prioritize integrity over availability for hardened kernels.

    - We change or disable performance options that hurt uptime and hurt
      availability which can cause premature permadeath in the gaming
      kernel.

    - If competitive gaming, availability comes first but performance-critical
      preferences are prioritized second.  For grinding, live tournament play,
      or live game streaming, we want to focus on actual gaming rather than
      wasting time fixing and finding the cause of availability loss.  A
      properly run live game stream has no technical difficulties, lag, or
      crashes caused by our flag selections.

    - For competitive gaming, hardening is not acceptable because of the -30%
      performance drop with Retpoline and the kernel has UBSan (~3x worst case
      performance) and KFENCE (~1.08x performance penalty) are enabled by
      default.  It will studder gameplay or cause the computer to reset on
      false positive on hardcore mode during aggro.

    - For the hardened kernel runtime memory corruption detection, the user
      must pick a choice in order to neutralize unseen or overlooked critical
      severity vulnerabilities.  Virtually all proper hardened kernels will
      enable a flavor of ASan.  The trade-off is speed versus comprehensive
      check or comprehensive security.  The distro kernel will enable KFENCE but
      it should be disabled for competitive gaming to avoid a false positive
      unintended consequence scenario that leads to premature permadeath.  For
      casual gaming, KFENCE has acceptable performance tolerance.  For
      competitive gaming, the performance is unacceptable because both the use
      of -O2 (10% penalty) and the hardening may stack or be additive so maybe
      nearly 20% performance impact penalty combined if using the 10 ms hardened
      KFENCE.   We start out with the 90% performance as the new baseline then
      drop it down again 8% in a near best case scenario though.  If the scene
      is content heavy in a worst case scenario, the performance impact can
      increase chances of loss.  KFENCE is like the analog of a sheep skin
      condom.  Generic KASAN is like the analog of a latex condom.

    - For trusted code integrity on both kernels, KCFI may have a 1.08x worst
      case performance penalty which may go over the 1 FPS drop for 60 FPS
      systems.  For 30 FPS systems, 2 FPS drop. For 60 FPS systems, 5 FPS drop.
      For 180 FPS systems, 10 FPS drop.  It is acceptable for casual gaming but
      not for hardcore mode and competitive gaming.  The KCFI may contribute to
      the possibility of premature permadeath.

Memory corruption vulnerabilities and their estimated CVSS severity range

| Vulnerability            | Typical severity | Typically announced in security advisories |
| ---                      | ---              | ---                                        |
| Use After Free (UAF) [1] | High - Critical  | Yes                                        |
| Double Free (DF) [1]     | High             | Yes                                        |
| Out Of Bounds (OOB) [1]  | Medium - High    | Yes                                        |
| Use After Return (UAR)   | High             | Rarely                                     |
| Use After Scope (UAS)    | Medium - High    | No                                         |
| Heap Overflow (HO) [1]   | High - Critical  | Yes                                        |
| Stack Overflow (SO)      | High             | Yes                                        |

For all the rows above, if unmitigated can lead to Remote Code Execution (RCE) and/or
Privilege Escalation (PE).

[1] Can be exploited in a zero-click attack.

ASan and look-alike estimates

| Flavor                 | Security score [5] | Performance score [6] | Performance impact [9] | Coverage [10]             | UAF [1][11] | DF [1][11]  | OOB [1][11]  | UAR [1] | UAS [1] | HO [1][11] | SO [1] |
| ---                    | ---                | ---                   | ---                    | ---                       | ---         | ---         | ---          | ---     | ---     | ---        | ---    |
| _FORTIFY_SOURCE=2 [2]  | 7.5                | 9.8                   | 1.02 / 1.05            | Full                      | N           | N           | Y            | N       | N       | P [3]      | P [3]  |
| _FORTIFY_SOURCE=3 [2]  | 8.0                | 9.4                   | 1.04 / 1.08            | Full                      | N           | N           | Y            | N       | N       | P [3]      | P [3]  |
| KFENCE (100 ms) [7][8] | 6.5                | 9.9                   | 1.0003 / 1.01          | Partial, approx 1 in 1000 | Y           | Y           | Y            | N       | N       | Y          | Y      |
| KFENCE (10 ms) [7]     | 8.0                | 9.4                   | 1.04 / 1.08            | Partial, approx 1 in 100  | Y           | Y           | Y            | N       | N       | Y          | Y      |
| KFENCE (1 ms) [7]      | 8.5                | 8.8                   | 1.12 / 1.25            | Partial, approx 1 in 10   | Y           | Y           | Y            | N       | N       | Y          | Y      |
| Generic KASAN          | 9.2                | 4.0                   | 1.75 / 2.50            | Full                      | Y           | Y           | Y            | N       | N       | Y          | Y      |
| HW_TAGS KASAN          | 9.5                | 8.0                   | 1.15 / 1.30            | Full                      | Y           | Y           | Y            | N       | N       | Y          | Y      |
| SW_TAGS KASAN          | 9.0                | 6.0                   | 1.40 / 1.60            | Full                      | Y           | Y           | Y            | N       | N       | Y          | Y      |
| ASan [4]               | 9.8                | 3.5                   | 2.00 / 3.00            | Full                      | Y           | Y           | Y            | Y       | Y       | Y          | Y      |
| HWSan [4]              | 9.7                | 8.5                   | 1.20 / 1.40            | Full                      | Y           | Y           | Y            | Y       | Y       | Y          | Y      |
| None                   | 0.0                | 10.0                  | 1.00 / 1.00            | None                      | N           | N           | N            | N       | N       | N          | N      |

* [1] Implies mitigation
* [2] Only available for user space libs/programs built with glibc
* [3] Fortified (mem*, str*) function only
* [4] Userspace flavor only
* [5] Higher score means more secure
* [6] Higher score means faster system or faster completion
* [7] It is recommended to use KFENCE for the builder kernel or general use, and
      Generic KASAN or HW_TAGS KASAN for hardened or short lived
      critical-security scenarios.  You can also change the sampling rate to be
      more agressive with KFENCE with `kfence_sample_interval=10` added to the
      bootloader or built into the kernel command line (CONFIG_CMDLINE) instead
      of using KASAN.  The 10 ms and 1 ms are considered hardened versions but
      not secure-criticial.  90% is considered security-critical.
      For comparison, a condom has 87% typical use and 98% perfect use.  This
      is relevant to coverage.  The AI says that KFENCE does not meet
      security-critical coverage for any kfence_sample_interval.  KFENCE is
      recommended for balanced security but not critical security.
* [8] Kernel default.  It may be tolerable for scenarios where the loss is
      not catastrophic.
* [9] Typical / worst case
* [10] The amount of allocations and deallocations checked
* [11] Even with sanitizers enabled, there is a chance to completely or partially
       bypass mitigation.  Mitigation implies imperfect security.

Serious severities caught by UBSan before being exploited

| Vulnerability                                    | Estimated severity range  | Typically announced in security advisories |
| ---                                              | ---                       | ---                                        |
| (Signed) Integer Overflow (SIO, IO) [1]          | High - Critical           | Yes                                        |
| Shift Out Of Bounds (SOOB) [1]                   | High - Critical           | Yes                                        |
| Null Pointer Dereference (NPD)                   | Medium - High             | Yes                                        |
| (Array) Index Out Of Bounds (AIOOB, IOOB) [1][3] | High                      | Yes                                        |
| Bool Overflow / Conversion [2]                   | High                      | No                                         |
| Enum Value Overflow                              | High                      | No                                         |
| Misaligned Access                                | Medium - High             | No                                         |
| Variable Length Array (VLA) Bound Overflow [1]   | High                      | No                                         |

A zero-click attack is possible with all rows above.

* [1] Remote Code Execution (RCE) possible
* [2] Privilege Escalation possible
* [3] There are two versions -- the more secure UBSAN_BOUNDS for local, global,
      dynamic scope and the performant UBSAN_LOCAL_BOUNDS for local scope.  Both
      only provide partial AIOOB coverage in the kernel.  For full AIOOB
      coverage you need to use it with KASAN.  For unknown size pointer
      indexing, it is considered part of AIOOB.  KASAN and ASan can catch it but
      KFENCE cannot catch it.

Typically hardened kernels do not enable UBSan, but it is recommended to block
the some of the top 25 or top 50 classes of vulnerabilities.  Even the
distro's kernel doesn't enable UBSan.

If using a custom kernel, for the sanitizers to act like club
bouncers and not chihuahuas, the `panic_on_warn=1` must be set in the
bootloader or CONFIG_CMDLINE to make the warnings fatal errors or the
kernel modded in the way that sanitizers make them fatal.

## Performance consistency and the mutual exclusitivity of security and performance

We want a safety buffer or winning guarantees.  The hardening just reduces it.
Hypothetically speaking, a 30 FPS game has heavy content or high poly count
scene that reduces to 25 FPS (or motion picture movie FPS).  KFENCE has a worst
case performance at 8%.  SSP has possibly 20% worst case.  Stack clash at 10%
worst case.  The goal is to have deterministic/reproducible performance by
eliminating or reducing the worst case boundary.  The approximation is closer
to additive when stacked.  If KFENCE or even SSP proc'ed, it would dip to less
than movie FPS, it can affect outcome with 3 FPS reduction or annoy/distract
others who notice that something is off or not right.  Licensed car drivers
know that distracted driving can lead to crashes as in bad user performance.  If
KFENCE were disabled, then there would be no unintended consequences from any
KFENCE proc's.  It would be in a safe condition.  25 FPS is 83% or grade B
performance.  22 FPS is 73% or grade C performance.  The safe zone for
competitive A grade consistency is B grade performance.  The safe zone for
casual B grade consistency is grade C grade performance.  The safe zone allows
for resilient results for the player to bounce back from B grade back to A
grade performance.  If the casual performance baseline were downgraded to D
performance, the corresponding safe zone would be F.  In both instances D and
F performance, it is not a passing grade for casual gameplay performance.  To
increase the safety buffer, one may also consider enabling the vanilla USE
flag or disabling default hardening patches in the gcc ebuild for use in the
gaming partition, but it comes with the trade-off of double build time for
both the performant and secure partitions and lowered security in the
performant partition.

 There are cases were the security and performance are mutually exclusive:

 - Using -O0 will cut build times by half but disable _FORTIFY_SOURCE mitigation.
   _FORTIFY_SOURCE acts like the inferior or demo version of ASan.
 - Using -O3 may optimize away or eliminate _FORTIFY_SOURCE checks lowering
   security.  It is recommended to just keep it at -O2 for security marked
   packages so that also availability is not reduced and that _FORTIFY_SOURCE
   integrity is not reduced significantly to unacceptable levels.
 - When using _FORTIFY_SOURCE, it is also recommended to apply an additional
   flag set `fortify-fix-<LEVEL>-<COMPILER>.conf` to disable optimizations that
   compromise _FORTIFY_SOURCE integrity if not using the oiledmachine-overlay
   for both security-critical packages and packages that handle untrusted data
   when _FORTIFY_SOURCE is default on or enabled explicitly.  The hardened
   compilers don't do this automatically and has to be done manually
   per-package with the .conf files or by the modified ebuilds in the
   oiledmachine-overlay.  The idea for these .conf files is to either maintain
   theoretical or practical coverage of _FORTIFY_SOURCE checks that -O3 and
   LTO undo.  Some projects had been observed already applying some of these
   flags, but not all project security teams are aware about it.  A simple
   example would be like a military base where there are checkpoints on the
   entry, at the store, at the armory.  Applying -O3 optimization or LTO would
   be like deleting the guards randomly or completely at the checkpoints, or
   placing the guard's post improperly at the bathroom while the armory is
   being looted.
 - Using -Ofast or -ffast-math may compromise the integrity of mathematical
   models with non-deterministic fmul or float optimizations.  Both -Ofast
   and -ffast-math should be disabled when real world losses are possible like
   use of finance mathematical models (spreadsheets, the JavaScript or PHP
   package(s) itself if it used as a finance calculator, POS systems, etc) or
   safety-critical packages.

## FPS tolerance for competitive play

* For 30 FPS, 1 FPS is 33.33 ms.  3 frames render chances within 0.1 seconds inclusive.  4 frames render chances within 0.15 seconds inclusive.
* For 60 FPS, 1 FPS is 16.66 ms.  6 frames render chances within 0.1 seconds inclusive.  9 frames render chances within 0.15 seconds inclusive.
* For 240 FPS, 1 FPS is 4.166ms.  24 frames render chances within 0.1 seconds inclusive.  36 frames render chances within 0.15 seconds inclusive.
* Formula:  t total ms = 1000 ms / x frames
* Human object recognition is 100 - 150 ms or 0.1 - 0.15 seconds.
* The recommended esports policy in this profile is too render
  at least 90% frames render chance or above, which translates to A grade
  average FPS, within 0.15 total seconds to prevent affecting gameplay
  outcome.  Simply put, the average FPS should not dip below 27 FPS in
  30 FPS games, 54 FPS in 60 FPS games, 216 FPS in 240 FPS games in
  high poly count or high content scenario in competitive play.  It is
  assumed that the object will appear visually long enough.
  Competitive is A grade consistency.  Casual is B to C grade
  consistency.
* 60 FPS is the mainstream gamer standard and assumed in this profile.
* 240 FPS is the esports standard.

## Performance bump policy and FPS tolerance for casual play

### Hypothetical / theorycraft

Take for example 30 FPS with the following penalties:

* 50% reduction is 15 FPS. (Unacceptable)
* 25% reduction is 22.5 FPS. (Unacceptable)
* 20% reduction is 24 FPS.  (Barely meets)
* 16.67% reduction is 25 FPS.  (Meets)
* 10% reduction is 27 FPS. (Meets 25 FPS like in the movies)

* A newer codec's age adds -10% penalty for newer while older will be 0%.
* If the lib/app is already optimized, add +10% benefit.

Take for example 60 FPS with the following penalties:

* 41.6% reduction is 24.9 FPS.  (Unacceptable at high motion.  Maybe acceptable for a high poly raid event but not in competition.)
* 50% reduction is 30 FPS. (Acceptable at high motion.  Acceptable if FPS counter hidden for old school gaming.)
* 25% reduction is 45 FPS. (Not acceptable if looking at FPS counter while looking at GL Aquarium.)
* 20% reduction is 48 FPS.  (Not acceptable if looking at FPS counter while looking at GL Aquarium.)
* 16.67% reduction is 50 FPS.  (Meets performance counter.  Tolerable.)
* 10% reduction is 54 FPS. (Meets performance counter.   Tolerable.)
* 5% reduction is 57 FPS. (Acceptable for a 60 FPS gamer if looking at FPS counter and when the FPS counter is off.)
* 0% reduction is 60 FPS. (High satisfaction for a 60 FPS gamer if looking at FPS counter.)

### Solution

The rational solution, -Oflag(s) that are no less than 16.67% performance penalty
is/are required to achieve 25 FPS or more, so find the -Oflag level(s) that
fits.  -O3 (Solution by ricers), -O2 (Solution by distro), -Os (best case or by
chance or trial or error).  The side-effect is increased build time.

The intuitive solution, performance bumps are done to get over the 50% drop, so
keep bumping the -Oflag (through divide and conquer) until it appears to be 25
FPS.  (Solution used by this repo).  One side-effect is random increased
runtime cost.  The quirk descriptions for performace degration are listed below.

* No apparent performance penalty stays:  -O0
* Observed visual studder bump:  -O1
* Observed visual studder encountered again bump:  -O2
* An easy trivial task not completed in 1 minute bump:  -O1
* An easy trivial task not completed in 1 minute encountered again bump:  -O2
* 1.5+ minute durations with no problems:  -Ofast
* 1.5+ minute durations with problems:  -O3

* Problems may manifest as visual artifacts, flicker, wrong behavior, missing
data.

* If the duration is still too long, a backtrack and evaluation of the
dependency tree is made and -Oflag bumps are made to packages that may relate to
the issue.  Once it is found, we restore the -Oflag to -O0 for irrelevant
packages.  If a package is known to be slow (or is the performance bottleneck),
backtracking will be cut short or end.

## Performance estimates

* -Ofast is +- 3% performance drop or benefit, +10% benefit for outliers ; A to A+ grade
* -O3 is 100% reference ; A grade
* -O2 is +1% benefit to -3% to -9% performance drop ; A grade
* -Os is -7% to -25% performance drop ; A to C grade
* -O1 is -17% to -32% performance drop ; B to D grade ; D grade for the newest codecs
* -Og is -19% to -26% ; B to C grade
* -O0 is -55% to -95% worst case performance drop, possibly +3x execution time ; F grade for crypto/codecs/security.  C to F grade for basic programs.
* -march=native is &lt; 2% drop to &lt;= 12% performance benefit
* -fomit-frame-pointer is a 4% to 85% benefit (default ON in -O1) or &lt; 1% drop
* -ffast-math is 10% benefit or possibly 40% processing time reduction (outlier), based on -Ofast stats.
* PGO is 10% performance benefit with 40% benefit outliers
* BOLT is 10-15% performance benefit
* LTO is -15% cost to +5% benefit for real world ; 41% performance benefit for outliers/synthetic ; +17% mode avg for space savings ; up to 5x the normal build times
* CFI is &lt;= 1% performance cost
* -O0 is preferred to reduce build times by 60-70%.
* lld link times can be up to ~2-5x longer than mold; gold link times can be up to ~22-24x longer than mold; bfd link times can be up to ~88-120x longer than mold.  All multithreaded.
* gold link times can be up to ~2x longer than lld with single thread linking.
* For hardening
  - Retpoline - 1.30x worst case performance 
  - ASan - 4.00x worst case performance
  - UBSan - 2.00x worst case performance

#### Section footnotes

1. -Oflags percents are measured relative to -O3.
2. Link times can be about the same between different linkers in some cases with short link times, but disparity increases with longer link times.
3. The other flags percents are relative to the same -Oflag.

## Footnotes

<a name="footnote-1">1.</a> The mold linker can only be used in non-commercial purposes.  See that project for details.
