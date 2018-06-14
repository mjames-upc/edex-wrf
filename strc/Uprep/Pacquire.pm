#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Pacquire.pm
#
#  DESCRIPTION:  Pacquire contains each of the primary routines used for the 
#                acquisition and preparation of datasets to be included in
#                the initialization of a numerical weather prediction (NWP)
#                simulation using the Unified Environmental Modeling System 
#                (UEMS).
#                
#                This module is called from either the ems_autorun.pl or 
#                ems_prep.pm routines and returns a value to indicate success,
#                failure, or something in between.
#
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Pacquire;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Uprep $status);

use Others;
use Ecomm;
use Ecore;


sub PrepDataAcquisition {
#==================================================================================
#  This routine goes through the initialization dataset types and attempts to
#  acquire the desired files by every means possible. It refuses to give until
#  completely exhausted. It's kind of like a dog, only different.
#==================================================================================
#
    my %rcs       = &ReturnMessages();
    my $upref     = shift; %Uprep = %{$upref};

    my %initdsets = %{$Uprep{initdsets}};

    #------------------------------------------------------------------------------
    #  Attempt to acquire the requested file from each dataset. The status value
    #  return from &AcquireDataset_ICBCs in $initdsets{$ds}->status determines
    #  the message to print, if any, and how to proceed.  When using multiple data
    #  sets for the initial and boundary condition files, the loop must not exit
    #  until both datasets are attempted.
    #  
    #  In some cases an error is encountered after a partial download occurred, in
    #  which case the %Uprep hash is returned with an error number in $Uprep{error}.
    #------------------------------------------------------------------------------
    #
    $Uprep{error} = 0;
    $Uprep{mesg}  = $rcs{0}{mesg};


    foreach my $ds (qw(ICS BCS LSM SFC)) {

        if ($initdsets{$ds}) {

            $initdsets{$ds} = &AcquireDataset_ICBCs($initdsets{$ds});

            #  Set the status of any surface dataset to 0 since the simulation
            #  continues without it.
            #
            unless ($Uprep{error}) {
                $Uprep{mesg}  = $rcs{$initdsets{$ds}->status}{mesg};
#               $initdsets{$ds}->status(0) if $initdsets{$ds}->useid == 5;
                $Uprep{error} = $rcs{$initdsets{$ds}->status}{stat} if $initdsets{$ds}->status;
            }

            next if $initdsets{$ds}->useid == 2;  # Continue on to BC if IC dataset failed 

            return %Uprep if $initdsets{$ds}->status and $initdsets{$ds}->useid != 5;
        }
    }
    %{$Uprep{initdsets}} = %initdsets;


return %Uprep;
}



sub DefineInitFiles {
#==================================================================================
#  This routine populates a list of initialization files with the correct dates
#  and filenames on both the local and remote systems based on the information
#  provided in the <dataset>_gribinfo.conf file and user input.
#==================================================================================
#
     my %dsfiles = ();
     my $locall  = 0;

     my ($locfile,$remfile,$yyyymmddcc,$initfm,$finlfm,$freqfm,$analys) = @_;

     my $cdate = &Others::DateString2DateString($yyyymmddcc,'yyyymmddccmn');  # The cycle date and time used as basis

     for (my $minutes = $initfm; $minutes <= $finlfm; $minutes+=$freqfm) {

         my $cmin  = ($analys >= 0) ? $analys : $minutes;
         my $ffmn  = sprintf('%02d',$cmin%60);
         my $ffhr  = sprintf('%02d',int($cmin/60));
         my $fffhr = sprintf('%03d',int($cmin/60));

         #  Note that $cdate contains the cycle date & time for the dataset and $adate is the forecast
         #  date & time. This distinction may be is important depending upon the naming convention of the
         #  files to be acquired or whether this is an analysis dataset.
         #
         my $vdate = &Others::CalculateNewDate($cdate,$minutes*60);
         my $adate = ($analys >= 0) ? &Others::DateString2DateString($vdate,'yyyymmddccmn') : $cdate;

         my $lfile = &Others::PlaceholderFillDate($locfile,$adate,"NN:$ffmn","FFF:$fffhr","FF:$ffhr","ZEROHR:$yyyymmddcc","VALIDTIME:$vdate");
         my $rfile = &Others::PlaceholderFillDate($remfile,$adate,"NN:$ffmn","FFF:$fffhr","FF:$ffhr","ZEROHR:$yyyymmddcc","VALIDTIME:$vdate");

         #  Check whether the file already resides on the local system
         #
         $dsfiles{$lfile}{remfile} = $rfile;
         $dsfiles{$lfile}{lsize}   = -e $lfile ? -s $lfile : 0;

     }


return %dsfiles;
}


sub AcquireDataset_ICBCs {
#==================================================================================
#  This routine attempts to acquire the GRIB files requested for model
#  initialization. The grib directory is initially checked to see whether
#  the files already exist locally, and if not then attempts to get them.
#  The routine returns a data structure (same as that passed) that has
#  been updated with the list of files retrieved and the status of 
#  the effort.  Upon return, the $dstruct->status value will be one of
#  the following:
#  
#     -1  :  An problem occurred during file acquisition
#      0  :  All requested file exist in the grib directory
#      1  :  Some of the files are missing from the grib directory.
#      2  :  All the files are missing from the grib directory.
#      
#==================================================================================
#
use List::Util qw(shuffle);

    my ($fstruct,$cstruct);

    my $dstruct = shift;

    return qw{} unless defined $dstruct;

    #----------------------------------------------------------------------------------
    #  Some of the information we will need to determine the files needed to 
    #  download and initialize the simulation.
    #----------------------------------------------------------------------------------
    #
    my $yyyymmddcc = $dstruct->yyyymmddcc; #  Date & cycle hour of dataset


    STRUCT: while (defined $dstruct) {

        @{$dstruct->gribs} = ();  #  Just to make sure
        $dstruct->status(0);

        my $yyyymmddcc = $dstruct->yyyymmddcc; #  Date & cycle hour of dataset
        my $ptile      = $dstruct->ptile ? $dstruct->dset : 0; $ptile =~ s/pt$//ig;

        my $dset    = uc $dstruct->dset;
        my %sources = %{$dstruct->sources};
        my $locfile = $dstruct->locfil;  #  The local filename with placeholders

        my $initfm  = $dstruct->initfm;
        my $finlfm  = $dstruct->finlfm;
        my $freqfm  = $dstruct->freqfm;

        my $analys  = $dstruct->analysis;


        #----------------------------------------------------------------------------------
        #  Provide some information to user
        #----------------------------------------------------------------------------------
        #
        my $files = $ptile ? 'personal tiles' : 'files';
        my $local = $dstruct->local ? 'Checking grib directory for' : 'Searching for';
        my $aged  = $dstruct->aged; $aged  = $aged  ? " up to $aged days old" : '';

        my $use = "Locating $dset files for nefarious purposes";  #  The default value
           $use = sprintf ("$local a $dset file to initialize a global simulation")               if $dstruct->useid == 0;
           $use = sprintf ("$local $dset $files to use as model initial and boundary conditions") if $dstruct->useid == 1;
           $use = sprintf ("$local $dset $files to use as model initial conditions")              if $dstruct->useid == 2;
           $use = sprintf ("$local $dset $files to use as model lateral boundary conditions")     if $dstruct->useid == 3;
           $use = sprintf ("$local $dset $files to augment land surface fields")                  if $dstruct->useid == 4;
           $use = sprintf ("$local $dset $files$aged to use with model surface fields")           if $dstruct->useid == 5;

        &Ecomm::PrintMessage(1,11+$Uprep{arf},255,1,1,&Ecomm::TextFormat(0,0,255,0,0,$use));

        
        #----------------------------------------------------------------------------------
        #  If this is a static surface dataset ($dstruct->useid == 5) and $dstruct->aged
        #  is greater then 0, we need to loop over the period window until a file is 
        #  is found. All we need is one file. For any other dataset the $dstruct->aged = 0
        #----------------------------------------------------------------------------------
        #
        for (my $age = 0; $age <= $dstruct->aged; $age++) {

            $yyyymmddcc = substr(&Others::CalculateNewDate($yyyymmddcc, $age ? -86400 : 0),0,10);

            #----------------------------------------------------------------------------------
            #  Before we enter the loop looking for data files make sure they doe not already 
            #  reside in the local grib directory. Use DefineInitFiles to create a list of 
            #  filenames for comparison with those in the local grib directory. The remote
            #  filename place is not necessary at the moment since we are only looking in the 
            #  local directory. If the files already exist then there is no need to enter
            #  the foreach method-server loop.
            #----------------------------------------------------------------------------------
            #
            my %dsfiles = &DefineInitFiles($locfile,'notused',$yyyymmddcc,$initfm,$finlfm,$freqfm,$analys);


            #----------------------------------------------------------------------------------
            #  If the files already exist locally then the file size will be located in 
            #  $dsfiles{$lfile}{lsize}. If the file size is zero it does not exist in the 
            #  local directory.
            #----------------------------------------------------------------------------------
            #
            my $nfiles = keys %dsfiles;
            my $tfiles = $nfiles;
            foreach (keys %dsfiles) {$nfiles-- if $dsfiles{$_}{lsize};}
            
            unless ($nfiles) {
                &Ecomm::PrintMessage(2,11+$Uprep{arf},255,1,1,'The data files are already at home in your grib directory');
                @{$dstruct->gribs} = sort keys %dsfiles;
                $age = $dstruct->aged+1;
                %sources  = ();
            }

        
            #----------------------------------------------------------------------------------
            #  If the local flag was passed then only check the local grib directory for 
            #  the files. If $nfiles has a non-zero value then some files were missing. If 
            #  any files are missing then provide a summary of those files that exist and 
            #  those that do not.
            #----------------------------------------------------------------------------------
            #  
            if ($dstruct->local and $nfiles)  {
    
                foreach my $lfile (sort keys %dsfiles) {
                    &Ecomm::PrintMessage(0,14+$Uprep{arf},255,1,0,sprintf("File %s",&Others::popit($lfile)));
                    $dsfiles{$lfile}{lsize} ? &Ecomm::PrintMessage(0,14+$Uprep{arf},255,0,0,' - Exists') : &Ecomm::PrintMessage(0,14+$Uprep{arf},255,0,0,' - Missing');
                }
    
                my $str = ($nfiles == 1) ? "missing file" : "$nfiles missing files";
                &Ecomm::PrintMessage(0,11+$Uprep{arf},255,2,2,"You'll have to locate the $str and try again. Oh ya, have a nice day!");
                $nfiles == $tfiles ? $dstruct->status(10*$dstruct->useid+2) : $dstruct->status(10*$dstruct->useid+1);
                $age = $dstruct->aged+1;
                %sources  = ();
            }


            #----------------------------------------------------------------------------------
            #  Loop through all the server-method options listed in the <dset>_gribinfo.conf 
            #  file in search of the requested data files. If the files were found locally
            #  then %sources should have been deleted and thus to attempt will be made. The 
            #  %nometh hash keep track of methods that failed internally to avoid trying them
            #  repeatedly. Unfortunately it's memory is short-lived.
            #----------------------------------------------------------------------------------
            #
            my %nometh = ();
            foreach my $method (shuffle keys %sources) {  #  Attempt to semi randomize the order
           
                $nometh{$method} = 0;
     
                foreach my $server (shuffle keys %{$sources{$method}}) {  #  Select the 
    
                    next if $nometh{$method};
    
                    #----------------------------------------------------------------------------------
                    #  If $nfiles has a non-zero value means initialization files are still missing
                    #----------------------------------------------------------------------------------
                    #
                    if ($nfiles) {

                        my $status  = 0;
                        my $remfile = $sources{$method}{$server}; #  $remfile is the path/filename with placeholders on the remote system
                        my %dsfiles = &DefineInitFiles($locfile,$remfile,$yyyymmddcc,$initfm,$finlfm,$freqfm,$analys);
        
                        $status = &FileDownload_FTP($server,%dsfiles)          if $method =~ /ftp/i;
                        $status = &FileDownload_HTTP($server,%dsfiles)         if $method =~ /http$/i;
                        $status = &FileDownload_HTTPS($server,%dsfiles)        if $method =~ /https/i;
                        $status = &FileDownload_PTILE($ptile,$server,%dsfiles) if $method =~ /ptile/i;
                        $status = &FileDownload_LOCAL($server,%dsfiles)        if $method =~ /nfs/i;
    
                        $status = $dstruct->useid*10+$status if $status > 0;
    
                        $nometh{$method} = 1 if $status == -1;
    
                        #  Populate the dstruct->gribs array unless there was a problem
                        #
                        @{$dstruct->gribs} = sort keys %dsfiles unless $status;
     
                        #----------------------------------------------------------------------------------
                        #  Setting $nfiles = 0 allows for the continuation to the next dataset in the
                        #  list. It does not necessarily mean that all the files have been acquired.
                        #----------------------------------------------------------------------------------
                        #
                        $nfiles = 0 unless $status;
                        
                        #----------------------------------------------------------------------------------
                        #  Some errors require that the server-method loop be terminated. These include 
                        #  configuration problems and situations when the areal coverage of domain falls
                        #  outside that of the dataset. Set $nfiles = 0 but define status.
                        #----------------------------------------------------------------------------------
                        #
                        $nfiles = 0 if $status == -3;
    
                        if ($dstruct->useid == 5 and ! $status) {
                            $age = $dstruct->aged+1;
                            $dstruct->yyyymmddcc($yyyymmddcc);
                        }
                        
    
                        $dstruct->status($status);

                    }  #  if $nfiles
                }  #  foreach my $server
            }  #  foreach my $method

        }  #  for $aged 0 .. $dstruct->aged

        if (defined $fstruct) {
            $cstruct->nlink($dstruct);
            $cstruct = $dstruct
        } else {
            $fstruct = $dstruct;
            $cstruct = $dstruct;
        }

        $fstruct->status($dstruct->status) if $dstruct->status;

        $dstruct = $dstruct->nlink;

    }


return $fstruct;
}



sub ReturnMessages {
#==================================================================================
#  Routine to define the error messages and return codes 
#  
#    0  - All good, or good enough - carry on
#    23 - Something went wrong - failure
#    24 - LSM file error - try next on list
#==================================================================================
#
    my %errmsgs = ();
       for my $i (-10 .. 256) {$errmsgs{$i}{stat} = 99; $errmsgs{$i}{mesg} = 'What the ^&$*%*@42 just happened?!';}

       $errmsgs{-3}{stat} = 22;
       $errmsgs{-3}{mesg} = 'Domain too large for dataset? This didn\'t end well!';

       $errmsgs{-2}{stat} = 21;
       $errmsgs{-2}{mesg} = 'Technical difficulties? This didn\'t end well!';

       $errmsgs{-1}{stat} = 21;
       $errmsgs{-1}{mesg} = 'Are we having a bad UEMS day?';


       #  All good
       #
       $errmsgs{0}{stat}  = 0;
       $errmsgs{0}{mesg}  = 'Excellent! - Your master plan is working!';

       #  Usage ID = 0 - Global IC file
       #
       $errmsgs{1}{stat}  = 23;
       $errmsgs{1}{mesg}  = 'Semi-excellence achieved! - Your master plan is (almost) working!';

       $errmsgs{2}{stat}  = 23;
       $errmsgs{2}{mesg}  = 'Without an initialization data file, your plan for world domination will just have to wait.';

       #  Usage ID = 1 - IC & BC files
       #
       $errmsgs{11}{stat} = 23;
       $errmsgs{11}{mesg} = 'Unfortunately, some of your initialization files were unavailable, but at least you still look good!';

       $errmsgs{12}{stat} = 23;
       $errmsgs{12}{mesg} = 'Sorry your Royal Awesomeness, but none of the initialization files were available.';

       #  Usage ID = 2 - IC file
       #
       $errmsgs{22}{stat} = 23;
       $errmsgs{22}{mesg} = 'Sorry your Royal Awesomeness, but the initial condition file was not available.';

       #  Usage ID = 3 - BC files
       #
       $errmsgs{31}{stat} = 23;
       $errmsgs{31}{mesg} = 'I\'m sorry to report that some of your boundary condition files went missing. But keep trying anyway!';

       $errmsgs{32}{stat} = 23;
       $errmsgs{32}{mesg} = 'Sorry my Lord/Lady of Awesome, but none of your boundary condition files were available.';

       $errmsgs{41}{stat} = 24;
       $errmsgs{41}{mesg} = 'I tried, but some of your LSM files were unavailable.';

       #  Usage ID = 4 - LSM files
       #
       $errmsgs{42}{stat} = 24;
       $errmsgs{42}{mesg} = 'Well that\'s unfortunate - none of your LSM files were available.';

       #  Usage ID = 5 - SFC files
       #
       $errmsgs{51}{stat} = 0;
       $errmsgs{51}{mesg} = 'Some of your surface files were unavailable - I found the best ones though, just for you.';

       $errmsgs{52}{stat} = 0;
       $errmsgs{52}{mesg} = 'Darn, surface files went missing - You don\'t need them anyway.';
       

return %errmsgs
}


sub FileDownload_HTTP {
#==================================================================================
#  This routine download the requested files to the local system via http
#  commands and returns a status code, where:
#
#      status  0 : All requested files exist on the local system
#      status  1 : A subset of the requested files exist on the local system
#      status -2 : Some other type of error
#==================================================================================
#
use if defined eval{require Time::HiRes;} >0,  "Time::HiRes" => qw(time);

    $SIG{INT} = \&Ecore::SysIntHandle;  #  Hopefully trap ^C before returning

    my ($host, %files) = @_;
    my $status  = 0;
    my $command = qw{};

    #  The HTTP option uses the curl and/or wget to pull files from the remote server.
    #  Make sure that at least one of these utilities exists on the system.
    #
    my $curl = &Others::LocateX('curl');
    my $wget = &Others::LocateX('wget');

    unless ($curl or $wget) {
        my $mesg = "Neither \"curl\" nor \"wget\" could be localed on the local system. These utilities are ".
                   "needed to download the data files via http and are available for most Linux distributions. ".
                   "You will need to install at least one of the packages before continuing.";
 
        &Ecomm::PrintMessage(6,11+$Uprep{arf},92,1,2,&Ecomm::TextFormat(0,0,255,0,0,'A little help is needed:',$mesg));
        return -1;
    }


    #  The %gfiles hash will contain the files to download from the remote server.
    #  Note that this may be different from the list passed to this routine
    #  since some of the files may already reside on the local system.
    #
    my %gfiles = ();
    for my $lfile (sort keys %files) {$gfiles{$lfile} = $files{$lfile}{remfile} unless -s $lfile;}

    #  Formulation of the command used to acquire the personal tiles via http is different
    #  from that used for the non personal tile datasets.
    #
    my $clog = "$Uprep{rtenv}{logdir}/prep_http_checkfile.log";
    my $dlog = "$Uprep{rtenv}{logdir}/prep_http_download.log";

    &Ecomm::PrintMessage(0,14+$Uprep{arf},96,1,2,"Initiating HTTP connection to $host");

    for my $lfile (sort keys %gfiles) {

        my $remsize = 0;
        my $remfile = $gfiles{$lfile};

        &Others::rm($clog);

        #  Before continuing, we need to address the condition where the files on the remote
        #  system are packed, as indicated by a ".bz2", ".gz", or ".bz" extension. 
        #  
        my $packed = ($remfile =~ /(.gz)$|(.bz2)$|(.bz)$/) ? 1 : 0;
        if ($packed) {
            $lfile = "$lfile\.gz"  if $remfile =~ /(.gz)$/;
            $lfile = "$lfile\.bz"  if $remfile =~ /(.bz)$/;
            $lfile = "$lfile\.bz2" if $remfile =~ /(.bz2)$/;
        }


        #  Start by checking to see if the file is available on the remote host
        #  and if so get the size of the file
        #
        &Ecomm::PrintMessage(5,16+$Uprep{arf},255,0,0,sprintf ("Checking if available : %s",$remfile));

        
        #  Flags for wget:
        #
        #    -T   : timeout length
        #    -t   : attempt
        #
        #  Run the command to get the size of the file
        #
        $status = &Ecore::SysExecute($curl ? "curl -f -o $clog --connect-timeout 3 -sI http://$host$remfile" : "wget -o $clog -T 3 -t 1 --spider http://$host$remfile");

        if ($status == 2) {&Ecore::SysIntHandle();}

        if ($status)      {
            my $errmsg = $curl ? &Ecore::CurlExitCodes($status) : &Ecore::WgetExitCodes($status);
            &Ecomm::PrintMessage(0,1,255,0,1,"- Not Available ($errmsg)");
            next;
        }

        #  Get the size of the file on the remote server for comparison with the local file
        #
        if (-s $clog) {
            my @info = ();
            open (my $fh, '<', $clog);
            while (<$fh>) {@info = split ' ', $_ if s/Content-Length:|Length:|Longueur://i;}
            $remsize = $info[0];
        }
        &Others::rm($clog);

        unless ($remsize) {
            my $log = &Others::popit($clog);
            &Ecomm::PrintMessage(0,1,96,0,1,"- Error reading log/$log");
            next;
        }


        #  At this point we have identified the file on the remote server and obtained the file size.
        #  Now go get the file.
        #
        &Ecomm::PrintMessage(0,1,96,0,1,sprintf ("- Available (%s MB)",sprintf('%.2f',&Others::Bytes2MB($remsize))));
        &Ecomm::PrintMessage(5,16+$Uprep{arf},255,0,0,sprintf ("Bring'n it home to you: %s",$remfile));

        my $secs = time();
        $command = $curl ? "curl -C - -s -f --connect-timeout 30 --max-time 1200  http://$host$remfile -o $lfile > $dlog 2>&1"
                         : "wget -a $dlog -L -nv --connect-timeout=30 --read-timeout=1200 -t 3 -O $lfile http://$host$remfile";

        if ($status = &Ecore::SysExecute($command)) {
            &Others::rm($lfile);
            &Ecore::SysIntHandle() if $status == 2; #  Interrupt
            my $errmsg = $curl ? &Ecore::CurlExitCodes($status) : &Ecore::WgetExitCodes($status);
            &Ecomm::PrintMessage(0,1,96,0,2,"- Failed ($errmsg)");
            return 1;
        }
        $secs   = time()-$secs; $secs = 1 unless $secs;

        my $lsize = &Others::FileSize($lfile);


        if ($lsize and $lsize == $remsize) {
            my $comm = $secs > 10. ? 'Slowly' : 'Success';
            &Ecomm::PrintMessage(0,1,96,0,2,sprintf ("- $comm (%s MB/s)",sprintf('%.2f',&Others::Bytes2MB($remsize)/$secs))) unless $packed;
        } elsif ($lsize and $lsize != $remsize) {
            &Ecomm::PrintMessage(0,1,96,0,2,sprintf ("- Size mismatch - %s MB (remote) Vs. %s MB (local)",sprintf('%.2f',&Others::Bytes2MB($remsize)),sprintf('%.2f',&Others::Bytes2MB($lsize))));
            &Others::rm($lfile);
        } else {
             &Ecomm::PrintMessage(0,1,96,0,2,"- Failed for some unknown reason");
             &Ecomm::PrintMessage(6,18+$Uprep{arf},96,0,2,'Problem with on remote host or local file system?');
             &Others::rm($lfile);
        }

        &Others::FileUnpack(1,$lfile) if $packed;
    }

    #  Before we leave check to see if all the files are downloaded
    #
    my $tfiles = keys %files;
    my $nfiles = $tfiles;

    for my $lfile (sort keys %files) {$nfiles-- if -s $lfile;}

    &Others::rm($dlog);
    &Others::rm($clog);


return $nfiles ? ($nfiles == $tfiles) ? 2 : 1 : 0;
} #  FileDownload_HTTP



sub FileDownload_HTTPS {
#==================================================================================
#  This routine download the requested files to the local system via https
#  commands and returns a status code, where:
#
#      status  0 : All requested files exist on the local system
#      status  1 : A subset of the requested files exist on the local system
#      status -2 : Some other type of error
#==================================================================================
#
use if defined eval{require Time::HiRes;} >0,  "Time::HiRes" => qw(time);

    $SIG{INT} = \&Ecore::SysIntHandle;  #  Hopefully trap ^C before returning

    my ($host, %files) = @_;
    my $status  = 0;
    my $command = qw{};

    #  The HTTPS option uses the curl and/or wget to pull files from the remote server.
    #  Make sure that at least one of these utilities exists on the system.
    #
    my $curl = &Others::LocateX('curl');
    my $wget = &Others::LocateX('wget');

    unless ($curl or $wget) {
        my $mesg = "Neither \"curl\" nor \"wget\" could be localed on the local system. These utilities are ".
                   "needed to download the data files via https and are available for most Linux distributions. ".
                   "You will need to install at least one of the packages before continuing.";
 
        &Ecomm::PrintMessage(6,11+$Uprep{arf},92,1,2,&Ecomm::TextFormat(0,0,255,0,0,'A little help is needed:',$mesg));
        return -1;
    }


    #  The %gfiles hash will contain the files to download from the remote server.
    #  Note that this may be different from the list passed to this routine
    #  since some of the files may already reside on the local system.
    #
    my %gfiles = ();
    for my $lfile (sort keys %files) {$gfiles{$lfile} = $files{$lfile}{remfile} unless -s $lfile;}

    #  Formulation of the command used to acquire the personal tiles via https is different
    #  from that used for the non personal tile datasets.
    #
    my $clog = "$Uprep{rtenv}{logdir}/prep_https_checkfile.log";
    my $dlog = "$Uprep{rtenv}{logdir}/prep_https_download.log";

    &Ecomm::PrintMessage(0,14+$Uprep{arf},96,1,2,"Initiating HTTPS connection to $host");

    for my $lfile (sort keys %gfiles) {

        my $remsize = 0;
        my $remfile = $gfiles{$lfile};

        &Others::rm($clog);

        #  Before continuing, we need to address the condition where the files on the remote
        #  system are packed, as indicated by a ".bz2", ".gz", or ".bz" extension. 
        #  
        my $packed = ($remfile =~ /(.gz)$|(.bz2)$|(.bz)$/) ? 1 : 0;
        if ($packed) {
            $lfile = "$lfile\.gz"  if $remfile =~ /(.gz)$/;
            $lfile = "$lfile\.bz"  if $remfile =~ /(.bz)$/;
            $lfile = "$lfile\.bz2" if $remfile =~ /(.bz2)$/;
        }


        #  Start by checking to see if the file is available on the remote host
        #  and if so get the size of the file
        #
        &Ecomm::PrintMessage(5,16+$Uprep{arf},255,0,0,sprintf ("Checking if available : %s",$remfile));

        
        #  Flags for wget:
        #
        #    -T   : timeout length
        #    -t   : attempt
        #
        #  Run the command to get the size of the file
        #
        $status = &Ecore::SysExecute($curl ? "curl -f -o $clog --connect-timeout 3 -sI https://$host$remfile" : "wget -o $clog -T 3 -t 1 --spider https://$host$remfile");

        if ($status == 2) {&Ecore::SysIntHandle();}

        if ($status)      {
            my $errmsg = $curl ? &Ecore::CurlExitCodes($status) : &Ecore::WgetExitCodes($status);
            &Ecomm::PrintMessage(0,1,255,0,1,"- Not Available ($errmsg)");
            next;
        }

        #  Get the size of the file on the remote server for comparison with the local file
        #
        if (-s $clog) {
            my @info = ();
            open (my $fh, '<', $clog);
            while (<$fh>) {@info = split ' ', $_ if s/Content-Length:|Length:|Longueur://i;}
            $remsize = $info[0];
        }
        &Others::rm($clog);

        unless ($remsize) {
            my $log = &Others::popit($clog);
            &Ecomm::PrintMessage(0,1,96,0,1,"- Error reading log/$log");
            next;
        }


        #  At this point we have identified the file on the remote server and obtained the file size.
        #  Now go get the file.
        #
        &Ecomm::PrintMessage(0,1,96,0,1,sprintf ("- Available (%s MB)",sprintf('%.2f',&Others::Bytes2MB($remsize))));
        &Ecomm::PrintMessage(5,16+$Uprep{arf},255,0,0,sprintf ("Bring'n it home to you: %s",$remfile));

        my $secs = time();
        $command = $curl ? "curl -C - -s -f --connect-timeout 30 --max-time 1200  https://$host$remfile -o $lfile > $dlog 2>&1"
                         : "wget -a $dlog -L -nv --connect-timeout=30 --read-timeout=1200 -t 3 -O $lfile https://$host$remfile";

        if ($status = &Ecore::SysExecute($command)) {
            &Others::rm($lfile);
            &Ecore::SysIntHandle() if $status == 2; #  Interrupt
            my $errmsg = $curl ? &Ecore::CurlExitCodes($status) : &Ecore::WgetExitCodes($status);
            &Ecomm::PrintMessage(0,1,96,0,2,"- Failed ($errmsg)");
            return 1;
        }
        $secs   = time()-$secs; $secs = 1 unless $secs;

        my $lsize = &Others::FileSize($lfile);


        if ($lsize and $lsize == $remsize) {
            my $comm = $secs > 10. ? 'Slowly' : 'Success';
            &Ecomm::PrintMessage(0,1,96,0,2,sprintf ("- $comm (%s MB/s)",sprintf('%.2f',&Others::Bytes2MB($remsize)/$secs))) unless $packed;
        } elsif ($lsize and $lsize != $remsize) {
            &Ecomm::PrintMessage(0,1,96,0,2,sprintf ("- Size mismatch - %s MB (remote) Vs. %s MB (local)",sprintf('%.2f',&Others::Bytes2MB($remsize)),sprintf('%.2f',&Others::Bytes2MB($lsize))));
            &Others::rm($lfile);
        } else {
             &Ecomm::PrintMessage(0,1,96,0,2,"- Failed for some unknown reason");
             &Ecomm::PrintMessage(6,18+$Uprep{arf},96,0,2,'Problem with on remote host or local file system?');
             &Others::rm($lfile);
        }

        &Others::FileUnpack(1,$lfile) if $packed;
    }

    #  Before we leave check to see if all the files are downloaded
    #
    my $tfiles = keys %files;
    my $nfiles = $tfiles;

    for my $lfile (sort keys %files) {$nfiles-- if -s $lfile;}

    &Others::rm($dlog);
    &Others::rm($clog);


return $nfiles ? ($nfiles == $tfiles) ? 2 : 1 : 0;
} #  FileDownload_HTTPS



sub FileDownload_PTILE {
#==================================================================================
#  This routine download the requested files to the local system via http
#  commands and returns a status code, where:
#
#      status  0 : All requested files exist on the local system
#      status  1 : A subset of the requested files exist on the local system
#      status -2 : An HTTP error such as network problem, timeout, etc.
#      status -3 : Problem with ptile configuration either local or on EMS server
#==================================================================================
#
use if defined eval{require Time::HiRes;} >0,  "Time::HiRes" => qw(time);
use Ptiles;


    $SIG{INT} = \&Ecore::SysIntHandle;  #  Hopefully trap ^C before returning

    my ($ptile, $host, %files) = @_;

    my $status  = 0;
    my $command = qw{};
    my $pturl = qw{};

    #  The HTTP option uses the curl and/or wget to pull files from the remote server.
    #  Make sure that at least one of these utilities exists on the system.
    #
    my $curl = &Others::LocateX('curl');
    my $wget = &Others::LocateX('wget');

    unless ($curl or $wget) {
        my $mesg = "Neither \"curl\" nor \"wget\" could be localed on the local system. These utilities are ".
                   "needed to download the data files via http and are available for most Linux distributions. ".
                   "You will need to install at least one of the packages before continuing.";

        &Ecomm::PrintMessage(6,11+$Uprep{arf},92,1,2,&Ecomm::TextFormat(0,0,255,0,0,'A little help is needed:',$mesg));
        return -2;
    }


    #  The %gfiles hash will contain the files to download from the remote server.
    #  Note that this may be different from the list passed to this routine
    #  since some of the files may already reside on the local system.
    #
    my %gfiles=();
    for my $lfile (sort keys %files) {$gfiles{$lfile} = $files{$lfile}{remfile} unless -s $lfile;}


    #  The PersonalTilesConfig subroutine configures the URL variable string that is
    #  sent to a UEMS personal tile server. Should there be a problem and empty
    #  string is returned and you get nothing.
    #
    return -3 unless $pturl = &Ptiles::PersonalTilesConfig($ptile,$host,%gfiles);


    #  Formulation of the command used to acquire the personal tiles via http is different
    #  from that used for the non personal tile datasets.
    #
    my $rlog = "$Uprep{rtenv}{logdir}/prep_http_request.log";
    my $dlog = "$Uprep{rtenv}{logdir}/prep_http_download.log";
    
    &Ecomm::PrintMessage(0,14+$Uprep{arf},96,1,2,"Initiating HTTP connection to $host");


    #  Make sure that the Timeout value is large enough so that the UEMS servers
    #  can process the personal tile request. If the user is requesting a large number
    #  of forecast files this could take 15 minutes if the load on the system is
    #  heavy so set to 20 minutes (1200 seconds). Hopefully the amount of time 
    #  required to process the files will decrease in the future but I'll probably
    #  forget to change these values.
    #
    my $secs = time();
    $command = $curl ? "curl -s -f --no-buffer --connect-timeout 30 --max-time 1200  $pturl > $rlog 2>&1"
                     : "wget -a $dlog -L -nv --connect-timeout=30 --read-timeout=1200 -t 1 -O $rlog $pturl";


    #  Run the command and check for any error codes 
    #
    if ($status = &Ecore::SysExecute($command)) {
        &Others::rm($rlog);
        &Ecore::SysIntHandle() if $status == 2; #  Interrupt
        my $errmsg = $curl ? &Ecore::CurlExitCodes($status) : &Ecore::WgetExitCodes($status);
        &Ecomm::PrintMessage(9,14+$Uprep{arf},96,0,2,"Connection to $host failed ($errmsg)");
        return -2;
    }
    $secs   = time()-$secs; $secs = 1 unless $secs;


    #----------------------------------------------------------------------------------------
    #  There were no errors returned by wget or curl, but that does not mean everything
    #  was a glowing success. Consequently, we need to interrogate the log file to determine
    #  whether there any server side issues that were caught during ptile processing.
    #
    #  Normal results includes both complete or incomplete downloads. Error statements
    #  indicate problems, but you probably already knew that. 
    #----------------------------------------------------------------------------------------
    #
    my $success = 0;

    open (my $fh, '<', $rlog); my @loginfo = <$fh>; close $fh; 

    foreach (@loginfo) {chomp; $success = 1 if /Transfer Log/i;}

    unless ($success) {

        &Ecomm::PrintMessage(9,14+$Uprep{arf},96,0,2,"Connection to $host failed");

        #  There seems to have been a problem with the request. Fabricate a plausible explanation 
        #  for the user and hope the problem fixes itself.
        #
        foreach (@loginfo) {

            next unless /Error/i;

            if (/Overwhelmed/i)  {&Ecomm::PrintMessage(6,14+$Uprep{arf},144,1,2,'Busy : Server overwhelmed with love from users - Trying again very soon.');}

            if (/Script Error/i) {
                &Ecomm::PrintMessage(6,14+$Uprep{arf},144,1,2,'It appears that you are not requesting personal tiles or that there is a problem with the ptile request:');
                &Ecomm::PrintMessage(0,14+$Uprep{arf},96,1,2,$pturl);
                system "cp -f $rlog $rlog\.error";
            }

            if (/Server Error/i) {&Ecomm::PrintMessage(6,14+$Uprep{arf},144,1,2,"Ugh!  There was an internal error on the server. Try hitting another ptile server.");}

        } 

        &Others::rm($rlog);
        return -2;

    } #  end unless (success)


    #----------------------------------------------------------------------------------------
    #  So the personal tile request appears to have been a success. It's now time to
    #  parse the URLs to each personal tile file from the log file and go get them.
    #----------------------------------------------------------------------------------------
    #

    #  Reverse the file order of the hash to make things easier during rem <-> loc file check
    #  Then use %ptfiles rather than %gfiles
    #
    my %ptfiles = ();
    for my $lfile (sort keys %gfiles) {
        my ($requrl, $file) = split /\?/ => $gfiles{$lfile};
        $ptfiles{$file} = $lfile;
    }


    foreach (@loginfo) {

        next unless s/http:\/\///g;
        my ($url, $file, $mesg, $size) = split / / => $_;
     
        &Ecomm::PrintMessage(5,14+$Uprep{arf},255,0,0,"Attempting to acquire $file");

        if ($mesg =~ /Success/i) { # The request was successful - go get the file

            my $lfile = $ptfiles{$file};

            my $secs = time();
            $command = $curl ? "curl -s -f --no-buffer --connect-timeout 30 --max-time 1200  $url/$file -o $lfile  > $dlog 2>&1"
                             : "wget -a $dlog -L -nv --connect-timeout=30 --read-timeout=1200 -t 3 -O $lfile $url/$file";


            #  Run the command and check for any error codes 
            #
            if ($status = &Ecore::SysExecute($command)) {
                &Others::rm($rlog);
                &Ecore::SysIntHandle() if $status == 2; #  Interrupt - we don't return from here
                my $errmsg = $curl ? &Ecore::CurlExitCodes($status) : &Ecore::WgetExitCodes($status);
                &Ecomm::PrintMessage(0,1,96,0,2,"- Download Error ($errmsg)");
                &Others::rm($lfile);
                next;
            }
            $secs   = time()-$secs; $secs = 1 unless $secs;


            my $lsize = &Others::FileSize($lfile);

            if ($lsize and $lsize == $size) {
                &Ecomm::PrintMessage(0,1,96,0,1,sprintf ("- Success (%s MB/s)",sprintf('%.2f',&Others::Bytes2MB($lsize)/$secs)));
            } elsif ($lsize and $lsize != $size) {
                &Ecomm::PrintMessage(0,1,96,0,1,sprintf ("- Size mismatch - %s MB (remote) Vs. %s MB (local)",sprintf('%.2f',&Others::Bytes2MB($size)),sprintf('%.2f',&Others::Bytes2MB($lsize))));
                &Others::rm($lfile);
            } else {
                 &Ecomm::PrintMessage(0,1,96,0,1,"- Failed for some unknown reason");
                 &Ecomm::PrintMessage(6,14+$Uprep{arf},96,1,1,'Possible problem with on remote host or local file system?');
                 &Others::rm($lfile);
            }


        } elsif (/Unavailable/i) { # If the grib file is not found on the remote server
            &Ecomm::PrintMessage(0,1,96,0,1,"- Ptile Not Currently Available");
        } elsif (/Failed/i) { # If there was an error on the remote server during processing
            &Ecomm::PrintMessage(0,1,96,0,2,"- Error on Remote Ptile Server");
        } else {
            &Ecomm::PrintMessage(0,1,96,0,2,"- Error on Remote Ptile Server");
        }


    }
            
    #  Before we leave check to see if all the files are downloaded
    #
    my $tfiles = keys %files;
    my $nfiles = $tfiles;

    for my $lfile (sort keys %files) {$nfiles-- if -s $lfile;}

    &Others::rm($dlog);
    &Others::rm($rlog);


return $nfiles ? ($nfiles == $tfiles) ? 2 : 1 : 0;
}  #  FileDownload_PTILE



sub FileDownload_LOCAL {
#==================================================================================
#  This routine download the requested files to the local system via the (secure)
#  copy command and returns a status code, where:
#
#      status  0 : All requested files exist on the local system
#      status  1 : A subset of the requested files exist on the local system
#      status -2 : Some other type of error
#==================================================================================
#
use if defined eval{require Time::HiRes;} >0,  "Time::HiRes" => qw(time);


    $SIG{INT} = \&Ecore::SysIntHandle;  #  Hopefully trap ^C before returning

    my ($host, %files) = @_;
    my $status  = 0;

    #  The %gfiles hash will contain the files to download from the remote server.
    #  Note that this may be different from the list passed to this routine
    #  since some of the files may already reside on the local system.
    #
    my %gfiles=();

    for my $lfile (sort keys %files) {$gfiles{$lfile} = $files{$lfile}{remfile} unless -s $lfile;}

    my $copy = $host =~ /local/i;

    &Ecomm::PrintMessage(0,14+$Uprep{arf},96,1,2,$copy ? "Copying files from local system" : "Secure copy from $host");

    my @list = split /\./ => $host; my $shost = $list[0];

    for my $lfile (sort keys %gfiles) {

        my $remfile = $gfiles{$lfile};

        #  Before continuing, we need to address the condition where the files on the remote
        #  system are packed, as indicated by a ".bz2", ".gz", or ".bz" extension. 
        #  
        my $packed = ($remfile =~ /(.gz)$|(.bz2)$|(.bz)$/) ? 1 : 0;
        if ($packed) {
            $lfile = "$lfile\.gz"  if $remfile =~ /(.gz)$/;
            $lfile = "$lfile\.bz"  if $remfile =~ /(.bz)$/;
            $lfile = "$lfile\.bz2" if $remfile =~ /(.bz2)$/;
        }

        &Ecomm::PrintMessage(5,16+$Uprep{arf},255,0,0,$copy ? "Rsync $remfile" : "Rsync from $shost:$remfile");
         
      
        $status = $copy ? &Ecore::SysExecute("rsync -qa $remfile $lfile > /dev/null 2>&1") 
                        : &Ecore::SysExecute("rsync -qa $host:$remfile $lfile > /dev/null 2>&1");

        $status         ? &Ecomm::PrintMessage(0,1,96,0,1,sprintf("- Failed (%s)",&Ecore::RsyncExitCodes($status)))
                        : &Ecomm::PrintMessage(0,1,96,0,1,sprintf("- Success (%s MB)",sprintf('%.2f',&Others::Bytes2MB(&Others::FileSize($lfile)))));

        &Others::FileUnpack(0,$lfile) if $packed;

    }

    #  Before we leave check to see if all the files are downloaded
    #
    my $tfiles = keys %files;
    my $nfiles = $tfiles;

    for my $lfile (sort keys %files) {$nfiles-- if -s $lfile;}


return $nfiles ? ($nfiles == $tfiles) ? 2 : 1 : 0;
} #  FileDownload_LOCAL



sub FileDownload_FTP {
#==================================================================================
#  This routine download the requested files to the local system via FTP (File
#  Transfer Protocal for you whipper-snappers), and returns a status code, where:
#
#      status  0 : All requested files exist on the local system
#      status  1 : A subset of the requested files exist on the local system
#      status -2 : Some other type of error
#==================================================================================
#
use Net::FTP;
use if defined eval{require Time::HiRes;} >0,  "Time::HiRes" => qw(time);

    $SIG{INT} = \&Ecore::SysIntHandle;  #  Hopefully trap ^C before returning

    my ($host, %files) = @_;
    my $status = 0;
    my $ftpp   = qw{};


    &Ecomm::PrintMessage(0,14+$Uprep{arf},96,1,2,"Initiating FTP connection to $host");

    my $fail = 1;
    while ($fail > 0 and $fail < 4) {
        $fail = ($ftpp=Net::FTP->new(lc $host, Timeout => 20)) ? 0 : $fail+1 ;
        my $error = $fail-1;
        if ($@ and $@ =~ /hostname/i) {
            $fail = 4;
            &Ecomm::PrintMessage(6,14+$Uprep{arf},96,0,2,"CONNECTION ERROR - $@");
        } else {
            &Ecomm::PrintMessage(6,14+$Uprep{arf},96,0,2,"CONNECTION ERROR: Attempt #$error of 3 - $@") if $fail;
        }
    }
    return -2 if $fail;

    #  Log into server. Note that this step will fail if non-anonymous login information
    #  is not located in ~/.netrc file
    #
    unless  ($ftpp->login()) {&Ecomm::PrintMessage(6,14+$Uprep{arf},96,0,2,"LOGIN ERROR",$ftpp->message() );return -2;}
    $ftpp->binary();

    #  The %gfiles hash will contain the files to download from the remote server.
    #  Note that this may be different from the list passed to this routine
    #  since some of the files may already reside locally.
    #
    #  The %lsizes hash will contain the file sizes of the local files
    #
    my %gfiles = ();
    my %rsizes = ();
    for my $lfile (sort keys %files) {$gfiles{$lfile} = $files{$lfile}{remfile} unless -s $lfile;}

    #  Now lets go get the files
    #
    for my $lfile (sort keys %gfiles) {

        my $remfile = $gfiles{$lfile};
        my $remsize = $ftpp->size($remfile); $remsize = 0 unless $remsize;

        &Ecomm::PrintMessage(5,16+$Uprep{arf},256,0,0,"Attempting to acquire $remfile");

        
        #  Before continuing, we need to address the condition where the files on the remote
        #  system are packed, as indicated by a ".bz2", ".gz", or ".bz" extension. 
        #  
        my $packed = ($remfile =~ /(.gz)$|(.bz2)$|(.bz)$/) ? 1 : 0;
        if ($packed) {
            $lfile = "$lfile\.gz"  if $remfile =~ /(.gz)$/;
            $lfile = "$lfile\.bz"  if $remfile =~ /(.bz)$/;
            $lfile = "$lfile\.bz2" if $remfile =~ /(.bz2)$/;
        }

        #  With FTP a non-zero return indicates a result, which may or may not be a good one.
        #
        my $secs = time();
        if ($ftpp->get($remfile,$lfile)) {

            #  Check the file sizes
            #
            my $lsize = &Others::FileSize($lfile);

            if ($lsize == 0) { # File size is zero bytes
                &Ecomm::PrintMessage(0,1,96,0,2,"- Zero Byte File");
                &Ecomm::PrintMessage(6,16+$Uprep{arf},108,0,1,'File size on local system is zero bytes. Problem with on remote host or local file system?');
                &Others::rm($lfile);
            } elsif ($lsize != $remsize) {
                my $f  = &Others::popit($lfile);
                $remsize = 0 unless $remsize;
                $lsize = 0 unless $lsize;
                &Ecomm::PrintMessage(0,1,96,0,1,'- Size Problem', sprintf ("Remote server %s MB Vs. Local %s MB",sprintf('%.2f',&Others::Bytes2MB($remsize)),sprintf('%.2f',&Others::Bytes2MB($lsize))));

                if ($remsize) {
                    &Ecomm::PrintMessage(0,1,96,0,2,"Downloading $f again");
                    &Others::rm($lfile);

                    if ($ftpp->get($remfile,$lfile)) {
                        my $lsize = &Others::FileSize($lfile);
 
                    } else {
                        &Ecomm::PrintMessage(6,16+$Uprep{arf},96,0,2,"FTP ERROR",$ftpp->message());
                        &Others::rm($lfile);
                    }
                } else {
                   &Ecomm::PrintMessage(5,18+$Uprep{arf},108,0,1,"Assuming local file $f is correct");
                }
            } else {
                $secs   = time()-$secs; $secs = 1 unless $secs;
                &Ecomm::PrintMessage(0,1,96,0,2,sprintf ("- Success (%s MB/s)",sprintf('%.2f',&Others::Bytes2MB($lsize)/$secs))) unless $packed;
            }

            &Others::FileUnpack(1,$lfile) if $packed;

        } elsif ( $ftpp->message() =~ /No such file or directory|Failed to open file/i ) {
            &Ecomm::PrintMessage(0,1,96,0,1,"- Not Currently Available");
        } else {
            my $mesg = $ftpp->message(); $mesg = "- Unknown FTP failure ($? and $!)" unless $mesg;
            &Ecomm::PrintMessage(0,1,96,0,1,$mesg);
        }

    }


    #  Before we leave check to see if all the files are downloaded
    #
    my $tfiles = keys %files;
    my $nfiles = $tfiles;

    for my $lfile (sort keys %files) {$nfiles-- if -s $lfile;}


return $nfiles ? ($nfiles == $tfiles) ? 2 : 1 : 0;
} #  FileDownload_FTP



