#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Pmain
#
#  DESCRIPTION:  Pmain is the main ems_prep driver module. It is either called
#                by ems_autorun or ems_prep, and returns an error value to
#                indicate success, failure or something in between.
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Pmain;

require 5.8.0;
use strict;
use warnings;
use English;

use vars qw (%Uprep $rc);


sub ProcessDriver {
#===============================================================================
#   The purpose of &ProcessDriver is to execute each of the individual steps
#   involved in running ems_prep and return an error ($rc) should there be
#   a problem.  Note that the Uprep hash is global within this module.
#===============================================================================
#
    %Uprep = ();  #  Global
    @ARGV  = @_;

    #---------------------------------------------------------------------------
    #  Adding an unnecessary call for the sake of aesthetics. The &ReturnHandler
    #  routine is not really necessary other than to provide cover for otherwise
    #  ugly code.  The return code variable ($rc) and %Uprep are global within 
    #  this module.
    #---------------------------------------------------------------------------
    #
    return $rc if &ProcessReturnHandler(&ProcessStart());

    return $rc if &ProcessReturnHandler(&ProcessAcquire());

    return 20  if $Uprep{parms}{noprocess};

    return $rc if &ProcessReturnHandler(&ProcessUngrib());

    return $rc if &ProcessReturnHandler(&ProcessInterp());


return 0;
}



sub ProcessStart {
#==================================================================================
#  This subroutine calls routines that perform the initial configuration for
#  ems_prep prior to any real work being done. The responsibility of this 
#  section is to:
#
#      1. Initialize the %Uprep hash
#      2. Read and parse the user input options
#      3. Check for input and configuration issues 
#
#  Note that the handling of the return is different here than with the other
#  routines as a return of the %Uprep hash indicates success when an empty
#  hash means failure.
#==================================================================================
#
use Pinit;
use Pconf;
use Poptions;

    return 11 unless %Uprep = &Pinit::PrepInitialize(\%Uprep);
    return 12 unless %Uprep = &Poptions::PrepOptions(\%Uprep);
    return 13 unless %Uprep = &Pconf::PrepConfiguration(\%Uprep);

return 0;
}


sub ProcessAcquire {
#==================================================================================
#  This subroutine calls routines that perform the identifying and acquisition
#  of datasets used for model initialization. Because the entire %Uprep must
#  be returned, the error code is included in $Uprep{error}, which is
#  returned to the calling program.
#==================================================================================
#
use Pacquire;

    my $attempt = 1;
  
    $Uprep{emsenv}{autorun} ? &Ecomm::PrintMessage(0,7,144,2,1,sprintf("%-4s AutoPrep: Collecting the initialization datasets for your simulation",&Ecomm::GetRN($ENV{PRN}++)))
                            : &Ecomm::PrintMessage(0,4,144,2,1,sprintf("%-4s Collecting the initialization datasets for your simulation",&Ecomm::GetRN($ENV{PRN}++)));

    while ($attempt <= $Uprep{parms}{attempts}) {

        #---------------------------------------------------------------------------
        #  &PrepDataAcquisition attempts to acquire the data files for simulation
        #  initialization and returns a variety of error codes in $Uprep{error}
        #  corresponding to success (0) or the various levels of failure. The
        #  %Uprep hash is not returned because it is global within this module.
        #---------------------------------------------------------------------------
        #  
        %Uprep = &Pacquire::PrepDataAcquisition(\%Uprep);


        #---------------------------------------------------------------------------
        #  The reality is that an error code of 23/24 necessitates a continuation
        #  in this loop.
        #---------------------------------------------------------------------------
        #
        $attempt = $Uprep{parms}{attempts} unless grep {/^$Uprep{error}$/} (23,24);

        $attempt++;
        unless ($attempt > $Uprep{parms}{attempts}) {
            &Ecomm::PrintMessage(0,12+$Uprep{arf},96,1,0,"Zzzzz - Sleeping $Uprep{parms}{sleep} seconds before making attempt $attempt of $Uprep{parms}{attempts}");
            sleep $Uprep{parms}{sleep};
            &Ecomm::PrintMessage(0,1,26,0,2," Wake up, time to go!");
        }
    }
    &Ecomm::PrintMessage(0,9+$Uprep{arf},255,2,1,$Uprep{mesg});


return $Uprep{error};
}



sub ProcessUngrib {
#==================================================================================
#  This subroutine manages the processing of GRIB files into WRF 
#  intermediate format.
#==================================================================================
#
use Pungrib;

    return 31 unless %Uprep = &Pungrib::PrepProcessGrib(\%Uprep);

return 0;
}


sub ProcessInterp {
#==================================================================================
#  This subroutine manages the horizontal interpolation of intermediate format
#  files from the ungrib routine to the computational domain.
#==================================================================================
#
use Pinterp;

    return 41 unless %Uprep = &Pinterp::PrepInterpolation(\%Uprep);

return 0;
}


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



