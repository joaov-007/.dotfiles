#!/usr/bin/env bash
# rate-mirrors.sh -- sort your pacman mirrors by REAL speed measured from your own connection.
#
#   ./rate-mirrors.sh              test + write /etc/pacman.d/mirrorlist + pacman -Syy
#   ./rate-mirrors.sh -n           dry run, print the new mirrorlist, change nothing
#   ./rate-mirrors.sh -l           only list the candidate mirrors, no download test
#   ./rate-mirrors.sh -a           test mirrors from every country (slower, more traffic)
#   ./rate-mirrors.sh -c Brazil,Chile -t 6
#   ./rate-mirrors.sh -r           restore the previous mirrorlist
#   ./rate-mirrors.sh -u           also run a full pacman -Syu afterwards
#
# Two-round test: cheap probe on every candidate, then a bigger sample on the
# finalists. ~15s total, ~30-50 MB of traffic, no packages required (curl + coreutils).

set -euo pipefail

MIRRORLIST=${MIRRORLIST:-/etc/pacman.d/mirrorlist}
CACHE=${CACHE:-$HOME/.cache/rate-mirrors}
ARCH=${ARCH:-$(uname -m)}
COUNTRIES=${COUNTRIES:-Brazil}   # local mirrors win, worldwide tier-1 added as backup
TOP=${TOP:-10}                   # how many mirrors to keep
JOBS=${JOBS:-12}                 # parallel tests
PROBE_TIMEOUT=${PROBE_TIMEOUT:-4}
FINAL_TIMEOUT=${FINAL_TIMEOUT:-8}
FINALISTS=${FINALISTS:-6}
ANYWHERE=0
DRYRUN=0
ONLYLIST=0
DORESTORE=0
DOUPDATE=0

BOLD=$'\033[1m'; DIM=$'\033[2m'; GRN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'; RST=$'\033[0m'
[ -t 1 ] || { BOLD='' DIM='' GRN='' YEL='' RED='' RST=''; }

die()  { printf '%s%s%s\n' "$RED" "$*" "$RST" >&2; exit 1; }
info() { printf '%s\n' "$*"; }
step() { printf '%s==>%s %s\n' "$BOLD" "$RST" "$*"; }

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while getopts ":nlat:c:ruh" opt; do
  case $opt in
    n) DRYRUN=1 ;;
    l) ONLYLIST=1 ;;
    a) ANYWHERE=1 ;;
    t) TOP=$OPTARG ;;
    c) COUNTRIES=$OPTARG ;;
    r) DORESTORE=1 ;;
    u) DOUPDATE=1 ;;
    h) usage ;;
    :) die "option -$OPTARG needs an argument" ;;
    *) die "unknown option -$OPTARG (try -h)" ;;
  esac
done

command -v curl >/dev/null || die "curl is required"
command -v xargs >/dev/null || die "xargs is required"

WORK=$(mktemp -d) || die "cannot create temp dir"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------- undo it

if [ "$DORESTORE" = 1 ]; then
  BACKUP=$CACHE/latest
  [ -e "$BACKUP" ] || BACKUP=$(ls -1t "$CACHE"/mirrorlist.* 2>/dev/null | head -1) || true
  [ -n "$BACKUP" ] && [ -f "$BACKUP" ] || die "no backup found in $CACHE"
  step "restoring $BACKUP"
  if [ "$DRYRUN" = 1 ]; then cat "$BACKUP"; exit 0; fi
  sudo install -m 644 "$BACKUP" "$MIRRORLIST"
  sudo pacman -Syy
  info "${GRN}restored.${RST}"
  exit 0
fi

# ---------------------------------------------------------------- candidate list

# Verified fallback list, used when archweb is unreachable.
fallback_mirrors() {
  cat <<'EOF'
https://mirror.ufscar.br/archlinux/
https://br.mirrors.cicku.me/archlinux/
https://archlinux.c3sl.ufpr.br/
https://mirrors.ic.unicamp.br/archlinux/
https://geo.mirror.pkgbuild.com/
https://mirror.rackspace.com/archlinux/
https://mirrors.ocf.berkeley.edu/archlinux/
https://mirror.dogado.de/archlinux/
https://ftp.fau.de/archlinux/
https://mirror.selfnet.de/archlinux/
EOF
}

# Ask archweb which mirrors are alive right now. Needs jq; without it (or without
# network) the built-in list above is used instead.
api_mirrors() {
  command -v jq >/dev/null || return 1
  curl -fsS --max-time 10 https://archlinux.org/mirrors/status/json/ \
    | jq -r '
        .urls[]
        | select(.active == true and .completion_pct == 1 and .protocol == "https")
        | select(.score != null and .delay != null)
        | "\(.score)\t\(.delay)\t\(.country)\t\(.url)"
      ' || return 1
}

# score<TAB>delay<TAB>country<TAB>url  ->  url, local first then best worldwide
pick_candidates() {
  local scored="$WORK/scored.tsv"
  if ! api_mirrors >"$scored" || [ ! -s "$scored" ]; then
    info "${DIM}archweb unreachable, using the built-in mirror list${RST}"
    fallback_mirrors
    return
  fi

  local want="," country
  for country in ${COUNTRIES//,/ }; do want="$want$country,"; done

  awk -F'\t' -v want="$want" -v anywhere="$ANYWHERE" '
    { local = index(want, "," $3 ",") > 0
      if (anywhere == 1)      print (local ? 0 : 1) "\t" $1 "\t" $4
      else if (local)         print 0 "\t" $1 "\t" $4
      else                    print 1 "\t" $1 "\t" $4 }
  ' "$scored" \
    | sort -t$'\t' -k1,1n -k2,2n \
    | cut -f3 \
    | awk '!seen[$0]++' \
    | { if [ "$ANYWHERE" = 1 ]; then head -40; else head -14; fi; }
}

# ---------------------------------------------------------------------- the test

# One mirror -> "speed_bytes_per_second<TAB>url". 0 speed means unusable.
probe() {
  local url=$1 secs=$2 bytes=$3 out code
  out=$(curl -fsS -o /dev/null --max-time "$secs" -r "0-$bytes" \
        -w '%{speed_download} %{http_code}' \
        "${url}core/os/${ARCH}/core.db" 2>/dev/null) || out="0 000"
  code=${out##* }
  case $code in
    200|206) printf '%s\t%s\n' "${out%% *}" "$url" ;;
    *)       printf '0\t%s\n' "$url" ;;
  esac
}
export -f probe
export ARCH

probe_all() {  # file, timeout, bytes, jobs
  xargs -P "$JOBS" -n 1 -I@ bash -c 'probe "$1" "$2" "$3"' _ @ "$2" "$3" \
    <"$1" >"$1.res" 2>/dev/null || true
}

# The mirror you are using right now, so the report can show the gain.
current_mirror() {
  grep -m1 -E '^[[:space:]]*Server[[:space:]]*=' "$MIRRORLIST" 2>/dev/null \
    | sed -E 's@^.*= *(.+)/\$repo/os/\$arch/?[[:space:]]*$@\1/@'
}

format_speed() {
  awk -v b="$1" 'BEGIN {
    if (b <= 0)      { print "  dead"; exit }
    if (b < 1048576) { printf "%6.0f KB/s\n", b/1024; exit }
                      printf "%6.1f MB/s\n", b/1048576 }'
}

# ------------------------------------------------------------------------- report

CANDIDATES=$WORK/candidates
: >"$CANDIDATES"
pick_candidates >>"$CANDIDATES"

[ -s "$CANDIDATES" ] || die "no candidate mirrors found"

info "${DIM}$(wc -l <"$CANDIDATES") candidates | $JOBS parallel tests | arch $ARCH | keeping top $TOP${RST}"
info ""

if [ "$ONLYLIST" = 1 ]; then
  nl -ba "$CANDIDATES"
  exit 0
fi

# round 1 -- cheap probe of everybody
step "probing $(wc -l <"$CANDIDATES") mirrors..."
probe_all "$CANDIDATES" "$PROBE_TIMEOUT" 1048575
sort -t$'\t' -k1,1nr "$CANDIDATES.res" >"$CANDIDATES.sorted" 2>/dev/null || true
[ -s "$CANDIDATES.sorted" ] || die "no mirror answered the probe (offline?)"

FINALISTS=$(head -n "$FINALISTS" "$CANDIDATES.sorted" | cut -f2)
CUR=$(current_mirror)
if [ -n "$CUR" ] && ! grep -qxF "$CUR" <<<"$FINALISTS"; then
  FINALISTS="$FINALISTS
$CUR"
fi

# round 2 -- bigger sample on the survivors, to get the order right
step "measuring $(wc -l <<<"$FINALISTS") finalists (${FINAL_TIMEOUT}s each)..."
printf '%s\n' "$FINALISTS" >"$WORK/final"
probe_all "$WORK/final" "$FINAL_TIMEOUT" 8388607
sort -t$'\t' -k1,1nr "$WORK/final.res" >"$WORK/ranked" 2>/dev/null || true
[ -s "$WORK/ranked" ] || die "final measurement failed"

# never write a dead mirror into the mirrorlist
awk -F'\t' '$1 > 0' "$WORK/ranked" >"$WORK/ranked.live"
[ -s "$WORK/ranked.live" ] || {
  info "${RED}every candidate mirror failed the test, keeping your current mirrorlist${RST}"
  exit 1
}

BEST=$(head -1 "$WORK/ranked.live" | cut -f1)
if [ -n "$CUR" ]; then
  CUR_SPEED=$(awk -F'\t' -v u="$CUR" '$2==u {print $1}' "$WORK/ranked.live")
  if [ -n "$CUR_SPEED" ]; then
    info ""
    info "  current first mirror: ${DIM}${CUR}${RST}  $(format_speed "$CUR_SPEED")"
    info "  new best mirror:      ${GRN}$(head -1 "$WORK/ranked" | cut -f2)${RST}  $(format_speed "$BEST")"
    if [ "$CUR_SPEED" -gt 0 ] 2>/dev/null; then
      awk -v a="$CUR_SPEED" -v b="$BEST" 'BEGIN {
        if (b > a) printf "  -> %dx faster\n", b/a
        else        printf "  -> same ballpark, no gain\n" }'
    fi
  fi
fi

# ------------------------------------------------------------------ build the file

OUT=$WORK/mirrorlist.new
{
  echo "##"
  echo "## Arch Linux mirrorlist -- ordered by measured speed from this machine"
  echo "## Generated by rate-mirrors.sh on $(date '+%Y-%m-%d %H:%M')"
  echo "## Countries: $COUNTRIES | top $TOP of $(wc -l <"$WORK/ranked.live") tested mirrors"
  echo "## Restore with: sudo cp -v $CACHE/mirrorlist.* $MIRRORLIST"
  echo "##"
  head -n "$TOP" "$WORK/ranked.live" | while IFS=$'\t' read -r speed url; do
    printf 'Server = %s$repo/os/$arch\n' "$url"
  done
  echo ""
} >"$OUT"

info ""
info "${BOLD}new mirrorlist${RST}"
info "${DIM}speed      mirror${RST}"
head -n "$TOP" "$WORK/ranked.live" | nl -w2 -s'. ' | while read -r _ speed url; do
  printf '  %s  %s\n' "$(format_speed "$speed")" "$url"
done
info ""

if [ "$DRYRUN" = 1 ]; then
  info "${YEL}dry run, nothing changed.${RST} New file would be:"
  info ""
  cat "$OUT"
  exit 0
fi

# ---------------------------------------------------------------------- apply it

mkdir -p "$CACHE"
STAMP=$(date '+%Y%m%d-%H%M%S')
if [ -f "$MIRRORLIST" ]; then
  sudo cp -v "$MIRRORLIST" "$CACHE/mirrorlist.$STAMP"
  ln -sfn "$CACHE/mirrorlist.$STAMP" "$CACHE/latest" 2>/dev/null || true
fi
sudo install -m 644 "$OUT" "$MIRRORLIST"

step "mirrorlist updated (backup: $CACHE/mirrorlist.$STAMP)"
sudo pacman -Syy

if [ "$DOUPDATE" = 1 ]; then
  step "running full upgrade"
  sudo pacman -Syu
fi

info ""
info "${GRN}done.${RST} undo with: ${BOLD}$0 -r${RST}"
