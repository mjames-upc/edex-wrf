#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Pginfo.pm
#
#  DESCRIPTION:  Pginfo contains each of the primary routines used for the
#                reading and QC of the information contained in the GRIB
#                information files, i.e., <dset>_gribinfo.conf.
#
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Pginfo;

use warnings;
use strict;
require 5.008;
use English;


use vars qw (%Hostkeys);

use Ecomm;
use Ecore;
use Others;



sub CollectGribInfo {
#==================================================================================
#  Routine that reads the contents of the files in the conf/gribinfo directory
#  and then returns a hash of hashes where the first key is the dataset and
#  the sub keys for each %{$hash{<dataset>}} are the various fields defined
#  in each file. Note that this step should only be done once.
#==================================================================================
#
    my %gihash = ();
    my @ginfos = ();


    #----------------------------------------------------------------------------------
    #  Step 1.  Collect the files from conf/gribinfo that have the '_gribinfo.conf' 
    #           string.
    #----------------------------------------------------------------------------------
    #
    @ginfos = &Others::FileMatch("$ENV{EMS_CONF}/gribinfo",'_gribinfo.conf',0,0);

    unless (@ginfos) {
        my $mesg = "It appears that the $ENV{EMS_CONF}/gribinfo directory does not contain ".
                   "any <dataset>_gribinfo.conf files.";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,94,0,0,'Sorry, but we just can\'t continue like this:',$mesg);
        return ();
     }


     #----------------------------------------------------------------------------------
     #  Step 2. Read the HostKey file, which provides the URL associated with 
     #          each HOST key in the gribinfo.conf files.
     #----------------------------------------------------------------------------------
     #
     return () unless %Hostkeys = &ReadHostKeysConf();

     #----------------------------------------------------------------------------------
     #  Save the host key information just in case it is needed outside of
     #  the Pginfo module. The %Hostkeys hash is available within Pginfo.pm.
     #----------------------------------------------------------------------------------
     #
     %{$gihash{HKEYS}} = %Hostkeys;


     #----------------------------------------------------------------------------------
     #  Step 3.  Read the contents of each gribinfo file
     #----------------------------------------------------------------------------------
     #
     foreach my $ginfo (@ginfos) {
         my $name = &Others::popit($ginfo); $name =~ s/_gribinfo.conf//g;
         my $dset = lc $name;
         next unless %{$gihash{$dset}} = &ReadGribinfoFile($ginfo);
         $gihash{$dset}{moniker}       = $name;
     }


return %gihash;
} 



sub ReadGribinfoFile {
#==================================================================================
#  Read the contents of the passed <dataset>_gribinfo.conf file and return
#  the values in a hash. Any missing values will be initialized with appropriate
#  values.
#==================================================================================
#
    my %ginfo = ();

    #  Initialize the values in the hash 
    #
    $ginfo{info}       = 'Apparently nothing is known about this dataset';
    $ginfo{aged}       = 0;
    $ginfo{ptile}      = 0;
    $ginfo{delay}      = 0;
    $ginfo{vcoord}     = '';

    $ginfo{initfh}     = 0;
    $ginfo{finlfh}     = 0;
    $ginfo{freqfh}     = 0;

    $ginfo{initfm}     = 0;
    $ginfo{finlfm}     = 0;
    $ginfo{freqfm}     = 0;

    $ginfo{locfil}     = '';
    $ginfo{vtable}     = '';
    $ginfo{moniker}    = '';
    $ginfo{lvtable}    = '';
    $ginfo{metgrid}    = 'METGRID.TBL.CORE';
    $ginfo{timevar}    = 0;
    $ginfo{maxfreq}    = 0;
    $ginfo{category}   = 'Land of misfit datasets';
    $ginfo{analysis}   = -1;
    @{$ginfo{cycles}}  = ();
    %{$ginfo{sources}} = ();

    my %sftp  = ();
    my %shtp  = ();
    my %snfs  = ();
    my %shtps = ();


    my $file = shift; return %ginfo unless -f $file;

    open (my $rfh, '<', $file);  #  Open the file and begin the read

    while (<$rfh>) {

        chomp;
        tr/\000-\037/ /;
        s/^\s+|^\t+//g;
        next if /^#|^$|^\s+/;
        next unless $_;

        my ($field, $value) = split /\s*=\s*/, $_, 2;

        $value = 0 unless defined $value;

        for ($field) {

            $ginfo{info}     = &Ginfo_info($value)     if /INFO/i;

            $ginfo{category} = &Ginfo_category($value) if /CATEGORY/i;
            $ginfo{vcoord}   = &Ginfo_vcoord($value)   if /VCOORD/i;
            $ginfo{locfil}   = &Ginfo_locfil($value)   if /LOCFIL/i;
            $ginfo{delay}    = &Ginfo_delay($value)    if /DELAY/i;
            $ginfo{initfh}   = &Ginfo_initfh($value)   if /INITFH/i;
            $ginfo{finlfh}   = &Ginfo_finlfh($value)   if /FINLFH/i;
            $ginfo{freqfh}   = &Ginfo_freqfh($value)   if /FREQFH/i;

            $ginfo{initfm}   = &Ginfo_initfm($value)   if /INITFM/i;
            $ginfo{finlfm}   = &Ginfo_finlfm($value)   if /FINLFM/i;
            $ginfo{freqfm}   = &Ginfo_freqfm($value)   if /FREQFM/i;

            $ginfo{maxfreq}  = &Ginfo_maxfreq($value)  if /MAXFREQ/i;
            $ginfo{aged}     = &Ginfo_aged($value)     if /AGED/i;

            $ginfo{vtable}   = &Ginfo_vtable($value)   if /^VTABLE/i;
            $ginfo{lvtable}  = &Ginfo_vtable($value)   if /LVTABLE/i;
            $ginfo{metgrid}  = &Ginfo_metgrid($value)  if /METGRID/i;
            $ginfo{timevar}  = &Ginfo_timevar($value)  if /TIMEVAR/i;

            @{$ginfo{cycles}}= &Ginfo_cycles($value)   if /CYCLES/i;

            %sftp            = &Ginfo_ftp ($value,\%sftp)   if /SERVER-FTP/i;
            %shtp            = &Ginfo_http($value,\%shtp)   if /SERVER-HTTP$/i;
            %shtps           = &Ginfo_https($value,\%shtps) if /SERVER-HTTPS/i;
            %snfs            = &Ginfo_nfs ($value,\%snfs)   if /SERVER-NFS/i;

        } # For each field 

        $ginfo{ptile} = ($ginfo{category} =~ /Personal Tile/i) ? 1 : 0;
        $ginfo{gfile} = &Others::popit($file);

        %{$ginfo{sources}{FTP}}   = %sftp  if %sftp;
        %{$ginfo{sources}{HTTP}}  = %shtp  if %shtp;
        %{$ginfo{sources}{HTTPS}} = %shtps if %shtps;
        %{$ginfo{sources}{NFS}}   = %snfs  if %snfs;

    }  # While loop

    #  One final touch
    #
    $ginfo{metgrid} = "$ENV{DATA_TBLS}/wps/$ginfo{metgrid}";

    close $rfh;


return %ginfo;
} #  ReadGribinfoFile



sub QueryGribinfo {
#==================================================================================
#  Called from the ParseOptions routine, QueryGribinfo calls either 
#  QueryDatasetList or QueryDatasetInfo depending whether the user passed
#  the "--dslist" or "--query <dataset>" flag.  There is no return from
#  this subroutine but simply any exit. Just the way it should be.
#
#  Note that this is one of the few subroutines from which there is no return.
#==================================================================================
#
    my $type = shift;  $type = lc $type;

    unless ($type) {
        my $mesg = "You need to include the moniker to identify the dataset you wish to query, i.e, ".
                   "\"--dsquery <moniker>\". The moniker is part of the gribinfo.conf file name, ".
                   "<moniker>_gribinfo.conf located in the uems/conf/gribinfo directory. You can also ".
                   "get a list of the available datasets by passing the \"--dslist\" flag.";
        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,84,0,0,'Oops, Your bad!',$mesg));
    }


    my %ginfos = &CollectGribInfo();

    if ($type =~ /^list/) {

        &QueryDatasetList(\%ginfos);

    } else {

       my @dsets = keys %ginfos;
       unless (defined $ginfos{$type}) {
           my $mesg = "The dataset about which you are inquiring ($type) is not supported by the UEMS. The System ".
                      "Elders expect nothing less than perfection from you, so next time do a better job and make us ".
                      "proud; otherwise, we are going to lay a big guilt trip on you (again).\n\n".

                      "Here's a hint: Try using the \"--dslist\" flag to view a list of supported datasets.";
           &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'Flying Blind?',$mesg));
       }
       &QueryDatasetInfo(\%{$ginfos{$type}});

    }


&Ecore::SysExit(-4);
} 



sub QueryDatasetList {
#==================================================================================
#   Routine to print out the supported initialization datasets in a organized list
#==================================================================================
#
    my $len   = 0;
    my %dlist = ();
    my @ord   = qw (I. II. III. IV. V. VI. VII. VIII. IX. X. XI. XII.);

    my $href  = shift;
    my %dsets = %{$href};

    &Ecomm::PrintTerminal(0,4,144,1,1,'Initialization datasets currently supported for use with the UEMS:');

    foreach my $key (keys %dsets) { next if $key =~ /HKEYS/i;
        $dlist{$dsets{$key}{category}}{$dsets{$key}{moniker}}    = $dsets{$key}{info};
        $len = length $dsets{$key}{moniker} if length $dsets{$key}{moniker} > $len;
    }

    foreach my $key (sort keys %dlist) {

        my $ex = ($key =~ /Land Surface Model/) ? ' (--lsm Option Only)' : ($key =~ /Surface/) ? ' (--sfc Option Only)' : '';
        my $nn = ($key =~ /Personal Tile/) ? '    ' : shift @ord;
        my $nl = $nn eq '    ' ? 1 : 2;
        &Ecomm::PrintTerminal(0,6,255,$nl,2,sprintf("%4s  %s",$nn,"$key Datasets$ex"));

        foreach my $name (keys %{$dlist{$key}}) {
            &Ecomm::PrintTerminal(0,14,255,0,1,sprintf("%-${len}s   %s",$name,$dlist{$key}{$name}));
        }
    }

    my $mesg = "NOTE: The first column lists the ID used when specifying a model initialization dataset.";
    &Ecomm::PrintTerminal(0,6,144,2,1,$mesg);

    $mesg = "More information on a specific dataset can be obtained by using the \"--dsinfo\" option:\n\n".
            "    %  ems_prep --dsinfo <dataset ID>";
    &Ecomm::PrintTerminal(0,6,144,2,1,$mesg);

    $mesg = "Finally, all initialization dataset configuration files are located in:\n\n    $ENV{EMS_CONF}/gribinfo\n\n".
            "You may want consult the user guide for more information about adding datasets.";
    &Ecomm::PrintTerminal(0,6,94,2,2,$mesg);


return;
}



sub QueryDatasetInfo {
#==================================================================================
#   Routine to print out the supported initialization datasets in a organized list
#==================================================================================
#
    my @list  = ();
    my %cords = ();
       $cords{press}  = 'Pressure';
       $cords{hybrid} = 'Hybrid';
       $cords{theta}  = 'Isentropic';
       $cords{height} = 'Height';
       $cords{sigma}  = 'Sigma';
       $cords{none}   = 'None';
       $cords{unknown}= 'Unknown';

    my $href  = shift;
    my %ginfo = %{$href};

    my $cycles = join ', ' => @{$ginfo{cycles}};

    push @list =>  &Ecomm::TextFormat(5,0,255,2,0,sprintf('Default settings from the %s grib information file: %s',$ginfo{moniker},$ginfo{gfile}));

    push @list =>  &Ecomm::TextFormat(7,0,255,1,0,sprintf('%-11s  : %s','Description',$ginfo{info}));
    push @list =>  &Ecomm::TextFormat(9,0,144,1,0,sprintf('%-32s  : %s','Dataset Category',$ginfo{category}));
    push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s','Vertical Coordinate',$cords{$ginfo{vcoord}}));
    push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s','Default Initial Forecast Hour',$ginfo{initfh}));
    push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s','Default Final Forecast Hour',$ginfo{finlfh}));
    push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s Hour%s','Default BC Update Frequency',$ginfo{freqfh},$ginfo{freqfh} eq '01' ? ' ' : 's'));
    push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s','Available Cycles (UTC)',$cycles));
    push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s Hour%s','Remote Server Delay',$ginfo{delay},$ginfo{delay} eq '01' ? ' ' : 's'));
    push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s','Local Filename',$ginfo{locfil}));
    push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s','Vtable Grid Information File',$ginfo{vtable} ? $ginfo{vtable} : 'None'));
    push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s','LVtable Grid Information File',$ginfo{lvtable} ? $ginfo{lvtable} : 'None'));
    push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s Hour%s','Maximum BC Update Frequency',$ginfo{maxfreq},$ginfo{maxfreq}eq '01' ? ' ' : 's'));
#   push @list =>  &Ecomm::TextFormat(9,0,144,0,0,sprintf('%-32s  : %s','',$ginfo{}));

    print "$_\n" foreach @list;

    if (%{$ginfo{sources}}) {
        &Ecomm::PrintTerminal(0,0,144,1,0,&Ecomm::TextFormat(9,0,144,0,0,'METHOD       SOURCE                           LOCATION'));
        &Ecomm::PrintTerminal(0,0,144,1,2,&Ecomm::TextFormat(7,0,144,0,0,'------------------------------------------------------------------------------------------------------------------'));

        for my $method (sort keys %{$ginfo{sources}}) {
            foreach my $server (sort keys %{$ginfo{sources}{$method}}) {
                &Ecomm::PrintTerminal(0,0,255,0,1,&Ecomm::TextFormat(9,0,255,0,0,sprintf("%-4s         %-32s %s",lc $method,$server,$ginfo{sources}{$method}{$server})));
            }
        }
    } else {
        &Ecomm::PrintTerminal(6,9,94,1,1,"NOTE:  No sources for the $ginfo{moniker} files are specified in $ginfo{gfile}.",'All files are assumed to be available locally.');
    }


return;
}



sub ReadHostKeysConf {
#==================================================================================
#  Read Hostkey file in the uems/conf/ems_prep directory. The information contained
#  within is used when accessing initialization datasets. The returned %hkeys hash
#  contains a set of KEY:address pairs where the address may take the form of an
#  IP address or hostname.
#==================================================================================

    my $hkeyf = "$ENV{EMS_CONF}/ems_prep/prep_hostkeys.conf";

    unless (-s $hkeyf) {
        my $mesg = "Missing Host Key information file: $hkeyf";
        $ENV{PMESG} = &Ecomm::TextFormat(0,0,255,0,0,'Trouble getting started?',$mesg);
        return ();
    }

    my %hkeys = &Others::ReadConfigurationFile($hkeyf);


return %hkeys;
}



sub ResolveHostKey {
#==================================================================================
#  This routine matches the HOST KEY used in the gribinfo.conf files with 
#  a corresponding hostname or IP address from the prep_global.conf file.
#==================================================================================
#
    my %hkeys = ();

    my ($hkey, $rkeys) = @_; return '' unless $hkey;

    %hkeys = $rkeys ? %{$rkeys} : %Hostkeys;

    #  Check for passed IP or hostname
    #
    for ($hkey) {
        if (/^local/i)                                      {return  'local';}
        if (/^([\d]+)\.([\d]+)\.([\d]+)\.([\d]+)$/)         {return  $hkey;} # IP address
        if (/^([\w]|-)+\.([\w]|-)+\.([\w]|-)+\.([\w]|-)+$/) {return  $hkey;} # Hostname
        if (/^([A-Z0-9])+$/)                                {return  $hkeys{uc $hkey} if defined $hkeys{uc $hkey};}  
        if (/^([\w]|-)+$/)                                  {defined $hkeys{uc $hkey} ? return $hkeys{uc $hkey} : return lc $hkey;}
    }

    &Ecomm::PrintMessage(6,8,84,1,1,sprintf("Could not match %s to IP or hostname. Is it defined in conf/ems_prep/prep_hostkeys.conf?",$hkey));

return;
}



sub Ginfo_aged {
#==================================================================================
#  Format the input from the AGED field in the  <dataset>_gribinfo.conf
#  files.  Returns a padded integer.
#==================================================================================
#
    my $value = shift;

    $value = 2  unless defined $value and length $value;
    $value = 2  unless &Others::isInteger($value);
    $value = abs $value;
    $value = 30 if $value > 30;  #  Set 30 day maximum
    $value +=0;

return sprintf('%02d',$value);
}



sub Ginfo_category {
#==================================================================================
#  Format the input from the CATEGORY field in the  <dataset>_gribinfo.conf
#  files.  Returns a clean string for framing.
#==================================================================================
#
    my $string = shift;

    for ($string) {
        s/^\s+|\s+$//g;
        s/\s+/ /g;
        s/LSM/Land Surface Model/g;
        s/SFC/Surface/g;
        s/OPER/Operational/g;
        s/FCST/Forecast/g;
        s/ANAL/Analysis/g;
        s/MODL/Model/g;
        s/REAN/Historical/g;
        s/PTIL/Personal Tile/g;
     }

     $string = 'Land of misfit datasets' unless $string;
        
return $string;
}



sub Ginfo_cycles {
#==================================================================================
#  Format the input from the CYCLES field in the  <dataset>_gribinfo.conf
#  files.  Returns a clean string for framing. Note that the values must be
#  padded with zeros.
#==================================================================================
#
    my @cycles = ();
    my $string = shift;

    $string = &Gstring($string);
    $string =~ s/,+|;+/;/g;

    foreach my $cycle (split /;/, $string) {
        my @clist = split /:/, $cycle;
        foreach (@clist) {
            if (/\D/) {
                $_ = uc $_;
                s/S//g; # eliminate trailing "S"
                s/[CYCLE|INITFH|FINLFH|FREQFH]//g; # catch screw-ups
            } else {
                $_ = sprintf '%02d', $_;
            }
            my $tmp = join ":", @clist;
            push @cycles => $tmp;
        }
    }


return @cycles;
}



sub Ginfo_delay {
#==================================================================================
#  Format the input from the DELAY field in the  <dataset>_gribinfo.conf
#  files.  Returns a padded integer.
#==================================================================================
#
    my $value = shift;

    $value = 3 unless defined $value and length $value and $value;
    $value = 3 unless &Others::isInteger($value);
    $value = 3 if $value < 0;
    $value +=0;

return sprintf('%02d',$value);
}



sub Ginfo_finlfh {
#==================================================================================
#  Format the input from the FINLFH field in the  <dataset>_gribinfo.conf
#  files.  Returns a padded integer.
#==================================================================================
#
    my $value = shift;

    $value = 24 unless defined $value and length $value and $value;
    $value = 24 unless &Others::isInteger($value);
    $value = 24 if $value < 0;
    $value +=0;
    $value = sprintf('%02d',$value) if $value < 100;

return $value;
}



sub Ginfo_finlfm {
#==================================================================================
#  Format the input from the FINLFM field in the  <dataset>_gribinfo.conf
#  files.  Returns a padded integer.
#==================================================================================
#
    my $value = shift;

    $value = 0 unless defined $value and length $value and $value;
    $value = 0 unless &Others::isInteger($value);
    $value = 0 if $value < 0;
    $value +=0;

return $value;
}



sub Ginfo_freqfh {
#==================================================================================
#  Format the input from the FREQFH field in the  <dataset>_gribinfo.conf
#  files.  Returns a padded integer.
#==================================================================================
#
    my $value = shift;

    $value = 3  unless defined $value and length $value ;
    $value = 3  unless &Others::isInteger($value);
    $value = 3  if $value < 0;
    $value = 24 if $value > 24;
    $value +=0;

return sprintf('%02d',$value);
}



sub Ginfo_freqfm {
#==================================================================================
#  Format the input from the FREQFM field in the  <dataset>_gribinfo.conf
#  files.  Returns a padded integer.
#==================================================================================
#
    my $value = shift;

    $value = 0  unless defined $value and length $value;
    $value = 0  unless &Others::isInteger($value);
    $value = 0  if $value < 0;
    $value = 0  if $value > 24*60; #  24 hours * 60 mintes
    $value +=0;

return sprintf('%02d',$value);
}



sub Ginfo_ftp {
#==================================================================================
#  Format the input from the SERVER-FTP field in the  <dataset>_gribinfo.conf
#  files.  Returns a clean string for framing.
#==================================================================================
#
    my ($string,$href) = @_;
    my %hash = %{$href};

    $string = &Gstring($string);

    for ($string) {

        s/,+|;+| +//g;
        my @list = split (/:/,$_,2);
 
        unless ($list[1]) {
            &Ecomm::PrintMessage(6,8,104,1,1,sprintf("Mis-configured SERVER-FTP entry (Line containing %s)",$list[0] ? $list[0] : $list[1]));
        }

        #  At this point we need to replace the Host key ID with a corresponding IP or URL
        #  for the server; however, before doing so it's necessary to check whether $list[0]
        #  does not already contain an IP or URL, in which case there is no need for the
        #  substitution.
        #
        my $host = $list[0];

        unless ($list[0] = &ResolveHostKey($list[0])) {
            &Ecomm::PrintMessage(6,8,104,1,1,"Missing Hostkey entry for ID $host");
            return ();
        }
        $hash{$list[0]} = $list[1];
    }

return %hash;
}



sub Ginfo_http {
#==================================================================================
#  Format the input from the SERVER-HTTP field in the  <dataset>_gribinfo.conf
#  files.  Returns a clean string for framing.
#==================================================================================
#
    my ($string,$href) = @_;
    my %hash = %{$href};

    $string = &Gstring($string);

    for ($string) {

        s/,+|;+| +//g;
        my @list = split (/:/,$_,2);

        unless ($list[1]) {
            &Ecomm::PrintMessage(6,8,104,1,1,sprintf("Mis-configured SERVER-HTTP entry (Line with %s)",$list[0] ? $list[0] : $list[1]));
        }

        #  At this point we need to replace the Host key ID with a corresponding IP or URL
        #  for the server; however, before doing so it's necessary to check whether $list[0]
        #  does not already contain an IP or URL, in which case there is no need for the
        #  substitution.
        #
        my $host = $list[0];

        unless ($list[0] = &ResolveHostKey($list[0])) {
            &Ecomm::PrintMessage(6,8,104,1,1,"Missing Hostkey entry for ID $host");
            return ();
        }
        $hash{$list[0]} = $list[1];

    }


return %hash;
}



sub Ginfo_https {
#==================================================================================
#  Format the input from the SERVER-HTTPS field in the  <dataset>_gribinfo.conf
#  files.  Returns a clean string for framing.
#==================================================================================
#
    my ($string,$href) = @_;
    my %hash = %{$href};

    $string = &Gstring($string);

    for ($string) {

        s/,+|;+| +//g;
        my @list = split (/:/,$_,2);

        unless ($list[1]) {
            &Ecomm::PrintMessage(6,8,104,1,1,sprintf("Mis-configured SERVER-HTTPS entry (Line with %s)",$list[0] ? $list[0] : $list[1]));
        }

        #  At this point we need to replace the Host key ID with a corresponding IP or URL
        #  for the server; however, before doing so it's necessary to check whether $list[0]
        #  does not already contain an IP or URL, in which case there is no need for the
        #  substitution.
        #
        my $host = $list[0];

        unless ($list[0] = &ResolveHostKey($list[0])) {
            &Ecomm::PrintMessage(6,8,104,1,1,"Missing Hostkey entry for ID $host");
            return ();
        }
        $hash{$list[0]} = $list[1];

    }


return %hash;
}



sub Ginfo_info {
#==================================================================================
#  Format the input from the INFO field in the  <dataset>_gribinfo.conf
#  files.  Returns a 1|0 value;
#==================================================================================
#
    my $string = shift;

    for ($string) {
        chomp;
        s/^\s+|\s+$//g;
        s/\s+/ /g;
        s/\t/ /g;
        tr/\014|\015|\003|\001//;
    }

return $string;
}



sub Ginfo_initfh {
#==================================================================================
#  Format the input from the INITFH field in the  <dataset>_gribinfo.conf
#  files. Returns a padded integer.
#==================================================================================
#
    my $value = shift;

    $value = 0 unless defined $value and length $value and $value;
    $value = 0 unless &Others::isInteger($value);
    $value = 0 if $value < 0;
    $value +=0;

return sprintf('%02d',$value);
}



sub Ginfo_initfm {
#==================================================================================
#  Format the input from the INITFM field in the  <dataset>_gribinfo.conf
#  files. Returns a padded integer.
#==================================================================================
#
    my $value = shift;

    $value = 0 unless defined $value and length $value and $value;
    $value = 0 unless &Others::isInteger($value);
    $value = 0 if $value < 0;
    $value +=0;

return sprintf('%02d',$value);
}



sub Ginfo_locfil {
#==================================================================================
#  Format the input from the LOCFIL field in the  <dataset>_gribinfo.conf
#  files.  Returns a clean string for framing.
#==================================================================================
#
return &Gstring(shift);
}



sub Ginfo_maxfreq {
#==================================================================================
#  Format the input from the MAXFREQ field in the  <dataset>_gribinfo.conf
#  files.  Returns a padded integer.
#==================================================================================
#
    my $value = shift;

    $value = 6  unless defined $value and length $value;
    $value = 6  unless &Others::isInteger($value);
    $value = 6  if $value < 0;
    $value = 24 if $value > 24;
    $value +=0;

return sprintf('%02d',$value);
}



sub Ginfo_metgrid {
#==================================================================================
#  Format the input from the METGRID field in the  <dataset>_gribinfo.conf
#  files.  Returns a clean string for framing.
#==================================================================================
#
    my $string = shift;

    $string = &Gstring($string);
    
return $string ? $string : 'METGRID.TBL.CORE';
}



sub Ginfo_nfs {
#==================================================================================
#  Format the input from the SERVER-NFS field in the  <dataset>_gribinfo.conf
#  files.  Returns a clean string for framing.
#==================================================================================
#
    my ($string,$href) = @_;
    my %hash = %{$href};

    $string = &Gstring($string);

    for ($string) {

        s/,+|;+| +//g;
        my @list = split (/:/,$_,2);
        unless ($list[0] and $list[1]) {
            if ($list[0]) {
                $list[1] = $list[0];
                $list[0] = 'LOCAL';
            } else {
                $list[0] = 'LOCAL';
            }
        }
        $list[0] = &ResolveHostKey($list[0]);
        $hash{$list[0]} = $list[1];
    }

return %hash;
}



sub Ginfo_timevar {
#==================================================================================
#  Format the input from the TIMEVAR field in the  <dataset>_gribinfo.conf
#  files.  Returns a 1|0 value;
#==================================================================================
#
    my $string = shift;

    $string = &Gstring($string);

return ($string=~/^Y|^1/i) ? 1 : 0;
}



sub Ginfo_vcoord {
#==================================================================================
#  Format the input from the VCOORD field in the  <dataset>_gribinfo.conf
#  files.  Returns a clean string for framing.
#==================================================================================
#
    my $string = shift;

    for ($string) {
        s/^\s+|\s+$//g;
        s/\s+/ /g;
        $_ = 'press'  if /press|isobar/ig;
        $_ = 'hybrid' if /hybrid|ruc|rap/ig;
        $_ = 'theta'  if /theta|isentrop/ig;
        $_ = 'height' if /height|hgt/ig;
        $_ = 'sigma'  if /sig/ig;
        $_ = 'none'   if /no/ig;
     }
     $string = 'unknown' unless $string;

return $string;
}



sub Ginfo_vtable {
#==================================================================================
#  Format the input from the VTABLE field in the  <dataset>_gribinfo.conf
#  files.  Returns a clean string for framing.
#==================================================================================
#
    my $vtable = &Gstring(shift);

return $vtable ? "$ENV{DATA_TBLS}/vtables/$vtable" : '';
}



sub Gstring {
#==================================================================================
#  Simply clean up a sting by removing spaces and tabs
#==================================================================================
#
    my $string = shift;
    
    for ($string) {
        chomp;
        s/\s//g;
        s/\t//g;
        tr/\014|\015|\003|\001//;
    }

return $string;
} 



