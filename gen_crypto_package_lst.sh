#!/bin/bash

DISTDIR=${DISTDIR:-"/var/cache/distfiles"}
CRYPTO_CHEAP_OPT_CFG=${CRYPTO_CHEAP_OPT_CFG:-"O1.conf"}
CRYPTO_EXPENSIVE_OPT_CFG=${CRYPTO_EXPENSIVE_OPT_CFG:-"O3.conf"}
CRYPTO_ASYM_OPT_CFG=${CRYPTO_ASYM_OPT_CFG:-"Ofast-ts.conf"} # Based on benchmarks, expensive
EXPENSIVE_ALGS=(
	25519
	"curve.*25519"
	"curve.*448"
	dh
	dsa
	elgamal
	"ec(dsa|dh)"
	sm2

	# Add your custom list here
	# Maybe you should add the name of the algorithm when keysize > native word size
	#   or
	# number of rounds is very large
	sha3
)

gen_pn() {
	local path="${1}"
	local pn
	pn=$(basename "${path}")
	pn="${pn,,}"
	pn=$(echo "${pn}" | sed -r -e "s/tzdata/timezone-data-/g")
	pn=$(echo "${pn}" | sed -r -e "s/tzcode/timezone-data-/g")
	pn=$(echo "${pn}" | sed -r -e "s/(\.|_|-)v?[0-9].*//g")
	pn=$(echo "${pn}" | sed -r -e "s/[0-9]+\.(tar.*|zip)//g")
	pn=$(echo "${pn}" | sed -r -e "s/-everywhere-opensource-src(-|)//g")
	pn=$(echo "${pn}" | sed -r -e "s/\./-/g")
	pn=$(echo "${pn}" | sed -r -e "s/bin_x86/bin/g")
	echo "${pn}"
}

has_single_dh() {
	local len=$(echo "${@}" | grep -o "," | wc -l)
	[[ -z "${len}" ]] && len=0
	(( "${len}" == 1 )) && return 0
	return 1
}

has_expensive_crypto() {
	local A=($(echo "${@}" | sed -e "s|,| |g"))
	local a
	local b
	for a in ${A[@]} ; do
		for b in ${EXPENSIVE_ALGS[@]} ; do
			[[ "${x}" =~ "${a}" ]] && return 0
		done
	done
	return 1
}

search() {
	local asym_algs=(
		25519
		"curve.*25519"
		"curve.*448"
		dh
		dsa
		"ec(dsa|dh|rdsa)"
		elgamal
	)
	local algs=(
		"(blow|two|three)fish"
		25519
		aes
		aegis
		anubis
		arc4
		argon2
		"blake(|2|2b|2s)"
		camellia
		"cast.*(5|6|128|256)"
		"chacha(|8|12|20)"
		"crypt(|o)"
		"curve.*25519"
		"curve.*448"
		des
		dh
		dsa
		"ec(dh|dsa|rdsa)"
		elgamal
		gf128
		gost
		keccak
		khazad
		"md(4|5)"
		poly1305
		rc6
		rijndael
		ripemd
		"rmd.*(128|160|256|320)"
		rsa
		"(|x)salsa(|20)"
#		seed
		"sha(1|2|3|256|512)"
		serpent
		"sm(2|3|4)"
		streebog
		"(x|)tea"
		whirlpool
		wp512
		xxhash
	)
	unset cryptlst
	unset asym_cryptlst
	declare -A cryptlst
	declare -A asym_cryptlst
	local algs_s=$(echo "${algs[@]}" | tr " " "|")
	local asym_algs_s=$(echo "${algs[@]}" | tr " " "|")
	local found=()
	local found_asym=()
	local x
	for x in $(find "${DISTDIR}" -maxdepth 1 -name "*tar.*" -o -name "*.zip") ; do
		local hc=$(echo "${x}" | sha1sum | cut -f 1 -d " ")
		local paths
		[[ "${x}" =~ "zip"$ ]] && paths=($(unzip -l "${x}" 2>/dev/null))
		[[ "${x}" =~ "tar" ]] && paths=($(tar -tf "${x}" 2>/dev/null))
		if echo "${paths[@]}" \
			| grep -i -E -q -e "(${alg_s}).*(\.c|\.cpp|\.cxx|\.h|\.hxx)"
		then
			found+=("${x}")
			local s=""
			for a in ${algs[@]} ; do
				if echo -e "${paths[@]}" \
					| grep -i -q -e "${a}" ; then
					s+="${a}, "
				fi
			done
			s=$(echo "${s}" | sed -e 's|, $||g')
			[[ -n "${s}" ]] && cryptlst[${hc}]="${s}"
		fi
		if echo "${paths[@]}" \
			| grep -i -E -q -e "(${asym_alg_s}).*(\.c|\.cpp|\.cxx|\.h|\.hxx)"
		then
			found_asym+=("${x}")
			local s=""
			for a in ${asym_algs[@]} ; do
				if echo -e "${paths[@]}" \
                        		| grep -i -q -e "${a}" ; then
					s+="${a}, "
				fi
			done
			s=$(echo "${s}" | sed -e 's|, $||g')
			[[ -n "${s}" ]] && asym_cryptlst[${hc}]="${s}"
		fi
	done
	for x in $(echo ${found[@]} | tr " " "\n" | sort | uniq) ; do
		local pn=$(gen_pn "${x}")
		local hc=$(echo "${x}" | sha1sum | cut -f 1 -d " ")
		if (( ${#asym_cryptlst[${hc}]} > 0 )) ; then
			has_single_dh && return
			printf "%-3s%-10s %s\n" "*/${pn}" "${CRYPTO_ASYM_OPT_CFG}" "# Contains ${asym_cryptlst[${hc}]} (expensive)"
		elif (( ${#cryptlst[${hc}]} > 0 )) && has_expensive_crypto "${#cryptlst[${hc}]}" ; then
			printf "%-30s%-10s %s\n" "*/${pn}" "${CRYPTO_EXPENSIVE_OPT_CFG}" "# Contains ${cryptlst[${hc}]} (expensive)"
		elif (( ${#cryptlst[${hc}]} > 0 )) ; then
			printf "%-30s%-10s %s\n" "*/${pn}" "${CRYPTO_CHEAP_OPT_CFG}" "# Contains ${cryptlst[${hc}]} (cheap)"
		fi
	done
}

search
