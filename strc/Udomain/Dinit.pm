#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Dinit.pm
#
#  DESCRIPTION:  Dinit contains each of the primary routines used for the
#                initialization of the Udomain hash shortly after ems_domain
#                starts.
#                
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Dinit;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Udomain);

use Ecomm;
use Ecore;
use Elove;
use Others;



sub Domain_Initialize {
#===============================================================================
#  Initialize the common hashes and variables used by ems_domain
#===============================================================================
#
use Cwd;
use Math::Trig;


    my $upref      = shift;
    my %Udomain = %{$upref};

    unless (defined $ENV{UEMS} and $ENV{UEMS} and -e $ENV{UEMS}) {
        print '\n\n    !  The UEMS environment is not properly set - EXIT\n\n';
        return ();
    }


    #----------------------------------------------------------------------------------
    #  Initialize $ENV{OMESG}, which used to be @{$ENV{UMESG}} but resulted
    #  in conflicts is another UEMS routine was running (See ems_autopost.pl).
    #----------------------------------------------------------------------------------
    #
    $ENV{DMESG} = '';


    #  ----------------------------------------------------------------------------------
    #  Set default language to English because the UEMS attempts to match English
    #  words when attempting to get system information.
    #  ----------------------------------------------------------------------------------
    #
    $ENV{LC_ALL} = 'C';

     
    #----------------------------------------------------------------------------------
    #  The $ENV{DRN} environment variable holds the indexing for Roman Numerals
    #----------------------------------------------------------------------------------
    #
    $ENV{DRN}   = 0;


    #----------------------------------------------------------------------------------
    #  Now initialize values that are only use within Udomain
    #----------------------------------------------------------------------------------
    #
    $Udomain{CONST}{erad} = 6370.0;  #  Assume a spherical earth with radius of 6370.0 km, just like ARW
    $Udomain{CONST}{eckm} = $Udomain{CONST}{erad} * acos(-1) * 2.0;


    #----------------------------------------------------------------------------------
    #  Initialize the common variables
    #----------------------------------------------------------------------------------
    #
    %Udomain = &Ecore::SysInitialize(\%Udomain);


    #----------------------------------------------------------------------------------
    #  Define the location of the executables used by ems_domain
    #----------------------------------------------------------------------------------
    #
    $Udomain{UEXE}{geogrid} = "$ENV{EMS_BIN}/geogrid";
    $Udomain{UEXE}{mpiexec} = "$ENV{EMS_MPI}/bin/mpiexec.gforker";

    
    #----------------------------------------------------------------------------------
    #  Determine which terrestrial datasets are installed 
    #----------------------------------------------------------------------------------
    #
    @{$Udomain{GEOG}{datasets}} = &Others::FileMatch("$ENV{EMS_DATA}/geog",'',1,0);


    #----------------------------------------------------------------------------------
    #  Hugs & kisses all around
    #---------------------------------------------------------------------------------- 
    #
    &Elove::Greeting('ems_domain',$Udomain{UEMSVER},$Udomain{SYSINFO}{shost});

    
#   $Udomain{LOGFILE} = "$Udomain{EMSRUN}{logdir}/Udomain.$Udomain{LDAT}.log";
#   open (my $lfh, '>', $Udomain{LOGFILE}) || die "Can not open log file - $Udomain{LOGFILE}";


return %Udomain;
}


