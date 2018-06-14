#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Pinit.pm
#
#  DESCRIPTION:  Pinit contains each of the primary routines used for the
#                initialization of the Uprep hash shortly after ems_prep
#                starts.
#                
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Pinit;

use warnings;
use strict;
require 5.008;
use English;

use Ecomm;
use Ecore;
use Elove;
use Others;



sub PrepInitialize {
#==================================================================================
#  Initialize the common hashes and variables used by ems_prep
#==================================================================================
#
use Cwd;

    my $upref  = shift;  
    my %Uprep  = %{$upref};


    unless (defined $ENV{UEMS} and $ENV{UEMS} and -e $ENV{UEMS}) {
        print '\n\n    !  The UEMS environment is not properly set - EXIT\n\n';
        return ();
    }


    #----------------------------------------------------------------------------------
    #  Initialize $ENV{PMESG}, which used to be @{$ENV{UMESG}} but resulted
    #  in conflicts is another UEMS routine was running (See autopost.pl).
    #----------------------------------------------------------------------------------
    #
    $ENV{PMESG} = '';


    #----------------------------------------------------------------------------------
    #  The $ENV{PRN} environment variable holds the indexing for Roman Numerals
    #----------------------------------------------------------------------------------
    #
    $ENV{PRN}   = 0;


    #  ----------------------------------------------------------------------------------
    #  Set default language to English because the UEMS attempts to match English
    #  words when attempting to get system information.
    #  ----------------------------------------------------------------------------------
    #
    $ENV{LC_ALL} = 'C';


    #----------------------------------------------------------------------------------
    #  Populate the %Uprep hash with the information about the system
    #----------------------------------------------------------------------------------
    #
    return () unless %{$Uprep{emsenv}} = &Ecore::SysInitialize(\%Uprep);


    #----------------------------------------------------------------------------------
    #  Make the lower-level keys lower case. This is for no particular reason
    #  other than that's the way I like it, which is also the way I should have
    #  written it in the first place but didn't and I'm too lazy to change.
    #
    #  "Hey you kids, get off my simulated lawn!"
    #----------------------------------------------------------------------------------
    #
    foreach my $key (keys %{$Uprep{emsenv}}) { my $lk = lc $key;
        $Uprep{emsenv}{$lk} = $Uprep{emsenv}{$key}; delete $Uprep{emsenv}{$key};
    }

    
    #----------------------------------------------------------------------------------
    #  $Uprep{apf} shifts the messages an additional 3 spaces to the right when
    #  ems_prep is being run via ems_autorun.pl
    #----------------------------------------------------------------------------------
    #
    $Uprep{arf} = $Uprep{emsenv}{autorun} ? 3 : 0;


    #----------------------------------------------------------------------------------
    #  Read the uems_prep global configuraton file located in the conf/ems_prep
    #  directory.
    #----------------------------------------------------------------------------------
    #
    return () unless %{$Uprep{pconf}} = &ReadGlobalConf();


    #  Define the user's run-time domain directory
    #
    return () unless %{$Uprep{rtenv}}   = &SetRuntimeEnvironment($Uprep{emsenv}{cwd});


    #----------------------------------------------------------------------------------
    #  At this point time to redefine the $ENV{EMS_RUN} variable
    #----------------------------------------------------------------------------------
    #
    $ENV{EMS_RUN} = $Uprep{emsenv}{cwd};


    
    #  Read the namelist file
    #
    return () unless %{$Uprep{masternl}} = &ReadPrepMasterNamelist($Uprep{rtenv}{wpsnl}); 


    #----------------------------------------------------------------------------------
    #  Prove the user with some well-deserved information
    #----------------------------------------------------------------------------------
    #
    &Elove::Greeting('ems_prep',$Uprep{emsenv}{uemsver},$Uprep{emsenv}{sysinfo}{shost}) unless $Uprep{emsenv}{autorun};


    #  Open the log file and keep it open until the end of ems_prep
    #
#   $Uprep{logfile} = "$Uprep{rtenv}{logdir}/uemsprep.$Uprep{emsenv}{ldat}.log";
#   open (my $lfh, '>', $Uprep{logfile}) || die "Can not open log file - $Uprep{logfile}";


return %Uprep;
}



sub SetRuntimeEnvironment {
#==================================================================================
#  Set the run-time environment for running ems_prep. Note that the contents 
#  of %hash are returned to &PrepInitialize as %{$Uprep{rtenv}}.
#==================================================================================
#
    my %hash   = ();

    my $emsrun = Cwd::realpath(shift) || return %hash;

    return () unless %hash = &Others::RuntimeEnvironment($emsrun);

    #  Make sure the GRIB directory exists
    #
    if (my $err = &Others::mkdir($hash{grbdir})) {
        my $mesg = "There I was, just checking on your $hash{domname}/grib directory, and something broke.\n\n".
                   "Error: $err";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,0,'I made this mess, now you clean it up!',$mesg);
        return ();
    }


    #  Has the domain been localized?  Check by looking for the "geo_*.nc" files 
    #  in the static directory. We need this information anyway.
    #
    @{$hash{geofls}} = sort &Others::FileMatch($hash{static},'^geo_(.+)\.d\d\d\.nc$',1,0);

    unless (@{$hash{geofls}}) {
        my $mesg = "While I like your enthusiasm (and style), you will need to complete a successful ".
                   "localization before running ems_prep. It appears this task was never done or it ".
                   "failed miserably while you were off doing something else such as looking at something ".
                   "shiny (yet again). You can correct this problem by simply running the following from ".
                   "your \"$hash{domname}\" domain directory:\n\n".
                   "X02X%  ems_domain --localize\n\n".
                   "and then return to me after you are successful. I like the smell of success!";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,84,0,0,"Let's try this again, from the top:",$mesg);
        return ();
    }

    $hash{maxdoms}   = @{$hash{geofls}};  #  Maximum number of domains

 
    #  Some of the information in the geo_* files will be used later
    #  
    my @d01 = grep /d01/ =>  @{$hash{geofls}};
    $hash{modis}  = (&Others::ReadVariableNC("$hash{static}/$d01[0]",'MMINLU') =~ /MODIS/i) ? 1 : 0;
    $hash{islake} = (&Others::ReadVariableNC("$hash{static}/$d01[0]",'ISLAKE') == -1) ? 0 : 1;


return %hash;
}



sub ReadGlobalConf {
#==================================================================================
#  Read global configuration file in the uems/conf/ems_prep directory.
#==================================================================================
    my %confs = ();

    my $conf = "$ENV{EMS_CONF}/ems_prep/prep_global.conf";

    unless (-s $conf) {
        my $mesg = "Missing ems_prep global configuration file: $conf";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,255,0,0,'Trouble getting started?',$mesg);
        return ();
    }

    %confs = &Others::ReadConfigurationFile($conf);

return %confs;
}


sub ReadPrepMasterNamelist {
#==================================================================================
#  Read the run-time domain namelist.wps file and define necessary variables
#==================================================================================
#
    my %masternl = ();

    my $nlfile = shift || return %masternl;

    unless (-s $nlfile) {
        my $mesg = "Missing namelist file: $nlfile \n\nDid you forget to localize your domain?";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,255,0,0,'Trouble getting started?',$mesg);
        return ();
    }

    
    unless (%masternl = &Others::Namelist2Hash($nlfile)) {
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,255,0,0,'The ReadPrepMasterNamelist routine',"BUMMER: Problem reading $nlfile");
        return ();
    }


    #  Make sure tat there is only a single entry for the ref I/J values.
    #
    @{$masternl{GEOGRID}{ref_x}} = ();
    @{$masternl{GEOGRID}{ref_y}} = ();
    $masternl{GEOGRID}{ref_x}[0] = $masternl{GEOGRID}{e_we}[0]/2;
    $masternl{GEOGRID}{ref_y}[0] = $masternl{GEOGRID}{e_sn}[0]/2;


    ($masternl{core}   = uc $masternl{SHARE}{wrf_core}[0]) =~ s/'//g;
    $masternl{global}  = ($masternl{GEOGRID}{map_proj}[0]  =~ /lat-lon/i and ! defined $masternl{GEOGRID}{dx}) ? 1 : 0;
    $masternl{maxdoms} = $masternl{SHARE}{max_dom}[0];

    @{$masternl{SHARE}{active_grid}} = ('.false.') x $masternl{maxdoms};

return %masternl;
}



