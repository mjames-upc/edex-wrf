#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Others.pm
#
#  DESCRIPTION:  Others contains all the other subroutines used for testing
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Others;

use warnings;
use strict;
require 5.008;
use English;

use Ecore;
use Ecomm;


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


sub ArrayIntersection {
#==================================================================================
#  Returns the Intersection of 2 arrays. Note that the arrays are passed and
#  not just the references.
#==================================================================================
#
    my %count = ();
    my @inter = ();    
    my @array = @_;

    foreach (@array) {$count{$_}++;}
    foreach (keys %count) { push @inter => $_ if $count{$_} > 1;}

return (sort @inter);
} #  ArrayIntersection


sub ArrayMissing {
#==================================================================================
#  Returns elements in @a that are not in @b - Note arrays must be passed as 
#  references, i.e., @missing = &ArrayMissing(\@a,\@b);
#==================================================================================
#
    my %count = ();
    my @miss  = ();
    my ($a, $b) = @_;

    @{$a} = &rmdups(@{$a});

    foreach (@{$b}) {$count{$_}++;}
    foreach (@{$a}) {push @miss => $_ unless defined $count{$_};}


return (sort @miss);
} #  ArrayMissing


sub ArrayUnion {
#==================================================================================
#  Returns the union of 2 arrays
#==================================================================================
#
    my %count = ();
    my @array = @_;

    foreach (@array) {$count{$_}++;}

return (sort keys %count);
} #  ArrayUnion


sub ArrayMultiply {
#==================================================================================
#  Return array in which each element in @a is multiplied by corresponding 
#  element in @b. @a & @b are passed as references.
#
#  return @multiplied = &ArrayMultiply(\@a,\@b);
#==================================================================================
#
    my $i;
    my ($a, $b) = @_;

    my @a = @$a;
    my @b = @$b;


#   my @r = map { $_*(@l > @m ? @l : @m)[$i++]||0 } @l > @m ? @m : @l;
    my @r = map { $_ * (@b > @a ? @b : @a)[$i++]||0 } @b > @a ? @a : @b;

return @r;
} #  ArrayMultiply


sub BestPatchDecomposition {
#==================================================================================
#  This routine determines the decomposition of a domain given the available
#  number of processors, number of grid points in each direction, and the 
#  minimum number of grid points in each direction allowed within a patch.
# 
#  The final argument specifies the "best decomposition" target, of which there
#  are currently 3:
#
#      1 - 1 x ncpus :  Where there is 1 cpu in the x-direction and MAX cpus in
#                       the y-direction. For example, the decomposition of a 
#                       4 x 4 grid point domain with 4 cpus would look like:
#
#                              cpu# |4 4 4 4
#                              cpu# |3 3 3 3 
#                              cpu# |2 2 2 2
#                              cpu# |1 1 1 1
#                                   --------
#
#      2 - ncpus x 1  :  Where there is 1 cpu in the y-direction and MAX cpus in
#                        the x-direction. For example, the decomposition of a 
#                        4 x 4 grid point domain with 4 cpus would look like:
#
#                                   |1 2 3 4
#                                   |1 2 3 4 
#                                   |1 2 3 4
#                                   |1 2 3 4
#                                   --cpu#--
#
#      3 - cpus_y x cpu_x: Where cpus_y*cpus_x = ncpus AND cpus_y-cpus_x is as
#                          small as possible. If ncpus is not a square of 2
#                          integers (say 6 cpus) then cpu_x < cpus_y.
#
#                                   |3 3 4 4
#                                   |3 3 4 4 
#                                   |1 1 2 2
#                                   |1 1 2 2
#                                   --cpu#--
#
#      4 - cpus_y x cpu_x: Where cpus_y*cpus_x = ncpus AND cpus_y-cpus_x is as 
#                          large as possible. This decomposition method will 
#                          likely result in the best performance on a single
#                          node, and quite possibly on a multi-node system as
#                          well, although testing is recommended.
#  
#                          Depending upon the grid dimensions of the domaini(s) 
#                          and the number of cpus used, the decomposition will
#                          range between option #1 and #4. For example, on a 24
#                          core system, the possible domain decompositions (NXxNY):
#
#                             a. 1 x 24  
#                             b. 2 x 12
#                             c. 3 x 8
#                             d. 4 x 6
#                          
#                          The UEMS will determine the best decomposition for your
#                          simulation, from 1 x 24 (assumed best) -> 4 x 6.
#
#                          Note that #1 and #4 are essentially the same.
#                          
#
#  The routine returns the best decomposition values for cpus_y and cpu_x that
#  could be achieved given the input. It may return values for cpus_y and cpu_x,
#  where cpu_x*cpus_y < maxcpus if a viable decomposition could not be calculated
#  given the input value of maxcpus. This would most likely occur when maxcpus
#  is a prime number and fails the min_pts_per_patch test. If no values could be
#  determined then the routine returns cpu_x = cpu_y = 0.
#
#  Note that this subroutine is unusual in that the description is longer
#  than the routine itself!
#==================================================================================
#
    my $decomp_x = 0;
    my $decomp_y = 0;

    my ($maxcpus, $domain_nx, $domain_ny, $min_pts_per_patch, $target) = @_;

    foreach my $cpus (1 .. $maxcpus) {

        my @factors=();
        foreach (1..$cpus) {push @factors => $_ unless $cpus % $_;}

        my @ydims = ();
        foreach my $cpus_y (@factors) {
            if ($target == 2) {
                push @ydims => $cpus_y if $cpus_y <= $cpus/$cpus_y;
            } else {
                push @ydims => $cpus_y if $cpus_y >= $cpus/$cpus_y;
            }
        }
        @ydims = ($target == 3) ? sort {$b <=> $a} @ydims : sort {$a <=> $b} @ydims;

        foreach my $cpus_y (@ydims) {
            my $cpus_x = $cpus/$cpus_y;
            my $dxppt = int ($domain_nx/$cpus_x);
            my $dyppt = int ($domain_ny/$cpus_y);
            unless ($dxppt<$min_pts_per_patch or $dyppt<$min_pts_per_patch) {
                $decomp_x = $cpus_x;
                $decomp_y = $cpus_y;
            }
        }
    }


return ($decomp_x, $decomp_y);

}  #  BestPatchDecomposition


sub PatchDecompositionCheck {
#==================================================================================
#  This determines whether the chosen decomposition meets the strict UEMS
#  standard (those written in the WRF source code).
#==================================================================================
#
    my ($npatches, $ngridpts, $min_pts_per_patch) = (0, 0, 0);

       ($npatches, $ngridpts, $min_pts_per_patch) = @_;
    
    return 1 unless $npatches and $ngridpts and $min_pts_per_patch;

return ($ngridpts/$npatches < $min_pts_per_patch) ? 1 : 0;
}  #  PatchDecompositionCheck


sub Bytes2MB {
#==================================================================================
#  Convert number of Bytes (input) to MegaBytes (Returned).
#==================================================================================
#
    my $bytes = shift; return 0 unless defined $bytes and $bytes;

return $bytes*0.000000953674316;
} #  Bytes2MB


sub CalculateEpochSeconds {
#==================================================================================
#  This routine accepts a date/time string YYYYMMDDHH[MN[SS]] and calculates
#  the number of seconds since the epoc.
#==================================================================================
#
use Time::Local;

    my $date = shift || return 0;
    my @list = &DateString2DateList($date);

return timegm($list[5],$list[4],$list[3],$list[2],$list[1]-1,$list[0]);
} #  CalculateEpochSeconds


sub CalculateNewDate {
#==================================================================================
#  This routine takes in a date string and offset (seconds) and calculates the
#  date. It returns a string YYYYMMSSMNSS.
#==================================================================================
#
use Time::Local;

    my ($date, $offset) = @_; 

    $date    += 0;
    $offset  += 0;

    my $ctime = &CalculateEpochSeconds($date) + $offset;
    my @time  = gmtime($ctime);

return &DateList2DateString($time[5]+1900,$time[4]+1,$time[3],$time[2],$time[1],$time[0]);
} #  CalculateNewDate


sub CompatibleGLib {
#==================================================================================
#  This routine checks the compatibility of the system GLIBC with the passed 
#  executable and returns an empty string if OK or a message if not.
#==================================================================================
#
    my $rglib = '';
    my $mesg  = '';

    my $exe = shift; 

    foreach (`ldd $exe 2>&1 | cat`) { chomp;   #  Redirect stdio & stderr 
        if (/GLIBC_(\d+\.\d+)/) {$rglib = $1;}
    }

    return $mesg unless $rglib;

    #  First get the current GLIBC version nuber from the ldd command
    #   
    my @lines = `ldd --version 2>&1 | cat`;
    my @words = split " +" => $lines[0];
    (my $dglib = $words[-1]) =~ s/ //g;

    $mesg = "The $exe routine requires GLIB C version $rglib or later, but unfortunately ".
            "this system is running GLIB C version $dglib.";

 return $mesg;
}


sub DataDump {
#==================================================================================
#  Use the perl data dumper routine to format and print out the hash structure
#  such that it can be eval'd by the calling routine into a another hash.
#==================================================================================
#
use Data::Dumper;

    $Data::Dumper::Terse  = 1;
    $Data::Dumper::Indent = 0;
    print Dumper \%{$_[0]};

return;
}


sub DateList2DateString {
#==================================================================================
#  This routine takes an array containing date & time and returns a datestr 
#  formatted as YYYYMMDDHH[MN[SS]].
#
#  Input: @list = ($yyyy, $mm, $dd, $hh, $mn, $ss)
#  Out  : $datestr = YYYYMMDDHH[MN[SS]]
#==================================================================================
#
    my @list = (0,0,0,0,0,0);
    @list[0..$#_] = @_;

    foreach (@list) {$_+=0; $_=sprintf "%02d",$_ ;}
    $list[0] = sprintf "%04d",$list[0];

    my $datestr = join '' => @list;

return $datestr;
} #  DateList2DateString


sub DateList2DateStringWRF {
#==================================================================================
#  This routine takes an array containing date & time and returns a datestr 
#  formatted as YYYY-MM-DD_HH:MN:SS, just the way WRF likes it.
#
#  Input: @list = ($yyyy, $mm, $dd, $hh, $mn, $ss)
#  Out  : $datestr = YYYY-MM-DD_HH:MN:SS
#==================================================================================
#
    my $wrfstr = 'YYYY-MM-DD_HH:MN:SS';

    my @list = (0,0,0,0,0,0);
    @list[0..$#_] = @_;

    foreach (@list) {$_+=0; $_=sprintf '%02d',$_ ;}
    $list[0] = sprintf '%04d',$list[0];

    for ($wrfstr) {
        s/YYYY/$list[0]/g;
        s/MM/$list[1]/g;
        s/DD/$list[2]/g;
        s/HH/$list[3]/g;
        s/MN/$list[4]/g;
        s/SS/$list[5]/g;
    }

return $wrfstr;
} #  DateList2DateStringWRF


sub DateString2DateList {
#==================================================================================
#  This routine takes a date/time string, formatted as YYYYMMDDHH[MN[SS]], parses 
#  the year, month, day, hour, and second values, and then returns a list containing 
#  the date/time values. Missing values are padded with "00".
#
#  Input: YYYYMMDDHH[MN[SS]]
#  Out  : ($yyyy, $mm, $dd, $hh, $mn, $ss) = @list
#==================================================================================
#
    my @blist = (0,0,0,0,0,0);
    my @alist = (0,0,0,0,0,0);

    for (&DateStringWRF2DateString(shift)) {
        @blist = $_ =~ /^(\d\d\d\d)$/                               if /^(\d\d\d\d)$/;
        @blist = $_ =~ /^(\d\d\d\d)(\d\d)$/                         if /^(\d\d\d\d)(\d\d)$/;
        @blist = $_ =~ /^(\d\d\d\d)(\d\d)(\d\d)$/                   if /^(\d\d\d\d)(\d\d)(\d\d)$/;
        @blist = $_ =~ /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)$/             if /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)$/;
        @blist = $_ =~ /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/       if /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/;
        @blist = $_ =~ /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/ if /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/;
    }
    @alist[0..$#blist] = @blist;
    foreach (@alist) {$_+=0; $_=sprintf "%02d",$_ ;}

return @alist;
} #  DateString2DateList


sub DateString2DateString {
#==================================================================================
#  This routine takes a date/time string and returns a new date string in
#  the requested format.
#==================================================================================
#
    my ($datestr, $format) = @_;  $format =~ s/cc/hh/i;

    #  Get the date string in the proper format
    #
    $datestr = &DateList2DateString(&DateString2DateList($datestr));

    for ($format) {

        if (/^yyyymmddhhmnss$/i) {return substr $datestr, 0, 14;}
        if (/^yyyymmddhhmn$/i)   {return substr $datestr, 0, 12;}
        if (/^yyyymmddhh$/i)     {return substr $datestr, 0, 10;}
        if (/^yyyymmdd$/i)       {return substr $datestr, 0, 8;}
        if (/^yymmddhh$/i)       {return substr $datestr, 2, 8;}
        if (/^yymmdd$/i)         {return substr $datestr, 2, 6;}
        if (/^yyyymm$/i)         {return substr $datestr, 0, 6;}
        if (/^yyyy$/i)           {return substr $datestr, 0, 4;}
        if (/^yy$/i)             {return substr $datestr, 2, 2;}
        if (/^mm$/i)             {return substr $datestr, 4, 2;}
        if (/^dd$/i)             {return substr $datestr, 6, 2;}
        if (/^hh$/i)             {return substr $datestr, 8, 2;}
        if (/^mn$/i)             {return substr $datestr, 10, 2;}
        if (/^ss$/i)             {return substr $datestr, 12, 2;}
    }

return $datestr;
} #  DateString2DateString


sub DateString2DateStringWRF {
#==================================================================================
#  This routine takes a date & time string YYYYMMDDHH and returns a datestr 
#  formatted as YYYY-MM-DD_HH:MN:SS, just the way WRF likes it.
#
#  Input: $yyyymmddhh
#  Out  : $wrfstr = YYYY-MM-DD_HH:MN:SS
#==================================================================================
#
    my $yyyymmddhh = shift;

    my @list   = &DateString2DateList($yyyymmddhh);
    my $wrfstr = &DateList2DateStringWRF(@list);

return $wrfstr;
} #  DateString2DateStringWRF


sub DateString2Pretty {
#==================================================================================
#  This routine accepts YYYYMMDDHH[MM][SS] and returns a nice date/time
#  suitable for framing.
#
#  In:  2008062417[00][00]
#  Out: Tue Jun 24 17:00:00 2008 UTC
#==================================================================================
#
    my @list = &Others::DateString2DateList(shift);
    my $string = gmtime(timegm($list[5],$list[4],$list[3],$list[2],$list[1]-1,$list[0]));

return "$string UTC";
} #  DateString2Pretty


sub DateStringWRF2DateString {
#==================================================================================
#  This routine accepts a WRF netCDF file date/time string in YYYY-MM-DD_HH:MN:SS
#  format and returns a YYYYMMDDHHMNSS string.  Note that filesnames such as
#  met_em.d01.2016-05-17_12:00:00.nc or wrfout_d01_2016-05-17_12:00:00 are also
#  allowed.
#==================================================================================
#
    my $datestr = shift || return 0;
    for ($datestr) {chomp; s/\w*d\d\d//g; s/\D//g;}

return $datestr;
} #  DateStringWRF2DateString


sub EpochSeconds2DateString {
#==================================================================================
#  Input: iNumber of seconds since 1 January 1970 00:00:00 UTC
#  Out  : $datestr = YYYYMMDDHHMNSS
#==================================================================================
#
use POSIX 'strftime';

    my $epochs = shift;
    my $datestr = strftime '%Y%m%d%H%M%S', gmtime $epochs;

return $datestr;
} #  EpochSeconds2DateString


sub FileExistsHost {
#==================================================================================
#  FileExistsHost simply checks whether the specified file exists on the remote 
#  system via SSH. The return value of 0 indicates success; otherwise, an error
#  message (non-zero value) is returned.
#==================================================================================
#
    my ($host, $file) = @_;

return &Ecore::SysExecute("ssh -q -o BatchMode=yes $host ls $file  > /dev/null 2>&1") ? "SSH file test failed on $host" : 0;
}


sub FileExists {
#==================================================================================
#  This routine checks for the existence of a file or directory and returns 0 if
#  exists, otherwise 1. Yes, I am aware that the name might be counter intuitive
#  but I wanted to be consistent with those tests that return a cause for failure
#  string upon failure, such as FileExistsHost.
#==================================================================================
#
    my $file = shift; 

return (defined $file and $file and -e $file and (-f $file or -d $file or -l $file) ) ? 0 : 1;
} #  FileExists


sub FileMatch {
#==================================================================================
#  This routine returns a list of files in a directory that match the specified
#  string. The arguments are:
#
#      $dir    -  The directory path to search
#      $string -  The string to match - "0" indicates get all files
#      $nodir  -  Whether to include (0) or not include (1) the full path in returned values
#      $nochk  -  0 (check) or 1 (don't check) the file size - Yes, the double neg is confusing
#
#==================================================================================
#   
    my @ffiles = ();
    my @files  = ();

    my ($dir,$string,$nodir,$nochk) = @_;  

    $nochk = 0 unless defined $nochk and $nochk; 

    return @files unless -d $dir;

    system "ls $dir > /dev/null 2>&1";  #  Workaround for NFS issues

    opendir DIR => $dir; @files = $string ? sort grep /$string/ => readdir DIR : sort grep !/^\./ => readdir DIR; close DIR;

    return @files unless @files; # return list if empty

    @files = &Others::rmdups(@files);

    foreach (@files) {  
        next if /^\./;
        if ($nochk) {
            push @ffiles => $_ if -f "$dir/$_";
        } else {
            push @ffiles => $_ if -e "$dir/$_" and ! -z "$dir/$_";
        }
    }
    @files = sort @ffiles;

    unless ($nodir) {$_ = "$dir/$_" foreach @files;}

return @files;
}  #  FileMatch


sub FileMatchDomain {
#==================================================================================
#  This routine returns a list of files in a directory that match the specified
#  string. The arguments are:
#
#      $dir    -  The directory path to search
#      $string -  The string to match - The string to match - "0" indicates get all files
#      $nodir  -  Whether to include the full path in returned values
#      $domain -  The domain number (optional)
#      $index  -  Used by ems_autopost so don't worry about it
#
#  Basically, this routine collects a list of files containing a STRING from
#  a DIRECTORY using the FileMatch subroutine and then further subsets the list
#  with the DOMAIN number.
#==================================================================================
#
    my @files = ();
    my ($dir, $string, $nodir, $domain, $index) = @_;

    return @files unless -d $dir;

    @files = &FileMatch($dir,$string,1,1);  #  The first '1' tells FileMatch not to include 
                                            #  the directory path. It will be added later 
                                            #  if it was requested. The second '1' turns
                                            #  off file size checking.

    return @files unless @files;

    #  Assume that the domain is identified by "d##" in the filename
    #
    $domain = sprintf('%02d', $domain);
    @files = sort grep /d${domain}/ => @files;
     
    return @files unless @files; 

    $index = 0 unless defined $index and $index;

    @files = sort @files[$index .. $#files];  @files = &Others::rmdups(@files);

    unless ($nodir) {$_ = "$dir/$_" foreach @files;}


return @files;
}  #  FileMatchDomain



sub FileSize {
#==================================================================================
#  This routine returns the size in bytes of a file or zero if it doesn't exist
#==================================================================================
#
    my $file = shift; 

return (defined $file and $file and -e $file and -f $file) ? (-s $file) : 0;
} #  FileSize


sub FileType {
#==================================================================================
#  This routine accepts a filename and returns the file type as netcdf (cdf),
#  gempak (gempak), GRIB 1 (grib1), GRIB 2 (grib2), HDF5 (hdf), or unknown (unknown).
#==================================================================================
#
    my $unk    = 'unknown';
    my $buffer = qw{};

    my $file = shift;

    unless (defined $file and $file) {&Ecomm::PrintMessage(6,5,86,1,1,"FileType : No file passed!"); return $unk;}

    open (my $fh, '<', $file) || return $unk; ; read $fh, $buffer, 256; close $fh;

    my ($format, $version)  = unpack 'a7c', $buffer;

    $format =~ s/\W//g; $format = lc $format;
    $format = "grib$version" if $format =~ /GRIB/i;
    $format = ($format =~ /CDF|GEMPAK|GRIB|HDF/i) ? lc $format : $unk;

    #  Before relegating the file type to the world of "unknown" make
    #  sure the header isn't just messed up.
    #
    if ($format eq $unk) {
        $format = unpack 'a8', $buffer;
        $format = ($format =~ /CDF|GEM|GRI|HDF|/i) ? lc $format : $unk;
        $format = 'grib1' if $format =~ /GRI/i;
    }

    
    for ($format) {
        $_ = 'grib2'  if /grib2/i;
        $_ = 'grib1'  if /grib1/i;
        $_ = 'netcdf' if /cdf/i;
        $_ = 'gempak' if /gem/i;
        $_ = 'hdf5'   if /hdf5/i;
        $_ = 'hdf4'   if /hdf4/i;
    }

return $format;
} #  FileType


sub FileInfo {
#==================================================================================
#  This subroutine takes the fully qualified name of a file or directory and
#  and returns a hash containing all sorts of information used by the UEMS.
#==================================================================================
#
use Cwd;
use File::stat;

    my %fhash = ();
    my @fields = qw(realpath exists isfile islink isdir isread iswrite
                    isexec isowner size modsecs fdate fage uname);

    foreach (@fields) {$fhash{$_} = 0;}  #  Initialize the fields to zero
    
    my $file = shift; return %fhash unless defined $file and $file and -e $file;

    my $csecs = time();

    for ($file) {

        $fhash{realpath} = Cwd::realpath($_);
        $fhash{exists}   = -e $_ ? 1 : 0;
        $fhash{isfile}   = -f $_ ? 1 : 0;
        $fhash{islink}   = -l $_ ? 1 : 0;
        $fhash{isdir}    = -d $_ ? 1 : 0;
        $fhash{isread}   = -r $_ ? 1 : 0;
        $fhash{iswrite}  = -w $_ ? 1 : 0;
        $fhash{isexec}   = -x $_ ? 1 : 0;
        $fhash{isowner}  = -o $_ ? 1 : 0;
        $fhash{size}     = -s $_ ;
    
        my $sf   = stat $fhash{realpath};

        $fhash{modsecs}  = $sf->mtime;
        $fhash{fdate}    = gmtime $fhash{modsecs};
        $fhash{fage}     = $csecs - $sf->mtime;

        $fhash{uname}    = getpwuid($sf->uid);

    }

return  %fhash;
} #  FileInfo


       
sub FileUnpack {
#==================================================================================
#  this routine unpacks files compressed in gzip, bzip, or bzip2 format
#  The packed files are passed as a list and he method used for unpacking 
#  is determined by the file extention.
#==================================================================================
#
    my @unpacked = ();

    my ($verbose, @packed) = @_;  return () unless @packed;

    my $method = $packed[0] =~ /(.gz)$/  ? 'gunzip'   :
                 $packed[0] =~ /(.bz2)$/ ? 'bunzip2'  :
                 $packed[0] =~ /(.bz)$/  ? 'bunzip2'  : 0;

    unless ($method) {
        &Ecomm::PrintMessage(6,11,96,0,1,"Unknown file compression suffix ($packed[0]). - Exit"); return ();
    }

    $method = &Others::LocateX($method);

    foreach my $zfile (@packed) {

       next unless ((my $file = $zfile) =~ s/(.gz)$|(.bz2)$|(.bz)$//g);

       system "$method $zfile > /dev/null 2>&1";

       if (-e $file) {
           my $sizemb = &Bytes2MB(&Others::FileSize($file)); 
           &Ecomm::PrintMessage(0,1,96,0,1,sprintf("- Unpacked (%.2f MB)",$sizemb)) if $verbose;
           push @unpacked => $file;
       } else {
           # There was a problem with unpacking
           #
           &Ecomm::PrintMessage(6,11,96,1,2,"Problem unpacking $zfile");
           return ();
       }
   }

return @unpacked;
} #  FileUnpack


sub FileFcstTimes {
#==================================================================================
#  Routine to extract the initialization and forecast times from a data file.
#  Currently supported are GRIB 1, GRIB 2, netCDF, and GEMPAK formatted files.
#
#  Input Arguments: <data file> <format (optional> 
#  Output String  : YYYYMMDDHHMNSS
#==================================================================================
#
    my @fcsts = ();
    my $init  = 0;

    my ($file, $format) = @_;

    $format = &FileType($file) unless defined $format and $format;


    if ($format eq 'grib2' || $format eq 'grib') {
        $init  = &Others::Grib2InitTime($file);
        @fcsts = &Others::Grib2VerifTimes($file);
    }


    if ($format eq 'grib1') {
        $init  = &Others::Grib1InitTime($file);
        @fcsts = &Others::Grib1VerifTimes($file);
    }


    if ($format eq 'netcdf') {
        $init  = &Others::NetcdfInitTime($file);
        @fcsts = &Others::NetcdfVerifTimes($file);
    }


    if ($format eq 'gempak') {
        @fcsts = &Others::GempakVerifTimes($file);
        $init  = shift @fcsts;
    }


return ($init, @fcsts);
} #  FileFcstTimes



sub FilenameWRF2DateStringWRF {
#==================================================================================
#  This routine accepts a WRF netCDF filename such as wrfout_d01_2016-05-17_12:00:00
#  and returns a WRF date string (YYYY-MM-DD_HH:MN:SS).
#==================================================================================
#
    my $datestr = shift || return 0;
    for ($datestr) {chomp; s/(d\d\d)//g; s/\D//g;}

    $datestr = &DateString2DateStringWRF($datestr);

return $datestr;
} #  FilenameWRF2DateStringWRF


sub Grib1VerifTimes {
#==================================================================================
#  Extract all verification date/times from a GRIB 1 file record.
#  Output from this routine is a list of date strings matching YYYYMMDDHHMMSS.
#==================================================================================
#
    my $n     = 0;
    my %dates = ();
    my $miss  = '00000000000000';
    my $wgrib = "$ENV{EMS_UBIN}/wgrib";

    return ($miss) unless -x $wgrib;

    my $grib = shift;  return ($miss) unless (defined $grib and $grib and -f $grib);

    foreach (`$wgrib -verf  -4yr -min $grib`)  {if (/(\d{12})/) {$n++; $dates{"${1}00"} = $n;}}

    my @fcsts = sort {$a <=> $b} keys %dates;


return @fcsts;
} #  Grib1VerifTimes



sub Grib2InitTime {
#==================================================================================
#  Extract the initialization date/time from the 1st record of a GRIB 2 file.
#  Output from this routine is a date string matching YYYYMMDDHHMMSS.
#==================================================================================
#
    my $miss  = 0;
    my $wgrib = "$ENV{EMS_UBIN}/wgrib2";

    return $miss unless -x $wgrib;

    my $grib = shift;  return $miss unless (defined $grib and $grib and -f $grib);

return (`$wgrib -S -d 1 $grib` =~ /(\d{14})/) ? $1 : $miss;
} #  Grib2InitTime



sub Grib2VerifTime {
#==================================================================================
#  Extract the first verification date/times from a GRIB 2 file record.
#  Output from this routine is a date string matching YYYYMMDDHHMMSS.
#==================================================================================
#
    my $miss  = '00000000000000';
    my $wgrib = "$ENV{EMS_UBIN}/wgrib2";

    return ($miss) unless -x $wgrib;

    my $grib = shift;  return ($miss) unless (defined $grib and $grib and -f $grib);

return (`$wgrib -VT -d 1 $grib` =~ /(\d{14})/) ? $1 : $miss;
} #  Grib2VerifTimes



sub Grib2VerifTimes {
#==================================================================================
#  Extract all verification date/times from a GRIB 2 file record.
#  Output from this routine is a list of date strings matching YYYYMMDDHHMMSS.
#==================================================================================
#
    my $n     = 0;
    my %dates = ();
    my $miss  = '00000000000000';
    my $wgrib = "$ENV{EMS_UBIN}/wgrib2";

    return ($miss) unless -x $wgrib;

    my $grib = shift;  return ($miss) unless (defined $grib and $grib and -f $grib);

    foreach (`$wgrib -VT $grib`)  {if (/(\d{14})/) {$n++; $dates{$1} = $n;}}

    my @fcsts = sort {$a <=> $b} keys %dates;


return @fcsts;
} #  Grib2VerifTimes



sub Grib2NumGribs {
#==================================================================================
#  Get the number of GRIBS in s GRIB 2 file - Yes, thats all
#==================================================================================
#
    my $N = -1;
    my $wgrib = "$ENV{EMS_UBIN}/wgrib2";

    return $N unless -x $wgrib;

    my $grib = shift; return $N unless (defined $grib and $grib and -f $grib);

    foreach (`$wgrib -n $grib`) {$N = /^(\d+):/ ? $1 : $N;}

return $N
} #  Grib2NumGribs



sub NetcdfInitTime {
#==================================================================================
#  Extract the initialization date/time from a netCDF file.
#  Output from this routine is a date string matching YYYYMMDDHHMMSS.
#==================================================================================
#
    my $init   = 0;
    my $rdwrfnc = "$ENV{EMS_UBIN}/rdwrfnc";

    return $init unless -x $rdwrfnc;

    my $cdf = shift;  return $init unless (defined $cdf and $cdf and (-f $cdf or -l $cdf)); 

    foreach (`$rdwrfnc -times $cdf`) {
        chomp; next if (/^(#.*|\s*)$/); next unless $_;
        if (/^\s*START\s+TIME:\s*(\d{4}.\d{2}.\d{2}.\d{2}.\d{2}.\d{2})\s*/) {$init = &Others::DateStringWRF2DateString($1);}
    }

return $init;
} #  NetcdfInitTime



sub NetcdfVerifTime {
#==================================================================================
#  Extract the last verification date/time from a netCDF file. This routine
#  is similar to &NetcdfVerifTimes but returns the final date/time in the list.
#  Output from this routine is a date string matching YYYYMMDDHHMMSS.
#==================================================================================
#
    my $n     = 0;
    my %dates = ();
    my $miss  = 0;
    my $rdwrfnc = "$ENV{EMS_UBIN}/rdwrfnc";

    return ($miss) unless -x $rdwrfnc;

    my $cdf = shift;  return ($miss) unless (defined $cdf and $cdf and (-f $cdf or -l $cdf));

    foreach (`$rdwrfnc -times $cdf`) {
        chomp; next if (/^(#.*|\s*)$/);
        if (/^\s*FRCST\s+TIME:\s*(\d{4}.\d{2}.\d{2}.\d{2}.\d{2}.\d{2})\s*/) {$n++; $dates{&Others::DateStringWRF2DateString($1)} = $n;}
    }

    my @verfs = sort {$a <=> $b} keys %dates;

return pop @verfs;
} #  NetcdfVerifTime



sub NetcdfVerifTimes {
#==================================================================================
#  Extract the verification date/time(s) from a netCDF file.
#  Output from this routine is a date string matching YYYYMMDDHHMMSS.
#==================================================================================
#
    my $n     = 0;
    my %dates = ();
    my $miss  = '00000000000000';
    my $rdwrfnc = "$ENV{EMS_UBIN}/rdwrfnc";

    return ($miss) unless -x $rdwrfnc;

    my $cdf = shift;  return ($miss) unless (defined $cdf and $cdf and (-f $cdf or -l $cdf));

    foreach (`$rdwrfnc -times $cdf`) {
        chomp; next if (/^(#.*|\s*)$/);
        if (/^\s*FRCST\s+TIME:\s*(\d{4}.\d{2}.\d{2}.\d{2}.\d{2}.\d{2})\s*/) {$n++; $dates{&Others::DateStringWRF2DateString($1)} = $n;}
    }

    my @verfs = sort {$a <=> $b} keys %dates;

return @verfs;
} #  NetcdfVerifTimes



sub Grib1InitTime {
#==================================================================================
#  Extract the initialization date/time from the 1st record of a GRIB 1 file.
#  Output from this routine is a date string matching YYYYMMDDHHMMSS.  Note that
#  for GRIB 1 files the seconds are assumed to be "00".
#==================================================================================
#
    my $miss  = '00000000000000';
    my $wgrib = "$ENV{EMS_UBIN}/wgrib";

    return $miss unless -x $wgrib;

    my $grib = shift;  return $miss unless (defined $grib and $grib and -f $grib);


return (`$wgrib -d 1 -4yr -min $grib` =~ /(\d{12})/) ? "${1}00" : $miss;
} #  Grib1InitTime



sub GempakVerifTimes {
#==================================================================================
#  Extract the initialization and verification date/time(s) from a Gempak file.
#  Output from this routine is a date string matching YYYYMMDDHHMMSS.
#  This routine also provides the initialization file as the first
#  element in the list.
#
#  Note:  Unlike other similar routines, there is nothing elegant in
#         this process. This is brute-force sausage making at its wurst.
#         That's a bit of sausage humor for you.
#==================================================================================
#
    my $n     = 0;
    my %dates = ();
    my $miss  = '00000000000000';
    my $gdinfo = "$ENV{GEMEXE}/gdinfo";
    my @gemfls = qw(gdinfo.fil gdinfo.in gemglb.nts last.nts);

    return ($miss) unless -x $gdinfo;

    my $gempak = shift;  return ($miss) unless (defined $gempak and $gempak and -f $gempak);

    #  Set the GEMPAK environment
    #
    $ENV{NAWIPS}     = "$ENV{EMS_UTIL}/nawips";
    $ENV{GEMEXE}     = "$ENV{NAWIPS}/os/linux/bin";
    $ENV{GEMPAK}     = "$ENV{NAWIPS}/gempak";

    $ENV{GEMTBL}     = "$ENV{GEMPAK}/tables";
    $ENV{GEMPARM}    = "$ENV{GEMPAK}/parm";
    $ENV{GEMERR}     = "$ENV{GEMPAK}/error";
    $ENV{GEMNTS}     = "$ENV{GEMPAK}/nts";
    $ENV{GEMPDF}     = "$ENV{GEMPAK}/pdf";

    &Others::rm($_) foreach @gemfls;

    #  Create a relative link to the file to avoid problems with GEMPAK and
    #  capital letters in the directory path.
    #
    my $gem = &Others::popit($gempak);
    symlink $gempak => $gem unless -e $gem;

    open (my $gfh, '>', 'gdinfo.in');
    print  $gfh "GDFILE = $gem\n",
                          "LSTALL = Yes\n",
                          "OUTPUT = F\n",
                          "GDATTIM= All\n",
                          "GLEVEL = 0\n",
                          "GVCORD = None\n",
                          "GFUNC  = LAND;PRES;HGHT\n";

    print $gfh "run \n",
               "exit\n";

    close $gfh;

    &Others::rm($gem) if -l $gem;


    #  Run gdinfo and collect the information written to the file. Since the format
    #  of the GEMPAK date/time string is YYMMDD/CC00FHHHHMM, it must be parsed and
    #  reformatted into a workable format.
    #
    system "$gdinfo < gdinfo.in > /dev/null 2>&1";

    open ($gfh, '<', 'gdinfo.fil');

    while (<$gfh>) { chomp;
        next unless /PRES|HGHT|LAND/;
        my @fields = split;
        $fields[1] =~ s/\///g;
        my ($initt, $fcst) = split /F/i => $fields[1];

        #  The next line may need to change with pre-1926 datasets
        #
        $initt = substr($initt,0,2) < 26 ? "20$initt" : "19$initt";

        $initt = &Others::DateString2DateString($initt,'yyyymmddhhmnss');

        $fcst +=0;  $fcst = sprintf '%03d',$fcst;  #  Pad the front of hours

        my $hrs = substr($fcst,0,3);      $hrs +=0;
        my $mns = substr("${fcst}00",3,2);$mns +=0;

        $fcst = $hrs * 3600 + $mns * 60; #  Convert $fcst to seconds

        $fcst = &Others::CalculateNewDate($initt,$fcst);
        $dates{$fcst}  = $n;
        $dates{$initt} = 0;

    } close $gfh;

    &Others::rm($_) foreach @gemfls;

    my @fcsts = sort {$a <=> $b} keys %dates;


return @fcsts;
} #  GempakVerifTimes



sub GempakNumGrids {
#==================================================================================
#  Attempt to determine the current and maximum number of grids allowed in a 
#  GEMPAK file.
#
#  Note:  Unlike other similar routines, there is nothing elegant in
#         this process. This is brute-force sausage making at its wurst.
#         That's a bit of sausage humor for you.
#==================================================================================
#
use File::Spec;

    my $ngrids  = 0;
    my $mgrids  = 0;

    my $gdinfo = "$ENV{GEMEXE}/gdinfo";

    return ($ngrids,$mgrids) unless -x $gdinfo;

    my $gempak = shift;  return ($ngrids,$mgrids) unless (defined $gempak and $gempak and -f $gempak);

    #  Set the GEMPAK environment
    #
    $ENV{NAWIPS}     = "$ENV{EMS_UTIL}/nawips";
    $ENV{GEMEXE}     = "$ENV{NAWIPS}/os/linux/bin";
    $ENV{GEMPAK}     = "$ENV{NAWIPS}/gempak";

    $ENV{GEMTBL}     = "$ENV{GEMPAK}/tables";
    $ENV{GEMPARM}    = "$ENV{GEMPAK}/parm";
    $ENV{GEMERR}     = "$ENV{GEMPAK}/error";
    $ENV{GEMNTS}     = "$ENV{GEMPAK}/nts";
    $ENV{GEMPDF}     = "$ENV{GEMPAK}/pdf";

    &Others::rm($_) foreach qw(gdinfo.fil gdinfo.in gemglb.nts last.nts);

    #  Create a relative link to the file to avoid problems with GEMPAK and
    #  capital letters in the directory path.
    #
    my $ptfile = File::Spec->abs2rel($gempak);
    my $ptloc  = &Others::popit($ptfile); &Others::rm($ptloc);

    unless (-e $ptloc) {return ($ngrids,$mgrids) unless symlink $ptfile => $ptloc;}

    open (my $gfh, '>', 'gdinfo.in');
    print  $gfh "GDFILE = $ptloc\n",
                          "LSTALL = NO\n",
                          "OUTPUT = F\n";

    print $gfh "run \n",
               "exit\n";
    close $gfh;

    &Others::rm($ptloc) if -l $ptloc;

    system "$gdinfo < gdinfo.in > /dev/null 2>&1";

    open ($gfh, '<', 'gdinfo.fil');

    while (<$gfh>) { chomp; s/\s+/ /g;
        $ngrids = $1 if /Number of grids in file:\s*(\d+)/i;
        $mgrids = $1 if /Maximum number of grids in file:\s*(\d+)/i;
    } close $gfh;

    &Others::rm($_) foreach qw(gdinfo.fil gdinfo.in gemglb.nts last.nts);


return ($ngrids,$mgrids);
} #  GempakNumGrids



sub FormatCornerPoints {
#==================================================================================
#  Creates a ascii map of the user domain with the defined corner and
#  center points. Returns the mat in string format for printing.
#==================================================================================
#
    my ($swlat,$swlon,$nwlat,$nwlon,$selat,$selon,$nelat,$nelon,$celat,$celon) = @_;

    #  What gets printed out except with the character placeholders replaced
    #
    my $map = "Corner Lat-Lon points of the domain:\n\n".
              "   NWLAT, NWLON             NELAT, NELON\n".
              "  *                            *\n\n".
              "                 * CELAT, CELON\n\n".
              "  *                            *\n".
              "   SWLAT, SWLON             SELAT, SELON";

    #  Format the lat/lon pairs
    #
    $_ = sprintf ('%-4.2f',$_) foreach ($swlat,$swlon,$nwlat,$nwlon,$selat,$selon,$nelat,$nelon,$celat,$celon) ;

    for ($map) {
        s/SWLAT/$swlat/g;
        s/SWLON/$swlon/g;
        s/NWLAT/$nwlat/g;
        s/NWLON/$nwlon/g;
        s/SELAT/$selat/g;
        s/SELON/$selon/g;
        s/NELAT/$nelat/g;
        s/NELON/$nelon/g;
        s/CELAT/$celat/g;
        s/CELON/$celon/g;
    }


return $map;
}  #  FormatCornerPoints


sub GetPrimeFactors {
#==================================================================================
#  Returns an array of prime factors for a given number.
#  From http://www.perlmonks.org
#==================================================================================
#
    my @primes = ();
    my $num=shift; for(my $n=2;$n <=$num;){next if $num%$n++; $num/=--$n; push @primes => $n;}

return @primes;
} #  GetPrimeFactors


sub Hash2Namelist {
#==================================================================================
#  This routine takes the name of a namelist file, a file serving as a template
#  for the order in which to write out the information, and then a hash containing
#  the information, and writes out the namelist file. 
#==================================================================================
#
    my ($namelist, $template, %hash)  = @_;

    return 1 unless my %nlorder = &NamelistOrder($template);

    #  Open namelist file for writing
    #
    open (my $wfh, '>', $namelist) || return 1;

    foreach my $sect (@{$nlorder{order}}) {

        print $wfh '&',lc $sect,"\n";

        foreach my $field (@{$nlorder{$sect}}) {

            unless ($sect =~ /wizard/i) {
                next unless ( (defined $hash{uc $sect}{$field} and @{$hash{uc $sect}{$field}}) or 
                              (defined $hash{lc $sect}{$field} and @{$hash{lc $sect}{$field}}) ); 
            }

            #  Over time the coding has changed so that the sect key went from UC to LC - allow for both
            #
            if (defined $hash{uc $sect}{$field}) {
                my $valu = join ', ' => @{$hash{uc $sect}{$field}};
                my $line = sprintf ' %-26s = %s',lc $field,$valu;
                print $wfh "$line\n";
            }

            if (defined $hash{lc $sect}{$field}) { 
                my $valu = join ', ' => @{$hash{lc $sect}{$field}};
                my $line = sprintf ' %-26s = %s',lc $field,$valu;
                print $wfh "$line\n";
            }

        }
        print $wfh "/\n\n";

    }
    close $wfh;

return;
} #  Hash2Namelist - Party time!


sub HashMerge {
#==================================================================================
#  This routine takes the values from %hashB and updates the values in %hashA
#  then returns %hashA.
#==================================================================================
#
    my ($hrefA, $hrefB)  = @_;

    my %hashA = %{$hrefA};
    my %hashB = %{$hrefB};
    
    foreach my $sect (keys %hashB) {
        foreach my $field (keys %{$hashB{$sect}}) {
           @{$hashA{$sect}{$field}} = @{$hashB{$sect}{$field}} ;
        }
    }


return %hashA;
} #  HashMerge


sub isInteger {
#==================================================================================
#  This routine returns 1|0 depending whether in input is|is not an integer.
#  In reality, it tests to see whether the passed value is a string of integers
#  so 00000005 would satisfy the condition.
#==================================================================================
#

return (shift =~ /^[-+]?[0-9]*$/) ? 1 : 0;
} #  isInteger


sub isNumber {
#==================================================================================
#  This routine returns 1|0 depending whether in input is|is not an number 
#  (integer, float, or exponential notation).
#==================================================================================
#

return (shift =~ /^[-+]?[0-9]*\.?[0-9]*([eE][-+]?[0-9]+)?$/) ? 1 : 0;
} #  isNumber


sub isPrimeNumber {
#==================================================================================
#  Simple test whether an integer is prime - From http://www.perlmonks.org
#==================================================================================
#
   my $n = shift || return 0;

return (1 x $n) !~ /^1?$|^(11+?)\1+$/;
} #  isPrimeNumber


sub isLocalHost {
#==================================================================================
#  Simple routine to determine whether the hostname passed is that of the
#  local host or one of it's aliases.  For this test the $host hostname 
#  will be compared to the hostnames in the %hostinfo hash.
#
#  Note: Similar to &TestLocalHostname under UEMSsupport
#==================================================================================
#
    my %hostinfo = &SystemAddressInfo();

    for (shift) {
        return 1 if $_ eq 'local';
        return 1 if $_ eq 'localhost';
        return 1 if $_ eq $hostinfo{hostname0};
        return 1 if $_ eq $hostinfo{hostname1};
        return 1 if $_ eq $hostinfo{shost};
        return 1 if $_ eq $hostinfo{address0};
        return 1 if $_ eq $hostinfo{address1};
        return 1 if $_ eq '127.0.0.1';

        foreach my $iface (keys %{$hostinfo{ifaces}}) {
            return 1 if $_ eq $hostinfo{ifaces}{$iface}{HOST};
            return 1 if $_ eq $hostinfo{ifaces}{$iface}{ADDR};
        }
    }

return 0;
} #  isLocalHost


sub LocateX {
#==================================================================================
#  Routine to locate a Linux utility on the system
#==================================================================================
#
    my $rutil = shift; my $util = (-e '/usr/bin/which2') ? `/usr/bin/which --skip-alias --skip-functions --skip-dot --skip-tilde $rutil 2> /dev/null`
                                                         : `which $rutil 2> /dev/null`; chomp $util;

    unless (-s $util and -x $util) {
        $util = `whereis -b $rutil`; chomp $util; if ($util) {my @util = split / / => $util; $util = $#util ? $util[1] : 0;}
        $util = (-s "/usr/bin/$rutil") ? "/usr/bin/$rutil" : (-s "/bin/$rutil") ? "/bin/$rutil" : 0 unless -s $util;
    } chomp $util;


return $util ? $util : 0;
} #  LocateX


sub MissingLibraryCheck {
#==================================================================================
#   This routine accepts a list of dynamic binary routines and an returns
#   a list of missing libraries on the system.
#==================================================================================
#
   my @libs = ();
   my @routines = @_;  return () unless @routines;

   my $ldd  = &Others::LocateX('ldd');
   my $file = &Others::LocateX('file');

   exit unless $ldd;

   foreach (@routines) {
      next unless $_;
      my $type = (grep {/ELF 64-bit/i} `$file $_`) ? '64-bit' : (grep {/ELF 32-bit/i} `$file $_`) ? '32-bit' : 'Unknown';
      foreach (grep {/not found/i} `$ldd $_ 2>&1`) {
          chomp; s/\s//g;
          my @list = split /=/ => $_;
          push @libs => "$type $list[0]";
      }
   }
   @libs = &Others::rmdups(@libs);


return @libs;
} #  MissingLibraryCheck



sub mkdir {
#==================================================================================
#  A wrapper routine for the system mkdir utility
#==================================================================================
#
    my $dir  = shift;

    return 'Missing directory name in &Others::mkdir' unless defined $dir and $dir;

    return 0 if -d $dir;

    my $err = `mkdir -m 755 -p $dir 2>&1`; chomp $err;

return $err;
} #  mkdir


sub Namelist2Hash {
#==================================================================================
#  This routine reads a WRF namelist and writes it to a hash. Each hash contains a
#  list of nl variables with a list of values. So, a hash of lists of lists. Got it.
#  Returns the hash.
#==================================================================================
#
    my $sect = qw{};
    my $tvr  = qw{};
    my %hash = ();

    # namelist is the only argument passed into routine
    #
    my $nl  = shift;

    open (my $rfh, '<', $nl) || return ();
    my @lines = <$rfh>; close $rfh;

    foreach (@lines) {

        chomp;              #  Eliminate trailing newline characters
        tr/\000-\037/ /;    #  Forgot
        s/\s+//g;           #  Eliminate all whitespace
        next unless $_;     #  Empty line - never mind
        next if /^#|^$/;    #  Next line for comments

        #  Don't care about anything following "!"
        #
        my ($line, $comnt) = split /\s*!\s*/, $_, 2;
        next unless $line;  # May be unnecessary but a precaution

        for ($line) {

            $sect = qw{} if $sect and /^\s*(\/)/;

            if ($sect) { #  If section is open
                my ($var, $value) = split(/\s*=\s*/, $_, 2);  # Split at "=" sign

                $var   = qw{} unless defined $var;     #  $var should be defined at this point though
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
    }

return %hash;
} #  Namelist2Hash


sub NamelistOrder {
#==================================================================================
#  This routine reads the contents of a default namelist to get the desired order
#  for the fields printed to the namelists in the users runs. The purpose for this
#  routine is that since the primary namelist list is contained in a hash, making
#  control of the output order difficult unless a template is used.
#==================================================================================
#
    my %hash;
    my $sect;

    # namelist is the only argument passed into routine
    #
    my $nl  = shift;


    open (my $rfh, '<', $nl) || return ();
    my @lines = <$rfh>; close $rfh;

    foreach (@lines) {

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


return %hash;
} #  NamelistOrder


sub isProcessRunning {
#==================================================================================
#  &isProcessRunning simply checks whether a process is running on the target 
#  system. It takes a process ID (PID) and (optional) hostname as arguments and 
#  checks whether the PID exists in the /proc/ directory. 
#
#  &isProcessRunning returns 1 if /proc/PID exists or 0 if not exists
#
#  This routine differs from isProcessRunning2 in that this routine only checks
#  whether the process is running and NOT whether it may be killed by the user.
#==================================================================================
#
    my ($pid, $host) = @_; 

    $host = '' unless defined $host and $host;
    $host = '' if $host =~ /^local/i;

return $host ? &Ret10to01(&FileExistsHost($host,"/proc/$pid")) : &Ret10to01(&FileExists("/proc/$pid"));
}


sub isProcessRunning2 {
#==================================================================================
#  &isProcessRunning2 simply checks whether a process is running on the target 
#  system. It takes a process ID (PID) and (optional) hostname as arguments and 
#  checks whether the PID is active on the host by using the "kill -0" command.
#
#  This routine differs from &isProcessRunning in that this routine checks if 
#  the process is running and if it can be killed by the user. If both latter
#  conditions are true (running & can be killed), &isProcessRunning2 returns 1;
#  otherwise, it returns 0;
#==================================================================================
#
    my ($pid, $host) = @_;

    $host = '' unless defined $host and $host;
    $host = '' if $host =~ /^local/i;

    my $cmd  = $host ? "ssh -q -o BatchMode=yes $host kill -0 $pid > /dev/null 2>&1" : "kill -0 $pid > /dev/null 2>&1";

return &Ret10to01(&Ecore::SysExecute($cmd));
}


sub KillProcessPID {
#==================================================================================
#  &KillProcessPID attempts to kill a process running on a specified host 
#  by using the "kill -9 PID" command. If a hostname is not passed the PID
#  is assumed to be running on the local system.
#
#  Returns 0 if successful (or PID does not exist) or 1 if there is a problem.
#==================================================================================
#
    my ($pid, $host) = @_;

    $host = '' unless defined $host and $host;
    $host = '' if $host =~ /^local/i;

    return 0 unless &isProcessRunning2($pid,$host);

    my $cmd  = $host ? "ssh -q -o BatchMode=yes $host kill -9 $pid > /dev/null 2>&1" : "kill -9 $pid > /dev/null 2>&1";

return &Ecore::SysExecute($cmd);
}


sub PlaceholderFillDate {
#==================================================================================
#  This routine takes a string that contains the various placeholders
#  and returns the string with the placeholders populated in with the
#  appropriate values.
#
#  The date that is passed is assumed to have YYYYMMDDHH[MN[SS]] format
#
#  Input:  $string  - A template string
#          $datestr - A date string YYYYMMDDHH[MN[SS]]
#          @list    - An array of MATCH:VALUE pairs
#==================================================================================
#
    my ($string, $datestr, @list) = @_;

    my @dlist = &Others::DateString2DateList($datestr);

    my $yy   = substr($dlist[0],2,2);

    #  A problem exists in that the reserved characters may actually be
    #  used in the naming convention of the file, directory, etc. Thus,
    #  the "\" will be used to designate a character that is not to be
    #  replaced or is not a placeholder.
    #
    my @chars = $string =~ /(\\\D)/g; # Identify characters to preserve
    $string   =~ s/(\\\D)/\*/g;       # Replace characters with "*"
    s/\\//g foreach @chars;           # Remove leading "\"

    for ($string) {
        s/NMMB/ZZZ/g;
        s/YYYY/$dlist[0]/g if $dlist[0];
        s/YY/$yy/g        if $yy;
        s/MM/$dlist[1]/g   if $dlist[1];
        s/DD/$dlist[2]/g   if $dlist[2];
        s/HH/$dlist[3]/g   if $dlist[3];
        s/CC/$dlist[3]/g   if $dlist[3];
        s/MN/$dlist[4]/g   if $dlist[4];
#       s/SS/$dlist[5]/g   if $dlist[5];
        s/EMSDIR/$ENV{UEMS}/g;
        s/ZZZ/NMMB/g;
    }

    #  Now complete the task of populating the string with any
    #  additional characters.
    #
    $string = &PlaceholderFill($string,$_) foreach (@list);

    #  Replace "*" with original characters
    #
    $string =~ s/\*/$_/ foreach @chars;


return  $string;
} #  PlaceholderFillDate


sub PlaceholderFill {
#==================================================================================
#  This routine takes a string that contains the various placeholders and
#  a string with the placeholders populated with the placeholder values.
#
#  This routine is similar to &PlaceholderFillDate but without the date stuff.
#
#  Input:  $string  - A template string
#          @pairs   - An array of MATCH:VALUE pairs
#==================================================================================
#
    my ($string, @pairs) = @_;

    #  A problem exists in that the reserved characters may actually be
    #  used in the naming convention of the file, directory, etc. Thus,
    #  the "\" will be used to designate a character that is not to be
    #  replaced or is not a placeholder.
    #
    my @chars = $string =~ /(\\\D)/g; # Identify characters to preserve
    $string   =~ s/(\\\D)/\*/g;       # Replace characters with "*"
    s/\\//g foreach @chars;           # Remove leading "\"


    #  Populating the string with "MATCH:VALUE" pairs
    #
    $string = &FillPlaceholders($string,$_) foreach (@pairs);


    #  Replace "*" with original characters
    #
    $string =~ s/\*/$_/ foreach @chars;


return  $string;
} #  PlaceholderFill


sub FillPlaceholders {
#==================================================================================
#  This routine takes a string and a list of placeholder:value pairs and returns
#  the string with the placeholder characters replaced by the values.
#==================================================================================
#
    my ($string, @pairs) = @_;

    foreach (@pairs) {
        my ($wc, $val) = split /:/ => $_, 2; $val = '' unless length $val;
        $string =~ s/$wc/$val/g;
    }
    $string =~ s/\n//g;
    $string =~ s/ //g;


return $string;
} #  FillPlaceholders


sub PackageLogFiles {
#==================================================================================
#  Called in the event of a failed run, this routine tars up most of the
#  necessary log and namelist files for easy emailing.
#==================================================================================
#
use Cwd;

    my $date  = `date -u +%Y%m%d%H`; chomp $date;
    my $tfile = 'DATE.ROUT_crash_logs.tgz';
   
    my ($rundir, $routine, @files) = @_;

    chdir $rundir;  #  Make sure we are in the correct location

    my $logdir  = "$rundir/log";

    $tfile =~ s/DATE/$date/g;
    $tfile =~ s/ROUT/$routine/g;

    foreach my $file (&Others::FileMatch($logdir,'_crash_logs.tgz',0,1)) {&Others::rm($file);}

    system "tar --ignore-failed-read -czf $tfile @files > /dev/null 2>&1";

    my $mesg = "The log files from this failure were written to log/$tfile. Feel free to send the file to a person ".
               "who cares if you need some assistance troubleshooting this problem.";
    &Ecomm::PrintMessage(0,17,104,1,2,$mesg);

    system "mv $tfile $logdir > /dev/null 2>&1";

return;
} #  PackageLogFiles



sub PairWise(&\@\@)  {
#=================================================================
#  The PairWise routine was liberated from &List::MoreUtils module
#  available from GitHub, but because of all the problems caused
#  by having users install a non-standard module, it was easier
#  just to include it.
#=================================================================
#
    my $op = shift;
    use vars qw/@A @B/;
    local (*A, *B) = @_;    # syms for caller's input arrays

    my ($caller_a, $caller_b) = do
    {
        my $pkg = caller();
        no strict 'refs';
        \*{$pkg.'::a'}, \*{$pkg.'::b'};
    };

    my $limit = $#A > $#B? $#A : $#B;    # loop iteration limit

    local(*$caller_a, *$caller_b);
    map    # This map expression is also the return value.
    {
        # assign to $a, $b as refs to caller's array elements
        (*$caller_a, *$caller_b) = \($A[$_], $B[$_]);
        $op->();    # perform the transformation
    }  0 .. $limit;
}


sub popit2 {
#==================================================================================
#  This routine accepts the fully qualified path/filename and returns
#  filename and the path.
#==================================================================================
#
my $file = '';
my $path = '';

    my $str = shift || return ($path,$file);

    for ($str) {
        return ($path,$file) unless $_;

        s/\s+//g;
        s/^\.//g;
        s/\/+/\//g;
        s/\/$//g;

        my @list = split /\// => $_;
        return ($path,$file) unless @list;

        $file = pop @list;
        $path = join '/' => @list;
    }

return ($path,$file);
} #  popit2


sub popitlev {
#==================================================================================
#  This routine accepts the fully qualified path/name and returns 
#  the directory path to the file (included) starting $levs above.
#==================================================================================
#
my $path = qw{};
my $levs = 0;

    ($path, $levs) = @_;

    return qw{} unless defined $path and $path;
    $levs = 0   unless defined $levs and $levs;
    $levs = 999 if $levs < 0;
    $levs = 999 if $levs !~ /\d/g;

    for ($path) {
        s/\s+//g;
        s/^\.//g;
        s/\/+/\//g;
        s/\/$//g;

        my @list = split /\// => $_;
        $levs = $#list if $levs > $#list;
        $path = join '/' => @list[$#list-$levs .. $#list];
    }


return $path;
} #  popitlev


sub popitpath {
#==================================================================================
#  This routine accepts the fully qualified path/filename and returns
#  the name of the path.
#==================================================================================
#
my $file = '';
my $path = '';

    my $str = shift || return $path;

    for ($str) {

        return ($path,$file) unless $_;
        s/\s+//g;
        s/^\.//g;
        s/\/+/\//g;
        s/\/$//g;

        my @list = split /\// => $_;
        return ($path,$file) unless @list;

        $file = pop @list;
        $path = join '/' => @list;
    }


return $path;
} #  popitpath


sub popit {
#==================================================================================
#  This routine accepts the fully qualified path/name and returns just
#  the name of the file or what ever was at the end if the string.
#==================================================================================
#
my $file = qw{};

    my $str = shift || return $file;

    for ($str) {
        return $file unless $_;

        s/\s+//g;
        s/^\.//g;
        s/\/+/\//g;
        s/\/$//g;

        my @list = split /\// => $_;
        $file = pop @list;
    }

return $file;
} #  popit


sub Ret10to01 {
#==================================================================================
#  This subroutine is used to reverse the return value 0 -> 1, 1 -> 0 of another
#  routine.  Used when the user wants a non-zero value to indicate success (failure)
#  subroutine returns 0 or empty string.  It just reverses the return value;
#==================================================================================
#

return (shift) ? 0 : 1;
}


sub ReadLocalConfiguration {
#==================================================================================
#  Collect the configuration files (*.conf) under the specified directory
#  and then reads the individual files while writing the parameters & values
#  to the %parms hash. The parameter values are written to an array that is
#  return in the %parms hash.
#==================================================================================
#
    my %parms = ();
    my $cdir  = shift; return %parms unless -d $cdir;

    foreach my $conf (&FileMatch($cdir,'\.conf$',0,1)) {
        if ($conf =~ /_export/i) {
            @{$parms{EXPORT}} = &ReadConfigurationFile($conf);
        } else {
            my %cparms = &ReadConfigurationFile($conf);
            foreach my $key (keys %cparms) {@{$parms{$key}} = split /,/, $cparms{$key}; foreach (@{$parms{$key}}) {$_+=0 if /^\d+$/;} }
        }
     }

return %parms;
}  #  ReadLocalConfiguration


sub ReadConfigurationFile {
#==================================================================================
#  This routine reads the contents of an individual UEMS configuration file and
#  returns a hash containing parameter-value pairs where the values are contained
#  within a comma separated string. For most files a hash is returned with the 
#  exception of an array being returned for the post_export.conf file.
#==================================================================================
#
    my $filename  = shift;

    my $exp = $filename =~ /export/i;

    my %hash=();
    my @list=();
    my $pvar='';

    open (my $rfh, '<', $filename); my @lines = <$rfh>; close $rfh; foreach (@lines) {chomp; tr/\000-\037/ /; s/^\s+//g;}
    foreach (@lines) {
        next if /^#|^$|^\s+/;
        s/ //g unless /MPIRUNARGS/;
        s/\t//g;s/\n//g;
        next if /^SUITE_/i;

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

return $exp ? @list : %hash;
}


sub ReadVariableNC {
#==================================================================================
#  This routine returns the value of a specified field from a WRF netCDF file.
#  Only works for global attribute fields such as parent_id or SIMULATION_START_DATE.
#  Note that the case of the variable name must match that in the netCDF file!
#  
#  Input:
#         file  - The WRF netcdf file to interrogate
#         field - Field from which to get value
#  Output:
#         value - The value of the field
#==================================================================================
#
    my $rdwrfnc = "$ENV{EMS_UBIN}/rdwrfnc"; return '' unless -x $rdwrfnc;

    my ($file, $field) = @_; 

    chomp $field; $field =~ s/ //g;

    return '' unless -e $file;
    return '' unless $field;

    my $line = `$rdwrfnc -gav $field $file`; chomp $line; $line =~ s/ //g;

    my ($att, $value) = split ':', $line; 

    $value = '' unless defined $value and length $value;
   
return $value;
} #  ReadVariableNC


sub ReadVariableNC_MaxMin {
#==================================================================================
#  This routine returns a maximum or minimum value of a specified field 
#  (you decide) from a WRF netCDF file.
#  
#  Input:
#         file    - The WRF netcdf file to interrogate
#         field   - Field from which to get value
#         desired - either 'Max' or 'Min';
#  Output:
#         value - The value of the field
#==================================================================================
#
    my ($max, $min) = (0,0);

    my $rdwrfnc = "$ENV{EMS_UBIN}/rdwrfnc"; return '' unless -x $rdwrfnc;

    my ($file, $field, $maxmin) = @_; return -9999 unless $maxmin;

    chomp $field; $field =~ s/ //g;

    $max = 1 if $maxmin =~ /max/i;
    $min = 1 if $maxmin =~ /min/i;

    return '' unless $max or $min;
    return '' unless -e $file;
    return '' unless $field;
    

    foreach (`$rdwrfnc -v $field $file`) {
        chomp $_; s/\s+/ /g;
        if (/:\s*MIN\s*=\s*(\d*\.\d+)\s*MAX\s*=\s*(\d*\.\d*)/i) {return $min ? $1 : $2};
     }

return '';
} #  ReadVariableNC


sub ReadVariableNC_LevsMaxMin {
#==================================================================================
#  This routine returns a maximum or minimum value of a specified field 
#  (you decide) from a WRF netCDF file. Uses the UEMS added '-L' flag.
#  
#  Input:
#         file    - The WRF netcdf file to interrogate
#         field   - Field from which to get value
#         desired - either 'Max' or 'Min';
#  Output:
#         a hash containing the maximum & minimum values at each level (key)
#==================================================================================
#
    my %hash = ();

    my $rdwrfnc = "$ENV{EMS_UBIN}/rdwrfnc"; return ()  unless -x $rdwrfnc;

    my ($file, $field) = @_; 

    chomp $field; $field =~ s/ //g;

    return () unless -e $file;
    return () unless $field;
    

    foreach (`$rdwrfnc -L $field $file`) {
        chomp $_; s/\s+/ /g;
        if (/:\s*LEV\s*=\s*(\d+)\s+MIN\s*=\s*(\d*\.\d+)\s*MAX\s*=\s*(\d*\.\d*)/i) {$hash{$1}{min} = $2; $hash{$1}{max} = $3;};
     }

return %hash;
} #  ReadVariableNC


sub ReadVariableNC_XYZ {
#==================================================================================
#  This routine returns the dimensions of a specified field (you decide) 
#  from a WRF netCDF file. Uses the '-v' flag.
#  
#  Input:
#         file    - The WRF netcdf file to interrogate
#         field   - Field from which to get value
#  Output:
#         a hash containing the X, Y, and Z dimensions
#==================================================================================
#
    my %hash    = ();
       $hash{X} = 0;
       $hash{Y} = 0;
       $hash{Z} = 0;

    my $rdwrfnc = "$ENV{EMS_UBIN}/rdwrfnc"; return ()  unless -x $rdwrfnc;

    my ($file, $field) = @_; 

    chomp $field; $field =~ s/ //g;

    return () unless -e $file;
    return () unless $field;
    

    foreach (`$rdwrfnc -v $field $file`) {
        chomp $_; s/\s+/ /g;
        if (/:\s*(\d+)\s*\(x\)\s*(\d+)\s*\(y\)\s*(\d+)\s*\(z\)/i) {$hash{X} = $1; $hash{Y} = $2; $hash{Z} = $3};
    }

return %hash;
} 


sub rmdups {
#==================================================================================
#  This routine eliminates duplicates from a list.
#==================================================================================
#
    my @list=();
    my %temp=();

    foreach (@_) {push @list => $_ if defined $_;}
    return @list unless @list;

    @list = grep ++$temp{$_} < 2 => @list; 


return @list;
} #  rmdups


sub rm {
#==================================================================================
#  This routine deletes files, links and directories if found. Ya, that's all
#==================================================================================
#
my $status = 0;

    foreach (@_) {
        return -1 unless $_;
        if    (-d)       { $status = system "rm -fr $_  > /dev/null 2>&1"; }
        elsif (-f or -l) { $status = system "rm -f  $_  > /dev/null 2>&1"; }
    }


return $status
} #  rm


sub RuntimeEnvironment { 
#==================================================================================
#  Verify that the directory (full path) passed is a viable UEMS run-time 
#  directory, and if so, then set the necessary variables related to the domain.
#  
#  The following variables are assigned and returned via the %hash hash.
#   
#    dompath   - full path to the run-time domain
#    domname   - run-time domain name
#    static    - full path to the run-time /static directory
#    conf      - full path to the run-time /conf directory
#    grbdir    - full path to the run-time /grib directory
#    wpsprd    - full path to the run-time /wpsprd directory
#    wrfprd    - full path to the run-time /wrfprd directory
#    emsprd    - full path to the run-time /emsprd directory
#    rstprd    - full path to the run-time /rstprd (restart) directory
#    logdir    - full path to the run-time /log  directory
#
#    bench     - benchmark case flag - yes (1) or no (0) 
#    core      - run-time model/core ID
#
#    autoconf  - full path to the run-time conf/ems_auto configuration files
#    runconf   - full path to the run-time conf/ems_run configuration files
#    postconf  - full path to the run-time conf/ems_post configuration files
#
#    wpsnl     - full path to the run-time static/namelist.wps file
#    reanl     - full path to the run-time static/namelist.real file
#    wrfnl     - full path to the run-time static/namelist.wrfm file
#
#    wpsnlh    - hash containing the namelist.wps parameters and variables  | ()
#    wrfnlh    - hash containing the namelist.wrfm parameters and variables | ()
#==================================================================================
#
use Cwd;

    my %hash   = ();

    my $emsrun = shift || return %hash;

    #  First thing to do is check whether the <domain>/static and <domain>/conf
    #  directories exist.
    #
    unless (-d "$emsrun/static" and -d "$emsrun/conf") {
        my $mesg = "The $ENV{EMSEXE} routine must be run from a valid run-time directory, and $emsrun isn't one of them!";
        &Ecomm::PrintMessage(9,9,94,1,2,'We thought you had such great potential!',$mesg);
        return ();
    }

    #  The following assignments are duplicates of the global initialization done in Ecore,
    #  but may differ when running ems_autorun.
    #
    $hash{pexe}    = Cwd::realpath($0);
    $hash{emspid}  = $$;
    
    $hash{dompath} = $emsrun;
    $hash{domname} = &Others::popit($emsrun);
    $hash{static}  = "$emsrun/static";
    $hash{conf}    = "$emsrun/conf";
    $hash{grbdir}  = "$emsrun/grib";   &Others::mkdir($hash{grbdir});
    $hash{wpsprd}  = "$emsrun/wpsprd"; &Others::mkdir($hash{wpsprd});
    $hash{wrfprd}  = "$emsrun/wrfprd"; &Others::mkdir($hash{wrfprd});
    $hash{rstprd}  = "$emsrun/rstprd";  
    $hash{emsprd}  = "$emsrun/emsprd"; &Others::mkdir($hash{emsprd});
    $hash{logdir}  = "$emsrun/log";    &Others::mkdir($hash{logdir});

    $hash{bench}   = -e "$hash{static}/.benchmark" ? 1 : 0;
    $hash{core}    = -e "$hash{static}/.arw" ? 'ARW' : 'ARW';  #  keep = 1 until NMM-B

    $hash{autoconf}= "$hash{conf}/ems_auto";
    $hash{runconf} = "$hash{conf}/ems_run"; 
    $hash{postconf}= "$hash{conf}/ems_post";

    #  The following will eventually need to be moved to an conditional statement
    #  for the various models/cores supported, but not right now.
    #
    $hash{wpsnl}   = "$hash{static}/namelist.wps";
    $hash{reanl}   = "$hash{static}/namelist.real";
    $hash{wrfnl}   = "$hash{static}/namelist.wrfm";

    #  While interrogating the run-time directory, read the wpsnl & wrfnl files if they exists
    #
    %{$hash{wpsnlh}} = -e $hash{wpsnl} ? &Others::Namelist2Hash($hash{wpsnl}) : ();
    %{$hash{wrfnlh}} = -e $hash{wrfnl} ? &Others::Namelist2Hash($hash{wrfnl}) : ();


return %hash;
}


sub StringIndexMatch {
#==================================================================================
#  This routine returns the index of the first array element that contains the  
#  the string defined by the first element.
#==================================================================================
#
    my $e = pop @_;

    $e = pop @_ while @_ and $e !~ /$_[0]/;
    @_-1;

} #  StringIndexMatch



sub StringIndexMatchExact {
#==================================================================================
#  This routine returns the index of an array element that exactly matches 
#  the first element.
#==================================================================================
#
    my $e = pop @_;

    $e = pop @_ while @_ and $e ne $_[0];
    @_-1;

} #  StringIndexMatchExact


sub IntegerIndexMatchExact {
#==================================================================================
#  This routine returns the index of an integer array element that exactly matches
#  the first element. Returns -1 if not found.
#
#  Commented out code searches from the last position - modified from 1st - Roz
#==================================================================================
#   my $e = pop @_;
#   $e = pop @_ while @_ and $e != $_[0];
#   @_-1;
#
    my $e = shift @_;
    my $n = @_;
    shift @_ while @_ and $e != $_[0];

return @_ ? $n-@_ : -1;
} #  IntegerIndexMatchExact


sub SystemAddressInfo {
#==================================================================================
#  This routine gathers information about the system hostname(s) and IP address(es)
#  It returns a hash containing stuff it collected.
#==================================================================================
#
use Sys::Hostname;
use Net::hostent;
use Socket;

    my %info = ();

    #------------------------------------------------------------------
    #  Get basic hostname and IP information
    #------------------------------------------------------------------
    #
    my $host0 = hostname;
    my $shost = $host0;


    #------------------------------------------------------------------
    #  Check whether the hostname can be resolved via NIS/DNS. First
    #  initialize the variables.
    #------------------------------------------------------------------
    #
    my $host1 = '';
    my $addr0 = `hostname -i`;
    my $addr1 = 'None available';

    #------------------------------------------------------------------
    #
    if (my $h = gethost($host0)) {  #  Is resolved vo
       $host1 = $h->name;
       $addr0 = inet_ntoa($h->addr);
       unless (system "host $host1 > /dev/null 2>&1") {
           my @hi = split / +/ => `host $host1`; $addr1 = $hi[-1];
       }
    }


    $info{hostname0} = $host0;
    $info{hostname1} = ($host1 and $host1 ne $host0) ? $host1 : 'None';
    $info{nhost}     = $host1 ? $host1 : $host0;
    $info{lhost}     = $info{nhost};
    $info{shost}     = $shost;
    
    $info{address0}  = $addr0;
    $info{address1}  = $addr1;

    foreach my $key (keys %info) {chomp $info{$key};}

    $info{hosts_file} = q{};
    if ($addr0 ne $addr1) {  # Read the /etc/hosts file for additional information
        open (my $fh, '<', '/etc/hosts'); my @hosts = <$fh>; close $fh; foreach (@hosts) {chomp; s/^\s*/    /g; s/\s+$//g;}
        $info{hosts_file} = join "\n" => @hosts;
    }

    #---------------------------------------------------------------
    #  Collect the interface information should it be needed
    #---------------------------------------------------------------
    #
    %{$info{ifaces}} = &SystemIfaceInfo();

 
    #  Finally, check the system date & time.  There really isn't any good place for this.
    #  
    my $date = gmtime(); chomp $date;
    $info{sysdate} = $date;


return %info;
} #  SystemAddressInfo



sub SystemCpuInfo1Host {
#==================================================================================
#  The SystemCpuInfo1Host routine is similar to SystemCpuInfo1 in that it attempts
#  to read the /proc/cpuinfo and process the information about the system CPUs. The
#  difference is that this routine uses ssh to read the file on the specified remote 
#  system.
#==================================================================================
#
    my $href = shift;
    my %info = %{$href};

    #  The list of temporary variables used
    #
    my ($modelname, $processor, $cpucores, $siblings, $bogomips) = (0, 0, 0, 0, 0);
    my %phyid   = ();
    my %coreid  = ();
    my @coreids = ();
    my @lines   = ();

    if ($info{host}) {  #  Get information froma remote system
        return %info if &Ecore::SysExecute("ssh -q -o BatchMode=yes $info{host} ls /proc/cpuinfo  > /dev/null 2>&1");

        @lines = `ssh -q -o BatchMode=yes $info{host} cat /proc/cpuinfo   2>&1`;
        foreach (@lines) {chomp; s/^\s*/    /g; s/\s+$//g;}
    }
    return %info unless @lines;


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
    my $amd = ($modelname =~ /amd/i) ? 1 : 0;


    $processor = 1 unless $processor;
    $cpucores+=0; $cpucores = 1 unless $cpucores;
    $siblings+=0; $siblings = 1 unless $siblings;
    $bogomips+=0; $bogomips = 0 unless $bogomips;

    my $sockets   = keys %phyid;  $sockets = 1 unless $sockets; #  The number of sockets on the system
    my $thrdscore = int ($siblings/$cpucores);


    #  The number of "cpu cores" should be the same as the number of unique core IDs.
    #  Note that @coreids is not currently used.
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

    $info{cputype}          = `/bin/uname -p`; chomp $info{cputype};
    $info{microarch}        = 'Unknown';


return %info;
} #  SystemCpuInfo1


sub SystemCpuInfo1 {
#==================================================================================
#  This routine attempts reads the /proc/cpuinfo file and return valuable
#  CPU related information.
#==================================================================================
#
    my $href = shift;
    my %info = %{$href};


    #  The list of temporary variables used
    #
    my ($modelname, $processor, $cpucores, $siblings, $bogomips) = (0, 0, 0, 0, 0);
    my %phyid   = ();
    my %coreid  = ();
    my @coreids = ();

    return %info unless -e '/proc/cpuinfo';

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
    my $amd = ($modelname =~ /amd/i) ? 1 : 0;


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

    $info{cputype}          = `/bin/uname -p`; chomp $info{cputype};
    $info{microarch}        = 'Unknown';

    if (my $cpuid = &LocateX('cpuid')) {
        foreach (`$cpuid`) {
            chomp; s/ //g;
            if (/^type/i) {
                my ($u, $t) = split /:/ => $_, 2;
                $t =~ s/-tp//g; $t =~ s/-64//g;
                $info{microarch} = $t;
            }
        }
    }


return %info;
} #  SystemCpuInfo1


sub SystemCpuInfo2Host {
#==================================================================================
#  The SystemCpuInfo2Host routine is similar to SystemCpuInfo2 in that it attempts
#  to process the information from the Linux lscpu utility about the system CPUs.
#  The difference is that this routine uses ssh to run the command on the specified 
#  remote system.
#==================================================================================
#
    my $href = shift;
    my %info = %{$href};

    return %info unless $info{host};

    #  The list of temporary variables used
    #
    my ($modelname, $sockets, $totlcores, $cpucores, $thrdscore, $bogomips, $cpuarch) = (0, 0, 0, 0, 0, 0, 0);
    my %phyid   = ();
    my %coreid  = ();
    my @coreids = ();

    return %info if &Ecore::SysExecute("ssh -q -o BatchMode=yes $info{host} ls /usr/bin/lscpu > /dev/null 2>&1");

    my @lines = `ssh -q -o BatchMode=yes $info{host} /usr/bin/lscpu 2>&1`;
    return %info unless @lines;

    foreach (@lines) {
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

    unless ($cpuarch) {$cpuarch = `/bin/uname -p`; chomp $cpuarch;}

    $info{model_name}       = $modelname unless $info{model_name};
    $info{cputype}          = $cpuarch ? $cpuarch : 'Unknown';
    $info{sockets}          = $sockets;
    $info{cores_per_socket} = $cpucores;
    $info{total_cores}      = $cpucores*$sockets;
    $info{threads_per_core} = $thrdscore;
    $info{cpu_speed}        = sprintf('%.3f',0.001*int($bogomips*0.5));
    $info{ht}               = (! $amd and $thrdscore > 1) ? 1 : 0;
    $info{amd}              = $amd;
    $info{microarch}        = 'Unknown';


return %info;
} #  SystemCpuInfo2Host


sub SystemCpuInfo2 {
#==================================================================================
#  This routine attempts to mine the output from the lscpu command for valuable
#  CPU related information, and then returns it.
#==================================================================================
#
    my $href = shift;
    my %info = %{$href};

    return %info unless -e '/usr/bin/lscpu';

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

    unless ($cpuarch) {$cpuarch = `/bin/uname -p`; chomp $cpuarch;}

    $info{model_name}       = $modelname unless $info{model_name};
    $info{cputype}          = $cpuarch ? $cpuarch : 'Unknown';
    $info{sockets}          = $sockets;
    $info{cores_per_socket} = $cpucores;
    $info{total_cores}      = $cpucores*$sockets;
    $info{threads_per_core} = $thrdscore;
    $info{cpu_speed}        = sprintf('%.3f',0.001*int($bogomips*0.5));
    $info{ht}               = (! $amd and $thrdscore > 1) ? 1 : 0;
    $info{amd}              = $amd;
    $info{microarch}        = 'Unknown';

    if (my $cpuid = &LocateX('cpuid')) {
        foreach (`$cpuid`) {
            chomp; s/ //g;
            if (/^type/i) {
                my ($u, $t) = split /:/ => $_, 2;  
                $t =~ s/-tp//g; $t =~ s/-64//g; 
                $info{microarch} = $t;
            }
        }
    }


return %info;
} #  SystemCpuInfo2


sub SystemCpuInfo {
#==================================================================================
#  This routine attempts to gather information about the CPUs on the system,
#  through use of the "lscpu" command and interrogating the /proc/cpuinfo file.
#  Ideally, just the lscpu commend would be used because it tends to provide more
#  accurate information on whether hyper-threading is turned ON but neither
#  method is perfect.
#==================================================================================
#
    my $host = shift || 0;

    my %info = ();
       $info{host} = $host;


    if ($host) { 
       %info = &SystemCpuInfo1Host(\%info);
       %info = &SystemCpuInfo2Host(\%info);
    } else {
       %info = &SystemCpuInfo1(\%info);
       %info = &SystemCpuInfo2(\%info);
    }


    #  User messages of love and encouragement.
    #
    my %mesgs=();

       $mesgs{intht} = "Note:  Attempting to use virtual \"Hyper-threaded\" CPUs while running the UEMS may result in a degradation in performance.";

       $info{message}= $info{ht} ? $mesgs{intht} : ' ';


return %info;
} #  SystemCpuInfo


sub SystemIfaceInfo {
#==================================================================================
#  SystemIfaceInfo interrogates the local system network interfaces and returns
#  a hash containing the interface name, hostname, and IP address, where:
#
#      $iface                  - The name in the network interface
#      $myfaces{$iface}{ADDR}  - The IP address associated with the interface
#      $myfaces{$iface}{HOST}  - Hostname if available
#      $myfaces{$iface}{STATE} - Interface state (Up || Inactive)
#==================================================================================
#
use Socket;
use Net::hostent;


    #------------------------------------------------------------------------
    #  Start by collecting all the network interfaces on the local system
    #------------------------------------------------------------------------
    #
    my %myfaces = ();
    my %lips    = ();
    my $iface   = qw{};

    foreach ( qx{ (LC_ALL=C /sbin/ifconfig -a 2>&1) } ) {

        $iface = $1 if /^(\S+?):?\s/;
        next unless defined $iface;

        $myfaces{$iface}{HOST}  = '' unless defined $myfaces{$iface}{HOST};
        $myfaces{$iface}{ADDR}  = '' unless defined $myfaces{$iface}{ADDR};
        $myfaces{$iface}{STATE} = '' unless defined $myfaces{$iface}{STATE};

        $myfaces{$iface}{STATE} = 'Up'  if /\b(up )\b/i;
        $myfaces{$iface}{ADDR}  = $1    if /inet\D+(\d+\.\d+\.\d+\.\d+)/i;

        if ($myfaces{$iface}{ADDR} and ! $myfaces{$iface}{HOST}) {
            if (my $ah = gethostbyaddr(inet_aton($myfaces{$iface}{ADDR}), AF_INET) ){
                $myfaces{$iface}{HOST} = $ah->name;
            }
        }
    }


return %myfaces;
}


sub SystemInformationHost {
#==================================================================================
#  This routine attempts to gather information about a system for configuration
#  and informational purposes. It's different from the SystemInformation routine
#  in that it uses SSH to run the uemsinfo routine on a remove system to collect
#  the information. Consequently, it's important that passwordless SSH be tested
#  between the local and remote hosts prior to calling SystemInformationHost. This
#  routine will also run "uemsinfo" on the local host (no SSH) if necessary should
#  you be looping through a list of hostnames.
#
#  Input : $host - A hostname or IP address
#          $islh - Either 1 (is the local host) or 0 (not local host)
#
#  Output: A hash containing the output from the $EMS_STRC/Ubin/emsinfo routine.
#==================================================================================
#
    my %sysinfo=();      #  Hash used to collect all the information

    my ($host, $islh)  = @_;

    $sysinfo{error} = "!  Error locating UEMS on $host ($ENV{EMS_STRC}/Ubin/uemsinfo)";

    #  Check whether the UEMS is installed on the remote system and emsinfo is available.
    #
    return %sysinfo if ! $islh and &FileExistsHost($host,"$ENV{EMS_STRC}/Ubin/uemsinfo");

    %sysinfo = $islh ? %{ eval `$ENV{EMS_STRC}/Ubin/uemsinfo $host` } : %{ eval `ssh $host $ENV{EMS_STRC}/Ubin/uemsinfo $host` };


return %sysinfo;
}


sub SystemInformation {
#==================================================================================
#  This routine attempts to gather information about a system for configuration
#  and informational purposes.  It calls the appropriately named routines to
#  collect the desired information before packaging it up into a string suitable
#  for framing, printing, or returning.
#==================================================================================
#

    my %sysinfo=();  #  Hash used to collect all the information
    my %hash   =();

    %hash = &SystemAddressInfo(); foreach my $key (keys %hash) {$sysinfo{$key} = $hash{$key};}
    %hash = &SystemLinuxInfo();   foreach my $key (keys %hash) {$sysinfo{$key} = $hash{$key};}
    %hash = &SystemCpuInfo();     foreach my $key (keys %hash) {$sysinfo{$key} = $hash{$key};}
    %hash = &SystemMemoryInfo();  foreach my $key (keys %hash) {$sysinfo{$key} = $hash{$key};}

return %sysinfo;
} #  SystemInformation


sub SystemLinuxInfo {
#==================================================================================
#  This routine attempts to mine information on the Linux distribution running
#  the system. It's a simple approach but should work for most systems. It returns
#  a hash containing the Linux distribution name, architecture, and more stuff.
#  Note that the Perl "Config" hash/module could also be used in place of some
#  system calls but it assumes the module is installed on the user's system.
#==================================================================================
#
    my %info = ();

    #  Get OS information
    #
    $info{os}      = (`/bin/uname` =~ /linux/i) ? 'Linux' : 'Non Linux';
    $info{kernel}  = `/bin/uname -r`; my @list = split /\./ => $info{kernel};
    $info{cputype} = `/bin/uname -p`;
    $info{hwtype}  = `/bin/uname -i`;
    $info{ostype}  = $list[-1];

    #  Try to determine the distribution name and version
    #
    my $distro     = q{};

    if (-e '/usr/bin/lsb_release') {  #  Not always available
        $distro = `/usr/bin/lsb_release -ds`;
    } else {
        my @files = qw (os-release redhat-release fedora-release debian_version UnitedLinux-release 
                        SuSE-release slackware-version mandrake-release gentoo-release);
        foreach (@files) {$distro = `cat /etc/$_` if -e "/etc/$_";}
        $distro = `cat /etc/*-release` unless $distro;
    }
    $info{distro} = $distro ? $distro : 'Unknown';  $info{distro} =~ s/\"//g;

    foreach my $key (keys %info) {chomp $info{$key};}


return %info;
} #  SystemLinuxInfo


sub SystemMemoryInfo {
#==================================================================================
#  This routine attempts to gather information about the amount of physical memory
#  installed on the system by interrogating the /proc/meminfo file.
#==================================================================================
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
} #  SystemMemoryInfo


sub SystemUemsInfo {
#==================================================================================
#  This routine collects information about the UEMS such as the directory location,
#  UEMS & WRF version, and configuration.
#==================================================================================
#
use File::stat;

    my %info    = ();
    $info{uems} = (defined $ENV{UEMS} and -d $ENV{UEMS}) ? 'Installed' : 'Not Installed';
    
    return %info if $info{uems} eq 'Not Installed';

    $info{uemsvers} = &Elove::GetUEMSrelease($ENV{UEMS});
    $info{wrfvers}  = &Elove::GetWRFrelease($ENV{UEMS});
    
    my $uems = stat($ENV{UEMS});
    
    $info{emshome}  = $ENV{UEMS};
    $info{emsuid}   = $uems->uid;
    $info{emsgid}   = $uems->gid;
    $info{emsname}  = getpwuid $info{emsuid};
    $info{emsmount} = (`stat -f -L -c %T $ENV{UEMS}` =~ /nfs/i) ? 'NFS' : 'Local';
    $info{emscores} = (defined $ENV{CORES})   ? $ENV{CORES} : 0;
    $info{emsncpus} = (defined $ENV{SOCKETS}) ? $ENV{SOCKETS} : 0;  # $info{emsncpus} remains for legacy reasons
    $info{totcores} = $info{emsncpus} * $info{emscores};

    $info{emsgname} = getgrgid $info{emsgid};  #  Get group name

    $info{emsrun}   = 0;

    if ($ENV{EMS_RUN} and -d $ENV{EMS_RUN}) {

        my $rund = stat($ENV{EMS_RUN});

        $info{emsrun} = $ENV{EMS_RUN};

        $info{runduid}  = $rund->uid;
        $info{rundgid}  = $rund->gid;
        $info{rundname} = getpwuid $info{runduid};
        $info{rundgname}= getgrgid $info{rundgid};
        $info{runmount} = (`stat -f -L -c %T $ENV{EMS_RUN}` =~ /nfs/i) ? 'NFS' : 'Local';

        #  Get disk space info on Run directory
        #
        my @df = split / +/ => qx (df -m $ENV{EMS_RUN} | grep -v system);

        $info{partition}  = $df[0];
        $info{disk_total} = floor (100. * $df[1]/1024); $info{disk_total} = $info{disk_total} * 0.01;
        $info{disk_used}  = floor (100. * $df[2]/1024); $info{disk_used}  = $info{disk_used}  * 0.01;
        $info{disk_avail} = floor (100. * $df[3]/1024); $info{disk_avail} = $info{disk_avail} * 0.01;

    }
    $info{bindir}  = 0;
    $info{emsutil} = ($ENV{EMS_UTIL} and -d $ENV{EMS_UTIL}) ? $ENV{EMS_UTIL} : 0;
    $info{utilbin} = $info{emsutil} ? "$info{emsutil}/bin" : 0;
     
    my @bins = ();
    if ($ENV{EMS_BIN} and -d $ENV{EMS_BIN}) {
        opendir (my $dfh, $ENV{EMS_BIN}); @bins = grep /^\.\w+/ , readdir $dfh; closedir $dfh;
        $info{bindir} = $ENV{EMS_BIN};
    } 
    s/^\.//g foreach @bins;
    $info{emsbin} = @bins ? join ', ' => @bins : 'Unknown or Non UEMS';
        

return %info;
} #  SystemUemsInfo


sub SystemUserInfo {
#==================================================================================
#  This routine collects information about the user such as the home directory,
#  shell being used, number and group.
#==================================================================================
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
    $info{mount} = (`stat -f -L -c %T $uinfo[7]` =~ /nfs/i) ? 'NFS' : 'Local';

    @uinfo = getgrgid $info{gid};

    $info{gname} = $uinfo[0];  #  Get group name


return %info;
} #  SystemUserInfo


