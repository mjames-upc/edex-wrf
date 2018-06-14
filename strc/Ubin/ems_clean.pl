#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ems_clean.pl
#
#  DESCRIPTION:  The uems_clean routine is used for general cleaning up of
#                domain directories.  The lone options to uems_clean are 
#                "--help" and "--level <0 ... 6>". For the most part users
#                should be executing uems_clean as "ems_clean --level <3 or 4>".
#
#                Additional details are provided by passing the "--help" flag
#                or by reading the UEMS user guide.
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
use lib abs_path("$RealBin/../Uutils");

use Eclean;

use Ecore;
use Eenv;
use Others;


#===============================================================================
#   So ems_clean begins.  Note that while the %Upost hash is passed into
#   the individual modules, it is global within a module. Any variables that
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


    #---------------------------------------------------------------------------
    #  &Eclean::CleanDriver is the primary user interface for running ems_clean.
    #  The argument passed to &Eclean::CleanDriver is a string of command line flags
    #  and arguments as defined in the user guide. The possible return values
    #
    #     0 - No problems
    #     1 - General Error
    #---------------------------------------------------------------------------
    #   
    &Ecore::SysExit(&CleanReturnHandler(&Eclean::CleanDriver(@ARGV)),$0);


&Ecore::SysExit(0,$0);



sub CleanReturnHandler {
#=====================================================================================
#  The purpose of this routine is to interpret the return codes from the various
#  UEMS clean subroutines. The value that is returned identifies the routine from
#  which it was passed and any specific error, where the 10's digit identifies
#  the routine and the 1s is the error. Some routines may provide more error
#  information than others.
#
#  The routine itself returns 0 (UEMS clean carries on) for success or 1 (UEMS clean
#  terminates) for failure.
#=====================================================================================
#
    my $rc = shift;

    my $umesg = (defined $ENV{CMESG} and $ENV{CMESG}) ? $ENV{CMESG} : '';

    #  Return codes 11 - 19 are reserved for the Eclean Start
    #
    if ($rc == 11) {&Ecomm::PrintMessage(6,4,96,1,1,$umesg || 'Apparently, the UEMS clean initialization is upset with you at the moment');}
    if ($rc == 12) {&Ecomm::PrintMessage(6,4,96,1,1,$umesg || 'Apparently, the UEMS clean options is upset with you at the moment');}

    #----------------------------------------------------------------------------------
    #  Return codes 21-29 are reserved for the &EcleanProcess subroutine, although
    #  right now only 21 is being used.
    #----------------------------------------------------------------------------------
    #
    if ($rc == 21) {&Ecomm::PrintMessage(9,4,255,2,1,$umesg || 'Well, at least this hurts you more than it hurts me!');}


return $rc ? 1 : 0;
}



