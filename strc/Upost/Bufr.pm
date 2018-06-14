#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Bufr.pm
#
#  DESCRIPTION:  Bufr contains the routines used when processing the simulation
#                output into BUFR and secondary format files.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Bufr;

use warnings;
use strict;
require 5.008;
use English;

use vars qw ($mesg);


sub Process2Bufr {
# =================================================================================
#  The &Process2Bufr routine is the driver for the processing and managing the 
#  creation of BUFR sounding files via the UEMS version of the NCEP BUFR generation
#  machine, or whatever it's called.
# =================================================================================
#
    my $g2ref = shift; my %Post = %{$g2ref};

    return %Post unless $Post{proc} and %{$Post{bufr}};

    #----------------------------------------------------------------------------------
    #  Process the netCDF files into BUFR format
    #----------------------------------------------------------------------------------
    #
    @{$Post{bufr}{allfiles}}   = &Netcdf2Bufr(\%Post);
    @{$Post{bufr}{newfiles}}   = @{$Post{bufr}{allfiles}};
    &ExportBtype('bufr',\%Post); #  Hey, I'm in the import/export business!


    #----------------------------------------------------------------------------------
    #  Process BUFR into GEMPAK sounding files
    #----------------------------------------------------------------------------------
    #
    @{$Post{gemsnd}{allfiles}}  = &Bufr2Gemsnd(\%Post);
    @{$Post{gemsnd}{newfiles}}  = @{$Post{gemsnd}{allfiles}};
    &ExportBtype('gemsnd',\%Post);


    #----------------------------------------------------------------------------------
    #  Process GEMPAK sounding into ASCII sounding files.
    #----------------------------------------------------------------------------------
    #
    @{$Post{ascisnd}{allfiles}} = &Bufr2Ascisnd(\%Post);
    @{$Post{ascisnd}{newfiles}} = @{$Post{ascisnd}{allfiles}};
    &ExportBtype('ascisnd',\%Post);


return %Post;
}


sub Netcdf2Bufr {
# =================================================================================
#  This routine uses the UEMS version of the NCEP BUFR file processor to create
#  BUFR sounding files from simulation netCDF files.
#
#  Lots of stuff going on here so pay close attention.
# =================================================================================
#
use File::Spec;

    my $MAX_BUFR_STATIONS = 501;  # The maximum number of stations that can be processed
                                  # This value may be increased up to 1500 but don't
                                  # go any further.

    my $MAX_BUFR_TIMES    = 601;  # The maximum output times that can be processed
                                  # Note that this limit is arbitrarily set by the UEMS
                                  # developer and may be increased; however, there may be 
                                  # limits defined within secondary programs used to view
                                  # these data.

    my @Deloops = (); #  The list of files to be deleted after each process loop
    my @Bufrs   = ();

    my $g2ref = shift; my %Post = %{$g2ref};

    return ()  unless $Post{proc} and  %{$Post{bufr}};


    #  Attend to some local configuration
    #
    my $dom      = sprintf '%02d', $Post{domain};
    my $bufrstns = "$ENV{EMS_BIN}/bufrstns";
    my $emsbufr  = "$ENV{EMS_BIN}/emsbufr";

    $ENV{BUFRID} =  lc $Post{bufr}{fname};


    #----------------------------------------------------------------------------------
    #  Alert the user if no files are available for processing
    #----------------------------------------------------------------------------------
    #
    unless (@{$Post{netcdf}{allfiles}}) {
        &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Creating BUFR soundings from domain %s primary files",$dom));
        &Ecomm::PrintMessage(0,12+$Post{arf},144,1,1,"I looked, but there are no domain $dom wrfout netCDF files to process right now");
        return ();
    }


    #----------------------------------------------------------------------------------
    #  Make sure any netCDF files available for processing actually need to be 
    #  processed as defined by the $Post{bufr}{freq} (FREQ:START:STOP) setting
    #----------------------------------------------------------------------------------
    #
    my @NetCDFs  = ();
    (my $mfreq = $Post{bufr}{freq}) =~ s/:\w*//g;
    unless (@NetCDFs = sort &Outils::FrequencySubset($Post{bufr}{freq},@{$Post{netcdf}{allfiles}})) {
        &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Creating BUFR soundings from domain %s primary files",$dom));
        &Ecomm::PrintMessage(0,12+$Post{arf},144,1,1,"Yay! I have nothing to do since the processing frequency ($mfreq minutes) has left me without any primary files!");
        return ();
    }


    #----------------------------------------------------------------------------------
    #  Prepare a message to the used about what is being done. Note that the 
    #  following currently does not work for monolithic netCDF files.
    #----------------------------------------------------------------------------------
    #
    my $sdate = &Others::DateString2Pretty(&Others::NetcdfVerifTime($NetCDFs[0])); $sdate =~ s/^\w{3}\s//g; $sdate =~ s/\s+/ /g; $sdate =~ s/:\d\d / /;
    my $edate = &Others::DateString2Pretty(&Others::NetcdfVerifTime($NetCDFs[-1]));$edate =~ s/^\w{3}\s//g; $edate =~ s/\s+/ /g; $edate =~ s/:\d\d / /;

    @NetCDFs == 1 ? &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Creating a BUFR soundings from a single measly domain %s primary file for $sdate",$dom))
                  : &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Creating BUFR soundings from domain %s primary files every %s minutes between $sdate & $edate",$dom,$mfreq));



    #----------------------------------------------------------------------------------
    #  Make sure there are no files or links left over from a previous process.
    #  This step is a bit tricky because while we want to delete any existing GEMPAK
    #  files for the current domain being processed (unless scour), we don't want
    #  to delete GEMPAK files previously created for another domain or file type. 
    #
    #  Housekeeping is simple with BUFR files since you have to start over each time.
    #----------------------------------------------------------------------------------
    #
    if (&Others::mkdir($Post{bufr}{dpost})) {&Ecomm::PrintMessage(6,12+$Post{arf},144,1,2,"Netcdf2Bufr: Failed to create $Post{bufr}{dpost} - Return"); return ();}

    #  Scour any files remaining in the directory from previous runs
    #
    foreach (&Others::FileMatch($Post{bufr}{dpost},'',1,0)) {&Others::rm("$Post{bufr}{dpost}/$_") unless /^emsbufr_/;}

    #  Scour any BUFR files for this domain that are about to be replaced, keeping any BUFR files from 
    #  previous runs with a different domain.
    #
    foreach (&Others::FileMatch($Post{bufr}{dpost},'',1,0)) {&Others::rm("$Post{bufr}{dpost}/$_") if /$ENV{BUFRID}/;}


    #----------------------------------------------------------------------------------
    #  Make sure the UEMS BUFR binaries exists and that my cheese is where I left it.
    #----------------------------------------------------------------------------------
    #
    foreach ($bufrstns, $emsbufr) {
        if (&Others::FileExists($_)) {
            &Ecomm::PrintMessage(6,12+$Post{arf},255,1,2,'Netcdf2Bufr: Who moved my Cheese!',"It appears that $_ is missing.  Go find it Inspector BUFR!");
            return ();
        }
    }


    #----------------------------------------------------------------------------------
    #  The total number of times to process is currently the same as the number of 
    #  netCDF files. This will need to be modified for monolithic files.
    #----------------------------------------------------------------------------------
    #
    if (@NetCDFs > $MAX_BUFR_TIMES) {  #  Too many BUFR times
        my $n = @NetCDFs;
        $mesg = "The number of output times to include in the BUFR file ($n) exceeds the maximum allowed by law ($MAX_BUFR_TIMES). ".
                "Remember who's the sheriff around these parts of the UEMS so don't test me, cause I'm likely to start quoting ".
                "Clint Eastwood.\n\nAnd it ain't gonna be no \"Bronco Billy\" prose either!";
        &Ecomm::PrintMessage(6,12+$Post{arf},92,1,2,"I Got a Message For You (That's BUFR humor):",$mesg);
        return ();
    }


    #----------------------------------------------------------------------------------
    #  Before attempting to create BUFR files make sure the necessary tables exit.
    #----------------------------------------------------------------------------------
    #
    unless (-s "$Post{bufr}{tables}/uems_bufrpack1.tbl" and -s "$Post{bufr}{tables}/uems_bufrpack2.tbl") {
        $mesg = "In order for this operation to work, you must figure out what happened to the required ".
                "BUFR packing tables:\n\n".

                "X04X$Post{bufr}{tables}/uems_bufrpack1.tbl\n".
                "And\n".
                "X04X$Post{bufr}{tables}/uems_bufrpack2.tbl\n\n".
       
                "Until then, there will be no BUFR love for you.";

        &Ecomm::PrintMessage(6,12+$Post{arf},92,1,2,"No BUFR For You:",$mesg);
        return ();
    }


    #----------------------------------------------------------------------------------
    #  This odyssey begins in the emsprd/bufr directory... and never ends!
    #----------------------------------------------------------------------------------
    #
    chdir $Post{bufr}{dpost};


    #==================================================================================
    #  Enough with the preliminaries - Start the BUFR party already!
    #==================================================================================
    #

    #----------------------------------------------------------------------------------
    #  Step I. Create the BUFR station list for your domain
    #   
    #  This routine extracts those stations from the BUFR station file that reside
    #  within the computational domain.
    #----------------------------------------------------------------------------------
    #
    unless (-s $Post{bufr}{stnlist}) {
        my $stnlist = &Others::popitlev($Post{bufr}{stnlist},2);
        $mesg = "In order for this operation to work, you must have a viable station table containing ".
                "the locations of each BUFR site you want to create. Unfortunately (for you), this table ".
                "appears to be missing:\n\n".
                "X04X$stnlist\n\n".
                "The simulated world is your oyster - Eat it!";
        &Ecomm::PrintMessage(6,12+$Post{arf},88,1,2,"No BUFR For You:",$mesg);
        return ();
    }


    my $stfile = File::Spec->abs2rel($Post{bufr}{stnlist});
    &Ecomm::PrintMessage(0,14+$Post{arf},144,2,2,sprintf("BUFR Station list to be used for domain $dom - static/%s",&Others::popit($stfile)));

    unless (symlink $stfile => 'fort.15') {
        &Ecomm::PrintMessage(6,12+$Post{arf},144,1,2,sprintf("Link creation to $stfile Failed (%s) - Return",$!));
        return (); 
    }
    push @Deloops, "$Post{bufr}{dpost}/fort.15";



    #----------------------------------------------------------------------------------
    #  Create a link to a netcdf file from the simulation. Any netCDF will do provided
    #  it is for the domain being processed.
    #----------------------------------------------------------------------------------
    #
    my $stnlog = File::Spec->abs2rel($Post{bufr}{stnslog});
    my $ptfile = File::Spec->abs2rel($NetCDFs[0]);
    my $ptloc  = &Others::popit($ptfile);

    unless (symlink $ptfile => $ptloc) {
        &Ecomm::PrintMessage(6,12+$Post{arf},144,1,2,sprintf("Link creation to wrfprd/$ptloc Failed (%s) - Return",$!));
        return ();
    }
    my @verfs  = &Others::NetcdfVerifTimes($ptloc);
    my $mono   = @verfs > 1 ? 1 : 0;
    my $ptdate = &Others::DateString2DateStringWRF($verfs[0]);

    push @Deloops, "$Post{bufr}{dpost}/$ptloc";



    #----------------------------------------------------------------------------------
    #  Write the input file, "bufrstns.in"
    #----------------------------------------------------------------------------------
    #
    my $infile = 'bufrstns.in';

    push @Deloops, "$Post{bufr}{dpost}/$infile";
    open (my $ifh, '>', "$Post{bufr}{dpost}/$infile");

    print $ifh "$ptloc\n",
               "$ptdate\n";
    close $ifh; $| = 1;



    #----------------------------------------------------------------------------------
    #  Set and run the command to extract the BUFR sites. The information is
    #  written to the 'fort.19' files, because that's way more exciting than
    #  actually giving it a name.  
    #----------------------------------------------------------------------------------
    #
    &Ecomm::PrintMessage(0,14+$Post{arf},255,1,0,"Step 1. Create a list of stations that reside within domain $dom "); 

    if (my $err = &Ecore::SysExecute("$bufrstns < $infile",$Post{bufr}{stnslog})) {

        #  If the user passed a Control-C (^C) then simply clean up the mess
        #  that was made and exit
        # 
        &Outils::ProcessInterrupt('bufrstns',2,$Post{bufr}{dpost},\@Deloops,['fort.19']) if $err == 2;
        &Ecomm::PrintMessage(0,1,144,0,2,"- Failed (No BUFR Love for You)");

        if (-s $Post{bufr}{stnslog} and open my $bfh, '<', $Post{bufr}{stnslog}) {
            my @lines = <$bfh>; close $bfh; foreach (@lines) {chomp $_; s/^\s+//g;}
            &Outils::ErrorHelper($Post{bufr}{stnslog},$Post{arf},$err,@lines);
        }
        return ();
    }

    #----------------------------------------------------------------------------------
    #  Make sure the 'fort.19' file exists - Because that's our baby
    #----------------------------------------------------------------------------------
    # 
    unless (-s 'fort.19') {
        &Ecomm::PrintMessage(0,1,32,0,1,'- You have a problem');
        $mesg = "There are no BUFR stations located within your computational domain. Make sure that your master station ".
                "list is formatted correctly and that it contains stations that reside within your domain.\n\n".
                "Don't worry, I understand it can happen to anyone - Except me.";
        &Ecomm::PrintMessage(6,14+$Post{arf},88,2,2,$mesg);
        &Others::rm(@Deloops);
        return ();
    }
    &Ecomm::PrintMessage(0,1,1,0,2,"\xe2\x9c\x93");


    #----------------------------------------------------------------------------------
    #  Now show the user what he/she's won! HINT - It's detailed in the log file.
    #----------------------------------------------------------------------------------
    #
    my $nstns = 0;
    my @lines = ();
    if (-s $Post{bufr}{stnslog} and open my $bfh, '<', $Post{bufr}{stnslog}) {
        while (<$bfh>) {chomp $_; s/^\s+//g; next unless $_; push @lines, $_ if $nstns; $nstns = $1 if /PROFILE STATIONS\s*:\s*(\d+)/;} close $bfh;
    } 

    if ($nstns) {
        &Ecomm::PrintMessage(0,16+$Post{arf},144,1,1,"There are $nstns BUFR stations within domain ${dom}:");
        &Ecomm::PrintMessage(0,16+$Post{arf},144,1,0,'  NUM       STNM        LAT       LON      STID');
        &Ecomm::PrintMessage(0,16+$Post{arf},144,1,1,'-' x 54);

        my $nn = 1;
        foreach (sort { ($a =~ /^(\d+)/)[0] <=> ($b =~ /^(\d+)/)[0] } @lines) {  #  Numerically sort strings using station number
            my @stn = split / +/ => $_;
            &Ecomm::PrintMessage(0,16+$Post{arf},144,0,1,sprintf(" %4d      %06d    %7.2f   %7.2f     %-4s",$nn++,$stn[0],$stn[1],$stn[2],$stn[7]));
        }
        &Ecomm::PrintMessage(0,16+$Post{arf},144,0,1,'-' x 54);


        #----------------------------------------------------------------------------------
        #  Place the "Too many stations" error message after the list to allow the user
        #  to see all the stations. Because seeing is believing - usually.
        #----------------------------------------------------------------------------------
        #
        if ($nstns > $MAX_BUFR_STATIONS) {
            $mesg = "The number of stations requested ($nstns) exceeds the maximum allowed ($MAX_BUFR_STATIONS), which ".
                    "was arbitrarily set for your safety and the developer's senility.\n\n".
                    "You need to \"thin the herd\" before continuing.\n\n".
                    "BTW - You DO have wonderful eyes!";
            &Ecomm::PrintMessage(6,14+$Post{arf},88,2,1,"Your eyes are bigger than your stomach",$mesg);
            return ();
        }
    }
    &Others::rm(@Deloops);

   
    #----------------------------------------------------------------------------------
    #  Step II.
    #   
    #  Run the emsbufr routine to extract the profiles from the WRF forecast files.
    #  Data will be place in a temporary file that will be packed into BUFR files
    #  during the next step.
    #----------------------------------------------------------------------------------
    #
    @Deloops = ('emsbufr.in','fort.79','fort.76','fort.32','fort.19');  #  Clean house before continuing

    my $phr    = $mfreq%60  ? 'ZZ'   : (int($mfreq/60) > 99) ? 'ZZ' : sprintf("%02d",int($mfreq/60));
    my $fty    = $mono      ? 'mono' : 'indiv';
    my $sfreq  = $mfreq*60;  #  Set frequency to seconds


    #----------------------------------------------------------------------------------
    #  Prepare the BUFR packing table for some hot BUFR action, which includes 
    #  defining the precipitation accumulation period (bucket dump) within the 
    #  variable IDs, E.g., R01M, F01M, etc.
    #----------------------------------------------------------------------------------
    #
    open my $ofh, '>', "$Post{bufr}{dpost}/fort.32";
    open $ifh, '<', "$Post{bufr}{tables}/uems_bufrpack1.tbl";
    while (<$ifh>) {chomp $_; s/ZZ/$phr/g; print $ofh "$_\n";} close $ofh; close $ifh;

    
    #----------------------------------------------------------------------------------
    #  Write the input file to emsbufr and create the links to the files. Note that
    #  unlike the UEMS UPP, UEMS BUFR will loop through the available netCDF files 
    #  until the next file (filetime+$sfreq) is not found.
    #----------------------------------------------------------------------------------
    #
    open $ifh, '>', 'emsbufr.in';

    print $ifh   "$ptloc\n",
                 "ncar\n",
                 "$fty\n",
                 "$ptdate\n",
                 "$sfreq\n",
                 "$Post{bufr}{bfinfo}\n";
    close $ifh; $| = 1;


    #----------------------------------------------------------------------------------
    #  Now create links to all the netCDF files in the wrfprd directory
    #----------------------------------------------------------------------------------
    #
    foreach (@NetCDFs) {
        my $ptfile = File::Spec->abs2rel($_);
        my $ptloc  = &Others::popit($ptfile);

        unless (symlink $ptfile => $ptloc) {
            &Ecomm::PrintMessage(6,12+$Post{arf},144,1,2,sprintf("Link creation to wrfprd/$ptloc Failed (%s) - Return",$!));
            return ();
        }
        push @Deloops, "$Post{bufr}{dpost}/$ptloc";
    }


    #----------------------------------------------------------------------------------
    #  Set and run the command to create the BUFR files.  The 'BUFRID' envirinment 
    #  variable must be set with the BUFR file name string since the UEMS BUFR 
    #  routine uses it when creating the files. Yes, it is rather strange but it
    #  works so why mess with it.
    #----------------------------------------------------------------------------------
    #
    &Ecomm::PrintMessage(0,14+$Post{arf},255,2,0,"Step 2. Extract the domain $dom profiles and pack into BUFR files - Extract\'n & Pack\'n");

    if (my $err = &Ecore::SysExecute("$emsbufr < emsbufr.in",$Post{bufr}{bufrlog})) {
        #  If the user passed a Control-C (^C) then simply clean up the mess
        #  that was made and exit
        # 
        &Outils::ProcessInterrupt('emsbufr',2,$Post{bufr}{dpost},\@Deloops) if $err == 2;
        &Ecomm::PrintMessage(0,1,144,0,2,"- Failed (No BUFR Love for You)");

        if (-s $Post{bufr}{bufrlog} and open my $bfh, '<', $Post{bufr}{bufrlog}) {
            my @lines = <$bfh>; close $bfh; foreach (@lines) {chomp $_; s/^\s+//g;}
            &Outils::ErrorHelper($Post{bufr}{bufrlog},$Post{arf},$err,@lines);
        }
        return ();
    }
    &Others::rm(@Deloops);


    #----------------------------------------------------------------------------------
    #  BUFR creation accomplished! I hope
    #----------------------------------------------------------------------------------
    #
    @Bufrs = &Others::FileMatch($Post{bufr}{dpost},$ENV{BUFRID},0,0);
    
    @Bufrs ? &Ecomm::PrintMessage(0,1,24,0,1,"\xe2\x98\x94 (Raining BUFRs!)") 
           : &Ecomm::PrintMessage(0,1,255,0,2,"\xe2\x98\xa0 Something broke - Check $Post{bufr}{bufrlog}");


    #----------------------------------------------------------------------------------
    #  Print information about the precipitation fields to be included
    #----------------------------------------------------------------------------------
    #
    &Ecomm::PrintMessage(0,16+$Post{arf},255,2,1,'A summary of what you will find within each BUFR file:') if @Bufrs;
    &Ecomm::PrintMessage(0,16+$Post{arf},255,1,1,&PfieldsInfo($mfreq)) if @Bufrs;

    my $date = gmtime();
    &Ecomm::PrintMessage(0,12+$Post{arf},144,1,2,sprintf("Creation of domain $dom BUFR files %s at %s UTC",@Bufrs ? 'completed' : 'failed',$date));


return @Bufrs;
}



sub Bufr2Gemsnd {
# =================================================================================
#  This routine creates gempak sounding files from the freshly minted BUFR 
#  files. It returns a reference to a list of GEMPAK and ascii sounding files.
# =================================================================================
#
use File::Spec;

    my $MAX_GEM_STATIONS = 30000; # The maximum number of stations that can be handled
                                  # by GEMPAK as defined in the GEMPRM.PRM file
                                   

    my $MAX_GEM_TIMES    = 300;   # The maximum output times that can be handled
                                  # by GEMPAK as defined in the GEMPRM.PRM file


    my @Deloops = (); #  The list of files to be deleted after each process loop
    my @Gemsnd  = ();

    my $g2ref = shift; my %Post = %{$g2ref};

    return ()  unless $Post{proc} and %{$Post{gemsnd}} and @{$Post{bufr}{allfiles}};


    #----------------------------------------------------------------------------------
    #  Prepare a message to the used about what is being done. Note that the 
    #  following currently does not work for monolithic netCDF files
    #----------------------------------------------------------------------------------
    #
    my $dom    = sprintf '%02d', $Post{domain};
    my $dt    = %{$Post{ascisnd}} ? 'GEMPAK and text file soundings' : 'GEMPAK soundings';
    my @Bufrs = @{$Post{bufr}{allfiles}};
    my $n     = @Bufrs;

    @Bufrs == 1 ? &Ecomm::PrintMessage(1,9+$Post{arf},255,1,1,sprintf ("Creating a %s from a very lonely domain %s BUFR file",$dt,$dom))
                : &Ecomm::PrintMessage(1,9+$Post{arf},255,1,1,sprintf ("Creating $n %s from domain %s BUFR files",$dt,$dom));


    #----------------------------------------------------------------------------------
    #  Make sure there are no files or links left over from a previous process.
    #  This step is a bit tricky because while we want to delete any existing GEMPAK
    #  files for the current domain being processed (unless scour), we don't want
    #  to delete GEMPAK files previously created for another domain or file type. 
    #
    #  Housekeeping is simple with BUFR files since you have to start over each time.
    #----------------------------------------------------------------------------------
    #
    if (&Others::mkdir($Post{gemsnd}{dpost})) {&Ecomm::PrintMessage(6,12+$Post{arf},144,1,2,"Netcdf2Bufr: Failed to create $Post{gemsnd}{dpost} - Return"); return ();}



    #----------------------------------------------------------------------------------
    #  Make sure the EMS UPP binary exists and that my cheese is where I left it.
    #----------------------------------------------------------------------------------
    #
    my $namsnd = "$Post{gemsnd}{nawips}/os/linux/bin/namsnd";
    if (&Others::FileExists($namsnd)) {
        &Ecomm::PrintMessage(6,12+$Post{arf},255,1,2,'Bufr2Gemsnd: Who moved my Cheese!',"It appears that $namsnd is missing.\n\nGo find it Inspector NAMSND!");
        return ();
    }



    #----------------------------------------------------------------------------------
    #  Since the ASCII sounding files are created at the same time as the GEMPAK 
    #  sounding files, the directory needs to created as well.
    #----------------------------------------------------------------------------------
    #
    if (%{$Post{ascisnd}} and &Others::mkdir($Post{ascisnd}{dpost})) { 
        &Ecomm::PrintMessage(6,12+$Post{arf},144,1,2,"Bufr2Gemsnd: Failed to create $Post{ascisnd}{dpost}\n\nNo ASCII sounding files will be made.");
        %{$Post{ascisnd}} = ();
    }



    #----------------------------------------------------------------------------------
    #  Collect the active station numbers and IDs into a hash that will be used
    #----------------------------------------------------------------------------------
    #
    my %Stations    = ();
    $Stations{$_} = $Post{bufr}{stations}{$_} foreach map {/\.(\d{6})\./} @{$Post{bufr}{allfiles}};



    #----------------------------------------------------------------------------------
    #  This odyssey begins in the emsprd/gemsnd directory... and never ends!
    #----------------------------------------------------------------------------------
    #
    chdir $Post{gemsnd}{dpost};


    #----------------------------------------------------------------------------------
    #  Ideally, the user will have uncommented the NAWIPS environment variable 
    #  in the startup files but just to make sure that the proper tables are 
    #  being used set the GEMPAK environment here.
    #----------------------------------------------------------------------------------
    #
    &Outils::SetNawipsEnvironment($Post{gemsnd}{nawips});


    #----------------------------------------------------------------------------------
    #  Create the filename to be used from the BUFR filename, which currently set
    #  to be YYYYMMDDCC_gemsnd_CORE_dWD.[snd|sfc]
    #----------------------------------------------------------------------------------
    #
    my $gemfil = '';
    my $gemstr = '';

    if ($Bufrs[0] =~ /(\w+)\.\d{6}\.(\d+)/) { my $ydm = $2;
        ($gemstr = $Post{gemsnd}{fname}) =~ s/YYYYMMDDCC//i;
        ($gemfil = $Post{gemsnd}{fname}) =~ s/YYYYMMDDCC/$ydm/i;

        $Post{ascisnd}{fname} =~ s/YYYYMMDDCC/$ydm/i if %{$Post{ascisnd}};
    }
    my $gemsfc = "${gemfil}.sfc";
    my $gemsnd = "${gemfil}.snd";
    my $gemaux = "${gemfil}.sfc_aux";


    #----------------------------------------------------------------------------------
    #  Scour any files remaining in the directory from previous runs. This will 
    #  require two sweeps of the directory. The first sweep deletes all files 
    #  that do not include 'gemsnd_' in the filename. The second deletes all
    #  GEMSND files associated with current domain & data type.
    #----------------------------------------------------------------------------------
    #
    foreach (&Others::FileMatch($Post{gemsnd}{dpost},'',1,0)) {&Others::rm("$Post{gemsnd}{dpost}/$_") unless /'gemsnd_'/;}
    foreach ($gemsfc, $gemsnd, $gemaux) {&Others::rm("$Post{gemsnd}{dpost}/$_");}



    #----------------------------------------------------------------------------------
    #  The BUFR packing tables in the UEMS are dynamic in that the precipitation
    #  accumulation period must be inserted into the file prior to run-time to
    #  reflect the value in the BUFR files. The precipitation period is the same
    #  as the bufr processing freqency used in the previous subroutine.
    #----------------------------------------------------------------------------------
    #
    (my $mfreq = $Post{bufr}{freq}) =~ s/:\w*//g;
    my $phr = $mfreq%60 ? 'ZZ' : (int($mfreq/60) > 99) ? 'ZZ' : sprintf("%02d",int($mfreq/60));

    foreach my $prm ('sfuems.prm','sfuems.prm_aux','snuems.prm') {
        unless (-s "$Post{bufr}{tables}/$prm") {
            &Ecomm::PrintMessage(6,12+$Post{arf},144,1,2,"Bufr2Gemsnd: GEMPAK sounding parameter table is missing: $Post{bufr}{tables}/$prm.");
            return ();
        }
        open my $ofh, '>', "$Post{gemsnd}{dpost}/$prm";
        open my $ifh, '<', "$Post{bufr}{tables}/$prm";
        while (<$ifh>) {chomp $_; s/ZZ/$phr/g; print $ofh "$_\n";} close $ofh; close $ifh;
        push @Deloops, "$Post{gemsnd}{dpost}/$prm";
    }


    #----------------------------------------------------------------------------------
    # More user information
    #----------------------------------------------------------------------------------
    #
    &Ecomm::PrintMessage(0,14+$Post{arf},96,1,1,"Sounding File   : $gemsnd");
    &Ecomm::PrintMessage(0,14+$Post{arf},96,0,1,"Surface  File   : $gemsfc");
    &Ecomm::PrintMessage(0,14+$Post{arf},96,0,1,"Aux Surface File: $gemsfc\_aux");



    #----------------------------------------------------------------------------------
    #  Loop over the list of BUFR files, writing each to the same GEMPAK surface &
    #  sounding files.
    #----------------------------------------------------------------------------------
    #
    my $nt     = $MAX_GEM_TIMES;
    my $ns     = keys %Stations;

    push @Deloops, "$Post{gemsnd}{dpost}/namsnd.in";
    push @Deloops, "$Post{gemsnd}{dpost}/gemglb.nts";
    push @Deloops, "$Post{gemsnd}{dpost}/last.nts";


    foreach my $bufr (@Bufrs) {

        my $stnm   = 0;
        my $stid   = 0;

        my $lprof  = '';
        my $rprof  = '';
 
        my $ptfile = File::Spec->abs2rel($bufr);
        my $ptloc  = &Others::popit($ptfile);
        my $snbufr = $ptloc;

        unless (symlink $ptfile => $ptloc) {
            &Ecomm::PrintMessage(6,12+$Post{arf},144,1,2,sprintf("Link creation to emsprd/bufr/$ptloc Failed (%s) - Return",$!));
            return ();
        }


        #----------------------------------------------------------------------------------
        #  If the ASCISND file option is turned ON then the namsnd parameter "SNBUFR" 
        #  includes an appended "|$stid=$stnm" 
        #----------------------------------------------------------------------------------
        #
        if (%{$Post{ascisnd}} and $snbufr =~ /\w+\.(\d{6})\.(\d+)/) {
            $stnm   = $1;
            $stid   = lc $Stations{$stnm}; $stid = substr $stid,1,3  if length $stid  == 4;  #  Must be 3 characters
            $stnm   +=0;
            $snbufr = "$snbufr|$stid=$stnm";

            $lprof  = "prof.$stid";
            $rprof  = $Post{ascisnd}{fname};
            $rprof  =~ s/STID/$stid/g;
            $rprof  =~ s/STNM/$stnm/g;
            $rprof  = "$Post{ascisnd}{dpost}/$rprof";

            &Others::rm($rprof);
        }
               
        
        #----------------------------------------------------------------------------------
        #  Write the input file to namsnd and create the gempak sounding file, which is 
        #  required for any processing beyond the creation of BUFR files.
        #----------------------------------------------------------------------------------
        #
        open my $ifh, '>', 'namsnd.in';

        print $ifh "SNOUTF = $gemsnd\n".
                   "SFOUTF = $gemsfc+\n".
                   "SNBUFR = $snbufr\n".
                   "SNPRMF = ./snuems.prm\n".
                   "SFPRMF = ./sfuems.prm\n".
                   "TIMSTN = $nt\/$ns\n\n".
                   "    \n".
                   "list\n".
                   "run \n".
                   "    \n".
                   "exit\n";

        close $ifh; $| = 1;


        #----------------------------------------------------------------------------------
        #  Set up and run the "namsnd" routine, which extracts the data from the BUFR
        #  file and writes it fo the GEMPAK sounding & surface files.
        #----------------------------------------------------------------------------------
        #
        if (my $err = &Ecore::SysExecute("$namsnd < namsnd.in",$Post{gemsnd}{logfile})) {

            #  If the user passed a Control-C (^C) then simply clean up the mess
            #  that was made and exit
            # 
            &Outils::ProcessInterrupt('namsnd',2,$Post{gemsnd}{dpost},\@Deloops,[$ptloc]) if $err == 2;
            &Ecomm::PrintMessage(6,12+$Post{arf},144,2,1,"GEMPAK sounding file creation (1) - Failed (No GEMSND Love for You)");

            if (-s $Post{gemsnd}{logfile} and open my $bfh, '<', $Post{gemsnd}{logfile}) {
                my @lines = <$bfh>; close $bfh; foreach (@lines) {chomp $_; s/^\s+//g;}
                &Outils::ErrorHelper($Post{gemsnd}{logfile},$Post{arf},$err,@lines);
            }  
            &Others::rm(@Deloops,$ptloc);
            return ();
        }
        system "mv -f $lprof $rprof > /dev/null 2>&1" if $lprof;  #  Move the asci file to the final directory

        &Others::rm("$Post{gemsnd}{dpost}/$ptloc");
    }
    &Others::rm(@Deloops);


    #----------------------------------------------------------------------------------
    #  GEMPAK sounding file creation accomplished! I hope
    #----------------------------------------------------------------------------------
    #
    @Gemsnd = &Others::FileMatch($Post{gemsnd}{dpost},$gemstr,0,0);

    &Others::rm($Post{gemsnd}{logfile}) if @Gemsnd;

    my $date = gmtime();
    &Ecomm::PrintMessage(0,12+$Post{arf},144,1,2,sprintf("Creation of domain $dom $dt files %s at %s UTC",@Gemsnd ? 'completed' : "failed \xe2\x98\x9c",$date));


return @Gemsnd;
}



sub Bufr2Ascisnd {
# =================================================================================
#  The ASCII text sounding files were created in the Bufr2Gemsnd routine but 
#  they need to be corralled into the @Ascii array;
# =================================================================================
#
use List::Util 'first';

    my $g2ref = shift; my %Post = %{$g2ref};

    return () unless $Post{proc} and %{$Post{ascisnd}} and @{$Post{gemsnd}{allfiles}};


    #----------------------------------------------------------------------------------
    #  Use the GEMPAK sounding file, *.snd, as the key string for the text files
    #----------------------------------------------------------------------------------
    #
    my $gensnd = first {/\.snd/} @{$Post{gemsnd}{allfiles}};
    (my $askey  = &Others::popit($gensnd)) =~ s/\.snd//g;  #  Get it?  
    $askey  =~ s/gemsnd/ascisnd/g;


    #----------------------------------------------------------------------------------
    #  Collect the matching files and go home
    #----------------------------------------------------------------------------------
    #
    my @Ascii = &Others::FileMatch($Post{ascisnd}{dpost},$askey,0,0);


return @Ascii;
}


sub PfieldsInfo {
# =================================================================================
#  This subroutine populates the precipitation information initialized by the 
#  &InitializePfields subroutine and then returns a multi-line string to be 
#  printed out by the calling program.
# =================================================================================
#    
    my @lines = ();
	my $info  = '';

    my $tmin = shift; return $info unless $tmin;

    my $phr  = $tmin%60 ? 'ZZ' : (int($tmin/60) > 99) ? 'ZZ' : sprintf("%02d",int($tmin/60));
    my $ph   = int ($tmin/60);
    my $tp   = $tmin%60 ? "$tmin tminute" : "$ph hour";
  
    my %Pfields = &InitializePfields();

    push @lines,"Precipitation fields in BUFR, GEMPAK, and BUFKIT sounding files (mm;liquid equivalent)\n";
    push @lines,"----------------------------------------------------------------------------------------\n";
    push @lines,"\n";

    foreach my $field ('PXXM', 'CXXM', 'SXXM', 'AXXM', 'RXXM', 'FXXM', 'IXXM', 'GXXM', 'HXXM', 'WXXM', 'NXXM') {
        push @lines, "  $field - $Pfields{$field}\n";
    }
    push @lines,"\n";


    foreach my $field ('PZZM', 'CZZM', 'SZZM', 'RZZM', 'FZZM', 'IZZM', 'GZZM', 'HZZM', 'WZZM', 'NZZM', 'SZZR', 'GZZR') {
        push @lines, "  $field - $Pfields{$field}\n";
    }
    push @lines,"\n\n";

    push @lines,"Precipitation rate fields in BUFR, GEMPAK, and BUFKIT sounding files (mm/hr;liquid equivalent)\n";
    push @lines,"------------------------------------------------------------------------------------------------\n\n";
    foreach my $field ('ITPR', 'IRPR', 'IZPR', 'ISPR', 'IGPR', 'IHPR') {
        push @lines, "  $field - $Pfields{$field}\n";
    }
    push @lines,"\n";


    foreach my $field ('MTPR', 'MRPR', 'MZPR', 'MSPR', 'MGPR', 'MHPR') {
        push @lines, "  $field - $Pfields{$field}\n";
    }

    $info = join '', @lines;
    $info =~ s/QQQ/$tp/g;
    $info =~ s/ZZ/$phr/g;

    
return $info;
}



sub InitializePfields {
# =================================================================================
#  Subroutine to initialize the precipitation fields hash (%Pfields) used
#  by &Netcdf2Bufr.  The %Pfields will be used to provide information to the 
#  user regarding the various pricip types.
#
#  Only here to keep &Netcdf2Bufr semi-tidy.
# =================================================================================
#
    my %Pfields=();
       $Pfields{PXXM} = 'Simulation Accumulated Total Precipitation';
       $Pfields{CXXM} = 'Simulation Accumulated Convective Precipitation';
       $Pfields{SXXM} = 'Simulation Accumulated Non-Convective Precipitation';
       $Pfields{AXXM} = 'Simulation Accumulated Shallow-Convective Precipitation';

       $Pfields{RXXM} = 'Simulation Accumulated Rainfall';
       $Pfields{FXXM} = 'Simulation Accumulated Freezing Rainfall';
       $Pfields{IXXM} = 'Simulation Accumulated Snow & Ice';
       $Pfields{GXXM} = 'Simulation Accumulated Graupel';
       $Pfields{HXXM} = 'Simulation Accumulated Hail';
       $Pfields{WXXM} = 'Simulation Accumulated Snow & Graupel';
       $Pfields{NXXM} = 'Simulation Accumulated Melted Frozen Stuff';

       $Pfields{PZZM} = 'Period (QQQ) Accumulated Total Precipitation';
       $Pfields{CZZM} = 'Period (QQQ) Accumulated Convective Precipitation';
       $Pfields{SZZM} = 'Period (QQQ) Accumulated Non-Convective Precipitation';
       #$Pfields{AZZM} = 'Period (QQQ) Accumulated Shallow-Convective Precipitation';

       $Pfields{RZZM} = 'Period (QQQ) Accumulated Rainfall';
       $Pfields{FZZM} = 'Period (QQQ) Accumulated Freezing Rainfall';
       $Pfields{IZZM} = 'Period (QQQ) Accumulated Snow & Ice';
       $Pfields{GZZM} = 'Period (QQQ) Accumulated Graupel';
       $Pfields{HZZM} = 'Period (QQQ) Accumulated Hail';
       $Pfields{WZZM} = 'Period (QQQ) Accumulated Snow & Graupel';
       $Pfields{NZZM} = 'Period (QQQ) Accumulated Melted Frozen Stuff';

       $Pfields{SZZR} = 'Period (QQQ) Accumulated Surface Water Run-off';
       $Pfields{GZZR} = 'Period (QQQ) Accumulated Ground Water Run-off';


       $Pfields{ITPR} = 'Instantaneous Total Precipitation Rate';
       $Pfields{IRPR} = 'Instantaneous Rainfall Precipitation Rate';
       $Pfields{IZPR} = 'Instantaneous Freezing Rain Precipitation Rate';
       $Pfields{ISPR} = 'Instantaneous Snow (Snow + Graupel) Precipitation Rate';
       $Pfields{IGPR} = 'Instantaneous Graupel Precipitation Rate';
       $Pfields{IHPR} = 'Instantaneous Hail Precipitation Rate';

       $Pfields{MTPR} = 'Period (QQQ) Maximum Total Precipitation Rate';
       $Pfields{MRPR} = 'Period (QQQ) Maximum Rainfall Precipitation Rate';
       $Pfields{MZPR} = 'Period (QQQ) Maximum Freezing Rain Precipitation Rate';
       $Pfields{MSPR} = 'Period (QQQ) Maximum Snow (Snow + Graupel) Precipitation Rate';
       $Pfields{MGPR} = 'Period (QQQ) Maximum Graupel Precipitation Rate';
       $Pfields{MHPR} = 'Period (QQQ) Maximum Hail Precipitation Rate';

return %Pfields;
}


sub ExportBtype {
# =================================================================================
#  This routine uses the exports any Bufr or secondary files to other 
#  locations per the user's request.
# =================================================================================
#
    my ($btype, $pref) = @_; my %Post = %{$pref};

    return 0 unless $Post{$btype}{export} and %{$Post{$btype}{export}}; #  Data type not processed
    return 0 unless @{$Post{$btype}{newfiles}};  #  No files to export


    #  Attend to some local configuration
    #
    my $dom  = sprintf '%02d', $Post{domain};
    my @phs  = (@{$Post{placeholders}},"DSET:$btype");
    my $ucb  = uc $btype;
    
    &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Teleporting Domain %s $ucb files to wonderful and exotic locations",$dom));

    #----------------------------------------------------------------------------------
    #  Loop over each of the export requests (there may be more than one)
    #----------------------------------------------------------------------------------
    #
    my $nt = keys %{$Post{$btype}{export}};  my $nn = $nt;

    foreach my $exp (sort {$a <=> $b}  keys %{$Post{$btype}{export}}) {

        @{$Post{$btype}{export}{$exp}{files}} = sort @{$Post{$btype}{newfiles}};

        $Post{$btype}{export}{$exp}{rdir} = &Others::PlaceholderFillDate($Post{$btype}{export}{$exp}{rdir},$Post{yyyymmddcc},@phs);

        if (&Outils::ExportFiles(\%{$Post{$btype}{export}{$exp}}) ) {
            &Ecomm::PrintMessage(0,14+$Post{arf},144,1,1,sprintf("ExportBtype: There was an error with $btype export"));
            next;
        }
        $nn--;
    }

    my $date = gmtime();
    my $str  = $nn ? ($nn == $nt) ? 'was science fiction' : 'worked better on Star Trek' : 'was just another triumph for science';
    &Ecomm::PrintMessage(0,12+$Post{arf},144,1,2,sprintf("This teleportation experiment $str on %s",$date));


return 0;
}


