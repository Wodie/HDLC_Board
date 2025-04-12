# HDLC_Board - HDLC v.24 Sync to/from Async Hardware.

This is the sourcecode for the Microchip PICs 15F887 or 16F884 for the v.24 board created by Juan Carlos.
This board converts Sync to Async HDLC and Async to Sync HDLC.
Quantar/DIU3000 needs to be the master clock (set them to internal clock).

Sync to Async buffer is not needed, it pass bytes inmediatelly.
Buffer from Async to Sync is limited to 120/112 bytes, but need testing.

Sync side is 9,600 bps.
Async side is 19,200 bps.

This software and hardware is licenced under the GPL v3. If you are using it, please let me know, I will be glad to know it.
