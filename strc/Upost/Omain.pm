#!/usr/bin/perl
#===============================================================================
#
#
#         FILE:  Omain
#
#  DESCRIPTION:  Omain is the main ems_post driver module. It is either called
#                by ems_autorun or ems_post, and returns an error value to
#                indicate success, failure or something in between.
#                At least that's the plan.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#
#===============================================================================
#
package Omain;

require 5.008;
use strict;
use warnings;
use English;

use vars qw (%Upost $rc);



sub ProcessDriver {
#===============================================================================
#   The purpose of &ProcessDriver is to execute each of the individual steps
#   involved in running ems_post and return an error ($rc) should there be
#   a problem.  Note that the %Upost hash is global within this module.
#===============================================================================
#
    %Upost = ();  #  Global
    @ARGV  = @_;

    #---------------------------------------------------------------------------
    #  Adding an unnecessary call for the sake of aesthetics. The &ReturnHandler
    #  routine is not really necessary other than to provide cover for otherwise
    #  ugly code.  The return code variable ($rc) and %Upost are global within 
    #  this module.
    #---------------------------------------------------------------------------
    #
    return $rc if &ProcessReturnHandler(&PostStart());
    return $rc if &ProcessReturnHandler(&PostProcess());


return 0;
}



sub PostStart {
#==================================================================================
#  This subroutine calls routines that perform the initial configuration for
#  ems_post prior to any real work being done. The responsibility of this 
#  routine is to:
#
#      1. Initialize the %Upost hash
#      2. Read and parse the user input options
#      3. Gather run-time domain configuration
#      4. Check for input and configuration issues
#
#  Note that the handling of the return is different here than with the other
#  routines as a return of the %Upost hash indicates success when an empty
#  hash means failure.
#==================================================================================
#
use Oinit;
use Oconf;
use Ooptions;

    return 11 unless %Upost = &Oinit::PostInitialize(\%Upost);
    return 12 unless %Upost = &Ooptions::PostOptions(\%Upost);
    return 13 unless %Upost = &Oconf::PostConfiguration(\%Upost);

return 0;
}



sub PostProcess {
#==================================================================================
#  This subroutine calls the primary post-processing routine driver
#==================================================================================
#
use Opost;

    return 21 unless %Upost = &Opost::ExecutePost(\%Upost);

return 0;
}



sub ProcessReturnHandler {
#=====================================================================================
#  This nice and important sounding routine does nothing other than to set the
#  global $rc variable, allowing for a more elegant flow to the calling subroutine.
#  That's all, just for the sake of aesthetics.
#=====================================================================================
#
    $rc = shift;

return $rc ? 1 : 0;
}



