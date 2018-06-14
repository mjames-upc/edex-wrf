#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ARWfinal.pm
#
#  DESCRIPTION:  This module handles the configuration of the &logging 
#                namelist options for the ARW core. 
#
#   WHAT THE WRF
#   GUIDE SAYS:  Unfortunately, nothing
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package ARWfinal;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Rconf %Config %ARWconf %ARWfinal);

use Others;


sub Configure {
# ==============================================================================================
# WRF ARW FINAL NAMELIST CONFIGURATION DIVER
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME? EVERYTHING IMPORTANT
#
#  The entire purpose of this module is to clean up any configuration "loose ends", meaning
#  that final checks are done to ensure a viable namelist file gets wriiten to "namelist.input",
#  (namelist.real & namelist.wrfm) prior to starting a simulation. Unlike the previous namelist
#  modules that serve to populate individual namelist sections, this module will crosscheck all
#  sections for compatibility. If a potential problem is not caught here it will be written
#  to the live namelist.
#
# ==============================================================================================
# ==============================================================================================
#   
    %Config = %ARWconfig::Config;
    %Rconf  = %ARWconfig::Rconf;

    my $href = shift; %ARWconf = %{$href};

    %ARWfinal = %{$ARWconf{namelist}};  #  We need the entire namelist hash for this task

    return () if &ARWfinal_Control(); 
    return () if &ARWfinal_Debug();

    %{$ARWconf{namelist}}  = %ARWfinal; #  Re-assign after updates


return %ARWconf;
}


sub ARWfinal_Control {
# ==============================================================================================
# WRF ARW FINAL NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME? NOT MUCH
#
#    This routine handles the configuration of some of the more esoteric 
#    parameters and options available to WRF users. Additionally, final 
#    check are made to ensure a viable configuration is written to the 
#    final namelist file. Whether the simulation runs to completion is
#    not my problem.
# ==============================================================================================
#

    &ConfigFinal_TimeControl(); return 1 if $ENV{RMESG}; #  Final &time_control namelist section checks
    &ConfigFinal_Domains();     return 1 if $ENV{RMESG}; #  Final &domains namelist section checks
    &ConfigFinal_Physics();     return 1 if $ENV{RMESG}; #  Final &physics namelist section checks
    &ConfigFinal_Dynamics();    return 1 if $ENV{RMESG}; #  Final &dynamics namelist section checks
    &ConfigFinal_FDDA();        return 1 if $ENV{RMESG}; #  Final &fdda namelist section checks
    &ConfigFinal_DFI();         return 1 if $ENV{RMESG}; #  Final &dfi_control namelist section checks

return;
}


#
# ==================================================================================
# ==================================================================================
#      SO BEGINS THE INDIVIDUAL PARAMETER CONFIGURATION SUBROUTINES
# ==================================================================================
# ==================================================================================
#

sub ConfigFinal_TimeControl {
# ==================================================================================
# ==================================================================================
#
    my $mesg = qw{};

    #-------------------------------------------------------------------------------
    #  If SST Update is turned ON (SST_UPDATE = 1) then the auxinput4 parameters 
    #  must also be set.  May need auxinput4_end_h
    #-------------------------------------------------------------------------------
    #
    if ($ARWfinal{physics}{sst_update}[0]) {

        # !!!  TO DO - Get SST update files @{$Rconf{rtenv}{sstfls}{1}} and interval
        # @{$ARWfinal{time_control}{auxinput4_interval}} = (sstint) x $Config{maxdoms};
        @{$ARWfinal{time_control}{auxinput4_inname}}   = ('"wrflowinp_d<domain>"');
        @{$ARWfinal{time_control}{io_form_auxinput4}}  = (2);
    }

return;
}


sub ConfigFinal_Physics {
# ==================================================================================
# ==================================================================================
#
    my $mesg = qw{};

    #-------------------------------------------------------------------------------
    #  The SAS schemes do not play well with the adaptive time step method
    #-------------------------------------------------------------------------------
    #
    if ( (grep {/^$ARWfinal{physics}{cu_physics}[0]$/} (4,14,18)) and $ARWfinal{domains}{use_adaptive_time_step}[0] eq 'T') {
        $mesg = "Unfortunately, none of the SAS CU options (CU_PHYSICS = 4, 14, or 84) work with ".
                "the adaptive time step. Please hide your face in shame and try again.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'SAS Cumulus Scheme and Adaptive Time Step:',$mesg);
    }

    
return;
}


sub ConfigFinal_Domains {
# ==================================================================================
# ==================================================================================
#
    my $mesg = qw{};

    #-------------------------------------------------------------------------------
    #  Turn FEEDBACK OFF (0) if nested domain in which CU_PHYSICS is ON -> OFF
    #  Restriction lifted - 4/2017
    #-------------------------------------------------------------------------------
    #
  # if ($ARWfinal{physics}{cu_physics}[0] != $ARWfinal{physics}{cu_physics}[-1] and $ARWfinal{domains}{feedback}[0]) {
  #     $mesg = "2-way feedback is not recommended for simulations where CU -> Explicit ".
  #             "precipitation. Using 1-way feedback instead.";
  #     &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,"Turning OFF 2-way Feedback:",$mesg);
  #     @{$ARWfinal{domains}{feedback}}      = (0);
  #     @{$ARWfinal{domains}{smooth_option}} = (0);
  # }


    #-------------------------------------------------------------------------------
    #  Turn FEEDBACK OFF (0) if nested domain with nudging
    #-------------------------------------------------------------------------------
    #
    if ($ARWfinal{fdda}{grid_fdda}[0] and $ARWfinal{domains}{feedback}[0]) {
        &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,"2-way feedback is not allowed when nudging - Turning feedback OFF");
        @{$ARWfinal{domains}{feedback}}      = (0);
        @{$ARWfinal{domains}{smooth_option}} = (0);
    }



    #-------------------------------------------------------------------------------
    #  If Thompson AA scheme is being used define the aerosol dataset options.
    #  I know what you're thinking, because I though it - The use_aero_icbc {physics} 
    #  flag is used to tell WRF that the aerosol data are to be read from the WPS
    #  files (T). The wif_input_opt = 1 defines which aerosol dataset to read.
    #  The possibility exists for multiple datasets to be in the WPS files, say
    #  the WIF & GoCart (GCA), so wif_input_opt & gca_input_opt tells WRF which
    #  to use.  This method of specifying a dataset could be better organized.
    #-------------------------------------------------------------------------------
    #
    if ($ARWfinal{physics}{mp_physics}[0] == 28 and $ARWfinal{physics}{use_aero_icbc}[0] eq 'T') {  #  Using Thompson AA scheme
         @{$ARWfinal{domains}{wif_input_opt}}   = (1);
         @{$ARWfinal{domains}{num_wif_levels}}  = (30);  #  Hardcoded but available from %renv{nwifs}
    }
    

return;
}


sub ConfigFinal_Dynamics {
# ==================================================================================
# ==================================================================================
#
    my $mesg = qw{};

    #-------------------------------------------------------------------------------
    #  The Gravity Wave Drag option only works with YSU & MYNN PBL schemes per   
    #  module_check_a_mundo.F (V3.7)
    #--------------------------------------------------------------------------------
    #
    if ($ARWfinal{dynamics}{gwd_opt}[0] and ! grep {/^$ARWfinal{physics}{bl_pbl_physics}[0]$/} (1,5,6) ) {
        $mesg = "When using the Gravity Wave Drag option (GWD_OPT = $ARWfinal{dynamics}{gwd_opt}[0]), ".
                "you must also use the YSU or MYNN PBL scheme.  That's just the way it the WRF works.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'What a Drag!',$mesg);
    }


return;
}


sub ConfigFinal_FDDA {
# ==================================================================================
# ==================================================================================
#
    my $mesg = qw{};

    #-------------------------------------------------------------------------------
    #  Make sure Digital Filter Initialization and FDDA are not turned on at 
    #  the same time.
    #-------------------------------------------------------------------------------
    #
    if ($ARWfinal{fdda}{grid_fdda}[0] and $ARWfinal{dfi_control}{dfi_opt}[0]) {
        $mesg = "It appears that you have turned on both digital filter initialization (DFI) and nudging. ".
                "Unfortunately, these options do not play well together, and thus you will have to ".
                "decide which one you love more.\n\nIt's kind of like choosing between your children, ".
                "but this time, one gets sent away to a military academy.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,80,0,0,'Nudging and DFI do not make for a happy simulation:',$mesg);
    }

return;
}


sub ConfigFinal_DFI {
# ==================================================================================
# ==================================================================================
#
    my $mesg = qw{};

    #-------------------------------------------------------------------------------
    #  Per module_check_a_mundo.F (V3.7): Digital Filter Initialization does not 
    #                                     work with TEMF PBL
    #-------------------------------------------------------------------------------
    #
    if ($ARWfinal{dfi_control}{dfi_opt}[0] and ($ARWfinal{physics}{bl_pbl_physics}[0] == 10) ) {
        $mesg = "Unfortunately for us (but mostly you), the Total Energy Mass Flux (TEMF) PBL Scheme ".
                "can not be used with Digital Filter Initialization (DFI), so you will have to decide ".
                "which one you love more.\n\nIt's kind of like choosing between your children, but this ".
                "time, one gets sent away to a military academy.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,80,0,0,'TEMF PBL and DFI are not the perfect couple:',$mesg);
    }

return;
}


sub ARWfinal_Debug {
# ==============================================================================================
# &ARWfinal NAMELIST DEBUG ROUTINE
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  When the --debug 3+ flag is passed, prints out the contents of the WRF &ARWfinal section.
#
# ==============================================================================================
# ==============================================================================================
#   
    return unless $ENV{RUN_DBG} > 2;  #  Only for --debug 3+

    my @nlsects = qw(time_control domains physics noah_mp dynamics dfi_control fdda stoch diags afwa bdy_control logging namelist_quilt);

    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,13+$Rconf{arf},144,1,1,'Leaving &ARWfinal - Final ARW Namelist Values:');

    foreach my $nlsect (@nlsects) {

        my @defvars  = ();
        my @ndefvars = ();

        foreach my $tcvar (@{$ARWconf{nlorder}{$nlsect}}) {
            defined $ARWfinal{$nlsect}{$tcvar} ? push @defvars => $tcvar : push @ndefvars => $tcvar;
        }

        next unless @defvars;

        &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,"&${nlsect}");
        &Ecomm::PrintMessage(0,19+$Rconf{arf},204,1,0,sprintf('%-28s  = %s',$_,join ', ' => @{$ARWfinal{$nlsect}{$_}})) foreach @defvars;
        &Ecomm::PrintMessage(0,19+$Rconf{arf},94,1,0,' ');

    }  # foreach my $nlsect (@nlsects)

    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,0,2,'=' x 72);
        

return;
}


