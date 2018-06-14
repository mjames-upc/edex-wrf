#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Oinit.pm
#
#  DESCRIPTION:  Oinit contains each of the primary routines used for the
#                initialization of the Upost hash shortly after ems_post
#                starts.
#                
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Oinit;

use warnings;
use strict;
require 5.008;
use English;

use Ecomm;
use Ecore;
use Elove;
use Others;



sub PostInitialize {
#==================================================================================
#  Initialize the common hashes and variables used by ems_run
#==================================================================================
#
use Cwd;

    my $upref    = shift;
    my %Upost  = %{$upref};

    unless (defined $ENV{UEMS} and $ENV{UEMS} and -e $ENV{UEMS}) {
        print '\n\n    !  The UEMS environment is not properly set - EXIT\n\n';
        return ();
    }


    #----------------------------------------------------------------------------------
    #  Initialize $ENV{OMESG}, which used to be @{$ENV{UMESG}} but resulted
    #  in conflicts is another UEMS routine was running (See autopost.pl).
    #----------------------------------------------------------------------------------
    #
    $ENV{OMESG} = '';


    #  ----------------------------------------------------------------------------------
    #  Set default language to English because the UEMS attempts to match English
    #  words when attempting to get system information.
    #  ----------------------------------------------------------------------------------
    #
    $ENV{LC_ALL} = 'C';


    #----------------------------------------------------------------------------------
    #  The $ENV{ORN} environment variable holds the indexing for Roman Numerals
    #----------------------------------------------------------------------------------
    #
    $ENV{ORN}   = 0;

   
    #----------------------------------------------------------------------------------
    #  Populate the Upost hash with the information about the system
    #----------------------------------------------------------------------------------
    #
    return () unless %{$Upost{emsenv}} = &Ecore::SysInitialize(\%Upost);


    #----------------------------------------------------------------------------------
    #  Make the lower-level keys lower case. This is for no particular reason
    #  other than that's the way I like it, which is also the way I should have
    #  written it in the first place but didn't and I'm too lazy to change.
    #
    #  "Hey you kids, get off my simulated lawn!"
    #----------------------------------------------------------------------------------
    #
    foreach my $key (keys %{$Upost{emsenv}}) { my $lk = lc $key;
        $Upost{emsenv}{$lk} = $Upost{emsenv}{$key}; delete $Upost{emsenv}{$key};
    }


    #----------------------------------------------------------------------------------
    #  At this point time to redefine the $ENV{EMS_RUN} variable - May need to be 
    #  redefined in Config
    #----------------------------------------------------------------------------------
    #
    $ENV{EMS_RUN} = $Upost{emsenv}{cwd};



    #----------------------------------------------------------------------------------
    #  $Upost{apf} shifts the messages an additional 3 spaces to the right when
    #  ems_prep is being run via ems_autorun.pl
    #----------------------------------------------------------------------------------
    #
    $Upost{arf} = $Upost{emsenv}{autorun} ? 3 : 0;


    #----------------------------------------------------------------------------------
    #  Prove the user with some well-deserved information
    #----------------------------------------------------------------------------------
    #
    &Elove::Greeting('ems_post',$Upost{emsenv}{uemsver},$Upost{emsenv}{sysinfo}{shost}) unless $Upost{emsenv}{autorun} or $ENV{AUTOPOST};



    #  Open the log file and keep it open until the end of ems_prep
    #
#   $Upost{logfile} = "$Upost{rtenv}{logdir}/uemsprep.$Upost{emsenv}{ldat}.log";
#   open (my $lfh, '>', $Upost{logfile}) || die "Can not open log file - $Upost{logfile}";


return %Upost;
}  



