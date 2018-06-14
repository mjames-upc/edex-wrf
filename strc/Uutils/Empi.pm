#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Empi.pm
#
#  DESCRIPTION:  Empi contains subroutines used to support running MPI routines.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Empi;

use warnings;
use strict;
require 5.008;
use English;

use Others;
use Enet;

sub ConfigureProcessMPI {
# ===================================================================================
#   This routine prepares the system for execution of program with MPI (MPICH). The
#   hash passed to &ConfigureProcessMPI must include a node hash %process{nodes}.
#  
#      $process{process}                 - Name of process to be run
#      $process{hostpath}                - Path to the directory where hostsfile is written
#      $process{nogforker}               - Flag (1) if not to use gforker (mpiexec.gforker)

#      $process{mpiexe}                  - Path & executable filename to be run
#      $process{mpidbg}                  - include mpich debug flags ? (1|0)
#      @process{nodeorder}               - An array containing the order of the nodes passed
#
#   The nodes hash:
#      $process{nodes}{$node}{hostname}  - Hostname
#      $process{nodes}{$node}{address}   - IP Address
#      $process{nodes}{$node}{iface}     - Network Iface
#      $process{nodes}{$node}{localhost} - Localhost ? (1|0)
#      $process{nodes}{$node}{headnode}  - Headnode  ? (1|0)
#      $process{nodes}{$node}{usecores}  - The number of cores to use on node
#   
#   The returned %mpi hash contains the following information:
#      $mpi{error}                       - Message if error occurred or 0 
#      $mpi{hydra}                       - If using hydra (MPICH)
#      $mpi{ncores}    =                 - Total number of cores used
#      $mpi{process}   =                 - Name of process (returned)
#      $mpi{hostsfile} =                 - Full path to hostsfile
#      $mpi{mpiexec}   =                 - Formatted MPI command to run
#      %{$mpi{nodes}}  =                 - The node list (returned)
# ===================================================================================
#
    my %mpi        = ();
       $mpi{error} = '';

    my $href    = shift;
    my %process = %{$href};


    #----------------------------------------------------------------------------------
    #  Begin by deleting any previously defined MPICH environment variables 
    #----------------------------------------------------------------------------------
    #
    my @envs = qw(MPIEXEC_PORT_RANGE MPICH_PORT_RANGE HYDRA_IFACE HYDRA_ENV MPIEXEC_TIMEOUT);
    foreach (@envs) {delete $ENV{$_} if defined $ENV{$_};}


    #----------------------------------------------------------------------------------
    #  Export all the environment variables
    #----------------------------------------------------------------------------------
    #
    $ENV{HYDRA_ENV} = 'all' unless $ENV{LSF_SYS};


    #----------------------------------------------------------------------------------
    #  Count the total number of cores requested by adding up the requested
    #  cores from all nodes. A new hash (%ncores) is created where 
    #  $ncores{$node} = ncores, because that is what &Empi::SumTotalProcessors
    #  expects.
    #----------------------------------------------------------------------------------
    #
    my %nodes      = %{$process{nodes}};

    my %ncores     = ();
       $ncores{$_} = $nodes{$_}{usecores} foreach keys %nodes;

    $mpi{ncores}   = &SumTotalProcessors(\%ncores);


    #----------------------------------------------------------------------------------
    #  The $mpi{hydra} determines whether to use the MPICH Hydra process manager
    #  when running over multiple nodes or gforker on a single node.
    #----------------------------------------------------------------------------------
    #
    $mpi{hydra}     = (keys %nodes == 1 and defined $nodes{localhost}) ? 0 : 1;
    $mpi{process}   = $process{process};
    $mpi{hostsfile} = $mpi{hydra} ? "$process{hostpath}/mpich2.hosts.$$" : '';


    #----------------------------------------------------------------------------------
    #  Make sure that MPICH is installed on each node in the same location identified
    #  by the $EMS_MPI environment variable. The test is only for the existence of the
    #  mpich/bin directory and it is assumed that the necessary routines are present.
    #  Yes, this is a requirement when running MPI.
    #----------------------------------------------------------------------------------
    #
    if (defined $process{mpicheck} and $process{mpicheck}) {

        my $mpich = "$ENV{EMS_MPI}/bin";  #  Target directory

        foreach (keys %nodes) {
            if ($mpi{hydra}) {
                $mpi{error} = "MPI Not Found on $_ ($mpich)" if &Others::FileExistsHost($nodes{$_}{hostname},$mpich);
            } else {
                $mpi{error} = "MPI Not Found on $_ ($mpich)" if &Others::FileExists($mpich);
            }
        }
        return %mpi if $mpi{error};
    }


    #----------------------------------------------------------------------------------
    #  The %nodes hash uses the name of the node, as identified by the user, as the
    #  the primary hash key. The outgoing %mpi{nodes} hash will instead list the 
    #  nodes in order from {0 .. N}, where %mpi{nodes}{0} will be the localhost.
    #----------------------------------------------------------------------------------
    #
    my $n = 1;
    foreach (@{$process{nodeorder}}) {
        if ($nodes{$_}{headnode}) {
            %{$mpi{nodes}{0}}  = %{$nodes{$_}};
        } else {
            %{$mpi{nodes}{$n}} = %{$nodes{$_}};
            $n++;
        }
    }


    #----------------------------------------------------------------------------------
    #  The $mpi{mpiexec} contains the command  string will all the flags and 
    #  arguments. The %mpi is also populated with information that will be needed
    #  outside of this subroutine.
    #----------------------------------------------------------------------------------
    #
    my $nogforker   = (defined $process{nogforker} and $process{nogforker}) ? 1 : 0;
    my $mpiexe      = $process{mpiexe};
    my $iface       = $mpi{hydra}   ? (defined $mpi{nodes}{0} and $mpi{nodes}{0}{iface})
                                    ? "-iface $mpi{nodes}{0}{iface}" : "-iface $mpi{nodes}{1}{iface}" : '';

    my $hostsfile   = $mpi{hydra}   ? "-f $mpi{hostsfile}" : '';
    my $mpiexec     = ($mpi{hydra} or $nogforker) ? "$ENV{EMS_MPI}/bin/mpiexec" : "$ENV{EMS_MPI}/bin/mpiexec.gforker";
    my $dbg         = (defined $process{mpidbg} and $process{mpidbg}) ? ' -verbose -print-all-exitcodes -profile ' : '';
    my $ncores      = "-n $mpi{ncores}";

    $mpi{mpiexec}   = "$mpiexec $hostsfile $ncores $dbg $mpiexe";  #  The formatted command


return %mpi;
}


sub ProcessNodeCpus {
# ===================================================================================
#  This routine takes the <process>_NODECPUS setting and processes it for use
#  by the UEMS when running on distributed memory systems.
#  This routine collects information from each of the specified notes necessary
#  for running an MPI process. The input is an array of "$node:$ncpus" string 
#  just like the format to <process>_NODECPUS parameters.
# ===================================================================================
#
use List::Util 'first';

    my $debug   = ((defined $ENV{RUN_DBG} and $ENV{RUN_DBG} > 5) or (defined $ENV{POST_DBG} and $ENV{POST_DBG})) ? 1 : 0; 

    my %Nodes   = ();
    my @Process = @_;

    return () unless @Process;

    my $lhost            = qw{};  #  Keep track of the localhost

    %{$Nodes{nodes}}     = (); 
    @{$Nodes{nodeorder}} = ();
    $Nodes{totalcpus}    = 0;
    my $nn               = @Process;  #  Keep track of processed nodes in case of failures


    my ($hostname, $address, $iface) = (0, 0, 0);  #  Initialize the key variables

    foreach my $node (@Process) {

        my ($host, $ncores) = split ':', $node, 2;

        #-----------------------------------------------------------------------------------
        #  Need to collect information about the host, specifically:
        #  
        #  $Nodes{nodes}{$host}{hostname}   - The hostname for the node
        #  $Nodes{nodes}{$host}{address}    - IP Address assigned to hostname
        #  $Nodes{nodes}{$host}{localhost}  - Local Host? (1|0 == Yes|No)
        #  $Nodes{nodes}{$host}{headnode}   - Is this the headnode ? (1|0 == Yes|No)
        #  $Nodes{nodes}{$host}{maxcores}   - Total number of cores available on hostname
        #  $Nodes{nodes}{$host}{reqcores}   - Number of requested cores on hostname
        #  $Nodes{nodes}{$host}{usecores}   - Number of cores that will be used on hostname
        #  $Nodes{nodes}{$host}{iface}      - Name of Head Node Network Interface to use
        #  @{$Nodes{nodeorder}}             - List of passed node order 
        #-----------------------------------------------------------------------------------
        #
        &Ecomm::PrintTerminal(0,12,86,1,$debug?1:0,sprintf('%-26s  %3s',"Checking \"$host\"",' - ')) if $debug;
        

        #-----------------------------------------------------------------------------------
        #  Test whether the hostname points to the local host, in which case all the 
        #  host information will be mined locally (Duh); otherwise, passwordless SSH
        #  will be used.
        #-----------------------------------------------------------------------------------
        #
        $host = 'localhost' if $host eq 'local';

        #-----------------------------------------------------------------------------------
        #  Determine whether the argument passed is an IP address or hostname
        #-----------------------------------------------------------------------------------
        #
        ($hostname, $address) = &Enet::isHostnameOrIP($host);

        &Ecomm::PrintTerminal(4,12,255,1,1,"Following isHostnameOrIP     : $hostname | $address") if $debug;

        unless ($hostname || $address) {
            &Ecomm::PrintTerminal($debug?6:0,$debug?7:0,144,$debug?1:0,1,"Failed: neither IP address nor hostname ($host).");
            return ();
        }


        #-----------------------------------------------------------------------------------
        #  Now that we have one ($hostname || $address), get the other
        #-----------------------------------------------------------------------------------
        #
        if ($address) {
            $hostname = &Enet::Address2Hostname($address);
        } else {
            $address  = &Enet::Hostname2Address($hostname);
        }

        &Ecomm::PrintTerminal(4,12,255,0,1,"Following IP Hostname Match  : $hostname | $address") if $debug;

        unless ($hostname and $address) {
            my $mesg = $hostname ? "Oh Poop!  Could not map \"$hostname\" to an IP address." : "Oh Poop!  Could not map \"$address\" to a hostname.";
            &Ecomm::PrintTerminal($debug?6:0,$debug?7:0,144,$debug?1:0,1,$mesg);
            return ();
        }


        #-----------------------------------------------------------------------------------
        #  Prefer a long hostname if possible but only if it maps to the same IP
        #-----------------------------------------------------------------------------------
        #
        my $lhostname = &Enet::Hostname2LongHostname($hostname); $lhostname = '' unless $lhostname;
        my $laddress  = &Enet::Hostname2Address($lhostname);     $laddress  = '' unless $laddress;

        $hostname = $lhostname if $lhostname and $address eq $laddress;

        &Ecomm::PrintTerminal(4,12,255,0,1,"Following Long Hostname Match: $hostname | $address") if $debug;


        #-----------------------------------------------------------------------------------
        #  Get the network interface used to communicate with the remote host.
        #-----------------------------------------------------------------------------------
        #
        $iface = &Enet::Address2Iface($address);

        &Ecomm::PrintTerminal(4,12,255,0,1,"Following Interface IP Match : $hostname | $address | $iface") if $debug;

        unless ($iface) {
           &Ecomm::PrintTerminal($debug?6:0,$debug?7:0,144,$debug?1:0,1,"Error: Unable to identify network interface for $address.");
           return ();
        }

        #-----------------------------------------------------------------------------------
        #  Account for users having multiple entries for the same host. Yes, they should
        #  not do this but that doesn't stop anyone from trying.
        #-----------------------------------------------------------------------------------
        #
        $host = &Enet::Hostname2ShortHostname($lhostname || $hostname);

        %{$Nodes{nodes}{$host}}  = () unless defined $Nodes{nodes}{$host};

        $Nodes{nodes}{$host}{hostname}  = $hostname;
        $Nodes{nodes}{$host}{address}   = $address;
        $Nodes{nodes}{$host}{iface}     = $iface;
        $Nodes{nodes}{$host}{localhost} = &Others::isLocalHost($host);
        $Nodes{nodes}{$host}{headnode}  = $Nodes{nodes}{$host}{localhost};

        unless ($Nodes{nodes}{$host}{localhost})  {

            #  Since the system is not the local host, test whether it is available
            #  and passwordless SSH can be used to run the commands necessary to 
            #  collect the information.
            #
            if (my $notavail = (&Enet::TestHostAvailability($host) || &Enet::TestPasswordlessSSH($host))) {

               $notavail = "$notavail to $host" if $notavail =~ /refused/i; #  Needed for clarification

               &Ecomm::PrintTerminal(9,11,144,2,0,"I tried, but $notavail");

               #  Since we cannot connect to the host then remove it from the list and continue
               #
               delete $Nodes{nodes}{$host};
               next;
            }

            
            if (&Others::FileExistsHost($host,"$ENV{EMS_MPI}/bin/mpiexec")) {
                &Ecomm::PrintTerminal($debug?7:9,$debug?7:11,144,$debug?1:1,0,"MPI executables not found on $host ($ENV{EMS_MPI}/bin/)!");
                delete $Nodes{nodes}{$host};
                next;
            }


            #  Save for CompatibleGLibCHost in later release
            #
            #if (my $glibc = &Others::CompatibleGLibCHost($host,"$ENV{EMS_MPI}/bin/mpiexec")) {
            #    &Ecomm::PrintTerminal($debug?7:9,$debug?7:11,144,$debug?1:1,0,"Incompatible GLIBC on $host:",$glibc);
            #    delete $Nodes{nodes}{$host};
            #    next;
            #}

            
            if (&Others::FileExistsHost($host,$ENV{EMS_BIN})) {
                &Ecomm::PrintTerminal($debug?7:9,$debug?7:11,144,$debug?1:1,0,"UEMS executables not found on $host ($ENV{EMS_BIN})!");
                delete $Nodes{nodes}{$host};
                next;
            }

         
 
            #  Comment out until it's determined whether $EMS_RUN must exist on all systems
            #
#           if (&Others::FileExistsHost($host,$ENV{EMS_RUN})) {
#               &Ecomm::PrintTerminal($debug?6:0,$debug?7:0,144,$debug?1:0,0,"UEMS run-time directory not found ($ENV{EMS_RUN})!");
#               delete $Nodes{nodes}{$host};
#               next;
#           }

       
        }

        my %cpuinfo = $Nodes{nodes}{$host}{localhost} ? &Others::SystemCpuInfo() : &Others::SystemCpuInfo($host);

        $ncores                         =~ s/NCPUS/$ENV{OMP_NUM_THREADS}/g;  #  Make sure 
        $Nodes{nodes}{$host}{sockets}   = $cpuinfo{sockets};
        $Nodes{nodes}{$host}{maxcores}  = $cpuinfo{total_cores};
        $Nodes{nodes}{$host}{reqcores}  = (defined $Nodes{nodes}{$host}{reqcores}) ? $Nodes{nodes}{$host}{reqcores} + $ncores : $ncores;
        $Nodes{nodes}{$host}{usecores}  = ($Nodes{nodes}{$host}{reqcores} > $cpuinfo{total_cores}) ? $cpuinfo{total_cores} : $Nodes{nodes}{$host}{reqcores};

        &Ecomm::PrintTerminal(0,0,24,0,0,'Looks good!') if $debug; $nn--;
#       &Ecomm::PrintTerminal(0,0,24,$debug?1:0,$debug?1:0,'Looks good!'); $nn--;
        
        #---------------------------------------------------------------------------------
        #  Make sure that the localhost is specified first in the node list
        #---------------------------------------------------------------------------------
        #
        unless (grep {/^$host$/} @{$Nodes{nodeorder}}) {
            $Nodes{nodes}{$host}{localhost} ? unshift  @{$Nodes{nodeorder}} => $host : push @{$Nodes{nodeorder}} => $host;
        }
        $lhost = $host if $Nodes{nodes}{$host}{localhost};

    }

    #----------------------------------------------------------------------------------
    #  Determine whether the local host was included in the list with multiple
    #  nodes. If so, then rename 'localhost' to $lhost; otherwise, retain 'localhost'.
    #----------------------------------------------------------------------------------
    #
    if (keys %{$Nodes{nodes}} > 1 and grep {/^localhost$/} keys %{$Nodes{nodes}} ) {

        my $host  = first { !/^localhost$/ } keys %{$Nodes{nodes}};  #  Get the 1st non-localhost hostname

        $Nodes{nodes}{localhost}{iface}    = $Nodes{nodes}{$host}{iface};
        $Nodes{nodes}{localhost}{address}  = &Enet::Iface2Address($Nodes{nodes}{localhost}{iface});
        $Nodes{nodes}{localhost}{hostname} = &Enet::Address2Hostname($Nodes{nodes}{localhost}{address});

        %{$Nodes{nodes}{$lhost}} = %{$Nodes{nodes}{localhost}};
        delete $Nodes{nodes}{localhost};
 
    }


    if (keys %{$Nodes{nodes}} == 1 and defined $Nodes{nodes}{localhost}) {
       @{$Nodes{nodeorder}} = ('localhost');
       my $lh = `hostname -f`; chomp $lh;
       $Nodes{nodes}{localhost}{hostname} = $lh if $lh;
    }
    @{$Nodes{nodeorder}} = () if $nn;  #  Zero out nodeorder if there was an error; $nn = 0 (no errors)

    &Ecomm::PrintMessage(4,11,255,1,$nn?0:1,"Final Node Order : @{$Nodes{nodeorder}}") if $debug and @{$Nodes{nodeorder}} > 1;
    
    $Nodes{totalcpus}+=$Nodes{nodes}{$_}{usecores} foreach @{$Nodes{nodeorder}};


return %Nodes;
}



sub WriteHostsFile  {
#==================================================================================
#  This routine creates the MPICH hosts file used when running MPI programs 
#  across multiple nodes. The path and filename are passed in via the $hostfl
#  variable while the list of nodes is provided in the %nodes hash, which should
#  have the following structure:
#
#  $nodes{0 .. N}{address}  - IP address of the node
#  $nodes{0 .. N}{hostname} - The hostname associated with the IP address
#  $nodes{0 .. N}{usecores} - The number of cores to use on the node
#
#  The WriteHostsFile routine returns 0 if all was successful or an descriptive
#  string is there was an error.
#==================================================================================
#   
    my $error = qw{};

    my ($nref, $hfref)  = @_;

    my %nodes  = %$nref;
    my $hostfl = $$hfref;

    return 0 unless $hostfl;  #  No hostfile to write

    #----------------------------------------------------------------------------------
    #  Begin by opening the hosts file.
    #----------------------------------------------------------------------------------
    #
    &Others::rm($hostfl);  #  Remove any hostfile with the same name

    open (my $hfh, '>', $hostfl) || return "Unable to open MPI hosts file -\n\n$hostfl\n\nPossible permission problem?";


    #----------------------------------------------------------------------------------
    #  If all nodes are on the same subnet then is IPs; otherwise, use hostnames
    #----------------------------------------------------------------------------------
    #
    my %addrs = ();
    foreach (sort {$a <=> $b} keys %nodes) {
        next unless %{$nodes{$_}};
        my @sn = split /\./ => $nodes{$_}{address};
        my $as = join "." => @sn[0..2];
        $addrs{$as} = 0;
    }
    my $key = (keys %addrs == 1) ? 'address' : 'hostname';  #  Everybody on the same subnet so use IP addresses


    #----------------------------------------------------------------------------------
    #  Populate the hosts file with the hostnames or addresses of each node with
    #  the local host (if available) first. Each node will be listed N-times, where
    #  N  is the number of cores to use.
    #----------------------------------------------------------------------------------
    #
    foreach my $node (sort {$a <=> $b} keys %nodes) { print $hfh "$nodes{$node}{$key}\n" for 1 .. $nodes{$node}{usecores}; } close $hfh;

    #----------------------------------------------------------------------------------
    #  Final error check
    #----------------------------------------------------------------------------------
    #
    $error = "The mpich host file ($hostfl) is empty, which is probably not what you intended. ".
             "Check the machine:CPU specifications in the configuration file.";


return (-z $hostfl) ? $error : 0;
}


sub SumTotalProcessors {
#==================================================================================
#  The SumTotalProcessors routine sums up the total number of cores specified
#  for each node listed in the %nodes hash. The %nodes hash should be passed
#  containing each node name as a key with the number of cores to use assigned
#  to the key (node).
#==================================================================================
#
    my $ncpus = 0;

    my $href  = shift || return $ncpus; 
    my %nodes = %{$href};

    $ncpus = $ncpus + $nodes{$_} foreach keys %nodes;

return ($ncpus > 0) ? $ncpus : 0;
} #  SumTotalProcessors



