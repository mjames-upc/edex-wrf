#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Autils.pm
#
#  DESCRIPTION:  Autils contains the utility subroutines used to drive
#                ems_autorun.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Autils;

use warnings;
use strict;
require 5.008;
use English;


sub AutoCleaner {
#=====================================================================
#  This routine is the ems_run front end that calls the UEMS
#  cleaning utility.  Each one of the run-time routines should have 
#  a similar subroutine in its arsenal.  This routine should probably
#  be moved to the Eclean module, but I'm too lazy.
#=====================================================================
#
use Eclean;

    my ($level, $domain, $autorun) = @_; return unless $domain;

    my @args = ('--domain',$domain,'--level',$level,'--silent');

    $domain = &Others::popit($domain);

    &Ecomm::PrintMessage(1,7,255,1,1,"Cleaning up the $domain domain before beginning this delightful journey");
   
 
return &Eclean::CleanDriver(@args);
}



sub AutoMailer {
#==================================================================================
#==================================================================================
#

    my $fdate = `date -u +%Y%m%d%H`; chomp $fdate;
    my $date  = gmtime(); $date = "$date UTC";

    my $upref  = shift; my %Uauto = %{$upref};

    #----------------------------------------------------------------------------------
    #  Determine whether mail can be sent from the system 
    #----------------------------------------------------------------------------------
    #
    return unless $Uauto{parms}{users} and $ENV{MAILX} and $Uauto{rc};


    #----------------------------------------------------------------------------------
    #  Form the message
    #----------------------------------------------------------------------------------
    #
    my @lines= ();
    my $caus = '';
    my $mail = $ENV{MAILX};
    my $subj = "'About Your UEMS Simulation ...'";
    my $user = $Uauto{parms}{users};
    my $file = "$Uauto{rtenv}{logdir}/user_mesg.$fdate";


    for ($Uauto{rc}) {
        $caus = "for some unknown reason ($Uauto{rc})";
        $caus = 'while downloading and processing initialization data' if $_  < 10;
        $caus = 'during the run initialization phase'                  if $_ == 11;
        $caus = 'during the run initialization phase'                  if $_ == 12;
        $caus = 'during the run initialization phase'                  if $_ == 13;
        $caus = 'during the domain decomposition'                      if $_ == 21;
        $caus = 'while creating initial and boundary condition files'  if $_ == 22;
        $caus = 'during model integration'                             if $_ == 23;
        $caus = 'while post processing the simulation output'          if $_ == 31;
    }
 
    
    my $mesg = "It appears that on $date, your UEMS run suffered from a premature termination, ".
               "which is never good. I perused the log files, and from my very limited reading ".
               "ability, it appears that the run failed $caus.\n\n".

               "I've placed the files from the run in the $Uauto{rtenv}{domname}/log/ directory ".
               "for your inspection, just because I'm looking out for your best interests so you ".
               "don't have to bother.";


    push @lines, &Ecomm::TextFormat(0,0,84,2,1,"Greetings exceptionally intelligent and good looking UEMS user!");
    push @lines, &Ecomm::TextFormat(2,2,84,1,1,$mesg);
    push @lines, &Ecomm::TextFormat(0,0,84,2,3,'XXXOOO - Your UEMS');
    $mesg = join "\n", @lines;


    open my $ufh, '>', $file or return; print $ufh $mesg; close $ufh;

    #----------------------------------------------------------------------------------
    #  Commented out because mailx on Ubuntu systems do not have a '-S' flag
    #----------------------------------------------------------------------------------
    #
    #$mesg = "Try the following from the command line to debug the problem:\n\nX02X$mail -S sendwait -v -s $subj $user < $file";
    #system ("$mail -S sendwait -s $subj $user < $file") ? &Ecomm::PrintMessage(6,7,144,2,2,"Problem sending message to $user",$mesg) : &Others::rm($file);

    $mesg = "Try the following from the command line to debug the problem:\n\nX02X$mail -v -s $subj $user < $file";
    system ("$mail -s $subj $user < $file") ? &Ecomm::PrintMessage(6,7,144,2,2,"Problem sending message to $user",$mesg) : &Others::rm($file);


return;
}



sub AutoLockStat {
#==================================================================================
#  This routine looks for lock files associated with current ems_autorun 
#  running on the system and determines how to proceed. THis routine is also
#  at the end of a simulation to delete any lock files that were created.
#==================================================================================
#
    my $upref  = shift; my %Uauto = %{$upref};

    &Others::rm($Uauto{rtenv}{arlock});

    return %Uauto unless defined $Uauto{parms}{wait} and $Uauto{parms}{wait};
    return %Uauto if defined $Uauto{parms}{nolock} and $Uauto{parms}{nolock};

    #----------------------------------------------------------------------------------
    #  All lockfiles include a PID for the ems_autorun.pl jobs running on 
    #  this system. The filename format is uems_autorun.lock.$uemspid, where
    #  $ENV{EMS_LOGS} contains the top level logs directory (uems/logs) and
    #  $uemspid if the process ID associated with the job.
    #----------------------------------------------------------------------------------
    # 

    #  Get a local hostname as a default
    #
    my $shost   = $Uauto{emsenv}{sysinfo}{shost};
    my $domname = $Uauto{rtenv}{domname};

    #----------------------------------------------------------------------------------
    #  Look for any existing lock files to test whether there is an on-going
    #  simulation.  If yes, then the wait period begins.  There is a problem
    #  with this logic in that this routine does not know whether the new 
    #  simulation is destined for a remote system on which there is one
    #  already running.
    #----------------------------------------------------------------------------------
    #
    my %locks = ();
    my $mesg  = '';
    foreach my $lockfile (&Others::FileMatch($ENV{EMS_LOGS},'uems_autorun.lock',0,1)) {

        unless (-s $lockfile) {&Others::rm($lockfile); next;}   #  Empty file?  Move on

        my $loc = &Others::popit($lockfile);

        #  $rpid  - The process ID of the simulation
        #  $rdir  - run-time domain directory
        #  $host  - The host on which the simulation is running
        #  $ssecs - The number of seconds after Jan 1, 1970 the simulation started
        #
        my ($rpid, $rdir, $host, $ssecs) = '' x 4;

        open my $rfh, '<', $lockfile;
        while (<$rfh>) {
            s/^\s//g;
            next if /^#|^$|^\s+/;
            ($rpid, $rdir, $host, $ssecs) = split / +/ => $_;
        }  close $rfh;

        my %linfo = &Others::FileInfo($lockfile);


        #  If the simulation is currently running on the local host. Now it's a question
        #  of how long it's been running and whether the PID is owned by the same user.
        #  Note that &isProcessRunning is called rather than &isProcessRunning2 since
        #  ownership is not important here.
        #
        if ( $host eq $shost and &Others::isProcessRunning($rpid,'') ) {

            my %finfo = &Others::FileInfo("/proc/$rpid");
            my $age   = &Ecomm::FormatTimingString($finfo{fage});

            #  Check whether you have the power
            #
            if (&Others::isProcessRunning2($rpid,'')) {  #  True (1) means you can kill it


                if ($finfo{fage} > 21600) { # If run is longer than 6 hours give warning
                   
                    $mesg = "There appears to be an existing simulation (PID $rpid) in the $rdir directory that has been ".
                            "running for $age. Is there a problem?\n\nThe current simulation will not start until all ".
                            "on-going processes have ended.";
                    &Ecomm::PrintMessage(6,7,86,2,2,'AutoRun: Problem with Previous Model Run?',$mesg);

                 } elsif ($finfo{fage} > 43200) { # If run is longer than 12 hours then kill previous run

                    $mesg = "There appears to be an existing simulation (PID $rpid) on $shost from the $rdir directory ".
                            "than has been running for $age.\n\nThis simulation will be terminated to allow the new run ".
                            "to start.";

                    &Ecomm::PrintMessage(6,7,86,2,2,'AutoRun: Problem with Previous Model Run?',$mesg);

                    unless (&Others::KillProcessPID($rpid,'')) {
                        &Others::rm($lockfile);
                        next;
                    }

                }

            }  else {  #  You don't have the power to kill it.  Need more power

                $mesg = "There is an existing simulation (PID $rpid) in the $rdir directory that has been running for $age. ".
                        "Rather than offending the other user ($finfo{uname}), your simulation will be parked for $Uauto{parms}{wait} seconds ".
                        "or until the current simulation has completed. If the simulation has not ended after the wait ".
                        "period, your run will be terminated.";

                &Ecomm::PrintMessage(6,7,86,2,2,'AutoRun: This is a busy place!',$mesg);

            }
            $locks{$lockfile} = $rpid;

        } elsif ($linfo{isowner} and ($host eq $shost or $linfo{fage} > 86400)) {
            &Others::rm($lockfile);
            next;
        }

    }  # End of foreach lock file loop


    #----------------------------------------------------------------------------------
    #  If there are simulations running then wait until finished.
    #----------------------------------------------------------------------------------
    #
    if (%locks) {
        my @lockids = values %locks;  my $lockids = &Ecomm::JoinString(\@lockids);

        $mesg = "It appears that there are multiple UEMS jobs already running on the system, so you must wait your turn like everybody else. ".
                "I will monitor the status of the following process IDs for the next $Uauto{parms}{wait} seconds. As soon as they ".
                "finish, your ems_autorun.pl job will begin. If one or more processes fail to finish within the specified time limit, your run ".
                "will be terminated.\n\nX04XJob PIDs: $lockids\n\nYa know, it's just business.";
        &Ecomm::PrintMessage(6,7,94,2,2,$mesg) if %locks;

        my $delts = 15;
        my $wsecs = $Uauto{parms}{wait};

        while ($wsecs and %locks) {

            #  Hang out and wait $wsecs for the previous previous runs to end. Check every 60 second.
            #
            sleep $delts;  $wsecs -= $delts;

            &Ecomm::PrintMessage(0,10,108,1,0,sprintf("AutoRun (%4s): Checking whether the previous run(s) have finished ",$Uauto{parms}{wait}-$wsecs));
    
            my %tmp=();
            foreach my $alog (keys %locks) {
                $tmp{$alog} = $locks{$alog} if &Others::isProcessRunning($locks{$alog});
            } %locks = %tmp;
    
            %locks ? &Ecomm::PrintMessage(0,1,20,0,0,"- Nope, Checking again in $delts seconds") : &Ecomm::PrintMessage(0,1,20,0,2,"- Yes! Let's Go");
        }
    }


    #----------------------------------------------------------------------------------
    #  If any lock files remain do not start the simulation
    #----------------------------------------------------------------------------------
    #
    if (%locks) {&Ecomm::PrintMessage(6,7,108,2,2,'AutoRun: Sorry, but you are out of time. Terminating current run - Bummer!'); return ();}


    #----------------------------------------------------------------------------------
    #  Good news!  Time to start the simulation
    #----------------------------------------------------------------------------------
    #
    my $uemspid  = $Uauto{rtenv}{emspid};

    $Uauto{rtenv}{arlock} = "$ENV{EMS_LOGS}/uems_autorun.lock.$uemspid" unless $Uauto{rtenv}{arlock};  #  As a precaution

    my $autolock = $Uauto{rtenv}{arlock};
    my $csecs    = time();

    open my $wfh, '>', $autolock || return ();
    print $wfh "$uemspid $domname $shost $csecs";
    close $wfh;

    $ENV{AUTOLOCK} = $Uauto{rtenv}{arlock};

    $Uauto{parms}{wait} = 0;  #  Set WAIT to 0 since it's no longer needed


return %Uauto;
}



