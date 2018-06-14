#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Phelp.pm
#
#  DESCRIPTION:  Phelp contains subroutines used to provide love & guidance
#                to the user running ems_prep, including the help menu and
#                information on each option.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Phelp;

use warnings;
use strict;
require 5.008;
use English;

use Ehelp;


sub PrepHelpMe {
#==================================================================================
#  The PrepHelpMe routine determines what to do when the --help flag is
#  passed with or without an argument. If arguments are passed then the 
#  PrintPrepOptionHelp subroutine is called and never returns.
#==================================================================================
#
    my @args  = &Others::rmdups(@_);

    &PrintPrepOptionHelp(@args) if @args;

    &Ecomm::PrintTerminal(0,7,255,1,1,&ListPrepOptions);

&Ecore::SysExit(-4); 
}


sub PrepHelpMeError {
#==================================================================================
#  The &PrepHelpMeError routine determines what to do when the --help flag is
#  passed with or without an argument.
#==================================================================================
#
    my @args  = @_;

    &Ecomm::PrintTerminal(6,7,255,1,1,"It appears you have caused an error (@args)",&ListPrepOptions);

&Ecore::SysExit(-4); 
}



sub ListPrepOptions  {
#==================================================================================
#  This routine provides the basic structure for the ems_prep help menu 
#  should  the "--help" option is passed or something goes terribly wrong.
#==================================================================================
#

    my @opts1 = qw (dset lsm sfc domains cycle date length);            $_ = "--$_" foreach @opts1;
    my @opts2 = qw (analysis previous syncsfc attempts sleep);          $_ = "--$_" foreach @opts2;
    my @opts3 = qw (bndyrows hiresbc noaerosols noaltsst);              $_ = "--$_" foreach @opts3;
    my @opts4 = qw (ncpus nodelay nointdel noproc nudge scour timeout); $_ = "--$_" foreach @opts4;
    my @opts5 = qw (dslist dsinfo dsquery query benchmark help debug);  $_ = "--$_" foreach @opts5;

    my $mesg  = qw{};
    my @helps = ();

    my $exe = 'ems_prep'; my $uce = uc $exe;

    my %opts = &DefinePrepOptions();  #  Get options list

    push @helps => &Ecomm::TextFormat(0,0,114,0,1,"RUDIMENTARY GUIDANCE FOR $uce (Because you need it)");

    $mesg = "The primary purpose of the ems_prep routine is to identify, acquire, and process the datasets ".
            "for use as initial and boundary condition information in the UEMS. The ems_prep routine is ".
            "the most complex of the run-time scripts as it must sort though a myriad of user options to ".
            "determine which data to download, where to obtain the files, how to process the data, and then ".
            "complete the horizontal interpolation to the user's computational domain. The final output files ".
            "from ems_prep are in netCDF format and serve as input when running the ems_run routine.";


    push @helps => &Ecomm::TextFormat(2,2,98,1,1,$mesg);

    push @helps => &Ecomm::TextFormat(0,0,114,2,1,"$uce USAGE:");
    push @helps => &Ecomm::TextFormat(4,0,114,1,1,"% $exe --dset <dataset>  [additional flags & fun]");

    push @helps => &Ecomm::TextFormat(0,0,124,2,1,"AVAILABLE OPTIONS - BECAUSE I LIKE THE LOOK OF DETERMINATION ON YOUR FACE - IT WORKS FOR YOU!");

    push @helps => &Ecomm::TextFormat(6,0,114,1,1,"Flag            Argument [optional]       Description");

    push @helps => &Ecomm::TextFormat(4,0,114,1,2,"The main $exe flags & options:");
    foreach my $opt (@opts1) {push @helps => &Ecomm::TextFormat(6,0,256,0,1,sprintf("%-17s  %-18s  %-60s",$opt,$opts{$opt}{arg},$opts{$opt}{desc}));}

    push @helps => &Ecomm::TextFormat(4,0,114,1,2,"Some other acquisition related flags:");
    foreach my $opt (@opts2) {push @helps => &Ecomm::TextFormat(6,0,256,0,1,sprintf("%-17s  %-18s  %-60s",$opt,$opts{$opt}{arg},$opts{$opt}{desc}));}

    push @helps => &Ecomm::TextFormat(4,0,114,1,2,"Miscellaneous flags looking for a home:");
    foreach my $opt (@opts3) {push @helps => &Ecomm::TextFormat(6,0,256,0,1,sprintf("%-17s  %-18s  %-60s",$opt,$opts{$opt}{arg},$opts{$opt}{desc}));}

    push @helps => &Ecomm::TextFormat(0,0,1,0,1,' ');
    foreach my $opt (@opts4) {push @helps => &Ecomm::TextFormat(6,0,256,0,1,sprintf("%-17s  %-18s  %-60s",$opt,$opts{$opt}{arg},$opts{$opt}{desc}));}

    push @helps => &Ecomm::TextFormat(4,0,114,1,2,'Because help usually arrives when you need it most:');
    foreach my $opt (@opts5) {push @helps => &Ecomm::TextFormat(6,0,256,0,1,sprintf("%-17s  %-18s  %-60s",$opt,$opts{$opt}{arg},$opts{$opt}{desc}));}


    push @helps => &Ecomm::TextFormat(0,0,114,2,2,"FOR ADDITIONAL HELP, LOVE AND UNDERSTANDING:");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"a. Read  - docs/uems/uemsguide/uemsguide_chapter07.pdf");
    push @helps => &Ecomm::TextFormat(2,0,114,0,1,"Or");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"b. http://strc.comet.ucar.edu/software/uems");
    push @helps => &Ecomm::TextFormat(2,0,114,0,1,"Or");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"c. % $exe --help <topic>  For a more detailed explanation of each option (--<topic>)");
    push @helps => &Ecomm::TextFormat(2,0,114,0,1,"Or");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"d. % $exe --help  For this menu again");

    my $help = join '' => @helps;


return $help;
}


sub DefinePrepOptions {
#==================================================================================
#  This routine defined the list of options that can be passed to the program
#  and returns them as a hash.
#==================================================================================
#
    my %opts = (
                '--scour'       => { arg => ''           , help => '&PrepHelp_scour'     , desc => 'Scour the grib/ directory prior to running ems_prep'},
                '--bndyrows'    => { arg => '[ROWS]'     , help => '&PrepHelp_bndyrows'  , desc => 'Process only [ROWS] outer rows used for the lateral boundaries. Default is 5 rows'},
                '--benchmark'   => { arg => ''           , help => '&PrepHelp_benchmark' , desc => 'Process initialization files for use in the benchmark case. Really not necessary since the UEMS knows everything.'},
                '--timeout'     => { arg => 'SECS'       , help => '&PrepHelp_timeout'   , desc => 'Override the default timeout value of 299s when running metgrid. Use  \'--timeout 0\' to turn OFF'},
                '--nodelay'     => { arg => ''           , help => '&PrepHelp_nodelay'   , desc => 'Override the default gribinfo file DELAY setting'},
                '--nudge'       => { arg => ''           , help => '&PrepHelp_nudge'     , desc => 'Process the domains for 3D Analysis/Spectral nudging'},
                '--ncpus'       => { arg => '#CPUS'      , help => '&PrepHelp_ncpus'     , desc => 'The number of processors to use when running metgrid (horizontal interpolation)'},
                '--previous'    => { arg => ''           , help => '&PrepHelp_previous'  , desc => 'Use the previous cycle of the dataset rather than the current one to initialize model run'},
                '--nointdel'    => { arg => ''           , help => '&PrepHelp_nointdel'  , desc => 'Do not delete the intermediate files after processing (Default: Delete)'},
                '--noproc'      => { arg => ''           , help => '&PrepHelp_noproc'    , desc => 'Do not processes the grib files for model initialization after acquiring them'},
                '--local'       => { arg => ''           , help => '&PrepHelp_local'     , desc => 'Only check for initialization files in local directory'},
                '--hiresbc'     => { arg => ''           , help => '&PrepHelp_hiresbc'   , desc => 'Interpolate between available file times to create hourly BC files'},
                '--help'        => { arg => '[TOPIC]'    , help => '&PrepHelp_help'      , desc => 'Either print this list again or pass me a topic and I\'ll explain it to you'},
                '--noaerosols'  => { arg => ''           , help => '&PrepHelp_aerosols'  , desc => 'Do not include the monthly aerosol climatology in the initialization dataset'},
                '--noaltsst'    => { arg => ''           , help => '&PrepHelp_noaltsst'  , desc => 'Do not use the alternate method (mean surface temperature) for water temperatures in the absence of data'},
                '--length'      => { arg => 'HOURS'      , help => '&PrepHelp_length'    , desc => 'The length of the simulation in hours (Mandatory with multiple dataset initialization)'},
                '--analysis'    => { arg => '[FCST HOUR]', help => '&PrepHelp_analysis'  , desc => 'The initialization dataset is a series of analyses or a specific cycle forecast hour'},
                '--dset'        => { arg => 'DSET[:...]' , help => '&PrepHelp_dset'      , desc => 'The dataset (and more) to use for initial and boundary conditions'},
                '--sfc'         => { arg => 'LIST'       , help => '&PrepHelp_dset'      , desc => 'List of time-invariant surface datasets used for initialization. Mostly follows --dset rules'},
                '--lsm'         => { arg => 'LIST'       , help => '&PrepHelp_dset'      , desc => 'List of time-variant* datasets used for initialization. Follows --dset rules. *See ems_prep --help lsm for details'},
                '--domains'     => { arg => 'DOM:HOUR'   , help => '&PrepHelp_domains'   , desc => 'List of domain numbers and start hour to include in the simulation, separated by a comma (2,3,4, etc)'},
                '--date'        => { arg => 'YYYYMMDD'   , help => '&PrepHelp_date'      , desc => 'The date of the files used for initialization of the simulation'},
                '--cycle'       => { arg => 'HOUR'       , help => '&PrepHelp_cycle'     , desc => 'Set the cycle time of the of the primary dataset used for initialization.'},
                '--syncsfc'     => { arg => '[LIST]'     , help => '&PrepHelp_syncsfc'   , desc => 'List of surface datasets (--sfc) to match with the closest simulation 00-hour'},
                '--sleep'       => { arg => 'SECS'       , help => '&PrepHelp_sleep'     , desc => 'The number of seconds between attempts to acquire initialization data'},
                '--attempts'    => { arg => '#ATTEMPTS'  , help => '&PrepHelp_attempts'  , desc => 'The number of attempts to acquire initialization data'}, 
                '--dsinfo'      => { arg => 'DSET'       , help => '&PrepHelp_dsquery'   , desc => 'List information contained within the DSET_gribinfo.conf file'},
                '--dsquery'     => { arg => 'DSET'       , help => '&PrepHelp_dsquery'   , desc => 'List information contained within the DSET_gribinfo.conf file (Same as --dsinfo)'},
                '--query'       => { arg => 'DSET'       , help => '&PrepHelp_dsquery'   , desc => 'List information contained within the DSET_gribinfo.conf file (Same as --dsinfo)'},
                '--dslist'      => { arg => ''           , help => '&PrepHelp_dslist'    , desc => 'List the datasets supported for initialization'},
                '--debug'       => { arg => '[ARG]'      , help => '&PrepHelp_debug'     , desc => 'Print out some less-than-informative messages debugging purposes (ungrib|metgrid)'}
                );
return %opts;
}  #  DefinePrepOptions


sub PrintPrepOptionHelp {
#==================================================================================
#  The PrintPrepOptionHelp takes a string that is matched to a help topic. 
#  There is no returning from this subroutine - ever.
#
#  This routine is a bit sloppy and should be cleaned up - You do it.
#==================================================================================
#
    my ($package, $filename, $line, $subr, $has_args, $wantarray)= caller(1);

    my $exit = ($subr =~ /CheckPrepOptions/) ? -5 : -4;

    my %opts = &DefinePrepOptions();  #  Get options list

    my $dash   = '-' x 108;
    my @topics = &Others::rmdups(@_);

    foreach my $topic (@topics) {

        my $flag = &Poptions::MatchPrepOptions("--$topic");

        my @flags = keys %{$opts{$flag}};

        if ($flag and defined $opts{$flag}{help}) {

            my $help = eval $opts{$flag}{help}; 
               $help = "Hey - Add some magic words for the $flag flag!" unless $help;
  
            my $head = ($subr =~ /CheckPrepOptions/) ? "It appears you need some assistance with the $flag flag:" 
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


sub PrepHelp_analysis {
#==================================================================================
#  Routine provides guidance for using the --Analysis flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--analysis [forecast hour]';

       $help{WHAT} = 'Tells ems_prep to use a series of analyses rather than forecasts for initialization';

       $help{USE}  = '% ems_prep --analysis  [more important stuff]';

       $help{DESC} = "Passing the \"--analysis\" flag results in your simulation being initialized from a ".
                     "series of analyses rather than a single forecast. The default behavior of ems_prep ".
                     "is to look for a sequence of forecast files from a single model run to serve as the ".
                     "boundary condition update times. For example, when passing:\n\n".

                     "  %  ems_prep --dset gfs --date 20170230 --cycle 12 --length 24 \n\n".

                     "the ems_prep routine will look for 24 hours of forecast files from the 12 UTC cycle ".
                     "run of the operational GFS from 30 February 2017 to initialize your simulation.\n\n".

                     "However, by passing the --analysis flag, you can initialize your simulation from a ".
                     "succession of cycle runs, in which case the 00-hour (default) forecast files from ".
                     "each of the GFS cycles runs beginning with 30 February 2017 through 31 February 2017 ".
                     "will be used.\n\n".

                     "This option is primarily intended for use with historical or reanalysis datasets ".
                     "where a series of forecasts is not available. This would apply to datasets such as ".
                     "the North American Regional Renalysis (NARR), Climate Forecast System Renalysis (CFSR) ".
                     "or the ECMWF ERA Interim analysis dataset. While this option can be used with ".
                     "operational model guidance such as the GFS, it is not recommended since the BC update ".
                     "frequency is likely to be much lower than that you would get from the available forecast ".
                     "files\n\n".

                     "But wait, there's more! What if you're feeling all wild & crazy and want to initialize ".
                     "your simulation from a series of non zero-hour forecasts?  Well then you can simply pass ".
                     "an argument to the --analysis flag like:\n\n".

                     "  %  ems_prep --analysis 24 [Other stuff]\n\n".

                     "which will initialize your simulation from a series of 24-hour forecasts. Mind blowing, eh?\n\n".
                     "However, if you are seriously considering such actions, you may want to first get a ".
                     "nights rest as chances are that you are suffering from some serious sleep deprivation. This ".
                     "option will still be there in the morning.\n\nSweet dreams.";
            
       $help{ADDN} = "\"% ems_prep --analysis\” is more powerful than you"; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_attempts {
#==================================================================================
#  Routine provides guidance for using the --attempts flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--attempts';

       $help{WHAT} = 'The number of attempts to acquire initialization data - For real-time use only';

       $help{USE}  = '% ems_prep --attempts <number of attempts> [other stuff]';

       $help{DESC} = "The \"--attempts\" flag specifies the number of attempts to make in acquiring the initialization data ".
                     "data before giving up. It is intended to be passed by ems_autorun during real-time forecasting ".
                     "applications. Defaults value is 3 (attempts).";
            
       $help{ADDN} = "The \”--attempts\” works in harmony with the \"--asleep\" flag, and so should you."; 


return &Ehelp::FormatHelpTopic(\%help);
}



sub PrepHelp_aerosols {
#==================================================================================
#  Routine provides guidance for using the --noaerosols flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--noaerosols';

       $help{WHAT} = 'Do not include the monthly aerosol climatology in the initialization dataset';

       $help{USE}  = '% ems_prep --noaerosols [way more important stuff]';

       $help{DESC} = "Pass the \"--noaerosols\" flag if you do not want to include the Thompson Water/Ice Friendly ".
                     "Aerosols in the initialization dataset. These \"WIF\" data are used with the Thompson \"Aerosol ".
                     "Aware\" microphysics scheme (MP_PHYSICS = 28) during the simulation. By default, the UEMS ".
                     "includes these data regardless of your future choice of microphysics, so that when you are ".
                     "ready, you can go \"Aerosol Aware\" without going back to ems_prep.\n\n".

                     "The downside of this approach is that the initialization files in wpsprd/ are much larger ".
                     "with the inclusion of these data. So if this fact bothers you to the point of giving you a ".
                     "frowny face, then the \"--noaerosols\" flag is here for you.\n\n".
                     "Just because the UEMS HATES frowny faces!";


       $help{ADDN} = "Since you asked, here is a summary of the aerosol climatology data from the WRF website:\n\n".

                     "\"Aerosol number concentrations were derived from multi-year (2001-2007) global model\n".
                     "simulations (Colarco, 2010) in which particles and their precursors are emitted by\n".
                     "natural and anthropogenic sources and are explicitly modeled with multiple size bins\n".
                     "for multiple species of aerosols by the Goddard Chemistry Aerosol Radiation and\n".
                     "Transport (GOCART) model (Ginoux et al. 2001). The aerosol input data we used included\n".
                     "mass mixing ratios of sulfates, sea salts, organic carbon, dust, and black carbon\n".  
                     "from the 7-year simulation with 0.5-degree longitude by 1.25-degree latitude spacing.\n".
                     "We transformed these data into our simplified aerosol treatment by accumulating dust mass\n".  
                     "larger than 0.5 microns into the ice nucleating, non-hygroscopic mineral; dust mode, NIFA,\n".
                     "and combining all other species besides black carbon as an internally-mixed cloud droplet\n".
                     "nucleating, hygroscopic CCN mode, NWFA. Input mass mixing ratio data; were converted\n".
                     "to final number concentrations by assuming log-normal distributions with characteristic\n".
                     "diameters and geometric standard deviations taken from Chin et al.; (2002; Table 2).\"";


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_benchmark {
#==================================================================================
#  Routine provides guidance for using the --benchmark flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--benchmark';

       $help{WHAT} = 'Tell ems_prep to processes initialization data for the benchmark case';

       $help{USE}  = '% ems_prep --benchmark';

       $help{DESC} = "Passing the \"--benchmark\" flag tells ems_prep to process the initialization data for the 27 April 2011 ".
                     "benchmark simulation provided with the UEMS. This flag is only valid when running the benchmark ".
                     "case, which is located under uems/util/benchmark/27april2011; otherwise, it will likely have no ".
                     "effect although some cases of infatuation with the UEMS developer have been reported.";

       $help{ADDN} = "You are encouraged to read the uems/util/benchmark/benchmark.README file for more information.\n";


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_bndyrows {
#==================================================================================
#  Routine provides guidance for using the --bndyrows flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--bndyrows #ROWS';

       $help{WHAT} = 'Specify the number of outer rows to use as lateral boundary conditions';

       $help{USE}  = '% ems_prep --bndyrows 8';

       $help{DESC} = "If your looking for a flag lacking in sex appeal, then you've come to the right ".
                     "place. Passing the \"--bndyrows\" option overrides the default number of rows to ".
                     "process for use as lateral boundary conditions.  The default value is 5, which ".
                     "should be good enough for you, but if you insist upon changing it then knock ".
                     "yourself out and pass \"--bndyrows.\"\n\n";
                      
            
       $help{ADDN} = "The maximum value for #ROWS is 10. Don't make me play the enforcer!"; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_cycle {
#==================================================================================
#  Routine provides guidance for using the --cycle flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--cycle HOUR[:INITFH[:FINLFH[:FREQFH]]]';

       $help{WHAT} = 'Defines the cycle times (UTC) of the forecast or analysis system from which the data files are available. '.
                     'For a operational forecast model, this is often the00-hour time of that run. For an analysis system, the '.
                     'cycle time typically identifies the hour at which the dataset is valid. NOTE: not for use with real-time '.
                     'forecast applications!  No, just don\'t do it.';

       $help{USE}  = '% ems_prep --cycle HOUR[:INITFH[:FINLFH[:FREQFH]]] [other stuff]';


       $help{DESC} = "First - The Default Behavior When NOT Passing \"--cycle\":\n\n".

                     "Not passing the \"--cycle\" flag will cause ems_prep to use the UTC cycle time of the most recent model ".
                     "run from which data are available. The list of available cycles is already defined by the CYCLES ".
                     "parameter in each of the <dset>_gribinfo.conf files. To determine the most current available cycle time, ".
                     "ems_prep accounts for the amount of time required for an operational model to run and process any data ".
                     "files for distribution. This delay between the official UTC cycle time and when the data files first become ".
                     "available is defined in the DELAY parameter in the <dset>_gribinfo.conf file.\n\n". 
  
                     "For example, if the 12 UTC GFS takes three hours to run and process forecast GRIB files for distribution ".
                     "(DELAY = 3), ems_prep will not attempt to obtain the data until after 15Z. If ems_prep is run, say at ".
                     "at 14:55 UTC (again, without \"--cycle\"), data from the 06 UTC cycle will be acquired because that is the ".
                     "most current run from which data are available.\n\n\n".

                     "Now the Behavior When \"--cycle\" is Passed:\n\n".

                     "The --cycle flag specifies the cycle time of the model dataset to use for initialization of your ".
                     "simulation. The general usage is:\n\n".

                     "  %  ems_prep --dset gfs --cycle CYCLE\n\n".

                     "When you specify the cycle time of the dataset to be acquired, ems_prep will attempt to access the most ".
                     "recent dataset available corresponding to that cycle time (assuming \"--date\" was not passed). So using the ".
                     "GFS example above, passing \"--cycle 12\" at 14:55 UTC will cause ems_prep to acquire data from the ".
                     "previous 12 UTC run as opposed to the 06 UTC cycle if \"--cycle 12\" had not been passed (default).\n\n\n".

                     "But wait, there's more whether you want it or not.\n\n".

                     "The --cycle flag accepts additional arguments that override the initial forecast hour, final forecast hour, and ".
                     "frequency of the boundary condition files, the default values of which are defined in each <dataset>_gribinfo.conf ".
                     "file as INITFH, FINLFH, and FREQFH respectively. The format for the argument list is:\n\n".

                     "  %  ems_prep --dset gfs --cycle HOUR[:INITFH[:FINLFH[:FREQFH]]]\n\n".
               
                     "Where the brackets indicate that everything is optional. These optional arguments are passed as a string, with ".
                     "each separated by a colon (:). Trailing colons need not be included.\n\n\n".

                     "Here are a few examples. Feel free to make some of your own.\n\n".

                     "  %  ems_prep --dset gfs --cycle 00:00:24:03\n\n".

                     "Translation: Use the 00 UTC cycle time, the 00 hour forecast for the initialization time, the 24 hour forecast for ".
                     "the final BC time (thus a 24 hour forecast), and use 3-hourly files for boundary conditions. In this example, ems_prep ".
                     "will attempt to download the 00, 03,06,09,12,15,18,21, and 24 hour forecast files from the most recent 00 UTC cycle of ".
                     "the GFS. All default values for these parameters are overridden, or in UEMS Central Headquarter's parlance, \"Crushed.\"\n\n\n".


                     "More examples - Just because we're having so much fun together:\n\n".

                     "  %  ems_prep --dset gfs  --cycle 06:06:30\n\n".

                     "Translation: Use the 06 UTC cycle time, the 06-hour forecast for the initialization hour and the 30-hour forecast for the final ".
                     "boundary condition time (a 24 hour forecast). Because the BC update frequency (FREQFH) was not passed the default value in ".
                     "gfs_gribinfo.conf file will be used.\n\n\n".

                     "Tell me if you've heard this one before. What is the difference between the following:\n\n".

                     "    %  ems_prep --dset gfs --cycle CYCLE:INITFH:36:12\n".
                     "And\n".
                     "    %  ems_prep --dset gfs --cycle ::36:12\n\n".

                     "Answer:  NOTHING! In both cases, the data files from most current available cycle hour will be used (default) starting ".
                     "from the default initialization forecast hour found in gfs_gribinfo.conf (INITFH) through the 36 hour forecast, with a 12-hourly ".
                     "BC update frequency. So if INITFH = 0 in gfs_gribinfo.conf, then the 00, 12, 24, and 36-hour frecast files from most current ".
                     "run of the GFS will be used to initialize your simulation.  The inclusion of 'CYCLE:INITFH', or 'CYCLE:INITFH:FINLFH:FREQFH' are ".
                     "not necessary but still valid.\n\n\n".

                     "If you choose not to use the placeholders, then remember that leading colons are require but trailing ones are not:\n\n".

                     "  %  ems_prep --dset gfs --cycle :::12\n\n".
                  
                     "Use all default values except 12 hourly BC updates.\n\n".
                  
                     "  %  ems_prep --dset gfs --cycle :24:84\n\n".

                     "Use the defaults for cycle & BC update use 24 hour through 84 hour forecast files.\n\n\n".

                     "You have the power; use it wisely and often.";


       $help{ADDN} = "Again, the \"--cycle\" flag is not for use with real-time forecast applications!"; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_date {
#==================================================================================
#  Routine provides guidance for using the --date flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--date ';

       $help{WHAT} = 'Specify the date of the dataset to use for initialization.  NOTE: not for use with real-time '.
                     'forecast applications!  No, just don\'t do it.';

       $help{USE}  = '% ems_prep --date [YY]YYMMDD [other important stuff]';

       $help{DESC} = "Passing the \"--date\" flag specifies the date of the dataset used for model initialization. ".
                     "Usually, this will also be the initialization date of the simulation but this isn't always ".
                     "the case (see below).\n\n".

                     "The Default Behavior When NOT Passing \"--date\":\n\n".

                     "Not passing the \"--date\" flag will cause ems_prep to use the date (YYYYMMDD) of the most recent model ".
                     "run for which data are available, which is normally the current system date. So if today is 30 February ".
                     "2021, ems_prep will use a value of 20210230 unless the \"--date\" flag is passed with a better date. ".
                     "There is an exception to this rule in that when the most recent date for which data are available is from ".
                     "the previous day, then ems_prep will adjust accordingly.  Just remember: \"The UEMS thinks, so you don't ".
                     "have to.\", which is poor grammar but gets the point across.\n\n\n".


                     "Behavior When \"--date\" is Passed:\n\n".

                     "Passing the \"--date\" flag overrides the default behavior described above and tells ems_prep that you ".
                     "want to use a dataset from YYYYMMDD to initialize your simulation. Again, while this typically will be ".
                     "the same date as your model initialization, it doesn't have to be the case. For example, if you passed\n\n".

                     "  % ems_prep --dset gfs  --date 19751109  --cycle 12:24\n\n".

                     "you are instructing ems_prep to use the 24-hour forecast from the 9 November 1975 12 UTC cycle (12:24; ".
                     "see --cycle) of the GFS (if it existed) to initialize your simulation. Consequently, your initialization ".
                     "00-hour date will be 10 November 1975 for all you maritime disaster aficionados.\n\n";



            
       $help{ADDN} = "The \”--date\” flag works in harmony with \"--cycle\""; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_debug {
#==================================================================================
#  Routine provides guidance for using the --debug flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--debug';

       $help{WHAT} = 'Special flag for debugging problems with ems_prep';

       $help{USE}  = '% ems_prep --debug [metgrid|ungrib]';

       $help{DESC} = "The \”--debug\” is a extra top secret flag for which only the developed has clearance and authority ".
                     "to use. That said, it's primary purpose is to dump out a bunch of information about what's happening ".
                     "while running the routine. Currently, the only options are:\n\n".

                     "  %  ems_prep --debug         <- Provides some basic diagnostic information\n".
                     "Or\n".
                     "  %  ems_prep --debug ungrib  <- Dumps out ready to manually run ungrib\n".
                     "Or\n".
                     "  %  ems_prep --debug metgrid <- Dumps out ready to manually run metgrid\n\n";
            
       $help{ADDN} = "The \”--debug\” flag is always under development and may change with each new release, so it's best to ". 
                     "just stay away; otherwise, you discover what I'm wearing behind the curtain.";

return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_domains {
#==================================================================================
#  Routine provides guidance for using the --domains flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--domains ';

       $help{WHAT} = 'Provide control over domains included in the simulation.';
           

       $help{USE}  = '% ems_prep --domains Domain1[:START HOUR],...,DomainN[:START HOUR]   Where N <= Max Domains';

       $help{DESC} = "Passing the \"--domains\" flag specifies a list of (nested) domain(s) to initialize for inclusion in ".
                     "a simulation. Any domain(s) must have been defined and localized previously when running the Domain ".
                     "Wizard or ems_domains utility. If you created any sub-domains (multiple nests), then passing \"--domains\" ".
                     "will activate them. You will not be able to run a nested simulation unless you activate the sub-domains!\n\n".

                     "Important: Domain 1 (primary domain) is the Mother, or Parent, of all domains and is always included by default.\n\n".

                     "If you plan to start integration on all domains at the same time as the primary domain (Domain 1), then you only ".
                     "need to include the last domain as an argument to \"--domains\". For example, if you created three nested domains ".
                     "(four total domains) and wish to activate all three, then both:\n\n".
 
                     "  %  ems_prep --dset gfs  --domains 2,3,4 (NO spaces between domains)\n".
                     "And\n".
                     "  %  ems_prep --dset gfs  --domains 4\n\n".

                     "result in Domains 1 through 4 being activated.\n\n\n".

                     "\"But what if I want to start integration of my sub-domains at different times?\"\n\n".

                     "You can control the start time of individual domains by including a \":START HOUR\" in the list, where START HOUR ".
                     "is the number of hours after the start of the simulation (Domain 1). To demonstrate the power of \"--domains\", ".
                     "let's assume that you have created 10 domains (1 Primary and 9 sub-domains) with the following configuration:\n\n".

                     "                  DOMAIN 1\n".
                     "-------------------------------------------------\n".
                     "       Domain 2    Domain 3    Domain 6\n\n".
       
                     "       Domain 4    Domain 9    Domain 7\n\n".
       
                     "       Domain 5    Domain 10   Domain 8\n\n\n".


                     "In the above example, Domain 1 is the parent of Domains 2, 3, and 6. Domain 2 is the parent of Domain 4, ".
                     "Domain 6 is the parent of 7, Domain 9 the parent of 10, and 7 is the parent of 8, etc.\n\n".

                     "Some domains will be included in the initialization whether you want them or not, regardless of any relationship ".
                     "within the family tree of domains. This is because, as described earlier, explicitly requesting the initialization ".
                     "of any sub-domain will automatically cause ems_prep to include all the domains from 1 to N, where N is the domain ".
                     "specified. So, if you were to pass \"--domains 9\" to ems_prep, then Domains (1), 2,3,4,5,6,7, and 8 will also be ".
                     "included in the initialization. The start time for the implicitly included domains will be the same as that of their ".
                     "parent. That's just the way things work here. I don't make the rules, I just enforce them.\n\n\n".


                     "Including a START HOUR\n\n".

                     "Let's say that the length of the simulation (Domain 1) is 24 hours. However, you want to start Domains 2 and 6, 9 and ".
                     "12 hours respectively AFTER the start of Domain 1. If this is the way you like to rock then you will need to include the ".
                     "START HOUR in your argument list:\n\n".

                     "  %  ems_prep --dset gfs --domains 2:9,6:12\n\n".

                     "The above example will initialize Domain 2 to start nine hours after Domain 1 (2:9). Domain 6 will begin 12 hours after ".
                     "Domain 1.  It should be noted that the start hour for a sub-domain must coincide with a boundary condition update time. ".
                     "If you are using 6-hourly GFS files for your boundary conditions, then you can not start Domain 2, nine hours after the ".
                     "simulation start time, unless you include the \"--hiresbc\" flag. The \"--hiresbc\" flag will linearly interpolate the ".
                     "temporally lower resolution BC dataset to hourly update times, thus allowing you to do lots of crazy stuff your mother ".
                     "warned you about like play with models.  I think this is what she meant.\n\n\n".

                     "Here is a more complicated example:\n\n".

                     "  %  ems_prep --dset gfs --domains 2:3,3:12,5:15,7:6,8:24,9:6\n\n".

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
                     "    will automatically be turned off!";


       $help{ADDN} = "That's all I have to say about \”--domains\.”"; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_dset {
#==================================================================================
#  Routine provides guidance for using the --dset flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--dset, --sfc, and --lsm ';

       $help{WHAT} = 'Manage the datasets included in the model initialization';

       $help{USE}  = "  % ems_prep --dset <dataset>[:METHOD:SOURCE:LOCATION]%[dataset[:METHOD:SOURCE:LOCATION]]\n".
                     "Or\n".
                     "  % ems_prep --sfc  <dataset>[:METHOD:SOURCE:LOCATION],[dataset[:METHOD:SOURCE:LOCATION]],...\n".
                     "Or\n".
                     "  % ems_prep --lsm  <dataset>[:METHOD:SOURCE:LOCATION],[dataset[:METHOD:SOURCE:LOCATION]],...\n";


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
                     "located in the uems/conf/ems_prep/prep_hostkeys.conf file. The NFS entry without a server ID ".
                     "specifies the location of the gfs files on the local file system.\n\n".

                     "Let us begin with the simplest usage of \"--dset\":\n\n".

                     "  %  ems_prep --dset <dataset>\n\n".

                     "Or how it's done on the street:\n\n".

                     "  %  ems_prep --dset gfs\n\n".


                     "If you were to run the \"ems_prep --dset gfs\" command in the example above, ems_prep would use ".
                     "the information located in the SERVERS section of gfs_gribinfo.conf file to acquire the initialization ".
                     "files. The order (HTTP, FTP, and NFS) and sources (server IDs) of the data are semi-randomized ".
                     "so as not to access the sources in the same order every time. If ems_prep is unsuccessful in acquiring ".
                     "the necessary files at the first location it will move on to the next. This process ".
                     "will continue until all data sources have been exhausted, at which time ems_prep will request that ".
                     "you re-evaluate your life goals. Yes, ems_prep will attempt every possible source identified in the ".
                     "gfs_gribinfo.conf file, because \"Working harder so you can slack off!\" would be ems_prep's motto ".
                     "if it had one, which it doesn't.\n\n".


                     "At this point you should be aware that any files acquired by ems_prep will be written to the <domain>/grib ".
                     "directory and renamed according to the naming convention defined by the LOCFIL parameter in the ".
                     "<dataset>_gribinfo.conf file. When you run the routine, ems_prep will first look in <domain>/grib and ".
                     "determine whether the requested files already exist and attempt to acquire any that are missing.\n\n".


                     "There are additional arguments that may be included with the \"--dset <dataset>\" flag that serve to modify its ".
                     "default behavior:\n\n".

                     "  %  ems_prep --dset <dataset>[:[METHOD]:[SOURCE]:[LOCATION]]\n\n".

                     "Where METHOD, SOURCE, and LOCATION specify the method of acquisition, the source of the files, and the ".
                     "directory location and naming convention used on the remote server respectively. Here is a brief summary ".
                     "of each:\n\n\n".


                     "Placeholder: METHOD\n".
                     "---------------------\n\n".

                     "The METHOD placeholder is used to control the method of data acquisition. The default behavior of ems_prep is to ".
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

                     "  %  ems_prep --dset gfs:ftp\n\n".

                     "Translation: Only use the SERVER-FTP entries in the gfs_gribinfo.conf file to acquire data. If ems_prep fails to ".
                     "locate data from NCEP and TGFTP it will not use the other methods listed and you will be devastated.\n\n".


                     "  %  ems_prep --dset gfs:noftp \n\n".

                     "Translation: Do not use the SERVER-FTP entries in the gfs_gribinfo.conf file to acquire data. The ems_prep routine ".
                     "will use the other methods listed (NFS and HTTP) to acquire the files.\n\n".


                     "  %  ems_prep --dset gfs:none \n\n".

                     "Translation: Do not attempt to acquire the files as they already are correctly named and reside in the <domain>/grib ".
                     "directory (as explained above). Note that commenting out or deleting all the SERVER entries in the gfs_gribinfo.conf ".
                     "file OR by passing may achieve the same behavior:\n\n".

                     "  %  ems_prep --dset gfs --nomethod\n\n\n".


                     "Placeholder: SOURCE\n".
                     "---------------------\n\n".

                     "The SOURCE placeholder is used to specify the source, or server, of the files being requested. It typically takes the ".
                     "form of the server ID as specified in the SERVERS section, (i.e. NCEP, TGFTP, STRC, TOC, and DATA1), and may be ".
                     "associated with multiple methods. For example:\n\n".

                     "  %  ems_prep --dset gfs:http:strc\n\n".

                     "tells ems_prep to only acquire the gfs files from the STRC server via http. The location of the files on the remote ".
                     "server and the file naming convention are obtained from the SERVER-HTTP = STRC: entry in the gfs_gribinfo.conf file.\n\n".

                     "The use of a METHOD is optional. When excluding METHOD, ems_prep will use all the methods listed that are associated with a ".
                     "given source:\n\n".

                     "  %  ems_prep --dset gfs::strc  <-- No method specified so use all listed\n\n".


                     "To acquire files locally that do not have a SOURCE associated with them in the <dataset>_gribinfo.conf file, such as in the ".
                     "last SERVER-NFS entry above, use \"local\":\n\n".

                     "  %  ems_prep --dset gfs:nfs:local\n\n\n".


                     "Placeholders: METHOD, SOURCE, and LOCATION together, just like one big, happy family\n".
                     "--------------------------------------------------------------------------------------\n\n".

                     "The SOURCE may also take the form of a hostname or IP address. This is best done in combination with METHOD and LOCATION. ".
                     "By using all three arguments, you can request that initialization files be acquired from a location not listed ".
                     "in <dataset>_gribinfo.conf. The format will look similar to a SERVER entry:\n\n".

                     "  %  ems_prep --dset gfs:http:nomad6:/pub/gfs/YYYYMMDD/gfs.tCCz.pgrbfFF\n".
                     "Or\n".
                     "  %  ems_prep --dset gfs:http:nomads6.ncdc.noaa.gov:/pub/gfs/YYYYMMDD/gfs.tCCz.pgrbfFF\n".
                     "Or\n".
                     "  %  ems_prep --dset gfs:http:205.167.25.170:/pub/gfs/YYYYMMDD/gfs.tCCz.pgrbfFF\n\n".

                     "All of the above examples are equivalent, provided that there is a NOMAD6 server ID entry in the prep_global.conf file. Any ".
                     "placeholders such as YYYYMMDD will be dutifully filled in with the appropriate values. Also, you must specify a METHOD; ".
                     "otherwise something will fail.\n\n\n".


                     "Using Multiple datasets\n".
                     "-------------------------\n\n".

                     "The \"--dset\" flag can be used to request different datasets to serve as initial and boundary conditions. For example, if you ".
                     "wish to use 12km NAM files as the initial conditions and 0.5 degree GFS for your boundary conditions, simply separate ".
                     "the two datasets with a \"%\" in the dataset argument to \"--dset\", i.e.\n\n".

                     "  %  ems_prep --dset nam218%gfs  --length 24\n\n".

                     "Wherein ems_prep will attempt to acquire a single nam218 file to use as the initial conditions (00-hour) and GFS files will ".
                     "be used for the boundary conditions through 24 hours.\n\n".

                     "IMPORTANT:  The \"--length\" flag must be used when specifying multiple datasets.\n\n".

                     "All the optional flags detailed ad nauseam above are available for use with multiple datasets as well.  For example, knock ".
                     "yourself out with such classics as:\n\n".

                     "  %  ems_prep --dset nam218:http%gfs::strc  --length 36\n\n".

                     "Translation: Only use the SERVER-HTTP entries in the nam218_gribinfo.conf file to acquire data for use as the initial conditions, ".
                     "and use all the methods listed in the gfs_gribinfo.conf file to obtain the boundary conditions files through 36 hours.\n\n\n".


                     "Using Time-invariant Surface (--sfc) and (Sometimes) Time-Invariant* Land Surface datasets (--lsm)\n".
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

                     "  %  ems_prep --dset gfs  --sfc rtgsst:ftp:nomads\n\n".

                     "The above use of the \"--sfc\" flag would replace the sst fields in the GFS dataset with the 1/12th degree sst field from the ".
                     "polar ftp server.\n\n".

                     "* The determination whether an LSM field is time-variant or invariant is provided by the TIMEVAR parameter in some ".
                     "<dset>_gribinfo.conf files\n\n".


                     "Fail-over Option with Land Surface datasets (--lsm)\n".
                     "---------------------------------------------------\n\n".

                     "For including surrogate LSM-based fields such as skin temperature, soil moisture and temperature, the \"--lsm\" flag can be used. ".
                     "A major difference between the \"--sfc\" and \"--lsm\" flags is that while the \"--sfc\" datasets are not required for model ".
                     "initialization, ems_prep will terminate if any of the \"--lsm\" datasets are missing. To reduce the likelihood of your forecast ".
                     "coming to an untimely demise, fail-over datasets can be specified should your first choice not be available. In this application, ".
                     "the pipe (|) character is used to separate a succession of datasets in decreasing order of desirability (from left to right). If ".
                     "a dataset in this list is not available, ems_prep will proceed to the next. Once a dataset from the list is acquired, the search ".
                     "ends and ems_prep continues with processing of the files; however, if none of the listed fail-over options are found, the ".
                     "entire process terminates and your forecast dreams are dashed once again.\n\n".

                     "The use of the \"|\" separator should not be confused with the comma-separated LSM datasets. The comma is used to specify multiple ".
                     "datasets that are mandatory for model initialization, while a \"|\" is used to specify alternatives to each mandatory data type. ".
                     "Additionally. when using \"|\" separator with the \"--lsm\" flag, the entire string must be in quotations. This is due to how ".
                     "the Linux command line interpreter handles the pipe symbol.\n\n".

                     "Here is a slightly less confusing example:\n\n".

                     "  --lsm  \"Alsm1|Alsm2|Alsm3,Blsm1|Blsm2\"   Note the use of quotations!\n\n".

                     "Assuming that the datasets listed above actually mean anything, this example specifies that two LSM datasets are required for ".
                     "model initialization; one from group \"A\", Alsm1|Alsm2|Alsm3, and one from group \"B\", Blsm1|Blsm2. The ems_prep routine will ".
                     "first attempt to get Alsm1 from group A. Should that dataset not be available, it will try to get the Alsm2 dataset, and so on. ".
                     "If successful, the routine will next attempt to acquire Blsm1 from the second group with Blsm2 serving as a fail-over. Should ".
                     "ems_prep fail to locate a dataset from any group, model initialization is over for you.\n\n\n".

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



            
       $help{ADDN} = "You might want to pipe this output to \"more\":  \"% ems_prep --help dset | more\""; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_dsquery {
#==================================================================================
#  Routine provides guidance for using the --dsquery & --dsquery flags
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--dsquery|dsinfo DSET';

       $help{WHAT} = 'Query the default configuration settings for the specified dataset.';

       $help{USE}  = '% ems_prep --dsquery DSET';


       $help{DESC} = "The \"--dsquery\" flag allows you to review the contents of a <dset>_gribinfo.conf file, which ".
                     "provides the default configuration values including a description of the dataset, file sources, ".
                     "naming conventions, and other valuable information.\n\n".

                     "The argument to \"--dsquery\" is the moniker used to identify a specific dataset, a list of which is provided ".
                     "by the \"--dslist\" flag. Lots of good information.\n\n".

                     "Here is an example for the gfsp25 dataset:\n\n".

                     "  % ems_prep --dsquery gfsp25\n\n".

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


sub PrepHelp_dslist {
#==================================================================================
#  Routine provides guidance for using the --dslist flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--dslist';

       $help{WHAT} = 'Provide a summary of available initialization datasets';

       $help{USE}  = '% ems_prep --dslist';

       $help{DESC} = "Passing the \"--dslist\" flag provides a brief summary of the datasets supported by ".
                     "the UEMS for initializing a simulation. Further information about a specific dataset ".
                     "can be obtained by passing the \"--dsquery\" flag along with the corresponding moniker.";

       $help{ADDN} = "The \”--dslist\” flag also gives you fresher breath, but you probably don't need it."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_help {
#==================================================================================
#  Routine provides guidance for using the --help flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--help';

       $help{WHAT} = "I'm the help flag, what did you expect?";

       $help{USE}  = '% ems_prep --help [maybe a help topic]';

       $help{DESC} = "The \"--help\" flag should not need any introduction, but since you're rather new at this, I'll entertain ".
                     "your insatiable quest for knowledge and let you in on some valuable information.\n\n".

                     "Passing the \"--help\" flag without any arguments provides a list of flags and options that can be ".
                     "used with ems_prep when running on the command line. It's fairly simple, and may be used as a quick ".
                     "reference to my utility should your brain fail you yet again.\n\n".

                     "Once the above usage has been mastered, there is else something you must learn that isn't taught during ".
                     "any \"Birds & Bees\" discussions. The \"--help\" flag can also take an argument in the form of a listed ".
                     "flag without the leading dashes (\"--\"). \"Wow!\" you exclaim, \"I didn't know that!\"\n\n".

                     "Well, now you know.  And at least you didn't have to hear it on the streets.";

            
       $help{ADDN} = "The UEMS is the font of half of life's useful knowledge, kindergarten provides the rest."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_hiresbc {
#==================================================================================
#  Routine provides guidance for using the --hiresbc flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--hiresbc';

       $help{WHAT} = 'Interpolate between available file times to create hourly BC update files';

       $help{USE}  = '% ems_prep [important stuff] --hiresbc';

       $help{DESC} = "By passing the \"--hiresbc\" flag you are requesting that 1-hourly boundary condition update ".
                     "files be created instead of the default frequency, which would be the same as the temporal ".
                     "frequency of the boundary condition files downloaded for model initialization. This flag ".
                     "serves to provide no benefit to the quality of the model simulation, but rather, will allow:\n\n".

                     "  1. The user to start the integration of a child domain at a time that does not\n".
                     "     coincide with a default boundary condition update time.\n\n".

                     "  2. A simulation to end at a time that does not coincide with a default boundary\n".
                     "     condition update time.\n\n".

                     "For example, if your boundary condition files were 3-hourly, but you wanted to run a 2 hour ".
                     "simulation, or if you wanted to start the integration of a child domain 2 hours after the start ".
                     "of the primary domain. Passing \"--hiresbc\" would allow you to accomplish this task.";


       $help{ADDN} = "4 out of 5 dentists don't know what the \”--hiresbc\” flag is used for, but they still make ". 
                     "more money than you.";

return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_length {
#==================================================================================
#  Routine provides guidance for using the --length flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--length HOURS';

       $help{WHAT} = 'Specify the simulation length (hours) for the primary domain';

       $help{USE}  = '% ems_prep --length HOURS [other stuff]';

       $help{DESC} = "Passing the \"--length\" flag overrides the value of FINLFH (See: \"--cycle\" option) ".
                     "in defining the maximum length of a simulation (excluding global). Passing:\n\n".
            
                     "    % ems_prep --dset <dataset> --cycle 00:06 --length 36\n\n".

                     "is the same as passing:\n\n".

                     "    % ems_prep --dset <dataset> --cycle 00:06:42:03  (Note: 42-6 = 36)\n\n".

                     "The \“--length\” option overrides everything when defining the length of your simulation.";

       $help{ADDN} = "The \”--length\” option must be used when specifying separate datasets for initial ". 
                     "and boundary conditions (See: \"--dset\" option).";


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_local {
#==================================================================================
#  Routine provides guidance for using the --local flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--local';

       $help{WHAT} = 'Instructs ems_prep to only look in the <domain>/grib directory for initialization files';

       $help{USE}  = '% ems_prep [other more important stuff] --local';


       $help{DESC} = "Pass the \"--local\" flag if you want the ems_prep routine to only look in the local grib/ ".
                     "directory for the initialization files.  This flag does the same thing as specifying ".
                     "\"--dset <dataset>:local\", but too much of a good thing makes an even better thing so ".
                     "\"--local\" was added. Enjoy them together!";


       $help{ADDN} = "The \”--local\” flag does not play well with \"--scour\""; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_noaltsst {
#==================================================================================
#  Routine provides guidance for using the --noaltsst flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--noaltsst';

       $help{WHAT} = 'Do not use the derived daily-average surface air temperatures in the absence of actual SST data';

       $help{USE}  = '% ems_prep --noaltsst [other stuff]';

       $help{DESC} = "Passing the --noaltsst flag instructs ems_prep to not use the WRF derived daily-average surface ".
                     "air temperatures for water temperatures in the absence of data when initializing lake SSTs. This ".
                     "flag only applies to domains that are initialized with the modis_lakes or usgs_lakes dataset and ".
                     "are greater than 24 hours in length. If this does not describe your simulation then please ".
                     "entertain yourself with another \"--help\" topic.\n\n\n".


                     "The Background Information (Selectively liberated from the WRF User's Guide):\n".
                     "-------------------------------------------------------------------------------\n\n".

                     "The treatment of water temperatures, both for oceans and lakes, normally involves simply interpolating ".
                     "the SST field to all water points in the WRF domain. However, if the lakes that are not well resolved in ".
                     "either the WRF domain or GRIB data, and especially if those lakes are geographically distant from resolved ".
                     "water bodies, the SST field over lakes will most likely be extrapolated from the nearest resolved body of ".
                     "water in the GRIB data. This situation can lead to lake SST values that are either unrealistically warm or ".
                     "unrealistically cold.\n\n".

                     "An alternative to extrapolating SST values for lakes is to manufacture a “best guess” at the SST for lakes. ".
                     "This is done using a combination of a special land use dataset that distinguishes between lakes and oceans, ".
                     "and a field to be used as a proxy for SST over lakes. A special land use dataset is necessary, since WRF ".
                     "needs to know where the manufactured SST field should be used instead of the interpolated SST field from the ".
                     "GRIB data.\n\n\n".

            
                     "Now, How It Happens in the UEMS:\n".
                     "---------------------------------\n\n".
 
                     "By default, the UEMS uses the alternative initialization method for lake SSTs described above when a domain ".
                     "is localized with the modis_lakes or usgs_lakes dataset and the simulation is greater than 24 hours in ".
                     "length. However, a potential problem exists in that because this alternate SST field is based on air temperature, ".
                     "it sometimes does not properly represent the water temperatures during certain parts of the year. For example, ".
                     "sub-freezing air temperatures may be assigned to water points when climatologically, the water temperatures ".
                     "are much warmer. This mis-assignment can result in open water being treated as ice covered during the simulation. ".
                     "As a possible work-around to this issue, the \"--noaltsst\"  flag may be passed that effectively turns off ".
                     "the alternative initialization method, for better or worse.\n\n".

                     "One last comment before I go. The \”--noaltsst\” flag is automatically turned ON for global simulations or when ".
                     "the computational domain was localized without inland lakes (USGS & MODIS land use datasets).";
            
       $help{ADDN} = "The \”--noaltsst\” flag is your friend and simulation savior, except when it isn't."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_ncpus {
#==================================================================================
#  Routine provides guidance for using the --ncpus flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--ncpus #CPUS';

       $help{WHAT} = 'Specify the number of processors to use when running WRF metgrid (horizontal interpolation)';

       $help{USE}  = '% ems_prep --ncpus #CPUS [other more important stuff]';

       $help{DESC} = "Passing the \"--ncpus\" flag overrides the default value for the number of processors ".
                     "to use when running the WRF metgrid routine.  If \"--ncpus\" is not passed, then the UEMS ".
                     "will determine the number of physical cores on the system and use that value.\n\n".

                     "Note that just because you want X processors when running metgrid, doesn't mean the UEMS ".
                     "will use that many. The system will only use available physical (non-hyperthreaded) cores ".
                     "and will test for domain over-decomposition and reduce the number of cpus as necessary.";
                      
            
       $help{ADDN} = "The \”--ncpus\” flag is probably not the most important flag in your arsenal."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_nodelay {
#==================================================================================
#  Routine provides guidance for using the --nodelay flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--nodelay';

       $help{WHAT} = 'Override the default gribinfo file DELAY setting (Set DELAY = 0)';

       $help{USE}  = '% ems_prep --nodelay [other stuff]';

       $help{DESC} = "Passing the \"--nodelay\" flag will turn off (set to 0 hours) the DELAY value defined in the ".
                     "DSET_gribinfo.conf file for each dataset being used for initialization. Using the ".
                     "\"--nodelay\" flag is kind of like saying \"I want it now!\" even though this effort might \n".
                     "be futile.";
            
       $help{ADDN} = "Passing the \”--nodelay\” flag always seems like a good idea at the time."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_nointdel {
#==================================================================================
#  Routine provides guidance for using the --nointdel flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--nointdel';

       $help{WHAT} = 'Do not delete the intermediate files after processing (Default: Delete)';

       $help{USE}  = '% ems_prep --nointdel [other stuff]';

       $help{DESC} = "Pass the --nointrdel flag if you do not want the processed WRF intermediate files scoured from the ".
                     "wpsprd directory following successful completion of ems_prep. The default behavior is to delete these ".
                     "files since they are no longer needed.\n\n".

                     "The WRF intermediate files contain information extracted from the GRIB files for the fields identified ".
                     "by the designated variable table (Vtable) and written out in a binary format. Typically, you do not need ".
                     "to keep the intermediate files since they are processed into WRF netCDF for use in creating the initial ".
                     "and boundary condition files. However, there are times when you need to do some troubleshooting and ".
                     "thus require these files for the investigation.";

       $help{ADDN} = "The contents of the WRF intermediate files may be viewed with the provided \"rdwrfin\" utility:\n\n". 
                     "  %  rdwrfin  <intermediate file>";

return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_noproc {
#==================================================================================
#  Routine provides guidance for using the --noproc flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--noproc';

       $help{WHAT} = 'Do not processes the grib files for model initialization after acquisition';

       $help{USE}  = '% ems_prep --noproc [other stuff but not much]';

       $help{DESC} = "Passing the \"--noproc\" flag will instruct ems_prep to acquire the requested GRIB files for ".
                     "model initialization but do not process them for use in a simulation. The GRIB files will be placed ".
                     "in the <domain>/grib directory and named according to the convention defined in DSET_gribinfo.conf, ".
                     "but that's all the action you're going to get.";

            
       $help{ADDN} = "Use the \”--noproc\” flag if you are just looking for GRIB files, or trouble."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_nudge {
#==================================================================================
#  Routine provides guidance for using the --nudge flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--nudge';

       $help{WHAT} = 'Process the domains for 3D Analysis/Spectral nudging';

       $help{USE}  = '% ems_prep --nudge [lots of other stuff]';

       $help{DESC} = "Passing the \"--nudge\" flag instructs ems_prep to process the initialization dataset files for use ".
                     "with 3D analysis or spectral nudging during the simulation. While this step is required if you intend ".
                     "to use analysis or spectral nudging, you still have the option to turn it off later on (See Chapter ".
                     "8 of the \"UEMS Guide to Simulation Excitement\").";

            
       $help{ADDN} = "Didn't know there was a \"UEMS Guide to Simulation Excitement\", did you?"; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_previous {
#==================================================================================
#  Routine provides guidance for using the --previous flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--previous';

       $help{WHAT} = 'Use the previous cycle of an initialization dataset rather than the current one';

       $help{USE}  = '% ems_prep --previous [other stuff]';

       $help{DESC} = "Passing the \"--previous\" flag will instruct ems_prep to acquire and use initialization data from ".
                     "the previous dataset cycle time rather than the current cycle. This flag is primarily used as a ".
                     "fail-over option when running real-time forecasts with the ems_autorun routine and should not be ".
                     "attempted by mortals unless you think you know what you are doing.";
            
       $help{ADDN} = "Go ahead, pass the \”--previous\” flag. What do you have to lose but time and your sense of self-worth?"; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_scour {
#==================================================================================
#  Routine provides guidance for using the --[no]scour flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--[no]scour';

       $help{WHAT} = 'Controls the amount of domain directory cleaning done prior to the start of ems_prep';

       $help{USE}  = '% ems_prep --[no]scour [more important stuff]';

       $help{DESC} = "Passing the \"--scour\" flag overrides the default level of cleaning done prior to ".
                     "the start of ems_prep. If this flag is not passed, then the default level is the same ".
                     "as running \"ems_clean --level 3\", which deletes all non-essential files in the domain ".
                     "directory while keeping any initialization data under grib/.\n\n".

                     "Passing \"--scour\" is the same as running \"ems_clean --level 4\", which also includes ".
                     "the removal of all files from grib/. You might include this flag if you wanted to download ".
                     "a fresh set of GRIB files for initialization while deleting any existing files.\n\n".
 
                     "Passing \"--noscour\" is the same as running \"ems_clean --level 0\", which simply ".
                     "deletes old log files and recreates the symbolic links to the run-time scripts.";
                      
            
       $help{ADDN} = "\"% ems_prep --scour [other stuff]\” is the default when running ems_autorun"; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_sleep {
#==================================================================================
#  Routine provides guidance for using the --sleep flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--sleep';

       $help{WHAT} = 'The number of seconds between attempts to acquire initialization data - For real-time use only';

       $help{USE}  = '%  ems_prep --sleep <seconds to wait> [other stuff]';

       $help{DESC} = "The \"--sleep\" flag specifies the amount of time, in seconds, between attempts to acquire ".
                     "the dataset(s) used for model initialization. Should an attempt fail, ems_prep will wait # ".
                     "seconds before trying again.\n\n".

                     "The \"--sleep\" and \"--attempts\" flags are designed for real-time forecasting purposes ".
                     "to allow for delays in the availability of operational datasets on remote servers. ";
            
       $help{ADDN} = "See the conf/ems_autorun/ems_autorun.conf file for more details."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_syncsfc {
#==================================================================================
#  Routine provides guidance for using the --syncsfc flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--syncsfc';

       $help{WHAT} = 'Synchronize surface datasets to simulation initialization (00-hour) time';

       $help{USE}  = '% ems_prep [other stuff] --syncsfc [<sfc dataset>,<sfc dataset>,...]';

       $help{DESC} = "Passing \"--syncsfc\" tells the ems_prep to synchronize the valid hour of the specified surface dataset(s) ".
                     "with the initialization time of the model simulation, i.e., only use those data that are valid near the ".
                     "simulation start hour. The argument to \"--syncsfc\" is a list of surface datasets, separated by commas, to ".
                     "which this requirement is applied. Should a dataset not be available near the simulation start date and time, ".
                     "ems_prep will look for data 24 hours earlier rather than use the next closest verification time. The number ".
                     "of previous 24-hour periods (days) searched is defined by the AGED parameter in the <dataset>_gribinfo.conf ".
                     "associated with each surface dataset listed.\n\n".

                     "The \"--syncsfc\" flag can be passed with or without an argument. Any surface dataset listed must also be included ".
                     "with the \"--sfc\" flag; however, not all \"--sfc\" datasets must be included with \"--syncsfc\". If no ".
                     "dataset is specified, i.e, just \"--syncsfc\", then all \"--sfc\" datasets will be used whether you like it or ".
                     "not.\n\n\n".


                     "Why do this?\n".
                     "--------------\n\n".

                     "Some datasets, such as MODIS SSTs, have a diurnal variation that needs to be taken into account when used to ".
                     "initialize a simulation. It may not be appropriate to use a dataset from 00 UTC for a 12 UTC run start, even ".
                     "if that file time is closest to the simulation start date. If \"--syncsfc\" is passed, ems_prep will look ".
                     "for data valid near 12 UTC from the previous day rather than use data from 00 UTC the current day. ".
                     "Note that the times do not have to exactly match model initialization since the verification hour closest ".
                     "to the model initialization will be determined.";

            
       $help{ADDN} = "The \”--syncsfc\” flag is easier to use than explain - Sort of."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PrepHelp_timeout {
#==================================================================================
#  Routine provides guidance for using the --timeout flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--timeout';

       $help{WHAT} = 'Override the default MPICH timeout value when doing the horizontal interpolation';

       $help{USE}  = '% ems_prep [more better stuff] --timeout [seconds]';

       $help{DESC} = "Passing --timeout serves to override the value of TIMEOUT located in the default prep_global.conf file. The ".
                     "purpose for TIMEOUT is to avoid problems with the WRF horizontal interpolation routine (metgrid) hanging after ".
                     "processing of the intermediate files into netCDF. On most systems, this is not an issue and processing ends ".
                     "normally, but sometimes the routine will fail to exit even though all files have been successfully processed. ".
                     "In that event, the TIMEOUT setting will define the length of time (seconds) from the beginning of processing ".
                     "until the horizontal interpolation is forcefully terminated.\n\n".

                     "Note that the TIMEOUT period starts at the beginning of the horizontal interpolation, so for some very large ".
                     "datasets or simulations with many boundary condition files it is possible to exceed the timeout period while ".
                     "processing is ongoing. If this happens the simulation will fail during initialization. In most cases though, ".
                     "the default default setting of 1199 seconds should be sufficient.\n\n".

                     "Finally, passing \"--timeout 0\" turns the timeout option OFF (no time limit).\n";


       $help{ADDN} = "The default value of 1199 seconds is almost 20 minutes!"; 


return &Ehelp::FormatHelpTopic(\%help);
}


