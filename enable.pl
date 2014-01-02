#!/usr/bin/perl
use strict;
use warnings;

my @users = @ARGV;

for my $user (@users) {
  print "Enabling for user: $user\n";

  # Stopping.
  &run_command("systemctl", "stop", "spawn-php-fcgi\@$user.socket");
  &run_command("systemctl", "stop", "spawn-php-fcgi\@$user.service");

  # Reload in case of changes to unit files.
  &run_command("systemctl", "daemon-reload");

  # Enabling.
  &run_command("systemctl", "enable", "spawn-php-fcgi\@$user.socket");
  &run_command("systemctl", "enable", "spawn-php-fcgi\@$user.service");

  # Initializing.
  &run_command("systemctl", "start", "spawn-php-fcgi\@$user.socket");
  &run_command("systemctl", "start", "spawn-php-fcgi\@$user.service");
}

sub run_command {
  my ($cmd, @args) = @_;

  print "Executing command...\n";
  print "$cmd @args\n";

  my $ret;
  if (($ret = system($cmd, @args)) < 0) {
    die "Error executing command: $!";
  }

  if ($? & 127) {
    printf "Command died with signal %d\n", $? & 127;
  } elsif ($? >> 8) {
    printf "Command exited erroneously with return code %d\n", $? >> 8;
  } else {
    printf "Command completed successfully\n";
  }

  print "\n";
}
