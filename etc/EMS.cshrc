#!/bin/tcsh 
#----------------------------------------------------------------------------------
#
#  This file is used to define some of the environment variables for the EMS
# 
#  If the EMS was installed correctly then few changes are needed to this
#  file unless you really feel it's really, really necessary.
#
#  R.Rozumalski  Version 18.X - The "helping me to help myself" release
#----------------------------------------------------------------------------------
#

#  The EMS variable below MUST be set correctly for everything to operate as
#  advertised. At least that is the plan. Note that this parameter should have
#  correctly set during installation but sometimes stuff just happens.
#
setenv UEMS /awips2/uems

if ( ! -d $UEMS ) then
    echo "Can not find EMS distribution - Check location and modify uems/etc/EMS.cshrc"
    unsetenv UEMS
    exit
endif



#  We begin with some user-configurable parameters that serve the greater good of
#  almost all of humanity as well as the EMS, just the way it should be.
#

#  UEMS_LOCAL
#
#     Setting the UEMS_LOCAL environment variable tells the UEMS that the default
#     location for the EMS_RUN directory (Default: uems/runs) is to be reassigned to
#     another location. You would set UEMS_LOCAL = 1 if the UEMS is being controlled
#     a "UEMS administrator" but there will be multiple users creating domains and
#     running simulations, such as in a classroom setting.
#
#     If UEMS_LOCAL is set, then the new locations for EMS_RUN and EMS_LOGS will be
#     defined by the RUNS_HOME variable below. Additionally, if the user is in
#     the development group then UEMS_LOCAL will be reset to 0.
#
setenv UEMS_LOCAL 0


#  RUNS_HOME
#
#     In the event that UEMS_LOCAL = 1, RUNS_HOME will define the top level of the
#     user's working directory, i.e., where "uems/runs" and "uems/logs" will be
#     located. If UEMS_LOCAL is not defined (or 0) then RUNS_HOME will be ignored
#     and $EMS_RUN and $EMS_LOGS will be assigned thier default locations. If
#     UEMS_LOCAL = 1 but RUNS_HOME is not defined or invalid, then the top level
#     of the user's home directory, $env(HOME), will be used.
#
#     If a single large multi-user space is to be used for running the UEMS, it is
#     recommended that RUNS_HOME be set to something like "<path to space>/$env(USER)".
#
setenv RUNS_HOME $HOME


#  MPICH_HOME
#  
#     MPICH_HOME defines location of the MPICH executables on your system. By default,
#     the UEMS will use the pre-compiled executables located under uems/util/mpich2,
#     which in most cases should be fine. However, if you would like to use a locally
#     compiled version of MPICH or the package provided with your Linux distibution
#     you may do so by specifying the location of MPICH below. If MPICH_HOME is 
#     commented out or blank the UEMS provided package will be used.
#
#     DWIZ users - If using an alternate MPICH installation, you will need to create
#     a link from $MPICH_HOME/bin/mpiexec.gf to $MPICH_HOME/bin/mpiexec.gforker:
#
#       cd $MPICH_HOME/bin
#
#       #  ln -s mpiexec.gforker mpiexec.gf 
#
setenv MPICH_HOME $UEMS/util/mpich2



#  SOCKETS and CORES
#
#     SOCKETS defines the number of physical processors (sockets) on that reside on your
#     local system. These variables provide guidance to the UEMS when running a simulation
#     on the local system. The actual number of processors (maximum = sockets*cores) is
#     assigned in the run_ncpus.conf file, which is part the configuration for each 
#     run-time domain. SOCKETS is simply the number of physical processors that you 
#     could touch if you were to open up the computer case and move the large heat sinks. 
#     Most stand-alone workstations have either 1 or 2 of these physical CPUs although 
#     some most exotic and expensive mainboards can support 8 or more, but you probably 
#     don't have one of those.

#     CORES defines the number of cores contained within each of those touchable CPUs,
#     or in other words, the number of "CORES per SOCKET". You can find this infomation
#     by reading the system /proc/cpuinfo file, or by running the "lscpu" utility.
#
setenv SOCKETS 10
setenv CORES   1


#  MAILX
#
#     MAILX defines the routine to use when sending you informative messages or pearls of
#     nonsensical wisdom, which it tends to do from time to time, especially following a
#     mail real-time forecast. On most Linux systems the "/bin/mailx" utility is used
#     for this purpose but it must also be properly configured to send mail, which is why
#     this option is turned OFF by default.
# 
#     Note that the email recipients are defined in the ems_autorun.conf file located
#     beneath the individual run-time domain directories.
#
#setenv MAILX /bin/mailx



#  EMS_NAWIPS
#
#     The EMS includes the NAWIPS the diagnostic and display system. Just because one
#     of the many mottos here at EMS world headquarters is "Giving more of what they
#     need, whether they need it or not!".
#
#     By default the EMS_NAWIPS setting is commented out. You may remove the '#' if you 
#     want to use NAWIPS.  If you have your own NAWIPS release installed and wish to
#     use it instead, you may either replace the path to the EMS provided release with
#     your own or leave EMS_NAWIPS blank and set the NAWIPS environment outside this file. 
#
#setenv EMS_NAWIPS $UEMS/util/nawips



#  HTTP_PROXY
#
#     The HTTP_PROXY environment variable is used when your local network has a proxy
#     server which accepts http requests on some port other then 1080. Symptoms of this 
#     problem would be if you are unable to connect to outside data sources via http
#     when running ems_prep or ems_autorun.  For most users this is not a problem, in 
#     which case HTTP_PROXY should be left blank. If you know this is the case for 
#     your system then set the HTTP_PROXY to:
#
#       HTTP_PROXY = <IP address of server>:<port used>
#
#     For example, if proxy server 192.168.150.10 used port 80:
#
#       HTTP_PROXY = 192.168.150.10:80
#
#     If the proxy server requires a user name and password
#
#       HTTP_PROXY = <user>:<passwd>@<IP address>:<port used>
#
setenv HTTP_PROXY 



#  MPIEXEC_PORT_RANGE 
#
#     Setting MPICH_PORT_RANGE will override the default range of ports to use when communicating
#     to the other hosts while using MPICH2. If you want to change the default values, simply set
#     MPIEXEC_PORT_RANGE = <lowest port>:<highest port>, for example:
#
#         MPIEXEC_PORT_RANGE  = 50001:59999
#
#     The range specified below can be overridden from the run_ncpus.conf file with the 
#     MPICH_PORT_RANGE parameter. Should you not do anything then MPICH2 will select the
#     ports to use all by itself and you will like it.  Leave commented out unless you plan 
#     on using it.
#
#setenv MPIEXEC_PORT_RANGE 



#  FTP_PASSIVE
#
#     FTP_PASSIVE specifies that all FTP transfers be done in either PASSIVE (1) or
#     non PASSIVE (0) mode.
#
setenv FTP_PASSIVE 1



#  COMPILER
#
#    If you plan on using the provided scripts to build your own executables for the UEMS,
#    then set COMPILER to the compiler being used. Current options are the Portland Group
#    ("PGI") or Intel ("INTEL") packages, one of which is hopefully installed on your 
#    system (license required) and that you have the environment variables properly set.
#
#    If you do not plan on building your own executables then leave COMPILER commented 
#    out.
#
#setenv COMPILER INTEL



#  ==================================================================================
#    End general user-configurable options - Unless you need to change EMS_RUNS
#  ==================================================================================
#

#  ----------------------------------------------------------------------------------
#  UEMS package environment variables - Here top level "UEMS" value is used to set
#  "EMS", which, in turn defines all the other environment variables. This is
#  done to avoid mashing of variables with older versions of the EMS still running
#  on a system.
#  ----------------------------------------------------------------------------------
#
    setenv EMS          $UEMS
    setenv EMS_HOME     $EMS

    setenv EMS_BIN      $EMS_HOME/bin
    setenv EMS_DATA     $EMS_HOME/data

    setenv EMS_STRC     $EMS_HOME/strc
    setenv STRC_BIN     $EMS_STRC/Ubin
    setenv STRC_PREP    $EMS_STRC/Uprep
    setenv STRC_RUN     $EMS_STRC/Urun
    setenv STRC_POST    $EMS_STRC/Upost
    setenv STRC_AUTO    $EMS_STRC/Uauto
    setenv STRC_UTIL    $EMS_STRC/Uutils

    setenv EMS_RUN      $EMS_HOME/runs
    setenv EMS_LOGS     $EMS_HOME/logs

    if ($?UEMS_LOCAL & $UEMS_LOCAL == 1) then
       #  You may change these if UEMS_LOCAL is set.  Notice that the default location
       #  is under the user's home directory; however, if there is to be an alternate
       #  location then use the RUNS_HOME variable to redefine the location.
       #
       setenv EMS_RUN      $RUNS_HOME/uems/runs
       setenv EMS_LOGS     $RUNS_HOME/uems/logs
      
       #  Create the directories (hopefully) if they do not exist
       #
#      `/bin/mkdir -p $EMS_RUN  >& /dev/null`
#      `/bin/mkdir -p $EMS_LOGS >& /dev/null`
    endif

    setenv RUN_BASE     $EMS_RUN

    setenv EMS_UTIL     $EMS_HOME/util
    setenv EMS_DOCS     $EMS_HOME/docs
    setenv EMS_CONF     $EMS_HOME/conf
    setenv EMS_ETC      $EMS_HOME/etc

    setenv EMS_UBIN     $EMS_UTIL/bin
    setenv EMS_MPI      $EMS_UTIL/mpich2

    setenv DATA_GEOG    $EMS_DATA/geog
    setenv DATA_TBLS    $EMS_DATA/tables

    setenv DW           $EMS_HOME/domwiz
    setenv DW_BIN       $DW/bin
    setenv DW_LIB       $DW/libs

    #  For those determined to build your own UEMS
    #
    if (! $?UEMS_LOCAL | $UEMS_LOCAL == 0) then
       setenv EMS_BUILD   $EMS_UTIL/UEMSbuild

       setenv BUILD_SRC   $EMS_BUILD/src
       setenv BUILD_LIBS  $EMS_BUILD/libs
       setenv BUILD_BIN   $EMS_BUILD/bin

       setenv SRC_LIBS    $BUILD_SRC/libs
       setenv SRC_UTILS   $BUILD_SRC/utils
       setenv SRC_POST    $BUILD_SRC/post
       setenv SRC_MODELS  $BUILD_SRC/models

       setenv EWRF        $EMS_BUILD/src/models/wrf
       setenv EWPS        $EMS_BUILD/src/models/wps
       setenv EPOST       $EMS_BUILD/src/post/emsupp/src
       setenv EBUFR       $EMS_BUILD/src/post/emsbufr

    endif


    # Set the value of OMP_NUM_THREADS to be the number of 
    # cores * physical cpus
    #
    @ nprocs = $SOCKETS * $CORES
    setenv OMP_NUM_THREADS $nprocs

    setenv MPSTKZ 512M
    setenv OMP_STACKSIZE 64M

    setenv MP_STACK_SIZE $OMP_STACKSIZE

#  use ulimit for bash

    unset limits
    limit stacksize unlimited

#   Legacy setting that should be removed someday
#
    setenv ARCH  x64

    setenv NO_STOP_MESSAGE 1  #  for the PGF-compiled binaries
    setenv UEMS_MODULE     0

    
#  Set the GrADS environment variables
#
    setenv GADDIR $EMS_UTIL/grads/data
    setenv GAUDFT $EMS_UTIL/grads/data/tables
    setenv GASCRP $EMS_UTIL/grads/scripts


#  Set the NAWIPS environment variables
#
    if ($?EMS_NAWIPS) then
        setenv   NAWIPS $EMS_NAWIPS
        unsetenv EMS_NAWIPS
        if ( -e "$NAWIPS/Nawips.cshrc") source $NAWIPS/Nawips.cshrc
    endif


#  Set the NCVIEW environment variables
#
    setenv UDUNITS2_XML_PATH $EMS_UTIL/ncview/udunits/udunits2.xml
    setenv NCVIEWBASE   $EMS_UTIL/ncview/lib
    setenv XAPPLRESDIR  $EMS_UTIL/ncview/app-defaults
    alias  ncview 'ncview -extra -minmax med -private -no1d'

    set xresources=""
    if ( -d $EMS_UTIL/ncview/app-defaults ) then
        set xresources="$EMS_UTIL/ncview/app-defaults/%N"
        if ( $?XUSERFILESEARCHPATH ) then
           setenv XUSERFILESEARCHPATH ${xresources}:${XUSERFILESEARCHPATH}
        else
           setenv XUSERFILESEARCHPATH $xresources
        endif
    endif


#   Additions to HTTP_PROXY
#
    if ($?HTTP_PROXY) then
        set tmp = `echo $HTTP_PROXY | wc -w`
        if ($tmp) then
            setenv http_proxy http://$HTTP_PROXY
        endif
        unsetenv  HTTP_PROXY
    endif


#  Set the compiler environment
#
    unsetenv COMPLC
    unsetenv COMP

    if ($?COMPILER) then
       set tmp = `echo $COMPILER | wc -w`
       if ($tmp) then 
          setenv COMPLC `echo $COMPILER | tr '[:upper:]' '[:lower:]'`
          setenv COMP   `echo $COMPLC | sed -e 's/^./\U&/'`
       endif
       unsetenv COMPILER
    endif


 
#  Add Unified EMS executables and scripts to the existing path
#
set path = (. $STRC_BIN $DW_BIN $EMS_BIN $EMS_UTIL/grads/bin $EMS_UTIL/bin $GADDIR $EMS_MPI/bin $EMS_UTIL/ncview/bin $EMS_UTIL/HDFView/bin $path)

#  Done!
