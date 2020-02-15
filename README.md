# Bash ULA Generator
Generate an IPv6 Unique Local Address prefix

Timothe Litt <litt@acm.org> - bugfixes and simplified usage
2020-02-03

Alexandre de Verteuil <alexandre@deverteuil.net>  
2017-06-20

Based on scripts from **Shinsuke Suzuki** and **Holger Zuleger**, available under the `prior_art` directory.

## Usage

Simply run in a bash shell.  For additional options, use `-h`

## Requirements

`wget`, `cut`, `tr`, `sed`, `grep`, `tail`, `head`, `sort`, `which`

## Optional

`ntpq`, `ntpdate`, `ip`, `ifconfig`

## Improvements over other scripts

  - Not a CGI script
  - Computes the SHA1 hash of bytes, not their hex representation
  - Better text output

## References

 - [RFC 4193 — Unique Local IPv6 Unicast Addresses](https://tools.ietf.org/html/rfc4193)
 - [RFC 3513 - Internet Protocol Version 6 (IPv6) Addressing Architecture](https://tools.ietf.org/html/rfc3513)
 - [Unique local address](https://en.wikipedia.org/wiki/Unique_local_address) on Wikipedia
