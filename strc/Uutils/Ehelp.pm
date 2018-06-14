#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Ehelp.pm
#
#  DESCRIPTION:  Ehelp contains subroutines used to provide hand holding 
#                service to the user.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Ehelp;

use warnings;
use strict;
require 5.008;
use English;

use Ecomm;
use Ecore;



sub FormatHelpTopic {
#==================================================================================
#  Format the help topic for printing to a screen or window.
#==================================================================================
#
    my $href = shift;
    my %help = %{$href};

    my $flag = 'Flag          : ';
    my $what = 'What I Do     : ';
    my $use  = 'Usage         : ';
    my $desc = 'How You Do It : ';
    my $addn = 'Did You Know? : ';

    my $indt = length $what; 

    $flag    = &Ecomm::TextFormat(0,$indt,92,0,2,"${flag}$help{FLAG}");
    $what    = &Ecomm::TextFormat(0,$indt,104,0,2,"${what}$help{WHAT}");
    $use     = &Ecomm::TextFormat(0,$indt,255,0,2,"${use}$help{USE}");
    $desc    = &Ecomm::TextFormat(0,$indt,104,1,2,"${desc}$help{DESC}");
    $addn    = &Ecomm::TextFormat(0,$indt,124,1,2,"${addn}$help{ADDN}");

    my $help = "$flag$what$use$desc$addn";

return $help;
}


