# glddns

This is a openwrt-style DDNS script for GL.iNet's glddns.com service.

## Usage

1. Download the `ipk` file from the [latest release].
2. Install the `ipk` file in OpenWRT.
   1. Go to your OpenWRT device's System -> [Software] page.
   2. Select the _Upload Package..._ button.
   3. Click on the _Browse..._ button.
   4. Select the file downloaded in step 1.
   5. Confirm the install as needed.
   6. Also ensure `luci-app-ddns` is installed from the normal feeds.
3. Set up DDNS.
   1. Go to your OpenWRT device's Services -> [Dynamic DNS] page.
   2. Click on _Edit_ of an IPv4 entry.
   3. Enter the required information:

      Section | Entry | Value | Notes
      --- | --- | --- | ---
      Basic Settings | Lookup Hostname | `foo.glddns.com` | The prefix (`foo`) should be on a sticker on your router.
      &zwnj; | DDNS Service provider | `glddns.com`
      &zwnj; | Domain | | Any value will work; it will be ignored.
      &zwnj; | Username | | Any value will work; it will be ignored.
      &zwnj; | Password | | Any value will work; it will be ignored.
      Advanced Settings | DNS-Server | `ns1.glddns.com` | Optional.

[latest release]: https://github.com/mook/ddns-scripts-glddns/releases/latest
[Software]: http://router/cgi-bin/luci/admin/system/package-manager
[Dynamic DNS]: http://router/cgi-bin/luci/admin/services/ddns

## Details

Per [Forum post], GLDDNS uses `http://ddns.glddns.com/update?hostname=&myip=`
with HTTP auth, where the user name is the mac (in hex, without `:`), and the
password is the device serial number.  `hostname` is the DDNS element in
`/proc/gl-hw-info`, which can be found on a sticker on the device.  `myip` is,
of course, the IP address to store.  From experimentation, it appears that this
server also accept HTTPS.

Examining the [GL.iNet source] shows that all of the fields can be found in
flash (ubi, mmc, or mtd).  The offsets into the flash block is coded within the
device tree; this would not be available in an upstream OpenWRT build, so it
must be hard-coded into the script.  In the case of mtd, a name is given and we
must look up the correct block device based on the name.

Examining that source also shows that there is a certificate that is store in
Flash; it is unclear at this point how this is used, but presumably as a client
certificate.  My current device does not have this, so it cannot be tested.

[Forum post]: https://forum.gl-inet.com/t/script-use-glddns-behind-another-router-testing/39747/14
[GL.iNet source]: https://github.com/gl-inet/gl-feeds/tree/v4.8_e5800_ko/gl-sdk4-hw-info/src

## Support Policy

Feel free to file issues, but response is not guaranteed; while this seems to
work on my device, unless I obtain other devices everything is just based on
guesswork.  Action is slightly more likely if there is concrete information I
could use to fix things, but even that has slim chances.

I don't _think_ this is likely to cause damage, but if it happens you're solely
responsible for dealing with it.
