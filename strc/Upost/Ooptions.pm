#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Ooptions.pm
#
#  DESCRIPTION:  Ooptions contains each of the primary routines used for the
#                reading and interpreting the many command line options and
#                flags passed to ems_post.
#
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Ooptions;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Saved);

use Ecomm;
use Ecore;
use Others;
use Ohelp;


sub PostOptions {
#==================================================================================
#  Front end to the GetPostOptions routine
#==================================================================================
#
      my %Options = ();

      my $upref   = shift;  my %Upost = %{$upref};

      return () unless %Options = &GetPostOptions();
      return () unless %Options = &SetPostOptionValues(\%Options);

      %{$Upost{clflags}} = %Options;

     
return %Upost;
}



sub GetPostOptions {
#==================================================================================
#  The GetPostOptions routine parses the flags and Option passed from the
#  command line to ems_post. Simple enough.
#==================================================================================
#
use Getopt::Long qw(:config pass_through);

    my %Option = ();

    #  Do an initial check of the Option and flags to look for obvious problems
    #
#   @ARGV = &CheckPostOption(@ARGV);

    GetOptions ("h|help|?"           => sub {&Ohelp::PostHelpMe(@ARGV)},   #  Just what the doctor ordered
                "scour!"             => \$Option{SCOUR},            #  Run ems_clean --level 1 rather than 0 (default)
                "debug:s"            => \$Option{DEBUG},            #  Turns on the debugging and prints out additional information
                "domains:s"          => \$Option{DOMAIN},           #  Specify the domain to be processed
                "rundir:s"           => \$Option{RUNDIR},           #  Specify the run-time directory to use
                "wrfout"             => \$Option{WRFOUT},           #  Process the primary history files
                "auxhist"            => \$Option{AUXHIST},          #  Process the auxiliary history files
                "afwa"               => \$Option{AFWA},             #  Process the AFWA history files
                "noupp"              => \$Option{NOUPP},            #  Skip the EMS UPP routine to process netCDF to GRIB
                "grib:s"             => \$Option{GRIB},             #  Run the EMS UPP routine to process netCDF to GRIB 2. Overrides "GRIB = " in post_grib.conf
                "info"               => \$Option{INFO},             #  Print summary of post processing tasks and get out.
                "summary"            => \$Option{SUMMARY},          #  Just like "--info" but continues with processing
                "nogrib"             => \$Option{NOGRIB},           #  Do not run the EMS UPP routine to process netCDF to GRIB & Turn off all derived products
                "gempak!"            => \$Option{GEMPAK},           #  Turn ON|OFF processing of GRIB into GEMPAK format
                "grads!"             => \$Option{GRADS},            #  Turn ON|OFF processing of GRIB into GRADS format
                "bufr:s"             => \$Option{BUFR},             #  Turns ON  creation of BUFR files from netCDF
                "nobufr"             => \$Option{NOBUFR},           #  Turns OFF creation of BUFR files from netCDF
                "bufkit!"            => \$Option{BUFKIT},           #  Turns ON/OFF creation of BUFKIT (and BUFR) files
                "gemsnd!"            => \$Option{GEMSND},           #  Turns ON/OFF creation of GEMPAK sounding files from BUFR
                "bfinfo!"            => \$Option{BFINFO},           #  Write Lots on sounding information to the BUFR log
                "noexport:s"         => \$Option{NOEXPORT},         #  Catch-all for all export option flags
                "autopost:s"         => \$Option{AUTOPOST},         #  This is AUTOPOST part of an autorun simulation
                "emspost:s"          => \$Option{EMSPOST},          #  This is EMSPOST  part of an autorun simulation 
                "autoupp:i"          => \$Option{AUTOUPP},          #  Overrides value of EMSUPP_NODECPUS in post_grib.conf for autopost runs
                "index:i"            => \$Option{INDEX},            #  The number of CPUs to use when running emsupp
                "ncpus:i"            => \$Option{NCPUS}             #  Used with the autopost routine to keep track of which files to process
               );  #  &Ohelp:::PostHelpMeError(@ARGV) if @ARGV;


return %Option; 
}


sub SetPostOptionValues {
#==================================================================================
#  The SetPostOptionValues takes the option hash and gives them a value, whether 
#  they were passed or not.
#==================================================================================
#
    my $oref   = shift;
    my %Option = %{$oref};

    #  ---------------------- Attempt the configuration ---------------------------
    #
    #  Note that the order is important for some!
    #
    $Option{AFWA}         =  &PostOptionValue('afwa'      ,$Option{AFWA});
    $Option{AUTOPOST}     =  &PostOptionValue('autopost'  ,$Option{AUTOPOST});
    $Option{AUTOUPP}      =  &PostOptionValue('autoupp'   ,$Option{AUTOUPP});
    $Option{AUXHIST}      =  &PostOptionValue('auxhist'   ,$Option{AUXHIST});
    $Option{BFINFO}       =  &PostOptionValue('bfinfo'    ,$Option{BFINFO});
    $Option{BUFKIT}       =  &PostOptionValue('bufkit'    ,$Option{BUFKIT});
    $Option{BUFR}         =  &PostOptionValue('bufr'      ,$Option{BUFR});
    $Option{DEBUG}        =  &PostOptionValue('debug'     ,$Option{DEBUG});
    $Option{DOMAIN}       =  &PostOptionValue('domain'    ,$Option{DOMAIN});
    $Option{EMSPOST}      =  &PostOptionValue('emspost'   ,$Option{EMSPOST});
    $Option{GEMPAK}       =  &PostOptionValue('gempak'    ,$Option{GEMPAK});
    $Option{GEMSND}       =  &PostOptionValue('gemsnd'    ,$Option{GEMSND});
    $Option{GRADS}        =  &PostOptionValue('grads'     ,$Option{GRADS});
    $Option{GRIB}         =  &PostOptionValue('grib'      ,$Option{GRIB});
    $Option{INDEX}        =  &PostOptionValue('index'     ,$Option{INDEX});
    $Option{NCPUS}        =  &PostOptionValue('ncpus'     ,$Option{NCPUS});
    $Option{NOBUFR}       =  &PostOptionValue('nobufr'    ,$Option{NOBUFR});
    $Option{NOEXPORT}     =  &PostOptionValue('noexport'  ,$Option{NOEXPORT});
    $Option{NOGRIB}       =  &PostOptionValue('nogrib'    ,$Option{NOGRIB});
    $Option{INFO}         =  &PostOptionValue('info'      ,$Option{INFO});
    $Option{SUMMARY}      =  &PostOptionValue('summary'   ,$Option{SUMMARY});
    $Option{NOUPP}        =  &PostOptionValue('noupp'     ,$Option{NOUPP});
    $Option{RUNDIR}       =  &PostOptionValue('rundir'    ,$Option{RUNDIR});
    $Option{SCOUR}        =  &PostOptionValue('scour'     ,$Option{SCOUR});
    $Option{WRFOUT}       =  &PostOptionValue('wrfout'    ,$Option{WRFOUT});

    return () if $ENV{OMESG};


return %Option;
}


sub MatchPostOptions {
#=====================================================================================
#  This routine matched a passed flag to an actual option should the user have
#  used a partial flag name. This is necessary for the help routines.
#=====================================================================================
#
use List::Util 'first';

    my $flag = qw{};
    my %flags= ();

    my %opts = &Ohelp::DefinePostOptions();  #  Get options list

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


sub PostOptionValue {
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


sub Option_afwa {
#==================================================================================
#  Specify 1|0 whether the --afwa flag was passed.
#==================================================================================
#
    my $passed = shift;

return (defined $passed and $passed) ? 1 : 0;
}


sub Option_autopost {
#==================================================================================
#  Flag to turn ON processing of simulation output concurrent with integration.
#  The argument is a list of domain IDs separated by commas and may also include
#  dataset types to process (primary, auxilliary) separated by colons.  Passing
#  --autopost without an argument or an invalid argument turns ON all domains.
#  Passing --autopost without an argument or an invalid argument turns ON all 
#  turns ON all domains. A return value of 0 simply means --autopost was not 
#  passed.
#==================================================================================
#
    my $passed  = shift;  return 0 unless defined $passed;  #  Return value 0 = flag not passed

    return 'auto' unless length $passed;  # --autopost without arguments turns all domains ON
    return 'auto' if $passed =~ /^All|^Auto/i;

    $passed  = lc $passed;
    $passed  =~ s/,+|;+/,/g;  #  Config_autopost will accept ; or , to separate domains -  use , for now
    $passed  =~ s/:+/:/g;     #  Separates domain:data:sets
    $passed  =~ s/(,+)$//g;   #  Eliminate dangling commas 
    $passed  =~ s/(:+)$//g;   #  Eliminate dangling colons ;)

    return 0 unless $passed;  #  A 0 value turns all off
    return 0 if $passed =~ /^Off/i;

    my @pargs  = split /,/ => $passed;
       @pargs  = sort &Others::rmdups(@pargs);

return @pargs ? join ',', @pargs : 'auto';
}



sub Option_autoupp {
#==================================================================================
#  Passage of the --autoupp serves to replace the value of EMSUPP_NODECPUS in
#  the post_grib.conf file when accompanied by the --autopost flag.
#==================================================================================
#
    my $passed = shift;

return (defined $passed and $passed) ? $passed : 0;
}



sub Option_auxhist {
#==================================================================================
#  Specify 1|0 whether the --auxhist flag was passed.
#==================================================================================
#
    my $passed = shift;

return (defined $passed and $passed) ? 1 : 0;
}


sub Option_bfinfo {
#==================================================================================
#  Define the value for the --[no]bfinfo flag, which is used to request the output
#  of additional IO to the BUFR logfile.
#
#  Values:  -1 = no bfinfo (--nobfinfo), 1 = use bfinfo (--bfinfo), 0 = not passed
#==================================================================================
#
    my $passed = shift;

       $passed = (defined $passed) ? $passed ? 1 : -1 : 0;

return $passed;
}


sub Option_bufkit {
#==================================================================================
#  Define the value for the --[no]bufkit flag, which is used to request the 
#  processing of BUFR files into BUFKIT format.
#
#  Values:  -1 = no bufkit (--nobufkit), 1 = use bufkit (--bufkit), 0 = not passed
#==================================================================================
#
    my $passed = shift;

       $passed = (defined $passed) ? $passed ? 1 : -1 : 0;

return $passed;
}


sub Option_bufr {
#==================================================================================
#  Define the value for option --bufr, which is used to specify the processing
#  of netCDF into bufr datasets during the post processing. Any arguments
#  passed serve to override the FREQUENCY_ parameter in the post_bufr.conf file.
#  If the --nobufr flag is also passed then bufr file processing turned OFF
#  whether --bufr was passed or not.
#==================================================================================
#
    my $passed = shift;

       return 0 unless defined $passed;
       return 1 unless $passed;
       
       #  Any arguments passed are applied to the FREQUENCY_ parameters located
       #  in the post_bufr.conf file. Easiest just to set them both to the same
       #  values.  The format of the argument is FREQ:START:STOP but we need to
       #  account for the use of commas (,) and semicolons (;) as separators. 
       #  Here the "@tmp" list is used to catch any extraneous values.
       #
       my $form = '';

       $passed =~ s/:|,|;|"|'/:/g;  #  Replace Separators with ":"
       $passed =~ s/[^\d|\:]//g;

       my ($freq,$start,$stop,@tmp) = split /:/ => $passed;

       $freq = 1 unless $freq;
       $stop = 0 unless $stop;
       $start= 0 unless $start;

       $stop = 0  if ($stop  =~ /^\D/i or $stop  < 1 or $stop < $start);
       $start= 0  if ($start =~ /^\D/i or $start < 1 or ($stop and $start > $stop) );
       $freq = 1  if ($freq  =~ /^\D/i or $freq <= 1);

       $freq = 'Auto' if $freq == 1;  #  Need to avoid confusion with bufr = 1

       $stop = 0 unless $stop;
       $start= 0 unless $start;


return "$freq:$start:$stop";
}



sub Option_debug {
#==================================================================================
#  Define the value for the --debug flag. This flag may be an integer value of
#  (doesn't matter as they all get 1, or a character string, "upp" or "emsupp".
#  If upp or emsupp, the ems_post will exit prior to running the EMSUPP routine
#  An optional ":#" may be appended to emsupp, i.e., "--debug emsupp:3", that
#  instructs the ems_post to exit just before processing the third netCDF file
#  into GRIB2. Used for debugging by the developer.
#==================================================================================
#
    my $passed = shift;

    return 0 unless defined $passed;
    return 1 unless $passed;

    return 1 if &Others::isInteger($passed);

    if ($passed =~ /^upp|^uems|^ems/i) {
        #  Exit prior to running EMSUPP - use a negative value
        #  for fine number to avoid general debug statements.
        #
        my ($up,$fn) = split ':' => $passed;
        $fn = 1 unless defined $fn and &Others::isInteger($fn) and $fn > 0;
        return -1*$fn;
    }

    return -101 if $passed =~ /grib2ctl/i;  #  Exit prior to running g2ctl.pl
    return -102 if $passed =~ /gribmap/i;   #  Exit prior to running gribmap
 

return 1;  #  Just in case - of what? I have no idea
}


sub Option_domain {
#==================================================================================
#  Specifies the domain number to be processed. Default is the primary domain (#1)
#  unless the --domains flag was passed. Additional (secret) enhancement in that
#  a comma separated list of domains may be also be passed. Additionally, the 
#  domains to process may be included as part of the --emspost flag but don't
#  tell anybody.
#==================================================================================
#
    my @doms    = ();
    my $passed  = shift;

    return 1 unless defined $passed and $passed;  #  Default is domain 1 

    #  Clean up the formatting of the string if passed.
    #
    for ($passed) { s/,+|;+|:+/,/g; }

    foreach my $dom (split /,/ => $passed) {
        next unless ($dom =~ /^(\d+)$/);
        $dom+=0;  next unless $dom > 0;
        push @doms => $dom;
    }
    @doms = (1) unless @doms;
    @doms = sort {$a <=> $b} &Others::rmdups(@doms);

    $passed  = join ',' => @doms;


return $passed;
}



sub Option_emspost {
#==================================================================================
#  Flag to turn ON post processing of simulation output after the run is
#  completed. The argument is a list of domain IDs separated by commas and
#  may also include dataset types to process (primary, auxilliary) separated
#  by colons.  Passing --emspost without an argument or an invalid argument
#  turns ON all domains. A return value of 0 simply means --emspost was not 
#  passed.
#==================================================================================
#
    my $passed  = shift;  return 0 unless defined $passed;  #  Return value 0 = flag not passed

    return 'auto' unless length $passed;  # --emspost without arguments turns all domains ON
    return 'auto' if $passed =~ /^All|^Auto/i;

    $passed  = lc $passed;
    $passed  =~ s/,+|;+/,/g;  #  Config_emspost will accept ; or , to separate domains -  use , for now
    $passed  =~ s/:+/:/g;     #  Separates domain:data:sets
    $passed  =~ s/(,+)$//g;   #  Eliminate dangling commas 
    $passed  =~ s/(:+)$//g;   #  Eliminate dangling colons ;)

    return 0 unless $passed;         #  A 0 value turns all off
    return 0 if $passed =~ /^Off/i;  #  Not valid for running ems_post directly
    
    my @pargs  = split /,/ => $passed;
       @pargs  = sort &Others::rmdups(@pargs);


return @pargs ? join ',', @pargs : 'auto';
} 


sub Option_index {
#==================================================================================
#  Specifies the index within the list of simulation output files with which to
#  begin processing. Default is 0 or the beginning (all files).
#==================================================================================
#
    my $passed = shift;  $passed = 0 unless defined $passed and $passed;

    $passed = 0 unless $passed =~ /^(\d+)$/g;
    $passed = 0 unless $passed > 0;

return $passed;
}


sub Option_gempak {
#==================================================================================
#  Define the value for the --[no]gempak flag, which is used to request the 
#  processing of GRIB files into gempak format.
#
#  Values:  -1 = no gempak (--nogempak), 1 = use gempak (--gempak), 0 = not passed
#==================================================================================
#
    my $passed = shift;

       $passed = (defined $passed) ? $passed ? 1 : -1 : 0;

return $passed;
}


sub Option_gemsnd {
#==================================================================================
#  Define the value for the --[no]gemsnd flag, which is used to request the 
#  processing of BUFR files into gempak sounding files.
#
#  Values:  -1 = no gemsnd (--nogemsnd), 1 = use gemsnd (--gemsnd), 0 = not passed
#==================================================================================
#
    my $passed = shift;

       $passed = (defined $passed) ? $passed ? 1 : -1 : 0;

return $passed;
}


sub Option_grads {
#==================================================================================
#  Define the value for the --[no]grads flag, which is used to request the 
#  processing of GRIB files into GrADS format.
#
#  Values:  -1 = no grads (--nograds), 1 = use grads (--grads), 0 = not passed
#==================================================================================
#
    my $passed = shift;

       $passed = (defined $passed) ? $passed ? 1 : -1 : 0;

return $passed;
}


sub Option_grib {
#==================================================================================
#  Define the value for option --grib, which is used to specify the processing
#  of netCDF into grib datasets during the post processing. Any arguments
#  passed serve to override the FREQUENCY_ parameter in the post_grib.conf file.
#  If the --nogrib flag is also passed then GRIB file processing turned OFF
#  whether --grib was passed or not.
#==================================================================================
#
    my $passed = shift;

       return 0 unless defined $passed;
       return 1 unless $passed;
       
       #  Any arguments passed are applied to the FREQUENCY_ parameters located
       #  in the post_grib.conf file. Easiest just to set them both to the same
       #  values.  The format of the argument is FREQ:START:STOP but we need to
       #  account for the use of commas (,) and semicolons (;) as separators. 
       #  Here the "@tmp" list is used to catch any extraneous values.
       #
       my $form = '';

       $passed =~ s/:|,|;|"|'/:/g;  #  Replace Separators with ":"
       $passed =~ s/[^\d|\:]//g;

       my ($freq,$start,$stop,@tmp) = split /:/ => $passed;

       $freq = 1 unless $freq;
       $stop = 0 unless $stop;
       $start= 0 unless $start;

       $stop = 0  if ($stop  =~ /^\D/i or $stop  < 1 or $stop < $start);
       $start= 0  if ($start =~ /^\D/i or $start < 1 or ($stop and $start > $stop) );
       $freq = 1  if ($freq  =~ /^\D/i or $freq <= 1);

       $freq = 'Auto' if $freq == 1;  #  Need to avoid confusion with GRIB = 1

       $stop = 0 unless $stop;
       $start= 0 unless $start;


return "$freq:$start:$stop";
}



sub Option_info {
#==================================================================================
#  Define the value for option --info flag was passed.
#==================================================================================
#
    my $passed = shift;

return (defined $passed and $passed) ? 1 : 0;
}



sub Option_summary {
#==================================================================================
#  Define the value for option --summary flag was passed.
#==================================================================================
#
    my $passed = shift;

return (defined $passed and $passed) ? 1 : 0;
}



sub Option_ncpus {
#==================================================================================
#  Process requested number of processors used when running EMSUPP. 
#  Further checks are done in the configuration module.
#==================================================================================
#
    my $passed = shift;

    $passed = (defined $passed and $passed) ? $passed : 0;

    #  Make sure the argument passed to --ncpus was a non negative integer
    #
    my $mesg = "The argument passed to \"--ncpus\" must be in the form of an positive integer since you are specifying ".
               "the number of processors to use when running the EMSUPP.\n\n".

               "Maybe a bit of school'n will help:  %  ems_post --help ncpus";
    
    $ENV{OMESG} = &Ecomm::TextFormat(0,0,88,0,0,'More from: "When Good Arguments Go Bad"',$mesg) unless $passed =~ /^(\d)+$/;


return $passed;
}



sub Option_nobufr {
#==================================================================================
#  Define the value for the --nobufr flag, which is used to override the value
#  of bufr in the ems_post.conf file. Note that passing --nobufr takes precedent
#  if the --bufr <arg> flag is also passed.
#==================================================================================
#
    my $passed = shift;

return (defined $passed and $passed)  ? 1 : 0;
}


sub Option_noexport {
#==================================================================================
#  Define the value for option --noexport, which is used to de-select datasets
#  to be exported as defined in the post_exports.conf file.  If the --noexport
#  flag is passed without an argument then turn OFF the export of ALL files;
#  Otherwise the argument should be a character string that is matched to data
#  sets and then removed from the export list.
#==================================================================================
#
    my $passed = shift;

    #  For this option:
    #
    #     $passed = 1  if no argument was passed
    #     $passed = 0  if --noexport was not passed (do all)
    #     $passed = <argument string> if argument string was passed
    #
    return 0 unless defined $passed; # --noexport was not passed (do all)
    return 1 unless $passed;         # --noexport passed without an argument

    $passed =~ s/\.+|,+|;+|:+/,/g; $passed = lc $passed; chomp $passed;
    $passed =~ s/grib2/grib/ig;


return $passed;
}



sub Option_nogrib {
#==================================================================================
#  Define the value for the --nogrib flag, which is used to override the value
#  of GRIB in the ems_post.conf file. Note that passing --nogrib takes precedent
#  if the --grib <arg> flag is also passed.
#==================================================================================
#
    my $passed = shift;

return (defined $passed and $passed)  ? 1 : 0;
}


sub Option_noupp {
#==================================================================================
#  Define the value for option --noupp flag was passed.
#==================================================================================
#
    my $passed = shift;

return (defined $passed and $passed) ? 1 : 0;
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


sub Option_scour {
#==================================================================================
#  Set the clean flag if passed to ems_post. Note that passing --clean currently
#  deletes the log files and local files only.
#==================================================================================
#
    my $passed = shift;
       $passed = (defined $passed) ? $passed ? 1 : -1 : 0;

return $passed;
}


sub Option_wrfout {
#==================================================================================
#  Specify 1|0 whether the --wrfout flag was passed.
#==================================================================================
#
    my $passed = shift;

return (defined $passed and $passed) ? 1 : 0;
}


