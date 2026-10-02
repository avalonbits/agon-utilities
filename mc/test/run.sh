#!/bin/bash
# The 12AM Commander under hub, on the full emulator (SDL's dummy video, so
# the VDP's own firmware runs and answers the mode query display_init waits
# for). The commander is built with test/script.c, which takes its keys and
# typed lines from /mckeys.txt and writes /mcstate.txt as it quits; test/
# marker.c is the external program it runs, which leaves /m_<arg>.txt.
#
# Needs agondev (AGONDEV, default ~/agondev), hub (HUB_BIN, default hub's
# own build at ~/code/devel/build/hub.bin) and the emulator (AGON_EMU,
# default ~/fab-agon-emulator-1.2.4).
set -uo pipefail
cd "$(dirname "$0")/.."

AGONDEV=${AGONDEV:-$HOME/agondev}
HUB_BIN=${HUB_BIN:-$HOME/code/devel/build/hub.bin}
EMU=${AGON_EMU:-$HOME/fab-agon-emulator-1.2.4}
export PATH="$AGONDEV/bin:$PATH"

status=0
check() {
    if [ "$2" = "$3" ]; then
        echo "PASS  $1"
    else
        echo "FAIL  $1"
        echo "      got:  $2"
        echo "      want: $3"
        status=1
    fi
}

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT

# The scripted commander and the marker, each as an agondev project of its
# own, so the real build is left as it is.
mkdir -p "$W/mc/src" "$W/marker/src"
cp src/*.c src/*.h test/script.c test/script.h "$W/mc/src/"
cat > "$W/mc/Makefile" <<MK
NAME=mc
include \$(shell agondev-config --makefile)
CFLAGS += -DMC_SCRIPT -I$PWD/hub/include
PROJECTLIBDIR := $PWD/hub/lib
LIBS := -lhub
MK
cp test/marker.c "$W/marker/src/"
printf 'NAME=marker\ninclude $(shell agondev-config --makefile)\n' > "$W/marker/Makefile"
(cd "$W/mc" && make >/dev/null 2>&1) && (cd "$W/marker" && make >/dev/null 2>&1) \
    || { echo "FAIL  build"; exit 1; }

# boot <autoexec> <keys> [<hub script>]: run a card until the commander
# quits (or a minute passes), and leave it in $card. With WAIT_FOR set, until
# that file appears instead, and two seconds more.
boot() {
    local fifo hold emu i
    card=$(mktemp -d -p "$W")
    mkdir -p "$card/bin"
    cp -r "$EMU/sdcard/mos" "$card/"
    cp "$EMU/sdcard/MOS.bin" "$EMU/sdcard/firmware.bin" "$card/"
    cp "$HUB_BIN" "$card/mos/hub.bin"
    cp "$W/mc/bin/mc.bin" "$W/marker/bin/marker.bin" "$card/bin/"
    printf 'mode 3\r\n' > "$card/bin/12amc.cfg"
    printf "$1" > "$card/autoexec.txt"
    printf "$2" > "$card/mckeys.txt"
    [ -n "${3:-}" ] && printf "$3" > "$card/script.txt"

    fifo=$(mktemp -u -p "$W")
    mkfifo "$fifo"
    tail -f /dev/null > "$fifo" & hold=$!
    (cd "$EMU" && exec env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
        SDL_AUDIO_DRIVER=dummy ./fab-agon-emulator -u --sdcard "$card" \
        < "$fifo" > /dev/null 2>&1) & emu=$!
    for ((i = 0; i < 120; i++)); do
        [ -s "$card/${WAIT_FOR:-mcstate.txt}" ] && break
        sleep 0.5
    done
    sleep 0.5
    [ -n "${WAIT_FOR:-}" ] && sleep 2
    kill "$emu" "$hold" 2>/dev/null
    wait "$emu" "$hold" 2>/dev/null
}

has_file() { [ -s "$card/$1" ] && tr -d '\r' < "$card/$1" || echo "no $1"; }

# --- under hub ---------------------------------------------------------------
# Typed at the commander: "marker one" runs through hub, which brings the
# commander back with its directories; Tab picks the right-hand one; a
# command longer than hub takes is refused, and the commander carries on;
# "/bin/marker.bin two", by its path, runs too, and the commander comes back
# with the right-hand directory still picked; F10 quits. No hub frame is
# left open: the commander turned the long command down before asking hub.
long="marker $(printf 'x%.0s' $(seq 1 95))"
boot 'hub -f /script.txt\r\n' \
     "ch 109\r\nline marker one\r\nvk 142\r\nch 109\r\nline $long\r\nch 32\r\nch 109\r\nline /bin/marker.bin two\r\nvk 168\r\n" \
     'Set Hub$NoPause 1\r\nmc /bin /mos\r\n'
check "under hub, an external command runs, and the commander comes back" \
      "$(has_file m_one.txt)" "one"
check "  one given by its path too" "$(has_file m_two.txt)" "two"
check "  a command too long for hub is refused" \
      "$(ls "$card" | grep -c '^m_x')" 0
check "  and the commander keeps its directories and side across runs" \
      "$(has_file mcstate.txt)" "left /bin right /mos which 2 depth 0"

# A command typed at the commander pauses after it (HUB_PAUSE_AFTER): without
# Hub$NoPause, hub waits for a key that never comes, so the commander isn't
# back two seconds after the command ran.
WAIT_FOR=m_one.txt boot 'hub -f /script.txt\r\n' \
     "ch 109\r\nline marker one\r\nvk 168\r\n" 'mc /bin /mos\r\n'
check "a typed command pauses after it, under hub" \
      "$(has_file m_one.txt) / $(has_file mcstate.txt)" "one / no mcstate.txt"

# --- without hub -------------------------------------------------------------
# The commander says an external command needs hub, waits for a key, and
# carries on -- Tab picks the right-hand directory -- and nothing runs.
boot 'mc /bin /mos\r\n' \
     "ch 109\r\nline marker three\r\nch 32\r\nvk 142\r\nvk 168\r\n"
check "without hub, an external command doesn't run" "$(has_file m_three.txt)" "no m_three.txt"
check "  and the commander carries on" "$(has_file mcstate.txt)" "left /bin right /mos which 2 depth 0"

exit $status
