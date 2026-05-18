#!/system/bin/sh
ASH_STANDALONE=1

LOG=/data/local/tmp/fstrim.log

ui_print() {
    echo "$1"
    log -t FSTRIM "$1"
}

notify() {
    cmd notification post -S bigtext -t "FSTRIM" "fstrim_action" "$1" >/dev/null 2>&1
}

detect_env() {
    if getprop | grep -qi magisk; then
        echo "Magisk"
    elif [ -d /data/adb/ksu ] && ps -A | grep -q ksu; then
        echo "KernelSU"
    elif [ -d /data/adb/ap ] && ps -A | grep -q apd; then
        echo "APatch"
    else
        echo "Unknown"
    fi
}

find_busybox() {
    for bb in \
        /data/adb/modules/brutal_busybox/bin/busybox \
        /data/adb/ksu/bin/busybox \
        /data/adb/magisk/busybox \
        /data/adb/ap/bin/busybox \
        /system/bin/busybox \
        busybox
    do
        if [ -x "$bb" ] && "$bb" true >/dev/null 2>&1; then
            echo "$bb"
            return
        fi
    done
}

ENV=$(detect_env)
BB=$(find_busybox)

if [ -n "$BB" ]; then
    export PATH="$(dirname "$BB"):$PATH"
    BB_CMD="$BB"
else
    BB_CMD=""
    ENV="$ENV (toybox)"
fi

bb_exec() {
    if [ -n "$BB_CMD" ]; then
        "$BB_CMD" "$@"
    else
        "$@"
    fi
}

FSTRIM_BIN=$(command -v fstrim)

if [ -z "$FSTRIM_BIN" ]; then
    ui_print "fstrim not found!"
    exit 1
fi

ui_print "=========================="
ui_print "FSTRIM action triggered"
ui_print "Environment: $ENV"
ui_print "BusyBox: ${BB:-none}"
ui_print "fstrim bin: $FSTRIM_BIN"
ui_print "=========================="

notify "Fstrim running ($ENV)"

echo "=== FSTRIM START $(date) ===" >> "$LOG"

CANDIDATES="
/
/data
/cache
/metadata
/persist
/product
/system
/system_ext
/vendor
/odm
/mnt/vendor/persist
/mnt/vendor/efs
"

MOUNTED=""
NOT_MOUNTED=""

is_mounted() {
    if [ -n "$BB_CMD" ]; then
        "$BB_CMD" mountpoint -q "$1" 2>/dev/null
    else
        mount | grep -q "on $1 "
    fi
}

get_fs() {
    mount | grep "on $1 " | awk '{print $5}'
}

for p in $CANDIDATES; do
    if is_mounted "$p"; then
        MOUNTED="$MOUNTED $p"
    else
        NOT_MOUNTED="$NOT_MOUNTED $p"
    fi
done

ui_print "Mounted partitions:"
for p in $MOUNTED; do
    FS=$(get_fs "$p")
    ui_print "  $p [$FS]"
done

ui_print "--------------------------"

ui_print "Not mounted partitions:"
for p in $NOT_MOUNTED; do
    ui_print "  $p"
done

ui_print "--------------------------"

for m in $MOUNTED; do
    FS=$(get_fs "$m")

    case "$FS" in
        f2fs|ext4)
            ui_print "Executing fstrim on $m..."

            if [ -n "$BB_CMD" ] && "$BB_CMD" --list 2>/dev/null | grep -q "^fstrim$"; then
                OUT=$("$BB_CMD" fstrim -v "$m" 2>&1)
            else
                OUT=$("$FSTRIM_BIN" -v "$m" 2>&1)
            fi

            echo "[$m] $OUT" >> "$LOG"

            if echo "$OUT" | grep -qi "inappropriate ioctl"; then
                ui_print "Result: not supported"
            else
                ui_print "Result: $OUT"
            fi
        ;;
        *)
            ui_print "Skipped $m (unsupported fs: $FS)"
        ;;
    esac

    ui_print "Done: $m"
    ui_print "--------------------------"
done

echo "=== FSTRIM END $(date) ===" >> "$LOG"

ui_print "FSTRIM finished"
notify "Fstrim finished"
