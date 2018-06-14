#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Aoptions.pm
#
#  DESCRIPTION:  Aoptions contains the routines used to read and process the
#                command-line flags passeed to ems_autorun.
#
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Aoptions;

use warnings;
use strict;
require 5.008;
use English;

use Ecomm;
use Ecore;
use Others;
use Ahelp;
use Pginfo;


sub AutoOptions {
#==================================================================================
#  Front end to the GetAutoOptions routine
#==================================================================================
#
      my %Options = ();
      my $upref   = shift;  my %Uauto = %{$upref};

      return () unless %Options = &GetAutoOptions();
      return () unless %Options = &SetAutoOptionValues(\%Options);

      %{$Uauto{aflags}} = %Options;
     
return %Uauto;
}



sub GetAutoOptions {
#==================================================================================
#  The GetAutoOptions routine parses the flags and Option passed from the
#  command line to ems_autorun. Simple enough.
#==================================================================================
#
use Getopt::Long qw(:config pass_through);

    my %Option = ();

    #  Do an initial check of the Option and flags to look for obvious problems
    #
    @ARGV = &CheckAutoOptions(@ARGV);

    GetOptions ("h|help|?"           => sub {&Ahelp::AutoHelpMe(@ARGV)},   #  Just what the doctor ordered

                "scour!"             => \$Option{SCOUR},            #  Run ems_clean --level 4 rather than 3 (default)
                "debug"              => \$Option{DEBUG},            #  Turns on the debugging and prints out additional information
                "nolock"             => \$Option{NOLOCK},           #
                "autopost:s"         => \$Option{AUTOPOST},         #  List of domains to include during concurrent post processing
                "emspost:s"          => \$Option{EMSPOST},          #  List of domains to include during post processing following the simulation completion
 
                "rundir:s"           => \$Option{RUNDIR},           #  Specify the run-time directory to use
                "nudging!"           => \$Option{NUDGING},          #  Turn ON|OFF 3D analysis or spectral nudging for requested domains
                "length:s"           => \$Option{LENGTH},           #  The length of the simulation in hours
                "cycle:s"            => \$Option{RCYCLE},           #  The requested cycle hour of the initialization dataset [CC]
                "dset:s"             => \$Option{RDSET},            #  Identify the initialization dataset(s) to use
                "sfc:s"              => \$Option{SFC},              #  Any additional the surface datasets to include in the initialization
                "lsm:s"              => \$Option{LSM},              #  Any additional land surface datasets to include in the initialization

                "domains:s"          => \$Option{DOMAINS},          #  Specify the domain(s) to be processed
                "date:s"             => \$Option{RDATE},            #  The requested date of the initialization dataset [YYYYMMDD]

                "dsquery|query:s"    => sub {&Pginfo::QueryGribinfo($_[1])},
                "dsinfo:s"           => sub {&Pginfo::QueryGribinfo($_[1])},
                "dslist"             => sub {&Pginfo::QueryGribinfo('list')}, # list out datasets available for initialization

               );  #  &Ahelp::AutoHelpMeError(@ARGV) if @ARGV;


return %Option; 
}


sub SetAutoOptionValues {
#==================================================================================
#  The &SetAutoOptionValues routine takes the option hash and gives them a value, 
#  whether they were passed or not. The $ENV{AMESG} environment variable is used  
#  to indicate a failure.
#==================================================================================
#

    my $oref   = shift;
    my %Option = %{$oref};

    #  ---------------------- Attempt the configuration ---------------------------
    #
    #  Note that the order is important for some!
    #
    $Option{DOMAINS}      =  &AutoOptionValue('domains'   ,$Option{DOMAINS});
    $Option{LENGTH}       =  &AutoOptionValue('length'    ,$Option{LENGTH});
    $Option{RDATE}        =  &AutoOptionValue('rdate'     ,$Option{RDATE});     #  Must be before RDSET for CFSR
    $Option{RCYCLE}       =  &AutoOptionValue('rcycle'    ,$Option{RCYCLE});
    $Option{RDSET}        =  &AutoOptionValue('rdset'     ,$Option{RDSET});     #  A must have!
    $Option{SFC}          =  &AutoOptionValue('sfc'       ,$Option{SFC});
    $Option{LSM}          =  &AutoOptionValue('lsm'       ,$Option{LSM});
    $Option{SCOUR}        =  &AutoOptionValue('scour'     ,$Option{SCOUR});
    $Option{DEBUG}        =  &AutoOptionValue('debug'     ,$Option{DEBUG});
    $Option{NOLOCK}       =  &AutoOptionValue('nolock'    ,$Option{NOLOCK});
    $Option{NUDGING}      =  &AutoOptionValue('nudging'   ,$Option{NUDGING});
    $Option{AUTOPOST}     =  &AutoOptionValue('autopost'  ,$Option{AUTOPOST});
    $Option{EMSPOST}      =  &AutoOptionValue('emspost'   ,$Option{EMSPOST});
    $Option{RUNDIR}       =  &AutoOptionValue('rundir'    ,$Option{RUNDIR});

    return () if $ENV{AMESG};


return %Option;
}


sub MatchAutoOptions {
#==================================================================================
#  This routine matched a passed flag to an actual option should the user have
#  used a partial flag name. This is necessary for the help routines.
#==================================================================================
#
use List::Util 'first';

    my $flag = qw{};
    my %flags= ();

    my %opts = &Ahelp::DefineAutoOptions();  #  Get options list

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


sub CheckAutoOptions {
#==================================================================================
#  This routine does a basic check of the options and flags passed to ems_autorun 
#  to determine whether they are valid. Additional checks will be done during the
#  configuration stage.
#==================================================================================
#
    my %full = ();
    my %opts = &Ahelp::DefineAutoOptions();  #  Get list of options

    my @list = @_;

    #  Do an initial run through of the argument list to make sure each --[option] is valid .
    #
    foreach (@list) {

        next unless /^\-\-/;   #  It's an argument to an option if not preceded by a '-'

        my $opt = $_; 

        $_ = &MatchAutoOptions($opt);

        #  Test if it's a valid option
        #
        if (defined $_ and defined $opts{$_}) {

            if ($opts{$_}{arg} and $opts{$_}{arg} !~ /^\[/) {         #  If the flag requires an argument 
                my $i = &Others::StringIndexMatchExact($opt,@_); $i++;  #  Get the index of the argument to test
                &Ahelp::PrintAutoOptionHelp($_) if $i > $#_ || $_[$i] =~ /^\-/;    #  Missing or bad argument - print help
            }

        } else {
            my $help = "Try passing \"--help\" for some hand-holding and a list of valid flags.";
            $ENV{AMESG} = &Ecomm::TextFormat(0,0,94,0,0,'Making stuff up as you go along?',"Passing \"$opt\" will not endear yourself to the UEMS Oligarch.\n\n$help");
            return ();
        }

    }


return @_;
}


sub AutoOptionValue {
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


sub Option_scour {
#==================================================================================
#  By default the --scour flag is set to value of 4, which removes any residue
#  from previous runs including the initialization files under /grib. Passing
#  --noscour sets the value to 3 and retains the initialization files.  If 
#  the --[no]scour flag is not passed ems_autorun defaults to the config file.
#==================================================================================
#
    my $passed = shift;

    return 0 unless defined $passed;  #  Default 0 if --[no]scour not passed
    $passed = $passed ? 4 : 3;        #  Set to 4  if --scour; otherwise 3 for --noscour 

return $passed;
}



sub Option_debug {
#==================================================================================
#  Define the value for the --debug flag, which for ems_autorun will be 1 or 0.
#==================================================================================
#
    my $passed = shift;

return (defined $passed and $passed) ? 1 : 0;
}



sub Option_nolock {
#==================================================================================
#  Define the value for the --nolock flag, which for ems_autorun will be 1 or 0.
#==================================================================================
#
    my $passed = shift;

return (defined $passed and $passed) ? 1 : 0;
}


sub Option_nudging {
#==================================================================================
#  Define the value for the --[no]nudging flag, which for ems_autorun will be 1 or 0.
#==================================================================================
#
    my $passed = shift;

    return 0 unless defined $passed;

return $passed ? 1 : -1;
}



sub Option_length {
#==================================================================================
#  Specify the length of the simulation.  For this option a placeholder will be used 
#  and eventually replaced with a value in hours.
#==================================================================================
#
    my $passed = shift;

    $passed = 0 unless defined $passed and $passed;

return $passed;
}


sub Option_rcycle {
#==================================================================================
#  Manage the argument passed to --cycle
#==================================================================================
#
    my $string = 'CYCLE:INITFH:FINLFH:FREQFH';
    my @slist  = split /:/ => $string;

    my $passed = shift; return '' unless defined $passed;

    return '' unless length $passed;

    $passed   =~ s/,|;/:/g; #  replace with colons
    my @plist = split /:/ => $passed;
    
    foreach (0 .. $#plist) { 
        $slist[$_] = sprintf("%02d", $plist[$_]) if length $plist[$_] and &Others::isInteger($plist[$_]);
    }
    $passed = join ':' =>  @slist;

return $passed;
}



sub Option_rdset {
#==================================================================================
#  Dataset options in the form of <dataset>:<method>:<source>:<path>
#==================================================================================
#
    my $passed = shift;

    return '' unless defined $passed and $passed;

    $passed =~ s/ptiles|ptile/pt/g;
    $passed =~ s/%+/%/g;
    $passed =~ s/,+/%/g;
    $passed =~ s/;/:/g;

return $passed;
}



sub Option_lsm {
#==================================================================================
#  Process arguments passed with the --lsm flag
#==================================================================================
#
    my $passed = shift;

    return '' unless defined $passed and $passed;

    $passed =~ s/%+/,/g;
    $passed =~ s/,+/,/g;
    $passed =~ s/ptiles|ptile/pt/g;

return $passed;
}



sub Option_sfc {
#==================================================================================
#  Process arguments passed with the --sfc flag
#==================================================================================
#
    my $passed = shift;

    return '' unless defined $passed and $passed;

    $passed =~ s/%+/,/g;
    $passed =~ s/,+/,/g;
    $passed =~ s/ptiles|ptile/pt/g;

return $passed;
}



sub Option_rdate {
#==================================================================================
#  Specify the date of the files used for initialization.
#==================================================================================
#
    my $mesg   = qw{};
    my $passed = shift; return 0 unless defined $passed;

    unless (length $passed and $passed) {  
        $mesg = "When passing the \"--date\" flag you must provide an argument. Simply passing ".
                "\"--date\" by itself does neither of us any good (especially you). Come on, show ".
                "me you care, show me you want this!";
        $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,0,'One of us is holding you back',$mesg);
        return 0;
    }

    
    #  The silly user passed a non-digit
    #
    unless (&Others::isInteger($passed)) {
        $mesg = "The argument to \"--date\" is supposed to be a string of 8 digits in the format ".
                "of \"--date YYYYMMDD\".\n\nMaybe you missed the \"Numbers & Me\" lesson during the ".
                "Elmo does the UEMS video marathon, but consider yourself schooled.";
        $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,0,'School is in session!',$mesg);
        return 0;
    }


    #  If the user passed a 6-digit date (YYMMDD)
    #
    if (length $passed == 6) {$passed = (substr($passed,0,2)<45) ? "20${passed}" : "19${passed}";}


    unless ($passed =~ /^\d{8}$/) {
        $mesg = "The argument to \"--date\" is supposed to be a string of 8 digits in the format ".
                "of \"--date YYYYMMDD\".\n\nMaybe you missed the \"Numbers & Me\" lesson during the ".
                "Elmo does the UEMS video marathon, but consider yourself schooled.";
        $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,0,'School is in session!',$mesg);
        return 0;
    }


return $passed;
}



sub Option_domains {
#==================================================================================
#  Process initialization files for domains 1 ... --domains #.
#  Arguments to the --domain flag are --domain <number>[:<start hour>],<number>...,
#  where the <start hour> is the number of hours after the start of the primary
#  domain. Note that unlike the option passed to ems_run, the "LENGTH" of the
#  simulation must be in hours.
#
#  Additional configuration is done the Aconf module.
#==================================================================================
#
use POSIX;

    my @rdoms = ();

    my $passed = shift;

    return '' unless defined $passed and $passed;

    foreach (split /,|;/ => $passed) {

        my ($dom, $start, $length) = split /:/ => $_, 3;

        next unless $dom =~ /(\d)+/; $dom+=0;
        next if $dom <= 1;

        $start = 0 unless defined $start and &Others::isInteger($start);
        $start+= 0;
        $start = 0 unless $start > 0;

        $length = 0 unless defined $length and length $length;
        $length =~ s/[^0-9.]//g;  #  Strip and non-number charaters
        $length = int ceil $length;
        $length = 0 unless $length;

        $start  = '' unless $start;
        $length = '' unless $length;

        my @list = ($dom,$start,$length);
        push @rdoms => join ':' => @list;

    }
    foreach (@rdoms) {$_ =~ s/:+$//g;}
    @rdoms = &Others::rmdups(@rdoms);
    unshift @rdoms, '1' if @rdoms;  #  don't add unless other values


return @rdoms ? join ',' => sort @rdoms : 0;
} 



sub Option_emspost {
#==================================================================================
#  Flag to turn ON post processing of simulation output after the run is
#  completed. The argument is a list of domain IDs separated by commas and
#  may also include dataset types to process (primary, auxilliary) separated
#  by colons.  Passing --emspost without an argument or an invalid argument
#  turns ON all domains. A return value of 'OFF' turns OFF processing, triggered
#  if the user passes "--emsopost 0". A return value of 'Auto' specifies that
#  all active domains are to be processed.
#==================================================================================
#
    my $passed  = shift;  return 0 unless defined $passed;  #  Return value 0 = flag not passed

    return 'auto' unless length $passed;  # --emspost without arguments turns all domains ON
    return 'auto' if $passed =~ /^All|^Auto/i;

       $passed  = lc $passed;
       $passed  =~ s/,+|;+/,/g;  #  Config_autopost will accept ; or , to separate domains -  use , for now
       $passed  =~ s/:+/:/g;     #  Separates domain:data:sets
       $passed  =~ s/(,+)$//g;   #  Eliminate dangling commas 
       $passed  =~ s/(:+)$//g;   #  Eliminate dangling colons ;)

    return 'off' unless $passed;  #  A 0 value turns all off
    return 'off' if $passed =~ /^Off/i;
    
    my @pargs  = split /,/ => $passed;
       @pargs  = sort &Others::rmdups(@pargs);


return @pargs ? join ',', @pargs : 'auto';
} 



sub Option_autopost {
#==================================================================================
#  Flag to turn ON processing of simulation output concurrent with integration.
#  The argument is a list of domain IDs separated by commas and may also include
#  dataset types to process (primary, auxilliary) separated by colons.  Passing
#  --autopost without an argument or an invalid argument turns ON all domains.
#  A return value of 'OFF' turns OFF processing, triggered if the user passes
#  "--autopost 0". A return value of 'Auto' specifies that all active domains
#  are to be processed.
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

    return 'off' unless $passed;  #  A 0 value turns all off
    return 'off' if $passed =~ /^Off/i;

    my @pargs  = split /,/ => $passed;
       @pargs  = sort &Others::rmdups(@pargs);

return @pargs ? join ',', @pargs : 'auto';
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


