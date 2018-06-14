#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Dconf.pm
#
#  DESCRIPTION:  Dconf contains each of the primary routines used for the
#                final configuration of ems_domain. It's the least elegant of
#                ems_domain modules simply because there is a lot of sausage
#                making going on.
#
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Dconf;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Udomain %Conf);


sub Domain_Configuration {
#===============================================================================
#  Routine that calls each of the configuration subroutines
#===============================================================================
#
      %Conf = ();  #  Initialize the Conf hash, which is available to all 
                   #  subroutines within this module.

      my $upref     = shift; %Udomain = %{$upref};

      &Ecomm::PrintTerminal(0,4,255,1,1,sprintf ("%-4s Attempting to decipher your request",&Ecomm::GetRN($ENV{DRN}++))) unless $Udomain{OPTIONS}{MCSERVER};

      return () unless %{$Udomain{CONF}}  = &FinalConfiguration();


return %Udomain;
}


sub FinalConfiguration {
#==================================================================================
#  The FinalConfiguration calls each of the final configuration subroutines. The use
#  of individual routines is not really necessary since both the %Udomain and
#  %Final hashes are global but serves to compartmentalize a block of code for each 
#  variable thus making it easier for future development. Note the change from
#  upper to lower case hash keys.
#==================================================================================
#

    #------------------------- The important parameters -------------------------------
    #  First things first - Note that the order of configuration is important
    #  as some parameters are needed in the configuration of others.  Any 
    #  information that needs to be saved is held in the %Conf hash, which
    #  is only available within this module.
    #----------------------------------------------------------------------------------
    #
    $Conf{create}       =  &Config_create();
    $Conf{update}       =  &Config_update();   #  Kludge for DWIZ
    $Conf{emscwd}       =  &Config_emscwd();   #  Determine whether CWD is domain directory
    $Conf{rundir}       =  &Config_rundir();

    $Conf{localize}     =  &Config_localize();
    $Conf{benchmark}    =  &Config_benchmark();
    $Conf{info}         =  &Config_info();
    %{$Conf{imports}}   =  &Config_import();
    

    #----------------------- Attempt the configuration --------------------------------
    #  The variables below do not require any additional configuration beyond
    #  what was completed in the options module. Should a variable need 
    #  additional attention in the future a routine can be added.
    #----------------------------------------------------------------------------------
    #
    $Conf{rotate}       =  &Config_passvalue('ROTATE');
    $Conf{debug}        =  &Config_passvalue('DEBUG');
    $Conf{scour}        =  &Config_passvalue('SCOUR');
    $Conf{core}         =  &Config_passvalue('CORE');
    $Conf{gwdo}         =  &Config_passvalue('GWDO');
    $Conf{dwiz}         =  &Config_passvalue('DWIZ');
    $Conf{dxres}        =  &Config_passvalue('DXRES');
    $Conf{mcserver}     =  &Config_passvalue('MCSERVER');
    
 
    #  The following require some additional configuration
    # 
    $Conf{restore}      =  &Config_restore();  #  Must come before &Config_refresh
    $Conf{refresh}      =  &Config_refresh();
    

    $Conf{global}       =  &Config_global();
    $Conf{g_nests}      =  &Config_gnests();
    $Conf{g_dxdy}       =  &Config_gdxdy();
    $Conf{g_useny}      =  &Config_guseny();
    $Conf{g_nx}         =  &Config_gnx();
    $Conf{g_ny}         =  &Config_gny();

    $Conf{ncpus}        =  &Config_ncpus();

    #  Terrestrial dataset flags that need to be configured
    #
    $Conf{topo}         =  &Config_topo();
    $Conf{gfrac}        =  &Config_gfrac();
    $Conf{landuse}      =  &Config_landuse();
    $Conf{lakes}        =  &Config_lakes();
    $Conf{stype}        =  &Config_stype();
    $Conf{lai}          =  &Config_lai();
    $Conf{modis}        =  &Config_modis();
    $Conf{defres}       =  &Config_defres();


    #  Make sure we're supposed to do something
    #
    &Config_activate();

    @{$Conf{domains}}   =  &Config_domains();

 
return %Conf;  
}


sub Config_create {
#===============================================================================
#  Define the final value for --create which has an argument in the name
#  of the domain to create. This information will be used to populate 
#  $Conf{rundir}, which gets called shortly after this routine.
#===============================================================================
#
use Cwd;

    my $mesg   = qw{};

    my $create = $Udomain{OPTIONS}{NEWDOM} || $Udomain{OPTIONS}{CREATE} || return 0;
    my $force  = $Udomain{OPTIONS}{DWIZ}   || $Udomain{OPTIONS}{FORCE}  || 0;

 
    unless ($create =~ /^\w/ and $create =~ /\w$/) { 

        my $lt = length $create == 1 ? '' : ($create !~ /^\w/) ? 'leading' : 'training';
        $mesg = "I know. I get it. You really like \"$create\" as a domain name, but it's ".
                "something about that $lt character I just don't trust. There's ".
                "a rather nefarious look about it, like it means trouble.\n\n".
                "And I don't like trouble unless I'm start'n it!";
        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'This situation just chafes my hide!',$mesg));
    }
    
    
    $create = Cwd::realpath("$ENV{EMS_RUN}/$create");


    #-------------------------------------------------------------------------------
    #  Check whether a directory  with the same name already exists. If the
    #  --force flag was passed then move along and delete the previous directory.
    #-------------------------------------------------------------------------------
    #
    if (-e $create and -d $create and ! $force) {

        my $dir  = &Others::popit($create);
  
        $mesg = "I know. I get it. You really like \"$dir\" as a domain name. I do too, but I really ".
                "can't do anything about the existing directory,\n\n".
                "X02X$create,\n\n".
                "unless you request that I remove it by passing the \"--force\" flag, in which case I might ".
                "know some people who can make this problem go away.";

        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'I see you have a most unfortunate situation:',$mesg));

    }


return $create;
}


sub Config_update {
#===============================================================================
#  Define the final value for --update which has an argument in the name
#  of the domain to update. This flag is here to please the DWIZ gods and
#  to allow the developer to avoid the DWIZ source code.  The flag should
#  only be passed by DWIZ.
#===============================================================================
#
use Cwd;

    my $mesg   = qw{};

    my $update = $Udomain{OPTIONS}{UPDATE} || return 0;
    
    unless ($update =~ /^\w/ and $update =~ /\w$/) {

        my $lt = length $update == 1 ? '' : ($update !~ /^\w/) ? 'leading' : 'training';
        $mesg = "I know. I get it. You really like \"$update\" as a domain name, but it's ".
                "something about that $lt character I just don't trust. There's ".
                "a rather nefarious look about it, like it means trouble.\n\n".
                "And I don't like trouble unless I'm start'n it!";
        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'This situation just chafes my hide!',$mesg));
    }

    $update = Cwd::realpath("$ENV{EMS_RUN}/$update");


return $update;
}



sub Config_emscwd {
#===============================================================================
#  Determine whether ems_domain was run from a valid domain directory, in which
#  case the information will be assigned to the --rundir, --localize, and --info
#  flag arguments, overriding existing values.
#===============================================================================
#
use Cwd;

    my $emscwd = 0;

    $emscwd = $Udomain{CWD} if -e "$Udomain{CWD}/static" and
                               -d "$Udomain{CWD}/static" and
                               -e "$Udomain{CWD}/static/namelist.wps";

    $emscwd = Cwd::realpath($emscwd) if $emscwd;


return $emscwd;
}


sub Config_rundir {
#===============================================================================
#  Define the value for RUNDIR, which is the full path to the domain directory
#  that is being created/refreshed/interrogated. The problem is that the name of
#  the domain directory may not be known at this step since it may have been 
#  passed as an argument to the "--create" option, but it will be addressed
#  shortly.
#===============================================================================

    my $mesg   = qw{};
    my $rundir = qw{};
    my $emsrun = Cwd::realpath($ENV{EMS_RUN});
    my $passed = $Udomain{OPTIONS}{RUNDIR};



    #  There are like almost 4 possibilities here:
    #
    #    1. The user passed the --create flag with argument - assign create value to rundir
    #
    return $Conf{create} if $Conf{create};


    #    1.5  DWIZ passed the --update flag with argument - assign update value to rundir
    #
    return $Conf{update} if $Conf{update};


    #    2. ems_domain is run from and existing domain directory (most common) and
    #       overrides any argument passed to --rundir
    #
    return $Conf{emscwd} if $Conf{emscwd};


    #  The value of $passed will only be non-zero if the --rundir flag was passed
    #  with a domain directory as an argument. If nothig was assigned then just
    #  get out now and worry about it later.
    #
    return 0 unless $passed;


    #  At this point $passed contains the name of a domain directory that should reside
    #  under $EMS_RUN.  Make sure it exists and is valid.
    #
    $passed = &Others::popit($passed); $passed = "$emsrun/$passed"; #  Just a precaution


    $rundir = $passed  if -e "$passed/static" and
                          -d "$passed/static" and
                          -e "$passed/static/namelist.wps";

    unless ($rundir) {

        $mesg = "Something is not quite right in that $passed does not exist. You want me to work my ".
                "magic but I have nothing with which to work. Besides being good-looking, you are ".
                "exceptional at what you do, so work with me and we can shine together!";

        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'Shine on You Crazy Diamond!',$mesg)) unless -e $passed;


        $mesg = "Something is not quite right in that $passed does not appear to be a proper domain ".
                "directory. Maybe you intended to pass the \"--rundir <domain>\" flag or there is a ".
                "typo in your domain path, but I am unable to continue our journey until this ".
                "problem is addressed, and not by me!";

        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'User Faux Paux!',$mesg));

    }
                

return Cwd::realpath($rundir);
}


sub Config_localize {
#===============================================================================
#  Final configuration of the --localize flag. If the flag was not passed then
#  return a value of 0. If the flag was passed without an argument then 
#  set to $Conf{rundir} unless $Conf{rundir} = 0, in which case we are lost.
#  If an argument was passed to --localize the set to $EMS_RUN/
#===============================================================================
#
use Cwd;

    my $mesg = qw{};

    my $localize = $Udomain{OPTIONS}{LOCALIZE} || return 0;


    #  If both the --create and --localize flags were passed then turn OFF --localize
    #
    if ($Conf{create}) {
        my $domain = &Others::popit($Conf{create});
        $mesg = "I hate to be the one to break the news to you (not really), but you can't ".
                "pass the \"--create\" and \"--localize\" flags together. You'll need to ".
                "first edit the $domain/static/namelist.wps file and then run:\n\n".
                "  %  ems_domain --localize  [other flags]\n\n".
                "from the newly created domain directory before getting down to your modeling business.";

        &Ecomm::PrintTerminal(6,11,82,1,1,'You\'re rather new at this!',$mesg);
        return 0;
    }


    #  Anything passed --rundir usurps what was passed to --localize. If $Conf{rundir} is 
    #  empty then continue.
    #
    return $Conf{rundir} if $Conf{rundir};



    #  If the --localize flag was passed without an argument ('CWD') then use the 
    #  --rundir value. If this too is missing a value then notify the user that this
    #  is of a terminal nature.
    #
    $localize = ($localize eq 'CWD') ? $Conf{rundir} : Cwd::realpath("$ENV{EMS_RUN}/$localize");

    unless ($localize)  {
        $mesg = "Maybe you were sleeping during the \"UEMS-feastival\" celebration, but you'll need to ".
                "provide some clue as to what domain directory I might be localizing, either in the ".
                "form of an argument to \"--localize\" (or \"--rundir\"), or better yet, run ems_domain ".
                "from the run-time domain directory itself.\n\n".
                "You can wake up now.";

        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'Zzzzzzzzzzz!',$mesg));
    }



    #  Now test whether $localize points to a viable domain directory
    #
    my $finl  = $localize;
    $localize = 0  unless -e "$localize/static" and
                          -d "$localize/static" and
                          -e "$localize/static/namelist.wps";

    unless ($localize) {

        $mesg = "Something is not quite right in that $finl does not exist. You want me to work my ".
                "magic but I have nothing with which to work. Besides being good-looking, you are ".
                "exceptional at what you do, so work with me and we can shine together!";

        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'Shine on You Crazy Diamond!',$mesg)) unless -e $finl;


        $mesg = "Something is not quite right in that $finl does not appear to be a proper domain ".
                "directory. Maybe you intended to pass \"--localize <domain>\" or there is a ".
                "typo in your domain name, but I am unable to continue our journey until this ".
                "problem is addressed, and not by me either!";

        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'User Faux Paux!',$mesg));

    }


    #----------------------------------------------------------------------------------
    #  Check whether the executables are available - geogrid & mpiexec
    #----------------------------------------------------------------------------------
    #
    unless (-e $Udomain{UEXE}{geogrid}) {
        $mesg = "It appears that either your UEMS environment is not correct or the installation ".
                "went horribly wrong as you are missing the $Udomain{UEXE}{geogrid} routine. Consequently, ".
                "I am unable to help you help yourself to a whole lot of simulation excitement.";
        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,"You could'a been somebody",$mesg));
    }

    unless (-e $Udomain{UEXE}{mpiexec}) {
        $mesg = "It appears that either your UEMS environment is not correct or the installation ".
                "went horribly wrong as you are missing the $Udomain{UEXE}{mpiexec} routine. Consequently, ".
                "I am unable to help you help yourself to a whole lot of simulation excitement.";
        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,"You could'a been somebody",$mesg));
    }
    

    #  Before leaving set the value of $Conf{rundir} to $localize since we're here only if $Conf{rundir}
    #  is undefined.
    #
    $Conf{rundir} = $localize;


return $localize;
}


sub Config_benchmark {
#===============================================================================
#  Configure the $Conf{benchmark} parameter,  which is determines whether the
#  target directory is the benchmark case directory, in which case there is a
#  limit to what can be done with ems_domain.
#===============================================================================
#
    my $mesg = qw{};

    my $benchmark = (-e "$Conf{rundir}/static/.benchmark") ? 1 : 0;


    #  If $benchmark and $Conf{create}
    #
    $mesg = "It appears that neither one of us knows what you are doing.  You can not ".
            "create the existing benchmark directory!\n\n".
            "Ugh!  Where did your mother and me go so wrong?";
    &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,"I'll keep this brief:",$mesg)) if $Conf{create} and $benchmark;


    #  If $Conf{localize}
    #
    $mesg = "I hate to be the one to break the news to you (not really), but you can't ".
            "localize the benchmark directory without written consent from the UEMS ".
            "Principal. So send your request along with a note from your advisor and ".
            "two vintage boxtops from Quisp cereal (not Quake, he's a chump).";
    &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,"I'll keep this brief:",$mesg)) if $Conf{localize} and $benchmark;


return $benchmark;
}


sub Config_info {
#===============================================================================
#  Final configuration of the --info flag. If the flag was not passed then
#  return a value of 0. If the flag was passed the set to $Conf{rundir} 
#  unless $Conf{rundir} = 0, in which case we are lost. Note that regardless
#  of whatever happens in this subroutine, the --info flag will be set to "ON"
#  if the localized flag was passed.
#===============================================================================
#
    my $mesg = qw{};

    my $info = $Udomain{OPTIONS}{INFO};


    #  The --info flag gets turned on by default with localize; otherwise
    #  it's dependent upon whether --info was passwd.
    #
    return $Conf{localize} if $Conf{localize};

    return 0 unless $info;  #  --info was not passed

     
    #  The --info flag gets turned on by default with create
    #
    return $Conf{create} if $Conf{create};


    #  Anything passed --rundir usurps what was passed to --info. If $Conf{rundir} is 
    #  empty then continue.
    #
    return $Conf{rundir} if $Conf{rundir};

    $info =~ s/RUNDIR//g;

    #  If we are here then we're lost. Better to provide a distress signal.
    #
    $mesg = "Maybe you at too much during the \"UEMS-feastival\" celebration, but you'll need to ".
            "provide some clue as to what domain directory you want interrogated, either in the form ".
            "of an argument to \"--info\", or better yet, run ems_domain from the run-time domain directory ".
            "itself.\n\n".
            "You may return to your catatonic state now.";

    &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'Pardon the Interruption',$mesg)) unless $info;


    $info = Cwd::realpath("$ENV{EMS_RUN}/$info");

    $mesg = "You still have some learning to do. The argument to \"--info\" must be a domain directory ".
            "that actually exists, which is not the case for $info. I know you mean well, but that's just ".
            "not good enough in the big leagues. I need action from you!\n\n".
            "Action! Action! Action!";

    &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'Show me what you got!',$mesg)) unless -d $info;

 
    $Conf{rundir} = $info;


return $info;
}


sub Config_import {
#===============================================================================
#  At this point if the --import flag was passed then %imports should contain a
#  list of directories from which domains must be selected for import into the 
#  current uems/runs directory.  All that is needed is to verify that the 
#  domain directories are valid.
#
#  When importing directories the domain configuration files will always be
#  refreshed, i.e, --refresh = 1.
#===============================================================================
#
use Cwd;
use List::Util qw(max);

    my $mesg = qw{};

    my @importdirs = @{$Udomain{OPTIONS}{IMPORTS}}; return () unless @importdirs;


    $mesg = "I like your style, but you can't pass the \"--import\" flag with \"--create\" because ".
            "there are things that you can do with imported domains that you shouldn't do with a new ".
            "domain. I rather not get into the details.";

    &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,"It's the law!",$mesg)) if $Conf{create};


    #  Use the "find" utility to locate all "static" directories, which should be located beneath
    #  a valid domain. Additionally, make sure a "conf" directory exists as well to be reasonably
    #  certain the domain is valid.
    #
    my @domains=();
    $_ = Cwd::realpath($_) foreach @importdirs;

    foreach my $import (@importdirs) {my @statics = `find ${import} -name static`;@domains = (@domains,@statics);} @importdirs = (); #  All should be in @domain
    foreach (@domains) {chomp; s/\/static//g; push @importdirs=>Cwd::realpath($_) if -e "$_/conf" and -d "$_/conf";} @importdirs = &Others::rmdups(@importdirs);


    $mesg = "I realize that you requested run-time domains to be imported, but I could not identify ".
            "a single valid domain directory from the list you provided. Maybe this is something that ".
            "you need to work out with yourself and then try me again.";

    &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'I Found Nothing!',$mesg)) unless @importdirs;

    $_ = Cwd::realpath($_) foreach @importdirs;


    #  Check for existing directories with the same domain names as those being imported. Checks must
    #  must be done for those currently existing in the $EMS_RUN directory as well as multiple imported
    #  directories with the same name.
    #
    my $path     = '';
    my $counter  = 0;
    my $pathlen  = 0;
    my @multiple = ();
    my %imports  = ();

    foreach (@importdirs) {  #  Loop through each directory being imported

        my ($ipath,$idir) = &Others::popit2($_);
        my $ldir = "$ENV{EMS_RUN}/$idir";

        if ($path ne $ipath) {$counter++; $path = $ipath;}

        if (defined $imports{$idir} or (-e $ldir and -d $ldir) ) {  #  The $idir name already exists - figure out a new name
            my $filecnt = sprintf 'imported%02d',$counter;
            $idir = "${idir}.${filecnt}";
            push @multiple => $idir;
            $pathlen = max $pathlen, length $_;
        }
        $imports{$idir}  = $_;
    }

        
    if (@multiple) {
        $mesg = "It appears that you are importing one or more domains that conflict with a directory currently ".
                "residing under $ENV{EMS_RUN} and/or each other. No worries, as I will simply rename the imported directory and ".
                "allow to figure out what to do with it.  Note that these domains will not be localized but they ".
                "will be refreshed. You will have to localize them individually once they are renamed again by you.";

        &Ecomm::PrintTerminal(6,11,104,1,2,"Did you name all your children \"George\" too?",$mesg);
    
        foreach (sort @multiple) {&Ecomm::PrintTerminal(1,11,255,0,1,sprintf("%-${pathlen}s  -> %s/%s",$imports{$_},'uems/runs',$_));}

        &Ecomm::PrintTerminal(0,1,255,1,1,'');
        sleep 10;
    }

    
return %imports;
}


sub Config_ncpus {
#===============================================================================
#  Define the number of processors to be used when running geogrid, but first,
#  some issues must be resolved:
#
#    1.  Is the value of OMP_NUM_THREADS (SOCKETS * CORES) as defined in the
#        EMS.cshrc|profile file, greater then the total number of cpus identified
#        on the machine (total_cores). If so then set maxcpus = total_cores.
#
#    2.  Was the --ncpus flag passed?  If yes then check against maxcpus value.
#===============================================================================
#
    my $maxcpus = 0;
       $maxcpus = $ENV{OMP_NUM_THREADS} if defined $ENV{OMP_NUM_THREADS} and $ENV{OMP_NUM_THREADS} > 0;
       $maxcpus = $Udomain{SYSINFO}{total_cores} if defined $Udomain{SYSINFO}{total_cores} and $Udomain{SYSINFO}{total_cores} > 0;

       if ($Udomain{OPTIONS}{NCPUS} > $maxcpus) {
           my $mesg = "Setting NCPUS to $maxcpus, because that's all the cores you have on this system.";
           &Ecomm::PrintTerminal(6,11,114,1,1,"I'm Givin' Her All She's Got, Captain!",$mesg);
       }

       $maxcpus = $Udomain{OPTIONS}{NCPUS} if $Udomain{OPTIONS}{NCPUS} and $Udomain{OPTIONS}{NCPUS} < $maxcpus;
       $maxcpus = 1 unless $maxcpus > 0;  #  A Safety check

return $maxcpus;
}


sub Config_refresh {
#===============================================================================
#  Configure the value for the --refresh flag, which may require an override
#  of the user. Here are the basic rules:
#
#    * Turn ON  if --import flag passed
#    * Turn ON  if --localize flag passed
#    * Turn OFF if --create flag passed
#    * Turn OFF if --restore flag passed
#===============================================================================
#
    my $refresh = $Udomain{OPTIONS}{REFRESH};

    #  If both the --create and --refresh flags were passed then turn OFF --refresh
    #
    return 0 if $Conf{create} or $Conf{restore};
 
    return 1 if $Conf{update};

    return 1 if $Conf{localize} || %{$Conf{imports}};

    my $mesg = "You were checking whether I would notice that you passed the \"--refresh\" flag without ".
               "indicating the domain(s) on which to operate. Well, the jokes on you now as the next simulation ".
               "you will get from me will be that of paint drying!";

    &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'I See What You Did!',$mesg)) if $refresh and !$Conf{rundir};

        
return $refresh;
}


sub Config_restore {
#===============================================================================
#  Configure the value for the --restore flag, which returns the domain
#  configuration to a factory fresh state.
#===============================================================================
#
    my $restore = $Udomain{OPTIONS}{RESTORE} || return 0;

    #  If both the --create and --restore flags were passed then turn OFF --restore
    #
    return 0 if $Conf{create};

    return $restore if $Conf{localize} || %{$Conf{imports}};

    my $mesg = "You were checking whether I would notice that you passed the \"--restore\" flag without ".
               "indicating the domain(s) on which to operate. Well, the jokes on you now as the next simulation ".
               "you will get from me will be that of your voice screaming in deep space!";

    &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'I See What You Did!',$mesg)) if $restore and !$Conf{rundir};


return $restore;
}


sub Config_landuse {
#===============================================================================
#  Define the landuse dataset, USGS,  MODIS, SSIB, NLCD2006, or NLCD2011 to use 
#  when creating or localizing a domain. The default value is determined by the
#  current geog_data_res setting in the namelist.wps file but may be changed
#  by passing one of the valid options as an argument to --landuse.
#===============================================================================
#
    my $landuse  = '';

    my $n = $Udomain{OPTIONS}{MODIS} + $Udomain{OPTIONS}{USGS};
       $n++ if $Udomain{OPTIONS}{LANDUSE};

    if ($n > 1) {
        my $mesg = "\"YOU NOT FUNNY!\" (hopefully the accent was evident). You may not pass any combination ".
                   "of the \"--modis\", \"--usgs\", and \"--landuse\" flags because they are opposite sides ".
                   "of the same coin (or something like that). You can only pass just one!";

        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'As my advisor once said to me,',$mesg));
    }

    $landuse = 'default' if $Udomain{OPTIONS}{MODIS} || $Udomain{OPTIONS}{DWIZ};
    $landuse = 'usgs'    if $Udomain{OPTIONS}{USGS};
    $landuse = $Udomain{OPTIONS}{LANDUSE} if $Udomain{OPTIONS}{LANDUSE};


    if ($landuse and %{$Conf{imports}}) {
        &Ecomm::PrintTerminal(1,11,84,1,1,'Using current geog_data_res value for land use dataset with --imports'); 
        $landuse = '';
    }


return $landuse;
}


sub Config_lakes {
#===============================================================================
#  Define the value for lakes , which determines whether to include the high-
#  resolution lakes during localization. Options are to use the value in the 
#  namelist file or input from the --[no]lakes. The default is NO lakes. If
#  a land use dataset other than USGS or MODIS is used, set $lakes to -1 (none).
#===============================================================================
#
    #  Start by checking the value in the namelist.wps file
    #
    my $lakes = 0;

    #  If --nolakes was passed then option value should be -1
    #  If --lakes was passed then option value should be 1
    #  If --[no]lakes was not passed then option value should be 0
    #
    $lakes = $Udomain{OPTIONS}{LAKES} if $Udomain{OPTIONS}{LAKES};


    if ($lakes and %{$Conf{imports}}) {
        &Ecomm::PrintTerminal(1,11,84,1,1,'Using current geog_data_res value for inland lakes dataset with --imports');
        return 0;
    }     


    #  Lakes not supported with nlcd or ssib datasets.
    #
    if ($lakes == 1 and $Conf{landuse} =~ /nlcd|ssib/) {
        &Ecomm::PrintTerminal(1,11,84,1,1,'Inland lakes data not available with NLCD or SSIB land use datasets.');
        $lakes = -1;
    }


return $lakes;
}


sub Config_gfrac {
#===============================================================================
#  Configure the --gfrac if passed 
#===============================================================================
#
    my $gfrac = $Udomain{OPTIONS}{GFRAC} || return 0;

    if ($gfrac and %{$Conf{imports}}) {
        &Ecomm::PrintTerminal(1,11,84,1,1,'Using current geog_data_res value for greenness fraction dataset with --imports');
        return 0;
    }

return $gfrac;
}


sub Config_stype {
#===============================================================================
#  Configure the --stype if passed 
#===============================================================================
#
    my $stype = $Udomain{OPTIONS}{STYPE} || return 0;

    if ($stype and %{$Conf{imports}}) {
        &Ecomm::PrintTerminal(1,11,84,1,1,'Using current geog_data_res value for soil type dataset with --imports');
        return 0;
    }

return $stype;
}


sub Config_topo {
#===============================================================================
#  Configure the --topo if passed 
#===============================================================================
#
    my $topo = $Udomain{OPTIONS}{TOPO} || return 0;

    if ($topo eq 'gtopo' and ! grep {/^topo_/} @{$Udomain{GEOG}{datasets}}) {
        my $mesg = "The privilege of passing \"--topo gtopo\" requires that you also install the Pre WPS V3.8 ".
                   "USGS terrain elevation dataset, which is not included by default with the UEMS. To install ".
                   "the gtopo dataset:\n\n".
                   "X02X%  uems_install.pl --install --geog gtopo\n\n".
                   "and then feel free to try me again.";
        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,"I can't do ALL the heavy lifting!",$mesg));
    }


    if ($topo and %{$Conf{imports}}) {
        &Ecomm::PrintTerminal(1,11,84,1,1,'Using current geog_data_res value for topography dataset with --imports');
        return 0;
    }


return $topo;
}


sub Config_lai {
#===============================================================================
#  This is just a dummy subroutine to ensure that $Conf{lai} is initialized
#  because it will be used later on.  In the future a --lai flag should be 
#  added to the options list.
#===============================================================================
#

return 0;
}


sub Config_modis {
#===============================================================================
#  Passing the modis flag simply sets the dataset flags to 'default', because 
#  the default is MODIS. This subroutine must be called after the individual
#  dataset assignments but before &Config_defres. Note that --modis is is the
#  default if this routine is being run by DWIZ.
#===============================================================================
#
    my $modis = $Udomain{OPTIONS}{MODIS} || $Udomain{OPTIONS}{DWIZ} || return 0;

    #  So we know that the --modis flag was passed, but what about the 
    #  individual terrestrial dataset flags? Below are the UEMS defaults.
    #
    $Conf{gfrac}   = &Dutils::LookupGreenFractionDataset('modis')  unless $Conf{gfrac};
    $Conf{lai}     = &Dutils::LookupLeafAreaIndexDataset('modis')  unless $Conf{lai};
    $Conf{lakes}   = 1                                             unless $Conf{lakes} == -1;

    $Conf{landuse} = &Dutils::LookupLanduseDataset($Conf{lakes} == -1 ? 'modis' : 'modis_lakes')  unless $Conf{landuse};
    

return $modis;
}


sub Config_defres {
#===============================================================================
#  Configuration of the --defres flag is a bit tricky. Passing --defres instructs
#  ems_domain to use the default values for the various terrestrial datasets 
#  when configuring geog_data_res for namelist.wps; however, the default values
#  may be overridden by the various flags passed such as --landuse, --topo,
#  and --greenfrac.
#===============================================================================
#
    my $defres = $Udomain{OPTIONS}{DEFRES} || return 0;

    if ($defres and %{$Conf{imports}}) {
        &Ecomm::PrintTerminal(1,11,84,1,1,'Using current namelist.wps geog_data_res values with --imports');
        return 0;
    }

    #  So we know that the --defres flag was passed, but what about the 
    #  individual terrestrial dataset flags? Below are the UEMS defaults.
    #
    $Conf{landuse} = 'default'    unless $Conf{landuse};
    $Conf{lakes}   = -1           unless $Conf{lakes} == 1;
    $Conf{topo}    = 'default'    unless $Conf{topo};
    $Conf{gfrac}   = 'default'    unless $Conf{gfrac};
    $Conf{stype}   = 'default'    unless $Conf{stype};
    $Conf{gwdo}    = 0            unless $Conf{gwdo};

return $defres;
}


sub Config_global {
#===============================================================================
#  Define the value for global, which become a bit complicated since if the 
#  global flag is not passed then the contents of the namelist.wps file will
#  determine whether this is a global domain but that in formation is not
#  available yet.
#===============================================================================
#
    my $global = $Udomain{OPTIONS}{GLOBAL} ? 1 : 0;

    &Ecomm::PrintTerminal(1,11,84,1,1,'Thinking outside the box!  This will be a global domain.') if $global;

return $global;
}


sub Config_gnests {
#===============================================================================
#  Define the value for --g_nests, which is only used with global domains to
#  specify any nested domains. The argument is a comma or semi-colon sepatared
#  list of parameters used to define the navigation for each nest.  Each nest
#  is defined by colon-separated numeric values,
#
#    <Parent ID>:<Start Lat>:<Start Lon>:<NX>:<NY>:<Ratio>
#
#  Where,
#
#    Parent ID  - The ID number of the parent domain (1 ... N)
#    Start Lat  - The Latitude  of Point 1,1 (SW corner)
#    Start Lon  - The Longitude of Point 1,1 (SW corner; use Neg for degrees West)
#    NX         - The number of grid points in the NX direction (adjusted to parent points)
#    NY         - The number of grid points in the NY direction (adjusted to parent points)
#    Ratio      - The ratio of child to parent grid points (either 3 or 5; no 7)
#===============================================================================
#
    my $mesg    = qw{};
    my @gnests  = ();
    my %g_nhash = (); $g_nhash{1} = 'defined'; #  Need to populate domain 1 with something

    my $g_nests = $Udomain{OPTIONS}{G_NESTS} || return 0;

    
    my $dom = 2;
    foreach (split /;|,/ => $g_nests) {s/ //g; next unless $_;

        my ($par,$slat,$slon,$nx,$ny,$ratio) = split /:/ => $_;

        #  Check whether only numerical values are used
        #
        my $ok=1;
        for ($par,$slat,$slon,$nx,$ny,$ratio) {$ok = $ok * &Others::isNumber($_); $_ = '<missing>' unless $_;}

        $mesg = "One or more of your values passed to \"--g_nests\" does not appear to be a number:\n\n".
                "  <Parent ID>:<Start Lat>:<Start Lon>:<NX>:<NY>:<Ratio>\n\n".

                "        ${par}  :    ${slat}   :   ${slon}  :   ${nx}  :   ${ny}  :   ${ratio}\n\n".
                "Correct this problem and then try again.";

        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'All numeric values please',$mesg)) unless $ok;


        
        #  Make sure $par, $nx, $ny, and $ratio are integers
        #
        $slat  = 1.0*$slat;
        $slon  = 1.0*$slon;

        $par   = int $par;
        $nx    = int $nx;
        $ny    = int $ny;
        $ratio = int $ratio;
       


        #  Make sure the Parent domain has been identified
        #
        $mesg = "The specified parent domain ($par) for domain $dom has not yet been defined. Did you make a mistake ".
                "in specifying the domain information with the --g_nests option?  Here is the offending ".
                "argument:\n\n".

                "  <Parent ID>:<Start Lat>:<Start Lon>:<NX>:<NY>:<Ratio>\n\n".

                "     ${par}  :    ${slat}   :   ${slon}  :   ${nx}  :   ${ny}  :   ${ratio}";

        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'A Child Domain in Need of a Parent',$mesg)) unless defined $g_nhash{$par};


        #  Check the Parent:Child grid Ratio
        #
        $mesg = "Sorry, but the parent to child grid ratio ($ratio) for domain $dom must be either 3 or 5.";
        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,114,0,0,'Bad Parent:Child Ratio',$mesg)) unless $ratio == 3 || $ratio == 5;


        
        #  Make sure the latitude & longitude values are OK.
        #
        $mesg = "The value of the Start Longitude ($slon) for domain $dom must be between -180.0 and 180.0 degrees (Neg for degrees West).";
        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,114,0,0,'Incorrect Value for Longitude:',$mesg)) if $slon < -180.0 || $slon > 180.0;


        $mesg = "The value of the Start Latitude ($slat) for domain $dom must be between -89.0 and 89.0 degrees.";
        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,114,0,0,'Incorrect Value for Latitude:',$mesg)) if $slat < -89.0 || $slat > 89.0;


        my $domain   = join ':' => ($par,$slat,$slon,$nx,$ny,$ratio);
        push @gnests => $domain;

        $dom++;
    }

    $g_nests = join ';' => @gnests;


return $g_nests;
}


sub Config_gdxdy {
#===============================================================================
#  Define the value for --g_dxdy, which is only used with global domains. 
#===============================================================================
#
    my $g_dxdy = $Udomain{OPTIONS}{G_DXDY} || return 0;

    my $mesg = "It is certainly out of character for you to make this simple mistake, but as a reminder, ".
               "you can not pass both the \"--g_ny|nx\" and \"--g_dxdy\" flags together. The way this operation works is ".
               "that when you pass one, I get to calculate the other. We are a team that enjoys sharing ".
               "the workload, no matter how easy it is to complete your tasks.";

    &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'Our Team is Strong',$mesg)) if $Udomain{OPTIONS}{G_NX} || $Udomain{OPTIONS}{G_NY};


return $g_dxdy;
}


sub Config_gnx {
#===============================================================================
#  Define the value for --g_nx, which is only used with global domains
#===============================================================================
#
    my $g_nx = $Udomain{OPTIONS}{G_NX} || return 0;

    my $mesg = "It is certainly out of character for you to make this simple mistake, but as a reminder, ".
               "you can not pass both the \"--g_ny|nx\" and \"--g_dxdy\" flags together. The way this operation works is ".
               "that when you pass one, I get to calculate the other. We are a team that enjoys sharing ".
               "the workload, no matter how easy it is to complete your tasks.";

    &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'But I Still Forgive You:',$mesg)) if $Udomain{OPTIONS}{G_DXDY};


return $g_nx;
}


sub Config_gny {
#===============================================================================
#  Define the value for --g_ny, which is only used with global domains
#===============================================================================
#
    my $g_ny = $Udomain{OPTIONS}{G_NY} || return 0;

    my $mesg = "It is certainly out of character for you to make this simple mistake, but as a reminder, ".
               "you can not pass both the \"--g_ny|nx\" and \"--g_dxdy\" flags together. The way this operation works is ".
               "that when you pass one, I get to calculate the other. We are a team that enjoys sharing ".
               "the workload, no matter how easy it is to complete your tasks.";

    &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'But I Still Forgive You:',$mesg)) if $Udomain{OPTIONS}{G_DXDY};


return $g_ny;
}


sub Config_guseny {
#===============================================================================
#  Define the value for --g_useny, which is only used with global domains
#===============================================================================
#
    my $g_useny = $Udomain{OPTIONS}{G_USENY}  || return 0;

return $g_useny;
}


sub Config_passvalue {
#===============================================================================
#  Simply transfer the value from the OPTIONS hash for the final configuration
#===============================================================================
#
    my $field = shift;

return $Udomain{OPTIONS}{$field};
}


sub Config_domains {
#===============================================================================
#  Pretty simple routine in that all it does is initialize the @{$Conf{domains}}
#  array used to loop throug the domains to process.  The output will either
#  be the contents of $Conf{rundir} or an empty hash if --import was passed,
#  in which case @{$Conf{domains}} will be populated in Dmain::DomainProcess
#  before entering the loop.
#===============================================================================
#

return $Conf{rundir} ? ($Conf{rundir}) : ();
}


sub Config_activate {
#===============================================================================
#  A Final check to ensure the user has specified something to be done. It's
#  possible to pass a bunch of minor flags but not one of the primary ones.
#===============================================================================
#   
    my $mesg = qw{};

    $mesg = "You can pass all the flags you want, but unless you include \"--create\", \"--localize\", ".
            "\"--refresh\", \"--restore\", \"--info\", or \"--import\", you leave me with ".
            "nothing to do other than to gaze into your beautiful eyes.\n\n".

            "Better yet, try passing the \"--help\" flag.";

    unless (%{$Conf{imports}} or $Conf{create} or $Conf{localize} or $Conf{refresh} or $Conf{restore} or $Conf{info}) {
        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,"I'm Still Here For You:",$mesg));
    }


    if ($Conf{create}) { 
        #  If the --create flag was passed then turn off any flags that might cause issues or
        #  otherwise are not necessary.
        #
        my @notallowed = qw(benchmark refresh restore scour);
        $Conf{$_} = 0 foreach @notallowed;  %{$Conf{imports}} = ();
    }


    if (%{$Conf{imports}} and ($Conf{rotate}  || $Conf{gwdo}    || $Conf{g_nests} || $Conf{g_dxdy} || $Conf{g_nx} || $Conf{g_ny} ||
                               $Conf{g_useny} || $Conf{landuse} || $Conf{lakes}   || $Conf{gfrac}  || $Conf{topo} || $Conf{stype})) {
    
        $mesg = "Since you are passing the \"--import\" flag, I am turning off any minor domain configuration flags that you ".
                "might have included for good measure. These flags are intended for use when running ems_domain from a run-time ".
                "directory and should not be applied to across multiple domains.\n\n".

                "The minor flags include: --rotate, --gwdo, --lakes, --landuse, --topo, --gfrac, --stype and any global domain flags ".
                "(--g_nests, g_dxdy, --g_nx, --g_ny, --g_useny).\n\n".

                "Should you feel strongly about using these flags then it's recommended that you apply them to the domains individually.";

        &Ecomm::PrintTerminal(6,11,104,2,2,"Some flags have been turned off for your convenience:",$mesg);

        $Conf{$_}    = 0 for qw(rotate gwdo landuse topo gfrac stype lakes global g_nests g_dxdy g_nx g_ny g_useny);
    }

        
return;
}


