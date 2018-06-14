#!/usr/bin/perl
#===============================================================================
#
#         FILE:  ARWtcntrl.pm
#
#  DESCRIPTION:  ARWtcntrl contains the subroutines used for configuration of
#                the &time_control section of the WRF ARW core namelist. 
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package ARWtcntrl;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Rconf %Config %ARWconf %TimeControl);

use Others;


sub Configure {
# ==============================================================================================
# &TIME_CONTROL NAMELIST CONFIGURATION DIVER
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

    return () if &TimeControl_Timing();
    return () if &TimeControl_PrimaryIO();
    return () if &TimeControl_Ancillary();
    return () if &TimeControl_AuxHist1();
    return () if &TimeControl_AuxHist2();
#   return () if &TimeControl_Restart();
    return () if &TimeControl_Diagnostics();
    return () if &TimeControl_Final();
    return () if &TimeControl_Debug();

    %{$ARWconf{namelist}{time_control}} = %TimeControl;
    @{$ARWconf{tables}{io_form}}        = &Others::rmdups(@{$ARWconf{tables}{io_form}});


return %ARWconf;
}


sub TimeControl_Timing {
# ==============================================================================================
# WRF SIMULATION TIMING &TIME_CONTROL NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  This subroutine populates the namelist hash with the start & end dates and times of
#  the simulation, most of which was determined in the &ErunConfigureDomains subroutine.
#  There is one caveat in that if this is a global or nudging simulation then the end_*
#  values need to be modified outside of this routine when running wrf real. For example
#  in a global simulation the start & end date/times must be the same when running real 
#  otherwise the program will look for BC update files to process when there are none.
#
# ==============================================================================================
# ==============================================================================================
#
    my $maxdoms = $Config{maxdoms};
    my %dinfo   = %{$Rconf{dinfo}};  #  just making things easier


    #---------------------------------------------------------------------
    #  Get the simulation start date for the primary domain, which will
    #  be used to populate the namelist arrays from 0 .. maxdoms-1. The
    #  same value will be used for the end times because the correct 
    #  values will be substituted for those domains in the simulation.
    #---------------------------------------------------------------------
    #
    my ($yr, $mo, $dy, $hr, $mn, $ss);

    ($yr, $mo, $dy, $hr, $mn, $ss) = &Others::DateString2DateList($dinfo{domains}{1}{sdate});

    @{$TimeControl{start_year}}   = ($yr) x $maxdoms;
    @{$TimeControl{start_month}}  = ($mo) x $maxdoms;
    @{$TimeControl{start_day}}    = ($dy) x $maxdoms;
    @{$TimeControl{start_hour}}   = ($hr) x $maxdoms;
    @{$TimeControl{start_minute}} = ($mn) x $maxdoms;
    @{$TimeControl{start_second}} = ($ss) x $maxdoms;

    @{$TimeControl{end_year}}     = ($yr) x $maxdoms;
    @{$TimeControl{end_month}}    = ($mo) x $maxdoms;
    @{$TimeControl{end_day}}      = ($dy) x $maxdoms;
    @{$TimeControl{end_hour}}     = ($hr) x $maxdoms;
    @{$TimeControl{end_minute}}   = ($mn) x $maxdoms;
    @{$TimeControl{end_second}}   = ($ss) x $maxdoms;


    #---------------------------------------------------------------------
    #  Now substitute the correct values for the simulation domains
    #---------------------------------------------------------------------
    #
    foreach my $d (keys %{$dinfo{domains}}) {

        ($yr, $mo, $dy, $hr, $mn, $ss) = &Others::DateString2DateList($dinfo{domains}{$d}{sdate});

        $TimeControl{start_year}[$d-1]   = $yr;
        $TimeControl{start_month}[$d-1]  = $mo;
        $TimeControl{start_day}[$d-1]    = $dy;
        $TimeControl{start_hour}[$d-1]   = $hr;
        $TimeControl{start_minute}[$d-1] = $mn;
        $TimeControl{start_second}[$d-1] = $ss;

        ($yr, $mo, $dy, $hr, $mn, $ss) = &Others::DateString2DateList($dinfo{domains}{$d}{edate});

        $TimeControl{end_year}[$d-1]     = $yr;
        $TimeControl{end_month}[$d-1]    = $mo;
        $TimeControl{end_day}[$d-1]      = $dy;
        $TimeControl{end_hour}[$d-1]     = $hr;
        $TimeControl{end_minute}[$d-1]   = $mn;
        $TimeControl{end_second}[$d-1]   = $ss;

    }


return;
}  #  TimeControl_Timing


sub TimeControl_PrimaryIO {
# ==============================================================================================
# WRF PRIMARY IO &TIME_CONTROL NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  This subroutine manages the configuration of the primary history files, including the
#  file output frequency, naming convention, and format. Values for many of these fields
#  come from the local configuration files.
#
# ==============================================================================================
# ==============================================================================================
#
    my $mesg  = qw{};

    #----------------------------------------------------------------------------------------
    #   Option:  HISTORY_INTERVAL - File frequency for the primary WRF output files
    #
    #   Values:  The primary question is how to manage both user and missing value rules:
    #   
    #    Rules:  
    #            *  All values must be an integer multiple of the simulation length
    #            *  Nested domains with value of "0" (OFF) get assigned simulation length
    #            *  Nested domains with value of "-1" (Not assigned) get parent domain
    #               value adjusted downward to be integer multiple of run length
    #
    #   Default: HISTORY_INTERVAL D(1) = f(dx,length)
    #----------------------------------------------------------------------------------------
    #
    my $l     = int ($Rconf{dinfo}{domains}{1}{length}/60);  #  Length of primary simulation in minutes
    my @uvals = @{$Config{uconf}{HISTORY_INTERVAL}};



    #  Set user values to 0 if greater than simulation length
    #
    foreach (@uvals) {$_ = 0 if $_ > $l;}  
    
    #  Determine what to do for the parent domain
    #
    unless ($uvals[0]) {  # Primary domain value is missing

        #  Missing value for primary domain? Assign value according to grid size (arbitrary).
        #  Also make sure its a integer multiple of simulation length
        #
        $uvals[0] = 1;
        foreach (qw(2 3 5 6 10 12 15 20 30 60)) {$uvals[0]=$_ unless ($l%$_ or $l/$_ < 3);}

        my $dx = int (0.001*$Rconf{rtenv}{geodoms}{1}{dx});

        $uvals[0] = 30  if $dx > 3.0  and $l/30  > 2;
        $uvals[0] = 60  if $dx > 6.0  and $l/60  > 2;
        $uvals[0] = 180 if $dx > 15.0 and $l/180 > 2;
        $uvals[0] = 360 if $dx > 36.0 and $l/360 > 2;

    }
    $uvals[0] = $l if $uvals[0] > $l;  #  Set to simulation length if greater than simulation
    $uvals[0]-- while $l%$uvals[0];    #  Make sure integer multiple of simulation length

    my $dx = int (0.001*$Rconf{rtenv}{geodoms}{1}{dx});


    #  Loop through all the nested domains in the simulation and assign values to those missing.
    #  If value is missing (-1), then assign parent domain value and then correct downward
    #  so that value is an integer multiple if child simulation length and greater than parent:child
    #  grid ratio output times. It's not perfect but it seemed reasonable to me at the time.
    #
    #  Comment: Added 60 min max freq for nested domains when not assigned - I feel better now
    #
    #  if OFF (0) set value to simulation length.
    #  
    my @children = grep {!/^1$/} sort {$a <=> $b} keys %{$Rconf{dinfo}{domains}};

    foreach my $d (@children) { 

        my $di = $d-1;
        my $l  = int ($Rconf{dinfo}{domains}{$d}{length}/60);
        my $p  = $Rconf{dinfo}{domains}{$d}{parent}; my $pi = $p-1;
        my $r  = $Rconf{dinfo}{domains}{$d}{pratio}; my $rt = $r+1;

        $uvals[$di] = $l unless $uvals[$di]; # Simulation length for OFF

        if ($uvals[$di] < 0) {         #  Missing value (-1)
            $uvals[$di] = ($uvals[$pi] > $uvals[0]) ? $uvals[0] : $uvals[$pi]; #  Take parent value unless greater than D1
            $uvals[$di]-- while ($uvals[$di] > 0) and ($l%$uvals[$di] or 60%$uvals[$di] or ($l/$uvals[$di]) < $rt);
        }
        
        $uvals[$di]-- while $l%$uvals[$di] and $uvals[$di] > 0;  #  For user specified values
        $uvals[$di] = $l if $uvals[$di] <=0;
    }
 
    #  Assign d1 value to any domains not included in the simulation but have a value less than 0.
    #
    map {$_ = $uvals[0] if $_ < 0} @uvals;

    @{$TimeControl{history_interval}} = @uvals[0..$Config{maxindex}];



    #----------------------------------------------------------------------------------------
    #   Option:  HISTORY_NAMEKEY - Primary WRF output filename key
    #
    #   Values:  The HISTORY_NAMEKEY parameter is a string that will be used to complete
    #            the naming convention for the primary WRF fields.  All files will use a
    #            convention of "<namekey>_d<domain>_<date>" where "<namekey>" is replaced
    #            by the default or a user-specified string defined by HISTORY_NAMEKEY.
    #
    #   Default: HISTORY_NAMEKEY = wrfout
    #----------------------------------------------------------------------------------------
    #
    my $default = 'wrfout';
    my $namekey = (defined $Config{uconf}{HISTORY_NAMEKEY}[0] and $Config{uconf}{HISTORY_NAMEKEY}[0]) ? $Config{uconf}{HISTORY_NAMEKEY}[0] : $default;
       $namekey = $default unless $namekey =~ /\D/;


    unless ($namekey eq $default) {
        $mesg = "Did you know that changing the WRF primary history filenames may cause the ".
                "UEMS post processor to fail?  And if the UEMS post processor does not tolerate ".
                "failure, then neither should you! So kindly consider changing the value of ".
                "HISTORY_NAMEKEY from \"$Config{uconf}{HISTORY_NAMEKEY}[0]\" to its original value of ".
                "\"$default\". You can thank me later.";
         &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,'Almost Illegal Substitution!',$mesg);
    }


    #  Now form the value for history_outname in the namelist file.
    #  Assume that the default history_outname assigned in the namelist.arw
    #  file has a naming convention of "<namekey>_d<domain>_<date>" so we
    #  can extract the "<namekey>" with a split.
    # 
    my $nldef = $Config{nldefault}{TIME_CONTROL}{history_outname}[0];
       $nldef =~ s/\'|\"//g;  # Strip the leading and trailing quotes
       $nldef = 'wrfout_d<domain>_<date>' unless $nldef;

    my ($nkey, $str) = split /_/ => $nldef;

    $nldef =~ s/$nkey/$namekey/;
    $TimeControl{history_outname}[0] = "\'$nldef\'";

    my ($of,$ss) = split /</, $nldef, 2;
    push @{$ARWconf{outfiles}} => $of;



    #----------------------------------------------------------------------------------------
    #   Option:  OUTPUT_READY_FLAG - Write-out an empty file to indicate output is ready 
    #                                for post processing
    #
    #   Values:
    #     T - Write out "output ready" file
    #     F - Don't create  "output ready" file
    #
    #   Default: OUTPUT_READY_FLAG = T  If the --autopost flag is passed
    #            OUTPUT_READY_FLAG = F  No --autopost flag
    #----------------------------------------------------------------------------------------
    #
    $TimeControl{output_ready_flag}[0] = $Rconf{flags}{autopost} ? 'T' : 'F';


    #----------------------------------------------------------------------------------------
    #   Option:  IO_FORM - Format of the primary WRF output files
    #
    #   Values:
    #
    #     1 - Machine dependent unformatted (binary) output (no software support)
    #     2 - WRF netCDF format (Not AWIPS compatible) (Default)
    #     4 - PHDF5 format (no software support)
    #     5 - GRIB 1 format  (ARW only) 
    #    10 - GRIB 2 format  (ARW only) 
    #
    #   Default: IO_FORM = 2
    #----------------------------------------------------------------------------------------
    #
    my @opts = qw(2 5 10);
    $TimeControl{io_form_history}[0] = (defined $Config{uconf}{IO_FORM_HISTORY} and $Config{uconf}{IO_FORM_HISTORY}[0]) ? $Config{uconf}{IO_FORM_HISTORY}[0] : $opts[0];
    $TimeControl{io_form_history}[0] = $opts[0] unless grep {/^$TimeControl{io_form_history}[0]$/} @opts;

    push @{$ARWconf{tables}{io_form}} => "grib/grib2map.tbl" if $TimeControl{io_form_history}[0] == 10;
    push @{$ARWconf{tables}{io_form}} => "grib/gribmap.tbl"  if $TimeControl{io_form_history}[0] == 5;

 
    #----------------------------------------------------------------------------------------
    #   Options: io_form_restart, io_form_boundary, io_form_input, and reset_simulation_start
    #
    #   Values:  Just set all to netCDF (2)
    #----------------------------------------------------------------------------------------
    #
    @{$TimeControl{io_form_restart}}        = (2);
    @{$TimeControl{io_form_boundary}}       = (2);
    @{$TimeControl{io_form_input}}          = (2);
    @{$TimeControl{io_form_auxinput2}}      = (2);
    @{$TimeControl{reset_simulation_start}} = ('F');


    #----------------------------------------------------------------------------------------
    #   Option:  USE_NETCDF_CLASSIC
    #
    #   Values:  T - Use netCDF classic version 3 (Default)
    #            F - Use netCDF-4 with HDF5 
    #
    #   Notes:   Controls whether output is in netCDF 3, i.e., "classic", (T) or netCDF-4 (HDF5; F).
    #
    #   Default: USE_NETCDF_CLASSIC = 'T'
    #----------------------------------------------------------------------------------------
    #
    $TimeControl{use_netcdf_classic}[0] = (defined $Config{uconf}{USE_NETCDF_CLASSIC} and $Config{uconf}{USE_NETCDF_CLASSIC}[0]) ? $Config{uconf}{USE_NETCDF_CLASSIC}[0] : 'T';
    $TimeControl{use_netcdf_classic}[0] = ($TimeControl{use_netcdf_classic}[0] =~ /^F/i) ? 'F' : 'T';


    #----------------------------------------------------------------------------------------
    #   Option:  FRAMES_PER_OUTFILE - Number of data dumps per file
    #
    #   Notes:   Prefer value of 1 but will also allow ALL frames (10000)
    #
    #   Default: FRAMES_PER_OUTFILE = 1 
    #----------------------------------------------------------------------------------------
    #
    @{$TimeControl{frames_per_outfile}} = map { $_ = $Rconf{flags}{autopost} ? 1 : $_ } @{$Config{uconf}{FRAMES_PER_OUTFILE}};

      

return;
}


sub TimeControl_AuxHist1 {
# ==============================================================================================
# WRF AUXHIST1 &TIME_CONTROL NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This routine manages the configuration of the auxiliary1 output files, including
#   the output frequency, naming convention, and format. 
#
# ==============================================================================================
# ==============================================================================================
#
use List::Util qw(sum);


    my $mesg    = qw{};

    my @rundoms = sort {$a <=> $b} keys %{$Rconf{dinfo}{domains}};


    #----------------------------------------------------------------------------------------
    #   Option :  AUXHIST1_INTERVAL - File frequency for the auxiliary EMS output files
    #
    #   Rules  : Not all listed here 
    #            a. If a child domain has a non-zero value (ON) then so must it's parent
    #            b. If 'Auto' anywhere in value list then all values set to history_interval
    #            c. Domain value must be integer multiple of domain simulation length
    #
    #   Default: auxhist1_interval = 0 or to run length if greater than forecast length
    #            Note that at the time of this writing, there  is a bug in WRF in that
    #            turning on AuxHist files for one domain requires the files be turned
    #            on for all parent domains as well; Otherwise, no files are output.
    #----------------------------------------------------------------------------------------
    #
    my $l     = int ($Rconf{dinfo}{domains}{1}{length}/60);  #  Length of primary simulation in minutes

    my @uvals = @{$Config{uconf}{AUXHIST1_INTERVAL}};
       @uvals = @{$TimeControl{history_interval}} if grep {/auto/i} @uvals;

    foreach (@uvals) {$_ = 0 if $_ > $l;}

    #  Reverse loop through all the domains in the simulation and assign values 
    #  to parent domains if missing.
    #  
    foreach my $d (sort {$b <=> $a} @rundoms) {

        my $di = $d-1;
        my $p  = $Rconf{dinfo}{domains}{$d}{parent}; my $pi = $p-1;
        my $l  = int ($Rconf{dinfo}{domains}{$d}{length}/60);

        $uvals[$di] = $l if $uvals[$di] > $l;

        if ($uvals[$di]) {
            $uvals[$di] = $l if $uvals[$di] > $l;  # Set to simulation length if greater
            $uvals[$di]-- while $l%$uvals[$di] and ($uvals[$di] > 0);
            $uvals[$di] = $TimeControl{history_interval}[$di] if $uvals[$di] <=0;
        }

        # Set parent value to simulation length unless already set
        #
        if ($uvals[$di]) {$uvals[$pi] = int ($Rconf{dinfo}{domains}{$p}{length}/60) unless $uvals[$pi];} 

    }
    @{$TimeControl{auxhist1_interval}} = $uvals[0] ? @uvals[0..$Config{maxindex}] : (0);


    #----------------------------------------------------------------------------------------
    #  There is no reason to continue if we're not doing anything
    #----------------------------------------------------------------------------------------
    #
    return unless sum @{$TimeControl{auxhist1_interval}};



    #----------------------------------------------------------------------------------------
    #   Option:  AUXHIST1_NAMEKEY - Primary WRF output filename key
    #
    #   Values:  The AUXHIST1_NAMEKEY parameter is a string that will be used to complete
    #            the naming convention for the primary WRF fields.  All files will use a
    #            convention of "<namekey>_d<domain>_<date>" where "<namekey>" is replaced
    #            by the default or a user-specified string defined by AUXHIST1_NAMEKEY.
    #
    #   Default: AUXHIST1_NAMEKEY = auxhist1
    #----------------------------------------------------------------------------------------
    #
    my $default = 'auxhist1';
    my $namekey =  $Config{uconf}{AUXHIST1_NAMEKEY}[0];

    unless ($namekey eq $default) {
        $mesg = "Did you know that changing the WRF auxiliary history filenames may cause the ".
                "UEMS post processor to fail?  And if the UEMS post processor does not tolerate ".
                "failure, then neither should you! So kindly consider changing the value of ".
                "AUXHIST1_NAMEKEY from \"$Config{uconf}{AUXHIST1_NAMEKEY}[0]\" to its original value of ".
                "\"$default\". You can thank me later.";
         &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,'Almost Illegal Substitution!',$mesg) if $TimeControl{auxhist1_interval}[0];
    }


    #  Now form the value for auxhist1_outname in the namelist file.
    #  Assume that the default auxhist1_outname assigned in the namelist.arw
    #  file has a naming convention of "<namekey>_d<domain>_<date>" so we
    #  can extract the "<namekey>" with a split.
    # 
    my $nldef = $Config{nldefault}{TIME_CONTROL}{auxhist1_outname}[0];
       $nldef =~ s/\'|\"//g;  # Strip the leading and trailing quotes
       $nldef = 'auxhist1_d<domain>_<date>' unless $nldef;

    my ($nkey, $str) = split /_/ => $nldef;

    $nldef =~ s/$nkey/$namekey/;

    $TimeControl{auxhist1_outname}[0] = "\'$nldef\'";

    my ($of,$ss) = split /</, $nldef, 2;
    push @{$ARWconf{outfiles}} => $of;


    #----------------------------------------------------------------------------------------
    #   Option:  IO_FORM_AUXHIST1 - Format of the auxiliary WRF output files
    #
    #   Values:
    #
    #     1 - Machine dependent unformatted (binary) output (no software support)
    #     2 - WRF netCDF format (Not AWIPS compatible) (Default)
    #     4 - PHDF5 format (no software support)
    #     5 - GRIB 1 format  (ARW only) 
    #    10 - GRIB 2 format  (ARW only) 
    #
    #   Default: IO_FORM_AUXHIST1 = 2
    #----------------------------------------------------------------------------------------
    #
    my @opts = qw(2 5 10);
    $TimeControl{io_form_auxhist1}[0] = (defined $Config{uconf}{IO_FORM_AUXHIST1} and $Config{uconf}{IO_FORM_AUXHIST1}[0]) ? $Config{uconf}{IO_FORM_AUXHIST1}[0] : $opts[0];
    $TimeControl{io_form_auxhist1}[0] = $opts[0] unless grep {/^$TimeControl{io_form_auxhist1}[0]$/} @opts;

    push @{$ARWconf{tables}{io_form}} => "grib/grib2map.tbl" if $TimeControl{io_form_auxhist1}[0] == 10;
    push @{$ARWconf{tables}{io_form}} => "grib/gribmap.tbl"  if $TimeControl{io_form_auxhist1}[0] == 5;



    #----------------------------------------------------------------------------------------
    #   Option:  FRAMES_PER_AUXHIST1 - Number of data dumps per file
    #
    #   Notes:   Prefer value of 1 but will also allow ALL frames (10000)
    #
    #   Default: FRAMES_PER_AUXHIST1 = 1 
    #----------------------------------------------------------------------------------------
    #
    @{$TimeControl{frames_per_auxhist1}} = map { $_ = $Rconf{flags}{autopost} ? 1 : $_ } @{$Config{uconf}{FRAMES_PER_AUXHIST1}};


return;
}


sub TimeControl_AuxHist2 {
# ==============================================================================================
# WRF AUXHIST2 &TIME_CONTROL NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#   This routine manages the configuration of the auxiliary2 or AFWA output files,
#   including output frequency, naming convention, and format. Note that due to
#   errors in the WRF source code, use of these fields has been turned OFF for the
#   time being. 
#
# ==============================================================================================
# ==============================================================================================
#
use List::Util qw(sum);

    my $mesg    = qw{};

    my @rundoms = sort {$a <=> $b} keys %{$Rconf{dinfo}{domains}};

    #----------------------------------------------------------------------------------------
    #   Option :  AUXHIST2_INTERVAL - File frequency for the auxiliary EMS output files
    #
    #   Rules  : Not all listed here 
    #            a. If a child domain has a non-zero value (ON) then so must it's parent
    #            b. If 'Auto' anywhere in value list then all values set to history_interval
    #            c. Domain value set to history_interval if auxhist2_interval > history_interval
    #            d. Domain value must be integer multiple of domain simulation length
    #
    #   Default: auxhist2_interval = 0 or to run length if greater than forecast length
    #            Note that at the time of this writing, there  is a bug in WRF in that
    #            turning on AuxHist files for one domain requires the files be turned
    #            on for all parent domains as well; Otherwise, no files are output.
    #
    #   Note   : Until the AFWA diagnostics can be run on MPI the auxhist2 files have
    #            "immobilized" in the ARWprep::ProcessLocalConfiguration module.
    #----------------------------------------------------------------------------------------
    #
    my $l     = int ($Rconf{dinfo}{domains}{1}{length}/60);  #  Length of primary simulation in minutes
    my @rvals = (0) x $Config{maxdoms};  #  Initialize maxdoms values to 0

    my @uvals = (defined $Config{uconf}{AUXHIST2_INTERVAL} and @{$Config{uconf}{AUXHIST2_INTERVAL}}) ?  @{$Config{uconf}{AUXHIST2_INTERVAL}} : (0);
       @uvals = @{$TimeControl{history_interval}} if grep {/auto/i} @uvals;

    foreach (@uvals) {$_ = 0 if $_ > $l;}

    splice @rvals, 0, @uvals, @uvals;


    #  Reverse loop through all the domains in the simulation and assign values 
    #  to parent domains if missing.
    #  
    foreach my $d (sort {$b <=> $a} @rundoms) {

        my $di = $d-1;
        my $p  = $Rconf{dinfo}{domains}{$d}{parent}; my $pi = $p-1;
        my $l  = int ($Rconf{dinfo}{domains}{$d}{length}/60);

        $rvals[$di] = $l if $rvals[$di] > $l;

        if ($rvals[$di]) {
            $rvals[$di] = $l if $rvals[$di] > $l;  # Set to simulation length if greater
            $rvals[$di]-- while $l%$rvals[$di] and ($rvals[$di] > 0);
            $rvals[$di] = $TimeControl{history_interval}[$di] if $rvals[$di] <=0;
        }
        $rvals[$pi] = int ($Rconf{dinfo}{domains}{$p}{length}/60) unless $rvals[$pi];  # Set parent value to simulation length unless already set

    }
    @{$TimeControl{auxhist2_interval}} = $uvals[0] ? @uvals[0..$Config{maxindex}] : (0);


    #----------------------------------------------------------------------------------------
    #  There is no reason to continue if we're not doing anything
    #----------------------------------------------------------------------------------------
    #
    return unless sum @{$TimeControl{auxhist2_interval}};


    #----------------------------------------------------------------------------------------
    #   Option:  AUXHIST2_NAMEKEY - Primary WRF output filename key
    #
    #   Values:  The AUXHIST2_NAMEKEY parameter is a string that will be used to complete
    #            the naming convention for the primary WRF fields.  All files will use a
    #            convention of "<namekey>_d<domain>_<date>" where "<namekey>" is replaced
    #            by the default or a user-specified string defined by AUXHIST2_NAMEKEY.
    #
    #   Default: AUXHIST2_NAMEKEY = afwa
    #----------------------------------------------------------------------------------------
    #
    my $default = 'afwa';
    my $namekey = $Config{uconf}{AUXHIST2_NAMEKEY}[0];


    unless ($namekey eq $default) {
        $mesg = "Did you know that changing the WRF auxiliary history filenames may cause the ".
                "UEMS post processor to fail?  And if the UEMS post processor does not tolerate ".
                "failure, then neither should you! So kindly consider changing the value of ".
                "AUXHIST2_NAMEKEY from \"$Config{uconf}{AUXHIST2_NAMEKEY}[0]\" to its original value of ".
                "\"$default\". You can thank me later.";
         &Ecomm::PrintMessage(6,11+$Rconf{arf},94,1,2,'Almost Illegal Substitution!',$mesg) if $TimeControl{auxhist2_interval}[0];
    }


    #  Now form the value for auxhist2_outname in the namelist file.
    #  Assume that the default auxhist2_outname assigned in the namelist.arw
    #  file has a naming convention of "<namekey>_d<domain>_<date>" so we
    #  can extract the "<namekey>" with a split.
    # 
    my $nldef = $Config{nldefault}{TIME_CONTROL}{auxhist2_outname}[0];
       $nldef =~ s/\'|\"//g;  # Strip the leading and trailing quotes
       $nldef = 'afwa_d<domain>_<date>' unless $nldef;

    my ($nkey, $str) = split /_/ => $nldef;

    $nldef =~ s/$nkey/$namekey/;

    $TimeControl{auxhist2_outname}[0] = "\'$nldef\'";

    my ($of,$ss) = split /</, $nldef, 2;
    push @{$ARWconf{outfiles}} => $of;


    if ($TimeControl{auxhist2_interval}[0]) { #  Not needed unless using auxhist2 (afwa) files

        #----------------------------------------------------------------------------------------
        #   Option:  IO_FORM_AUXHIST2 - Format of the auxiliary WRF output files
        #
        #   Values:
        #
        #     1 - Machine dependent unformatted (binary) output (no software support)
        #     2 - WRF netCDF format (Not AWIPS compatible) (Default)
        #     4 - PHDF5 format (no software support)
        #     5 - GRIB 1 format  (ARW only) 
        #    10 - GRIB 2 format  (ARW only) 
        #
        #   Default: IO_FORM_AUXHIST2 = 2
        #----------------------------------------------------------------------------------------
        #
        my @opts = qw(2 5 10);
        $TimeControl{io_form_auxhist2}[0] = (defined $Config{uconf}{IO_FORM_AUXHIST2} and $Config{uconf}{IO_FORM_AUXHIST2}[0]) ? $Config{uconf}{IO_FORM_AUXHIST2}[0] : $opts[0];
        $TimeControl{io_form_auxhist2}[0] = $opts[0] unless grep {/^$TimeControl{io_form_auxhist2}[0]$/} @opts;

        push @{$ARWconf{tables}{io_form}} => "grib/grib2map.tbl" if $TimeControl{io_form_auxhist2}[0] == 10;
        push @{$ARWconf{tables}{io_form}} => "grib/gribmap.tbl"  if $TimeControl{io_form_auxhist2}[0] == 5;


        #----------------------------------------------------------------------------------------
        #   Option:  FRAMES_PER_AUXHIST2 - Number of data dumps per file
        #
        #   Notes:   Prefer value of 1 but will also allow ALL frames (10000)
        #
        #            FRAMES_PER_AUXHIST2 must be 1 if using autopost
        #
        #   Default: FRAMES_PER_AUXHIST2 = 1 
        #----------------------------------------------------------------------------------------
        #
        @{$TimeControl{frames_per_auxhist2}} = map { $_ = $Rconf{flags}{autopost} ? 1 : $_ } @{$Config{uconf}{FRAMES_PER_AUXHIST2}};

    }


return;
}


sub TimeControl_Ancillary {
# ==============================================================================================
# WRF ANCILLARY &TIME_CONTROL NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Configure time_control variables not handled by other subroutines.
#
# ==============================================================================================
# ==============================================================================================
#
    my $mesg = qw{};

    my @rundoms = sort {$a <=> $b} keys %{$Rconf{dinfo}{domains}};

    #----------------------------------------------------------------------------------------
    #   Option:  INTERVAL_SECONDS - Input data interval for boundary conditions
    #   
    #   Notes:   Calculated internally by the EMS
    #----------------------------------------------------------------------------------------
    #
    unless ($Rconf{dinfo}{domains}{1}{interval}) {
        $mesg = "There is no value specified for interval_seconds in the namelist static/namelist.wps file, ".
                "This problem must be addressed before continuing.";
        $ENV{RMESG} = &Ecomm::TextFormat(0,0,94,0,0,'Namelist Problems',$mesg);
        return 1;
    }
    $TimeControl{interval_seconds}[0]    = $Rconf{dinfo}{domains}{1}{interval};



    #----------------------------------------------------------------------------------------
    #   Options: INPUT_FROM_FILE and FINE_INPUT_STREAM
    #
    #   We need to check whether a nested domain starts later than the primary domain
    #   since this will determine whether the fine_input_stream value is 0 or 2.
    #----------------------------------------------------------------------------------------
    #
    @{$TimeControl{fine_input_stream}} = (0) x $Config{maxdoms};

    @{$TimeControl{input_from_file}}   = ('F') x $Config{maxdoms};
    $TimeControl{input_from_file}[0]   = 'T';  # Always T for domain 1

    foreach my $d (@rundoms) {  my $di = $d-1;

        $TimeControl{input_from_file}[$di]   = 'T' unless $Rconf{flags}{interp};

        $TimeControl{fine_input_stream}[$di] = $Rconf{dinfo}{domains}{$d}{sdate} eq $Rconf{dinfo}{domains}{1}{sdate} ? 0 
                                             : $TimeControl{input_from_file}[$di] eq 'T'                             ? 2 : 0;
    }



    #----------------------------------------------------------------------------------------
    #   Option:  ADJUST_OUTPUT_TIMES - Automatically adjust output times in forecast files
    #
    #   Values:  T - Automatically adjust output times in forecast files
    #            F - Do not adjust output times in forecast files
    #
    #   Notes:   Override user choice as the UEMS POST will fail otherwise
    #
    #   Default: ADJUST_OUTPUT_TIMES = 'T'
    #----------------------------------------------------------------------------------------
    #
    $TimeControl{adjust_output_times}[0]    = 'T';


    
    #----------------------------------------------------------------------------------------
    #   Option:  IOFIELDS_FILENAME - list of filenames used to override registry IO
    #
    #   Values:  The IOFIELDS_FILENAME parameter is a list of filenames in quotes, separated
    #            by a comma, that contain modifications to the registry data stream. Files
    #            must be located in the <domain>/static directory.
    #
    #            This option will be turned OFF if IOFIELDS_FILENAME is blank.
    #
    #   Notes:   If you use this option then make sure you follow the guidelines provided
    #            in the official WRF user's guide. The files must have a naming convention
    #            of "iofields_d<domain>.txt", i.e.,
    #
    #            IOFIELDS_FILENAME = iofields_d01.txt,iofields_d02.txt,...,iofields_d0N.txt
    #
    #            Otherwise the UEMS will "accidentally" delete the files from the directory
    #            during one of it's many cleaning fits.
    #
    #            Actually, any files with the name "iofields_*" will be preserved.
    #
    #   Default: IOFIELDS_FILENAME = (blank)
    #----------------------------------------------------------------------------------------
    #
    if (defined $Config{uconf}{IOFIELDS_FILENAME} and $Config{uconf}{IOFIELDS_FILENAME}[0]) {

        foreach (@{$Config{uconf}{IOFIELDS_FILENAME}}) {$_ =~ s/\s+|\'|\"//g; next unless $_; $_ =~ "\'$_\'";}
        
        if (@{$Config{uconf}{IOFIELDS_FILENAME}} and $Config{uconf}{IOFIELDS_FILENAME}[0]) {
            @{$TimeControl{iofields_filename}}       = ($Config{uconf}{IOFIELDS_FILENAME}[0]);
            $TimeControl{ignore_iofields_warning}[0] = 'T';
        }
    }


return;
}


sub TimeControl_Diagnostics {
# ==============================================================================================
# WRF DIAGNOSTICS &TIME_CONTROL NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Configure the various diagnostic output options in the time_control section of the 
#  WRF namelist file. Note that some or all of these fields may not be active in the UEMS.
#
# ==============================================================================================
# ==============================================================================================
#
    my $value   = 0;
    my @opts    = ();

    #----------------------------------------------------------------------------------------
    #  Variable:  DEBUG_LEVEL
    #
    #  Description:  A value between 0 and 18,446,744,073,709,551,615 (I think on 64-bit system)
    #                with a larger value giving you more text printed out but less information.
    #----------------------------------------------------------------------------------------
    #
    $value = (defined $Config{uconf}{DEBUG_LEVEL} and $Config{uconf}{DEBUG_LEVEL}[0]) ? $Config{uconf}{DEBUG_LEVEL}[0] : 0;
    for ($value) {$_ = 0 unless $_ and $_ =~ /^\d+$/ and $_ > 0;}  #  Set to 0 unless proper format

    @{$TimeControl{debug_level}} = ($value) if $value;



    #----------------------------------------------------------------------------------------
    #  Variable:  DIAG_PRINT
    #
    #  Description:
    #
    #    0 - Turned OFF with no additional diagnostic information (Default)
    #    1 - Include domain averaged 3-hourly hydrostatic surface pressure and 
    #        column pressure tendency to the WRFOUT files.
    #    2 - In addition to fields from 1, include domain-averaged rainfall,
    #        surface evaporation, and sensible & latent heat fluxes. Party on!
    #----------------------------------------------------------------------------------------
    #
    @opts = qw(0 1 2);
    $value = (defined $Config{uconf}{DIAG_PRINT} and $Config{uconf}{DIAG_PRINT}[0]) ? $Config{uconf}{DIAG_PRINT}[0] : 0;
    for ($value) {$_ = 0 unless $_ and $_ =~ /^\d+$/ and $_ > 0; $_+=0;}  #  Set to 0 unless proper format
    $value = $opts[0] unless grep {/^${value}$/} @opts;

    @{$TimeControl{diag_print}} = ($value) if $value;



    #----------------------------------------------------------------------------------------
    #  Variable:  OUTPUT_DIAGNOSTICS
    #
    #  Description: 
    #
    #    0 - Off with no additional diagnostic information (Default)
    #    1 - Output and additional 36 (and growing) surface diagnostic arrays
    #        in the time interval are specified. Outout is written to Aux history
    #        stream #3.
    #----------------------------------------------------------------------------------------
    #
    $value = (defined $Config{uconf}{OUTPUT_DIAGNOSTICS} and $Config{uconf}{OUTPUT_DIAGNOSTICS}[0]) ? $Config{uconf}{OUTPUT_DIAGNOSTICS}[0] : 0;
    for ($value) {$_ = 0 unless $_ and $_ =~ /^\d+$/ and $_ > 0; $_+=0; $_ = $_ ? 1 : 0;}  #  Set to 0 unless proper format

 
    if ($value) {
    
        @{$TimeControl{output_diagnostics}} = ($value);

        #-------------------------------------------------------------------------------
        #  Note that the following are hard coded simply because they have not been 
        #  tested in the UEMS.
        #
        #  auxhist3_outname    - Name of output file (Default: wrfxtrm_d<domain>_<date>
        #  auxhist3_interval   - Frequency of output file
        #  frames_per_auxhist3 - Times per file (Should always be 1)
        #  io_form_auxhist3    - File Format (Should always be 2)
        #-------------------------------------------------------------------------------
        #
        $TimeControl{auxhist3_outname}[0]    = "\'wrfxtrm_d<domain>_<date>\'";
        $TimeControl{auxhist3_interval}[0]   = $TimeControl{history_interval}[0]; #  Just use history_interval
        $TimeControl{frames_per_auxhist3}[0] = 1;
        $TimeControl{io_form_auxhist3}[0]    = 2;
    }


    #----------------------------------------------------------------------------------------
    #  Variable:  NWP_DIAGNOSTICS
    #
    #  Description:
    #
    #    0 - Off with no additional diagnostic information (Default)
    #    1 - Output and additional 7 (and growing) diagnostic fields to the primary
    #        history file. Most of these fields are already included by default
    #        with the EMS via the EMS diagnostic routine and thus would just be 
    #        duplicated. Fields are part of NSSL collection.
    #----------------------------------------------------------------------------------------
    #
    $value = (defined $Config{uconf}{NWP_DIAGNOSTICS} and $Config{uconf}{NWP_DIAGNOSTICS}[0]) ? $Config{uconf}{NWP_DIAGNOSTICS}[0] : 0;
    for ($value) {$_ = 0 unless $_ and $_ =~ /^\d+$/ and $_ > 0; $_+=0; $_ = $_ ? 1 : 0;}  #  Set to 0 unless proper format

    @{$TimeControl{nwp_diagnostics}} = ($value) if $value;
    
    
return;
}


sub TimeControl_Final {
# ==============================================================================================
# WRF FINAL &TIME_CONTROL NAMELIST CONFIGURATION 
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  Subroutine that cleans up any loose ends within the &time_control section of the WRF
#  namelist. Occasionally, variables require tweaks after everything else has been set.
#  This is the routine where it would be done if there were any to do, which there isn't.
#
# ==============================================================================================
# ==============================================================================================
#

    #  Currently nothing needed for the Time Control section but thanks for visiting!
    #  The subroutine is here for consistency.
        

return;
}


sub TimeControl_Debug {
# ==============================================================================================
# &TIME_CONTROL NAMELIST DEBUG ROUTINE
# ==============================================================================================
#
# SO WHAT DOES THIS ROUTINE DO FOR ME?
#
#  When the --debug 4+ flag is passed, prints out the contents of the WRF time_control 
#  namelist section .
#
# ==============================================================================================
# ==============================================================================================
#   
    my @defvars  = ();
    my @ndefvars = ();
    my $nlsect   = 'time_control'; #  Specify the namelist section to print out

    return unless $ENV{RUN_DBG} > 3;  #  Only for --debug 4+

    foreach my $tcvar (@{$ARWconf{nlorder}{$nlsect}}) {
        defined $TimeControl{$tcvar} ? push @defvars => $tcvar : push @ndefvars => $tcvar;
    }

    return unless @defvars or @ndefvars;

    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,13+$Rconf{arf},144,1,1,'Leaving &ARWtcntrl');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-24s  = %s',$_,join ', ' => @{$TimeControl{$_}})) foreach @defvars;
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,' ');
    &Ecomm::PrintMessage(0,18+$Rconf{arf},94,1,0,sprintf('%-24s  = %s',$_,'Not Used')) foreach @ndefvars;
    &Ecomm::PrintMessage(0,13+$Rconf{arf},94,1,2,'=' x 72);
       


return;
}


