#!/bin/bash
#===============================================================================
#  UEMS WRAPPER FILE - Bash Shell version
#
#  This file serves as a wrapper for running the ems_autorun.pl routine via cron
#  to ensure that the UEMS environment variables are properly set. Any arguments
#  to this script will be passed directly to ems_autorun.pl, so it is important
#  that the user, that be you, review the available ems_autorun.pl flags and
#  options prior to using this file. 
#  
#  The only required flag is "--rundir <path to run-time directory>", because
#  the UEMS needs to know what domain to use. Any other ems_autorun.pl flags
#  are probably unnecessary. Here is an example:
#
#    uems_autorun-wrapper.sh --rundir /usr1/uems/runs/<somedomain>
#
#  Where <somedomain> is the name of the directory containing a computational
#  domain.  This information is then placed in a crontab file entry that might
#  look something like:
#
#  48 11 * * * /usr1/uems/strc/Ubin/uems_autorun-wrapper.sh --rundir /usr1/uems/runs/<somedomain> >& /usr1/uems/logs/uems_autorun.log 2>&1
#
#  Remember that --rundir <path>/<somedomain> is mandatory for success. Failure,
#  on the other hand, is your domain (some UEMS humor for you).
#
#  Recent developments:
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#

    #  A simple check to make sure some effort was made to include the domain
    #
    if [ -z $2 ] ; then
        echo ''
        echo "  You appear to be missing --rundir <path>/<somedomain> as an argument to $0"
        echo ''
        exit 
    fi


    # The UEMS environment variable must be correctly set
    #
    UEMS=/awips2/uems ; export UEMS
    EMS=$UEMS       ; export EMS


    #  Make sure the environment has been set correctly
    #
    if [ ! -d $EMS/etc/EMS.profile ] ; then
        . $EMS/etc/EMS.profile
    else
        echo ""
        echo "  ERROR: UEMS Environment variable not correct in $0."
        echo "         Fix it and try again."
        echo "" 
        exit
    fi


    #  Let's start the show
    #
    echo "  RUNNING: $EMS_STRC/Ubin/ems_autorun.pl $@ > $EMS_LOGS/uems_autoruns.log 2>&1"
    `$EMS_STRC/Ubin/ems_autorun.pl $@ > $EMS_LOGS/uems_autoruns.log 2>&1`


exit
