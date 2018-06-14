#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Ofinal.pm
#
#  DESCRIPTION:  Ofinal contains each of the primary routines used for the
#                final configuration of ems_post. It's the least elegant of
#                the ems_post modules simply because there is a lot of sausage
#                making going on.
#
#                A lot of sausage making
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Ofinal;

use warnings;
use strict;
require 5.008;
use English;

use List::Util qw( max );

use vars qw (%Final %Oconf %Upost);


sub PostFinalConfiguration {
#==================================================================================
#  The &PostFinalConfiguration routine merges the final configuration file values
#  with any command line flags that were passed. The resulting returned hash 
#  will be used throughout ems_post.  Note that the order of subroutine calls
#  is important because some values must be set before others can be defined.
#  
#  Not all variables need to be merged since some file parameters do not have
#  a command line override flag.  Finally only parameters needed after this
#  routine are passed out. The others are left to fend for themselves.
#
#  A somewhat inconvenient issue that needs to be cleaned up in this routine is
#  that values from any flags passed, such as --grib, are single variable values,
#  $Oconf{flags}{grib} while those read from the configuration files are arrays
#  of maxdoms values. Consequently, any argument passed to these flags will
#  replace the individual parameter values from the configuration file. It's a 
#  heavy-handed but you'll get over it, I hope.
#==================================================================================
#
    $ENV{OMESG} = '';

    my $upref = shift; %Upost = %{$upref};
    my $cpref = shift; %Oconf = %{$cpref};
     

    #  ----------------- The important parameters ---------------------------------
    #  First things first - Note that the order of configuration is important
    #  as some parameters are needed in the configuration of others.  Any 
    #  information that needs to be saved is held in the %Final hash, which
    #  is only available within this module.
    #------------------------------------------------------------------------------
    #
    %Final = ();


    #  ----------------- Missing Library Test -----------------------------------
    #  Both GEMPAK & GrADS use shared system libraries, which may not be 
    #  installed on the local system. Test whether the necessary libraries
    #  are available. The required libraries are specified with each 
    #  subroutine with any missing libraries returned as a comma separated 
    #  string.
    #------------------------------------------------------------------------------
    #
    $Final{gempaklibs}     = &Final_gempaklibs();
    $Final{bufkitlibs}     = &Final_bufkitlibs();
    $Final{gradslibs}      = &Final_gradslibs();


    #  ----------------- The simple parameters -----------------------------------
    #  These post configuration file parameters do not need any additional
    #  checks or configuration and just needs to be passed along to the 
    #  %Final hash.
    #------------------------------------------------------------------------------
    #
    $Final{mpicheck}       =  &Final_filevalue('mpicheck');
    $Final{mdlid}          =  &Final_filevalue('mdlid');
    $Final{ocntr}          =  &Final_filevalue('ocntr');
    $Final{filename_grib}  =  &Final_filevalue('filename_grib');
    $Final{filename_bufr}  =  &Final_filevalue('filename_bufr');

    $Final{filename_gempak}=  &Final_filevalue('filename_gempak');
    $Final{monofile_gempak}=  &Final_filevalue('monofile_gempak');
    $Final{monofile_grads} =  &Final_filevalue('monofile_grads');
    $Final{bufr_style}     =  &Final_filevalue('bufr_style');
    $Final{ascisnd}        =  &Final_filevalue('ascisnd');
    $Final{append_date}    =  &Final_filevalue('append_date');
    $Final{zipit}          =  &Final_filevalue('zipit');

    $Final{rundir}         =  &Final_flagvalue('rundir');
    $Final{debug}          =  &Final_flagvalue('debug');
    $Final{summary}        =  &Final_flagvalue('summary');
    $Final{info}           =  &Final_flagvalue('info');
    $Final{index}          =  &Final_flagvalue('index');

	$Final{domains}        =  join ',' => keys %{$Upost{rtenv}{postdoms}};


    #  ------------------- The general parameters ---------------------------------
    #  Actually, all the parameters are important, although some more than
    #  others. Below are those parameters that are not domain specific, i.e.,
    #  are either applied to all the domains being processed or just used for 
    #  running ems_post.
    #------------------------------------------------------------------------------
    # 
    $Final{grib}           =  &Final_grib();
    $Final{noupp}          =  &Final_noupp();
    $Final{exports}        =  &Final_exports();
    $Final{emspost}        =  &Final_emspost();
    $Final{autopost}       =  &Final_autopost();
    $Final{scour}          =  &Final_scour();
    $Final{nodecpus}       =  &Final_nodecpus();


    #----------------- GRIB and ancillary products --------------------------------
    #  Complete the final configuration for the creation of GRIB 2 files from
    #  the simulation output. Additionally, configure any products that are 
    #  derived from GRIB. Remember that order may be important!
    #------------------------------------------------------------------------------
    #
    $Final{scntr}        =  &Final_scntr();

    $Final{frqwrf_grib}  =  &Final_frequency('freq_wrf_grib',$Final{grib});
    $Final{accwrf_grib}  =  &Final_accumulation('accum_period_wrf',$Final{frqwrf_grib});

    $Final{frqaux_grib}  =  &Final_frequency('freq_aux_grib',$Final{grib});
    $Final{accaux_grib}  =  &Final_accumulation('accum_period_aux',$Final{frqaux_grib});

    
    #------------------------------------------------------------------------------
    #  GEMPAK file configuration
    #------------------------------------------------------------------------------
    #
    $Final{gempak}       =  &Final_gempak($Final{grib});

    $Final{frqwrf_gempak}=  &Final_frequency('freq_wrf_gempak',$Final{gempak});
    $Final{frqwrf_gempak}=  &Frequency_Check($Final{frqwrf_gempak},$Final{frqwrf_grib});

    $Final{frqaux_gempak}=  &Final_frequency('freq_aux_gempak',$Final{gempak});
    $Final{frqaux_gempak}=  &Frequency_Check($Final{frqaux_gempak},$Final{frqaux_grib});

    $Final{scraux_gempak}=  &Final_script('postscr_aux_gempak');
    $Final{scrwrf_gempak}=  &Final_script('postscr_wrf_gempak');
    

    #------------------------------------------------------------------------------
    #  GrADS file configuration
    #------------------------------------------------------------------------------
    #
    $Final{grads}        =  &Final_grads($Final{grib});

    $Final{frqwrf_grads} =  &Final_frequency('freq_wrf_grads',$Final{grads});
    $Final{frqwrf_grads} =  &Frequency_Check($Final{frqwrf_grads},$Final{frqwrf_grib});

    $Final{frqaux_grads} =  &Final_frequency('freq_aux_grads',$Final{grads});
    $Final{frqaux_grads} =  &Frequency_Check($Final{frqaux_grads},$Final{frqaux_grib});

    $Final{scraux_grads} =  &Final_script('postscr_aux_grads');
    $Final{scrwrf_grads} =  &Final_script('postscr_wrf_grads');


    #----------------- BUFR and ancillary products --------------------------------
    #  Complete the final configuration for the creation of BUFR files from
    #  the simulation output. Additionally, configure any products that are 
    #  derived from BUFR. Remember that order may be important!
    #------------------------------------------------------------------------------
    #
    $Final{bufr}         =  &Final_bufr();
    $Final{frqwrf_bufr}  =  &Final_frequency('freq_wrf_bufr',$Final{bufr});

    $Final{bufkit}       =  &Final_bufkit($Final{bufr});
    $Final{gemsnd}       =  &Final_gemsnd($Final{bufr});
    $Final{bfinfo}       =  &Final_bfinfo($Final{bufr});


    #  ------------------ configurable files and lists ----------------------------
    #  
    $Final{grbcntrl_wrf}   = &Final_gribcntrl('grib_cntrl_wrf'); return () if $ENV{OMESG};
    $Final{grbcntrl_aux}   = &Final_gribcntrl('grib_cntrl_aux'); return () if $ENV{OMESG};
    $Final{station_list}   = &Final_stationlist('station_list'); return () if $ENV{OMESG};


    #------------------------------------------------------------------------------
    #  Debug information if the --debug <value> is greater than 0
    #------------------------------------------------------------------------------
    #
    &FinalDebugInformation(\%Final) if $Final{debug} > 0;


return %Final;  
}



sub Final_nodecpus {
#==================================================================================
#  Complete the (semi-) final configuration of the EMSUPP_NODECPUS parameter 
#  located in the post_grib.conf file.  If the --ncpus flag was passed with a 
#  value argument then the value of EMSUPP_NODECPUS is replaced by "local:#",
#  where "#" is the number of cpus passed to --ncpus.  Note that the number
#  of processors passed to --ncpus may have been modified in the Config_ncpus
#  subroutine if the value was greater then the maximum number available on
#  the local system.
# 
#  If this is part of a UEMS Autopost run and the --autoupp flag was passed,
#  the argument will have the same format as EMSUPP_NODECPUS (AUTOUPP_NODECPUS)
#  and will take precedence.
#==================================================================================
#
    my $maxcpus  = 0;
       $maxcpus  = $ENV{OMP_NUM_THREADS} if defined $ENV{OMP_NUM_THREADS} and $ENV{OMP_NUM_THREADS} > 0;
       $maxcpus  = $Upost{emsenv}{sysinfo}{total_cores} if defined $Upost{emsenv}{sysinfo}{total_cores} and $Upost{emsenv}{sysinfo}{total_cores} > 0;

    my @nodecpu  = $Oconf{flags}{ncpus} ? ("local:$Oconf{flags}{ncpus}") : @{$Oconf{files}{EMSUPP_NODECPUS}};

    my $nodecpus = join ',' => @nodecpu;
       $nodecpus = $Oconf{flags}{autoupp} if $Oconf{flags}{autoupp};  #  From the autopost routine
       $nodecpus =~ s/NCPUS/$maxcpus/g;  #  A default of "local:NCPUS" was set in &PostFileConfiguration
       

return $nodecpus;
}



sub Final_grib {
#==================================================================================
#  Complete the final configuration of the GRIB option based upon the values 
#  in $Oconf{flags}{grib} and $Oconf{files}{GRIB}. Note that priority is given
#  to --[no]grib if it was passed.
#
#  Upon exit, the $Final{grib} value will be either:
#
#      0 - Grib and ancillary file processing OFF
#      1 or string - Grib and ancillary file processing ON
#
#==================================================================================
#
    my @array = @{$Oconf{files}{GRIB}};

    if ($Oconf{flags}{grib}) {
        $Oconf{flags}{grib} = 0 if $Oconf{flags}{grib} =~ /^-1$/;
        @array = ($Oconf{flags}{grib}) x $Upost{maxdoms};
    }
    @array = (0) unless max @array;


return join ',' =>  @array;
}


sub Final_noupp {
#==================================================================================
#  Complete the final configuration of the noupp flag,  which controls whether
#  the UEMS UPP is run to process the netCDF files into GRIB 2 format.
#
#    1 - DO NOT run the EMS UPP
#    0 - Do whatever was requested
#
#  Not that passing the --nogrib flag implies --noupp
#==================================================================================
#
    my $noupp = $Oconf{flags}{noupp};
       $noupp = 1 unless $Final{grib};

return $noupp;
}


sub Frequency_Check {
#==================================================================================
#  The purpose of this routine is to ensure that the frequency, start, and stop
#  times used for processing a requested dataset do not exceed those of the dataset 
#  used to create them. For example, the values used for GrADS "FREQ:START:STOP"
#  are within the bounds defined for GRIB. The input arguments are:
#
#      $reqst = the "FREQ:START:STOP" for the dataset to be checked
#      $bound = the "FREQ:START:STOP" for the dataset that serves as bounds
#==================================================================================
#
    my ($reqst, $bound) = @_;

    my @reqsts = split ',', $reqst;
    my @bounds = split ',', $bound;


    foreach my $i (0..$#reqsts) {

        my ($rfreq, $rstart, $rstop) = split ':', defined $reqsts[$i] ? $reqsts[$i] : $reqsts[-1];
        my ($bfreq, $bstart, $bstop) = split ':', defined $bounds[$i] ? $bounds[$i] : $bounds[-1];

        $rfreq  = $bfreq  if $bfreq  > $rfreq  or $rfreq%$bfreq;
        $rstart = $bstart if $rstart < $bstart or $rstart%$rfreq;
        $rstop  = $bstop  if $rstop  > $bstop  or $rstop%$rfreq;

        $reqsts[$i] = "$rfreq:$rstart:$rstop";

     }
     $reqst = @reqsts ? join ',', @reqsts : '';
        
return $reqst;
}


sub Final_frequency {
#==================================================================================
#  This subroutine manages the value of freq_wrf_grib as described in the 
#  post_grib.conf file. If the user passed an argument to the --grib flag
#  then that string will be substituted before its passed to the &FinalFreqStartStop 
#  routine for QA checks. 
#==================================================================================
#
    my ($parm,$str) = @_;
    my ($freq,$type,$form) = split '_' => lc $parm;

    my @flags = (defined $str) ? split ',' => $str : (0);
    my @array = (grep {/^$flags[0]$/} (0,1)) ? @{$Oconf{files}{uc $parm}} : @flags;

    my $i=0;
    foreach my $fse (@array) {
        $fse = &FinalFreqStartStop($fse,$Upost{rtenv}{hist}{$type}[$i++]);
    }


return join ',' =>  @array;
}



sub Final_accumulation {
#==================================================================================
#  This subroutine manages the value of accum_period_wrf|aux as described in the 
#  post_grib.conf file. The requested accumulation period is checked against the
#  GRIB file processing frequency ($Final{frqwrf|aux_grib}) for each domain and 
#  data type (wrfout or auxhist) where the final accumulation period value must
#  be the same as $Final{frqwrf|aux_grib} or the simulation length
#==================================================================================
#
    my $run          = int ($Upost{rtenv}{length}/60);
    my @array        = ();
    my ($parm,$freq) = @_;

    my @freqs = split ',' => $freq;  #  Frequency of netCDF to GRIB processing
    my $type  = ($parm =~ /aux/i) ? 'aux' : 'wrf';

    my $i=0;
    foreach my $pacc (@{$Oconf{files}{uc $parm}}) {
        my $freq = ($freqs[$i] =~ /^(\d+)/) ? $1 : $Upost{rtenv}{hist}{$type}[$i]; $i++;
        $pacc = ($pacc < $run) ? $freq : $run;
        push @array => $pacc;
    }


return join ',' =>  @array;
}



sub Final_gempak {
#==================================================================================
#  Complete the final configuration of the GEMPAK option based upon the values 
#  in $Oconf{flags}{gempak} and $Oconf{files}{GEMPAK}. Note that priority is given
#  to --[no]gempak if it was passed.
#
#  Upon exit, the $Final{gempak} values will be a csv string of values where:
#
#      0 - GEMPAK and ancillary file processing OFF
#      1 - GEMPAK and ancillary file processing ON
#
#==================================================================================
#
    my $str    = shift;

    my @gempak = @{$Oconf{files}{GEMPAK}};
    my @gribs  = map { $_ ? 1 : 0 } split /,/ => $str;

    if ($Oconf{flags}{gempak}) {
        $Oconf{flags}{gempak} = 0 if $Oconf{flags}{gempak} =~ /^-1$/;
        @gempak = ($Oconf{flags}{gempak}) x $Upost{maxdoms};
    }

    #  Ensure the GRIB flag is turned ON for each GEMPAK domain
    #
    @gempak = &Others::ArrayMultiply(\@gribs,\@gempak);
    @gempak = (0) unless max @gempak;


return join ',' =>  @gempak;
}



sub Final_grads {
#==================================================================================
#  Complete the final configuration of the GRADS option based upon the values 
#  in $Oconf{flags}{grads} and $Oconf{files}{GRADS}. Note that priority is given
#  to --[no]grads if it was passed.
#
#  Upon exit, the $Final{grads} values will be a csv string of values where:
#
#      0 - GRADS and ancillary file processing OFF
#      1 - GRADS and ancillary file processing ON
#
#==================================================================================
#
    my $str    = shift;

    my @grads = @{$Oconf{files}{GRADS}};
    my @gribs  = map { $_ ? 1 : 0 } split /,/ => $str;

    if ($Oconf{flags}{grads}) {
        $Oconf{flags}{grads} = 0 if $Oconf{flags}{grads} =~ /^-1$/;
        @grads = ($Oconf{flags}{grads}) x $Upost{maxdoms};
    }

    #  Ensure the GRIB flag is turned ON for each GRADS domain
    #
    @grads = &Others::ArrayMultiply(\@gribs,\@grads);
    @grads = (0) unless max @grads;


return join ',' =>  @grads;
}



sub Final_bufr {
#==================================================================================
#  Complete the final configuration of the BUFR option based upon the values 
#  in $Oconf{flags}{bufr} and $Oconf{files}{bufr}. Note that priority is given
#  to --[no]bufr if it was passed.
#
#  Upon exit, the $Final{bufr} value will be either:
#
#      0 - BUFR and ancillary file processing OFF
#      1 or string - BUFR and ancillary file processing ON
#
#==================================================================================
#
    my @array = @{$Oconf{files}{BUFR}};

    if ($Oconf{flags}{bufr}) {
        $Oconf{flags}{bufr} = 0 if $Oconf{flags}{bufr} =~ /^-1$/;
        @array = ($Oconf{flags}{bufr}) x $Upost{maxdoms};
    }
    @array = (0) unless max @array;


return join ',' =>  @array;
}



sub Final_bfinfo {
#==================================================================================
#  Complete the final configuration of the BUFR_INFO option based upon the values 
#  in $Oconf{flags}{bfinfo} and $Oconf{files}{BUFR_INFO}. Note that priority is given
#  to --[no]bfinfo if it was passed.
#
#  Upon exit, the $Final{bfinfo} values will be a csv string of values where:
#
#      0 - BFINFO information OFF
#      1 - BFINFO information ON
#
#==================================================================================
#
    my $str    = shift;

    my @bfinfo = @{$Oconf{files}{BUFR_INFO}};
    my @bufrs  = map { $_ ? 1 : 0 } split /,/ => $str;

    if ($Oconf{flags}{bfinfo}) {
        $Oconf{flags}{bfinfo} = 0 if $Oconf{flags}{bfinfo} =~ /^-1$/;
        @bfinfo = ($Oconf{flags}{bfinfo}) x $Upost{maxdoms};
    }

    #  Ensure the BUFR flag is turned ON for each BFINFO domain
    #
    @bfinfo = &Others::ArrayMultiply(\@bufrs,\@bfinfo);

    @bfinfo = (0) unless max @bfinfo;


return join ',' =>  @bfinfo;
}



sub Final_bufkit {
#==================================================================================
#  Complete the final configuration of the BUFKIT option based upon the values 
#  in $Oconf{flags}{bufkit} and $Oconf{files}{BUFKIT}. Note that priority is given
#  to --[no]bufkit if it was passed.
#
#  Upon exit, the $Final{bufkit} values will be a csv string of values where:
#
#      0 - BUFKIT and ancillary file processing OFF
#      1 - BUFKIT and ancillary file processing ON
#
#==================================================================================
#
    my $str    = shift;

    my @bufkit = @{$Oconf{files}{BUFKIT}};
    my @bufrs  = map { $_ ? 1 : 0 } split /,/ => $str;

    if ($Oconf{flags}{bufkit}) {
        $Oconf{flags}{bufkit} = 0 if $Oconf{flags}{bufkit} =~ /^-1$/;
        @bufkit = ($Oconf{flags}{bufkit}) x $Upost{maxdoms};
    }

    #  Ensure the BUFR flag is turned ON for each BUFKIT domain
    #
    @bufkit = &Others::ArrayMultiply(\@bufrs,\@bufkit);

    @bufkit = (0) unless max @bufkit;


return join ',' =>  @bufkit;
}



sub Final_gemsnd {
#==================================================================================
#  Complete the final configuration of the GEMSND option based upon the values 
#  in $Oconf{flags}{gemsnd} and $Oconf{files}{GEMSND}. Note that priority is given
#  to --[no]bufkit if it was passed.
#
#  Upon exit, the $Final{gemsnd} values will be a csv string of values where:
#
#      0 - GEMSND and ancillary file processing OFF
#      1 - GEMSND and ancillary file processing ON
#==================================================================================
#
    my $str    = shift;

    my @gemsnd = @{$Oconf{files}{GEMSND}};
    my @bufrs  = map { $_ ? 1 : 0 } split /,/ => $str;
    my @bfkts  = map { $_ ? 1 : 0 } split /,/ => $Final{bufkit};

    if ($Oconf{flags}{gemsnd}) {
        $Oconf{flags}{gemsnd} = 0 if $Oconf{flags}{gemsnd} =~ /^-1$/;
        @gemsnd = ($Oconf{flags}{gemsnd}) x $Upost{maxdoms};
    }
    
    #  Ensure the GEMSND flag is turned ON for each BUFKIT domain
    #
    @gemsnd = &Others::ArrayMultiply(\@bufrs,\@bfkts||\@gemsnd);

    @gemsnd = (0) unless max @gemsnd;


return join ',' =>  @gemsnd;
}



sub Final_autopost {
#==================================================================================
#  Complete the final configuration for the AUTOPOST parameter, which is obtained
#  obtained from the --autopost flag. If --autopost was passed then the work
#  done here is transfered to Final_emspost output since --autopost overrides
#  the --emspost flag but $Final{emspost} is used in the processing. If that 
#  happens then $Final{autopost} will be set to 1.
#==================================================================================
#
    my $autopost  = $Oconf{flags}{autopost}  ? $Oconf{flags}{autopost} : '';  # set to config file value
       $autopost  = '0:primary' if $autopost =~ /^auto/;                      # '0:primary' is the default value

    return '' unless $autopost;
    return '' if $autopost =~ /^off/;  # Turns off all post-processing

    my @rundoms = sort {$a <=> $b} keys %{$Upost{rtenv}{postdoms}};

    #-----------------------------------------------------------------------------
    #  Split the argument string into "groups" and then parse further to determine
    #  the domain and datasets to process. The rules for each domain specified
    #  are carried within a hash of arrays. If the user sets a default rule
    #  then that will be carried in the @{$rules{0}} array. If the $rules{0} 
    #  hash is not populated following this loop then ONLY those domains explicitly
    #  specified by AUTOPOST or --autopost will be processed. If the $rules{0}
    #  hash is populated following this loop then all domains will be processed
    #  with those not explicitly defined getting the @{$rules{0}} values.
    #  If the --afwa, --auxhist, or --wrfout flags are passed (which they should 
    #  not since --autopost is not for the command line, but just in case) then
    #  those define the default rules.  
    #
    #  The AFWA dataset is not working yet so ignore for now.
    #-----------------------------------------------------------------------------
    #
    my %rules = ();
    foreach my $group (split ',', $autopost) {
        my ($d,$p,$a) = (0,'','');;
        foreach (split ':', $group) {
            $d = $_ if /(\d)+/; $d+=0;
            $p = 1 if /^pri|^wrf/i;
            $a = 1 if /^aux/i;
        }
        next unless grep {/^$d$/} (0,@rundoms);  #  Skip domains not in simulation

        @{$rules{$d}} = () unless defined $rules{$d};
        push @{$rules{$d}}, 'primary'   if $p;
        push @{$rules{$d}}, 'auxiliary' if $a;
    }


    #------------------------------------------------------------------
    #  If the default rule option is turned ON make sure it has a 
    #  dataset value (primary). This would only happen if either
    #  the user included a '0' as a domain and failed to specify a 
    #  dataset.
    #------------------------------------------------------------------
    #
    @{$rules{0}} = ('primary') if defined $rules{0} and ! @{$rules{0}};

    push @{$rules{0}} => 'primary'   if $Oconf{flags}{wrfout};
    push @{$rules{0}} => 'auxiliary' if $Oconf{flags}{auxhist};
    push @{$rules{0}} => 'afwa'      if $Oconf{flags}{afwa};   # Should be 0 now.

    @{$rules{0}} = reverse sort &Others::rmdups(@{$rules{0}});


    #------------------------------------------------------------------
    #  Loop over all the run-time domains. Create the rule groups and 
    #  then write them to an array.
    #------------------------------------------------------------------
    #
    my @groups=();
    foreach my $d (sort {$a <=> $b} @rundoms) {

        next unless defined $rules{$d} or defined $rules{0};

        my @rg = (defined $rules{0}) ? @{$rules{0}} : ();
           @rg = @{$rules{$d}} if defined $rules{$d} and @{$rules{$d}};


        @{$rules{$d}} = reverse sort &Others::rmdups(@rg);
        @{$rules{$d}} = ('primary') unless @{$rules{$d}};  # Only necessary when neither default rule nor domain rule is defined

        push @groups, join ':', ($d,@{$rules{$d}});
    }

    
    #------------------------------------------------------------------
    #  The big switch - replace primary -> wrfout and 
    #  auxiliary -> auxhist in the array because that is what
    #  ems_post is expecting.
    #------------------------------------------------------------------
    #
    s/primary/wrfout/g    for @groups;
    s/auxiliary/auxhist/g for @groups;

    
    
    #------------------------------------------------------------------
    #  Override the value to $Final{emspost} and return 1
    #------------------------------------------------------------------
    #
    $Final{emspost} = join ',', @groups;


return 1;
}


sub Final_emspost {
#==================================================================================
#  Complete the final configuration for the EMSPOST parameter, which is obtained
#  obtained from the --emspost, --auxhist, and --wrfout flags.  If the --autopost
#  flag was also passed then the value returned here will be replaced with 
#  the final value from Final_autopost.
#
#  PS - This routine is similar to Final_autopost.
#==================================================================================
#
    my $emspost  = $Oconf{flags}{emspost} ? $Oconf{flags}{emspost} : '';  # set to config file value
       $emspost  = '0:primary' if $emspost =~ /^auto/;                 #  '0:primary' is the default value


    my @rundoms = sort {$a <=> $b} keys %{$Upost{rtenv}{postdoms}};

    #-----------------------------------------------------------------------------
    #  Split the argument string into "groups" and then parse further to determine
    #  the domain and datasets to process. The rules for each domain specified
    #  are carried within a hash of arrays. If the user sets a default rule
    #  then that will be carried in the @{$rules{0}} array. If the $rules{0} 
    #  hash is not populated following this loop then ONLY those domains explicitly
    #  specified by --emspost will be processed. If the $rules{0}
    #  hash is populated following this loop then all domains will be processed
    #  with those not explicitly defined getting the @{$rules{0}} values.
    #  If the --afwa, --auxhist, or --wrfout flags are passed (which they should 
    #  not since --emspost is not for the command line, but just in case) then
    #  those define the default rules.  
    #
    #  The AFWA dataset is not working yet so ignore for now.
    #-----------------------------------------------------------------------------
    #
    my %rules = ();
    foreach my $group (split ',', $emspost) {
        my ($d,$p,$a) = (0,'','');;
        foreach (split ':', $group) {
            $d = $_ if /(\d)+/; $d+=0;
            $p = 1 if /^pri|^wrf/i;
            $a = 1 if /^aux/i;
        }
        next unless grep {/^$d$/} (0,@rundoms);  #  Skip domains not in simulation

        @{$rules{$d}} = () unless defined $rules{$d};
        push @{$rules{$d}}, 'primary'   if $p;
        push @{$rules{$d}}, 'auxiliary' if $a;
    }


    #------------------------------------------------------------------
    #  If the default rule option is turned ON make sure it has a 
    #  dataset value (primary). This would only happen if either
    #  the user included a '0' as a domain and failed to specify a 
    #  dataset.
    #------------------------------------------------------------------
    #
    @{$rules{0}} = ('primary') if defined $rules{0} and ! @{$rules{0}};

    push @{$rules{0}} => 'primary'   if $Oconf{flags}{wrfout};
    push @{$rules{0}} => 'auxiliary' if $Oconf{flags}{auxhist};
    push @{$rules{0}} => 'afwa'      if $Oconf{flags}{afwa};   # Should be 0 now.

    @{$rules{0}} = reverse sort &Others::rmdups(@{$rules{0}});


    #------------------------------------------------------------------
    #  Loop over all the run-time domains. Create the rule groups and 
    #  then write them to an array.
    #------------------------------------------------------------------
    #
    my @groups=();
    foreach my $d (sort {$a <=> $b} @rundoms) {

        next unless defined $rules{$d} or defined $rules{0};

        my @rg = (defined $rules{0}) ? @{$rules{0}} : ();
           @rg = @{$rules{$d}} if defined $rules{$d} and @{$rules{$d}};

        @{$rules{$d}} = reverse sort &Others::rmdups(@rg);
        @{$rules{$d}} = ('primary') unless @{$rules{$d}};  # Only necessary when neither default rule nor domain rule is defined

        push @groups, join ':', ($d,@{$rules{$d}});
    }


    #------------------------------------------------------------------
    #  The big switch - replace primary -> wrfout and 
    #  auxiliary -> auxhist in the array because that is what
    #  ems_post is expecting.
    #------------------------------------------------------------------
    #
    s/primary/wrfout/g    for @groups;
    s/auxiliary/auxhist/g for @groups;


return  @groups ? join ',', @groups : '';
}



sub Final_exports {
#==================================================================================
#  This routine takes any input from the --noexport  flag and determines which
#  entries in the post_export.conf file (if any) to use.
#==================================================================================
#
use List::Util qw( first min );

   my @final   = ();

   my @methods = qw(ftp sftp cp scp rsync);
   my @dsets   = qw(netcdf wrfout auxhist afwa grib grads gempak bufr bufkit gemsnd acisnd);

   my @exports = @{$Oconf{files}{EXPORT}};  return 0 unless @exports;
   my @noexpts = split /,/ => $Oconf{flags}{noexport};
   

   #  The first step is to clean up the EXPORT entries in the post_export.conf file
   #
   foreach my $exp (@exports) {

       chomp $exp;
       my @list = split '\|' => $exp;


       #---------------------------------------------------------
       #  Element 0 - DOMAIN
       #---------------------------------------------------------
       #
       $list[0] = 0 unless $list[0];
       unshift @list, 0 unless &Others::isInteger($list[0]);
       $list[0]+=0;

       #  Not a processed domain - skip
       #
       next if $list[0] and ! grep {/^$list[0]$/} keys %{$Upost{rtenv}{postdoms}};


       #---------------------------------------------------------
       #  Element 1 - FILE TYPE
       #---------------------------------------------------------
       #
       $list[1] = lc $list[1];
       my ($ds,$s) = split ':',$list[1],2;
       next unless $ds;

       for ($ds) {
           $_ = 'grib'    if /^grb|^gri/i;  #  Needed for GRIB 2 transition
           $_ = 'grads'   if /^gra|^grd/i;
           $_ = 'wrfout'  if /^wrf/i; 
           $_ = 'auxhist' if /^aux/i;
           $_ = 'afwa'    if /^afwa/i;
           $_ = 'netcdf'  if /^net/i;
           $_ = 'bufr'    if /^bufr/i;
           $_ = 'bufkit'  if /^bufk/i;
           $_ = 'gempak'  if /^gemp/i;
           $_ = 'gemsnd'  if /^gems/i;
           $_ = 'acisnd'  if /^asc/i;
       }
       next unless grep {/^${ds}$/} @dsets;
       next if grep {/^${ds}$/}     @noexpts;  #  Eliminate dataset types passed to --noexport

       if (grep {/^${ds}$/} ('wrfout','auxhist','afwa') ) {$list[2] = $ds; $ds = 'netcdf';}

       $list[1] = $s ? "$ds:s" : $ds;


       #---------------------------------------------------------
       #  Element 2 - KEY 
       #
       #  IF a "KEY" was not specified for datasets "netcdf",
       #  "grib", "gempak", or "grads", then assume the user
       #  wants both wrfout and auxhist exported.
       #---------------------------------------------------------
       #
       $list[2] = ''  unless $list[2];

       my @keys = (' ');  #  Default for BUFR or BUFR-derived file type

       if (grep {/^${ds}$/} ('netcdf','grib','gempak','grads') ) {
           $list[2] = 0 unless $list[2];  #  The Perl "first" command does not like an empty string
           my $key = first {/^$list[2]/} ('wrfout','auxhist');
           @keys = $key ? ($key) : ('wrfout','auxhist');
       }


       #---------------------------------------------------------
       #  Element 3 - METHOD
       #---------------------------------------------------------
       #
       $list[3] = lc $list[3];
       my $meth = $list[3];
       unless ($list[3] = first {/^$list[3]/} @methods) {
           $exp =~ s/\|/ | /g;
           my $meths = &Ecomm::JoinString(\@methods);
           my $mesg  = "The value for METHOD ($meth) in EXPORT entry:\n\n".
                       "X02XEXPORT = $exp\n\n".
                       "is not a valid export method ($meths). Skipping this export request.";
           &Ecomm::PrintMessage(6,11+$Upost{arf},255,1,2,$mesg) unless $Upost{emsenv}{mc};
           next;
       }

       #--------------------------------------------------------
       #  Yes, these are supposed to be out of order
       #--------------------------------------------------------
       #

       #---------------------------------------------------------
       #  Element 5 - USER@HOSTNAME 
       #---------------------------------------------------------
       #
       #  Provide error if USER@HOSTNAME is missing unless method = copy 
       #
       $list[5] = lc $list[5];
       $list[5] = 'localhost' if $list[3] eq 'cp';
       $list[5] = 'localhost' if $list[3] eq 'rsync' and !$list[5];
       $list[5] = 'localhost' if $list[3] eq 'scp'   and !$list[5];
       unless ($list[5]) {
           $exp =~ s/\|/ | /g;
           my $mesg = "Use of the $list[3] method in EXPORT requires \'[USER@]HOSTNAME\' entry ".
                      "in field six:\n\n".
                      "X02XEXPORT = $exp\n\n".
                      "Skipping this export request.";
           &Ecomm::PrintMessage(6,11+$Upost{arf},255,1,2,$mesg) unless $Upost{emsenv}{mc};
           next;
       }


       #---------------------------------------------------------
       #  Element 6 - LOCATION
       #---------------------------------------------------------
       #
       $list[6] =~ s/\s+//g;
       next unless $list[6];


       #--------------------------------------------------------
       #  Do the foreach @keys loop
       #--------------------------------------------------------
       #
       foreach my $key (@keys) {

           $list[2] = $key;


           #---------------------------------------------------------
           #  Element 4 - FREQ:START:STOP 
           #---------------------------------------------------------
           #
           #  Need to use the export dataset ($ds) to get the value 
           #  of the minimum frequency (FREQ)
           #
           $list[4] = 1 if grep {/^${ds}$/} ('bufr','bufkit','gemsnd','acisnd');

           my $fkey  = '';
              $fkey  = 'aux' if  $list[2] and $list[2] =~ /^aux/i;
              $fkey  = 'aux' if $ds eq 'auxhist';
              $fkey  = 'wrf' if  $list[2] and $list[2] =~ /^wrf/i;
              $fkey  = 'wrf' if $ds eq 'wrfout';

           my $freq = $fkey ? min @{$Upost{rtenv}{hist}{$fkey}} : min (@{$Upost{rtenv}{hist}{aux}}, @{$Upost{rtenv}{hist}{wrf}});

           $list[4] = &FinalFreqStartStop($list[4]||1,$freq);

      
           #---------------------------------------------------------
           #  Recreate the EXPORT string by joining with '|'
           #---------------------------------------------------------
           #
           push @final => (join '|' => @list);

        }
    }


return join ',' => @final;
}



sub FinalFreqStartStop {
#==================================================================================
#  Routine to ensure proper formatting of the FREQ:START:STOP string used by
#  various parameters. The input is a 'FREQ:START:STOP' string, with or without
#  FREQ, START, STOP, or ':', and the output file frequency for the data type
#  being processed. Output is a 'FREQ:START:STOP' string with each field populated
#  with (hopefully) correct values.
#==================================================================================
#
    my $length      = int ($Upost{rtenv}{length}/60);  # Convert to minutes
    my ($fse,$hint) = @_;  return '' unless defined $fse and length $fse;
    
    return "1:0:$hint" unless $hint;

    $fse =~ s/:|,|;|"|'/:/g;  #  Replace Separators with ":"
    $fse =~ s/[^\d|\:]//g;

    my ($freq,$start,$stop,@tmp) = split /:/ => $fse;

    $freq  = $hint unless $freq;
    $freq  = $hint unless &Others::isInteger($freq);
    $freq  = $hint unless $freq > 1;
    $freq  = $hint * int ($freq/$hint) if $hint;
    $freq  = $hint unless $freq > 0;
    $freq  = $length if $freq > $length;
    $freq+=0;

    $start = 0 unless $start;
    $start = 0 unless &Others::isInteger($start);
    $start = 0 unless $start > 0;
    $start = $hint * int ($start/$hint) if $hint;
    $start = 0 if $start > $length;
    $start+=0;

    $stop = $length unless $stop;
    $stop = $length unless &Others::isInteger($stop);
    $stop = $length unless $stop > 0 and $stop > $start;
    $stop = $hint * int ($stop/$hint) if $hint;
    $stop = $length unless $stop > 0 and $stop > $start; #  Yes, again
    $stop = $length if $stop > $length;
    $stop+=0;


return "$freq:$start:$stop";
}



sub Final_scntr {
#==================================================================================
#  Set the final value for the GRIB 2 sub-center value, generally recommended
#  to be 20+domain ID.
#==================================================================================
#   
    my $i=1;
    foreach (@{$Oconf{files}{SCNTR}}) {$_+=$i++ if $_ == 20;}


return join ',' => @{$Oconf{files}{SCNTR}};
}



sub Final_scour {
#==================================================================================
#  Set the final value for "scour", which is dependent upon the values of "noupp"
#  and "autopost".  If either one is ON (1) set scour = -1. Note the meaning of
#  the values from Ooptions.pm:
#
#      -1 - NO scour (anything)
#       0 - Normal scouring
#       1 - Full power scrub
#==================================================================================
#
    my $scour = $Oconf{flags}{scour};
       $scour = -1 if $Final{noupp};
       $scour = -1 if $Final{autopost};

return $scour;
}


sub Final_gribcntrl {
#==================================================================================
#  Check whether the configuration files requested reside under the static
#  directory.
#==================================================================================
#
    my @pdoms = sort {$a <=> $b} keys %{$Upost{rtenv}{postdoms}};
    my $field = shift;

    my @a = defined $Oconf{files}{uc $field} ? @{$Oconf{files}{uc $field}} : ();

    my $n = 1; foreach (@a) {my $d = sprintf '%02d', $n++; s/WD/$d/g;}

    if ($Final{grib}) {
        my @m = ();
        foreach (@pdoms) {push @m => "X02X$a[$_-1]" unless -s $a[$_-1];}
        if (@m) {
            @m = &Others::rmdups(@m); $n = @m;
            push @m => "\nCompare the GRIB_CNTRL_WRF|AUX parameter in post_grib.conf with the files in static/.";
            my $mesg = join "\n",@m;
            $ENV{OMESG} = &Ecomm::TextFormat(0,0,255,0,0,sprintf("The Requested UEMS UPP Control %s Missing:", ($n==1) ? 'File is' : 'Files are'),$mesg);
            return ();
        }
    }


return join ',' => @a;
}


sub Final_stationlist {
#==================================================================================
#  Check whether the configuration files requested reside under the static
#  directory.
#==================================================================================
#
    my @pdoms = sort {$a <=> $b} keys %{$Upost{rtenv}{postdoms}};
    my $field = shift;
    
    my @a = defined $Oconf{files}{uc $field} ? @{$Oconf{files}{uc $field}} : ();

    my $n = 1; foreach (@a) {my $d = sprintf '%02d', $n++; s/WD/$d/g;}

    if ($Final{bufr}) {
        my @m = ();
        foreach (@pdoms) {push @m => "X02X$a[$_-1]" unless -s $a[$_-1];}
        if (@m) {
            @m = &Others::rmdups(@m); $n = @m;
            push @m => "\nCompare the STATION_LIST parameter in post_bufr.conf to the files in static/.";
            my $mesg = join "\n",@m;
            $ENV{OMESG} = &Ecomm::TextFormat(0,0,255,0,0,sprintf("The Requested BUFR Station List %s Missing:", ($n==1) ? 'File is' : 'Files are'),$mesg);
            return ();
        }
    }


return join ',' => @a;
}


sub Final_flagvalue {
#==================================================================================
#  This routine simply passes along the value from the flags hash for the 
#  passed variable. Values previously defined in &PostFlagConfiguration 
#  and do not need any additional modification.
#==================================================================================
#
    my $field = shift;

    my $a = (defined $Oconf{flags}{$field}) ?  $Oconf{flags}{$field} : '';


return $a;
}



sub Final_filevalue {
#==================================================================================
#  This routine simply passes along the value from the files hash for the passed
#  variable. These values previously were defined in &PostFileConfiguration and
#  do not need any additional modification.
#==================================================================================
#
    my $field = shift;

    my @a = defined $Oconf{files}{uc $field} ? @{$Oconf{files}{uc $field}} : ();


return join ',' => @a;
}



sub Final_script {
#==================================================================================
#  Similar to &Final_filevalue but checks whether the file exists before returning
#  the full path to the file or provide a message to the user if missing.
#==================================================================================
#
    my $field = shift;

    my @a = defined $Oconf{files}{uc $field} ? @{$Oconf{files}{uc $field}} : ();

    if (@a and ! -s $a[0]) {
        my $rout  = ($a[0] =~ /grads/i) ? 'GrADS' : 'GEMPAK';
        my $type  = ($a[0] =~ /grads/i) ? 'auxiliary' : 'wrfout';
        my $mesg = "\"BOOO\" - The script for processing $rout $type files is missing:\n\n".
                   "X02X$a[0]\n\n".
                   "This step will be skipped. Again, \"BOOO!\"";
        &Ecomm::PrintMessage(6,11+$Upost{arf},255,1,2,$mesg) unless $Upost{emsenv}{mc};
        @a = ();
    }

     
return @a ? join ',' => @a : 0;
}


sub Final_gempaklibs {
#==================================================================================
#  This subroutine checks whether all required libraries for converting GRIB2
#  files into gempak format exist on the local system.  If not, then a comma
#  separated list containing the missing libraries is returned; otherwise
#  an empty list is returned.
#==================================================================================
#
    my @a = ();

    #  The list of routines to be checked
    #
    my $upath    = "$ENV{EMS_UTIL}/nawips/os/linux/bin";
    my @routines = qw(dcgrib2);

    $_ = "$upath/$_" foreach @routines;


    #  First check whether the package is installed
    #
    foreach my $routine (@routines) {
        push @a => "Missing routine: $routine" unless -s $routine;
    }
    return join ',' => @a if @a;

    #  Now check whether the subroutines exist
    #
    @a = &Others::MissingLibraryCheck(@routines);


return @a ? join ',' => @a : '';
}



sub Final_bufkitlibs {
#==================================================================================
#  This subroutine checks whether all required libraries for converting GRIB2
#  files into gempak format exist on the local system.  If not, then a comma
#  separated list containing the missing libraries is returned; otherwise
#  an empty list is returned.
#==================================================================================
#
    my @a = ();

    #  The list of routines to be checked
    #
    my $upath    = "$ENV{EMS_UTIL}/nawips/os/linux/bin";
    my @routines = qw(namsnd snlist sflist sfcfil sfedit);

    $_ = "$upath/$_" foreach @routines;


    #  First check whether the package is installed
    #
    foreach my $routine (@routines) {
        push @a => "Missing $routine" unless -s $routine;
    }
    return join ',' => @a if @a;


    #  Now check whether the subroutines exist
    #
    @a = &Others::MissingLibraryCheck(@routines);


return @a ? join ',' => @a : ''; 
}


sub Final_gradslibs {
#==================================================================================
#  This subroutine checks whether all required libraries for converting GRIB2
#  files into gempak format exist on the local system.  If not, then a comma
#  separated list containing the missing libraries is returned; otherwise
#  an empty list is returned.
#==================================================================================
#
    my @a = ();

    #  The list of routines to be checked
    #
    my $upath    = "$ENV{EMS_UTIL}/grads/bin";
    my @routines = qw(grads gribmap g2ctl.pl);

    $_ = "$upath/$_" foreach @routines;


    #  First check whether the package is installed
    #
    foreach my $routine (@routines) {
        next if -s $routine;
        next if $routine =~ /g2ctl/;
        push @a => "Missing $routine";
    }
    return join ',' => @a if @a;


    #  Now check whether the subroutines exist
    #
    @a = &Others::MissingLibraryCheck(@routines);


return @a ? join ',' => @a : '';
}



sub FinalDebugInformation {
#==================================================================================
#  Debug information if the --debug <value> is greater than 0
#==================================================================================
#
    my $href = shift; my %Final = %{$href};

    &Ecomm::PrintMessage(0,9,94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,11,255,1,2,'&PostFinalConfiguration - Final ems_post configuration values:');
    &Ecomm::PrintMessage(0,16,255,0,1,sprintf('--%-10s = %s',$_,$Final{$_})) foreach sort keys %Final;
    &Ecomm::PrintMessage(0,9,94,0,2,'=' x 72);

return;
}



