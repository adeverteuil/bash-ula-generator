#!/bin/bash
#
# ULA Generator
# Alexandre de Verteuil <adeverteuil@inap.com>
# 2017-06-20
#
# Timothe Litt <litt@acm.org>
# 2020-02-03
#   - Autodetect hardware address from an interface if not specified
#   - Handle upper-case hex input
#   - Allow user-specified NTP server
#   - If ntpq fails, try ntpdate (many NTP servers block rv commands with restrict noquery).
#   - Handle NTP servers with more than one address.
#   - Fix use of undefined 'date' (instead of 'clock') in GID, use LSB of SHA per RFC
#   - If oui.txt is downloaded, put it in /tmp & remove it on exit
#   - Use variables for defaults
#   - Default to autodetection, add a -i option to prompt user
#   - Add usage and command line options.
#   - Ensure all errors reported to stderr.  Fully validate input.
#   - Suppress leading zeros in ULA
#   - Don't depend on GNU sed's extended REs or GNU echo -ne
#   - By default, only output generated ULA.  -v for verbose mode.
#   - Option to get (download) a copy of oui.txt
#
# Based on scripts from Shinsuke Suzuki and Holger Zuleger,
# available under the prior_art directory.
#
# Usage: simply run in a bash shell. 
# use -h for complete usage information.
#
# Requirements: wget, cut, tr, sed, grep, tail, head, sort, which
# Optional: ntpq, ntpdate, ip, ifconfig
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
# RFC 3513 -- Internet Protocol Version 6 (IPv6) Addressing Architecture
#   https://tools.ietf.org/html/3513
#
# Unique local address
#   https://en.wikipedia.org/wiki/Unique_local_address

LC_ALL=C
export LC_ALL

# Default NTP server
NTP_server="0.pool.ntp.org"

# Source for oui.txt (MAC issuers)
[ -z "$OUI_URI" ] && OUI_URI="http://standards-oui.ieee.org/oui.txt"
#
# Default placement of oui.txt
# - Will look for it here first
OUI_TXT_dir="."
# - Will put a temporary copy here if not found in OUI_TXT_dir
[ -z "$TMPDIR" ] && TMPDIR="/tmp"

# Prevent inherited variables from influencing command

GET_oui=
INTER=
mac=
clock=
VERB=
OUI_UID=

# Report error and exit

function die() {
    cat <<EOF >&2

== Error ==
$@
EOF
    exit 1
}

# ifconfig, ip are usually in /usr/sbin.  Ensure that at least one of
# the various sbins is in PATH.  If not, put at end so as not to
# replace anything in the current PATH.

if ! echo "$PATH" | grep -q '/sbin'; then
    PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"
    export PATH
fi

# Produce usage & exit

function usage() {
    local prog="`basename $0 .sh`"

    cat <<EOF
Generates a Unique Local IPv6 Unicast address block

Usage:
    ${prog} [-i] [-n ntp] [-m mac] [-t time] [-g] [-d dir] [-v]

Unique Local IPv6 Unicast addresses are defined in RFC4193.  ${prog}
generates a /48 prefix for a ULA address block as recommended in
RFC4193.

The ULA is not globally routable, but may be routed within a
site/organization.  It is useful for provider-independent internal
addressing, including for VPN tunnels.

There is a good chance that the ULA will be globally unique - this
means that if your network is ever acquired/merged/tunneled, conflicts
are unlikely.  "Good chance" and "unlikely" are not guarantees.

The pseudo-random 40-bit global ID is generated from the hash of an NTP
timestamp and a MAC address.  Both of these are discovered by default,
but can be specified for advanced usage.  Hashing makes the GID opaque.
Please read RFC4193 carefully before deviating from the defaults.

OPTIONS:
  -i      - Interactive mode.  Prompts for MAC address and NTP time.
  -n ntp  - Specify the NTP server to query.
            Use -n if default is blocked, e.g. by firewall.
            Current: $NTP_server
  -m mac  - Specify the MAC (hardware) address of an interface on which
            to base the ULA.  Use one permanently assigned to your site
            or organization.  48-bit, in hexadecemal.
            Current: select from system interfaces.
  -t time - Specify an absolute NTP timestamp. 64-bit, in hexadecimal.
            Provides deterministic ULA.
            Current: obtain from NTP
  -g      - Get (download) a copy of the OUI database, no ULA
            will be generated,
  -d dir  - Directory for cached copy of OUI database.
            Current: $OUI_TXT_dir (Non-cached stored in $TMPDIR)
  -v      - Verbose mode (show progress/intermediate results)
  -h      - This usage.

Generally, you don't need to specify any options.

The MAC autoselection uses the first interface with an ethernet
address. The address of another interface can be used safely.
However, since the purpose is only to seed a hash to identify
the network, there is no reason to prefer one over another.

MAC addresses are validated with the IEEE registry of issuers,
found at $OUI_URI.  If $OUI_TXT_dir/oui.txt is
present, it is used.  Otherwise, a temporary copy is downloaded,
used and deleted.  To get or update a local copy, which is useful if
many ULAs are to be generated, specify -g.

The NTP timestamp allows a given system to generate many distinct ULAs.

The hash ensures that there are no privacy concerns or information leakage
in the ULA.

ENVIRONMENT VARIABLES
  OUI_URI - Source for OUI database
            Current: $OUI_URI
  TMPDIR  - directory used for temporary file
            Current: $TMPDIR

EXAMPLES
  Generate a ULA
    # $prog
    fd97:a562:a484::/48

  Generate several ULAs
    # ./gen-ula.sh -g
    # ./gen-ula.sh
    fd92:daf6:ab94::/48
    # ./gen-ula.sh
    fd83:87a2:ded7::/48
    # ./gen-ula.sh
    fde4:dbe8:2798::/48
    rm -f oui.txt

BUGS
  Report any suspected bugs at
  https://github.com/adeverteuil/bash-ula-generator/issues

AUTHORS
  Alexandre de Verteuil, based on scripts from Shinsuke Suzuki and Holger Zuleger,
  Timothe Litt:  Bug fixes and simplified usage (fork:
                 https://github.com/tlhackque/bash-ula-generator)
EOF
    exit 0
}

# Parse options

while getopts ":d:ghin:m:t:v" opt; do
    case "${opt}" in
        d)
            OUI_TXT_dir="$OPTARG"
            ;;
        g)
            GET_oui=1
            ;;
        h)
            usage
            ;;
        i)
            INTER=1
            ;;
        m)
            mac="$OPTARG"
            ;;
        n)
            NTP_server="$OPTARG"
            ;;
        t)
            clock="#$OPTARG"
            ;;
        v)
            VERB=1
            ;;
        \?)
            die "Invalid option: \"$OPTARG\", use -h for usage"
            ;;
        : )
            die "Option: \"$OPTARG\" requires an argument, use -h for usage"
            ;;
    esac
done
shift $((OPTIND -1))

[ -n "$1" ] && die "Superfluous argument \"$1\", use -h for usage"

# oui.txt download only

if [ -n "$GET_oui" ]; then
    Q="-q"
    [ -n "$VERB" ] && Q=

    # wget may exit success even if file not found.

    rm -f "$OUI_TXT_dir/oui.txt"
    if ! wget -O "$OUI_TXT_dir/oui.txt" $Q "$OUI_URI" || [ ! -r "$OUI_TXT_dir/oui.txt" ]; then
        die "Failed to download $OUI_URI"
    fi
    exit 0
fi

# Validate a hex string for content and length

function checkhex() {
    local in="$1"
    local len="$2"
    local ele="$3"

    # Isolate any non-hex characters
    local tmp="$(echo "$in" | tr -d '[:xdigit:]')"
    if [ -n "$tmp" ]; then
        # Report unique instances of invalid characters in input
        tmp="$(echo "$tmp" | grep -o '.' | sort -u | tr -d '\n')"
        die "Invalid character(s) \"$tmp\" in $ele"
    fi

    # Check length
    if [ "${#in}" -ne "$len" ]; then
        die "Length of $ele is ${#in}, but should be $len"
    fi
}

# Prompt for MAC address if interactive and not specified

[ -n "$INTER" -a -z "$mac" ] && read -p "MAC address (<CR> to detect): " mac
if [ -z "$mac" ]; then
    # Use first interface with a hardware address

    if which ip >/dev/null 2>&1 ; then
        mac="`ip link show | sed -n -e'/link\/ether /!d;s|^.*link/ether \([0-9a-f:-]*\).*$|\1|p' | head -n1 | tr -d '\n:'`"
    elif which ifconfig >/dev/null 2>&1 ; then
        # ifconfig output varies
        # Caution: [] contains space && tab
        mac="`ifconfig | sed -n  -e'/[ ]\(ether\|HWaddr\) /!d;s,^.*\(ether\|HWaddr\) \([0-9a-fA-F:-]*\).*$,\2,p' | head -n1 | tr -d '\n:'`"
    else
        die "Neither 'ip' nor 'ifconfig' found on $PATH."
    fi
fi

# Remove any delimiters from MAC address and force lower-case hex

mac="$(echo "$mac" | tr 'A-F' 'a-f' | tr -d '\n:.-')"
checkhex "$mac" 12 "MAC address"

# Prompt for time source (or time) if interactive and not specified

if [ -n "$INTER" -a -z "$clock" ]; then
    cat <<EOF
Time in NTP format is required.  Options:
 - Type <CR> to use $NTP_server, or
 - Type an NTP server name, or
 - For a deterministic result, type "#high.low", where "high" and "low" are 8 hex digits.
EOF
    read -p "Clock: " clock
fi
if [ "${clock:0:1}" = "#" ]; then
    clock="${clock:1}"
else
    [ -n "$clock" ] && NTP_server="$clock"
    clock=
fi
if [ -z "${clock}" ]; then
    if [ -n "$VERB" ]; then
        echo "Obtaining time from $NTP_server. This may take a while."
        echo "Note: \"timed-out\" messages are non-fatal."
        exec 99>&2
    else
       exec 99>/dev/null
    fi
    # A server with multiple addresses may return multiple results.  Use only the last.
    # ntpq "rv" is most efficient, but many servers now block.  Fall back to ntpdate.

    if now="$(2>&99 ntpq -c 'rv 0 clock' "$NTP_server" | grep 'clock=')"; then
        clock="$(echo "$now"  | tail -n 1 | cut -c7-23)"
        # Input: "clock=dcf4268b.208dd000  Tue, Jun 20 2017 18:56:11.127"
        # Output: "dcf4268b.208dd000"
    elif now="$(ntpdate -d -q "$NTP_server" 2>&99 )" ; then
        clock="$(echo "$now" | sed -n -e'/^transmit timestamp:/!d;s/^transmit timestamp: *\([0-9a-fA-F][0-9a-fA-F.]*\) .*/\1/p' | tail -n 1 | tr -d '.')"
    else
        99>&-
        die "Unable to contact $NTP_server"
    fi
    99>&-
fi
clock=$(tr -d . <<< "${clock}")
checkhex "$clock" 16 "NTP format time (hex)"

# OUI check.  If oui.txt exists, leave it alone.  Otherwise fetch a temporary copy

if [ ! -r "$OUI_TXT_dir/oui.txt" ]; then
    OUI_TXT_dir="$TMPDIR"
    OUI_UID=".$$"
    trap "rm -f $OUI_TXT_dir/oui${OUI_UID}.txt" INT TERM EXIT
    if [ -n "$VERB" ]; then
        echo "Fetching OUI data from $OUI_URI"
    fi
    if ! wget -O "$OUI_TXT_dir/oui${OUI_UID}.txt" -q "$OUI_URI" || [ ! -r "$OUI_TXT_dir/oui.txt" ]; then
        die "Failed to download $OUI_URI"
    fi
fi

# MAC Vendor check

machexvendor="$(tr 'a-f' 'A-F' <<< "${mac:0:6}")"
macvendor="$(grep "^$machexvendor" "$OUI_TXT_dir/oui${OUI_UID}.txt" | sed -e "s/.*\t\([^\r\n]*\).*/\1/")"
if [ -z "$macvendor" ]; then
    die "MAC address \"${mac}\" is not registered by IEEE. "\
        "Please use a REAL MAC address."
fi

# Generate an EUI64 from the MAC address
# as described in RFC 3513
# https://tools.ietf.org/html/rfc3513

first="`echo "$mac" | cut -c1-1`"
second="`echo "$mac" | cut -c2-2`"
macu="`echo "$mac" | cut -c3-6`"
macl="`echo "$mac" | cut -c7-12`"

# reversing u/l bit
case $second in
    [13579bdf])
        die "MAC-address \"${mac}\" is a group address"
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
        # impossible - non-hex, found in oui.txt
        die "MAC address \"${mac}\" is registered to \"${macvendor}\" in the IEEE database, "\
            "but the first octet (${first}${second}) is regarded as invalid. "\
            "(probably a bug in this script...)"
esac
eui64="${first}${second_rev}${macu}fffe${macl}"

# Convert from hex string representation to bytes before sha1sum
# https://unix.stackexchange.com/a/82766
globalid="$(printf "$(sed -e's/../\\x&/g' <<< "${clock}${eui64}")" | sha1sum -b | cut -c31-40)"

# Format resulting ULA as an IPv6 address.  fd00::/8 designates a ULA (prefix fc00/7) with L=1..
# GlobalID is 40 bits. (last 10 (hex) chars of SHA).  Total of 48 bits assigned here.
# Subnet(16) and interface(64) bits are 0 (for user to assign).
ula="$(echo "fd${globalid}" | sed -e "s|\(....\)\(....\)\(....\)|\1:\2:\3:|; s/:00*/:/g; s/::/:0:/; s/::/:0:/")"
ula="$ula:/48"

# Results

if [ -n "$VERB" ]; then
    cat <<EOF

## Inputs ##
MAC address = ${mac} (${macvendor})
NTP time    = ${clock}

## Intermediate values ##
EUI64 address = ${eui64}

## Generated ULA ##
EOF
fi
echo "${ula}"

exit 0
