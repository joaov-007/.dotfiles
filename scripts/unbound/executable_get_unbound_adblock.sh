#!/bin/sh
#
# FUCKING PUBLIC LICENCE

# This code belongs to me jul@github.com/@obnoxiousJul and all (insert <#alias>) contributing in making it fun.
# And fucking stop being Pissenlit Würzel Schleckers met bigoudis with open source devs and maintainers

# v 0.7     POSIX sh, no associative arrays; works on Arch (systemctl) too
# v 0.6     updated source of doh, and oisd, works on linuxmint, use always_null from unbound for adblocking
# v 0.5.1   cross devuan/debian restarting of unbound
# v 0.5     having fun
# v 0.4     code got ugly, BUT, making dynamic list from adblock conf for firefox (easylist)
# v 0.3     building a dynamic list of DNS over HTTP server
# v 0.2.1   meilleure info sur les erreurs curl et préz plus compacte
# v 0.2     générer une sortie du fichier qui pète pas unbound

set -eu
RZ=$(printf '\033[0m')
GD=$(printf '\033[32m')
RD=$(printf '\033[31m')
BL=$(tput bold 2>/dev/null) || BL=

adblock_to_block_list() {
    # $1 url for ezlist/adblock list
    curl -s "$1" | perl -ane 'm!^\|\|(:?.*\*\.)*([^/\|]+)\^$! and print "$2\n"'
}

export PATH="/bin/:/usr/bin/:/sbin/:/usr/sbin:/usr/local/sbin:/usr/local/bin"

tmpfile=$(mktemp)
tmp_work=$(mktemp)
tmp_entries=$(mktemp)
tmp_sorted=$(mktemp)
trap 'rm -f -- "$tmpfile" "$tmp_work" "$tmp_entries" "$tmp_sorted"' 0
: >"$tmpfile"
: >"$tmp_work"

unboundconf="/etc/unbound/unbound.conf.d/_unbound-adhosts.conf"

EZLIST_FN="/etc/ez_black.txt"

ezlist_entries() {
    cat <<'EOF'
privacy https://easylist.to/easylist/easyprivacy.txt
easylist https://easylist.to/easylist/easylist.txt
fanboy https://easylist.to/easylist/fanboy-social.txt
fanboy_annoyance https://secure.fanboy.co.nz/fanboy-annoyance.txt
fr_annoyance https://easylist-downloads.adblockplus.org/liste_fr.txt
EOF
}

block_entries() {
    cat <<'EOF'
oisd https://big.oisd.nl/
doh https://raw.githubusercontent.com/oneoffdallas/dohservers/master/list.txt
adaway https://adaway.org/hosts.txt
pihole_disconad https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt
pihole_discontrack https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt
fademind https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts
pihole_stevenblack https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
sysctl http://sysctl.org/cameleon/hosts
NSO https://raw.githubusercontent.com/AmnestyTech/investigations/master/2021-07-18_nso/domains.txt
suspicous_low https://www.dshield.org/feeds/suspiciousdomains_Low.txt
suspicous_medium https://www.dshield.org/feeds/suspiciousdomains_Medium.txt
suspicous_high https://www.dshield.org/feeds/suspiciousdomains_High.txt
winhelp https://winhelp2002.mvps.org/hosts.txt
yoyo "https://pgl.yoyo.org/as/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext"
firebog_w3k https://v.firebog.net/hosts/static/w3kbl.txt
matomo https://raw.githubusercontent.com/matomo-org/referrer-spam-blacklist/master/spammers.txt
dawsey https://raw.githubusercontent.com/Dawsey21/Lists/master/main-blacklist.txt
vokins https://raw.githubusercontent.com/vokins/yhosts/master/hosts
EOF
}

if python3 -c 'import tld; tld.is_tld(".com")' >/dev/null 2>&1; then
    printf 'python3.tld %sOK%s\n' "$GD" "$RZ"
else
    python3 -m pip install --user tld
fi

transform_into_unbound_entries() {
    perl -pe 's/ *#.*$//g' |
        perl -ane 'if (/^\|?\|?([^#\^\*].+)\^?$/) { @l=split( /\s+/,$1);
    $h = lc(pop(@l));
    $h =~ s/\015//g;
    $h =~ s/^\s+|\s+$//g;
    if ($h=~ /^(?=.{1,255}$)[0-9\-_a-z](([\-_0-9a-z]|\b-){0,61}[\-_a0-9a-z])?(\.[\-_0-9a-z](([\-_0-9a-z]|\b-){0,61}[\-_a0-9a-z])?)*(\.|\^)?$/) {
        print "$h\n";
    } else {
        $h =~ /^\s*$/ or print STDERR "IGNORED: $h\n";
    }
  }' |
        python3 -c '(sys,tld)=(__import__("sys"), __import__("tld")); [ ( tld.get_tld(l.strip(), fix_protocol=True,fail_silently=True) and sys.stdout or sys.stderr).write(l) for l in sys.stdin.readlines() ] ' 2>/dev/null |
        while read -r h; do printf '   local-zone: "%s" always_null\n' "$h"; done
}

sudo touch "$EZLIST_FN"
sudo chmod 664 "$EZLIST_FN"
sudo tee "$EZLIST_FN" </dev/null >/dev/null

printf '\ngenerating lists from eazylist\n'
printf '==============================\n\n'

ezlist_entries >"$tmp_entries"
while IFS=' ' read -r K URL; do
    [ -n "$K" ] || continue
    printf '%s%-20s%s ' "$BL" "$K" "$RZ"
    if adblock_to_block_list "$URL" >"$tmp_work"; then
        printf '%sOK%s %7d entries\n' "$GD" "$RZ" "$(wc -l <"$tmp_work" | tr -d ' ')" >&2
    else
        printf '%sKO%s\n' "$RD" "$RZ" >&2
        curl -s -S "$URL" >&2
    fi
    # The input file is owned by this user; sudo only has to write the target.
    # shellcheck disable=SC2024
    sudo tee -a "$EZLIST_FN" <"$tmp_work" >/dev/null
done <"$tmp_entries"

sort -r <"$EZLIST_FN" | uniq >"$tmp_work"
# shellcheck disable=SC2024
sudo tee "$EZLIST_FN" <"$tmp_work" >/dev/null
printf 'Total                     %s%s%s entries (unique)\n' "$BL" "$(wc -l <"$EZLIST_FN" | tr -d ' ')" "$RZ"
printf '\n'

printf '\ngetting blocklists for unbound\n'
printf '==============================\n\n'

printf 'server:\n   harden-below-nxdomain:yes\n' >"$tmpfile"
: >"$tmp_sorted"

block_entries >"$tmp_entries"
while IFS=' ' read -r K URL; do
    [ -n "$K" ] || continue
    # Strip the optional quotes some entries use for URLs with '&'.
    URL=${URL%\"}
    URL=${URL#\"}
    printf '%s%-20s%s ' "$BL" "$K" "$RZ" >&2
    if curl -s "$URL" >"$tmp_work"; then
        printf '%sOK%s %7d entries\n' "$GD" "$RZ" "$(wc -l <"$tmp_work" | tr -d ' ')" >&2
    else
        printf '%sKO%s\n' "$RD" "$RZ" >&2
        curl -s -S "$URL" >&2
    fi
    transform_into_unbound_entries <"$tmp_work" >>"$tmp_sorted"
done <"$tmp_entries"

sort -r <"$tmp_sorted" | uniq >>"$tmpfile"

printf 'Total                    %s%s%s entries (unique)\n' "$BL" "$(wc -l <"$tmpfile" | tr -d ' ')" "$RZ"
printf '\n'

BACKUP="$unboundconf.$(date +%Y-%m-%dT%H:%M:%S)"
printf 'backup in  %s%s%s\n' "$BL" "$BACKUP" "$RZ"
if [ -e "$unboundconf" ]; then
    sudo cp -p "$unboundconf" "$BACKUP"
fi

printf 'installing %s%s%s\n' "$BL" "$unboundconf" "$RZ"
sudo cp "$tmpfile" "$unboundconf"
sudo chown root "$unboundconf"
sudo chmod 644 "$unboundconf"

printf '\nchecking unbound configuration '
if sudo unbound-checkconf >/dev/null; then
    printf '%sOK%s\n' "$GD" "$RZ"

    printf 'restarting unbound             '
    if command -v systemctl >/dev/null 2>&1; then
        if sudo systemctl restart unbound >/dev/null; then
            restart_ok=1
        else
            restart_ok=0
        fi
    elif [ -x /etc/init.d/unbound ]; then
        if sudo /etc/init.d/unbound restart >/dev/null; then
            restart_ok=1
        else
            restart_ok=0
        fi
    else
        restart_ok=0
    fi

    if [ "$restart_ok" -eq 1 ]; then
        printf '%sOK%s\n' "$GD" "$RZ"
    else
        printf '%sKO%s\n' "$RD" "$RZ"
    fi
else
    printf '%sKO%s\n' "$RD" "$RZ"
fi

exit 0
