#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ARWconfig.pm
#
#  DESCRIPTION:  ARWconfig manages the preliminary configuration duties prior
#                to calling the namelist specific subroutines. It's within 
#                this module that the values from the configuration files
#                are merged with the UEMS defaults (namelist.arw) and then
#                overridden by any command-line flags and options when 
#                available.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package ARWconfig;

use warnings;
use strict;
require 5.008;
use English;

use Others;

use vars qw (%Rconf %Config %ARWconf);


sub NamelistControlARW {
# ==============================================================================================
# WRF NAMELIST PRE-CONFIGURATION DRIVER
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  This subroutine manages the configuration of the WRF ARW core namelist file. In 
#  addition, it also assigns some of the important hash values used throughout the
#  ARWconfigs module.  The process begins by setting values for ALL the ARW namelist
#  variables, whether they will be used or not. This is done by reading the local
#  parameter values within the configuration file. Those values are initially checked to
#  determine if they are valid and then assigned to the run-time namelist if required.
# ==============================================================================================
# ==============================================================================================
#
use ARW::ARWdfi;
use ARW::ARWfdda;
use ARW::ARWafwa;
use ARW::ARWfinal;
use ARW::ARWquilt;
use ARW::ARWstoch;
use ARW::ARWdiags;
use ARW::ARWdmpar;
use ARW::ARWtcntrl;
use ARW::ARWlogging;
use ARW::ARWdomains;
use ARW::ARWphysics;
use ARW::ARWbdycntrl;
use ARW::ARWdynamics;

use List::Util qw( max );

    my $href = shift; %Rconf = %{$href}; return () unless %Rconf;


    %ARWconf = ();  #  Hash to be returned      - global within ARWconf.pm module
    %Config  = ();  #  Local configuration hash - also global within ARWconf.pm module

    #---------------------------------------------------------------------
    #  Begin by reading in the default WRF ARW namelist file {default}. 
    #  This will used to populate the "live" version {emsrun}. Additionally,
    #  we will the proper order of the variables when writing out the file.
    #  This order is defined in namelist.arw as well.
    #---------------------------------------------------------------------
    #
    my $namelist = "$ENV{EMS_DATA}/tables/wrf/uems/namelist.arw";

    %{$ARWconf{namelist}}  = ();

    unless (%{$ARWconf{nlorder}} = &Others::NamelistOrder($namelist)) {
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,255,0,0,'In &NamelistControlARW',"BUMMER: Namelist file problem ($namelist)");
        return ();
    }


    unless (%{$Config{nldefault}} = &Others::Namelist2Hash($namelist)) {
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,255,0,0,'In &NamelistControlARW',"BUMMER: Problem reading $namelist");
        return ();
    }


   
    #---------------------------------------------------------------------
    #  $Config{maxdoms} will be used throughout the namelist configuration
    #  as the final domain for which information must be provided in the 
    #  namelist file. Note that it is NOT the last available domain, just
    #  the last one being used in the simulation.
    #---------------------------------------------------------------------
    #
    $Config{maxdoms}   = max keys %{$Rconf{dinfo}{domains}};
    $Config{maxdoms}   = 1 if $Config{maxdoms} < 1;  #  Should not happen though
    $Config{maxindex}  = $Config{maxdoms}-1;


    #---------------------------------------------------------------------
    #  It's also very helpful to have a parent index array so that 
    #  the array index of a child domain contains the array index of
    #  its parent.  This cleans up loops in which the parent value
    #  is used for a missing child value.
    #---------------------------------------------------------------------
    #
    @{$Config{parentidx}} = map {$Rconf{rtenv}{geodoms}{$_}{parent}-1} 1..$Config{maxdoms};


    #---------------------------------------------------------------------
    #  Next read the WRF ARW parameter key file that defines a variable
    #  as single or multi-value (max domains). This information is used
    #  by the &MainARW_FileConfigs setting values.
    #---------------------------------------------------------------------
    #
    my $namekeys = "$ENV{EMS_DATA}/tables/wrf/uems/arwconf_key.tbl";

    return () unless %{$Config{parmkeys}} = &ReadParmkeyFile($namekeys);


    #---------------------------------------------------------------------
    #  Read and process the local configuration files under conf/ems_run
    #---------------------------------------------------------------------
    #
    return () unless %{$Config{uconf}} = &ReadConfigurationFilesARW($Rconf{rtenv}{runconf});


    #---------------------------------------------------------------------
    #  If the --debug flag was used
    #---------------------------------------------------------------------
    #
    &MainNamelistDebugARW();

    #---------------------------------------------------------------------
    #  Before getting into the namelist configuration, process the
    #  MPI-related paremeters from the configuration files.  This
    #  information is placed in the %{$ARWconf{dmpar}} hash for
    #  use outside this module.
    #---------------------------------------------------------------------
    #
    return () unless %ARWconf = &ARWdmpar::Configure(\%ARWconf);


    #---------------------------------------------------------------------
    #  Now configure the individual sections in the WRF namelist file 
    #  used to run the simulation. Note that although the %ARWconf hash
    #  is passed, it doesn't have to be since it's global.
    #---------------------------------------------------------------------
    #
    return () unless %ARWconf = &ARWtcntrl::Configure(\%ARWconf);
    return () unless %ARWconf = &ARWfdda::Configure(\%ARWconf);  #  Must come before &ARWdomains for TS adjustment
    return () unless %ARWconf = &ARWdomains::Configure(\%ARWconf);
    return () unless %ARWconf = &ARWphysics::Configure(\%ARWconf);
    return () unless %ARWconf = &ARWdynamics::Configure(\%ARWconf);
    return () unless %ARWconf = &ARWdfi::Configure(\%ARWconf);
    return () unless %ARWconf = &ARWbdycntrl::Configure(\%ARWconf);
    return () unless %ARWconf = &ARWafwa::Configure(\%ARWconf);
    return () unless %ARWconf = &ARWstoch::Configure(\%ARWconf);
    return () unless %ARWconf = &ARWdiags::Configure(\%ARWconf);
    return () unless %ARWconf = &ARWquilt::Configure(\%ARWconf);
    return () unless %ARWconf = &ARWlogging::Configure(\%ARWconf);

   return () unless %ARWconf = &ARWfinal::Configure(\%ARWconf);


return %ARWconf;
}


sub ReadParmkeyFile {
#===========================================================================
#  A Mini routine to read the WRF ARW parameter key file
#===========================================================================
#
    my %parmkeys = ();
    my $namekeys = shift;

    unless (-e $namekeys) {
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,"Missing Parm Key File: $namekeys");
        return ();
    }

    my %hash = &Others::ReadConfigurationFile($namekeys);

    foreach my $parm (keys %hash) {
        my ($section, $maxdoms) = split /:/, $hash{$parm}, 2; $maxdoms = (defined $maxdoms and $maxdoms) ? $Config{maxdoms} : 1;
        $parmkeys{lc $parm}{section} = lc $section;
        $parmkeys{lc $parm}{maxdoms} = $maxdoms;
    }

return %parmkeys;
}


sub ReadConfigurationFilesARW {
# ==============================================================================================
# WRF SIMULATION LOCAL CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Collect the 236 configuration settings under the local conf/ems_run directory, which are
#  returned in a hash containing PARAMETER = @{VALUES}. Checks are made to ensure the values
#  are valid.  Note that the individual subroutines are not necessary but serve to organize
#  the parameters and break up the monotony, although I have yet to include them.
#
# ==============================================================================================
# ==============================================================================================
#
use List::Util 'sum';

    my $cdir  = shift; return () unless -d $cdir;

    #----------------------------------------------------------------------------------
    #  Read the local configuration files, which are returned in the %eparms hash.
    #----------------------------------------------------------------------------------
    #
    return () unless my %eparms = &Others::ReadLocalConfiguration($cdir); 


    #----------------------------------------------------------------------------------
    #  Now begin the process of checking the parameters for valid values. Each 
    #  parameter is checked for validity but are not crossed-checked with other
    #  parameters, which is done prior to the values being used. 
    #----------------------------------------------------------------------------------
    #
    my $mesg  = qw{};
    my $cval  = qw{}; #  Config Value
    my $fval  = qw{}; #  Flag Value
    my $dval  = qw{};
    my @opts  = ();
    my @fvals = ();
    my @rvals = ();
    my @dvals = ();
    my @cvals = ();


    #----------------------------------------------------------------------------------
    #  Just to keep track, the rtenv hash contains the following keys: 
    #
    #     albsi autoconf bdyfls bench conf core domname dompath emspid emsprd geodoms 
    #     geofls global grbdir icedpth inifls islake logdir maxmsf mminlu modis mproj 
    #     nilevs nlcats nslevs pexe postconf qnwfa reanl rstfls rstprd runconf snowsi 
    #     static wpsfls wpsnl wpsnlh wpsprd wrfnl wrfnlh wrfprd
    #----------------------------------------------------------------------------------
    #
    my %renv  = %{$Rconf{rtenv}};
    my %flags = %{$Rconf{flags}};
    my %defnl = %{$Config{nldefault}};  #  Default namelist values
    my %pkeys = %{$Config{parmkeys}};   #  The parameter keys


    #----------------------------------------------------------------------------------
    #  The %suites hash contains the physics suite configurations, which we want to
    #  set prior to going through all the configuration parameter checks. Note that
    #  this can be easily expanded in the future for other namelist suites as well.
    #----------------------------------------------------------------------------------
    #
    if ($eparms{PHYSICS_SUITE} and $eparms{PHYSICS_SUITE}[0]) {
        my %suites = &ReadSuiteConfigurationFile($cdir);
        my %suite  = ($suites{$eparms{PHYSICS_SUITE}[0]}) ? %{$suites{$eparms{PHYSICS_SUITE}[0]}} : ();
        @{$eparms{$_}} = @{$suite{$_}}  foreach keys %suite;
    }
    delete $eparms{PHYSICS_SUITE};


    #============================================================================
    #  RUN_NAMELIST: ALT_NAMELIST (single string)
    #============================================================================
    #
    $cval  = (defined $eparms{ALT_NAMELIST}[0] and $eparms{ALT_NAMELIST}[0]) ? $eparms{ALT_NAMELIST}[0]  : '';

    %eparms = &ReadAlternateNamelist(\%eparms) if $cval;  return () unless %eparms;


    #============================================================================
    #  RUN_NAMELIST: OVERRIDE:PARAMETERS - Separated by :
    #
    #  This needs to be at the end of the file because the values override 
    #  any values set above.
    #============================================================================
    #
    unless ($cval) {
        foreach my $eparm (grep {/:/} keys %eparms) {
            @rvals = @{$eparms{$eparm}} ? @{$eparms{$eparm}} : (); 
            my ($sect, $parm) = split /:/ => $eparm, 2;
            next unless $sect and $parm;
            next unless $defnl{uc $sect};
            @{$eparms{uc $parm}} = @rvals;
            delete $eparms{$eparm};
        }
    }


    #============================================================================
    #  RUN_DYNAMICS: NON_HYDROSTATIC (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{non_hydrostatic}[0]) ? $defnl{DYNAMICS}{non_hydrostatic}[0] : 'T';
    $cval  = (defined $eparms{NON_HYDROSTATIC} and $eparms{NON_HYDROSTATIC}[0]) ? $eparms{NON_HYDROSTATIC}[0] : $dval;

    @{$eparms{NON_HYDROSTATIC}}      = &SetValues_TrueFalse($cval,$dval,1);



    #============================================================================
    #  RUN_DYNAMICS: HYBRID_OPT (0|2)
    #============================================================================
    #
    @opts  = (0,2);
    $dval  = (defined $defnl{DYNAMICS}{hybrid_opt}[0]) ? $defnl{DYNAMICS}{hybrid_opt}[0] : 0;
    $cval  = (defined $eparms{HYBRID_OPT} and $eparms{HYBRID_OPT}[0]) ? $eparms{HYBRID_OPT}[0] : $dval;

    unless (grep {/^${cval}$/} @opts) {
        $mesg = "Your choice for HYBRID_OPT ($cval) is not valid - BOOO!  You will be using the original WRF ".
                "terrain following coordinate whether you like it or not.";
        &Ecomm::PrintMessage(6,11+$Rconf{arf},88,2,2,'Bad Vertical Coordinate Choice:', $mesg);
        $cval = $opts[0];
    }
    @{$eparms{HYBRID_OPT}}      = ($cval);



    #============================================================================
    #  RUN_DYNAMICS: ETAC (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{etac}[0]) ? $defnl{DYNAMICS}{etac}[0] : 0.20;
    $cval  = (defined $eparms{ETAC}[0])          ? $eparms{ETAC}[0]      : $dval;

    if ($eparms{HYBRID_OPT}[0]) {
        unless (&Others::isNumber($cval) and $cval > 0.10 and $cval < 0.30) {
            if ( ! &Others::isNumber($cval) or ($cval <= 0.05 or $cval >= 0.50) ) {
                $mesg = "Your value for ETAC in run_dynamics.conf ($cval) outside the recommended bounds. Resetting ".
                        "to ETAC = 0.20.";
                &Ecomm::PrintMessage(6,11+$Rconf{arf},88,2,2,'Bad ETAC Value:', $mesg);
                $cval  = 0.20;
            } else {
                $mesg = "Values for ETAC ($cval) in run_dynamics.conf should not vary much from the recommended ".
                        "value of 0.20 unless you enjoy the weight of failure on your shoulders.\n\nI'll just leave ".
                        "you to your self-inflicted misery.";
                &Ecomm::PrintMessage(6,11+$Rconf{arf},88,2,2,'Questionable ETAC Value:', $mesg);
            }
        }
    }
    @{$eparms{ETAC}} = ($cval);



    #============================================================================
    #  RUN_DYNAMICS: GWD_OPT  (0|1)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{gwd_opt}[0]) ? $defnl{DYNAMICS}{gwd_opt}[0] : 0;
    $cval  = (defined $eparms{GWD_OPT}[0])          ? $eparms{GWD_OPT}[0]         : $dval;

    @{$eparms{GWD_OPT}} = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  RUN_DYNAMICS: RK_ORD (2|3)
    #============================================================================
    #
    @opts  = (3,2);
    $dval  = (defined $defnl{DYNAMICS}{rk_ord}[0])            ? $defnl{DYNAMICS}{rk_ord}[0] : $opts[0];
    $cval  = (defined $eparms{RK_ORD} and $eparms{RK_ORD}[0]) ? $eparms{RK_ORD}[0]          : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{RK_ORD}} = ($cval);

    
    #=================================================================================================================================
    #  RUN_DYNAMICS: MOIST_ADV_OPT, SCALAR_ADV_OPT, CHEM_ADV_OPT, TKE_ADV_OPT (0-4) (Max Domains)
    #          NOTE: OPTIONS 1 & 4 INCLUDE POSITIVE DEFINITE ADVECTION
    #=================================================================================================================================
    #
    @opts = (1,2,3,4,0);
    foreach (qw(MOIST_ADV_OPT SCALAR_ADV_OPT CHEM_ADV_OPT TKE_ADV_OPT)) {
        $dval  = (defined $defnl{DYNAMICS}{lc $_}[0])     ? $defnl{DYNAMICS}{lc $_}[0] : $opts[0];
        $cval  = (defined $eparms{$_} and $eparms{$_}[0]) ? $eparms{$_}[0]            : $dval;
        $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

        @{$eparms{$_}} = ($cval) x $Config{maxdoms};
    }


    #============================================================================
    #  RUN_DYNAMICS: MOMENTUM_ADV_OPT (1|3) (Max Domains)
    #============================================================================
    #
    @opts  = (1,3);
    $dval  = (defined $defnl{DYNAMICS}{momentum_adv_opt}[0]) ? $defnl{DYNAMICS}{momentum_adv_opt }[0] : $opts[0];
    $cval  = (defined $eparms{MOMENTUM_ADV_OPT} and $eparms{MOMENTUM_ADV_OPT}[0]) ? $eparms{MOMENTUM_ADV_OPT}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{MOMENTUM_ADV_OPT}} = ($cval) x $Config{maxdoms};

        
    #=================================================================================================================================
    #  RUN_DYNAMICS: H_MOM_ADV_ORDER & H_SCA_ADV_ORDER (2-6) (Max Domains)
    #=================================================================================================================================
    #
    @opts = (5,2,3,4,6);
    foreach (qw(H_MOM_ADV_ORDER H_SCA_ADV_ORDER)) {
        $dval  = (defined $defnl{DYNAMICS}{lc $_}[0]) ? $defnl{DYNAMICS}{lc $_}[0] : $opts[0];
        $cval  = (defined $eparms{$_} and $eparms{$_}[0]) ? $eparms{$_}[0] : $dval;
        $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

        @{$eparms{$_}} = ($cval) x $Config{maxdoms};
    }


    #=================================================================================================================================
    #  RUN_DYNAMICS: V_MOM_ADV_ORDER & V_SCA_ADV_ORDER (2-6) (Max Domains)
    #=================================================================================================================================
    #
    @opts = (3,2,4,5,6);
    foreach (qw(V_MOM_ADV_ORDER V_SCA_ADV_ORDER)) {
        $dval  = (defined $defnl{DYNAMICS}{lc $_}[0]) ? $defnl{DYNAMICS}{lc $_}[0] : $opts[0];
        $cval  = (defined $eparms{$_} and $eparms{$_}[0]) ? $eparms{$_}[0] : $dval;
        $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

        @{$eparms{$_}} = ($cval) x $Config{maxdoms};
    }


    #============================================================================
    #  RUN_DYNAMICS: DIFF_OPT (0-2) (Max Domains)
    #============================================================================
    #
    @opts  = $renv{global} ? (0) : (1,0,2); #  Option 1 not valid with global domain
    @dvals = ($defnl{DYNAMICS}{diff_opt} and @{$defnl{DYNAMICS}{diff_opt}}) ? @{$defnl{DYNAMICS}{diff_opt}} : ($opts[0]);
    @cvals = ($eparms{DIFF_OPT} and @{$eparms{DIFF_OPT}})                   ? @{$eparms{DIFF_OPT}}          : @dvals;
    @rvals = ($cvals[-1]) x $Config{maxdoms};

    foreach (@cvals) {$_ = $opts[0] unless grep {/^${_}$/} @opts;}

    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{DIFF_OPT}} = @rvals[0..$Config{maxindex}];



    #============================================================================
    #  RUN_DYNAMICS: KM_OPT (1-4) (Max Domains)
    #============================================================================
    #
    @opts  = $renv{global} ? (0) : (4,1,2,3); # Not valid with global domain
    @dvals = ($defnl{DYNAMICS}{km_opt} and @{$defnl{DYNAMICS}{km_opt}}) ? @{$defnl{DYNAMICS}{km_opt}} : ($opts[0]);
    @cvals = ($eparms{KM_OPT} and @{$eparms{KM_OPT}})                   ? @{$eparms{KM_OPT}}          : @dvals;
    @rvals = ($cvals[-1]) x $Config{maxdoms};

    foreach (@cvals) {$_ = $opts[0] unless grep {/^${_}$/} @opts;}

    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{KM_OPT}} = @rvals[0..$Config{maxindex}];
    

    #============================================================================
    #  RUN_DYNAMICS: DIFF_6TH_OPT (0-2) (Max Domains)
    #  Defaults: DIFF_6TH_OPT = 2 if PDA; Otherwise DIFF_6TH_OPT = 0
    #============================================================================
    #
    @opts  = (grep {/^$eparms{SCALAR_ADV_OPT}[0]$/} (1,4)) ? (2,0) : (0,2);  #  Don't allow option 1 due to negative q

    $dval  = (defined $defnl{DYNAMICS}{diff_6th_opt}[0] and length $defnl{DYNAMICS}{diff_6th_opt}[0]) ? $defnl{DYNAMICS}{diff_6th_opt}[0] : $opts[0];
    $cval  = (defined $eparms{DIFF_6TH_OPT}[0] and length $eparms{DIFF_6TH_OPT}[0]) ? $eparms{DIFF_6TH_OPT}[0] : $opts[0];
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{DIFF_6TH_OPT}} = ($cval) x $Config{maxdoms};


    #============================================================================
    #  RUN_DYNAMICS: DIFF_6TH_FACTOR (value) (Max Domains)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{diff_6th_factor}[0]) ? $defnl{DYNAMICS}{diff_6th_factor}[0] : 0.25;
    $cval  = (defined $eparms{DIFF_6TH_FACTOR}[0])          ? $eparms{DIFF_6TH_FACTOR}[0]         : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval <= 1. and $cval >= 0.;

    @{$eparms{DIFF_6TH_FACTOR}} = ($cval) x $Config{maxdoms};


    #============================================================================
    #  RUN_DYNAMICS: DAMP_OPT (0-3)
    #
    #  DAMP_OPT = 2 for idealized cases only
    #============================================================================
    #
    @opts  = $renv{global} ? (3,0) : (0,1,3);
    $dval  = (defined $defnl{DYNAMICS}{damp_opt}[0]) ? $defnl{DYNAMICS}{damp_opt}[0] : $opts[0];
    $cval  = (defined $eparms{DAMP_OPT} and defined $eparms{DAMP_OPT}[0]) ? $eparms{DAMP_OPT}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{DAMP_OPT}} = ($cval);


    #============================================================================
    #  RUN_DYNAMICS: DAMPCOEF (value) (Max Domains)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{dampcoef}[0]) ? $defnl{DYNAMICS}{dampcoef}[0] : 0.2;
    @cvals = (defined $eparms{DAMPCOEF} and @{$eparms{DAMPCOEF}}) ? @{$eparms{DAMPCOEF}} : ($dval);
    foreach (@cvals) {$_ = $dval unless $_ and &Others::isNumber($_) and $_ <= 1.0;}
    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{DAMPCOEF}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_DYNAMICS: ZDAMP (value) (Max Domains)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{zdamp}[0]) ? $defnl{DYNAMICS}{zdamp}[0] : 5000.;
    @cvals = (defined $eparms{ZDAMP} and @{$eparms{ZDAMP}}) ? @{$eparms{ZDAMP}} : ($dval);
    foreach (@cvals) {$_ = $dval unless $_ and &Others::isNumber($_) and $_ > 0.;}
    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{ZDAMP}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_DYNAMICS: W_DAMPING  (0|1)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{w_damping}[0]) ? $defnl{DYNAMICS}{w_damping}[0] : 1;
    $cval  = (defined $eparms{W_DAMPING}[0])          ? $eparms{W_DAMPING}[0]          : $dval;

    @{$eparms{W_DAMPING}} = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  RUN_DYNAMICS: SMDIV (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{smdiv}[0]) ? $defnl{DYNAMICS}{smdiv}[0] : 0.10;
    $cval  = (defined $eparms{SMDIV}[0])      ? $eparms{SMDIV}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{SMDIV}} = ($cval);


    #============================================================================
    #  RUN_DYNAMICS: EMDIV (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{emdiv}[0]) ? $defnl{DYNAMICS}{emdiv}[0] : 0.01;
    $cval  = (defined $eparms{EMDIV}[0])      ? $eparms{EMDIV}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{EMDIV}} = ($cval);


    #============================================================================
    #  RUN_DYNAMICS: FFT_FILTER_LAT (value)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{fft_filter_lat}[0]) ? $defnl{DYNAMICS}{fft_filter_lat}[0] : 45.0;
    $cval  = (defined $eparms{FFT_FILTER_LAT}[0])          ? $eparms{FFT_FILTER_LAT}[0]         : $dval;
    
    @{$eparms{FFT_FILTER_LAT}} = (&Others::isNumber($cval) and abs $cval < 90. ) ? ($cval) : ($dval);


    #============================================================================
    #  RUN_DYNAMICS: USE_THETA_M  (0|1)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{use_theta_m}[0]) ? $defnl{DYNAMICS}{use_theta_m}[0] : 0;
    $cval  = (defined $eparms{USE_THETA_M}[0])          ? $eparms{USE_THETA_M}[0]          : $dval;

    $cval  = 0 if $Config{maxdoms} > 1;  # USE_THETA_M can't be used with nests

    @{$eparms{USE_THETA_M}} = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  RUN_DYNAMICS: USE_Q_DIABATIC  (0|1)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{use_q_diabatic}[0]) ? $defnl{DYNAMICS}{use_q_diabatic}[0] : 0;
    $cval  = (defined $eparms{USE_Q_DIABATIC}[0])          ? $eparms{USE_Q_DIABATIC}[0]          : $dval;

    @{$eparms{USE_Q_DIABATIC}} = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  RUN_DYNAMICS: MIX_FULL_FIELDS (T|F) (Max Domains)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{mix_full_fields}[0]) ? $defnl{DYNAMICS}{mix_full_fields}[0] : 'T';
    $cval  = (defined $eparms{MIX_FULL_FIELDS} and $eparms{MIX_FULL_FIELDS}[0]) ? $eparms{MIX_FULL_FIELDS}[0] : $dval;

    @{$eparms{MIX_FULL_FIELDS}}     = &SetValues_TrueFalse($cval,$dval,$Config{maxdoms});


    #============================================================================
    #  RUN_DYNAMICS: TKE_DRAG_COEFFICIENT (value) (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{DYNAMICS}{tke_drag_coefficient} and @{$defnl{DYNAMICS}{tke_drag_coefficient}}) ? @{$defnl{DYNAMICS}{tke_drag_coefficient}} : (0.0013);
    @cvals = ($eparms{TKE_DRAG_COEFFICIENT} and @{$eparms{TKE_DRAG_COEFFICIENT}})                    ? @{$eparms{TKE_DRAG_COEFFICIENT}}         : @dvals;

    foreach (@cvals) {$_ = $dvals[0] unless $_ and &Others::isNumber($_) and $_ >= 0;}
    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{TKE_DRAG_COEFFICIENT}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_DYNAMICS: TKE_HEAT_FLUX (value) (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{DYNAMICS}{tke_heat_flux} and @{$defnl{DYNAMICS}{tke_heat_flux}}) ? @{$defnl{DYNAMICS}{tke_heat_flux}} : (0.02);
    @cvals = ($eparms{TKE_HEAT_FLUX} and @{$eparms{TKE_HEAT_FLUX}})                    ? @{$eparms{TKE_HEAT_FLUX}} : @dvals;

    foreach (@cvals) {$_ = $dvals[0] unless $_ and &Others::isNumber($_) and $_ >= 0;}
    @rvals = ($cvals[-1]) x $Config{maxdoms};

    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{TKE_HEAT_FLUX}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_DYNAMICS: KHDIF (value) (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{DYNAMICS}{khdif} and @{$defnl{DYNAMICS}{khdif}}) ? @{$defnl{DYNAMICS}{khdif}} : (1.);
    @cvals = ($eparms{KHDIF} and @{$eparms{KHDIF}})                    ? @{$eparms{KHDIF}}          : @dvals;

    foreach (@cvals) {$_ = $dvals[0] unless $_ and &Others::isNumber($_) and $_ >= 0;}
   
    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{KHDIF}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_DYNAMICS: KVDIF (value) (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{DYNAMICS}{kvdif} and @{$defnl{DYNAMICS}{kvdif}}) ? @{$defnl{DYNAMICS}{kvdif}} : (1.);
    @cvals = ($eparms{KVDIF} and @{$eparms{KVDIF}})                    ? @{$eparms{KVDIF}}          : @dvals;

    foreach (@cvals) {$_ = $dvals[0] unless $_ and &Others::isNumber($_) and $_ >= 0;}

    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{KVDIF}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_DYNAMICS: MIX_UPPER_BOUND (value) (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{DYNAMICS}{mix_upper_bound} and @{$defnl{DYNAMICS}{mix_upper_bound}}) ? @{$defnl{DYNAMICS}{mix_upper_bound}} : (0.1);
    @cvals = ($eparms{MIX_UPPER_BOUND} and @{$eparms{MIX_UPPER_BOUND}})                    ? @{$eparms{MIX_UPPER_BOUND}}          : @dvals;

    foreach (@cvals) {$_ = $dvals[0] unless $_ and &Others::isNumber($_) and $_ >= 0;}
    
    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{MIX_UPPER_BOUND}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_DYNAMICS: EPSSM (value) (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{DYNAMICS}{epssm} and @{$defnl{DYNAMICS}{epssm}}) ? @{$defnl{DYNAMICS}{epssm}} : (0.1);
    @cvals = ($eparms{EPSSM} and @{$eparms{EPSSM}})                    ? @{$eparms{EPSSM}}          : @dvals;

    foreach (@cvals) {$_ = $dvals[0] unless $_ and &Others::isNumber($_) and $_ >= 0;}

    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{EPSSM}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_DYNAMICS: COUPLED_FILTERING (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{coupled_filtering}[0]) ? $defnl{DYNAMICS}{coupled_filtering}[0] : 'T';
    $cval  = (defined $eparms{COUPLED_FILTERING} and $eparms{COUPLED_FILTERING}[0]) ? $eparms{COUPLED_FILTERING}[0] : $dval;

    @{$eparms{COUPLED_FILTERING}}      = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  RUN_DYNAMICS: POS_DEF (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{pos_def}[0]) ? $defnl{DYNAMICS}{pos_def}[0] : 'T';
    $cval  = (defined $eparms{POS_DEF} and $eparms{POS_DEF}[0]) ? $eparms{POS_DEF}[0] : $dval;

    @{$eparms{POS_DEF}}      = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  RUN_DYNAMICS: SWAP_POLE_WITH_NEXT_J (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{swap_pole_with_next_j}[0]) ? $defnl{DYNAMICS}{swap_pole_with_next_j}[0] : 'F';
    $cval  = (defined $eparms{SWAP_POLE_WITH_NEXT_J} and $eparms{SWAP_POLE_WITH_NEXT_J}[0]) ? $eparms{SWAP_POLE_WITH_NEXT_J}[0] : $dval;

    @{$eparms{SWAP_POLE_WITH_NEXT_J}}      = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  RUN_DYNAMICS: ACTUAL_DISTANCE_AVERAGE (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{actual_distance_average}[0]) ? $defnl{DYNAMICS}{actual_distance_average}[0] : 'F';
    $cval  = (defined $eparms{ACTUAL_DISTANCE_AVERAGE} and $eparms{ACTUAL_DISTANCE_AVERAGE}[0]) ? $eparms{ACTUAL_DISTANCE_AVERAGE}[0] : $dval;

    @{$eparms{ACTUAL_DISTANCE_AVERAGE}}      = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  RUN_DYNAMICS: BASE_TEMP (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{base_temp}[0]) ? $defnl{DYNAMICS}{base_temp}[0] : 290.;
    $cval  = (defined $eparms{BASE_TEMP}[0])          ? $eparms{BASE_TEMP}[0]          : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{BASE_TEMP}} = ($cval);


    #============================================================================
    #  RUN_DYNAMICS: M_OPT (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{m_opt}[0]) ? $defnl{DYNAMICS}{m_opt}[0] : 0;
    $cval  = (defined $eparms{M_OPT} and $eparms{M_OPT}[0]) ? $eparms{M_OPT}[0] : $dval;

    @{$eparms{M_OPT}}      = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  RUN_DYNAMICS: SFS_OPT (defined values)
    #============================================================================
    #
    @opts  = (0,1,2);
    $dval  = (defined $defnl{DYNAMICS}{sfs_opt}[0]) ? $defnl{DYNAMICS}{sfs_opt}[0] : $opts[0];
    $cval  = (defined $eparms{SFS_OPT} and $eparms{SFS_OPT}[0]) ? $eparms{SFS_OPT}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{SFS_OPT}} = ($cval);


    #============================================================================
    #  RUN_WRFREAL: USE_MAXW_LEVEL  (0|1)
    #============================================================================
    #
    $dval  = (defined $defnl{DOMAINS}{use_maxw_level}[0]) ? $defnl{DOMAINS}{use_maxw_level}[0]  : 0;
    $cval  = (defined $eparms{USE_MAXW_LEVEL}[0])         ? $eparms{USE_MAXW_LEVEL}[0]         : $dval;

    @{$eparms{USE_MAXW_LEVEL}} = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  RUN_WRFREAL: USE_TROP_LEVEL  (0|1)
    #============================================================================
    #
    $dval  = (defined $defnl{DOMAINS}{use_trop_level}[0]) ? $defnl{DOMAINS}{use_trop_level}[0]  : 0;
    $cval  = (defined $eparms{USE_TROP_LEVEL}[0])         ? $eparms{USE_TROP_LEVEL}[0]         : $dval;

    @{$eparms{USE_TROP_LEVEL}} = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  RUN_WRFREAL: USE_SURFACE (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{DOMAINS}{use_surface}[0]) ? $defnl{DOMAINS}{use_surface}[0] : 'T';
    $cval  = (defined $eparms{USE_SURFACE} and $eparms{USE_SURFACE}[0]) ? $eparms{USE_SURFACE}[0] : $dval;

    @{$eparms{USE_SURFACE}}         = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  RUN_WRFREAL: FORCE_SFC_IN_VINTERP (integer value)
    #============================================================================
    #
    @rvals = (2,1,3,4,5,6,7,8,9,10);
    $dval  = (defined $defnl{DOMAINS}{force_sfc_in_vinterp}[0]) ? $defnl{DOMAINS}{force_sfc_in_vinterp}[0] : $rvals[0];
    $cval  = (defined $eparms{FORCE_SFC_IN_VINTERP} and $eparms{FORCE_SFC_IN_VINTERP}[0]) ? $eparms{FORCE_SFC_IN_VINTERP}[0] : $dval;
    $cval  = $rvals[0] unless grep {/^${cval}$/} @rvals;

    $cval  = 0 unless $eparms{USE_SURFACE}[0] eq 'T';

    @{$eparms{FORCE_SFC_IN_VINTERP}} = ($cval);


    #============================================================================
    #  RUN_WRFREAL: LOWEST_LEV_FROM_SFC (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{DOMAINS}{lowest_lev_from_sfc}[0]) ? $defnl{DOMAINS}{lowest_lev_from_sfc}[0] : 'F';
    $cval  = (defined $eparms{LOWEST_LEV_FROM_SFC} and $eparms{LOWEST_LEV_FROM_SFC}[0]) ? $eparms{LOWEST_LEV_FROM_SFC}[0] : $dval;

    $cval  = 'F' if $eparms{USE_SURFACE}[0] eq 'F';

    @{$eparms{LOWEST_LEV_FROM_SFC}} = &SetValues_TrueFalse($cval,$dval,1);




    #============================================================================
    #  RUN_WRFREAL: INTERP_TYPE (1|2)
    #============================================================================
    #
    @opts = (2,1);
    $dval  = (defined $defnl{DOMAINS}{interp_type}[0]) ? $defnl{DOMAINS}{interp_type}[0] : $opts[0];
    $cval  = (defined $eparms{INTERP_TYPE} and $eparms{INTERP_TYPE}[0]) ? $eparms{INTERP_TYPE}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{INTERP_TYPE}} = ($cval);


    #============================================================================
    #  RUN_WRFREAL: EXTRAP_TYPE (1|2)
    #============================================================================
    #
    @opts = (2,1);
    $dval  = (defined $defnl{DOMAINS}{extrap_type}[0]) ? $defnl{DOMAINS}{extrap_type}[0] : $opts[0];
    $cval  = (defined $eparms{EXTRAP_TYPE} and $eparms{EXTRAP_TYPE}[0]) ? $eparms{EXTRAP_TYPE}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{EXTRAP_TYPE}} = ($cval);


    #============================================================================
    #  RUN_WRFREAL: T_EXTRAP_TYPE (1-3)
    #============================================================================
    #
    @opts = (2,1,3);
    $dval  = (defined $defnl{DOMAINS}{t_extrap_type}[0]) ? $defnl{DOMAINS}{t_extrap_type}[0] : $opts[0];
    $cval  = (defined $eparms{T_EXTRAP_TYPE} and $eparms{T_EXTRAP_TYPE}[0]) ? $eparms{T_EXTRAP_TYPE}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{T_EXTRAP_TYPE}} = ($cval);


    #============================================================================
    #  RUN_WRFREAL: USE_LEVELS_BELOW_GROUND (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{DOMAINS}{use_levels_below_ground}[0]) ? $defnl{DOMAINS}{use_levels_below_ground}[0] : 'T';
    $cval  = (defined $eparms{USE_LEVELS_BELOW_GROUND} and $eparms{USE_LEVELS_BELOW_GROUND}[0]) ? $eparms{USE_LEVELS_BELOW_GROUND}[0] : $dval;

    @{$eparms{USE_LEVELS_BELOW_GROUND}} = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  RUN_WRFREAL: LAGRANGE_ORDER (1,2,9)
    #  Per module_check_a_mundo.F: LAGRANGE_ORDER = 1 if num_metgrid_levels < 21
    #============================================================================
    #
    @opts = (9,1,2);
    $dval  = (defined $defnl{DOMAINS}{lagrange_order}[0]) ? $defnl{DOMAINS}{lagrange_order}[0] : $opts[0];
    $cval  = (defined $eparms{LAGRANGE_ORDER} and $eparms{LAGRANGE_ORDER}[0]) ? $eparms{LAGRANGE_ORDER}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;
    $cval  = 1 if $renv{nilevs} < 21;

    @{$eparms{LAGRANGE_ORDER}} = ($cval);


    #============================================================================
    #  RUN_WRFREAL: ZAP_CLOSE_LEVELS (value)
    #============================================================================
    #
    $dval  = (defined $defnl{DOMAINS}{zap_close_levels}[0]) ? $defnl{DOMAINS}{zap_close_levels}[0] : 500.;
    $cval  = (defined $eparms{ZAP_CLOSE_LEVELS}[0])         ? $eparms{ZAP_CLOSE_LEVELS}[0]         : $dval;

    @{$eparms{ZAP_CLOSE_LEVELS}} = (&Others::isNumber($cval) and $cval > 0.) ? ($cval) : ($dval);


    #============================================================================
    #  RUN_WRFREAL: MAXW_HORIZ_PRES_DIFF (value)
    #============================================================================
    #
    $dval  = (defined $defnl{DOMAINS}{maxw_horiz_pres_diff}[0]) ? $defnl{DOMAINS}{maxw_horiz_pres_diff}[0] : 5000.;
    $cval  = (defined $eparms{MAXW_HORIZ_PRES_DIFF}[0])         ? $eparms{MAXW_HORIZ_PRES_DIFF}[0]         : $dval;

    @{$eparms{MAXW_HORIZ_PRES_DIFF}} = (&Others::isNumber($cval) and $cval > 0.) ? ($cval) : ($dval);


    #============================================================================
    #  RUN_WRFREAL: TROP_HORIZ_PRES_DIFF (value)
    #============================================================================
    #
    $dval  = (defined $defnl{DOMAINS}{trop_horiz_pres_diff}[0]) ? $defnl{DOMAINS}{trop_horiz_pres_diff}[0] : 5000.;
    $cval  = (defined $eparms{TROP_HORIZ_PRES_DIFF}[0])         ? $eparms{TROP_HORIZ_PRES_DIFF}[0]         : $dval;

    @{$eparms{TROP_HORIZ_PRES_DIFF}} = (&Others::isNumber($cval) and $cval > 0.) ? ($cval) : ($dval);


    #============================================================================
    #  RUN_WRFREAL: SFCP_TO_SFCP (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{DOMAINS}{sfcp_to_sfcp}[0]) ? $defnl{DOMAINS}{sfcp_to_sfcp}[0] : 'T';
    $cval  = (defined $eparms{SFCP_TO_SFCP} and $eparms{SFCP_TO_SFCP}[0]) ? $eparms{SFCP_TO_SFCP}[0] : $dval;

    @{$eparms{SFCP_TO_SFCP}}        = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  RUN_WRFREAL: SMOOTH_CG_TOPO (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{DOMAINS}{smooth_cg_topo}[0]) ? $defnl{DOMAINS}{smooth_cg_topo}[0] : 'T';
    $cval  = (defined $eparms{SMOOTH_CG_TOPO} and $eparms{SMOOTH_CG_TOPO}[0]) ? $eparms{SMOOTH_CG_TOPO}[0] : $dval;

    @{$eparms{SMOOTH_CG_TOPO}}      = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  RUN_WRFREAL: HYPSOMETRIC_OPT (1|2)
    #============================================================================
    #
    @opts = (2,1);
    $dval  = (defined $defnl{DOMAINS}{hypsometric_opt}[0]) ? $defnl{DOMAINS}{hypsometric_opt}[0] : $opts[0];
    $cval  = (defined $eparms{HYPSOMETRIC_OPT} and $eparms{HYPSOMETRIC_OPT}[0]) ? $eparms{HYPSOMETRIC_OPT}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{HYPSOMETRIC_OPT}} = ($cval);


    #============================================================================
    #  UNAFFILIATED: ADJUST_HEIGHTS  (T|F)
    #============================================================================
    #    
    $dval  = (defined $defnl{DOMAINS}{adjust_heights}[0]) ? $defnl{DOMAINS}{adjust_heights}[0] : 'F';
    $cval  = (defined $eparms{ADJUST_HEIGHTS} and $eparms{ADJUST_HEIGHTS}[0]) ? $eparms{ADJUST_HEIGHTS}[0] : $dval;
    $cval  = 'F' if $eparms{HYPSOMETRIC_OPT}[0] == 2;  #  Per module_check_a_mundo.F

    @{$eparms{ADJUST_HEIGHTS}}    = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  RUN_WRFREAL: MAXW_ABOVE_THIS_LEVEL (value)
    #============================================================================
    #
    $dval  = (defined $defnl{DOMAINS}{maxw_above_this_level}[0]) ? $defnl{DOMAINS}{maxw_above_this_level}[0] : 30000.;
    $cval  = (defined $eparms{MAXW_ABOVE_THIS_LEVEL}[0])         ? $eparms{MAXW_ABOVE_THIS_LEVEL}[0]         : $dval;

    @{$eparms{MAXW_ABOVE_THIS_LEVEL}} = (&Others::isNumber($cval) and $cval > 0.) ? ($cval) : ($dval);


    #============================================================================
    #  RUN_WRFREAL: USE_INPUT_W (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{DYNAMICS}{use_input_w}[0]) ? $defnl{DYNAMICS}{use_input_w}[0] : 'F';
    $cval  = (defined $eparms{USE_INPUT_W} and $eparms{USE_INPUT_W}[0]) ? $eparms{USE_INPUT_W}[0] : $dval;

    @{$eparms{USE_INPUT_W}}      = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  RUN_WRFOUT: HISTORY_INTERVAL (Max Domains)
    #============================================================================
    #
    @rvals = (-1) x $Config{maxdoms};
    @dvals = ($defnl{TIME_CONTROL}{history_interval} and @{$defnl{TIME_CONTROL}{history_interval}}) ? @{$defnl{TIME_CONTROL}{history_interval}} : (0);
    @cvals = ($eparms{HISTORY_INTERVAL} and @{$eparms{HISTORY_INTERVAL}})                            ? @{$eparms{HISTORY_INTERVAL}}              : @dvals;

    foreach (@cvals) {$_ = 0 unless $_ and $_ =~ /^\d+$/ and $_ > 0;}
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{HISTORY_INTERVAL}} = @rvals[0..$Config{maxindex}];



    #============================================================================
    #  RUN_WRFOUT: FRAMES_PER_OUTFILE (max domains)
    #============================================================================
    #
    @dvals = ($defnl{TIME_CONTROL}{frames_per_outfile} and @{$defnl{TIME_CONTROL}{frames_per_outfile}}) ? @{$defnl{TIME_CONTROL}{frames_per_outfile}} : (1);
    @cvals = ($eparms{FRAMES_PER_OUTFILE} and @{$eparms{FRAMES_PER_OUTFILE}})                            ? @{$eparms{FRAMES_PER_OUTFILE}}              : @dvals;

    foreach (@cvals) {$_ = (&Others::isInteger($_) and $_ > 1) ? (10000) : (1);}
    @rvals = ($cvals[-1]) x $Config{maxdoms};

    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{FRAMES_PER_OUTFILE}} = @rvals[0..$Config{maxindex}];



    #============================================================================
    #  RUN_WRFOUT: HISTORY_NAMEKEY (string)
    #============================================================================
    #
    $cval  = (defined $eparms{HISTORY_NAMEKEY} and $eparms{HISTORY_NAMEKEY}[0]) ? $eparms{HISTORY_NAMEKEY}[0] : 'wrfout';
    $cval  = 'wrfout' if $cval =~ /\W/;

    @{$eparms{HISTORY_NAMEKEY}}  = ($cval);


    #============================================================================
    #  RUN_WRFOUT: ADJUST_OUTPUT_TIMES (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{TIME_CONTROL}{adjust_output_times}[0]) ? $defnl{TIME_CONTROL}{adjust_output_times}[0] : 'T';
    $cval  = (defined $eparms{ADJUST_OUTPUT_TIMES} and $eparms{ADJUST_OUTPUT_TIMES}[0]) ? $eparms{ADJUST_OUTPUT_TIMES}[0] : $dval;

    @{$eparms{ADJUST_OUTPUT_TIMES}}      = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  RUN_WRFOUT: IOFIELDS_FILENAME (string value)
    #============================================================================
    #
    $dval  = (defined $defnl{TIME_CONTROL}{iofields_filename}[0]) ? $defnl{TIME_CONTROL}{iofields_filename}[0] : '';
    $cval  = (defined $eparms{IOFIELDS_FILENAME}[0])      ? $eparms{IOFIELDS_FILENAME}[0]      : $dval;

    @{$eparms{IOFIELDS_FILENAME}} = ($cval =~ /\W/) ? ($cval) : ($dval);


    #============================================================================
    #  RUN_WRFOUT: USE_NETCDF_CLASSIC (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{TIME_CONTROL}{use_netcdf_classic}[0]) ? $defnl{TIME_CONTROL}{use_netcdf_classic}[0] : 'T';
    $cval  = (defined $eparms{USE_NETCDF_CLASSIC} and $eparms{USE_NETCDF_CLASSIC}[0]) ? $eparms{USE_NETCDF_CLASSIC}[0] : $dval;

    @{$eparms{USE_NETCDF_CLASSIC}}  = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  RUN_WRFOUT: DEBUG_LEVEL (int value)
    #============================================================================
    #    
    $dval  = (defined $defnl{TIME_CONTROL}{debug_level}[0]) ? $defnl{TIME_CONTROL}{debug_level}[0] : 1;
    $cval  = (defined $eparms{DEBUG_LEVEL} and $eparms{DEBUG_LEVEL}[0]) ? $eparms{DEBUG_LEVEL}[0] : $dval;

    @{$eparms{DEBUG_LEVEL}}    = (&Others::isNumber($cval) and $cval >= 0) ? (int $cval) : (int $dval);


    #============================================================================
    #  RUN_WRFOUT: LOGGING (1|0)
    #============================================================================
    #
    $cval  = (defined $eparms{LOGGING} and $eparms{LOGGING}[0]) ? $eparms{LOGGING}[0] : 0;

    @{$eparms{LOGGING}}             = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  RUN_TIMESTEP: TIME_STEP (string or number)
    #============================================================================
    #
    $cval  = (defined $eparms{TIME_STEP} and $eparms{TIME_STEP}[0]) ? uc $eparms{TIME_STEP}[0] : 'AUTO';
     
    $cval = 'AUTO'     unless &Others::isNumber($cval) or $cval =~ /^ADAP/i or $cval =~ /_S$/i;

    $cval = 'ADAPTIVE' if $cval =~ /^ADAP/i;
    $cval = 'AUTO_S'   if $cval =~ /_S$/i;

    $cval = sprintf '%.3f', $cval if &Others::isNumber($cval);

    @{$eparms{TIME_STEP}} = ($cval);


    #============================================================================
    #  RUN_TIMESTEP: TIMESTEP_SYNC (defined values)
    #============================================================================
    #
    @opts  = $renv{global} ? (0,2) : (1,0,2); #  Option 1 not valid with global domain

    $cval  = (defined $eparms{TIMESTEP_SYNC}) ? $eparms{TIMESTEP_SYNC}[0] : $opts[0];
#   $cval  = 1 if &Others::isNumber($eparms{TIME_STEP}[0]); #  Automatically set to TIMESTEP_SYNC option 1
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{TIMESTEP_SYNC}} = ($cval);


    #============================================================================
    #  RUN_TIMESTEP: TIME_STEP_SOUND (max domains)
    #============================================================================
    #
    @dvals = ($defnl{DYNAMICS}{time_step_sound} and @{$defnl{DYNAMICS}{time_step_sound}}) ? @{$defnl{DYNAMICS}{time_step_sound}} : (0);
    @cvals = ($eparms{TIME_STEP_SOUND} and @{$eparms{TIME_STEP_SOUND}})                    ? @{$eparms{TIME_STEP_SOUND}}          : @dvals;

    foreach (@cvals) {$_ = 0 unless $_ and &Others::isNumber($_) and $_ > 0;}
   
    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{TIME_STEP_SOUND}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_TIMESTEP: STEP_TO_OUTPUT_TIME (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{DOMAINS}{step_to_output_time}[0]) ? $defnl{DOMAINS}{step_to_output_time}[0] : 'T';
    $cval  = (defined $eparms{STEP_TO_OUTPUT_TIME} and $eparms{STEP_TO_OUTPUT_TIME}[0]) ? $eparms{STEP_TO_OUTPUT_TIME}[0] : $dval;

    @{$eparms{STEP_TO_OUTPUT_TIME}} = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  RUN_TIMESTEP: TARGET_CFL (any number value) (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{DOMAINS}{target_cfl} and @{$defnl{DOMAINS}{target_cfl}})           ? @{$defnl{DOMAINS}{target_cfl}} : (1.2);
    @cvals = ($eparms{TARGET_CFL} and @{$eparms{TARGET_CFL}} and $eparms{TARGET_CFL}[0]) ? @{$eparms{TARGET_CFL}}         : @dvals;

    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{TARGET_CFL}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_TIMESTEP: TARGET_HCFL (any number value) (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{DOMAINS}{target_hcfl} and @{$defnl{DOMAINS}{target_hcfl}})            ? @{$defnl{DOMAINS}{target_hcfl}} : (0.84);
    @cvals = ($eparms{TARGET_HCFL} and @{$eparms{TARGET_HCFL}} and $eparms{TARGET_HCFL}[0]) ? @{$eparms{TARGET_HCFL}}         : @dvals;

    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{TARGET_HCFL}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_TIMESTEP: MAX_STEP_INCREASE_PCT (number value) (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{DOMAINS}{max_step_increase_pct} and @{$defnl{DOMAINS}{max_step_increase_pct}}) ? @{$defnl{DOMAINS}{max_step_increase_pct}} : (5,51);
    @cvals = ($eparms{MAX_STEP_INCREASE_PCT} and @{$eparms{MAX_STEP_INCREASE_PCT}})                  ? @{$eparms{MAX_STEP_INCREASE_PCT}}         : @dvals;
    @rvals = ($cvals[-1]) x $Config{maxdoms};

    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{MAX_STEP_INCREASE_PCT}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_TIMESTEP: STARTING_TIME_STEP (any number value) (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{DOMAINS}{starting_time_step} and @{$defnl{DOMAINS}{starting_time_step}}) ? @{$defnl{DOMAINS}{starting_time_step}} : (-1);
    @cvals = ($eparms{STARTING_TIME_STEP} and @{$eparms{STARTING_TIME_STEP}})                  ? @{$eparms{STARTING_TIME_STEP}}         : @dvals;
    @cvals = (-1) x $Config{maxdoms} if grep {$_ == -1} @cvals;
    @rvals = (-1) x $Config{maxdoms};

    splice @rvals, 0, @cvals, @cvals;
    
    @{$eparms{STARTING_TIME_STEP}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_TIMESTEP: MAX_TIME_STEP (any number value) (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{DOMAINS}{max_time_step} and @{$defnl{DOMAINS}{max_time_step}}) ? @{$defnl{DOMAINS}{max_time_step}} : (-1);
    @cvals = ($eparms{MAX_TIME_STEP} and @{$eparms{MAX_TIME_STEP}})                  ? @{$eparms{MAX_TIME_STEP}}         : @dvals;
    @cvals = (-1) x $Config{maxdoms} if grep {$_ == -1} @cvals;
    @rvals = (-1) x $Config{maxdoms};

    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{MAX_TIME_STEP}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_TIMESTEP: MIN_TIME_STEP (any number value) (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{DOMAINS}{min_time_step} and @{$defnl{DOMAINS}{min_time_step}}) ? @{$defnl{DOMAINS}{min_time_step}} : (-1);
    @cvals = ($eparms{MIN_TIME_STEP} and @{$eparms{MIN_TIME_STEP}})                  ? @{$eparms{MIN_TIME_STEP}}         : @dvals;
    @cvals = (-1) x $Config{maxdoms} if grep {$_ == -1} @cvals;
    @rvals = (-1) x $Config{maxdoms};

    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{MIN_TIME_STEP}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_TIMESTEP: ADAPTATION_DOMAIN (Domain #)
    #============================================================================
    #
    $dval  = (defined $defnl{DOMAINS}{adaptation_domain}[0]) ? $defnl{DOMAINS}{adaptation_domain}[0] : 1;
    $cval  = (defined $eparms{ADAPTATION_DOMAIN} and $eparms{ADAPTATION_DOMAIN}[0]) ? $eparms{ADAPTATION_DOMAIN}[0] : $dval;

    @{$eparms{ADAPTATION_DOMAIN}} = (int $cval);


    #============================================================================
    #  RUN_RESTART: RESTART_INTERVAL (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{TIME_CONTROL}{restart_interval}[0]) ? $defnl{TIME_CONTROL}{restart_interval}[0] : 0;
    $cval  = (defined $eparms{RESTART_INTERVAL} and $eparms{RESTART_INTERVAL}[0]) ? $eparms{RESTART_INTERVAL}[0] : $dval;
    $cval  = 0 unless $_ and ( ($_ =~ /^\d+$/ and $_ > 0) or ($_ =~ /^auto/i) );

    @{$eparms{RESTART_INTERVAL}} = ($cval =~ /auto/i) ? ('Auto') : ($cval);


    #============================================================================
    #  RUN_NUDGING: NUDGING (single value) - Comes in as multi-value array
    #
    #  NUDGING controls the domains and period length IF any nudging is to
    #  be done during the simulation. Do not confuse with --nudge flag,
    #  which turns ON|OFF analysis or spectral nudging (or neither) from 
    #  the command line and overrides GRID_FDDA (below) in run_nudging.conf.
    #
    #  One of the few times that heavy reformatting is done in this subroutine
    #============================================================================
    #
    my %nudge = ();
    @cvals = (defined $eparms{NUDGING}[0] and $eparms{NUDGING}[0]) ? @{$eparms{NUDGING}} : ();
    foreach (@cvals) { next unless $_;
        my @dls = split(/:/,$_,2); 
        next unless $dls[0] and $dls[0] =~ /^(\d+)$/;
        $dls[1] = 0 unless $dls[1] and $dls[1] =~ /^(\d+)$/;
        $nudge{$dls[0]+=0} = 3600.*($dls[1]+=0);  #  Convert from hours to seconds
    }
    $nudge{1} = 0 unless defined $nudge{1};

    @{$eparms{NUDGING}} = map { "$_:$nudge{$_}" } sort {$a <=> $b} keys %nudge;
    

    #============================================================================
    #  RUN_NUDGING: GRID_FDDA (defined values) (Max Domains - don't care)
    #
    #  The command-line flag --nudge overrides the value of GRID_FDDA with 
    #  values of: -1 (defer to run_nudging.conf), 0 (OFF), 1 (analysis), or 2 (spectral).
    #============================================================================
    #
    $fval  = $flags{nudge};

    @opts = (0,1,2);
    $dval  = (defined $defnl{FDDA}{grid_fdda}[0]) ? $defnl{FDDA}{grid_fdda}[0] : $opts[0];
    $cval  = (defined $eparms{GRID_FDDA} and $eparms{GRID_FDDA}[0]) ? $eparms{GRID_FDDA}[0] : $dval;
    $cval  = 0 unless $fval;         #  $flags{nudge} = 0 turns GRID_FDDA OFF
    $cval  = $fval if $fval > 0;     #  Set to 1 (analysis), or 2 (spectral)
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{GRID_FDDA}} = ($cval);


    #============================================================================
    #  RUN_NUDGING: SPWAVELEN (Max Domains)
    #============================================================================
    #
    $cval  = defined  $eparms{SPWAVELEN}[0] ? $eparms{SPWAVELEN}[0] : 400;
    $cval  = 400 unless $eparms{SPWAVELEN}[0] and &Others::isNumber($eparms{SPWAVELEN}[0]);
    $cval  = 400 unless $cval > 0;

    @{$eparms{SPWAVELEN}} = ($cval);


    #============================================================================
    #  RUN_NUDGING: DTRAMP_MIN (Max Domains)
    #============================================================================
    #
    $dval  = defined $defnl{FDDA}{dtramp_min}[0] ? $defnl{FDDA}{dtramp_min}[0] : 60; 
    $cval  = defined  $eparms{DTRAMP_MIN}[0]     ? $eparms{DTRAMP_MIN}[0]      : 60;
    $cval  = 60 unless &Others::isNumber($cval);

    @{$eparms{DTRAMP_MIN}} = (int $cval);


    #============================================================================
    #  RUN_NUDGING: IF_RAMPING (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{FDDA}{if_ramping}[0]) ? $defnl{FDDA}{if_ramping}[0] : 1;
    $cval  = (defined $eparms{IF_RAMPING} and $eparms{IF_RAMPING}[0]) ? $eparms{IF_RAMPING}[0] : $dval;

    @{$eparms{IF_RAMPING}}      = &SetValues_OnOff($cval,$dval,1);



    #============================================================================
    #  RUN_NUDGING: IF_NO_PBL_NUDGING_T|Q|UV (1|0; Max Domains)
    #============================================================================
    #
    foreach my $nparm (qw(IF_NO_PBL_NUDGING_T IF_NO_PBL_NUDGING_Q IF_NO_PBL_NUDGING_UV)) {

        @dvals = ($defnl{FDDA}{lc $nparm} and @{$defnl{FDDA}{lc $nparm}}) ? @{$defnl{FDDA}{lc $nparm}} : (1);
        @cvals = ($eparms{$nparm} and @{$eparms{$nparm}})                  ? @{$eparms{$nparm}}         : @dvals;
        @rvals = ($cvals[-1]) x $Config{maxdoms};

        splice @rvals, 0, @cvals, @cvals;

        &SetValues_OnOff($_,0,1) foreach @rvals;

        @{$eparms{$nparm}} = @rvals[0..$Config{maxindex}];

    }
   

    #============================================================================
    #  RUN_NUDGING:  K_ZFAC_T|Q|UV (integer values; Max Domains)
    #============================================================================
    #
    foreach my $nparm (qw(K_ZFAC_T  K_ZFAC_Q  K_ZFAC_UV)) {

        @dvals = ($defnl{FDDA}{lc $nparm} and @{$defnl{FDDA}{lc $nparm}}) ? @{$defnl{FDDA}{lc $nparm}} : (10);
        @cvals = ($eparms{$nparm} and @{$eparms{$nparm}})                  ? @{$eparms{$nparm}}         : @dvals;
        @rvals = ($cvals[-1]) x $Config{maxdoms};
    
        splice @rvals, 0, @cvals, @cvals;

        @{$eparms{$nparm}} = @rvals[0..$Config{maxindex}];

    }


    #============================================================================
    #  RUN_NUDGING:  GT|Q|UV (float; Max Domains)
    #============================================================================
    #
    foreach my $nparm (qw(GT GQ GUV)) {

        @dvals = ($defnl{FDDA}{lc $nparm} and @{$defnl{FDDA}{lc $nparm}}) ? @{$defnl{FDDA}{lc $nparm}} : (0.0003);
        @cvals = ($eparms{$nparm} and @{$eparms{$nparm}})                  ? @{$eparms{$nparm}}         : @dvals;
        @rvals = ($cvals[-1]) x $Config{maxdoms};

        splice @rvals, 0, @cvals, @cvals;

        @{$eparms{$nparm}} = @rvals[0..$Config{maxindex}];

    }


    #============================================================================
    #  RUN_NESTING: FEEDBACK (0|1)
    #============================================================================
    #
    $dval  = (defined $defnl{DOMAINS}{feedback}[0]) ? $defnl{DOMAINS}{feedback}[0] : 0;
    $cval  = (defined $eparms{FEEDBACK}[0])         ? $eparms{FEEDBACK}[0]        : $dval;

    @{$eparms{FEEDBACK}} = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  RUN_NESTING: SMOOTH_OPTION (defined values)
    #============================================================================
    #
    @opts = $eparms{FEEDBACK}[0] ? (1,0,2) : (0);
    $dval  = (defined $defnl{DOMAINS}{smooth_option}[0]) ? $defnl{DOMAINS}{smooth_option}[0] : $opts[0];
    $cval  = (defined $eparms{SMOOTH_OPTION}) ? $eparms{SMOOTH_OPTION}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{SMOOTH_OPTION}} = ($cval);




    #============================================================================
    #  RUN_NCPUS: REAL_NODECPUS, WRFM_NODECPUS (UEMS; string)
    #============================================================================
    #
    foreach my $nparm (qw(REAL_NODECPUS WRFM_NODECPUS)) {
        @cvals  = defined  $eparms{$nparm}[0] ? @{$eparms{$nparm}} : ('local:NCPUS');
        @cvals  = ('local:NCPUS') unless $eparms{$nparm}[0];
        @{$eparms{$nparm}} = @cvals;
    }


    #============================================================================
    #  RUN_NCPUS: DECOMP (UEMS; single value)
    #============================================================================
    #
    @opts = (0,1,2);
    $cval  = defined $eparms{DECOMP} ? $eparms{DECOMP}[0] : $opts[0];
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{DECOMP}} = ($cval);


    #============================================================================
    #  RUN_NCPUS: DECOMP_X DECOMP_Y (UEMS; integer value)
    #============================================================================
    #
    foreach my $nparm (qw(DECOMP_X DECOMP_Y)) {
        $cval  = defined  $eparms{$nparm}[0] ? $eparms{$nparm}[0] : 0;
        $cval  = 0 unless &Others::isNumber($cval); $cval = int $cval;
        $cval  = 0 unless $eparms{DECOMP}[0] == 2;
        @{$eparms{$nparm}} = ($cval);
    }


    #============================================================================
    #  RUN_NCPUS: NUMTILES (integer value)
    #============================================================================
    #
    $dval  = (defined $defnl{DOMAINS}{numtiles}[0]) ? $defnl{DOMAINS}{numtiles}[0] : 1;
    $cval  = (defined $eparms{NUMTILES} and $eparms{NUMTILES}[0]) ? $eparms{NUMTILES}[0] : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{NUMTILES}}    = (int $cval);


    #============================================================================
    #  RUN_NCPUS: TILE_SZ_X (integer value)
    #
    #       NOTE: UEMS support for TILE_SZ_X still needs to be added 
    #============================================================================
    #
    $dval  = (defined $defnl{DOMAINS}{tile_sz_x}[0]) ? $defnl{DOMAINS}{tile_sz_x}[0] : 0;
    $cval  = (defined $eparms{TILE_SZ_X} and $eparms{TILE_SZ_X}[0]) ? $eparms{TILE_SZ_X}[0] : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{TILE_SZ_X}}    = (int $cval);


    #============================================================================
    #  RUN_NCPUS: TILE_SZ_Y (integer value)
    #
    #       NOTE: UEMS support for TILE_SZ_Y still needs to be added
    #============================================================================
    #
    $dval  = (defined $defnl{DOMAINS}{tile_sz_y}[0]) ? $defnl{DOMAINS}{tile_sz_y}[0] : 0;
    $cval  = (defined $eparms{TILE_SZ_Y} and $eparms{TILE_SZ_Y}[0]) ? $eparms{TILE_SZ_Y}[0] : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{TILE_SZ_Y}}    = (int $cval);


    #============================================================================
    #  RUN_NCPUS: MPICHECK (1|0)
    #============================================================================
    #
    $cval  = (defined $eparms{MPICHECK} and $eparms{MPICHECK}[0]) ? $eparms{MPICHECK}[0] : 0;

    @{$eparms{MPICHECK}}      = &SetValues_OnOff($cval,0,1);


    #============================================================================
    #  RUN_NCPUS: HYDRA_IFACE (single value)
    #============================================================================
    #
    $cval  = (defined $eparms{HYDRA_IFACE}[0] and $eparms{HYDRA_IFACE}[0]) ? $eparms{HYDRA_IFACE}[0] : 0;

    @{$eparms{HYDRA_IFACE}} = ($cval);


    #============================================================================
    #  RUN_LIGHTNING: LIGHTNING_OPTION (defined values; Max Domains)
    #============================================================================
    #
    @opts  = (3,0,1,2,11);
    $dval  = (defined $defnl{PHYSICS}{lightning_option}[0]) ? $defnl{PHYSICS}{lightning_option}[0] : $opts[0];
    $cval  = (defined $eparms{LIGHTNING_OPTION} and $eparms{LIGHTNING_OPTION}[0]) ? $eparms{LIGHTNING_OPTION}[0] : $dval;
    $cval  = $opts[0]  if $cval =~ /^Auto/i;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{LIGHTNING_OPTION}} = ($cval);


    #============================================================================
    #  RUN_LIGHTNING: LIGHTNING_START_SECONDS (any number value) (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{PHYSICS}{lightning_start_seconds} and @{$defnl{PHYSICS}{lightning_start_seconds}}) ? @{$defnl{PHYSICS}{lightning_start_seconds}} : (600.);
    @cvals = ($eparms{LIGHTNING_START_SECONDS} and @{$eparms{LIGHTNING_START_SECONDS}})                  ? @{$eparms{LIGHTNING_START_SECONDS}}         : @dvals;

    foreach  (@cvals) {$_ = 0 unless $_ and &Others::isNumber($_) and $_ > 0;}
    @rvals = ($cvals[-1]) x $Config{maxdoms};

    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{LIGHTNING_START_SECONDS}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_LIGHTNING: FLASHRATE_FACTOR (any number value) (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{PHYSICS}{flashrate_factor} and @{$defnl{PHYSICS}{flashrate_factor}}) ? @{$defnl{PHYSICS}{flashrate_factor}} : (1.0);
    @cvals = ($eparms{FLASHRATE_FACTOR} and @{$eparms{FLASHRATE_FACTOR}})                  ? @{$eparms{FLASHRATE_FACTOR}}         : @dvals;

    foreach  (@cvals) {$_ = 0 unless $_ and &Others::isNumber($_) and $_ > 0;}
    @rvals = ($cvals[-1]) x $Config{maxdoms};

    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{FLASHRATE_FACTOR}} = @rvals[0..$Config{maxindex}];
 

    #============================================================================
    #  NAME: CELLCOUNT_METHOD (defined values)
    #============================================================================
    #
    @opts  = (0,1,2);
    $dval  = (defined $defnl{PHYSICS}{cellcount_method}[0]) ? $defnl{PHYSICS}{cellcount_method}[0] : $opts[0];
    $cval  = (defined $eparms{CELLCOUNT_METHOD} and $eparms{CELLCOUNT_METHOD}[0]) ? $eparms{CELLCOUNT_METHOD}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{CELLCOUNT_METHOD}} = ($cval) x $Config{maxdoms};


    #============================================================================
    #  RUN_LIGHTNING: CLDTOP_ADJUSTMENT (any number value) (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{PHYSICS}{cldtop_adjustment} and @{$defnl{PHYSICS}{cldtop_adjustment}}) ? @{$defnl{PHYSICS}{cldtop_adjustment}} : (2.0);
    @cvals = ($eparms{CLDTOP_ADJUSTMENT} and @{$eparms{CLDTOP_ADJUSTMENT}})                  ? @{$eparms{CLDTOP_ADJUSTMENT}}         : @dvals;

    foreach  (@cvals) {$_ = 0 unless $_ and &Others::isNumber($_) and $_ > 0;}
    @rvals = ($cvals[-1]) x $Config{maxdoms};

    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{CLDTOP_ADJUSTMENT}} = @rvals[0..$Config{maxindex}];

 
    #============================================================================
    #  RUN_LIGHTNING: ICCG_METHOD (defined values) (Max Domains)
    #  Note: Option 4 not supported in UEMS
    #============================================================================
    #
    @opts = (0,1,2,3);
    $dval  = (defined $defnl{PHYSICS}{iccg_method}[0]) ? $defnl{PHYSICS}{iccg_method}[0] : $opts[0];
    $cval  = (defined $eparms{ICCG_METHOD} and $eparms{ICCG_METHOD}[0]) ? $eparms{ICCG_METHOD}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{ICCG_METHOD}} = ($cval) x $Config{maxdoms};


    #============================================================================
    #  RUN_LIGHTNING: ICCG_PRESCRIBED_NUM (Max Domains)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{iccg_prescribed_num}[0]) ? $defnl{PHYSICS}{iccg_prescribed_num}[0] : 0.;
    $cval  = (defined $eparms{ICCG_PRESCRIBED_NUM}[0])         ? $eparms{ICCG_PRESCRIBED_NUM}[0]         : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{ICCG_PRESCRIBED_NUM}} = ($cval) x $Config{maxdoms};


    #============================================================================
    #  RUN_LIGHTNING: ICCG_PRESCRIBED_DEN (Max Domains)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{iccg_prescribed_den}[0]) ? $defnl{PHYSICS}{iccg_prescribed_den}[0] : 1.;
    $cval  = (defined $eparms{ICCG_PRESCRIBED_DEN}[0])         ? $eparms{ICCG_PRESCRIBED_DEN}[0]         : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{ICCG_PRESCRIBED_DEN}} = ($cval) x $Config{maxdoms};


    #============================================================================
    #  RUN_LEVELS: PTOP (single value)
    #============================================================================
    #
    $dval  = -1;
    $cval  = defined $eparms{PTOP}[0] ? $eparms{PTOP}[0] : $dval;

    @{$eparms{PTOP}} = (&Others::isNumber($cval) and $cval > 0.) ? ($cval) : ($dval);


    #============================================================================
    #  RUN_LEVELS: LEVELS (single or multi-value)
    #============================================================================
    #
    @cvals = (defined $eparms{LEVELS} and @{$eparms{LEVELS}}) ? @{$eparms{LEVELS}} : (45);
    @cvals = &Others::rmdups(@cvals); @cvals = sort {$b <=> $a} @cvals;

    $cval  = @cvals > 1 ? @cvals : $cvals[0];
    $cval  = (&Others::isNumber($cval) and $cval > 0) ? int $cval : 45;
    $cval  = join ',' => @cvals if $cvals[0] == 1.0 and $cvals[-1] == 0.0;
    
    $cval  = $flags{levels} if $flags{levels};

    @{$eparms{LEVELS}} = ($cval);


    #============================================================================
    #  RUN_DFI: DFI_OPT (defined values)
    #  FLAG VALUES: -1 (OFF), 0 (NOT PASSED), or value:value (DFI_OPT:DFI_NFILTER)
    #============================================================================
    #
    @fvals = split ':' => $flags{dfi}, 2; # $fvals[0] is DFI_OPT, $fvals[1] is DFI_NFILTER
    
    @opts  = (3,0,1,2);
    $dval  = (defined $defnl{DFI_CONTROL}{dfi_opt}[0]) ? $defnl{DFI_CONTROL}{dfi_opt}[0] : $opts[0];
    $cval  = (defined $eparms{DFI_OPT} and $eparms{DFI_OPT}[0]) ? $eparms{DFI_OPT}[0]   : $dval;
    $cval  = 0 if $fvals[0] < 0;         #  $flags{dfi} = -1 turns DFI OFF
    $cval  = $fvals[0] if $fvals[0] > 0; 
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{DFI_OPT}} = ($cval);


    #============================================================================
    #  RUN_DFI: DFI_NFILTER (defined values)
    #  FLAG VALUES: $fvals[1] = DFI_NFILTER
    #============================================================================
    #
    $fvals[1] = -1 unless defined $fvals[1];  #  No value (--dfi 2)? Assign invalid

    @opts  = (7,0,1,2,3,4,5,6);
    $dval  = (defined $defnl{DFI_CONTROL}{dfi_nfilter}[0]) ? $defnl{DFI_CONTROL}{dfi_nfilter}[0]     : $opts[0];
    $cval  = (defined $eparms{DFI_NFILTER} and $eparms{DFI_NFILTER}[0]) ? $eparms{DFI_NFILTER}[0]   : $dval;
    $cval  = $fvals[1] if grep {/^$fvals[1]$/} @opts;
    $cval  = $opts[0]  unless grep {/^${cval}$/} @opts;

    @{$eparms{DFI_NFILTER}} = ($cval);


    #============================================================================
    #  RUN_DFI: TIME_STEP_DFI (single value)
    #============================================================================
    #
    $cval  = (defined $eparms{TIME_STEP_DFI}[0] and $eparms{TIME_STEP_DFI}[0])  ? $eparms{TIME_STEP_DFI}[0] : 0;
    $cval  = 0 unless &Others::isNumber($cval) and $cval > 0;

    @{$eparms{TIME_STEP_DFI}} = ($cval);


    #============================================================================
    #  RUN_DFI: DFI_BACKSTOP (single value)
    #============================================================================
    #
    $dval  = 40;
    $cval  = (defined $eparms{DFI_BACKSTOP}[0])  ? $eparms{DFI_BACKSTOP}[0]        : $dval;

    @{$eparms{DFI_BACKSTOP}} = (&Others::isNumber($cval) and $cval > 0.) ? ($cval) : ($dval);


    #============================================================================
    #  RUN_DFI: DFI_FWDSTOP (single value)
    #============================================================================
    #
    $dval  = 20;
    $cval  = (defined $eparms{DFI_FWDSTOP}[0])  ? $eparms{DFI_FWDSTOP}[0]         : $dval;

    @{$eparms{DFI_FWDSTOP}} = (&Others::isNumber($cval) and $cval > 0.) ? ($cval) : ($dval);


    #============================================================================
    #  RUN_DFI: DFI_WRITE_FILTERED_INPUT (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{DFI_CONTROL}{dfi_write_filtered_input}[0]) ? $defnl{DFI_CONTROL}{dfi_write_filtered_input}[0] : 'T';
    $cval  = (defined $eparms{DFI_WRITE_FILTERED_INPUT} and $eparms{DFI_WRITE_FILTERED_INPUT}[0]) ? $eparms{DFI_WRITE_FILTERED_INPUT}[0] : $dval;

    @{$eparms{DFI_WRITE_FILTERED_INPUT}}      = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  RUN_DFI: DFI_WRITE_DFI_HISTORY (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{DFI_CONTROL}{dfi_write_dfi_history}[0]) ? $defnl{DFI_CONTROL}{dfi_write_dfi_history}[0] : 'F';
    $cval  = (defined $eparms{DFI_WRITE_DFI_HISTORY} and $eparms{DFI_WRITE_DFI_HISTORY}[0]) ? $eparms{DFI_WRITE_DFI_HISTORY}[0] : $dval;

    @{$eparms{DFI_WRITE_DFI_HISTORY}}      = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  RUN_DFI: DFI_CUTOFF_SECONDS (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{DFI_CONTROL}{dfi_cutoff_seconds}[0]) ? $defnl{DFI_CONTROL}{dfi_cutoff_seconds}[0] : 1800;
    $cval  = (defined $eparms{DFI_CUTOFF_SECONDS}[0])  ? $eparms{DFI_CUTOFF_SECONDS}[0]         : $dval;

    @{$eparms{DFI_CUTOFF_SECONDS}} = (&Others::isNumber($cval) and $cval > 0.) ? ($cval) : ($dval);


    #============================================================================
    #  RUN_DFI: DFI_TIME_DIM (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{DFI_CONTROL}{dfi_time_dim}[0]) ? $defnl{DFI_CONTROL}{dfi_time_dim}[0] : '1000';
    $cval  = (defined $eparms{DFI_TIME_DIM}[0])  ? $eparms{DFI_TIME_DIM}[0]         : $dval;

    @{$eparms{DFI_TIME_DIM}} = (&Others::isNumber($cval) and $cval > 0.) ? (int $cval) : (int $dval);


    #============================================================================
    #  RUN_DFI: DFI_RADAR (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{DFI_CONTROL}{dfi_radar}[0]) ? $defnl{DFI_CONTROL}{dfi_radar}[0] : 0;
    $cval  = (defined $eparms{DFI_RADAR} and $eparms{DFI_RADAR}[0]) ? $eparms{DFI_RADAR}[0] : $dval;

    @{$eparms{DFI_RADAR}}      = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  RUN_AUXHIST1: AUXHIST1_INTERVAL (Max Domains)
    #============================================================================
    #
    @rvals = (0) x $Config{maxdoms};
    @dvals = ($defnl{TIME_CONTROL}{auxhist1_interval} and @{$defnl{TIME_CONTROL}{auxhist1_interval}}) ? @{$defnl{TIME_CONTROL}{auxhist1_interval}} : (0);
    @cvals = ($eparms{AUXHIST1_INTERVAL} and @{$eparms{AUXHIST1_INTERVAL}})                            ? @{$eparms{AUXHIST1_INTERVAL}}              : @dvals;

    foreach (@cvals) {$_ = 0 unless $_ and ( ($_ =~ /^\d+$/ and $_ > 0) or ($_ =~ /^auto/i) );}

    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{AUXHIST1_INTERVAL}} = (grep {/auto/i} @rvals) ? ('Auto') : @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_AUXHIST1: AUXHIST1_NAMEKEY (single value)
    #============================================================================
    #
    $dval  = 'auxhist1';
    $cval  = (defined $eparms{AUXHIST1_NAMEKEY}[0] and $eparms{AUXHIST1_NAMEKEY}[0])  ? $eparms{AUXHIST1_NAMEKEY}[0] : $dval;
    $cval  = $dval if $cval =~ /\W/;

    @{$eparms{AUXHIST1_NAMEKEY}} = ($cval);


    #============================================================================
    #  RUN_AUXHIST1: FRAMES_PER_AUXHIST1 (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{TIME_CONTROL}{frames_per_auxhist1} and @{$defnl{TIME_CONTROL}{frames_per_auxhist1}}) ? @{$defnl{TIME_CONTROL}{frames_per_auxhist1}} : (1);
    @cvals = ($eparms{FRAMES_PER_AUXHIST1} and @{$eparms{FRAMES_PER_AUXHIST1}})                            ? @{$eparms{FRAMES_PER_AUXHIST1}}              : @dvals;

    foreach (@cvals) {$_ = (&Others::isInteger($_) and $_ > 1) ? (10000) : (1);}

    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{FRAMES_PER_AUXHIST1}} = @rvals[0..$Config{maxindex}];



    #============================================================================
    #  RUN_AFWAOUT: DIAGNOSTIC SWITCHES (1|0)
    #============================================================================
    #
    foreach my $nparm (qw(AFWA_SEVERE_OPT AFWA_ICING_OPT AFWA_VIS_OPT AFWA_CLOUD_OPT 
                          AFWA_THERM_OPT AFWA_TURB_OPT AFWA_BUOY_OPT AFWA_HAILCAST_OPT)) {

        $dval  = (defined $defnl{AFWA}{lc $nparm}[0]) ? $defnl{AFWA}{lc $nparm}[0] : 0;
        $cval  = (defined $eparms{uc $nparm} and $eparms{uc $nparm}[0]) ? $eparms{uc $nparm}[0] : $dval;

#       @{$eparms{uc $nparm}}  = &SetValues_OnOff($cval,$dval,1);
        @{$eparms{uc $nparm}}  = (0);  #  Turn OFF

    }


    #============================================================================
    #  RUN_AFWAOUT: AFWA_DIAG_OPT (1|0) - Used by the UEMS as a switch to 
    #  turn ON|OFF processing of AFWA diagnostic fields.
    #============================================================================
    #
    @{$eparms{AFWA_DIAG_OPT}}  = (sum (@{$eparms{AFWA_SEVERE_OPT}},@{$eparms{AFWA_ICING_OPT}},@{$eparms{AFWA_VIS_OPT}}, @{$eparms{AFWA_CLOUD_OPT}},
                                       @{$eparms{AFWA_THERM_OPT}}, @{$eparms{AFWA_TURB_OPT}}, @{$eparms{AFWA_BUOY_OPT}},@{$eparms{AFWA_HAILCAST_OPT}}) ? 1 : 0);



    #============================================================================
    #  RUN_AFWAOUT: AUXHIST2_INTERVAL (Max Domains)
    #============================================================================
    #
    @rvals = (0) x $Config{maxdoms};
    @dvals = ($defnl{TIME_CONTROL}{auxhist2_interval} and @{$defnl{TIME_CONTROL}{auxhist2_interval}}) ? @{$defnl{TIME_CONTROL}{auxhist2_interval}} : (0);
    @cvals = ($eparms{AUXHIST2_INTERVAL} and @{$eparms{AUXHIST2_INTERVAL}})                            ? @{$eparms{AUXHIST2_INTERVAL}}              : @dvals;

    foreach (@cvals) {$_ = 0 unless $_ and ( ($_ =~ /^\d+$/ and $_ > 0) or ($_ =~ /^auto/i) );}
    splice @rvals, 0, @cvals, @cvals;

#   @{$eparms{AUXHIST2_INTERVAL}} = (grep {/auto/i} @rvals) ? ('Auto') : @rvals[0..$Config{maxindex}];
    @{$eparms{AUXHIST2_INTERVAL}} = (0);  # Turn OFF for now


    #============================================================================
    #  RUN_AFWAOUT: AUXHIST2_NAMEKEY (single value)
    #============================================================================
    #
    $dval  = 'afwa';
    $cval  = (defined $eparms{AUXHIST2_NAMEKEY}[0] and $eparms{AUXHIST2_NAMEKEY}[0])  ? $eparms{AUXHIST2_NAMEKEY}[0] : $dval;
    $cval  = $dval if $cval =~ /\W/;

    @{$eparms{AUXHIST2_NAMEKEY}} = ($cval);



    #============================================================================
    #  RUN_AFWAOUT: FRAMES_PER_AUXHIST2 (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{TIME_CONTROL}{frames_per_auxhist2} and @{$defnl{TIME_CONTROL}{frames_per_auxhist2}}) ? @{$defnl{TIME_CONTROL}{frames_per_auxhist2}} : (1);
    @cvals = ($eparms{FRAMES_PER_AUXHIST2} and @{$eparms{FRAMES_PER_AUXHIST2}})                            ? @{$eparms{FRAMES_PER_AUXHIST2}}              : @dvals;

    foreach (@cvals) {$_ = (&Others::isInteger($_) and $_ > 1) ? (10000) : (1);}

    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{FRAMES_PER_AUXHIST2}} = @rvals[0..$Config{maxindex}];



    #============================================================================
    #  UNAFFILIATED - DIAGS: P_LEV_DIAGS (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{DIAGS}{p_lev_diags}[0]) ? $defnl{DIAGS}{p_lev_diags}[0] : 0;
    $cval  = (defined $eparms{P_LEV_DIAGS} and $eparms{P_LEV_DIAGS}[0]) ? $eparms{P_LEV_DIAGS}[0] : $dval;

    @{$eparms{P_LEV_DIAGS}}      = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  UNAFFILIATED - DIAGS: PRESS_LEVELS (values)
    #============================================================================
    #
    @cvals = (defined $eparms{PRESS_LEVELS} and @{$eparms{PRESS_LEVELS}}) ? @{$eparms{PRESS_LEVELS}} : (0);
    @cvals = &Others::rmdups(@cvals); @cvals = sort {$a <=> $b} @cvals;
    foreach (@cvals) {$_ = 0 unless &Others::isNumber($_) and $_ > 0.;}
    @cvals = &Others::rmdups(@cvals); @cvals = sort {$a <=> $b} @cvals; #  Yes, again
    $cval  = join ',' => @cvals;

    @{$eparms{PRESS_LEVELS}} = ($cval);


    #============================================================================
    #  UNAFFILIATED - DIAGS: NUM_PRESS_LEVELS (integer value)
    #============================================================================
    #
    $dval  = (defined $defnl{DIAGS}{num_press_levels}[0]) ? $defnl{DIAGS}{num_press_levels}[0] : 0;
    $cval  = (defined $eparms{NUM_PRESS_LEVELS} and $eparms{NUM_PRESS_LEVELS}[0]) ? $eparms{NUM_PRESS_LEVELS}[0] : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{NUM_PRESS_LEVELS}} = (int $cval);


    #============================================================================
    #  UNAFFILIATED - DIAGS: USE_TOT_OR_HYD_P (defined values)
    #============================================================================
    #
    @opts  = (2,1);
    $dval  = (defined $defnl{DIAGS}{use_tot_or_hyd_p}[0]) ? $defnl{DIAGS}{use_tot_or_hyd_p}[0] : $opts[0];
    $cval  = (defined $eparms{USE_TOT_OR_HYD_P} and $eparms{USE_TOT_OR_HYD_P}[0]) ? $eparms{USE_TOT_OR_HYD_P}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{USE_TOT_OR_HYD_P}} = ($cval);


    #============================================================================
    #  UNAFFILIATED - DIAGS: P_LEV_MISSING (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{DIAGS}{p_lev_missing}[0]) ? $defnl{DIAGS}{p_lev_missing}[0] : -9999.;
    $cval  = (defined $eparms{P_LEV_MISSING}[0])      ? $eparms{P_LEV_MISSING}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval);

    @{$eparms{P_LEV_MISSING}} = ($cval);


    #============================================================================
    #  UNAFFILIATED - DIAGS: Z_LEV_DIAGS (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{DIAGS}{z_lev_diags}[0]) ? $defnl{DIAGS}{z_lev_diags}[0] : 0;
    $cval  = (defined $eparms{Z_LEV_DIAGS} and $eparms{Z_LEV_DIAGS}[0]) ? $eparms{Z_LEV_DIAGS}[0] : $dval;

    @{$eparms{Z_LEV_DIAGS}}      = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  UNAFFILIATED - DIAGS: Z_LEVELS (values)
    #============================================================================
    #
    @cvals = (defined $eparms{Z_LEVELS} and @{$eparms{Z_LEVELS}}) ? @{$eparms{Z_LEVELS}} : (0);
    @cvals = &Others::rmdups(@cvals); @cvals = sort {$a <=> $b} @cvals;
    foreach (@cvals) {$_ = 0 unless &Others::isNumber($_);}
    @cvals = &Others::rmdups(@cvals); @cvals = sort {$a <=> $b} @cvals; #  Yes, again
    $cval  = join ',' => @cvals;

    @{$eparms{Z_LEVELS}} = ($cval);


    #============================================================================
    #  UNAFFILIATED - DIAGS: NUM_Z_LEVELS (integer value)
    #============================================================================
    #
    $dval  = (defined $defnl{DIAGS}{num_z_levels}[0]) ? $defnl{DIAGS}{num_z_levels}[0] : 0;
    $cval  = (defined $eparms{NUM_Z_LEVELS} and $eparms{NUM_Z_LEVELS}[0]) ? $eparms{NUM_Z_LEVELS}[0] : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{NUM_Z_LEVELS}} = (int $cval);


    #============================================================================
    #  UNAFFILIATED - DIAGS: Z_LEV_MISSING (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{DIAGS}{z_lev_missing}[0]) ? $defnl{DIAGS}{z_lev_missing}[0] : -9999.;
    $cval  = (defined $eparms{Z_LEV_MISSING}[0])      ? $eparms{Z_LEV_MISSING}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval);

    @{$eparms{Z_LEV_MISSING}} = ($cval);


    #----------------------------------------------------------------------------------
    #  RUN_PHYSICS PARAMETERS 
    #----------------------------------------------------------------------------------
    #

    #============================================================================================================
    #  PHYSICS_MICROPHYSICS: MP_PHYSICS (multiple values with error mesg)
    #  
    #  NOTE: The following somewhat messy code should allow for two values, a physics
    #        scheme value and 0 (off). Also, if the primary domain physics scheme is
    #        off, all domains will be off.  Additional parent-child matching is done
    #        in the primary physics configuration module.
    #============================================================================================================
    #
    @opts  = (2,0,1,2,3,4,5,6,7,8,9,10,11,13,14,16,17,18,19,21,22,28,30,32,50,51);
    $dval  = (defined $defnl{PHYSICS}{mp_physics}[0]) ? $defnl{PHYSICS}{mp_physics}[0] : $opts[0];
    $cval  = (defined $eparms{MP_PHYSICS} and $eparms{MP_PHYSICS}[0]) ? $eparms{MP_PHYSICS}[0] : $dval;

    unless (grep {/^${cval}$/} @opts) {
        my @popts = sort {$a <=> $b} @opts; my $vstr = &Ecomm::JoinString(\@popts);
        $mesg = "I'm not quite sure what you are thinking, but \"$cval\" is not a valid option for ".
                "the MP_PHYSICS parameter in the run_physics_microphysics.conf file. Available ".
                "options include $vstr, so why don't you try one of those values instead.\n\n".
                "We'll both be glad you did.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Get With The MP_PHYSICS Program:',$mesg);
        return ();
    }
    
    #  MP_PHYSICS must be the same for all domains
    #
    @{$eparms{MP_PHYSICS}} = ($cval) x $Config{maxdoms};


    #============================================================================
    #  PHYSICS_MICROPHYSICS: NO_MP_HEATING (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{no_mp_heating}[0]) ? $defnl{PHYSICS}{no_mp_heating}[0] : 1;
    $cval  = (defined $eparms{NO_MP_HEATING} and $eparms{NO_MP_HEATING}[0]) ? $eparms{NO_MP_HEATING}[0] : $dval;
    $cval  = 0 unless $eparms{MP_PHYSICS}[0];

    @{$eparms{NO_MP_HEATING}}      = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  PHYSICS_MICROPHYSICS: MP_ZERO_OUT (defined values)
    #============================================================================
    #
    @opts  = (0,1,2);
    # No MP_ZERO_OUT with PDA
    #
    foreach my $parm (qw(MOIST_ADV_OPT SCALAR_ADV_OPT CHEM_ADV_OPT TKE_ADV_OPT)) {@opts  = (0) if grep {/^$eparms{$parm}[0]$/} (1,4);}
    $dval  = (defined $defnl{PHYSICS}{mp_zero_out}[0]) ? $defnl{PHYSICS}{mp_zero_out}[0] : $opts[0];
    $cval  = (defined $eparms{MP_ZERO_OUT} and $eparms{MP_ZERO_OUT}[0]) ? $eparms{MP_ZERO_OUT}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{MP_ZERO_OUT}} = ($cval);


    #============================================================================
    #  PHYSICS_MICROPHYSICS: MP_ZERO_OUT_THRESH (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{mp_zero_out_thresh}[0]) ? $defnl{PHYSICS}{mp_zero_out_thresh}[0] : 1.e-8;
    $cval  = (defined $eparms{MP_ZERO_OUT_THRESH}[0])      ? $eparms{MP_ZERO_OUT_THRESH}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{MP_ZERO_OUT_THRESH}} = ($cval);



    #============================================================================
    #  PHYSICS_MICROPHYSICS: GSFCGCE_2ICE (defined values)
    #============================================================================
    #
    @opts  = (0,1,2);
    $dval  = (defined $defnl{PHYSICS}{gsfcgce_2ice}[0]) ? $defnl{PHYSICS}{gsfcgce_2ice}[0] : $opts[0];
    $cval  = (defined $eparms{GSFCGCE_2ICE} and $eparms{GSFCGCE_2ICE}[0]) ? $eparms{GSFCGCE_2ICE}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{GSFCGCE_2ICE}} = ($cval);


    #============================================================================
    #  PHYSICS_MICROPHYSICS: GSFCGCE_HAIL (defined values)
    #============================================================================
    #
    @opts  = (0,1);
    $dval  = (defined $defnl{PHYSICS}{gsfcgce_hail}[0]) ? $defnl{PHYSICS}{gsfcgce_hail}[0] : $opts[0];
    $cval  = (defined $eparms{GSFCGCE_HAIL} and $eparms{GSFCGCE_HAIL}[0]) ? $eparms{GSFCGCE_HAIL}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;
    $cval  = 0 if $eparms{GSFCGCE_2ICE}[0];  #  GSFCGCE_HAIL is ignored if GSFCGCE_2ICE = 1 or 2

    @{$eparms{GSFCGCE_HAIL}} = ($cval);


    #============================================================================
    #  PHYSICS_MICROPHYSICS: HAIL_OPT (defined values)
    #============================================================================
    #
    @opts  = (0,1);
    $dval  = (defined $defnl{PHYSICS}{hail_opt}[0]) ? $defnl{PHYSICS}{hail_opt}[0] : $opts[0];
    $cval  = (defined $eparms{HAIL_OPT} and $eparms{HAIL_OPT}[0]) ? $eparms{HAIL_OPT}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{HAIL_OPT}} = ($cval);


    #============================================================================
    #  PHYSICS_MICROPHYSICS: CCN_CONC (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{ccn_conc}[0]) ? $defnl{PHYSICS}{ccn_conc}[0] : 1.e8;
    $cval  = (defined $eparms{CCN_CONC}[0])      ? $eparms{CCN_CONC}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{CCN_CONC}} = ($cval);


    #============================================================================
    #  PHYSICS_MICROPHYSICS: NSSL_ALPHAH (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{nssl_alphah}[0]) ? $defnl{PHYSICS}{nssl_alphah}[0] : 0.;
    $cval  = (defined $eparms{NSSL_ALPHAH}[0])      ? $eparms{NSSL_ALPHAH}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{NSSL_ALPHAH}} = ($cval);


    #============================================================================
    #  PHYSICS_MICROPHYSICS: NSSL_ALPHAHL (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{nssl_alphahl}[0]) ? $defnl{PHYSICS}{nssl_alphahl}[0] : 2.;
    $cval  = (defined $eparms{NSSL_ALPHAHL}[0])      ? $eparms{NSSL_ALPHAHL}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{NSSL_ALPHAHL}} = ($cval);


    #============================================================================
    #  PHYSICS_MICROPHYSICS: NSSL_CNOH (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{nssl_cnoh}[0]) ? $defnl{PHYSICS}{nssl_cnoh}[0] : 4.e5;
    $cval  = (defined $eparms{NSSL_CNOH}[0])      ? $eparms{NSSL_CNOH}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{NSSL_CNOH}} = ($cval);


    #============================================================================
    #  PHYSICS_MICROPHYSICS: NSSL_CNOHL (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{nssl_cnohl}[0]) ? $defnl{PHYSICS}{nssl_cnohl}[0] : 4.e4;
    $cval  = (defined $eparms{NSSL_CNOHL}[0])      ? $eparms{NSSL_CNOHL}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{NSSL_CNOHL}} = ($cval);


    #============================================================================
    #  PHYSICS_MICROPHYSICS: NSSL_CNOR (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{nssl_cnor}[0]) ? $defnl{PHYSICS}{nssl_cnor}[0] : 8.e5;
    $cval  = (defined $eparms{NSSL_CNOR}[0])      ? $eparms{NSSL_CNOR}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{NSSL_CNOR}} = ($cval);


    #============================================================================
    #  PHYSICS_MICROPHYSICS: NSSL_CNOS (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{nssl_cnos}[0]) ? $defnl{PHYSICS}{nssl_cnos}[0] : 3.e6;
    $cval  = (defined $eparms{NSSL_CNOS}[0])      ? $eparms{NSSL_CNOS}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{NSSL_CNOS}} = ($cval);


    #============================================================================
    #  PHYSICS_MICROPHYSICS: NSSL_RHO_QH (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{nssl_rho_qh}[0]) ? $defnl{PHYSICS}{nssl_rho_qh}[0] : 500.;
    $cval  = (defined $eparms{NSSL_RHO_QH}[0])      ? $eparms{NSSL_RHO_QH}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{NSSL_RHO_QH}} = ($cval);


    #============================================================================
    #  PHYSICS_MICROPHYSICS: NSSL_RHO_QHL (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{nssl_rho_qhl}[0]) ? $defnl{PHYSICS}{nssl_rho_qhl}[0] : 900.;
    $cval  = (defined $eparms{NSSL_RHO_QHL}[0])      ? $eparms{NSSL_RHO_QHL}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{NSSL_RHO_QHL}} = ($cval);


    #============================================================================
    #  PHYSICS_MICROPHYSICS: NSSL_RHO_QS (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{nssl_rho_qs}[0]) ? $defnl{PHYSICS}{nssl_rho_qs}[0] : 100.;
    $cval  = (defined $eparms{NSSL_RHO_QS}[0])      ? $eparms{NSSL_RHO_QS}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{NSSL_RHO_QS}} = ($cval);


    #============================================================================
    #  PHYSICS_MICROPHYSICS: PROGN (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{progn}[0]) ? $defnl{PHYSICS}{progn}[0] : 1;
    $cval  = (defined $eparms{PROGN} and $eparms{PROGN}[0]) ? $eparms{PROGN}[0] : $dval;

    @{$eparms{PROGN}}       = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  PHYSICS_MICROPHYSICS: DO_RADAR_REF (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{do_radar_ref}[0]) ? $defnl{PHYSICS}{do_radar_ref}[0] : 1;
    $cval  = (defined $eparms{DO_RADAR_REF} and $eparms{DO_RADAR_REF}[0]) ? $eparms{DO_RADAR_REF}[0] : $dval;
    $cval  = 1;  #  Override - Always ON

    @{$eparms{DO_RADAR_REF}}       = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  PHYSICS_MICROPHYSICS: USE_AERO_ICBC (T|F) - Set to 'F' if no WIF data
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{use_aero_icbc}[0]) ? $defnl{PHYSICS}{use_aero_icbc}[0] : 'T';
    $cval  = (defined $eparms{USE_AERO_ICBC} and $eparms{USE_AERO_ICBC}[0]) ? $eparms{USE_AERO_ICBC}[0] : $dval;
    $cval  = 'F' unless $renv{nwifs};  #  Must be OFF unless WIF data are in WPS files

    @{$eparms{USE_AERO_ICBC}}       = &SetValues_TrueFalse($cval,$dval,1);



    #============================================================================================================
    #  PHYSICS_BOUNDARYLAYER: BL_PBL_PHYSICS (multiple values with error mesg)
    #  
    #  NOTE: The following somewhat messy code should allow for two values, a physics
    #        scheme value and 0 (off). Also, if the primary domain physics scheme is
    #        off, all domains will be off.  Additional parent-child matching is done
    #        in the primary physics configuration module.
    #============================================================================================================
    #
    @opts  = (1,0,2,4,5,6,7,8,9,10,11,12);
    $dval  = (defined $defnl{PHYSICS}{bl_pbl_physics}[0]) ? $defnl{PHYSICS}{bl_pbl_physics}[0] : $opts[0];
    @cvals = (defined $eparms{BL_PBL_PHYSICS} and @{$eparms{BL_PBL_PHYSICS}}) ? @{$eparms{BL_PBL_PHYSICS}} : ($dval) x $Config{maxdoms};

    foreach my $cval (@cvals) {

        $cval = $cval ? $cvals[0] : 0;

        unless (grep {/^${cval}$/} @opts) {
            my @popts = sort {$a <=> $b} @opts; my $vstr  = &Ecomm::JoinString(\@popts);
            $mesg = "I'm not quite sure what you are thinking, but \"$cval\" is not a valid option for ".
                    "the BL_PBL_PHYSICS parameter in the run_physics_boundarylayer.conf file. Available ".
                    "options include $vstr, so why don't you try one of those values instead.\n\n".
                    "We'll both be glad you did.";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Get With The BL_PBL_PHYSICS Program:',$mesg);
            return ();
        }

    }
    @rvals = ($cvals[0]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{BL_PBL_PHYSICS}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  PHYSICS_BOUNDARYLAYER: BLDT (any number value) (Max Domains)
    #============================================================================
    #
    @rvals = (0) x $Config{maxdoms};
    @dvals = ($defnl{PHYSICS}{bldt} and @{$defnl{PHYSICS}{bldt}}) ? @{$defnl{PHYSICS}{bldt}} : @rvals;
    @cvals = ($eparms{BLDT} and @{$eparms{BLDT}})                  ? @{$eparms{BLDT}}         : @dvals;

    foreach (@cvals) {$_ = 0 unless $_ and &Others::isNumber($_) and $_ > 0;}
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{BLDT}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  PHYSICS_BOUNDARYLAYER: GRAV_SETTLING (max domains)
    #  Not used with Thompson Aerosol Aware MP scheme (28)
    #============================================================================
    #
    @opts  = (0,1,2);
    @rvals = ($opts[0]) x $Config{maxdoms};
    @dvals = ($defnl{PHYSICS}{grav_settling} and @{$defnl{PHYSICS}{grav_settling}}) ? @{$defnl{PHYSICS}{grav_settling}} : @rvals;
    @cvals = ($eparms{GRAV_SETTLING} and @{$eparms{GRAV_SETTLING}})                  ? @{$eparms{GRAV_SETTLING}}         : @dvals;

    foreach (@cvals) {$_ = 0 unless $_ and $_ =~ /^\d+$/ and $_ > 0;}
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{GRAV_SETTLING}} = ($eparms{MP_PHYSICS}[0] == 28) ? (0) x $Config{maxdoms} : @rvals[0..$Config{maxindex}];


    #============================================================================
    #  PHYSICS_BOUNDARYLAYER: SCALAR_PBLMIX (1|0)
    #  Turn ON with Thompson Aerosol Aware MP scheme (28)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{scalar_pblmix}[0]) ? $defnl{PHYSICS}{scalar_pblmix}[0] : 1;
    $cval  = (defined $eparms{SCALAR_PBLMIX}) ? $eparms{SCALAR_PBLMIX}[0] : $dval;
    $cval  = 1 if $eparms{MP_PHYSICS}[0] == 28;

    @{$eparms{SCALAR_PBLMIX}}      = &SetValues_OnOff($cval,$dval,$Config{maxdoms});


    #============================================================================
    #  PHYSICS_BOUNDARYLAYER: TRACER_PBLMIX (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{tracer_pblmix}[0]) ? $defnl{PHYSICS}{tracer_pblmix}[0] : 1;
    $cval  = (defined $eparms{TRACER_PBLMIX}) ? $eparms{TRACER_PBLMIX}[0] : $dval;

    @{$eparms{TRACER_PBLMIX}}      = &SetValues_OnOff($cval,$dval,$Config{maxdoms});


    #============================================================================
    #  PHYSICS_BOUNDARYLAYER: TOPO_WIND (Max Domains)
    #============================================================================
    #
    @opts  = (0,1,2);
    @dvals = ($defnl{PHYSICS}{topo_wind} and @{$defnl{PHYSICS}{topo_wind}}) ? @{$defnl{PHYSICS}{topo_wind}} : (0);
    @cvals = ($eparms{TOPO_WIND} and @{$eparms{TOPO_WIND}})                 ? @{$eparms{TOPO_WIND}}         : @dvals;

     
    #  Note:  Must have VAR_SSO in geo_em.d01.nc to use TOPO_WIND - Turn off if missing
    #
    @cvals = (0) unless $renv{varsso};

    $cvals[0] = $opts[0] unless grep {/^$cvals[0]$/} @opts;

    foreach  my $c (@cvals) {$c = $cvals[0] unless (grep {/^${c}$/} @opts);}
    @rvals = ($cvals[-1]) x $Config{maxdoms};

    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{TOPO_WIND}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  PHYSICS_BOUNDARYLAYER: YSU_TOPDOWN_PBLMIX (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{ysu_topdown_pblmix}[0]) ? $defnl{PHYSICS}{ysu_topdown_pblmix}[0] : 0;
    $cval  = (defined $eparms{YSU_TOPDOWN_PBLMIX} and $eparms{YSU_TOPDOWN_PBLMIX}[0]) ? $eparms{YSU_TOPDOWN_PBLMIX}[0] : $dval;

    @{$eparms{YSU_TOPDOWN_PBLMIX}}      = &SetValues_OnOff($cval,$dval,$Config{maxdoms});


    #============================================================================
    #  PHYSICS_BOUNDARYLAYER: ICLOUD_BL (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{icloud_bl}[0]) ? $defnl{PHYSICS}{icloud_bl}[0] : 1;
    $cval  = (defined $eparms{ICLOUD_BL} and $eparms{ICLOUD_BL}[0]) ? $eparms{ICLOUD_BL}[0] : $dval;

    @{$eparms{ICLOUD_BL}}      = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  PHYSICS_BOUNDARYLAYER: BL_MYNN_TKEBUDGET (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{bl_mynn_tkebudget}[0]) ? $defnl{PHYSICS}{bl_mynn_tkebudget}[0] : 1;
    $cval  = (defined $eparms{BL_MYNN_TKEBUDGET} and $eparms{BL_MYNN_TKEBUDGET}[0]) ? $eparms{BL_MYNN_TKEBUDGET}[0] : $dval;

    @{$eparms{BL_MYNN_TKEBUDGET}}      = &SetValues_OnOff($cval,$dval,$pkeys{bl_mynn_tkebudget}{maxdoms});


    #============================================================================
    #  PHYSICS_BOUNDARYLAYER: BL_MYNN_TKEADVECT (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{bl_mynn_tkeadvect}[0]) ? $defnl{PHYSICS}{bl_mynn_tkeadvect}[0] : 'F';
    $cval  = (defined $eparms{BL_MYNN_TKEADVECT} and $eparms{BL_MYNN_TKEADVECT}[0]) ? $eparms{BL_MYNN_TKEADVECT}[0] : $dval;

    @{$eparms{BL_MYNN_TKEADVECT}}      = &SetValues_TrueFalse($cval,$dval,$pkeys{bl_mynn_tkeadvect}{maxdoms});


    #============================================================================
    #  PHYSICS_BOUNDARYLAYER: BL_MYNN_CLOUDMIX (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{bl_mynn_cloudmix}[0]) ? $defnl{PHYSICS}{bl_mynn_cloudmix}[0] : 1;
    $cval  = (defined $eparms{BL_MYNN_CLOUDMIX} and $eparms{BL_MYNN_CLOUDMIX}[0]) ? $eparms{BL_MYNN_CLOUDMIX}[0] : $dval;

    @{$eparms{BL_MYNN_CLOUDMIX}}      = &SetValues_OnOff($cval,$dval,$pkeys{bl_mynn_cloudmix}{maxdoms});


    #============================================================================
    #  PHYSICS_BOUNDARYLAYER: BL_MYNN_MIXLENGTH (defined values)
    #============================================================================
    #
    @opts  = (1,0,2);
    $dval  = (defined $defnl{PHYSICS}{bl_mynn_mixlength}[0]) ? $defnl{PHYSICS}{bl_mynn_mixlength}[0] : $opts[0];
    $cval  = (defined $eparms{BL_MYNN_MIXLENGTH} and $eparms{BL_MYNN_MIXLENGTH}[0]) ? $eparms{BL_MYNN_MIXLENGTH}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{BL_MYNN_MIXLENGTH}} = ($cval) x $pkeys{bl_mynn_mixlength}{maxdoms};


    #============================================================================
    #  PHYSICS_BOUNDARYLAYER: BL_MYNN_CLOUDPDF (defined values)
    #============================================================================
    #
    @opts  = (2,1,0);
    $dval  = (defined $defnl{PHYSICS}{bl_mynn_cloudpdf}[0]) ? $defnl{PHYSICS}{bl_mynn_cloudpdf}[0] : $opts[0];
    $cval  = (defined $eparms{BL_MYNN_CLOUDPDF} and $eparms{BL_MYNN_CLOUDPDF}[0]) ? $eparms{BL_MYNN_CLOUDPDF}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{BL_MYNN_CLOUDPDF}} = ($cval) x $pkeys{bl_mynn_cloudpdf}{maxdoms};


    #============================================================================
    #  PHYSICS_BOUNDARYLAYER: BL_MYNN_EDMF (defined values)
    #============================================================================
    #
    @opts  = (1,0);  #  (0,1,2);  (TEMF option disabled for now)
    $dval  = (defined $defnl{PHYSICS}{bl_mynn_edmf}[0]) ? $defnl{PHYSICS}{bl_mynn_edmf}[0] : $opts[0];
    $cval  = (defined $eparms{BL_MYNN_EDMF} and $eparms{BL_MYNN_EDMF}[0]) ? $eparms{BL_MYNN_EDMF}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{BL_MYNN_EDMF}} = ($cval) x $pkeys{bl_mynn_edmf}{maxdoms};


    #============================================================================
    #  PHYSICS_BOUNDARYLAYER: BL_MYNN_EDMF_MOM (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{bl_mynn_edmf_mom}[0]) ? $defnl{PHYSICS}{bl_mynn_edmf_mom}[0] : 0;
    $cval  = (defined $eparms{BL_MYNN_EDMF_MOM} and $eparms{BL_MYNN_EDMF_MOM}[0]) ? $eparms{BL_MYNN_EDMF_MOM}[0] : $dval;
    $cval  = 0 unless $eparms{BL_MYNN_EDMF}[0];

    @{$eparms{BL_MYNN_EDMF_MOM}}  = &SetValues_OnOff($cval,$dval,$pkeys{bl_mynn_edmf_mom}{maxdoms});


    #============================================================================
    #  PHYSICS_BOUNDARYLAYER: BL_MYNN_EDMF_TKE (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{bl_mynn_edmf_tke}[0]) ? $defnl{PHYSICS}{bl_mynn_edmf_tke}[0] : 0;
    $cval  = (defined $eparms{BL_MYNN_EDMF_TKE} and $eparms{BL_MYNN_EDMF_TKE}[0]) ? $eparms{BL_MYNN_EDMF_TKE}[0] : $dval;
    $cval  = 0 unless $eparms{BL_MYNN_EDMF}[0];

    @{$eparms{BL_MYNN_EDMF_TKE}}  = &SetValues_OnOff($cval,$dval,$pkeys{bl_mynn_edmf_tke}{maxdoms});


    #============================================================================
    #  PHYSICS_BOUNDARYLAYER: SHINHONG_TKE_DIAG (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{shinhong_tke_diag}[0]) ? $defnl{PHYSICS}{shinhong_tke_diag}[0] : 0;
    $cval  = (defined $eparms{SHINHONG_TKE_DIAG} and $eparms{SHINHONG_TKE_DIAG}[0]) ? $eparms{SHINHONG_TKE_DIAG}[0] : $dval;
    $cval  = 0 unless $eparms{BL_MYNN_EDMF}[0];

    @{$eparms{SHINHONG_TKE_DIAG}}  = &SetValues_OnOff($cval,$dval,1);


    #============================================================================================================
    #  PHYSICS_CUMULUS: CU_PHYSICS (multiple values with error mesg)
    #  
    #  NOTE: The following somewhat messy code should allow for two values, a physics
    #        scheme value and 0 (off). Also, if the primary domain physics scheme is
    #        off, all domains will be off.  Additional parent-child matching is done
    #        in the primary physics configuration module.
    #============================================================================================================
    #
    @opts  = (11,0,1,2,3,4,5,6,7,10,14,16,84,93);
    $dval  = (defined $defnl{PHYSICS}{cu_physics}[0]) ? $defnl{PHYSICS}{cu_physics}[0] : $opts[0];
    @cvals = (defined $eparms{CU_PHYSICS} and @{$eparms{CU_PHYSICS}}) ? @{$eparms{CU_PHYSICS}} : ($dval) x $Config{maxdoms};

    foreach my $cval (@cvals) {

        $cval = $cval ? $cvals[0] : 0;

        unless (grep {/^${cval}$/} @opts) {
            my @popts = sort {$a <=> $b} @opts; my $vstr  = &Ecomm::JoinString(\@popts);
            $mesg = "I'm not quite sure what you are thinking, but \"$cval\" is not a valid option for ".
                    "the CU_PHYSICS parameter in the run_physics_cumulus.conf file. Available ".
                    "options include $vstr, so why don't you try one of those values instead.\n\n".
                    "We'll both be glad you did.";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Get With The CU_PHYSICS Program:',$mesg);
            return ();
        }

    }
    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{CU_PHYSICS}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  PHYSICS_CUMULUS: KFETA_TRIGGER (defined values)
    #============================================================================
    #
    @opts  = (1,2,3);
    $dval  = (defined $defnl{PHYSICS}{kfeta_trigger}[0]) ? $defnl{PHYSICS}{kfeta_trigger}[0] : $opts[0];
    $cval  = (defined $eparms{KFETA_TRIGGER} and $eparms{KFETA_TRIGGER}[0]) ? $eparms{KFETA_TRIGGER}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{KFETA_TRIGGER}} = ($cval);


    #============================================================================
    #  PHYSICS_CUMULUS: KF_EDRATES (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{kf_edrates}[0]) ? $defnl{PHYSICS}{kf_edrates}[0] : 1;
    $cval  = (defined $eparms{KF_EDRATES} and $eparms{KF_EDRATES}[0]) ? $eparms{KF_EDRATES}[0] : $dval;

    @{$eparms{KF_EDRATES}}      = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  PHYSICS_CUMULUS: CUDT (max domain)
    #============================================================================
    #
    @opts  = (1,11,99);
    @rvals = (0) x $Config{maxdoms};
    @dvals = ($defnl{PHYSICS}{cudt} and @{$defnl{PHYSICS}{cudt}}) ? @{$defnl{PHYSICS}{cudt}} : ($rvals[0]);
    @cvals = ($eparms{CUDT} and @{$eparms{CUDT}})                  ? @{$eparms{CUDT}}         : @dvals;

    foreach (@cvals) {$_ = $rvals[0] unless &Others::isNumber($_) and $_ > 0.};

    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{CUDT}} = @rvals[0..$Config{maxindex}];
    @{$eparms{CUDT}} = (0) unless grep {/^$eparms{CU_PHYSICS}[0]$/} @opts; #  Only valid for CU = 1,11,99


    #============================================================================
    #  PHYSICS_CUMULUS: CUGD_AVEDX (integer value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{cugd_avedx}[0]) ? $defnl{PHYSICS}{cugd_avedx}[0] : 'Auto';
    $cval  = (defined $eparms{CUGD_AVEDX} and $eparms{CUGD_AVEDX}[0]) ? $eparms{CUGD_AVEDX}[0] : $dval;
    $cval  = $dval unless $cval =~ /^Auto/i or (&Others::isNumber($cval) and &Others::isInteger($cval) and $cval > 0.);
    $cval  = 'Auto' if $cval =~ /^Auto/i;

    @{$eparms{CUGD_AVEDX}} = ($cval);


    #============================================================================
    #  PHYSICS_CUMULUS: CU_RAD_FEEDBACK (max domains: set in physics)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{cu_rad_feedback}[0]) ? $defnl{PHYSICS}{cu_rad_feedback}[0] : 'T';
    $cval  = (defined $eparms{CU_RAD_FEEDBACK} and $eparms{CU_RAD_FEEDBACK}[0]) ? $eparms{CU_RAD_FEEDBACK}[0] : $dval;

    @{$eparms{CU_RAD_FEEDBACK}}  = &SetValues_TrueFalse($cval,$dval,1);
    @{$eparms{CU_RAD_FEEDBACK}}  = ('T') if $eparms{CU_PHYSICS}[0] == 10 or  $eparms{CU_PHYSICS}[0] == 11;  # Per configuration file


    #============================================================================
    #  PHYSICS_CUMULUS: NSAS_DX_FACTOR (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{nsas_dx_factor}[0]) ? $defnl{PHYSICS}{nsas_dx_factor}[0] : 0;
    $cval  = (defined $eparms{NSAS_DX_FACTOR} and $eparms{NSAS_DX_FACTOR}[0]) ? $eparms{NSAS_DX_FACTOR}[0] : $dval;

    @{$eparms{NSAS_DX_FACTOR}}      = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  PHYSICS_CUMULUS: NUMBINS (ODD integer value; max domains)
    #============================================================================
    #
    @rvals = (0) x $Config{maxdoms};
    @dvals = ($defnl{PHYSICS}{numbins} and @{$defnl{PHYSICS}{numbins}}) ? @{$defnl{PHYSICS}{numbins}} : (21);
    @cvals = ($eparms{NUMBINS} and @{$eparms{NUMBINS}})                  ? @{$eparms{NUMBINS}}         : @dvals;

    $cvals[0] = 21 unless $cvals[0] and &Others::isNumber($cvals[0]) and $cvals[0] > 0; $cvals[0] = int $cvals[0]; $cvals[0]++ unless $cvals[0]%2;

    foreach (@cvals) {$_ = 0 unless $_ and &Others::isNumber($_) and $_ > 0; $_ = int $_; $_++ unless $_%2 or ! $_;}
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{NUMBINS}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  PHYSICS_CUMULUS: THBINSIZE (default: 0.1; max domains)
    #============================================================================
    #
    @rvals = (0) x $Config{maxdoms};
    @dvals = ($defnl{PHYSICS}{thbinsize} and @{$defnl{PHYSICS}{thbinsize}}) ? @{$defnl{PHYSICS}{thbinsize}} : @rvals;
    @cvals = ($eparms{THBINSIZE} and @{$eparms{THBINSIZE}})                  ? @{$eparms{THBINSIZE}}         : @dvals;

    $cvals[0] = 0.1 unless $cvals[0] and &Others::isNumber($cvals[0]) and $cvals[0] > 0;

    foreach (@cvals) {$_ = 0 unless $_ and &Others::isNumber($_) and $_ > 0;}
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{THBINSIZE}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  PHYSICS_CUMULUS: RBINSIZE (default: 0.3333;  max domains)
    #============================================================================
    #
    @rvals = (0) x $Config{maxdoms};
    @dvals = ($defnl{PHYSICS}{rbinsize} and @{$defnl{PHYSICS}{rbinsize}}) ? @{$defnl{PHYSICS}{rbinsize}} : @rvals;
    @cvals = ($eparms{RBINSIZE} and @{$eparms{RBINSIZE}})                  ? @{$eparms{RBINSIZE}}         : @dvals;

    $cvals[0] = 0.3333 unless $cvals[0] and &Others::isNumber($cvals[0]) and $cvals[0] > 0;

    foreach (@cvals) {$_ = 0 unless $_ and &Others::isNumber($_) and $_ > 0;}
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{RBINSIZE}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  PHYSICS_CUMULUS: MINDEEPFREQ (default: 0.0004; max domains)
    #============================================================================
    #
    @rvals = (0) x $Config{maxdoms};
    @dvals = ($defnl{PHYSICS}{mindeepfreq} and @{$defnl{PHYSICS}{mindeepfreq}}) ? @{$defnl{PHYSICS}{mindeepfreq}} : @rvals;
    @cvals = ($eparms{MINDEEPFREQ} and @{$eparms{MINDEEPFREQ}})                  ? @{$eparms{MINDEEPFREQ}}         : @dvals;

    $cvals[0] = 0.0004 unless $cvals[0] and &Others::isNumber($cvals[0]) and $cvals[0] > 0;

    foreach (@cvals) {$_ = 0 unless $_ and &Others::isNumber($_) and $_ > 0;}
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{MINDEEPFREQ}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  PHYSICS_CUMULUS: MINSHALLOWFREQ (default: 0.01; max domains)
    #============================================================================
    #
    @rvals = (0) x $Config{maxdoms};
    @dvals = ($defnl{PHYSICS}{minshallowfreq} and @{$defnl{PHYSICS}{minshallowfreq}}) ? @{$defnl{PHYSICS}{minshallowfreq}} : @rvals;
    @cvals = ($eparms{MINSHALLOWFREQ} and @{$eparms{MINSHALLOWFREQ}})                  ? @{$eparms{MINSHALLOWFREQ}}         : @dvals;

    $cvals[0] = 0.01 unless $cvals[0] and &Others::isNumber($cvals[0]) and $cvals[0] > 0;

    foreach (@cvals) {$_ = 0 unless $_ and &Others::isNumber($_) and $_ > 0;}
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{MINSHALLOWFREQ}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  PHYSICS_CUMULUS: SHALLOWCU_FORCED_RA (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{shallowcu_forced_ra}[0]) ? $defnl{PHYSICS}{shallowcu_forced_ra}[0] : 'F';
    $cval  = (defined $eparms{SHALLOWCU_FORCED_RA} and $eparms{SHALLOWCU_FORCED_RA}[0]) ? $eparms{SHALLOWCU_FORCED_RA}[0] : $dval;

    @{$eparms{SHALLOWCU_FORCED_RA}} = &SetValues_TrueFalse($cval,$dval,1);
    @{$eparms{SHALLOWCU_FORCED_RA}} = ('F') unless $eparms{CU_PHYSICS}[0] == 10;
    @{$eparms{SHALLOWCU_FORCED_RA}} = ('F'); # Set to 'False' for now


    #============================================================================
    #  PHYSICS_CUMULUS: SHCU_AEROSOLS_OPT (0|2)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{shcu_aerosols_opt}[0]) ? $defnl{PHYSICS}{shcu_aerosols_opt}[0] : 0;
    $cval  = (defined $eparms{SHCU_AEROSOLS_OPT} and $eparms{SHCU_AEROSOLS_OPT}[0]) ? $eparms{SHCU_AEROSOLS_OPT}[0] : $dval;
    $cval  = $cval ? 2 : 0;

    @{$eparms{SHCU_AEROSOLS_OPT}}  = ($cval) x $Config{maxdoms};
    @{$eparms{SHCU_AEROSOLS_OPT}}  = (0);  # Set to OFF for now - for WRF Chem only


    #============================================================================
    #  FROM WPS FILES: NUM_LAND_CAT (20,21,24,28,40,50)
    #============================================================================
    #
    @{$eparms{NUM_LAND_CAT}} = ();

    if (%{$renv{wpsfls}}) {

        unless (grep {/^$renv{nlcats}$/} (20,21,24,28,40,50)) {
            $mesg = "The number of land categories in $renv{wpsfls}{1}[0] ($renv{nlcats}) does not appear to valid ".
                    "for the USGS (24 or 28) or MODIS (20 or 21) datasets.\n\nUnfortunately this problem must be ".
                    "resolved before your life can return to normal.";
            $ENV{RMESG} = &Ecomm::TextFormat(0,0,84,0,0,'Number of Land Categories from WPS Files',$mesg);
            return ();
        }
        @{$eparms{NUM_LAND_CAT}} = ($renv{nlcats});

    }


    #============================================================================================================
    #  PHYSICS_LANDSURFACE: SF_SURFACE_PHYSICS (multiple values with error mesg)
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
    #  NOTE: The Land Surface Model choice depends upon the value of NUM_LAND_CAT in
    #        the WPS netCDF files created when ems_prep was run. If ems_prep was not
    #        run then assume that the --runinfo flag was passed and simply continue.
    #  
    #============================================================================================================
    #
    @opts  = (2,0,1,3,4,5,7,8);
    $dval  = (defined $defnl{PHYSICS}{sf_surface_physics}[0]) ? $defnl{PHYSICS}{sf_surface_physics}[0] : $opts[0];
    $cval  = (defined $eparms{SF_SURFACE_PHYSICS} and $eparms{SF_SURFACE_PHYSICS}[0]) ? $eparms{SF_SURFACE_PHYSICS}[0] : $dval;

    unless (grep {/^${cval}$/} @opts) {
        my @popts = sort {$a <=> $b} @opts; my $vstr = &Ecomm::JoinString(\@popts);
        $mesg = "I'm not quite sure what you are thinking, but \"$cval\" is not a valid option for ".
                "the SF_SURFACE_PHYSICS parameter in the run_physics_landsurface.conf file. Available ".
                "options include $vstr, so why don't you try one of those values instead.\n\n".
                "We'll both be glad you did.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Get With The SF_SURFACE_PHYSICS Program:',$mesg);
        return ();
    }

    #  If the WPS netCDF files are available make sure that the value of NUM_LAND_CAT is
    #  compatible with the LSM scheme.
    #
    if (%{$renv{wpsfls}}) { 

        @opts =  $renv{nlcats} == 20  ? qw(2 3 4 5 7 8 0)   :
                 $renv{nlcats} == 21  ? qw(2 3 4 5 7 8 0)   :
                 $renv{nlcats} == 24  ? qw(2 1 3 4 5 7 8 0) :
                 $renv{nlcats} == 28  ? qw(2 1 3 4 7 8 0)   :
                 $renv{nlcats} == 40  ? qw(7 0)             :
                 $renv{nlcats} == 50  ? qw(2 1 4 7 0)       :  qw(2 4 0);


        unless (grep {/^${cval}$/} @opts) {

            my $lopts =  ($cval == 0) ? 'USGS, USGS+lakes, MODIS, and MODIS+lakes' :
                         ($cval == 1) ? 'USGS and USGS+lakes'                      :
                         ($cval == 2) ? 'USGS, USGS+lakes, MODIS, and MODIS+lakes' :
                         ($cval == 3) ? 'USGS, USGS+lakes, MODIS, and MODIS+lakes' :
                         ($cval == 4) ? 'USGS, USGS+lakes, MODIS, and MODIS+lakes' :
                         ($cval == 5) ? 'MODIS, MODIS+lakes, and USGS (no lakes)'  :
                         ($cval == 7) ? 'USGS, USGS+lakes, MODIS, and MODIS+lakes' :
                         ($cval == 8) ? 'USGS (no lakes)'                          : 'USGS, USGS+lakes, MODIS, and MODIS+lakes';

             my $llu  =  ($renv{nlcats} == 20)  ? 'MODIS'       :
                         ($renv{nlcats} == 21)  ? 'MODIS+lakes' :
                         ($renv{nlcats} == 24)  ? 'USGS'        :
                         ($renv{nlcats} == 28)  ? 'USGS+lakes'  :
                         ($renv{nlcats} == 40)  ? 'NLCD2006'    : 'What are you looking at?!';

             my $alsm =  ($renv{nlcats} == 20)  ? 'SF_SURFACE_PHYSICS = 2, 3, 4, 5, 7, or 8' :
                         ($renv{nlcats} == 21)  ? 'SF_SURFACE_PHYSICS = 2, 3, 4, 5, or 7'     :
                         ($renv{nlcats} == 24)  ? 'SF_SURFACE_PHYSICS = 1, 2, 3, 4, 5, 7, or 8' :
                         ($renv{nlcats} == 28)  ? 'SF_SURFACE_PHYSICS = 1, 2, 3, 4, 7, or 8'       :
                         ($renv{nlcats} == 40)  ? 'SF_SURFACE_PHYSICS = 7' : 
                         ($renv{nlcats} == 50)  ? 'SF_SURFACE_PHYSICS = 7' : 'SF_SURFACE_PHYSICS = ?';


            my $avail = &Ecomm::JoinString(\@opts);

            $mesg = "Your choice of Land Surface Model (LSM), SF_SURFACE_PHYSICS = $cval, is not compatible with the ".
                    "number of land categories ($renv{nlcats}) available from the $llu datasets used to localize your ".
                    "computational domain.\n\n".

                    "Your options are to either relocalize your domain and use the $lopts datasets:\n\n".

                    "X02X%  ems_domain --localize <--usgs, --modis, --[no]lakes>\n\n".
                    "or reconsider the LSM being used:\n\n".

                    "X02X$alsm\n\n".

                    "and then fire me up again.  The moment is yours, so \"Carpe diem\"!";

             $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Land Surface Model Incompatible with Land Categories',$mesg);
             return ();
        }

    }

    #  SF_SURFACE_PHYSICS must be the same for all domains
    #
    @{$eparms{SF_SURFACE_PHYSICS}} = ($cval) x $Config{maxdoms};


    #============================================================================
    #  PHYSICS_LANDSURFACE: SURFACE_INPUT_SOURCE (1,2,3)
    #  Default was (1) prior to 3.8 now (3)
    #============================================================================
    #
    @opts  = (3,1,2);
    $dval  = (defined $defnl{PHYSICS}{surface_input_source}[0]) ? $defnl{PHYSICS}{surface_input_source}[0] : $opts[0];
    $cval  = (defined $eparms{SURFACE_INPUT_SOURCE} and $eparms{SURFACE_INPUT_SOURCE}[0]) ? $eparms{SURFACE_INPUT_SOURCE}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{SURFACE_INPUT_SOURCE}} = ($cval);


    #============================================================================
    #  PHYSICS_LANDSURFACE: IFSNOW (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{ifsnow}[0]) ? $defnl{PHYSICS}{ifsnow}[0] : 1;
    $cval  = (defined $eparms{IFSNOW} and $eparms{IFSNOW}[0]) ? $eparms{IFSNOW}[0] : $dval;

    @{$eparms{IFSNOW}}      = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  PHYSICS_LANDSURFACE: OPT_THCND (1|2)
    #============================================================================
    #
    @opts  = (1,2);
    $dval  = (defined $defnl{PHYSICS}{opt_thcnd}[0]) ? $defnl{PHYSICS}{opt_thcnd}[0] : 1;
    $cval  = (defined $eparms{OPT_THCND} and $eparms{OPT_THCND}[0]) ? $eparms{OPT_THCND}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;
    
    @{$eparms{OPT_THCND}} = ($cval);


    #============================================================================
    #  PHYSICS_LANDSURFACE: SF_SURFACE_MOSAIC (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{sf_surface_mosaic}[0]) ? $defnl{PHYSICS}{sf_surface_mosaic}[0] : 1;
    $cval  = (defined $eparms{SF_SURFACE_MOSAIC} and $eparms{SF_SURFACE_MOSAIC}[0]) ? $eparms{SF_SURFACE_MOSAIC}[0] : $dval;

    @{$eparms{SF_SURFACE_MOSAIC}}      = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  PHYSICS_LANDSURFACE: MOSAIC_CAT (integer value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{mosaic_cat}[0]) ? $defnl{PHYSICS}{mosaic_cat}[0] : 3;
    $cval  = (defined $eparms{MOSAIC_CAT} and $eparms{MOSAIC_CAT}[0]) ? $eparms{MOSAIC_CAT}[0] : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{MOSAIC_CAT}} = (int $cval);


    #============================================================================
    #  PHYSICS_LANDSURFACE: MOSAIC_LU (1|0) Only for RUC LSM
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{mosaic_lu}[0]) ? $defnl{PHYSICS}{mosaic_lu}[0] : 1;
    $cval  = (defined $eparms{MOSAIC_LU} and $eparms{MOSAIC_LU}[0]) ? $eparms{MOSAIC_LU}[0] : $dval;

    @{$eparms{MOSAIC_LU}}  = &SetValues_OnOff($cval,$dval,1);



   #============================================================================
    #  PHYSICS_LANDSURFACE: MOSAIC_SOIL (1|0) Only for RUC LSM
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{mosaic_soil}[0]) ? $defnl{PHYSICS}{mosaic_soil}[0] : 1;
    $cval  = (defined $eparms{MOSAIC_SOIL} and $eparms{MOSAIC_SOIL}[0]) ? $eparms{MOSAIC_SOIL}[0] : $dval;

    @{$eparms{MOSAIC_SOIL}}  = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  PHYSICS_LANDSURFACE: UA_PHYS (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{ua_phys}[0]) ? $defnl{PHYSICS}{ua_phys}[0] : 'T';
    $cval  = (defined $eparms{UA_PHYS} and $eparms{UA_PHYS}[0]) ? $eparms{UA_PHYS}[0] : $dval;

    @{$eparms{UA_PHYS}}      = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  PHYSICS_LANDSURFACE: RUC_NUM_SOIL_LEVELS (6|9)
    #============================================================================
    #
    $dval  = 6;
    $cval  = (defined $eparms{RUC_NUM_SOIL_LEVELS} and $eparms{RUC_NUM_SOIL_LEVELS}[0]) ? $eparms{RUC_NUM_SOIL_LEVELS}[0] : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval == 9;

    @{$eparms{RUC_NUM_SOIL_LEVELS}}      = $cval;


    #============================================================================
    #  PHYSICS_LANDSURFACE (NOT):  PXLSM_SMOIS_INIT (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{pxlsm_smois_init}[0]) ? $defnl{PHYSICS}{pxlsm_smois_init}[0] : 1;
    $cval  = (defined $eparms{PXLSM_SMOIS_INIT} and $eparms{PXLSM_SMOIS_INIT}[0]) ? $eparms{PXLSM_SMOIS_INIT}[0] : $dval;

    @{$eparms{PXLSM_SMOIS_INIT}}      = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  PHYSICS_LANDSURFACE: DVEG (various options)
    #============================================================================
    #
    @opts  = (4,1,2,3,5);
    $dval  = (defined $defnl{NOAH_MP}{dveg}[0]) ? $defnl{NOAH_MP}{dveg}[0] : $opts[0];
    $cval  = (defined $eparms{DVEG} and $eparms{DVEG}[0]) ? $eparms{DVEG}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{DVEG}} = ($cval);


    #============================================================================
    #  PHYSICS_LANDSURFACE: OPT_CRS (various options)
    #============================================================================
    #
    @opts  = (1,2);
    $dval  = (defined $defnl{NOAH_MP}{opt_crs}[0]) ? $defnl{NOAH_MP}{opt_crs}[0] : $opts[0];
    $cval  = (defined $eparms{OPT_CRS} and $eparms{OPT_CRS}[0]) ? $eparms{OPT_CRS}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{OPT_CRS}} = ($cval);


    #============================================================================
    #  PHYSICS_LANDSURFACE: OPT_SFC (various options)
    #============================================================================
    #
    @opts  = (1,2);
    $dval  = (defined $defnl{NOAH_MP}{opt_sfc}[0]) ? $defnl{NOAH_MP}{opt_sfc}[0] : $opts[0];
    $cval  = (defined $eparms{OPT_SFC} and $eparms{OPT_SFC}[0]) ? $eparms{OPT_SFC}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{OPT_SFC}} = ($cval);


    #============================================================================
    #  PHYSICS_LANDSURFACE: OPT_BTR (various options)
    #============================================================================
    #
    @opts  = (1,2,3);
    $dval  = (defined $defnl{NOAH_MP}{opt_btr}[0]) ? $defnl{NOAH_MP}{opt_btr}[0] : $opts[0];
    $cval  = (defined $eparms{OPT_BTR} and $eparms{OPT_BTR}[0]) ? $eparms{OPT_BTR}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{OPT_BTR}} = ($cval);


    #============================================================================
    #  PHYSICS_LANDSURFACE: OPT_RUN (various options)
    #============================================================================
    #
    @opts  = (1,2,3,4);
    $dval  = (defined $defnl{NOAH_MP}{opt_run}[0]) ? $defnl{NOAH_MP}{opt_run}[0] : $opts[0];
    $cval  = (defined $eparms{OPT_RUN} and $eparms{OPT_RUN}[0]) ? $eparms{OPT_RUN}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{OPT_RUN}} = ($cval);


    #============================================================================
    #  PHYSICS_LANDSURFACE: OPT_FRZ (various options)
    #============================================================================
    #
    @opts  = (1,2);
    $dval  = (defined $defnl{NOAH_MP}{opt_frz}[0]) ? $defnl{NOAH_MP}{opt_frz}[0] : $opts[0];
    $cval  = (defined $eparms{OPT_FRZ} and $eparms{OPT_FRZ}[0]) ? $eparms{OPT_FRZ}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{OPT_FRZ}} = ($cval);


    #============================================================================
    #  PHYSICS_LANDSURFACE: OPT_INF (various options)
    #============================================================================
    #
    @opts  = (1,2);
    $dval  = (defined $defnl{NOAH_MP}{opt_inf}[0]) ? $defnl{NOAH_MP}{opt_inf}[0] : $opts[0];
    $cval  = (defined $eparms{OPT_INF} and $eparms{OPT_INF}[0]) ? $eparms{OPT_INF}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{OPT_INF}} = ($cval);


    #============================================================================
    #  PHYSICS_LANDSURFACE: OPT_RAD (various options)
    #============================================================================
    #
    @opts  = (3,1,2);
    $dval  = (defined $defnl{NOAH_MP}{opt_rad}[0]) ? $defnl{NOAH_MP}{opt_rad}[0] : $opts[0];
    $cval  = (defined $eparms{OPT_RAD} and $eparms{OPT_RAD}[0]) ? $eparms{OPT_RAD}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{OPT_RAD}} = ($cval);


    #============================================================================
    #  PHYSICS_LANDSURFACE: OPT_ALB (various options)
    #============================================================================
    #
    @opts  = (2,1);
    $dval  = (defined $defnl{NOAH_MP}{opt_alb}[0]) ? $defnl{NOAH_MP}{opt_alb}[0] : $opts[0];
    $cval  = (defined $eparms{OPT_ALB} and $eparms{OPT_ALB}[0]) ? $eparms{OPT_ALB}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{OPT_ALB}} = ($cval);


    #============================================================================
    #  PHYSICS_LANDSURFACE: OPT_SNF (various options)
    #============================================================================
    #
    @opts  = (4,1,2,3);
    $dval  = (defined $defnl{NOAH_MP}{opt_snf}[0]) ? $defnl{NOAH_MP}{opt_snf}[0] : $opts[0];
    $cval  = (defined $eparms{OPT_SNF} and $eparms{OPT_SNF}[0]) ? $eparms{OPT_SNF}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{OPT_SNF}} = ($cval);


    #============================================================================
    #  PHYSICS_LANDSURFACE: OPT_TBOT (various options)
    #============================================================================
    #
    @opts  = (2,1);
    $dval  = (defined $defnl{NOAH_MP}{opt_tbot}[0]) ? $defnl{NOAH_MP}{opt_tbot}[0] : $opts[0];
    $cval  = (defined $eparms{OPT_TBOT} and $eparms{OPT_TBOT}[0]) ? $eparms{OPT_TBOT}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{OPT_TBOT}} = ($cval);


    #============================================================================
    #  PHYSICS_LANDSURFACE: OPT_STC (various options)
    #============================================================================
    #
    @opts  = (1,2,3);
    $dval  = (defined $defnl{NOAH_MP}{opt_stc}[0]) ? $defnl{NOAH_MP}{opt_stc}[0] : $opts[0];
    $cval  = (defined $eparms{OPT_STC} and $eparms{OPT_STC}[0]) ? $eparms{OPT_STC}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{OPT_STC}} = ($cval);


    #============================================================================
    #  PHYSICS_LANDSURFACE: OPT_GLA (various options)
    #============================================================================
    #
    @opts  = (1,2);
    $dval  = (defined $defnl{NOAH_MP}{opt_gla}[0]) ? $defnl{NOAH_MP}{opt_gla}[0] : $opts[0];
    $cval  = (defined $eparms{OPT_GLA} and $eparms{OPT_GLA}[0]) ? $eparms{OPT_GLA}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{OPT_GLA}} = ($cval);


    #============================================================================
    #  PHYSICS_LANDSURFACE: OPT_RSF (various options)
    #============================================================================
    #
    @opts  = (1,2,3,4);
    $dval  = (defined $defnl{NOAH_MP}{opt_rsf}[0]) ? $defnl{NOAH_MP}{opt_rsf}[0] : $opts[0];
    $cval  = (defined $eparms{OPT_RSF} and $eparms{OPT_RSF}[0]) ? $eparms{OPT_RSF}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{OPT_RSF}} = ($cval);


    #============================================================================
    #  PHYSICS_LANDSURFACE: NUM_SOIL_CAT (integer value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{num_soil_cat}[0]) ? $defnl{PHYSICS}{num_soil_cat}[0] : 16;
    $cval  = (defined $eparms{NUM_SOIL_CAT} and $eparms{NUM_SOIL_CAT}[0]) ? $eparms{NUM_SOIL_CAT}[0] : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{NUM_SOIL_CAT}} = (int $cval);


    #============================================================================
    #  PHYSICS_LANDSURFACE: TMN_UPDATE (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{tmn_update}[0]) ? $defnl{PHYSICS}{tmn_update}[0] : 0;
    $cval  = (defined $eparms{TMN_UPDATE} and $eparms{TMN_UPDATE}[0]) ? $eparms{TMN_UPDATE}[0] : $dval;

    @{$eparms{TMN_UPDATE}}      = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  PHYSICS_LANDSURFACE: LAGDAY (integer value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{lagday}[0]) ? $defnl{PHYSICS}{lagday}[0] : 150;
    $cval  = (defined $eparms{LAGDAY} and $eparms{LAGDAY}[0]) ? $eparms{LAGDAY}[0] : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{LAGDAY}} = (int $cval);


    #============================================================================
    #  PHYSICS_LANDSURFACE: USEMONALB (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{usemonalb}[0]) ? $defnl{PHYSICS}{usemonalb}[0] : 'T';
    $cval  = (defined $eparms{USEMONALB} and $eparms{USEMONALB}[0]) ? $eparms{USEMONALB}[0] : $dval;

    @{$eparms{USEMONALB}}           = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  PHYSICS_LANDSURFACE: RDMAXALB (T|F)
    #============================================================================
    # 
    $dval  = (defined $defnl{PHYSICS}{rdmaxalb}[0]) ? $defnl{PHYSICS}{rdmaxalb}[0] : 'T';
    $cval  = (defined $eparms{RDMAXALB} and $eparms{RDMAXALB}[0]) ? $eparms{RDMAXALB}[0] : $dval;

    @{$eparms{RDMAXALB}}            = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  PHYSICS_LANDSURFACE: RDLAI2D (T|F)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{rdlai2d}[0]) ? $defnl{PHYSICS}{rdlai2d}[0] : 'T';
    $cval  = (defined $eparms{RDLAI2D} and $eparms{RDLAI2D}[0]) ? $eparms{RDLAI2D}[0] : $dval;
    $cval  = 'F' unless defined $renv{lai12m} and $renv{lai12m};  #  because it must be in the file
     

    @{$eparms{RDLAI2D}}             = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================================================
    #  PHYSICS_RADIATION: RA_LW_PHYSICS (multiple values with error mesg)
    #  
    #  NOTE: The following somewhat messy code should allow for two values, a physics
    #        scheme value and 0 (off). Also, if the primary domain physics scheme is
    #        off, all domains will be off.  Additional parent-child matching is done
    #        in the primary physics configuration module.
    #============================================================================================================
    #
    @opts  = (1,0,3,4,5,7,24,31);
    $dval  = (defined $defnl{PHYSICS}{ra_lw_physics}[0]) ? $defnl{PHYSICS}{ra_lw_physics}[0] : $opts[0];
    $cval  = (defined $eparms{RA_LW_PHYSICS} and $eparms{RA_LW_PHYSICS}[0]) ? $eparms{RA_LW_PHYSICS}[0] : $dval;

    unless (grep {/^${cval}$/} @opts) {
        my @popts = sort {$a <=> $b} @opts; my $vstr = &Ecomm::JoinString(\@popts);
        $mesg = "I'm not quite sure what you are thinking, but \"$cval\" is not a valid option for ".
                "the RA_LW_PHYSICS parameter in the run_physics_radiation.conf file. Available ".
                "options include $vstr, so why don't you try one of those values instead.\n\n".
                "We'll both be glad you did.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Get With The RA_LW_PHYSICS Program:',$mesg);
        return ();
    }

    #  RA_LW_PHYSICS must be the same for all domains
    #
    @{$eparms{RA_LW_PHYSICS}} = ($cval) x $Config{maxdoms};


    #============================================================================================================
    #  PHYSICS_RADIATION: RA_SW_PHYSICS (multiple values with error mesg)
    #  
    #  NOTE: The following somewhat messy code should allow for two values, a physics
    #        scheme value and 0 (off). Also, if the primary domain physics scheme is
    #        off, all domains will be off.  Additional parent-child matching is done
    #        in the primary physics configuration module.
    #============================================================================================================
    #
    @opts  = (2,1,0,3,4,5,7,24);
    $dval  = (defined $defnl{PHYSICS}{ra_sw_physics}[0]) ? $defnl{PHYSICS}{ra_sw_physics}[0] : $opts[0];
    $cval  = (defined $eparms{RA_SW_PHYSICS} and $eparms{RA_SW_PHYSICS}[0]) ? $eparms{RA_SW_PHYSICS}[0] : $dval;

    unless (grep {/^${cval}$/} @opts) {
        my @popts = sort {$a <=> $b} @opts; my $vstr = &Ecomm::JoinString(\@popts);
        $mesg = "I'm not quite sure what you are thinking, but \"$cval\" is not a valid option for ".
                "the RA_SW_PHYSICS parameter in the run_physics_radiation.conf file. Available ".
                "options include $vstr, so why don't you try one of those values instead.\n\n".
                "We'll both be glad you did.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Get With The RA_SW_PHYSICS Program:',$mesg);
        return ();
    }

    #  RA_SW_PHYSICS must be the same for all domains
    #
    @{$eparms{RA_SW_PHYSICS}} = ($cval) x $Config{maxdoms};


    #============================================================================
    #  PHYSICS_RADIATION: RADT (Various options) (Max Domains)
    #
    #  Multiple possibilities - worry about them in @Physics_Radiation
    #============================================================================
    #
    @dvals = ($defnl{PHYSICS}{radt} and @{$defnl{PHYSICS}{radt}}) ? @{$defnl{PHYSICS}{radt}} : ('Auto_1');
    @cvals = ($eparms{RADT} and @{$eparms{RADT}})                  ? @{$eparms{RADT}}         : @dvals;
    @{$eparms{RADT}} = @cvals;


    #============================================================================
    #  PHYSICS_RADIATION: SLOPE_RAD (1|0) (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{PHYSICS}{slope_rad} and @{$defnl{PHYSICS}{slope_rad}}) ? @{$defnl{PHYSICS}{slope_rad}} : (0);
    @cvals = ($eparms{SLOPE_RAD} and @{$eparms{SLOPE_RAD}})                  ? @{$eparms{SLOPE_RAD}}         : @dvals;
    foreach (@cvals) {$_ = &SetValues_OnOff($_,0,1);}

    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{SLOPE_RAD}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  PHYSICS_RADIATION: TOPO_SHADING (1|0) (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{PHYSICS}{topo_shading} and @{$defnl{PHYSICS}{topo_shading}}) ? @{$defnl{PHYSICS}{topo_shading}} : (0);
    @cvals = ($eparms{TOPO_SHADING} and @{$eparms{TOPO_SHADING}})                  ? @{$eparms{TOPO_SHADING}}         : @dvals;
    foreach (@cvals) {$_ = &SetValues_OnOff($_,0,1);}

    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{TOPO_SHADING}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  PHYSICS_RADIATION: SHADLEN (25000)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{shadlen}[0]) ? $defnl{PHYSICS}{shadlen}[0] : 25000;
    $cval  = (defined $eparms{SHADLEN}[0])      ? $eparms{SHADLEN}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 500. and $cval < 100000.;

    @{$eparms{SHADLEN}} = (int $cval);


    #============================================================================
    #  PHYSICS_RADIATION: SWINT_OPT (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{swint_opt}[0]) ? $defnl{PHYSICS}{swint_opt}[0] : 1;
    $cval  = (defined $eparms{SWINT_OPT} and $eparms{SWINT_OPT}[0]) ? $eparms{SWINT_OPT}[0] : $dval;

    @{$eparms{SWINT_OPT}}      = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  PHYSICS_RADIATION: SWRAD_SCAT (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{swrad_scat}[0]) ? $defnl{PHYSICS}{swrad_scat}[0] : 1.;
    $cval  = (defined $eparms{SWRAD_SCAT}[0])      ? $eparms{SWRAD_SCAT}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{SWRAD_SCAT}} = ($cval);


    #============================================================================
    #  PHYSICS_RADIATION: ICLOUD (defined values)
    #============================================================================
    #
    @opts  = (1,0,3);  #  ICLOUD = 2 no longer UEMS supported
    $dval  = (defined $defnl{PHYSICS}{icloud}[0]) ? $defnl{PHYSICS}{icloud}[0] : $opts[0];
    $cval  = (defined $eparms{ICLOUD} and $eparms{ICLOUD}[0]) ? $eparms{ICLOUD}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{ICLOUD}} = ($cval);


    #============================================================================
    #  NAME: RA_CALL_OFFSET (-1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{ra_call_offset}[0]) ? $defnl{PHYSICS}{ra_call_offset}[0] : 0;
    $cval  = (defined $eparms{RA_CALL_OFFSET} and $eparms{RA_CALL_OFFSET}[0]) ? -1 : 0;

    @{$eparms{RA_CALL_OFFSET}}      = ($cval);


    #============================================================================
    #  PHYSICS_RADIATION: O3INPUT (defined values)
    #============================================================================
    #
    @opts  = (2,0);
    $dval  = (defined $defnl{PHYSICS}{o3input}[0]) ? $defnl{PHYSICS}{o3input}[0] : $opts[0];
    $cval  = (defined $eparms{O3INPUT} and $eparms{O3INPUT}[0]) ? $eparms{O3INPUT}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{O3INPUT}} = ($cval);


    #============================================================================
    #  PHYSICS_RADIATION: USE_MP_RE (1|0)
    #  Only valid with MP_PHYSICS = 3,4,6,8,14,16,17,18,19,20,21, and 22
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{use_mp_re}[0]) ? $defnl{PHYSICS}{use_mp_re}[0] : 1;
    $cval  = (defined $eparms{USE_MP_RE} and $eparms{USE_MP_RE}[0]) ? $eparms{USE_MP_RE}[0] : $dval;
    $cval  = 0 unless grep {/^$eparms{MP_PHYSICS}[0]$/} (3,4,6,8,14,16,17,18,19,20,21,22);

    @{$eparms{USE_MP_RE}}      = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  PHYSICS_RADIATION: CAM_ABS_FREQ_S (21600)
    #
    #  Set Automatically CAM radiation scheme
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{cam_abs_freq_s}[0]) ? $defnl{PHYSICS}{cam_abs_freq_s}[0] : 21600;
    $cval  = (defined $eparms{CAM_ABS_FREQ_S}[0])         ? $eparms{CAM_ABS_FREQ_S}[0]         : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{CAM_ABS_FREQ_S}} = (int $cval);


    #============================================================================
    #  PHYSICS_RADIATION: CAM_ABS_DIM1 (4)
    #
    #  Set Automatically CAM radiation scheme
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{cam_abs_dim1}[0]) ? $defnl{PHYSICS}{cam_abs_dim1}[0] : 4;
    $cval  = (defined $eparms{CAM_ABS_DIM1}[0])         ? $eparms{CAM_ABS_DIM1}[0]         : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{CAM_ABS_DIM1}} = (int $cval);


    #============================================================================
    #  PHYSICS_RADIATION: LEVSIZ (59)
    #
    #  Set Automatically CAM radiation scheme
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{levsiz}[0]) ? $defnl{PHYSICS}{levsiz}[0] : 59;
    $cval  = (defined $eparms{LEVSIZ}[0])         ? $eparms{LEVSIZ}[0]         : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{LEVSIZ}} = (int $cval);


    #============================================================================
    #  PHYSICS_RADIATION: PAERLEV (29)
    #
    #  Set Automatically CAM radiation scheme
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{paerlev}[0]) ? $defnl{PHYSICS}{paerlev}[0] : 29;
    $cval  = (defined $eparms{PAERLEV}[0])         ? $eparms{PAERLEV}[0]         : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{PAERLEV}} = (int $cval); 


    #============================================================================
    #  PHYSICS_RADIATION: AER_OPT (defined values)
    #  AER_OPT 3 is only for use with Thompson AA MP (MP_PHYSICS = 28)
    #============================================================================
    #
    @opts  = ($eparms{MP_PHYSICS}[0] == 28) ? (3,0) : (1,0,2);
    $dval  = (defined $defnl{PHYSICS}{aer_opt}[0]) ? $defnl{PHYSICS}{aer_opt}[0] : $opts[0];
    $cval  = (defined $eparms{AER_OPT}) ? $eparms{AER_OPT}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;
    
    @{$eparms{AER_OPT}} = ($cval);


    #============================================================================
    #  PHYSICS_RADIATION: ALEVSIZ (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{alevsiz}[0]) ? $defnl{PHYSICS}{alevsiz}[0] : 12;
    $cval  = (defined $eparms{ALEVSIZ}[0])         ? $eparms{ALEVSIZ}[0]         : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 1.;

    @{$eparms{ALEVSIZ}} = (int $cval);


    #============================================================================
    #  PHYSICS_RADIATION: NO_SRC_TYPES (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{no_src_types}[0]) ? $defnl{PHYSICS}{no_src_types}[0] : 6;
    $cval  = (defined $eparms{NO_SRC_TYPES}[0])         ? $eparms{NO_SRC_TYPES}[0]         : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 1.;

    @{$eparms{NO_SRC_TYPES}} = (int $cval);


    #============================================================================
    #  PHYSICS_RADIATION: AER_TYPE (defined values)
    #============================================================================
    #
    @opts  = (1,2,3);
    $dval  = (defined $defnl{PHYSICS}{aer_type}[0]) ? $defnl{PHYSICS}{aer_type}[0] : $opts[0];
    $cval  = (defined $eparms{AER_TYPE} and $eparms{AER_TYPE}[0]) ? $eparms{AER_TYPE}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{AER_TYPE}} = ($cval);


    #============================================================================
    #  PHYSICS_RADIATION: AER_AOD550_OPT (defined values)
    #============================================================================
    #
    @opts  = (1);
    $dval  = (defined $defnl{PHYSICS}{aer_aod550_opt}[0]) ? $defnl{PHYSICS}{aer_aod550_opt}[0] : $opts[0];
    $cval  = (defined $eparms{AER_AOD550_OPT} and $eparms{AER_AOD550_OPT}[0]) ? $eparms{AER_AOD550_OPT}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{AER_AOD550_OPT}} = ($cval);


    #============================================================================
    #  PHYSICS_RADIATION: AER_AOD550_VAL (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{aer_aod550_val}[0]) ? $defnl{PHYSICS}{aer_aod550_val}[0] : 0.12;
    $cval  = (defined $eparms{AER_AOD550_VAL}[0])      ? $eparms{AER_AOD550_VAL}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{AER_AOD550_VAL}} = ($cval);


    #============================================================================
    #  PHYSICS_RADIATION: AER_ANGEXP_OPT (defined values)
    #============================================================================
    #
    @opts  = (1,3);
    $dval  = (defined $defnl{PHYSICS}{aer_angexp_opt}[0]) ? $defnl{PHYSICS}{aer_angexp_opt}[0] : $opts[0];
    $cval  = (defined $eparms{AER_ANGEXP_OPT} and $eparms{AER_ANGEXP_OPT}[0]) ? $eparms{AER_ANGEXP_OPT}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{AER_ANGEXP_OPT}} = ($cval);


    #============================================================================
    #  PHYSICS_RADIATION: AER_ANGEXP_VAL (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{aer_angexp_val}[0]) ? $defnl{PHYSICS}{aer_angexp_val}[0] : 1.3;
    $cval  = (defined $eparms{AER_ANGEXP_VAL}[0])      ? $eparms{AER_ANGEXP_VAL}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{AER_ANGEXP_VAL}} = ($cval);


    #============================================================================
    #  PHYSICS_RADIATION: AER_SSA_OPT (defined values)
    #============================================================================
    #
    @opts  = (1,3);
    $dval  = (defined $defnl{PHYSICS}{aer_ssa_opt}[0]) ? $defnl{PHYSICS}{aer_ssa_opt}[0] : $opts[0];
    $cval  = (defined $eparms{AER_SSA_OPT} and $eparms{AER_SSA_OPT}[0]) ? $eparms{AER_SSA_OPT}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{AER_SSA_OPT}} = ($cval);


    #============================================================================
    #  PHYSICS_RADIATION: AER_SSA_VAL (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{aer_ssa_val}[0]) ? $defnl{PHYSICS}{aer_ssa_val}[0] : 0.85;
    $cval  = (defined $eparms{AER_SSA_VAL}[0])      ? $eparms{AER_SSA_VAL}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{AER_SSA_VAL}} = ($cval);


    #============================================================================
    #  PHYSICS_RADIATION: AER_ASY_OPT (defined values)
    #============================================================================
    #
    @opts  = (1,3);
    $dval  = (defined $defnl{PHYSICS}{aer_asy_opt}[0]) ? $defnl{PHYSICS}{aer_asy_opt}[0] : $opts[0];
    $cval  = (defined $eparms{AER_ASY_OPT} and $eparms{AER_ASY_OPT}[0]) ? $eparms{AER_ASY_OPT}[0] : $dval; 
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{AER_ASY_OPT}} = ($cval);


    #============================================================================
    #  PHYSICS_RADIATION: AER_ASY_VAL (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{aer_asy_val}[0]) ? $defnl{PHYSICS}{aer_asy_val}[0] : 0.90;
    $cval  = (defined $eparms{AER_ASY_VAL}[0])      ? $eparms{AER_ASY_VAL}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{AER_ASY_VAL}} = ($cval);


    #============================================================================
    #  PHYSICS_SEALAKES: SF_OCEAN_PHYSICS (defined values)
    #  Option 2 is currently not supported
    #============================================================================
    #
    @opts  = (0,1,2);
    $dval  = (defined $defnl{PHYSICS}{sf_ocean_physics}[0]) ? $defnl{PHYSICS}{sf_ocean_physics}[0] : $opts[0];
    $cval  = (defined $eparms{SF_OCEAN_PHYSICS} and $eparms{SF_OCEAN_PHYSICS}[0]) ? $eparms{SF_OCEAN_PHYSICS}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    if ($cval == 2) {  # Pinkel is not currently supported
        $mesg = "The Price-Weller-Pinkel option (2) is not currently supported by the UEMS due to the fact that ".
                "the user (you) must manually specify ocean_levels, ocean_z, ocean_t, and ocean_s. This option will ".
                "be activated in the UEMS once Pinkel comes up with a better initialization method.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,"It's All About Pinkel:",$mesg);
        return ();
    }
    @{$eparms{SF_OCEAN_PHYSICS}} = $cval ? ($cval) x $Config{maxdoms} : (0);


    #============================================================================
    #  PHYSICS_SEALAKES: OML_HML0 (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{oml_hml0}[0]) ? $defnl{PHYSICS}{oml_hml0}[0] : 50.;
    $cval  = (defined $eparms{OML_HML0}[0])      ? $eparms{OML_HML0}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{OML_HML0}} = ($cval);


    #============================================================================
    #  PHYSICS_SEALAKES: OML_GAMMA (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{oml_gamma}[0]) ? $defnl{PHYSICS}{oml_gamma}[0] : 0.14;
    $cval  = (defined $eparms{OML_GAMMA}[0])      ? $eparms{OML_GAMMA}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{OML_GAMMA}} = ($cval);


    #============================================================================
    #  PHYSICS_SEALAKES: SST_SKIN (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{sst_skin}[0]) ? $defnl{PHYSICS}{sst_skin}[0] : 0;
    $cval  = (defined $eparms{SST_SKIN} and $eparms{SST_SKIN}[0]) ? $eparms{SST_SKIN}[0] : $dval;

    @{$eparms{SST_SKIN}}      = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  PHYSICS_SEALAKES: SST_UPDATE (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{sst_update}[0]) ? $defnl{PHYSICS}{sst_update}[0] : 0;
    $cval  = (defined $eparms{SST_UPDATE} and $eparms{SST_UPDATE}[0]) ? $eparms{SST_UPDATE}[0] : $dval;

    @{$eparms{SST_UPDATE}}      = &SetValues_OnOff($cval,$dval,1); 


    #============================================================================
    #  PHYSICS_SEALAKES: FRACTIONAL_SEAICE (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{fractional_seaice}[0]) ? $defnl{PHYSICS}{fractional_seaice}[0] : 0;
    $cval  = (defined $eparms{FRACTIONAL_SEAICE} and $eparms{FRACTIONAL_SEAICE}[0]) ? $eparms{FRACTIONAL_SEAICE}[0] : $dval;
    $cval  = $cval ? 1 : 0;
    $cval  = 1 if $eparms{SF_SURFACE_PHYSICS}[0] == 8;  #  Required by the source code

    @{$eparms{FRACTIONAL_SEAICE}} = ($cval);


    #============================================================================
    #  PHYSICS_SEALAKES: SEAICE_THRESHOLD (single value)
    #============================================================================
    #
    $cval  = $eparms{FRACTIONAL_SEAICE}[0]   ? 0. : 271.4;
    @{$eparms{SEAICE_THRESHOLD}} = ($cval);


    #============================================================================
    #  PHYSICS_SEALAKES: TICE2TSK_IF2COLD (T|F)
    #============================================================================
    #
    $cval  = $eparms{FRACTIONAL_SEAICE}[0]   ? 'T' : 'F';
    @{$eparms{TICE2TSK_IF2COLD}} = ($cval);


    #============================================================================
    #  PHYSICS_SEALAKES: SEAICE_ALBEDO_OPT (defined values)
    #
    #  Note:  SEAICE_ALBEDO_OPT = 1 only available with NOAH LSM
    #============================================================================
    #
    @opts  = (grep {/^$eparms{SF_SURFACE_PHYSICS}[0]$/} (2,4)) ? (0,1,2) : (0,2);

    $dval  = (defined $defnl{PHYSICS}{seaice_albedo_opt}[0]) ? $defnl{PHYSICS}{seaice_albedo_opt}[0] : $opts[0];
    $cval  = (defined $eparms{SEAICE_ALBEDO_OPT} and $eparms{SEAICE_ALBEDO_OPT}[0]) ? $eparms{SEAICE_ALBEDO_OPT}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    if ($cval == 2 and defined $renv{albsi} and ! $renv{albsi}) {
        $mesg = "The SEAICE_ALBEDO_OPT = 2 option is only available with ALBSI in the netCDF initialization ".
                "file. Changing to SEAICE_ALBEDO_OPT = 0.";
        &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,"Is that measured above or below the water line?:",$mesg);
        $cval  = 1;
    }
    @{$eparms{SEAICE_ALBEDO_OPT}} = ($cval);


    #============================================================================
    #  PHYSICS_SEALAKES: SEAICE_ALBEDO_DEFAULT (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{seaice_albedo_default}[0]) ? $defnl{PHYSICS}{seaice_albedo_default}[0] : 0.65;
    $cval  = (defined $eparms{SEAICE_ALBEDO_DEFAULT}[0])      ? $eparms{SEAICE_ALBEDO_DEFAULT}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{SEAICE_ALBEDO_DEFAULT}} = ($cval);


    #============================================================================
    #  PHYSICS_SEALAKES: SEAICE_SNOWDEPTH_OPT (1|0)
    #  SEAICE_SNOWDEPTH_OPT = 1 only available with SNOWSI in WPS file
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{seaice_snowdepth_opt}[0]) ? $defnl{PHYSICS}{seaice_snowdepth_opt}[0] : 0;
    $cval  = (defined $eparms{SEAICE_SNOWDEPTH_OPT} and $eparms{SEAICE_SNOWDEPTH_OPT}[0]) ? $eparms{SEAICE_SNOWDEPTH_OPT}[0] : $dval;
    $cval  = $cval ? 1 : 0;

    if ($cval and defined $renv{snowsi} and ! $renv{snowsi}) {
        $mesg = "The rather esoteric SEAICE_SNOWDEPTH_OPT = 1 option in only available to those with SNOWSI in the netCDF initialization ".
                "file. Changing to SEAICE_SNOWDEPTH_OPT = 0.";
        &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,"Rather Persnickety, Aren't You:",$mesg);
        $cval  = 0;
    }
    @{$eparms{SEAICE_SNOWDEPTH_OPT}} = ($cval);


    #============================================================================
    #  PHYSICS_SEALAKES: SEAICE_SNOWDEPTH_MAX (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{seaice_snowdepth_max}[0]) ? $defnl{PHYSICS}{seaice_snowdepth_max}[0] : 10.;
    $cval  = (defined $eparms{SEAICE_SNOWDEPTH_MAX}[0])      ? $eparms{SEAICE_SNOWDEPTH_MAX}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{SEAICE_SNOWDEPTH_MAX}} = ($cval);


    #============================================================================
    #  PHYSICS_SEALAKES: SEAICE_SNOWDEPTH_MIN (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{seaice_snowdepth_min}[0]) ? $defnl{PHYSICS}{seaice_snowdepth_min}[0] : 0.001;
    $cval  = (defined $eparms{SEAICE_SNOWDEPTH_MIN}[0])      ? $eparms{SEAICE_SNOWDEPTH_MIN}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{SEAICE_SNOWDEPTH_MIN}} = ($cval);


    #============================================================================
    #  PHYSICS_SEALAKES: SEAICE_THICKNESS_OPT (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{seaice_thickness_opt}[0]) ? $defnl{PHYSICS}{seaice_thickness_opt}[0] : 0;
    $cval  = (defined $eparms{SEAICE_THICKNESS_OPT} and $eparms{SEAICE_THICKNESS_OPT}[0]) ? $eparms{SEAICE_THICKNESS_OPT}[0] : $dval;
    $cval  = $cval ? 1 : 0;

    if ($cval and defined $renv{icedpth} and ! $renv{icedpth}) {
        $mesg = "The SEAICE_THICKNESS_OPT = 1 option in only available with ICEDEPTH in the netCDF initialization ".
                "file. Changing to SEAICE_THICKNESS_OPT = 0.";
        &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,"Is that measured above or below the water line?:",$mesg);
        $cval  = 0;
    }
    @{$eparms{SEAICE_THICKNESS_OPT}} = ($cval);


    #============================================================================
    #  PHYSICS_SEALAKES: SEAICE_THICKNESS_DEFAULT (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{seaice_thickness_default}[0]) ? $defnl{PHYSICS}{seaice_thickness_default}[0] : 3.;
    $cval  = (defined $eparms{SEAICE_THICKNESS_DEFAULT}[0])      ? $eparms{SEAICE_THICKNESS_DEFAULT}[0]      : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{SEAICE_THICKNESS_DEFAULT}} = ($cval);


    #============================================================================
    #  PHYSICS_SEALAKES: SF_LAKE_PHYSICS (1|0) (max domains)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{sf_lake_physics}[0]) ? $defnl{PHYSICS}{sf_lake_physics}[0] : 0;
    $cval  = (defined $eparms{SF_LAKE_PHYSICS} and $eparms{SF_LAKE_PHYSICS}[0]) ? $eparms{SF_LAKE_PHYSICS}[0] : $dval;
    $cval  = $cval ? 1 : 0;

    if ($cval and ! $renv{islakes}) {
        $mesg = "Sure, turning ON the inland lake model (SF_LAKE_PHYSICS = 1) sounds like a lot of fun, but before the ".
                "fun there's work to be done (Seuss has nothing on me!). If you want to use this option you need to ".
                "localize your computational domain with the \"--lakes\" flag:\n\n".
                "X02X%  ems_domain --localize --lakes\n\n".
                "Otherwise this simulation is doomed to failure, and I don't want that stain on me!\n".
                "In the mean time the SF_LAKE_PHYSICS option will be turned OFF.";
        &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,'I "Seas" You Like the Lakes:', $mesg);
        $cval = 0;
    }
    @{$eparms{SF_LAKE_PHYSICS}} = $cval ? ($cval) x $Config{maxdoms} : (0);


    #============================================================================
    #  PHYSICS_SEALAKES: LAKEDEPTH_DEFAULT (single value)
    #============================================================================
    #
    @rvals = (0) x $Config{maxdoms};
    @dvals = ($defnl{PHYSICS}{lakedepth_default} and @{$defnl{PHYSICS}{lakedepth_default}}) ? @{$defnl{PHYSICS}{lakedepth_default}} : @rvals;
    @cvals = ($eparms{LAKEDEPTH_DEFAULT} and @{$eparms{LAKEDEPTH_DEFAULT}})                  ? @{$eparms{LAKEDEPTH_DEFAULT}}         : @dvals;
    $cvals[0] = 50. unless $cvals[0] and &Others::isNumber($cvals[0]) and $cvals[0] > 0.;

    foreach (@cvals) {$_ = $cvals[-1] unless &Others::isNumber($_) and $_ > 0.;}
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{LAKEDEPTH_DEFAULT}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  PHYSICS_SEALAKES: LAKE_MIN_ELEV (single value)
    #============================================================================
    #
    @rvals = (0) x $Config{maxdoms};
    @dvals = ($defnl{PHYSICS}{lake_min_elev} and @{$defnl{PHYSICS}{lake_min_elev}}) ? @{$defnl{PHYSICS}{lake_min_elev}} : @rvals;
    @cvals = ($eparms{LAKE_MIN_ELEV} and @{$eparms{LAKE_MIN_ELEV}})                  ? @{$eparms{LAKE_MIN_ELEV}}         : @dvals;
    $cvals[0] = 5. unless $cvals[0] and &Others::isNumber($cvals[0]) and $cvals[0] > 0.;

    foreach (@cvals) {$_ = $cvals[-1] unless &Others::isNumber($_) and $_ > 0.;}
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{LAKE_MIN_ELEV}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  PHYSICS_SEALAKES: USE_LAKEDEPTH (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{PHYSICS}{use_lakedepth}[0]) ? $defnl{PHYSICS}{use_lakedepth}[0] : 1;
    $cval  = (defined $eparms{USE_LAKEDEPTH} and $eparms{USE_LAKEDEPTH}[0]) ? $eparms{USE_LAKEDEPTH}[0] : $dval;
    $cval  = $cval ? 1 : 0;

    @{$eparms{USE_LAKEDEPTH}} = ($cval);


    #============================================================================
    #  PHYSICS_SHALLOWCUMULUS: SHCU_PHYSICS (defined values)
    #============================================================================
    #
    @opts  = (99,0,1,2,3);
    $dval  = (defined $defnl{PHYSICS}{shcu_physics}[0]) ? $defnl{PHYSICS}{shcu_physics}[0] : $opts[0];
    $cval  = (defined $eparms{SHCU_PHYSICS}[0]) ? $eparms{SHCU_PHYSICS}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{SHCU_PHYSICS}} = ($cval);


    #====================================================================================================================
    #  PHYSICS_SURFACELAYER: SF_SFCLAY_PHYSICS (defined values)
    #
    #  Note: The selection of BL_PBL_PHYSICS scheme determines
    #        the allowed values for SF_SFCLAY_PHYSICS since they
    #        must play nice together.
    #
    #      0 - No surface layer                     Use with  bl_pbl_physics=0
    #      1 - Revised MM5 Monin-Obukhov (prev 11)  Use with  bl_pbl_physics=0,1,5,6,7,8,9,11,12
    #      2 - MYJ Monin-Obukhov similarity theory  Use with  bl_pbl_physics=0,2,5,6,8,9
    #      3 - NCEP Global Forecast System scheme (NMM only)  bl_pbl_physics=3
    #      4 - QNSE Monin-Obukhov similarity theory Use with  bl_pbl_physics=4
    #      5 - MYNN Monin-Obukhov similarity theory Use with  bl_pbl_physics=5,6
    #      7 - Pleim-Xiu surface layer (EPA)        Use with  bl_pbl_physics=7 and sf_surface_physics=7
    #     10 - TEMF surface layer                   Use with  bl_pbl_physics=10
    #     91 - Old option 1 (MM5)                   Use with  bl_pbl_physics=0,1,5,6,7,8,9,11,12 
    #
    #====================================================================================================================
    #
    @opts = $eparms{BL_PBL_PHYSICS}[0] == 0  ? qw(1 2 0 91) :
            $eparms{BL_PBL_PHYSICS}[0] == 1  ? qw(1 91)     :
            $eparms{BL_PBL_PHYSICS}[0] == 2  ? qw(2)        :
            $eparms{BL_PBL_PHYSICS}[0] == 3  ? qw(3)        :
            $eparms{BL_PBL_PHYSICS}[0] == 4  ? qw(4)        :
            $eparms{BL_PBL_PHYSICS}[0] == 5  ? qw(5 1 2 91) :
            $eparms{BL_PBL_PHYSICS}[0] == 6  ? qw(5 1 2 91) :
            $eparms{BL_PBL_PHYSICS}[0] == 7  ? qw(7 1 91)   :
            $eparms{BL_PBL_PHYSICS}[0] == 8  ? qw(1 2 91)   :
            $eparms{BL_PBL_PHYSICS}[0] == 9  ? qw(1 2 91)   :
            $eparms{BL_PBL_PHYSICS}[0] == 10 ? qw(10)       :
            $eparms{BL_PBL_PHYSICS}[0] == 11 ? qw(1 91)     :
            $eparms{BL_PBL_PHYSICS}[0] == 12 ? qw(1 91)     : qw(1);

    $cval  = (defined $eparms{SF_SFCLAY_PHYSICS} and $eparms{SF_SFCLAY_PHYSICS}[0]) ? $eparms{SF_SFCLAY_PHYSICS}[0] : $opts[0];

    unless (grep {/^${cval}$/} @opts)  {

        $mesg = "I'm afraid I just can't allow your hand picked value for SF_SFCLAY_PHYSICS ($cval) to be ".
                "used with BL_PBL_PHYSICS = $eparms{BL_PBL_PHYSICS}[0] since they are not compatible. The PBL ".
                "and surface layer physics should be a team, just like you and me, and since every team has a ".
                "captain (me), I will assign SF_SFCLAY_PHYSICS = $opts[0] as the other teammate.\n\n".

                "Teamwurks - That's all I ever do around here.";

        &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,'You Can\'t Spell "Teamwurks" Without "UEMS"', $mesg);
        $cval = $opts[0];
    }
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    #  SF_SFCLAY_PHYSICS must be the same for all domains
    #
    @{$eparms{SF_SFCLAY_PHYSICS}} = ($cval) x $Config{maxdoms};


    #============================================================================
    #  PHYSICS_SURFACELAYER: ISFFLX (defined values)
    #  Dependent upon BL_PBL_PHYSICS beig ON or OFF
    #============================================================================
    #
    @opts  = $eparms{BL_PBL_PHYSICS}[0] ? (1,0) : (1,0,2);
    $dval  = (defined $defnl{PHYSICS}{isfflx}[0]) ? $defnl{PHYSICS}{isfflx}[0] : $opts[0];
    $cval  = (defined $eparms{ISFFLX}[0]) ? $eparms{ISFFLX}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{ISFFLX}} = ($cval);


    #============================================================================
    #  PHYSICS_SURFACELAYER: IZ0TLND (defined values)
    #============================================================================
    #
    @opts  = (1,0);
    $dval  = (defined $defnl{PHYSICS}{iz0tlnd}[0]) ? $defnl{PHYSICS}{iz0tlnd}[0] : $opts[0];
    $cval  = (defined $eparms{IZ0TLND}[0]) ? $eparms{IZ0TLND}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{IZ0TLND}} = ($cval);


    #============================================================================
    #  PHYSICS_SURFACELAYER: ISFTCFLX (defined values)
    #============================================================================
    #
    @opts  = (0,1,2);
    $dval  = (defined $defnl{PHYSICS}{isftcflx}[0]) ? $defnl{PHYSICS}{isftcflx}[0] : $opts[0];
    $cval  = (defined $eparms{ISFTCFLX}[0]) ? $eparms{ISFTCFLX}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{ISFTCFLX}} = ($cval);


    #============================================================================
    #  PHYSICS_URBANCANOPY: SF_URBAN_PHYSICS (defined values)
    #============================================================================
    #
    @opts  = (0,1,2,3);
    $dval  = (defined $defnl{PHYSICS}{sf_urban_physics}[0]) ? $defnl{PHYSICS}{sf_urban_physics}[0] : $opts[0];
    $cval  = (defined $eparms{SF_URBAN_PHYSICS}[0]) ? $eparms{SF_URBAN_PHYSICS}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    if ($cval and $eparms{SF_SURFACE_PHYSICS}[0] != 2) {  #  SF_URBAN_PHYSICS ONLY available with NOAH LSM
       $mesg = "I know you're into the urban scene and all (SF_URBAN_PHYSICS = $cval), but the UEMS don't play ".
               "with anything but the NOAH Land Surface Model (2). So why don't you go back into the run_physics_landsurface.conf ".
               "file and specify yourself some LSM proper.\n\n".
               "I'll just be hanging here till you do.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'U R Not From This Neighborhood',$mesg);
        return ();
    }
    @{$eparms{SF_URBAN_PHYSICS}} = $cval ? ($cval) x $Config{maxdoms} : (0);


    #============================================================================
    #  RUN_STOCH: SKEBS (1|0) (max Domains) - One value for all, all for one
    #============================================================================
    #
    $dval  = (defined $defnl{STOCH}{skebs}[0]) ? $defnl{STOCH}{skebs}[0] : 0;
    $cval  = (defined $eparms{SKEBS} and $eparms{SKEBS}[0]) ? $eparms{SKEBS}[0] : $dval;

    @{$eparms{SKEBS}}      = &SetValues_OnOff($cval,$dval, $cval ? $Config{maxdoms} : 1);



    #============================================================================
    #  RUN_STOCH: NENS (integer value)
    #============================================================================
    #
    $dval  = int rand (99);
    $cval  = (defined $eparms{NENS} and $eparms{NENS}[0]) ? $eparms{NENS}[0] : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{NENS}} = (int $cval);


    #============================================================================
    #  RUN_STOCH: ISEED_SKEBS (integer value)
    #============================================================================
    #
    $dval  = int rand (999);
    $cval  = (defined $eparms{ISEED_SKEBS} and $eparms{ISEED_SKEBS}[0]) ? $eparms{ISEED_SKEBS}[0] : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{ISEED_SKEBS}} = (int $cval);


    #============================================================================
    #  RUN_STOCH: TOT_BACKSCAT_PSI (any number value) (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{STOCH}{tot_backscat_psi} and @{$defnl{STOCH}{tot_backscat_psi}}) ? @{$defnl{STOCH}{tot_backscat_psi}} : (1.0E-5);
    @cvals = ($eparms{TOT_BACKSCAT_PSI} and @{$eparms{TOT_BACKSCAT_PSI}})              ? @{$eparms{TOT_BACKSCAT_PSI}}       : @dvals;

    @{$eparms{TOT_BACKSCAT_PSI}} = ($cvals[0]); # Changed to single value


    #============================================================================
    #  RUN_STOCH: TOT_BACKSCAT_T (any number value) (Max Domains)
    #============================================================================
    #
    @dvals = ($defnl{STOCH}{tot_backscat_t} and @{$defnl{STOCH}{tot_backscat_t}}) ? @{$defnl{STOCH}{tot_backscat_t}} : (1.0E-6);
    @cvals = ($eparms{TOT_BACKSCAT_T} and @{$eparms{TOT_BACKSCAT_T}})              ? @{$eparms{TOT_BACKSCAT_T}}       : @dvals;
    
    @{$eparms{TOT_BACKSCAT_T}} = ($cvals[0]);  # Changed to single value



    #============================================================================
    #  RUN_STOCH: ZTAU_PSI (any number value) (Max Domains)
    #============================================================================
    #
    $dval  = (defined $defnl{STOCH}{ztau_psi}[0]) ? $defnl{STOCH}{ztau_psi}[0] : 10800.;
    $cval  = (defined $eparms{ZTAU_PSI}[0])      ? $eparms{ZTAU_PSI}[0]        : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{ZTAU_PSI}} = ($cval);


    #============================================================================
    #  RUN_STOCH: ZTAU_T (any number value) (Max Domains)
    #============================================================================
    #
    $dval  = (defined $defnl{STOCH}{ztau_t}[0]) ? $defnl{STOCH}{ztau_t}[0] : 10800.;
    $cval  = (defined $eparms{ZTAU_T}[0])       ? $eparms{ZTAU_T}[0]       : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{ZTAU_T}} = ($cval);



    #============================================================================
    #  RUN_STOCH: REXPONENT_PSI (any number value) (Max Domains)
    #============================================================================
    #
    $dval  = (defined $defnl{STOCH}{rexponent_psi}[0]) ? $defnl{STOCH}{rexponent_psi}[0] : -1.83;
    $cval  = (defined $eparms{REXPONENT_PSI}[0])      ? $eparms{REXPONENT_PSI}[0]        : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{REXPONENT_PSI}} = ($cval);


    #============================================================================
    #  RUN_STOCH: REXPONENT_T (any number value) (Max Domains)
    #============================================================================
    #
    $dval  = (defined $defnl{STOCH}{rexponent_t}[0]) ? $defnl{STOCH}{rexponent_t}[0] : -1.83;
    $cval  = (defined $eparms{REXPONENT_T}[0])       ? $eparms{REXPONENT_T}[0]       : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{REXPONENT_T}} = ($cval);



    #============================================================================
    #  RUN_STOCH: KMINFORC (integer value)
    #
    #  Per module_check a_mundo.F: KMINFORC = 1
    #============================================================================
    #
#   $dval  = (defined $defnl{STOCH}{kminforc}[0])                 ? $defnl{STOCH}{kminforc}[0] : 1;
#   $cval  = (defined $eparms{KMINFORC} and $eparms{KMINFORC}[0]) ? $eparms{KMINFORC}[0]      : $dval;
#   $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;
    $cval  = 1;

    @{$eparms{KMINFORC}} = (int $cval);


    #============================================================================
    #  RUN_STOCH: LMINFORC (integer value)
    #
    #  Per module_check a_mundo.F: LMINFORC = 1
    #============================================================================
    #
#   $dval  = (defined $defnl{STOCH}{lminforc}[0])                 ? $defnl{STOCH}{lminforc}[0] : 1;
#   $cval  = (defined $eparms{LMINFORC} and $eparms{LMINFORC}[0]) ? $eparms{LMINFORC}[0]      : $dval;
#   $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;
    $cval  = 1;

    @{$eparms{LMINFORC}} = (int $cval);


    #============================================================================
    #  RUN_STOCH: KMINFORCT (integer value)
    #
    #  Per module_check a_mundo.F: KMINFORCT = 1
    #============================================================================
    #
#   $dval  = (defined $defnl{STOCH}{kminforct}[0])                  ? $defnl{STOCH}{kminforct}[0] : 1;
#   $cval  = (defined $eparms{KMINFORCT} and $eparms{KMINFORCT}[0]) ? $eparms{KMINFORCT}[0]      : $dval;
#   $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;
    $cval  = 1;

    @{$eparms{KMINFORCT}} = (int $cval);


    #============================================================================
    #  RUN_STOCH: LMINFORCT (integer value)
    #
    #  Per module_check a_mundo.F: LMINFORCT = 1
    #============================================================================
    #
#   $dval  = (defined $defnl{STOCH}{lminforct}[0])                  ? $defnl{STOCH}{lminforct}[0] : 1;
#   $cval  = (defined $eparms{LMINFORCT} and $eparms{LMINFORCT}[0]) ? $eparms{LMINFORCT}[0]      : $dval;
#   $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;
    $cval  = 1;

    @{$eparms{LMINFORCT}} = (int $cval);


    #============================================================================
    #  RUN_STOCH: KMAXFORC (integer value)
    #
    #  Per module_check a_mundo.F: KMAXFORC = 1000000
    #============================================================================
    #
#   $dval  = (defined $defnl{STOCH}{kmaxforc}[0])                 ? $defnl{STOCH}{kmaxforc}[0] : 1000000;
#   $cval  = (defined $eparms{KMAXFORC} and $eparms{KMAXFORC}[0]) ? $eparms{KMAXFORC}[0]       : $dval;
#   $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;
    $cval  = 1000000;

    @{$eparms{KMAXFORC}} = (int $cval);


    #============================================================================
    #  RUN_STOCH: LMAXFORC (integer value)
    #
    #  Per module_check a_mundo.F: LMAXFORC = 1000000
    #============================================================================
    #
#   $dval  = (defined $defnl{STOCH}{lmaxforc}[0])                 ? $defnl{STOCH}{lmaxforc}[0] : 1000000;
#   $cval  = (defined $eparms{LMAXFORC} and $eparms{LMAXFORC}[0]) ? $eparms{LMAXFORC}[0]       : $dval;
#   $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;
    $cval  = 1000000;

    @{$eparms{LMAXFORC}} = (int $cval);


    #============================================================================
    #  RUN_STOCH: KMAXFORCT (integer value)
    #
    #  Per module_check a_mundo.F: KMAXFORCT = 1000000
    #============================================================================
    #
#   $dval  = (defined $defnl{STOCH}{kmaxforct}[0])                  ? $defnl{STOCH}{kmaxforct}[0] : 1000000;
#   $cval  = (defined $eparms{KMAXFORCT} and $eparms{KMAXFORCT}[0]) ? $eparms{KMAXFORCT}[0]       : $dval;
#   $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;
    $cval  = 1000000;
    
    
    @{$eparms{KMAXFORCT}} = (int $cval);


    #============================================================================
    #  RUN_STOCH: LMAXFORCT (integer value)
    #
    #  Per module_check a_mundo.F: LMAXFORCT = 1000000
    #============================================================================
    #
#   $dval  = (defined $defnl{STOCH}{lmaxforct}[0])                  ? $defnl{STOCH}{lmaxforct}[0] : 1000000;
#   $cval  = (defined $eparms{LMAXFORCT} and $eparms{LMAXFORCT}[0]) ? $eparms{LMAXFORCT}[0]       : $dval;
#   $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;
    $cval  = 1000000;

    @{$eparms{LMAXFORCT}} = (int $cval);


    #============================================================================
    #   RUN_STOCH: ZSIGMA2_EPS (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{STOCH}{zsigma2_eps}[0]) ? $defnl{STOCH}{zsigma2_eps}[0] : 0.833;
    $cval  = (defined $eparms{ZSIGMA2_EPS}[0])       ? $eparms{ZSIGMA2_EPS}[0]       : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{ZSIGMA2_EPS}} = ($cval);


    #============================================================================
    #   RUN_STOCH: ZSIGMA2_ETA (single value)
    #============================================================================
    #
    $dval  = (defined $defnl{STOCH}{zsigma2_eta}[0]) ? $defnl{STOCH}{zsigma2_eta}[0] : 0.833;
    $cval  = (defined $eparms{ZSIGMA2_ETA}[0])       ? $eparms{ZSIGMA2_ETA}[0]       : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{ZSIGMA2_ETA}} = ($cval);


    #============================================================================
    #  RUN_STOCH: SKEBS_VERTSTRUC (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{STOCH}{skebs_vertstruc}[0]) ? $defnl{STOCH}{skebs_vertstruc}[0] : 1;
    $cval  = (defined $eparms{SKEBS_VERTSTRUC} and $eparms{SKEBS_VERTSTRUC}[0]) ? $eparms{SKEBS_VERTSTRUC}[0] : $dval;

    @{$eparms{SKEBS_VERTSTRUC}}      = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  RUN_STOCH: PERTURB_BDY (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{STOCH}{perturb_bdy}[0]) ? $defnl{STOCH}{perturb_bdy}[0] : 0;
    $cval  = (defined $eparms{PERTURB_BDY} and $eparms{PERTURB_BDY}[0]) ? $eparms{PERTURB_BDY}[0] : $dval;

    @{$eparms{PERTURB_BDY}}      = &SetValues_OnOff($cval,$dval,1);



    #============================================================================
    #  RUN_STOCH: RAND_PERTURB (1|0) (max Domains) - Only used with WRF-CHEM
    #============================================================================
    #
    @opts  = (0,1);
    @dvals = ($defnl{STOCH}{rand_perturb} and @{$defnl{STOCH}{rand_perturb}}) ? @{$defnl{STOCH}{rand_perturb}} : $opts[0];
    @cvals = ($eparms{RAND_PERTURB} and @{$eparms{RAND_PERTURB}})              ? @{$eparms{RAND_PERTURB}}       : @dvals;

    foreach (@cvals) {$_ = $opts[0] unless grep {/^${_}$/} @opts;}

    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{RAND_PERTURB}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_STOCH: GRIDPT_STDDEV_RAND_PERT (value) (max Domains) - Only used with WRF-CHEM
    #============================================================================
    #
    @dvals = ($defnl{STOCH}{gridpt_stddev_rand_pert} and @{$defnl{STOCH}{gridpt_stddev_rand_pert}}) ? @{$defnl{STOCH}{gridpt_stddev_rand_pert}} : (0.03);
    @cvals = ($eparms{GRIDPT_STDDEV_RAND_PERT} and @{$eparms{GRIDPT_STDDEV_RAND_PERT}})              ? @{$eparms{GRIDPT_STDDEV_RAND_PERT}}       : @dvals;

    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{GRIDPT_STDDEV_RAND_PERT}} = @rvals[0..$Config{maxindex}];



    #============================================================================
    #  RUN_STOCH: STDDEV_CUTOFF_RAND_PERT (value) (max Domains) - Only used with WRF-CHEM
    #============================================================================
    #
    @dvals = ($defnl{STOCH}{stddev_cutoff_rand_pert} and @{$defnl{STOCH}{stddev_cutoff_rand_pert}}) ? @{$defnl{STOCH}{stddev_cutoff_rand_pert}} : (3.);
    @cvals = ($eparms{STDDEV_CUTOFF_RAND_PERT} and @{$eparms{STDDEV_CUTOFF_RAND_PERT}})              ? @{$eparms{STDDEV_CUTOFF_RAND_PERT}}       : @dvals;

    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{STDDEV_CUTOFF_RAND_PERT}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_STOCH: LENGTHSCALE_RAND_PERT (value) (max Domains) - Only used with WRF-CHEM
    #============================================================================
    #
    @dvals = ($defnl{STOCH}{lengthscale_rand_pert} and @{$defnl{STOCH}{lengthscale_rand_pert}}) ? @{$defnl{STOCH}{lengthscale_rand_pert}} : (500000.);
    @cvals = ($eparms{LENGTHSCALE_RAND_PERT} and @{$eparms{LENGTHSCALE_RAND_PERT}})              ? @{$eparms{LENGTHSCALE_RAND_PERT}}        : @dvals;

    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{LENGTHSCALE_RAND_PERT}} = @rvals[0..$Config{maxindex}];


    #============================================================================
    #  RUN_STOCH: TIMESCALE_RAND_PERT (value) (max Domains) - Only used with WRF-CHEM
    #============================================================================
    #
    @dvals = ($defnl{STOCH}{timescale_rand_pert} and @{$defnl{STOCH}{timescale_rand_pert}}) ? @{$defnl{STOCH}{timescale_rand_pert}} : (21600.);
    @cvals = ($eparms{TIMESCALE_RAND_PERT} and @{$eparms{TIMESCALE_RAND_PERT}})              ? @{$eparms{TIMESCALE_RAND_PERT}}       : @dvals;

    @rvals = ($cvals[-1]) x $Config{maxdoms};
    splice @rvals, 0, @cvals, @cvals;

    @{$eparms{TIMESCALE_RAND_PERT}} = @rvals[0..$Config{maxindex}];



    #============================================================================
    #  RUN_STOCH: ISEED_RAND_PERT (random integer value) - Only used with WRF-CHEM
    #============================================================================
    #
    $dval  = (defined $defnl{STOCH}{iseed_rand_pert}[0]) ? $defnl{STOCH}{iseed_rand_pert}[0] : int rand (999);
    $cval  = (defined $eparms{ISEED_RAND_PERT} and $eparms{ISEED_RAND_PERT}[0]) ? $eparms{ISEED_RAND_PERT}[0] : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{ISEED_RAND_PERT}} = (int $cval);


    #============================================================================
    #  RUN_STOCH: RAND_PERT_VERTSTRUC (1|0)  - Only used with WRF-CHEM
    #============================================================================
    #
    $dval  = (defined $defnl{STOCH}{rand_pert_vertstruc}[0]) ? $defnl{STOCH}{rand_pert_vertstruc}[0] : 0;
    $cval  = (defined $eparms{RAND_PERT_VERTSTRUC} and $eparms{RAND_PERT_VERTSTRUC}[0]) ? $eparms{RAND_PERT_VERTSTRUC}[0] : $dval;

    @{$eparms{RAND_PERT_VERTSTRUC}}      = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  UNAFFILIATED:  RH2QV_WRT_LIQUID (T|F)
    #============================================================================
    #    
    $dval  = (defined $defnl{DOMAINS}{rh2qv_wrt_liquid}[0]) ? $defnl{DOMAINS}{rh2qv_wrt_liquid}[0] : 'T';
    $cval  = (defined $eparms{RH2QV_WRT_LIQUID} and $eparms{RH2QV_WRT_LIQUID}[0]) ? $eparms{RH2QV_WRT_LIQUID}[0] : $dval;

    @{$eparms{RH2QV_WRT_LIQUID}}    = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  UNAFFILIATED: RH2QV_METHOD (1|2)
    #============================================================================
    #
    @opts = (2,1);
    $dval  = (defined $defnl{DOMAINS}{rh2qv_method}[0]) ? $defnl{DOMAINS}{rh2qv_method}[0] : $opts[0];
    $cval  = (defined $eparms{RH2QV_METHOD} and $eparms{RH2QV_METHOD}[0]) ? $eparms{RH2QV_METHOD}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{RH2QV_METHOD}} = ($cval);


    #============================================================================
    #  UNAFFILIATED: AGGREGATE_LU  (T|F)
    #============================================================================
    #    
    $dval  = (defined $defnl{DOMAINS}{aggregate_lu}[0]) ? $defnl{DOMAINS}{aggregate_lu}[0] : 'F';
    $cval  = (defined $eparms{AGGREGATE_LU} and $eparms{AGGREGATE_LU}[0]) ? $eparms{AGGREGATE_LU}[0] : $dval;

    @{$eparms{AGGREGATE_LU}}    = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  UNAFFILIATED: USE_TAVG_FOR_TSK  (T|F)
    #============================================================================
    #    
    $dval  = (defined $defnl{DOMAINS}{use_tavg_for_tsk}[0]) ? $defnl{DOMAINS}{use_tavg_for_tsk}[0] : 'F';
    $cval  = (defined $eparms{USE_TAVG_FOR_TSK} and $eparms{USE_TAVG_FOR_TSK}[0]) ? $eparms{USE_TAVG_FOR_TSK}[0] : $dval;

    @{$eparms{USE_TAVG_FOR_TSK}}    = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  UNAFFILIATED: INTERP_THETA  (T|F)
    #============================================================================
    #    
    $dval  = (defined $defnl{DOMAINS}{interp_theta}[0]) ? $defnl{DOMAINS}{interp_theta}[0] : 'F';
    $cval  = (defined $eparms{INTERP_THETA} and $eparms{INTERP_THETA}[0]) ? $eparms{INTERP_THETA}[0] : $dval;

    @{$eparms{INTERP_THETA}}    = &SetValues_TrueFalse($cval,$dval,1);


    #============================================================================
    #  UNAFFILIATED: INTERP_METHOD_TYPE (defined values)
    #============================================================================
    # 
    @opts  = (2,1,3,4,12);
    $dval  = (defined $defnl{DOMAINS}{interp_method_type}[0]) ? $defnl{DOMAINS}{interp_method_type}[0] : $opts[0];
    $cval  = (defined $eparms{INTERP_METHOD_TYPE} and $eparms{INTERP_METHOD_TYPE}[0]) ? $eparms{INTERP_METHOD_TYPE}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{INTERP_METHOD_TYPE}} = ($cval);


    #============================================================================
    #  UNAFFILIATED: TRAJ_OPT (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{DOMAINS}{traj_opt}[0]) ? $defnl{DOMAINS}{traj_opt}[0] : 0;
    $cval  = (defined $eparms{TRAJ_OPT} and $eparms{TRAJ_OPT}[0]) ? $eparms{TRAJ_OPT}[0] : $dval;

    @{$eparms{TRAJ_OPT}}      = &SetValues_OnOff($cval,$dval,1);


    #============================================================================
    #  UNAFFILIATED: NUM_TRAJ (1|0)
    #============================================================================
    #
    $dval  = (defined $defnl{DOMAINS}{num_traj}[0]) ? $defnl{DOMAINS}{num_traj}[0] : 0;
    $cval  = (defined $eparms{NUM_TRAJ} and $eparms{NUM_TRAJ}[0]) ? $eparms{NUM_TRAJ}[0] : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;
    $cval  = 0 unless $eparms{TRAJ_OPT}[0];

    @{$eparms{NUM_TRAJ}}      = &SetValues_OnOff($cval,$dval,1);
    @{$eparms{TRAJ_OPT}}      = (0) unless $eparms{NUM_TRAJ}[0];
    


    #============================================================================
    #  UNAFFILIATED: VERT_REFINE_METHOD (defined values)
    #============================================================================
    #
    @opts  = (0,1,2);
    $dval  = (defined $defnl{DOMAINS}{vert_refine_method}[0]) ? $defnl{DOMAINS}{vert_refine_method}[0] : $opts[0];
    $cval  = (defined $eparms{VERT_REFINE_METHOD} and $eparms{VERT_REFINE_METHOD}[0]) ? $eparms{VERT_REFINE_METHOD}[0] : $dval;
    $cval  = $opts[0] unless grep {/^${cval}$/} @opts;

    @{$eparms{VERT_REFINE_METHOD}} = ($cval);


    #============================================================================
    #  QUILTING: NIO_TASKS_PER_GROUP (integer value)
    #============================================================================
    #
    $dval  = (defined $defnl{NAMELIST_QUILT}{nio_tasks_per_group}[0]) ? $defnl{NAMELIST_QUILT}{nio_tasks_per_group}[0] : 0;
    $cval  = (defined $eparms{NIO_TASKS_PER_GROUP} and $eparms{NIO_TASKS_PER_GROUP}[0]) ? $eparms{NIO_TASKS_PER_GROUP}[0] : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{NIO_TASKS_PER_GROUP}} = (int $cval);


    #============================================================================
    #  QUILTING: NIO_GROUPS (integer value)
    #============================================================================
    #
    $dval  = (defined $defnl{NAMELIST_QUILT}{nio_groups}[0]) ? $defnl{NAMELIST_QUILT}{nio_groups}[0] : 1;
    $cval  = (defined $eparms{NIO_GROUPS} and $eparms{NIO_GROUPS}[0]) ? $eparms{NIO_GROUPS}[0] : $dval;
    $cval  = $dval unless &Others::isNumber($cval) and $cval > 0.;

    @{$eparms{NIO_GROUPS}} = (int $cval);


return %eparms;
}  #  LocalConfiguration  - That was long!


sub SetValues_TrueFalse {
#=================================================================================
#  Routine set the incoming valiable ($var) to a single true (T) or false (F) 
#  value. Support for 1|0s is provided for legacy reasons. It return an array
#  populated with $nvars values.
#=================================================================================
#
    my ($var, $def, $nvars) = @_;  $nvars = 1 unless $nvars;

    for ($var) {
        $_ = 'F' if /^0/ or /^F/i;
        $_ = 'T' if /^1/ or /^T/i;
        $_ = $def unless $_ eq 'T' or $_ eq 'F';
    }

return ($var) x $nvars;
}


sub SetValues_OnOff {
#=================================================================================
#  Routine set the incoming valiable ($var) to a single ON (1) or OFF (0) 
#  value. Support for T|Fs is provided for legacy reasons. It return an array
#  populated with $nvars values.
#=================================================================================
#
    my ($var, $def, $nvars) = @_;  $nvars = 1 unless $nvars;

    for ($var) {
        $_ = 0 if /^0/ or /^F/i;
        $_ = 1 if /^1/ or /^T/i;
        $_ = $def unless $_ == 1 or $_ == 0;
    }

return ($var) x $nvars;
}


sub ReadSuiteConfigurationFile {
#=================================================================================
#  Read and parse the contents of the physics suite configuration file
#=================================================================================
#
    my %parms = ();
    my $cdir  = shift; return %parms unless -d $cdir;

    foreach my $conf (&Others::FileMatch($cdir,'_suite\.conf$',0,1)) {

        open (my $rfh, '<', $conf); my @lines = <$rfh>; close $rfh; foreach (@lines) {chomp; tr/\000-\037/ /; s/^\s+//g;}

        foreach (@lines) {

            next if /^#|^$|^\s+/;
            s/\t//g;s/\n//g;
            next unless /^SUITE_/i;

            my ($var, $value) = split /\s*=\s*/, $_, 2;

            next unless length $value;
            next unless $value =~ /:/;

            $var = uc $var;
            $var =~ s/^SUITE_//g; 

            my ($parm, $values) = split /:/, $value;
            next unless $parm and defined $values;

            @{$parms{$var}{$parm}} = split /,/, $values;

        }
    }


return %parms;
}  


sub ReadAlternateNamelist {
#=================================================================================
#  Read the alternate namelist file and replace values in eparms
#=================================================================================
#
    my %defnl = %{$Config{nldefault}};  #  Config is global

    my $href  = shift; my %eparms = %{$href}; return () unless %eparms;


    #============================================================================
    #  RUN_NAMELIST: altnl (single string)
    #============================================================================
    #
    my $cval  = $eparms{ALT_NAMELIST}[0];
       $cval = "$Rconf{rtenv}{static}/$cval" if -s "$Rconf{rtenv}{static}/$cval";  #  Rconf is global


    unless (-s $cval) {
        my $mesg = "Your request to use an alternate namelist has been rejected due to its lack of ".
                   "availability, or otherwise stated, I can't find the file:\n\n".
                   "X02X$cval\n\n".
                   "You must either (correctly) specify the full path to the file or just the filename ".
                   "if it resides in the static/ directory, which it doesn\'t because I checked.\n\n".
                   "You need to check run_namelist.conf to make sure you have not mangled something.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,88,0,0,'I\'m looking at you!',$mesg);
        return ();
    }


    #---------------------------------------------------------------------------------------------
    #  Read the alternate namelist and replace Eparms values. Some parameters will be ignored
    #  because they are specified internally within the UEMS.
    #---------------------------------------------------------------------------------------------
    #
    &Ecomm::PrintMessage(1,11+$Rconf{arf},144,2,2,sprintf("Using alternate namelist file: %s",&Others::popit($cval)));

    my @ignore_params = qw(num_land_cat s_we e_we s_sn e_sn s_vert e_vert eta_levels num_metgrid_levels
                           num_metgrid_soil_levels);
    #                      num_metgrid_soil_levels nio_tasks_per_group nio_groups);

    my %altnl = &Others::Namelist2Hash($cval);

    #---------------------------------------------------------------------------------------------
    #  Some cleaning for use with the UEMS
    #---------------------------------------------------------------------------------------------
    #
    @{$eparms{LEVELS}} = ($altnl{DOMAINS}{e_vert}[0])   if defined $altnl{DOMAINS}{e_vert} and $altnl{DOMAINS}{e_vert}[0];
    @{$eparms{LEVELS}} = @{$altnl{DOMAINS}{eta_levels}} if $altnl{DOMAINS}{eta_levels} and @{$altnl{DOMAINS}{eta_levels}} > 21;

    foreach my $sect (keys %altnl) { $sect = uc $sect;
        foreach my $param (keys %{$altnl{$sect}}) { $param = lc $param;
            next if grep {/$param/} @ignore_params;
            unless (defined $defnl{$sect}{$param}) {
                my $lcs = lc $sect;
                &Ecomm::PrintMessage(0,14+$Rconf{arf},254,0,1,"Discarded alternate namelist parameter - &$lcs:$param");
                next;
            }
            @{$eparms{uc $param}} = @{$altnl{$sect}{$param}};
        }
    }
    @{$eparms{ALT_NAMELIST}} = ($cval);

    #&Ecomm::PrintHash(\%eparms);

return %eparms;
}



sub MainNamelistDebugARW {
# ==============================================================================================
# USER PARAMETER DEBUG ROUTINE
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  When the --debug 3+ flag is passed, prints out the results from the configuration of 
#  user-defined parameters in the conf/ems_run/ directory.
#
# ==============================================================================================
# ==============================================================================================
#   
    return unless $ENV{RUN_DBG} > 2;  #  Only for --debug 3+

    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,13+$Rconf{arf},144,1,1,'Leaving &MainARW - Final Configuration File Values:');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf( '%-24s  (%s)   = %s',$_,$Config{parmkeys}{lc $_}{maxdoms},join ', ' => @{$Config{uconf}{$_}} )) foreach sort keys %{$Config{uconf}};
    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,2,'=' x 72);
        

return;
}


