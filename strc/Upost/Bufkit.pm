#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Bufkit.pm
#
#  DESCRIPTION:  Bufkit contains the routines used when processing the simulation
#                output into Bufkit and secondary format files.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Bufkit;

use warnings;
use strict;
require 5.008;
use English;

use vars qw ($mesg);


sub Process2Bufkit {
# =================================================================================
#  The &Process2Bufkit routine takes the GEMPAK sounding and surface files created
#  from BUFR and produces BUFKIT formatted bundles of love and data.
# =================================================================================
#
    my $g2ref = shift; my %Post = %{$g2ref};


    #----------------------------------------------------------------------------------
    #  No reason to hang out if there's nothing with which to work
    #----------------------------------------------------------------------------------
    #
    return %Post unless $Post{proc} and %{$Post{bufkit}} and %{$Post{gemsnd}} and @{$Post{gemsnd}{allfiles}};


    #----------------------------------------------------------------------------------
    #  Process the GEMPAK sounding files into BUFKIT
    #----------------------------------------------------------------------------------
    #
    @{$Post{bufkit}{allfiles}}  = &Gemsnd2Bufkit(\%Post);
    @{$Post{bufkit}{newfiles}}  = @{$Post{bufkit}{allfiles}};


    #----------------------------------------------------------------------------------
    #  Move them to the needy
    #----------------------------------------------------------------------------------
    #
    &ExportBufkit('bufkit',\%Post);


return %Post;
}


sub Gemsnd2Bufkit {
# =================================================================================
#  This routine uses the UEMS version of the NCEP BUFR file processor to create
#  BUFR sounding files from simulation netCDF files.
#
#  Lots of stuff going on here so pay close attention.
# =================================================================================
#
use File::Spec;

    my $MAX_GEM_STATIONS = 30000; # The maximum number of stations that can be handled
                                  # by GEMPAK as defined in the GEMPRM.PRM file


    my $MAX_GEM_TIMES    = 300;   # The maximum output times that can be handled
                                  # by GEMPAK as defined in the GEMPRM.PRM file


    my $logfile = ''; #  Used a number of places
    my $infile  = '';

    my @Deloops = (); #  The list of files to be deleted after each process loop
    my @Bufkit  = ();

    my $g2ref   = shift; my %Post = %{$g2ref};


    #  Attend to some local configuration
    #
    my $dom     = sprintf '%02d', $Post{domain};


    #----------------------------------------------------------------------------------
    #  The following are the GEMPAK utilities to be used in this routine
    #----------------------------------------------------------------------------------
    #
    my $snlist  = "$Post{bufkit}{nawips}/os/linux/bin/snlist";
    my $sflist  = "$Post{bufkit}{nawips}/os/linux/bin/sflist";
    my $sfcfil  = "$Post{bufkit}{nawips}/os/linux/bin/sfcfil";
    my $sfedit  = "$Post{bufkit}{nawips}/os/linux/bin/sfedit";


    #----------------------------------------------------------------------------------
    #  Prepare a message to the used about what is being done. Note that the 
    #  following currently does not work for monolithic netCDF files
    #----------------------------------------------------------------------------------
    #
    my @Gemsnd  = @{$Post{gemsnd}{allfiles}};
    my @Bufrs   = @{$Post{bufr}{allfiles}};
    my $n       = @Bufrs;


    my $h = 'No BUKITs for you!';
       $h = 'You can do better than one!'    if $n == 1;
       $h = 'Make\'n it sprinkle BUFKITs'    if $n > 1;
       $h = 'Like it\'s rain\'n BUFKITs'     if $n > 10;
       $h = 'It\'s pouring down BUFKITs!'    if $n > 35;
       $h = 'It\'s a BUFKIT deluge!'         if $n > 66;
       $h = 'It\'s a $&%^@$! BUFKIT Sunami!' if $n > 120;


    @Bufrs == 1 ? &Ecomm::PrintMessage(1,9+$Post{arf},255,1,2,sprintf ("Creating a very lonely domain %s BUFKIT file \xe2\x98\x94 ($h)",$dom))
                : &Ecomm::PrintMessage(1,9+$Post{arf},255,1,2,sprintf ("Creating $n individual domain %s BUFKIT files \xe2\x98\x94 ($h)",$dom));


    #----------------------------------------------------------------------------------
    #  Make sure the EMS UPP binary exists and that my cheese is where I left it.
    #----------------------------------------------------------------------------------
    #
    foreach ($snlist, $sflist, $sfcfil, $sfedit) {
        if (&Others::FileExists($_)) {
            &Ecomm::PrintMessage(6,12+$Post{arf},144,0,1,'Gemsnd2Bufkit: Who moved my Cheese!',"It appears that $_ is missing.\n\nGo find it Inspector BUFKIT!");
            return ();
        }
    }


    #----------------------------------------------------------------------------------
    #  Make sure there are no files or links left over from a previous process.
    #  This step is a bit tricky because while we want to delete any existing GEMPAK
    #  files for the current domain being processed (unless scour), we don't want
    #  to delete GEMPAK files previously created for another domain or file type. 
    #
    #  Housekeeping is simple with BUFR files since you have to start over each time.
    #----------------------------------------------------------------------------------
    #
    if (&Others::mkdir($Post{bufkit}{dpost})) {&Ecomm::PrintMessage(6,12+$Post{arf},144,0,1,"Gemsnd2Bufkit: Failed to create $Post{bufkit}{dpost} - Return"); return ();}

    
    #----------------------------------------------------------------------------------
    #  Extract the key string that will be used when collecting the BUFKIT files at 
    #  the end of this routine and for scouring old files at the beginning. Because
    #  my work is never done.
    #----------------------------------------------------------------------------------
    #
    (my $bufkey = $Post{bufkit}{fname}) =~ s/^YYYYMMDDCC\.//g;  #  Don't know whether
        $bufkey =~ s/\w{3,4}\.\w*$//g;
    

    #  Scour any files remaining in the directory from previous runs
    #
    foreach (&Others::FileMatch($Post{bufkit}{dpost},'',1,0)) {&Others::rm("$Post{bufkit}{dpost}/$_") if /$bufkey|^work/;}
  

    
    #  Create the work directory. Any previous work directory should have been deleted 
    #  as part of the action above.
    #
    if (&Others::mkdir($Post{bufkit}{dwork})) {&Ecomm::PrintMessage(6,12+$Post{arf},144,0,1,"Gemsnd2Bufkit: Failed to create $Post{bufkit}{dwork} - Return"); return ();}


    #----------------------------------------------------------------------------------
    #  If the user requested compressed BUFKIT files check for the utility
    #----------------------------------------------------------------------------------
    #
    $Post{bufkit}{zipit} = 1 if $Post{bufkit}{fname} =~ s/\.buz$/\.buf/;

    my $zipit = $Post{bufkit}{zipit} ? &WhichZipIt() : 0;

    if ($Post{bufkit}{zipit} and !$zipit) {
        $mesg = "I am unable to find neither the \"zip\" nor \"gzip\" routine on your system, which are to compress ".
                "the BUFKIT files. Since these utilities are available with most Linux distributions, it is ".
                "likely they were left out during the OS install.\n\nThe BUFR files will remain in the standard ".
                "ASCII text format (*.buf) for now.";
        &Ecomm::PrintMessage(6,12+$Post{arf},88,0,3,"Your \"BUFR Buzz\" was tempered:",$mesg); 
    }

 

    #----------------------------------------------------------------------------------
    #  Collect the active station numbers and IDs into a hash that will be used
    #----------------------------------------------------------------------------------
    #
    my %Stations  = ();
    $Stations{$_} = lc $Post{bufr}{stations}{$_} foreach map {/\.(\d{6})\./} @Bufrs;

    my $nt = $MAX_GEM_TIMES;
    my $ns = keys %Stations;


    #----------------------------------------------------------------------------------
    #  We'll need the initialization date & time from the BUFR filename
    #----------------------------------------------------------------------------------
    #  
    my $yyyymmddcc = ($Bufrs[0] =~ /\.(\d{10})$/) ? $1 : 0;


    #----------------------------------------------------------------------------------
    #  Define the various GEMPAK sounding & surface files to be used in the 
    #  production of BUFKIT files.
    #----------------------------------------------------------------------------------
    #
    my ($gemsnd, $gemsfc, $gemsfcx) = ('') x 3;
    foreach (@{$Post{gemsnd}{allfiles}}) {
        $gemsnd  = $_ if /\.snd$/;
        $gemsfc  = $_ if /\.sfc$/;
        $gemsfcx = $_ if /\.sfc_aux$/;
    }


    #----------------------------------------------------------------------------------
    #  This odyssey begins in the emsprd/bufkit directory... and never ends!
    #----------------------------------------------------------------------------------
    #
    chdir $Post{bufkit}{dwork};


    #----------------------------------------------------------------------------------
    #  Ideally, the user will have uncommented the NAWIPS environment variable 
    #  in the startup files but just to make sure that the proper tables are 
    #  being used set the GEMPAK environment here.
    #----------------------------------------------------------------------------------
    #
    &Outils::SetNawipsEnvironment($Post{bufkit}{nawips});


    #----------------------------------------------------------------------------------
    #  Before attempting to create BUFR files make sure the necessary tables exit.
    #----------------------------------------------------------------------------------
    #
#   unless (-s "$Post{bufr}{tables}/uems_bufrpack1.tbl" and -s "$Post{bufr}{tables}/uems_bufrpack2.tbl") {
#       $mesg = "In order for this operation to work, you must figure out what happened to the required ".
#               "BUFR packing tables:\n\n".

#               "X04X$Post{bufr}{tables}/uems_bufrpack1.tbl\n".
#               "And\n".
#               "X04X$Post{bufr}{tables}/uems_bufrpack2.tbl\n\n".
#      
#               "Until then, there will be no BUFR love for you.";

#       &Ecomm::PrintMessage(6,14+$Post{arf},98,0,1,"No BUFRs For You:",$mesg);
#       return ();
#   }



    #==================================================================================
    #  Enough with the preliminaries - Start the BUFKIT party already!
    #==================================================================================
    #


    #----------------------------------------------------------------------------------
    #  STEP I. - Formulate parameter settings for snlist
    #
    #  The three necessary gempak files are in @{$Post{gemsnd}{allfiles}} 
    #  The BUFR stations from which BUFKIT files are made are in @{$Post{bufr}{allfiles}}
    #
    #  The stations extracted from the station list can not be used because some
    #  may lie outside the computational domain and thus no BUFR file exists.
    #----------------------------------------------------------------------------------
    #
    ($logfile  = $Post{bufkit}{logfile}) =~ s/ROUTINE/snlist/g;
    my $ptfile = File::Spec->abs2rel($gemsnd);
    my $ptloc  = &Others::popit($ptfile);

    unless (symlink $ptfile => $ptloc) {
        &Ecomm::PrintMessage(9,12+$Post{arf},144,0,2,sprintf("Step 1 (snlist): Link creation to gemsnd/$ptloc Failed (%s) - Return",$!));
        return ();
    }
    push @Deloops, "$Post{bufkit}{dwork}/$ptloc";
    push @Deloops, $logfile;



    #----------------------------------------------------------------------------------
    #  Prepare the input for running snlist, which requires looping
    #  through alll stations being processed.
    #----------------------------------------------------------------------------------
    #
    $infile = "st1_snlist.$$";
    push @Deloops, "$Post{bufkit}{dwork}/$infile";
    push @Deloops, "$Post{bufkit}{dwork}/gemglb.nts";
    push @Deloops, "$Post{bufkit}{dwork}/last.nts";
    push @Deloops, "$Post{bufkit}{dwork}/$ptloc";

    open my $ifh, '>', $infile;

    print $ifh "SNFILE = $ptloc\n",
               "LEVELS = ALL\n",
               "STNDEX = show;lift;swet;kinx;lclp;pwat;totl;cape;lclt;cins;eqlv;lfct;brch\n",
               "SNPARM = pres;tmpc;tmwc;dwpc;thte;drct;sknt;omeg;cfrl;hght\n",
               "DATTIM = ALL\n",
               "VCOORD = PRES\n",
               "MRGDAT = YES\n" ;


    foreach my $stnm (sort {$a <=> $b} keys %Stations) {
 
        print $ifh "AREA     =\@$stnm\n",
                   "OUTPUT   = f/snfile_${stnm}_snd.$$\n",
                   "list\n",
                   "run\n"  ,
                   " \n";
    }
    print $ifh "exit\n";  
    close $ifh; $| = 1;



    #----------------------------------------------------------------------------------
    #  Run the GEMPAK snlist routine to extract the individual station soundings from 
    #  the GEMPAK sounding file and write them to text files.
    #----------------------------------------------------------------------------------
    #
    if (my $err = &Ecore::SysExecute("$snlist < $infile",$logfile)) {

        #  If the user passed a Control-C (^C) then simply clean up the mess
        #  that was made and exit
        # 
        &Outils::ProcessInterrupt('snlist',2,$Post{bufkit}{dwork},\@Deloops,[$logfile]) if $err == 2;
        &Ecomm::PrintMessage(9,12+$Post{arf},144,0,2,"Bufkit station files (1) - Failed (No BUFKIT Love for You)");
      
        if (-s $logfile and open my $bfh, '<', $logfile) {
            my @lines = <$bfh>; close $bfh; foreach (@lines) {chomp $_; s/^\s+//g;}
            &Outils::ErrorHelper($logfile,$Post{arf},$err,@lines);
        }
        return ();
    }


    #----------------------------------------------------------------------------------
    #  Collect the newly created ASCII text files containing the individual soundings
    #----------------------------------------------------------------------------------
    #  Check whether @Snlists == $ns ?
    unless (&Others::FileMatch($Post{bufkit}{dwork},'snfile',1,0)) {
        &Ecomm::PrintMessage(9,12+$Post{arf},255,0,2,"\xe2\x98\xa0 Something broke - Check $logfile");
        return ();
    }
    &Others::rm(@Deloops);  @Deloops = ();



    # ================================================================================
    #  Step II.  Create an empty GEMPAK surface file using the bufkt_uems.pack table
    #            that will eventually be populated with data from the BUFR files.
    # ================================================================================
    #
    (my $mfreq = $Post{bufr}{freq}) =~ s/:\w*//g;
     my $phr = $mfreq%60 ? 'ZZ' : (int($mfreq/60) > 99) ? 'ZZ' : sprintf("%02d",int($mfreq/60));


    foreach my $prm ('bufkt_uems.pack') {
        unless (-s "$Post{bufr}{tables}/$prm") {
            &Ecomm::PrintMessage(9,12+$Post{arf},144,0,2,"Gemsnd2Bufkit: GEMPAK packing table is missing: $Post{bufr}{tables}/$prm.\n\nGo find it Inspector GEMPAK!");
            return ();
        }
        open my $ofh, '>', "$Post{bufkit}{dwork}/$prm";
        open my $ifh, '<', "$Post{bufr}{tables}/$prm";
        while (<$ifh>) {chomp $_; s/ZZ/$phr/g; print $ofh "$_\n";} close $ofh; close $ifh;
        push @Deloops, "$Post{bufkit}{dwork}/$prm";
    }

    $infile = "st2_sfcfil.$$";
    push @Deloops, "$Post{bufkit}{dwork}/$infile";
    push @Deloops, "$Post{bufkit}{dwork}/gemglb.nts";
    push @Deloops, "$Post{bufkit}{dwork}/last.nts";


    ($logfile  = $Post{bufkit}{logfile}) =~ s/ROUTINE/sfcfil/g;
    push @Deloops, $logfile;


    #----------------------------------------------------------------------------------
    #  Prepare the input file for running
    #----------------------------------------------------------------------------------
    #
    my $sfdset = "sffile_dset_sfc.$$";  #  Name of empty surface file

    open $ifh, '>', $infile;
    print $ifh    "SFOUTF = $sfdset\n",
                  "SFPRMF = ./bufkt_uems.pack\n",
                  "STNFIL = \n",
                  "SHIPFL = NO\n",
                  "TIMSTN = $nt\/$ns\n",
                  "SFFSRC = \n",
                  "list\n",
                  "run \n"  ,
                  "    \n"  ,
                  "exit\n"  ;
    close $ifh; $| = 1;


    #----------------------------------------------------------------------------------
    #  Run the GEMPAK sfcfil routine to extract the individual station surface info
    #----------------------------------------------------------------------------------
    #
    if (my $err = &Ecore::SysExecute("$sfcfil < $infile",$logfile)) {

        #  If the user passed a Control-C (^C) then simply clean up the mess
        #  that was made and exit
        # 
        &Outils::ProcessInterrupt('sfcfil',2,$Post{bufkit}{dwork},\@Deloops,[$logfile]) if $err == 2;
        &Ecomm::PrintMessage(6,12+$Post{arf},144,0,2,"Bufkit station files (2) - Failed (No BUFKIT Love for You)");

        if (-s $logfile and open my $bfh, '<', $logfile) {
            my @lines = <$bfh>; close $bfh; foreach (@lines) {chomp $_; s/^\s+//g;}
            &Outils::ErrorHelper($logfile,$Post{arf},$err,@lines);
        }
        return ();

    }


    unless (-s $sfdset) {
        &Ecomm::PrintMessage(6,12+$Post{arf},255,0,2,"\xe2\x98\xa0 Something broke - Check $logfile");
        return ();
    }
    &Others::rm(@Deloops);  @Deloops = ();



    # ================================================================================
    #  Step III. You know that empty surface file that was just created?  It's
    #            about to be used for step III. Run sflist for each station to
    #            and write data to temporary ascii files. These files (ascii)
    #            will be used to populate the surface file.
    # ================================================================================
    #
    $ptfile = File::Spec->abs2rel($gemsfc);
    $ptloc  = &Others::popit($ptfile);

    unless (symlink $ptfile => $ptloc) {
        &Ecomm::PrintMessage(6,12+$Post{arf},144,0,2,sprintf("Link creation to gemsnd/$ptloc Failed (%s) - Return",$!));
        return ();
    }


    #----------------------------------------------------------------------------------
    #  The period indicator, 'ZZ' (hours) for fields such as pZZm and cZZm,
    #  is populated dynamically unless the period is less than 1 hour, in
    #  which case 'ZZ' is used.
    #----------------------------------------------------------------------------------
    #
    #  BUFKIT V1 ORDER:
    #
    #    STN YYMMDD/HHMM PMSL PRES SKTC STC1 SNFL WTNS P01M C01M STC2 LCLD 
    #                    MCLD HCLD SNRA UWND VWND R01M BFGR T2MS Q2MS WXTS
    #                    WXTP WXTZ WXTR USTM VSTM HLCY SLLH WSYM CDBP VSBK TD2M
    #
    #  my $sfc_parm1 = 'pmsl;pres;sktc;t2mc;t2mx;t2mn;rh2m;rhmx;rhmn';  #  New School
    #
    my $sfc_parm1 = "pmsl;pres;sktc;stc1;stc2;snfl;wtns;p${phr}m;c${phr}m;sfgr;bfgr;t2ms;q2ms;lcld;mcld;hcld";
    my $sfc_parm2 = 'snra;uwnd;vwnd;wxts;wxtp;wxtz;wxtr;ustm;vstm;hlcy;sllh;wsym;cdbp;vsbk;td2m';



    # =================================================================================
    #  The big foreach loop through all stations in hope of creating that special
    #  BUFKIT file. This process takes you through various steps, most of which
    #  involve GEMPAK surface and sounding routines, that culminate in a text file
    #  suitable for viewing in BUFKIT.
    #
    #  Now stand back and allow the conductor to work!
    # =================================================================================
    #
    foreach my $stnm (sort {$a <=> $b} keys %Stations) {


        unless (-s "snfile_${stnm}_snd.$$") {
            &Ecomm::PrintMessage(6,12+$Post{arf},144,1,2,"Missing sounding file for station ${stnm} (snfile_${stnm}_snd.$$) - Next station");
            next;
        }


        # *********************************************************************************
        #  Step IIIa. Run sflist to extract surface infomation from the GEMPAK 
        #             surface file. Start by preparing the input file to sflist.
        # *********************************************************************************
        #

        #----------------------------------------------------------------------------------
        #  Prepare the input for running snlist, which requires looping
        #  through alll stations being processed.
        #----------------------------------------------------------------------------------
        #
        ($logfile  = $Post{bufkit}{logfile}) =~ s/ROUTINE/3a_sflist/g;
        $infile    = "st3_sflist.$$";
        push @Deloops, $logfile;
        push @Deloops, "$Post{bufkit}{dwork}/$infile";
        push @Deloops, "$Post{bufkit}{dwork}/gemglb.nts";
        push @Deloops, "$Post{bufkit}{dwork}/last.nts";


        open  $ifh, '>', $infile;
        print $ifh "SFFILE = $ptloc\n",
                   "AREA   = \@$stnm\n",
                   "DATTIM = ALL\n",
                   "IDNTYP = STNM\n",
                   "SFPARM = $sfc_parm1\n",
                   "OUTPUT = f/sflist_${stnm}_01.$$\n",
                   "list\n",
                   "run \n",
                   "    \n",

                   "SFPARM = $sfc_parm2\n",
                   "OUTPUT = f/sflist_${stnm}_02.$$\n",
                   "list\n", 
                   "run \n", 
                   "    \n", 
                   "exit\n";
        close $ifh; $| = 1;


        #----------------------------------------------------------------------------------
        #  Run the sflist routine and let's see what you got.
        #----------------------------------------------------------------------------------
        #
        if (my $err = &Ecore::SysExecute("$sflist < $infile",$logfile)) {

            #  If the user passed a Control-C (^C) then simply clean up the mess
            #  that was made and exit
            # 
            &Outils::ProcessInterrupt('sflist',2,$Post{bufkit}{dwork},\@Deloops,[$logfile]) if $err == 2;
            &Ecomm::PrintMessage(6,12+$Post{arf},144,0,2,"Bufkit station $stnm (3) - Failed (No BUFKIT Love for You)");

            if (-s $logfile and open my $bfh, '<', $logfile) {
                my @lines = <$bfh>; close $bfh; foreach (@lines) {chomp $_; s/^\s+//g;}
                &Outils::ErrorHelper($logfile,$Post{arf},$err,@lines);
            }
            return ();
        }


        #----------------------------------------------------------------------------------
        #  Make sure we have the files we're expecting - sflist_${stnm}_01.$$ and 
        #  sflist_${stnm}_02.$$.
        #----------------------------------------------------------------------------------
        #
        unless (-s "sflist_${stnm}_01.$$" and -s "sflist_${stnm}_02.$$") {
            &Ecomm::PrintMessage(6,12+$Post{arf},144,1,2,"\xe2\x98\xa0 Something broke - Check $logfile");
            return ();
        }
        &Others::rm(@Deloops); @Deloops = ();



        # *********************************************************************************
        #  Step IIIb. Run the sfedit routine and write the information back to the gempak
        #             surface file. Start by creating the input file.
        # *********************************************************************************
        #
        ($logfile  = $Post{bufkit}{logfile}) =~ s/ROUTINE/3b_sfedit/g;
        $infile    = "st3_sfedit.$$";

        push @Deloops, $logfile;
        push @Deloops, "$Post{bufkit}{dwork}/$infile";
        push @Deloops, "$Post{bufkit}{dwork}/sflist_${stnm}_01.$$";
        push @Deloops, "$Post{bufkit}{dwork}/sflist_${stnm}_02.$$";

        open  $ifh, '>', $infile;
        print $ifh "SFFILE = $sfdset\n",
                   "SFEFIL = sflist_${stnm}_01.$$\n",
                   "list\n"  ,
                   "run \n"  ,
                   "    \n"  ,
                   "SFEFIL = sflist_${stnm}_02.$$\n",
                   "run \n"  ,
                   "    \n"  ,
                   "exit\n"  ;
        close $ifh;


        #----------------------------------------------------------------------------------
        #  Run the sfedit routine to extract the individual surface info.
        #----------------------------------------------------------------------------------
        # 
        if (my $err = &Ecore::SysExecute("$sfedit < $infile",$logfile)) {

            #  If the user passed a Control-C (^C) then simply clean up the mess
            #  that was made and exit
            # 
            &Outils::ProcessInterrupt('sfedit',2,$Post{bufkit}{dwork},\@Deloops,[$logfile]) if $err == 2;
            &Ecomm::PrintMessage(6,12+$Post{arf},144,0,2,"Bufkit station $stnm (4) - Failed (No BUFKIT Love for You)");

            if (-s $logfile and open my $bfh, '<', $logfile) {
                my @lines = <$bfh>; close $bfh; foreach (@lines) {chomp $_; s/^\s+//g;}
                &Outils::ErrorHelper($logfile,$Post{arf},$err,@lines);
            }
            return ();
        }
        &Others::rm(@Deloops); @Deloops = ();# Don't need these anymore


       
        # *********************************************************************************
        #  Step IIIc. Write out the final ascii text file containing the data for the
        #             station. This file is essentially the same as the final BUFKIT
        #             file except for some minor massaging that takes place at the end.
        # *********************************************************************************
        #
        ($logfile  = $Post{bufkit}{logfile}) =~ s/ROUTINE/3c_sflist/g;
        $infile    = "st3_sflist.$$";

        push @Deloops, $logfile;
        push @Deloops, "$Post{bufkit}{dwork}/$infile";
        push @Deloops, "$Post{bufkit}{dwork}/gemglb.nts";
        push @Deloops, "$Post{bufkit}{dwork}/last.nts";

        open  $ifh, '>', $infile;
        print $ifh "SFFILE = $sfdset\n",
                   "AREA   = \@$stnm\n",
                   "DATTIM = ALL\n",
                   "IDNTYP = STNM \n",
                   "SFPARM = dset\n",
                   "OUTPUT = f/sffile_${stnm}_sfc.$$\n",
                   "list\n",
                   "run \n",
                   "    \n",
                   "exit\n";
        close $ifh;


        #----------------------------------------------------------------------------------
        #  Run the sfedit routine to extract the individual surface info.
        #----------------------------------------------------------------------------------
        # 
        if (my $err = &Ecore::SysExecute("$sflist < $infile",$logfile)) {

            #  If the user passed a Control-C (^C) then simply clean up the mess
            #  that was made and exit - This was cut-n-pasted (Duh).
            # 
            &Outils::ProcessInterrupt('sflist',2,$Post{bufkit}{dwork},\@Deloops,[$logfile]) if $err == 2;
            &Ecomm::PrintMessage(6,12+$Post{arf},144,0,2,"Bufkit station $stnm (5) - Failed (No BUFKIT Love for You)");

            if (-s $logfile and open my $bfh, '<', $logfile) {
                my @lines = <$bfh>; close $bfh; foreach (@lines) {chomp $_; s/^\s+//g;}
                &Outils::ErrorHelper($logfile,$Post{arf},$err,@lines);
            }
            return ();
        }


        #----------------------------------------------------------------------------------
        #  Make sure we have the files we're expecting - ascii_${stnm}.sfc.$$
        #----------------------------------------------------------------------------------
        #
        unless (-s "sffile_${stnm}_sfc.$$") {
            &Ecomm::PrintMessage(6,12+$Post{arf},144,1,2,"\xe2\x98\xa0 Something broke - Check $logfile");
            return ();
        }
        &Others::rm(@Deloops); @Deloops = ();



        # *********************************************************************************
        #  Step IIId. Massage the ascii files to eliminate unwanted white spaces and 
        #             other undesirable characters :) 
        # *********************************************************************************
        #
        my $snfile = "snfile_${stnm}_snd.$$";
        my $sffile = "sffile_${stnm}_sfc.$$";
        my $stfile = "stfile_${stnm}.$$";

        open my $snfh, '<', $snfile;  #  Open for read
        open my $sffh, '<', $sffile;  #  Open for read

        open my $stfh, '>', $stfile;  #  Open for write

        my $p = 0;
        while (<$snfh>) {print $stfh $_;} close $snfh;
        while (<$sffh>) {$p = 1 if /STN/; print $stfh $_ if $p;} close $sffh; close $stfh;
        
 
        #----------------------------------------------------------------------------------
        #  Time to create the BUFKIT file.
        #----------------------------------------------------------------------------------
        #
        my $bufkit = $Post{bufkit}{fname};
           $bufkit =~ s/STNM/$stnm/g;
           $bufkit =~ s/STID/$Stations{$stnm}/g;
           $bufkit =~ s/YYYYMMDDCC/$yyyymmddcc/g;
           $bufkit =~ s/\.buz/.buf/g;  #  As a precaution
           $bufkit = File::Spec->abs2rel("$Post{bufkit}{dpost}/$bufkit");


        open my $bkfh, '>', $bufkit;
        open    $stfh, '<', $stfile;
        while (<$stfh>) {tr/ / /s;s/^ //g;s/\n/\15\n/g;print $bkfh $_;}

        &Others::rm($snfile,$sffile,$stfile);

        #----------------------------------------------------------------------------------
        #  Did the user request a zipped file?
        #----------------------------------------------------------------------------------
        #
        if ($zipit) { 

            (my $buzkit = $bufkit) =~ s/\.buf/.buz/g;
            (my $cmd = $zipit) =~ s/BUZ/$buzkit/; $cmd =~ s/BUF/$bufkit/;

            if (system "$cmd > /dev/null 2>&1") {
                &Ecomm::PrintMessage(6,14+$Post{arf},144,1,1,sprintf("%s -> %s failed",&Others::popit($bufkit),&Others::popit($buzkit)));
                &Others::rm($buzkit);
            } else {
                &Others::rm($bufkit);
                $bufkit = $buzkit;
            }

        }
        my $bufloc = &Others::popit($bufkit);
        -s $bufkit ? &Ecomm::PrintMessage(0,14+$Post{arf},96,0,1,"BUFKIT file created - $bufloc") : &Ecomm::PrintMessage(6,14+$Post{arf},96,0,1,"Problem creating BUFKIT file - $bufloc"); 


    }  #  For each station loop


    #----------------------------------------------------------------------------------
    #  BUFKIT creation accomplished! I hope
    #----------------------------------------------------------------------------------
    #
    chdir $Post{bufkit}{dpost};  #  Must change or next command produces error

    @Bufkit = &Others::FileMatch($Post{bufkit}{dpost},$bufkey,0,0);
    &Ecomm::PrintMessage(9,12+$Post{arf},255,2,2,"\xe2\x98\xa0 Something broke - I don't know why") unless @Bufkit;
    &Others::rm($Post{bufkit}{dwork});
    
    my $date = gmtime();
    &Ecomm::PrintMessage(0,12+$Post{arf},255,1,2,sprintf("Creation of domain $dom BUFKIT files %s at %s UTC",@Bufkit ? 'completed' : 'failed',$date));


return @Bufkit;
}


sub WhichZipIt {
# =================================================================================
#  If the user requests that the BUFKIT files be compressed (*.buz), then locate
#  a utility for the job and return a command; otherwise, return empty string.
# =================================================================================
#
    #  Locate the zip and/or gzip commands
    #
    my %routine = ();
    $routine{$_} = &Others::LocateX($_) foreach ('zip', 'gzip');

return %routine ? $routine{zip} ? "$routine{zip} -q -j BUZ BUF" : "$routine{gzip} -q -c BUF > BUZ" : '';
}


sub ExportBufkit {
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

    &Ecomm::PrintMessage(1,9+$Post{arf},144,1,1,sprintf("Using mind control to send domain %s $ucb files to a new home",$dom));

    #----------------------------------------------------------------------------------
    #  Loop over each of the export requests (there may be more than one)
    #----------------------------------------------------------------------------------
    #
    my $nt = keys %{$Post{$btype}{export}}; my $nn = $nt;

    foreach my $exp (sort {$a <=> $b}  keys %{$Post{$btype}{export}}) {

        @{$Post{$btype}{export}{$exp}{files}} = sort @{$Post{$btype}{newfiles}};

        $Post{$btype}{export}{$exp}{rdir} = &Others::PlaceholderFillDate($Post{$btype}{export}{$exp}{rdir},$Post{yyyymmddcc},@phs);

        if (&Outils::ExportFiles(\%{$Post{$btype}{export}{$exp}}) ) {
            &Ecomm::PrintMessage(6,14+$Post{arf},144,1,1,sprintf("There was an error with $btype export"));
        }
        $nn--;
    }


    my $date = gmtime();
    my $inc  = $nn ? 'went the way of Uri Geller' : 'successful';
    &Ecomm::PrintMessage(0,12+$Post{arf},144,1,2,sprintf("Mind control $inc at %s",$date));


return 0;
}



