# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User specific environment and startup programs

if [ -f /usr1/uems/etc/EMS.profile ]; then
        . /usr1/uems/etc/EMS.profile
fi

#EMS_RUN=$HOME/uems/runs    ; export EMS_RUN
#EMS_LOGS=$HOME/uems/logs   ; export EMS_LOGS


PATH=$PATH:$HOME/bin

export PATH
