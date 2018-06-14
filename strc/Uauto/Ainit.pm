#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Ainit.pm
#
#  DESCRIPTION:  Ainit contains each of the primary routines used for the
#                initialization of the Uauto hash shortly after ems_autorun
#                starts.
#                
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Ainit;

use warnings;
use strict;
require 5.008;
use English;

use Ecomm;
use Ecore;
use Elove;
use Others;



sub AutoInitialize {
#==================================================================================
#  Initialize the common hashes and variables used by ems_prep
#==================================================================================
#
use Cwd;

    my $upref    = shift;
    my %Uauto  = %{$upref};

    unless (defined $ENV{UEMS} and $ENV{UEMS} and -e $ENV{UEMS}) {
        print '\n\n    !  The UEMS environment is not properly set - EXIT\n\n';
        return ();
    }


    #----------------------------------------------------------------------------------
    #  Initialize $ENV{AMESG}, which used to be @{$ENV{UMESG}} but resulted
    #  in conflicts is another UEMS routine was running (See autopost.pl).
    #----------------------------------------------------------------------------------
    #
    $ENV{AMESG} = '';


    #  ----------------------------------------------------------------------------------
    #  Set default language to English because the UEMS attempts to match English
    #  words when attempting to get system information.
    #  ----------------------------------------------------------------------------------
    #
    $ENV{LC_ALL} = 'C';


    #----------------------------------------------------------------------------------
    #  Set the UEMSPID environment variable that defined the PID associated with 
    #  this task (ems_autorun.pl). This variable will be checked by the run-time 
    #  routines to determine whether each step is part of a ems_autorun.pl run.
    #  Note that $ENV{UEMSPID} must be set prior to calling &Ecore::SysInitialize.
    #----------------------------------------------------------------------------------
    #
    $ENV{UEMSPID} = $$;


    #----------------------------------------------------------------------------------
    #  Populate the %Uauto hash with the information about the system
    #----------------------------------------------------------------------------------
    #
    %{$Uauto{emsenv}} = &Ecore::SysInitialize(\%Uauto);


    #----------------------------------------------------------------------------------
    #  Make the lower-level keys lower case. This is for no particular reason
    #  other than that's the way I like it, which is also the way I should have
    #  written it in the first place but didn't and I'm too lazy to change.
    #
    #  "Hey you kids, get off my simulated lawn!"
    #----------------------------------------------------------------------------------
    #
    foreach my $key (keys %{$Uauto{emsenv}}) { my $lk = lc $key;
        $Uauto{emsenv}{$lk} = $Uauto{emsenv}{$key}; delete $Uauto{emsenv}{$key};
    }

    
    #----------------------------------------------------------------------------------
    #  Prove the user with some well-deserved information
    #----------------------------------------------------------------------------------
    #
    &Elove::Greeting('ems_autorun',$Uauto{emsenv}{uemsver},$Uauto{emsenv}{sysinfo}{shost});


    #  Open the log file and keep it open until the end of ems_autorun
    #
#   $Uauto{logfile} = "$Uauto{emsrun}{logdir}/Uauto.$Uauto{ldat}.log";
#   open (my $lfh, '>', $Uauto{logfile}) || die "Can not open log file - $Uauto{logfile}";


return %Uauto;
} 



