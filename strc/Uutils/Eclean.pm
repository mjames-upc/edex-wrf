#!/usr/bin/perl
#===============================================================================
#
#
#         FILE:  Eclean.pm
#
#  DESCRIPTION:  Contains utilities used by the ems_clean routine to
#                clean/scour domain directories.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#
#===============================================================================
#
package Eclean;

require 5.008;
use strict;
use warnings;
use English;

use Cwd 'abs_path';

use vars qw (%Uclean $rc);

use Ecomm;
use Ecore;
use Eenv;
use Others;



sub CleanDriver {
#===============================================================================
#   The purpose of &CleanDriver is to execute each of the individual steps
#   involved in running ems_clean and return an error ($rc) should there be
#   a problem. Note that although the %Uclean is global within this module
#   it is passed between some subroutine in order to retain consistency with
#   other UEMS routines, and because I cut-n-paste a lot. 
#===============================================================================
#
    %Uclean = ();  #  Global
    @ARGV   = @_;

    #---------------------------------------------------------------------------
    #  Adding an unnecessary call for the sake of aesthetics. The &ReturnHandler
    #  routine is not really necessary other than to provide cover for otherwise
    #  ugly code.  The return code variable ($rc) and %Uclean are global within 
    #  this module.
    #---------------------------------------------------------------------------
    #
    return $rc if &ProcessReturnHandler(&CleanStart(\%Uclean));
    return $rc if &ProcessReturnHandler(&CleanProcess(\%Uclean));


return 0;
}



sub CleanStart {
#==================================================================================
#  This routine may not look like much, because it isn't, but it is the 
#  but it handles the initial configuration and and option processing for 
#  the ems_clean routine. It's to be called from &CleanDriver (or whatever it
#  may be called by now).
#==================================================================================
#
    my $upref = shift; %Uclean = %{$upref};  # %Uclean is actually global

    return 11 unless %Uclean   = &CleanInitialize(\%Uclean);
    return 12 unless %Uclean   = &ParseCleanOptions(\%Uclean);

 
return 0;
}


sub CleanProcess {
#==================================================================================
#  Takes care of the cleaning better than "Mr. Clean" because it's "Dr. Clean."
#  This routine will only return a value if the %Uclean hash is empty, in 
#  which case no file scouring will be done.
#==================================================================================
#
     my $upref  = shift; %Uclean = %{$upref};  return 21 unless  %Uclean;

   
    &Ecomm::PrintTerminal(1,4,256,0,1,"Running ems_clean level $Uclean{level} for the $Uclean{rtenv}{domname} domain") unless $Uclean{silent};

    #----------------------------------------------------------------------------------
    #  Every instance of ems_clean includes a scrubbing of the $UEMS/logs 
    #  directory to remove any lock files that may exist from previous
    #  simulations.  However, care must be taken so that a log file for a 
    #  simulation started on another system is not scoured.
    #----------------------------------------------------------------------------------
    #
    &CleanLogs();

    &CleanLevel0();   #  Everybody gets a 0 level scrub

    
    #----------------------------------------------------------------------------------
    #  Move through the levels of cleaning in succession from the least (0 - above)
    #  to the greatest (6). There is a bit of redundancy along the way but this 
    #  never hurt nobody before.
    #----------------------------------------------------------------------------------
    #
    &CleanLevel1() if $Uclean{level} > 0;
    &CleanLevel2() if $Uclean{level} > 1;
    &CleanLevel3() if $Uclean{level} > 2;
    &CleanLevel4() if $Uclean{level} > 3;
    &CleanLevelX() if $Uclean{level} > 4;


    #----------------------------------------------------------------------------------
    #  Recreate the links
    #----------------------------------------------------------------------------------
    #
    &CleanLinks();

    &Ecomm::PrintTerminal(1,4,256,1,1,"Squeaky clean! $Uclean{rtenv}{domname} has that \"new domain\" scent again.") unless $Uclean{silent};


return 0;
}


sub CleanInitialize {
#==================================================================================
#  Initialize the common hashes and variables used by ems_clean
#==================================================================================
#
    my $upref = shift; %Uclean = %{$upref};  #  %Uclean is global

    unless (defined $ENV{UEMS} and $ENV{UEMS} and -e $ENV{UEMS}) {
        print '\n\n    !  The UEMS environment is not properly set - EXIT\n\n';
        return ();
    }


    #----------------------------------------------------------------------------------
    #  Initialize $ENV{CMESG}, which used to be @{$ENV{UMESG}} but resulted
    #  in conflicts is another UEMS routine was running (See autopost.pl).
    #----------------------------------------------------------------------------------
    #
    $ENV{CMESG} = '';


    #  ----------------------------------------------------------------------------------
    #  Set default language to English because the UEMS attempts to match English
    #  words when attempting to get system information.
    #  ----------------------------------------------------------------------------------
    #
    $ENV{LC_ALL} = 'C';


    #----------------------------------------------------------------------------------
    #  Populate the %Uclean hash with the information about the system
    #----------------------------------------------------------------------------------
    #
    %{$Uclean{emsenv}}     = &Ecore::SysInitialize(\%Uclean);



    #----------------------------------------------------------------------------------
    #  Make the lower-level keys lower case. This is for no particular reason
    #  other than that's the way I like it, which is also the way I should have
    #  written it in the first place but didn't and I'm too lazy to change.
    #
    #  "Hey you kids, get off my simulated lawn!"
    #----------------------------------------------------------------------------------
    #
    foreach my $key (keys %{$Uclean{emsenv}}) { my $lk = lc $key;
        $Uclean{emsenv}{$lk} = $Uclean{emsenv}{$key}; delete $Uclean{emsenv}{$key};
    }


return %Uclean;
}


sub ParseCleanOptions {
#==================================================================================
#  The ParseCleanOptions routine parses the flags and options passed to
#  ems_clean from the command line or via a direct subroutine call.
#==================================================================================
#
use Getopt::Long qw(:config pass_through);
use Time::Local;

    my %Option = ();
    my $upref  = shift; %Uclean = %{$upref};  # %Uclean is actually global 


    GetOptions ( "h|help|?"  => sub {&CleanHelpMePlease(@ARGV)},   #  Just what the doctor ordered
                 "domain:s"  => \$Option{domain},
                 "level:s"   => \$Option{LEVEL},
                 "silent"    => \$Option{SILENT},
                 "match:s"   => \$Option{MATCH},
               );  #  &CleanHelpMePleaseError(@ARGV) if @ARGV;


    $Uclean{domain} = &Option_domain($Option{domain});
    $Uclean{level}  = &Option_level($Option{LEVEL});
    $Uclean{silent} = &Option_silent($Option{SILENT});
    $Uclean{match}  = &Option_match($Option{MATCH});


    #----------------------------------------------------------------------------------
    #  Prove the user with some well-deserved information. Note that this call is
    #  normally found in the &Initialize subroutine but it needs to reside here due
    #  to its dependence on $Uclean{silent}
    #----------------------------------------------------------------------------------
    #
    &Elove::Greeting('ems_clean',$Uclean{emsenv}{uemsver},$Uclean{emsenv}{sysinfo}{shost}) unless $Uclean{silent};

    return () if $ENV{CMESG};


    #  Best place for this call although I am not thrilled
    #
    return () unless %{$Uclean{rtenv}} = &Others::RuntimeEnvironment($Uclean{domain});

    $Uclean{level}  = 3 if $Uclean{rtenv}{bench} and $Uclean{level} > 3;


return %Uclean;
}



sub CleanLogs {
#==================================================================================
#  Every instance of ems_clean includes a scrubbing of the $UEMS/logs 
#  directory to remove any lock files that may exist from previous
#  simulations.  However, care must be taken so that a log file for a 
#  simulation started on another system is not scoured.
#==================================================================================
#

    foreach my $lock (&Others::FileMatch($ENV{EMS_LOGS},'uems_autorun.lock',0,1)) {

        my ($rpid, $rdir, $host, $ssecs) = (0,0,0,0);

        open (my $lfh, '<', $lock);  #  Open the lock file and begin the read
        while (<$lfh>) {
            s/^\s//g;
            next if /^#|^$|^\s+/;
            ($rpid, $rdir, $host, $ssecs) = split / +/ => $_;
        } close $lfh;

        $host = '' if &Others::isLocalHost($host);
    
        &Others::rm($lock) if $rdir eq $Uclean{rtenv}{domname} and ! &Others::isProcessRunning($rpid,$host);
    }


    foreach my $host (&Others::FileMatch($ENV{EMS_LOGS},'mpich2.hosts',0,1)) {
       my @list = split '\.' => $host;
       $list[2]+=0 if defined $list[2] and $list[2];
       &Others::rm($host) unless -e "/proc/$list[2]";
    } 

    #&Others::rm("$ENV{EMS_LOGS}/domain_wizard.log");  


return;
}


sub CleanLevel0 {
#==================================================================================
#  Clean level 0 is just a superficial "tarting up" of the domain directory
#  that includes removal of any foreign files or directories from the top
#  level.
#==================================================================================
#

    foreach (&Others::FileMatch($Uclean{rtenv}{dompath},'',1,1)) {
        &Others::rm("$Uclean{rtenv}{dompath}/$_") unless (/^wrfbdy_|^wrfinput_|^wrffdda_|^grib$|^static$|^conf$|^wpsprd$|^wrfprd$|^emsprd$|^rstprd$|^log$/);
    }

    foreach (&Others::FileMatch($Uclean{rtenv}{static},'',1,1)) {
        &Others::rm("$Uclean{rtenv}{static}/$_") if (/^geogrid|^mpich2_|^GEOGRID|^nest7grid/);
    }

    foreach (&Others::FileMatch($Uclean{rtenv}{logdir},'',1,1)) {
        &Others::rm("$Uclean{rtenv}{static}/$_") if (/^geogrid|^mpich2_/);
    }

    #------------------------------------------------------------------------------
    #  Search and delete dead links
    #------------------------------------------------------------------------------
    #
    system "find $Uclean{rtenv}{dompath} -type l ! -exec test -e {} \\; -exec rm {} \\; > /dev/null 2>&1";


return;
}


sub CleanLevel1 {
#==================================================================================
#  Clean level 1 takes level 0 a step further by scouring anything below
#  the emsprd directory and any post_ files below logs/.
#==================================================================================
#

    if ($Uclean{match}) {
        foreach my $dir (`find $Uclean{rtenv}{emsprd} -type d`) { chomp $dir;
            foreach (&Others::FileMatch($dir,$Uclean{match},0,1)) {&Others::rm($_);}
        }
    } else {
        foreach (&Others::FileMatch($Uclean{rtenv}{emsprd},'',0,1)) {&Others::rm($_);}
        foreach (`find $Uclean{rtenv}{emsprd} -type d`) { chomp; next if /emsprd$/; &Others::rm($_);}
    }

    foreach (&Others::FileMatch($Uclean{rtenv}{logdir},'^post_',0,1)) {&Others::rm($_);}

return;
}


sub CleanLevel2 {
#==================================================================================
#  Clean level 2 takes level 1 a step further by scouring anything below
#  the wrfprd directory and any run related files below logs/.
#==================================================================================
#

    foreach (&Others::FileMatch($Uclean{rtenv}{dompath},'',1,1)) {
        &Others::rm("$Uclean{rtenv}{dompath}/$_") if (/^wrfbdy_|^wrfinput_|^wrffdda_/);
    }

    foreach (&Others::FileMatch($Uclean{rtenv}{wrfprd},'',0,1)) {&Others::rm($_);}

    foreach (&Others::FileMatch($Uclean{rtenv}{logdir},'^mpich2_|^real|^wrfm|^rsl|^post|cnvrt',0,1)) {&Others::rm($_);}

return;
}


sub CleanLevel3 {
#==================================================================================
#  Clean level 3 takes level 2 a step further by scouring anything below
#  the wpsprd directory and all files below logs/.
#==================================================================================
#
    foreach (&Others::FileMatch($Uclean{rtenv}{wpsprd},'',0,1)) {&Others::rm($_);}
    foreach (&Others::FileMatch($Uclean{rtenv}{logdir},'',0,1)) {&Others::rm($_);}

return;
}


sub CleanLevel4 {
#==================================================================================
#  Clean level 4 takes level 3 a step further by scouring anything below
#  the grib/ directory.
#==================================================================================
#
    foreach (&Others::FileMatch($Uclean{rtenv}{grbdir},'',0,1)) {&Others::rm($_);}

return;
}


sub CleanLevelX {
#==================================================================================
#  Here we begin hitting the hard stuff. Clean level 5 is the same as running
#  ems_domain --refresh while level 6 does a localization and returns the 
#  configuration files back to the default.
#==================================================================================
#
    chdir $Uclean{rtenv}{dompath};

    if ($Uclean{level} == 5) {
        system "$ENV{STRC_BIN}/ems_domain --refresh";
    }

    if ($Uclean{level} == 6) {
        system "$ENV{STRC_BIN}/ems_domain --localize --restore";
    }

return;
}


sub CleanLinks {
#==================================================================================
#  Recreate the relative links to the UEMS run-time scripts 
#==================================================================================
#
use File::Spec;

    # Take Care of business (TCB)
    #
    my @routines = qw (ems_prep ems_run ems_autorun ems_post);

    chdir $Uclean{rtenv}{dompath};

    my $rp = File::Spec->abs2rel("$ENV{EMS_STRC}/Ubin");

    foreach (@routines) {
        &Others::rm("$Uclean{rtenv}{dompath}/$_");
        symlink "$rp/$_.pl" => $_;
    }

    if ($Uclean{bench}) {
        &Others::rm("$Uclean{rtenv}{dompath}/grib");
        symlink "../data" => "$Uclean{rtenv}{dompath}/grib";
    }

return;
}



sub Option_level {
#==================================================================================
#  Define the value for LEVEL, which defines the amount of scouring to be done
#  withing the domain directory. Values rangle from 0 through 6, although 5 & 6
#  should not be passed very often.  The default is level 0.
#==================================================================================
#
    my @levels = qw(0 1 2 3 4 5 6);
    my $passed = shift; $passed = 0 unless defined $passed;

    unless (grep /^$passed$/ => @levels) {
        my $mesg = 'I\'m not sure what you are thinking, but the valid clean levels range from '.
                   '0 .. 6, where 0 provides the least amount of cleaning and 6 the most. I '.
                   'suggest that you review the destructive capacity of each level by passing '.
                   'the \"--help\" flag before attempting this option again.';
        $ENV{CMESG} = &Ecomm::TextFormat(0,0,84,0,0,"Let's try this again, from the top:",$mesg);
        return 0;
    }

return $passed;
}


sub Option_match {
#==================================================================================
#  The --match option takes as an argument a string that is used to scour only
#  those files that contain that string. Although intended for use by the ems_post 
#  routine, users may attempt to harness its power for their own nefarious 
#  purposes. This option is only valid for clean levels 0 and 1.
#==================================================================================
#
    my $passed = shift; $passed = '' unless defined $passed and length $passed;

    $passed = '' if $Uclean{level} > 1;

return $passed;
}


sub Option_domain {
#==================================================================================
#  Define the value for --domain, which is the full path to the domain directory
#  that is being cleaned. The argument to --domain may be either the full path
#  to the run-time domain or the run-time directory name. If --domain is not
#  passed then assume current working directory.
#==================================================================================
#
use Cwd;

    my $mesg = qw{};
    my $CWD  = cwd(); chomp $CWD; $CWD = Cwd::realpath($CWD); #  Should not be necessary 

    my $passed = shift; $passed = $CWD unless defined $passed and $passed;


    #----------------------------------------------------------------------------------
    #  Check whether just the domain directory was passed - if so, append to
    #  $RUN_BASE
    #----------------------------------------------------------------------------------
    #
    my @list = split /\// => $passed; $passed = "$ENV{RUN_BASE}/$passed" unless $#list;
    
    $passed  = Cwd::realpath($passed);
   
    #----------------------------------------------------------------------------------
    #  Check whether the domain directory exists, which it should
    #----------------------------------------------------------------------------------
    #
    unless (-d $passed) {
        $mesg = "Hey - We've only just begun and you go and provide me with an invalid run-time directory:\n\n    --domain $passed\n\nLet's try this again";
        $ENV{CMESG} = &Ecomm::TextFormat(0,0,84,0,0,$mesg);
        return 0;
    }

    
    #---------------------------------------------------------------------------------------------
    #  Test the existence of a "statics/" directory below $passed.
    #---------------------------------------------------------------------------------------------
    #
    unless (-d "$passed/static") {
        $mesg = "The ems_clean utility must be run from a valid run-time domain directory and not $passed\n\nLet's try this again";
        $ENV{CMESG} = &Ecomm::TextFormat(0,0,84,0,0,$mesg);
        return 0;
    }


    #---------------------------------------------------------------------------------------------
    #  Check permissions
    #---------------------------------------------------------------------------------------------
    #
    unless (-w $passed) {
        $mesg = "Hey Big Shot - You do not have write permission on (--domain $passed)!";
        $ENV{CMESG} = &Ecomm::TextFormat(0,0,84,0,0,$mesg);
        return 0;
    }

    
return $passed;
}


sub Option_silent {
#==================================================================================
#  Specifies the value for --silent, which determines whether to print out a
#  summary of what is being scoured.  Typically, this flag is only passed when
#  ems_clean is called from within another program; otherwise, don't bother
#  using it.
#==================================================================================
#
    my $passed = shift; $passed = defined $passed ? 1 : 0;
       $passed = 1 unless $Uclean{emsenv}{exe} =~ /ems_clean/i;

return $passed;
}


sub CleanHelpMePlease {
#==================================================================================
#  Simply the help menu when --help is passed.
#==================================================================================
#
    # An abbreviated help menu when the user screws up or wants some help.
    #
    my $help = "The UEMS clean routine (V$Uclean{emsenv}{uemsver}) used for spiff'n up a UEMS domain directory\n\n".
               "  Usage:  $Uclean{emsenv}{exe} --level <0 1 2 3 4 5 6> [other less important stuff]\n\n".
               "  Where the list of available options consists of the following:\n\n".
               "      Flag   Argument    Description\n\n".
               "    --domain   DIR       The name of the domain directory that you wish to clean. Not\n".
               "                         necessary when running from with in an existing directory.\n\n".

               "    --match    STRING    Scour only those files that match STRING. Intend for use by the\n".
               "                         ems_post routine but users may also attempt to harness its power\n".
               "                         for more nefarious purposes. Not including a STRING will result \n".
               "                         in both you and the flag being ignored.\n\n".
               "                         This flag is only valid for for clean levels 0 and 1.\n\n".

               "    --level    LEVEL     Level of cleaning to be done <0 1 2 3 4 5 6> where:\n\n".
               "                 0       Just the lock and log files. Just lock and log baby!\n\n".

               "                 1       Return the run directory to a post ems_run state. Just like it\n".
               "                         looked after you ran the model and before ems_post.\n\n".

               "                 2       Return the run directory to a pre ems_run state. Just like it\n".
               "                         looked after running ems_prep.\n\n".

               "                 3       Return the run directory to a pre data download state. It WILL NOT\n".
               "                         scour files in the grib directory.\n\n".

               "                 4       Return the domain directory to a just created state AND scour\n".
               "                         all files in the grib directory.\n\n".

               "                 5       Return the domain directory to just created state AND scour\n".
               "                         all files in the grib directory AND restore the configuration\n".
               "                         to the default values.\n\n".

               "                 6       Kick\'n it up to the max baby! Do it just like 5 but also localize\n".
               "                         the domain cause you\'ve manually edited the static/namelist.wps\n".
               "                         file and you\'re itch\'n for some excitement.\n\n".

               "  Note that \"--level <0 1 2 3 4 5 6>\" is the only recommended option. Failure to pass \"--level\"\n".
               "  will result in a default value of 3 being used, i.e, \"--level 3\".\n\n".

               "  In the absence of the \"--domain\" flag, $Uclean{emsenv}{exe} will search the current working directory \n".
               "  for a valid domain configuration. If found, the cleaning will commence.";

    &Ecomm::PrintTerminal(0,4,256,1,1,$help);


&Ecore::SysExit(-4);
}


sub ProcessReturnHandler {
#=====================================================================================
#  This nice and important sounding routine does nothing other than to set the
#  global $rc variable, allowing for a more elegant flow to the calling subroutine.
#  That's all, just for the sake of aesthetics.
#=====================================================================================
#
    $rc = shift;
 
return $rc ? 1 : 0;
}



