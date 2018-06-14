#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Gempak.pm
#
#  DESCRIPTION:  Gempak contains the routines used to process the GRIB 2 files 
#                from the UEMS UPP for use with Gempak.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Gempak;

use warnings;
use strict;
require 5.008;
use English;

use vars qw ($mesg);


sub Process2Gempak {
# ======================================================================================
#  The &Process2Gempak routine is the driver for the processing and managing the 
#  creation of GEMPAK grid files from GRIB 2.
# ======================================================================================
#
use Cwd;

    my ($ftype, $g2ref) = @_; my %Post = %{$g2ref};

    return %Post unless $Post{proc} and %{$Post{gempak}};


    #----------------------------------------------------------------------------------
    #  Grib2Gempak - Where all the processing magic happens
    #----------------------------------------------------------------------------------
    #
    @{$Post{gempak}{newfiles}} = ();
    @{$Post{gempak}{newfiles}} = &Grib2Gempak($ftype,\%Post);


    #----------------------------------------------------------------------------------
    #  Hey, I'm in the import/export business!
    #----------------------------------------------------------------------------------
    #
    &ExportGempak($ftype,\%Post);


    #  Before returning collect the newly minted GEMPAK files located in the emsprd/gempak
    #  directory.  Get a string to match against all available files.
    #
    @{$Post{gempak}{allfiles}} = ();
    
    my ($ymd, $match) = split '_', $Post{gempak}{fname}, 2; ($match, $ymd) = split '\.', $match;
    push @{$Post{gempak}{allfiles}} => Cwd::realpath($_) foreach &Others::FileMatch($Post{gempak}{dpost},$match,0,0);


return %Post;
}


sub Grib2Gempak {
# ======================================================================================
#  This routine uses the dcgrib2 routine to process simulation GRIB 2 files into
#  GEMPAK grid files. Lots of stuff going on here so pay close attention.
# ======================================================================================
#
use List::Util qw[min];

    my @Post    = ();
    my @Gempak  = ();

    my ($ftype, $g2ref) = @_; my %Post = %{$g2ref};
  
    my $dom      = sprintf '%02d', $Post{domain};
    my $dcgrib2  = "$Post{gempak}{nawips}/os/linux/bin/dcgrib2";
    my $MAXGRIDS = 51999; #  Maximum number of GEMPAK grids (set at compile time)


    #----------------------------------------------------------------------------------
    #  Alert the user if no files are available for processing
    #----------------------------------------------------------------------------------
    #
    unless (@{$Post{grib}{newfiles}}) {
        &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Creating GEMPAK files from domain %s GRIB 2 files",$dom));
        &Ecomm::PrintMessage(0,12+$Post{arf},144,1,1,"I looked, but there are no domain $dom $ftype GRIB 2 files to process right now");
        return ();
    }


    #----------------------------------------------------------------------------------
    #  Make sure any Grib 2 files available for processing actually need to be 
    #  processed as defined by the $Post{gempak}{freq} (FREQ:START:STOP) setting
    #----------------------------------------------------------------------------------
    #
    my @Gribs  = ();
    (my $mfreq = $Post{gempak}{freq}) =~ s/:\w*//g;
    unless (@Gribs = sort &Outils::FrequencySubset($Post{gempak}{freq},@{$Post{grib}{newfiles}})) {
        &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Creating GEMPAK files from domain %s GRIB 2 files",$dom));
        &Ecomm::PrintMessage(0,12+$Post{arf},144,1,1,"Yay! I have nothing to do since the processing frequency ($mfreq minutes) has left me without any GRIB 2 files!");
        return ();
    }

    
    my $sdate = &Others::DateString2Pretty(&Others::Grib2VerifTime($Gribs[0])); $sdate =~ s/^\w{3}\s//g; $sdate =~ s/\s+/ /g; $sdate =~ s/:\d\d / /;
    my $edate = &Others::DateString2Pretty(&Others::Grib2VerifTime($Gribs[-1]));$edate =~ s/^\w{3}\s//g; $edate =~ s/\s+/ /g; $edate =~ s/:\d\d / /;

    @Gribs == 1 ? &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Creating GEMPAK grids from a single measly domain %s %s GRIB 2 file for $sdate",$dom,$ftype=~/^wrf/ ? 'primary':'auxiliary'))
                : &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Creating GEMPAK grids from domain %s %s GRIB 2 files every %s minutes between $sdate & $edate",$dom,$ftype=~/^wrf/ ? 'primary':'auxiliary',$mfreq));

 
    #----------------------------------------------------------------------------------
    #  Make sure there are no files or links left over from a previous process.
    #  This step is a bit tricky because while we want to delete any existing GEMPAK
    #  files for the current domain being processed (unless scour), we don't want
    #  to delete GEMPAK files previously created for another domain or file type. 
    #----------------------------------------------------------------------------------
    #
    if (&Others::mkdir($Post{gempak}{dpost})) {&Ecomm::PrintMessage(6,12+$Post{arf},144,1,2,"Grib2Gempak: Failed to create $Post{gempak}{dpost} - Return"); return ();}

    foreach (&Others::FileMatch($Post{gempak}{dpost},'',1,0)) {&Others::rm("$Post{gempak}{dpost}/$_") unless /_d\d\d.[gem]/; }

    if ($Post{scour}) {
        my ($ymd, $match) = split '_', $Post{gempak}{fname}, 2; ($match, $ymd) = split '\.', $match;
        &Others::rm("$Post{gempak}{dpost}/$_") foreach &Others::FileMatch($Post{gempak}{dpost},$match,1,0);
    }


    #----------------------------------------------------------------------------------
    #  Make sure the dcgrib2 binary exist and that my cheese is where I left it.
    #----------------------------------------------------------------------------------
    #
    if (&Others::FileExists($dcgrib2)) {
        &Ecomm::PrintMessage(6,12+$Post{arf},144,2,1,'Grib2Gempak: Who moved my Cheese!',"It appears that $dcgrib2 is missing.\n\nNo GEMLOVE for you!");
        return ();
    }



    #----------------------------------------------------------------------------------
    #  The next step is to create the working directory (if necessary), which is the
    #  same as the final GRIB destination, /emsprd/grib. Afterwards, create the links
    #  to the tables and other necessary files.
    #
    #  This odyssey begins in the emsprd/grib directory.
    #----------------------------------------------------------------------------------
    #
    chdir $Post{gempak}{dpost};


    #  Attend to some local configuration
    #
    my $dclog1 = File::Spec->abs2rel($Post{gempak}{gemlog1});  &Others::rm($dclog1);
    my $dclog2 = File::Spec->abs2rel($Post{gempak}{gemlog2});  &Others::rm($dclog2);
    my $gemlog = File::Spec->abs2rel($Post{gempak}{gemlog});   &Others::rm($gemlog);


    #----------------------------------------------------------------------------------
    #  Ideally, the user will have uncommented the NAWIPS environment variable 
    #  in the startup files but just to make sure that the proper tables are 
    #  being used set the GEMPAK environment here.
    #----------------------------------------------------------------------------------
    #
    &Outils::SetNawipsEnvironment($Post{gempak}{nawips});


    #----------------------------------------------------------------------------------
    #  Before commencing, run the UNIDATA provided (UEMS modified) "clean-up" utility
    #----------------------------------------------------------------------------------
    #
    if (my $err = &Ecore::SysExecute("$Post{gempak}{nawips}/bin/cleanup > /dev/null 2>&1")) {

        #  If the user passed a Control-C (^C) then simply clean up the mess
        #  that was made and exit
        # 
        &Outils::ProcessInterrupt('Grib2Gempak',2,$Post{gempak}{dpost},()) if $err == 2;
        &Ecomm::PrintMessage(6,12+$Post{arf},144,1,1,sprintf('NAWIPS cleanup failed (%s) - Throwing caution to the wind',$err));
    }

    
    #----------------------------------------------------------------------------------
    #  Get the number of fields to be written to the GEMPAK file(s). There's a limit
    #  of $MAXGRIDS (59999) but there is a problem if auto post is running since
    #  there is no way to know with certainty if the $MAXGRIDS value will be exceeded
    #  prior to running dcgrib2. A work-around for this problem is to automatically
    #  use $MAXGRIDS as the argument to -m when creating the file and hope that 
    #  successive calls don't caus e the number of grids to exceed $MAXGRIDS.
    #----------------------------------------------------------------------------------
    #
    my $gemfile = '';
    my $ngribs  = &Others::Grib2NumGribs($Gribs[-1])+1;  #  +1 is fudge factor
    my @Agribs  = sort &Outils::FrequencySubset($Post{gempak}{freq},@{$Post{grib}{allfiles}});
    my $cgrids  = $ngribs * (@Agribs - @Gribs);

    my $mono = ($cgrids < $MAXGRIDS) ? $Post{gempak}{monofile} : 0;

    if ($mono) {  #  Create the gemfile name

        my $ptfile = File::Spec->abs2rel($Gribs[0]);
        my $ptloc  = &Others::popit($ptfile); &Others::rm($ptloc);

        #----------------------------------------------------------------------------------
        #  First - Create the name of the GEMPAK file to which the grids will be written.
        #  If the file currently exists and index = 0, then delete it. Otherwise, there 
        #  is some additional work to do.  To create the filename we need to get the 
        #  initialization date/time of the simulation from the GRIB file.
        #----------------------------------------------------------------------------------
        #
        unless (symlink $ptfile => $ptloc) {
            &Ecomm::PrintMessage(6,12+$Post{arf},144,0,2,sprintf("Link creation to emsprd/grib/$ptloc Failed (%s) - Return",$!));
            return ();
        }
        my $init   = &Others::Grib2InitTime($ptloc);
        $gemfile   = &Others::PlaceholderFillDate($Post{gempak}{fname},$init,()); 

        &Others::rm($gemfile) unless $Post{index};

        #----------------------------------------------------------------------------------
        #  If the file still exists, then the process gets messy. Delete the file unless
        #  auto post is ON because we want to write additional grids to the file; however,
        #  if the additional grids result the total number of grids in the GEMPAK file to
        #  exceed $MAXGRIDS then set $mono to 0 and proceed from the beginning with 
        #  individual GEMPAK files.
        #----------------------------------------------------------------------------------
        #
        &Others::rm($gemfile) unless $Post{autop};

        my $tgrids = $ngribs * @Agribs;

        $mono = 0 if $tgrids > $MAXGRIDS;

        unless ($mono) {
            $mesg = "The number if GRIB 2 fields exceeds the maximum allowed in a single GEMPAK file ($MAXGRIDS). Changing ".
                    "MONOFILE_GEMPAK parameter to \"NO\" and creating GEMPAK files for each output time, which increases my ".
                    "workload but I'm happy to to it for you, again. Sigh :(";
            &Ecomm::PrintMessage(6,14+$Post{arf},94,1,2,'Maximum Number of Fields Exceeded',$mesg);
            &Others::rm($gemfile);

            @Gribs = @Agribs;
        }

    }


    #----------------------------------------------------------------------------------
    #  Calculate the number of grids that will be written to the GEMPAK file
    #----------------------------------------------------------------------------------
    #
    my $maxgrids = $mono ? $Post{autop} ? $MAXGRIDS : $ngribs * @Gribs : $ngribs;
    

    #----------------------------------------------------------------------------------
    #  Begin the process of looping over the  available GRIB 2 file and writing the 
    #  fields to the appropriate GEMPAK file.
    #----------------------------------------------------------------------------------
    #
    my $ntimes  = @Gribs;

    for my $ntime (1 .. $ntimes) {

        $|    = 1;
        my $i = $ntime-1;

        my $ptfile = File::Spec->abs2rel($Gribs[$i]);
        my $ptloc  = &Others::popit($ptfile); &Others::rm($ptloc);
           
        #  Create the link from the emsprd/gempak directory to the grib file in emsprd/grib
        #
        unless (symlink $ptfile => $ptloc) {
            &Ecomm::PrintMessage(6,12+$Post{arf},144,0,2,sprintf("Link creation to emsprd/grib/$ptloc Failed (%s) - Return",$!));
            return ();
        }


        unless ($mono) {
            my $verf   = &Others::Grib2VerifTime($ptloc);
            $gemfile   = &Others::PlaceholderFillDate($Post{gempak}{fname},$verf,()); &Others::rm($gemfile);
        }


        #==================================================================================
        #  Set the command for running dcgrib2
        #==================================================================================
        #
        my $cmd = "$dcgrib2 -v 1 -d $dclog1 -m $maxgrids -e GEMTBL=$ENV{GEMTBL}  $gemfile < $ptloc";
       

        #----------------------------------------------------------------------------------
        #  If the user passed --debug real|wrfm then it's time to shut down and allow
        #  their hands to get dirty.
        #----------------------------------------------------------------------------------
        #
        if ($ENV{POST_DBG} == -201 ) {
            &Ecomm::PrintMessage(4,12+$Post{arf},256,2,2,"The table has been set for you. Now try running:\n\n  % $cmd\n\nfrom the $Post{gempak}{dpost} directory.");
            &Ecore::SysExit(98);
        }
    

        #----------------------------------------------------------------------------------
        #  Run dcgrib2 and create the GEMPAK grid file
        #----------------------------------------------------------------------------------
        #
        &Ecomm::PrintMessage(0,16+$Post{arf},144,1,0,sprintf("%10s Writing fields from $ptloc to GEMPAK - ","$ntime of $ntimes :")); $ntime++;

        if (my $err = &Ecore::SysExecute($cmd,$dclog2)) {

            #  If the user passed a Control-C (^C) then simply clean up the mess
            #  that was made and exit
            # 
            &Outils::ProcessInterrupt('dcgrib2',2,$Post{gempak}{dpost},[$gemfile,$ptloc]) if $err == 2;
            &Ecomm::PrintMessage(0,1,144,0,2,'Failure (No GEMLOVE for You)');
            if (-s $dclog2 and open my $bfh, '<', $dclog2) {
                my @lines = <$bfh>; close $bfh; foreach (@lines) {chomp $_; s/^\s+//g;}
                &Outils::ErrorHelper($dclog2,$Post{arf},$err,@lines);
            }
            return ();
        }
        &Ecomm::PrintMessage(0,1,144,0,0,sprintf('%s (%.2f MBs)',$gemfile,&Others::Bytes2MB(&Others::FileSize($gemfile))));


        &Others::rm($ptloc,$dclog1,$dclog2);

        push @Gempak, Cwd::realpath("$Post{gempak}{dpost}/$gemfile");

     }  #  foreach sort {$a <=> $b} keys %Ghash


     &Ecomm::PrintMessage(0,14+$Post{arf},255,2,1,sprintf("Reminder: Precipitation accumulation period in GEMPAK files is %s",&Ecomm::FormatTimingString($Post{grib}{pacc}*60)));

     #----------------------------------------------------------------------------------
     #  Time to clean up after ourselves
     #----------------------------------------------------------------------------------
     #
     @Gempak = sort &Others::rmdups(@Gempak);

     foreach (&Others::FileMatch($Post{gempak}{dpost},'',1,0)) {&Others::rm("$Post{gempak}{dpost}/$_") unless /\.gem/;}

     my $date = gmtime();
     &Ecomm::PrintMessage(0,12+$Post{arf},144,1,2,sprintf("Creation of domain $dom %s GEMPAK files %s at %s UTC",$ftype=~/^wrf/ ? 'primary':'auxiliary',@Gempak ? 'completed':'failed',$date));


     #==================================================================================
     #  The GEMPAK script stuff will go here eventually
     #==================================================================================
     #


return @Gempak;
}


sub ExportGempak {
# =================================================================================
#  This routine uses the exports any Gempak files to other locations per the 
#  user's request.
# =================================================================================
#
    my ($ftype, $pref) = @_; my %Post = %{$pref};

    return unless %{$Post{gempak}{export}} and @{$Post{gempak}{newfiles}};


    #  Attend to some local configuration
    #
    my $dom  = sprintf '%02d', $Post{domain};
    my @phs  = (@{$Post{placeholders}},'DSET:gempak');

    &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Exporting Domain %s %s GEMPAK files to wonderful and exotic locations",$dom,$ftype=~/^wrf/ ? 'primary':'auxiliary'));

    #----------------------------------------------------------------------------------
    #  Loop over each of the export requests (there may be more than one)
    #----------------------------------------------------------------------------------
    #
    my $nt = keys %{$Post{gempak}{export}}; my $nn = $nt;

    foreach my $exp (sort {$a <=> $b}  keys %{$Post{gempak}{export}}) {

        $Post{gempak}{export}{$exp}{rdir} = &Others::PlaceholderFillDate($Post{gempak}{export}{$exp}{rdir},$Post{yyyymmddcc},@phs);

        @{$Post{gempak}{export}{$exp}{files}} = $Post{gempak}{monofile} ? @{$Post{gempak}{newfiles}} : &Outils::FrequencySubset($Post{gempak}{export}{$exp}{freq},@{$Post{gempak}{newfiles}});
        @{$Post{gempak}{export}{$exp}{files}} = sort @{$Post{gempak}{export}{$exp}{files}};

        unless (@{$Post{gempak}{export}{$exp}{files}}) {
            if ($ENV{POST_DBG} > 0) {
                &Ecomm::PrintMessage(6,12+$Post{arf},144,2,1,sprintf("I have nothing to move since the export frequency has left me without any domain $dom %s GEMPAK files!",$ftype=~/^wrf/ ? 'primary':'auxiliary'));
            }
            next;
        }

        if (&Outils::ExportFiles(\%{$Post{gempak}{export}{$exp}}) ) {
            &Ecomm::PrintMessage(0,14+$Post{arf},144,1,1,sprintf("&ExportGempak: There was an error with file export"));
            next;
        }
        $nn--;

    }

    my $date = gmtime();
    my $inc  = $nn ? ' not quite' : '';
    &Ecomm::PrintMessage(0,12+$Post{arf},144,1,2,sprintf("Export$inc accomplished at %s",$date));



return 0;
}


