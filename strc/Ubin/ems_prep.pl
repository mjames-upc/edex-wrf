#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ems_prep.pl
#
#  DESCRIPTION:  The ems_prep.pl routine acquires and processes data for the
#                purpose of NWP model initialization. The routine is very
#                flexible with lots of user options so start by reading
#                the help pages or user guide should you have any questions.
#
#                Additional details are provided by passing the "--help" flag
#                or by reading the UEMS user guide.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
require 5.8.0;
use strict;
use warnings;
use English;
use Cwd 'abs_path';
use FindBin qw($RealBin);
use lib (abs_path("$RealBin/../Uutils"), abs_path("$RealBin/../Uprep"));

use Ecore;
use Eenv;
use Others;


#===============================================================================
#   This front end to the main ems_prep routine is intended to be run from
#   the command line.
#===============================================================================
#
use Pmain;


    #---------------------------------------------------------------------------
    #  Override interrupt handler - Use the local one since some of the local
    #  environment variables are needed for clean-up after the interrupt.
    #---------------------------------------------------------------------------
    #
    $SIG{INT} = \&Ecore::SysIntHandle;


    #---------------------------------------------------------------------------
    #  Make sure the UEMS environment is set
    #---------------------------------------------------------------------------
    #
    &Ecore::SysExit(-1,$0) if &Eenv::SetEnvironment($ENV{UEMS});


    #---------------------------------------------------------------------------
    #  &Pmain::PrepDriver is the primary user interface for running ems_prep.
    #  The argument passed to &PrepDriver is a string of command line flags
    #  and arguments as defined in the user guide. The possible return values
    #
    #     0 - No problems
    #     1 - General Error
    #---------------------------------------------------------------------------
    #   
    &Ecore::SysExit(&ReturnHandler(&Pmain::ProcessDriver(@ARGV)),$0);


&Ecore::SysExit(0,$0);


sub ReturnHandler {
#==================================================================================
#  The purpose of this routine is to interpret the return codes from the various
#  ems_prep subroutines. The value that is returned identifies the routine from
#  which it was passed and any specific error, where the 10's digit identifies
#  the routine and the 1s is the error. Some routines may provide more error
#  information than others.
#
#  The routine itself returns 0 (ems_prep carries on) for success or 1 
#  (ems_prep terminates) for failure.
#==================================================================================
#
    my $rc = shift;

    my $umesg = (defined $ENV{PMESG} and $ENV{PMESG}) ? $ENV{PMESG} : '';

    #----------------------------------------------------------------------------------
    #  Return codes 11-19 are reserved for the Pstart module
    #----------------------------------------------------------------------------------
    #
    if ($rc == 11) {&Ecomm::PrintMessage(9,4,144,2,1,$umesg || 'Apparently, the &PrepInitialize routine routine is upset with you at the moment');}
    if ($rc == 12) {&Ecomm::PrintMessage(9,4,144,2,1,$umesg || 'Apparently, the &PrepOptions routine routine is upset with you at the moment');}
    if ($rc == 13) {&Ecomm::PrintMessage(9,4,144,2,1,$umesg || 'Apparently, the &PrepConfiguration routine is upset with you at the moment');}


    #----------------------------------------------------------------------------------
    #  Return codes 21-29 are reserved for the Pacquire Module. Note that 
    #  &Pacquire::ReturnMessages lists the return codes as 0, 21, 22, 23, and 24.
    #  Return code 0 is switched for 20 id the --noproc flag was passed. Some
    #  return codes don't require additional blather (23 & 24).
    #----------------------------------------------------------------------------------
    #
    if ($rc == 20) {&Ecomm::PrintMessage(0,7,144,2,1,$umesg || 'Just as you wished, your requested files have been downloaded - Enjoy!'); $rc = 0;}
    if ($rc == 21) {&Ecomm::PrintMessage(9,4,144,2,1,$umesg || 'Well, at least this hurts you more than it hurts me!');}
    if ($rc == 22) {&Ecomm::PrintMessage(9,4,144,2,1,$umesg || 'Check the areal coverage of the dataset used for initialization');}

    #  Don't remember why this is here
    #
    if ($rc == 29) {&Ecomm::PrintMessage(9,4,144,2,1,$umesg || 'I\'m pretty sure absolute failure was not part of the plan.');}
    
    #----------------------------------------------------------------------------------
    #  Return codes 31-39 are reserved for Pungrib module
    #----------------------------------------------------------------------------------
    #
    if ($rc == 31) {&Ecomm::PrintMessage(9,4,144,1,1,$umesg || 'We managed to mangle the GRIB file processing again.');}

    #----------------------------------------------------------------------------------
    #  Return code 41 is reserved for Pinterp module
    #----------------------------------------------------------------------------------
    #
    if ($rc == 41) {&Ecomm::PrintMessage(9,7,144,1,1,$umesg || 'The interpolation of data to the computational domain failed, which bites.');}



return $rc ? 1 : 0;
}



