#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ARWdomains.pm
#
#  DESCRIPTION:  ARWdomains contains the subroutines used for configuration of
#                the &domains section of the WRF ARW core namelist. 
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package ARWdomains;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Rconf %Config %ARWconf %Domains);

use Others;


sub Configure {
# ==============================================================================================
# WRF &DOMAINS NAMELIST CONFIGURATION DRIVER
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Each subroutine controls the configuration for the somewhat crudely organized namelist
#  variables. Should there be a serious problem an empty hash is returned (not really).
#  Not all namelist variables are configured as some do not require anything beyond the
#  default settings. The %Domains hash is only used within this module to reduce the
#  number of characters being cut-n-pasted.
#
#  Additionally, the MPI-related parameters are configured in this module even though they
#  will need to be included in the &domains section of the namelist file.
#
# ==============================================================================================
# ==============================================================================================
#
    %Config = %ARWconfig::Config;
    %Rconf  = %ARWconfig::Rconf;


    my $href = shift; %ARWconf = %{$href};

    return () if &Domains_Timestep();
    return () if &Domains_Realinit();
    return () if &Domains_Nesting();
    return () if &Domains_Levels();
    return () if &Domains_Domain();
    return () if &Domains_Final();
    return () if &Domains_Debug();

    %{$ARWconf{namelist}{domains}} = %Domains;


return %ARWconf;
}


sub Domains_Timestep {
# ==============================================================================================
# WRF TIME STEP (OR TIMESTEP OR TIME-STEP) CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?:
#
#  This subroutine manages the various simulation time step options available to the user,
#  including the adaptive time step option.
#
# ==============================================================================================
# ==============================================================================================
#   
use Math::Trig;

    my $mesg    = qw{};
    my %renv    = %{$Rconf{rtenv}};   #  Contains the  local configuration
    my %dinfo   = %{$Rconf{dinfo}};  #  just making things easier
    my %uconf   = %{$Config{uconf}};

    my $timestep= $uconf{TIME_STEP}[0];


    #========================================================================================
    #  Calculate the UEMS suggested simulation time step, which will be used to compare
    #  against any user-defined values or as the basis for the simulation time step if
    #  AUTO_S or AUTO_R (or no value) is specified.  We also need to account for the 
    #  value of TIMESTEP_SYNC, which specifies whether to sync the time step values to
    #  the BC update frequency (1; default), BC update frequency & history file output
    #  frequency (2), or not at all (0).
    #
    #  Additionally, if FDDA (nudging) is turned ON, then the time step may need to be 
    #  adjusted to coincide with a nudging data file time.
    #
    #  ts6dx = ARW default where ts = 6*DX (primary domain) adjusted to be an
    #          integer multiple of history_interval.
    #
    #  autos = Similar to ts6dx except that DX is taken to be the smallest grid spacing
    #          within the computational domain.
    #
    #  mapsf = The mapscale factor to be used in the calculation. Only used for AUTO_S 
    #          option or a global domain.
    #
    #  Special Perl note for the forgetful developer: The Perl modulo operator is an 
    #  integer operator, and if it receives fractional arguments, Perl will only use 
    #  the integer portion of the fraction. Thus, most of the modulo operations 
    #  are scaled by 100.
    #========================================================================================
    #
    my $mscale = 100;  #  for modulus operations
    my $hints  = $ARWconf{namelist}{time_control}{history_interval}[0]*60; #  Convert history_interval to seconds
    my $bcint  = $ARWconf{namelist}{time_control}{interval_seconds}[0];    # Boundary condition update frequency
    my $fdint  = $ARWconf{namelist}{fdda}{grid_fdda}[0] ? $ARWconf{namelist}{fdda}{gfdda_interval_m}[0]*60. : 0;

    my $dx = 0.50*($dinfo{domains}{1}{dx}+$dinfo{domains}{1}{dy});  # Take the average of dx&dy
       $dx = $dx * 0.001; #  Convert to km


    #  Determine the mapscale factor for a global domain or if the AUTO_S option is chosen.
    #
    my $mapsf  = $renv{global} ? 1./cos($uconf{FFT_FILTER_LAT}[0]*acos(-1.)/180.0) : $renv{maxmsf};


    #  Calculate the two primary domain TS that will be used as the basis 
    #  for the final time step.
    #
    my $ts6dx  = sprintf '%.2f',6*$dx;         # ARW default (6*dx in km) 
    my $ts5dx  = sprintf '%.2f',5*$dx;         # ARW default (5*dx in km)
    my $autos  = sprintf '%.2f',$ts6dx/$mapsf; # If AUTO_S or Global domain
       $autos  = $ts5dx if $autos < $ts5dx;    # Avoid an excessively small timestep


    #  There are five possible time step options available, 'Auto' ($ts6dx), 'Auto_S' ($autos), 
    #  Global domain ($autos), user value (some value), and 'Adaptive' (Adaptive time step)
    #
    $Domains{use_adaptive_time_step}[0] = ($timestep =~ /^Adapt/i) ? 'T' : 'F';


    my $tstst  = $renv{global} ? $autos : $ts6dx;  #  Use the appropriate time step for comparison

    if (&Others::isNumber($timestep)) {  
        #  The user has specified the time step so compare to accepted time step values
        #  and provide a warning if out of recommended range.
        #
        if ($tstst/$timestep > 4) {  # Time step is less than 25% the 6*DX value
             my $pcnt = sprintf '%.1f', 100.*$timestep/$tstst;
             my $rts  = sprintf '%.1f', $tstst;
             my $uts  = sprintf '%.1f', $timestep;
             $mesg = "The time step you have chosen for this simulation, $uts seconds, is ${pcnt}% of the ".
                     "largest recommended value of $rts seconds. You might want to consider increasing your ".
                     "time step value, unless you don't mind the wait.";
             &Ecomm::PrintMessage(6,11+$Rconf{arf},88,1,2,"That's a rather small time step you have there:",$mesg);
        }

        if ($timestep/$tstst > 1.25) {  # Time step is greater than 125% the 6*DX value
             my $pcnt = sprintf '%.1f', 100.*$timestep/$tstst;
             my $rts  = sprintf '%.1f', $tstst;
             my $uts  = sprintf '%.1f', $timestep;
             $mesg = "The time step you have chosen for this simulation, $uts seconds, is ${pcnt}% of the ".
                     "largest recommended value of $rts seconds. You might want to consider decreasing your ".
                     "time step value, unless you don't mind disappointment.";
             &Ecomm::PrintMessage(6,11+$Rconf{arf},88,1,2,"That's a rather large time step you have there:",$mesg);
        }
    } else {

        for ($timestep) {
            $_ = $autos     if /_S$/ or $renv{global};
            $_ = $ts6dx     if /^AUTO$/ or /^ADAPT/;
        }
    }


    # ==================================================================================
    #   Option:  TIME_STEP_DFI
    #
    #     Set TIME_STEP_DFI (whole seconds) to the timestep you wish to use during
    #     the DFI portion of simulation. This value should be appropriate for your
    #     primary ARW domain and follow the same rules as those used to select a
    #     time step used for the main simulation, which is based on the grid spacing.
    #
    #     If you are planning on using DFI with adaptive timestep during the simu-
    #     lation and leave TIME_STEP_DFI blank or commented out, the value of $ts6dx
    #     will be assigned to TIME_STEP_DFI.
    #
    #     TIME_STEP_DFI should divide evenly into DFI_BACKSTOP minutes (seconds).
    #
    #   Default: TIME_STEP_DFI = (blank)
    # ==================================================================================
    #
    my $lsim  = $dinfo{domains}{1}{length}*$mscale;  # Length of the simulation in seconds
    my $tsdfi = $uconf{TIME_STEP_DFI}[0] ? $uconf{TIME_STEP_DFI}[0] : int $timestep; 
       $tsdfi = $tsdfi*$mscale;

    my $bssec = $uconf{DFI_BACKSTOP}[0]*60*$mscale;;
       $bssec = $lsim if $bssec > $lsim;
       $tsdfi-- while $bssec%$tsdfi and $tsdfi > 0;
       $tsdfi = $tsdfi * 0.01;
    

    #  Set the precision of the time step to 10th if greater then 10s; otherwise 100ths
    #
    $timestep = ($timestep < 10.0) ? sprintf '%.2f',$timestep :  sprintf '%.1f',$timestep;

    
    #  Warn the user if an adaptive timestep was selected with a global domain and 
    #  change to the recommended time step ($autos).
    #
    if ($Domains{use_adaptive_time_step}[0] eq 'T' and $renv{global}) {

        my $rts  = sprintf '%.1f', $timestep;
        $mesg = "The adaptive time step is not an option with a global domain. Rather than make you change ".
                "your value in the configuration file, this simulation will use the UEMS recommended value ".
                "of $rts seconds as the basis for the large time step.\n\nHey, I just don't make the rules, ".
                "I get to enforce them too!";
        &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,"Adaptive Time Step & Global Domains",$mesg);

        $Domains{use_adaptive_time_step}[0] = 'F';
    }


    unless ($Domains{use_adaptive_time_step}[0] eq 'T') {  #  Don't worry about if using adaptive time step

        #========================================================================================
        #  There are a number of conditions that require an adjustment to the timestep:
        #
        #    1. The time step is greater then the history interval
        #    2. User requests that the time step divide evenly into the BC update frequency
        #    3. User requests that the time step divide evenly into the history interval
        #========================================================================================
        #

        #  If the time step is greater then the history interval then set timestep = history_interval
        #  if within 20%.
        #  
        if ($hints < $timestep and $timestep/$hints < 1.201) {
            my $ots  = sprintf '%.1f', $timestep;
            my $inc  = sprintf '%.1f',100*($timestep-$hints)/$timestep;
            my $int  = sprintf '%.1f', $hints;
 
            $mesg = "The time step for this simulation ($ots seconds) is less than the data output frequency ($int seconds). ".
                    "The time step will be adjusted downward to match the output frequency, which will increase the total time ".
                    "to run the simulation by ${inc}%.";
            &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,"A necessary time step adjustment",$mesg);
            $timestep = $hints;
        }


        #  Check whether the history file output frequency is smaller and the time step 
        #  
        if ($hints < $timestep) {
            my $rts  = sprintf '%.1f', $timestep;
            my $int  = sprintf '%.1f', $hints;
            $mesg = "The history file frequency value ($int seconds) is smaller than the time step ($rts seconds). ".
                    "You need to either increase the number of minutes between simulation output times in the run_wrfout.conf ".
                    "file or decrease your time step in run_timestep.conf.\n\nIt's all on you now!";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,80,0,0,'Simulation output frequency not compatible with time step',$mesg);
            return 1;
        }
    }


    #========================================================================================
    #  Now adjust the time step according to the $uconf{TIMESTEP_SYNC} option. To make
    #  this task easier, multiply the variables used in the calculation so to make them
    #  consistent with an increment value of 1. Note that this calculation is being done
    #  regardless whether the adaptive time step is on. Just because, that's why.
    #========================================================================================
    #
    my $mfact = ($timestep < 10.0) ? 100 : 10;
    
    $timestep = int ($timestep*$mfact);
    $hints    = int ($hints*$mfact);
    $bcint    = int ($bcint*$mfact);
    $fdint    = int ($fdint*$mfact);  #  FDDA update interval

    if ($uconf{TIMESTEP_SYNC}[0] == 1) {   #  Adjust the time step so that it divides evenly into BC update frequency
        $timestep = int ($timestep*1.01);  #  Slight upward fudge factor
        $timestep-- while $bcint%$timestep and $timestep > 0;
    } elsif ($uconf{TIMESTEP_SYNC}[0] == 2) { 
        $timestep = int ($timestep*1.01);  #  Slight upward fudge factor
        $timestep-- while ($bcint%$timestep or $hints%$timestep) and $timestep > 0;
    }
    $timestep-- while $fdint%$timestep and $timestep > 0;  #  Should not change TS if FDDA is OFF

    $timestep = sprintf '%.2f',$timestep/$mfact;



    #========================================================================================
    #  Assign the time step values - Note that the time step is assigned regardless whether
    #  USE_ADAPTIVE_TIME_STEP = T.
    #========================================================================================
    #
    $Domains{time_step}[0]           = int $timestep;
    $Domains{time_step_fract_num}[0] = ($timestep*100)%($Domains{time_step}[0]*100);
    $Domains{time_step_fract_den}[0] = 100;
    $Domains{time_step_dfi}[0]       = $tsdfi;



    #========================================================================================
    #   USE_ADAPTIVE_TIME_STEP - If adaptive timestep is requested then populate the 
    #   necessary fields. Current default are:
    #
    #     step_to_output_time   : True
    #     target_cfl            : 1.2, 1.2, 1.2
    #     target_hcfl           : 0.84, 0.84, 0.84
    #     max_step_increase_pct : 5, 51, 51
    #     starting_time_step    : -1, -1, -1
    #     max_time_step         : -1, -1, -1
    #     min_time_step         : -1, -1, -1
    #
    #   Note that when using the adaptive timestep with a regional lat-lon domain, the 
    #   value of fft_filter_lat must my set to a value less than 90. This is done in the 
    #   &Dynamics_GlobalDomain subroutine.
    #========================================================================================
    #
    if ($Domains{use_adaptive_time_step}[0] eq 'T') {

        my @rundoms = sort {$a <=> $b} keys %{$dinfo{domains}};

        #  First order of business is check whether the use has specified the starting, max, and min
        #  time step. If yes, then check whether they are reasonable. Let the following be the guide:
        #
        #  starting_time_step =  5*DX (ARW guide uses 4*DX)
        #  max_time_step      = 15*DX (ARW guide uses 8*DX)
        #  min_time_step      =  2*DX (ARW guide uses 3*DX)
        #
        #  FYI - If any of the values for min_time_step, max_time_step, or starting_time_step are set
        #        to zero, the UEMS will replace them with $ts02dx, $ts15dx, and $ts05dx respectively.
        #
        my $ts06dx  = int  6*$dx; $ts06dx-- while 10800%$ts06dx and $ts06dx > 2*$dx;

        my $ts02dx  = int  2*$dx; $ts02dx++ while 10800%$ts02dx and $ts02dx < $ts06dx;
        my $ts05dx  = int  5*$dx; $ts05dx-- while 10800%$ts05dx and $ts02dx < $ts05dx;
        my $ts15dx  = int 15*$dx; $ts15dx-- while 10800%$ts15dx and $ts15dx > $ts06dx;


        @{$Domains{adaptation_domain}}     = (grep {/^$uconf{ADAPTATION_DOMAIN}[0]$/} @rundoms) ? ($uconf{ADAPTATION_DOMAIN}[0]) : (1);


        @{$uconf{STARTING_TIME_STEP}} = ($ts05dx) unless $uconf{STARTING_TIME_STEP}[0];

        if ($uconf{STARTING_TIME_STEP}[0] > 0 and $uconf{STARTING_TIME_STEP}[0] > $ts06dx) {
            $mesg = "Starting adaptive timestep for the primary domain ($uconf{STARTING_TIME_STEP}[0] seconds) is larger ".
                    "than recommended ($ts06dx seconds). Consider reducing if failure in life persists or you are just having ".
                    "a bad day.\n\nAnd check the value for any other domains while you're at it.";
            &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,"Attitude adjustment time (step)",$mesg);
        }
        @{$Domains{starting_time_step}}    = @{$uconf{STARTING_TIME_STEP}};


        @{$uconf{MIN_TIME_STEP}} = ($ts02dx) unless $uconf{MIN_TIME_STEP}[0];

        if ($uconf{MIN_TIME_STEP}[0] > 0 and $uconf{MIN_TIME_STEP}[0] < $ts02dx) {
            $mesg = "Minimum adaptive timestep for the primary domain ($uconf{MIN_TIME_STEP}[0] seconds) is smaller ".
                    "than recommended ($ts02dx seconds). Consider increasing if failure in life persists or you are just having ".
                    "a bad day.\n\nAnd check the value for any other domains while you're at it.";
            &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,"Attitude adjustment time (step)",$mesg);
        }
        @{$Domains{min_time_step}}         = @{$uconf{MIN_TIME_STEP}};


        @{$uconf{MAX_TIME_STEP}} = ($ts15dx) unless $uconf{MAX_TIME_STEP}[0];

        if ($uconf{MAX_TIME_STEP}[0] > 0 and $uconf{MAX_TIME_STEP}[0] > $ts15dx) {
            $mesg = "Maximum adaptive timestep for the primary domain ($uconf{MAX_TIME_STEP}[0] seconds) is larger ".
                    "than recommended ($ts15dx seconds). Consider reducing if failure in life persists or you are just having ".
                    "a bad day.\n\nAnd check the value for any other domains while you're at it.";
            &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,"Attitude adjustment time (step)",$mesg);
        }
        @{$Domains{max_time_step}}         = @{$uconf{MAX_TIME_STEP}};


        @{$Domains{max_step_increase_pct}} = @{$uconf{MAX_STEP_INCREASE_PCT}};
        @{$Domains{target_hcfl}}           = @{$uconf{TARGET_HCFL}};
        @{$Domains{target_cfl}}            = @{$uconf{TARGET_CFL}};

        @{$Domains{step_to_output_time}}   = @{$uconf{STEP_TO_OUTPUT_TIME}};

    }


return;
}  #  Domains_Timing


sub Domains_Realinit {
# ==============================================================================================
# WRF REAL INITIALIZATION &DOMAINS NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   Below you will find configuration options for the vertical interpolation of the
#   (WPS) initialization data during the first step in ems_run. During this process
#   the WRF "real" program interpolates the fields on original (pressure) levels to
#   the native model levels. In addition, the program creates the initial and
#   boundary condition files used by the simulation for each included domain.
#
# ==============================================================================================
# ==============================================================================================
#
    my $mesg    = qw{};
    my %renv    = %{$Rconf{rtenv}};   #  Contains the  local configuration
    my %dinfo   = %{$Rconf{dinfo}};  #  just making things easier
    my %uconf   = %{$Config{uconf}};


    #  ------------------------------------------------------------------------
    #  WRF REAL program vertical interpolation/extrapolation options
    #  ------------------------------------------------------------------------
    #

    #   Option:  USE_MAXW_LEVEL  & USE_TROP_LEVEL - Include the maximum level wind and tropopause level 
    #                                               information during vertical interpolation
    #
    #   Values:
    #
    #     0 - Exclude maximum level wind information
    #     1 - Include maximum level wind information
    #
    #   Note:  The use of maximum level wind and tropopause information is relatively new and assumes 
    #          that this information has been extracted from the dataset used for initialization. This
    #          means that the fields must be available in the original GRIB files and identified in the 
    #          corresponding Vtable. If you don't see maximum level wind information contained in the
    #          output from WPS (use "rdwrfnc -m <WPS output file>") then this setting is useless.
    #
    #          Also - The default in the ARW user's guide is to exclude the information (0), but I think
    #          it is a good idea so the default is to include maximum level wind information in the EMS.
    #
    #   Default: USE_MAXW_LEVEL & USE_TROP_LEVEL = 0
    #
    @{$Domains{use_maxw_level}} = @{$uconf{USE_MAXW_LEVEL}};
    @{$Domains{use_trop_level}} = @{$uconf{USE_TROP_LEVEL}};


    if ($Domains{use_maxw_level}[0])  { #  Use the maximum wind level data - Make sure it exists

        if (%{$renv{wpsfls}}) {  #  No WPS files, No data
            my $umaxw = &Others::ReadVariableNC("$renv{wpsprd}/$renv{wpsfls}{1}[0]",'FLAG_UMAXW')   ? 1 : 0;
            my $vmaxw = &Others::ReadVariableNC("$renv{wpsprd}/$renv{wpsfls}{1}[0]",'FLAG_VMAXW')   ? 1 : 0;
            my $pmaxw = &Others::ReadVariableNC("$renv{wpsprd}/$renv{wpsfls}{1}[0]",'FLAG_PMAXW')   ? 1 : 0;
            my $tmaxw = &Others::ReadVariableNC("$renv{wpsprd}/$renv{wpsfls}{1}[0]",'FLAG_TMAXW')   ? 1 : 0;
            my $zmaxw = &Others::ReadVariableNC("$renv{wpsprd}/$renv{wpsfls}{1}[0]",'FLAG_HGTMAXW') ? 1 : 0;
            my $nmaxw = &Others::ReadVariableNC("$renv{wpsprd}/$renv{wpsfls}{1}[0]",'FLAG_PMAXWNN') ? 1 : 0;

            unless ($umaxw*$vmaxw*$pmaxw) {
                $mesg = "Although you requested the inclusion of maximum wind level information in the initialization, it appears that ".
                        "the data are not available in the WPS files located in the wpsprd directory. You can take a look for yourself ".
                        "with the \"rdwrfnc\" utility, i.e, \"rdwrfnc -m <WPS file>\". The necessary fields include PMAXW, UMAXW, PMAXW, ".
                        "TMAXW, HGTMAXW, and PMAXWNN.\n\n".
                        "Alternatively, you can set USE_MAXW_LEVEL = 0 (OFF) in run_wrfreal.conf.";
                $ENV{RMESG} = &Ecomm::TextFormat(0,0,86,0,0,'No Max Wind Level Data For YOU!',$mesg);
                return 1;
            }

        }


        #   Option:  MAXW_HORIZ_PRES_DIFF - Pressure threshold (Pa) for using the level of max winds
        #
        #   Notes:   For using the level of max winds, when the pressure difference between
        #            neighboring values exceeds this maximum, the variable is NOT included
        #            in the vertical interpolation.
        #
        #
        #   Default: MAXW_HORIZ_PRES_DIFF = 5000 (Pa)
        #
        @{$Domains{maxw_horiz_pres_diff}}  = @{$uconf{MAXW_HORIZ_PRES_DIFF}}  ? @{$uconf{MAXW_HORIZ_PRES_DIFF}}   : (5000);


        #   Option:  MAXW_ABOVE_THIS_LEVEL - Minimum pressure (Pa) to allow using the level of max wind info
        #
        #   Notes:   If value is 300 hPa (30000 Pa), then a max wind value at 500 hPa will be ignored.
        #
        #   Default: MAXW_ABOVE_THIS_LEVEL = 30000 (Pa)
        #
        @{$Domains{maxw_above_this_level}} = @{$uconf{MAXW_ABOVE_THIS_LEVEL}} ? @{$uconf{MAXW_ABOVE_THIS_LEVEL}}  : (30000);

    }


    if ($Domains{use_trop_level}[0])  { #  Use the tropopause level data - Make sure it exists


        if (%{$renv{wpsfls}}) {  #  No WPS files, No data
            my $utrop = &Others::ReadVariableNC("$renv{wpsprd}/$renv{wpsfls}{1}[0]",'FLAG_UTROP')   ? 1 : 0;
            my $vtrop = &Others::ReadVariableNC("$renv{wpsprd}/$renv{wpsfls}{1}[0]",'FLAG_VTROP')   ? 1 : 0;
            my $ptrop = &Others::ReadVariableNC("$renv{wpsprd}/$renv{wpsfls}{1}[0]",'FLAG_PTROP')   ? 1 : 0;
            my $ttrop = &Others::ReadVariableNC("$renv{wpsprd}/$renv{wpsfls}{1}[0]",'FLAG_TTROP')   ? 1 : 0;
            my $ztrop = &Others::ReadVariableNC("$renv{wpsprd}/$renv{wpsfls}{1}[0]",'FLAG_HGTTROP') ? 1 : 0;
            my $ntrop = &Others::ReadVariableNC("$renv{wpsprd}/$renv{wpsfls}{1}[0]",'FLAG_PTROPNN') ? 1 : 0;

            unless ($utrop*$vtrop*$ptrop) {
                $mesg = "Although you requested the inclusion of tropopause level information in the initialization, it appears that ".
                        "the data are not available in the WPS files located in the wpsprd directory. You can take a look for yourself ".
                        "with the \"rdwrfnc\" utility, i.e, \"rdwrfnc -m <WPS file>\". The necessary fields include PTROP, UTROP, PTROP, ".
                        "TTROP, HGTTROP, and PTROPNN.\n\n".
                        "Alternatively, you can set USE_TROP_LEVEL = 0 (OFF) in run_wrfreal.conf.";
                $ENV{RMESG} = &Ecomm::TextFormat(0,0,86,0,0,'No Tropopause Level Data For YOU!',$mesg);
                return 1;
            }
        }


        #   Option:  TROP_HORIZ_PRES_DIFF - Pressure threshold (Pa) for using tropopause level winds
        #
        #   Notes:   For using the tropopause level, when the pressure difference between
        #            neighboring values exceeds this maximum, the variable is NOT included
        #            in the vertical interpolation.
        #
        #   Default: TROP_HORIZ_PRES_DIFF = 5000 (Pa)
        #
        @{$Domains{trop_horiz_pres_diff}}  = @{$uconf{TROP_HORIZ_PRES_DIFF}}  ? @{$uconf{TROP_HORIZ_PRES_DIFF}}   : (5000);

    }


    #   Option:  USE_SURFACE - Specifies whether to use surface data in the vertical interpolation
    #
    #   Values:
    #
    #     F - Do not use the input surface data
    #     T - Use the input surface data
    #
    #   Default: USE_SURFACE = T
    #
    @{$Domains{use_surface}} = @{$uconf{USE_SURFACE}} ? @{$uconf{USE_SURFACE}}  : ('T');



    #   Option:  USE_INPUT_W - Specifies whether to use vertical velocity from input file
    #
    #   Values:
    #
    #     F - Do not use the input vertical motion
    #     T - Use the input vertical motion
    #
    #   Default: USE_INPUT_W = F
    #
    @{$Domains{use_input_w}} = @{$uconf{USE_INPUT_W}} ? @{$uconf{USE_INPUT_W}}  : ('F');



    #   Option:  FORCE_SFC_IN_VINTERP - Include surface level as the lower boundary for first 
    #                                   FORCE_SFC_IN_VINTERP eta levels
    #
    #   Notes:   The FORCE_SFC_IN_VINTERP defines the of vertical eta levels, from the bottom
    #            of the domain, over which to include the surface data during interpolation.
    #
    #   Values:
    #
    #     N - Some integer value from 0 to LEVELS
    #
    #   Default: FORCE_SFC_IN_VINTERP = 0 if USE_SURFACE = F  (Not used)
    #            FORCE_SFC_IN_VINTERP = 2 if USE_SURFACE = T
    #
    @{$Domains{force_sfc_in_vinterp}}  = @{$uconf{FORCE_SFC_IN_VINTERP}} if $Domains{use_surface}[0] eq 'T';



    #   Option:  INTERP_TYPE - Method used for the vertical interpolation of variables
    #
    #   Values:
    #
    #     1 - Linear in pressure
    #     2 - Linear in log pressure
    #
    #   Default: INTERP_TYPE = 2
    #
    @{$Domains{interp_type}}  = @{$uconf{INTERP_TYPE}}  ? @{$uconf{INTERP_TYPE}}   : (2);



    #   Option:  EXTRAP_TYPE - Method used to extrapolate non-temperature variables below ground
    #
    #   Values:
    #
    #     1 - Extrapolate using the two lowest levels
    #     2 - Use lowest level as constant value below ground
    #
    #   Default: EXTRAP_TYPE = 2
    #
    @{$Domains{extrap_type}}  = @{$uconf{EXTRAP_TYPE}}  ? @{$uconf{EXTRAP_TYPE}}   : (2);



    #   Option:  T_EXTRAP_TYPE - Method used to extrapolate temperature variables below ground
    #
    #   Values:
    #
    #     1 - Isothermal extrapolation
    #     2 - Constant lapse rate of -6.5 K/km
    #     3 - Constant Theta extrapolation
    #
    #   Default: T_EXTRAP_TYPE = 2
    #
    @{$Domains{t_extrap_type}}  = @{$uconf{T_EXTRAP_TYPE}}  ? @{$uconf{T_EXTRAP_TYPE}}   : (2);



    #   Option:  USE_LEVELS_BELOW_GROUND - Whether to use below surface levels during interpolation
    #
    #     T - Use input isobaric levels below input surface
    #     F - Extrapolate when WRF location is below input surface level
    #
    #   Default: USE_LEVELS_BELOW_GROUND = T
    #
    @{$Domains{use_levels_below_ground}}  = @{$uconf{USE_LEVELS_BELOW_GROUND}}  ? @{$uconf{USE_LEVELS_BELOW_GROUND}}   : ('T');


    # ------------------------------------------------------------------------
    # Ancillary Configurations You Don't Need to Worry About
    # ------------------------------------------------------------------------
    #

    #   Option:  LAGRANGE_ORDER - Specifies the vertical interpolation order used
    #
    #   Values:
    #
    #     1 - Linear
    #     2 - Quadratic
    #     9 - Cubic spline
    #
    #   Default: LAGRANGE_ORDER = 9
    #
    @{$Domains{lagrange_order}}  = @{$uconf{LAGRANGE_ORDER}}  ? @{$uconf{LAGRANGE_ORDER}}   : (9);



    #   Option:  LOWEST_LEV_FROM_SFC  - Specifies whether to assign surface values to lowest model level
    #
    #   Values:
    #
    #     T - Use surface values for the lowest eta (u,v,t,q)
    #     F - No, use traditional interpolation
    #
    #   Default: LOWEST_LEV_FROM_SFC = F
    #
    @{$Domains{lowest_lev_from_sfc}}  = @{$uconf{LOWEST_LEV_FROM_SFC}}  ? @{$uconf{LOWEST_LEV_FROM_SFC}}   : ('F');



    #   Option:  ZAP_CLOSE_LEVELS -  Ignore isobaric level above surface if delta p (Pa) < zap_close_levels
    #
    #   Default: ZAP_CLOSE_LEVELS = 500 (Pa)
    #
    @{$Domains{zap_close_levels}}  = @{$uconf{ZAP_CLOSE_LEVELS}}  ? @{$uconf{ZAP_CLOSE_LEVELS}}   : (500.);



    #   Option:  SFCP_TO_SFCP - Use optional method for computing surface pressure
    #
    #   Values:
    #
    #     T - Use optional method
    #     F - Do not use optional method
    #
    #   Notes:   Optional method to compute model's surface pressure when incoming data only
    #            has surface pressure and terrain, but not sea-level pressure
    #
    #   Default:  SFCP_TO_SFCP = T
    #
    @{$Domains{sfcp_to_sfcp}}  = @{$uconf{SFCP_TO_SFCP}}  ? @{$uconf{SFCP_TO_SFCP}}   : ('T');



    #   Option:  SMOOTH_CG_TOPO - Smooth outer rows & columns of primary domain topography
    #
    #   Values:
    #
    #     T - Smooth the topography
    #     F - Do not smooth the topography
    #
    #   Default:  SMOOTH_CG_TOPO = T
    #
    @{$Domains{smooth_cg_topo}}  = @{$uconf{SMOOTH_CG_TOPO}}  ? @{$uconf{SMOOTH_CG_TOPO}}   : ('T');



    #   Option:  HYPSOMETRIC_OPT - Use an alternative method for computation of height (REAL) and pressure (WRF)
    #
    #   Values:
    #
    #     1 - Do not use alternative method
    #     2 - Use alternative method
    #
    #   Default:  HYPSOMETRIC_OPT = 2
    #
    @{$Domains{hypsometric_opt}}  = @{$uconf{HYPSOMETRIC_OPT}}  ? @{$uconf{HYPSOMETRIC_OPT}}   : (2);



    #   Option:  AGGREGATE_LU - whether to aggregate the grass, shrubs, trees in dominant landuse
    #
    #   Values:
    #
    #     T - Aggregate the grass, shrubs, trees in dominant landuse
    #     F - Do not aggregate the grass, shrubs, trees in dominant landuse
    #
    #   Default:  AGGREGATE_LU = F
    #
    @{$Domains{aggregate_lu}}  = ('T') if $uconf{AGGREGATE_LU}[0] eq 'T';;



    #   Option:  RH2QV_WRT_LIQUID - Compute RH with respect to water (true) or ice (false)
    #
    #   Values:
    #
    #     T - Compute RH with respect to water
    #     F - Compute RH with respect to ice
    #
    #   Default:  RH2QV_WRT_LIQUID = T
    #
    @{$Domains{rh2qv_wrt_liquid}}  = @{$uconf{RH2QV_WRT_LIQUID}}  ? @{$uconf{RH2QV_WRT_LIQUID}}   : ('T');



    #   Option:  RH2QV_METHOD - Method to use to computer mixing ratio from RH
    #
    #   Values:
    #
    #     1 - Use old MM5 method (NCAR Default)
    #     2 - Use WMO recommended method (EMS Default)
    #
    #   Default:  RH2QV_METHOD = 2
    #
    @{$Domains{rh2qv_method}}  = @{$uconf{RH2QV_METHOD}}  ? @{$uconf{RH2QV_METHOD}}   : (2);



    #   Option:  INTERP_THETA - Whether to vertically interpolate potential temperature
    #
    #   Values:
    #
    #     T - Vertically interpolate potential temperature
    #     F - Vertically interpolate temperature
    #
    #   Default:  INTERP_THETA = F
    #
    @{$Domains{interp_theta}}  = ('T') if $uconf{INTERP_THETA}[0] eq 'T';



    #   Option:  USE_TAVG_FOR_TSK - Use diurnally averaged surface temp as skin temp
    #
    #   Values:
    #
    #     T - Use diurnally averaged surface temp as skin temp
    #     F - Do Not use diurnally averaged surface temp as skin temp
    #
    #   Notes:   The diurnally averaged surface temp can be computed using avg_tsfc.exe. 
    #            May use this option when SKINTEMP is not present. 
    #
    #   Default:  USE_TAVG_FOR_TSK = F
    #
    @{$Domains{use_tavg_for_tsk}}  = ('T') if $uconf{USE_TAVG_FOR_TSK}[0] eq 'T';


    #   Option:  ADJUST_HEIGHTS - T/F adjust pressure level input to match 500 mb height
    #
    #   Values:
    #
    #     T - Adjust pressure level input to match 500 mb height
    #     F - Do Not adjust pressure level input to match 500 mb height
    #
    #   Notes:  Used for processing of data from WPS with WRF real only.
    #           Also, if hypsometric_opt = 2, then ADJUST_HEIGHTS = F (check_a_mundo.F)
    #
    #   Default: ADJUST_HEIGHTS = F
    #
    @{$Domains{adjust_heights}}  =  @{$uconf{ADJUST_HEIGHTS}};




    #-----------------------------------------------------------------------------------
    #  Horizontal interpolation options, coarse grid to fine grid
    #-----------------------------------------------------------------------------------
    #

    #   Option:  INTERP_METHOD_TYPE - Alternative method for large parent:child ratios
    #
    #   Values:
    #
    #     1 - Bi-linear interpolation
    #     2 - Smolarkiewicz "SINT" method (default)
    #     3 - Nearest-neighbor - only to be used for testing purposes
    #     4 - Overlapping quadratic
    #    12 - Uses SINT horizontal interpolation, and same scheme for computation of FG lateral boundaries
    #
    #   Default:  INTERP_METHOD_TYPE = 2
    #
    @{$Domains{interp_method_type}}  = @{$uconf{INTERP_METHOD_TYPE}}  unless $uconf{INTERP_METHOD_TYPE}[0] == 2;


return;
} 


sub Domains_Nesting {
# ==============================================================================================
# WRF NESTING &DOMAINS SECTION CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME (FROM THE WRF USER GUIDE):
#
#   A two-way nested run is a run in which multiple domains at different grid 
#   resolutions are run simultaneously and communicate with each other. The
#   coarser domain provides the boundary values for the nest, and the nest feeds
#   its calculation back to the coarser domain. The model can handle multiple
#   domains at the same nest level (no overlapping nest), and multiple nest
#   levels (telescoping).  
#
# ==============================================================================================
# ==============================================================================================
#
    my @rundoms = sort {$a <=> $b} keys %{$Rconf{dinfo}{domains}};


    if (@rundoms > 1) {

        @{$Domains{feedback}}       = &Config_feedback();
        @{$Domains{smooth_option}}  = &Config_smooth_option() if $Domains{feedback}[0];

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

sub Config_feedback {
# ==================================================================================
#   Option: FEEDBACK - Passing of information between parent and child domains
#
#   Values:
#
#     0 - Only 1-way exchange of information from Parent to child domain
#     1 - Turns ON 2-way exchange of information between parent and child domains
#
#   Notes:  The FEEDBACK parameter determines whether to pass prognostic information
#           from a child domain back to the parent during a simulation (2-way).
#           Two-way feedback will only be allowed if you are using an ODD PARENT-TO-NEST
#           grid spacing ratio.
#
#           When feedback is ON, the values of the coarse domain are overwritten by
#           the values of the variables (average of cell values for mass points, and
#           average of the cell-face values for horizontal momentum points) in the
#           nest at the coincident points. For masked fields, only the single point
#           value at the collocating points is feedback.
#
#           If FEEDBACK = 0, then the exchange of information will only be 1-way, that
#           is, from parent to child, in which case the outer (parent) domain provides
#           the lateral boundary conditions to the inner domain.
#
#           If You are Nudging: If you are using 3D analysis nudging with your nested simulation
#                               then you might consider setting 2-way nesting OFF or the UEMS
#                               sheriff will do it for you.
#
#           Finally, if you are nesting from a parent domain with CU_PHYSICS ON to a child domain
#           with explicit precipitation (CU_PHYSICS OFF), FEEDBACK will automatically be set to
#           1-way nesting.  This will be addressed in ARWfinal.pm
#
#   Default: FEEDBACK = 0 (1-way nesting)
# ==================================================================================
#
    my @feedback = @{$Config{uconf}{FEEDBACK}};

return @feedback;
}


sub Config_smooth_option {
# ==================================================================================
#   Option: SMOOTH_OPTION - Smoothing option for parent domain with 2-way nesting
#
#   Values:
#
#     0 - No smoothing
#     1 - 1-2-1 smoothing technique
#     2 - Smoothing-Desmoothing technique
#
#   Notes:  This option is only used if 2-way feedback is turned ON
#
#   Default: SMOOTH_OPTION = 2 (When feedback is ON)
# ==================================================================================
#
    my @smooth_option = @{$Config{uconf}{SMOOTH_OPTION}};

return @smooth_option;
}


sub Domains_Levels {
# ==============================================================================================
# WRF LEVELS &DOMAINS SECTION CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   Below you will find configuration options for the various parameters related to the 
#   vertical structure of a simulation. Just "levels" stuff.
#
# ==============================================================================================
# ==============================================================================================
#
use List::Util qw[min max];

    my $mesg    = qw{};
    my %renv    = %{$Rconf{rtenv}};   #  Contains the  local configuration
    my %dinfo   = %{$Rconf{dinfo}};  #  just making things easier
    my %uconf   = %{$Config{uconf}};


    #   Option:  LEVELS (E_VERT and/or ETA_LEVELS)
    #
    #     LEVELS is used to defined the number and/or the vertical distribution of
    #     the levels to be used in your simulation. Note that ALL the domains will
    #     use the same vertical structure. No need to get silly.
    #
    #     The value specified to LEVELS may either be a single integer, which simply
    #     represents the number of levels to be used in the simulation OR a series
    #     of values representing individual model ETA levels separated by a comma (,).
    #
    #     If you choose to specify the number of vertical levels with a single integer
    #     value, e.g. LEVELS = 45, the WRF real program will use this value to generate
    #     a set of well-spaced levels. However, the number of levels is up to you.
    #     The default value for LEVELS is 45 but feel free to increase this value as
    #     necessary. THIS IS THE RECOMMENDED METHOD.
    #
    #     If you feel that you must manually define the vertical structure of the
    #     model domain, then simply provide a list of whole ETA level values, ranging
    #     from 1. to 0. (inclusive) separated by a commas (,). Here is an example
    #     for a model domain with 35 levels:
    #
    #       LEVELS = 1.000, 0.993, 0.983, 0.970, 0.954, 0.934, 0.909, 0.880,
    #                0.845, 0.807, 0.765, 0.719, 0.672, 0.622, 0.571, 0.520,
    #                0.468, 0.420, 0.376, 0.335, 0.298, 0.263, 0.231, 0.202,
    #                0.175, 0.150, 0.127, 0.106, 0.088, 0.070, 0.055, 0.040,
    #                0.026, 0.013, 0.000
    #
    #     Using the --levels command line option:
    #
    #     The --levels command line option serves to override the LEVELS parameter
    #     in this file. The only difference is that  --levels ONLY accepts the
    #     number of levels and not the vertical distribution.
    #
    #     Failing to define the number of vertical levels by any method will force
    #     ems_run to use the default value (45).
    #
    #     Finally, just remember that increasing the number of levels will
    #     proportionally increase the amount of time required to run your simulation.
    #
    #     DEVELOPERS NOTE:  The "--levels" flag was applied in ProcessLocalConfiguration
    #
    #   Default: LEVELS = 45  (Because the value seems reasonable)
    #
    my @levels = split /,\s*/ => $uconf{LEVELS}[0];

    @levels = &Others::rmdups(@levels);  #  Eliminate duplicates
    @levels = sort {$b <=> $a} @levels;  #  Make sure in ascending order


    #  DOMAINS Variable:  E_VERT and/or ETA_LEVELS
    #
    $Domains{e_vert}[0] = (@levels > 1) ? @levels : $levels[0];


    if (@levels > 1) { #  Assume the user has specified the vertical structure

        #  Make sure the first eta level above the surface is not too shallow
        #
        if ($levels[1] > 0.9985) {
            my $el = $levels[0] - $levels[1];
            $mesg = "Your first eta layer is too shallow ($el), which may cause your simulation to crash. Unless you are into ".
                    "that sort of thing (the UEMS never judges), you might consider decreasing the value of the first eta level ".
                    "below the $levels[1] you are currently using.";
            &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,'First Eta Layer Too Shallow',$mesg);
        }
        @{$Domains{eta_levels}} = @levels;
    }


    #  Provide a sanity check for the users who chose far too few vertical levels
    #  for the author's recommendation.  Get nasty if necessary.
    #
    $mesg = "You really need to have more than $Domains{e_vert}[0] vertical levels to make this model'n thingy work. ".
            "Now go back and try it again with more levels and I'll keep this issue between you and me.\n\n".
            "And just so you know, the default is 45 levels.";
    if ($Domains{e_vert}[0] < 15) {
        $mesg = "You really need to have more than $Domains{e_vert}[0] vertical levels to make this model'n thingy work. ".
                "Now go back and try it again with more levels and I'll keep this issue between you and me.\n\n".
                "And just so you know, the default is 45 levels.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,84,0,0,'"Hey You Kids, Get Off My Model!"',$mesg);
        return 1;
    }


    $mesg = "Do you really only want to use only $Domains{e_vert}[0] levels to define the vertical structure of your ".
            "simulation?  I just hope you know what you are doing.";
   
    if ($Domains{e_vert}[0] < 31) {
        $mesg = "Do you really only want to use only $Domains{e_vert}[0] levels to define the vertical structure of your ".
                "simulation?  I just hope you know what you are doing.";
        &Ecomm::PrintMessage(6,11+$Rconf{arf},84,1,2,'Are You Sure About This?',$mesg);
        @{$Domains{max_dz}} = (1000.);
    }

    
    #  While we are in the neighborhood
    #
    @{$Domains{e_vert}} = ($Domains{e_vert}[0]) x $Config{maxdoms};
    @{$Domains{s_vert}} = (1) x $Config{maxdoms};



    if (%{$renv{wpsfls}}) {  #  No WPS files, No data

        #  DOMAINS Variable:  NUM_METGRID_LEVELS
        #
        @{$Domains{num_metgrid_levels}} = (defined $renv{nilevs} and $renv{nilevs}) ? ($renv{nilevs}) : (0);

        unless ($Domains{num_metgrid_levels}[0]) {
            $mesg = "Unable to determine number of pressure levels in $renv{wpsfls}{1}[0]";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,84,0,0,'From Your EMS Doctor:',$mesg);
            return 1;
        }



        #  DOMAINS Variable:  NUM_METGRID_SOIL_LEVELS
        #
        #  Determine the number of soil levels available in the WPS files. The default is 4 levels
        #
        @{$Domains{num_metgrid_soil_levels}} = (defined $renv{nslevs} and $renv{nslevs}) ? ($renv{nslevs}) : (0);

        unless ($Domains{num_metgrid_soil_levels}[0]) {
            $mesg = "Unable to determine number of soil levels in $renv{wpsfls}{1}[0].";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,84,0,0,'From Your EMS Doctor:',$mesg);
            return 1;
        }
    }



    #  DOMAINS Variable:  P_TOP_REQUESTED
    #
    #  Make sure that the ptop pressure exists in each of the input files. If not, then look
    #  for the lowest pressure level contained in each of the WPS files and use that value; 
    #  however, there's a catch.  In the case of a hybrid coordinate dataset, such as with 
    #  the RAP or HRRR, the pressure levels are in reverse order, from N (first level above
    #  surface) to 2 (top level). Level 1 is the surface (more confusion).  All pressure
    #  coordinate datasets, such as the GFS, go from 1 (lowest level) to N (top)
    #    
    #  Since the data used to populate the top level of initialization must be at or above 
    #  the pressure level defined by p_top_requested (PTOP), we must search for the 
    #  dataset PRES field level with the lowest maximum pressure values at or above 
    #  PTOP.  Got that?  This kludge all because of RAP & HRRR.
    #
    #  While there may be a clue in the namelist.wps fg_name field, multiple dataset names 
    #  do not necessarily indicate separate IC & BC sources since the source of the LSM 
    #  fields may also be listed.  Drats!
    #
    my $ptop = ($uconf{PTOP}[0] == -1) ? 0 : $uconf{PTOP}[0];  #  Temporary, unless it isn't

    if (%{$renv{wpsfls}}) {

         my %ptop0 = ();
         my %ptop1 = ();

         #  There are a few nuggets of information that can be gleaned from the fg_name 
         #  fields in namelist.wps (really, just 1). If there is just one dataset listed
         #  then we only need to interrogate the first WPS file. Additionally, if there
         #  is only one wpsfls (global simulation) then we can stop with the one file.
         #
         %ptop0 = &Others::ReadVariableNC_LevsMaxMin("$renv{wpsprd}/$renv{wpsfls}{1}[0]",'PRES');
         %ptop1 = $renv{global} ? %ptop0 : &Others::ReadVariableNC_LevsMaxMin("$renv{wpsprd}/$renv{wpsfls}{1}[1]",'PRES');

         #  Now get the minimum of the maximum values at each pressure level
         #
         my @pmax0 = sort {$a <=> $b } map { int $ptop0{$_}{max} } keys %ptop0; @pmax0 = (0) unless @pmax0;
         my @pmax1 = sort {$a <=> $b } map { int $ptop1{$_}{max} } keys %ptop1; @pmax1 = (0) unless @pmax1;

         $ptop = max (max($pmax0[0], $pmax1[0]), $ptop); 

         $ptop++ while $ptop%500;
         $ptop++ while $ptop%2500 and $ptop >= 2500;

         if ($uconf{PTOP}[0] > 0 and $ptop != $uconf{PTOP}[0]) {

             $mesg = "You know what's good for you, and so does the UEMS. Consequently, the UEMS Oligarchs will ".
                     "use $ptop pascals as the pressure at the top of your model domain rather than the $uconf{PTOP}[0] ".
                     "pascals specified in run_levels.conf (PTOP). This programmatic overreach is due to the lack of data ".
                     "at or above the $uconf{PTOP}[0] pascal pressure level in the initialization data.\n\n".
                     "The UEMS - Looking out for your best interests so you can mess around!";

             &Ecomm::PrintMessage(6,11+$Rconf{arf},88,1,2,'Slight correction to PTOP needed',$mesg);

         }
         
    }
    @{$Domains{p_top_requested}} = ($ptop);


return 0;
}  #  Domains_Levels


sub Domains_Domain {
# ==============================================================================================
# WRF DOMAIN &DOMAINS NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   While the subroutine's name may seem redundant, none of the configuration below
#   has been done before. This subroutine does most of the final configuration 
#   for those parameters related to the computation domain in the '&domains' 
#   section of the namelist file. Get it? 'domain' & '&domains'?  Never mind.
#
# ==============================================================================================
# ==============================================================================================
#
use List::Util qw[min max first];

    my %renv    = %{$Rconf{rtenv}};   #  Contains the  local configuration
    my %dinfo   = %{$Rconf{dinfo}};  #  just making things easier

    
    #  Parameters: GRID_ID, PARENT_ID, PARENT_GRID_RATIO, DX, DY, E_WE, E_SN, I_PARENT_START,
    #              J_PARENT_START, GRID_ALLOWED, & PARENT_TIME_STEP_RATIO
    #
    #  Most of the following information was collested in the Rconf::ErunConfigureDomains 
    #  module for use here.
    #
    @{$Domains{max_dom}}           = ($Config{maxdoms});
    
    @{$Domains{grid_id}}           = map {$_}                          1..$Config{maxdoms};
    @{$Domains{parent_id}}         = map {$renv{geodoms}{$_}{parent}}  1..$Config{maxdoms};
    @{$Domains{parent_grid_ratio}} = map {$renv{geodoms}{$_}{pratio}}  1..$Config{maxdoms};
    
    @{$Domains{dx}}                = map {$renv{geodoms}{$_}{dx}}      1..$Config{maxdoms};
    @{$Domains{dy}}                = map {$renv{geodoms}{$_}{dy}}      1..$Config{maxdoms};

    @{$Domains{e_we}}              = map {$renv{geodoms}{$_}{nx}}      1..$Config{maxdoms};
    @{$Domains{e_sn}}              = map {$renv{geodoms}{$_}{ny}}      1..$Config{maxdoms};

    @{$Domains{i_parent_start}}    = map {$renv{geodoms}{$_}{ipstart}} 1..$Config{maxdoms};
    @{$Domains{j_parent_start}}    = map {$renv{geodoms}{$_}{jpstart}} 1..$Config{maxdoms};

    @{$Domains{s_we}}              = (1) x $Config{maxdoms};
    @{$Domains{s_sn}}              = (1) x $Config{maxdoms};

    @{$Domains{grid_allowed}}      = map {defined $dinfo{domains}{$_} ? 'T' : 'F'} 1..$Config{maxdoms};

    @{$Domains{parent_time_step_ratio}} = @{$Domains{parent_grid_ratio}};


return;
}  #  Domains_Domain


sub Domains_Final {
# ==============================================================================================
# WRF FINAL &DOMAINS  NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Subroutine that cleans up any loose ends within the &domains section of the WRF
#  namelist. Occasionally, variables require tweaks after everything else has been set.
#  This is the routine where it would be done if there were any to do, which there isn't.
#
# ==============================================================================================
# ==============================================================================================
#

    #  Currently nothing needed for the Domains section but thanks for visiting!
    #  The subroutine is here for consistency.
        

return;
}


sub Domains_Debug {
# ==============================================================================================
# &DOMAINS NAMELIST DEBUG ROUTINE
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  When the --debug 4+ flag is passed, prints out the contents of the WRF &domains
#  namelist section .
#
# ==============================================================================================
# ==============================================================================================
#   
    my @defvars  = ();
    my @ndefvars = ();
    my $nlsect   = 'domains'; #  Specify the namelist section to print out

    return unless $ENV{RUN_DBG} > 3;  #  Only for --debug 4+

    foreach (@{$ARWconf{nlorder}{$nlsect}}) {
        defined $Domains{$_} ? push @defvars => $_ : push @ndefvars => $_;
    }

    return unless @defvars or @ndefvars;

    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,13+$Rconf{arf},144,1,1,'Leaving &ARWdomains');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},194,1,0,sprintf('%-24s  = %s',$_,join ', ' => @{$Domains{$_}})) foreach @defvars;
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,' ');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-24s  = %s',$_,'Not Used')) foreach @ndefvars;
    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,2,'=' x 72);
        

return;
}


