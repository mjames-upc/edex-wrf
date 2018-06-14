#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Putils.pm
#
#  DESCRIPTION:  Putils contains the utility subroutines used to drive
#                ems_prep.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Putils;

use warnings;
use strict;
require 5.008;
use English;


sub PrepFormatSummary {
#==================================================================================
#  Routine to format a summary of the domains & datasets used for initialization
#  of the simulation.  All the information should already be included in the
#  %Info hash.
#==================================================================================
#
use Others;
use Ecomm;

    my @lines=();
    my $href = shift;  my %Info = %{$href}; 

    my $bmi = $Info{conf}{bm} * 3;
    my $sfc = @{$Info{sfc}} ? join ', ' => @{$Info{sfc}} : 'None';
    my $lsm = @{$Info{lsm}} ? join ', ' => @{$Info{lsm}} : 'None';
    my $tac = $Info{conf}{aerosols} ? sprintf("Aerosol Climatology Dataset  : %s",&Others::popit($Info{conf}{aerosols})) : '';
       $tac = '' if $bmi;

    if ($Info{conf}{global}) {

        push @lines, &Ecomm::TextFormat(0,0,144,0,0,"Simulation Start Time        : $Info{sdate}");
        push @lines, &Ecomm::TextFormat(0,0,144,0,0,"Simulation End   Time        : $Info{edate}");
        push @lines, &Ecomm::TextFormat(0,0,144,0,0,"Initial Condition Dataset    : $Info{ics}");
        push @lines, &Ecomm::TextFormat(0,0,144,0,0,"Static Surface Datasets      : $sfc");
        push @lines, &Ecomm::TextFormat(0,0,144,0,0,"Land Surface Datasets        : $lsm");
        push @lines, &Ecomm::TextFormat(0,0,144,0,0,$tac) if $tac;
        push @lines, &Ecomm::TextFormat(0,0,144,1,0,'This is a GLOBAL simulation  - Going global!');

    } else {

    
        my $bcf = sprintf("$Info{bcf} Minute%s",$Info{bcf} == 1 ? "" : "s");
        my $bcs = ($Info{conf}{analysis} >= 0) ? '(Analysis dataset)' : '(Forecast dataset)';
           $bcs = "$bcs -> Interpolated to 60 Minute" if $Info{conf}{hiresbc};

        push @lines, &Ecomm::TextFormat(0,0,144,0,1,"\xe2\x98\xba  Running the 27 April 2011 benchmark case - You are so awesome!") if $bmi;
        push @lines, &Ecomm::TextFormat($bmi,0,144,0,0,"Simulation Start Time        : $Info{sdate}");
        push @lines, &Ecomm::TextFormat($bmi,0,144,0,0,"Simulation End   Time        : $Info{edate}");
        push @lines, &Ecomm::TextFormat($bmi,0,144,0,0,"Boundary Condition Frequency : $bcf $bcs");
        push @lines, &Ecomm::TextFormat($bmi,0,144,0,0,"Initial Condition Dataset    : $Info{ics}");
        push @lines, &Ecomm::TextFormat($bmi,0,144,0,0,"Boundary Condition Dataset   : $Info{bcs}");
        push @lines, &Ecomm::TextFormat($bmi,0,144,0,0,"Static Surface Datasets      : $sfc");
        push @lines, &Ecomm::TextFormat($bmi,0,144,0,0,"Land Surface Datasets        : $lsm");
        push @lines, &Ecomm::TextFormat($bmi,0,144,0,0,$tac) if $tac;

    }

    #  The %domains hash now contains all the requested domains and start times. Now
    #  make sure a domain does not start before parent and fill in non-requested domains
    #  with start time of -1.
    #
    push @lines, &Ecomm::TextFormat(0,0,255,1,1,'Included Sub-Domains:',"X02XDomainX04XParentX04XStart Date & Time") if @{$Info{conf}{reqdoms}} > 1;

    foreach my $dom (@{$Info{conf}{reqdoms}}) {
        next if $dom == 1;
        push @lines, &Ecomm::TextFormat($bmi,0,255,0,0,"X04X$dom         $Info{conf}{parents}{$dom}       $Info{domains}{$dom}{sdate}");
    }


return join "\n", @lines;
}



sub PrepCleaner {
#=====================================================================
#  This routine is the ems_run front end that calls the UEMS
#  cleaning utility.  Each one of the run-time routines should have 
#  a similar subroutine in its arsenal.  This routine should probably
#  be moved to the Eclean module, but I'm too lazy.
#=====================================================================
#
use Eclean;

    my ($level, $domain, $autorun) = @_; return unless $domain;

    return 0 if $autorun;  

    my @args = ('--domain',$domain,'--level',$level,'--silent');

return &Eclean::CleanDriver(@args);
}


