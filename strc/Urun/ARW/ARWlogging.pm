#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ARWlogging.pm
#
#  DESCRIPTION:  This module handles the configuration of the &logging 
#                namelist options for the ARW core. 
#
#   WHAT THE WRF
#   GUIDE SAYS:  Unfortunately, nothing
#
#                This routine controls the information written to the RSL 
#                standard error files. For the most part this information 
#                is already captured in the RSL out files and tends to slow
#                down the simulation.  Information regarding error logging
#                is buried deep within the bowels of the model code so you 
#                will have to do some digging should you really be interested, 
#                which you are not.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package ARWlogging;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Rconf %Config %ARWconf %Logging);

use Others;


sub Configure {
# ==============================================================================================
# &LOGGING NAMELIST CONFIGURATION DIVER
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Each subroutine controls the configuration for the somewhat crudely organized namelist
#  variables. Should there be a serious problem an empty hash is returned (not really).
#  Not all namelist variables are configured as some do not require anything beyond the
#  default settings. The %Logging hash is only used within this module to reduce the number
#  of characters being cut-n-pasted.
#
# ==============================================================================================
# ==============================================================================================
#   
    %Config = %ARWconfig::Config;
    %Rconf  = %ARWconfig::Rconf;

    my $href = shift; %ARWconf = %{$href};

    return () if &Logging_Control(); 
    return () if &Logging_Debug();

    %{$ARWconf{namelist}{logging}}  = %Logging;


return %ARWconf;
}


sub Logging_Control {
# ==============================================================================================
# WRF &LOGGING NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME? NOT MUCH
#
#   This routine controls the information written to the RSL standard error files.
#   For the most part this information is already captured in the RSL out files
#   and tends to slow down the simulation.  Information regarding error logging
#   is buried deep within the bowels of the model code so you will have to do
#   some digging should you really be interested, which you are not.
# ==============================================================================================
#
    %Logging  = ();

    @{$Logging{stderr_logging}}        = &Config_stderr_logging($Config{uconf}{LOGGING}[0]);
    @{$Logging{io_servers_silent}}     = &Config_io_servers_silent($Config{uconf}{LOGGING}[0]);
    @{$Logging{compute_slaves_silent}} = &Config_compute_slaves_silent($Config{uconf}{LOGGING}[0]);

return;
}


#
# ==================================================================================
# ==================================================================================
#      SO BEGINS THE INDIVIDUAL PARAMETER CONFIGURATION SUBROUTINES
# ==================================================================================
# ==================================================================================
#

sub Config_stderr_logging {
# ==================================================================================
#  Option:  STDERR_LOGGING - Standard Error Logging 
#
#  Values:
#           0 - No Standard Error Logging
#           1 - Turn ON Standard Error Logging 
#
#  Default: STDERR_LOGGING = 1 (ON)
# ==================================================================================
#
    my $logging = shift;

    my @stderr_logging = $logging ? (1) : (0);

return @stderr_logging;
}


sub Config_io_servers_silent {
# ==================================================================================
#  Option:  IO_SERVERS_SILENT - All I/O server ranks are silent
#
#  Values:  T (silent) or F (not silent)
#
#  Default: IO_SERVERS_SILENT = 0
# ==================================================================================
#
    my $logging = shift;

    my @io_servers_silent = $logging ? ('F') : ('T');

return @io_servers_silent;
}


sub Config_compute_slaves_silent {
# ==================================================================================
#  Option:  COMPUTE_SLAVES_SILENT - Compute_slaves_silent - All compute ranks except 0 are silent
#
#  Values: T (silent) or F (not silent)
#
#  Default: COMPUTE_SLAVES_SILENT = 0
# ==================================================================================
#
    my $logging = shift;

    my @compute_slaves_silent = $logging ? ('F') : ('T');

return @compute_slaves_silent;
}


sub Logging_Debug {
# ==============================================================================================
# &LOGGING NAMELIST DEBUG ROUTINE
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  When the --debug 4+ flag is passed, prints out the contents of the WRF &logging section.
#
# ==============================================================================================
# ==============================================================================================
#   
    my @defvars  = ();
    my @ndefvars = ();
    my $nlsect   = 'logging'; #  Specify the namelist section to print out

    return unless $ENV{RUN_DBG} > 3;  #  Only for --debug 4+

    foreach my $tcvar (@{$ARWconf{nlorder}{$nlsect}}) {
        defined $Logging{$tcvar} ? push @defvars => $tcvar : push @ndefvars => $tcvar;
    }

    return unless @defvars or @ndefvars;

    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,13+$Rconf{arf},144,1,1,'Leaving &ARWlogging');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-21s  = %s',$_,join ', ' => @{$Logging{$_}})) foreach @defvars;
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,' ');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-21s  = %s',$_,'Not Used')) foreach @ndefvars;
    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,0,2,'=' x 72);
        

return;
}


