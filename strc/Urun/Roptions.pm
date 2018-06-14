#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Roptions.pm
#
#  DESCRIPTION:  Roptions contains each of the primary routines used for the
#                reading and interpreting the many command line options and
#                flags passed to ems_run.
#
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Roptions;

use warnings;
use strict;
require 5.008;
use English;

use Ecomm;
use Ecore;
use Others;
use Rhelp;


sub RunOptions {
#==================================================================================
#  Front end to the GetRunOptions routine
#==================================================================================
#
      my %Options  = ();

      my $upref = shift;
      my %Urun  = %{$upref};

      return () unless %Options = &GetRunOptions();
      return () unless %Options = &SetRunOptionValues(\%Options);

      %{$Urun{options}} = %Options;
     
return %Urun;
}



sub GetRunOptions {
#==================================================================================
#  The GetRunOptions routine parses the flags and Option passed from the
#  command line to ems_run. Simple enough.
#==================================================================================
#
use Getopt::Long qw(:config pass_through);
use Time::Local;

    my %Option = ();

    #  Do an initial check of the Option and flags to look for obvious problems
    #
#   @ARGV = &CheckRunOption(@ARGV);

    GetOptions ( "h|help|?"         => sub {&Rhelp::RunHelpMe(@ARGV)},   #  Just what the doctor ordered

                 "clean|scour!"     => \$Option{SCOUR},
                 "debug:s"          => \$Option{DEBUG},

                 "levels:s"         => \$Option{LEVELS},    #  Specify the number of levels to use
                 "restart:s"        => \$Option{RESTART},   #  User-specified restart run with filename and interval
                 "dfi:s"            => \$Option{DFI},       #  Turn ON [OFF] the digital filter initialization for the simulation 

                 "rundir:s"         => \$Option{RUNDIR},    #  location of the domain directory

                 "interp"           => \$Option{INTERP},    #  Interpolate nested domain static fields from parent
                 "domains:s"        => \$Option{DOMAINS},   #  Process initialization files for domains 1 ... --domains #

                 "noreal"           => \$Option{NOREAL},    #  Do not run the WRF REAL program. Just the WRF model
                 "nowrf"            => \$Option{NOWRFM},    #  Do not start WRF run just run through REAL
                 "runinfo"          => \$Option{RUNINFO},   #  Print out information about the run
                 "autopost:s"       => \$Option{AUTOPOST},  #  Turn autopost processing ON
                 "ahost:s"          => \$Option{AHOST},     #  The host on which to run the autopost
                 "nudge:s"          => \$Option{NUDGE},     #  Turn ON spectral or grid nudging
                 "nudging:s"        => \$Option{NUDGE},     #  Same as above, only spelled different

                 "start|sdate:s"    => \$Option{SDATE},     #  Set the start time for the primary domain.
                 "length:s"         => \$Option{LENGTH},    #  Set the forecast run length to # [d|h|m|s].
               
               );  # &Rhelp::RunHelpMeError(@ARGV) if @ARGV;#  Should not get here but just in case


return %Option; 
}


sub SetRunOptionValues {
#==================================================================================
#  The SetRunOptionValues takes the option hash and gives them a value, whether 
#  they were  passed or not.
#==================================================================================
#
    my $oref   = shift;
    my %Option = %{$oref};

    #  --------------------------------- Attempt the configuration --------------------------------------------
    #
    #  Note that the order for some configurations is important!
    #
    $Option{SCOUR}        =  &RunOptionValue('scour'     ,$Option{SCOUR});
    $Option{DEBUG}        =  &RunOptionValue('debug'     ,$Option{DEBUG});
    $Option{LEVELS}       =  &RunOptionValue('levels'    ,$Option{LEVELS});  

    $Option{RESTART}      =  &RunOptionValue('restart'   ,$Option{RESTART});
    $Option{RUNDIR}       =  &RunOptionValue('rundir'    ,$Option{RUNDIR});
    $Option{INTERP}       =  &RunOptionValue('interp'    ,$Option{INTERP});
    $Option{DFI}          =  &RunOptionValue('dfi'       ,$Option{DFI});
    $Option{DOMAINS}      =  &RunOptionValue('domains'   ,$Option{DOMAINS});
    $Option{NOREAL}       =  &RunOptionValue('noreal'    ,$Option{NOREAL});
    $Option{NOWRFM}       =  &RunOptionValue('nowrfm'    ,$Option{NOWRFM});
    $Option{RUNINFO}      =  &RunOptionValue('runinfo'   ,$Option{RUNINFO});
    $Option{AUTOPOST}     =  &RunOptionValue('autopost'  ,$Option{AUTOPOST});
    $Option{AHOST}        =  &RunOptionValue('ahost'     ,$Option{AHOST});
    $Option{NUDGE}        =  &RunOptionValue('nudge'     ,$Option{NUDGE});

    $Option{LENGTH}       =  &RunOptionValue('length'    ,$Option{LENGTH});
    $Option{SDATE}        =  &RunOptionValue('sdate'     ,$Option{SDATE});    

    return () if $ENV{RMESG};


return %Option;
}


sub MatchRunOptions {
#=====================================================================================
#  This routine matched a passed flag to an actual option should the user have
#  used a partial flag name. This is necessary for the help routines.
#=====================================================================================
#
use List::Util 'first';

    my $flag = qw{};
    my %flags= ();

    my %opts = &Rhelp::DefineRunOptions();  #  Get options list

    #  Expand the --[no]flags into the negation and affirmation variants.
    #
    foreach (keys %opts) {s/\-\-//g; my $orig = $_; $flags{"no${_}"} = $orig if (s/\[no\]//g); $flags{$_} = $orig;}

    #  Do an initial run through of the argument list to make sure each --[flag] is valid .
    #
    my $passed = shift;

    $passed =~ s/\-//g;
    $passed =  lc $passed;   #  Make sure the flag is lower case
    $passed =~ s/s$//g;      #  Eliminate trailing 's'

    $flag = first {/^$passed/} keys %flags; $flag = "--$flags{$flag}" if $flag;


return $flag;
}


sub RunOptionValue {
#==================================================================================
#  This routine manages the configuration of each user option/flag.  It's basically
#  just an interface to the individual option configuration routines.
#==================================================================================
#
    my $flag = q{};
    my @args = ();

    ($flag, @args) = @_;

    my $subroutine = "&Option_${flag}(\@args)";

return eval $subroutine;
}


sub Option_autopost {
#==================================================================================
#  Flag to turn ON the concurrent post-processing of simulation output. Argument 
#  a list of domain IDs separated by a comma but anything will work.  Passing 
#  --autopost without an argument or an invalid argument turns ON all domains.
#==================================================================================
#
    my $passed  = shift;  return 0 unless defined $passed;
       $passed  = lc $passed;
       $passed  = '0:wrfout' unless $passed;
       $passed  =~ s/,+|;+/,/g;  #  Config_autopost will accept ; or , to separate domains -  use , for now
       $passed  =~ s/:+/:/g;     #  Separates domain:data:sets

    my @pargs  = split /,/ => $passed;

    return '0:wrfout' unless @pargs;
    return '0:wrfout' if grep {/^All|^Auto/i} @pargs;

return $passed;
}


sub Option_ahost {
#==================================================================================
#  The --ahost flag is passed by the UEMS AutoPost routine to specify the
#  system on which to start ems_autopost.pl. It Must be passed with the 
#  --autopost flag; otherwise an error will be generated.
#==================================================================================
#
    my $passed = shift;

return (defined $passed and $passed) ? $passed : 0;
}


sub Option_debug {
#==================================================================================
#  Define the value for the --debug flag. This flag may be an integer value of
#  between 0 and 9 or a character string, "real|wrfm".  The "real" string gets 
#  assigned a value of 10 while "wrfm" gets 11.
#==================================================================================
#
    my $passed = shift;

    return 0 unless defined $passed;
    return 1 if ! $passed;

    if (&Others::isInteger($passed)) {
        return 9 if $passed > 9;
        return 0 if $passed < 0;
        return $passed;
    }

    return -10 if $passed =~ /^rea/i;
    return -11 if $passed =~ /^wrf/i;

return 0;  #  Just in case - of what? I have no idea
}


sub Option_dfi {
#==================================================================================
#  Flag to to turn ON (--dfi) or OFF (--dfi 0) Digital Filter Initialization 
#  prior to the simulation.  Overrides the configuration file value.
#  
#  Values:   0 = --dfi not passed, 
#           -1 = --dfi 0 passed (turn OFF)
#        'DEF' = --dfi passed without arg, 
#      $passed = --dfi passed with arg
#==================================================================================
#
    my $passed = shift;

       return  0 unless defined $passed;
       return -1 if length $passed and !$passed;  #  For --dfi 0
       return 'DEF' unless $passed;               #  for --dfi

       $passed =~ s/;|,/:/g;
       $passed =~ s/:+/:/g;
       $passed = 'DEF' if $passed =~ /^:$/;
    
return $passed;
}


sub Option_domains {
#==================================================================================
#  Flag to specify the domains to be included in the simulation. The length of
#  integration for that domain may be included by appending a ":length", where
#  "length" includes integration length and time units.
#==================================================================================
#
    my %dhash = ();
    my $passed  = shift;

    return 0 unless defined $passed and $passed;

    #  Clean up the formatting of the string.
    #
    for ($passed) { s/,+|;+/;/g; s/:+/:/g; $_=lc $_; }

    foreach (split /;/ => $passed) {

        my ($dom, $len) = split /:/ => $_, 2; $len = 0 unless $len;

        unless ($dom =~ /^(\d+)$/) {
            my $mesg = "When passing \"--domains\", each domain is specified by the domain (integer) number (\"--domains 1,..,N\")";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,94,0,0,"Not an appropriate domain number ($dom):",$mesg);
            return 0;
        }
        $dom+=0;  next unless $dom > 0;
       
 
        if ($len) {
            my $val = ($len =~ /^(\d+)/)    ? $1 : 0;
            my $unt = ($len =~ /([a-z]+)$/) ? $1 : 0;
            my $vtu = ($unt =~ /^([dhms])/) ? $1 : 0;
            unless ($val and $unt) {
                my $miss = $val ? "time units appended to the integer length value (E.g., --domains  ${dom}:${val}h)" 
                                : "integer length of the simulation preceding the time units (E.g., --domains  ${dom}:3m)";

                my $mesg = "When passing \"--domains $dom:$len\", you must also include the $miss.";
                $ENV{RMESG} = &Ecomm::TextFormat(0,0,80,0,0,'Integration length incorrectly specified ("--domains"):',$mesg);
                return 0;
            }

            unless ($vtu) {
                my $mesg = "When passing \"--domains $dom:$len\", you must also include a valid unit of time, either \"d\" (days), ".
                           "\"h\" (hours), \"m\" (minutes), or \"s\" (seconds).\n\nI'm not quite sure how to interpret \"$len\".";
                $ENV{RMESG} = &Ecomm::TextFormat(0,0,80,0,0,'Integration length incorrectly specified ("--domains"):',$mesg);
            }

            #  Clean up the unit string to ensure there is just the single character
            #
            $vtu = substr $vtu, 0;
            $len = "$val$vtu";
        }
      
        if (defined $dhash{$dom}) {
            &Ecomm::PrintMessage(6,9,104,1,2,"Multiple domain $dom instances passed to \"--domain $passed\" - using \"$dhash{$dom}\".");
            next;
        }

        $dhash{$dom} = "$dom:$len";
     
    }
    $passed = %dhash ? join(',' , map { $dhash{$_} } sort {$a <=> $b} keys %dhash) : 0;


return $passed;
}


sub Option_interp {
#==================================================================================
#  Flag to specify that the static fields from nested (child) domains should
#  be interpolated from the courser resolution parent rather than from the 
#  grid spacing consistent dataset created when geogrid was run.
#==================================================================================
#
    my $passed = shift;

return (defined $passed and $passed) ? 1 : 0;
}


sub Option_length {
#==================================================================================
#  Flag to specify the length of the simulation.  A character indicating the 
#  time units is optional with the defaults being hours.
#==================================================================================
#
    my $passed  = shift || return 0;

    return 0 unless defined $passed and $passed; $passed = lc $passed;

    my $value = ($passed =~ /^(\d+)/)       ? $1 : 0;
    my $units = ($passed =~ /^\d+([a-z]+)/) ? $1 : 0;
    my $tu    = ($units  =~ /(^[dhms])/)    ? $1 : 0;

    unless ($value) {$ENV{RMESG} = &Ecomm::TextFormat(0,0,144,0,0,"Error \"--length\": Flag passed missing value - \"$passed\""); return '';}
    unless ($tu)    {$units ? $ENV{RMESG} = &Ecomm::TextFormat(0,0,144,0,0,"Time units for simulation length not properly specified ($units)")
                            : &Ecomm::PrintMessage(6,4,144,1,2,"Time units for primary domain simulation length not specified - Assuming ${value} hours");}
    $tu = 'h' unless $tu;

    $value+=0;
    $passed = "$value$tu";

return $passed;
}


sub Option_levels {
#==================================================================================
#  Flag to specify the number of levels to be included in the simulation.  If 
#  "--levels" is not passed the value is set to 0.
#==================================================================================
#
    my $passed = shift;

return (defined $passed and $passed) ? $passed : 0;
}


sub Option_noreal {
#==================================================================================
#  Flag to bypass the processing of WPS metgrid fields into WRF initial and
#  boundary condition datasets before running WRF.
#==================================================================================
#
    my $passed = shift;

return (defined $passed and $passed) ? 1 : 0;
}


sub Option_nowrfm {
#==================================================================================
#  Flag to only process WPS metgrid fields into WRF initial and boundary
#  condition dataset with WRF REAL and not continue with running the 
#  simulation.
#==================================================================================
#
    my $passed = shift;

return (defined $passed and $passed) ? 1 : 0;
}


sub Option_nudge {
#==================================================================================
#  The --nudge flag turns on 3D analysis or spectral nudging for the simulation.
#  Possible arguments are 0 (turn nudging OFF), 1 (analysis nudging), or
#  2 (spectral nudging). Passing --nudge without an argument causes the UEMS
#  to defer to the run_nudging.conf file for guidance. Passing anything else
#  gets a value of 3 and a good Ol' tongue lashing.
#
#  Let's Review:
#
#    *  not passed -> Return  0  (nudging off)
#    *  --nudge    -> Return -1  (defer to run_nudging.conf)
#    *  --nudge 0  -> Return  0  (nudging off - same as not passed)
#    *  --nudge 1  -> Return  1  (analysis nudging)
#    *  --nudge 2  -> Return  2  (spectral nudging).
#    *  --nudge <anything else> ->  Return 3 and a Good Ol' Tongue Lashing!
#==================================================================================
#
    my %dhash  = ();
    my $passed = shift; return 0 unless defined $passed;

    return -1 unless length $passed;  #  passed without argument - defer to run_nudging.conf
    return  3 unless grep {/^$passed$/} (0,1,2); 
    return  0 unless $passed;

return $passed; # Should be 1 or 2
}


sub Option_restart {
#==================================================================================
#  The --restart flag specified the restart date & time of simulation. The argument 
#  to --restart is a string YYYYMMDDHH although a WRF string such as
#  2016-12-27_18:00:00 is also valid. The routine output a string with the 
#  format of YYYYMMDDHHMNSS. 
#==================================================================================
#
    my $passed = shift; return 0 unless defined $passed;

    unless ($passed) {
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,144,0,0,"Missing argument to \"--restart YYYYMMDDHH\". See \"--help restart\" for additional information."); return 0;
    }


    if (length $passed < 10) {
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,144,0,0,"Error with \"--restart YYYYMMDDHH\":  Argument incorrect - $passed (What is that?)."); return 0;
    }


    my $restart = &Others::DateString2DateStringWRF(&Others::DateStringWRF2DateString($passed));


    if ($restart eq '0000-00-00_00:00:00') {
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,144,0,0,"Missing argument to \"--restart YYYYMMDDHH\". See \"--help restart\" for additional information."); return 0;
    }


return &Others::DateStringWRF2DateString($restart);
}

 
sub Option_rundir {
#==================================================================================
#  Define the value for RUNDIR, which is the name of the run-time domain 
#  directory to be used for the simulation. The argument to --rundir may 
#  or may not include the full path to the run-time domain. Only the directory
#  name is important and any path to the domain directory will be replaced with
#  $EMS_RUNS in the configuration module.
#==================================================================================
#
    my $passed = shift; 


    #  In this initial stage we only care if the name of a domain directory was passed;
    #  otherwise set to 0 and get out.  Further configuration will be done during the
    #  configuration module.
    #
    return 0 unless defined $passed and $passed;


    #   Make sure the user did not pass jibberish
    #
    return 0 if $passed =~ /^\.|\.$|;|=|\?|\]|\[|\(|\)/;


    #  Prune the domain directory from the full path. If only the directory
    #  was passed then it's still ok.
    #
    $passed = &Others::popit($passed);


return $passed ? "$ENV{EMS_RUN}/$passed" : 0;
}


sub Option_runinfo {
#==================================================================================
#  Flag to print out the current model configuration  and then exit
#==================================================================================
#
    my $passed = shift;

return (defined $passed and $passed) ? 1 : 0;
}


sub Option_scour {
#==================================================================================
#  By default the --scour flag is set to value of 2, which removes any residue
#  from previous runs but retains all the files created while running ems_prep.
#  If this is a restart or passing the --nowrf or --noreal flags then the
#  value is set to 1. Sometimes it is set to 0 but the actual configuration
#  is done in the configuration module and not here.
#==================================================================================
#
    my $passed = shift;

    return 2 unless defined $passed;  #  Default level 2 if --[no]scour not passed
    $passed = $passed ? 2 : 0;        #  Set to 2 fir --scour; otherwise 0 for --noscour 

return $passed;
}


sub Option_sdate {
#==================================================================================
#  The --sdate flag defines the start date & time of the simulation. The argument 
#  to --sdate is a string YYYYMMDDHH although a WRF string such as
#  2016-12-27_18:00:00 is also valid. The routine output a string with the 
#  format of YYYYMMDDHHMNSS.
#==================================================================================
#
    my $passed = shift; return 0 unless defined $passed;

    unless ($passed) {
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,144,0,0,"Missing argument to \"--sdate YYYYMMDDHH\". See \"--help sdate\" for additional information."); return 0;
    }


    if (length $passed < 10) {
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,144,0,0,"Error with \"--sdate YYYYMMDDHH\":  Argument incorrect - $passed (What is that?)."); return 0;
    }


    my $sdate = &Others::DateString2DateStringWRF(&Others::DateStringWRF2DateString($passed));


    if ($sdate eq '0000-00-00_00:00:00') {
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,144,0,0,"Missing argument to \"--sdate YYYYMMDDHH\". See \"--help sdate\" for additional information."); return 0;
    }


return &Others::DateStringWRF2DateString($sdate);
}


