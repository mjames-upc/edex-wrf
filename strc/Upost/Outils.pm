#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Outils.pm
#
#  DESCRIPTION:  Outils contains various utilities used by ems_post
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Outils;

use warnings;
use strict;
require 5.008;
use English;

use vars qw ($mesg);

use Others;

sub FrequencySubset {
#==================================================================================
#  The &FrequencySubset routine subsets a list of files (@arg2) based upon a 
#  FREQ:START:STOP string ($arg1) and returns a list of matching files.
#==================================================================================
#
   my @subset = ();
   my ($freq,$start,$stop) = (1,0,100000);

   my ($fstr, @flist) = @_;  $fstr = '1:0:0' unless $fstr;

   my @freqs  = split /:/ => $fstr;

   $freq = $freqs[0] if $freqs[0];  $freq = int ($freq  +=0); return @flist if $freq =~ /^\D/i or $freq <= 1;
   $start= $freqs[1] if $freqs[1];  $start= int ($start +=0); $start = 0 if $start < 0;
   $stop = $freqs[2] if $freqs[2];  $stop = int ($stop  +=0); $stop  = 10000*$freq if $stop < $start; $start = 0 if $start > $stop;

   foreach my $file (@flist) {

       my ($init, @verfs) = &Others::FileFcstTimes($file);

       #  return entire list if more than one forecast in each file
       #
       if ($init and @verfs) {
           my $verfm    = (&Others::CalculateEpochSeconds($verfs[$#verfs])-&Others::CalculateEpochSeconds($init))/60;
           next if $verfm < $start or $verfm > $stop;
           push @subset => $file unless $verfm%$freq;
       }
   }

return @subset;
}


sub Grib2DateStrings {
#==================================================================================
#  If the name was not intuitive enough, the &Grib2DateStrings takes a GRIB 2
#  file and returns an array containing "place holder:value" pairs used in the
#  naming of GRIB 2 files with the UEMS UPP.
#==================================================================================
#
    my @pairs= ();
    my $grib = shift; return () unless $grib and -s $grib;


    #-------------------------------------------------------------
    #  Start by getting the initialization and verification 
    #  date/times from the GRIB file.
    #-------------------------------------------------------------
    #
    my $init = &Others::Grib2InitTime($grib);
    my $verf = &Others::Grib2VerifTime($grib);

   
    #-------------------------------------------------------------
    #  Compute the verification date/time in seconds from T0.
    #-------------------------------------------------------------
    #
    my $vsecs = &Others::CalculateEpochSeconds($verf) - &Others::CalculateEpochSeconds($init);


    #-------------------------------------------------------------
    #  Now slice & dice the date strings to get values for the 
    #  various placeholders that are used for grib file names:
    #
    #     YYYY - 4-digit Year  (Initialization)
    #     YY   - 2-digit Year  (Initialization)
    #     MM   - 2-digit Month (Initialization)
    #     DD   - 2-digit Day   (Initialization)
    #     HH   - 2-digit Hour (24-hour clock) (Initialization)
    #     MN   - 2-digit Minute (Initialization)
    #     SS   - 2-digit Second (Initialization)
    #     WD   - 2-digit domain number
    #
    #     V4Y  - 4-digit Year  (Verification)
    #     V2Y  - 2-digit Year  (Verification)
    #     VM   - 2-digit Month (Verification)
    #     VD   - 2-digit Day   (Verification)
    #     VH   - 2-digit Hour (24-hour clock) (Verification)
    #     VN   - 2-digit Minute (Verification)
    #     VS   - 2-digit Second (Verification)
    #
    #     FH   - 4-digit forecast hour (0 to forecast length - 0006, 0024, or 0144)
    #     FZ   - 3-digit forecast hour (0 to forecast length - 006, 024, or 144)
    #     FX   - Auto-adjusted 2 to 4 digit forecast hour (0 to forecast length - 06 or 24)
    #     FM   - 2-digit forecast minute (0 to 60)
    #     FS   - 2-digit forecast second (0 to 60)
    #-------------------------------------------------------------
    #

    #  The initialization date strings
    #
    my ($yyyy,$mm,$dd,$hh,$mn,$ss) = &Others::DateString2DateList($init); # Gives YYYY, MM, DD, HH, MN & SS
    my $yy = substr $yyyy,2,2;

    push @pairs, "YYYY:$yyyy";
    push @pairs, "YY:$yy";
    push @pairs, "MM:$mm";
    push @pairs, "DD:$dd";
    push @pairs, "HH:$hh";
    push @pairs, "MN:$mn";
    push @pairs, "SS:$ss";


    #  The verification date strings
    #
    my ($v4y,$vm,$vd,$vh,$vn,$vs) = &Others::DateString2DateList($verf); # Gives VY4, VM, VD, VH, VN & VS
    my $v2y = substr $v4y,2,2;
 
    push @pairs, "V4Y:$v4y";
    push @pairs, "V2Y:$v2y";
    push @pairs, "VM:$vm";
    push @pairs, "VD:$vd";
    push @pairs, "VH:$vh";
    push @pairs, "VN:$vn";
    push @pairs, "VS:$vs";
   
 
    #  Simulation length from T0 (forecast) strings
    #
    my $vhrs = int ($vsecs/3600); $vsecs = $vsecs - $vhrs * 3600;
    my $vmin = int ($vsecs/60);   $vsecs = $vsecs - $vmin * 60;

    my $fx = sprintf '%02d', $vhrs;  push @pairs, "FX:$fx";
    my $fz = sprintf '%03d', $vhrs;  push @pairs, "FZ:$fz";
    my $fh = sprintf '%04d', $vhrs;  push @pairs, "FH:$fh";
    my $fm = sprintf '%02d', $vmin;  push @pairs, "FM:$fm";
    my $fs = sprintf '%02d', $vsecs; push @pairs, "FS:$fs";

  
return @pairs;
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

    &Ecomm::PrintMessage(9,11+$arf,255,1,1,$mesg);
    
    my $log = &Others::popitlev($logfile,2);

    &Ecomm::PrintMessage(0,14+$arf,255,1,1,"Here is some information from $log:");

    my $ls  = @lines-25; $ls = 0 if $ls < 0;
    
    splice @lines, 0, $ls;

    &Ecomm::PrintMessage(0,14+$arf,144,1,1,"-" x 114);
    &Ecomm::PrintMessage(0,16+$arf,255,0,1,"Error Log: $_") foreach @lines;
    &Ecomm::PrintMessage(0,14+$arf,144,0,2,"-" x 114);


return;
}


sub SetNawipsEnvironment {
#==================================================================================
#  This routine sets a local NAWIPS environment for those subroutines needing it.
#==================================================================================
#
    my %Nawips = ();

    my $dist = shift; return () unless $dist and -d $dist;

    $ENV{NAWIPS} =  $dist;
    $ENV{GEMEXE} = "$dist/os/linux/bin";
    $ENV{GEMPAK} = "$dist/gempak";
    $ENV{GEMTBL} = "$dist/gempak/tables";
    $ENV{GEMPARM}= "$dist/gempak/parm";
    $ENV{GEMMAPS}= "$dist/gempak/maps";
    $ENV{GEMNTS} = "$dist/gempak/nts";
    $ENV{GEMERR} = "$dist/gempak/error";
    $ENV{GEMPDF} = "$dist/gempak/pdf";
    $ENV{GEMGTXT}= "$dist/gempak/txt/gemlib";


return %Nawips;
}



sub ProcessInterrupt {
#==================================================================================
#  If the user becomes impatient and interrupts the active process by pulling 
#  a Control-C, then clean up the domain directory before exiting.
#==================================================================================
#
    my ($proc, $err, $rundir, @deletes) = @_;

    foreach my $ref (@deletes) {Others::rm($_) foreach @$ref;}


&Ecore::SysExit($err);
}  #  ProcessInterrupt



sub ExportFiles {
#==================================================================================
#  Takes the information from the exports hash and works magic. Passed into
#  the routine is a hash reference containing the target location information,
#  method to use, and the files to transfer.
#  
#    $Export{mkdir} - 1|0 Whether to attempt creating a remote directory
#    $Export{host}  - Hostname of remote machine if any
#    $Export{meth}  - Method to use for transfer
#    $Export{rdir}  - Directory location on remote system (already populated)
#    @Export{files} - An array of file to transfer on the local system
#==================================================================================
#
    my $href = shift;   my %Export = %{$href};

    return 0 unless @{$Export{files}};

    #---------------------------------------------------------------------------
    #  Added for Mission Control but may be used with ems_post
    #---------------------------------------------------------------------------
    #
    $Export{mkdir} = 1 unless defined $Export{mkdir};
    $Export{mkdir} = 0 unless $Export{mkdir};

    &Ecomm::PrintHash(\%Export)   if $ENV{POST_DBG} > 0;

    return &FileTransfer_Copy(\%Export)  if $Export{meth} eq 'cp';
    return &FileTransfer_Rsync(\%Export) if $Export{meth} eq 'rsync';
    return &FileTransfer_SCP(\%Export)   if $Export{meth} eq 'scp';
    return &FileTransfer_FTP(\%Export)   if $Export{meth} eq 'ftp';
    return &FileTransfer_SFTP(\%Export)  if $Export{meth} eq 'sftp';


return;
}


sub FileTransfer_Copy {
#==================================================================================
#  This routine transfers a list of files via the copy command
#==================================================================================
#
use if defined eval{require Time::HiRes;} >0,  "Time::HiRes" => qw(time);

    my $err   = 0;
    my $sleep = 0.5; #  number of seconds between file transfers

    my $href = shift;   my %Export = %{$href};  return 0 unless @{$Export{files}};

    &Ecomm::PrintMessage(0,14+$Export{arf},255,1,1,"Initiating file copy to $Export{rdir}");


    #  Need to create the remote directory
    #
    if ($Export{mkdir} and $err = &Others::mkdir($Export{rdir})) {
        &Ecomm::PrintMessage(6,14+$Export{arf},255,1,1,"FileTransfer_Copy: Failed to create $Export{rdir}",$err);
        &Ecomm::PrintMessage(0,14+$Export{arf},92,1,1,'File Copy Terminated') unless $err;
        return 1;
    }

    my $secs = time();
    foreach my $file (sort @{$Export{files}}) {

        my $sizemb = &Others::Bytes2MB(&Others::FileSize($file));  next unless $sizemb;

        my $locfile = &Others::popit($file);
        my $remfile = "$Export{rdir}/$locfile";

        &Ecomm::PrintMessage(0,16+$Export{arf},144,1,0,"File Copy: $locfile -");

        unless (-s $file) {&Ecomm::PrintMessage(0,1,144,0,1,"is Missing! Possible NFS problem?"); next;}

        if (my $err = `cp -f $file $remfile 2>&1`) { chomp $err;
            &Ecomm::PrintMessage(0,1,144,0,1,"Failed : ($?)");
            &Ecomm::PrintMessage(0,18+$Export{arf},255,1,1,"$err") if $err;
            &Ecomm::PrintMessage(0,16+$Export{arf},255,1,1,"Premature termination of file copy") unless $err;
            return 1;
        } else {
            &Ecomm::PrintMessage(0,1,144,0,0,sprintf("%.2f MBs of pure export bliss",$sizemb));
            sleep $sleep unless $file eq $Export{files}[-1];
        }
    }

    &Ecomm::PrintMessage(0,14+$Export{arf},255,2,1,sprintf("Completed file copy in %s",&Ecomm::FormatTimingString(time()-$secs)));


return 0;
} #  FileTransfer_Copy



sub FileTransfer_Rsync {
#==================================================================================
#  This routine transfers a list of files via the rsync command
#==================================================================================
#
use if defined eval{require Time::HiRes;} >0,  "Time::HiRes" => qw(time);

    my $sleep = 0.5; #  number of seconds between file transfers

    my $href  = shift;   my %Export = %{$href};  return 0 unless @{$Export{files}};


    $Export{host} = '' if $Export{host} =~ /^local/i;
    $Export{host} ? &Ecomm::PrintMessage(0,14+$Export{arf},255,1,1,"Initiating rsync of files to $Export{host}:$Export{rdir}") :
                    &Ecomm::PrintMessage(0,14+$Export{arf},255,1,1,"Initiating rsync of files to $Export{rdir}");


    if ($Export{mkdir}) {
        if ($Export{host}) {
            if (system "ssh -q $Export{host} mkdir -p $Export{rdir} > /dev/null 2>&1") {
                my $mesg0 = "SSH Problem creating $Export{rdir} on $Export{host}";
                my $mesg1 = "Make sure that you are configured to run ssh commands such as:\n\n".
                            "  % ssh $Export{host} mkdir -p $Export{rdir} \n\nbefore trying rsync gain.";
                &Ecomm::PrintMessage(6,14+$Export{arf},144,1,1,$mesg0,$mesg1);
                &Ecomm::PrintMessage(9,14+$Export{arf},144,1,2,"Rsync to $Export{host} terminated");
                return 1;
            }
        } else {
            if (my $err = &Others::mkdir($Export{rdir})) { chomp $err;
                &Ecomm::PrintMessage(6,14+$Export{arf},255,1,1,"FileTransfer_Rsync: Failed to create $Export{rdir}",$err);
                &Ecomm::PrintMessage(0,14+$Export{arf},92,1,1,'File Rsync Terminated') unless $err;
                return 1;
            }
        }
    }


    my $secs = time();
    foreach my $file ( sort @{$Export{files}} ) {

        my $sizemb = &Others::Bytes2MB(&Others::FileSize($file));  next unless $sizemb;

        my $locfile = &Others::popit($file);
        my $remfile = "$Export{rdir}/$locfile";

        &Ecomm::PrintMessage(0,16+$Export{arf},144,1,0,"Rsync File: $locfile -");

        unless (-s $file) {&Ecomm::PrintMessage(0,1,144,0,1,"is Missing! Possible NFS problem?"); next;}

        my $args = $Export{host} ? "-aq --no-l $file $Export{host}:$remfile" : "-aq --no-l $file $remfile";
        my $loc  = $Export{host} ? "$Export{host}:$remfile" : $remfile;

        if (my $err = `rsync $args 2>&1`) { chomp $err;
            &Ecomm::PrintMessage(0,1,144,0,1,"Failed : ($?)");
            &Ecomm::PrintMessage(0,18+$Export{arf},255,1,1,$err) if $err;
            &Ecomm::PrintMessage(0,16+$Export{arf},255,1,1,"Premature termination of rsync") unless $err;
            return 1;
        } else {
            &Ecomm::PrintMessage(0,1,144,0,0,sprintf("%.2f MBs of rsync'n fun",$sizemb));
            sleep $sleep unless $file eq $Export{files}[-1];
        }
    }
    &Ecomm::PrintMessage(0,14+$Export{arf},255,2,1,sprintf("Completed rsync in %s",&Ecomm::FormatTimingString(time()-$secs)));


return 0;
} #  FileTransfer_Rsync



sub FileTransfer_SCP {
#==================================================================================
#  This routine transfers a list of files via the SCP command
#==================================================================================
#
use if defined eval{require Time::HiRes;} >0,  "Time::HiRes" => qw(time);

    my $sleep = 0.5; #  number of seconds between file transfers

    my $href  = shift;   my %Export = %{$href};  return 0 unless @{$Export{files}};

    $Export{host} = '' if $Export{host} =~ /^local/i;
    &Ecomm::PrintMessage(0,14+$Export{arf},255,1,1,"Initiating scp of files to $Export{host}:$Export{rdir}");

    if ($Export{mkdir}) {
        if ($Export{host}) {
            if (system "ssh -q $Export{host} mkdir -p $Export{rdir} > /dev/null 2>&1") {
                my $mesg0 = "SSH Problem creating $Export{rdir} on $Export{host}";
                my $mesg1 = "Make sure that you are configured to run ssh commands such as:\n\n".
                        "  % ssh $Export{host} mkdir -p $Export{rdir} \n\nbefore trying scp gain.";
                &Ecomm::PrintMessage(6,14+$Export{arf},144,1,1,$mesg0,$mesg1);
                &Ecomm::PrintMessage(9,14+$Export{arf},144,1,2,"scp to $Export{host} terminated");
                return 1;
            }
        } else {
            if (my $err = &Others::mkdir($Export{rdir})) { chomp $err;
                &Ecomm::PrintMessage(6,14+$Export{arf},255,1,1,"FileTransfer_SCP: Failed to create $Export{rdir}",$err);
                &Ecomm::PrintMessage(0,14+$Export{arf},92,1,1,'File Rsync Terminated') unless $err;
                return 1;
            }
        }
    }


    my $secs = time();
    foreach my $file ( sort @{$Export{files}} ) {

        my $sizemb = &Others::Bytes2MB(&Others::FileSize($file));  next unless $sizemb;

        my $locfile = &Others::popit($file);
        my $remfile = "$Export{rdir}/$locfile";

        &Ecomm::PrintMessage(0,16+$Export{arf},144,1,0,"SCP File: $locfile -");

        unless (-s $file) {&Ecomm::PrintMessage(0,1,144,0,1,"is Missing! Possible NFS problem?"); next;}

        my $args = $Export{host} ? "-B -q -p $file $Export{host}:$remfile" : "-q $file $remfile";
        my $loc  = $Export{host} ? "$Export{host}:$remfile" : $remfile;

        if (my $err = `scp $args 2>&1`) { chomp $err;
            &Ecomm::PrintMessage(0,1,144,0,1,"Failed : ($?)");
            &Ecomm::PrintMessage(0,18+$Export{arf},255,1,1,$err);
            &Ecomm::PrintMessage(0,16+$Export{arf},255,1,1,'Premature termination of SCP');
            return 1;
        } else {
            &Ecomm::PrintMessage(0,1,144,0,0,sprintf("%.2f MBs of booty-mov'n success",$sizemb));
            sleep $sleep unless $file eq $Export{files}[-1];
        }
    }
    &Ecomm::PrintMessage(0,14+$Export{arf},255,2,1,sprintf("Completed secure copy in %s",&Ecomm::FormatTimingString(time()-$secs)));


return 0;
} #  FileTransfer_SCP



sub FileTransfer_FTP {
#==================================================================================
#  This routine transfers a list of files via the FTP command. It may or may not
#  work since I no longer have an FTP server on which to test.
#==================================================================================
#
use if defined eval{require Time::HiRes;} >0,  "Time::HiRes" => qw(time);
use Net::FTP;

    my $DEBUG = 0;
    my $pass  = 1;
    my $sleep = 0.5; #  number of seconds between file transfers

    my $href  = shift;   my %Export = %{$href};  return 0 unless @{$Export{files}};

    &Ecomm::PrintMessage(0,14+$Export{arf},255,1,1,"Initiating FTP of files to $Export{host}:$Export{rdir}");


    #  Set up ftp connection
    #
    my $ftp=qw{};
    unless ($ftp=Net::FTP->new(lc $Export{host}, Debug => $DEBUG, Passive => $pass)) {print "           CONNECTION ERROR: $@ \n\n";return 1;}
    unless ($ftp->login())                                                           {print "           LOGIN ERROR : ",$ftp->message(),"\n";return 1;}

    $ftp->binary();
    $ftp->mkdir($Export{rdir},'true') if $Export{mkdir};


    foreach my $file ( sort @{$Export{files}} ) {

        my $sizemb = &Others::Bytes2MB(&Others::FileSize($file));  next unless $sizemb;

        my $locfile = &Others::popit($file);
        my $remfile = "$Export{rdir}/$locfile";

        &Ecomm::PrintMessage(0,16+$Export{arf},144,1,0,"Transferring File: $locfile -");

        unless (-s $file) {&Ecomm::PrintMessage(0,1,144,0,1,"is Missing! Possible local NFS problem?"); next;}

        my $secs = time();
        if (!$ftp->put($file,$remfile)) {
            &Ecomm::PrintMessage(0,1,84,0,1,"Failed");
            &Ecomm::PrintMessage(0,16+$Export{arf},255,1,1,sprintf ("Premature termination of FTP - %s",$ftp->message()));
            return 1;
        } else {
            $secs = time() - $secs; $secs = 0.01 unless $secs;
            &Ecomm::PrintMessage(0,1,255,0,0,sprintf("Antiquated FTP success in %.1f seconds",$secs));
            sleep $sleep unless $file eq $Export{files}[-1];
        }

    }

    &Ecomm::PrintMessage(0,14+$Export{arf},255,2,1,"Completed Old School FTP Transfer");


return 0;
} #  FileTransfer_FTP



sub FileTransfer_SFTP {
#==================================================================================
#  This routine transfers a list of files via the Secure FTP command. It may
#  or may not work since I no longer have an FTP server on which to test.
#==================================================================================
#
use if defined eval{require Time::HiRes;} >0,  "Time::HiRes" => qw(time);

    my $href = shift;   my %Export = %{$href};  return 0 unless @{$Export{files}};

    &Ecomm::PrintMessage(0,14+$Export{arf},255,1,1,"Initiating Secure FTP of files to $Export{host}:$Export{rdir}");

    #  =================================================================================
    #  Begin by creating the directory on the remote host. Note that I'm failing to trap
    #  for errors since if the directory already exists on the remote system $fh will
    #  return a cryptic error that is not possible to distinguish from other errors. Thus
    #  we just have to let the user figure out the problem. Also, $fh will not create
    #  more than one level of directories.
    #  =================================================================================
    #
    if ($Export{mkdir}) {
        &Others::rm('sftp.in');
        open (my $fh,'>', 'sftp.in');
        print $fh "mkdir -p $Export{rdir}\n";
        print $fh "exit\n";
        close $fh;
        system "sftp -b $fh.in $Export{host} > /dev/null 2>&1";
    }


    #  =================================================================================
    #
    &Others::rm('sftp.in');
    
    open (my $fh,'>', 'sftp.in');

    foreach my $file ( sort @{$Export{files}} ) {
        my $locfile = &Others::popit($file);
        my $remfile = "$Export{rdir}/$locfile"; $remfile =~ s/\/\//\//g;
        &Ecomm::PrintMessage(0,16+$Export{arf},144,0,1,"Transfering File: $locfile");
        unless (-e $file) {
            &Ecomm::PrintMessage(0,1,144,0,0,'is Missing! Possible local NFS problem?');
            next;
        }
        print $fh "put $file $remfile\n";
    }
    print $fh "exit\n";
    close $fh;
    
    &Others::rm('/tmp/sftp.log');

    if (system "sftp -b sftp.in $Export{host} > /tmp/sftp.log 2>&1") {
        my $mesg0 = "Premature termination of secure FTP to $Export{host}";
        my $mesg1 = "Possibly due to an inability to create a remote directory. ".
                    "See /tmp/sftp.error for a few details.";
        &Ecomm::PrintMessage(6,18+$Export{arf},86,1,1,$mesg0,$mesg1);

        system "mv /tmp/sftp.log /tmp/sftp.error";

        &Ecomm::PrintMessage(9,16+$Export{arf},144,1,2,sprintf ("Secure file transfer terminated",lc $Export{host}));
        return 1;
    }
    &Ecomm::PrintMessage(0,14+$Export{arf},255,2,1,"Completed Old School Secure FTP Transfer");


return 0;
} #  FileTransfer_SFTP


sub PostCleaner {
#=====================================================================
#  This routine is the ems_run front end that calls the UEMS
#  cleaning utility.  Each one of the run-time routines should have 
#  a similar subroutine in its arsenal.  This routine should probably
#  be moved to the Eclean module, but I'm too lazy.
#=====================================================================
#
use Eclean;

    my ($level, $domain, $autorun) = @_; return unless $domain;

    return 0 if $autorun or $level < 0;  

    my @args = ('--domain',$domain,'--level',$level,'--silent');

    
return &Eclean::CleanDriver(@args);
}



