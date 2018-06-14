#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Doptions.pm
#
#  DESCRIPTION:  Doptions contains each of the primary routines used for the
#                reading and interpreting the many command line options and
#                flags passed to ems_domain.
#
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Doptions;

use warnings;
use strict;
require 5.008;
use English;

use Ecomm;
use Ecore;
use Others;
use Dutils;


sub Domain_Options {
#==================================================================================
#  Front end to the GetDomainOptions routine
#==================================================================================
#
      my %Options  = ();

      my $upref    = shift;
      my %Udomain = %{$upref};

      %Options         = &GetDomainOptions();
      %Options         = &SetDomainOptionValues(\%Options);

      %{$Udomain{OPTIONS}} = %Options;
     
return %Udomain;
}


sub GetDomainOptions {
#===============================================================================
#  The GetDomainOptions routine parses the flags and options passed
#  from the command line. Simple enough.
#===============================================================================
#
use Getopt::Long qw(:config pass_through);
use Time::Local;
use Dhelp;

    my %Option = ();


    #  Do an initial check of the options and flags to look for obvious problems
    #
    @ARGV = &CheckDomainOptions(@ARGV);


    GetOptions ( "h|help|?"           => sub {&Dhelp::DomainHelpMe(@ARGV)},   #  Just what the doctor ordered

                 "core:s"             => \$Option{CORE},             #  The model core (Currently ARW) that the domain will use (Use with --create)
                 "create:s"           => \$Option{CREATE},           #  Create a new computational domain DOMAIN
                 "newdom:s"           => \$Option{NEWDOM},           #  Create a new computational domain DOMAIN (DWIZ Only)
                 "update:s"           => \$Option{UPDATE},           #  Update an existing domain directory with DWIZ Only
                 "dxres"              => \$Option{DXRES},            #  Calculate the default resolution based upon grid spacing
                 "dwiz"               => \$Option{DWIZ},             #  Passed by DWIZ to indicate that the routine is being run from DWIZ
                 "debug:s"            => \$Option{DEBUG},            #  Turns on the debugging and prints out additional information
                 "force"              => \$Option{FORCE},            #  Delete an existing DOMAIN domain when using --create and --import
                 "defres"             => \$Option{DEFRES},           #  Replace the resolution of the geog datasets specified in the namelist file with WRF defaults.
                 "gwdo"               => \$Option{GWDO},             #  Use the appropriate GWD dataset resolution for each domain (Default: 10m for all)

                 #  The following options apply only to global domains
                 #
                 "global"             => \$Option{GLOBAL},           #  Create a global domain
                 "g_nests:s"          => \$Option{G_NESTS},          #  Specify nested domains to be included in a global domain    - Global Only
                 "g_dxdy:s"           => \$Option{G_DXDY},           #  Define the spacing between horizontal grid points at the equator - Global Only
                 "g_useny"            => \$Option{G_USENY},          #  Retain the value of e_sn specified in the namelist file     - Global Only
                 "g_nx:i"             => \$Option{G_NX},             #  Define the number of grid points along a latitude circle    - Global Only
                 "g_ny:i"             => \$Option{G_NY},             #  Define the number of grid points along a longitude circle   - Global Only

                 "import:s"           => \@{$Option{IMPORTS}},       #  Transfer previous run-time directory from DIR and localize'
                 "info:s"             => \$Option{INFO},             #  Simply list the domain configuration information and exit
                 "lakes!"             => \$Option{LAKES},            #  [Do not] Include the USGS or MODIS lakes dataset
                 "localize:s"         => \$Option{LOCALIZE},         #  Localize an existing computational domain
                 "modis"              => \$Option{MODIS},            #  Request the MODIS land use dataset.  - Depricated
                 "mcserver"           => \$Option{MCSERVER},         #  Only passed by UEMS Mission Control - Turns off copying of default config files into local dir
                 "usgs"               => \$Option{USGS},             #  Request the USGS land use dataset.   - Depricated
                 "landuse:s"          => \$Option{LANDUSE},          #  Specify the land use dataset to use (Default: MODIS; LSM scheme dependent)!
                 "topo:s"             => \$Option{TOPO},             #  Specify the topography dataset to use (gmted2010 or gtopo; Default gmted2010)
                 "gfrac:s"            => \$Option{GFRAC},            #  Specify the greenness fraction dataset to use (modis or nesdis; Default modis) 
                 "stype:s"            => \$Option{STYPE},            #  Specify the soil type data set to use bnu or default
                 "ncpus:s"            => \$Option{NCPUS},            #  Request the number of processors to use when running geogrid
                 "refresh"            => \$Option{REFRESH},          #  Refresh configuration files in the current directory or in argument
                 "restore"            => \$Option{RESTORE},          #  Restore the domain to the default configuration (conf & static files)
                 "rotate"             => \$Option{ROTATE},           #  Rotate the pole latitude & longitude - Lat-Lon Domains only
                 "rundir:s"           => \$Option{RUNDIR},           #  Location where the target domain resides.
                 "scour!"             => \$Option{SCOUR},            #  Define the level of scouring of the files from domain directory

#                "ems:s"              => \$Option{NOTUSED},          #  Legacy support for the previous version of DW
#                "guide"              => sub {&Dhelp::DomainGuideMe} #  Additional gentle guidance should you be interested
            
               );  # &Dhelp::DomainHelpMeError(@ARGV) if @ARGV;  #  Should not get here but just in case


return %Option; 
}


sub CheckDomainOptions {
#===============================================================================
#  This routine does a basic check of the options and flags passed to ems_Domain to
#  determine whether they are valid. Additional checks will be done during the
#  configuration stage.
#===============================================================================
#
    my %full = ();
    my %opts = &Dhelp::DefineDomainOptions();  #  Get list of options

    my @list = @_;

    #  Do an initial run through of the argument list to make sure each --[option] is valid .
    #
    foreach (@list) {

        next unless /^\-\-/;   #  It's an argument to an option if not preceded by a '-'

        my $opt = $_; 

        $_ = &MatchDomainOptions($opt);

        #  Test if it's a valid option
        #
        if (defined $_ and defined $opts{$_}) {

            if ($opts{$_}{arg} and $opts{$_}{arg} !~ /^\[/) {         #  If the flag requires an argument 
                my $i = &Others::StringIndexMatchExact($opt,@_); $i++;  #  Get the index of the argument to test
                &Dhelp::PrintDomainOptionHelp($_) if $i > $#_ || $_[$i] =~ /^\-/;    #  Missing or bad argument - print help
            }

        } else {
            my $help = "Try passing \"--help\" for some hand-holding and a list of valid flags.";
            &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,94,0,0,'Making stuff up as you go along?',"Passing \"$opt\" will not endear yourself to the UEMS Oligarch.\n\n$help"));
        }

    }


return @_;
}


sub MatchDomainOptions {
#=====================================================================================
#  This routine matched a passed flag to an actual option should the user have
#  used a partial flag name. This is necessary for the help routines.
#=====================================================================================
#
use List::Util 'first';

    my $flag = qw{};
    my %flags= ();

    my %opts = &Dhelp::DefineDomainOptions();  #  Get options list

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


sub SetDomainOptionValues {
#===============================================================================
#  The SetDomainOptionValues takes the option hash and gives them a value, whether 
#  they were  passed or not.
#===============================================================================
#
    my $oref   = shift;
    my %Option = %{$oref};

    #  --------------------------------- Attempt the configuration --------------------------------------------
    #
    $Option{CORE}       =  &DomainOptionValue('core'    ,$Option{CORE});
    $Option{NEWDOM}     =  &DomainOptionValue('newdom'  ,$Option{NEWDOM});
    $Option{CREATE}     =  &DomainOptionValue('create'  ,$Option{CREATE});
    $Option{UPDATE}     =  &DomainOptionValue('update'  ,$Option{UPDATE});
    $Option{DXRES}      =  &DomainOptionValue('dxres'   ,$Option{DXRES});
    $Option{DEBUG}      =  &DomainOptionValue('debug'   ,$Option{DEBUG});
    $Option{DWIZ}       =  &DomainOptionValue('dwiz'    ,$Option{DWIZ});
    $Option{FORCE}      =  &DomainOptionValue('force'   ,$Option{FORCE});  
    $Option{DEFRES}     =  &DomainOptionValue('defres'  ,$Option{DEFRES});
    $Option{GWDO}       =  &DomainOptionValue('gwdo'    ,$Option{GWDO});

    $Option{GLOBAL}     =  &DomainOptionValue('global'  ,$Option{GLOBAL});
    $Option{G_DXDY}     =  &DomainOptionValue('gdxdy'   ,$Option{G_DXDY});
    $Option{G_NX}       =  &DomainOptionValue('gnx'     ,$Option{G_NX});
    $Option{G_NY}       =  &DomainOptionValue('gny'     ,$Option{G_NY});
    $Option{G_USENY}    =  &DomainOptionValue('guseny'  ,$Option{G_USENY});
    $Option{G_NESTS}    =  &DomainOptionValue('gnests'  ,$Option{G_NESTS});

    @{$Option{IMPORTS}} =  &DomainOptionValue('import'  ,@{$Option{IMPORTS}});
    $Option{INFO}       =  &DomainOptionValue('info'    ,$Option{INFO});  
    $Option{LAKES}      =  &DomainOptionValue('lakes'   ,$Option{LAKES});
    $Option{LOCALIZE}   =  &DomainOptionValue('localize',$Option{LOCALIZE});
    $Option{MCSERVER}   =  &DomainOptionValue('mcserver',$Option{MCSERVER});
    $Option{NCPUS}      =  &DomainOptionValue('ncpus'   ,$Option{NCPUS});
    $Option{REFRESH}    =  &DomainOptionValue('refresh' ,$Option{REFRESH});   
    $Option{RESTORE}    =  &DomainOptionValue('restore' ,$Option{RESTORE});
    $Option{ROTATE}     =  &DomainOptionValue('rotate'  ,$Option{ROTATE});
    $Option{RUNDIR}     =  &DomainOptionValue('rundir'  ,$Option{RUNDIR});
    $Option{SCOUR}      =  &DomainOptionValue('scour'   ,$Option{SCOUR});   
    $Option{MODIS}      =  &DomainOptionValue('modis'   ,$Option{MODIS});  #  Depricated
    $Option{USGS}       =  &DomainOptionValue('usgs'    ,$Option{USGS});   #  Depricated
    $Option{TOPO}       =  &DomainOptionValue('topo'    ,$Option{TOPO});
    $Option{GFRAC}      =  &DomainOptionValue('gfrac'   ,$Option{GFRAC});
    $Option{LANDUSE}    =  &DomainOptionValue('landuse' ,$Option{LANDUSE});
    $Option{STYPE}      =  &DomainOptionValue('stype'   ,$Option{STYPE});

    return () if $ENV{DMESG};

return %Option;  
}


sub DomainOptionValue {
#===============================================================================
#  This routine manages the configuration of each user option/flag.  It's basically
#  just an interface to the individual option configuration routines.
#===============================================================================
#
    my $flag = q{};
    my @args = ();

    ($flag, @args) = @_;

    my $subroutine = "&Option_${flag}(\@args)";

return eval $subroutine;
}


sub Option_core {
#===============================================================================
#  Define the model core for the creation of a domain. This flag is only valid
#  with --create and currently only has 'arw' as an option.
#===============================================================================
#
    my $passed = shift; return 'ARW'  unless defined $passed;   

return 'ARW';
}


sub Option_create {
#===============================================================================
#  Define the value for the --create flag has an optional argument in the name
#  of the domain to create
#===============================================================================
#
use Cwd;

    my $passed = shift || return 0;

    #  Check whether just the domain directory was passed.  If the user just passed just the
    #  name of the top level directory then use 'RUNDIR' as a placeholder until the full
    #  path can be resolved in the configuration module.
    #
    my @list = split /\// => $passed;
    $passed = $#list ? $list[$#list] : $passed;

return $passed;
}


sub Option_newdom {
#===============================================================================
#  Define the value for the --newdom flag has an optional argument in the name
#  of the domain to newdom. Note that the --newdom flag is deprecated and will
#  be removed once the developer recompiles Domain Wizard.  User's should
#  embrace the --create flag instead even id DWIZ doesn't.
#===============================================================================
#
use Cwd;

    my $passed = shift || return 0;

    #  Check whether just the domain directory was passed.  If the user just passed just the
    #  name of the top level directory then use 'RUNDIR' as a placeholder until the full
    #  path can be resolved in the configuration module.
    #
    my @list = split /\// => $passed;
    $passed = $#list ? $list[$#list] : $passed;

return $passed;
}


sub Option_update {
#===============================================================================
#  Define the value for the --update flag has an optional argument in the name
#  of the domain to update. This flag is the same as --refresh but is passed
#  by DWIZ along with the domain name as as argument. The inclusion of this
#  flag is simply a hack to avoid gettign into the bowels of DWIZ to fix
#  the call to ems_domain.
#===============================================================================
#
use Cwd;

    my $passed = shift || return 0;

    #  Check whether just the domain directory was passed.  If the user just passed just the
    #  name of the top level directory then use 'RUNDIR' as a placeholder until the full
    #  path can be resolved in the configuration module.
    #
    my @list = split /\// => $passed;
    $passed = $#list ? $list[$#list] : $passed;

return $passed;
}


sub Option_dxres {
#===============================================================================
#  Define the value for the --dxres flag, which is used to specify the default
#  resolution for the static datasets based upon the domain grid spacing. This
#  was the approach prior to WRF V3.8 but now the preferred method is to use
#  the default value defined in the GEOGRID.TBL for each dataset. Passing
#  --dxres returns the pre- WRFV3.8 experience.
#===============================================================================
#
    my $passed = shift;

       $passed = (defined $passed) ? 1 : 0;

return $passed;
}


sub Option_debug {
#===============================================================================
#  Define the value for the --debug flag. This flag may be an integer value
#  between 1 & 4 or a character string, "geogrid".  The "geogrid' string gets
#  assigned a debug level of 5.
#===============================================================================
#
    my $passed = shift;

    return 0 unless defined $passed;
    return 1 if $passed =~ /\d/ or ! $passed;
    return 5 if $passed =~ /^geo/i;

return 0;
}


sub Option_dwiz {
#===============================================================================
#  Define the value for the "--dwiz" flag, which should only be passed via the
#  Domain Wizard. The purpose of this flag is to notify ems_domain that DW
#  is in the house so certain flags must be set.
#===============================================================================
#
    my $passed = shift;

return (defined $passed) ? 1 : 0;
}


sub Option_force {
#===============================================================================
#  Define the value for the --force, flag is used to scour existing domains 
#  with the same name as a new one being created.  It should be called --scour
#  but DWIZ passes --force  and --scour is already taken. Note that the value
#  may be subject to change in the configuration section.
#===============================================================================
#
    my $passed = shift;  $passed = defined $passed ? 1 : 0;


return $passed;
}


sub Option_gdxdy {
#===============================================================================
#  Define the value for the "--g_dxdy" flag,  which is used to specify the grid 
#  spacing in km or degrees for global domains. 
#===============================================================================
#
    my $mesg   = qw{};
    my $passed = shift;

    return 0 unless defined $passed;

    $passed =~ s/,+|:+|;+|\s+//g;
    $passed = lc $passed;

    $mesg = "You somehow missed that an argument is required when passing the \"--g_dxdy\". Here is a ".
            "little secret. The \"--help <topic>\" option is your friend, so try passing\n\n".

            "X04X%  ems_domain --help g_dxdy\n\n".

            "and figure where you went wrong.";

    &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'Missing Argument for "--g_dxdy"!',$mesg))  unless $passed;


    $mesg = "The argument passed to \"--g_dxdy\" must be in the form of a number value followed by a unit identifier, ".
            "which can be either \"deg\" for degrees (e.g. --g_dxdy 0.25deg) or \"km\" for kilometers.";

    #  Note that 'meters' is allowed as a unit although not advertised.
    #
    &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'When Good Arguments Go Bad:',$mesg)) unless $passed =~ /\d*\.?\d*(deg|km|m)$/;


return $passed;
}


sub Option_defres {
#===============================================================================
#  Define the value for the --defres flag specifies whether use the 
#  geog_data_res values in the namelist.wps file (not passed) or the
#  WRF default values (--defres).
#===============================================================================
#
    my $passed = shift;

       $passed = (defined $passed and $passed) ? 1 : 0;

return $passed;
}


sub Option_global {
#===============================================================================
#  Set the value for the --global flag, which specifies that a global domain
#  is being created. This flag does not need to be passed when relocalizing 
#  an existing domain.
#===============================================================================
#
    my $global = shift;

       $global = (defined $global and $global) ? 1 : 0;

return $global;
}


sub Option_gnests {
#===============================================================================
#  Set the value for the --gnests flag, which specifies any nested domains
#  to be created within a global domain.  Because of the complexity of the
#  arguments string most of the checking will be done during the configuration
#  module.
#===============================================================================
#
    my $gnests = shift;

       $gnests =  0 unless defined $gnests and $gnests;

return $gnests;
}


sub Option_gnx {
#===============================================================================
#  Define the value for the "--g_nx" and "--g_ny" flag, which is used to define
#  the number of global grid points in the NX & NY directions respectively. The
#  only check here is to ensure that the value passed is an integer. Any other
#  calculations are done in the configuration module.
#===============================================================================
#
    my $mesg   = qw{};
    my $passed = shift;

    return 0 unless defined $passed;

    $passed =~ s/,+|:+|;+|\s+//g;


    $mesg = "The argument passed to \"--g_nx\" must be in the form of an positive integer since you are specifying ".
            "the number of grid points in the NX direction over a global domain.\n\n".

            "Maybe a bit of school'n will help:  %  ems_domain --help g_nx";

    &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'When Good Arguments Go Bad:',$mesg)) unless $passed and &Others::isInteger($passed) and $passed > 0;


return $passed;
}


sub Option_gny {
#===============================================================================
#  Define the value for the "--g_nx" and "--g_ny" flag, which is used to define
#  the number of global grid points in the NX & NY directions respectively. The
#  only check here is to ensure that the value passed is an integer. Any other
#  calculations are done in the configuration module.
#===============================================================================
#
    my $mesg   = qw{};
    my $passed = shift;

    return 0 unless defined $passed;

    $passed =~ s/,+|:+|;+|\s+//g;


    $mesg = "The argument passed to \"--g_ny\" must be in the form of an positive integer since you are specifying ".
            "the number of grid points in the NY direction over a global domain.\n\n".

            "Maybe a bit of school'n will help:  %  ems_domain --help g_ny";

    &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'When Good Arguments Go Bad:',$mesg)) unless $passed and &Others::isInteger($passed) and $passed > 0;


return $passed;
}


sub Option_guseny {
#===============================================================================
#  Set the value for the --guseny flag, which specifies that the e_sn value
#  in the existing namelist.wps file is to be used when creating a global
#  domain.
#===============================================================================
#
    my $guseny = shift;

       $guseny = (defined $guseny and $guseny) ? 1 : 0;

return $guseny;
}


sub Option_gwdo {
#===============================================================================
#  Passing the --gwdo flag tells ems_domain that you intend to use the gravity
#  wave drag option during the simulation, in which case an appropriate dataset
#  resolution for each domain. If --gwdo is not passed then the default resolution 
#  of 10m will be used by default.
#===============================================================================
#
    my $gwdo = shift;

       $gwdo = (defined $gwdo and $gwdo) ? 1 : 0;

return $gwdo;
}

sub Option_import {
#===============================================================================
#   The --import flag allows the user to specify existing domains to be imported
#   into the new installation. Typically, this involves copying domain directories
#   from a previous installation into the new "uems/runs", updating the configuration
#   files, and then localizing the domain.
#
#   The argument to --import should be either a path to the directory containing
#   multiple domains or a single domain.
#===============================================================================
#
    my $mesg    = qw{};
    my @imports = ();
    my @passed  = @_; return @imports unless @passed;

    #  We need to determine whether an argument is an actual directory
    #
    foreach my $import (@passed) {$import =~ s/,+|:+/;/g; foreach (split /;/ => $import) {next unless $_; push @imports => $_;}}

    foreach my $import (@imports) {

        unless (-e $import and -d $import) {
            my $mesg = "It's obvious that neither you nor I know what you are doing.\n\nThe \"--import\" flag ".
                       "needs the full path to an existing directory as an argument, i.e.,\n\n".
                       "X04X% ems_domain  --import <path>/domain  [--import <path>/domain]\n\n".
                       "And you give me \"--import IMPORT\"?!";

            $mesg=~s/IMPORT/$import/g;
            &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'Import Faux Paux!',$mesg));
        }
        
    }


return @imports;
}


sub Option_info {
#===============================================================================
#   The --info flag is used to request information about current domain directory.
#===============================================================================
#
use Cwd;

    my $passed = shift; return 0 unless defined $passed;

    return 'RUNDIR' unless $passed;

    #  Check whether just the domain directory was passed.  If the user just passed just the
    #  name of the top level directory then use 'RUNDIR' as a placeholder until the full
    #  path can be resolved in the configuration module.
    #
    my @list = split /\// => $passed;
    $passed = $#list ? $list[$#list] : $passed;

return $passed;
}


sub Option_lakes {
#===============================================================================
#  Define the value for the --[no]lakes flag, which is used to specify whether to 
#  include the lakes dataset during the localization. The default, i.e., neither
#  --lakes nor --nolakes passed, results in the  current namelist.wps setting
#  being used.
#
#  Values:  -1 = no lakes (--nolakes), 1 = use lakes (--lakes), 0 = not passed
#===============================================================================
#
    my $passed = shift;

       $passed = (defined $passed) ? $passed ? 1 : -1 : 0;

return $passed;
}


sub Option_localize {
#===============================================================================
#  Define the value for the --localize flag, which has an optional argument in 
#  the name of the domain to localize
#===============================================================================
#
    my $passed = shift; 

    return 0 unless defined $passed;
    return 'CWD' unless $passed;     #  The CWD placeholder will be assigned in 
                                     #  configuration module


    #  Check whether just the domain directory was passed. If the user passed the full path
    #  then just return the domain directory since the path will be defined by $EMS_RUN
    #  in the configuration module.
    #
    my @list = split /\// => $passed;
    $passed = $#list ? $list[$#list] : $passed;


return $passed;
}


sub Option_mcserver {
#===============================================================================
#  Define the value for the "--mcserver" flag, which should only be passed 
#  by the UEMS Mission Control server side routine. The effect of including 
#  this flag is to not copy the default configration files into the local
#  conf/ directory since the information is being provided via another method.
#===============================================================================
#
    my $passed = shift;

return (defined $passed) ? 1 : 0;
}


sub Option_modis {
#===============================================================================
#  Define the value for the --modis flag, which is used to specify whether to 
#  include MODIS rather than USGS landuse datasets during the localization.
#  The default, i.e., neither --modis nor --usgs passed, results in the current
#  namelist.wps setting being used.
#===============================================================================
#
    my $passed = shift;

       $passed = (defined $passed) ? 1 : 0;

return $passed;
}


sub Option_ncpus {
#===============================================================================
#  Process requested number of processors used when running geogrid
#===============================================================================
#
    my $passed = shift;

    return 0 unless defined $passed and $passed;

    #  Make sure the argument passed to --ncpus was a non negative integer
    #
    my $mesg = "The argument passed to \"--ncpus\" must be in the form of an positive integer since you are specifying ".
               "the number of processors to use when localizing your domain.\n\n".

               "Maybe a bit of school'n will help:  %  ems_domain --help ncpus";

    &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'More from: "When Good Arguments Go Bad"',$mesg)) unless $passed and &Others::isInteger($passed) and $passed > 0;


return $passed;
}


sub Option_refresh {
#===============================================================================
#  Define the value for the --refresh flag used to refresh the configuration files
#  in the domain directory to factory original state with the user configuration.
#===============================================================================
#
    my $passed = shift;  $passed = defined $passed ? 1 : 0;

return $passed;
}


sub Option_restore {
#===============================================================================
#  Define the value for the --restore flag used to restore the configuration files
#  in the domain directory to factory original state with the user configuration.
#===============================================================================
#
    my $passed = shift;  $passed = defined $passed ? 1 : 0;

return $passed;
}


sub Option_rotate {
#===============================================================================
#  Define the value for the --rotate flag.
#===============================================================================
#
    my $passed = shift;  $passed = defined $passed ? 1 : 0;

return $passed;
}


sub Option_rundir {
#===============================================================================
#  Define the value for RUNDIR, which is the full path to the domain directory
#  being created/refreshed/interrogated. The problem is that the name of the
#  domain directory may not be known at this step since it may have been passed
#  as an argument to the "--create" flag, but it will be addressed shortly.
#===============================================================================
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
#===============================================================================
#  Define the value for the "--scour" flag. Note that passing --[no]scour 
#  controls the amount of cleaning to be done prior for the start of ems_domain.
#  The default, or if --scour is not passed, is the same as ems_clean --level 3.
#  The --scour 0 flag is the same as ems_clean --level 0 and the --scour flag
#  is the same as ems_clean --level 4.
#===============================================================================
#
    my $passed = shift;

    $passed = (defined $passed) ? $passed ? 4 : 0 : 3;

return $passed;
}


sub Option_landuse {
#===============================================================================
#  Define the value for the --landuse flag. This flag is used to specify a
#  landuse dataset to include in the localization. Options currently include 
#  modis, usgs, ssib, nlcd2006, and nlcd2011, although it's hard to keep track
#  all the available datasets. 
#===============================================================================
#
    my $passed = shift;

    return '' unless defined $passed; $passed = lc $passed;

    return 'default' unless $passed;  #  If --landuse was passed without arg

    $passed = &Dutils::LookupLanduseDataset($passed);

    $passed = 'default' unless $passed;
    
return $passed;  #  Don't play games
}


sub Option_gfrac {
#===============================================================================
#  Define the value for the --gfrac flag. This flag is used to specify the 
#  gfracgraphic dataset to include in the localization. Options currently 
#  include modis_fpar and nesdis_greenfrac.
#===============================================================================
#
    my $passed = shift;

    return '' unless defined $passed; $passed = lc $passed;

    return 'default' unless $passed;  #  If --gfrac was passed without arg

    $passed = &Dutils::LookupGreenFractionDataset($passed);

    $passed = 'default' unless $passed;

return $passed;  #  Don't play games
}


sub Option_stype {
#==================================================================================
#  Define the value for the --stype flag. This flag is used to specify the 
#  soil type dataset to include in the localization.
#==================================================================================
#
    my $passed = shift;

    return '' unless defined $passed; $passed = lc $passed;

    return 'default' unless $passed;  #  If --stype was passed without arg

    $passed = &Dutils::LookupSoilTypeDataset($passed);

    $passed = 'default' unless $passed;

return $passed;  #  Don't play games
}


sub Option_topo {
#===============================================================================
#  Define the value for the --topo flag. This flag is used to specify the 
#  topographic dataset to include in the localization. Options currently 
#  include gmted2010 and gtopo.
#
#  Available datasets are specified by the keys defined in 
#  $EMS_DATA/tables/wps/GEOGRID.TBL, where:
#
#    rel_path =    KEY:dataset directory
#===============================================================================
#
    my $passed = shift;

    return '' unless defined $passed; $passed = lc $passed;

    return 'default' unless $passed;  #  If --topo was passed without arg

    $passed = &Dutils::LookupTerrainDataset($passed);

    $passed = 'default' unless $passed;

return $passed;  #  Don't play games
}


sub Option_usgs {
#===============================================================================
#  Define the value for the --usgs flag, which is used to specify whether to 
#  include usgs rather than MODIS landuse datasets during the localization.
#  The default, i.e., neither --modis nor --usgs passed, results in the current
#  namelist.wps setting being used.
#===============================================================================
#
    my $passed = shift;

       $passed = (defined $passed) ? 1 : 0;

return $passed;
}


