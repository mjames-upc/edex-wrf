#!/bin/tcsh
#-------------------------------------------------------
# ~/.cshrc file for UEMS usage
#
#-------------------------------------------------------
#

setenv EDITOR /usr/bin/vim
 
# Set the default file protection to be mode 0644 (-rw-r--r--)
#
umask 002

 
# Set the path
#
setenv PATH ".:$HOME/bin:/sbin:/usr/sbin:/usr/local/sbin:/bin:/usr/bin:/usr/local/bin"


# Source EMS.cshrc
#
if (-f /usr1/uems/etc/EMS.cshrc) source /usr1/uems/etc/EMS.cshrc


#  setenv EMS_RUN <your run directory>
#
#setenv EMS_RUN  $HOME/uems/runs
#setenv EMS_LOGS $HOME/uems/logs

 
# Various definitions
#
set filec
set cdpath = ( ~ )
set notify
set history = 200 
set savehist = 200
limit coredumpsize 0
unset limits
limit stacksize unlimited


# Set a user prompt
#
set host=`hostname | cut -d"." -f1`
set prompt="${USER}@${host}-> "

# Set a few aliases
#
alias dir       'ls -F'
alias la        'ls -a'
alias ll        'ls -lt'
alias lla       'ls -la'
alias ls        'ls -CF'
alias c         clear
alias sl        ls
alias h         history
alias hh        'history -h'
alias .         'echo $cwd'
alias ..        'set dot=$cwd;cd ..'
alias cd        'set old=$cwd;chdir \!*;pwd'
alias lwd       'set lwd=$old;set old=$cwd;cd $lwd; unset lwd '
