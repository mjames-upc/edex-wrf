#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Elove.pm
#
#  DESCRIPTION:  Elove contains subroutines used to provide love & guidance
#                to the user.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Elove;

use warnings;
use strict;
require 5.008;
use English;



sub Greeting {
#==================================================================================
#  Provide a semi-informative Greeting to the user
#==================================================================================
#
    my $date = gmtime();

    my ($exe,$ver,$host) = @_;

    $exe = defined $exe  ? $exe  : $ENV{EMSEXE}; chomp $exe;
    $ver = defined $ver  ? $ver  : $ENV{EMSVER}; chomp $ver; my @ever = split ',', $ver; $ver = $ever[0];
    $host= defined $host ? $host : $ENV{EMSHOST};chomp $host if $host;

    $host ?  &Ecomm::PrintMessage(0,2,192,2,2,sprintf ("Starting UEMS Program %s (V%s) on %s at %s UTC",$exe,$ver,$host,$date)) :
             &Ecomm::PrintMessage(0,2,192,2,2,sprintf ("Starting UEMS Program %s (V%s) on %s UTC",$exe,$ver,$date));

return;
}



sub GetUEMSrelease {
#==================================================================================
#    Routine reads the contents of the $UEMS/strc/.release file and returns the
#    UEMS version number. If one is not available '00.00.00.00' is returned.
#==================================================================================
#
    my $ver  = 0;

    my $ems = shift; return $ver unless defined $ems and $ems;

    my $rfile = (-e "$ems/strc/.release")                              ? "$ems/strc/.release"       :
                (defined $ENV{UEMS} and -e "$ENV{UEMS}/strc/.release") ? "$ENV{UEMS}/strc/.release" : 0;

    return $ver unless $rfile;

    open (my $fh, '<', $rfile); my @lines = <$fh>; close $fh; foreach (@lines) {chomp; $ver = $_ if /EMS/i;}
    $ver =~ s/ //g; $ver =~ s/UEMS|EMS//g;


return $ver;
} #  GetUEMSrelease


sub GetWRFrelease {
#==================================================================================
#    Routine reads the contents of the $UEMS/strc/.release file and returns the
#    the WRF version number. If one is not available '0' is returned.
#==================================================================================
#
    my $ver  = 0;

    my $ems = shift; return $ver unless defined $ems and $ems;

    my $rfile = (-e "$ems/strc/.release")                              ? "$ems/strc/.release"       :
                (defined $ENV{UEMS} and -e "$ENV{UEMS}/strc/.release") ? "$ENV{UEMS}/strc/.release" : 0;

    return $ver unless $rfile;

    open (my $fh, '<', $rfile); my @lines = <$fh>; close $fh; foreach (@lines) {chomp; $ver = $_ if /WRF|ARW/i;}
    $ver =~ s/ //g; $ver =~ s/WRF|ARW//g;


return $ver;
} #  GetWRFrelease


