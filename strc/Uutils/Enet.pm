#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Enet.pm
#
#  DESCRIPTION:  Enet contains subroutines used to collect information about
#                the local network.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Enet;

use warnings;
use strict;
require 5.008;
use English;

use Ecore;

sub Address2Hostname {
#==================================================================================
#  This routine takes an IP address and attempts to resolve the hostname. Either
#  returns the fully qualified hostname or 0 if failure.  There is a problem
#  in that gethostbyaddr will retrieve the first record from DNS, which may
#  not be what you want is aliases are being used. If the returned hostname
#  is not the one you wanted then use the Address2HostnameMatch subroutine
#  instead.
#==================================================================================
#
use Socket;
use Net::hostent;

    my $hostname = 0;
    my $address  = shift || return $hostname;

    if (my $ah = gethostbyaddr(inet_aton($address), AF_INET) ) {
        $hostname = $ah->name;
    }

return $hostname;
} #  Address2Hostname


sub Address2Iface {
#==================================================================================
#  This routine takes an IP address and attempts to identify the interface device
#  on the local host used for communication. The routine begins by running the 
#  system /sbin/ip utility to get the IP address associated with the interface
#  on the local host and then maps the address to that interface.
#  returns the interface name or 0 if failure.
#==================================================================================
#
    my $iface    = 0;
    my $address  = shift || return 'lo';

    return 0 unless -e '/sbin/ip';

    #  Use the /sbin/ip utility to get the IP address associated with the interface
    #  on the local host. Just like stated above.
    #
    my $iaddress = `/sbin/ip route get $address | grep -oP 'src \\K\\S+'`; chomp $iaddress;

    return 0 unless $iaddress;

    #  Now collect the network interfaces available on the local system
    #
    my %ifaces = &Others::SystemIfaceInfo();


    #  Finally, loop through the devices until there is a match
    #
    foreach (keys %ifaces) { $iface = $_ if $iaddress eq $ifaces{$_}{ADDR}; }


return $iface;
} #  Address2Iface


sub GetMyOutsideAddressHTTP {
#==================================================================================
#  This routine gets the IP address of the local system as seen
#  by the outside world when using HTTP.  It simply checks whether
#  contact can be made to either of the SOO STRC HTTP servers and
#  returns the IP outside address. If no contact can be made then
#  null (0) is returned.
#==================================================================================
#
use IO::Socket;

    $| = 1;
    my $address = 0;

    #  Contact the soostrc web servers and make sure the use is on the network

    if (my $sock = IO::Socket::INET->new(PeerAddr=> "soostrc.comet.ucar.edu", PeerPort=> 80, Proto => "tcp") ) {
         $address = $sock->sockhost;
    }

    if (my $sock = IO::Socket::INET->new(PeerAddr=> "strc.comet.ucar.edu", PeerPort=> 80, Proto => "tcp") ) {
         $address = $sock->sockhost;
    }

return $address;
}


sub GetMyOutsideAddressSSH {
#==================================================================================
#  This routine gets the IP address of the local system as seen
#  by the outside world when using SSH.  It simply checks whether
#  contact can be made to the remote server via SSH. If yes, then 
#  it returns the IP outside address and ssh port of the local and
#  remote machines. If no contact can be made then null is returned.
#==================================================================================
#
use IO::Socket;

    $| = 1;
    my ($sockhost, $peerhost, $sockport, $peerport) = (0, 0, 0, 0);;

    my $remote = shift || return ;

    if (my $sock = IO::Socket::INET->new(PeerAddr=> $remote, PeerPort=> 'ssh') ) {
         $sockhost = $sock->sockhost;
         $peerhost = $sock->peerhost;
         $sockport = $sock->sockport;
         $peerport = $sock->peerport;
    }


return ($sockhost, $peerhost, $sockport, $peerport);
}


sub Hostname2Address {
#==================================================================================
#  This routine takes a hostname and attempts to get the IP address. Either
#  returns the IP address or 0 if failure
#==================================================================================
#
use Socket;

    my $hostname  = shift || return 0;

    return 0 unless my $iaddr = inet_aton $hostname;

return inet_ntoa ( $iaddr );
} #  Hostname2Address


sub Hostname2LongHostname {
#==================================================================================
#  This routine takes a hostname and attepts to get the fully qualified domain 
#  name (FQDN).  Either returns the FQDN or 0 if failure.
#==================================================================================
#
use Socket;
use Net::hostent;
use List::Util 'first';

    my $lhostname = 0;

    my $hostname  = shift || return 0;

    return 0 if &isAddressIP($hostname);

    my $ah = gethost($hostname) || return 0;

    $lhostname = @{$ah->aliases} ? first { /^${hostname}\./ } @{$ah->aliases} : $ah->name;  #  Get the 1st non-localhost hostname;
    $lhostname = '' unless $lhostname;

    my @list = split '\.' => $lhostname;

return $#list ? $lhostname : 0;
} #  Hostname2LongHostname


sub Hostname2ShortHostname {
#==================================================================================
#  This routine takes a hostname and attepts to get the fully qualified domain 
#  name (FQDN).  Either returns the FQDN or 0 if failure.
#==================================================================================
#
    my @list  = ();

    my $hostname  = shift || return 0;
    
    $hostname = &Address2Hostname($hostname) if &isAddressIP($hostname);

    @list  = split '\.' => $hostname if $hostname;

return @list ? shift @list : 0;
} #  Hostname2ShortHostname


sub Iface2Address {
#==================================================================================
#  This routine takes a network interface device (eth1, lo, etc) and matches it
#  to an IP address. The local machine's interface information is  collected 
#  by the &SystemIfaceInfo routine, which probes the system via the ifconfig utility.
#  Returns the interface IP address or 0 if failure.
#==================================================================================
#
    my $iface  = shift || return 0;

    #  Collect the network interfaces available on the local system
    #
    my %ifaces = &Others::SystemIfaceInfo();


return (defined $ifaces{$iface}{ADDR} and $ifaces{$iface}{ADDR}) ? $ifaces{$iface}{ADDR} : 0;
} #  Iface2Address


sub isAddressIP {
#==================================================================================
#  This routine returns 1|0 depending whether in input is|is not an IP
#==================================================================================
#

return (shift =~ /^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$/) ? 1 : 0;
} #  isAddressIP


sub isHostnameOrIP {
#==================================================================================
#  Simple routine that checks whether the passed string could be a hostname
#  or IP address.  Emphasis on the "could be".
#==================================================================================
#
    my $input = shift || return (0, 0);

    return (0, $input) if &isAddressIP($input);
    return ($input, 0) if &isLongHostname($input);
    return ($input, 0) if &isShortHostname($input);

return (0, 0);
} #  isHostnameOrIP


sub isHostname {
#==================================================================================
#  Simple routine that checks whether the passed string meets the criteria for
#  being a hostname or IP address. Yes, I am aware that "isHostname" is technically
#  incorrect for a routine that includes a check for an IP address.
#==================================================================================
#
    my $host = shift || return 0;

    my $ih = &isAddressIP($host) + &isLongHostname($host) + &isShortHostname($host);

return $ih;
} #  isHostname


sub isLongHostname {
#==================================================================================
#  This routine returns 1|0 depending whether in input is|is not a fully 
#  qualified hostname .
#==================================================================================
#

#  Note that changing the first "+" to "*" below will cause match to short hostname
#
return (shift =~ /^(?:(?:(?:(?:[a-zA-Z0-9][-a-zA-Z0-9]{0,61})?[a-zA-Z0-9])[.])+(?:[a-zA-Z][-a-zA-Z0-9]{0,61}[a-zA-Z0-9]|[a-zA-Z])[.]?)$/) ? 1 : 0;
} #  isLongHostname


sub isShortHostname {
#==================================================================================
#  This routine returns 1|0 depending whether in input is|is not a short hostname
#  Matches any string that does not contain a '.', '~', (others stuff) or is a
#  number (exponential notation not withstanding).
#==================================================================================
#

return (shift =~ /(?!^\d+$)^[a-zA-Z0-9-]+$/ ) ? 1 : 0;
} #  isShortHostname


sub TestHostAvailability {
#==================================================================================
#  A simple interface to the &Enet::TestPingHost routine
#==================================================================================
#
    my $host  = shift;

return &TestPingHost($host) ? 0 : "TCP ping to $host - Failed (System not reachable)";
}


sub TestPasswordlessSSH {
#==================================================================================
#  This is just a wrapper around &TestPasswordlessSSH_Outgoing for legacy
#  reasons.
#==================================================================================
#

return &TestPasswordlessSSH_Outgoing(shift);
}  


sub TestPasswordlessSSH_Incoming {
#==================================================================================
#  &TestPasswordlessSSH_Incoming checks whether passwordless SSH has been 
#  configured between a remote system ($rhost) back to the localhost ($lhost).
#  
#  A return value of 0 indicates success; an error message will be returned.
#==================================================================================
#
use Ecore;

    my ($lhost, $rhost) = @_;  return "Missing hostname ($lhost, $rhost) in &TestPasswordlessSSH_Incoming" unless $lhost and $rhost;

return &Ecore::SysExecute("ssh -q -o BatchMode=yes $rhost ssh -q -o BatchMode=yes $lhost exit  > /dev/null 2>&1") ? $! : 0;
}  


sub TestPasswordlessSSH_Outgoing {
#==================================================================================
#  &TestPasswordlessSSH_Outgoing checks whether passwordless SSH is working 
#  between the localhost and a remote system ($host).
#
#  A return value of 0 indicates success; an error message will be returned.
#  Note that from the command line ssh does not provide a description of the
#  problem via $! but one magically appears from this routine.  Also, a
#  "No route to host" error may mean "permission denied" or password needed.
#==================================================================================
#
use Ecore;

    my $host = shift || return 'Missing hostname in &TestPasswordlessSSH_Outgoing';

return &Ecore::SysExecute("ssh -q -o BatchMode=yes $host exit > /dev/null 2>&1") ? $! : 0;
}  


sub TestFileAvailableSSH_Incoming {
#==================================================================================
#  TestFileAvailableSSH_Incoming checks the existence of a file ($file) on 
#  another system ($rhost) from a "local" system ($lhost) using SSH. It assumes 
#  that passwordless is configured correctly between the two machines.
#  
#  A return value of 0 indicates success; an error message will be returned.
#==================================================================================
#
use Ecore;

    my ($lhost, $rhost, $file) = @_;  

    return "Missing hostname ($lhost, $rhost) in &TestFileAvailableSSH_Incoming" unless $lhost and $rhost;
    return "Missing filename in &TestFileAvailableSSH_Incoming" unless $file;

return &Ecore::SysExecute("ssh -q -o BatchMode=yes $rhost ssh -q -o BatchMode=yes $lhost ls $file > /dev/null 2>&1") ? $! : 0;
}  


sub TestFileAvailableSSH_Outgoing {
#==================================================================================
#  TestFileAvailableSSH_Outgoing checks the existence of a file ($files) on 
#  another system ($rhost) using SSH. It assumes that passwordless is configured
#  correctly. 
#
#  A return value of 0 indicates success; an error message will be returned.
#==================================================================================
#
use Ecore;

    my ($rhost, $file) = @_;  

    return "Missing hostname in &TestFileAvailableSSH_Outgoing" unless $rhost;
    return "Missing filename in &TestFileAvailableSSH_Outgoing" unless $file;

return &Ecore::SysExecute("ssh -q -o BatchMode=yes $rhost ls $file > /dev/null 2>&1") ? $! : 0;
}  


sub TestPingHost {
#==================================================================================
#  TestPingHost is a simple routine to test whether a system is alive. 
#  Returns 1 for success (alive) and 0 for failure, which may be due to
#  the host system being down or is blocking tcp pings.  The system ping
#  command may work (icmp) but the Perl implementation requires root priv.
#==================================================================================
#
use Net::Ping;
use if defined eval{require Time::HiRes;} >0,  "Time::HiRes" => qw(time);

    my $ping    = 0;  #  Set default to failure
    my $timeout = 2;  #  Default 2 second timeout

    my $host    = shift;

    # ----------------------------------------------------------------------
    #  Start with the Perl Ping command - default uses tcp
    # ----------------------------------------------------------------------
    #
    my $pinger = Net::Ping->new();

    $ping = $pinger->ping($host,$timeout)  ? 1 : 0; $pinger->close();

    return $ping if $ping;

    # ----------------------------------------------------------------------
    #  The Perl ping failed but the system might be blocking tcp pings
    #  so try system ping, which uses icmp. 
    # ----------------------------------------------------------------------
    #
    $ping = (system "ping -q -c 2 $host > /dev/null 2>&1") ? 0 : 1;


return $ping;
}


