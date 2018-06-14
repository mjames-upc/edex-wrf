#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Oflags.pm
#
#  DESCRIPTION:  Oflags contains each of the primary routines used for the
#                final configuration of ems_post. It's the least elegant of
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
package Oflags;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Flags %Upost);


sub PostFlagConfiguration {
#==================================================================================
#  &PostFlagConfiguration manages the final configuration for command-line flags.
#==================================================================================
#   
    %Flags    = ();

    my $upref = shift; %Upost = %{$upref};


    #  ----------------- The important parameters ---------------------------------
    #  First things first - Note that the order of configuration is important
    #  as some parameters are needed in the configuration of others.  Any 
    #  information that needs to be saved is held in the %Flags hash, which
    #  is only available within this module.
    #------------------------------------------------------------------------------
    #
    $Flags{debug}    =  &Flag_debug();    return () if $ENV{OMESG};
    $Flags{emscwd}   =  &Flag_emscwd();   return () if $ENV{OMESG};
    $Flags{rundir}   =  &Flag_rundir();   return () if $ENV{OMESG};
    $Flags{noexport} =  &Flag_noexport(); return () if $ENV{OMESG};
    $Flags{autoupp}  =  &Flag_autoupp();  return () if $ENV{OMESG};


    #  ----------------- Attempt the configuration --------------------------------
    #  The variables below do not require any additional configuration beyond
    #  what was completed in the options module. Should a variable need 
    #  additional attention in the future a routine can be added.
    #------------------------------------------------------------------------------
    #
    $Flags{scour}    =  &Flag_passvalue('scour');
    $Flags{index}    =  &Flag_passvalue('index');

    $Flags{noupp}    =  &Flag_passvalue('noupp');
    $Flags{summary}  =  &Flag_passvalue('summary');
    $Flags{info}     =  &Flag_passvalue('info');

    $Flags{afwa}     =  &Flag_passvalue('afwa');
    $Flags{auxhist}  =  &Flag_passvalue('auxhist');
    $Flags{wrfout}   =  &Flag_passvalue('wrfout');

    #------------------------------------------------------------------------------
    #  The $Flags{domains} value must include any domains passed via the 
    #  --autopost & --emspost flags so they must be processed first.
    #------------------------------------------------------------------------------
    #   
    $Flags{autopost} =  &Flag_autopost(); 
    $Flags{emspost}  =  &Flag_emspost(); 

    $Flags{domains}  =  &Flag_domains();

    $Flags{ncpus}    =  &Flag_ncpus();     return () if $ENV{OMESG};

    
    #------------------------------------------------------------------------------
    #  GRIB related flags: Note that --[no]gempak and --[no]grads must be set
    #  after --nogrib because passing because passing --nogrib turns OFF all
    #  secondary formats but --grib is turned ON if --gempak or --grads is
    #  passed without --nogrib.
    #------------------------------------------------------------------------------
    #
    $Flags{nogrib}   =  &Flag_passvalue('nogrib');

    $Flags{gempak}   =  &Flag_gempak();    return () if $ENV{OMESG};
    $Flags{grads}    =  &Flag_grads();     return () if $ENV{OMESG};

    $Flags{grib}     =  &Flag_passvalue('grib');
    $Flags{grib}     =  &Flag_grib();      return () if $ENV{OMESG};


    #------------------------------------------------------------------------------
    #  BUFR related flags: Note that --[no]gemsnd and --[no]bufkit must be set
    #  after --[no]bufr because passing because passing --nobufr turns OFF all
    #  secondary formats but --bufr is turned ON if --bufkit or --gemsnd is
    #  passed without --nobufr.
    #------------------------------------------------------------------------------
    #
    $Flags{nobufr} =  &Flag_passvalue('nobufr');

    $Flags{gemsnd} =  &Flag_gemsnd();    return () if $ENV{OMESG}; #  Must come between Flags{nobufr} and Flags{bufr}
    $Flags{bufkit} =  &Flag_bufkit();    return () if $ENV{OMESG}; #  Must come between Flags{nobufr} and Flags{bufr}

    $Flags{bufr}   =  &Flag_passvalue('bufr');
    $Flags{bufr}   =  &Flag_bufr();      return () if $ENV{OMESG};

    $Flags{bfinfo} =  &Flag_passvalue('bfinfo');


    #------------------------------------------------------------------------------
    #  Debug information if the --debug <value> is greater than 0
    #------------------------------------------------------------------------------
    #
    &FlagsDebugInformation() if $Flags{debug} > 0;



return %Flags;  
}


sub Flag_emscwd {
#==================================================================================
#  Determine whether ems_post was run from a valid domain directory, in which
#  case the information will be assigned to the --rundir flag argument, 
#  overriding existing values.
#==================================================================================
#
use Cwd;

    my $emscwd = 0;

    $emscwd = $Upost{emsenv}{cwd} if -e "$Upost{emsenv}{cwd}/static" and
                                     -d "$Upost{emsenv}{cwd}/static" and
                                     -e "$Upost{emsenv}{cwd}/static/namelist.wrfm";

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
    my $emsrun = Cwd::realpath($Upost{emsenv}{cwd});
    my $passed = $Upost{clflags}{RUNDIR};

    #  If ems_post is run from and existing domain directory (most common) and
    #  overrides any argument passed to --rundir
    #
    return $Flags{emscwd} if $Flags{emscwd};

   
    
    #  I believe the following redundant but remains here as a precaution to prevent
    #  something of which I can not think about at the moment.
    #
    $passed = $emsrun unless $passed;


    #  At this point $passed contains the name of a domain directory that should reside
    #  under $EMS_RUN.  Make sure it exists and is valid.
    #
    $passed = $emsrun unless $passed;


    $rundir = $passed  if -e "$passed/static" and
                          -d "$passed/static" and
                          -e "$passed/static/namelist.wps";


    unless ($rundir) {

        unless (-e $passed) {
            $mesg = "Something is not quite right because $passed does not exist. You want me to work my ".
                    "magic but I have nothing with which to work. Besides being good-looking, you are ".
                    "exceptional at what you do, so work with me so we can shine together!";
    
            $ENV{OMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Shine on You Crazy Diamond!',$mesg);
            return;
        }


        $mesg = "Something is not quite right because $passed does not appear to be a proper domain ".
                "directory. Maybe you intended to pass the \"--rundir <domain>\" flag or there is a ".
                "typo in your domain path, but I am unable to continue our journey until this ".
                "problem is addressed, and not by me!";

        $ENV{OMESG} = &Ecomm::TextFormat(0,0,88,0,0,'User Faux Paux!',$mesg);
        return;
    }
                

return Cwd::realpath($rundir);
}


sub Flag_grib {
#==================================================================================
#  Complete the final configuration of the --grib flag by combining the values
#  from $Flags{grib}, $Flags{nogrib}, $Flags{gempak}, and $Flags{grads}. Upon exit, 
#  the $Flags{grib} value will be be either:
#
#      -1 - grib file processing OFF (--nogrib passed)
#       1 or FREQ:START:END - grib file processing ON (--grib, or --grads, or --gempak)
#       0 - neither --nogrib nor --grib passed
#==================================================================================
#
    my $grib = 0;
       $grib = 1 if $Flags{gempak} == 1;
       $grib = 1 if $Flags{grads}  == 1;
       $grib = $Flags{grib} if $Flags{grib}; #  Value will be either 0 (not passed), 1 (--grib), or string
       $grib = -1 if $Flags{nogrib}; #  If --nogrib passed

return $grib;
}


sub Flag_gempak {
#==================================================================================
#  Complete the final configuration of the --gempak flag by combining the values
#  from $Flags{nogrib} and $Upost{clflags}{GEMPAK}. The return value should be
#  either:
#
#      -1 - gempak processing explicitly turned OFF (--nogempak passed)
#       1 - gempak processing explicitly turned ON  (--gempak without --nogrib)
#       0 - no gempak related flag passed or --nogrib passed
#==================================================================================
#
    my $gempak = $Upost{clflags}{GEMPAK};  #  Value will be either 1 (--gempak passed), 
                                              #  -1 (--nogempak passed), or 0 (neither passed)
       $gempak = 0 if $Flags{nogrib};


return $gempak;
}


sub Flag_grads {
#==================================================================================
#  Complete the final configuration of the --grads flag by combining the values
#  from $Flags{nogrib} and $Upost{clflags}{GRADS}. The return value should be
#  either:
#
#      -1 - grads processing explicitly turned OFF (--nograds passed)
#       1 - grads processing explicitly turned ON  (--grads without --nogrib)
#       0 - no grads related flag passed or --nogrib passed
#==================================================================================
#
    my $grads = $Upost{clflags}{GRADS};  #  Value will be either 1 (--grads passed), 
                                            #  -1 (--nograds passed), or 0 (neither passed)
       $grads = 0 if $Flags{nogrib};


return $grads;
}


sub Flag_bufr {
#==================================================================================
#  Complete the final configuration of the --bufr flag by combining the values
#  from $Flags{bufr}, $Flags{nobufr}, $Flags{gemsnd}, and $Flags{bufkit}. Upon exit, 
#  the $Flags{bufr} value will be be either:
#
#      -1 - bufr OFF (--nobufr passed)
#       1 or FREQ:START:END - bufr ON (--bufr, or --bufkit, or --gemsnd)
#       0 - neither --nobufr nor --bufr passed
#==================================================================================
#
    my $bufr = 0;
       $bufr = 1 if $Flags{gemsnd} == 1;
       $bufr = 1 if $Flags{bufkit} == 1;
       $bufr = $Flags{bufr} if $Flags{bufr}; #  Value will be either 0 (not passed), 1 (--bufr), or string
       $bufr = -1 if $Flags{nobufr}; #  Only care if --nobufr passed

return $bufr;
}


sub Flag_gemsnd {
#==================================================================================
#  Complete the final configuration of the --gemsnd flag by combining the values
#  from $Flags{nobufr} and $Upost{clflags}{GEMSND}. The return value should be
#  either:
#
#      -1 - gemsnd processing explicitly turned OFF (--nogemsnd passed)
#       1 - gemsnd processing explicitly turned ON  (--gemsnd without --nobufr)
#       0 - no gemsnd related flag passed or --nobufr passed
#==================================================================================
#
    my $gemsnd = $Upost{clflags}{GEMSND};  #  Value will be either 1 (--gemsnd passed), 
                                              #  -1 (--nogemsnd passed), or 0 (neither passed)
       $gemsnd = 0 if $Flags{nobufr};


return $gemsnd;
}


sub Flag_bufkit {
#==================================================================================
#  Complete the final configuration of the --bufkit flag by combining the values
#  from $Flags{nobufr} and $Upost{clflags}{BUFKIT}. The return value should be
#  either:
#
#      -1 - bufkit processing explicitly turned OFF (--nobufkit passed)
#       1 - bufkit processing explicitly turned ON  (--bufkit without --nobufr)
#       0 - no bufkit related flag passed or --nobufr passed
#==================================================================================
#
    my $bufkit = $Upost{clflags}{BUFKIT};  #  Value will be either 1 (--bufkit passed), 
                                              #  -1 (--nobufkit passed), or 0 (neither passed)
       $bufkit = 0 if $Flags{nobufr};


return $bufkit;
}


sub Flag_debug {
#==================================================================================
#  Passing the --debug flag sets the level of verbosity when attempting to figure
#  out why the UEMS is behaving so badly. It's unlikely to reveal much and will
#  leave you with no choice but to BLAME THE PARENTS!
#==================================================================================
#
    my $debug = $Upost{clflags}{DEBUG} || return 0;

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
    my $autopost = $Upost{clflags}{AUTOPOST} || return 0;
       $autopost = lc $autopost;

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
#   0          --emspost not passed 
#   0:primary  - Process default emspost data type(s) for ALL domains
#   #:datatype - Specified dataset type for each domain
#==================================================================================
#
    my $emspost = $Upost{clflags}{EMSPOST} || return 0;
       $emspost = lc $emspost;

    return '0:primary' if $emspost =~ /^auto/;

return $emspost;
}


sub Flag_domains {
#==================================================================================
#  Define the domains to be processed. There are multiple sources for this
#  information, specifically the --domain, --autopost, and --emspost flags.
#  if all else fails then default to the primary domain.
#==================================================================================
#
    my @domains = split ',', $Upost{clflags}{DOMAIN}; 
       @domains = (1) unless @domains;  # May have already been set in options

    my $apstr   = $Flags{autopost}; $apstr =~ s/:+/,/g; # Change : to , for next step
    my $epstr   = $Flags{emspost};  $epstr =~ s/:+/,/g; # Change : to , for next step

    foreach (split ',', $apstr) {push @domains, $_ if /^\d+$/ and $_;}
    foreach (split ',', $epstr) {push @domains, $_ if /^\d+$/ and $_;}

    @domains = sort {$a <=> $b} &Others::rmdups(@domains);

return join ',', @domains;
}    


sub Flag_autoupp {
#==================================================================================
#  The autoupp flag is passed by ems_autorun, normally
#==================================================================================
#
    my $autoupp = $Upost{clflags}{AUTOUPP} || return '';
       $autoupp =~ s/,+|;+/,/g;
       $autoupp =~ s/:+/:/g;


    my @rvals  = ();
    my @cvals  = split ',' => $autoupp;

    foreach (@cvals) {

        my ($host, $core) = '' x 2;
        
        foreach my $val (split ':' => $_) {
            $host = $val     if &Enet::isHostname($val);
            $core = int $val if &Others::isNumber($val);
        }
        next unless $core and $host;

        push @rvals => "${host}:${core}";
    }

return @rvals ? join ',' => @rvals : '';
}


sub Flag_noexport {
#==================================================================================
#  The noexport flag is passed by ems_autorun
#==================================================================================
#
    my @expts = ();
    my @dsets = qw(netcdf wrfout auxhist afwa grib grads gempak bufr bufkit gemsnd acisnd);

    my $noexport = $Upost{clflags}{NOEXPORT} || return 0;
      
    return join ',', @dsets  if $noexport =~ /^1/;

    foreach my $exp (split /,/, $noexport) {
        for ($exp) {
            $_ = 'grib'    if /^grb|^gri/i;  #  Needed for GRIB 2 transition
            $_ = 'grads'   if /^gra|^grd/i;
            $_ = 'wrfout'  if /^wrf/i;
            $_ = 'auxhist' if /^aux/i;
            $_ = 'afwa'    if /^afwa/i;
            $_ = 'netcdf'  if /^net/i;
            $_ = 'bufr'    if /^bufr/i;
            $_ = 'bufkit'  if /^bufk/i;
            $_ = 'gempak'  if /^gemp/i;
            $_ = 'gemsnd'  if /^gems/i;
            $_ = 'acisnd'  if /^asc/i;
        }
        next unless grep {/^${exp}$/} @dsets;
        push @expts => $exp;
    }


return @expts ?  join ',', sort &Others::rmdups(@expts) : 0;
}


sub Flag_ncpus {
#==================================================================================
#  Define the number of processors to be used when running emsupp, but first,
#  some issues must be resolved:
#
#    1.  Is the value of OMP_NUM_THREADS (SOCKETS * CORES) as defined in the
#        EMS.cshrc|profile file, greater then the total number of cpus identified
#        on the machine (total_cores). If so then set maxcpus = total_cores.
#
#    2.  Was the --ncpus flag passed?  If yes then check against maxcpus value.
#
#    3.  Turn OFF --ncpus flag if --autoupp was also passed
#==================================================================================
#
    return 0 unless $Upost{clflags}{NCPUS};  #  Return 0 if not passed
    return 0 if $Flags{autoupp};

    my $maxcpus  = 0;
       $maxcpus  = $ENV{OMP_NUM_THREADS} if defined $ENV{OMP_NUM_THREADS} and $ENV{OMP_NUM_THREADS} > 0;
       $maxcpus  = $Upost{emsenv}{sysinfo}{total_cores} if defined $Upost{emsenv}{sysinfo}{total_cores} and $Upost{emsenv}{sysinfo}{total_cores} > 0;

       if ($Upost{clflags}{NCPUS} > $maxcpus) {
           my $mesg = "Setting NCPUS to $maxcpus, because that's all the cores you have on this system.";
           &Ecomm::PrintMessage(6,12+$Upost{arf},124,1,1,"I'm Givin' Her All She's Got, Captain!",$mesg);
       }

       $maxcpus = $Upost{clflags}{NCPUS} if $Upost{clflags}{NCPUS} and $Upost{clflags}{NCPUS} < $maxcpus;
       $maxcpus = 1 unless $maxcpus > 0;  #  A Safety check


return $maxcpus;
}



sub Flag_passvalue {
#==================================================================================
#  Simply transfer the value from the OPTIONS hash for the final configuration
#==================================================================================
#
    my $field = shift;

return $Upost{clflags}{uc $field};
}


sub FlagsDebugInformation {
#==================================================================================
#  Debug information if the --debug <value> is greater than 0
#==================================================================================
#
    &Ecomm::PrintMessage(0,9,94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,12,255,1,1,'&PostFlagConfiguration - Final command-line flag values:');
    &Ecomm::PrintMessage(0,15,255,1,2,'Note: Some values have preset defaults');
    &Ecomm::PrintMessage(0,17,255,0,1,sprintf('--%-10s = %s',$_,$Flags{$_})) foreach sort keys %Flags;
    &Ecomm::PrintMessage(0,9,94,0,2,'=' x 72);

return;
}



