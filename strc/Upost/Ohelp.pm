#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Ohelp.pm
#
#  DESCRIPTION:  Ohelp contains subroutines used to provide love & guidance
#                to the user running ems_post, including the help menu and
#                information on each option.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Ohelp;

use warnings;
use strict;
require 5.008;
use English;

use Ehelp;


sub PostHelpMe {
#==================================================================================
#  The PostHelpMe routine determines what to do when the --help flag is
#  passed with or without an argument. If arguments are passed then the 
#  PrintPostOptionHelp subroutine is called and never returns.
#==================================================================================
#
    my @args  = &Others::rmdups(@_);

    &PrintPostOptionHelp(@args) if @args;

    &Ecomm::PrintTerminal(0,7,255,1,1,&ListPostOptions);

&Ecore::SysExit(-4); 
}


sub PostHelpMeError {
#==================================================================================
#  The PostHelpMeError routine determines what to do when the --help flag is
#  passed with or without an argument.
#==================================================================================
#
    my @args  = @_;

    &Ecomm::PrintTerminal(6,4,255,1,1,"It appears you have caused an error (@args)",&ListPostOptions);

&Ecore::SysExit(-4); 
}


sub ListPostOptions  {
#==================================================================================
#  This routine provides the basic structure for the ems_post help menu 
#  should  the "--help" option is passed or something goes terribly wrong.
#==================================================================================
#

    my $mesg  = qw{};
    my @helps = ();

    my $exe = 'ems_post'; my $uce = uc $exe;

    my %opts = &DefinePostOptions();  #  Get options list

    push @helps => &Ecomm::TextFormat(0,0,114,0,1,"RUDIMENTARY GUIDANCE FOR $uce (Because you need it)");

    $mesg = "The ems_post routine is used to process simulation output from the UEMS into a format ".
            "suitable for display or for additional processing by an external package. Options include, ".
            "but are not limited to converting the netCDF files to GRIB 2 format, writing GRIB to GrADS ".
            "files, creating and processing BUFR sounding files, sending files to another system and lots ".
            "of other fun stuff that I have not yet contemplated.\n\n".

            "If no flags or options are passed to $exe, the default behavior is to process all available ".
            "primary output files for domain #1 in accordance to the parameter setting in the post_uems.conf ".
            "file. If you are looking for something different, read the description for each flag and option ".
            "below or the UEMS User's Guide (under uems/docs), and then let your imagination run wild.";

    push @helps => &Ecomm::TextFormat(2,2,90,1,1,$mesg);

    push @helps => &Ecomm::TextFormat(0,0,114,2,1,"$uce USAGE:");
    push @helps => &Ecomm::TextFormat(4,0,144,1,1,"% $exe [--domains 1,..,N] [Other options]");

    push @helps => &Ecomm::TextFormat(0,0,124,2,1,"AVAILABLE OPTIONS - BECAUSE THAT GLINT IN YOUR EYE SAYS, \"BACK OFF MAN, I'M A MODELER!\"");

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


sub DefinePostOptions {
#==================================================================================
#  This routine defined the list of options that can be passed to the program
#  and returns them as a hash.
#==================================================================================
#
    my %opts = (
                '--scour'       => { arg => ''            , help => '&PostHelp_scour'     , desc => 'Scour all files and directories beneath emsprd before processing model output'},
                '--debug'       => { arg => ''            , help => '&PostHelp_debug'     , desc => 'Turn ON debugging statements (If any exist)'},
                '--domains'     => { arg => 'DOMAIN #'    , help => '&PostHelp_domain'    , desc => 'Specify the domain to be processed (Default is domain 1)'},
                '--rundir'      => { arg => 'DIR'         , help => '&PostHelp_rundir'    , desc => 'Set the simulation run-time directory if not current working directory'},
                '--auxhist'     => { arg => ''            , help => '&PostHelp_auxhist'   , desc => 'Process auxiliary (auxhist1) output files'},
                '--wrfout'      => { arg => ''            , help => '&PostHelp_wrfout'    , desc => 'Process primary (wrfout) output files'},
                '--afwa'        => { arg => ''            , help => '&PostHelp_afwa'      , desc => 'Process AFWA output files (Not currently activated)'},
                '--noupp'       => { arg => ''            , help => '&PostHelp_noupp'     , desc => 'Skip the netCDF to GRIB processing via EMSUPP as output was previously converted to GRIB'},
                '--info'        => { arg => ''            , help => '&PostHelp_info'      , desc => 'Print a summary of the post-processing tasks and then exit'},
                '--summary'     => { arg => ''            , help => '&PostHelp_info'      , desc => 'Similar to --info, but continues with data processing after printing the summary'},
                '--[no]grib'    => { arg => '[FREQ:START:STOP]' , help => '&PostHelp_grib', desc => 'Turn ON [OFF] processing of netCDF into GRIB and all derived products (FREQ:START:STOP in minutes)'},
                '--[no]gempak'  => { arg => ''            , help => '&PostHelp_gempak'    , desc => '[Do Not] Process GRIB files into GEMPAK format'},
                '--[no]grads'   => { arg => ''            , help => '&PostHelp_grads'     , desc => '[Do Not] Convert GRIB files into GrADS compatible files'},
                '--[no]bufr'    => { arg => '[FREQ:START:STOP]' , help => '&PostHelp_bufr', desc => 'Turn ON [OFF] processing of netCDF into BUFR and all derived products'},

                '--[no]bufkit'  => { arg => ''            , help => '&PostHelp_bufkit'    , desc => '[Do Not] Convert processed BUFR files into BUFKIT compatible files'},
                '--[no]gemsnd'  => { arg => ''            , help => '&PostHelp_gemsnd'    , desc => '[Do Not] Create GEMPAK station profile and surface files from BUFR files'},
                '--[no]bfinfo'  => { arg => ''            , help => '&PostHelp_bfinfo'    , desc => '[Do Not] Write lots of interesting information to the BUFR log file'},

                '--noexport'    => { arg => '[LIST]'      , help => '&PostHelp_noexport'  , desc => '[Do Not] Export files in LIST that match an EXPORTS entry'},
                '--emspost'     => { arg => 'ID#:dsA:dsB' , help => '&PostHelp_emspost'   , desc => 'Used by ems_autorun (or you) to define the domains and datasets to process following a simulation'},
                '--autopost'    => { arg => 'ID#:dsA:dsB' , help => '&PostHelp_autopost'  , desc => 'Similar to --emspost but used by ems_autorun as part of concurrent post-processing'},
                '--autoupp'     => { arg => 'HOST:NCPUS[,..]', help => '&PostHelp_autoupp', desc => 'Override the value of EMSUPP_NODECPUS in post_grib.conf when running UEMS AutoPost'},

                '--ncpus'       => { arg => 'CPUS'        , help => '&PostHelp_ncpus'     , desc => 'Specify the number of CPUs to use during EMSUPP'},
                
                '--index'       => { arg => '#'           , help => '&PostHelp_index'     , desc => 'Used by autopost to specify the file with which to begin processing'} 
                );

return %opts;
}



sub PrintPostOptionHelp {
#==================================================================================
#  The PrintPostOptionHelp takes a string that is matched to a help topic. 
#  There is no returning from this subroutine - ever.
#
#  This routine is a bit sloppy and should be cleaned up - You do it.
#==================================================================================
#
    my ($package, $filename, $line, $subr, $has_args, $wantarray)= caller(1);

    my $exit = ($subr =~ /CheckPostOptions/) ? -5 : -4;

    my %opts = &DefinePostOptions();  #  Get options list

    my $dash   = '-' x 108;
    my @topics = &Others::rmdups(@_);

    foreach my $topic (@topics) {

        my $flag = &Ooptions::MatchPostOptions("--$topic");

        if ($flag and defined $opts{$flag}{help}) {

            my $help = eval $opts{$flag}{help}; 
               $help = "Hey - Add some magic words for the $flag flag!" unless $help;
  
            my $head = ($subr =~ /CheckPostOptions/) ? "It appears you need some assistance with the $flag flag:" 
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


sub PostHelp_help {
#==================================================================================
#  Routine provides guidance for using the --help flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--help';

       $help{WHAT} = "I'm the help flag, what did you expect?";

       $help{USE}  = '% ems_post --help [maybe a help topic]';

       $help{DESC} = "The \"--help\" flag should not need any introduction, but since you're rather new at this, I'll entertain ".
                     "your insatiable quest for knowledge and let you in on some valuable information.\n\n".

                     "Passing the \"--help\" flag without any arguments provides a list of flags and options that can be ".
                     "used with ems_post when running on the command line. It's fairly simple, and may be used as a quick ".
                     "reference to any utility should your brain fail you yet again.\n\n".

                     "Once the above usage has been mastered, there is else something you must learn that isn't taught during ".
                     "any \"Birds & Bees\" discussions. The \"--help\" flag can also take an argument in the form of a listed ".
                     "flag without the leading dashes (\"--\"). \"Wow!\" you exclaim, \"I didn't know that!\"\n\n".

                     "Well, now you know.  And at least you didn't have to hear it on the street.";

            
       $help{ADDN} = "The UEMS is the font of half of life's useful knowledge, kindergarten provides the rest."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_bufr {
#==================================================================================
#  Routine provides guidance for the --bufr flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--[no]bufr';

       $help{WHAT} = 'Turn ON [OFF] processing of netCDF into BUFR and all derived products';

       $help{USE}  = '% ems_post --[no]bufr  [FREQ:START:STOP] [some less, some more, important stuff]';

       $help{DESC} = "Passing \"--[no]bufr\" gives you the type of super power you always wanted while ".
                     "in elementary school, except for X-ray vision, which will be included in a ".
                     "future UEMS release.\n\n".
                     
                     "The \"--[no]bufr\" flag is used to override the BUFR parameter value in post_uems.conf. ".
                     "If BUFR = Yes and you want to turn OFF processing, just pass \"--nobufr\" and ems_post ".
                     "will magically make it happen for you. Note that turning OFF the creation of BUFR ".
                     "files also turns OFF processing of all secondary data formats such as BUFKIT and ".
                     "GEMPAK sounding files. Alternatively, passing \"--bufr\" turns ON BUFR file generation; ".
                     "however, the processing BUFR into secondary formats is dependent upon the parameter ".
                     "settings in post_bufr.conf or associated command-line flags.\n\n".

                     "Besides the guidance provided above, you can fine-tune your BUFR files processing by ".
                     "including the \"FREQ:START:STOP\" option (because it\'s optional). This string overrides ".
                     "the value of FREQUENCY_WRFOUT in post_bufr.conf by defining the frequency (minutes) of ".
                     "raw netCDF files to process into BUFR, the data file with which to start, and the final ".
                     "file time to process. The START & STOP values are specified in minutes from T0 (integration ".
                     "start time for the domain being processed) and FREQ is the number of minutes between data ".
                     "files. For the example, if the output frequency of a simulation is every 15 minutes but ".
                     "you want to only process 30 minute data between minute 60 and 180, pass:\n\n".

                     "X02X% ems_post --bufr 30:60:180\n\n".

                     "The UEMS checks to ensure that your time range falls within that of your simulation, so you ".
                     "can't mess things up too badly. Note that any secondary BUFR file processing will be impacted ".
                     "if you use this option since the resultant files will be carried into the additional steps.";
 

       $help{ADDN} = 'The --[no]bufr flag - just like --[no]grib, only shorter';


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_grib {
#==================================================================================
#  Routine provides guidance for the --grib flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--[no]grib';

       $help{WHAT} = 'Turn ON [OFF] processing of netCDF into GRIB 2 and all derived products';

       $help{USE}  = '% ems_post --[no]grib  [FREQ:START:STOP] [less important stuff]';

       $help{DESC} = "Passing \"--[no]grib\" gives you the type of super power you always wanted while ".
                     "in college, including the ability to focus every cell phone at the party on you, just ".
                     "after you've screamed \"Hey, Watch This!\". Use the power wisely my friends.\n\n".
                     
                     "The \"--[no]grib\" flag is used to override the GRIB parameter value in post_uems.conf. ".
                     "If GRIB = Yes and you want to turn OFF processing, just pass \"--nogrib\" and ems_post ".
                     "will magically make it happen for you. Note that turning OFF the creation of GRIB ".
                     "files also turns OFF processing of all secondary data formats such as GrADS and ".
                     "GEMPAK sounding files.\n\n".


                     "Passing \"--grib\" turns on the creation of GRIB 2 files with the EMSUPP routine. This ".
                     "flag might be used if you set GRIB = No in post_uems.conf and are too lazy to change it. ".
                     "However, the primary purpose for this option is to allow for finer control over the ".
                     "processing of simulation netCDF files into GRIB 2. The \"--grib\" flag also accepts an ".
                     "argument that specifies the start and stop times along with the frequency of netCDF files ".
                     "to process, \"FREQ:START:STOP\". All values are all defined in minutes from the start of ".
                     "integration for the domain being processed.\n\n".

                     "Here are a few examples:\n\n".

                     "X04X%   ems_post --grib 60\n\n".

                     "Translation: Have the EMSUPP process 60-minute (hourly) output netCDF files from the primary ".
                     "simulation (wrfout) into GRIB2. If the frequency of simulation output is hourly, then the \"60\" ".
                     "was not necessary and you clearly don't know what you are doing. If the frequency of wrfout files ".
                     "is 30-minute, then ems_post will only process every other netCDF file. If the output frequency ".
                     "from the model was less than 60-minute, say 3-hourly, then ems_post will adjust the processing ".
                     "frequency to that of the model output and then give you a snarky response before continuing.\n\n".


                     "X04X%   ems_post --grib 60  --auxhist\n\n".

                     "Translation: The same as for the previous example except the auxiliary history files will be ".
                     "processed rather then the primary output from the simulation.\n\n".


                     "X04X%   ems_post --grib 60  --auxhist  --domain 2\n\n".

                     "Translation: The same as for the previous example for the auxiliary history files but this time ".
                     "output for domain 2 will be processed.\n\n".


                     "X04X%   ems_post --grib 60:180\n\n".

                     "Translation: Have the EMSUPP process 60-minute (hourly) output netCDF files from the primary ".
                     "simulation (wrfout) into GRIB2, beginning with the 180-minute (3-hour) output file and continuing ".
                     "through the final model output time. In this example all simulation output prior to the 3 hour ".
                     "mark will be skipped.\n\n".


                     "X04X%   ems_post --grib 60:180:720\n\n".

                     "Translation: Have the EMSUPP process 60-minute (hourly) output netCDF files from the primary ".
                     "simulation (wrfout) into GRIB2, beginning with the 180-minute (3-hour) output file and continuing ".
                     "through the 12-hour output file.\n\n".


                     "X04X%   ems_post --grib ::720\n\n".

                     "Translation: Have the EMSUPP process every primary simulation output netCDF file (wrfout) into GRIB2, ".
                     "beginning with the zero hour (T0) output file and continuing through the 12 hour output file.\n\n".

                     "So you can see where this is going and can figure the rest out for yourself. Note that the management ".
                     "of GRIB file generation does impact secondary file formats such as GrADS and GEMPAK, since these data ".
                     "are created from GRIB.";


       $help{ADDN} = 'The --[no]grib flag has the power to make you go viral!';


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_bfinfo {
#==================================================================================
#  Routine provides guidance for the --[no]bfinfo flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--[no]bfinfo';

       $help{WHAT} = '[Do Not] Write lots of interesting blather to the BUFR log file';

       $help{USE}  = '% ems_post --[no]bfinfo  [any other flags you desire]';

       $help{DESC} = "Passing the \"--[no]bfinfo\" flag overrides the BUFR_INFO setting in the post_bufr.conf file. ".
                     "Passing \"--bfinfo\" or setting BUFR_INFO = YES in post_bufr.conf will include additional and ".
                     "hopefully interesting information in the post_emsbufr.log file. The downside is that all the ".
                     "additional I|O will slightly increase processing time but may also enhance your social status ".
                     "as you will have plenty of fodder for scintillating conversation with complete strangers.";

       $help{ADDN} = 'Pass \"--bfinfo\" and become immediately more interesting to others - Do it today!';


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_bufkit {
#==================================================================================
#  Routine provides guidance for the --bufkit flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--[no]bufkit';

       $help{WHAT} = 'Override the generation of BUFKIT files as specified in post_bufr.conf';

       $help{USE}  = '% ems_post --bufkit [anything else you might have on your mind]';

       $help{DESC} = "Passing \"--[no]bufkit\" overrides the generation of BUFKIT files as specified in the post_bufr.conf file, ".
                     "just as you read above, but I want to make sure you are paying attention. Passing \"--bufkit\" also turns ".
                     "on BUFR file processing whether you like it or not since the BUFKIT station files are created from BUFR. ".
                     "Conversely, passing \"--nobufkit\" will not affect the processing of BUFR files.\n\n".

                     "After the smoke clears, all BUFKIT files will be located in the \"emsprd/bufkit/\" directory. If you ".
                     "want to export the files to other exotic locations, then check out the possibilities presented in the ".
                     "post_export.conf file. You'll be glad you did.";


       $help{ADDN} = 'That\'s just the way this thing works.';


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_debug {
#==================================================================================
#  Routine provides guidance for using the --debug flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--debug';

       $help{WHAT} = 'Sets the level of debugging or something';

       $help{USE}  = '% ems_post --debug [emsupp] [other stuff]';

       $help{DESC} = "Passing the \"--debug\" prints out some additional information about the processing of simulation ".
                     "output with ems_post. It primarily serves the developer in debugging the problems that remain in ".
                     "in the routine, of which there are none.\n\n".

                     "The optional argument \"emsupp\" may be passed for debugging the UEMS UPP program.  If passed, ems_post ".
                     "forgets about printing the \"additional information\" and simply prepares the developer for running ".
                     "uems/bin/emsupp from the command line.";

       $help{ADDN} = "Treat the \”--debug\” flag with the respect it deserves."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_autopost {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--autopost';

       $help{WHAT} = 'Turn autopost processing ON for domains 1 to Infinity+42';

       $help{USE}  = '% ems_post --autopost ';

       $help{DESC} = "The \"--autopost\" flag is passed by ems_autorun.pl when doing concurrent post processing ".
                     "of the simulation output files, i.e, while the model is still running. This flag is not ".
                     "intended for use from the command line, but if attempted, it will mimic the behavior of ".
                     "the \"--emspost\" flag.";


       $help{ADDN} = 'I bet you were hoping for something more exciting.'; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_emspost {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--emspost';

       $help{WHAT} = 'Turn post processing ON for domains 1 to Infinity+42';

       $help{USE}  = '% ems_post --emspost 1[:dsA[:dsB]],...,Infinity+11    [superior flags]';

       $help{DESC} = "The \"--emspost\" flag is typically used internally by ems_autorun to specify the domains ".
                     "and datasets to process following the completion of a simulation; however, that doesn't ".
                     "mean that you can't harness its power when running ems_post from the command line.\n\n".

                     "The argument to \"--emspost\" specifies the domains and datasets that you want to process. ".
                     "There are currently two output datasets available for processing, \"primary\" and \"auxiliary\". ". 
                     "One or both of these datasets, along with a domain ID, may be included as part of a \"rules group\",".
                     "the format for which is:\n\n".

                     "X02X% ems_post --emspost ID#:dsA:dsB\n\n".

                     "Where ID# is the domain number to apply the rules, and dsA & dsB are placeholders for ".
                     "\"primary\" and|or \"auxiliary\", i.e, the \"rules\". For example:\n\n".

                     "X02X% ems_post --emspost 2:primary:auxiliary\n\n".

                     "Specifying rules for multiple domains is done by separating individual rule groups with a comma. ".
                     "A default rule group may also be included by excluding the domain ID. This default will be applied ".
                     "to any domain for which post processing is turned ON but does not have its own rule group:\n\n".

                     "X02X% ems_post --emspost primary:auxiliary,2:auxiliary,3,4:primary\n\n".

                     "In the above ill-advised exmple, domains 2, 3, and 4 are included for post processing. ".
                     "The \"primary:auxiliary\" serves as the default rule group, which will be applied to processing ".
                     "of the domain 3 output files only since both domain 2 (auxiliary) and 4 (primary) have their ".
                     "own rules. In the absence of any rules, only the primary dataset will be processed.\n\n\n".

                     "A few additional comments:\n\n".

                     "X02X1. Order is not important, either within an individual rule group or among\n".
                     "X02X   groups in the argument list.\n\n".
                     "X02X2. Passing \"--emspost\" without an argument is the same as passing \"--emspost 0\"\n". 
                     "X02X   or not passing it at all.\n\n".
                     "X02X3. The \"primary\" dataset refers to the \"wrfout*\" simulation output files.\n\n".
                     "X02X4. The output frequency for the \"primary\" dataset is specified in the\n".
                     "X02X   run_wrfout.conf configuration file.\n\n".
                     "X02X5. The \"auxiliary\" dataset refers to the \"auxhist1*\" simulation output files.\n\n".
                     "X02X6. The output frequency for the \"auxiliary\" dataset is specified in the\n".
                     "X02X   run_auxhist.conf configuration file.\n\n".
                     "X02X7. When using the \"--emspost\" flag, the \"--auxhist\" and --wrfout\" flags\n". 
                     "X02X   are ignored.\n\n".
                     "X02X8. If the \"--domain\" flag is also passed, the domains will be merged with\n".
                     "X02X   \"--emspost\" and the default rules applied if necessary.\n\n";



       $help{ADDN} = 'The author is aware that some of the above information may be confusing or poorly worded.'; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_autoupp {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--autoupp';

       $help{WHAT} = 'Specify the machines and processors for running the UEMS UPP with AutoPost';

       $help{USE}  = '% ems_run --autoupp hostname1:NP,hostname2:NP,...,hostnameN:NP';


       $help{DESC} = "The \"--autoupp\" flag is specifies the machines and processors for use then running the ".
                     "UEMS UPP with Auto Post processing turned ON (\"--autopost\"). It serves to override the value ".
                     "of the EMSUPP_NODECPUS parameter in post_grib.conf.\n\n".

                     "If you want to know more about the \"--autoupp\" flag configuration, read the information about ". 
                     "the AUTOUPP_NODECPUS parameter in ems_autopost.conf, which is the same as EMSUPP_NODECPUS in ".
                     "post_grib.conf, only different.";
                     

       $help{ADDN} = 'Be careful of what you read on bathroom walls, some of it might actually be true.'; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_auxhist {
#==================================================================================
#  Routine provides guidance for the --auxhist flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--auxhist';

       $help{WHAT} = 'Requests the processing of auxiliary history files';

       $help{USE}  = '% ems_post --auxhist  [whatever suits your fancy, should you have a fancy in need of a suit]';

       $help{DESC} = "Passing \"--auxhist\" tells ems_post that you want to processes the auxiliary files output during ".
                     "the simulation. These files are activated when the user specifies an output frequency greater than ".
                     "0 (default; OFF) in run_auxhist.conf prior to running a simulation.";

       $help{ADDN} = 'The --auxhist flag - "Less talk and more action"';


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_info {
#==================================================================================
#  Routine provides guidance for the --info flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--info & --summary';

       $help{WHAT} = 'Print a summary of the post-processing tasks';

       $help{USE}  = '% ems_post --info | --summary  [other options, like you mean business]';

       $help{DESC} = "Passing \"--info\" causes ems_post to print a summary of the post-processing tasks ".
                     "to be completed and then exits without any processing actually done. Use this flag ".
                     "to check the final settings based upon input from the configuration files and any ".
                     "command-line flags passed. The flag gives you the opportunity to \"try it before you ".
                     "buy it\" with ems_post.\n\n".

                     "The \"--summary\" flag is similar to \"--info\", except that it continues with the ".
                     "data processing as described in the printed summary. You would use the \"--summary\" ".
                     "if you think you know what you are doing but want some reassurance.";

       $help{ADDN} = "\"Try it before you buy it\" is the best approach in life.";


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_noupp {
#==================================================================================
#  Routine provides guidance for the --noupp flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--noupp';

       $help{WHAT} = 'Turn off processing of netCDF to GRIB format via UEMS UPP';

       $help{USE}  = '% ems_post --noupp  [other options, but nothing stupid]';

       $help{DESC} = "Passing \"--noupp\" turns off the processing of netCDF files into GRIB 2 format. ".
                     "Use this flag if GRIB files have already been created, presumably during a ".
                     "previous running of ems_post, but you now want to create a dataset that is ".
                     "derived from GRIB such as GrADS or GEMPAK. If this is your intent, then be sure ".
                     "that the necessary GRIB files exist; otherwise, you should not be playing with ".
                     "this flag.";

       $help{ADDN} = '"A person with a new idea is a crank until the idea succeeds." - Mark Twain';


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_noexport {
#==================================================================================
#  Routine provides guidance for the --noexport flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--noexport';

       $help{WHAT} = 'Turn off the export of processed files to exotic destinations and workstations';

       $help{USE}  = '% ems_post --noexport  [type1,type2,...,typeN]  [other options]';

       $help{DESC} = "Passing \"--noexport <string>\" tells ems_post that you want to turn off the exporting of ".
                     "files that are otherwise scheduled for departure in post_export.conf. Including the ".
                     "\"type1,type2,..,typeN\" argument serves to selectively turn OFF exporting of specific file ".
                     "types identified by the EXPORT parameter in the configuration file. Each \"type\" must match a ".
                     "\"FILE TYPE\" defined as part of EXPORT string in the file.\n\nFor example,\n\n".

                     "X04X% ems_post --noexport  GRIB,BUFR    [other options]\n\n".

                     "will turn off the exporting of GRIB  and BUFR formatted files, whether they were schedule ".
                     "in the configuration file or not. The string should be carefully specified so as not to ".
                     "unintentionally turn off the exporting of files.\n\n".

                     "In the absence of an argument, passing \"--noexport\" will turn off the export of all data ".
                     "types listed in the configuration file, regardless of your intent.";

       $help{ADDN} = '"Thunder is good, thunder is impressive; but it is lightning that does the work." - Mark Twain';


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_gempak {
#==================================================================================
#  Routine provides guidance for the --gempak flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--[no]gempak';

       $help{WHAT} = 'Override the creation of GEMPAK files from GRIB 2 as defined in post_uems.conf';

       $help{USE}  = '% ems_post --gempak  ';

       $help{DESC} = "The UEMS includes a full installation of NAWIPS/GEMPAK display software for visualizing simulation ".
                     "output; however, the package is turned OFF by default in the etc/EMS.cshrc and EMS.profile files ".
                     "(EMS_NAWIPS) since many users already have NAWIPS installed on their system.\n\n".

                     "If you already have NAWIPS installed and just want to create GEMPAK files, then you do not need to ".
                     "activate the UEMS NAWIPS package on your system. The GRIB2 to GEMPAK conversion routines are handled ".
                     "by ems_post without the need for additional configuration.\n\nNow, back to the flag:\n\n".

                     "Passing \"--[no]gempak\" overrides the GEMPAK parameter setting in post_uems.conf. It should come ".
                     "as no surprise that passing \"--nogempak\" turns OFF the creation of GEMPAK files, while \"--gempak\" ".
                     "turns them ON with all processed files located in the emsprd/gempak/ directory.\n\n".

                     "Note that the --[no]gempak flag only serves to turn ON|OFF GEMPAK file processing. The frequency of ".
                     "of the GRIB files to be processed into gempak is controlled by the FREQ_WRF|AUX_GEMPAK  parameter in ".
                     "post_gempak.conf and the specified GRIB file processing.\n\n".

                     "Finally, the NAWIPS/GEMPAK package provided by the UEMS includes executables that were compiled for ".
                     "use with shared system libraries. This means that you may need to install libraries that were excluded ".
                     "when the Linux OS was installed. To determine whether you are missing a shared library, you can use ".
                     "the \"uems/util/nawips/bin/libcheck\" utility.";
                     

       $help{ADDN} = 'Sell your Goods and Services here!';


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_grads {
#==================================================================================
#  Routine provides guidance for the --grads flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--[no]grads';

       $help{WHAT} = 'Override the processing of GRIB2 into GrADS files as defined in post_uems.conf';

       $help{USE}  = '% ems_post --grads  ';

       $help{DESC} = "The UEMS includes a installation of the GrADS display software for visualizing simulation ".
                     "output, which is located under uems/util/. If you already have the GrADS installed ".
                     "and just want to create GrADS files, the ems_post routine will still use the UEMS installation ".
                     "for file processing, but you may use your own installation for viewing the data.\n\n".

                     "Passing \"--[no]grads\" overrides the GRADS parameter setting in post_uems.conf. It should come ".
                     "as no surprise that passing \"--nograds\" turns OFF the creation of GrADS files, while \"--grads\" ".
                     "turns them ON with all processed files located in the emsprd/grads/ directory provided everything ".
                     "went well, which it always does for the developer.\n\n".

                     "Note that the --[no]grads flag only serves to turn ON|OFF grads file processing. The frequency of ".
                     "of the GRIB files to be processed into GrADS is controlled by the FREQ_WRF|AUX_GRADS parameter in ".
                     "post_grads.conf and the specified GRIB file processing.";

       $help{ADDN} = 'The UEMS: Sell your Goods and Services here!';


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_gemsnd {
#==================================================================================
#  Routine provides guidance for the --gemsnd flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--[no]gemsnd';

       $help{WHAT} = 'Override the generation of GEMPAK sounding files as specified in post_bufr.conf';

       $help{USE}  = '% ems_post --[no]gemsnd [Advertise your goods & services here]';

       $help{DESC} = "Passing \"--[no]gemsnd\" overrides the generation of GEMPAK sounding files as specified in the post_bufr.conf file, ".
                     "just as you read above, but I want to make sure you are paying attention. Passing \"--gemsnd\" also turns ".
                     "on BUFR file processing whether you like it or not since the GEMPAK station files are created from BUFR. ".
                     "Conversely, passing \"--nogemsnd\" does not affect the processing of BUFR files.\n\n".

                     "After the smoke clears, all GEMPAK sounding files will be located in the \"emsprd/gemsnd/\" directory. If you ".
                     "want to export the files to other exotic locations, then check out the possibilities presented in the ".
                     "post_export.conf file. You'll be glad you did.";


       $help{ADDN} = 'That\'s just the way this thing works.';


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_wrfout {
#==================================================================================
#  Routine provides guidance for the --wrfout flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--wrfout';

       $help{WHAT} = 'Requests the processing of primary history (simulation output) files';

       $help{USE}  = '% ems_post --wrfout  [whatever suits your fancy, should you have a fancy in need of a suit]';

       $help{DESC} = "Passing \"--wrfout\" tells ems_post that you want to processes the primary netCDF files (wrfout*) output ".
                     "during the simulation. These files are activated when the user specifies an output frequency greater than ".
                     "0 (default; 60) in run_wrfout.conf prior to running a simulation.\n\n".

                     "Since ems_post defaults to processing of the primary output files if nothing else is passed, this flag ".
                     "only serves a purpose when combined with \"--auxhist\", in which case both file types will be processed.";

       $help{ADDN} = 'The --wrfout flag - "More talk than action"';


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_domain {
#==================================================================================
#  Routine provides guidance for the --domains flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--domain';

       $help{WHAT} = 'Specifies the domain number to be post processed';

       $help{USE}  = '% ems_post --domains  #,   Where # is the domain number 1(or not) ... N';

       $help{DESC} = "Passing the \"--domain\" flag specifies which domain output files to process with ems_post. ".
                     "By default, ems_post will process the data from domain 1, so if the primary domain is your main ".
                     "objective, then you do not need to include \"--domains 1\". However, if you have your eyes on a ".
                     "different prize (domain), you must include \"--domains #\", where \"#\" is the domain number to ".
                     "process.\n\n".
                   
                     "All simulation output files to be processed must be located in the \"wrfprd/\" directory prior ".
                     "to running ems_post or else all heck will break loose, and you will get an intimidating error ".
                     "message and a note to take home to your mother.";


       $help{ADDN} = 'The --domains flag is under appreciated, even by its own mother.';


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_index {
#==================================================================================
#  Routine provides guidance for the --index flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--index';

       $help{WHAT} = 'Helps the UEMS autopost routine keep track of which files to process';

       $help{USE}  = '% ems_post --index  #';

       $help{DESC} = "The \"--index\" is not intended for human consumption. It's used by the UEMS autopost routine to tell ".
                     "ems_post which simulation output files have already been processed. This information is necessary ".
                     "because ems_post's memory is failing (although better than the developer's) and autopost is the ".
                     "brains in this operation anyway.";

       $help{ADDN} = "Don't touch the --index flag unless you're looking for trouble!\nBesides, you're a modeler, not a fighter (nor a lover).";


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_rundir {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--rundir';

       $help{WHAT} = 'Set the simulation run-time directory if not current (.) directory';

       $help{USE}  = '% ems_post --rundir <simulation run-time directory>   [superior flags]';

       $help{DESC} = "Pass the \"--rundir\" flag to specify the run-time domain use for post-processing of the ". 
                     "simulation output files. It's primarily used by the ems_autorun routine and is of little value ".
                     "domain directory must exist or ems_post will terminate, and you don't want that to ".
                     "happen now do you?\n\n".

                     "Note: This flag is not intended to be passed by a user. It is used by ems_autorun internally.";
            
       $help{ADDN} = "Nobody at UEMS world headquarters uses \"--rundir\", and neither should you."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_scour {
#==================================================================================
#  Routine provides guidance for using the --[no]scour flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--[no]scour';

       $help{WHAT} = '[Do Not] Whack the emsprd directory prior to running ems_post';

       $help{USE}  = '% ems_post --[no]scour [more important stuff]';

       $help{DESC} = "By default, ems_post will do some selective pruning of files and directories beneath emsprd/ ".
                     "prior to processing model output. This includes deleting any log, error, and input files while ".
                     "retaining the final post-processed products from previous ems_post runs. However, any products ".
                     "scheduled for processing for the specified domain WILL be scoured prior to (re)creation.\n\n".

                     "Should you not care for this behavior, then passing \"--noscour\" will serve to keep everything ".
                     "intact under emsprd/. You might think \"--noscour\" is the perfect flag for you, but it actually ".
                     "serves a very limited purpose. For example, if you processed a subset of available simulation ".
                     "output into GRIB2 and then wanted to process the remaining files, the first batch of GRIB files ".
                     "will be deleted prior to the creation of any new files. This is true even when the files are not ".
                     "included in the second group. Note that this only applies to files of the same domain and file ".
                     "type (primary or auxiliary). All other files will be spared the wrath of the UEMS sanitation machine.\n\n".

                     "Passing \"--scour\" tells ems_post to perform a heavy handed \"cleansing\" of the emsprd/ directory, ".
                     "meaning that all the subdirectories are deleted prior to performing any new post-processing activities. ".
                     "You are more likely to use \"--scour\" than \"--noscour\", which is why it was created just for you.\n\n".
                     
                     "Finally, the exceptions to the above behaviors is when the UEMS autopost feature is ON or when also ".
                     "passing the \"--noupp\" flag, in which case NO scouring is done, i.e, same as \"--noscour\".";
                      
            
       $help{ADDN} = "You probably will not need this option, but it's there for taking."; 


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_afwa {
#==================================================================================
#  Routine provides guidance for the --afwa flag
#==================================================================================
#
    my %help = ();
    
       $help{FLAG} = '--afwa';

       $help{WHAT} = 'Currently nothing';

       $help{USE}  = '% ems_post --afwa [will get you nothing] ';

       $help{DESC} = "Passing the \"--afwa\" flag suggests that you did not take the above messages seriously.  The \"--afwa\" flag ".
                     "has not been activated in the current release because the AFWA code in the WRF needs to be rewritten to support ".
                     "parallel processing. So until somebody does something, the utility of the \"--afwa\" flag will remain just ".
                     "another playful fantasy in the mind of the UEMS developer.";

       $help{ADDN} = 'His mind is already crowded with too many fantasies.';


return &Ehelp::FormatHelpTopic(\%help);
}


sub PostHelp_notused {
#==================================================================================
#  Routine provides guidance for those flags that are of no use to the user.
#==================================================================================
#
    my %help = ();
    my $flag = shift;
    
       $help{FLAG} = "--$flag";

       $help{WHAT} = 'Flag from the land of misfit options & stuff';

       $help{USE}  = "% ems_post --$flag [don't even bother]";

       $help{DESC} = "Some flag are listed in the options module because they serve an internal purpose, such as ".
                     "being passed by ems_autorun or to maintain compatibility for legacy reasons. There ".
                     "isn't much to gain by attempting to pass one of these flags and more than likely you'll poke ".
                     "your own eye out.\n\n".

                     "So just don't do it.";
            
       $help{ADDN} = 'This message should have self-destructed 13.799 Billion years 36 days ago.'; 


return &Ehelp::FormatHelpTopic(\%help);
}


