#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ARWbdycntrl.pm
#
#  DESCRIPTION:  This module handles the configuration of the &bdy_control namelist 
#                options for the ARW core. 
#
#   WHAT THE WRF
#   GUIDE SAYS:  This namelist record controls the boundary condition parameters
#
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package ARWbdycntrl;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Rconf %Config %ARWconf %BoundaryControl);

use Others;


sub Configure {
# ==============================================================================================
# &BDY_CONTROL NAMELIST CONFIGURATION DIVER
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Each subroutine controls the configuration for the somewhat crudely organized namelist
#  variables. Should there be a serious problem an empty hash is returned (not really).
#  Not all namelist variables are configured as some do not require anything beyond the
#  default settings. The %BoundaryControl hash is only used within this module to reduce 
#  the number of characters being cut-n-pasted.
#
# ==============================================================================================
# ==============================================================================================
#   
    %Config = %ARWconfig::Config;
    %Rconf  = %ARWconfig::Rconf;

    my $href = shift; %ARWconf = %{$href};

    return () if &BoundaryControl_Control();
    return () if &BoundaryControl_Debug();

    %{$ARWconf{namelist}{bdy_control}} = %BoundaryControl;


return %ARWconf;
}


sub BoundaryControl_Control {
# ==============================================================================================
# WRF PRIMARY IO &BDY_CONTROL NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME? NOT MUCH
#
# ==============================================================================================
#
   %BoundaryControl = ();

   if ($Rconf{rtenv}{global}) {
       %BoundaryControl = &BoundaryControl_GlobalDomain();
   } else {
       %BoundaryControl = &BoundaryControl_LimitedAreaDomain();
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

sub BoundaryControl_GlobalDomain {
# ==================================================================================
#   Configure the &bndy_cntrl namelist parameters for use with a global
#   simulation. 
# ==================================================================================
#
    my %bdynl = ();

    @{$bdynl{periodic_x}}   = ('F') x $Config{maxdoms}; $bdynl{periodic_x}[0] = 'T';
    @{$bdynl{polar}}        = ('F') x $Config{maxdoms}; $bdynl{polar}[0]      = 'T';
    @{$bdynl{nested}}       = ('T') x $Config{maxdoms}; $bdynl{nested}[0]     = 'F';

    @{$bdynl{symmetric_xs}} = ('F');
    @{$bdynl{symmetric_xe}} = ('F');
    @{$bdynl{open_xs}}      = ('F');
    @{$bdynl{open_xe}}      = ('F');
    @{$bdynl{periodic_y}}   = ('F');
    @{$bdynl{symmetric_ys}} = ('F');
    @{$bdynl{symmetric_ye}} = ('F');
    @{$bdynl{open_ys}}      = ('F');
    @{$bdynl{open_ye}}      = ('F');


return %bdynl;
}


sub BoundaryControl_LimitedAreaDomain {
# ==================================================================================
#   Configure the &bndy_cntrl namelist parameters for use with a limited area
#   domain simulation.
# ==================================================================================
#
    my %bdynl = ();

    @{$bdynl{specified}} = ('F') x $Config{maxdoms}; $bdynl{specified}[0] = 'T';
    @{$bdynl{nested}}    = ('T') x $Config{maxdoms}; $bdynl{nested}[0] = 'F';

    @{$bdynl{spec_zone}}      = (1);
    @{$bdynl{relax_zone}}     = (4);
    @{$bdynl{spec_bdy_width}} = (5); #  spec_bdy_width = relax_zone + spec_zone
    @{$bdynl{spec_exp}}       = (0);
    

return %bdynl;
}


sub BoundaryControl_Debug {
# ==============================================================================================
# &BDY_CONTROL NAMELIST DEBUG ROUTINE
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  When the --debug 4 flag is passed, prints out the contents of the WRF &bdy_control
#  namelist section .
#
# ==============================================================================================
# ==============================================================================================
#   

    my @defvars  = ();
    my @ndefvars = ();
    my $nlsect   = 'bdy_control'; #  Specify the namelist section to print out

    return unless $ENV{RUN_DBG} > 3;  #  Only for --debug 3+

    foreach my $tcvar (@{$ARWconf{nlorder}{$nlsect}}) {
        defined $BoundaryControl{$tcvar} ? push @defvars => $tcvar : push @ndefvars => $tcvar;
    }

    return unless @defvars or @ndefvars;

    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,13+$Rconf{arf},144,1,1,'Leaving &ARWbdycntrl');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-20s  = %s',$_,join ', ' => @{$BoundaryControl{$_}})) foreach @defvars;
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,' ');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-20s  = %s',$_,'Not Used')) foreach @ndefvars;
    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,2,'=' x 72);
        

return;
}


