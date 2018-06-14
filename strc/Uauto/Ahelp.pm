#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Ahelp.pm
#
#  DESCRIPTION:  Ahelp contains subroutines used to provide love & guidance
#                to the user running ems_autorun, including the help menu and
#                information on each option.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Ahelp;

use warnings;
use strict;
require 5.008;
use English;

use Ehelp;


sub AutoHelpMe {
#==================================================================================
#  The AutoHelpMe routine determines what to do when the --help flag is
#  passed with or without an argument. If arguments are passed then the 
#  PrintAutoOptionHelp subroutine is called and never returns.
#==================================================================================
#
    my @args  = &Others::rmdups(@_);

    &PrintAutoOptionHelp(@args) if @args;

    &Ecomm::PrintTerminal(0,7,255,1,1,&ListAutoOptions);

&Ecore::SysExit(-4); 
}


sub AutoHelpMeError {
#==================================================================================
#  The AutoHelpMeError routine determines what to do when the --help flag is
#  passed with or without an argument.
#==================================================================================
#
    my @args  = @_;

    &Ecomm::PrintTerminal(6,4,255,1,1,"It appears you have caused an error (@args)",&ListAutoOptions);

&Ecore::SysExit(-4); 
}


sub ListAutoOptions  {
#==================================================================================
#  This routine provides the basic structure for the ems_autorun help menu 
#  should  the "--help" option is passed or something goes terribly wrong.
#==================================================================================
#

    my $mesg  = qw{};
    my @helps = ();

    my $exe = 'ems_autorun'; my $uce = uc $exe;

    my %opts = &DefineAutoOptions();  #  Get options list

    push @helps => &Ecomm::TextFormat(0,0,114,0,1,"RUDIMENTARY GUIDANCE FOR $uce (Because you need it)");

    $mesg = "The purpose of the ems_autorun.pl routine is to automate the entire process of running a simulation ".
            "from data acquisition and model initialization to managing the output files. The routine reads a ".
            "user-controlled configuration file and then executes ems_prep.pl, ems_run.pl, and ems_post.pl in ".
            "succession. It is ideally suited for real-time forecast applications; however, it may also be used ".
            "to conduct other experiments such as case and sensitivity studies. For real-time forecasting, there ".
            "are features and options to improve the reliability of your forecasts. Additionally, there is even ".
            "an option for processing the output model data concurrent with a run.\n\n".

            "The ems_autorun routine is typically called from within a shell script or wrapper, which is initiated ".
            "via cron. If you prefer a more hands-on approach, the routine may also be run from the top level of a ".
            "domain directory. In each directory you will find a link from ems_autorun to the actual routine, ".
            "ems_autorun.pl, which resides under \"uems/strc.\" Beneath \"uems/strc\" exists the \"Uauto\" ".
            "subdirectory that contains all of the libraries used by ems_autorun.pl. Never run ems_autorun.pl ".
            "directly. In the event that the ems_autorun link gets deleted, it may be recreated by executing:\n\n".
            "X03X%  ems_clean --level 0";


    push @helps => &Ecomm::TextFormat(2,2,90,1,1,$mesg);

    push @helps => &Ecomm::TextFormat(0,0,114,2,1,"$uce USAGE:");
    push @helps => &Ecomm::TextFormat(4,0,144,1,1,"% $exe [Other options if you're in the mood]");

    push @helps => &Ecomm::TextFormat(0,0,124,2,1,"AVAILABLE OPTIONS - BECAUSE YOU ASKED NICELY AND I'M BEGINNING TO LIKE YOUR BLOODSHOT EYES");

    push @helps => &Ecomm::TextFormat(4,0,114,1,2,"Flag            Argument [optional]       Description");


    foreach my $opt (sort keys %opts) {
        push @helps => &Ecomm::TextFormat(4,0,256,0,1,sprintf("%-17s  %-18s  %-60s",$opt,$opts{$opt}{arg},$opts{$opt}{desc}));
    }


    push @helps => &Ecomm::TextFormat(0,0,114,2,2,"FOR ADDITIONAL HELP, LOVE AND UNDERSTANDING:");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"a. Read  - docs/uems/uemsguide/uemsguide_chapter10.pdf");
    push @helps => &Ecomm::TextFormat(2,0,114,0,1,"Or");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"b. http://strc.comet.ucar.edu/software/uems");
    push @helps => &Ecomm::TextFormat(2,0,114,0,1,"Or");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"c. % $exe --help <topic>  For a more detailed explanation of each option (--<topic>)");
    push @helps => &Ecomm::TextFormat(2,0,114,0,1,"Or");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"d. % $exe --help  For this menu again");

    my $help = join '' => @helps;


return $help;
}


sub DefineAutoOptions {
#==================================================================================
#  This routine defined the list of options that can be passed to the program
#  and returns them as a hash.
#==================================================================================
#
    my %opts = (
                '--[no]scour'   => { arg => ''                      , help => '&AutoHelp_scour'     , desc => '[Do Not] scour the domain and grib directories prior to running ems_autorun'},
                '--debug'       => { arg => ''                      , help => '&AutoHelp_debug'     , desc => 'Turn ON debugging statements (If any exist, which they may not)'},
                '--nolock'      => { arg => ''                      , help => '&AutoHelp_nolock'    , desc => 'Do not set a lock file when running simulation'},
                '--autopost'    => { arg => '[DOM#[:DS1[:DS2]]]'    , help => '&AutoHelp_autopost'  , desc => 'Turn autopost processing ON for domains 1 through Infinity+11'},
                '--emspost'     => { arg => '[DOM#[:DS1[:DS2]]]'    , help => '&AutoHelp_emspost'   , desc => 'Turn emspost processing ON for domains 1 through Infinity-11'},
                '--rundir'      => { arg => 'DOMAIN DIR'            , help => '&AutoHelp_rundir'    , desc => 'Set the simulation run-time directory if not current working directory'},
                '--[no]nudging' => { arg => ''                      , help => '&AutoHelp_nudging'   , desc => 'Turn [OFF} ON 3D Analysis or spectral nudging during the simulation'},
                '--length'      => { arg => 'HOURS'                 , help => '&AutoHelp_length'    , desc => 'Set the length of the simulation in hours. Overrides all other possible settings for length.'},
                '--cycle'       => { arg => 'HOUR[:...]'            , help => '&AutoHelp_rcycle'    , desc => 'The cycle time of the initialization dataset, plus a whole lot more'},
                '--dset'        => { arg => 'DSET[:...]'            , help => '&AutoHelp_dsets'     , desc => 'The dataset (and more) to use for initial and boundary conditions'},
                '--sfc'         => { arg => 'LIST'                  , help => '&AutoHelp_dsets'     , desc => 'List of static surface datasets used for initialization. Mostly follows --dset rules'},
                '--lsm'         => { arg => 'LIST'                  , help => '&AutoHelp_dsets'     , desc => 'List of land surface datasets used for initialization. Mostly follows --dset rules'},
                '--domains'     => { arg => 'DOMAIN[:START:STOP'    , help => '&AutoHelp_domains'   , desc => 'Specify the domain to be included in the simulation (Default is domain 1)'},
                '--date'        => { arg => 'YYYYMMDD'              , help => '&AutoHelp_date'      , desc => 'The date of the files used for initialization of the simulation'},
                '--help'        => { arg => '[TOPIC]'               , help => '&AutoHelp_help'      , desc => 'Either print this list again or pass me a topic and I\'ll explain it to you'},

#               '--analysis'    => { arg => '[FCST HOUR]'           , help => '&AutoHelp_analysis' , desc => 'The initialization dataset is a series of analyses or cycle forecast hour'},
                '--dsinfo'      => { arg => 'DSET'                  , help => '&AutoHelp_dsquery'   , desc => 'List information contained within the DSET_gribinfo.conf file'},
                '--dsquery'     => { arg => 'DSET'                  , help => '&AutoHelp_dsquery'   , desc => 'List information contained within the DSET_gribinfo.conf file (Same as --dsinfo)'},
                '--query'       => { arg => 'DSET'                  , help => '&AutoHelp_dsquery'   , desc => 'List information contained within the DSET_gribinfo.conf file (Same as --dsinfo)'},
                '--dslist'      => { arg => ''                      , help => '&AutoHelp_dslist'    , desc => 'List the datasets supported for initialization'},

                );

return %opts;
}



sub PrintAutoOptionHelp {
#==================================================================================
#  The PrintAutoOptionHelp takes a string that is matched to a help topic. 
#  There is no returning from this subroutine - ever.
#
#  This routine is a bit sloppy and should be cleaned up - You do it.
#==================================================================================
#
    my ($package, $filename, $line, $subr, $has_args, $wantarray)= caller(1);

    my $exit = ($subr =~ /CheckAutoOptions/) ? -5 : -4;

    my %opts = &DefineAutoOptions();  #  Get options list

    my $dash   = '-' x 108;
    my @topics = &Others::rmdups(@_);

    foreach my $topic (@topics) {

        my $flag = &Aoptions::MatchAutoOptions("--$topic");

        my @flags = keys %{$opts{$flag}};

        if ($flag and defined $opts{$flag}{help}) {

            my $help = eval $opts{$flag}{help}; 
               $help = "Hey Robert - Add some special words of wisdom for the $flag flag!" unless $help;
  
            my $head = ($subr =~ /CheckAutoOptions/) ? "It appears you need some assistance with the $flag flag:" 
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


sub AutoHelp_help {
#==================================================================================
#  Routine provides guidance for using the --help flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--help';

       $help{WHAT} = "I'm the help flag, what did you expect?";

       $help{USE}  = '% ems_autorun --help [maybe a help topic]';

       $help{DESC} = "The \"--help\" flag should not need any introduction, but since you're rather new at this, I'll entertain ".
                     "your insatiable quest for knowledge and let you in on some valuable information.\n\n".

                     "Passing the \"--help\" flag without any arguments provides a list of flags and options that can be ".
                     "used with ems_autorun from the command line. It's fairly simple, and may be used as a quick reference ".
                     "to any utility should your brain fail you once again.\n\n".

                     "Once the above usage has been mastered, there is else something you must learn that isn't taught during ".
                     "any \"Birds & Bees\" discussions. The \"--help\" flag can also take an argument in the form of a listed ".
                     "flag without the leading dashes (\"--\"). \"Wow!\" you exclaim, \"I didn't know that!\"\n\n".

                     "Well, now you know.  And at least you didn't have to hear it on the street.";

            
       $help{ADDN} = "The UEMS is the font of half of life's useful knowledge, the street provides the rest."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub AutoHelp_scour {
#==================================================================================
#  Routine provides guidance for using the --[no]scour flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--[no]scour';

       $help{WHAT} = '[Do Not] Completely scrub the run-time directory prior to running ems_autorun';

       $help{USE}  = '% ems_autorun --[no]scour [more important stuff]';

       $help{DESC} = "The \"--[no]scour\" flag is used to override the value of the SCOUR parameter in the ems_autorun.conf ".
                     "configuration file. By default (SCOUR = Yes), ems_autorun will do some selective culling of files ".
                     "and directories beneath the run-time domain directory prior to starting the process of running a ".
                     "simulation. This includes deleting any output files left from previous runs including initialization ".
                     "data in the \"grib\" directory, which is normally what you want for real-time forecasting purposes.\n\n".

                     "Passing \"--noscour\" overrides this behaviour by keeping the contents of the \"grib\" directory intact. ".
                     "The purpose for including this flag is if you were using ems_autorun for running case study simulations ".
                     "and wanted to keep the initialization files. This outcome can also be achieved by setting (SCOUR = No ".
                     "in the configuration file and then not having to remember to pass \"--noscour\" each time.\n\n".

                     "Conversely, passing \"--scour\" whacks the contents of the \"grib\", which is what you are likely to do ".
                     "following yet another unsuccessful simulation.";
                     
                 
       $help{ADDN} = "Remember - The default value for the SCOUR parameter in ems_autorun.conf is YES."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub AutoHelp_debug {
#==================================================================================
#  Routine provides guidance for using the --debug flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--debug';

       $help{WHAT} = 'Sets the level of debugging or something';

       $help{USE}  = '% ems_autorun --debug [other stuff]';

       $help{DESC} = "Passing the \"--debug\" prints out some additional information about the processing of simulation ".
                     "output with ems_autorun. It primarily serves the developer in debugging the problems that remain in ".
                     "in the routine, of which there are none.\n\n";

       $help{ADDN} = "Treat the \”--debug\” flag with the respect it deserves."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub AutoHelp_nolock {
#==================================================================================
#  Routine provides guidance for using the --nolock flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--nolock';

       $help{WHAT} = 'Do not set a lock file when running simulation';

       $help{USE}  = '% ems_autorun --nolock [more important stuff]';


       $help{DESC} = "Normally the ems_autorun routine will create a lock file in the uems/logs directory containing ".
                     "information about the simulation process ID (PID), start date/time, the domain directory, and ".
                     "hostname of the system running ems_autorun. Each time an ems_autorun simulation is initiated, ".
                     "the uems/logs directory is checked for existing lock files. If a lock file is found containing ".
                     "information indicating there may be an existing run in that same directory, the PID is checked ".
                     "against those processes running on the system. If the previous process has not finished, ems_autorun ".
                     "will wait (WAIT) for a specified amount of time for the simulation to complete before terminating itself.\n\n".

                     "When the \"--nolock\" option is passed, ems_autorun does NOT look for existing lock files before ".
                     "starting a simulation. It doesn't create a new one either. It just doesn't care.";



       $help{ADDN} = "See the WAIT parameter in ems_autorun.conf for more details."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub AutoHelp_nudging {
#==================================================================================
#  Routine provides guidance for using the --[no]nudging flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--[no]nudging';

       $help{WHAT} = 'Turn ON|OFF 3D analysis or spectral nudging as part of the simulation.';

       $help{USE}  = '% ems_autorun --[no]nudging [more important stuff]';


       $help{DESC} = "The \"--[no]nudging\" flag serves to override the NUDGING parameter found in ems_autorun.conf. Passing \"--nudging\" turns ".
                     "ON 3D analysis or spectral nudging as part of the simulation. If nudging is ON, the UEMS will process the initialization files ".
                     "and run the simulation based upon the configuration values specified in the conf/ems_run/run_nudge.conf file. So, if you are ".
                     "entertaining the idea of nudging, then make sure to read and configure run_nudge.conf.\n\n".

                     "The ems_autorun \"--nudging\" flag differs from a similar flag passed to ems_run (\"--nudge\") in that this option only serves ".
                     "to turn nudging ON|OFF, while \"--nudge\" takes additional arguments that override values in the run_nudge.conf file.";


       $help{ADDN} = "Remember to complete the necessary configuration in conf/ems_run/run_nudge.conf before turning ON nudging."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub AutoHelp_emspost {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--emspost';

       $help{WHAT} = 'Turn emspost processing ON for domains 1 to Infinity+42';

       $help{USE}  = '% ems_autorun --emspost 1[:dsA[:dsB],...,Infinity+11    [superior flags]';

       $help{DESC} = "Passing the \"--emspost\" flag initiates post processing of simulation output files after ".
                     "the model has completed integration. This option is typically activated via the EMSPOST ".
                     "parameter in ems_autorun.conf; however, you can override the configuration file values by ".
                     "passing \"--emspost\" to ems_autorun.\n\n".

                     "The argument to \"--emspost\" defines the domains for which you want to turn the post ".
                     "processing ON and the datasets to process. Currently, there are two model output ".
                     "datasets available for processing, primary and auxiliary, which are specified as \"primary\", ".
                     "and \"auxiliary\" respectively. One or both of these datasets, along with a domain ID, ".
                     "may be included as part of a \"rules group\" that is passed as an argument to \"--emspost\". ".
                     "The format for the argument string is:\n\n".

                     "X02X% ems_autorun --emspost ID1:dsA:dsB,ID2:dsA:dsB,...,IDN:dsA:dsB\n\n".

                     "where id# the domain ID to which to apply the rules, and dsA & dsB are placeholders for the \"primary\" ".
                     "and/or \"auxiliary\" datasets, i.e, the \"rules\". Specifying rules for multiple domains is done ".
                     "by separating individual rule groups with a comma. A default rule group may also be included by ".
                     "excluding a domain ID. This default will be applied to any domain for which concurrent post ".
                     "processing is turned ON that does not have a rule group.  In the absence of a specified default ".
                     "rule group only the \"primary\" dataset (\"wrfout*\" for WRF) will be processed. Passing the ".
                     "\"--emspost\" flag without an argument turns concurrent post processing of the primary output ".
                     "files ON for all domains included in the simulation.";


       $help{ADDN} = 'Be careful of what you read about the EMSPOST option in ems_autorun.conf, some of it might be correct.'; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub AutoHelp_autopost {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--autopost';

       $help{WHAT} = 'Turn autopost processing ON for domains 1 to Infinity+42';

       $help{USE}  = '% ems_autorun --autopost 1[:dsA[:dsB],...,Infinity+11    [superior flags]';

       $help{DESC} = "Passing the \"--autopost\" flag initiates concurrent post processing of the simulation ".
                     "output files, i.e, while the model is still running. This option is typically activated ".
                     "through the AUTOPOST parameter in ems_autorun.conf; however, you can activate it by ".
                     "passing the \"--autopost\" flag to ems_autorun.\n\n".

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

                     "X02X% ems_autorun --autopost ID1:dsA:dsB,ID2:dsA:dsB,...,IDN:dsA:dsB\n\n".

                     "where id# the domain ID to which to apply the rules, and dsA & dsB are placeholders for the \"primary\" ".
                     "and/or \"auxiliary\" datasets, i.e, the \"rules\". Specifying rules for multiple domains is done ".
                     "by separating individual rule groups with a comma. A default rule group may also be included by ".
                     "excluding a domain ID. This default will be applied to any domain for which concurrent post ".
                     "processing is turned ON that does not have a rule group.  In the absence of a specified default ".
                     "rule group only the \"primary\" dataset (\"wrfout*\" for WRF) will be processed. Passing the ".
                     "\"--autopost\" flag without an argument turns concurrent post processing of the primary output ".
                     "files ON for all domains included in the simulation.";


       $help{ADDN} = 'Be careful of what you read about the AUTOPOST option in ems_autorun.conf, some of it might be correct.'; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub AutoHelp_rundir {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--rundir';

       $help{WHAT} = 'Set the simulation run-time directory if not current (.) directory';

       $help{USE}  = '% ems_autorun --rundir <simulation run-time directory>   [superior flags]';

       $help{DESC} = "Pass the \"--rundir\" option if you want to specify the run-time directory to use in your simulation. ".
                     "This option is not recommended for use when running ems_autorun from the command line, although this ".
                     "suggestion will probably not stop most of you.\n\n".

                     "Not passing \"--rundir\" will set the current working directory as the run-time domain, which is probably ".
                     "what you want when running from the command line.  The run-time directory must exist or ems_autorun will ".
                     "terminate, and you don't want that to happen now do you? So again, it is probably in your best interest to ".
                     "leave this option alone.\n\n".

                     "Typically, you would only include \"--rundir\" as an argument to uems_autorun-wrapper.csh|sh in a crontab ".
                     "entry for real-time simulations, but hey, who am I to stop you from using it for other ill-conceived activities.";


       $help{ADDN} = "Nobody at UEMS world headquarters uses \"--rundir\", and neither should you."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub AutoHelp_length {
#==================================================================================
#  Routine provides guidance for using the --length flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--length HOURS';

       $help{WHAT} = 'Specify the simulation length (hours) for the primary domain';

       $help{USE}  = '% ems_autorun --length HOURS [other stuff]';

       $help{DESC} = "Passing the \"--length\" flag defines the maximum length of the primary domain simulation in hours. There are ".
                     "multiple ways in which the simulation length can be specified (See \"--cycle\" and \"--domains\" flags), but ".
                     "the \"--length\" flag overrides all other options & flags. Something has to have the ultimate power, and that ".
                     "something would be the UEMS developer. However, in my absence, the \"--length\" flag carries the responsibility.\n\n".

                     "Here is just one example of the power bestowed upon \"--length\"\n\n".

                     "    % ems_autorun --dset <dataset> --cycle 00:06 --length 36\n\n".

                     "is the same as passing:\n\n".

                     "    % ems_autorun --dset <dataset> --cycle 00:06:42:03  (Note: 42-6 = 36)\n\n";

       $help{ADDN} = "The \”--length\” option must be used when specifying separate datasets for initial ". 
                     "and boundary conditions (See: \"--dset\" option).";


return &Ehelp::FormatHelpTopic(\%help);
}


sub AutoHelp_rcycle {
#==================================================================================
#  Routine provides guidance for using the --cycle flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--cycle HOUR[:INITFH[:FINLFH[:FREQFH]]]';

       $help{WHAT} = 'Specifies the cycle time of the initialization dataset, initial and final forecast '.
                     'hour, and boundary condition update frequency. NOTE: not for use with real-time '.
                     'forecast applications!  No, just don\'t do it.';

       $help{USE}  = '% ems_autorun --cycle HOUR[:INITFH[:FINLFH[:FREQFH]]] [other stuff]';


       $help{DESC} = "First - The Default Behavior When NOT Passing \"--cycle\":\n\n".

                     "Not passing the \"--cycle\" flag will cause ems_autorun to use the UTC cycle time of the most recent model ".
                     "run from which data are available. The list of available cycles is already defined by the CYCLES ".
                     "parameter in each of the <dset>_gribinfo.conf files. To determine the most current available cycle time, ".
                     "ems_autorun accounts for the amount of time required for an operational model to run and process any data ".
                     "files for distribution. This delay between the official UTC cycle time and when the data files first become ".
                     "available is defined in the DELAY parameter in the <dset>_gribinfo.conf file.\n\n". 
  
                     "For example, if the 12 UTC GFS takes three hours to run and process forecast GRIB files for distribution ".
                     "(DELAY = 3), ems_autorun will not attempt to obtain the data until after 15Z. If ems_autorun is run, say at ".
                     "at 14:55 UTC (again, without \"--cycle\"), data from the 06 UTC cycle will be acquired because that is the ".
                     "most current run from which data are available.\n\n\n".

                     "Now for the Behavior When \"--cycle\" is Passed:\n\n".

                     "The --cycle flag specifies the cycle time of the model dataset to use for initialization of your ".
                     "simulation. The general usage is:\n\n".

                     "  %  ems_autorun --dset gfs --cycle CYCLE\n\n".

                     "When you specify the cycle time of the dataset to be acquired, ems_autorun will attempt to access the most ".
                     "recent dataset available corresponding to that cycle time (assuming \"--date\" was not passed). So using the ".
                     "GFS example above, passing \"--cycle 12\" at 14:55 UTC will cause ems_autorun to acquire data from the ".
                     "previous 12 UTC run as opposed to the 06 UTC cycle if \"--cycle 12\" had not been passed (default).\n\n\n".

                     "But wait, there's more, whether you want it or not.\n\n".

                     "The --cycle flag accepts additional arguments that override the initial forecast hour, final forecast hour, and ".
                     "frequency of the boundary condition files, the default values of which are defined in each <dataset>_gribinfo.conf ".
                     "file as INITFH, FINLFH, and FREQFH respectively. The format for the argument list is:\n\n".

                     "  %  ems_autorun --dset gfs --cycle HOUR[:INITFH[:FINLFH[:FREQFH]]]\n\n".
               
                     "Where the brackets indicate that everything is optional. These optional arguments are passed as a string, with ".
                     "each separated by a colon (:). Trailing colons need not be included.\n\n\n".

                     "Here are a few examples. Feel free to make some of your own.\n\n".

                     "  %  ems_autorun --dset gfs --cycle 00:00:24:03\n\n".

                     "Translation: Use the 00 UTC cycle time, the 00 hour forecast for the initialization time, the 24 hour forecast for ".
                     "the final BC time (thus a 24 hour forecast), and use 3-hourly files for boundary conditions. In this example, ems_autorun ".
                     "will attempt to download the 00, 03,06,09,12,15,18,21, and 24 hour forecast files from the most recent 00 UTC cycle of ".
                     "the GFS. All default values for these parameters are overridden, or in UEMS Central Headquarter's parlance, \"Crushed.\"\n\n\n".


                     "More examples - Just because we're having so much fun together:\n\n".

                     "  %  ems_autorun --dset gfs  --cycle 06:06:30\n\n".

                     "Translation: Use the 06 UTC cycle time, the 06-hour forecast for the initialization hour and the 30-hour forecast for the final ".
                     "boundary condition time (a 24 hour forecast). Because the BC update frequency (FREQFH) was not passed the default value in ".
                     "gfs_gribinfo.conf file will be used.\n\n\n".

                     "Tell me if you've heard this one before. What is the difference between the following:\n\n".

                     "    %  ems_autorun --dset gfs --cycle CYCLE:INITFH:36:12\n".
                     "And\n".
                     "    %  ems_autorun --dset gfs --cycle ::36:12\n\n".

                     "Answer:  NOTHING! In both cases, the data files from most current available cycle hour will be used (default) starting ".
                     "from the default initialization forecast hour found in gfs_gribinfo.conf (INITFH) through the 36 hour forecast, with a 12-hourly ".
                     "BC update frequency. So if INITFH = 0 in gfs_gribinfo.conf, then the 00, 12, 24, and 36-hour frecast files from most current ".
                     "run of the GFS will be used to initialize your simulation.  The inclusion of 'CYCLE:INITFH', or 'CYCLE:INITFH:FINLFH:FREQFH' are ".
                     "not necessary but still valid.\n\n\n".

                     "If you choose not to use the placeholders, then remember that leading colons are require but trailing ones are not:\n\n".

                     "  %  ems_autorun --dset gfs --cycle :::12\n\n".
                  
                     "Use all default values except 12 hourly BC updates.\n\n".
                  
                     "  %  ems_autorun --dset gfs --cycle :24:84\n\n".

                     "Use the defaults for cycle & BC update use 24 hour through 84 hour forecast files.\n\n\n".

                     "You have the power; use it wisely and often.";


       $help{ADDN} = "Again, the \"--cycle\" flag is not for use with real-time forecast applications!"; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub AutoHelp_dsets {
#==================================================================================
#  Routine provides guidance for using the --dset flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--dset, --sfc, and --lsm ';

       $help{WHAT} = 'Manage the datasets included in the model initialization';

       $help{USE}  = "  % ems_autorun --dset <dataset>[:METHOD:SOURCE:LOCATION]%[dataset[:METHOD:SOURCE:LOCATION]]\n".
                     "Or\n".
                     "  % ems_autorun --sfc  <dataset>[:METHOD:SOURCE:LOCATION],[dataset[:METHOD:SOURCE:LOCATION]],...\n".
                     "Or\n".
                     "  % ems_autorun --lsm  <dataset>[:METHOD:SOURCE:LOCATION],[dataset[:METHOD:SOURCE:LOCATION]],...\n";


       $help{DESC} = "In their simplest usage, the \"--dset\", \"--sfc\", and \"--lsm\" flags specify the datasets to use for ".
                     "initial and boundary conditions (--dset), surface (--sfc), and land-surface (--lsm) fields ".
                     "respectively. Note that \"--dset <dataset>\" is the only mandatory flag while the inclusion ".
                     "of \"--sfc\" or \"--lsm\" is optional.\n\n".

                     "The behavior of these flags is inextricably tied to the parameters and settings found in the ".
                     "associated <dataset>_gribinfo.conf files. In particular, the SERVERS section (Appendix A), ".
                     "which defines the source(s) for the datasets. Thus, to fully understand the functionality ".
                     "of these flags, you should review the SERVERS section of a <dataset>_gribinfo.conf file. ".
                     "Just pick one and read it, they basically all say the same thing.\n\n".

                     "For the sake of this instruction, assume that the SERVERS section in gfs_gribinfo.conf looks ".
                     "something like:\n\n".

                     "  SERVER-FTP = NCEP:/pub/data/nccf/com/gfs/prod/gfs.YYYYMMDDCC/gfs.tCCz.pgrb2fFF\n".
                     "  SERVER-FTP = TGFTP:/data/RD.YYYYMMDD/PT.grid_DF.gr2/fh.00FF_tl.press_gr.0p5deg\n\n".

                     "  SERVER-HTTP = STRC:/data/grib/YYYYMMDD/gfs/grib.tCCz/YYMMDDCC.gfs.tCCz.pgrb2fFF\n".
                     "  SERVER-HTTP = TOC:/data/RD.YYYYMMDD/PT.grid_DF.gr2/fh.00FF_tl.press_gr.0p5deg\n\n".

                     "  SERVER-NFS = DATA1:/usr1/ems/data/YYYYMMDD/YYMMDDCC.gfs.tCCz.pgrb2fFF\n".
                     "  SERVER-NFS = /data/grib/YYYYMMDD/YYMMDDCC.gfs.tCCz.pgrb2fFF\n\n".

                     "The above entries show two FTP sources for initialization files (NCEP and TGFTP), two HTTP ".
                     "sources (STRC and TOC), and two NFS sources (DATA1 and the local system). Each of the server ".
                     "IDs, i.e., NCEP, TGFTP, STRC, TOC, and DATA1 correspond to predefined hostnames or IP addresses ".
                     "located in the uems/conf/ems_autorun/prep_hostkeys.conf file. The NFS entry without a server ID ".
                     "specifies the location of the gfs files on the local file system.\n\n".

                     "Let us begin with the simplest usage of \"--dset\":\n\n".

                     "  %  ems_autorun --dset <dataset>\n\n".

                     "Or how it's done on the street:\n\n".

                     "  %  ems_autorun --dset gfs\n\n".


                     "If you were to run the \"ems_autorun --dset gfs\" command in the example above, ems_autorun would use ".
                     "the information located in the SERVERS section of gfs_gribinfo.conf file to acquire the initialization ".
                     "files. The order (HTTP, FTP, and NFS) and sources (server IDs) of the data are semi-randomized ".
                     "so as not to access the sources in the same order every time. If ems_autorun is unsuccessful in acquiring ".
                     "the necessary files at the first location it will move on to the next. This process ".
                     "will continue until all data sources have been exhausted, at which time ems_autorun will request that ".
                     "you re-evaluate your life goals. Yes, ems_autorun will attempt every possible source identified in the ".
                     "gfs_gribinfo.conf file, because \"Working harder so you can slack off!\" would be ems_autorun's motto ".
                     "if it had one, which it doesn't.\n\n".


                     "At this point you should be aware that any files acquired by ems_autorun will be written to the <domain>/grib ".
                     "directory and renamed according to the naming convention defined by the LOCFIL parameter in the ".
                     "<dataset>_gribinfo.conf file. When you run the routine, ems_autorun will first look in <domain>/grib and ".
                     "determine whether the requested files already exist and attempt to acquire any that are missing.\n\n".


                     "There are additional arguments that may be included with the \"--dset <dataset>\" flag that serve to modify its ".
                     "default behavior:\n\n".

                     "  %  ems_autorun --dset <dataset>[:[METHOD]:[SOURCE]:[LOCATION]]\n\n".

                     "Where METHOD, SOURCE, and LOCATION specify the method of acquisition, the source of the files, and the ".
                     "directory location and naming convention used on the remote server respectively. Here is a brief summary ".
                     "of each:\n\n\n".


                     "Placeholder: METHOD\n".
                     "---------------------\n\n".

                     "The METHOD placeholder is used to control the method of data acquisition. The default behavior of ems_autorun is to ".
                     "attempt each method and source listed in the <dataset>_gribinfo.conf file, but you can modify this processes by ".
                     "including a keyword in the METHOD position shown above. Possible keywords include:\n\n".

                     "  nfs    - Only use the SERVER-NFS entries in the <dataset>_gribinfo.conf file\n".
                     "  ftp    - Only use the SERVER-FTP entries in the <dataset>_gribinfo.conf file\n".
                     "  http   - Only use the SERVER-HTTP entries in the <dataset>_gribinfo.conf file\n".

                     "  nonfs  - Don't use the SERVER-NFS entries in the <dataset>_gribinfo.conf file\n".
                     "  noftp  - Don't use the SERVER-FTP entries in the <dataset>_gribinfo.conf file\n".
                     "  nohttp - Don't use the SERVER-HTTP entries in the <dataset>_gribinfo.conf file\n".

                     "  none   - Don't use any of the methods listed in the SERVERS section. All files \n".
                     "           are assumed to be correctly named and reside in the <domain>/grib directory\n\n\n".

                     "The above flags should cover just about everything. Here are just a few of examples:\n\n".

                     "  %  ems_autorun --dset gfs:ftp\n\n".

                     "Translation: Only use the SERVER-FTP entries in the gfs_gribinfo.conf file to acquire data. If ems_autorun fails to ".
                     "locate data from NCEP and TGFTP it will not use the other methods listed and you will be devastated.\n\n".


                     "  %  ems_autorun --dset gfs:noftp \n\n".

                     "Translation: Do not use the SERVER-FTP entries in the gfs_gribinfo.conf file to acquire data. The ems_autorun routine ".
                     "will use the other methods listed (NFS and HTTP) to acquire the files.\n\n".


                     "  %  ems_autorun --dset gfs:none \n\n".

                     "Translation: Do not attempt to acquire the files as they already are correctly named and reside in the <domain>/grib ".
                     "directory (as explained above). Note that commenting out or deleting all the SERVER entries in the gfs_gribinfo.conf ".
                     "file OR by passing may achieve the same behavior:\n\n".

                     "  %  ems_autorun --dset gfs --nomethod\n\n\n".


                     "Placeholder: SOURCE\n".
                     "---------------------\n\n".

                     "The SOURCE placeholder is used to specify the source, or server, of the files being requested. It typically takes the ".
                     "form of the server ID as specified in the SERVERS section, (i.e. NCEP, TGFTP, STRC, TOC, and DATA1), and may be ".
                     "associated with multiple methods. For example:\n\n".

                     "  %  ems_autorun --dset gfs:http:strc\n\n".

                     "tells ems_autorun to only acquire the gfs files from the STRC server via http. The location of the files on the remote ".
                     "server and the file naming convention are obtained from the SERVER-HTTP = STRC: entry in the gfs_gribinfo.conf file.\n\n".

                     "The use of a METHOD is optional. When excluding METHOD, ems_autorun will use all the methods listed that are associated with a ".
                     "given source:\n\n".

                     "  %  ems_autorun --dset gfs::strc  <-- No method specified so use all listed\n\n".


                     "To acquire files locally that do not have a SOURCE associated with them in the <dataset>_gribinfo.conf file, such as in the ".
                     "last SERVER-NFS entry above, use \"local\":\n\n".

                     "  %  ems_autorun --dset gfs:nfs:local\n\n\n".


                     "Placeholders: METHOD, SOURCE, and LOCATION together, just like one big, happy family\n".
                     "--------------------------------------------------------------------------------------\n\n".

                     "The SOURCE may also take the form of a hostname or IP address. This is best done in combination with METHOD and LOCATION. ".
                     "By using all three arguments, you can request that initialization files be acquired from a location not listed ".
                     "in <dataset>_gribinfo.conf. The format will look similar to a SERVER entry:\n\n".

                     "  %  ems_autorun --dset gfs:http:nomad6:/pub/gfs/YYYYMMDD/gfs.tCCz.pgrbfFF\n".
                     "Or\n".
                     "  %  ems_autorun --dset gfs:http:nomads6.ncdc.noaa.gov:/pub/gfs/YYYYMMDD/gfs.tCCz.pgrbfFF\n".
                     "Or\n".
                     "  %  ems_autorun --dset gfs:http:205.167.25.170:/pub/gfs/YYYYMMDD/gfs.tCCz.pgrbfFF\n\n".

                     "All of the above examples are equivalent, provided that there is a NOMAD6 server ID entry in the prep_global.conf file. Any ".
                     "placeholders such as YYYYMMDD will be dutifully filled in with the appropriate values. Also, you must specify a METHOD; ".
                     "otherwise something will fail.\n\n\n".


                     "Using Multiple datasets\n".
                     "-------------------------\n\n".

                     "The \"--dset\" flag can be used to request different datasets to serve as initial and boundary conditions. For example, if you ".
                     "wish to use 12km NAM files as the initial conditions and 0.5 degree GFS for your boundary conditions, simply separate ".
                     "the two datasets with a \"%\" in the dataset argument to \"--dset\", i.e.\n\n".

                     "  %  ems_autorun --dset nam218%gfs  --length 24\n\n".

                     "Wherein ems_autorun will attempt to acquire a single nam218 file to use as the initial conditions (00-hour) and GFS files will ".
                     "be used for the boundary conditions through 24 hours.\n\n".

                     "IMPORTANT:  The \"--length\" flag must be used when specifying multiple datasets.\n\n".

                     "All the optional flags detailed ad nauseam above are available for use with multiple datasets as well.  For example, knock ".
                     "yourself out with such classics as:\n\n".

                     "  %  ems_autorun --dset nam218:http%gfs::strc  --length 36\n\n".

                     "Translation: Only use the SERVER-HTTP entries in the nam218_gribinfo.conf file to acquire data for use as the initial conditions, ".
                     "and use all the methods listed in the gfs_gribinfo.conf file to obtain the boundary conditions files through 36 hours.\n\n\n".


                     "Using Static Surface (--sfc) and Land Surface datasets (--lsm)\n".
                     "----------------------------------------------------------------\n\n".

                     "There are two additional flags used for acquiring and processing of surface and land-surface dataset named \"--sfc\" and ".
                     "\"--lsm\" respectively.  These flags behave very similar to \"--dset\", i.e.,\n\n".

                     "  --sfc  dataset[:METHOD:SOURCE:LOCATION],[dataset[:METHOD:SOURCE:LOCATION]],...\n".
                     "And\n".
                     "  --lsm  dataset[:METHOD:SOURCE:LOCATION],[dataset[:METHOD:SOURCE:LOCATION]],...\n\n".

                     "The primary difference between \"--sfc\", \"--lsm\", and the \"--dset\" flag is that multiple datasets are separated by a comma ".
                     "(\",\") and not a \"%\" as with \"--dset\".\n\n".


                     "When multiple datasets are specified, such as:\n\n".

                     "  --sfc  sstpt,rtgsst\n".
                     "Or\n".
                     "  --lsm  lis,rappt\n\n".

                     "The first dataset listed in the string will take priority in the initialization processes.  By using multiple datasets, users ".
                     "can specify a fail-over dataset should a more desired one not be available.\n\n".

                     "The \"--sfc\" flag allows users to acquire and process surface fields such as sst or snow cover, which  will be used to replace or ".
                     "augment a field or fields in the primary initialization dataset specified by \"--dset\". An example of using the \"--sfc\" ".
                     "flag would be:\n\n".

                     "  %  ems_autorun --dset gfs  --sfc rtgsst:ftp:nomads\n\n".

                     "The above use of the \"--sfc\" flag would replace the sst fields in the GFS dataset with the 1/12th degree sst field from the ".
                     "polar ftp server.\n\n".


                     "Fail-over Option with Land Surface datasets (--lsm)\n".
                     "---------------------------------------------------\n\n".

                     "For including surrogate LSM-based fields such as skin temperature, soil moisture and temperature, the \"--lsm\" flag can be used. ".
                     "A major difference between the \"--sfc\" and \"--lsm\" flags is that while the \"--sfc\" datasets are not required for model ".
                     "initialization, ems_autorun will terminate if any of the \"--lsm\" datasets are missing. To reduce the likelihood of your forecast ".
                     "coming to an untimely demise, fail-over datasets can be specified should your first choice not be available. In this application, ".
                     "the pipe (|) character is used to separate a succession of datasets in decreasing order of desirability (from left to right). If ".
                     "a dataset in this list is not available, ems_autorun will proceed to the next. Once a dataset from the list is acquired, the search ".
                     "ends and ems_autorun continues with processing of the files; however, if none of the listed fail-over options are found, the ".
                     "entire process terminates and your forecast dreams are dashed once again.\n\n".

                     "The use of the \"|\" separator should not be confused with the comma-separated LSM datasets. The comma is used to specify multiple ".
                     "datasets that are mandatory for model initialization, while a \"|\" is used to specify alternatives to each mandatory data type. ".
                     "Additionally. when using \"|\" separator with the \"--lsm\" flag, the entire string must be in quotations. This is due to how ".
                     "the Linux command line interpreter handles the pipe symbol.\n\n".

                     "Here is a slightly less confusing example:\n\n".

                     "  --lsm  \"Alsm1|Alsm2|Alsm3,Blsm1|Blsm2\"   Note the use of quotations!\n\n".

                     "Assuming that the datasets listed above actually mean anything, this example specifies that two LSM datasets are required for ".
                     "model initialization; one from group \"A\", Alsm1|Alsm2|Alsm3, and one from group \"B\", Blsm1|Blsm2. The ems_autorun routine will ".
                     "first attempt to get Alsm1 from group A. Should that dataset not be available, it will try to get the Alsm2 dataset, and so on. ".
                     "If successful, the routine will next attempt to acquire Blsm1 from the second group with Blsm2 serving as a fail-over. Should ".
                     "ems_autorun fail to locate a dataset from any group, model initialization is over for you.\n\n\n".

                     "A few Comments Regarding the Use of Alternative LSM Fields\n".
                     "------------------------------------------------------------\n\n".

                     "Care should be used when using LSM Fields such as skin temperature, soil moisture and temperature that server to replace ".
                     "or augment similar fields already available from the primary initialization dataset(s) (\"--dset\"). This word of caution is ".
                     "predicated on the primary dataset fields already being \"in balance\" with one another. The substitution of an external field, ".
                     "such as skin temperature, is likely to introduce an initial imbalance to the system resulting in additional \"spin-up\" time ".
                     "once the simulation begins.\n\n".

                     "Additionally, do not use any supplementary dataset that does not completely cover your primary computational domain (Domain 1)! ".
                     "While it is possible to introduce an external data source with partial areal coverage, the resulting field used for integration ".
                     "will likely have a discontinuity where the non-primary dataset ends. This discontinuity will likely lead to undesirable results ".
                     "within your simulation.";



            
       $help{ADDN} = "You might want to pipe this output to \"more\":  \"% ems_autorun --help dset | more\""; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub AutoHelp_date {
#==================================================================================
#  Routine provides guidance for using the --date flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--date ';

       $help{WHAT} = 'Specify the date of the dataset to use for initialization.  NOTE: not for use with real-time '.
                     'forecast applications!  No, just don\'t do it.';

       $help{USE}  = '% ems_autorun --date [YY]YYMMDD [other important stuff]';

       $help{DESC} = "Passing the \"--date\" flag specifies the date of the dataset used for model initialization. ".
                     "Usually, this will also be the initialization date of the simulation but this isn't always ".
                     "the case (see below).\n\n".

                     "The Default Behavior When NOT Passing \"--date\":\n\n".

                     "Not passing the \"--date\" flag will cause ems_autorun to use the date (YYYYMMDD) of the most recent model ".
                     "run for which data are available, which is normally the current system date. So if today is 30 February ".
                     "2021, ems_autorun will use a value of 20210230 unless the \"--date\" flag is passed with a better date. ".
                     "There is an exception to this rule in that when the most recent date for which data are available is from ".
                     "the previous day, then ems_autorun will adjust accordingly.  Just remember: \"The UEMS thinks, so you don't ".
                     "have to.\", which is poor grammar but gets the point across.\n\n\n".


                     "Behavior When \"--date\" is Passed:\n\n".

                     "Passing the \"--date\" flag overrides the default behavior described above and tells ems_autorun that you ".
                     "want to use a dataset from YYYYMMDD to initialize your simulation. Again, while this typically will be ".
                     "the same date as your model initialization, it doesn't have to be the case. For example, if you passed\n\n".

                     "  % ems_autorun --dset gfs  --date 19751109  --cycle 12:24\n\n".

                     "you are instructing ems_autorun to use the 24-hour forecast from the 9 November 1975 12 UTC cycle (12:24; ".
                     "see --cycle) of the GFS (if it existed) to initialize your simulation. Consequently, your initialization ".
                     "00-hour date will be 10 November 1975 for all you maritime disaster aficionados.\n\n";



            
       $help{ADDN} = "The \”--date\” flag works in harmony with \"--cycle\""; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub AutoHelp_domains {
#==================================================================================
#  Routine provides guidance for using the --domains flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--domains';

       $help{WHAT} = 'Controls the domains to be included in the simulation';

       $help{USE}  = "%  ems_autorun --domains  Domain1[:START HOUR[:LENGTH]],...,DomainN[:START HOUR[:LENGTH]]\n\n".
                     "Where N <= Max Domains";


       $help{DESC} = "Passing the \"--domains\" flag specifies a list of (nested) domain(s) to initialize for inclusion in ".
                     "a simulation. Any domain(s) must have been defined and localized previously when running the Domain ".
                     "Wizard or ems_domains utility. If you created any sub-domains (multiple nests), then passing \"--domains\" ".
                     "will activate them. You will not be able to run a nested simulation unless you activate the sub-domain!\n\n".

                     "Important: Domain 1 (primary domain) is the Mother, or Parent, of all domains and is always included by default.\n\n".

                     "If you plan to start integration on all domains at the same time as the primary domain (Domain 1), then you only ".
                     "need to include the last domain as an argument to \"--domains\". For example, if you created three nested domains ".
                     "(four total domains) and wish to activate all three, then both:\n\n".

                     "  %  ems_autorun --dset gfs  --domains 2,3,4 (NO spaces between domains)\n".
                     "And\n".
                     "  %  ems_autorun --dset gfs  --domains 4\n\n".

                     "result in Domains 1 through 4 being activated.\n\n\n".

                     "\"But what if I want to start integration of my sub-domains at different times?\"\n\n".

                     "You can control the start time of individual domains by including a \":START HOUR\" in the list, where START HOUR ".
                     "is the number of hours after the start of the simulation (Domain 1). To demonstrate the power of \"--domains\", ".
                     "let's assume that you have created 10 domains (1 Primary and 9 sub-domain) with the following configuration:\n\n".

                     "                  DOMAIN 1\n".
                     "-------------------------------------------------\n".
                     "       Domain 2    Domain 3    Domain 6\n\n".

                     "       Domain 4    Domain 9    Domain 7\n\n".

                     "       Domain 5    Domain 10   Domain 8\n\n\n".


                     "In the above example, Domain 1 is the parent of Domains 2, 3, and 6. Domain 2 is the parent of Domain 4, ".
                     "Domain 6 is the parent of 7, Domain 9 the parent of 10, and 7 is the parent of 8, etc.\n\n".

                     "Some domains will be included in the initialization whether you want them or not, regardless of any relationship ".
                     "within the family tree of domains. This is because, as described earlier, explicitly requesting the initialization ".
                     "of any sub-domains will automatically cause ems_autorun to include all the domains from 1 to N, where N is the domain ".
                     "specified. So, if you were to pass \"--domains 9\" to ems_autorun, then Domains (1), 2,3,4,5,6,7, and 8 will also be ".
                     "included in the initialization. The start time for the implicitly included domains will be the same as that of their ".
                     "parent. That's just the way things work here. I don't make the rules, I just enforce them.\n\n\n".


                     "Including a START HOUR\n\n".

                     "Let's say that the length of the simulation (Domain 1) is 24 hours. However, you want to start Domains 2 and 6, 9 and ".
                     "12 hours respectively AFTER the start of Domain 1. If this is the way you like to rock then you will need to include the ".
                     "START HOUR in your argument list:\n\n".

                     "  %  ems_autorun --dset gfs --domains 2:9,6:12\n\n".

                     "The above example will initialize Domain 2 to start nine hours after Domain 1 (2:9). Domain 6 will begin 12 hours after ".
                     "Domain 1.  It should be noted that the start hour for a sub-domain must coincide with a boundary condition update time. ".
                     "If you are using 6-hourly GFS files for your boundary conditions, then you can not start Domain 2, nine hours after the ".
                     "simulation start time, unless you include the \"--hiresbc\" flag. The \"--hiresbc\" flag will linearly interpolate the ".
                     "temporally lower resolution BC dataset to hourly update times, thus allowing you to do lots of crazy stuff your mother ".
                     "warned you about like play with models.  I think this is what she meant.\n\n\n".

                     "Here is a more complicated example:\n\n".

                     "  %  ems_autorun --dset gfs --domains 2:3,3:12,5:15,7:6,8:24,9:6\n\n".

                     "There is a lot of stuff going on here.  First, note that Domain 10 is not implicitly or explicitly included in the list, ".
                     "so it will not be included in the initialization. Additionally,\n\n".

                     "  * Domain 2  is (explicitly) initialized to start three hours after Domain 1\n".
                     "  * Domain 4  is (implicitly) initialized to start three hours after Domain 1\n".
                     "  * Domain 5  is (explicitly) initialized to start 15 hours after Domain 1\n".

                     "  * Domain 3  is (explicitly) initialized to start 12 hours after Domain 1\n".
                     "  * Domain 9  is (explicitly) initialized to start six hours after Domain 1\n\n".

                     "    However, since Domain 9 is the child of Domain 3, this start hour is BEFORE\n".
                     "    the parent domain, so it will be overridden and Domain 9 will start 12 hours\n".
                     "    after Domain 1.\n\n".

                     "  * Domain 10 is (explicitly) turned OFF\n".

                     "  * Domain 6  is (implicitly) initialized to start at the same time as Domain 1\n".
                     "  * Domain 7  is (explicitly) initialized to start 6 hours after Domain 1\n".
                     "  * Domain 8  is (explicitly) initialized to start 24 hours after Domain 1\n\n".

                     "    However, since the total length of the simulation is 24 hours, Domain 8 \n".
                     "    will automatically be turned off!\n\n".

                     "See the <domain>/static/projection.jpg for available domains.\n\n".

                     "Just a reminder that if you turn a nested domain ON, then you also should include the parent domain (except for domain 1). ".
                     "Thus, if domain 3 is a child of domain 2, and you want to include 3, you should also include 2.\n\n\n".


                     "Including a simulation LENGTH\n\n".

                     "If you recall from the beginning of this rather lengthy description of the \"--domains\" flag, the option exists to specify ".
                     "the length of a sub-domain simulation in hours (LENGTH). The simulation period defined by LENGTH begins at the start of ".
                     "child domain integration and will continue for LENGTH hours. If the length extends beyond that of the parent, the child ".
                     "domain will be terminated with the end of the parent simulation.\n\n".


                     "Some more examples, because I know you want them:\n\n".

                     "  %  ems_autorun --domains  2:3:12\n\n".

                     "Translation:  Start domain 2 simulation three hours after the start of domain 1 and run for 12 hours. Here's another:\n\n".

                     "  %  ems_autorun  --domains  2:3:12,3:6:12\n\n".

                     "Translation:  Start domain 2 simulation three hours after the start of domain 1 and run for 12 hours. Start domain 3, six ".
                     "hours after domain 1 and run for 12 hours (!!). However, Since the forecast length of domain 3 would extend beyond that of its ".
                     "parent (domain 2), the run length will be reduced to nine hours by the UEMS.";

       $help{ADDN} = "Do unlike the UEMS Overlord, keep it simple with \"--domains\""; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub AutoHelp_dslist {
#==================================================================================
#  Routine provides guidance for using the --dslist flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--dslist';

       $help{WHAT} = 'Provide a summary of available initialization datasets';

       $help{USE}  = '% ems_autorun --dslist';

       $help{DESC} = "Passing the \"--dslist\" flag provides a brief summary of the datasets supported by ".
                     "the UEMS for initializing a simulation. Further information about a specific dataset ".
                     "can be obtained by passing the \"--dsquery\" flag along with the corresponding moniker.";

       $help{ADDN} = "The \”--dslist\” flag also gives you whiter teeth, but you probably don't need it."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub AutoHelp_dsquery {
#==================================================================================
#  Routine provides guidance for using the --dsquery & --dsquery flags
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--dsquery|dsinfo DSET';

       $help{WHAT} = 'Query the default configuration settings for the specified dataset.';

       $help{USE}  = '% ems_autorun --dsquery DSET';


       $help{DESC} = "The \"--dsquery\" flag allows you to interrogate the contents of a requested DSET_gribinfo.conf file, which ".
                     "provides the default configuration settings, such as a description of the dataset, sources for the files, ".
                     "local file naming convention, and other valuable information.\n\n".

                     "The argument to \"--dsquery\" is the moniker used to identify a specific dataset, a list of which is provided ".
                     "by the \"--dslist\" flag. Lots of good information.\n\n".

                     "Here is an example of the information for the gfsp25 dataset:\n\n".

                     "  % ems_autorun --dsquery gfsp25\n\n".

                     "  Default settings from the gfsp25 grib information file: gfsp25_gribinfo.conf\n\n".

                     "  Description : GFS 0.25 degree dataset on pressure surfaces\n\n".

                     "    Dataset Category              : Forecast\n".
                     "    Vertical Coordinate           : Pressure\n".
                     "    Default Initial Forecast Hour : 00\n".
                     "    Default Final Forecast Hour   : 24\n".
                     "    Default BC Update Frequency   : 03 Hours\n".
                     "    Available Cycles (UTC)        : 00, 06, 12, 18\n".
                     "    Remote Server Delay           : 03 Hours\n".
                     "    Local Filename                : YYMMDDCC.gfs.tCCz.0p25.pgrb2fFFF\n".
                     "    Vtable Grid Information File  : /uems/data/tables/vtables/Vtable.GFS\n".
                     "    LVtable Grid Information File : None\n".
                     "    Maximum BC Update Frequency   : 03 Hours\n\n".

                     "    METHOD  SOURCE                    LOCATION\n".
                     "  --------------------------------------------------------------------------------\n\n".

                     "    http    nomads.ncep.noaa.gov      /data/YYYYMMDDCC/gfs.tCCz.pgrb2.0p25.fFFF\n".
                     "    http    www.nomads.ncep.noaa.gov  /data/YYYYMMDDCC/gfs.tCCz.pgrb2.0p25.fFFF";

            
       $help{ADDN} = "The format of the information provided above is subject to change at the whim of the developer."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub AutoHelp_notused {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    my $flag = shift;
    
       $help{FLAG} = "--$flag";

       $help{WHAT} = 'Flag from the land of misfit options & stuff';

       $help{USE}  = "% ems_autorun  --$flag [don't even bother]";

       $help{DESC} = "Some flag are listed in the options module because they serve an internal purpose, such as ".
                     "being passed within ems_autorun or to maintain compatibility for legacy reasons. There ".
                     "isn't much to gain by attempting to pass one of these flags and more than likely you'll poke ".
                     "your own eye out.\n\n".

                     "So just don't do it.";
            
       $help{ADDN} = 'This message should have self-destructed 13.799 Billion years and 36 days ago.'; 


return &Ehelp::FormatHelpTopic(\%help);
}


