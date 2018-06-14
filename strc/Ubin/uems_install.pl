#!/usr/bin/perl 
#=======================================================================================
#
#         FILE:  uems_install.pl
#
#  DESCRIPTION:  The uems_install.pl routine's lone purpose in life is to satisfy
#                all your UEMS installation and updating needs.
#
#                Should you have any questions, I encourage you to seek the truth
#                by passing the "--help" flag, reading the UEMS user's guide, or
#                asking for help. Something is eventually bound to work.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.04.4
#      CREATED:  25 January 2018
#=======================================================================================
#
use warnings;
use strict;
require 5.008;
use English;

use vars qw (%UEMSinstall $mesg);
#  =====================================================================================
#    The front end to the UEMS installation routine simply initializes a few necessary
#    variables before execution begins - Fortunately for you, it's not your's.
#  =====================================================================================
#
use subs qw(SysIntHandle SysReturnHandler SysDied);

    #  ---------------------------------------------------------------------------------
    #  Override interrupt intHandle - Use the local one since some of the 
    #  environment variables are needed for clean-up after the interrupt.
    #  ---------------------------------------------------------------------------------
    #
    $SIG{INT} = \&SysIntHandle;

    &UEMS_Initialize();

    &UEMS_Greeting();

    SysReturnHandler &UEMS_ParseOptions();

    SysReturnHandler &UEMS_PackageList();

    SysReturnHandler &UEMS_SystemInstall();

    SysReturnHandler &UEMS_SystemUpdate();

    SysReturnHandler &UEMS_SystemAddpacks();


CORE::exit 0;
#  =====================================================================================
#    The main UEMS installation routines are located below - Way Cool
#  =====================================================================================
#



sub UEMS_Greeting {
#----------------------------------------------------------------------------------
#  Prints a greeting to the user
#----------------------------------------------------------------------------------
#
    &PrintMessage(0,2,96,2,1,"Greetings irrefutably intelligent and devastatingly good-looking UEMS user!");

    $mesg = "Welcome to the NWS SOO Science and Training Resource Center (SOO/STRC) Universal ".
            "Environmental Modeling System (UEMS) installation and update routine.\n\n".
            "Phew! That's more than a mouthful.";
    &PrintMessage(0,4,94,1,2,$mesg);

return;
}


sub UEMS_Initialize {
#  ==================================================================================
#  Initialize some of the values used for the installation process
#  ==================================================================================
#
use Cwd;

    %UEMSinstall = ();

    my $VER  = '18.04.4';
    my $TOP  = 'uems';

    my $EXE  = &popit($0);
    my $PEXE = cwd;    chomp $PEXE; $PEXE = "$PEXE/$EXE";
    my $DATE = gmtime; chomp $DATE; $DATE = "$DATE UTC";

    #  ----------------------------------------------------------------------------------
    #  Determine whether there is a UEMS on the system and, if possible, the version.
    #  Also attempt to determine the state of the installation, i.e, whether it's
    #  a full or partial (failed) installation.
    # 
    #  The DEMSDIR (Default UEMS home directory) will be defined as $EMSROOT/$TOP and 
    #  IEMSDIR (currently installed UEMS home directory) will be defined as 
    #  $IROOT/$ITOP.  They may be the same but are here should the user elects to 
    #  rename the installation.
    #  ----------------------------------------------------------------------------------
    #
    my $IEMS  = (defined $ENV{UEMS} and $ENV{UEMS} and -e $ENV{UEMS}) ? $ENV{UEMS} : 0;

    my ($IROOT, $ITOP)       =  $IEMS  ? &popit2($IEMS) : (0,0);
    my $EMSROOT              =  $IROOT ? $IROOT : 0;
    my $DEMSDIR              =  $IROOT ? "$IROOT/$TOP" : 0;

    $UEMSinstall{UEMSTOP}    =  $TOP;      #  The directory name containing the UEMS - Currently 'uems'
    $UEMSinstall{UEMSHOME}   =  $DEMSDIR;  #  The default location for the UEMS ($root/$top)

    %{$UEMSinstall{IEMS}}    =  &CollectUemsInfo($IEMS);


    #  ----------------------------------------------------------------------------------
    #  Define the UEMS servers
    #  ----------------------------------------------------------------------------------
    #
    @{$UEMSinstall{SERVERS}} =  qw (ems1.comet.ucar.edu ems2.comet.ucar.edu ems3.comet.ucar.edu);


    #  ----------------------------------------------------------------------------------
    #  Define the optional UEMS packages
    #  ----------------------------------------------------------------------------------
    #
    @{$UEMSinstall{OPTPKGS}} =  qw (nawips workshop source xgeog);
    @{$UEMSinstall{XGEOGS}}  =  qw (gtopo nlcd2006 nlcd2011);

    #  ----------------------------------------------------------------------------------
    #  Set default language to English because the UEMS attempts to match English
    #  words when attempting to get system information.
    #  ----------------------------------------------------------------------------------
    #
    $ENV{LC_ALL} = 'C';


    #  ----------------------------------------------------------------------------------
    #  Eventially, CORE will have a flag with options but for now ARW is the only one.
    #  ----------------------------------------------------------------------------------
    #
    $UEMSinstall{CORE}       = 'arw';

    $UEMSinstall{DATE}       =  $DATE;     #  The current system date and time

    $UEMSinstall{EXE}        =  $EXE;      #  The name of of uems_install.pl, just in case its changed
    $UEMSinstall{PEXE}       =  $PEXE;     #  The path to uems_install.pl, or CWD
    $UEMSinstall{VERSION}    =  $VER;      #  The version number of uems_install.pl

    $UEMSinstall{EMSPRV}     =  0;         #  Will eventually contain the path to a previous release, if any

    @{$UEMSinstall{RN}}      =  qw (I. II. III. IV. V. VI. VII. VIII. IX. X. XI. XII.);
    @{$UEMSinstall{AB}}      =  qw (A. B. C. D. E. F. G. H. I. J. K. L. M. N. O. P. Q. R. S. T. U. W. X. Y. Z. Aa. Ab. Ac. Ad. Ae. Af. Ag. Ah. Ai. Aj. Ak. Al. Am. An. Ao. Ap. Aq. Ar. As. At.);
    @{$UEMSinstall{DYKS}}    =  &GetDidYouKnow();

    %{$UEMSinstall{ISYS}}    =  &CollectSystemInfo();

    %{$UEMSinstall{IUSER}}   =  &CollectUserInfo($<);    #  Get information about the installer

    %{$UEMSinstall{EUSER}}   =  %{$UEMSinstall{IUSER}};  #  Until told otherwise


return;
}


sub UEMS_ParseOptions {
#  ==================================================================================
#  The UEMS_ParseOptions routine parses the flags and options passed
#  from the command line. Simple enough.
#  ==================================================================================
#
use Getopt::Long qw(:config pass_through);
use Time::Local;

    my %Option = ();


    GetOptions ("allyes"             => \$Option{ALLYES},      #  Respond to yes to ALL questions - Used for automated updates
                "curl"               => \$Option{CURL},        #  Use curl for http requests
                "continue"           => \$Option{CONTINUE},    #  Continue download and installation from a previous attempt
                "debug|d"            => \$Option{DEBUG},       #  For debugging
                "dvd:s"              => \$Option{DVD},         #  Location of the DVD mount point for DVD installation
                "emshome:s"          => \$Option{EMSHOME},     #  The top level directory for the UEMS installation
                "force"              => \$Option{FORCE},       #  Force the installation of and update or release
                "h|help|?"           => sub {&GetHelpPlease(@ARGV)},   #  Just what the doctor ordered
                "emshost:s"          => \$Option{EMSHOST},     #  The hostname of the server from which to get the UEMS files
                "import:s"           => \@{$Option{IMPORTS}},  #  Import domains from existing UEMS installation
                "install:s"          => \$Option{INSTALL},     #  Fresh install a release
                "list"               => \$Option{LIST},        #  Use --install list    or --update list
                "listall"            => \$Option{LISTALL},     #  Use --install listall or --update listall
                "nogeog"             => \$Option{NOGEOG},      #  Do not download and install the default geographic datasets
                "noruns"             => \$Option{NORUNS},      #  Do not import computational domains from $UEMS/runs (--install only)
                "nolocal"            => \$Option{NOLOCAL},     #  Get the files again from the server and ignore local copy
                "nounpack"           => \$Option{NOUNPACK},    #  Do not unpack the files after downloading
                "addpack:s"          => \@{$Option{ADDPACK}}, #  Allows users to include a non-default package
                "xgeog:s"            => \@{$Option{XGEOGS}},   #  Download and install the additional geographic datasets not included as default
                "proxy:s"            => \$Option{PROXY},       #  Set the environment if a proxy server is used
                "relsdir:s"          => \$Option{RELDIR},      #  Override the default location for the release files
                "repodir:s"          => \$Option{REPODIR},     #  Location or local repository for the update and release
                "norefresh"          => \$Option{NOREFRESH},   #  Do not refresh (update) the configuration files in each domain directory
                "scour"              => \$Option{SCOUR},       #  Delete the existing release rather than rename it
                "update:s"           => \$Option{UPDATE},      #  Update to the requested release
                "updtdir:s"          => \$Option{UPDIR},       #  Override the default location for the update files
                "version"            => sub {&PrintVersion()}, #  Print out the version of the installation script and get out
                "wget"               => \$Option{WGET}         #  Use wget for http requests
               );  &GetHelpPleaseError(@ARGV) if @ARGV;



    #  Make sure that one and only one of the primary flags are passed
    #
    return 1 unless %Option = &StartSanityCheck(\%Option);



    #  --------------------------------- Attempt the configuration --------------------------------------------
    #
    #  Note that the order for some configurations is important!
    #
    %{$UEMSinstall{OPTION}} = ();

    $UEMSinstall{UEMSHOME}             =  &StartCallOption('emshome'  ,$Option{EMSHOME});

    $UEMSinstall{OPTION}{allyes}       =  &StartCallOption('allyes'   ,$Option{ALLYES});
    $UEMSinstall{OPTION}{nolocal}      =  &StartCallOption('nolocal'  ,$Option{NOLOCAL});
    $UEMSinstall{OPTION}{debug}        =  &StartCallOption('debug'    ,$Option{DEBUG});   #  Order Dependent
    $UEMSinstall{OPTION}{list}         =  &StartCallOption('list'     ,$Option{LIST});    #  Deprecated as flag but still in use
    $UEMSinstall{OPTION}{listall}      =  &StartCallOption('listall'  ,$Option{LISTALL}); #  Deprecated as flag but still in use
    $UEMSinstall{OPTION}{updatedir}    =  &StartCallOption('updtdir'  ,$Option{UPDIR});
    $UEMSinstall{OPTION}{releasedir}   =  &StartCallOption('relsdir'  ,$Option{RELDIR});
    $UEMSinstall{OPTION}{update}       =  &StartCallOption('update'   ,$Option{UPDATE});
    $UEMSinstall{OPTION}{install}      =  &StartCallOption('install'  ,$Option{INSTALL});
    $UEMSinstall{OPTION}{nogeog}       =  &StartCallOption('nogeog'   ,$Option{NOGEOG});   #  Order Dependent
    $UEMSinstall{OPTION}{noruns}       =  &StartCallOption('noruns'   ,$Option{NORUNS});   #  Order Dependent
    $UEMSinstall{OPTION}{force}        =  &StartCallOption('force'    ,$Option{FORCE});    #  Order Dependent
    $UEMSinstall{OPTION}{proxy}        =  &StartCallOption('proxy'    ,$Option{PROXY}); 
    $UEMSinstall{OPTION}{dvd}          =  &StartCallOption('dvd'      ,$Option{DVD});
    $UEMSinstall{OPTION}{scour}        =  &StartCallOption('scour'    ,$Option{SCOUR});
    $UEMSinstall{OPTION}{continue}     =  &StartCallOption('continue' ,$Option{CONTINUE});
    $UEMSinstall{OPTION}{nounpack}     =  &StartCallOption('nounpack' ,$Option{NOUNPACK});
    $UEMSinstall{OPTION}{refresh}      =  &StartCallOption('norefresh',$Option{NOREFRESH});
    @{$UEMSinstall{OPTION}{repodirs}}  =  &StartCallOption('repodir'  ,$Option{REPODIR});
    @{$UEMSinstall{OPTION}{imports}}   =  &StartCallOption('import'   ,@{$Option{IMPORTS}});
    %{$UEMSinstall{EMSHOSTS}}          =  &StartCallOption('emshost'  ,$Option{EMSHOST});
    @{$UEMSinstall{OPTION}{xgeogs}}    =  &StartCallOption('xgeog'    ,@{$Option{XGEOGS}});
    $UEMSinstall{OPTION}{addpacks}     =  &StartCallOption('addpack'  ,@{$Option{ADDPACK}});
    %{$UEMSinstall{OPTION}{methods}}   =  &StartCallOption('methods'  ,($Option{CURL},$Option{WGET}));

    $ENV{HTTP_PROXY} = $UEMSinstall{PROXY} if $UEMSinstall{PROXY};


return -1;  #  Value < 0 is good
}


sub UEMS_PackageList {
#==================================================================================
#   This routine calls the appropriate routine to get the UEMS package list,
#   then subset the list based upon the user request.
#==================================================================================
#
     #  ---------------------------------------------------------------------------
     #  Begin by checking for an available source for the package files.
     #  ---------------------------------------------------------------------------
     #
     $UEMSinstall{EMSHOST} = &GetAvailableServer();


     my $rv = $UEMSinstall{EMSHOST} ? &GetPackageListRemote()
                                    : &GetPackageListLocal();

    &PrintPackageList() if $UEMSinstall{OPTION}{list};

    #  ---------------------------------------------------------------------------
    #  While we are here, apply the include packages to the file lists. Since
    #  the lists contain all the package tar files, this process serves to 
    #  just remove files. Note that the exclusion-inclusion only applies during 
    #  installation.
    #  ---------------------------------------------------------------------------
    #
    my @excludes = ();
    my @includes = ();
    my $exclude  = ' ';
    my $include  = ' ';

    if ($UEMSinstall{OPTION}{addpacks}) {
        $include  = $UEMSinstall{OPTION}{addpacks}; $include =~ s/,/|/g;
        unless ($include eq 'none') {
            foreach my $key (keys %{$UEMSinstall{RELEASES}}) {
                @includes = grep {/$include/} keys %{$UEMSinstall{RELEASES}{$key}};
                @{$UEMSinstall{ADDPACKS}{$key}}{@includes} = @{$UEMSinstall{RELEASES}{$key}}{@includes};
            }
        }
        %{$UEMSinstall{RELEASES}} = ();
    }


    if ($UEMSinstall{OPTION}{install}) {
        @excludes = &ArrayDifference(@{$UEMSinstall{XGEOGS}},@{$UEMSinstall{OPTPKGS}});

        push @excludes, 'wrf.geog_' if $UEMSinstall{OPTION}{nogeog};  #  Exclude all geog files with --nogeog
        $exclude  = @excludes ? join '|', @excludes : ' ';  #  Create a regex pattern for the strings to exclude

        foreach my $key (keys %{$UEMSinstall{RELEASES}}) {
            @excludes = grep {/$exclude/} keys %{$UEMSinstall{RELEASES}{$key}};
            delete @{$UEMSinstall{RELEASES}{$key}}{@excludes};
        }
    }

    
    if ($UEMSinstall{OPTION}{update}) {

        @includes = qw(nawips source workshop gtopo nlcd2006 nlcd2011);
        @excludes = grep { ! $UEMSinstall{IEMS}{$_} } @includes;
        $exclude  = @excludes ? join '|', @excludes : ' ';

        foreach my $key (keys %{$UEMSinstall{UPDATES}}) {
            @excludes = grep {/$exclude/} keys %{$UEMSinstall{UPDATES}{$key}};
            delete @{$UEMSinstall{UPDATES}{$key}}{@excludes};
        }
    }


    #  ---------------------------------------------------------------------------
    #  DEBUG: Print out the package list  - must be changed for new %hash
    #  ---------------------------------------------------------------------------
    #
    if ($UEMSinstall{OPTION}{debug}) {
        foreach my $key (keys %{$UEMSinstall{ADDPACKS}}) {print "ADDPACK: $key PACKAGES: \n\n"; &PrintHash(\%{$UEMSinstall{ADDPACKS}{$key}});}
        foreach my $key (keys %{$UEMSinstall{RELEASES}}) {print "RELEASE: $key PACKAGES: \n\n"; &PrintHash(\%{$UEMSinstall{RELEASES}{$key}});}
        foreach my $key (keys %{$UEMSinstall{UPDATES}})  {print "UPDATE:  $key PACKAGES: \n\n"; &PrintHash(\%{$UEMSinstall{UPDATES}{$key}});}
    }

    
return $UEMSinstall{OPTION}{list} ? 0 : $rv;
}


sub StartCallOption {
#----------------------------------------------------------------------------------
#  This routine manages the configuration of each user option/flag.  It's basically
#  just an interface to the individual option configuration routines.
#----------------------------------------------------------------------------------
#
    my $option = q{};
    my @args   = ();

    ($option, @args) = @_;

    for ($option) {

        return  &Options_addpack(@args)   if /^addpack$/;
        return  &Options_allyes(@args)    if /^allyes$/;
        return  &Options_continue(@args)  if /^continue$/;
        return  &Options_debug(@args)     if /^debug$/;
        return  &Options_dvd(@args)       if /^dvd$/;
        return  &Options_emshost(@args)   if /^emshost$/;
        return  &Options_emshome(@args)   if /^emshome$/;
        return  &Options_force(@args)     if /^force$/;
        return  &Options_xgeog(@args)     if /^xgeog$/;
        return  &Options_import(@args)    if /^import$/;
        return  &Options_install(@args)   if /^install$/;
        return  &Options_list(@args)      if /^list$/;
        return  &Options_listall(@args)   if /^listall$/;
        return  &Options_listgeog(@args)  if /^listgeog$/;
        return  &Options_methods(@args)   if /^methods$/;
        return  &Options_nogeog(@args)    if /^nogeog$/;
        return  &Options_noruns(@args)    if /^noruns$/;
        return  &Options_nolocal(@args)   if /^nolocal$/;
        return  &Options_nounpack(@args)  if /^nounpack$/;
        return  &Options_package(@args)   if /^package$/;
        return  &Options_proxy(@args)     if /^proxy$/;
        return  &Options_norefresh(@args) if /^norefresh$/;
        return  &Options_relsdir(@args)   if /^relsdir$/;
        return  &Options_repodir(@args)   if /^repodir$/;
        return  &Options_scour(@args)     if /^scour$/;
        return  &Options_update(@args)    if /^update$/;
        return  &Options_updtdir(@args)   if /^updtdir$/;

    }


#  You are here only because something went wrong!
#
&SysDied("Something smells funny again (--$option) and it ain\'t me!");

return;  #  We should never get here but somehow destiny has brought us together!
}


sub StartSanityCheck {
#  ==================================================================================
#  Make sure the user is not mixing the primary flags or doing something
#  otherwise foolish.
#  ==================================================================================
#
    my $href   = shift;
    my %option = %{$href};

    #  ------------------------------------------------------------------------------
    #  Make sure installation is on a x64 Linux OS
    #  ------------------------------------------------------------------------------
    #
    $mesg = "The UEMS is designed for a 64-bit (x86_64) machine architecture; however, it appears ".
            "this system OS is 32-bit. While this activity might be accepted by a lesser modeling ".
            "system, the UEMS will not let you do this to yourself.\n\n".
            "And you shall NOT be having any pudding after dinner tonight!";

    &SysDied($mesg) if $UEMSinstall{ISYS}{hwtype} ne 'x86_64';



    #  ------------------------------------------------------------------------------
    #  Make sure user is not as confused as the developer 
    #  ------------------------------------------------------------------------------
    #
    my $n=0; for ('UPDATE', 'INSTALL') {$n++ if defined $option{$_};}
       $n++  if @{$option{ADDPACK}};
    $mesg = "This is not a \"McSloppy Burger\", so you can't have it \"Your Way\"!\n\n".
            "It's either \"--update\" or \"--install\" or \"--addpack\", but not any\ncombination thereof.\n\n".
            "If you have questions and feel hand-holding is in order, pass the \"--help\" ".
            "flag:\n\n  %  $UEMSinstall{EXE} --help ";

    &SysDied($mesg) if $n > 1;


   $mesg = "What do you want from me?\n\n".
            "You must pass either \"--update\" or \"--install\" or \"--addpack\" when running $UEMSinstall{EXE}:\n\n".
            "    % $UEMSinstall{EXE} --install [release version] [list|listall|info]\n".
            "Or\n".
            "    % $UEMSinstall{EXE} --update  [release version] [list|listall|info]\n".
            "Or\n".
            "    % $UEMSinstall{EXE} --addpack <nawips|workshop|source|xgeog> \n\n".
            "The release version is optional as the default is the most current release.\n\n".
            "Also, more hand-holding is provided by passing the \"--help\" flag, i.e.,\n\n    % $UEMSinstall{EXE} --help ";

    &SysDied($mesg) unless $n;


    $mesg = "The use of \"--list\" and \"--listall\" have been integrated into the \"--install\" and \"--update\" flags, ".
            "depending what you want from me:\n\n".
            "    %  $UEMSinstall{EXE}  --install  list|listall|listgeog\n".
            "Or\n".
            "    %  $UEMSinstall{EXE}  --update   list|listall\n\n".
            "Let\'s go - show me what you got!";

    &SysDied($mesg) if defined $option{LIST} or $option{LISTALL};


    #  --------------------------------------------------------------------------------
    #    At this point the UEMS directory has been created on the local system. Now
    #    collect the system information to determine which release files to download.
    #  --------------------------------------------------------------------------------
    #
    if ((defined $option{UPDATE} or @{$option{ADDPACK}}) and ! $UEMSinstall{IEMS}{emsver}) {
       $mesg = "I'm not pointing any fingers, but I'm unable to determine the release number of the ".
               "current UEMS installation, which is necessary when using the \"--update\" or \"--addpacks\" ".
               "flags. Consequently, I'm unwilling to participate in this little experiment.\n\n".
               "The release number should be located in the $UEMSinstall{UEMSTOP}/strc/.release file.";
       &SysDied($mesg);
    }


return %option;
}


sub Options_allyes {
#----------------------------------------------------------------------------------
#  Define the value for option "--allyes"
#----------------------------------------------------------------------------------
#
    my $passed = shift;

return defined $passed ? 1 : 0;
}


sub Options_continue {
#----------------------------------------------------------------------------------
#  Define the value for option "--continue"
#----------------------------------------------------------------------------------
#
    my $passed = shift;

    $passed = (defined $passed) ? 1 : 0;

return $passed;
}


sub Options_debug {
#----------------------------------------------------------------------------------
#  Define the value for option "--debug"
#----------------------------------------------------------------------------------
#
    my $passed = shift;

return defined $passed ? 1 : 0;
}


sub Options_dvd {
#----------------------------------------------------------------------------------
#  Define the value for option "--dvd"
#----------------------------------------------------------------------------------
#
use File::Spec;

    my $passed = shift;

    $passed    = File::Spec->curdir() if -e '.dvd';

    return 0 unless defined $passed;

    $passed = $passed ? File::Spec->canonpath($passed) : 0;

    $mesg =  "You have passed the \"--dvd\" option but you are not running $UEMSinstall{EXE} ".
             "from the fabulous UEMS DVD or you did not include the path to the DVD mount point ".
             "as an argument.\n\n".

             "You can\'t pull the wool over my eyes, unless it\'s cashmere. I love cashmere.";

    &SysDied($mesg) unless $passed;


    $UEMSinstall{OPTION}{workshop} = 1;
    $UEMSinstall{OPTION}{install}  = 'current';
    $UEMSinstall{OPTION}{repodir}  = $passed;
    $UEMSinstall{OPTION}{update}   = 0;


    $mesg =  "You have passed the \"--dvd\" option; however, I am unable to locate and ".
             "release files on the DVD (looking in $UEMSinstall{OPTION}{repodir})\n\n".
             "What's up with that?!";

    &SysDied($mesg) unless -d $UEMSinstall{OPTION}{repodir};


return $passed;
}


sub Options_emshome {
#----------------------------------------------------------------------------------
#  Define the value for option "--emshome".  This should be the path to the
#  directory where $UEMSinstall{UEMSTOP} will reside and not the value for $EMS
#----------------------------------------------------------------------------------
#
use Cwd;

    my $passed = shift; $passed = 0 unless defined $passed;

    return $UEMSinstall{UEMSHOME} unless $passed;  #  Set the default

    #  Need to check whether $passed is a link and does it point to anything
    #
    if (-l $passed) {  #  A link
        my $linked = Cwd::realpath($passed);
        &rm($passed) unless -d $linked;
    }

    #  If $passed leads to a full UEMS installation then split out the root path from the
    #  top level directory name.
    #
    my ($path, $dir) = &popit2($passed);

    #  If it's an existing UEMS directory
    #
    $passed = $path if -e "$passed/strc" and -e "$passed/util";
    $passed = $path if $dir and ($dir eq $UEMSinstall{UEMSTOP} or $dir eq 'uems');

    &SysDied("Hey - We've only just begun and you go and provide me with an invalid directory:\n\n".
             "    --emshome $passed\n\nLet's try this again") unless -d $path;

    &SysDied("Hey Big Shot - You DO NOT have write permission on $path (--emshome $path)!") unless -w $path;

    $passed = "$path/$UEMSinstall{UEMSTOP}";

return $passed;
}


sub Options_emshost {
#----------------------------------------------------------------------------------
#  Define the value for the --emshost flag as well as the host list
#----------------------------------------------------------------------------------
#
    my %emshosts=();
    my %emshash =();
    my %lochash =(); $lochash{local} = 0;

    foreach my $ehost (@{$UEMSinstall{SERVERS}}) {(my $shost = $ehost) =~ s/\.comet\.ucar\.edu//g; $emshash{$shost} = $ehost;}


    #  Passed is the name of the requested host.
    #
    my $host = shift;

    #  If either the REPODIR or DVD flags are ON then assume this is a local job and the UEMS
    #  servers will not be accessed.
    #
    if (@{$UEMSinstall{OPTION}{repodirs}} or $UEMSinstall{OPTION}{dvd}) {%emshosts = %lochash; return %emshosts;}

    unless (defined $host and $host) {%emshosts = %emshash; return %emshosts;}

    #  A hostname was passed so make sure its valid before returning.
    #
    $host = lc $host; $host =~ s/\.comet\.ucar\.edu//g;

    #  If "local" was passed
    #
    if ($host eq 'local') {%emshosts = %lochash; return %emshosts;}

    #  If name of host was passed
    #
    &SysDied("Sorry to be a pest but \"$host\" if not an UEMS server (ems1, ems2, ems3).") unless defined $emshash{$host};

    $emshosts{$host} = $emshash{$host};


return %emshosts;
}


sub Options_force {
#----------------------------------------------------------------------------------
#  Define the value for option "--force"
#----------------------------------------------------------------------------------
#
    my $passed = shift;

return defined $passed ? 1 : 0;
}


sub Options_xgeog  {
#----------------------------------------------------------------------------------
#   The --xgeog flag allows the user to download one or more of the large static
#   geographic datasets that are not part of the default dataset download. The
#   argument to --xgeog is a string, i.e, "--xgeog <string>" that will matched to
#   one of the available wrf.geog_* files on the specified repository. If no 
#   arguments are passed then ALL the terrestrial data sets defined in 
#   @{$UEMSinstall{XGEOGS}} are installed.
#----------------------------------------------------------------------------------
#
use List::Util 'first';

    my @xgeogs = ();
    my @passed = @_;  return () unless @passed;

    $mesg = "I'm sure this is just a misunderstanding between you and your large brain. The ".
            "\"--xgeog\" flag is not available when doing an update. You can only use this ".
            "flag with \"--install\".";

    &SysDied($mesg) if $UEMSinstall{OPTION}{update};

    return @{$UEMSinstall{XGEOGS}} unless $passed[0];

    #  Clean up list of arguments
    #
    my $list = join ',' => @passed; @passed = split /,|;|:/, $list;

    my @filtered = ();
    foreach (@passed) {
        $_ = lc $_;
        s/\.tbz|\.tgz|\.tar|\.gz|\.zip|\.bzip//g;
        next unless $_;
        push @filtered => $_;
    }
    @filtered  = &rmdups(@filtered);

    foreach my $arg (@filtered) {my @valids = grep {/$arg/} @{$UEMSinstall{XGEOGS}}; @xgeogs = (@xgeogs,@valids);}
    @xgeogs = &rmdups(@xgeogs);

    $mesg = "Well, it appears that you passed the \"--xgeog\" flag but something went horribly wrong while ".
            "filtering your requests leaving you with no geographic datasets to download. I know this is not ".
            "what you intended so why don't you check your arguments and try again.";

    &SysDied($mesg) unless @xgeogs;


return reverse @xgeogs;
}


sub Options_import {
#----------------------------------------------------------------------------------
#   The "--import" flag allows users to specify any existing computational
#   domain directories that reside outside of a new installation, to be made
#   available for use. This includes the copying (rsync) of domain directories
#   into the "uems/runs" directory, updating the configuration files, and then
#   relocalizing the each domain.
#
#   The argument to --import may be a path to the directory containing the domain
#   directories or to a single domain. The --import flag doesn't care.
#
#   The routine returns an array containing all domains to be imported.
#----------------------------------------------------------------------------------
#
use Cwd;

    my @passed = @_;  return () unless @passed;

    #  The --import flag is only allowed with fresh installations.
    #
    unless ($UEMSinstall{OPTION}{install}) {
        &SysDied("It hurts you more than it hurts me to say that the \"--import\" flag can\nonly be used during an installation (--install).");
    }


    #  We need to determine whether an argument is an actual directory
    #
    $mesg = "You passed \"IMPORT\" as an argument to \"--import\" but it does not appear to be ".
            "an existing directory. - Go fix the problem!";

    foreach my $import (@passed) {
        chomp $import; $import=~s/\s+//g;
        next unless $import;
        unless (-d $import) {$mesg=~s/IMPORT/$import/g;&PrintMessage(6,4,88,1,1,"Import Faux Paux!",$mesg); &SysDied(q{ });}
    }


    #  By default, include all domains from an existing UEMS installation, identified by 
    #  $UEMSinstall{IEMS}{cuems}, unless the "--noruns flag was passed.
    #
    unless ($UEMSinstall{OPTION}{noruns}) {
        push @passed => "$UEMSinstall{IEMS}{rundir}" if $UEMSinstall{IEMS}{cuems} and -d "$UEMSinstall{IEMS}{rundir}";
    }

    return () unless @passed;


    #  The &GetDomainList() routine will search down the directory tree looking for viable
    #  domain directories and will write them to the @passed array.
    #
    @passed = &GetDomainList(@passed);


return @passed;
}


sub Options_addpack  {
#  ==================================================================================
#   The --addpack flag allows the user to specify which additional package files to
#   download.  The string(s) passed as arguments to --addpack will be used to match
#   against tarfiles on the specified repository.
#  ==================================================================================
#
use List::Util 'first';

    my @addpacks  = ();


    #  ------------------------------------------------------------------------------
    #  Attempt to manage the various alternate names for the data sets.
    #  ------------------------------------------------------------------------------
    #
    my %aliases   = ();
    my %raliases  = ();  #  Hash to be inverted

       @{$raliases{buildsrc}} = qw(source src sorc buildsrc);
       @{$raliases{nawips}}   = qw(nawips gempak);
       @{$raliases{workshop}} = qw(workshop lessons lesson class work);
       @{$raliases{xgeog}}    = qw(xgeog geog geogs xgeogs terrestial geographic);
       @{$raliases{gtopo}}    = qw(gtopo _gtopo topo);
       @{$raliases{nlcd2006}} = qw(nlcd2006 _nlcd2006 nlcd200 2006);
       @{$raliases{nlcd2011}} = qw(nlcd2011 _nlcd2011 nlcd201 2011);
       
    #  ------------------------------------------------------------------------------
    #  Invert the %raliases hast to %aliases
    #  ------------------------------------------------------------------------------
    #
    foreach my $key (keys %raliases) {foreach my $val (@{$raliases{$key}}) {$aliases{$val} = $key;}}


    #  ------------------------------------------------------------------------------
    #  For simplicity the contents of the @{$UEMSinstall{OPTION}{xgeogs}} is included
    #  with the arguments passed so that they can be handled together.
    #  ------------------------------------------------------------------------------
    #
    my @passed = (@_,@{$UEMSinstall{OPTION}{xgeogs}}); return () unless @passed;


    #  ------------------------------------------------------------------------------
    #  Guidance should it be needed
    #  ------------------------------------------------------------------------------
    #
    $mesg = "I'm sure this is just a misunderstanding between you and your large brain. The ".
            "\"--addpack\" flag is a stand-alone option used to install additional support ".
            "packages and data sets, after an installation or update has been completed.";

    &SysDied($mesg) if $UEMSinstall{OPTION}{update} or $UEMSinstall{OPTION}{install};


    $mesg = "Did you know that you must provide either the name of the package you want to include for ".
            "installation or a string that can be used to match against the available packages as an ".
            "argument to \"--addpack\"?  That's a rhetorical question as you would have included ".
            "one had you known.\n\n".

            "Optional packages available for inclusion are:\n\n".
            "    nawips   - The N-AWIPS (GEMPAK) graphics package with pre-built binaries\n".
            "    source   - The source code used to build the UEMS (some exclusions)\n".
            "    workshop - Tutorial and training package (very large)\n".
            "    xgeog    - Auxiliary terrestrial datasets (gtopo,nlcd2006,nlcd2011)\n\n".

            "    %  $UEMSinstall{EXE} --addpack nawips\n".
            "Or\n".
            "    %  $UEMSinstall{EXE} --addpack nawips,source\n\n".

            "You can pass multiple instances of \"--addpack\" too:\n\n".

            "    %  $UEMSinstall{EXE} --addpack xgeog --addpack workshop\n\n".

            "So don't just think about it, do it.";

    unless ($passed[0]) {&PrintMessage(6,4,94,1,1,$mesg); &SysDied();}


    #  ------------------------------------------------------------------------------
    #  Clean up the argument list
    #  ------------------------------------------------------------------------------
    #
    my $list = join ',' => @passed; @passed = split /,|;|:/, $list;

    my @filtered = ();
    foreach (@passed) {
        $_ = lc $_;
        s/\.tbz|\.tgz|\.tar|\.gz|\.zip|\.bzip//g;
        next unless $_;
        push @filtered => $_;
    }
    

    #  ------------------------------------------------------------------------------
    #  Apply the alias filters
    #  ------------------------------------------------------------------------------
    #
    foreach my $arg (@filtered) { if (my $p = first {/$arg/} keys %aliases) {push @addpacks => $aliases{$p};}}
    my @packs  = map {$_ eq 'xgeog' ? @{$UEMSinstall{XGEOGS}} : $_} @addpacks;
    @addpacks  = &rmdups(@packs);


    $mesg = "Well, it appears that you passed the \"--addpack\" flag but something went horribly wrong ".
            "while filtering your requests leaving you with no packages to download. I know this is not ".
            "what you wanted so why don't you check your arguments and try again.";

    &SysDied($mesg) unless @addpacks;


    #  ------------------------------------------------------------------------------
    #  Finally, check whether the package is already installed
    #  ------------------------------------------------------------------------------
    #
    my @install = ();
    my @mesgs   = ();
    foreach (@addpacks) {
        if (/nawips/   and $UEMSinstall{IEMS}{nawips})   {push @mesgs, "\xe2\x9c\x93 The N-AWIPS (GEMPAK) graphics package"; next;}
        if (/buildsrc/ and $UEMSinstall{IEMS}{source})   {push @mesgs, '\xe2\x9c\x93 The UEMS source code package (excludes WRF)'; next;}
        if (/workshop/ and $UEMSinstall{IEMS}{workshop}) {push @mesgs, '\xe2\x9c\x93 The UEMS training and tutorial package (may not be available)'; next;}
        if (/gtopo/    and $UEMSinstall{IEMS}{gtopo})    {push @mesgs, '\xe2\x9c\x93 Global USGS terrain elevation dataset (Since Updated)'; next;}
        if (/nlcd2006/ and $UEMSinstall{IEMS}{nlcd2006}) {push @mesgs, '\xe2\x9c\x93 US CONUS 40-category 2011 NLCD/MODIS landuse classification'; next;}
        if (/nlcd2011/ and $UEMSinstall{IEMS}{nlcd2011}) {push @mesgs, '\xe2\x9c\x93 US CONUS 40-category 2006 NLCD/MODIS landuse classification'; next;}
        push @install, $_;
    } 

    unless ($UEMSinstall{OPTION}{force}) {
        @addpacks = @install;
        if (@mesgs) {
            $mesg = join '\n', @mesgs;
            &PrintMessage(6,4,94,1,1,'Some requested packages already installed:',$mesg);
            &PrintMessage(0,7,94,1,2,"Please include the \"--force\" flag to reinstall these packages.");
        }
    }

        
return @addpacks ? join ',' => @addpacks : 'none';
}


sub Options_info {
#----------------------------------------------------------------------------------
#  Define the value for option "--info"
#----------------------------------------------------------------------------------
#
    my $passed = shift; return 0 unless defined $passed and $passed;

    $UEMSinstall{OPTION}{update}      = 0 if $passed;
    $UEMSinstall{OPTION}{install}     = 0 if $passed;
    $UEMSinstall{OPTION}{updatedir}   = 0 if $passed;
    $UEMSinstall{OPTION}{releasedir}  = 0 if $passed;

return $passed;
}


sub Options_install {
#----------------------------------------------------------------------------------
#  Define the value for option "--install"
#----------------------------------------------------------------------------------
#
    my $passed = shift;

    $passed = 'current' if defined $passed and ! $passed;

    $UEMSinstall{OPTION}{listgeog} = &Options_listgeog('releases') if defined $passed and $passed =~ /listgeog/i;
    $UEMSinstall{OPTION}{listall}  = &Options_listall('releases')  if defined $passed and $passed =~ /listall/i;
    $UEMSinstall{OPTION}{list}     = &Options_list('releases')     if defined $passed and $passed =~ /list/i;
    $UEMSinstall{OPTION}{info}     = &Options_info('releases')     if defined $passed and $passed =~ /info/i;

    $passed = 0 if $UEMSinstall{OPTION}{listgeog} or $UEMSinstall{OPTION}{listall} or $UEMSinstall{OPTION}{list} or $UEMSinstall{OPTION}{info};

    $passed = 'current' if $passed and $passed !~ /[\d\.]/g;  #  Covers is the user passed a mistake

    $passed = 0 unless defined $passed;

return $passed;
}


sub Options_listall {
#----------------------------------------------------------------------------------
#  Define the value for option  "--listall"
#----------------------------------------------------------------------------------
#
    my $passed = shift; return 0 unless defined $passed and $passed;

return $passed;
}


sub Options_listgeog {
#----------------------------------------------------------------------------------
#  Define the value for option  "--listgeog"
#----------------------------------------------------------------------------------
#
    my $passed = shift; return 0 unless defined $passed and $passed;

return $passed;
}


sub Options_list {
#----------------------------------------------------------------------------------
#  Define the value for option "--list"
#----------------------------------------------------------------------------------
#
    my $passed = shift; return 0 unless defined $passed and $passed;

    #  If the user passed "--listall" as well
    #
    $passed = $UEMSinstall{OPTION}{listall} if $UEMSinstall{OPTION}{listall};

    $UEMSinstall{OPTION}{update}      = 0 if $passed;
    $UEMSinstall{OPTION}{install}     = 0 if $passed;
    $UEMSinstall{OPTION}{updatedir}   = 0 if $passed;
    $UEMSinstall{OPTION}{releasedir}  = 0 if $passed;

return $passed;
}


sub Options_methods {
#----------------------------------------------------------------------------------
#  Define the value for option "--curl" and "--wget"
#----------------------------------------------------------------------------------
#
    my %methods = ();

    my ($curl, $wget) = @_;

    $curl = defined $curl ? 1 : 0;
    $wget = defined $wget ? 1 : 0;

    unless ($curl or $wget) {$curl = 1; $wget = 1;}

    $methods{curl} = $curl ? &LocateX('curl') : 0;
    $methods{wget} = $wget ? &LocateX('wget') : 0;

return %methods;
}


sub Options_nogeog {
#----------------------------------------------------------------------------------
#  Define the value for option "--nogeog"
#----------------------------------------------------------------------------------
#
    my $passed = shift;

return defined $passed ? 1 : 0;
}


sub Options_nolocal {
#----------------------------------------------------------------------------------
#  Define the value for the "--nolocal" flag
#----------------------------------------------------------------------------------
#
    my $passed = shift;

return defined $passed ? 1 : 0;
}


sub Options_norefresh {
#----------------------------------------------------------------------------------
#  Define the value for option "--norefresh"
#----------------------------------------------------------------------------------
#
    my $passed = shift;

return defined $passed ? 0 : 1;  #  Note that the negative is returned
}


sub Options_noruns {
#----------------------------------------------------------------------------------
#  Define the value for the "--noruns" flag, which turns ON|OFF the importing
#  of computational domains in the runs directory from a previously installed UEMS.
#----------------------------------------------------------------------------------
#
    my $noruns = shift;

    return 1 if defined $noruns;


return ($UEMSinstall{OPTION}{update} ? 1 : $UEMSinstall{OPTION}{install} ? 0 : 1);
}


sub Options_nounpack {
#----------------------------------------------------------------------------------
#  Define the value for option  "--nounpack"
#----------------------------------------------------------------------------------
#
    my $passed = shift;

return defined $passed ? 1 : 0;
}


sub Options_proxy {
#----------------------------------------------------------------------------------
#  Define the value for option "--proxy"
#----------------------------------------------------------------------------------
#
    my $passed = shift; return 0 unless defined $passed;

    $mesg = "Use of the --proxy option requires an argument that will be used to set the HTTP_PROXY ".
            "environment variable. This may look like:\n\n".

            "  --proxy IP:PORT          (E.g. --proxy 192.168.150.10:80)\n".

            "Or\n".

            "  --proxy USER:PWD\@IP:PORT (E.g. --proxy roz:HelloKitty\@192.168.150.10:80)\n\n".

            "So you are must either put the \"--proxy\" option back into your EMS quiver or specify ".
            "the correct environment setting for your system.";

    &SysDied($mesg) unless $passed;

return $passed;
}


sub Options_relsdir {
#----------------------------------------------------------------------------------
#  Define the value for option "--reldir"
#----------------------------------------------------------------------------------
#
use Cwd;

    my $passed = shift; $passed = 0 unless defined $passed and $passed;

    $passed = Cwd::realpath($passed) if $passed and -d $passed;

return $passed;
}


sub Options_repodir {
#----------------------------------------------------------------------------------
#  This routine sets the available UEMS releases located in the repodir passed
#  as an argument to --repodir.  Officially, the argument is the path to a
#  directory (repository) that contains various one or more UEMS release or
#  update directories that are identified with X.X.X in the name where "X"
#  represents a number such as "14.52.8". Each release directory should
#  contain the full compliment of package files for that release or update.
#
#  Unofficially, the argument to --repodir may also include a specific
#  release directory, e.g., --repodir=/bla/bla/bla/X.X.X. In this case
#  the "X.X.X" will be stripped from the argument and passed to either
#  the UPDATE or INSTALL variable, overriding any previous value.
#----------------------------------------------------------------------------------
#
use Cwd;

    my $release;
    my @releases=();

    #  This is a bit awkward since $UEMSinstall{OPTION}{repodir} is only used in the event
    #  the --dvd flag is passed, in which case it is the only way to get the
    #  --repodir flag set.
    #
    $UEMSinstall{OPTION}{repodir} = 0 unless defined $UEMSinstall{OPTION}{repodir};

    my $passed = shift;  $passed = $UEMSinstall{OPTION}{repodir} if $UEMSinstall{OPTION}{repodir};
    return () unless defined $passed;


    unless ($passed) {
        $mesg = "You requested that the UEMS release files be accessed locally by passing ".
                "\"--repodir\", but you forgot to include the directory:\n\n".
                "    --repodir=<directory>\n\nNow go remedy this situation!";
        &SysDied($mesg);
    }


    my $dpkg = $passed;
    $mesg = "You requested that the UEMS release or update files be accessed locally by ".
            "passing \"--repodir=$dpkg\". \n\nThis option assumes that the ".
            "package files are located under\n\n".

            "  \"<repodir>/<release>\"\n\n".

            "However, I am unable to locate the $dpkg directory.\n\nWhat's up with that?!";

    &SysDied($mesg) unless $passed = Cwd::realpath($passed) and -d $passed;


    my ($path, $drel) = &popit2($passed);

    #  Attempt to figure out what the user wants.  The argument to --repodir should be the
    #  path to a directory containing one or more UEMS releases, each containing the
    #  package tarfiles.  In the event that the user passed the path to a specific
    #  release then make use that as the argument to --install or --update but check
    #  to make sure it has not been defined already.
    #
    if ($drel =~ /(\d+)\.(\d+)\.(\d+)/g) {  # Assume user include a specific release
        $UEMSinstall{OPTION}{install} = $drel if $UEMSinstall{OPTION}{install};
        $UEMSinstall{OPTION}{update}  = $drel if $UEMSinstall{OPTION}{update};

        push @releases => $passed;
        $passed = $path;
    }  else {  # Check for release directories
        opendir DIR => $passed;
        foreach (readdir DIR) {push @releases => "$passed/$_" if /(\d+)\.(\d+)\.(\d+)/g;}
        closedir DIR;
    }

    unless (@releases) {
        $mesg = "You requested that UEMS release or update files be accessed locally from $passed; ".
                "however, this directory does not appear to contain any UEMS releases.\n\n".
                "I was hoping to find $passed/<release>, where <release> contains the package ".
                "files from the update or release.\n\n".
                "You can\'t pull the wool over my eyes, unless it\'s cashmere. I love cashmere.";
        &SysDied($mesg);
    }

    #  Rather than modifying code the throughout $UEMSinstall{OPTION}{repodir} will be assigned
    #  here and used wherever necessary.
    #
    ($path, $drel) = &popit2($releases[0]);
    $UEMSinstall{OPTION}{repodir} = $path;


return @releases;
}


sub Options_scour {
#----------------------------------------------------------------------------------
#  Define the value for option "--scour"
#----------------------------------------------------------------------------------
#
    my $passed = shift;

return defined $passed ? 1 : 0;
}


sub Options_update {
#----------------------------------------------------------------------------------
#  Define the value for option "--update"
#----------------------------------------------------------------------------------
#
    my $passed = shift;

    $passed = 'current' if defined $passed and ! $passed;

    $UEMSinstall{OPTION}{listall} = &Options_listall('updates') if defined $passed and $passed =~ /listall/i;
    $UEMSinstall{OPTION}{list}    = &Options_list('updates')    if defined $passed and $passed =~ /list/i;
    $UEMSinstall{OPTION}{info}    = &Options_info('updates')    if defined $passed and $passed =~ /info/i;

    $passed = 0 if $UEMSinstall{OPTION}{listall} or $UEMSinstall{OPTION}{list} or $UEMSinstall{OPTION}{info};

    $passed = 'current' if $passed and $passed !~ /[\d\.]/g;  #  Covers is the user passed a mistake

    $passed = 0 unless defined $passed;

return $passed;
}


sub Options_updtdir {
#----------------------------------------------------------------------------------
#  Define the value for option "--updtdir"
#----------------------------------------------------------------------------------
#
    my $passed = shift; $passed = 0 unless defined $passed and $passed;

    $passed = Cwd::realpath($passed) if $passed and -e $passed;

return $passed;
}


sub UEMS_SystemInstall {
#  ===========================================================================================
#   This routine manages the installation of the UEMS
#  ===========================================================================================
#
use File::stat;

    return -1 unless %{$UEMSinstall{RELEASES}};

    
    #  --------------------------------------------------------------------------------
    #    Create a sorted list containing the release packages. The @releases array
    #    contains all the available releases
    #  --------------------------------------------------------------------------------
    #
    my @releases  = &SortPackages(keys %{$UEMSinstall{RELEASES}});

    my $src = $UEMSinstall{EMSHOST} ? 'on the UEMS server' : 'in the specified repository';
    $mesg = "There appears to be a problem in that either there are no UEMS releases available ".
            "$src or there was a problem getting the release information.\n\n".
            "You can add the \"--list\" or \"--listall\" flag for a listing of the available ".
            "EMS package files.\n\n".
            "Regardless, this is not looking good for you, although you still look good!";

    &SysDied($mesg) unless @releases;


    #  --------------------------------------------------------------------------------
    #    Provide some debugging information if requested
    #  --------------------------------------------------------------------------------
    #
    if ($UEMSinstall{OPTION}{debug}) {
        $mesg = $UEMSinstall{EMSHOST} ? "Available releases on $UEMSinstall{EMSHOST}"
                                      : "Available releases in $UEMSinstall{OPTION}{repodir}";
        &PrintMessage(0,9,78,1,2,$mesg);
        foreach (@releases) {
            my ($reldir,$f)=&popit2((keys %{$UEMSinstall{RELEASES}{$_}})[0]); 
            &PrintMessage(1,11,144,0,2,"RELEASE : $_\nLOCATION: $reldir");
       }
    }


    #  --------------------------------------------------------------------------------
    #    It is assumed that the user knows what he or she is doing; however, we must
    #    check that the requested release exists and provide a warning should they
    #    attempt to install an earlier release.
    #  --------------------------------------------------------------------------------
    #
    return $releases[0] unless @releases and $releases[0] ne '1'; #  No files


    #  --------------------------------------------------------------------------------
    #  Now manage the argument passed to the --install option
    #  --------------------------------------------------------------------------------
    #
    $UEMSinstall{OPTION}{install} = $releases[0] if $UEMSinstall{OPTION}{install} eq 'current';


    #  --------------------------------------------------------------------------------
    #  Check the current installation before continuing.
    #  --------------------------------------------------------------------------------
    #
    &SysDied('The installation preparation gnomes are agitated again!') if &Install_PreConfiguration();



    #  --------------------------------------------------------------------------------
    #    At this point the UEMS directory has been created on the local system. Now
    #    collect the system information to determine which release files to download.
    #  --------------------------------------------------------------------------------
    #
    my $irel = &GetUEMSrelease($UEMSinstall{UEMSHOME});  #  The installed release information
    my $frel = $irel ? $irel : 'No UEMS Installed';

    
    &PrintMessage(0,7,78,1,2,"Current Installed Release: $frel") if $UEMSinstall{OPTION}{debug};



    #  --------------------------------------------------------------------------------
    #    Check whether the requested release actually exists
    #  --------------------------------------------------------------------------------
    #
    unless (grep /$UEMSinstall{OPTION}{install}$/ => @releases) {

        my $uems = &popit($UEMSinstall{UEMSHOME}); &rm($UEMSinstall{UEMSHOME}) if $uems eq $UEMSinstall{UEMSTOP};

        $mesg = "Fantasy Release: $UEMSinstall{OPTION}{install}\n\n".
                "It appears that you are attempting to install a non-existent release, $UEMSinstall{OPTION}{install}. You ".
                "can use the \"--list\" option see any updates or releases for which you are eligible.";

        &SysDied($mesg);

    }



    #  --------------------------------------------------------------------------------
    #    If the release has already been installed, or partially installed, the user
    #    must include the --continue or --force flags to continue. The --continue
    #    flag might be used if an process was interrupted for some reason, in which
    #    case the installation will continue from where it left off. The --force flag
    #    is intended to do a complete re-install using the existing package tarfiles.
    #    If the --nolocal flag is included then the existing tarfiles will not be used
    #    and new ones will be acquired from the specified source.
    #  --------------------------------------------------------------------------------
    #
    if ($irel eq $UEMSinstall{OPTION}{install} and !$UEMSinstall{OPTION}{force} and !$UEMSinstall{OPTION}{continue}) {
        $mesg = "The requested release, $irel, is the same as that already installed. If you are true ".
                "about your intent, then pass the \"--force\" flag to tell me that you really, truly care.\n\n".
                "FYI - The default behavior of uems_install.pl is to not install any package files located under ".
                "$UEMSinstall{OPTION}{releasedir} because it is assumed they were installed previously.\n\n".
                "Including the \"--force\" flag re-installs the UEMS using all available package files under ".
                "$UEMSinstall{OPTION}{releasedir} in addition to acquiring and installing any missing files.\n\n".
                "If the \"--nolocal\" flag is included then the local file discarded and new ones acquired\n\n".
                "from the source.\n\n";

        &PrintMessage(6,4,86,2,1,"UEMS V$UEMSinstall{OPTION}{install} already installed",$mesg);
        %{$UEMSinstall{RELEASES}} = ();  #  Needed to avoid oath
        return;
    }


    #  --------------------------------------------------------------------------------
    #    Provide notice if the user is attempting to install an earlier release.
    #  --------------------------------------------------------------------------------
    #
    my @tmp=();
    my @cfv = split /\./ => $releases[0];         @tmp=(); foreach (@cfv) {push @tmp=> $_ unless /\D/;} my $cfv = join ".", @tmp;
    my @ifv = split /\./ => $irel;                @tmp=(); foreach (@ifv) {push @tmp=> $_ unless /\D/;} my $ifv = join ".", @tmp;
    my @rfv = split /\./ => $UEMSinstall{OPTION}{install}; @tmp=(); foreach (@rfv) {push @tmp=> $_ unless /\D/;} my $rfv = join ".", @tmp;

    $mesg = "Installation Faux Paux: $irel > $UEMSinstall{OPTION}{install}\n\n".
            "Did you know that you are attempting to install an earlier release than the one that ".
            "currently resides on the system?\n\nIf you are true about your intent, then use the ".
            "\"--force\" option to tell me that you really, truly care.";

    &SysDied($mesg) if (&CompareReleaseNumbers($rfv,$ifv) < 0 and !$UEMSinstall{OPTION}{force});


    #  --------------------------------------------------------------------------------
    #  Make sure the user is ready for the installation
    #  --------------------------------------------------------------------------------
    #
    unless ($UEMSinstall{OPTION}{allyes}) {
        &PrintMessage(0,7,144,1,0,"Installing UEMS Version $UEMSinstall{OPTION}{install}. Is this OK by you? [OK by me]: ");
        my $ans = <>; chomp $ans; $ans =~ s/\s+//g;
        my $resp = $ans ? $ans : "Yes";
        unless ($resp =~ /^Y/i or $resp =~ /^OK/i) {
            &PrintMessage(0,7,92,1,1,"Maybe we can try again later - Bye");
            my $uems = &popit($UEMSinstall{UEMSHOME});
            &rm($UEMSinstall{UEMSHOME}) if $irel eq '00.00.00.00' and  $uems eq $UEMSinstall{UEMSTOP} and ! -e "$UEMSinstall{UEMSHOME}/strc";
            return 3;
        } 
        &PrintMessage(0,1,144,0,1,q{ })
    }

    

    #  --------------------------------------------------------------------------------
    #    Any downloaded tarfiles will be placed in $UEMSinstall{OPTION}{releasedir},
    #    but first take inventory of any package files that currently exist to 
    #    determine what needs to be done.
    #  --------------------------------------------------------------------------------
    #
    #$UEMSinstall{OPTION}{releasedir} = "$UEMSinstall{OPTION}{releasedir}/$UEMSinstall{OPTION}{install}";
    &SysDied("Bummer! Unable to create $UEMSinstall{OPTION}{releasedir}") if &mkdir($UEMSinstall{OPTION}{releasedir});

    my %relfiles = %{$UEMSinstall{RELEASES}{$UEMSinstall{OPTION}{install}}};


    #  --------------------------------------------------------------------------------
    #  Check the local release directory for existing files.  If any exist, get the 
    #  file that was accessed last. This file may need to be re-installed because
    #  we don't know whether the installation was interrupted by the user during 
    #  unpacking. 
    #  --------------------------------------------------------------------------------
    #
    my %existing = ();
    my $nfile    = '';
    my $at       = 0;
    unless ($UEMSinstall{OPTION}{nolocal} || $UEMSinstall{OPTION}{force}) {
        foreach (&FileMatch($UEMSinstall{OPTION}{releasedir},'',0,1))  {
            $existing{&popit($_)} = -s $_;
            my $f = stat $_;
            if (${$f}[8] > $at) {$at = ${$f}[8]; $nfile    = &popit($_);}
        }
    }


    #  --------------------------------------------------------------------------------
    #  Compare the number of files that already reside on the system, and thus will
    #  not be installed unless either the --force or --nolocal flags are passed,
    #  to the total installation. Provide guidance if necessary.
    #  --------------------------------------------------------------------------------
    #
    my $nlocal = keys %existing;
    my $ntotal = keys %relfiles;

    if ($nlocal == $ntotal) {
        $mesg = "It appears that all the package files have been installed, which is probably not what you expected ".
                "when you started this process. If you want to re-install the UEMS from local package files then ".
                "re-run $UEMSinstall{EXE} and include the \"--force\" flag, or if you want to download and install ".
                "a fresh set of package files then pass the \"--nolocal\" flag.";
        &PrintMessage(6,4,86,2,1,"UEMS V$UEMSinstall{OPTION}{install} already installed",$mesg);
        %{$UEMSinstall{RELEASES}} = ();  #  Needed to avoid oath
        return;
    }
        
        
    #  --------------------------------------------------------------------------------
    #    Begin the download (or copy) of release tarfiles to the RELDIR directory.
    #    The files (packages) are organized into groups to provide an explanation
    #    of what is contained within the files:
    #
    #      @geogs    - Default geographic datasets
    #      @xgeogs   - Additional geographic datasets
    #      @strc     - UEMS base tarfiles
    #      @binaries - UEMS target binaries
    #      @release  - UEMS package files and perl scripts
    #      @utils    - UEMS utility packages
    #
    #    The tarfiles are installed as they are downloaded, which can result in
    #    problems should there be an interruption in the process.
    #  --------------------------------------------------------------------------------
    #
    my (@geogs,@xgeogs,@binaries,@release,@utils,@strc)=();
 
    foreach my $rfile (keys %relfiles) { next unless $rfile;
        for (&popit($rfile)) {
            next if defined $existing{$_} and $existing{$_} == $relfiles{$rfile} and $nfile ne $_;
            if    (/^wrf\.geog_/) {push @xgeogs   => $rfile if     /gtopo_|nlcd2006_|nlcd2011_/;}  
            if    (/^wrf\.geog_/) {push @geogs    => $rfile unless /gtopo_|nlcd2006_|nlcd2011_/;}
            if   (/\.strc\./)     {push @strc     => $rfile;}
            elsif (/\.x64/)       {push @binaries => $rfile;}
            elsif (/grads|hdfview|ncview|mpich2|domwiz/) {push @utils   => $rfile;}
            elsif (/^release\./)  {push @release  => $rfile;}
        }
    }
    (@xgeogs) = () unless @{$UEMSinstall{OPTION}{xgeogs}};
    (@geogs)  = () if $UEMSinstall{OPTION}{nogeog};  #  Do not include @xgeogs with --nogeog

    #  --------------------------------------------------------------------------------
    #    The filtering has been completed for the geographic datasets so combine 
    #    geogs & xgeogs.
    #  --------------------------------------------------------------------------------
    #
    @geogs = &rmdups(@geogs,@xgeogs);

    #  Make sure STRC package tarfile is the 1st installed
    #
    @release = sort @release; @release = (@strc,@release);


    #  --------------------------------------------------------------------------------
    #    Begin the acquisition & installation process for each file group. The
    #    order of package installation is important as some directories must
    #    be created before other packages can be installed.  
    #  --------------------------------------------------------------------------------
    #
    my $wrel = '';
    my $inst = $UEMSinstall{OPTION}{nounpack} ? '' : 'and installing ';

    my $nt = @geogs+@binaries+@release+@utils;
    my $n  = 0;

    &PrintMessage(1,4,78,1,1,"Installing a total if $nt UEMS package files");

    if (@release) {my $nf = @release; &PrintMessage(0,7,78,1,2,"Acquiring ${inst}$nf core package files");

        foreach my $rfile (@release) { $n++;

            my $lsfile = &popit($rfile); next unless $lsfile;
            my $lfile  = "$UEMSinstall{OPTION}{releasedir}/$lsfile";
            my $cnt    = sprintf("%10s","$n of $nt :");

            &PrintMessage(0,7,108,0,0,sprintf("$cnt UEMS %-43s - ",$lsfile));

            if (-s $lfile and !$UEMSinstall{OPTION}{nolocal}) {
                &PrintMessage(0,1,14,0,0,"Found locally");
            } else { #  Get the files from the source
                if ($UEMSinstall{OPTION}{repodir}) {
                    &SysDied("Failed: cp -f $rfile $lfile") if system "cp -f $rfile $lfile";
                    &PrintMessage(0,1,12,0,0,"Copied");
                } else {
                    &SysDied("Failed during http acquisition - Check connection & local file system") if &GetFileHTTP($rfile,$lfile);
                    &PrintMessage(0,1,12,0,0,"Downloaded");
                }
            }

            if ($UEMSinstall{OPTION}{nounpack}) {&PrintMessage(0,1,12,0,1,"; Not Installed");next;}
            &SysDied("Failed: Unpack of $lfile") if &UnpackTarfile($lfile,$UEMSinstall{UEMSHOME});
            &PrintMessage(0,1,12,0,1,"& Installed");
        }
    }


    if (@utils) {my $nf = @utils; &PrintMessage(0,7,78,1,2,"Acquiring ${inst}$nf utility packages");


        foreach my $rfile (sort @utils) { $n++;

            my $lsfile = &popit($rfile); next unless $lsfile;
            my $lfile  = "$UEMSinstall{OPTION}{releasedir}/$lsfile";
            my $cnt    = sprintf("%10s","$n of $nt :");

            &PrintMessage(0,7,108,0,0,sprintf("$cnt UEMS %-43s - ",$lsfile));

            if (-s $lfile and !$UEMSinstall{OPTION}{nolocal}) {
                &PrintMessage(0,1,14,0,0,"Found locally");
            } else { #  Get the files from the source
                if ($UEMSinstall{OPTION}{repodir}) {
                    &SysDied("Failed: cp -f $rfile $lfile") if system "cp -f $rfile $lfile";
                    &PrintMessage(0,1,12,0,0,"Copied");
                } else {
                    &SysDied("Failed during http acquisition - Check connection & local file system") if &GetFileHTTP($rfile,$lfile);
                    &PrintMessage(0,1,12,0,0,"Downloaded");
                }
            }

            if ($UEMSinstall{OPTION}{nounpack}) {&PrintMessage(0,1,12,0,1,"; Not Installed");next;}
            &SysDied("Failed: Unpack of $lfile") if &UnpackTarfile($lfile,$UEMSinstall{UEMSHOME});
            &PrintMessage(0,1,12,0,1,"& Installed");

        }
    }


    if (@binaries) {my $nf = @binaries; &PrintMessage(0,7,78,1,2,"Acquiring ${inst}${nf} package executables");

        foreach my $rfile (sort @binaries) { $n++;

            my $lsfile = &popit($rfile); next unless $lsfile;
            my $lfile  = "$UEMSinstall{OPTION}{releasedir}/$lsfile";
            my $cnt    = sprintf("%10s","$n of $nt :");

            &PrintMessage(0,7,108,0,0,sprintf("$cnt UEMS %-43s - ",$lsfile));

            if (-s $lfile and !$UEMSinstall{OPTION}{nolocal}) {
                &PrintMessage(0,1,14,0,0,"Found locally");
            } else { #  Get the files from the source
                if ($UEMSinstall{OPTION}{repodir}) {
                    &SysDied("Failed: cp -f $rfile $lfile") if system "cp -f $rfile $lfile";
                    &PrintMessage(0,1,12,0,0,"Copied");
                } else {
                    &SysDied("Failed during http acquisition - Check connection & local file system") if &GetFileHTTP($rfile,$lfile);
                    &PrintMessage(0,1,12,0,0,"Downloaded");
                }
            }

            if ($UEMSinstall{OPTION}{nounpack}) {&PrintMessage(0,1,12,0,1,"; Not Installed");next;}
            &SysDied("Failed: Unpack of $lfile") if &UnpackTarfile($lfile,$UEMSinstall{UEMSHOME});
            &PrintMessage(0,1,12,0,1,"& Installed");

        }
    }


    #  --------------------------------------------------------------------------------
    #    Finally - Install the geographic datasets
    #  --------------------------------------------------------------------------------
    #
    if (@geogs) {my $nf = @geogs; &PrintMessage(0,7,78,1,2,"Acquiring ${inst}${nf} required WRF geographic datasets");

        foreach my $rfile (sort @geogs) { $n++;

            my $lsfile = &popit($rfile); next unless $lsfile;
            my $lfile  = "$UEMSinstall{OPTION}{releasedir}/$lsfile";
            my $cnt    = sprintf("%10s","$n of $nt :");

            &PrintMessage(0,7,108,0,0,sprintf("$cnt UEMS %-43s - ",$lsfile));

            if (-s $lfile and !$UEMSinstall{OPTION}{nolocal}) {
                &PrintMessage(0,1,14,0,0,"Found locally");
            } else { #  Get the files from the source
                if ($UEMSinstall{OPTION}{repodir}) {
                    &SysDied("Failed: cp -f $rfile $lfile") if system "cp -f $rfile $lfile";
                    &PrintMessage(0,1,12,0,0,"Copied");
                } else {
                    &SysDied("Failed during http acquisition - Check connection & local file system") if &GetFileHTTP($rfile,$lfile);
                    &PrintMessage(0,1,12,0,0,"Downloaded");
                }
            }

            if ($UEMSinstall{OPTION}{nounpack}) {&PrintMessage(0,1,12,0,1,"; Not Installed");next;}
            &SysDied("Failed: Unpack of $lfile") if &UnpackTarfile($lfile,$UEMSinstall{UEMSHOME});
            &PrintMessage(0,1,12,0,1,"& Installed");

        }
    }


    #  --------------------------------------------------------------------------------
    #    That's all the downloading and installation - On to configuration.
    #  --------------------------------------------------------------------------------
    #
    return if $UEMSinstall{OPTION}{nounpack};

    #  Do the configuration of the UEMS
    #
    if ($wrel) {open (my $fh, '>', "$UEMSinstall{UEMSHOME}/strc/.release"); print $fh "UEMS $frel\nWRF $wrel\n";close $fh;}

    if (@release || @utils || @strc) {
        &SysDied('Well, the Install_PostConfiguration configuration gods are not happy with you!')  if &Install_PostConfiguration();
    }


    #  Import any requested domains
    #
    &Install_ImportDomains(@{$UEMSinstall{OPTION}{imports}});

    &rm($UEMSinstall{EMSPRV}) if $UEMSinstall{OPTION}{scour};



return 0;
} # End of UEMS_SystemInstall


sub UEMS_SystemAddpacks {
#  ===========================================================================================
#   This routine manages the installation of the UEMS
#  ===========================================================================================
#
    return -1 unless %{$UEMSinstall{ADDPACKS}} || $UEMSinstall{OPTION}{addpacks};


    #  --------------------------------------------------------------------------------
    #  Make a graceful exit if the user has passed --addpacks but they have all
    #  been installed.
    #  --------------------------------------------------------------------------------
    #
    if ($UEMSinstall{OPTION}{addpacks} eq 'none') {
        &PrintMessage(2,4,144,2,1,'All requested ancillary packages have been installed, Your Awesomeness!');
        return 0;
    }

    
    #  --------------------------------------------------------------------------------
    #    Create a sorted list containing the release packages. The @releases array
    #    contains all the available releases
    #  --------------------------------------------------------------------------------
    #
    my @packages  = &SortPackages(keys %{$UEMSinstall{ADDPACKS}});

    my $src = $UEMSinstall{EMSHOST} ? 'on the UEMS server' : 'in the specified repository';
    $mesg = "There appears to be a problem in that either there are no UEMS releases available ".
            "$src or there was a problem getting the release information.\n\n".
            "Regardless, this is not looking good for you, although you still look good!";

    &SysDied($mesg) unless @packages;


    #  --------------------------------------------------------------------------------
    #    Provide some debugging information if requested
    #  --------------------------------------------------------------------------------
    #
    if ($UEMSinstall{OPTION}{debug}) {
        $mesg = $UEMSinstall{EMSHOST} ? "Available packages on $UEMSinstall{EMSHOST}"
                                      : "Available packages in $UEMSinstall{OPTION}{repodir}";
        &PrintMessage(0,9,78,1,2,$mesg);
        foreach (@packages) {
            my ($reldir,$f)=&popit2((keys %{$UEMSinstall{ADDPACKS}{$_}})[0]); 
            &PrintMessage(1,11,144,0,2,"PACKAGE : $_\nLOCATION: $reldir");
       }
    }


    #  --------------------------------------------------------------------------------
    #  Now manage the argument passed to the --install option
    #  --------------------------------------------------------------------------------
    #
    $UEMSinstall{OPTION}{install} = $packages[0];


    #  --------------------------------------------------------------------------------
    #    At this point the UEMS directory has been created on the local system. Now
    #    collect the system information to determine which release files to download.
    #  --------------------------------------------------------------------------------
    #
    my $irel = &GetUEMSrelease($UEMSinstall{UEMSHOME});  #  The installed release information
    &PrintMessage(0,7,78,1,2,"Current Installed Release: $irel") if $UEMSinstall{OPTION}{debug};


    #  --------------------------------------------------------------------------------
    #    Any downloaded tarfiles will be placed in $UEMSinstall{OPTION}{releasedir},
    #    but first take inventory of any package files that currently exist to 
    #    determine what needs to be done.
    #  --------------------------------------------------------------------------------
    #
    my $releasedir  = $UEMSinstall{OPTION}{releasedir}  ? $UEMSinstall{OPTION}{releasedir}  : "$UEMSinstall{UEMSHOME}/release";
    &SysDied('That is just a bummer!') if &mkdir($releasedir);

    my %relfiles = %{$UEMSinstall{ADDPACKS}{$UEMSinstall{OPTION}{install}}};

    my %existing = ();
    foreach (&FileMatch($releasedir,'',0,1))  {$existing{&popit($_)} = -s $_;}
    %existing = () if $UEMSinstall{OPTION}{nolocal};
    
    #  --------------------------------------------------------------------------------
    #    Begin the download (or copy) of release tarfiles to the RELDIR directory.
    #    The files (packages) are organized into groups to provide an explanation
    #    of what is contained within the files:
    #
    #      @geogs    - Default geographic datasets
    #      @source   - UEMS source code packages
    #      @utils    - UEMS utility packages
    #
    #    The tarfiles are installed as they are downloaded, which can result in
    #    problems should there be an interruption in the process.
    #  --------------------------------------------------------------------------------
    #
    my (@geogs,@source,@utils)=();

 
    foreach my $rfile (keys %relfiles) { next unless $rfile;
        for (&popit($rfile)) {
            next if defined $existing{$_} and ($existing{$_} == $relfiles{$rfile}) and !$UEMSinstall{OPTION}{force};     
            if    (/^wrf\.geog/) {push @geogs  => $rfile;}
            elsif (/\buildsrc/)  {push @source => $rfile;}
            else  {push @utils                 => $rfile;}
        }
    }

    #  --------------------------------------------------------------------------------
    #    Begin the acquisition & installation process for each file group. The
    #    order of package installation is important as some directories must
    #    be created before other packages can be installed.  
    #  --------------------------------------------------------------------------------
    #
    my $inst = $UEMSinstall{OPTION}{nounpack} ? '' : 'and installing ';


    #  --------------------------------------------------------------------------------
    #  Everything is a utility, unless it's a geog file
    #  --------------------------------------------------------------------------------
    #
    if (@utils) {&PrintMessage(0,7,78,1,2,"Acquiring ${inst}the UEMS utility packages");

        my $nf = @utils;
        my $n  = 0;

        foreach my $rfile (sort @utils) { $n++;

            my $lsfile = &popit($rfile); next unless $lsfile;
            my $lfile  = "$releasedir/$lsfile";
            my $cnt    = sprintf("%10s","$n of $nf :");

            &PrintMessage(0,7,108,0,0,sprintf("$cnt UEMS %-43s - ",$lsfile));

            if (-s $lfile and !$UEMSinstall{OPTION}{nolocal}) {
                &PrintMessage(0,1,14,0,0,"Found locally");
            } else { #  Get the files from the source
                if ($UEMSinstall{OPTION}{repodir}) {
                    &SysDied("Failed: cp -f $rfile $lfile") if system "cp -f $rfile $lfile";
                    &PrintMessage(0,1,12,0,0,"Copied");
                } else {
                    &SysDied("Failed: Http acquisition") if &GetFileHTTP($rfile,$lfile);
                    &PrintMessage(0,1,12,0,0,"Downloaded");
                }
            }

            if ($UEMSinstall{OPTION}{nounpack}) {&PrintMessage(0,1,12,0,1,"; Not Installed");next;}
            &SysDied("Failed: Unpack of $lfile") if &UnpackTarfile($lfile,$UEMSinstall{UEMSHOME});
            &PrintMessage(0,1,12,0,1,"& Installed");

        }
    }

    if (@source) {&PrintMessage(0,7,78,1,2,"Acquiring ${inst}the UEMS source code packages");

        my $nf = @source;
        my $n  = 0;

        foreach my $rfile (sort @source) { $n++;

            my $lsfile = &popit($rfile); next unless $lsfile;
            my $lfile  = "$releasedir/$lsfile";
            my $cnt    = sprintf("%10s","$n of $nf :");

            &PrintMessage(0,7,108,0,0,sprintf("$cnt UEMS %-43s - ",$lsfile));

            if (-s $lfile and !$UEMSinstall{OPTION}{nolocal}) {
                &PrintMessage(0,1,14,0,0,"Found locally");
            } else { #  Get the files from the source
                if ($UEMSinstall{OPTION}{repodir}) {
                    &SysDied("Failed: cp -f $rfile $lfile") if system "cp -f $rfile $lfile";
                    &PrintMessage(0,1,12,0,0,"Copied");
                } else {
                    &SysDied("Failed: Http acquisition") if &GetFileHTTP($rfile,$lfile);
                    &PrintMessage(0,1,12,0,0,"Downloaded");
                }
            }

            if ($UEMSinstall{OPTION}{nounpack}) {&PrintMessage(0,1,12,0,1,"; Not Installed");next;}
            &SysDied("Failed: Unpack of $lfile") if &UnpackTarfile($lfile,$UEMSinstall{UEMSHOME});
            &PrintMessage(0,1,12,0,1,"& Installed");

        }
    }


    #  --------------------------------------------------------------------------------
    #    Finally - Install the geographic datasets
    #  --------------------------------------------------------------------------------
    #
    if (@geogs) {&PrintMessage(0,7,78,1,2,"Acquiring ${inst}the required WRF geographic datasets");

        my $nf = @geogs;
        my $n  = 0;

        foreach my $rfile (sort @geogs) { $n++;

            my $lsfile = &popit($rfile); next unless $lsfile;
            my $lfile  = "$releasedir/$lsfile";
            my $cnt    = sprintf("%10s","$n of $nf :");

            &PrintMessage(0,7,108,0,0,sprintf("$cnt UEMS %-43s - ",$lsfile));

            if (-s $lfile and !$UEMSinstall{OPTION}{nolocal}) {
                &PrintMessage(0,1,14,0,0,"Found locally");
            } else { #  Get the files from the source
                if ($UEMSinstall{OPTION}{repodir}) {
                    &SysDied("Failed: cp -f $rfile $lfile") if system "cp -f $rfile $lfile";
                    &PrintMessage(0,1,12,0,0,"Copied");
                } else {
                    &SysDied("Failed: Http acquisition") if &GetFileHTTP($rfile,$lfile);
                    &PrintMessage(0,1,12,0,0,"Downloaded");
                }
            }

            if ($UEMSinstall{OPTION}{nounpack}) {&PrintMessage(0,1,12,0,1,"; Not Installed");next;}
            &SysDied("Failed: Unpack of $lfile") if &UnpackTarfile($lfile,$UEMSinstall{UEMSHOME});
            &PrintMessage(0,1,12,0,1,"& Installed");

        }
    }


return 0;
} # End of UEMS_SystemAddpacks


sub Install_UserIntroduction {
#  ===========================================================================================
#  If this is a fresh installation then provide an introduction to the process;
#  otherwise just get out.
#  ===========================================================================================
#
    return 0 if $UEMSinstall{IEMS}{cuems}; # $UEMSinstall{IEMS}{cuems} should be 0 if $EMS not set


    &PrintMessage(1,4,92,2,1,'We shall start with some old-school user interrogation');

    $mesg = 'Before we begin this rather painless process, I will need to ask a few '.
            'questions regarding the location and ownership of the EMS.';
    &PrintMessage(0,7,92,1,1,$mesg);


    if ($>) {
        $mesg = "Since you are not installing as root user, the ownership will be initially given to user \"$UEMSinstall{IUSER}{uname}\" ".
                "but you may change it later. Additionally, you must have write permission on the installation ".
                "directory, which will be specified by you shortly.";
        &PrintMessage(0,7,92,1,1,$mesg);
    } else {
        $mesg = "Since you are installing the release as root user, this process should go smoothly. You will ".
                "be asked for a user name to assign ownership of the files and a location for the ".
                "installation. If the user does not exist then an account will be created.\n\n".

                "Note that running the UEMS currently requires users run bash or [t]csh as their shell. ".
                "This requirement may change someday but it won't be tomorrow unless you are doing all ".
                "the work.";

        &PrintMessage(0,7,92,1,1,$mesg);
    }


    $mesg = $UEMSinstall{OPTION}{allyes} ? "Do you wish to continue? [Yes] Yes" : "Do you wish to continue? [Yes] ";
    &PrintMessage(0,9,92,1,0,$mesg);


    unless ($UEMSinstall{OPTION}{allyes}) {
        my $ans = <>; chomp $ans; $ans =~ s/\s+//g;
        my $resp = $ans ? $ans : "Yes"; 
        &SysDied('I\'m rather disappointed in you!',0) unless $resp =~ /^Y/i or $resp =~ /^OK/i;
    }

    &PrintMessage(0,7,20,1,1,"So let us continue this forbidden UEMS dance...");


return;
}


sub Install_FindLocation {
#  ===========================================================================================
#    This routine gets the home directory for the UEMS
#  ===========================================================================================
#
use Cwd;
use POSIX;
use List::Util 'first';

    my $csh    = -e '/bin/csh'  ? '/bin/csh' : 0;
    my $tcsh   = -e '/bin/tcsh' ? '/bin/tcsh': 0;
    my $bash   = -e '/bin/bash' ? '/bin/bash': 0;

    #  -------------------------------------------------------------------------------------------
    #  At this point assume that this is a fresh install. If an installation currently exists
    #  on the system then the path should be saved in $UEMSinstall{UEMSHOME}.  
    #  -------------------------------------------------------------------------------------------
    #
    my $instems      = $UEMSinstall{UEMSHOME} ? $UEMSinstall{UEMSHOME} : $UEMSinstall{IEMS}{emsenv} ? $UEMSinstall{IEMS}{emsenv} : 0;
    my ($root, $ems) = $UEMSinstall{UEMSHOME} ? &popit2($UEMSinstall{UEMSHOME}) : (0,0);
    my $defroot      = $root ? $root : '/usr1';


    unless ($instems) {

        &PrintMessage(1,4,144,2,1,'Finding that perfect home - Location, Location, ... then Simulation');

        $mesg = "You need to specify the directory where the UEMS will live and grow with you; ".
                "after all, it's your baby now. The UEMS requires a lot of space, about 180Gb to ".
                "start, which will only increase in size as you spend all your free time ".
                "enjoying the fruits of its labor, so a partition with at least 300Gb is ".
                "recommended.\n\n";

        &PrintMessage(0,7,92,1,1,$mesg);

        &PrintMessage(0,7,92,0,1,"The default location is \"$defroot\" but you can put anywhere provided you have write permission.");

        &PrintMessage(0,7,96,1,0,"Where would you like to install your UEMS? [$defroot] ");
        my $ans = <>; chomp $ans; $ans =~ s/\s+//g;
        $root = $ans ? $ans : $defroot; $root =~ s/\s+//g;
        $UEMSinstall{UEMSHOME} = "$root/$UEMSinstall{UEMSTOP}";

    }

    #  -------------------------------------------------------------------------------------------
    #  A UEMS installation, or a previous attempt, already exists in this location. If it's
    #  just an empty uems directory the delete it and carry on as if nothing happened. What
    #  must be checked is whether a release file exists, indicating at lease a partial install
    #  and whether there is a release directory.
    #  -------------------------------------------------------------------------------------------
    #
    my $nrel = (-e "$UEMSinstall{UEMSHOME}/strc"    and -e "$UEMSinstall{UEMSHOME}/strc/.release")                ? 1 : 0;
    my $drel = (-e "$UEMSinstall{UEMSHOME}/release" and &FileMatch("$UEMSinstall{UEMSHOME}/release",'\.tbz',0,0)) ? 1 : 0;
    my $runs = (-e "$UEMSinstall{UEMSHOME}/runs"    and &FileMatch("$UEMSinstall{UEMSHOME}/runs",'',0,0))         ? 1 : 0;

    &rm($UEMSinstall{UEMSHOME}) unless $nrel or $drel or $runs;



    my $valid  = 0;
    my @valids = qw(1 2 3 4);

    while (! $valid) {

        unless ($root) {
            &PrintMessage(0,7,96,2,0,"Where would you like to install the UEMS? [$defroot] ");
            my $ans = <>; chomp $ans; $ans =~ s/\s+//g;
            $root = $ans ? $ans : $defroot;
            $root = Cwd::realpath($root);
            $UEMSinstall{UEMSHOME} = "$root/$UEMSinstall{UEMSTOP}";
        }


        $valid = 1;
        if (! -d $root) {

            &PrintMessage(6,7,96,1,1,"OOPS! $root is not a valid directory. Let us try it again.");
            $valid = 0;
            $root  = 0;
            $UEMSinstall{UEMSHOME} = 0;

        } elsif (! -w $root) {

            &PrintMessage(6,7,96,1,1,"BUMMER! $UEMSinstall{IUSER}{uname} does not have write permission on $root.");
            &PrintMessage(0,9,96,1,0,'Do you want to continue? [No] ');
            my $ans = <>; chomp $ans; $ans =~ s/\s+//g;
            &SysDied("Let's do this again! Can we? Can we?") unless $ans =~ /^Y/i;
            $valid = 0;
            $root     = 0;
            $UEMSinstall{UEMSHOME} = 0;

        } elsif (-e $UEMSinstall{UEMSHOME}) {

            $valid = 0;
            my $emstop = Cwd::realpath($UEMSinstall{UEMSHOME});  #  Absolute path to the top of the EMS
            my $emsprv = $emstop; #  Just in case wee need the old path for @imports
            my $irel   = &GetUEMSrelease($emstop); $irel = 'Unknown' unless $irel;

            &SysDied("What exactly is this: $UEMSinstall{UEMSHOME}") unless $emstop;

            unless ($UEMSinstall{OPTION}{continue}) {

                $emstop  = "$emstop.$irel"; #  $emstop - new (renamed) name for existing UEMS installation

                &rm($emstop) if -e $emstop and -l $emstop;
                if (-e $emstop) {my $n=2; $n++ while -e "${emstop}_$n";$emstop = "${emstop}_$n";}
                my $emsdir  = &popit($emstop);

                $valid = 2 if $UEMSinstall{OPTION}{scour};

                unless ($valid == 2) {

                    #  -------------------------------------------------------------------------------------------
                    #  A UEMS installation, or a previous attempt, already exists in this location. If it's
                    #  just an empty uems directory the delete it and carry on as if nothing happened.
                    #  -------------------------------------------------------------------------------------------
                    #
                    $mesg = "It appears that a UEMS installation already exists in $UEMSinstall{UEMSHOME}.\n\n";
                    $mesg = "It appears that a UEMS installation already exists in $UEMSinstall{UEMSHOME}, ".
                            "although I can not determine the release version, if any. These files may be left over ".
                            "from a previous failed/aborted installation attempt.\n\n" if $irel eq 'Unknown';
    
                    &PrintMessage(6,4,92,2,0,$mesg);
    
                    my $optA = sprintf("%-66s (Option 1)","1. Delete the existing UEMS installation, version \"$irel\"");
                    my $optB = sprintf("%-66s (Option 2)","2. Rename the existing UEMS installation to \"uems.$irel\" ");
                    my $optC = sprintf("%-66s (Option 3)","3. Choose another location for the UEMS installation");
                    my $optD = sprintf("%-66s (Option 4)","4. Continue the UEMS download and installation at this location");
                    my $optE = sprintf("%-66s (Anything else)","Q. Forget this \^\$\&\*\@ thing, I'm out of here!");

                    $mesg = "It's your choice how we will continue this process. You can:\n\n".
    
                            "$optA\n".
                            "$optB\n".
                            "$optC\n".
                            "$optD\n".
                            "$optE\n";

                    &PrintMessage(0,7,254,1,0,$mesg);


                    &PrintMessage(0,7,96,1,0,'What shall it be, 1, 2, 3, or 4? : ');
                    my $ans = <>; chomp $ans; $ans =~ s/\s+//g;
                    $valid = first { /^${ans}$/ } @valids;
                    &SysDied('That was a brief coexistence!',0) unless $valid;

                }   #  unless $valid == 2


                if ($valid == 1) {
                    &PrintMessage(0,7,96,2,0,'Are you sure you want to delete the current UEMS? [Yes|No] : ');
                    my $ans = <>; chomp $ans; $ans =~ s/\s+//g;
                    if ($ans =~ /^Y/i) {&rm($UEMSinstall{UEMSHOME});} else {$valid = 0;}
                }


                if ($valid == 2) {system "mv $UEMSinstall{UEMSHOME} $emstop"; &PrintMessage(6,7,92,1,2,"The existing $UEMSinstall{UEMSHOME} directory has been moved to $emstop.");}


                $UEMSinstall{EMSPRV}  = $emstop;  #  Need to keep track of previous release for --scour
                $UEMSinstall{CURRENT} = $UEMSinstall{EMSPRV};

                #  -------------------------------------------------------------------------------------------
                #  Sort through the list of domain directories to be imported and rename the path to the
                #  previous installation.  The old path is in $emsprv and the new path is $emstop
                #  -------------------------------------------------------------------------------------------
                #
                if ($valid == 2) {foreach (@{$UEMSinstall{OPTION}{imports}}) { s/$emsprv/$emstop/g;} }

                if ($valid == 3) {$valid = 0;$root = 0;}

                if ($valid == 4) {$UEMSinstall{OPTION}{continue} = 1;}

            }  # Unless continue

            $valid = 4 if $UEMSinstall{OPTION}{continue};  #  In case the user passed --continue
        }

    }

    &SysDied('The mkdir gods are not happy with you ($UEMSinstall{UEMSHOME})!') if &mkdir($UEMSinstall{UEMSHOME});

    &PrintMessage(0,7,92,1,1,"The new UEMS installation will be located in $UEMSinstall{UEMSHOME}");

    #  Check if installed
    #
    &PrintMessage(1,4,92,2,1,"Checking if an acceptable system shell is available on the system");

    $mesg = "IMPORTANT: The user assigned ownership of the UEMS must run a Bash or Tcsh ".
            "shell environment. This shell must also be installed on any other systems running the UEMS.";

    &PrintMessage(6,7,86,1,1,$mesg);

    &PrintMessage(7,10,28,1,0,'Is Tcsh shell installed? - ');
    $tcsh ? &PrintMessage(0,1,3,0,0,'Yes') : &PrintMessage(0,1,3,0,0,'No');

    &PrintMessage(7,10,28,1,0,'Is Csh shell installed?  - ');
    $csh  ? &PrintMessage(0,1,3,0,0,'Yes') : &PrintMessage(0,1,3,0,0,'No');

    &PrintMessage(7,10,28,1,0,'Is Bash shell installed? - ');
    $bash ? &PrintMessage(0,1,3,0,1,'Yes') : &PrintMessage(0,1,3,0,1,'No');

    unless ($bash or $tcsh or $csh) {
        $mesg = 'It appears that neither Bash nor [T]csh shells are installed on your system. '.
                'The UEMS requires that one of these shells be installed and that it be assigned '.
                'to the user running the system.';

        &PrintMessage(6,7,92,1,1,$mesg);
        my $ans = 'Yes';

        &PrintMessage(0,10,96,1,0,'Do you wish to continue with the installation? [Yes] ');
        $ans = <>; chomp $ans; $ans =~ s/\s+//g; $ans = 'Yes' unless $ans;
        unless ($ans =~ /^Y/i) {
            &rm($UEMSinstall{UEMSHOME});
            &SysDied('I am missing you already!');
        }
    }


return $valid ? 0 : 1;
}


sub Install_DefineOwner {
#-----------------------------------------------------------------------------------
#  Routines guides the installer in choosing an owner for the UEMS. If a user
#  account is not available on the system then one will be created.
#-----------------------------------------------------------------------------------
#
    my $csh    = -e "/bin/csh"  ? '/bin/csh' : 0;
    my $tcsh   = -e "/bin/tcsh" ? '/bin/tcsh': 0;
    my $bash   = -e "/bin/bash" ? '/bin/bash': 0;
    my $shell  = 0;

    $UEMSinstall{EUSER}{uname} = 'emsuser' if $UEMSinstall{IUSER}{uname} eq 'root';

    unless ($>) {
        my $noname=1;
        &PrintMessage(1,4,92,2,1,"OK, Enough About Me. What About ... YOU?");
        while ($noname) {
            &PrintMessage(0,9,92,1,0,"To whom shall I assign guardianship of the EMS? [$UEMSinstall{EUSER}{uname}]: ");
            my $ans = <>; chomp $ans; $ans =~ s/\s+//g;
            $ans = $UEMSinstall{EUSER}{uname} if !$ans and $UEMSinstall{EUSER}{uname};
            if (!$ans or $ans =~ /^root$/i) {
                $mesg = "Sorry but user $ans is not allowed. Try something without \"root\" ".
                        "in the name.";
                &PrintMessage(6,7,92,1,1,$mesg);
            } else {
                $UEMSinstall{EUSER}{uname} = $ans ? $ans : $UEMSinstall{EUSER}{uname};
                $noname=0 if $UEMSinstall{EUSER}{uname} ne 'root';
            }
        }
    }

    my @user = ();
    if (@user = getpwnam $UEMSinstall{EUSER}{uname}) {

        $shell = $user[-1];

        unless ($shell =~ /\/bin\/tcsh|\/bin\/csh|\/bin\/bash/) {
            my $s = &popit($shell);
            $mesg = "WARNING: User $UEMSinstall{EUSER}{uname} is NOT running a Tcsh or Bash shell! (current: $s)!\n\nBe sure ".
                    "to fix this problem before running the EMS; otherwise, you will be greatly disappointed. ".
                    "And we do not want that to happen now do we?";
            &PrintMessage(6,7,92,1,1,$mesg);

            &PrintMessage(0,10,92,1,0,"I accept the consequences of not using the proper shell environment [Yes]: ");
            my $ans = <>; chomp $ans; $ans =~ s/\s+//g;
            &PrintMessage(0,10,92,1,0," ");
            $shell = 0;
        }


        if ($shell =~ /\/bin\/csh/) {
           $mesg = "WARNING: It is strongly recommended that you switch from your current C shell (/bin/csh) to ".
                   "either a T (/bin/tcsh) or Bash (/bin/bash) shell.  Using a C shell with the UEMS has shown to ".
                   "cause problems on some Linux systems (Debian & Ubuntu) as well as promote tooth decay.\n\n".

                   "Since it is the policy of the UEMS not to promote ANYTHING (the UEMS is \"tooth decay neutral\"), ".
                   "you should make this change while you have most of your teeth.";

           &PrintMessage(6,7,92,1,1,$mesg);

           &PrintMessage(0,10,92,1,0,"I accept the consequences of not using the proper shell environment, or flossing [Yes]: ");
           my $ans = <>; chomp $ans; $ans =~ s/\s+//g;
           &PrintMessage(0,10,92,1,0," ");
       }


    } else {

        $shell = ($bash and ($tcsh or $csh)) ? 0 : $bash ? $bash : $tcsh;

        if (! $>) {

            $mesg = "User $UEMSinstall{EUSER}{uname} does not exist on the system.";
            &PrintMessage(6,7,92,1,2,$mesg);

            $mesg = $shell ? "Don't worry, I can create a user account for \"$UEMSinstall{EUSER}{uname}\". System defaults will be used for the ".
                             "user and group IDs, and login shell will be $shell."
                           : "Don't worry, I can create a user account for \"$UEMSinstall{EUSER}{uname}\". System defaults will be used for the ".
                             "user and group IDs.";

            &PrintMessage(0,7,86,1,1,$mesg);

            &PrintMessage(0,9,92,1,0,"Do you want to create a user account? [Yes]: ");
            my $ans = <>; chomp $ans; $ans =~ s/\s+//g;
            my $resp = $ans ? $ans : "Yes";
            unless ($resp =~ /^Y/i) {
                &PrintMessage(0,7,92,2,2,"You will have to create a user account for $UEMSinstall{EUSER}{uname} continuing. - Bye Bye");
                &rm($UEMSinstall{UEMSHOME});

                &SysDied("I\'ll be waiting for you right here!");
            }

            # check to see which shells are available on the system
            #
            unless ($bash or $tcsh or $csh) {
                $mesg = "None of the UEMS required system shells ($bash, $tcsh or $csh) could be found!\n\nPlease install a shell and run $UEMSinstall{EXE} again.";
                &PrintMessage(6,7,92,2,2,$mesg);
                &rm($UEMSinstall{UEMSHOME});
                &SysDied("I\'ll be waiting for you right here!");
            }

            if ($bash and ($csh or $tcsh)) {

                my $def = $tcsh ? $tcsh : $csh;

                my $opt = "$def or $bash";
                &PrintMessage(0,9,92,1,0,"Which Shell do you prefer, $opt [$def]? ");

                $ans = <>; chomp $ans; $ans =~ s/\s+//g;
                $shell = $ans ? $ans : $def;

                for ($shell) {$_ = /tcsh/i ? $tcsh : /csh/i ? $csh : /bash/i ? $bash : $def;}

            } else {

                $shell = $bash if $bash;
                $shell = $csh  if $csh;
                $shell = $tcsh if $tcsh;

            }


            &PrintMessage(0,9,92,1,0,"Please specify a password for user $UEMSinstall{EUSER}{uname} [disable account]: ");

            $ans = <>; chomp $ans; $ans =~ s/\s+//g;
            my $pw  = $ans ? $ans : "";

            my $homedir = "-d /home/$UEMSinstall{EUSER}{uname}";
            my $desc    = "-c \"Awesome UEMS Owner\"";
            my $ushell  = "-s $shell";

            if (system "/usr/sbin/useradd -m $homedir $desc $ushell $UEMSinstall{EUSER}{uname} > /dev/null 2>&1") {
                &PrintMessage(3,7,92,1,1,"Creation of account for user $UEMSinstall{EUSER}{uname} failed. Installing as user root.");
                &PrintMessage(0,7,92,1,1,"You will have to create the account for user $UEMSinstall{EUSER}{uname} manually and then change ownership.");

                &PrintMessage(0,9,92,1,0,"Is this OK with you? [Ok by me!] ");
                my $ans = <>; chomp $ans; $ans =~ s/\s+//g;
                my $resp = $ans ? $ans : "Yes";
                return 1 if $resp !~ /^Y|^O/i;

            } else {
                if ($pw) {
                    &PrintMessage(0,7,92,1,0,"A user account for \"$UEMSinstall{EUSER}{uname}\" has been created.");
                    if (system "echo $pw | /usr/bin/passwd --stdin $UEMSinstall{EUSER}{uname} > /dev/null 2>&1") {
                       $mesg = "Password creation failed. Account initially disabled. You will have ".
                               "to run the passwd command to enable the account.";
                       &PrintMessage(6,7,92,2,2,$mesg);
                    } else {
                       &PrintMessage(0,7,92,2,2,"The password file has been updated.");
                    }
                } else {
                    &PrintMessage(0,7,92,2,1,"User account for \"$UEMSinstall{EUSER}{uname}\" created");
                    $mesg = "Account initially disabled. You will have to run the passwd command ".
                            "to enable the account.";
                    &PrintMessage(0,7,92,1,1,$mesg);
                }

            } # End useradd
        }
    }

    %{$UEMSinstall{EUSER}} = &CollectUserInfo($UEMSinstall{EUSER}{uname});


return;
}


sub Install_ImportDomains {
#----------------------------------------------------------------------------------
#  This routine imports and refreshes the requested computational domains when
#  completing a new installation.
#----------------------------------------------------------------------------------
#
use Cwd;

    my $imported= 0;
    my @domains = @_; return unless @domains;

    foreach my $domorig (@domains) {

        my $domain   = &popit($domorig);
        my $domdest = "$UEMSinstall{UEMSHOME}/runs/$domain";

        my $mesg = "Importing $domorig to $UEMSinstall{UEMSHOME}/runs - ";
        my $l = length $mesg;
        &PrintMessage(1,4,$l+7,2,0,$mesg);

        if (-e $domdest) {
            &PrintMessage(0,0,14,0,1,' Failed (Already Exists)');
            &PrintMessage(6,4,255,1,1,"Not Imported: Domain \"$domain\" already exists under $domdest");
            next;
        }

        #  Step 1.  Copy (rsync) the requested domains to new uems/runs directory
        # 
        if (system "rsync -aq $domorig  $UEMSinstall{UEMSHOME}/runs > /dev/null 2>&1") {
            &PrintMessage(0,0,24,0,1," Failed ($?)");
            &PrintMessage(6,4,255,1,1,"Import Failed: Attempted import of $domorig to $UEMSinstall{UEMSHOME}/runs");
            next;
        }
        &PrintMessage(0,1,10,0,2,'Completed');


        #  Step 2.  Refresh and update the domain with the latest configuration files
        #
        &PrintMessage(1,4,255,1,1,"Updating configuration files under $domdest");

        &UpdateConfigurationFiles($domdest);
        &UpdatePostProcessorFiles($domdest);
        &RefreshNamelistPaths($domdest);

        $imported++;
   }


   #  Tell the user to localize the imported domain
   #

   if ($imported) {
       $mesg = "Now that your domains have been imported, it is up to you to re-localize them before they can be used.";
       &PrintMessage(6,4,94,1,1,$mesg);

       $mesg = "To complete this last step, from each domain directory simply run\n\n".
               "   % ems_domain --localize";
       &PrintMessage(0,7,94,1,1,$mesg);

       $mesg = "You must log out and back in again prior to running the ems_domain utility to ensure ".
               "the environment variables are properly set.";
       &PrintMessage(0,7,94,1,1,$mesg);
   }


return 0;
}


sub Install_PreConfiguration {
#  ===========================================================================================
#   This routine does the initial prep work for the installation
#  ===========================================================================================
#

    return 1 if &Install_UserIntroduction();

    return 1 if &Install_FindLocation();

    return 1 if &Install_DefineOwner();


    $mesg = "The top level of the UEMS is not defined, so I am unable to complete ".
            "whatever task you are requesting. So either you need to make sure that ".
            "the UEMS environment variable is set or you can pass the \"--emshome <path>\" ".
            "option.\n\n".

            "Just providing the type of service that YOU deserve!";

    &SysDied($mesg) unless $UEMSinstall{UEMSHOME};


    $mesg = "I am looking for the UEMS here:\n\n".
            "    $UEMSinstall{UEMSHOME}\n\n".
            "But I don't see it. Which one of us needs glasses?\n\n".

            "Either you need to make sure that the UEMS environment variable is correctly ".
            "set or you can pass the \"--emshome <path>\" option.\n\n".

            "Just providing the type of service that YOU deserve!";

    &SysDied($mesg) unless -e $UEMSinstall{UEMSHOME};



    #  Set the default path to the necessary directories
    #
    $UEMSinstall{OPTION}{releasedir}  = $UEMSinstall{OPTION}{releasedir}  ? $UEMSinstall{OPTION}{releasedir}  : "$UEMSinstall{UEMSHOME}/release";
    &SysDied('The mkdir gods are not happy with you ($UEMSinstall{OPTION}{releasedir})!') if &mkdir($UEMSinstall{OPTION}{releasedir});


    #  Inform the user regarding the number of CPUs
    #
    &PrintInfoCPU();

    &PrintMessage(0,7,96,2,2,&GetSystemInfoString(\%{$UEMSinstall{ISYS}}));


return;
}  #  End Install_PreConfiguration


sub Install_PostConfiguration {
#  ==================================================================================
#  This routine does the post install configuration of the package
#  ==================================================================================
#
    &PrintMessage(1,4,92,2,1,'Completing post-install configuration');


    unless (%{$UEMSinstall{ADDPACKS}}) {

        &ConfigureLocalSystemFiles();  #  Fill in configuration placeholders with user's information

        #  ----------------------------------------------------------------------------------
        #  The post_install.pl does any necessary clean up of the system due to changes 
        #  from release to release. This includes deleting files that are no longer used 
        #  and renaming files as necessary. After this task is completed the 
        #  post_install.pl is removed.
        #  ----------------------------------------------------------------------------------
        #
        my $postexe = "$UEMSinstall{UEMSHOME}/strc/Ubin/post_install.pl";
        system "$postexe $UEMSinstall{UEMSHOME}" if -f $postexe; &rm($postexe);

        unless ($<) {
            &PrintMessage(0,7,92,1,1,"Setting ownership of UEMS to $UEMSinstall{EUSER}{uname}\:$UEMSinstall{EUSER}{gname}");
            system "/bin/chown -R $UEMSinstall{EUSER}{uname}:$UEMSinstall{EUSER}{gname} $UEMSinstall{UEMSHOME} > /dev/null 2>&1";
        }
        &MissingLibraryTest();
        &ConfigureUserGuidance();
    }
    &MissingLibraryTest() if %{$UEMSinstall{ADDPACKS}};


return;
}  #  End Install_PostConfiguration


sub UEMS_SystemUpdate {
#  ===========================================================================================
#  This routine handles all steps in updating an existing UEMS
#  ===========================================================================================
#
    return -1 unless %{$UEMSinstall{UPDATES}};

    
    #  --------------------------------------------------------------------------------
    #    Create a sorted list containing the update packages. Note that @updates
    #    contains all the available updates.
    #  --------------------------------------------------------------------------------
    #
    my @updates  = &SortPackages(keys %{$UEMSinstall{UPDATES}});

    my $src = $UEMSinstall{EMSHOST} ? 'on the UEMS server' : 'in the specified repository';
    $mesg = "There appears to be a problem in that either there are no UEMS updates available ".
            "$src or there was a problem getting the update information.\n\n".

            "You can add the \"--list\" or \"--listall\" flag for a listing of the available ".
            "EMS package files.\n\n".

            "Regardless, this is not looking good for you, although you still look good!";

    &SysDied($mesg) unless @updates;



    #  --------------------------------------------------------------------------------
    #    Provide some debugging information if requested
    #  --------------------------------------------------------------------------------
    #
    if ($UEMSinstall{OPTION}{debug}) {
        $mesg = $UEMSinstall{EMSHOST} ? "Available updates on $UEMSinstall{EMSHOST}"
                                      : "Available updates in $UEMSinstall{OPTION}{repodir}";
        &PrintMessage(0,9,78,1,2,$mesg);
        foreach (@updates) {
            my ($reldir,$f)=&popit2((keys %{$UEMSinstall{UPDATES}{$_}})[0]); 
            &PrintMessage(1,11,144,0,2,"UPDATE : $_\nLOCATION: $reldir");
       }
    }


    #  --------------------------------------------------------------------------------
    #    At this point we should have an UEMS directory on the system. Now we need to
    #    get the system information to determine which release files to download.
    #  --------------------------------------------------------------------------------
    #
    my $frel = $UEMSinstall{IEMS}{emsver} ? $UEMSinstall{IEMS}{emsver} : 0; my $irel = $frel;

    &PrintMessage(1,4,78,1,2,"Current Installed Release: $frel") if $UEMSinstall{OPTION}{debug};


    #  --------------------------------------------------------------------------------
    #    It is assumed that the user knows what he or she is doing; however, we must
    #    check that the requested update exists and provide a warning should they
    #    attempt to install an earlier update.
    #  --------------------------------------------------------------------------------
    #
    return $updates[0] unless @updates and $updates[0] ne '1'; #  No files


    #  Now manage the argument passed to the --update flag
    #
    $UEMSinstall{OPTION}{update} = $updates[0] if $UEMSinstall{OPTION}{update} eq 'current';


    #  --------------------------------------------------------------------------------
    #    Current?  - Great
    #  --------------------------------------------------------------------------------
    #
    unless (&CompareReleaseNumbers($frel,$UEMSinstall{OPTION}{update})) {
        &PrintMessage(2,4,144,2,1,"No need to update - You are current (V$frel), and beautiful!");
        return 0;
    }


    #  --------------------------------------------------------------------------------
    #  Check the current installation before continuing.
    #  --------------------------------------------------------------------------------
    #
    $mesg = "No swim'n with the fishes!\n\nCall me an idiot, but it appears that you are attempting ".
            "to \"update\" to a previous release ($frel -> $UEMSinstall{OPTION}{update}), but who am I to question ".
            "your lack of judgement during this apparent time of need?  Oh yes, the UEMS Godfather.";

    &SysDied($mesg) if &CompareReleaseNumbers($UEMSinstall{OPTION}{update},$irel) < 0;


    $mesg = "Your Bad!\n\n".
            "It appears that you are attempting to update to a non-existent release (V$UEMSinstall{OPTION}{update}). ".
            "Go take a break and try me again in 15 minutes. Maybe the release will magically appear, or not.";


    &SysDied($mesg) unless (grep (/$UEMSinstall{OPTION}{update}/, @updates));


    #  --------------------------------------------------------------------------------
    #  Eliminate those updates that predate the current release
    #  --------------------------------------------------------------------------------
    #
    my @slist=(); foreach (@updates) {push @slist => $_ if &CompareReleaseNumbers($_,$irel) > 0;} @updates = @slist;


    #  --------------------------------------------------------------------------------
    #  Eliminate those updates that post date the requested update release, which 
    #  does not have to be the most current available.
    #  --------------------------------------------------------------------------------
    #
    @slist=(); foreach (@updates) {push @slist => $_ unless &CompareReleaseNumbers($_,$UEMSinstall{OPTION}{update}) > 0;} @updates = @slist;

    if ($UEMSinstall{OPTION}{debug}) {
        &PrintMessage(0,9,78,1,2,"After Reconciling Updates");
        &PrintMessage(1,11,78,0,1,"UPDATE: $_") foreach @updates;
        &PrintMessage(1,11,78,0,1,"UPDATE: None Needed") unless @updates;
    }

    &SysDied('The update preparation gnomes are not happy!') if &Update_PreConfiguration();



    #  --------------------------------------------------------------------------------------
    #    Begin the process of updating the UEMS. This includes downloading and installing
    #    the necessary "update.*" files from the identified server or repository, and then
    #    running the configuration routine. Note that @updates contains the files in
    #    reverse order so that the latest files are installed last.
    #  --------------------------------------------------------------------------------------
    #
    $mesg = $UEMSinstall{OPTION}{nounpack} ?  "I'll download the following updates but you must complete the installation ($updates[0]):" :
                                              "I'll install the following updates to bring your UEMS to the requested level ($updates[0]):" ;
    &PrintMessage(1,4,144,2,2,$mesg);

    &PrintMessage(0,9,78,0,1,"Update Release: $_") foreach reverse @updates;

    #  --------------------------------------------------------------------------------
    #  Make sure the user is ready for the installation
    #  --------------------------------------------------------------------------------
    #
    unless ($UEMSinstall{OPTION}{allyes}) {
        &PrintMessage(0,7,144,1,0,'Is this OK by you? [OK by me]: ');
        my $ans = <>; chomp $ans; $ans =~ s/\s+//g;
        my $resp = $ans ? $ans : "Yes";
        unless ($resp =~ /^Y/i or $resp =~ /^OK/i) {
            &PrintMessage(0,7,92,1,1,'Maybe we can try again later - Bye');
            return 3;
        } 
        &PrintMessage(0,1,144,0,1,q{ });
    }


    #  --------------------------------------------------------------------------------
    #    Any downloaded tarfiles will be placed in $UEMSinstall{OPTION}{updatedir},
    #    but first take inventory of any package files that currently exist to 
    #    determine what done.
    #  --------------------------------------------------------------------------------
    #
    my %existing = ();
    foreach (&FileMatch($UEMSinstall{OPTION}{updatedir},'',0,1))  {$existing{&popit($_)} = -s $_;}
    %existing = () if $UEMSinstall{OPTION}{nolocal};


    my %tarfiles = ();
    foreach my $update (reverse @updates) {

        next unless keys %{$UEMSinstall{UPDATES}{$update}};

        my %updfile = %{$UEMSinstall{UPDATES}{$update}};

        foreach my $rfile (keys %updfile) { next unless $rfile;
            for (&popit($rfile)) {
                next if /^wrf\.geog_/;  #  Geog files handled in a different routine
                if (defined $existing{$_} and ($existing{$_} == $updfile{$rfile}) and !$UEMSinstall{OPTION}{force}) {
                    &PrintMessage(8,4,114,1,0,sprintf('%-48s  %s',"Already installed ($_)","Pass \"--force\" flag to re-install"));
                    next;
                }
                push @{$tarfiles{$update}} => $rfile;
            }
        }
    }  return 0 unless %tarfiles;


    #  --------------------------------------------------------------------------------
    #    Begin the acquisition & installation process for each file group. The
    #    order of package installation is important as some directories must
    #    be created before other packages can be installed.  
    #  --------------------------------------------------------------------------------
    #
    my $wrel = '';
    my $inst = $UEMSinstall{OPTION}{nounpack} ? '' : 'and installing ';


    if (%tarfiles) {&PrintMessage(1,4,78,1,2,"Beginning UEMS update process - Are you excited yet?");

        my %alph;
           @alph{'a' .. 'z'} = (0 .. 25);

        $wrel = &GetWRFrelease(); #  $wrel - WRF release $frel - current installed release

        foreach my $updt (reverse &SortPackages(keys %tarfiles)) {

            my $nf = @{$tarfiles{$updt}};
            my $n  = 0;

            foreach my $rfile (sort @{$tarfiles{$updt}}) {$n++;

                my $lsfile = &popit($rfile); next unless $lsfile;
                my $lfile  = "$UEMSinstall{OPTION}{updatedir}/$lsfile";
                my $cnt    = sprintf("%10s","$n of $nf :");

                &PrintMessage(0,7,108,0,0,sprintf("$cnt UEMS %-43s - ",$lsfile));

                if (-s $lfile and !$UEMSinstall{OPTION}{nolocal}) {
                    &PrintMessage(0,1,14,0,0,"Found locally");
                } else { #  Get the files from the source
                    if ($UEMSinstall{OPTION}{repodir}) {
                        &SysDied("Failed: cp -f $rfile $lfile") if system "cp -f $rfile $lfile";
                        &PrintMessage(0,1,12,0,0,"Copied");
                    } else {
                        &SysDied("Failed during http acquisition - Check connection & local file system") if &GetFileHTTP($rfile,$lfile);
                        &PrintMessage(0,1,12,0,0,"Downloaded");
                    }
                }

                if ($UEMSinstall{OPTION}{nounpack}) {&PrintMessage(0,1,12,0,1,"; Not Installed");next;}
                &SysDied("Failed: Unpack of $lfile") if &UnpackTarfile($lfile,$UEMSinstall{UEMSHOME});
                &PrintMessage(0,1,12,0,1,"& Installed");

                if ($lsfile =~ s/wrfbin_(\w+)\.x64//) {my @wvl = split // => $1;$_ = $alph{$_} foreach @wvl; $wrel = join '.' => @wvl;}

            }  #  foreach my $rfile
        }
    }

    #  --------------------------------------------------------------------------------
    #    That's all the downloading and installation - On to configuration.
    #  --------------------------------------------------------------------------------
    #
    return if $UEMSinstall{OPTION}{nounpack};

    &SysDied('The update configuration gods are not happy with you!')  if &Update_PostConfiguration();

    #  Refresh any configuration files that might have changed since the previous release
    #
    &Update_RefreshDomains() if $UEMSinstall{OPTION}{refresh};

return 0;
} # End of UEMS_SystemUpdate


sub Update_PreConfiguration {
#  ===========================================================================================
#   This routine does the initial prep work for the update
#  ===========================================================================================
#
use File::stat;

    $mesg = "The top level of the UEMS is not defined, so I am unable to complete the UEMS update. ".
            "You need to make sure that the UEMS environment variable is set or you can pass ".
            "\"--emshome <path>\" flag\n\n".

            "Just providing the type of service that YOU deserve!";

    &SysDied($mesg) unless $UEMSinstall{UEMSHOME};


    $mesg = "Hey you, I am looking for the UEMS here:\n\n".
            "    $UEMSinstall{UEMSHOME}\n\n".
            "But I don't see it. Which one of us needs glasses?\n\n".

            "Either you need to make sure that the UEMS environment variable ".
            "is correctly set or you can pass the \"--emshome <path>\" option.\n\n".

            "Just providing the type of service that YOU deserve!";

    &SysDied($mesg) unless -d $UEMSinstall{UEMSHOME};


    #  Check the ownership of the uems
    #
    my $uid  = stat $UEMSinstall{UEMSHOME}; 
    %{$UEMSinstall{EUSER}}   = &CollectUserInfo($uid->uid);

    if ($UEMSinstall{IUSER}{uname} ne 'root' and $UEMSinstall{EUSER}{uid} != $UEMSinstall{IUSER}{uid}) {

        if ($UEMSinstall{OPTION}{force}) {
            $mesg = "It appears that your user name is $UEMSinstall{IUSER}{uname} ($UEMSinstall{IUSER}{uid}) but the UEMS ".
                    "that I am about to update, $UEMSinstall{UEMSHOME}, is owned by $UEMSinstall{EUSER}{uname} ($UEMSinstall{EUSER}{uid}). ".
                    "Nonetheless, you are forcing me to do this update.";
            &PrintMessage(6,4,92,2,2,"Hey! Model rustling is illegal in these parts!",$mesg);
        } else {
            $mesg = "Hold on there Partner!\n\n".
                    "I don't think I can continue this update as it appears that you are $UEMSinstall{IUSER}{uname} ($UEMSinstall{IUSER}{uid}) ".
                    "and $UEMSinstall{UEMSHOME} is owned by $UEMSinstall{EUSER}{uname} ($UEMSinstall{EUSER}{uid}). Maybe we should think about who's ".
                    "the sheriff around these parts.";
            &SysDied($mesg);
        }

    }


    #  Set the default path to the necessary directories
    #
    $UEMSinstall{OPTION}{updatedir}  = $UEMSinstall{OPTION}{updatedir}  ? $UEMSinstall{OPTION}{updatedir}  : "$UEMSinstall{UEMSHOME}/updates";
    &SysDied('The mkdir gods are not happy with you ($UEMSinstall{OPTION}{updatedir})!') if &mkdir($UEMSinstall{OPTION}{updatedir});


    &PrintMessage(0,7,96,2,2,&GetSystemInfoString(\%{$UEMSinstall{ISYS}}));


return;
} # End Update_PreConfiguration


sub Update_PostConfiguration {
#  ==================================================================================
#  This routine does the post update configuration of the package
#  ==================================================================================
#
    &PrintMessage(1,4,92,1,1,'Completing post-update configuration');

    &ConfigureLocalSystemFiles();  #  Fill in configuration placeholders with user's information

    #  ----------------------------------------------------------------------------------
    #  The post_install.pl does any necessary clean up of the system due to changes 
    #  from release to release. This includes deleting files that are no longer used 
    #  and renaming files as necessary. After this task is completed the 
    #  post_install.pl is removed.
    #  ----------------------------------------------------------------------------------
    #
    my $postexe = "$UEMSinstall{UEMSHOME}/strc/Ubin/post_update.pl";
    system "$postexe $UEMSinstall{UEMSHOME}" if -f $postexe; &rm($postexe);

    unless ($<) {
        &PrintMessage(0,7,92,1,1,"Setting ownership of UEMS to $UEMSinstall{EUSER}{uname}\:$UEMSinstall{EUSER}{gname}");
        system "/bin/chown -R $UEMSinstall{EUSER}{uname}:$UEMSinstall{EUSER}{gname} $UEMSinstall{UEMSHOME} > /dev/null 2>&1";
    }

    &CleanupLocalSystemFiles();

    &MissingLibraryTest();

return;
}  #  End Update_PostConfiguration


sub Update_RefreshDomains {
#----------------------------------------------------------------------------------
#  This routine attempts to refresh the all the configuration files that reside
#  beneath the specified domain directory with those from the current UEMS release.
#  There are multiple steps in the process including the refresh of the run-time
#  configuration files under <domain>/conf,
#----------------------------------------------------------------------------------
#
use Cwd;

    my $startd  = shift; $startd = "$UEMSinstall{UEMSHOME}/runs" unless $startd;
    my @domains = &FindDomainDirectories($startd);

    foreach my $dompath (@domains) {

        my $domain = &popit($dompath);

        &PrintMessage(1,4,114,1,1,"Domain \"$domain\" appears to be in need of some updating (my work is never done!):");
 
        &UpdateConfigurationFiles($dompath);
        &UpdatePostProcessorFiles($dompath);
        &RefreshNamelistPaths($dompath);

    }


return 0;
}


sub UpdateConfigurationFiles {
#  ===============================================================================
#  Refresh the configuration files under <import domain>/conf. 
#  ===============================================================================
#   
use Cwd;
use File::Compare;

    my $alph    = 'a';

    my $task    = 'Refreshing';
    my $taskuc  = 'REFRESH';
    my $saved   = ' (configuration retained)';

    #--------------------------------------------------------------------------------------------
    #  Translate V15 parameters to V18, which will only be of use for a short amount of time.
    #--------------------------------------------------------------------------------------------
    #
    my @noused = qw(INITFH BCFREQ POSTTYPE MONOLITHIC BSCHOOL);
    my %params = ();

       #           V15                   V18
       #-------------------------------------------------------
       $params{GRIBCNTRL_WRFOUT}     = 'GRIB_CNTRL_WRF';
       $params{GRIBCNTRL_AUXHIST}    = 'GRIB_CNTRL_AUX';
       $params{GRIBNAME_WRFOUT}      = 'FILENAME_GRIB';
       $params{GEMFILE_WRFOUT}       = 'FILENAME_GEMPAK';
       $params{BUFRNAME}             = 'FILENAME_BUFR';
       $params{FREQUENCY_AUXHIST}    = 'FREQ_AUX_GRIB';
       $params{FREQUENCY_WRFOUT}     = 'FREQ_WRF_GRIB';
       $params{ACCUM_PERIOD_AUXHIST} = 'ACCUM_PERIOD_AUX';
       $params{ACCUM_PERIOD_WRFOUT}  = 'ACCUM_PERIOD_WRF';
       $params{AUTOPOST_NCPUS}       = 'AUTOUPP_NODECPUS';
       $params{CLEAN}                = 'SCOUR';
       $params{SYNCTS}               = 'TIMESTEP_SYNC';
       $params{ICCG_PRESCRIIBED_DEN} = 'ICCG_PRESCRIBED_DEN';
       $params{ICCG_PRESCRIIBED_NUM} = 'ICCG_PRESCRIBED_NUM';
       $params{ASCII}                = 'ASCISND';
       $params{BFINFO}               = 'BUFR_INFO';
       $params{STNFILE}              = 'STATION_LIST';
       $params{PREPEND}              = 'APPEND_DATE';


    my $model     = lc $UEMSinstall{CORE};

    my $dompath   = shift; $dompath = Cwd::realpath($dompath);
    my $domname   = &popit($dompath);

    my $econf     = "$UEMSinstall{UEMSHOME}/conf";
    my $dconf     = "$dompath/conf";

   my @confdirs  = qw(ems_auto ems_run ems_post);


    foreach my $confdir (@confdirs) { # Foreach configuration directory (ems_auto ems_post ems_run)

        my $nfiles   = 0;
        my $retired  = 1;
        my @retirees = ();

        my $emsconf = "$econf/$confdir";
        my $domconf = "$dconf/$confdir";  &mkdir($domconf); #  The configuration file directory under the target domain


        #--------------------------------------------------------------------------------------------
        #  Open the UEMS configuration directory and read each of the files that end in '.conf',
        #  which indicates a valid configuration file. Store all the settings in a hash for 
        #  repopulating with any updated files from uems/conf/<run-time>/. Note that PARAM = VALUE 
        #  settings for all the config files will saved into a single hash before any updating 
        #  is done. This step is done to allow for filename changes and movement of parameters
        #  between files.
        #--------------------------------------------------------------------------------------------
        #
        my %uservalues = ();

        foreach my $uconf (&FileMatch($domconf,'\.conf$',0,1)) {

            my $ufile = &popit($uconf);


            #-------------------------------------------------------------------------------
            #  The post_export.conf file must be managed  separately due to the multiple 
            #  EXPORT entries.
            #-------------------------------------------------------------------------------
            #
            next if $ufile =~ /post_export/;


            #  Read the local configuration file into a temporary hash
            #
            my %uparms = ();
            my %oparms = &ReadConfigurationFile($uconf);

            #  Do the necessary translation
            #
            foreach (keys %oparms) { defined $params{$_} ? $uparms{$params{$_}} = $oparms{$_} : $uparms{$_} = $oparms{$_}; } 


            #  Write the local file parameters & settings into the main hash
            #
            foreach my $parm (keys %uparms) {$uservalues{$parm} = $uparms{$parm};}

            #  Check whether the local configuration file is current or whether it
            #  has been replaced with a newer, sexier version.
            #
            my $econf = "$emsconf/$ufile";

            unless (-e $econf) {
                if ($retired) {
                    &mkdir("$domconf/retired");
                    $retired = 0;
                }
                system "mv -f $uconf $domconf/retired/${ufile}.retired > /dev/null 2>&1";
                push @retirees => $ufile;
                next;
            }

            #-------------------------------------------------------------------------------
            #  Recondition the user configuration file to eliminate extra spaces and blank
            #  lines.
            #-------------------------------------------------------------------------------
            #
            open (my $ifh, '<', $uconf); my @clines = <$ifh>; close $ifh;
            open (my $ofh, '>', $uconf); foreach (@clines) {chomp;s/^\s+//g;s/\s+$//g;tr/\000-\037//;print $ofh "$_\n";} close $ofh;

        }  # foreach FileMatch


        #--------------------------------------------------------------------------------------------
        #  In the above section the parameter values were read from each configuration file beneath
        #  the domain $confdir directory. Now the remaining files will be updated with the default
        #  files in uems/conf/$confdir .
        #--------------------------------------------------------------------------------------------
        #
        foreach my $econf (&FileMatch($emsconf,'\.conf$',0,1)) {

            my $efile = &popit($econf);
            my $uconf = "$domconf/$efile";

            #-------------------------------------------------------------------------------
            #  We don't want to report that a user configuration file is being updated 
            #  when it isn't really any different from the default version. The problem
            #  is that the Perl compare routine reports ANY difference regardless how minor
            #  it is such as an extra space. In attempt to avoid this problem, both the 
            #  user and default config files will be "reconditioned" prior to the test.
            #
            #  The user files were handled above so now for the default files.
            #
            #  A problem persists in that if the user has modified a default value then
            #  the compare routine will correctly report a difference between the files 
            #  even if that is the only difference, thus the file will be refreshed
            #  every time this routine is run - Ugh.
            #-------------------------------------------------------------------------------
            #
            open (my $ifh, '<', $econf); my @elines = <$ifh>; close $ifh;
            open (my $ofh, '>', $econf); foreach (@elines) {chomp;s/^\s+//g;s/\s+$//g;tr/\000-\037//;print $ofh "$_\n";} close $ofh;

            if (compare($uconf,$econf)) {  #  Compare the domain to the default configuration

                &PrintMessage(0,7,255,$alph eq 'a'? 1 : 2,2,"$alph. Files under conf/$confdir:") unless $nfiles;

                -s $uconf ? &PrintMessage(0,12,255,0,1,"REFRESH  : Configuration file   - $efile")
                          : &PrintMessage(0,12,255,0,1,"NEW CONF : Configuration file   - $efile");


                #-------------------------------------------------------------------------------
                #  post_export.conf requires special handling
                #-------------------------------------------------------------------------------
                #
                if ($efile =~ /post_export/) { 

                    #  Read in the user post_export.conf file to get the parameter values
                    #
                    open (my $ifh, '<', $uconf); my @ulines = <$ifh>; close $ifh;

                    #  Open the same file for write but start by writing the default file
                    #  guidance and information - basically all the comments. Note that the
                    #  bottom 3 lines should remain at the bottom of the files so don't print
                    #  them out just yet.  Also preserve a blank line before and after the 
                    #  user configuration.
                    #
                    open (my $ofh, '>', $uconf);
                    foreach (@elines[0..$#elines-3]) {print $ofh "$_\n" if /^#/;} print $ofh "\n";

                    foreach (@ulines) {
                        chomp; s/^\s+//g; s/\s+$//g;tr/\000-\037//;
                        next if /^#|^$|^\s+/;
                        if (s/\s*EXPORT\s*=\s*//i) {  #  We have a parameter
                            my @values = split /\|/ => $_; $_ =~ s/\s+//g foreach @values;
                            my $exp = sprintf("%2s | %-6s | %-6s | %-4s | %-4s | %-12s | %s",@values[0..6]);
                            print $ofh "EXPORT = $exp\n";
                        }
                    }
                    print $ofh "\n"; foreach (@elines[$#elines-3..$#elines]) {print $ofh "$_\n" if /^#/;}
                    close $ofh; $nfiles++; next;
                }

                #-------------------------------------------------------------------------------
                #  This is a regular configuration file
                #-------------------------------------------------------------------------------
                #
                open (my $ofh, '>', $uconf);

                foreach (@elines) {

                    chomp;s/^\s+//g;s/\s+$//g;tr/\000-\037//;

                    if (/^#|^$|^\s+$/) {print $ofh "$_\n";next;}

                    s/\t//g;s/\n//g;s/ //g;

                    if (/\s*=\s*/) {  #  We have a parameter

                        my ($var, $value) = split(/\s*=\s*/, $_, 2);

                        for ($var) {
                            s/\s+//g;
                            $_ = uc $_;
                        }
                        my $len = length $var; $len += 3;

                        $value = $uservalues{$var} if defined $uservalues{$var};

                        for ($value) {
                            s/\s+//g;  #  No white spaces - yet
                            s/,$//g;   #  No trailing comma
                            s/^,//g;   #  No leading comma
                            s/,/, /g;  #  Now add the space
                        }

                        print $ofh &TextFormat(0,$len,88,0,1,"$var = $value");
                    }

                } close $ofh; $nfiles++;
            }

        }  #  foreach my $econf


        #----------------------------------------------------------------------------------
        #  Let's copy over the README files for each section while we are at it.
        #----------------------------------------------------------------------------------
        #
        foreach my $eread (&FileMatch($emsconf,'\.README$',0,1)) {
            system "rsync -qa $eread  $domconf/  > /dev/null 2>&1";
        }


        if (@retirees) {
            &PrintMessage(0,10,255,1,2,"Configuration files no longer used ($domname/conf/$confdir/retired):");
            &PrintMessage(0,12,255,0,1,"RETIRED  : Configuration file   - $_") foreach @retirees;
            &PrintMessage(0,10,255,1,1,"Retired file configuration settings transfered to new files.") unless $retired;
        }
        $alph++;

        #  &PrintMessage(0,7,255,1,1,"The conf/$confdir configuration files are now ready for you") if $nfiles;

    }  #  foreach my $confdir


return;
}  #  End UpdateConfigurationFiles


sub RefreshNamelistPaths {
#----------------------------------------------------------------------------------
#  Make sure that the namelist.wps file contains the correct paths to the various
#  static datasets.  Unfortunately, this will not fix the problem where a bad
#  path exists in the namelist file when running DWIZ since the namelist information
#  was read into the domain wizard prior to running ems_domain.pl and will be written
#  out just before running geogrid, thus overwriting the information here.
#----------------------------------------------------------------------------------
#
use Cwd;

    my @uppflds   = ();
    my @auxflds   = ();

    my $dompath   = shift; $dompath = Cwd::realpath($dompath);
    my $domain    = &popit($dompath);
    my $stkpath   = "$dompath/static";

    my $wpsnl    = "$stkpath/namelist.wps";
    my $tbldir   = "$UEMSinstall{UEMSHOME}/data/tables/wps";
    my %masternl = &Namelist2Hash($wpsnl)  if -e $wpsnl;

    &PrintMessage(0,7,96,3,2,"e. Updating paths in $domain/static/namelist.wps");

    $masternl{SHARE}{opt_output_from_geogrid_path}[0] = "\'$stkpath\'";
    $masternl{GEOGRID}{geog_data_path}[0] = "\'$UEMSinstall{UEMSHOME}/data/geog\'";
    $masternl{GEOGRID}{opt_geogrid_tbl_path}[0] = "\'$stkpath\'";

    &Hash2Namelist($wpsnl,"$tbldir/namelist.wps",%masternl);


return;
}


sub UpdatePostProcessorFiles {
#  ===============================================================================
#  This routine makes sure the EMSUPP control files in the target domain directory
#  are up to date with the default UEMS files.  All relevant level settings will
#  be transfered to the refreshed files.
#  ===============================================================================
#
use Cwd;
use File::Compare;

    my $date    = `date +"%Y.%m.%d"`; chomp $date;
    my @uppflds = ();
    my @auxflds = ();

    my $model   = lc $UEMSinstall{CORE};

    my $dompath = shift; $dompath = Cwd::realpath($dompath);
    my $domain  = &popit($dompath);
    my $dstatic = "$dompath/static";

    my $task    = 'Refreshing';
    my $taskuc  = 'REFRESH';
    my $saved   = ' (configuration saved)';

    #----------------------------------------------------------------------------------
    #  Now make sure that the EMSUPP control files in the target domain directory
    #  are up to date with the default UEMS files. All relevant level settings will
    #  be transfered to the refreshed files.
    #----------------------------------------------------------------------------------
    #
    my $emsupp = "$UEMSinstall{UEMSHOME}/data/tables/post/grib2/emsupp_cntrl.MASTER";
    my $emsaux = "$UEMSinstall{UEMSHOME}/data/tables/post/grib2/emsupp_auxcntrl.MASTER";
    my $emsbuf = "$UEMSinstall{UEMSHOME}/data/tables/post/bufr/emsbufr_stations.MASTER";


    open (my $rfh, '<', $emsupp); while (<$rfh>) {chomp; s/\s+$//g; push @uppflds => $_;} close $rfh;
    open (   $rfh, '<', $emsaux); while (<$rfh>) {chomp; s/\s+$//g; push @auxflds => $_;} close $rfh;


    &PrintMessage(0,7,96,2,1,"d. EMSUPP control files under $domain/static${saved}:");

    #----------------------------------------------------------------------------------
    #  Collect all the potential EMSUPP control files from the static directory. 
    #  This method assumes that the filename contain the _cntrl or _auxcntrl string.
    #----------------------------------------------------------------------------------
    #
    foreach my $upost (&FileMatch($dstatic,'[_cntrl|_auxcntrl].parm$',0,1)) {

        my $ufile = &popit($upost);
        my $epost = ($ufile =~ /_cntrl/) ? $emsupp : $emsaux;

        unless (compare($upost,$epost)) {&PrintMessage(0,12,255,1,1,"ALL GOOD : EMSUPP Control file  - $ufile"); next;}
        &PrintMessage(0,12,255,1,2,"REFRESH  : EMSUPP Control file  - $ufile");

        #----------------------------------------------------------------------------------
        #  The user's control file differs from the UEMS default so time to update.
        #  Open each user control file and read the string containing the field ID
        #  and the level list of 0|1s.
        #----------------------------------------------------------------------------------
        #
        my %ufields=();
        my $ufield  ='';

        open (my $ifh, '<', $upost);

        while (<$ifh>) {
            chomp;
            next if /\s*#/;
            next unless /SCAL=|L=/ig;
            s/^\s+|\s+$//g;
            $ufield = $1 if /^\s*\(([A-Za-z0-9_-]{0,52})\)/;

            if ($ufield and /\s*L=\(([016 ]{95})\)/) {
                $ufields{$ufield} = $1;
                $ufield = '';
            }
        } close $ifh;

        #----------------------------------------------------------------------------------
        #  Save off the existing file should the user want to revert back
        #----------------------------------------------------------------------------------
        #
        &SysExecute("rsync -qa $upost ${upost}.$date > /dev/null 2>&1") unless -s ${upost}.$date;


        #----------------------------------------------------------------------------------
        #  Open the user's control file and begin writing the text/comments from the 
        #  default UEMS file, only stopping to inject the user's configuration
        #----------------------------------------------------------------------------------
        #
        my $replace = '';
        my @emsflds = ($ufile =~ /_cntrl/) ? @uppflds : @auxflds;

        open (my $ofh, '>', $upost);

        foreach (@emsflds) {
            $_ = " L=($ufields{$replace})" if $replace;
            $replace = (/^\s*\(([A-Za-z0-9_-]{0,52})\)/ and defined $ufields{$1}) ? $1 : '';
            &PrintMessage(0,14,255,0,1,"NEW FIELD ADDED ($ufile) : $1") if (/^\s*\(([A-Za-z0-9_-]{0,52})\)/ and ! $replace);
            print $ofh "$_\n";
        } close $ofh;


        #  Finally copy over the EMSUPP control files
        #
        &SysExecute("rsync -qa $emsupp $dstatic/emsupp_cntrl.parm > /dev/null 2>&1")        unless -s "$dstatic/emsupp_cntrl.parm";
        &SysExecute("rsync -qa $emsaux $dstatic/emsupp_auxcntrl.parm > /dev/null 2>&1")     unless -s "$dstatic/emsupp_auxcntrl.parm";
        &SysExecute("rsync -qa $emsbuf $dstatic/emsbufr_stations_d01.txt > /dev/null 2>&1") unless -s "$dstatic/emsbufr_stations_d01.txt";

    }


return;
}


sub ConfigureLocalSystemFiles {
#-------------------------------------------------------------------------------------
#  Configure the UEMS for the local system based upon the information gathered
#  from the user and machine interrogation. This step includes adding the processor
#  information and location of the UEMS to the environment variables as well as
#  the default settings in the configuration files.
#
#  The files to be updated are listed in the logs/ConfigurationFileList.txt file
#  included with every release and update. Files are listed relative to the top
#  of the UEMS installation.
#-------------------------------------------------------------------------------------
#
    #  Multiple file names are checked for backwards compatibility.
    # 
    my $clist = "$UEMSinstall{UEMSHOME}/logs/ConfigurationFileList.txt";
 
    return unless -s $clist;


    #  Set the total number of processors or NON Hyper-threaded cores on the machine.
    #  $sockets * $cores must equal $nprocs or something is wrong!
    #
    my $nprocs  = $UEMSinstall{ISYS}{total_cores};     $nprocs  = 1 unless $nprocs;
    my $sockets = $UEMSinstall{ISYS}{sockets};         $sockets = 1 unless $sockets;
    my $cores   = $UEMSinstall{ISYS}{cores_per_socket};$cores   = 1 unless $cores;

    if (${cores}*${sockets} != $nprocs) {$nprocs = int($sockets*$cores);}
       
    open (my $fh, '<', $clist); my @cfiles = <$fh>; close $fh; 

    foreach my $file (@cfiles) {

        chomp $file; $file =~ s/ //g; next unless $file;

        $file = "$UEMSinstall{UEMSHOME}/$file";

        next unless -f $file;

        open (my $ifh, '<', $file); my @cflines = <$ifh>; close $ifh;
        open (my $ofh, '>', $file);

        foreach (@cflines) {
            s/EMSDIR/$UEMSinstall{UEMSHOME}/g;
            s/NPROCS/$nprocs/g;
            s/NCORES/$cores/g;
            s/NSOCKETS/$sockets/g;
            print $ofh $_;
        }
        close $ofh;
    }
    &rm($clist);

return;
}  #  End ConfigureLocalSystemFiles


sub ConfigureUserGuidance {
#  ===============================================================================
#  If this is a fresh install then place the included .cshrc file in the users
#  home directory. If an update then assume all is well but check anyway
#  ===============================================================================
#

    #  The first task is to make sure the user has a home directory so that the appropriate
    #  shell command can be added to the login file.
    #
    my $code  = q{};
    my $wrpr  = q{};
    my $shell = $UEMSinstall{EUSER}{shell};
    my $home  = $UEMSinstall{EUSER}{home};
    my $login = $UEMSinstall{EUSER}{rcfile};
    my $urel  = &GetUEMSrelease($UEMSinstall{UEMSHOME});


    #  In a departure from previous UEMS installation routines, do not attempt to edit the user's
    #  shell login files. The logic becomes messy and the user must take some responsibility in 
    #  this process.
    #
    if ($shell =~ /bash/i) {
        $code  = "   #  Set the UEMS V$urel environment variables\n".
                 "   #\n".
                 "   if [ -f $UEMSinstall{UEMSHOME}/etc/EMS.profile ]; then\n".
                 "       . $UEMSinstall{UEMSHOME}/etc/EMS.profile\n".
                 "   fi\n\n";

        $wrpr = "$UEMSinstall{UEMSHOME}/strc/Ubin/uems_autorun-wrapper.sh";
    } else {
        $code  = "   #  Set the UEMS V$urel environment variables\n".
                 "   #\n".
                 "   if (-f $UEMSinstall{UEMSHOME}/etc/EMS.cshrc) then\n".
                 "       source $UEMSinstall{UEMSHOME}/etc/EMS.cshrc\n".
                 "   endif\n\n";

        $wrpr = "$UEMSinstall{UEMSHOME}/strc/Ubin/uems_autorun-wrapper.csh";
    }


    &PrintMessage(1,4,94,2,1,'Now for a special message from the UEMS Overlord:');

                 
    #  Write the "Honey-Do" list to the user
    #
    open (my $fh, '>', "$home/UEMS_Honey-DoList.txt");

    $mesg = "Here is your opportunity to get involved in the UEMS installation process, because up ".
            "until now you've had it rather easy. In order for you to use the UEMS, the environment ".
            "variables must be set; therefore, it is recommended that you place the following lines ".
            "in your $home/$login file:\n\n".
    
            "\n$code\n".

            "And while you are hacking up the file, make sure to comment out or delete references to any ".
            "previous UEMS, EMS, or WRF EMS installations, because you don't want any problems";

    &PrintMessage(0,9,94,1,1,'Greetings wonderful UEMS user,');
    &PrintMessage(0,11,94,1,2,$mesg);

    &PrintMessageFile($fh,0,2,94,2,1,'Greetings wonderful UEMS user,',$mesg);

    $mesg = "Additionally, if you are considering using the UEMS for real-time forecasting purposes (and who isn't!), ".
            "the package includes both bash and T|Cshell wrapper files to facilitate the process. The wrappers ".
            "are designed to set the environment variables prior to initiating the forecast and should be used ".
            "in lieu of running ems_autorun.pl directly via cron.\n\n".

            "A typical crontab entry might look something like the following:";

    &PrintMessage(0,11,94,1,1,$mesg);
    &PrintMessageFile($fh,0,2,94,1,1,$mesg);

    &PrintMessage(0,12,255,2,2,"01 23 * * * $wrpr >& $UEMSinstall{UEMSHOME}/logs/ems_autorun.log 2>&1");
    &PrintMessageFile($fh,0,5,255,2,2,"01 23 * * * $wrpr >& $UEMSinstall{UEMSHOME}/logs/ems_autorun.log 2>&1");


    $mesg = "Finally, just because I like you, this information and more has been written to a \"UEMS_Honey-DoList.txt\" ".
            "file in your home directory.";

    &PrintMessage(0,11,94,1,2,$mesg);

    &PrintMessage(0,9,92,1,0,'I will get to it right away! [enter]');
    my $ans = <>;
    &PrintMessage(0,9,92,0,1,' ');


return;
}  #  End ConfigureUserGuidance


sub CleanupLocalSystemFiles {
#-------------------------------------------------------------------------------
#  Do a final cleanup of the UEMS following the update. This routine is used to
#  scour extraneous files that are no longer used by the UEMS but may still be
#  hanging around looking for glory.
#
#  The files to be scoured are listed in the logs/FileDeleteList.txt file
#  sometimes included with an update. Files are listed relative to the top
#  of the UEMS installation.
#-------------------------------------------------------------------------------
#
    &PrintMessage(0,7,92,2,1,'Tidying up the your UEMS release');

    #  Multiple file names are checked for backwards compatibility.
    #
    my $clist = -f "$UEMSinstall{UEMSHOME}/logs/FileDeleteList.txt" ? "$UEMSinstall{UEMSHOME}/logs/FileDeleteList.txt" : '';

    return unless $clist;

    open (my $fh, '<', $clist); my @cfiles = <$fh>; close $fh;

    foreach my $file (@cfiles) {
        chomp $file; $file =~ s/ //g; next unless $file;
        $file = "$UEMSinstall{UEMSHOME}/$file";
        next unless -f $file;
        &rm($file);
    }

return;
}


sub CollectCpuInfo {
#----------------------------------------------------------------------------------
#  This routine attempts to gather information about the CPUs on the system,
#  through use of the "lscpu" command and interrogating the /proc/cpuinfo file.
#  Ideally, just the lscpu commend would be used because it tends to provide more
#  accurate information on whether hyper-threading is turned ON but neither
#  method is perfect.
#----------------------------------------------------------------------------------
#
    my %info = ();
       %info = &CollectCpuInfo1(\%info);
       %info = &CollectCpuInfo2(\%info);

    #  User messages of love and encouragement.
    #
    my %mesgs=();

       $mesgs{intht} = "Special note on hyper-threading:\n\nAttempting to use virtual \"Hyper-threaded\" CPUs while running ".
                       "the UEMS may result in a degradation in performance.\n\n";

       $info{message}= $info{ht} ? $mesgs{intht} : '';


return %info;
}


sub CollectCpuInfo1 {
#----------------------------------------------------------------------------------
#  This routine attempts reads the /proc/cpuinfo file and return valuable
#  CPU related information.
#----------------------------------------------------------------------------------
#
    my $href = shift;
    my %info = %{$href};


    #  The list of temporary variables used
    #
    my ($modelname, $processor, $cpucores, $siblings, $bogomips) = (0, 0, 0, 0, 0);
    my %phyid   = ();
    my %coreid  = ();
    my @coreids = ();

    if ( -e '/proc/cpuinfo' ) {
       open (my $fh, '<', '/proc/cpuinfo'); my @lines = <$fh>; close $fh; foreach (@lines) {chomp; s/^\s*/    /g; s/\s+$//g;}
       foreach (@lines) {
           chomp;
           if  ( s/^\s*(model name)\s*://i )  {s/ +/ /g;($modelname = $_) =~ s/^ //g;}
           if  ( s/^\s*(physical id)\s*://i ) {$_+=0;$phyid{$_} = (defined $phyid{$_}) ? $phyid{$_}++ : 0;}
           if  ( s/^\s*(processor)\s*://i )   {$processor++}
           if  ( s/^\s*(cpu cores)\s*://i )   {$cpucores = $_+=0 if $_;}
           if  ( s/^\s*(siblings)\s*://i )    {$siblings = $_+=0 if $_;}
           if  ( s/^\s*(core id)\s*://i )     {$_+=0;push @coreids => $_;}
           if  ( s/^\s*(bogomips)\s*://i )    {$bogomips = $_+=0 if $_;}

       }
    } my $amd = ($modelname =~ /amd/i) ? 1 : 0;


    $processor = 1 unless $processor;
    $cpucores+=0; $cpucores = 1 unless $cpucores;
    $siblings+=0; $siblings = 1 unless $siblings;
    $bogomips+=0; $bogomips = 0 unless $bogomips;

    my $sockets   = keys %phyid;  $sockets = 1 unless $sockets; #  The number of sockets on the system
    my $thrdscore = int ($siblings/$cpucores);


    #  The number of "cpu cores" should be the same as the number of unique core IDs.
    #  Note that @coreids is not currently used.
    #
    #  @coreids = sort {$a <=> $b} @coreids;
    #  do {grep { !$coreid{$_}++ } @coreids };
    #  my $ncoreids = keys %coreid;
    #
    $info{model_name}       = $modelname if $modelname;
    $info{sockets}          = $sockets;
    $info{cores_per_socket} = $cpucores;
    $info{total_cores}      = $cpucores*$sockets;
    $info{threads_per_core} = $thrdscore;
    $info{siblings}         = $siblings;
    $info{cpu_speed}        = sprintf('%.3f',0.001*int($bogomips*0.5));
    $info{ht}               = (! $amd and $thrdscore > 1) ? 1 : 0;
    $info{amd}              = $amd;

    #  Used to be /bin/uname -p' but "-p" is not valid for Debian users
    #
    $info{cputype}          = `/bin/uname -m`; chomp $info{cputype};


return %info;
}


sub CollectCpuInfo2 {
#----------------------------------------------------------------------------------
#  This routine attempts to mine the output from the lscpu command for valuable
#  CPU related information, and then returns it.
#----------------------------------------------------------------------------------
#
    my $href = shift;
    my %info = %{$href};


    #  The list of temporary variables used
    #
    my ($modelname, $sockets, $totlcores, $cpucores, $thrdscore, $bogomips, $cpuarch) = (0, 0, 0, 0, 0, 0, 0);
    my %phyid   = ();
    my %coreid  = ();
    my @coreids = ();

    foreach (`lscpu`) {
        chomp; s/[\)|\(]//g; s/:\s*/:/g;
        if  ( s/^\s*(vendor id)\s*://i )  {s/ +/ /g;($modelname = $_) =~ s/^ //;}
        if  ( s/^\s*(architecture)\s*://i ){s/ +/ /g;($cpuarch = $_) =~ s/^ //g;}
        if  ( s/^\s*(threads per core)\s*://i){$thrdscore = $_+=0 if $_;}
        if  ( s/^\s*(cores per socket)\s*://i){$cpucores = $_+=0 if $_;}
        if  ( s/^\s*(sockets)\s*://i )     {$sockets = $_+=0 if $_;}
        if  ( s/^\s*(core id)\s*://i )     {$_+=0;push @coreids => $_;}
        if  ( s/^\s*(bogomips)\s*://i )    {$bogomips = $_+=0 if $_;}
        if  ( s/^\s*(cpus)\s*://i )        {$totlcores= $_+=0 if $_;}
    } my $amd = ($modelname =~ /amd/i) ? 1 : 0;


    $cpucores+=0; $cpucores = 1 unless $cpucores;
    $bogomips+=0; $bogomips = 0 unless $bogomips;

    #  Used to be 'uname -p' but the "-p" is not valid under Debian
    #
    unless ($cpuarch) {$cpuarch = `/bin/uname -m`; chomp $cpuarch;}

    $info{model_name}       = $modelname unless $info{model_name};
    $info{cputype}          = $cpuarch ? $cpuarch : 'Unknown';
    $info{sockets}          = $sockets;
    $info{cores_per_socket} = $cpucores;
    $info{total_cores}      = $cpucores*$sockets;
    $info{threads_per_core} = $thrdscore;
    $info{cpu_speed}        = sprintf('%.3f',0.001*int($bogomips*0.5));
    $info{ht}               = (! $amd and $thrdscore > 1) ? 1 : 0;
    $info{amd}              = $amd;


return %info;
}


sub CollectHostInfo {
#----------------------------------------------------------------------------------
#  This routine gathers information about the system hostname(s) and IP address(es)
#  It returns a hash containing stuff.
#----------------------------------------------------------------------------------
#
use Sys::Hostname;
use Net::hostent;
use Socket;

    my %info = ();

    #  Get hostname and IP information
    #
    my $host0 = hostname;

    #  We need to test whether the system is resolvable on the network
    #
    my $host1 = '';
    my $addr0 = 'None available';
    my $addr1 = 'None available';

    my $h = gethost($host0);
    if ($h) {  #  Is resolved
       $host1 = $h->name;
       $addr0 = inet_ntoa($h->addr);
       unless (system "host $host1 > /dev/null 2>&1") {
           my @hi = split / +/ => `host $host1`; $addr1 = $hi[-1];
       }
    }

    $info{hostname0} = $host0;
    $info{hostname1} = $host1 ne $host0 ? $host1 : 'None';

    $info{nhost}     = $host1;
    $info{address0}  = $addr0;
    $info{address1}  = $addr1;

    foreach my $key (keys %info) {chomp $info{$key};}

    $info{hosts_file} = q{};
    if ($addr0 ne $addr1) {  # Read the /etc/hosts file for additional information
        open (my $fh, '<', '/etc/hosts'); my @hosts = <$fh>; close $fh; foreach (@hosts) {chomp; s/^\s*/    /g; s/\s+$//g;}
        $info{hosts_file} = join "\n" => @hosts;
    }


return %info;
}


sub CollectLinuxInfo {
#----------------------------------------------------------------------------------
#  This routine attempts to mine information on the Linux distribution running
#  the system. It's a simple approach but should work for most systems. It returns
#  a hash containing the Linux distribution name, architecture, and more stuff.
#  Note that the Perl "Config" hash/module could also be used in place of some
#  system calls but it assumes the module is installed on the user's system.
#----------------------------------------------------------------------------------
#
    my %info = ();

    #  Try to determine the distribution name and version
    #
    my $distro = q{};

    if (-e '/usr/bin/lsb_release') {  #  Not always available
        $distro = `/usr/bin/lsb_release -ds`;
    } else {
        if (open (my $ifh, '<', '/etc/os-release') ) {
            while (<$ifh>) { chomp; $distro = $1 if /PRETTY_NAME=(.+)/;} close $ifh;
        } else {
            foreach my $rel (&FileMatch('/etc','-release$',0,1)) {$distro=`cat $rel`; chomp $distro;}
        }
    }
    $info{distro} = $distro ? $distro : 'Unknown';  $info{distro} =~ s/\"//g;

    #  Get OS information
    #
    $info{os}      = (`/bin/uname` =~ /linux/i) ? 'Linux' : 'Non Linux';
    $info{kernel}  = `/bin/uname -r`; my @list = split /\./ => $info{kernel};
    $info{cputype} = `/bin/uname -m`;  
    $info{hwtype}  = $info{cputype};
    $info{ostype}  = $list[-1];


    foreach my $key (keys %info) {chomp $info{$key};}


return %info;
}


sub CollectMemoryInfo {
#----------------------------------------------------------------------------------
#  This routine attempts to gather information about the amount of physical memory
#  installed on the system by interrogating the /proc/meminfo file.
#----------------------------------------------------------------------------------
#
use POSIX 'floor';

    my %info = ();
       $info{available_memory} = 'Unknown';

    if ( -e '/proc/meminfo' ) {
        open (my $fh, '<', '/proc/meminfo'); my @lines = <$fh>; close $fh; foreach (@lines) {chomp; s/^\s*/    /g; s/\s+$//g;}
        foreach (@lines) {chomp; if  (s/^\s*(MemTotal)\s*://i)  {($info{available_memory} = $_) =~ s/[a-z]+//i;}}
        $info{available_memory} = sprintf('%.2f',0.010*floor($info{available_memory}/10240));
    }


return %info;
}


sub CollectSystemInfo {
#----------------------------------------------------------------------------------
#  This routine attempts to gather information about a system for configuration
#  and informational purposes.  It calls the appropriately named routines to
#  collect the desired information before packaging it up into a string suitable
#  for framing, printing, or returning.
#----------------------------------------------------------------------------------
#

    my %sysinfo=();  #  Hash used in collect all the information
    my %hash   =();

    %hash = &CollectHostInfo();   foreach my $key (keys %hash) {$sysinfo{$key} = $hash{$key};}
    %hash = &CollectLinuxInfo();  foreach my $key (keys %hash) {$sysinfo{$key} = $hash{$key};}
    %hash = &CollectCpuInfo();    foreach my $key (keys %hash) {$sysinfo{$key} = $hash{$key};}
    %hash = &CollectMemoryInfo(); foreach my $key (keys %hash) {$sysinfo{$key} = $hash{$key};}

return %sysinfo;
}


sub CollectUemsInfo {
#  ==================================================================================
#  This routine collects information about the current UEMS installation
#  ==================================================================================
#
    my %uems = ();
       $uems{emsenv} = 0;  #  Contains the $EMS environment variable if set
       $uems{cuems}  = 0;  #  Current UEMS installation, if any
       $uems{emsver} = 0;
       $uems{wrfver} = 0;
       $uems{rundir} = 0;

    $uems{emsenv} = shift || return %uems;

    $uems{cuems}  = $uems{emsenv}; return %uems unless -e $uems{cuems};

    $uems{emsver} = &GetUEMSrelease($uems{cuems});
    $uems{wrfver} = &GetWRFrelease($uems{cuems});
    $uems{rundir} = -e "$uems{cuems}/runs" ? Cwd::realpath("$uems{cuems}/runs") : 0;

    #  ----------------------------------------------------------------------------------
    #  Determine whether one of the optional packages or data sets exist. Used
    #  for updates.
    #  ----------------------------------------------------------------------------------
    #
    $uems{nawips}    = -e "$uems{cuems}/util/nawips"              ?  Cwd::realpath("$uems{cuems}/util/nawips")              : 0;  #  NAWIPS flag update
    $uems{source}    = -e "$uems{cuems}/util/UEMSbuild"           ?  Cwd::realpath("$uems{cuems}/util/UEMSbuild")           : 0;  #  Source code update
    $uems{workshop}  = -e "$uems{cuems}/util/workshop"            ?  Cwd::realpath("$uems{cuems}/util/workshop")            : 0;  #  Workshop update
    $uems{gtopo}     = -e "$uems{cuems}/data/geog/topo_30s"       ?  Cwd::realpath("$uems{cuems}/data/geog/topo_30s")       : 0;  #  Deprecated USGS elevation data
    $uems{nlcd2006}  = -e "$uems{cuems}/data/geog/nlcd2006_ll_9s" ?  Cwd::realpath("$uems{cuems}/data/geog/nlcd2006_ll_9s") : 0;  #  High Resolution 2006 NLCD
    $uems{nlcd2011}  = -e "$uems{cuems}/data/geog/nlcd2011_ll_9s" ?  Cwd::realpath("$uems{cuems}/data/geog/nlcd2011_ll_9s") : 0;  #  High Resolution 2011 NLCD

 
return %uems;
}


sub CollectUserInfo {
#----------------------------------------------------------------------------------
#  This routine collects information about the user such as the home directory,
#  shell being used, number and group.
#----------------------------------------------------------------------------------
#
    my %info  = ();

    my $user  = shift;

    my @uinfo = ($user =~ /^[\d]+$/) ? getpwuid $user : getpwnam $user;

    $info{uname} = $uinfo[0];
    $info{uid}   = $uinfo[2];
    $info{gid}   = $uinfo[3];
    $info{rname} = $uinfo[6] ? $uinfo[6] : q{};
    $info{home}  = ($uinfo[7] and -d $uinfo[7]) ? $uinfo[7] : 0;
    $info{shell} = $uinfo[8];
    $info{rcfile}= ($info{shell} =~ /bash/i) ? '.bash_profile' : '.cshrc';

    @uinfo = getgrgid $info{gid};

    $info{gname} = $uinfo[0];  #  Get group name

return %info;
}


sub GetDesire {
#----------------------------------------------------------------------------------
#  Just a list of desirable stuff, although the UEMS developer should also
#  be on this list. Such an oversight!
#----------------------------------------------------------------------------------
#
use List::Util qw(shuffle);

    my @desires;

    @desires = ('some flowers', 'some jewelry', 'some love', 'a new Porsche', 'some new shoes', 'a massage', 'a vacation', 'some cashmere',
                'a personal chef', 'to lose 5kg', 'to lose another 5kg', 'a Ferrari', 'a vacation home', 'a man-servant');

return $desires[int rand scalar @desires];
}


sub GetFunCharacter {
#----------------------------------------------------------------------------------
#  This routine returns an unusual unicode character randomly selected from a non-
#  random list.
#----------------------------------------------------------------------------------
#
use List::Util qw(shuffle);

    my @unichars = ("\xe2\x98\x80","\xe2\x98\x81","\xe2\x98\x82","\xe2\x98\x83","\xe2\x98\x84","\xe2\x98\x85","\xe2\x98\x86","\xe2\x98\x87",
                    "\xe2\x98\x88","\xe2\x98\x89","\xe2\x98\x94","\xe2\x98\x95","\xe2\x98\x98","\xe2\x98\xa0","\xe2\x98\xa2","\xe2\x98\xa3",
                    "\xe2\x98\xae","\xe2\x98\xba","\xe2\x98\xbb","\xe2\x98\xbc","\xe2\x98\xbd","\xe2\x98\xbe","\xe2\x99\xa5","\xe2\x99\xa8",
                    "\xe2\x99\xb9","\xe2\x99\xba","\xe2\x99\xbb","\xe2\x99\xbc","\xe2\x9a\x98","\xe2\x9a\x9b");

       @unichars = shuffle @unichars;

return $unichars[int rand scalar @unichars]
}


sub GetInspirationMessage {
#----------------------------------------------------------------------------------
#  An inspirational message when needed, and one is always needed!
#----------------------------------------------------------------------------------
#
use List::Util qw(shuffle);

    my @inspired;

    @inspired = ("\"What we got here is failure to communicate\" - Cool Hand Luke",
                 "\"If something’s hard to do, then it’s not worth doing.\" - Homer Simpson".
                 "\"You just pick up a chord, go twang, and you've got music\" - Sid Vicious",
                 "\"A man who carries a cat by the tail learns something he can learn in no other way\" - Mark Twain",
                 "\"A person who won't read has no advantage over one who can't read\" - Mark Twain",
                 "\"A person with a new idea is a crank until the idea succeeds\" - Mark Twain",
                 "\"Action speaks louder than words but not nearly as often\" - Mark Twain",
                 "\"All generalizations are false, including this one\" - Mark Twain",
                 "\"All right, then, I'll go to hell.\" - Mark Twain",
                 "\"All you need is ignorance and confidence and the success is sure\" - Mark Twain",
                 "\"Buy land, they're not making it anymore\" - Mark Twain",
                 "\"Climate is what we expect, weather is what we get.\" - Mark Twain",
                 "\"Clothes make the man. Naked people have little or no influence on society.\" - Mark Twain",
                 "\"Do the right thing. It will gratify some people and astonish the rest.\" - Mark Twain",
                 "\"Don't tell fish stories where the people know you; but particularly, don't tell them where they know the fish.\" - Mark Twain",
                 "\"Facts are stubborn, but statistics are more pliable.\" - Mark Twain",
                 "\"Get your facts first, then you can distort them as you please.\" - Mark Twain",
                 "\"Go to Heaven for the climate, Hell for the company.\" - Mark Twain",
                 "\"Honesty is the best policy - when there is money in it.\" - Mark Twain",
                 "\"We have the best government that money can buy.\" - Mark Twain",
                 "\"What would men be without women? Scarce, sir, mighty scarce.\" - Mark Twain",
                 "\"When you fish for love, bait with your heart, not your brain.\" - Mark Twain",
                 "\"Think Globally, Model Locally\" - EMS",
                 "\"Nobody likes to come in second place, except the person in third.\" - EMS",
                 "\"The trouble ain't that there is too many fools, but that the lightning ain't distributed right.\" - Mark Twain",
                 "\"The very ink with which history is written is merely fluid prejudice.\" - Mark Twain",
                 "\"Thunder is good, thunder is impressive; but it is lightning that does the work.\" - Mark Twain",
                 "\"The fear of death follows from the fear of life. A man who lives fully is prepared to die at any time.\" - Mark Twain",
                 "\"The main difference between a cat and a lie is that a cat only has nine lives.\" - Mark Twain",
                 "\"The more things are forbidden, the more popular they become.\" - Mark Twain",
                 "\"The reports of my death have been greatly exaggerated.\" - Mark Twain",
                 "\"Reader, suppose you were an idiot. And suppose you were a member of Congress. But I repeat myself.\" - Mark Twain",
                 "\"Sometimes too much to drink is barely enough.\" - Mark Twain",
                 "\"The best way to cheer yourself up is to try to cheer somebody else up.\" - Mark Twain",
                 "\"If you tell the truth, you don't have to remember anything.\" - Mark Twain",
                 "\"It is better to deserve honors and not have them than to have them and not deserve them.\" - Mark Twain",
                 "\"It is better to keep your mouth closed and let people think you are a fool than to open it and remove all doubt.\" - Mark Twain",
                 "\"It's not the size of the dog in the fight, it's the size of the fight in the dog.\" - Mark Twain",
                 "\"I didn't attend the funeral, but I sent a nice letter saying I approved of it.\" - Mark Twain",
                 "\"I have never let my schooling interfere with my education.\" - Mark Twain",
                 "\"Habit is habit and not to be flung out of the window by any man, but coaxed downstairs a step at a time.\" - Mark Twain"); @inspired = shuffle @inspired;


return $inspired[int rand scalar @inspired];
}


sub GetSystemInfoString {
#----------------------------------------------------------------------------------
#  This routine takes the hash output by the &CollectSystemInfo routine and
#  created a formatted string for printing.
#----------------------------------------------------------------------------------
#
    my $hashref = shift;
    my %syshash = %{$hashref};

    my $infostr = "System Information for $syshash{hostname0}:\n\n".
                 "    Alternate Hostname  : $syshash{hostname1}\n".
                 "    Machine Address     : $syshash{address0} \n".
                 "    Alternate Address   : $syshash{address1} \n\n".

                 "    Linux Kernel        : $syshash{kernel}   \n".
                 "    Linux Distribution  : $syshash{distro}   \n\n".

                 "    CPU Name            : $syshash{model_name}\n".
                 "    CPU Type            : $syshash{cputype}\n".
                 "    Sockets             : $syshash{sockets}\n".
                 "    Cores per Socket    : $syshash{cores_per_socket}\n".
                 "    Total Physical CPUs : $syshash{total_cores}\n".
                 "    CPU Speed           : $syshash{cpu_speed} MHz\n".
                 "    Available Memory    : $syshash{available_memory} GB\n";

    #if ($syshash{hosts_file}) {$infostr = "$infostr"."\n"."Contents of the /etc/hosts file:\n\n"."$syshash{hosts_file}";}


return $infostr;
}


sub ArrayDifference {
#==================================================================================
#  Returns the difference between 2 arrays
#==================================================================================
#
    my %count = ();
    my @diffa = ();
    my @array = @_;

    foreach (@array) {$count{$_}++;}
    foreach (keys %count) {push @diffa => $_ if $count{$_} == 1;}

return (sort @diffa);
} #  ArrayDifference


sub Bytes2MB {
#==================================================================================
#  Convert number of Bytes (input) to MegaBytes (Returned).
#==================================================================================
#
    my $bytes = shift; return 0 unless defined $bytes and $bytes;

return $bytes*0.000000953674316;
} #  Bytes2MB


sub Bytes2KB {
#==================================================================================
#  Convert number of Bytes (input) to KiloBytes (Returned).
#==================================================================================
#
    my $bytes = shift; return 0 unless defined $bytes and $bytes;

return $bytes*0.0009765625;
} #  Bytes2KB


sub CompareReleaseNumbers {
#----------------------------------------------------------------------------------
#  Compares two release versions ($a and $b) and returns:
#
#    -1 :  if $a is earlier than $b
#     0 :  if $a is same as $b
#     1 :  if $a is later than $b
#----------------------------------------------------------------------------------
#
    my ($a, $b) = @_;

    return 0 unless $a and $b;  # just move along

    $a =~ s/ //g;
    $b =~ s/ //g;

    return 0 if $a eq $b;

return (&FormatReleaseNumber($a) < &FormatReleaseNumber($b)) ? -1 : 1;
}


sub FileAvailableHTTP {
#----------------------------------------------------------------------------------
#  This routine checks the availability of a file given the method of acquisition
#  the host and filename including path. It returns the size of the file if
#  successful or 0 upon failure.
#----------------------------------------------------------------------------------
#
    my $dbg = 1;

    if (&mkdir("$UEMSinstall{UEMSHOME}/logs")) {
       &PrintMessage(6,4,96,0,0," FileAvailableHTTP: Failed to create $UEMSinstall{UEMSHOME}/logs ");
       return 1;
    }
    my $log = "$UEMSinstall{UEMSHOME}/logs/http_available.log"; &rm($log);

    my @size=();
    my ($meth, $hfile) = @_;


    #  Specify the options and flags being passed to curl|wget
    #
    my $tv = 20;  # Set timeout value to 20s

    #  Flags for wget:
    #    --dns-timeout     : number of seconds to wait for DNS hostname resolution
    #    --connect-timeout : number of seconds to wait to connect
    #    -t                : number of attempts
    #    --spider          : Spider mode - just check if file exists
    #
    my $wopts = "--dns-timeout=$tv --connect-timeout=$tv -t 1 --spider";


    #  Flags for curl:
    #    --connect-timeout   : number of seconds to wait for a connection
    #    -s                  : Silent mode - no status bar
    #    -I                  : Curl's "spider mode"
    #
    my $copts = "--connect-timeout $tv -sI";

    my $opts  = ($meth =~ /curl/) ? $copts : $wopts;

    system "$UEMSinstall{OPTION}{method} -o $log $opts $hfile";

    if (-s $log) {open(my $fh, '<', $log); while(<$fh>) {@size = split ' ', $_ if s/Content-Length:|Length:|Longueur:|Lunghezza://i;} close $fh;}
    $_ =~ tr/,|\.//d foreach @size;

    if (@size) {&rm($log); $size[0]+=0;}

    unless (@size) {
        if (-s $log and $dbg) {
            &PrintMessage(6,4,96,1,0,"DBG: Contents of $log");
            system "cat $log";
        }
    }
    

return @size ? $size[0] : 0;

}  #  End FileAvailableHTTP


sub FileMatch {
#==================================================================================
#  This routine returns a list of files in a directory that match the specified
#  string. The arguments are:
#
#      $dir    -  The directory path to search
#      $string -  The string to match - "0" indicates get all files
#      $nodir  -  Whether to include (0) or not include (1) the full path in returned values
#      $nocheck-  0 (check) or 1 (don't check) the file size - Yes, the double neg is confusing
#
#  Turning "nocheck" ON (1) excludes directories from being returned (just files).
#==================================================================================
#   
    my @ffiles = ();
    my @files  = ();

    my ($dir, $string, $nodir, $nocheckz) = @_;  

    $nocheckz = 0 unless defined $nocheckz and $nocheckz; 

    return @files unless -d $dir;

    system "ls $dir > /dev/null 2>&1";  #  Workaround for NFS issues

    opendir DIR => $dir; @files = $string ? sort grep /$string/ => readdir DIR : sort grep !/^\./ => readdir DIR; close DIR;

    return @files unless @files; # return list if empty

    @files = &rmdups(@files);

    foreach (@files) {  
        next if /^\./;
        if ($nocheckz) {
            push @ffiles => $_ if -f "$dir/$_";
        } else {
            push @ffiles => $_ if -e "$dir/$_" and ! -z "$dir/$_";
        }
    }
    @files = sort @ffiles;

    unless ($nodir) {$_ = "$dir/$_" foreach @files;}

return @files;
}  #  FileMatch


sub FindDomainDirectories {
#----------------------------------------------------------------------------------
#  This routine takes a path to a directory and then searches below that point
#  for for viable UEMS computational domains.  This routine returns ALL domains
#  found, so its probably best to limit the scope of the search.
#----------------------------------------------------------------------------------
#  
    my @domains = ();

    my $startd  = shift; chomp $startd; $startd =~ s/\s+//g; return @domains unless $startd;

    my @statics = `find $startd -name static -type d -readable`;

    foreach (@statics) { 
        chomp;
        $_ = Cwd::realpath($_);
        next if -e "$_/.benchmark";       #  Don't want benchmark directories
        s/\/static//g;                    #  Remove /static from the path
        next unless -d "$_/conf/ems_run"; #  Check is the conf directory exists
        push @domains => $_;
    } 


return @domains;
}
   

sub FormatReleaseNumber {
#----------------------------------------------------------------------------------
#    Reformat the release number for easier sorting and comparisons
#----------------------------------------------------------------------------------
#
    my $rv = shift;
    my @rv = split /\./ => $rv;
    my @nv = ();
    foreach (@rv) {
        next if /\D/;  $_+=0;
        push @nv => sprintf("%02d",$_);
    }
    my $ver = join q{} => @nv; $ver =~ s/ //g;

return $ver
}


sub GetAvailableServer {
#----------------------------------------------------------------------------------
#   This routine simply tests whether a connection can be made to the remote UEMS
#   servers.  If successful, a value of -1 is returned; otherwise, it dies,
#   which is not good for you.
#----------------------------------------------------------------------------------
#
use List::Util qw(shuffle);
use Net::hostent;


    #   Info:  The list of available UEMS servers was defined during initialization and
    #          located in the @{$UEMSinstall{SERVERS}} array. This list was used to set
    #          the %{$UEMSinstall{EMSHOSTS}} hash in Options_emshosts routine.
    #          If the user did not pass the --emshost or --local flag, then this hash
    #          should contain the both the FQHN and short same of each UEMS server.
    #
    #   Note:  If --local was passed then $UEMSinstall{EMSHOSTS}{$shost} will
    #          be set to 0 rather than the FQHN.
    #
    my @servers = shuffle keys %{$UEMSinstall{EMSHOSTS}};
    my $shost   = $servers[int rand scalar @servers];


    #  $emshost will hopefully contain the selected server after this routine is done.
    #
    my $emshost = 0;


    if ($UEMSinstall{EMSHOSTS}{$shost}) { #  look for a known remote server and not a local system request

        foreach my $host (@servers) {

            next if $emshost; #  We've established a connection

            &PrintMessage(1,4,96,1,0,"Checking http connection to $UEMSinstall{EMSHOSTS}{$host}");

            $emshost = gethost($UEMSinstall{EMSHOSTS}{$host}) ? $host : 0;
            $emshost ? &PrintMessage(0,2,26,0,1," - It's Alive!")
                     : &PrintMessage(0,2,26,0,1," - What we got here is failure to communicate!");

        }

        my $list = join  ', ' => @servers;
        $mesg = "This is not good - For You!\n\n".
                "I was unable to contact any of the remote servers on my list ($list), which is probably ".
                "due to a local network issue or you do not have a connection to the outside world.\n\nAnyway, ".
                "some magic must happen for us to work together, so go make some magic!";

        &SysDied($mesg) unless $emshost;
    }


return $emshost;
}


sub GetDidYouKnow {
#----------------------------------------------------------------------------------
#  Initialize the "Did You Know" statements
#----------------------------------------------------------------------------------
#
        my @messages=();

        $mesg = "The STRC UEMS is an end-to-end forecasting system, from ingesting the data used for ".
                "model initialization to post-processing and exporting the forecasts the their final destination.";

        push @messages => $mesg;
        $mesg    = "There are a variety of tools available to UEMS users, including:\n\n".

                   "  ems_clean   - Restores run-time directories to a user-specified\n".
                   "                state. Run \"% ems_clean --help\" for more information.\n\n".

                   "  ems_domain  - allows users to create new domains without the domain wizard\n".
                   "                or re-localize existing domains efficiently.\n\n".

                   "  gribnav     - Reads the GDS block of GRIB 1 or 2 files and prints out\n".
                   "                the navigation information including corner and center\n".
                   "                points, pole point, grid dimensions and spacing.\n\n".

                   "  netcheck    - A tool for finding potential networking problems when \n".
                   "                executing the UEMS on a cluster of Linux systems.\n\n".

                   "  sysinfo     - Provides information about your system including the number\n".
                   "                of CPUs, CPU speed, amount of physical memory, and a whole\n".
                   "                lot more stuff that you never cared to know about.\n\n".

                   "  runinfo     - Provides details of the run configuration for a selected\n".
                   "                model domain. Simply run \"runinfo\" in a domain directory\n".
                   "                and allow your state of semi-consciousness to be stimulated by\n".
                   "                the smorgasbord of valuable information.\n\n".

                   "  grib2cdf   -  Creates standard netCDF and companion cdl files from GRIB \n".
                   "                version 1 and 2 files - Enjoy!";

        push @messages => $mesg;

        $mesg = "That the UEMS includes a modified version of the Domain Wizard ".
                "developed by Earth System Research Laboratory (ESRL)? This tool ".
                "greatly simplifies the task of setting up the computational domain ".
                "for your simulations.\n\n".

                "Simply run from the command line:\n\n".

                "  % dwiz";

        push @messages => $mesg;

        $mesg = "That the UEMS provides benchmark simulations for both the NMM and ARW cores? This ".
                "utility will allow you to compare the performance of each model on your workstation ".
                "to that on other platforms. In addition running a benchmark will verify that the UEMS ".
                "is working on your system.\n\n".

                "To run a benchmark case after the install:\n\n".
                "  1. cd $UEMSinstall{UEMSTOP}/util/benchmark \n".
                "  2. Read the benchmark.README file\n".
                "  3. cd to either core directory (arw or nmm)\n".
                "  4. Run the benchmark case as per the guidance";



        push @messages => $mesg;


        $mesg = "Someday the brand new \"Universal EMS\" will be unleashed to the universe. The UEMS ".
                "will combine the best of the WRF with the MPAS system, along with a bunch of other goodies ".
                "of which I have to conceive.";

        push @messages => $mesg;

        $mesg = "The UEMS includes the much talked about (just by me) option to the $UEMSinstall{EXE} routine ".
                "that allows you to automatically (via cron) download and install patches and updates while ".
                "you sleep.";

        push @messages => $mesg;

        $mesg = "The UEMS includes a variety of utility routines that may be used to enhance your ".
                "modeling experience. I know you are saying \"How is this possible!?\", but it's true.\n\n".

                "Here is a summary of the file in the $UEMSinstall{UEMSTOP}/util/bin directory:\n\n".

                    "  cnvgrib - Utility to convert between GRIB Version 1 and 2 (GRIB 1 <-> GRIB 2)\n".
                    "  copygb  - Utility to interpolate to a different grid projection/navigation (GRIB 1 only)\n".
                    "  g1print - Utility to dump information from GRIB 1 files for the creation of Vtables\n".
                    "  g2print - Utility to dump information from GRIB 2 files for the creation of Vtables\n".
                    "  ncdump  - Utility to dump out information from netCDF formatted files\n".
                    "  ncview  - Display tool for the the contents of netCDF files - Fun for all ages\n".
                    "  rdwrfin - Utility to dump out information from WRF intermediate formatted files\n".
                    "  rdwrfnc - Utility to dump out information from WRF netCDF formatted files\n".
                    "  wgrib   - Utility to interrogate GRIB 1 formatted files\n".
                    "  wgrib2  - Utility to interrogate and manipulate GRIB 2 formatted files\n".

        push @messages => $mesg;

return @messages;
}


sub GetDomainList {
#----------------------------------------------------------------------------------
#  This routine returns an array containing a list of directory paths to individual
#  computational domains. The input to this routine is an array containing one or
#  more directories below which the &FindDomainDirectories subroutine will search
#  for domains.
#----------------------------------------------------------------------------------
#
use Cwd;

    my @domains = ();

    my @dompaths = @_; return @domains unless @dompaths;


    #  Loop through each starting directory to search looking for domains.
    #
    foreach (@dompaths) {
        
        chomp; s/\s+//g;
        next unless $_;
        $_  = Cwd::realpath($_);
        next unless -d;

        my @found = &FindDomainDirectories($_);
        @domains  = (@domains,@found) if @found;

     }
     @domains  = &rmdups(@domains);  #  Eliminate duplicates


return @domains;
}  #  End GetDomainList


sub GetFileHTTP {
#---------------------------------------------------------------------------------
#   This routine uses the specified http utility to download a file from a
#   remote server. 
#---------------------------------------------------------------------------------
#
use File::stat;

    my $err = 1;
    my $tfile;

    return 1 if &mkdir("$UEMSinstall{UEMSHOME}/logs");
    my $dlog = "$UEMSinstall{UEMSHOME}/logs/http_download.log"; &rm($dlog);

    my ($rfile,$lfile) = @_; &rm($lfile); my $lsfile = &popit($lfile);

    my $meth = &popit($UEMSinstall{OPTION}{method});

    local $|=1;

    if (my $rsize = &FileAvailableHTTP($meth,$rfile)) {

        $err = 0;

        #  Give local file a temporary name, <filename>.<size>, until a successful download can be verified
        #
        $tfile = "${lfile}.$rsize";

        #  If a file with the same temporary filename already exists locally, then it ia likely that there was a problem
        #  during a previous download attempt.
        #
        my $cmd = ($meth =~ /curl/) ? "$UEMSinstall{OPTION}{method} -v -C - -s --connect-timeout 25 --max-time 7200 $rfile -o $tfile > $dlog 2>&1" :
                  ($meth =~ /wget/) ? "$UEMSinstall{OPTION}{method} -c -a $dlog -v -t 25 -T 25 --read-timeout=7200 --connect-timeout=10 -O $tfile  $rfile" : 0;
        return 1 unless $cmd;

        if (my $err = &SysExecute($cmd)) {
            &SysIntHandle if $err == 2; &PrintMessage(0,1,22,0,1,"Failed ($err)"); 
            if (-e $dlog) {open (my $fh, '<', $dlog);while (<$fh>) {$err = $err ? "$err $_" : $_;} close $fh;}
            return $err;
        }
        my $sf  = stat($tfile);
        $err = ($sf->size == $rsize) ? 0 : 1;
    }

    #  If successful, then rename the file
    #
    system "mv -f $tfile $lfile > /dev/null 2>&1" unless $err;


return $err;
}


sub GetHelpPleaseError  {
#-------------------------------------------------------------------------------------
#  Inform the user that a bad option/flag was passed - and that he/she is at fault
#-------------------------------------------------------------------------------------
#
    my @helps = @_;  #  Need to see if something was passed

    my %opts = &GetOptionList();  #  Get options list
    my @flgs = sort @{$opts{ids}};

    foreach my $arg (@helps) {$arg =~ s/\-//g;&SysDied("Are you missing dashes before the \"--$arg\" option?") if grep {/^$arg$/} @flgs;}
    foreach my $arg (@helps) {&SysDied("What, exactly, do you expect to achieve by passing such jibberish (\"$arg\")?");}

CORE::exit -1;
}


sub GetHelpPlease {
#-------------------------------------------------------------------------------------
#  This routine provides the basic structure for the ems_prep help menu
#  should  the "--help" option is passed or something goes terribly wrong.
#-------------------------------------------------------------------------------------
#
    my $exe = $UEMSinstall{EXE};

    my @helps = @_;  #  Need to see if something was passed

    my %opts = &GetOptionList();  #  Get options list
    my @flgs = sort @{$opts{ids}};

    #  Save for option help
    #
    #foreach my @arg (@helps) {s/\-//g;&helpers($arg) if grep (/^$arg$/, @flgs);}

    &PrintMessage(0,5,114,1,1,"RUDIMENTARY INFORMATION OF THE BASIC KIND:");

    $mesg = "The $exe routine handles all your UEMS installation and updating needs, even those of which ".
            "you were not aware. This routine is more powerful than you can imagine. Sometimes, it already ".
            "knows what you want before you do, although whether complies depends upon how it's been treated. ".
            "Just remember, as with all UEMS routines (and life too), $exe puts out as much as you put in.\n\n".

            "While the possible number of option combinations is probably unlimited, the list below contains ".
            "those options that will actually work, so you're better off playing it safe than attempting ".
            "something \"unauthorized\" that can have serious consequences.\n\nAlways listen to the UEMS (and your mother).";

    &PrintMessage(0,7,98,1,1,$mesg);

    &PrintMessage(0,5,144,2,1,"USAGE:  % $exe [semi-mandatory verbiage] [stuff you may not know about] [additional options]");

    &PrintMessage(0,5,144,2,1,"GUIDANCE - BECAUSE YOU ARE GOING TO NEED IT:");


    $mesg = "The novice $exe user should embrace its most basic of functions:\n\n".

            "   % $exe --install [release version] [--force]\n".
            "Or\n".
            "   % $exe --update  [release version] [--force]\n".
            "Or\n".
            "   % $exe --addpack  [nawips|source|workshop|xgeogs] [--force]\n\n".

            "The release version is optional as the default is the most current release. The inclusion of the \"--force\" flag ".
            "instructs $exe to unpack and install any tarfiles that already reside in the uems/release or update directory. These ".
            "files should have been unpacked during an earlier installation or update unless the \"--nounpack\" flag was passed.";

    &PrintMessage(0,7,90,1,1,$mesg);


    $mesg = "And as if it hasn't done enough for you already; look what else $exe can do for you:\n\n".

            "   % $exe --install list|listall|listgeog\n".
            "Or\n".
            "   % $exe --update  list|listall\n\n".

            "Which provides a listing of available UEMS releases, updates, and static terrestrial datasets.";

    &PrintMessage(0,7,104,2,1,$mesg);


    $mesg = "Still not satisfied (ya, me neither), then there is the \"info\" option:\n\n".

            "   % $exe --install info\n".
            "Or\n".
            "   % $exe --update  info\n\n".

            "Which lists the changes, enhancements, bug fixes, and moments of Zen in the specified release";

    &PrintMessage(0,7,104,2,1,$mesg);


    $mesg = "An additional helpful suggestion. When doing a fresh installation, you can import any existing computational ".
            "domains from a previous release with:\n\n".

          "   % $exe --install --import <path to existing domains>\n\n".

          "Each of the domains' configuration files will be updated with your current settings. Note that you don't have ".
          "to include the current $UEMSinstall{UEMSTOP}/runs directory as that is imported by default unless you pass the \"--noruns\" flag.";

    &PrintMessage(0,7,104,2,1,$mesg);



    $mesg = "OTHER AVAILABLE OPTIONS - BECAUSE YOU ASKED NICELY AND I'M BEGINNING TO LIKE YOU\n\n".
            "    Option            Argument             Usage       Description\n".
            "                     [optional] \n";
    &PrintMessage(0,5,114,2,0,$mesg);


    my @uses = qw(general install update both);
    foreach my $use (@uses) {
        &PrintMessage(0,1,1,1,0,q{ });
        foreach my $opt (@{$opts{order}{$use}}) {
            &PrintMessage(0,9,256,0,1,sprintf("%-16s  %-19s  %-10s  %-60s",$opt,$opts{list}{$opt}{arg},$opts{list}{$opt}{use},$opts{list}{$opt}{desc}));
        }
    }

    &PrintMessage(0,5,114,2,2,"FOR ADDITIONAL HELP, LOVE AND UNDERSTANDING:");
    &PrintMessage(0,11,114,0,1,"a. Read  - docs/uems/emsguide/emsguide_chapter02.pdf");
    &PrintMessage(0,7,114,0,1,"Or");
    &PrintMessage(0,11,114,0,1,"b. http://strc.comet.ucar.edu/software/uems");
    &PrintMessage(0,7,114,0,1,"Or");
    &PrintMessage(0,11,114,0,2,"c. Run   - % $exe --help       For this menu again");


CORE::exit -1;
}


sub GetOptionList {
#  =====================================================================================
#  This routine defined the list of options that can be passed to the program
#  and returns them as a hash.
#  =====================================================================================
#
    my %opts = ();

    %{$opts{list}} = (
                '--list'        => { arg => q{}                  , use  => 'general'    , desc => 'Provide a listing of available releases and updates.         NOTE: Use "--install|update list"'},
                '--listall'     => { arg => q{}                  , use  => 'general'    , desc => 'Provide a verbose listing of available releases and updates. NOTE: Use "--install|update listall"'},
                '--version'     => { arg => q{}                  , use  => 'general'    , desc => 'Print the UEMS install version number routine and get out.'},
                '--proxy'       => { arg => 'PROXY SETTING'      , use  => 'general'    , desc => 'Set the HTTP_PROXY environment variable. For those using a proxy server.'},

                '--install'     => { arg => '[RELEASE]'          , use  => 'install\'n' , desc => 'Tell the UEMS you want some installation action.'},
                '--continue'    => { arg => q{}                  , use  => 'install\'n' , desc => 'Continue download and installation from a previous attempt.'},
                '--dvd'         => { arg => 'MOUNT POINT'        , use  => 'install\'n' , desc => 'Install the UEMS from DVD and location of the DVD mount point.'},
                '--relsdir'     => { arg => 'DIR'                , use  => 'install\'n' , desc => 'Override the default directory for the release tarfiles on the local system.'},
                '--import'      => { arg => 'DIR'                , use  => 'install\'n' , desc => 'Import existing computational domains located in DIR (E.g., /usr1/ems_old/runs) to a new installation.'},
                '--noruns'      => { arg => q{}                  , use  => 'install\'n' , desc => 'Do not import existing domains from current ems/runs directory (Default: import domains).'},
                '--nogeog'      => { arg => q{}                  , use  => 'install\'n' , desc => 'Do not download and install the default WRF geographic datasets.'},
                '--xgeog'       => { arg => 'STRING'             , use  => 'install\'n' , desc => 'Download and install the WRF geographic datasets that match STRING.'},
          
                '--scour'       => { arg => q{}                  , use  => 'install\'n' , desc => 'Delete any current UEMS installation rather than saving it.'},
                '--addpack'     => { arg => 'STRING'             , use  => 'install\'n' , desc => 'Specify an ancillary package [nawips|workshop|source|xgeog] to be installed.'},

                '--allyes'      => { arg => q{}                  , use  => 'update\'n'  , desc => 'Automatically responds "YES" to all questions. Used for auto-updating via cron.'},
                '--update'      => { arg => '[RELEASE]'          , use  => 'update\'n'  , desc => 'Tell the UEMS you want some update\'n action.'},
                '--updtdir'     => { arg => 'DIR'                , use  => 'update\'n'  , desc => 'Override the default location (directory) of the UEMS update files.'},
                '--force'       => { arg => q{}                  , use  => 'update\'n'  , desc => 'Force the installation of an update even though it\'s already installed.'},
                '--norefresh'   => { arg => q{}                  , use  => 'update\'n'  , desc => 'Do not refresh (update) and older configuration files with new ones (although values are saved).'},


                '--debug'       => { arg => q{}                  , use  => 'both'       , desc => 'Turn ON basic debugging, which may be of limited value.'},
                '--emshome'     => { arg => 'EMSHOME'            , use  => 'both'       , desc => "Full path to the UEMS (E.g.: --emshome /usr1/$UEMSinstall{UEMSTOP})."},
                '--emshost'     => { arg => 'HOSTNAME'           , use  => 'both'       , desc => 'The hostname or IP of the UEMS server (Default is all UEMS servers).'},
                '--repodir'     => { arg => 'DIR'                , use  => 'both'       , desc => 'Directory where the releases or updates reside locally (DIR/<release>).'},
                '--nounpack'    => { arg => q{}                  , use  => 'both'       , desc => 'Do not unpack & install the downloaded tarfiles (Default is to install).'},
                '--nolocal'     => { arg => q{}                  , use  => 'both'       , desc => "Do not use the tarfiles found locally in $UEMSinstall{UEMSTOP}/release|updates - Get them server fresh."},
                '--wget'        => { arg => q{}                  , use  => 'both'       , desc => 'Use the wget routine for http requests to the UEMS server.'},
                '--curl'        => { arg => q{}                  , use  => 'both'       , desc => 'Use the curl routine for http requests to the UEMS server.'},
                );

    @{$opts{order}{install}} = qw(--install --relsdir  --addpack --continue --import  --noruns --nogeog --xgeog --dvd --scour);
    @{$opts{order}{update}}  = qw(--update  --updtdir  --allyes  --force --norefresh);
    @{$opts{order}{both}}    = qw(--emshome  --repodir --emshost --nolocal --nounpack  --curl --wget --debug );
    @{$opts{order}{general}} = qw(--list --listall --proxy --version);

    @{$opts{ids}}            = qw(install dvd import nogeog xgeog relsdir addpack continue update allyes force updtdir emshome wget curl debug emshost nolocal
                                  nounpack norefresh repodir scour list listall proxy version); @{$opts{ids}} = sort @{$opts{ids}}; #$_ = "--$_" foreach @{$opts{ids}};


return %opts;
}


sub GetPackageListLocal {
#==================================================================================
#   This routine sends a request to the UEMS server for a list of all release
#   and update tarfiles (packages) available for download. If successful, the
#   package names will be written to the appropriate hashed ($UEMSinstall{UPDATES}
#   and $UEMSinstall{RELEASES}.
#==================================================================================
#
use List::Util qw(shuffle);


    %{$UEMSinstall{UPDATES}}  = ();
    %{$UEMSinstall{RELEASES}} = ();

    #------------------------------------------------------------------------------
    #  All log files are written to $UEMS/logs or the instalers home directory,
    #  depending upon whether this is an update or new installation.
    #------------------------------------------------------------------------------
    #
    my $rlog = ($UEMSinstall{OPTION}{update} and -d "$ENV{UEMS}/logs") ? "$ENV{UEMS}/logs/http_request.log"
                                                                       : "$UEMSinstall{IUSER}{home}/http_request.log";
    &rm($rlog);


    #------------------------------------------------------------------------------
    #  We need the names of the updates indicated by update.* or the names of
    #  the releases packages indicated by release.*
    #------------------------------------------------------------------------------
    #
    my ($drepo,$rel) = &popit2($UEMSinstall{OPTION}{repodirs}[0]);
    &PrintMessage(1,4,255,1,1,"Local UEMS release and update repository: $drepo");

    my $ku = 'update';    #  Matching string for UPDATE  package files
    my $kr = 'release';   #  Matching string for RELEASE package files
    my $kg = 'wrf.geog';  #  Matching string for TERRESTRIAL datasets

    foreach my $drepo (@{$UEMSinstall{OPTION}{repodirs}}) {

        next unless -d $drepo;

        my $drel = &popit($drepo);

        opendir (my $dh, $drepo);

        foreach my $pkg (readdir $dh) { chomp $pkg;

            next unless $pkg =~ /^$ku|^$kr|^$kg/;

            my $size = -s "$drepo/$pkg";

            $UEMSinstall{UPDATES}{$drel}{"$drepo/$pkg"}  = $size if $pkg =~ /^$ku/;
            $UEMSinstall{RELEASES}{$drel}{"$drepo/$pkg"} = $size if $pkg =~ /^$kr|^$kg/;

        } closedir $dh;
    }

    %{$UEMSinstall{ADDPACKS}} = ();
    %{$UEMSinstall{UPDATES}}  = () if $UEMSinstall{OPTION}{install} or $UEMSinstall{OPTION}{addpacks};
    %{$UEMSinstall{RELEASES}} = () if $UEMSinstall{OPTION}{update};

return -1; #  Value < 0 is good
}


sub GetPackageListRemote {
#==================================================================================
#   This routine sends a request to the UEMS server for a list of all release
#   and update tarfiles (packages) available for download. If successful, the
#   package names will be written to the appropriate hashed ($UEMSinstall{UPDATES}
#   and $UEMSinstall{RELEASES}.
#==================================================================================
#
use List::Util qw(shuffle);

    #----------------------------------------------------------------------------------
    #  All log files are written to $UEMS/logs or the installer's home directory,
    #  depending upon whether this is an update or new installation.
    #----------------------------------------------------------------------------------
    #
    my $rlog = ($UEMSinstall{OPTION}{update} and -d "$ENV{UEMS}/logs") ? "$ENV{UEMS}/logs/http_request.log"
                                                                       : "$UEMSinstall{IUSER}{home}/http_request.log";
    &rm($rlog);


    my $host = $UEMSinstall{EMSHOSTS}{$UEMSinstall{EMSHOST}};

    #----------------------------------------------------------------------------------
    #  Set the routine to be used for http communication. Why do this step here rather than
    #  during the initialization or options process?  Because this routine will only be called
    #  for a connection to a remote server. Why bother checking is wget or curl are available
    #  when they will not be used?
    #----------------------------------------------------------------------------------
    #
    my $method=0;
    foreach (shuffle keys %{$UEMSinstall{OPTION}{methods}}) {$method = $UEMSinstall{OPTION}{methods}{$_} if $UEMSinstall{OPTION}{methods}{$_};}

    my $meth = &popit($method);

    $mesg = "Well that\'s just too bad - For You!\n\n".

            "I am unable to local neither the \"wget\" nor \"curl\" utilities, which are needed ".
            "to access information from the STRC servers. It was likely left out during the OS ".
            "installation so it should be pretty easy to fix the situation.";

    &SysDied($mesg) unless $method;

    #----------------------------------------------------------------------------------
    #  The utility to be used is now set in $UEMSinstall{OPTION}{method} 
    #----------------------------------------------------------------------------------
    #
    $UEMSinstall{OPTION}{method} = $method;

    #----------------------------------------------------------------------------------
    #  Configure the command
    #----------------------------------------------------------------------------------
    #
    my $https = "\"http://$host/cgi-bin/uems_info.pl?list\"";


    #----------------------------------------------------------------------------------
    #  Define the commands to be used by wget and curl to retrieve the information. 
    #----------------------------------------------------------------------------------
    #
    local $|=1;
    my $cmd = ($meth eq 'curl') ? "$meth -q -s -f --connect-timeout 10 --max-time 30 $https > $rlog 2>&1" :
              ($meth eq 'wget') ? "$meth -a /tmp/wget.log -nv -t 3 -T 10 --read-timeout=1800 --connect-timeout=10 -O $rlog $https" : 0;
    &SysDied("Who took my method ($meth)?") unless $cmd;


    #----------------------------------------------------------------------------------
    #  Connect to the designated UEMS server via http
    #----------------------------------------------------------------------------------
    #
    &PrintMessage(1,4,96,1,0,"Connecting to $host -");


    #----------------------------------------------------------------------------------
    #  This is how it works - An attempt will be made to collect the requested 
    #  information. If successful, then the information will be processed and
    #  printed out for the user. If it fails, then the http commands will be 
    #  run again in verbose mode to collect additional information and hopefully
    #  determine the cause of the issue.
    #----------------------------------------------------------------------------------
    #
    if (system "$cmd") { &SysIntHandle if $? == 2;

        &PrintMessage(0,1,60,0,2," Failed");

        #----------------------------------------------------------------------------------
        #  We are here only if the curl or wget command has failed, in which case we 
        #  must re-run the command in verbose mode and collect information about the cause.
        #----------------------------------------------------------------------------------
        #
        &rm($rlog);


        #----------------------------------------------------------------------------------
        #  Let's run the command again in verbose mode to get some helpful information.
        #----------------------------------------------------------------------------------
        #
        my $acmd = ($meth eq 'curl') ? "$meth -q -v -f --connect-timeout 10 --max-time 30 $https > $rlog 2>&1" :
                   ($meth eq 'wget') ? "$meth -a /tmp/wget.log -v -t 3 -T 10 --read-timeout=1800 --connect-timeout=10 -O $rlog $https" : 0;


        #----------------------------------------------------------------------------------
        #  Run the command and collect the information
        #----------------------------------------------------------------------------------
        #
        system "$acmd";


        #----------------------------------------------------------------------------------
        #  Now collect the information and report back to user
        #----------------------------------------------------------------------------------
        #
        my $err = q{};
        if (-e $rlog) {open (my $fh, '<', $rlog); while (<$fh>) {$err = $err ? "$err $_" : $_;} close $fh;}

        &PrintMessage(6,8,144,1,1,"There was a problem retrieving information from $host");
        &PrintMessage(0,11,144,1,1,$err) if $err;
        &SysDied(q{ });

    }
    my $type = $UEMSinstall{OPTION}{install} ? 'Release' : $UEMSinstall{OPTION}{update} ? 'Update' : 'UEMS package';
    &PrintMessage(0,1,60,0,1," $type information received");


    #----------------------------------------------------------------------------------
    #  Begin by interrogating the log file to determine whether there was a result.
    #  We need the names of the updates indicated by AVAILABLE UPDATE: <UPDATE>
    #  or the names of the releases indicated by AVAILABLE RELEASE: <RELEASE>
    #----------------------------------------------------------------------------------
    #
    my $ku = 'AVAILABLE UPDATE:';
    my $kr = 'AVAILABLE RELEASE:';

    open (my $fh, '<', $rlog);
    while (<$fh>) { chomp;

        next unless /$ku|$kr/;

        if (s/$ku//g) { #  Update package file
            s/ //g; chomp;
            my ($drel, $pkg, $size) = split /;/ => $_, 3;
            next unless defined $drel and defined $pkg and defined $size;
            $UEMSinstall{UPDATES}{$drel}{$pkg} = $size;
        } elsif (s/$kr//g) { #  Release package file
            s/ //g; chomp;
            my ($drel, $pkg, $size) = split /;/ => $_, 3;
            next unless defined $drel and defined $pkg and defined $size;
            $UEMSinstall{RELEASES}{$drel}{$pkg} = $size;
        }

    } close $fh; &rm($rlog);


    %{$UEMSinstall{ADDPACKS}} = ();
    %{$UEMSinstall{UPDATES}}  = () if $UEMSinstall{OPTION}{install} or $UEMSinstall{OPTION}{addpacks};
    %{$UEMSinstall{RELEASES}} = () if $UEMSinstall{OPTION}{update};


return -1; #  Value < 0 is good
}


sub GetUEMSrelease {
#----------------------------------------------------------------------------------
#    Routine reads the contents of the $UEMS/strc/.release file and returns the
#    UEMS version number. If one is not available '00.00.00.00' is returned.
#----------------------------------------------------------------------------------
#
    my $ver  = 0;

    my $ems = shift; return $ver unless defined $ems and $ems;

    my $rfile = (-e "$ems/strc/.release")                              ? "$ems/strc/.release"       :
                (defined $ENV{UEMS} and -e "$ENV{UEMS}/strc/.release") ? "$ENV{UEMS}/strc/.release" : 0;

    return $ver unless $rfile;

    open (my $fh, '<', $rfile); my @lines = <$fh>; close $fh; foreach (@lines) {chomp; $ver = $_ if /EMS/i;}
    $ver =~ s/ //g; $ver =~ s/UEMS|EMS//g; $ver = 0 unless $ver;
    

return $ver;
}


sub GetWRFrelease {
#----------------------------------------------------------------------------------
#    Routine reads the contents of the $UEMS/strc/.release file and returns the
#    the WRF version number. If one is not available '0' is returned.
#----------------------------------------------------------------------------------
#
    my $ver  = 0;

    my $ems = shift; return $ver unless defined $ems and $ems;

    my $rfile = (-e "$ems/strc/.release")                              ? "$ems/strc/.release"       :
                (defined $ENV{UEMS} and -e "$ENV{UEMS}/strc/.release") ? "$ENV{UEMS}/strc/.release" : 0;

    return $ver unless $rfile;

    open (my $fh, '<', $rfile); my @lines = <$fh>; close $fh; foreach (@lines) {chomp; $ver = $_ if /WRF|ARW/i;}
    $ver =~ s/ //g; $ver =~ s/WRF|ARW//g;

return $ver;
}


sub Hash2Namelist {
#----------------------------------------------------------------------------------
#  This routine takes the name of a namelist file and a hash of namelist sections
#  and variables (a hash of a hash) and writes the information to the namelist
#  file. Basically, the reverse of Namelist2Hash.
#----------------------------------------------------------------------------------
#
    my ($nl, $template, %hash)  = @_;

    #  Save off the original namelist file should things go horribly wrong.
    #
    system "mv $nl $nl\.orig" if -e $nl and ! -e "$nl\.orig";

    my %nlorder = &NamelistOrder($template);

    #  Open namelist file for writing
    #
    open (my $wfh, '>', $nl) || &SysDied('The Hash2Namelist routine',"BUMMER: Namelist file problem ($nl)",0);

    foreach my $sect (@{$nlorder{order}}) {
        print $wfh '&',lc $sect,"\n";
        foreach my $field (@{$nlorder{$sect}}) {
            unless ($sect =~ /wizard/i) {next unless (defined $hash{uc $sect}{$field} and @{$hash{uc $sect}{$field}});}
            if (defined $hash{uc $sect}{$field}) {
                my $valu = join ', ' => @{$hash{uc $sect}{$field}};
                my $line = sprintf ' %-26s = %s',lc $field,$valu;
                print $wfh "$line\n";
            }
        }
        print $wfh "/\n\n";
    }
    close $wfh;

return;
}


sub Namelist2Hash {
#----------------------------------------------------------------------------------
#  This routine reads a namelist and writes it to a hash. Each hash contains a
#  list of nl variables with a list of values. So, a hash of lists of lists. Got it.
#  Returns the hash.
#----------------------------------------------------------------------------------
#
    my $sect;
    my $tvr;
    my %hash;

    # namelist is the only argument passed into routine
    #
    my $nl  = shift;
    open (my $rfh, '<', $nl) || &SysDied('The Namelist2Hash routine',"BUMMER: Namelist file problem ($nl) - $!",0);

    while (<$rfh>) {
        chomp;
        next if /^#|^$/;
        undef $sect if $sect and /^\s*(\/)/;

        if ($sect) {
            my ($var, $value) = split /\s*=\s*/, $_, 2;
            # Eliminate training comma. Also do some clean up string by eliminating multiple
            # white spaces between values.
            #
            $var   =~ s/ //g;
            $var   = lc $var;
            $value =~ s/(,\s*)$//g if defined $value;

            if (defined $value) {
                # clean up entries in the configuration file by removing
                # training commas and white spaces and also substituting commas
                # for (semi-) colons.
                #
                $tvr   = $var;
                $value =~ s/ //g unless $var =~ /dwiz_desc/i;
                my @list = split /,/ => $value;
                @{$hash{uc $sect}{lc $var}} = @list;
            } else { # A continuation of the previous value
                $var =~ s/ //g;
                $var =~ s/(,\s*)$//g;
                my @list = split /,/ => $var;
                push @{$hash{uc $sect}{lc $tvr}}, @list;
            }
        }
        $sect = uc $_ if s/^\s*(&)//g;
    }
    close $rfh;

return %hash;
}


sub NamelistOrder {
#----------------------------------------------------------------------------------
#  This routine reads the contents of a default namelist to get the desired
#  order for the fields printed to the namelists in the users runs. The reason
#  for this routine is that since the primary namelist list is help in a hash,
#  it prints in random order and thus can be confusing to a reader.  This
#  could be built into the Namelist2Hash routine but this appears easier.
#----------------------------------------------------------------------------------
#
    my %hash;
    my $sect;

    # namelist is the only argument passed into routine
    #
    my $nl  = shift;
    open (my $rfh, '<', $nl) || &SysDied('The NamelistOrder routine',"BUMMER: Namelist file problem ($nl) - $!",0);

    while (<$rfh>) {
        chomp;
        next if /^#|^$/;

        undef $sect if $sect and /^\s*(\/)/;
        if ($sect) {
            my ($var, $value) = split /\s*=\s*/, $_, 2;

            # Eliminate training comma. Also do some clean up string by eliminating multiple
            # white spaces between values.
            #
            $var   =~ s/ //g;
            $var   = lc $var;
            push @{$hash{$sect}} => $var if defined $value;
        }

        if (s/^\s*(&)//g) {
            $sect = lc $_;
            push @{$hash{order}} => $sect;
        }
    }
    close $rfh;

return %hash;
}


sub ReadConfigurationFile {
#----------------------------------------------------------------------------------
#  This routine reads the contents of the input configuration files and
#  returns a hash containing the parameter and value
#----------------------------------------------------------------------------------
#
    my $filename  = shift;

    my $exp = $filename =~ /export/i;

    open (my $rfh, '<', $filename);

    my %hash=();
    my @list=();
    my $pvar='';

    while (<$rfh>) {
        tr/\000-\037/ /;
        s/^\s+//g;
        next if /^#|^$|^\s+/;
        s/ //g unless /MPIRUNARGS/;
        s/\t//g;s/\n//g;

        if (/\s*=\s*/) {
            my ($var, $value) = split /\s*=\s*/, $_, 2;
            $value = '' unless length $value;  # Make sure everything is initialized to a value
            if ($exp) {
                push @list => $value;
            } else {
                $hash{uc $var} = $value;
                $pvar = $var;
            }
        } else { # must be a continuation
            $hash{uc $pvar} = "$hash{uc $pvar}$_";
        }
    }
    close $rfh;

return $exp ? @list : %hash;
}


sub SortPackages {
#----------------------------------------------------------------------------------
#   A routine to sort the update and full release names. This task gets messy
#   as the names can not be correctly sorted by the Perl sort routines due to
#   the naming convention. Thus, some reformatting is necessary before we can
#   use the Perl sort utility. 
#----------------------------------------------------------------------------------
#
    my %hash = ();

    my @list = sort @_;

    foreach (@list) {

        my @nlist = ();
        my @rlist = split /\./ => $_;

        foreach (@rlist) {
            next if /\D/;  $_+=0;
            push @nlist => sprintf("%02d",$_);
        }

        #  The reformatted and original names are placed in a hash with the reformatted
        #  name used as the key. Then sort on the keys and write the original names to
        #  a new list.
        #
        my $ver = join q{} => @nlist; $ver =~ s/ //g;
        $hash{$ver} = $_ if $ver;
    }

    #  We now have the hash so sort on the keys. The original names will
    #  be written to the list from newest -> oldest (hopefully).
    #
    @list = ();
    push @list => $hash{$_} foreach sort {$b <=> $a} keys %hash;

return @list;
}


sub TextFormat {
#==================================================================================
#  Routine to format a sentence/paragraph for printing.  The arguments are:
#
#  $h_indnt  -  Number of spaces to indent the 1st line of the string $head
#  $b_indnt  -  Number of spaces to indent remaining lines of $head or all of @body
#  $wrapcol  -  Column number at which to wrap the paragraph, independent of indent
#  $leadnl   -  Number of newlines before initial line of text
#  $trailnl  -  Number of newlines after final line of text
#  @body     -  Array of Character strings that make up the paragraph
#==================================================================================
#
use Text::Wrap;

    my $nl = "\n";

    my ($h_indnt,$b_indnt,$wrapcol,$leadnl,$trailnl,@body)  = @_;

    return '' unless @body;

    my $head = shift @body;

    #  Set defaults
    #
    local $Text::Wrap::columns = $wrapcol > 80 ? $wrapcol : 80;  # sets the wrap point. Default is 80 columns.
    local $Text::Wrap::separator="\n";
    local $Text::Wrap::unexpand=0;

    $h_indnt = 0 unless $h_indnt =~ /^\d+$/;
    $b_indnt = 0 unless $b_indnt =~ /^\d+$/;

    $h_indnt   = ! $h_indnt ? 0 : $h_indnt < 0 ? 0 : $h_indnt;
    $b_indnt   = ! $b_indnt ? 0 : $b_indnt < 0 ? 0 : $b_indnt;

    $leadnl  = $leadnl  < 0 ? sprintf ('%s',$nl x 1) : sprintf ('%s',$nl x $leadnl);
    $trailnl = $trailnl < 0 ? sprintf ('%s',$nl x 1) : sprintf ('%s',$nl x $trailnl);

    my $hindnt = $h_indnt < 0 ? sprintf('%s',q{ } x 1) : sprintf('%s',q{ } x $h_indnt);
    my $bindnt = sprintf('%s',q{ } x $b_indnt);

    my $bodyA = wrap($hindnt,$bindnt,$head); $bodyA = "$bodyA\n\n" if @body;
    my $bodyB = @body ? fill($bindnt,$bindnt,@body) : '';

return "$leadnl$bodyA$bodyB$trailnl";
} #  TextFormat



sub UnpackTarfile {
#---------------------------------------------------------------------------------
#   Unpack UEMS package tarfile
#---------------------------------------------------------------------------------
#
    my ($file, $dir) = @_;

    unless (-e $file) {
        &PrintMessage(6,7,144,1,2,"File not found - $file");
        return 1;
    }
    system "chmod -R 755 $file > /dev/null 2>&1";

    if ($file =~ /tgz$/i) {

        if (my $err = &SysExecute("tar -xzf $file -C $dir > /dev/null 2>&1")) {
            &PrintMessage(6,7,144,2,1,"Problem unpacking $file ($err) - Exit");
            &PrintMessage(0,7,144,1,1,"Command: tar -xzf $file -C $dir");
            return 1;
        }

    } elsif ($file =~ /tbz$/i) {

        if (my $err = &SysExecute("tar -xjf $file -C $dir > /dev/null 2>&1")) {
            &PrintMessage(6,7,144,2,1,"Problem unpacking $file ($err) - Exit");
            &PrintMessage(0,7,144,1,1,"Command: tar -xjf $file -C $dir");
            return 1;
        }
    }
    system "chmod -R 755 $dir > /dev/null 2>&1";

return 0;
}


sub PrintDidYouKnow {
#----------------------------------------------------------------------------------
#  Information to be printed out at various times during the downloading and
#  installation process.
#----------------------------------------------------------------------------------
#
    return unless @{$UEMSinstall{DYKS}};

    my @headers = ("\"DID YOU KNOW?\"",
                   "\"DID YOU NEED TO KNOW?\"",
                   "\"HAVE YOU SEEN ME?\"",
                   "\"LOOK AT ME WHEN I'M TALKING TO YOU!\"",
                   "\"HEY, WATCH THIS!\"",
                   "\"DO YOU CARE?\"");

    my $mesg = shift @{$UEMSinstall{DYKS}};
    my $head = $headers[int rand($#headers)];
    &PrintMessage(0,14,108,1,1,$head,$mesg);

return;
}


sub PrintVersion {
#----------------------------------------------------------------------------------
#  Print the version number and exit
#----------------------------------------------------------------------------------
#
    &PrintMessage(0,4,96,1,2,"What you have here is the UEMS installation and update tool (V$UEMSinstall{VERSION})");

CORE::exit 0;
}


sub PrintHash {
#----------------------------------------------------------------------------------
#  This routine prints out the contents of a hash. If a KEY is passed then the
#  routine will only print key-value pairs beneath that KEY. If no KEY is passed
#  then the routine will print out all key-value pairs in the hash.
#  For Debugging only.
#----------------------------------------------------------------------------------
#
    my ($href, $skey, $ns) = @_;

    my %phash = %{$href}; return unless %phash;

    $skey = q{} unless $skey;
    $ns   = 0 unless $ns;

    print sprintf("\n\n%sHASH:  %s\n\n",q{ }x$ns,$skey) if $skey;
    print sprintf("\n    TOP LEVEL OF HASH:  %s\n\n",$skey) unless $ns;

    $ns+=4;

    foreach my $key (sort keys %phash) {

        my $refkey = $skey ? "{$skey}{$key}" : "{$key}";

        for (ref($phash{$key})) {

            /HASH/     ?  &PrintHash(\%{$phash{$key}},$key,$ns)      :
            /ARRAY/    ?  print sprintf("%sARRAY :   %-60s  %s\n",q{ }x$ns,$refkey,@{$phash{$key}}      ? join ', ' => @{$phash{$key}} : "Array $refkey is empty\n")  :
                          print sprintf("%sSCALAR:   %-60s  %s\n",q{ }x$ns,$refkey,defined $phash{$key} ? $phash{$key}                 : "Value $refkey is not defined\n");

        }
    }
    print "\n";

return;
}


sub PrintInfoCPU {
#----------------------------------------------------------------------------------
#  Print out the information about the CPUs on the local system.
#----------------------------------------------------------------------------------
#

    my $es = ($UEMSinstall{EUSER}{shell} =~ /bash/i) ? 'EMS.profile' : 'EMS.cshrc';
       $es = "$UEMSinstall{UEMSHOME}/etc/$es";

    $mesg = "    HOSTNAME         : $UEMSinstall{ISYS}{hostname0}\n".
            "    SOCKETS          : $UEMSinstall{ISYS}{sockets}\n".
            "    CORES PER SOCKET : $UEMSinstall{ISYS}{cores_per_socket}\n".
            "    TOTAL CORES      : $UEMSinstall{ISYS}{total_cores}\n\n".
   
            "If these values are not correct, then feel free to change them in the $es file ".
            "once the installation is complete.";
 

    &PrintMessage(1,4,94,2,1,"Here's the processor information I dug up for $UEMSinstall{ISYS}{hostname0}:",$mesg);


    if ($UEMSinstall{ISYS}{ht}) {

        $mesg = "The UEMS installation routine also noticed that you have hyper-threading turned ON, which ".
                "gives the illusion and false sense of security that your system has twice as many processors. ".
                "Don't be fooled into thinking that you can use more processors than are physically available, ".
                "no matter what some large marketing department has told you. The UEMS will run most efficiently ".
                "with one thread per processor. Any more will degrade performance!\n\n".

                "The UEMS Overlord strongly suggests that you forget about this hyper-thread nonsense by turning ".
                "it OFF in your BIOS; otherwise, you are likely to see this message again (and again).";

        &PrintMessage(6,4,92,2,1,"Oh yes, there is one more thing ... Warning to Hyper-Threading junkies!",$mesg);

        &PrintMessage(0,7,88,2,0,"\"I recognize and accept the consequences of my actions.\" [just hit enter]:");
        my $ans = <>;

    }


return;
}


sub PrintInspiration {
#----------------------------------------------------------------------------------
#  Provides an inspirational message to the user in the event of a screw-up
#----------------------------------------------------------------------------------
#
     $mesg = shift;

     return unless $mesg;

     my $err  = int rand(1000);
     my $tab = q{  };

     my $im   = &GetInspirationMessage(); my $lm = length $im;

     my $c = '"';
     my $i = rindex $im,$c;

     my $q = substr $im, 0, $i+1;
     my $a = substr $im, $i+1; $a =~ s/^ +//g; $a =~ s/ +$//g;
     my $ca = 80 - length $a;

     &PrintMessage(6,4,94,2,1,"UEMS Inspirational Message #$err - Help Me, Help You");
     &PrintMessage(0,7,88,1,2,$mesg);
     &PrintMessage(0,7,88,1,1,$q);
     &PrintMessage(0,$ca,88,0,1,$a);

return;
}


sub PrintOath {
#  ==================================================================================
#  Get the users to agree to anything. Once this delusion is achieved the garden
#  gnomes will follow!
#  ==================================================================================
#
        unless (%{$UEMSinstall{RELEASES}}) {
            &PrintMessage(2,4,114,1,2,"The UEMS is just another arrow in your quiver of success. Don't blow it.");
            return;
        }

        &PrintMessage(2,4,144,1,1,"Almost done - But now re-read the information above, just in case you missed something important.");

        #&PrintMessage(1,4,104,2,1,"Almost done - But first recite the following UEMS Loyalty Oath:");

        #$mesg = "\"I have perused the barely readable and totally incomprehensible babble above,\n".
        #         " and completely believe in the omnipotent wisdom of the UEMS and its\n".
        #         " creator. In addition, I do not hold the UEMS responsible for my personal\n".
        #         " failings, which would be few if I had any at all. I also understand that\n".
        #         " running the UEMS may result in my becoming more svelte, increasingly\n".
        #         " intelligent, and devastatingly good looking, not necessarily in that order.\"";

        #&PrintMessage(0,9,104,1,1,$mesg);

        #&PrintMessage(0,7,114,1,0,"Press the Enter key to continue this odyssey [I completely agree with some of it]:  ");

        &PrintMessage(0,7,114,1,0,"\"I'm Continuing my trajectory towards success! [And I've re-read the blather above]:  ");
        my $ans = <>;

        &PrintMessage(0,1,1,1,0,q{});

return;
}


sub PrintPackageList {
#-------------------------------------------------------------------------------------------
#   This routine prints out information on the UEMS packages available in the servers
#-------------------------------------------------------------------------------------------
#
    #&PrintMessage(1,4,104,1,2,&GetSystemInfoString(\%{$UEMSinstall{ISYS}}));

    my $rv = ($UEMSinstall{OPTION}{list} eq 'releases') ? &PrintReleasePackages()
                                                        : &PrintUpdatePackages();

return $rv;
}


sub PrintReleasePackages {
#===========================================================================================
#   This routine prints out information on the UEMS packages available from 
#   the STRC family of servers.
#===========================================================================================
#
use List::Util qw(min max first);


    my %alph;  @alph{'a' .. 'z'} = (0 .. 25);

    my $irel = $UEMSinstall{IEMS}{emsver}  ? $UEMSinstall{IEMS}{emsver} : 'No UEMS Installed';
    my $wrel = $UEMSinstall{IEMS}{wrfver}  ? "(WRF V$UEMSinstall{IEMS}{wrfver})" : q{};


    #-------------------------------------------------------------------------------------------
    #  Now create lists containing the sorted updates and releases. This is a bit messy
    #  as the file names must be reformatted for the Perl sort routines.
    #
    #  @releases  contains the correctly sorted list of available UEMS releases
    #-------------------------------------------------------------------------------------------
    #
    my @releases = &SortPackages(keys %{$UEMSinstall{RELEASES}});


    &PrintMessage(1,4,96,1,2,"Installed UEMS Release : $irel $wrel");

    my @frels = ();
    my $wvstr = 0;
    my %wrfv  = ();

    foreach (@releases) {
        next if /^wrfgeog|^wrf\.geog/i;
        push @frels => $_;
        if ($wvstr = first { /wrfbin_/ } keys %{$UEMSinstall{RELEASES}{$_}}){$wvstr = ($wvstr =~ s/wrfbin_(\w+)\.x64//) ? $1 : 0;}
        if ($wvstr) {my @wvl = split // => $wvstr; $_ = $alph{$_} foreach @wvl; $wvstr = join '.' => @wvl;}
        $wrfv{$_} = $wvstr ? "(WRF V$wvstr)" : q{};
    }
    &PrintMessage(1,4,96,1,1,"Summary of Available UEMS Releases");


    #-------------------------------------------------------------------------------------------
    #  Print out the available full releases
    #-------------------------------------------------------------------------------------------
    #
    &PrintMessage(0,7,96,1,0,@frels ? 'Available Full Releases:' : 'Available Full Releases: None');

    my $n  = 0;
    foreach (@frels) {
        my $fwrf = $wrfv{$_};
        $_ = sprintf('%-12s',$_); s/ //g;
        $n++ ? $irel eq $_ ? &PrintMessage(0,32,96,1,0,"$_ -> Currently Installed $wrel") :
                             &PrintMessage(0,32,96,1,0,"$_ $fwrf") :
                             &PrintMessage(0,32,96,1,0,"$_ -> Most Current Release $fwrf");
    }
    &PrintMessage(0,10,96,1,0,q{ });


    #-------------------------------------------------------------------------------------------
    #  If --install listall or --update listall was passed
    #-------------------------------------------------------------------------------------------
    #
    if ($UEMSinstall{OPTION}{listall}) {

        foreach my $release (sort @releases) {

            my %packages = %{$UEMSinstall{RELEASES}{$release}};  my $n = grep {!/wrf\.geog/} keys %packages;

            $mesg = $UEMSinstall{EMSHOST}  ? "$n Release $release packages on $UEMSinstall{EMSHOSTS}{$UEMSinstall{EMSHOST}} (not including geographical datasets)" :
                                             "$n Release packages in $UEMSinstall{OPTION}{repodir}/$release (not including geographical datasets)";
            &PrintMessage(0,7,255,2,1,$mesg);

            foreach my $file (sort keys %packages) {
                next if &popit($file) =~ /wrf\.geog/;
                my $sz = ($packages{$file} < 100000) ? sprintf '%-.2f KB', &Bytes2KB($packages{$file})
                                                     : sprintf '%-.2f MB', &Bytes2MB($packages{$file});
                &PrintMessage(0,9,255,1,0,sprintf('File: %-36s %12s',&popit($file),$sz));
            }
        }
        &PrintMessage(0,10,96,1,0,q{ });
    }


    #-------------------------------------------------------------------------------------------
    #  If --install listgeog was passed
    #-------------------------------------------------------------------------------------------
    #
    if ($UEMSinstall{OPTION}{listgeog}) {

        foreach my $release (sort @releases) {

            my %packages = %{$UEMSinstall{RELEASES}{$release}};

            my @ageogs = grep {/_gtopo|_nlcd2006|_nlcd2011/}  grep {/wrf\.geog/} keys %packages;
            my @bgeogs = grep {!/_gtopo|_nlcd2006|_nlcd2011/} grep {/wrf\.geog/} keys %packages;
             
            my $n = @bgeogs;  # Number of base datasets 

            $mesg = $UEMSinstall{EMSHOST}  ? "$n Base geographical dataset packages on $UEMSinstall{EMSHOSTS}{$UEMSinstall{EMSHOST}}" :
                                             "$n Base geographical dataset packages in $UEMSinstall{OPTION}{repodir}/$release";
            &PrintMessage(0,7,255,2,1,$mesg);

            foreach my $file (sort @bgeogs) {
                my $sz = ($packages{$file} < 100000) ? sprintf '%-.2f KB', &Bytes2KB($packages{$file})
                                                     : sprintf '%-.2f MB', &Bytes2MB($packages{$file});
                &PrintMessage(0,9,255,1,0,sprintf('Base Geog: %-48s %12s',&popit($file),$sz));
            }

            $n = @ageogs;  # Number of additional datasets

            &PrintMessage(0,7,255,2,1,"The following $n geographic dataset are available by using the \"--xgeog gtopo|nlcd2006|nlcd2011\" flag:");

            foreach my $file (sort @ageogs) {
                my $sz = ($packages{$file} < 100000) ? sprintf '%-.2f KB', &Bytes2KB($packages{$file})
                                                     : sprintf '%-.2f MB', &Bytes2MB($packages{$file});
                &PrintMessage(0,9,255,1,0,sprintf('Additional Geog: %-42s %12s',&popit($file),$sz));
            }

        }
        &PrintMessage(0,10,96,1,0,q{ });
    }


    #-------------------------------------------------------------------------------------------
    #  Print something if the user is up-to-date
    #-------------------------------------------------------------------------------------------
    #
    &PrintMessage(2,4,96,2,2,"No need for an UEMS update at this time - You are current ... and totally awesome!") if $irel eq $releases[0];

return ($irel eq $releases[0]) ? 0 : ($irel eq 'No UEMS Installed') ? 3 : 2;
}


sub PrintUpdatePackages {
#===========================================================================================
#   This routine prints out information on the UEMS updates available from 
#   the STRC family of servers.
#===========================================================================================
#
use List::Util 'first';


    my %alph;
       @alph{'a' .. 'z'} = (0 .. 25);

    my $irel = $UEMSinstall{IEMS}{emsver}  ? $UEMSinstall{IEMS}{emsver} : 'No UEMS Installed';
    my $wrel = $UEMSinstall{IEMS}{wrfver}  ? "(WRF V$UEMSinstall{IEMS}{wrfver})" : q{};


    #-------------------------------------------------------------------------------------------
    #  Now create lists containing the sorted updates and releases. This is a bit messy
    #  as the file names must be reformatted for the Perl sort routines.
    #
    #  @updates  contains the correctly sorted list of available UEMS updates
    #-------------------------------------------------------------------------------------------
    #
    my @updates  = &SortPackages(keys %{$UEMSinstall{UPDATES}});


    &PrintMessage(1,4,96,1,2,"Installed UEMS Release : $irel $wrel");

    my @fupds = ();
    my $wvstr = 0;
    my %wrfv  = ();

    foreach (@updates) {
        next unless $_;
        push @fupds => $_;
        if ($wvstr = first { /wrfbin_/ } keys %{$UEMSinstall{UPDATES}{$_}}){$wvstr = ($wvstr =~ s/wrfbin_(\w+)\.x64//) ? $1 : 0;}
        if ($wvstr) {my @wvl = split // => $wvstr; $_ = $alph{$_} foreach @wvl; $wvstr = join '.' => @wvl;}
        $wrfv{$_} = $wvstr ? "(WRF V$wvstr)" : q{};
    }
    &PrintMessage(1,4,96,1,1,"Summary of Available UEMS Updates");

    #-------------------------------------------------------------------------------------------
    #  Print out the available updates
    #-------------------------------------------------------------------------------------------
    #
    &PrintMessage(0,7,96,1,0,@fupds ? 'Available Release Updates :' : 'Available Release Updates : None');

    my $iq = 0;
    my $n  = 0;
    foreach (@fupds) {
        next if $iq;
        my $fwrf = $wrfv{$_};
        $_ = sprintf("%-12s",$_); s/ //g;
        $n++ ? ($irel eq $_) ? &PrintMessage(0,35,96,1,0,"$_ -> Currently Installed $wrel") :
                               &PrintMessage(0,35,96,1,0,"$_ $fwrf") :
                               &PrintMessage(0,35,96,1,0,"$_ -> Most Current Release $fwrf");
        $iq = 1 if $irel eq $_;
    }
    &PrintMessage(0,35,96,1,0,q{ }) if @fupds;


    #-------------------------------------------------------------------------------------------
    #  If --install listall or --update listall was passed
    #-------------------------------------------------------------------------------------------
    #
    if ($UEMSinstall{OPTION}{listall}) {

        foreach my $update (sort @updates) {

            my %packages = %{$UEMSinstall{UPDATES}{$update}};  my $n = keys %packages;

            $mesg = $UEMSinstall{EMSHOST} ? "$n Update $update packages located on $UEMSinstall{EMSHOSTS}{$UEMSinstall{EMSHOST}}" :
                                            "$n Update packages found in $UEMSinstall{OPTION}{repodir}/$update";
            &PrintMessage(0,7,96,2,1,$mesg);

            foreach my $file (sort keys %packages) {
                next if &popit($file) =~ /wrf\.geog/;
                my $sz = ($packages{$file} < 100000) ? sprintf '%-.2f KB', &Bytes2KB($packages{$file}) 
                                                     : sprintf '%-.2f MB', &Bytes2MB($packages{$file});
                &PrintMessage(0,9,255,1,0,sprintf('Update File: %-36s %12s',&popit($file),$sz));
            }
            &PrintMessage(0,10,96,1,0,q{ });
        }
    }


    #-------------------------------------------------------------------------------------------
    #  Print something if the user is up-to-date
    #-------------------------------------------------------------------------------------------
    #
    &PrintMessage(2,4,96,3,1,"There are no updates available, which means you are current ... and totally awesome!") unless @updates;
    &PrintMessage(2,4,96,3,1,"No need for an UEMS update at this time - You are current ... and totally awesome!") if @updates and $irel eq $updates[0];

return (! @updates or $irel eq $updates[0]) ? 0 : ($irel eq 'No UEMS Installed') ? 3 : 2;
}


sub PrintMessage {
#----------------------------------------------------------------------------------
#  This routine prints all error, warning, and information statements to the
#  user with a consistent format.
#----------------------------------------------------------------------------------
#
use Text::Wrap;

    my ($type,$indnt,$cols,$leadnl,$trailnl,$head,$body,$text)  = @_;

    # - &styleCharacters
    #    2 - "\xe2\x98\xba"  Smiley Face
    #    3 - "\xe2\x98\x85"  Black sun with rays
    #    4 - "dbg"
    #    5 - "->"
    #    6 - "!"
    #    7 - "\xe2\x9c\x93" Check Mark
    #    9 - "\xe2\x98\xa0" Skull & Crossbones


    #  Set defaults
    #
    local $Text::Wrap::columns = $cols > 80 ? $cols : 80;  # sets the wrap point. Default is 80 columns.
    local $Text::Wrap::separator="\n";
    local $Text::Wrap::unexpand=1;

    my $nl   = "\n";

    $indnt   = ! $indnt ? 6 : $indnt < 0 ? 6 : $indnt;
    $leadnl  = $leadnl  < 0 ? sprintf('%s',$nl x 1) : sprintf('%s',$nl x $leadnl);
    $trailnl = $trailnl < 0 ? sprintf('%s',$nl x 1) : sprintf('%s',$nl x $trailnl);


    my $symb  = ($type == 0) ? q{}            :
                ($type == 1) ? '*'            :
                ($type == 2) ? "\xe2\x98\xba" :
                ($type == 3) ? "\xe2\x98\x85" :
                ($type == 4) ? 'dbg'          :
                ($type == 5) ? '->'           :
                ($type == 6) ? '!'            :
                ($type == 7) ? "\xe2\x9c\x93" :
                ($type == 8) ? '?'            :
                ($type == 9) ? "\xe2\x98\xa0" : &GetFunCharacter();

    $text  = $text ? " ($text)" : q{};

    my $header = $type ? "$symb$text  " : q{};

    $head      = "$header$head";
    $body      = "\n\n$body" if $body;

    #  Format the indent
    #
    my $hindnt = $indnt < 0 ? sprintf('%s',q{ } x 1) : sprintf('%s',q{ } x $indnt);
    my $bindnt = sprintf('%s',q{ } x length "$hindnt$header");
    my $windnt = $type ? "   $hindnt" : $bindnt;

    local $| = 1;
    print "$leadnl";
    print wrap($hindnt,$windnt,$head);
    print wrap($bindnt,$bindnt,$body)   if $body;
    print "$trailnl";

return;
}


sub PrintMessageFile {
#==================================================================================
#  This routine prints all error, warning, and information statements to the
#  user with a consistent format.
#==================================================================================
#
use Text::Wrap;

    my %spaces = ();
       $spaces{X01X} = sprintf('%s',q{ } x 1);
       $spaces{X02X} = sprintf('%s',q{ } x 2);
       $spaces{X03X} = sprintf('%s',q{ } x 3);
       $spaces{X04X} = sprintf('%s',q{ } x 4);


    my ($fh,$type,$indnt,$cols,$leadnl,$trailnl,$head,$body,$text)  = @_;

    return unless defined $fh and $fh;

    #  Note Types:
    #
    #    0 = ''
    #    1 - "*"
    #    2 - "\xe2\x98\xba"  Smiley Face
    #    3 - "\xe2\x98\x85"  Black sun with rays
    #    4 - "dbg"
    #    5 - "->"
    #    6 - "!"
    #    7 - "\xe2\x9c\x93" Check Mark
    #    9 - "\xe2\x98\xa0" Skull & Crossbones

    #  Set defaults
    #
    local $Text::Wrap::columns = ($cols > 80) ? $cols : 80;  # sets the wrap point. Default is 80 columns.
    local $Text::Wrap::separator="\n";
    local $Text::Wrap::unexpand=0;  #  Was 1 - changed 3/2017

    my $nl = "\n";

    $head    = $nl unless $head;
    $indnt   = ! $indnt ? 0 : $indnt < 0 ? 0 : $indnt;
    $leadnl  = $leadnl  < 0 ? sprintf ("%s",$nl x 1) : sprintf ("%s",$nl x $leadnl);
    $trailnl = $trailnl < 0 ? sprintf ("%s",$nl x 1) : sprintf ("%s",$nl x $trailnl);

    #  Check for requested spaces as indicated by I\d\dX.
    #
    foreach my $nsp (keys %spaces) {
        $head =~ s/$nsp/$spaces{$nsp}/g if $head;
        $body =~ s/$nsp/$spaces{$nsp}/g if $body;
        $text =~ s/$nsp/$spaces{$nsp}/g if $text;
    }

    my $symb  = ($type == 0) ? q{}            :
                ($type == 1) ? '*'            :
                ($type == 2) ? "\xe2\x98\xba" :
                ($type == 3) ? "\xe2\x98\x85" :
                ($type == 4) ? 'dbg'          :
                ($type == 5) ? '->'           :
                ($type == 6) ? '!'            :
                ($type == 7) ? "\xe2\x9c\x93" :
                ($type == 8) ? '?'            :
                ($type == 9) ? "\xe2\x98\xa0" : &GetFunCharacter();


    $text  = $text ? " ($text)" : q{};

    #  Format the text
    #
    my $header = ($symb eq '*')     ? "$symb$text  " : 
                 ($symb eq '!')     ? "$symb$text  " : 
                 ($symb eq '->')    ? "$symb$text "  : 
                 ($symb =~ /dbg/)   ? "$symb$text: " : 
                 ($symb)            ? "$symb$text  " : q{};

    $head      = "$header$head";
    $body      = "\n\n$body" if $body;

    #  Format the indent
    #
    my $hindnt = $indnt < 0 ? sprintf('%s',q{ } x 1) : sprintf('%s',q{ } x $indnt);
    my $bindnt = sprintf('%s',q{ } x length "$hindnt$header");

    my $windnt = ($symb eq '*')     ? "   $hindnt"   : 
                 ($symb eq '->')    ? "  $hindnt"    : 
                 ($symb eq '!')     ? "   $hindnt"   : 
                 ($symb)            ? "   $hindnt"   : $bindnt;

    $| = 1;
    print $fh "$leadnl";
    print $fh wrap($hindnt,$windnt,$head);
    print $fh wrap($windnt,$windnt,$body)   if $body;
   #print $fh wrap($bindnt,$bindnt,$body)   if $body;
    print $fh "$trailnl";


return;
} #  PrintMessageFile


sub MissingLibraryTest {
#  ==================================================================================
#  This routine does a simple test for missing libraries on the local system
#  It does not do a compatibility check.
#  ==================================================================================
#
    my @libs=();
    my @bins=();
    my @list=();

    &PrintMessage(1,4,92,2,1,'Checking for missing system libraries needed to run the Domain Wizard GUI');

    push @bins =>"$UEMSinstall{UEMSHOME}/util/mpich/bin/mpiexec";
    @libs = &LibraryTest(@bins);

    if (@libs) {

        &PrintMessage(0,1,12,0,1,'Incompatible GLIBC Libraries');

        my $mesg = "Some of the MPICH executables provided with UEMS require GLIBC 2.17 (CentOS 7). The \n".
                   "switch to shared libraries in the current release was due to problems encountered \n".
                   "with the static binaries built with the current PGI C compiler. If you are running \n".
                   "an older version of GLIB C (RH 6, CentOS 6, probably anything with with a \"6\"), \n".
                   "you will have to implement the following workaround:\n\n".
  
                   "    a.  Install the packaged mpich release for your Linux distribution using \n".
                   "        \"apt-get\", \"yum\", \"yum-yum\", \"yummy-yum\", or whatever.\n\n".
  
                   "    b.  Then (as root) make a link from mpiexec.gf to mpiexec.gforker:\n\n".
  
                   "        # cd /usr/lib64/mpich/bin   (or wherever the system binaries reside)\n".
                   "        # ln -s mpiexec.gforker mpiexec.gf  (Because DWIZ looks for \"mpiexec.gf\")\n\n".
  
                   "    c.  Also, from the uems/util/mpich/ directory:\n\n".
  
                   "        % mv bin bin.uems\n".
                   "        % ln -s /usr/lib64/mpich/bin   (or wherever the system binaries reside)\n\n".

                   "    d.  Finally, specify the location of the MPICH installation:\n\n".

                   "          In EMS.cshrc:    setenv MPICH_HOME  /usr/lib64/mpich\n".
                   "        Or\n".
                   "          In EMS.profile:  MPICH_HOME=/usr/lib64/mpich; export MPICH_HOME\n\n".

                   "You should be good to go; however, prior to any updates, remove the link and move \n".
                   "bin.uems back to bin, just in case mpich is updated in the release.";

        &PrintMessage(0,1,12,0,1,'Incompatible GLIBC Libraries',$mesg);
    }


    @bins = ();
    $ENV{LD_LIBRARY_PATH} = "$UEMSinstall{UEMSHOME}/domwiz/libs/jre1.7.0_17.x64/lib/amd64:$UEMSinstall{UEMSHOME}/domwiz/libs/jre1.7.0_17.x64/lib/amd64/server";
    push @bins => "$UEMSinstall{UEMSHOME}/domwiz/libs/jre1.7.0_17.x64/bin/java";
    push @bins => "$UEMSinstall{UEMSHOME}/domwiz/libs/jre1.7.0_17.x64/lib/amd64/xawt/libmawt.so";

    &PrintMessage(5,9,92,1,0,'Checking Java libs -');
    @libs = &LibraryTest(@bins);

    if (@libs) {
        &PrintMessage(0,1,12,0,1,'Missing x64 System Libraries');
        &PrintMessage(0,10,144,1,0,$_) foreach @libs;

        my $str = 'x64 (64-bit) libs are normally located in the /usr/lib64';
        $mesg = "You will need to install the missing x64 system libraries on your machine before running ".
                "the Domain Wizard GUI. The $str directory.";

        &PrintMessage(6,7,92,2,2,$mesg);
        &PrintMessage(0,7,92,1,0,'You have some work to do before running dwiz [Ya, ya, I know] ');
        unless ($UEMSinstall{OPTION}{allyes}) {my $ans = <>; chomp $ans; $ans =~ s/\s+//g;}
        &PrintMessage(0,7,92,0,1,q{ });

    } else {
        &PrintMessage(0,1,12,0,2," All good!");
    }

    &PrintMessage(1,4,92,1,1,'Checking for missing system libraries needed for utility packages');


    &PrintMessage(5,9,92,1,0,'Checking NCVIEW routines  -');

    @bins = qw (ncview);
    foreach (@bins) {
        push @list => "$UEMSinstall{UEMSHOME}/util/ncview/bin/$_" if -e "$UEMSinstall{UEMSHOME}/util/ncview/bin/$_";
    }

    unless (@list) {
        &PrintMessage(0,1,12,0,1,' Failed');
        &PrintMessage(0,7,92,1,0,"Missing NCVIEW executable. Was there a problem with the installation?");
    }

    @libs = @list ? &LibraryTest(@list) : ();
    if (@libs) {
        &PrintMessage(0,1,12,0,1,'Missing System Libraries');
        &PrintMessage(0,10,92,1,0,$_) foreach @libs;
        $mesg = 'Not critical, but you will need to install the missing system libraries before using ncview.';
        &PrintMessage(6,7,92,2,2,$mesg);
    } else {
        &PrintMessage(0,1,12,0,0," All good!");
    }


    &PrintMessage(5,9,92,1,0,'Checking GrADS routines   -');

    @bins = qw (bufrscan grads grib2scan gribmap gribscan gxeps gxps gxtran stnmap);
    @list=();
    foreach (@bins) {
        push @list => "$UEMSinstall{UEMSHOME}/util/grads/bin/$_" if -e "$UEMSinstall{UEMSHOME}/util/grads/bin/$_";
    }

    unless (@list) {
        &PrintMessage(0,1,12,0,1,' Failed');
        &PrintMessage(0,7,92,1,0,'Missing GrADS executables. Was there a problem with the installation?');
    }

    @libs = @list ? &LibraryTest(@list) : ();
    if (@libs) {
        &PrintMessage(0,1,12,0,1,'Missing System Libraries');
        &PrintMessage(0,10,92,1,0,$_) foreach @libs;
        $mesg = 'Not critical, but you will need to install the missing system libraries before using GrADS routines.';
        &PrintMessage(6,7,92,2,2,$mesg);
    } else {
        &PrintMessage(0,1,12,0,0," All good!");
    }


    &PrintMessage(5,9,92,1,0,'Checking GEMPAK routines  -');

    @bins = qw (dcgrib2 nagrib gdcntr gdmap gdlist gdplot3 gdplot_gf nmap2 ncolor h5dump xw);
    @list=();
    foreach (@bins) {
        push @list => "$UEMSinstall{UEMSHOME}/util/nawips/os/linux/bin/$_" if -e "$UEMSinstall{UEMSHOME}/util/nawips/os/linux/bin/$_";
    }

    @libs = @list ? &LibraryTest(@list) : ();
    if (@libs) {
        &PrintMessage(0,1,12,0,1,'Missing System Libraries');
        &PrintMessage(0,10,92,1,0,$_) foreach @libs;
        $mesg = 'Not critical, but you will need to install the missing system libraries before using NAWIPS/GEMPAK routines.';
        &PrintMessage(6,7,92,2,2,$mesg);
    } else {
        &PrintMessage(0,1,12,0,1," All good!");
    }


return;
}


sub LibraryTest {
#  ==================================================================================
#   This routine accepts a list of dynamic binary routines and an returns
#   a list of missing libraries on the system.
#  ==================================================================================
#
   my @libs = ();
   my @routines = @_;  return () unless @routines;

   my $ldd  = &LocateX('ldd');
   my $file = &LocateX('file');

   return () unless $ldd;

   foreach (@routines) {
      next unless $_;
      my $type = (grep {/ELF 64-bit/i} `$file $_`) ? '64-bit' : (grep {/ELF 32-bit/i} `$file $_`) ? '32-bit' : 'Unknown';
      foreach (grep {/not found/i} `$ldd $_ 2>&1`) {
          chomp; s/\s//g;
          my @list = split /=/ => $_;
          push @libs => "$type $list[0]";
      }
   }
   @libs = &rmdups(@libs);

return @libs;
}


sub LocateX {
#---------------------------------------------------------------------------------
#  Routine to locate a Linux utility on the system
#---------------------------------------------------------------------------------
#
    my $rutil = shift; my $util = `which $rutil`; chomp $util;

    unless (-s $util and -x $util) {
        $util = `whereis $rutil`; chomp $util; if ($util) {my @util = split / / => $util; $util = $#util ? $util[1] : 0;}
        $util = (-s "/usr/bin/$rutil") ? "/usr/bin/$rutil" : (-s "/bin/$rutil") ? "/bin/$rutil" : 0 unless -s $util;
    }

return $util ? $util : 0;
}


sub mkdir {
#---------------------------------------------------------------------------------
#   Creates a specified directory
#---------------------------------------------------------------------------------
#
    my $dir    = shift;

return (-d $dir) ? 0 : system "mkdir -m 755 -p $dir > /dev/null 2>&1";
}


sub popit2 {
#----------------------------------------------------------------------------------
#  This routine accepts the fully qualified path/name and returns both
#  the name of the file and the path.
#----------------------------------------------------------------------------------
#
    for (shift) {
        s/\^.//g;
        my @list = split /\// => $_;
        my $prog = pop @list;
        my $path = join "/" => @list;
        return $path, $prog;
    }
}


sub popit {
#----------------------------------------------------------------------------------
#  This routine accepts the fully qualified path/name and returns just
#  the name of the file or what ever was at the end if the string.
#----------------------------------------------------------------------------------
#
    my $path = shift;
    $path =~ s/\^.//g;
    my @list = split /\// => $path;

return pop @list;
}


sub rmdups {
#----------------------------------------------------------------------------------
#  Eliminate duplicates from a list
#----------------------------------------------------------------------------------
#
    my @list = ();
    my %temp = ();

    foreach (@_) {push @list => $_ if defined $_;}
    return @list unless @list;

    @list = grep ++$temp{$_} < 2 => @list;

return @list;
}


sub rm {
#---------------------------------------------------------------------------------
#   Deletes the specified file or directory
#---------------------------------------------------------------------------------
#
    my $status = 0;

    for (shift) {
        if    (-d)       { $status = system "rm -fr $_"; }
        elsif (-f or -l) { $status = system "rm -f $_";  }
    }

return $status
}


sub SysIntHandle {
#  ==================================================================================
#  Determines what to do following an interrupt signal or control-C.
#  ==================================================================================
#
    if ($UEMSinstall{EMSPRV} and -e $UEMSinstall{EMSPRV} and !$UEMSinstall{OPTION}{continue}) {

       &PrintMessage(0,4,96,3,1,"Ouch! - Aren't we a bit sensitive?! Let's do this again sometime very soon!");
       &PrintMessage(0,4,96,1,3,"I'm Putting stuff back the way I found it - YOU HOPE!");

       my $failed = "$UEMSinstall{UEMSHOME}.aborted_install"  ; &rm($failed);

       system "mv $UEMSinstall{UEMSHOME} $failed > /dev/null 2>&1"; &rm($UEMSinstall{UEMSHOME});
       system "mv $UEMSinstall{EMSPRV} $UEMSinstall{UEMSHOME} > /dev/null 2>&1";

    } else {
       &PrintMessage(0,4,96,3,3,"Ouch! - Aren't we a bit sensitive?! Let's do this again sometime very soon!");
    }


CORE::exit 2;
}


sub SysReturnHandler {
#  ==================================================================================
#  This routine handles the return values from the various ems_install subroutines.
#  and determines whether to send email to specifies users in the event of a failure.
#
#  Simply return 0 if there was not a problem.
#  ==================================================================================
#
    my $oath=0;
    my $mesg=q{}; #  Need a local variable since &PrintOath will overwrite value

    my $ret = shift; $ret = 0 unless $ret;

    return if $ret < 0;

    my $res = $ret > 0 ? 'Incomplete' : 'Complete';

    if ($UEMSinstall{OPTION}{list}) {
        my $req = $UEMSinstall{OPTION}{update} ? 'Update' : 'Release';
        my $cmd = $ret ==-1 ? 'That\'s all I got to say on this matter' :
                  $ret == 1 ? 'Now go forth and fix the problem!' :
                  $ret == 2 ? 'Now go forth and Update!'          :
                  $ret == 3 ? 'Now go forth and Install the EMS!'          :
                  'Now go forth and simulate!';
        $mesg = sprintf("%s Listing %s - %s",$req,'Complete',$cmd);
    } else {
        my $req;
        my $cmd;
        if ($UEMSinstall{OPTION}{nounpack}) {
            $req = $UEMSinstall{OPTION}{update} ? 'Update Download' : $UEMSinstall{OPTION}{install} ? 'Release Download' : 'Request';
            $cmd = ($ret > 0) ? 'Now go forth and fix the problem!' : 'Now go forth and install!';
        } else {
            $req = $UEMSinstall{OPTION}{update} ? 'Update' : $UEMSinstall{OPTION}{install} ? 'Installation' : 'Request';
            $cmd = ($ret > 0) ? 'Now go forth and fix the problem!' : 'Now go forth and simulate!';
            $oath = 1 if $UEMSinstall{OPTION}{install} and %{$UEMSinstall{RELEASES}} and $ret == 0;
        }
        $mesg = sprintf("Your %s is %s - %s",$req,$res,$cmd);
    }

    &PrintOath() if $oath;

    &PrintMessage(0,4,96,2,2,$mesg);

    &PrintMessage(0,2,114,1,3,"As Homer Would Say:  \"Here's to the UEMS, the cause of, and solution to, all life's problems!\"");


CORE::exit 0;
}


sub SysExecute {
#=================================================================================
#  This routine uses the Perl "exec" routine to run the passed command and 
#  then interpret and return the exit status.
#=================================================================================
#
    #  Override interrupt handler - Use the local one since some of the local
    #  environment variables are needed for clean-up after the interrupt.
    #
    $SIG{INT} = \&SysIntHandle;  $|=1;

    my ($prog, $log) = @_;

    my $cmd = $log ? "$prog > $log 2>&1" : $prog;

    my $pid = fork;

    exec $cmd unless $pid; 

    #  The $rc = $? >> 8 is needed for waitpid
    #
    my $we = waitpid($pid,0); my $rc = $? >> 8; $we = 0 if $we == $pid; 

       $rc = 256 if $we and ! $rc;

return $rc;
} #  SysExecute



sub SysDied {
#  ==================================================================================
#  This routine handles some of the failure messages from the secondary routines.
#  ==================================================================================
#
    my ($mesg, $im) = @_;  $im = 1 unless defined $im;

    $mesg = 'Something died do to developer (or user) incompetence - again!' unless $mesg;
    $mesg =~ s/^\s+$//g;

    if ($mesg) {$im ? &PrintInspiration($mesg) : &PrintMessage(9,4,96,1,2,$mesg);}

    &PrintMessage(2,4,96,1,3,sprintf('Our relationship is off to a rocky start. I need %s!',&GetDesire()));

CORE::exit 1;
}


