#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Rutils.pm
#
#  DESCRIPTION:  Rutils contains utilities used when running WRF simulations.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Rutils;

use warnings;
use strict;
require 5.008;
use English;


sub InitNodesCores {
# ==================================================================================
#  This subroutine simply isolates the call to &Empi::ProcessNodeCpus, which
#  handles the processing of the REAL|WRFM_NODECPUS setting in the run_ncpus.conf
#  file. Like many of the routines in the UEMS, &InitNodesCores uses a mix of 
#  global and local variables (arrays & hashes) to make the developers life
#  a bit easier.
# ==================================================================================
#
    my @nodecpu = @_;

    my %ncores = &Empi::ProcessNodeCpus(@nodecpu);

    unless (@{$ncores{nodeorder}}) {
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,144,0,0,'Oh Poop! There is a problem with one or more hosts requested - Exit');
        return ();
    }
 


return %ncores;
}



sub DomainDecomp0 {
# ==================================================================================
#  This routine manages the domain decomposition for both REAL and WRF model
#  based upon the value of the DECOMP = 0 in run_ncpus.conf, which requests
#  the WRF internal decomposition.
# ==================================================================================
#
    my $href = shift; my %dprocess = %{$href};

    $dprocess{nproc_x} = -1;
    $dprocess{nproc_y} = -1;


return %dprocess;
}



sub DomainDecomp1 {
# ==================================================================================
#  This routine manages the domain decomposition for both REAL and WRF model
#  based upon the value of the DECOMP = 1 in run_ncpus.conf, which requests
#  the UEMS decomposition.
# ==================================================================================
#
use List::Util qw( min max );

    my $mesg = qw{};

    my ($proc, $dref, $pref) = @_;  my %dinfo = %{$dref}; my %parallel = %{$pref};

    my $maldom  = 0;
    my $maxcpus = $parallel{totalcpus};
    my $ncpus   = $maxcpus;
    my $nxmax   = 0;  #  Need to retain the configuration with the largest $decomp_x value since that 

    foreach (sort {$a <=> $b} keys %{$dinfo{domains}}) {

        my $min_pts_per_patch = ($_ == 1) ? 8 : 7;

        my $dimx = $dinfo{domains}{$_}{nx};
        my $dimy = $dinfo{domains}{$_}{ny};
        my ($decomp_x, $decomp_y) = &Others::BestPatchDecomposition($maxcpus,$dimx,$dimy,$min_pts_per_patch,4);

        unless ($decomp_x * $decomp_y) {
            $mesg = "The UEMS was unable to determine a viable domain decomposition for domain $_ ($dimx (NX) x $dimy (NY)) ".
                    "using $maxcpus or fewer CPUs.  This is likely due to the inadequate size (I'm looking at you) of your ".
                    "domain. The UEMS looks forward to working you again once you've increased the dimensions to suitable values.";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,80,0,0,'About the size of your domain:',$mesg);
            return ();
        }

        $maldom = $_ if $decomp_x*$decomp_y < $ncpus;
        $ncpus  = min ($ncpus, $decomp_x*$decomp_y) if $decomp_x*$decomp_y;
        $nxmax  = max ($nxmax, $decomp_x);
    }


    #-----------------------------------------------------------------------------------
    #  If $maldom has a value then allow user to make changes for WRF only
    #-----------------------------------------------------------------------------------
    #
    if ($maldom and $proc eq 'wrfm') {
        $mesg = "Due to the dimensions of domain $maldom ($dinfo{domains}{$maldom}{nx} (NX) x $dinfo{domains}{$maldom}{ny} (NY)), the ".
                "UEMS recommends that you decrease the total number of CPUs for running WRF ARW to $ncpus. This is because there ".
                "is no decomposition factors for $maxcpus cpus that work for every domain in your simulation.\n\n".
                "If you don't like this recommendation then set DECOMP = 0 in run_ncpus.conf and you won't hear from me again until ".
                "after you are asleep.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,84,0,0,'Just remember, change is always good:',$mesg);
        return ();
    }

    #---------------------------------------------------------------------------------------
    #  If this is WRF REAL and the number of cores has been reduced, take them equitably
    #  from each node. If a node runs out of cores, delete it. This becomes a bit messy
    #  but there's no better way than brute force.
    #---------------------------------------------------------------------------------------
    #  
    if ($ncpus < $maxcpus) {  #  Should be for $proc eq 'real' only

        my $rcores = $maxcpus-$ncpus;
        while ($rcores) {
            foreach my $node (@{$parallel{nodeorder}}) {
                $parallel{nodes}{$node}{usecores}-- if $parallel{nodes}{$node}{usecores} and $rcores;
                $rcores-- if $rcores;
            }
        }

        my @newlist = ();
        foreach (@{$parallel{nodeorder}}) {push @newlist => $_ if $parallel{nodes}{$_}{usecores};}
        @{$parallel{nodeorder}} = @newlist;
        foreach (@{$parallel{nodeorder}}) {delete $parallel{nodes}{$_} unless $parallel{nodes}{$_}{usecores};}

        unless (@{$parallel{nodeorder}}) {
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,144,0,0,"Oh Poop! I've run out of nodes for running WRF real. I should not be here with 0 cpus");
            return ();
        }
    }
    $parallel{nproc_x}   = $nxmax;
    $parallel{nproc_y}   = $ncpus/$nxmax;
    $parallel{totalcpus} = $parallel{nproc_x}*$parallel{nproc_y};


return %parallel;
}



sub DomainDecomp2 {
# ==================================================================================
#  This routine manages the domain decomposition for both REAL and WRF model
#  based upon the value of the DECOMP = 2 in run_ncpus.conf, which requests
#  the user defined decomposition values for nproc_x & nproc_y.
# ==================================================================================
#
    my ($decomp_x, $decomp_y, $href) = @_;  my %dprocess = %{$href};

    $dprocess{nproc_x} = $decomp_x;
    $dprocess{nproc_y} = $decomp_y;


return %dprocess;
}



sub ProcessCleanup {
#==================================================================================
#  Clean up the run-time directory following a process, either WRF real or ARW.
#==================================================================================
#
    my ($proc, $rundir, $dfr, $ofr) = @_;

    my @delfls = @$dfr;
    my @outfls = @$ofr;

    &Others::rm($_) foreach @delfls;
    &Others::rm($_) foreach &Others::FileMatch($rundir,'^rsl\.',1,1);
    &Others::rm($_) foreach &Others::FileMatch($rundir,'Ready_d',1,1);
    &Others::rm($_) foreach &Others::FileMatch($rundir,'^namelist\.',1,1);

    foreach my $of (@outfls) {
        system "mv -f $_ $rundir/wrfprd/" foreach &Others::FileMatch($rundir,"^$of",1,1);
    }


return;
}  #  ProcessCleanup



sub ProcessInterrupt {
#==================================================================================
#  If the user becomes impatient and interrupts the active process by pulling 
#  a Control-C, then clean up the domain directory before exiting.
#==================================================================================
#
    my ($proc, $err, $rundir, $dfr, $ofr) = @_;

    my @delfls = @$dfr;
    my @outfls = @$ofr;

    &Others::rm($_) foreach @delfls;
    &Others::rm($_) foreach &Others::FileMatch($rundir,'Ready_',1,1);

    #----------------------------------------------------------------
    #  Save the rsl.* files to log/crash_rslfiles/ 
    #----------------------------------------------------------------
    #
    if ($err and $err != 2) {
        &Others::rm("$rundir/log/crash_rslfiles");
        &Others::mkdir("$rundir/log/crash_rslfiles");
        
        foreach my $rslfile (&Others::FileMatch($rundir,'rsl\.',1,1)) {
            if (-s $rslfile and open my $efh, '<', $rslfile) {
                my @lines = <$efh>; close $efh; foreach (@lines) {chomp $_; s/^\s+//g;s/\s+/  /g;}
                system "mv -f $rslfile $rundir/log/crash_rslfiles/" if grep {/Segmentation|Illegal|Interrupt|CFL|Floating|Namelist/i} @lines;
            }
        }
        system "mv -f $_ $rundir/log/crash_rslfiles/" foreach &Others::FileMatch($rundir,'^namelist\.',1,1);
    } 
    
    #----------------------------------------------------------------
    #  If the rsl * namelist files still exist in $rundir - Delete
    #----------------------------------------------------------------
    #
    &Others::rm($_) foreach &Others::FileMatch($rundir,'^rsl\.',1,1);
    &Others::rm($_) foreach &Others::FileMatch($rundir,'^namelist\.',1,1);

    if ($proc eq 'real') {
        &Others::rm($_) foreach &Others::FileMatch($rundir,'^wrfbdy_',1,1);
        &Others::rm($_) foreach &Others::FileMatch($rundir,'^wrffdda_',1,1);
        &Others::rm($_) foreach &Others::FileMatch($rundir,'^wrfinput_',1,1);
    }

    foreach my $of (@outfls) {
        system "mv -f $_ $rundir/wrfprd/" foreach &Others::FileMatch($rundir,"^$of",1,1);
    }


$err == 2 ? &Ecore::SysExit($err) : return;
}  #  ProcessInterrupt



sub RunCleaner {
#=====================================================================
#  This routine is the ems_run front end that calls the UEMS
#  cleaning utility.  Each one of the run-time routines should have 
#  a similar subroutine in its arsenal.  This routine should probably
#  be moved to the Eclean module, but I'm too lazy.
#=====================================================================
#
use Eclean;


    my ($level, $domain, $autorun) = @_; return unless $domain;

    return 0 if $autorun;  

    my @args = ('--domain',$domain,'--level',$level,'--silent');

return &Eclean::CleanDriver(@args);
}



sub Check4Success {
#==================================================================================
#  This routine checks for the existence of the "SUCCESS COMPLETE"
#  message in the passed logfile. Returns 1 if true, 0 if false.
#==================================================================================
#
    my $logfile = shift; return 1 unless -e $logfile;

    open (my $rfh, '<', $logfile); my @lines = <$rfh>;
 
return grep {/SUCCESS/i} @lines;
}


