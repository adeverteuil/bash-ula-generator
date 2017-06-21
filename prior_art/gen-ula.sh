#!/bin/sh
#
#  ULA Generator
#  SUZUKI, Shinsuke <suz@kame.net>
#	based on Holger Zuleger's script
#	@(#) generate-uniq-local-ipv6-unicast-addr.sh
#	(c) Sep 2004	Holger Zuleger 
#
# Copyright (C) 1995, 1996, 1997, 1998, 1999, 2000, 2001, and 2002 WIDE Project.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of the project nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# $Id: gen-ula.cgi,v 1.11 2013/05/20 22:43:57 suz Exp $
#


#
#site-specific parameters
#

#NTP server name
ntpserv="clk.notemachi.wide.ad.jp"

#ntpdate program
ntpdate=/usr/sbin/ntpdate

#the caller of this CGI script
url="http://www.kame.net/~suz/gen-ula.html"

#list of typical bogus lower 24-bits in MAC address
typical_mac_list="010203 000000 000001 000102 123456"

#SHA hash calculator
sha=/usr/local/bin/sha

#IEEE OUI Database (available at http::/standards.ieee.org/regauth/oui/oui.txt)
ieeeoui=oui.txt

#
# main routine
#
#print-out header
echo Content-type: text/html
echo

cat << EOH
<body>
<head>
<title>
Generated ULA
</title>
</head>
<body>
EOH

#main routine

#1. NTP-date
date=`$ntpdate -dq $ntpserv 2> /dev/null |
	sed -n 's/^transmit timestamp: *\([^ ]*\) .*/\1/p' |
	tr -d "."`

#2. EUI64
# obtains a MAC address
#	sed 's/\(.*\)=\(..:..:..:..:..:..\).*$/\2/' |
mac=`echo $QUERY_STRING | sed 's/%3A/:/g' | 
	tr '[:lower:]' '[:upper:]' |
	sed 's/\(.*\)=\(..:..:..:..:..:..\).*$/\2/'`;
machex=`echo $mac | tr -d ':'`
#length check
len1=`echo $machex | wc -m`
#character check
len2=`echo $machex | tr -d [:xdigit:] | wc -m`
if [ $len1 != 13 -o $len2 != 1 ]; then
	echo "<h1>Error</h1>"
	echo "<p>MAC-address $mac is invalid"
	echo "<p>Please take care of the following points:
	<ul>
	<li>each octet must be separeted by colon (e.g. 00-01-02-03-04-05 is not permitted)
	<li>leading 0 of each octet cannot be omitted (e.g. 3:4:5:4:5:9 is not permitted)
	<li>each octet consists of 0-9 and A-F.
	</ul></p>"
	echo "<a href="$url">go back to the previous page</a></body>"
	exit
fi

# MAC Vendor check
machexvendor=`echo $machex | cut -c1-6`
macvendor=`grep "^  $machexvendor" $ieeeoui | cut -c23-`
if [ -z "$macvendor" ]; then
	echo "<h1>Error</h1>"
	echo "<p>MAC-address $mac"
	echo "is not registered to IEEE</p>"
	echo "<p>Please use the REAL MAC address</p>"
	echo "<a href="$url">go back to the previous page</a></body>"
	exit
fi

# booby trap:-)
machexid=`echo $machex | cut -c7-12`
for i in $typical_mac_list; do
	if [ $machexid = $i ]; then
		echo "<h1>Error</h1>"
		echo "<p>MAC-address $mac"
		echo "is a typical non-existing MAC address that is frequently used when a user is reluctant to find his/her own MAC address:-)</p>"
		echo "<p>Please use the REAL MAC address</p>"
		echo "<a href="$url">go back to the previous page</a></body>"
		exit
	fi
done

# generates EUI64 from the MAC address
first=`echo $machex | cut -c1-1`
second=`echo $machex | cut -c2-2`
macu=`echo $machex | cut -c3-6`
macl=`echo $machex | cut -c7-12`

# reversing u/l bit
case $second in
[13579BDF])
	echo "<h1>Error</h1>"
	echo "<p>MAC-address = $mac is a group MAC address</p>"
	echo "<a href="$url">go back to the previous page</a></body>"
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
A)
	second_rev=8;
	;;
C)
	second_rev=e;
	;;
E)
	second_rev=c;
	;;
*)
	#impossible
	echo "<h1>Error</h1>"
	echo "<p>MAC-address = $mac"
	echo "is registered to the IEEE database, but the first octet is regarded as invalid. (probably a bug in this script...) ($first$second)</p>"
	echo "<a href="$url">go back to the previous page</a></body>"
	exit
esac
eui64="${first}${second_rev}${macu}fffe${macl}"

globalid=`echo $date$eui64 | ${sha} -1 | cut -c23-32`
echo "<center>"
echo "<h1>"
echo "Generated ULA="
echo fd${globalid} | sed "s|\(....\)\(....\)\(....\)|\1:\2:\3::/48|"
echo "</center>"
echo "</h1>"

cat << TAIL
<ul>
<li>MAC address=$mac ($macvendor)
<li>EUI64 address=$eui64
<li>NTP date=$date
</ul>

<a href="$url">go back to the previous page</a>
</body>
TAIL
exit
