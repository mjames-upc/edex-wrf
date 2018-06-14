#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ARWafwa.pm
#
#  DESCRIPTION:  This module handles the configuration of the &afwa namelist 
#                options for the ARW core. 
#
#   WHAT THE WRF
#   GUIDE SAYS:  Main control option to turn on weather diagnostics contributed 
#                by AFWA. Output goes to auxiliary stream 2. 
#
#         NOTE:  These options cannot be used with OpenMP.
#
#                That last line is a real bummer!
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package ARWafwa;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Rconf %Config %ARWconf %AFWA);

use Others;


sub Configure {
# ==============================================================================================
# &AFWA NAMELIST CONFIGURATION DIVER
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Each subroutine controls the configuration for the somewhat crudely organized namelist
#  variables. Should there be a serious problem an empty hash is returned (not really).
#  Not all namelist variables are configured as some do not require anything beyond the
#  default settings. The %AFWA hash is only used within this module to reduce the number
#  of characters being cut-n-pasted.
#
# ==============================================================================================
# ==============================================================================================
#   
    %Config = %ARWconfig::Config;
    %Rconf  = %ARWconfig::Rconf;

    my $href = shift; %ARWconf = %{$href};

    return () if &AFWA_Control(); 
    return () if &AFWA_Debug();

    %{$ARWconf{namelist}{afwa}}  = %AFWA;


return %ARWconf;
}


sub AFWA_Control {
# ==============================================================================================
# WRF &AFWA NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME? NOT MUCH
#
#   This routine configures the &afwa section of the WRF namelist file. Unfortunately,
#   The routines in WRF module_diag_afwa.F & module_diag_afwa_hail.F are not properly
#   written for parallel execution. Consequently, this routine serves no purpose other
#   than to make sure the AFWA diagnostics are turned OFF. Hopefully somebody will take
#   it upon themselves to rewrite the WRF subroutines so these diagnostics can be used.
#
#   Below you will find parameters that control the output of additional fields
#   contributed by AFWA. These fields include stability, precipitation type,
#   reflectivity, and turbulence diagnostics, as well as some others. Not all
#   of the AFWA fields are output in the UEMS as some were determined to be
#   duplicates of existing fields or cause problems while writing out the
#   netCDF file. Consequently, you get the best of the rest.
#
#  OK - SINCE YOU ASKED NICELY, HERE'S THE ENTIRE LIST:
#
#    * TCOLI_MAX         -    MAX TOTAL COLUMN INTEGRATED ICE                    [kg m-2]
#    * GRPL_FLX_MAX      -    MAX PSEUDO GRAUPEL FLUX                            [g kg-1 m s-1]
#    * FZLEV             -    FREEZING LEVEL                                     [m]
#    * ICINGTOP          -    TOPMOST ICING LEVEL                                [m]
#    * ICINGBOT          -    BOTTOMMOST ICING LEVEL                             [m]
#    * QICING_LG_MAX     -    COLUMN MAX ICING MIXING RATIO (>50 um)             [kg kg-1]
#    * QICING_SM_MAX     -    COLUMN MAX ICING MIXING RATIO (<50 um)             [kg kg-1]
#    * ICING_LG          -    TOTAL COLUMN INTEGRATED ICING (>50 um)             [kg m-2]
#    * ICING_SM          -    TOTAL COLUMN INTEGRATED ICING (<50 um)             [kg m-2]
#    * AFWA_MSLP         -    AFWA Diagnostic: Mean sea level pressure           [Pa]
#    * AFWA_HEATIDX      -    AFWA Diagnostic: Heat index                        [K]
#    * AFWA_WCHILL       -    AFWA Diagnostic: Wind chill                        [K]
#    * AFWA_LLTURB       -    AFWA Diagnostic: Low Level Turbulence index        [-]
#    * AFWA_LLTURBLGT    -    AFWA Diagnostic: Prob of LGT Low-level Turb        [%]
#    * AFWA_LLTURBMDT    -    AFWA Diagnostic: Prob of MDT Low-level Turb        [%]
#    * AFWA_LLTURBSVR    -    AFWA Diagnostic: Prob of SVR Low-level Turb        [%]
#    * AFWA_VIS          -    AFWA Diagnostic: Visibility                        [m]
#    * AFWA_CLOUD        -    AFWA Diagnostic: Cloud cover fraction              [fraction]
#    * AFWA_CLOUD_CEIL   -    AFWA Diagnostic: Cloud ceiling                     [m]
#    * AFWA_CAPE         -    AFWA Diagnostic: Convective Avail Pot Energy       [J kg-1]
#    * AFWA_CAPE_MAX     -    UEMS ADDED AFWA Diagnostic: Period Maximum Pot Energy [J kg-1]
#    * AFWA_CIN          -    AFWA Diagnostic: Convective Inhibition             [J kg-1]
#    * AFWA_CAPE_MU      -    AFWA Diagnostic: Most unstable CAPE 0-180mb        [J kg-1]
#    * AFWA_CIN_MU       -    AFWA Diagnostic: Most unstable CIN 0-180mb         [J kg-1]
#    * AFWA_ZLFC         -    AFWA Diagnostic: Level of Free Convection          [m]
#    * AFWA_PLFC         -    AFWA Diagnostic: Pressure of LFC                   [Pa]
#    * AFWA_LIDX         -    AFWA Diagnostic: Surface Lifted Index              [K]
#    * AFWA_PWAT         -    AFWA Diagnostic: Precipitable Water                [kg m-2]
#    * AFWA_HAIL         -    AFWA Diagnostic: Hail Diameter (Weibull)           [mm]
#    * AFWA_LLWS         -    AFWA Diagnostic: 0-2000 ft wind shear              [m s-1]
#    * AFWA_TORNADO      -    AFWA Diagnostic: Tornado wind speed (Weibull)      [m s-1]
#    * TORNADO_MASK      -    Tornado mask, 1 if AFWA tornado 0
#    * TORNADO_DUR       -    Tornado duration                                   [s]
#    * AFWA_HAIL         -    AFWA Diagnostic: Hail Diameter (Weibull)           [mm]
#    * AFWA_HAIL_NEWMEAN -    AFWA Diagnostic: New Mean Hail Diameter (Selin)    [mm]
#    * AFWA_HAIL_NEWSTD  -    AFWA Diagnostic: New Stand. Dev. Hail Diameter     [mm]
#
#  NOTE:  There is some duplication of fields between the AFWA and UEMS diagnostics.
#
#  ADDITIONAL FOOD FOR THOUGHT:  Some fields, such as MSLP, are already calculated as part
# ==============================================================================================
#
use List::Util qw(sum);

    %AFWA  = ();

    @{$AFWA{afwa_diag_opt}} = &Config_afwa_diag_opt();

    if (sum @{$AFWA{afwa_diag_opt}}) {

        @{$AFWA{afwa_hailcast_opt}} = &Config_afwa_hailcast_opt();
        @{$AFWA{afwa_buoy_opt}}     = &Config_afwa_buoy_opt();
        @{$AFWA{afwa_turb_opt}}     = &Config_afwa_turb_opt();
        @{$AFWA{afwa_therm_opt}}    = &Config_afwa_therm_opt();
        @{$AFWA{afwa_cloud_opt}}    = &Config_afwa_cloud_opt();
        @{$AFWA{afwa_vis_opt}}      = &Config_afwa_vis_opt();
        @{$AFWA{afwa_icing_opt}}    = &Config_afwa_icing_opt();
        @{$AFWA{afwa_severe_opt}}   = &Config_afwa_severe_opt();

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


sub Config_afwa_diag_opt {
# ==================================================================================
#   Option:  AFWA_DIAG_OPT       - Turn ON (1) or OFF (0) AFWA Diagnostic option
#
#   Notes:  Will automatically be turned ON if any other AFWA_*_OPT = 1
#
# ==================================================================================
#
    my @afwa_diag_opt = @{$Config{uconf}{AFWA_DIAG_OPT}};

return @afwa_diag_opt;
}


sub Config_afwa_severe_opt {
# ==================================================================================
#   Option:  AFWA_SEVERE_OPT - Turn ON (1) or OFF (0) AFWA Severe Wx option
#
#     Adds Fields: TCOLI_MAX       : MAX TOTAL COLUMN INTEGRATED ICE
#                  GRPL_FLX_MAX    : MAX PSEUDO GRAUPEL FLUX
#                  AFWA_CAPE       : AFWA Diagnostic: Convective Avail Pot Energy
#                  AFWA_CAPE_MAX   : UEMS ADDED AFWA Diagnostic: Period Maximum Pot Energy
#                  AFWA_CIN        : AFWA Diagnostic: Convective Inhibition
#                  AFWA_ZLFC       : AFWA Diagnostic: Level of Free Convection
#                  AFWA_PLFC       : AFWA Diagnostic: Pressure of LFC
#                  AFWA_LIDX       : AFWA Diagnostic: Surface Lifted Index
#                  AFWA_HAIL       : AFWA Diagnostic: Hail Diameter (Weibull)
#                  AFWA_LLWS       : AFWA Diagnostic: 0-2000 ft wind shear
#                  AFWA_TORNADO    : AFWA Diagnostic: Tornado wind speed (Weibull)
#                  WUP_MASK        : Updraft mask, 1 if 10m/s
#                  WDUR            : Updraft duration
#                  TORNADO_MASK    : Tornado mask, 1 if AFWA tornado 0
#                  TORNADO_DUR     : Tornado duration
# ==================================================================================
#
    my @afwa_severe_opt = @{$Config{uconf}{AFWA_SEVERE_OPT}};

return @afwa_severe_opt;
}


sub Config_afwa_icing_opt {
# ==================================================================================
#   Option:  AFWA_ICING_OPT - Turn ON (1) or OFF (0) AFWA Icing option
#
#     Adds Fields: FZLEV           : FREEZING LEVEL
#                  ICINGTOP        : TOPMOST ICING LEVEL
#                  ICINGBOT        : BOTTOMMOST ICING LEVEL
#                  QICING_LG_MAX   : COLUMN MAX ICING MIXING RATIO (>50 um)
#                  QICING_SM_MAX   : COLUMN MAX ICING MIXING RATIO (<50 um)
#                  ICING_LG        : SUPERCOOLED WATER MIXING RATIO (>50 um)
#                  ICING_SM        : SUPERCOOLED WATER MIXING RATIO (<50 um)
# ==================================================================================
#
    my @afwa_icing_opt = @{$Config{uconf}{AFWA_ICING_OPT}};

return @afwa_icing_opt;
}


sub Config_afwa_vis_opt {
# ==================================================================================
#   Option:  AFWA_VIS_OPT - Turn ON (1) or OFF (0) AFWA Visibility option
#
#     Adds Fields: AFWA_VIS        : AFWA Diagnostic: Visibility
# ==================================================================================
#
    my @afwa_vis_opt = @{$Config{uconf}{AFWA_VIS_OPT}};

return @afwa_vis_opt;
}


sub Config_afwa_cloud_opt {
# ==================================================================================
#   Option:  AFWA_CLOUD_OPT - Turn ON (1) or OFF (0) AFWA Cloud option
#
#     Adds Fields: AFWA_CLOUD      : AFWA Diagnostic: Cloud cover fraction
#                  AFWA_CLOUD_CEIL : AFWA Diagnostic: Cloud ceiling
# ==================================================================================
#
    my @afwa_cloud_opt = @{$Config{uconf}{AFWA_CLOUD_OPT}};

return @afwa_cloud_opt;
}


sub Config_afwa_therm_opt {
# ==================================================================================
#   Option:  AFWA_THERM_OPT - Turn ON (1) or OFF (0) AFWA Thermal index option
#
#     Adds Fields: AFWA_HEATIDX    : AFWA Diagnostic: Heat index
#                  AFWA_WCHILL     : AFWA Diagnostic: Wind chill
# ==================================================================================
#
    my @afwa_therm_opt = @{$Config{uconf}{AFWA_THERM_OPT}};

return @afwa_therm_opt;
}


sub Config_afwa_turb_opt {
# ==================================================================================
#   Option:  AFWA_TURB_OPT - Turn ON (1) or OFF (0) AFWA Turbulence option
#
#     Adds Fields: AFWA_LLTURB     : AFWA Diagnostic: Low Level Turbulence index
#                  AFWA_LLTURBLGT  : AFWA Diagnostic: Prob of LGT Low-level Turb
#                  AFWA_LLTURBMDT  : AFWA Diagnostic: Prob of MDT Low-level Turb
#                  AFWA_LLTURBSVR  : AFWA Diagnostic: Prob of SVR Low-level Turb
# ==================================================================================
#
    my @afwa_turb_opt = @{$Config{uconf}{AFWA_TURB_OPT}};

return @afwa_turb_opt;
}


sub Config_afwa_buoy_opt {
# ==================================================================================
#   Option:  AFWA_BUOY_OPT - Turn ON (1) or OFF (0) AFWA Buoyancy option
#
#     Adds Fields: AFWA_CAPE_MU    : AFWA Diagnostic: Most unstable CAPE 0-180mb
#                  AFWA_CIN_MU     : AFWA Diagnostic: Most unstable CIN 0-180mb
#                  AFWA_CAPE       : AFWA Diagnostic: Convective Avail Pot Energy
#                  AFWA_CIN        : AFWA Diagnostic: Convective Inhibition
#                  AFWA_ZLFC       : AFWA Diagnostic: Level of Free Convection
#                  AFWA_PLFC       : AFWA Diagnostic: Pressure of LFC
#                  AFWA_LIDX       : AFWA Diagnostic: Surface Lifted Index
#
#      Some Duplicate Fields
# ==================================================================================
#
    my @afwa_buoy_opt = @{$Config{uconf}{AFWA_BUOY_OPT}};

return @afwa_buoy_opt;
}


sub Config_afwa_hailcast_opt {
# ==================================================================================
#   Option:  AFWA_HAILCAST_OPT -  Turn ON (1) or OFF (0) AFWA Hailcast option
#
#     Adds Fields: AFWA_HAIL_NEWMEAN : AFWA Diagnostic: New Mean Hail Diameter
#                  AFWA_HAIL_NEWSTD  : AFWA Diagnostic: New Stand. Dev. Hail Diameter
#                  AFWA_HAIL_NEW1    : AFWA Diagnostic: New Hail Diameter, 1st rank order
#                  AFWA_HAIL_NEW2    : AFWA Diagnostic: New Hail Diameter, 2nd rank order
#                  AFWA_HAIL_NEW3    : AFWA Diagnostic: New Hail Diameter, 3rd rank order
#                  AFWA_HAIL_NEW4    : AFWA Diagnostic: New Hail Diameter, 4th rank order
#                  AFWA_HAIL_NEW5    : AFWA Diagnostic: New Hail Diameter, 5th rank order
# ==================================================================================
#
    my @afwa_hailcast_opt = @{$Config{uconf}{AFWA_HAILCAST_OPT}};

return @afwa_hailcast_opt;
}



sub AFWA_Debug {
# ==============================================================================================
# &AFWA NAMELIST DEBUG ROUTINE
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  When the --debug 4+ flag is passed, prints out the contents of the WRF &afwa namelist section.
#
# ==============================================================================================
# ==============================================================================================
#   
    my @defvars  = ();
    my @ndefvars = ();
    my $nlsect   = 'afwa'; #  Specify the namelist section to print out

    return unless $ENV{RUN_DBG} > 3;  #  Only for --debug 3+

    foreach my $tcvar (@{$ARWconf{nlorder}{$nlsect}}) {
        defined $AFWA{$tcvar} ? push @defvars => $tcvar : push @ndefvars => $tcvar;
    }

    return unless @defvars or @ndefvars;

    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,13+$Rconf{arf},144,1,1,'Leaving &ARWafwa');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-20s  = %s',$_,join ', ' => @{$AFWA{$_}})) foreach @defvars;
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,' ');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-20s  = %s',$_,'Not Used')) foreach @ndefvars;
    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,2,'=' x 72);
        

return;
}


