---
title: "How to measure network stability"
date: 2026-07-17T00:00:00+05:00
tags: [ "networking", "ping", "packet-loss" ]
categories: [ "guide" ]
---

Speed tests tell you almost nothing about why your calls freeze or your games rubber-band. A connection can do 300 Mbps download and still be unusable if it drops packets every few minutes. What you actually need to see is **stability over time**: ping, jitter, and packet loss logged continuously, not a single snapshot.

### The tool: pingpackettest.com

[pingpackettest.com](http://pingpackettest.com/) is a free, continuous connection monitor built for exactly this. Instead of one-off speed measurements, it sends small probe packets to test servers near major gaming datacenters at a steady interval and plots the result live:

- **Ping (latency)** — round-trip time to the server.
- **Jitter** — how much that latency varies packet to packet; high jitter is what causes stutter and choppy audio even when average ping looks fine.
- **Packet loss** — probes that never came back at all. Any nonzero loss means something on the path is dropping traffic.

You pick a game or a generic testing tier (it has profiles for 800+ games, each using that game's real tick rate and packet size), pick a server, and let it run in the background while you work, play, or do nothing. When you're done, export the results — as a PNG chart for a quick look, or as a **CSV with 100ms-resolution timestamps** for real analysis. The CSV is the useful part: `Timestamp, Ping (ms), Jitter (ms)`, with dropped probes marked `PACKET_LOSS`.

### Why the CSV matters more than the live chart

The live chart is fine for a quick eyeball check, but it can't tell you things like "how many outages over 20 seconds did I have last night" or "did loss cluster around a specific time." For that you need to load the CSV somewhere and actually crunch it — count consecutive loss rows, group them into discrete drop events, and sort by duration.

That's a spreadsheet exercise nobody wants to do by hand for a 10,000-row file, so I built a small analyzer for it.

### [Ping Log Analyzer](/ping-analyzer/)

Drop a pingpackettest.com CSV into **[zxc.sx/ping-analyzer](/ping-analyzer/)** and it will, entirely in your browser (nothing is uploaded anywhere):

- Parse timestamp/ping/jitter columns automatically.
- Group consecutive lost packets into discrete **drop events** with start time, end time, and duration.
- Chart latency over time, where gaps in the line are packet loss.
- Chart loss density in 10-second windows, so you can spot clustering (e.g. loss every night around the same time — a strong hint it's your ISP's maintenance window, not your router).
- Give you summary stats: total loss %, number of drop events, how many were "major" (≥1s), total time spent offline, and average/max ping.

### Reading a real example

I ran an 18-minute test and fed the CSV into the analyzer. The summary:

- **10,772** samples over **~18 minutes**
- **14.4%** overall packet loss
- **69** distinct drop events, **8** of them ≥1s
- **148.6s** total time with no connectivity at all
- Average ping **187ms**, spiking to **1000ms** (timeout ceiling) right before drops

The events table is where it gets interesting — sorted by duration, the top of the list showed:

| Start | End | Duration | Packets lost |
|---|---|---|---|
| 01:58:13 | 01:59:09 | 56.7s | 568 |
| 02:03:35 | 02:04:04 | 29.4s | 295 |
| 01:53:31 | 01:53:53 | 21.3s | 214 |
| 01:53:01 | 01:53:17 | 15.9s | 160 |

Three separate outages over 20 seconds, one nearly a full minute — that's not jitter or a noisy line, that's the connection **fully disappearing**, repeatedly. Anything under ~0.3s in the table is a single-packet blip and usually not worth worrying about; anything running several seconds or longer is a real outage worth taking to your ISP.

### How to use it yourself

1. Run a test at [pingpackettest.com](http://pingpackettest.com/) for as long as you need (an hour or two overnight is a good way to catch intermittent issues).
2. Export the CSV.
3. Drop it into [zxc.sx/ping-analyzer](/ping-analyzer/).
4. Look at the drop-events table first — that's your evidence. Long, repeated outages (not just high average ping) are what actually justify an ISP support ticket, and the exported chart plus the table gives them a timestamped log they can't argue with.
