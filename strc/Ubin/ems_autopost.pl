#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ems_autopost.pl
#
#  DESCRIPTION:  The ems_autopost.pl routine is intended to be used for post
#                processing simulation output files concurrent with the model
#                RUN, i.e., while the simulation is running. The routine is
#                initiated from ems_run.pl when the AUTOPOST option is set
#                when using ems_autopost. 
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
require 5.008;
use strict;
use warnings;
use English;

use Cwd 'abs_path';
use FindBin qw($RealBin);
use lib (abs_path("$RealBin/../Uutils"),abs_path("$RealBin/../Upost"));


use vars qw (%Apost $rc);

use Ecore;
use Eenv;
use Others;


#===============================================================================
#   So ems_autopost begins. Note that while the %Apost hash is passed into
#   the individual modules, it is global within a module. Any variables that
#   are required later on will be carried in this hash.
#===============================================================================
#
    #  Override interrupt handler - Use the local one since some of the local
    #  environment variables are needed for clean-up after the interrupt.
    #
    $SIG{INT} = \&Ecore::SysIntHandle;


    #  Make sure the UEMS environment is set
    #
    &Ecore::SysExit(53,$0) if &Eenv::SetEnvironment($ENV{UEMS});


    #---------------------------------------------------------------------------
    #  &Apost::ApostDriver is the primary user interface for running ems_run.
    #  The argument passed to &ApostDriver is a string of command line flags
    #  and arguments as defined in the user guide. The possible return values
    #  are:
    #
    #     0  - No problems
    #     53 - General Error
    #---------------------------------------------------------------------------
    #   
    &Ecore::SysExit(&ReturnHandler(&AutoPostManager(@ARGV),$0));


&Ecore::SysExit(0,$0);


sub AutoPostManager {
#==================================================================================
#  The AutoPostManager subroutine manages the running of ems_post from the 
#  system identified by AUTOPOST_HOST in ems_autopost.conf. At this point 
#  ems_autopost has been initiated on AUTOPOST_HOST and this subroutine is
#  the first one called and thus established the viability of the environment.
#==================================================================================
#

    %Apost = ();  #  Global
    @ARGV  = @_; @ARGV = ('--help') unless @ARGV;

    #---------------------------------------------------------------------------
    #  Adding an unnecessary call for the sake of aesthetics. The &ReturnHandler
    #  routine is not really necessary other than to provide cover for otherwise
    #  ugly code and to be consistent with other modules..  The return code 
    #  variable ($rc) and %Apost are global within this module.
    #---------------------------------------------------------------------------
    #
    return $rc if &ProcessReturnHandler(&AutoPostStart());
    return $rc if &ProcessReturnHandler(&AutoPostProcess());


return 0;
}



sub AutoPostStart {
#==================================================================================
#  This subroutine calls routines that perform the initial configuration for
#  ems_autorun prior to any real work being done. The responsibility of this 
#  routine is to:
#
#      1. Initialize the %Apost hash
#      2. Read and parse the user input options
#      3. Gather run-time domain configuration
#      4. Check for input and configuration issues
#
#  Note that the handling of the return is different here than with the other
#  routines as a return of the %Apost hash indicates success when an empty
#  hash means failure.
#==================================================================================
#
    return 51 unless %Apost = &AutoPostInitialize(\%Apost);
    return 51 unless %Apost = &AutoPostOptions(\%Apost);
    return 51 unless %Apost = &ApostFileConfiguration(\%Apost);

return 0;
}


sub AutoPostProcess {
#==================================================================================
#  This routine is the primary driver for the UEMS Autopost processor. Provided 
#  that the user has the proper configuration to run processes via ssh on the 
#  identified system, this routine will wait for simulation files to appear
#  in the top level of the specified run-time directory and then kick off 
#  ems_post.pl.
#
#  Upon completion, the routine will sleep for $Apost{await} number of seconds
#  before checking for new simulation output.
#
#  The routine will exit the primary loop once the simulation has completed, at
#  which time it will look for any unprocessed data files in the wrfprd directory.
#==================================================================================
#
use POSIX;
use Omain;

    #----------------------------------------------------------------------------------
    #  %Omesgs contains diagnostic messages should ems_post fail, which it will.
    #  return codes don't require additional blather (23 & 24).
    #----------------------------------------------------------------------------------
    #
    my %Omesgs     = ();

       $Omesgs{0}  = "The simulation output has been processed and delivered to you safely - We're a team!";
       $Omesgs{11} = 'A problem was encountered during ems_post initialization';
       $Omesgs{12} = 'There is a problem with the ems_post options';
       $Omesgs{13} = 'A problem was encountered during ems_post configuration';
       $Omesgs{21} = 'Well, at least this hurts you more than it hurts me!';



    #------------------------------------------------------------------------------
    #  Do an initial check for the PID on the simulation master host. If it fails
    #  then it is most likely a communication problem between the Autopost 
    #  and simulation system. Regardless, of the cause, terminate the Autopost.
    #------------------------------------------------------------------------------
    #
    sleep 10;  # Wait a few seconds to ensure everything is up and running.

    my ($master,$emspid) = split ':', $Apost{emspid}, 2;  #  Get the hostname and PID

    unless (&Others::isProcessRunning($emspid,$master)) {
        $ENV{APMESG} = &Ecomm::TextFormat(0,0,255,0,0,"Autopost: Unable to access process ID $emspid on $master - Exit");
        return 0;
    }
  
    #------------------------------------------------------------------------------
    #  Set the environment AUTOPOST variable
    #------------------------------------------------------------------------------
    #
    $ENV{AUTOPOST} = 1;


    #------------------------------------------------------------------------------
    #  Summarize what the Autopost will be doing
    #------------------------------------------------------------------------------
    #
    &Ecomm::PrintMessage(0,7,255,1,2,'Autopost: A Summary of Post-Processing Tasks:');
    &Ecomm::PrintMessage(0,10,255,0,2,&AutopostSummary(\%Apost));

    my @apdoms = sort {$a <=> $b} keys %{$Apost{domains}}; #  Get the list of domains to process

    #------------------------------------------------------------------------------
    #  Create a lock file with the current autopost process ID
    #------------------------------------------------------------------------------
    # 
    open my $lfh, '>', $Apost{aplock}; print $lfh "PID=$$"; close $lfh;

    
    #------------------------------------------------------------------------------
    #  Execute this script as long as the parent program (ems_run.pl) is running.
    #  This is accomplished by checking for the existence of the /proc/PID directory
    #  where PID is the process ID of ems_run.pl, which is passed to Autopost via
    #  the --pid flag.  
    #
    #  Additionally, the time required to complete a process loop ($psecs) is
    #  monitored so that if $psecs is greater than $Apost{await} (user defined),
    #  then 
    #------------------------------------------------------------------------------
    #
    my $l=0;
    my $psecs  = 0;  #  Time requires (s) for previous process
    my $dsecs  = 0;
    my $tsleep = $Apost{await};  #  Calculated amount of time to sleep between process
    my $incval = ceil (0.20*$Apost{await});
    my $alive  = 0;

    my @list=();
    while (my $ir = &Others::isProcessRunning($emspid,$master) or $alive) {

        $tsleep = 5 unless $ir; #  Wait 10 seconds before completing the final pass

        #  push @list, sprintf('          %-3s - %s',$l,"Processing took $psecs seconds Sleeping for $tsleep seconds") if $l;

        my $tstr = &Ecomm::FormatTimingString($psecs);
        &Ecomm::PrintMessage(0,7,255,1,2,"Autopost: Processing loop $l took $tstr - Sleeping $tsleep seconds before trying again") if $l and $ir;
        &Ecomm::PrintMessage(0,7,255,1,2,"Autopost: Processing loop $l took $tstr - Sleeping $tsleep seconds before making final pass") unless $ir;

        sleep $tsleep; $l++;

        #------------------------------------------------------------------------------
        #  If by chance the simulation completed while sleeping 
        #------------------------------------------------------------------------------
        #
        $ir    = &Others::isProcessRunning($emspid,$master);
        $psecs = time();

        my @rdyfls=();
        my %outfls=();


        #-------------------------------------------------------------------------
        #  Look for the existence of the "Ready" file that is used to indicate
        #  a file has been completely written to disk. Processing of any data
        #  files is determined by the %{$Apost{domains}} hash.
        #-------------------------------------------------------------------------
        #
        foreach (sort &Others::FileMatch($Apost{rundir},'Ready_d',1,1)) {

            push @rdyfls, "$Apost{rundir}/$_";

            if (/^(\w+)Ready_d(\d\d)_/i) {  next unless $1 and $2;
                (my $d=$2)+=0; 
                next unless grep {/^$d$/} keys %{$Apost{domains}};
                next unless grep {/^$1$/} @{$Apost{domains}{$d}};
                push @{$outfls{$d}{$1}}  => $_;
            }
        }
        foreach my $d (keys %outfls) {foreach my $f (keys %{$outfls{$d}}) {s/Ready//gi foreach @{$outfls{$d}{$f}};}}

        #-------------------------------------------------------------------------
        #  At this point @rdyfls contains All the "Ready" files, which can be 
        #  deleted, and %outfls contains the simulation output files to process.
        #-------------------------------------------------------------------------
        #

        #-------------------------------------------------------------------------
        #  While looping through the domains & datasets to process, if any, 
        #  determine the index value of the first dataset type file to process.
        #  The index (--index) is passed to ems_post and is used to determine
        #  the first file to process, thus ignoring those files that have 
        #  already been processed.
        #-------------------------------------------------------------------------
        #
        my $n=1;
        foreach my $d (sort {$a <=> $b} keys  %outfls) {  #  For each domain with files to process

            next unless keys %{$outfls{$d}};

            my $gtime  = gmtime();
            my @ftypes = reverse sort keys %{$outfls{$d}}; my $fstr = &Ecomm::JoinString(\@ftypes);
            &Ecomm::PrintMessage(0,7,255,$n,2,sprintf("Autopost: Started domain $d processing of %s files on %s UTC",$fstr,$gtime)); $n=2 if $n==1;

            foreach my $t (reverse sort keys %{$outfls{$d}}) {  #  For each file type requested

                my @pargs = ();

                #-------------------------------------------------------------------------
                #  We must begin each processing pass from the top level of the domain
                #  directory; otherwise, we end up attempting to run ems_post from
                #  emsprd/grib directory or something stupid like that.
                #-------------------------------------------------------------------------
                #
                chdir $Apost{rundir};

                #-------------------------------------------------------------------------
                #  Move the %outfls to be processed into the work directory (wrfprd/) 
                #-------------------------------------------------------------------------
                #
                system "mv -f $Apost{rundir}/$_ $Apost{rundir}/wrfprd/ > /dev/null 2>&1" foreach @{$outfls{$d}{$t}};

                #-------------------------------------------------------------------------
                #  Determine the index of the first file to process. It might be better
                #------------------------------------------------------------------------- 
                my @AllFiles = &Others::FileMatch("$Apost{rundir}/wrfprd",sprintf('%s_d%02d_',$t,$d),1,1);
                my $i = &Others::StringIndexMatchExact($outfls{$d}{$t}[0],@AllFiles);


                #-------------------------------------------------------------------------
                #  Specify the flags & arguments and run ems_post
                #-------------------------------------------------------------------------
                #
                push @pargs => "--rundir  $Apost{rundir}";
                push @pargs => "--domain $d";
                push @pargs => "--auxhist" if $t eq 'auxhist1';
                push @pargs => "--afwa"    if $t eq 'afwa';
                push @pargs => "--index $i";
                push @pargs => "--nodecpus $Apost{nodecpus}" if $Apost{nodecpus};
                push @pargs => "--autopost";
                push @pargs => "--autorun";

                @pargs = split / +/ => (join " " => @pargs);

                for ($rc = &Omain::ProcessDriver(@pargs)) {
                    my $omesg = (defined $ENV{OMESG} and $ENV{OMESG}) ? $ENV{OMESG} : '';
                    if ($rc) {&Ecomm::PrintMessage(6,10,255,1,2,$omesg||$Omesgs{$rc});return $rc};
                }

            } #  For each dataset type to process

            $gtime  = gmtime();
            &Ecomm::PrintMessage(0,7,255,1,1,sprintf("Autopost: Finished domain $d processing of %s files on %s UTC",$fstr,$gtime));

        }  #  For each domain with files to process
        &Others::rm(@rdyfls);


        #----------------------------------------------------------------------------------
        #  Determine whether there needs to be a change in the time between data processing
        #----------------------------------------------------------------------------------
        #
        $psecs  = time()-$psecs;
        $dsecs  = ($psecs < $incval)       ? ceil -0.50*$incval    : ceil 0.50*$psecs;
        $tsleep = $Apost{await} if $tsleep == 0;  # Safety
        $tsleep = ($psecs > $Apost{await}) ? 0  : ($tsleep > $psecs) ? $Apost{await}-$dsecs : $Apost{await};

        #----------------------------------------------------------------------------------
        #  The value of $alive will determine when to make the final loop following 
        #  the end of the simulation. It takes the affirmative value of &isProcessRunning 
        #  after the simulation has ended, thus ensuring a final pass.
        #----------------------------------------------------------------------------------
        #
        $alive = $ir;

    }  #  while isProcessRunning


    #print "$_\n" foreach @list;  # used for degugging of loop timing


return 0;
}


sub AutoPostInitialize {
#==================================================================================
#  Initialize (nothing really) the system hashes with information. This routine
#  is primarily here for consistency with the other run-time routines and 
#  to provide the greeting, which is important.
#==================================================================================
#
    my $upref    = shift;  %Apost  = %{$upref};


    unless (defined $ENV{UEMS} and $ENV{UEMS} and -e $ENV{UEMS}) {
        print '\n\n    !  The UEMS Autopost environment is not properly set - EXIT\n\n';
        return ();
    }


    #----------------------------------------------------------------------------------
    #  Initialize $ENV{APMESG}, which used to be @{$ENV{UMESG}} but resulted
    #  in conflicts is another UEMS routine was running (E.g, ems_autopost.pl).
    #----------------------------------------------------------------------------------
    #
    $ENV{APMESG} = '';

   
    #----------------------------------------------------------------------------------
    #  Populate %emsenv
    #----------------------------------------------------------------------------------
    #
    my %emsenv = ();
       %emsenv = &Ecore::SysInitialize(\%emsenv);


    #----------------------------------------------------------------------------------
    #  Provide the user with some well-deserved information
    #----------------------------------------------------------------------------------
    #
    &Elove::Greeting('UEMS AutoPost',$emsenv{UEMSVER},$emsenv{SYSINFO}{shost});


    #----------------------------------------------------------------------------------
    #  Finally, this subroutine serves a purpose by defining the names of
    #  the UEMS Autopost lock file. The path to the file will be appended
    #  in another subroutine (Options).
    #----------------------------------------------------------------------------------
    #  
    $Apost{aplock}   = '.uems_autopost.lock';
    $Apost{ahost}    = $emsenv{SYSINFO}{shost};


return %Apost;
}  


sub AutoPostOptions {
#==================================================================================
#  The GetApostOptions routine parses the flags and arguments passed down
#  from ems_run. Little error checking is done here since the flags should
#  be correct. - I hope.
#
#  Note that unlike in the other UEMS run-time scripts, this subroutine reads
#  and processes the arguments to ems_autorun.pl with very minimal error checking.
#==================================================================================
#
use Getopt::Long qw(:config pass_through);

    my %Option  = ();
    my $upref   = shift;  %Apost  = %{$upref};


    GetOptions ("h|help|?"           => sub {&ApostHelpMe()}, #  Just what the doctor ordered
                "debug"              => \$Option{DEBUG},      #  Turns on the debugging and prints out additional information
                "domains:s"          => \$Option{DOMAINS},    #  Specify the domains & datasets to be processed - was --autopost when passed to ems_run
                "rundir:s"           => \$Option{RUNDIR},     #  Specify the run-time directory to use
                "emspid:s"           => \$Option{EMSPID}      #  The hostname and process ID for the UEMS simulation
               ); 


    #  Note that the order is important for some but not others!
    #
    %{$Apost{domains}} =  &ApostOptionValue('domains'   ,$Option{DOMAINS}); 
      $Apost{debug}    =  &ApostOptionValue('debug'     ,$Option{DEBUG});
      $Apost{emspid}   =  &ApostOptionValue('emspid'    ,$Option{EMSPID});
      $Apost{rundir}   =  &ApostOptionValue('rundir'    ,$Option{RUNDIR});
      
    return () if $ENV{APMESG};


    $Apost{aplock}  = "$Apost{rundir}/$Apost{aplock}";


return %Apost; 
}


sub ApostOptionValue {
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



sub Option_debug {
#==================================================================================
#  Set the DEBUG flag, either ON (1) or OFF(0)
#==================================================================================
#
    my $passed = shift;

    $passed = (defined $passed and $passed) ? $passed : 0;

return $passed;
}


sub Option_domains {
#==================================================================================
#  Specifies the domains and dataset(s) to be processed. The argument to the 
#  --domains flag will be passed in from ems_autorun -> ems_run so most of the 
#  error checking will be completed outside of ems_autopost.
#==================================================================================
#
    my %domains = ();
    my $passed  = shift; $passed = '' unless defined $passed;

    $passed =~ s/aux\w+/auxhist1/g;
    $passed =~ s/wrf\w+/wrfout/g;
    $passed =~ s/afw\w+/afwa/g;


    #  Clean up the formatting of the string if passed.
    #
    foreach my $dom (split /,/ => $passed) {
        next unless ($dom =~ /^(\d+)/);
        my ($d, @types) = split /:/ => $dom; 
        @types = &Others::rmdups(@types);
        @types = ('wrfout') unless @types;
        @{$domains{$d}} = @types;
    }
    @{$domains{1}} = ('wrfout') unless %domains;


return %domains;
}


sub Option_emspid {
#==================================================================================
#  The process ID of UEMS simulation for which processing is to be done.
#  There should not be any issues with the incoming value but it will
#  be checked during configuration anyway.
#==================================================================================
#
use Enet;

    my $passed = shift;

    #------------------------------------------------------------------------------
    #  I lied, there is some error checking because I can't help it.
    #------------------------------------------------------------------------------
    #
    unless (defined $passed and $passed) {
        $passed = 0 unless defined $passed;
        $ENV{APMESG} = &Ecomm::TextFormat(0,0,88,0,0,'More from: "When Good Arguments Go Bad"',"Must include --emspid <master node>:<emspid>");
        return 0;
    }

    
    #------------------------------------------------------------------------------
    #  The emspid argument contains the simulation master node hostname and the 
    #  process ID separated by a colon. Split the argument and get both parts
    #  before we do additional error checking.
    #------------------------------------------------------------------------------
    #
    my ($master,$pid) = split /:/ => $passed;  $master = 'localhost' if ! defined $master or ! $master or $master =~ /^local/i;


    unless (defined $pid and $pid and &Others::isInteger($pid)) {
        $ENV{APMESG} = &Ecomm::TextFormat(0,0,88,0,0,'More from: "When Good Arguments Go Bad"',"The required PID is incorrect (--emspid $master:$passed)");
        return 0;
    }


    #------------------------------------------------------------------------------
    #  Check whether the PID is active. Note that although a PID might be active,
    #  on the system, it might not be the PID associated with the simulation.
    #------------------------------------------------------------------------------
    #
    unless (&Others::isProcessRunning($pid,$master)) {
        $ENV{APMESG} = &Ecomm::TextFormat(0,0,255,0,0,"UEMS Autopost: Simulation process ID $pid does not exist on master node $master");
        return 0
    }


return "$master:$pid";
}


sub ApostFileConfiguration {
# ==============================================================================================
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Collect the few configuration settings in ems_autopost.conf. Checks are made to ensure
#  the values are valid.
# ==============================================================================================
#
    my $aref  = shift; %Apost = %{$aref};
    my %parms = ();


    #----------------------------------------------------------------------------------
    #  Read the local configuration file , which are returned in the %Apost hash.
    #----------------------------------------------------------------------------------
    #
    my $autoconf = "$ENV{EMS_CONF}/ems_auto";

    return () unless -d $autoconf and -f "$autoconf/ems_autopost.conf";
    return () unless my %cparms = &Others::ReadConfigurationFile("$autoconf/ems_autopost.conf");
    foreach my $key (keys %cparms) {@{$parms{$key}} = split /,/, $cparms{$key}; foreach (@{$parms{$key}}) {$_+=0 if /^\d+$/;} }
    %cparms = %parms;



    #----------------------------------------------------------------------------------
    #  Now begin the process of checking the parameters for valid values. Each 
    #  parameter is checked for validity but are not crossed-checked with other
    #  parameters, which is done prior to the values being used. 
    #----------------------------------------------------------------------------------
    #
    my $cval  = qw{}; #  Config Value
    my $dval  = qw{};
    my @rvals = ();
    my @cvals = ();


    #============================================================================
    #  EMS_AUTOPOST: AUTOPOST_AWAIT - Wait between post processing attempts
    #============================================================================
    #
    $dval  = 60;
    $cval  = (defined $cparms{AUTOPOST_WAIT}[0] and $cparms{AUTOPOST_WAIT}[0]) ?  $cparms{AUTOPOST_WAIT}[0] : $dval;
    $cval  = $dval unless &Others::isInteger($cval) and $cval >= 60;

    $Apost{await}    = $cval;



    #============================================================================
    #  EMS_AUTOPOST: AUTOUPP_NODECPUS (UEMS; string)
    #============================================================================
    #
    my $local = 'local:NCPUS';

    @rvals  = ();
    @cvals  = defined  $cparms{AUTOUPP_NODECPUS}[0] ? @{$cparms{AUTOUPP_NODECPUS}} : ($local);
    @cvals  = ($local) unless @cvals;

    foreach (@cvals) {

        my $host = 'local';
        my $core = 'NCPUS';

        foreach my $val (split ':' => $_) {
            $host = $val     if &Enet::isHostname($val);
            $core = int $val if &Others::isNumber($val);
        }
        next unless $core;

        push @rvals => "${host}:${core}";
    }
    $Apost{autoupp} = @rvals ? join ',', @rvals : $local;



    #============================================================================
    #  EMS_AUTOPOST: AUTOPOST_VERBOSE
    #============================================================================
    #
    $dval  = 0;
    $cval  = (defined $cparms{AUTOPOST_VERBOSE}[0] and $cparms{AUTOPOST_VERBOSE}[0]) ?  $cparms{AUTOPOST_VERBOSE}[0] : $dval;
    for ($cval) {
        $_ = 0 if /^0/ or /^F/i or /^N/i;
        $_ = 1 if /^1/ or /^T/i or /^Y/i; 
        $_ = $dval unless $_ == 1 or $_ == 0;
    }
    $Apost{averb} = $cval;


return %Apost;
}


sub AutopostSummary {
#================================================================================
#  Provide the users a summary of the autopost processing to be completed. 
#================================================================================
#
    my $string   = '    D          P           A          F';
    my @summary  = ();

    my $uref = shift;  my %Apost = %{$uref};

    push @summary, '  Domain     Primary    Auxillary     AFWA';
    push @summary, '---------------------------------------------';
    foreach my $d (sort {$a <=> $b} keys  %{$Apost{domains}}) {  #  For each domain requested
        my $dd = sprintf '%02d', $d;
        (my $line = $string) =~ s/D/$dd/g;
        foreach (@{$Apost{domains}{$d}}) {
            $line =~ s/P/X/g if /^wrf/i;
            $line =~ s/F/X/g if /^afw/i;
            $line =~ s/A/X/g if /^aux/i;
        }
        $line =~ s/0|A|F|P/ /g;
        push @summary, $line;
    }

          
return join "\n", @summary;
}


sub Option_rundir {
#==================================================================================
#  The domain directory in which post processing will be conducted
#==================================================================================
#
    my $passed = shift;

    #------------------------------------------------------------------------------
    #  I lied, there is some error checking because I can't help it.
    #------------------------------------------------------------------------------
    #
    unless (defined $passed and $passed) {
        $ENV{APMESG} = &Ecomm::TextFormat(0,0,88,0,0,"More from: \"When Good Arguments Go Bad\":  --rundir was not passed");
        return 0;
    }

    $ENV{APMESG} = &Ecomm::TextFormat(0,0,88,0,0,"More from: \"When Good Arguments Go Bad\":  Domain $passed not found") unless -d $passed;
        

return $passed;
}


sub ApostHelpMe {
#==================================================================================
#  The PostHelpMe routine determines what to do when the --help flag is
#  passed with or without an argument. If arguments are passed then the 
#  PrintPostOptionHelp subroutine is called and never returns.
#==================================================================================
#
    &Ecomm::PrintTerminal(0,7,255,1,1,&ListApostOptions());

&Ecore::SysExit(-4); 
}


sub ListApostOptions  {
#=====================================================================================
#  This routine provides the basic structure for the ems_post help menu 
#  should  the "--help" option is passed or something goes terribly wrong.
#=====================================================================================
#

    my $mesg  = qw{};
    my @helps = ();

    my $exe = 'ems_autopost'; my $uce = uc $exe;

    my %opts = &DefineApostOptions();  #  Get options list

    push @helps => &Ecomm::TextFormat(0,0,114,0,1,"$uce USAGE:");
    push @helps => &Ecomm::TextFormat(4,0,144,1,1,"% $exe [--domains 1,..,N] [Other options]");

    push @helps => &Ecomm::TextFormat(0,0,124,2,1,"AVAILABLE OPTIONS - BECAUSE YOU ASKED NICELY AND I'M BEGINNING TO LIKE YOUR BLOODSHOT EYES");

    push @helps => &Ecomm::TextFormat(4,0,114,1,2,"Flag            Argument [optional]       Description");


    foreach my $opt (sort keys %opts) {
        push @helps => &Ecomm::TextFormat(4,0,256,0,1,sprintf("%-17s  %-18s  %-60s",$opt,$opts{$opt}{arg},$opts{$opt}{desc}));
    }


    push @helps => &Ecomm::TextFormat(0,0,114,2,1,"RUDIMENTARY GUIDANCE FOR $uce (Because you need it)");

    $mesg = "The ems_autopost routine is intended for post processing output files concurrent with the ".
            "simulation, i.e, while the simulation is running. The routine is initiated from ems_run when ".
            "AUTOPOST option is set in ems_autorun.conf or the --autopost flag is passed to ems_autorun.\n\n".

            "CAVEAT UTILITOR!\n\n".
 
            "It is strongly suggested that you not initiate autopost on the same system being used to ".
            "run a simulation. In most cases, doing so will result in a degradation in performance for ".
            "both the simulation and post processor. If you are thinking about using the autopost option, ".
            "and I know you are, it is imperative that an alternate system be used for this task and ".
            "follow the steps below:";

    push @helps => &Ecomm::TextFormat(2,2,88,1,2,$mesg);
 
    $mesg = "1. Find a Linux system with a minimum 8Gb of memory. The system should be running an x64 ".
            "Linux distribution similar to that on the primary (simulation) machine to avoid headaches. ".
            "And just remember, should anyone ask, tell them \"It fell off a truck.\"";

    push @helps => &Ecomm::TextFormat(2,5,88,1,1,$mesg);
 
    $mesg = "2. The UEMS must be available on the autopost machine and in the same directory path as that ".
            "on the primary system. The simplest way of doing this is to export the UEMS partition to the ".
            "autopost machine and create any necessary links.";

    push @helps => &Ecomm::TextFormat(2,5,88,1,1,$mesg);
 
    $mesg = "3. You will also need to create a user on the autopost machine with the same name, ID, and group, ".
            "as that on the primary system. You can also export the user's home directory to the autopost ".
            "machine is you don't want to manage individual home directories. The accounts must be the same ".
            "for permission purposes and to ensure all the environment variables are correctly set.";

    push @helps => &Ecomm::TextFormat(2,5,88,1,1,$mesg);
 
    $mesg = "4. If you choose to create a separate home directory on the autopost machine, then make sure the ".
            "UEMS environment variable is correctly set in the user's .cshrc or .bashrc file.";

    push @helps => &Ecomm::TextFormat(2,5,88,1,1,$mesg);
 
    $mesg = "5. Configure passwordless SSH back and forth (primary <--> autopost) between the two systems ".
            "for the UEMS user. One-way (primary --> autopost) is not sufficient as the autopost machine ".
            "must monitor the simulation system to determine when the run has completed. You can test whether ".
            "passwordless SSH is configured properly with the UEMS \"cnet\" utility:";

    push @helps => &Ecomm::TextFormat(2,5,88,1,1,$mesg);
 
    $mesg = "From the primary (simulation) system:\n\n".
 
            "X02X%  uems/strc/UEMSbin/cnet --v <autopost hostname>";

    push @helps => &Ecomm::TextFormat(7,7,255,1,1,$mesg);
 
    $mesg = "Followed by (again from the simulation machine):\n\n".
 
            "X02X%  ssh <autopost hostname>  uems/strc/UEMSbin/cnet --v  <primary hostname>";

    push @helps => &Ecomm::TextFormat(7,7,255,1,2,$mesg);
 
    $mesg = "6. If you are planning on exporting and of the post processed datasets such as GRIB, GrADS, ".
            "GEMPAK, BUFR, etc., via SCP (see post_exports.conf) then passwordless SSH must also be configured ".
            "between the autopost system and destination machine(s).";

    push @helps => &Ecomm::TextFormat(2,5,88,1,2,$mesg);
 
    $mesg = "So, lets face it, you have a lot of work to do!\n\n".
 
            "Should you experience any problems, the most likely cause is a firewall or SELinux configuration. ".
            "The recommended method of troubleshooting is to turn off both of these services until you get ".
            "AUTOPOST working, and then selectively turn them on again to diagnose the problem.";


    push @helps => &Ecomm::TextFormat(2,2,88,1,1,$mesg);


    push @helps => &Ecomm::TextFormat(0,0,114,2,2,"FOR ADDITIONAL HELP, LOVE, UNDERSTANDING, AND HAND HOLDING:");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"a. Read  - docs/uems/uemsguide/uemsguide_chapter11.pdf");
    push @helps => &Ecomm::TextFormat(2,0,114,0,1,"Or");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"b. http://strc.comet.ucar.edu/software/uems");
    push @helps => &Ecomm::TextFormat(2,0,114,0,1,"Or");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"c. % $exe --help <topic> For a more detailed explanation of each option (--<topic>)");
    push @helps => &Ecomm::TextFormat(2,0,114,0,1,"Or");
    push @helps => &Ecomm::TextFormat(6,0,114,0,1,"d. % $exe --help  For this menu again");

    my $help = join '' => @helps;


return $help;
}


sub DefineApostOptions {
#==================================================================================
#  This routine defined the list of options that can be passed to the program
#  and returns them as a hash.
#==================================================================================
#
    my %opts = (
                '--debug'       => { arg => ''            , help => '&ApostHelp_debug'     , desc => 'Turn ON debugging statements (If any exist)'},
                '--domains'     => { arg => 'DOMAIN #'    , help => '&ApostHelp_domain'    , desc => 'Specify the domain to be processed (Default is domain 1)'},
                '--rundir'      => { arg => 'DIR'         , help => '&ApostHelp_rundir'    , desc => 'Set the simulation run-time directory if not current working directory'},
                '--emspid'      => { arg => 'PID'         , help => '&ApostHelp_emspid'    , desc => 'The master node and process ID for the UEMS simulation'}
                );

return %opts;
}


sub ReturnHandler {
#==================================================================================
#  The purpose of this routine is to interpret the return codes from the 
#  ems_autopost routine. It's somewhat irrelevant since all that is of concern
#  is success or failure. It returns 53 upon failure or 0 for success.
#==================================================================================
#
    my $date = gmtime();
    my $rc   = shift;

    my $umesg = (defined $ENV{APMESG} and $ENV{APMESG}) ? $ENV{APMESG} : '';

    $rc ?  &Ecomm::PrintMessage(9,7,255,1,1,$umesg || 'UEMS Autopost FAILED - Processing migrated to UEMS Post')
        :  &Ecomm::PrintMessage(2,7,255,1,1,sprintf("UEMS Autopost successfully completed on %s at %s UTC",$Apost{ahost},$date));

    &Others::rm($Apost{aplock});  #  No other location for this task

return $rc ? 53 : 0;
}


sub ProcessReturnHandler {
#==================================================================================
#  This nice and important sounding routine does nothing other than to set the
#  global $rc variable, allowing for a more elegant flow to the calling subroutine.
#  That's all, just for the sake of aesthetics.
#==================================================================================
#
    $rc = shift;

return $rc ? 1 : 0;
}


