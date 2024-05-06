#!/bin/bash

function die
{
	echo "$@" >&2
	exit 1
}

function generate_u8_sample_data
{
	local out_file="$1"
	
	local tmp_1=/var/tmp/rnd.u8
	local tmp_2=/var/tmp/null.u8

	dd if=/dev/urandom bs=512k count=1 of="$tmp_1" &>/dev/null
	dd if=/dev/zero    bs=512k count=1 of="$tmp_2" &>/dev/null

	rm -f "$out_file"
	local i=0
	while [[ $i -lt $((2 * 1024)) ]] ; do
		cat "$tmp_1" >> "$out_file"
		cat "$tmp_2" >> "$out_file"
		i=$(( $i + 1 ))
	done

	rm -f "$tmp_1" "$tmp_2"
}

function downsample_4_u8
{
	local quality="$1"


	# https://sox.sourceforge.net/sox.html
	# https://stackoverflow.com/questions/1768077/how-can-i-make-sure-sox-doesnt-perform-automatic-dithering-without-knowing-the

	# About sox quality controls, from https://community.audirvana.com/t/explanation-for-sox-filter-controls/10848/9
	#       Quality   Band-  Rej dB   Typical Use
	#                 width
	# -q     quick     n/a   ~=30 @   playback on
	#                         Fs/4    ancient hardware
	# -l      low      80%    100     playback on old
	#                                 hardware
	# -m    medium     95%    100     audio playback
	# -h     high      95%    125     16-bit mastering
	#                                 (use with dither)
	# -v   very high   95%    175     24-bit mastering

	# Performance tests (SoX v14.4.2 / Linux 5.15.0-84-generic x86_64 / Ubuntu 22.04 / Intel(R) Core(TM) i5-4590 CPU)
	# - "-l" has about 50% usage of a single CPU core @ 40MSps -> 10MSps downsample
	#        10 MSps at 80% BW should give 4MHz analog signal bandwidth -> plenty for HiFi audio
	#        Manually confirmed to be correct by downsampling a sine sweep -> -6dB at 80% :)

	time sox -D \
		-t raw -r 400000 -b 8 -c 1 -L -e unsigned-integer - \
		-t raw           -b 8 -c 1 -L -e unsigned-integer - rate $quality 100000
}


if [[ ! -f test.u8 ]] ; then
	echo "Will generate test data ..."
	generate_u8_sample_data test.u8
fi

echo "Will bench now ..."

for q in "-q" "-l" "-m" ; do
	echo "====== sox qaulity $q ======"
	cat test.u8 | downsample_4_u8 "$q" > /dev/null
	echo "====== sox qaulity $q ======"
done

echo "Bench done :D"
