#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ARWdynamics.pm
#
#  DESCRIPTION:  ARWdynamics contains the subroutines used for configuration of
#                the &dynamics section of the WRF ARW core namelist. 
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package ARWdynamics;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Rconf %Config %ARWconf %Dynamics);

use Others;


sub Configure {
# ==============================================================================================
# WRF &dynamics NAMELIST CONFIGURATION DRIVER
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Each subroutine controls the configuration for the somewhat crudely organized namelist
#  variables. Should there be a serious problem an empty hash is returned (not really).
#  Not all namelist variables are configured as some do not require anything beyond the
#  default settings. The %Dynamics hash is only used within this module to reduce the
#  number of characters being cut-n-pasted.
#
# ==============================================================================================
# ==============================================================================================
#
    %Config = %ARWconfig::Config;
    %Rconf  = %ARWconfig::Rconf;

    my $href = shift; %ARWconf = %{$href};

    return () if &Dynamics_TimeIntegration();
    return () if &Dynamics_VerticalCoordinate();
    return () if &Dynamics_Advection();
    return () if &Dynamics_Diffusion();
    return () if &Dynamics_Damping();
    return () if &Dynamics_GravityWaveDrag();
    return () if &Dynamics_FinalConfiguration();
    return () if &Dynamics_Debug();

    # ----------------------------------------------------------------------------
    #  The namelist variables are carried in the %Dynamics hash and the table 
    #  files are carried in the %Ptables hash.
    # ----------------------------------------------------------------------------
    #
    %{$ARWconf{namelist}{dynamics}}  = %Dynamics;


return %ARWconf;
}


sub Dynamics_VerticalCoordinate {
# ==============================================================================================
# WRF &DYNAMICS NAMELIST CONFIGURATION FOR THE VERTICAL COORDINATE
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This subroutine manages the configuration of all thing gravity wave drag in the
#   &dynamics section of the WRF namelist file. 
#
#   FROM THE ARW USER GUIDE AND OTHER "DARK WEB" DOCUMENTS:
#
#   Option: HYBRID_OPT (NEW) - Use either a terrain following or a hybrid vertical coordinate
#  
#     The HYBRID_OPT defines the vertical coordinate used in a simulation. The options are
#     either a terrain following (TF) vertical coordinate (original WRF coordinate) or a
#     new hybrid vertical coordinate (HVC). The new hybrid vertical coordinate uses the
#     terrain following coordinate within the lower part of a model atmosphere and gradually
#     transition to an isobaric coordinate at a defined level (See ETAC below). The benefit 
#     of this coordinate option is to reduce the artificial influence of topography towards 
#     the top of the model.
#
#     The UEMS includes this compile/run-time option as part of the pre-built binaries
#     provided with the release so you are free to use the new hybrid coordinate with
#     passion!
#
#     Values:
#
#         HYBRID_OPT = 0  - Original terrain following coordinate (TF)
#         HYBRID_OPT = 2  - New hybrid vertical coordinate (HVC)
#     
#         
#    Info:  Per module_check_a_mundo.F (V3.7) The GWD option only works with YSU PBL!
#
#    Set HYBRID_OPT to 0 to use the original WRF terrain following coordinate.
#
#    Default:  HYBRID_OPT = 0 (TF)
#
#    And that pretty much says it all - because that's all it says.
#
# ==============================================================================================
# ==============================================================================================
#
	@{$Dynamics{hybrid_opt}}  = @{$Config{uconf}{HYBRID_OPT}};

    @{$Dynamics{etac}}        = &Config_etac()  if $Dynamics{hybrid_opt}[0];

return;
}  #  Dynamics_VerticalCoordinate - That was rather boring



sub Config_etac {
# ==================================================================================
#   Option: ETAC - ETA level at which the WRF model surfaces become isobaric
#
#   Notes:  Used with HYBRID_OPT = 2 only
#
#   Liberated Information:
#
#           ETAC allows the user to select the eta level at which the WRF model surfaces
#           become completely isobaric. As the value of ETAC increases (from 0 towards 1), 
#           more eta levels are impacted as increasing numbers of levels (downward from 
#           the model top) are flattened out,  which is normally a good thing. However,
#           over areas of high topography (not necessarily steep or complex), the vertical
#           eta levels get too compressed when ETAC values larger than about ETAC = 0.22. 
#           Over the Himalayan Plateau with a 10 hPa model lid, a value of ETAC = 0.25 
#           causes model failures. Globally then, a value of 0.2 is considered "safe".
#
#   Default: ETAC = 0.20
# ==================================================================================
#
    my @etac = @{$Config{uconf}{ETAC}};


return @etac;
}




sub Dynamics_TimeIntegration {
# ==============================================================================================
# WRF &DYNAMICS NAMELIST CONFIGURATION FOR RUNGE-KUTTA & OTHER MISCELLANEOUS STUFF
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This subroutine manages the configuration of the time integration scheme parameters
#   within the &dynamics section of the WRF namelist file. In addition, one or two other
#   parameters with absolutely no direct connection to time integration are also 
#   configured here, only because I didn't want to write another subroutine to do it.
#
#   FROM THE ARW USER GUIDE AND OTHER NEFARIOUS DOCUMENTS:
#
# ==============================================================================================
# ==============================================================================================
#
    #---------------------------------------------------------------------------------------------
    #  This parameter is here because there is no better place
    #---------------------------------------------------------------------------------------------
    #
    @{$Dynamics{non_hydrostatic}} = &Config_non_hydrostatic();


    #---------------------------------------------------------------------------------------------
    #  The time integration scheme (order) to use
    #---------------------------------------------------------------------------------------------
    #
    @{$Dynamics{rk_ord}}          = &Config_rk_ord();
    @{$Dynamics{time_step_sound}} = &Config_time_step_sound();

return;
}  #  Dynamics_TimeIntegration - That was rather boring


#
# ===============================================================================================
# ===============================================================================================
#     SO BEGINS THE INDIVIDUAL PARAMETER CONFIGURATION SUBROUTINES - OF WHICH THERE ARE NONE
# ===============================================================================================
# ===============================================================================================
#

sub Config_non_hydrostatic {
# ==================================================================================
#  Variable:  NON_HYDROSTATIC - To be Hydro or non-hydro, that is the question
#
#    Putting this parameter in here simply because it can't find another home
# ==================================================================================
#
    my @non_hydrostatic = @{$Config{uconf}{NON_HYDROSTATIC}};

return @non_hydrostatic;
}


sub Config_rk_ord {
# ==================================================================================
#   Option:  RK_ORD - Time-integration scheme to use.
#
#   Values:
#
#     2 - Runge-Kutta 2nd order  (requires odd-order advection)
#     3 - Runge-Kutta 3rd order  (Recommended)
#
#         *  RK3 is 3rd order accurate for linear eqns, 
#            2nd order accurate for nonlinear eqns.
#
#         *  Stable for centered and upwind advection
#            schemes.    
#
#         *  Stable for Courant number Udt/dx < 1.73
#          
#   Notes:  The higher the order, the more accuracy. The more accuracy, the better you feel!
#            
#           If RK_ORD = 2 then an ODD order advection must be used; unstable otherwise
#           Checked in &Dynamics_FinalConfiguration
#
#   Default: RK_ORD = 3
# ==================================================================================
#
    my @rk_ord = @{$Config{uconf}{RK_ORD}};


return @rk_ord;
}


sub Config_time_step_sound {
# ==================================================================================
#    Option: TIME_STEP_SOUND - number of sound time steps per main time step
#
#    Values:  Typical value is 4 (4:1 ratio); however, if you are using a time
#             step much larger than 6*dx you may need to increase this value.
#             Also, if a simulation becomes unstable, increasing this value is
#             something you could try.
#
#    Notes:   Only use even integers
#
#             If using the adaptive time step option then TIME_STEP_SOUND
#             will automatically be set to 0 as required by law.
#
#    Default: TIME_STEP_SOUND = 0 (set automatically)
# ==================================================================================
#
    my @time_step_sound = @{$Config{uconf}{TIME_STEP_SOUND}};

    foreach (@time_step_sound) {$_ = int $_; $_++ if $_%2;}  #  Must be even integer

    @time_step_sound = (0) x $Config{maxdoms} if grep {/^0$/} @time_step_sound; #  If one domain 0, all domains 0

return @time_step_sound;
}


sub Dynamics_Advection {
# ==============================================================================================
# WRF &DYNAMICS NAMELIST CONFIGURATION FOR ADVECTION AND STUFF
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This subroutine manages the configuration of all things advection in the
#   &dynamics section of the WRF namelist file. 
#
#   Note that some (most) of the information used to produce the guidance presented
#   in this file was likely taken from the WRF user's guide and presentation materials,
#   and those authors should receive all the gratitude as well as any proceeds that 
#   may be derived from reading this information.
#
# ==============================================================================================
# ==============================================================================================
#

    #---------------------------------------------------------------------------------------------
    #  Method of Advection for Scalar Variables (MAX DOMAINS)
    #---------------------------------------------------------------------------------------------
    #
    #  Values - Some are better than others:
    #
    #    0 - Simple advection
    #    1 - Positive-Definite (default)
    #    2 - Monotonic
    #    3 - 5th weighted essentially non-oscillatory (WENO)
    #    4 - 5th weighted essentially non-oscillatory (WENO) with Positive Definite
    #
    #   The default value is Positive-Definite  ON (1).
    #
    #   Some pearls of wisdom from the WRF developers regarding the monotonic
    #   and positive-definite advection options:
    #
    #   "The positive-definite and monotonic options are available for moisture,
    #    scalars, chemical scalars and TKE in the ARW solver.  Both the monotonic
    #    and positive-definite transport options conserve scalar mass locally and
    #    globally and are consistent with the ARW mass conservation equation. We
    #    recommend using the positive-definite option for moisture variables on
    #    all real-data simulations. "
    #
    #    Lots more jewels:
    #
    #    1. "The integration sequence in ARW changes when the positive-definite
    #        or monotonic options are used.  When the options are not activated,
    #        the timestep tendencies from the physics (excluding microphysics) i
    #        are used to update the scalar mixing ratio at the same time as the
    #        transport (advection), and the microphysics is computed and moisture
    #        is updated based on the transport+physics update.  When the monotonic
    #        or positive definite options are activated, the scalar mixing ratio is
    #        first updated with the physics tendency, and the new updated values are
    #        used as the starting values for the transport scheme.  The microphysics
    #        update occurs after the transport update using these latest values as
    #        its starting point. It is important to remember that for any scalars,
    #        the local and global conservation properties, positive definiteness and
    #        monotonicity depend upon each update possessing these properties."
    #
    #    2. "Some model filters may not be positive definite:
    #
    #        i.  diff_6th_opt = 1 is neither positive definite nor monotonic.  Use
    #            diff_6th_opt = 2 if you need this diffusion option (diff_6th_opt = 2
    #            is monotonic and positive-definite).  We have encountered cases where
    #            the departures from monotonicity and positive-definiteness have been
    #            very noticeable.
    #
    #        ii. diff_opt = 1 and km_opt = 4 (a commonly-used real-data case mixing option)
    #            is not guaranteed to be positive-definite nor monotonic due to the variable
    #            eddy diffusivity K.  We have not observed significant departures from
    #            positive-definiteness or monotonicity when this filter is used with these
    #            transport options.
    #
    #        iii.The diffusion option that uses a user-specified constant eddy viscosity
    #            is positive definite and monotonic.
    #
    #        iv. Other filter options that use variable eddy viscosity are not positive
    #            definite or monotonic."
    #
    #    3.  "Most of the model physics are not monotonic nor should they be - they represent
    #         sources and sinks in the system.  All should be positive definite, although we
    #         have not examined and tested all options for this property."
    #
    #    4.  "The monotonic option adds significant smoothing to the transport in regions
    #         where it is active.  You may want to consider turning off the other model
    #         filters for variables using monotonic transport (filters such as the second
    #         and sixth order horizontal filters)."
    #
    #    5.   If you are using a double moment microphysics scheme, you should consider 
    #         WENO (4 & 5) if your simulations fields are noisy.
    #
    #    GLOBAL USERS TAKE NOTE:
    #
    #    If you are running a simulation on a global (lat-lon) grid then neither Positive nor 
    #    Definite (1) nor Monotonic (2) advection should be used as they do not play well with 
    #    the polar filters.  Instead use simple advection (0), and if you forget it will be
    #    forced upon you.  This restriction is not placed on regional latitude-longitude 
    #    grids in the UEMS although the documentation is not clean regarding the use of PDA
    #    with regional latitude-longitude grids.
    #
    #    The Positive-Definite Advection is only valid with moisture (moist_adv_opt),
    #    scalar (scalar_adv_opt), chemistry variables (chem_adv_opt) and TKE (tke_adv_opt)
    #
    #---------------------------------------------------------------------------------------------
    #
    @{$Dynamics{moist_adv_opt}}    = &Config_moist_adv_opt();
    @{$Dynamics{scalar_adv_opt}}   = &Config_scalar_adv_opt();
#   @{$Dynamics{chem_adv_opt}}     = &Config_chem_adv_opt();
    @{$Dynamics{tke_adv_opt}}      = &Config_tke_adv_opt();

    @{$Dynamics{momentum_adv_opt}} = &Config_momentum_adv_opt();


    #  ------------------------------------------------------------------------
    #  Horizontal Advection Order for Momentum & Scalars
    #  ------------------------------------------------------------------------
    #
    @{$Dynamics{h_mom_adv_order}}  = &Config_h_mom_adv_order();
    @{$Dynamics{h_sca_adv_order}}  = &Config_h_sca_adv_order();


    #  ------------------------------------------------------------------------
    #  Vertical Advection Order for Momentum & Scalars
    #  ------------------------------------------------------------------------
    #
    @{$Dynamics{v_mom_adv_order}}  = &Config_v_mom_adv_order();
    @{$Dynamics{v_sca_adv_order}}  = &Config_v_sca_adv_order();


    #  ------------------------------------------------------------------------
    #  (Possibly) Additional Advection Related Parameters
    #  ------------------------------------------------------------------------
    #
    @{$Dynamics{use_theta_m}}      = &Config_use_theta_m();
    @{$Dynamics{use_q_diabatic}}   = &Config_use_q_diabatic();


return;
}  #  Dynamics_Advection


#
# ==================================================================================
# ==================================================================================
#      SO BEGINS THE INDIVIDUAL PARAMETER CONFIGURATION SUBROUTINES
# ==================================================================================
# ==================================================================================
#

sub Config_moist_adv_opt {
# ==================================================================================
#   Values:
#
#     0 - Simple advection
#     1 - Positive Definite  (default)
#     2 - Monotonic
#     3 - 5th weighted essentially non-oscillatory (WENO)
#     4 - 5th weighted essentially non-oscillatory (WENO) with Positive Definite
# ==================================================================================
#
    my @moist_adv_opt = @{$Config{uconf}{MOIST_ADV_OPT}};

return @moist_adv_opt;
}


sub Config_scalar_adv_opt {
# ==================================================================================
#   Values:
#
#     0 - Simple advection
#     1 - Positive Definite  (default)
#     2 - Monotonic
#     3 - 5th weighted essentially non-oscillatory (WENO)
#     4 - 5th weighted essentially non-oscillatory (WENO) with Positive Definite
# ==================================================================================
#
    my @scalar_adv_opt = @{$Config{uconf}{SCALAR_ADV_OPT}};


return @scalar_adv_opt;
}


sub Config_tke_adv_opt {
# ==================================================================================
#   Values:
#
#     0 - Simple advection
#     1 - Positive Definite  (default)
#     2 - Monotonic
#     3 - 5th weighted essentially non-oscillatory (WENO)
#     4 - 5th weighted essentially non-oscillatory (WENO) with Positive Definite
# ==================================================================================
#
    my @tke_adv_opt = @{$Config{uconf}{TKE_ADV_OPT}};


return @tke_adv_opt;
}


sub Config_chem_adv_opt {
# ==================================================================================
#   Values:
#
#     0 - Simple advection
#     1 - Positive Definite  (default)
#     2 - Monotonic
#     3 - 5th order weighted essentially non-oscillatory (WENO)
#     4 - 5th order weighted essentially non-oscillatory (WENO) with Positive Definite
# ==================================================================================
#
    my @chem_adv_opt = @{$Config{uconf}{CHEM_ADV_OPT}};


return @chem_adv_opt;
}


sub Config_momentum_adv_opt {
# ==================================================================================
#   Values:
#
#     1 - Standard  (default)
#     3 - 5th order weighted essentially non-oscillatory (WENO)
# ==================================================================================
#
    my @momentum_adv_opt = @{$Config{uconf}{MOMENTUM_ADV_OPT}};


return @momentum_adv_opt;
}


sub Config_h_mom_adv_order {
# ==================================================================================
#   Option: H_MOM_ADV_ORDER
#
#     Horizontal advection order may be 2nd through 6th order with 5th order (5)
#     being the recommended value. Note that you should use an ODD order.
#
#     The odd-ordered flux divergence schemes are equivalent to the next higher
#     ordered (even) flux-divergence scheme plus a dissipation term of the 
#     higher even order with a coefficient proportional to the Courant number.
#
#     H_MOM_ADV_ORDER  - Horizontal momentum advection order
#
#   Defaults:  H_MOM_ADV_ORDER = 5
# ==================================================================================
#
    my @h_mom_adv_order = @{$Config{uconf}{H_MOM_ADV_ORDER}};


return @h_mom_adv_order;
}


sub Config_h_sca_adv_order {
# ==================================================================================
#   Option: H_SCA_ADV_ORDER
#
#     Horizontal advection order may be 2nd through 6th order with 5th order (5)
#     being the recommended value. Note that you should use an ODD order.
#
#     The odd-ordered flux divergence schemes are equivalent to the next higher
#     ordered (even) flux-divergence scheme plus a dissipation term of the 
#     higher even order with a coefficient proportional to the Courant number.
#
#     H_SCA_ADV_ORDER  - Horizontal scalar advection order
#
#   Defaults:  H_SCA_ADV_ORDER = 5
# ==================================================================================
#
    my @h_sca_adv_order = @{$Config{uconf}{H_SCA_ADV_ORDER}};


return @h_sca_adv_order;
}


sub Config_v_mom_adv_order {
# ==================================================================================
#   Options: V_MOM_ADV_ORDER
#
#     Vertical advection order may be 2nd through 6th order with 3rd order (3)
#     being the recommended value. Note that you should use an ODD order.
#
#     V_MOM_ADV_ORDER  - Vertical momentum advection order
#
#   Defaults:  V_MOM_ADV_ORDER = 3
# ==================================================================================
#
    my @v_mom_adv_order = @{$Config{uconf}{V_MOM_ADV_ORDER}};


return @v_mom_adv_order;
}


sub Config_v_sca_adv_order {
# ==================================================================================
#   Options: V_SCA_ADV_ORDER
#
#     Vertical advection order may be 2nd through 6th order with 3rd order (3)
#     being the recommended value. Note that you should use an ODD order.
#
#     V_SCA_ADV_ORDER  - Vertical scalar advection order
#
#   Defaults:  V_SCA_ADV_ORDER = 3
# ==================================================================================
#
    my @v_sca_adv_order = @{$Config{uconf}{V_SCA_ADV_ORDER}};


return @v_sca_adv_order;
}


sub Config_use_theta_m {
# ==================================================================================
#   Option:  USE_THETA_M - Option to use moist theta = theta(1+1.61Qv) in WRF solver
#
#   Values:
#
#     0 - Use dry theta in dynamics
#     1 - Use moist theta (theta_m = theta(1+1.61Qv) )
#
#   Notes:   
#
#     a.  For LES simulations
#     b.  Only works with a single domain
#     c.  May not be used with damp_opt=2 (UEMS enforced)
#     d.  The option may not be used with rad_nudge (Not UEMS supported anyway)
#
#   Default: USE_THETA_M = 0 (Old behavior)
# ==================================================================================
#
    my @use_theta_m = @{$Config{uconf}{USE_THETA_M}};


return @use_theta_m;
}


sub Config_use_q_diabatic {
# ==================================================================================
#   Option:  USE_Q_DIABATIC - Included QV and QC tendencies in advection
#
#   Values:
#
#     0 - Don't Advect QV and QC tendencies
#     1 - Advect QV and QC tendencies
#
#   Notes:  helps to produce correct solution in an idealized 'moist benchmark'
#           test case. In real data cases requires that timestep be reduced.
#           Exactly how much?  I have no idea.
#
#   Default: USE_Q_DIABATIC = 0 (Old behavior)
# ==================================================================================
#
    my @use_q_diabatic = @{$Config{uconf}{USE_Q_DIABATIC}};


return @use_q_diabatic;
}


sub Dynamics_Diffusion {
# ==============================================================================================
# WRF &DYNAMICS NAMELIST CONFIGURATION FOR DIFFUSION AND STUFF
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This subroutine manages the configuration of all things diffusion in the
#   &dynamics section of the WRF namelist file. 
#
#   Diffusion in WRF is categorized under two parameters, the diffusion option and
#   the K option. The diffusion option selects how the derivatives used in diffusion
#   are calculated, and the K option selects how the K coefficients are calculated.
#   Note that when a PBL option is selected, vertical diffusion is done by the PBL
#   scheme, and not by the diffusion scheme.
#
#   Note that if you are running a LES simulation the ems_run routine will attempt to
#   configure your run with the appropriate settings.
#
#   RECOMMENDATIONS - Real-data cases with PBL physics turned ON (dx > 500m)
#     a. DIFF_OPT = 1
#     b. KM_OPT = 4
#     Compliments vertical diffusion done by PBL scheme
#
#   RECOMMENDATIONS - Cloud resolving models with smooth or no topography
#     a. DIFF_OPT = 1
#     b. KM_OPT = 2 or 3
#
#   RECOMMENDATIONS - LES and cloud resolving simulations with complex topography and NO PBL
#     a. DIFF_OPT = 2 <- more accurate for sloped coordinate surfaces
#     b. KM_OPT = 2 or 3
#
#   RECOMMENDATIONS - When running an LES simulation:
#     c. No WRF mesoscale -> LES nested simulations allowed (yet)
#     d. Start with Super hi-res BCs from WRF simulation
#     e. Do 2-way LES -> LES nest
#     f. Must be 3D diffusion
#     g. Grid spacing must be << energy-containing eddies (to resolve “large eddies”)
#     h. Set domain to be ~5 times of PBL height zi and vertical domain ~ 2 zi
#     i. Turn off PBL schemes; use 3D diffusion (the TKE diffusion scheme)
#     j. If nesting, be careful about spin-up process
#
# Finally: DIFF_OPT = 2, KM_OPT = 4 is now an option for high resolution (DX < 1km) 
#          real data cases over complex terrain; HOWEVER, this is not to be confused
#          with a "guaranteed not to fail" option. Your experiences may less than
#          successful and you will have to live with it.
#
# ==============================================================================================
# ==============================================================================================
#

    #---------------------------------------------------------------------------------------------
    #  Configure the various diffusion options available in the dynamics namelist. This 
    #  process is a bit messy as the diffusion choices vary for global simulations with
    #  PD advection OFF and LES simulations.
    #
    #  This subroutine completes a first pass of the configuration settings. Most of the 
    #  "heavy lifting" is done in the &Dynamics_FinalConfiguration subroutine.
    #---------------------------------------------------------------------------------------------
    #
    @{$Dynamics{diff_opt}}        = &Config_diff_opt();
    @{$Dynamics{km_opt}}          = &Config_km_opt();

    @{$Dynamics{diff_6th_opt}}    = &Config_diff_6th_opt();
    @{$Dynamics{diff_6th_factor}} = &Config_diff_6th_factor() if $Dynamics{diff_6th_opt}[0];


return;
}  #  Dynamics_Diffusion


#
# ==================================================================================
# ==================================================================================
#      SO BEGINS THE INDIVIDUAL PARAMETER CONFIGURATION SUBROUTINES
# ==================================================================================
# ==================================================================================
#

sub Config_diff_opt {
# ==================================================================================
#   Option:  DIFF_OPT  - turbulence and mixing (diffusion) scheme (MAX DOMAINS)
#
#     DIFF_OPT specifies which turbulence and mixing (diffusion) scheme to use.
#     Current options include:
#
#        0 - No diffusion. Note that the value of KM_OPT is ignored.
#            Some vertical diffusion is still done in the PBL scheme.
#
#            It's ok to use DIFF_OPT = 0 for real-data cases.
#
#        1 - Simple diffusion. Evaluates the 2nd order diffusion term on
#            coordinate surfaces, which is fine in most cases unless the 
#            model surfaces have extreme slope, such as with well-resolved
#            complex terrain. Problem because large model surface slopes
#            introduce a vertical component in the mixing that is not 
#            correct.
#
#            Uses KVDIF for vertical diffusion unless PBL option is used
#            May be used with KM_OPT = 1 or 4. 
#
#            Recommended for real-data cases.
#
#        2 - Full diffusion. Evaluates mixing terms in physical space
#            (horizontally), which provides a more accurate result over 
#            complex (steep) terrain but may be unstable.
#
#            A bit more computationally expensive since it requires a 
#            vertical correction term and additional data points in the 
#            calculation.
#
#            Value of EPSSM (sound wave damper) may need to be increased 
#            to 0.5 or greater to improve stability.
#
#            Also set in the ancillary option section:
#              MIX_FULL_FIELDS = T
#              ISFFLX = 1 or 2  (In run_physics.conf)
#              KM_OPT = 2, 3, or 4
#              DAMP_OPT = 0
#
#     You can now specify a DIFF_OPT value for each domain. This should only
#     be done if you are nesting down to an LES or to a sub 500m dx over 
#     complex terrain.
# ==================================================================================
#
    my @diff_opt = @{$Config{uconf}{DIFF_OPT}};

    #  Provide a warning for DIFF_OPT = 2 if the DX of the domain is greater then 1km
    #
    my @dopts = ();
    foreach (sort {$a <=> $b} keys %{$Rconf{dinfo}{domains}}) {push @dopts => $_ if $Rconf{dinfo}{domains}{$_}{dx} > 1000. and $diff_opt[$_-1] == 2;}

    if (@dopts) {
        my $str = &Ecomm::JoinString(\@dopts);
        my $mesg = "The DIFF_OPT = 2 option should not be used with a grid spacing of greater than 1 km. Setting ".
                   "DIFF_OPT = 1 for domains $str.";
        &Ecomm::PrintMessage(6,11+$Rconf{arf},88,1,2,'Just Saving Your Simulation, Again:',$mesg);
        $diff_opt[$_-1] = 1 foreach @dopts;
    }
    
return @diff_opt;
}


sub Config_km_opt {
# ==================================================================================
#   Option:  KM_OPT - Eddy coefficient (K) configuration
#
#    KM_OPT defines the Eddy coefficient (K) option to use.  When using a PBL
#    only options (1) and (4) below make sense, because (2) and (3) are
#    designed for 3D diffusion and would duplicate some of the diffusion
#    done by the PBL scheme.
#
#    Current options include:
#
#        0 - Nothing (only used with global domains - gets set elsewhere)
#
#        1 - Constant K value (Horizontal and vertical diffusion is specified
#            by KHDIF and KVDIF respectively)
#
#            *  For idealized LES simulations
#            *  Set khdif
#            *  Set kvdif
#            *  Get your party started
#
#        2 - 1.5 order TKE closure (3D)(K). A prognostic equation for
#            turbulent kinetic energy is used, and K is based on TKE.
#
#            *  Requires DIFF_OPT = 1
#            *  Not recommended for DX > 2km
#            *  Nonlinear Backscatter Anisotropic (NBA) scheme available
#            *  Set mix_isotropic (Automatically set to 1 (ON)
#            *  Set mix_upper_bound
#            *  Additional namelist parameter c_k make added
#
#        3 - Smagorinsky first order closure (3D)  wherein K is diagnosed
#            from 3d deformation and stability.
#
#            *  Requires DIFF_OPT = 1
#            *  Not recommended for DX > 2km
#            *  Nonlinear Backscatter Anisotropic (NBA) scheme available
#            *  Set mix_isotropic (Automatically set to 1 (ON)
#            *  Set mix_upper_bound
#            *  Set isfflx  (In run_physics.conf)
#
#        4 - Horizontal Smagorinsky first order closure (2D) wherein K for
#            horizontal diffusion is diagnosed from just horizontal deformation.
#            The vertical diffusion is assumed to be done by the PBL scheme.
#
#            *  Use with PBL scheme
#            *  Always the best choice for real-data cases
#            *  Nothing additional needed
#
#    Note that options 2 and 3 are NOT recommended for DX > 2km and should only
#    be used when running without a PBL scheme since they do 3D diffusion.
#
#    Options 1 and 4 is recommended for real-data cases since they compliment
#    vertical diffusion dome by the PBL scheme.
# ==================================================================================
#
    my @km_opt = @{$Config{uconf}{KM_OPT}};


return @km_opt;
}


sub Config_diff_6th_opt {
# ==================================================================================
#  Option:  DIFF_6TH_OPT - 6th order diffusion configuration
#
#    6th order diffusion will be applied to all variables to serve
#    as a short-wave numerical noise filter. May be used for real-data
#    simulations.
#
#    Values for DIFF_6TH_OPT include:
#
#        0 - None (default unless Positive Definite Advection used)
#        1 - 6th order diffusion ON (can produce negative moisture - Not allowed in UEMS)
#        2 - 6th order diffusion ON and prohibit up-gradient diffusion
#            which is better for moisture conservation. SHOULD BE USED
#            IN COMBINATION WITH Positive Definite Advection
#
#  Default: DIFF_6TH_OPT = <blank> (Advection Dependent)
# ==================================================================================
#
    my @diff_6th_opt = @{$Config{uconf}{DIFF_6TH_OPT}};


return @diff_6th_opt;
}


sub Config_diff_6th_factor {
# ==================================================================================
#    DIFF_6TH_FACTOR is the non-dimensional strength of the diffusion.
#    typical value is 0.12. A value of 1.0 will result in complete
#    removal of 2*dx waves in a single time step (Ouch!).  The default
#    value for DIFF_6TH_OPT is 0 although DIFF_6TH_OPT = 2 is recommended.
#
#    Default: DIFF_6TH_FACTOR = 0.12
# ==================================================================================
#
    my @diff_6th_factor = @{$Config{uconf}{DIFF_6TH_FACTOR}};


return @diff_6th_factor;
}


sub Dynamics_Damping {
# ==============================================================================================
# WRF &DYNAMICS NAMELIST CONFIGURATION FOR DAMPING STUFF
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This subroutine manages the configuration of all things damping in the
#   &dynamics section of the WRF namelist file. 
#
#   FROM THE ARW USER GUIDE:
#
#     Upper Damping (DAMP_OPT): 
#
#       Either a layer of increased diffusion (damp_opt =1) or a Rayleigh
#       relaxation layer (2) or an implicit gravity-wave damping layer (3),
#       can be added near the model top to control reflection from the upper 
#       boundary.
#
#     Vertical velocity damping (W_DAMPING):
#    
#       For operational robustness, vertical motion can be damped to prevent
#       the model from becoming unstable with locally large vertical velocities.
#       This only affects strong updraft cores, so has very little impact on
#       results otherwise.
#
#     Divergence Damping (SMDIV):
#
#       Controls horizontally-propagating sound waves.
#
#     External Mode Damping (EMDIV):
#
#       Controls upper-surface (external) waves.
#
#     Time Off-centering (EPSSM):
#
#       Controls vertically-propagating sound waves.
#
# ==============================================================================================
# ==============================================================================================
#

    #---------------------------------------------------------------------------------------------
    #  Configure the various upper damping options available in the dynamics namelist. 
    #
    #  This subroutine completes a first pass of the configuration settings. Most of the 
    #  "heavy lifting" is done in the &Dynamics_FinalConfiguration subroutine.
    #---------------------------------------------------------------------------------------------
    #
    @{$Dynamics{damp_opt}}        = &Config_damp_opt();
    @{$Dynamics{dampcoef}}        = &Config_dampcoef()  if $Dynamics{damp_opt}[0];
    @{$Dynamics{zdamp}}           = &Config_zdamp()     if $Dynamics{damp_opt}[0];


    #---------------------------------------------------------------------------------------------
    #  Configure the vertical velocity damping options
    #---------------------------------------------------------------------------------------------
    #
    @{$Dynamics{w_damping}}        = &Config_w_damping();


return;
}  #  Dynamics_Damping


#
# ==================================================================================
# ==================================================================================
#      SO BEGINS THE INDIVIDUAL PARAMETER CONFIGURATION SUBROUTINES
# ==================================================================================
# ==================================================================================
#

sub Config_damp_opt {
# ==================================================================================
#  DYNAMICS Variable:  DAMP_OPT
#
#    0 - No upper level damping
#
#    1 - Upper level diffusive layer. Enhanced horizontal diffusion at model
#        top. Also enhanced vertical diffusion at top for diff_opt=2.
#        Cosine function of height.  Uses additional parameters
#
#          *  zdamp   : depth of damping layer
#          *  dampcoef: non dimensional maximum magnitude of damping ~ 0.01 to 0.1
#        
#        Note: Do not use if mix_full_fields = T
#
#    2 - Rayleigh relaxation damping.  Upper level relaxation towards 1-d
#        profile. For idealized cases only -outlawed!
# 
#    3 - W-Rayleigh relaxation damping. Upper level relaxation towards zero 
#        vertical motion. Cosine function of height.  Applied in small time-
#        steps (dampcoef=0.2 is stable). Uses additional parameters:
#
#          *  zdamp   : Depth of damping layer
#          *  dampcoef: Maximum magnitude for damping
#     
#        Used for global domains although 0 also works
# ==================================================================================
#
    my @damp_opt = @{$Config{uconf}{DAMP_OPT}};


return @damp_opt;
}


sub Config_dampcoef {
# ==================================================================================
#   Option:  DAMPCOEF - The non-dimensional maximum magnitude for damping
#
#   Values:
#            Set DAMPCOEF < = 0.2 for real data cases
#
#   Default: DAMPCOEF = 0.2
# ==================================================================================
#
    my @dampcoef = @{$Config{uconf}{DAMPCOEF}};


return @dampcoef;
}


sub Config_zdamp {
# ==================================================================================
#   Option:  ZDAMP (Max Domains) - Depth over which damping is applied
#
#   Notes:   ZDAMP is the depth (meters) from the model top over which
#            to apply damping with DAMP_OPT = 1 or 3.
#
#   Default: ZDAMP = 5000
# ==================================================================================
#
    my @zdamp = @{$Config{uconf}{ZDAMP}};

return @zdamp;
}


sub Config_w_damping {
# ==================================================================================
#   Option:  W_DAMPING - Turn ON|OFF vertical velocity damping
#
#   Values:
#
#     0 - No  damping
#     1 - Yes damping
#
#   Notes:   W_DAMPING sets the vertical velocity damping can be used for
#            real-time simulations. Vertical motion is damped to prevent
#            the model from becoming unstable with locally large vertical
#            velocities.  This only affects strong updraft cores so it
#            has very little impact on results otherwise.
#
#             For real-time and case study simulations it is recommended
#             that W_DAMPING = 1.
#
#   Default:  W_DAMPING = 1
# ==================================================================================
#
    my @w_damping = @{$Config{uconf}{W_DAMPING}};

return @w_damping;
}


sub Config_smdiv {
# ==================================================================================
#   Option:  SMDIV - Divergence damping (0.1 is typical)
# ==================================================================================
#
    my @smdiv = @{$Config{uconf}{SMDIV}};

return @smdiv;
}


sub Config_emdiv {
# ==================================================================================
#   Option:  EMDIV - External-mode filter coef (0.01 is typical for real-data cases)
# ==================================================================================
#
    my @emdiv = @{$Config{uconf}{EMDIV}};

return @emdiv;
}


sub Dynamics_GravityWaveDrag {
# ==============================================================================================
# WRF &DYNAMICS NAMELIST CONFIGURATION FOR STUFF
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This subroutine manages the configuration of all thing gravity wave drag in the
#   &dynamics section of the WRF namelist file. 
#
#   FROM THE ARW USER GUIDE AND OTHER NEFARIOUS DOCUMENTS:
#
#   Option: GWD_OPT  - Gravity Wave Drag Scheme
#
#    The Gravity Wave Drag and Mountain Blocking scheme attempts to account for sub-grid
#    scale mountain effects. Tests using the gravity wave drag option on the operational
#    NAM at NCEP has shown an improvement in overall synoptic scale  and near-surface
#    wind and temperature forecasts.
#
#    The use of gravity wave drag parameterization is suggested:
#
#      a.  When DX > 10km
#      b.  With simulations longer than 5 days
#      c.  Over large domains with mountain ranges
#
#    The Gravity wave drag parameterization incorporates the effects of mountain wave
#    stress and pressure drag. The vertical distribution of wave stress effects the winds
#    aloft due to momentum deposition.

#    The "Mountain Blocking" component attempts to account for the effects of flow around
#    subgrid scale topography wherein low-level flow is blocked below a dividing streamline
#    and is forced around and not over barriers.
#
#    Note:  For the ARW, this option should only be used un-rotated lat/long (e.g. global)
#           or Mercator projections because the input orographic sub-grid asymmetry arrays
#           assume this grid orientation.
#
#    Info:  Per module_check_a_mundo.F (V3.7) The GWD option only works with YSU PBL!
#
#    Set GWD_OPT to 1 to turn ON gravity wave drag in the model, 0 to turn it OFF.
#
#    Default:  GWD_OPT = 0 (OFF)
#
#    And that pretty much says it all - because that's all it says.
#
# ==============================================================================================
# ==============================================================================================
#
	@{$Dynamics{gwd_opt}}  = @{$Config{uconf}{GWD_OPT}};

return;
}  #  Dynamics_GravityWaveDrag - That was rather boring


sub Dynamics_FinalConfiguration {
# ==============================================================================================
# WRF FINAL &dynamics NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Subroutine that cleans up any loose ends within the &dynamics section of the WRF
#  namelist. Occasionally, variables require tweaks after everything else has been 
#  due to dependencies that had not been resolved at the time of original configuration.
#
#  Note: Due to the specialized nature of many of the &dynamics parameter values, some of 
#        the configuration subroutines have been moved here in an attempt to retain the 
#        values from the configuration file. A value might be lost if the configuration 
#        of a sub-option were done (or not done) previously but then needed to be changed
#        here.
#
#        Also, because the diffusion options are tied to the PBL scheme, this is one of
#        the few namelist configuration subroutines (&dynamics) where a parameter setting 
#        from outside the primary namelist will be used. Normally, this approach is reserved
#        for the &ARW_FinalConfiguration subroutine wherein all namelist variables are 
#        available.
# ==============================================================================================
# ==============================================================================================
#

    return () if &ConfigFinal_GravityWaveDrag();
    return () if &ConfigFinal_TimeIntegration();
    return () if &ConfigFinal_GlobalDomain();
    return () if &ConfigFinal_Advection();
    return () if &ConfigFinal_Diffusion();
    return () if &ConfigFinal_Damping();

    return () if &ConfigFinal_ExcludedDomains();

return;
} #  Dynamics_FinalConfiguration


sub ConfigFinal_Advection {
# ==================================================================================
#  This routine handles any final configuration checks for the advection
#  scheme that could not be done previously due to dependencies that had
#  not been resolved. Boilerplate stuff - just like this text.
# ==================================================================================
#
    my %Physics = %{$ARWconf{namelist}{physics}};  #  We'll need this

    #---------------------------------------------------------------------------------------------
    #  If using 2nd order Runge-Kutta then must use odd-order advection
    #---------------------------------------------------------------------------------------------
    #
    if ($Dynamics{rk_ord}[0] == 2) {

        unless ($Dynamics{h_mom_adv_order}[0]%2 and $Dynamics{h_sca_adv_order}[0]%2 and $Dynamics{h_mom_adv_order}[0]%2 and $Dynamics{h_sca_adv_order}[0]%2) {
            my $mesg = "When using 2nd order Runge-Kutta (RK_ORD = 2) you must use an odd-order advection scheme for computational stability. ".
                       "Setting horizontal advection order to 5 and vertical advection order to 3.";
            &Ecomm::PrintMessage(6,11+$Rconf{arf},92,1,2,'Just Saving Your Simulation, Again:',$mesg);

            @{$Dynamics{h_mom_adv_order}} = (5) x $Config{maxdoms};
            @{$Dynamics{h_sca_adv_order}} = (5) x $Config{maxdoms};
            @{$Dynamics{v_mom_adv_order}} = (3) x $Config{maxdoms};
            @{$Dynamics{v_sca_adv_order}} = (3) x $Config{maxdoms};
        }
    }

    #---------------------------------------------------------------------------------------------
    #  Encourage use of odd advection orders
    #---------------------------------------------------------------------------------------------
    #
    my $parm = '';
    foreach my $p (qw(h_mom_adv_order h_sca_adv_order h_mom_adv_order h_sca_adv_order)) {$parm = $p unless  $Dynamics{$p}[0]%2;}
    if ($parm) {
        my $mesg = "You are using an EVEN advection order ($parm = $Dynamics{$parm}[0]). An ODD order is strongly encouraged.";
        &Ecomm::PrintMessage(6,11+$Rconf{arf},92,1,2,$mesg);
    }


    #---------------------------------------------------------------------------------------------
    #  Consider using a WENO advection scheme (3,4) with double moment microphysics schemes
    #---------------------------------------------------------------------------------------------
    #
    if (  grep {/^$Physics{mp_physics}[0]$/} (9,10,11,13,14,16,17,18,22,28,30,32) and 
        ! grep {/^$Dynamics{moist_adv_opt}[0]$/} (3,4) ) {
#       &Ecomm::PrintMessage(6,11+$Rconf{arf},404,1,2,"A WENO advection scheme (3,4) is recommended with double moment microphysics (MP = $Physics{mp_physics}[0])");
    }

                     
return;
}


sub ConfigFinal_GlobalDomain {
# ==================================================================================
#  This routine overrides the user configuration and assigns values for a global
#  WRF simulation based on the recommendations by the WRF development team. This
#  action is necessary due to the specific requirements for a global simulation
#  and to save the developer from endless hours of troubleshooting. Note that
#  this brute-force approach only applies for the dynamics section of the 
#  namelist. 
#  
#  Some comments from the WRF User's Guide V3.8:
#
#    Since this (global) is not a commonly-used configuration in the model, use it 
#    with caution. Not all physics and diffusion options have been tested with it, 
#    and some options may not work well with polar filters. Also, positive-definite 
#    and monotonic advection options do not work with polar filters in a global run 
#    because polar filters can generate negative values of scalars. This also implies, 
#    that WRF-Chem cannot be run with positive-definite and monotonic options in a 
#    global WRF setup.
# ==================================================================================
#
    return unless $Rconf{rtenv}{global};  #  Don't need to be here unless necessary

    #-------------------------------------------------------------------------------
    #  Advection Options: Use simple advection with global simulations
    #-------------------------------------------------------------------------------
    #
    @{$Dynamics{moist_adv_opt}}    = (0) x $Config{maxdoms};
    @{$Dynamics{scalar_adv_opt}}   = (0) x $Config{maxdoms};
    @{$Dynamics{momentum_adv_opt}} = (0) x $Config{maxdoms};
    @{$Dynamics{tke_adv_opt}}      = (0) x $Config{maxdoms};


    #-------------------------------------------------------------------------------
    #  Diffusion & Damping Options:  
    #
    #     a. diff_opt & km_opt = 0
    #     b. diff_6th_opt = 0
    #     c. damp_opt = 0 or 3
    #-------------------------------------------------------------------------------
    #
    @{$Dynamics{diff_opt}}        = (0) x $Config{maxdoms};
    @{$Dynamics{diff_6th_opt}}    = (0) x $Config{maxdoms};
    @{$Dynamics{damp_opt}}        = (3) x $Config{maxdoms} unless grep {/^$Dynamics{damp_opt}[0]$/} (0,3);
   
    if ($Dynamics{damp_opt}[0] == 3) {
       @{$Dynamics{dampcoef}} = @{$Config{uconf}{DAMPCOEF}};
       @{$Dynamics{zdamp}}    = @{$Config{uconf}{ZDAMP}};
    }


    #-------------------------------------------------------------------------------
    #  Additional GLOBAL domain parameters not used anywhere else
    #-------------------------------------------------------------------------------
    #
    @{$Dynamics{pos_def}}                 = &Config_pos_def();
    @{$Dynamics{base_temp}}               = &Config_base_temp();
    @{$Dynamics{coupled_filtering}}       = &Config_coupled_filtering();
    @{$Dynamics{swap_pole_with_next_j}}   = &Config_swap_pole_with_next_j();
    @{$Dynamics{actual_distance_average}} = &Config_actual_distance_average();

    @{$Dynamics{fft_filter_lat}}          = &Config_fft_filter_lat();


return;
}


sub ConfigFinal_TimeIntegration {
# ==================================================================================
#  This routine handles any final configuration checks for the time integration 
#  routines that could not be done previously due to dependencies that had
#  not been resolved.
# ==================================================================================
#
    my %Domains = %{$ARWconf{namelist}{domains}};  #  We'll need this

    #-------------------------------------------------------------------------------
    #  Make sure that if the adaptive time step is used the time_step_sound = 0
    #-------------------------------------------------------------------------------
    #
    @{$Dynamics{time_step_sound}} = (0) x $Config{maxdoms} if $Domains{use_adaptive_time_step}[0] eq 'T';


return;
}


sub ConfigFinal_Diffusion {
# ==================================================================================
#  This routine handles any final configuration checks for the diffusion
#  scheme that could not be done previously due to dependencies that had
#  not been resolved. Boilerplate stuff - just like this text and that above.
# ==================================================================================
#
    my %Domains = %{$ARWconf{namelist}{domains}};  #  We'll need this
    my %Physics = %{$ARWconf{namelist}{physics}};  #  We'll need this too

    #---------------------------------------------------------------------------------------------
    #  The configuration of the fft_filter_lat parameter should be located in the 
    #  &Dynamics_GlobalDomain subroutine; however, when using a limited area lat-lon
    #  domain the value of fft_filter_lat must be to a value less than 90 because
    #  it's used in the source code.  Set to 89 degrees and forget it.
    #---------------------------------------------------------------------------------------------
    #
    @{$Dynamics{fft_filter_lat}} = (89.) if $Rconf{rtenv}{mproj} == 6 and $Domains{use_adaptive_time_step}[0] eq 'T';


    #---------------------------------------------------------------------------------------------
    # Make sure that DIFF_6TH_OPT is turned OFF for monotonic advection (2) due to heavy filtering
    #---------------------------------------------------------------------------------------------
    #
    my @advs = qw(moist_adv_opt scalar_adv_opt tke_adv_opt);
    foreach my $adv (@advs) {@{$Dynamics{diff_6th_opt}} = (0) x $Config{maxdoms} if $Dynamics{$adv}[0] == 2;}
    

    #---------------------------------------------------------------------------------------------
    #  The DIFF_OPT parameter comes with many caveats, which will hopefully be addressed here
    #  In most cases the configuration should be straight forward but that changes quickly
    #  when running a LES simulation.
    #
    #  The best approach for setting the value of DIFF_OPT (and other parameters) is to
    #  use the PBL scheme setting, where there are three possibilities:
    #
    #  1. The PBL scheme is being used for all domains
    #
    #     * sf_sfclay_physics = appropriate scheme (not 0)
    #     * diff_opt = 1 or 0 (global simulations)
    #     * isfflx   = 1 only
    #     * km_opt   = 0 (global), 1, or 4 (recommended)
    #  
    #  2. A Nested simulation where the PBL is turned OFF in child domain
    #
    #     * sf_sfclay_physics = 1 or 2 only (1 recommended)
    #     * diff_opt = 1 or 0 (domains with PBL) -> 2 (domains with No PBL)
    #     * isfflx   = 1 only (because non "max domain" variable and we need surface fluxes from surface layer)
    #     * km_opt   = 4 (recommended with DX > 500m) -> 2,3,4 (recommend 2 or 4 - strongly slopped terrain)
    #     * sfs_opt  = 0 when PBL ON; 0,1,2 when PBL OFF
    #
    #  3. The PBL scheme is turned OFF for all domains
    #
    #     * sf_sfclay_physics = 0, 1 or 2 only 
    #     * diff_opt = 2 only
    #     * isfflx   = 0 (sf_sfclay_physics=0), 1 or 2 (sf_sfclay_physics=1 or 2)
    #     * km_opt   = 2,3,4 (recommend 2 or 4 - strongly slopped terrain)
    #     * sfs_opt  = 0,1,2 
    #
    #  Notes:
    # 
    #  a. If diff_opt = 2  with PBL OFF
    #
    #     * Set mix_full_fields = T
    #     * Set damp_opt = 0,2,3 (not 1) Per README.namelist
    #      
    #  b. If km_opt = 2 or 3
    #
    #     * Set mix_isotropic = 1
    #     * set mix_upper_bound = value
    #     * Set sfs_opt = 0, 1, or 2
    #      
    #  c. If isfflx = 0 (idealized)
    #
    #     * Set tke_heat_flux (examples range from 0.02 to 0.24 K m/s)
    #     * Set tke_drag_coefficient
    #
    #     If isfflx = 2  (idealized)
    #
    #     * Set tke_heat_flux (examples range from 0.02 to 0.24 K m/s)
    #
    #  d. If km_opt = 1 (constant K values)
    #
    #     * Set damp_opt = 0
    #     * Set khdif
    #     * Set kvdif
    #---------------------------------------------------------------------------------------------
    #
    if ($Physics{bl_pbl_physics}[0] == 0) { #  PBL is turned OFF  for all domains


        # 1. Assign DIFF_OPT
        #
        @{$Dynamics{diff_opt}} = (2) x $Config{maxdoms};
       
 
        # 2. Assign ISFFLX
        #
        if ($Physics{sf_sfclay_physics}[0]) {
            # If sf_sfclay_physics != 0 then isfflx = 1 (recommended) or 2  
            #
            @{$Physics{isfflx}} = (1) unless $Physics{isfflx}[0] == 2;
        } else {
            # If sf_sfclay_physics = 0 then isfflx = 0
            #
            @{$Physics{isfflx}} = (0);  # If sf_sfclay_physics = 0 then isfflx = 0
        }


        # 3. Assign KM_OPT
        #
        @{$Dynamics{km_opt}}   = (2) unless grep {/^$Dynamics{km_opt}[0]$/} (2,4);
        @{$Dynamics{km_opt}}   = ($Dynamics{km_opt}[0])   x $Config{maxdoms};


        # 4. Assign MIX_FULL_FIELDS
        #
        @{$Dynamics{mix_full_fields}}   = ('T')   x $Config{maxdoms};


        # 5. Set SFS_OPT
        #
        @{$Dynamics{sfs_opt}}   =  &Config_sfs_opt();
        @{$Dynamics{sfs_opt}}   =  (1) if grep {/^3$/} @{$Dynamics{km_opt}} and $Dynamics{sfs_opt}[0];
        @{$Dynamics{sfs_opt}}   =  ($Dynamics{sfs_opt}[0]) x $Config{maxdoms};


    } elsif (grep {/^0$/} @{$Physics{bl_pbl_physics}}) {


        #  1. Assign DIFF_OPT:  Set diff_opt = 1|0 with PBL; otherwise 2
        #
        my $def = $Dynamics{diff_opt}[0] ? 1 : 0;
        for (0..$Config{maxindex}) {$Dynamics{diff_opt}[$_] = $Physics{bl_pbl_physics}[$_] ? $def : 2;}


        # 2. Assign ISFFLX
        #
        @{$Physics{isfflx}} = (1); # isfflx must be 1


        # 3. Assign KM_OPT
        #
        $def = ($Dynamics{km_opt}[-1] == 4) ? 4 : 2;  #  Last value should not be 0
        for (0..$Config{maxindex}) {$Dynamics{km_opt}[$_] = $Physics{bl_pbl_physics}[$_] ? 4 : $def;}


        # 4. Assign MIX_FULL_FIELDS
        #
        for (0..$Config{maxindex}) {$Dynamics{mix_full_fields}[$_] = $Physics{bl_pbl_physics}[$_] ? 'F' : 'T';}


        # 5. Assign SFS_OPT - Note that option 2 only available for km_opt = 2, while option 3 is available for km_opt = 2,3
        #
        @{$Dynamics{sfs_opt}}   =  &Config_sfs_opt();
        @{$Dynamics{sfs_opt}}   =  (1) if grep {/^3$/} @{$Dynamics{km_opt}} and $Dynamics{sfs_opt}[0];
        for (0..$Config{maxindex}) {$Dynamics{sfs_opt}[$_] = (grep {/^$Dynamics{km_opt}[$_]$/} (2,3)) ? $Dynamics{sfs_opt}[0] : 0;}


    } else { #  All PBL all the time!


        # 1. Assign DIFF_OPT
        #
        @{$Dynamics{diff_opt}} = ($Dynamics{diff_opt}[0]) x $Config{maxdoms};


        # 2. Assign ISFFLX
        #
        @{$Physics{isfflx}} = (1) if $Physics{isfflx}[0]; # isfflx must be 1 or 0


        # 3. Assign KM_OPT
        #
        my $def = (grep {/^$Dynamics{km_opt}[0]$/} (1,4)) ? $Dynamics{km_opt}[0] : 4;
        @{$Dynamics{km_opt}}   =  $Dynamics{diff_opt}[0]  ? ($def) x $Config{maxdoms} : (0)  x $Config{maxdoms}; 


    }


    #  Not sure when EPSSM is used but turn it on all the time
    #
    @{$Dynamics{epssm}}   = &Config_epssm();


    #  Set mix_isotropic & mix_upper_bound for km_opt = 2,3
    #
    if (grep {/^[2|3]$/} @{$Dynamics{km_opt}}) {
        @{$Dynamics{mix_isotropic}}   = &Config_mix_isotropic();   # Values to be ignored
        @{$Dynamics{mix_upper_bound}} = &Config_mix_upper_bound(); # Values to be ignored

        #  Both mix_isotropic & mix_upper_bound are max domain variables whos values
        #  should be ON when km_opt = 2 or 3. Note that when going PBL -> No PBL km_opt
        #  may not be 2|3 for all domains.
        #
        for (0..$Config{maxindex}) {
            $Dynamics{mix_isotropic}[$_]   = ($Dynamics{km_opt}[$_] == 2 or $Dynamics{km_opt}[$_] == 3) ? 1 : 0;
            $Dynamics{mix_upper_bound}[$_] = ($Dynamics{km_opt}[$_] == 2 or $Dynamics{km_opt}[$_] == 3) ? 1 : 0;
        }
    }

    #  Set khdif & kvdif for km_opt = 1
    #
    @{$Dynamics{khdif}}    = &Config_khdif()    if grep {/^1$/} @{$Dynamics{km_opt}};
    @{$Dynamics{kvdif}}    = &Config_kvdif()    if grep {/^1$/} @{$Dynamics{km_opt}};


    #  For isfflx = 0,2 set tke_heat_flux & tke_drag_coefficient (0)
    #
    @{$Dynamics{tke_heat_flux}}        = &Config_tke_heat_flux()        if grep {/^$Physics{isfflx}[0]$/} (0,2);
    @{$Dynamics{tke_drag_coefficient}} = &Config_tke_drag_coefficient() if grep {/^$Physics{isfflx}[0]$/} (0);


return;
}


sub ConfigFinal_Damping {
# ==================================================================================
#  This routine handles any final configuration checks for vertical damping
#  scheme that could not be done previously due to dependencies that had
#  not been resolved. Boilerplate stuff - just like this text and that above.
#
#  A few rules:
#
#      1. if diff_opt = 2 then damp_opt != 1        (Set damp_opt = 0)
#      2. if mix_full_fields = T then damp_opt != 1 (Covered by #1)
# ==================================================================================
#
    #  We know from namelist.README that DAMP_OPT can not be 1 if DIFF_OPT = 2
    #
    @{$Dynamics{damp_opt}} = (0) if $Dynamics{damp_opt}[0] == 1 and grep {/^2$/} @{$Dynamics{diff_opt}};


return;
}


sub ConfigFinal_GravityWaveDrag {
# ==================================================================================
#  This routine handles any final configuration checks for the gravity wave
#  drag scheme that could not be done previously due to dependencies that 
#  had not been resolved.
# ==================================================================================
#
    return unless $Dynamics{gwd_opt}[0];

    my $mesg    = qw{};
    my %Physics = %{$ARWconf{namelist}{physics}};  #  We'll need this

    #  Per module_check_a_mundo.F (V3.7) The GWD option only works with YSU & MYNN PBL
    #
    unless (grep {/^$Physics{bl_pbl_physics}[0]$/} (1,5,6)) {
        $mesg = "The Gravity Wave Drag option only works with the YSU & MYNN PBL schemes.  Rather than take ".
                "matters into my own hands, I will delegate the authority to correct this problem to you.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Take this bull^#&! by the horns!',$mesg);
        return 1;
    }


    #  Make sure the domain DX and simulation length is appropriate for GWD usage.
    #
    my $dx = $Rconf{dinfo}{domains}{1}{dx};
    my $l  = $Rconf{dinfo}{domains}{1}{length};

    if ($dx < 10000. or $l < 86400) {  #  Recommendation is 5 days but we'll say 1
        my $lstr = &Ecomm::FormatTimingString($l);
        my $dstr = sprintf '%.1f', 0.001*$dx; $dx = "$dx kilometers";
        $mesg = "Your simulation configuration includes the Gravity Wave Drag option turned ON ".
                "with a primary domain grid spacing of $dstr and a simulation length of $lstr. ".
                "If you recall from the user guide, the Gravity Wave Drag scheme should be limited ".
                "to a grid spacing of 10km or greater and simulation lengths longer than 5 days.\n\n".

                "Since the EMS is more powerful than you, the GWD option will be turned OFF until you ".
                "learn to play by the rules.";
         &Ecomm::PrintMessage(6,11+$Rconf{arf},88,1,2,"You're Busted:",$mesg);
         @{$Dynamics{gwd_opt}} = (0);
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

    foreach my $parm (keys %Dynamics) {
        next unless $Config{parmkeys}{$parm}{maxdoms} > 1;
        next unless @{$Dynamics{$parm}} == $Config{maxdoms};
        foreach (@ndoms) {$Dynamics{$parm}[$_-1] = $Dynamics{$parm}[$Config{parentidx}[$_]-1];}
    }

return;
}


sub Config_khdif {
# ==================================================================================
#   Option:  KHDIF - Value of horizontal diffusion in m^2/s.
#
#   Notes:   KHDIF is only used with KM_OPT = 1
#
#   Default: KHDIF = 0
# ==================================================================================
#
    my @khdif = @{$Config{uconf}{KHDIF}};


return @khdif;
}


sub Config_kvdif {
# ==================================================================================
#   Option:  KVDIF - Value of vertical diffusion in m^2/s.
#
#   Notes:   KVDIF is only used with KM_OPT = 1
#
#   Default: KVDIF = 0
# ==================================================================================
#
    my @kvdif = @{$Config{uconf}{KVDIF}};


return @kvdif;
}


sub Config_sfs_opt {
# ==================================================================================
#  Option: SFS_OPT - Nonlinear Backscatter Anisotropic (NBA)
#
#    Sub-grid turbulent stress option for momentum in LES applications.
#
#    Options for sfs_opt are:
#
#      0 - NBA turned OFF - just like the lockout
#      1 - Diagnostic sub-grid stress to be used with diff_opt = 2 and km_opt = 2 or 3
#      2 - TKE sub-grid stress to be used with diff_opt = 2 and km_opt = 2.
#
#  Default: SFS_OPT = 0 (OFF) For all domains
# ==================================================================================
#
    my @sfs_opt = @{$Config{uconf}{SFS_OPT}};

return @sfs_opt;
}


sub Config_tke_drag_coefficient {
# ==================================================================================
#   Option:  TKE_DRAG_COEFFICIENT - Surface drag coefficient (Cd, dimensionless)
#
#   Notes:   TKE_DRAG_COEFFICIENT is used with DIFF_OPT = 2 only
#
#   Default: TKE_DRAG_COEFFICIENT = 0.001
# ==================================================================================
#
    my @tke_drag_coefficient = @{$Config{uconf}{TKE_DRAG_COEFFICIENT}};


return @tke_drag_coefficient;
}


sub Config_tke_heat_flux {
# ==================================================================================
#   Option:  TKE_HEAT_FLUX - Surface thermal flux (H/(rho*cp), K m/s)
#
#   Notes:   TKE_HEAT_FLUX is used with DIFF_OPT = 2 only
#   
#   Default: TKE_HEAT_FLUX = 0.01
# ==================================================================================
#
    my @tke_heat_flux = @{$Config{uconf}{TKE_HEAT_FLUX}};

return @tke_heat_flux;
}


sub Config_mix_full_fields {
# ==================================================================================
#   Option:  MIX_FULL_FIELDS - Whether to mix full fields
#
#   Values:
#
#      T - Go ahead and mix full fields  (your only real option)
#      F - subtract 1-D base state before mixing (Idealized only!)
#
#   Notes:   MIX_FULL_FIELDS is only used with DIFF_OPT = 2 & DAMP_OPT ! = 1
#
#   Default: MIX_FULL_FIELDS = T
# ==================================================================================
#
    my @mix_full_fields = @{$Config{uconf}{MIX_FULL_FIELDS}};


return @mix_full_fields;
}


sub Config_epssm {
# ==================================================================================
#   Option:  EPSSM - Time off-centering for vertical sound waves (sound wave damper)
#
#   Notes:   Used with DIFF_OPT, although may only be with DIFF_OPT = 2
#
#            Value of EPSSM may need to be increased to 0.5 or greater to improve 
#            stability.
#
#   Default: EPSSM = 0.1
# ==================================================================================
#
    my @epssm = @{$Config{uconf}{EPSSM}};

return @epssm;
}


sub Config_mix_upper_bound {
# ==================================================================================
#   Option:  MIX_UPPER_BOUND - Non-dimensional upper limit for diffusion coeffs
#
#   Notes:   MIX_UPPER_BOUND is used with KM_OPT = 2 or 3 only
#
#   Default: MIX_UPPER_BOUND = 0.1
# ==================================================================================
#
    my @mix_upper_bound = @{$Config{uconf}{MIX_UPPER_BOUND}};

return @mix_upper_bound;
}


sub Config_mix_isotropic {
# ==================================================================================
#   Option: MIX_ISOTROPIC - Anistropic vertical/horizontal diffusion coeffs
#                           Set to 1 if DX =~ DZ
#
#   Values:
#           0 - ON
#           1 - OFF
#
#   Notes:  If subroutine is being called assume set to 1
# ==================================================================================
#
    my @mix_isotropic = (1);

return @mix_isotropic;
}


sub Config_fft_filter_lat {
# ==================================================================================
#   Option:  FFT_FILTER_LAT - Latitude at which to initiate FFT (Global Only)
#
#   Notes:   FFT_FILTER_LAT is the latitude at which the FFT routines begin
#            to filter out high-frequency waves when running over global domain.
#            Again, this value is only applicable to global domain runs.
#
#            Setting this value to 90. (degrees) will eliminate FFT filtering
#            and probably cause your simulation to crash due to CFL violations
#            unless your time step is unreasonably small. The value will be
#            ignored for limited area domains EXCEPT for lat-lon domains when
#            the adaptive time step is turned ON, in which event the value
#            will be set to 89. degrees internally within the UEMS.
#
#   Default: FFT_FILTER_LAT = 45. (Global Domains)
#            FFT_FILTER_LAT = 89. (Regional Lat-Lon domains with adaptive timestep ON
# ==================================================================================
#
    my @fft_filter_lat = @{$Config{uconf}{FFT_FILTER_LAT}};

return @fft_filter_lat;
}


sub Config_coupled_filtering {
# ==================================================================================
#  Option: COUPLED_FILTERING - The mu coupled scalar arrays are run through 
#          the polar filters
#
#  Default: COUPLED_FILTERING = T
# ==================================================================================
#
    my @coupled_filtering = @{$Config{uconf}{COUPLED_FILTERING}};

return @coupled_filtering;
}


sub Config_pos_def {
# ==================================================================================
#   Option:  POS_DEF - T/F remove negative values of scalar arrays by setting 
#            minimum value to zero
#
#   Default: POS_DEF = T
# ==================================================================================
#
    my @pos_def = @{$Config{uconf}{POS_DEF}};

return @pos_def;
}


sub Config_swap_pole_with_next_j {
# ==================================================================================
#  Option: SWAP_POLE_WITH_NEXT_J - Replace the entire j=1 (jds-1) with the values 
#          from j=2 (jds-2)
#
#  Default: SWAP_POLE_WITH_NEXT_J = F
# ==================================================================================
#
    my @swap_pole_with_next_j = @{$Config{uconf}{SWAP_POLE_WITH_NEXT_J}};

return @swap_pole_with_next_j;
}


sub Config_actual_distance_average {
# ==================================================================================
#  Option: ACTUAL_DISTANCE_AVERAGE - Average the field at each i location in the 
#          j-loop with a number of grid points based on a map-factor ratio
#
#  Default: ACTUAL_DISTANCE_AVERAGE = F
# ==================================================================================
#
    my @actual_distance_average = @{$Config{uconf}{ACTUAL_DISTANCE_AVERAGE}};

return @actual_distance_average;
}


sub Config_base_temp {
# ==================================================================================
#  Option: BASE_TEMP - real-data, em ONLY, base sea-level temp (K)
#
#  Notes:  From: http://www2.mmm.ucar.edu/wrf/users/namelist_best_prac_wrf.html#base_temp
#
#          This option can help to improve simulations when the model top is higher 
#          than 20 km (~50 mb). Note: This option is only available for real data, 
#          em-only. This is a representative temperature at sea-level in the middle of 
#          your domain, regardless of the topography height at that point. Typical 
#          values range from 270-300 K. This value must stay the same through 
#          initialization, model runs, and restarts.
#
#  Default: BASE_TEMP = 290.
# ==================================================================================
#
    my @base_temp = @{$Config{uconf}{BASE_TEMP}};

return @base_temp;
}


sub Dynamics_Debug {
# ==============================================================================================
# &DYNAMICS NAMELIST DEBUG ROUTINE
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  When the --debug 4+ flag is passed, prints out the contents of the WRF &dynamics
#  namelist section.
#
# ==============================================================================================
# ==============================================================================================
#   
    my @defvars  = ();
    my @ndefvars = ();
    my $nlsect   = 'dynamics'; #  Specify the namelist section to print out

    return unless $ENV{RUN_DBG} > 3;  #  Only for --debug 4+

    foreach (@{$ARWconf{nlorder}{$nlsect}}) {
        defined $Dynamics{$_} ? push @defvars => $_ : push @ndefvars => $_;
    }

    return unless @defvars or @ndefvars;

    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,13+$Rconf{arf},144,1,1,'Leaving &ARWdynamics');
 
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-24s  = %s',$_,join ', ' => @{$Dynamics{$_}})) foreach @defvars;
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,' ');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-24s  = %s',$_,'Not Used')) foreach @ndefvars;
    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,2,'=' x 72);
       


return;
}


