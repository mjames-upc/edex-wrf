#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ARWdmpar.pm
#
#  DESCRIPTION:  This module handles the configuration of parameters used
#                in MPI execution of the WRF
#
#   WHAT THE WRF
#   GUIDE SAYS:  Nothing of value for this module
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package ARWdmpar;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Rconf %Config %ARWconf %ParmsDM);

use Others;
use Empi;


sub Configure {
# ==============================================================================================
# MPI PROCESSING CONFIGURATION DIVER
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This file contains the configuration settings used when running a simulation
#   on multiple processors and nodes. In you are running the UEMS on a cluster
#   then changes are you will need to edit this file. If you are running simulations
#   on a single system then you probably do not need to make any changes here; however,
#   it is recommended that you at least become familiar with the valuable information
#   provided below.
# ==============================================================================================
# ==============================================================================================
#   
    %ParmsDM = ();

    %Config  = %ARWconfig::Config;
    %Rconf   = %ARWconfig::Rconf;

    my $href = shift; %ARWconf = %{$href};

    return () if &ParmsDM_Control(); 
    return () if &ParmsDM_Debug();

    %{$ARWconf{dmpar}}  = %ParmsDM;


return %ARWconf;
}


sub ParmsDM_Control {
# ==============================================================================================
# WRF SIMULATION LOCAL CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This file contains the configuration settings used when running a simulation
#   on multiple processors and nodes. In you are running the UEMS on a cluster
#   then changes are you will need to edit this file. If you are running simulations
#   on a single system then you probably do not need to make any changes here; however,
#   it is recommended that you at least become familiar with the valuable information
#   provided below.
# ==============================================================================================
# ==============================================================================================
#

    #----------------------------------------------------------------------------------
    #  Now begin the process of checking the parameters for valid values. Each 
    #  parameter is checked for validity but are not crossed-checked with other
    #  parameters, which is done prior to the values being used. 
    #----------------------------------------------------------------------------------
    #
    my %renv  = %{$Rconf{rtenv}};
    my %flags = %{$Rconf{flags}};

    @{$ParmsDM{mpicheck}}       =  &Config_mpicheck();
    @{$ParmsDM{iface}}          =  &Config_iface();
    @{$ParmsDM{numtiles}}       =  &Config_numtiles();
    @{$ParmsDM{decomp}}         =  &Config_decomp();
    @{$ParmsDM{decomp_x}}       =  &Config_decomp_x();
    @{$ParmsDM{decomp_y}}       =  &Config_decomp_y();


    unless ($flags{noreal}) {return 1 unless @{$ParmsDM{process}{real}{nodecpus}} = &Config_nodecpus('real_nodecpus');}
    unless ($flags{nowrfm}) {return 1 unless @{$ParmsDM{process}{wrfm}{nodecpus}} = &Config_nodecpus('wrfm_nodecpus');}


return;
}


#
# ==================================================================================
# ==================================================================================
#      SO BEGINS THE INDIVIDUAL PARAMETER CONFIGURATION SUBROUTINES
# ==================================================================================
# ==================================================================================
#

sub Config_nodecpus {
# ==================================================================================
#  Option:  NODECPUS - Set the NODES & number of CPUs
#
#  Default: NODECPUS = local:NCPUS
# ==================================================================================
#
use List::Util 'first';

    my $parm     = shift; return ('local:NCPUS') unless $parm;
    my @nodecpus = @{$Config{uconf}{uc $parm}};

    #--------------------------------------------------------------------------------
    #  First task is to check whether this is a simulation on the local host.
    #  This step should look for entries specified as "local", "localhost", or
    #  if the local hostname or IP address was used.  A "local" or "localhost" 
    #  entry negates all other hostnames in the string.
    #--------------------------------------------------------------------------------
    #
    if (my $local = first {/^local/} @nodecpus) {
        my ($node,$cpus) = split /:/ => $local, 2;
        $cpus = 'NCPUS' unless defined $cpus and $cpus and &Others::isInteger($cpus) and $cpus > 0;
        return ("localhost:$cpus");
    }

    #--------------------------------------------------------------------------------
    #  If a single hostname or IP address was specified, check whether it's the 
    #  local host. Note that this will also catch the 'local' assigned above but 
    #  that's not a problem.
    #--------------------------------------------------------------------------------
    #
    if (@nodecpus == 1) {  #  Check whether it's the local host - Note that this will also catch 
        my ($node,$cpus) = split /:/ => $nodecpus[0], 2;
        if ($node and &Others::isLocalHost($node)) {
            $cpus = 'NCPUS' unless defined $cpus and $cpus and &Others::isInteger($cpus) and $cpus > 0;
            return ("localhost:$cpus");
        }
    }

    
    #--------------------------------------------------------------------------------
    #  Loop through the entries to make sure the entries pass the initial
    #  "smell test". Yes, the UEMS can smell you too, and I like it!
    #--------------------------------------------------------------------------------
    #
    foreach (@nodecpus) {
        
        my ($node,$cpus) = split /:/ => $_, 2;
        my $str  = join ',', @nodecpus;
        my $prm  = uc $parm;

        unless ($node and &Enet::isHostname($node) ) {
            my $mesg = "It appears that a proper hostname or IP address is missing from the $prm ".
                       "parameter setting in the run_ncpus.conf file:\n\n".
                       "X02X$prm = $str\n\n".
                       "Now just what are you going to do about it?";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,"What is this \"$_\" thing?",$mesg);
            return ();
        }

        unless (defined $cpus and $cpus and &Others::isInteger($cpus) and $cpus > 0 ) {
            $node =~ s/://g;
            my $mesg = "Bad entry within the $prm parameter in the run_ncpus.conf file:\n\n".
                       "X02X$prm = $str\n\n".
                       "You need to assign some number of CPUS to $node before I do it for you.";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,"What is this \"$_\" thing?",$mesg);
            return ();
        }
    }


return @nodecpus;
}


sub Config_decomp {
# ==================================================================================
#  Option:  DECOMP - Method of domain decomposition to use
#
#    DECOMP tells UEMS which method of domain decomposition to use when running on 
#    a parallel distributed memory system. If you set DECOMP to 0, the WRF model
#    will use its own internal decomposition. This value is equivalent to setting
#    NPROC_X and NPROC_Y = -1 in the WRF namelist.
#
#    Setting DECOMP to 1 will decompose your domain in to 1 x N patches where N is the
#    number of processors being used. So if you are running on on 8 processors, then your
#    domain will be broken out as 1x8.
#
#    If DECOMP = 2, the UEMS will use the values of DECOMP_X and DECOMP_Y for the WRF 
#    namelist variables NPROC_X and NPROC_Y, respectively. If DECOMP_X and _Y are not
#    specified, or the values are unreasonable, the UEMS will use DECOMP = 0.
#
#  Default: DECOMP = 0 
# ==================================================================================
#
    my @decomp = @{$Config{uconf}{DECOMP}};

return @decomp;
}


sub Config_decomp_x {
# ==================================================================================
#  Option:  DECOMP_X - The number of patches in the X-direction
#
#  Default: DECOMP_X = 0 (Will be assigned later)
# ==================================================================================
#
    my @decomp_x = ($ParmsDM{decomp}[0] == 2) ? @{$Config{uconf}{DECOMP_X}} : (0);

return @decomp_x;
}


sub Config_decomp_y {
# ==================================================================================
#  Option:  DECOMP_Y - The number of patches in the Y-direction
#
#  Default: DECOMP_Y = 0 (Will be assigned later)
# ==================================================================================
#
    my @decomp_y = ($ParmsDM{decomp}[0] == 2) ? @{$Config{uconf}{DECOMP_Y}} : (0);

return @decomp_y;
}


sub Config_mpicheck {
# ==================================================================================
#  Option:  MPICHECK - Run simple network check before running MPI routine
#
#  Description:
#
#    Setting MPICHECK to any value will cause the UEMS to run a simple network check
#    prior to running a simulation across multiple system. It's purpose is to ensure
#    that the machines listed in REAL_NODECPUS and WRFM_NODECPUS are reachable and
#    configured for running the UEMS. If you ran the "netcheck" utility previously
#    and feel comfortable that your cluster is configured correctly, then leave
#    leave MPICHECK blank and save yourself 30 seconds of execution time.
#
#  Default: MPICHECK = 1
# ==================================================================================
#
    my @mpicheck = @{$Config{uconf}{MPICHECK}};


return @mpicheck;
}


sub Config_iface {
# ==================================================================================
#  Option:  HYDRA_IFACE - Network interface used in distributed computing
#
#    The UEMS uses the MPICH2 "HYDRA" processes manager for distributed computing.
#    The HYDRA_IFACE parameter tells HYDRA which network interface to use for the
#    communication between nodes. Available interfaces may be found by running the 
#    "ifconfig" utility on your system where the interface names (eth0, lo, etc) 
#    are listed on the left hand side of the output.
#
#    The default for HYDRA_IFACE is to leave it blank, in which case the UEMS 
#    will attempt to determine the interface to use from the IP addresses of the
#    hosts specified in REAL_NODECPUS and WRFM_NODECPUS.
#
#    If the UEMS is run on the local host only, then leave HYDRA_IFACE blank as
#    it will not be ignored anyway.
#
#  Default: HYDRA_IFACE = <blank>
# ==================================================================================
#
    my @iface = @{$Config{uconf}{HYDRA_IFACE}};

return @iface;
}


sub Config_numtiles {
# ==================================================================================
#  Option:  NUMTILES -
#
#    You can further improve the performance of your system by setting NUMTILES to 
#    a value greater than 1. The NUMTILES setting will further subdivide the 
#    decomposed domain patches into smaller tiles that are processed individually.
#    The goal is to define NUMTILES such that the amount of memory used for each 
#    tile can fit into the CPUs cache. 
#
#    A NUMTILES value that is too large, thus making the size of the tiles (and memory
#    required) too small, will result in a degradation in performance or possible model
#    crash (seg fault). If the NUMTILES value is too small then you will may see a 
#    reduced performance benefit.
#
#    Since "perfect" value for NUMTILES depends upon the type of CPU, the number of total
#    cores used in the simulation, and the size of your domain, it is impossible for the
#    Wizards of the UEMS to determine an algorithm for setting NUMTILES automatically. So it
#    is up to you to determine a value by trial and error. 
#
#  Default: NUMTILES = 1
# ==================================================================================
#
    my @numtiles = @{$Config{uconf}{NUMTILES}};

return @numtiles;
}



sub ParmsDM_Debug {
# ==============================================================================================
# MPI PROCESSING DEBUG ROUTINE
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  When the --debug 4+ flag is passed, prints out the contents of the MPI processing hash
#
# ==============================================================================================
# ==============================================================================================
#   
    return unless $ENV{RUN_DBG} > 3;  #  Only for --debug 3+

    my @defvars  = qw(mpicheck iface decomp decomp_x decomp_y numtiles);

    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,13+$Rconf{arf},144,1,1,'Leaving &ARWdmparms');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-16s  = %s',$_,join ', ' => @{$ParmsDM{$_}})) foreach @defvars;
    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,2,'=' x 72);

return;
}


