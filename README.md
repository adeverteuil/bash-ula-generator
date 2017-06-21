# Bash ULA Generator
Generate an IPv6 Unique Local Address prefix

Alexandre de Verteuil <alexandre@deverteuil.net>  
2017-06-20

Based on scripts from **Shinsuke Suzuki** and **Holger Zuleger**, available under the `prior_art` directory.

## Usage

Simply run in a bash shell. You will be prompted for your physical MAC address (guessing "eth0" is no longer relevant in 2017).

## Requirements

`wget`, `ntpq`

## Improvements over other scripts

  - Not a CGI script
  - Computes the SHA1 hash of bytes, not their hex representation
  - Better text output

## References

 - [RFC 4193 — Unique Local IPv6 Unicast Addresses](https://tools.ietf.org/html/rfc4193)
 - [Unique local address](https://en.wikipedia.org/wiki/Unique_local_address) on Wikipedia
