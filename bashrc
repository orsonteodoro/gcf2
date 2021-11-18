# Copy the following inside /etc/portage/bashrc:

_gcf_translate_to_gcc_retpoline() {
	einfo
	einfo "Auto translating retpoline for gcc"
	einfo
	export CFLAGS=$(echo "${CFLAGS}" | sed -e "s|-mretpoline|-mindirect-branch=thunk -mindirect-branch-register|g")
	export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -e "s|-mretpoline|-mindirect-branch=thunk -mindirect-branch-register|g")
	export LDFLAGS=$(echo "${LDFLAGS}" | sed -e "s|-mretpoline|-mindirect-branch=thunk -mindirect-branch-register|g")
}

_gcf_translate_to_clang_retpoline() {
	einfo
	einfo "Auto translating retpoline for clang"
	einfo
	export CFLAGS=$(echo "${CFLAGS}" | sed -e "s|-mindirect-branch=thunk|-mretpoline|g" -e "s|-mindirect-branch-register||g")
	export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -e "s|-mindirect-branch=thunk|-mretpoline|g" -e "s|-mindirect-branch-register||g")
	export LDFLAGS=$(echo "${LDFLAGS}" | sed -e "s|-mindirect-branch=thunk|-mretpoline|g" -e "s|-mindirect-branch-register||g")
}

gcf_retpoline_translate() {
	if [[ -n "${USE_CLANG}" && "${USE_CLANG}" == "1" ]] ; then
		# explicit
		_gcf_translate_to_clang_retpoline
	elif [[ -n "${USE_GCC}" && "${USE_GCC}" == "1" ]] ; then
		# explicit
		_gcf_translate_to_gcc_retpoline
	elif [[ "${CC}" =~ "clang" || "${CXX}" =~ "clang++" ]] \
		&& [[ "${CFLAGS}" =~ "-mindirect-branch=thunk" \
			|| "${CXXFLAGS}" =~ "-mindirect-branch=thunk" ]] ; then
		# implicit
		_gcf_translate_to_clang_retpoline
	elif [[ "${CC}" =~ "gcc" || "${CXX}" =~ "g++" ]] \
		&& [[ "${CFLAGS}" =~ "-mretpoline" \
			|| "${CXXFLAGS}" =~ "-mretpoline" ]] ; then
		# implicit
		_gcf_translate_to_gcc_retpoline
	fi
}

gcf_strip_no_plt() {
	if [[ -n "${DISABLE_FNO_PLT}" && "${DISABLE_FNO_PLT}" == "1" ]] ; then
		einfo
		einfo "Removing -fno-plt from ${C,CXX,LD}FLAGS"
		einfo
		export CFLAGS=$(echo "${CFLAGS}" | sed -e "s|-fno-plt||g")
		export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -e "s|-fno-plt||g")
		export LDFLAGS=$(echo "${LDFLAGS}" | sed -e "s|-fno-plt||g")
	fi
}

gcf_strip_gcc_flags() {
	local gcc_flags=(
		-fopt-info-vec
		-fopt-info-inline
		-frename-registers
	)

	if [[ -n "${DISABLE_GCC_FLAGS}" && "${DISABLE_GCC_FLAGS}" == "1" ]] ; then
		einfo
		einfo "Removing ${gcc_flags[@]} from ${C,CXX,LD}FLAGS"
		einfo
		for f in ${gcc_flags[@]} ; do
			export CFLAGS=$(echo "${CFLAGS}" | sed -e "s|${f}||g")
			export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -e "s|${f}||g")
			export LDFLAGS=$(echo "${LDFLAGS}" | sed -e "s|${f}||g")
		done
	fi
}

gcf_strip_z_retpolineplt() {
	if [[ -n "${DISABLE_Z_RETPOLINEPLT}" && "${DISABLE_Z_RETPOLINEPLT}" == "1" ]] ; then
		einfo
		einfo "Removing -Wl,-z,retpolineplt from LDFLAGS"
		einfo
		export LDFLAGS=$(echo "${LDFLAGS}" | sed -e "s|-Wl,-z,retpolineplt||g")
	fi
}

# Auto scales MAKEOPTS based on RAM size or by a
# ${CATEGORY}/${PN} makeopts-xxx-MiB-per-process.conf row in package.env or
# per-package TOTAL_MEMORY_PER_PROCESS_MIB to scale based on the observed
# ceil_worst_case(rss+swap) usage per core from ps/top.
gcf_scale_makeopts() {
	# Set PHYSICAL_MEMORY_PER_GIB or PHYSICAL_MEMORY_PER_MIB in make.conf.
	local physical_memory_per_mib=0
	if [[ -n "${PHYSICAL_MEMORY_PER_GIB}" ]] ; then
		physical_memory_per_mib=$(( ${PHYSICAL_MEMORY_PER_GIB} * 1024 ))
	elif [[ -n "${PHYSICAL_MEMORY_PER_MIB}" ]] ; then
		physical_memory_per_mib=${PHYSICAL_MEMORY_PER_MIB}
	fi

	# This is the observable ceil(ram + swap) of running processes [%cpu] during linking.
	local total_memory_per_process_mib=${TOTAL_MEMORY_PER_PROCESS_MIB:=1024} # 1 GiB or override value

	# Add one of the following templates in package.env to a ${CATEGORY}/${PN} row:
	# makeopts-xxx-GiB-per-process.conf
	# makeopts-xxx-MiB-per-process.conf
	# or your package.conf manually setting TOTAL_MEMORY_PER_PROCESS_MIB

	# Reasons for -1 thread is to minimize trashing and as a safety
	# buffer from statistical outliers.

	local physical_memory_bytes=$(( ${physical_memory_per_mib} * 1024 ))
	local process_bytes=$(( ${total_memory_per_process_mib} * 1024 ))

	# More memory be reserved per package or based on cores.
	# The more cores the more reserved GiB may be required if more C/C++ instances overflow over 1 GiB.
	# So maybe RESERVED_GIB_OVERRIDE = ncores / 4.
	local reserved_gib=${RESERVED_GIB_OVERRIDE:=1}

	nthreads=$(python -c "import math;print(math.ceil(${physical_memory_bytes}/${process_bytes} - ${reserved_gib}))")
	if (( ${nthreads} <= 0 )) ; then
		nthreads=1
	fi

	if (( ${physical_memory_per_mib} == 0 )) ; then
		ewarn
		ewarn "Set PHYSICAL_MEMORY_PER_GIB or PHYSICAL_MEMORY_PER_MIB in make.conf to"
		ewarn "enable the MAKEOPTS autoscaler."
		ewarn
	elif [[ -n "${DISABLE_SCALE_MAKEOPTS}" && "${DISABLE_SCALE_MAKEOPTS}" == "1" ]] ; then
		:;
	else
		einfo
		einfo "Auto adjusted with MAKEOPTS=-j${nthreads} assuming ${total_memory_per_process_mib} MiB per process"
		einfo
		export MAKEOPTS="-j${nthreads}"
		export MAKEFLAGS="-j${nthreads}"
	fi
}

gcf_lto() {
	_gcf_strip_lto_flags() {
		export CFLAGS=$(echo "${CFLAGS}" | sed -r -e 's/-flto( |$)//g' -e "s/-flto=[0-9]+//g" -e "s/-flto=(auto|jobserver|thin|full)//g" -e "s/-fuse-ld=(lld|bfd)//g")
		export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -r -e 's/-flto( |$)//g' -e "s/-flto=[0-9]+//g" -e "s/-flto=(auto|jobserver|thin|full)//g" -e "s/-fuse-ld=(lld|bfd)//g")
		export FCFLAGS=$(echo "${FCFLAGS}" | sed -r -e 's/-flto( |$)//g' -e "s/-flto=[0-9]+//g" -e "s/-flto=(auto|jobserver|thin|full)//g" -e "s/-fuse-ld=(lld|bfd)//g")
		export FFLAGS=$(echo "${FFLAGS}" | sed -r -e 's/-flto( |$)//g' -e "s/-flto=[0-9]+//g" -e "s/-flto=(auto|jobserver|thin|full)//g" -e "s/-fuse-ld=(lld|bfd)//g")
		export LDFLAGS=$(echo "${LDFLAGS}" | sed -r -e 's/-flto( |$)//g' -e "s/-flto=[0-9]+//g" -e "s/-flto=(auto|jobserver|thin|full)//g" -e "s/-fuse-ld=(lld|bfd)//g")
	}

	if [[ "${CC}" =~ "clang" || "${CXX}" =~ "clang++" ]] \
		|| [[ -n "${USE_CLANG}" && "${USE_CLANG}" == "1" ]] ; then
		einfo
		einfo "Auto switching to ThinLTO"
		einfo
		_gcf_strip_lto_flags
		export CFLAGS=$(echo "${CFLAGS} -flto=thin")
		export CXXFLAGS=$(echo "${CXXFLAGS} -flto=thin")
		export FCFLAGS=$(echo "${FCFLAGS} -flto=thin")
		export FFLAGS=$(echo "${FFLAGS} -flto=thin")
		export LDFLAGS=$(echo "${LDFLAGS} -fuse-ld=lld -flto=thin")
	fi

	if [[ -n "${DISABLE_LTO_STRIPPING}" && "${DISABLE_LTO_STRIPPING}" == "1" ]] ; then
		:;
	elif [[ -n "${DISABLE_LTO}" && "${DISABLE_LTO}" == "1" ]] ; then
		einfo
		einfo "Forced removal of -flto from {C,CXX,LD}FLAGS"
		einfo
		_gcf_strip_lto_flags
	elif has lto ${IUSE_EFFECTIVE} ; then
		# Prioritize the lto USE flag over make.conf/package.env.
		# Some build systems are designed to ignore *FLAGS provided by make.conf/package.env.
		einfo
		einfo "Removing -flto from {C,CXX,LD}FLAGS.  Using the USE flag setting instead."
		einfo
		_gcf_strip_lto_flags
	fi
	export CFLAGS
	export CXXFLAGS
	export FCFLAGS
	export FFLAGS
	export LDFLAGS
}

pre_pkg_setup()
{
	einfo
	einfo "Running pre_pkg_setup()"
	einfo
	gcf_lto
}

pre_src_configure()
{
	einfo
	einfo "Running pre_src_configure()"
	einfo
	gcf_retpoline_translate
	gcf_strip_no_plt
	gcf_strip_gcc_flags
	gcf_strip_z_retpolineplt
	gcf_scale_makeopts
}
