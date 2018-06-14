#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Ecomm.pm
#
#  DESCRIPTION:  Ecomm contains subroutines used in communicating information
#                to the user.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Ecomm;

use warnings;
use strict;
require 5.008;
use English;


sub PrintMessage {
#==================================================================================
#  This routine manages all the messages being issues by the UEMS.  The arguments
#  are similar to those used when calling uemsPrint routines - for now.
#==================================================================================
#
    my ($sym,$ind,$wth,$lnl,$tnl,$msg1,$msg2,$opt,$lfh) = @_; return unless $msg1;
     
    $msg2 = '' unless defined $msg2 and $msg2;
    $opt  = '' unless defined $opt  and $opt;
    $lfh  = 0  unless defined $lfh  and $lfh;
    


    #------------------------------------------------------------------------
    #  The PrintTerminal simply prints to the screen.
    #------------------------------------------------------------------------
    #
    &PrintTerminal($sym,$ind,$wth,$lnl,$tnl,$msg1,$msg2,$opt) unless defined $ENV{VERBOSE} and ! $ENV{VERBOSE};


    return unless $lfh;
    #------------------------------------------------------------------------
    #  The PrintFile used to be uemsPrintFile and prints info
    #  to a log file with the $lfh filehandle.
    #------------------------------------------------------------------------
    #
    &PrintFile($lfh,$sym,$ind,$wth,$lnl,$tnl,$msg1,$msg2,$opt);


return;
} #  PrintMessage



sub PrintTerminal {
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
       $spaces{X08X} = sprintf('%s',q{ } x 8);
       $spaces{X16X} = sprintf('%s',q{ } x 16);
       $spaces{X32X} = sprintf('%s',q{ } x 32);


    my ($type,$indnt,$cols,$leadnl,$trailnl,$head,$body,$text)  = @_;

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
    #    # - &GetFunCharacter

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
                ($type == 8) ? '+'            :
                ($type == 9) ? "\xe2\x98\xa0" : &GetFunCharacter();


    $text  = $text ? " ($text)" : q{};

    #  Format the text
    #
    my $header = ($symb eq '*')     ? "$symb$text  " : 
                 ($symb eq '!')     ? "$symb$text  " : 
                 ($symb eq '->')    ? "$symb$text "  : 
                 ($symb =~ /dbg/)   ? "$symb$text: " : 
                 ($symb eq '+')     ? "$symb$text  " :
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
                 ($symb eq '+')     ? "   $hindnt"   :
                 ($symb)            ? "   $hindnt"   : $bindnt;

    $| = 1;
    print "$leadnl";
    print wrap($hindnt,$windnt,$head);
    print wrap($windnt,$windnt,$body)   if $body;
    print "$trailnl";


return;
} #  PrintTerminal



sub PrintString {
#==================================================================================
#  This routine is just like &PrintTerminal except that it returns the message 
#  as a character string rather than printing it. You would used this routine
#  if you wanted to append other information to the message before printing
#  to the terminal or file.
#==================================================================================
#
use Text::Wrap;

    my %spaces = ();
       $spaces{X01X} = sprintf('%s',q{ } x 1);
       $spaces{X02X} = sprintf('%s',q{ } x 2);
       $spaces{X03X} = sprintf('%s',q{ } x 3);
       $spaces{X04X} = sprintf('%s',q{ } x 4);


    my ($type,$indnt,$cols,$leadnl,$trailnl,$head,$body,$text)  = @_;

    #  Note Types:
    #
    #    0 = ''
    #    1 - "*"
    #    2 - "\xe2\x98\xba"  Smiley Face
    #    3 - "&GetFunCharacter"
    #    4 - "dbg"
    #    5 - "->"
    #    6 - "!"
    #    7 - "\xe2\x9c\x93" Check Mark
    #    9 - "\xe2\x98\xa0" Skull & Crossbones
    #    # - &GetFunCharacter

    #  Set defaults
    #
    local $Text::Wrap::columns = ($cols > 80) ? $cols : 80;  # sets the wrap point. Default is 80 columns.
    local $Text::Wrap::separator="\n";
    local $Text::Wrap::unexpand=0;  #  Was 1 - changed 3/2017

    my $nl = "\n";
    $leadnl = 0 unless $leadnl  > 0;
    $trailnl= 0 unless $trailnl > 0;

    $head    = $nl unless $head;
    $indnt   = ! $indnt ? 0 : $indnt < 0 ? 0 : $indnt;

    $leadnl  = sprintf ('%s',$nl x $leadnl)  if $leadnl;
    $trailnl = sprintf ('%s',$nl x $trailnl) if $trailnl;

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
                ($type == 3) ? &GetFunCharacter() :
                ($type == 4) ? 'dbg'          :
                ($type == 5) ? '->'           :
                ($type == 6) ? '!'            :
                ($type == 7) ? "\xe2\x9c\x93" :  
                ($type == 8) ? '+'            :
                ($type == 9) ? "\xe2\x98\xa0" : &GetFunCharacter();


    $text  = $text ? " ($text)" : q{};

    #  Format the text
    #
    my $header = ($symb eq '*')     ? "$symb$text  " : 
                 ($symb eq '!')     ? "$symb$text  " : 
                 ($symb eq '->')    ? "$symb$text "  : 
                 ($symb eq '+')     ? "$symb$text  " : 
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
                 ($symb eq '+')     ? "   $hindnt"   : 
                 ($symb eq '!')     ? "   $hindnt"   : 
                 ($symb)            ? "   $hindnt"   : $bindnt;

    $| = 1;
    my @mesg = ();
    push @mesg, $leadnl if $leadnl;
    push @mesg, wrap($hindnt,$windnt,$head);
    push @mesg, wrap($bindnt,$bindnt,$body) if $body;
    push @mesg, $trailnl if $trailnl;


return join "\n", @mesg;
} #  PrintString



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



sub PrintFile {
#==================================================================================
#  This routine prints all error, warning, and information statements to the
#  user with a consistent format.
#==================================================================================
#
use Text::Wrap;
use IO::Handle;

    my %spaces = ();
       $spaces{X01X} = sprintf('%s',q{ } x 1);
       $spaces{X02X} = sprintf('%s',q{ } x 2);
       $spaces{X03X} = sprintf('%s',q{ } x 3);
       $spaces{X04X} = sprintf('%s',q{ } x 4);


    my ($fh,$type,$indnt,$cols,$leadnl,$trailnl,$head,$body,$text)  = @_;

    $fh = '' unless defined $fh and $fh;
    $fh->autoflush(1) if $fh;

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
    #    8 - '+'
    #    9 - "\xe2\x98\xa0" Skull & Crossbones
    #    # - &GetFunCharacter

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
                ($type == 8) ? '+'            :
                ($type == 9) ? "\xe2\x98\xa0" : &GetFunCharacter();


    $text  = $text ? " ($text)" : q{};

    #  Format the text
    #
    my $header = ($symb eq '*')     ? "$symb$text  " : 
                 ($symb eq '!')     ? "$symb$text  " : 
                 ($symb eq '->')    ? "$symb$text "  : 
                 ($symb =~ /dbg/)   ? "$symb$text: " : 
                 ($symb eq '+')     ? "$symb$text  " :
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
                 ($symb eq '+')     ? "   $hindnt"   :
                 ($symb)            ? "   $hindnt"   : $bindnt;

    $| = 1;
    $fh ? print $fh $leadnl : print $leadnl;
    $fh ? print $fh wrap($hindnt,$windnt,$head)             : print wrap($hindnt,$windnt,$head);
    if ($body) {$fh ? print $fh wrap($windnt,$windnt,$body) : print wrap($windnt,$windnt,$body);}
    $fh ? print $fh "$trailnl" : print "$trailnl";


return;
} #  PrintFile



sub JoinString {
#==================================================================================
#  This routine takes an array and formats the values for printing. Fro example
#  a list of @array = (apples  boogers  fish  Jupiter  Jim) will be turned into
#  a string $string = "apples, boogers, fish, Jupiter, and Jim". Note values must
#  passed as a reference.
#==================================================================================
#
    my $r = shift || return '';
    my @a = @{$r}; return '' unless @a;

    my $string = (@a == 1) ? $a[0] : (@a == 2) ? join ' and ', @a : join ', ', @a;
       $string =~ s/,(?!.*,)/, and/g;  #  Replaces last occurrence of "," with ", and"

return $string;
} #  JoinString



sub PrintDsetStruct {
#==================================================================================
#  Prints out information within the data structure for a requested dataset
#==================================================================================
#
    my @list    = ();
    my $dstruct = shift;

    while ($dstruct) {

        my $method  = 'Nefarious Global Purposes (0)';
           $method  = 'Initial & Boundary Conditions (1)'   if $dstruct->useid  == 1;
           $method  = 'Initial Conditions (2)'              if $dstruct->useid  == 2;
           $method  = 'Boundary Conditions (3)'             if $dstruct->useid  == 3;
           $method  = 'Land Surface Fields (4)'             if $dstruct->useid  == 4;
           $method  = 'Static Surface Fields (5)'           if $dstruct->useid  == 5;

        my $dset    = uc $dstruct->dset;
        my $ptile   = $dstruct->ptile        ? 'Yes' : 'No';
        my $timed   = ($dstruct->useid == 5) ? 'No' : 'Yes';
           $timed   = 'Yes' if $dstruct->useid == 4 and $dstruct->timed;

        push @list =>  &Ecomm::TextFormat(5,0,255,2,1,sprintf('Configured simulation settings for the %s grib dataset - %s',$dset,$method));

        push @list =>  &Ecomm::TextFormat(7,0,255,0,1,sprintf('Simulation Information:'));

        push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s','Simulation Start Date',&Others::DateString2Pretty($dstruct->rsdate)));
        push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s','Simulation End Date',&Others::DateString2Pretty($dstruct->redate)));
        push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s Hours','Simulation Length',sprintf('%02d',$dstruct->length)));
        push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s Hourly','BC Update Frequency',$dstruct->freqfh)) unless $dstruct->initfh == $dstruct->finlfh;


        push @list =>  &Ecomm::TextFormat(7,0,255,1,1,sprintf("Timing Information for $dset:"));

        push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s',"Dataset Cycle Date",&Others::DateString2Pretty($dstruct->yyyymmddcc)));
        push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s (%s Hour Forecast)','Start Fcst Hour Verif',&Others::DateString2Pretty($dstruct->yyyymmddhh),$dstruct->initfh));
        
    
        unless ($dstruct->initfh == $dstruct->finlfh) {
            push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s (%s Hour Forecast)','Stop  Fcst Hour Verif',&Others::DateString2Pretty($dstruct->redate),$dstruct->finlfh));
        }
        push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s','Time Dependent',$timed)) if $dstruct->useid == 4 or $dstruct->useid == 5;
        push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s','Synchronize Time',$dstruct->syncsfc ? 'Yes' : 'No')) if $dstruct->useid == 5;
        push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s','Thompson Aerosol-Aware',$dstruct->aerosol ? $dstruct->aerosol : 'No')) if $dstruct->useid < 3;

        push @list =>  &Ecomm::TextFormat(7,0,255,1,1,sprintf("General Information for $dset:"));

        push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s','Dataset Category',$dstruct->category));
        push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s','Vertical Coordinate',$dstruct->vcoord));
    
        push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s','Personal Tile Dataset',$ptile));
        push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s UTC','Available Cycles',join(' ',sort {$a <=> $b} @{$dstruct->cycles})));
        push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s Hours','Availability Delay',sprintf('%02d',$dstruct->delay)));
        push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s','Local File Name',$dstruct->locfil));

        push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s','GRIB Variable Table',$dstruct->vtable));
        push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s','WRF Metgrid Table',$dstruct->metgrid));

        print "$_\n" foreach @list;
  
        if (%{$dstruct->sources}) {
            my %hash = %{$dstruct->sources};
            &Ecomm::PrintTerminal(0,0,144,1,0,&Ecomm::TextFormat(9,0,144,0,0,'METHOD       SOURCE                           LOCATION'));
            &Ecomm::PrintTerminal(0,0,144,1,2,&Ecomm::TextFormat(7,0,144,0,0,'------------------------------------------------------------------------------------------------------------------'));
            for my $method (sort keys %hash) {
                foreach my $server (sort keys %{$hash{$method}}) {
                    &Ecomm::PrintTerminal(0,0,255,0,1,&Ecomm::TextFormat(9,0,255,0,0,sprintf("%-4s         %-32s %s",lc $method,$server,$hash{$method}{$server})));
                }
            }
        } else {
            my $dset = $dstruct->dset;
            &Ecomm::PrintTerminal(0,5,144,2,1,"NOTE:  All $dset files should already exist in the local grib directory.");
        }
        print "\n\n";

        $dstruct = $dstruct->nlink;

    }

return;
}


sub NodeSummary {
#==================================================================================
#  The NodeSummary routine prints out a summary of information about a
#  single node to be included in a distributed memory application, including 
#  Hostname, IP address, and the total number of cores available.  Input is in
#  the form of the hostname ($host) and a hash containing the other information
#  listed below.
#==================================================================================
#
    my $str  = qw{};

    my ($host, $href) = @_;
    my %info = %{$href};

    my $lhost        = $info{localhost} ? "\"$host\" (localhost)" : "\"$host\"";
    $info{localhost} = $info{localhost} ? 'Yes' : 'No';
    $info{headnode}  = $info{headnode}  ? 'Yes' : 'No';

    $str = "Information for $lhost\n\n";
    $str = $str."X04XHostname        :  $info{hostname}\n"  if defined $info{hostname};
    $str = $str."X04XAddress         :  $info{address}\n"   if defined $info{address};
    $str = $str."X04XLocal Host      :  $info{localhost}\n" if defined $info{localhost};
    $str = $str."X04XHead Node       :  $info{headnode}\n"  if defined $info{headnode};
    $str = $str."X04XNetwork Iface   :  $info{iface}\n"     if defined $info{iface};
    $str = $str."X04XNumber Sockets  :  $info{sockets}\n"   if defined $info{sockets};
    $str = $str."X04XCores Available :  $info{maxcores}\n"  if defined $info{maxcores};
    $str = $str."X04XCores Requested :  $info{reqcores}\n"  if defined $info{reqcores};

    if ( defined ($info{reqcores} and $info{usecores}) ) {
        if ($info{reqcores} == $info{usecores}) {
            $str = $str."X04XCores to be Used:  $info{usecores}\n";
        } else {
            $str = $str."X04XCores to be Used:  $info{usecores}  <-- NOTE\n";
        }
    }

return $str;
}


sub NodeCoresSummary {
#==================================================================================
#  The &NodeCoresSummary prepares a string containing a machine hostname and 
#  the number of core to be used for a process. This routine is typically called
#  called within a loop over a number of node/systems/machines to be included
#  in running a specific process.
#==================================================================================
#
    my ($lh, $nt, $href) = @_;
    my %info = %{$href};

    my $hostname     = &Enet::Hostname2ShortHostname($info{hostname});
       $hostname     = (defined $info{localhost} and $info{localhost}) ? "$hostname (localhost)" : "$hostname            ";
    my $cores        = (defined $info{usecores} and $info{usecores}) ? $info{usecores} : 'unknown number';
    my $ntiles       = ($nt == 1) ? '1 tile' : "$nt tiles";

    my $string       = sprintf("%-2s processors on %-${lh}s (%s per processor)",$cores,$hostname,$ntiles);

return $string;
}


sub PrintHash {
#==================================================================================
#  This routine prints out the contents of a hash. If a KEY is passed then the
#  routine will only print key-value pairs beneath that KEY. If no KEY is passed
#  then the routine will print out all key-value pairs in the hash.
#  For Debugging only.
#==================================================================================
#
    my %type         = ();
    @{$type{scalar}} = ();
    @{$type{array}}  = ();
    @{$type{hash}}   = ();
    @{$type{struct}} = ();

    my ($href, $skey, $ns, $alt) = @_;

    my %phash = %{$href}; return unless %phash;
     
    $skey     = q{} unless $skey;
    $ns       = 0 unless $ns;
    $alt      = 'TOP LEVEL OF HASH'  unless $alt;

    foreach my $key (sort keys %phash) {
        for (ref($phash{$key})) {
            /hash/i   ?  push @{$type{hash}}   => $key   :
            /array/i  ?  push @{$type{array}}  => $key   :
            /struct/i ?  push @{$type{struct}} => $key   :
                         push @{$type{scalar}} => $key;
        }
    }

    print sprintf("\n%sHASH:  %s\n\n",q{ }x$ns,$skey) if $skey;
    print sprintf("\n  $alt:  %s\n\n",$skey) unless $ns;
    $ns+=4;

    foreach (sort @{$type{scalar}}) {my $refkey = $skey ? "{$skey}{$_}" : "{$_}"; print sprintf("%sSCALAR:   %-60s  %s\n",q{ }x$ns,$refkey,defined $phash{$_} ? $phash{$_}                 : "Value $refkey is not defined\n");}
    foreach (sort @{$type{array}})  {my $refkey = $skey ? "{$skey}{$_}" : "{$_}"; print sprintf("%sARRAY :   %-60s  %s\n",q{ }x$ns,$refkey,@{$phash{$_}}      ? join ', ' => @{$phash{$_}} : "Array $refkey is empty\n");}
    foreach (sort @{$type{hash}})   {&PrintHash(\%{$phash{$_}},$_,$ns);}
    foreach (sort @{$type{struct}}) {&PrintDsetStruct($phash{$_});}

#    print "\n";

return;
} #  PrintHash



sub PrintVersion {
#==================================================================================
#  Print the version number and exit
#==================================================================================
#
    my ($exe,$ver,$host) = @_;

    $exe = defined $exe  ? $exe  : $ENV{EMSEXE};
    $ver = defined $ver  ? $ver  : $ENV{EMSVER};
    $host= defined $host ? $host : $ENV{EMSHOST};

    $host  ?  &PrintTerminal(0,2,96,1,2,sprintf("What you have here is UEMS %s routine (V%s) on %s",$exe,$ver,$host)) :
              &PrintTerminal(0,2,96,1,2,sprintf("What you have here is UEMS %s routine (V%s)",$exe,$ver));


&Ecore::SysExit(100,$0)
} #  PrintVersion



sub FormatTimingString {
#==================================================================================
#  This routine takes an amount of time in seconds and formats a string that
#  can be used to print out the amount of time in Hours, Minutes, and Seconds
#==================================================================================
#
use POSIX "floor";

    my $timing;
    my $secs  = shift;
       
    if ($secs < 1) {
        $secs=$secs*100; $secs=sprintf("%.2f",$secs*0.01);
        return "$secs seconds";
    }
    my $isecs = int $secs;
    my $fsecs = $secs - $isecs;
    $secs     = $isecs;

    my $hours = floor ($secs / 3600);
    my $mins  = floor ( ( ($secs % 86400) % 3600 ) / 60 );
       $secs  = ( ($secs % 86400) % 3600 ) % 60;

    $hours = ($hours == 1) ? " $hours hour " : " $hours hours"  if $hours;
    $mins  = ($mins == 1)  ? " $mins minute ": " $mins minutes" if $mins;

    $secs  = $secs + $fsecs if !$hours and !$mins;
    $secs  = $secs%1 ? sprintf('%.1f',$secs) : int $secs;
    $secs  = ($secs == 0) ? "" : $secs == 1  ? " $secs second" : " $secs seconds";

    $timing = "$hours"        if $hours;
    $timing = "$timing$mins"  if $mins;
    $timing = "$timing$secs"  if $secs;

    chomp $timing; $timing =~ s/ +/ /g; $timing =~ s/^ //g; $timing =~ s/ $//g;


return $timing;
} #  FormatTimingString



sub FormatSystemInformationShort  {
#==================================================================================
#  This routine takes the system information contained in the hash passed as an
#  argument and formats it for printing to the screen. The routine returns a 
#  formatted string with everything included and looking for a print statement.
#==================================================================================
#
    my $sref    = shift;
    my %sysinfo = %$sref;

    return $sysinfo{error} if $sysinfo{error};

    my $ht = $sysinfo{PROC}{ht} ? 'On' : 'Off';
    my $am = int $sysinfo{MEM}{available_memory};

    my $string  = "Basic System Information for $sysinfo{LHOST}\n\n".
                  "    System Date           : $sysinfo{HOST}{sysdate}\n".
                  "    System Hostname       : $sysinfo{HOST}{nhost}\n".
                  "    System Address        : $sysinfo{HOST}{address1}\n\n".

                  "    System OS             : $sysinfo{DIST}{os}\n".
                  "    Linux Distribution    : $sysinfo{DIST}{distro}\n".
                  "    OS Kernel             : $sysinfo{DIST}{kernel}\n".
                  "    Kernel Type           : $sysinfo{DIST}{ostype}\n\n".

                  "Processor and Memory Information for $sysinfo{LHOST}\n\n".

                  "    CPU Name              : $sysinfo{PROC}{model_name}\n".
                  "    CPU Microarchitecture : $sysinfo{PROC}{microarch}\n".
                  "    CPU Type              : $sysinfo{PROC}{cputype}\n".
                  "    CPU Speed             : $sysinfo{PROC}{cpu_speed} MHz\n\n".

                  "    UEMS Determined Processor Count\n".
                  "        Sockets           : $sysinfo{PROC}{sockets}\n".
                  "        Cores per Socket  : $sysinfo{PROC}{cores_per_socket}\n".
                  "        Total Cores       : $sysinfo{PROC}{total_cores}\n\n".

                  "    Hyper-Threading       : $ht  $sysinfo{PROC}{message}\n\n".
   
                  "    System Memory         : $am Gbytes\n\n".

                  "UEMS Release Information for $sysinfo{LHOST}\n\n".

                  "    UEMS Release          : $sysinfo{UEMS}{uemsvers}\n".
                  "    UEMS WRF Release      : $sysinfo{UEMS}{wrfvers}\n".
                  "    UEMS Binaries         : $sysinfo{UEMS}{emsbin}";


return $string;
}


sub FormatSystemInformationLong {
#==================================================================================
#  This routine takes the system information contained in the hash passed as an
#  argument and formats it for printing to the screen. The routine returns a 
#  formatted string with everything included and looking for a print statement.
#==================================================================================
#
    my @ifs     = ();
    my $sref    = shift;
    my %sysinfo = %$sref;

    return $sysinfo{error} if $sysinfo{error};

    my $ht = $sysinfo{PROC}{ht} ? 'On' : 'Off';
    my $am = int $sysinfo{MEM}{available_memory};
    my $ec = ($sysinfo{USER}{shell} =~ /bash/i) ? 'UEMS.profile' : 'UEMS.cshrc';
    my $ma = ucfirst $sysinfo{PROC}{microarch};

    foreach my $if (sort keys %{$sysinfo{IFACE}}) {

        my $ifi = qw{};
        if ($sysinfo{IFACE}{$if}{STATE}) {  # Should only be specified when 'Up'
            $sysinfo{IFACE}{$if}{ADDR}  = 'None Assigned' unless $sysinfo{IFACE}{$if}{ADDR};
            $sysinfo{IFACE}{$if}{HOST}  = 'Nothing'       unless $sysinfo{IFACE}{$if}{HOST};
            $ifi = "    Network Interface     : $if\n".
                   "    Interface Address     : $sysinfo{IFACE}{$if}{ADDR}\n".
                   "    Address Resolves to   : $sysinfo{IFACE}{$if}{HOST}\n".
                   "    Interface State       : $sysinfo{IFACE}{$if}{STATE}\n";
        } else {
            $ifi = "    Network Interface     : $if\n".
                   "    Interface State       : Inactive\n";
        }
        push @ifs => $ifi;
    }

    my $ifi = join "\n" => @ifs;


    my $string  = "System Information for $sysinfo{LHOST}\n\n".

                  "    System Date           : $sysinfo{HOST}{sysdate}\n".
                  "    System Hostname       : $sysinfo{HOST}{nhost}\n".
                  "    System Address        : $sysinfo{HOST}{address1}\n\n".

                  "    System OS             : $sysinfo{DIST}{os}\n".
                  "    Linux Distribution    : $sysinfo{DIST}{distro}\n".
                  "    OS Kernel             : $sysinfo{DIST}{kernel}\n".
                  "    Kernel Type           : $sysinfo{DIST}{ostype}\n\n".

                  "Network Interface Information for $sysinfo{LHOST}\n\n".

                  "$ifi\n".

                  "Processor and Memory Information for $sysinfo{LHOST}\n\n".

                  "    CPU Name              : $sysinfo{PROC}{model_name}\n".
                  "    CPU Microarchitecture : $ma\n".
                  "    CPU Type              : $sysinfo{PROC}{cputype}\n".
                  "    CPU Speed             : $sysinfo{PROC}{cpu_speed} MHz\n\n".

                  "    UEMS Determined Processor Count\n".
                  "        Sockets           : $sysinfo{PROC}{sockets}\n".
                  "        Cores per Socket  : $sysinfo{PROC}{cores_per_socket}\n".
                  "        Total Cores       : $sysinfo{PROC}{total_cores}\n\n".

                  "    $ec Specified Processor Count\n".
                  "        Sockets           : $sysinfo{UEMS}{emsncpus} \n".
                  "        Cores per Socket  : $sysinfo{UEMS}{emscores}\n".
                  "        Total Cores       : $sysinfo{UEMS}{totcores}\n\n".

                  "    Hyper-Threading       : $ht  $sysinfo{PROC}{message}\n\n".

                  "    System Memory         : $am Gbytes\n\n".

                  "UEMS User Information for $sysinfo{USER}{uname} on $sysinfo{LHOST}\n\n".

                  "    Home Directory        : $sysinfo{USER}{home}\n".
                  "    User  ID              : $sysinfo{USER}{uid} ($sysinfo{USER}{uname})\n".
                  "    Group ID              : $sysinfo{USER}{gid} ($sysinfo{USER}{gname})\n".
                  "    Home Directory Mount  : $sysinfo{USER}{mount}\n".
                  "    User Shell            : $sysinfo{USER}{shell}\n".
                  "    Shell Login Files     : $sysinfo{USER}{rcfile}\n\n".


                  "UEMS Installation Information for $sysinfo{LHOST}\n\n".

                  "    UEMS Home Directory   : $sysinfo{UEMS}{emshome}\n".
                  "    UEMS User ID          : $sysinfo{UEMS}{emsuid} ($sysinfo{UEMS}{emsname})\n".
                  "    UEMS Group ID         : $sysinfo{UEMS}{emsgid} ($sysinfo{UEMS}{emsgname})\n".
                  "    UEMS Home Mount       : $sysinfo{UEMS}{emsmount}\n".
                  "    UEMS Binaries         : $sysinfo{UEMS}{emsbin}\n".
                  "    UEMS Release          : $sysinfo{UEMS}{uemsvers}\n".
                  "    UEMS WRF Release      : $sysinfo{UEMS}{wrfvers}\n\n".

                  "    UEMS Run Directory    : $sysinfo{UEMS}{emsrun}\n".
                  "    UEMS Run Dir User ID  : $sysinfo{UEMS}{runduid} ($sysinfo{UEMS}{rundname})\n".
                  "    UEMS Run Dir Group ID : $sysinfo{UEMS}{rundgid} ($sysinfo{UEMS}{rundgname})\n".
                  "    UEMS Run Dir Mount    : $sysinfo{UEMS}{runmount}\n\n".

                  "    Run Dir Total Space   : $sysinfo{UEMS}{disk_total} Gb\n".
                  "    Run Dir Space Used    : $sysinfo{UEMS}{disk_used} Gb\n".
                  "    Run Dir Avail Space   : $sysinfo{UEMS}{disk_avail} Gb";

return $string;
}



sub GetRN {
#==================================================================================
#  This, like so many other routines in the UEMS, is a kludge to allow for the
#  availability of incremental Roman Numeral values in informational statements.
#  Yes
#==================================================================================
#  
    my @rns = (qw(I. II. III. IV. V. VI. VII. VIII. IX. X. XI. XII. XIII. XIV. XV. XVI. XVII. XVIII. XIX. XX.));

    my $n = shift;
  
return $rns[$n];
}


sub GetFunCharacter {
#==================================================================================
#  This routine returns an unusual unicode character randomly selected from a non-
#  random list.
#==================================================================================
#
use List::Util qw(shuffle);

    my @unichars = ("\xe2\x98\x80","\xe2\x98\x82","\xe2\x98\x83","\xe2\x98\x84","\xe2\x98\x85","\xe2\x98\x86","\xe2\x98\x87",
                    "\xe2\x98\x88","\xe2\x98\x8e","\xe2\x98\x94","\xe2\x98\x95","\xe2\x98\xa0","\xe2\x98\xa2","\xe2\x98\xa3",
                    "\xe2\x98\xae","\xe2\x98\xaf","\xe2\x98\xb8","\xe2\x98\xb9","\xe2\x98\xba","\xe2\x98\xbb","\xe2\x98\xbc",
                    "\xe2\x98\xbd","\xe2\x98\xbe","\xe2\x98\xbf","\xe2\x99\x80","\xe2\x99\x81","\xe2\x99\x82","\xe2\x99\x83",
                    "\xe2\x99\x84","\xe2\x99\x85","\xe2\x99\x86","\xe2\x99\x87","\xe2\x99\x94","\xe2\x99\x9a","\xe2\x99\x9b",
                    "\xe2\x99\x9c","\xe2\x99\x9e","\xe2\x99\x9f","\xe2\x99\xa8","\xe2\x99\xa9","\xe2\x99\xaa","\xe2\x99\xab",
                    "\xe2\x99\xac","\xe2\x99\xad","\xe2\x99\xb2","\xe2\x99\xbb","\xe2\x99\xbc","\xe2\x9a\x9b","\xe2\x9a\x98");

       @unichars = shuffle @unichars;

return $unichars[int rand scalar @unichars]
} #  GetFunCharacter



