#!/usr/bin/perl
#===============================================================================
#
#         FILE:  UEMS_MissionControl.pl
#
#  DESCRIPTION:  
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.10.4
#      CREATED:  08 March 2018
#===============================================================================
#
require 5.008;
use strict;
use warnings;
use English;

use Cwd 'abs_path';
use FindBin qw($RealBin);
use lib (abs_path("$RealBin/../Uutils"));

use vars qw (%Ucntrl $UEMS_CONTROL);

use Others;
use Ecomm;

#  Define this process as being run on the SERVER or CLIENT side.
#
BEGIN {
    $UEMS_CONTROL = (defined $ENV{UEMS_CONTROL} and $ENV{UEMS_CONTROL}) ?  $ENV{UEMS_CONTROL} : 'CLIENT'; 
}


#  ===============================================================================
#  The mission control routine summary - someday
#  ===============================================================================
#
    
    #--------------------------------------------------------------------------
    #  Override system interrupt handler - A local one is needed since 
    #  environment variables are used for clean-up after the interrupt.
    #--------------------------------------------------------------------------
    #
    $SIG{INT} = \&SysIntHandle;


    #--------------------------------------------------------------------------
    #  &MissionIgnition sets the environment, reads the flags, and completes
    #  the configuration.  &MissionControl manages the process.
    #--------------------------------------------------------------------------
    #
    &SysExit(1,$0)  if &ReturnHandler(&MissionIgnition());  #  Ya, it rymes

    &SysExit(1,$0)  if &ReturnHandler(&MissionControl());


&SysExit(0,$0);


sub MissionIgnition {
#==================================================================================
#  The &MissionIgnition subroutine calls routines to perform the initial configuration 
#  of UEMS_MissionControl.pl prior to any real work being done. The responsibility
#  this routine is to:
#
#      1. Initialize the %Ucntrl hash with some choice information
#      2. Read and parse the user input options
#==================================================================================
#

    return 1 unless %{$Ucntrl{mcenv}}  = &SetMissionEnvironment(\%Ucntrl);
    return 1 unless %{$Ucntrl{flags}}  = &ProcessMissionOptions(\%Ucntrl);

return 0;
}



sub MissionControl {
#==================================================================================
#  The subroutine called depends upon whether UEMS_MissionControl.pl is being run 
#  in the SERVER or CLIENT side. A value of 1 is returned on failure with any 
#  messages returned via the $ENV{MCMESG} environment variable.
#==================================================================================
#

    if ($Ucntrl{mcenv}{mc_client}) {
        return 1 if &MissionControl_Client(\%Ucntrl);
    }
   
    if ($Ucntrl{mcenv}{mc_server}) {
        return 1 if &MissionControl_Server(\%Ucntrl);
    }


return 0;
}



sub SetMissionEnvironment {
#==================================================================================
#  Define the common environment variables used by Mission_Control.pl
#==================================================================================
#
use Cwd;
use Elove;
use File::Basename;

    my %mcenv    = ();

    $mcenv{mc} = 1;  #  Because this is Mission Control

    #----------------------------------------------------------------------------------
    #  Initialize $ENV{MCMESG}, which contains a text string with an explanation 
    #  should there be a problem. Contents printed out in &ReturnHandler
    #----------------------------------------------------------------------------------
    #
    $ENV{MCMESG} = '';
    $ENV{LC_ALL} = 'C';


    #----------------------------------------------------------------------------------
    #  Check whether the UEMS environment is set
    #----------------------------------------------------------------------------------
    #
    unless (defined $ENV{UEMS} and $ENV{UEMS} and -e $ENV{UEMS}) {
        $ENV{MCMESG} = "\n\n    !  The UEMS environment is not properly set - EXIT\n\n";
        return ();
    }


    #----------------------------------------------------------------------------------
    #  Ensure that $UEMS_CONTROL is properly defined 
    #----------------------------------------------------------------------------------
    #
   	unless (defined $UEMS_CONTROL and $UEMS_CONTROL) {
        $ENV{MCMESG} = "\n\n    !  UEMS_CONTROL is not defined in UEMS_MissionControl.pl - EXIT\n\n";
        return ();
    }
    $UEMS_CONTROL = uc $UEMS_CONTROL;


    unless ($UEMS_CONTROL eq 'SERVER' || $UEMS_CONTROL eq 'CLIENT') {
        $ENV{MCMESG} = "\n\n    !  UEMS_CONTROL must be defined as SERVER|CLIENT in UEMS_MissionControl.pl - EXIT\n\n";
        return ();
    }



    #------------------------------------------------------------------------------
    #   The value of $UEMS_CONTROL determines which configuration file to read.
    #   All files are located in the uems/conf/mission_control directory.
    #------------------------------------------------------------------------------
    #  
    $mcenv{mc_monitor} = ($UEMS_CONTROL eq 'MONITOR') ? 'MissionControl-Monitor' : 0;
    $mcenv{mc_client}  = ($UEMS_CONTROL eq 'CLIENT')  ? 'MissionControl-Client'  : 0;
    $mcenv{mc_server}  = ($UEMS_CONTROL eq 'SERVER')  ? 'MissionControl-Server'  : 0;

    
    #----------------------------------------------------------------------------------
    #  Populate the %mcenv  hash with the information about the system
    #----------------------------------------------------------------------------------
    #
    $mcenv{core}   = 'ARW';  #  Changed someday

    $mcenv{mcpid}  = $$;
    $mcenv{mcexe}  = &Others::popit($0);
    $mcenv{mccwd}  = cwd();
    $mcenv{mccfg}  = "$ENV{UEMS}/conf/uems_mission";
    
    $mcenv{mcruns} = (defined $ENV{EMS_RUN} and $ENV{EMS_RUN} and -d $ENV{EMS_RUN}) ? $ENV{EMS_RUN} : '';
    $mcenv{mclogs} = (defined $ENV{EMS_LOGS} and $ENV{EMS_LOGS} and -d $ENV{EMS_LOGS}) ? $ENV{EMS_LOGS} : '';
    $mcenv{mcubin} = dirname(__FILE__);
   

    #----------------------------------------------------------------------------------
    #  Greet the user like you mean business.
    #----------------------------------------------------------------------------------
    #
    &MissionGreeting($mcenv{mc_server} ? $mcenv{mc_server} : $mcenv{mc_client} , &Elove::GetUEMSrelease($ENV{UEMS})) unless $mcenv{mc_monitor};


return %mcenv;
} 



sub MissionControl_Client {
#==================================================================================
#  This routine manages the preparation of the simulation for submission to
#  the remote system.
#==================================================================================
#
    my $mesg   = '';
    my %client = ();

    my $href = shift; my %Ucntrl = %{$href};


    #------------------------------------------------------------------------------
    #  Step 1.  Set the configuration for use on the client side. The %Ucntrl
    #           hash is passed through but a hash containing only those variables
    #           necessary are returned. 
    #------------------------------------------------------------------------------
    #
    return 1 unless %client = &SetClientEnvironment(\%Ucntrl);



    #------------------------------------------------------------------------------
    #  Step 2.  Read the contents of the static/namelist.wps file into a hash 
    #           that will be used to do a simple pre-check of the ems_autorun
    #           and ems_run configuration files.
    #------------------------------------------------------------------------------
    #
    %{$client{wpsnlh}} = &Others::Namelist2Hash($client{wpsnl});


    #------------------------------------------------------------------------------
    #  Step 3.  Assign domain values that will be used throughout the configuration
    #           steps. 
    #------------------------------------------------------------------------------
    #
    $client{dominfo}{mproj}  = ($client{wpsnlh}{GEOGRID}{map_proj}[0] =~ /lambert/i)  ? 1 :
                               ($client{wpsnlh}{GEOGRID}{map_proj}[0] =~ /polar/i)    ? 2 :
                               ($client{wpsnlh}{GEOGRID}{map_proj}[0] =~ /mercator/i) ? 3 :
                               ($client{wpsnlh}{GEOGRID}{map_proj}[0] =~ /lat-lon/i)  ? 6 : 6;

    $client{dominfo}{global} = ($client{wpsnlh}{GEOGRID}{map_proj}[0]  =~ /lat-lon/i and ! defined $client{wpsnlh}{GEOGRID}{dx}) ? 1 : 0;

    $client{dominfo}{bench}  = 0;


    #------------------------------------------------------------------------------
    #  Step 4.  The &PrepareAutoConfiguration determines the parameter values
    #           to be written to the ems_autorun.conf file passed to the server.
    #------------------------------------------------------------------------------
    #
    return 1 unless %client = &PrepareAutoConfiguration(\%client);
    #&Ecomm::PrintHash(\%client);


    #------------------------------------------------------------------------------
    #  Step 5.  The &PreparePrepConfiguration uses the UEMS Uprep modules to
    #           ensure the viability of the configuration when running ems_prep.
    #------------------------------------------------------------------------------
    #
    return 1 unless %client = &PreparePrepConfiguration(\%client);
    #&Ecomm::PrintHash(\%client);
     

    #------------------------------------------------------------------------------
    #  Step 6.  The &PrepareRunConfiguration determines the parameter values
    #           to be written to the ems_run.conf file passed to the server.
    #------------------------------------------------------------------------------
    #
    return 1 unless %client = &PrepareRunConfiguration(\%client);
    #&Ecomm::PrintHash(\%client);


    #------------------------------------------------------------------------------
    #  Step 7.  The &PreparePostConfiguration determines the parameter values
    #           to be written to the ems_post.conf file passed to the server.
    #------------------------------------------------------------------------------
    #
    return 1  unless %client = &PreparePostConfiguration(\%client);
    #&Ecomm::PrintHash(\%client);


    #------------------------------------------------------------------------------
    #  Step 8.  Prepare the directory with the configuration files and create
    #           a tarfile to be passed to the server for execution.
    #------------------------------------------------------------------------------
    #
    return 1 unless %client = &PrepareServerUpload(\%client);
    #&Ecomm::PrintHash(\%client);


    #------------------------------------------------------------------------------
    #  Step 9. Finally - Upload the tar file to the remote server
    #------------------------------------------------------------------------------
    #
    return 1 unless %client = &Upload2Server(\%client);
    

return 0;
}



sub SetClientEnvironment {
#==================================================================================
#  This subroutine manages the preliminary details of running UEMS Mission
#  Control from a client. It checks the validity of the flags passed while
#  ignoring server side flags, sets the UEMS environment and a few other
#  requires variable values.
#==================================================================================
#   
    my $mesg;

    my $href  = shift; my %Ucntrl = %{$href};
    my %mcenv = %{$Ucntrl{mcenv}};
    my %flags = %{$Ucntrl{flags}};


    #------------------------------------------------------------------------------
    #  Read the local configuration file, making sure that the values are correct
    #------------------------------------------------------------------------------
    #
    my %conf = ();
    my $mccfg = "$mcenv{mccfg}/$mcenv{mc_client}.conf";

    unless (%conf = &ReadMissionConfiguration($mccfg)) {
        $mesg = "It appears that there was a problem reading the UEMS Mission Control Client\n".
                "configuration file:\n\n".
                "X03X$mccfg\n\n";
        $ENV{MCMESG} = &Ecomm::TextFormat(0,0,144,0,2,"Failed $mcenv{mc_client} Ignition:",$mesg);
        return ();
    }


    my @nds = ();
    foreach ('client_id', 'server_username', 'server_hostname', 'u_incoming') {
        my $up = uc $_;
        push @nds, "Not Defined - $up\n" unless defined $conf{$_} and $conf{$_};
        $mcenv{$_} = $conf{$_};
    }


    if (@nds) {
        $ENV{MCMESG} = &Ecomm::TextFormat(0,0,144,0,2,"You have a problem in $mcenv{mc_client}.conf:",@nds);
        return ();
    }


    #------------------------------------------------------------------------------
    #  The $emscwd variable will be non-zero if Mission Control is being run
    #  from a current viable run-time directory, in which case it is assumed
    #  to be the directory to use.
    #------------------------------------------------------------------------------
    #
    my $rundir = (defined $flags{rundir} and $flags{rundir}) ? "$ENV{EMS_RUN}/$flags{rundir}" : '';

       $rundir = $mcenv{mccwd} if -e "$mcenv{mccwd}/conf"   and
                                  -d "$mcenv{mccwd}/conf"   and
                                  -e "$mcenv{mccwd}/static" and
                                  -d "$mcenv{mccwd}/static" and
                                  -e "$mcenv{mccwd}/static/namelist.wps";

       $rundir = ''        unless -e "$rundir/conf"   and
                                  -d "$rundir/conf"   and
                                  -e "$rundir/static" and
                                  -d "$rundir/static" and
                                  -e "$rundir/static/namelist.wps";

    
    #------------------------------------------------------------------------------
    #  Since this is running on the client the --run
    #------------------------------------------------------------------------------
    #
    unless ($rundir or -e $rundir) {
       $mesg = "When running $mcenv{mcexe} from a client system, you must either run the routine from a ".
               "valid run-time domain directory, or include the \"--rundir\" flag along with the path to ".
               "a run-time directory as an argument:\n\n".
               "X03X%  $mcenv{mcexe} --rundir  <directory>\n\n".
               "See \"$mcenv{mcexe} --help rundir\" for more details.";
       $ENV{MCMESG} = &Ecomm::TextFormat(0,0,86,0,2,'Missing something?',$mesg);
       return ();
    }

    
    #------------------------------------------------------------------------------
    #  Assign the variables that will be used in processing
    #------------------------------------------------------------------------------
    #
    $mcenv{rundir} =  $rundir;
    $mcenv{static} = "$rundir/static";
    $mcenv{wpsprd} = "$rundir/wpsprd";
    $mcenv{confd}  = "$rundir/conf";
    $mcenv{wpsnl}  = "$mcenv{static}/namelist.wps";


    #------------------------------------------------------------------------------
    #  Define the directories where the configuration files will be placed before
    #  the tarfile is created.  These are the "MC" variables.
    #------------------------------------------------------------------------------
    #
    $mcenv{mcdir}  = "$rundir/mcfiles";  #  A McDonald's product placement
    $mcenv{mcdirc} = "$mcenv{mcdir}/conf";
    $mcenv{mcdirs} = "$mcenv{mcdir}/static";


    #------------------------------------------------------------------------------
    #  Define the configuration filenames for each run-rime routine
    #------------------------------------------------------------------------------
    #
    $mcenv{mcconf}{ems_auto}{cfile} = 'ems_autorun.conf';
    $mcenv{mcconf}{ems_run}{cfile}  = 'ems_run.conf';
    $mcenv{mcconf}{ems_post}{cfile} = 'ems_post.conf';


    #------------------------------------------------------------------------------
    #  We'll need the current date information
    #------------------------------------------------------------------------------
    #
    $mcenv{yyyymmdd}   = `date -u +%Y%m%d`;   chomp $mcenv{yyyymmdd};
    $mcenv{yyyymmddhh} = `date -u +%Y%m%d%H`; chomp $mcenv{yyyymmddhh};


    #------------------------------------------------------------------------------
    #  Some of the flags passed to Mission Control are intended for use by
    #  ems_autorun so collect then in the %{$mcenv{aflags}} hash.
    #------------------------------------------------------------------------------
    #
    $mcenv{aflags}{rdset}   = $flags{rdset};
    $mcenv{aflags}{rdate}   = $flags{rdate};
    $mcenv{aflags}{rcycle}  = $flags{rcycle};
    $mcenv{aflags}{length}  = $flags{length};
    $mcenv{aflags}{domains} = $flags{domains};


    $mcenv{autorun}         = 0;  #  Used by UEMS run-time routines


    #------------------------------------------------------------------------------
    #  Create the name of the if the server side run-time directory, which is a
    #  string created from the station ID, the local run-time directory name, and
    #  the local process ID.  The combination of these values should be enough to
    #  avoid a duplication of requests on the server side.
    #------------------------------------------------------------------------------
    #
#   $mcenv{mcpid} = $$;

    my $clientid  = lc $mcenv{client_id};  #  must be lower case
    my $clientpid = $mcenv{mcpid};
    my $clientdir = lc &Others::popit($rundir);

       
    $mcenv{mctarfl} = "${clientid}_${clientpid}_${clientdir}.tgz";

 
return %mcenv;
}  



sub PrepareAutoConfiguration  {
#==================================================================================
#  Process the configuration provided by the user in the ems_autorun.conf file
#  This step requires use of the modules under uems/strc/Uauto to check the 
#  validity of the values. These parameters are then merged with the flag values
#  passed to Mission control and then returned in the %{$client{autorun}} hash.
#==================================================================================
#
use lib (abs_path("$RealBin/../Uauto"),abs_path("$RealBin/../Upost"));

use Aflags;
use Aconf;
use Afinal;

use Enet;


    my %Uauto = ();
    my %Aconf = ();

    $ENV{AMESG}  = '';

    my $href = shift; my %client = %{$href}; 

   
    #-------------------------------------------------------------------------------
    #  Process the flags passed to Mission Control, which are similar to those
    #  passed to uems_autorun.pl. The hash passed to the autorun routines must
    #  be properly organized so that it does not create problems, which is the 
    #  reason for the odd-looking assignment of the keys & values. 
    # 
    #  Flags must be in UPPER CASE going into &AutoFlagConfiguration
    #-------------------------------------------------------------------------------
    #
    foreach (keys %{$client{aflags}}) {$Uauto{aflags}{uc $_} = $client{aflags}{$_};}

    $Uauto{aflags}{LSM}     = '';
    $Uauto{aflags}{SFC}     = '';
    $Uauto{aflags}{NOLOCK}  = '';
    $Uauto{aflags}{SCOUR}   = 4;
    $Uauto{aflags}{NUDGING} = 0;


    #-------------------------------------------------------------------------------
    #  Collect a list of the supported grib information files.
    #-------------------------------------------------------------------------------
    #
    unless (@{$Uauto{rtenv}{ginfos}} = &Others::FileMatch("$ENV{EMS_CONF}/gribinfo",'_gribinfo.conf',1,0)) {
        my $mesg = "Something is not quite correct as the $ENV{EMS_CONF}/gribinfo directory or the grib information ".
                   "files contained within has gone missing.";
        $ENV{MCMESG} = &Ecomm::TextFormat(0,0,86,0,2,'Missing GRIB information',$mesg);
        return ();
    } @{$client{ginfos}} = @{$Uauto{rtenv}{ginfos}};


    #-------------------------------------------------------------------------------
    #  Now call the ems_autorun flag handling routine. Some environment variables
    #  needed for the configuration.
    #-------------------------------------------------------------------------------
    #
    $Uauto{emsenv}{mc}      = 1;
    $Uauto{emsenv}{cwd}     = $client{rundir};
    $Uauto{emsenv}{autorun} = $client{autorun};
    $Uauto{emsenv}{yyyymmdd}= $client{yyyymmdd};

    $Uauto{rtenv}{autoconf} = "$client{confd}/ems_auto";
    $Uauto{rtenv}{bench}    = $client{dominfo}{bench};
    $Uauto{rtenv}{global}   = $client{dominfo}{global};


    unless (%{$Aconf{flags}} = &Aflags::AutoFlagConfiguration(\%Uauto)) {
        $ENV{MCMESG} = &Ecomm::TextFormat(0,2,144,0,2,'An error occurred during UEMS autorun configuration (1):',$ENV{AMESG});
        return ();
    }


    #-------------------------------------------------------------------------------
    #  Call the UEMS autorun routine that reads the contents of ems_autorun.conf
    #-------------------------------------------------------------------------------
    #
    unless (%{$Aconf{files}} = &Afiles::AutoFileConfiguration(\%Uauto)) {
        $ENV{MCMESG} = &Ecomm::TextFormat(0,2,144,0,2,'An error occurred during UEMS autorun configuration (2):',$ENV{AMESG});
        return ();
    }


    #-------------------------------------------------------------------------------
    #  the @{$Uauto{geodoms}} array holds the list of localized domains for which 
    #  geog_* files reside under the static/ directory. Because the domain is not
    #  localized on the client, the geog_ files don't exist so use namelist.wps
    #-------------------------------------------------------------------------------
    #
    @{$Uauto{geodoms}}   = (1 .. @{$client{wpsnlh}{GEOGRID}{parent_id}});


    #-------------------------------------------------------------------------------
    #  Both the user flags and configuration files have been collected and massaged,
    #  so it's time to create the master hash for use by ems_autorun.
    #-------------------------------------------------------------------------------
    #
    unless (%{$Aconf{parms}} = &Afinal::AutoFinalConfiguration(\%Uauto,\%Aconf)) {
        $ENV{MCMESG} = &Ecomm::TextFormat(0,2,144,0,2,'An error occurred during UEMS autorun configuration (3):',$ENV{AMESG});
        return ();
    }


    #-------------------------------------------------------------------------------
    #  Create an hash containing the domains included in the simulation along with
    #  the start and stop times. This information is for the user and not directly
    #  part of 
    #-------------------------------------------------------------------------------
    #
    $client{rundoms}{1}{start} = 0;
    $client{rundoms}{1}{stop}  = $Aconf{parms}{length};
    foreach (split ',', $Aconf{parms}{domains}) {
       my ($dm,$sh,$eh) = split ':', $_;
       $client{rundoms}{$dm}{start}  = defined $sh ? $sh : 0;
       $client{rundoms}{$dm}{stop}   = defined $eh ? $eh : $Aconf{parms}{length};
    } 
    @{$client{rdoms}} = sort {$a <=> $b} keys %{$client{rundoms}}; 


    #-------------------------------------------------------------------------------
    #  Create an array containing the domains assigned for post processing.
    #-------------------------------------------------------------------------------
    #
    @{$client{postdoms}} = ();
    foreach (split ',', $Aconf{parms}{mergpost}) {
       my @dom = split ':', $_;
       push @{$client{postdoms}}, $dom[0] if $dom[0];
    }
    @{$client{postdoms}} = sort {$a <=> $b} &Others::rmdups(@{$client{postdoms}});

 
    #-------------------------------------------------------------------------------
    #  Final step is to write all the parameters to the "autorun" hash. This hash
    #  will later be included in a tarball that will be sent to the server.
    #-------------------------------------------------------------------------------
    #
    my @params = qw(domains dsets emspost length lsm nudging rcycle rdate scour sfc sleep syncsfc);

    foreach (@params) {$client{mcconf}{ems_auto}{parms}{uc $_} = $Aconf{parms}{$_}};

    %{$client{aparms}} = %{$Aconf{parms}};  #  Because it may be needed later
 
    
return %client;
}



sub PreparePrepConfiguration  {
#==================================================================================
#  Process the configuration provided by the ems_prep routine. This step requires
#  use of the modules under uems/strc/Uprep to check the validity of the values.
#  These parameters are then merged with the flag values passed to Mission control
#  and then returned in the %{$client{emsprep}} hash.
#==================================================================================
#
use lib (abs_path("$RealBin/../Uprep"));

use Poptions;
use Pconf;

    my %Pconf = ();

    $ENV{PMESG}  = '';

    my $href = shift; my %client = %{$href}; %{$client{emsprep}} = ();
  
 
    #-------------------------------------------------------------------------------
    #  Set up the environment similar to that expected by ems_prep - %Pconf
    #-------------------------------------------------------------------------------
    #
    $Pconf{emsenv}{mc}        = 1;
    $Pconf{emsenv}{cwd}       = $client{rundir};
    $Pconf{emsenv}{autorun}   = $client{autorun};
    $Pconf{emsenv}{yyyymmdd}  = $client{yyyymmdd};
    $Pconf{emsenv}{yyyymmddhh}= $client{yyyymmddhh};

    $Pconf{rtenv}{islake}     = 0;
    $Pconf{rtenv}{core}       = $client{core};
    $Pconf{rtenv}{modis}      = 1;
    $Pconf{rtenv}{grbdir}     = "$client{rundir}/grib";
    $Pconf{rtenv}{wpsprd}     = $client{wpsprd};
    $Pconf{rtenv}{static}     = $client{static};
    $Pconf{rtenv}{dompath}    = $client{rundir};

    $Pconf{rtenv}{bench}      = $client{dominfo}{bench};
    $Pconf{rtenv}{global}     = $client{dominfo}{global};

    @{$Pconf{rtenv}{ginfos}}  = @{$client{ginfos}};

    %{$Pconf{masternl}}       = %{$client{wpsnlh}};
    $Pconf{masternl}{global}  = 0;
    $Pconf{masternl}{maxdoms} = @{$client{wpsnlh}{GEOGRID}{parent_id}};



    #-------------------------------------------------------------------------------
    #  Now call the ems_prep flag configuration routine. Populate he @ARGV array
    #  with flags and values that would be passed from the command line.
    #-------------------------------------------------------------------------------
    #
    my @dsets = split ',', $client{aparms}{dsets};
    my $dset  = $dsets[0];
    
    @ARGV = ('--dset', $dset);

    @ARGV = (@ARGV,('--length', $client{aparms}{length}))    if $client{aparms}{length};
    @ARGV = (@ARGV,('--domains', $client{aparms}{pdomains})) if $client{aparms}{pdomains};
    @ARGV = (@ARGV,('--date', $client{aparms}{rdate}))       if $client{aparms}{rdate};
    @ARGV = (@ARGV,('--cycle', $client{aparms}{rcycle}))     if $client{aparms}{rcycle};

    unless (%Pconf = &Poptions::PrepOptions(\%Pconf)) {
        $ENV{MCMESG} = &Ecomm::TextFormat(0,0,86,0,2,'An error occurred during ems_prep (1):',$ENV{PMESG});
        return ();
    }


    #-------------------------------------------------------------------------------
    #  Call &PrepConfiguration, the primary purpose of which is to get the final
    #  namelist.wps information that will be needed in the ems_run checks.
    #-------------------------------------------------------------------------------
    #
    unless (%Pconf = &Pconf::PrepConfiguration(\%Pconf)) {
        $ENV{MCMESG} = &Ecomm::TextFormat(0,0,86,0,2,'An error occurred during ems_prep (2):',$ENV{PMESG});
        return ();
    }


    #-------------------------------------------------------------------------------
    #  What we really need is an updated namelist.wps file to provide the 
    #  information to pass to ems_run.
    #-------------------------------------------------------------------------------
    #
    %{$client{wpsnlh}} = %{$Pconf{masternl}};


    
return %client;
}



sub PrepareRunConfiguration  {
#==================================================================================
#  Process the configuration provided by the user in the ems_run.conf file
#  This step requires use of the modules under uems/strc/Urun to check the 
#  validity of the values. These parameters are then merged with the flag values
#  passed to Mission control and then returned in the %{$client{emsrun}} hash.
#==================================================================================
#
use lib (abs_path("$RealBin/../Urun"));
use ARW::ARWconfig;
use Roptions;
use Rflags;
use Rconf;


    $ENV{RMESG}   = '';
    $ENV{RUN_DBG} = 0;   #  In case of an emergency

    my %Rconf   = ();
    my $href    = shift; my %client = %{$href};


    #-------------------------------------------------------------------------------
    #  Step 1.  Initialize the options & flags that are used by ems_run, which all 
    #           should have a value corresponding to "not passed". These flags are 
    #           used in the namelist Q&A checks and we don't want any errors for 
    #           uninitialized variables.
    #-------------------------------------------------------------------------------
    #
    $Rconf{arf}            = 0;

    $Rconf{emsenv}{mc}     = 1;
    $Rconf{emsenv}{cwd}    = $client{rundir};
    $Rconf{emsenv}{wpsprd} = $client{wpsprd};
    $Rconf{emsenv}{autorun}= $client{autorun};

    $Rconf{rtenv}{runconf} = "$client{confd}/ems_run";
    $Rconf{rtenv}{nilevs}  = 31;  # Arbitrary for this purpose
    $Rconf{rtenv}{nslevs}  = 4;
    $Rconf{rtenv}{maxmsf}  = 1.;
    $Rconf{rtenv}{mproj}   = $client{dominfo}{mproj};
    $Rconf{rtenv}{global}  = $client{dominfo}{global};
    $Rconf{rtenv}{bench}   = $client{dominfo}{bench};


    unless (%Rconf = &Roptions::RunOptions(\%Rconf)) {
        $ENV{MCMESG} = &Ecomm::TextFormat(0,0,86,0,2,'An error occurred during ems_run (1):',$ENV{RMESG});
        return ();
    }



    #-------------------------------------------------------------------------------
    #  Step 1a. Modify the output options based on the information returned from
    #           &PrepareAutoConfiguration. The options must be formatted the same 
    #           as if ems_run was being called from the command line.
    #-------------------------------------------------------------------------------
    #
    $Rconf{options}{DOMAINS} = "$client{aparms}{domains}h";
    $Rconf{options}{DOMAINS} =~s/:\d+:/:/g;
    $Rconf{options}{DOMAINS} =~s/,/h,/g;
    $Rconf{options}{LENGTH}  = "$client{aparms}{length}h";
    $Rconf{options}{NUDGE}   = -1 * $client{aparms}{nudging};

    unless (%{$Rconf{flags}} = &Rflags::RunFlagConfiguration(\%Rconf)) {
        $ENV{MCMESG} = &Ecomm::TextFormat(0,0,86,0,2,'An error occurred during ems_run (2):',$ENV{RMESG});
        return ();
    }

    #------------------------------------------------------------------------------
    #  Step 2.  We need to replicate the %domains and %geodoms hashes used in 
    #           ems_run from the contents of the namelist.wps file, because that's
    #           all we have. In ems_run, the information is obtained by reading the
    #           static/geog files but they are not available for this application.
    #------------------------------------------------------------------------------
    #
    my %domains = ();
    my %geodoms = ();

    my $start_secs = &Others::CalculateEpochSeconds(&Others::DateStringWRF2DateString($client{wpsnlh}{SHARE}{start_date}[0]));
    my $start_date = &Others::DateStringWRF2DateString($client{wpsnlh}{SHARE}{start_date}[0]);
    my $stops_secs = &Others::CalculateEpochSeconds(&Others::DateStringWRF2DateString($client{wpsnlh}{SHARE}{end_date}[0]));


    #------------------------------------------------------------------------------
    #  Need to populate the values for DX & DY for lat-lon domains (inc global)
    #------------------------------------------------------------------------------
    #
    my $dx0        = $Rconf{rtenv}{global} ? (360.0/($client{wpsnlh}{GEOGRID}{e_we}[0]-1)) : $client{wpsnlh}{GEOGRID}{dx}[0]; 
       $dx0        = 1000.0*111.0*$dx0 if $Rconf{rtenv}{mproj} == 6;

    my $dy0        = $Rconf{rtenv}{global} ? (360.0/($client{wpsnlh}{GEOGRID}{e_we}[0]-1)) : $client{wpsnlh}{GEOGRID}{dy}[0];
       $dy0        = 1000.0*111.0*$dy0 if $Rconf{rtenv}{mproj} == 6;
    

    foreach my $d (1 .. $client{rdoms}[-1]) {

        my $p     = $client{wpsnlh}{GEOGRID}{parent_id}[$d-1];

        unless (defined $client{rundoms}{$d}) {
            $client{rundoms}{$d}{start} = $client{rundoms}{$p}{start};
            $client{rundoms}{$d}{stop}  = $client{rundoms}{$p}{stop};
        }
        my $start = ($client{rundoms}{$d}{start} < $client{rundoms}{$p}{start}) ? $client{rundoms}{$p}{start} : $client{rundoms}{$d}{start};
        my $stop  = ($start+$client{rundoms}{$d}{stop} > $client{rundoms}{$p}{stop}) ? $client{rundoms}{$p}{stop} : $start+$client{rundoms}{$d}{stop};
        my $len   = $stop - $start;

        $domains{$d}{parent}   = $client{wpsnlh}{GEOGRID}{parent_id}[$d-1];
        $domains{$d}{pratio}   = $client{wpsnlh}{GEOGRID}{parent_grid_ratio}[$d-1];
        $domains{$d}{fratio}   = ($d == 1) ? 1 : $domains{$domains{$d}{parent}}{fratio}*$domains{$d}{pratio};
        $domains{$d}{dx}       = $dx0/$domains{$d}{fratio};
        $domains{$d}{dy}       = $dy0/$domains{$d}{fratio};
        $domains{$d}{length}   = $client{aparms}{length} * 3600;
        $domains{$d}{interval} = $client{wpsnlh}{SHARE}{interval_seconds}[0];

        $domains{$d}{sdate}    = &Others::DateString2DateStringWRF(&Others::CalculateNewDate($start_date,$start*3600));
        $domains{$d}{edate}    = &Others::DateString2DateStringWRF(&Others::CalculateNewDate($start_date,$stop*3600));

        $geodoms{$d}{parent} = $domains{$d}{parent};
        $geodoms{$d}{fratio} = $domains{$d}{fratio};
        $geodoms{$d}{dx}     = $domains{$d}{dx}; 
        $geodoms{$d}{dy}     = $domains{$d}{dy};

    }
    %{$client{domains}} = %domains;
    %{$client{geodoms}} = %geodoms;

    #-------------------------------------------------------------------------------
    #  Step 3.  The ems_run configuration files must be checked for viability to 
    #           reduce the chance of failure on the remote system. This step 
    #           requires the use of the Urun modules because it would be too 
    #           messy to duplicate the subroutines here. The ARWconfig module 
    #           is where all the ARW configuration routines are located.
    #-------------------------------------------------------------------------------
    #
    %{$Rconf{dinfo}{domains}} = %{$client{domains}};
    %{$Rconf{rtenv}{geodoms}} = %{$client{geodoms}};
    %{$Rconf{rtenv}{wpsfls}}  = ();
    %{$Rconf{rtenv}{geofls}}  = ();
    %{$Rconf{rtenv}{inifls}}  = ();


    #-------------------------------------------------------------------------------
    #  Need a value for the number of land use categories 20,21,24,28,40,50
    #-------------------------------------------------------------------------------
    #
    $Rconf{rtenv}{nlcats} = (grep {/nlcd2006_/} @{$client{wpsnlh}{SHARE}{geog_data_res}}) ? 40 :
                            (grep {/usgs_/}     @{$client{wpsnlh}{SHARE}{geog_data_res}}) ? 24 : 20;
          
    unless (%Rconf = &ARWconfig::NamelistControlARW(\%Rconf)) {
        $ENV{MCMESG} = &Ecomm::TextFormat(0,0,86,0,2,'An error occurred during ems_run (4):',$ENV{RMESG});
        return ();
    }


    #----------------------------------------------------------------------------------
    #  Step 4.  Before leaving provide some information to the user
    #----------------------------------------------------------------------------------
    #
    my @rundoms = @{$client{rdoms}};
    &Ecomm::PrintMessage(0,4,144,2,1,sprintf("%-4s Simulation Run Summary",&Ecomm::GetRN($ENV{PRN}++)));
    &Ecomm::PrintMessage(0,11,94,1,0,'Simulation start and end times:');
    &Ecomm::PrintMessage(0,11,94,2,1, (@rundoms > 1) ? 'Domain         Start                   End              Parent'
                                                     : 'Domain         Start                   End');

    &Ecomm::PrintMessage(0,11,94,0,0, (@rundoms > 1) ? '-' x 64 : '-' x 54);

    foreach my $dom (@rundoms) {
        my $parent = $dom == 1 ? ' ' : $domains{$dom}{parent} ;
        my $sdate  = $domains{$dom}{sdate};
        my $edate  = $domains{$dom}{edate};
        my $length = &Ecomm::FormatTimingString($domains{$dom}{length});
        &Ecomm::PrintMessage(0,14,94,1,0,"$dom     $sdate     $edate      $parent");
    }
    my $lstr = &Ecomm::FormatTimingString($domains{1}{length});
    &Ecomm::PrintMessage(0,11,94,2,2,"Primary domain simulation length will be $lstr.");




    #-------------------------------------------------------------------------------
    #  Everything appears to be OK but we need to read the ems_run/ configuration 
    #  for the regurgitation into the ems_run.conf file sent to the server. Some 
    #  files & parameters will be skipped since they are no longer necessary.
    #-------------------------------------------------------------------------------
    #
    %Rconf = &ReadRunConfiguration("$client{confd}/ems_run");

    foreach my $parm (keys %Rconf) {$client{mcconf}{ems_run}{parms}{$parm} = join ',', @{$Rconf{$parm}};}



return %client;
}



sub PreparePostConfiguration  {
#==================================================================================
#  Process the configuration provided by the user in the ems_post.conf file
#  This step requires use of the modules under uems/strc/Upost to check the 
#  validity of the values. These parameters are then merged with the flag values
#  passed to Mission control and then returned in the %{$client{emspost}} hash.
#==================================================================================
#
use lib (abs_path("$RealBin/../Upost"));
use Ooptions;
use Ofiles;
use Oflags;
use Ofinal;


    my %Oconf = ();
    my %Upost = ();

    $ENV{OMESG}  = '';

    my $href = shift; my %client = %{$href}; 

    #-------------------------------------------------------------------------------
    #  This step is the simplest in the succession of the run-time routines 
    #  because there really isn't anything to check.
    #  Process the flags passed to mission control, which are similar to those
    #  passed to ems_post.pl. The hash passed to the ems_post routines must
    #  be organized so that it does not create problems, which is the reason
    #  for the assignment of the keys & values.
    #-------------------------------------------------------------------------------
    #
    $Upost{emsenv}{mc}          = 1;
    $Upost{emsenv}{cwd}         = $client{rundir};
    $Upost{emsenv}{autorun}     = $client{autorun};

    $Upost{rtenv}{core}         = $client{core};
    $Upost{rtenv}{static}       = $client{static};
    $Upost{rtenv}{tables}{grib} = "$ENV{DATA_TBLS}/post/grib2";
    $Upost{rtenv}{tables}{bufr} = "$ENV{DATA_TBLS}/post/bufr";
    $Upost{rtenv}{dompath}      = $client{rundir};
    $Upost{rtenv}{postconf}     = "$client{confd}/ems_post";
    $Upost{rtenv}{length}       = $client{mcconf}{ems_auto}{parms}{LENGTH} * 3600;

    foreach (@{$client{postdoms}}) { %{$Upost{rtenv}{postdoms}{$_}} = %{$client{domains}{$_}};}
        

    $Upost{maxdoms}   = $client{rdoms}[-1];
    $Upost{maxindex}  = $Upost{maxdoms}-1; #  Index of final domain information.

    my @wrfint = split ',' => $client{mcconf}{ems_run}{parms}{HISTORY_INTERVAL};
    my @auxint = split ',' => $client{mcconf}{ems_run}{parms}{AUXHIST1_INTERVAL};

    foreach (0 .. $Upost{maxindex}) {
        $Upost{rtenv}{hist}{wrf}[$_] = $wrfint[$_] ? $wrfint[$_] : $wrfint[-1];
        $Upost{rtenv}{hist}{aux}[$_] = $auxint[$_] ? $auxint[$_] : $auxint[-1];
    }


    @ARGV = ();
    unless (%Upost = &Ooptions::PostOptions(\%Upost)) {
        $ENV{MCMESG} = &Ecomm::TextFormat(0,2,144,0,2,'An error occurred during UEMS post configuration (1):',$ENV{OMESG});
        return ();
    }


    unless (%{$Oconf{flags}} = &Oflags::PostFlagConfiguration(\%Upost)) {
        $ENV{MCMESG} = &Ecomm::TextFormat(0,2,144,0,2,'An error occurred during UEMS post configuration (2):',$ENV{OMESG});
        return ();
    }

    $Oconf{flags}{info} = 1;  #  Provide information to the user

    unless (%{$Oconf{files}} = &Ofiles::PostFileConfiguration(\%Upost)) {
        $ENV{MCMESG} = &Ecomm::TextFormat(0,2,144,0,2,'An error occurred during UEMS post configuration (3):',$ENV{OMESG});
        return ();
    }


    unless (%{$Upost{parms}} = &Ofinal::PostFinalConfiguration(\%Upost,\%Oconf)) {
        $ENV{MCMESG} = &Ecomm::TextFormat(0,2,144,0,2,'An error occurred during UEMS post configuration (4):',$ENV{OMESG});
        return ();
    }


    #-------------------------------------------------------------------------------
    #  Final step is to write all the parameters to the "emspost" hash. The emspost
    #  hash contains the parameter names that will be written to the ems_post
    #  configuration file included for export to the server.
    #-------------------------------------------------------------------------------
    #
    $client{mcconf}{ems_post}{cfilename} = 'ems_post.conf';

    $client{mcconf}{ems_post}{parms}{GRIB}           = $Upost{parms}{grib};
    $client{mcconf}{ems_post}{parms}{FILENAME_GRIB}  = $Upost{parms}{filename_grib};
    $client{mcconf}{ems_post}{parms}{FREQ_WRF_GRIB}  = $Upost{parms}{frqwrf_grib};
    $client{mcconf}{ems_post}{parms}{FREQ_AUX_GRIB}  = $Upost{parms}{frqaux_grib};
    $client{mcconf}{ems_post}{parms}{GRIB_CNTRL_WRF} = join ',', map {&Others::popit($_)} split ',',$Upost{parms}{grbcntrl_wrf};
    $client{mcconf}{ems_post}{parms}{GRIB_CNTRL_AUX} = join ',', map {&Others::popit($_)} split ',',$Upost{parms}{grbcntrl_aux};
 
    $client{mcconf}{ems_post}{parms}{BUFR}           = $Upost{parms}{bufr};
    $client{mcconf}{ems_post}{parms}{FILENAME_BUFR}  = $Upost{parms}{filename_bufr};
    $client{mcconf}{ems_post}{parms}{STATION_LIST}   = join ',', map {&Others::popit($_)} split ',',$Upost{parms}{station_list};
    $client{mcconf}{ems_post}{parms}{FREQ_WRF_BUFR}  = $Upost{parms}{frqwrf_bufr};
  
    $client{mcconf}{ems_post}{parms}{GRADS}          = 0;
    $client{mcconf}{ems_post}{parms}{GEMPAK}         = 0;
    $client{mcconf}{ems_post}{parms}{BUFKIT}         = 0;
    $client{mcconf}{ems_post}{parms}{GEMSND}         = 0;

    @{$client{mcstat}{conffiles}{wrf_cntrl}} = grep {-e $_ } &Others::rmdups(split ',',$Upost{parms}{grbcntrl_wrf});
    @{$client{mcstat}{conffiles}{aux_cntrl}} = grep {-e $_ } &Others::rmdups(split ',',$Upost{parms}{grbcntrl_aux});
    @{$client{mcstat}{conffiles}{stn_list}}  = grep {-e $_ } &Others::rmdups(split ',',$Upost{parms}{station_list});

    
return %client;
}



sub PrepareServerUpload  {
#==================================================================================
#  Process the configuration provided by the user in the ems_post.conf file
#  This step requires use of the modules under uems/strc/Upost to check the 
#  validity of the values. These parameters are then merged with the flag values
#  passed to Mission control and then returned in the %{$client{emspost}} hash.
#==================================================================================
#
use Ecore;

    my $href = shift; my %client = %{$href}; 



    #-------------------------------------------------------------------------------
    #  Create the directory under which the various configuration files will 
    #  reside.
    #-------------------------------------------------------------------------------
    #
    &Others::rm($client{mcdir}); &Others::mkdir($client{mcdir});


    #-------------------------------------------------------------------------------
    #  Write the configuration files for ems_autorun, ems_run, and ems_post
    #-------------------------------------------------------------------------------
    #
    foreach my $cdir (keys %{$client{mcconf}}) {

        &Others::mkdir("$client{mcdirc}/$cdir");

        open my $fh, '>', "$client{mcdirc}/$cdir/$client{mcconf}{$cdir}{cfile}" or die "no open $client{mcconf}{$cdir}{cfile}\n";

        my @lens = sort { length $b <=> length $a } keys %{$client{mcconf}{$cdir}{parms}};
        my $l = length $lens[0];

        foreach my $parm (sort keys %{$client{mcconf}{$cdir}{parms}}) {
            print $fh sprintf("%-${l}s = %s\n",$parm,$client{mcconf}{$cdir}{parms}{$parm});
        }
        close $fh;
    }


    #-------------------------------------------------------------------------------
    #  Copy over the configuration files under static/.  To ensure that just those
    #  file that are necessary, use the information from the ems_post.conf file.
    #-------------------------------------------------------------------------------
    #
    &Others::rm($client{mcdirs}); &Others::mkdir($client{mcdirs});

    foreach my $t ('wrf_cntrl', 'aux_cntrl', 'stn_list') {
        system "cp -f $_ $client{mcdirs}" foreach @{$client{mcstat}{conffiles}{$t}};
    }
    

    if (&Ecore::SysExecute("tar --ignore-failed-read -C $client{mcdir} -czf $client{mcdir}/$client{mctarfl}  conf static > /dev/null 2>&1")) {
        my $mesg = "The command that failed:\n\n".
                   "X02Xtar --ignore-failed-read -C $client{mcdir} -czf $client{mcdir}/$client{mctarfl}  conf static";
        $ENV{MCMESG} = &Ecomm::TextFormat(0,2,144,0,2,"An error occurred while creating the simulation tarfile ($?)",$mesg);
        return ();
    } 

    #-------------------------------------------------------------------------------
    #  The final step after leaving this subroutine is to upload the tarfile to
    #  the remote server.
    #-------------------------------------------------------------------------------
    #
    $client{mctarfl} = "$client{mcdir}/$client{mctarfl}";


return %client;
}



sub Upload2Server  {
#==================================================================================
#  Upload the tarfile to the remote server for processing. To accomplish this
#  task the &ExportFiles and &FileTransfer_Rsync routines were liberated from
#  the Outils module. A hash containing the information is passed to &ExportFiles
#  with the following infomation:
#  
#    $Export{host}  - Hostname of remote machine if any     - $client{server_username};
#    $Export{meth}  - Method to use for transfer (rsync)
#    $Export{rdir}  - Upload directory on the remote system - $client{server_hostname}
#    $Export{files} - The local tar file to upload          - $client{u_incoming};
#==================================================================================
#   
use Outils;

    #------------------------------------------------------------------------------
    #  Needed by &Outils::ExportFiles
    #------------------------------------------------------------------------------
    #
    $ENV{VERBOSE}  = 0;  # Default is verbose mode (1) but we don't want all the info
    $ENV{POST_DBG} = 0;
    $ENV{OMESG}     = '';

    my %Export = ();

    my $href = shift; my %client = %{$href}; 


    #------------------------------------------------------------------------------
    #  Set up the hash to be passed to the export routine
    #------------------------------------------------------------------------------
    #
    $Export{arf}      = 0;
    $Export{host}     = "$client{server_username}\@$client{server_hostname}";
    $Export{meth}     = 'rsync';
    $Export{rdir}     = $client{u_incoming};
    $Export{mkdir}    = 0;
    @{$Export{files}} = ($client{mctarfl});

    my ($user,$serv) = split '@', $Export{host};

    if (&Outils::ExportFiles(\%Export)) {
        $ENV{VERBOSE} = 1;
        my $mesg = "An error occurred while uploading the configuration file to $serv";
        $ENV{MCMESG} = &Ecomm::TextFormat(0,0,86,0,2,$mesg);
        return ();
    }
    $ENV{VERBOSE} = 1;

return %client;
}



sub ReadRunConfiguration {
#==================================================================================
#  Collect the configuration files (*.conf) under the specified directory
#  and then reads the individual files while writing the parameters & values
#  to the %parms hash. The parameter values are written to an array that is
#  return in the %parms hash.
#==================================================================================
#
    my %parms = ();
    my $cdir  = shift; return %parms unless -d $cdir;

    foreach my $conf (&Others::FileMatch($cdir,'\.conf$',0,1)) {
        next if $conf =~ /_afwaout|_namelist|_ncpus/;
        my %cparms = &Others::ReadConfigurationFile($conf);
        foreach my $key (keys %cparms) {@{$parms{$key}} = split /,/, $cparms{$key}; foreach (@{$parms{$key}}) {$_+=0 if /^\d+$/;} }
     }

return %parms;
}  #  ReadLocalConfiguration


sub MissionControl_Server {
#==================================================================================
#  This routines serves as the primary driver for running a UEMS simulation on 
#  a remote server.
#==================================================================================
#
    my $dsep = '-' x 92;
    my $mesg = '';
    my $date = gmtime;
    my %server = ();

    my $href = shift; my %Ucntrl = %{$href};


    #------------------------------------------------------------------------------
    #  Step 1.  Set the configuration for use on the server side. The %Ucntrl
    #           hash is passed through but a hash containing only those variables
    #           necessary are returned. 
    #------------------------------------------------------------------------------
    #
    return 1 unless %server = &SetServerEnvironment(\%Ucntrl);



    #------------------------------------------------------------------------------
    #  Step 2.  Create the designated run-time directory using the ems_domain.pl
    #           utility.  
    #------------------------------------------------------------------------------
    #
    &Ecomm::PrintTerminal(1,4,114,1,0,"UEMS Mission Control ($server{client_id}:$server{client_pid}): Creating $server{client_dir} run-time domain -");

    if (&Ecore::SysExecute("$server{mcubin}/ems_domain.pl --create $server{rundir} --force --mcserver", $server{runlog}) || ! -d "$server{mcruns}/$server{rundir}") {

        &Ecomm::PrintTerminal(0,0,12,0,1,' Failed');

        my $wfo = uc $server{client_id};
        $mesg = "The simulation for $wfo domain \"$server{client_dir}\" (PID: $server{client_pid}) ".
                "has met an untimely demise during the creation of the computational domain, which likely the ".
                "result of an internal error on the server. Check the log file for more information:\n\n".
                "    $server{runlog}";

        $ENV{MCMESG} = &Ecomm::TextFormat(0,2,144,0,2,'UEMS Mission Control - Server Error:',$mesg);
        return 1;
    }
    $date = gmtime;
    &Ecomm::PrintTerminal(0,0,12,0,1," Completed ($date UTC)"); &Others::rm($server{runlog});



    #------------------------------------------------------------------------------
    #  Step 3.  Unpack the incoming tarfile into the newly created run-time 
    #           directory.  The tarfile should contain the following:
    #
    #           a.  <rundir>/conf/ems_auto/ems_autorun.conf 
    #           b.  <rundir>/conf/ems_run/ems_run.conf
    #           c.  <rundir>/conf/ems_post/ems_post.conf
    #           d.  <rundir>/conf/static/namelist.wps
    #           e.  <rundir>/conf/static/emsupp_cntrl.parm
    #           f.  <rundir>/conf/static/emsupp_auxcntrl.parm
    #           g.  <rundir>/conf/static/emsbufr_stations_d##.txt
    #
    #           %  tar -C $ENV{EMS_RUN}/$server{rundir} -xzvf <path to tarball repository>/tarfile.tgz $ENV{EMS_RUN}/$server{rundir}
    #------------------------------------------------------------------------------
    #
    &Ecomm::PrintTerminal(1,4,114,1,0,"UEMS Mission Control ($server{client_id}:$server{client_pid}): Unpacking configuration -");

    my $flags = ($server{tarfile} =~ /\.tbz$/) ? '-xjvf' : 
                ($server{tarfile} =~ /\.tgz$/) ? '-xzvf' :
                ($server{tarfile} =~ /\.tar$/) ? '-xvf'  : '-xzvf';


    if (&Ecore::SysExecute("tar -C $server{mcruns}/$server{rundir} $flags $server{tarfile}", $server{runlog})) {

        &Ecomm::PrintTerminal(0,0,12,0,1,' Failed');

        my $tarfile = &Others::popit($server{tarfile});
        $mesg = "The simulation for $server{client_id} domain $server{client_dir} (PID: $server{client_pid}) has met an ".
                "untimely demise while unpacking the tarfile ($tarfile) containing the configuration.";

        $ENV{MCMESG} = &Ecomm::TextFormat(0,2,92,0,2,'UEMS Mission Control - Server Error:',$mesg);
 
        if (-s $server{runlog}) {
            open (my $fh, '<', $server{runlog}); my @lines = <$fh>; close $fh;  chomp $_ foreach @lines;
            unshift @lines, $dsep;
            unshift @lines, "   Here is some (hopefully) useful information mined from the log file:\n";
            my $info = join "\n   ", @lines;
            $ENV{MCMESG} = $ENV{MCMESG}.$info;
            &Others::rm($server{runlog});
        }
        return 1;
    }
    $date = gmtime;
    &Ecomm::PrintTerminal(0,0,12,0,1," Completed ($date UTC)"); &Others::rm($server{runlog});
    
    #------------------------------------------------------------------------------
    #  Move the tarfile into the logs directory
    #------------------------------------------------------------------------------
    #
    system "mv -f $server{tarfile} $server{logdir} > /dev/null 2>&1";

    system "echo REAL_NODECPUS = local:18                               >> $server{mcruns}/$server{rundir}/conf/ems_run/run_ncpus.conf";
    system "echo REAL_NODECPUS = kielbasa0:18,kielbasa1:18,kielbasa2:18 >> $server{mcruns}/$server{rundir}/conf/ems_run/run_ncpus.conf";
    system "echo EMSUPP_NODECPUS = local:17                             >> $server{mcruns}/$server{rundir}/conf/ems_post/run_post.conf";


    #------------------------------------------------------------------------------
    #  Step 3. Run ems_domain again to localize the run-time directory
    #
    #          %  ems_domain.pl --localize $server{rundir}
    #------------------------------------------------------------------------------
    #
    &Ecomm::PrintTerminal(1,4,114,1,0,"UEMS Mission Control ($server{client_id}:$server{client_pid}): Localizing $server{rundir} -");

    if (&Ecore::SysExecute("$server{mcubin}/ems_domain.pl --localize $server{rundir} --ncpus 18 --mcserver", $server{runlog})) {

        &Ecomm::PrintTerminal(0,0,12,0,1,' Failed');

        $mesg = "The localization of $server{rundir} has failed for some unknown reason. Check the log file for more information:\n\n".
                "    $server{runlog}";

        $ENV{MCMESG} = &Ecomm::TextFormat(0,2,92,0,2,'UEMS Mission Control - Server Error:',$mesg);
        return 1;
    }
    $date = gmtime;
    &Ecomm::PrintTerminal(0,0,12,0,1," Completed ($date UTC)"); &Others::rm($server{runlog});



    #------------------------------------------------------------------------------
    #  Step 4. Run the simulation via ems_autorun
    #
    #          %  ems_autorun.pl --rundir /usr1/uems/runs/<somedomain>
    #------------------------------------------------------------------------------
    #
    &Ecomm::PrintTerminal(1,4,114,1,0,"UEMS Mission Control ($server{client_id}:$server{client_pid}): Running Simulation -");


    if (&Ecore::SysExecute("$server{mcubin}/ems_autorun.pl --rundir $server{rundir}", $server{runlog})) {

        &Ecomm::PrintTerminal(0,0,12,0,1,' Failed');

        $mesg = "The simulation for $server{client_id} domain $server{client_dir} (PID: $server{client_pid}) ".
                "has met an untimely demise. Check the log file for more information:\n\n".
                "    $server{runlog}";

        $ENV{MCMESG} = &Ecomm::TextFormat(0,2,92,0,2,'UEMS Mission Control - Server Error:',$mesg);
        return 1;
    }
    $date = gmtime;
    &Ecomm::PrintTerminal(0,0,12,0,1," Completed ($date UTC)"); 

    &Others::rm($server{logdir});
    &Others::rm($server{rundir});


return 0;
}



sub SetServerEnvironment {
#==================================================================================
#  This subroutine manages the preliminary details of running UEMS Simulation
#  on the server client.  Unlike the Client-side version of this routine, there
#  is only one flag passed that needs to be checked, --tarfile, although 
#  it is passed by the UEMS Mission Monitor and should be correct.
#==================================================================================
#
    my $mesg;

    my $href  = shift; my %Ucntrl = %{$href};
    my %mcenv = %{$Ucntrl{mcenv}};
    my %flags = %{$Ucntrl{flags}};


    #------------------------------------------------------------------------------
    #  Read the local configuration file, making sure that the values are correct
    #------------------------------------------------------------------------------
    #
    my %conf = ();
    my $mccfg = "$mcenv{mccfg}/$mcenv{mc_server}.conf";

    unless (%conf = &ReadMissionConfiguration($mccfg)) {
        $mesg = "It appears that there was a problem reading the UEMS Mission Control Server ".
                "configuration file:\n\n".
                "X03X$mccfg\n\n";
        $ENV{MCMESG} = &Ecomm::TextFormat(0,0,84,0,2,"Failed $mcenv{mc_server} Ignition:",$mesg);
        return ();
    }


    #---------------------------------------------------------------------------------------
    #  U_PROCESS defines were the simulation configuration files are moved from the
    #  incoming directory and made available for processing.  It should already exist
    #  at this point since the check is done by Watchdog but better safe than sorry.
    #---------------------------------------------------------------------------------------
    #
    unless (defined $conf{u_process} and -d $conf{u_process}) {

        unless (defined $conf{u_process} and $conf{u_process}) {
            $ENV{MCMESG} = &Ecomm::TextFormat(0,0,144,0,2,"UEMS $mcenv{mc_server} termination","Illegal or missing value for u_process in $mccfg");
            return ();
        }

        if (&mkdir($conf{u_process})) {
            $ENV{MCMESG} = &Ecomm::TextFormat(0,0,144,0,2,"UEMS $mcenv{mc_server} termination","Unable to create u_process: $conf{u_process}");
            return ();
        }
    }


    #---------------------------------------------------------------------------------------
    #  Set the value of U_SIMID, which defines the simulation ID and should be a string of
    #  placeholders that will by used in creating directories and log files associated with
    #  each simulation request. 
    #---------------------------------------------------------------------------------------
    #
    $conf{u_simid} = 'STID_NAME_PID'  unless defined $conf{u_simid} and $conf{u_simid};



    #------------------------------------------------------------------------------
    #  Check whether the tar file containing the configuration information is
    #  available.
    #------------------------------------------------------------------------------
    #
    unless (defined $flags{tarfile} and $flags{tarfile}) {
       my $mesg = "When running $mcenv{mcexe} from the server system, you must include the \"--tarfile\" ".
                  "flag along with the path to the tarfile containing the configuration as an argument.\n\n".
                  "See \"$mcenv{mcexe} --help tarfile\" for more details.";
       $ENV{MCMESG} = &Ecomm::TextFormat(0,0,84,0,2,'Missing something?',$mesg);
       return ();
    }


    #------------------------------------------------------------------------------
    #  Manage the incoming tarfile that should me located in the designated 
    #  incoming directory. 
    #------------------------------------------------------------------------------
    #
    unless (-s $flags{tarfile}) {
       my $mesg = "When running $mcenv{mcexe} from the server system, you must include the \"--tarfile\" ".
                  "flag along with the path to the incoming tarfile containing the configuration.\n\n".
                  "Unfortunately for you, $flags{tarfile}, does not exist.";
       $ENV{MCMESG} = &Ecomm::TextFormat(0,0,94,0,2,'Configuration tarfile missing in action!',$mesg);
       return ();
    }
    my $tarfile = &Others::popit($flags{tarfile});


    unless ($tarfile =~ /\.tgz$|\.tbz$|\.tar$/i) {
        my $mesg = "The filename passed as an argument to \"--tarfile\" does not appear to be one of the supported ".
                   "formats, either .tgz, .tbz, or .tar:\n\n".
                   "X02X$tarfile\n\n".
                   "Consequently, I am unable to process your request.";
        $ENV{MCMESG} = &Ecomm::TextFormat(0,0,84,0,2,'I hope this hurts you more than it hurts me!',$mesg);
        return ();
    }


    #------------------------------------------------------------------------------
    #  The tarfile name includes the user (office) ID, the runtime directory name
    #  and a process ID (PID), which will be used to create the run-time 
    #  directory on the server.
    #  
    #  CHANGE: The local PID will be used in the run-time domain directory.
    #------------------------------------------------------------------------------
    #
    unless ($tarfile =~ /(\w+)_(\d+)_(\w+)\.t/i) {
        my $mesg = "The naming convention used for the tarfile passed with the to \"--tarfile\" flag does not meet ".
                   "the strict UEMS standards of\n\nX02X<client id>_<client pid>_<run-time directory>.tgz|tbz|tar\n\n".
                   "Your attempt with $tarfile does not pass muster.\n\n".
                   "Now that we understand each other, try passing a proper filename.";
        $ENV{MCMESG} = &Ecomm::TextFormat(0,0,84,0,2,'I say how we do things around here!',$mesg);
        return ();
    }

    #------------------------------------------------------------------------------
    #  The station or client ID, local process ID and directory name is used 
    #  to create the log and run-time directories.
    #------------------------------------------------------------------------------
    #
    $mcenv{client_id}  = lc $1;
    $mcenv{client_pid} = $2;  
    $mcenv{client_dir} = lc $3;

    for ($conf{u_simid}) {
        s/STID/$mcenv{client_id}/g; 
        s/PID/$mcenv{client_pid}/g;  
        s/NAME/$mcenv{client_dir}/g;
    }
    
    $mcenv{rundir}  = $conf{u_simid};
    $mcenv{logdir}  = "$conf{u_logging}/$conf{u_simid}";
    $mcenv{runlog}  = "$mcenv{logdir}/MissionControl-Autorun.log";

    $ENV{EMS_LOGS}  = $mcenv{logdir};


    #------------------------------------------------------------------------------
    #  Move the tarfile into the received directory for further interrogation
    #------------------------------------------------------------------------------
    #
    $mcenv{tarfile} = "$conf{u_process}/$tarfile";

    if (system "mv -f $flags{tarfile} $mcenv{tarfile} > /dev/null 2>&1") {
       $ENV{MCMESG} = &Ecomm::TextFormat(0,0,144,0,2,"Failed move of $tarfile to $mcenv{tarfile}");
       return ();
    }



return %mcenv;
}  



sub ProcessMissionOptions {
#==================================================================================
#  Front end to the GetOptions routine
#==================================================================================
#
      my %Options = ();

      %Options = &ParseMissionOptions(\%Options);
      %Options = &DefineOptionValues(\%Options);

return %Options;
}


sub ParseMissionOptions {
#==================================================================================
#  The ParseMissionOptions routine parses the flags and Option passed from the
#  command line to UEMS_MissionControl.pl Simple enough.
#==================================================================================
#
use Getopt::Long qw(:config pass_through);

    my $oref = shift; my %Options = %{$oref};


    GetOptions ("h|help|?"       => sub {&OptionHelp()},  #  Just what the doctor ordered

                "debug:s"        => \$Options{debug},       #  Just debugging information
                "tarfile:s"      => \$Options{tarfile},     #  Specify the tarfile file to use
                "rundir:s"       => \$Options{rundir},      #  Specify the run-time directory to use

                "domains:s"      => \$Options{domains},     #  Specify the domain(s) to be processed
                "length:s"       => \$Options{length},      #  The length of the simulation in hours
                "cycle:s"        => \$Options{rcycle},      #  The requested cycle hour of the initialization dataset [CC]
                "dset:s"         => \$Options{rdset},       #  Identify the initialization dataset(s) to use
                "date:s"         => \$Options{rdate}        #  The requested date of the initialization dataset [YYYYMMDD]
              
               );  &OptionHelp() if @ARGV;


return %Options; 
}


sub DefineOptionValues {
#==================================================================================
#  The &DefineOptionValues routine takes the option hash and gives them a value, 
#  whether they were passed or not. The $ENV{MCMESG} environment variable is used  
#  to indicate a failure.
#==================================================================================
#
    my $oref = shift; my %Options = %{$oref};
    
    #  ---------------------- Attempt the configuration ---------------------------
    #
    #  Note that the order is important for some!
    #
    $Options{debug}      =  &EvalMissionOption('debug'    ,$Options{debug});
    $Options{tarfile}    =  &EvalMissionOption('tarfile'  ,$Options{tarfile});
    $Options{rundir}     =  &EvalMissionOption('rundir'   ,$Options{rundir});

    $Options{domains}    =  &EvalMissionOption('domains'  ,$Options{domains});
    $Options{length}     =  &EvalMissionOption('length'   ,$Options{length});
    $Options{rdate}      =  &EvalMissionOption('rdate'    ,$Options{rdate});     #  Must be before RDSET for CFSR
    $Options{rcycle}     =  &EvalMissionOption('rcycle'   ,$Options{rcycle});
    $Options{rdset}      =  &EvalMissionOption('rdset'    ,$Options{rdset});    


    return () if $ENV{MCMESG};


return %Options;
}


sub EvalMissionOption {
#==================================================================================
#  This routine passes along the valid flag/argument list passed to Mission
#  Control for initialization and quality control. It's simply an interface 
#  to the individual option configuration routines.
#==================================================================================
#
    my $flag = q{};
    my @args = ();

    ($flag, @args) = @_;

    my $subroutine = "&Option_${flag}(\@args)";

return eval $subroutine;
}


sub DefineMissionOptions {
#==================================================================================
#  This routine defined the list of options that can be passed to the program
#  and returns them as a hash.
#==================================================================================
#
    my %opts = (
                '--debug'     => { arg => ''                   , help => '&Help_debug'    , desc => 'Turn ON debugging statements (If any exist, which they may not)'},
                '--rundir'    => { arg => 'DOMAIN DIR'         , help => '&Help_rundir'   , desc => 'Specify the simulation run-time directory to be used - client side'},
                '--tarfile'   => { arg => 'FILENAME'           , help => '&Help_tarfile'  , desc => 'Specify the path to the incoming tarfile - server side'},
                '--length'    => { arg => 'HOURS'              , help => '&Help_length'   , desc => 'Set the length of the simulation in hours. Overrides all other possible settings for length.'},
                '--cycle'     => { arg => 'HOUR[:...]'         , help => '&Help_rcycle'   , desc => 'The cycle time of the initialization dataset, plus a whole lot more'},
                '--dset'      => { arg => 'DSET[:...]'         , help => '&Help_dsets'    , desc => 'The dataset (and more) to use for initial and boundary conditions'},
                '--domains'   => { arg => 'DOMAIN[:START:STOP' , help => '&Help_domains'  , desc => 'Specify the domain to be included in the simulation (Default is domain 1)'},
                '--date'      => { arg => 'YYYYMMDD'           , help => '&Help_date'     , desc => 'The date of the files used for initialization of the simulation'},
                '--help'      => { arg => '[TOPIC]'            , help => '&Help_help'     , desc => "Either print this list again or pass me a topic and I\'ll explain it to you"}
               );

return %opts;
}



sub OptionHelp {
#==================================================================================
#  The OptionHelp routine determines what to do when the --help flag is passed
#  with or without an argument. If arguments are passed then the &PrintOptionHelp
#  subroutine is called; otherwise the entire option menu is printed.
#==================================================================================
#
    my @args  = &Others::rmdups(@_);

#   &PrintOptionHelp(@args) if @args;  #  Temporarily commented until 

    &Ecomm::PrintTerminal(0,7,255,1,1,&OptionHelpMenu);


&SysExit(-4); 
}


sub OptionHelpMenu  {
#==================================================================================
#  This routine provides the basic structure for the Mission Control help menu 
#  should  the "--help" option is passed or something goes terribly wrong.
#==================================================================================
#
    my @order = qw(dset date cycle length domains rundir tarfile debug help);
    my $mesg  = qw{};
    my @helps = ();

    my $exe = 'UEMS_MissionControl'; my $uce = uc $exe;

    my %opts = &DefineMissionOptions();  #  Get options list

    push @helps => &Ecomm::TextFormat(0,0,114,0,1,"RUDIMENTARY GUIDANCE FOR $uce (You didn't see anything here, right?)");

    $mesg = "The ${exe}.pl routine serves two purposes, to prepare a simulation configuration for submission and ".
            "execution on a remote server from a client workstation (that's a lot of \"ions\"), and to manage requests ".
            "submitted by a client workstation on the remote server. This is a work in progress and the details are being ".
            "worked out, so it's best that you move along and don't tell anyone what you read here.\n\n";


    push @helps => &Ecomm::TextFormat(2,2,90,1,1,$mesg);

    push @helps => &Ecomm::TextFormat(0,0,114,2,1,"$uce USAGE:");
    push @helps => &Ecomm::TextFormat(4,0,144,1,1,"% $exe [Other options if you're in the mood]");

    push @helps => &Ecomm::TextFormat(0,0,124,2,1,"AVAILABLE OPTIONS - BECAUSE YOU ASKED NICELY AND I'M BEGINNING TO LIKE YOUR BLOODSHOT EYES");

    push @helps => &Ecomm::TextFormat(4,0,114,1,2,"Flag            Argument [optional]       Description");


    foreach my $opt (@order) {
        $opt = "--$opt";
        push @helps => &Ecomm::TextFormat(4,0,256,0,1,sprintf("%-17s  %-18s  %-60s",$opt,$opts{$opt}{arg},$opts{$opt}{desc}));
    }


    push @helps => &Ecomm::TextFormat(0,0,114,2,2,"FOR ADDITIONAL HELP, LOVE AND UNDERSTANDING:");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"a. Read  - docs/uems/uemsguide/uemsguide_chapterXX.pdf");
    push @helps => &Ecomm::TextFormat(2,0,114,0,1,"Or");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"b. http://strc.comet.ucar.edu/software/uems");
    push @helps => &Ecomm::TextFormat(2,0,114,0,1,"Or");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"c. % $exe --help <topic>  For a more detailed explanation of each option (--<topic>)");
    push @helps => &Ecomm::TextFormat(2,0,114,0,1,"Or");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"d. % $exe --help  For this menu again");

    my $help = join '' => @helps;


return $help;
}


sub Option_domains {
#==================================================================================
#  Process initialization files for domains 1 ... --domains #.
#  Arguments to the --domain flag are --domain <number>[:<start hour>],<number>...,
#  where the <start hour> is the number of hours after the start of the primary
#  domain. Note that unlike the option passed to ems_run, the "LENGTH" of the
#  simulation must be in hours.
#
#  Additional configuration is done the Aconf module.
#==================================================================================
#
use POSIX;

    my @rdoms = ();

    my $passed = shift;

    return '' unless defined $passed and $passed;

    foreach (split /,|;/ => $passed) {

        my ($dom, $start, $length) = split /:/ => $_, 3;

        next unless $dom =~ /(\d)+/; $dom+=0;
        next if $dom <= 1;

        $start = 0 unless defined $start and &Others::isInteger($start);
        $start+= 0;
        $start = 0 unless $start > 0;

        $length = 0 unless defined $length and length $length;
        $length =~ s/[^0-9.]//g;  #  Strip and non-number charaters
        $length = int ceil $length;
        $length = 0 unless $length;

        $start  = '' unless $start;
        $length = '' unless $length;

        my @list = ($dom,$start,$length);
        push @rdoms => join ':' => @list;

    }
    foreach (@rdoms) {$_ =~ s/:+$//g;}
    @rdoms = &Others::rmdups(@rdoms);
    unshift @rdoms, '1' if @rdoms;  #  don't add unless other values


return @rdoms ? join ',' => sort @rdoms : 0;
} 



sub Option_length {
#==================================================================================
#  Specify the length of the simulation.  For this option a placeholder will be used 
#  and eventually replaced with a value in hours.
#==================================================================================
#
    my $passed = shift;

    $passed = 0 unless defined $passed and $passed;

return $passed;
}


sub Option_rcycle {
#==================================================================================
#  Manage the argument passed to --cycle
#==================================================================================
#
    my $string = 'CYCLE:INITFH:FINLFH:FREQFH';
    my @slist  = split /:/ => $string;

    my $passed = shift; return '' unless defined $passed;

    return '' unless length $passed;

    $passed   =~ s/,|;/:/g; #  replace with colons
    my @plist = split /:/ => $passed;
    
    foreach (0 .. $#plist) { 
        $slist[$_] = sprintf("%02d", $plist[$_]) if length $plist[$_] and &Others::isInteger($plist[$_]);
    }
    $passed = join ':' =>  @slist;

return $passed;
}



sub Option_rdate {
#==================================================================================
#  Specify the date of the files used for initialization.
#==================================================================================
#
    my $mesg   = qw{};
    my $passed = shift; return 0 unless defined $passed;

    unless (length $passed and $passed) {  
        $mesg = "When passing the \"--date\" flag you must provide an argument. Simply passing ".
                "\"--date\" by itself does neither of us any good (especially you). Come on, show ".
                "me you care, show me you want this!";
        $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,0,'One of us is holding you back',$mesg);
        return 0;
    }

    
    #  The silly user passed a non-digit
    #
    unless (&Others::isInteger($passed)) {
        $mesg = "The argument to \"--date\" is supposed to be a string of 8 digits in the format ".
                "of \"--date YYYYMMDD\".\n\nMaybe you missed the \"Numbers & Me\" lesson during the ".
                "Elmo does the UEMS video marathon, but consider yourself schooled.";
        $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,0,'School is in session!',$mesg);
        return 0;
    }


    #  If the user passed a 6-digit date (YYMMDD)
    #
    if (length $passed == 6) {$passed = (substr($passed,0,2)<45) ? "20${passed}" : "19${passed}";}


    unless ($passed =~ /^\d{8}$/) {
        $mesg = "The argument to \"--date\" is supposed to be a string of 8 digits in the format ".
                "of \"--date YYYYMMDD\".\n\nMaybe you missed the \"Numbers & Me\" lesson during the ".
                "Elmo does the UEMS video marathon, but consider yourself schooled.";
        $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,0,'School is in session!',$mesg);
        return 0;
    }


return $passed;
}



sub Option_rdset {
#==================================================================================
#  Dataset options in the form of <dataset>:<method>:<source>:<path>
#==================================================================================
#
    my $passed = shift;

    return '' unless defined $passed and $passed;

    $passed =~ s/ptiles|ptile/pt/g;
    $passed =~ s/%+/%/g;
    $passed =~ s/,+/%/g;
    $passed =~ s/;/:/g;

return $passed;
}



sub Option_rundir {
#==================================================================================
#  Define the value for RUNDIR, which is the name of the run-time domain 
#  directory to be used for the simulation. The argument to --rundir may 
#  or may not include the full path to the run-time domain. Only the directory
#  name is important and any path to the domain directory will be replaced with
#  $EMS_RUNS in the configuration module.
#==================================================================================
#
    my $passed = shift; 

    #----------------------------------------------------------------------------------
    #  In this initial stage we only care if the name of a domain directory was passed;
    #  otherwise set to 0 and get out.  Further configuration will be done during the
    #  configuration module.
    #----------------------------------------------------------------------------------
    #
    return '' unless defined $passed and $passed;  

 
    #----------------------------------------------------------------------------------
    #  Just interested in the name of the run-time directory at this point.
    #----------------------------------------------------------------------------------
    #
    $passed = &popit($passed);


    #----------------------------------------------------------------------------------
    #   Make sure the user did not pass jibberish
    #----------------------------------------------------------------------------------
    #
    return '' if $passed =~ /^\.|\.$|;|=|\?|\]|\[|\(|\)/;


return $passed || '';
}


sub Option_tarfile {
#==================================================================================
#  Define the value for tarfile, which is the name of the run-time domain 
#==================================================================================
#
    my $passed = shift; 

    
    return '' unless defined $passed and $passed;  

 
    #   Make sure the user did not pass jibberish
    #
    return '' if $passed =~ /^\.|\.$|;|=|\?|\]|\[|\(|\)/;


return $passed ? $passed : '';
}


sub Option_debug {
#==================================================================================
#  Define the value for the --debug flag, which for ems_autorun will be 1 or 0.
#==================================================================================
#
    my $passed = shift;

return (defined $passed and $passed) ? 1 : 0;
}



sub ReadMissionConfiguration {
#==================================================================================
#  This routine reads the contents of the specified mission configuration file
#  located in the uems/conf/uems_mission/ directory. It returns a hash in which 
#  keys are all lower case.
#==================================================================================
#
    my %cparms = ();
    my $cfile  = shift; 

    #----------------------------------------------------------------------------------
    #  Read the local configuration file. Minimal error checking will be done on
    #  the client because that requires knowledge of configuration files the other
    #  information that is not available.
    #----------------------------------------------------------------------------------
    #
    return () unless -s $cfile;
    return () unless my %parms = &Others::ReadConfigurationFile($cfile);

    foreach my $key (keys %parms) {$cparms{lc $key} = $parms{$key};}


return %cparms;
}



sub MissionGreeting {
#==================================================================================
#  Provide a semi-informative Greeting to the user
#==================================================================================
#
    my $date = gmtime();

    my ($exe,$ver) = @_;

    $exe = defined $exe  ? $exe  : $ENV{EMSEXE}; chomp $exe;
    $ver = defined $ver  ? $ver  : $ENV{EMSVER}; chomp $ver; my @ever = split ',', $ver; $ver = $ever[0];

    &Ecomm::PrintTerminal(0,2,192,2,2,sprintf ("Starting UEMS %s (V%s) on %s UTC",$exe,$ver,$date));

return;
}



sub ReturnHandler {
#==================================================================================
#  The purpose of this routine is to interpret the return codes from the various
#  mission control subroutines. Most of the real information is returned via the 
#  $MCMESG environment variable and is printed to the screen before exiting.
#==================================================================================
#
    my $rc = shift || return 0;  #  Hey!  Return code or it never happened!

    my $umesg =   (defined $ENV{MCMESG} and $ENV{MCMESG}) ? $ENV{MCMESG} : "Something happened RC = $rc";

    &Ecomm::PrintTerminal(9,4,255,1,1,$umesg);


return $rc;
}


sub SysIntHandle {
#==================================================================================
#  Determines what to do following an interrupt signal or control-C.
#==================================================================================
#
    $ENV{VERBOSE} = 1;  #  Set to verbose mode regardless of what the user wanted
    $ENV{EMSERR}  = 1 unless defined $ENV{EMSERR} and $ENV{EMSERR};  #  Need a value here

    my $rout = 'UEMS Mission Control';

   
    #------------------------------------------------------------------------------
    #  Let the user know how we feel about this
    #------------------------------------------------------------------------------
    #
    my @heys = ('Terminated!? Me? - But I was just getting this $rout party started!',
                'Hey, I thought we were a team!',
                'You know, it would be a shame if something happened to your keyboard.',
                'I think you did that with a bit too much enthusiasm!',
                'I hope you enjoyed yourself!',
                'I hope this hurts you more than it hurts me!',
                'And I was just beginning to like you!');


    $ENV{EMSERR} == 2 ? &Ecomm::PrintTerminal(6,0,96,1,1,"Hey, just wait a moment while I finish my business!!") :
                        &Ecomm::PrintTerminal(2,0,96,2,1,sprintf "$heys[int rand scalar @heys]");


    $ENV{EMSERR} = 2;  #  Set the EMS return error so that the files can be processed correctly.

    
    sleep 2;  #  As a precaution


&SysExit(2);
} #  SysIntHandle


sub SysExit {
#==================================================================================
#  Override the default behavior and prints out a semi-informative message
#  when exiting. The routine takes three arguments, only one of which is
#  mandatory ($err) with $rout (recommended) identifying the calling routine
#  and $mesg, which serves to override the prescribed messages.
#==================================================================================
#
    #  Modified to get rid of Perl version issues with switch statement.
    #
    $ENV{VERBOSE} = 1;  #  Set to verbose mode regardless of what the user wanted

    my $date = gmtime;
    my $slog = '"Think Globally, Model Locally!"';

     
    my ($err, $rout) = @_;  $rout = 'UEMS Mission Control';

    $err  = 0 unless defined $err and $err;

    my @whos = ('As the UEMS Genie says',
                'Mark Twain wished he had said',
                'The UEMS Metaphysician says',
                'The scribbling on my doctors prescription actually reads',
                'As the alchemists at Cambridge are fond of stating',
                'Michelangelo\'s hidden secret code in Sistine Chapel reads',
                'Alexander Graham Bell\'s first words on the telephone really were',
                'A little known tenet of Confucianism is',
                'The deciphered Voynich manuscript actually reads',
                'You can sometimes hear Tibetan Monks chant',
                'As Shields and Yarnell loved to gesticulate',
                'The very first message detected by SETI will be',
                'Smoke signals from the Vatican are often interpreted as',
                'Neil Armstrong\'s microphone cut out just before he said',
                'Alphanumeric code 6EQUJ5 will someday be interpreted as'
                );


    my $mesg = '';
    if ($err == 0) {$mesg = ($UEMS_CONTROL eq 'CLIENT') ? sprintf ("UEMS Client mission accomplished - Let's hope this this thing actually flies - %s UTC",$date) :
                            ($UEMS_CONTROL eq 'SERVER') ? sprintf ("UEMS Server mission accomplished - Success looks good on you! - %s UTC",$date)                :
                                                          sprintf ("I think that went better than expected - %s UTC",$date);}


    if ($err == 1) {$mesg = ($UEMS_CONTROL eq 'CLIENT') ? sprintf ("Your attempted simulation was grounded at %s UTC - Because stuff just happens",$date) :
                            ($UEMS_CONTROL eq 'SERVER') ? sprintf ("Your simulation didn't quite go as planned (%s UTC) - But you still look good!",$date):
                                                          sprintf ("There shall be no UEMS mission submission for you on %s UTC",$date);}

    if ($err == 2) {$mesg = sprintf "This $UEMS_CONTROL mission was terminated by Grumpy on %s UTC",$date;}


    &Ecomm::PrintTerminal(0,4,144,2,1,$mesg);
    &Ecomm::PrintTerminal(0,2,144,1,3,sprintf "$whos[int rand scalar @whos]: $slog");


CORE::exit $err;
} 



