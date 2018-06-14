#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Pconf.pm
#
#  DESCRIPTION:  Pconf contains each of the primary routines used for the
#                final configuration of ems_prep. It's the least elegant of
#                ems_prep modules simply because there is a lot of sausage
#                making going on.
#
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Pconf;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Uprep %Info);

use Pginfo;
use Pstructs;
use Putils;


sub PrepConfiguration {
#==================================================================================
#  The main driver for each of the configuration subroutines. For ems_prep:
#
#    1. Read the information contained in the gribinfo files
#    2. Do the final checks of the configuration file parameters
#    3. Set the UEMS autorun environment
#    4. Collect information from the master namelist file.
#    5. Set the final %Uprep hash for use by ems_prep
#==================================================================================
#
use Pfinal;
use Pginfo;


    %Info = ();  #  Initialize the Info hash, which is available to all 
                 #  subroutines within this module.

    my $upref    = shift; %Uprep = %{$upref};

    #-------------------------------------------------------------------------------
    #  Collect the information contained within the GRIB information files.
    #-------------------------------------------------------------------------------
    #
    return () unless %{$Uprep{ginfo}} = &Pginfo::CollectGribInfo();


    #-------------------------------------------------------------------------------
    #  Collect information on the local domain configuration
    #-------------------------------------------------------------------------------
    #
    return () unless %{$Uprep{parms}} = &Pfinal::PrepFinalConfiguration(\%Uprep);

    
    #-------------------------------------------------------------------------------
    #  Assign the information just collected %{$Uprep{parms}} to %Info
    #-------------------------------------------------------------------------------
    #
    %{$Info{conf}} = %{$Uprep{parms}};


    return () unless %{$Uprep{initdsets}} = &InitializationDataSets();
    return () unless %{$Uprep{masternl}}  = &UpdateMasterNamelist();


    #-------------------------------------------------------------------------------
    #  Probably a good time to do the initial clean-up of the domain directory
    #-------------------------------------------------------------------------------
    # 
    return () if &Putils::PrepCleaner($Uprep{parms}{scour},$Uprep{rtenv}{dompath},$Uprep{emsenv}{autorun});


    #  Provide some general information about the Initialization
    #
    $Uprep{emsenv}{autorun} ? &Ecomm::PrintMessage(0,7,144,1,1,sprintf("%-4s AutoPrep: UEMS ems_prep Simulation Initialization Summary",&Ecomm::GetRN($ENV{PRN}++))) :
    $Uprep{emsenv}{mc}      ? &Ecomm::PrintMessage(0,4,144,1,1,sprintf("%-4s Initialization Dataset Summary",&Ecomm::GetRN($ENV{PRN}++)))    :
                              &Ecomm::PrintMessage(0,4,144,1,1,sprintf("%-4s UEMS ems_prep Simulation Initialization Summary",&Ecomm::GetRN($ENV{PRN}++)));


    $Uprep{emsenv}{autorun} ? &Ecomm::PrintMessage(0,14,144,2,1,&Ecomm::TextFormat(0,0,144,0,0,&Putils::PrepFormatSummary(\%Info)))   :
    $Uprep{emsenv}{mc}      ? &Ecomm::PrintMessage(0,11,144,1,1,&Ecomm::TextFormat(0,0,144,0,0,&Putils::PrepFormatSummary(\%Info)))   :
                              &Ecomm::PrintMessage(0,11,144,2,1,&Ecomm::TextFormat(0,0,144,0,0,&Putils::PrepFormatSummary(\%Info)));

 
return %Uprep;
}



sub InitializeDataSet {
#==================================================================================
#  This routine takes input from the --dsets, --lsm and --sfc options, parses out
#  the dataset to be used, opens and reads the appropriate _gribinfo.conf file,
#  and then populates a hash with all the default information.
#==================================================================================
#
use Class::Struct;

    my $ghome = $Uprep{rtenv}{grbdir};

    my ($fstruct,$cstruct);

    my ($dslist, $useid) = @_;

 
    #----------------------------------------------------------------------------------
    #  Split the list at each pipe "|". This is done to handle both LSM and SFC
    #  datasets but should not impact IC or BC datasets.
    #----------------------------------------------------------------------------------
    #
    foreach my $dsinfo (split /\|/ => $dslist) {

        my ($dset,$method,$host,$path) = split /:/ => $dsinfo, 4;  foreach ($method,$host,$path) {$_ = '' unless $_};

        unless (defined $Uprep{ginfo}{$dset}) {
            my $mesg = "The dataset that you are attempting to use ($dset) is not supported by the UEMS. The System ".
                       "Elders expect only perfection from you, so next time do a better job and make us proud; otherwise, ".
                       "we are going to lay a big guilt trip on you (again).\n\n".
    
                       "Here's a hint: Try using the \"--dslist\" flag to view a list of supported datasets.";

            $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,0,"You've come so far, yet have so far to go!",$mesg);
            return '';
        }

        my %gribinfo = %{$Uprep{ginfo}{$dset}};


        #----------------------------------------------------------------------------------
        #  Do a final check to make sure the values in the files are appropriate
        #----------------------------------------------------------------------------------
        #
        if ($useid < 4 and $gribinfo{maxfreq} > $gribinfo{freqfh}) {

            #  If maxfreq > freqfh then the user has been messing with the file.
            #
            my $mesg = "The value of MAXFREQ ($gribinfo{maxfreq}) is greater than FREQFH ($gribinfo{freqfh}) in ".
                       "the $dset configuration file ($gribinfo{gfile}). The simulation will continue but if you ".
                       "encounter problems I'm not taking the blame.";
    
            &Ecomm::PrintMessage(6,6+$Uprep{arf},88,1,2,'Just letting you know:',$mesg);
    
            $gribinfo{maxfreq} =  $gribinfo{freqfh};
        }


        if (($useid == 4 or $useid == 5) and $gribinfo{category} !~ /surface/i) {
            my $opt = ($useid == 4) ? '--lsm' : '--sfc';
            my $uds = uc $dset;
            my $mesg = "The $uds dataset can not be used with the $opt option";
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,0,'From your personal UEMS:',$mesg);
            return '';
        }

        #----------------------------------------------------------------------------------
        #  If this is a global simulation then use useid = 0, just because, that's why
        #----------------------------------------------------------------------------------
        #
        $useid = 0 if $Uprep{parms}{global} and $useid < 4;
    
    
        #----------------------------------------------------------------------------------
        #  If using --analysis flag the BCMAXFQ value will need to reflect the time 
        #  between cycles.
        #
        #  I hate using a global variable here but the maxfreq for the BC dataset is
        #  needed for the initialization dataset.
        #----------------------------------------------------------------------------------
        #
        $Uprep{parms}{bcmaxfq} = ($useid == 3) ? $gribinfo{maxfreq}+=0 : 0;


        my ($nfs, $ftp, $http, $https) = (1, 1, 1, 1);
        #---------------------------------------------------------------------------------------
        #  Handle the condition where the user has overridden the server, method, and location
        #  information in the GRIB info file from the command line.
        #---------------------------------------------------------------------------------------
        #
        if ($method or $host or $path) {
    
            if ($host and $host =~ /\//) {$path = $host; $host = 'LOCAL';}
            $host = 'LOCAL' if $host and $host =~ /^local/i;
            unless ($host) {$host = 'LOCAL' if $method and lc $method eq 'nfs' and $path;}

            $nfs   = ($method and (grep /^$method$/i, qw(none nonfs  ftp http https))) ? 0 : 1;
            $ftp   = ($method and (grep /^$method$/i, qw(none noftp  nfs http https))) ? 0 : 1;
            $http  = ($method and (grep /^$method$/i, qw(none nohttp nfs ftp)))  ? 0 : 1;
            $https = ($method and (grep /^$method$/i, qw(none nohttp nfs ftp)))  ? 0 : 1;

            #  Resolve the hostname if included
            #
            $host = &Pginfo::ResolveHostKey($host,%{$Uprep{HKEYS}}) if $host;
    
    
            if ($method and $host and $path) {

                #----------------------------------------------------------------------------------
                #  Special case when user specifies method, host and location.
                #  Turn off all methods but define source here.
                #----------------------------------------------------------------------------------
                #
                delete $gribinfo{sources}{FTP};
                delete $gribinfo{sources}{HTTP};
                delete $gribinfo{sources}{HTTPS};
                delete $gribinfo{sources}{NFS};
    
                $gribinfo{sources}{FTP}{$host}   = $path if $ftp;
                $gribinfo{sources}{HTTP}{$host}  = $path if $http;
                $gribinfo{sources}{HTTPS}{$host} = $path if $https;
                $gribinfo{sources}{NFS}{$host}   = $path if $nfs;
            }

            
            #  If a host was specified then make sure the other hostnames are culled
            #
            if ($host) {
                foreach my $meth (qw(FTP HTTP HTTPS NFS)) {
                    if (defined $gribinfo{sources}{$meth}{$host}) {
                        my $hpath = $gribinfo{sources}{$meth}{$host};
                        delete $gribinfo{sources}{$meth};
                        $gribinfo{sources}{$meth}{$host} = $hpath;
                    }
                }
            }
                 

        }  #  if ($method or $host or $path)


        #----------------------------------------------------------------------------------
        #  If this is a personal tile dataset set HTTP method to PTILE and delete the
        #  HTTP hash entries.
        #----------------------------------------------------------------------------------
        #
        if ($gribinfo{ptile}) {
            %{$gribinfo{sources}{PTILE}} = %{$gribinfo{sources}{HTTP}};
            %{$gribinfo{sources}{HTTP}}  = ();
        }



        #---------------------------------------------------------------------------------------
        #  Command line override checks completed
        #---------------------------------------------------------------------------------------
        #
        delete $gribinfo{sources}{FTP}   unless $ftp;
        delete $gribinfo{sources}{HTTP}  unless $http;
        delete $gribinfo{sources}{HTTPS} unless $https;
        delete $gribinfo{sources}{NFS}   unless $nfs;

        unless (%{$gribinfo{sources}}) {
            unless ($method eq 'none') {
                my $mesg = "It appears that there are no sources available for the $dset initialization files. ".
                           "Maybe you went a bit crazy with the command line flags & arguments and failed to ".
                           "appreciate their power, or you possibly out-thunk yourself while editing the ".
                           "$gribinfo{gfile} file. Regardless, unless the files already reside in the grib ".
                           "directory with the proper filenames, you are going to get nothing and like it.";
                &Ecomm::PrintMessage(6,6+$Uprep{arf},92,1,2,'I hope you know what you are doing!',$mesg);
            }
            $gribinfo{sources}{NFS}{local} = "$ghome/$gribinfo{locfil}";
            $method = 'none';  #  Make sure $method equals 'none' as though the --local flag was passed.
        }

        #  If the --nodelay flag has been passed
        #
        $gribinfo{delay} = 0 if $Uprep{parms}{nodelay};

        
        #----------------------------------------------------------------------------------
        #  If the analysis flag was passed, there are multiple fields that must be changed from the
        #  default gribinfo file information, initfh and freqfh. The initfh is changed since the 
        #  user defined the value as an argument to --analysis (0-hour default) and freqfh is now
        #  the period of time between cycles and not forecasts.
        #
        #  Oh yes, the category is changed to "Analysis" and maxfreq gets the same value as freqfh.
        #----------------------------------------------------------------------------------
        #
        if ($Uprep{parms}{analysis} >= 0 or $gribinfo{category} =~ /^anal/i) {

            my @ac=();
            foreach (sort @{$gribinfo{cycles}}) {

                #----------------------------------------------------------------------------------
                #  It is assumed that there is an equal delta between cycle times
                #  Otherwise stuff fails.
                #----------------------------------------------------------------------------------
                #
                my ($c, $z) = split ':' => $_, 2;
                push @ac => $c+=0;
            } @ac = sort {$a <=> $b} @ac;

            $gribinfo{freqfh}   = ($ac[-1] - $ac[0])/(@ac-1);
            $gribinfo{freqfh}   = 24 unless $gribinfo{freqfh};
            $gribinfo{initfh}   = $gribinfo{freqfh};
            $gribinfo{maxfreq}  = $gribinfo{freqfh};
            $Uprep{parms}{bcmaxfq}      = $gribinfo{maxfreq};


            #  Check whether the requested length of the simulation is an integer multiple of
            #  the BC frequency. If not then bail out.
            #
            if ($Uprep{parms}{length}%$gribinfo{freqfh}) {
                my $mesg = "The length of the simulation ($Uprep{parms}{length} hours) must be an integer multiple of the BC update ".
                           "frequency ($gribinfo{freqfh} hours). So let's play together nicely and adjust the length of your ".
                           "run to something that works for both of us.";
                $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,0,"Can't we just get along?",$mesg);
                return '';
            }

            #  If the user passed the analysis flag with a value then make
            #  sure freqfh is an integer multiple of the value.
            #
            $gribinfo{freqfh}   = $Uprep{parms}{analysis} if $Uprep{parms}{analysis} > 0 and ! $Uprep{parms}{analysis}%$gribinfo{freqfh};
            $gribinfo{category} = 'Analysis';
            $gribinfo{analysis} = $Uprep{parms}{analysis}*60;

        }

        
        #----------------------------------------------------------------------------------
        #  Make sure the cycle parameters for surface fields are correct
        #----------------------------------------------------------------------------------
        #
        if ($gribinfo{category} =~ /surface/i) {
            my @ac=();
            foreach (@{$gribinfo{cycles}}) {
                my ($c, $z) = split ':' => $_, 2;
                push @ac => sprintf('%02d', $c+=0);
            }
            @{$gribinfo{cycles}} = sort @ac;
        }


        #----------------------------------------------------------------------------------
        #  Finally, make sure the minute fields are populated, just in case they
        #  are needed someday.
        #----------------------------------------------------------------------------------
        #
        $gribinfo{initfm} = $gribinfo{initfh}*60 unless $gribinfo{initfm};
        $gribinfo{finlfm} = $gribinfo{finlfh}*60 unless $gribinfo{finlfm};
        $gribinfo{freqfm} = $gribinfo{freqfh}*60 unless $gribinfo{freqfm};


        #  Assign core to metgrid table
        #
        $gribinfo{metgrid}=~ s/CORE/$Uprep{parms}{ucore}/g;

        #----------------------------------------------------------------------------------
        #  Make sure the dataset has a vtable associated with it.
        #----------------------------------------------------------------------------------
        #
        my $vtable = ($useid == 4) ? $gribinfo{lvtable} : $gribinfo{vtable};

        unless ($vtable) {
            my $mesg = ($useid == 4) ? "You must have a Vtable listed for the LVTABLE entry in the $gribinfo{gfile} file for use with --lsm option."   
                                     : "You must have a Vtable listed for the VTABLE entry in the $gribinfo{gfile} file.";
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,0,'It\'s your Vtable problem now:',$mesg);
            return '';
        }

        unless (-s $vtable) {
            my $mesg = "I am unable to locate the variable table for this dataset ($vtable).";
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,0,"Problem in the $gribinfo{gfile} file?",$mesg);
            return '';
        }

        #----------------------------------------------------------------------------------
        #  set the value of aged to 0 unless $useid = 5 (static surface dataset)
        #----------------------------------------------------------------------------------
        #
        $gribinfo{aged} = 0 unless $useid == 5;
        $gribinfo{aged} = 0 unless defined $gribinfo{aged} and length $gribinfo{aged} and &Others::isInteger($gribinfo{aged});
        $gribinfo{aged} = abs $gribinfo{aged};


        #----------------------------------------------------------------------------------
        #  Create new grib information data structure and populate values
        #  with input from file.
        #----------------------------------------------------------------------------------
        #
        my $dstruct = dset_struct-> new (

            #  dataset specific information 
            #
            dset       => $dset,
            gfile      => $gribinfo{gfile},
            info       => $gribinfo{info},
            category   => $gribinfo{category},
            vcoord     => $gribinfo{vcoord},
            initfh     => $gribinfo{initfh}+=0,
            finlfh     => $gribinfo{finlfh}+=0,
            freqfh     => $gribinfo{freqfh}+=0,
            initfm     => $gribinfo{initfm}+=0,
            finlfm     => $gribinfo{finlfm}+=0,
            freqfm     => $gribinfo{freqfm}+=0,
            cycles     => [@{$gribinfo{cycles}}],
            delay      => $gribinfo{delay}+=0,
            sources    => {%{$gribinfo{sources}}},
            locfil     => "$ghome/$gribinfo{locfil}",
            maxfreq    => $gribinfo{maxfreq}+=0,
            vtable     => $gribinfo{vtable},
            lvtable    => $gribinfo{lvtable},
            metgrid    => $gribinfo{metgrid},
            timed      => $gribinfo{timevar},
            aged       => $gribinfo{aged}+=0,
            ptile      => $gribinfo{ptile},
            analysis   => $gribinfo{analysis},

    
            #  While we are here
            #
            useid      => $useid,
            local      => $method eq 'none' ? 1 : 0,

    
            #  Values supplied outside routine
            #
            acycle     => 00,         #  Cycle hour of dataset
            yyyymmdd   => 19700101,   #  Date of dataset
            yyyymmddcc => 1970010100, #  Really just yyyymmdd+acycle
            yyyymmddhh => 1970010100, #  First date & hour to use from dataset
            sim00hr    => 1970010100, #  Simulation start date & time
            rsdate     => 1970010100, #  Same as sim00hr for legacy
            redate     => 1970010100, #  Simulation stop date & time
            length     => 0,          #  Simulation length in hours
            syncsfc    => 0,          #  Whether to synchronize surface data
            aerosol    => $Uprep{parms}{aerosols}, #  Whether user requested aerosol dataset
            process    => $Uprep{parms}{noprocess} ? 0 : 1,
            status     => 0,

            #  Other stuff 
            #
            flist      => [()],
            gribs      => [()],
            nlink      => undef);
    
        #  If this is the fist time through then point fstruct and cstruct to the structure
        #
        if (defined $fstruct) { # Then must not be first time through
            $cstruct->nlink($dstruct);
            $cstruct = $dstruct;
        } else {
            $fstruct = $dstruct;
            $cstruct = $dstruct;
        }

   }  #  End foreach loop


return $fstruct;
}



sub InitializationDataSets {
#==================================================================================
#  Final configuration for the initial and boundary condition datasets. The 
#  routine returns an array of dataset structures that should be completely
#  populated.
#==================================================================================
#
     my %initdsets = (); 

     %initdsets = &InitializeDataSets_ICBCs(\%initdsets) or return ();
     %initdsets = &InitializeDataSets_SFCs(\%initdsets); return () if $ENV{PMESG};
     %initdsets = &InitializeDataSets_LSMs(\%initdsets); return () if $ENV{PMESG};


return %initdsets;
}



sub InitializeDataSets_ICBCs {
#==================================================================================
#  Final configuration for the initial and boundary condition datasets. The 
#  routine returns a hash of dataset structures that should be completely
#  populated. Here The initial conditions (ICs) are assigned to hash key "1"
#  and separate boundary conditions, if any, are assigned to hash key "2".
#==================================================================================
#
     my $href      = shift;
     my %initdsets = %{$href};

     for my $i (qw(ICS BCS)) {$initdsets{$i} = qw{}; $Info{lc $i} = qw{};}

     if (@{$Uprep{parms}{dsets}} > 1) {
         $initdsets{ICS} = &InitializeDataSet($Uprep{parms}{dsets}[0],2) or return ();
         $initdsets{BCS} = &InitializeDataSet($Uprep{parms}{dsets}[1],3) or return ();

         $initdsets{ICS} = &SimulationTiming_ICs($initdsets{ICS}); return () if $ENV{PMESG};
         $initdsets{BCS} = &SimulationTiming_BCs($initdsets{BCS}); return () if $ENV{PMESG};
     } else {
         $initdsets{ICS} = &InitializeDataSet($Uprep{parms}{dsets}[0],1) or return ();
         $initdsets{ICS} = &SimulationTiming_ICs($initdsets{ICS}); return () if $ENV{PMESG};
     }


return %initdsets;
}



sub InitializeDataSets_LSMs {
#==================================================================================
#  Final configuration for the any land surface model datasets. Multiple 
#  datasets are returned as a linked list of dataset structures and 
#  assigned to hash key "LSM".
#==================================================================================
#
     my $href      = shift;
     my %initdsets = %{$href};

     $initdsets{LSM} = qw{};
     @{$Info{lsm}}   = ();

     return %initdsets unless @{$Uprep{parms}{lsms}}; #  No worries if --lsm was not passed

     $initdsets{LSM} = &InitializeDataSet($Uprep{parms}{lsms}[0],4) or return ();
     $initdsets{LSM} = &SimulationTiming_LSMs($initdsets{LSM}); return () if $ENV{PMESG};


return %initdsets;
}



sub InitializeDataSets_SFCs {
#==================================================================================
#  Final configuration for the any static surface datasets. Multiple 
#  datasets are returned as a linked list of dataset structures and 
#  assigned to hash key "SFC".
#==================================================================================
#
     my $href      = shift;
     my %initdsets = %{$href};

     $initdsets{SFC} = qw{};
     @{$Info{sfc}}   = ();

     return %initdsets unless @{$Uprep{parms}{sfcs}}; #  No worries if --sfc was not passed

     $initdsets{SFC} = &InitializeDataSet($Uprep{parms}{sfcs}[0],5) or return ();
     $initdsets{SFC} = &SimulationTiming_SFCs($initdsets{SFC});


return %initdsets;
}



sub SimulationTiming_ICs {
#==================================================================================
#  Routine determines the cycle time, initial & final forecast hours,  and boundary
#  condition frequency of the initialization dataset from the information provided
#  in the <dset>_gribinfo.conf file and user input. If multiple datasets were
#  specified for initialization, then this routine will handle the configuration
#  of the initial conditions (ICs) only; otherwise, it manages  the information for
#  the entire simulation.
#==================================================================================
#
    my ($dinitfh, $dfinlfh, $dfreqfh) = (0, 0, 0);


    my $dstruct = shift;  return '' unless $dstruct;


    #  Begin by creating a list of available date/cycle times (yyyymmddcc) for the 
    #  requested initialization dataset given the date (yyyymmdd) passed as an
    #  argument to the --date flag. If the --date flag was not passed then use the
    #  current system date (all UTC).  The first YYYYMMDDCC in the list should the
    #  most current.
    #
    my $rdate  = $Uprep{parms}{rdate} ? $Uprep{parms}{rdate} : 0;  # 0 - use current system date
    
    my @acdates = &AvailableCycleDates(24,$rdate,$dstruct->delay,@{$dstruct->cycles});

    #  Make sure the list does not include the previous day
    #
    if ($rdate) {@acdates = grep /^$rdate/ => @acdates;}


    if ($Uprep{parms}{debug} == 1) {&Ecomm::PrintTerminal(4,9,96,1,1,sprintf("%-30s - %s",'Most Current Cycle Date',$acdates[0]));}
    if ($Uprep{parms}{debug} == 1) {&Ecomm::PrintTerminal(4,9,96,1,0,sprintf("%-30s - %s",'Available Cycle Date',$_)) foreach @acdates; print "\n";}


    #  Use command-line options if passed to override the default values in the
    #  gribinfo files. $rcycle variable contains the 'CYCLE:INITFH:FINLFH:FREQFH'
    #  where each substring (: delimited) may have been replaced with values
    #  passed as arguments to the --cycle flag. If not then they will be replaced
    #  with default values from the gribinfo file.
    # 
    my $length = $Uprep{parms}{length}; # $length usurps everything else
    my $rcycle = $Uprep{parms}{rcycle};


    #  Collect the default values for INITFH, FINLFH, and FREQFH from the gribinfo 
    #  file. There are two possible sources in the file with the default being 
    #  the INITFH, FINLFH, and FREQFH parameters. These values may be overridden
    #  by values configured into the CYCLES parameter.
    #
    $dinitfh = $dstruct->initfh;  #  Default INITFH
    $dfinlfh = $dstruct->finlfh;  #  Default FINLFH
    $dfreqfh = $dstruct->freqfh;  #  Default FREQFH


    #  Remember $rcycle = 'CYCLE:INITFH:FINLFH:FREQFH'
    #
    #  Make sure the 'CYCLE' placeholder has been populated with a cycle value.
    #  If the user included a value when passing the --cycle flag then 'CYCLE'
    #  will already be replaced with that value. If not then the default is 
    #  the cycle value from the most current date/time string in @acdates.
    #  in the @acdates array.
    #
    my $cc = &Others::DateString2DateString($acdates[0], 'cc');
    $rcycle =~ s/CYCLE/$cc/g;


    #  Split the rcycle string because we need the cycle hour for the next step.
    #  Might as well save INITFH, FINLFH, and FREQFH since they will be needed
    #  shortly. 
    #
    my ($ucycle, $uinitfh, $ufinlfh, $ufreqfh) = split /:/ => $rcycle;


    #  At this point we do not know whether the requested cycle time is valid,
    #  i.e., listed in the gribinfo file CYCLES parameter. Additionally, the CYCLES
    #  CYCLES field in the gribinfo file can contain values for INITFH, FINLFH, 
    #  and FREQFH that override the default parameters.
    #
    if (my @gicycle = grep (/^$ucycle/ => @{$dstruct->cycles})) {

        #  Unpack the cycle string because that can also contain info
        #
        my ($drc, $dri, $drf, $drq) = split /:|;|,/, $gicycle[0];

        #  Replace the default values if available
        #
        $dinitfh = printf '%02d', $dri if $dri; $dinitfh = '00' unless $dinitfh;
        $dfinlfh = printf '%02d', $drf if $drf;
        $dfreqfh = printf '%02d', $drq if $drq;

    } else {   #  Not a valid cycle

        my $gifl = $dstruct->gfile;
        my $mesg = "According to the CYCLES parameter in the $gifl file, there is no such thing ".
                   "as a $ucycle UTC cycle time!";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,0,"I may be slow, but I'm not THAT slow!",$mesg);
        return '';

    }
    my $dlength = $dfinlfh - $dinitfh;


    #  Extract the date/cycle time that matches the requested cycle. There should 
    #  be only one. If there are none then it is likely that the user passed a date
    #  and cycle hour for which a dataset is not yet available.
    #
    my @matches = grep /$ucycle$/ => @acdates;
    
    unless (@matches) {

        my @mesgs = ();
        my $d = substr $acdates[0],0,8;
        my $l = $dstruct->delay;
        my $t = $dstruct->dset;

        my $mesg = "Unless I am mistaken, which would be a first, $t forecast files from $d @ $ucycle UTC are ".
                   "not available yet. This fact of life may be due to the $l hour delay for post processing on ".
                   "the remote server or you are just getting a bit anxious. Either way, you'll just have to wait.\n\n".
                   "In the mean time, may I interest you in something you can get right now, such as:";

        push @mesgs => &Ecomm::TextFormat(0,0,88,0,1,"You have requested an initialization dataset that is not yet available.",$mesg);

        foreach (@acdates) {
            my $d = substr $_,0,8;
            my $c = substr $_,8,2;
            push @mesgs => &Ecomm::TextFormat(4,0,88,1,0,"$d @ $c UTC");
        }

        $ENV{PMESG} = join '' => @mesgs;
        return '';
    }


    #  Define the date/cycle of the initialization dataset - for now. This is not 
    #  necessarily the 00hr of the simulation.  Just the date/cycle of the dataset
    #  from whivh the simulation 00hr will be extracted.
    #
    my $yyyymmddcc = $matches[0];


    #  Determine the simulation 00hour date/time, which may be different from the 
    #  cycle date/time of the dataset used for initialization if the user specified
    #  a non-zero INITFH value.
    #
    $uinitfh =~ s/INITFH/$dinitfh/g; $uinitfh = 0 if $dstruct->analysis >= 0;
    $ufinlfh =~ s/FINLFH/$dfinlfh/g; 
    $ufreqfh =~ s/FREQFH/$dfreqfh/g;


    #  If initializing a simulation from a non 00-hour forecast then make sure the 
    #  dataset supports that hour.
    #
    my $maxfreq = $dstruct->maxfreq; $maxfreq = 3 unless $maxfreq;

    
    #  The value for BC update frequency needs to be checked against the MAXFREQ value
    #  for the dataset. This is not necessary with useid = 2 since the data are only
    #  used for the 00-hour forecast.
    #
    unless ($dstruct->useid == 2 or $ufreqfh%${maxfreq} == 0) {
       my $d = $dstruct->dset;
       my $f = $dstruct->gfile;
       my $u = $ufreqfh+=0;
       my $t = $u > $maxfreq ? 'Go smaller, or go home!' : 'Go bigger, or go home!';
       my $mesg = "It appears that you are attempting to initialize your simulation with a ${u}-hourly ".
                  "boundary condition update cycle. The problem is that the forecast data file frequency ".
                  "for this dataset is ${maxfreq}-hourly. If you strongly believe that you are correct, ".
                  "then change the MAXFREQ value in the $f file to the appropriate value; otherwise, ".
                  "change your plan of operation.";

       $ENV{PMESG} = &Ecomm::TextFormat(0,0,94,0,0,$t,$mesg);
       return '';
    }


    if ($uinitfh and $uinitfh%${maxfreq}) {
        my $d = $dstruct->dset;
        my $f = $dstruct->gfile;
        my $mesg = "It appears that you are attempting to initialize your simulation from a $d ".
                   "${uinitfh} hour forecast. The problem is that the forecast data file frequency ".
                   "for this dataset is ${maxfreq}-hourly. If you strongly believe that you are ".
                   "correct, then change the MAXFREQ value in the $f file to the appropriate value; ".
                   "otherwise, change your plan of operation.";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,94,0,0,'Making this up as you go along?',$mesg);
        return '';
    }

    
    #  Calculate the 00hr of the simulation
    #
    my $startfs = ($dstruct->analysis >= 0) ? $dstruct->analysis*60 : $uinitfh*3600;
    my $sim00hr = substr(&Others::CalculateNewDate($yyyymmddcc,$startfs),0,10);


    #  Check whether the simulation zero hour forecast is compatible with the maxfreq value of
    #  the BC dataset. Check that the start hour is an integer multiple of $Uprep{parms}{bcmaxfq},
    #  the value for which was saved for this purpose in the Initializedataset routine.
    #
    #  If this test fails then it is possible to make an adjustment. If the forecast frequency
    #  of the IC dataset is hourly then adjust the initialization hour forward in time 
    #  so that the 00hr + BC dataset update time coincides with an actial BC dataset time.
    #
    #  If maxfreq is not hourly then let user deal with the problem, which will be caught
    #  in the next subroutine.
    #
    if ($dstruct->useid == 2 and $maxfreq == 1) {

        my $cc = &Others::DateString2DateString($sim00hr, 'cc');
        my $hh = $cc;

        while ($hh%$Uprep{parms}{bcmaxfq} != 0) {$hh+=$maxfreq; $uinitfh+=$maxfreq;}

        if ($hh != $cc) {
            my $h = $hh - $cc; $h = $h > 1 ? "$h hours" : "$h hour";
            my $d = uc $dstruct->dset;

            $sim00hr = substr(&Others::CalculateNewDate($yyyymmddcc,$uinitfh*3600),0,10);

            my $s = &Others::DateString2Pretty($sim00hr);

            my $mesg = "The initial forecast hour of the $yyyymmddcc $d initial condition dataset has ".
                       "been moved up $h to accommodate the available update frequency of the boundary ".
                       "conditions.\n\nYour new simulation 00 hour time will be $s";

            &Ecomm::PrintMessage(6,6+$Uprep{arf},88,1,1,$mesg);
           
        }
    }

    #  So $yyyymmddhh contains the valid date/time of the first dataset file to download which
    #  is the same as the simulation 00hr for the IC dataset.
    #
    my $yyyymmddhh = $sim00hr;


    if ($Uprep{parms}{previous}) {

        #  If the user passed the --previous flag then:
        #
        #  1. We want the 00 hour of the simulation defined by the information
        #     provided by the user either by default or otherwise.
        #
        #  2. We need to account for the delta between the 00 hour of the simulation
        #     and the 00 hour of the requested dataset.
        #

        #  Go through the list of cdates and when the date matching $yyyymmddcc is
        #  encountered grab the previous one.
        #
        my $prev = 0;
        for my $i (1 .. $#acdates) {$prev = $acdates[$i] if $acdates[$i-1] == $yyyymmddcc;}

        unless ($prev) {
            my $mesg = "There were no previous cycle defined prior to $yyyymmddcc. I'm not sure why either, ".
                       "but feel free to give up all hope and toss me aside if it makes you feel any better.\n\n".
                       "I'll still be here in the morning!";
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,0,"Sorry, but the \"--previous\" flag isn't helping:",$mesg);
            return ''; 
        }

        #  Get the delta in hours
        #
        my $delta = int ((&Others::CalculateEpochSeconds($yyyymmddcc)-&Others::CalculateEpochSeconds($prev))/3600);

        $uinitfh = $uinitfh + $delta;
        $ufinlfh = $ufinlfh + $delta;

        $matches[0] = $prev;
        $yyyymmddcc = $matches[0];
    }



    #  Now is the time to determine the length of the forecast, which can be determined
    #  from different sources. If this simulation uses 2 datasets for initialization, 
    #  then length should have been passed by the user and saved in $Uprep{parms}{length}.  
    #
    $length  = $ufinlfh - $uinitfh unless $length; # $length should already be assigned with multiple datasets

    $ufinlfh = $uinitfh + $length;

    $ufinlfh = $uinitfh if $dstruct->useid == 0 and !$Uprep{parms}{nudging};
    $ufinlfh = $uinitfh if $dstruct->useid == 2;


    #  --------------------------------------------------------------------------------------
    #  Set the final values in the dataset structure. So as not to become confused:
    #
    #  $yyyymmddcc - $yyyymmddcc represents the date & cycle time of the dataset 
    #                to be used for IC or BCs.  If different IC and BC datasets 
    #                are to be used then $yyyymmddcc may be different for each.
    #
    #                Carried in $dstruct->yyyymmdd and $dstruct->acycle for each
    #                dataset.
    #
    #  $yyyymmddhh - The $yyyymmddhh represents the date & hour of the first forecast
    #                period to be used from the dataset. 
    #                Note that $yyyymmddhh >= $yyyymmddcc.
    #
    #                Carried in $dstruct->yyyymmddhh for each dataset
    #
    #  $sim00hr    - The 00-hour date & time of the simulation. Carried in 
    #                $dstruct->sim00hr for each dataset. Will be the same as
    #                $yyyymmddhh if INITFH is 0 (default).
    #  --------------------------------------------------------------------------------------
    #
    my $yyyymmdd   = &Others::DateString2DateString($yyyymmddcc, 'yyyymmdd');
    my $acycle     = &Others::DateString2DateString($yyyymmddcc, 'cc');

    $dstruct->yyyymmdd($yyyymmdd);
    $dstruct->acycle($ucycle);
    $dstruct->yyyymmddcc($yyyymmddcc);
    $dstruct->yyyymmddhh($yyyymmddhh);
    $dstruct->sim00hr($sim00hr);

    for ($uinitfh, $ufinlfh, $ufreqfh) {$_ = sprintf("%02d", $_);}

#   print "\n";
#   print "uinitfh   : $uinitfh\n";
#   print "ufinlfh   : $ufinlfh\n";
#   print "ufreqfh   : $ufreqfh\n";
#   print "yyyymmddcc: $yyyymmddcc\n";
#   print "yyyymmddhh: $yyyymmddhh\n";
#   print "sim00hr   : $sim00hr\n";
#   print "length    : $length\n";

    $dstruct->initfh($uinitfh);
    $dstruct->finlfh($ufinlfh);
    $dstruct->freqfh($ufreqfh);

    $dstruct->initfm($uinitfh*60);
    $dstruct->finlfm($ufinlfh*60);
    $dstruct->freqfm($ufreqfh*60);

    $dstruct->length($length);


    #  The folilowing assignment of the minute variables is temporary until full
    #  support has been implemented.
    #
    $dstruct->initfm($dstruct->initfh*60);
    $dstruct->finlfm($dstruct->finlfh*60);
    $dstruct->freqfm($dstruct->freqfh*60);


    #  We already have the simulation start date ($sim00hr), now determine the end date.
    #
    my $redate = substr(&Others::CalculateNewDate($yyyymmddhh,$length*3600),0,10);

    $dstruct->rsdate($sim00hr);
    $dstruct->redate($redate);


    #  Write these back to the global hash since they will be needed later
    #
    $Uprep{parms}{length}  = $length;
    $Uprep{parms}{sim00hr} = $sim00hr;
    $Uprep{parms}{redate}  = $redate;

    
    #  If this is an analysis dataset then make sure none of the BC times are 
    #  in the future.
    #
    if ($dstruct->analysis >= 0 and $dstruct->useid == 1) {
        if (my $bdate = &AvailableAnalysisDates($length,$yyyymmddcc,$dstruct->freqfh)) {
            my $pdate = &Others::DateString2Pretty($bdate);
            my $mesg  = "Were you aware that this simulation extends beyond the current date & time? Since you are ".
                        "using an analysis dataset, the last available valid date & time is $pdate, so you are just ".
                        "going to have to sit there and wait like the rest of us.";
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,80,0,0,'The UEMS Elder keeps track of time, and so should you!',$mesg);
            return '';
        }
    }


    #  The final task is to populate the Info hash
    #
    my $du = ($dstruct->useid == 2) ? 'bcs' : 'ics';

    foreach ('ics', 'bcs') {
        $Info{$_}    = uc $dstruct->dset;
        $Info{$_}    = "$Info{$_} personal tile dataset" if $dstruct->ptile;
        $Info{sdate} = &Others::DateString2Pretty($sim00hr);
        $Info{edate} = &Others::DateString2Pretty($redate);
        $Info{bcf}   = $dstruct->freqfh*60;
    }

return $dstruct;
}


sub SimulationTiming_BCs {
#==================================================================================
#  Routine determines the cycle time, initial & final forecast hours, and update
#  frequency for the boundary condition dataset given the information provided
#  in the <dset>_gribinfo.conf file and user input. This routine is only called
#  when multiple datasets are used for simulation initialization.
#==================================================================================
#
    my ($dinitfh, $dfinlfh, $dfreqfh) = (0, 0, 0);

    my $dstruct = shift;  return '' unless $dstruct;

    
    #  Collect values that were determined in the SimulationTiming_ICs routine
    #
    my $length  = $Uprep{parms}{length};
    my $rcycle  = $Uprep{parms}{rcycle};
    my $sim00hr = $Uprep{parms}{sim00hr};


    #  Compare the start hour for the simulation and make sure it is an integer 
    #  multiple of the BC dataset maxfreq value. If not, then the BC dataset 
    #  will not work with this start time. For example, if the simulation start
    #  hour is 14 UTC but the BC dataset maxfreq value is 3 (3-hourly), there
    #  will be an available update time at 17 UTC (14 UTC + 3 hours).
    #
    my $maxfreq = $dstruct->maxfreq; $maxfreq = 3 unless $maxfreq;
    my $cc      = &Others::DateString2DateString($sim00hr, 'cc');

    unless ($cc%${maxfreq} == 0) {
       my $d = $dstruct->dset;
       my $f = $dstruct->gfile;
       my $u = $cc+=0;
       my $b = $cc + $maxfreq; $b = $b-24 if $b > 23;
       my $mesg = "The simulation start time of $u UTC is incompatible with this BC dataset, which has ".
                  "a maximum update frequency of every $maxfreq hours. This means that there are no BC ".
                  "data that coincide with the expected simulation update times, such as $b UTC.\n\n".
                  "If you believe that the BC information is incorrect, then change the MAXFREQ value in ".
                  "the $f file to an appropriate value; otherwise, change your plan of action.";
       $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,0,'BC dataset incompatible with start time!',$mesg);
       return '';
    }


    #  Collect the default values for INITFH, FINLFH, and FREQFH from the gribinfo 
    #  file. There are two possible sources in the file with the default being 
    #  the INITFH, FINLFH, and FREQFH parameters. These values may be overridden
    #  by values configured into the CYCLES parameter.
    #
    $dinitfh = $dstruct->initfh;  #  Default INITFH
    $dfinlfh = $dstruct->finlfh;  #  Default FINLFH
    $dfreqfh = $dstruct->freqfh;  #  Default FREQFH


    #  Split the rcycle string because we need the cycle hour for the next step.
    #  Might as well save INITFH, FINLFH, and FREQFH since they will be needed
    #  shortly. 
    #
    my ($ucycle, $uinitfh, $ufinlfh, $ufreqfh) = split /:/ => $rcycle;


    #  We only care about the forecast frequency of the BC dataset.
    #
    $ufreqfh =~ s/FREQFH/$dfreqfh/g;


    #  The value for BC update frequency needs to be checked against the MAXFREQ value
    #  for the dataset. 
    #
    unless ($ufreqfh%${maxfreq} == 0) {
       my $d = $dstruct->dset;
       my $f = $dstruct->gfile;
       my $u = $ufreqfh+=0;
       my $t = $u > $maxfreq ? 'Go smaller, or go home!' : 'Go bigger, or go home!';
       my $mesg = "It appears that you are attempting to initialize your simulation with a ${u}-hourly ".
                  "boundary condition update cycle. The problem is that the forecast data file frequency ".
                  "for this dataset is ${maxfreq}-hourly. If you strongly believe that you are correct, ".
                  "then change the MAXFREQ value in the $f file to the appropriate value; otherwise, ".
                  "change your plan of operation.";
       $ENV{PMESG} = &Ecomm::TextFormat(0,0,94,0,0,$t,$mesg);
       return '';
    }


    #  Now use the simulation 00-hour date & time to determine the BC dataset. There is
    #  a philosophical issue here. Do we use a BC dataset that has a cycle time closest
    #  to the cycle time of the IC dataset, the 00-hour of the simulation, or the first
    #  BC update time? You didn't know the UEMS wizards considered these things, did you?
    #
    #  Here is an example:  %  ems_prep --dser hrrr%gfs --cycle 00:03::03 
    #
    #  Initialize the simulation from the 3-hour forecast of the 00 UTC HRRR run and use
    #  a 3-hourly BC update frequency from the GFS. The 00-hour of the simulation is 
    #  03 UTC, which is between the 00 and 06 UTC GFS cycles. The first BC update time
    #  is 06 UTC (03 UTC + 3 hours), which is a GFS cycle time. 
    #
    #  So do you start with the 6-hour forecast from the 00 UTC GFS or the 0-hour forecast
    #  from the 06 UTC GFS?  The 00 UTC cycle of the HRRR from which the 3-hour forecast
    #  originated does have connections to the 00 UTC GFS but the 06 UTC GFS cycle would
    #  be more accurate.
    #
    #  Since this situation would only present itself during real-time forecasting, it's
    #  unlikely that the 06 UTC GFS cycle will be available and thus the 00 UTC cycle 
    #  would be used.
    #
    my $yyyymmddhh = substr(&Others::CalculateNewDate($Uprep{parms}{sim00hr},$ufreqfh*3600),0,10);

    #  If you rather use the BC cycle time closest to the 1st update time then simply change
    #  $Uprep{parms}{sim00hr} to $yyyymmddhh in the 2 lines below.
    #
    my @acdates    = &AvailableCycleDates($length,$Uprep{parms}{sim00hr},$dstruct->delay,@{$dstruct->cycles});
       @acdates    = grep {$_ <= $Uprep{parms}{sim00hr}} @acdates;

    my $yyyymmddcc = $acdates[0];

    if ($Uprep{parms}{debug} == 1) {&Ecomm::PrintTerminal(4,7,96,1,0,"BC Update Start Cycle Date - $yyyymmddhh");}
    if ($Uprep{parms}{debug} == 1) {&Ecomm::PrintTerminal(4,7,96,1,2,"BC Dset Cycle Time & Date  - $yyyymmddcc");}
    if ($Uprep{parms}{debug} == 1) {&Ecomm::PrintTerminal(4,7,96,0,1,"Available BC Cycle Date    - $_") foreach @acdates;}


 
    #  Calculate the values for INITFH and FINLFH, for which we have the necessary information
    #  but need to get the simple math correct.
    #
    #  $uinitfh - Initial forecast hour to use from the BC dataset 
    #  $ufinlfh - Final forecast hour to use from the BC dataset
    #
    $uinitfh = int ((&Others::CalculateEpochSeconds($yyyymmddhh)-&Others::CalculateEpochSeconds($yyyymmddcc))/3600);
    $ufinlfh = $uinitfh + $length - $ufreqfh;

    $dstruct->initfh($uinitfh);
    $dstruct->finlfh($ufinlfh);
    $dstruct->freqfh($ufreqfh);
    $dstruct->length($length);

    $dstruct->initfm($dstruct->initfh*60);
    $dstruct->finlfm($dstruct->finlfh*60);
    $dstruct->freqfm($dstruct->freqfh*60);


    #  --------------------------------------------------------------------------------------
    #  Set the final values in the dataset structure. So as not to become confused:
    #
    #  $yyyymmddcc - $yyyymmddcc represents the date & cycle time of the dataset 
    #                to be used for IC or BCs.  If different IC and BC datasets 
    #                are to be used then $yyyymmddcc may be different for each.
    #
    #                Carried in $dstruct->yyyymmdd and $dstruct->acycle for each
    #                dataset.
    #
    #  $yyyymmddhh - The $yyyymmddhh represents the date & hour of the first forecast
    #                period to be used from the dataset. 
    #                Note that $yyyymmddhh >= $yyyymmddcc.
    #
    #                Carried in $dstruct->yyyymmddhh for each dataset
    #
    #  $sim00hr    - The 00-hour date & time of the simulation. Carried in 
    #                $dstruct->sim00hr for each dataset. Will be the same as
    #                $yyyymmddhh if INITFH is 0 (default).
    #  --------------------------------------------------------------------------------------
    #
    my $yyyymmdd   = &Others::DateString2DateString($yyyymmddcc, 'yyyymmdd');
    my $acycle     = &Others::DateString2DateString($yyyymmddcc, 'cc');

    $dstruct->yyyymmdd($yyyymmdd);
    $dstruct->acycle($ucycle);
    $dstruct->yyyymmddcc($yyyymmddcc);
    $dstruct->yyyymmddhh($yyyymmddhh);
    $dstruct->sim00hr($sim00hr);


    #  We already have the simulation start date ($sim00hr), now determine the end date.
    #
    my $redate = substr(&Others::CalculateNewDate($sim00hr,$length*3600),0,10);

    $dstruct->rsdate($sim00hr);
    $dstruct->redate($redate);

    #  The final task is to populate the Info hash
    #
    $Info{bcs} = uc $dstruct->dset;
    $Info{bcs} = "$Info{bcs} personal tile dataset" if $dstruct->ptile;
    $Info{bcf} = $dstruct->freqfh*60;


return $dstruct;
}


sub SimulationTiming_LSMs {
#==================================================================================
#  Routine determines the date and cycle time for the land surface model datasets
#  requested with the simulation. Note that the datasets are passed in as a
#  linked list of dataset structures that are looped.
#==================================================================================
#
    my ($fstruct,$cstruct);

    my $dstruct = shift;  return '' unless $dstruct;

    #  Collect values that were determined in the SimulationTiming_ICs routine
    #
    my $nprint  = 1;
    my $length  = $Uprep{parms}{length};
    my $rcycle  = $Uprep{parms}{rcycle};
    my $sim00hr = $Uprep{parms}{sim00hr};
    my $rdate   = $Uprep{parms}{sim00hr};

    while ($dstruct) {

        my $timed = $dstruct->timed;

        #  Hassle the user about using LIS datasets with MODIS terrestrial files.
        #
        my $dset = $dstruct->dset;

        if ($dset =~ /lis/i and ! $Uprep{parms}{modis} and $nprint) {
            my $mesg = "I am taking this time away from your simulation to strongly urge you to consider ".
                        "using the MODIS land use categories with the LIS LSM dataset.\n\nTo make this change, run:\n\n".
                        "  % ems_domain --localize --modis\n\n".
                        "next time before to running ems_prep. You only need to do this step once, and trust me, we ".
                        "will both be better off for the change.";
            &Ecomm::PrintMessage(6,6+$Uprep{arf},88,1,3,'Your Localization Disturbs Me:',$mesg);
            $nprint = 0;
        }

        my @acdates = &AvailableCycleDates(24,$rdate,$dstruct->delay,@{$dstruct->cycles});

        unless (@acdates) {
            my $gfile = $dstruct->gfile;
            my $mesg = "No $dset LSM data files could be found that correspond to the initialization time ".
                       "of the simulation ($sim00hr).  Please make sure that the cycle times in the $gfile ".
                       "are correct (Currently: @{$dstruct->cycles}) and if this is a real-time simulation ".
                       "check the value of DELAY in the same file.";
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Problem with LSM Initialization:',$mesg);
            return '';
        }
           

        if ($Uprep{parms}{debug} == 1) {&Ecomm::PrintTerminal(4,9,96,1,0,sprintf("%-30s - %s",'Available Land Surface Date',$_)) foreach @acdates; print "\n";}

        my $yyyymmddcc = $acdates[0];
        my $yyyymmdd   = &Others::DateString2DateString($yyyymmddcc, 'yyyymmdd');
        my $acycle     = &Others::DateString2DateString($yyyymmddcc, 'cc');

        $dstruct->initfh('00');
        $dstruct->finlfh('00');
        $dstruct->freqfh('01');
        $dstruct->length($timed ? $length : 0);

        $dstruct->initfm($dstruct->initfh*60);
        $dstruct->finlfm($dstruct->finlfh*60);
        $dstruct->freqfm($dstruct->freqfh*60);


        $dstruct->acycle($acycle);
        $dstruct->yyyymmdd($yyyymmdd);
        $dstruct->yyyymmddcc($yyyymmddcc);
        $dstruct->yyyymmddhh($yyyymmddcc);  #  Should be the same
        $dstruct->sim00hr($sim00hr);

        $dstruct->rsdate($sim00hr);
        $dstruct->redate($Uprep{parms}{redate});

        if (defined $fstruct) {
            $cstruct->nlink($dstruct);
            $cstruct = $dstruct
        } else {
            $fstruct = $dstruct;
            $cstruct = $dstruct;
        }

        $dstruct = $dstruct->nlink;
    
        push @{$Info{lsm}} => uc $dset;
    }


return $fstruct;
}



sub SimulationTiming_SFCs {
#==================================================================================
#  Routine determines the date and cycle time for the surface (static) datasets
#  requested with the simulation. Note that the datasets are passed in as a
#  linked list of dataset structures that are looped.
#==================================================================================
#
use List::Util qw(min);

    my ($fstruct,$cstruct);

    my $dstruct = shift;  return qw{} unless $dstruct;

    #  Collect values that were determined in the SimulationTiming_ICs routine
    #
    my $length  = $Uprep{parms}{length};
    my $rcycle  = $Uprep{parms}{rcycle};
    my $sim00hr = $Uprep{parms}{sim00hr};
    my $rdate   = $Uprep{parms}{sim00hr};
    my @syncs   = $Uprep{parms}{syncsfc} ? (split ',' => $Uprep{parms}{syncsfc}) : ();

    while ($dstruct) {

        #----------------------------------------------------------------------------------
        #  If the --syncsfc flag was passed then check whether this dataset was included
        #  in the list. If so, then determine the closest cycle time to the 00-hour 
        #  forecast hour. Should there be 2 equally close times then use the earliest
        #  of the cycle times. The latestest is desired, then change the "min" to "max".
        #----------------------------------------------------------------------------------
        #
        my $dset = $dstruct->dset;
        if (grep (/^$dset$/, @syncs)) {
            my %hash=();
            $dstruct->syncsfc(1);
            my $ac = &Others::DateString2DateString($sim00hr, 'cc');
            push @{$hash{abs((abs($ac-$_)>12) ? 24-abs($ac-$_) : $ac-$_)}} => $_ foreach @{$dstruct->cycles};
            @{$dstruct->cycles} = min @{$hash{min keys %hash}};
        }
                
        my @acdates = &AvailableCycleDates(24,$rdate,$dstruct->delay,@{$dstruct->cycles});

        if ($Uprep{parms}{debug} == 1) {&Ecomm::PrintTerminal(4,9,96,1,0,sprintf("%-30s - %s",'Available Surface Date',$_)) foreach @acdates; print "\n";}

        my $yyyymmddcc = $acdates[0];
        my $yyyymmdd   = &Others::DateString2DateString($yyyymmddcc, 'yyyymmdd');
        my $acycle     = &Others::DateString2DateString($yyyymmddcc, 'cc');

        $dstruct->initfh('00');
        $dstruct->finlfh('00');
        $dstruct->freqfh('01');
        $dstruct->length($length);

        $dstruct->initfm($dstruct->initfh*60);
        $dstruct->finlfm($dstruct->finlfh*60);
        $dstruct->freqfm($dstruct->freqfh*60);

        $dstruct->acycle($acycle);
        $dstruct->yyyymmdd($yyyymmdd);
        $dstruct->yyyymmddcc($yyyymmddcc);
        $dstruct->yyyymmddhh($yyyymmddcc);  #  Should be the same
        $dstruct->sim00hr($sim00hr);

        $dstruct->rsdate($sim00hr);
        $dstruct->redate($Uprep{parms}{redate});

        if (defined $fstruct) {
            $cstruct->nlink($dstruct);
            $cstruct = $dstruct
        } else {
            $fstruct = $dstruct;
            $cstruct = $dstruct;
        }

        $dstruct = $dstruct->nlink;

        push @{$Info{sfc}} => uc $dset;
    }


return $fstruct;
}



sub AvailableAnalysisDates {
#==================================================================================
#  Similar to the AvailableCycleDates routine, except that it checks whether
#  any of the analysis file date & times are in the future, which we don't want.
#==================================================================================
#
    my $yyyymmddhh = $Uprep{emsenv}{yyyymmddhh}; #  The current machine date/time

    my ($hours, $rdate, $freq) = @_;

    my @pdates  = ();  # A list of 24 possible date/times.
    my $dhour   = 0;
    my $ncycles = int($hours/$freq);

    #  $rdate should be the date and cycle time of the first file to be used
    #  $yyyymmddhh holds the current machine date and time in UTC
    #

    #  Note that while not used, @pdates is retained just in case its needed some day.
    #
    while (@pdates <= $ncycles) { # We only want a $ncycle window of times
        my $pdate = substr(&Others::CalculateNewDate($rdate,$dhour*3600),0,10);
        return $pdates[-1] if $pdate > $yyyymmddhh; #  Dataset is not available yet (00Hr after current date/time)
        push @pdates => $pdate;       #  Add it to the list
        $dhour+=$freq; #  Count up hours
    }

    #  Might need these someday, but not today.
    #
    @pdates = &Others::rmdups(@pdates);
    @pdates = sort {$a <=> $b} @pdates;

return 0;
}



sub AvailableCycleDates {
#==================================================================================
#  Return an array of available dates and cycle times YYYYMMDDCC over a 24 hour
#  period beginning with the most current. 
#==================================================================================
#
    my $yyyymmddhh = $Uprep{emsenv}{yyyymmddhh}; #  The current machine date/time

    my ($hours, $rdate, $delay, @cycles) = @_;

    my @pdates = ();  # A list of 24 possible date/times.
    my $dhour  = 1;

    #  $sdate is the upper bound (most current) date/time to be used for a specified
    #  dataset. The actual date/time in the list will be controlled by factors such
    #  as the date or cycle time passed by the user, the available cycle times of a
    #  dataset, and the date cycle time of the initialization dataset (BC data).
    #
    #  $yyyymmddhh holds the current machine date and time in UTC
    #
    
    my $sdate = $rdate ? (length $rdate == 8) ? "${rdate}23" : $rdate : $yyyymmddhh;

    #  Note that we also take into account the DELAY setting from the gribinfo file for
    #  a dataset here.
    #
    while (@pdates < $hours) { # We only want a $hours-hour window of times
        $dhour--; #  Count down hours
        my $pdate = substr(&Others::CalculateNewDate($sdate,$dhour*3600),0,10);
        next if $pdate > $yyyymmddhh; #  Dataset is not available yet (00Hr after current date/time)
        my $adate = substr(&Others::CalculateNewDate($pdate,$delay*3600),0,10);  
#       my $adate = substr(&Others::CalculateNewDate($pdate,$delay*60),0,10);  # Changed in favor of minutes
        next if $adate > $yyyymmddhh; #  Dataset is not available yet (Delay included)
        push @pdates => $pdate;       #  Add it to the list
    }

    #  The available cycle times for a dataset is defined by the CYCLES parameter
    #  in the gribinfo.conf file. Here the list of 24 times will be paired down
    #  to just those matching those cycle times.
    #
    @cycles = sort {$a <=> $b} @cycles;


    #  Use the CYCLES information from the gribinfo file to select only those date &
    #  times that coincide with cycle hours.
    #
    my @cdates = @cycles ? () : @pdates;

    foreach my $str (@cycles) {
        my @list = split /:/ => $str; #  Split the info and get the actual cycle hour
        my $cycle = sprintf("%02d", $list[0]);

        # Extract those dates/time that coincide with a cycle time in the list
        #
        my @matches = grep /$cycle$/ => @pdates;
        @cdates = (@cdates, @matches);
    }
    
    @cdates = &Others::rmdups(@cdates);
    @cdates = sort {$b <=> $a} @cdates;


return  @cdates;
}



sub UpdateMasterNamelist {
#==================================================================================
#  Update the information to be published in the WPS namelist file. The file
#  was originally read into the %{$Uprep{masternl}} hash during initialization
#  and now it's time to update the values. The %masternl hash is returned although
#  it's really not necessary since the $Uprep{masternl} hash is available. It's
#  done this way just to keep everything neat.
#==================================================================================
#
use List::Util qw( max );

    my $mesg=qw{};

    #  Just for the sake of neatness and maintainability, work with
    #  copies of the global Uprep hash.
    #
    my %masternl  = %{$Uprep{masternl}}; 
    my %initdsets = %{$Uprep{initdsets}};
    my %emsrun    = %{$Uprep{rtenv}};


    #----------------------------------------------------------------------------------
    #  Begin with the &share record in namelist file, where we have the following:
    #
    #    debug_level      - Debug Level
    #    max_dom          - Number of domains available - Saved run value in $masternl{maxdoms}
    #    start_date       - Start date/time for each domain separated by a comma
    #    end_date         - End date/time for each domain separated by a comma
    #    interval_seconds - Number of seconds between BC updates - Not defined until ungrib routine
    #    active_grid      - A list of MAX_DOM logical values indicating active domains
    #    io_form_geogrid  - The format of the geogrid files (2 = netCDF)
    #    opt_output_from_geogrid_path - Path to geogrid files (static)
    #----------------------------------------------------------------------------------
    #
    $masternl{SHARE}{io_form_geogrid}[0] = 2;  #  Always
    $masternl{SHARE}{debug_level}[0]     = 0;  #  Always
    $masternl{SHARE}{active_grid}[$_-1]  = '.true.' foreach keys %{$Uprep{parms}{domains}};
    $masternl{SHARE}{opt_output_from_geogrid_path}[0] = "\'$emsrun{static}\'";
    

    #  Assign the start/stop times for the primary and any nested domains.
    #  While the start times must be set here, the stop times are not important 
    #  as they are set prior to running the actual simulation. Just use the 
    #  stop time of the primary domain for now.
    #
    @{$masternl{SHARE}{start_date}} = ();
    @{$masternl{SHARE}{end_date}}   = ();


    #  Start with the primary domain 
    #
    $masternl{SHARE}{start_date}[0] = &Others::DateString2DateStringWRF($Uprep{parms}{sim00hr});
    $masternl{SHARE}{start_date}[0] = "\'$masternl{SHARE}{start_date}[0]\'";

    $masternl{SHARE}{end_date}[0]   = &Others::DateString2DateStringWRF($Uprep{parms}{redate});
    $masternl{SHARE}{end_date}[0]   = "\'$masternl{SHARE}{end_date}[0]\'";


    #----------------------------------------------------------------------------------
    #  Initialize the start_date and end_date values through the last domain included
    #  in the simulation. Depending upon the configuration of the sub-domains (if any)
    #  this step may involve domains that are not part of the simulation but still
    #  need values associated with them in the namelist (them's the rules.) 
    #
    #  Any changes to these values will be dome within the foreach loop below.
    #----------------------------------------------------------------------------------
    #
    my $maxdom = max keys %{$Uprep{parms}{domains}};

    @{$masternl{SHARE}{start_date}} = ($masternl{SHARE}{start_date}[0]) x $maxdom;
    @{$masternl{SHARE}{end_date}}   = ($masternl{SHARE}{end_date}[0])   x $maxdom;
    
    

    my $pstart = &Others::DateString2Pretty($Uprep{parms}{sim00hr});
    my $pend   = &Others::DateString2Pretty($Uprep{parms}{redate});


    foreach my $domain (sort {$a <=> $b} keys %{$Uprep{parms}{domains}}) {

        next unless $domain > 1;

        my $shr   =  $Uprep{parms}{domains}{$domain} < 0 ? 0 : $Uprep{parms}{domains}{$domain};
        my $start = substr(&Others::CalculateNewDate($Uprep{parms}{sim00hr},$shr*3600),0,10);

        if ($shr >= $Uprep{parms}{length}) { #  Can not start integrating a nested domain after simulation ends
            my $nstart = &Others::DateString2Pretty($start);
            $mesg = "The start time for domain $domain ($nstart) is after the simulation has finished ($pend), ".
                    "which is not good\nunless you are trying to start a hullabaloo or something.";
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,0,"Start Time Problem for Nested Domain $domain",$mesg);
            return ();
        }


        if ($Uprep{parms}{global} and $shr) {
            $mesg = "The start time for any domain nested within a global simulation must be the same as ".
                    "the primary (global) domain. Remove the start hour and try again.";
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,0,"Start Time Problem for Nested Domain",$mesg);
            return ();
        }

        $masternl{SHARE}{start_date}[$domain-1] = &Others::DateString2DateStringWRF($start);
        $masternl{SHARE}{start_date}[$domain-1] = "\'$masternl{SHARE}{start_date}[$domain-1]\'";
        $masternl{SHARE}{end_date}[$domain-1]   = $Uprep{parms}{nudging} ? $masternl{SHARE}{end_date}[0] : $masternl{SHARE}{start_date}[$domain-1];

        $Info{domains}{$domain}{sdate}          = &Others::DateString2Pretty($start);

    }

    #----------------------------------------------------------------------------------
    #  Next the &metgrid record in the namelist file, where we have the following:
    #
    #    fg_name          - Set in metgrid routine
    #    constants_name   - Set in metgrid routine
    #    process_only_bdy - An integer specifying the number of boundary rows and columns to be processed
    #    io_form_metgrid  - 2 for NetCDF
    #    opt_metgrid_tbl_path -  path, either relative or absolute, to the METGRID.TBL file
    #    opt_output_from_metgrid_path - path to  metgrid output
    #----------------------------------------------------------------------------------
    #
    @{$masternl{METGRID}{constants_name}}  = ();
    @{$masternl{METGRID}{fg_name}}         = ();

    $masternl{METGRID}{io_form_metgrid}[0] = 2;  #  Hard-coded value for netCDF
    $masternl{METGRID}{opt_output_from_metgrid_path}[0] = "\'$emsrun{wpsprd}\'";
    $masternl{METGRID}{opt_metgrid_tbl_path}[0]         = "\'$emsrun{dompath}\'";
    $masternl{METGRID}{process_only_bdy}[0]             = $Uprep{parms}{bndyrows};


return %masternl;
}



