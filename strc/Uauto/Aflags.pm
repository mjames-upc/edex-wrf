#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Aflags.pm
#
#  DESCRIPTION:  Aflags contains each of the primary routines used for the
#                final configuration of ems_autorun. It's the least elegant
#                of the ems_autorun modules simply because there is a lot of 
#                sausage making going on.
#
#                A lot of sausage making
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Aflags;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Flags %Uauto);


sub AutoFlagConfiguration {
#==================================================================================
#  &AutoFlagConfiguration manages the final configuration for command-line flags.
#==================================================================================
#   
    %Flags    = ();

    my $upref = shift; %Uauto = %{$upref};

    #  ----------------- The important parameters ---------------------------------
    #  First things first - Note that the order of configuration is important as
    #  some parameters are needed in the configuration of others. Any information
    #  that needs to be saved is held in the %Flags hash, which is only available
    #  within this module. The environment variable $ENV{AMESG} is used as an
    #  indicator of failure resulting in an empty hash to be returned.
    #------------------------------------------------------------------------------
    #
    $Flags{debug}        =  &Flag_debug();    return () if $ENV{AMESG};
    $Flags{emscwd}       =  &Flag_emscwd();   return () if $ENV{AMESG}; 
    $Flags{rundir}       =  &Flag_rundir();   return () if $ENV{AMESG};

    $Flags{length}       =  &Flag_length();   return () if $ENV{AMESG};
    $Flags{emspost}      =  &Flag_emspost();  return () if $ENV{AMESG};
    $Flags{autopost}     =  &Flag_autopost(); return () if $ENV{AMESG};

    #  ----------------- Attempt the configuration --------------------------------
    #  The variables below do not require any additional configuration beyond
    #  what was completed in the options module. Should a variable need 
    #  additional attention in the future a routine can be added.
    #------------------------------------------------------------------------------
    #
    $Flags{rdate}        =  &Flag_passvalue('rdate');
    $Flags{rcycle}       =  &Flag_passvalue('rcycle');
    $Flags{rdset}        =  &Flag_passvalue('rdset');
    $Flags{scour}        =  &Flag_passvalue('scour');
    $Flags{nudging}      =  &Flag_passvalue('nudging');
    $Flags{nolock}       =  &Flag_passvalue('nolock');
    $Flags{domains}      =  &Flag_passvalue('domains');
    $Flags{sfc}          =  &Flag_passvalue('sfc');
    $Flags{lsm}          =  &Flag_passvalue('lsm');


    #------------------------------------------------------------------------------
    #  Debug information if the --debug <value> is greater than 0
    #------------------------------------------------------------------------------
    #
    &FlagsDebugInformation() if $Flags{debug} > 0;


return %Flags;  
}



sub Flag_emscwd {
#==================================================================================
#  Determine whether ems_autorun was run from a valid domain directory, in which
#  case the information will be assigned to the --rundir flag argument, 
#  overriding existing values.
#==================================================================================
#
use Cwd;

    my $emscwd = 0;

    $emscwd = $Uauto{emsenv}{cwd} if -e "$Uauto{emsenv}{cwd}/static" and
                                     -d "$Uauto{emsenv}{cwd}/static" and
                                     -e "$Uauto{emsenv}{cwd}/static/namelist.wps";

    $emscwd = Cwd::realpath($emscwd) if $emscwd;


return $emscwd;
}



sub Flag_rundir {
#==================================================================================
#  Define the value for RUNDIR, which is the full path to the domain directory
#  that is being used for the simulation. 
#==================================================================================
#
use Cwd;

    my $rundir = qw{};
    my $emsrun = Cwd::realpath($Uauto{emsenv}{cwd});
    my $passed = $Uauto{aflags}{RUNDIR};


    #  If ems_autorun is run from and existing domain directory (most common) and
    #  overrides any argument passed to --rundir
    #
    return $Flags{emscwd} if $Flags{emscwd};

   
    #  At this point $passed contains the name of a domain directory that should reside
    #  under $EMS_RUN.  Make sure it exists and is valid.
    #
    $passed = $emsrun unless $passed;


    $rundir = $passed  if -e "$passed/static" and
                          -d "$passed/static" and
                          -e "$passed/static/namelist.wps";


    unless ($rundir) {

        my $mesgA = "Something is not quite right in that $passed does not exist. You want me to work my ".
                    "magic but I have nothing with which to work. Besides being good-looking, you are ".
                    "exceptional at what you do, so work with me so we can shine together!";

        my $mesgB = "Something is not quite right in that $passed does not appear to be a proper domain ".
                    "directory. Maybe you intended to pass the \"--rundir <domain>\" flag or there is a ".
                    "typo in your domain path, but I am unable to continue our journey until this ".
                    "problem is addressed, and not by me!";

        $ENV{AMESG} = -e $passed ? &Ecomm::TextFormat(0,0,88,0,0,"Shine on You Crazy Diamond!",$mesgA)
                                 : &Ecomm::TextFormat(0,0,88,0,0,'User Faux Paux!',$mesgB);
        return;
    }
                

return Cwd::realpath($rundir);
}



sub Flag_length {
#==================================================================================
#  Conduct some simple checks to ensure that the argument passed to --length 
#  is actually viable.
#==================================================================================
#
    my $length = $Uauto{aflags}{LENGTH} || return 0;

    unless (&Others::isInteger($length)) {
        my $mesg = "The argument to the \"--length\" flag must be an integer specifying the simulation ".
                   "length, in hours, for the primary domain.  You seem to have missing that small ".
                   "requirement when you passed:\n\n".
                   "  %  ems_autorun --length $length\n\n".
                   "Let's go!  Accomplish your mission!";
        $ENV{AMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Mission NOT accomplished!',$mesg);
        return;
    }


return $length;
}



sub Flag_debug {
#==================================================================================
#  Passing the --debug flag sets the level of verbosity when attempting to figure
#  out why the UEMS is behaving so badly. It's unlikely to reveal much and will
#  leave you with no choice but to BLAME THE PARENTS!
#==================================================================================
#
    my $debug = $Uauto{aflags}{DEBUG} || return 0;

return $debug;
}



sub Flag_autopost {
#==================================================================================
#  Further refine the arguments to the --autopost flag. There isn't a whole
#  lot that we can do yet because the flag values must be reconciled with
#  the AUTOPOST configuration file parameter.  For now make sure values are
#  in lower case.  Return values include:
#
#    0        --autopost not passed 
#   Off       --autopost 0 passed (turn OFF) 
#   0:primary - Process default autopost data type(s) for ALL domains
#   #:datatype - specified dataset type for each domain
#==================================================================================
#
    my $autopost = $Uauto{aflags}{AUTOPOST} || return 0;
       $autopost = lc $autopost;

    return 'off'       if $autopost =~ /off/; #  Turn autopost OFF
    return '0:primary' if $autopost =~ /^auto/;

return $autopost;
}



sub Flag_emspost {
#==================================================================================
#  Further refine the arguments to the --emspost flag. There isn't a whole
#  lot that we can do yet because the flag values must be reconciled with
#  the EMSPOST configuration file parameter.  For now make sure values are
#  in lower case.  Return values include:
#
#    0         --emspost not passed 
#   Off        --emspost  0  passed (turn OFF) 
#   0:primary  - Process default emspost data type(s) for ALL domains
#   #:datatype - Specified dataset type for each domain
#==================================================================================
#
    my $emspost = $Uauto{aflags}{EMSPOST} || return 0;
       $emspost = lc $emspost;

    return 'off'       if $emspost =~ /off/; #  Turn emspost OFF
    return '0:primary' if $emspost =~ /^auto/;

return $emspost;
}



sub Flag_passvalue {
#==================================================================================
#  Simply transfer the value from the OPTIONS hash for the final configuration
#==================================================================================
#
    my $field = shift;

return $Uauto{aflags}{uc $field};
}



sub FlagsDebugInformation {
#==============================================================================
#  Debug information if the --debug <value> is greater than 0
#==============================================================================
#
    &Ecomm::PrintMessage(0,9,94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,9,255,1,1,'&AutoFlagConfiguration - Final command-line flag values:');
    &Ecomm::PrintMessage(0,14,255,1,2,'Note: Some values have preset defaults');
    &Ecomm::PrintMessage(0,16,255,0,1,sprintf('--%-10s = %s',$_,$Flags{$_})) foreach sort keys %Flags;
    &Ecomm::PrintMessage(0,9,94,0,2,'=' x 72);

return;
}



