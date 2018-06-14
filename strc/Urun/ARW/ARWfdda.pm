#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ARWfdda.pm
#
#  DESCRIPTION:  This module handles the configuration of the FDDA namelist 
#                options for the ARW core. 
#
#   WHAT THE WRF
#   GUIDE SAYS:  About the Grid Nudging Option
#
#                This option nudges the WRF run towards a gridded analysis linearly
#                interpolated in time between specified analyses. It only requires 
#                multiple time periods of analyses for each domain to be nudged, and 
#                these are input to real in the same format as the initial conditions.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package ARWfdda;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Rconf %Config %ARWconf %FDDA);

use Others;


sub Configure {
# ==============================================================================================
# &FDDA NAMELIST CONFIGURATION DIVER
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Each subroutine controls the configuration for the somewhat crudely organized namelist
#  variables. Should there be a serious problem an empty hash is returned (not really).
#  Not all namelist variables are configured as some do not require anything beyond the
#  default settings. The %FDDA hash is only used within this module to reduce the
#  number of characters being cut-n-pasted.
#
# ==============================================================================================
# ==============================================================================================
#   
    %FDDA = ();

    %Config = %ARWconfig::Config;
    %Rconf  = %ARWconfig::Rconf;

    my $href = shift; %ARWconf = %{$href};

    return () if &FDDA_Control();
    return () if &FDDA_Debug();

    %{$ARWconf{namelist}{fdda}} = %FDDA;


return %ARWconf;
}


sub FDDA_Control {
# ==============================================================================================
# WRF PRIMARY IO &FDDA NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   For most users - Nothing, Nada, Bupkis, Zilch
#
#   This file is used for the configuration 3D Analysis or Spectral Nudging as
#   part of a WRF simulation. Nudging can be useful for some types of retro-
#   spective simulations and regional climatology studies by reducing the
#   amount of forecast "drift" or error during model integration.
#
#   For studies that involve the dissection of model forcing it is recommended
#   that nudging NOT be applied to any domains directly involved in the
#   analysis. For example, if you are running a simulation with 2 nested sub-
#   domains and plan on using only the inner-most nest in the research, then
#   turn OFF nudging for that domain. This is because the inclusion of nudging
#   introduces additional (non-physical) forcing into the model atmosphere
#   that you would have to explain, and you really don't want to go there.
#
#   If you are running a nested simulation with 3D nudging, then you should
#   also consider turning 2-way feedback OFF in run_nests.conf (FEEDBACK = 0).
#
#   Note that nudging will not be used in the simulation unless either the
#   "--nudge" flag is passed to ems_run or the NUDGING parameter is set
#   in ems_autorun.conf; otherwise, the contents of this file will be ignored.
#
#   Also important: If nudging is requested the default behavior is to turn
#   ON nudging for the primary domain (Domain 1) ONLY over the entire length
#   of the simulation unless otherwise specified by the NUDGING setting below.
#
#   Here are the rules:
#
#     0. If you want to do any sort of nudging during a simulation, you must
#        also pass the --nudge flag when running ems_prep. This flag requests
#        that the required nudging fields be created from the initialization
#        datasets. No "ems_prep --nudge", NO nudging love!
#
#     1. Turning nudging ON in ems_run requires either:
#
#            a. Passing of  the --nudge flag to ems_run
#        Or
#            b. Setting NUDGING = Yes (or 1) in ems_autorun.conf (for ems_autorun)
#
#        Otherwise, this file is ignored and NO nudging will happen for you. You
#        like your simulations straight without the embellishments.
#
#     2. Passing "--nudge" to ems_run WITHOUT arguments or setting NUDGING = Yes
#        in ems_autorun.conf (when running ems_autorun) will turn ON nudging for
#        those domains specified in the NUDGING parameter below. In the absence
#        of a NUDGING value, nudging will by done for the primary domain only
#        over the entire length of the simulation.
#
#     3. Passing "--nudge" to ems_run WITH arguments, either 1 or 2, overrides
#        the GRID_FDDA parameter (Nudging Method) below. Passing anything other
#        than --nudge 1 or 2 will default back to the GRID_FDDA value.
#
#     4. There is an entire Appendix dedicated to nudging in the UEMS user guide.
#
#    Finally, to reduce user confusion and screw-ups, some WRF nudging parameters
#    are set internally by the UEMS since there is limited reason for the values
#    to deviate from the default values.
#
#    NOTE:  You can not use analysis or spectral nudging with DFI because
#           bad things will happen to good simulations, like yours
# ==============================================================================================
#
    @{$FDDA{grid_fdda}} =  &Config_grid_fdda();


    if ($FDDA{grid_fdda}[0]) {  #  FDDA it turned ON

        @{$FDDA{gfdda_end_h}}  = &Config_gfdda_end_h($FDDA{grid_fdda}[0]);

        if ($FDDA{gfdda_end_h}[0]) {

            @{$FDDA{if_ramping}}           = &Config_if_ramping();
            @{$FDDA{dtramp_min}}           = &Config_dtramp_min() if $FDDA{if_ramping}[0];

            @{$FDDA{k_zfac_q}}             = &Config_k_zfac_q();
            @{$FDDA{k_zfac_t}}             = &Config_k_zfac_t();
            @{$FDDA{k_zfac_uv}}            = &Config_k_zfac_uv();

            @{$FDDA{if_zfac_q}}            = &Config_if_zfac_q(@{$FDDA{k_zfac_q}});
            @{$FDDA{if_zfac_t}}            = &Config_if_zfac_t(@{$FDDA{k_zfac_t}});
            @{$FDDA{if_zfac_uv}}           = &Config_if_zfac_uv(@{$FDDA{k_zfac_uv}});

            @{$FDDA{gq}}                   = &Config_gq()         if $FDDA{k_zfac_q}[0];
            @{$FDDA{gt}}                   = &Config_gt()         if $FDDA{k_zfac_t}[0];
            @{$FDDA{guv}}                  = &Config_guv()        if $FDDA{k_zfac_uv}[0];

            @{$FDDA{if_no_pbl_nudging_q}}  = &Config_if_no_pbl_nudging_q();
            @{$FDDA{if_no_pbl_nudging_t}}  = &Config_if_no_pbl_nudging_t();
            @{$FDDA{if_no_pbl_nudging_uv}} = &Config_if_no_pbl_nudging_uv();

            @{$FDDA{xwavenum}}             = &Config_xwavenum()   if $FDDA{grid_fdda}[0] == 2;
            @{$FDDA{ywavenum}}             = &Config_ywavenum()   if $FDDA{grid_fdda}[0] == 2;

            @{$FDDA{fgdt}}                 = &Config_fgdt();
            @{$FDDA{io_form_gfdda}}        = &Config_io_form_gfdda();
            @{$FDDA{gfdda_inname}}         = &Config_gfdda_inname();
            @{$FDDA{gfdda_interval_m}}     = &Config_gfdda_interval_m();

        }
        &InitializationFileCheck();  return 1 if $ENV{RMESG};
    }


return;
}


#
# ==================================================================================
# ==================================================================================
#      SO BEGINS THE INDIVIDUAL PARAMETER CONFIGURATION SUBROUTINES
# ==================================================================================
# ==================================================================================
#

sub Config_grid_fdda {
# ==================================================================================
#   Option: GRID_FDDA - Nudging Method
#
#     The WRF allows users to choose between two methods of nudging, analysis or spectal.
#     In analysis nudging, each grid-point is nudged towards a value that is time-interpolated
#     from analyses. Spectral nudging is designed towards the nudging of only selected larger
#     scales, may be useful for controlling longer wave phases for long simulations.
#
#   Default:
#
#       For analysis nudging, select GRID_FDDA = 1   (Default)
#       For spectral nudging, select GRID_FDDA = 2
# ==================================================================================
#   
    my @grid_fdda = @{$Config{uconf}{GRID_FDDA}};
       @grid_fdda = $grid_fdda[0] ? ($grid_fdda[0]) x $Config{maxdoms} : (0);


return @grid_fdda;
}


sub Config_gfdda_end_h {
# ========================================================================================================
#   Option:  NUDGING  - Does a lot and then populates the gfdda_end_h array
#
#   Works Like:
#
#       NUDGING = <domain #:length in hours from T0>,...,<domain #N:length in hours from T0>
#
#    NUDGING defines the domains on which to conduct 3D nudging (analysis|spectral)
#    during the simulation. By now you should understand that any domains listed
#    must have been created when defining your computational domain.
#
#    SILLY NOTE: You must be sure that you are actually including each domain specified
#                in NUDGING below in your simulation.
#
#    The convention for DOMAIN is:
#
#      NUDGING = <domain number>:<length of nudging period in hours from simulation start>
#
#    Where:
#          <domain number> = Domain number 1..N (easy enough). Why include Domain 1 in
#                            the list when it's included by default? Well, there are
#                            times when you might want to turn OFF (ramp down) analysis
#                            nudging for domain 1 before the end of a simulation.
#
#          <period length> = Length of the nudging period in hours from the start of
#                            model (not nest) integration (T0). If the period extends
#                            beyond the end of model integration for a given domain 
#                            nudging will terminate when the model stops (obviously).
#
#                            If you start a nested domain at a later time than its 
#                            parent (see ems_prep) the nudging period STILL STARTS
#                            with model integration. Consequently, the period length
#                            is only used to define the time at which nudging is turned
#                            OFF.
#
#                            It is important that the period length be an integer 
#                            multiple of the time interval between analysis times. 
#                            If you are using 3-hourly analyses then the length
#                            must be 180 (min) x N, where 180N is less than or 
#                            equal to the simulation length.
#
#
#    For example, if you created 5 nested domains, identified as 01...05 (domain 01
#    is the parent of all domains) and you want to turn ON nudging for domains
#    1,2, and 4, but not 5 then set NUDGING = 1,2,3,4.
#
#    Note that if you turn nudging ON then you also should include the parent domain.
#    If domain 3 is a child of 2, and you want to nudge domain 3 you will need
#    to nudge domain 2 as well. Conversely, if you nudge domain 2 then domain 3 does
#    not have to be nudged.
#
#    Again, the "period" of nudging begins with the start of domain 1 integration.
#
#    Examples:
#
#      NUDGING = 2:12 - Terminate analysis nudging on domain 2 twelve hours after the start of
#                       model integration. Nudging on domain 1 will be included by default and
#                       run through the end of the simulation.
#
#      NUDGING = 1:12,3:9 - Terminate analysis nudging on domain one 12 hours after the start
#                           of integration. Stop nudging on domain 3 nine hours after the
#                           model start. If domain 2, which is not included, is the parent of
#                           domain 3 then it will also be included and nudging will be 
#                           conducted on domain 2 from the start of integration to the end
#                           of domain 1 nudging.
#
#                           If the 9 hour nudging period for domain 3 extends beyond the end
#                           of nudging on domain 2, then it will be terminated with domain 2.
# ========================================================================================================
#
use List::Util 'max';

    my %dnudge  = ();
    my %renv    = %{$Rconf{rtenv}};   #  Contains the  local configuration
    my %dinfo   = %{$Rconf{dinfo}};  #  just making things easier

    my %nudging = map {split( /:/, $_, 2) } @{$Config{uconf}{NUDGING}};
    my $dmax    = max keys %nudging;
    my $meth    = shift;

    #  Initialize the hash containing all the domains with dummy start stop and period length seconds
    #
    my $epochsT0 = &Others::CalculateEpochSeconds(&Others::DateStringWRF2DateString($Rconf{dinfo}{domains}{1}{sdate}));
    my $interval = $Rconf{dinfo}{domains}{1}{interval};
    my $flength  = $Rconf{dinfo}{domains}{1}{length};

    #-------------------------------------------------------------------------------------------------
    #  Begin the process of determining the period length of nudging for each domain. Remember that:
    #  
    #    1. If nudging for a child domain is activated, it must be activated for it's parent.
    #       This means that if nudging is turned ON for the inner-most domain of a three level
    #       nested simulation, nudging for all domains is turned ON.
    #
    #    2. The period length specified in run_nudging.conf is calculated from T0 of the primary 
    #       domain (1), which is NOT necessarily the same start time of the child domain that is
    #       being nudged. Start time for a nest (child) is specified when running ems_prep.
    #
    #    3. The time period over which nudging is turned ON for a child domain cannot extend beyond
    #       that of its parent. - See #1
    # 
    #    4. For obvious reasons, if the nudging period for a parent domain ends prior to the start
    #       of a child domain (#2), then no nudging will occur on the child domain.
    #
    #  The messy login below must determine the period length of nudging for each domain to be
    #  included in the WRF namelist file.  Consequently, it must account for all domains on 
    #  which nudging is being conducted, domains included in the simulation but without nudging
    #  and those domains that are not included in the simulation but are included in the string
    #  populating the namelist file.
    #
    #  COMMENT - From previous UEMS documentation:
    #
    #    "If this is a global simulation and the nudging is set to be turned OFF prior model"
    #    "termination, set the end time 1 updated period prior to nudging end.  I don't"
    #    "know why though.  Hack - turn OFF nudging 1 hour prior to final analysis time."
    #
    #  The above condition is not addressed here but may need to be should this still be 
    #  an issue in future WRF releases.
    #-------------------------------------------------------------------------------------------------
    #
    for my $d (1..$Config{maxdoms}) {
    
        $dnudge{$d}{ssecs} = (defined $Rconf{dinfo}{domains}{$d}) ? &Others::CalculateEpochSeconds(&Others::DateStringWRF2DateString($Rconf{dinfo}{domains}{$d}{sdate})) 
                                                                  : $dnudge{1}{ssecs};
        $dnudge{$d}{esecs} = (defined $Rconf{dinfo}{domains}{$d}) ? &Others::CalculateEpochSeconds(&Others::DateStringWRF2DateString($Rconf{dinfo}{domains}{$d}{edate})) 
                                                                  : $dnudge{1}{esecs};
        $dnudge{$d}{esecs} = $dnudge{$d}{ssecs} unless defined $Rconf{dinfo}{domains}{$d} and $d <= $dmax;
        $dnudge{$d}{nsecs} = $dnudge{$d}{esecs} - $dnudge{$d}{ssecs};

        next unless defined $Rconf{dinfo}{domains}{$d} and $d <= $dmax;

        my $p = $Rconf{dinfo}{domains}{$d}{parent};

        #  Prepare the nudging period value specified by the user
        #
        $nudging{$d}       = $flength unless defined $nudging{$d} and $nudging{$d} > 0;
        $nudging{$d}       = $flength if $nudging{$d} > $flength;
        if ($nudging{$d}) {$nudging{$d}++ while $nudging{$d}%$interval and $nudging{$d} < $flength;}  #  Make period an integer multiple of update interval

        #  At this point:
        #      ssecs - The Epoch seconds of Domain # simulation start
        #      esecs - The Epoch seconds of Domain # simulation end
        #      nsecs - The length of Domain # simulation (seconds) Note: Not from T0
        #
        $dnudge{$d}{esecs} =  $epochsT0 + $nudging{$d} unless ($epochsT0+$nudging{$d}) > $dnudge{$d}{esecs};

        #  Now esecs - The Epoch seconds of Domain # nudging end
        #
        $dnudge{$d}{esecs} = $dnudge{$p}{esecs} if $dnudge{$d}{esecs} > $dnudge{$p}{esecs};
        $dnudge{$d}{esecs} = $dnudge{$d}{ssecs} if $dnudge{$d}{ssecs} > $dnudge{$d}{esecs}; #  Turn OFF if Tstart > Tend
        $dnudge{$d}{nsecs} = $dnudge{$d}{esecs}  - $dnudge{$d}{ssecs};
    
    }
    my @nudging = map { $dnudge{$_}{nsecs} } sort {$a <=> $b} keys %dnudge;  # The @nudging array contains the period length (seconds) for ALL domains
    @{$FDDA{grid_fdda}} = Others::PairWise {$a * ($b ? 1 : 0)}  @{$FDDA{grid_fdda}}, @nudging;

    my $ilast = $#nudging; $ilast-- until $nudging[$ilast];
    my @gfdda_end_h = map { int ($_/3600.) } @nudging[0..$ilast];


return @gfdda_end_h;
}


sub Config_dtramp_min {
# ==================================================================================
#   Option:  DTRAMP_MIN - Ramping period
#
#    The ramping period is only used when analysis nudging is turned OFF prior to the termination
#    the model simulation. Setting DTRAMP_MIN to a non-zero value will instruct the model to gradually
#    reduce the nudging over DTRAMP_MIN minutes until the nudging is turned OFF.  It is recommended
#    that DTRAMP_MIN be used in cases where  nudging is turned OFF prior to the termination of the
#    model to avoid the generation of noise as the model adjusts to a non-nudged state.
#
#    Examples of DTRAMP_MIN values include:
#
#      DTRAMP_MIN = -60. - Begin ramping down nudging 60 minutes prior to the requested nudging
#                          termination time.
#
#      DTRAMP_MIN = 0.   - Abruptly end nudging at requested time
#
#      DTRAMP_MIN = 60.  - Begin ramping down nudging at requested time and continue for 60 minutes.
#
#    DTRAMP_MIN is only used when nudging is turned OFF prior to model termination.
#
#   Default: DTRAMP_MIN = 60
# ==================================================================================
#
    my @dtramp_min = @{$Config{uconf}{DTRAMP_MIN}};
       @dtramp_min = (-60) if $dtramp_min[0] < -180;
       @dtramp_min = (60)  if $dtramp_min[0] >  180;

return @dtramp_min;
}


sub Config_if_ramping {
# ==================================================================================
#   Option:  IF_RAMPING - A switch to decide if nudging is ramped down linearly
#
#   Values:
#
#       0 - Nudging ends abruptly as a step function
#       1 - Ramping nudging down linearly at end of period
#
#   Default: IF_RAMPING = 1
# ==================================================================================
#
    my @if_ramping = @{$Config{uconf}{IF_RAMPING}};


return @if_ramping;
}


sub Config_if_no_pbl_nudging_q {
# ==================================================================================
#   Options: IF_NO_PBL_NUDGING_(UV|T|Q)
#
#     Specifies whether to turn OFF (1) or keep ON (0) nudging withing the PBL.
#     When set to 1, this parameter effectively overrides k_zfac_(uv|t|q) in cases
#     where nudging is turned ON above a layer but that layer resides within the
#     simulated PBL. The very limited documentation indicates that nudging will
#     be turned off for that layer. The recommended value is 1, which directs the
#     model to turn OFF nudging within the PBL. An exception may be made for UV;
#     otherwise, you will get a warning.
#
#  Values:
#
#     0 - Turn ON nudging withing the PBL
#     1 - Turn OFF nudging withing the PBL
#
#  Defaults: IF_NO_PBL_NUDGING_(UV|T|Q) = 1  (No Nudging in PBL) 
# ==================================================================================
#
    my @if_no_pbl_nudging_q = @{$Config{uconf}{IF_NO_PBL_NUDGING_Q}};
       @if_no_pbl_nudging_q = @if_no_pbl_nudging_q[0..$#{$FDDA{gfdda_end_h}}];
    my $index = &Others::IntegerIndexMatchExact(0,@if_no_pbl_nudging_q); $index+=1;

    my $mesg = "3D analysis nudging of mixing ratio (Q) within the PBL is not recommended (IF_NO_PBL_NUDGING_Q = 0 for domain $index).";
    &Ecomm::PrintMessage(6,11+$Rconf{arf},144,1,2,$mesg) if $index;


return @if_no_pbl_nudging_q;
}


sub Config_if_no_pbl_nudging_t {
# ==================================================================================
#   Options: IF_NO_PBL_NUDGING_(UV|T|Q)
#
#     Specifies whether to turn OFF (1) or keep ON (0) nudging withing the PBL.
#     When set to 1, this parameter effectively overrides k_zfac_(uv|t|q) in cases
#     where nudging is turned ON above a layer but that layer resides within the
#     simulated PBL. The very limited documentation indicates that nudging will
#     be turned off for that layer. The recommended value is 1, which directs the
#     model to turn OFF nudging within the PBL. An exception may be made for UV;
#     otherwise, you will get a warning.
#
#  Values:
#
#     0 - Turn ON nudging withing the PBL
#     1 - Turn OFF nudging withing the PBL
#
#  Defaults: IF_NO_PBL_NUDGING_(UV|T|Q) = 1  (No Nudging in PBL) 
# ==================================================================================
#
    my @if_no_pbl_nudging_t = @{$Config{uconf}{IF_NO_PBL_NUDGING_T}};
       @if_no_pbl_nudging_t = @if_no_pbl_nudging_t[0..$#{$FDDA{gfdda_end_h}}];

    my $index = &Others::IntegerIndexMatchExact(0,@if_no_pbl_nudging_t); $index+=1;

    my $mesg = "3D analysis nudging of temperature (T) within the PBL is not recommended (IF_NO_PBL_NUDGING_T = 0 for domain $index).";
    &Ecomm::PrintMessage(6,11+$Rconf{arf},144,1,2,$mesg) if $index;


return @if_no_pbl_nudging_t;
}


sub Config_if_no_pbl_nudging_uv {
# ==================================================================================
#   Options: IF_NO_PBL_NUDGING_(UV|T|Q)
#
#       Specifies whether to turn OFF (1) or keep ON (0) nudging withing the PBL.
#       When set to 1, this parameter effectively overrides k_zfac_(uv|t|q) in cases
#       where nudging is turned ON above a layer but that layer resides within the
#       simulated PBL. The very limited documentation indicates that nudging will
#       be turned off for that layer. The recommended value is 1, which directs the
#       model to turn OFF nudging within the PBL. An exception may be made for UV;
#       otherwise, you will get a warning.
#
#  Values:
#
#       0 - Turn ON nudging withing the PBL
#       1 - Turn OFF nudging withing the PBL
#
#  Defaults: IF_NO_PBL_NUDGING_(UV|T|Q) = 1  (No Nudging in PBL) 
# ==================================================================================
#
    my @if_no_pbl_nudging_uv = @{$Config{uconf}{IF_NO_PBL_NUDGING_UV}};
       @if_no_pbl_nudging_uv = @if_no_pbl_nudging_uv[0..$#{$FDDA{gfdda_end_h}}];


return @if_no_pbl_nudging_uv;
}


sub Config_if_zfac_q {
# ==================================================================================
#   Option: IF_ZFAC_Q - A switch to control nudging of water vapor mixing ratio 
#                       in the vertical direction.
#
#   Values:
#
#        0 - Nudge water vapor mixing ratio for all layers
#        1 - Limit nudging to levels above k_zfac_q
#
#  Defaults: IF_ZFAC_Q = 0 (nudge water vapor mixing ratio for all layers)
# ==================================================================================
#
    my @if_zfac_q = map {$_ == 1 ? 0 : 1} @_;
       @if_zfac_q = @if_zfac_q[0..$#{$FDDA{gfdda_end_h}}];


return @if_zfac_q;
}


sub Config_if_zfac_t {
# ==================================================================================
#   Option: IF_ZFAC_T - A switch to control nudging of temperature in the vertical
#
#   Values:
#
#        0 - Nudge temperature for all layers
#        1 - Limit nudging to levels above k_zfac_t
#
#  Defaults: IF_ZFAC_T = 0 (Nudge temperature for all layers)
# ==================================================================================
#
    my @if_zfac_t = map {$_ == 1 ? 0 : 1} @_;
       @if_zfac_t = @if_zfac_t[0..$#{$FDDA{gfdda_end_h}}];


return @if_zfac_t;
}


sub Config_if_zfac_uv {
# ==================================================================================
#   Option: IF_ZFAC_UV 
#
#       A switch to control nudging of u-component and v-component of wind in 
#       vertical (0=nudge ua and v for all layers, 1=limit nudging to levels 
#       above or larger than k_zfac_uv). 
#
#       For example, model level 1 is always at the surface and say model level 
#       15 is at 850 mb for your case, and below this level you wish to turn 
#       analysis nudging off for wind. You would ten set this parameter to 1 
#       and the following parameter to 15.
#
#   Values:
#
#        0 - Nudge water u-component and v-component of wind for all layers
#        1 - Limit nudging to levels above k_zfac_uv
#
#  Defaults: IF_ZFAC_UV = 0 (or all layers)
# ==================================================================================
#
    my @if_zfac_uv = map {$_ == 1 ? 0 : 1} @_;
       @if_zfac_uv = @if_zfac_uv[0..$#{$FDDA{gfdda_end_h}}];


return @if_zfac_uv;
}


sub Config_gq {
# ==================================================================================
#   Options:  G(UV|T|Q)
#
#       The nudging coefficient for each variable, E.g., guv, gt, and gq. Setting
#       the parameter to 0.0 turns OFF analysis nudging for that variable. A value
#       greater than 0 turns ON nudging and applies the value.
#
#       The default value is 0.0003 (s-1), which corresponds to a timescale of
#       about 1 hour.  Doubling the value to 0.0006 gives you a timescale of about
#       30 minutes.
#
#       Note that nudging may also be turned off (g(uv|t|q) = 0.) by setting
#       setting k_zfac_(uv|t|q) = 0 below.
#
#  Defaults: G(UV|T|Q) = 0.0003 s-1
# ==================================================================================
#
    my @gq = @{$Config{uconf}{GQ}};
       @gq = @gq[0..$#{$FDDA{gfdda_end_h}}];


return @gq;
}


sub Config_gt {
# ==================================================================================
#   Options:  G(UV|T|Q)
#
#       The nudging coefficient for each variable, E.g., guv, gt, and gq. Setting
#       the parameter to 0.0 turns OFF analysis nudging for that variable. A value
#       greater than 0 turns ON nudging and applies the value.
#
#       The default value is 0.0003 (s-1), which corresponds to a timescale of
#       about 1 hour.  Doubling the value to 0.0006 gives you a timescale of about
#       30 minutes.
#
#       Note that nudging may also be turned off (g(uv|t|q) = 0.) by setting
#       setting k_zfac_(uv|t|q) = 0 below.
#
#  Defaults: G(UV|T|Q) = 0.0003 s-1
# ==================================================================================
#
    my @gt = @{$Config{uconf}{GT}};
       @gt = @gt[0..$#{$FDDA{gfdda_end_h}}];


return @gt;
}


sub Config_guv {
# ==================================================================================
#   Options: G(UV|T|Q)
#
#       The nudging coefficient for each variable, E.g., guv, gt, and gq. Setting
#       the parameter to 0.0 turns OFF analysis nudging for that variable. A value
#       greater than 0 turns ON nudging and applies the value.
#
#       The default value is 0.0003 (s-1), which corresponds to a timescale of
#       about 1 hour.  Doubling the value to 0.0006 gives you a timescale of about
#       30 minutes.
#
#       Note that nudging may also be turned off (g(uv|t|q) = 0.) by setting
#       setting k_zfac_(uv|t|q) = 0 below.
#
#  Defaults: G(UV|T|Q) = 0.0003 s-1
# ==================================================================================
#
    my @guv = @{$Config{uconf}{GUV}};
       @guv = @guv[0..$#{$FDDA{gfdda_end_h}}];


return @guv;
}


sub Config_k_zfac_q {
# ==================================================================================
#   Options: K_ZFAC_(UV|T|Q)
#
#       Specifies the model layer below which nudging is to be turned OFF. It can
#       be advantageous to only nudge a simulation within the mid- to upper model
#       atmosphere and allow the lower tropospheric features to evolve naturally.
#
#       In this case set k_zfac_(uv|t|q) to the integer layer above which nudging
#       will be applied.  In the WRF the surface is level 1 and increases vertically.
#
#       Setting k_zfac_(uv|t|q) = 1 turns ON (uv|t|q) nudging for all layers.
#
#       Setting k_zfac_(uv|t|q) = 0 turns OFF (uv|t|q) nudging for all layers, which
#       is the same as setting g(uv|t|q) = 0.
#
#       Setting k_zfac_(uv|t|q) = 10 turns OFF (uv|t|q) nudging below model layer 10.
#
#   Notes:
#
#       Note for those familiar with the FDDA WRF namelist configuration. The value provided
#       for k_zfac_(uv|t|q) will control the configuration of if_zfac_(uv|t|q) so don't get
#       all upset that both parameters aren't presented here.
#
#   Defaults: K_ZFAC_(UV|T|Q) = 1
# ==================================================================================
#
    my @k_zfac_q = @{$Config{uconf}{K_ZFAC_Q}};
       @k_zfac_q = @k_zfac_q[0..$#{$FDDA{gfdda_end_h}}];


return @k_zfac_q;
}


sub Config_k_zfac_t {
# ==================================================================================
#   Options: K_ZFAC_(UV|T|Q)
#
#       Specifies the model layer below which nudging is to be turned OFF. It can
#       be advantageous to only nudge a simulation within the mid- to upper model
#       atmosphere and allow the lower tropospheric features to evolve naturally.
#
#       In this case set k_zfac_(uv|t|q) to the integer layer above which nudging
#       will be applied.  In the WRF the surface is level 1 and increases vertically.
#
#       Setting k_zfac_(uv|t|q) = 1 turns ON (uv|t|q) nudging for all layers.
#
#       Setting k_zfac_(uv|t|q) = 0 turns OFF (uv|t|q) nudging for all layers, which
#       is the same as setting g(uv|t|q) = 0.
#
#       Setting k_zfac_(uv|t|q) = 10 turns OFF (uv|t|q) nudging below model layer 10.
#
#   Notes:
#
#       Note for those familiar with the FDDA WRF namelist configuration. The value provided
#       for k_zfac_(uv|t|q) will control the configuration of if_zfac_(uv|t|q) so don't get
#       all upset that both parameters aren't presented here.
#
#   Defaults: K_ZFAC_(UV|T|Q) = 1
# ==================================================================================
#
    my @k_zfac_t = @{$Config{uconf}{K_ZFAC_T}};
       @k_zfac_t = @k_zfac_t[0..$#{$FDDA{gfdda_end_h}}];

return @k_zfac_t;
}


sub Config_k_zfac_uv {
# ==================================================================================
#   Options: K_ZFAC_(UV|T|Q)
#
#       Specifies the model layer below which nudging is to be turned OFF. It can
#       be advantageous to only nudge a simulation within the mid- to upper model
#       atmosphere and allow the lower tropospheric features to evolve naturally.
#
#       In this case set k_zfac_(uv|t|q) to the integer layer above which nudging
#       will be applied.  In the WRF the surface is level 1 and increases vertically.
#
#       Setting k_zfac_(uv|t|q) = 1 turns ON (uv|t|q) nudging for all layers.
#
#       Setting k_zfac_(uv|t|q) = 0 turns OFF (uv|t|q) nudging for all layers, which
#       is the same as setting g(uv|t|q) = 0.
#
#       Setting k_zfac_(uv|t|q) = 10 turns OFF (uv|t|q) nudging below model layer 10.
#
#   Notes:
#
#       Note for those familiar with the FDDA WRF namelist configuration. The value provided
#       for k_zfac_(uv|t|q) will control the configuration of if_zfac_(uv|t|q) so don't get
#       all upset that both parameters aren't presented here.
#
#   Defaults: K_ZFAC_(UV|T|Q) = 1
# ==================================================================================
#
    my @k_zfac_uv = @{$Config{uconf}{K_ZFAC_UV}};
       @k_zfac_uv = @k_zfac_uv[0..$#{$FDDA{gfdda_end_h}}];
    

return @k_zfac_uv;
}


sub Config_xwavenum {
# ==================================================================================
#   Option: XWAVENUM - wavelength to nudge for spectral nudging
#
#     Should you choose to apply spectral nudging, you will have to decide which wavelengths
#     to nudge.  If you are familiar with the WRF namelist options then you will know that
#     this setting is controlled by the xwavenum & ywavenum parameters. However, since the
#     UEMS is all about making your life easier and thus affording you the opportunity to
#     slack off, a single UEMS parameter, SPWAVELEN is used for the same purpose. The
#     SPWAVELEN defines the smallest wavelength to nudge. The wavelength (in Km) should
#     be determined from the grid spacing of your initialization dataset, E.g. 0.5 deg.
#     If you assume that it requires ~ 6 to 8 grid points to adequately resolve a wave,
#     Then the minimum wavelength should be between 6 to 8 DX, E.g. 3 to 4 degrees or
#     about 300 to 450 km.  If you nudging dataset has a courser (finer) resolution then
#     you should increase (decrease) the wavelength.
#
#       SPWAVELEN = smallest wavelength to nudge (km)
#
#     The highly complex mathematical algorithm in the UEMS will calculate the values
#     of xwavenum & ywavenum from your SPWAVELEN setting and the areal coverage of your
#     computational domain.
#
#     If you leave SPWAVELEN blank, the UEMS will attempt to guess the resolution of your
#     nudging dataset to calculate some appropriate values for xwavenum & ywavenum.
#
#   Default: SPWAVELEN = 400
# ==================================================================================
#
    my @wavelen = @{$Config{uconf}{SPWAVELEN}};
       @wavelen = (400.) unless $wavelen[0];

    my $dxkm    = 0.001*$Rconf{dinfo}{domains}{1}{dx}*$Rconf{dinfo}{domains}{1}{nx};
    my $wavenum = int (0.5 + $dxkm/$wavelen[0]);

return ($wavenum);
}


sub Config_ywavenum {
# ==================================================================================
#   Option: XWAVENUM - wavelength to nudge for spectral nudging
#
#     Should you choose to apply spectral nudging, you will have to decide which wavelengths
#     to nudge.  If you are familiar with the WRF namelist options then you will know that
#     this setting is controlled by the xwavenum & ywavenum parameters. However, since the
#     UEMS is all about making your life easier and thus affording you the opportunity to
#     slack off, a single UEMS parameter, SPWAVELEN is used for the same purpose. The
#     SPWAVELEN defines the smallest wavelength to nudge. The wavelength (in Km) should
#     be determined from the grid spacing of your initialization dataset, E.g. 0.5 deg.
#     If you assume that it requires ~ 6 to 8 grid points to adequately resolve a wave,
#     Then the minimum wavelength should be between 6 to 8 DX, E.g. 3 to 4 degrees or
#     about 300 to 450 km.  If you nudging dataset has a courser (finer) resolution then
#     you should increase (decrease) the wavelength.
#
#       SPWAVELEN = smallest wavelength to nudge (km)
#
#     The highly complex mathematical algorithm in the UEMS will calculate the values
#     of xwavenum & ywavenum from your SPWAVELEN setting and the areal coverage of your
#     computational domain.
#
#     If you leave SPWAVELEN blank, the UEMS will attempt to guess the resolution of your
#     nudging dataset to calculate some appropriate values for xwavenum & ywavenum.
#
#   Default: SPWAVELEN = 400
# ==================================================================================
#
    my @wavelen = @{$Config{uconf}{SPWAVELEN}};
       @wavelen = (400.) unless $wavelen[0];

    my $dykm    = 0.001*$Rconf{dinfo}{domains}{1}{dy}*$Rconf{dinfo}{domains}{1}{ny};
    my $wavenum = int (0.5 + $dykm/$wavelen[0]);

return ($wavenum);
}


sub Config_gfdda_interval_m {
# ==================================================================================
#   Option: GFDDA_INTERVAL_M - Time interval (min) between analysis times
#
#   Values: Set this parameter to 360 if you are using 6-hourly analyses
# ==================================================================================
#
    my @gfdda_interval_m = (int($Rconf{dinfo}{domains}{1}{interval}/60)) x $Config{maxdoms};
       @gfdda_interval_m = @gfdda_interval_m[0..$#{$FDDA{gfdda_end_h}}];

return @gfdda_interval_m;
}



sub Config_gfdda_inname {
# ==================================================================================
#   Option:  GFDDA_INNAME - Analysis nudging input file name defined in Real
# ==================================================================================
#
    my @gfdda_inname = ('"wrffdda_d<domain>"');

return @gfdda_inname;
}


sub Config_io_form_gfdda {
# ==================================================================================
#   Option: IO_FORM_GFDDA - Analysis data io format (2=netCDF)
# ==================================================================================
#
    my @io_form_gfdda = (2);

return @io_form_gfdda;
}


sub Config_fgdt {
# ==================================================================================
#   Option:  FGDT - Calculation frequency (minutes) for analysis nudging where
#                  0=every step. We suggest you use this default value.
# ==================================================================================
#
    my @fgdt = (0);  #  Stick with the default

return @fgdt;
}


sub InitializationFileCheck {
# ==================================================================================
#   Subroutine to check whether the initialization files are available for the 
#   domains to be nudged. Simly loop through the domains in the final nudging 
#   list and compare the number of WPS files in the wpsprd/ directory associated
#   with that domain to those for domain #1. If the number of files are not the
#   same then there is a problem - Halt.
# ==================================================================================
#
    if (%{$Rconf{rtenv}{wpsfls}}) {  #  No WPS files, No data
        for my $i (0..$#{$FDDA{grid_fdda}}) {
            if ($FDDA{grid_fdda}[$i] and @{$Rconf{rtenv}{wpsfls}{$i+1}} != @{$Rconf{rtenv}{wpsfls}{1}}) {
                my $mesg = "It appears that you have not processed the initialization files for use with 3D analysis ".
                           "nudging. Return to running \"ems_prep\" and be sure to include the \"--nudging\" flag ".
                           "this time.\n\nRemember, don't come into the house of UEMS unless you mean business!";
                $ENV{RMESG} = &Ecomm::TextFormat(0,0,94,0,0,'You Skipped a Step:',$mesg);
                return;
            }
        }
    }

return;
}
    



sub FDDA_Debug {
# ==============================================================================================
# &FDDA NAMELIST DEBUG ROUTINE
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  When the --debug 4+ flag is passed, prints out the contents of the WRF &fdda 
#  namelist section .
#
# ==============================================================================================
# ==============================================================================================
#   
    my @defvars  = ();
    my @ndefvars = ();
    my $nlsect   = 'fdda'; #  Specify the namelist section to print out

    return unless $ENV{RUN_DBG} > 3;  #  Only for --debug 4+

    foreach my $tcvar (@{$ARWconf{nlorder}{$nlsect}}) {
        defined $FDDA{$tcvar} ? push @defvars => $tcvar : push @ndefvars => $tcvar;
    }

    return unless @defvars or @ndefvars;

    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,13+$Rconf{arf},144,1,1,'Leaving &ARWfdda');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-24s  = %s',$_,join ', ' => @{$FDDA{$_}})) foreach @defvars;
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,' ');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-24s  = %s',$_,'Not Used')) foreach @ndefvars;
    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,2,'=' x 72);
        

return;
}


