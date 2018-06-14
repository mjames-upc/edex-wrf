#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ems_post.pl
#
#  DESCRIPTION:  The ems_post.pl routine acquires and processes data for the
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
require 5.008;
use strict;
use warnings;
use English;

use Cwd 'abs_path';
use FindBin qw($RealBin);
use lib (abs_path("$RealBin/../Uutils"), abs_path("$RealBin/../Upost"));

use Omain;

use Ecore;
use Eenv;
use Others;


#===============================================================================
#   So ems_post begins.  Note that while the %Upost hash is passed into
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
    #  &Omain::ProcessDriver is the primary user interface for running ems_run.
    #  The argument passed to &ProcessDriver is a string of command line flags
    #  and arguments as defined in the user guide. The possible return values
    #
    #     0 - No problems
    #     1 - General Error
    #---------------------------------------------------------------------------
    #   
    &Ecore::SysExit(&ReturnHandler(&Omain::ProcessDriver(@ARGV)),$0);


&Ecore::SysExit(0,$0);


sub ReturnHandler {
#==================================================================================
#  The purpose of this routine is to interpret the return codes from the various
#  ems_post subroutines. The value that is returned identifies the routine from
#  which it was passed and any specific error, where the 10's digit identifies
#  the routine and the 1s is the error. Some routines may provide more error
#  information than others.
#
#  The routine itself returns 0 (ems_post carries on) for success or 1 (ems_post
#  terminates) for failure.
#==================================================================================
#
    my $rc    = shift;
    my $umesg = (defined $ENV{OMESG} and $ENV{OMESG}) ? $ENV{OMESG} : '';

    #  Return codes 11 - 19 are reserved for the Ostart Module
    #
    if ($rc == 11) {&Ecomm::PrintMessage(6,7,144,1,1,$umesg || 'Apparently, the ems_post initialization routine is upset with you at the moment');}
    if ($rc == 12) {&Ecomm::PrintMessage(6,7,144,1,1,$umesg || 'Apparently, the ems_post options routine is upset with you at the moment');}
    if ($rc == 13) {&Ecomm::PrintMessage(6,7,144,1,1,$umesg || 'Apparently, the ems_post configuration routine is upset with you at the moment');}

    #----------------------------------------------------------------------------------
    #  Return codes 21-29 are reserved for the &PostProcess subroutine, although
    #  right now only 21 is being used.
    #----------------------------------------------------------------------------------
    #
    if ($rc == 21) {&Ecomm::PrintMessage(9,7,144,2,1,$umesg || 'Well, at least this hurts you more than it hurts me!');}


return $rc ? 1 : 0;
}



