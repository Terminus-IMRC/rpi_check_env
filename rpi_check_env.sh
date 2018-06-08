#!/usr/bin/env bash

show_info() {
    rev=$(fgrep Revision /proc/cpuinfo | cut -d: -f2 | tr -d '[:space:]')
    echo "Revision: $rev"
    if echo "$rev" | grep -q '^2'; then
        echo "Warning: Warranty is void for this Pi"
    fi

    kern=$(vcgencmd get_config kernel | cut -d= -f2)
    echo -n "Kernel: "
    [ -n "$kern" ] && echo "$kern" || echo "not set"

    serial=$(fgrep Serial /proc/cpuinfo | cut -d: -f2 | tr -d '[:space:]')
    echo "Serial: $serial"

    firm_hash=$(vcgencmd version | fgrep version | cut -d' ' -f2)
    echo "Firmware hash: $firm_hash"

    firm_date=$(vcgencmd version | head -n 1 | sed 's/[ \t]*$//g')
    echo "Firmware date: $firm_date"
}

# See https://elinux.org/RPi_HardwareHistory#Board_Revision_History
detect_model() {
    rev=$(fgrep Revision /proc/cpuinfo \
          | awk '{print substr($NF,length($NF)-5,6)}')
    case "$rev" in
        0002)   rel=2012Q1 mod=1B  pcb=1.0 mem=256MB mfg=;;
        0003)   rel=2012Q3 mod=1B  pcb=1.0 mem=256MB mfg=;;
        0004)   rel=2012Q3 mod=1B  pcb=2.0 mem=256MB mfg=Sony;;
        0005)   rel=2012Q4 mod=1B  pcb=2.0 mem=256MB mfg=Qisda;;
        0006)   rel=2012Q4 mod=1B  pcb=2.0 mem=256MB mfg=Egoman;;
        0007)   rel=2013Q1 mod=1A  pcb=2.0 mem=256MB mfg=Egoman;;
        0008)   rel=2013Q1 mod=1A  pcb=2.0 mem=256MB mfg=Sony;;
        0009)   rel=2013Q1 mod=1A  pcb=2.0 mem=256MB mfg=Qisda;;
        000d)   rel=2012Q4 mod=1B  pcb=2.0 mem=512MB mfg=Egoman;;
        000e)   rel=2012Q4 mod=1B  pcb=2.0 mem=512MB mfg=Sony;;
        000f)   rel=2012Q4 mod=1B  pcb=2.0 mem=512MB mfg=Qisda;;
        0010)   rel=2014Q3 mod=1B+ pcb=1.0 mem=512MB mfg=Sony;;
        0011)   rel=2014Q2 mod=CM1 pcb=1.0 mem=512MB mfg=Sony;;
        0012)   rel=2014Q4 mod=1A+ pcb=1.1 mem=256MB mfg=Sony;;
        0013)   rel=2015Q1 mod=1B+ pcb=1.2 mem=512MB mfg=Embest;;
        0014)   rel=2014Q2 mod=CM1 pcb=1.0 mem=512MB mfg=Embest;;
        a01040) rel=unk    mod=2B  pcb=1.0 mem=1GB   mfg=Sony;;
        a01041) rel=2015Q1 mod=2B  pcb=1.1 mem=1GB   mfg=Sony;;
        a21041) rel=2015Q1 mod=2B  pcb=1.1 mem=1GB   mfg=Embest;;
        a22042) rel=2016Q3 mod=2B+ pcb=1.2 mem=1GB   mfg=Embest;;
        900021) rel=2016Q3 mod=1A+ pcb=1.1 mem=512MB mfg=Sony;;
        900032) rel=2016Q2 mod=1B+ pcb=1.2 mem=512MB mfg=Sony;;
        900092) rel=2015Q4 mod=0   pcb=1.2 mem=512MB mfg=Sony;;
        900093) rel=2016Q2 mod=0   pcb=1.3 mem=512MB mfg=Sony;;
        920093) rel=2016Q4 mod=0   pcb=1.3 mem=512MB mfg=Embest;;
        9000c1) rel=2017Q1 mod=0W  pcb=1.1 mem=512MB mfg=Sony;;
        a02082) rel=2016Q1 mod=3B  pcb=1.2 mem=1GB   mfg=Sony;;
        a020a0) rel=2017Q1 mod=CM3 pcb=1.0 mem=1GB   mfg=Sony;;
        a22082) rel=2016Q1 mod=3B  pcb=1.2 mem=1GB   mfg=Embest;;
        a32082) rel=2016Q4 mod=3B  pcb=1.2 mem=1GB   mfg=Sony\ Japan;;
        a020d3) rel=2018Q1 mod=3B+ pcb=1.3 mem=1GB   mfg=Sony;;
        *) echo 'Cannot detect Raspberry Pi model!' >&2; return;;
    esac
    echo "rel=\"$rel\" mod=\"$mod\" pcb=\"$pcb\" mem=\"$mem\" mfg=\"$mfg\""
}

check_freq() {
    extract_freq() {
        name="$1"
        vcgencmd get_config "${name}_freq" | cut -d= -f2
    }
    gpu=$(extract_freq gpu)
    core=$(extract_freq core)
    h264=$(extract_freq h264)
    isp=$(extract_freq isp)
    v3d=$(extract_freq v3d)
    arm=$(extract_freq arm)
    sdram=$(extract_freq sdram)

    [ "$core" != 0 ] || core=$gpu
    [ "$h264" != 0 ] || h264=$gpu
    [ "$isp"  != 0 ] || isp=$gpu
    [ "$v3d"  != 0 ] || v3d=$gpu

    match_freq() {
        name="$1"
        def="$2"
        freq="$(eval echo \$$name)"
        if [ "$freq" != "$def" ]; then
            echo "Warning:" \
                "${name}_freq is ${freq}MHz while the default is ${def}MHz" >&2
            return 1
        else
            return 0
        fi
    }

    model="$(echo $1 | tr -d 'ABCMW')"
    case "$model" in
        0)
            match_freq gpu    400
            match_freq core   300
            match_freq h264   300
            match_freq isp    300
            match_freq v3d    300
            match_freq arm   1000
            match_freq sdram  450
            ;;
        1|1\+)
            match_freq gpu    250
            match_freq core   250
            match_freq h264   250
            match_freq isp    250
            match_freq v3d    250
            match_freq arm    700
            match_freq sdram  400
            ;;
        2)
            match_freq gpu    250
            match_freq core   250
            match_freq h264   250
            match_freq isp    250
            match_freq v3d    250
            match_freq arm    900
            match_freq sdram  400
            ;;
        2\+|3)
            match_freq gpu    300
            match_freq core   400
            match_freq h264   300
            match_freq isp    300
            match_freq v3d    300
            match_freq arm   1200
            match_freq sdram  450
            ;;
        3\+)
            match_freq gpu    300
            match_freq core   400
            match_freq h264   300
            match_freq isp    300
            match_freq v3d    300
            match_freq arm   1400
            if ! match_freq sdram 500; then
                echo "Note: Early versions of firmware set sdram_freq to 450MHz"
            fi
            ;;
        *) echo "Unknown model $model" >&2;;
    esac
}

check_hdmi() {
    if ! tvservice -s | fgrep -q  'TV is off'; then
        echo "Warning: HDMI is turned on. Run 'tvservice -o' to turn it off."
    fi
}

check_throttled() {
    th=$(vcgencmd get_throttled | cut -d= -f2)
    if [ $(awk "BEGIN{print and($th, lshift(1, 16))}") -ne 0 ]; then
        echo "Warning: Under-volrage has occured"
    fi
    if [ $(awk "BEGIN{print and($th, lshift(1, 17))}") -ne 0 ]; then
        echo "Warning: ARM frequency capping has occured"
    fi
    if [ $(awk "BEGIN{print and($th, lshift(1, 18))}") -ne 0 ]; then
        echo "Warning: Throttling has occured"
    fi
}

eval $(detect_model)
if [ -n "$mod" ]; then
    echo "Model: $mod"
    echo "Memory: $mem"
    echo "Released: $rel"
    echo "PCB revision: $pcb"
    if [ -n "$mfg" ]; then
        echo "Manufactured by: $mfg"
    fi
fi
show_info
check_freq "$mod"
check_hdmi
check_throttled
