#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Rconf.pm
#
#  DESCRIPTION:  Rconf contains each of the primary routines used for the
#                final configuration of ems_run. It's the least elegant of
#                the ems_run modules simply because there is a lot of sausage
#                making going on.
#
#                A lot of sausage making
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Rconf;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Rconf %Conf %Urun);


sub RunConfiguration {
#==================================================================================
#  Routine that calls each of the configuration subroutines. For ems_run:
#
#    1. Do the initial checks of any command line flags passed
#    2. Read the default WRFM namelist file
#    3. Read the default configuration files in conf/ems_run/...
#    4. Get the domain configuration including initialization and restart files
#    5. Read the user local simulation configuration
#    6. Make some sense of everything
#==================================================================================
#
use Rflags;

    my $upref     = shift; %Urun = %{$upref};

    $Urun{emsenv}{autorun} ? &Ecomm::PrintMessage(0,7,144,1,1,sprintf("%-4s AutoRun:  Attempting to make sense of your configuration",&Ecomm::GetRN($ENV{RRN}++)))  :
    $Urun{emsenv}{bench}   ? &Ecomm::PrintMessage(0,4,144,1,1,sprintf("%-4s Benchmark:  Attempting to make sense of your configuration",&Ecomm::GetRN($ENV{RRN}++))) 
                           : &Ecomm::PrintMessage(0,4,144,1,1,sprintf("%-4s Attempting to make sense of your configuration",&Ecomm::GetRN($ENV{RRN}++)));


    #----------------------------------------------------------------------------------
    #  The %Rconf hash will hold all the collected information until it can be
    #  sorted out. The following keys are used to hold the information:
    #
    #    a.  %Rconf{flags}  - Command line flag configurations
    #    b.  %Rconf{dinfo}  - Domain configuration and information
    #----------------------------------------------------------------------------------
    #
    %Rconf  = (); #  %Rconf is the "work" hash and contains many temporary 
                  #  variables used in the various configuration routines
                  #  within this module.

    $Rconf{arf} =  $Urun{emsenv}{autorun} ? 3 : 0;   #  Needed for formatting in &ConfigureSimulation

    #  Begin with the final configuration of the command line flags. This step
    #  is first because we need to determine which domain is to be used for the
    #  simulation.
    #
    return () unless %{$Rconf{flags}} = &Rflags::RunFlagConfiguration(\%Urun);


    #  Collect information on the domain(s) to be post processed. This step must be 
    #  completed prior to processing the configuration files because the model core
    #  other necessary information will be used in the file parameter configuration.
    #
    return () unless %{$Rconf{rtenv}}  = &SetRuntimeEnvironment($Rconf{flags}{rundir});

 
    #  Just when you though there was enough configuration. The next step is to configure
    #  the domains to be included in the simulation. The information returned to the 
    #  %{$Rconf{dinfo}} hash includes the start & stop times for each domain as well as
    #  grid spacing, the parent, number of grid points and other information.
    #  
    return () unless %{$Rconf{dinfo}}  = &DefineRuntimeDomains(\%Rconf);

    return () unless %{$Urun{apost}}   = &RunApostConfiguration(\%Rconf);

    return () unless %{$Urun{emsrun}}  = &ConfigureSimulation(\%Rconf);  #  Will eventually need to pass model system as argument

#   return () unless %{$Urun{runinfo}} = &FormatRunInformation();

    #  Sometimes you are able to think enough in advance to anticipate and plan
    #  for the usage of variables outside of the local module, and other times 
    #  you fall on your face. Both the DINFO & rtenv hash variables will be used
    #  in the Rexe module, and thus should have been named %{$Urun{dinfo}} and
    #  %{$Urun{rtenv}} respectively, but at this point I'm in too deep to make 
    #  all the necessary changes.
    #
    #  Additionally, there are %Urun hash variables that are not used outside
    #  of this module and should be removed. Since the developer does not like messy
    #  hashes and writing about himself in the third person, a gratuitous routine
    #  has been added to clean up %Urun before sending it on it's way.
    # 
    return () unless %Urun             = &OrganizeFinalHash();

    #-------------------------------------------------------------------------------
    #  Probably a good time to do the initial clean-up of the domain directory
    #-------------------------------------------------------------------------------
    # 
    return () if &Rutils::RunCleaner($Urun{flags}{scour},$Urun{rtenv}{dompath},$Urun{emsenv}{autorun});

return %Urun;
} 



sub SetRuntimeEnvironment {
#==================================================================================
#  Collect information on the run-time domain used in the simulation
#==================================================================================
#
    my %hash   = ();

    my $emsrun = Cwd::realpath(shift) || return %hash;


    # Note that the local static/namelist.wps hash is read in RuntimeEnvironment
    #
    return () unless %hash = &Others::RuntimeEnvironment($emsrun);


    #  Make sure the GRIB directory exists
    #
    if (my $err = &Others::mkdir($hash{wrfprd})) {
        my $mesg = "There I was, just checking on your $hash{domname}/wrfprd directory, and something broke.\n\n".
                   "Error: $err";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'I made this mess, now you clean it up!',$mesg);
        return ();
    }


    #  At this point the model/core is known so collect information that is specific
    #  to the model being used.
    #
    if ($hash{core} eq 'ARW') {

        #  Check for any existing processed initialization files
        #  
        %{$hash{geofls}}  = ();
        foreach (sort &Others::FileMatch($hash{static},'^geo_(.+)\.d\d\d\.nc$',1,0)) {
            if (/d(\d\d)\./) {my $d=$1;$d+=0;$hash{geofls}{$d} = $_;}
        }

        %{$hash{wpsfls}}  = ();
        foreach (sort &Others::FileMatch($hash{wpsprd},'^met_em\.d(\d\d)\..+.nc$',1,0)) {
            if (/d(\d\d)\./) {my $d=$1;$d+=0;push @{$hash{wpsfls}{$d}}  => $_;}
        }

        %{$hash{bdyfls}}  = ();
        foreach (sort &Others::FileMatch($emsrun,'^wrfbdy_d(\d\d)$',1,0)) {
            if (/d(\d\d)/) {my $d=$1;$d+=0;$hash{bdyfls}{$d} = $_;}
        }

        %{$hash{inifls}}  = ();
        foreach (sort &Others::FileMatch($emsrun,'^wrfinput_d(\d\d)$',1,0)) {
            if (/d(\d\d)/) {my $d=$1;$d+=0;push @{$hash{inifls}{$d}}  => $_;}
        }

        %{$hash{rstfls}}  = ();
        if (-d $hash{rstprd}) {
            foreach (sort &Others::FileMatch($hash{rstprd},'^wrfrst_d(\d\d)$',1,0)) {
                if (/d(\d\d)/) {my $d=$1;$d+=0;push @{$hash{rstfls}{$d}}  => $_;}
            }
        }

        #  Likely need to move this test after the configuration because the user may
        #  just want to get the configuration information prior to running ems_prep.
        #
        unless (%{$hash{geofls}}) {
            my $mesg = "While I like your enthusiasm (and style), there appears to be a serious problem in that ".
                       "I am unable to locate the terrestrial datasets (geo_*) located in $hash{static}. I'm sure ".
                       "this was just a case of mis-communication, but you will need to localize this domains with ".
                       "the ems_domain utility and then re-run ems_prep before using ems_run again.";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,84,0,0,"Let's try this again, from the top:",$mesg);
            return ();
        }

        #------------------------------------------------------------------------------------------
        #  Some of the information in the WPS files will be used to configure the simulation.
        #  Note that for the geogrid terrestrial files the domain ID is pulled from the file
        #  and not from the filename unless absolutely necessary.
        #------------------------------------------------------------------------------------------
        #  
        foreach my $g (sort {$a <=> $b} keys %{$hash{geofls}}) {

            my $d  = &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'grid_id'); $d = $g unless $d;

            $hash{geodoms}{$d}{geofile}= "$hash{static}/$hash{geofls}{$g}";
            $hash{geodoms}{$d}{nx}     = &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'WEST-EAST_GRID_DIMENSION');
            $hash{geodoms}{$d}{ny}     = &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'SOUTH-NORTH_GRID_DIMENSION');
            $hash{geodoms}{$d}{dx}     = &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'DX');
            $hash{geodoms}{$d}{dy}     = &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'DY');
            $hash{geodoms}{$d}{clat}   = &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'CEN_LAT');
            $hash{geodoms}{$d}{clon}   = &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'CEN_LON');
            $hash{geodoms}{$d}{parent} = &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'parent_id');
            $hash{geodoms}{$d}{pratio} = &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'parent_grid_ratio');
            $hash{geodoms}{$d}{fratio} = ($d == 1) ? 1 : $hash{geodoms}{$hash{geodoms}{$d}{parent}}{fratio} * $hash{geodoms}{$d}{pratio}; #  Family Ratio
            $hash{geodoms}{$d}{ipstart}= &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'i_parent_start');
            $hash{geodoms}{$d}{jpstart}= &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'j_parent_start');
            $hash{geodoms}{$d}{ipend}  = &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'i_parent_end');
            $hash{geodoms}{$d}{jpend}  = &Others::ReadVariableNC("$hash{static}/$hash{geofls}{$g}",'j_parent_end');
        }
        
        $hash{mproj}  =  &Others::ReadVariableNC("$hash{static}/$hash{geofls}{1}",'MAP_PROJ');
        $hash{mminlu} =  &Others::ReadVariableNC("$hash{static}/$hash{geofls}{1}",'MMINLU');
        $hash{modis}  = ($hash{mminlu} =~ /modis/i) ? 1 : 0;
        $hash{varsso} = &Others::ReadVariableNC("$hash{static}/$hash{geofls}{1}",'FLAG_VAR_SSO') ? 1 : 0;
        $hash{islake} = (&Others::ReadVariableNC("$hash{static}/$hash{geofls}{1}",'ISLAKE') == -1) ? 0 : 1;
        $hash{maxmsf} = &Others::ReadVariableNC_MaxMin("$hash{static}/$hash{geofls}{1}",'MAPFAC_M','maximum');
        $hash{maxmsf} = 1. unless $hash{maxmsf};

        if (%{$hash{wpsfls}}) {
            $hash{qnwfa}   = &Others::ReadVariableNC("$hash{wpsprd}/$hash{wpsfls}{1}[0]",'FLAG_QNWFA') ? 1 : 0;
            $hash{qnifa}   = &Others::ReadVariableNC("$hash{wpsprd}/$hash{wpsfls}{1}[0]",'FLAG_QNIFA') ? 1 : 0;
            $hash{icedpth} = &Others::ReadVariableNC("$hash{wpsprd}/$hash{wpsfls}{1}[0]",'ICEDEPTH')   ? 1 : 0;  #  Used for seaice_thickness_opt test
            $hash{snowsi}  = &Others::ReadVariableNC("$hash{wpsprd}/$hash{wpsfls}{1}[0]",'SNOWSI')     ? 1 : 0;  #  Used for seaice_snowdepth_opt test
            $hash{albsi}   = &Others::ReadVariableNC("$hash{wpsprd}/$hash{wpsfls}{1}[0]",'ALBSI')      ? 1 : 0;  #  Used for seaice_albedo_opt test
            $hash{lai12m}  = &Others::ReadVariableNC("$hash{wpsprd}/$hash{wpsfls}{1}[0]",'FLAG_LAI12M')? 1 : 0;  #  Used for rdlai2d test
            $hash{nslevs}  = &Others::ReadVariableNC("$hash{wpsprd}/$hash{wpsfls}{1}[0]",'NUM_METGRID_SOIL_LEVELS');
            $hash{nilevs}  = &Others::ReadVariableNC("$hash{wpsprd}/$hash{wpsfls}{1}[0]",'BOTTOM-TOP_GRID_DIMENSION');
            $hash{nlcats}  = &Others::ReadVariableNC("$hash{wpsprd}/$hash{wpsfls}{1}[0]",'NUM_LAND_CAT');
            $hash{mproj}   = &Others::ReadVariableNC("$hash{wpsprd}/$hash{wpsfls}{1}[0]",'MAP_PROJ');
            $hash{nwifs}   = 0;
            if ($hash{qnwfa}) {
               my %dims = &Others::ReadVariableNC_XYZ("$hash{wpsprd}/$hash{wpsfls}{1}[0]",'I_WIF_JAN');
               $hash{nwifs}   = $dims{Z};
            }
        }

  
        # Check whether the binaries were compiled with the new (V3.9) hybrid coordinate option
        #
        if (%{$hash{inifls}} and $hash{inifls}{1}[0]) {
            $hash{hybrid}  = (&Others::ReadVariableNC("$emsrun/$hash{inifls}{1}[0]",'HYBRID_OPT') == -1) ? 0 : 1;
        }
    }
    
    #  Now we can determine  whether this is a global domain
    #
    $hash{global}  = ($hash{mproj} == 6 and ! defined $hash{wpsnlh}{GEOGRID}{dx}) ? 1 : 0;

    #  Finally, set the value for $ENV{RUN_DBG} that defines the level of debugging 
    #
    $ENV{RUN_DBG} = $Rconf{flags}{debug};


return %hash;
}



sub DefineRuntimeDomains {
#==================================================================================
#  The DefineRuntimeDomains manages the domains to include in the simulation.
#  along with the start & stop times. A %Dinfo hash is returned that contains
#  the critical information used by the UEMS. 
#==================================================================================
#
    my %Dinfo = ();

    my $upref = shift; %Rconf = %{$upref};

    my %flags = %{$Rconf{flags}};
    my %renv  = %{$Rconf{rtenv}};


    #  Initialize the domains hash that will carry the final simulation start & end
    #  times for each domain.
    #
    %{$Dinfo{domains}} = ();

    
    #----------------------------------------------------------------------------------
    #  Step 1. (of many) Create a list of available initialization files for each domain
    #----------------------------------------------------------------------------------
    #
    my @geodoms = %{$renv{geofls}} ? sort {$a <=> $b} keys %{$renv{geofls}} : ();
    my @wpsdoms = %{$renv{wpsfls}} ? sort {$a <=> $b} keys %{$renv{wpsfls}} : ();
    my @inidoms = %{$renv{inifls}} ? sort {$a <=> $b} keys %{$renv{inifls}} : ();


    #----------------------------------------------------------------------------------
    #  Step 2. Create a %domains hash from $flags{domains} to contain the domains to
    #          be included in the simulation and integration length.
    #----------------------------------------------------------------------------------
    # 
    my %domains = map {split(/:/, $_) } split(/,/, $flags{domains});
    my @rundoms = sort {$a <=> $b} keys %domains;


    if (my @miss = &Others::ArrayMissing(\@rundoms,\@geodoms)) {
        my $str  = &Ecomm::JoinString(\@miss); $str  = (@miss > 1) ? "domains $str" : "domain $str";
        my $mesg = "While I like your enthusiasm (and style), there appears to be a serious problem in that I ".
                   "am unable to locate the terrestrial dataset (geo_*) located in the /static directory for ".
                   "$str. This typically means that you messed up when specifying which domains to include; ".
                   "however, it could also suggest that they were never created and thus not localized when ".
                   "running ems_domain or Domain Wizard.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,84,0,0,"Let's try this again, from the top:",$mesg);
        return ();
    }


    my @bctimes=();
    if ($flags{noreal}) {

        #  If the --noreal flag was passed then get the simulation information from the existing wrfinput_ 
        #  wrfbdy_ files, which should have been created the last time ems_run was run.
        #
        if (my @miss = &Others::ArrayMissing(\@rundoms,\@inidoms)) {
            my $dst  = &Ecomm::JoinString(\@rundoms); $dst  = (@rundoms > 1) ? "domains $dst" : "domain $dst";
            my $str  = &Ecomm::JoinString(\@miss);    $str  = (@miss    > 1) ? "files for domains $str are" : "file for domain $str is";
            my $tt   = (@miss > 1) ? 'these domains' : 'this domain';

            my $mesg = "You seem to be getting ahead of yourself with use of the \"--noreal\" flag. You first ".
                       "must run \"ems_run\" with or without the \"--nowrf\" flag to create the initial and ".
                       "boundary condition files for $dst and then get back to me.";

            $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,"Initialization $str missing!",$mesg);
            return ();
        }


        unless ($renv{global} or (defined $renv{bdyfls}{1} and $renv{bdyfls}{1})) {
            my $mesg = "You seem to be missing the boundary condition file for the primary domain, which is critical to ".
                       "running a successful simulation. No ICs, no BCs, no simulation. It's the \"No shoes, no shirt, no ".
                       "service\" rule in numerical modeling. One that the UEMS has lived by, since at least the 1960's.";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,"No BCs, No service!",$mesg);
            return ();
        }
            
        #  Read the available BC times from the wrfbdy_d01 file 
        #
        push @bctimes, &Others::DateString2DateStringWRF($_) foreach sort &Others::rmdups(&Others::NetcdfVerifTimes($renv{bdyfls}{1}));


        unless ($renv{global}) {
            #  Need to add the final time to the list since it is not listed in the wrfbdy_d01 file. Use last time + interval_seconds.
            #
            my $edate = &Others::CalculateNewDate(&Others::DateStringWRF2DateString($bctimes[-1]),$renv{wpsnlh}{SHARE}{interval_seconds}[0]);
            push @bctimes, &Others::DateString2DateStringWRF($edate);
        }

    }


    unless ($flags{noreal}) {

        #  If @wpsdoms is empty then ems_prep was not run prior to running ems_run, which
        #  is a problem unless the --runinfo flag was passed, in which case we just want
        #  to print out the configuration. This will be 
        #
        if (my @miss = &Others::ArrayMissing(\@rundoms,\@wpsdoms)) {
            my $str  = &Ecomm::JoinString(\@miss); $str  = (@miss > 1) ? "domains $str" : "domain $str";
            my $tt   = (@miss > 1) ? 'these domains' : 'this domain';

            my $mesg = "While I like your enthusiasm (and style), there appears to be a serious problem in that I am unable ".
                       "to locate the required initialization datasets for $str under wpsprd/, which should have been ".
                       "created when running ems_prep. This typically means that either you failed to include $tt for ".
                       "processing, the pre-processing crashed for some strange reason, or you completely forgot to run ems_prep.\n\n".
                       "The UEMS doesn't care why it happened, only that it doesn't happen again. So return to your ems_prep ".
                       "\"roots\" and show me that you mean business!";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,84,0,0,"Hey you, missing something?",$mesg);
            return ();
        }
        push @bctimes, &Others::DateString2DateStringWRF($_) foreach sort @{$renv{wpsfls}{1}};

    }


    #----------------------------------------------------------------------------------
    #  Step 3. Determine the length of the (primary) domain simulation, with will
    #          either be the period over which the WPS files were created or the 
    #          value in $flags{length}, whichever one is shorter. If the --sdate
    #          was passed then make sure it coincides with a WRF file date.
    #          Also, we need to take into account whether this is a global 
    #          simulation since there will only be one WPS file
    #----------------------------------------------------------------------------------
    #
    if (@bctimes) {

        #  To start, define the default length of the simulation to be that specified when 
        #  processing initialization files with ems_prep. The start and end date/times are
        #  defined as start_date & end_date respectively in the namelist.wps file.
        #
        my $sdate = $renv{wpsnlh}{SHARE}{start_date}[0]; $sdate =~ s/'|\"//g;
        my $edate = $renv{wpsnlh}{SHARE}{end_date}[0];   $edate =~ s/'|\"//g;

        unless ($sdate and $edate) {
           my $mesg = "There appears to be a problem simulation start and stop date/times as defined ".
                      "in the static/namelist.wps file. The values read from the file:\n\n".

                      "X02Xstart_date: $sdate\n".
                      "X02Xend_date  : $edate";
           $ENV{RMESG} = &Ecomm::TextFormat(0,0,84,0,0,'Problem with simulation start & end dates:',$mesg);
           return ();
        }

        my $ssecs = &Others::CalculateEpochSeconds(&Others::DateStringWRF2DateString($sdate));
        my $esecs = &Others::CalculateEpochSeconds(&Others::DateStringWRF2DateString($edate));
        my $dsecs = $esecs - $ssecs;

        unless ($dsecs > 0) {
           my $mesg = "There appears to be a problem simulation start and stop date/times as defined ".
                      "in the static/namelist.wps file. The values read from the file:\n\n".

                      "X02Xstart_date: $sdate\n".
                      "X02Xend_date  : $edate";
           $ENV{RMESG} = &Ecomm::TextFormat(0,0,84,0,0,'Non-positive simulation length calculated:',$mesg);
           return ();
        }



        #  If the --sdate flag was passed then make sure the date/time is valid and that there is
        #  a corresponding WPS file. Note that a problem should only occur if the user requests a
        #  start date/time that does not coincide with an available initialization file.
        #
        $sdate = $flags{sdate} ? &Others::DateString2DateStringWRF($flags{sdate}) : $sdate;

        unless ($flags{runinfo}) {
            my $i = &Others::StringIndexMatch($sdate,@bctimes);
            if ($i < 0) {  # $i will be less than 0 for failed match
                my $mesg = "Something is not quite right in your UEMS world as there is no initialization ".
                           "file that matches the requested simulation start date ($sdate). Maybe you need ".
                           "to check the date stamps on the files in the wpsprd directory and try again.";
                $ENV{RMESG} = &Ecomm::TextFormat(0,0,84,0,0,'Having problems with --sdate?',$mesg); 
                return ();
            }
            @bctimes = @bctimes[$i..$#bctimes];
        }

        #  Get updated simulation start date & seconds
        #
        $ssecs = &Others::CalculateEpochSeconds(&Others::DateStringWRF2DateString($sdate));

        
        #  Check to make sure the simulation start date/time is not after or the same as the 
        #  final available initialization file time. This is only important for limited area
        #  domain simulations.
        # 
        if (! $renv{global} and $ssecs >= $esecs) {
            my $mesg = ($ssecs == $esecs) ? 'is the same as' : 'is after';
            $mesg = "It appears that your requested start time ($sdate) $mesg the simulation end ($edate). ".
                    "Maybe you just got carried away with the \"--sdate\" flag but something has to change in ".
                    "this relationship, and it\'s not me!";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Problem with Simulation Start',$mesg);
            return ();
        }


        
        #  Now that we have a start date/time have been established, determine the simulation end time. 
        #  By default, this value is obtained from end_date in namelist.wps; however, if this is a global
        #  simulation then the user may extend the period of integration by passing the --length flag.
        #  Additionally, the user may also reduce the simulation length with the --length flag provided 
        #  the ending date/time coincides with an available BC update file.
        #
        my $isecs = $renv{wpsnlh}{SHARE}{interval_seconds}[0];
        my $lsecs = $esecs-$ssecs; $lsecs = 0 unless $lsecs > 0;


        
        #  SIMULATION (PRIMARY DOMAIN) LENGTH NOTES
        #
        #  Coming into this routine, the value of $flags{length} contains the user requested
        #  simulation length while $lsecs contains the simulation length as defined when ems_prep
        #  was run. Consequently the value of $flags{length} takes priority when $flags{length} 
        #  is less than $lsecs UNLESS it is a global simulation, in which case $flags{length}
        #  is used.
        #
        #  Note that is the --sdate flag was passed then the value of $flags{length} will be 
        #  decreased by the amount of time that the simulation start was advanced.
        #
        $flags{length} = 0 unless $flags{length} > 0;
        $flags{length} = $lsecs unless $flags{length};

        if ($flags{length} > $lsecs and ! $renv{global}) {
            my $nstr = &Ecomm::FormatTimingString($lsecs);
            my $ostr = &Ecomm::FormatTimingString($flags{length});
            my $mesg = "You must be getting carried away by your UEMS euphoria but the requested length ".
                       "of your simulation ($ostr) is greater than the processed initialization files will allow.\n\n".
                       "Reseting the simulation length to $nstr (End @ $edate).";
            &Ecomm::PrintMessage(6,9+$Urun{arf},88,1,2,'Simulation Length Gone Too Far:',$mesg);
            $flags{length} = $lsecs;
        }


        if ($flags{length} == 0) { 
            my $mesg = "I have no idea what just happened but I am unable to determine the length for your ".
                       "simulation. Try passing the \"--length\" flag but if that does not work there is ".
                       "something else going on that neither of us can control.";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,84,0,0,'Incorrect Simulation Length:',$mesg);
            return ();
        }



        #  Make sure that the Simulation end date/time coincides with a BC update file time
        #
        $edate = &Others::CalculateNewDate(&Others::DateStringWRF2DateString($sdate),$flags{length});
        $edate = &Others::DateString2DateStringWRF($edate);
        $esecs = &Others::CalculateEpochSeconds(&Others::DateStringWRF2DateString($edate));


        unless ($renv{global})  {  #  Do not need check for end file - global domain

            my $i = &Others::StringIndexMatch($edate,@bctimes);

            if ($i < 0) {  # A value of -1 indicates the BC update file time was not processed
    
                my $mesg1 = "Something is not quite right in your UEMS world as there is no initialization file ".
                            "that coincides with the calculated simulation end date/time of $edate.\n\n";
    
                #  Increment $flags{length} 1 second until it is an integer multiple of the BC update frequency
                #
                $flags{length}++ while $flags{length}%$isecs;
                $edate = &Others::CalculateNewDate(&Others::DateStringWRF2DateString($sdate),$flags{length});
                $edate = &Others::DateString2DateStringWRF($edate);
                $i     = &Others::StringIndexMatch($edate,@bctimes);
    
                if ($i < 0) { 
                    my $mesg2 = "Unfortunately, I attempted to make the most of the situation but I just could not figure out ".
                                "where you went so horribly wrong. Probably Kindergarten!";
                    $ENV{RMESG} = &Ecomm::TextFormat(0,0,94,0,0,'At least we know who\'s to blame:',"$mesg1$mesg2");
                    return ();
                }

                my $ostr  = &Ecomm::FormatTimingString($flags{length});
                my $mesg2 = "No worries, as I adjusted the length of your primary domain simulation to the next closest ".
                            "available file time:\n\n".
                            "X02XSimulation Start: $sdate\n".
                            "X02XSimulation End:   $edate\n\n".
                            "which will make your simulation length $ostr.";
                &Ecomm::PrintMessage(6,9+$Urun{arf},94,1,2,'Simulation Length Gone Not Far Enough:',"$mesg1$mesg2");
            }
            @bctimes = @bctimes[0..$i];

        }

        $Dinfo{domains}{1}{sdate}    = $sdate;
        $Dinfo{domains}{1}{edate}    = $edate;
        $Dinfo{domains}{1}{length}   = $esecs - $ssecs; 
        $Dinfo{domains}{1}{parent}   = 1;
        $Dinfo{domains}{1}{nx}       = $renv{geodoms}{1}{nx};
        $Dinfo{domains}{1}{ny}       = $renv{geodoms}{1}{ny};
        $Dinfo{domains}{1}{mproj}    = $renv{mproj};
        $Dinfo{domains}{1}{dx}       = $renv{geodoms}{1}{dx};
        $Dinfo{domains}{1}{dy}       = $renv{geodoms}{1}{dy};
        $Dinfo{domains}{1}{pratio}   = $renv{geodoms}{1}{pratio};
        $Dinfo{domains}{1}{fratio}   = $renv{geodoms}{1}{fratio};
        $Dinfo{domains}{1}{clat}     = $renv{geodoms}{1}{clat};
        $Dinfo{domains}{1}{clon}     = $renv{geodoms}{1}{clon};
        $Dinfo{domains}{1}{maxmsf}   = $renv{maxmsf};
        $Dinfo{domains}{1}{interval} = $isecs;   #  BC update interval

        @{$Dinfo{domains}{1}{wpsfiles}} = @bctimes ? $flags{runinfo} ? () : $renv{global} ? $bctimes[0] : @bctimes : ();
    }
    $domains{1} = $Dinfo{domains}{1}{length}; #  Will need shortly


    #----------------------------------------------------------------------------------
    #  Step 4. Determine whether and parent domains were excluded from the list
    #          of domains to use in the simulation. Begin with the largest number
    #          domain in @rundoms and check for parent in @parent_id until parent
    #          is primary domain.
    #----------------------------------------------------------------------------------
    #
    my @nests   = ();
    my @incdoms = ();
    my @parents = @{$renv{wpsnlh}{GEOGRID}{parent_id}};

    foreach my $d (sort {$b <=> $a} @rundoms) {my $p = $parents[$d-1]; while ($p > 1) {push @incdoms => $p unless defined $domains{$p}; $p = $parents[$p-1];}}

    if (@incdoms) {
        @incdoms = sort {$a <=> $b} @incdoms; @incdoms = &Others::rmdups(@incdoms);
        my $inc  = &Ecomm::JoinString(\@incdoms); 
        my $mesg = (@incdoms > 1) ? "Domains $inc must be included in the simulation as they are parents of a requested child domain. ".
                                    "Domains $inc will be added with the appropriate start and stop times.\n\nJust sit back and relax."
                                  : "Domain $inc must be included in the simulation as it is the parent of a requested child domain. ".
                                    "Domain $inc will be added with the appropriate start and stop times.\n\nJust sit back and relax.";
        &Ecomm::PrintMessage(6,9+$Urun{arf},94,1,2,'Who\'s Your Daddy?',$mesg);
        $domains{$_} = 0 foreach @incdoms;  #  Set the length of the child domain simulation to 0 for now
        
        @rundoms = sort {$a <=> $b} keys %domains;
    }

    
    
    #  Assign the simulation length for each domain. The length cannot be greater than
    #  a parent. Note that the length may need to be adjusted depending upon that start
    #  date/time.  This check is handled below.
    #
    foreach (@rundoms) {$domains{$_} = $domains{$parents[$_-1]} unless $domains{$_} and $domains{$_} <= $domains{$parents[$_-1]};}

    if (my @miss = &Others::ArrayMissing(\@rundoms,\@wpsdoms)) {
        my $str  = &Ecomm::JoinString(\@miss);
        $str  = (@miss > 1) ? "domains $str" : "domain $str";
        my $mesg = "While I like your enthusiasm (and style), there appears to be a serious problem in that I ".
                   "am unable to locate the initialization files (met_em.*) located in the /wpsprd directory for ".
                   "$str. This typically means that you messed up when specifying which domains to include; ".
                   "however, it could also suggest that they were never processed when running ems_prep.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,84,0,0,"Let's try this again, like from ems_prep:",$mesg);
        return ();
    }

 
    #----------------------------------------------------------------------------------
    #  Step 5.  Loop through and assign the simulation start & and times for each 
    #           domain. The start times for nested domains are defined when running
    #           ems_prep and can not be changed unless all fields are being
    #           interpolated from parent domain.
    #----------------------------------------------------------------------------------
    #
    foreach my $child (grep {!/^1$/} @rundoms) {

        my $parent = $renv{wpsnlh}{GEOGRID}{parent_id}[$child-1];

        my $psdate = $Dinfo{domains}{$parent}{sdate};
        my $csdate = $renv{wpsnlh}{SHARE}{start_date}[$child-1];  $csdate =~ s/'|\"//g;

        my $pssecs = &Others::CalculateEpochSeconds(&Others::DateStringWRF2DateString($psdate));
        my $cssecs = &Others::CalculateEpochSeconds(&Others::DateStringWRF2DateString($csdate));


        #  Check that the start time is not before that of the parent domain
        #
        if ($pssecs > $cssecs) {
            my $mesg = "The start date for child domain $child ($csdate) is before that of the parent domain ($psdate). ".
                       "Maybe you got carried away when passing the --sdate flag but a child domain cannot start before its parent.\n\n".

                       "The start date & time for any nested domains was defined when running ems_prep and cannot be changed in ems_run, ".
                       "so you will either have to rerun ems_prep or specify an earlier start time for Domain 1.";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,"Nested Domain $child Start Before Parent Domain",$mesg);
            return ();
        }
        $Dinfo{domains}{$child}{sdate} = $csdate;


        #  Now check the simulation end times for each domain. The simulation stop times can not be
        #  after the parent domain, but rather than terminating ems_run, provide warning.
        #  
        my $pedate = $Dinfo{domains}{$parent}{edate};  #  Format should be YYYY-MM-DD_HH:MN:SS
        my $cedate = &Others::DateString2DateStringWRF(&Others::CalculateNewDate(&Others::DateStringWRF2DateString($csdate),$domains{$child}));

        my $pesecs = &Others::CalculateEpochSeconds(&Others::DateStringWRF2DateString($pedate));
        my $cesecs = &Others::CalculateEpochSeconds(&Others::DateStringWRF2DateString($cedate));


        $Dinfo{domains}{$child}{edate}   = ( ($cesecs <= $pesecs) and ($cesecs > $cssecs) ) ? $cedate : $pedate;
        $Dinfo{domains}{$child}{length}  = $cesecs - $cssecs;  #  Simulation length in seconds


        #  This check may be redundant but that's how we roll at UEMS world headquarters
        #
        unless (@{$renv{wpsfls}{$child}} and $renv{wpsfls}{$child}[0] =~ /$Dinfo{domains}{$child}{sdate}/) {
            my $mesg = "One of us is confused. Domain $child has a requested start date and time of $Dinfo{domains}{$child}{sdate}, but ".
                       "I am unable to find a corresponding WPS file in the wpsprd/ directory.\n\nI need some \"me\" time!";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,94,0,0,"Missing initialization file for domain $child",$mesg);
            return ();
        }


        $Dinfo{domains}{$child}{parent} = $renv{geodoms}{$child}{parent};
        $Dinfo{domains}{$child}{pratio} = $renv{geodoms}{$child}{pratio};
        $Dinfo{domains}{$child}{fratio} = $renv{geodoms}{$child}{fratio};
        $Dinfo{domains}{$child}{nx}     = $renv{geodoms}{$child}{nx};
        $Dinfo{domains}{$child}{ny}     = $renv{geodoms}{$child}{ny};
        $Dinfo{domains}{$child}{dx}     = $renv{geodoms}{$child}{dx};
        $Dinfo{domains}{$child}{dy}     = $renv{geodoms}{$child}{dy};
        $Dinfo{domains}{$child}{clon}   = $renv{geodoms}{$child}{clon};
        $Dinfo{domains}{$child}{clat}   = $renv{geodoms}{$child}{clat};

        @{$Dinfo{domains}{$child}{wpsfiles}} = @{$renv{wpsfls}{$child}};
    }
    

    
    #---------------------------------------------------------------------------------- 
    #  Step X. Add some debugging code for later
    #----------------------------------------------------------------------------------
    #
    if ($ENV{RUN_DBG} > 0) {

        &Ecomm::PrintMessage(0,11+$Urun{arf},94,1,0,'=' x 72);
        &Ecomm::PrintMessage(4,13+$Urun{arf},255,1,1,"In &DefineRuntimeDomains");
       
        my @doms = sort {$a <=> $b} keys %{$Dinfo{domains}};
        my $str  = &Ecomm::JoinString(\@doms);
        &Ecomm::PrintMessage(0,16+$Urun{arf},255,1,1,"Simulation Domains: $str");

        foreach my $d (sort {$a <=> $b} keys %{$Dinfo{domains}}) {

            &Ecomm::PrintMessage(0,18+$Urun{arf},255,1,1,"Domain ($d) Start  : $Dinfo{domains}{$d}{sdate}");
            &Ecomm::PrintMessage(0,18+$Urun{arf},255,0,1,"Domain ($d) End    : $Dinfo{domains}{$d}{edate}");
            my $len = &Ecomm::FormatTimingString($Dinfo{domains}{$d}{length});
            &Ecomm::PrintMessage(0,18+$Urun{arf},255,0,1,"Domain ($d) Length : $len");
            &Ecomm::PrintMessage(0,18+$Urun{arf},255,0,1,"Domain ($d) Parent : $Dinfo{domains}{$d}{parent}");
            &Ecomm::PrintMessage(0,18+$Urun{arf},255,0,1,"Domain ($d) Pratio : 1:$Dinfo{domains}{$d}{pratio}");
            &Ecomm::PrintMessage(0,18+$Urun{arf},255,0,1,"Domain ($d) Fratio : 1:$Dinfo{domains}{$d}{fratio}");
            my $dx = ($Dinfo{domains}{$d}{dx} < 1000.) ? sprintf("%.1f meters",$Dinfo{domains}{$d}{dx}) : sprintf("%.3f kilometers",0.001*$Dinfo{domains}{$d}{dx});
            &Ecomm::PrintMessage(0,18+$Urun{arf},255,0,1,"Domain ($d) DX     : $dx");
            &Ecomm::PrintMessage(0,18+$Urun{arf},255,0,1,"Domain ($d) NX     : $Dinfo{domains}{$d}{nx}");
            &Ecomm::PrintMessage(0,18+$Urun{arf},255,0,1,"Domain ($d) NY     : $Dinfo{domains}{$d}{ny}");
            &Ecomm::PrintMessage(0,18+$Urun{arf},255,0,1,"Domain ($d) Clat   : $Dinfo{domains}{$d}{clat}");
            &Ecomm::PrintMessage(0,18+$Urun{arf},255,0,1,"Domain ($d) Clon   : $Dinfo{domains}{$d}{clon}");

            if ($d == 1) {
                my $maxmsf = sprintf '%.3f', $Dinfo{domains}{1}{maxmsf};
                &Ecomm::PrintMessage(0,18+$Urun{arf},255,0,1,"Domain ($d) Map SF : $maxmsf");
            }
      
            my $flds = &Ecomm::JoinString(\@{$Dinfo{domains}{$d}{wpsfiles}});
            &Ecomm::PrintMessage(0,18+$Urun{arf},255,0,1,"Domain ($d) BC TIMES: $flds") if $ENV{RUN_DBG} > 3;

        }
        &Ecomm::PrintMessage(0,11+$Urun{arf},94,0,2,'=' x 72);

    }
        

    #----------------------------------------------------------------------------------
    #  Step X.  Before leaving provide some information to the user
    #----------------------------------------------------------------------------------
    #
    &Ecomm::PrintMessage(1,11+$Urun{arf},94,1,0,'Simulation start and end times:');
    &Ecomm::PrintMessage(0,14+$Urun{arf},94,2,1, (@rundoms > 1) ? 'Domain         Start                   End              Parent' 
                                                     : 'Domain         Start                   End');
    
    &Ecomm::PrintMessage(0,14+$Urun{arf},94,0,0, (@rundoms > 1) ? '-' x 64 : '-' x 54);

    foreach my $dom (@rundoms) {
        my $parent = $dom == 1 ? ' ' : $Dinfo{domains}{$dom}{parent} ;
        my $sdate  = $Dinfo{domains}{$dom}{sdate};
        my $edate  = $Dinfo{domains}{$dom}{edate};
        my $length = &Ecomm::FormatTimingString($Dinfo{domains}{$dom}{length});
        &Ecomm::PrintMessage(0,17+$Urun{arf},94,1,0,"$dom     $sdate     $edate      $parent");
    }
    my $lstr = &Ecomm::FormatTimingString($Dinfo{domains}{1}{length});
    &Ecomm::PrintMessage(0,14+$Urun{arf},94,2,1,"Primary domain simulation length will be $lstr.");
        

return %Dinfo;
} 



sub RunApostConfiguration {
#==================================================================================
#  The &RunApostConfiguration routine manages the domains & datasets to include
#  when the UEMS Autopost processor is turned ON.
#==================================================================================
#
    my %Ainfo = ();
    my %aconf = ();

    my $upref = shift; %Rconf = %{$upref};  
 
    my %flags = %{$Rconf{flags}};
    my %rdoms = %{$Rconf{dinfo}};

    $Ainfo{autopost} = $flags{autopost};  return %Ainfo unless $flags{autopost};

    
    #----------------------------------------------------------------------------------
    #  Step 1. (of many) Create a list of domains included in the simulation and
    #          those requested for auto post-processing. The requested domains are
    #          specified by $Ainfo{autopost} on input but leave reformatted as
    #          $Ainfo{domains}, just because.
    #----------------------------------------------------------------------------------
    #
    %{$aconf{domains}} = ();
    %{$aconf{domains}} = map {split(/:/, $_, 2) } split(/,/, $Ainfo{autopost});

    my @rundoms = sort {$a <=> $b} keys %{$rdoms{domains}};
    my @apdoms  = sort {$a <=> $b} keys %{$aconf{domains}};
       @apdoms  = grep {!/^0$/} @apdoms;
       @apdoms  = @rundoms unless @apdoms;


    #----------------------------------------------------------------------------------
    #  Step 2. So which domains will be included and which removed from the AP list?
    #          The @apdoms contains the AP domains to match against the run domains.
    #----------------------------------------------------------------------------------
    # 
    if (my @miss = &Others::ArrayMissing(\@apdoms,\@rundoms)) {
        my $str  = &Ecomm::JoinString(\@miss); $str  = (@miss > 1) ? "domains $str, simply because they are" : "domain $str, simply because it is";
        my $mesg = "The UEMS Concurrent post processing will be turned OFF for $str not included in ".
                   "your simulation. Maybe next time.";
        &Ecomm::PrintMessage(6,9+$Urun{arf},88,1,2,'Autopost Domains Unavailable:',$mesg);
    }


    unless(@apdoms = sort {$a <=> $b} &Others::ArrayIntersection(@rundoms,@apdoms)) {  #  Pass @arrays and not \$references
        my $mesg = "Unfortunately, none of your requested autopost domains are included in the simulation. ".
                   "There will be no concurrent post processing for you today.";
        &Ecomm::PrintMessage(6,9+$Urun{arf},88,1,2,'UEMS Autopost Turned OFF:',$mesg);
        return ();
    }


    #----------------------------------------------------------------------------------
    #  Step 3. Populate the %{$Ainfo{domains}} hash with the domains in include
    #          in the concurrent post-processing along with the datasets.
    #----------------------------------------------------------------------------------
    #
    my $aptd = (defined $aconf{domains}{0} and $aconf{domains}{0}) ? $aconf{domains}{0} : 'wrfout'; delete $aconf{domains}{0};
    foreach my $d (@apdoms) {$aconf{domains}{$d} = $aptd unless defined $aconf{domains}{$d} and $aconf{domains}{$d};}


    #----------------------------------------------------------------------------------
    #  Step 4. Define the --domains flag that will be passed to UEMS AutoPost. This
    #          flag specifies the domains to include and the datasets to process.
    #          It's not called $Ainfo{domains} because that variable is already taken.
    #----------------------------------------------------------------------------------
    #
    $Ainfo{autopost} = 1;
    $Ainfo{domains}  = join ',', map {"$_:$aconf{domains}{$_}"} sort {$a <=> $b} keys %{$aconf{domains}};



    #----------------------------------------------------------------------------------
    #  Finally, assign the hostname of the system to be used when running ems_autopost,
    #  the local hostname, and the location of ems_autopost.pl.  Note that The %Urun
    #  hash is used to assign the local hostname because it's not available from the
    #  passed hash, which is unfortunate.
    #----------------------------------------------------------------------------------
    #
    if ($flags{ahost} eq 'localhost') {  #  Start Autopost on local system
        $Ainfo{lhost}  = 'localhost';
        $Ainfo{ahost}  = 'localhost';
    } else {
        $Ainfo{lhost}  = $Urun{emsenv}{sysinfo}{shost};
        $Ainfo{ahost}  = $flags{ahost};
    }

    $Ainfo{appid}  = 0;
    $Ainfo{apssh}  = $Ainfo{ahost} eq 'localhost'   ? 0 : 1;
    $Ainfo{apexe}  = &Others::popitpath($Rconf{rtenv}{pexe}); $Ainfo{apexe} = "$Ainfo{apexe}/ems_autopost.pl";
    $Ainfo{rundir} = $Rconf{rtenv}{dompath};
    $Ainfo{aplock} = "$Ainfo{rundir}/.uems_autopost.lock"; #  The Autopost lockfile 
    $Ainfo{aplog}  = "$Ainfo{rundir}/log/uems_autopost.log";

    &Others::rm($Ainfo{aplock}, $Ainfo{aplog});


    #----------------------------------------------------------------------------------
    #  Add some debugging code for later
    #----------------------------------------------------------------------------------
    #
    if ($flags{debug} == 1) {
        &Ecomm::PrintMessage(0,11+$Urun{arf},94,1,0,'=' x 72);
        &Ecomm::PrintMessage(4,13+$Urun{arf},255,1,2,"In &RunApostConfiguration");

        &Ecomm::PrintMessage(0,16+$Urun{arf},255,0,1,"Passed --ahost      : $Ainfo{ahost}");
        &Ecomm::PrintMessage(0,16+$Urun{arf},255,0,2,"Passed --autopost   : $flags{autopost}");

        my @doms = sort {$a <=> $b} keys %{$aconf{domains}};
        my $str  = &Ecomm::JoinString(\@doms);
        &Ecomm::PrintMessage(0,16+$Urun{arf},255,0,1,"Autopost Domains    : $str");

        $str  = &Ecomm::JoinString(\@rundoms);
        &Ecomm::PrintMessage(0,16+$Urun{arf},255,0,2,"Simulation Domains  : $str");

        foreach my $d (sort {$a <=> $b} @rundoms) {
            my $val = defined $aconf{domains}{$d} ? $aconf{domains}{$d} : 'Off';
            &Ecomm::PrintMessage(0,16+$Urun{arf},255,0,1,"Domain ($d) Autopost : $val");
        }

        &Ecomm::PrintMessage(0,16+$Urun{arf},255,1,1,"Domains Flag        : --domains $Ainfo{domains}");
        &Ecomm::PrintMessage(0,16+$Urun{arf},255,0,1,"Ahost Flag          : --apost $Ainfo{ahost}");
        &Ecomm::PrintMessage(0,16+$Urun{arf},255,0,1,"Start Autopost SSH  : $Ainfo{apssh}");
        &Ecomm::PrintMessage(0,16+$Urun{arf},255,0,1,"Autopost Path       : $Ainfo{apexe}");
        &Ecomm::PrintMessage(0,16+$Urun{arf},255,1,1,"Local Hostname      : $Ainfo{lhost}");
        &Ecomm::PrintMessage(0,16+$Urun{arf},255,1,1,"Lock Filename       : $Ainfo{aplock}");
        &Ecomm::PrintMessage(0,16+$Urun{arf},255,1,1,"Log Filename        : $Ainfo{aplog}");
        &Ecomm::PrintMessage(0,16+$Urun{arf},255,0,1,"Run-time Directory  : $Ainfo{rundir}");
        
        &Ecomm::PrintMessage(0,11+$Urun{arf},94,0,1,'=' x 72);
    }

        
return %Ainfo;
} 



sub ConfigureSimulation {
#==================================================================================
#  The ConfigureSimulation calls the appropriate configuration routines
#  depending upon the model system or core being used. Currently only the 
#  WRF ARW is available but may be expanded in the future, at which time
#  the name of the system or core will be passed into this subroutine.
#==================================================================================
#
use ARW::ARWconfig;

    my %Conf = ();
    my $system = 'arw';

    my $href = shift; my %Rconf = %{$href}; return () unless %Rconf;

    for ($system) {
        if (/arw/i)   {return () unless %Conf = &ARWconfig::NamelistControlARW(\%Rconf);}
    }

return %Conf;
}  



sub OrganizeFinalHash {
#==================================================================================
#  The &OrganizeFinalHash  subroutine makes the developer happy by preparing 
#  the %Urun hash for passage outside of this module.
#==================================================================================
#
    my %Nrun = ();

    #  Hashes to be retained from %Urun -> %Urun.
    #
    $Nrun{arf}       = $Urun{arf};   #  ARF = 'AutoRun Format'

    %{$Nrun{emsenv}} = %{$Urun{emsenv}};
    %{$Nrun{emsrun}} = %{$Urun{emsrun}};
    %{$Nrun{apost}}  = %{$Urun{apost}};

    #  %Rconf hashes to be transferred to %Nrun.
    #
    %{$Nrun{flags}} = %{$Rconf{flags}};
    %{$Nrun{dinfo}} = %{$Rconf{dinfo}};
    %{$Nrun{rtenv}} = %{$Rconf{rtenv}};


return %Nrun;  #  There, I'm happy now
}


