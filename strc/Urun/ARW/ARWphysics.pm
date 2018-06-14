#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ARWphysics.pm
#
#  DESCRIPTION:  ARWphysics contains the subroutines used for configuration of
#                the &physics section of the WRF ARW core namelist. 
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package ARWphysics;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Rconf %Config %ARWconf %Physics %NoahMP %Ptables);

use Others;


sub Configure {
# ==============================================================================================
# WRF &PHYSICS NAMELIST CONFIGURATION DRIVER
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Each subroutine controls the configuration for the somewhat crudely organized namelist
#  variables. Should there be a serious problem an empty hash is returned (not really).
#  Not all namelist variables are configured as some do not require anything beyond the
#  default settings. The %Physics hash is only used within this module to reduce the
#  number of characters being cut-n-pasted.
#
# ==============================================================================================
# ==============================================================================================
#
    %Physics = ();
    %NoahMP  = ();
    %Ptables = ();

    %Config  = %ARWconfig::Config;
    %Rconf   = %ARWconfig::Rconf;

    my $href = shift; %ARWconf = %{$href};

    return () if &Physics_Cumulus();
    return () if &Physics_MicroPhysics();
    return () if &Physics_Radiation();
    return () if &Physics_BoundryLayer();
    return () if &Physics_SurfaceLayer();
    return () if &Physics_LandSurface();
    return () if &Physics_UrbanCanopy();
    return () if &Physics_SeaLakes();
     
    return () if &Physics_Lightning();
    return () if &Physics_ShallowCumulus();
    return () if &Physics_FinalConfiguration();
    return () if &Physics_Debug();


    # ----------------------------------------------------------------------------
    #  The namelist variables are carried in the %Physics hash and the table 
    #  files are carried in the %Ptables hash.
    # ----------------------------------------------------------------------------
    #
    %{$ARWconf{namelist}{physics}}  = %Physics;
    %{$ARWconf{namelist}{noah_mp}}  = %NoahMP;
    @{$ARWconf{tables}{physics}}    = map { @{$Ptables{$_}} } keys %Ptables;


return %ARWconf;
}


sub Physics_Cumulus {
# ==============================================================================================
# WRF &PHYSICS NAMELIST CONFIGURATION FOR CUMULUS SCHEMES AND STUFF
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This subroutine manages the configuration of all things cumulus scheme in the
#   &physics section of the WRF namelist file. 
#
#   Note that some (most) of the information used to produce the guidance presented
#   in this file was likely taken from the WRF user's guide and presentation materials,
#   and those authors should receive all the gratitude as well as any proceeds that 
#   may be derived from reading this information.
#
#   Some basic guidance to follow:
#
#   *  For dx >= 10 km: probably need cumulus scheme
#
#   *  For dx <= 3 km: probably do not need scheme, although it
#      may help to trigger convection earlier.
#
#   *  For dx = 3-10 km, scale separation is a question - there are few
#      schemes designed for this range.
#
#   *  Issues with 2-way nesting when physics differs across nest 
#      boundaries (seen in precip field on parent domain)
#
#   *  Best to use same physics in both domains or 1-way nesting
#
#   *  Note that CUDT is assigned in phys_tscalc
#
# ==============================================================================================
# ==============================================================================================
#
use List::Util qw[min max first];

    my $mesg    = qw{};
    my @opts    = ();

    my %renv    = %{$Rconf{rtenv}};   #  Contains the  local configuration
    my %dinfo   = %{$Rconf{dinfo}};  #  just making things easier

    my @rundoms = sort {$a <=> $b} keys %{$dinfo{domains}}; #  Run-time domains in reverse order

    #-----------------------------------------------------------------------------
    #  PHYSICS Variable: CU_PHYSICS - Cumulus scheme
    #
    #    CU options include:
    #
    #    0 - No CU scheme used - Explicit (MP Scheme) only
    #    1 - Kain-Fritsch (new Eta) scheme
    #    2 - Betts-Miller-Janjic scheme
    #    3 - Grell-Freitas (GF) scheme
    #    4 - Old GFS Simpified Arakawa-Schubert (SAS) 
    #    5 - Grell-3D ensemble scheme
    #    6 - Modifed Tiedtke scheme (U. Hawaii version)
    #    7 - CAM5 Zhang-McFarlane scheme (CESM 1_0_1)
    #   10 - Multi-scale Kain-Fritsch cumulus potential scheme (kfcupscheme)
    #   11 - Multi-scale Kain-Fritsch scheme (mskfscheme)
    #   14 - New GFS Simpified Arakawa-Schubert (NSAS) scheme from YSU (ARW)
    #   16 - A newer Modifed Tiedtke scheme (U. Hawaii version)
    #   84 - New GFS Simpified Arakawa-Schubert (HWRF)
    #   93 - Grell-Devenyi Ensemble (Moved from option 3 in V3.5)
    #   99 - Previous Kain-Fritsch scheme (Not EMS supported)
    #
    #   Note: If CU -> explicit across domains then feedback will be
    #         automatically set to 1 in final configuration.
    #-----------------------------------------------------------------------------
    #
    
    #  Make sure that any physics scheme used by a nested domain is also used by
    #  the parent. IT'S THE LAW!
    #
    @{$Physics{cu_physics}} = map {$Config{uconf}{CU_PHYSICS}[$_] ? $Config{uconf}{CU_PHYSICS}[$Config{parentidx}[$_]] : 0} 0..$Config{maxindex};

   
    #  Provide warning to user if CU scheme inappropriate for DX
    #
    my @lines=();
    foreach (@rundoms) { 
        my $dx = sprintf '%.1f', 0.001*$dinfo{domains}{$_}{dx};
        my $cu = $Physics{cu_physics}[$_-1];
        push @lines => "Domain $_ is using cu_physics = $cu at $dx km" unless $dx > 10 or grep {/^$cu$/} (0,3,5,10,11);
    }
    $mesg = 'Only the Grell 3D (5), Grell-Freitas (3), multi-scale KF-CuP (10), and multi-scale KF (11) schemes are designed for DX < 10km.';
    &Ecomm::PrintMessage(6,11+$Rconf{arf},84,1,2,$mesg,join "\n", @lines) if @lines;



    #  ------------------------------ Additional CU_PHYSICS Configuration ---------------------------------------------
    #  If CU_PHYSICS is turn ON then complete additional configuration for the selected scheme.
    #  Note that the use of individual subroutines is not necessary since all the variables are
    #  global, but it make for cleaner code. Also - Most of the pre-configuration of user 
    #  defined variables was done in &ARWprep::ProcessLocalConfiguration, the values from which
    #  used here. The only difficulty in writing this code was how to organize the individual
    #  variables that need to be set for each CU scheme. Some variables are valid for all schemes
    #  some for different schemes, and others for only one scheme.
    #
    #  So an executive decision was made for the cleanest solution. There are individual subroutines
    #  for each parameter, which are called from a separate subroutine for each CU scheme. Parameters
    #  that are always used together are combined into a single subroutine.  Hopefully it will all
    #  work out.
    #  ----------------------------------------------------------------------------------------------------------------
    #
    for ($Physics{cu_physics}[0]) {

        &Physics_CU01_KainFritsch()          if $_ ==  1; #  Configure Kain-Fritsch (CU_PHYSICS = 1)
        &Physics_CU02_BettsMillerJanjic()    if $_ ==  2; #  Configure Betts-Miller-Janjic (CU_PHYSICS = 2)
        &Physics_CU03_GrellFreitas()         if $_ ==  3; #  Configure Grell-Freitas (CU_PHYSICS = 3)
        &Physics_CU04_ArakawaSchubert()      if $_ ==  4; #  Configure the Simpified Arakawa-Schubert (CU_PHYSICS = 4)
        &Physics_CU05_Grell3D()              if $_ ==  5; #  Configure Grell-3D (CU_PHYSICS = 5)
        &Physics_CU06_ModifedTiedTKE()       if $_ ==  6; #  Configure Modifed TiedTKE (CU_PHYSICS = 6)
        &Physics_CU07_ZhangMcFarlane()       if $_ ==  7; #  Configure Zhang-McFarlane CAM5 (CU_PHYSICS = 7)
        &Physics_CU10_KainFritschCUP()       if $_ == 10; #  Configure Kain-Fritsch Cumulus Potential (CU_PHYSICS = 10)
        &Physics_CU11_KainFritschMS()        if $_ == 11; #  Configure Kain-Fritsch Multi-Scale (CU_PHYSICS = 11)
        &Physics_CU14_ArakawaSchubert()      if $_ == 14; #  Configure New Simpified Arakawa-Schubert (NSAS) (CU_PHYSICS = 14)
        &Physics_CU16_ModifedTiedTKE()       if $_ == 16; #  Configure Hawaii Modifed Tiedtke (CU_PHYSICS = 16)
        &Physics_CU84_ArakawaSchubert()      if $_ == 84; #  Configure New Simpified Arakawa-Schubert (HWRF) (CU_PHYSICS = 84)
        &Physics_CU93_GrellDevenyiEnsemble() if $_ == 93; #  Configure Grell-Devenyi Ensemble (CU_PHYSICS = 93)

    }


return;
}  #  Physics_Cumulus


sub Physics_CU01_KainFritsch {
# ==================================================================================
#    Configuration options for the Kain-Fritsch (CU_PHYSICS = 1) Cumulus Scheme
#
#    Kain-Fritsch scheme: A deep and shallow sub-grid scheme using a mass
#    flux approach with downdrafts and CAPE removal time scale.
#
#      Moisture Tendencies: Qc,Qr,Qi,Qs
#      Momentum Tendencies: No
#      Shallow Convection:  Yes
#
#    Ancillary options:
#      kfeta_trigger - Convective trigger
#      cudt          - Minutes between calls to CU scheme
#
#    Reference: Kain (2004, JAM)
# ==================================================================================
#
    @{$Physics{kfeta_trigger}}   = &Config_kfeta_trigger(1);
    @{$Physics{kf_edrates}}      = &Config_kf_edrates();
    @{$Physics{cu_rad_feedback}} = &Config_cu_rad_feedback(1);
    @{$Physics{cudt}}            = &Config_cudt(1);


return;
}


sub Physics_CU02_BettsMillerJanjic {
# ==================================================================================
#  Configuration options for the Betts-Miller-Janjic (CU_PHYSICS = 2) Cumulus Scheme
#
#    Betts-Miller-Janjic scheme: Adjustment scheme for deep and shallow convection
#    relaxing towards variable temperature and humidity profiles determined from
#    thermodynamic considerations.
#
#      Moisture Tendencies:
#      Momentum Tendencies: No
#      Shallow Convection:  Yes
#
#    Ancillary options:
#      cudt          - Not used (automatically set to 0)
#
#  Reference: Janjic 1994, MWR; 2000, JAS
# ==================================================================================
#
    @{$Physics{cudt}}          = &Config_cudt(2);


return;
}


sub Physics_CU03_GrellFreitas {
# ==================================================================================
#  Configuration options for the Grell-Freitas (CU_PHYSICS = 3) Cumulus Scheme
#
#    Grell-Freitas (GF) scheme (3): An improved GD scheme that tries to smooth the
#    transition to cloud-resolving scales, as proposed by Arakawa et al. (2004).
#
#      Moisture Tendencies: Qc,Qi
#      Momentum Tendencies: No
#      Shallow Convection:  Yes (With shcu_physics = 1 in run_physics_shallowcumulus.conf)
#
#    Ancillary options:
#      cudt         - Not used (automatically set to 0)
#      cugd_avedx   - Number of grid boxes over which subsidence is spread
#      shcu_physics - Shallow Convection option (see above; ishallow in NCAR WRF)
#
#    Reference: Grell et al. (2013)
# ==================================================================================
#
    @{$Physics{cugd_avedx}}         = &Config_cugd_avedx();
    @{$Physics{convtrans_avglen_m}} = &Config_convtrans_avglen_m();
    @{$Physics{cu_rad_feedback}}    = &Config_cu_rad_feedback(3);
    @{$Physics{maxiens}}            = &Config_maxiens();
    @{$Physics{cu_diag}}            = &Config_cu_diag(3) if $Physics{cu_rad_feedback}[0] eq 'T';
    @{$Physics{cudt}}               = &Config_cudt(3);


return;
}


sub Physics_CU04_ArakawaSchubert {
# ==================================================================================
#  Configuration options for the Simpified Arakawa-Schubert (CU_PHYSICS = 4) Cumulus Scheme
#
#    Simplified Arakawa-Schubert scheme: Simple mass-flux scheme with quasi-
#    equilibrium closure with shallow mixing scheme.
#
#      Moisture Tendencies: Qc,Qi
#      Shallow Convection:  Yes (ARW)
#
#    Ancillary options:
#      cudt        - Not used (automatically set to 0)
#
#    Reference: Pan and Wu (1995), NMC Office Note 409
# ==================================================================================
#
    @{$Physics{nsas_dx_factor}} = &Config_nsas_dx_factor();
    @{$Physics{cudt}}           = &Config_cudt(4);


return;
}


sub Physics_CU05_Grell3D {
# ==================================================================================
#  Configuration options for the Grell-3D (CU_PHYSICS = 5) Cumulus Scheme
#
#    Grell 3D ensemble scheme: Similar to G-D scheme above but designed for
#    higher resolutions and allows for subsidence between neighboring columns.
#    May be used for simulations where DX < 10km!
#
#      Moisture Tendencies: Qc,Qi
#      Momentum Tendencies: No
#      Shallow Convection:  Yes (With shcu_physics = 1 in run_physics_shallowcumulus.conf)
#
#    Ancillary options:
#      cudt         - Not used (automatically set to 0)
#      cugd_avedx   - Number of grid boxes over which subsidence is spread
#      shcu_physics - Shallow Convection option (see above; ishallow in NCAR WRF)
#
#    Reference: None available
# ==================================================================================
#
    @{$Physics{cugd_avedx}}         = &Config_cugd_avedx();
    @{$Physics{convtrans_avglen_m}} = &Config_convtrans_avglen_m();
    @{$Physics{cu_rad_feedback}}    = &Config_cu_rad_feedback(5);
    @{$Physics{cu_diag}}            = &Config_cu_diag(5) if $Physics{cu_rad_feedback}[0] eq 'T';
    @{$Physics{cudt}}               = &Config_cudt(5);


return;
}


sub Physics_CU06_ModifedTiedTKE {
# ==================================================================================
#  Configuration options for the Modifed TiedTKE (CU_PHYSICS = 6) Cumulus Scheme
#
#    Modified Tiedtke scheme (U. of Hawaii version):  Mass-flux type scheme with
#    CAPE-removal time scale, shallow component and momentum transport.
#
#      Moisture Tendencies: Qc,Qi
#      Momentum Tendencies: Yes
#      Shallow Convection:  Yes
#
#    Ancillary options:
#      cudt         - Not used (automatically set to 0)
#
#    Reference: Tiedtke (1989, MWR), Zhang et al. (2011, MWR)
# ==================================================================================
#
    @{$Physics{cudt}}          = &Config_cudt(6);


return;
}


sub Physics_CU07_ZhangMcFarlane {
# ==================================================================================
#  Configuration options for the Zhang-McFarlane CAM5 (CU_PHYSICS = 7) Cumulus Scheme
#
#    Zhang-McFarlane scheme: Mass-flux CAPE-removal type deep convection from
#    CESM climate model with momentum transport. (Zhang and McFarlane 1995, AO)
#
#    Comment: Must be used with MYJ or UW PBL, - UW PBL (9) is computationally
#             slower than MYJ (2) - It's your call.
#
#      Moisture Tendencies: Qc,Qi
#      Momentum Tendencies: Yes
#      Shallow Convection:  No  (Use shcu_physics = 2 or 3 w/pbl scheme)
#
#    Ancillary options:
#      cudt         - Not used (automatically set to 0)
#
#    Reference: Zhang and McFarlane (1995, AO)
#
#    Note:  Additional configuration checks done in &Physics_FinalConfiguration
# ==================================================================================
#
    @{$Physics{cudt}}          = &Config_cudt(7);


return;
}


sub Physics_CU10_KainFritschCUP { 
# ==================================================================================
#  Configuration options for the Kain-Fritsch Cumulus Potential (CU_PHYSICS = 10) Cumulus Scheme
#
#    Multi-scale Kain-Fritsch cumulus potential scheme: The KF-CuP parameterization
#    of sub-grid scale clouds modifies the Kain-Fritsch ad-hoc trigger function with
#    one linked to boundary layer turbulence via probability density functions (PDFs)
#    using the cumulus potential (CuP) scheme. An additional modification is the
#    computation of cumulus cloud fraction based on the time scale relevant for shallow
#    cumuli.
#
#    Note: KF-CuP has only been tested using for the CAM radiation scheme (ra_sw_physics = 3,
#          ra_lw_physics = 3), although in theory it should work with any radiation package.
#
#      Moisture Tendencies: Qc,Qr,Qi,Qs
#      Momentum Tendencies: No
#      Shallow Convection:  Yes
#
#    Other parameters that are automatically set (regardless of user value):
#
#      *  shallowcu_forced_ra = FALSE  #  Do not override cloud fraction calculations
#      *  shcu_aerosols_opt   = 0      #  Do not include aerosols
#      *  cu_rad_feedback     = TRUE   #  Include the feedback of parameterized clouds on radiation
#
#    Ancillary parameters that may be set below:
#
#      *  numbins        -  Number of perturbations for potential temperature and specific humidity
#      *  thBinSize      -  Bin size of potential temperature perturbation increment (K)
#      *  rBinSize       -  Bin size of mixing ratio perturbation increment (kg/kg)
#      *  minDeepFreq    -  Minimum frequency required before deep convection is allowed
#      *  minShallowFreq -  Minimum frequency required before shallow convection is allowed
#
#    References:  Kain and Fritsch, 1990; Kain, 2004, Berg and Stull, 2005; Berg et al., 2013.
# ==================================================================================
#
    @{$Physics{numbins}}             = &Config_numbins();
    @{$Physics{thbinsize}}           = &Config_thbinsize();
    @{$Physics{rbinsize}}            = &Config_rbinsize();
    @{$Physics{mindeepfreq}}         = &Config_mindeepfreq();
    @{$Physics{minshallowfreq}}      = &Config_minshallowfreq();
    @{$Physics{cu_rad_feedback}}     = &Config_cu_rad_feedback(10);
    @{$Physics{shallowcu_forced_ra}} = &Config_shallowcu_forced_ra();
    @{$Physics{cudt}}                = &Config_cudt(10);


return;
}


sub Physics_CU11_KainFritschMS {
# ==================================================================================
#  Configuration options for the Kain-Fritsch Multi-Scale (CU_PHYSICS = 11) Cumulus Scheme
#
#    Multi-scale Kain-Fritsch scheme: This scheme includes (a) diagnosed deep and
#    shallow KF cloud fraction; (b) Scale-dependent Dynamic adjustment timescale for
#    KF clouds; (c) Scale-dependent LCL-based entrainment methodology; (d) Scale-
#    dependent fallout rate; (e) Scale-dependent stabilization capacity; (f) Estimation
#    and feedback of updraft vertical velocities back to gridscale vertical velocities;
#    (g) new Trigger function based on Bechtold method.
#
#    Comment: Must be used with YSU PBL; ICLOUD will automatically be set to 1
#
#      Moisture Tendencies: Qc,Qr,Qi,Qs
#      Momentum Tendencies: No
#      Shallow Convection:  Yes
#
#    Other parameters that are automatically set (regardless of user value):
#
#      *  cu_rad_feedback     = TRUE   #  Include the feedback of parameterized clouds on radiation
#
#    Ancillary options:
#      cudt          - Minutes between calls to CU scheme*
#      kfeta_trigger - Convective trigger
#
#      * The documentation only mentions CUDT with KF (1) but the source code clearly
#        uses CUDT with 1, 11, and the old KF-eta
#
#    Reference: Zheng et al. 2015, MWR
# ==================================================================================
#
    @{$Physics{cu_rad_feedback}} = &Config_cu_rad_feedback(11);
    @{$Physics{kfeta_trigger}}   = &Config_kfeta_trigger();
    @{$Physics{kf_edrates}}      = &Config_kf_edrates();
    @{$Physics{cudt}}            = &Config_cudt(11);


return;
}


sub Physics_CU14_ArakawaSchubert {
# ==================================================================================
#  Configuration options for the New Simpified Arakawa-Schubert (NSAS) (CU_PHYSICS = 14) Cumulus Scheme
#
#    New Simplified Arakawa-Schubert from YSU: New mass-flux scheme with deep
#    and shallow components and momentum transport.
#
#      Moisture Tendencies: Qc,Qr,Qi,Qs
#      Momentum Tendencies: Yes
#      Shallow Convection:  Yes
#
#    Ancillary options:
#      cudt         - Not used (automatically set to 0)
#
#    Reference: Han and Pan (2011, WAF)
# ==================================================================================
#
    @{$Physics{nsas_dx_factor}} = &Config_nsas_dx_factor();
    @{$Physics{cudt}}           = &Config_cudt(14);


return;
}


sub Physics_CU16_ModifedTiedTKE {
# ==================================================================================
#  Configuration options for the Hawaii Modifed Tiedtke (CU_PHYSICS = 16) Cumulus Scheme
#
#    A newer Tiedtke scheme (U. of Hawaii version):  Mass-flux type scheme with
#    CAPE-removal time scale, shallow component and momentum transport. This
#    version is similar to the Tiedtke scheme used in REGCM4 and ECMWF cy40r1.
#    Differences from the previous scheme include (a) New trigger functions for
#    deep and shallow convections; b) Non-equilibrium situations are considered
#    in the closure for deep convection; (c) New convection time scale for deep
#    convection closure; (d) New entrainment and detrainment rates for all convection
#    types; (e) New formula for conversion from cloud water/ice to rain/snow;
#    (f) Different way to include cloud scale pressure gradients.
#
#    Note: This option is experimental!
#
#      Moisture Tendencies: Qc,Qi
#      Momentum Tendencies: Yes
#      Shallow Convection:  Yes
#
#    Ancillary options:
#      cudt         - Not used (automatically set to 0)
#
#    Reference: Tiedtke (1989, MWR), Zhang et al. (2011, MWR)
# ==================================================================================
#
    @{$Physics{cudt}}          = &Config_cudt(16);


return;
}

sub Physics_CU84_ArakawaSchubert {
# ==================================================================================
#  Configuration options for the New Simpified Arakawa-Schubert (HWRF) (CU_PHYSICS = 84) Cumulus Scheme
#
#    New Simplified Arakawa-Schubert HWRF version: New mass-flux scheme with deep
#    and shallow components and momentum transport.
#
#      Moisture Tendencies: Qc,Qr,Qi,Qs
#      Momentum Tendencies: Yes
#      Shallow Convection:  Yes
#
#    Ancillary options:
#      cudt         - Not used (automatically set to 0)
#
#    Reference: Han and Pan (2011, WAF)
# ==================================================================================
#
    @{$Physics{nsas_dx_factor}} = &Config_nsas_dx_factor();
    @{$Physics{cudt}}           = &Config_cudt(84);


return;
}


sub Physics_CU93_GrellDevenyiEnsemble {
# ==================================================================================
#  Configuration options for the Grell-Devenyi Ensemble (CU_PHYSICS = 93) Cumulus Scheme
#
#    Grell-Devenyi ensemble scheme: Multi-closure, multi-parameter, ensemble
#    method with typically 144 sub-grid members. (Grell and Devenyi (2002, GRL).
#    Note that there are some additional configuration parameters for the Grell
#    ensemble scheme at the bottom of this file if you know what you are doing.
#    This scheme is not recommended for DX < 25km.
#
#    Comment: Scheme was previously option 3 in WRF V3.4
#
#      Moisture Tendencies: Qc,Qi
#      Momentum Tendencies: No
#      Shallow Convection:  No
#
#    Ancillary options:
#      cudt         - Not used (automatically set to 0)
#
#    Reference: Grell and Devenyi (2002, GRL)
# ==================================================================================
#
    @{$Physics{cu_rad_feedback}} = &Config_cu_rad_feedback(93);
    @{$Physics{maxiens}}         = &Config_maxiens();
    @{$Physics{maxens}}          = &Config_maxens();
    @{$Physics{maxens2}}         = &Config_maxens2();
    @{$Physics{maxens3}}         = &Config_maxens3();
    @{$Physics{ensdim}}          = &Config_ensdim();
    @{$Physics{cudt}}            = &Config_cudt(93);


return;
}

#
# ==================================================================================
# ==================================================================================
#      SO BEGINS THE INDIVIDUAL PARAMETER CONFIGURATION SUBROUTINES
# ==================================================================================
# ==================================================================================
#

sub Config_cudt {
# ==================================================================================
#   Option: CUDT - The number of minutes between calls to the cumulus scheme.
#
#   Values:
#           Set CUDT to the number of minutes (integer) between calls to the
#           Kain-Fritsch cumulus schemes. Set CUDT to 0 for every time step.
#
#           CUDT will automatically be set to 0 if you are NOT using KF
#
#           For obvious reasons CUDT is not used if CU_PHYSICS = 0.
#
# ==================================================================================
#
    my @cudt = (0) x $Config{maxdoms}; #  Default for all except CU = 1 or 11

    my $cu = shift;

    if ($cu == 1 or $cu == 11) {
        for (0..$Config{maxindex}) {$cudt[$_] = $Config{uconf}{CUDT}[$_] ? $Config{uconf}{CUDT}[$_] : $cudt[$Config{parentidx}[$_]];}
        @cudt = map {$Physics{cu_physics}[$_] ? $cudt[$_] : 0} 0..$Config{maxindex};
    } 


return @cudt;
}


sub Config_cugd_avedx {
# ==================================================================================
#   Option:  CUGD_AVEDX - The number of grid boxes over which subsidence is spread
#
#   Values:
#
#     Typically set to 1 (1 grid box) for large grid distances of greater than
#     10km but may be increased for smaller grid spacing (E.g., CUGD_AVEDX = 3
#     for DX < 5km). Set CUGD_AVEDX = Auto to have EMS determine an appropriate
#     value similar to that indicated above. Maximum value is 3 grid boxes.
#
#   Default:  CUGD_AVEDX = Auto
# ==================================================================================
#
use POSIX qw(ceil floor);

    my @cugd_avedx = ();

    my $dx = 0.001*$Rconf{dinfo}{domains}{1}{dx};

    $cugd_avedx[0] = ($Config{uconf}{CUGD_AVEDX}[0] =~ /^A/i) ? ($dx<= 10.) ? int ceil (15./$dx) : 1 : $Config{uconf}{CUGD_AVEDX}[0];
    $cugd_avedx[0] = 3 if $cugd_avedx[0] > 3;
    $cugd_avedx[0] = 1 if $cugd_avedx[0] < 1;


return @cugd_avedx;
}


sub Config_convtrans_avglen_m {
# ==================================================================================
#   Option:  CONVTRANS_AVGLEN_M - Averaging time for variables used by convective transport 
#                                 (Not EMS supported)
# ==================================================================================
#
    my @convtrans_avglen_m = ();

    @convtrans_avglen_m = (30); # Default (30)


return @convtrans_avglen_m;
}


sub Config_cu_rad_feedback {
# ==================================================================================
#   Option:  CU_RAD_FEEDBACK - Include the sub-grid cloud effects in the
#                              optical depth within the radiation schemes
#
#   Values:  T (include) or F (don't include)
#
#   Default: CU_RAD_FEEDBACK = T (Include)
#
#   Special Note (#%%^$&*!!!): The documentation (V3.7) is confusing/misleading/wrong 
#                              as too whether to use cu_rad_feedback with CU_PHYSICS = 10/11.
#                              The WRF namelist.README file says to use it with KF-CUP
#                              (kfcupscheme; CU_PHYSICS = 10) but the WRF source code
#                              only directly uses the value with CU_PHYSICS = 1 and
#                              indirectly (icloud_cu = 2) with CU_PHYSICS = 11. 
#
#                              So the UEMS solution to this mess is to automatically
#                              set CU_RAD_FEEDBACK = T for CU_PHYSICS = 10 & 11, and
#                              let the model sort it out.
# ==================================================================================
#
    my @cu_rad_feedback = ();

    my $cu = shift; 

    @cu_rad_feedback = @{$Config{uconf}{CU_RAD_FEEDBACK}};

    @cu_rad_feedback = ('T') if $cu == 10 or $cu == 11;  #  Must have


return @cu_rad_feedback;
}


sub Config_cu_diag {
# ==================================================================================
#   Option:  CU_DIAG - Additional t-averaged stuff for cu physics (Not EMS supported)
# ==================================================================================
#
    my @cu_diag = ();

    my $cu = shift;
                                      
    @cu_diag = (grep {/^$cu$/} (3,5,93)) ? (1) : (0); # Only supported with Grell & cu_rad_feedback = T


return @cu_diag;
}


sub Config_kfeta_trigger {
# ==================================================================================
#
#   Option:  KFETA_TRIGGER - Method used to determine whether CU scheme is active
#
#   Values:
#
#     1 - Original mass flux trigger method
#     2 - Moisture-advection based trigger (Ma and Tan [2009]) - ARW only
#         May improve results in subtropical regions when large-scale forcing is weak
#     3 - RH-dependent additional perturbation to option 1
#
#   Default:  KFETA_TRIGGER = 1
# ==================================================================================
#
    my @kfeta_trigger = @{$Config{uconf}{KFETA_TRIGGER}};


return @kfeta_trigger;
}


sub Config_kf_edrates  {
# ==================================================================================
#
#   Option: KF_EDRATES - Option to add entrainment/detrainment rates and 
#           convective timescale output variables for KF-based cumulus schemes.
#
#   Values:
#           0 - No additional output
#           1 - Yes please, even more output cause I can't get enough of this stuff
#
#   Default:  KF_EDRATES = 0
# ==================================================================================
#
    my @kf_edrates = @{$Config{uconf}{KF_EDRATES}};


return @kf_edrates;
}


sub Config_shcu_aerosols_opt {
# ==================================================================================
#   Option:  SHCU_AEROSOLS_OPT - Do not include aerosols (Used with WRF Chem only)
#
#   Default: SHCU_AEROSOLS_OPT = 0  (For all domains)
# ==================================================================================
#
    my @shcu_aerosols_opt = ();

    for (0..$Config{maxindex}) {$shcu_aerosols_opt[$_] = $Config{uconf}{SHCU_AEROSOLS_OPT}[$_] ? $Config{uconf}{SHCU_AEROSOLS_OPT}[$_] : $shcu_aerosols_opt[$Config{parentidx}[$_]];}
    @shcu_aerosols_opt = map {$Physics{cu_physics}[$_] ? $shcu_aerosols_opt[$_] : 0} 0..$Config{maxindex};


return @shcu_aerosols_opt;
}


sub Config_numbins {
# ==================================================================================
#   Option:  NUMBINS - Number of perturbations for potential temperature and
#                      mixing ratio in the CuP probability distribution function.
#
#   Values:
#
#     Should be an odd value (UEMS enforced) greater than 0. WRF default is 1
#     although the recommended value is 21
#
#   Default:  NUMBINS = value or parent with CU ; 0 if CU = 0 (explicit)
# ==================================================================================
#
    my @numbins = ();

    for (0..$Config{maxindex}) {$numbins[$_] = $Config{uconf}{NUMBINS}[$_] ? $Config{uconf}{NUMBINS}[$_] : $numbins[$Config{parentidx}[$_]];}

    @numbins = map {$Physics{cu_physics}[$_] ? $numbins[$_] : 0} 0..$Config{maxindex};


return @numbins;
}


sub Config_thbinsize {
# ==================================================================================
#   Option:  THBINSIZE - The bin size of potential temperature perturbation increment (K).
#
#   Default: THBINSIZE = 0.1  (Because thats what module_cu_kfcup.F says)
# ==================================================================================
#
    my @thbinsize = ();

    for (0..$Config{maxindex}) {$thbinsize[$_] = $Config{uconf}{THBINSIZE}[$_] ? $Config{uconf}{THBINSIZE}[$_] : $thbinsize[$Config{parentidx}[$_]];}

    @thbinsize = map {$Physics{cu_physics}[$_] ? $thbinsize[$_] : 0} 0..$Config{maxindex};


return @thbinsize;
}


sub Config_rbinsize {
# ==================================================================================
#   Option:  RBINSIZE - The bin size of mixing ratio perturbation increments (1.0e-4 kg/k).
#
#   Default: RBINSIZE = 0.0004  (Because thats what module_cu_kfcup.F says)
# ==================================================================================
#
    my @rbinsize = ();

    for (0..$Config{maxindex}) {$rbinsize[$_] = $Config{uconf}{RBINSIZE}[$_] ? $Config{uconf}{RBINSIZE}[$_] : $rbinsize[$Config{parentidx}[$_]];}

    @rbinsize = map {$Physics{cu_physics}[$_] ? $rbinsize[$_] : 0} 0..$Config{maxindex};


return @rbinsize;
}


sub Config_mindeepfreq {
# ==================================================================================
#   Option:  MINDEEPFREQ - minimum frequency required before deep convection is allowed.
#
#   Default: MINDEEPFREQ = 0.3333  (Because thats what the WRF guidance recommends:
#                                   http://www2.mmm.ucar.edu/wrf/users/wrfv3.8/KF-CuP.htm)
# ==================================================================================
#
    my @mindeepfreq = ();

    for (0..$Config{maxindex}) {$mindeepfreq[$_] = $Config{uconf}{MINDEEPFREQ}[$_] ? $Config{uconf}{MINDEEPFREQ}[$_] : $mindeepfreq[$Config{parentidx}[$_]];}

    @mindeepfreq = map {$Physics{cu_physics}[$_] ? $mindeepfreq[$_] : 0} 0..$Config{maxindex};


return @mindeepfreq;
}


sub Config_minshallowfreq {
# ==================================================================================
#   Option:  MINSHALLOWFREQ - minimum frequency required before deep convection is allowed.
#
#   Default: MINSHALLOWFREQ = 0.01  (Because thats what the WRF guidance recommends:
#                                    http://www2.mmm.ucar.edu/wrf/users/wrfv3.8/KF-CuP.htm)
# ==================================================================================
#
    my @minshallowfreq = ();

    for (0..$Config{maxindex}) {$minshallowfreq[$_] = $Config{uconf}{MINSHALLOWFREQ}[$_] ? $Config{uconf}{MINSHALLOWFREQ}[$_] : $minshallowfreq[$Config{parentidx}[$_]];}

    @minshallowfreq = map {$Physics{cu_physics}[$_] ? $minshallowfreq[$_] : 0} 0..$Config{maxindex};


return @minshallowfreq;
}


sub Config_shallowcu_forced_ra {
# ==================================================================================
#   Option:  SHALLOWCU_FORCED_RA - radiative impact of shallow Cu by a prescribed 
#                                  maximum cloud fraction
#
#   Default: SHALLOWCU_FORCED_RA = 'F' (For all domains)
# ==================================================================================
#
    my @shallowcu_forced_ra = ();

    for (0..$Config{maxindex}) {$shallowcu_forced_ra[$_] = $Config{uconf}{SHALLOWCU_FORCED_RA}[$_] ? $Config{uconf}{SHALLOWCU_FORCED_RA}[$_] : $shallowcu_forced_ra[$Config{parentidx}[$_]];}

    @shallowcu_forced_ra = map {$Physics{cu_physics}[$_] ? $shallowcu_forced_ra[$_] : 'F'} 0..$Config{maxindex};


return @shallowcu_forced_ra;
}


sub Config_nsas_dx_factor {
# ==================================================================================
#  Option:  NSAS_DX_FACTOR - Turns ON|OFF grid-size awareness
#
#   Values:
#
#     0 - Grid-size awareness method is OFF
#     1 - Grid-size awareness method is ON
#
#   Notes:   The functionality of this option is not well documented
#
#   Default: NSAS_DX_FACTOR = 0
# ==================================================================================
#
    my @nsas_dx_factor = ();

    @nsas_dx_factor = @{$Config{uconf}{NSAS_DX_FACTOR}};

return @nsas_dx_factor;
}


sub Config_maxiens {
# ==================================================================================
#   Option:   MAXIENS - Used for G3/G93 and that's about it
# ==================================================================================
#
    my @maxiens = (1); # Default (1)


return @maxiens;
}


sub Config_maxens {
# ==================================================================================
#   Option:   maxens - Used for G93 and that's about it
# ==================================================================================
#
    my @maxens = (3); # Default (3)


return @maxens;
}


sub Config_maxens2 {
# ==================================================================================
#   Option:   maxens2 - Used for G93 and that's about it
# ==================================================================================
#
    my @maxens2 = (3); # Default (3)


return @maxens2;
}


sub Config_maxens3 {
# ==================================================================================
#   Option:   maxens3 - Used for G93 and that's about it
# ==================================================================================
#
    my @maxens3 = (16); # Default (16)


return @maxens3;
}


sub Config_ensdim {
# ==================================================================================
#   Option:   ensdim - Used for G93 and that's about it
# ==================================================================================
#
    my @ensdim = (144); # Default (144)


return @ensdim;
}


sub Physics_MicroPhysics {
# ==============================================================================================
# WRF &PHYSICS NAMELIST CONFIGURATION FOR MICROPHYSICS SCHEMES AND RELATED STUFF
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This subroutine manages the configuration of all things microphysics scheme
#   in the &physics section of the WRF namelist file. 
#
#   Note that some (most) of the information used to produce the guidance presented
#   in this file was likely taken from the WRF user's guide and presentation materials,
#   and those authors should receive all the gratitude as well as any proceeds that 
#   may be derived from reading this information.
#
#   Some basic guidance to follow:
#
#   *  Single-moment schemes have one prediction equation for mass (kg/kg) per
#      species (Qr, Qs, etc.) with particle size distribution being diagnostic
#
#   *  Double-moment schemes add a prediction equation for number concentration
#      (#/kg) per double-moment species (Nr, Ns, etc.)
#
#   *  Double-moment schemes may only be double-moment for a few species
#
#   *  Double-moment schemes allow for additional processes such as size-sorting
#      during fall-out and sometimes aerosol effects on clouds
#
# ==============================================================================================
# ==============================================================================================
#
    @{$Ptables{micro}} = ();


    my %renv    = %{$Rconf{rtenv}};   #  Contains the  local configuration
    my %dinfo   = %{$Rconf{dinfo}};  #  just making things easier

    my @rundoms = sort {$a <=> $b} keys %{$dinfo{domains}}; #  Run-time domains in reverse order

    #-----------------------------------------------------------------------------
    #  PHYSICS Variable:  MP_PHYSICS - Microphysics scheme
    #
    #    Note: May not switch PBL schemes between domains!
    #
    #    MP options include:
    #
    #    0 - No MP scheme used - LES simulation
    #    1 - Kessler scheme
    #    2 - Purdue Lin et al. scheme
    #    3 - WSM 3-class scheme
    #    4 - WSM 5-class scheme
    #    5 - Ferrier (current NAM) scheme
    #    6 - WSM 6-class scheme
    #    7 - Goddard 6-class scheme
    #    8 - New Thompson et al. scheme 
    #    9 - Milbrandt-Yau 2-moment scheme
    #   10 - Morrison 2-moment scheme
    #   11 - CAM 5.1 (Like your home theater) DM 5 class scheme microphysics scheme
    #   13 - Stonybrook University (Y. Lin, SBU) scheme
    #   14 - WDM 5-class scheme
    #   16 - WDM 6-class scheme
    #   17 - NSSL 2-moment 7-class 4-ice scheme
    #   18 - NSSL 2-moment 7-class 4-ice scheme with predicted CCN (Idealized only)
    #   19 - NSSL single moment 7-class 4-ice scheme with graupel volume
    #   21 - NSSL single moment 6-class scheme with other options
    #   22 - NSSL 2-moment 6-class 3-ice scheme (no hail)
    #   28 - Thompson aerosol-aware scheme with water- and ice-friendly aerosol climatology
    #   30 - HUJI (Hebrew University of Jerusalem, Israel) spectral bin microphysics fast version
    #   32 - HUJI (Hebrew University of Jerusalem, Israel) spectral bin microphysics full version
    #   50 - P3 Predicted Particle Property scheme (Morrison and Milbrandt, 2015, JAS).
    #   51 - P3 Predicted Particle Property scheme with some other stuff (Morrison and Milbrandt, 2015, JAS).
    #-----------------------------------------------------------------------------
     
    #  The same physics scheme must be used for all domains. IT'S THE MODULE_CHECK_A_MUNDO.F LAW!
    #
    @{$Physics{mp_physics}} = @{$Config{uconf}{MP_PHYSICS}}; # Preconfigured in &ProcessLocalConfiguration

   
    #  ------------------------------ Additional MP_PHYSICS Configuration ---------------------------------------------
    #  If MP_PHYSICS is turn ON then complete additional configuration for the selected scheme.
    #  Note that the use of individual subroutines is not necessary since all the variables are
    #  global, but it make for cleaner code. Also - Most of the pre-configuration of user 
    #  defined variables was done in &ReadConfigurationFilesARW, the values from which
    #  used here. The only difficulty in writing this code was how to organize the individual
    #  variables that need to be set for each MP scheme. Some variables are valid for all schemes
    #  some for different schemes, and others for only one scheme.
    #
    #  So an executive decision was made for the cleanest solution. There are individual subroutines
    #  for each parameter, which are called from a separate subroutine for each MP scheme. Parameters
    #  that are always used together are combined into a single subroutine.  Hopefully it will all
    #  work out.
    #  ----------------------------------------------------------------------------------------------------------------
    #
    for ($Physics{mp_physics}[0]) {

        &Physics_MP00_NoMicrophysics()          if $_ ==  0; #  Configure Simulation without MP scheme (MP_PHYSICS = 0)
        &Physics_MP01_Kessler()                 if $_ ==  1; #  Configure Kessler Warm Rain (MP_PHYSICS = 1)
        &Physics_MP02_PurdueLin()               if $_ ==  2; #  Configure Purdue Lin et al. (MP_PHYSICS = 2)
        &Physics_MP03_WSM3Class()               if $_ ==  3; #  Configure WSM Single Moment 3-class (MP_PHYSICS = 3)
        &Physics_MP04_WSM5Class()               if $_ ==  4; #  Configure WSM Single Moment 5-class (MP_PHYSICS = 4)
        &Physics_MP05_Ferrier()                 if $_ ==  5; #  Configure Ferrier NAM (MP_PHYSICS = 5)
        &Physics_MP06_WSM6Class()               if $_ ==  6; #  Configure WSM Single Moment 6-class (MP_PHYSICS = 6)
        &Physics_MP07_Goddard()                 if $_ ==  7; #  Configure Goddard Single Moment 6-class (MP_PHYSICS = 7)
        &Physics_MP08_Thompson()                if $_ ==  8; #  Configure Thompson Single Moment 6-class (MP_PHYSICS = 8)
        &Physics_MP09_MilbrandtYau()            if $_ ==  9; #  Configure Milbrandt-Yau 7-class Double Moment (MP_PHYSICS = 9)
        &Physics_MP10_Morrison()                if $_ == 10; #  Configure Morrison Double Moment 6-class (MP_PHYSICS = 10)
        &Physics_MP11_CAM5Class()               if $_ == 11; #  Configure CAM 5.1 5-class Double Moment (MP_PHYSICS = 11)
        &Physics_MP13_Stonybrook()              if $_ == 13; #  Configure Stony Brook University/Y. Lin Scheme (MP_PHYSICS = 13)
        &Physics_MP14_WDM5Class()               if $_ == 14; #  Configure WDM Double Moment 5-class (MP_PHYSICS = 14)
        &Physics_MP16_WDM6Class()               if $_ == 16; #  Configure WDM Double Moment 6-class (MP_PHYSICS = 16)
        &Physics_MP17_NSSL7Class()              if $_ == 17; #  Configure NSSL Double Moment 7-class 4-ice (MP_PHYSICS = 17)
        &Physics_MP18_NSSL7ClassCCN()           if $_ == 18; #  Configure NSSL Double Moment 7-class 4-ice with predicted CCN (MP_PHYSICS = 18)
        &Physics_MP19_NSSL7ClassVg()            if $_ == 19; #  Configure NSSL Double Moment 7-class 4-ice with predicted Vg (MP_PHYSICS = 19)
        &Physics_MP21_NSSL6Class()              if $_ == 21; #  Configure NSSL Single Moment 6-class 4-ice & No hail (MP_PHYSICS = 21)
        &Physics_MP22_NSSLDM6Class()            if $_ == 22; #  Configure NSSL Double Moment 6-class 3-ice without hail (MP_PHYSICS = 22)
        &Physics_MP28_ThompsonAerosol()         if $_ == 28; #  Configure Thompson Double Moment 6-class Aerosol-Aware (MP_PHYSICS = 28)
        &Physics_MP30_HUJISpectralBinFast()     if $_ == 30; #  Configure HUJI Spectral Bin Microphysics Fast Version (MP_PHYSICS = 30)
        &Physics_MP32_HUJISpectralBinFull()     if $_ == 32; #  Configure HUJI FULL Spectral Bin Microphysics (MP_PHYSICS = 32)
        &Physics_MP50_PredictedParticle()       if $_ == 50; #  Configure P3 Predicted Particle Property scheme (MP_PHYSICS = 50)
        &Physics_MP51_PredictedParticlePlus()   if $_ == 51; #  Configure P3 Plus double-moment cloud water (MP_PHYSICS = 51)

        return 1 if $ENV{RMESG};

    }

    @{$Physics{no_mp_heating}}         =  &Config_no_mp_heating()      if $Physics{mp_physics}[0];
    @{$Physics{mp_zero_out}}           =  &Config_mp_zero_out();
    @{$Physics{mp_zero_out_thresh}}    =  &Config_mp_zero_out_thresh() if $Physics{mp_zero_out}[0];
    @{$Physics{do_radar_ref}}          =  &Config_do_radar_ref(); 


return;
}  #  Physics_MicroPhysics



sub Physics_MP00_NoMicrophysics {
# ==================================================================================
#  Configure Simulation without MP scheme (MP_PHYSICS = 0)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#

return;
}


sub Physics_MP01_Kessler {
# ==================================================================================
#  Configure Kessler Warm Rain (MP_PHYSICS = 1)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#

return;
}


sub Physics_MP02_PurdueLin {
# ==================================================================================
#  Configure Purdue Lin et al. (MP_PHYSICS = 2)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#

return;
}


sub Physics_MP03_WSM3Class {
# ==================================================================================
#  Configure WSM Single Moment 3-class (MP_PHYSICS = 3)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#

return;
}


sub Physics_MP04_WSM5Class {
# ==================================================================================
#  Configure WSM Single Moment 5-class (MP_PHYSICS = 4)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#

return;
}


sub Physics_MP05_Ferrier {
# ==================================================================================
#  Configure Ferrier NAM (MP_PHYSICS = 5)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#

    #------------------------------------------------------------
    #  Set the tables to be used by MP scheme
    #------------------------------------------------------------
    #
    my @mptables = qw(ETAMPNEW_DATA.expanded_rain);

    @{$Ptables{micro}} = &TableLocateMP(@mptables);


return;
}


sub Physics_MP06_WSM6Class {
# ==================================================================================
#  Configure WSM Single Moment 6-class (MP_PHYSICS = 6)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#
    @{$Physics{hail_opt}}  = &Config_hail_opt();


return;
}


sub Physics_MP07_Goddard {
# ==================================================================================
#  Configure Goddard Single Moment 6-class (MP_PHYSICS = 7)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#
    @{$Physics{gsfcgce_2ice}}  = &Config_gsfcgce_2ice();
    @{$Physics{gsfcgce_hail}}  = &Config_gsfcgce_hail();

return;
}


sub Physics_MP08_Thompson {
# ==================================================================================
#  Configure Thompson Single Moment 6-class (MP_PHYSICS = 8)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#

    #------------------------------------------------------------
    #  Set the tables to be used by MP scheme
    #------------------------------------------------------------
    #
    my @mptables = qw(freezeH2O.dat  qr_acr_qg.dat  qr_acr_qs.dat);

    @{$Ptables{micro}} = &TableLocateMP(@mptables);


return;
}


sub Physics_MP09_MilbrandtYau {
# ==================================================================================
#  Configure Milbrandt-Yau 7-class Double Moment (MP_PHYSICS = 9)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#

return;
}


sub Physics_MP10_Morrison {
# ==================================================================================
#  Configure Morrison Double Moment 6-class (MP_PHYSICS = 10)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#
    @{$Physics{hail_opt}}  = &Config_hail_opt();
    @{$Physics{progn}}     = &Config_progn();

return;
}


sub Physics_MP11_CAM5Class {
# ==================================================================================
#  Configure CAM 5.1 5-class Double Moment (MP_PHYSICS = 11)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#

return;
}


sub Physics_MP13_Stonybrook {
# ==================================================================================
#  Configure Stony Brook University/Y. Lin Scheme (MP_PHYSICS = 13)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#

return;
}


sub Physics_MP14_WDM5Class {
# ==================================================================================
#  Configure WDM Double Moment 5-class (MP_PHYSICS = 14)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#
    @{$Physics{ccn_conc}}  = &Config_ccn_conc();
    @{$Physics{progn}}     = &Config_progn();

return;
}


sub Physics_MP16_WDM6Class {
# ==================================================================================
#  Configure WDM Double Moment 6-class (MP_PHYSICS = 16)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#
    @{$Physics{hail_opt}}  = &Config_hail_opt();
    @{$Physics{ccn_conc}}  = &Config_ccn_conc();
    @{$Physics{progn}}     = &Config_progn();

return;
}


sub Physics_MP17_NSSL7Class {
# ==================================================================================
#  Configure NSSL Double Moment 7-class 4-ice (MP_PHYSICS = 17)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#
    my $dx = sprintf '%.1f', 0.001*$Rconf{dinfo}{domains}{1}{dx};
    &Ecomm::PrintMessage(6,11+$Rconf{arf},104,1,2,'The NSSL Double Moment schemes are designed for cloud resolving simulations (DX < 2km)') if $dx > 2.5;


    @{$Physics{nssl_alphah}}   = &Config_nssl_alphah();
    @{$Physics{nssl_alphahl}}  = &Config_nssl_alphahl();
    @{$Physics{nssl_cnoh}}     = &Config_nssl_cnoh();
    @{$Physics{nssl_cnohl}}    = &Config_nssl_cnohl();
    @{$Physics{nssl_cnor}}     = &Config_nssl_cnor();
    @{$Physics{nssl_cnos}}     = &Config_nssl_cnos();
    @{$Physics{nssl_rho_qh}}   = &Config_nssl_rho_qh();
    @{$Physics{nssl_rho_qhl}}  = &Config_nssl_rho_qhl();
    @{$Physics{nssl_rho_qs}}   = &Config_nssl_rho_qs();


return;
}


sub Physics_MP18_NSSL7ClassCCN {
# ==================================================================================
#  Configure NSSL Double Moment 7-class 4-ice with predicted CCN (MP_PHYSICS = 18)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#
    my $mesg = "The NSSL Double Moment with CCN (18) is best suited for idealized cases - You\'ve been warned";
    &Ecomm::PrintMessage(6,11+$Rconf{arf},104,1,2,'MP scheme choice not recommended:',$mesg);

    my $dx = sprintf '%.1f', 0.001*$Rconf{dinfo}{domains}{1}{dx};
    &Ecomm::PrintMessage(6,11+$Rconf{arf},104,1,2,'The NSSL Double Moment schemes are designed for cloud resolving simulations (DX < 2km)') if $dx > 2.5;
    
    @{$Physics{nssl_alphah}}   = &Config_nssl_alphah();
    @{$Physics{nssl_alphahl}}  = &Config_nssl_alphahl();
    @{$Physics{nssl_cnoh}}     = &Config_nssl_cnoh();
    @{$Physics{nssl_cnohl}}    = &Config_nssl_cnohl();
    @{$Physics{nssl_cnor}}     = &Config_nssl_cnor();
    @{$Physics{nssl_cnos}}     = &Config_nssl_cnos();
    @{$Physics{nssl_rho_qh}}   = &Config_nssl_rho_qh();
    @{$Physics{nssl_rho_qhl}}  = &Config_nssl_rho_qhl();
    @{$Physics{nssl_rho_qs}}   = &Config_nssl_rho_qs();


return;
}


sub Physics_MP19_NSSL7ClassVg {
# ==================================================================================
#  Configure NSSL Double Moment 7-class 4-ice with predicted Vg (MP_PHYSICS = 19)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#
    my $dx = sprintf '%.1f', 0.001*$Rconf{dinfo}{domains}{1}{dx};
    &Ecomm::PrintMessage(6,11+$Rconf{arf},104,1,2,'The NSSL Double Moment schemes are designed for cloud resolving simulations (DX < 2km)') if $dx > 2.5;


    @{$Physics{nssl_alphah}}   = &Config_nssl_alphah();
    @{$Physics{nssl_alphahl}}  = &Config_nssl_alphahl();
    @{$Physics{nssl_cnoh}}     = &Config_nssl_cnoh();
    @{$Physics{nssl_cnohl}}    = &Config_nssl_cnohl();
    @{$Physics{nssl_cnor}}     = &Config_nssl_cnor();
    @{$Physics{nssl_cnos}}     = &Config_nssl_cnos();
    @{$Physics{nssl_rho_qh}}   = &Config_nssl_rho_qh();
    @{$Physics{nssl_rho_qhl}}  = &Config_nssl_rho_qhl();
    @{$Physics{nssl_rho_qs}}   = &Config_nssl_rho_qs();

    @{$Physics{progn}}         = &Config_progn();

return;
}


sub Physics_MP21_NSSL6Class {
# ==================================================================================
#  Configure NSSL Single Moment 6-class 4-ice  (MP_PHYSICS = 21)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#
    my $dx = sprintf '%.1f', 0.001*$Rconf{dinfo}{domains}{1}{dx};
    &Ecomm::PrintMessage(6,11+$Rconf{arf},104,1,2,'The NSSL Double Moment schemes are designed for cloud resolving simulations (DX < 2km)') if $dx > 2.5;

    @{$Physics{nssl_alphah}}   = &Config_nssl_alphah();
    @{$Physics{nssl_cnoh}}     = &Config_nssl_cnoh();
    @{$Physics{nssl_cnor}}     = &Config_nssl_cnor();
    @{$Physics{nssl_cnos}}     = &Config_nssl_cnos();
    @{$Physics{nssl_rho_qh}}   = &Config_nssl_rho_qh();
    @{$Physics{nssl_rho_qs}}   = &Config_nssl_rho_qs();

    @{$Physics{progn}}         = &Config_progn();


return;
}


sub Physics_MP22_NSSLDM6Class {
# ==================================================================================
#  Configure NSSL Double Moment 6-class 3-ice without hail (MP_PHYSICS = 22)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#
    my $dx = sprintf '%.1f', 0.001*$Rconf{dinfo}{domains}{1}{dx};
    &Ecomm::PrintMessage(6,11+$Rconf{arf},104,1,2,'The NSSL Double Moment schemes are designed for cloud resolving simulations (DX < 2km)') if $dx > 2.5;

    @{$Physics{nssl_alphah}}   = &Config_nssl_alphah();
    @{$Physics{nssl_cnoh}}     = &Config_nssl_cnoh();
    @{$Physics{nssl_cnor}}     = &Config_nssl_cnor();
    @{$Physics{nssl_cnos}}     = &Config_nssl_cnos();
    @{$Physics{nssl_rho_qh}}   = &Config_nssl_rho_qh();
    @{$Physics{nssl_rho_qs}}   = &Config_nssl_rho_qs();


return;
}


sub Physics_MP28_ThompsonAerosol {
# ==================================================================================
#  Configure Thompson Double Moment 6-class Aerosol-Aware (MP_PHYSICS = 28)
#
#  Note: Although wif_input_opt & num_wif_levels are assigned in ARWfinal
#        routine because the parameters are part of the &domains namelist.
# ==================================================================================
#
    @{$Physics{use_aero_icbc}} = &Config_use_aero_icbc();

    #------------------------------------------------------------
    #  Set the tables to be used by MP scheme
    #------------------------------------------------------------
    #
    my @mptables = qw(CCN_ACTIVATE.BIN freezeH2O.dat  qr_acr_qg.dat  qr_acr_qs.dat);

    @{$Ptables{micro}} = &TableLocateMP(@mptables);


return;
}


sub Physics_MP30_HUJISpectralBinFast {
# ==================================================================================
#  Configure HUJI Spectral Bin Microphysics Fast Version (MP_PHYSICS = 30)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#

    #------------------------------------------------------------
    #  Set the tables to be used by MP scheme
    #------------------------------------------------------------
    #
    my @mptables = qw(capacity.asc masses.asc termvels.asc constants.asc kernels_z.asc
                      kernels.asc_s_0_03_0_9 bulkdens.asc_s_0_03_0_9 bulkradii.asc_s_0_03_0_9
                      coeff_p.asc coeff_q.asc);

    @{$Ptables{micro}} = &TableLocateMP(@mptables);


return;
}


sub Physics_MP32_HUJISpectralBinFull {
# ==================================================================================
#  Configure HUJI FULL Spectral Bin Microphysics (MP_PHYSICS = 32)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#

    #------------------------------------------------------------
    #  Set the tables to be used by MP scheme
    #------------------------------------------------------------
    #
    my @mptables = qw(capacity.asc masses.asc termvels.asc constants.asc kernels_z.asc 
                      kernels.asc_s_0_03_0_9 bulkdens.asc_s_0_03_0_9 bulkradii.asc_s_0_03_0_9
                      coeff_p.asc coeff_q.asc);
  
    @{$Ptables{micro}} = &TableLocateMP(@mptables);


return;
}


sub Physics_MP50_PredictedParticle {
# ==================================================================================
#  Configure P3 Predicted Particle Property (MP_PHYSICS = 50)
#
#  Predicted Particle Property scheme (Morrison and Milbrandt, 2015, JAS). This 
#  scheme represents ice-phase microphysics by several physical properties in 
#  space and time. The four prognostic variables are mixing ratios of total mass,  
#  rimed ice mass, rimed ice volume, and number. The liquid phase is double moment 
#  rain and ice. The scheme is coupled to RRTMG radiation. 10 cm radar reflectivity 
#  diagnosed. Uses data file, p3_lookup_table_1.dat.
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#

    #------------------------------------------------------------
    #  Set the tables to be used by MP scheme
    #------------------------------------------------------------
    #
    my @mptables = qw(p3_lookup_table_1.dat);

    @{$Ptables{micro}} = &TableLocateMP(@mptables);


return;
}


sub Physics_MP51_PredictedParticlePlus {
# ==================================================================================
#  Configure P3 Predicted Particle Property Plus (MP_PHYSICS = 51)
#
#  Predicted Particle Property scheme (Morrison and Milbrandt, 2015, JAS). This 
#  scheme represents ice-phase microphysics by several physical properties in 
#  space and time. The four prognostic variables are mixing ratios of total mass,  
#  rimed ice mass, rimed ice volume, and number. The liquid phase is double moment 
#  rain and ice. The scheme is coupled to RRTMG radiation. 10 cm radar reflectivity 
#  diagnosed. Uses data file, p3_lookup_table_1.dat. Like MP50 but adds 
#  supersaturation dependent activation and double-moment cloud water. 
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#

    #------------------------------------------------------------
    #  Set the tables to be used by MP scheme
    #------------------------------------------------------------
    #
    my @mptables = qw(p3_lookup_table_1.dat);

    @{$Ptables{micro}} = &TableLocateMP(@mptables);


return;
}



#
# ==================================================================================
# ==================================================================================
#      SO BEGINS THE INDIVIDUAL PARAMETER CONFIGURATION SUBROUTINES
# ==================================================================================
# ==================================================================================
#

sub Config_do_radar_ref {
# ==================================================================================
#   Option:  DO_RADAR_REF -  Turns ON|OFF the calculation of simulated reflectivity from the MP scheme
#                            
#
#   Values:
#
#     0 - Turn OFF calculation of simulated reflectivity
#     1 - Turn ON  calculation of simulated reflectivity
#
#   Default: DO_RADAR_REF = 1  (ALWAYS ON WITH UEMS)
#
#   Notes:   Only available MP Schemes 2, 4, 5, 6, 7, 8, 9, 10, 14, 16; however, the EMS adds
#            a calculation for Ferrier and the other schemes (basic).
#
#            Additionally - setting DO_RADAR_REF = 0 also turns off output of many 
#            UEMS variables for reasons unknown - so DO_RADAR_REF = 1 always
# ==================================================================================
#
    my @do_radar_ref = @{$Config{uconf}{DO_RADAR_REF}};


return @do_radar_ref;
}


sub Config_no_mp_heating {
# ==================================================================================
#   Option:  NO_MP_HEATING - Turning off latent heating from microphysics
#
#   Values:
#
#     0 - Do what you normally do and keep LH in the simulation
#     1 - Turn OFF heating
#
#   Notes:   If NO_MP_HEATING = 1 then CU_PHYSICS = 0
#
#   Default: NO_MP_HEATING = 0
# ==================================================================================
#
    my @no_mp_heating  = @{$Config{uconf}{NO_MP_HEATING}};

    my $mesg = "Interesting - Running a simulation with latent heating from microphysics turned OFF.\n".
            "              You go Captain Dangerous!";

    &Ecomm::PrintMessage(1,11+$Rconf{arf},96,1,2,$mesg) if $no_mp_heating[0];


return @no_mp_heating;
}


sub Config_mp_zero_out {
# ==================================================================================
#   Option:  MP_ZERO_OUT - Options for moisture field actions
#
#   Values:
#
#     0 - Do nothing and like it
#     1 - Except for Qv, all other moist arrays are set to zero if below MP_ZERO_OUT_THRESH
#     2 - Qv along with other moist arrays are set to zero if they fall below MP_ZERO_OUT_THRESH.
#         This method does not conserve total water but will not cause negative Q values.
#
#   Notes:   Don't use MP_ZERO_OUT unless PDA is OFF (default) in run_dynamics.conf, although
#            you really should use PDA rather than this option. If PDA is being used then
#            MP_ZERO_OUT will automatically be set to 0, and you will like it.
#
#            If you are running a global simulation, PDA will automatically be turned OFF
#            with MP_ZERO_OUT = 2 and MP_ZERO_OUT_THRESH = 1.e-8. This override was handled
#            in &ReadConfigurationFilesARW.
#
#   Default: MP_ZERO_OUT = 0
# ==================================================================================
#
    my @mp_zero_out = @{$Config{uconf}{MP_ZERO_OUT}};


return @mp_zero_out;
}


sub Config_mp_zero_out_thresh {
# ==================================================================================
#   Option:  MP_ZERO_OUT_THRESH - Moisture threshold value for MP_ZERO_OUT
#
#   Notes:   MP_ZERO_OUT_THRESH is the critical value for moisture variable threshold, below
#            which moist arrays (except for Qv) are set to zero (unit: kg/kg). A default might
#            be 1.e-8. Obviously not used if MP_ZERO_OUT = 0.
#
#   Default: MP_ZERO_OUT_THRESH = 1.e-8
# ==================================================================================
#
    my @mp_zero_out_thresh = @{$Config{uconf}{MP_ZERO_OUT_THRESH}};


return @mp_zero_out_thresh;
}



sub Config_ccn_conc {
# ==================================================================================
#   Option:  CCN_CONC - CCN Concentration value for WDM Schemes
#
#   Notes:   New for WRF Version 3.6 and not well documented
#
#   Default: CCN_CONC = 1.E8
# ==================================================================================
#
    my @ccn_conc = @{$Config{uconf}{CCN_CONC}};


return @ccn_conc;
}


sub Config_hail_opt {
# ==================================================================================
#   Option:  HAIL_OPT - Turn ON|OFF Hail option
#
#   Values:
#
#     0 - Hail option for MP scheme is OFF (Only Graupel today)
#     1 - Hail option for MP scheme is ON  (Hail and graupel will fall from the sky)
#
#   Notes:   New for WRF Version 3.7
#
#   Default: HAIL_OPT = 0
# ==================================================================================
#
    my @hail_opt = @{$Config{uconf}{HAIL_OPT}};


return @hail_opt;
}


sub Config_gsfcgce_2ice {
# ==================================================================================
#   Option:  GSFCGCE_2ICE - Run gsfcgce microphysics with snow, ice (plus GSFCGCE_HAIL setting)
#
#   Values:
#
#     0 - Run gsfcgce microphysics with snow, ice and graupel/hail
#     1 - Run gsfcgce microphysics with only ice and snow    (GSFCGCE_HAIL is ignored)
#     2 - Run gsfcgce microphysics with only ice and graupel (GSFCGCE_HAIL is ignored)
#
#   Notes:   GSFCGCE_HAIL is ignored if GSFCGCE_2ICE = 1 or 2 - Handled in &ReadConfigurationFilesARW
#
#   Default: GSFCGCE_2ICE = 0
# ==================================================================================
#

    my @gsfcgce_2ice = @{$Config{uconf}{GSFCGCE_2ICE}}; 


return @gsfcgce_2ice;
}


sub Config_gsfcgce_hail {
# ==================================================================================
#   Option:  GSFCGCE_HAIL - Running with graupel and/or hail
#
#   Values:
#
#     0 - Run gsfcgce microphysics with graupel
#     1 - Run gsfcgce microphysics with graupel and hail
#
#   Notes:   GSFCGCE_HAIL = 0 if GSFCGCE_2ICE = 1 or 2 - Handled in &ReadConfigurationFilesARW
#
#   Default: GSFCGCE_HAIL = 0
# ==================================================================================
#
    my @gsfcgce_hail = @{$Config{uconf}{GSFCGCE_HAIL}};


return @gsfcgce_hail;
}


sub Config_nssl_alphah {
# ==================================================================================
#   Option:   NSSL_ALPHAH  - Shape parameter for graupel
#
#   Notes:    Can set intercepts and particle densities For NSSL 1-moment schemes, the intercept
#             and particle densities can be set for snow, graupel, hail, and rain. For the 1-
#             and 2-moment schemes, the shape parameters for graupel and hail can be set.
#
#   Default:  NSSL_ALPHAH = 0.
# ==================================================================================
#
    my @nssl_alphah     = @{$Config{uconf}{NSSL_ALPHAH}};


return @nssl_alphah;
}


sub Config_nssl_alphahl {
# ==================================================================================
#   Option:   NSSL_ALPHAHL - Shape parameter for hail
#
#   Notes:    Can set intercepts and particle densities For NSSL 1-moment schemes, the intercept
#             and particle densities can be set for snow, graupel, hail, and rain. For the 1-
#             and 2-moment schemes, the shape parameters for graupel and hail can be set.
#
#   Default:  NSSL_ALPHAHL = 2.
# ==================================================================================
#
    my @nssl_alphahl    = @{$Config{uconf}{NSSL_ALPHAHL}};


return @nssl_alphahl;
}


sub Config_nssl_cnoh {
# ==================================================================================
#   Option:   NSSL_CNOH    - Graupel intercept
#
#   Notes:    Can set intercepts and particle densities For NSSL 1-moment schemes, the intercept
#             and particle densities can be set for snow, graupel, hail, and rain. For the 1-
#             and 2-moment schemes, the shape parameters for graupel and hail can be set.
#
#   Default:  NSSL_CNOH = 4.e5
# ==================================================================================
#
    my @nssl_cnoh       = @{$Config{uconf}{NSSL_CNOH}};


return @nssl_cnoh;
}


sub Config_nssl_cnohl {
# ==================================================================================
#   Option:   NSSL_CNOHL   - Hail intercept
#
#   Notes:    Can set intercepts and particle densities For NSSL 1-moment schemes, the intercept
#             and particle densities can be set for snow, graupel, hail, and rain. For the 1-
#             and 2-moment schemes, the shape parameters for graupel and hail can be set.
#
#   Default:  NSSL_CNOHL = 4.e4
# ==================================================================================
#
    my @nssl_cnohl      = @{$Config{uconf}{NSSL_CNOHL}};


return @nssl_cnohl;
}


sub Config_nssl_cnor {
# ==================================================================================
#   Option:   NSSL_CNOR    - Rain intercept
#
#   Notes:    Can set intercepts and particle densities For NSSL 1-moment schemes, the intercept
#             and particle densities can be set for snow, graupel, hail, and rain. For the 1-
#             and 2-moment schemes, the shape parameters for graupel and hail can be set.
#
#   Default:  NSSL_CNOR = 8.e5
# ==================================================================================
#
    my @nssl_cnor       = @{$Config{uconf}{NSSL_CNOR}};


return @nssl_cnor;
}


sub Config_nssl_cnos {
# ==================================================================================
#   Option:   NSSL_CNOS    - Snow intercept
#
#   Notes:    Can set intercepts and particle densities For NSSL 1-moment schemes, the intercept
#             and particle densities can be set for snow, graupel, hail, and rain. For the 1-
#             and 2-moment schemes, the shape parameters for graupel and hail can be set.
#
#   Default:  NSSL_CNOS = 3.e6
# ==================================================================================
#
    my @nssl_cnos       = @{$Config{uconf}{NSSL_CNOS}};


return @nssl_cnos;
}


sub Config_nssl_rho_qh {
# ==================================================================================
#   Option:   NSSL_RHO_QH  - Graupel density
#
#   Notes:    Can set intercepts and particle densities For NSSL 1-moment schemes, the intercept
#             and particle densities can be set for snow, graupel, hail, and rain. For the 1-
#             and 2-moment schemes, the shape parameters for graupel and hail can be set.
#
#   Default:  NSSL_RHO_QH = 500.
# ==================================================================================
#
    my @nssl_rho_qh     = @{$Config{uconf}{NSSL_RHO_QH}};


return @nssl_rho_qh;
}


sub Config_nssl_rho_qhl {
# ==================================================================================
#   Option:   NSSL_RHO_QHL - Hail density
#
#   Notes:    Can set intercepts and particle densities For NSSL 1-moment schemes, the intercept
#             and particle densities can be set for snow, graupel, hail, and rain. For the 1-
#             and 2-moment schemes, the shape parameters for graupel and hail can be set.
#
#   Default:  NSSL_RHO_QHL = 900.
# ==================================================================================
#
    my @nssl_rho_qhl    = @{$Config{uconf}{NSSL_RHO_QHL}};


return @nssl_rho_qhl;
}


sub Config_nssl_rho_qs {
# ==================================================================================
#   Option:   NSSL_RHO_QS  - Snow density
#
#   Notes:    Can set intercepts and particle densities For NSSL 1-moment schemes, the intercept
#             and particle densities can be set for snow, graupel, hail, and rain. For the 1-
#             and 2-moment schemes, the shape parameters for graupel and hail can be set.
#
#   Default:  NSSL_RHO_QS = 100.
# ==================================================================================
#
    my @nssl_rho_qs     = @{$Config{uconf}{NSSL_RHO_QS}};


return @nssl_rho_qs;
}


sub Config_progn {
# ==================================================================================
#   Option:  PROGN -  Switch to use mix-activate scheme
#
#   Values:
#
#     0 - Do not use mix-activate scheme because I have no idea what it does
#     1 - I don't care what happens, I want it!
#
#   Notes:   New for WRF Version 3.7 and not well documented
#
#   Default: PROGN = 0  (OFF)
# ==================================================================================
#
    my @progn     = @{$Config{uconf}{PROGN}};


return @progn;
}


sub Config_mp_tend_lim {
# ==================================================================================
#   Option:  MP_TEND_LIM - Limit on temp tendency from mp latent heating from radar data assimilation
#
#   Notes:   In the event that the temperature field does not include the effects of that
#            MCS in your radar data, don't try to add all the heat at once.
#
#            This option is currently turned OFF in phys_final.pm
#
#   Default: MP_TEND_LIM = 10.  (Not activated in UEMS)
# ==================================================================================
#
    my @mp_tend_lim = (10.);


return @mp_tend_lim;
}


sub Config_use_aero_icbc {
# ==================================================================================
#   Option:  USE_AERO_ICBC - Source of climatological aerosol input data
#
#   Values:
#
#     T - Use input from WPS (Must run ems_prep with "--aerosol" flag)
#     F - Use Constant values pre-defined in routine
#
#   Default: USE_AERO_ICBC = T
# ==================================================================================
#
    my @use_aero_icbc = @{$Config{uconf}{USE_AERO_ICBC}};

    #  If USE_AERO_ICBC = T then check whether the --aerosol flag was passed during ems_prep.
    #
    if ($use_aero_icbc[0] eq 'T' and ! $Rconf{rtenv}{qnwfa}) {
        my $mesg = "You have requested the Thompson \"Aerosol Aware\" microphysics scheme (MP_PHYSICS = 28) along with the ".
                   "WPS netCDF files (in wpsprd/) as the source of the climatological aerosol data (USE_AERO_ICBC = T); ".
                   "however, it appears that these data were not included in the initialization files. This issue may be caused ".
                   "by not including the \"--aerosol\" flag when running ems_prep, or that there are no compatible aerosol data ".
                   "for the initialization dataset.\n\n".

                   "Hope is not lost however, as the UEMS will use the constant aerosol values pre-defined in the Thompson scheme ".
                   "(USE_AERO_ICBC = F), which are intended for such an emergency.\n\n".

                   "For additional information regarding the initialization with climatological aerosol input data, please see: ".
                   "\"ems_prep --help aerosol\".  We'll both be glad you did.";

        &Ecomm::PrintMessage(6,11+$Rconf{arf},88,1,2,'Climatological Aerosol Data Not Available:',$mesg);

        @use_aero_icbc = ('F');
    }


return @use_aero_icbc;
}


sub TableLocateMP {
# ==================================================================================
#  This routine just tests whether the required MP tables are available. It 
#  fails if a table is missing; otherwise it returns an array containing the
#  absolute path to the table file.
# ==================================================================================
#
    my @mistbl = ();
    my @mptbls = ();

    my $dmicro = "$ENV{DATA_TBLS}/wrf/physics/micro";  # Tables located under $EMS_DATA/tables/wrf/physics/micro

    my @tables = @_;  return () unless @tables; @tables = sort @tables;

    foreach (@tables) { -f "$dmicro/$_" ? push @mptbls  => "$dmicro/$_" : push @mistbl => $_;}

    if (@mistbl) {  #  Oops - Some required tables are missing

        my @lines = ("Missing Microphysics Tables\n");
 
        push @lines, "The MP physics scheme you have chosen requires the following tables files located ".
                     "in the $dmicro/ directory:";
 
        foreach my $table (@tables) {push @lines,sprintf("X04X%-18s %14s",$table,(grep {/^$table$/} @mistbl) ? '<- Missing!' : '');}
 
        push @lines, "\nEither you promptly locate the missing table files or change your microphysics scheme for this simulation; ".
                     "otherwise, you will be reading these words again.\n\nBut next time, they will be sung by an army of clowns.";
 
        $ENV{RMESG} = join "\n", @lines;

        return ();

    }


return @mptbls;
}
                

sub Physics_Radiation {
# ==============================================================================================
# WRF &PHYSICS NAMELIST CONFIGURATION FOR RADIATION SCHEMES AND RELATED STUFF
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This subroutine manages the configuration of all things Radiation scheme
#   in the &physics section of the WRF namelist file. 
#
#   Note that some (most) of the information used to produce the guidance presented
#   in this file was likely taken from the WRF user's guide and presentation materials,
#   and those authors should receive all the gratitude as well as any proceeds that 
#   may be derived from reading this information.
#
#   Some basic guidance to follow:
#
#   *  Slope effects available for all SW options
#
#      Represents effect of slope on surface solar flux accounting for diffuse/direct effects
#
# ==============================================================================================
# ==============================================================================================
#
    @{$Ptables{radn}} = ();

    #-----------------------------------------------------------------------------
    #    Note: May not switch Radiation schemes between domains!
    #
    #    Long & short wave radiation options include:
    #
    #    0 - No Radiation scheme used - LES simulation 
    #    1 - Rapid Radiative Transfer Model (RRTM) (default)
    #    2 - Goddard shortwave (RA_SW_PHYSICS only) 
    #    3 - CAM3 scheme
    #    4 - New Rapid Radiative Transfer Model (RRTM3)
    #    5 - New Goddard scheme 
    #    7 - Fu-Long-Gu (FLG) (UCLA) scheme
    #   24 - Faster Newer Rapid Radiative Transfer Model (RRTM3)
    #   31 - Held-Suarez relaxation term (idealized simulations)
    #-----------------------------------------------------------------------------
    #
     
    #  The same physics scheme must be used for all domains. IT'S THE MODULE_CHECK_A_MUNDO.F LAW!
    #
    @{$Physics{ra_lw_physics}} = @{$Config{uconf}{RA_LW_PHYSICS}}; # Preconfigured in &ProcessLocalConfiguration
    @{$Physics{ra_sw_physics}} = @{$Config{uconf}{RA_SW_PHYSICS}}; # Preconfigured in &ProcessLocalConfiguration

   
    #  ------------------- Additional RA_LW_PHYSICS & RA_SW_PHYSICS Configuration -------------------------------------
    #  Complete additional configuration for the selected RA_LW_PHYSICS & RA_SW_PHYSICS scheme.
    #  Note that the use of individual subroutines is not necessary since all the variables are
    #  global, but it make for cleaner code. Also - Most of the pre-configuration of user 
    #  defined variables was done in &ReadConfigurationFilesARW, the values from which
    #  used here. The only difficulty in writing this code was how to organize the individual
    #  variables that need to be set for each RA scheme. Some variables are valid for all schemes
    #  some for different schemes, and others for only one scheme.
    #
    #  So an executive decision was made for the cleanest solution. There are individual subroutines
    #  for each parameter, which are called from a separate subroutine for each radiation scheme. 
    #  Hopefully it will all work out.
    #  ----------------------------------------------------------------------------------------------------------------
    #
    for ($Physics{ra_lw_physics}[0]) {

        &Physics_LW00_NoRadiation()          if $_ ==  0; #  Configure Simulation without LW scheme (RA_LW_PHYSICS = 0)
        &Physics_LW01_RRTM()                 if $_ ==  1; #  Configure Rapid Radiative Transfer Model (RA_LW_PHYSICS = 1)
        &Physics_LW03_CAM3()                 if $_ ==  3; #  Configure CAM3 Longwave Radiation Scheme (RA_LW_PHYSICS = 3)
        &Physics_LW04_RRTMG()                if $_ ==  4; #  Configure Newer Rapid Radiative Transfer Model (RA_LW_PHYSICS = 4)
        &Physics_LW05_NewGoddard()           if $_ ==  5; #  Configure New Goddard (GFDL) Scheme (RA_LW_PHYSICS = 5)
        &Physics_LW07_FuLongGu()             if $_ ==  7; #  Configure Fu-Liou-Gu Scheme (UCLA) (RA_LW_PHYSICS = 7)
        &Physics_LW24_RRTMGF()               if $_ == 24; #  Configure Faster Newer Rapid Radiative Transfer Model (RA_LW_PHYSICS = 24)

        return 1 if $ENV{RMESG};

    }

 
    for ($Physics{ra_sw_physics}[0]) {

        &Physics_SW00_NoRadiation()          if $_ ==  0; #  Configure Simulation without Shortwave Scheme (RA_SW_PHYSICS = 0)
        &Physics_SW01_Dudia()                if $_ ==  1; #  Configure Dudia Shortwave (RA_SW_PHYSICS = 1)
        &Physics_SW02_Goddard()              if $_ ==  2; #  Configure Goddard (GFDL) SW Scheme (RA_SW_PHYSICS = 2)
        &Physics_SW03_CAM3()                 if $_ ==  3; #  Configure CAM3 Shortwave Radiation Scheme (RA_SW_PHYSICS = 3)
        &Physics_SW04_RRTMG()                if $_ ==  4; #  Configure Newer Rapid Radiative Transfer Model (RA_SW_PHYSICS = 4)
        &Physics_SW05_NewGoddard()           if $_ ==  5; #  Configure New Goddard (GFDL) Scheme (RA_SW_PHYSICS = 5)
        &Physics_SW07_FuLongGu()             if $_ ==  7; #  Configure Fu-Liou-Gu Scheme (UCLA) (RA_SW_PHYSICS = 7)
        &Physics_SW24_RRTMGF()               if $_ == 24; #  Configure Faster Newer Rapid Radiative Transfer Model (RA_SW_PHYSICS = 24)

        return 1 if $ENV{RMESG};

    }

    @{$Physics{ra_call_offset}} =  &Config_ra_call_offset();
    @{$Physics{icloud}}         =  &Config_icloud();
    @{$Physics{swint_opt}}      =  &Config_swint_opt();
    @{$Physics{slope_rad}}      =  &Config_slope_rad();
    @{$Physics{topo_shading}}   =  &Config_topo_shading();
    @{$Physics{shadlen}}        =  &Config_shadlen() if grep {/^1$/} @{$Physics{topo_shading}};

    @{$Physics{radt}}           =  &Config_radt();

    @{$Ptables{radn}}           =  &Others::rmdups(@{$Ptables{radn}});


return;
}  #  Physics_Radiation



sub Physics_LW00_NoRadiation {
# ==================================================================================
#  Configure Simulation without LW scheme (RA_LW_PHYSICS = 0)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#


return;
}


sub Physics_LW01_RRTM {
# ==================================================================================
#  Configure Rapid Radiative Transfer Model (RA_LW_PHYSICS = 1)
#
#    RRTM scheme: Rapid Radiative Transfer Model. An accurate spectral scheme
#    using look-up tables for efficiency. Accounts for multiple bands, trace
#    gases, and microphysics species. Interacts with clouds.  For trace gases,
#    the volume-mixing ratio values for CO2 = 379e-6, N2O = 319e-9 and CH4 = 1774e-9,
#    which are updated from pre-V3.5 values (CO2 = 330e-6, N2O = 0. and CH4 = 0).
#    (Mlawer et al 1997).
#
# ==================================================================================
#
    @{$Physics{icloud}}                =  &Config_icloud();

    #-------------------------------------------------------------------------------
    #  Specify lookup tables used by scheme
    #-------------------------------------------------------------------------------
    #
    my @ratables = qw(RRTM_DATA CAMtr_volume_mixing_ratio);

    @{$Ptables{radn}} = (@{$Ptables{radn}}, &TableLocateRA('longwave',@ratables));


return;
}


sub Physics_LW03_CAM3 {
# ==================================================================================
#  Configure CAM3 Longwave Radiation Scheme (RA_LW_PHYSICS = 3)
#
#    CAM3 Longwave Radiation Scheme (ARW only): A spectral scheme with 8 long-wave
#    bands. Scheme allows for interactions with clouds (RH-based cloud fraction
#    when RH < 1), trace gasses, and aerosols. Ozone profile is a function
#    of the month and latitude only). It uses yearly CO2, and constant N2O (311e-9)
#    and CH4 (1714e-9).
#
# ==================================================================================
#
    @{$Physics{levsiz}}                =  &Config_levsiz();
    @{$Physics{paerlev}}               =  &Config_paerlev();
    @{$Physics{cam_abs_dim1}}          =  &Config_cam_abs_dim1();
    @{$Physics{cam_abs_freq_s}}        =  &Config_cam_abs_freq_s();

    #-------------------------------------------------------------------------------
    #  Specify lookup tables used by scheme
    #-------------------------------------------------------------------------------
    #
    my @ratables = qw(CAM_ABS_DATA CAM_AEROPT_DATA CAMtr_volume_mixing_ratio 
                      ozone.formatted ozone_lat.formatted ozone_plev.formatted);

    @{$Ptables{radn}} = (@{$Ptables{radn}}, &TableLocateRA('longwave',@ratables));


return;
}


sub Physics_LW04_RRTMG {
# ==================================================================================
#  Configure Newer Rapid Radiative Transfer Model (RA_LW_PHYSICS = 4)
#
#    RRTMG scheme (ARW only): Rapid Radiative Transfer Model with a G at the end.
#    An updated version of the RRTM scheme including MCICA method of random cloud
#    overlap. Uses 16 long-wave Bands (K-distribution), look-up tables fit to
#    accurate calculations, cloud, trace gas and aerosol interactions. Ozone and
#    CO2 profiles are specified (CO2 = 379e-6, N2O = 319e-9, CH4 = 1774e-9).
#
#    Notes: The  default ozone used in the scheme only varies with height. To use
#           use the CAM ozone dataset, use O3INPUT = 2 (Below)
#
#           The default is for the aerosol option to be turned OFF AER_OPT = 0
#
# ==================================================================================
#
    @{$Physics{icloud}}                =  &Config_icloud();
    @{$Physics{use_mp_re}}             =  &Config_use_mp_re();

    @{$Physics{o3input}}               =  &Config_o3input();
    @{$Physics{aer_opt}}               =  &Config_aer_opt();

    @{$Physics{alevsiz}}               =  &Config_alevsiz()          if $Physics{aer_opt}[0] == 1;
    @{$Physics{no_src_types}}          =  &Config_no_src_types()     if $Physics{aer_opt}[0] == 1;

    @{$Physics{aer_aod550_opt}}        =  &Config_aer_aod550_opt()   if $Physics{aer_opt}[0] == 2;
    @{$Physics{aer_aod550_val}}        =  &Config_aer_aod550_val()   if $Physics{aer_opt}[0] == 2;
    @{$Physics{aer_angexp_opt}}        =  &Config_aer_angexp_opt()   if $Physics{aer_opt}[0] == 2;
    @{$Physics{aer_angexp_val}}        =  &Config_aer_angexp_val()   if $Physics{aer_opt}[0] == 2;
    @{$Physics{aer_ssa_opt}}           =  &Config_aer_ssa_opt()      if $Physics{aer_opt}[0] == 2;
    @{$Physics{aer_ssa_val}}           =  &Config_aer_ssa_val()      if $Physics{aer_opt}[0] == 2;
    @{$Physics{aer_asy_opt}}           =  &Config_aer_asy_opt()      if $Physics{aer_opt}[0] == 2;
    @{$Physics{aer_asy_val}}           =  &Config_aer_asy_val()      if $Physics{aer_opt}[0] == 2;


    #-------------------------------------------------------------------------------
    #  Specify lookup tables used by scheme
    #-------------------------------------------------------------------------------
    #
    my @ratables = qw(RRTMG_LW_DATA CAM_AEROPT_DATA CAMtr_volume_mixing_ratio 
                      ozone.formatted ozone_lat.formatted ozone_plev.formatted);

    @{$Ptables{radn}} = (@{$Ptables{radn}}, &TableLocateRA('longwave',@ratables));


return;
}


sub Physics_LW05_NewGoddard {
# ==================================================================================
#  Configure New Goddard (GFDL) Scheme (RA_LW_PHYSICS = 5)
#
#    New Goddard (GFDL) scheme: Efficient, multiple bands, ozone from climatology.
#    It uses constant CO2 = 337e-6, N2O = 320e-9, CH4 = 1790e-9
#
# ==================================================================================
#

    #-------------------------------------------------------------------------------
    #  Specify lookup tables used by scheme
    #-------------------------------------------------------------------------------
    #
    my @ratables = qw(tr49t67 tr49t85 tr67t85 co2_trans);

    @{$Ptables{radn}} = (@{$Ptables{radn}}, &TableLocateRA('longwave',@ratables));


return;
}


sub Physics_LW07_FuLongGu {
# ==================================================================================
#  Configure Fu-Liou-Gu Scheme (UCLA) (RA_LW_PHYSICS = 7)
#
#    Fu-Liou-Gu scheme (UCLA):  Multiple bands, cloud and cloud fraction effects,
#    ozone profile from climatology (CO2 = 345e-6).
#
# ==================================================================================
#


return;
}


sub Physics_LW24_RRTMGF {
# ==================================================================================
#  Configure Faster Newer Rapid Radiative Transfer Model (RA_LW_PHYSICS = 24)
#
#    Super faster RRTMG scheme (ARW only): A faster, sexier version of the Rapid
#    Radiative Transfer Model with a G at the end. It's just like option 4, only
#    faster, and possibly a bit shinier. And who doesn't want that?
#
# ==================================================================================
#
    @{$Physics{icloud}}                =  &Config_icloud();
    @{$Physics{use_mp_re}}             =  &Config_use_mp_re();

    @{$Physics{o3input}}               =  &Config_o3input();
    @{$Physics{aer_opt}}               =  &Config_aer_opt();

    @{$Physics{alevsiz}}               =  &Config_alevsiz()          if $Physics{aer_opt}[0] == 1;
    @{$Physics{no_src_types}}          =  &Config_no_src_types()     if $Physics{aer_opt}[0] == 1;

    @{$Physics{aer_aod550_opt}}        =  &Config_aer_aod550_opt()   if $Physics{aer_opt}[0] == 2; 
    @{$Physics{aer_aod550_val}}        =  &Config_aer_aod550_val()   if $Physics{aer_opt}[0] == 2; 
    @{$Physics{aer_angexp_opt}}        =  &Config_aer_angexp_opt()   if $Physics{aer_opt}[0] == 2; 
    @{$Physics{aer_angexp_val}}        =  &Config_aer_angexp_val()   if $Physics{aer_opt}[0] == 2;
    @{$Physics{aer_ssa_opt}}           =  &Config_aer_ssa_opt()      if $Physics{aer_opt}[0] == 2;
    @{$Physics{aer_ssa_val}}           =  &Config_aer_ssa_val()      if $Physics{aer_opt}[0] == 2;
    @{$Physics{aer_asy_opt}}           =  &Config_aer_asy_opt()      if $Physics{aer_opt}[0] == 2;
    @{$Physics{aer_asy_val}}           =  &Config_aer_asy_val()      if $Physics{aer_opt}[0] == 2;

    
    #-------------------------------------------------------------------------------
    #  Specify lookup tables used by scheme
    #-------------------------------------------------------------------------------
    #
    my @ratables = qw(RRTMG_LW_DATA CAM_AEROPT_DATA CAMtr_volume_mixing_ratio 
                      ozone.formatted ozone_lat.formatted ozone_plev.formatted);

    @{$Ptables{radn}} = (@{$Ptables{radn}}, &TableLocateRA('longwave',@ratables));



return;
}


sub Physics_SW00_NoRadiation {
# ==================================================================================
#  Configure Simulation without Shortwave scheme (RA_SW_PHYSICS = 0)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#


return;
}


sub Physics_SW01_Dudia {
# ==================================================================================
#  Configure Dudia Shortwave Radiation Scheme (RA_SW_PHYSICS = 1)
#
#    Dudhia scheme: Simple downward integration allowing efficiently for clouds
#    and clear-sky absorption and scattering. Does not account for aerosols and
#    is tuned for Kansas so locations with more pollution (air) may see a
#    positive bias in the downward surface fluxes (dudhia 1989).
#
#      Microphysics interactions : Qc,Qr,Qi,Qs, and Qg
#      Cloud fraction            : 1|0  (No cloud|Cloud - no fraction)
#      Ozone effects             : None
#
#    RA_SW_PHYSICS = 1 has the following ancillary options (see bottom of file):
#
#      SWRAD_SCAT - Used to increase aerosols scattering if you don't like Kansas
#      ICLOUD     - Cloud effect to the optical depth
#
# ==================================================================================
#
    @{$Physics{icloud}}                =  &Config_icloud();
    @{$Physics{swrad_scat}}            =  &Config_swrad_scat();

    #-------------------------------------------------------------------------------
    #  Specify lookup tables used by scheme
    #-------------------------------------------------------------------------------
    #
    my @ratables = qw(RRTM_DATA CAMtr_volume_mixing_ratio);

    @{$Ptables{radn}} = (@{$Ptables{radn}}, &TableLocateRA('shortwave',@ratables));


return;
}


sub Physics_SW02_Goddard {
# ==================================================================================
#  Configure Goddard Shortwave Radiation Scheme (RA_SW_PHYSICS = 2)
#
#    Goddard (GFDL) shortwave: Two-stream multi-band (8) scheme with ozone from
#    climatology and cloud effects. Increases computational time (3x) at radiation
#    call times (RADT) but not during between times. Ozone profile is function
#    season and region (tropics, mid-latitude, polar). Fixed CO2. (Chou and Suarez 1994).
#
#      Microphysics interactions : Qc,Qi
#      Cloud fraction            : 1|0  (No cloud|Cloud - no fraction)
#      Ozone effects             : 5 profiles
#
# ==================================================================================
#


return;
}


sub Physics_SW03_CAM3 {
# ==================================================================================
#  Configure CAM3 Shortwave Radiation Scheme (RA_SW_PHYSICS = 3)
#
#    CAM3 Shortwave Radiation Scheme: 19-band spectral method. Can interact with
#    clouds. Same CO2/Ozone profiles as in CAM3 longwave scheme. Interacts with
#    aerosols and trace gases. Additional configuration options are found in the
#    ancillary configuration section.
#
#      Microphysics interactions : Qc,Qi,Qs
#      Cloud fraction            : Max-rand overlap
#      Ozone effects             : Latitude & monthly variability
#
# ==================================================================================
#
    @{$Physics{levsiz}}                =  &Config_levsiz();
    @{$Physics{paerlev}}               =  &Config_paerlev();
    @{$Physics{cam_abs_dim1}}          =  &Config_cam_abs_dim1();
    @{$Physics{cam_abs_freq_s}}        =  &Config_cam_abs_freq_s();

    #-------------------------------------------------------------------------------
    #  Specify lookup tables used by scheme
    #-------------------------------------------------------------------------------
    #
    my @ratables = qw(CAM_ABS_DATA CAM_AEROPT_DATA CAMtr_volume_mixing_ratio 
                      ozone.formatted ozone_lat.formatted ozone_plev.formatted);

    @{$Ptables{radn}} = (@{$Ptables{radn}}, &TableLocateRA('shortwave',@ratables));


return;
}


sub Physics_SW04_RRTMG {
# ==================================================================================
#  Configure Newer Rapid Radiative Transfer Model (RA_SW_PHYSICS = 4)
#
#    RRTMG scheme (ARW only): Rapid Radiative Transfer Model with a G at the end.
#    An updated version of the RRTM scheme including MCICA method of random cloud
#    overlap. Uses 16 long-wave Bands (K-distribution), look-up tables fit to
#    accurate calculations, cloud, trace gas and aerosol interactions. Ozone and
#    CO2 profiles are specified. (Mlawer et al 1997).
#
#      Microphysics interactions : Qc,Qr,Qi,Qs
#      Cloud fraction            : Max-rand overlap
#      Ozone effects             : 1 profile or Latitude & monthly variability
#
#    RA_SW_PHYSICS = 4 has the following ancillary options (see bottom of file):
#
#      ICLOUD     - Cloud effect to the optical depth
#      O3INPUT    - Specify source of Ozone initialization data
#      AER_OPT    - Activation & source of Aerosol option
#
# ==================================================================================
#
    @{$Physics{icloud}}                =  &Config_icloud();
    @{$Physics{use_mp_re}}             =  &Config_use_mp_re();

    @{$Physics{o3input}}               =  &Config_o3input();
    @{$Physics{aer_opt}}               =  &Config_aer_opt();

    @{$Physics{alevsiz}}               =  &Config_alevsiz()          if $Physics{aer_opt}[0] == 1;
    @{$Physics{no_src_types}}          =  &Config_no_src_types()     if $Physics{aer_opt}[0] == 1;

    @{$Physics{aer_aod550_opt}}        =  &Config_aer_aod550_opt()   if $Physics{aer_opt}[0] == 2; 
    @{$Physics{aer_aod550_val}}        =  &Config_aer_aod550_val()   if $Physics{aer_opt}[0] == 2; 
    @{$Physics{aer_angexp_opt}}        =  &Config_aer_angexp_opt()   if $Physics{aer_opt}[0] == 2; 
    @{$Physics{aer_angexp_val}}        =  &Config_aer_angexp_val()   if $Physics{aer_opt}[0] == 2;
    @{$Physics{aer_ssa_opt}}           =  &Config_aer_ssa_opt()      if $Physics{aer_opt}[0] == 2;
    @{$Physics{aer_ssa_val}}           =  &Config_aer_ssa_val()      if $Physics{aer_opt}[0] == 2;
    @{$Physics{aer_asy_opt}}           =  &Config_aer_asy_opt()      if $Physics{aer_opt}[0] == 2;
    @{$Physics{aer_asy_val}}           =  &Config_aer_asy_val()      if $Physics{aer_opt}[0] == 2;

    #-------------------------------------------------------------------------------
    #  Specify lookup tables used by scheme
    #-------------------------------------------------------------------------------
    #
    my @ratables = qw(RRTMG_SW_DATA CAM_AEROPT_DATA CAMtr_volume_mixing_ratio
                      ozone.formatted ozone_lat.formatted ozone_plev.formatted);

    @{$Ptables{radn}} = (@{$Ptables{radn}}, &TableLocateRA('shortwave',@ratables));


return;
}


sub Physics_SW05_NewGoddard {
# ==================================================================================
#  Configure New Goddard (GFDL) Shortwave Radiation Scheme (RA_SW_PHYSICS = 5)
#
#    New Goddard scheme: Efficient, multiple bands, ozone from climatology.
#
#      Microphysics interactions : Qc,Qr,Qi,Qs,Qg
#      Cloud fraction            : 1|0  (No cloud|Cloud - no fraction)
#      Ozone effects             : 5 profiles
#
# ==================================================================================
#

    #-------------------------------------------------------------------------------
    #  Specify lookup tables used by scheme
    #-------------------------------------------------------------------------------
    #
    my @ratables = qw(tr49t67 tr49t85 tr67t85 co2_trans);

    @{$Ptables{radn}} = (@{$Ptables{radn}}, &TableLocateRA('shortwave',@ratables));


return;
}


sub Physics_SW07_FuLongGu {
# ==================================================================================
#  Configure Fu-Liou-Gu Shortwave Radiation Scheme (UCLA) (RA_SW_PHYSICS = 7)
#
#    Fu-Liou-Gu scheme (UCLA):  Multiple bands, cloud and cloud fraction effects,
#    ozone profile from climatology. Can allow for aerosols.
#
#      Microphysics interactions : Qc,Qr,Qi,Qs,Qg
#      Cloud fraction            : 1|0  (No cloud|Cloud - no fraction)
#      Ozone effects             : 5 profiles
#
# ==================================================================================
#

return;
}


sub Physics_SW24_RRTMGF {
# ==================================================================================
#  Configure Faster Newer Rapid Radiative Transfer Model (RA_SW_PHYSICS = 24)
#
#    Super faster RRTMG scheme (ARW only): A faster, sexier version of the Rapid
#    Radiative Transfer Model with a G at the end. It's just like option 4, only
#    faster, and possibly a bit shinier. And who doesn't want that?
#
#      Microphysics interactions : Qc,Qr,Qi,Qs
#      Cloud fraction            : Max-rand overlap
#      Ozone effects             : 1 profile or Latitude & monthly variability
#
#    RA_SW_PHYSICS = 24 has the following ancillary options (see bottom of file):
#
#      ICLOUD     - Cloud effect to the optical depth
#      O3INPUT    - Specify source of Ozone initialization data
#      AER_OPT    - Activation & source of Aerosol option
#
# ==================================================================================
#   
    @{$Physics{icloud}}                =  &Config_icloud();
    @{$Physics{use_mp_re}}             =  &Config_use_mp_re();

    @{$Physics{o3input}}               =  &Config_o3input();
    @{$Physics{aer_opt}}               =  &Config_aer_opt();

    @{$Physics{alevsiz}}               =  &Config_alevsiz()          if $Physics{aer_opt}[0] == 1;
    @{$Physics{no_src_types}}          =  &Config_no_src_types()     if $Physics{aer_opt}[0] == 1;

    @{$Physics{aer_aod550_opt}}        =  &Config_aer_aod550_opt()   if $Physics{aer_opt}[0] == 2; 
    @{$Physics{aer_aod550_val}}        =  &Config_aer_aod550_val()   if $Physics{aer_opt}[0] == 2; 
    @{$Physics{aer_angexp_opt}}        =  &Config_aer_angexp_opt()   if $Physics{aer_opt}[0] == 2; 
    @{$Physics{aer_angexp_val}}        =  &Config_aer_angexp_val()   if $Physics{aer_opt}[0] == 2;
    @{$Physics{aer_ssa_opt}}           =  &Config_aer_ssa_opt()      if $Physics{aer_opt}[0] == 2;
    @{$Physics{aer_ssa_val}}           =  &Config_aer_ssa_val()      if $Physics{aer_opt}[0] == 2;
    @{$Physics{aer_asy_opt}}           =  &Config_aer_asy_opt()      if $Physics{aer_opt}[0] == 2;
    @{$Physics{aer_asy_val}}           =  &Config_aer_asy_val()      if $Physics{aer_opt}[0] == 2;

    #-------------------------------------------------------------------------------
    #  Specify lookup tables used by scheme
    #-------------------------------------------------------------------------------
    #
    my @ratables = qw(RRTMG_SW_DATA CAM_AEROPT_DATA CAMtr_volume_mixing_ratio ozone.formatted 
                      ozone_lat.formatted ozone_plev.formatted);

    @{$Ptables{radn}} = (@{$Ptables{radn}}, &TableLocateRA('shortwave',@ratables));


return;
}

#
# ==================================================================================
# ==================================================================================
#      SO BEGINS THE INDIVIDUAL PARAMETER CONFIGURATION SUBROUTINES
# ==================================================================================
# ==================================================================================
#


sub Config_radt {
# ==================================================================================
#  Option:  RADT - Minutes between calls to LW & SW radiation schemes (MAX DOMAINS)
#
#  NOTES:   RADT is the number of minutes between calls to the long and short wave
#           radiation schemes. This value should decrease with smaller grid spacing;
#           however, for 2-way nested domains, a single value based on the DX of the
#           domain with the smallest DX should be used for all domains. In fact, it
#           is recommended that you always use the same value for all domains unless
#           you have a good reason not to follow directions, which you don't.
#
#           According to the WRF FAQ page:
#
#               "This value (RADT) should coincide with the finest domain resolution
#                (1 minute per km dx), but it usually is not necessary to go below 5
#                minutes All domains should use the same value, so that radiation
#                forcing is applied at the same time for all domains."
#
#           For example, if you are running a 27/9/3km nested domain configuration then
#           the value for RADT for all domains will be determined from the 3km DX value,
#           which is three minutes. Some refinement may be done so that the value is
#           an integer multiple of the number of timesteps, but all that magic occurs
#           behind the curtain.
#
#           If you are using a scheme other than Dudia, such as Goddard, then you may
#           be able to get away with a RADT greater than DX value (again ignore the units).
#
#
#           Possible values for RADT include:
#
#              1. A single value to represent the number of minutes between calls to
#                 radiation schemes. This value will be used for all domains included
#                 in the simulation.
#
#              2. Multiple numbers, separated by a comma (,) that represent the number
#                 of minutes between calls to radiation schemes for each domain used
#                 in the simulation.
#
#              3. Use one of the predefined UEMS configuration options. All calculations
#                 are based upon the grid spacing of domains included in the simulation
#                 with a possible slight adjustment so that RADT is an integer multiple
#                 of the large timestep. If an adaptive timestep is used, then no
#                 adjustments are made. The options include:
#
#                   Auto   - Use a value for RADT based on the DX of each domain
#                   Auto_1 - Use the value calculated for the primary domain for all sub-domains
#                   Auto_2 - Use the value calculated for domain with the smallest DX for all domains
#
#                            If the calculated RADT value is smaller than the simulation large time-
#                            step (very possible), the time step value will be used for RADT.
#
#                 !  There is no 5km/5min lower limit with the "Auto" option (1 minute minimum).
#
#
#  DEFAULT: RADT = Auto_2 - Each domain the same value based upon smallest DX.
#
# ==================================================================================
#
    my @radt = @{$Config{uconf}{RADT}};

    #  The best approach is to look at the first value in the @radt array and
    #  determine whether it's a number value or character string ('Auto*').
    #
    if (&Others::isNumber($radt[0])) {

        #--------------------------------------------------------------------------
        #  In this case the user has specified RADT values to be used. It is 
        #  assumed that they know what they are doing but we need to make some 
        #  quality assurance checks in case they don't. If only a single value
        #  is specified and this is a nested simulation, then apply that value
        #  to all domains provided it's within reason.
        #--------------------------------------------------------------------------
        #

        #  Assumption that the last domain included has the smallest DX
        #
        my $dtmin = sprintf '%.2f', 0.001*$Rconf{dinfo}{domains}{$Config{maxdoms}}{dx};

        if (@radt < $Config{maxdoms}) {  #  not enough values
            @radt = (@radt == 1) ? ($radt[0]) x $Config{maxdoms} : ($dtmin) x $Config{maxdoms};
        }

        my $dx = sprintf '%.2f', 0.001*$Rconf{dinfo}{domains}{1}{dx};
        my $dt = sprintf '%.2f',$radt[0];
        if ($dt/$dx > 2.) {
            my $mesg = "The RADT value specified for domain 1 ($dt minutes) is larger than the recommended ".
                       "value of $dx minutes. I'm sure this value is what you wanted, but I just wanted to ".
                       "be sure that you are sure that is what you wanted.";
            &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,'Questionable RADT Value:', $mesg);
        }


        if ($radt[0] == 0) {
            my $mesg = "Your radiation scheme call frequency is set to every time step (RADT = 0), which is ".
                       "is computationally expensive. I hope you have a good book to read!\n\n".
                       "Oh, of course! Silly me, you have the UEMS User's Guide \xe2\x98\xba";
            &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,'Enjoy the book:', $mesg);
        }

        foreach (@radt) {$_ = sprintf '%.2f',$_;}

    } else { #  The user has requested one of the 'Auto' options

        #  Auto   - Use a value for RADT based on the DX of each domain
        #  Auto_1 - Use the value calculated for the primary domain for all sub-domains
        #  Auto_2 - Use the value calculated for domain with the smallest DX for all domains (default)
        #
        #  Developer's note - This value should really be adjusted such that the radiation time step
        #                     is an integer multiple of of the timestep for each domain AND divide
        #                     evenly into the BC update frequency (unless global) but I have 
        #                     better things to do at the moment.
        #
        my $opt = lc $radt[0];
           $opt = 'auto_2' unless grep {/^${opt}$/} ('auto','auto_1','auto_2');

        @radt   = ();

        if ($opt eq 'auto') {  #  Auto   - Use a value for RADT based on the DX of each domain
            for (1..$Config{maxdoms}) {
                push @radt => defined $Rconf{dinfo}{domains}{$_} ? max (1.,sprintf '%.2f', 0.001*$Rconf{dinfo}{domains}{$_}{dx}) : max (1.,$radt[-1]);
            }
        }


        if ($opt eq 'auto_1') { #  Auto_1 - Use the value calculated for the primary domain for all sub-domains
            my $dt = max (1.,sprintf '%.2f', 0.001*$Rconf{dinfo}{domains}{1}{dx});
            @radt = ($dt)  x $Config{maxdoms};
        }


        if ($opt eq 'auto_2') { #  Auto_2 - Use the value calculated for domain with the smallest DX for all domains (default)
            my $dt = max (1.,sprintf '%.2f', 0.001*$Rconf{dinfo}{domains}{$Config{maxdoms}}{dx});
            @radt = ($dt)  x $Config{maxdoms};
        }

    }


return @radt;
}


sub Config_swint_opt {
# ==================================================================================
#   Option:  SWINT_OPT - Interpolate SW Radiation based on updated zenith angle between SW calls
#
#   Values:
#
#     0 - Do not update between calls (Previous method)
#     1 - Update SW radiation based on zenith angle between calls
#
#   Notes: Available with all radiation schemes
#
#   Default: SWINT_OPT = 1
# ==================================================================================
#
    my @swint_opt = @{$Config{uconf}{SWINT_OPT}};


return @swint_opt;
}


sub Config_slope_rad {
# ==================================================================================
#   Option:  SLOPE_RAD - Modify surface solar radiation flux according to terrain slope
#
#   Values:
#
#     0 - Do not modify surface solar radiation flux according to terrain slope (OFF)
#     1 - Modify surface solar radiation flux according to terrain slope        (ON)
#
#   Notes:   Only necessary when grid spacing is a few kilometers or less
#
#   Default: SLOPE_RAD = 0
# ==================================================================================
#
    #  Assume the user wants the option ON if it's turned ON for any domain. This will
    #  eliminate the possibility that just a single ON value (SLOPE_RAD = 1) was set in the
    #  configuration file.
    #
    my $ON = (grep {/^1$/}  @{$Config{uconf}{SLOPE_RAD}}) ? 1 : 0;

    #  Temporarily (maybe) set domains to OFF, afterwards turn those domains           
    #  ON that meet the ON requirements.
    #
    my @slope_rad = (0) x $Config{maxdoms};

    if ($ON) {
        foreach my $d (sort {$a <=> $b} keys %{$Rconf{dinfo}{domains}}) {
            my $dx = sprintf '%.1f', 0.001*$Rconf{dinfo}{domains}{$d}{dx};
            $slope_rad[$d-1] = $ON if $dx <= 5.0;
        }
    }


return @slope_rad;
}


sub Config_topo_shading {
# ==================================================================================
#   Option:  TOPO_SHADING - Allows for shadowing of neighboring grid cells
#
#   Values:  (MAX DOMAINS)
#
#     0 - Do not include topography shading (OFF)
#     1 - Include the shadowing of neighboring grid cells (ON)
#
#   Notes:   Only necessary when grid spacing is a few kilometers or less
#
#   Default: TOPO_SHADING = 0
# ==================================================================================
#
    #  Assume the user wants the option ON if it's turned ON for any domain. This will
    #  eliminate the possibility that just a single ON value (TOPO_SHADING = 1) was set in the
    #  configuration file.
    #
    my $ON = (grep {/^1$/} @{$Config{uconf}{TOPO_SHADING}}) ? 1 : 0;

    #  Temporarily (maybe) set domains to OFF, afterwards turn those domains           
    #  ON that meet the ON requirements.
    #
    my @topo_shading = (0) x $Config{maxdoms};

    if ($ON) {
        foreach my $d (sort {$a <=> $b} keys %{$Rconf{dinfo}{domains}}) {
            my $dx = sprintf '%.1f', 0.001*$Rconf{dinfo}{domains}{$d}{dx};
            $topo_shading[$d-1] = $ON if $dx <= 5.0;
        }
    }


return @topo_shading;
}


sub Config_shadlen {
# ==================================================================================
#   Option:  SHADLEN -  Max orographic shadow length in meters when TOPO_SHADING = 1
#
#   Values:  (MAX DOMAINS)
#
#   Notes:   The default is 25000 meters (25km), which probably is OK
#
#   Default: SHADLEN = 25000
# ==================================================================================
#
    my @shadlen = @{$Config{uconf}{SHADLEN}};


return @shadlen;
}


sub Config_ra_call_offset {
# ==================================================================================
#   Option:  RA_CALL_OFFSET - Radiation call offset
#
#   Values:
#
#     0 - Call Radiation after output time (Default)
#    -1 - (Old Method) Call Radiation before output time
#
#   Default: RA_CALL_OFFSET = 0
# ==================================================================================
#
    my @ra_call_offset = @{$Config{uconf}{RA_CALL_OFFSET}};


return @ra_call_offset;
}


sub Config_icloud {
# ==================================================================================
#   Option:  ICLOUD - Cloud fraction and the effect to the optical depth in radiation
#
#   Values:
#
#     0 - Do not include the effect of clouds in calculating the
#         optical depth in shortwave radiation scheme (1 or 4)
#     1 - With fractional cloud effects Xu-Randall cloud fraction (0 to 1)
#     2 - Use threshold method which gives either 0 or 1 as cloud fraction
#     3 - RH-based method that follows Sundqvist et al. (1989). The threshold of RH depends on grid sizes.
#
#   Notes:   *  Functionality of this option changed with V3.7
#            *  If CU_PHYSICS = 11, ICLOUD will automatically be set to 1 regardless 
#               of RA_LW_PHYSICS and RA_SW_PHYSICS values.
#
#   Default: ICLOUD = 1 (Xu-Randall cloud fraction)
# ==================================================================================
#
    my @icloud = @{$Config{uconf}{ICLOUD}};


return @icloud;
}


sub Config_o3input {
# ==================================================================================
#   Option:  O3INPUT - Specify source of Ozone initialization data
#
#   Values:
#
#     0 - Use default profile in scheme
#     2 - Use CAM ozone data
#
#   Notes:   Yes, the values above are correct, there is no option "1".
#
#   Default: O3INPUT = 2 (using CAM ozone data))
# ==================================================================================
#
    my @o3input = @{$Config{uconf}{O3INPUT}};


return @o3input;
}


sub Config_use_mp_re {
# ==================================================================================
#   Option:  USE_MP_RE - control the interaction between effective radii
#                        computed in some microphysics with RRTMG radiation.
#
#   Info:  Whether to use effective radii computed in mp schemes in RRTMG
#          (the mp schemes that compute effective radii are 3, 4, 6, 8, 14, 16, 17-21)
#
#   Values:
#
#     0 - Off (Do not use)
#     1 - On  (Use effective radii)
#
#   Default: USE_MP_RE = 1 (Use effective radii)
# ==================================================================================
#
    my @use_mp_re = @{$Config{uconf}{USE_MP_RE}};


return @use_mp_re;
}

sub Config_swrad_scat {
# ==================================================================================
#   Option:  SWRAD_SCAT - Clear-sky shortwave scattering tuning parameter
#
#   Notes:   Default value of 1., which is equivalent to  is 1.e-5 m2/kg
#            Actual value used is SWRAD_SCAT * 1.e-5 m2/kg in the code,
#            which approximates the value over Kansas.
#
#   Default: SWRAD_SCAT = 1
# ==================================================================================
#
    my @swrad_scat = @{$Config{uconf}{SWRAD_SCAT}};


return @swrad_scat;
}


sub Config_aer_opt {
# ==================================================================================
#   Option:  AER_OPT - Activation & source of Aerosol option
#
#   Values:
#
#     0 - Off (Aerosol data not included in simulation
#     1 - On  Tegan climatology dataset)
#     2 - On  J. A. Ruiz-Arias method and set all the AER_* options below
#     3 - On  Climatological water and ice-friendly aerosols
#
#   Notes:   The Tegan climatology dataset (AER_OPT = 1) has 6 types: organic carbon,
#            black carbon, sulfate, sea salt, dust and stratospheric aerosol (volcanic
#            ash, which is zero). The data also has spatial (5 degrees in longitude and
#            4 degrees in latitudes) and temporal (monthly) variations.
#
#            The J. A. Ruiz-Arias method (AER_OPT = 2)  requires further configuration
#            of the various AER_* options below. It also works with the new Goddard
#            radiation schemes (RA_LW|SW_PHYSICS = 5), although the heading above does
#            not reflect that fact.
#
#            The Climatological water and ice-friendly aerosols option (3) is only for 
#            use with the Thompson (mp_physics=28) MP scheme. If using the Thompson
#            aerosol aware MP scheme then AER_OPT will be set to 3 for a non-zero value
#            below. If not using the Thompson aerosol aware MP scheme and AER_OPT = 3
#            below, the value will be reset to 1 and you will like it.
#
#   Default: AER_OPT = 0
# ==================================================================================
#
    my @aer_opt = @{$Config{uconf}{AER_OPT}};

    if (grep {/^1$/} @aer_opt) {
        my @ratables = qw(aerosol_plev.formatted aerosol_lon.formatted
                          aerosol_lat.formatted  aerosol.formatted);

        @{$Ptables{radn}} = (@{$Ptables{radn}}, &TableLocateRA('aerosol',@ratables));
    }


return @aer_opt;
}


sub Config_alevsiz {
# ==================================================================================
#   Option:  ALEVSIZ - Use with Tegen data
#
#   Notes: These parameters are set to default values here although the documentation 
#          states that they are "set automatically". So why are they also specified
#          in the namelist file?
#
#   Default: ALEVSIZ      = 12 for Tegen aerosol input levels, set automatically
# ==================================================================================
#
    my @alevsiz = @{$Config{uconf}{ALEVSIZ}};


return @alevsiz;
}


sub Config_no_src_types {
# ==================================================================================
#   Option:  NO_SRC_TYPES - Use with Tegen data
#
#   Notes: These parameters are set to default values here although the documentation 
#          states that they are "set automatically". So why are they also specified
#          in the namelist file?
#
#   Default: NO_SRC_TYPES =  6 for Tegen aerosols: organic and black carbon, sea salt, 
#                              sulfalte, dust,and stratospheric aerosols
# ==================================================================================
#
    my @no_src_types = @{$Config{uconf}{NO_SRC_TYPES}};


return @no_src_types;
}


sub Config_aer_type {
# ==================================================================================
#   Option:  AER_TYPE (1|2|3) : (default AER_TYPE=1)
#       
#   Values:
#
#     1 - rural
#     2 - urban
#     3 - maritime
#
#  A new way to input aerosol for RRTMG and Goddard (?) radiation options. 
#  Either AOD at 550 nm or AOD plus Angstrom exponent, single scattering albedo
#  and cloud asymmetry parameters can be input via constant values from namelist
#  or 2D input via auxiliary input stream 15 (Not Yet UEMS Supported). 
# ==================================================================================
#
    my @aer_type = @{$Config{uconf}{AER_TYPE}};


return @aer_type;
}


sub Config_aer_aod550_opt {
# ==================================================================================
#   Option:   AER_AOD550_OPT (1|2): (default AER_AOD550_OPT=1)
#
#   Values:
#
#     1 - input constant value for AOD at 550 nm from AER_AOD550_VAL
#     2 - input value from auxiliary input 5, time-varying 2D grid in netcdf format. 
# ==================================================================================
#
    my @aer_aod550_opt = @{$Config{uconf}{AER_AOD550_OPT}};


return @aer_aod550_opt;
}


sub Config_aer_aod550_val {
# ==================================================================================
#   Option:   AER_AOD550_VAL - Value when AER_AOD550_OPT = 1 
#
#   Default:  AER_AOD550_VAL = 0.12
# ==================================================================================
#
    my @aer_aod550_val = @{$Config{uconf}{AER_AOD550_VAL}};


return @aer_aod550_val;
}


sub Config_aer_angexp_opt {
# ==================================================================================
#   Option:   AER_ANGEXP_OPT (1|2|3): (default AER_ANGEXP_OPT=1)
#
#   Values:
#           
#     1 - input constant value for Angstrom exponent from AER_ANGEXP_VAL
#     2 - input value from auxiliary input 5, time-varying 2D grid in netcdf format
#     3 - Angstrom exponent value estimated from the aerosol type defined in aer_type, 
#         and modulated with the RH in WRF.
# ==================================================================================
#
    my @aer_angexp_opt = @{$Config{uconf}{AER_ANGEXP_OPT}};


return @aer_angexp_opt;
}


sub Config_aer_angexp_val {
# ==================================================================================
#   Option:   AER_ANGEXP_VAL - Value when AER_ANGEXP_OPT = 1 
#
#   Default:  AER_ANGEXP_VAL = 1.3
# ==================================================================================
#
    my @aer_angexp_val = @{$Config{uconf}{AER_ANGEXP_VAL}};


return @aer_angexp_val;
}


sub Config_aer_ssa_opt {
# ==================================================================================
#   Option:   AER_SSA_OPT (1|2|3): (default AER_SSA_OPT=1)
#
#   Values:
#           
#     1 - input constant value for SSA from AER_SSA_VAL
#     2 - input value from auxiliary input 5, time-varying 2D grid in netcdf format
#     3 - SSA value estimated from the aerosol type defined in aer_type,
#         and modulated with the RH in WRF.
# ==================================================================================
#
    my @aer_ssa_opt = @{$Config{uconf}{AER_SSA_OPT}};


return @aer_ssa_opt;
}


sub Config_aer_ssa_val {
# ==================================================================================
#   Option:   AER_SSA_VAL - Value when AER_SSA_OPT = 1 
#
#   Default:  AER_SSA_VAL = 0.85
# ==================================================================================
#
    my @aer_ssa_val = @{$Config{uconf}{AER_SSA_VAL}};


return @aer_ssa_val;
}


sub Config_aer_asy_opt {
# ==================================================================================
#   Option:   AER_ASY_OPT (1|2|3): (default AER_ASY_OPT=1)
#
#   Values:
#           
#     1 - input constant value for ASY from AER_ASY_VAL
#     2 - input value from auxiliary input 5, time-varying 2D grid in netcdf format
#     3 - ASY value estimated from the aerosol type defined in aer_type,
#         and modulated with the RH in WRF.
# ==================================================================================
#
    my @aer_asy_opt = @{$Config{uconf}{AER_ASY_OPT}};


return @aer_asy_opt;
}


sub Config_aer_asy_val {
# ==================================================================================
#   Option:   AER_ASY_VAL - Value when AER_ASY_OPT = 1 
#
#   Default:  AER_ASY_VAL = 0.90
# ==================================================================================
#
    my @aer_asy_val = @{$Config{uconf}{AER_ASY_VAL}};


return @aer_asy_val;
}


sub Config_levsiz {
# ==================================================================================
#   Option:   LEVSIZ - Value now set internally 
# ==================================================================================
#
    my @levsiz = @{$Config{uconf}{LEVSIZ}};


return @levsiz;
}


sub Config_paerlev {
# ==================================================================================
#   Option:   PAERLEV - Value now set internally 
# ==================================================================================
#
    my @paerlev = @{$Config{uconf}{PAERLEV}};


return @paerlev;
}


sub Config_cam_abs_dim1 {
# ==================================================================================
#   Option:   CAM_ABS_DIM1 - Value now set internally 
# ==================================================================================
#
    my @cam_abs_dim1 = @{$Config{uconf}{CAM_ABS_DIM1}};


return @cam_abs_dim1;
}


sub Config_cam_abs_freq_s {
# ==================================================================================
#   Option:   CAM_ABS_FREQ_S - Value now set internally 
# ==================================================================================
#
    my @cam_abs_freq_s = @{$Config{uconf}{CAM_ABS_FREQ_S}};


return @cam_abs_freq_s;
}


sub TableLocateRA {
# ==================================================================================
#  This routine just tests whether the required MP tables are available. It 
#  fails if a table is missing; otherwise it returns an array containing the
#  absolute path to the table file.
# ==================================================================================
#
    my @mistbl = ();
    my @ratbls = ();

    my $dradn = "$ENV{DATA_TBLS}/wrf/physics/radn";  # Tables located under $EMS_DATA/tables/wrf/physics/radn

    my ($ra, @tables) = @_;  return () unless @tables; @tables = sort &Others::rmdups(@tables);

    foreach (@tables) { -f "$dradn/$_" ? push @ratbls  => "$dradn/$_" : push @mistbl => $_;}

    if (@mistbl) {  #  Oops - Some required tables are missing

        my @lines = ("Missing $ra Radiation Lookup Tables\n");
        push @lines, "The $ra radiation physics scheme you have chosen requires the following tables files located ".
                     "in the following directory:\n\n".
                     "X02X$dradn/";
 
        foreach my $table (@tables) {push @lines,sprintf("X04X%-18s %14s",$table,(grep {/^$table$/} @mistbl) ? '<- Missing!' : '');}
        
        push @lines, "\nEither you promptly locate the missing table files or change your radiation scheme for this simulation; ".
                     "otherwise, you will be reading these words again.\n\nBut next time, they will be written with a much angrier ".
                     "tone and without the sarcasm.";
 
        $ENV{RMESG} = join "\n", @lines;
 
        return ();
    }


return @ratbls;
}


sub Physics_BoundryLayer {
# ==============================================================================================
# WRF &PHYSICS NAMELIST CONFIGURATION FOR BOUNDRY LAYER SCHEMES AND RELATED STUFF
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This subroutine manages the configuration of all things boundary layer scheme
#   in the &physics section of the WRF namelist file. 
#
#   Note that some (most) of the information used to produce the guidance presented
#   in this file was likely taken from the WRF user's guide and presentation materials,
#   and those authors should receive all the gratitude as well as any proceeds that 
#   may be derived from reading this information.
#
#   Some basic guidance to follow:
#
#   *  PBL schemes can be used for most grid sizes when surface fluxes are 
#      present.
#
#   *  PBL schemes assume  that PBL eddies are not resolved. This assumption
#      breaks down at  grid size dx << 1 km; however, it's still recommended 
#      to use a PBL scheme when DX > 400m.
#
#   *  With ACM2, GFS and MRF PBL schemes, the lowest full level should be
#      .99 or .995, not too close to 1.0
#
#   *  The TKE schemes can use thinner surface layers
#
# ==============================================================================================
# ==============================================================================================
#
    my %renv    = %{$Rconf{rtenv}};   #  Contains the  local configuration
    my %dinfo   = %{$Rconf{dinfo}};  #  just making things easier

    my @rdoms   = sort {$a <=> $b} keys %{$Rconf{dinfo}{domains}};


    #-----------------------------------------------------------------------------
    #  PHYSICS Variable:  BL_PBL_PHYSICS - PBL scheme
    #
    #    Note: May not switch PBL schemes between nests!
    #
    #    PBL options include:
    #
    #    0 - No PBL scheme used - LES simulation
    #    1 - YSU PBL scheme
    #    2 - Mellor-Yamada-Janjic (Eta/NMM) PBL
    #    3 - NCEP Global Forecast System (GFS) Scheme (Not UEMS Supported)
    #    4 - QNSE (Quasi-Normal Scale Elimination) PBL
    #    5 - MYNN (Nakanishi and Niino) 1.5-order, level 2.5, TKE prediction PBL
    #    6 - MYNN (Nakanishi and Niino) )2nd-order, level 3, TKE + more pediction
    #    7 - Asymmetrical Convective Model (ACM2) Version 2
    #    8 - BouLac PBL (Bougeault and Lacarrère)
    #    9 - Bretherton-Park/UW TKE
    #   10 - Total Energy - Mass Flux (TEMF) PBL (Angevine et al.)
    #   11 - Shin-Hong PBL Scheme
    #   12 - Grenier-Bretherton-McCaa scheme - V3.5
    #-----------------------------------------------------------------------------
     
    #  Make sure that any physics scheme used by a nested domain is also used by
    #  the parent. IT'S THE LAW!
    #
    @{$Physics{bl_pbl_physics}} = map {$Config{uconf}{BL_PBL_PHYSICS}[$_] ? $Config{uconf}{BL_PBL_PHYSICS}[$Config{parentidx}[$_]] : 0} 0..$Config{maxindex};


    #  Make sure the PBL scheme is ON if the DX of the domain is greater then 500m
    #
    my @dopts = ();
    foreach (@rdoms) {push @dopts => $_ if $Rconf{dinfo}{domains}{$_}{dx} > 500. and $Physics{bl_pbl_physics}[$_-1] == 0;}

    if (@dopts) {
        my $str = &Ecomm::JoinString(\@dopts);
        my $mesg = "The PBL physics should be turned ON with a grid spacing of greater than 500 meters. Setting ".
                   "BPL scheme to $Physics{bl_pbl_physics}[0] for domains $str.";
        &Ecomm::PrintMessage(6,11+$Rconf{arf},88,1,2,'Just Saving Your Simulation, Again:',$mesg);
        $Physics{bl_pbl_physics}[$_-1] = $Physics{bl_pbl_physics}[0] foreach @dopts;
    }


    #  This section of code is simply to maintain order in the bl_pbl_physics string. Baisically
    #  it's making sure that any domains not being used are assigned the PBL scheme of the parent.
    #  Don't ask why - I just prefer the way it looks when debugging code.
    #
    my @nopts = (1..$Config{maxdoms});
    foreach (&Others::ArrayMissing(\@nopts,\@rdoms)) {$Physics{bl_pbl_physics}[$_-1] = $Physics{bl_pbl_physics}[$Config{parentidx}[$_]-1];}


    #  -------------------------- Additional BL_PBL_PHYSICS Configuration ---------------------------------------------
    #  Complete additional configuration for the selected BL_PBL_PHYSICS scheme.
    #  Note that the use of individual subroutines is not necessary since all the variables are
    #  global, but it make for cleaner code. Also - Most of the pre-configuration of user 
    #  defined variables was done in &ReadConfigurationFilesARW, the values from which
    #  used here. The only difficulty in writing this code was how to organize the individual
    #  variables that need to be set for each MP scheme. Some variables are valid for all schemes
    #  some for different schemes, and others for only one scheme.
    #
    #  So an executive decision was made for the cleanest solution. There are individual subroutines
    #  for each parameter, which are called from a separate subroutine for each MP scheme. Parameters
    #  that are always used together are combined into a single subroutine.  Hopefully it will all
    #  work out.
    #  ----------------------------------------------------------------------------------------------------------------
    #
    for ($Physics{bl_pbl_physics}[0]) {

        &Physics_BL00_NOPBL()       if $_ ==  0; #  Configure Simulation without a Boundary layer scheme (BL_PBL_PHYSICS = 0)
        &Physics_BL01_YSU()         if $_ ==  1; #  Yonsei University Scheme (YSU) (BL_PBL_PHYSICS = 1)
        &Physics_BL02_MYJ()         if $_ ==  2; #  Mellor-Yamada-Janjic (Eta/NMM) PBL (BL_PBL_PHYSICS = 2)
        &Physics_BL03_GFS()         if $_ ==  3; #  NCEP Global Forecast System (GFS) Scheme (BL_PBL_PHYSICS = 3)
        &Physics_BL04_QNSE()        if $_ ==  4; #  QNSE (Quasi-Normal Scale Elimination) PBL (BL_PBL_PHYSICS = 4)
        &Physics_BL05_MYNN2()       if $_ ==  5; #  MYNN (Nakanishi and Niino) 1.5-order, level 2.5, TKE prediction PBL (BL_PBL_PHYSICS = 5)
        &Physics_BL06_MYNN3()       if $_ ==  6; #  MYNN (Nakanishi and Niino) )2nd-order, level 3, TKE + more prediction (BL_PBL_PHYSICS = 6)
        &Physics_BL07_ACM2()        if $_ ==  7; #  Asymmetrical Convective Model (ACM2) Version 2 (BL_PBL_PHYSICS = 7)
        &Physics_BL08_BOULAC()      if $_ ==  8; #  BouLac PBL (Bougeault and Lacarrère) (BL_PBL_PHYSICS = 8)
        &Physics_BL09_UW()          if $_ ==  9; #  Bretherton-Park/UW TKE (BL_PBL_PHYSICS = 9)
        &Physics_BL10_TEMF()        if $_ == 10; #  Total Energy - Mass Flux (TEMF) PBL (Angevine et al.) (BL_PBL_PHYSICS = 10)
        &Physics_BL11_ShinHong()    if $_ == 11; #  Shin-Hong PBL Scheme (BL_PBL_PHYSICS = 11)
        &Physics_BL12_GBM()         if $_ == 12; #  Grenier-Bretherton-McCaa scheme - V3.5 (BL_PBL_PHYSICS = 12)

        return 1 if $ENV{RMESG};

    }

    @{$Physics{bldt}}            =  &Config_bldt();
    @{$Physics{grav_settling}}   =  &Config_grav_settling();
    @{$Physics{scalar_pblmix}}   =  &Config_scalar_pblmix();
    @{$Physics{tracer_pblmix}}   =  &Config_tracer_pblmix();

    #  Finally, complete any consistency checks
    #
    &Physics_PBL_ConsistencyCheck(); return 1 if $ENV{RMESG};


return;
}  #  Physics_BoundryLayer


sub Physics_BL00_NOPBL {
# ==================================================================================
#  Configure Simulation without a Boundary layer scheme (BL_PBL_PHYSICS = 0)
#
#  Note: Parameter values defined in &ReadConfigurationFilesARW
# ==================================================================================
#

return;
}


sub Physics_BL01_YSU {
# ==================================================================================
#  Yonsei University Scheme (YSU) (BL_PBL_PHYSICS = 1)
#
#  Yonsei University scheme: Parabolic non-local-K mixing in dry convective
#  boundary layer. Depth of PBL determined from thermal profile. Explicit
#  treatment of entrainment. Diffusion depends on Richardson Number (Ri) in
#  the free atmosphere. New stable surface BL mixing using bulk Ri in V3.
#  Most popular for ARW. (Skamarock et al. 2005).
#
#  For use with SF_SFCLAY_PHYSICS = 1
#
#     Prognostic Variables: None
#     Diagnostic Variables: exch_h
#     Cloud Mixing        : Qc,Qi
#
#  Ancillary options (See Below):
#     topo_wind          - Topographic correction for surface winds
#                          Requires additional information from geogrid
#
#     ysu_topdown_pblmix - Turns on top-down radiation-driven mixing
#
# ==================================================================================
#
    @{$Physics{topo_wind}}          =  &Config_topo_wind();
    @{$Physics{ysu_topdown_pblmix}} =  &Config_ysu_topdown_pblmix();

return;
}


sub Physics_BL02_MYJ {
# ==================================================================================
#  Mellor-Yamada-Janjic (Eta/NMM) PBL (BL_PBL_PHYSICS = 2)
#
#  Mellor-Yamada-Janjic scheme: The NAM operational scheme. One-dimensional
#  1.5 order level 2.5 prognostic turbulent kinetic energy scheme with local
#  vertical mixing, that is only between neighboring grid boxes. Local TKE-
#  based vertical mixing in boundary layer and free atmosphere (Janjic 1990,
#  1996a, 2002).
#
#  For use with SF_SFCLAY_PHYSICS = 2  (Default = 2)
#
#     Prognostic Variables: tke_pbl
#     Diagnostic Variables: exch_h,el_myj
#     Cloud Mixing        : Qc,Qi
#
#  Note that model predicted 2m (shelter) temperatures are only available
#  when running with MYJ scheme; otherwise that are diagnosed in UEMSUPP.
#
# ==================================================================================
#


return;
}


sub Physics_BL03_GFS {
# ==================================================================================
#  NCEP Global Forecast System (GFS) Scheme (BL_PBL_PHYSICS = 3)
#
#  NCEP Global Forecast System (GFS) scheme: First-order vertical diffusion
#  of Troen and Mahrt (1986) and further described by Hong and Pan (1996).
#  The PBL height is determined by an iterative bulk-Richardson approach
#  working from the ground upward whereupon the profile of the diffusivity
#  coefficient is specified as a cubic function of height. Coefficient values
#  are obtained by matching the surface-layer fluxes. A counter-gradient flux
#  parameterization is included. Used operationally at NCEP.
#
#  For use with SF_SFCLAY_PHYSICS = 3   (Default = 3)
#
#     Prognostic Variables: None
#     Diagnostic Variables: None
#     Cloud Mixing        : Qc,Qi
#
# ==================================================================================
#


return;
}


sub Physics_BL04_QNSE {
# ==================================================================================
#  QNSE (Quasi-Normal Scale Elimination) PBL (BL_PBL_PHYSICS = 4)
#
#  Quasi-Normal Scale Elimination (QNSE) PBL: A TKE-prediction option that uses a new
#  theory for stably stratified regions.
#
#  For use with SF_SFCLAY_PHYSICS = 4   (Default = 4)
#
#     Prognostic Variables: tke_pbl
#     Diagnostic Variables: exch_h,exch_m,em_myj
#     Cloud Mixing        : Qc,Qi
#
#  Note:  This PBL scheme also includes a shallow convective option, which, when
#         activated, means that you are running QNSE-EDMF, where the EDMF stands
#         Eddy Daytime Mass Flux (At least I thinks its "Eddy") The shallow CU
#         option is turned OFF when SHCU_PHYSICS = 0, and turned ON (mfshconv = 1)
#         when SHCU_PHYSICS = -1 unless a CU_PHYSICS option is selected that
#         also incorporates the effects of shallow convection that can not be
#         turned off.
#
#  Info:  The QNSE PBL scheme can not be used with the scale-aware KF cumulus
#         scheme, CU_PHYSICS = 11, as per note in module_check_a_mundo.F (V3.7)
#
# ==================================================================================
#


return;
}


sub Physics_BL05_MYNN2 {
# ==================================================================================
#  MYNN (Nakanishi and Niino) 1.5-order, level 2.5, TKE prediction PBL (BL_PBL_PHYSICS = 5)
#
#  Mellor-Yamada Nakanishi Niino (MYNN2) 2.5 level TKE scheme (M. Pagowski - NOAA),
#
#  For use with SF_SFCLAY_PHYSICS = 1,2, or 5  (Default = 5)
#
#     Prognostic Variables: qke
#     Diagnostic Variables: tsq,qsq,cov,exch_h,exch_m
#     Cloud Mixing        : Qc
#
# ==================================================================================
#
    @{$Physics{icloud_bl}}           =  &Config_icloud_bl();

    @{$Physics{bl_mynn_cloudmix}}    =  &Config_bl_mynn_cloudmix();
    @{$Physics{bl_mynn_cloudpdf}}    =  &Config_bl_mynn_cloudpdf();
    @{$Physics{bl_mynn_mixlength}}   =  &Config_bl_mynn_mixlength();

    @{$Physics{bl_mynn_edmf}}        =  &Config_bl_mynn_edmf();
    @{$Physics{bl_mynn_edmf_mom}}    =  &Config_bl_mynn_edmf_mom()  if $Physics{bl_mynn_edmf}[0];
    @{$Physics{bl_mynn_edmf_tke}}    =  &Config_bl_mynn_edmf_tke()  if $Physics{bl_mynn_edmf}[0];

    @{$Physics{bl_mynn_tkeadvect}}   =  &Config_bl_mynn_tkeadvect();
    @{$Physics{bl_mynn_tkebudget}}   =  &Config_bl_mynn_tkebudget() if $Physics{bl_mynn_tkeadvect}[0] eq 'T';


return;
}


sub Physics_BL06_MYNN3 {
# ==================================================================================
#  MYNN (Nakanishi and Niino) )2nd-order, level 3, TKE + more prediction (BL_PBL_PHYSICS = 6)
#
#  Mellor-Yamada Nakanishi Niino (MYNN3) 3rd level TKE scheme (M. Pagowski - NOAA),
#
#  For use with SF_SFCLAY_PHYSICS = 1,2, or 5  (Default = 5)
#
#     Prognostic Variables: qke,tsq,qsq,cov
#     Diagnostic Variables: exch_h,exch_m
#     Cloud Mixing        : Qc
#
# ==================================================================================
#
    @{$Physics{icloud_bl}}           =  &Config_icloud_bl();

    @{$Physics{bl_mynn_cloudmix}}    =  &Config_bl_mynn_cloudmix();
    @{$Physics{bl_mynn_cloudpdf}}    =  &Config_bl_mynn_cloudpdf();
    @{$Physics{bl_mynn_mixlength}}   =  &Config_bl_mynn_mixlength();

    @{$Physics{bl_mynn_edmf}}        =  &Config_bl_mynn_edmf();
    @{$Physics{bl_mynn_edmf_mom}}    =  &Config_bl_mynn_edmf_mom()  if $Physics{bl_mynn_edmf}[0];
    @{$Physics{bl_mynn_edmf_tke}}    =  &Config_bl_mynn_edmf_tke()  if $Physics{bl_mynn_edmf}[0];

    @{$Physics{bl_mynn_tkeadvect}}   =  &Config_bl_mynn_tkeadvect();
    @{$Physics{bl_mynn_tkebudget}}   =  &Config_bl_mynn_tkebudget() if $Physics{bl_mynn_tkeadvect}[0] eq 'T'; 


return;
}


sub Physics_BL07_ACM2 {
# ==================================================================================
#  Asymmetrical Convective Model (ACM2) Version 2 (BL_PBL_PHYSICS = 7)
#
#  Asymmetrical Convective Model V2 (ACM2) Scheme: Blackadar-type thermal
#  mixing (non-local) upwards from the surface layer. Local mixing downwards.
#  PBL height determined from critical bulk Richardson number. New to WRF V3.
#
#  For use with SF_SFCLAY_PHYSICS = 1 or 7   (Default = 7)
#
#     Prognostic Variables: None
#     Diagnostic Variables: None
#     Cloud Mixing        : Qc,Qi
#
# ==================================================================================
#


return;
}


sub Physics_BL08_BOULAC {
# ==================================================================================
#  BouLac PBL (Bougeault and Lacarrère) (BL_PBL_PHYSICS = 8)
#
#  Bougeault and Lacarrere (BouLac) PBL (by B. Galperin of U of South Florida)
#  A TKE prediction scheme designed for use with the NOAH LSM and the Multi-layer
#  urban canopy model.
#
#  For use with SF_SFCLAY_PHYSICS = 1 or 2  (Default = 2)
#
#     Prognostic Variables: tke_pbl
#     Diagnostic Variables: el_pbl,exch_h,exch_m,wu_tur,wv_tur,wt_tur,wq_tur
#     Cloud Mixing        : Qc
#
# ==================================================================================
#


return;
}


sub Physics_BL09_UW {
# ==================================================================================
#  Bretherton-Park/UW TKE (BL_PBL_PHYSICS = 9)
#
#  UW (Bretherton and Park) Scheme:  TKE scheme from CESM climate model.
#
#  For use with SF_SFCLAY_PHYSICS = 1 or 2 (Default = 1)
#
#     Prognostic Variables: tke_pbl
#     Diagnostic Variables: exch_h,exch_m
#     Cloud Mixing        : Qc
#
# ==================================================================================
#


return;
}


sub Physics_BL10_TEMF {
# ==================================================================================
#  Total Energy - Mass Flux (TEMF) PBL (Angevine et al.) (BL_PBL_PHYSICS = 10)
#
#  Total Energy - Mass Flux (TEMF) Scheme: Sub-grid total energy prognostic
#  variable plus mass-flux type shallow convection.
#
#  For use with SF_SFCLAY_PHYSICS = 10   (Default = 10)
#
#     Prognostic Variables: te_temf
#     Diagnostic Variables: *_temf
#     Cloud Mixing        : Qc,Qi
#
# ==================================================================================
#


return;
}


sub Physics_BL11_ShinHong {
# ==================================================================================
#  Shin-Hong PBL Scheme (BL_PBL_PHYSICS = 11)
#
#  Shin-Hong 'scale-aware' PBL scheme: A scheme that includes scale-dependency for
#  vertical transport in convective PBL while the vertical mixing in stable PBL and
#  free atmosphere follows YSU. Nonlocal mixing term reduces in strength as grid
#  size gets smaller and local mixing increases.
#
#  Note that this scheme is designed for SUB 1-km grid scale!
#
#     Prognostic Variables: None
#     Diagnostic Variables: exch_h, tke_diag
#     Cloud Mixing        : Qc,Qi
#
# ==================================================================================
#
use List::Util qw[min];

    #  Because this PBL scheme is designed for sub-1km grid scale make sure the user 
    #  is heeding the basic guidance.
    #
    my $sdx = min map {$Rconf{dinfo}{domains}{$_}{dx}} keys %{$Rconf{dinfo}{domains}};

    unless ($sdx < 1000.) { #  Scheme is designed for SUB 1-km grid scale!

        my $dx = sprintf '%.1f', 0.001*$sdx; $dx = "$dx kilometers";

        my $mesg = "The Shin-Hong PBL Scheme (BL_PBL_PHYSICS = 11) is a \"scale-aware\" scheme that is ".
                    "designed for SUB 1-km grid scale.  The smallest grid spacing in your computational ".
                    "domain is $dx, which is larger than the UEMS maximum minimum of 1.0 km.  Consequently, ".
                    "you need to find a new PBL scheme or get a smaller DX.";

        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'PBL choice not recommended:',$mesg);
        return;
    }

    @{$Physics{shinhong_tke_diag}} =  &Config_shinhong_tke_diag();
    @{$Physics{topo_wind}}         =  &Config_topo_wind();


return;
}


sub Physics_BL12_GBM {
# ==================================================================================
#  Grenier-Bretherton-McCaa scheme - V3.5 (BL_PBL_PHYSICS = 12)
#
#   Grenier-Bretherton-McCaa Scheme: Similar to option 9, this is a Mellor-
#   Yamada TKE type scheme that was developed for marine boundary layer
#   applications. Grenier and Bretherton, MWR, 2001 - New in Version 3.5.
#
#   For use with SF_SFCLAY_PHYSICS = 1
#
#     Prognostic Variables: tke_pbl
#     Diagnostic Variables: el_pbl,exch_tke
#     Cloud Mixing        : Qc,Qi
#
# ==================================================================================
#


return;
}


#
# ==================================================================================
# ==================================================================================
#      SO BEGINS THE INDIVIDUAL PARAMETER CONFIGURATION SUBROUTINES
# ==================================================================================
# ==================================================================================
#


sub Config_bldt {
# ==================================================================================
#  Option:  BLDT - Minutes between PBL and LSM scheme calls (NESTED)
#
#     *  Recommended value is every time step (0) for all domains
# ==================================================================================
#
    my @bldt = @{$Config{uconf}{BLDT}};
   
    if ($bldt[0]) {
        my $mesg = "The recommended call frequency to the PBL and LSM schemes is every ".
                   "time step (BLDT = 0). Your frequency is every $bldt[0] minutes.\n\n".
                   "You are on your own for this simulation!";
        &Ecomm::PrintMessage(6,11+$Rconf{arf},88,1,2,'About your PBL Time Step',$mesg);
    }


return @bldt;
}


sub Config_grav_settling {
# ==================================================================================
#   Option:  GRAV_SETTLING - Include gravitational settling of fog/cloud droplets
#
#   Values:  MAX DOMAINS 
#
#     0 - No settling of cloud droplets
#     1 - Settling from Dyunkerke 1991 (in atmos and at surface)
#     2 - Fogdes (vegetation & wind speed dependent) at surface and Dyunkerke in the atmos.
#
#     Info:  Per module_check_a_mundo.F (V3.7): GRAV_SETTLING = 0 with MP_PHYSICS = 28
#            because MP_PHYSICS (28) already has a gravitational settling scheme.
#            (UEMS enforced so you don't have to worry).
#
#     Notes: Available for all PBL Schemes
#
#   Default:  GRAV_SETTLING = 0
# ==================================================================================
#
    my @grav_settling = @{$Config{uconf}{GRAV_SETTLING}};


return @grav_settling;
}


sub Config_scalar_pblmix {
# ==================================================================================
#   Option:  SCALAR_PBLMIX - Mix scalar fields consistent with PBL option (exch_h)
#
#   Values:  MAX DOMAINS
#
#     0 - Do not mix scalar fields consistent with PBL option (exch_h)
#     1 - Mix scalar fields consistent with PBL option (exch_h)
#
#     Info:  Per module_check_a_mundo.F (V3.8): SCALAR_PBLMIX must be turned ON
#            with MP_PHYSICS = 28 (UEMS enforced so you don't have to worry).
#
#     Notes: Available for all PBL Schemes
#
#   Default:  SCALAR_PBLMIX = 1
# ==================================================================================
#
    my @scalar_pblmix = @{$Config{uconf}{SCALAR_PBLMIX}};


return @scalar_pblmix;
}


sub Config_tracer_pblmix {
# ==================================================================================
#   Option:  TRACER_PBLMIX - Mix tracer fields consistent with PBL option (exch_h)
#
#   Values: MAX DOMAINS
#
#     0 - Do not mix tracer fields consistent with PBL option (exch_h)
#     1 - Mix tracer fields consistent with PBL option (exch_h)
#
#   Default:  TRACER_PBLMIX = 1
# ==================================================================================
#
    my @tracer_pblmix = @{$Config{uconf}{TRACER_PBLMIX}};


return @tracer_pblmix;
}


sub Config_topo_wind {
# ==================================================================================
#   Option:  TOPO_WIND - Topographic correction for surface winds
#
#   Values: (MAX DOMAINS)
#
#     0 - No Topographic drag correction
#     1 - Use Jimenez and Dudhia Method
#     2 - Use simpler terrain variance-related correction (Mass - UW)
#
#   Notes:   Topographic correction for surface winds to represent extra drag
#            from sub-grid topography and enhanced flow at hill tops. Shown to
#            reduce 10m wind biases, which is good, but designed for dx < 2km,
#            which is a bummer.
#
#   Default: TOPO_WIND = 0 (No Topographic drag correction)
# ==================================================================================
#   
    #  Make sure parameter value is same as parent unless 
    #
    my @mapped = map {$Config{uconf}{TOPO_WIND}[$_] ? $Config{uconf}{TOPO_WIND}[$Config{parentidx}[$_]] 
                                                    ? $Config{uconf}{TOPO_WIND}[$Config{parentidx}[$_]] 
                                                    : $Config{uconf}{TOPO_WIND}[$_] : 0} 0..$Config{maxindex};

    #  Turn OFF if PBL scheme is turned OFF
    #
    my @topo_wind = map {$Physics{bl_pbl_physics}[$_] ? $mapped[$_] : 0} 0..$Config{maxindex};

    
return @topo_wind;
}


sub Config_icloud_bl {
# ==================================================================================
#   Option:  ICLOUD_BL - Couple the sub-grid scale clouds from the MYNN PBL
#                        scheme to the radiation scheme.
#
#   Values:
#
#     0 - No coupling  (Boo! Coupling!)
#     1 - Yes coupling (Yay Coupling!)
#
#   Default: ICLOUD_BL = 1 (Because we all should like coupling)
# ==================================================================================
#
    my @icloud_bl = @{$Config{uconf}{ICLOUD_BL}};


return @icloud_bl;
}


sub Config_bl_mynn_tkeadvect {
# ==================================================================================
#   Option:  BL_MYNN_TKEADVECT - Turns ON|OFF advection of TKE in the PBL
#
#   Values: 
#
#     T - Do MYNN tke advection
#     F - Do not advect TKE
#
#   Default: BL_MYNN_TKEADVECT = F (No TKE Advection)
# ==================================================================================
#
    my @bl_mynn_tkeadvect = map {$Physics{bl_pbl_physics}[$_] ? $Config{uconf}{BL_MYNN_TKEADVECT}[$_] : 'F'} 0..$Config{maxindex};


return @bl_mynn_tkeadvect;
}


sub Config_bl_mynn_cloudmix {
# ==================================================================================
#   Option:  BL_MYNN_CLOUDMIX - Turns ON|OFF the mixing of qc and qi in MYNN
#
#   Note:    qnc and qni are mixed when SCALAR_PBLMIX = 1
#
#   Values:
#
#     0 - Do not mix qc & qi, and don't mix my vegetables either!
#     1 - Mix qc & qi  (Mix it real good)
#
#   Default: BL_MYNN_CLOUDMIX = 1 (Mix it up)
# ==================================================================================
#
    my @bl_mynn_cloudmix = map {$Physics{bl_pbl_physics}[$_] ? $Config{uconf}{BL_MYNN_CLOUDMIX}[$_] : 0} 0..$Config{maxindex};


return @bl_mynn_cloudmix;
}


sub Config_bl_mynn_mixlength {
# ==================================================================================
#   Option:  BL_MYNN_MIXLENGTH - Option to change mixing length formulation in MYNN
#
#   Values:
#
#     0 - Original (Nakanishi and Niino 2009)
#     1 - RAP/HRRR (including BouLac in free atmosphere)
#     2 - Experimental (includes cloud-specific mixing length and a scale-aware
#         mixing length; following Ito et al. 2015, BLM); this option has been
#         well-tested with the edmf options.
#
#   Default: BL_MYNN_MIXLENGTH = 1 (RAP/HRRR)
# ==================================================================================
#
    my @bl_mynn_mixlength = ($Config{uconf}{BL_MYNN_MIXLENGTH}[0]);


return @bl_mynn_mixlength;
}


sub Config_bl_mynn_tkebudget {
# ==================================================================================
#   Option:  BL_MYNN_TKEBUDGET - Turns ON|OFF diagnostic printing of TKE budget 
#
#   Values: (MAX DOMS)
#
#     0 - Do not outout TKE budget
#     1 - Do MYNN tke budget output
#
#   Default: BL_MYNN_TKEBUDGET = 0 (No diagnostic info)
# ==================================================================================
#
    my @bl_mynn_tkebudget = map {$Physics{bl_pbl_physics}[$_] ? $Config{uconf}{BL_MYNN_TKEBUDGET}[$_] : 0} 0..$Config{maxindex};


return @bl_mynn_tkebudget;
}


sub Config_bl_mynn_cloudpdf {
# ==================================================================================
#   Option:  BL_MYNN_CLOUDPDF - Option to change mixing length formulation in MYNN
#
#   Values:
#
#     0 - Original (Sommeria and Deardorf 1977)
#     1 - Similar to option 0, but uses resolved scale gradients, as opposed to higher order moments (Kuwano et al. 2010)
#     2 - Chaboureau and Bechtold 2002
#
#   Default: BL_MYNN_CLOUDPDF = 2 (Chaboureau and Bechtold 2002)
# ==================================================================================
#
    my @bl_mynn_cloudpdf = ($Config{uconf}{BL_MYNN_CLOUDPDF}[0]);


return @bl_mynn_cloudpdf;
}


sub Config_bl_mynn_edmf {
# ==================================================================================
#   Option:  BL_MYNN_EDMF - Option to activate mass-flux scheme in MYNN
#
#   Notes:   Additional configuration of BL_MYNN_EDMF_MOM & BL_MYNN_EDMF_TKE
#
#   Values:
#
#     0 - Regular MYNN
#     1 - For StEM
#     2 - For TEMF
#
#   Default: BL_MYNN_EDMF = 0 (Regular MYNN)
# ==================================================================================
#
    my @bl_mynn_edmf = map {$Physics{bl_pbl_physics}[$_] ? $Config{uconf}{BL_MYNN_EDMF}[$_] : 0} 0..$Config{maxindex};


return @bl_mynn_edmf;
}


sub Config_bl_mynn_edmf_mom {
# ==================================================================================
#   Option:  BL_MYNN_EDMF_MOM - Option to activate momentum transport in MYNN
#                               mass-flux scheme (BL_MYNN_EDMF > 0)
#
#   Notes:   Only valid when BL_MYNN_EDMF > 0
#
#   Values:
#
#     0 - No momentum transport
#     1 - Activate momentum transport
#
#   Default: BL_MYNN_EDMF_MOM = 1 (Activate momentum transport)
# ==================================================================================
#
    my @bl_mynn_edmf_mom = map {$Physics{bl_pbl_physics}[$_] ? $Config{uconf}{BL_MYNN_EDMF_MOM}[$_] : 0} 0..$Config{maxindex};


return @bl_mynn_edmf_mom;
}


sub Config_bl_mynn_edmf_tke {
# ==================================================================================
#   Option:  BL_MYNN_EDMF_TKE - Option to activate TKE transport in MYNN
#                               mass-flux scheme (BL_MYNN_EDMF > 0)
#
#   Notes:   Only valid when BL_MYNN_EDMF > 0
#
#   Values:
#
#     0 - Just say "No"
#     1 - Say "Yes" to TKE energy transport
#
#   Default: BL_MYNN_EDMF_TKE = 0 (No TKE transport)
# ==================================================================================
#
    my @bl_mynn_edmf_tke = map {$Physics{bl_pbl_physics}[$_] ? $Config{uconf}{BL_MYNN_EDMF_TKE}[$_] : 0} 0..$Config{maxindex};


return @bl_mynn_edmf_tke;
}


sub Config_shinhong_tke_diag {
# ==================================================================================
#   Option:  SHINHONG_TKE_DIAG - Turns ON|OFF diagnostic TKE and mixing length
#
#   Values: 
#
#     0 - Turn ON diagnostic TKE and mixing length
#     1 - Save for a rainy day
#
#   Note:    Scale-aware designed for sub-1km grid scale
#
#   Default: SHINHONG_TKE_DIAG = 0
# ==================================================================================
#
    my @shinhong_tke_diag = map {$Physics{bl_pbl_physics}[$_] ? $Config{uconf}{SHINHONG_TKE_DIAG}[$_] : 0} 0..$Config{maxindex};


return @shinhong_tke_diag;
}


sub Config_ysu_topdown_pblmix {
# ==================================================================================
#   Option:  YSU_TOPDOWN_PBLMIX - Turns ON|OFF top-down radiation-driven mixing
#
#   Values:  (Single value in ARW core)
#
#     0 - No top-down radiation-driven mixing
#     1 - Yes, I want me some top-down mixing action
#
#   Default: YSU_TOPDOWN_PBLMIX = 0 (No top-down mixing action)
# ==================================================================================
#
    my @ysu_topdown_pblmix = $Physics{bl_pbl_physics}[0] ? ($Config{uconf}{YSU_TOPDOWN_PBLMIX}[0]) : (0);


return @ysu_topdown_pblmix;
}


sub Physics_PBL_ConsistencyCheck {
# ==================================================================================
#   This subroutine is a catch-all for any final PBL Scheme checks to ensure
#   consistency or compatibility of the scheme with the computational domains 
#   as well as other configuration options. 
#
#   In others words, the PBL configuration "Junk Drawer".
# ==================================================================================
#

    #  Check whether the PBL Scheme is turned OFF for either the primary or a child domain
    #
    my $i = &Others::IntegerIndexMatchExact(0,@{$Physics{bl_pbl_physics}});


    #  If $i has a value greater than 0 then the PBL scheme has been turned OFF between the 
    #  primary and a child domain. If the value equals 0 then it's turned OFF for the parent;
    #  otherwise, a value less then 0 (-1) indicates the PBL is ON for all domains.
    #
    if ($i > 0) {

        my $mesg = qw{};
        my $d  = $i+1;
        my $dx = sprintf '%.1f',($Rconf{dinfo}{domains}{$d}{dx} > 1000.) ? 0.001*$Rconf{dinfo}{domains}{$d}{dx} : $Rconf{dinfo}{domains}{$d}{dx};
           $dx = $Rconf{dinfo}{domains}{$d}{dx} > 1000 ?  "$dx kilometers" : "$dx meters";


        #  Check if the PBL scheme is being turned OFF within a subdomain that it has a 
        #  surface layer scheme that supports running without PBL scheme. Since the surface
        #  layer scheme is loosely tied to the bl_pbl_physics value, the surface layer schemes
        #  used with PBL schemes 3,4, & 10 do not support LES (at least currently.).
        #  
        if (grep {/^0$/} @{$Physics{bl_pbl_physics}} and grep {/^$Physics{bl_pbl_physics}[0]$/} (3,4,10) ) {
            $mesg = "You have turned OFF your PBL scheme within domain ${d}; however, the surface layer scheme used ".
                    "with the chosen PBL does not support an LES. You must go back to the run_physics_boundarylayer.conf ".
                    "file and select a different scheme.\n\n".
                    "Yes, I'm making you do the heavy lifting this time!";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Boundary Layer Troubles:',$mesg);
            return;
        }

    } elsif ($i == 0 and $Rconf{dinfo}{domains}{1}{dx} > 0.40) {

        my $dx = sprintf '%.1f',($Rconf{dinfo}{domains}{1}{dx} > 1000.) ? 0.001*$Rconf{dinfo}{domains}{1}{dx} : $Rconf{dinfo}{domains}{1}{dx};
           $dx = $Rconf{dinfo}{domains}{1}{dx} > 1000 ?  "$dx kilometers" : "$dx meters";

        my $mesg = qw{};

        $mesg = "You have turned OFF your PBL scheme for the primary domain, which has a grid spacing of $dx. ".
                "It is not recommended that you turn off the PBL scheme with grid spacing greater than 400m ".
                "unless this is a cloud scale simulation.\n\n".

                "If this is an LES, then your primary domain should have a grid spacing of 400 meters or less ".
                "and then nest down as necessary. The details of running an LES can be found in the LES ".
                "\"How-To\" Appendix in the UEMS User's Guide.\n\n".

                "In the mean time, I will leave you in pursuit of your dastardly plan.";

         &Ecomm::PrintMessage(6,11+$Rconf{arf},88,1,2,'Just Keeping My Eye On You:',$mesg);

    }

 
return;
}


sub Physics_SurfaceLayer {
# ==============================================================================================
# WRF &PHYSICS NAMELIST CONFIGURATION FOR SURFACE LAYER SCHEMES AND STUFF
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This subroutine manages the configuration of all things surface layer in the
#   &physics section of the WRF namelist file. 
#
#   Note that some (most) of the information used to produce the guidance presented
#   in this file was likely taken from the WRF user's guide and presentation materials,
#   and those authors should receive all the gratitude as well as any proceeds that 
#   may be derived from reading this information.
#
#   Some basic guidance to follow:
#
#      a.  Handle the calculation of heat, moisture and momentum fluxes between the
#          surface (skin) and reference model level, typically the 1st model, 2m or
#          10m level. These exchange coefficients are used by the LSM.
#
#      b.  Provide friction velocities to PBL scheme
#
#      c.  Provide the surface fluxes over water points (but not over land)
#
#      d.  Calculations are a function of Zo - roughness length
#
#      e.  The roughness length is a function of land-use type
#
#      f.  Roughness lengths are a measure of the “initial” length scale of surface
#          eddies, and generally differ for velocity and scalars
#
#      g.  Some schemes use smaller roughness length for heat than for momentum
#
#      h.  For water points roughness length is a function of surface wind speed
#
#      i.  The exchange coefficient for heat is related to roughness length and u*
#
# ==============================================================================================
# ==============================================================================================
#

    #-----------------------------------------------------------------------------
    #  PHYSICS Variable:  SF_SFCLAY_PHYSICS
    #
    #    The SF_SFCLAY_PHYSICS parameter defines the surface layer scheme to use in your
    #    simulation. The scheme is NOT the land surface model (LSM), but rather, handles
    #    the calculation of necessary information at the surface-atmosphere interface
    #    in the model (exchange/transfer coeffs). Because much of this information is
    #    used by the PBL scheme, the choice of SF_SFCLAY_PHYSICS is limited by the
    #    BL_PBL_PHYSICS setting.
    #
    #    Note: Values are tied to choice of PBL scheme
    #
    #      0 - No surface layer                     Use with  bl_pbl_physics=0
    #      1 - Revised MM5 MoninObukhov (prev 11)   Use with  bl_pbl_physics=0,1,5,6,7,8,9,11,12
    #      2 - MYJ MoninObukhov similarity theory   Use with  bl_pbl_physics=0,2,5,6,8,9
    #      3 - NCEP Global Forecast System scheme (NMM only)  bl_pbl_physics=3
    #      4 - QNSE MoninObukhov similarity theory  Use with  bl_pbl_physics=4
    #      5 - MYNN MoninObukhov similarity theory  Use with  bl_pbl_physics=5,6
    #      7 - PleimXiu surface layer (EPA)         Use with  bl_pbl_physics=7 and sf_surface_physics=7
    #     10 - TEMF surface layer                   Use with  bl_pbl_physics=10
    #     91 - Old SF_SFCLAY_PHYSICS = 1 (mm5)      Use with  bl_pbl_physics=0,1,5,6,7,8,9,11,12
    #
    #-----------------------------------------------------------------------------
    #
    
    #  The same physics scheme must be used for all domains. IT'S THE MODULE_CHECK_A_MUNDO.F LAW!
    #
    @{$Physics{sf_sfclay_physics}} = @{$Config{uconf}{SF_SFCLAY_PHYSICS}};


    #  -------------------------- Additional SF_SFCLAY_PHYSICS Configuration ------------------------------------------
    #  If SF_SFCLAY_PHYSICS is turn ON then complete additional configuration for the selected scheme.
    #  Note that the use of individual subroutines is not necessary since all the variables are
    #  global, but it make for cleaner code. Also - Most of the pre-configuration of user 
    #  defined variables was done in &ReadConfigurationFilesARW, the values from which
    #  used here. The only difficulty in writing this code was how to organize the individual
    #  variables that need to be set for each CU scheme. Some variables are valid for all schemes
    #  some for different schemes, and others for only one scheme.
    #
    #  So an executive decision was made for the cleanest solution. There are individual subroutines
    #  for each parameter, which are called from a separate subroutine for each CU scheme. Parameters
    #  that are always used together are combined into a single subroutine.  Hopefully it will all
    #  work out because I'm closing my eyes.
    #  ----------------------------------------------------------------------------------------------------------------
    #
    for ($Physics{sf_sfclay_physics}[0]) {

        &Physics_SL00_NoSurfaceLayer()         if $_ ==  0; 
        &Physics_SL01_MoninObukhovMM5()        if $_ ==  1;
        &Physics_SL02_MoninObukhovMYJ()        if $_ ==  2;
        &Physics_SL03_GlobalForecastSystem()   if $_ ==  3;
        &Physics_SL04_MoninObukhovQSNE()       if $_ ==  4;
        &Physics_SL05_MoninObukhovMYNN()       if $_ ==  5;
        &Physics_SL07_PleimXiu()               if $_ ==  7;
        &Physics_SL10_TEMF()                   if $_ == 10;
        &Physics_SL91_OldMoninObukhovMM5()     if $_ == 91;

    }


return;
}  #  Physics_SurfaceLayer


sub Physics_SL00_NoSurfaceLayer {
# ==================================================================================
#  Configuration options for SF_SFCLAY_PHYSICS = 0 Surface Layer Scheme
#
#  Here because it might be needed - Someday
# ==================================================================================
#
    @{$Physics{isfflx}}              = &Config_isfflx(0);


return;
}


sub Physics_SL01_MoninObukhovMM5 {
# ==================================================================================
#  Configuration options for SF_SFCLAY_PHYSICS = 1 Surface Layer Scheme
#
# ==================================================================================
#
    @{$Physics{isfflx}}              = &Config_isfflx(1);
    @{$Physics{iz0tlnd}}             = &Config_iz0tlnd();
    @{$Physics{isftcflx}}            = &Config_isftcflx();

    @{$Physics{fractional_seaice}}   = &Config_fractional_seaice();
    @{$Physics{seaice_threshold}}    = &Config_seaice_threshold() if $Physics{fractional_seaice}[0];
    @{$Physics{tice2tsk_if2cold}}    = &Config_tice2tsk_if2cold() if $Physics{fractional_seaice}[0];


return;
}


sub Physics_SL02_MoninObukhovMYJ {
# ==================================================================================
#  Configuration options for SF_SFCLAY_PHYSICS = 2 Surface Layer Scheme
#
# ==================================================================================
#
    @{$Physics{isfflx}}              = &Config_isfflx(2);

    @{$Physics{fractional_seaice}}   = &Config_fractional_seaice();
    @{$Physics{seaice_threshold}}    = &Config_seaice_threshold() if $Physics{fractional_seaice}[0];
    @{$Physics{tice2tsk_if2cold}}    = &Config_tice2tsk_if2cold() if $Physics{fractional_seaice}[0];


return;
}


sub Physics_SL03_GlobalForecastSystem {
# ==================================================================================
#  Configuration options for SF_SFCLAY_PHYSICS = 3 Surface Layer Scheme
#
# ==================================================================================
#
    @{$Physics{isfflx}}              = &Config_isfflx(3);

    @{$Physics{fractional_seaice}}   = &Config_fractional_seaice();
    @{$Physics{seaice_threshold}}    = &Config_seaice_threshold() if $Physics{fractional_seaice}[0];
    @{$Physics{tice2tsk_if2cold}}    = &Config_tice2tsk_if2cold() if $Physics{fractional_seaice}[0];


return;
}


sub Physics_SL04_MoninObukhovQSNE {
# ==================================================================================
#  Configuration options for SF_SFCLAY_PHYSICS = 4 Surface Layer Scheme
#
# ==================================================================================
#
    @{$Physics{isfflx}}              = &Config_isfflx(4);

    @{$Physics{fractional_seaice}}   = &Config_fractional_seaice();
    @{$Physics{seaice_threshold}}    = &Config_seaice_threshold() if $Physics{fractional_seaice}[0];
    @{$Physics{tice2tsk_if2cold}}    = &Config_tice2tsk_if2cold() if $Physics{fractional_seaice}[0];


return;
}


sub Physics_SL05_MoninObukhovMYNN  {
# ==================================================================================
#  Configuration options for SF_SFCLAY_PHYSICS = 5 Surface Layer Scheme
#
# ==================================================================================
#
    @{$Physics{isfflx}}              = &Config_isfflx(5);

    @{$Physics{iz0tlnd}}             = &Config_iz0tlnd();

    @{$Physics{fractional_seaice}}   = &Config_fractional_seaice();
    @{$Physics{seaice_threshold}}    = &Config_seaice_threshold() if $Physics{fractional_seaice}[0];
    @{$Physics{tice2tsk_if2cold}}    = &Config_tice2tsk_if2cold() if $Physics{fractional_seaice}[0];


return;
}


sub Physics_SL07_PleimXiu {
# ==================================================================================
#  Configuration options for SF_SFCLAY_PHYSICS = 7 Surface Layer Scheme
#
# ==================================================================================
#
    @{$Physics{isfflx}}              = &Config_isfflx(7);

    @{$Physics{fractional_seaice}}   = &Config_fractional_seaice();
    @{$Physics{seaice_threshold}}    = &Config_seaice_threshold() if $Physics{fractional_seaice}[0];
    @{$Physics{tice2tsk_if2cold}}    = &Config_tice2tsk_if2cold() if $Physics{fractional_seaice}[0];


return;
}


sub Physics_SL10_TEMF {
# ==================================================================================
#  Configuration options for SF_SFCLAY_PHYSICS = 10 Surface Layer Scheme
#
# ==================================================================================
#
    @{$Physics{isfflx}}              = &Config_isfflx(10);

return;
}


sub Physics_SL91_OldMoninObukhovMM5 {
# ==================================================================================
#  Configuration options for SF_SFCLAY_PHYSICS = 91 Surface Layer Scheme
#
# ==================================================================================
#
    @{$Physics{isfflx}}              = &Config_isfflx(1);
    @{$Physics{iz0tlnd}}             = &Config_iz0tlnd();
    @{$Physics{isftcflx}}            = &Config_isftcflx();

    @{$Physics{fractional_seaice}}   = &Config_fractional_seaice();
    @{$Physics{seaice_threshold}}    = &Config_seaice_threshold() if $Physics{fractional_seaice}[0];
    @{$Physics{tice2tsk_if2cold}}    = &Config_tice2tsk_if2cold() if $Physics{fractional_seaice}[0];


return;
}



#
# ==================================================================================
# ==================================================================================
#      SO BEGINS THE INDIVIDUAL PARAMETER CONFIGURATION SUBROUTINES
# ==================================================================================
# ==================================================================================
#

sub Config_isfflx {
# ==================================================================================
#   Option:  ISFFLX - Source for heat and moisture fluxes from the surface
#
#   Notes:   The rationale and affects of the ISFFLX setting must take
#            into account the BL_PBL_PHYSICS setting, specifically, whether
#            BL_PBL_PHYSICS is ON or OFF (BL_PBL_PHYSICS = 0).
#
# ----------------------------------------------------------------------------------
#   When the PBL scheme is ON and SF_SFCLAY_PHYSICS = 1, 5, or 7 (Only)
#
#   Values (0 or 1):
#
#     0 - Turn OFF latent & sensible heat fluxes from the surface
#     1 - Turn ON  latent & sensible heat fluxes from the surface
#
#         With the PBL scheme turned ON (normal), this options serves to
#         provide a sensitivity test for the impact of surface fluxes on
#         a simulation.
#
#   Default: ISFFLX = 1 (ON) when BL_PBL_PHYSICS is ON
#
# ----------------------------------------------------------------------------------
#   When the PBL scheme is OFF (BL_PBL_PHYSICS = 0):
#
#   Notes:   The PBL scheme should only be OFF (BL_PBL_PHYSICS = 0) with
#            grid spacing of 300m or less.  If this is a real data case
#            then consider keeping PBL ON unless unless grid spacing is
#            less than 100m. Additionally, if your DX is less then 1km
#            then strongly consider increasing the number of vertical
#            layers to more than 100.
#
#            When the PBL scheme is OFF you are also turning off the
#            diffusion in your simulation. Thus, when BL_PBL_PHYSICS = 0,
#            you should use DIFF_OPT = 2 and KM_OPT = 2 or 3 (Dynamics).
#
#   Values (0, 1, or 2):
#
#     0 - Do not use surface latent & sensible heat fluxes, but rather, use
#         the values for tke_drag_coefficient & tke_heat_flux found in the
#         dynamics configuration file. (SF_SFCLAY_PHYSICS = 0 Only)
#
#         This combination, ISFFLX = 0, BL_PBL_PHYSICS = 0, and SF_SFCLAY_PHYSICS = 0,
#         only works with DIFF_OPT = 2 (Dynamics) and appropriate values for
#         tke_drag_coefficient & tke_heat_flux. IDEALIZED SIMULATIONS ONLY
#
#     1 - Use model computed drag (u*), and latent & sensible heat fluxes from
#         the surface.
#
#         To use ISFFLX = 1, SF_SFCLAY_PHYSICS must be ON (unlike value 0) and
#         DIFF_OPT = 2 or 3 (Dynamics).  USE FOR REAL DATA SIMULATIONS WHEN
#         BL_PBL_PHYSICS = 0.
#
#     2 - Use model computed drag (u*), but fluxes are provided by tke_heat_flux
#
#         For this option, SF_SFCLAY_PHYSICS must be ON because that is where u*
#         is derived and appropriate values for tke_heat_flux are needed.
#
#   Default:  ISFFLX = 1
#
# ==================================================================================
#

    # -------------------------------------------------------------------------------
    #  The problem here is that we do not know that status of the pbl scheme if
    #  the surface layer is non-zero, so the values will have to be reviewed 
    #  during the final physics configuration.
    # -------------------------------------------------------------------------------
    #
    my $sfl    = shift;
    my @isfflx = @{$Config{uconf}{ISFFLX}};

    unless ($isfflx[0]) {

        @isfflx = (0); #  Just making sure
        if (grep {/^$sfl$/} (1,5,7)) {
            my $mesg = "Were you aware that the surface fluxes are turned OFF (ISFFLX = 0)?\n".
                       "You must be testing the impact of surface latent & sensible heat fluxes ".
                       "on the simulation.\n\n".
                       "BTW - I like your style!";
            &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,'Surface Fluxes are turned OFF', $mesg);
        } else {
            my $mesg = "Were you aware that the surface fluxes are turned OFF (ISFFLX = 0)? You must ".
                       "be testing the impact of surface latent & sensible heat fluxes on the simulation; ".
                       "however, this option may not be valid with SF_SFCLAY_PHYSICS = $sfl. A better choice ".
                       "would be SF_SFCLAY_PHYSICS = 1.";
            &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,'Surface Fluxes are turned OFF', $mesg);
        }
    }
    @isfflx = (0) unless $sfl;  #  Set to 0 if no surface layer used
     
return @isfflx;
}


sub Config_iz0tlnd {
# ==================================================================================
#   Option:  IZ0TLND - Switch to control thermal roughness length over land 
#
#   Values:
#
#     0 - Original or non-vegetation dependent thermal roughness length over land
#     1 - Chen-Zhang thermal roughness length over land, which depends on vegetation height
#
#   Notes:   SF_SFCLAY_PHYSICS = 1 or 5
#
#   Default: IZ0TLND = 1
# ==================================================================================
#
    my @iz0tlnd = @{$Config{uconf}{IZ0TLND}};


return @iz0tlnd;
}


sub Config_isftcflx {
# ==================================================================================
#   Option:  ISFTCFLX - Alternative surface-layer options for high-wind ocean surface
#
#   Notes:   Modify surface bulk drag (Donelan) and enthalpy coefficients to be 
#            more in line with recent research results of those for tropical storms
#            and hurricanes. This option also includes dissipative heating term in
#            heat flux. 
#
#            It is only available for SF_SFCLAY_PHYSICS = 1
#
#   Values:
#
#     If SF_SFCLAY_PHYSICS = 1:
#
#       0 = OFF (default)
#       1 = Constant Z0q (since V3.2) for heat and moisture
#       2 = Garratt formulation, slightly different forms for heat and moisture
#
#   Default: ISFTCFLX = 0
# ==================================================================================
#
    my @isftcflx = @{$Config{uconf}{ISFTCFLX}};


return @isftcflx;
}


sub Config_fractional_seaice {
# ==================================================================================
#   Option: FRACTIONAL_SEAICE - Treat sea-ice as fractional field or ice/no-ice
#
#           A set of modifications to better represent processes and conditions over 
#           the high latitudes and a capability to allow for fractional sea-ice coverage.
#
#           The option to interpret the sea-ice array as a fractional field was added. 
#           The range is 0.0 to 1.0, meaning 0% to 100% coverage of a model grid cell 
#           by sea ice. 
#
#           If the user selects the fractional sea-ice option, surface layer routines that
#           compute surface exchange coefficients and fluxes are called twice: once for
#           once for open-water conditions and once for ice-cover conditions. The resulting
#           values are then averaged between open-water and ice-cover results, weighted 
#           by the sea-ice fraction.
#   
#           To use the fractional sea-ice option, a fractional sea-ice field is necessary 
#           for input to WRF. This field may come from, for example, NCEP GFS output, or
#           other sources (e.g., various datasets available from the National Snow and Ice
#           Data Center: http://nsidc.org/data/seaice/index.html)
#
#
#   Values:
#           0 - Treat Sea Ice field as 1|0 (All or Nothing)
#           1 - Treat Sea Ice field as a fraction
#
#
#   Notes:  The FRACTIONAL_SEAICE option may only be used with:
#
#              SF_SURFACE_PHYSICS = 2 (NOAH), 3 (RUC), 4 (NOAH), 7 (Pleim-Xiu), and 8 (SSiB)
#           And
#              SF_SFCLAY_PHYSICS  = 1 (MM5 Monin), 2 (Janjic Monin-Obukhov), 4 (QNSE), 5 (MYNN), and 7 (Pleim-Xiu)
#
#
#  The UEMS SAYS:  
#  
#           The GFS dataset includes fractional sea ice. So if you are using the GFS to 
#           initialize a simulation you should be OK for fractional seaice.
#
#           Another source:  http://nsidc.org/data/seaice/index.html
#
#           Also, tests show that there is NO difference in the netCDF files from metdat
#           when using XICE Vs SEAICE with GFS data as described in the WRF User's Guide.
#           consequently, you should be OK in using FRACTIONAL_SEAICE = 1 without any
#           special configuration. - Just go for it.
#
#           If FRACTIONAL_SEAICE ON (FRACTIONAL_SEAICE=1) SEAICE_THRESHOLD is automatically
#           set to 100.0 K; otherwise, 271.4 K
#
#           For SF_SURFACE_PHYSICS = 8 (SSiB), FRACTIONAL_SEAICE is automatically turned ON since
#           the source code mandates its use.
#                              
#  Default: FRACTIONAL_SEAICE = 0
# ==================================================================================
#
    my @fractional_seaice = @{$Config{uconf}{FRACTIONAL_SEAICE}};


return @fractional_seaice;
}


sub Config_seaice_threshold {
# ==================================================================================
#   Option:   SEAICE_THRESHOLD - Threshold water temperature below which to set 
#                                to land point and permanent ice
#
#   Notes:    *  Used with SF_SURFCE_PHYSICS = 1, 2, 3, 4, or 8
#             *  Avoid using this option if FRACTIONAL_SEAICE = 1
#             *  If FRACTIONAL_SEAICE = 1 then set SEAICE_THRESHOLD = 100
#             *  If FRACTIONAL_SEAICE = 0 then set SEAICE_THRESHOLD = 271
#  
#             *  Value set in &ProcessLocalConfiguration for UEMS
#
#   Default: SEAICE_THRESHOLD = 271.4 (if FRACTIONAL_SEAICE = 0)
#            SEAICE_THRESHOLD = 100.0 (if FRACTIONAL_SEAICE = 1)
# ==================================================================================
#
    my @seaice_threshold = @{$Config{uconf}{SEAICE_THRESHOLD}};


return @seaice_threshold;
}


sub Config_tice2tsk_if2cold {
# ==================================================================================
#   Option:  TICE2TSK_IF2COLD - Set Tice to Tsk to avoid unrealistically low 
#                               sea ice temperatures
#
#   Default: TICE2TSK_IF2COLD = T (if FRACTIONAL_SEAICE = 1)
#            TICE2TSK_IF2COLD = F (if FRACTIONAL_SEAICE = 0)
# ==================================================================================
#
    my @tice2tsk_if2cold = @{$Config{uconf}{TICE2TSK_IF2COLD}};


return @tice2tsk_if2cold;
}


sub Physics_LandSurface {
# ==============================================================================================
# WRF &PHYSICS NAMELIST CONFIGURATION FOR LAND SURFACE SCHEMES AND STUFF
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This subroutine manages the configuration of all things land surface model in the
#   &physics section of the WRF namelist file. 
#
#   Note that some (most) of the information used to produce the guidance presented
#   in this file was likely taken from the WRF user's guide and presentation materials,
#   and those authors should receive all the gratitude as well as any proceeds that 
#   may be derived from reading this information.
#
#   The SF_SURFACE_PHYSICS parameter defined the land-surface model (LSM) to use when running
#   a simulation. The scheme handles many of the complex atmospheric processes near the surface
#   including the prediction of:
#
#      a. Soil temperature and moisture
#      b. Snow water equivalent on ground
#      c. Canopy moisture & temperature
#      d. Vegetation and soil processes
#      e. Some urban effects
#
#   Note that your choice of LSM will be influenced by the land surface/use dataset
#   used during localization:
#
#                LSM Physics                             Land Use Dataset
#   -------------------------------------------------------------------------------------------
#      Thermal Diffusion LSM (SF_SURFACE_PHYSICS = 1) | USGS and USGS+lakes
#      Unified Noah LSM      (SF_SURFACE_PHYSICS = 2) | USGS, USGS+lakes, MODIS, and MODIS+lakes
#      RUC LSM               (SF_SURFACE_PHYSICS = 3) | USGS, USGS+lakes, MODIS, and MODIS+lakes
#      Unified MP Noah LSM   (SF_SURFACE_PHYSICS = 4) | USGS, USGS+lakes, MODIS, and MODIS+lakes
#      Community Land Model  (SF_SURFACE_PHYSICS = 5) | USGS (no lakes)
#      Pleim-Xiu LSM         (SF_SURFACE_PHYSICS = 7) | MODIS, USGS (no lakes), NLCD2006, and NLCD2011
#      SSiB LSM              (SF_SURFACE_PHYSICS = 8) | USGS (no lakes), SSIB
#   -------------------------------------------------------------------------------------------
#
# ==============================================================================================
# ==============================================================================================
#
    @{$Ptables{lsm}} = ();

    #-----------------------------------------------------------------------------
    #  PHYSICS Variable:  SF_SURFACE_PHYSICS
    #
    #    The sf_surface_physics scheme that is used depends upon the value of num_land_cat
    #    and whether the user is running without a PBL scheme. Options are:
    #
    #      0 - No Land Surface Model
    #      1 - Thermal diffusion scheme
    #      2 - Unified Noah land-surface model
    #      3 - RUC land-surface model
    #      4 - Unified multi-physics land-surface model (additional &noah_mp namelist)
    #      5 - Community Land Model version 4 (CLM4), adapted from CAM
    #      7 - Pleim-Xiu LSM - Used for retrospective simulations with plxm_soil_nudge
    #      8 - Simplified Simple Biosphere Model (SSiB)
    #
    #   The NOAH and RUC schemes above require that soil moisture and temperature
    #   fields be available in the initialization dataset. It is also best that 
    #   the type of LSM scheme be consistent with the dataset used for initialization. 
    #   So use the RAP initialization dataset with the RAP LSM  and the NAM/GFS/NNRP
    #   Finally, spin-up issues may occur if static surface datasets, such as the 
    #   land-use and soil types, are inconsistent between initialization dataset
    #   and LSM scheme, but this may be unavoidable.
    #-----------------------------------------------------------------------------
    #
   
 
    #  The same physics scheme must be used for all domains. IT'S THE MODULE_CHECK_A_MUNDO.F LAW!
    #
    @{$Physics{sf_surface_physics}} = @{$Config{uconf}{SF_SURFACE_PHYSICS}};

   

    #  ------------------------- Additional SF_SURFACE_PHYSICS Configuration ------------------------------------------
    #  If SF_SURFACE_PHYSICS is turn ON then complete additional configuration for the selected scheme.
    #  Note that the use of individual subroutines is not necessary since all the variables are
    #  global, but it make for cleaner code. Also - Most of the pre-configuration of user 
    #  defined variables was done in &ReadConfigurationFilesARW, the values from which
    #  used here. The only difficulty in writing this code was how to organize the individual
    #  variables that need to be set for each CU scheme. Some variables are valid for all schemes
    #  some for different schemes, and others for only one scheme.
    #
    #  So an executive decision was made for the cleanest solution. There are individual subroutines
    #  for each parameter, which are called from a separate subroutine for each CU scheme. Parameters
    #  that are always used together are combined into a single subroutine.  Hopefully it will all
    #  work out.
    #  ----------------------------------------------------------------------------------------------------------------
    #
    for ($Physics{sf_surface_physics}[0]) {

        &Physics_LS00_NONE()          if $_ == 0; #  No Land Surface Mosel Used (SF_SURFACE_PHYSICS = 0)
        &Physics_LS01_5LAYER()        if $_ == 1; #  5-Layer Thermal Diffusion (SF_SURFACE_PHYSICS = 1)
        &Physics_LS02_NOAH()          if $_ == 2; #  NOAH Land Surface Model (SF_SURFACE_PHYSICS = 2)
        &Physics_LS03_RUC()           if $_ == 3; #  RUC Land Surface Model (SF_SURFACE_PHYSICS = 3)
        &Physics_LS04_NOAHMP()        if $_ == 4; #  Noah-MP (multi-physics) Land Surface Model (SF_SURFACE_PHYSICS = 4)
        &Physics_LS05_CLM4()          if $_ == 5; #  Community Land Model Version 4 (SF_SURFACE_PHYSICS = 5)
        &Physics_LS07_PleimXiu()      if $_ == 7; #  2-Layer Pleim-Xiu Land Surface Model (SF_SURFACE_PHYSICS = 7)
        &Physics_LS08_SSIB()          if $_ == 8; #  Simplified Simple Biosphere Model (SF_SURFACE_PHYSICS = 8)

        return 1 if  $ENV{RMESG};

        @{$Physics{num_soil_layers}}   = &Config_num_soil_layers($_);  #  Here because its scheme dependent
    }

    @{$Physics{num_land_cat}}          = &Config_num_land_cat();
    @{$Physics{num_soil_cat}}          = &Config_num_soil_cat();
    @{$Physics{surface_input_source}}  = &Config_surface_input_source();
    @{$Physics{usemonalb}}             = &Config_usemonalb();
    @{$Physics{rdmaxalb}}              = &Config_rdmaxalb();
    @{$Physics{tmn_update}}            = &Config_tmn_update();
    @{$Physics{lagday}}                = &Config_lagday() if $Physics{tmn_update}[0];


return;
}  #  Physics_LandSurface


sub Physics_LS00_NONE {
# ==================================================================================
#  No Land Surface Mosel Used (SF_SURFACE_PHYSICS = 0)
#
# ==================================================================================
#

    #------------------------------------------------------------
    #  Set the tables to be used by the (non) land surface model
    #------------------------------------------------------------
    #
    @{$Ptables{lsm}} = ();


return;
}


sub Physics_LS01_5LAYER {
# ==================================================================================
#  5-Layer Thermal Diffusion (SF_SURFACE_PHYSICS = 1)
#
#  Soil temperature only scheme that uses five layers. Hence the name. Thermal 
#  properties depend on land use. No soil moisture  or snow-cover prediction.
#  Moisture availability depends on land-use only. (Skamarock et al, 2005)
# ==================================================================================
#
    @{$Physics{ifsnow}}   = &Config_ifsnow();


    #------------------------------------------------------------
    #  Set the tables to be used by land surface model
    #------------------------------------------------------------
    #
    my @lstables = qw(GENPARM.TBL LANDUSE.TBL SOILPARM.TBL VEGPARM.TBL);

    @{$Ptables{lsm}} = &TableLocateLS(@lstables);


return;
}


sub Physics_LS02_NOAH {
# ==================================================================================
#  NOAH Land Surface Model (SF_SURFACE_PHYSICS = 2)
#
#  NOAH Land Surface Model: Unified NCEP/NCAR/AFWA scheme with soil temperature
#  and moisture in four layers, fractional snow cover, and frozen soil physics.
#  Vegetation effects included. Predicts snow cover and canopy moisture. Diagnoses
#  skin temperature ans uses emissivity. Provided heat and moisture fluxes to
#  the PBL. (Chen and Dudhia, 2001).
# ==================================================================================
#
    @{$Physics{opt_thcnd}}               = &Config_opt_thcnd();
    @{$Physics{rdlai2d}}                 = &Config_rdlai2d();
    @{$Physics{ua_phys}}                 = &Config_ua_phys();
    @{$Physics{sf_surface_mosaic}}       = &Config_sf_surface_mosaic();
    @{$Physics{mosaic_cat}}              = &Config_mosaic_cat() if $Physics{sf_surface_mosaic}[0];


    # Unsure whether these apply to ALL LSM schemes or just NOAH
    #
    @{$Physics{seaice_snowdepth_opt}}     = &Config_seaice_snowdepth_opt();
    @{$Physics{seaice_snowdepth_min}}     = &Config_seaice_snowdepth_min();
    @{$Physics{seaice_snowdepth_max}}     = &Config_seaice_snowdepth_max();

    @{$Physics{seaice_albedo_opt}}        = &Config_seaice_albedo_opt();
    @{$Physics{seaice_albedo_default}}    = &Config_seaice_albedo_default() unless $Physics{seaice_albedo_opt}[0];

    @{$Physics{seaice_thickness_opt}}     = &Config_seaice_thickness_opt();
    @{$Physics{seaice_thickness_default}} = &Config_seaice_thickness_default() unless $Physics{seaice_thickness_opt}[0];

    #------------------------------------------------------------
    #  Set the tables to be used by land surface model
    #------------------------------------------------------------
    #
    my @lstables = qw(GENPARM.TBL LANDUSE.TBL SOILPARM.TBL VEGPARM.TBL MPTABLE.TBL VEGPARM.TBL);

    @{$Ptables{lsm}} = &TableLocateLS(@lstables);

    
return;
}


sub Physics_LS03_RUC {
# ==================================================================================
#  RUC Land Surface Model (SF_SURFACE_PHYSICS = 3)
#
#  RUC Land Surface Model: The RUC operational scheme with soil temperature and
#  moisture in six layers, multi-layer snow and frozen soil physics. The possibility
#  exists for 9 soil moisture and temperature layers. Used in the operational HRRR.
#  (Smirnove et al. 1997, 2000).
# ==================================================================================
#
    @{$Physics{rdlai2d}}             = &Config_rdlai2d();
    @{$Physics{mosaic_lu}}           = &Config_mosaic_lu();
    @{$Physics{mosaic_soil}}         = &Config_mosaic_soil();

    #------------------------------------------------------------
    #  Set the tables to be used by land surface model
    #------------------------------------------------------------
    #
    my @lstables = qw(GENPARM.TBL LANDUSE.TBL SOILPARM.TBL VEGPARM.TBL);

    @{$Ptables{lsm}} = &TableLocateLS(@lstables);


return;
}


sub Physics_LS04_NOAHMP {
# ==================================================================================
#  Noah-MP (multi-physics) Land Surface Model (SF_SURFACE_PHYSICS = 4)
# 
#  Noah-MP (multi-physics) Land Surface Model: uses multiple options for key land-
#  atmosphere interaction processes. Noah-MP contains a separate vegetation canopy
#  defined by a canopy top and bottom with leaf physical and radiometric properties
#  used in a two-stream canopy radiation transfer scheme that includes shading effects.
#  Noah-MP contains a multi-layer snow pack with liquid water storage and melt/refreeze
#  capability and a snow-interception model describing loading/unloading, melt/refreeze,
#  and sublimation of the canopy-intercepted snow. Multiple options are available for
#  surface water infiltration and runoff, and groundwater transfer and storage including
#  water table depth to an unconfined aquifer. Horizontal and vertical vegetation density
#  can be prescribed or predicted using prognostic photosynthesis and dynamic vegetation
#  models that allocate carbon to vegetation (leaf, stem, wood and root) and soil carbon
#  pools (fast and slow).
# ==================================================================================
#

    @{$NoahMP{dveg}}                = &Config_dveg();
    @{$NoahMP{opt_crs}}             = &Config_opt_crs();
    @{$NoahMP{opt_sfc}}             = &Config_opt_sfc();
    @{$NoahMP{opt_btr}}             = &Config_opt_btr();
    @{$NoahMP{opt_run}}             = &Config_opt_run();
    @{$NoahMP{opt_frz}}             = &Config_opt_frz();
    @{$NoahMP{opt_inf}}             = &Config_opt_inf();
    @{$NoahMP{opt_rad}}             = &Config_opt_rad();
    @{$NoahMP{opt_alb}}             = &Config_opt_alb();
    @{$NoahMP{opt_snf}}             = &Config_opt_snf();
    @{$NoahMP{opt_tbot}}            = &Config_opt_tbot();
    @{$NoahMP{opt_stc}}             = &Config_opt_stc();
    @{$NoahMP{opt_gla}}             = &Config_opt_gla();
    @{$NoahMP{opt_rsf}}             = &Config_opt_rsf();


    # Unsure whether these apply to ALL LSM schemes or just NOAH
    #
    @{$Physics{seaice_snowdepth_opt}}     = &Config_seaice_snowdepth_opt();
    @{$Physics{seaice_snowdepth_min}}     = &Config_seaice_snowdepth_min();
    @{$Physics{seaice_snowdepth_max}}     = &Config_seaice_snowdepth_max();

    @{$Physics{seaice_albedo_opt}}        = &Config_seaice_albedo_opt();
    @{$Physics{seaice_albedo_default}}    = &Config_seaice_albedo_default() unless $Physics{seaice_albedo_opt}[0];

    @{$Physics{seaice_thickness_opt}}     = &Config_seaice_thickness_opt();
    @{$Physics{seaice_thickness_default}} = &Config_seaice_thickness_default() unless $Physics{seaice_thickness_opt}[0];

    #------------------------------------------------------------
    #  Set the tables to be used by land surface model
    #------------------------------------------------------------
    #
    my @lstables = qw(GENPARM.TBL LANDUSE.TBL SOILPARM.TBL VEGPARM.TBL MPTABLE.TBL VEGPARM.TBL);

    @{$Ptables{lsm}} = &TableLocateLS(@lstables);


return;
}


sub Physics_LS05_CLM4 {
# ==================================================================================
#  Community Land Model Version 4 (SF_SURFACE_PHYSICS = 5)
#
#  CLM4 (Community Land Model Version 4): CLM4 was developed at the National Center for
#  Atmospheric Research with many external collaborators and represents a state-of-the-
#  science land surface process model. It contains sophisticated treatment of biogeophysics,
#  hydrology, biogeochemistry, and dynamic vegetation. In CLM4, the land surface in each
#  model grid cell is characterized into five primary sub-grid land cover types (glacier,
#  lake, wetland, urban, and vegetated). The vegetated sub-grid consists of up to 4 plant
#  functional types (PFTs) that differ in physiology and structure. The WRF input land
#  cover types are translated into the CLM4 PFTs through a look-up table. The CLM4
#  vertical structure includes a single-layer vegetation canopy, a five-layer snowpack,
#  and a ten layer soil column.
#
#
#  Highlights:
#    *  10-level soil, 5-level snow
#    *  Sub-grid tiling
#    *  CESM land component
#    *  Further capabilities not activated: dynamic vegetation 
#       (AKA "Chia Pet" Parameterization), lake model, carbon-nitrogen cycle
#
#  Notes:
#    *  Does not work with any Urban Canopy Model (SF_URBAN_PHYSICS)
#    *  Must be using USGS (24) or MODIS (20/21) Land Categories
#    *  Does not work with MYJ PBL - Per module_surface_driver.F
#
#    !  As good as the CLM4 may be, it will bring your simulation to a crawl!
#
#  An earlier version of CLM has been quantitatively evaluated within WRF in Jin and
#  Wen (2012; JGR-Atmosphere), Lu and Kueppers (2012; JGR-Atmosphere), and Subin et al.
#  (2011; Earth Interactions) (from Jin).
# ==================================================================================
#

    #  Check compatibility between CLM4 and PBL Scheme
    #
    if ($Physics{bl_pbl_physics}[0] == 2) {
        my $mesg = "The Community Land Model (CLM4) does not work with the MYJ PBL (BL_PBL_PHYSICS = 2) scheme. ".
                   "So it appears that you have two choices - make a difference today.\n\n".
                   "Well, don\'t just look at me (Although I know you can't help it), do something!";  
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'The Configuration Force is not with you today:',$mesg);
        return;
    }

    #------------------------------------------------------------
    #  Set the tables to be used by land surface model
    #------------------------------------------------------------
    # 
    my @lstables = qw(CLM_ALB_ICE_DFS_DATA CLM_ALB_ICE_DRC_DATA CLM_ASM_ICE_DFS_DATA CLM_ASM_ICE_DRC_DATA 
                      CLM_EXT_ICE_DFS_DATA CLM_EXT_ICE_DRC_DATA CLM_DRDSDT0_DATA CLM_KAPPA_DATA CLM_TAU_DATA
                      GENPARM.TBL LANDUSE.TBL SOILPARM.TBL VEGPARM.TBL URBPARM.TBL);

    @{$Ptables{lsm}} = &TableLocateLS(@lstables);


return;
}


sub Physics_LS07_PleimXiu {
# ==================================================================================
#  2-Layer Pleim-Xiu Land Surface Model (SF_SURFACE_PHYSICS = 7)
#
#  Pleim-Xiu Land Surface Model (EPA): A two-layer scheme with vegetation and
#  sub-grid tilting. Includes simple snow-cover model. Users should recognize that
#  the PX LSM was primarily developed for retrospective simulations, where surface-
#  based observations are available to inform the indirect soil nudging. While it
#  may be run without soil nudging, little testing has been done in this mode,
#  although some users have reported reasonable results. UEMS users have
#  encountered problems when using the PX LSM without surface nudging.
#
#  Notes:
#    *  Works with MODIS, USGS, NLCD2006, and NLCD2011 land use datasets.
# ==================================================================================
#
    unless ($Physics{bl_pbl_physics}[0] == 7 and $Physics{sf_sfclay_physics}[0] == 7) {
        my $mesg = "The Pleim-Xiu Land Surface Model (7) will only work as part of the Pleim-Xiu ".
                   "\"Fantasic Physics Family\". Consequently, you will have to go back to the ".
                   "run_physics_boundarylayer.conf file and specify Pleim-Xiu (7) as your PBL scheme.\n\n".

                   "Just Remember, \"7\" was the rabbit's lucky number in \"Schoolhouse Rock.\" It might also be yours.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,82,0,0,'All In The Pleim-Xiu Family',$mesg);
        return;
    }
    @{$Physics{pxlsm_smois_init}}           = &Config_pxlsm_smois_init();


    #------------------------------------------------------------
    #  Set the tables to be used by land surface model
    #------------------------------------------------------------
    #
    my @lstables = qw(GENPARM.TBL LANDUSE.TBL SOILPARM.TBL VEGPARM.TBL);

    @{$Ptables{lsm}} = &TableLocateLS(@lstables);


return;
}


sub Physics_LS08_SSIB {
# ==================================================================================
#  Simplified Simple Biosphere Model (SF_SURFACE_PHYSICS = 8)
#
#  SSiB Land Surface Model: This is the third generation of the Simplified
#  Simple Biosphere Model (Xue et al. 1991; Sun and Xue, 2001). SSiB is developed
#  for land/atmosphere interaction studies in the climate model. The aerodynamic
#  resistance values in SSiB are determined in terms of vegetation properties,
#  ground conditions and bulk Richardson number according to the modified Monin–
#  Obukhov similarity theory. SSiB-3 includes three snow layers to realistically
#  simulate snow processes, including destructive metamorphism, densification
#  process due to snow load, and snow melting, which substantially enhances the
#  model’s ability for the cold season study.
#
#  To use this option, ra_lw_physics and ra_sw_physics must be set to 1, 3, or 4
#  and the fractional seaice option must be turned ON (fractional_seaice = 1);
#  however, use of the SSiB model with fractional_seaice is not documented
#  anywhere except within the model code (module_surface_driver.F), so Caveat 
#  Emptor!
#
#  Additionally, the second full model level should be set to no larger than
#  0.982 so that the height of that level is higher than vegetation height.
#
#  IMPORTANT:
#
#  The SSIB LSM is designed to work with the SSIB land use dataset but may
#  also be used with USGS. These datasets are specified during the creation of
#  the computational domain. Since the default is MODIS, you may need to re-
#  localize your domain with "ems_domain" and passing "--landuse ssib".
#
#  And if the above is not enough, SSiB MUST be used with a PBL scheme, so no
#  LES or cloud-scale simulations with the SSiB.
#
#  ONCE AGAIN:
#
#    a. The SSiB scheme only works with:
#
#       *  LW & SW radiation schemes - RRTM (1), CAM (3), or RRTMG (4) (& 24?)
#       *  PBL Scheme - YSU (1)
#       *  Surface Layer Scheme - Monin-Obukhov (1)  (Set automatically)
#       *  Fractional Sea Ice ON (Set automatically)
#
#    b. The second full model level above ground, 1.0 being the first, must be
#       equal or smaller than 0.982 (0.979 is OK, 0.985 is not OK), which means
#       you will likely have to manually set the LEVELS parameter in run_levels.conf.
#       This is because SSiB requires that this level be above the vegetation
#       height. A 28-level example might look like:
#
#       LEVELS = 1.000, 0.982, 0.973, 0.964, 0.946, 0.922, 0.894, 0.860, 0.817, 0.766,
#                0.707, 0.644, 0.576, 0.507, 0.444, 0.380, 0.324, 0.273, 0.228, 0.188,
#                0.152, 0.121, 0.093, 0.069, 0.048, 0.029, 0.014, 0.000
# ==================================================================================
#
    my $mesg = qw{};

    #  The SSiB scheme apparently only plays well with the YSA PBL scheme
    #
    unless ($Physics{bl_pbl_physics}[0] == 1) { 
        $mesg = "The SSiB LSM must be used with the YSU PBL scheme (BL_PBL_PHYSICS = 1). So change either your ".
                "setting for SF_SURFACE_PHYSICS or BL_PBL_PHYSICS to something more reasonable; otherwise, I will ".
                "whip this error out again.\n\n".
                "And I have an itchy taser finger!";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Greetings from the UEMS Sheriff:',$mesg);
        return;
    }


    #  SSiB has problems with many physics schemes - Only available with RA_SW|LW_PHYSICS = 1,3,4,24
    #
    unless ( (grep {/^$Physics{ra_sw_physics}[0]$/} (1,3,4,24))  and (grep {/^$Physics{ra_lw_physics}[0]$/} (1,3,4,24)) ) {
        $mesg = "From the UEMS Overlord: When using the Simplified Simple Biosphere Land Surface Model (SF_SURFACE_PHYSICS = 8), ".
                "you must use options 1, 3, 4, or 24 for the LW and SW radiation schemes. Your choice of RA_SW_PHYSICS = ".
                "$Physics{ra_sw_physics}[0] and RA_LW_PHYSICS = $Physics{ra_lw_physics}[0] just won't work.\n\n".
                "And don't make me regurgitate this message again!";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Configuration Confusion Again:',$mesg);
        return;
    }

    
    $mesg = "When using the SSiB Land Surface Model, the first level above the surface (1.0) MUST be less than or equal ".
            "to 0.982. For example, a value of 0.979 is OK, but 0.985 is not OK.  This is because the SSiB model requires ".
            "that the first level be above the vegetation height.\n\n".

            "If you simply set LEVELS = # Levels in run_levels.conf, then this requirement might not be satisfied. You will ".
            "likely have to manually set the individual level values. See run_levels.conf for details.";
             
     &Ecomm::PrintMessage(1,11+$Rconf{arf},86,1,2,'The Facts of (SSiB) Life:', $mesg);


    #------------------------------------------------------------
    #  Set the tables to be used by land surface model
    #------------------------------------------------------------
    #
    my @lstables = qw(GENPARM.TBL LANDUSE.TBL SOILPARM.TBL VEGPARM.TBL);

    @{$Ptables{lsm}} = &TableLocateLS(@lstables);


return;
}


#
# ==================================================================================
# ==================================================================================
#      SO BEGINS THE INDIVIDUAL PARAMETER CONFIGURATION SUBROUTINES
# ==================================================================================
# ==================================================================================
#

sub Config_num_land_cat {
# ==================================================================================
#  PHYSICS Variable:  NUM_LAND_CAT
#
#    The num_land_cat specifies the number of land categories, which should be
#    the same as the num_land_cat attribute in the metgrid files. If the global
#    attribute ISLAKE in the metgrid files indicates that there is a special
#    land use category for lakes, the real program will substitute the TAVGSFC 
#    field for the SST field only over those grid points whose category matches
#    the lake category; additionally, the real program will change the land use
#    category of lakes back to the general water category (the category used for
#    oceans), since neither the LANDUSE.TBL nor the VEGPARM.TBL files contain an
#    entry for a lake category.
#
#       MODIS LSM Data: num_land_cat = 20 or 21 (w/lakes)
#       USGS  LSM Data: num_land_cat = 24 or 28 (w/lakes)
#       NLCD  LSM Data: num_land_cat = 40 
#
#    Note that either we should have a valid value for NUM_LAND_CAT or an empty
#    array indicating ems_prep was not run prior to ems_run. A
#
#    All consistency checks were done in &ReadConfigurationFilesARW
# ==================================================================================
#
    my @num_land_cat = @{$Config{uconf}{NUM_LAND_CAT}};


return @num_land_cat;
}


sub Config_surface_input_source {
# ==================================================================================
#   Option:  SURFACE_INPUT_SOURCE - Specifies source of landuse and soil category data
#
#   Values:
#
#     1 - WPS/geogrid, but with dominant categories recomputed in real (default WRF V3.7)
#     2 - GRIB data from another model (only if arrays VEGCAT/SOILCAT exist)
#     3 - Like 1 but use dominant land and soil categories from WPS/geogrid 
#
#   Default: SURFACE_INPUT_SOURCE = 3
# ==================================================================================
#
    my @surface_input_source = @{$Config{uconf}{SURFACE_INPUT_SOURCE}};


return @surface_input_source;
}


sub Config_num_soil_layers {
# ==================================================================================
#  PHYSICS Variable:  NUM_SOIL_LAYERS
#
#    Values are dependent on LSM scheme selected:
#    
#      5 - Thermal Diffusion Scheme        (sf_surface_physics = 1)
#      4 - Unified Noah Land-Surface Model (sf_surface_physics = 2 & 4)
#    6|9 - RUC Land-Surface Model          (sf_surface_physics = 3) -> Currently set to 6 cause it works
#     10 - Community Land Model version 4  (sf_surface_physics = 5)
#      2 - Pleim-Xiu LSM                   (sf_surface_physics = 7)
#      8 - SSiB Land-Surface Model         (sf_surface_physics = 8)
# ==================================================================================
#
    my @num_soil_layers = ();

    my $lsm = shift;

    @num_soil_layers = ($lsm == 1)  ?  (5)  :
                       ($lsm == 2)  ?  (4)  :
                       ($lsm == 3)  ?  ($Config{uconf}{RUC_NUM_SOIL_LEVELS}[0])  :
                       ($lsm == 4)  ?  (4)  :
                       ($lsm == 5)  ?  (10) :
                       ($lsm == 7)  ?  (2)  :
                       ($lsm == 8)  ?  (3)  : (4);


return @num_soil_layers;
}


sub Config_rdlai2d {
# ==================================================================================
#   Option:  RDLAI2D - Source of Leaf Area Index (LAI) data
#
#   Values:
#
#     T - Read LAI values from GEOGRID input files
#     F - Read LAI values from tables
#
#   Default:  RDLAI2D = T
# ==================================================================================
#
    my @rdlai2d = @{$Config{uconf}{RDLAI2D}};


return @rdlai2d;
}


sub Config_rdmaxalb {
# ==================================================================================
#   Option:  RDMAXALB - Source of snow albedo values
#
#   Values:
#
#     T - Use GEOGRID snow albedo instead of table values
#     F - Use the snow albedo values from tables
#
#   Default:  RDMAXALB = T
# ==================================================================================
#
    my @rdmaxalb = @{$Config{uconf}{RDMAXALB}};


return @rdmaxalb;
}


sub Config_usemonalb {
# ==================================================================================
#   Option:  USEMONALB - Source of albedo values
#
#   Values:
#
#     T - Use GEOGRID climatological albedo instead of table values
#     F - Use the albedo values from tables
#
#   Default:  USEMONALB = T
# ==================================================================================
#
    my @usemonalb = @{$Config{uconf}{USEMONALB}};


return @usemonalb;
}


sub Config_tmn_update {
# ==================================================================================
#   Option:  TMN_UPDATE - Update deep layer soil temperature
#
#     0 - Turn OFF deep layer soil temperature update
#     1 - Turn ON  deep layer soil temperature update
#
#   Notes:   Useful for long simulations
#
#   Default: TMN_UPDATE = 0 (OFF)
# ==================================================================================
#
    my @tmn_update = @{$Config{uconf}{TMN_UPDATE}};


return @tmn_update;
}


sub Config_lagday {
# ==================================================================================
#   Option:  LAGDAY - Days over which TMN is computed using skin temperature
#
#   Notes:   Only used when TMN_UPDATE = 1
#
#   Default: LAGDAY = 150
# ==================================================================================
#
    my @lagday = @{$Config{uconf}{LAGDAY}};


return @lagday;
}


sub Config_num_soil_cat {
# ==================================================================================
#   Option:  NUM_SOIL_CAT - Number of soil categories in initialization data
#
#   Notes:   Looking though the code did not clairify the purpose of this option
#
#   Default: NUM_SOIL_CAT = 16
# ==================================================================================
#
    my @num_soil_cat = @{$Config{uconf}{NUM_SOIL_CAT}};


return @num_soil_cat;
}


sub Config_ifsnow {
# ==================================================================================
#   Option:  IFSNOW - Turns ON|OFF surface snow cover effects
#
#   Values:
#
#     0 - Turn OFF snow cover effects
#     1 - Turn ON  snow cover effects
#
#   Notes:    Only for Thermal Diffusion (SF_SURFACE_PHYSICS = 1) LSM
#
#   Default:  IFSNOW = 1 (ON)
# ==================================================================================
#
    my @ifsnow = @{$Config{uconf}{IFSNOW}};


return @ifsnow;
}


sub Config_sf_surface_mosaic {
# ==================================================================================
#   Option:  SF_SURFACE_MOSAIC - Turns ON|OFF option to MOSAIC landuse categories
#
#   Values:
#
#     0 - Use dominant land use category only
#     1 - Use mosaic landuse categories (Also see MOSAIC_CAT)
#
#   Default:  SF_SURFACE_MOSAIC = 1 if NOAH LSM
# ==================================================================================
#
    my @sf_surface_mosaic = @{$Config{uconf}{SF_SURFACE_MOSAIC}};


return @sf_surface_mosaic;
}


sub Config_mosaic_cat {
# ==================================================================================
#   Option:  MOSAIC_CAT - The number of mosaic landuse categories allowed in a grid cell
#
#   Values:  1 to total number of land use categories (Don't be greedy)
#
#   Default: MOSAIC_CAT = 3
# ==================================================================================
#
    my @mosaic_cat = @{$Config{uconf}{MOSAIC_CAT}};


return @mosaic_cat;
}


sub Config_mosaic_lu {
# ==================================================================================
#   Option:  MOSAIC_LU - option to specify landuse parameters based on a mosaic 
#                        approach when using the RUC LSM
#
#   Values:  1 (ON) or 0 (OFF)
#
#   Default: MOSAIC_LU = 1
# ==================================================================================
#
    my @mosaic_lu = @{$Config{uconf}{MOSAIC_LU}};


return @mosaic_lu;
}


sub Config_mosaic_soil {
# ==================================================================================
#   Option:  MOSAIC_SOIL - option to specify soil parameters based on a mosaic 
#                          approach when using the RUC LSM
#
#   Values:  1 (ON) or 0 (OFF)
#
#   Default: MOSAIC_SOIL = 1
# ==================================================================================
#
    my @mosaic_soil = @{$Config{uconf}{MOSAIC_SOIL}};


return @mosaic_soil;
}


sub Config_ua_phys {
# ==================================================================================
#   Option:  UA_PHYS - Activate new snow-cover physics
#
#   Values:
#
#     T - Activate new physics
#     F - I'm enjoying the old physics "Thank you very much"
#
#   Notes:   Activate changes to NOAH LSM that use different snow-cover physics
#            to improve the treatment of snow as it relates to the vegetation
#            canopy. Also uses new columns added in VEGPARM.TBL.
#
#   Default: UA_PHYS = T
# ==================================================================================
#
    my @ua_phys = @{$Config{uconf}{UA_PHYS}};


return @ua_phys;
}

sub Config_seaice_snowdepth_opt {
# ==================================================================================
#   Option:   SEAICE_SNOWDEPTH_OPT - Method for treating snow depth on sea ice
#
#   Values:
#
#     0 - snow depth on sea ice is bounded by SEAICE_SNOWDEPTH_MAX and SEAICE_SNOWDEPTH_MIN
#     1 - snow depth on sea ice read in from input array SNOWSI but still bounded by
#         SEAICE_SNOWDEPTH_MAX and SEAICE_SNOWDEPTH_MIN
#
#  Default:  SEAICE_SNOWDEPTH_OPT = 0
# ==================================================================================
#
    my @seaice_snowdepth_opt = @{$Config{uconf}{SEAICE_SNOWDEPTH_OPT}};


return @seaice_snowdepth_opt;
}


sub Config_seaice_snowdepth_min {
# ==================================================================================
#   Option:   SEAICE_SNOWDEPTH_MIN - Minimum allowed accumulation of snow (m) on sea ice
#
#   Default:  SEAICE_SNOWDEPTH_MIN = 0.001 meters
# ==================================================================================
#
    my @seaice_snowdepth_min = @{$Config{uconf}{SEAICE_SNOWDEPTH_MIN}};


return @seaice_snowdepth_min;
}


sub Config_seaice_snowdepth_max {
# ==================================================================================
#   Option:   SEAICE_SNOWDEPTH_MAX - Maximum allowed accumulation of snow (m) on sea ice
#
#   Default:  SEAICE_SNOWDEPTH_MAX = 100. meter
# ==================================================================================
#
    my @seaice_snowdepth_max = @{$Config{uconf}{SEAICE_SNOWDEPTH_MAX}};


return @seaice_snowdepth_max;
}


sub Config_seaice_thickness_opt {
# ==================================================================================
#   Option:   SEAICE_THICKNESS_OPT - Method for treating sea ice thickness
#
#   Values:
#
#     0 - Seaice thickness is uniform value taken from namelist variable SEAICE_THICKNESS_DEFAULT
#     1 - Seaice_thickness is read in from input variable ICEDEPTH
#
#   Notes:  Unless you know that the ICEDEPTH fields is available in your netCDF initialization
#           files, set SEAICE_THICKNESS_OPT = 0.
#
#  Default:  SEAICE_THICKNESS_OPT = 0
# ==================================================================================
#
    my @seaice_thickness_opt = @{$Config{uconf}{SEAICE_THICKNESS_OPT}};


return @seaice_thickness_opt;
}


sub Config_seaice_thickness_default {
# ==================================================================================
#  Option:   SEAICE_THICKNESS_DEFAULT - Default value of seaice thickness for SEAICE_THICKNESS_OPT = 0
#
#  Default:  SEAICE_THICKNESS_DEFAULT = 3.0
# ==================================================================================
#
    my @seaice_thickness_default = @{$Config{uconf}{SEAICE_THICKNESS_DEFAULT}};


return @seaice_thickness_default;
}


sub Config_seaice_albedo_opt {
# ==================================================================================
#   Option:   SEAICE_ALBEDO_OPT - Option to set albedo over sea ice
#
#   Values:
#
#     0 - Seaice albedo is a constant value set by SEAICE_ALBEDO_DEFAULT
#     1 - Seaice albedo is f(Tair,Tskin,Snow) following Mills (2011) for Arctic Ocean
#     2 - Seaice albedo read in from input variable ALBSI
#
#  Notes:   SEAICE_ALBEDO_OPT = 1 Only available with NOAH LSM (SF_SURFACE_PHYSICS = 2,4)
#
#  Default: SEAICE_ALBEDO_OPT = 0
# ==================================================================================
#
    my @seaice_albedo_opt = @{$Config{uconf}{SEAICE_ALBEDO_OPT}};


return @seaice_albedo_opt;
}


sub Config_seaice_albedo_default {
# ==================================================================================
#   Option:   SEAICE_ALBEDO_DEFAULT - Default value of seaice albedo when SEAICE_ALBEDO_OPT = 0
#
#   Default: SEAICE_ALBEDO_DEFAULT = 0.65
# ==================================================================================
#
    my @seaice_albedo_default = @{$Config{uconf}{SEAICE_ALBEDO_DEFAULT}};


return @seaice_albedo_default;
}


sub Config_opt_thcnd {
# ==================================================================================
#   Option:  OPT_THCND
#
#   Values:
#
#     1 - The original (what ever that is)
#     2 - McCumber and Pielke for silt loam and sandy loam
#
#   Default:  OPT_THCND = 1 (Original)
# ==================================================================================
#
    my @opt_thcnd = @{$Config{uconf}{OPT_THCND}};


return @opt_thcnd;
}


sub Config_pxlsm_smois_init {
# ==================================================================================
#   Option:  PXLSM_SMOIS_INIT - Soil moisture initialization option
#
#   Values:
#
#     0 - Get values from analysis
#     1 - From moisture availability or SLMO in LANDUSE.TBL
#
#   Default:  PXLSM_SMOIS_INIT = 1
# ==================================================================================
#
    my @pxlsm_smois_init = @{$Config{uconf}{PXLSM_SMOIS_INIT}};


return @pxlsm_smois_init;
}


sub Config_dveg {
# ==================================================================================
#  DVEG - Noah-MP Dynamic Vegetation option
#
#  Options are:
#
#    1  -  Off (LAI from table; FVEG = shdfac)
#    2  -  On
#    3  -  Off (LAI from table; FVEG calculated)
#    4  -  Off (LAI from table; FVEG = maximum veg. fraction)
#    5  -  On  (LAI predicted;  FVEG = maximum veg. fraction)
#
#  Default value is DVEG = 4
# ==================================================================================
#
    my @dveg = @{$Config{uconf}{DVEG}};


return @dveg;
}


sub Config_opt_crs {
# ==================================================================================
#  OPT_CRS - Noah-MP Stomatal Resistance option
#
#  Options are:
#
#    1  -  Ball-Berry
#    2  -  Jarvis
#
#  Default value is OPT_CRS = 1
# ==================================================================================
#
    my @opt_crs = @{$Config{uconf}{OPT_CRS}};


return @opt_crs;
}


sub Config_opt_sfc {
# ==================================================================================
#  OPT_SFC - MP surface layer drag coefficient calculation
#
#  Options are:
#
#    1  -  Monin-Obukhov
#    2  -  Original Noah
#
#  Default value is OPT_SFC = 1
# ==================================================================================
#
    my @opt_sfc = @{$Config{uconf}{OPT_SFC}};


return @opt_sfc;
}


sub Config_opt_btr {
# ==================================================================================
#  OPT_BTR - Noah-MP Soil Moisture Factor for Stomatal Resistance
#
#  Options are:
#
#    1  -  Noah
#    2  -  CLM
#    3  -  SSiB
#
#  Default value is OPT_BTR = 1
# ==================================================================================
#
    my @opt_btr = @{$Config{uconf}{OPT_BTR}};


return @opt_btr;
}


sub Config_opt_run {
# ==================================================================================
#  OPT_RUN - Noah-MP Runoff and Groundwater option
#
#  Options are:
#
#    1  -  TOPMODEL with groundwater
#    2  -  TOPMODEL with equilibrium water table
#    3  -  Original surface and subsurface runoff (free drainage)
#    4  -  BATS surface and subsurface runoff (free drainage)
#
#  Default value is OPT_RUN = 1
# ==================================================================================
#
    my @opt_run = @{$Config{uconf}{OPT_RUN}};


return @opt_run;
}


sub Config_opt_frz {
# ==================================================================================
#  OPT_FRZ - Noah-MP Supercooled Liquid Water option
#
#  Options are:
#
#    1  -  No iteration
#    2  -  Koren's iteration
#
#  Default value is OPT_FRZ = 1
# ==================================================================================
#
    my @opt_frz = @{$Config{uconf}{OPT_FRZ}};


return @opt_frz;
}


sub Config_opt_inf {
# ==================================================================================
#  OPT_INF - Noah-MP Soil Permeability option
#
#  Options are:
#
#    1  -  Linear effects, more permeable
#    2  -  Non-linear effects, less permeable
#
#  Default value is OPT_INF = 1
# ==================================================================================
#
    my @opt_inf = @{$Config{uconf}{OPT_INF}};


return @opt_inf;
}


sub Config_opt_rad {
# ==================================================================================
#  OPT_RAD - Noah-MP Radiative Transfer option
#
#  Options are:
#
#    1  -  Modified two-stream
#    2  -  Two-stream applied to grid-cell
#    3  -  Two-stream applied to vegetated fraction
#
#  Default value is OPT_RAD = 3
# ==================================================================================
#
    my @opt_rad = @{$Config{uconf}{OPT_RAD}};


return @opt_rad;
}


sub Config_opt_alb {
# ==================================================================================
#  OPT_ALB - Noah-MP Ground Surface Albedo option
#
#  Options are:
#
#    1  -  BATS
#    2  -  CLASS
#
#  Default value is OPT_ALB = 2
# ==================================================================================
#
    my @opt_alb = @{$Config{uconf}{OPT_ALB}};


return @opt_alb;
}


sub Config_opt_snf {
# ==================================================================================
#  OPT_SNF - Noah-MP Precipitation Partitioning between snow and rain
#
#  Options are:
#
#    1  -  Jordan (1991)
#    2  -  BATS:  Snow when SFCTMP < TFRZ+2.2
#    3  -  Snow when SFCTMP < TFRZ
#    4  -  Use partitioning based on output from MP scheme
#
#  Default value is OPT_SNF = 4
# ==================================================================================
#
    my @opt_snf = @{$Config{uconf}{OPT_SNF}};


return @opt_snf;
}


sub Config_opt_tbot {
# ==================================================================================
#  OPT_TBOT - Noah-MP Soil Temperature Lower Boundary Condition
#
#  Options are:
#
#    1  -  Zero heat flux
#    2  -  TBOT at 8 m from input file
#
#  Default value is OPT_TBOT = 2
# ==================================================================================
#
    my @opt_tbot = @{$Config{uconf}{OPT_TBOT}};


return @opt_tbot;
}


sub Config_opt_stc {
# ==================================================================================
#  OPT_STC - Noah-MP Snow/Soil temperature time scheme
#
#  Options are:
#
#    1  -  Semi-implicit
#    2  -  Full-implicit
#    3  -  Semi-implicit where Ts use snow cover fraction
#
#  Default value is OPT_STC = 1
# ==================================================================================
#
    my @opt_stc = @{$Config{uconf}{OPT_STC}};


return @opt_stc;
}


sub Config_opt_gla {
# ==================================================================================
#  OPT_GLA - Noah-MP  glacier treatment option
#
#  Options are:
#
#    1  -  Include phase change
#    2  -  Slab Ice
#
#  Default value is OPT_GLA = 1
# ==================================================================================
#
    my @opt_gla = @{$Config{uconf}{OPT_GLA}};


return @opt_gla;
}


sub Config_opt_rsf {
# ==================================================================================
#  OPT_RSF - Noah-MP surface evaporation resistence option
#
#  Options are:
#
#    1  -  Sakaguchi and Zeng 2009
#    2  -  Sellers 1992
#    3  -  Adjusted Sellers to decrease RSURF for wet soil
#    4  -  Option 1 for non-snow; rsurf = rsurf_snow for snow (set in MPTABLE)
#
#  Default value is OPT_RSF = 1
# ==================================================================================
#
    my @opt_rsf = @{$Config{uconf}{OPT_RSF}};


return @opt_rsf;
}



sub TableLocateLS {
# ==================================================================================
#  This routine just tests whether the required land surface tables are available.
#  It fails if a table is missing; otherwise it returns an array containing the
#  absolute path to the table file.
# ==================================================================================
#
    my @mistbl = ();
    my @lstbls = ();

    my $dlsm = "$ENV{DATA_TBLS}/wrf/physics/lsm";  # Tables located under $EMS_DATA/tables/wrf/physics/lsm

    my @tables = @_;  return () unless @tables; @tables = sort &Others::rmdups(@tables);

    foreach (@tables) { -f "$dlsm/$_" ? push @lstbls  => "$dlsm/$_" : push @mistbl => $_;}

    if (@mistbl) {  #  Oops - Some required tables are missing

        my @lines = ("Missing Land Surface Tables\n");
 
        push @lines, "The land surface physics scheme you have chosen requires the following tables files located ".
                     "in the $dlsm/ directory:\n";
 
        foreach my $table (@tables) {push @lines,sprintf("X04X%-18s %14s",$table,(grep {/^$table$/} @mistbl) ? '<- Missing!' : '');}
 
        push @lines, "\nEither you promptly locate the missing table files or change your land surface model for this simulation; ".
                     "otherwise, you will be reading these words again.\n\nBut next time, they will be written with a much angrier tone.";
 
        $ENV{RMESG} = join "\n", @lines;
 
        return ();
    }


return @lstbls;
}



sub Physics_UrbanCanopy {
# ==============================================================================================
# WRF &PHYSICS NAMELIST CONFIGURATION FOR AVAILABLE URBAN CANOPY MODELS AND STUFF
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This subroutine manages the configuration of all things urban canopy model in the
#   &physics section of the WRF namelist filei, of which there is not much.
#
#   Note that some (most) of the information used to produce the guidance presented
#   in this file was likely taken from the WRF user's guide and presentation materials,
#   and those authors should receive all the gratitude as well as any proceeds that 
#   may be derived from reading this information.
#
#   Some basic guidance to follow:
#
#   *  For dx >= 10 km: probably need cumulus scheme
#
# ==============================================================================================
# ==============================================================================================
#

    #-----------------------------------------------------------------------------
    #   NOTE: SF_URBAN_PHYSICS can ONLY be used with:
    #                                                SF_SURFACE_PHYSICS = 2 (NOAH LSM)
    #                                           and:
    #                                                BL_PBL_PHYSICS = 8 (BouLac) PBL)
    #                                             or BL_PBL_PHYSICS = 2 (Mellor-Yamada-Janjic)
    #
    #   Setting SF_URBAN_PHYSICS to a value other than 0 (OFF) activates the NOAH LSM urban canopy
    #   model. An urban canopy model is used to better represent the physical processes involved in
    #   the exchange of heat, momentum, and water vapor in urban environment. It is primarily
    #   intended for very high resolution simulations (DX < 3km) over urban areas.
    #
    #   The possible values for SF_URBAN_PHYSICS are:
    #
    #       SF_URBAN_PHYSICS = 0   - OFF (This anthropogenic mumbo-jumbo scares me)
    #
    #       SF_URBAN_PHYSICS = 1   - Single-layer, Noah UCM (Hiroyuki Kusaka)
    #
    #       SF_URBAN_PHYSICS = 2   - Multi-layer, BEP scheme (Alberto Martilli)
    #                                BEP needs additional sub-grid building fractional area information.
    #
    #       SF_URBAN_PHYSICS = 3   - Multi-layer, BEM scheme (Alberto Martilli)
    #                                BEM needs additional sub-grid building fractional area information.
    #
    #   Some of the features of the single layer model include, shadowing from buildings, reflection
    #   of short and longwave radiation, wind profile in the canopy layer and multi-layer heat transfer
    #   equation for roof, wall and road surfaces (Kusaka and Kimura, JAM, 2004). For additional information
    #   see wrf_physics_lsm_ucmA.pdf and wrf_physics_lsm_ucmA.pdf located in the ems/docs directory.
    #
    #   For V3.7 - New hydrological processes are added to single-layer UCM (SF_URBAN_PHYSICS = 1):
    #
    #       a. Oasis effect;
    #       b. Urban irrigation;
    #       c. Anthropogenic latent heat;
    #       d. Evaporation over impervious surface;
    #       e. Multi-layer green roof
    #
    #   There may be additional configuration necessary, such as for num_urban_layers; however, the
    #   documentation is very limited. See additional information located in the docs directory:
    #
    #       $UEMS/docs/wrf
    #
    #   Finally, per module_check_a_mundo.F, ALL domains must have the same value (UEMS will handle it)
    #-----------------------------------------------------------------------------
    #
    
    #  Make sure that any physics scheme used by a nested domain is also used by the parent. IT'S THE LAW!
    #
    @{$Physics{sf_urban_physics}} = @{$Config{uconf}{SF_URBAN_PHYSICS}};

   
    #  ---------------------- Additional SF_URBAN_PHYSICS Configuration ---------------------------------------------
    #  If SF_URBAN_PHYSICS is turn ON then complete additional configuration for the selected scheme.
    #  Note that the use of individual subroutines is not necessary since all the variables are
    #  global, but it make for cleaner code. Also - Most of the pre-configuration of user 
    #  defined variables was done in &ReadConfigurationFilesARW, the values from which
    #  used here. The only difficulty in writing this code was how to organize the individual
    #  variables that need to be set for each CU scheme. Some variables are valid for all schemes
    #  some for different schemes, and others for only one scheme.
    #  ----------------------------------------------------------------------------------------------------------------
    #
    for ($Physics{sf_urban_physics}[0]) {

        &Physics_UC01_SLUCM()    if $_ ==  1; #  Single-layer, Noah UCM (Hiroyuki Kusaka)
        &Physics_UC02_MLBEP()    if $_ ==  2; #  Multi-layer, BEP scheme (Alberto Martilli)
        &Physics_UC03_MLBEM()    if $_ ==  3; #  Multi-layer, BEM scheme (Alberto Martilli)

        #  Make sure the URBPARM physics tables are made available.
        #
        my @lstables     = qw(URBPARM.TBL URBPARM_UZE.TBL); @lstables = &TableLocateLS(@lstables);
        @{$Ptables{lsm}} = &Others::rmdups((@{$Ptables{lsm}},@lstables));

        return 1 if $ENV{RMESG};

    }


return;
}  #  Physics_UrbanCanopy


sub Physics_UC01_SLUCM {
# ==================================================================================
#  Single-layer, Noah UCM (Hiroyuki Kusaka)
#
#  Additional configuration would go here - if there were any
# ==================================================================================
#


return;
}


sub Physics_UC02_MLBEP {
# ==================================================================================
#  Multi-layer, BEP scheme (Alberto Martilli)
#
#  Additional configuration would go here - if there were any
# ==================================================================================
#
    unless (grep {/^$Physics{bl_pbl_physics}[0]$/} (2,8)) {
        my $mesg = "The Multi-layer, BEP scheme (SF_URBAN_PHYSICS = 2) only works with PBL option 2 (MYJ) or 8 (BouLac).\n\n".
                   "Please change your configuration and then try your luck again.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,84,0,0,'Back to the configuration files for you:',$mesg);
    }


return;
}


sub Physics_UC03_MLBEM {
# ==================================================================================
#  Multi-layer, BEM scheme (Alberto Martilli)
#
#  Additional configuration would go here - if there were any
# ==================================================================================
#
    unless (grep {/^$Physics{bl_pbl_physics}[0]$/} (2,8)) {
        my $mesg = "The Multi-layer, BEM scheme (SF_URBAN_PHYSICS = 3) only works with PBL option 2 (MYJ) or 8 (BouLac).\n\n".
                   "Please change your configuration and then try your luck again.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,84,0,0,'Back to the configuration files for you:',$mesg);
    }


return;
}


sub Physics_SeaLakes {
# ==============================================================================================
# WRF &PHYSICS NAMELIST CONFIGURATION FOR OCEANS, SEAS, LAKES, POOLS, & PUDDLES, AND STUFF
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This subroutine manages the configuration of special sea ice, lakes, & ocean physics in 
#   the &physics section of the WRF namelist file. Many of the configuraton options below
#   are associated with the model surface layer physics but placed here to avoid 
#
#   Note that some (most) of the information used to produce the guidance presented
#   in this file was likely liberated from the WRF user's guide and presentation materials,
#   and those authors should receive all the gratitude as well as any proceeds that 
#   may be derived from reading this information.
#
#   NOTE: Unlike most of the other physics configuration subroutines, this subroutine is a
#         loose collection of &physics options that have been thrown together. Consequently,
#         the organization is somewhat less strict, which is just a messy thing.
# ==============================================================================================
# ==============================================================================================
#
use List::Util qw[sum];

    
    #---------------------------------------------------------------------------------------------
    #---------------------------------------------------------------------------------------------
    #   Option:  SF_LAKE_PHYSICS - Activate lake model options (NESTED)
    #
    #   Values:
    #
    #     0 - Lake Model is OFF
    #     1 - Simple lake model turned ON
    #
    #   Notes:   The lake model is a one-dimensional mass and energy balance scheme with 20-25
    #            model layers, including up to 5 snow layers on the lake ice, 10 water layers,
    #            and 10 soil layers on the lake bottom. The lake scheme is used with actual lake
    #            points and lake depth derived from the WPS, and it also can be used with user-
    #            defined lake points and lake depth in WRF (lake_min_elev and lakedepth_default).
    #
    #            The lake scheme is independent of a land surface scheme and therefore can be used
    #            with any land surface scheme embedded in WRF. The lake scheme developments and
    #            evaluations were included in Subin et al. (2012) and Gu et al. (2013).
    #
    #   Default:  SF_LAKE_PHYSICS = 0 (OFF)
    #---------------------------------------------------------------------------------------------
    #
    @{$Physics{sf_lake_physics}} = @{$Config{uconf}{SF_LAKE_PHYSICS}};

    if (sum @{$Physics{sf_lake_physics}}) {  #  Configure if SF_LAKE_PHYSICS is ON

        @{$Physics{use_lakedepth}}     = &Config_use_lakedepth();
        @{$Physics{lakedepth_default}} = &Config_lakedepth_default();
        @{$Physics{lake_min_elev}}     = &Config_lake_min_elev();

    }


    #---------------------------------------------------------------------------------------------
    #---------------------------------------------------------------------------------------------
    #
    #   Option:  SF_OCEAN_PHYSICS - Activate ocean model options (NESTED)
    #
    #        NOTES:   Primarily used for tropical storm and hurricane applications.
    #
    #   Values:
    #
    #     0 - OFF (Default)
    #
    #     1 - Simple ocean mixed layer model (Previously OMLCALL = 1) 
    #
    #         1-D ocean mixed layer model following that of Pollard, Rhines and Thompson (1972). 
    #         Two other namelist options are available to specify the initial mixed layer depth 
    #         (although one may ingest real mixed layer depth data) (oml_hml0) and a temperature 
    #         lapse rate below the mixed layer (oml_gamma). 
    #
    #         Includes wind-driven ocean mixing
    #
    #         Works with all sf_surface_physics options.
    #          
    #         Uses:
    #           oml_hml0  - Initial ocean mixed layer depth
    #           oml_gamma - Lapse rate in deep water below mixed layer
    #
    #
    #     2 - Use 3D Ocean Model - 3D Price-Weller-Pinkel (PWP) ocean model based on Price et al. (1994). 
    #         This model predicts horizontal advection, pressure gradient force, as well as mixed layer
    #         processes. Only simple initialization via namelist variables ocean_z, ocean_t, and ocean_s is available
    #
    #         Only works with sf_surface_physics = 1 (5-Layer slab soil temperature scheme)
    #
    #         Uses:
    #            ocean_levels - Number of vertical levels in 3D PWP
    #            ocean_z      - Depth of levels
    #            ocean_t      - Temperature of levels
    #            ocean_s      - Salinity of levels
    #
    #   Notes:    Primarily used for tropical storm and hurricane applications
    #
    #   Default:  SF_OCEAN_PHYSICS = 0 (OFF)
    #---------------------------------------------------------------------------------------------
    #
    @{$Physics{sf_ocean_physics}} = @{$Config{uconf}{SF_OCEAN_PHYSICS}};

    if (sum @{$Physics{sf_ocean_physics}}) {  #  Configure if SF_OCEAN_PHYSICS is ON

        @{$Physics{oml_hml0}}     = &Config_oml_hml0(); 
        @{$Physics{oml_gamma}}    = &Config_oml_gamma();

    }

    
    #---------------------------------------------------------------------------------------------
    #---------------------------------------------------------------------------------------------
    #  Various SST related configurations
    #---------------------------------------------------------------------------------------------
    #
    @{$Physics{sst_skin}}         = &Config_sst_skin();
    @{$Physics{sst_update}}       = &Config_sst_update();


return;
}  #  Physics_SeaLakes.conf



#
# ==================================================================================
# ==================================================================================
#      SO BEGINS THE INDIVIDUAL PARAMETER CONFIGURATION SUBROUTINES
# ==================================================================================
# ==================================================================================
#


sub Config_sst_update {
# ==================================================================================
#   Option:  SST_UPDATE - Time-varying sea-surface temperature
#
#   Values:
#
#     0 - Time-varying sea-surface temperature is OFF
#     1 - Time-varying sea-surface temperature is ON
#
#   Notes:   The WRF model physics does not predict sea-surface temperature,
#            vegetation fraction, albedo and sea ice. For long simulations,
#            the model provides an alternative to read-in the time-varying
#            data and update these fields. In order to use this option,
#            one must have access to time-varying SST and sea ice fields
#            and then process the data as part of your initialization and
#            boundary condition datasets.
#
#   Default: SST_UPDATE = 0 (OFF)
# ==================================================================================
#
    my @sst_update = @{$Config{uconf}{SST_UPDATE}};


return @sst_update;
}



sub Config_sst_skin {
# ==================================================================================
#   Option:  SST_SKIN - calculate skin SST based on Zeng and Beljaars (2005)
#
#   Values:
#
#     0 - Calculation of SST skin temperatures is OFF
#     1 - Calculation of SST skin temperatures is ON
#
#   Notes:   The SST_SKIN parameter to used to allow the water points in the
#            simulation to respond to a simple radiative (diurnal) forcing
#            based on Zeng and Beljaars (2005). The documentation states that
#            it is useful for multi-year runs but it's a DIURNAL cycle, so
#            why not use it for any simulation?
#
#   Default: SST_SKIN = 0 (OFF)
# ==================================================================================
#
    my @sst_skin = @{$Config{uconf}{SST_SKIN}};


return @sst_skin;
}


sub Config_oml_gamma {
# ==================================================================================
#   Option:  OML_GAMMA - Lapse rate (K m-1) in deep water (below the mixed layer)
#
#            Only used when SF_OCEAN_PHYSICS = 1
#
#   Default: OML_GAMMA = 0.14 (K m-1)
# ==================================================================================
#
    my @oml_gamma = map {$Physics{sf_ocean_physics}[$_] ? $Config{uconf}{OML_GAMMA}[$_] : 0} 0..$Config{maxindex};


return @oml_gamma;
}


sub Config_oml_hml0 {
# ==================================================================================
#   Option:  OML_HML0 - Initial ocean mixed layer depth value (m)
#
#   Notes:   The value of OML_HML0 defines the initial depth of the simple ocean mixed layer
#            model in meters.
#
#            Only used when SF_OCEAN_PHYSICS = 1
#
#   Default: OML_HML0 = 50. (meters)
# ==================================================================================
#
    my @oml_hml0 = map {$Physics{sf_ocean_physics}[$_] ? $Config{uconf}{OML_HML0}[$_] : 0} 0..$Config{maxindex};


return @oml_hml0;
}


sub Config_use_lakedepth {
# ==================================================================================
#   Option:  USE_LAKEDEPTH - Option to use lake depth data
#
#   Notes:   If one didn't process the lake depth data, but this switch is set to 1, the
#            program will stop and you will be disappointed.
#
#   Values:
#
#     0 - Do not use lake depth data
#     1 - Use lake depth data
#
#   Default:  USE_LAKEDEPTH = 1 (Use it)
# ==================================================================================
#
    my @use_lakedepth = map {$Physics{sf_lake_physics}[$_] ? $Config{uconf}{USE_LAKEDEPTH}[$_] : 0} 0..$Config{maxindex};


return @use_lakedepth;
}


sub Config_lakedepth_default {
# ==================================================================================
#   Option:  LAKEDEPTH_DEFAULT - Default lake depth in meters
#
#   Notes:   If there is no lake_depth information in the input data, then lake
#            depth is assumed to be 50m. Data is available through GEOGRID when
#            localizing a domain.
#
#   Default: LAKEDEPTH_DEFAULT = 50.
# ==================================================================================
#
    my @lakedepth_default = map {$Physics{sf_lake_physics}[$_] ? $Config{uconf}{LAKEDEPTH_DEFAULT}[$_] : 0} 0..$Config{maxindex};


return @lakedepth_default;
}


sub Config_lake_min_elev {
# ==================================================================================
#   Option:  LAKE_MIN_ELEV - Minimum elevation of lakes in meters
#
#   Notes:   May be used to determine whether a water point is a lake in the absence of lake
#            category. If the landuse type includes 'lake' (i.e. Modis_lake and USGS_LAKE),
#            this variable is of no effects.
#
#   Default: LAKE_MIN_ELEV = 5.
# ==================================================================================
#
    my @lake_min_elev = map {$Physics{sf_lake_physics}[$_] ? $Config{uconf}{LAKE_MIN_ELEV}[$_] : 0} 0..$Config{maxindex};


return @lake_min_elev;
}


sub Physics_Lightning {
# ==============================================================================================
# WRF &PHYSICS NAMELIST CONFIGURATION FOR LIGHTNING PARAMETERIZATION AND STUFF
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This subroutine manages the configuration of all things johnny lightning in the
#   &physics section of the WRF namelist file. 
#
#   Note that some (most) of the information used to produce the guidance presented
#   in this file was likely taken from the WRF user's guide and presentation materials,
#   and those authors should receive all the gratitude as well as any proceeds that 
#   may be derived from reading this information.
#
#   FROM THE ARW USER GUIDE AND OTHER LESS REPUTABLE SOURCES:
#
#     About the Lightning Parameterization
#
#       The WRF Lightning Parameterization Scheme is intended for the parameterization
#       of lightning flash rates, which was previously only avaiable to WRF CHEM users.
#       There are a lot of caveats in the assignment of default values so the UEMS
#       developer takes no credit in the success or failure of your simulation results.
#
#       This scheme is controlled via the following physics namelist parameters (maxdomains):
#
#       *  lightning_option        (max_dom)   Lightning parameterization option 
#       *  lightning_dt            (max_dom)   Time interval (seconds) for calling lightning parameterization.
#       *  lightning_start_seconds (max_dom)   Start time for calling lightning parameterization. 
#       *  flashrate_factor        (max_dom)   Factor to adjust the predicted number of flashes. 
#       *  cellcount_method        (max_dom)   Method for counting storm cells. 
#       *  cldtop_adjustment       (max_dom)   Adjustment from LNB in km. 
#       *  iccg_method             (max_dom)   IC:CG partitioning method 
#       *  iccg_prescribed_num                 Numerator of user-specified prescribed IC:CG
#       *  iccg_prescribed_den                 Denominator of user-specified prescribed IC:CG
# ==============================================================================================
# ==============================================================================================
#

    #-----------------------------------------------------------------------------
    #  PHYSICS Variable:  LIGHTNING_OPTION - controls which variation of the PR scheme
    #
    #    Note: Currently, lightning_option = 1 & 2 are intended for simulations 
    #          run without a CU scheme (MP only), while lightning_option = 11 is
    #          for use with LIGHTNING_OPTION = 5 & 93 (Grell).  The ARW guide states that 
    #          options 1 & 2 can only be used with mp_physics = 2,4,6,11+$Rconf{arf},8,10,14,16 
    #          since these schemes include a simulated reflectivity field; however,
    #          the UEMS includes a reflectivity calculation for the remaining MP 
    #          schemes so it is possible to use lightning_options 1 & 2 regardless 
    #          of the MP scheme selected.
    #              
    #    0 - Lightning Parameteization OFF
    #    1 - PR92 based on maximum w, redistributes flashes within dBZ > 20  (MP only runs)
    #    2 - PR92 based on 20 dBZ top, redistributes flashes within dBZ > 20 (MP only runs)
    #    3 - Predicting the potential for lightning activity (based on Yair et. al. 2010)
    #   11 - PR92 based on level of neutral buoyancy from convective parameterization 
    #        (Use CU 3, 5 or 93) intended for use at 10 < dx < 50 km;
    #-----------------------------------------------------------------------------
    #
    @{$Physics{lightning_option}} = (0);

    for ($Config{uconf}{LIGHTNING_OPTION}[0]) {

        @{$Physics{lightning_option}} = &Physics_LT01_PR92W()    if $_ ==  1; #  PR92 based on maximum W,  redistributes flashes within dBZ > 20 (MP only runs)
        @{$Physics{lightning_option}} = &Physics_LT02_PR92Z()    if $_ ==  2; #  PR92 based on 20 dBZ top, redistributes flashes within dBZ > 20 (MP only runs)
        @{$Physics{lightning_option}} = &Physics_LT03_LPI()      if $_ ==  3; #  Lightning Potential Index (LPI)
        @{$Physics{lightning_option}} = &Physics_LT11_PR92B()    if $_ == 11; #  PR92 based on level of neutral buoyancy from convective parameterization

    }


return;
}  #  Physics_Lightning


sub Physics_LT01_PR92W {
# ==================================================================================
#  PR92 based on maximum W,  redistributes flashes within dBZ > 20 (MP only runs)
#  Run without a CU scheme (MP only)
# ==================================================================================
#
    my @lightning_option = map {$Physics{cu_physics}[$_] ? 0 : 1} 0..$Config{maxindex};

    unless ($lightning_option[-1]) {
        my $mesg = "Your choice of Lightning Scheme (1) should only be used in the absence of parameterized convection. ".
                   "Since it appears that cumulus parameterization is turned ON ($Physics{cu_physics}[0]) for all of your ".
                   "simulation domains the lightning scheme will be turned OFF.";
        &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,'Lightning Scheme Not Compatible with CU Physics:',$mesg);
        return (0);
    }
    
    @{$Physics{flashrate_factor}}        = &Config_flashrate_factor();

    @{$Physics{cellcount_method}}        = &Config_cellcount_method();

    @{$Physics{lightning_dt}}            = &Config_lightning_dt();
    @{$Physics{lightning_start_seconds}} = &Config_lightning_start_seconds();

    @{$Physics{iccg_method}}             = &Config_iccg_method();
    @{$Physics{iccg_prescribed_num}}     = &Config_iccg_prescribed_num() if $Physics{iccg_method} == 1;
    @{$Physics{iccg_prescribed_den}}     = &Config_iccg_prescribed_den() if $Physics{iccg_method} == 1;
    

return @lightning_option;
}


sub Physics_LT02_PR92Z {
# ==================================================================================
#  PR92 based on 20 dBZ top, redistributes flashes within dBZ > 20 (MP only runs)
#
# ==================================================================================
#
    my @lightning_option = map {$Physics{cu_physics}[$_] ? 0 : 2} 0..$Config{maxindex};

    unless ($lightning_option[-1]) {
        my $mesg = "Your choice of Lightning Scheme (2) should only be used in the absence of parameterized convection. ".
                   "Since it appears that cumulus parameterization is turned ON ($Physics{cu_physics}[0]) for all of your ".
                   "simulation domains the lightning scheme will be turned OFF.";
        &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,'Lightning Scheme Not Compatible with CU Physics:',$mesg);
        return (0);
    }

    @{$Physics{flashrate_factor}}        = &Config_flashrate_factor();

    @{$Physics{cellcount_method}}        = &Config_cellcount_method();

    @{$Physics{lightning_dt}}            = &Config_lightning_dt();
    @{$Physics{lightning_start_seconds}} = &Config_lightning_start_seconds();

    @{$Physics{iccg_method}}             = &Config_iccg_method();
    @{$Physics{iccg_prescribed_num}}     = &Config_iccg_prescribed_num() if $Physics{iccg_method} == 1;
    @{$Physics{iccg_prescribed_den}}     = &Config_iccg_prescribed_den() if $Physics{iccg_method} == 1;


return @lightning_option;
}


sub Physics_LT03_LPI {
# ==================================================================================
#  Lightning Potential Index (LPI) - Requires MP scheme with Graupel
#  NOTE - Removed no CU scheme restriction
# ==================================================================================
#
  # my @lightning_option = map {$Physics{cu_physics}[$_] ? 0 : 3} 0..$Config{maxindex};

  # unless ($lightning_option[-1]) {
  #     my $mesg = "Your choice of Lightning Scheme (3) should only be used in the absence of parameterized convection. ".
  #                "Since it appears that cumulus parameterization is turned ON ($Physics{cu_physics}[0]) for all of your ".
  #                "simulation domains the lightning scheme will be turned OFF.";
  #     &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,'Lightning Scheme Not Compatible with CU Physics:',$mesg);
  #     return (0);
  # }

    my @lightning_option = (3) x $Config{maxdoms};

    #  Test whether MP schemes supports graupel - Schemes 0,1,3,4,5,13,14,50,51 do not
    #
    if (grep {/$Physics{mp_physics}[0]$/} (0,1,3,4,5,13,14,50,51)) {
        my $mesg = "Your choice of MP scheme (MP_PHYSICS = $Physics{mp_physics}[0]) is incompatible with the lightning ".
                   "potential index parameterization since it does not support graupel. The lightning scheme will be ". 
                   "turned OFF whether you like it or not.";
        &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,'MP Physics Not Compatible with Lightning Scheme:',$mesg);
        return (0);
    }


return @lightning_option;
}


sub Physics_LT11_PR92B {
# ==================================================================================
#  PR92 based on level of neutral buoyancy from convective parameterization
#
# ==================================================================================
#
    my @lightning_option = map {$Physics{cu_physics}[$_] ? 11 : 0} 0..$Config{maxindex};

    unless (grep {/^$Physics{cu_physics}[0]$/} (3,5)) {
        my $mesg = "Your choice of Lightning Scheme (11) is only available with the Grell cumulus parameterization schemes (CU_PHYSICS = 3,5). ".
                   "Since it appears that you are using CU_PHYSICS = $Physics{cu_physics}[0], the lightning scheme will be turned OFF until ".
                   "you decide to get with the program.";
        &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,'Lightning Scheme Not Compatible with CU Physics:',$mesg);
        return (0);
    }

    @{$Physics{flashrate_factor}}        = &Config_flashrate_factor();
    @{$Physics{cellcount_method}}        = &Config_cellcount_method();
    @{$Physics{cldtop_adjustment}}       = &Config_cldtop_adjustment();

    @{$Physics{lightning_dt}}            = &Config_lightning_dt();
    @{$Physics{lightning_start_seconds}} = &Config_lightning_start_seconds();

    @{$Physics{iccg_method}}             = &Config_iccg_method();
    @{$Physics{iccg_prescribed_num}}     = &Config_iccg_prescribed_num() if $Physics{iccg_method} == 1;
    @{$Physics{iccg_prescribed_den}}     = &Config_iccg_prescribed_den() if $Physics{iccg_method} == 1;


return @lightning_option;
}


#
# ==================================================================================
# ==================================================================================
#      SO BEGINS THE INDIVIDUAL PARAMETER CONFIGURATION SUBROUTINES
# ==================================================================================
# ==================================================================================
#


sub Config_cellcount_method {
# ==================================================================================
#  PHYSICS Variable:  cellcount_method - Method for counting storm cells. Used by Non-CU options (lightning_option 1 & 2)
#
#    0 - Model determines method used
#    1 - Tile-wide, appropriate for large domains
#    2 - Domain-wide, appropriate for sing-storm domains
#
#    Why use anything besides 0?
# ==================================================================================
#
    my @cellcount_method = map {$Physics{cu_physics}[$_] ? 0 : $Config{uconf}{CELLCOUNT_METHOD}[$_]} 0..$Config{maxindex};


return @cellcount_method;
}


sub Config_lightning_start_seconds {
# ==================================================================================
#   Option:  LIGHTNING_START_SECONDS = Seconds (MAX DOMAINS)
#
#     The lightning_start_seconds parameter specifies the number of seconds following the
#     start of a simulation to turn ON the lightning scheme. The default and recommended
#     value is 600 seconds (10 minutes), which allows for the simulation to spin up and
#     hopefully suppress "flash-rate fireworks".
#
#   Default: Stick with 600 (seconds).
# ==================================================================================
#
    my @lightning_start_seconds = map {$Physics{cu_physics}[$_] ? 0 : $Config{uconf}{LIGHTNING_START_SECONDS}[$_]} 0..$Config{maxindex};


return @lightning_start_seconds;
}


sub Config_flashrate_factor {
# ==================================================================================
#   Option:  FLASHRATE_FACTOR - Factor to adjust the predicted number of flashes (MAX DOMAINS)
#
#     The existence of the flashrate_factor parameter is one of the reasons why the
#     lightning scheme is not best suited for real-time applications. The WRF
#     documentation recommends a value of 1 for lightning_option = 11, which is used
#     with CU schemes, but then "suggests" manual tuning of all other options indepen-
#     dently for each nest. No other guidance is provided, which is understandable
#     after you have read J. Wong et al.
#
#     A previous version of the WRF Chem user guide (V3.3) suggests scaling the
#     flashrate_factor value for each nested domain at the parent:child DX ratio,
#     so if flashrate_factor = 1 for the parent then a value of 0.33 would be used
#     for a child domain assuming a 1:3 DX ratio. However, this recommendation is
#     not included in any current WRF guidance so you are on your own here.
#
#   Default: FLASHRATE_FACTOR = 1 for all domains
# ==================================================================================
#
    my @flashrate_factor = map {$Physics{cu_physics}[$_] ? 0 : $Config{uconf}{FLASHRATE_FACTOR}[$_]} 0..$Config{maxindex};


return @flashrate_factor;
}


sub Config_cldtop_adjustment {
# ==================================================================================
#   Option:  CLDTOP_ADJUSTMENT - Adjustment from Level of Neutral Bouyancy (LNB) in km (MAX DOMAINS)
#
#     The cldtop_adjustment parameter is only used with LIGHTNING_OPTION = 11,
#     which requires a CU scheme, so if you are using LIGHTNING_OPTION = 1 or 2
#     then you need not worry your pretty little head over what value to use.
#
#     If you are using LIGHTNING_OPTION = 11 then this value becomes problematic,
#     the reasons for which are detailed in Wong et. al., but you already know
#     this, don't you.  The default value is 2 (km). Use it unless you know
#     what you are doing.
#
#   Default:  CLDTOP_ADJUSTMENT = 2
# ==================================================================================
#
    my @cldtop_adjustment = map {$Physics{cu_physics}[$_] ? 0 : $Config{uconf}{CLDTOP_ADJUSTMENT}[$_]} 0..$Config{maxindex};


return @cldtop_adjustment;
}


sub Config_iccg_method {
# ==================================================================================
#   Option:  ICCG_METHOD - IC:CG partitioning method (IC: intra-cloud; CG: cloud-to-ground)
#
#   Values: Select wisely
#
#     0  -  Default method depending on lightning option,
#           Currently all options use iccg_method = 2 by default
#
#     1  -  Constant everywhere, set with namelist options
#           iccg_prescribed_(num|den)# below, default is 0./1. (all CG)
#
#     2  -  Coarsely prescribed 1995-1999 NLDN/OTD climatology based on
#           Boccippio et al. (2001) This is what you get for ICCG_METHOD = 0
#
#     3  -  Parameterization by Price and Rind (1993) based on cold-cloud depth
#
#     4  -  Gridded input via arrays iccg_in_(num|den) from wrfinput for
#           monthly mapped ratios. Points with 0/0 values use ratio
#           defined by iccg_prescribed_(num|den) below. (Not for the UEMS)
#
#   According to J. Wong et al (see ems/docs/wrf), using iccg_method = 2 provides a more 
#   reasonable result.  So the default it is.
#
#   Default: ICCG_METHOD = 0
# ==================================================================================
#
    my @iccg_method = map {$Physics{cu_physics}[$_] ? 0 : $Config{uconf}{ICCG_METHOD}[$_]} 0..$Config{maxindex};


return @iccg_method;
}


sub Config_iccg_prescribed_num {
# ==================================================================================
#   Option:  ICCG_PRESCRIBED_NUM & ICCG_PRESCRIBED_DEN - Numerator & Denominator of IC:CG ratio
#
#     Used only when ICCG_METHOD = 2 or 4, you get to define the IC:CG ratio used.
#     Note that you should not set ICCG_PRESCRIBED_DEN = 0 because bad things can
#     happen to good modelers.
#
#   Defaults: ICCG_PRESCRIBED_NUM = 0.
# ==================================================================================
#
    my @iccg_prescribed_num = map {$Physics{cu_physics}[$_] ? 0 : $Config{uconf}{ICCG_PRESCRIBED_NUM}[0]} 0..$Config{maxindex};


return @iccg_prescribed_num;
}


sub Config_iccg_prescribed_den {
# ==================================================================================
#   Option:  ICCG_PRESCRIBED_NUM & ICCG_PRESCRIBED_DEN - Numerator & Denominator of IC:CG ratio
#
#     Used only when ICCG_METHOD = 2 or 4, you get to define the IC:CG ratio used.
#     Note that you should not set ICCG_PRESCRIBED_DEN = 0 because bad things can
#     happen to good modelers.
#
#   Defaults: ICCG_PRESCRIBED_DEN = 1.
# ==================================================================================
#
    my @iccg_prescribed_den = @{$Config{uconf}{ICCG_PRESCRIBED_DEN}};


return @iccg_prescribed_den;
}

sub Config_lightning_dt {
# ==================================================================================
#  Option:  LIGHTNING_DT - Time interval (seconds) for calling lightning parameterization
#
#  Values:  In the UEMS, lightning_dt will use the default value of every timestep (0). 
#           This is simply because setting a call frequency in seconds becomes 
#           problematic when the adaptive timestep is being used and I see no reason 
#           to address every possible condition when every timestep is good enough.
#
#  Default: LIGHTNING_DT = 0 (Every time step)
# ==================================================================================
#
    my @lightning_dt = (0);

return @lightning_dt;
}



sub Physics_ShallowCumulus {
# ==============================================================================================
# WRF &PHYSICS NAMELIST CONFIGURATION FOR CUMULUS SCHEMES AND STUFF
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This subroutine manages the configuration of all things shallow cumulus scheme in the
#   &physics section of the WRF namelist file. 
#
#   Note that some (most) of the information used to produce the guidance presented
#   in this file was likely taken from the WRF user's guide and presentation materials,
#   and those authors should receive all the gratitude as well as any proceeds that 
#   may be derived from reading this information.
#
# SHALLOW CONVECTION SCHEMES
#
#   The SHCU_PHYSICS parameter specifies the scheme to use for including the effects of
#   non-precipitating (convective) mixing withing the PBL and above. The effects of this
#   shallow mixing are to dry the PBL while moistening and cooling the levels above,
#   which may be accomplished though through an enhanced mixing or mass-flux approach.
#
#   Inclusion of shallow cumulus parameterization may be useful at grid sizes greater
#   than 1km (DX > 1km) since shallow cumulus clouds are typically not resolved at
#   this scale.
#
#   In many instances, the addition of a shallow cumulus scheme may not be necessary as
#   the effects may already be included with the chosen CU_PHYSICS option. This would
#   include CU_PHYSICS options 1 (KF), 2 (BMJ), TiedTKE (6) and 4, 14, 84 (SAS).
#
#    COMMENTS:  As best I can tell from the lack of guidance:
#
#      *  The stand-alone shallow CU scheme should be turned OFF when using a CU scheme
#         that includes the effects of shallow convection.
#  
#         CU schemes with shallow - KF (1, 10, 11), BMJ (2) SAS (4, 14, 84), Grell (ishallow) Tiedtke (6)
#
#         Only CU schemes without shallow convection - Zhang-McFarlane (7) and Grell-Devenyi (93)
#
#      *  shcu_physics options are currently 2 (UW) and 3 (GRIMS/YSU)
#
#      *  shcu_physics = 2 is to be used with Zhang-McFarlane scheme and 
#
#           For shcu_physics = 2 - TKE PBL scheme (2 & 9)  - Use bl_pbl_physics = 9
#
#      *  While there are multiple PBL scheme that include a shallow CU component it is not
#         known whether these PBL schemes should be used with shcu_physics or one of the
#         cu_physics schemes. The rule shall be to turn OFF the independent shallow CU
#         scheme (SHCU_PHYSICS = 0) in favor of the internal scheme.
#
#           bl_pbl_physics = 4   - Quasi-Normal Scale Elimination PBL (TKE_PBL)
#           bl_pbl_physics = 5,6 - MYNN (see below)
#           bl_pbl_physics = 10  - Total Energy - Mass Flux (TEMF)
#           bl_pbl_physics = 12  - GBM PBL
#
#      *  According to module_check_a_mundo.F (V3.7), the GRIMS scheme (shcu_physics = 3) cam
#         only be used with YSU (1) & MYNN (5,6) PBL; however, since the MYNN schemes have an
#         integrated mass flux option (BL_MYNN_EDMF=1), the GRIMS scheme will not be used with 
#         MYNN (5 or 6).
#                 
#      *  Finally, this scheme will need to be rewritten as the rules change with time.
#         Additionally, there are no guarantees everything is correct as the rules have been
#         cobbled together from multiple sources.
#
# ==============================================================================================
# ==============================================================================================
#

    #-----------------------------------------------------------------------------
    #  PHYSICS Variable: SHCU_PHYSICS - Shallow Cumulus scheme
    #
    #    Note: Some care was taken to ensure that this option is configured properly; however "some"
    #          is probably not enough.
    #
    #    Shallow CU options include:
    #
    #    0 - No separate Shallow CU scheme used 
    #    1 - Use Grell shallow scheme with CU_PHYSICS = 3 or 5 (Sets SHCU_PHYSICS = 0 and ishallow = 1)
    #    2 - Park and Bretherton shallow cumulus from CAM5 - Only works with UW (9), MYJ (2), or MYNN (5 & 6) PBL
    #    3 - GRIMS shallow cumulus from YSU group - Only with YSU (1) PBL
    #
    #    * - MYNN (5 & 6) PBL schemes have an integrated shallow cumulus option (BL_MYNN_EDMF=1)
    #    * - QNSE (4) PBL scheme has an integrated shallow cumulus option (MFSHCONV=1)
    #    * - TEMF (10) PBL scheme has an integrated shallow cumulus that is always ON
    #    * - UW (9) PBL scheme will only use SHCU_PHYSICS = 2
    #    * - GRELL (3 & 5) CU schemes will only use ISHALLOW = 1 unless MYNN, QNSE, or UW PBL (ISHALLOW=0)
    #-----------------------------------------------------------------------------
    #
    
    #  Make sure that any physics scheme used by a nested domain is also used by the parent. IT'S THE LAW!
    #
    @{$Physics{shcu_physics}} = map {$Config{uconf}{SHCU_PHYSICS}[$_] ? $Config{uconf}{SHCU_PHYSICS}[$Config{parentidx}[$_]] : 0} 0..$Config{maxindex};

    #  Note that the Config_AutoConfiguration routine is called regardless of the non-zero shcu_physics value.
    #  This is because the user may have assigned an inappropriate value for the physics configuration, in which
    #  case the auto-configuration figure out what should have been specified.
    #
    @{$Physics{shcu_physics}} = &Config_AutoConfiguration() if $Physics{shcu_physics}[0];    


return;
}  #  Physics_ShallowCumulus


sub Config_AutoConfiguration {
# ==================================================================================
#  These "rules" are derived from attempting to decipher the sometime vague guidance 
#  provided by the WRF User's guide, the README files, on-line presentations, and
#  the WRF source code. That is NOT to say they are correct and may be subject to
#  change should the developer uncover more instructive guidance.  
#
#  For Auto Configuration the rules are:
#
#   #1  Turn shcu_physics OFF (0) if any physics scheme (PBL or CU) supports the effects of shallow cumulus clouds
#
#       * MYNN (5 & 6) PBL schemes have an integrated shallow cumulus option (BL_MYNN_EDMF=1)
#       * QNSE (4) PBL scheme has an integrated shallow cumulus option (MFSHCONV=1)
#       * TEMF (10) PBL scheme has an integrated shallow cumulus that is always ON
#       * UW (9) PBL scheme will only use SHCU_PHYSICS = 2
#       * GRELL (3 & 5) CU schemes will only use ISHALLOW = 1 unless MYNN, QNSE, or UW PBL (ISHALLOW=0)
#       * CU_PHYSICS that support shallow cumulus schemes (1,2,4,6,10,11,14,16,84), (7 does not)
# 
#   #2  Set shcu_physics to 2 if CU_PHYSICS = 0 or 7 and BL_PBL_PHYSICS = 2, 8, 9, or 12  (TKE PBL Schemes)
#   #3  Set shcu_physics to 3 if CU_PHYSICS = 0 and BL_PBL_PHYSICS = 1 (YSU)
# ==================================================================================
#

    #  If we are in this routine it is known that the user wants to include the effects of
    #  shallow convection. Due to the very myriad of possible options involved, an executive
    #  decision was made to restrict the final configuration to (hopefully) a single result
    #  determined from the other physics options selected. The user may see multiple non-zero
    #  options for SHCU_PHYSICS (1, 2, 3, -1) but the end result should be the same regardless
    #  of user input.
    #
    my @shcu_physics = (99);  #  Turn shcu_physics to "AUTO" and then determine the best approach 
                              #  for including the effects of shallow convection. The final two
                              #  tests should be for UW (2) and GRIMS (3) .

    #  Test for PBL schemes that support shallow cumulus effects
    #
    if (grep {/^$Physics{bl_pbl_physics}[0]$/} (5,6)) { #  MYNN (5 & 6) PBL
        @{$Physics{bl_mynn_edmf}}     = (1)  unless $Physics{bl_mynn_edmf}[0];
        @{$Physics{bl_mynn_edmf_mom}} = (1)  unless $Physics{bl_mynn_edmf_mom}[0];
        @shcu_physics                 = (0);
    }

    if (grep {/^$Physics{bl_pbl_physics}[0]$/} (4)) { #  QNSE PBL
        @{$Physics{mfshconv}}     = (1)  unless $Physics{mfshconv}[0];
        @shcu_physics             = (0);
    }

    if (grep {/^$Physics{bl_pbl_physics}[0]$/} (10)) { #  TEMF PBL
        @shcu_physics             = (0);
    }

   
    #  Test for CU schemes that support shallow cumulus effects
    #
    @shcu_physics = (0) if grep {/^$Physics{cu_physics}[0]$/} (1,2,4,6,10,11,14,16,84);  #  CU Schemes that support shallow CU effects (except 3&5)

    if ($shcu_physics[0] and grep {/^$Physics{cu_physics}[0]$/} (3,5)) { # Grell CU - Set ishallow
        @{$Physics{ishallow}}     = (1);
        @shcu_physics             = (0);
    }

    if (grep {/^$Physics{cu_physics}[0]$/} (10)) { #  KF CuP scheme - Note this may cause double counting
        @{$Physics{shallowcu_forced_ra}} = map {$Physics{cu_physics}[$_] ? 'T' : 'F'} 0..$Config{maxindex};
        @shcu_physics             = (0);
    }

    if ($shcu_physics[0]) {  #  Check whether SHCU_PHYSICS = 2, 3 is an option

        @shcu_physics = (0);

        @shcu_physics = (3)  if  grep {/^$Physics{bl_pbl_physics}[0]$/} (1);  #  Set GRIMS for YSU PBL
        @shcu_physics = (2)  if  grep {/^$Physics{bl_pbl_physics}[0]$/} (2,8,9,12) 
                             and grep {/^$Physics{cu_physics}[0]$/}     (0,7,93);
    
    }


return @shcu_physics;
}


sub Physics_FinalConfiguration {
# ==============================================================================================
# WRF FINAL &PHYSICS NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Subroutine that cleans up any loose ends within the &physics section of the WRF
#  namelist. Occasionally, variables require tweaks after everything else has been 
#  due to dependencies that had not been resolved at the time of original configuration.
#
# ==============================================================================================
# ==============================================================================================
#
    return () if &ConfigFinal_Cumulus();
    return () if &ConfigFinal_Microphysics();
    return () if &ConfigFinal_Radiation(); 
    return () if &ConfigFinal_SurfaceLayer();
    return () if &ConfigFinal_ExcludedDomains();

return;
} #  Physics_FinalConfiguration


sub ConfigFinal_Cumulus {
# ==================================================================================
#  This routine handles any final configuration checks for the cumulus schemes 
#  and associated variables that could not be done previously due to unresolved 
#  dependencies.
# ==================================================================================
#
    my $mesg = qw{};

    #----------------------------------------------------------------------------------
    #   The Zhang-McFarlane (7) can only be used with MYJ or CAM UW PBL schemes
    #----------------------------------------------------------------------------------
    #
    if ($Physics{cu_physics}[0] == 7 ) {
        unless (grep {/^$Physics{bl_pbl_physics}[0]$/} (2,9)) {
            $mesg = "The Zhang-McFarlane cumulus scheme may only be used with the MYJ (2) or CAM UW (9) ".
                    "PBL schemes. You will have to decide which scheme to use and edit the configuration ".
                    "file yourself as I have better things to do right now.";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Configuration Confusion Again:',$mesg);
            return 1;
        }
    }


    #----------------------------------------------------------------------------------
    #  If no_mp_heating ON (1) then cu_physics = 0
    #----------------------------------------------------------------------------------
    #
    if ($Physics{cu_physics}[0] and $Physics{no_mp_heating}[0]) {
       &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,"The NO_MP_HEATING option is designed to work with cumulus parameterization off, ".
                                       "so I'll be turning OFF your CU scheme ($Physics{cu_physics}[0] -> 0)."); 
       @{$Physics{cu_physics}} = (0) x $Config{maxdoms};
    }


    #----------------------------------------------------------------------------------
    #  The Multi-scale Kain-Fritsch scheme (11) only works with YSU PBL
    #----------------------------------------------------------------------------------
    #
    if ($Physics{cu_physics}[0] == 11 and $Physics{bl_pbl_physics}[0] != 1) {
        $mesg = "The scale-aware KF cumulus scheme (CU_PHYSICS = 11) must be used with the YSU PBL scheme ".
                "(BL_PBL_PHYSICS = 1). Your choice, BL_PBL_PHYSICS = $Physics{bl_pbl_physics}[0], does not".
                "cut the mustard.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,"I don't make the rules, just enforce them!",$mesg);
        return 1;
    }




return;
}


sub ConfigFinal_Microphysics {
# ==================================================================================
#  This routine handles any final configuration checks for the microphysics schemes 
#  and associated variables that could not be done previously due to unresolved 
#  dependencies.
# ==================================================================================
#
    #  Turn ON scalar_pblmix for mp_physics = 28 & PBL ON
    #
    if ($Physics{mp_physics}[0] == 28) {
        for (0..$Config{maxindex}) {$Physics{scalar_pblmix}[$_] = $Physics{bl_pbl_physics}[$_] ? 1 : 0;}
    }

   
return;
}


sub ConfigFinal_Radiation {
# ==================================================================================
#  This routine handles any final configuration checks for the radiation schemes 
#  and associated variables that could not be done previously due to unresolved 
#  dependencies.
# ==================================================================================
#
    my $mesg = qw{};

    #----------------------------------------------------------------------------------
    #  RRTMG (4) must be used with mp_physics = 50 or 51
    #----------------------------------------------------------------------------------
    #
    if (grep {/^$Physics{mp_physics}[0]$/} (50,51)) {
        unless ($Physics{ra_sw_physics}[0] == 4 and $Physics{ra_sw_physics}[0] == 4) {
            $mesg = "When using either P3 or P3+ microphysics (50, 51) microphysics scheme, you must also use the RRTMG ".
                    "radiation scheme (RA_LW|SW_PHYSICS = 4). This law of the land was stated in the microphysics ".
                    "configuration file, just in case you missed it. Consequently, you will be using RRTMG (4) for both ".
                    "long and short-wave radiation instead of RA_LW|SW_PHYSICS = $Physics{ra_lw_physics}[0], $Physics{ra_sw_physics}[0].";
            &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,"I don't make the rules, just enforce them!", $mesg);
            @{$Physics{ra_lw_physics}} = (4);
            @{$Physics{ra_sw_physics}} = (4);

            #  Make sure ICLOUD is set to either 1 or 3
            #
            @{$Physics{icloud}}        = (1) unless grep {/^$Physics{icloud}[0]$/} (1,3);
        }
    }



    
    #----------------------------------------------------------------------------------
    #  If CU_PHYSICS = 11, ICLOUD will automatically be set to 1 regardless
    #  of RA_LW_PHYSICS and RA_SW_PHYSICS values. This check is here because 
    #  icloud is most closely related to radiation.
    #----------------------------------------------------------------------------------
    #
    @{$Physics{icloud}} = (1) if $Physics{cu_physics}[0] == 11;


    #----------------------------------------------------------------------------------
    #  Info:  Per module_check_a_mundo.F (V3.9), icloud = 3 cannot be used with the 
    #  kessler or WSM3 MP schemes.
    #----------------------------------------------------------------------------------
    #
    if (grep {/^$Physics{mp_physics}[0]$/} (1,3)) {
        @{$Physics{icloud}} = (1) if $Physics{icloud}[0] == 3;
    }


    #----------------------------------------------------------------------------------
    #  More ICLOUD checks and messaging
    #----------------------------------------------------------------------------------
    #
    unless ($Physics{icloud}[0]) {
        $mesg = "Your choice for ICLOUD (ICLOUD = 0) means that you do NOT want to include the effect ".
                "of clouds in calculating the shortwave radiation scheme, which could be detrimental to ".
                "your simulation. Unless you're into that sort of thing.";
         &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,"Where are you headed with this simulation?", $mesg);
    }



return;
}


sub ConfigFinal_SurfaceLayer {
# ==================================================================================
#  The primary purpose for this subroutine is to make sure the surface layer
#  configuration is properly set if the PBL scheme is turned OFF during a 
#  nested simulation, i.e, an LES.
# ==================================================================================
#
    #  Check whether the PBL Scheme is turned OFF for either the primary or a
    #  child domain, which indicates a LES configuration.
    #
    my $i = &Others::IntegerIndexMatchExact(0,@{$Physics{bl_pbl_physics}});

    if ($i > 0) { #  Nesting down to LES 

        my $def = ($Physics{bl_pbl_physics}[0] == 2) ? 2 : 1;  #  Set the default sf_sfclay_physics values

        unless (grep {/^$Physics{sf_sfclay_physics}[0]$/} (1,2)) {
            my $mesg = "For LES simulations with surface layer scheme ON it's best to use sf_sfclay_physics = 1 or 2. ".
                       "Because the UEMS only want the best for you, sf_sfclay_physics = $def will be used.";
            &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,"Only the Best, Because You're Worth It:", $mesg);
        }

        #  The surface layer must be turned ON across all domains
        #
        @{$Physics{sf_sfclay_physics}} = ($def) x $Config{maxdoms};
        @{$Physics{isfflx}}            = (1); # For sf_sfclay_physics = 1 only

    }
    

return;
}


sub ConfigFinal_ExcludedDomains {
# ==================================================================================
#  The purpose of this subroutine is to populate domains that must be included
#  as part of the parameter values but are not part of the sumulation. Because
#  they are not part of the simulation, these values are not configured with the
#  domains in the simulation. Consequently, it annoys the developer to see
#  inconsistent values within the configuration. To please the developer this
#  routine simply assigns the parent domain value to any child domain not
#  part of the simulation party.
# ==================================================================================
#
    my @rdoms = sort {$a <=> $b} keys %{$Rconf{dinfo}{domains}};
    my @ndoms = (1..$Config{maxdoms});
       @ndoms = &Others::ArrayMissing(\@ndoms,\@rdoms);

    return unless @ndoms;  #  Nothing to do here

    foreach my $parm (keys %Physics) {
        next unless $Config{parmkeys}{$parm}{maxdoms} > 1;
        next unless @{$Physics{$parm}} == $Config{maxdoms};
        foreach (@ndoms) {$Physics{$parm}[$_-1] = $Physics{$parm}[$Config{parentidx}[$_]-1];}
    }

return;
}


sub Physics_Debug {
# ==============================================================================================
# &PHYSICS NAMELIST DEBUG ROUTINE
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  When the --debug 4+ flag is passed, prints out the contents of the WRF &physics
#  namelist section.
#
# ==============================================================================================
# ==============================================================================================
#   
    my @defvars  = ();
    my @ndefvars = ();

    return unless $ENV{RUN_DBG} > 3;  #  Only for --debug 4+

    foreach ( (@{$ARWconf{nlorder}{physics}},@{$ARWconf{nlorder}{noah_mp}}) ) {
        defined $Physics{$_} ? push @defvars => $_ : push @ndefvars => $_;
    }

    return unless @defvars or @ndefvars;

    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,13+$Rconf{arf},144,1,1,'Leaving &ARWphysics');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-20s  = %s',$_,join ', ' => @{$Physics{$_}})) foreach @defvars;
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,' ');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-20s  = %s',$_,'Not Used')) foreach @ndefvars;
    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,2,'=' x 72);
        

return;
}


