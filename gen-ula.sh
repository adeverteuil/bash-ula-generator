#!/bin/bash
#
# ULA Generator
# Alexandre de Verteuil <adeverteuil@inap.com>
# 2017-06-20
#
# Based on scripts from Shinsuke Suzuki and Holger Zuleger,
# available under the prior_art directory.
#
# Usage: simply run in a bash shell. You will be prompted for your
# physical MAC address. Guessing eth0 is no longer relevant in 2017.
#
# Requirements: wget, ntpq
#
# Improvements over other scripts:
#   - Not a CGI script
#   - Computes the SHA1 hash of bytes, not their hex representation
#   - Better text output
#
# References:
#
# RFC 4193 -- Unique Local IPv6 Unicast Addresses
#   https://tools.ietf.org/html/rfc4193
#
# Unique local address
#   https://en.wikipedia.org/wiki/Unique_local_address


function die() {
    echo
    echo "== Error =="
    echo "$@"
    exit 1
}

read -p "MAC address: " mac
mac=$(echo $mac | tr -d :-)
if [ ${#mac} -ne 12 ]; then
    die "MAC address \"${mac}\" is invalid"
fi

echo "For a deterministic calculation, you may enter the ntp clock time."
echo "Leave empty to query an NTP server."
read -p "Clock: " clock
if [ -z "${clock}" ]; then
    clock=$(ntpq -c "rv 0 clock" 0.pool.ntp.org | cut -c7-23)
    # Input: "clock=dcf4268b.208dd000  Tue, Jun 20 2017 18:56:11.127"
    # Output: "dcf4268b.208dd000"
fi
clock=$(tr -d . <<< "${clock}")
if [ "${#clock}" -ne 16 ]; then
    die "Time in NTP format is 64 bits, "\
        "or 16 characters in hex representation. "\
        "You entered: \"${clock}\"."
fi


if [ ! -r oui.txt ]; then
    wget http://standards.ieee.org/regauth/oui/oui.txt
fi

# MAC Vendor check
machexvendor=$(tr a-f A-F <<< "${mac:0:6}")
macvendor=$(grep "^$machexvendor" oui.txt | sed -r "s/.*\t([^\r\n]*).*/\1/")
if [ -z "$macvendor" ]; then
    die "MAC address \"${mac}\" is not registered to IEEE. "\
        "Please use a REAL MAC address."
fi

# Generate an EUI64 from the MAC address
# as described in RFC 3513
# https://tools.ietf.org/html/rfc3513

first=`echo $mac | cut -c1-1`
second=`echo $mac | cut -c2-2`
macu=`echo $mac | cut -c3-6`
macl=`echo $mac | cut -c7-12`

# reversing u/l bit
case $second in
    [13579bdf])
        echo "Error"
        echo "MAC-address = $mac is a group MAC address"
        exit
        ;;
    0)
        second_rev=2
        ;;
    2)
        second_rev=0
        ;;
    4)
        second_rev=6;
        ;;
    6)
        second_rev=4;
        ;;
    8)
        second_rev=a;
        ;;
    a)
        second_rev=8;
        ;;
    c)
        second_rev=e;
        ;;
    e)
        second_rev=c;
        ;;
    *)
        #impossible
        die "MAC address \"${mac}\" is registered to the IEEE database, "\
            "but the first octet (${first}${second}) is regarded as invalid. "\
            "(probably a bug in this script...)"
esac
eui64="${first}${second_rev}${macu}fffe${macl}"

# Convert from hex string representation to bytes before sha1sum
# https://unix.stackexchange.com/a/82766
globalid=$(echo -ne $(sed "s/../\\x&/g" <<< ${date}${eui64}) | sha1sum | cut -c23-32)
ula=$(echo fd${globalid} | sed "s|\(....\)\(....\)\(....\)|\1:\2:\3::/48|")

echo
echo "## Inputs ##"
echo "MAC address = ${mac} (${macvendor})"
echo "NTP time = ${clock}"
echo
echo "## Intermediary values ##"
echo "EUI64 address = ${eui64}"
echo
echo "## Generated ULA ##"
echo "${ula}"
echo
