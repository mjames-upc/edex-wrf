#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Oconf.pm
#
#  DESCRIPTION:  Oconf contains each of the primary routines used for the
#                final configuration of ems_post. It's the least elegant of
#                the ems_post modules simply because there is a lot of sausage
#                making going on.
#
#                A lot of sausage making
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Oconf;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Oconf $mesg);


sub PostConfiguration {
#==================================================================================
#  Routine that calls each of the configuration subroutines. For ems_post:
#
#    1. Do the final checks of any command line flags passed
#    2. Do the final checks of the configuration file parameters
#    3. Set the post processing environment
#    4. Merge the command-line and configuration file parameters
#    5. Set the final %Post hash for use by ems_post
#==================================================================================
#
use Oflags;
use Ofiles;
use Ofinal;

use List::Util qw( max );

    my $upref = shift; my %Upost = %{$upref};

    &Ecomm::PrintTerminal(0,4,255,1,1,sprintf ("%-4s Attempting to translate your configuration into something ems_post can understand",&Ecomm::GetRN($ENV{ORN}++))) unless $Upost{emsenv}{autorun} or $Upost{clflags}{AUTOPOST};


    #----------------------------------------------------------------------------------
    #  The %Oconf hash will hold all the collected information until it can be
    #  sorted out. The following keys are used to hold the information:
    #
    #    a.  %Oconf{flags} - Command line flag configurations
    #    b.  %Oconf{files} - Configuration file parameters
    #----------------------------------------------------------------------------------
    #
    %Oconf  = (); #  %Oconf is the "work" hash and contains temporary variables used
                  #  in the configuration routines within this module.
                   
    #  Begin with the final configuration checks of the command line flags. This step
    #  must be completed first in order to determine the domain(s) to be processed.
    #
    return () unless %{$Oconf{flags}} = &Oflags::PostFlagConfiguration(\%Upost);


    #  Collect information on the domain(s) to be post processed. This step must be 
    #  completed prior to processing the configuration files because the model core
    #  other necessary information will be used in the file parameter configuration.
    #  Also note that the domains to be process is finalized here rather than in the
    #  &PostFinalConfiguration subroutine.
    #
    return () unless %{$Upost{rtenv}} = &SetRuntimeEnvironment($Oconf{flags}{rundir});


    #  the value of $Upost{maxdoms} will be used throughout the configuration to
    #  define the final domain ID for which information must be provided.
    #
    $Upost{maxdoms}   = max keys %{$Upost{rtenv}{postdoms}};
    $Upost{maxindex}  = $Upost{maxdoms}-1; #  Index of final domain information.


    #  Read and process the local configuration files under conf/ems_post
    #
    return () unless %{$Oconf{files}} = &Ofiles::PostFileConfiguration(\%Upost);


    #  Both the user flags and configuration files have been collected and massaged,
    #  so it's time to create the master hash that will used throughout ems_post.
    #
    return () unless %{$Upost{parms}} = &Ofinal::PostFinalConfiguration(\%Upost,\%Oconf);


    #  Ensure the environment variable is properly set
    #
    $ENV{EMS_RUN} = $Upost{parms}{rundir};


    #-------------------------------------------------------------------------------
    #  Probably a good time to do the initial clean-up of the domain directory
    #-------------------------------------------------------------------------------
    # 
    return () if &Outils::PostCleaner($Upost{parms}{scour},$Upost{parms}{rundir},$Upost{emsenv}{autorun});


return %Upost;
}  #  &PostConfiguration



sub SetRuntimeEnvironment {
#==================================================================================
#  Collect information on the run-time domain used in the simulation
#==================================================================================
#
use List::Util qw( max );

    my %penv = ();
    my %hash = ();

    my $emsrun = Cwd::realpath(shift) || return %hash;


    # Note that the local static/namelist.wps  and namelist.wrfm files are read in &Others::RuntimeEnvironment
    #
    return () unless %hash = &Others::RuntimeEnvironment($emsrun);


    unless (%{$hash{wrfnlh}}) { 
        my $mesg = "While I like your enthusiasm and style, there appears to be a problem in that I am unable ".
                   "to find the static/namelist.wrfm file. This file contains information about the domains ".
                   "for which you are trying to process output.  Unfortunately, I can not continue without ".
                   "this information.";
        $ENV{OMESG} = &Ecomm::TextFormat(0,0,88,0,0,'A most unfortunate start for us:',$mesg);
        return ();
    }


    #  Make sure the GRIB directory exists
    #
    if (my $err = &Others::mkdir($hash{wrfprd})) {
        my $mesg = "There I was, just checking on your $hash{domname}/wrfprd directory, and something broke.\n\n".
                   "Error: $err";
        $ENV{OMESG} = &Ecomm::TextFormat(0,0,88,0,0,'I made this mess, now you clean it up!',$mesg);
        return ();
    }


    #------------------------------------------------------------------------------------------
    #  The domain information comes in three flavors; 
    #
    #     1. The localized domains   - Info available from the geog files under static/ and
    #                                  are needed for the grid dimension information.
    #
    #     2. The simulation domains  - Info available from the namelist.wrfm file and 
    #                                  output files under wrfprd/ 
    #
    #     3. The domains to process  - Available from the --domains flag
    #
    #  Start by getting the list of domains included in the simulation from the namelist.wrfm
    #  and then extracting the navigation from the geog files for those domains.
    #------------------------------------------------------------------------------------------
    #
    my @simdoms  = map {$hash{wrfnlh}{DOMAINS}{grid_allowed}[$_-1] eq 'T' ? ($_) : ()} @{$hash{wrfnlh}{DOMAINS}{grid_id}};
    my @reqdoms  = split /,/ => $Oconf{flags}{domains};
    my @postdoms = &Others::ArrayIntersection(@simdoms,@reqdoms);


    #------------------------------------------------------------------------------------------
    #  Check whether the domains passed to --domain are valid
    #------------------------------------------------------------------------------------------
    #
    unless (@postdoms) {
        my $d    = (@reqdoms == 1) ? 'domain' : 'domains';
        my $str  = &Ecomm::JoinString(\@reqdoms); $str  = (@reqdoms == 1) ? "$str, was" : "$str, were";
        my $mesg = "I beg your pardon, but the $d that you requested for post processing, $str not included in ".
                   "the simulation according to the static/namelist.wrfm file. Are you sure you passed the ".
                   "correct domain IDs to \"--domain\"?";
        $ENV{OMESG} = &Ecomm::TextFormat(0,0,88,0,0,'A most unfortunate start for us:',$mesg);
        return ();
    }


    if (my @miss = &Others::ArrayMissing(\@reqdoms,\@simdoms)) {
        my $pstr  = &Ecomm::JoinString(\@postdoms); $pstr  = (@postdoms == 1) ? "domain $pstr" : "domains $pstr";
        my $mstr  = &Ecomm::JoinString(\@miss);     $mstr  = (@miss == 1)     ? "domain $mstr was" : "domains $mstr were";
        my $d     = (@miss == 1) ? 'domain' : 'domains';
        my $mesg = "Were you aware that $mstr not included in the simulation?  That's a rhetorical question because if you had ".
                   "been awake, you would not have included the $d for post processing. Regardless, I will continue with the ".
                   "processing of $pstr.";
        &Ecomm::PrintMessage(6,9,84,1,2,'At least you get partial credit for your effort:',$mesg);
     }
    

    %{$penv{postdoms}} = ();  # Hash holds information on the domains to be processed

    if ($hash{core} eq 'ARW') {

        #  Check for any existing processed initialization files
        #  
        %{$hash{geofls}}  = ();
        foreach (sort &Others::FileMatch($hash{static},'^geo_(.+)\.d\d\d\.nc$',1,0)) {
            if (/d(\d\d)\./) {my $d=$1;$d+=0;$hash{geofls}{$d} = $_;}
        }


        #  Likely need to move this test after the configuration because the user may
        #  just want to get the configuration information prior to running ems_prep.
        #
        unless (%{$hash{geofls}}) {
            my $mesg = "While I like your enthusiasm (and style), there appears to be a serious problem in that ".
                       "I am unable to locate the terrestrial datasets (geo_*) located under $hash{static}. I'm sure ".
                       "this was just a case of mis-communication, so go find files, run ems_prep and ems_run before ".
                       "attempting ems_post again.";
            $ENV{OMESG} = &Ecomm::TextFormat(0,0,84,0,0,"Let's try this again, from the very top:",$mesg);
            return ();
        }


        #------------------------------------------------------------------------------------------
        #  Collect the navigation information from the GEOG files under static/
        #------------------------------------------------------------------------------------------
        #  
        foreach my $g (sort {$a <=> $b} keys %{$hash{geofls}}) {
            my $d  = &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'grid_id'); $d = $g unless $d;
            next unless grep {/^$d$/} @postdoms;
            $penv{postdoms}{$d}{geofile}= "$hash{static}/$hash{geofls}{$g}";
            $penv{postdoms}{$d}{nx}     = &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'WEST-EAST_GRID_DIMENSION');
            $penv{postdoms}{$d}{ny}     = &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'SOUTH-NORTH_GRID_DIMENSION');
            $penv{postdoms}{$d}{dx}     = &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'DX');
            $penv{postdoms}{$d}{dy}     = &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'DY');
            $penv{postdoms}{$d}{clat}   = &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'CEN_LAT');
            $penv{postdoms}{$d}{clon}   = &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'CEN_LON');

            #  The following arrays will hold the names of existing simulation output files of each type
            #
            @{$penv{postdoms}{$d}{wrffls}} = ();
            @{$penv{postdoms}{$d}{auxfls}} = ();
            @{$penv{postdoms}{$d}{afwfls}} = ();
        }
        my $maxdoms  = max keys %{$penv{postdoms}};;
        my $lastidx  = $maxdoms-1;


        # Information from the simulation namelist file
        #
        my @rvals             = (0) x $maxdoms;  # @rvals set to last value
        my @cvals             = @rvals;
        $penv{global}         = ($hash{wpsnlh}{GEOGRID}{map_proj}[0]  =~ /lat-lon/i and ! defined $hash{wpsnlh}{GEOGRID}{dx}) ? 1 : 0;

        my $fname_wrf         = $hash{wrfnlh}{TIME_CONTROL}{history_outname}[0];    $fname_wrf = 'wrfout_d<domain>_<date>'   unless $fname_wrf;
        @{$penv{hist}{wrf}}   = defined $hash{wrfnlh}{TIME_CONTROL}{history_interval}    ? @{$hash{wrfnlh}{TIME_CONTROL}{history_interval}}   : @rvals;
        @{$penv{frames}{wrf}} = defined $hash{wrfnlh}{TIME_CONTROL}{frames_per_outfile}  ? @{$hash{wrfnlh}{TIME_CONTROL}{frames_per_outfile}} : @rvals; 
        @cvals = @rvals; splice @cvals, 0, @{$penv{hist}{wrf}}, @{$penv{hist}{wrf}};  @{$penv{hist}{wrf}} = @cvals[0..$lastidx];

        my $fname_aux         = $hash{wrfnlh}{TIME_CONTROL}{auxhist1_outname}[0];   $fname_aux = 'auxhist1_d<domain>_<date>' unless $fname_aux;
        @{$penv{hist}{aux}}   = defined $hash{wrfnlh}{TIME_CONTROL}{auxhist1_interval}   ? @{$hash{wrfnlh}{TIME_CONTROL}{auxhist1_interval}}   : @rvals;
        @{$penv{frames}{aux}} = defined $hash{wrfnlh}{TIME_CONTROL}{frames_per_auxhist1} ? @{$hash{wrfnlh}{TIME_CONTROL}{frames_per_auxhist1}} : @rvals;
        @cvals = @rvals; splice @cvals, 0, @{$penv{hist}{aux}}, @{$penv{hist}{aux}};  @{$penv{hist}{aux}} = @cvals[0..$lastidx];

        my $fname_afw         = $hash{wrfnlh}{TIME_CONTROL}{auxhist2_outname}[0];   $fname_afw = 'auxhist2_d<domain>_<date>' unless $fname_afw;
        @{$penv{hist}{afw}}   = defined $hash{wrfnlh}{TIME_CONTROL}{auxhist2_interval}   ? @{$hash{wrfnlh}{TIME_CONTROL}{auxhist2_interval}}   : @rvals;
        @{$penv{frames}{afw}} = defined $hash{wrfnlh}{TIME_CONTROL}{frames_per_auxhist2} ? @{$hash{wrfnlh}{TIME_CONTROL}{frames_per_auxhist2}} : @rvals;
        @cvals = @rvals; splice @cvals, 0, @{$penv{hist}{afw}}, @{$penv{hist}{afw}};  @{$penv{hist}{afw}} = @cvals[0..$lastidx];


        foreach my $fname ($fname_wrf, $fname_aux, $fname_afw) {
            $fname =~ s/\'|\"//g;
            next unless $fname;
            $fname = substr $fname, 0, index($fname, '<');
        }


        #  Get the simulation start, stop (epoc seconds), and length (seconds) for each domain
        #  
        my $syr = $hash{wrfnlh}{TIME_CONTROL}{start_year}[0];
        my $smo = $hash{wrfnlh}{TIME_CONTROL}{start_month}[0]; $smo = "0$smo" if length $smo == 1;
        my $sdy = $hash{wrfnlh}{TIME_CONTROL}{start_day}[0];   $sdy = "0$sdy" if length $sdy == 1;
        my $shr = $hash{wrfnlh}{TIME_CONTROL}{start_hour}[0];  $shr = "0$shr" if length $shr == 1;
        my $smn = $hash{wrfnlh}{TIME_CONTROL}{start_minute}[0];$smn = "0$smn" if length $smn == 1;
        my $ssc = $hash{wrfnlh}{TIME_CONTROL}{start_second}[0];$ssc = "0$ssc" if length $ssc == 1;
        $penv{sdate}  = &Others::CalculateEpochSeconds("$syr$smo$sdy$shr$smn$ssc");

        my $eyr = $hash{wrfnlh}{TIME_CONTROL}{end_year}[0];
        my $emo = $hash{wrfnlh}{TIME_CONTROL}{end_month}[0]; $emo = "0$emo" if length $emo == 1;
        my $edy = $hash{wrfnlh}{TIME_CONTROL}{end_day}[0];   $edy = "0$edy" if length $edy == 1;
        my $ehr = $hash{wrfnlh}{TIME_CONTROL}{end_hour}[0];  $ehr = "0$ehr" if length $ehr == 1;
        my $emn = $hash{wrfnlh}{TIME_CONTROL}{end_minute}[0];$emn = "0$emn" if length $emn == 1;
        my $esc = $hash{wrfnlh}{TIME_CONTROL}{end_second}[0];$esc = "0$esc" if length $esc == 1;
        $penv{edate}  = &Others::CalculateEpochSeconds("$eyr$emo$edy$ehr$emn$esc");

        $penv{length} = $penv{edate} - $penv{sdate};  #  Length of simulation in seconds


        #  Collect and sort the files in the wrfprd/ directory
        #
        foreach (sort &Others::FileMatch($hash{wrfprd},"^${fname_wrf}",1,0)) {
            if (/d(\d\d)_/) {my $d=$1;$d+=0;push @{$penv{postdoms}{$d}{wrffls}} => "$hash{wrfprd}/$_" if grep {/^$d$/} @postdoms;}
        }

        foreach (sort &Others::FileMatch($hash{wrfprd},"^${fname_aux}",1,0)) {
            if (/d(\d\d)_/) {my $d=$1;$d+=0;push @{$penv{postdoms}{$d}{auxfls}} => "$hash{wrfprd}/$_" if grep {/^$d$/} @postdoms;}
        }

        foreach (sort &Others::FileMatch($hash{wrfprd},"^${fname_afw}",1,0)) {
            if (/d(\d\d)_/) {my $d=$1;$d+=0;push @{$penv{postdoms}{$d}{afwfls}} => "$hash{wrfprd}/$_" if grep {/^$d$/} @postdoms;}
        }

        #  Get the dimain initialization date/time from the netCDF files. We need to probe all files should
        #  one dataset not be available.
        #
        foreach my $d (sort {$a <=> $b} keys %{$penv{postdoms}}) {
            $penv{postdoms}{$d}{initdate} = '';
            $penv{postdoms}{$d}{initdate} = &Others::NetcdfInitTime($penv{postdoms}{$d}{afwfls}[0]) if @{$penv{postdoms}{$d}{afwfls}};
            $penv{postdoms}{$d}{initdate} = &Others::NetcdfInitTime($penv{postdoms}{$d}{auxfls}[0]) if @{$penv{postdoms}{$d}{auxfls}} and ! $penv{postdoms}{$d}{initdate};
            $penv{postdoms}{$d}{initdate} = &Others::NetcdfInitTime($penv{postdoms}{$d}{wrffls}[0]) if @{$penv{postdoms}{$d}{wrffls}} and ! $penv{postdoms}{$d}{initdate};

            $penv{postdoms}{$d}{wrfhint}  = @{$penv{postdoms}{$d}{wrffls}} ? &Others::ReadVariableNC($penv{postdoms}{$d}{wrffls}[0],'HISTORY_INTERVAL')  : 0;
            $penv{postdoms}{$d}{auxhint}  = @{$penv{postdoms}{$d}{auxfls}} ? &Others::ReadVariableNC($penv{postdoms}{$d}{auxfls}[0],'AUXHIST1_INTERVAL') : 0;

            $penv{postdoms}{$d}{wrfframes}= @{$penv{postdoms}{$d}{wrffls}} ? &Others::ReadVariableNC($penv{postdoms}{$d}{wrffls}[0],'FRAMES_PER_OUTFILE')  : 0;
            $penv{postdoms}{$d}{auxframes}= @{$penv{postdoms}{$d}{auxfls}} ? &Others::ReadVariableNC($penv{postdoms}{$d}{auxfls}[0],'FRAMES_PER_AUXHIST1') : 0;

        }

    }
    

    unless (keys %{$penv{postdoms}}) {
        my $grm  = (@postdoms == 1) ? "it doesn't" : "they don't";
        my $str  = &Ecomm::JoinString(\@postdoms); $str  = (@postdoms == 1) ? "domain $str is" : "domains $str are";
        my $mesg = "While I like your enthusiasm (and style), there appears to be a serious problem in that $str ".
                   "unknown to the UEMS, as though $grm even exist. I'm sure this is just a case of mis-communication, ".
                   "so go collect yourself and start from the beginning by running ems_domain again. I'm counting on you!";
        $ENV{OMESG} = &Ecomm::TextFormat(0,0,84,0,0,'Enough practice already!',$mesg);
        return ();
    }


    #  Keep it simple - The %hash hash contains some variables that are needed but many more that are not.
    #  Just write the desired ones to the %post hash.
    #
    $penv{domname}  = $hash{domname};
    $penv{dompath}  = $hash{dompath};
    $penv{postconf} = $hash{postconf};
    $penv{static}   = $hash{static};
    $penv{core}     = $hash{core};
    $penv{logdir}   = $hash{logdir};
    $penv{emsprd}   = $hash{emsprd};  # The default location. May be overridden
    $penv{wrfprd}   = $hash{wrfprd};


    #  Almost there - set the default data table directory
    #
    $penv{tables}{grib}   = "$ENV{DATA_TBLS}/post/grib2";
    $penv{tables}{bufr}   = "$ENV{DATA_TBLS}/post/bufr";
    $penv{tables}{crtm2}  = "$ENV{DATA_TBLS}/post/crtm2/Big_Endian";


    #  Finally, set the value for $ENV{POST_DBG} that defines the level of debugging 
    #
    $ENV{POST_DBG}  = $Oconf{flags}{debug};


return %penv;
}  #  SetRuntimeEnvironment



