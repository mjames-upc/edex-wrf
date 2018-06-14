#!/usr/bin/perl
#===============================================================================
#
#         FILE:  UEMS_WatchDog.pl
#
#  DESCRIPTION:  
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.10.4
#      CREATED:  08 March 2018
#===============================================================================
#
require 5.008;
use strict;
use warnings;
use English;


#  Define this process as being run on the SERVER or CLIENT side.
#
BEGIN {
    $ENV{UEMS_CONTROL} = 'SERVER';
}

#  ===============================================================================
#  The UEMS Watch Dog routine summary - someday
#  ===============================================================================
#
    
    #--------------------------------------------------------------------------
    #  Override system interrupt handler - A local one is needed since 
    #  environment variables are used for clean-up after the interrupt.
    #--------------------------------------------------------------------------
    #
    $SIG{INT} = \&SysIntHandle;

    #--------------------------------------------------------------------------
    # &WatchDogMonitor manages the process.
    #--------------------------------------------------------------------------
    #
    &SysExit(1,$0)  if &ReturnHandler(&WatchDogMonitor()); 


&SysExit(0,$0);



sub WatchDogMonitor {
#==================================================================================
#  This subroutine continuously checks for the existence of the 
#==================================================================================
#
use POSIX ":sys_wait_h";

    $ENV{WDMESG} = '';

    my %Iwatch  = ();
    
    return 1 unless %Iwatch = &ReadWatchDogConfiguration(\%Iwatch);

    #-------------------------------------------------------------------------
    #  &WatchDogMonitor will run as long as the $Iwatch{dogrun} exists.
    #  There is a sleep period ($Iwatch{u_sleep}) at the bottom of each
    #  loop iteration.
    #-------------------------------------------------------------------------
    #
    my $nt = int (3600/$Iwatch{u_sleep});  #  Print "WatchDog on duty" Once per hour
    my $np = 0;  #  Print Queued processes frequency

    my $nprocs = 0;

    while (&WatchDogRun(\%Iwatch)) {

        %{$Iwatch{queued}} = ();
        my $nq = 0;

        #-------------------------------------------------------------------------
        #  Requested simulation arrive by way of a tarfile containing the 
        #  configuration placed into the incoming directory by the client.
        #-------------------------------------------------------------------------
        #
        foreach my $incoming (&GetIncomingRequests(\%Iwatch)) {

            unless (-s $incoming) {&rm($incoming); next;}  #  Skip empty files


            #-------------------------------------------------------------------------
            #  Make sure the incoming file has a viable naming convention
            #-------------------------------------------------------------------------
            #
            my $tarfile = &popit($incoming);
            unless ($tarfile =~ /(\w+)_(\d+)_(\w+)\.t/i) {
                my $date = gmtime();
                my $mesg = "The naming convention used for the tarfile $tarfile does not meet the UEMS ".
                           "standards of \n\nX02X<client id>_<client pid>_<run-time directory>.tgz|tbz|tar\n\n".
                           "It will be ignored.";
                &PrintFile($ENV{WDFH}||0,1,4,114,1,1,"File in error ($date)",$mesg);
                &rm($incoming);
                next;
            }
            my $client_id  = lc $1;
            my $client_pid = $2;
            my $client_dir = lc $3;

            my %finfo      = &FileInfo($incoming);
            my $post_time  = &EpochSeconds2Pretty($finfo{modsecs});

            #-------------------------------------------------------------------------
            #  If the maximum number of on-going processes has not been met then
            #  look for new requests.
            #-------------------------------------------------------------------------
            #
            if ($nprocs < $Iwatch{u_maxprocs}) {  #  Job ON!

                #-------------------------------------------------------------------------
                #  The simulation ID is a string consisting of the client ID, the run-time
                #  directory name, and the local process ID (STID_NAME_PID). At this point
                #  the local process ID is not yet available so use the client PID.
                #-------------------------------------------------------------------------
                #
                my $client_sid = $Iwatch{u_simid};
                   $client_sid =~ s/STID/$client_id/g;
                   $client_sid =~ s/NAME/$client_dir/g;
                   $client_sid =~ s/PID/$client_pid/g;
                

                #-------------------------------------------------------------------------
                #  Create the logfile name for the simulation. Everything will be written
                #  to the U_LOGGING/client_ldir/ directory. Note that the PID has not yet
                #  been incorporated into $client_sid. That step will occur just before
                #  executing the simulation.
                #-------------------------------------------------------------------------
                #
                my $client_ldir = "$Iwatch{u_logging}/$client_sid"; &mkdir($client_ldir);
                my $client_log  = "$client_ldir/MissionControl-Server.log";


                #-------------------------------------------------------------------------
                #  Output the process ID of the simulation. No PID means an error ocurred.
                #-------------------------------------------------------------------------
                #
                my $pid = 0;

                unless ($pid = &NotifyMissionControl($Iwatch{u_mc},$incoming,$client_log)) {
                    $ENV{WDMESG} = &TextFormat(0,0,84,0,2,'Mission WatchDog Termination',$ENV{WDMESG});
                    return 1;
                }

      
                #-------------------------------------------------------------------------
                #  The %{$Iwatch{processes}} hash contains the pid of all simulations
                #  currently running on the system. Add another entry.
                #-------------------------------------------------------------------------
                #
                $Iwatch{processes}{$pid}{queued}  = $post_time;
                $Iwatch{processes}{$pid}{started} = gmtime();
                $Iwatch{processes}{$pid}{sepocs}  = `date -u +%s`; chomp $Iwatch{processes}{$pid}{sepocs};

                $Iwatch{processes}{$pid}{stopped} = 0;
                $Iwatch{processes}{$pid}{eepocs}  = 0;
    
                $Iwatch{processes}{$pid}{client_id}   = $client_id;   #  The client system ID
                $Iwatch{processes}{$pid}{client_pid}  = $client_pid;  #  The process client ID 
                $Iwatch{processes}{$pid}{client_dir}  = $client_sid;  #  The client run-time directory & SID
                $Iwatch{processes}{$pid}{client_log}  = $client_log;  #  The client logfile
                $Iwatch{processes}{$pid}{client_ldir} = $client_ldir; #  The client log directory

                &UpdateWatchDogLog($pid,\%{$Iwatch{processes}{$pid}});

                $nprocs++; #  One more process running

                next;  #  

            }  #  If $nprocs < $Iwatch{u_maxprocs}

            $nq++;
            $Iwatch{queued}{$nq}{client_id}  = $client_id;
            $Iwatch{queued}{$nq}{client_dir} = $client_dir;
            $Iwatch{queued}{$nq}{client_pid} = $client_pid;
            $Iwatch{queued}{$nq}{post_time}  = $post_time;


        }  #  Foreach Incoming

             
        #-------------------------------------------------------------------------
        #  Check the status of on-going processes using the Perl wait call. If the 
        #  returned value is 0 the process is still running. If the value is the 
        #  same as the PID, then the process has terminated, in which case write
        #  the date & time of the completion to the %{$Iwatch{processes}} hash.
        #  This information will be posted to the U_HTMPAGE webpage for U_PURGE
        #  hours. 
        #-------------------------------------------------------------------------
        #
        foreach my $child (sort {$a <=> $b} keys %{$Iwatch{processes}}) {
            if ($child==waitpid($child,WNOHANG)) { #  Child has completed
                $Iwatch{processes}{$child}{status}  = $? >> 8;
                $Iwatch{processes}{$child}{stopped} = gmtime();
                $Iwatch{processes}{$child}{eepocs}  = `date -u +%s`; chomp $Iwatch{processes}{$child}{eepocs};
                &UpdateWatchDogLog($child,\%{$Iwatch{processes}{$child}});
                $nprocs--; #  One less running process
            }
        }

        
        #-------------------------------------------------------------------------
        #  Update the website with the process information
        #-------------------------------------------------------------------------
        #
        &UpdateStatusPage(\%Iwatch);


        #-------------------------------------------------------------------------
        #  Update the log file with the Queued information.
        #-------------------------------------------------------------------------
        #
        &QueuedWatchDogLog(\%{$Iwatch{queued}}) if $nq and $nq != $np;
        $np = $nq;
    


        #-------------------------------------------------------------------------
        #  Purge any process information that has passed it's end of life
        #-------------------------------------------------------------------------
        #
        my $epocs  = `date -u +%s`; chomp $epocs;

        foreach my $child (sort {$a <=> $b} keys %{$Iwatch{processes}}) {
            next unless $Iwatch{processes}{$child}{eepocs};
            delete $Iwatch{processes}{$child} if $epocs-$Iwatch{processes}{$child}{eepocs} > $Iwatch{u_purge};
        }

        sleep $Iwatch{u_sleep};

        my $date = gmtime(); chomp $date;
        &PrintFile($ENV{WDFH}||0,0,6,144,1,1,"WatchDog on duty - $date") unless $nt;
        
        $nt = $nt ? $nt-1 : int (3600/$Iwatch{u_sleep});
     }


return 0;
}



sub NotifyMissionControl {
#==================================================================================
#  &NotifyMissionControl passes the tarfile to MissionControl-Server routine,
#  which initiates the simulation. The process ID is returned unless there was 
#  an error in which case a "0" is returned. The process ID is monitored through
#  completion by the calling program.
#==================================================================================
#
    my ($u_mc, $tarfile, $logfile) = @_;

    my $pid = &SysExecute("$u_mc --tarfile $tarfile",$logfile);


    #-----------------------------------------------------------------------------
    #  WatchDogPrint.pl is used for development
    #-----------------------------------------------------------------------------
    #
    #my $pid = &SysExecute('/usr1/Uems/Development/UEMSbuilds/UEMSbuild.18.X/strc/UEMScontrol/WatchDog/WatchDogPrint.pl');

return ($pid and $pid > 0) ? $pid : 0;
}


sub UpdateStatusPage {
#==================================================================================
#  &UpdateStatusPage prepares a hash containg the current process information for 
#  posting to a web page.
#==================================================================================
#
    my $href = shift; my %Iwatch = %{$href};

    #------------------------------------------------------------------------------
    #  Split the processes into completed and current hashes.
    #------------------------------------------------------------------------------
    #
    my %Process = ();

    %{$Process{current}}  = map { $Iwatch{processes}{$_}{eepocs} ? () : ($_ => $Iwatch{processes}{$_}) }  keys %{$Iwatch{processes}};
    %{$Process{complete}} = map { $Iwatch{processes}{$_}{eepocs} ? ($_ => $Iwatch{processes}{$_}) : () }  keys %{$Iwatch{processes}};
    %{$Process{queued}}   = %{$Iwatch{queued}};

    $Process{u_htmpage}   = $Iwatch{u_htmpage};

    &WriteStatusHtml(\%Process);

        
return;
}


sub WriteStatusHtml {
#==================================================================================
#  &WriteStatusHtml writes a webpage to the location defined by $Iwatch{u_htmpage}
#  Containing the status of the past and current processes.
#==================================================================================
#
use IO::Handle;

    my %pids = ();
    my $href = shift; my %Process = %{$href};

    return unless $Process{u_htmpage};

    open (my $wfh, '>', $Process{u_htmpage}) || return; $wfh->autoflush(1);

    
    print $wfh "Content-type: text/html\n\n";
    print $wfh '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">';
    print $wfh "\n<html><head><title>SOO/STRC Personal Tile Data Server</title></head>\n";
    print $wfh "<font color=red><h2 align=\"center\">UEMS WCOSS Simulation Status Page</h2></font>\n";
    print $wfh "<align=left><body bgcolor=\"#ffffff\">\n";
    
    %pids = %{$Process{current}};  #  Keep it short
    foreach my $pid (sort {$a <=> $b} keys %pids) {
        print $wfh sprintf('<br>   %8d   %6s   %16s   Started: %12s    Running',$pid,$pids{$pid}{client_id},$pids{$pid}{client_dir},$pids{$pid}{started});
    }

    %pids = %{$Process{complete}};  #  Keep it short
    foreach my $pid (sort {$a <=> $b} keys %pids) {
        $pids{$pid}{status} ? print $wfh sprintf('<br>   %8d   %6s   %16s   Started: %12s    Failed  : %12s (%3d)',$pid,$pids{$pid}{client_id},$pids{$pid}{client_dir},$pids{$pid}{started},$pids{$pid}{stopped},$pids{$pid}{failed})
                            : print $wfh sprintf('<br>   %8d   %6s   %16s   Started: %12s    Finished: %12s',$pid,$pids{$pid}{client_id},$pids{$pid}{client_dir},$pids{$pid}{started},$pids{$pid}{stopped});
    }


    %pids = %{$Process{queued}};
    foreach my $pid (sort {$a <=> $b} keys %pids) {
        print $wfh sprintf('<br>   %4d   %6s   %16s   Received: %12s    Running',$pid,$pids{$pid}{client_id},$pids{$pid}{client_dir},$pids{$pid}{post_time});
    }

    
    print $wfh "\n</body><br>\n";
    print $wfh "</html>\n";

    close $wfh;


return;
}



sub WatchDogRun {
#==================================================================================
#  This routine checks for the existence if a file identified by $Iwatch{dogrun}
#  and returns 1 if it exists or 0 if not.
#==================================================================================
#
    my $href = shift; my %Iwatch = %{$href};

return (-e $Iwatch{dogrun}) ? 1 : 0;
}


sub GetIncomingRequests {
#==================================================================================
#  This subroutine looks for any tarfiles deposited in the $Iwatch{u_incoming}
#  directory. It returns an array containing the tarfile(s) including the 
#  path. If none exists then an empty array is returned.
#==================================================================================
#
    my $href     = shift; my %Iwatch = %{$href};
    my @incoming = &FileMatch($Iwatch{u_incoming},'\.tar|\.tgz|\.tbz',0,1,4);

return @incoming;
}


sub OpenWatchdogLog {
#==================================================================================
#  Opens the logfile in the directory identified by $Iwatch{u_logging}. The log
#  file include the process ID. The filehandle for the log file is written to
#  the $ENV{WDFH} environment variable for use within other subroutines.
#==================================================================================
#
    my $href      = shift; my %Iwatch = %{$href};
    my $u_logfile = "$Iwatch{u_logging}/MissionControl-WatchDog_$Iwatch{dogpid}.log";

    unless (open $ENV{WDFH}, '>', $u_logfile) {
        $ENV{WDMESG} = &TextFormat(0,0,144,0,2,'UEMS WatchDog Termination',"Unable to open log file: $u_logfile");
        return ();
    }
    
    my $date = gmtime(); chomp $date;
    &PrintFile($ENV{WDFH}||0,0,4,144,1,1,"UEMS WatchDog Started on $date");


return %Iwatch;
}



sub UpdateWatchDogLog {
#==================================================================================
#  Writes the logfile in the directory identified by $Iwatch{u_logging}. The log
#  file include the process ID. The filehandle for the log file is written to
#  the $ENV{WDFH} environment variable for use within other subroutines.
#==================================================================================
#
    my ($pid, $href) = @_; my %proc = %{$href};

    my $mesg = $proc{eepocs} ? 
               $proc{status} ? sprintf('%06d  %6s   %26s   FAILED (%3d) %12s',$pid,$proc{client_id},$proc{client_dir},$proc{status},$proc{stopped})
                             : sprintf('%06d  %6s   %26s   FINISHED     %12s',$pid,$proc{client_id},$proc{client_dir},$proc{stopped})
                             : sprintf('%06d  %6s   %26s   STARTED      %12s',$pid,$proc{client_id},$proc{client_dir},$proc{started});
    &PrintFile($ENV{WDFH}||0,0,7,144,1,1,$mesg);

return;
}


sub QueuedWatchDogLog {
#==================================================================================
#  Writes a listing of the queued tasks to the WatchDog logfile .
#==================================================================================
#
    my $href = shift; my %Queued = %{$href};

    return unless %Queued;

    my $date = gmtime(); chomp $date;

    foreach my $nq (sort {$a <=> $b} keys %Queued) {
        my $mesg = sprintf('%6d  %6s   %18s  %6d   IN QUEUE     %12s',$nq,$Queued{$nq}{client_id},$Queued{$nq}{client_dir},$Queued{$nq}{client_pid},$Queued{$nq}{post_time});
        &PrintFile($ENV{WDFH}||0,0,7,144,1,0,$mesg);
    }
    &PrintFile($ENV{WDFH}||0,0,1,1,1,0,' ');
    

return;
}
    


sub ReadWatchDogConfiguration {
#==================================================================================
#  This routine reads the contents of the UEMS Watch Dog configuration file
#  located in the uems/conf/uems_mission/ directory and then uses the information
#  to set the environment necessary for monitoring incoming requests, initiating
#  simulations, and then cleaning up the leftover mess. This routine also creates
#  the $Iwatch{dogrun} file that is used by WatchDog as a marker for termination.
#  
#  It returns a hash in which  keys are all lower case.
#==================================================================================
#
    my $cfile = "$ENV{EMS_CONF}/uems_mission/MissionControl-Server.conf"; 

    my $cf    = &popit($cfile);
    my $href  = shift; my %Iwatch = %{$href};


    #----------------------------------------------------------------------------------
    #  Read the local configuration file. Minimal error checking will be done on
    #  the client because that requires knowledge of configuration files and other
    #  information that is not available.
    #----------------------------------------------------------------------------------
    #
    unless (-s $cfile and %Iwatch = &ReadConfigurationFile($cfile)) {
        my $mesg = "It appears that there was a problem reading the UEMS Server configuration file:\n\n".
                   "X03X$cf\n\n";
        $ENV{WDMESG} = &TextFormat(0,0,144,0,2,'UEMS WatchDog Termination',$mesg);
        return ();
    }


    #---------------------------------------------------------------------------------------
    # Set the Watchdog PID.
    #---------------------------------------------------------------------------------------
    #
    $Iwatch{dogpid} = $$;


    #---------------------------------------------------------------------------------------
    #  U_BIN specifies the location of the $EMS/strc/Ubin directory. Since the $UEMS 
    #  environment variables are not used by WatchDog, this location must be provided
    #  by the configuration file.  Additionally, UEMS_MissionControl.pl must reside
    #  in the same directory.
    #---------------------------------------------------------------------------------------
    #
    unless (defined $Iwatch{u_bin} and -d $Iwatch{u_bin}) {
        unless (defined $Iwatch{u_bin} and $Iwatch{u_bin}) {
            $ENV{WDMESG} = &TextFormat(0,0,144,0,2,'UEMS WatchDog Termination',"Illegal or missing value for U_BIN in $cf");
            return ();
        }
    }


    unless (-s "$Iwatch{u_bin}/UEMS_MissionControl.pl" and -x "$Iwatch{u_bin}/UEMS_MissionControl.pl") {
        $ENV{WDMESG} = &TextFormat(0,0,255,0,2,'UEMS WatchDog Termination',"Unable to locate executable $Iwatch{u_bin}/UEMS_MissionControl.pl");
        return ();
    }
    $Iwatch{u_mc} = "$Iwatch{u_bin}/UEMS_MissionControl.pl";


    #---------------------------------------------------------------------------------------
    #  U_INCOMING defines were all tar files are placed when uploaded by the client.
    #---------------------------------------------------------------------------------------
    #
    unless (defined $Iwatch{u_incoming} and $Iwatch{u_incoming}) {
        $ENV{WDMESG} = &TextFormat(0,0,144,0,2,'UEMS WatchDog Termination',"Illegal or missing value for U_INCOMING in $cf");
        return ();
    }
    &rm($Iwatch{u_incoming});


    if (&mkdir($Iwatch{u_incoming})) {
        $ENV{WDMESG} = &TextFormat(0,0,144,0,2,'UEMS WatchDog Termination',"Unable to create U_INCOMING: $Iwatch{u_incoming}");
        return ();
    }


    #---------------------------------------------------------------------------------------
    #  U_PROCESS defines were tar files are moved by UEMS_MissionControl.pl for processing.
    #---------------------------------------------------------------------------------------
    #
    unless (defined $Iwatch{u_process} and $Iwatch{u_process}) {
        $ENV{WDMESG} = &TextFormat(0,0,144,0,2,'UEMS WatchDog Termination',"Illegal or missing value for U_PROCESS in $cf");
        return (); 
    }
    &rm($Iwatch{u_process});

    if (&mkdir($Iwatch{u_process})) {
        $ENV{WDMESG} = &TextFormat(0,0,144,0,2,'UEMS WatchDog Termination',"Unable to create U_PROCESS: $Iwatch{u_process}");
        return (); 
    }


    #---------------------------------------------------------------------------------------
    #  U_LOGGING defines were all the logging is done so make sure the directory
    #  exists and is writable.
    #---------------------------------------------------------------------------------------
    #
    unless (defined $Iwatch{u_logging} and $Iwatch{u_logging}) {
        $ENV{WDMESG} = &TextFormat(0,0,144,0,2,'UEMS WatchDog Termination',"Illegal or missing value for U_LOGGING in $cf");
        return ();
    }
    &rm($Iwatch{u_logging});

    if (&mkdir($Iwatch{u_logging})) {
        $ENV{WDMESG} = &TextFormat(0,0,144,0,2,'UEMS WatchDog Termination',"Unable to create U_LOGGING: $Iwatch{u_logging}");
        return ();
    }


    #---------------------------------------------------------------------------------------
    #  We are past the termination point for errors. Everything beyond gets written to 
    #  to the log file.
    #---------------------------------------------------------------------------------------
    #
    return () unless %Iwatch = &OpenWatchdogLog(\%Iwatch);



    #---------------------------------------------------------------------------------------
    #  U_SLEEP defines the amount of time (s) between checks in U_INCOMING for new files.
    #---------------------------------------------------------------------------------------
    #
    unless (defined $Iwatch{u_sleep} and $Iwatch{u_sleep} =~ /^\d+$/ and $Iwatch{u_sleep} > 0) {
        &PrintFile($ENV{WDFH}||0,1,4,114,1,1,'Watchdog: Illegal or missing value for U_SLEEP - Using 60 seconds');
        $Iwatch{u_sleep} = 60;
    }

  
    #---------------------------------------------------------------------------------------
    #  Set the value of U_PURGE, which is the integer number of hours that defines the
    #  amount of time to keep process information on-line before it is purged.
    #---------------------------------------------------------------------------------------
    #
    $Iwatch{u_purge} = 24 unless defined $Iwatch{u_purge} and $Iwatch{u_purge};
    $Iwatch{u_purge} = 24 unless $Iwatch{u_purge} =~ /^\d+$/ and $Iwatch{u_purge} > 0;
    $Iwatch{u_purge} = 24 unless $Iwatch{u_purge} < 144;
    $Iwatch{u_purge} = $Iwatch{u_purge} * 3600;  #  Convert to seconds



    #---------------------------------------------------------------------------------------
    #  Set the value of U_HTMPAGE, which contains the path and filename of the HTML page
    #  used to provide information to the external user. This page is updated every U_SLEEP
    #  seconds with the status of ongoing simulations. If this parameter or no value is
    #  provided then no webpage will be created.
    #---------------------------------------------------------------------------------------
    #
    $Iwatch{u_htmpage} = '' unless $Iwatch{u_htmpage} and $Iwatch{u_htmpage};

    unless ($Iwatch{u_htmpage}) {
       &PrintFile($ENV{WDFH}||0,1,4,114,1,1,'Watchdog: U_HTMPAGE not assigned - Status Updates Via Web is Turned Off'); 
    }


    if ($Iwatch{u_htmpage}) {
        my ($path,$page) = &popit2($Iwatch{u_htmpage});
        unless (-e $path) {
            my $mesg = "The directory specified for U_HTMPAGE does not exist:\n\n".
                       "X02X$Iwatch{u_htmpage}\n\n".
                       "Check $cf and get back to me.";
            $ENV{WDMESG} = &TextFormat(0,0,94,0,2,'UEMS WatchDog Termination',$mesg);
            return ();
        }
        
        unless (-w $path) {
            my $mesg = "You do not have write permission to the directory specified by U_HTMPAGE:\n\n".
                       "X02X$path\n\n".
                       "Check $cf and get back to me.";
            $ENV{WDMESG} = &TextFormat(0,0,94,0,2,'UEMS WatchDog Termination',$mesg);
            return ();
        }
    }
    &PrintFile($ENV{WDFH}||0,0,1,114,1,0,' ');  #  Just adding a newline to output


    #---------------------------------------------------------------------------------------
    #  Set the value of U_SIMID, which defines the simulation ID and should be a string of
    #  placeholders that will by used in creating directories and log files associated with
    #  each simulation request.
    #---------------------------------------------------------------------------------------
    #
    $Iwatch{u_simid} = 'STID_NAME_PID'  unless defined $Iwatch{u_simid} and $Iwatch{u_simid};



    #--------------------------------------------------------------------------------------- 
    #  The value of U_MAXPROCS defines the maximum number of processes that can be running 
    #  simultaneously on the system.  Any requests arriving in U_INCOMING when the number
    #  of U_MAXPROCS has been achieved will wait in a queue until an existing simulation 
    #  has finished or crashed.   
    #
    #  Default: U_MAXPROCS = 1
    #---------------------------------------------------------------------------------------
    #
    my $u_maxprocs = 1;  # Default

    $Iwatch{u_maxprocs} = $u_maxprocs unless defined $Iwatch{u_maxprocs} and $Iwatch{u_maxprocs};
    $Iwatch{u_maxprocs} = $u_maxprocs unless $Iwatch{u_maxprocs} =~ /^\d+$/ and $Iwatch{u_maxprocs} > 0;
    $Iwatch{u_maxprocs} = $u_maxprocs unless $Iwatch{u_maxprocs} < 99;


    #---------------------------------------------------------------------------------------
    # Touch the dogrun file while we are here.
    #---------------------------------------------------------------------------------------
    #
    $Iwatch{dogrun} = "$Iwatch{u_logging}/.uems_watchdog"; system "touch $Iwatch{dogrun}";


return %Iwatch;
}


sub ReadConfigurationFile {
#==================================================================================
#  This routine reads the contents of an individual UEMS configuration file and
#  returns a hash containing parameter-value pairs where the values are contained
#  within a comma separated string. 
#==================================================================================
#
    my $cfile = shift;
    my %hash  = ();

    open (my $rfh, '<', $cfile); my @lines = <$rfh>; close $rfh; foreach (@lines) {chomp; tr/\000-\037/ /; s/^\s+//g;}

    foreach (@lines) {
        next if /^#|^$|^\s+/;
        s/\t//g;s/\n//g;
        if (/\s*=\s*/) {
            my ($var, $value) = split /\s*=\s*/, $_, 2;
            $value = '' unless length $value;  # Make sure everything is initialized to a value
            $hash{lc $var} = $value;
        }
    }

return %hash;
}


sub FileMatch {
#==================================================================================
#  This routine returns a list of files matching a specified string, reverse
#  sorted by creation time, from a directory. The arguments are:
#
#      $dir    -  The directory path to search
#      $string -  The string to match - "0" indicates get all files
#      $nodir  -  Whether to include (0) or not include (1) the full path in returned values
#      $nochk  -  0 (check) or 1 (don't check) the file size - Yes, the double neg is confusing
#      $srtby  -  Determines how files are to be sorted. Values are:
#       
#                    0 - No additional sorting (although may already be sorted)
#                 (-)1 - Alphabeticali/Numerical (default)
#                 (-)2 - File size
#                 (-)3 - Access Time (atime)
#                 (-)4 - Modified Time (mtime)
#                 (-)5 - Inode Change Time (ctime)
#
#                 A value below 0 indicates reverse order.
#==================================================================================
#   
#   
    my ($dir,$string,$nodir,$nochk,$srtby) = @_;  return () unless -d $dir;
    
    $nochk = 0 unless defined $nochk and $nochk; 
    $srtby = 0 unless defined $srtby and $srtby and $srtby=~/\d+$/;
    
    system "ls $dir > /dev/null 2>&1";  #  Workaround for update NFS issues
    
    #--------------------------------------------------------------------
    #  Read the directory - excluding . & ..
    #--------------------------------------------------------------------
    #
    opendir (my $dh, $dir) || return ();
    
    my @dfiles = grep !/^\./ => readdir $dh; closedir $dh;  return () unless @dfiles;
    my @files  = $string ? grep {/$string/} @dfiles : @dfiles;
    
    
    #--------------------------------------------------------------------
    #  Check again to make sure the file still exists before doing tests
    #  Also do $nochk test.  Note that following this step the @files
    #  array contains the full path to the file.
    #--------------------------------------------------------------------
    #  
    @dfiles = (); 
    if ($nochk) { 
        foreach (@files) {push @dfiles => "$dir/$_" if -f "$dir/$_";}
    } else { 
        foreach (@files) {push @dfiles => "$dir/$_" if -e "$dir/$_" and ! -z "$dir/$_";}
    } @files = @dfiles;

    
    #--------------------------------------------------------------------
    #  Sort the files according to the requested method. 
    #--------------------------------------------------------------------
    #
    if ($srtby ==  1) {@files = sort @files;}
    if ($srtby ==  2) {@files = sort {(stat $a)[7]  <=> (stat $b)[7]}  @files;}
    if ($srtby ==  3) {@files = sort {(stat $a)[8]  <=> (stat $b)[8]}  @files;}
    if ($srtby ==  4) {@files = sort {(stat $a)[9]  <=> (stat $b)[9]}  @files;}
    if ($srtby ==  5) {@files = sort {(stat $a)[10] <=> (stat $b)[10]} @files;}
    
    if ($srtby == -1) {@files = reverse sort @files;}
    if ($srtby == -2) {@files = sort {(stat $b)[7]  <=> (stat $a)[7]}  @files;}
    if ($srtby == -3) {@files = sort {(stat $b)[8]  <=> (stat $a)[8]}  @files;}
    if ($srtby == -4) {@files = sort {(stat $b)[9]  <=> (stat $a)[9]}  @files;}
    if ($srtby == -5) {@files = sort {(stat $b)[10] <=> (stat $a)[10]} @files;}
    
    if ($nodir) {$_ = &popit($_) foreach @files;}

return @files;
}  #  FileMatch
                                                                  


sub mkdir {
#==================================================================================
#  A wrapper routine for the system mkdir utility
#==================================================================================
#
    my $dir  = shift;

    return 'Missing directory name in &Others::mkdir' unless defined $dir and $dir;

    return 0 if -d $dir;

    my $err = `mkdir -m 755 -p $dir 2>&1`; chomp $err;

return $err;
} #  mkdir


sub rm {
#==================================================================================
#  This routine deletes files, links and directories if found. Ya, that's all
#==================================================================================
#
my $status = 0;

    foreach (@_) {
        return -1 unless $_;
        if    (-d)       { $status = system "rm -fr $_  > /dev/null 2>&1"; }
        elsif (-f or -l) { $status = system "rm -f  $_  > /dev/null 2>&1"; }
    }


return $status
} #  rm


sub rmdups {
#==================================================================================
#  This routine eliminates duplicates from a list.
#==================================================================================
#
    my @list=();
    my %temp=();

    foreach (@_) {push @list => $_ if defined $_;}
    return @list unless @list;

    @list = grep ++$temp{$_} < 2 => @list; 


return @list;
} #  rmdups



sub popit {
#==================================================================================
#  This routine accepts the fully qualified path/name and returns just
#  the name of the file or what ever was at the end if the string.
#==================================================================================
#
my $file = qw{};

    my $str = shift || return $file;

    for ($str) {
        return $file unless $_;

        s/\s+//g;
        s/^\.//g;
        s/\/+/\//g;
        s/\/$//g;

        my @list = split /\// => $_;
        $file = pop @list;
    }

return $file;
} #  popit


sub popit2 {
#==================================================================================
#  This routine accepts the fully qualified path/filename and returns
#  filename and the path.
#==================================================================================
#
my $file = '';
my $path = '';

    my $str = shift || return ($path,$file);

    for ($str) {
        return ($path,$file) unless $_;

        s/\s+//g;
        s/^\.//g;
        s/\/+/\//g;
        s/\/$//g;

        my @list = split /\// => $_;
        return ($path,$file) unless @list;

        $file = pop @list;
        $path = join '/' => @list;
    }

return ($path,$file);
} #  popit2






sub PrintFile {
#==================================================================================
#  This routine prints all error, warning, and information statements to the
#  user with a consistent format.
#==================================================================================
#
use Text::Wrap;
use IO::Handle;

    my %spaces = ();
       $spaces{X01X} = sprintf('%s',q{ } x 1);
       $spaces{X02X} = sprintf('%s',q{ } x 2);
       $spaces{X03X} = sprintf('%s',q{ } x 3);
       $spaces{X04X} = sprintf('%s',q{ } x 4);


    my ($fh,$type,$indnt,$cols,$leadnl,$trailnl,$head,$body,$text)  = @_;

    $fh = '' unless defined $fh and $fh;
    $fh->autoflush(1) if $fh;

    #  Note Types:
    #
    #    0 = ''
    #    1 - "*"
    #    2 - "\xe2\x98\xba"  Smiley Face
    #    3 - "\xe2\x98\x85"  Black sun with rays
    #    4 - "dbg"
    #    5 - "->"
    #    6 - "!"
    #    7 - "\xe2\x9c\x93" Check Mark
    #    9 - "\xe2\x98\xa0" Skull & Crossbones
    #    # - &GetFunCharacter

    #  Set defaults
    #
    local $Text::Wrap::columns = ($cols > 80) ? $cols : 80;  # sets the wrap point. Default is 80 columns.
    local $Text::Wrap::separator="\n";
    local $Text::Wrap::unexpand=0;  #  Was 1 - changed 3/2017

    my $nl = "\n";

    $head    = $nl unless $head;
    $indnt   = ! $indnt ? 0 : $indnt < 0 ? 0 : $indnt;
    $leadnl  = $leadnl  < 0 ? sprintf ("%s",$nl x 1) : sprintf ("%s",$nl x $leadnl);
    $trailnl = $trailnl < 0 ? sprintf ("%s",$nl x 1) : sprintf ("%s",$nl x $trailnl);

    #  Check for requested spaces as indicated by I\d\dX.
    #
    foreach my $nsp (keys %spaces) {
        $head =~ s/$nsp/$spaces{$nsp}/g if $head;
        $body =~ s/$nsp/$spaces{$nsp}/g if $body;
        $text =~ s/$nsp/$spaces{$nsp}/g if $text;
    }

    my $symb  = ($type == 0) ? q{}            :
                ($type == 1) ? '*'            :
                ($type == 2) ? "\xe2\x98\xba" :
                ($type == 3) ? "\xe2\x98\x85" :
                ($type == 4) ? 'dbg'          :
                ($type == 5) ? '+'            :
                ($type == 6) ? '!'            :
                ($type == 7) ? "\xe2\x9c\x93" :
                ($type == 8) ? '+'            :
                ($type == 9) ? "\xe2\x98\xa0" : &GetFunCharacter();


    $text  = $text ? " ($text)" : q{};

    #  Format the text
    #
    my $header = ($symb eq '*')     ? "$symb$text  " : 
                 ($symb eq '!')     ? "$symb$text  " : 
                 ($symb eq '+')     ? "$symb$text  " : 
                 ($symb =~ /dbg/)   ? "$symb$text: " : 
                 ($symb)            ? "$symb$text  " : q{};

    $head      = "$header$head";
    $body      = "\n\n$body" if $body;

    #  Format the indent
    #
    my $hindnt = $indnt < 0 ? sprintf('%s',q{ } x 1) : sprintf('%s',q{ } x $indnt);
    my $bindnt = sprintf('%s',q{ } x length "$hindnt$header");

    my $windnt = ($symb eq '*')     ? "   $hindnt"   : 
                 ($symb eq '+')     ? "   $hindnt"   : 
                 ($symb eq '!')     ? "   $hindnt"   : 
                 ($symb)            ? "   $hindnt"   : $bindnt;

    $| = 1;
    $fh ? print $fh $leadnl : print $leadnl;
    $fh ? print $fh wrap($hindnt,$windnt,$head)             : print wrap($hindnt,$windnt,$head);
    if ($body) {$fh ? print $fh wrap($windnt,$windnt,$body) : print wrap($windnt,$windnt,$body);}
    $fh ? print $fh "$trailnl" : print "$trailnl";


return;
} #  PrintFile



sub FileInfo {
#==================================================================================
#  This subroutine takes the fully qualified name of a file or directory and
#  and returns a hash containing all sorts of information used by the UEMS.
#==================================================================================
#
use Cwd;
use File::stat;

    my %fhash = ();
    my @fields = qw(realpath exists isfile islink isdir isread iswrite
                    isexec isowner size modsecs fdate fage uname);

    foreach (@fields) {$fhash{$_} = 0;}  #  Initialize the fields to zero
    
    my $file = shift; return %fhash unless defined $file and $file and -e $file;

    my $csecs = time();

    for ($file) {

        $fhash{realpath} = Cwd::realpath($_);
        $fhash{exists}   = -e $_ ? 1 : 0;
        $fhash{isfile}   = -f $_ ? 1 : 0;
        $fhash{islink}   = -l $_ ? 1 : 0;
        $fhash{isdir}    = -d $_ ? 1 : 0;
        $fhash{isread}   = -r $_ ? 1 : 0;
        $fhash{iswrite}  = -w $_ ? 1 : 0;
        $fhash{isexec}   = -x $_ ? 1 : 0;
        $fhash{isowner}  = -o $_ ? 1 : 0;
        $fhash{size}     = -s $_ ;
    
        my $sf   = stat $fhash{realpath};

        $fhash{modsecs}  = $sf->mtime;
        $fhash{fdate}    = gmtime $fhash{modsecs};
        $fhash{fage}     = $csecs - $sf->mtime;

        $fhash{uname}    = getpwuid($sf->uid);

    }

return  %fhash;
} #  FileInfo


       
sub TextFormat {
#==================================================================================
#  Routine to format a sentence/paragraph for printing.  The arguments are:
#
#  $h_indnt  -  Number of spaces to indent the 1st line of the string $head
#  $b_indnt  -  Number of spaces to indent remaining lines of $head or all of @body
#  $wrapcol  -  Column number at which to wrap the paragraph, independent of indent
#  $leadnl   -  Number of newlines before initial line of text
#  $trailnl  -  Number of newlines after final line of text
#  @body     -  Array of Character strings that make up the paragraph
#==================================================================================
#
use Text::Wrap;

    my $nl = "\n";

    my ($h_indnt,$b_indnt,$wrapcol,$leadnl,$trailnl,@body)  = @_;

    return '' unless @body;

    my $head = shift @body;

    #  Set defaults
    #
    local $Text::Wrap::columns = $wrapcol > 80 ? $wrapcol : 80;  # sets the wrap point. Default is 80 columns.
    local $Text::Wrap::separator="\n";
    local $Text::Wrap::unexpand=0;

    $h_indnt = 0 unless $h_indnt =~ /^\d+$/;
    $b_indnt = 0 unless $b_indnt =~ /^\d+$/;

    $h_indnt   = ! $h_indnt ? 0 : $h_indnt < 0 ? 0 : $h_indnt;
    $b_indnt   = ! $b_indnt ? 0 : $b_indnt < 0 ? 0 : $b_indnt;

    $leadnl  = $leadnl  < 0 ? sprintf ('%s',$nl x 1) : sprintf ('%s',$nl x $leadnl);
    $trailnl = $trailnl < 0 ? sprintf ('%s',$nl x 1) : sprintf ('%s',$nl x $trailnl);

    my $hindnt = $h_indnt < 0 ? sprintf('%s',q{ } x 1) : sprintf('%s',q{ } x $h_indnt);
    my $bindnt = sprintf('%s',q{ } x $b_indnt);

    my $bodyA = wrap($hindnt,$bindnt,$head); $bodyA = "$bodyA\n\n" if @body;
    my $bodyB = @body ? fill($bindnt,$bindnt,@body) : '';

return "$leadnl$bodyA$bodyB$trailnl";
} #  TextFormat



sub EpochSeconds2Pretty {
#==================================================================================
#  Input: Number of seconds since 1 January 1970 00:00:00 UTC
#  Out  : Something better looking and more informative
#==================================================================================
#
use POSIX 'strftime';

    my $epochs = shift;
    my $datestr = gmtime $epochs;

return $datestr;
} #  EpochSeconds2Pretty


sub ReturnHandler {
#==================================================================================
#  The purpose of this routine is to interpret the return codes from the various
#  mission control subroutines. Most of the real information is returned via the 
#  $MMESG environment variable and is printed to the screen before exiting.
#==================================================================================
#
    my $rc = shift || return 0;  #  Hey!  Return code or it never happened!

    my $umesg =   (defined $ENV{WDMESG} and $ENV{WDMESG}) ? $ENV{WDMESG} : "Something happened RC = $rc";

    &PrintFile($ENV{WDFH}||0,9,4,255,2,1,$umesg);


return $rc;
}


sub SysExecute {
#=================================================================================
#  This routine uses the Perl "exec" routines to run the passed command.  
#=================================================================================
#
    $SIG{INT} = \&SysIntHandle; 

    my ($prog, $log) = @_;

    my $cmd = $log ? "$prog > $log 2>&1" : $prog;

    my $pid = fork;

    exec $cmd unless $pid; 


return $pid;
} #  SysExecute



sub SysIntHandle {
#==================================================================================
#  Determines what to do following an interrupt signal or control-C.
#==================================================================================
#
    $ENV{VERBOSE} = 1;  #  Set to verbose mode regardless of what the user wanted
    $ENV{EMSERR}  = 1 unless defined $ENV{EMSERR} and $ENV{EMSERR};  #  Need a value here

    #------------------------------------------------------------------------------
    #  Let the user know how we feel about this
    #------------------------------------------------------------------------------
    #
    my @heys = ('Terminated!? Me? - But I was just getting this UEMS Watch Dog party started!',
                'Hey, I thought we were a team!',
                'You know, it would be a shame if something happened to your keyboard.',
                'I think you did that with a bit too much enthusiasm!',
                'I hope you enjoyed yourself!',
                'I hope this hurts you more than it hurts me!',
                'And I was just beginning to like you!');


    $ENV{EMSERR} == 2 ? &PrintFile($ENV{WDFH}||0,6,4,96,1,1,"Hey, just wait a moment while I finish my business!!") :
                        &PrintFile($ENV{WDFH}||0,2,4,96,2,1,sprintf "$heys[int rand scalar @heys]");


    $ENV{EMSERR} = 2;  #  Set the EMS return error so that the files can be processed correctly.

    
    sleep 2;  #  As a precaution


&SysExit(2);
} #  SysIntHandle


sub SysExit {
#==================================================================================
#  Override the default behavior and prints out a semi-informative message
#  when exiting. The routine takes three arguments, only one of which is
#  mandatory ($err) with $rout (recommended) identifying the calling routine
#  and $mesg, which serves to override the prescribed messages.
#==================================================================================
#
    #  Modified to get rid of Perl version issues with switch statement.
    #
    $ENV{VERBOSE} = 1;  #  Set to verbose mode regardless of what the user wanted

    my $date = gmtime;
    my $slog = '"Think Globally, Model Locally!"';

     
    my ($err, $rout) = @_;  $rout = 'UEMS Mission Control';

    $err  = 0 unless defined $err and $err;

    my @whos = ('As the UEMS Genie says',
                'Mark Twain wished he had said',
                'The UEMS Metaphysician says',
                'The scribbling on my doctor\'s prescription actually reads',
                'As the alchemists at Cambridge are fond of stating',
                'Michelangelo\'s hidden secret code in Sistine Chapel reads',
                'Alexander Graham Bell\'s first words on the telephone really were',
                'A little known tenet of Confucianism is',
                'The deciphered Voynich manuscript actually reads',
                'You can sometimes hear Tibetan Monks chant',
                'As Shields and Yarnell loved to gesticulate',
                'The very first message detected by SETI will be',
                'Smoke signals from the Vatican are often interpreted as',
                'Neil Armstrong\'s microphone cut out just before he said',
                'Alphanumeric code 6EQUJ5 will someday be interpreted as'
                );



    my $mesg = sprintf ("That was fun while it lasted, which is never long enough! - %s UTC",$date);
       $mesg = sprintf ("It doesn't matter who's at fault. I'm still throwing you under the bus! - %s UTC",$date) if $err;
       $mesg = sprintf ("UEMS Mission Monitor was terminated by Grumpy on %s UTC",$date) if $err == 2;


    &PrintFile($ENV{WDFH}||0,0,4,144,2,1,$mesg);
    &PrintFile($ENV{WDFH}||0,0,2,144,1,3,sprintf "$whos[int rand scalar @whos]: $slog");

    close  $ENV{WDFH} if defined $ENV{WDFH} and $ENV{WDFH};


CORE::exit $err;
} 



sub PrintHash {
#==================================================================================
#  This routine prints out the contents of a hash. If a KEY is passed then the
#  routine will only print key-value pairs beneath that KEY. If no KEY is passed
#  then the routine will print out all key-value pairs in the hash.
#  For Debugging only.
#==================================================================================
#
    my %type         = ();
    @{$type{scalar}} = ();
    @{$type{array}}  = ();
    @{$type{hash}}   = ();
    @{$type{struct}} = ();

    my ($href, $skey, $ns, $alt) = @_;

    my %phash = %{$href}; return unless %phash;
     
    $skey     = q{} unless $skey;
    $ns       = 0 unless $ns;
    $alt      = 'TOP LEVEL OF HASH'  unless $alt;

    foreach my $key (sort keys %phash) {
        for (ref($phash{$key})) {
            /hash/i   ?  push @{$type{hash}}   => $key   :
            /array/i  ?  push @{$type{array}}  => $key   :
            /struct/i ?  push @{$type{struct}} => $key   :
                         push @{$type{scalar}} => $key;
        }
    }

    print sprintf("\n%sHASH:  %s\n\n",q{ }x$ns,$skey) if $skey;
    print sprintf("\n  $alt:  %s\n\n",$skey) unless $ns;
    $ns+=4;

    foreach (sort @{$type{scalar}}) {my $refkey = $skey ? "{$skey}{$_}" : "{$_}"; print sprintf("%sSCALAR:   %-60s  %s\n",q{ }x$ns,$refkey,defined $phash{$_} ? $phash{$_}                 : "Value $refkey is not defined\n");}
    foreach (sort @{$type{array}})  {my $refkey = $skey ? "{$skey}{$_}" : "{$_}"; print sprintf("%sARRAY :   %-60s  %s\n",q{ }x$ns,$refkey,@{$phash{$_}}      ? join ', ' => @{$phash{$_}} : "Array $refkey is empty\n");}
    foreach (sort @{$type{hash}})   {&PrintHash(\%{$phash{$_}},$_,$ns);}
    foreach (sort @{$type{struct}}) {&PrintDsetStruct($phash{$_});}

#    print "\n";

return;
} #  PrintHash



