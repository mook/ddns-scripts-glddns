# glddns

This is a openwrt-style DDNS script for GL.iNet's glddns.com service.

## Details

Per [Forum post](https://forum.gl-inet.com/t/script-use-glddns-behind-another-router-testing/39747/14),
GLDDNS uses `http://ddns.glddns.com/update?hostname=&myip=` with HTTP auth, where
the user name is the mac (in hex, without `:`), and the password is the device
serial number.  `hostname` is the DDNS element in `/proc/gl-hw-info`, which can
be found on a sticker on the device.  `myip` is, of course, the IP address to
store.  From experimentation, it appears that this server also accept HTTPS.

Examining the [GL.iNet source](https://github.com/gl-inet/gl-feeds/tree/v4.8_e5800_ko/gl-sdk4-hw-info/src)
shows that all of the fields can be found in flash (ubi, mmc, or mtd).  The
offsets into the flash block is coded within the device tree; this would not be
available in an upstream OpenWRT build, so it must be hard-coded into the script.
In the case of mtd, a name is given and we must look up the correct block device
based on the name.

Examining that source also shows that there is a certificate that is store in
Flash; it is unclear at this point how this is used, but presumably as a client
certificate.  My current device does not have this, so it cannot be tested.
