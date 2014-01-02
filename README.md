#### About

A small program (there is a C and an equivalent Perl implementation) to launch PHP FastCGI instances with `systemd` socket activation.
The `systemd` unit files use a template mechanism to drop privileges to the user specified in the template (see the `enable.pl` helper script).

This is really handy for running PHP in FastCGI mode with `lighttpd`, `nginx`, or even `apache`, communicating over a Unix domain socket.
It decouples the web server from PHP (and allows them to run as different users) for better security.
As a bonus, if PHP crashes (or you need to restart the PHP daemons for maintenance/configuration changes), `systemd` will buffer any incoming requests on the socket it manages.
It will then automatically restart the service (with the socket being passed to the PHP daemon --- that's all this program really does, everything else is handled by `systemd`).

#### Usage

This will, by default, compile the C implementation and install the binary to `/usr/bin/spawn-php-fcgi`.

```bash
make
sudo make install
```

To enable PHP FastCGI to run as users `john`, `jack`, and `jill`, run the following helper script.
```bash
sudo ./enable.pl john jack jill
```

The `systemd` controlled sockets will be created in: `/run/spawn-php-fcgi/`.

#### Additional Reading
Systemd socket activation:
http://0pointer.de/blog/projects/socket-activation.html

Includes documentation on `systemd` templates (amongst other things):
http://www.freedesktop.org/software/systemd/man/systemd.unit.html
