---
title: "How to safely copy files to a flash drive on Linux"
date: 2026-05-17T08:28:50+00:00
tags: [ "linux", "usb", "storage" ]
categories: [ "guide" ]
---

If you copy files to a USB flash drive and remove it right after `cp` finishes, data may still be in the kernel write cache.

That means copy command is done, but device writes are not fully done yet.

The safe approach is simple:

1. Copy files
2. Force data to disk
3. Unmount device
4. Remove flash drive

### Basic safe flow
```bash
cp -r ./my-folder /mnt/usb/
sync
umount /mnt/usb
```

### Linux vs Windows write cache behavior
On Linux, if you run `umount` without `sync` first, `umount` may take a while.
That is normal: Linux flushes pending cached writes before it completes unmount.

On Windows, removable drives are usually configured for quick removal, so writes are flushed more aggressively.
Because of that, eject is often instant after copy is fully completed, and people often remove drives without manual eject.

### Copy with stronger write guarantees
If you want to reduce cache effects during writing, use tools that flush writes:

```bash
dd if=file.txt of=/mnt/usb/file.txt bs=4M oflag=dsync
```

```bash
rsync --fsync file.txt /mnt/usb/
```

`oflag=dsync` and `--fsync` make writes more explicit and safer for removable media workflows.

### Seeing sync progress
If you want visible sync progress (instead of waiting blindly), use this helper script:

- https://gist.github.com/merura/387c5fa55ecf5ede58412f7e0d114c04

It wraps `sync` and shows progress/ETA based on dirty pages, which is useful before unplugging a drive.

thanks @tsalkenov for help
