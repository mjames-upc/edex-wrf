#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Apost.pm
#
#  DESCRIPTION:  Apost is the main Perl module used by ems_autopost. It is either
#                called by ems_autorun or ems_run and returns a single error code
#                depending on what happens and something always happens.
#
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Apost;

require 5.008;
use strict;
use warnings;
use English;



sub AutopostCommunications {
#===============================================================================
#  The purpose of this routine is to test the 2-way communication between
#  the machine ems_run.pl and ems_autopost.pl. 
#
#  1. Check whether passwordless SSH is configured between the localhost
#     and the system running autopost.
# 
#  2. Check whether ems_autopost.pl exists on the remote system
#
#  3. Check whether passwordless SSH is configured from the remote system
#     back to the localhost.
#
#===============================================================================
#
use Enet;

    my $err = '';
    my $href = shift; my %Apost = %{$href};  return 0 if $Apost{ahost} eq 'localhost';

    my $rhost = $Apost{ahost};
    my $lhost = $Apost{lhost};
    my $apexe = $Apost{apexe};
    
    if ($err = &Enet::TestPasswordlessSSH_Outgoing($rhost)) { 
        my $mesg = "It appears that passwordless SSH is not properly configured between the localhost and ".
                   "the system used to run ems_autopost.pl. Make sure that you can use passwordless SSH to ".
                   "login to $rhost, and then adain from $rhost back to the localhost. Also check whether ".
                   "$ENV{EMS_STRC}/ems_autopost.pl exists on $rhost. Once you have completed those tasks, I ".
                   "may allow you to play with the UEMS auto post-processor, but only on special occasions.\n\n".
                   "Unfortunately for us, I must postpone all concurrent post processing activities until after ".
                   "the simulation has completed, and I hate to wait.\n\n\n".
                   "BTW - The error message returned: $err";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,"UEMS Autopost: What we've got here is failure to communicate",$mesg);
        return 53;
    }


    if ($err = &Enet::TestFileAvailableSSH_Outgoing($rhost,$apexe)) {
         my $mesg = "It appears that the ems_autopost.pl routine could not be located on $rhost:\n\n".
                    "X02X$apexe\n\n".
                    "which is unfortunate for you because I must postpone all concurrent post processing activities ".
                    "until after the simulation has completed, and I hate to wait.";
         &Ecomm::PrintMessage(6,17,88,1,1,'UEMS Autopost: No Autopost for you!',$mesg);
         return 53;
    }


    if ($err = &Enet::TestPasswordlessSSH_Incoming($lhost,$rhost)) {
        my $mesg = "It appears that passwordless SSH is not properly configured between the system used to run ".
                   "ems_autopost.pl ($rhost) and the localhost ($lhost).\n\nAs in all relationships, communication ".
                   "is a two (or more) way street in the UEMS, so you need to step up your game. Remember, you're ".
                   "\"In it to win it\", a \"team player\", \"taking it to the next level\", \"staying focused\", ".
                   "\"giving it 110%\", and \"taking it one simulation at a time.\" All this so you can \"Show me ".
                   "the money!\"\n\n". 
                   "X04XAnd by \"Me\", I mean ME.\n\n".
                   "Unfortunately for us, I must postpone all concurrent post processing activities until after ".
                   "the simulation has completed, and I hate to wait.\n\n\n".
                   "BTW - The error message returned: $err";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,"UEMS Autopost: What we've got here is failure to communicate",$mesg);
        return 53;
    }


return 0;
}


sub AutopostLaunch {
#===============================================================================
#  This routine starts ems_autopost.pl on the road to post processing nirvana.
#  Note that although it appears a value ($astat) is returned, it is not used
#  by the calling routine because it can not be seen outside the statement
#  branch, which is a bummer.
#===============================================================================
#
    my $mesg = qw{};
    my ($emspid, $href) = @_; my %Apost = %{$href}; 


    #----------------------------------------------------------------------------------
    #  Specify the arguments to be passed to ems_post. If this is a benchmark run
    #  then the user input arguments are limited to just a couple to avoid failure.
    #----------------------------------------------------------------------------------
    #
    my @pargs=();
    push @pargs => "--rundir   $Apost{rundir}";
    push @pargs => "--domains  $Apost{domains}";
    push @pargs => "--emspid   $Apost{lhost}:$emspid";
    
    @pargs = split / +/ => (join " " => @pargs);

    #----------------------------------------------------------------------------------
    #  Just as a precaution, delete the lock & log files
    #----------------------------------------------------------------------------------
    #
    &Others::rm($Apost{aplog}, $Apost{aplock});

    #----------------------------------------------------------------------------------
    #  Determine whether this is a local application or to be started on a
    #  remote system via SSH.
    #----------------------------------------------------------------------------------
    #
    my $apcmd = $Apost{apssh} ? "ssh -q -o BatchMode=yes $Apost{ahost} $Apost{apexe} @pargs > $Apost{aplog}"  :
                                "$Apost{apexe} @pargs > $Apost{aplog}";


    my $astat = system "$apcmd 2>&1 &";


return $astat;
}


sub AutopostActive {
#==================================================================================
#  The &AutopostActive routine is called just before the start of a simulation
#  to check the status of ems_autopost.pl, which is forked prior to ems_run.pl.
#  If successful (ems_autopost.pl is running), the routine returns the PID of
#  ems_autopost.pl, which was written to a file when ems_autopost.pl was started.
#
#  Note that nothing is returned from &AutopostActive to the calling
#  routine because the value can not be seen outside of the brach in the 
#  fork statement.
#==================================================================================
#
    my $date = gmtime();
    my $mesg = qw{};

    #----------------------------------------------------------------------------------
    #  A separate $SIG{INT} handler is used to prevent multiple calls to 
    #  &Ecore::SysIntHandle due to &AutopostActive being run as a child
    #  process.
    #----------------------------------------------------------------------------------
    #
    $SIG{INT} = \&SysIntHandle;

    my $href = shift; my %Apost = %{$href}; 

    &Ecomm::PrintMessage(1,14,255,2,0,"AutoPost: Starting ems_autopost.pl on $Apost{ahost} - ");
    
    #----------------------------------------------------------------------------------
    #  Check whether autopost.pl has started on the system by looking for the existance
    #  of a lock file, which will contain the process ID. The ID will then be used to
    #  determine whether the ems_autopost.pl is still running. The problem with this 
    #  approach is ems_autopost.pl expects that the simulation has already started,
    #  which it has not, and will terminate itself if it can not find the PID 
    #  associated with the simulation.
    #  
    #  Get get around this problem a 60s delay (sleep) is used in ems_autopost.pl
    #  after the creation of the lock file but before the it checks whether the 
    #  simulation is running. The AutopostActive (this) routine will wait up to 
    #  30s for the appearance of the lock file. If the lockfile does not appear within
    #  the allotted time, it is assumed that ems_autopost.pl has failed during
    #  the preliminary configuration. If the lock file does appear then the PID from
    #  the lock file is used to determine whether ems_autopost.pl is running.
    #----------------------------------------------------------------------------------
    #
    my $wait  = 30;
    my $decr  = 2;  #  Amount to decrement the counter each step


    #----------------------------------------------------------------------------------
    #  Wait for the appearance of the lock file to get the ems_autopost.pl PID. Even
    #  though ems_autopost.pl is (should be) running on another system, the lock
    #  file will appear on the run-time directory on the local host, although to 
    #  compensate for NFS issues the ls command "ls -a" will be used. Finally, don't
    #  be alarmed my the "kill -0 PID", it is used to check for the existence of
    #  a running process.
    #----------------------------------------------------------------------------------
    #
    while ($wait) {sleep $decr; $wait-=$decr; next if system "ls -a $Apost{aplock} > /dev/null 2>&1"; sleep $decr; $wait = 0;}

    
    if (&isAutopostRunning($Apost{aplock},$Apost{apssh} ? $Apost{ahost} : '')) {
        &Ecomm::PrintMessage(0,0,12,0,1,'Done');
        &Ecomm::PrintMessage(0,17,96,1,1,"Don't take my word for it, check it out for yourself:");
        &Ecomm::PrintMessage(0,19,144,1,1,"%  tail -f $Apost{aplog}");
        &Ecomm::PrintMessage(0,17,96,1,1,"Or you can just trust me.");
    } else {
        &Ecomm::PrintMessage(0,0,12,0,1,'Failed');
        $mesg = "The Autopost lock file is missing:\n\n$Apost{aplock}";
        $mesg = "The UEMS Autopost failed for unknown reason and it's up to you to figure out what went so horribly wrong. ".
                "You might be able to find a clue by looking in the log file:" if -s $Apost{aplock};
        &Ecomm::PrintMessage(9,17,88,1,1,"That didn't go quite as planned!",$mesg);
        &Ecomm::PrintMessage(0,20,144,1,2,$Apost{aplog}) if -s $Apost{aplock};
        &Ecomm::PrintMessage(0,17,96,1,1,"I will manage the post processing after your simulation has completed.");
        &Others::rm($Apost{aplock});
    }


return;
}


sub isAutopostRunning {
#==================================================================================
#  The &isAutopostRunning routine checks whether UEMS autopost is running.
#  Returns the Autopost PID if yes; otherwise 0.
#==================================================================================
#
    my ($aplock, $ahost) = @_;

    my $apid = &GetAutopostPID($aplock);

return ($apid and &Others::isProcessRunning2($apid,$ahost)) ? $apid : 0;
}
    


sub TerminateAutopost {
#==================================================================================
#  Only called in the event of a ^C by the user, &TerminateAutopost kills the
#  ems_autopost.pl job.
#==================================================================================
#
    my @euphs = ('has been whacked', 'is now terminated', 'was sent to a farm', 'is now sleeping with the fishes');

    my $href  = shift; my %Apost = %{$href}; 
 
    my $ahost = $Apost{apssh} ? $Apost{ahost} : '';

    if (my $apid = &isAutopostRunning($Apost{aplock},$ahost) ) {

        my $hi = $ahost ? "on $ahost" : 'on localhost';
        &Ecomm::PrintMessage(6,7,92,1,0,"Terminating UEMS Autopost $hi");

        &Others::KillProcessPID($apid,$ahost) ?  &Ecomm::PrintMessage(0,1,1,0,1," - just like cockroaches, ems_autopost.pl will not die!") 
                                              :  &Ecomm::PrintMessage(0,1,1,0,1," - ems_autopost.pl $euphs[int rand scalar @euphs]");
    }
    &Others::rm($Apost{aplock});


return;
}


sub GetAutopostPID {
#==================================================================================
#  The Autopost process ID information is used to check whether the Autopost is
#  running. It is written to a file at the top level of a run-time directory when
#  the Autopost is started. Due to the use of "fork" in &ProcessControl_WRFM 
#  to start Autopost as a child process the PID can not be returned via normal
#  methods so &GetAutopostPID is used simply to read the file.
#
#  Returns Autopost PID or 0 if AP lock file does not exist.
#==================================================================================
#
    my $appid  = 0;
    my $aplock = shift;

    if (open my $lfh, '<', $aplock) {while (<$lfh>) {s/ +//g; $appid = $1 if /PID=(\d+)/i;} close $lfh;}

return $appid;
}


sub SysIntHandle {
#==================================================================================
#  Here to prevent multiple &Ecore::SysIntHandle calls 
#==================================================================================
#
exit(0);
}


