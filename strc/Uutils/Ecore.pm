#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Ecore.pm
#
#  DESCRIPTION:  Ecore contains the routines 
#
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Ecore;

use warnings;
use strict;
require 5.008;
use English;

use Ecomm;
use Elove;
use Others;



sub DefineExitCodes {
#=================================================================================
#  Initialize an array of Standard system exit codes
#=================================================================================
#
    my @exits = ('Unknown Cause') x 256;

       $exits[0]   = 'Normal Exit';
       $exits[1]   = 'General Error';
       $exits[2]   = 'Incorrect Shell Command Usage';

       $exits[64]  = 'Command Line Usage Error';
       $exits[65]  = 'Data Format Error';
       $exits[66]  = 'Cannot Open Input';
       $exits[67]  = 'Addressee Unknown';
       $exits[68]  = 'Host Name Unknown';
       $exits[69]  = 'Service Unavailable';
       $exits[70]  = 'Internal Software Error';
       $exits[71]  = 'System Error (e.g., Cannot Fork)';
       $exits[72]  = 'Critical OS File Missing';
       $exits[73]  = 'Cannot Create (user) Output File';
       $exits[74]  = 'Input/Output Error';
       $exits[75]  = 'Temporary Failure; User is Invited to Retry';
       $exits[76]  = 'Remote Error in Protocol';
       $exits[77]  = 'Permission Denied';
       $exits[78]  = 'Configuration Error';

       $exits[126] = 'Command Cannot be Executed';
       $exits[127] = 'Command Not Found';

return @exits;
}  #  DefineExitCodes



sub DefineSignalCodes {
#=================================================================================
#  Initialize an array of SIG return codes
#=================================================================================
#
    my @sigs     = ('Unknown Signal') x 256;

       $sigs[0]  = 'Normal Exit';
       $sigs[1]  = 'Death of Controlling Process or Hangup';
       $sigs[2]  = 'Terminal Interrupt';
       $sigs[3]  = 'Terminal Quit',
       $sigs[4]  = 'Illegal Instruction';
       $sigs[5]  = 'Trace Trap';
       $sigs[6]  = 'Abort Signal';
       $sigs[7]  = 'BUS error';
       $sigs[8]  = 'Floating Point Exception';
       $sigs[9]  = 'Kill signal';
       $sigs[11] = 'Invalid Memory Reference - Seg Fault';
       $sigs[13] = 'Broken Pipe';
       $sigs[14] = 'Timer Signal from Alarm(2)';
       $sigs[15] = 'Termination signal';
       $sigs[16] = 'Stack Fault';

       $sigs[$_] = 'User-Defined Signal 1'                  for qw(30 10 16);
       $sigs[$_] = 'User-Defined Signal 2'                  for qw(31 12 17);
       $sigs[$_] = 'Child Process Stopped or Terminated'    for qw(20 17 18);
       $sigs[$_] = 'Stop Process'                           for qw(17 19 23);
       $sigs[$_] = 'Stop Typed at Terminal'                 for qw(18 20 24);
       $sigs[$_] = 'Terminal Input for Background Process'  for qw(21 26);
       $sigs[$_] = 'Terminal Output for Background Process' for qw(22 27);

       $sigs[126]= 'Permission Problem or Command is Not an Executable';
       $sigs[127]= 'Command or File Not Found';
       $sigs[128]= 'Invalid Argument to Exit, What Ever That Means';

       $sigs[256]= 'That Didn\'t Turn Out as Planned';
       
return @sigs;
} #  DefineSignalCodes



sub SysInitialize {
#==================================================================================
#  Define & assign some of the commonly used variables and information. An 
#  optional hash reference may be passed; otherwise a new %Uinit hash is
#  initialized and used.  The choice is yours, be it.
#==================================================================================
#
use Cwd;

    my %Uinit = ();

    my $upref  = shift; %Uinit  = %{$upref} if $upref;

    unless (defined $ENV{UEMS} and $ENV{UEMS} and -e $ENV{UEMS}) {
        print '\n\n    !  The UEMS environment is not properly set - EXIT\n\n';
        return ();
    }


    my $CWD            = cwd; chomp $CWD;
    my $DATE           = gmtime; chomp $DATE; $DATE = "$DATE UTC";
    my $LDAT           = `date`; chomp $LDAT; $LDAT =~ s/\s+/_/g;
    my $EXE            = &Others::popit($0);

    #  ----------------------------------------------------------------------------------
    #  Set default language to English because the UEMS attempts to match English
    #  words when attempting to get system information.
    #  ----------------------------------------------------------------------------------
    #
    $ENV{LC_ALL}       = 'C';
    $ENV{EMSEXE}       = $EXE;

    $Uinit{MC}         = 0;  #  Mission Control flag - Set to 1 by MC

    $Uinit{CWD}        = $CWD;
    $Uinit{DATE}       = $DATE;        #  The current system date and time
    $Uinit{LDAT}       = $LDAT;
    $Uinit{EXE}        = $ENV{EMSEXE}; 
    $Uinit{UBIN}       = Cwd::realpath($ENV{STRC_BIN});

    $Uinit{YYMMDD}     = `date -u +%y%m%d`;   chomp $Uinit{YYMMDD};
    $Uinit{YYYYMMDD}   = `date -u +%Y%m%d`;   chomp $Uinit{YYYYMMDD};
    $Uinit{YYYYMMDDHH} = `date -u +%Y%m%d%H`; chomp $Uinit{YYYYMMDDHH};

    $Uinit{UEMSVER}    = &Elove::GetUEMSrelease($ENV{UEMS});
    $Uinit{UEMSWRF}    = &Elove::GetWRFrelease($ENV{UEMS});
    $Uinit{VERSION}    = "$Uinit{UEMSVER} ($Uinit{UEMSWRF})";

    $Uinit{AUTORUN}    = ( ($EXE =~ /autorun/i) and (defined $ENV{UEMSPID}) and $ENV{UEMSPID} ) ? $ENV{UEMSPID} : 0;

    $ENV{UEMSPID}      = $Uinit{AUTORUN} ? $Uinit{AUTORUN} : 0;

    %{$Uinit{SYSINFO}} = &Others::SystemInformation();
    %{$Uinit{IUSER}}   = &Others::SystemUserInfo($<);    #  Get information about the installer

    $Uinit{BENCH}      = -e "$Uinit{CWD}/static/.benchmark";


return %Uinit;
}


sub SysExecute {
#=================================================================================
#  This routine uses the Perl "exec" routine to run the passed command and 
#  then interpret and return the exit status.
#=================================================================================
#
    $ENV{EMSERR} = 0;

    #  Override interrupt handler - Use the local one since some of the local
    #  environment variables are needed for clean-up after the interrupt.
    #
    $SIG{INT} = \&Ecore::SysIntHandle;  $|=1;

    my ($prog, $log) = @_;

    my $cmd = $log ? "$prog > $log 2>&1" : $prog;

    my $pid = fork;

    exec $cmd unless $pid; 

    #  The $rc = $? >> 8 is needed for waitpid
    #
    my $we = waitpid($pid,0); my $rc = $? >> 8; $we = 0 if $we == $pid; 

       $rc = 256 if $we and ! $rc;
       $rc = 2 if $ENV{EMSERR} == 2;
       
return $rc;
} #  SysExecute



sub SysReturnCode {
#=================================================================================
#  Attempt to explain the exit code returned from a failed routine
#
#  The return value is the exit status of the program as returned through
#  the wait(2) syscall. Under traditional semantics, to get the real exit
#  value, divide by 256 or shift right by 8 bits. That's because the lower
#  byte has something else in it. (Two somethings, really.) The lowest
#  seven bits indicate the signal number that killed the process (if any),
#  and the eighth bit indicates whether the process dumped core. You can
#  check all possible failure possibilities, including signals and core
#  dumps.
#
#  Note exit values:
#
#    exit_value  - $? >> 8
#    signal_num  - $? & 127
#    dumped_core - $? & 128
#    Everything is coming up roses - 0
#=================================================================================
#
    my $rc = shift; return 0 unless $rc;

    my $mesg    = '';
    my @signals = &DefineSignalCodes();
    my @exits   = &DefineExitCodes();

    # The return code is in the high 8 bits and is obtained via an 8-bit right shift
    # 

    # The low 8 bits are system dependent and contain the signal number that 
    # killed the process, such as ^C (2)
    #
    my $ec = $rc >> 8;              #  Actual return code
    my $cd = $rc & 128 ? 1 : 0;     #  1|0 (Yes|No) for core dump
    my $sn = $rc & 127;             #  Signal Number that killed the process

    return 2 if $sn == 2;           #  Killed by ^C

    my $ss = $signals[$sn];
    my $es = $exits[$ec];

    if ($rc) {
       #&Ecomm::PrintMessage(0,0,44,0,1,"Process Return Code(RC) : $rc");

       $mesg = ($sn and $ec) ? "System Signal : $sn ($ss) & Command Exit : $ec ($es)"  :
                    $sn      ? "System Signal Code (SN) : $sn ($ss)"                   :
                               "Command Exit Code  (EC) : $ec ($es)";
    }


return $mesg;
} #  SysReturnCode


sub SysIntHandle {
#==================================================================================
#  Determines what to do following an interrupt signal or control-C.
#==================================================================================
#
    $ENV{VERBOSE} = 1;  #  Set to verbose mode regardless of what the user wanted
    $ENV{EMSERR}  = 1 unless defined $ENV{EMSERR} and $ENV{EMSERR};  #  Need a value here

    my $program   = (defined $ENV{EMSEXE} and $ENV{EMSEXE}) ? $ENV{EMSEXE} : 'Unknown UEMS';

    #my ($package, $filename, $line, $subr, $has_args, $wantarray)= caller(0);
    #print "EXIT CALLER 0: ($package, $filename, $line, $subr, $has_args)\n";

    #  What and how much to clean up is determined by the routine being run
    #  at the time of the ^C.
    #
    my $lev=1;
    my $sft=7;
    my $pdl=2;
    my $noc=0; # Default 0 - set to 1 if ems_clean is not to be run

    for ($program) {
        if (/auto/i)     {$lev=3;$sft=7;$pdl=2;}
        if (/prep/i)     {$lev=3;$sft=9;$pdl=2;}
        if (/info/i)     {$lev=3;$sft=9;$pdl=2;$noc=1;}  #  Covers sysinfo & runinfo
        if (/grib2/i)    {$lev=3;$sft=9;$pdl=2;$noc=1;}  #  Covers grib2awips & grib2cdf
        if (/gribnav/i)  {$lev=3;$sft=9;$pdl=2;$noc=1;}  
        if (/benchtest/i){$lev=3;$sft=9;$pdl=2;$noc=1;}
        if (/mpicheck/i) {$lev=3;$sft=9;$pdl=2;$noc=1;}
        if (/run/i )     {$lev=1;$sft=7;}
        if (/post/i)     {$lev=0;$sft=7;$pdl=2;}
        if (/domain/i)   {$lev=3;$sft=9;$pdl=2;}
    }

    my @heys = ("Terminated!? Me? - But I was just getting this $program party started!",
                'Hey, I thought we were a team!',
                'You know, it would be a shame if something happened to your keyboard.',
                'I think you did that with a bit too much enthusiasm!',
                'I hope you enjoyed yourself!',
                'I hope this hurts you more than it hurts me!',
                'Wow, you have such strong digits!',
                'And I was just beginning to like you!');

    $ENV{EMSERR} == 2 ? &Ecomm::PrintMessage(6,$sft,96,1,1,"Hey, just wait a moment while I finish my business!!") :
                        &Ecomm::PrintMessage(2,$sft,96,$pdl,1,sprintf "$heys[int rand scalar @heys]");

    $ENV{EMSERR} = 2;  #  Set the EMS return error so that the files can be processed correctly.

    return if $program =~ /ems_run/i;

    #  Attempt to clean up the mess that was left
    #
    unless ($ENV{EMS_RUN} eq $ENV{RUN_BASE}) {  #  In which case $EMS_RUN was not redefined
        &Eclean::CleanDriver('--domain',$ENV{EMS_RUN},'--level',$lev,'--silent') unless $noc;
    }

    
    #  Some additional tasks required depending upon the routine
    #
    &Others::rm($ENV{AUTOLOCK}) if $program =~ /_autorun/i and defined $ENV{AUTOLOCK};

    sleep 3;  #  As a precaution


&SysExit(2);
} #  SysIntHandle


sub SysDied {
#==================================================================================
#  Used instead of the Perl "die", this routine will hopefully allow for a more
#  graceful exit. This routine takes as arguments a message string that is printed
#  and the name of the calling routine. It prints the message and then either
#  returns to the calling program or exists depending upon the value of $ret.
#
#  CALL:   &Ecore::SysDied(ret(1=yes|0=no),mesg1,mesg2)
#==================================================================================
#
    #  Override the user verbose setting
    #
    $ENV{VERBOSE} = 1;
    $ENV{EMSERR}  = 1;

    #  Note that the return variable is first
    #
    my ($ret,$mesg0,$mesg1) = @_; $mesg0 = $mesg1 if $mesg1 and !$mesg0;

    #my ($package, $filename, $line, $subr, $has_args, $wantarray)= caller(0);
    #print "DIED CALLER 0: ($package, $filename, $line, $subr, $has_args)\n";

    $ret   = $ret ?  1 : 0;
    $mesg0 = 'Something died in the pursuit of science - Again!' unless $mesg0;

    &Ecomm::PrintMessage(9,4,256,2,1,$mesg0,$mesg1);

    #  Some additional tasks required depending upon the routine
    #
    &Others::rm($ENV{AUTOLOCK}) if defined $ENV{AUTOLOCK};


    return if $ret;


&SysExit(-99);
} #  SysDied


sub SysExit {
#==================================================================================
#  Override the default behavior and prints out a semi-informative message
#  when exiting. The routine takes three arguments, only one of which is
#  mandatory ($err) with $rout (recommended) identifying the calling routine
#  and $mesg, which serves to override the prescribed messages.
#==================================================================================
#
    #  Modified to get rid of Perl version issues with switch statement.
    #
    $ENV{VERBOSE} = 1;  #  Set to verbose mode regardless of what the user wanted

    my $uc   = 0;
    my $spc  = 1;
    my $date = gmtime;
    my $secs = `date +%S`; chomp $secs; 
    my $slog = '"Think Globally, Model Locally!"';

     
    my ($err, $rout, $mesg) = @_;

    #my ($package, $filename, $line, $subr, $has_args, $wantarray)= caller(0);
    #print "EXIT CALLER 0: ($package, $filename, $line, $subr, $has_args)\n";

    $err  = defined $err  ? $err  : defined $ENV{EMSERR} ? $ENV{EMSERR} : 0;
    $rout = defined $rout ? $rout : (defined $ENV{EMSEXE} and $ENV{EMSEXE}) ? $ENV{EMSEXE} : 'Unknown UEMS'; $rout = &Others::popit($rout);
    $mesg = defined $mesg ? $mesg : sprintf ("There shall be no UEMS gruven for you on %s UTC",$date);

    my @whos = ('As the UEMS Genie says',
                'Mark Twain wished he had said',
                'The UEMS Metaphysician says',
                'The scribbling on my doctors prescription actually reads',
                'As the alchemists at Cambridge are fond of stating',
                'Michelangelo\'s hidden secret code in Sistine Chapel reads',
                'Alexander Graham Bell\'s first words on the telephone really were',
                'A little known tenet of Confucianism is',
                'The deciphered Voynich manuscript actually reads',
                'You can sometimes hear Tibetan Monks chant',
                'As Shields and Yarnell loved to gesticulate',
                'The very first message detected by SETI will be',
                'Smoke signals from the Vatican are often interpreted as',
                'Neil Armstrong\'s microphone cut out just before he said',
                'Alphanumeric code 6EQUJ5 will someday be interpreted as'
                );

    my @dicks = ('Playing Hercule Poirot I see. Very well then, carry on.',
                 'Playing Lieutenant Columbo I see. I hope that explains the trench coat.');


    #  Define a better routine name description than the one that is passed
    #
    for ($rout) {
        $_ = 'UEMS Grib2Awips'       if /grib2awip/i;
        $_ = 'UEMS Post'             if /_post/i;
        $_ = 'UEMS Simulation'       if /_run/i;
        $_ = 'UEMS Run Information'  if /info/i;
        $_ = 'UEMS Grib Information' if /gribnav/i;
        $_ = 'UEMS sysinfo'          if /sysinfo/i;
        $_ = 'UEMS mpicheck'         if /mpicheck/i;
        $_ = 'UEMS Prep'             if /_prep/i;
        $_ = 'UEMS AutoPost'         if /_autopost/i;
        $_ = 'UEMS AutoRun'          if /_autorun/i;
        $_ = 'UEMS Domain'           if /domain/i;
        $_ = 'UEMS Benchmark'        if /benchtest/i;
        $_ = 'UEMS Cleaning'         if /clean/i;
    }


    #  Some additional tasks required depending upon the routine
    #
    &Others::rm($ENV{AUTOLOCK}) if $rout eq 'UEMS AutoRun' and defined $ENV{AUTOLOCK};

    #  If a message was passed then the value of $err must not match one below; otherwise it will
    #  be overridden.
    #
    if ($err == -99) {$mesg = $secs % 2 ? sprintf "$whos[int rand scalar @whos]: \"If in doubt, blame it on the tool!\"" 
                                       : sprintf "$whos[int rand scalar @whos]: \"If in doubt, blame it on the user!\"" ;$spc=3;}
    if ($err == -6) {$mesg = sprintf "\"Try it before you buy it\" is always a good plan.";}
    if ($err == -5) {$mesg = sprintf "Let's Go!  Less talk, more action!";}
    if ($err == -4) {$mesg = sprintf "Your UEMS information mining is complete";}
    if ($err == -3) {$mesg = sprintf "Practicing \"Leave no trace\" I see. It's always good to cover your tracks!";$uc=0;}
    if ($err == -2) {$mesg = sprintf "$whos[int rand scalar @whos]: \"What about all MY #?&^@ wishes?!\"";$spc=3;}
    if ($err == -1) {$mesg = sprintf "Let's get this $rout party started!";}
    if ($err ==  0) {$mesg = sprintf "Your awesome $rout party is complete - %s UTC",$date;}
    if ($err ==  1) {$mesg = sprintf "Your $rout party was busted at %s UTC - Ya know, 'cause stuff just happens",$date;}
    if ($err ==  2) {$mesg = sprintf "This UEMS buzz was killed by Grumpy on %s UTC",$date;}
    if ($err == 10) {$mesg = sprintf "And remember to always love your data, because it will love you back"; $uc=2;}
    if ($err == 98) {$mesg = sprintf "$dicks[int rand scalar @dicks]";}
    if ($err == 99) {$mesg = sprintf "There shall be no UEMS gruven for you on %s UTC",$date;}
    if ($err ==100) {$mesg = sprintf "$whos[int rand scalar @whos]: $slog";$spc=3;}
    if ($err ==101) {$mesg = qw{};$spc=0;$uc=0;}


    &Ecomm::PrintMessage($uc,4,144,2,$spc,$mesg) if $mesg;

    &Ecomm::PrintMessage(0,2,144,1,3,sprintf "$whos[int rand scalar @whos]: $slog") unless ($err == -99 or $err == 100 or $err == -2);


CORE::exit $err;
} 



sub RsyncExitCodes {
#=================================================================================
# Initialize an array of Standard Rsync exit codes. This routine is only
# for information purposes and should not be called unless Rsync returns
# a non-zero value, so ignore the $_ == 0 condition.
#================================================================================= i
#
 
    my $mesg = 'Unknown Error';

    for (shift) {

        if (/^0$/)  {$mesg =  '';}
        if (/^1$/)  {$mesg =  'Syntax or usage error';}
        if (/^2$/)  {$mesg =  'Protocol incompatibility';}
        if (/^3$/)  {$mesg =  'Errors selecting input/output files, dirs';}
        if (/^4$/)  {$mesg =  'Requested action not supported';}
        if (/^5$/)  {$mesg =  'Error starting client-server protocol';}
        if (/^6$/)  {$mesg =  'Daemon unable to append to log-file';}
        if (/^10$/) {$mesg =  'Error in socket I/O';}
        if (/^11$/) {$mesg =  'Error in file I/O';}
        if (/^12$/) {$mesg =  'Error in rsync protocol data stream';}
        if (/^13$/) {$mesg =  'Errors with program diagnostics';}
        if (/^14$/) {$mesg =  'Error in IPC code';}
        if (/^20$/) {$mesg =  'Received SIGUSR1 or SIGINT';}
        if (/^21$/) {$mesg =  'Some error returned by waitpid';}
        if (/^22$/) {$mesg =  'Error allocating core memory buffers';}
        if (/^23$/) {$mesg =  'File or directory not found';} #  Could also be "Failed to change directories" (permission)
        if (/^24$/) {$mesg =  'Partial transfer due to vanished files';}
        if (/^25$/) {$mesg =  'The --max-delete limit stopped deletions';}
        if (/^30$/) {$mesg =  'Timeout in data send/receive';}
        if (/^35$/) {$mesg =  'Timeout waiting for daemon connection';}
    }


return $mesg;
} #  RsyncExitCodes


sub CurlExitCodes {
#=================================================================================
# Initialize an array of Standard Curl exit codes. This routine is only
# for information purposes and should not be called unless Curl returns
# a non-zero value, so ignore the $_ == 0 condition.
#=================================================================================
#
    my $mesg = 'Unknown Error';

    for (shift) {

        if (/^0$/)  {$mesg =  '';}
        if (/^1$/)  {$mesg =  'Unsupported protocol';}
        if (/^2$/)  {$mesg =  'Failed to initialize';}
        if (/^3$/)  {$mesg =  'URL malformat. The syntax was not correct';}
        if (/^4$/)  {$mesg =  'URL user malformatted';}
        if (/^5$/)  {$mesg =  'Couldn’t resolve proxy';}
        if (/^6$/)  {$mesg =  'Couldn’t resolve host';}
        if (/^7$/)  {$mesg =  'Failed to connect to host';}
        if (/^8$/)  {$mesg =  'FTP weird server reply';}
        if (/^9$/)  {$mesg =  'FTP access denied';}
        if (/^10$/) {$mesg =  'FTP user/password incorrect';}
        if (/^11$/) {$mesg =  'FTP weird PASS reply';}
        if (/^12$/) {$mesg =  'FTP weird USER reply';}
        if (/^13$/) {$mesg =  'FTP weird PASV reply';}
        if (/^14$/) {$mesg =  'FTP weird line 227 format';}
        if (/^15$/) {$mesg =  'FTP can’t get host IP';}
        if (/^16$/) {$mesg =  'FTP can’t reconnect';}
        if (/^17$/) {$mesg =  'FTP couldn’t set binary';}
        if (/^18$/) {$mesg =  'Only a part of the file was transfered';}
        if (/^19$/) {$mesg =  'FTP couldn’t download/access the given file';}
        if (/^20$/) {$mesg =  'FTP write error';}
        if (/^21$/) {$mesg =  'FTP quote error';}
        if (/^22$/) {$mesg =  'Requested file was not found';}
        if (/^23$/) {$mesg =  'Local write error';}
        if (/^24$/) {$mesg =  'User name badly specified';}
        if (/^25$/) {$mesg =  'FTP couldn’t STOR file';}
        if (/^26$/) {$mesg =  'Read error';}
        if (/^27$/) {$mesg =  'Out of memory';}
        if (/^28$/) {$mesg =  'Operation timeout';}
        if (/^29$/) {$mesg =  'FTP couldn’t set ASCII';}
        if (/^30$/) {$mesg =  'FTP PORT failed';}
        if (/^31$/) {$mesg =  'FTP couldn’t use REST';}
        if (/^32$/) {$mesg =  'FTP couldn’t use SIZE';}
        if (/^33$/) {$mesg =  'HTTP range error';}
        if (/^34$/) {$mesg =  'HTTP post error';}
        if (/^35$/) {$mesg =  'SSL handshaking failed';}
        if (/^36$/) {$mesg =  'FTP bad download resume';}
        if (/^37$/) {$mesg =  'FILE couldn’t read file. Permissions?';}
        if (/^38$/) {$mesg =  'LDAP bind operation failed';}
        if (/^39$/) {$mesg =  'LDAP search failed';}
        if (/^40$/) {$mesg =  'The LDAP library was not found';}
        if (/^41$/) {$mesg =  'A required LDAP function was not found';}
        if (/^42$/) {$mesg =  'An application told curl to abort the operation';}
        if (/^43$/) {$mesg =  'A function was called with a bad parameter';}
        if (/^44$/) {$mesg =  'A function was called in a bad order';}
        if (/^45$/) {$mesg =  'A specified outgoing interface could not be used';}
        if (/^46$/) {$mesg =  'Bad password entered';}
        if (/^47$/) {$mesg =  'Too many redirects';}
        if (/^48$/) {$mesg =  'Unknown TELNET option specified';}
        if (/^49$/) {$mesg =  'Malformed telnet option';}
        if (/^52$/) {$mesg =  'The server didn’t reply anything';}
        if (/^53$/) {$mesg =  'SSL crypto engine not found';}
        if (/^54$/) {$mesg =  'Cannot set SSL crypto engine as default';}
        if (/^55$/) {$mesg =  'Failed sending network data';}
        if (/^56$/) {$mesg =  'Failure in receiving network data';}
        if (/^57$/) {$mesg =  'Share is in use (internal error)';}
        if (/^58$/) {$mesg =  'Problem with the local certificate';}
        if (/^59$/) {$mesg =  'Couldn’t use specified SSL cipher';}
        if (/^60$/) {$mesg =  'Problem with the CA cert (permission?)';}
        if (/^61$/) {$mesg =  'Unrecognized transfer encoding';}
        if (/^62$/) {$mesg =  'Invalid LDAP URL';}
        if (/^63$/) {$mesg =  'Maximum file size exceeded';}
    }


return $mesg;
} #  CurlExitCodes


sub WgetExitCodes {
#=================================================================================
#  Initialize an array of Standard wget exit codes. This routine is only
#  for information purposes and should not be called unless wget returns
#  a non-zero value, so ignore the $_ == 0 condition.
#=================================================================================
#
    my $mesg = 'Unknown Cause';

    for (shift) {

       $mesg = ''                    if $_ == 0;
       $mesg = 'General Error'       if $_ == 1;
       $mesg = 'Parse error'         if $_ == 2;
       $mesg = 'File I/O Error'      if $_ == 3;
       $mesg = 'Network Failure'     if $_ == 4;
       $mesg = 'SSL verification failure' if $_ == 5;
       $mesg = 'Username/password authentication failure' if $_ == 6;
       $mesg = 'Protocol Errors'     if $_ == 7;
       $mesg = 'Server-issued Error' if $_ == 8;

    }

return $mesg;
}  #  WgetExitCodes


