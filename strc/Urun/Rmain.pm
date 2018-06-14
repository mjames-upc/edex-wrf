#!/usr/bin/perl
#===============================================================================
#
#
#         FILE:  Rmain
#
#  DESCRIPTION:  Rmain is the main ems_run driver module. It is either called
#                by ems_autorun or ems_run, and returns an error value to
#                indicate success, failure or something in between.
#                At least that's the plan.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#
#===============================================================================
#
package Rmain;

require 5.008;
use strict;
use warnings;
use English;

use Cwd 'abs_path';
use FindBin qw($RealBin);
use lib (abs_path("$RealBin/../Uapost"));

use vars qw (%Urun $rc);



sub ProcessDriver {
#===============================================================================
#   The purpose of &ProcessDriver is to execute each of the individual steps
#   involved in running ems_run and return an error ($rc) should there be
#   a problem.  Note that the %Urun hash is global within this module.
#===============================================================================
#
    %Urun = ();  #  Global
    @ARGV = @_;

    #---------------------------------------------------------------------------
    #  Adding an unnecessary call for the sake of aesthetics. The &ReturnHandler
    #  routine is not really necessary other than to provide cover for otherwise
    #  ugly code.  The return code variable ($rc) and %Urun are global within 
    #  this module.
    #---------------------------------------------------------------------------
    #
    return $rc if &ProcessReturnHandler(&ProcessStart());

    return $rc if &ProcessReturnHandler(&ProcessManage());


return 0;
}



sub ProcessStart {
#==================================================================================
#  This subroutine calls routines that perform the initial configuration for
#  ems_run prior to any real work being done. The responsibility of this 
#  routine is to:
#
#      1. Initialize the %Urun hash
#      2. Read and parse the user input options
#      3. Gather run-time domain configuration
#      4. Check for input and configuration issues
#
#  Note that the handling of the return is different here than with the other
#  routines as a return of the %Urun hash indicates success when an empty
#  hash means failure.
#==================================================================================
#
use Rinit;
use Rconf;
use Roptions;

    return 11 unless %Urun = &Rinit::RunInitialize(\%Urun);
    return 12 unless %Urun = &Roptions::RunOptions(\%Urun);
    return 13 unless %Urun = &Rconf::RunConfiguration(\%Urun);

return 0;
}



sub ProcessManage {
#==================================================================================
#  The &ProcessManage routine manages the set-up and running of the simulation 
#  depending upon the core. Currently support exists for only the WRF ARW but
#  additional cores may be added in the future via a $Urun{core} variable. 
#
#  The $Urun{rc} variable is used notify the ems_autopost.pl (if used) whether
#  the Autopost routine was successful (0) or not (53). A $Urun{rc} = 53 value
#  tells ems_autopost.pl that the simulation was successful but the autopost
#  failed, in which case all post processing will be done after the simulation.
#
#  In summary, this routine:
#
#    1. Estabilished the domain decomposition for each routine
#    2. Initiates the preprocessing of initialization files
#    3. Runs the simulation
#==================================================================================
#
use Rexe;

    return 21 unless %Urun = &Rexe::ProcessNodesCores(\%Urun);

    if (grep {/^real$/} keys %{$Urun{processes}}) {return 22 unless %Urun = &Rexe::ProcessControl_REAL(\%Urun);}
    
    if (grep {/^wrfm$/} keys %{$Urun{processes}}) {return 23 unless %Urun = &Rexe::ProcessControl_WRFM(\%Urun);}
    

return $Urun{rc};
}  #  ProcessManage



sub ProcessReturnHandler {
#==================================================================================
#  This nice and important sounding routine does nothing other than to set the
#  global $rc variable, allowing for a more elegant flow to the calling subroutine.
#  That's all, just for the sake of aesthetics.
#==================================================================================
#
    $rc = shift;

return $rc ? 1 : 0;
}



