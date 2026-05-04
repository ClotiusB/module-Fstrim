#!/system/bin/sh

ASH_STANDALONE=1

if [ -x /data/adb/ksu/bin/busybox ]; then
    BB=/data/adb/ksu/bin/busybox
    ENV="KernelSU"
elif [ -x /data/adb/magisk/busybox ]; then
    BB=/data/adb/magisk/busybox
    ENV="Magisk"
elif [ -x /data/adb/ap/bin/busybox ]; then
    BB=/data/adb/ap/bin/busybox
    ENV="APatch"
else
    BB=busybox
    ENV="Unknown"
fi

LOG=/data/local/tmp/fstrim.log

ui_print() {
    echo "$1"
    log -t FSTRIM "$1"
}

notify() {
    cmd notification post -S bigtext -t "FSTRIM" "fstrim_action" "$1" >/dev/null 2>&1
}

ui_print "FSTRIM action triggered"
ui_print "Environment: $ENV"
notify "Fstrim running ($ENV)"

echo "=== FSTRIM START $(date) ===" >> $LOG

PARTS="/data /metadata /cache /persist /mnt/vendor/persist /mnt/vendor/efs"

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
