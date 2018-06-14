#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Aconf.pm
#
#  DESCRIPTION:  Aconf contains each of the primary routines used for the
#                final configuration of ems_autorun. It's the least elegant of
#                the ems_autorun modules simply because there is a lot of sausage
#                making going on.
#
#                A lot of sausage making
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Aconf;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Aconf $mesg);


sub AutoConfiguration {
#==================================================================================
#  Routine that calls each of the configuration subroutines. For ems_autorun:
#
#    1. Do the final checks of any command line flags passed
#    2. Do the final checks of the configuration file parameters
#    3. Set the UEMS autorun environment
#    4. Merge the command-line and configuration file parameters
#    5. Set the final %Uauto hash for use by ems_autorun
#==================================================================================
#
use Aflags;
use Afiles;
use Afinal;

    my $apref = shift; my %Uauto = %{$apref};

    &Ecomm::PrintTerminal(2,4,255,1,1,sprintf ("Attempting to translate your UEMS Autorun configuration into something special, like you!"));


    #----------------------------------------------------------------------------------
    #  The %Aconf hash will hold all the collected information until it can be
    #  sorted out. The following keys are used to hold the information:
    #
    #    a.  %Aconf{flags} - Command line flag configurations
    #    b.  %Aconf{files} - Configuration file parameters
    #----------------------------------------------------------------------------------
    #
    %Aconf  = (); #  %Aconf is the "work" hash and contains temporary variables used
                  #  in the configuration routines within this module.
                   

    #  Begin with the final configuration checks of the command line flags. This step
    #  must be completed first in order to determine the domain(s) to be processed.
    #
    return () unless %{$Aconf{flags}} = &Aflags::AutoFlagConfiguration(\%Uauto);


    #  Collect information on the local domain configuration 
    #
    return () unless %{$Uauto{rtenv}} = &SetRuntimeEnvironment($Aconf{flags}{rundir});


    #  Read and process the local configuration files under conf/ems_autorun.
    #  Note that the location of this call varies between modules depending 
    #  on whether the environment needs to be set.
    #
    return () unless %{$Aconf{files}} = &Afiles::AutoFileConfiguration(\%Uauto);


    #  the @{$Uauto{geodoms}} array holds the list of localized domains for which 
    #  geog_* files reside under the static/ directory. 
    #
    @{$Uauto{geodoms}}   = sort {$a <=> $b} keys %{$Uauto{rtenv}{geofls}};


    #  Both the user flags and configuration files have been collected and massaged,
    #  so it's time to create the master hash that will used throughout ems_autorun.
    #
    return () unless %{$Uauto{parms}} = &Afinal::AutoFinalConfiguration(\%Uauto,\%Aconf);

    return () unless $Uauto{emsenv}{mc} or %Uauto = &Afinal::AutoPostPreCheck(\%Uauto);


return %Uauto;
}  



sub SetRuntimeEnvironment {
#==================================================================================
#  Set the run-time environment for running ems_autorun. Note that the contents 
#  of %hash are returned to &AutoConfiguration as %{$Uauto{rtenv}}.
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
        $ENV{AMESG} = &Ecomm::TextFormat(0,0,88,0,0,'I made this mess, now you clean it up!',$mesg);
        return ();
    }


    if ($hash{core} eq 'ARW') {
        #  Have any domains been localized?  Check by looking for the "geo_*.nc" files 
        #  in the static directory. We need this information anyway.
        #
        %{$hash{geofls}}  = ();
        foreach (sort &Others::FileMatch($hash{static},'^geo_(.+)\.d\d\d\.nc$',1,0)) {
            if (/d(\d\d)\./) {my $d=$1;$d+=0;$hash{geofls}{$d} = $_;}
        }
    }


    unless (%{$hash{geofls}}) {
        my $mesg = "While I like your enthusiasm (and style), you will need to complete a successful ".
                   "localization before running ems_autorun. It appears this task was never done or it ".
                   "failed miserably while you were off doing something else such as looking at shiny ".
                   "things (yet again). You can correct this problem by simply running the following from ".
                   "the \"$hash{domname}\" domain directory:\n\n".
                   "X02X%  ems_domain --localize\n\n".
                   "and then return to me after you are successful. I like the smell of success!";
        $ENV{AMESG} = &Ecomm::TextFormat(0,0,84,0,0,"Let's try this again, from the top:",$mesg);
        return ();
    }

    $hash{mproj}  =  &Others::ReadVariableNC("$hash{static}/$hash{geofls}{1}",'MAP_PROJ');
    $hash{global} = ($hash{mproj} == 6 and ! defined $hash{wpsnlh}{GEOGRID}{dx}) ? 1 : 0;
    $hash{arlock} = "$ENV{EMS_LOGS}/uems_autorun.lock.$hash{emspid}";


    #------------------------------------------------------------------------------
    #  Collect the list of supported GRIB initialization files
    #------------------------------------------------------------------------------
    #
    unless (@{$hash{ginfos}} = &Others::FileMatch("$ENV{EMS_CONF}/gribinfo",'_gribinfo.conf',1,0)) {
        my $mesg = "It appears that the $ENV{EMS_CONF}/gribinfo directory does not contain ".
                   "any <dataset>_gribinfo.conf files.";
        $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,0,"Ha! The jokes on YOU!",$mesg);
        return ();
    }


return %hash;
}



