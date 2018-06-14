#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Rinit.pm
#
#  DESCRIPTION:  Rinit contains each of the primary routines used for the
#                initialization of the Urun hash shortly after ems_run starts.
#                
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Rinit;

use warnings;
use strict;
require 5.008;
use English;

use Ecomm;
use Ecore;
use Elove;
use Others;



sub RunInitialize {
#==================================================================================
#  Initialize the common hashes and variables used by ems_run
#==================================================================================
#
use Cwd;

    my $upref    = shift;
    my %Urun  = %{$upref};

    unless (defined $ENV{UEMS} and $ENV{UEMS} and -e $ENV{UEMS}) {
        print '\n\n    !  The UEMS environment is not properly set - EXIT\n\n';
        return ();
    }
    

    #----------------------------------------------------------------------------------
    #  Initialize $ENV{RMESG}, which used to be @{$ENV{UMESG}} but resulted
    #  in conflicts is another UEMS routine was running (See autopost.pl).
    #----------------------------------------------------------------------------------
    #
    $ENV{RMESG} = '';


    #----------------------------------------------------------------------------------
    #  The $ENV{RRN} environment variable holds the indexing for Roman Numerals
    #----------------------------------------------------------------------------------
    #
    $ENV{RRN}   = 0;


    #  ----------------------------------------------------------------------------------
    #  Set default language to English because the UEMS attempts to match English
    #  words when attempting to get system information.
    #  ----------------------------------------------------------------------------------
    #
    $ENV{LC_ALL} = 'C';

   
    #----------------------------------------------------------------------------------
    #  Populate the %Urun hash with the information about the system
    #----------------------------------------------------------------------------------
    #
    %{$Urun{emsenv}}     = &Ecore::SysInitialize(\%Urun);


    #----------------------------------------------------------------------------------
    #  Make the lower-level keys lower case. This is for no particular reason
    #  other than that's the way I like it, which is also the way I should have
    #  written it in the first place but didn't and I'm too lazy to change.
    #
    #  "Hey you kids, get off my simulated lawn!"
    #----------------------------------------------------------------------------------
    #
    foreach my $key (keys %{$Urun{emsenv}}) { my $lk = lc $key;
        $Urun{emsenv}{$lk} = $Urun{emsenv}{$key}; delete $Urun{emsenv}{$key};
    }


    #----------------------------------------------------------------------------------
    #  Prove the user with some well-deserved information
    #----------------------------------------------------------------------------------
    #
    &Elove::Greeting('ems_run',$Urun{emsenv}{uemsver},$Urun{emsenv}{sysinfo}{shost}) unless $Urun{emsenv}{autorun};


    $Urun{arf} = $Urun{emsenv}{autorun} ? 3 : 0;


    #  This will have to be moved until after logdir has been set
    #
#   $Urun{logfile} = "$Urun{rtenv}{logdir}/Urun.$Urun{LDAT}.log";
#   open (my $lfh, '>', $Urun{logfile}) || die "Can not open log file - $Urun{logfile}";


return %Urun;
}



