#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Poptions.pm
#
#  DESCRIPTION:  Poptions contains each of the primary routines used for the
#                reading and interpreting the many command line options and
#                flags passed to ems_prep.
#
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Poptions;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Saved);

use Ecomm;
use Ecore;
use Ehelp;
use Others;


sub PrepOptions {
#==================================================================================
#  Front end to the GetPrepOption routine
#==================================================================================
#
      my %Options  = ();

      my $upref    = shift; my %Uprep = %{$upref};

      $Saved{bm}       = $Uprep{rtenv}{bench};      #  Will be needed during configuration
      $Saved{islake}   = $Uprep{rtenv}{islake};     #  Whether the domain was localized with +lakes
      $Saved{global}   = $Uprep{masternl}{global};  #  Also needed
      $Saved{maxdoms}  = $Uprep{masternl}{maxdoms}; #  The number of localized domains 
      $Saved{yyyymmdd} = $Uprep{emsenv}{yyyymmdd};  #  Needed to check --date option

      return () unless %Options = &GetPrepOptions();
      return () unless %Options = &SetPrepOptionValues(\%Options);

      %{$Uprep{OPTIONS}} = %Options;
     
return %Uprep;
}


sub GetPrepOptions {
#==================================================================================
#  The GetPrepOptions routine parses the flags and options passed
#  from the command line. Simple enough.
#==================================================================================
#
use Getopt::Long qw(:config pass_through);
use Phelp;

    my %Option  = ();


    #  Do an initial check of the options and flags to look for obvious problems
    #
    return () unless @ARGV = &CheckPrepOptions(@ARGV) or $Saved{bm};


    GetOptions ( "h|help|?"           => sub {&Phelp::PrepHelpMe(@ARGV)},   #  Just what the doctor ordered

                 "scour!"             => \$Option{SCOUR},
                 "bndyrows:5"         => \$Option{BNDYROWS},     #  Process only [ROWS] outer rows used for the lateral boundaries. Default is 5 rows
                 "benchmark"          => \$Option{BM},           #  Run the benchmark case
                 "timeout:s"          => \$Option{TIMEOUT},      #  Timeout value to be used with mpich2 & metgrid
                 "nodelay"            => \$Option{NODELAY},      #  Sets the DELAY to 0 hours
                 "nudge"              => \$Option{NUDGING},      #  Process requested domains for 3D Analysis/Spectral Nudging
                 "previous"           => \$Option{PREVIOUS},     #  Use the previous cycle of the dataset rather then the current one
                 "nointdel"           => \$Option{NOINTDEL},     #  Do not delete the intermediate files after processing 
                 "noproc"             => \$Option{NOPROCESS},    #  Do not processes the GRIB files for model initialization
                 "local"              => \$Option{LOCALGRIB},    #  Only check for initialization files in local directory
                 "hiresbc"            => \$Option{HIRESBC},      #  Interpolate between BC file times to create hourly BC files.
                 "noaerosols"         => \$Option{AEROSOLS},     #  Flag to not include monthly aerosol climatology in the initialization dataset
                 "noaltsst"           => \$Option{NOALTSST},     #  Do not use the alternate method for water temperatures in the absence of data
                 
                 "length:i"           => \$Option{FLENGTH},      #  Define the forecast length
                 "analysis:0"         => \$Option{ANALYSIS},     #  Use analyses for initial and boundary conditions

                 "dset:s"             => \$Option{RDSET},        #  Specify the initialization dataset(s)

                 "sfc:s"              => \@{$Option{SFCS}},      #  Specify the static surface datasets
                 "lsm:s"              => \@{$Option{LSMS}},      #  Specify the land surface datasets

                 "domains:s"          => \$Option{DOMAIN},       #  Process initialization files for domains 1 ... --domains #
                 "date:s"             => \$Option{RDATE},        #  Specify the date of the files used for initialization
                 "cycle:s"            => \$Option{RCYCLE},       #  Specify the cycle time to be used for initialization
                 "syncsfc:s"          => \$Option{SYNCSFC},      #  Match the surface dataset hour with the closest cycle hour
                 "ncpus:s"            => \$Option{NCPUS},        #  The requested number of processors when running metgrid
                 "attempts:s"         => \$Option{ATTEMPTS},     #  Number of attempts in getting initialization datasets - Default 1
                 "sleep:s"            => \$Option{SLEEP},        #  Number of seconds to sleep between attempts

                 "debug:s"            => \$Option{DEBUG},        #  Turn on debugging 
                 
                 "dsquery|query:s"    => sub {&Pginfo::QueryGribinfo($_[1])},
                 "dsinfo:s"           => sub {&Pginfo::QueryGribinfo($_[1])},
                 "dslist"             => sub {&Pginfo::QueryGribinfo('list')}, # list out datasets available for initialization

               );  &Phelp::PrepHelpMeError(@ARGV) if @ARGV;  #  Should not get here but just in case


return %Option; 
}



sub CheckPrepOptions {
#==================================================================================
#  This routine does a basic check of the options and flags passed to ems_prep to
#  determine whether they are valid. Additional checks will be done during the
#  configuration stage.
#==================================================================================
#
    my %opts = &Phelp::DefinePrepOptions();  #  Get options list

    #  Do an initial run through of the argument list to make sure each --[option] is valid .
    #
    foreach (@_) {

        next unless /^\-/;   #  It's an argument to an option if not preceded by a '-'
        next if /^\-\d+/;    #  Exclude negative digits - must be arguments
        s/\-//g; $_ = "--$_";
        $_ = lc $_;

        #  Don't worry about --help or --guide
        #
        $_ = '--help'       if /-h$|-he/;
        $_ = '--benchmark'  if /-be/;
        $_ = '--domains'    if /-dom/;
        $_ = '--dset'       if /-dse/;
        $_ = '--noaerosols' if /-noaero/;

        next if $_ eq '--help';
        next if /scour/;  #  Skip - The [no] part is problematic

        #  Test if it's a valid option
        #
        if (defined $opts{$_}) {

            #  check whether flag needs an argument
            #
            if ($opts{$_}{arg} and $opts{$_}{arg} !~ /^\[/) {  #  option requires an argument - check
                my $i = &Others::StringIndexMatchExact($_,@_); $i++;  #  Get the expected index of the argument to test
                &Phelp::PrintPrepOptionHelp($_) if $i > $#_ || $_[$i] =~ /^\-/;    #  Missing or bad argument - print help
            }

        } else {
            my $help = "Try passing \"--help\" for some hand-holding and a list of valid options.";
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,94,0,0,'Making stuff up as you go along?',"Passing \"$_\" will not endear yourself to the UEMS Oligarch.\n\n$help");
            return ();
        }
    }

    
return @_;
}


sub SetPrepOptionValues {
#==================================================================================
#  The &SetPrepOptionValues routine takes the option hash and gives them a value,
#  whether they were passed or not. The $ENV{PMESG} environment variable is used
#  to indicate a failure.
#==================================================================================
#
    my $oref   = shift;
    my %Option = %{$oref};

    #  --------------------------------- Attempt the configuration --------------------------------------------
    #
    #  Note that the order for some configurations is important!
    #
    $Option{BM}           =  &PrepOptionValue('benchmark' ,$Option{BM});     
    $Option{DEBUG}        =  &PrepOptionValue('debug'     ,$Option{DEBUG});
    $Option{FLENGTH}      =  &PrepOptionValue('flength'   ,$Option{FLENGTH});
    $Option{PREVIOUS}     =  &PrepOptionValue('previous'  ,$Option{PREVIOUS}); 
    $Option{RDATE}        =  &PrepOptionValue('rdate'     ,$Option{RDATE});    
    $Option{RCYCLE}       =  &PrepOptionValue('rcycle'    ,$Option{RCYCLE});
    $Option{LOCALGRIB}    =  &PrepOptionValue('localgrib' ,$Option{LOCALGRIB}); 
    $Option{RDSET}        =  &PrepOptionValue('rdset'     ,$Option{RDSET}); 
    $Option{SFCS}         =  &PrepOptionValue('sfcs'      ,@{$Option{SFCS}});
    $Option{LSMS}         =  &PrepOptionValue('lsms'      ,@{$Option{LSMS}});
    $Option{DOMAIN}       =  &PrepOptionValue('domain'    ,$Option{DOMAIN});
    $Option{SCOUR}        =  &PrepOptionValue('scour'     ,$Option{SCOUR});
    $Option{NUDGING}      =  &PrepOptionValue('nudging'   ,$Option{NUDGING});
    $Option{BNDYROWS}     =  &PrepOptionValue('bndyrows'  ,$Option{BNDYROWS});
    $Option{TIMEOUT}      =  &PrepOptionValue('timeout'   ,$Option{TIMEOUT});
    $Option{NODELAY}      =  &PrepOptionValue('nodelay'   ,$Option{NODELAY});
    $Option{NOINTDEL}     =  &PrepOptionValue('nointdel'  ,$Option{NOINTDEL});
    $Option{NOPROCESS}    =  &PrepOptionValue('noprocess' ,$Option{NOPROCESS});
    $Option{HIRESBC}      =  &PrepOptionValue('hiresbc'   ,$Option{HIRESBC});
    $Option{AEROSOLS}     =  &PrepOptionValue('aerosols'  ,$Option{AEROSOLS});
    $Option{NOALTSST}     =  &PrepOptionValue('noaltsst'  ,$Option{NOALTSST});
    $Option{NCPUS}        =  &PrepOptionValue('ncpus'     ,$Option{NCPUS});
    $Option{SLEEP}        =  &PrepOptionValue('sleep'     ,$Option{SLEEP});
    $Option{ATTEMPTS}     =  &PrepOptionValue('attempts'  ,$Option{ATTEMPTS});
    $Option{ANALYSIS}     =  &PrepOptionValue('analysis'  ,$Option{ANALYSIS});
    $Option{SYNCSFC}      =  &PrepOptionValue('syncsfc'   ,$Option{SYNCSFC});
   
    return () if $ENV{PMESG};


return %Option;  
}


sub MatchPrepOptions {
#==================================================================================
#  This routine matched a passed flag to an actual option should the user have
#  used a partial flag name. This is necessary for the help routines.
#==================================================================================
#
use List::Util 'first';

    my $flag = qw{};
    my %flags= ();

    my %opts = &Phelp::DefinePrepOptions();  #  Get options list

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


sub PrepOptionValue {
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


sub Option_analysis {
#==================================================================================
#  Use analyses for initial and boundary conditions
#==================================================================================
#
    my $passed = shift;

    $passed = -1 unless defined $passed;
    $passed = -1 if $Saved{global};  #  Not relevant for a global domain
    $passed =  0 unless $passed;
    $passed = -1 if $passed < 0;
    $passed =  0 if grep (/^cfsr|^era|^narr|^nrrp/i, @{$Saved{dsets}}) and @{$Saved{dsets}} == 1 and $passed == -1;

    if (@{$Saved{dsets}} > 1 and $passed >= 0) {
        my $mesg = "You must specify only one initialization dataset when using the \"--analysis\" flag.\n\n".
                   "Go ahead - Punch out the monitor!";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':'Just getting started?',$mesg);
    }

return $passed;
}


sub Option_attempts {
#==================================================================================
#  Define the number of attempts to make when a acquiring initialization data.
#  Intended for use with ems_autorun. Must be passed along with the --sleep flag.
#==================================================================================
#
    my $passed = shift;

    $passed = (defined $passed and $passed) ? $passed : 1;

    $passed = 3 unless $passed > 0;
    $passed = 3 unless &Others::isInteger($passed);
    $passed = 3 unless $passed < 10;

return $passed;
}



sub Option_sleep {
#==================================================================================
#  Define the number seconds to sleep between attempts to acquire initialization 
#  datasets. Intended for use with ems_autorun. Must be passed along with the 
#  --attempts flag. Default 300s, minimum 30s, maximum 1800s.
#==================================================================================
#
    my $passed = shift;

    $passed = (defined $passed and $passed) ? $passed : 300;

    $passed = 30   unless $passed > 30;
    $passed = 300  unless &Others::isInteger($passed);
    $passed = 1800 unless $passed < 1800;

return $passed;
}



sub Option_benchmark {
#==================================================================================
#  Turn ON the benchmark case - This flag is no longer necessary but it's easier
#  to keep it even though it doesn't do anything since $Saved{bm} gets assigned
#  during the initialization step.
#==================================================================================
#
    my $passed = shift;

    $passed = $Saved{bm};

return $passed;
}


sub Option_bndyrows {
#==================================================================================
#  Process only N outer rows used for the lateral boundaries. Default is 5.
#  Not passed or bad value turns this option OFF.
#==================================================================================
#
    my $passed = shift; 

    $passed = 0 unless defined $passed;
    $passed = 0 if $passed < 0 or $passed > 10;

    &Ecomm::PrintMessage(6,8,104,1,2,"Ignoring \"--bndyrows\" flag - not compatible with \"--nudging\"") if $passed and $Saved{nudging};
    $passed = 0 if $Saved{nudging};  # Turn OFF with nudging

    #  Value will be written to $Uprep{masternl}{METGRID}{process_only_bdy}[0] in the interpolation
    #  routine so use an empty character string instead of 0.
    #
    $passed = '' unless $passed;

return $passed;
}


sub Option_domain {
#==================================================================================
#  Process initialization files for domains 1 ... --domains #
#  Arguments to the --domain flag are --domain <number>[:<start hour>],<number>...,
#  where the <start hour> is the number of hours after the start of the primary
#  domain. The routine returns a string 
#
#  Additional configuration is done the Pconf module.
#==================================================================================
#
    my @rdoms = ();
    my $mesg  = '';

    my $passed = shift;

    return '' unless defined $passed and $passed;

    foreach (split /,|;/ => $passed) {

        my ($dom, $hour) = split /:/ => $_, 2;
        next unless $dom =~ /(\d)+/; $dom+=0;
        next if $dom <= 1;

        $hour = 0 unless defined $hour and &Others::isInteger($hour);
        $hour+= 0;
        $hour = 0 unless $hour > 0;

        #  Now that the above is over with - 
        #
        if ($dom > $Saved{maxdoms}) {
            $mesg = "Domain $dom does not exist - Only 1 .. $Saved{maxdoms}";
            $mesg = "Domain $dom does not exist - Only Domain 1" if $Saved{maxdoms} == 1;
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':'Counting was never my strength either!',$mesg);
            return '';
        }


        if (@{$Saved{dsets}} > 1 and $hour > 0) {
            my $str = join " & ",@{$Saved{dsets}};
            $mesg = "Unfortunately, you can not begin a nested simulation after the start of the Primary domain (+$hour hours) ".
                    "when initializing with multiple datasets ($str).";
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':"It's the UEMS LAW!",$mesg);
            return '';
        }
        push @rdoms => "$dom:$hour";  #  @rdoms is an array of user specified domains

        #  We have a slight problem in that the --hiresbc flag should be passed when a nested
        #  domain start hour falls between BC update times; however, to set the --hiresbc flag
        #  automatically, we need information that will not be collected until later (BC update
        #  frequency).  As a kludge, it will be assumed that if the start hour for any nested
        #  domain is not evenly divisible by 3 (hours), then hiresbc needs to be set.
        #
        #  This workaround does not work when the BC update interval is 6 through.
        # 
        $Saved{hiresbc} = 1 if $hour%3;

    }

    @rdoms = &Others::rmdups(@rdoms);
    $passed = join ',' => sort @rdoms;

return $passed;
}



sub Option_debug {
#==================================================================================
#  Define the value for option "--debug".  This option may be an integer value
#  between 1 & 4 or a character string, "ungrib" or "metgrid".  The "ungrib" and
#  "metgrid" strings get converted to debug levels "5" and "6" respectively.
#==================================================================================
#
    my $passed = shift;

    return 0 unless defined $passed;
    return 1 if $passed =~ /\d/ or ! $passed;
    return 4 if $passed =~ /^ptile/i;
    return 5 if $passed =~ /^degr|^ungr/i;
    return 6 if $passed =~ /^met/i;

return 0;
}


sub Option_flength {
#==================================================================================
#  Define the forecast length.  For this option a placeholder will be used 
#  and eventually replaced with a value in hours.
#==================================================================================
#
    my $passed = shift;

    $passed = 0 unless defined $passed and $passed;

    #  The silly user passed a non-digit
    #
    unless (&Others::isInteger($passed)) {
        my $mesg = "The argument to \"--length\" is supposed to be the integer number of hours ".
                   "over which the primary domain is to be integrated. You passed \"--length $passed\".";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':'UEMS school is in session!',$mesg);
        return '';
    }

    #  Make sure user does not override length of benchmark simulation
    #
    $passed = 30 if $Saved{bm} and ($passed > 30 or $passed <= 0);

    $Saved{flength} = $passed;

return $passed;
}


sub Option_hiresbc {
#==================================================================================
#  Interpolate between BC file times to create hourly BC files
#==================================================================================
#
    my $passed = shift;
     
    $passed = 1 if $Saved{hiresbc};  #  See comments in &Option_domain

return (defined $passed and $passed) ? 1 : 0;
}


sub Option_localgrib {
#==================================================================================
#  Only check for initialization files in local directory
#==================================================================================
#
    my $passed = shift;

    $passed = (defined $passed and $passed) ? 1 : 0;

    $Saved{local} = $passed;

return $passed;
}


sub Option_lsms {
#==================================================================================
#  Process arguments passed with the --lsm flag
#==================================================================================
#
    return '' unless @_;  #  --lsm was not passed

    my @array = grep {$_} @_;  #  Eliminate empty lists that are passed

    unless (@array)  {
        my $mesg = "When passing the \"--lsm\" flag you must provide an argument. Simply passing ".
                   "\"--lsm\" by itself does neither of us any good (especially you). Come on, show ".
                   "me you care, show me you want this!";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':'One of us is holding you back!',$mesg);
        return '';
    }

    my $passed = join "," => @array;

    return '' if $Saved{bm};

    $passed =~ s/%+/,/g;
    $passed =~ s/,+/,/g;
    $passed =~ s/ptiles|ptile/pt/g;

    my @lmsets = split ',' => $passed;

    #  Make sure the arguments are properly formatted
    #
    foreach (@lmsets) {

        my ($dset,$method,$server,$path) = split /:/ => $_, 4;

        foreach ($dset,$method,$server,$path) {$_ = '' unless $_;}

        unless ($dset) {
            my $mesg = "No dataset was specified for --lsm <dataset>[:<method>:<source>:<path>]";
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':'Disappearing dataset!',$mesg);
            return '';
        }

        $dset =~ s/pt$//g if $Saved{global}; #  No personal tiles for global datasets


        if ($method and $method !~ /ftp|http|nfs|none/i) {
            my $mesg = "Invalid acquisition method requested ($method). Only [no]ftp|[no]http|[no]nfs|none supported.";
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,94,0,2,$ENV{PMESG}?'':'What method is this?',$mesg);
            return '';
        }

        if ($Saved{local}) {  #  Override when the --local flag is passed
            $method = 'none';
            $server = '';
            $path   = '';
        }

        $_ = join ':' => ($dset,$method,$server,$path);
        $_ =~ s/(:+)$//g;

        push @{$Saved{lsms}} => $dset;

    }
    $passed = join ',' => reverse @lmsets;


return $passed;
}


sub Option_noaltsst {
#==================================================================================
#  Do not use the alternate method for water temperatures in the absence of data
#  No be eligible to use the alternative method the domain must be localized 
#  with the --lakes option; otherwise $passed is set to 1 by default and the
#  --noaltlakes is useless.
#==================================================================================
#
    my $passed = shift;

    $passed = (defined $passed and $passed) ? 1 : 0;  #  If --noaltsst was passed

    $passed = 1 unless $Saved{islake}; #  Can't use alternative method unless --lakes used to localize

    #  If not passed, meaning that the alternative method is to be used (default)
    #  then check whether the avg_tsfc exists. If not, then turn option off.
    #
    unless ($passed or -s "$ENV{EMS_UBIN}/avg_tsfc") {
        my $mesg = "Turning alternate surface water temperature method OFF since I am unable to locate $ENV{EMS_UBIN}/avg_tsfc";
        &Ecomm::PrintMessage(6,8,88,1,2,$mesg);
        $passed = 1;
    }


return $passed;
}


sub Option_nodelay {
#==================================================================================
#  Set the DELAY value to 0 (no delay)
#==================================================================================
#
    my $passed = shift;

    $passed = 1 if $Saved{bm};

return (defined $passed and $passed) ? 1 : 0;
}


sub Option_nointdel {
#==================================================================================
#  Do not delete the intermediate files after processing
#==================================================================================
#
    my $passed = shift;

    $passed = 0 if $Saved{bm};

return (defined $passed and $passed) ? 1 : 0;
}


sub Option_noprocess {
#==================================================================================
#  Do not processes the grid files for model initialization
#==================================================================================
#
    my $passed = shift;

return (defined $passed and $passed) ? 1 : 0;
}



sub Option_nudging {
#==================================================================================
#  Process requested domains for 3D Analysis/Spectral Nudging
#==================================================================================
#
    my $passed = shift;

    $passed = (defined $passed and $passed) ? 1 : 0;

    $Saved{nudging} = $passed;

return $passed;
}



sub Option_ncpus {
#==================================================================================
#  Process requested number of processors used when running metgrid
#==================================================================================
#
    my $passed = shift;

    $passed = (defined $passed and $passed) ? $passed : 0;

    #  Make sure the argument passed to --ncpus was a non negative integer
    #
    my $mesg = "The argument passed to \"--ncpus\" must be in the form of an positive integer since you are specifying ".
               "the number of processors to use when localizing your domain.\n\n".
               "Maybe a bit of school'n will help:  %  ems_prep --help ncpus";
    $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':'More from: "When Good Arguments Go Bad"',$mesg) unless $passed =~ /^(\d)+$/;


return $passed;
}



sub Option_previous {
#==================================================================================
#  Use the previous cycle of the dataset rather then the current one
#==================================================================================
#
    my $passed = shift;

    $passed = (defined $passed and $passed) ? 1 : 0;

    $Saved{previous} = $passed;

return $passed;
}


sub Option_rcycle {
#==================================================================================
#  Manage the argument passed to --cycle
#==================================================================================
#
    my $string = 'CYCLE:INITFH:FINLFH:FREQFH';
    my @slist  = split /:/ => $string;

    my $passed = shift;


    if (defined $passed and ! length $passed)  {
        my $mesg = "When passing the \"--cycle\" flag you must provide an argument. Simply passing ".
                   "\"--cycle\" by itself does neither of us any good (especially you). Come on, show ".
                   "me you care, show me you want this!";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':'One of us is holding you back!',$mesg);
        return '';
    }


    #  The --date or --cycle flag may not be passed with --previous. It's the law!
    #
    if (defined $passed and $Saved{previous}) {
        my $mesg = "Unfortunately, you can not pass the \"--cycle\" and \"--previous\" flags together.\n\n".
                   "The UEMS understands that life can suck sometimes, but at least you are still awesome!";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':'Well, at least we have each other!',$mesg);
        return '';
    }

    #  Define if benchmark run - may be overridden if --length flag is passed
    #
    return '06:00:30:06' if $Saved{bm};
    return $string unless (defined $passed and length $passed);


    $passed   =~ s/,|;/:/g; #  replace with colons
    my @plist = split /:/ => $passed;
    
    foreach (0 .. $#plist) { 
        $slist[$_] = sprintf("%02d", $plist[$_]) if length $plist[$_] and $plist[$_] !~ /\D/;
    }
    $passed = join ':' =>  @slist;

return $passed;
}


sub Option_rdate {
#==================================================================================
#  Specify the date of the files used for initialization.
#==================================================================================
#
    my $passed = shift;

    $passed = '20110427' if $Saved{bm};  #  Current benchmark case is from 27 April 2011

    if (defined $passed and ! length $passed)  {
        my $mesg = "When passing the \"--date\" flag you must provide an argument. Simply passing ".
                   "\"--date\" by itself does neither of us any good (especially you). Come on, show ".
                   "me you care, show me you want this!";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':'One of us is holding you back!',$mesg);
        return 0;
    }
    $passed = 0 unless defined $passed;

    
    #  The --date or --cycle flag may not be passed with --previous. It's the law!
    #
    if ($passed and $Saved{previous}) {
        my $mesg = "Unfortunately, you can not pass the \"--date\" and \"--previous\" flags together.\n\n".
                   "The UEMS understands that life can suck sometimes, but at least you are still awesome!";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':'Well, at least we have each other!',$mesg);
        return 0;
    }


    #  The silly user passed a non-digit
    #
    unless (&Others::isInteger($passed) or length $passed <= 8) {
        my $mesg = "The argument to \"--date\" is supposed to be a string of 8 digits in the format ".
                   "of \"--date YYYYMMDD\".\n\nMaybe you missed the \"Numbers & Me\" lesson during the ".
                   "Elmo does the UEMS video marathon, but consider yourself schooled.";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':'School is in session!',$mesg);
        return 0;
    }

    if (length $passed == 6) {$passed = (substr($passed,0,2)<45) ? "20${passed}" : "19${passed}";}


    unless (! $passed or $passed =~ /^\d{8}$/) {
        my $mesg = "The argument to \"--date\" is supposed to be a string of 8 digits in the format ".
                   "of \"--date YYYYMMDD\".\n\nMaybe you missed the \"Numbers & Me\" lesson during the ".
                   "Elmo does the UEMS video marathon, but consider yourself schooled.";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':'School is in session!',$mesg);
        return 0;
    }


    if ($passed > $Saved{yyyymmdd}) {
        my $mesg = "The date you requested \"--date $passed\", appears to be in the future, which is not ".
                   "allowed under current space-time physics rules (go look it up). Thus, you will have ".
                   "to do it again, and do it correctly this time.";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':'Einstein would be disappointed in you!',$mesg);
        return 0;
    }


    #  Test for an incorrect date from the Perl Time utility
    #
    if ($passed) {

        my $sdate = "${passed}00";

        my $tdate = substr(&Others::CalculateNewDate($sdate,0),0,10);

        if ($tdate > $sdate) {
            my $mesg = "The Perl time module is returning an invalid date/time. This problem usually ".
                       "occurs when the initialization date of your simulation is more than 50 years older ".
                       "than the current system date.  To fix the problem you can either temporarily modify ".
                       "the Perl library or reset your system clock but I can't allow you to dig ".
                       "a deeper hole until you remedy this situation.";
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':"Simulation Start Date ($passed) and Perl - A Match Not Made in UEMS HQ!",$mesg);
            return $passed;
        }

    }
    $Saved{rdate} = $passed;


return $passed;
}



sub Option_rdset {
#==================================================================================
#  Dataset options in the form of <dataset>:<method>:<source>:<path>
#==================================================================================
#
    my $passed = shift;

    $passed = 'cfsr:none' if $Saved{bm};

    unless (defined $passed and $passed) {
        my $mesg = "Maybe you were absent during UEMS \"Indoctrination Fridays\", but the  \"--dset <dataset>\" flag ".
                   "is one of the few required when running ems_prep. The UEMS Elders won't hold this oversight ".
                   "against you, but don't do it again. Besides, the UEMS awesome train is leaving the station and ".
                   "you want to be on board.\n\nSee \"--help dset\" for more information.";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,92,0,2,$ENV{PMESG}?'':"I can't see you but I'm still watching!",$mesg);
        return '';
    }


    $passed =~ s/ptiles|ptile/pt/g;
    $passed =~ s/,+/%/g;
    $passed =~ s/;/:/g;

    my @rdsets = split /%/ => $passed; my $nd = @rdsets;


    if ($nd > 2) {
        my $mesg = "You may specify a maximum of 2 different datasets, separated by '%', to serve ".
                   "as the initial and boundary conditions with the \"--dset\" option. So let's try ".
                   "it again.\n\nSee \"--help dset\" for more information.";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':'Hey Trouble Maker!',$mesg);
        return '';
    }

    if ($nd > 1 and ! $Saved{flength}) {
        my $mesg = "You must specify the forecast length, in hours, using the \"--length <hours>\" ".
                   "option when using different datasets for initial and boundary conditions.";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':'Hello There!',$mesg);
        return '';
    }

    

    
    if ($nd > 1 and $Saved{global}) {

         my $udset= uc $rdsets[0];
         my $mesg = "The last time I checked, a boundary condition dataset ($rdsets[1]) is not needed ".
                    "when running over a global domain. The fact that you included one as an argument ".
                    "to \"--dset\" suggests you believe otherwise. I'll just save you the embarrassment ".
                    "of public humiliation and forget about this transgression while carrying on with just ".
                    "the $udset as if nothing ever happened.";
         &Ecomm::PrintMessage(6,8,94,1,2,'Move along, there is nothing to see here ...',$mesg);

         my $dset = $rdsets[0];
         @rdsets  = ();
         push @rdsets => $dset;
         $nd = 1;
     }
        

    #  Make sure the arguments are properly formatted
    #
    foreach (@rdsets) {

        my ($dset,$method,$server,$path) = split /:/ => $_, 4;   

        foreach ($dset,$method,$server,$path) {$_ = '' unless $_;}

        unless ($dset) {
            my $mesg = "No dataset was specified for --dset <dataset>[:<method>:<source>:<path>]";
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':'Disappearing dataset!',$mesg);
            return '';
        }


        $dset =~ s/pt$//g if $Saved{global}; #  No personal tiles for global datasets


        if ( ($dset =~ /^cfsr/) and ($dset !~ /pt$/) ) {
            $dset = ($Saved{rdate} and $Saved{rdate} < 20110401) ? 'cfsrv1' : 'cfsrv2';
        }

        if ($method and $method !~ /ftp|http|nfs|none/i) {
            my $mesg = "Invalid acquisition method requested ($method). Only [no]ftp|[no]http|[no]nfs|none supported.";
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,94,0,2,$ENV{PMESG}?'':'What method is this?',$mesg);
            return '';
        }

        if ($Saved{local}) {  #  Override when the --local flag is passed
            $method = 'none';
            $server = '';
            $path   = '';
        }

        $_ = join ':' => ($dset,$method,$server,$path);
        $_ =~ s/(:+)$//g;
        
        push @{$Saved{dsets}} => $dset;

    }
    $passed = join '%' => @rdsets;

return $passed;
}


sub Option_scour {
#==================================================================================
#  Define the value for option "--scour". Note that the --[no]scour option 
#  controls the amount of cleaning to be done prior for the start of ems_prep.
#  The default, or if --scour is not passed, is the same as ems_clean --level 3.
#  The --noscour flag is the same as ems_clean --level 0 and the --scour flag
#  is the same as ems_clean --level 4.
#==================================================================================
#
    my $passed = shift;

    $passed = (defined $passed) ? $passed ? 4 : 0 : 3;
    $passed = 3 if $Saved{bm};

return $passed;
}


sub Option_sfcs {
#==================================================================================
#  Process arguments passed with the --sfc flag
#==================================================================================
#
    return '' unless @_;  #  --sfc was not passed

    my @array = grep {$_} @_;  #  Eliminate empty lists that are passed

    unless (@array)  {
        my $mesg = "When passing the \"--sfc\" flag you must provide an argument. Simply passing ".
                   "\"--sfc\" by itself does neither of us any good (especially you). Come on, show ".
                   "me you care, show me you want this!";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':'One of us is holding you back!',$mesg);
        return '';
    }

    my $passed = join "," => @array;

    return '' if $Saved{bm};

    $passed =~ s/%+/,/g;
    $passed =~ s/,+/,/g;
    $passed =~ s/ptiles|ptile/pt/g;

    my @sfsets = split ',' => $passed;

    #  Make sure the arguments are properly formatted
    #
    foreach (@sfsets) {

        my ($dset,$method,$server,$path) = split /:/ => $_, 4;

        foreach ($dset,$method,$server,$path) {$_ = '' unless $_;}

        unless ($dset) {
            my $mesg = "No dataset was specified for --sfc <dataset>[:<method>:<source>:<path>]";
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,88,0,2,$ENV{PMESG}?'':'Disappearing dataset!',$mesg);
            return '';
        }

        $dset =~ s/pt$//g if $Saved{global}; #  No personal tiles for global datasets


        if ($method and $method !~ /ftp|http|nfs|none/i) {
            my $mesg = "Invalid acquisition method requested ($method). Only [no]ftp|[no]http|[no]nfs|none supported.";
            $ENV{PMESG} = &Ecomm::TextFormat(0,0,94,0,2,$ENV{PMESG}?'':'What method is this?',$mesg);
            return '';
        }

        if ($Saved{local}) {  #  Override when the --local flag is passed
            $method = 'none';
            $server = '';
            $path   = '';
        }

        $_ = join ':' => ($dset,$method,$server,$path);
        $_ =~ s/(:+)$//g;

        push @{$Saved{sfcs}} => $dset;

    }
    $passed = join ',' => @sfsets;


return $passed;
}



sub Option_syncsfc {
#==================================================================================
#  syncsfc tells the EMS to select the SFC data used for initialization such that
#  the validation hour is closest in time to the model initialization hour. When using
#  syncsfc, the EMS will ignore other available data times within a 24 hour day in favor
#  of a dataset that best matches the simulation initialization hour. The EMS will look
#  for datasets with the same validation hour going back over the period of N days as
#  defined by the AGED parameter in the <dataset>_gribinfo.conf file.
#==================================================================================
#
    my @syncs  = ();
    my $passed = shift;

    #  If flag was not passed then turn OFF for all surface datasets
    #
    return 0 unless defined $passed and @{$Saved{sfcs}};

    #  If flag was passed without arguments then turn ON for all
    #
    $passed = join ',' => @{$Saved{sfcs}} unless $passed;

    $passed =~ s/ptiles|ptile/pt/g;

    my @list = split /,|;|:/ => $passed if $passed;

    #  Eliminate datasets not included with --sfc flag (@{$Saved{sfcs}});
    #
    foreach my $sync (@list) {
        unless (grep (/^$sync$/i, @{$Saved{sfcs}}))  { 
            &Ecomm::PrintMessage(6,8,88,1,2,"Sync surface dataset \"--syncsfc $sync\" not requested with \"--sfc\" - Skipped");
            next;
        }
        push @syncs => $sync;
    }


return @syncs ? join ',' => @syncs : 0;
}


sub Option_aerosols {
#==================================================================================
#  Flag to not include monthly aerosol climatology for use with the Thompson 
#  Aerosol Aware MP scheme (28). The default is to always include this data
#  set in anticipation of the Thompson Aerosol Aware MP scheme being used.
#==================================================================================
#
    my $passed = shift;  

    #-----------------------------------------------------------------------------
    #  If the user passed --noaerosols, then just get out.
    #-----------------------------------------------------------------------------
    #
    return 0 if defined $passed and $passed;

    #-----------------------------------------------------------------------------
    #  Otherwise, assign the data file to be read when running metgrid.
    #-----------------------------------------------------------------------------
    #
    $passed = "$ENV{DATA_TBLS}/aerosol/QNWFA_QNIFA_SIGMA_MONTHLY.dat";

    
    #-----------------------------------------------------------------------------
    #  Make sure the file exists
    #-----------------------------------------------------------------------------
    #
    unless (-s $passed) {
        my $aerosol = &Others::popit($passed);
        my $mesg = "The monthly aerosol climatology data for the $Saved{dsets}[0] dataset ".
                   "($aerosol) should be located in $ENV{DATA_TBLS}/aerosol, but either I ".
                   "can't read or it's missing. Either way, you are not getting the simulation ".
                   "that you deserve!";
        &Ecomm::PrintMessage(6,8,94,1,2,'Aerosol Climatology Dataset',$mesg);
        $passed = 0;
    }


return $passed;
}


sub Option_timeout {
#==================================================================================
#  set the MPI timeout value for metgrid.  The default value is 1199 seconds and
#  a value of 0 turns this option OFF. If the option is not passed then assign 
#  -1, in which case defer to the global file value.
#
#  Again:  --timeout not passed   -  set timeout = -1  (defer to config file)
#          --timeout 0            -  set timeout = 0 (turn off)
#          --timeout              -  set timeout = 0 (turn off)
#          --timeout <value>      -  set timeout = <value> (override config file)
#==================================================================================
#
    my $passed = shift;

    $passed = -1 unless defined $passed;
    $passed =  0 unless $passed;
    $passed = -1 unless $passed =~ /(\d)+/; 
    $passed = -1 if $passed < 0;
    $passed = -1 if $passed > 3600;

return $passed;
}


