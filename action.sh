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

test_busybox() {
    for bb in \
        /data/adb/ksu/bin/busybox \
        /data/adb/magisk/busybox \
        /data/adb/ap/bin/busybox \
        busybox
    do
        if [ -x "$bb" ] && "$bb" true >/dev/null 2>&1; then
            echo "$bb"
            return
        fi
    done
}

ENV=$(detect_env)
BB=$(test_busybox)

if [ -z "$BB" ]; then
    BB=""
    ENV="$ENV (toybox)"
else
    export PATH="$(dirname $BB):$PATH"
fi

FSTRIM_BIN=$(command -v fstrim)

if [ -z "$FSTRIM_BIN" ]; then
    ui_print "fstrim não encontrado!"
    exit 1
fi

ui_print "FSTRIM action triggered"
ui_print "Environment: $ENV"
ui_print "BusyBox: ${BB:-none}"
ui_print "fstrim bin: $FSTRIM_BIN"

notify "Fstrim running ($ENV)"

echo "=== FSTRIM START $(date) ===" >> $LOG

PARTS="/data /metadata /cache /persist /mnt/vendor/persist /mnt/vendor/efs"

is_mounted() {
    if [ -n "$BB" ]; then
        $BB mountpoint -q "$1" 2>/dev/null
    else
        mount | grep -q "on $1 "
    fi
}

get_fs() {
    mount | grep "on $1 " | awk '{print $5}'
}

for m in $PARTS; do
    if is_mounted "$m"; then
        FS=$(get_fs "$m")

        ui_print "Partition: $m"
        ui_print "Filesystem: $FS"

        case "$FS" in
            f2fs|ext4)
                ui_print "Executing fstrim..."
                OUT=$($FSTRIM_BIN -v $m 2>&1)
                echo "[$m] $OUT" >> $LOG
                if echo "$OUT" | grep -qi "inappropriate ioctl"; then
                    ui_print "Result: not supported"
                else
                    ui_print "Result: $OUT"
                fi
            ;;
            *)
                ui_print "Skipped (unsupported fs)"
            ;;
        esac

        ui_print "Done: $m"
    else
        ui_print "Partition not mounted: $m"
    fi
done

echo "=== FSTRIM END $(date) ===" >> $LOG

ui_print "FSTRIM finished"
notify "Fstrim finished"
for m in $PARTS; do
    if $BB mountpoint -q $m; then
        FS=$($BB mount | $BB grep "on $m " | $BB awk '{print $5}')
        ui_print "Partition: $m"
        ui_print "Filesystem: $FS"
        ui_print "Executing fstrim..."

        OUT=$($BB fstrim -v $m 2>&1)
        echo "$OUT" >> $LOG

        if echo "$OUT" | $BB grep -q "Inappropriate ioctl"; then
            ui_print "Result: not supported"
        else
            ui_print "Result: $OUT"
        fi

        ui_print "Done: $m"
    else
        ui_print "Partition not mounted: $m"
    fi
done

echo "=== FSTRIM END $(date) ===" >> $LOG

ui_print "FSTRIM finished"
notify "Fstrim finished"
