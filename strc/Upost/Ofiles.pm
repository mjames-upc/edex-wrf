#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Ofiles.pm
#
#  DESCRIPTION:  Files contains the primary routines used for the initial checks
#                of ems_post parameters read from the configuration files. Each
#                parameter is handled individually.
#
#                Some sausage making
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Ofiles;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Upost);


sub PostFileConfiguration {
# ==============================================================================================
# UEMS POST LOCAL CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Collect the few dozen configuration settings under the local conf/ems_post directory, 
#  which are returned in a hash containing PARAMETER = @{VALUES}. Checks are made to ensure 
#  the values are valid.  Note that the individual subroutines are not necessary but serve
#  to organize the parameters and break up the monotony, although I have yet to include them.
#  So long live monotony!
#
# ==============================================================================================
# ==============================================================================================
#
use List::Util 'sum';
use Enet;

    my $fdbg  = 0;  #  For local debugging

    my $upref = shift; %Upost = %{$upref};


    #----------------------------------------------------------------------------------
    #  Read the local configuration files, which are returned in the %Files hash.
    #----------------------------------------------------------------------------------
    #
    return () unless defined $Upost{rtenv}{postconf} and -d $Upost{rtenv}{postconf};
    return () unless my %Files = &Others::ReadLocalConfiguration($Upost{rtenv}{postconf}); 


    #----------------------------------------------------------------------------------
    #  Now begin the process of checking the parameters for valid values. Each 
    #  parameter is checked for validity but are not crossed-checked with other
    #  parameters, which is done prior to the values being used. 
    #----------------------------------------------------------------------------------
    #
    my $run   = int ($Upost{rtenv}{length}/60);
    my $cval  = qw{}; #  Config Value
    my $dval  = qw{};
    my @rvals = ();
    my @cvals = ();

    my %penv  = %{$Upost{rtenv}};


    #============================================================================
    #  POST_UEMS: GRIB (Y|N) MAX DOMAINS - 1|0 are the desired output values
    #============================================================================
    #
    @cvals = (defined $Files{GRIB} and @{$Files{GRIB}}) ?  @{$Files{GRIB}} : (1);

    $cvals[0] = &SetValues_OnOff($cvals[0],1,1); #  Ensure $cvals[0] is properly set

    foreach (@cvals) {$_ = &SetValues_OnOff($_,$cvals[0],1);}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{GRIB}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_UEMS: GEMPAK (Y|N) MAX DOMAINS - 1|0 are the desired output values
    #============================================================================
    #
    @cvals = (defined $Files{GEMPAK} and @{$Files{GEMPAK}}) ?  @{$Files{GEMPAK}} : (0);

    $cvals[0] = &SetValues_OnOff($cvals[0],0,1); #  Ensure $cvals[0] is properly set

    foreach (@cvals) {$_ = &SetValues_OnOff($_,$cvals[0],1);}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{GEMPAK}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_UEMS: GRADS (Y|N) MAX DOMAINS - 1|0 are the desired output values
    #============================================================================
    #
    @cvals = (defined $Files{GRADS} and @{$Files{GRADS}}) ?  @{$Files{GRADS}} : (0);

    $cvals[0] = &SetValues_OnOff($cvals[0],0,1); #  Ensure $cvals[0] is properly set

    foreach (@cvals) {$_ = &SetValues_OnOff($_,$cvals[0],1);}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{GRADS}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_UEMS: BUFR (Y|N) MAX DOMAINS - 1|0 are the desired output values
    #============================================================================
    #
    @cvals = (defined $Files{BUFR} and @{$Files{BUFR}}) ?  @{$Files{BUFR}} : (0);

    $cvals[0] = &SetValues_OnOff($cvals[0],0,1); #  Ensure $cvals[0] is properly set

    foreach (@cvals) {$_ = &SetValues_OnOff($_,$cvals[0],1);}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{BUFR}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_GRIB: FREQ_WRF_GRIB (Integer)  MAX DOMAINS 
    #============================================================================
    #
    @cvals = (defined $Files{FREQ_WRF_GRIB} and @{$Files{FREQ_WRF_GRIB}}) ?  @{$Files{FREQ_WRF_GRIB}} : (1);

    foreach (@cvals) {$_ = &FreqStartStop($_);}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{FREQ_WRF_GRIB}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_GRIB: FREQ_AUX_GRIB (Integer)  MAX DOMAINS 
    #============================================================================
    #
    @cvals = (defined $Files{FREQ_AUX_GRIB} and @{$Files{FREQ_AUX_GRIB}}) ?  @{$Files{FREQ_AUX_GRIB}} : (1);

    foreach (@cvals) {$_ = &FreqStartStop($_);}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{FREQ_AUX_GRIB}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_GRIB: ACCUM_PERIOD_WRF (Integer)  MAX DOMAINS 
    #============================================================================
    #
    @cvals = (defined $Files{ACCUM_PERIOD_WRF} and @{$Files{ACCUM_PERIOD_WRF}}) ?  @{$Files{ACCUM_PERIOD_WRF}} : (1);

    foreach (@cvals) {$_ = $run if /^r|^s|^f/i; $_ = 1 unless &Others::isInteger($_); $_ = 1 unless $_ > 0; $_ = $run if $_ > $run}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{ACCUM_PERIOD_WRF}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_GRIB: ACCUM_PERIOD_AUX (Integer)  MAX DOMAINS 
    #============================================================================
    #
    @cvals = (defined $Files{ACCUM_PERIOD_AUX} and @{$Files{ACCUM_PERIOD_AUX}}) ?  @{$Files{ACCUM_PERIOD_AUX}} : (1);

    foreach (@cvals) {$_ = $run if /^r|^s|^f/i; $_ = 1 unless &Others::isInteger($_); $_ = 1 unless $_ > 0; $_ = $run if $_ > $run}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{ACCUM_PERIOD_AUX}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_GRIB: GRIB_CNTRL_WRF (string value)
    #============================================================================
    #
    $dval   = 'emsupp_cntrl.parm'; system "cp -f $penv{tables}{grib}/emsupp_cntrl.MASTER $penv{static}/$dval > /dev/null 2>&1" unless -s "$penv{static}/$dval";
    @cvals  = (defined $Files{GRIB_CNTRL_WRF}[0] and length $Files{GRIB_CNTRL_WRF}[0]) ? @{$Files{GRIB_CNTRL_WRF}}  : ($dval);

    #  Don't check whether file exists until the final configuration routine since it has not been 
    #  determined whether GRIB 2 files will be created in which case the control files are not needed.
    #
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    foreach (@rvals) {$_ = "$penv{static}/$_";}

    @{$Files{GRIB_CNTRL_WRF}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_GRIB: GRIB_CNTRL_AUX (string value)
    #============================================================================
    #
    $dval   = 'emsupp_auxcntrl.parm'; system "cp -f $penv{tables}{grib}/emsupp_auxcntrl.MASTER $penv{static}/$dval > /dev/null 2>&1" unless -s "$penv{static}/$dval";
    @cvals  = (defined $Files{GRIB_CNTRL_AUX}[0] and length $Files{GRIB_CNTRL_AUX}[0]) ? @{$Files{GRIB_CNTRL_AUX}}  : ($dval);

    #  Don't check whether file exists until the final configuration routine since it has not been 
    #  determined whether GRIB 2 files will be created in which case the control files are not needed.
    #
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    foreach (@rvals) {$_ = "$penv{static}/$_";}

    @{$Files{GRIB_CNTRL_AUX}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_GRIB: EMSUPP_NODECPUS (UEMS; string)
    #============================================================================
    #
    my $local = 'local';

    @rvals  = ();
    @cvals  = defined  $Files{EMSUPP_NODECPUS}[0] ? @{$Files{EMSUPP_NODECPUS}} : ($local);
    @cvals  = ($local) unless $Files{EMSUPP_NODECPUS}[0];

    foreach (@cvals) {

        my $host = 'local';
        my $core = 'NCPUS';

        foreach my $val (split ':' => $_) {
            $host = $val     if &Enet::isHostname($val);
            $core = int $val if &Others::isNumber($val);
        }
        next unless $core;

        push @rvals => "${host}:${core}";
    }
    @{$Files{EMSUPP_NODECPUS}} = @rvals ? @rvals : ($local);


    #============================================================================
    #  POST_GRIB: MDLID (110 > integer < 255) (Max Domains)
    #============================================================================
    #
    $dval  = 116;
    @cvals = (defined $Files{MDLID} and @{$Files{MDLID}}) ?  @{$Files{MDLID}} : ($dval);

    foreach (@cvals) {$_ = $cvals[0] unless $_ and $_ =~ /^\d+$/ and $_ > 110 and $_ < 255;}

    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{MDLID}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_GRIB: OCNTR (0 > integer < 255 but 7 should be used) (Max Domains)
    #============================================================================
    #
    $dval  = 7;
    @cvals = (defined $Files{OCNTR} and @{$Files{OCNTR}}) ?  @{$Files{OCNTR}} : ($dval);

    foreach (@cvals) {$_ = $cvals[0] unless $_ and $_ =~ /^\d+$/ and $_ > 0 and $_ < 255;}

    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{OCNTR}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_GRIB: SCNTR (20+domain number) (Max Domains)
    #============================================================================
    #
    $dval  = 20;
    @cvals = (defined $Files{SCNTR} and @{$Files{SCNTR}}) ?  @{$Files{SCNTR}} : ($dval);

    foreach (@cvals) {$_ = $dval unless $_ and $_ =~ /^\d+$/ and $_ > 19 and $_ < 255;}

    @rvals = ($dval) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{SCNTR}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_GRIB: FILENAME_GRIB (string value; default: YYMMDDHHMN_KEY_CORE_dWD.grb2fFXFMFS)
    #============================================================================
    #
    $dval  = 'YYMMDDHHMN_KEY_CORE_dWD.grb2fFXFMFS';
    $cval  = (defined $Files{FILENAME_GRIB}[0] and length $Files{FILENAME_GRIB}[0]) ? $Files{FILENAME_GRIB}[0] : $dval;

    @{$Files{FILENAME_GRIB}} = ($cval);



    #============================================================================
    #  POST_GRIB: MPICHECK (1|0)
    #============================================================================
    #
    $cval  = (defined $Files{MPICHECK} and $Files{MPICHECK}[0]) ?  1 : 0;
    @{$Files{MPICHECK}}      = ($cval);



    #============================================================================
    #  POST_BUFR: FREQ_WRF_BUFR (Integer)  MAX DOMAINS 
    #============================================================================
    #
    @cvals = (defined $Files{FREQ_WRF_BUFR} and @{$Files{FREQ_WRF_BUFR}}) ?  @{$Files{FREQ_WRF_BUFR}} : (1);

    foreach (@cvals) {$_ = &FreqStartStop($_);}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{FREQ_WRF_BUFR}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_BUFR: FILENAME_BUFR (string value; default: emsbufr_CORE_dWD)
    #============================================================================
    #
    $dval  = 'emsbufr_CORE_dWD';
    $cval  = (defined $Files{FILENAME_BUFR}[0] and length $Files{FILENAME_BUFR}[0]) ? $Files{FILENAME_BUFR}[0] : $dval;

    @{$Files{FILENAME_BUFR}} = ($cval);



    #============================================================================
    #  POST_BUFR: STATION_LIST (string value; max domains)
    #============================================================================
    #
    $dval   = 'emsbufr_stations_d01.txt'; system "cp -f $penv{tables}{bufr}/uemsbufr_stations.MASTER $penv{static}/$dval > /dev/null 2>&1" unless -s "$penv{static}/$dval";
    @cvals  = (defined $Files{STATION_LIST}[0] and length $Files{STATION_LIST}[0]) ? @{$Files{STATION_LIST}}  : ($dval);

    #  Don't check whether file exists until the final configuration routine since it has not been 
    #  determined whether GRIB 2 files will be created in which case the control files are not needed.
    #
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    foreach (@rvals) {$_ = "$penv{static}/$_";}

    @{$Files{STATION_LIST}} = @rvals[0..$Upost{maxindex}];




    #============================================================================
    #  POST_BUFR: BUFR_INFO (Y|N) MAX DOMAINS - 1|0 are the desired output values
    #============================================================================
    #
    @cvals = (defined $Files{BUFR_INFO} and @{$Files{BUFR_INFO}}) ?  @{$Files{BUFR_INFO}} : (0);

    $cvals[0] = &SetValues_OnOff($cvals[0],0,1); #  Ensure $cvals[0] is properly set

    foreach (@cvals) {$_ = &SetValues_OnOff($_,$cvals[0],1);}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{BUFR_INFO}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_BUFR: BUFKIT (Y|N) MAX DOMAINS - 1|0 are the desired output values
    #============================================================================
    #
    @cvals = (defined $Files{BUFKIT} and @{$Files{BUFKIT}}) ?  @{$Files{BUFKIT}} : (0);

    $cvals[0] = &SetValues_OnOff($cvals[0],0,1); #  Ensure $cvals[0] is properly set

    foreach (@cvals) {$_ = &SetValues_OnOff($_,$cvals[0],1);}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{BUFKIT}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_BUFR: APPEND_DATE (Y|N) MAX DOMAINS - 1|0 are the desired output values
    #============================================================================
    #
    @cvals = (defined $Files{APPEND_DATE} and @{$Files{APPEND_DATE}}) ?  @{$Files{APPEND_DATE}} : (1);

    $cvals[0] = &SetValues_OnOff($cvals[0],1,1); #  Ensure $cvals[0] is properly set

    foreach (@cvals) {$_ = &SetValues_OnOff($_,$cvals[0],1);}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{APPEND_DATE}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_BUFR: BUFR_STYLE (1|2) MAX DOMAINS
    #============================================================================
    #
    @cvals = (defined $Files{BUFR_STYLE} and @{$Files{BUFR_STYLE}}) ?  @{$Files{BUFR_STYLE}} : (1);

    foreach (@cvals) {$_ = 1 unless &Others::isInteger($_) and $_ == 2;}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{BUFR_STYLE}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_BUFR: ZIPIT (Y|N) MAX DOMAINS - 1|0 are the desired output values
    #============================================================================
    #
    @cvals = (defined $Files{ZIPIT} and @{$Files{ZIPIT}}) ?  @{$Files{ZIPIT}} : (0);

    $cvals[0] = &SetValues_OnOff($cvals[0],0,1); #  Ensure $cvals[0] is properly set

    foreach (@cvals) {$_ = &SetValues_OnOff($_,$cvals[0],1);}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{ZIPIT}} = @rvals[0..$Upost{maxindex}];




    #============================================================================
    #  POST_BUFR: GEMSND (Y|N) MAX DOMAINS - 1|0 are the desired output values
    #============================================================================
    #
    @cvals = (defined $Files{GEMSND} and @{$Files{GEMSND}}) ?  @{$Files{GEMSND}} : (0);

    $cvals[0] = &SetValues_OnOff($cvals[0],0,1); #  Ensure $cvals[0] is properly set

    foreach (@cvals) {$_ = &SetValues_OnOff($_,$cvals[0],1);}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{GEMSND}} = @rvals[0..$Upost{maxindex}];

    foreach (0..$Upost{maxindex}) {$Files{GEMSND}[$_] = 1 if $Files{BUFKIT}[$_];}



    #============================================================================
    #  POST_BUFR: ASCISND (Y|N) MAX DOMAINS - 1|0 are the desired output values
    #============================================================================
    #
    @cvals = (defined $Files{ASCISND} and @{$Files{ASCISND}}) ?  @{$Files{ASCISND}} : (0);

    $cvals[0] = &SetValues_OnOff($cvals[0],0,1); #  Ensure $cvals[0] is properly set

    foreach (@cvals) {$_ = &SetValues_OnOff($_,$cvals[0],1);}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{ASCISND}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_GEMPAK: FREQ_WRF_GEMPAK (Integer)  MAX DOMAINS 
    #============================================================================
    #
    @cvals = (defined $Files{FREQ_WRF_GEMPAK} and @{$Files{FREQ_WRF_GEMPAK}}) ?  @{$Files{FREQ_WRF_GEMPAK}} : (1);

    foreach (@cvals) {$_ = &FreqStartStop($_);}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{FREQ_WRF_GEMPAK}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_GEMPAK: FREQ_AUX_GEMPAK (Integer)  MAX DOMAINS 
    #============================================================================
    #
    @cvals = (defined $Files{FREQ_AUX_GEMPAK} and @{$Files{FREQ_AUX_GEMPAK}}) ?  @{$Files{FREQ_AUX_GEMPAK}} : (1);

    foreach (@cvals) {$_ = &FreqStartStop($_);}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{FREQ_AUX_GEMPAK}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_GEMPAK: MONOFILE_GEMPAK (Y|N) MAX DOMAINS - 1|0 are the desired output values
    #============================================================================
    #
    @cvals = (defined $Files{MONOFILE_GEMPAK} and @{$Files{MONOFILE_GEMPAK}}) ?  @{$Files{MONOFILE_GEMPAK}} : (1);

    $cvals[0] = &SetValues_OnOff($cvals[0],1,1); #  Ensure $cvals[0] is properly set

    foreach (@cvals) {$_ = &SetValues_OnOff($_,$cvals[0],1);}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{MONOFILE_GEMPAK}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_GEMPAK: FILENAME_GEMPAK (string value; default: YYYYMMDDHHMN_CORE_KEY_dWD.gem)
    #============================================================================
    #
    $dval  = 'YYYYMMDDHHMN_CORE_KEY_dWD.gem';
    $cval  = (defined $Files{FILENAME_GEMPAK}[0] and length $Files{FILENAME_GEMPAK}[0]) ? $Files{FILENAME_GEMPAK}[0] : $dval;

    @{$Files{FILENAME_GEMPAK}} = ($cval);



    #============================================================================
    #  POST_GEMPAK: POSTSCR_AUX_GEMPAK  (string value - Path to script)
    #============================================================================
    #
    @cvals  = (defined $Files{POSTSCR_AUX_GEMPAK}[0] and length $Files{POSTSCR_AUX_GEMPAK}[0]) ? ($Files{POSTSCR_AUX_GEMPAK}[0]) : ();

    @{$Files{POSTSCR_AUX_GEMPAK}} = @cvals;



    #============================================================================
    #  POST_GEMPAK: POSTSCR_WRF_GEMPAK (string value - Path to script)
    #============================================================================
    #
    @cvals  = (defined $Files{POSTSCR_WRF_GEMPAK}[0] and length $Files{POSTSCR_WRF_GEMPAK}[0]) ? ($Files{POSTSCR_WRF_GEMPAK}[0]) : ();

    @{$Files{POSTSCR_WRF_GEMPAK}} = @cvals;



    #============================================================================
    #  POST_GRADS: FREQ_WRF_GRADS (Integer)  MAX DOMAINS 
    #============================================================================
    #
    @cvals = (defined $Files{FREQ_WRF_GRADS} and @{$Files{FREQ_WRF_GRADS}}) ?  @{$Files{FREQ_WRF_GRADS}} : (1);

    foreach (@cvals) {$_ = &FreqStartStop($_);}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{FREQ_WRF_GRADS}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_GRADS: FREQ_AUX_GRADS (Integer)  MAX DOMAINS 
    #============================================================================
    #
    @cvals = (defined $Files{FREQ_AUX_GRADS} and @{$Files{FREQ_AUX_GRADS}}) ?  @{$Files{FREQ_AUX_GRADS}} : (1);

    foreach (@cvals) {$_ = &FreqStartStop($_);}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{FREQ_AUX_GRADS}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_GRADS: MONOFILE_GRADS (Y|N) MAX DOMAINS - 1|0 are the desired output values
    #============================================================================
    #
    @cvals = (defined $Files{MONOFILE_GRADS} and @{$Files{MONOFILE_GRADS}}) ?  @{$Files{MONOFILE_GRADS}} : (1);

    $cvals[0] = &SetValues_OnOff($cvals[0],1,1); #  Ensure $cvals[0] is properly set

    foreach (@cvals) {$_ = &SetValues_OnOff($_,$cvals[0],1);}
    @rvals = ($cvals[-1]) x $Upost{maxdoms};  # @rvals set to last value
    splice @rvals, 0, @cvals, @cvals;

    @{$Files{MONOFILE_GRADS}} = @rvals[0..$Upost{maxindex}];



    #============================================================================
    #  POST_GRADS: FILENAME_GRADS (string value - Path to script)
    #============================================================================
    #
    $dval  = 'YYYYMMDDHHMN_CORE_KEY_dWD.gem';
    $cval  = (defined $Files{FILENAME_GRADS}[0] and length $Files{FILENAME_GRADS}[0]) ? $Files{FILENAME_GRADS}[0] : $dval; 

    @{$Files{FILENAME_GRADS}} = ($cval);



    #============================================================================
    #  POST_GRADS: POSTSCR_AUX_GRADS (string value - Path to script)
    #============================================================================
    #
    @cvals  = (defined $Files{POSTSCR_AUX_GRADS}[0] and length $Files{POSTSCR_AUX_GRADS}[0]) ? ($Files{POSTSCR_AUX_GRADS}[0]) : ();

    @{$Files{POSTSCR_AUX_GRADS}} = @cvals;



    #============================================================================
    #  POST_GRADS: POSTSCR_WRF_GRADS (string value; default: YYYYMMDDHHMN_CORE_KEY_dWD.gem)
    #============================================================================
    #
    @cvals  = (defined $Files{POSTSCR_WRF_GRADS}[0] and length $Files{POSTSCR_WRF_GRADS}[0]) ? ($Files{POSTSCR_WRF_GRADS}[0]) : ();

    @{$Files{POSTSCR_WRF_GRADS}} = @cvals;



    #============================================================================
    #  POST_EXPORT: EXPORT (Pipe (|) separated string values
    #============================================================================
    #
    @cvals  = (defined $Files{EXPORT}[0] and length $Files{EXPORT}[0]) ? @{$Files{EXPORT}} : ();
    @{$Files{EXPORT}} = @cvals;


  
    #============================================================================
    #  Just some developer debug statements
    #============================================================================
    #
    if ($fdbg) {
        my %temp = &Others::ReadLocalConfiguration($Upost{rtenv}{postconf});
        &Ecomm::PrintMessage(0,14+$Upost{arf},255,1,0,'Parameter              Conf File                               UEMS');
        &Ecomm::PrintMessage(0,9+$Upost{arf},255,1,1,'-' x 82);
        foreach my $key (sort keys %temp) { 
            my $stemp  = @{$temp{$key}}  ? join ',' => @{$temp{$key}}  : ' '; chomp $stemp;
            my $sfiles = @{$Files{$key}} ? join ',' => @{$Files{$key}} : ' '; chomp $sfiles;
            my $str = sprintf("%-16s    =  %-36s :  %-36s", $key,$stemp,$sfiles); 
            &Ecomm::PrintMessage(4,11+$Upost{arf},255,0,1,$str);
        }
        &Ecomm::PrintMessage(0,9+$Upost{arf},255,0,2,'-' x 82);
    }
    #============================================================================



return %Files;
}  #  &FileConfiguration 



sub SetValues_OnOff {
#==================================================================================
#  Routine set the incoming valiable ($var) to a single ON (1) or OFF (0) 
#  value. Support for T|Fs & Y|Ns is provided for legacy reasons. It return an
#  array populated with $nvars values.
#==================================================================================
#
    my ($var, $def, $nvars) = @_;  $nvars = 1 unless $nvars;

    &Ecomm::PrintMessage(6,11+$Upost{arf},94,1,1,"Warning: Default value ($def) must be 0|1 in &SetValues_OnOff") unless grep {/^$def$/} (0,1);

    for ($var) {
        $_ = 0 if /^0/ or /^F/i or /^N/i;
        $_ = 1 if /^1/ or /^T/i or /^Y/i;
        $_ = $def unless $_ == 1 or $_ == 0;
    }

    

return ($var) x $nvars;
}


sub FreqStartStop {
#==================================================================================
#  Routine to ensure proper formatting of the FREQ:START:STOP string used by
#  various parameters.
#==================================================================================
#
    my $passed = shift;  return '' unless defined $passed and length $passed;


    #  Any arguments passed are applied to the FREQUENCY_ parameters located
    #  in the post_grib.conf file. Easiest just to set them both to the same
    #  values.  The format of the argument is FREQ:START:STOP but we need to
    #  account for the use of commas (,) and semicolons (;) as separators. 
    #  Here the "@tmp" list is used to catch any extraneous values.
    #
    my $form = '';

    $passed =~ s/:|,|;|"|'/:/g;  #  Replace Separators with ":"
    $passed =~ s/[^\d|\:]//g;

    my ($freq,$start,$stop,@tmp) = split /:/ => $passed;

    $freq = 1 unless $freq;
    $stop = 0 unless $stop;
    $start= 0 unless $start;

    $stop = 0  if ($stop  =~ /^\D/i or $stop  < 1 or $stop < $start);
    $start= 0  if ($start =~ /^\D/i or $start < 1 or ($stop and $start > $stop) );
    $freq = 1  if ($freq  =~ /^\D/i or $freq <= 1);

    $freq = 'Auto' if $freq == 1;  #  Need to avoid confusion

    $stop = '' unless $stop;
    $start= '' unless $start;
    my $st= ($start and $stop) ? "$start:$stop" : $start ? $start : $stop ? ":$stop" : '';

    $form = $st ? "$freq:$st" : $freq;


return $form;
}


