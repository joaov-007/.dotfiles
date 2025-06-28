#!/bin/bash
#
# FUCKING PUBLIC LICENCE

# This code belongs to me jul@github.com/@obnoxiousJul and all (insert <#alias>) contributing in making it fun.
# And fucking stop being Pissenlit Würzel Schleckers met bigoudis with open source devs and maintainers

# v 0.6     updated source of doh, and oisd, works on linuxmint, use always_null from unbound for adblocking
# v 0.5.1   cross devuan/debian restarting of unbound
# v 0.5     having fun
# v 0.4     code got ugly, BUT, making dynamic list from adblock conf for firefox (easylist)
# v 0.3     building a dynamic list of DNS over HTTP server
# v 0.2.1   meilleure info sur les erreurs curl et préz plus compacte
# v 0.2     générer une sortie du fichier qui pète pas unbound


set -e
RZ="\e[0m"
GD="\e[32m"
RD="\e[31m"
BL=$( tput bold )
get_abs_filename() {
  # $1 : relative filename
  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}
function adblock_to_block_list {
# $1 url for ezlist/adblock list
    curl -s "$1" | perl -ane 'm!^\|\|(:?.*\*\.)*([^/\|]+)\^$! and print "$2\n"'
}


export PATH="/bin/:/usr/bin/:/sbin/:/usr/sbin:/usr/local/sbin:/usr/local/bin"
tmpfile="$(mktemp)" && echo '' > "$tmpfile"
tmp_work="$(mktemp)" && echo '' > "$tmp_work"
unboundconf="/etc/unbound/unbound.conf.d/_unbound-adhosts.conf"

NO_DOH=$( get_abs_filename ~/no_doh.txt)
NO_DOH_SOURCE=https://github.com/curl/curl/wiki/DNS-over-HTTPS
EZLIST_FN="/etc/ez_black.txt"

echo
declare -A EZLIST=(
    [privacy]=https://easylist.to/easylist/easyprivacy.txt
    [easylist]=https://easylist.to/easylist/easylist.txt
    [fanboy]=https://easylist.to/easylist/fanboy-social.txt
    [fanboy_annoyance]=https://secure.fanboy.co.nz/fanboy-annoyance.txt
    [fr_annoyance]=https://easylist-downloads.adblockplus.org/liste_fr.txt
)

# personnal list in /etc/adblack.txt
declare -A BLOCK=(
    # [perso]="file:///etc/adblack.txt"
    # [ezlist]="file://${EZLIST_FN}"
    [oisd]=https://big.oisd.nl/
    # [no_doh]=file://$( get_abs_filename "$NO_DOH" )
    [doh]=https://raw.githubusercontent.com/oneoffdallas/dohservers/master/list.txt
    [adaway]=https://adaway.org/hosts.txt
    [pihole_disconad]="https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt"
    [pihole_discontrack]="https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt"
    [fademind]="https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts"
    [pihole_stevenblack]="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
    [sysctl]=http://sysctl.org/cameleon/hosts
    [NSO]=https://raw.githubusercontent.com/AmnestyTech/investigations/master/2021-07-18_nso/domains.txt
    [suspicous_low]=https://www.dshield.org/feeds/suspiciousdomains_Low.txt
    [suspicous_medium]=https://www.dshield.org/feeds/suspiciousdomains_Medium.txt
    [suspicous_high]=https://www.dshield.org/feeds/suspiciousdomains_High.txt
    [winhelp]=https://winhelp2002.mvps.org/hosts.txt
    [yoyo]="https://pgl.yoyo.org/as/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext"
    [firebog_w3k]=https://v.firebog.net/hosts/static/w3kbl.txt
    [matomo]=https://raw.githubusercontent.com/matomo-org/referrer-spam-blacklist/master/spammers.txt
    [dawsey]=https://raw.githubusercontent.com/Dawsey21/Lists/master/main-blacklist.txt
    [vokins]=https://raw.githubusercontent.com/vokins/yhosts/master/hosts
)
python3 -c 'import tld; tld.is_tld(".com")' && echo -e "python3.tld ${GD}OK${RZ}" || ( sudo apt install python3-pip ; python3 -mpip install tld --user)

function transform_into_unbound_entries {
    perl -pe 's/ *#.*$//g' | \
    perl -ane 'if (/^\|?\|?([^#\^\*].+)\^?$/) { @l=split( /\s+/,$1);
    $h = lc(pop(@l));
    $h =~ s/\015//g;
    $h =~ s/^\s+|\s+$//g;
    if ($h=~ /^(?=.{1,255}$)[0-9\-_a-z](([\-_0-9a-z]|\b-){0,61}[\-_a0-9a-z])?(\.[\-_0-9a-z](([\-_0-9a-z]|\b-){0,61}[\-_0-9a-z])?)*(\.|\^)?$/) {
        print "$h\n";
    } else {
        $h =~ /^\s*$/ or print STDERR "IGNORED: $h\n";
    }
  }' | \
    python3 -c '(sys,tld)=(__import__("sys"), __import__("tld")); [ ( tld.get_tld(l.strip(), fix_protocol=True,fail_silently=True) and sys.stdout or sys.stderr).write(l) for l in sys.stdin.readlines() ] '  2> /dev/null | \
    while read h; do printf '   local-zone: "%s" always_null\n' "$h"; done;
};
sudo touch "${EZLIST_FN}"
sudo chmod 664 "${EZLIST_FN}"
sudo su -c "echo "" > "${EZLIST_FN}" "
echo -e "\ngenerating lists from eazylist"
echo -e "==============================\n"
for K in "${!EZLIST[@]}"; do
    printf "${BL}%-20s${RZ} " "$K"
    adblock_to_block_list "${EZLIST[$K]}" > $tmp_work && \
        >&2 echo  -e "${GD}OK${RZ} $( printf "%7d" `wc -l < "$tmp_work"` ) entries"  || \
        ( >&2 echo -e ${RD}KO${RZ} && curl -s -S "${EZLIST[$K]}"  );
    sudo su -c " cat "$tmp_work" >> "${EZLIST_FN}" "
done
sort -r < "${EZLIST_FN}" | uniq > "$tmp_work"
sudo su -c " cat "$tmp_work" >"${EZLIST_FN}" "
echo -n -e "Total                     ${BL}$( wc -l < "$EZLIST_FN" )${RZ} entries (unique)\n"
echo


echo -e "\ngetting blocklists for unbound"
echo -e "==============================\n"

{
    echo "server:
   harden-below-nxdomain:yes";
    for K in "${!BLOCK[@]}"; do
        >&2 printf "${BL}%-20s${RZ} " "$K"
        curl -s "${BLOCK[$K]}" > "$tmp_work" && \
            >&2 echo  -e "${GD}OK${RZ} $( printf "%7d" `wc -l < "$tmp_work"` ) entries"  || \
            ( >&2 echo -e ${RD}KO${RZ} && curl -s -S "${BLOCK[$K]}"  );
        transform_into_unbound_entries < "$tmp_work" &> /tmp/w.${K};
        transform_into_unbound_entries < "$tmp_work";
    done | sort -r | uniq
} >> "$tmpfile"

echo -n -e "Total                    ${BL}$( wc -l < "$tmpfile" )${RZ} entries (unique)\n"
echo
set -e
BACKUP="$unboundconf.$( date -Im)"
echo -e "backup in  $BL${BACKUP}${RZ}"
[ -e "$unboundconf" ] && sudo install -o root -m 644  "$unboundconf" "$BACKUP";

echo -e installing $BL"$unboundconf"${RZ}

sudo install -o root -m 644  "$tmpfile" "$unboundconf";


echo
echo -n "checking unbound configuration "

( sudo unbound-checkconf > /dev/null && echo  -e "${GD}OK${RZ}" || echo -e "${RD}KO${RZ}" ) && \
    ( echo -n "restarting unbound             " && sudo /etc/init.d/unbound restart 1>/dev/null && echo  -e "${GD}OK${RZ}" || echo -e "${RD}KO${RZ}" ) && \
    echo

exit 0
