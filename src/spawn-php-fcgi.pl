#!/usr/bin/perl
use strict;
use warnings;

use Errno qw/:POSIX/;
use Fcntl;

use constant FCGI_LISTENSOCK_FILENO => 0;
use constant SD_LISTEN_FDS_START => 3;

# Based on systemd implementation (src/libsystemd-daemon/sd-daemon.c)
sub sd_listen_fds {
  my $ret;
  my @sd_fhs = ();

  my $listen_pid = $ENV{'LISTEN_PID'};
  if (!defined $listen_pid) {
    $ret = 0;
    goto finish;
  }
  if ($listen_pid <= 0) {
    $ret = -&Errno::EINVAL;
    goto finish;
  }

  if ($listen_pid != $$) {
    # Not for us.
    $ret = 0;
    goto finish;
  }

  my $num_fds = $ENV{'LISTEN_FDS'};
  if (!defined $num_fds) {
    $ret = 0;
    goto finish;
  }

  for (my $fd = SD_LISTEN_FDS_START; $fd < (SD_LISTEN_FDS_START + $num_fds); $fd++) {
    open(my $sd_fh, "+<&=", $fd);  # Alias the fd.

    my $flags;

    if (!($flags = fcntl($sd_fh, F_GETFD, 0))) {
      $ret = -$!;
      goto finish;
    }

    if (!($flags & FD_CLOEXEC)) {
      if (!fcntl($sd_fh, F_SETFD, $flags | FD_CLOEXEC)) {
        $ret = -$!;
        goto finish;
      }
    }

    push(@sd_fhs, $sd_fh);
  }

  $ret = $num_fds;

finish:
  delete $ENV{'LISTEN_PID'};
  delete $ENV{'LISTEN_FDS'};
  return ($ret, \@sd_fhs);
}

# Main.
my $num_children;
if (scalar @ARGV > 0) {
  $num_children = $ARGV[0];
  if ($num_children <= 0) {
    die "spawn-php-fcgi: invalid number of children";
  }
} else {
  $num_children = 0;
}

my ($ret, $sd_fhs_ref) = &sd_listen_fds();
if ($ret < 0) {
  $! = -$ret;
  die "spawn-php-fcgi: error receiving file descriptors: $!";
}
if ($ret != 1) {
  die "spawn-php-fcgi: no or too many file descriptors received";
}

if ($num_children >= 0) {
  $ENV{'PHP_FCGI_CHILDREN'} = $num_children;
}

for my $sd_fh (@{$sd_fhs_ref}) {
  # Alias the file descriptor used for bidirectional FCGI communication (same as STDIN).
  open(my $fcgi_fh, "+<&=", FCGI_LISTENSOCK_FILENO);
  # Dup the systemd file descriptor.
  open($fcgi_fh, "+<&", $sd_fh) or die "Can't dup systemd fd: $!";
  # Can now close the systemd file descriptor (it would also be closed by exec() since we set FD_CLOEXEC).
  close($sd_fh);
}

exec("php-cgi");

die "spawn-php-fcgi: exec failed: $!";
