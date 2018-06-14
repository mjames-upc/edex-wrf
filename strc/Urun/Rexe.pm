#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Rexe.pm
#
#  DESCRIPTION:  Rexe contains each of the primary routines used for the
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Rexe;

use warnings;
use strict;
require 5.008;
use English;



sub ProcessNodesCores {
#==================================================================================
#  The ProcessNodesCores manages the configuration & testing of the nodes 
#  to be included in the simulation along with establishing the decomposition
#  for each run-time domain. For the WRF ARW core this step is completed
#  for both the "real" and model executables.
#==================================================================================
#
use List::Util qw( min max );

    my %Config = ();

    my $href = shift; my %Urun = %{$href};

    my %dinfo = %{$Urun{dinfo}};
    my %dmpar = %{$Urun{emsrun}{dmpar}};  # Note: %dmpar is a hash of single value arrays
    
    foreach my $proc (sort keys %{$dmpar{process}}) {

        %{$Config{$proc}} = ();


        #----------------------------------------------------------------------------------
        #  Step 1. Reconcile the requested nodes, number of processors to be used,
        #          network interface, and whether the UEMS resides on the remote
        #          systems.
        #----------------------------------------------------------------------------------
        #          
        
        &Ecomm::PrintMessage(1,11+$Urun{arf},255,1,1,sprintf("Gathering system information for running %s",$proc eq 'wrfm' ?'WRF ARW':'WRF REAL'));

        return () unless %{$Config{$proc}} = &Rutils::InitNodesCores(@{$dmpar{process}{$proc}{nodecpus}});


        #----------------------------------------------------------------------------------
        #  Step 2. Determine the domain decomposition to be used.  Normally this should
        #          simply default to the value of DECOMP but in some cases the user 
        #          requested value may not be appropriate. Only DECOMP = 1 is used for 
        #          running WRF REAL.
        #----------------------------------------------------------------------------------
        #
        my $decomp = ($proc eq 'real') ? 1 : $dmpar{decomp}[0];

        #  If DECOMP = 2 then make sure the values for decomp_x|y are appropriate 
        #
        if ($decomp == 2) {$decomp = 1 unless $dmpar{decomp_x}[0]*$dmpar{decomp_x}[0] == $Config{$proc}{totalcpus};}


        #----------------------------------------------------------------------------------
        #  Step 3. Handle the decomposition of the computational domains using the 
        #          user configuration values for DECOMP, DECOMP_X, DECOMP_Y, wtc.
        #
        #          If decomp = 0 - Use WRF internal decomposition
        #          If decomp = 1 - Use UEMS decomposition method
        #          If decomp = 2 - Use user defined values for decomp_x & decomp_y
        #----------------------------------------------------------------------------------
        #
        if ($decomp == 0) {return () unless %{$Config{$proc}} = &Rutils::DomainDecomp0(\%{$Config{$proc}});}
        if ($decomp == 1) {return () unless %{$Config{$proc}} = &Rutils::DomainDecomp1($proc,\%dinfo,\%{$Config{$proc}});}
        if ($decomp == 2) {return () unless %{$Config{$proc}} = &Rutils::DomainDecomp2($dmpar{decomp_x}[0],$dmpar{decomp_y}[0],\%{$Config{$proc}});}


        #----------------------------------------------------------------------------------
        #  Step 4.  For now just assign the value of NUMTILES to each process hash.
        #----------------------------------------------------------------------------------
        #
        $Config{$proc}{numtiles} = $dmpar{numtiles}[0];


    }
    %{$Urun{processes}} = %Config;
    

return %Urun;
}  #  ProcessNodesCores



sub ProcessControl_REAL {
#==================================================================================
#  The ProcessControl_REAL manages the configuration & testing of the nodes 
#  to be included in the running of the WRF REAL program, along with with 
#  establishing the decomposition for each run-time domain.
#==================================================================================
#
use Rutils;

    my $mesg = qw{};
    my $href = shift; my %Urun = %{$href};

    my $arf  = $Urun{arf};

    $Urun{rc}= 0;  #  Used by ems_autorun.pl but needs to be assigned if --nowrfm is passed

    #----------------------------------------------------------------------------------
    #  Populate the %process hash to be passed into &Empi::ConfigureProcessMPI
    #----------------------------------------------------------------------------------
    #
    my %Process = ();

    unless (%Process = &ProcessInit('real',\%Urun)) {
        &Ecomm::PrintMessage(6,11+$arf,255,1,2,'Error during WRF REAL initialization');
        return ();
    }

    $Process{autorun} ? &Ecomm::PrintMessage(0,7,144,2,1,$Process{headermsg}) : &Ecomm::PrintMessage(0,4,144,2,1,$Process{headermsg});


    #----------------------------------------------------------------------------------
    #  Collect the output from &Empi::ConfigureProcessMPI, check for errors and then
    #  run the MPI routine.
    #----------------------------------------------------------------------------------
    #
    my %mpirun  = &Empi::ConfigureProcessMPI(\%Process);

    if ($Process{mpidbg}) {
        foreach (keys %mpirun) {next if $_ eq 'nodes'; &Ecomm::PrintMessage(4,13+$arf,255,1,0,sprintf("MPIRUN - %-12s = %s",$_,$mpirun{$_}));}
    }

    if ($mpirun{error}) {
        &Ecomm::PrintMessage(6,11+$arf,255,1,2,'Error during MPI configuration:',$mpirun{error});
        return ();
    }

    if ($mpirun{error} = &Empi::WriteHostsFile(\%{$mpirun{nodes}},\$mpirun{hostsfile}) )  {
        &Ecomm::PrintMessage(6,11+$arf,94,1,2,'Error during writing of MPI hosts file:', $mpirun{error});
        return ();
    }


    #----------------------------------------------------------------------------------
    #  Prepare the domain directory for running the process. This includes scouring
    #  any unnecessary files, preparing ant writing the namelist file, and creating 
    #  links to initialization files.  The &ProcessPrep routine returns a list of
    #  files to be deleted from the run-time directory upon successful completion
    #  of the process, which in this case is WRF REAL.
    #----------------------------------------------------------------------------------
    #
    return () unless my @delfls = &ProcessPrep(\%Process);


    #----------------------------------------------------------------------------------
    #  Provide some information to the user regarding the time step, file output
    #  type and frequency, and maybe some other stuff too.
    #----------------------------------------------------------------------------------
    #
    &ProcessInfo(\%Process);

    
    #----------------------------------------------------------------------------------
    #  If the user passed --debug real|wrfm then it's time to shut down and allow
    #  their hands to get dirty.
    #----------------------------------------------------------------------------------
    #
    if ($ENV{RUN_DBG} == -10) {
        &Ecomm::PrintTerminal(4,11,256,2,2,"The table is set for you. Now try running:\n\n  % $mpirun{mpiexec}");
        &Ecore::SysExit(98);
    }


    #----------------------------------------------------------------------------------
    #  All appears normal - time to run the requested process 
    #----------------------------------------------------------------------------------
    #
    &Ecomm::PrintMessage(1,11+$arf,144,2,0,$Process{procmsg});  

    my $secs = time(); # Get the start time of the run
    if (my $err = &Ecore::SysExecute($mpirun{mpiexec},$Process{logfile})) {

        #  If the user passed a Control-C (^C) then simply clean up the mess
        #  that was made and exit
        #
        &Rutils::ProcessInterrupt('real',2,$Process{dompath},\@delfls,\@{$Urun{emsrun}{outfiles}}) if $err == 2;

       
        #  Otherwise, the failue has to be investigated
        #
        &Ecomm::PrintMessage(0,0,24,0,1,"Failed ($err)!");

        if (-s $Process{errlog} and open my $mfh, '<', $Process{errlog}) {
            my @lines = <$mfh>; close $mfh; foreach (@lines) {chomp $_; s/^\s+//g;} 
            &ErrorHelper($Process{errlog},$arf,$err,@lines) if @lines;
        }

        my @cats=(); push @cats, $Process{rsllog} if -s $Process{rsllog}; push @cats, $Process{errlog} if -s $Process{errlog};
        system "cat -s @cats > $Process{logfile}" if @cats;

        &Rutils::ProcessInterrupt('real',$err,$Process{dompath},\@delfls,\@{$Urun{emsrun}{outfiles}});


        my @tarfiles = ('log');
        foreach my $f ('namelist.wps', 'namelist.real', 'namelist.wrfm', 'uems_system.info', 'uems_benchmark.info') {push @tarfiles, "static/$f" if -e "static/$f";}
        &Others::PackageLogFiles($Process{dompath},'real',@tarfiles);


        return ();  #  Return an empty hash for failed simulation

    }

    
    #----------------------------------------------------------------------------------
    #  Although the system might not have thrown an error we still need to
    #  check for the existence of the "SUCCESS"  in the log file and whether
    #  the expected output files exist.
    #----------------------------------------------------------------------------------
    #
    sleep 2;  #  Wait for all information to finish writing, although I don't know how long to wait.

    my $err = &Rutils::Check4Success($Process{rsllog}) ? 0 : 1;

    my @initfls = &Others::FileMatch($Process{dompath},'wrfinput_',1,1);
    my @bndyfls = &Others::FileMatch($Process{dompath},'wrfbdy_',1,1);
    my @fddafls = &Others::FileMatch($Process{dompath},'wrffdda_',1,1);


    unless ($Process{global}) {$err = 1 unless @bndyfls;}
    if ($Process{nudge})      {$err = 1 unless @fddafls;}

    $err = 1 unless @initfls;

    if ($err) {
        &Ecomm::PrintMessage(0,0,24,0,1,'Failed for reasons unknown');
        &Ecomm::PrintMessage(0,11+$arf,94,1,1,'I hate when this #%^!\#!!% happens.  Hopefully nobody lost an eye!');
        system "cat -s $Process{rsllog} $Process{errlog} > $Process{logfile}";
        &Rutils::ProcessInterrupt('real',1,$Process{dompath},\@delfls,\@{$Urun{emsrun}{outfiles}});
        return ();
    }

    system "mv $Process{rsllog} $Process{logfile} > /dev/null 2>&1";
    
    &Ecomm::PrintMessage(0,0,32,0,1,"Success! Let's do it again!");
    &Ecomm::PrintMessage(0,14+$arf,144,1,1,sprintf("Initial and boundary condition files created in %s",&Ecomm::FormatTimingString(time()-$secs)));
    &Ecomm::PrintMessage(0,9+$arf,144,1,1,"Moving on to bigger and better delusions of grandeur \xe2\x98\xba");

    &Rutils::ProcessCleanup('real',$Process{dompath},\@delfls,\@{$Urun{emsrun}{outfiles}});


return %Urun;
} 



sub ProcessControl_WRFM {
#==================================================================================
#  The ProcessControl_WRFM manages the configuration & testing of the nodes 
#  to be included in the simulation along with establishing the decomposition
#  for each run-time domain. 
#==================================================================================
#
use Rutils;
use Apost;

    my $mesg = qw{};
    my $href = shift; my %Urun = %{$href};

    my $arf  = $Urun{arf};

    #----------------------------------------------------------------------------------
    #  Populate the %process hash to be passed into &Empi::ConfigureProcessMPI
    #----------------------------------------------------------------------------------
    #
    my %Process = ();

    unless (%Process = &ProcessInit('wrfm',\%Urun)) {
        &Ecomm::PrintMessage(6,11+$arf,255,1,2,'Error during WRF ARW initialization');
        return ();
    }

    $Process{autorun} ? &Ecomm::PrintMessage(0,7,144,2,1,$Process{headermsg}) : &Ecomm::PrintMessage(0,4,144,2,1,$Process{headermsg});


    #----------------------------------------------------------------------------------
    #  Collect the output from &Empi::ConfigureProcessMPI, check for errors and then
    #  run the MPI routine.
    #----------------------------------------------------------------------------------
    #
    my %mpirun  = &Empi::ConfigureProcessMPI(\%Process);

    if ($Process{mpidbg}) {
        foreach (keys %mpirun) {next if $_ eq 'nodes'; &Ecomm::PrintMessage(4,13+$arf,255,1,0,sprintf("MPIRUN - %-12s = %s",$_,$mpirun{$_}));}
    }

    if ($mpirun{error}) {
        &Ecomm::PrintMessage(6,11+$arf,255,1,2,'Error during MPI configuration:',$mpirun{error});
        return ();
    }

    if ($mpirun{error} = &Empi::WriteHostsFile(\%{$mpirun{nodes}},\$mpirun{hostsfile}) )  {
        &Ecomm::PrintMessage(6,11+$arf,94,1,2,'Error during writing of MPI hosts file:', $mpirun{error});
        return ();
    }

    #----------------------------------------------------------------------------------
    #  Prepare the domain directory for running the process. This includes scouring
    #  any unnecessary files, preparing ant writing the namelist file, and creating 
    #  links to initialization files.  The &ProcessPrep routine returns a list of
    #  files to be deleted from the run-time directory upon successful completion
    #  of the process, which in this case is WRF ARW core.
    #----------------------------------------------------------------------------------
    #
    return () unless my @delfls = &ProcessPrep(\%Process);


    #----------------------------------------------------------------------------------
    #  Provide some information to the user regarding the time step, file output
    #  type and frequency, and maybe some other stuff.
    #----------------------------------------------------------------------------------
    #
    &ProcessInfo(\%Process);

        
    #----------------------------------------------------------------------------------
    #  If the user passed --debug real|wrfm then it's time to shut down and allow
    #  their hands to get dirty.
    #----------------------------------------------------------------------------------
    #
    if ( $ENV{RUN_DBG} == -11 ) {
        &Ecomm::PrintTerminal(4,11,256,2,2,"The table is set for you. Now try running:\n\n  % $mpirun{mpiexec}");
        &Ecore::SysExit(98);
    }



    #----------------------------------------------------------------------------------
    #  Initiate the simulation
    #----------------------------------------------------------------------------------
    #
    my $pid   = qw{};
    my $secs  = time();
    my $err   = 0;
    my $rc    = 0;   #  Return code from the process - Not reliable with waitpid

    #----------------------------------------------------------------------------------
    #  If UEMS Autopost has been requested, test the viability of the communication 
    #  between the two systems.
    #----------------------------------------------------------------------------------
    #
    my $astat = $Urun{apost}{autopost} ? &Apost::AutopostCommunications(\%{$Urun{apost}}) : 0;  $Urun{apost}{autopost} = 0 if $astat; #  The return status of the autopost routine

    if ($pid = fork) {

        #----------------------------------------------------------------------------------
        #  If requested, launch ems_autopost.pl on the designated system. Note that
        #  autopost needs the PID of the simulation and not that of ems_run.
        #----------------------------------------------------------------------------------
        #
        &Apost::AutopostLaunch($pid,\%{$Urun{apost}}) if $Urun{apost}{autopost};


    } else {

        #----------------------------------------------------------------------------------
        #  If the UEMS AutoPost option has been turned ON, we need to wait for it to 
        #  start (or fail), which it will.  This test is not built into the AutoPost
        #  routines because it does not return in time for the information to be
        #  useful.  Note that the returned $appid value (autopost process ID) can not
        #  be seen outside of this statement branch which is why it's not returned.
        #----------------------------------------------------------------------------------
        #
        &Apost::AutopostActive(\%{$Urun{apost}})  if $Urun{apost}{autopost};


        #----------------------------------------------------------------------------------
        #  All appears normal - time to run the requested simulation
        #----------------------------------------------------------------------------------
        #
        &Ecomm::PrintMessage(1,11+$arf,144,2,0,$Process{procmsg});  

        exec "$mpirun{mpiexec} > $Process{logfile}  2>&1";
    }


    #----------------------------------------------------------------------------------
    #  The $rc variable contains the system status but it may not indicate whether a run 
    #  was successful so we also have to check the log file file the SUCCESS statement.
    #  Also, the return code from waitpid will most likely be the PID.
    #----------------------------------------------------------------------------------
    #
    my $we = waitpid($pid,0); $rc = $? >> 8; $we = 0 if $we == $pid; $secs=time()-$secs; &Ecomm::PrintMessage(0,1,1,1,0," ");


    #----------------------------------------------------------------------------------
    #  A failed (or interrupted) simulation will will result in an error code being 
    #  provided by the variables $ENV{EMSERR}, $we, or $rc, or by interrogating the 
    #  log file. If an error did occur then attempt to provide some additional info
    #  before returning an empty hash.
    #----------------------------------------------------------------------------------
    #
    sleep 2; #  Make sure the log files are completed

    if ($err = $ENV{EMSERR} || $we || $rc || &Others::Ret10to01(&Rutils::Check4Success($Process{rsllog}))) {

        if ($err == 2) { #  We have a ^C situation
            #----------------------------------------------------------------------------------
            #  If the user passed a Control-C (^C) then simply clean up the mess that was 
            #  made and exit.
            #----------------------------------------------------------------------------------
            #
            &Apost::TerminateAutopost(\%{$Urun{apost}}) if $Urun{apost}{autopost};  #  If ON
            &Rutils::ProcessInterrupt('wrfm',2,$Process{dompath},\@delfls,\@{$Urun{emsrun}{outfiles}});
        }

        &Ecomm::PrintMessage(9,11+$arf,144,1,2,'Your simulation has failed! I hate when this #%^!\#!!% happens.');

        if (-s $Process{logfile} and open my $mfh, '<', $Process{logfile}) {
            my @lines = <$mfh>; close $mfh; foreach (@lines) {chomp $_; s/^\s+//g;} 
            &ErrorHelper($Process{logfile},$arf,$err,@lines) if @lines;
        }

        my @cats=(); push @cats, $Process{rsllog} if -s $Process{rsllog}; push @cats, $Process{errlog} if -s $Process{errlog};
        system "cat -s @cats > $Process{logfile}" if @cats;

        &Rutils::ProcessInterrupt('wrfm',$err,$Process{dompath},\@delfls,\@{$Urun{emsrun}{outfiles}});

        #----------------------------------------------------------------------------------
        #  If this is part of a autorun job then tar up the log files
        #----------------------------------------------------------------------------------
        #
        if ($Process{autorun}) {
            my @tarfiles = ('log');
            foreach my $f ('namelist.wps', 'namelist.real', 'namelist.wrfm', 'uems_system.info', 'uems_benchmark.info') {push @tarfiles, "static/$f" if -e "static/$f";}
            &Others::PackageLogFiles($Process{dompath},'wrfm',@tarfiles);
        }

        &Ecomm::PrintMessage(0,9+$arf,144,1,2,"\"That simulation didn't go quite as planned, George\"");

        return ();  #  Return an empty hash for failed simulation
    }



    #==================================================================================
    #  SUCCESS! At this point it is assumed the simulation was successful. Initially
    #  set the $Urun{rc} variable to $astat. The $Urun{rc} variables is used by 
    #  the ems_autorun.pl routine to monitor the status of the Autopost processor.
    #==================================================================================
    #
    $Urun{rc} = $astat;

    system "mv $Process{rsllog} $Process{logfile} > /dev/null 2>&1";
    

    #----------------------------------------------------------------------------------
    #  If the UEMS AutoPost processor was initiated, then make sure it has completed
    #  before continuing.  There often is a delay while ems_post is making a last 
    #  processing loop with any remaining files.
    #----------------------------------------------------------------------------------
    #
    if ($Urun{apost}{autopost}) {

        #----------------------------------------------------------------------------------
        #  If the UEMS AutoPost is not running then assume it failed and post process
        #  the requested datasets with ems_post afterwards.
        #----------------------------------------------------------------------------------
        #
        if (&Apost::isAutopostRunning($Urun{apost}{aplock},$Urun{apost}{ahost})) {

            my $twait = 1800; 
            my $wait  = $twait;
            &Ecomm::PrintMessage(1,11+$arf,144,1,0,"Waiting for UEMS Autopost to finish its business:");

            while ($wait and &Apost::isAutopostRunning($Urun{apost}{aplock},$Urun{apost}{ahost})) {
                &Ecomm::PrintMessage(0,1,1,0,0,&Ecomm::GetFunCharacter()); sleep 10; $wait-=10;
            }

            if ($wait and &Rutils::Check4Success($Urun{apost}{aplog})) {  #  UEMS Autopost has completed
                &Ecomm::PrintMessage(0,1,1,0,1," - Completed");
            } else {
                $wait  = $twait - $wait;
                &Ecomm::PrintMessage(0,14+$arf,144,2,1,"UEMS Autopost failed to successfully finish after $wait seconds (Terminating)");
                &Apost::TerminateAutopost(\%{$Urun{apost}});
                $Urun{apost}{autopost} = 0;
                $Urun{rc} = 53;
            }

        } else {
            $Urun{rc} = 53;
            $Urun{apost}{autopost} = 0;
        }
    }
    

    #----------------------------------------------------------------------------------
    #  Provide a summary of the system and simulation information for the user
    #----------------------------------------------------------------------------------
    #
    if (my $summary = &SimulationSummary(\%Process)) {

        if (open my $lfh, '>', $Process{syslog})  {
            &Ecomm::PrintFile($lfh,1,11+$arf,144,1,1,'Just because it\'s all about you:');
            &Ecomm::PrintFile($lfh,0,14+$arf,144,1,2,$summary);
            &Ecomm::PrintFile($lfh,2,11+$arf,144,1,2,sprintf('%simulation accomplished in %s',$Process{bench} ? 'Benchmark s' : 'S',&Ecomm::FormatTimingString($secs)));
            close $lfh;
        }
        

        #----------------------------------------------------------------------------------
        #  If this is a benchmark run then also print information to the screen
        #----------------------------------------------------------------------------------
        #
        if ($Process{bench}) {
            &Ecomm::PrintTerminal(1,11+$arf,144,1,1,'Just because it\'s all about you:');
            &Ecomm::PrintTerminal(0,14+$arf,144,1,2,$summary);
        }

    }
    &Ecomm::PrintMessage(2,11+$arf,144,1,2,sprintf('%simulation accomplished in %s',$Process{bench} ? 'Benchmark s' : 'S',&Ecomm::FormatTimingString($secs)));

    &Rutils::ProcessCleanup('wrfm',$Process{dompath},\@delfls,\@{$Urun{emsrun}{outfiles}});


return %Urun;
}  


sub ProcessInit {
#==================================================================================
#  Here we hide all the "sausage making" that is part of the running a simulation
#  with the UEMS. This routine manages a number of simple tasks and the setting
#  of values related to running either WRF REAL or the WRF ARW core.
#==================================================================================
#
use Storable 'dclone';

    my %Process = ();

    my @insp = ('with inspired determination', 'with self-confidence', 'with conviction', 'with dedication', 'with single-mindedness',
                'with spunk', 'with fearlessness', 'with tenacity', 'with blind faith', 'with courage', 'with true grit',
                'with a sense of purpose', 'like I mean business', 'with unbridled enthusiasm', 'like I know what I\'m doing',
                'like I\'m the "Little Engine that Could"', 'with vim and vigor');

    my @acts = ('sing along to', 'tap dance to', 'pantomime to', 'play air piccolo to');


    my ($proc, $href) = @_; my %Urun = %{$href};

    my $exec = 'PROC_CORE.exe';
       $exec =~ s/PROC/$proc/g;
       $exec =~ s/CORE/$Urun{rtenv}{core}/g;
       $exec = lc $exec;  #  Because $Urun{dinfo}{core} is in upper case 


    #---------------------------------------------------------------------------------
    #  Manage and namelist-related configurations, assignment, and updates
    #---------------------------------------------------------------------------------
    #
    my %namelist = %{ dclone(\%{$Urun{emsrun}{namelist}}) }; #  Create local namelist  because some values must be modified

    @{$namelist{domains}{nproc_x}}  = ($Urun{processes}{$proc}{nproc_x});
    @{$namelist{domains}{nproc_y}}  = ($Urun{processes}{$proc}{nproc_y});
    @{$namelist{domains}{numtiles}} = ($Urun{processes}{$proc}{numtiles});


    #---------------------------------------------------------------------------------
    #  If running WRF REAL over a global domain, set the start and end date/times
    #  to the same value; otherwise the routine will fail looking for BC update
    #  files from WPS.  Additionally, special considerations need to be made for
    #  nudge simulations.
    #---------------------------------------------------------------------------------
    #
    if ($Urun{rtenv}{global}) {

        if ($proc eq 'real') {
            @{$namelist{time_control}{end_year}}   = @{$namelist{time_control}{start_year}};
            @{$namelist{time_control}{end_month}}  = @{$namelist{time_control}{start_month}};
            @{$namelist{time_control}{end_day}}    = @{$namelist{time_control}{start_day}};
            @{$namelist{time_control}{end_hour}}   = @{$namelist{time_control}{start_hour}};
            @{$namelist{time_control}{end_minute}} = @{$namelist{time_control}{start_minute}};
            @{$namelist{time_control}{end_second}} = @{$namelist{time_control}{start_second}};
        }

    }
    %{$Process{namelist}} = %namelist;


    #----------------------------------------------------------------------------------
    #  Set the variables that will be passed back via the %Process hash. These 
    #  values will be used throughout this module.
    #----------------------------------------------------------------------------------
    #
    
    #  The process name, either 'real' or 'wrfm'
    #
    $Process{process}      = $proc;
    $Process{dompath}      = $Urun{rtenv}{dompath};

    $Process{nlfile}       = ($proc eq 'real') ? $Urun{rtenv}{reanl} : $Urun{rtenv}{wrfnl}; $Process{nlfile} = &Others::popitlev($Process{nlfile},1);
    $Process{nldefs}       = "$ENV{EMS_DATA}/tables/wrf/uems/namelist.arw";  # May need to be moved in the future

    %{$Process{nodes}}     = %{$Urun{processes}{$proc}{nodes}};
    @{$Process{nodeorder}} = @{$Urun{processes}{$proc}{nodeorder}};
    $Process{totalcpus}    = $Urun{processes}{$proc}{totalcpus};

    $Process{nproc_x}      = $Urun{processes}{$proc}{nproc_x};
    $Process{nproc_y}      = $Urun{processes}{$proc}{nproc_y};   
    $Process{numtiles}     = $Urun{processes}{$proc}{numtiles};

    %{$Process{domains}}   = %{$Urun{dinfo}{domains}};

    %{$Process{wpsfls}}    = ($proc eq 'real') ? %{$Urun{rtenv}{wpsfls}} : ();


    if ($proc eq 'wrfm') {
        my @missing = ();
        my @rundoms = sort {$a <=> $b} keys %{$Process{domains}};

        foreach my $d (@rundoms) {
            push @missing => $d unless &Others::FileMatchDomain($Process{dompath},'^wrfinput_',1,$d,0);
        }

        if (@missing) {
            my $rdoms = &Ecomm::JoinString(\@rundoms);
            my $mdoms = &Ecomm::JoinString(\@missing);
            my $mesg = "I know you're excited to get started. So am I! But we have to take care of a few details ".
                       "before the action commences, such as creating the initial and boundary condition files for ".
                       "domains $mdoms, because they appear to be missing!";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,84,0,0,"Let's try this again, from the top:",$mesg);
            return ();
        }
    }

    @{$Process{phytbls}} = @{$Urun{emsrun}{tables}{physics}};

    #----------------------------------------------------------------------------------
    #  Save some information about the master (this) node, which may be needed if
    #  the user does not include the master in a process. Note - currently not
    #  being used but keep if needed later.
    #----------------------------------------------------------------------------------
    # 
    $Process{master}{hostname}    = $Urun{emsenv}{sysinfo}{nhost};
    $Process{master}{total_cores} = $Urun{emsenv}{sysinfo}{total_cores};

    foreach my $key (keys %{$Urun{emsenv}{sysinfo}{ifaces}}) {
        next unless $Urun{emsenv}{sysinfo}{ifaces}{$key}{STATE};
        $Process{master}{ifaces}{$key}{$key}{addr} = $Urun{emsenv}{sysinfo}{ifaces}{$key}{ADDR};
        $Process{master}{ifaces}{$key}{$key}{host} = $Urun{emsenv}{sysinfo}{ifaces}{$key}{HOST};
    }



    #  It this a benchmark simulation?
    #
    $Process{bench}     =  $Urun{rtenv}{bench};
    $Process{global}    =  $Urun{rtenv}{global};
    $Process{autorun}   =  $Urun{emsenv}{autorun};
    $Process{nudge}     =  $Urun{flags}{nudge};
    $Process{core}      =  $Urun{rtenv}{core};
    $Process{arf}       =  $Urun{arf};

    #  Define the various log files
    #
    $Process{rsllog}    = 'rsl.out.0000';
    $Process{errlog}    = 'rsl.error.0000';
    $Process{syslog}    = $Process{bench} ? "$Urun{rtenv}{static}/uems_benchmark.info" : "$Urun{rtenv}{static}/uems_system.info";
    $Process{logfile}   = "$Urun{rtenv}{logdir}/run_${proc}.log"; &Others::rm($Process{logfile});

    #  Related to process execution
    #
    $Process{mpiexe}    = "$ENV{EMS_BIN}/$exec";
    $Process{hostpath}  = $Urun{rtenv}{logdir};
    $Process{nogforker} = (grep {/^localhost$/} @{$Process{nodeorder}}) ? 0 : 1;
    $Process{mpidbg}    = 0;


    #------------------------------------------------------------------------------------
    #  Specify the information to be printed to the screen while the process is running.
    #------------------------------------------------------------------------------------
    #
    my @doms = sort {$a <=> $b} keys %{$Process{domains}};
    my $dstr = &Ecomm::JoinString(\@doms);

    if ($proc eq 'real') {
        $Process{headermsg} = $Process{global}  ? sprintf("%-4s Creating initial conditions for global simulation",&Ecomm::GetRN($ENV{RRN}++))
                            : $Process{autorun} ? sprintf("%-4s AutoRun: Creating initial and boundary condition files for domain%s %s",&Ecomm::GetRN($ENV{RRN}++),$#doms ? 's' : '',$dstr)
                            : $Process{bench}   ? sprintf("%-4s Benchmark: Creating initial and boundary condition files for domain%s %s",&Ecomm::GetRN($ENV{RRN}++),$#doms ? 's' : '',$dstr)
                                                : sprintf("%-4s Creating initial and boundary condition files for domain%s %s",&Ecomm::GetRN($ENV{RRN}++),$#doms ? 's' : '',$dstr);

    } else {
        $Process{headermsg} = $Process{autorun} ? sprintf("%-4s AutoRun: Running WRF %s while thinking happy thoughts",&Ecomm::GetRN($ENV{RRN}++),$Process{core})
                            : $Process{bench}   ? sprintf("%-4s Benchmark: Running WRF %s while thinking happy thoughts",&Ecomm::GetRN($ENV{RRN}++),$Process{core})
                                                : sprintf("%-4s Running WRF %s while thinking happy thoughts",&Ecomm::GetRN($ENV{RRN}++),$Process{core});
    }


    if ($proc eq 'real') {
        $Process{procmsg} = $Process{global} ? 'WRF global initial conditions file creation' : 'WRF initial and boundary condition file creation';
        $Process{procmsg} = $Process{nudge}  ? "$Process{procmsg} (with gridded fdda) - "    : "$Process{procmsg} - ";
    } else {
        my $purp = $insp[int rand @insp];
        my $act  = $acts[int rand @acts];
        my $what = $Process{bench} ? 'the benchmark' : 'your';
           
        $Process{procmsg} = "Running $what simulation $purp!\n\n".
                            "You can $act the progress of the simulation while watching:\n\n".
                            "X02X%  tail -f $Process{dompath}/$Process{rsllog}\n\n".
                            "Unless you have something better to do with your time.\n";
    }


return %Process;
}  


sub ProcessPrep {
#==================================================================================
#  This routine managed the final steps in preparing the run-time domain
#  directory for running either WRF real or the ARW core. These steps include 
#  writing out the namelist file, creating links to any tables and data files
#  used by the physics schemes, and then deleting any extraneous files.
#==================================================================================
#
    my @delete = ();

    my $pref = shift; my %Process = %{$pref};


    #----------------------------------------------------------------------------------
    #  At this point, the namelist has been populated so write out a wrfm_runinfo.txt 
    #  file. If the user passed the --runinfo flag then also print the information to
    #  the screen and exit. This task is placed here because if the --runinfo flag
    #  was passed there is no reason to go further.
    #----------------------------------------------------------------------------------
    #
    #my $runinfo = &CollectRunInformation(\%Process{namelist}});


    #----------------------------------------------------------------------------------
    #  Step 1. Write the namelist file to the /static directory and make a link from 
    #          the run-time directory (namelist.input) to the file. 
    #----------------------------------------------------------------------------------
    #
    if (&Others::Hash2Namelist($Process{nlfile},$Process{nldefs},%{$Process{namelist}})) {
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,84,0,0,'The Hash2Namelist routine',"BUMMER: Problem writing $Process{nlfile}");
        return ();
    }
    
    &Others::rm('namelist.input'); symlink $Process{nlfile} => 'namelist.input'; push @delete => 'namelist.input';


    #----------------------------------------------------------------------------------
    #  Step 2. If running WRF REAL, create links to the WPS files in the wpsprd/
    #          directory.  We only want to create links to the domains included 
    #          in the simulation.
    #----------------------------------------------------------------------------------
    #
    if (%{$Process{wpsfls}}) {
        foreach my $d (sort {$a <=> $b} keys %{$Process{domains}}) {
            foreach my $f (@{$Process{wpsfls}{$d}}) {symlink "wpsprd/$f" => $f; push @delete => $f;}
        }
    }


    #----------------------------------------------------------------------------------
    #  Step 3. Create links to the tables required by the physics schemes selected
    #          for the simulation.
    #----------------------------------------------------------------------------------
    #
    foreach my $pt (@{$Process{phytbls}}) {
        my $l = &Others::popit($pt);
        symlink $pt  => $l;
        push @delete => $l;
    }


    #----------------------------------------------------------------------------------
    #  Step 4.  Delete any existing rsl.* files
    #----------------------------------------------------------------------------------
    #
    &Others::rm($_) foreach &Others::FileMatch($Process{dompath},'^rsl\.',1,1);


    #----------------------------------------------------------------------------------
    #  Step 5.  Delete any existing Ready_ files
    #----------------------------------------------------------------------------------
    #
    &Others::rm($_) foreach &Others::FileMatch($Process{dompath},'Ready_',1,1);



return @delete;
} 



sub ProcessInfo {
#==================================================================================
#  This routine prints out basic run-time information regarding the time step,
#  simulation output files type(s) and frequency, DFI information (if used),
#  and nudging info (if used).
#==================================================================================
#
use List::Util qw( min max );

    my $pref = shift;  my %Process = %{$pref};

    my $arf  = $Process{arf};


    #----------------------------------------------------------------------------------
    #  Provide summary of the machines and number of cores to be used 
    #----------------------------------------------------------------------------------
    #          
    &Ecomm::PrintMessage(1,11+$arf,94,1,2,sprintf("The %s is being run on the following nodes and cores:",$Process{process}=~/real/?'WRF REAL':'WRF ARW core'));

    &Ecomm::PrintMessage(0,11+$arf,94,0,1,'=' x 60) if $ENV{RUN_DBG} > 0;
    foreach (@{$Process{nodeorder}}) {
        $ENV{RUN_DBG} > 0 ? &Ecomm::PrintMessage(4,11+$arf,255,0,0,&Ecomm::NodeSummary($_, \%{$Process{nodes}{$_}}))
                          : &Ecomm::PrintMessage(0,14+$arf,255,0,1,&Ecomm::NodeCoresSummary(16,$Process{numtiles},\%{$Process{nodes}{$_}}));
    }
    &Ecomm::PrintMessage(0,11+$arf,94,0,1,'=' x 60) if $ENV{RUN_DBG} > 0;


    #----------------------------------------------------------------------------------
    #  Provide a summary of the time step use as well as the file output types and 
    #  frequencies.
    #----------------------------------------------------------------------------------
    #
    if ($Process{process} eq 'wrfm') {

        #  Write out time step information
        #
        my $timestep = $Process{namelist}{domains}{time_step}[0] + $Process{namelist}{domains}{time_step_fract_num}[0]/$Process{namelist}{domains}{time_step_fract_den}[0];
        my $mesg = ($Process{namelist}{domains}{use_adaptive_time_step}[0] eq 'T') ? 'The adaptive time step method will be used for this simulation'
                                                                                   : "A large time step of $timestep seconds will be used for this simulation";
        &Ecomm::PrintMessage(1,11+$arf,144,2,1,$mesg);


        #  Write out WRF output file frequency information
        #
        $mesg    = 'Output Frequency    Primary wrfout';
        $mesg    = $mesg.'    Aux Output ' if max @{$Process{namelist}{time_control}{auxhist1_interval}};
        $mesg    = $mesg.'    AFWA Output' if max @{$Process{namelist}{time_control}{auxhist2_interval}};

        my $len  = length $mesg; $len+=2; $len = 56 if $len < 56;

        &Ecomm::PrintMessage(1,11+$arf,94,2,1,$mesg);
        &Ecomm::PrintMessage(0,14+$arf,255,0,1,'-' x $len);


        my @freqouts = map { $_ ?  sprintf('%-16s', &Ecomm::FormatTimingString($_*60.)) : '   Off' } @{$Process{namelist}{time_control}{history_interval}};
        my @freqauxs = map { $_ ?  sprintf('%-16s', &Ecomm::FormatTimingString($_*60.)) : '   Off' } @{$Process{namelist}{time_control}{auxhist1_interval}};
        my @freqafws = map { $_ ?  sprintf('%-16s', &Ecomm::FormatTimingString($_*60.)) : '   Off' } @{$Process{namelist}{time_control}{auxhist2_interval}};


        foreach my $d (sort {$a <=> $b} keys %{$Process{domains}}) {
            $mesg = sprintf("Domain %02s      :   %-16s",$d,$freqouts[$d-1]);
            $mesg = $mesg.sprintf("%-16s",$freqauxs[$d-1]) if max @{$Process{namelist}{time_control}{auxhist1_interval}};
            $mesg = $mesg.sprintf("%-16s",$freqafws[$d-1]) if max @{$Process{namelist}{time_control}{auxhist2_interval}};
            &Ecomm::PrintMessage(0,17+$arf,94,0,1,$mesg);
        }
        &Ecomm::PrintMessage(0,14+$arf,255,0,1,'-' x $len);

        #  Is Digital Filter Initialization ON? If yes, then let the user know
        #
        if ($Process{namelist}{dfi_control}{dfi_opt}[0]) {

            my @dfiops = ('None', 'DF Launch', 'Diabatic DFI', 'Twice DFI');
            my @filter = ('Uniform', 'Lanczos', 'Hamming', 'Blackman', 'Kaiser', 'Potter',
                          'Dolph Window', 'Dolph', 'Rec High-Order');

            &Ecomm::PrintMessage(1,11+$arf,94,2,1,'DFI Option      Filter                          Window');
            &Ecomm::PrintMessage(0,14+$arf,255,0,1,'-' x 74);

            my $opt = sprintf("%-15s",$dfiops[$Process{namelist}{dfi_control}{dfi_opt}[0]]);
            my $typ = sprintf("%-13s",$filter[$Process{namelist}{dfi_control}{dfi_nfilter}[0]]);


            #  Need to reformat the  dfi_fwd|bckstop string values into date string for printing
            #
            my ($yy, $mm, $dd, $hr, $mn, $ss) = (0) x 6;
            $yy = $Process{namelist}{dfi_control}{dfi_fwdstop_year}[0];
            $mm = $Process{namelist}{dfi_control}{dfi_fwdstop_month}[0];
            $dd = $Process{namelist}{dfi_control}{dfi_fwdstop_day}[0];
            $hr = $Process{namelist}{dfi_control}{dfi_fwdstop_hour}[0];
            $mn = $Process{namelist}{dfi_control}{dfi_fwdstop_minute}[0];
            $ss = $Process{namelist}{dfi_control}{dfi_fwdstop_second}[0];

            my $fwdstop = &Others::DateString2DateStringWRF("$yy$mm$dd$hr$mn$ss");


            $yy = $Process{namelist}{dfi_control}{dfi_bckstop_year}[0];
            $mm = $Process{namelist}{dfi_control}{dfi_bckstop_month}[0];
            $dd = $Process{namelist}{dfi_control}{dfi_bckstop_day}[0];
            $hr = $Process{namelist}{dfi_control}{dfi_bckstop_hour}[0];
            $mn = $Process{namelist}{dfi_control}{dfi_bckstop_minute}[0];
            $ss = $Process{namelist}{dfi_control}{dfi_bckstop_second}[0];

            my $bckstop = &Others::DateString2DateStringWRF("$yy$mm$dd$hr$mn$ss");

            &Ecomm::PrintMessage(0,14+$arf,255,0,2,"$opt $typ $bckstop to $fwdstop");

        }


        #---------------------------------------------------------------------------------- 
        #  If FDDA nudging was turned ON
        #----------------------------------------------------------------------------------
        #
        if ($Process{namelist}{fdda}{grid_fdda}[0]) {

            my $meth = ($Process{namelist}{fdda}{grid_fdda}[0] == 1) ? '3D Analysis' : 'Spectral';
            &Ecomm::PrintMessage(1,11+$arf,255,2,1,"FDDA $meth Nudging Start and End Times:");
            &Ecomm::PrintMessage(0,16+$arf,255,1,1,'Domain       Start Time             End Time');
            &Ecomm::PrintMessage(0,14+$arf,255,0,1,'-' x 56);

            foreach my $d (sort {$a <=> $b} keys %{$Process{domains}}) {

                my $sdate = $Process{domains}{$d}{sdate};
                my $edate = $sdate;  #  Temporary, unless it isn't

                if ($Process{namelist}{fdda}{grid_fdda}[$d-1]) {
                    $edate = &Others::DateString2DateStringWRF(&Others::CalculateNewDate(&Others::DateStringWRF2DateString($sdate),$Process{namelist}{fdda}{gfdda_end_h}[$d-1]*3600.));
                }
                &Ecomm::PrintMessage(0,18+$arf,255,0,1, $sdate eq $edate ? sprintf('%02d      %s  Nudging Off',$d,$meth) : sprintf('%02d      %s    %s',$d,$sdate,$edate));
            }
            &Ecomm::PrintMessage(0,14+$arf,255,0,2,'-' x 56);
        }

    }  #  End of information summary for $Process{process} eq 'wrfm'


return;
}



sub SimulationSummary {
#==================================================================================
#  Collect and format system information for output to the screen and file
#  following a benchmark simulation run.
#==================================================================================
#   
    my @sinfo = ();
    my @pinfo = ();
    my @hinfo = ();

    my $pref  = shift;  my %proc = %{$pref};  return '' unless %proc;
  
    my @sorted = sort {length($a) <=> length($b)} @{$proc{nodeorder}};  my $lh = length $sorted[0];

    push @hinfo => ' ';
    push @hinfo => sprintf('A summary of nodes and processors used for the%s simulation:',$proc{bench} ? ' benchmark' : '');
    push @hinfo => ' ';

    foreach my $n (@{$proc{nodeorder}}) {
        my %sysinfo = &Others::SystemInformationHost($proc{nodes}{$n}{hostname},$proc{nodes}{$n}{localhost});
        push @sinfo => &Ecomm::FormatSystemInformationShort(\%sysinfo) if %sysinfo;
        push @pinfo => sprintf ("  %-2s Processors on %-${lh}s",$proc{nodes}{$n}{usecores},$proc{nodes}{$n}{hostname});
    }

    @sorted = sort { length($a) <=> length($b) } @pinfo;  my $ll = length $sorted[0]; $ll+=4;

    push @pinfo => sprintf ("%s",'-' x $ll);
    push @pinfo => ' ';
    push @pinfo => sprintf("    *  %-2s Total Processors",$proc{totalcpus});
    push @pinfo => sprintf("    *  %-2s %s per Processor",$proc{numtiles},$proc{numtiles} == 1 ? 'Tile' : 'Tiles');

    my $str = ($proc{nproc_x} == -1) ? 'WRF Internal' : "$proc{nproc_x} x $proc{nproc_y}";  my $len = length $str;
    push @pinfo => sprintf("    *  %-${len}s %s",$str,'Domain Decomposition');

    my $summary = join "\n", (@sinfo,@hinfo,@pinfo);

return $summary;
}


sub ErrorHelper {
#==================================================================================
#  This routine formats the output from the logfile in case an error occurred
#  during the running of an UEMS executable.
#==================================================================================
#   
    my $mesg = '';

    my ($logfile,$arf,$err,@lines) = @_;

    return unless @lines;

    $mesg = &Ecore::SysReturnCode($err);
    $mesg = 'I just don\'t know what happened. Maybe you can make some sense of it.' unless $mesg;
    &Ecomm::PrintMessage(0,14+$arf,255,1,1,$mesg);

    my $log = &Others::popitlev($logfile,2);

    &Ecomm::PrintMessage(0,14+$arf,255,1,1,"Here is some information from $log:");
    
    my $ls  = @lines-25; $ls = 0 if $ls < 0;

    foreach (splice @lines, 0, $ls) {
        if (/ERROR while reading namelist (\w+) /) {
            &Ecomm::PrintMessage(9,18+$arf,255,1,2,"There is an error in the $1 section of the static/namelist.(real|wrfm) file");
            return;
        }
    }
    &Ecomm::PrintMessage(0,16+$arf,144,1,2,"-" x 88);
    &Ecomm::PrintMessage(0,18+$arf,255,0,1,"Error Log: $_") foreach @lines;
    &Ecomm::PrintMessage(0,16+$arf,144,1,1,"-" x 88);


return;
}


