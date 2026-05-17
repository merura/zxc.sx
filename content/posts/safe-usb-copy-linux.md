---
title: "How to safely copy files to USB flash drive on Linux"
date: 2026-05-17T13:28:33+05:00
tags: ["linux", "usb", "rsync"]
categories: ["guide"]
---

When you copy files to a flash drive on Linux, the copy command may finish before all data is physically written to the device.

This happens because Linux uses page cache. It's fast, but if you unplug the drive too early, you can lose data or damage the filesystem.

### Safe workflow

1. Copy files
2. Flush pending writes
3. Unmount the drive
4. Remove the drive

Example:

```bash
cp -r ./my-files /mnt/usb/
sync
umount /mnt/usb
```

### Better per-file options

If you want each file to be flushed when transfer finishes, use tools that support fsync-like behavior:

```bash
rsync --fsync -avh ./my-files/ /mnt/usb/my-files/
```

Or write directly with synchronized I/O:

```bash
dd if=./file.txt of=/mnt/usb/file.txt bs=4M oflag=dsync status=progress
```

### Seeing sync progress

Default `sync` gives no progress output. I use a small script for that:

- https://gist.github.com/merura/387c5fa55ecf5ede58412f7e0d114c04

It wraps `sync`, reads dirty memory counters, and prints an estimated progress/ETA so it's easier to know when writes are actually done.

thanks @tsalkenov for help
