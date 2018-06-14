#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Pungrib.pm
#
#  DESCRIPTION:  Pungrib contains each of the primary routines used for the 
#                acquisition and preparation of datasets to be included in
#                the initialization of a numerical weather prediction (NWP)
#                simulation using the Unified Environmental Modeling System 
#                (UEMS).
#                
#                This module is called from both the ems_autorun.pl or 
#                ems_prep.pm routines and returns a value to indicate success,
#                failure, or something in between.
#
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Pungrib;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Uprep %masternl %conf %emsrun);

use Others;


sub PrepProcessGrib {
#==================================================================================
#  This routine processes the available GRIB files into an intermediate format.
#  If multiple datasets were specified for initialization then the number
#  of levels in each dataset are checked for consistency. Should one dataset
#  have more levels than the other then these data are thinned so that both 
#  are equal.
#==================================================================================
#

    my $upref     = shift; %Uprep = %{$upref};

    my %initdsets = %{$Uprep{initdsets}};
       %masternl  = %{$Uprep{masternl}};
       %emsrun    = %{$Uprep{rtenv}};
       %conf      = %{$Uprep{parms}};


    @{$masternl{METGRID}{fg_name}}        = ();
    @{$masternl{METGRID}{constants_name}} = ();


    $Uprep{emsenv}{autorun} ? &Ecomm::PrintMessage(0,7,144,2,1,sprintf("%-4s AutoPrep: Create the WPS intermediate format files",&Ecomm::GetRN($ENV{PRN}++)))
                            : &Ecomm::PrintMessage(0,4,144,2,1,sprintf("%-4s Create the WPS intermediate format files",&Ecomm::GetRN($ENV{PRN}++)));

    #  Before we begin, make sure that the ungrib executable is available
    #
    unless (-s "$ENV{EMS_BIN}/ungrib") {
        my $mesg = "Failure is the only option - Missing $ENV{EMS_BIN}/ungrib";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,255,0,0,'You can do this!',$mesg);
        return ();
    }


    my %intds  = ();
    my $secs   = time();

    foreach my $ds (qw(ICS BCS LSM SFC)) {

        next unless $initdsets{$ds};
    
        if (my $dstruct = $initdsets{$ds}) {

            my $dset = $dstruct->dset;
            my $nudg = $conf{nudging} ? '(w/nudging)' : '';

            &Ecomm::PrintMessage(1,11+$Uprep{arf},144,1,0,"Processing $dset file to initialize a global simulation")           if $dstruct->useid == 0;
            &Ecomm::PrintMessage(1,11+$Uprep{arf},144,1,0,"Processing $dset files for initial and boundary conditions $nudg")  if $dstruct->useid == 1;
            &Ecomm::PrintMessage(1,11+$Uprep{arf},144,1,0,"Processing $dset file for initial conditions")                      if $dstruct->useid == 2;
            &Ecomm::PrintMessage(1,11+$Uprep{arf},144,1,0,"Processing $dset files for lateral boundary conditions")            if $dstruct->useid == 3;

            return () if &GribToIntermediateWRF($dstruct);

            #----------------------------------------------------------------------------------
            #  If separate IC & BC datasets are used then capture some information while the
            #  opportunity exists. This info will be used to reconciling the number of vertical
            #  levels in the intermediate files for each dataset since they must be the same.
            #----------------------------------------------------------------------------------
            #
            if ($dstruct->useid == 2 or $dstruct->useid == 3) {

               my $useid = $dstruct->useid;  # Keep things simple

               #  1. Collect a list of intermediate files for the dataset.  Only one file
               #     is needed but it's easiest to gobble them all.
               #
               my $ucdset = uc $dset;
               $intds{$useid}{dset} = $ucdset;
               my @intrs = &Others::FileMatch($emsrun{wpsprd},"^${ucdset}:",0,0);


               #  2. Get information on the vertical coordinate, the number of levels in
               #     the dataset and a list of levels.
               #
               my %ldata = ();
               ($intds{$useid}{vcoord}, $intds{$useid}{nlevs}, %ldata) = &InterVerticalLevels($intrs[0]); return () if $ENV{PMESG};


               unless (@{$ldata{levels}}) {
                   $ENV{PMESG} = &Ecomm::TextFormat(0,0,94,0,0,"Unable to determine coordinate or number of vertical levels for $ucdset dataset");
                   return ();
               }
               @{$intds{$useid}{levels}} = @{$ldata{levels}};
               %{$intds{$useid}{pldata}} = %{$ldata{pldata}};

             
               #  Check whether the datasets are the same. They will almost always be different unless
               #  the user has passed something like --dset gfs%gfs. Additionally, we can get away with
               #  the following statement since the IC (2) will always come before the BCs (3).
               #
               %intds  = () if $useid == 3 and $intds{2}{nlevs} == $intds{3}{nlevs};  
            }

        }
    }
    return () if &ReconcileVerticalLevels(%intds);

    $secs = time()-$secs; $secs = 1 unless $secs;
    
    &Ecomm::PrintMessage(0,9+$Uprep{arf},144,1,1,sprintf ("Intermediate file processing completed in %s",&Ecomm::FormatTimingString($secs)));
 
    %{$Uprep{initdsets}} = %initdsets;
    %{$Uprep{masternl}}  = %masternl;


return %Uprep;
}



sub GribToIntermediateWRF {
#==================================================================================
#  This subroutine simply runs the WRF ungrib.exe routine to unpack the 
#  initialization dataset GRIB files and write them to an intermediate
#  format that is read during the horizontal interpolation.
#==================================================================================
#
    chdir $emsrun{dompath};  #  We should be here anyway but not risking it

    my $dstruct = shift;

    #  Some of the information we will need to determine the files needed to 
    #  download and initialize the simulation.
    #
    my $wpsnl      = "$emsrun{dompath}/namelist.wps";  #  Define the local namelist


    STRUCT: while (defined $dstruct) {

        #  No grib files to process?  Then just skip it.
        #
        unless (@{$dstruct->gribs}) {$dstruct = $dstruct->nlink;next;}

        #  Get the dataset names set
        #
        my $dset    = $dstruct->dset;
        my $lcdset  = lc $dstruct->dset;
        my $ucdset  = uc $dstruct->dset; $ucdset = "${ucdset}LSM" if $dstruct->useid == 4;
        my $ulog1   = "$emsrun{logdir}/prep_ungrib1-$dset.log";
        my $ulog2   = "$emsrun{logdir}/prep_ungrib2-$dset.log";


        #  These lines are not grouped with the others in the calling routine in order
        #  handle the linked lists of datasets used for surface and LSM datasets.
        #
        &Ecomm::PrintMessage(1,11+$Uprep{arf},144,1,0,"Processing $dset files for land surface model fields")     if $dstruct->useid == 4;
        &Ecomm::PrintMessage(1,11+$Uprep{arf},144,1,0,"Processing $dset files for surface fields")                if $dstruct->useid == 5;



        #  Get the start and stop times for the dataset being degribbed. This is not necessarily
        #  the start and stop times of the model run; but rather, the period of the dataset.
        #
        my ($start,$stop) = (0,0);

        if ($dstruct->useid == 0) {$start = &Others::CalculateNewDate($dstruct->sim00hr, 0); $stop = $start;}
        if ($dstruct->useid == 1) {$start = &Others::CalculateNewDate($dstruct->sim00hr, 0); $stop = &Others::CalculateNewDate($dstruct->sim00hr, $dstruct->length*3600);}
        if ($dstruct->useid == 2) {$start = &Others::CalculateNewDate($dstruct->sim00hr, 0); $stop = $start;}
        if ($dstruct->useid == 2 and $conf{nudging}) {$start = &Others::CalculateNewDate($dstruct->sim00hr, 0); $stop = &Others::CalculateNewDate($dstruct->sim00hr, $dstruct->length*3600);}
        if ($dstruct->useid == 3) {$start = &Others::CalculateNewDate($dstruct->sim00hr, $dstruct->freqfh*3600); $stop = &Others::CalculateNewDate($dstruct->sim00hr, $dstruct->length*3600);}
        if ($dstruct->useid == 4) {$start = &Others::CalculateNewDate($dstruct->sim00hr, 0); $stop = &Others::CalculateNewDate($dstruct->sim00hr, $dstruct->length*3600);}
        if ($dstruct->useid == 5) {$start = $dstruct->yyyymmddcc; $stop = $start;}

        $start   = &Others::DateString2DateStringWRF(substr($start,0,10));
        $stop    = &Others::DateString2DateStringWRF(substr($stop,0,10));

        my $intrs = $conf{hiresbc} ? 3600 : $dstruct->freqfh*3600;

        #  Save the bc data frequency for metgrid
        #
        $masternl{SHARE}{interval_seconds}[0] = $intrs if $dstruct->useid == 1 or $dstruct->useid == 3;

        
        #------------------------------------------------------------------------------------- 
        #  Do some initial clean up of the runtime and wpsprd directories prior to writing 
        #  any files. The UEMS demigods appreciate a tidy house. 
        #-------------------------------------------------------------------------------------
        #
        system "rm -f $emsrun{dompath}/GRIBFILE.??? $emsrun{dompath}/Vtable $ulog1 $ulog2 $wpsnl > /dev/null 2>&1";
        opendir (my $dfh, $emsrun{wpsprd}); foreach (readdir $dfh) {&Others::rm("$emsrun{wpsprd}/$_") if /^PFILE/;} closedir $dfh;


        #-------------------------------------------------------------------------------------
        #  Begin the pre "running of the ungrib" festivities by creating a link "GRIBFILE.???"
        #  to each of the GRIB files, followed by the ceremonial "writing of the namelist 
        #  file."  A good time will be had by all.
        #-------------------------------------------------------------------------------------
        #
        my $ID = 'AAA';
        foreach my $grib (sort @{$dstruct->gribs}) {symlink $grib, "$emsrun{dompath}/GRIBFILE.$ID"; $ID++;}

        symlink $dstruct->useid == 4 ? $dstruct->lvtable : $dstruct->vtable => 'Vtable';


        #  The namelist should be written to the top level of the domain directory
        #  and not /static; otherwise you will loose important information.
        #
        open (my $lfh, '>', $wpsnl);
        print $lfh  "\&share\n",
                     "  start_date = \'$start\'\n",
                     "  end_date   = \'$stop\'\n",
                     "  interval_seconds = $intrs\n",
                     "  debug_level = 0\n",
                     "\/\n\n",

                     "\&ungrib\n",
                     "  out_format = \'WPS\'\n",
                     "  prefix     = \'$emsrun{wpsprd}/$ucdset\'\n",
                     "\/\n\n"; 
        close $lfh;

        #-------------------------------------------------------------------------------------
        #  Time to run ungrib. If the user is running in debug mode then drop out now
        #  while providing some guidance.
        #-------------------------------------------------------------------------------------
        #
        my $ungrib = "$ENV{EMS_BIN}/ungrib";

        if ($conf{debug} == 5) {
            &Ecomm::PrintTerminal(0,0,255,0,1,"- Preempted with \"--debug ungrib\"");
            &Ecomm::PrintTerminal(6,9,255,1,1,"Now seize the simulation by running:  % $ungrib");
            &Ecore::SysExit(98,$0);
        }


        #  Otherwise, just run it like you stole it.
        #
        if (my $status = &Ecore::SysExecute($ungrib, $ulog1)) {
            if ($status == 2) {&Ecomm::PrintMessage(0,1,96,0,2,"- Ouch!");  &Ecore::SysIntHandle();}
            &Ecomm::PrintMessage(0,1,96,0,2,sprintf("- Failed (%s)",&Ecore::SysReturnCode($status)));
            return 1;
        }

        #  We're not safe yet - check log file for success message
        #
        open ($lfh, '<', $ulog1); my @lines = <$lfh>; close $lfh;
        unless (grep /Successful completion/i => @lines) {
            &Ecomm::PrintMessage(0,1,96,0,2,'- Failed');
            &Ecomm::PrintMessage(6,11+$Uprep{arf},144,1,1,"Not looking good - Check $ulog1");
            my $mesg = "Make sure that the date/time in the nnrp2d file reflects the implied ".
                       "time in the filename. You might have to rename the files.";
            &Ecomm::PrintMessage(0,14+$Uprep{arf},96,0,1,$mesg) if $dset eq 'nnrp2d';
            &Ecomm::PrintMessage(0,14+$Uprep{arf},96,1,2,"Or try running:  % $ungrib");
            return 1;
        }
        &Ecomm::PrintMessage(0,1,96,0,1,"- Success");

        
        #  A quick clean up before the parents get home!
        #
        system "mv $emsrun{dompath}/ungrib.log  $ulog2  > /dev/null 2>&1";
        system "rm -f $emsrun{dompath}/GRIBFILE.??? $emsrun{dompath}/Vtable $wpsnl > /dev/null 2>&1";
        opendir ($dfh, $emsrun{wpsprd}); foreach (readdir $dfh) {&Others::rm("$emsrun{wpsprd}/$_") if /^PFILE/;} closedir $dfh;


        #-------------------------------------------------------------------------------------
        #  Before we move on we need to populate the master namelist hash for running metgrid. 
        #  This is really the only place for this step because we need to include all the data
        #  sets that were processed.
        #-------------------------------------------------------------------------------------
        #
        if ($dstruct->useid == 4) {
            push  @{$masternl{METGRID}{fg_name}} => "\'$emsrun{wpsprd}/$ucdset\'"; 
        } elsif ($dstruct->useid == 5) {
            my $sd = substr($start,0,16);
            unshift @{$masternl{METGRID}{constants_name}} => "\'$emsrun{wpsprd}/$ucdset:$sd\'";
        } else {
            push @{$masternl{METGRID}{fg_name}} => "\'$emsrun{wpsprd}/$ucdset\'";
        }
        $dstruct = $dstruct->nlink;

    }


return;
}


sub ReconcileVerticalLevels {
#==================================================================================
#  The WRF real.exe program requires that the number of vertical levels be the
#  same for the IC and BC datasets. Normally this is not a problem since they 
#  originate from the same dataset, but occasionally users want to get wild &
#  crazy by using different datasets with a mix of coordinate systems and levels.
#  This routine solves their potential problems.
#
#  WHAT THE WPS GUIDANCE TELLS US (Liberated from the July 2016 User's Guide)
#
#    Removing all but a specified subset of levels from meteorological datasets 
#    is particularly useful, for example, when one dataset is to be used for the 
#    model initial conditions and a second dataset is to be used for the lateral 
#    boundary conditions. This can be done by providing the initial conditions 
#    dataset at the first time period to be interpolated by metgrid, and the 
#    boundary conditions dataset for all other times. 
#
#    If the both datasets have the same number of vertical levels, then no work 
#    needs to be done; however, when these two datasets have a different number 
#    of levels, it will be necessary, at a minimum, to remove (m – n) levels, 
#    where m > n and m and n are the number of levels in each of the two datasets, 
#    from the dataset with m levels. The necessity of having the same number of 
#    vertical levels in all files is due to a limitation in real.exe, which 
#    requires a constant number of vertical levels to interpolate from.
#
#    The modlevs utility is something of a temporary solution to the problem of 
#    accommodating two or more datasets with differing numbers of vertical levels. 
#    Should a user choose to use modlevs, it should be noted that, although the 
#    vertical locations of the levels need not match between datasets, all data 
#    sets should have a surface level data, and, when running real.exe and 
#    wrf.exe, the value of p_top must be chosen to be below the lowest top among 
#    the datasets. 
#
#  UEMS DEVELOPERS NOTE
#
#    A problem exists in that ems_prep does not know the model top pressure
#    (PTOP) to be used in the simulation, which is located in the run_levels.conf
#    file. This information is important when working with initialization data
#    sets that extend above the default PTOP setting of 5000 pascals. In some
#    cases the routine below will thin levels that reside within the model
#    computational domain to ensure an even distribution between the surface
#    and upper limit of the pressure surfaces contained within the datasets.
#    for example, with 2 datasets that extend to 100 pascals but with a different
#    number of vertical levels, lower levels from the dataset with the greater 
#    number of levels may be sacrificed to retain levels above 5000 pascals,
#    even when these levels will not be used.
#
#    A kludge for this potential problem is to set a hard limit of 3000 pascals
#    and hope someone does not want to run a simulation with a PTOP above. 
#==================================================================================
#
use List::Util qw( min max );

    my %intds = @_; return unless %intds;

    my $PTOP_KLUDGE = 3000.;

    chdir $emsrun{dompath};  #  We should be here anyway but not risking it


    #  Determine which dataset is carrying the greater number of levels
    #
    my $dsmax = $intds{2}{nlevs} > $intds{3}{nlevs} ? 2 : 3;
    my $dsmin = $intds{2}{nlevs} > $intds{3}{nlevs} ? 3 : 2;

    my $maxlevs = $intds{$dsmax}{nlevs}-1; #  Subtract 1 for surface levels
    my $minlevs = $intds{$dsmin}{nlevs}-1; #  Subtract 1 for surface levels

    my $mesg = "Reconciling the number of levels between the $intds{$dsmax}{dset} ($maxlevs) and ".
               "$intds{$dsmin}{dset} ($minlevs) datasets.";
    &Ecomm::PrintMessage(1,11+$Uprep{arf},255,1,1,$mesg);


    my $modlevs = "$ENV{EMS_BIN}/modlevs";
    unless (-s $modlevs) {
        my $mesg = "Failure is your only option - Missing $modlevs";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,94,0,0,'Come on, you can do this!',$mesg);
        return 1;
    }


    #  There are 2 datasets MAX and MIN. MAX represents the dataset with the greater 
    #  number of levels, while MIN represents the dataset with the fewer levels. The 
    #  number of levels in MAX (#MAX) must be reduced to the total number in MIN (#MIN).
    #  Only the total number of levels is important; however, when thinning MAX down
    #  to #MIN levels, attempt to remove levels evenly over the entire range of values
    #  rather than taking #MAX-#MIN levels from a single area.  The purpose of this
    #  process is to create a list (array) of #MIN levels from MAX that will be used
    #  when running modlevs.
    #
    my @sfclevs_MAX = grep {$_ >= 200000} @{$intds{$dsmax}{levels}};
    my @plevels_MAX = sort {$a <=> $b} keys %{$intds{$dsmax}{pldata}};

    my @modlevs_MIN = grep {$_ <  200000} @{$intds{$dsmin}{levels}};
    my @plevels_MIN = sort {$a <=> $b} keys %{$intds{$dsmin}{pldata}};


    #  So many possibilities/options for reducing the number of levels. Start by
    #  removing any levels above the lower upper level in the two datasets. If
    #  the pressure is above $PTOP_KLUDGE then set to $PTOP_KLUDGE.
    #
    my $ltop = max (max ($plevels_MAX[0], $plevels_MIN[0]), $PTOP_KLUDGE);
    shift @plevels_MAX while @plevels_MAX > @plevels_MIN and $plevels_MAX[1] < $ltop;


    #  If the number of levels in MAX still exceeds the number in MIN then:
    #
    #    1. Determine which levels are shared between the two datasets. The number will be
    #       somewhere between 0 and #MIN. Use that subset and then add levels from MAX until 
    #       there are #MIN levels. To add levels, begin closest to the surface and move 
    #       upward through the atmosphere adding a level from MAX then skip the next level
    #       in MAX. Once all the levels in MAX are exhausted, begin again with the skipped
    #       levels.
    #
    #    2. To ensure maximum resolution is retained within the lower troposphere, a pressure
    #       level of 60000 pascals is arbitrarily set below which all level data will be 
    #       retained.
    #
    my @modlevs_KEEP = sort {$b <=> $a} &Others::ArrayIntersection(@plevels_MAX,@plevels_MIN);
    my @modlevs_AVLB = sort {$b <=> $a} &Others::ArrayMissing(\@plevels_MAX,\@plevels_MIN);

    while (@modlevs_KEEP < @modlevs_MIN) {
        push @modlevs_KEEP => shift @modlevs_AVLB; 
        push @modlevs_AVLB => shift @modlevs_AVLB if $modlevs_KEEP[-1] < 60000;
    }
    @modlevs_KEEP = sort {$b <=> $a} @modlevs_KEEP;


    #  We have the final list or pressure levels to keep but want the list of levels
    #  for modlevs.  If the dataset to be thinned is on pressure surfaces then we
    #  have what we need; otherwise, we need to get the actual levels.
    #
    my @modlevs_FINAL = @sfclevs_MAX;
    push @modlevs_FINAL => $intds{$dsmax}{pldata}{$_} foreach sort {$b <=> $a} @modlevs_KEEP;

 
    #----------------------------------------------------------------------------------
    #  Now run modlevs (mod_levs) to reduce the number of vertical levels in the 
    #  WRF intermediate file. This is only done for the dataset with the greater
    #  number of levels. While it appears that it is possible to use the same 
    #  input & output file names, play it safe and append _reduced to the output
    #  file and then rename the file afterwards.
    #----------------------------------------------------------------------------------
    #
    my $wpsnl = "$emsrun{dompath}/namelist.wps";  #  Define the local namelist
    my $log   = "$emsrun{logdir}/prep_modlevs-$intds{$dsmax}{dset}.log";

    my $lstr  = join ', ' => @modlevs_FINAL;
    &Ecomm::PrintMessage(0,14+$Uprep{arf},88,1,1,"$intds{$dsmax}{vcoord} levels to be retained in the $intds{$dsmax}{dset} dataset:",$lstr);


    #------------------------------------------------------------------------------------- 
    #  Do some initial clean up of the runtime and wpsprd directories prior to writing 
    #  any files. The UEMS demigods appreciate a tidy house. 
    #-------------------------------------------------------------------------------------
    #
    system "rm -f $log $wpsnl > /dev/null 2>&1";
    my @intrs = &Others::FileMatch($emsrun{wpsprd},"^$intds{$dsmax}{dset}:",0,0);


    #  The namelist should be written to the top level of the domain directory
    #  and not /static; otherwise you will loose important information. Additionally,
    #  there is no need to write out the file multiple times.
    #
    $lstr =~ s/ //g;
    open (my $lfh, '>', $wpsnl);
    print $lfh  "\&mod_levs\n",
                 "  press_pa = $lstr\n",
                 "\/\n\n";
    close $lfh;

 
    #-------------------------------------------------------------------------------------
    #  Loop through the list of intermediate files and begin thinning with modlevs.
    #  If the user is running in debug mode then drop out while providing some guidance.
    #-------------------------------------------------------------------------------------
    #
    if ($conf{debug} == 7) {
        my $inter = &Others::popit($intrs[0]);
        &Ecomm::PrintTerminal(0,0,255,0,1,"- Preempted with \"--debug modlevs\"");
        &Ecomm::PrintTerminal(6,9,255,1,1,"Now seize the simulation by running:  % $modlevs $intrs[0] $inter");
        &Ecore::SysExit(98,$0);
    }


    foreach my $intfile (@intrs) {


        #-------------------------------------------------------------------------------------
        #  At this point the $intfile includes the absolute path to the wpsprd directory, which in 
        #  some casts might be too long for modlevs to ingest. Better to create a link to the file.
        #  Also, write the outfile to the local directory and then move it to the wpsprd directory
        #  afterwards.
        #-------------------------------------------------------------------------------------
        #
        my $link =  &Others::popit($intfile);

        &Others::rm($link);
        &Others::rm("${link}_reduced");

        symlink $intfile => $link;

        #  Just run it like you stole it.
        #
        my $cmd = "$modlevs $link ${link}_reduced";

        if (my $status = &Ecore::SysExecute($cmd, $log)) {
            if ($status == 2) {&Ecomm::PrintMessage(0,1,96,0,2,"- Ouch!");  &Ecore::SysIntHandle();}
            my $intfile = &Others::popitlev($intfile,1);
            $cmd = "$modlevs $intfile ${intfile}_reduced";  #  Shortening 
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,94,0,0,sprintf("$cmd - Failed (%s)",&Ecore::SysReturnCode($status)));
            return 1;
        }


        #  We're not safe yet - check log file for success message
        #
        open ($lfh, '<', $log); my @lines = <$lfh>; close $lfh;
        unless (grep /Successful completion/i => @lines) { 
            my $intfile = &Others::popitlev($intfile,1);
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,94,0,0,"This is not looking good - Check $log","And try running:   %  $modlevs   $intfile   ${intfile}_reduced");
            return 1;
        }
        system "mv ${link}_reduced $intfile";
        &Others::rm($link);

    }
    &Others::rm($wpsnl);


return;
}



sub InterVerticalLevels {
#==================================================================================
#  This routine takes the name of an WRF WPS intermediate file and returns the
#  levels (pressure) contained in that file as an array.
#==================================================================================
#
    #  Before we begin, make sure that the rdwrfin executable is available
    #
    my $rdwrfin = "$ENV{EMS_UBIN}/rdwrfin";

    unless (-s $rdwrfin) {
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,94,0,0,'You can do this!',"Failure is your only option - Missing $rdwrfin");
        return ();
    }

    my $intfile = shift;

    #----------------------------------------------------------------------------------
    #  Extract the vertical level information from the file. The surface information needs to
    #  be segregated from the other levels for the time being. Note that the regex statement 
    #  below will likely not work for sigma coordinate data because it is looking for values
    #  greater than 0.
    #----------------------------------------------------------------------------------
    #
    my @vlevels=();
    my @slevels=();

    #  Read the contents of the intermediate file into an array rather than as part of a 
    #  foreach loop since the contents may be needed again.
    #
    my @intlines = `$rdwrfin $intfile`; chomp foreach @intlines;
    
    foreach (@intlines) {if (/LEVEL = (\d+)[\.| ]/g) {$1 < 200000 ? push @vlevels => $1 : push @slevels => $1;}}

    @slevels = sort {$a <=> $b} &Others::rmdups(@slevels);
    @vlevels = sort {$a <=> $b} &Others::rmdups(@vlevels);

    #  Now to get creative and attempt to determine the type of coordinate system from the values
    #  in the @vlevels array.  This approach may not be perfect but we only need to consider
    #  a few coordinates.  
    #
    my @levels = ();
    my $vcoord = 'unknown';
    my $vrange = $vlevels[$#vlevels] - $vlevels[0];

    $vcoord = 'pressure'   if $vrange > 600;
    $vcoord = 'isentropic' if $vrange < 550;
    $vcoord = 'hybrid'     if $vrange < 200;
    $vcoord = 'sigma'      if $vrange <= 1.0;   # Assume Sigma coordinate specified as 0 .. 1

    @levels = ($vcoord eq 'pressure' or $vcoord eq 'sigma') ? sort { $b <=> $a } @vlevels : sort { $a <=> $b } @vlevels;

    my $nlevels = @slevels ? @vlevels + 1 : @vlevels;


    #----------------------------------------------------------------------------------
    #  If this is not a pressure level dataset, we need to get the pressure on the levels
    #  defined in the dataset. This information will be used used when attempting to reduce
    #  levels in one dataset to match the other (in another subroutine).  The code below 
    #  assumes a certain order for the fields/lines in the output from rdwrfin which
    #  is "FIELD =" near the top, followed by "LEVEL =" and then "MIN = xxx, MAX = xxx".
    #  Note that the MIN & MAX line is added to rdwrfin for the UEMS.
    #----------------------------------------------------------------------------------
    #
    my %ldata =();
    my %pldata=();

    if ($vcoord ne 'pressure') { 
        my $pfield = 0;
        my $levl   = 0;
        foreach (@intlines) {
            if (/FIELD = (\D*)/)      {$pfield = ($1 =~ /PRESS/i) ? 1 : 0;} next unless $pfield;
            if (/LEVEL = (\d+\.\d+)/) {$levl = $1;}
            if (/MIN = (\d+\.\d+)/)   {$pldata{int $1} = $vcoord eq 'sigma' ? $levl : int $levl; $pfield=0;}
        }
    } else { #  Pressure level data - the trivial solution
        $pldata{$_} = $_ foreach @levels;
    }

    @{$ldata{levels}} = (@slevels,@levels);
    %{$ldata{pldata}} = %pldata;
   
 
return ($vcoord, $nlevels, %ldata);
}


