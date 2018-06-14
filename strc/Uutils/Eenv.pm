#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Eenv.pm
#
#  DESCRIPTION:  Contains the routines used in setting up the EMS environment.
#                All subroutines called within this module must also reside in
#                Eenv.pm.
#                 
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Eenv;

use warnings;
use strict;
require 5.008;
use English;

use Ecomm;
use Ecore;
use Others;

use vars qw (%Uenv);


sub SetEnvironment  {
#=====================================================================================
#  This routine completes the individual steps necessary in setting up the UEMS 
#  environment, which includes:
#
#      1. Setting the primary EMS environment variables
#      2. Setting the sub-package environment variables
#      4. Modifying the executable path
#
#  Note that the handling of the return is different here than with the other
#  routines as a return of the %Uenv hash indicates success when an empty
#  hash means failure.
#=====================================================================================
#
use Cwd 'abs_path';

    %Uenv = ();

    #  The top level of the EMS installation is the only argument passed
    #  to this routine.
    #
    my $ems = shift or return 1;

    my $verbose = (defined $ENV{VERBOSE} and $ENV{VERBOSE}) ? $ENV{VERBOSE} : 3; $ENV{VERBOSE} = 3;

    $Uenv{UEMS} = abs_path($ems);

    %Uenv = &EvaluateHiRes()      unless (caller(0))[1] =~ /uemsinfo/i;

    %Uenv = &DefineEnvironment()  or return 1;

    %Uenv = &ConfigEnvironment()  or return 1;

    #  Now assign the variables to the user environment, i.e, the %ENV hash;
    #
    @ENV{keys %Uenv} = values %Uenv;

return;
}


sub EvaluateHiRes {
#==================================================================================
#  This routine checks for the existence of needed Perl Modules.
#==================================================================================
#
use Ecomm;

    #  Perl Module Time::HiRes
    #
    $Uenv{'Time::HiRes'} = eval{require Time::HiRes} ? 1 : 0;

    #  Provide early warning messages
    #
    my $mesg =  'It is recommended that you install this library on your system, which '.
                'is simple enough to do and should relieve the pain and suffering caused '.
                'by seeing this message again and again, which you will.';

    &Ecomm::PrintMessage(6,5,86,1,1,'WARNING: Perl module not installed - Time::HiRes',$mesg) unless $Uenv{'Time::HiRes'};


return %Uenv;
}


sub DefineEnvironment {
#==================================================================================
#  Define & assign the UEMS environment variables. This is really just
#  a precaution if the user has not set the environment variables via
#  a login shell.
#==================================================================================
#
    $Uenv{EMS_HOME}  =  $Uenv{UEMS};
    $Uenv{EMS_BIN}   =  "$Uenv{EMS_HOME}/bin";
    $Uenv{EMS_DATA}  =  "$Uenv{EMS_HOME}/data";

    $Uenv{EMS_STRC}  =  "$Uenv{EMS_HOME}/strc";

    $Uenv{STRC_BIN}  =  "$Uenv{EMS_STRC}/Ubin";
    $Uenv{STRC_PREP} =  "$Uenv{EMS_STRC}/Uprep";
    $Uenv{STRC_RUN}  =  "$Uenv{EMS_STRC}/Urun";
    $Uenv{STRC_POST} =  "$Uenv{EMS_STRC}/Upost";
    $Uenv{STRC_APOST}=  "$Uenv{EMS_STRC}/Uapost";
    $Uenv{STRC_AUTO} =  "$Uenv{EMS_STRC}/Uauto";
    $Uenv{STRC_UTIL} =  "$Uenv{EMS_STRC}/Uutils";


    $Uenv{EMS_RUN}   =  "$Uenv{EMS_HOME}/runs";
    $Uenv{EMS_LOGS}  =  "$Uenv{EMS_HOME}/logs";


    #---------------------------------------------------------------------
    #  If the UEMS_LOCAL flag has been used to specify a non-default
    #  directory for the run-time domains.
    #---------------------------------------------------------------------
    #
    if (defined $ENV{UEMS_LOCAL} and $ENV{UEMS_LOCAL}) {

        if (defined $ENV{EMS_RUN} and $ENV{EMS_RUN}) {
            $Uenv{EMS_RUN}   = $ENV{EMS_RUN};
            $Uenv{EMS_LOGS}  = $ENV{EMS_LOGS};
        } else {
             $Uenv{EMS_RUN}   = "$ENV{HOME}/uems/runs";
             $Uenv{EMS_LOGS}  = "$ENV{HOME}/uems/logs";
        }
       
        #  Since the mkdir routine is not available yet
        #
        system "mkdir -p $Uenv{EMS_RUN}  > /dev/null 2>&1" unless -e $Uenv{EMS_RUN};
        system "mkdir -p $Uenv{EMS_LOGS} > /dev/null 2>&1" unless -e $Uenv{EMS_LOGS};
    }
    
    #---------------------------------------------------------------------
    #  The RUN_BASE environment variable is used when to check whether
    #  EMS_RUN has been redefined.
    #---------------------------------------------------------------------
    #
    $Uenv{RUN_BASE}  =  $Uenv{EMS_RUN};


    $Uenv{EMS_UTIL}  =  "$Uenv{EMS_HOME}/util";
    $Uenv{EMS_DOCS}  =  "$Uenv{EMS_HOME}/docs";
    $Uenv{EMS_LIB}   =  "$Uenv{EMS_HOME}/lib";
    $Uenv{EMS_CONF}  =  "$Uenv{EMS_HOME}/conf";
    $Uenv{EMS_ETC}   =  "$Uenv{EMS_HOME}/etc";


    $Uenv{EMS_UBIN}  =  "$Uenv{EMS_UTIL}/bin";

    if (defined $ENV{MPICH_HOME} and $ENV{MPICH_HOME}) {
        $Uenv{EMS_MPI} = $ENV{MPICH_HOME};
    } else {
        $Uenv{EMS_MPI} = "$Uenv{EMS_UTIL}/mpich2";
    }

    $Uenv{DATA_GEOG} =  "$Uenv{EMS_DATA}/geog";
    $Uenv{DATA_TBLS} =  "$Uenv{EMS_DATA}/tables";

    $Uenv{DW}        =  "$Uenv{EMS_HOME}/domwiz";
    $Uenv{DW_BIN}    =  "$Uenv{DW}/bin";
    $Uenv{DW_LIB}    =  "$Uenv{DW}/lib";

    $Uenv{NO_STOP_MESSAGE} = 1;  #  Need this statement to avoid signaling during ems_autorun

    $Uenv{LSF_SYS}   =  0 unless defined $Uenv{LSF_SYS} and $Uenv{LSF_SYS};  #  WCOSS


    #  If the user requested notification of a failed simulation.
    #
    $Uenv{MAILX}  = (defined $ENV{MAILX} and -e $ENV{MAILX}) ? $ENV{MAILX} : '';


return  %Uenv;
}


sub ConfigEnvironment {
#==================================================================================
#  Do the final configuration of the environment settings.
#==================================================================================
#
    #  What shell is the user running?
    #
    my $shell = (defined $ENV{SHELL} and $ENV{SHELL}) ? &Others::popit($ENV{SHELL}) : 'bash';


    #----------------------------------------------------------------------------------
    #  These are UEMS environment variables that should be set when the user logs in.
    #  Use  the existence of these variables to determine whether its safe to proceed.
    #----------------------------------------------------------------------------------
    #
    my $n=0;
    my @cfgs = qw(UEMS EMS_RUN EMS_CONF EMS_STRC); foreach (@cfgs) {$n++ if exists $ENV{$_};}

    unless ($n) {

        my $evf = ($shell =~ /csh/i) ? 'sourcing the UEMS.cshrc' : 'sourcing the UEMS.profile';
        my $cmd = ($shell =~ /csh/i) ? "if (-e $Uenv{UEMS}/etc/UEMS.cshrc) source $Uenv{UEMS}/etc/UEMS.cshrc"
                                     : "if [-e $Uenv{UEMS}/etc/UEMS.profile ] ; then . $Uenv{UEMS}/etc/UEMS.profile";

        my $mesg = "It appears that your UEMS environment is not correctly defined. This is most\n".
                   "likely the result of not $evf file when you logged in.\n".
                   "Please add a line to your login file similar to:\n\n".

                   "  $cmd\n\n".

                   "Then log out and back again. Hopefully it will take effect and we may continue.\n\n".

                   "You will have to resolve this issue before continuing. Attempting to execute\n".
                   "this routine repeatedly without determining the cause of the problem will not\n".
                   "win you any favors with me either.\n\n".

                   "It's your task. Don't make me print this message again.";

         &Ecomm::PrintMessage(9,4,94,2,1,'We thought you had such great potential!',$mesg);
         return ();
    }


    #----------------------------------------------------------------------------------
    #  Collect the system information and then check values against  values specified
    #  in the UEMS login file.  For the CPU configuration, don't allow values of 
    #  SOCKETS, CORES, and OMP_NUM_THREADS to exceed those determined by the UEMS.
    #----------------------------------------------------------------------------------
    #
    my %sysinfo = &Others::SystemInformation();

    #  The UEMS no longer supports 32-bit systems
    #
    $Uenv{ARCH} = ( ($sysinfo{hwtype} eq 'i386') or ($sysinfo{cputype} eq 'i686') ) ? 'x32' : 'x64';

    if ($Uenv{ARCH} eq 'x32') {
        my $date = gmtime();
        my $mesg = "The UEMS no longer supports i686 (32-bit) systems, because it makes the developer's life ".
                   "easier not having to build the binaries. Unfortunately for you, it also means that the UEMS ".
                   "will not run on this machine.\n\n".

                   "The UEMS - Making your job more difficult since $date";

        &Ecomm::PrintMessage(9,4,94,2,1,'Time to update your system!',$mesg);
        return ();
    }


    # Set the value of OMP_NUM_THREADS to be the number of cores * physical cpus
    #
    $ENV{SOCKETS} = 0 unless defined $ENV{SOCKETS} and $ENV{SOCKETS}; $Uenv{SOCKETS} = $ENV{SOCKETS};
    $ENV{CORES}   = 0 unless defined $ENV{CORES}   and $ENV{CORES};   $Uenv{CORES}   = $ENV{CORES};

    unless ($ENV{SOCKETS} and $ENV{CORES}) {

        my $evf = ($shell =~ /csh/i) ? 'UEMS.cshrc' : 'UEMS.profile';

        &Ecomm::PrintMessage(6,2,144,2,2,"Warning: SOCKETS or CORES not properly defined in $evf.\n\n         Using SOCKETS = $sysinfo{sockets} and CORES = $sysinfo{cores_per_socket}.");

        $Uenv{SOCKETS} = $sysinfo{sockets};
        $Uenv{CORES} = $sysinfo{cores_per_socket};
    }
    $Uenv{OMP_NUM_THREADS} = $Uenv{SOCKETS} * $Uenv{CORES};


    $Uenv{FTP_PASSIVE} =  defined $ENV{FTP_PASSIVE} ? $ENV{FTP_PASSIVE} : 1;
    $Uenv{EMS_DEBUG}   = 0;   #  Make sure it's defined. Overriden by command line options


    #  GRADS environment variables
    #
    $Uenv{GADDIR} = "$Uenv{EMS_UTIL}/grads/data";
    $Uenv{GAUDFT} = "$Uenv{EMS_UTIL}/grads/data/tables";
    $Uenv{GASCRP} = "$Uenv{EMS_UTIL}/grads/scripts";


    #  If the user requested notification of a failed simulation.
    #
    $Uenv{MAILX}  = (defined $ENV{MAILX} and -e $ENV{MAILX}) ? $ENV{MAILX} : '';


    #  Set the user path and make sure to add the UEMS paths at the beginning
    #
    my @epath = ( ".", "$Uenv{EMS_STRC}", "$Uenv{STRC_BIN}", "$Uenv{DW_BIN}", "$Uenv{EMS_BIN}", "$Uenv{GADDIR}/bin", 
                  "$Uenv{EMS_UBIN}", "$Uenv{GADDIR}", "$Uenv{EMS_MPI}/bin");

    my @upath = ();
    my %temp  = ();

    my $nawips = (defined $ENV{NAWIPS} and $ENV{NAWIPS} and -d $ENV{NAWIPS}) ? $ENV{NAWIPS} : 0;
    foreach (split /:/ => $ENV{PATH}) {
        s/ //g; next unless $_;
        next unless $_;
        next if /wrfems/;
        if ($nawips and /nawips/) {next unless /$nawips/;}
        next if /uems/    and ! /nawips/;
        next if /^\.$/;
        push @upath => $_;
    }
    @upath = grep ++$temp{$_} < 2 => @upath; @upath = (@epath,@upath);
    $Uenv{PATH} = join ':' => @upath;


return %Uenv;
}
   
 
