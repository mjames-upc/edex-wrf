#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Afiles.pm
#
#  DESCRIPTION:  Files contains the primary routines used for the initial checks
#                of ems_autorun parameters read from the configuration files. Each
#                parameter is handled individually.
#
#                Some sausage making
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Afiles;

use warnings;
use strict;
require 5.008;
use English;



sub AutoFileConfiguration {
# ==============================================================================================
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Collect the few configuration settings under the local conf/EMS_AUTORUN directory, 
#  which are returned in a hash containing PARAMETER = @{VALUES}. Checks are made to ensure 
#  the values are valid.  Note that the individual subroutines are not necessary but serve
#  to organize the parameters and break up the monotony, although I have yet to include them.
#  So long live monotony!
# ==============================================================================================
#
    my $fdbg  = 0;  #  For local debugging

    my %parms = ();
    my %Files = ();

    my $aref = shift; my %Uauto = %{$aref};


    #----------------------------------------------------------------------------------
    #  Read the local configuration files, which are returned in the %cparms hash.
    #----------------------------------------------------------------------------------
    #
    return () unless -d $Uauto{rtenv}{autoconf};
    return () unless my %cparms = &Others::ReadLocalConfiguration($Uauto{rtenv}{autoconf});


    #----------------------------------------------------------------------------------
    #  Now begin the process of checking the parameters for valid values. Each 
    #  parameter is checked for validity but are not crossed-checked with other
    #  parameters, which is done prior to the values being used. 
    #----------------------------------------------------------------------------------
    #
    my $cval  = qw{}; #  Config Value
    my $dval  = qw{};
    my @rvals = ();
    my @cvals = ();


    #============================================================================
    #  EMS_AUTORUN: DSETS (string value)  Default: gfspt
    #============================================================================
    #
    @rvals  = ();
    $dval   = 'gfsp25pt';
    @cvals  = ($cparms{DSETS} and @{$cparms{DSETS}}) ? @{$cparms{DSETS}}  : ($dval);
    foreach (@cvals) {s/'|,|;//g; push @rvals, $_ if length $_;} @cvals = &Others::rmdups(@rvals);
 
    @cvals = ()     if grep {/^0$/} @cvals; #  Set to 0 (OFF) if 0 value in string

    $Files{dsets} = @cvals ? join ',', @cvals : $dval; 



    #============================================================================
    #  EMS_AUTORUN: SFC (string value)
    #============================================================================
    #
    @rvals  = ();
    $dval   = 0;
    @cvals  = ($cparms{SFC} and @{$cparms{SFC}}) ? @{$cparms{SFC}}  : ($dval);
    foreach (@cvals) {s/'|,|;//g; push @rvals, $_ if length $_;} @cvals = &Others::rmdups(@rvals);

    @cvals = ()      if grep {/^0$/} @cvals; #  Set to 0 (OFF) if 0 value in string

    $Files{sfc} = @cvals ? join ',', @cvals : $dval;



    #============================================================================
    #  EMS_AUTORUN: SYNCSFC (string value)
    #============================================================================
    #
    @rvals  = ();
    $dval   = 0;
    @cvals  = ($cparms{SYNCSFC} and @{$cparms{SYNCSFC}}) ? @{$cparms{SYNCSFC}}  : ($dval);
    foreach (@cvals) {s/'|,|;//g; push @rvals, $_ if length $_;} @cvals = &Others::rmdups(@rvals);

    @cvals = ()      if grep {/^0$/} @cvals; #  Set to 0 (OFF) if 0 value in string

    $Files{syncsfc} = @cvals ? join ',', @cvals : $dval;



    #============================================================================
    #  EMS_AUTORUN: LSM (string value)
    #============================================================================
    #
    @rvals  = ();
    $dval   = 0;
    @cvals  = ($cparms{LSM} and @{$cparms{LSM}}) ? @{$cparms{LSM}}  : ($dval);
    foreach (@cvals) {s/'|,|;//g;push @rvals, $_ if length $_;} @cvals = &Others::rmdups(@rvals);
    
    @cvals = (0)      if grep {/^0$/} @cvals; #  Set to 0 (OFF) if 0 value in string

    $Files{lsm} = join ',', @cvals;

    
    #============================================================================
    #  EMS_AUTORUN: RDATE  (YYYYMMDD)
    #
    #  Note: Included for use with UEMS_MissionControl.pl and not intended
    #        to be part of the ems_autorun.conf file configured by the user.
    #        Users should be passing the --date & --cycle flags. 
    #============================================================================
    #
    $dval  = 0;
    $cval  = (defined $cparms{RDATE}[0] and $cparms{RDATE}[0]) ?  $cparms{RDATE}[0] : $dval;

    $Files{rdate}    = $cval;


    #============================================================================
    #  EMS_AUTORUN: RCYCLE  (CYCLE:INITFH:FINLFH:BCFREQ))
    #
    #  Note: Included for use with UEMS_MissionControl.pl and not intended
    #        to be part of the ems_autorun.conf file configured by the user.
    #        Users should be passing the --date & --cycle flags
    #============================================================================
    #
    $dval  = 0;
    $cval  = (defined $cparms{RCYCLE}[0] and $cparms{RCYCLE}[0]) ?  $cparms{RCYCLE}[0] : $dval;

    $Files{rcycle}    = $cval;



    #============================================================================
    #  EMS_AUTORUN: INITFH (integer value) 
    #
    #  Note: Deprecated and not used but retained for the sake of humanity
    #============================================================================
    #
    $dval  = 0;
    $cval  = (defined $cparms{INITFH}[0] and $cparms{INITFH}[0]) ?  $cparms{INITFH}[0] : $dval;

    $Files{initfh}    = $cval;


    #============================================================================
    #  EMS_AUTORUN: BCFREQ (integer value)
    #
    #  Note: Deprecated and not used but retained for the sake of humanity
    #============================================================================
    #
    $dval  = 3;
    $cval  = (defined $cparms{BCFREQ}[0] and $cparms{BCFREQ}[0]) ?  $cparms{BCFREQ}[0] : $dval;

    $Files{bcfreq}    = $cval;


    #============================================================================
    #  EMS_AUTORUN: LENGTH (integer value) in hours
    #============================================================================
    #
    $dval  = 24;
    $cval  = (defined $cparms{LENGTH}[0] and $cparms{LENGTH}[0]) ?  $cparms{LENGTH}[0] : $dval;

    $Files{length}    = $cval;



    #============================================================================
    #  EMS_AUTORUN: DOMAINS (Integer)
    #============================================================================
    #
    @rvals = ();
    @cvals = ($cparms{DOMAINS} and @{$cparms{DOMAINS}}) ? @{$cparms{DOMAINS}}  : ();

    foreach (@cvals) {$_ = &DomainStartStop($_); push @rvals, $_ if $_;} @cvals = sort &Others::rmdups(@rvals);
    unshift @cvals, '1'; #  Add domain 1

    $Files{domains} = join ',', @cvals;


    #============================================================================
    #  EMS_AUTORUN: EMSPOST (Integer:string)  
    #============================================================================
    #
    @cvals  = ($cparms{EMSPOST} and @{$cparms{EMSPOST}}) ? @{$cparms{EMSPOST}}  : (0);

    foreach (@cvals) {$_ = lc $_; s/,+|;+/,/g; s/:+/:/g; s/(,+)$//g; s/(:+)$//g;}
    @cvals = ('Auto') if grep {/All|Auto/i}  @cvals; #  Set to 'Auto' if All or Auto
    @cvals = (0)      if grep {/^0$/} @cvals; #  Set to 0 (OFF) if 0 value in string
    @cvals = (0)      if grep {/^Off/i} @cvals;
    @cvals = @cvals ? sort &Others::rmdups(@cvals) : (0);

    $Files{emspost} = join ',', @cvals;


    #============================================================================
    #  EMS_AUTORUN: AUTOPOST (Integer:string)  
    #============================================================================
    #
    @cvals  = ($cparms{AUTOPOST} and @{$cparms{AUTOPOST}}) ? @{$cparms{AUTOPOST}}  : (0);

    foreach (@cvals) {$_ = lc $_; s/,+|;+/,/g; s/:+/:/g; s/(,+)$//g; s/(:+)$//g;}
    @cvals = ('Auto') if grep {/All|Auto/i}  @cvals; #  Set to 'Auto' if All or Auto
    @cvals = (0)      if grep {/^0$/} @cvals; #  Set to 0 (OFF) if 0 value in string
    @cvals = (0)      if grep {/^Off/i} @cvals;
    @cvals = @cvals ? sort &Others::rmdups(@cvals) : (0);

    $Files{autopost} = join ',', @cvals;



    #============================================================================
    #  EMS_AUTORUN: NUDGING (Y|N)  - 1|0 are the desired output values
    #============================================================================
    #
    $cval = (defined $cparms{NUDGING}[0]) ?  $cparms{NUDGING}[0] : 0;

    $Files{nudging} = &SetValues_OnOff($cval,0,1); #  Ensure $cval is properly set



    #============================================================================
    #  EMS_AUTORUN: AEROSOLS (Y|N)  - 1|0 are the desired output values
    #============================================================================
    #
    $cval = (defined $cparms{AEROSOLS}[0]) ?  $cparms{AEROSOLS}[0] : 0;

    $Files{aerosols} = &SetValues_OnOff($cval,0,1); #  Ensure $cval is properly set



    #============================================================================
    #  EMS_AUTORUN: USERS (strings: primary | auxiliary)
    #============================================================================
    #
    @cvals = ($cparms{USERS} and @{$cparms{USERS}}) ? @{$cparms{USERS}}  : (0);
    @cvals = grep {/\@/} @cvals; @cvals = (0) unless @cvals;
    @cvals = sort &Others::rmdups(@cvals);

    $Files{users} = join ',', @cvals;

    if ($Files{users} and ! $ENV{MAILX}) {
        &Ecomm::PrintMessage(6,7,94,1,1,"Warning: MAILX not configured - No notifications will be sent to $Files{users}");
        $Files{users} = '';
    }



    #============================================================================
    #  EMS_AUTORUN: SCOUR (Y|N)  - 1|0 are the desired output values
    #============================================================================
    #
    $cval = (defined $cparms{SCOUR}[0] and length $cparms{SCOUR}[0]) ?  $cparms{SCOUR}[0] : 'Yes';
    $cval = ($cval =~ /^[41Yy]/) ? 'Yes' : 'No'; #  For backward compatibility; Set "1" to Yes

    $Files{scour} = &SetValues_OnOff($cval,1,1); #  Ensure $cval is properly set



    #============================================================================
    #  EMS_AUTORUN: SLEEP (integer seconds) 
    #============================================================================
    #
    $cval = (defined $cparms{SLEEP}[0] and $cparms{SLEEP}[0]) ?  $cparms{SLEEP}[0] : 600;
    $cval = 600 unless &Others::isInteger($cval) and $cval > 59 and $cval < 1801;

    $Files{sleep} = $cval;


    #============================================================================
    #  EMS_AUTORUN: ATTEMPTS (integer seconds) 
    #============================================================================
    #
    $cval = (defined $cparms{ATTEMPTS}[0] and $cparms{ATTEMPTS}[0]) ?  $cparms{ATTEMPTS}[0] : 3;
    $cval = 3 unless &Others::isInteger($cval) and $cval > 0 and $cval < 10;

    $Files{attempts} = $cval;


    #============================================================================
    #  EMS_AUTORUN: WAIT (integer seconds) 
    #============================================================================
    #
    $cval = (defined $cparms{WAIT}[0] and $cparms{WAIT}[0]) ?  $cparms{WAIT}[0] : 3600;
    $cval = 3600 unless &Others::isInteger($cval) and $cval > 300 and $cval < 7201;

    $Files{wait} = $cval;



    #============================================================================
    #  EMS_AUTOPOST: AUTOPOST_HOST - Hostname of system running autopost
    #  Note that we are cheating here because the ems_autopost.conf file 
    #  will be read again by the autopost routine. The problem is that the 
    #  host on which to run the autopost must be known beforehand. Maybe 
    #  AUTOPOST_HOST should be moved but I'm not in the mood.
    #============================================================================
    #
    $dval  = 'localhost';
    $cval  = (defined $cparms{AUTOPOST_HOST}[0] and $cparms{AUTOPOST_HOST}[0]) ?  $cparms{AUTOPOST_HOST}[0] : $dval;
    $cval  = $dval unless &Enet::isHostname($cval);
    $cval  = $dval if $cval =~ /^local/i;

    $Files{ahost} = $cval;



    #============================================================================
    #  Just some developer debug statements
    #============================================================================
    #
    if ($fdbg) {
        my %temp = &Others::ReadLocalConfiguration($Uauto{rtenv}{autoconf});
        &Ecomm::PrintMessage(0,12,255,1,0,'Parameter              Conf File                               UEMS');
        &Ecomm::PrintMessage(0,7,255,1,1,'-' x 80);
        foreach my $key (sort keys %temp) { 
            my $stemp  = @{$temp{$key}}  ? join ',' => @{$temp{$key}}  : ' '; chomp $stemp;
            my $sfiles = $Files{$key} ? $Files{$key} : ' '; chomp $sfiles;
            my $str = sprintf("%-16s    =  %-36s :  %-36s", $key,$stemp,$sfiles); 
            &Ecomm::PrintMessage(4,7,255,0,1,$str);
        }
        &Ecomm::PrintMessage(0,7,255,0,2,'-' x 80);
    }



return %Files;
}  



sub SetValues_OnOff {
#==================================================================================
#  Routine set the incoming valiable ($var) to a single ON (1) or OFF (0) 
#  value. Support for T|Fs & Y|Ns is provided for legacy reasons. It return an
#  array populated with $nvars values.
#==================================================================================
#
    my ($var, $def, $nvars) = @_;  $nvars = 1 unless $nvars;

    &Ecomm::PrintMessage(6,7,94,1,1,"Warning: Default value ($def) must be 0|1 in &Afiles::SetValues_OnOff") unless grep {/^$def$/} (0,1);

    for ($var) {
        $_ = 0 if /^0/ or /^F/i or /^N/i;
        $_ = 1 if /^1/ or /^T/i or /^Y/i;
        $_ = $def unless $_ == 1 or $_ == 0;
    }

return ($var) x $nvars;
}



sub DomainStartStop {
#==================================================================================
#  Routine to ensure proper formatting of the DOMAIN:START:STOP string used by
#  the DOMAINS parameters.
#==================================================================================
#
    my $passed = shift;  return '' unless defined $passed and length $passed;


    #  The format of the argument is DOM:START:STOP but we need to
    #  account for the use of commas (,) and semicolons (;) as separators. 
    #  Here the "@tmp" list is used to catch any extraneous values.
    #
    my $form = '';

    $passed =~ s/:|,|;|"|'/:/g;  #  Replace Separators with ":"
    $passed =~ s/[^\d|\:]//g;

    my ($dom,$start,$stop,@tmp) = split /:/ => $passed;

    $dom  = 1 unless $dom;
    $stop = 0 unless $stop;
    $start= 0 unless $start;

    $stop = 0  if ($stop  =~ /^\D/i or $stop  < 1 or $stop < $start);
    $start= 0  if ($start =~ /^\D/i or $start < 1 or ($stop and $start > $stop) );
    $dom  = 1  if ($dom   =~ /^\D/i or $dom <= 1);

    #  If domain = 1 then disregard
    #
    return  '' if $dom == 1;

    $stop = '' unless $stop;
    $start= '' unless $start;
    my $st= ($start and $stop) ? "$start:$stop" : $start ? $start : $stop ? ":$stop" : '';

    $form = $st ? "$dom:$st" : $dom;


return $form;
}



