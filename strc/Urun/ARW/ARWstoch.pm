#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ARWstoch.pm
#
#  DESCRIPTION:  This module handles the configuration of the &stoch namelist 
#                options for the ARW core. 
#
#   WHAT THE WRF
#   GUIDE SAYS:  WRF has an option to stochastically perturb forecasts via a 
#                stochastic kinetic-energy backscatter scheme (SKEBS; Shutts, 
#                2005, QJRMS). The scheme introduces temporally and spatially 
#                correlated perturbations to the rotational wind components u, 
#                v, and potential temperature θ. An application and verification 
#                of this scheme to mesoscale ensemble forecast in the mid-latitudes 
#                is available in Berner et. al, 2011, Monthly Weather Review, 139, 
#                1972—1995 (http://journals.ametsoc.org/doi/abs/10.1175/2010MWR3595.1).
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package ARWstoch;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Rconf %Config %ARWconf %Stoch);

use Others;


sub Configure {
# ==============================================================================================
# &STOCH NAMELIST CONFIGURATION DIVER
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Each subroutine controls the configuration for the somewhat crudely organized namelist
#  variables. Should there be a serious problem an empty hash is returned (not really).
#  Not all namelist variables are configured as some do not require anything beyond the
#  default settings. The %Stoch hash is only used within this module to reduce the number
#  of characters being cut-n-pasted.
#
# ==============================================================================================
# ==============================================================================================
#   
    %Config = %ARWconfig::Config;
    %Rconf  = %ARWconfig::Rconf;

    my $href = shift; %ARWconf = %{$href};

    return () if &Stochastic_Control(); 
    return () if &Stochastic_Debug();

    %{$ARWconf{namelist}{stoch}}  = %Stoch;


return %ARWconf;
}


sub Stochastic_Control {
# ==============================================================================================
# WRF &STOCH NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?   PERTURBS YOUR WORLD, BABY!
#
#   FROM THE ARW USER GUIDE AND OTHER LESS REPUTABLE SOURCES (WRF V3.7):
#
#     About Stochastic kinetic-energy backscatter scheme (SKEBS)
#
#        The scheme introduces temporally and spatially correlated perturbations to the
#        rotational wind components u, v, and potential temperature θ. An application and
#        verification of this scheme to mesoscale ensemble forecast in the mid-latitudes
#        is available in Berner et. al, 2011, Monthly Weather Review, 139, 1972—1995.
#
#        SKEBS generates perturbation tendency fields ru_tendf_stoch (in m2/s3),
#        rv_tendf_stoch (m2/s3), rt_tendf_stoch (K/s2) for u,v and θ, respectively.
#
#        For new applications we recommend to output the magnitude and spatial patterns
#        of these perturbation fields and compare them to the physics tendency fields
#        for the same variables.  Within the scheme, these perturbation fields are then
#        coupled to mass and added to physics tendencies of u,v, and θ. The stochastic
#        perturbations fields for wind and temperature are controlled by the kinetic
#        and potential energy they inject into the flow. The injected energy is expressed
#        as backscattered dissipation rate for streamfunction and temperature respectively.
#
#        Since the scheme uses Fast Fourier Transforms (FFTs) provided in the library FFTPACK,
#        we recommend the number of gridpoints in each direction to be product of small primes.
#        If the number of gridpoints is a large prime in at least one of the directions, the
#        computational cost may increase substantially. Multiple domains are supported by
#        interpolating the forcing from the largest domain for which the scheme is turned on
#        (normally the parent domain) down to all nested domain.
#
#        At present, default settings for the scheme have been thoroughly tested on synoptic
#        and meso-scale domains over the mid-latitudes and as such offer a starting point.
#        Relationships between backscatter amplitudes and perturbation fields for a given
#        variable are not necessarily proportional due to the complexity of the scheme.
#
#        Users wishing to adjust default settings are strongly advised to read details
#        in the technical document available at http://www.cgd.ucar.edu/~berner/skebs.html,
#        which also contains details on version history, derivations, and examples.
#
#        Further documentation is available at http://www.cgd.ucar.edu/~berner/skebs.html
#
#        This scheme is controlled via the following physics namelist parameters (maxdomains):
#
#          *  skebs               - Stochastic kinetic-energy backscatter scheme (ON|OFF)
#          *  nens                - Controls random number stream
#          *  skebs_vertstruc     - Structure of random pattern generator
#          *  tot_backscat_psi    - Controls amplitude of rotational wind perturbations
#          *  tot_backscat_t      - Controls amplitude of potential temperature perturbations
#          *  ztau_psi            - Decorrelation time (s) for streamfunction perturbations
#          *  ztau_t              - Decorrelation time (s) for potential temperature perturbations
#          *  rexponent_psi       - Spectral slope for streamfunction perturbations
#          *  rexponent_t         - Spectral slope for potential temperature perturbations
#          *  kminforc            - Minimal forcing wavenumber in longitude for streamfunction perturbations
#          *  lminforc            - Minimal forcing wavenumber in latitude for streamfunction perturbations
#          *  kminforct           - Minimal forcing wavenumber in longitude for potential temperature perturbations
#          *  lminforct           - Minimal forcing wavenumber in latitude for potential temperature perturbations
#          *  kmaxforc            - Maximal forcing wavenumber in longitude for streamfunction perturbations
#          *  lmaxforc            - Maximal forcing wavenumber in latitude for streamfunction perturbations
#          *  kmaxforct           - Maximal forcing wavenumber in longitude for potential temperature perturbations
#          *  lmaxforct           - Maximal forcing wavenumber in latitude for potential temperature perturbations
#          *  zsigma2_eps         - Noise variance in autoregressive process defining streamfunction perturbations
#          *  zsigma2_eta         - Noise variance in autoregressive process defining potential temperature perturbations
#          *  perturb_bdy         - Add perturbations to the boundary tendencies for u- and v-wind components
# ==============================================================================================
#
    %Stoch  = ();

    @{$Stoch{skebs}}       = &Config_skebs();

    if ($Stoch{skebs}[0]) {

        @{$Stoch{nens}}             = &Config_nens();
        @{$Stoch{iseed_skebs}}      = &Config_iseed_skebs();
        @{$Stoch{skebs_vertstruc}}  = &Config_skebs_vertstruc();
        @{$Stoch{tot_backscat_psi}} = &Config_tot_backscat_psi();
        @{$Stoch{tot_backscat_t}}   = &Config_tot_backscat_t();
        @{$Stoch{ztau_psi}}         = &Config_ztau_psi();
        @{$Stoch{ztau_t}}           = &Config_ztau_t();
        @{$Stoch{rexponent_psi}}    = &Config_rexponent_psi();
        @{$Stoch{rexponent_t}}      = &Config_rexponent_t();
        @{$Stoch{kminforc}}         = &Config_kminforc();
        @{$Stoch{lminforc}}         = &Config_lminforc();
        @{$Stoch{kminforct}}        = &Config_kminforct();
        @{$Stoch{lminforct}}        = &Config_lminforct();
        @{$Stoch{kmaxforc}}         = &Config_kmaxforc();
        @{$Stoch{lmaxforc}}         = &Config_lmaxforc();
        @{$Stoch{kmaxforct}}        = &Config_kmaxforct();
        @{$Stoch{lmaxforct}}        = &Config_lmaxforct();
        @{$Stoch{zsigma2_eps}}      = &Config_zsigma2_eps();
        @{$Stoch{zsigma2_eta}}      = &Config_zsigma2_eta();

        &Stoch_Check4LargePrimes();

    }

    @{$Stoch{perturb_bdy}} = &Config_perturb_bdy();


return;
}


#
# ==================================================================================
# ==================================================================================
#      SO BEGINS THE INDIVIDUAL PARAMETER CONFIGURATION SUBROUTINES
# ==================================================================================
# ==================================================================================
#

sub Config_skebs {
# ==================================================================================
#  Option:  SKEBS - Stochastic kinetic-energy backscatter scheme (SKEBS)
#
#  Values: 
#           0 - No stochastic parameterization 
#           1 - Use SKEBS stochastic parameterization
#
#  Default: SKEBS = 0 (OFF)
# ==================================================================================
#
    my @skebs = @{$Config{uconf}{SKEBS}};

return @skebs;
}


sub Config_nens {
# ==================================================================================
#  Option:  NENS - Seed for random number stream for both stochastic schemes. 
#
#  Notes:   For ensemble forecasts this parameter needs to be different for each 
#           member. The seed is a function of initial start time to ensure different 
#           random number streams for forecasts starting from different initial times.
#
#  Default: NENS = Random integer 1 .. 99
# ==================================================================================
#
    my @nens = @{$Config{uconf}{NENS}};

return @nens;
}


sub Config_iseed_skebs {
# ==================================================================================
#  Option:  ISEED_SKEBS - Seed for random number stream for skebs. 
#
#  Notes:   Will be combined with seed nens signifying ensemble member number and 
#           initial start time to ensure different random number streams for 
#           forecasts starting from different initial times and for different 
#           ensemble members.
#
#  Default: ISEED_SKEBS = Random integer 1 .. 999
# ==================================================================================
#
    my @iseed_skebs = @{$Config{uconf}{ISEED_SKEBS}};

return @iseed_skebs;
}


sub Config_skebs_vertstruc {
# ==================================================================================
#  Option:  SKEBS_VERTSTRUC - Defines the vertical structure of the random 
#                             pattern generator
#  
#  Values:  
#           0 - Constant vertical structure of random pattern generator
#           1 - Random phase vertical structure with westward tilt
#  
#  Default: SKEBS_VERTSTRUC = 1
# ==================================================================================
#
    my @skebs_vertstruc = @{$Config{uconf}{SKEBS_VERTSTRUC}};

return @skebs_vertstruc;
}


sub Config_tot_backscat_psi {
# ==================================================================================
#  Option:  TOT_BACKSCAT_PSI - Total backscattered streamfunction dissipation rate
#
#  Notes:   Controls amplitude of rotational wind perturbations.
#
#  Default: TOT_BACKSCAT_PSI = 1.0E-5 (m2/s3)
# ==================================================================================
#
    my @tot_backscat_psi = @{$Config{uconf}{TOT_BACKSCAT_PSI}};

return @tot_backscat_psi;
}


sub Config_tot_backscat_t {
# ==================================================================================
#  Option:  TOT_BACKSCAT_T - Total backscattered potential temperature dissipation rate
#
#  Notes:   Controls amplitude of potential temperature perturbations.
#
#  Default: TOT_BACKSCAT_T = 1.0E-6 (m2/s3)
# ==================================================================================
#
    my @tot_backscat_t = @{$Config{uconf}{TOT_BACKSCAT_T}};

return @tot_backscat_t;
}


sub Config_ztau_psi {
# ==================================================================================
#  Option:  ZTAU_PSI - Decorrelation time (s) for streamfunction perturbations. 
#
#  Default: ZTAU_PSI =  10800 (s)
# ==================================================================================
#
    my @ztau_psi = @{$Config{uconf}{ZTAU_PSI}};

return @ztau_psi;
}


sub Config_ztau_t {
# ==================================================================================
#  Option:  ZTAU_T - Decorrelation time (s) for potential temperature perturbations. 
#
#  Default: ZTAU_T =  10800 (s)
# ==================================================================================
#
    my @ztau_t = @{$Config{uconf}{ZTAU_T}};

return @ztau_t;
}


sub Config_rexponent_psi {
# ==================================================================================
#  Option:  REXPONENT_PSI - Spectral slope for streamfunction perturbations.
#
#  Values:  Default is -1.83 for a kinetic-energy forcing spectrum with slope -5/3.
#
#  Default: REXPONENT_PSI = -1.83
# ==================================================================================
#
    my @rexponent_psi = @{$Config{uconf}{REXPONENT_PSI}};

return @rexponent_psi;
}


sub Config_rexponent_t {
# ==================================================================================
#  Option:  REXPONENT_T - Spectral slope for potential temperature perturbations.
#
#  Values:  Default is -1.83 for a kinetic-energy forcing spectrum with slope -5/3.
#
#  Default: REXPONENT_T = -1.83
# ==================================================================================
#
    my @rexponent_t = @{$Config{uconf}{REXPONENT_T}};

return @rexponent_t;
}


sub Config_kminforc {
# ==================================================================================
#  Option:  KMINFORC - Minimal forcing wavenumber in longitude for streamfunction perturbations
#  
#  Default: KMINFORC = 1
# ==================================================================================
#
    my @kminforc = @{$Config{uconf}{KMINFORC}};

return @kminforc;
}


sub Config_lminforc {
# ==================================================================================
#  Option:  LMINFORC - Minimal forcing wavenumber in latitude for streamfunction perturbations
#  
#  Default: LMINFORC = 1
# ==================================================================================
#
    my @lminforc = @{$Config{uconf}{LMINFORC}};

return @lminforc;
}


sub Config_kminforct {
# ==================================================================================
#  Option:  KMINFORCT - Minimal forcing wavenumber in longitude for potential temperature perturbations
#  
#  Default: KMINFORCT = 1
# ==================================================================================
#
    my @kminforct = @{$Config{uconf}{KMINFORCT}};

return @kminforct;
}


sub Config_lminforct {
# ==================================================================================
#  Option:  LMINFORCT - Minimal forcing wavenumber in latitude for potential temperature perturbations
#  
#  Default: LMINFORCT = 1
# ==================================================================================
#
    my @lminforct = @{$Config{uconf}{LMINFORCT}};

return @lminforct;
}


sub Config_kmaxforc {
# ==================================================================================
#  Option:  KMAXFORC - Maximal forcing wavenumber in longitude for streamfunction 
#                      perturbations
#  
#  Default: KMAXFORC = Default is maximal possible wavenumbers determined by 
#                      number of gridpoints in longitude.
# ==================================================================================
#
    my @kmaxforc = @{$Config{uconf}{KMAXFORC}};

return @kmaxforc;
}


sub Config_lmaxforc {
# ==================================================================================
#  Option:  LMAXFORC - Maximal forcing wavenumber in latitude for streamfunction 
#                      perturbations
#  
#  Default: LMAXFORC = Default is maximal possible wavenumbers determined by 
#                      number of gridpoints in latitude.
# ==================================================================================
#
    my @lmaxforc = @{$Config{uconf}{LMAXFORC}};

return @lmaxforc;
}


sub Config_kmaxforct {
# ==================================================================================
#  Option:  KMAXFORCT - Maximal forcing wavenumber in longitude for potential 
#                       temperature perturbations
#  
#  Default: KMAXFORCT = Default is maximal possible wavenumbers determined by 
#                       number of gridpoints in longitude.
# ==================================================================================
#
    my @kmaxforct = @{$Config{uconf}{KMAXFORCT}};

return @kmaxforct;
}


sub Config_lmaxforct {
# ==================================================================================
#  Option:  LMAXFORCT - Maximal forcing wavenumber in latitude for potential 
#                       temperature perturbations
#  
#  Default: LMAXFORCT = Default is maximal possible wavenumbers determined by 
#                       number of gridpoints in latitude.
# ==================================================================================
#
    my @lmaxforct = @{$Config{uconf}{LMAXFORCT}};

return @lmaxforct;
}


sub Config_zsigma2_eps {
# ==================================================================================
#  Option:  ZSIGMA2_EPS - Noise variance in autoregressive process defining 
#                         streamfunction perturbations.
#  
#  Default: ZSIGMA2_EPS = 0.833
# ==================================================================================
#
    my @zsigma2_eps = @{$Config{uconf}{ZSIGMA2_EPS}};

return @zsigma2_eps;
}


sub Config_zsigma2_eta {
# ==================================================================================
#  Option:  ZSIGMA2_ETA - Noise variance in autoregressive process defining 
#                         potential temperature perturbations.
#  
#  Default: ZSIGMA2_ETA = 0.833
# ==================================================================================
#
    my @zsigma2_eta = @{$Config{uconf}{ZSIGMA2_ETA}};

return @zsigma2_eta;
}


sub Config_perturb_bdy {
# ==================================================================================
#  Option:  PERTURB_BDY - Add perturbations to the boundary tendencies for u- and 
#                         v-wind components and potential temperature in WRF stand-
#                         alone runs.
#
#  Notes:   The perturb_bdy option runs independently of SKEBS and as such may be 
#           run with or without the SKEB scheme, which operates solely on the 
#           interior grid.  However, selecting perturb_bdy=1 will require the 
#           generation of a domain-size random array, thus computation time may 
#           increase. 
#  
#  Values:
#           0 - No boundary perturbations (default)
#           1 - Use SKEBS pattern for boundary perturbations
#           2 - User provided pattern for boundary perturbations (not UEMS supported)
#  
#  Default: PERTURB_BDY = 0
# ==================================================================================
#
    my @perturb_bdy = @{$Config{uconf}{PERTURB_BDY}};

return @perturb_bdy;
}


sub Stoch_Check4LargePrimes { 
# ==================================================================================
#  Check if the primary domain array dimension in either direction is the product
#  of a large prime. How large is "large"? I don't know, so a warning will be 
#  provided should a factor exceed 101, which may need to be changed.
# ==================================================================================
#
use List::Util 'max';

    my $ngx_mpf = max &Others::GetPrimeFactors($Rconf{dinfo}{domains}{1}{nx});
    my $ngy_mpf = max &Others::GetPrimeFactors($Rconf{dinfo}{domains}{1}{ny});

    if ($ngx_mpf > 101 or $ngy_mpf > 101) {
        my $mesg = "\"Since the scheme uses Fast Fourier Transforms (FFTs) provided in the library FFTPACK, ".
                   "we recommend the number of grid points in each direction to be product of small primes. ".
                   "If the number of grid points is a large prime in at least one of the directions, the ".
                   "computational cost may increase substantially.\" - Word!\n\n".

                   "The largest prime number factor for your primary domain in the NX direction is $ngx_mpf and ".
                   "$ngy_mpf in the NY direction.  Since no other guidance is provided, the UEMS Godfather ".
                   "decided to provide this potentially meaningless warning about your domain grid dimensions ".
                   "when using SKEBS.\n\n".

                   "Modeler discretion is advised.";

        &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,"From the SKEBS section of the WRF User's Guide:",$mesg);
    }

return;
} 
sub Stochastic_Debug {
# ==============================================================================================
# &STOCH NAMELIST DEBUG ROUTINE
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  When the --debug 4+ flag is passed, prints out the contents of the WRF &stoch namelist section.
#
# ==============================================================================================
# ==============================================================================================
#   
    my @defvars  = ();
    my @ndefvars = ();
    my $nlsect   = 'stoch'; #  Specify the namelist section to print out

    return unless $ENV{RUN_DBG} > 3;  #  Only for --debug 4+

    foreach my $tcvar (@{$ARWconf{nlorder}{$nlsect}}) {
        defined $Stoch{$tcvar} ? push @defvars => $tcvar : push @ndefvars => $tcvar;
    }

    return unless @defvars or @ndefvars;

    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,13+$Rconf{arf},144,1,1,'Leaving &ARWstoch');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-24s  = %s',$_,join ', ' => @{$Stoch{$_}})) foreach @defvars;
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,' ');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-24s  = %s',$_,'Not Used')) foreach @ndefvars;
    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,2,'=' x 72);
       

return;
}


