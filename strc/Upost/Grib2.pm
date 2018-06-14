#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Grib2.pm
#
#  DESCRIPTION:  Grib2 contains the routines used when processing the simulation
#                output into GRIB 2 files.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Grib2;

use warnings;
use strict;
require 5.008;
use English;

use vars qw ($mesg);


sub Process2Grib {
# =================================================================================
#  The &Process2Grib routine is the driver for the processing and managing the 
#  creation of Grib 2 files via the UEMS version of the UPP.
# =================================================================================
#
    my ($ftype, $g2ref) = @_; my %Post = %{$g2ref};

    return %Post unless $Post{proc};

    #----------------------------------------------------------------------------------
    #  Now is the perfect time to export those pesky netCDF files you've been 
    #  collecting in the wrfprd directory.
    #----------------------------------------------------------------------------------
    #
    &ExportNetcdf($ftype,\%Post);


    #----------------------------------------------------------------------------------
    #  No more processing is needed if the %{$Post{grib}} hash is empty, which 
    #  happens when --nogrib is passed but there may be other times as well.
    #----------------------------------------------------------------------------------
    #
    return %Post unless %{$Post{grib}};


    #----------------------------------------------------------------------------------
    #  Process the netCDF files into GRIB 2 format UNLESS the --noupp flag was passed,
    #  in which case 
    #----------------------------------------------------------------------------------
    #
    @{$Post{grib}{allfiles}} = ();

    @{$Post{grib}{newfiles}} = ();
    @{$Post{grib}{newfiles}} = &Netcdf2Grib($ftype,\%Post)  unless $Post{noupp};

    
    #----------------------------------------------------------------------------------
    #  Hey, I'm in the import/export business!
    #----------------------------------------------------------------------------------
    #
    &ExportGrib2($ftype,\%Post);


    #  Before returning collect the newly minted grib files located in the emsprd/grib
    #  directory.  Get a string to match against all available files.
    #
    my ($ymd, $match) = split '_', $Post{grib}{fname}, 2; ($match, $ymd) = split '\.', $match;
    push @{$Post{grib}{allfiles}} => $_ foreach &Others::FileMatch($Post{grib}{dpost},$match,0,0);


    #  If the --noupp flag was passed then all the GRIB 2 files unless emsprd/grib are
    #  considered eligible for further processing.
    #
    @{$Post{grib}{newfiles}} = @{$Post{grib}{allfiles}} if $Post{noupp};


return %Post;
}


sub Netcdf2Grib {
# =================================================================================
#  This routine uses the UEMS version of the Unified Post Processor (UPP) to 
#  process simulation output netCDF files into GRIB 2 format. During this 
#  process, the data are interpolated from native coordinates to pressure,
#  height (AGL & ASL), theta, and/or potential vorticity levels. The output
#  is written directly to GRIB 2 files that may be used in a variety of 
#  secondary applications.
#
#  Lots of stuff going on here so pay close attention.
# =================================================================================
#
    my @Links   = ();
    my @Deletes = (); #  The list of files to be deleted after success
    my @Deloops = (); #  The list of files to be deleted after each process loop
    my @Gribs   = ();

    my ($ftype, $g2ref) = @_; my %Post = %{$g2ref};

  
    #  Attend to some local configuration
    #
    my $dom    = sprintf '%02d', $Post{domain};
    my $emsupp = "$ENV{EMS_BIN}/emsupp";
    my $infile = 'emsupp.in';


    #----------------------------------------------------------------------------------
    #  Alert the user if no files are available for processing
    #----------------------------------------------------------------------------------
    #
    unless (@{$Post{netcdf}{newfiles}}) {
        &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Creating GRIB 2 files from domain %s $ftype files",$dom));
        &Ecomm::PrintMessage(0,12+$Post{arf},144,1,1,"I looked, but there are no domain $dom $ftype netCDF files to process right now");
        return ();
    }

   
    #----------------------------------------------------------------------------------
    #  Make sure any netCDF files available for processing actually need to be 
    #  processed as defined by the $Post{grib}{freq} (FREQ:START:STOP) setting
    #----------------------------------------------------------------------------------
    #
    my @NetCDFs  = ();
    (my $mfreq = $Post{grib}{freq}) =~ s/:\w*//g;
    unless (@NetCDFs = sort &Outils::FrequencySubset($Post{grib}{freq},@{$Post{netcdf}{newfiles}})) {
        &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Creating GRIB 2 files from domain %s $ftype files",$dom));
        &Ecomm::PrintMessage(0,12+$Post{arf},144,1,1,"Yay! I have nothing to do since the processing frequency ($mfreq minutes) has left me without any $ftype files!");
        return ();
    }


    #----------------------------------------------------------------------------------
    #  Prepare a message to the used about what is being done. Note that the following currently 
    #  does not work for monolithic netCDF files.
    #----------------------------------------------------------------------------------
    #
    my $sdate = &Others::DateString2Pretty(&Others::NetcdfVerifTime($NetCDFs[0])); $sdate =~ s/^\w{3}\s//g; $sdate =~ s/\s+/ /g; $sdate =~ s/:\d\d / /;
    my $edate = &Others::DateString2Pretty(&Others::NetcdfVerifTime($NetCDFs[-1]));$edate =~ s/^\w{3}\s//g; $edate =~ s/\s+/ /g; $edate =~ s/:\d\d / /;

    @NetCDFs == 1 ? &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Creating a GRIB 2 file from a single measly domain %s %s file for $sdate",$dom,$ftype=~/^wrf/ ? 'primary':'auxiliary'))
                  : &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Creating GRIB 2 files from domain %s %s files every %s minutes between $sdate & $edate",$dom,$ftype=~/^wrf/ ? 'primary':'auxiliary',$mfreq));


    my @NetCDFa = sort &Outils::FrequencySubset($Post{grib}{freq},@{$Post{netcdf}{allfiles}});  #  Will be used soon

 
    if (&Others::mkdir($Post{grib}{dpost})) {&Ecomm::PrintMessage(6,12+$Post{arf},144,1,2,"Netcdf2Grib: Failed to create $Post{grib}{dpost} - Return"); return ();}

    #----------------------------------------------------------------------------------
    #  Make sure there are no files or links left over from a previous process.
    #  This step is a bit tricky because while we want to delete any existing GRIB 2
    #  files for the current domain being processed (unless scour), we don't 
    #  want to delete grib files previously created for another domain or file type. 
    #----------------------------------------------------------------------------------
    #
    foreach (&Others::FileMatch($Post{grib}{dpost},'',1,0)) {&Others::rm("$Post{grib}{dpost}/$_") unless /_d\d\d.grb/; }
    
    if ($Post{scour}) {
        my ($ymd, $match) = split '_', $Post{grib}{fname}, 2; ($match, $ymd) = split '\.', $match;
        &Others::rm("$Post{grib}{dpost}/$_") foreach &Others::FileMatch($Post{grib}{dpost},$match,1,0);
    }


    #----------------------------------------------------------------------------------
    #  Make sure the EMS UPP binary exists and that my cheese is where I left it.
    #----------------------------------------------------------------------------------
    #
    if (&Others::FileExists($emsupp)) {
        &Ecomm::PrintMessage(6,12+$Post{arf},144,1,2,'Netcdf2Grib: Who moved my Cheese!',"It appears that $emsupp is missing.\n\nGo find it Inspector Clouseau!");
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
    chdir $Post{grib}{dpost};


    #----------------------------------------------------------------------------------
    #  Read the UEMS UPP control file from the static directory and write it to 
    #  'fort.14' under emsprd/grib/ while assigning values for MDLID, OCNTR, & SCNTR
    #  Additionally, the $crtm variable controls whether links to the CRTM2 tables 
    #  need to be created. Set $crtm = 1 if the user has added any of the synthetic 
    #  brightness temperature fields to the UEMS UPP control file. By default, the 
    #  fields are not included in the control file because processing the data takes
    #  significantly longer to process.
    #----------------------------------------------------------------------------------
    #
    unless (-s $Post{grib}{cntrl}) {$ENV{OMESG} = &Ecomm::TextFormat(0,0,88,0,0,"Missing UEMS Control file: $Post{grib}{cntrl}"); return ();}

    open (my $rfh, '<', $Post{grib}{cntrl});  my @lines = <$rfh>; close $rfh;
    open (my $wfh, '>', "$Post{grib}{dpost}/fort.14"); push @Deletes, "$Post{grib}{dpost}/fort.14"; push @Deletes, "$Post{grib}{dpost}/fort.600"; my $crtm=0;
    foreach (@lines) {s/MDLID/$Post{grib}{mdlid}/m;s/OCNTR/$Post{grib}{ocntr}/m;s/SCNTR/$Post{grib}{scntr}/m;print $wfh $_;$crtm=1 if /AMSRE|SBT|SEVIR|SSMI|TMI_/;} close $wfh;
    
    
 
    #----------------------------------------------------------------------------------
    #  Provide some information to the user.
    #----------------------------------------------------------------------------------
    #
    my $mp = $Post{grib}{mdlid}+=0;
    my $os = $Post{grib}{ocntr}+=0;
    my $ss = $Post{grib}{scntr}+=0;
    $mesg = "GRIB file process information:\n\n".
            "X02XProcess (Model) ID : $mp\n".
            "X02XOriginating Center : $os\n".
            "X02XSubCenter ID       : $ss\n\n";
    &Ecomm::PrintMessage(0,14+$Post{arf},78,1,0,$mesg);


    @Links   = (@{$Post{grib}{grbtbls}},$crtm ? @{$Post{grib}{crtmtbls}} : ());
    @Deletes = (@Deletes, map {&Others::popit($_)} (@{$Post{grib}{grbtbls}},$crtm ? @{$Post{grib}{crtmtbls}} : ()));



    #----------------------------------------------------------------------------------
    #  Before getting down & 1i0irty, we must set up the MPI environment for running
    #  the UEMS UPP. Collect the output from &Empi::ConfigureProcessMPI and then
    #  check for errors.
    #----------------------------------------------------------------------------------
    #
    my %Process = %{$Post{grib}{process}};

    my %mpirun  = &Empi::ConfigureProcessMPI(\%Process);

    if ($Process{mpidbg}) {
        foreach (keys %mpirun) {next if $_ eq 'nodes'; &Ecomm::PrintMessage(4,12+$Post{arf},255,1,0,sprintf("MPIRUN - %-12s = %s",$_,$mpirun{$_}));}
    }

    if ($mpirun{error}) {
        &Ecomm::PrintMessage(6,14+$Post{arf},255,1,2,'Error during MPI configuration:',$mpirun{error});
        return ();
    }

    if ($mpirun{error} = &Empi::WriteHostsFile(\%{$mpirun{nodes}},\$mpirun{hostsfile}) )  {
        &Ecomm::PrintMessage(6,14+$Post{arf},94,1,2,'Error during writing of MPI hosts file:', $mpirun{error});
        return ();
    }

    &Ecomm::PrintMessage(0,14+$Post{arf},255,2,1,sprintf("Using $Process{totalcpus} processors to run the UEMS UPP - \"This thingy goes to $Process{totalcpus}!\""));



    #----------------------------------------------------------------------------------
    #  Get the simulation start time from the 1st netCDF file in the list to process
    #  A link from the emsprd/grib directory to <domain>/wrfprd is created because 
    #  the rdwrfnc utility has difficulty with long paths. Also determine whether
    #  the netcdf file contains a single or multiple output times ($mono).
    #
    #  !! If mono file - @verfs is not subset fr freq - fix!
    #----------------------------------------------------------------------------------
    #
    push @Deletes => $mpirun{hostsfile};
    my $local = &Others::popit($NetCDFs[0]); &Others::rm($local); symlink $NetCDFs[0] => $local; 
    my ($init, @verfs) = &Others::FileFcstTimes($local,'netcdf'); &Others::rm($local);
    my $indx = @NetCDFa - @NetCDFs;
    my $mono = (@verfs > 1) ? 1 : 0; my $ntimes = $mono ? @verfs : @NetCDFs; my $ntimespi = $ntimes + $indx;
    my $type = $mono ? 'mono' : 'single'; $type = 'auxhist' if  $ftype eq 'auxhist';
    my $core = $Post{core} eq 'arw' ? 'NCAR' : 'NCEP';
    my $pacc = 60.0*$Post{grib}{pacc};


    
    #=================================================================================
    #  Begin the processing of netCDF into GRIB2 files. Begin by creating links to
    #  any necessary tables. Note that both the $init & @verfs date/time string are 
    #  of the format YYYYMMDDHHMNSS (20170506030000).
    #=================================================================================
    #
    foreach (@Links) {my $l = &Others::popit($_); symlink $_ => $l; push @Deletes => "$Post{grib}{dpost}/$l";}

    for my $ntime (1 .. $ntimes) {

        $|    = 1;
        my $i = $ntime-1;

        #-----------------------------------------------------------------------------
        #  Retrieve the name of the netCDF file to process. $ptfile hold the filename
        #  to process
        #-----------------------------------------------------------------------------
        #
        my $ptfile = File::Spec->abs2rel($mono ? $NetCDFs[0] : $NetCDFs[$i]); 
        my $ptloc  = &Others::popit($ptfile); 
        my $ptdate = &Others::DateStringWRF2DateString($ptloc);
       

        #  Create the link from the emsprd/grib directory to the netcdf file in wrfprd.
        #
        unless (symlink $ptfile => $ptloc) {
            &Ecomm::PrintMessage(0,1,144,0,2,sprintf("Link creation to wrfprd/$ptloc Failed (%s) - Return",$!));
            return ();
        }
        push @Deloops => "$Post{grib}{dpost}/$ptloc";


        #-----------------------------------------------------------------------------
        #  Get the verification file time from the file being processed, which will
        #  be used to determine the filename and verification date of the file to
        #  used as the initial bucket dump time for the precipitation accumulation 
        #  period.
        #
        #  There are only two possible options for the accumulation period, either
        #  the time between netCDF files being processed of simulation total.
        #----------------------------------------------------------------------------- 
        #
        my $vtime  = 0;
        my $pacc0  = 0;
        my $acfile = 0;
        my $acloc  = 0;
        

        @verfs = &Others::NetcdfVerifTimes($ptloc) unless $mono;
        $vtime = shift @verfs;  #  The file verification time ($vtime) is of the format YYYYMMDDHHMNSS


        #  Calculate the verification time of the accumulation period start
        #
        $pacc0 = &Others::CalculateNewDate($vtime,-$pacc);
        $pacc0 = $init if $pacc0 < $init;

        
        #  Convert the verification times into WRF date string format
        #
        $vtime = &Others::DateString2DateStringWRF($vtime);  #  YYYY-MM-DD_HH:MN:SS
        $pacc0 = &Others::DateString2DateStringWRF($pacc0);  #  YYYY-MM-DD_HH:MN:SS


        #  Create a link from the file containing the accumulation period start time
        #  to the local directory.  If a monolithic file is being processed then the
        #  files are the same and only the times differ. If this is the 00-hour time
        #  being processed then the files and times are the same.
        #
        unless ($mono or $pacc0 eq $vtime) {
            ($acloc  = $ptloc)  =~ s/$vtime/$pacc0/;
            ($acfile = $ptfile) =~ s/$vtime/$pacc0/;
            symlink $acfile => $acloc; push @Deloops => "$Post{grib}{dpost}/$ptloc";
        }

    
        #  Write the UEMS UPP input file
        #
        push @Deloops, "$Post{grib}{dpost}/$infile";
        open (my $ifh, '>', "$Post{grib}{dpost}/$infile"); 

        print $ifh "$ptloc\n",
                   "$core\n",
                   "$type\n",
                   "netcdf\n",
                   "$vtime\n",
                   "$pacc\n";
         close $ifh; $| = 1;

        my $ntimepi  = $ntime + $indx;
        &Ecomm::PrintMessage(0,16+$Post{arf},144,1,0,sprintf("%10s Writing fields from $vtime to GRIB - ","$ntimepi of $ntimespi :"));


        #----------------------------------------------------------------------------------
        #  If the user passed --debug real|wrfm then it's time to shut down and allow
        #      their hands to get dirty.
        #----------------------------------------------------------------------------------
        #
        if ($ENV{POST_DBG} == -$ntime ) {
            &Ecomm::PrintMessage(4,9+$Post{arf},256,2,2,"The table has been set for you. Now try running:\n\n  % $mpirun{mpiexec}\n\nfrom the $Post{grib}{dpost} directory.");
            &Ecore::SysExit(98);
        }
        &Others::rm($Post{grib}{logfile});


        if (my $err = &Ecore::SysExecute($mpirun{mpiexec},$Post{grib}{logfile})) {

            #  If the user passed a Control-C (^C) then simply clean up the mess
            #  that was made and exit
            #
            &Outils::ProcessInterrupt('emsupp',2,$Post{grib}{dpost},\@Deletes,\@Deloops) if $err == 2;


            #  Otherwise, the failure has to be investigated
            #
            &Ecomm::PrintMessage(0,0,24,0,1,"Failed ($err)!");

            if (-s $Post{grib}{logfile} and open my $mfh, '<', $Post{grib}{logfile}) {
                my @lines = <$mfh>; close $mfh; foreach (@lines) {chomp $_; s/^\s+//g;}
                &Outils::ErrorHelper($Post{grib}{logfile},$Post{arf},$err,@lines);
            }

            #  Note that nothing returns from &ProcessInterrupt
            #
            &Outils::ProcessInterrupt('emsupp',$err,$Post{grib}{dpost},\@Deletes,\@Deloops);
        }


        #----------------------------------------------------------------------------------
        #  Corral and rename the newly-minted GRIB files. The date information used
        #  in the file naming convention comes from the GRIB file via wgrib. Then
        #  populate the user-defined string before renaming the file output from UPP.
        #----------------------------------------------------------------------------------
        #
        my @ngribs = sort &Others::FileMatch($Post{grib}{dpost},'EMSPRS',1,0); 
        my $ngrib  = @ngribs ? shift @ngribs : '';
       
        my @pairs = &Outils::Grib2DateStrings("$Post{grib}{dpost}/$ngrib");
           @pairs = (@pairs,"WD:$dom","CORE:$Post{core}","KEY:$ftype");

        my $grib2 = &Others::PlaceholderFill($Post{grib}{fname},@pairs);

        $mesg = (system "mv $ngrib $grib2") ? "Failed (mv code $?)" : $grib2; my $err = $?;
        &Outils::ProcessInterrupt('emsupp',2,$Post{grib}{dpost},\@Deletes,\@Deloops,[$ngrib]) if $err == 2;

        &Ecomm::PrintMessage(0,1,144,0,0,sprintf('%-34s (%.2f MBs)',$mesg,&Others::Bytes2MB(&Others::FileSize($grib2)))) if $mesg;

        push @Gribs => "$Post{grib}{dpost}/$grib2" unless $err;

        &Others::rm($_) foreach @Deloops;

        
    }  #  End of foreach netCDF -> GRIB 2 loop

    
    &Ecomm::PrintMessage(0,14+$Post{arf},255,2,1,sprintf("Reminder: Precipitation accumulation period in GRIB files is %s",&Ecomm::FormatTimingString($Post{grib}{pacc}*60)));

    #----------------------------------------------------------------------------------
    #  Time to clean up after ourselves
    #----------------------------------------------------------------------------------
    #
    @Gribs = sort &Others::rmdups(@Gribs);

    &Others::rm($mpirun{hostsfile});
    foreach (&Others::FileMatch($Post{grib}{dpost},'',1,0)) {&Others::rm("$Post{grib}{dpost}/$_") unless /_d\d\d.grb/;}

    my $date = gmtime();
    &Ecomm::PrintMessage(0,12+$Post{arf},144,1,2,sprintf("Processing $Post{core} netCDF %s output to GRIB 2 %s at %s UTC",$ftype=~/^wrf/ ? 'primary':'auxiliary',@Gribs ? 'completed':'failed',$date));


return @Gribs;
}


sub ExportNetcdf {
# =================================================================================
#  This routine uses the exports any netCDF files to other locations per the 
#  user's request.
# =================================================================================
#
    my ($ftype, $g2ref) = @_; my %Post = %{$g2ref};

    return unless %{$Post{netcdf}{export}};


    #  Attend to some local configuration
    #
    my $dom  = sprintf '%02d', $Post{domain};
    my @phs  = (@{$Post{placeholders}},'DSET:netcdf');

    &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Exporting domain %s %s netCDF files to wonderful and exotic locations",$dom,$ftype=~/^wrf/ ? 'primary':'auxiliary'));

    #----------------------------------------------------------------------------------
    #  Loop over each of the export requests (there may be more than one)
    #----------------------------------------------------------------------------------
    #
    my $nt = keys %{$Post{netcdf}{export}};  my $nn = $nt;

    foreach my $exp (sort {$a <=> $b}  keys %{$Post{netcdf}{export}}) {

        $Post{netcdf}{export}{$exp}{rdir} = &Others::PlaceholderFillDate($Post{netcdf}{export}{$exp}{rdir},$Post{yyyymmddcc},@phs);

        unless (@{$Post{netcdf}{export}{$exp}{files}} = sort &Outils::FrequencySubset($Post{netcdf}{export}{$exp}{freq},@{$Post{netcdf}{newfiles}})) {
            if ($ENV{POST_DBG} > 0) {
                &Ecomm::PrintMessage(6,12+$Post{arf},144,2,1,sprintf("I have nothing to move since the export frequency has left me without any domain $dom %s netCDF files!",$ftype=~/^wrf/ ? 'primary':'auxiliary'));
            }
            next;
        }

        if (&Outils::ExportFiles(\%{$Post{netcdf}{export}{$exp}}) ) {
            &Ecomm::PrintMessage(0,14+$Post{arf},144,1,1,sprintf("&ExportNetCDF: There was an error with file export"));
            next;
        }
        $nn--;
    }

    my $date = gmtime();
    my $inc  = $nn ? ' not quite' : '';
    &Ecomm::PrintMessage(0,12+$Post{arf},144,1,2,sprintf("Export$inc accomplished at %s",$date));

return 0;
}


sub ExportGrib2 {
# =================================================================================
#  This routine uses the exports any Grib2 files to other locations per the 
#  user's request.
# =================================================================================
#
    my ($ftype, $g2ref) = @_; my %Post = %{$g2ref};

    return unless %{$Post{grib}{export}} and @{$Post{grib}{newfiles}};


    #  Attend to some local configuration
    #
    my $dom  = sprintf '%02d', $Post{domain};
    my @phs  = (@{$Post{placeholders}},'DSET:grib2');

    &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Teleporting domain %s %s Grib 2 files to wonderful and exotic locations",$dom,$ftype=~/^wrf/ ? 'primary':'auxiliary'));   

    #----------------------------------------------------------------------------------
    #  Loop over each of the export requests (there may be more than one)
    #----------------------------------------------------------------------------------
    #
    my $nt = keys %{$Post{grib}{export}};  my $nn = $nt;
    
    foreach my $exp (sort {$a <=> $b}  keys %{$Post{grib}{export}}) {

        $Post{grib}{export}{$exp}{rdir} = &Others::PlaceholderFillDate($Post{grib}{export}{$exp}{rdir},$Post{yyyymmddcc},@phs);

        unless (@{$Post{grib}{export}{$exp}{files}} = sort &Outils::FrequencySubset($Post{grib}{export}{$exp}{freq},@{$Post{grib}{newfiles}})) {
            if ($ENV{POST_DBG} > 0) {
                &Ecomm::PrintMessage(6,12+$Post{arf},144,2,1,sprintf("I have nothing to move since the export frequency has left me without any domain $dom %s Grib 2 files!",$ftype=~/^wrf/ ? 'primary':'auxiliary'));
            }
            next;
        }

        if (&Outils::ExportFiles(\%{$Post{grib}{export}{$exp}}) ) {
            &Ecomm::PrintMessage(0,14+$Post{arf},144,1,1,sprintf("&ExportGrib2: There was an error with file export"));
            next;
        }
        $nn--;
    }

    my $date = gmtime();
    my $str  = $nn ? ($nn == $nt) ? 'was science fiction' : 'worked better on Star Trek' : 'was just another triumph for science';
    &Ecomm::PrintMessage(0,12+$Post{arf},144,1,2,sprintf("Teleportation $str on %s",$date));


return 0;
}


