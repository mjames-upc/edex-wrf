#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Pfinal.pm
#
#  DESCRIPTION:  Pfinal contains each of the primary routines used for the
#                final configuration of ems_prep. It's the least elegant of
#                the ems_prep modules simply because there is a lot of sausage
#                making going on.
#
#                A lot of sausage making
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Pfinal;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Final %Uprep);


sub PrepFinalConfiguration {
#==================================================================================
#  The PrepFinalConfiguration calls each of the final configuration subroutines. The use
#  of individual routines is not really necessary since both the %Uprep and
#  %Final hashes are global but serves to compartmentalize a block of code for each 
#  variable thus making it easier for future development. Note the change from
#  upper to lower case hash keys.
#==================================================================================
#
    my $upref = shift; %Uprep = %{$upref};


    #  ----------------- Attempt the configuration --------------------------------
    #  The variables below do not require any additional configuration beyond
    #  what was completed in the options module. Should a variable need additional 
    #  attention in the future a routine can be added.
    #
    $Final{bm}           =  &Final_value('BM');
    $Final{debug}        =  &Final_value('DEBUG');
    $Final{analysis}     =  &Final_value('ANALYSIS');
    $Final{nudging}      =  &Final_value('NUDGING');
    $Final{nodelay}      =  &Final_value('NODELAY');
    $Final{previous}     =  &Final_value('PREVIOUS');
    $Final{rcycle}       =  &Final_value('RCYCLE');
    $Final{rdate}        =  &Final_value('RDATE');
    $Final{bndyrows}     =  &Final_value('BNDYROWS');
    $Final{nointdel}     =  &Final_value('NOINTDEL');
    $Final{noprocess}    =  &Final_value('NOPROCESS');
    $Final{hiresbc}      =  &Final_value('HIRESBC');
    $Final{length}       =  &Final_value('FLENGTH');
    $Final{scour}        =  &Final_value('SCOUR');
    $Final{syncsfc}      =  &Final_value('SYNCSFC');
    $Final{aerosols}     =  &Final_value('AEROSOLS');
    $Final{sleep}        =  &Final_value('SLEEP');
    $Final{attempts}     =  &Final_value('ATTEMPTS');

    #  The following require some additional configuration
    # 
    $Final{global}       =  &Final_global();
    $Final{timeout}      =  &Final_timeout();
    $Final{lcore}        =  &Final_lcore();
    $Final{ucore}        =  &Final_ucore();
    $Final{ncpus}        =  &Final_ncpus();
    $Final{modis}        =  &Final_modis();
    @{$Final{dsets}}     =  &Final_dsets();
    %{$Final{domains}}   =  &Final_domains();
    %{$Final{parents}}   =  &Final_parents();
    @{$Final{reqdoms}}   =  &Final_reqdoms();

    @{$Final{sfcs}}      =  &Final_sfcs();     
    @{$Final{lsms}}      =  &Final_lsms();

    $Final{noaltsst}     =  &Final_noaltsst();

 
return %Final;  
}


sub Final_domains {
#==================================================================================
#  Final configuration for the primary and any nested domains to be included in
#  the simulation, which is a hash containing each domain and start time.
#==================================================================================
#
use List::Util 'max';

    my @parents = @{$Uprep{masternl}{GEOGRID}{parent_id}};  #  Just to keep things cleaner

    my %domains    = ();
       $domains{1} = 0;

    #------------------------------------------------------------------------------
    #  First thing to do is include and parent domains that were missing from the 
    #  command line arguments.
    #------------------------------------------------------------------------------
    #
    foreach (reverse split /,|;/ => $Uprep{OPTIONS}{DOMAIN}) {
        my ($domain, $start) = split /:/ => $_, 2;

        $domains{$domain} = $start;

        while ($domain != 1) {
           $domain = $parents[$domain-1];
           $domains{$domain} = 0;
        }
    }


    #------------------------------------------------------------------------------
    #  Now loop through from 1 .. last domain and ensure consistent start times.
    #  A child domain must have the same start time as its parent.
    #------------------------------------------------------------------------------
    #
    foreach my $d (sort {$a <=> $b} keys %domains) {
        $domains{$d} = $domains{$d} ? $domains{$d} : $domains{$parents[$d-1]};
    }


return %domains;
}



sub Final_parents {
#==================================================================================
#  This is a bit sloppy as the only reason this subroutine is necessary is to 
#  create a hash that can be used by the &PrepFormatSummary routine to print
#  information regarding the parent domains. 
#
#  Returns a %parents hash where $parent{domain ID} = parent ID
#==================================================================================
#
    my @parentids  = @{$Uprep{masternl}{GEOGRID}{parent_id}};

    my %parents    = ();
       $parents{1} = 0;

    foreach my $d (sort {$a <=> $b} keys %{$Final{domains}}) {
        $parents{$d} = $parentids[$d-1];
    }

return %parents;
}



sub Final_dsets {
#==================================================================================
#  The final configuration for the list of initialization datasets.
#==================================================================================
#
     my @dsets = split /%/ => $Uprep{OPTIONS}{RDSET};

return @dsets;
}


sub Final_global {
#==================================================================================
#  Final configuration for the GLOBAL variable
#==================================================================================
#
    my $conf = $Uprep{masternl}{global};

return $conf;
}


sub Final_lcore {
#==================================================================================
#  Final configuration for the GLOBAL variable
#==================================================================================
#
    my $conf = lc $Uprep{rtenv}{core};

return $conf;
}


sub Final_lsms {
#==================================================================================
#  The final configuration for the land surface model datasets
#==================================================================================
#
     my @dsets = ();

     return @dsets unless $Uprep{OPTIONS}{LSMS};

     my @list = split /,/ => $Uprep{OPTIONS}{LSMS};
     push @dsets => join '|' => @list;

return @dsets;
}


sub Final_modis {
#==================================================================================
#  Final configuration for the GLOBAL variable
#==================================================================================
#
    my $conf = $Uprep{rtenv}{modis};

return $conf;
}


sub Final_ncpus {
#==================================================================================
#  Final configuration for the NCPUS variable.  There are some issues that
#  need to be resolved, specifically:
#
#    1.  Is the value of OMP_NUM_THREADS (SOCKETS * CORES) as defined in the
#        EMS.cshrc|profile file, greater then the total number of cpus identified
#        on the machine (total_cores). If so then set maxcpus = total_cores.
#
#    2.  was the --ncpus flag passed?  If yes then check against maxcpus value.
#==================================================================================
#
    my $maxcpus = 0;
       $maxcpus = $ENV{OMP_NUM_THREADS} if defined $ENV{OMP_NUM_THREADS} and $ENV{OMP_NUM_THREADS} > 0;
       $maxcpus = $Uprep{emsenv}{sysinfo}{total_cores} if defined $Uprep{emsenv}{sysinfo}{total_cores} and $Uprep{emsenv}{sysinfo}{total_cores} > 0;

       if ($Uprep{OPTIONS}{NCPUS} > $maxcpus) {
           my $mesg = "Setting NCPUS to $maxcpus, because that's all the processors you have on this system.";
           &Ecomm::PrintMessage(6,6+$Uprep{arf},114,1,1,"I'm Givin' Her All She's Got, Captain!",$mesg);
       }

       $maxcpus = $Uprep{OPTIONS}{NCPUS} if $Uprep{OPTIONS}{NCPUS} and $Uprep{OPTIONS}{NCPUS} < $maxcpus;
       $maxcpus = 1 unless $maxcpus > 0;

return $maxcpus;
}


sub Final_noaltsst {
#==================================================================================
#  The final configuration for the noaltsst option. Basically, the flag is
#  turned ON (no alternat water temperatures) if the simulation length is less
#  than 24 hours, is a global domain, multiple initialization datasets being used,
#  or the domain was localized without the inland lakes.
#==================================================================================
#
    my $noaltsst = ($Final{length} < 24)     ? 1 :
                   ($Final{global})          ? 1 :
                   (! $Uprep{rtenv}{islake}) ? 1 :
                   (@{$Final{dsets}} > 1)    ? 1 : $Uprep{OPTIONS}{NOALTSST};

return $noaltsst;
}


sub Final_reqdoms {
#==================================================================================
#  From all the domains configured with this localization, create an array
#  containing only those used in this simulation.
#==================================================================================
#
    my @reqdoms = ();

    foreach (sort {$a <=> $b} keys %{$Final{domains}}) {push @reqdoms => $_ if $Final{domains}{$_} >= 0;}

return @reqdoms;
}


sub Final_sfcs {
#==================================================================================
#  The final configuration for static surface & sst datasets
#==================================================================================
#
     my @dsets = (); 

     return @dsets unless $Uprep{OPTIONS}{SFCS};

     my @list = split /,/ => $Uprep{OPTIONS}{SFCS};
     push @dsets => join '|' => @list;

return @dsets;
}


sub Final_timeout {
#==================================================================================
#  set the MPI timeout value for metgrid.  The default value is 1199 seconds and
#  a value of 0 turns this option OFF. If the option is not passed then assign 
#  -1, in which case defer to the global file value.
#
#  Again:  --timeout not passed   -  set timeout = -1  (defer to config file)
#          --timeout 0            -  set timeout = 0 (turn off)
#          --timeout              -  set timeout = 0 (turn off)
#          --timeout <value>      -  set timeout = <value> (override config file)
#==================================================================================
#
    my $conf = ($Uprep{OPTIONS}{TIMEOUT} < 0) ? $Uprep{pconf}{TIMEOUT} 
                                              : $Uprep{OPTIONS}{TIMEOUT};
       $conf = 0 unless $conf;

return $conf;
}


sub Final_ucore {
#==================================================================================
#  Final configuration for the GLOBAL variable
#==================================================================================
#
    my $conf = uc $Uprep{rtenv}{core};

return $conf;
}


sub Final_value {
#==================================================================================
#  Simply transfer the value from the OPTIONS hash for the final configuration
#==================================================================================
#
    my $field = shift;

return $Uprep{OPTIONS}{$field};
}



