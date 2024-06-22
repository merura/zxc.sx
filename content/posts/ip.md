---
title: "How go get my public IP address"
date: 2024-06-22T18:44:24+05:00
categories: [ "guide" ]
---

There are several pretty good websites that can tell you your IP address.
- [ident.me](https://ident.me/)
- [ip.zxc.sx](https://ip.zxc.sx/)
- [ifconfig.me](https://ifconfig.me/)
- [icanhazip.com](https://icanhazip.com/)
- [ipinfo.io](https://ipinfo.io/)
- [2ip.ru](https://2ip.ru/)

You can open them in a browser or use the terminal to get your IP address.
```bash
curl ident.me
```
```bash
curl ip.zxc.sx
```
```bash
curl ifconfig.me
```
```bash
curl icanhazip.com
```
```bash
curl ipinfo.io
```
```bash
curl 2ip.ru
```

If you don't have a curl installed, you can use wget.
```bash
wget -qO- ident.me
```
```bash
wget -qO- ip.zxc.sx
```
```bash
wget -qO- ifconfig.me
```
```bash
wget -qO- icanhazip.com
```
```bash
wget -qO- ipinfo.io
```
> Note that 2ip.ru doesn't support wget.

If you don't have anything rather than shell (sh, bash) and awk, you can use the following command.
```bash
(exec 3<>/dev/tcp/ident.me/80; echo -e "GET / HTTP/1.0\nHost: ident.me\n" >&3; awk 'NR>1 { print }' RS='\r\n\r\n' <&3)
```
```bash
(exec 3<>/dev/tcp/ip.zxc.sx/80; echo -e "GET / HTTP/1.0\nHost: ip.zxc.sx\n" >&3; awk 'NR>1 { print }' RS='\r\n\r\n' <&3)
```
```bash
(exec 3<>/dev/tcp/ifconfig.me/80; echo -e "GET / HTTP/1.0\nHost: ifconfig.me\n" >&3; awk 'NR>1 { print }' RS='\r\n\r\n' <&3)
```
```bash
(exec 3<>/dev/tcp/icanhazip.com/80; echo -e "GET / HTTP/1.0\nHost: icanhazip.com\n" >&3; awk 'NR>1 { print }' RS='\r\n\r\n' <&3)
```
```bash
(exec 3<>/dev/tcp/ipinfo.io/80; echo -e "GET / HTTP/1.0\nHost: ipinfo.io\n" >&3; awk 'NR>1 { print }' RS='\r\n\r\n' <&3)
```
> Note that 2ip.ru doesn't support this method.

If you have ONLY shell, you can use the following command.
```bash
(exec 3<>/dev/tcp/ident.me/80; echo -e "GET / HTTP/1.0\nHost: ident.me\n" >&3; cat <&3)
```
```bash
(exec 3<>/dev/tcp/ip.zxc.sx/80; echo -e "GET / HTTP/1.0\nHost: ip.zxc.sx\n" >&3; cat <&3)
```
```bash
(exec 3<>/dev/tcp/ifconfig.me/80; echo -e "GET / HTTP/1.0\nHost: ifconfig.me\n" >&3; cat <&3)
```
```bash
(exec 3<>/dev/tcp/icanhazip.com/80; echo -e "GET / HTTP/1.0\nHost: icanhazip.com\n" >&3; cat <&3)
```
```bash
(exec 3<>/dev/tcp/ipinfo.io/80; echo -e "GET / HTTP/1.0\nHost: ipinfo.io\n" >&3; cat <&3)
```
> Note that 2ip.ru doesn't support this method.

Just by the way, here is the source code of the ip.zxc.sx.
```php
<?php
header("Content-Type: text/plain");
if (isset($_SERVER['HTTP_CF_CONNECTING_IP'])) {
    $client_ip = $_SERVER['HTTP_CF_CONNECTING_IP'];
} else {
    $client_ip = $_SERVER['REMOTE_ADDR'];
}
echo $client_ip . "\n";
?>
```
