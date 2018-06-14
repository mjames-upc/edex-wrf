#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Pinterp.pm
#
#  DESCRIPTION:  Pinterp contains each of the primary routines used for the 
#                interpolation of initialization datasets to the model
#                computational domain(s). For the WRF, this includes running
#                the metgrid program on the WPS intermediate files that 
#                were created when running ungrib.exe.
#                
#                This module is called from bothe the ems_autorun.pl or 
#                ems_prep.pl routines and returns a value to indicate success,
#                failure, or something in between.
#
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Pinterp;

use warnings;
use strict;
require 5.008;
use English;

use Others;


sub PrepInterpolation {
#==================================================================================
#  This routine 
#==================================================================================
#
use if defined eval{require Time::HiRes;} >0,  "Time::HiRes" => qw(time);

    my $upref     = shift; my %Uprep = %{$upref};

    #  Before we begin, make sure that the metgrid executable is available
    #
    unless (-s "$ENV{EMS_BIN}/metgrid") {
        my $mesg = "Failure is the only option - Missing $ENV{EMS_BIN}/metgrid";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,94,0,0,'Yes You Can!',$mesg);
        return ();
    }

    $Uprep{emsenv}{autorun} ? &Ecomm::PrintMessage(0,7,144,2,1,sprintf("%-4s AutoPrep: Horizontal interpolation of intermediate files to the computational domain",&Ecomm::GetRN($ENV{PRN}++)))
                            : &Ecomm::PrintMessage(0,4,144,2,1,sprintf("%-4s Horizontal interpolation of intermediate files to the computational domain",&Ecomm::GetRN($ENV{PRN}++)));

    #----------------------------------------------------------------------------------
    #  Enough with the preliminaries!  I want my Metgrid!
    #----------------------------------------------------------------------------------
    #
    my $secs   = time();
    return () if &MetgridInterpolation(\%Uprep);
    $secs = time()-$secs; $secs = 1 unless $secs;

    &Ecomm::PrintMessage(0,9+$Uprep{arf},144,1,1,sprintf ("Interpolation to computational domain completed in %s",&Ecomm::FormatTimingString($secs)));
 

return %Uprep;
}



sub MetgridInterpolation {
#==================================================================================
#  I'm not in the mood to explain this subroutine.
#==================================================================================
#
use List::Util qw( min max );

    my $upref     = shift; my %Uprep = %{$upref};

    my %conf     = %{$Uprep{parms}};
    my %sysinfo  = %{$Uprep{emsenv}{sysinfo}};
    my %emsrun   = %{$Uprep{rtenv}};
    my %masternl = %{$Uprep{masternl}};


    chdir $emsrun{dompath};  #  We should be here anyway but not risking it

    my $wpsnl   = "$emsrun{dompath}/namelist.wps";     #  Define the local namelist
    my $mlog1   = "$emsrun{logdir}/prep_metgrid1.log";
    my $mlog2   = "$emsrun{logdir}/prep_metgrid2.log";
    my $metgrid = "$ENV{EMS_BIN}/metgrid";
    my $metgtbl = $Uprep{initdsets}{ICS}->metgrid;  #  Don't like this here but its easiest


    #  Before we begin, make sure that the metgrid executable is available
    #
    unless (-s $metgrid) {
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,255,0,0,"You're too good for this:","Missing: $metgrid");
        return ();
    }

    #----------------------------------------------------------------------------------
    #  This test is probably not necessary, but make sure to turn ON the noaltsst
    #  parameter (1) if the simulation end_date - start_date is less than 24 hours.
    #  This is necessary because the avg_tsfc.exe routine will simply exit without
    #  writing a TAVGSFC file, which causes metgrid.
    #----------------------------------------------------------------------------------
    #
    unless ($conf{noaltsst}) {
        my $ssecs = &Others::CalculateEpochSeconds(&Others::DateStringWRF2DateString($masternl{SHARE}{start_date}[0]));
        my $esecs = &Others::CalculateEpochSeconds(&Others::DateStringWRF2DateString($masternl{SHARE}{end_date}[0]));
        $conf{noaltsst} = 1 if ($esecs-$ssecs)/3600 < 24;
    }


    unshift  @{$masternl{METGRID}{constants_name}}    => "\'$emsrun{wpsprd}/TAVGSFC\'"  unless $conf{noaltsst};
    push @{$masternl{METGRID}{constants_name}}        => "\'$conf{aerosols}\'"          if     $conf{aerosols};


    my $fgs = join ", " => @{$masternl{METGRID}{fg_name}};
    my $cos = join ", " => @{$masternl{METGRID}{constants_name}};
    my $std = join ", " => @{$masternl{SHARE}{start_date}};
    my $act = join ", " => @{$masternl{SHARE}{active_grid}};
    my $end = ($conf{global} and ! $conf{nudge}) ? $std : join ", " => @{$masternl{SHARE}{end_date}};


    #----------------------------------------------------------------------------------
    #  The namelist should be written to the top level of the domain directory
    #  and not /static; otherwise you will loose important information.
    #----------------------------------------------------------------------------------
    #
    open (my $lfh, '>', $wpsnl);
    print $lfh  "\&share\n",
                "  wrf_core    = $masternl{SHARE}{wrf_core}[0]\n",
                "  max_dom     = $masternl{SHARE}{max_dom}[0]\n",
                "  active_grid = $act\n",
                "  start_date  = $std\n",
                "  end_date    = $end\n",
                "  interval_seconds = $masternl{SHARE}{interval_seconds}[0]\n",
                "  opt_output_from_geogrid_path = $masternl{SHARE}{opt_output_from_geogrid_path}[0]\n",
                "  debug_level = $masternl{SHARE}{debug_level}[0]\n",
                "\/\n\n",

                "\&metgrid\n",
                "  io_form_metgrid = $masternl{METGRID}{io_form_metgrid}[0]\n",
                "  fg_name = $fgs\n",
                "  constants_name = $cos\n",
                "  opt_metgrid_tbl_path = $masternl{METGRID}{opt_metgrid_tbl_path}[0]\n",
                "  opt_output_from_metgrid_path = $masternl{METGRID}{opt_output_from_metgrid_path}[0]\n",
                "  process_only_bdy = $masternl{METGRID}{process_only_bdy}[0]\n",
                "\/\n\n";
    close $lfh;


    #----------------------------------------------------------------------------------
    #  Unless the noaltsst flag was passed then create the dataset by running 
    #  the avg_tsfc routine. The resulting intermediate file will be placed in 
    #  the wpsprd directory.
    #----------------------------------------------------------------------------------
    #
    unless ($conf{noaltsst}) {

        my $avgtsfc = "$ENV{EMS_UBIN}/avg_tsfc";
        my $tlog    = "$emsrun{logdir}/prep_avgtsfc.log";

        &Ecomm::PrintMessage(1,11+$Uprep{arf},144,1,0,"Calculating mean surface temperatures for missing water values");

        #  Otherwise, just run it like you stole it.
        #
        if (my $status = &Ecore::SysExecute($avgtsfc,$tlog)) {
            if ($status == 2) {&Ecomm::PrintMessage(0,1,96,0,2,"- Ouch!");  &Ecore::SysIntHandle();}
            &Ecomm::PrintMessage(0,1,96,0,2,sprintf("- Failed (%s)",&Ecore::SysReturnCode($status)));
            system "mv $emsrun{dompath}/logfile.log $tlog  > /dev/null 2>&1";
            return 1;
        }


        #  We're not safe yet - check log file for success message
        #
        open ($lfh, '<', $tlog); my @lines = <$lfh>; close $lfh;
        system "mv $emsrun{dompath}/logfile.log $tlog  > /dev/null 2>&1";

        unless (grep /Successful completion/i => @lines) {
            &Ecomm::PrintMessage(0,1,96,0,2,'- Failed');
            &Ecomm::PrintMessage(6,11+$Uprep{arf},144,1,1,"Not looking good - Check $tlog");
            &Ecomm::PrintMessage(0,14+$Uprep{arf},96,1,2,"Or try running:  % $avgtsfc");
            return 1;
        }
        &Ecomm::PrintMessage(0,1,96,0,1,"- Success");
        system "mv $emsrun{dompath}/TAVGSFC $emsrun{wpsprd}";
        &Others::rm($tlog);

    }

    #----------------------------------------------------------------------------------
    #  Time to run the metgrid routine, which is the first time we have to account
    #  for the number of CPUs allocated for use with the UEMS. The primary purpose
    #  for this bit of caution is to ensure that the domain is not over-decomposed,
    #  which may lead to a segmentation fault floating point error. There is another
    #  potential issue related to IO.
    #----------------------------------------------------------------------------------
    #
    my $hydra = 0;

    
    #----------------------------------------------------------------------------------
    #  Determine the number of CPUs to use when running metgrid, which is dependent
    #  upon the domain with the fewest number of grid points. This effort is necessary 
    #  so as not to over-decompose the domain which can cause problems.
    #----------------------------------------------------------------------------------
    #
    my $min_pts_per_patch = 8; #  Minimum number of grid points per patch side

    my $maxtime = $conf{timeout};
    my $maxcpus = $conf{ncpus}-1; #  Changed from $maxcpus to $maxcpus-1 in V18.0.8
    my $ncpus   = $maxcpus;

    foreach my $dom (@{$conf{reqdoms}}) {
        my $dimx = $masternl{GEOGRID}{e_we}[$dom-1];
        my $dimy = $masternl{GEOGRID}{e_sn}[$dom-1];
        my ($decomp_x, $decomp_y) = &Others::BestPatchDecomposition($maxcpus,$dimx,$dimy,$min_pts_per_patch,3);
        $ncpus = min ($ncpus, $decomp_x*$decomp_y) if $decomp_x*$decomp_y;
    }
   


    #----------------------------------------------------------------------------------
    #  Formulate the command to run
    #----------------------------------------------------------------------------------
    #
    my $mpiexec = $hydra ? "$ENV{EMS_MPI}/bin/mpiexec" : "$ENV{EMS_MPI}/bin/mpiexec.gforker";
    my $exe     = $hydra ? "$mpiexec -exitinfo -n $ncpus $metgrid"                   : $maxtime 
                         ? "$mpiexec -exitinfo -n $ncpus -maxtime $maxtime $metgrid" : "$mpiexec -exitinfo -n $ncpus $metgrid";

    #  Create a link from the default metgrid tables to the local directory
    #
    &Others::rm('METGRID.TBL'); symlink $metgtbl => 'METGRID.TBL';


    &Ecomm::PrintMessage(1,11+$Uprep{arf},114,1,0,"Interpolating fields to the computational domain ($ncpus CPUs)");

    if ($conf{debug} == 6) {
        &Ecomm::PrintTerminal(0,0,255,0,1,"- Preempted with \"--debug metgrid\"");
        &Ecomm::PrintTerminal(6,9,255,1,1,"Now seize the simulation by running:  % $exe");
        &Ecore::SysExit(98,$0);
    }



    #----------------------------------------------------------------------------------
    #  Just run it like you stole it. Should there be a failure then attempt to
    #  extract some information from the log files that will provide some help
    #  to the user. Some errors are caught by the system while others can only
    #  be detected by looking in the log files.
    #----------------------------------------------------------------------------------
    #
    if (my $status = &Ecore::SysExecute($exe, $mlog1)) {

        if ($status == 2) {&Ecomm::PrintMessage(0,1,96,0,2,"- Ouch!");  &Ecore::SysIntHandle();}

        open ($lfh, '<', $mlog1); my @lines = <$lfh>; close $lfh;
        if (grep /Timeout of (\d+ seconds)|Timeout of (\d+ minutes)/i => @lines) {
            &Ecomm::PrintMessage(0,1,96,0,2,"- Timeout after $maxtime seconds");
        } elsif (grep /Missing values encountered/ => @lines) {
            &Ecomm::PrintMessage(0,1,96,0,1,'- Failed (Drawing outside the lines again!)');
            &Ecomm::PrintMessage(6,11+$Uprep{arf},144,1,1,"Not looking good - Check $mlog1");
            my $mesg0 = 'Missing values encountered in the interpolated fields.';
            my $mesg1 = 'Make sure the areal coverage of your domain lies entirely within '.
                        'the initialization dataset.';
            &Ecomm::PrintMessage(0,14+$Uprep{arf},88,1,2,$mesg0,$mesg1);
        } elsif (grep /Cannot combine time-independent data/ => @lines) {
            &Ecomm::PrintMessage(0,1,96,0,1,'- Failed (Can\'t mix time-dependent with independent data)');
            &Ecomm::PrintMessage(6,11+$Uprep{arf},144,1,1,"Not looking good - Check $mlog1");
            my $mesg0 = 'It appears that one or more --sfc datasets (time-independent) already exists in '.
                        'your initial or boundary condition datasets (time-dependent), which is not allowed.';
            &Ecomm::PrintMessage(0,14+$Uprep{arf},88,1,2,$mesg0);
        } else {
            &Ecomm::PrintMessage(0,1,96,0,2,sprintf("- Failed (%s)",&Ecore::SysReturnCode($status)));
        }
        system "rm -f metgrid.log.* METGRID.TBL $wpsnl > /dev/null 2>&1";

        unless ($conf{nointdel}) {
            foreach (@{$masternl{METGRID}{fg_name}}, @{$masternl{METGRID}{constants_name}}) {
                s/\'//g;
                s/:\d\d\d\d-\d\d-\d\d.*$//g;
                my $key = &Others::popit($_);
                foreach my $file (&Others::FileMatch($emsrun{wpsprd},"^$key:",0,1)) {&Others::rm($file);}
            }
        }

        return 1;

    }


    #  Collect some of the information and write it to a second log file
    #
    my @mlogs   = ();
    push @mlogs => $wpsnl if -s $wpsnl;
    push @mlogs => "$emsrun{dompath}/metgrid.log.0000" if -s "$emsrun{dompath}/metgrid.log.0000";
    system "cat @mlogs > $mlog2" if @mlogs;
    

    #  We're not safe yet - check log file for success message
    #
    open ($lfh, '<', $mlog1); my @lines = <$lfh>; close $lfh;
    unless (grep /Successful completion/i => @lines) {

        if (grep /Timeout of (\d+ seconds)|Timeout of (\d+ minutes)/i => @lines) {
            &Ecomm::PrintMessage(0,1,96,0,2,"- Timeout after $maxtime seconds");
        } elsif (grep /Missing values encountered/ => @lines) {
            &Ecomm::PrintMessage(0,1,96,0,1,'- Failed');
            &Ecomm::PrintMessage(6,11+$Uprep{arf},144,1,1,"Not looking good - Check $mlog1");
            my $mesg0 = 'Missing values encountered in the interpolated fields.';
            my $mesg1 = 'Make sure the areal coverage of your domain lies entirely within '.
                        'the initialization dataset.';
            &Ecomm::PrintMessage(0,14+$Uprep{arf},88,1,2,$mesg0,$mesg1);
        } elsif (grep /Cannot combine time-independent data/ => @lines) {
            &Ecomm::PrintMessage(0,1,96,0,1,'- Failed (Can\'t mix time-dependent with independent data)');
            &Ecomm::PrintMessage(6,11+$Uprep{arf},144,1,1,"Not looking good - Check $mlog1");
            my $mesg0 = 'It appears that one or more --sfc datasets (time-independent) already exists in '.
                        'your initial or boundary condition datasets (time-dependent), which is not allowed.';
            &Ecomm::PrintMessage(0,14+$Uprep{arf},88,1,2,$mesg0);
        } else {
            &Ecomm::PrintMessage(0,1,96,0,2,'- Failed');
            &Ecomm::PrintMessage(6,11+$Uprep{arf},144,1,1,"Not looking good - Check $mlog1");
            &Ecomm::PrintMessage(0,14+$Uprep{arf},96,1,2,"Or try running:  % $exe");
        }
        system "rm -f $emsrun{dompath}/metgrid.log.* METGRID.TBL $wpsnl > /dev/null 2>&1";

        unless ($conf{nointdel}) {
            foreach (@{$masternl{METGRID}{fg_name}}, @{$masternl{METGRID}{constants_name}}) {
                s/\'//g;
                s/:\d\d\d\d-\d\d-\d\d.*$//g;
                my $key = &Others::popit($_);
                foreach my $file (&Others::FileMatch($emsrun{wpsprd},"^$key:",0,1)) {&Others::rm($file);}
            }
        }
        return 1;

    }
    &Ecomm::PrintMessage(0,1,96,0,1,"- Success");

    
    #----------------------------------------------------------------------------------
    #  While the information is fresh, update the static/namelist.wps file.
    #---------------------------------------------------------------------------------- 
    #
    if (&Others::Hash2Namelist($emsrun{wpsnl},"$ENV{EMS_DATA}/tables/wps/namelist.wps",%masternl) ) {
        my $file = "$ENV{EMS_DATA}/tables/wps/namelist.wps";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,84,0,0,'The Hash2Namelist routine',"BUMMER: Problem writing $file");
        return 1;
    }



    #----------------------------------------------------------------------------------
    #  Do some final cleanup
    #----------------------------------------------------------------------------------
    #
    system "rm -f metgrid.log.* METGRID.TBL $wpsnl > /dev/null 2>&1";

    unless ($conf{nointdel}) {
        foreach (@{$masternl{METGRID}{fg_name}}, @{$masternl{METGRID}{constants_name}}) {
            s/\'//g;
            s/:\d\d\d\d-\d\d-\d\d.*$//g;
            my $key = &Others::popit($_);
            foreach my $file (&Others::FileMatch($emsrun{wpsprd},"^$key:",0,1)) {&Others::rm($file);}
        }
    }


return;
}

