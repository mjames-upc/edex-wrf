#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Rhelp.pm
#
#  DESCRIPTION:  Rhelp contains subroutines used to provide love & guidance
#                to the user running ems_run, including the help menu and
#                information on each option.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Rhelp;

use warnings;
use strict;
require 5.008;
use English;

use Ehelp;


sub RunHelpMe {
#==================================================================================
#  The RunHelpMe routine determines what to do when the --help flag is
#  passed with or without an argument. If arguments are passed then the 
#  PrintRunOptionHelp subroutine is called and never returns.
#==================================================================================
#
    my @args  = &Others::rmdups(@_);

    &PrintRunOptionHelp(@args) if @args;

    &Ecomm::PrintTerminal(0,7,255,1,1,&ListRunOptions);

&Ecore::SysExit(-4); 
}


sub RunHelpMeError {
#==================================================================================
#  The RunHelpMeError routine determines what to do when the --help flag is
#  passed with or without an argument.
#==================================================================================
#
    my @args  = @_;

    &Ecomm::PrintTerminal(6,4,255,1,1,"It appears you have caused an error (@args)",&ListRunOptions);

&Ecore::SysExit(-4); 
}


sub ListRunOptions  {
#==================================================================================
#  This routine provides the basic structure for the ems_Run help menu 
#  should  the "--help" option is passed or something goes terribly wrong.
#==================================================================================
#

    my $mesg  = qw{};
    my @helps = ();

    my $exe = 'ems_run'; my $uce = uc $exe;

    my %opts = &DefineRunOptions();  #  Get options list

    push @helps => &Ecomm::TextFormat(0,0,114,0,1,"RUDIMENTARY GUIDANCE FOR $uce (Because you need it)");

    $mesg = "The ems_run routine handles many of the minor details that typically encumber users prior to ".
            "running a simulation. The routine is responsible for making sure that the model configuration ".
            "is valid, creating the initial and boundary conditions, and then running the simulation. It ".
            "also manages and controls the pre-run MPI configuration if you are distributing the job across ".
            "multiple computers and processors. These are just a few of the banal tasks that are typically ".
            "completed prior to running a simulation, and the UEMS understands that you have better things ".
            "to do with your time. Making your life easier so you can slack off, that's the primary ".
            "responsibility of ems_run.";

    push @helps => &Ecomm::TextFormat(2,2,90,1,1,$mesg);

    push @helps => &Ecomm::TextFormat(0,0,114,2,1,"$uce USAGE:");
    push @helps => &Ecomm::TextFormat(4,0,144,1,1,"% $exe [--domains 1,..,N] [Other options]");

    push @helps => &Ecomm::TextFormat(0,0,124,2,1,"AVAILABLE OPTIONS - BECAUSE YOU ASKED NICELY AND I'M BEGINNING TO LIKE THE WAY YOU SMELL");

    push @helps => &Ecomm::TextFormat(4,0,114,1,2,"Flag            Argument [optional]       Description");


    foreach my $opt (sort keys %opts) {
        push @helps => &Ecomm::TextFormat(4,0,256,0,1,sprintf("%-17s  %-18s  %-60s",$opt,$opts{$opt}{arg},$opts{$opt}{desc}));
    }


    push @helps => &Ecomm::TextFormat(0,0,114,2,2,"FOR ADDITIONAL HELP, LOVE AND UNDERSTANDING:");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"a. Read  - docs/uems/uemsguide/uemsguide_chapter08.pdf");
    push @helps => &Ecomm::TextFormat(2,0,114,0,1,"Or");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"b. http://strc.comet.ucar.edu/software/uems");
    push @helps => &Ecomm::TextFormat(2,0,114,0,1,"Or");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"c. % $exe --help <topic>  For a more detailed explanation of each option (--<topic>)");
    push @helps => &Ecomm::TextFormat(2,0,114,0,1,"Or");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"d. % $exe --help  For this menu again");

    my $help = join '' => @helps;


return $help;
}


sub DefineRunOptions {
#==================================================================================
#  This routine defined the list of options that can be passed to the program
#  and returns them as a hash.
#==================================================================================
#
    my %opts = (
                '--domains'   => { arg => 'DOMAIN:LENGTH'      , help => '&RunHelp_domains'    , desc => 'Include DOMAIN # in run for LENGTH hours; --domains #:LEN,#:LEN,..,#:LEN'},
                '--nudge'     => { arg => '[DOMAIN:LENGTH]'    , help => '&RunHelp_nudge'      , desc => 'Use 3D analysis nudging with DOMAIN # for LENGTH hours; --nudging #:LEN,#:LEN,..,#:LEN'},

                '--interp'    => { arg => ''                   , help => '&RunHelp_interp'     , desc => 'Interpolate nested static fields from parent domain (ARW nesting only)'},
                '--length'    => { arg => 'TIME<d|h|m|s>'      , help => '&RunHelp_length'     , desc => 'Override the default length of the WRF run'},
                '--levels'    => { arg => '# LEVELS'           , help => '&RunHelp_levels'     , desc => 'Specify the number of vertical levels in the model'},
                '--sdate'     => { arg => 'YYYYMMDDCC'         , help => '&RunHelp_sdate'      , desc => 'Set the start date for the model simulation (Primary domain)'},

                '--autopost'  => { arg => '[DOM#[:DS1[:DS2]]]' , help => '&RunHelp_autopost'   , desc => 'Turn autopost processing ON for domains 1 through Infinity+11'},
                '--ahost'     => { arg => 'HOSTNAME'           , help => '&RunHelp_ahost'      , desc => 'Specifies the hostname of the system on which to run UEMS Autopost'},

                '--dfi'       => { arg => '[OPT[:FILTER]]'     , help => '&RunHelp_dfi'        , desc => 'Turn ON (or OFF) Digital Filter Initialization (DFI) for the simulation'},

                '--restart'   => { arg => 'DATE STRING'        , help => '&RunHelp_restart'    , desc => 'Define start date/time for restart (YYYY-MM-DD_HH:00:00)'},

                '--noreal'    => { arg => ''                   , help => '&RunHelp_noreal'     , desc => 'Do not run the REAL program prior to starting simulation'},
                '--nowrf'     => { arg => ''                   , help => '&RunHelp_nowrf'      , desc => 'Do not run the WRF model. Just run REAL and then exit'},

                '--rundir'    => { arg => 'DIR'                , help => '&RunHelp_rundir'     , desc => 'Set the simulation run-time directory if not current (.) directory'},

                '--[no]scour' => { arg => ''                   , help => '&RunHelp_scour'      , desc => '[Do Not] tidy up the current domain directory prior to model execution'},
                '--debug'     => { arg => '[ARG]'              , help => '&RunHelp_debug'      , desc => 'Print out some less-than-informative messages debugging purposes (1|real|wrfm)'},

                '--runinfo'   => { arg => ''                   , help => '&RunHelp_runinfo'    , desc => 'Print current configuration and exit'},
                '--help'      => { arg => ''                   , help => '&RunHelp_help'       , desc => 'Either print this list again or pass me a topic and I\'ll explain it to you'}
                );


return %opts;
}


sub PrintRunOptionHelp {
#==================================================================================
#  The PrintRunOptionHelp takes a string that is matched to a help topic. 
#  There is no returning from this subroutine - ever.
#
#  This routine is a bit sloppy and should be cleaned up - You do it.
#==================================================================================
#
    my ($package, $filename, $line, $subr, $has_args, $wantarray)= caller(1);

    my $exit = ($subr =~ /CheckRunOptions/) ? -5 : -4;

    my %opts = &DefineRunOptions();  #  Get options list

    my $dash   = '-' x 108;
    my @topics = &Others::rmdups(@_);

    foreach my $topic (@topics) {

        my $flag = &Roptions::MatchRunOptions("--$topic");

        if ($flag and defined $opts{$flag}{help}) {

            my $help = eval $opts{$flag}{help}; 
               $help = "Hey - Add some magic words for the $flag flag!" unless $help;
  
            my $head = ($subr =~ /CheckRunOptions/) ? "It appears you need some assistance with the $flag flag:" 
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


sub RunHelp_help {
#==================================================================================
#  Routine provides guidance for using the --help flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--help';

       $help{WHAT} = "I'm the help flag, what did you expect?";

       $help{USE}  = '% ems_run --help [maybe a help topic]';

       $help{DESC} = "The \"--help\" flag should not need any introduction, but since you're rather new at this, I'll entertain ".
                     "your insatiable quest for knowledge and let you in on some valuable information.\n\n".

                     "Passing the \"--help\" flag without any arguments provides a list of flags and options that can be ".
                     "used with ems_run when running on the command line. It's fairly simple, and may be used as a quick ".
                     "reference to any utility should your brain fail you yet again.\n\n".

                     "Once the above usage has been mastered, there is else something you must learn that isn't taught during ".
                     "any \"Birds & Bees\" discussions. The \"--help\" flag can also take an argument in the form of a listed ".
                     "flag without the leading dashes (\"--\"). \"Wow!\" you exclaim, \"I didn't know that!\"\n\n".

                     "Well, now you know.  And at least you didn't have to hear it on the street.";

            
       $help{ADDN} = "The UEMS is the font of half of life's useful knowledge, kindergarten provides the rest."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub RunHelp_debug {
#==================================================================================
#  Routine provides guidance for using the --debug flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--debug';

       $help{WHAT} = 'Sets the level of debugging';

       $help{USE}  = '% ems_run --debug [1-9|real|wrfm] [other stuff]';

       $help{DESC} = "Passing the \"--debug\" defined the level of verbosity in the printing out of blather ".
                     "while attempting to determine what went so horribly wrong with ems_run. Values range ".
                     "from 1 to 9 with an increasing amount of information spewed to the screen the higher ".
                     "you go, most of which will be of little use to you.\n\n".

                     "You don't like numbers? Fine, the \"--debug\" flag also takes letters as well in the ".
                     "form of \"real\" or \"wrfm\". Passing \"--debug real\" instructs ems_run to exit just ".
                     "before processing of IC & BC files, while \"--debug wrfm\" exits prior to starting a ".
                     "simulation. In each case, a command string is printed out that can be used to run the ".
                     "specified routine from the command line so that you can figure out what went so horribly ".
                     "wrong with your wisely-crafted 1014-day global simulation. Good Luck!";
            
       $help{ADDN} = "Treat the \”--debug\” flag with the respect it deserves."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub RunHelp_autopost {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--autopost';

       $help{WHAT} = 'Turn autopost processing ON for domains 1 to Infinity+42';

       $help{USE}  = '% ems_run --ahost HOSTNAME  --autopost 1[:dsetA[:dsetP],...,Infinity+11    [superior flags]';

       $help{DESC} = "Passing the \"--autopost\" flag initiates concurrent post processing of the simulation ".
                     "output files, i.e, while the model is still running. This option is typically activated ".
                     "through the ems_autorun routine with the AUTOPOST parameter in ems_autorun.conf; however, ".
                     "you can play with it by passing the \"--autopost\" flag to ems_run.\n\n".

                     "It is highly recommended that another system, which is not included in running of the simulation, ".
                     "be configured for concurrent post processing duties. This recommendation is due to the ".
                     "increased system resources needed when processing model output, which may result in a ".
                     "severe degradation in performance.  The configuration options for the UEMS autopost can be found ".
                     "in the ems_autopost.conf file.\n\n".

                     "The argument to \"--autopost\" specifies the domains for which you want to turn autopost ".
                     "processing ON and the datasets to process. Currently, there are two model output ".
                     "datasets available for processing, primary and auxiliary, which are specified as \"primary\", ".
                     "and \"auxiliary\" respectively. One or both of these datasets, along with a domain ID, ".
                     "may be included as part of a \"rules group\" that is passed as an argument to \"--autopost\". ".
                     "The format for the argument string is:\n\n".

                     "X02X% ems_run --autopost ID1:ds1:ds2,ID2:ds1:ds2,...,IDN:ds1:ds2\n\n".

                     "where id# the domain ID to which to apply the rules, and ds1 & ds2 are placeholders for the \"primary\" ".
                     "and/or \"auxhist\" datasets, i.e, the \"rules\". Specifying rules for multiple domains is done ".
                     "by separating individual rule groups with a comma. A default rule group may also be included by ".
                     "excluding a domain ID. This default will be applied to any domain for which concurrent post ".
                     "processing is turned ON that does not have a rule group.  In the absence of a specified default ".
                     "rule group only the \"primary\" dataset (\"wrfout*\" for WRF) will be processed. Passing the ".
                     "\"--autopost\" flag without an argument turns concurrent post processing of the primary output ".
                     "files ON for all domains included in the simulation.\n\n".
    
                     "Note that this option is not intended to be passed from the command line. Don't do it!";


       $help{ADDN} = "Be careful of what you read about the autopost option in ems_autopost.conf, some of it might\n".
                     "actually be correct."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub RunHelp_ahost {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--ahost';

       $help{WHAT} = 'Specifies the hostname of the system on which to run UEMS Autopost';

       $help{USE}  = '% ems_run --ahost HOSTNAME  --autopost 1[:dsetA[:dsetP],...,Infinity+11    [superior flags]';

       $help{DESC} = "The \"--ahost\" flag specifies the hostname of the system on which to start ems_autopost.pl. ".
                     "The flag is passed along with \"--autopost\" by ems_autorun.pl when initiating concurrent ".
                     "post-processing of simulation output. When the the UEMS Autopost option is initiated, a separate ".
                     "process is started on HOSTNAME. The autopost routine will look for data files output during ".
                     "integration and then kick-off ems_post for those datasets requested for processing. Once the ".
                     "simulation has completed, ems_post will be run a final time to ensure all files are processed ".
                     "and then terminate.\n\n".

                     "Note that this option is not intended to be passed from the command line. Don't do it!";


       $help{ADDN} = 'Read all about the UEMS auto post-processor in the conf/ems_auto/ems_autopost.conf file.'; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub RunHelp_dfi {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--[no]dfi';

       $help{WHAT} = 'Turn ON [OFF] Digital Filter Initialization (DFI) for the simulation';

       $help{USE}  = '% ems_run --dfi [dfi option[:dfi filter]]   [again with the other stuff]';

       $help{DESC} = "Passing of the \"--dfi\" flag is used to override the DFI_OPT and DFI_NFILTER parameter ".
                     "settings in the run_dfi.conf file. Passing \"--dfi 0\" turns OFF all DFI processing unless ".
                     "DFI is already turned off (DFI_OPT = 0), in which case it does nothing.\n\n".

                     "An argument may be included with the \"--dfi\" flag to specify the DFI option number (1,2, or 3), ".
                     "and filter to be used (0, 1, 2, 3, 4, 5, 6, 7, or 8), separated by a colon. For example:\n\n".

                     "X02X% ems_run  --dfi  3:7,\n\n".

                     "which instructs ems_run to use Twice DFI (3) with the Dolph (7) filter.\n\n".

                     "Current DFI options include\n\n".

                     "X02X0 - No DFI will be used (same as --nodfi)\n".
                     "X02X1 - Digital filter launch (DFL)\n".
                     "X02X2 - Diabatic DFI (DDFI)\n".
                     "X02X3 - Twice DFI (Default)\n\n".

                     "The current DFI filters include:\n\n".

                     "X02X0 - Uniform\n".
                     "X02X1 - Lanczos\n".
                     "X02X2 - Hamming\n".
                     "X02X3 - Blackman\n".
                     "X02X4 - Kaiser\n".
                     "X02X5 - Potter\n".
                     "X02X6 - Dolph window\n".
                     "X02X7 - Dolph (Default)\n".
                     "X02X8 - Recursive high-order\n\n".

                     "If \"--dfi\" is passed without an argument, or with a partial argument, the default values will be used.";


       $help{ADDN} = 'If it seems as though everybody has a filter named after him or her, you would be correct. '.
                     'There are actually billions and billions of DFI filters but only 8 are listed above as this '.
                     'guide was getting long enough.';


return &Ehelp::FormatHelpTopic(\%help);
}


sub RunHelp_domains {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--domains';

       $help{WHAT} = 'Provide control over which domains to be included in the simulation';

       $help{USE}  = '% ems_run --domains  domain1[:FCST LENGTH],...,domainN[:FCST LENGTH]     [inferior flags]';

       $help{DESC} = "Passing the \"--domains\" flag specifies the domain(s) to include in your simulation. All the ".
                     "domain(s) must have been included when running ems_prep prior to ems_run; otherwise, an ".
                     "error will be generated and you will be left with a sinking feeling and wet shoes.\n\n".

                     "By default, ems_run will only execute the primary domain (Domain 1) unless the \"--domains\" ".
                     "flag is passed with an argument. Them's the rules.\n\n".

                     "The \"--domains\" flag can also be used to refine the length of nested simulations, which ".
                     "is done by including a length of time followed by the units; d (days), h (hours), m (minutes), ".
                     "or s (seconds). A colon (:) is used to separate the domain number from the length. For example:\n\n".

                     "X02X%   ems_run  --domains  domain#:length[units],...\n\n".

                     "Where,\n\n".

                     "X02Xdomain#  -  The domain number you wish to include\n".
                     "X02Xlength   -  The length of the nested domain simulation in specified units [units]\n\n".


                     "Note that:\n\n".

                     "X02X1.  The Domain number is mandatory but the length is optional\n".
                     "X02X2.  The length value is preceded by a colon (:) and must include units (d|h|m|s)\n".
                     "X02X3.  Multiple domains are separated by a comma (,)\n".
                     "X02X4.  In the absence of a length value, the simulation will default to the end time\n".
                     "X02XX04Xof the parent simulation.\n".
                     "X02X5.  If a length value extends a nested domain's ending date/time beyond that of\n".
                     "X02XX04Xits parent, ems_run will reduce the length of the nested simulation to coincide\n".
                     "X02XX04Xwith that of the parent.\n\n".


                     "Here is an example:\n\n".

                     "X02X%   ems_run --domains 2:3h,4:6h\n\n".

                     "Translation: Include domains 2 and 4 in the simulation and run for 2 and 6 hours respectively. ".
                     "If domain 4 is the child of 2, then the 6 (hours) will be ignored and domain 4 will be run for ".
                     "3 hours unless the parent of domain 2 (domain 1) is terminated prior to the end of the 3 hour ".
                     "simulation, in which case all three domains will end at the same time. If domain 4 is actually ".
                     "the child of domain 3 (DNA tested), which is not listed, then domain 3 will be automatically ".
                     "included with a start time and length of its parent domain.";
            
       $help{ADDN} = 'You must put your trust in Uncle UEMS. There are many checks to ensure that the start '.
                     'and stop times of the nested simulations are correct!'; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub RunHelp_interp {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--interp';

       $help{WHAT} = 'Interpolate nested static fields from parent domain (ARW nesting only)';

       $help{USE}  = '% ems_run --interp [superior flags]';

       $help{DESC} = "Interpolate nested domain static surface fields (terrain, land-sea mask, etc.) ".
                     "from the parent domain. When you crafted your computational domain, separate ".
                     "terrestrial datasets were created for the primary and each sub-domain, the ".
                     "resolution of which was commensurate with its grid spacing. These tailored ".
                     "fields are used for each sub-grid when running a nested simulation.\n\n".

                     "Passing the \"--interp\" flag tells the UEMS not to use these higher (generally) ".
                     "resolution fields during a simulation, but rather, interpolate the data from ".
                     "the lower resolution (again, generally) primary domain terrestrial dataset.\n\n".

                     "Typically, you do not want to pass the \"--interp\" flag unless you are investigating ".
                     "the influence of the higher resolution terrestrial fields on a simulation. You know, ".
                     "like research stuff.";
            
       $help{ADDN} = "As your mother would say: \"You stay away from those types of flags!\""; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub RunHelp_length {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--length';

       $help{WHAT} = 'Specify the primary domain simulation length';

       $help{USE}  = '% ems_run --length TIME<d|h|m|s>  [inferior flags]';

       $help{DESC} = "Passing the \"--length\" flag overrides the primary domain (1) default simulation length. ".
                     "The period over which a simulation is to be run is defined during the processing of GRIB ".
                     "into netCDF with ems_prep. In the absence of the \"--length\" flag, ems_run will use ".
                     "the period of time covered by the initialization data to determine the length of the run.\n\n".

                     "For limited area domains, the \"--length\" flag can only be used to shorten length of a ".
                     "simulation. Any value that exceeds the default length will be ignored, as will you. For ".
                     "global domains, the --length flag can be used to extend a simulation beyond the ending ".
                     "date/time specified when running ems_prep.\n\n".

                    "Important:  Reducing the length of the primary simulation may have an undesired effect ".
                    "on any included nested domains. For example, if an original (default) ".
                    "length of a primary domain simulation is 24 hours with a 6-hour nested simulation ".
                    "scheduled to start 12 hours after the start of the primary domain, and the \"--length 12h\" ".
                    "is passed to ems_run, the nested simulation would automatically be turned off since its ".
                    "start time is the same as the end time of the parent domain.";

       $help{ADDN} = 'Did you get all that information? Yes, I know, run-on sentences are tough.'; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub RunHelp_levels {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--levels';

       $help{WHAT} = 'Specify the number of vertical levels to include in the simulation';

       $help{USE}  = '% ems_run --levels #levels  [superior flags]';

       $help{DESC} = "The \"--levels\" flag serves to override the LEVELS parameter in run_levels.conf. The ".
                     "difference is that the \"--levels\" flag only accepts an integer number of levels and ".
                     "not a complete vertical distribution. All the domains included in the simulation will ".
                     "use the same number of levels and distribution.\n\n".
 
                     "As a rough guide, the number of levels should be proportional to the amount of baroclinicity ".
                     "in the model-simulated atmosphere. Thus, the number of levels may need to be increased ".
                     "during the cool season. Additionally, it is recommended that the number of levels be increased ".
                     "with smaller horizontal grid spacing, but this is just a suggestion.";

            
       $help{ADDN} = 'Increasing (decreasing) the number of levels will proportionally increase (decrease) the time required to run your simulation.'; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub RunHelp_noreal {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--noreal';

       $help{WHAT} = 'Do not run the WRF REAL program prior to starting a simulation';

       $help{USE}  = '% ems_run --noreal    [exterior flags]';

       $help{DESC} = "Pass the \"--noreal\" flag if you do not want to run the WRF real program prior to ".
                     "the start of a simulation. The real program is used to create the initial and boundary ".
                     "condition files that are used in the run, so you would only pass \"--noreal\" if you ".
                     "already have the \"wrfbdy_\" and \"wrfinput_\" files lying around in the run-time directory."; 
            
       $help{ADDN} = 'This flag is of limited use unless you are debugging something.'; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub RunHelp_nowrf {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--nowrf';

       $help{WHAT} = 'Terminate ems_run prior to running the model. Just run WRF REAL program';

       $help{USE}  = '% ems_run --nowrf [superior flags]';

       $help{DESC} = "Pass the \"--nowrf\" option if you do not want to run a simulation after the initial and ".
                     "boundary condition files are created. This flag is primarily used for testing and debugging ".
                     "purposes.";
            
       $help{ADDN} = 'Never mind, you know everything already.'; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub RunHelp_nudge {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--nudge';

       $help{WHAT} = 'Turn ON 3D analysis or spectral nudging during a simulation';

       $help{USE}  = "%  ems_run  --nudge [1|2]   bla, bla, bla and more bla";

       $help{DESC} = "Passing the \"--nudge\" flag turns ON 3D analysis or spectral nudging during a simulation. ".
                     "When \"--nudge\" is passed, the configuration information is obtained from the run_nudging.conf ".
                     "file, so please, do not play with the \"--nudge\" flag until you have read and understand (read twice) ".
                     "the available configuration options.\n\n".

                     "The lone argument to \"--nudge\" [1|2] serves to override the GRID_FDDA parameter in the ".
                     "configuration file, which specifies whether to do analysis (1) or spectral (2) nudging. Not ".
                     "including 1 or 2 will cause the UEMS to default to the value of GRID_FDDA in run_nudging.conf.\n\n".
  
                     "To summarize:\n\n".

                     "X02X% ems_run --nudge   -> Nudging ON & use value of GRID_FDDA\n".
                     "X02X% ems_run --nudge 1 -> Analysis nudging ON & ignore value of GRID_FDDA\n".
                     "X02X% ems_run --nudge 0 -> Spectral nudging ON & ignore value of GRID_FDDA\n\n\n".

                     "Super Important: If you want to do any sort of nudging during a simulation, you must also pass ".
                     "the --nudge flag when running ems_prep. This flag requests that the required nudging fields ".
                     "be created from the initialization datasets.\n\n".

                     "Just Remember: No \"ems_prep --nudge\", NO nudging love!";

            
       $help{ADDN} = 'More information on 3D nudging in the WRF is provided in Appendix G or thereabouts.'; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub RunHelp_restart {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--restart';

       $help{WHAT} = 'Initiate a restart run at the specified time';

       $help{USE}  = '% ems_run --restart YYYY-MM-DD_HH:00:00    [superior flags]';

       $help{DESC} = "When you want to restart the run simply make whatever changes you need ".
                     "and then pass \"--restart YYYY-MM-DD_HH:00:00\" to ems_run. The date/time ".
                     "string passed as an argument must correspond to one of the restart files ".
                     "listed in the rstprd directory. For example:\n\n".

                     "X02X%  ems_run  --restart 2009-06-18_11:00:00\n\n".

                     "You may also pass \"--length\" flag if you wish to shorten the length of ".
                     "the simulation:\n\n".

                     "X02X%  ems_run  --restart 2009-06-18_11:00:00 --length 12h\n\n".

                     "Where the length of the simulation from the ORIGINAL start time will be 12 ".
                     "hours. If the new length exceeds that of the original simulation it will be ".
                     "correctly adjusted.";
            
       $help{ADDN} = 'The restart capability in the UEMS is neither doctor tested nor mother approved.'; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub RunHelp_rundir {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--rundir';

       $help{WHAT} = 'Set the simulation run-time directory if not current (.) directory';

       $help{USE}  = '% ems_run --rundir <simulation run-time directory>   [superior flags]';

       $help{DESC} = "Pass the \"--rundir\" flag to specify the run-time domain use for a simulation. The ".
                     "domain directory must exist or ems_run will terminate, and you don't want that to ".
                     "happen now do you?\n\n".

                     "Note: This flag is not intended to be passed by a user. It is used by ems_autorun internally.";
            
       $help{ADDN} = "Nobody at UEMS world headquarters uses \"--rundir\", and neither should you."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub RunHelp_runinfo {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--runinfo';

       $help{WHAT} = 'Prints out the current model configuration and exit';

       $help{USE}  = '% ems_run --runinfo [--domains 1,..N]' ;

       $help{DESC} = "Passing the \"--runinfo\" flag will provide a listing of the current model configuration and ".
                     "then exit. The simulation will not be run but you'll have a good read.\n\n".

                     "Unless the \"--domains 1,..,N\" flag is also passed, ems_run will only list the configuration ".
                     "for the primary domain (Domain 1). If you are planning to use sub-domains in your simulation, ".
                     "then include the \"--domains\" flag to view the configuration for the other domains as well.";
            
       $help{ADDN} = "the \"--runinfo\" flag is your friend with benefits, unless you already have one."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub RunHelp_scour {
#==================================================================================
#  Routine provides guidance for using the --[no]scour flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--[no]scour';

       $help{WHAT} = 'Controls the amount of directory cleaning done prior to the start of ems_run';

       $help{USE}  = '% ems_run --[no]scour [more important stuff]';

       $help{DESC} = "Passing the \"--[no]scour\" flag overrides the default ems_run penchant for cleaning up the ".
                     "run-time directory prior to starting a new simulation. If this flag is not passed, the ".
                     "default level is the same as running \"ems_clean --level 2\", which deletes all non-essential ".
                     "files in the run-time directory.\n\n".

                     "Passing \"--noscour\" is the same as running \"ems_clean --level 0\", which simply ".
                     "deletes old log files and recreates the symbolic links to the run-time scripts.";
                      
            
       $help{ADDN} = "You probably will never need this option, but it's there for taking."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub RunHelp_sdate {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--sdate';

       $help{WHAT} = 'Set the start date for the model simulation (Primary domain)';

       $help{USE}  = '% ems_run --sdate YYYYMMDDHH [less interesting stuff]';

       $help{DESC} = "Passing the \"--sdate\" flag allows users to begin a simulation after the date/time ".
                     "assigned when running ems_prep. The date and time specified by YYYYMMDDHH must ".
                     "correspond to an initialization data file residing in the \"wpsprd\" directory; otherwise, ".
                     "ems_run will give you the \"Stink Eye\" and quit.\n\n".

                     "For example, if ems_prep is used to initialize a 24 hour simulation beginning at 00 UTC 30 ".
                     "February 2019, including a 3-hourly boundary condition update frequency, passing \"--sdate 2019023006\" ".
                     "will result in ems_run to use the initialization file from 06 UTC as the initial conditions for ".
                     "the simulation. When \"--sdate\" is passed, the length of the simulation will be adjusted accordingly.\n\n". 

                     "Warning: passing \"--sdate\" along with \"--domains\" may cause problems unless the start times for ".
                     "any sub-domains are specified to be later than that of the primary domain when running ems_prep. ".
                     "You probably don't want to go there.";

            
       $help{ADDN} = "Just like many things in life, the \"--sdate\" flag seemed like a good idea at the time."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub RunHelp_notused {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    my $flag = shift;
    
       $help{FLAG} = "--$flag";

       $help{WHAT} = 'Flag from the land of misfit options & stuff';

       $help{USE}  = "% ems_run --$flag [don't even bother]";

       $help{DESC} = "Some flag are listed in the options module because they serve an internal purpose, such as ".
                     "being passed within ems_autorun or to maintain compatibility for legacy reasons. There ".
                     "isn't much to gain by attempting to pass one of these flags and more than likely you'll poke ".
                     "your own eye out.\n\n".

                     "So just don't do it.";
            
       $help{ADDN} = 'This message should have self-destructed 13.799 Billion years and 36 days ago.'; 


return &Ehelp::FormatHelpTopic(\%help);
}


