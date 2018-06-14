#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Afinal.pm
#
#  DESCRIPTION:  Afinal contains each of the primary routines used for the
#                final configuration of ems_autorun. It's the least elegant 
#                of the ems_autorun modules simply because there is a lot of
#                sausage making going on.
#
#                A lot of sausage making
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Afinal;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Final %Aconf %Uauto $slength);


sub AutoFinalConfiguration {
#==================================================================================
#  The &AutoFinalConfiguration routine merges the final configuration file values
#  with any command line flags that were passed. The resulting returned hash 
#  will be used throughout ems_autorun as the final word on what & how things get
#  done.  Note that the order of subroutine calls is important because some values
#  must be set before others can be defined.
#  
#  Not all variables need to be merged since some file parameters do not have
#  a command line override flag.  Finally, only parameters needed after this
#  routine are passed out. The others are left to fend for themselves.
#==================================================================================
#
    $slength    = 0;  #  Global variable used throughout module

    my $upref = shift; %Uauto = %{$upref};
    my $cpref = shift; %Aconf = %{$cpref};
     

    #=================== The important parameters =================================
    #  First things first - Note that the order of configuration is important
    #  as some parameters are needed in the configuration of others.  Any 
    #  information that needs to be saved is held in the %Final hash, which
    #  is global within this module.
    #==============================================================================
    #
    %Final = ();


    #=================== The simple parameters ===================================
    #  These post configuration file parameters do not need any additional
    #  checks or configuration and just needs to be passed along to the 
    #  %Final hash.
    #==============================================================================
    #
    $Final{users}    =  &Final_filevalue('users');
    $Final{wait}     =  &Final_filevalue('wait');
    $Final{sleep}    =  &Final_filevalue('sleep');
    $Final{attempts} =  &Final_filevalue('attempts');


    $Final{rundir}   =  &Final_flagvalue('rundir');
    $Final{debug}    =  &Final_flagvalue('debug');
    $Final{nolock}   =  &Final_flagvalue('nolock');

    #===================== The general parameters =================================
    #  Actually, all the parameters are important, although some more than
    #  others. Below are those parameters that are not domain specific, i.e.,
    #  are either applied to all the domains being processed or just used for 
    #  running ems_autorun.
    #==============================================================================
    # 
    $Final{rdate}    =  &Final_rdate();    return () if $ENV{AMESG};
    $Final{length}   =  &Final_length();   return () if $ENV{AMESG};
    $Final{rcycle}   =  &Final_rcycle();   return () if $ENV{AMESG};
    $Final{domains}  =  &Final_domains();  return () if $ENV{AMESG};
    $Final{dsets}    =  &Final_dsets();    return () if $ENV{AMESG};
    $Final{sfcs}     =  &Final_sfcs();     return () if $ENV{AMESG};
    $Final{lsms}     =  &Final_lsms();     return () if $ENV{AMESG};

    $Final{syncsfc}  =  &Final_syncsfc();  return () if $ENV{AMESG};
    $Final{aerosols} =  &Final_aerosols(); return () if $ENV{AMESG};
    
    $Final{emspost}  =  &Final_emspost();  return () if $ENV{AMESG};
    $Final{autopost} =  &Final_autopost(); return () if $ENV{AMESG};
    $Final{mergpost} =  &Final_mergpost(); return () if $ENV{AMESG};

    $Final{ahost}    =  &Final_ahost();    return () if $ENV{AMESG};

    $Final{nudging}  =  &Final_nudging();  return () if $ENV{AMESG};
    $Final{scour}    =  &Final_scour();    return () if $ENV{AMESG};


    #==============================================================================
    #  The following are used when running UEMS_MissionControl.pl for polulating
    #  the fields to be sent to the server.
    #==============================================================================
    #
    $Final{sfc}   =  $Final{sfcs};
    $Final{lsm}   =  $Final{lsms};


    #==============================================================================
    #  Create additional variables that will hold the arguments to be passed
    #  to --domains for ems_prep and ems_run.
    #==============================================================================
    #
    $Final{pdomains} =  &Final_pdomains();  return () if $ENV{AMESG};
    $Final{rdomains} =  &Final_rdomains();  return () if $ENV{AMESG};


    #==============================================================================
    #  Debug information if the --debug <value> is greater than 0
    #==============================================================================
    #
    &FinalDebugInformation(\%Final) if $Final{debug} > 0;


return %Final;  
}



sub Final_scour {
#==================================================================================
#  Set the final value for "scour". 
#
#       3 - Normal scouring
#       4 - Full power scrub
#==================================================================================
#
    my $scour = $Aconf{files}{scour} ? 4 : 3;
       $scour = $Aconf{flags}{scour} if $Aconf{flags}{scour}; #  values: 0, 3, or 4

return $scour;
}



sub Final_nudging {
#==================================================================================
#  Set the final value for "nudging".  
#
#  Final values:
#
#       0 - Nudging OFF
#       1 - Nudging On
#==================================================================================
#
    my $nudging = $Aconf{files}{nudging} ? 1 : 0;
       $nudging = 1 if $Aconf{flags}{nudging} > 0;
       $nudging = 0 if $Aconf{flags}{nudging} < 0;

return $nudging;
}



sub Final_rcycle {
#==================================================================================
#  Refine the argument passed to --cycle from input collected.  The format of
#  argument is "CYCLE:INITFH:FINLFH:FREQFH". This configuration is a bit messy
#  for multiple reasons and has been simplified from previous UEMS releases but 
#  a few bugs are sure to still exist. 
#
#  The order of precedence for the simulation length should be:
#
#        --length (flag) > --cycle (FINLFH-INITFH) > conf file (LENGTH),
#
#  but the configuration file and flag value have already been merged so 
#  $Aconf{flags}{length} must be used again.
#==================================================================================
#
    my $mesg  = qw{};
    my $rcycle = $Aconf{flags}{rcycle};
       $rcycle = '06:00:30:06' if $Uauto{rtenv}{bench};
       $rcycle = $Aconf{files}{rcycle} if defined $Aconf{files}{rcycle} and $Aconf{files}{rcycle};

    return '' unless length $rcycle;

    #------------------------------------------------------------------------------
    #  Check whether any placeholder values beyond CYCLE have been redefined by 
    #  the user. A simple integer check should work.
    #------------------------------------------------------------------------------
    #
    my ($vcycle, $vinitfh, $vfinlfh, $vfreqfh) = split /:/ => $rcycle;


    #------------------------------------------------------------------------------
    #  Return the values passed to --cycle to an unpadded integer format.
    #
    #  vinitfh - initial forecast hour
    #  vfinlfh - final   forecast hour
    #  vfreqfh - BC update frequency
    #------------------------------------------------------------------------------
    #
    foreach ($vcycle, $vinitfh, $vfinlfh, $vfreqfh) {$_ = (defined $_ and &Others::isInteger($_)) ? $_+=0 : '';}

    
    #------------------------------------------------------------------------------
    #  Make sure the value of CYCLE is reasonable (0 through 23).
    #------------------------------------------------------------------------------
    #
    if (length $vcycle and ! grep {/^$vcycle$/} (0..23) ) {
        my $mesg = "The value of the cycle time passed as an argument to the \"--cycle\" flag must be an integer ".
                   "value between 0 and 23 that represents an hour of the day. Maybe you were napping during ".
                   "\"Tell'n Time with Flavor Flav\" in kindergarten, but \"$vcycle\" does not work.";
        $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,2,'Time is not on your side',$mesg);
        return 0;
    }
    $vcycle = length $vcycle ? sprintf("%02d", $vcycle) : '';

    

    #------------------------------------------------------------------------------
    #  Allow INITFH and FINLFH to have non-placeholder values only if BOTH have
    #  realistic integer values.
    #------------------------------------------------------------------------------
    #
    if ($vfinlfh and !length $vinitfh) {
        my $mesg = "When including a value for FINLFH in the argument passed to \"--cycle\",\n\n".
                   "X02X%  ems_autorun --cycle [CYCLE]:[INITFH]:[FINLFH]:[FREQFH],\n\n".
                   "you must also include a value for the initial forecast hour (INITFH). These values will ".
                   "be used to override the length of the simulation setting in the configuration file, ".
                   "just because you are asking for it.\n\n".
                   "See \"ems_autorun --help cycle\" for more gory details.";
        $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,2,'FINLFH & INITFH are a couple, just like Ernie & Bert',$mesg);
        return 0;
    }
   
    
    #------------------------------------------------------------------------------
    #  Use everything available to define the length of the simulation. Note
    #  that the --length flag overrides all. The $Final{length} variable 
    #  contains the length value specified in the configuration file or 
    #  from the --length flag. The --length flag takes priority over all
    #  other options.
    #------------------------------------------------------------------------------
    #

    #  Set the default value for the simulation length
    #
    my $vlength = 0;  #  Initialize $vlength

    #  If passed INITFH & FINLFH - use values unless the--length flag was passed
    #
    $vinitfh = '' unless length $vinitfh and $vinitfh >=0; 
    $vfinlfh = '' unless $vfinlfh and $vfinlfh > $vinitfh;
    $vfinlfh = '' if $Aconf{flags}{length};
    
    $vlength = $vfinlfh-$vinitfh if $vfinlfh and length $vinitfh; # $vinitfh may be 0
    $Final{length} = 0 if $vlength;  #  Needs to be done
       
     
    $vfreqfh = &Final_bcfreq($vfreqfh); return 0 if $ENV{AMESG};

    $vinitfh =  sprintf("%02d", $vinitfh) if length $vinitfh;
    $vfinlfh =  sprintf("%02d", $vfinlfh) if length $vfinlfh;
    $vfreqfh =  sprintf("%02d", $vfreqfh) if length $vfreqfh;

    $slength = $vlength ? $vlength : $Final{length};

    if ($vfreqfh and $slength%$vfreqfh) { #  Forecast length not an integer multiple
        my $mesg = "The length of the primary domain simulation must by an integer multiple of the boundary ".
                   "condition update frequency. You have specified an update frequency of $vfreqfh hours, ".
                   "but a simulation length of $slength hours.  What were thinking?\n\n".
                   "That's a rhetorical question.\n\n".
                   "You will have to figure what is wrong with the configuration and try again. I'm getting too ".
                   "old and lazy (mostly lazy) to read your mind all the time.\n\n".
                   "I can actually read it some of the time, and I know what your thinking right now.";
         $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,0,"The UEMS resident clairvoyant is out to lunch (again):",$mesg);
         return;
    }


    if ($vinitfh and $vfreqfh and $vinitfh%$vfreqfh) { #  Forecast length not an integer multiple
        my $mesg = "The initialization forecast hour ($vinitfh), must by an integer multiple of the boundary ".
                   "condition update freqency. You have specified an update frequency of $vfreqfh hours, ".
                   "but an initialization hour of $vinitfh.  What were thinking?\n\n".
                   "That's a rhetorical question.\n\n".
                   "You will have to figure what is wrong with the configuration and try again. I'm getting too ".
                   "old and lazy (mostly lazy) to read your mind all the time.\n\n".
                   "I can actually read it some of the time, and I know what your thinking right now.";
         $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,0,"The UEMS resident clairvoyant is out to lunch (again):",$mesg);
         return;
    }

    ($rcycle = "$vcycle:$vinitfh:$vfinlfh:$vfreqfh") =~ s/:+$//g;
    

return $rcycle;
}


sub Final_rdate {
#==================================================================================
#  Define the initialization date to be used for the simulation. If the user
#  passed the --date flag then check whether the YYYYMMDD value is not in the 
#  future. If no --date flag was passed, then set to 0 and ems_prep will use
#  the current UTC date.
#
#  Note that for UEMS_MissionControl.pl, if rdate is populated in the 
#  server side configuration file then that value overrides all other values.
#==================================================================================
#
    my $mesg  = qw{};
    my $rdate = $Aconf{flags}{rdate};
       $rdate = '20110427' if $Uauto{rtenv}{bench};
       $rdate = $Aconf{files}{rdate} if defined $Aconf{files}{rdate} and $Aconf{files}{rdate};

    return 0 unless $rdate;


    if ($rdate > $Uauto{emsenv}{yyyymmdd}) {
        $mesg = "The date you requested \"--date $rdate\", appears to be in the future, which is not ".
                "allowed under current space-time physics rules (go look it up). Thus, you will have ".
                "to do it again, and do it correctly this time.";
        $ENV{AMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Einstein would be disappointed in you!',$mesg);
        return;
    }

    #  Test for an incorrect date from the Perl Time utility
    #
    my $sdate = "${rdate}00";
    my $tdate = substr(&Others::CalculateNewDate($sdate,0),0,10);

    if ($tdate > $sdate) {
        $mesg = "The Perl time module is returning an invalid date/time. This problem usually ".
                "occurs when the initialization date of your simulation is more than 50 years older ".
                "than the current system date.  To fix the problem you can either temporarily modify ".
                "the Perl library or reset your system clock but I can't allow you to dig ".
                "a deeper hole until you remedy this situation.";
        $ENV{AMESG} = &Ecomm::TextFormat(0,0,88,0,0,"Simulation Start Date ($rdate) and Perl - A Match Not Made in UEMS HQ!",$mesg);
        return;
    }

return $rdate;
}






sub Final_bcfreq {
#==================================================================================
#  BCFREQ is the frequency (hours) of data files used to update the lateral boundary
#  conditions. Typically, you will want to use the highest frequency available, which
#  is often 1- or 3-hourly, but it is up to you. Leaving BCFREQ blank will default to
#  the value specified in the corresponding DSET_gribinfo.conf file. The value of 
#  BCFREQ should be an integer multiple of the available initialization file frequency.
#  BCFREQ is set to 0 for global domains.
#==================================================================================
#
    my @bcfreqs = (0,1,3,6,12,24);

    my $bcfreq = shift; 
       return '' unless length $bcfreq;
       return '' if $Uauto{rtenv}{global};

    unless (&Others::isInteger($bcfreq)) {
        my $mesg = "The value of FREQFH included in the argument string to \"--cycle\" defines the ".
                   "boundary condition file update frequency in hours. You seem to have missed this ".
                   "bit of clearly documented information while you were dozing off because you have ".
                   "FREQFH = $bcfreq.\n\nRather than waking you from your slumber, the UEMS will use ".
                   "the default value defined in <DSET>_gribinfo.conf.";
        &Ecomm::PrintMessage(6,7,86,1,2,'Sweet Dreams, Zzzzz',$mesg);
        return '';
    }


    unless (grep {/^$bcfreq$/} @bcfreqs) {
        my $mesg = "The value of FREQFH included in the argument string to \"--cycle\" specifies the ".
                   "boundary condition file update frequency in hours and must also be an integer ".
                   "multiple of the available file times for the initialization dataset. Your value ".
                   "FREQFH = $bcfreq does not match any known file frequency. Perhaps you have discovered ".
                   "something new or made a mistake?";
        $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,2,"Where are you going with this?",$mesg);
        return '';
    }

         
return $bcfreq;
}



sub Final_initfh {
#==================================================================================
#  INITFH is the first forecast hour from the dataset specified in DSETS to use for
#  initializing your simulation (0-hour). Normally, this value would be 0 for the
#  DSET 0-hour forecast, but it's also possible to initialize a real-time forecast
#  from existing 6 hour forecast as well.  If you are using an analysis dataset for
#  DSETS such as ERA1 or CFSR then this value should be 0. If a non-zero value is used
#  then the specified value must correspond to a forecast hour file available from the
#  initialization dataset. If does not make sense to set INITFH = 4 when the available
#  forecast files are 3-hourly.
#==================================================================================
#
    my $initfh = shift; return '' unless length $initfh;

    unless (&Others::isInteger($initfh)) {
        my $mesg = "The value of INITFH in ems_autorun.conf is an integer that defines the initialization ".
                   "forecast file time from which to extract the initialization (0-hour) data for your ".
                   "simulation. However, you have chosen to use INITFH = $initfh, which appears to violate ".
                   "the laws of the UEMS.\n\n".
                   "Since the only violating allowed by the UEMS is your sense of humor, it is suggested ".
                   "that you revise your INITFH value to something less amusing.";

        $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,0,"Ha! The jokes on YOU!",$mesg);
        return '';
    }

return $initfh;
}



sub Final_length {
#==================================================================================
#  The Final_length routine finalizes the simulation length of the primary domain 
#==================================================================================
#
    my $default = 24;
    my $length  = $Aconf{files}{length}  ? $Aconf{files}{length} : $default;  # set to config file value
       $length  = $Aconf{flags}{length} if $Aconf{flags}{length};  # Override with --length flag input
       $length  = 30 if $Uauto{rtenv}{bench} and $length > 30;;
       $slength = $length;

return $length;
}



sub Final_domains {
#==================================================================================
#  The Final_domains manages the domains to include in the simulation.
#  along with the start & stop times. Note that the check for the inclusion
#  of parent domains occurs in ems_prep.
#==================================================================================
#
    my @list    = ();

    my $default = 1;
    my $domains = $Aconf{files}{domains}  ? $Aconf{files}{domains} : $default;  # set to config file value
       $domains = $Aconf{flags}{domains} if $Aconf{flags}{domains};  # Override with --domains flag input

    foreach my $domain (split ',', $domains) {
        $domain = &FinalDomainStartStop($domain);
        push @list, $domain if $domain;
    }

return join ',', sort @list;
}



sub Final_pdomains {
#==================================================================================
#  The Final_pdomains formats the argument to be passed to ems_prep via the
#  --domains flag. Unless a special start time is requested all that is needed
#  is a comma separated list of child domains.
#==================================================================================
#
    my @domains=();

    foreach my $domain (split ',',$Final{domains}) {
        my ($d,$s,$e) = split ':', $domain;
        next unless $d > 1;
        push @domains, $s ? "${d}:${s}" : $d;
    }

return @domains ? join ',', sort @domains : '';
}



sub Final_rdomains {
#==================================================================================
#  The Final_rdomains formats the argument to be passed to ems_run via the
#  --domains flag. Unless a special start time is requested all that is needed
#  is a comma separated list of child domains.  Note that is the simulation 
#  end is specified for a nested domain, it must have the hours unit (h) 
#  appended to the integer value.
#==================================================================================
#
    my @domains=();

    foreach my $domain (split ',',$Final{domains}) {
        my ($d,$s,$e) = split ':', $domain;
        next unless $d > 1;
        push @domains, ($e and $e != $slength) ? "${d}:${e}h" : $d;  
    }

return @domains ? join ',', sort @domains : '';
}



sub Final_dsets {
#==================================================================================
#  Define the final list of datasets to use for initializing the simulation.
#==================================================================================
#
    my $default = 'gfs';
    my $dslist  = $Aconf{files}{dsets}  ? $Aconf{files}{dsets} : $default;  # set to config file value
       $dslist  = $Aconf{flags}{rdset} if $Aconf{flags}{rdset};  # Override with --dsets flag input

       $dslist  = 'cfsr:none' if $Uauto{rtenv}{bench};


    #------------------------------------------------------------------------------
    #  Loop over the list of dataset entries separated by a comma. These dsets
    #  are in order of user preference and may include fail-over dsets.
    #------------------------------------------------------------------------------
    #
    my @fdsets = ();

    foreach my $rdset (split /,/ => $dslist) {

        my @dsets = split /%/ => $rdset;

        if (@dsets > 2) { 
            my $mesg = "You may specify a maximum of 2 different datasets, separated by '%', to serve ".
                       "as the initial and boundary conditions with the \"--dset\" option. So let's try ".
                       "it again.\n\nSee \"--help dset\" for more information.";
            $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,2,'Hey Trouble Maker!',$mesg);
            return '';
        }

        if (@dsets > 1 and ! $Final{length}) {
            my $mesg = "You must specify the forecast length, in hours, using the \"--length <hours>\" ".
                       "option when using different datasets for initial and boundary conditions.";
            $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,2,'Hello There!',$mesg);
            return '';
        }


        if (@dsets > 1 and $Uauto{rtenv}{global}) {
            my $udset= uc $dsets[0];
            my $mesg = "The last time I checked, a boundary condition dataset ($dsets[1]) is not needed ".
                       "when running over a global domain. The fact that you included one as an argument ".
                       "to \"--dset\" suggests you believe otherwise. I'll just save you the embarrassment ".
                       "of public humiliation and forget about this transgression while carrying on with just ".
                       "the $udset as if nothing ever happened.";
            &Ecomm::PrintMessage(6,7,94,1,2,'Move along, there is nothing to see here ...',$mesg);
            @dsets  = ($dsets[0]);
        }


        foreach (@dsets) {  #  Do not sort!

            my ($dset,$method,$server,$path) = split /:/ => $_, 4;

            foreach ($dset,$method,$server,$path) {$_ = '' unless $_;}

            unless ($dset) {
                my $mesg = "No dataset was specified for either DSET parameter in configuration file ".
                           "or --dset <dataset>[:<method>:<source>:<path>] flag";
                $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,2,'Disappearing dataset!',$mesg);
                return '';
            }

            unless (grep {/^${dset}_/} (@{$Uauto{rtenv}{ginfos}},'previous_')) {
                my $mesg = "The dataset that you are attempting to use ($dset) is not supported by the UEMS. The System ".
                       "Elders expect only perfection from you, so next time do a better job and make us proud; otherwise, ".
                       "we are going to lay a big guilt trip on you (again).\n\n".
                       "Here's a hint: Try using the \"--dslist\" flag to view a list of supported datasets.";
                $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,2,"You've come so far, yet have so far to go!",$mesg);
                return '';
            }


            $dset =~ s/pt$//g if $Uauto{rtenv}{global}; #  No personal tiles for global datasets

    
            if ( ($dset =~ /^cfsr/) and ($dset !~ /pt$/) ) {
                $dset = ($Final{rdate} and $Final{rdate} < 20110401) ? 'cfsrv1' : 'cfsrv2';
            }


            if ($method and $method !~ /ftp|http|nfs|none/i) {
                my $mesg = "Invalid acquisition method requested ($method). Only [no]ftp|[no]http|[no]nfs|none supported.";
                $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,2,'What method is this?',$mesg);
                return 0;
            }

            $_ = join ':' => ($dset,$method,$server,$path);
            $_ =~ s/(:+)$//g;
            
        }
        $rdset = join '%' => @dsets; push @fdsets, $rdset;


    }  # foreach my $rdset (split /,/ => $dslist)


return @fdsets ? join ',', @fdsets : '';
}



sub Final_sfcs {
#==================================================================================
#  Define the final list of datasets to use for initializing the simulation.
#==================================================================================
#
    my $default = '';
    my $dslist  = $Aconf{files}{sfc}  ? $Aconf{files}{sfc} : $default;  # set to config file value
       $dslist  = $Aconf{flags}{sfc} if $Aconf{flags}{sfc};  # Override with --dsets flag input

    return '' unless $dslist;
    return '' if $Uauto{rtenv}{bench};

    my @sfsets = split ',' => $dslist;

    #  Make sure the arguments are properly formatted
    #
    foreach (@sfsets) {

        my ($dset,$method,$server,$path) = split /:/ => $_, 4;

        foreach ($dset,$method,$server,$path) {$_ = '' unless $_;}

        unless ($dset) {
            my $mesg = "No dataset was specified for either DSET parameter in configuration file ".
                       "or --dset <dataset>[:<method>:<source>:<path>] flag";
            $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,2,'Disappearing dataset!',$mesg);
            return '';
        }

        unless (grep {/^${dset}_/} (@{$Uauto{rtenv}{ginfos}})) {
            my $mesg = "The static surface dataset that you are attempting to use ($dset) is not supported by the UEMS. The System ".
                       "Elders expect only perfection from you, so next time do a better job and make us proud; otherwise, ".
                       "we are going to lay a big guilt trip on you (again).\n\n".
                       "Here's a hint: Try using the \"--dslist\" flag to view a list of supported surface datasets.";
            $ENV{AMESG} = &Ecomm::TextFormat(0,0,84,0,2,"You've come so far, yet have so far to go!",$mesg);
            return '';
        }

        $dset =~ s/pt$//g  if $Uauto{rtenv}{global}; #  No personal tiles for global datasets


        if ($method and $method !~ /ftp|http|nfs|none/i) {
            my $mesg = "Invalid acquisition method requested ($method). Only [no]ftp|[no]http|[no]nfs|none supported.";
            $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,2,'What method is this?',$mesg);
            return '';
        }

        $_ = join ':' => ($dset,$method,$server,$path);
        $_ =~ s/(:+)$//g;

    }


return @sfsets ? join ',', @sfsets : '';
}



sub Final_lsms {
#==================================================================================
#  Define the final list of datasets to use for initializing the simulation.
#==================================================================================
#
    my $default = '';
    my $dslist  = $Aconf{files}{lsm}  ? $Aconf{files}{lsm} : $default;  # set to config file value
       $dslist  = $Aconf{flags}{lsm} if $Aconf{flags}{lsm};  # Override with --dsets flag input

    return '' unless $dslist;
    return '' if $Uauto{rtenv}{bench};

    my @lmsets = split ',' => $dslist;

    #  Make sure the arguments are properly formatted
    #
    foreach (@lmsets) {

        my ($dset,$method,$server,$path) = split /:/ => $_, 4;

        foreach ($dset,$method,$server,$path) {$_ = '' unless $_;}

        unless ($dset) {
            my $mesg = "No dataset was specified for either DSET parameter in configuration file ".
                       "or --dset <dataset>[:<method>:<source>:<path>] flag";
            $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,2,'Disappearing dataset!',$mesg);
            return '';
        }

        $dset =~ s/pt$//g  if $Uauto{rtenv}{global}; #  No personal tiles for global datasets

        unless (grep {/^${dset}_/} (@{$Uauto{rtenv}{ginfos}})) {
            my $mesg = "The land surface dataset that you are attempting to use ($dset) is not supported by the UEMS. The System ".
                       "Elders expect only perfection from you, so next time do a better job and make us proud; otherwise, ".
                       "we are going to lay a big guilt trip on you (again).\n\n".
                       "Here's a hint: Try using the \"--dslist\" flag to view a list of supported land surface datasets.";
            $ENV{AMESG} = &Ecomm::TextFormat(0,0,84,0,2,"You've come so far, yet have so far to go!",$mesg);
            return ''; 
        }

        if ($method and $method !~ /ftp|http|nfs|none/i) {
            my $mesg = "Invalid acquisition method requested ($method). Only [no]ftp|[no]http|[no]nfs|none supported.";
            $ENV{AMESG} = &Ecomm::TextFormat(0,0,86,0,2,'What method is this?',$mesg);
            return '';
        }

        $_ = join ':' => ($dset,$method,$server,$path);
        $_ =~ s/(:+)$//g;

    }


return @lmsets ? join ',', @lmsets : '';
}


sub Final_syncsfc {
#==================================================================================
#  syncsfc tells the UEMS to select the SFC data used for initialization such that
#  the validation hour is closest in time to the model initialization hour. When 
#  using syncsfc, the UEMS will ignore other available data times within a 24 hour
#  day in favor of a dataset that best matches the simulation initialization hour. 
#  The UEMS will look for datasets with the same validation hour going back over 
#  the period of N days as defined by the AGED parameter in the 
#  <dataset>_gribinfo.conf file.
#==================================================================================
#
    my $default = '';
    my $syncsfc = $Aconf{files}{syncsfc}  ? $Aconf{files}{syncsfc} : $default;  # set to config file value
       $syncsfc =~ s/ptiles|ptile/pt/g;

    return '' unless $syncsfc and $Final{sfcs};

    my @sfcs  = split ',', $Final{sfcs}; return '' unless @sfcs;
    my @syncs = split ',', $syncsfc;

    return '' unless @sfcs and @syncs;

    #  Eliminate datasets not included with $Final{sfcs}
    #
    my @list = ();
    foreach my $sync (@syncs) {
        unless (grep (/^$sync$/i, @sfcs))  {
            &Ecomm::PrintMessage(6,7,144,1,2,"Sync surface dataset \"SYNCSFC = $sync\" not requested with \"SFC\" - Skipped");
            next;
        }
        push @list => $sync;
    }


return @list ? join ',' => @list : '';
}



sub Final_aerosols {
#==================================================================================
#  Set AEROSOLS = Yes if you want want to include the WRF aerosol climatology as
#  part of the initialization because you are using the Thompson "Aerosol Aware" 
#  microphysics scheme (MP_PHYSICS = 28; ems_run) during the simulation. 
#  option is only with the Thompson AA scheme; however, if you set AEROSOLS = Yes 
#  but decide to use an alternate scheme, no harm will come to your simulation 
#  - this time.
#==================================================================================
#
    my $default  = 0;
    my $aerosols = $Aconf{files}{aerosols}  ? $Aconf{files}{aerosols} : $default;  # set to config file value

    return 0 unless defined $aerosols and $aerosols;

    #  Make sure a supported initialization dataset is being used
    #
    $aerosols = 0 unless $Final{dsets} =~ /gfs|era|awip/i;


return $aerosols;
}



sub Final_emspost {
#==================================================================================
#  Complete the final configuration for the EMSPOST parameter, which may be
#  obtained from the --emspost flag or the EMSPOST configuration file parameter.
#  The possible values from the configuration file parameter EMSPOST differs
#  from the --emspost flag. Specifically, the flag is used to override the
#  EMSPOST setting, including turning OFF all post-processing.
#==================================================================================
#
    my $emspost  = $Aconf{files}{emspost}  ? $Aconf{files}{emspost} : '';  # set to config file value
       $emspost  = $Aconf{flags}{emspost} if $Aconf{flags}{emspost};  #  $Aconf{flags}{emspost} = 0 for not passed
       $emspost  = '0:primary' if $emspost =~ /^auto/;  #  '0:primary' is the default value

    return '' unless $emspost;
    return '' if $emspost =~ /^off/;  # Turns off all post-processing
    
    
    my %domains = map {split(/:/, $_, 2) } split(/,/, $Final{domains});
    my @rundoms = sort {$a <=> $b} keys %domains;

    #----------------------------------------------------------------------------------
    #  Split the argument string into "groups" and then parse further to determine
    #  the domain and datasets to process. The rules for each domain specified
    #  are carried within a hash of arrays. If the user sets a default rule
    #  then that will be carried in the @{$rules{0}} array. If the $rules{0} 
    #  hash is not populated following this loop then ONLY those domains explicitly
    #  specified by EMSPOST or --emspost will be processed. If the $rules{0}
    #  hash is populated following this loop then all domains will be processed
    #  with those not explicitly defined getting the @{$rules{0}} values.
    #----------------------------------------------------------------------------------
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


    #  If the default rule option is turned ON make sure it has a dataset value
    #  (primary). This would only happen if either the user included a '0' as a
    #  domain and failed to specify a dataset.
    #
    @{$rules{0}} = ('primary') if defined $rules{0} and ! @{$rules{0}};

    #&Ecomm::PrintHash(\%rules);

    #  Loop over all the run-time domains. Create the rule groups and 
    #  then write them to an array.
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
        
return  @groups ? join ',', @groups : '';
}



sub Final_autopost {
#==================================================================================
#  Complete the final configuration for the AUTOPOST parameter, which may be
#  obtained from the --autopost flag or the AUTOPOST configuration file parameter.
#  The possible values from the configuration file parameter AUTOPOST differs
#  from the --autopost flag. Specifically, the flag is used to override the
#  AUTOPOST setting, including turning OFF all post-processing.
#==================================================================================
#
    my $autopost  = $Aconf{files}{autopost}  ? $Aconf{files}{autopost} : '';  # set to config file value
       $autopost  = $Aconf{flags}{autopost} if $Aconf{flags}{autopost};  #  $Aconf{flags}{autopost} = 0 for not passed
       $autopost  = '0:primary' if $autopost =~ /^auto/;                 #  '0:primary' is the default value

    return '' unless $autopost;
    return '' if $autopost =~ /^off/;  # Turns off all post-processing


    my %domains = map {split(/:/, $_, 2) } split(/,/, $Final{domains});
    my @rundoms = sort {$a <=> $b} keys %domains;


    #  Split the argument string into "groups" and then parse further to determine
    #  the domain and datasets to process. The rules for each domain specified
    #  are carried within a hash of arrays. If the user sets a default rule
    #  then that will be carried in the @{$rules{0}} array. If the $rules{0} 
    #  hash is not populated following this loop then ONLY those domains explicitly
    #  specified by AUTOPOST or --autopost will be processed. If the $rules{0}
    #  hash is populated following this loop then all domains will be processed
    #  with those not explicitly defined getting the @{$rules{0}} values.
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


    #  If the default rule option is turned ON make sure it has a dataset value
    #  (primary). This would only happen if either the user included a '0' as a
    #  domain and failed to specify a dataset.
    #
    @{$rules{0}} = ('primary') if defined $rules{0} and ! @{$rules{0}};


    #  Loop over all the run-time domains. Create the rule groups and 
    #  then write them to an array.
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


return  @groups ? join ',', @groups : '';
}


sub Final_mergpost {
#==================================================================================
#  Combine the emspost & autopost variables into mergpost variable that is 
#  used if the ems_autopost.pl fails, which it will.
#==================================================================================
#
    my %rules=();

    foreach my $post ($Final{emspost},$Final{autopost}) {

        next unless $post;

        foreach my $group (split ',', $post) {
            my ($d,$p,$a) = (0,'','');
            foreach (split ':', $group) {
                $d = $_ if /(\d)+/; $d+=0;
                $p = 1 if /^pri|^wrf/i;
                $a = 1 if /^aux/i;
            }
            @{$rules{$d}} = () unless defined $rules{$d};
            push @{$rules{$d}}, 'primary'   if $p;
            push @{$rules{$d}}, 'auxiliary' if $a;
        }
    }

    #  Loop over all the domains. Create the rule groups and 
    #  then write them to an array.
    #
    my @groups=();
    foreach my $d (sort {$a <=> $b} keys %rules) {
        @{$rules{$d}} = &Others::rmdups(@{$rules{$d}});
        push @groups, join ':', ($d,@{$rules{$d}});
    }

return @groups ? join ',', @groups : '';
}


sub Final_ahost {
#==================================================================================
#  Specify the name of the system on which to initiate ems_autopost.pl
#==================================================================================
#
    my $ahost  = $Aconf{files}{ahost}  ? $Aconf{files}{ahost} : '';
       $ahost  = '' unless $Final{autopost};
       $ahost  = 'localhost' if $Final{autopost} and ! $ahost;

return $ahost;
}


sub Final_flagvalue {
#==================================================================================
#  This routine simply passes along the value from the flags hash for the 
#  passed variable. Values previously defined in &PostFlagConfiguration 
#  and do not need any additional modification.
#==================================================================================
#
    my $field = shift;

    my $a = (defined $Aconf{flags}{$field}) ?  $Aconf{flags}{$field} : "$field not assigned!";

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

    my $a = (defined $Aconf{files}{$field}) ?  $Aconf{files}{$field} : "$field not assigned!";

return $a;
}



sub FinalDomainStartStop {
#==================================================================================
#  Routine to ensure proper formatting of the DOM:START:STOP string used by
#  the DOMAINS parameter and --domains flag. The input is a 'DOM:START:STOP'
#  string, with or without START & STOP, and the forecast length in hours.
#  Output is a 'DOM:START:STOP' string with each field populated with (hopefully) 
#  correct values.
#==================================================================================
#
    my $passed = shift;  return '' unless defined $passed and length $passed;

    #  The format of the argument is DOM:START:STOP but we need to
    #  account for the use of commas (,) and semicolons (;) as separators. 
    #
    my ($dom,$start,$stop) = (0) x 3;

    $passed =~ s/:|,|;|"|'/:/g;  #  Replace Separators with ":"
    $passed =~ s/[^\d|\:]//g;

    ($dom,$start,$stop) = split /:/ => $passed;

    return '' unless $dom;
    return '' if $dom =~ /^\D/;  $dom+=0;
    return '' unless grep {/^$dom$/} @{$Uauto{geodoms}};

    $start= 0 unless defined $start and $start;
    $start= 0 if $start =~ /^\D/i;

    if ($start >= $slength) {
        my $mesg = "The start hour for the domain $dom simulation (hour $start) is after the termination of the ".
                   "primary domain ($slength hour run). Consequently, domain $dom will not be included this ".
                   "simulation.";
        &Ecomm::PrintMessage(6,7,94,1,2,'Stopped Before Getting Started:',$mesg);
        return '';
    }
        
    $start= 0 if $start < 1;

    $stop = $slength unless defined $stop and $stop;
    $stop = $slength if $stop  =~ /^\D/;
    $stop = $slength if $stop > $slength or $stop  < 1;

    if ($start >= $stop) {
        my $mesg = "The start hour for the domain $dom simulation (hour $start) is after the scheduled ".
                   "termination of the run ($stop hour run). Consequently, domain $dom will not be ".
                   "included this simulation.";
        &Ecomm::PrintMessage(6,7,94,1,2,'Stopped Before Getting Started:',$mesg);
        return '';
    }


return "$dom:$start:$stop";
}



sub FinalDebugInformation {
#==============================================================================
#  Debug information if the --debug <value> is greater than 0
#==============================================================================
#
    my $href = shift; my %Final = %{$href};

    &Ecomm::PrintMessage(0,9,94,1,0,'=' x 72);
    &Ecomm::PrintMessage(4,9,255,1,2,'&AutoFinalConfiguration - Final ems_autorun configuration values:');
    &Ecomm::PrintMessage(0,16,255,0,1,sprintf('%-10s = %s',$_,$Final{$_})) foreach sort keys %Final;
    &Ecomm::PrintMessage(0,9,94,0,2,'=' x 72);

return;
}



sub AutoPostPreCheck {
#==================================================================================
#  Do an initial check of the ems_post and ems_autopost configuration to reduce
#  the likelihood of failure during post processing. To accomplish this task, the
#  configuration provided by ems_post.conf is tested for viability, especially in
#  regards to the existence of required files and tables.
#
#  The routine is similar to &PreparePostConfiguration in UEMS_MissionControl.pl
#==================================================================================
#
use List::Util qw( max );

use Ooptions;
use Ofiles;
use Oflags;
use Ofinal;



    my %Oconf = ();
    my %Upost = ();

    $ENV{OMESG}  = '';

    my $href = shift; my %Uauto = %{$href};

    $Upost{emsenv}{cwd}         = $Uauto{emsenv}{cwd};
    $Upost{emsenv}{autorun}     = $Uauto{emsenv}{autorun};

    $Upost{rtenv}{core}         = $Uauto{rtenv}{core};
    $Upost{rtenv}{static}       = $Uauto{rtenv}{static};
    $Upost{rtenv}{tables}{grib} = "$ENV{DATA_TBLS}/post/grib2";
    $Upost{rtenv}{tables}{bufr} = "$ENV{DATA_TBLS}/post/bufr";
    $Upost{rtenv}{dompath}      = $Uauto{rtenv}{dompath};
    $Upost{rtenv}{postconf}     = $Uauto{rtenv}{postconf};
    $Upost{rtenv}{length}       = $Uauto{parms}{length} * 3600;

    %{$Upost{rtenv}{postdoms}} = map {split ':', $_,2} split ',', $Uauto{parms}{mergpost};

    $Upost{maxdoms}   = max keys %{$Upost{rtenv}{postdoms}};
    $Upost{maxindex}  = $Upost{maxdoms}-1; #  Index of final domain information.


    #------------------------------------------------------------------------
    #  Some values are not going to be known until game time such as the 
    #  history inteval of the output files. (I'm too lazy to read the ems_run
    #  configuration files.) Thus, just make up some values and hope for the 
    #  best.
    #------------------------------------------------------------------------
    #
    foreach (0 .. $Upost{maxindex}) {
        $Upost{rtenv}{hist}{wrf}[$_] = 1;
        $Upost{rtenv}{hist}{aux}[$_] = 1;
    }


    #-------------------------------------------------------------------------------
    #  The returned Upost hash includes Upost{clflags} that contains the default
    #  ems_post flag values.
    #-------------------------------------------------------------------------------
    unless (%Upost = &Ooptions::PostOptions(\%Upost)) {
        $ENV{AMESG} = &Ecomm::TextFormat(0,2,88,0,2,'An error occurred during UEMS post configuration (1):',$ENV{OMESG});
        return ();
    }


    #-------------------------------------------------------------------------------
    #  Replace the default EMSPOST value with something reasonable. Also assign
    #  the run-time directory.
    #-------------------------------------------------------------------------------
    #
    $Upost{clflags}{EMSPOST} = $Uauto{parms}{mergpost};
    $Upost{clflags}{RUNDIR}  = $Uauto{rtenv}{dompath};

    unless (%{$Oconf{flags}} = &Oflags::PostFlagConfiguration(\%Upost)) {
        $ENV{AMESG} = &Ecomm::TextFormat(0,2,88,0,2,'An error occurred during UEMS post configuration (2):',$ENV{OMESG});
        return ();
    }

    
    #-------------------------------------------------------------------------------
    #  Read and check the configuration files values
    #-------------------------------------------------------------------------------
    #
    unless (%{$Oconf{files}} = &Ofiles::PostFileConfiguration(\%Upost)) {
        $ENV{AMESG} = &Ecomm::TextFormat(0,2,88,0,2,'An error occurred during UEMS post configuration (3):',$ENV{OMESG});
        return ();
    }


    #-------------------------------------------------------------------------------
    #  Complete the final configuration
    #-------------------------------------------------------------------------------
    #
    unless (%{$Upost{parms}} = &Ofinal::PostFinalConfiguration(\%Upost,\%Oconf)) {
        $ENV{AMESG} = &Ecomm::TextFormat(0,2,88,0,2,'An error occurred during UEMS post configuration (4):',$ENV{OMESG});
        return ();
    }


return %Uauto;
}


