#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ARWdiags.pm
#
#  DESCRIPTION:  This module handles the configuration of the &diags namelist 
#                options for the ARW core. 
#
#   WHAT THE WRF
#   GUIDE SAYS:  This namelist record controls the output of fields on 
#                pressure & height levels.
#
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package ARWdiags;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Rconf %Config %ARWconf %Diags);

use Others;


sub Configure {
# ==============================================================================================
# THE &DIAGS NAMELIST CONFIGURATION DIVER
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Each subroutine controls the configuration for the somewhat crudely organized namelist
#  variables. Should there be a serious problem an empty hash is returned (not really).
#  Not all namelist variables are configured as some do not require anything beyond the
#  default settings. The %Diags hash is only used within this module to reduce the number
#  of characters being cut-n-pasted.
#
# ==============================================================================================
# ==============================================================================================
#   
    %Config = %ARWconfig::Config;
    %Rconf  = %ARWconfig::Rconf;

    my $href = shift; %ARWconf = %{$href};

    return () if &Diags_Control(); 
    return () if &Diags_Debug();


    %{$ARWconf{namelist}{diags}} = %Diags;


return %ARWconf;
}


sub Diags_Control {
# ==============================================================================================
# WRF &DIAGS NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME? PROVIDES SOMETHING ABOUT WHICH TO GET EXCITED.
#
#   This routine configures the &diags section of the WRF namelist file. The choices are 
#   currently minimal but anticipate this section to grow as new diagnostics are added to 
#   the WRF.
# ==============================================================================================
#
   %Diags = ();

   @{$Diags{p_lev_diags}} = &Config_p_lev_diags();
   
   if ($Diags{p_lev_diags}[0]) {
       @{$Diags{press_levels}}     = &Config_press_levels();
       @{$Diags{num_press_levels}} = &Config_num_press_levels();
       @{$Diags{use_tot_or_hyd_p}} = &Config_use_tot_or_hyd_p();
       @{$Diags{p_lev_missing}}    = &Config_p_lev_missing();
   }


   @{$Diags{z_lev_diags}} = &Config_z_lev_diags();

   if ($Diags{z_lev_diags}[0]) {
       @{$Diags{z_levels}}       = &Config_z_levels();
       @{$Diags{num_z_levels}}   = &Config_num_z_levels();
       @{$Diags{z_lev_missing}}  = &Config_z_lev_missing();
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

sub Config_p_lev_diags {
# ==================================================================================
#   Option:  P_LEV_DIAGS  - Vertically interpolate diagnostics to pressure levels (1|0)
#
#   Notes:   Note that this field will be turned OFF if no pressure levels are 
#            defined in PRESS_LEVELS.
#
#   Default: P_LEV_DIAGS = 0 (OFF)
# ==================================================================================
#
    my @p_lev_diags = @{$Config{uconf}{P_LEV_DIAGS}};

return @p_lev_diags;
}


sub Config_num_press_levels {
# ==================================================================================
#   Option:  NUM_PRESS_LEVELS - The number of half pressure levels in press_levels
#
#   Default: NUM_PRESS_LEVELS = 0
# ==================================================================================
#
    my @num_press_levels = @{$Config{uconf}{NUM_PRESS_LEVELS}};

return @num_press_levels;
}


sub Config_press_levels {
# ==================================================================================
#   Option:  PRESS_LEVELS - The list of half pressure levels (Pa)
#
#   Notes:   Assume that {press_levels}[0] contains a comma delimited string of
#            pressure values that needs to be cleaned up a bit.
#
#   Default: PRESS_LEVELS = <blank>
# ==================================================================================
#
    my @press_levels = @{$Config{uconf}{PRESS_LEVELS}};

return @press_levels;
}


sub Config_p_lev_missing {
# ==================================================================================
#   Option:  P_LEV_MISSING - Missing value for below ground levels
#
#   Default: P_LEV_MISSING = -9999.
# ==================================================================================
#
    my @p_lev_missing = @{$Config{uconf}{P_LEV_MISSING}};

return @p_lev_missing;
}


sub Config_use_tot_or_hyd_p {
# ==================================================================================
#   Option:  USE_TOT_OR_HYD_P - Output half pressure levels as:
#
#   Values:
#           1 - Total Pressure (p+pb)         (Used by EMSUPP)
#           2 - Hydrostatic Pressure (p_hyd)  (less noisy ; Default)
#
#   Default: USE_TOT_OR_HYD_P = 2
# ==================================================================================
#
    my @use_tot_or_hyd_p = @{$Config{uconf}{USE_TOT_OR_HYD_P}};

return @use_tot_or_hyd_p;
}


sub Config_z_lev_diags {
# ==================================================================================
#   Option:  Z_LEV_DIAGS - Vertically interpolate diagnostics to height levels (1|0)
#
#   Notes:   Note that this field will be turned OFF if no pressure levels are 
#            defined in PRESS_LEVELS.
#
#   Default: OFF (0)
# ==================================================================================
#
    my @z_lev_diags = @{$Config{uconf}{Z_LEV_DIAGS}};

return @z_lev_diags;
}


sub Config_num_z_levels {
# ==================================================================================
#   Option:  NUM_Z_LEVELS - The number height levels identified Z_LEVELS
#
#   Default: NUM_Z_LEVELS = 0
# ==================================================================================
#
    my @num_z_levels = @{$Config{uconf}{NUM_Z_LEVELS}};

return @num_z_levels;
}


sub Config_z_levels {
# ==================================================================================
#   Option:  Z_LEVELS - The list of height levels (meters) 
#
#   Notes:   Positive height level values indicate Height Above Mean Sea Level
#            Negative height level values indicate Height Above Ground Level
#
#   Default: Z_LEVELS = <blank>
# ==================================================================================
#
    my @z_levels = @{$Config{uconf}{Z_LEVELS}};

return @z_levels;
}


sub Config_z_lev_missing {
# ==================================================================================
#   Option:  Z_LEV_MISSING - Missing value for below ground levels
#
#   Default: Z_LEV_MISSING = -9999.
# ==================================================================================
#
    my @z_lev_missing = @{$Config{uconf}{Z_LEV_MISSING}};

return @z_lev_missing;
}


sub Config_auxhist23_outname {
# ==================================================================================
#    TIME_CONTROL Variable:  AUXHIST23_OUTNAME  - File naming convention used
#
# ==================================================================================
#
    my @auxhist23_outname = @{$Config{uconf}{AUXHIST23_OUTNAME}};

return @auxhist23_outname;
}


sub Config_io_form_auxhist23 {
# ==================================================================================
#    TIME_CONTROL Variable:  IO_FORM_AUXHIST23 - I|0 format 
#
#        For now set to netCDF (2)
#
# ==================================================================================
#
    my @io_form_auxhist23 = @{$Config{uconf}{IO_FORM_AUXHIST23}};

return @io_form_auxhist23;
}


sub Config_auxhist23_interval {
# ==================================================================================
#    TIME_CONTROL Variables:  AUXHIST23_INTERVAL & FRAMES_PER_AUXHIST23
#
#      auxhist23_interval   - History interval for pressure level fields (use history_interval)
#      frames_per_auxhist23 - Format for output (Default is netcdf)
#
# ==================================================================================
#
    my @auxhist23_interval = @{$Config{uconf}{AUXHIST23_INTERVAL}};

return @auxhist23_interval;
}


sub Config_frames_per_auxhist23 {
# ==================================================================================
#    TIME_CONTROL Variables:  AUXHIST23_INTERVAL & FRAMES_PER_AUXHIST23
#
#      auxhist23_interval   - History interval for pressure level fields (use history_interval)
#      frames_per_auxhist23 - Format for output (Default is netcdf)
#
# ==================================================================================
#
    my @frames_per_auxhist23 = @{$Config{uconf}{FRAMES_PER_AUXHIST23}};

return @frames_per_auxhist23;
}


sub Diags_Debug {
# ==============================================================================================
# &DIAGS NAMELIST DEBUG ROUTINE
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  When the --debug 4+ flag is passed, prints out the contents of the WRF &diags
#  namelist section.
#
# ==============================================================================================
# ==============================================================================================
#   

    my @defvars  = ();
    my @ndefvars = ();
    my $nlsect   = 'diags'; #  Specify the namelist section to print out

    return unless $ENV{RUN_DBG} > 3;  #  Only for --debug 4+

    foreach my $tcvar (@{$ARWconf{nlorder}{$nlsect}}) {
        defined $Diags{$tcvar} ? push @defvars => $tcvar : push @ndefvars => $tcvar;
    }

    return unless @defvars or @ndefvars;

    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,13+$Rconf{arf},144,1,1,'Leaving &ARWdiags');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-20s  = %s',$_,join ', ' => @{$Diags{$_}})) foreach @defvars;
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,' ');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-20s  = %s',$_,'Not Used')) foreach @ndefvars;
    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,2,'=' x 72);


return;
}


