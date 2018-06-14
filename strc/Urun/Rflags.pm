#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Rflags.pm
#
#  DESCRIPTION:  Rflags contains each of the primary routines used for the
#                final configuration of ems_run. It's the least elegant of
#                the ems_post modules simply because there is a lot of sausage
#                making going on.
#
#                A lot of sausage making
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Rflags;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Flags %Urun);


sub RunFlagConfiguration {
#==================================================================================
#  The RunFlagConfiguration manages the final configuration for and flags
#  passed on the command line. 
#==================================================================================
#
    %Flags = ();

    my $upref = shift; %Urun = %{$upref};

    #  ----------------- The important parameters ---------------------------------
    #  First things first - Note that the order of configuration is important
    #  as some parameters are needed in the configuration of others.  Any 
    #  information that needs to be saved is held in the %Flags hash, which
    #  is only available within this module.
    #------------------------------------------------------------------------------
    #
    $Flags{debug}        =  &Flag_debug();     return () if $ENV{RMESG};
    $Flags{emscwd}       =  &Flag_emscwd();    return () if $ENV{RMESG};
    $Flags{rundir}       =  &Flag_rundir();    return () if $ENV{RMESG};

    $Flags{benchmark}    =  &Flag_benchmark(); return () if $ENV{RMESG};

    $Flags{domains}      =  &Flag_domains();   return () if $ENV{RMESG};
    $Flags{length}       =  &Flag_length();    return () if $ENV{RMESG};
    $Flags{dfi}          =  &Flag_dfi();       return () if $ENV{RMESG};
    $Flags{nudge}        =  &Flag_nudge();     return () if $ENV{RMESG};
    $Flags{levels}       =  &Flag_levels();    return () if $ENV{RMESG};

    $Flags{autopost}     =  &Flag_autopost();  return () if $ENV{RMESG};
    $Flags{ahost}        =  &Flag_ahost();     return () if $ENV{RMESG};


    #  ----------------- Attempt the configuration --------------------------------
    #  The variables below do not require any additional configuration beyond
    #  what was completed in the options module. Should a variable need 
    #  additional attention in the future a routine can be added.
    #------------------------------------------------------------------------------
    #
    $Flags{noreal}       =  &Flag_passvalue('NOREAL');
    $Flags{nowrfm}       =  &Flag_passvalue('NOWRFM');
    $Flags{sdate}        =  &Flag_passvalue('SDATE');
    $Flags{interp}       =  &Flag_passvalue('INTERP');
    $Flags{restart}      =  &Flag_passvalue('RESTART');  #  Will need to be fully implemented
    $Flags{runinfo}      =  &Flag_passvalue('RUNINFO');

    #  ---------------------- Dependent Parameters --------------------------------
    #
    #------------------------------------------------------------------------------
    #
    $Flags{scour}        =  &Flag_scour();


    #------------------------------------------------------------------------------
    #  Debug information if the --debug <value> is greater than 0
    #------------------------------------------------------------------------------
    #
    &ConfigDebugInformation() if $Flags{debug} > 0;



return %Flags;  
}



sub Flag_emscwd {
#==================================================================================
#  Determine whether ems_run was run from a valid domain directory, in which
#  case the information will be assigned to the --rundir flag argument, 
#  overriding existing values.
#==================================================================================
#
use Cwd;

    my $emscwd = 0;

    $emscwd = $Urun{emsenv}{cwd} if -e "$Urun{emsenv}{cwd}/static" and
                                    -d "$Urun{emsenv}{cwd}/static" and
                                    -e "$Urun{emsenv}{cwd}/static/namelist.wps";

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

    my $mesg   = qw{};
    my $rundir = qw{};
    my $emsrun = Cwd::realpath($Urun{emsenv}{cwd});
    my $passed = $Urun{options}{RUNDIR};



    #    1. ems_run is run from and existing domain directory (most common) and
    #       overrides any argument passed to --rundir
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

        $mesg = "Something is not quite right in that $passed does not exist. You want me to work my ".
                "magic but I have nothing with which to work. Besides being good-looking, you are ".
                "exceptional at what you do, so work with me and we can shine together!";

        unless (-e $passed) {
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Shine on You Crazy Diamond!',$mesg);
            return 0;
        }


        $mesg = "Something is not quite right in that $passed does not appear to be a proper domain ".
                "directory. Maybe you intended to pass the \"--rundir <domain>\" flag or there is a ".
                "typo in your domain path, but I am unable to continue our journey until this ".
                "problem is addressed, and not by me!";

        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'User Faux Paux!',$mesg); return 0;

    }
                

return Cwd::realpath($rundir);
}



sub Flag_benchmark {
#==================================================================================
#  Configure the $Flags{benchmark} parameter,  which is determines whether the
#  target directory is the benchmark case directory, in which case there is a
#  limit to what can be done with ems_run.
#==================================================================================
#
    my $benchmark = (-e "$Flags{rundir}/static/.benchmark") ? 1 : 0;


return $benchmark;
}



sub Flag_dfi {
#==================================================================================
#  Final configuration for the --dfi flag. At this point the user configuration
#  is not known so all that is needed here is to assign the default values if the
#  user had passed --dfi without any arguments. Note that the default value
#  of 3:7 (DFI_OPT:DFI_NFILTER) is hardcoded here because there is no better
#  place to set the value. Also note that "-1" turns OFF DFI (--dfi 0)
#==================================================================================
#  
    my $dfi = $Urun{options}{DFI};
       $dfi =~ s/DEF/3:7/g;  #  Note that '3:7' defines the default

       if ($dfi =~ /[^0-9-:]/) {
           my $mesg = "The format of arguments passed to the \"--dfi\" flag is DFI_OPT:DFI_NFILTER, ".
                      "where DFI_OPT is the DFI option number and DFI_NFILTER is the filter number. ".
                      "What you passed was \"--dfi $dfi\", which will get you nowhere.";
           $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'The DFI gods are dissapointed in you:',$mesg);
       }


return $dfi;
}



sub Flag_nudge {
#==================================================================================
#  Normally this routine would just pass the $Urun{options}{NUDGE} value 
#  through to $Flags{nudge}; however, we must account for a bad --nudge value.
#==================================================================================
# 
    my $mesg  = qw{};
    my $nudge = $Urun{options}{NUDGE};

    # Good Ol' Tongue Lashing! (See &Option_nudge
    #
    $mesg = "What we've got here is failure to communicate. Some modelers you just can't reach. So you ".
            "get the same message that everyone else gets, which is apparently the way you want it.\n\nI don't like it any ".
            "more than you.";
    $ENV{RMESG} = &Ecomm::TextFormat(0,0,84,0,0,'Invalid argument to --nudge [1|2]',$mesg) if $nudge == 3;


return $nudge;
}


sub Flag_passvalue {
#==================================================================================
#  Simply transfer the value from the OPTIONS hash for the final configuration
#==================================================================================
#
    my $field = shift;


return $Urun{options}{$field};
}



sub Flag_domains {
#==================================================================================
#  Much of the error checking for the --domains flag has already been done 
#  in the GetOptions processing; however,  we need to make sure that the 
#  primary domain (1) has been included. Note that this step is not the 
#  final word in configuration of the simulation length since the period
#  over which the processed initialization data is still not known. This
#  step is managed in the "simulation configuration"  routines.
#==================================================================================
#
    my $domains = $Urun{options}{DOMAINS};
    my $length  = $Urun{options}{LENGTH};
    my %dhash   = map {split(/:/, $_) } split(/,/, $domains) if $domains;


    #--------------------------------------------------------------------------
    #  Check whether the primary domain was included and if the --length flag
    #  was passed. The argument to the --length flag overrides any primary
    #  domain simulation length passed as an argument to --domains.
    #--------------------------------------------------------------------------
    #
    $dhash{1} = $length if $length;
    $dhash{1} = 0 unless defined $dhash{1} and $dhash{1};

    foreach (values %dhash) {

        my $secs  = 0;
        my $value = ($_ =~ /^(\d+)/)       ? $1 : 0;
        my $units = ($_ =~ /([d|h|m|s])$/) ? $1 : 0;

        $secs = $value*86400 if $units =~ /^d/;
        $secs = $value*3600  if $units =~ /^h/;
        $secs = $value*60    if $units =~ /^m/;
        $secs = $value       if $units =~ /^s/;

        $_    = $secs;
    }

    foreach (keys %dhash) {$dhash{$_} = "$_:$dhash{$_}";}

    $domains = join(',' , map { $dhash{$_} } sort {$a <=> $b} keys %dhash);


return $domains;
}



sub Flag_length {
#==================================================================================
#  Simply assign a value to $Flags{length} (seconds).  The value to be assigned 
#  was determined in Flag_domains as the simulation length for the primary
#  domain (1). Now simply pick it off. Note that the final simulation length 
#  value is subject to change in &Flag_timing;
#==================================================================================
#
    my ($d1, $ds)   = split /,/ => $Flags{domains};  # $d1 holds the simulation length
    my ($dom, $len) = split /:/ => $d1; $len = 0 unless $len;

    #  Check whether this is a benchmark simulation and apply the 30hr maximum
    #  simulation length restriction.
    #
    my $max = 30*3600; # 30hr maximum

    $len = $max if $Flags{benchmark} and $len > $max;


return $len ? $len : 0;
}



sub Flag_scour {
#==================================================================================
#  Passing the --[no]scour flag defined the amount of directory cleaning to
#  perform prior running a simulation.
#==================================================================================
#
    my $scour = $Urun{options}{SCOUR} || return 1;
       $scour = 1 if $Flags{noreal};

return $scour;
}



sub Flag_levels {
#==================================================================================
#  Passing the --levels flag bypasses the LEVELS parameter in the run_levels.conf
#  file. The same strict controls must be placed on the flag value as for the 
#  configuration file setting. (Ha, Ha).
#==================================================================================
#
    my $passed  = $Urun{options}{LEVELS} || return 0;
    return 0 unless $passed;

    my @levels = split /,/ => $passed;
    my $level  = @levels > 1 ? @levels : $levels[0];

    $level     = (&Others::isNumber($level) and $level > 0) ? int $level : (0);

    @levels    = &Others::rmdups(@levels); @levels = sort {$b <=> $a} @levels;

    $level     = join ',' => @levels if $levels[0] == 1.0 and $levels[-1] == 0.0;

    unless ($level) {
        my $mesg = "It appears you are having some difficulty with the \"--levels\" flag because ".
                   "you passed \"--levels $passed\", which failed the strict quality controls ".
                   "that have been put in place.";
         $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'About that --levels flag',$mesg);
    }

return $level;
}


sub Flag_debug {
#==================================================================================
#  Passing the --debug flag sets the level of verbosity when attempting to figure
#  out why the UEMS is behaving so badly. It's unlikely to reveal much and will
#  leave you with no choice but to BLAME THE PARENTS!
#==================================================================================
#
    my $debug = $Urun{options}{DEBUG} || return 0;

return $debug;
}



sub Flag_autopost {
#==================================================================================
#  Passing the "--autopost" flag initiates concurrent post processing of the simulation
#  output files, i.e, while the model is still running. This option is typically activated
#  through the ems_autorun routine with the AUTOPOST parameter in ems_autorun.conf;
#  however, you can play with it by passing the "--autopost" option to ems_run.
#   
#  The argument to "--autopost" specifies the domains for which you want to turn autopost
#  processing ON and the output datasets to process. Currently, there are two model output
#  datasets available for processing, primary and auxiliary, which are specified as
#  "primary", and "auxiliary" respectively. One or both of these datasets, along with a
#  domain ID, may be included as part of a "rules group" is passed as an argument to
#  "--autopost". The format of the argument string is:
#
#    % ems_run --autopost ID1:ds1:ds2,ID2:ds1:ds2,...,IDN:ds1:ds2
#   
#  where id# the domain ID to which apply the rules, and ds1 & ds2 are placeholders the
#  "primary" and/or "auxhist" datasets, i.e, the "rules". Specifying rules for multiple
#  domains is done by separating individual rule groups with a comma. A default rule group
#  may also be included by excluding the domain ID. This default will be applied to any
#  domain for which concurrent post processing is turned ON that does not have a rule
#  group.  In the absence of a specified default rule group only the "primary" dataset
#  ("wrfout*" for WRF) will be processed. Passing the "--autopost" flag without an
#  argument turns concurrent post processing of the primary output files ON for all
#  domains included in the simulation.
#==================================================================================
#
   my %types = ();
   my @list  = ();

   my $autopost  = $Urun{options}{AUTOPOST};  return 0 unless defined $autopost and $autopost;


   foreach my $d (split /,|;/ => $autopost) { #  Split between domains

       my $dom = 0;  #  Domain 0 is the default & indicates "all AP domains"
       my @dst = ();

       foreach (split /:/ => $d) {
           $dom = $1               if /(\d+)/;      #  Capture the domain number
           push @dst => 'wrfout'   if /^wrf|^pri/i; #  Capture wrfout dataset
           push @dst => 'auxhist1' if /^aux/i;      #  Capture auxiliary dataset
       }
       $dom += 0;
       @dst = reverse sort &Others::rmdups(@dst);
       @dst = qw(0) unless @dst; #  Needed for map in &ConfigureAutopost

       @{$types{$dom}} = @dst unless defined $types{$dom};  #  Only use 1st entry
   }
   @{$types{0}} = qw(wrfout) unless defined $types{0};

   foreach my $dom (sort {$a <=> $b} keys %types) {
       my $dsl = join ':' => ($dom, @{$types{$dom}});
       push @list => $dsl;
   }
   $autopost  = @list ? join ',' => @list : 0;


return $autopost;
}


sub Flag_ahost {
#==================================================================================
#  Specifies the name of the system on which to initiate ems_autopost.pl
#  Testing the viability of the system will occur later.
#==================================================================================
#
    my $ahost  = $Urun{options}{AHOST}  ? $Urun{options}{AHOST} : '';
       $ahost  = '' unless $Flags{autopost};
       $ahost  = 'localhost' if $ahost =~ /^local/i;

    if ($Flags{autopost} and ! $ahost) {
        my $mesg = "The UEMS Oligarchs recognize your display of \"spunk\" by playing with the UEMS Autopost ".
                   "feature from the command line, but if there is one thing that the Oligarchs hate, it's SPUNK!\n\n".
                   "If you insist upon passing the \"--autopost\" flag, you must also include \"--ahost HOSTNAME\" ".
                   "to specify the system on which to start the ems_autopost.pl routine; otherwise, you are just ".
                   "wasting our time.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'This behavior is frowned upon:',$mesg);
    }

return $ahost;
}


sub ConfigDebugInformation {
#==============================================================================
#  Debug information if the --debug <value> is greater than 0
#==============================================================================
#
    &Ecomm::PrintMessage(0,11+$Urun{arf},94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,13+$Urun{arf},255,1,1,'&RunFlagConfiguration - Final command-line flag values:');
    &Ecomm::PrintMessage(0,16+$Urun{arf},255,1,2,'Note: Some values have preset defaults');
    &Ecomm::PrintMessage(0,18+$Urun{arf},255,0,1,sprintf('--%-10s = %s',$_,$Flags{$_})) foreach sort keys %Flags;
    &Ecomm::PrintMessage(0,11+$Urun{arf},94,0,2,'=' x 72);

return;
}



