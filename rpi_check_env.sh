#!/usr/bin/env bash

echo_info() {
    echo "II: $@"
}

echo_warn() {
    echo -e "\e[7mWW\e[27m: $@"
}

echo_error() {
    echo -e "\e[5;7mEE\e[25;27m: $@"
}

echo_sup() {
    echo "  * $@"
}

show_version() {
    kern=$(vcgencmd get_config kernel | cut -d= -f2)
    if [ -n "$kern" ]; then
        echo_info "Kernel: $kern"
    else
        echo_info "Kernel: not set"
    fi

    serial=$(fgrep Serial /proc/cpuinfo | cut -d: -f2 | tr -d '[:space:]')
    echo_info "Serial: $serial"

    firm_hash=$(vcgencmd version | fgrep version | cut -d' ' -f2)
    echo_info "Firmware hash: $firm_hash"

    firm_date=$(vcgencmd version | head -n 1 | sed 's/[ \t]*$//g')
    echo_info "Firmware date: $firm_date"
}

check_model_and_freq() {
    rev=$(fgrep Revision /proc/cpuinfo | cut -d: -f2 | tr -d '[:space:]')
    echo_info "Revision: $rev"
    if echo "$rev" | grep -q '^2'; then
        echo_warn "Warranty is void for this Pi"
    fi

    # See https://www.raspberrypi.org/documentation/hardware/raspberrypi/revision-codes/README.md
    detect_model_new() {
        awk -v "rev_code=0x$rev" '
            function extract_bits(val, msb, lsb) {
                mask = lshift(lshift(1, msb - lsb + 1) - 1, lsb);
                return rshift(and(val, mask), lsb);
            }
            BEGIN {
                rev_code = strtonum(rev_code);
                pcb  = extract_bits(rev_code,  3,  0);
                mod  = extract_bits(rev_code, 11,  4);
                proc = extract_bits(rev_code, 15, 12);
                mfg  = extract_bits(rev_code, 19, 16);
                mem  = extract_bits(rev_code, 22, 20);
                new  = extract_bits(rev_code, 23, 23);
                if (new != 1) {
                    print("pcb=unk mod=unk proc=unk mfg=unk mem=unk");
                    exit 1;
                }
                pcb = sprintf("1.%d", pcb);
                switch (mod) {
                    case 0:
                        mod = "1A"; break;
                    case 1:
                        mod = "1B"; break;
                    case 2:
                        mod = "1A+"; break;
                    case 3:
                        mod = "1B+"; break;
                    case 4:
                        if (proc == 1) # BCM2836
                            mod = "2B";
                        else           # BCM2837
                            mod = "2B+";
                        break;
                    case 5:
                        mod = "@"; break;
                    case 6:
                        mod = "CM1"; break;
                    case 8:
                        mod = "3B"; break;
                    case 9:
                        mod = "0"; break;
                    case 10:
                        mod = "CM3"; break;
                    case 12:
                        mod = "0W"; break;
                    case 13:
                        mod = "3B+"; break;
                    default:
                        mod = sprintf("unk0x%02x", mod); break;
                }
                switch (mfg) {
                    case 0:
                        mfg = "Sony UK"; break;
                    case 1:
                        mfg = "Egoman"; break;
                    case 2:
                    case 4:
                        mfg = sprintf("Embest%d", mfg); break;
                    case 3:
                        mfg = "Sony Japan"; break;
                    case 5:
                        mfg = "Stadium"; break;
                    default:
                        mfg = sprintf("unk0x1x", mfg); break;
                }
                switch (mem) {
                    case 0:
                        mem = "256MB"; break;
                    case 1:
                        mem = "512MB"; break;
                    case 2:
                        mem = "1GB"; break;
                    default:
                        mem = sprintf("unk0x%1x", mem); break;
                }
                printf("pcb=\"%s\" mod=\"%s\" mfg=\"%s\" mem=\"%s\"\n",
                        pcb, mod, mfg, mem);
            }'
        return $?
    }

    rev=$(fgrep Revision /proc/cpuinfo |
            awk '{print substr($NF,length($NF)-5,6)}')
    # See https://elinux.org/RPi_HardwareHistory#Board_Revision_History
    case "$rev" in
        0002)   rel=2012Q1 mod=1B  pcb=1.0 mem=256MB mfg=;;
        0003)   rel=2012Q3 mod=1B  pcb=1.0 mem=256MB mfg=;;
        0004)   rel=2012Q3 mod=1B  pcb=2.0 mem=256MB mfg=Sony\ UK;;
        0005)   rel=2012Q4 mod=1B  pcb=2.0 mem=256MB mfg=Qisda;;
        0006)   rel=2012Q4 mod=1B  pcb=2.0 mem=256MB mfg=Egoman;;
        0007)   rel=2013Q1 mod=1A  pcb=2.0 mem=256MB mfg=Egoman;;
        0008)   rel=2013Q1 mod=1A  pcb=2.0 mem=256MB mfg=Sony\ UK;;
        0009)   rel=2013Q1 mod=1A  pcb=2.0 mem=256MB mfg=Qisda;;
        000d)   rel=2012Q4 mod=1B  pcb=2.0 mem=512MB mfg=Egoman;;
        000e)   rel=2012Q4 mod=1B  pcb=2.0 mem=512MB mfg=Sony\ UK;;
        000f)   rel=2012Q4 mod=1B  pcb=2.0 mem=512MB mfg=Qisda;;
        0010)   rel=2014Q3 mod=1B+ pcb=1.0 mem=512MB mfg=Sony\ UK;;
        0011)   rel=2014Q2 mod=CM1 pcb=1.0 mem=512MB mfg=Sony\ UK;;
        0012)   rel=2014Q4 mod=1A+ pcb=1.1 mem=256MB mfg=Sony\ UK;;
        0013)   rel=2015Q1 mod=1B+ pcb=1.2 mem=512MB mfg=Embest;;
        0014)   rel=2014Q2 mod=CM1 pcb=1.0 mem=512MB mfg=Embest;;
        0015)              mod=1A+ pcb=1.1 mem=256MB/512MB mfg=Embest;;
        a01040)            mod=2B  pcb=1.0 mem=1GB   mfg=Sony\ UK;;
        a01041) rel=2015Q1 mod=2B  pcb=1.1 mem=1GB   mfg=Sony\ UK;;
        a21041) rel=2015Q1 mod=2B  pcb=1.1 mem=1GB   mfg=Embest;;
        a22042) rel=2016Q3 mod=2B+ pcb=1.2 mem=1GB   mfg=Embest;;
        900021) rel=2016Q3 mod=1A+ pcb=1.1 mem=512MB mfg=Sony\ UK;;
        900032) rel=2016Q2 mod=1B+ pcb=1.2 mem=512MB mfg=Sony\ UK;;
        900092) rel=2015Q4 mod=0   pcb=1.2 mem=512MB mfg=Sony\ UK;;
        900093) rel=2016Q2 mod=0   pcb=1.3 mem=512MB mfg=Sony\ UK;;
        920093) rel=2016Q4 mod=0   pcb=1.3 mem=512MB mfg=Embest;;
        9000c1) rel=2017Q1 mod=0W  pcb=1.1 mem=512MB mfg=Sony\ UK;;
        a02082) rel=2016Q1 mod=3B  pcb=1.2 mem=1GB   mfg=Sony\ UK;;
        a020a0) rel=2017Q1 mod=CM3 pcb=1.0 mem=1GB   mfg=Sony\ UK;;
        a22082) rel=2016Q1 mod=3B  pcb=1.2 mem=1GB   mfg=Embest;;
        a32082) rel=2016Q4 mod=3B  pcb=1.2 mem=1GB   mfg=Sony\ Japan;;
        a52082)            mod=3B  pcb=1.2 mem=1GB   mfg=Stadium;;
        a020d3) rel=2018Q1 mod=3B+ pcb=1.3 mem=1GB   mfg=Sony\ UK;;
        *)
            echo_warn "Model is not on the eLinux list, using bit fields"
            s=$(detect_model_new)
            if [ $? -ne 0 ]; then
                echo_error "Cannot detect Raspberry Pi model"
                return
            fi
            eval $s;;
    esac

    echo_info "Model: $mod"
    echo_info "Memory: $mem"
    [ -n "$rel" ] && echo_info "Released: $rel"
    echo_info "PCB revision: $pcb"
    [ -n "$mfg" ] && echo_info "Manufactured by: $mfg"

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

        [ "$core" -ne 0 ] || core=$gpu
        [ "$h264" -ne 0 ] || h264=$gpu
        [ "$isp"  -ne 0 ] || isp=$gpu
        [ "$v3d"  -ne 0 ] || v3d=$gpu

        match_freq() {
            name="$1"
            def="$2"
            freq="$(eval echo \$$name)"
            if [ "$freq" != "$def" ]; then
                echo_warn "${name}_freq is ${freq}MHz instead of ${def}MHz"
                return 1
            else
                return 0
            fi
        }

        model="$(echo "$mod" | tr -d 'ABCM')"
        case "$model" in
            0|0W)
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
                    echo_sup "Early versions of firmware set sdram_freq to" \
                            "450MHz on Pi3+"
                fi
                ;;
            *) echo_error "Unknown model $model";;
        esac
    }

    check_freq

    export model
}

check_governor() {
    gov=$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor)
    if [ "$gov" != "performance" ]; then
        echo_warn "CPU freq governor is $gov instead of performance"
        echo_sup "Try 'echo performance | sudo tee" \
            "/sys/devices/system/cpu/cpufreq/policy0/scaling_governor'"
    fi
}

check_hdmi() {
    if ! tvservice -s | fgrep -q  'TV is off'; then
        echo_warn "HDMI is turned on"
        echo_sup "HDMI occupies the bus a little, which may affect performance"
        echo_sup "Run 'tvservice -o' to turn it off"
    fi
}

check_throttled() {
    th=$(vcgencmd get_throttled | cut -d= -f2)
    if [ $(awk "BEGIN{print and($th, lshift(1, 16))}") -ne 0 ]; then
        echo_warn "Under-voltage has occured"
        echo_sup "Try another robust power supply"
    fi
    if [ $(awk "BEGIN{print and($th, lshift(1, 17))}") -ne 0 ]; then
        echo_warn "ARM frequency capping has occured"
    fi
    if [ $(awk "BEGIN{print and($th, lshift(1, 18))}") -ne 0 ]; then
        echo_warn "Throttling has occured"
        echo_sup "This may because of under-voltage"
    fi
}

check_overlay() {
    [ "$model" == "0W" -o "$model" == "3" -o "$model" == "3+" ] || return
    overlays=$(sudo vcdbg log msg |& cut -d: -f2- | grep '^ Loaded overlay' |
            awk '{print $3}' | tr -d "'")
    if ! echo "$overlays" | fgrep -q pi3-disable-bt; then
        echo_warn "Bluetooth is enabled"
        echo_sup "Bluetooth inquiry occupies the bus a little," \
                "which may affect performance"
        echo_sup "Add 'dtoverlay=pi3-disable-bt' to config.txt to disable it"
    fi
    if ! echo "$overlays" | fgrep -q pi3-disable-wifi; then
        echo_warn "Wi-Fi is enabled"
        echo_sup "Wi-Fi inquiry occupies the bus a little," \
                "which may affect performance"
        echo_sup "Add 'dtoverlay=pi3-disable-wifi' to config.txt to disable it"
    fi
}

check_turbo() {
    val=$(vcgencmd get_config force_turbo | cut -d= -f2)
    if [ "$val" -eq 0 ]; then
        echo_warn "Turbo is not set"
        echo_sup "If not in turbo mode, GPU freqs are scaled dynamically," \
                "which may affect performance on a large VPM DMA transfers" \
                "for example"
        echo_sup "Add force_turbo=1 to config.txt to enable turbo mode"
    fi
    val=$(vcgencmd get_config avoid_warnings | cut -d= -f2)
    if [ "$val" -ne 2 ]; then
        echo_warn "avoid_warnings is not 2 in config.txt"
        echo_sup "Set avoid_warnings to 2 to disable GPU frequency scaling" \
                "when under-voltage"
    fi
}

check_swap() {
    if mount | fgrep -q swap; then
        echo_warn "Swap is enabled"
        echo_sup "Remove dphys-swapfile package"
    fi
}

show_version
check_model_and_freq
check_governor
check_hdmi
check_throttled
check_overlay
check_turbo
check_swap
