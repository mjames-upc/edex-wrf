#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ARWdfi.pm
#
#  DESCRIPTION:  This module handles the configuration of the &dfi_control namelist 
#                options for the ARW core. 
#
#   WHAT THE WRF
#   GUIDE SAYS:  Digital filter initialization
#
#                Digital filter initialization (DFI) is is a way to remove initial 
#                model imbalance as, for example, measured by the surface pressure 
#                tendency. This option might be important when one is interested in
#                the 0–6 hour simulation or forecast.
#
#                It runs a digital filter during a short model integration, backward 
#                and forward. and then starts the forecast. In WRF implementation, 
#                this is all done in a single job and may be used with for multiple
#                domains with concurrent nesting and feedback disabled.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package ARWdfi;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Rconf %Config %ARWconf %DFI);

use Others;


sub Configure {
# ==============================================================================================
# &DFI_CONTROL NAMELIST CONFIGURATION DIVER
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Each subroutine controls the configuration for the somewhat crudely organized namelist
#  variables. Should there be a serious problem an empty hash is returned (not really).
#  Not all namelist variables are configured as some do not require anything beyond the
#  default settings. The %TimeControl hash is only used within this module to reduce the
#  number of characters being cut-n-pasted.
#
# ==============================================================================================
# ==============================================================================================
#   
    %Config = %ARWconfig::Config;
    %Rconf  = %ARWconfig::Rconf;

    my $href = shift; %ARWconf = %{$href};

    return () if &DFI_Control();
    return () if &DFI_Debug();

    %{$ARWconf{namelist}{dfi_control}} = %DFI;


return %ARWconf;
}


sub DFI_Control {
# ==============================================================================================
# WRF PRIMARY IO &DFI_CONTROL NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This file contains the parameters necessary to use Digital Filter Initialization (DFI)
#   at the start of your simulation. DFI allows for the reduction in the model "spin-up"
#   time during the early stages of integration due to a mass/momentum imbalance in the
#   in the initial conditions.
#
#   Note that the use of DFI can increase the computational time of your model run sig-
#   nificantly, so use this option wisely. Also testing has been limited so there are
#   few promises as to whether this option will work as advertised. See the PDF file(s)
#   in the ems/docs directory for more fun facts about what DFI can do for you.
#
# PROCURED FROM THE ARW USERS GUIDE:
#
#   "Digital filter initialization (DFI) is a new option in V3. It is a way to remove
#    initial model imbalance as, for example, measured by the surface pressure tendency.
#    This might be important when one is interested in the 0-6 hour simulation or fore-
#    cast. It runs a digital filter during a short model integration, backward and for-
#    ward, and then starts the simulation. In the WRF, this is all done in a single job.
#    In the WRF implementation, this is all done in a single job. In the current version,
#    DFI can be used for multiple domains with concurrent nesting, with feedback disabled.
#
#    NOTE: You can not use DFI with fdda analysis or spectral nudging because bad things
#          will happen to good simulations, like yours.
#
#    ALSO: time_step_dfi is not calculated in this module look in &Domains_Timestep
#
#    Info:  Per module_check_a_mundo.F (V3.7) The DFI option does NOT work with TEMF PBL
#
# ==============================================================================================
# ==============================================================================================
#

    @{$DFI{dfi_opt}} =  &Config_dfi_opt();

    if ($DFI{dfi_opt}[0]) {  #  DFI it turned ON

        @{$DFI{dfi_radar}}                =  &Config_dfi_radar();
        @{$DFI{dfi_nfilter}}              =  &Config_dfi_nfilter();
        @{$DFI{dfi_time_dim}}             =  &Config_dfi_time_dim();
        @{$DFI{dfi_cutoff_seconds}}       =  &Config_dfi_cutoff_seconds();
        @{$DFI{dfi_write_dfi_history}}    =  &Config_dfi_write_dfi_history();
        @{$DFI{dfi_write_filtered_input}} =  &Config_dfi_write_filtered_input();

        #  At this point we need to calculate the fwdstop and backstop dates and then 
        #  split the string for the &dfi_control parameters.
        #
        my $sdate    = $Rconf{dinfo}{domains}{1}{sdate};  #  Simulation start date

        my $backstop = &Config_dfi_backstop();
        my $bsdate   = &Others::CalculateNewDate(&Others::DateStringWRF2DateString($sdate),$backstop);

        my $fwdstop  = &Config_dfi_fwdstop();
        my $fsdate   = &Others::CalculateNewDate(&Others::DateStringWRF2DateString($sdate),$fwdstop);

        my ($yr, $mo, $dy, $hr, $mn, $ss) = &Others::DateString2DateList($bsdate);

        @{$DFI{dfi_bckstop_year}}         = ($yr);
        @{$DFI{dfi_bckstop_month}}        = ($mo);
        @{$DFI{dfi_bckstop_day}}          = ($dy);
        @{$DFI{dfi_bckstop_hour}}         = ($hr);
        @{$DFI{dfi_bckstop_minute}}       = ($mn);
        @{$DFI{dfi_bckstop_second}}       = ($ss);

        ($yr, $mo, $dy, $hr, $mn, $ss) = &Others::DateString2DateList($fsdate);
         
        @{$DFI{dfi_fwdstop_year}}         = ($yr);
        @{$DFI{dfi_fwdstop_month}}        = ($mo);
        @{$DFI{dfi_fwdstop_day}}          = ($dy);
        @{$DFI{dfi_fwdstop_hour}}         = ($hr);
        @{$DFI{dfi_fwdstop_minute}}       = ($mn);
        @{$DFI{dfi_fwdstop_second}}       = ($ss);

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

sub Config_dfi_opt {
# ==================================================================================
#   Option:  DFI_OPT  - Defines the type of DFI to use
#
#   Values:
#
#       0 - No DFI will be used
#       1 - Digital filter launch (DFL)
#       2 - Diabatic DFI (DDFI)
#       3 - Twice DFI (TDFI)
#
#   Notes:  Twice DFI (3) is the recommended option
#
#   Default: DFI_OPT = 0 (Off)
# ==================================================================================
#   
    my @dfi_opt = @{$Config{uconf}{DFI_OPT}};

return @dfi_opt;
}


sub Config_dfi_nfilter {
# ==================================================================================
#   Option:  DFI_NFILTER defined the digital filter type to use.
#
#   Values:
#
#       0 - Uniform
#       1 - Lanczos
#       2 - Hamming
#       3 - Blackman
#       4 - Kaiser
#       5 - Potter
#       6 - Dolph window
#       7 - Dolph
#       8 - Recursive high-order
#
#   Notes:  Dolph (7) comes highly recommended
#
#   Default: DFI_NFILTER = 7
# ==================================================================================
#
    my @dfi_nfilter = @{$Config{uconf}{DFI_NFILTER}};


return @dfi_nfilter;
}


sub Config_dfi_write_filtered_input {
# ==================================================================================
#   Option:  DFI_WRITE_FILTERED_INPUT - Write out filtered initial model state
#
#   Values:
#
#     T  - Write out filtered initial model state prior to integration
#     F  - Don't do this
#
#   Default: DFI_WRITE_FILTERED_INPUT = T
# ==================================================================================
#
    my @dfi_write_filtered_input = @{$Config{uconf}{DFI_WRITE_FILTERED_INPUT}};


return @dfi_write_filtered_input;
}


sub Config_dfi_write_dfi_history {
# ==================================================================================
#   Option:  DFI_WRITE_DFI_HISTORY -  Write output files during filtering integration
#
#   Values:
#
#     T  - Do something
#     F  - Do something else
#
#   Default: DFI_WRITE_DFI_HISTORY = F
# ==================================================================================
#
    my @dfi_write_dfi_history = @{$Config{uconf}{DFI_WRITE_DFI_HISTORY}};


return @dfi_write_dfi_history;
}


sub Config_dfi_cutoff_seconds {
# ==================================================================================
#   Option:  DFI_CUTOFF_SECONDS - Cutoff period, in seconds, for the filter
#
#   Values:  Be reasonable and think in 30 minute periods
#
#   Default: DFI_CUTOFF_SECONDS = 1800
# ==================================================================================
#
    my @dfi_cutoff_seconds = @{$Config{uconf}{DFI_CUTOFF_SECONDS}};


return @dfi_cutoff_seconds;
}


sub Config_dfi_time_dim {
# ==================================================================================
#   Option:  DFI_TIME_DIM - Maximum number of time steps for filtering period
#
#   Values:  Just make it larger than necessary, but not too large
#
#   Default: DFI_TIME_DIM = 1000
# ==================================================================================
#
    my @dfi_time_dim = @{$Config{uconf}{DFI_TIME_DIM}};


return @dfi_time_dim;
}


sub Config_dfi_radar {
# ==================================================================================
#   Option:  DFI_RADAR - The DFI radar ON|OFF switch
#
#   Values:  1 (ON) or 0 (OFF)
#
#   Notes:   Its not connected to anything yet
#
#   Default: DFI_RADAR = 0 (OFF)
# ==================================================================================
#
    my @dfi_radar = @{$Config{uconf}{DFI_RADAR}};


return @dfi_radar;
}


sub Config_dfi_backstop {
# ==================================================================================
#   Options:  DFI_BACKSTOP
#
#     DFI_BACKSTOP and DFI_FWDSTOP are the number of minutes over which to do
#     the backwards and forward portion of the DFI integration respectively.
#
#     The recommended value is 40 minutes hour for DFI_BACKSTOP.
#
#   Defaults: DFI_BACKSTOP = 40
# ==================================================================================
#
    my $lsim     = $Rconf{dinfo}{domains}{1}{length};  # Length of the simulation in seconds
    my $backstop = 60. * $Config{uconf}{DFI_BACKSTOP}[0];  #  Convert to seconds

    $backstop = $lsim if $backstop > $lsim;
    $backstop = 3600  if $backstop > 3600;  #  Hard-coded for the developers convenience
    $backstop = -1.0*$backstop;  #  Must be negative

return $backstop;
}


sub Config_dfi_fwdstop {
# ==================================================================================
#   Options:  DFI_FWDSTOP
#
#     DFI_BACKSTOP and DFI_FWDSTOP are the number of minutes over which to do
#     the backwards and forward portion of the DFI integration respectively.
#
#     The recommended value is 20 minutes for DFI_FWDSTOP.
#
#   Default: DFI_FWDSTOP = 20
# ==================================================================================
#
    my $lsim    = $Rconf{dinfo}{domains}{1}{length};  # Length of the simulation in seconds
    my $fwdstop = 60. * $Config{uconf}{DFI_FWDSTOP}[0];

    if ($fwdstop > $lsim) {
        $lsim = 3600 if $lsim > 3600; #  Hard-coded for the developers convenience
        my $min  = int ($lsim/60);
        my $mesg = "The requested length of the forward DFI period is greater than that of your forecast. ".
                   "Changing forward/backward DFI period to $min minutes.";
        &Ecomm::PrintMessage(6,11+$Rconf{arf},92,1,2,'Length of DFI period',$mesg);
        $fwdstop = $lsim;
    }

return $fwdstop;
}



sub DFI_Debug {
# ==============================================================================================
# &DFI_CONTROL NAMELIST DEBUG ROUTINE
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  When the --debug 3+ flag is passed, prints out the contents of the WRF dfi_control 
#  namelist section.
#
# ==============================================================================================
# ==============================================================================================
#   

    my @defvars  = ();
    my @ndefvars = ();
    my $nlsect   = 'dfi_control'; #  Specify the namelist section to print out

    return unless $ENV{RUN_DBG} > 3;  #  Only for --debug 3+

    foreach my $tcvar (@{$ARWconf{nlorder}{$nlsect}}) {
        defined $DFI{$tcvar} ? push @defvars => $tcvar : push @ndefvars => $tcvar;
    }

    return unless @defvars or @ndefvars;

    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,13+$Rconf{arf},144,1,1,'Leaving &ARWdfi');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-24s  = %s',$_,join ', ' => @{$DFI{$_}})) foreach @defvars;
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,' ');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-24s  = %s',$_,'Not Used')) foreach @ndefvars;
    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,2,'=' x 72); 


return;
}


