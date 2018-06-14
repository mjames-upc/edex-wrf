#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Dhelp.pm
#
#  DESCRIPTION:  Dhelp contains subroutines used to provide love & guidance
#                to the user running ems_domain, including the help menu and
#                information on each option.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Dhelp;

use warnings;
use strict;
require 5.008;
use English;

use Ehelp;
sub DomainHelpMe {
#===============================================================================
#  The DomainHelpMe routine determines what to do when the --help flag is
#  passed with or without an argument. If arguments are passed then the 
#  PrintDomainOptionHelp subroutine is called and never returns.
#===============================================================================
#
    my @args  = &Others::rmdups(@_);

    &PrintDomainOptionHelp(@args) if @args;

    &Ecomm::PrintTerminal(0,7,255,1,1,&ListDomainOptions);

&Ecore::SysExit(-4); 
}


sub DomainHelpMeError {
#===============================================================================
#  The DomainHelpMeError routine determines what to do when the --help flag is
#  passed with or without an argument.
#===============================================================================
#
    my @args  = @_;

    &Ecomm::PrintTerminal(6,4,255,1,1,"It appears you have caused an error (@args)",&ListDomainOptions);

&Ecore::SysExit(-4); 
}


sub ListDomainOptions  {
#===============================================================================
#  This routine provides the basic structure for the ems_domain help menu 
#  should  the "--help" option is passed or something goes terribly wrong.
#===============================================================================
#

    my @optsmain = qw (create localize refresh restore info import ncpus);    $_ = "--$_" foreach @optsmain;
    my @optsglbl = qw (global g_nx g_ny g_useny g_dxdy g_nests);              $_ = "--$_" foreach @optsglbl;

    my @optsgeog = qw (topo landuse gfrac stype [no]lakes gwdo defres dxres); $_ = "--$_" foreach @optsgeog;
    my @optsgdep = qw (modis usgs);                                           $_ = "--$_" foreach @optsgdep;

    my @optsdoms = qw (rotate);                                               $_ = "--$_" foreach @optsdoms;
    my @optsothr = qw ([no]scour rundir force debug);                         $_ = "--$_" foreach @optsothr;

    
    my $mesg  = qw{};
    my @helps = ();

    my $exe = 'ems_domain'; my $uce = uc $exe;

    my %opts = &DefineDomainOptions();  #  Get options list

    push @helps => &Ecomm::TextFormat(0,0,114,0,1,"RUDIMENTARY GUIDANCE FOR $uce (Because you need it)");

    $mesg = "The primary purpose of the ems_domain routine is to create and/or localize a computational domain ".
            "for use with the EMS. It may be used as an alternative to the domain wizard if the DW GUI is ".
            "not available; however, using $exe requires that you understand the basics about model ".
            "domain configuration and grid navigation as there are no pretty depictions of your domain.\n\n".

            "After executing $exe your domain should be ready to run simulations, with or without you.";


    push @helps => &Ecomm::TextFormat(2,2,90,1,1,$mesg);

    push @helps => &Ecomm::TextFormat(0,0,114,2,1,"$uce USAGE:");
    push @helps => &Ecomm::TextFormat(4,0,144,1,1,"% $exe [--info [domain] or --create <domain> or --localize [domain] or --import <directory>] [Other options]");

    push @helps => &Ecomm::TextFormat(0,0,124,2,1,"AVAILABLE OPTIONS - BECAUSE YOU ASKED NICELY AND I'M BEGINNING TO LIKE THE WAY YOU SMELL");

    push @helps => &Ecomm::TextFormat(6,0,114,1,1,"Flag            Argument [optional]       Description");

    push @helps => &Ecomm::TextFormat(4,0,114,1,2,"The main $exe flags & options:");
    foreach my $opt (@optsmain) {push @helps => &Ecomm::TextFormat(6,0,256,0,1,sprintf("%-17s  %-18s  %-60s",$opt,$opts{$opt}{arg},$opts{$opt}{desc}));}

    push @helps => &Ecomm::TextFormat(4,0,114,1,2,"The global domain flags & options:");
    foreach my $opt (@optsglbl) {push @helps => &Ecomm::TextFormat(6,0,256,0,1,sprintf("%-17s  %-18s  %-60s",$opt,$opts{$opt}{arg},$opts{$opt}{desc}));}

    push @helps => &Ecomm::TextFormat(4,0,114,1,2,"The terrestrial datasets flags & options:");
    foreach my $opt (@optsgeog) {push @helps => &Ecomm::TextFormat(6,0,256,0,1,sprintf("%-17s  %-18s  %-60s",$opt,$opts{$opt}{arg},$opts{$opt}{desc}));}
    push @helps => &Ecomm::TextFormat(0,0,1,0,1,' ');
    foreach my $opt (@optsgdep) {push @helps => &Ecomm::TextFormat(6,0,256,0,1,sprintf("%-17s  %-18s  %-60s",$opt,$opts{$opt}{arg},$opts{$opt}{desc}));}

    push @helps => &Ecomm::TextFormat(4,0,114,1,2,"The limited area domain flags & options:");
    foreach my $opt (@optsdoms) {push @helps => &Ecomm::TextFormat(6,0,256,0,1,sprintf("%-17s  %-18s  %-60s",$opt,$opts{$opt}{arg},$opts{$opt}{desc}));}

    push @helps => &Ecomm::TextFormat(4,0,114,1,2,"Some additional flags & options:");
    foreach my $opt (@optsothr) {push @helps => &Ecomm::TextFormat(6,0,256,0,1,sprintf("%-17s  %-18s  %-60s",$opt,$opts{$opt}{arg},$opts{$opt}{desc}));}


    push @helps => &Ecomm::TextFormat(0,0,114,1,2,"FOR ADDITIONAL HELP, LOVE AND UNDERSTANDING:");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"a. Read  - docs/uems/uemsguide/uemsguide_chapter04.pdf");
    push @helps => &Ecomm::TextFormat(2,0,114,0,1,"Or");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"b. http://strc.comet.ucar.edu/software/uems");
    push @helps => &Ecomm::TextFormat(2,0,114,0,1,"Or");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"c. % $exe --help <topic>  For a more detailed explanation of each option (--<topic>)");
    push @helps => &Ecomm::TextFormat(2,0,114,0,1,"Or");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"d. % $exe --help  For this menu again");

    my $help = join '' => @helps;


return $help;
}


sub DefineDomainOptions {
#=====================================================================================
#  This routine defined the list of options that can be passed to the program
#  and returns them as a hash.
#=====================================================================================
#
    my %opts = (
                '--create'       => { arg => 'DOMAIN'       , help => '&DomainHelp_create'   , desc => 'Create a new computational domain DOMAIN'},
                '--newdom'       => { arg => 'DOMAIN'       , help => '&DomainHelp_create'   , desc => 'Create a new computational domain DOMAIN (DWIZ Only)'},
                '--update'       => { arg => 'DOMAIN'       , help => '&DomainHelp_refresh'  , desc => 'Same as "--refresh" but passed by DWIZ with the domain as an argument'},
                '--import'       => { arg => 'DIR'          , help => '&DomainHelp_import'   , desc => 'Import, refresh, and localize an existing domain directory from DIR'},
                '--info'         => { arg => '[DOMAIN]'     , help => '&DomainHelp_info'     , desc => 'Print out the domain configuration information and exit'},

                '--mcserver'     => { arg => ''             , help => '&DomainHelp_notused'  , desc => 'Turns OFF copying of default configuration files into local directory. For use with UEMS Mission Control'},
                '--force'        => { arg => ''             , help => '&DomainHelp_force'    , desc => 'Delete any previously existing domains of the same name. For use with "--create".'},
                '--[no]scour'    => { arg => ''             , help => '&DomainHelp_scour'    , desc => '[Do Not] scour the domain and grib directories prior to running ems_domain'},
                '--ncpus'        => { arg => '#CPUS'        , help => '&DomainHelp_ncpus'    , desc => 'The number of processors to use when running geogrid (horizontal interpolation)'},

                '--modis'        => { arg => ''             , help => '&DomainHelp_modis'    , desc => 'Use MODIS based land use, greenness fraction, and leaf area index terrestrial datasets'},
                '--usgs'         => { arg => ''             , help => '&DomainHelp_usgs'     , desc => 'Use the 24/25 category USGS land use dataset (Deprecated; see --landuse)'},
                '--[no]lakes'    => { arg => ''             , help => '&DomainHelp_lakes'    , desc => '[Do not] Include the inland lakes dataset with USGS or MODIS land use data'},
                '--localize'     => { arg => '[DOMAIN]'     , help => '&DomainHelp_localize' , desc => 'Run the WRF geogrid routine to build the terrestrial dataset for your computational domain'},
                '--landuse'      => { arg => '[LU DSET]'    , help => '&DomainHelp_landuse'  , desc => 'Specify the land use dataset to use (modis|usgs|ssib|nlcd2006|nlcd2011; default: MODIS).'},
                '--topo'         => { arg => '[TOPO DSET]'  , help => '&DomainHelp_topo',    , desc => 'Specify the topography elevation dataset to use (gmted2010|gtopo; default gmted2010)'},
                '--gfrac'        => { arg => '[VGF DSET]'   , help => '&DomainHelp_gfrac',   , desc => 'Specify the vegetation greenness fraction dataset to use (modis|nesdis; default MODIS)'},
                '--stype'        => { arg => '[SOIL DSET]'  , help => '&DomainHelp_stype',   , desc => 'Specify the soil type dataset to use (bnu|30s|2m|5m|10m; default: Domain dependent 30s|2m|5m|10m)'},
                '--refresh'      => { arg => ''             , help => '&DomainHelp_refresh'  , desc => 'Refresh configuration files for the computational domain (default with --import)'},
                '--restore'      => { arg => ''             , help => '&DomainHelp_restore'  , desc => 'Returns the domain configuration files to a factory fresh (default) state'},
                '--rundir'       => { arg => 'DIR'          , help => '&DomainHelp_rundir'   , desc => 'Location where domain currently resides ("--localize" and "--refresh") or will reside ("--create" and "--import")'},
                '--rotate'       => { arg => ''             , help => '&DomainHelp_rotate'   , desc => 'Rotate the pole latitude & longitude (LAT-LON GRIDS ONLY)'},
                '--defres'       => { arg => ''             , help => '&DomainHelp_defres'   , desc => 'Replace the current geog_data_res in namelist.wps with the WRF defaults specified in GEOGRID.TBL'},
                '--dxres'        => { arg => ''             , help => '&DomainHelp_dxres'    , desc => 'Calculate the default static dataset resolution from the domain grid spacing rather than using the WRF defaults'},
                '--gwdo'         => { arg => ''             , help => '&DomainHelp_gwdo'     , desc => 'Use the appropriate Gravity Wave Drag dataset for each subdomain'},
                
                '--global'       => { arg => ''             , help => '&DomainHelp_global'   , desc => 'Create a global domain. Uses values in namelist.wps or passed (See GLOBAL ONLY below)'},
                '--g_nx'         => { arg => 'NX POINTS'    , help => '&DomainHelp_gnxny'    , desc => 'Define the number of grid points along a latitude circle (GLOBAL ONLY)'},
                '--g_ny'         => { arg => 'NY POINTS'    , help => '&DomainHelp_gnxny'    , desc => 'Define the number of grid points along a longitude circle (GLOBAL ONLY)'},
                '--g_dxdy'       => { arg => 'DX value'     , help => '&DomainHelp_gdxdy'    , desc => 'Define the spacing between horizontal grid points ("deg" or "km") at the equator (GLOBAL ONLY)'},
                '--g_useny'      => { arg => ''             , help => '&DomainHelp_guseny'   , desc => 'Retain the value of e_sn specified in the namelist file (GLOBAL ONLY)'},
                '--g_nests'      => { arg => 'DOM#,...'     , help => '&DomainHelp_gnests'   , desc => 'Define nested domains to be included in a global domain (GLOBAL ONLY)'},

                '--help'         => { arg => '[TOPIC]'      , help => '&DomainHelp_help'     , desc => 'Either print this list again or pass me a topic and I\'ll explain it to you'},
                '--debug'        => { arg => '[ARG]'        , help => '&DomainHelp_debug'    , desc => 'Turns on the debugging and prints out additional information'},

                '--core'         => { arg => 'CORE'         , help => '&DomainHelp_notused'  , desc => 'Just ignore - used internally by UEMS gnomes'},
                '--dwiz'         => { arg => ''             , help => '&DomainHelp_notused'  , desc => 'Just ignore - used internally by UEMS gnomes'},
                '--domain'       => { arg => 'NAME'         , help => '&DomainHelp_notused'  , desc => 'Just ignore - used internally by UEMS gnomes'},
                '--ems'          => { arg => 'PATH'         , help => '&DomainHelp_notused'  , desc => 'Just ignore - used internally for legacy purposes'}
                );


return %opts;
}





sub PrintDomainOptionHelp {
#===============================================================================
#  The PrintDomainOptionHelp takes a string that is matched to a help topic. 
#  There is no returning from this subroutine - ever.
#
#  This routine is a bit sloppy and should be cleaned up.
#===============================================================================
#
    my ($package, $filename, $line, $subr, $has_args, $wantarray)= caller(1);

    my $exit = ($subr =~ /CheckDomainOptions/) ? -5 : -4;

    my %opts = &DefineDomainOptions();  #  Get options list

    my $dash   = '-' x 108;

    my @helps  = @_;

    my @topics = &Others::rmdups(@helps);

    foreach my $topic (@topics) {

        my $flag = &Doptions::MatchDomainOptions("--$topic");

        if ($flag and defined $opts{$flag}{help}) {

            my $help = eval $opts{$flag}{help}; 
               $help = "Hey - Add some magic words for the $flag flag!" unless $help;
  
            my $head = ($subr =~ /CheckDomainOptions/) ? "It appears you need some assistance with the $flag flag:" 
                                                       : "Looking for some assistance with the $flag flag I see:";

            &Ecomm::PrintTerminal(0,2,144,1,1,$head);
            &Ecomm::PrintTerminal(0,2,144,0,1,$dash);
            &Ecomm::PrintTerminal(0,4,256,1,1,$help);
            &Ecomm::PrintTerminal(0,2,144,0,2,$dash);

        } else {
           my $help = "What's this \"--help $topic\" nonsense?\n\n".
                      "Figure out what you want and get back to me very soon.\n\n".
                      "I miss you already!";

           &Ecomm::PrintTerminal(6,5,144,1,1,$help);
        }

    }

&Ecore::SysExit($exit); 
}


sub DomainHelp_help {
#===============================================================================
#  Routine provides guidance for using the --help flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--help';

       $help{WHAT} = "I'm the help flag, what did you expect?";

       $help{USE}  = '% ems_domain --help [maybe a help topic]';

       $help{DESC} = "The \"--help\" flag should not need any introduction, but since you're rather new at this, I'll entertain ".
                     "your insatiable quest for knowledge and let you in on some valuable information.\n\n".

                     "Passing the \"--help\" flag without any arguments provides a list of flags and options that can be ".
                     "used with ems_domain when running on the command line. It's fairly simple, and may be used as a quick ".
                     "reference to my utility should your brain fail you yet again.\n\n".

                     "Once the above usage has been mastered, there is else something you must learn that isn't taught during ".
                     "any \"Birds & Bees\" discussions. The \"--help\" flag can also take an argument in the form of a listed ".
                     "flag without the leading dashes (\"--\"). \"Wow!\" you exclaim, \"I didn't know that!\"\n\n".

                     "Well, now you know.  And at least you didn't have to hear it on the street.";

            
       $help{ADDN} = "The UEMS is the font of half of life's useful knowledge, kindergarten provides the rest."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_debug {
#===============================================================================
#  Routine provides guidance for using the --debug flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--debug';

       $help{WHAT} = 'Turns on the debugging and prints out additional information';

       $help{USE}  = '% ems_domain --localize --debug [1-4|geogrid]';

       $help{DESC} = "Passing the \"--debug\" flag serves to provide a bit of additional information of use to ".
                     "the developer. If you aspire to be a UEMS developer, then feel free to include the \"--debug\" ".
                     "flag, but don't expect much.  The primary utility of this flag is when including \"geogrid\"".
                     "as an argument (along with --localize), which instructs ems_domain to exit just before ".
                     "running the WPS geogrid routine to create the terrestrial datasets for your domain for ".
                     "debugging purposes.";
            
       $help{ADDN} = "The \”--debug\” flag - you wish it did more than it does."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_force {
#===============================================================================
#  Routine provides guidance for using the --force flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--force';

       $help{WHAT} = 'Delete any existing run-time domain directory when using --create';

       $help{USE}  = '% ems_domain  --create  mydomain --force';

       $help{DESC} = "Passing the \"--force\" flag tells ems_domain to scour and replace any existing run-time ".
                     "directory under $ENV{EMS_RUN} with the same name as that being created. Failing to pass ".
                     "\"--force\" will result in ems_domain stopping should it encounter another directory with ".
                     "that name.";

            
       $help{ADDN} = "It's always best to not use the \"--force\" flag unless you'll be comfortable with the results"; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_scour {
#===============================================================================
#  Routine provides guidance for using the --[no]scour flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--[no]scour';

       $help{WHAT} = 'Controls the amount of domain directory cleaning done prior to the start of ems_domain';

       $help{USE}  = '% ems_domain --[no]scour [more important stuff]';

       $help{DESC} = "Passing the \"--scour\" flag overrides the default level of cleaning done prior to ".
                     "the start of ems_domain. If this flag is not passed, then the default level is the same ".
                     "as running \"ems_clean --level 3\", which deletes all non-essential files in the domain ".
                     "directory while keeping any initialization data under grib/.\n\n".

                     "Passing \"--scour\" is the same as running \"ems_clean --level 4\", which also includes ".
                     "the removal of all files from grib/. You might include this flag if you wanted to download ".
                     "a fresh set of GRIB files for initialization while deleting any existing files.\n\n".
 
                     "Passing \"--noscour\" is the same as running \"ems_clean --level 0\", which simply ".
                     "deletes old log files and recreates the symbolic links to the run-time scripts.";
                      
            
       $help{ADDN} = "\"% ems_domain --scour [other stuff]\” is the default when running ems_autorun"; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_refresh {
#===============================================================================
#  Routine provides guidance for using the --refresh flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--refresh';

       $help{WHAT} = 'Refresh configuration files for the computational domain (default with --import)';

       $help{USE}  = '% ems_domain --refresh [other stuff]';

       $help{DESC} = "Passing \"--refresh\" updates the configuration files under the local \"conf\" directory for a specific domain. ".
                     "This flag is typically used following an UEMS update wherein the default configuration files under uems/conf ".
                     "were replaced. All local configuration settings will be retained during the refreshment process. The benefit ".
                     "of --refresh is that any changes to the available options and descriptions in the default configuration files ".
                     "will be transfered to the local files.\n\n".

                     "The \"--refresh\" flag is automatically included when importing domains from other UEMS releases because ".
                     "of the likelihood that the imported configuration files are outdated.";
                      
            
       $help{ADDN} = "The \”--refresh\” flag is a valuable tool in your arsenal of change."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_lakes {
#===============================================================================
#  Routine provides guidance for using the --[no]lakes flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--[no]lakes';

       $help{WHAT} = 'Controls [Do not] Include the inland lakes dataset with USGS or MODIS land use data';

       $help{USE}  = '% ems_domain --[no]lakes [other stuff]';

       $help{DESC} = "Passing the \"--[no]lakes\" flag instructs ems_domain to [not] include the MODIS- or USGS-based ".
                     "land use data with inland water bodies. Passing \"--lakes\" results in a domain dataset that uses ".
                     "a separate category for inland water bodies instead of the general water category used for oceans ".
                     "and seas. Passing \"--nolakes\" instructs ems_domain to use the standard treatment for inland ".
                     "bodies of water. Not passing \"--[no]lakes\" causes ems_domain to default to the current configuration ".
                     "as listed in the static/namelist.wps file. Your current domain configuration can be seen by using ".
                     "the \"--info\" flag:\n\n".

                     "  %  ems_domain --info\n\n".

                     "While using a separate lakes dataset sounds like a great idea, keep in mind that all the additional ".
                     "bodies of water will have to be given a temperature. These temperature values usually come from the ".
                     "files (GRIB) used for model initialization; however, these datasets may be unable to resolve the inland ".
                     "lakes, in which case the temperature values come from the closest resolvable water body or another ".
                     "source. The alternative in WRF is to use a \"best guess\" field that serves as a proxy for SST values ".
                     "over lakes. This field is calculated from the daily mean surface temperature during the running of ems_prep, ".
                     "and is used by default when the lakes field is present in the terrestrial files created after ".
                     "ems_domain is run. See \"ems_prep --help noaltsst\" for additional information.\n\n".

                     "Using the alternate SST dataset may seem like a good idea, but the mean surface (2m) temperature may ".
                     "not always be a good substitute for the water temperature.  For example, during periods of climate ".
                     "transition where the mean surface temperature is below (above) freezing, the actual water temperatures ".
                     "may be above (at) freezing levels. This error may result in some inland lakes to be labeled as ice ".
                     "covered (open water) when the opposite is true.\n\n".


                     "As a remiinder (as if you needed one), the inland lakes dataset is only available with the MOSID and ".
                     "USGS land use data.  You can pass \"--lakes\" all you want with the SSIB or NLCD datasets, but nothing ".
                     "will come from your efforts.";

                     
            
       $help{ADDN} = "Passing the \"--[no]lakes\” flag is like opening Pandora's box of chocolates, only less tasty.";


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_restore {
#===============================================================================
#  Routine provides guidance for using the --restore flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--restore';

       $help{WHAT} = 'Returns the domain configuration files to a factory fresh (default) state';

       $help{USE}  = '% ems_domain --restore [other stuff]';

       $help{DESC} = "The \"--restore\" flag returns the local configuration files to the original state when the ".
                     "domain was created. In doing so, all the local configuration files under <domain>/conf will ".
                     "be replaced along with the emsupp_cntrl.conf, emsupp_auxcntrl.conf files under <domain>/static.\n\n".
                     "This flag should be used after you have completely hacked your local configuration files and can't ".
                     "figure out why your simulation is failing.\n\n".

                     "Note that the \"--restore\" flag does not modify your local domain configuration defined in ".
                     "namelist.wps.";
            
       $help{ADDN} = "When passing \"--restore\", ems_domain must be run from an existing domain directory."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_usgs {
#===============================================================================
#  Routine provides guidance for using the --usgs flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--usgs';

       $help{WHAT} = '(Deprecated; See --landuse) Use the 24/25 category USGS land use dataset';

       $help{USE}  = '% ems_domain --usgs [--lakes] [other stuff]';

       $help{DESC} = "Passing the \--usgs\" flag instructs ems_domain to use the 24-category USGS land use dataset in ".
                     "the localization process. Since the default is to use the current dataset specified in the ".
                     "static/namelist.wps file, you would only pass this flag if you wanted to change to USGS from the ".
                     "21-category MODIS data.\n\n".

                     "If you desire to kick it up a category to 25, then pass the \"--lakes\" flag with \"--usgs\", " .
                     "which will get you the additional inland lakes dataset.\n\n".

                     "Note that, unlike most things in life, the greater number of categories in the USGS dataset does ".
                     "not make it better than the MODIS; only different. Additionally, MODIS is the default when creating ".
                     "a new domain and strongly recommended for use with the NOAH LSM (also default).";
            
       $help{ADDN} = "Just stick with MODIS unless you have a good reason to change."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_modis {
#===============================================================================
#  Routine provides guidance for using the --modis flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--modis';

       $help{WHAT} = 'Use MODIS based land use, greenness fraction, and leaf area index terrestrial datasets';

       $help{USE}  = '% ems_domain --modis [--lakes] [other stuff]';

       $help{DESC} = "Passing the \"--modis\" flag instructs ems_domain to use all available MODIS based terrestrial datasets in the ".
                     "the localization process. Since the default is to use the current dataset specified in the static/namelist.wps ".
                     "file, you would pass this flag if you wanted to ensure compatibility between the static terrestrial data and ".
                     "the most common WRF LSM and surface schemes.\n\n".

                     "If you desire to kick it up a category to 21, then pass the \"--lakes\" flag with \"--modis\", " .
                     "which will get you the additional inland lakes dataset.\n\n".

                     "Note that, unlike most things in life, the greater number of categories in the USGS dataset does ".
                     "not make it better than the MODIS; only different. Additionally, MODIS is the default when creating ".
                     "a new domain and strongly recommended for use with the NOAH LSM (also default).";
            
       $help{ADDN} = "Always stick with MODIS unless you have a good reason to change, which you don't"; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_create {
#===============================================================================
#  Routine provides guidance for using the --create flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--create';

       $help{WHAT} = "Create a new computational domain in the $ENV{EMS_RUN} directory";

       $help{USE}  = '% ems_domain --create DOMAIN  (and nothing else except maybe --force)';

       $help{DESC} = "So, running a fancy GUI to create your computational domain just isn't for you? ".
                     "You like things done the \“Ye olde fashion\" NWP way?  Well then, embrace your ".
                     "inner Luddite; the UEMS has you covered.\n\n".

                     "Passing the \"--create\" flag allows you to create a run-time domain without using the ".
                     "Domain Wizard GUI. The lone argument is the name for the domain, which will be placed ".
                     "under the $ENV{EMS_RUN} directory. The default domain still needs to be altered to ".
                     "meet your needs and then localized by running ems_domain again with the \"--localize\" ".
                     "flag, but all the necessary configuration files are in place.\n\n".

                     "After creating a domain directory you will likely want to modify the grid navigation since ".
                     "the default is the same as that used in the UEMS benchamrk simulation. ".
                     "If you are running a limited area domain, then you will need to edit the \"&geogrid\" ".
                     "block of information in the static/namelist.wps file. Chapter 5 of the UEMS User's Guide ".
                     "should provide some guidance.\n\n".

                     "If you are \"Thinking outside the box\" and desire a global domain, then ems_domain can ".
                     "take care of all your configuration needs. See \"ems_domain --help global\" for the gory ".
                     "details.";

            
       $help{ADDN} = "After running \"%  ems_domain --create mydomain\", you still have work to do."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_import {
#===============================================================================
#  Routine provides guidance for using the --import flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--import';

       $help{WHAT} = 'Import, update, and localize an existing domain directory or multiple directories';

       $help{USE}  = '% ems_domain --import DIR [--import DIR[,DIR]]';

       $help{DESC} = "Passing the \"--import\" flag allows a user to import, refresh, and localize an existing ".
                     "run-time domain from outside the current UEMS runs directory. The argument DIR may be a ".
                     "single domain or a directory containing more than one domain. Multiple \"--import\" flags ".
                     "may be passed with different DIR locations or you can include multiple DIR locations with ".
                     "a single flag by separating them with a comma (,). The UEMS doesn't care, its soul was sold ".
                     "years ago.\n\n".

                     "When importing run-time domains from another location, such as a previous well-loved ".
                     "UEMS release, any non domain directories will be excluded from the list. Directory names ".
                     "that conflict with those currently residing under $ENV{EMS_RUN} will have \".imported##\" ".
                     "appended to the name to avoid problems. The '##' is used when there are multiple imported ".
                     "domains of the same name.\n\n".

                     "After the directories are imported, the configuration files under conf will be refreshed ".
                     "(See \"--help reflesh\") with all user settings retained. The same is true for the emsupp ".
                     "files, emsupp_cntrl.conf and emsupp_auxcntrl.conf, under <domain>/static.\n\n".

                     "The imported domains will be localized so as to be viable with the current UEMS; however, ".
                     "any domains that were renamed due to a conflict with an existing directory name will not ".
                     "be localized, and thus it is up to the user to run \"ems_domain --localize\" after ".
                     "renaming them to something appropriate such as \"GoStormGo\".";
            
       $help{ADDN} = "When localizing imported domains, no changes will be made to the individual namelist.wps ".
                     "files from to flags passed to ems_domain such as \"--usgs\", \"--modis\", or the global ".
                     "domain configuration flags."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_info {
#===============================================================================
#  Routine provides guidance for using the --info flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--info';

       $help{WHAT} = 'Print out the domain configuration information and exit';

       $help{USE}  = '% ems_domain --info [mydomain]';

       $help{DESC} = "Passing \"--info\" instructs ems_domain to print out information about the domain configuration. ".
                     "That's about all it does.";

            
       $help{ADDN} = "Use the \"--info\" flag when you're feeling lonely."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_localize {
#===============================================================================
#  Routine provides guidance for using the --localize flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--localize';

       $help{WHAT} = 'Run the WRF geogrid routine to build the terrestrial dataset for your computational domain';

       $help{USE}  = '% ems_domain --localize [other stuff]';

       $help{DESC} = "The purpose of the \"--localize\" flag is to process the required terrestrial data (land use, ".
                     "topography, landmask, greenness fraction. etc.), for your computational domain.  If you make ".
                     "any changes to the navigation or number of points in your domain, you need to run ems_domain ".
                     "with the \"--localize\" flag.  If you want to change a terrestrial dataset, say from modis to ".
                     "nesdis greenness fraction, you need to run ems_domain with the \"--localize\" flag. ".
                     "If you create a new domain (See --help create) you need to run ems_domain with the ".
                     "\"--localize\" flag (after your modifications of course).\n\n".
                     "Embrace the \"--localize\" flag, and it will embrace you.";
            
       $help{ADDN} = "You want the \"--localize\" flag. You need the \"--localize\" flag."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_landuse {
#===============================================================================
#  Routine provides guidance for using the --landuse flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--landuse [LU DATASET]';

       $help{WHAT} = 'Specify the land use dataset to use for you computational domain';

       $help{USE}  = '% ems_domain --localize --landuse [modis|usgs|ssib|nlcd2006|nlcd2011] [other stuff]';

       $help{DESC} = "Pass the \"--landuse\" flag if you want to change the terrestrial land use (LU) dataset created during ".
                     "the localization process. Not passing \"--landuse\" results in use of the current LU dataset specified in ".
                     "the namelist.wps file.\n\n".

                     "To view the terrestrial dataset information for a specific domain:\n\n".

                     "X02X% ems_domain --info  [domain directory]\n\n\n".

                     "The  \"--landuse\" flag may take the name of an available LU dataset as an argument, which currently include:\n\n".

                     "X02Xmodis    - 20/21-category MODIS land-cover classification. Use with NOAH LSM (1,4)\n".
                     "X02Xusgs     - 24/25-category USGS land-cover classification\n".
                     "X02Xssib     - 12-category land-cover SSiB classification. Use with SSiB LSM (8)\n".
                     "X02Xnlcd2006 - 16-category National Land Cover Database (2006; North America Only)\n".
                     "X02Xnlcd2011 - 16-category National Land Cover Database (2011; North America Only)\n\n".

                     "Passing  \"--landuse\" without an argument results in the default 20-category MODIS dataset being used.\n\n".

                     "Some terrestrial datasets are available in multiple resolutions. For example, the MODIS data include 30- and ".
                     "15-arc second files. For these situations, ems_domain will use the dataset resolution that best matches the grid ".
                     "spacing for each domain and any nested domains.";

       $help{ADDN} = "The \”--landuse\” flag - It's what's for breakfast."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_topo {
#===============================================================================
#  Routine provides guidance for using the --topo flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--topo [TOPOGRAPHY DATASET]';

       $help{WHAT} = 'Specify the topography elevation dataset to use for you computational domain';

       $help{USE}  = '% ems_domain --localize --topo [gmted2010 gtopo] [other stuff]';

       $help{DESC} = "Pass the \"--topo\" flag if you want to change the topography dataset created during the ".
                     "localization process. Not passing \"--topo\" results in use of the current dataset as specified ".
                     "in the namelist.wps file. If you don't see a topography dataset specified in the namelist.wps ".
                     "then its very likely gmted2010 is being used.\n\n".

                     "To view the terrestrial dataset information for a specific domain:\n\n".

                     "X02X% ems_domain --info  [domain directory]\n\n\n".

                     "The \"--topo\" flag may take the name of an available elevation dataset as an argument, which currently include:\n\n".

                     "X02Xgmted2010 - 30-arc second USGS Global Terrain Elevation Data\n".
                     "X02Xgtopo     - Pre WRF 3.8 USGS Global Multi-resolution Terrain Elevation Data\n\n".

                     "Passing \"--topo\" without an argument results in the default gmted2010 elevation dataset being used.\n\n".

                     "Some terrestrial datasets are available in multiple resolutions. For example, gtopo is available in 10-, 5-, 2 arc minute, ".
                     "and 30-arc second files. For these situations, ems_domain will use the dataset resolution that best matches the grid ".
                     "spacing for each domain and any nested domains.\n\n".

                     "The default UEMS installation only includes the 30 sec gmted2010 dataset, which is plenty good for you. If you really ".
                     "must use the pre WRF 3.8 USGS \"gtopo\" data then you must download and install it separately with the uems_install.pl ".
                     "utility:\n\n".
                     
                     "X02X% uems_install.pl --geog gtopo\n\n".  

                     "before passing \"--topo gtopo\"";

       $help{ADDN} = "The \”--topo\” flag - It's what's for breakfast."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_gfrac {
#===============================================================================
#  Routine provides guidance for using the --gfrac flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--gfrac [VEGETATION GREENNESS FRACTION DATASET]';

       $help{WHAT} = 'Specify the vegetation greenness fraction dataset to use for you computational domain';

       $help{USE}  = '% ems_domain --localize --gfrac [modis|nesdis] [other stuff]';

       $help{DESC} = "Pass the \"--gfrac\" flag if you want to change the vegetation greenness fraction (GVF or VGF) dataset created ".
                     "during the localization process. Not passing \"--gfrac\" results in use of the current dataset as specified in ".
                     "the namelist.wps file. If no dataset is specified then the modis_fpar is likely being used.\n\n".

                     "To view the dataset information for a specific domain:\n\n".

                     "X02X% ems_domain --info  [domain directory]\n\n\n".

                     "The  \"--gfrac\" flag may take the name of an available GVF dataset as an argument, which currently include:\n\n".

                     "X02Xmodis  - 30-arc second GVF data based on 10 years MODIS (Default)\n".
                     "X02Xnesdis - 10-arc minute GVF data based on AVHRR (Pre WRF 3.8 Default)\n\n".

                     "Passing  \"--gfrac\" without an argument results in the 30-arc second MODIS dataset being used.\n\n".

                     "Some terrestrial datasets are available in multiple resolutions, but this is not one of them.";

       $help{ADDN} = "The \”--gfrac\” flag - for the Vegan in all of us."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_stype {
#===============================================================================
#  Routine provides guidance for using the --stype flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--stype [SOIL CATEGORY DATASET]';

       $help{WHAT} = 'Specify the soil category dataset to use for you computational domain';

       $help{USE}  = '% ems_domain --localize --stype [bnu|30s|2m|5m|10m] [other stuff]';

       $help{DESC} = "Pass the \"--stype\" flag if you want to change the soil category dataset created used ".
                     "during the localization process. Not passing \"--stype\" results in use of the current dataset as specified in ".
                     "the namelist.wps file. If no dataset is specified then the default WPS dataset is likely being used.\n\n".

                     "To view the dataset information for a specific domain:\n\n".

                     "X02X% ems_domain --info  [domain directory]\n\n\n".

                     "The  \"--stype\" flag may take the name of an optional soil type dataset as an argument, which currently includes:\n\n".

                     "X02Xbnu  - Global 30-arc second, 16-category BNU soil category dataset\n\n".
                     "X02X30s  - Global 30-arc second, 16-category soil type dataset\n".
                     "X02X10m  - Global 10-arc minute, 16-category soil type dataset\n".
                     "X02X5m   - Global  5-arc minute, 16-category soil type dataset\n".
                     "X02X2m   - Global  2-arc minute, 16-category soil type dataset\n\n".

                     "Passing  \"--stype\" without an argument results in a domain appropriate 16-category 30s, 2m, 5m, 10m soil type dataset.";

       $help{ADDN} = "The \”--stype\” flag - What is it good for?"; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_rotate {
#===============================================================================
#  Routine provides guidance for using the --rotate flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--rotate';

       $help{WHAT} = 'Rotate the pole latitude & longitude (Limited area Lat-Lon grids only)';

       $help{USE}  = '% ems_domain --rotate [other stuff]';

       $help{DESC} = "When a regular latitude-longitude projection is used for a regional domain, care must be taken to ".
                     "ensure that the map scale factors in the region covered by the domain do not deviate significantly ".
                     "from unity. This can be accomplished by rotating the projection such that the area covered by the ".
                     "domain is located near the equator of the projection, since, for the regular latitude-longitude ".
                     "projection, the map scale factors in the x-direction are given by the cosine of the computational ".
                     "latitude.\n\n".

                     "When passing \"--rotate\" for a latitude-longitude domain, ems_domain follows the guidance provided ".
                     "in the WPS Chapter of the WRF User's Guide, specifically:\n\n".

                     "X04XX04XX04XX04XX04XNorth Hemis   South Hemis\n".
                     "X04XX02X------------|-------------|---------------\n".
                     "X04XX04Xpole_lat  | 90.0-ref_lat| 90.0+ref_lat\n".
                     "X04XX04Xpole_lon  | 180.0       | 0.0\n".
                     "X04XX04Xstand_lon | -ref_lon    | 180.0-ref_lon\n\n".

                     "Where the \"ref_lat\" and \"ref_lon\" are typically assigned to be the center lat-lon of the primary ".
                     "grid.";

       $help{ADDN} = "The explanation above was \"pilfered\" from the WPS chapter of the WRF User's Guide. If you are ". 
                     "a member of the Nobel Committee for Literature in search of a potential nominee, then look no ".
                     "further than the original author of the above prose.";

return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_defres {
#===============================================================================
#  Routine provides guidance for using the --defres flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--defres';

       $help{WHAT} = 'Replace the current geog_data_res in namelist.wps with the UEMS defaults';

       $help{USE}  = '% ems_domain --localize  --defres  [other stuff]';

       $help{DESC} = "Passing \"--defres\" does the job of 4 flags, \"--topo\", \"--landuse\", \"--stype\", and \"--gfrac\". ".
                     "This super-flag replaces the existing terrestrial dataset defined in the namelist.wps file ".
                     "with the UEMS defaults (same as those for WPS V3.9), or specifically:\n\n".

                     "X02XTopography         - 30-arc second USGS GMTED2010 terrain elevation data\n".
                     "X02XLand Use           - 30-arc second 20-class MODIS IGVP land-use with lakes\n".
                     "X02XGreenness Fraction - 30-arc second GVF data based on 10 years MODIS (FPAR)\n\n".

                     "While \"--defres\" replaces the need to pass the 3 flags listed above (plus soil type), it does not exclude their use. ".
                     "For example,\n\n".

                     "X02X% ems_domain --localize  --defres  --landuse ssib\n\n".

                     "will replace the default MODIS land use dataset with the SSiB fields.";
            
       $help{ADDN} = "In case you can't take the hints above, the \”--defres\” flag should only be passed with \"--localize\"."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_dxres {
#===============================================================================
#  Routine provides guidance for using the --dxres flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--dxres';

       $help{WHAT} = 'Calculate the default static dataset resolution from the domain grid spacing';

       $help{USE}  = '% ems_domain --localize  --dxres  [other stuff]';

       $help{DESC} = "Some of the static terrestial datasets, such as the USGS \"gtopo\" terrain elevation, have multiple ".
                     "datasets containing data at various resolutions (E.g, gtopo_10m, gtopo_2m, gtopo_30s, etc). Passing the ".
                     "\"--dxres\" flag instructs ems_domain to use the dataset that is closest to the each domain grid spacing ".
                     "when creating the static terrestrial files for a simulation. This approach was the default prior to WRF ".
                     "version 3.8 (UEMS V15).  Now ems_domain will use the WRF default values defined in the GEOGRID.TBL ".
                     "file for each dataset, unless \"--dxres\" is passed.";
            
       $help{ADDN} = "The \"--dxres\" flag is probably best reserved for \"vintage\" simulations."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_gwdo {
#===============================================================================
#  Routine provides guidance for using the --gwdo flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--gwdo';

       $help{WHAT} = 'Use the appropriate Gravity Wave Drag dataset for each subdomain';

       $help{USE}  = '% ems_domain --localize --gwdo [other stuff]';

       $help{DESC} = "Passing the \”--gwdo\” tells ems_domain that you want the gravity wave drag dataset ".
                     "resolution that is most appropriate for each of your computational domains. Not passing ".
                     "\”--gwdo\” results in the 30-arc second version of each dataset to be included in the ".
                     "localization whether or not you plan to use the gravity wave drag option when running ".
                     "a simulation. If you intend to use the gravity wave drag in WRF, then passing \”--gwdo\” ".
                     "during localization instructs ems_domain to follow the guidance provided in the WPS ".
                     "chapter, which states:\n\n".

                     "\"It is recommended that these fields (GWD) be interpolated from a resolution of source ".
                     " data that is slightly lower (i.e., coarser) in resolution than the model grid.\"\n\n".

                     "And if it's good enough for WRF it's good enough for you.";
            
       $help{ADDN} = "The \”--gwdo\” flag - Use it like you mean business."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_global {
#===============================================================================
#  Routine provides guidance for using the --global flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--global';

       $help{WHAT} = 'Thinking outside the box - Create a global domain.';

       $help{USE}  = '% ems_domain --global [global-only flags]  [other stuff]';

       $help{DESC} = "Passing the \"--global\" flag simply tells ems_domain that you wish to create a global domain. ".
                     "Any domain information contained within namelist.wps will be ignored, although a backup of the ".
                     "file will be created. The saved file gets overwritten each time you run ems_domain.pl so if you ".
                     "really want to keep it, you will have to give it another name, such as namelist.wps.nofortune (see below).\n\n".

                     "Not passing the --global flag does not necessarily mean that you will forgo the creation of a ".
                     "global domain. A global domain may still be created if the geogrid section of the namelist.wps ".
                     "already contains the navigation for a global domain, which might look something like:\n\n".

                     "X04Xe_we        = 721\n".
                     "X04Xe_sn        = 361\n".
                     "X04Xmap_proj    = 'lat-lon'\n".
                     "X04Xstand_lon   = 180\n".
                     "X04Xpole_lat    = 90\n".
                     "X04Xpole_lon    = 0\n\n".

                     "Note that parameters dx, dy, ref_lat, and ref_lon, are not part of a global domain configuration. ".
                     "Additionally, ref_x and ref_y will be assigned during the localization process.\n\n".

                     "If you plan on creating a global domain with ems_domain, then also take a look at the \"g_\" flags, ".
                     "\"--g_nx\", \"--g_ny\", \"--g_dxdy\", \"--g_useny\", and \"--g_nests.\"";


       $help{ADDN} = "So you don’t like being governed by lateral boundary conditions? Yeah, me neither! Do you\n".
                     "feel as though the \"NWP Man\” is keeping you down? Well, did you know that with the UEMS,\n".
                     "every day is \“Primary Domain Emancipation Day\?” I bet you didn’t know that, did you? Well,\n".
                     "neither did I.\n\n".

                     "Since you are reading this section, then you must be considering the leap from limited area\n".
                     "to global modeling. It’s a big move but I know what you’re thinking; \“Wouldn’t it be cool\n".
                     "if I could predict every major freeze event for the Florida citrus crop over the next 250\n".
                     "years?  I would make a killing in the futures market!”  Well, hold on there my commodity\n".
                     "cowboy; you are getting a bit ahead of yourself. First, you have to create a global domain\n".
                     "before making your fortune. Your dream of making it rain money* will have to wait a few \n".
                     "more minutes.\n\n".

                     "Currently, only the WRF ARW core supports a global domain configuration, which is defined\n".
                     "on a cylindrical equidistant latitude-longitude grid.  Since you are wearing your \“I am\n".
                     "super fabulous\” thinking cap, you probably know that the areal coverage of a grid box on\n".
                     "a global latitude-longitude domain is maximized at the equator and decreases poleward toward\n".
                     "zero. Specifically, the physical distance between W-E oriented grid points along a latitude\n".
                     "circle decreases toward zero at the poles.  Because something multiplied by zero is usually\n".
                     "zero, this means that the time step used in your simulation will need to accommodate the \n".
                     "smallest shaped grid boxes to avoid an ugly CFL condition. But what time step is used when\n".
                     "the recommended 6 times the grid spacing is still zero?\n\n".

                     "The good news is that the global WRF employs a fast Fourier transform (FFT) filter that\n".
                     "removes high frequency waves during a simulation from a specified latitude to the poles.\n".
                     "This technique will allow you to use a time step larger than zero, which is a good thing if\n".
                     "you want to forecast major freeze events. The bad news is that the number of grid points in\n".
                     "the W-E and S-N directions is constrained such that they must adhere to the following equation:\n\n".

                     "X04XNX|NY = 2**P * 3**Q * 5**R + 1\n\n".
                     "X04XX04X(where P, Q, and R are any integers, including zero).\n\n".

                     "Relax - You don’t have to figure out whether your value for the number of grid points qualifies.\n".
                     "The ems_domain routine does all the work for you.\n\n".

                     "As mentioned above, the FFT filters are applied from a specified latitude, north and south, to\n".
                     "the poles. The default latitude is 45 degrees but can be changed prior to running a simulation\n".
                     "by editing the FFT_FILTER_LAT setting in run_dynamics.conf; however, it is not recommended that\n".
                     "you modify this value.\n\n".

                     "Finally, when defining a nested domain, it’s important that no part of the domain reside poleward\n".
                     "of the latitude defined by FFT_FILTER_LAT. Oh, you didn’t know that you could create nested domains\n".
                     "within your global empire? Read the details provided by \"--help g_nests\".\n\n\n".


                     "*  US or any other government currency in not a hydrometeor species supported by a microphysics\n".
                     "   scheme currently available in WRF, but we can all hope though.";




return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_gdxdy {
#===============================================================================
#  Routine provides guidance for using the --g_dxdy flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--g_dxdy  DX';

       $help{WHAT} = 'Define the spacing between horizontal grid points at the equator for a global domain';

       $help{USE}  = '% ems_domain --global --g_dxdy DX(deg|km) [other stuff]';

       $help{DESC} = "The \"--g_dxdy\" flag can be used an alternative to \"--g_nx\" and \"--g_ny\" to define the spacing ".
                     "between horizontal grid points along the equator. The grid space value must have a unit identifier ".
                     "appended to it, which can be either \"deg\" for degrees (e.g. --g_dxdy 0.25deg) or \"km\" for kilometers ".
                     "(E.g, --g_dxdy 25.5km). The ems_domain routine will calculate the number of grid points for the ".
                     "global domain from this value. The final value may deviate from the requested value due to the ".
                     "NX|NY = 2**P * 3**Q * 5**R + 1 requirement, but you’ll get over it.";

       $help{ADDN} = "Remember that the physical distance between grid points is only constant along a latitude circle and ". 
                     "decreases poleward. Additionally, the distance in the X-direction decreases more rapidly than in the ".
                     "Y-direction.";

return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_gnxny {
#===============================================================================
#  Routine provides guidance for using the --g_nxny flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--g_nx  NX and --g_ny  NY';

       $help{WHAT} = 'Define the number of grid points along longitude and latitude circles respectively';

       $help{USE}  = '% ems_domain --global --g_nx|ny NX|NY  [other stuff]';

       $help{DESC} = "You can pass either or both flags to specify the number of grid points over a global domain. Both ".
                     "flags take an integer argument that defines the number of grid points to use in the south-north ".
                     "(--g_ny) and west-east directions (--g_nx).\n\n".

                     "However, it is recommended that only the --g_nx flag be used, in which case ems_domain will ".
                     "automatically select a value for --g_ny so that the grid spacing in the NX and NY directions are ".
                     "similar and the number of grid points in the NY direction will equal to (NX+1)/2.";

       $help{ADDN} = "Just because you request a specific number of grid points does not mean ems_domain will use your values. ".
                     "This caveat is due to the global domain requirement that the number of grid points along a latitude ".
                     "circle must be equal to NX|NY = 2**P * 3**Q * 5**R + 1 (where P, Q, and R are any integers, including 0). ".
                     "This restriction is a due to the FFT filter implementation. So that you don’t have to figure out whether ".
                     "a value for the number of grid points qualifies, the UEMS will select a valid value that is closest to ".
                     "yours, which is usually pretty close.";


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_guseny {
#===============================================================================
#  Routine provides guidance for using the --g_useny flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--g_useny';

       $help{WHAT} = 'Retain the value of e_sn specified in the namelist file (GLOBAL ONLY)';

       $help{USE}  = '% ems_domain --global   --g_useny   [other stuff]';

       $help{DESC} = "Pass the --g_useny flag if you want to use the current NY value in the namelist.wps file ".
                     "when creating a global domain. By default, the number of Y-direction grid points (NY) will be ".
                     "calculated from the defined number of X-direction grid points (NX), such that NY = int (NX+1)/2.";

            
       $help{ADDN} = "You are probably best off packing this flag away until I can remember why this was such a good idea, ".
                     "which may be a long time.";


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_gnests {
#===============================================================================
#  Routine provides guidance for using the --gnests flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--g_nests';

       $help{WHAT} = 'Define nested domains to be included in a global domain (GLOBAL ONLY)';

       $help{USE}  = "% ems_domain --global --g_nests pid:slat:slon:nx:ny:ratio;pid:slat:slon:nx:ny:ratio;...\n\n".
                     "Where:\n".
                     "X04XX02Xpid    - The ID number of the parent domain\n".
                     "X04XX02Xslat   - The latitude of point 1,1 (southwest corner)\n".
                     "X04XX02Xslon   - The longitude of point 1,1 (Use negative for degrees west)\n".
                     "X04XX02Xnx     - The number of grid points in the NX direction (adjusted to parent points)\n".
                     "X04XX02Xny     - The number of grid points in the NY direction (adjusted to parent points)\n".
                     "X04XX02Xratio  - The ratio of child to parent grid point distance (either 3, 5, or 7)\n\n".

                     "Note that:\n\n".

                     "X04XX02X1. Fields are separated by a colon (:) and nested domains by a semicolon (;).\n".
                     "X04XX02X2. The ID number of a nest (child) begins at 2 and increases sequentially with each requested domain.\n".
                     "X04XX02X3. The Start Lat, Start Lon point will be adjusted by ems_domain to be collocated with the closest parent point.\n".
                     "X04XX02X4. NX and NY are the dimensions of a child domain, but may be adjusted to parent points. You will be notified should this happen.\n".
                     "X04XX02X5. The user must ensure that the areal coverage of a child domain falls entirely within that of its parent.\n\n".

                     "Some examples:\n\n".

                     "X04XX02X% ems_domain --global --g_nests 1:5:30:151:175:3;2:5:30:151:175:3\n".
                     "X04XOr\n".
                     "X04XX02X% ems_domain --global --g_nests 1:-5:-100:251:175:3;1:10:-170:151:171:5";



       $help{DESC} = "You can use the --g_nests flag to pass the navigation information for as many nested domains that you want ".
                     "to potentially include in your global simulation. You don’t have to include them all in a simulation, but ".
                     "they'll be available when you need them, just like a stuffy only not as soft.\n\nAll nested domains are on a ".
                     "limited area latitude-longitude grid, so you need to specify a parent domain number, a latitude and longitude ".
                     "of the sub-domain start point (point 1,1), the number of grid points in the NX and NY directions, and a value ".
                     "for the child:parent grid point ratio, typically either 3 or 5.\n\n".

                     "The values for each domain should be separated by a colon (:), with multiple domains separated by a semi-colon ".
                     "(;).  If necessary, the latitude and longitude of point 1,1 for a nested domain will be adjusted so that it is ".
                     "collocated with a parent domain grid point. The final NX and NY values may also be adjusted so that point NX, NY ".
                     "of your sub-domain is also collocated with a parent grid point. Fortunately, these changes are typically minor.\n\n".

                     "When defining a nested domain within a global mesh, it’s important that no part of the domain reside poleward of ".
                     "the latitude defined by FFT_FILTER_LAT. The default value of FFT_FILTER_LAT is 45 degrees N/S, and may be changed ".
                     "by editing the run_dynamics.conf file; however, it is not recommended that you change this value.";
            
       $help{ADDN} = "You could be the first to actually use this flag!"; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_notused {
#===============================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#===============================================================================
#
    my %help = ();
    my $flag = shift;
    
       $help{FLAG} = "--$flag";

       $help{WHAT} = 'Flag from the land of misfit options & stuff';

       $help{USE}  = "% ems_domain --$flag [don't even bother]";

       $help{DESC} = "Some flag are listed in the options module because they serve an internal purpose, such as ".
                     "being passed by Domain Wizard (DWIZ), used by UEMS Mission Control, or to maintain compatibility ".
                     "for legacy reasons. There isn't much to gain by attempting to pass one of these flags and more ".
                     "than likely you'll poke your own eye out.\n\n".

                     "So just don't do it.";
            
       $help{ADDN} = 'This message should have self-destructed 13.799 Billion years ago.'; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub DomainHelp_ncpus {
#===============================================================================
#  Routine provides guidance for using the --ncpus flag
#===============================================================================
#
    my %help = ();
    
       $help{FLAG} = '--ncpus #CPUS';

       $help{WHAT} = 'Specify the number of processors to use when running WRF geogrid (localization)';

       $help{USE}  = '% ems_domain --ncpus #CPUS [other more important stuff]';

       $help{DESC} = "Passing the \"--ncpus\" flag overrides the default value for the number of processors ".
                     "to use when running the WRF geogrid routine.  If \"--ncpus\" is not passed, then the UEMS ".
                     "will determine the number of physical cores on the system and use that value.\n\n".

                     "Note that just because you want X processors when running geogrid, doesn't mean the UEMS ".
                     "will use that many. The system will only use available physical (non-hyperthreaded) cores ".
                     "and will test for domain over-decomposition and reduce the number of cpus as necessary.";
                      
            
       $help{ADDN} = "The \”--ncpus\” flag is probably not the most important flag in your arsenal."; 


return &Ehelp::FormatHelpTopic(\%help);
}


