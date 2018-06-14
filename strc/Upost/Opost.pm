#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Opost.pm
#
#  DESCRIPTION:  Opost contains the routines used when processing the simulation
#                output into GRIB 2 files.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Opost;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Upost $mesg);

use Outils;
use Ecore;


sub ExecutePost {
#==================================================================================
#  The &ExecutePost routine is the driver for the individual tasks involved
#  in processing of the luscious simulation output. Most everything needed
#  to achieve the ultimate goal of PP nirvana is held in the %{$Upost{parms}} 
#  hash, including the list of model output files for each domain.
#==================================================================================
#
use Bufr;
use Grib2;
use Grads;
use Gempak;
use Bufkit;


    my $uref = shift;  %Upost = %{$uref};  #  %Upost is GLOBAL within this module

    #----------------------------------------------------------------------------
    #  Complete the assignment of the post processing tasks, which will be
    #  carried in the %{$Upost{post}} hash. 
    #----------------------------------------------------------------------------
    #
    return () unless %{$Upost{post}} = &Process2Domain(\%Upost);
    unless ($Upost{post}{proc}) {&Ecomm::PrintMessage(0,9+$Upost{arf},255,1,1,'"I have nothing to do?  Awww, Come on!  Please give me a chance to play!"'); return %Upost;}

    #----------------------------------------------------------------------------
    #  First provide a summary of the post processing tasks to be completed.
    #----------------------------------------------------------------------------
    #
    if ($Upost{post}{info}) {
        $Upost{emsenv}{autorun} ? &Ecomm::PrintMessage(0,7,144,2,2,sprintf("%-4s AutoPost: A Summary of Post-Processing Tasks",&Ecomm::GetRN($ENV{ORN}++)))
                                : &Ecomm::PrintMessage(0,4,144,2,2,sprintf("%-4s A Summary of Post-Processing Tasks:",&Ecomm::GetRN($ENV{ORN}++)));

        &Ecomm::PrintMessage(1,9+$Upost{arf},255,1,1,&Process2Summary(\%Upost));

        Ecomm::PrintMessage(0,12+$Upost{arf},255,2,1,'Now what are you going to do for me?');

        &Ecore::SysExit(-6) if $Upost{post}{info} < 0;
    }


    #----------------------------------------------------------------------------
    #  If the --scour flag was passed delete and recreate the emsprd/ directory.
    #----------------------------------------------------------------------------
    #
    &Others::rm($Upost{rtenv}{emsprd})     if $Upost{post}{scour};
    &Others::mkdir($Upost{rtenv}{emsprd});


    #----------------------------------------------------------------------------
    #  Loop over each domain and dataset requested for processing. Each
    #  processing subroutine is called regardless whether the user turned ON
    #  that data type. Should the data type be turned OFF (checked within the
    #  subroutine) or fail for some reason, an empty array is returned;
    #  otherwise, an array containing the data processed data files is
    #  returned.
    #----------------------------------------------------------------------------
    #
    foreach my $d (sort {$a <=> $b} keys  %{$Upost{post}{domains}}) {  #  For each domain requested

        foreach my $ftype (reverse sort keys %{$Upost{post}{domains}{$d}}) { #  For each data type requested (wrfout or auxhist)

            next unless $Upost{post}{domains}{$d}{$ftype}{proc};  #  If processing is necessary for $ftype (wrfout or auxhist)

            unless ($Upost{emsenv}{autorun} or $Upost{parms}{autopost}) {
                &Ecomm::PrintMessage(0,4,144,2,2,sprintf ("%-4s Begin post-processing domain $d %s simulation output",&Ecomm::GetRN($ENV{ORN}++),$ftype=~/auxhist/ ? 'auxiliary' : 'primary'));
            }

            #-------------------------------------------------------------------
            #  Begin the processing into each supported format
            #-------------------------------------------------------------------
            #
            %{$Upost{post}{domains}{$d}{$ftype}}  = &Grib2::Process2Grib($ftype,\%{$Upost{post}{domains}{$d}{$ftype}});
            %{$Upost{post}{domains}{$d}{$ftype}}  = &Grads::Process2Grads($ftype,\%{$Upost{post}{domains}{$d}{$ftype}});
            %{$Upost{post}{domains}{$d}{$ftype}}  = &Gempak::Process2Gempak($ftype,\%{$Upost{post}{domains}{$d}{$ftype}});

            next unless $ftype eq 'wrfout';

            %{$Upost{post}{domains}{$d}{$ftype}}  = &Bufr::Process2Bufr(\%{$Upost{post}{domains}{$d}{$ftype}});
            %{$Upost{post}{domains}{$d}{$ftype}}  = &Bufkit::Process2Bufkit(\%{$Upost{post}{domains}{$d}{$ftype}});
              
        } #  For each data type

    } #  For each domain


return %Upost;
} 



sub Process2Domain {
# ==================================================================================
#  This routine completes the final assignment of post processing tasks to each
#  requested domain.  It takes the contents of %{$Upost{parms}} and assigns 
#  specific domain values into a new hash for each domain. The returned hash
#  %Post will be used throughout ems_post (%{$Upost{post}}).
# ==================================================================================
#    
    my %Post   = ();  #  The new hash
    my %Explst = ();

    my $upref = shift; %Upost = %{$upref}; 

    my ($nogempak, $nobufkit, $nograds) = (0) x 3;

    #  Begin with the fields that are not domain specific. The simple stuff
    #
    $Post{proc}     = 0;  #  Should be greater than 0 if processing needed
    $Post{rundir}   = $Upost{parms}{rundir};
    $Post{scour}    = $Upost{parms}{scour} == 1 ? 1 : 0;  #  Note that value meaning differs slightly from processing value below
    $Post{info}     = $Upost{parms}{summary}  ? 1 : $Upost{parms}{info} ? -1 : 0;
    $Post{autopost} = $Upost{parms}{autopost};
    $Post{mpicheck} = $Upost{parms}{mpicheck};
    $Post{core}     = 'arw';  #  This will have to change as additional cores are added
    $Post{domain}   = &Others::popit($Post{rundir});

    my %Types       = map {split ':', $_,2} split ',', $Upost{parms}{emspost};


    #==============================================================================
    #  Configure the MPI related information for the system being used to 
    #  run the UEMS UPP. The number of cores used for each domain will be 
    #  further refined during the main loop below. Note that just because 
    #  a user has requested 24 cores to be used for processing a specific 
    #  domain does not mean that 24 cores will be used. The final number
    #  of cores depends upon the number of gridpoints in the NY direction.
    #==============================================================================
    #
    my %Process = ();

    unless ($Upost{parms}{noupp}) {
        %Process            = &ProcessInit_UPP($Upost{parms}{nodecpus});  return () unless %Process;
        $Process{hostpath}  = $Upost{rtenv}{logdir};  
        $Process{mpidbg}    = 0; # Include mpich debug flags ? (1|0) 
    }

    #  Organize the list of datasets to export
    #
    @{$Explst{0}} = ();  #  Must be initialized
    foreach (split ',' => $Upost{parms}{exports}) {my ($d,$str) = split '\|' => $_, 2; push @{$Explst{$d}} => $str; }

    foreach my $d (split ',' => $Upost{parms}{domains}) {

        my $dd  = sprintf('%02d',$d);  #  Needed for formatting of filenames

        %{$Post{domains}{$d}} = ();

        foreach my $filetype (split ':' => $Types{$d}) {

            $Post{domains}{$d}{$filetype}{noupp}    = $Upost{parms}{noupp};
            $Post{domains}{$d}{$filetype}{debug}    = $Upost{parms}{debug};
            $Post{domains}{$d}{$filetype}{domain}   = $d;
            $Post{domains}{$d}{$filetype}{arf}      = $Upost{arf};
            $Post{domains}{$d}{$filetype}{core}     = $Post{core};
            $Post{domains}{$d}{$filetype}{apost}    = $Post{autopost};
            $Post{domains}{$d}{$filetype}{index}    = $Upost{parms}{index};
            $Post{domains}{$d}{$filetype}{rundir}   = $Post{rundir};
       
            $Post{domains}{$d}{$filetype}{scour}    = ($Upost{parms}{scour} == -1 or $Upost{parms}{noupp} or $Post{autopost} or $Upost{parms}{index}) ? 0 : 1;  #  Note value change (-1 -> 0)


            #  Although post processing has been turned on for a specific dataset, 
            #  attempt to determine whether it's actually needed.
            #
            $Post{domains}{$d}{$filetype}{proc}  = 0;


            #  Transfer the list of simulation output files for each domain (if any) from the 
            #  Upost hash to the %Post hash. Two arrays are carried for each dataset. One for 
            #  all the netCDF files output since T0 (allfiles) and another for those output
            #  since the last call to ems_post from autopost (index).
            #
            my $fls = ($filetype eq 'wrfout') ? 'wrffls' : 'auxfls';
            @{$Post{domains}{$d}{$filetype}{netcdf}{allfiles}}  = @{$Upost{rtenv}{postdoms}{$d}{$fls}};
            @{$Post{domains}{$d}{$filetype}{netcdf}{newfiles}}  = @{$Post{domains}{$d}{$filetype}{netcdf}{allfiles}};


            #  Assign the history interval and whether the netcdf files contain more than one time (frames_per_*).
            #  There two possible sources for this information, the WRF namelist file or the netCDF files from
            #  the UEMS release binaries. Since the most reliable information will come from the netCDF files
            #  we'll use that source.
            #
            $Post{domains}{$d}{$filetype}{netcdf}{frames}       = ($filetype eq 'wrfout') ? $Upost{rtenv}{postdoms}{$d}{wrfframes} : $Upost{rtenv}{postdoms}{$d}{auxframes};
            $Post{domains}{$d}{$filetype}{netcdf}{monofile}     = ($Post{domains}{$d}{$filetype}{netcdf}{frames} > 1) ? 1 : 0;
            $Post{domains}{$d}{$filetype}{netcdf}{histfreq}     = ($filetype eq 'wrfout') ? $Upost{rtenv}{postdoms}{$d}{wrfhint} : $Upost{rtenv}{postdoms}{$d}{auxhint};

            #  Uncomment to use namelist file as source of information
            #
            #  my $hfs = ($filetype eq 'wrfout') ? 'wrf' : 'aux';
            #  $Post{domains}{$d}{$filetype}{netcdf}{frames}       = $Upost{rtenv}{frames}{$hfs}[$d-1];
            #  $Post{domains}{$d}{$filetype}{netcdf}{monofile}     = ($Upost{rtenv}{frames}{$hfs}[$d-1] > 1) ? 1 : 0;
            #  $Post{domains}{$d}{$filetype}{netcdf}{histfreq}     = $Upost{rtenv}{hist}{$hfs}[$d-1];
             

            if ($Upost{parms}{index}) {
                my $first = $Upost{parms}{index};
                my $last  = @{$Upost{rtenv}{postdoms}{$d}{$fls}}-1;
                if ($first > $last) {
                    my $n = $last+1;
                    $mesg = "The index value ($Upost{parms}{index}), is greater than the number of domain $d $filetype output files available ($n). ".
                            "Consequently, no domain $d output files will be processed,  which is probably not what you wanted.";
                    &Ecomm::PrintMessage(6,11+$Upost{arf},94,1,2,$mesg) unless $Post{noupp} or $Post{autopost};
                }
                @{$Post{domains}{$d}{$filetype}{netcdf}{newfiles}}  = ($first <= $last) ? @{$Upost{rtenv}{postdoms}{$d}{$fls}}[$first .. $last] : ();
            }
            $Post{domains}{$d}{$filetype}{netcdf}{dpost}  = $Upost{rtenv}{wrfprd};



            #  We need the initialization date/time for the domain, which may be different from 
            #  that of the primary domain.
            #
            $Post{domains}{$d}{$filetype}{yyyymmddcc}      = $Upost{rtenv}{postdoms}{$d}{initdate};


            #  Write the placeholder KEY:VALUE pairs to the array that will be passed to
            #  the &PlaceholderFill subroutines. The only thing that needs to be added
            #  later is DSET:VALUE.
            #
            @{$Post{domains}{$d}{$filetype}{placeholders}} = ("CORE:arw","KEY:$filetype","WD:$dd","RD:$Post{domain}");



            #  &GetExportFiles must be called within the domain loop because the domain ID is specified as a hashkey.
            #
            @{$Explst{$d}} = $Explst{$d} ? (@{$Explst{0}},@{$Explst{$d}}) : @{$Explst{0}};
            %{$Post{domains}{$d}{$filetype}{netcdf}{export}}  = @{$Post{domains}{$d}{$filetype}{netcdf}{newfiles}}  
                                                              ? &GetExportFiles('netcdf',$filetype,@{$Explst{$d}})  : ();

        
            %{$Post{domains}{$d}{$filetype}{grib}} = ();

            if (&GetDomainValue($d,$Upost{parms}{grib})) {

              @{$Post{domains}{$d}{$filetype}{grib}{allfiles}} = ();
              @{$Post{domains}{$d}{$filetype}{grib}{newfiles}} = ();

                $Post{domains}{$d}{$filetype}{grib}{ocntr}     = sprintf '%05d', &GetDomainValue($d,$Upost{parms}{ocntr});
                $Post{domains}{$d}{$filetype}{grib}{mdlid}     = sprintf '%05d', &GetDomainValue($d,$Upost{parms}{mdlid});
                $Post{domains}{$d}{$filetype}{grib}{scntr}     = sprintf '%05d', &GetDomainValue($d,$Upost{parms}{scntr});
                $Post{domains}{$d}{$filetype}{grib}{dpost}     = "$Upost{rtenv}{emsprd}/grib";

                $Post{domains}{$d}{$filetype}{proc}            = 1 if @{$Post{domains}{$d}{$filetype}{netcdf}{newfiles}};
                $Post{domains}{$d}{$filetype}{proc}            = 0 if $Upost{parms}{noupp};

                $Post{domains}{$d}{$filetype}{grib}{freq}      = &GetDomainValue($d,$filetype eq 'wrfout' ? $Upost{parms}{frqwrf_grib} : $Upost{parms}{frqaux_grib});
                $Post{domains}{$d}{$filetype}{grib}{pacc}      = &GetDomainValue($d,$filetype eq 'wrfout' ? $Upost{parms}{accwrf_grib} : $Upost{parms}{accaux_grib});

                $Post{domains}{$d}{$filetype}{grib}{cntrl}     = &GetDomainValue($d,$filetype eq 'wrfout' ? $Upost{parms}{grbcntrl_wrf} : $Upost{parms}{grbcntrl_aux});
                $Post{domains}{$d}{$filetype}{grib}{cntrl}     = &Others::PlaceholderFill($Post{domains}{$d}{$filetype}{grib}{cntrl},@{$Post{domains}{$d}{$filetype}{placeholders}},"DSET:grib2");

                $Post{domains}{$d}{$filetype}{grib}{fname}     = &Others::PlaceholderFill($Upost{parms}{filename_grib},@{$Post{domains}{$d}{$filetype}{placeholders}});
                $Post{domains}{$d}{$filetype}{grib}{logfile}   = sprintf("$Upost{rtenv}{logdir}/post_emsupp_%s_d%02d.log",$filetype eq 'wrfout' ? 'wrfout' : 'auxhist',$dd);
              %{$Post{domains}{$d}{$filetype}{grib}{export}}   = &GetExportFiles('grib',$filetype,@{$Explst{$d}});

              @{$Post{domains}{$d}{$filetype}{grib}{crtmtbls}} = sort &Others::FileMatch($Upost{rtenv}{tables}{crtm2},'',0,0);
              @{$Post{domains}{$d}{$filetype}{grib}{grbtbls}}  = map {"$Upost{rtenv}{tables}{grib}/$_"} qw(params_grib2_tbl_new post_avblflds.xml);

              #  Set the number of cores used to process the simulation output for this domain
              #
              %{$Post{domains}{$d}{$filetype}{grib}{process}}  = &DefineNodesCores($Upost{rtenv}{postdoms}{$d}{ny},\%Process) if $Post{domains}{$d}{$filetype}{proc};

            }


            %{$Post{domains}{$d}{$filetype}{gempak}} = ();

            if (&GetDomainValue($d,$Upost{parms}{gempak})) {

                $Post{domains}{$d}{$filetype}{proc}              = 1 unless $Upost{parms}{gempaklibs};
                $Post{domains}{$d}{$filetype}{gempak}{fname}     = &Others::PlaceholderFill($Upost{parms}{filename_gempak},@{$Post{domains}{$d}{$filetype}{placeholders}});
                $Post{domains}{$d}{$filetype}{gempak}{freq}      = &GetDomainValue($d,$filetype eq 'wrfout' ? $Upost{parms}{frqwrf_gempak} : $Upost{parms}{frqaux_gempak}); 
                $Post{domains}{$d}{$filetype}{gempak}{script}    = $Upost{parms}{scrwrf_gempak};
                $Post{domains}{$d}{$filetype}{gempak}{monofile}  = &GetDomainValue($d,$Upost{parms}{monofile_gempak});
                $Post{domains}{$d}{$filetype}{gempak}{dpost}     = "$Upost{rtenv}{emsprd}/gempak";
                $Post{domains}{$d}{$filetype}{gempak}{nawips}    = "$ENV{EMS_UTIL}/nawips";
                $Post{domains}{$d}{$filetype}{gempak}{gemlog1}   = sprintf("$Upost{rtenv}{logdir}/post_grib2gempak1_%s_d%02d.log",$filetype eq 'wrfout' ? 'wrfout' : 'auxhist',$dd);
                $Post{domains}{$d}{$filetype}{gempak}{gemlog2}   = sprintf("$Upost{rtenv}{logdir}/post_grib2gempak2_%s_d%02d.log",$filetype eq 'wrfout' ? 'wrfout' : 'auxhist',$dd);
              %{$Post{domains}{$d}{$filetype}{gempak}{export}}   = &GetExportFiles('gempak',$filetype,@{$Explst{$d}});


                #  If Upost{parms}{gempaklibs} is non-zero, that means there is a problem with the routine(s)
                #  used to process GRIB 2 to GEMPAK files. Consequently, we'll need to turn processing OFF.
                #
                if ($Upost{parms}{gempaklibs}) {
                    (my $desc = $Upost{parms}{gempaklibs}) =~ s/,/\nX02X/g;
                    $mesg = "There will not be an processing of GRIB 2 files into GEMPAK format until\n".
                            "you address the following problem:\n\n".
                            "X02X$desc\n\n".
                            "GEMPAK processing is turned off for now.";
                    &Ecomm::PrintMessage(9,11+$Upost{arf},255,1,2,$mesg) unless $nogempak;

                    $nogempak = 1;
                    %{$Post{domains}{$d}{$filetype}{gempak}} = ();
                }


            }  # GEMPAK


            %{$Post{domains}{$d}{$filetype}{grads}} = ();

            if (&GetDomainValue($d,$Upost{parms}{grads})) {

                $Post{domains}{$d}{$filetype}{proc}              = 1 unless $Upost{parms}{gradslibs};
                $Post{domains}{$d}{$filetype}{grads}{freq}       = &GetDomainValue($d,$filetype eq 'wrfout' ? $Upost{parms}{frqwrf_grads} : $Upost{parms}{frqaux_grads});
                $Post{domains}{$d}{$filetype}{grads}{script}     = $Upost{parms}{scrwrf_grads};
                $Post{domains}{$d}{$filetype}{grads}{monofile}   = &GetDomainValue($d,$Upost{parms}{monofile_grads}); 
               ($Post{domains}{$d}{$filetype}{grads}{fname}      = $Post{domains}{$d}{$filetype}{grib}{fname}) =~ s/\.grb2\w*//g;
                $Post{domains}{$d}{$filetype}{grads}{dpost}      = "$Upost{rtenv}{emsprd}/grads";
                $Post{domains}{$d}{$filetype}{grads}{dbin}       = "$ENV{EMS_UTIL}/grads/bin";
                $Post{domains}{$d}{$filetype}{grads}{logfile}    = sprintf("$Upost{rtenv}{logdir}/post_grib2grads_%s_d%02d.log",$filetype eq 'wrfout' ? 'wrfout' : 'auxhist',$dd);
              %{$Post{domains}{$d}{$filetype}{grads}{export}}    = &GetExportFiles('grads',$filetype,@{$Explst{$d}});


                #  If Upost{parms}{gradslibs} is non-zero, that means there is a problem with the routine(s)
                #  used to process GRIB 2 to GrADS files. Consequently, we'll need to turn processing OFF.
                #
                if ($Upost{parms}{gradslibs}) {
                    (my $desc = $Upost{parms}{gradslibs}) =~ s/,/\nX02X/g;
                    $mesg = "There will not be an processing of GRIB 2 files into GrADS format until\n".
                            "you address the following problem:\n\n".
                            "X02X$desc\n\n".
                            "GrADS processing is turned off for now.";
                    &Ecomm::PrintMessage(9,11+$Upost{arf},255,1,2,$mesg) unless $nograds;

                    $nograds = 1;
                    %{$Post{domains}{$d}{$filetype}{grads}} = ();
                }


            }  #  GRADS
            $Post{proc}+=$Post{domains}{$d}{$filetype}{proc};


            next unless $filetype eq 'wrfout';

            %{$Post{domains}{$d}{wrfout}{bufr}}    = ();
            %{$Post{domains}{$d}{wrfout}{gemsnd}}  = ();
            %{$Post{domains}{$d}{wrfout}{ascisnd}} = ();
            %{$Post{domains}{$d}{wrfout}{bufkit}}  = ();

            if (&GetDomainValue($d,$Upost{parms}{bufr}) and @{$Upost{rtenv}{postdoms}{$d}{wrffls}}) {

                unless ($Post{domains}{$d}{wrfout}{bufr}{stnlist} = &CheckBufrStationFile(&Others::PlaceholderFill(&GetDomainValue($d,$Upost{parms}{station_list}),@{$Post{domains}{$d}{$filetype}{placeholders}}))) {
                    %{$Post{domains}{$d}{wrfout}{bufr}}   = ();
                    next;
                }


                $Post{domains}{$d}{wrfout}{proc}                  = 1;
 
                $Post{domains}{$d}{wrfout}{bufr}{fname}           = &Others::PlaceholderFill($Upost{parms}{filename_bufr},@{$Post{domains}{$d}{$filetype}{placeholders}});
                $Post{domains}{$d}{wrfout}{bufr}{tables}          = $Upost{rtenv}{tables}{bufr};
                $Post{domains}{$d}{wrfout}{bufr}{freq}            = &GetDomainValue($d,$Upost{parms}{frqwrf_bufr});
                $Post{domains}{$d}{wrfout}{bufr}{style}           = &GetDomainValue($d,$Upost{parms}{bufr_style});
                $Post{domains}{$d}{wrfout}{bufr}{bfinfo}          = &GetDomainValue($d,$Upost{parms}{bfinfo}) ? 'T' : 'F';
                $Post{domains}{$d}{wrfout}{bufr}{dpost}           = "$Upost{rtenv}{emsprd}/bufr";
                $Post{domains}{$d}{wrfout}{bufr}{bufrlog}         = sprintf("$Upost{rtenv}{logdir}/post_uemsbufr_d%02d.log",$dd);
                $Post{domains}{$d}{wrfout}{bufr}{stnslog}         = sprintf("$Upost{rtenv}{logdir}/post_bufrstns_d%02d.log",$dd);
              %{$Post{domains}{$d}{wrfout}{bufr}{stations}}       = &ReadBufrStationList($Post{domains}{$d}{wrfout}{bufr}{stnlist});
              %{$Post{domains}{$d}{wrfout}{bufr}{export}}         = &GetExportFiles('bufr','',@{$Explst{$d}});


                #  If Upost{parms}{bufkitlibs} is non-zero, that means there is a problem with the routine(s)
                #  used to process BUFR to GEMSND & BUFKIT files. Consequently, we'll need to turn processing OFF.
                #
                if ($Upost{parms}{bufkitlibs}) {
                    (my $desc = $Upost{parms}{bufkitlibs}) =~ s/,/\nX02X/g;
                    $mesg = "There will not be an processing of BUFR into GEMPAK sounding & BUFKIT\n".
                            "files until you address the following problem:\n\n".
                            "X02X$desc\n\n".
                            "GEMPAK sounding & BUFKIT processing is turned off for now.";
                    &Ecomm::PrintMessage(9,11+$Upost{arf},255,1,2,$mesg) unless $nobufkit;

                    $nobufkit = 1;
                }


                if (&GetDomainValue($d,$Upost{parms}{gemsnd}) and ! $Upost{parms}{bufkitlibs}) {

                    $Post{domains}{$d}{wrfout}{gemsnd}{fname}     = &Others::PlaceholderFill('YYYYMMDDCC_gemsnd_CORE_dWD',@{$Post{domains}{$d}{$filetype}{placeholders}});
                    $Post{domains}{$d}{wrfout}{gemsnd}{dpost}     = "$Upost{rtenv}{emsprd}/gemsnd";
                    $Post{domains}{$d}{wrfout}{gemsnd}{logfile}   = sprintf("$Upost{rtenv}{logdir}/post_namsnd_d%02d.log",$dd);
                    $Post{domains}{$d}{wrfout}{gemsnd}{nawips}    = "$ENV{EMS_UTIL}/nawips";
                  %{$Post{domains}{$d}{wrfout}{gemsnd}{export}}   = &GetExportFiles('gemsnd','',@{$Explst{$d}});
                  %{$Post{domains}{$d}{wrfout}{gemsnd}{stations}} = %{$Post{domains}{$d}{wrfout}{bufr}{stations}};

                }


                if (&GetDomainValue($d,$Upost{parms}{ascisnd}) and ! $Upost{parms}{bufkitlibs}) {
                    $Post{domains}{$d}{wrfout}{ascisnd}{dpost}    = "$Upost{rtenv}{emsprd}/ascisnd";
                    $Post{domains}{$d}{wrfout}{ascisnd}{fname}    = &Others::PlaceholderFill('YYYYMMDDCC_ascisnd_CORE_dWD_STID.txt',@{$Post{domains}{$d}{$filetype}{placeholders}});
                  %{$Post{domains}{$d}{wrfout}{ascisnd}{export}}  = &GetExportFiles('ascisnd','',@{$Explst{$d}});

                }


                if (&GetDomainValue($d,$Upost{parms}{bufkit}) and ! $Upost{parms}{bufkitlibs}) {

                    $Post{domains}{$d}{wrfout}{bufkit}{dpost}     = "$Upost{rtenv}{emsprd}/bufkit";
                    $Post{domains}{$d}{wrfout}{bufkit}{dwork}     = "$Upost{rtenv}{emsprd}/bufkit/work";
                    $Post{domains}{$d}{wrfout}{bufkit}{logfile}   = sprintf("$Upost{rtenv}{logdir}/post_bufkit_ROUTINE_d%02d.log",$dd);
                    $Post{domains}{$d}{wrfout}{bufkit}{nawips}    = "$ENV{EMS_UTIL}/nawips";
                    $Post{domains}{$d}{wrfout}{bufkit}{zipit}     = &GetDomainValue($d,$Upost{parms}{zipit});
                    $Post{domains}{$d}{wrfout}{bufkit}{fname}     = &Others::PlaceholderFill('CORE_dWD_STID.buf',@{$Post{domains}{$d}{$filetype}{placeholders}}); #  Could also be 'CORE_dWD_STNM.buz'
                    $Post{domains}{$d}{wrfout}{bufkit}{fname}     = "YYYYMMDDCC.$Post{domains}{$d}{wrfout}{bufkit}{fname}" if &GetDomainValue($d,$Upost{parms}{append_date});
                    
                  %{$Post{domains}{$d}{wrfout}{bufkit}{export}}   = &GetExportFiles('bufkit','',@{$Explst{$d}});
                  %{$Post{domains}{$d}{wrfout}{bufkit}{stations}} = %{$Post{domains}{$d}{wrfout}{bufr}{stations}};

                }

            } #  BUFR

            $Post{proc}+=$Post{domains}{$d}{$filetype}{proc};

        }  #  For each dataset type
    }  #  For each Domain

    #  ADD - A subroutine for debugging


return %Post;
}


sub GetExportFiles {
# ==================================================================================
#   The &GetExportFiles routine takes a file type ($rtype), key string ($rkey),
#   and list of EXPORT entries for a domain as specified in post_exports.conf,
#   and returns a hash containing the export information for that dataset or
#   and empty hash if no EXPORT entry for the dataset exists.
# ==================================================================================
#
use List::Util qw( max );

    my %Exports  = ();

    my ($rtype,$rkey,@entries) = @_; return %Exports unless @entries;

    @entries = &Others::rmdups(@entries);

    foreach (@entries) {

        my ($type,$key,$method,$freq,$login,$dest) =  split '\|', $_, 6;

        my $s = ($type =~ s/:s$//g) ? 1 : 0;

        next unless $type eq $rtype;
        next if $rkey and $rkey ne $key;

        my $n = max keys %Exports; $n++;

        $Exports{$n}{meth} = $method ? $method : 0;
        $Exports{$n}{freq} = $freq   ? $freq   : 1;
        $Exports{$n}{host} = $login  ? $login  : 0;
        $Exports{$n}{rdir} = $dest   ? $dest   : 0;
        $Exports{$n}{indv} = $s;
        $Exports{$n}{arf}  = $Upost{arf};  #  No easy way to pass arf

    }


return %Exports;
}


sub ProcessInit_UPP {
# ==================================================================================
#  This subroutine initializes the hash used to configure the MPI environment for
#  running the UEMS UPP. While the hash variables are initialized here, final 
#  assignments or changes will be completed in &DefineNodesCores.
#
#  This routine first calls &Empi::ProcessNodeCpus, which handles the processing 
#  of the UPP_NODECPUS parameter from the post_grib.conf file and returns the 
#  "nodes" sub-hash:
#
#   The nodes hash:
#      $hash{nodes}{$node}{hostname}  - Hostname
#      $hash{nodes}{$node}{address}   - IP Address
#      $hash{nodes}{$node}{iface}     - Network Iface
#      $hash{nodes}{$node}{localhost} - Localhost ? (1|0)
#      $hash{nodes}{$node}{headnode}  - Headnode  ? (1|0)
#      $hash{nodes}{$node}{usecores}  - The number of cores to use on node
#
#   Also:
#      @hash{nodeorder}               - An array containing the order of the nodes passed
#      $hash{totalcores}              - The total number of cores assigned
#
#   The following are hash variables are outside of &Empi::ProcessNodeCpus 
#      $hash{process}                 - Name of process to be run
#      $hash{hostpath}                - Path to the directory where hostsfile is written
#      $hash{nogforker}               - Flag (1) if not to use gforker (mpiexec.gforker)
#      $hash{mpiexe}                  - Path & executable to be run
#      $hash{mpidbg}                  - include mpich debug flags ? (1|0)

# ==================================================================================
#
use Empi;

    my @nodecpu  = split ',' => shift;

    &Ecomm::PrintMessage(0,4,255,2,1,sprintf("%-4s Gathering system information for running %s",&Ecomm::GetRN($ENV{ORN}++),'UEMS UPP')) unless $Upost{emsenv}{autorun} or $Upost{parms}{autopost};

    my %phash = &Empi::ProcessNodeCpus(@nodecpu);

    unless (@{$phash{nodeorder}}) {
        $ENV{OMESG} = &Ecomm::TextFormat(0,0,144,0,0,sprintf('Oh Poop! There is a problem with one or more hosts requested for  UEMS UPP - Exit'));
        return ();
    }
    
    $phash{process}   = 'emsupp';
    $phash{nogforker} = 0;   # not used by ems_post but may be manually assigned
    $phash{mpiexe}    = "$ENV{EMS_BIN}/emsupp";
    $phash{rsllog}    = 'rsl.out.0000';
    $phash{errlog}    = 'rsl.error.0000';


return %phash;
}



sub DefineNodesCores {
# ==================================================================================
#  This subroutine simply determines the maximum number of processors allowed
#  when processing the simulation output for a specific domain. Should the user
#  requested value exceed this maximum is will be replaced in the returned hash.
#  As described in the post_grib.con file, the maximum number of cores allowed 
#  is defined by the number of NY grid points for a specific domain, where:
#
#      MAX_CORES = floor ($NY/6)
# ==================================================================================
#
use List::Util qw(sum);

    my $MIN_POINTS = 6.;

    my ($NY, $phref) = @_;  my %Process = %{$phref};

    my $MAX_CORES = POSIX::floor($NY/$MIN_POINTS); $MAX_CORES = 1 unless $MAX_CORES > 0;

    return %Process unless $Process{totalcpus} > $MAX_CORES;

    #---------------------------------------------------------------------------------
    #  Now it gets messy because the maximum number of cores allowed for a this 
    #  domain ($MAX_CORES) is less than the number requested. How to prune the 
    #  excess number of cores? 
    #---------------------------------------------------------------------------------
    #

    #  Traverse the @nodeorder array, counting the number of CPUs to be used, 
    #  until we've equaled or exceeded the value of $MAX_CORES, then determine 
    #  how to distribute an appropriate number of cores across those machines.
    #
    my @req_nodes = ();
    my $req_total = 0;

    foreach my $node (@{$Process{nodeorder}}) {
        push @req_nodes => $node if $req_total < $MAX_CORES;
        $req_total += $Process{nodes}{$node}{reqcores} if $req_total < $MAX_CORES;
    }


    #  Determine whether it's better to distribute $MAX_CORES over @req_nodes
    #  nodes or reduce the number of cores to use from the $MAX_CORES value 
    #  to the total number of reqcores over the first N-1 nodes in @req_nodes.
    #  The complete unknown in this wag is  which option is more efficient,
    #  using $MAX_CORES cores over N nodes or using fewer cores over N-1 nodes.
    #
    #  Approach: Look at how close the value of $MAX_CORES is to fully populating
    #  the remaining nodes (@req_nodes). If the number of cores on the last node
    #  is greater than 50% the requested value, evenly spread out $MAX_CORES
    #  across all remaining nodes (@req_nodes). Otherwise, use the fully populated
    #  nodes (remove last node from @req_nodes) and reduce the value of totalcpus 
    #  below $MAX_CORES.
    #  
    my %nodes = ();
    my $over = $req_total-$MAX_CORES;
    my $lreq = $Process{nodes}{$req_nodes[-1]}{reqcores};

    if (@req_nodes==1 or $over/$lreq > 0.50) {
        foreach my $node (@req_nodes) {
            %{$nodes{$node}}        = %{$Process{nodes}{$node}};
            $nodes{$node}{usecores} = POSIX::floor($MAX_CORES/@req_nodes);  #  May fail if one node has fewer cores than the others
        }
    } else { #  Use all requested cores from N-1 @req_nodes nodes - totalcpus will be less than $MAX_CORES
       pop @req_nodes;
       foreach my $node (@req_nodes) { %{$nodes{$node}} = %{$Process{nodes}{$node}}; }
    }


    #  If a single node remains, we need to check whether it's the local host because
    #  that will determine if gforker of Hydra is to be used as the MPI process manager.
    #  
    if (@req_nodes==1 and $nodes{$req_nodes[0]}{localhost}) {
        @req_nodes = ('localhost');
        %{$nodes{localhost}} = %{$nodes{$req_nodes[0]}};
    }


    #  Complete the final assignments
    #
    $Process{totalcpus}    = sum map { $nodes{$_}{usecores} } @req_nodes;
    @{$Process{nodeorder}} = @req_nodes;

    %{$Process{nodes}}     = %nodes;


return %Process;
}



sub ReadBufrStationList {
# ==================================================================================
#  This subroutine reads the contends of a BUFR station file and returns a hash
#  containing the zero-blocked 6-digit station number (key) and associated station
#  ID (value).  
# ==================================================================================
#
    my %stns = ();

    my $stnlist = shift; return () unless $stnlist and -s $stnlist;

    #----------------------------------------------------------------------------------
    #  This is not the neatest solution, but we need information from the BUFR
    #  station list read in the previous subroutine. Unfortunately, that information
    #  is not passed out for reuse, so just reread the file.
    #----------------------------------------------------------------------------------
    #
    open my $ifh, '<', $stnlist;
    while (<$ifh>) {chomp $_; if (/(\d+)\s+\w+\.\w+\s+\w+\.\w+\s+([#|\w]{3,4})\s+/) {$stns{sprintf('%06d',$1)} = $2 if $1 and $2;}}
    close $ifh;


return %stns;
}



sub CheckBufrStationFile {
# ==================================================================================
#  This subroutine checks whether the requested station files exists in the 
#  static/ directory and if not, informs the user
# ==================================================================================
#

    my $stnlist = shift;

    #----------------------------------------------------------------------------------
    #  What station list are you using?  Ahhh, I thought so.  Make sure the file
    #  exists, and if not, use the UEMS default from the /data/tables/post/bufr
    #  directory and let the user know about the file change.
    #----------------------------------------------------------------------------------
    #
    unless (-s $stnlist) {

        my $stfile = &Others::popit($stnlist);

        $mesg = "Since I often play a superhero in my own mind (\"UEMS Dude\"), and therefore morally ".
                "obligated to come to the rescue of UEMS users in distress, I figuratively stand before ".
                "you today.\n\n".

                "Your distress is the consequence of not having a BUFR station file that matches the one ".
                "specified in post_bufr.conf:\n\n".

                "X02Xstatic/$stfile";

        &Ecomm::PrintMessage(6,14+$Upost{arf},92,2,1,'So What If I Like To Wear Tight Shorts And A Cape?',$mesg);

        if (system "cp -f $Upost{post}{bufr}{tables}/uemsbufr_stations.MASTER $stnlist > /dev/null 2>&1") {

            $mesg = "Even the ultimate superhero has his/her limits! Since I am unable to copy the default ".
                    "BUFR station file,\n\n".

                    "X02Xuems/data/tables/post/bufr/uemsbufr_stations.MASTER,\n\n".

                    "into your local static/ directory.\n\n".

                    "I'm afraid I must leave you to suffer the same fate as most of my other patients|victims|users. ".
                    "So until you resolve this situation, don't attempt any more BUFR stuff.";

            &Ecomm::PrintMessage(0,17+$Upost{arf},92,1,2,$mesg);
            return 0;
        }

        $mesg = "Since these shorts are cutting off my circulation, I'm going to resolve your predicament ".
                "as quickly as possible by copying the default station file into your local static/ directory ".
                "as \"$stfile\" and then continue as if nothing happened, which it didn't.";

        &Ecomm::PrintMessage(0,17+$Upost{arf},92,1,2,$mesg);

    }


return $stnlist;
}
   

sub GetDomainValue {
# ==================================================================================
#  This routine takes a domain ID ($d) and a comma separated list of values ($str)
#  wherein each value is associated with a specific domain. It returns the value
#  for that domain or last available value if missing data.
# ==================================================================================
#
    my ($d,$str) = @_; $str =~ s/,+/,/g;  #  Remove consecutive commas
   
    my @vals = split ',' => $str;

return $d > @vals ? $vals[-1] : $vals[$d-1];
}



sub Process2Summary {
#================================================================================
#  Provide the users a summary of the post processing to be completed.  Note that
#  neither netCDF-4 (HDF5) nor binary format is currently supported by the UEMS.
#  Hopefully someday this will change.
#================================================================================
#
    my @summary  = ();

    my $uref = shift;  my %Upost = %{$uref};

    foreach my $d (sort {$a <=> $b} keys  %{$Upost{post}{domains}}) {  #  For each domain requested

    foreach my $ftype (reverse sort keys %{$Upost{post}{domains}{$d}}) { #  For each data type requested (wrfout or auxhist)

        next unless $Upost{post}{domains}{$d}{$ftype}{proc};  #  If processing is necessary for $ftype (wrfout or auxhist)

        my @NetCDFs = @{$Upost{post}{domains}{$d}{$ftype}{netcdf}{newfiles}};
        my @NetCDFa = @{$Upost{post}{domains}{$d}{$ftype}{netcdf}{allfiles}};  #  Must reprocess all netcdf files each time

        my @Gribs   = ();
        my $name    = $ftype=~/auxhist/ ? 'auxiliary' : 'primary';
        my $n       = @NetCDFs;

        push @summary, sprintf("There are %s domain %s %s netCDF files available for processing:",$n,$d,$name);

        my @exports = (@NetCDFs and %{$Upost{post}{domains}{$d}{$ftype}{netcdf}{export}}) ? &ExportSummary('netcdf',\%{$Upost{post}{domains}{$d}{$ftype}{netcdf}{export}},\@NetCDFs) : (); 
        foreach (@exports) {push @summary, sprintf("\nX02X$_");}


        if (%{$Upost{post}{domains}{$d}{$ftype}{grib}}) {

            push @summary, sprintf ("\nX02XNetCDF to GRIB2 Processing:\n"); #  Needed for proper formatting

            @Gribs = sort &Outils::FrequencySubset($Upost{post}{domains}{$d}{$ftype}{grib}{freq},@NetCDFs);

            my ($freq,$sdate,$edate) = split /:/, $Upost{post}{domains}{$d}{$ftype}{grib}{freq}, 3;

            if (@Gribs) {
                $sdate = &Others::DateString2Pretty(&Others::popit($Gribs[0])); $sdate =~ s/^\w{3}\s//g; $sdate =~ s/\s+/ /g; $sdate =~ s/:\d\d / /;
                $edate = &Others::DateString2Pretty(&Others::popit($Gribs[-1]));$edate =~ s/^\w{3}\s//g; $edate =~ s/\s+/ /g; $edate =~ s/:\d\d / /;
            }

            @Gribs ? @Gribs == 1 ? push @summary, sprintf("X04XX01X\xe2\x9c\x93  Process a single measly netCDF file to GRIB2 for $sdate") 
                                 : push @summary, sprintf("X04XX01X\xe2\x9c\x93  Process netCDF to GRIB2 every $freq minutes between $sdate  &  $edate")
                                 : push @summary, sprintf("X04XX01X\xe2\x9c\x93  Do nothing, since your GRIB2 processing frequency has left me without any netCDF files!");

            my @exports = (@Gribs and %{$Upost{post}{domains}{$d}{$ftype}{grib}{export}}) ? &ExportSummary('grib2',\%{$Upost{post}{domains}{$d}{$ftype}{grib}{export}},\@Gribs) : ();
            foreach (@exports) {push @summary, sprintf("X04XX01X$_");}
        }



        if (%{$Upost{post}{domains}{$d}{$ftype}{grads}}) {

            push @summary, sprintf ("\nX02XGRIB2 to GrADS Processing:\n"); #  Needed for proper formatting

            my @Grads = sort &Outils::FrequencySubset($Upost{post}{domains}{$d}{$ftype}{grads}{freq},@Gribs);

            my ($freq,$sdate,$edate) = split /:/, $Upost{post}{domains}{$d}{$ftype}{grads}{freq}, 3;

            if (@Grads) {
                $sdate = &Others::DateString2Pretty(&Others::popit($Grads[0])); $sdate =~ s/^\w{3}\s//g; $sdate =~ s/\s+/ /g; $sdate =~ s/:\d\d / /;
                $edate = &Others::DateString2Pretty(&Others::popit($Grads[-1]));$edate =~ s/^\w{3}\s//g; $edate =~ s/\s+/ /g; $edate =~ s/:\d\d / /;
            }

            @Grads ? @Grads == 1 ? push @summary, sprintf("X04XX01X\xe2\x9c\x93  Process a single measly GRIB2 file to GrADS for $sdate")
                                 : push @summary, sprintf("X04XX01X\xe2\x9c\x93  Process GRIB2 to GrADS every $freq minutes between $sdate  &  $edate")
                                 : push @summary, sprintf("X04XX01X\xe2\x9c\x93  Do nothing, since your processing frequency has left me without any GRIB2 files!");

            my @exports = (@Grads and %{$Upost{post}{domains}{$d}{$ftype}{grads}{export}}) ? &ExportSummary('grads',\%{$Upost{post}{domains}{$d}{$ftype}{grads}{export}},\@Grads) : ();
            foreach (@exports) {push @summary, sprintf("X04XX01X$_");}
        }



        if (%{$Upost{post}{domains}{$d}{$ftype}{gempak}}) {

            push @summary, sprintf ("\nX02XGRIB2 to GEMPAK Processing:\n");

            my @Gempaks = sort &Outils::FrequencySubset($Upost{post}{domains}{$d}{$ftype}{gempak}{freq},@Gribs);

            my ($freq,$sdate,$edate) = split /:/, $Upost{post}{domains}{$d}{$ftype}{gempak}{freq}, 3;

            if (@Gempaks) {
                $sdate = &Others::DateString2Pretty(&Others::popit($Gempaks[0])); $sdate =~ s/^\w{3}\s//g; $sdate =~ s/\s+/ /g; $sdate =~ s/:\d\d / /;
                $edate = &Others::DateString2Pretty(&Others::popit($Gempaks[-1]));$edate =~ s/^\w{3}\s//g; $edate =~ s/\s+/ /g; $edate =~ s/:\d\d / /;
            }

            @Gempaks ? @Gempaks == 1 ? push @summary, sprintf("X04XX01X\xe2\x9c\x93  Process a single measly GRIB2 file to GEMPAK for $sdate")
                                     : push @summary, sprintf("X04XX01X\xe2\x9c\x93  Process GRIB2 to GEMPAK every $freq minutes between $sdate  &  $edate")
                                     : push @summary, sprintf("X04XX01X\xe2\x9c\x93  Do nothing, since your processing frequency has left me without any GRIB2 files!");

            my @exports = (@Gempaks and %{$Upost{post}{domains}{$d}{$ftype}{gempak}{export}}) ? &ExportSummary('gempak',\%{$Upost{post}{domains}{$d}{$ftype}{gempak}{export}},\@Gempaks) : ();
            foreach (@exports) {push @summary, sprintf("X04XX01X$_");}
        }


        if ($Upost{post}{domains}{$d}{$ftype}{bufr} and %{$Upost{post}{domains}{$d}{$ftype}{bufr}}) {  #  Not defined if $ftype = auxhist

            push @summary, sprintf ("\nX02XNetCDF to BUFR Processing:\n");

            my @Bufrs = sort &Outils::FrequencySubset($Upost{post}{domains}{$d}{$ftype}{bufr}{freq},@NetCDFs);

            my ($freq,$sdate,$edate) = split /:/, $Upost{post}{domains}{$d}{$ftype}{bufr}{freq}, 3;

            if (@Bufrs) {
                $sdate = &Others::DateString2Pretty(&Others::popit($Bufrs[0])); $sdate =~ s/^\w{3}\s//g; $sdate =~ s/\s+/ /g; $sdate =~ s/:\d\d / /;
                $edate = &Others::DateString2Pretty(&Others::popit($Bufrs[-1]));$edate =~ s/^\w{3}\s//g; $edate =~ s/\s+/ /g; $edate =~ s/:\d\d / /;
            }

            @Bufrs ? @Bufrs == 1 ? push @summary, sprintf("X04XX01X\xe2\x9c\x93  Process a single measly netCDF file to BUFR for $sdate")
                                 : push @summary, sprintf("X04XX01X\xe2\x9c\x93  Process netCDF to BUFR every $freq minutes between $sdate  &  $edate")
                                 : push @summary, sprintf("X04XX01X\xe2\x9c\x93  Do nothing, since your BUFR processing frequency has left me without any netCDF files!");

            my @exports = (@Bufrs and %{$Upost{post}{domains}{$d}{$ftype}{bufr}{export}}) ? &ExportSummary('bufr',\%{$Upost{post}{domains}{$d}{$ftype}{bufr}{export}},\@Bufrs) : ();
            foreach (@exports) {push @summary, sprintf("X04XX01X$_");}


            if (@Bufrs and %{$Upost{post}{domains}{$d}{$ftype}{bufkit}}) {
                push @summary, sprintf("\nX04XX01X\xe2\x9c\x93  Write all BUFR files to BUFKIT format - Because this party train never stops");
                my @exports = (@Bufrs and %{$Upost{post}{domains}{$d}{$ftype}{bufkit}{export}}) ? &ExportSummary('bufkit',\%{$Upost{post}{domains}{$d}{$ftype}{bufkit}{export}},\@Bufrs) : ();
                foreach (@exports) {push @summary, sprintf("X04XX01X$_");}
            }

            if (@Bufrs and %{$Upost{post}{domains}{$d}{$ftype}{gemsnd}}) {
                push @summary, sprintf("\nX04XX01X\xe2\x9c\x93  Process all BUFR files to GEMPAK sounding files");
                my @exports = (@Bufrs and %{$Upost{post}{domains}{$d}{$ftype}{gemsnd}{export}}) ? &ExportSummary('gemsnd',\%{$Upost{post}{domains}{$d}{$ftype}{gemsnd}{export}},\@Bufrs) : ();
                foreach (@exports) {push @summary, sprintf("X04XX01X$_");}
            }

            if (@Bufrs and %{$Upost{post}{domains}{$d}{$ftype}{ascisnd}}) {
                push @summary, sprintf("\nX04XX01X\xe2\x9c\x93  Process all BUFR files to GEMPAK sounding files");
                my @exports = (@Bufrs and %{$Upost{post}{domains}{$d}{$ftype}{ascisnd}{export}}) ? &ExportSummary('ascisnd',\%{$Upost{post}{domains}{$d}{$ftype}{ascisnd}{export}},\@Bufrs) : ();
                foreach (@exports) {push @summary, sprintf("X04XX01X$_");}
            }
        }

    } #  For each data type
    } #  For each domain


return join "\n", @summary;
}



sub ExportSummary {
#================================================================================
#  Not enough time to explain
#================================================================================
#
    my @exports=();

    my $type = shift;  $type = uc $type;
    my $eref = shift;  my %Exports = %{$eref};
    my $nref = shift;  my @Efiles  = @{$nref};

    foreach my $e (sort {$a <=> $b} keys %Exports) {

        my ($freq,$sdate,$edate) = split /:/, $Exports{$e}{freq};
        my @enets = sort &Outils::FrequencySubset($Exports{$e}{freq},@Efiles);

        if (@enets) {
            $sdate = &Others::DateString2Pretty(&Others::popit($enets[0])); $sdate =~ s/^\w{3}\s//g; $sdate =~ s/\s+/ /g; $sdate =~ s/:\d\d / /;
            $edate = &Others::DateString2Pretty(&Others::popit($enets[-1]));$edate =~ s/^\w{3}\s//g; $edate =~ s/\s+/ /g; $edate =~ s/:\d\d / /;
        }
        my $n = @enets; $n = 0 if grep {/$type/} ('BUFR','BUFKIT','GEMSND','ASCISND');
           $n = $n ? " ($n)" : '';

        @enets ? @enets == 1 ? push @exports, sprintf("\xe2\x9c\x93  Export one lousy $type to %s on %s via %s - $sdate",$Exports{$e}{rdir},$Exports{$e}{host},uc $Exports{$e}{meth})
                             : push @exports, sprintf("\xe2\x9c\x93  Export $type files$n to %s on %s via %s ($freq minute frequency)",$Exports{$e}{rdir},$Exports{$e}{host},uc $Exports{$e}{meth})
                             : push @exports, sprintf("\xe2\x9c\x93  Do nothing, since your export frequency has left me without any $type files!");

    }


return @exports;
}



   
