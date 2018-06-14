#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Grads.pm
#
#  DESCRIPTION:  Grads contains the routines used to process the GRIB 2 files 
#                from the UEMS UPP for use with GrADS.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Grads;

use warnings;
use strict;
require 5.008;
use English;

use vars qw ($mesg);


sub Process2Grads {
# ======================================================================================
#  The &Process2Grads routine is the driver for the processing and managing the 
#  creation of GrADS files from UEMS UPP GRIB 2 files
# ======================================================================================
#
use Cwd;

    my ($ftype, $pref) = @_; my %Post = %{$pref};

    return %Post unless $Post{proc} and %{$Post{grads}};


    #----------------------------------------------------------------------------------
    #  &Grib2Grads - Where the processing magic happens
    #----------------------------------------------------------------------------------
    #
    @{$Post{grads}{newfiles}} = ();
    @{$Post{grads}{newfiles}} = &Grib2Grads($ftype,\%Post);


    #----------------------------------------------------------------------------------
    #  Hey, I'm in the import/export business!
    #----------------------------------------------------------------------------------
    #
    &ExportGrads($ftype,\%Post);


    #  Before returning, collect the newly minted GrADS files located in the emsprd/grads
    #  directory.  Get a string to match against all available files.
    #
    @{$Post{grads}{allfiles}} = ();
    
    my ($ymd, $match) = split '_', $Post{grads}{fname}, 2; ($match, $ymd) = split '\.', $match;
    push @{$Post{grads}{allfiles}} => Cwd::realpath($_) foreach &Others::FileMatch($Post{grads}{dpost},$match,0,0);


return %Post;
}


sub Grib2Grads {
# ======================================================================================
#  This routine uses the UEMS provided GrADS routines to process simulation GRIB 2 
#  files into GEMPAK grid files. Lots of stuff going on here so pay close attention.
# ======================================================================================
#
    my @Post    = ();
    my @Grads   = ();

    my ($ftype, $pref) = @_; my %Post = %{$pref};

  
    #  Attend to some local configuration
    #
    my $dom      = sprintf '%02d', $Post{domain};
    my $grib2ctl = "$Post{grads}{dbin}/g2ctl.pl";
    my $gribmap  = "$Post{grads}{dbin}/gribmap";



    #----------------------------------------------------------------------------------
    #  Alert the user if no files are available for processing
    #----------------------------------------------------------------------------------
    #
    unless (@{$Post{grib}{newfiles}}) {
        &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Creating GrADS files from domain %s GRIB 2 files",$dom));
        &Ecomm::PrintMessage(0,12+$Post{arf},144,1,1,"I looked, but there are no domain $dom $ftype GRIB 2 files to process right now");
        return ();
    }

    
    #----------------------------------------------------------------------------------
    #  Make sure any Grib 2 files available for processing actually need to be 
    #  processed as defined by the $Post{grads}{freq} (FREQ:START:STOP) setting
    #----------------------------------------------------------------------------------
    #
    my @Gribs  = ();
    (my $mfreq = $Post{grads}{freq}) =~ s/:\w*//g;
    unless (@Gribs = sort &Outils::FrequencySubset($Post{grads}{freq},@{$Post{grib}{newfiles}})) {
        &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Creating GrADS files from domain %s GRIB 2 files",$dom));
        &Ecomm::PrintMessage(0,12+$Post{arf},144,1,1,"Yay! I have nothing to do since the processing frequency ($mfreq minutes) has left me without any GRIB 2 files!");
        return ();
    }


    my $sdate = &Others::DateString2Pretty(&Others::Grib2VerifTime($Gribs[0])); $sdate =~ s/^\w{3}\s//g; $sdate =~ s/\s+/ /g; $sdate =~ s/:\d\d / /;
    my $edate = &Others::DateString2Pretty(&Others::Grib2VerifTime($Gribs[-1]));$edate =~ s/^\w{3}\s//g; $edate =~ s/\s+/ /g; $edate =~ s/:\d\d / /;

    @Gribs == 1 ? &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Creating GrADS files from a single measly domain %s %s GRIB2 file for $sdate",$dom,$ftype=~/^wrf/ ? 'primary':'auxiliary'))
                : &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Creating GrADS files from domain %s %s GRIB 2 files every %s minutes between $sdate & $edate",$dom,$ftype=~/^wrf/ ? 'primary':'auxiliary',$mfreq));

 
    #----------------------------------------------------------------------------------
    #  Make sure there are no files or links left over from a previous process.
    #  This step is a bit tricky because while we want to delete any existing GrADS
    #  files for the current domain being processed (unless scour), we don't 
    #  want to delete grib files previously created for another domain or file type. 
    #----------------------------------------------------------------------------------
    #
    if (&Others::mkdir($Post{grads}{dpost})) {&Ecomm::PrintMessage(6,12+$Post{arf},144,1,2,"Grib2Grads: Failed to create $Post{grads}{dpost} - Return"); return ();}

    foreach (&Others::FileMatch($Post{grads}{dpost},'',1,0)) {&Others::rm("$Post{grads}{dpost}/$_") unless /_d\d\d.[ctl|idx|grb]/; }

    if ($Post{scour}) {
        my ($ymd, $match) = split '_', $Post{grads}{fname}, 2; ($match, $ymd) = split '\.', $match;
        &Others::rm("$Post{grads}{dpost}/$_") foreach &Others::FileMatch($Post{grads}{dpost},$match,1,0);
    }


    #----------------------------------------------------------------------------------
    #  Make sure the GrADS binaries exist and that my cheese is where I left it.
    #----------------------------------------------------------------------------------
    #
    foreach ($grib2ctl, $gribmap) {
        if (&Others::FileExists($_)) {
            &Ecomm::PrintMessage(6,12+$Post{arf},144,2,1,'Grib2Grads: Who moved my Cheese!',"It appears that $_ is missing.\n\nNo GrADS love for you!");
            return ();
        }
    }

    #----------------------------------------------------------------------------------
    #  The next step is to create the working directory (if necessary), which is the
    #  same as the final GRIB destination, /emsprd/grib. Afterwards, create the links
    #  to the tables and other necessary files.
    #
    #  This odyssey begins in the emsprd/grib directory.
    #----------------------------------------------------------------------------------
    #
    chdir $Post{grads}{dpost};


    #----------------------------------------------------------------------------------
    #  Populate the filenames to be used in the creation of GrADS files. Get the 
    #  simulation start time ($init) from the 1st GRIB 2 file in the list to process.
    #  A link from the emsprd/grads directory to emsprd/grib is created, the date
    #  info is read and then used to populate the filename template {fname}.
    #----------------------------------------------------------------------------------
    #
    #----------------------------------------------------------------------------------
    #  If the user requested a MONOLITHIC file then the simplest approach is to 
    #  concatenate all the (NEW) GRIB files into a single GRIB file and allow 
    #  g2ctl.pl to operate on that file. The downside is that this step creates 
    #  a very large GRIB file but should work for this purpose.
    #
    #  Note that the "off the shelf" g2ctl.pl was modified for the UEMS to 
    #  accommodate temporal resolutions of less than one hour.
    #----------------------------------------------------------------------------------
    #
    my $alph = 'a';
    my %Ghash= ();

    if ($Post{grads}{monofile}) { 

        my $local     = &Others::popit($Gribs[0]); &Others::rm($local); symlink $Gribs[0] => $local;
        my $init      = &Others::Grib2InitTime($local); &Others::rm($local);

        my @pairs = &Outils::Grib2DateStrings($Gribs[0]);
           @pairs = (@pairs,"WD:$dom","CORE:$Post{core}","KEY:$ftype");

        my $gradsname = &Others::PlaceholderFillDate($Post{grads}{fname},$init,@pairs);

        my $monogrib2 = "$gradsname.grb2"; &Others::rm($monogrib2) unless $Post{apost} and $Post{index};

        &Ecomm::PrintMessage(0,16+$Post{arf},255,1,0,sprintf("%-3s Concatenating GRIB 2s into single file    - ","${alph}.")); $alph++;

        if (my $err = &Ecore::SysExecute("cat @Gribs >> $monogrib2 2>&1")) {

            #  If the user passed a Control-C (^C) then simply clean up the mess
            #  that was made and exit
            # 
            &Outils::ProcessInterrupt('ems_post',2,$Post{grads}{dpost},[$monogrib2]) if $err == 2;
            &Ecomm::PrintMessage(0,1,144,0,2,sprintf('Failed (%s) - Return',$err));
            return ();
        }
        &Ecomm::PrintMessage(0,1,144,0,1,sprintf("%s (%s)",$monogrib2,sprintf('%.2f Mb',&Others::Bytes2MB(&Others::FileSize($monogrib2)))));

        #  monogrib - Monolithic GRIB file flag (1|0)
        #  gribfile - Physical location and name of GRIB 2 file
        #  localgrb - name GRIB 2 file under emsprd/grads
        #  gradsctl - GrADS control file name under emsprd/grads
        #  gradsidx - GrADS index file name under emsprd/grads
        #
        $Ghash{$init}{monogrib} = 1;
        $Ghash{$init}{gribfile} = "$Post{grads}{dpost}/$monogrib2";
        $Ghash{$init}{localgrb} = $monogrib2;
        $Ghash{$init}{gradsctl} = "$gradsname.ctl";
        $Ghash{$init}{gradsidx} = "$gradsname.idx";
         
    } else {  

        &Ecomm::PrintMessage(0,16+$Post{arf},255,1,0,sprintf("%-3s Creating links to individual GRIB 2 files - ","${alph}.")); $alph++;

        foreach my $grib2 (@Gribs) {
            
            my $local = &Others::popit($grib2); &Others::rm($local); 

            unless (symlink $grib2 => $local) {
                &Ecomm::PrintMessage(0,1,144,0,2,sprintf('Failed (%s) - Return',$!));
                return ();
            }

            my $verf      = &Others::Grib2VerifTime($local);  &Others::rm($local);
            my $gradsname = &Others::PlaceholderFillDate($Post{grads}{fname},$verf,());
      

            #  monogrib - Monolithic GRIB file flag (1|0)
            #  gribfile - Physical location and name of GRIB 2 file
            #  localgrb - name GRIB 2 file under emsprd/grads
            #  gradsctl - GrADS control file name under emsprd/grads
            #  gradsidx - GrADS index file name under emsprd/grads
            #
            $Ghash{$verf}{monogrib} = 0;
            $Ghash{$verf}{gribfile} = $grib2;
            $Ghash{$verf}{localgrb} = $local;
            $Ghash{$verf}{gradsctl} = "$gradsname.ctl";
            $Ghash{$verf}{gradsidx} = "$gradsname.idx";
        }
        &Ecomm::PrintMessage(0,1,144,0,1,'Completed (Go GrADS or Go Home!)');
    }

             
    #-----------------------------------------------------------------------------
    #  Format the flags to be passed to g2ctl.pl 
    #-----------------------------------------------------------------------------
    #
    my $ts = int ($mfreq/60);
       $ts = $mfreq%60 ? "-ts${mfreq}mn" : "-ts${ts}hr";

   

    #-----------------------------------------------------------------------------
    #  Loop through the keys in %Ghash, which holds the verification date/time
    #  strings for each grib 2 files to process (MONOFILE_GRADS = 0 in the 
    #  post_grads.conf file) or the simulation initialization time (one value)
    #  if MONOFILE_GRADS = 1.
    #-----------------------------------------------------------------------------
    #
    foreach my $verf (sort {$a <=> $b} keys %Ghash) { 

        my $localgrb = $Ghash{$verf}{localgrb};
        my $gradsctl = $Ghash{$verf}{gradsctl};
        my $gradsidx = $Ghash{$verf}{gradsidx};

        &Others::rm($gradsctl);
        &Others::rm($gradsidx);
        
        symlink $Ghash{$verf}{gribfile} => $Ghash{$verf}{localgrb}  unless $Ghash{$verf}{monogrib};

        push @Grads, Cwd::realpath($Ghash{$verf}{gribfile});
      
 
        #==================================================================================
        #  Set the command to run g2ctl.pl -verf $ts  
        #
        #  Note that the name of the index file is passed ($gradsidx) to ensure the
        #  file is named correctly; otherwise, the index file will be $gradsname.grb2.idx
        #
        #  Also - The "off the shelf" g2ctl.pl was modified for the UEMS to 
        #  accommodate temporal resolutions of less than one hour.
        #==================================================================================
        #
        my $cmd = "$grib2ctl -verf $ts  $localgrb  $gradsidx  >  $gradsctl 2>&1";


        #----------------------------------------------------------------------------------
        #  If the user passed --debug real|wrfm then it's time to shut down and allow
        #  their hands to get dirty.
        #----------------------------------------------------------------------------------
        #
        if ($ENV{POST_DBG} == -101 ) {
            &Ecomm::PrintMessage(4,12+$Post{arf},256,2,2,"The table has been set for you. Now try running:\n\n  % $cmd\n\nfrom the $Post{grads}{dpost} directory.");
            &Ecore::SysExit(98);
        }
    

        #----------------------------------------------------------------------------------
        #  Run g2ctl.pl to create the GrADS control file
        #----------------------------------------------------------------------------------
        #
        &Others::rm($gradsctl);
        &Ecomm::PrintMessage(0,16+$Post{arf},255,1,0,sprintf("%-3s Creating the GrADS control file           - ","${alph}.")); $alph++;

        if (my $err = &Ecore::SysExecute($cmd)) {

            #  If the user passed a Control-C (^C) then simply clean up the mess
            #  that was made and exit
            # 
            &Outils::ProcessInterrupt('g2ctl.pl',2,$Post{grads}{dpost},[$gradsctl]) if $err == 2;
            &Ecomm::PrintMessage(0,1,144,0,2,'Failure (No GrADS Love for You)');
            return ();
        }
        &Ecomm::PrintMessage(0,1,144,0,0,$gradsctl);
      
        push @Grads, Cwd::realpath("$Post{grads}{dpost}/$gradsctl");



        #==================================================================================
        #  Set the command to be run $gribmap -big -q -E -i $gradsctl
        #==================================================================================
        # 
        $cmd = "$gribmap -big -q -E -i $gradsctl";


        #----------------------------------------------------------------------------------
        #  If the user passed --debug real|wrfm then it's time to shut down and allow
        #  their hands to get dirty.
        #----------------------------------------------------------------------------------
        #
        if ($ENV{POST_DBG} == -102 ) {
            &Ecomm::PrintMessage(4,12+$Post{arf},256,2,2,"The table has been set for you. Now try running:\n\n  % $cmd\n\nfrom the $Post{grads}{dpost} directory.");
            &Ecore::SysExit(98);
        }


        #----------------------------------------------------------------------------------
        #  Run gribmap to create the GrADS index file
        #----------------------------------------------------------------------------------
        #
        &Others::rm($gradsidx);
        &Ecomm::PrintMessage(0,16+$Post{arf},255,1,0,sprintf("%-3s Creating the GrADS index file             - ","${alph}.")); $alph++;

        if (my $err = &Ecore::SysExecute("$cmd > /dev/null 2>&1")) {

            #  If the user passed a Control-C (^C) then simply clean up the mess
            #  that was made and exit
            # 
            &Outils::ProcessInterrupt('gribmap',2,$Post{grads}{dpost},[$gradsidx,'dump']) if $err == 2;
            &Ecomm::PrintMessage(0,1,144,0,2,'Failure (No GrADS Love for You)');
            return ();
         }
         &Others::rm('dump');
         &Ecomm::PrintMessage(0,1,144,0,1,$gradsidx);

         push @Grads, Cwd::realpath("$Post{grads}{dpost}/$gradsidx");


     }  #  foreach sort {$a <=> $b} keys %Ghash

     &Ecomm::PrintMessage(0,14+$Post{arf},255,1,1,sprintf("Reminder: Precipitation accumulation period in GrADS files is %s",&Ecomm::FormatTimingString($Post{grib}{pacc}*60)));


     #----------------------------------------------------------------------------------
     #  Time to clean up after ourselves
     #----------------------------------------------------------------------------------
     #
     @Grads = sort &Others::rmdups(@Grads);

     my $date = gmtime();
     &Ecomm::PrintMessage(0,12+$Post{arf},144,1,2,sprintf("Creation of domain $dom %s GrADS files %s at %s UTC",$ftype=~/^wrf/ ? 'primary':'auxiliary', @Grads ? 'completed':'failed',$date));


     #==================================================================================
     #  The GrADS script stuff will go here - currently may not working
     #==================================================================================
     #
     &GradsScript($Post{grads}{script},$Post{grads}{dpost},$Post{rundir},$Post{domain},\@Grads) if $Post{grads}{script};


return @Grads;
}


sub ExportGrads {
# =================================================================================
#  This routine uses the exports any Grads files to other locations per the 
#  user's request.
# =================================================================================
#
    my ($ftype, $pref) = @_; my %Post = %{$pref};

    return unless %{$Post{grads}{export}} and @{$Post{grads}{newfiles}};


    #  Attend to some local configuration
    #
    my $dom  = sprintf '%02d', $Post{domain};
    my @phs  = (@{$Post{placeholders}},'DSET:grads');


    &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Exporting domain %s %s GrADS files to wonderful and exotic locations",$dom,$ftype=~/^wrf/ ? 'primary':'auxiliary'));

    #----------------------------------------------------------------------------------
    #  Loop over each of the export requests (there may be more than one)
    #----------------------------------------------------------------------------------
    #
    my $nt = keys %{$Post{grads}{export}};  my $nn = $nt;

    foreach my $exp (sort {$a <=> $b}  keys %{$Post{grads}{export}}) {

        @{$Post{grads}{export}{$exp}{files}} = sort @{$Post{grads}{newfiles}};

        $Post{grads}{export}{$exp}{rdir} = &Others::PlaceholderFillDate($Post{grads}{export}{$exp}{rdir},$Post{yyyymmddcc},@phs);

        if (&Outils::ExportFiles(\%{$Post{grads}{export}{$exp}}) ) {
            &Ecomm::PrintMessage(0,14+$Post{arf},144,1,1,sprintf("ExportGrads: There was an error with file export"));
            next;
        }
        $nn--

    }

    my $date = gmtime();
    my $inc  = $nn ? ' not quite' : '';
    &Ecomm::PrintMessage(0,12+$Post{arf},144,1,2,sprintf("Export$inc accomplished at %s",$date));


return 0;
}


sub GradsScript {
# ======================================================================================
#  The general purpose of &GradsScript is to allow users to conduct secondary or
#  tertiary processing on the newly created GrADS files. This processing usually
#  takes the form of image creation for the web but it can be anything the user
#  wants it to be. Feel free to modify this routine to your needs; however,
#  make sure you keep a copy of your changes as UEMS updates may overwrite this
#  file.
#
#  In the default configuration, &GradsScript is called from &Grib2Grads (bottom) 
#  with arguments:
#
#    $driver  - The path/filename to the primary routine used for processing
#    $gdir    - The path to the GrADS post processing directory (<domain>/emsprd/grads)
#    $rdir    - The path/directory to the run-time directory 
#    $dnum    - The domain number to process
#    $fref    - A reference to the GrADS files
#
#  Any changes you make may render these parameters obsolete.  
# ======================================================================================
#
use List::Util 'first';

    my ($driver,$gdir,$rdir,$dnum,$fref) = @_;  my @files = @{$fref};

    my $cntrl = first {/\.ctl/} @files;  $cntrl = &Others::popit($cntrl);
    my $gslog = "$rdir/log/post_grads2web.log";  &Others::rm($gslog);

    my ($path, $prog) = &Others::popit2($driver);

    $driver = &Others::FillPlaceholders($driver,"EMSDIR:$ENV{UEMS}","UEMSDIR:$ENV{UEMS}");


    &Ecomm::PrintMessage(1,9,124,1,1,"Processing GrADS file(s) with $driver");

    #  Make sure that the driver exists; otherwise return with message.
    #
    unless (-s $driver) {&Ecomm::PrintMessage(6,12,98,1,1,'GradsScript Error',"It appears that\n\nX03X$driver\n\ndoes not exist. Go find it and try again.");return;}

    #-----------------------------------------------------------------------------------
    #  With UEMS V18, the arguments passed to the image generation scripts changed:
    #
    #    $driver - The path/filename to the primary routine used for processing
    #    $gdir   - The path to the GrADS post processing directory
    #    $cntrl  - The filename of the GrADS control file
    #    $dnum   - The domain number to process
    #
    #  Additionally, the name of the sub-directory beneath <domain>/emsprd/grads 
    #  containing the web pages & images is now padded with a "0", i.e., d1htm -> d01htm
    #-----------------------------------------------------------------------------------
    #
    if (my $err = &Ecore::SysExecute("$driver $gdir $cntrl  $dnum",$gslog)) {

        $mesg = "It appears that $prog failed while running:\n\n".
                "$driver $gdir $cntrl $dnum\n\n".
                "Try it for yourself and fix the problem.";
        &Ecomm::PrintMessage(6,14,255,1,1,'GradsScript Error',$mesg);
        &Ecomm::PrintMessage(0,12,98,1,1,"Additional information may be found in:\n\n$gslog") if -s $gslog;
        return;
    }

    open my $ifh, '<', "$gslog";
    while (<$ifh>) {
        next unless /firefox/i;
        s/^ +//g;
        &Ecomm::PrintMessage(7,12,144,1,0,"You can view the simulation images with:\n\n$_");
    } close $ifh;

return;
}



