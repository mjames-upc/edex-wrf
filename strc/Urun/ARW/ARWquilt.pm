#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ARWquilt.pm
#
#  DESCRIPTION:  This module handles the configuration of the &namelist_quilt 
#                namelist options for the ARW core. 
#
#   WHAT THE WRF
#   GUIDE SAYS:  This namelist record controls synchronized I/O for MPI 
#                applications.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package ARWquilt;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Rconf %Config %ARWconf %Quilt);

use Others;


sub Configure {
# ==============================================================================================
# &NAMELIST_QUILT NAMELIST CONFIGURATION DIVER
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Each subroutine controls the configuration for the somewhat crudely organized namelist
#  variables. Should there be a serious problem an empty hash is returned (not really).
#  Not all namelist variables are configured as some do not require anything beyond the
#  default settings. The %Quilt hash is only used within this module to reduce the number
#  of characters being cut-n-pasted.
#
# ==============================================================================================
# ==============================================================================================
#   
    %Config = %ARWconfig::Config;
    %Rconf  = %ARWconfig::Rconf;

    my $href = shift; %ARWconf = %{$href};

    return () if &Quilt_Control(); 
    return () if &Quilt_Debug();

    %{$ARWconf{namelist}{namelist_quilt}}  = %Quilt;


return %ARWconf;
}


sub Quilt_Control {
# ==============================================================================================
# WRF &NAMELIST_QUILT  NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME? NOT MUCH
#
# ==============================================================================================
#

    %Quilt  = ();

    @{$Quilt{nio_tasks_per_group}} = &Config_nio_tasks_per_group();
    @{$Quilt{nio_groups}}          = &Config_nio_groups();


return;
}


#
# ==================================================================================
# ==================================================================================
#      SO BEGINS THE INDIVIDUAL PARAMETER CONFIGURATION SUBROUTINES
# ==================================================================================
# ==================================================================================
#

sub Config_nio_tasks_per_group {
# ==================================================================================
#  Option:  NIO_TASKS_PER_GROUP - # of processors used for IO quilting per IO group
#
#  Default: NIO_TASKS_PER_GROUP = 0
# ==================================================================================
#
    my @nio_tasks_per_group = @{$Config{uconf}{NIO_TASKS_PER_GROUP}};

return @nio_tasks_per_group;
}


sub Config_nio_groups {
# ==================================================================================
#  Option:  NIO_GROUPS - Number of groups
#
#  Values:  May be set to higher value for nesting IO or history and restart IO
#
#  Default: NIO_GROUPS = 1
# ==================================================================================
#
    my @nio_groups = @{$Config{uconf}{NIO_GROUPS}};

return @nio_groups;
}


sub Quilt_Debug {
# ==============================================================================================
# &NAMELIST_QUILT NAMELIST DEBUG ROUTINE
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  When the --debug 4+ flag is passed, prints out the contents of the WRF &namelist_quilt section.
#
# ==============================================================================================
# ==============================================================================================
#   
    my @defvars  = ();
    my @ndefvars = ();
    my $nlsect   = 'namelist_quilt'; #  Specify the namelist section to print out

    return unless $ENV{RUN_DBG} > 3;  #  Only for --debug 4+

    foreach my $tcvar (@{$ARWconf{nlorder}{$nlsect}}) {
        defined $Quilt{$tcvar} ? push @defvars => $tcvar : push @ndefvars => $tcvar;
    }

    return unless @defvars or @ndefvars;

    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,13+$Rconf{arf},144,1,1,'Leaving &ARWquilt');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-20s  = %s',$_,join ', ' => @{$Quilt{$_}})) foreach @defvars;
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,' ');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-20s  = %s',$_,'Not Used')) foreach @ndefvars;
    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,2,'=' x 72);
        

return;
}


