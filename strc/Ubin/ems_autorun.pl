#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ems_autorun.pl
#
#  DESCRIPTION:  The ems_autorun.pl routine is used to automate the process of
#                running a complete simulation, from acquiring initialization data, 
#                configuring and executing the model run, and then post processing
#                the simulation output. This routine may be used for both real-time
#                forecasting and case study purposes, unless you are with the NWS,
#                in which case operational use is not recommended.
#
#                This routine runs ems_prep, ems_run and ems_post in succession.
#                You also have the option of post-processing model output while
#                a simulation is running (AUTOPOST) or after it has completed,
#                although be sure to heed the warnings when attempting to do
#                concurrent post-processing (Hint - Do not try on same machine).
#                
#                When runnning ems_aurorun.pl, the default behavior is to use the 
#                current machine date and time when identifying the initialization
#                dataset. For case study use it is recommended that you include
#                the --date and --cycle flags. All other configurable parameters
#                are found in the ems_autorun.conf file
#                
#                Additional details are provided by passing the "--help" flag or
#                by reading the UEMS user guide.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
require 5.008;
use strict;
use warnings;
use English;

use Cwd 'abs_path';
use FindBin qw($RealBin);
use lib (abs_path("$RealBin/../Uutils"), abs_path("$RealBin/../Uauto"), abs_path("$RealBin/../Uprep"), 
         abs_path("$RealBin/../Urun"), abs_path("$RealBin/../Upost"));

use vars qw (%Uauto);

use Ecomm;
use Ecore;
use Eenv;
use Others;


#===============================================================================
#   So ems_autorun begins.  Note that while the %Uauto hash is passed into
#   the external modules, it is global within this module. Any variables that
#   are required later on will be carried in this hash.
#===============================================================================
#
    #  Override interrupt handler - Use the local one since some of the local
    #  environment variables are needed for clean-up after the interrupt.
    #
    $SIG{INT} = \&Ecore::SysIntHandle;


    #  Make sure the UEMS environment is set
    #
    &Ecore::SysExit(-1,$0) if &Eenv::SetEnvironment($ENV{UEMS});


    #  Might need a system return code handler in Ecore
    #
    #  !  Note that SysExit will be replaced with a simple return 1 for the final
    #
    &Ecore::SysExit(1,$0)  if &ReturnHandler(&AutoStart());

    &Ecore::SysExit(1,$0)  if &ReturnHandler(&AutoProcess());


&Ecore::SysExit(0,$0);


sub AutoStart {
#==================================================================================
#  This subroutine calls routines that perform the initial configuration for
#  ems_autorun prior to any real work being done. The responsibility of this 
#  routine is to:
#
#      1. Initialize the %Uauto hash
#      2. Read and parse the user input options
#      3. Gather run-time domain configuration
#      4. Check for input and configuration issues
#
#  Note that the handling of the return is different here than with the other
#  routines as a return of the %Uauto hash indicates success when an empty
#  hash means failure.
#==================================================================================
#
use Ainit;
use Aoptions;
use Aconf;

    return 11 unless %Uauto = &Ainit::AutoInitialize(\%Uauto);
    return 12 unless %Uauto = &Aoptions::AutoOptions(\%Uauto);
    return 13 unless %Uauto = &Aconf::AutoConfiguration(\%Uauto);

return 0;
}



sub AutoProcess {
#==================================================================================
#  This subroutine is the primary driver for ems_autorun. Provided that the 
#  configuration went properly (&AutoStart), this routine: 
#
#    0. Set the Autorun lock file
#    1. Executes ems_prep            - &Auems::AutoPrepDriver
#    2. Starts the simulation        - &Auems::AutoRunDriver
#    3. Initiated the post processor - &Auems::AutoPostDriver
#
#==================================================================================
#
use Auems;

    #  The first step is to check whether a simulation is already running 
    #
    return 90 unless %Uauto = &Autils::AutoLockStat(\%Uauto);

    return 21 unless %Uauto = &Auems::AutoPrepDriver(\%Uauto);
    return 31 unless %Uauto = &Auems::AutoRunDriver(\%Uauto);
    return 41 unless %Uauto = &Auems::AutoPostDriver(\%Uauto);

    #  All this call does is delete the lock file
    #
    return 91 unless %Uauto = &Autils::AutoLockStat(\%Uauto);

return 0;
}



sub ReturnHandler {
#==================================================================================
#  The purpose of this routine is to interpret the return codes from the various
#  ems_autorun subroutines. The value that is returned identifies the routine from
#  which it was passed and any specific error, where the 10's digit identifies
#  the routine and the 1s is the error. Some routines may provide more error
#  information than others.
#
#  The routine itself returns 0 (ems_autorun carries on) for success or 1 
#  (ems_autorun terminates) for failure.
#==================================================================================
#
    my $rc = shift;

    my $umesg = (defined $ENV{AMESG} and $ENV{AMESG}) ? $ENV{AMESG} : '';

    return 0 unless $rc;

    $umesg = 'It appears that you have unexpected company with multiple UEMS jobs - Maybe next time.' if $rc == 90;

    &Ecomm::PrintMessage(0,7,255,1,1,$umesg) if $umesg;

    &Others::rm($Uauto{rtenv}{arlock});  #  Otherwise it does not get deleted

return 1;
}



