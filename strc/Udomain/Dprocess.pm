#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Dprocess.pm
#
#  DESCRIPTION:  Dprocess contains subroutines used by multiple ems_domain
#                modules. No real organization, just a dumping ground.
#
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Dprocess;

use warnings;
use strict;
require 5.008;
use English;

use Others;
use Ecore;
use Ecomm;


sub DomainReadMasterNamelist {
#==================================================================================
#  Read the run-time domain namelist.wps file and define necessary variables
#==================================================================================
#
use Dutils;

    my %masternl = ();

    my $nlfile = shift || return %masternl;

    return () unless %masternl = &Others::Namelist2Hash($nlfile);

    #  Make sure tat there is only a single entry for the ref I/J values.
    #
    @{$masternl{GEOGRID}{ref_x}} = ();
    @{$masternl{GEOGRID}{ref_y}} = ();
    $masternl{GEOGRID}{ref_x}[0] = $masternl{GEOGRID}{e_we}[0]/2;
    $masternl{GEOGRID}{ref_y}[0] = $masternl{GEOGRID}{e_sn}[0]/2;


    ($masternl{core}    = uc $masternl{SHARE}{wrf_core}[0]) =~ s/'//g;
    $masternl{global}   = ($masternl{GEOGRID}{map_proj}[0]  =~ /lat-lon/i and ! defined $masternl{GEOGRID}{dx}) ? 1 : 0;
    $masternl{maxdoms}  = scalar @{$masternl{GEOGRID}{parent_id}};

    
    #---------------------------------------------------------------------------------
    #  Parse the geog_data_res parameter from the namelist.wps file and eliminate
    #  duplicate values and errors such as bad dataset IDs. This routine is not
    #  been tested thoroughly and may have errors, but I hope not.
    #
    #  Eliminate multiple static datasets for any one category by selecting 
    #  the first dataset specified.
    #---------------------------------------------------------------------------------
    #
    foreach my $dset ('landuse', 'lakes', 'topo', 'gfrac', 'stype', 'lai', 'gwd') {@{$masternl{$dset}} = ();}

    my $ret   = '';
    foreach (@{$masternl{GEOGRID}{geog_data_res}}) {s/\'|\"//g;

        my (@lu, @te, @gf, @st, @la, @gw) = () x 6;

        foreach my $dset (split '\+', $_) { next unless $dset and $dset ne 'default';
            $ret = &Dutils::LookupLanduseDataset($dset,1);         push @lu, $ret if $ret;
            $ret = &Dutils::LookupTerrainDataset($dset,1);         push @te, $ret if $ret;
            $ret = &Dutils::LookupGreenFractionDataset($dset,1);   push @gf, $ret if $ret;
            $ret = &Dutils::LookupSoilTypeDataset($dset,1);        push @st, $ret if $ret;
            $ret = &Dutils::LookupLeafAreaIndexDataset($dset,1);   push @la, $ret if $ret;
            $ret = &Dutils::LookupGravityWaveDragDataset($dset,1); push @gw, $ret if $ret;
        }

        my $lus = @lu ? shift @lu : '';  # Was $lus = @lu ? join '+', &Others::rmdups(@lu) : '';
        my $tes = @te ? shift @te : '';  # Was $tes = @te ? join '+', &Others::rmdups(@te) : '';
        my $gfs = @gf ? shift @gf : '';  # Was $gfs = @gf ? join '+', &Others::rmdups(@gf) : '';
        my $sts = @st ? shift @st : '';  # Was $sts = @st ? join '+', &Others::rmdups(@st) : '';
        my $las = @la ? shift @la : '';  # Was $las = @la ? join '+', &Others::rmdups(@la) : '';
        my $gws = @gw ? shift @gw : '';  # Was $gws = @gw ? join '+', &Others::rmdups(@gw) : '';

        push @{$masternl{landuse}}, $lus;
        push @{$masternl{topo}},    $tes; 
        push @{$masternl{gfrac}},   $gfs; 
        push @{$masternl{stype}},   $sts;
        push @{$masternl{lai}},     $las;
        push @{$masternl{gwd}},     $gws;

        $_ = join '+', ($lus,$tes,$gfs,$las,$sts,$gws,'default'); s/\++/+/g; s/^\+//g; s/\+$//g; $_ = "\'$_\'";
    }


    $masternl{SHARE}{max_dom}[0]     = $masternl{maxdoms};
    @{$masternl{SHARE}{active_grid}} = ('.true.') x $masternl{maxdoms};


    #  Delete those parts of the namelist about which we are not interested
    #
    delete $masternl{METGRID};
    delete $masternl{UNGRIB};

return %masternl;
}


sub DomainWriteMasterNamelist {
#=====================================================================================
#  Write the contents of the namelist hash to the static/namelist.wps file.
#  Well, sort of, since it's just interface to the 
#=====================================================================================
#
    my $upref      = shift;
    my %Udomain = %{$upref};

    my %masternl   = %{$Udomain{MASTERNL}}; 
    my $namelist   = $Udomain{EMSRUN}{wpsnl};
    my $template   = "$ENV{EMS_DATA}/tables/wps/namelist.wps";  #  Hardcoded - which I don't like


    #----------------------------------------------------------------------------------
    #  Save the current namelist to $namelist.prev and make sure the permissions 
    #  are correct for the file to be overwritten.
    #----------------------------------------------------------------------------------
    #
    if (-e $namelist)  {  #  The namelist should exist but just in case

        if (-e "$namelist.prev" and ! chmod 0664, "$namelist.prev") {
            my $mesg = "Well something is not correct since I am unable to set the permissions of the namelist.wps.prev ".
                       "file in preparation for over-writing namelist.wps -> namelist.wps.prev). Perhaps you are not ".
                       "the lawful owner of the file?\n\n".
                       "The UEMS police are on the way.";
            $ENV{DMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Stay where you are',$mesg);
            return 1;
        }

        if (system "cp -f $namelist $namelist.prev  > /dev/null 2>&1") {
            my $mesg = "Well something is not correct as I am unable to make a copy of the namelist.wps file ".
                       "(namelist.wps.prev). Maybe the permissions are not set properly or you are not the ".
                       "owner (namelist rustler!), but figure out what went wrong and get back to me.\n\n".
                       "Get back to me real soon!";
            $ENV{DMESG} = &Ecomm::TextFormat(0,0,88,0,0,'Pay Attention',$mesg);
            return 1;
        }

    }


    #----------------------------------------------------------------------------------
    #  Next write out the namelist.wps file with the contents of the %masternl hash
    #  but make sure we save any existing files. The $template file provides the
    #  correct order & format.
    #
    #  COMPLETE:  Need to make sure return is handled correctly.
    #----------------------------------------------------------------------------------
    #
    if (&Others::Hash2Namelist($namelist,$template,%masternl)) {
        $ENV{DMESG} = &Ecomm::TextFormat(0,0,88,0,0,'The Hash2Namelist routine',"BUMMER: Problem writing $namelist");
        return 1;
    }

    &Others::rm("$namelist.prev") if $Udomain{CONF}{mcserver};


return;
}


sub DomainRuntimeEnvironment {
#===============================================================================
#  Set the run-time environment for running ems_domain 
#===============================================================================
#
    my %hash   = ();

    my $emsrun = Cwd::realpath(shift) || return %hash;

    return () unless %hash = &Others::RuntimeEnvironment($emsrun);

    #  Make sure the GRIB directory exists
    #
    if (my $err = &Others::mkdir($hash{grbdir})) {
        my $mesg = "There I was, just checking on your $hash{domname}/grib directory, and something broke.\n\n".
                   "Error: $err";
        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'I made this mess, now you clean it up!',$mesg));
    }

    #  Has the domain been localized?  Check by looking for the "geo_*.nc" files 
    #  in the static directory.
    #
    @{$hash{geofls}} = sort &Others::FileMatch($hash{static},'^geo_(.+)\.d\d\d\.nc$',1,0);


return %hash;
}


sub UpdateMasterNamelistPaths {
#=====================================================================================
#  Read the run-time domain namelist.wps file and define necessary variables
#=====================================================================================
#
use List::Util qw(max);
use Dutils;

    my $upref      = shift;
    my %Udomain = %{$upref};

    my %masternl   = %{$Udomain{MASTERNL}};

    $masternl{SHARE}{opt_output_from_geogrid_path}[0] = "\'$Udomain{EMSRUN}{static}\'";
    $masternl{GEOGRID}{geog_data_path}[0] = "\'$ENV{EMS_DATA}/geog\'";
    $masternl{GEOGRID}{opt_geogrid_tbl_path}[0] = "\'$Udomain{EMSRUN}{static}\'";

    $masternl{domname} = $Udomain{EMSRUN}{domname}; # Because we'll need this later


return %masternl;
}


sub UpdateMasterNamelistDomain {
#=====================================================================================
#  Read the run-time domain namelist.wps file and define necessary variables
#=====================================================================================
#   
    my $mesg       = qw{};
    my %masternl   = ();

    my $upref      = shift;
    my %Udomain = %{$upref};  


    my $domname = $Udomain{EMSRUN}{domname};
    my $dompath = $Udomain{EMSRUN}{dompath};
    my $static  = $Udomain{EMSRUN}{static};

    my $core    = lc $Udomain{EMSRUN}{core} || 'arw';

    my $dwiz    = $Udomain{CONF}{dwiz};
    my $info    = $Udomain{CONF}{info};

    #  Determine whether this is a global domain
    #
    my $global  = ($Udomain{CONF}{global} || $Udomain{MASTERNL}{global}) ? 1 : 0;
    my $lamdom  = $global ? 0 : 1;


    #-------------------------------------------------------------------------
    #  Configure the global or limited area domain as requested.
    #-------------------------------------------------------------------------
    #
    %{$Udomain{MASTERNL}} =  &ConfigureGlobalDomain(\%Udomain)      if $global;
    %{$Udomain{MASTERNL}} =  &ConfigureLimitedAreaDomain(\%Udomain) if $lamdom;

    %{$Udomain{MASTERNL}} =  &UpdateGeographicDatasets(\%Udomain);
    %{$Udomain{MASTERNL}} =  &UpdateUpdateMasterNamelistDwiz(\%Udomain);

    %masternl   = %{$Udomain{MASTERNL}};  # Really not necessary

    if (&DomainProjectionCheck($core, $masternl{GEOGRID}{map_proj}[0])) {
        $mesg = "The map projection specified in the static/namelist.wps file ($masternl{GEOGRID}{map_proj}[0]) ".
                "is not compatible with the with the $core core. You will need to change one or the other before ".
                "continuing your journey towards NWP enlightenment and eternal and internal modeling peace.";
        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,"Something must change and it's not me!",$mesg));
    }


    #-------------------------------------------------------------------------
    #  Write the %masternl hash (via %Udomain) to the namelist.wps file.
    #-------------------------------------------------------------------------
    #  
    &DomainWriteMasterNamelist(\%Udomain);


    #-------------------------------------------------------------------------
    #  Finally, print information to the screen if requested
    #-------------------------------------------------------------------------
    #
    &DomainPrintInformation(\%masternl) if $info;

    
return %masternl;  #  Let's go home
}


sub UpdateGeographicDatasets {
#=====================================================================================
#  This routine configures the geog_data_res line in the GEOGRID section of the
#  namelist.wps file.
#=====================================================================================
#
    my (@dste, @dslu, @dsgf, @dsst, @dsla) = () x 5;

    my $refh = shift;  my %Udomain = %$refh;

    my %masternl = %{$Udomain{MASTERNL}};
    my %confs    = %{$Udomain{CONF}};


#   print "In  geog_data_res:  @{$masternl{GEOGRID}{geog_data_res}}\n";
    #------------------------------------------------------------------------------------------
    #  Eliminate the USGS dataset in favor of the default GMTED unless USGS is installed,
    #  which it is not by default.
    #------------------------------------------------------------------------------------------
    #
    unless (grep /^topo_/ => @{$Udomain{GEOG}{datasets}}) {
        map {s/gtopo_\d+[s|m]//g;s/\++/+/g;s/^\+//g;s/\+$//g;} @{$masternl{GEOGRID}{geog_data_res}};
    }


    #------------------------------------------------------------------------------------------
    #  Determine whether further configuration is necessary. If the neither the 
    #  --defres flag nor the --landuse, --topo, --lakes, --gfrac, --stype, or
    #  --gwdo flags were passed, then simply exit.
    #------------------------------------------------------------------------------------------
    #
    return %masternl unless $confs{landuse} || $confs{topo} || $confs{lakes} || $confs{gfrac} || $confs{stype};


    #------------------------------------------------------------------------------------------
    #  Stuff we'll need for the trip
    #------------------------------------------------------------------------------------------
    #
    my $dwdx   = $masternl{dwdx};
    my $global = ($confs{global} || $masternl{global}) ? 1 : 0;


    #------------------------------------------------------------------------------------------
    #  Define the relationship between degrees and distance (km) at the equator for 
    #  the various terrestrial datasets available with the WRF.
    #------------------------------------------------------------------------------------------
    #
   
    #  LANDUSE datasets and resolutions
    #
    my %lures = ();
       %{$lures{usgs}}     = (18.52=>'usgs_10m', 9.26=>'usgs_5m' , 3.37=>'usgs_2m' , 0.92=>'usgs_30s', 0=>'usgs_30s');
       %{$lures{modis}}    = ( 0.92=>'modis_30s', 0.46=>'modis_15s', 0=>'modis_30s');
       %{$lures{ssib}}     = (18.52=>'ssib_10m', 9.26=>'ssib_5m' , 0=>'ssib_5m' );
       %{$lures{nlcd2006}} = ( 0.92=>'nlcd2006_30s', 0.28=>'nlcd2006_9s' , 0=>'nlcd2006_30s');
       %{$lures{nlcd2011}} = ( 0.28=>'nlcd2011_9s' , 0=>'nlcd2011_9s');

 
    #  HGT_M datasets and resolutions
    #
    my %htres = ();
       %{$htres{gmted2010}}= ( 0.92=>'gmted2010_30s', 0=>'');
       %{$htres{gtopo}}    = (18.52=>'gtopo_10m', 9.26=>'gtopo_5m', 3.37=>'gtopo_2m', 0.92=>'gtopo_30s', 0=>'gtopo_30s');


    #  Currently not used but serves as a reference for the developer
    #
    #my %dsres = ('2deg'=>222.25, '1deg'=>111.125, '30m'=>55.56, '20m'=>37.04, '10m'=>18.52, '5m'=>9.26, '2m'=>3.37, '30s'=>0.92, '15s'=>0.46);


    # --------------------------------------------------------------------------------
    #  Loop through the domains and assign the geog_data_res string based upon 
    #  the grid spacing of that domain.  
    # --------------------------------------------------------------------------------
    #
    for my $i (0 .. $masternl{SHARE}{max_dom}[0]-1) {

        my @gdsets = ('default');


        my $p = $masternl{GEOGRID}{parent_id}[$i];
        my $r = $masternl{GEOGRID}{parent_grid_ratio}[$i];

        while ($p > 1) {
            $r = $r * $masternl{GEOGRID}{parent_grid_ratio}[$p-1];
            $p = $masternl{GEOGRID}{parent_id}[$p-1];
        }


        #------------------------------------------------------------------------------------------
        #  Determine the value for $dxc, which is the grid spacing in kilometers for
        #  a specific domain.  This information will be used to establish the best
        #  version of the requested datasets to use.
        #------------------------------------------------------------------------------------------
        #
        my $dx  = sprintf ("%.2f",$masternl{dwdx}/$r);
        my $dd  = $global ? (360.0/($masternl{GEOGRID}{e_we}[0]-1)) : $masternl{GEOGRID}{dx}[0] ; $dd = sprintf ("%.4f",$dd/$r);
        my $dm  = int $dx*1000;
        my $dxc = ($masternl{GEOGRID}{map_proj}[0] =~ /lat-lon/) ? 111.0*$dd : $dx;


        #------------------------------------------------------------------------------------------
        #  Allow ems_domain to assign default geog data resolution value. The cut-off values
        #  may need to be revised to be consistent with the somewhat arbitrary dxc*$fudge
        #  threshold used below.
        #------------------------------------------------------------------------------------------
        #
        my $dxres = ($dxc > 18.0) ? '10m' :
                    ($dxc >  9.0) ? '5m'  :
                    ($dxc >  4.0) ? '2m'  :
                    ($dxc >  1.5) ? '30s' : '30s';  #  Set to 30s for now - placeholder for higher resolution datasets

        unshift @gdsets,  $confs{dxres} ? $dxres : '';



        #------------------------------------------------------------------------------------------
        #  According to the WRF documentation, the GWD dataset used for each domain should be 
        #  slightly lower in resolution (greater grid spacing) than the domain DX.  How much 
        #  is "slightly" it does not say, for the UEMS it will be defined as 25%, which is
        #  DX*1.33, because it just feels right.  Also, don't include 30s dataset since it
        #  it might mess up the non-gwd dataset values.
        #------------------------------------------------------------------------------------------
        #
        my $gwdx = $dxc * 1.333;

        my $gwdo = ($gwdx > 222.0) ? '2deg' :
                   ($gwdx > 111.0) ? '1deg' :
                   ($gwdx >  55.0) ? '30m'  :
                   ($gwdx >  37.0) ? '20m'  : '';

        unshift @gdsets, $confs{gwdo} ? $gwdo : '';


        #------------------------------------------------------------------------------------------
        #  Determine the best available resolution for the requested land use dataset. Here the
        #  dataset with a resolution just below the domain grid spacing will be use. 33% seems
        #  about right, so $fudgef = 1.333,
        #------------------------------------------------------------------------------------------
        #
        my $fudgef = 1.333;


        #------------------------------------------------------------------------------------------
        #  Determine which soil type dataset to use. The user requested dataset 
        #  ($confs{stype}) takes priority over the current one (@{$masternl{stype}}).
        #------------------------------------------------------------------------------------------
        #
        my $stype = $confs{stype} ? $confs{stype} : shift @{$masternl{stype}};
           $stype = '' unless defined $stype and $stype;
           $stype = '' if $stype =~ /default/i;

        unshift @gdsets, $stype ? $stype : $dxres;
        push @dsst, $gdsets[0];



        #------------------------------------------------------------------------------------------
        #  Configure for Leaf Area Index (LAI) - Cut-off value at 18km because next resolution
        #  is 10m (~18.5km).
        #------------------------------------------------------------------------------------------
        #
        my $lai = $confs{lai} ? $confs{lai} : shift @{$masternl{lai}};
        unless ($lai) {$lai = ($dxc < 18.0) ? 'modis_lai' : '';}

        unshift @gdsets, $lai;
        push @dsla, $gdsets[0];



        #------------------------------------------------------------------------------------------
        #  Determine which greenness fraction dataset to use. The user requested dataset 
        #  ($confs{gfrac}) takes priority over the current one (@{$masternl{gfrac}}).
        #------------------------------------------------------------------------------------------
        #
        my $gfrac = $confs{gfrac} ? $confs{gfrac} : shift @{$masternl{gfrac}};
           $gfrac = '' unless defined $gfrac and $gfrac;
           $gfrac = '' if $gfrac =~ /default/i;

        unshift @gdsets, $gfrac;
        push @dsgf, $gdsets[0];


        #------------------------------------------------------------------------------------------
        #  Determine which land use dataset to use. The user requested dataset ($confs{landuse})
        #  takes priority over the current one (@{$masternl{landuse}}).
        #------------------------------------------------------------------------------------------
        #
        my $landuse = $confs{landuse} ? $confs{landuse} : shift @{$masternl{landuse}};
           $landuse = '' unless defined $landuse and $landuse;
           $landuse = '' if $landuse =~ /default/i;


        #------------------------------------------------------------------------------------------
        #  Was the --lakes flag passed?  
        #    $confs{lakes} = -1 then --nolakes passed
        #    $confs{lakes} =  1 then --lakes passed
        #    $confs{lakes} =  0 then not passed
        #
        #  Only usgs & modis have lakes dataset (usgs_lakes & modis_lakes)
        #  If both the --landuse flag (wo argument) and --nolakes flag was passed,
        #  then --landuse takes priority (modis_landuse_20class_30s_with_lakes);
        #------------------------------------------------------------------------------------------
        # 
        if ($confs{lakes} > 0)  { # --lakes passed
            $landuse = ''           if $landuse =~ /modis/i;  #  Use default landuse
            $landuse = 'usgs_lakes' if $landuse =~ /usgs/i;
        } elsif ($confs{lakes} < 0)  { # --nolakes passed
            $landuse = 'modis' unless $landuse;  #  Because the default ('') is modis_landuse_20class_30s_with_lakes
            $landuse =~ s/_lakes//g;  #  Should be left with either usgs|modis (or ssib|nlcd2006|nlcd2011)
        }


        #------------------------------------------------------------------------------------------
        #  Check whether $landuse is set to a general dataset, in which case the resolution
        #  information must be added.
        #------------------------------------------------------------------------------------------
        #
        if (grep {/^$landuse$/} ('modis','usgs','ssib') ) {
            my $lu_gres = 0;
            foreach (sort {$b <=> $a} keys %{$lures{$landuse}}) {$lu_gres = $lures{$landuse}{$_} if $dxc < $_*$fudgef || !$lu_gres;}
            $landuse = $lu_gres;
        }

        unshift @gdsets, $landuse;
        push @dslu, $gdsets[0];


        #------------------------------------------------------------------------------------------
        #  Determine which terrain elevation dataset to use. The user requested dataset 
        #  ($confs{topo}) takes priority over the current one (@{$masternl{topo}}).
        #------------------------------------------------------------------------------------------
        #
        my $topo = $confs{topo} ? $confs{topo} : shift @{$masternl{topo}};
           $topo = '' unless defined $topo and $topo;
           $topo = '' if $topo =~ /default/i;


        #------------------------------------------------------------------------------------------
        #  Determine which terrain elevation dataset to use. The user requested dataset 
        #  takes priority over the current one (@{$masternl{topo}}).
        #------------------------------------------------------------------------------------------
        #
        if ($topo eq 'gtopo') { #  Select the appropriate resolution for the domain
            my $ht_gres = 0;
            foreach (sort {$b <=> $a} keys %{$htres{$topo}}) {$ht_gres = $htres{$topo}{$_} if $dxc < $_*$fudgef || !$ht_gres;}
            $topo = $ht_gres;
        }

        unshift @gdsets, $topo;
        push @dste, $gdsets[0];


        #------------------------------------------------------------------------------------------
        #  Now put it all together like you mean business
        #------------------------------------------------------------------------------------------
        #
        @gdsets = &Others::rmdups(@gdsets);
        @gdsets = grep /\w/, @gdsets;
 
        $masternl{GEOGRID}{geog_data_res}[$i] = join '+', @gdsets;
        $masternl{GEOGRID}{geog_data_res}[$i] ="\'$masternl{GEOGRID}{geog_data_res}[$i]\'";

    }  # Foreach $i


    #----------------------------------------------------------
    #  Make sure the following are correctly updated as they
    #  will be used later on.
    #----------------------------------------------------------
    #
    @{$masternl{lai}}     = @dsla;
    @{$masternl{topo}}    = @dste;
    @{$masternl{gfrac}}   = @dsgf;
    @{$masternl{stype}}   = @dsst;
    @{$masternl{landuse}} = @dslu;


return %masternl;
}


sub DomainProjectionCheck {
#=====================================================================================
#  Make sure the projection is consistent with the core being run. Currently
#  only the ARW core need be tested. This test could also be located in the
#  DomainReadMasterNamelist subroutine but I didn't think of it at that time.
#=====================================================================================
#
    my %projections = ();
   
    @{$projections{ARW}} = qw(lambert mercator polar lat-lon);

    my ($core, $proj) = @_; $core = uc $core; $proj =~ s/\'//g;

return (grep /^$proj$/i, @{$projections{$core}}) ? 0 : 1;
}


sub UpdateDomainConfigurationFiles {
#===============================================================================
#  Refresh or restore the configuration files under <domain>/conf. If the 
#  --restore flag was passed then we wipe out the entire conf/ directory along
#  with the EMSUPP configuration files under static/ and replace them with the 
#  defaults. If the --refresh flag was passed then simply update the files 
#  with the defaults but retain the user configuration settings.
#===============================================================================
#   
use Cwd;
use File::Compare;

    my $mesg       = qw{};

    my $upref      = shift;
    my %Udomain = %{$upref};  

    return 0 unless $Udomain{CONF}{restore} or $Udomain{CONF}{refresh};

    my $edpost  = "$ENV{EMS_DATA}/tables/post";
    my $econf   = "$ENV{EMS_CONF}";

    my $domname = $Udomain{EMSRUN}{domname};
    my $dompath = $Udomain{EMSRUN}{dompath};
    my $dstatic = $Udomain{EMSRUN}{static};
    my $dconf   = $Udomain{EMSRUN}{conf};

    #----------------------------------------------------------------------------------
    #  If the --restore flag was used then simply replace the existing configuration 
    #  files with new ones.
    #----------------------------------------------------------------------------------
    #
    chdir $dompath;  # Start from the top

    &Ecomm::PrintTerminal(0,4,255,2,1,sprintf ("%-4s Domain \"$domname\" is in need of %s (My work is never done!):",&Ecomm::GetRN($ENV{DRN}++),$Udomain{CONF}{restore} ? 'restoration' : 'refreshment'));


    if ($Udomain{CONF}{restore}) {

        #  Scrub the current files while giggling.
        #
        &Others::rm($dconf); &Others::mkdir("$dconf/$_") foreach qw(ems_auto ems_run ems_post);
        foreach (&Others::FileMatch($dstatic,'^emsupp_',0,1))  {&Others::rm($_);}
        foreach (&Others::FileMatch($dstatic,'^emsbufr_',0,1)) {&Others::rm($_);}
 

        #  Now copy over the default configuration files.
        #
        &Ecore::SysExecute("rsync -qa $econf/ems_auto/      $dconf/ems_auto > /dev/null 2>&1");
        &Ecore::SysExecute("rsync -qa $econf/ems_run/       $dconf/ems_run  > /dev/null 2>&1");
        &Ecore::SysExecute("rsync -qa $econf/ems_post/      $dconf/ems_post > /dev/null 2>&1");
 

        #  Finally copy over the EMSUPP control files
        #
        &Ecore::SysExecute("rsync -qa $edpost/grib2/emsupp_cntrl.MASTER     $dstatic/emsupp_cntrl.parm > /dev/null 2>&1");
        &Ecore::SysExecute("rsync -qa $edpost/grib2/emsupp_auxcntrl.MASTER  $dstatic/emsupp_auxcntrl.parm > /dev/null 2>&1");
        &Ecore::SysExecute("rsync -qa $edpost/bufr/emsbufr_stations.MASTER  $dstatic/emsbufr_stations_d01.txt > /dev/null 2>&1");
 
        &Ecomm::PrintMessage(0,9,114,1,1,"A fresh set of configuration files were placed under conf/ and static/ - Hack away!");

        return 0;

    }


    #----------------------------------------------------------------------------------
    #  If the --refresh flag was used then we have our work cut out for us to ensure
    #  the use configuration is retained.
    #----------------------------------------------------------------------------------
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


    my @confdirs  = qw(ems_auto ems_run ems_post);

    foreach my $confdir (@confdirs) { # Foreach configuration directory (ems_auto ems_post ems_run)

        my $nfiles  = 0;
        my $retired = 1;

        my $emsconf = "$econf/$confdir";
        my $domconf = "$dconf/$confdir";  &Others::mkdir($domconf); #  The configuration file directory under the target domain


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
        
        foreach my $uconf (&Others::FileMatch($domconf,'\.conf$',0,1)) {

            my $ufile = &Others::popit($uconf);

            #-------------------------------------------------------------------------------
            #  The post_export.conf file must be managed  separately due to the multiple 
            #  EXPORT entries.
            #-------------------------------------------------------------------------------
            #
            next if $ufile =~ /post_export/;


            #  Read the local configuration file into a temporary hash
            #
            my %uparms = ();
            my %oparms = &Others::ReadConfigurationFile($uconf);

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
                    &Others::mkdir("$domconf/retired");
                    &Ecomm::PrintMessage(0,10,255,1,2,"Configuration files retired to the \"farm\" ($domname/conf/$confdir/retired):");
                    $retired = 0;
                }
                &Ecomm::PrintMessage(0,12,255,0,1,"RETIRED  : Configuration file   - $ufile");
                &Ecore::SysExecute("mv -f $uconf $domconf/retired/${ufile}.retired > /dev/null 2>&1");
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

        &Ecomm::PrintMessage(0,10,255,1,1,"It's OK - All the retired file configuration settings will be transfered to new files.") unless $retired;


        #--------------------------------------------------------------------------------------------
        #  In the above section the parameter values were read from each configuration file beneath
        #  the domain $confdir directory. Now the remaining files will be updated with the default
        #  files in uems/conf/$confdir .
        #--------------------------------------------------------------------------------------------
        #
        foreach my $econf (&Others::FileMatch($emsconf,'\.conf$',0,1)) {

            my $efile = &Others::popit($econf);
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

                &Ecomm::PrintMessage(0,10,255,2,2,"Updated conf/$confdir configuration files list:") unless $nfiles;

                -s $uconf ? &Ecomm::PrintMessage(0,12,255,0,1,"REFRESH  : Configuration file   - $efile") 
                          : &Ecomm::PrintMessage(0,12,255,0,1,"NEW CONF : Configuration file   - $efile");


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

                        print $ofh &Ecomm::TextFormat(0,$len,88,0,1,"$var = $value");
                    }
                
                } close $ofh; $nfiles++;
            }
        }  #  foreach my $econf

        #----------------------------------------------------------------------------------
        #  Let's copy over the README files for each section while we are at it.
        #----------------------------------------------------------------------------------
        #
        foreach my $eread (&Others::FileMatch($emsconf,'\.README$',0,1)) {
            &Ecore::SysExecute("rsync -qa $eread  $domconf/  > /dev/null 2>&1");
        }

        &Ecomm::PrintMessage(0,10,255,1,1,"The conf/$confdir configuration files are now ready for you") if $nfiles;
    
    }  #  foreach my $confdir


    #----------------------------------------------------------------------------------
    #  Now make sure that the EMSUPP control files in the target domain directory
    #  are up to date with the default UEMS files. All relevant level settings will
    #  be transfered to the refreshed files.
    #----------------------------------------------------------------------------------
    #
    my $date    = `date +"%Y.%m.%d"`; chomp $date;
    my @uppflds = ();
    my @auxflds = ();

    my $emsupp = "$edpost/grib2/emsupp_cntrl.MASTER";
    my $emsaux = "$edpost/grib2/emsupp_auxcntrl.MASTER";
    my $emsbuf = "$edpost/bufr/emsbufr_stations.MASTER";

    &Ecomm::PrintMessage(0,10,255,2,2,"Refreshing the EMSUPP & EMSBUFR configuration files list:");

    #  So begin with the EMSUPP control files
    #
    open (my $ifh, '<', $emsupp); while (<$ifh>) {chomp; s/\s+$//g; push @uppflds => $_;} close $ifh;
    open (   $ifh, '<', $emsaux); while (<$ifh>) {chomp; s/\s+$//g; push @auxflds => $_;} close $ifh;

    foreach my $upost (&Others::FileMatch($dstatic,'[_cntrl|_auxcntrl].parm$',0,1)) {

        my $ufile = &Others::popit($upost);

        my $epost = ($ufile =~ /_cntrl/) ? $emsupp : $emsaux;
        unless (compare($upost,$epost)) {&Ecomm::PrintMessage(0,12,255,1,1,"ALL GOOD : EMSUPP Control file  - $ufile"); next;}
        &Ecomm::PrintMessage(0,12,255,1,2,"REFRESH  : EMSUPP Control file  - $ufile");


        #----------------------------------------------------------------------------------
        #  The user's control file differs from the UEMS default so time to update.
        #  Open each user control file and read the string containing the field ID
        #  and the level list of 0|1s.
        #----------------------------------------------------------------------------------
        #
        my %ufields=();
        my $ufield  ='';

        open ($ifh, '<', $upost); 

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
        &Ecore::SysExecute("rsync -qa $upost ${upost}.$date > /dev/null 2>&1") unless -s ${upost}.$date;


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
            &Ecomm::PrintMessage(0,12,255,0,1,"NEW FIELD ADDED ($ufile) : $1") if (/^\s*\(([A-Za-z0-9_-]{0,52})\)/ and ! $replace);
            print $ofh "$_\n";
        } close $ofh;

    }
    
    #  Finally copy over the EMSUPP control files
    #
    &Ecore::SysExecute("rsync -qa $emsupp $dstatic/emsupp_cntrl.parm > /dev/null 2>&1")        unless -s "$dstatic/emsupp_cntrl.parm";
    &Ecore::SysExecute("rsync -qa $emsaux $dstatic/emsupp_auxcntrl.parm > /dev/null 2>&1")     unless -s "$dstatic/emsupp_auxcntrl.parm";
    &Ecore::SysExecute("rsync -qa $emsbuf $dstatic/emsbufr_stations_d01.txt > /dev/null 2>&1") unless -s "$dstatic/emsbufr_stations_d01.txt";
    

    &Ecomm::PrintMessage(0,9,255,1,2,"Mission \"$domname\" completed - just waiting on your next wish. Let's hope it's a good one!");

return;  #  Let's go home
}



sub UpdateUpdateMasterNamelistDwiz {
#=====================================================================================
#  Make sure values in the "domain_wizard" section of the namelist.wps
#  file is written out correctly.
#=====================================================================================
#
    my $refh = shift;  my %Udomain = %$refh;

    my %masternl = %{$Udomain{MASTERNL}};

    $masternl{DOMAIN_WIZARD}{dwiz_mpi_command}[0]    = 'null';
    $masternl{DOMAIN_WIZARD}{dwiz_lakes}[0]          = $masternl{lakes} ? 'true' : 'false';
    $masternl{DOMAIN_WIZARD}{dwiz_name}[0]           = lc $masternl{domname};
    $masternl{DOMAIN_WIZARD}{dwiz_gridpt_dist_km}[0] = sprintf("%11.7f",$masternl{dwdx});
    $masternl{DOMAIN_WIZARD}{dwiz_modis}[0]          = (grep /modis/, @{$masternl{GEOGRID}{geog_data_res}}) ? 'true' : 'false';


    unless ($masternl{global}) {
        $masternl{DOMAIN_WIZARD}{dwiz_stand_lon}[0]  = $masternl{GEOGRID}{ref_lon}[0];
        $masternl{DOMAIN_WIZARD}{dwiz_truelat1}[0]   = $masternl{GEOGRID}{ref_lat}[0];
        $masternl{DOMAIN_WIZARD}{dwiz_truelat2}[0]   = $masternl{GEOGRID}{ref_lat}[0];
    }


return %masternl;
}


sub ConfigureLimitedAreaDomain {
#==================================================================================
#  Check and complete the namelist configuration for a limited area domain.
#  Currently, this routine is intended for the WRF ARW core so it may need 
#  to be modified should another core be introduced.
#==================================================================================
#
use Emaproj;

    my $mesg       = qw{};
    my $upref      = shift;
    my %Udomain = %{$upref};

    my %masternl   = %{$Udomain{MASTERNL}};
    my %confs      = %{$Udomain{CONF}};

    my $eckm       = $Udomain{CONST}{eckm};

    #-------------------------------------------------------------------------------
    #  Begin by looping through each of the domains to ensure that the 
    #  dimensions of the subdomains are correct
    #-------------------------------------------------------------------------------
    #
    for my $i (0 .. $masternl{SHARE}{max_dom}[0]-1) {

        $masternl{SHARE}{start_date}[$i] = $masternl{SHARE}{start_date}[0];
        $masternl{SHARE}{end_date}[$i]   = $masternl{SHARE}{end_date}[0];

        my $nr   = $masternl{GEOGRID}{parent_grid_ratio}[$i];
        my $e_sn = $masternl{GEOGRID}{e_sn}[$i];
        my $e_we = $masternl{GEOGRID}{e_we}[$i];
        my $n_sn = $e_sn;
        my $n_we = $e_we;

        #-------------------------------------------------------------------------------
        #  The following code attempts to make sure that the n_we,n_sn point of
        #  a child domain is collocated with a parent point.
        #-------------------------------------------------------------------------------
        #
        $n_sn = $n_sn - 2 while ( (($n_sn-1)/$nr)/int(($n_sn-1)/$nr) > 1);
        $n_we = $n_we - 1 while ( (($n_we-1)/$nr)/int(($n_we-1)/$nr) > 1);

        if ($i) {

            my $dom = $i+1;

            $mesg = '';
            $mesg = "The UEMS recommends a child:parent grid ratio of either 3:1, 5:1, or 7:1.\n".
                    "Domain $dom has a ratio of $nr:1.  Ok, you've been warned." unless grep {/^${nr}$/} (3,5,7);
            &Ecomm::PrintTerminal(6,7,88,1,1,$mesg) if $mesg;

            $mesg = "The south-north grid dimension for domain $dom does not meet the strict ".
                    "requirements clearly spelled out somewhere in the ARW Users Guide.\nChanging ".
                    "the south-north dimension from $e_sn to $n_sn.\n\nI really hope you don't mind.";
            &Ecomm::PrintTerminal(6,7,86,1,1,$mesg) unless $e_sn == $n_sn;

            $mesg = "The west-east grid dimension for domain $dom does not meet the strict ".
                    "requirements clearly spelled out somewhere in the ARW Users Guide.\nChanging ".
                    "the west-east dimension from $e_we to $n_we.\n\nI really hope you don't mind.";
            &Ecomm::PrintTerminal(6,7,86,1,1,$mesg) unless $e_we == $n_we;


            #  Get the I,J start point on the parent domain ($psi,$psj)
            #
            my $psi = $masternl{GEOGRID}{i_parent_start}[$i];
            my $psj = $masternl{GEOGRID}{j_parent_start}[$i];

            #  Get the I,J end point of the parent domain ($pei,$pej)
            #
            my $pei = $masternl{GEOGRID}{e_we}[$masternl{GEOGRID}{parent_id}[$i]-1];
            my $pej = $masternl{GEOGRID}{e_sn}[$masternl{GEOGRID}{parent_id}[$i]-1];

            #  Now compare the $n_sn and $n_we points of the child domain to their
            #  location on the parent domain.
            #
            my $pgr = $masternl{GEOGRID}{parent_grid_ratio}[$i];
            if ( ($psi + ($n_we-1)/$pgr) > $pei or ($psj + ($e_sn-1)/$pgr) > $pej ) {

                my $cd = $i+1;
                my $pd = $masternl{GEOGRID}{parent_id}[$i];
                $mesg = "It appears that domain $cd extends outside the allowed areal coverage of its parent domain ($pd), ".
                        "which is simply going to result in massive failure and embarrassment for you. That is why ".
                        "I have elected to stop this process and allow you to fix the problem before further damage ".
                        "is done. No need to thank me, I'm just a computer.";
                &Ecomm::PrintTerminal(6,7,86,1,1,$mesg);

                my $cei = ($pei-$psi-1-5)*$pgr; #  Require 5 grid points from parent boundary
                my $cej = ($pej-$psj-1-5)*$pgr; #  Require 5 grid points from parent boundary

                $mesg = "Based upon the requested parent domain start I,J ($psi,$psj), my calculations indicate that the ".
                        "maximum grid dimensions of the child domain should be e_we=$cei and e_sn=$cej, which ".
                        "includes a 5 grid point buffer zone.\n\n".

                        "Note that making this change will require you to modify the dimensions of any sub ".
                        "domains, so you may have some additional work to do.";

                &Ecomm::PrintTerminal(0,10,86,1,2,$mesg);
                return ();
            }

        }  # IF $i

        $masternl{GEOGRID}{e_sn}[$i] = $n_sn;
        $masternl{GEOGRID}{e_we}[$i] = $n_we;

    } #  Foreach $i (Domain)

    #-------------------------------------------------------------------------------
    # Make sure there is only a single value in the ref_x & ref_y. These values
    # may be discarded later if not used for a given projection.
    #-------------------------------------------------------------------------------
    #
    @{$masternl{GEOGRID}{ref_y}} = ();
    $masternl{GEOGRID}{ref_y}[0] = $masternl{GEOGRID}{e_sn}[0]/2;
    @{$masternl{GEOGRID}{ref_x}} = ();
    $masternl{GEOGRID}{ref_x}[0] = $masternl{GEOGRID}{e_we}[0]/2;


    #-------------------------------------------------------------------------------
    # Handle another navigation such as Lambert, Polar Stereographic, Mercator, 
    # or Lat-lon.
    #
    # For the most part, the values of ref_lon and ref_lat define the center point
    # of the domain and other values are derived as necessary from the center point.
    #-------------------------------------------------------------------------------
    #
    $masternl{GEOGRID}{ref_lon}[0] = $masternl{GEOGRID}{stand_lon}[0] unless defined $masternl{GEOGRID}{ref_lon}[0] and $masternl{GEOGRID}{ref_lon}[0];
    $masternl{GEOGRID}{ref_lat}[0] = $masternl{GEOGRID}{truelat1}[0]  unless defined $masternl{GEOGRID}{ref_lat}[0] and $masternl{GEOGRID}{ref_lat}[0];


    if ($masternl{GEOGRID}{map_proj}[0] =~ /lat-lon/i) { #  A regular lat-lon projection

        #  Check if reference lat is in southern or northern hemisphere
        #
        $masternl{rotate} = $confs{rotate}; #  Saved for info

        if ($confs{rotate}) {
            
            if ($masternl{GEOGRID}{ref_lat}[0] > 0) { #  Northern Hemisphere - Changes to pole_lat, pole_lon, and stand_lon per WPS documentation
                $masternl{GEOGRID}{pole_lat}[0]  = 90.0 - $masternl{GEOGRID}{ref_lat}[0];
                $masternl{GEOGRID}{pole_lon}[0]  = 180.0;
                $masternl{GEOGRID}{stand_lon}[0] = -1 * $masternl{GEOGRID}{ref_lon}[0];
            } else { #  Southern Hemisphere - Changes to pole_lat, pole_lon, and stand_lon per WPS documentation
                $masternl{GEOGRID}{pole_lat}[0]  = 90.0 + $masternl{GEOGRID}{ref_lat}[0];
                $masternl{GEOGRID}{pole_lon}[0]  = 0.0;
                $masternl{GEOGRID}{stand_lon}[0] = 180.0 - $masternl{GEOGRID}{ref_lon}[0];
            }

        } else {

            delete $masternl{GEOGRID}{pole_lat};
            delete $masternl{GEOGRID}{pole_lon};
            $masternl{GEOGRID}{stand_lon}[0] = $masternl{GEOGRID}{ref_lon}[0];

        }

        #  Do some cleaning up of the navigation parameters
        #
        delete $masternl{GEOGRID}{ref_x}    if defined $masternl{GEOGRID}{ref_x};
        delete $masternl{GEOGRID}{ref_y}    if defined $masternl{GEOGRID}{ref_y};
        delete $masternl{GEOGRID}{truelat1} if defined $masternl{GEOGRID}{truelat1};
        delete $masternl{GEOGRID}{truelat2} if defined $masternl{GEOGRID}{truelat2};


    } elsif ($masternl{GEOGRID}{map_proj}[0] =~ /mercator/i) { #  A Mercator projection Duh!

        #  Set truelat1 equal to the reference lat to keep things simple
        #
        $masternl{GEOGRID}{truelat1}[0]  = $masternl{GEOGRID}{ref_lat}[0];
        $masternl{GEOGRID}{truelat2}[0]  = 0.0;
        $masternl{GEOGRID}{stand_lon}[0] = $masternl{GEOGRID}{ref_lon}[0];
        $masternl{GEOGRID}{pole_lat}[0]  = 90.0;
        $masternl{GEOGRID}{pole_lon}[0]  = 0;

    } elsif ($masternl{GEOGRID}{map_proj}[0] =~ /polar/i) { #  A polar stereographic projection Duh!

        $masternl{GEOGRID}{truelat1}[0]  = $masternl{GEOGRID}{ref_lat}[0];
        $masternl{GEOGRID}{stand_lon}[0] = $masternl{GEOGRID}{ref_lon}[0] unless defined $masternl{GEOGRID}{stand_lon} and $masternl{GEOGRID}{stand_lon}[0];

        delete $masternl{GEOGRID}{pole_lat}  if defined $masternl{GEOGRID}{pole_lat};
        delete $masternl{GEOGRID}{pole_lon}  if defined $masternl{GEOGRID}{pole_lon};
        delete $masternl{GEOGRID}{truelat2}  if defined $masternl{GEOGRID}{truelat2};

    } elsif ($masternl{GEOGRID}{map_proj}[0] =~ /lambert/i) { #  A Lambert Conformal projection Duh!

        $masternl{GEOGRID}{truelat1}[0]  = $masternl{GEOGRID}{ref_lat}[0] unless defined $masternl{GEOGRID}{truelat1}  and $masternl{GEOGRID}{truelat1}[0];
        $masternl{GEOGRID}{truelat2}[0]  = $masternl{GEOGRID}{ref_lat}[0] unless defined $masternl{GEOGRID}{truelat2}  and $masternl{GEOGRID}{truelat2}[0];
        $masternl{GEOGRID}{stand_lon}[0] = $masternl{GEOGRID}{ref_lon}[0] unless defined $masternl{GEOGRID}{stand_lon} and $masternl{GEOGRID}{stand_lon}[0];

        delete $masternl{GEOGRID}{pole_lat}  if defined $masternl{GEOGRID}{pole_lat};
        delete $masternl{GEOGRID}{pole_lon}  if defined $masternl{GEOGRID}{pole_lon};

    } else {

        $mesg = "The $masternl{GEOGRID}{map_proj}[0] projection is not supported. Maybe someday, ".
                "just not today.".
        &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,$mesg))
    }

    #  Additional information for DWIZ and the user
    #
    my ($dx, $dy);
    if ($masternl{GEOGRID}{map_proj}[0] =~ /lat-lon|latlon/i) {
        $dx = $masternl{GEOGRID}{dx}[0] * $eckm * 1000. / 360.0;
        $dy = $masternl{GEOGRID}{dy}[0] * $eckm * 1000. / 360.0;
    } else {
        $dx = $masternl{GEOGRID}{dx}[0];
        $dy = $masternl{GEOGRID}{dy}[0];
    }


    #  Additional information for DWIZ and the user
    #
    $masternl{dwdx} = (($dx+$dy)*0.5)*0.001;


return  %masternl;
}


sub ConfigureGlobalDomain {
#==================================================================================
#  Check and complete the namelist configuration for a global domain
#==================================================================================
#
use Emaproj;

    my $mesg       = qw{};
    my $upref      = shift;
    my %Udomain    = %{$upref};

    my %masternl   = %{$Udomain{MASTERNL}};
    my %confs      = %{$Udomain{CONF}};

    my $eckm       = $Udomain{CONST}{eckm};
    my $erad       = $Udomain{CONST}{erad};

    #------------------------------------------------------------------------------
    #  The following fields are not necessary in the global domain namelist file
    #------------------------------------------------------------------------------
    #
    delete $masternl{GEOGRID}{ref_x}    if defined $masternl{GEOGRID}{ref_x};
    delete $masternl{GEOGRID}{ref_y}    if defined $masternl{GEOGRID}{ref_y};
    delete $masternl{GEOGRID}{ref_lat}  if defined $masternl{GEOGRID}{ref_lat};
    delete $masternl{GEOGRID}{ref_lon}  if defined $masternl{GEOGRID}{ref_lon};
    delete $masternl{GEOGRID}{dx}       if defined $masternl{GEOGRID}{dx};
    delete $masternl{GEOGRID}{dy}       if defined $masternl{GEOGRID}{dy};
    delete $masternl{GEOGRID}{truelat1} if defined $masternl{GEOGRID}{truelat1};
    delete $masternl{GEOGRID}{truelat2} if defined $masternl{GEOGRID}{truelat2};

 
    #------------------------------------------------------------------------------
    #  Assign the default values for pole_lat (90), pole_lon (0.), and 
    #  stand_lon (180.0).
    #------------------------------------------------------------------------------
    #
    $masternl{GEOGRID}{pole_lat}[0]  = 90.0;
    $masternl{GEOGRID}{pole_lon}[0]  = 0.0;
    $masternl{GEOGRID}{stand_lon}[0] = $masternl{GEOGRID}{pole_lon}[0];

    $masternl{GEOGRID}{stand_lon}[0] = 180.0;  #  Changed after release 13.19
    $masternl{GEOGRID}{map_proj}[0]  = '\'lat-lon\'';


    #------------------------------------------------------------------------------
    #  Check whether the user passed any flags associated with a global domain, 
    #  which are saved in $confs{g_nests}, $confs{g_dxdy}, $confs{g_useny},
    #  $confs{g_nx}, and $confs{g_ny}.
    #------------------------------------------------------------------------------
    #
    if ($confs{g_nests} || $confs{g_dxdy} || $confs{g_nx} || $confs{g_ny}) {

        #  Clear out the existing arrays as they will be populated with
        #  new information.
        #
        @{$masternl{SHARE}{max_dom}}=();              $masternl{SHARE}{max_dom}[0]             = 1;
        delete $masternl{GEOGRID}{parent_id};         $masternl{GEOGRID}{parent_id}[0]         = 1;
        delete $masternl{GEOGRID}{parent_grid_ratio}; $masternl{GEOGRID}{parent_grid_ratio}[0] = 1;
        delete $masternl{GEOGRID}{i_parent_start};    $masternl{GEOGRID}{i_parent_start}[0]    = 1;
        delete $masternl{GEOGRID}{j_parent_start};    $masternl{GEOGRID}{j_parent_start}[0]    = 1;
   
    }


    if ($confs{g_dxdy} || $confs{g_nx} || $confs{g_ny}) {

        delete $masternl{GEOGRID}{dx};
        delete $masternl{GEOGRID}{dy};
        delete $masternl{GEOGRID}{e_we};
        delete $masternl{GEOGRID}{e_sn};
        delete $masternl{GEOGRID}{geog_data_res};


        #------------------------------------------------------------------------------
        #!!  CHECK - DO we need to cross check e_we & e_sn with valid values?
        #
        #  The user has specified the grid spacing of the global domain so now
        #  determine the value and units. Notice that --gdxdy value takes priority. 
        #------------------------------------------------------------------------------
        #
        if ($confs{g_dxdy} =~ /(^\d*\.?\d*)(\D+$)/) {

            my $unit = $2; chomp $unit;
            my $dxdy = $1; chomp $dxdy;  $dxdy = 0.001 * $dxdy if $unit =~ /^m/i;
 
            $masternl{GEOGRID}{e_we}[0] = ($unit =~ /^d/) ? int (360./$dxdy) : int ($eckm/$dxdy);
            $masternl{GEOGRID}{e_we}[0] = $masternl{GEOGRID}{e_we}[0]+1 unless $masternl{GEOGRID}{e_we}[0]%2 == 1; #  needs to be odd
            $masternl{GEOGRID}{e_sn}[0] = int (($masternl{GEOGRID}{e_we}[0]+1)/2.);  #  First guess but may need to change later

        } else {  #  Set e_we & e_sn when --gnx and --gny are passed

            #  If --gny is passed then e_we is set to (2*gny)-1
            #
            $masternl{GEOGRID}{e_we}[0] = $confs{g_nx} ? $confs{g_nx} : int (2*$confs{g_ny})-1;
            $masternl{GEOGRID}{e_sn}[0] = $confs{g_ny} ? $confs{g_ny} : int (($masternl{GEOGRID}{e_we}[0]+1)/2.);

        }

    }


    if ($confs{g_nests}) {

        #------------------------------------------------------------------------------
        #  Collect the navigation information for the primary domain as this will
        #  be needed in determining the start I,J point for any nests.
        #------------------------------------------------------------------------------
        #
        my %dhash=();
           $dhash{1}{slat} = -90.;  #!! Is this value correct?
           $dhash{1}{slon} = $masternl{GEOGRID}{stand_lon}[0];
           $dhash{1}{nx}   = $masternl{GEOGRID}{e_we}[0];
           $dhash{1}{ny}   = $masternl{GEOGRID}{e_sn}[0];
           $dhash{1}{dx}   = 360./($masternl{GEOGRID}{e_we}[0]-1);
           $dhash{1}{dy}   = 180./($masternl{GEOGRID}{e_sn}[0]-1);

    
        #------------------------------------------------------------------------------
        #  The user has passed the --gnests flag and the argument should have been
        #  tested in the Dconf module so we can get down to business.
        #------------------------------------------------------------------------------
        #
        my $dom = 2;
        foreach (split /;|,/ => $confs{g_nests}) {


            my ($par,$slat,$slon,$nx,$ny,$ratio) = split /:/ => $_;

            $dhash{$dom}{par}  = $par;  #  ID of parent domain
            $masternl{GEOGRID}{parent_id}[$dom-1] = $par;
            $masternl{GEOGRID}{parent_grid_ratio}[$dom-1] = $ratio;
                

            #------------------------------------------------------------------------------
            #  Collect the navigation information for each domain in a hash. It may not 
            #  be needed for the namelist but may be needed to determine the I,J start
            #  point of a child domain relative to its parent. We need the lat-lon for 
            #  point 1,1 as well as the grid spacing, the dimensions, and the ratio.
            #------------------------------------------------------------------------------
            #
            my %phash = &Emaproj::map_set('LL',$dhash{$par}{slat},$dhash{$par}{slon},1.0,1.0,0.5,
                                          $dhash{$par}{dx},$dhash{$par}{dy},0.5,$dhash{$par}{nx},$dhash{$par}{ny});

            #------------------------------------------------------------------------------
            #  The user has requested a start lat-lon point for their domain, which may 
            #  not be collocated ith a parent grid point. Fix the problem by adjusting
            #  the start lat-lon.
            #------------------------------------------------------------------------------
            #
            my ($pi,$pj) = &Emaproj::latlon_to_ij($slat,$slon,%phash);

             
            #  Just as a precaution
            #
            $pi = int ($pi + 0.499);
            $pj = int ($pj + 0.499);

            $masternl{GEOGRID}{i_parent_start}[$dom-1] = $pi;
            $masternl{GEOGRID}{j_parent_start}[$dom-1] = $pj;

            ($slat,$slon) = &Emaproj::ij_to_latlon($pi,$pj,%phash);


            #------------------------------------------------------------------------------
            #  At this point we need to make sure the nested domain does not extend  
            #  beyond a certain latitude. The WRF documentation states the latitude is
            #  the same as fft_filter_lat; however, the value of fft_filter_lat is not 
            #  known at this point so set an arbitrary limit of 50deg N/S.
            #------------------------------------------------------------------------------
            #
            if (abs($slat) > 50.) {
                my $e = ($slat > 0) ? 'north of 50 degrees' : 'south of 50 degrees';
                $mesg = "It appears that the southern edge of nested domain $dom is located $e ($slat degrees), ".
                        "which will not work with the global FFT filter routines according to the WRF documentation. ".
                        "Your entire nested domain must reside between 45 degrees south and north latitude. That's ".
                        "just the way it is, sometimes modeling hurts the ones it loves.";
                &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'Bad nested domain latitude',$mesg));
            }


            $dhash{$dom}{slat} = $slat;  #  Updated lat-lon of pt 1,1 on child domain
            $dhash{$dom}{slon} = $slon;  #  Updated lat-lon of pt 1,1 on child domain

            #------------------------------------------------------------------------------
            #  Grid spacing of child domain is simply parent GS/ratio - In degrees.
            #------------------------------------------------------------------------------
            #
            $dhash{$dom}{dx}   = $dhash{$par}{dx}/$ratio;
            $dhash{$dom}{dy}   = $dhash{$par}{dy}/$ratio;


            #------------------------------------------------------------------------------
            #  Check to make sure the dimensions of the child domain are such that
            #  the NX,NY point is collocated with that of a parent point.
            #------------------------------------------------------------------------------
            #
            $ny = $ny - 2 while ( (($ny-1)/$ratio)/int(($ny-1)/$ratio) > 1);
            $nx = $nx - 1 while ( (($nx-1)/$ratio)/int(($nx-1)/$ratio) > 1);

            $dhash{$dom}{nx}   = $nx;   #  NX grid points of child
            $dhash{$dom}{ny}   = $ny;   #  NY grid points of child


            my $dyp = $pj + ($ny-1)/$ratio;
            my $dxp = $pi + ($nx-1)/$ratio;

            ($slat,$slon) = &Emaproj::ij_to_latlon($dxp,$dyp,%phash);


            #------------------------------------------------------------------------------
            #  Note that this is being done for the northern boundary
            #------------------------------------------------------------------------------
            #
            if (abs($slat) > 50.) { 
                my $e = ($slat > 0) ? 'north of 50 degrees' : 'south of 50 degrees';
                $mesg = "It appears that the southern edge of nested domain $dom is located $e ($slat degrees), ".
                        "which will not work with the global FFT filter routines according to the WRF documentation. ".
                        "Your entire nested domain must reside between 45 degrees south and north latitude. That's ".
                        "just the way it is, sometimes modeling hurts the ones it loves.";
                &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,'Bad nested domain latitude',$mesg));
            }


            $masternl{GEOGRID}{e_we}[$dom-1] = $nx;
            $masternl{GEOGRID}{e_sn}[$dom-1] = $ny;

            $dom++;

        }  #  Foreach split nests

    }  #  If NESTS

    #--------------------------------------------------------------------------------------------
    #  From this point we need to check the global domain configuration for potential problems,
    #  of which there are many.
    #--------------------------------------------------------------------------------------------
    #

    #  Begin with the primary global domain
    #
    my $e_sn = $masternl{GEOGRID}{e_sn}[0];
    my $e_we = $masternl{GEOGRID}{e_we}[0];
    my $n_sn = $e_sn;
    my $n_we = $e_we;


    #------------------------------------------------------------------------------
    #  Since this is a global domain then the dimensions need to be specified 
    #  such that e_we is equal to 2**P * 3**Q * 5**R + 1 (where P, Q, and R are
    #  any integers, including 0). This requirement is due to the FFT filtering
    #  at the poles.
    #
    #  So, it's easiest to collect an array of values that meet this requirement
    #  and compare the user value against those allowed.
    #------------------------------------------------------------------------------
    #

    #  Allow the array of values to be roughly plus/minus 50% specified dimension
    #
    my $dmax = int ($n_we * 1.49);
    my $dmin = int ($n_we * 0.49);

    my @dims=();
    for my $p (0 .. 12) {
    for my $q (0 .. 12) {
    for my $r (0 .. 12) {
        my $dim = ((2**$p) * (3**$q) * (5**$r)) + 1;
        push @dims => $dim if $dim <= $dmax and $dim >= $dmin;
    } } }


    #------------------------------------------------------------------------------
    #  If the domain NX & NY values are in the list of those recommended then
    #  move on; otherwise, we have some work to do.
    #------------------------------------------------------------------------------
    #
    unless (grep /^$n_we$/i, @dims) {  #  Always test $n_we

        @dims = sort {$a <=> $b} @dims; @dims = &Others::rmdups(@dims);

        #  Find the allowed values above and below the specified dimension
        #
        my @dh=();
        my @dl=();
        foreach (@dims) {
            push @dl => $_ if $_ < $n_we;
            push @dh => $_ if $_ > $n_we;
        }
        @dl = sort {$a <=> $b} @dl;
        @dh = sort {$a <=> $b} @dh;


        #------------------------------------------------------------------------------
        #  Use the dimension closest to the specified value, print out information,
        #  and then move on.
        #------------------------------------------------------------------------------
        #
        my $newd = ( ($n_we - $dl[$#dl]) < ($dh[0] - $n_we)) ? $dl[$#dl] : $dh[0]; my $dlm = $#dl < 2 ? 0 : $#dl-2;
        my @svss = (@dl[$dlm..$#dl],@dh[0..2]); my $svs = join ', ',@svss; $svs =~ s/, $//g;
        my $newt = $newd; if ($newd < 36) {$newd = 36; $n_sn = 18;} #  Minimum dimension is 10 degrees (36)


        $mesg = "The W-E grid dimension for your global domain ($n_we) does not meet the recommended value:\n\n".
                "    NX = 2**P * 3**Q * 5**R + 1 (where P, Q, and R are any integers, including 0)\n\n".
                "Computationally valid values close to $n_we include $svs.\n\n".

                "The EMS Oracle has decided to use $newd for the W-E dimension of your domain, just ".
                "because that's his lucky number.";

        $mesg = ($newt < 36) ? "$mesg and that's the minimum NX dimension (10 degrees)." : ".";

        &Ecomm::PrintTerminal(6,7,104,2,2,'There, I fixed the domain for you',$mesg);

        $n_we = $newd;
    }
    $n_sn = $confs{g_useny} ? $n_sn ? $n_sn : int ( ($n_we+1)/2.) : int ( ($n_we+1)/2.);

    #------------------------------------------------------------------------------
    #  The following code attempts to make sure that the n_we,n_sn point of
    #  a child domain is collocated with a parent point.
    #------------------------------------------------------------------------------
    #
    my $nr = 1;
    $n_sn = $n_sn - 2 while ( (($n_sn-1)/$nr)/int(($n_sn-1)/$nr) > 1);
    $n_we = $n_we - 1 while ( (($n_we-1)/$nr)/int(($n_we-1)/$nr) > 1);

    $masternl{GEOGRID}{e_sn}[0] = $n_sn;
    $masternl{GEOGRID}{e_we}[0] = $n_we;


    $mesg = "Hey! Your requested grid spacing is greater than 10 degrees,\nwhich is rather pathetic on your part.\n\nLet's try a smaller grid spacing next time!";
    &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,$mesg)) if $masternl{GEOGRID}{e_we}[0] < 36;


    #  Now handle the domain dimensions for the primary domain and any nests
    #
    $masternl{SHARE}{max_dom}[0] = scalar @{$masternl{GEOGRID}{parent_id}};



    for my $i (1 .. $masternl{SHARE}{max_dom}[0]-1) {

        $masternl{SHARE}{start_date}[$i] = $masternl{SHARE}{start_date}[0];
        $masternl{SHARE}{end_date}[$i]   = $masternl{SHARE}{end_date}[0];

        my $nr   = $masternl{GEOGRID}{parent_grid_ratio}[$i];
        my $e_sn = $masternl{GEOGRID}{e_sn}[$i];
        my $e_we = $masternl{GEOGRID}{e_we}[$i];
        my $n_sn = $e_sn;
        my $n_we = $e_we;


        #------------------------------------------------------------------------------
        #  The following code attempts to make sure that the n_we,n_sn point of
        #  a child domain is collocated with a parent point.
        #------------------------------------------------------------------------------
        #
        $n_sn = $n_sn - 2 while ( (($n_sn-1)/$nr)/int(($n_sn-1)/$nr) > 1);
        $n_we = $n_we - 1 while ( (($n_we-1)/$nr)/int(($n_we-1)/$nr) > 1);


        my $dom = $i+1;

        $mesg = '';
        $mesg = "The south-north grid dimension for domain $dom does not meet the strict ".
            "requirements clearly spelled out somewhere in the ARW Users Guide.\nChanging ".
                "the south-north dimension from $e_sn to $n_sn.\n\nI really hope you don't mind.";
        &Ecomm::PrintTerminal(6,7,104,2,2,'I fixed the domain for you',$mesg) unless $e_sn == $n_sn;

        $mesg = "The west-east grid dimension for domain $dom does not meet the strict ".
                "requirements clearly spelled out somewhere in the ARW Users Guide.\nChanging ".
                "the west-east dimension from $e_we to $n_we.\n\nI really hope you don't mind.";
        &Ecomm::PrintTerminal(6,7,104,2,2,'I fixed the domain for you',$mesg) unless $e_we == $n_we;



        #  Get the I,J start point on the parent domain ($psi,$psj)
        #
        my $psi = $masternl{GEOGRID}{i_parent_start}[$i];
        my $psj = $masternl{GEOGRID}{j_parent_start}[$i];
 

        #  Get the I,J end point of the parent domain ($pei,$pej)
        #
        my $pei = $masternl{GEOGRID}{e_we}[$masternl{GEOGRID}{parent_id}[$i]-1];
        my $pej = $masternl{GEOGRID}{e_sn}[$masternl{GEOGRID}{parent_id}[$i]-1];
 

        #------------------------------------------------------------------------------
        #  Now compare the $n_sn and $n_we points of the child domain to their
        #  location on the parent domain.
        #------------------------------------------------------------------------------
        #
        my $pgr = $masternl{GEOGRID}{parent_grid_ratio}[$i];
        if ( ($psi + ($n_we-1)/$pgr) > $pei or ($psj + ($e_sn-1)/$pgr) > $pej ) {

            my $err = int rand(1000);
            my $cd = $i+1;
            my $pd = $masternl{GEOGRID}{parent_id}[$i];
            $mesg = "It appears that domain $cd extends outside the allowed areal coverage of its parent domain ($pd), ".
                    "which is simply going to result in massive failure and embarrassment for you. That is why ".
                    "I have elected to stop this process and allow you to fix the problem before further damage ".
                    "is done. No need to thank me, I'm just a computer.";
            &Ecomm::PrintTerminal(6,7,104,2,2,'This problem I can do nothing about',$mesg);

            my $cei = ($pei-$psi-1-5)*$pgr; #  Require 5 grid points from parent boundary
            my $cej = ($pej-$psj-1-5)*$pgr; #  Require 5 grid points from parent boundary

            $mesg = "Based upon the requested parent domain start I,J ($psi,$psj), my calculations indicate that the ".
                    "maximum grid dimensions of the child domain should be e_we=$cei and e_sn=$cej, which ".
                    "includes a 5 grid point buffer zone.\n\n".

                    "Note that making this change will require you to modify the dimensions of any sub ".
                    "domains, so you may have some additional work to do.";

            &Ecore::SysDied(0,&Ecomm::TextFormat(0,0,88,0,0,$mesg));

        }
        $masternl{GEOGRID}{e_sn}[$i] = $n_sn;
        $masternl{GEOGRID}{e_we}[$i] = $n_we;

    }


    #  Additional information for DWIZ and the user
    #
    $masternl{dwdx} = $eckm / $masternl{GEOGRID}{e_we}[0];

    # AND THAT'S HOW YOU MAKE A GLOBAL DOMAIN!


return %masternl;
}


sub DomainPrintInformation {
#==================================================================================
#  This routine simply provides information about the domains defined in the 
#  static/namelist.wps file.
#==================================================================================
#
    my $mesg     = qw{};
    my @mesgs    = ();

    my $upref    = shift;
    my %masternl = %{$upref};

    #------------------------------------------------------------------------------
    #  Define the variables that are used within this subroutine
    #------------------------------------------------------------------------------
    #
    my $core     = $masternl{core};
    my $global   = $masternl{global};
    my $maxdoms  = $masternl{maxdoms};
    my $domain   = $masternl{domname};
 
    my $landuse  = &DescriptionLanduse($masternl{landuse}[0]);
    my $topo     = &DescriptionTerrain($masternl{topo}[0]);
    my $gfrac    = &DescriptionGreenFraction($masternl{gfrac}[0]);
    my $leaf     = &DescriptionLeafAreaIndex($masternl{lai}[0]);
    my $stype    = &DescriptionSoilType($masternl{stype}[0]);


    #------------------------------------------------------------------------------
    #  Just making the output look neat & tidy
    #------------------------------------------------------------------------------
    #
    my $pro = qw{};
    for ($pro = $masternl{GEOGRID}{map_proj}[0]) {
        s/'//g;
        $_ = /lat-lon/i ? $masternl{rotate} ? 'Rotated Latitude-Longitude' : 'Regular Latitude-Longitude' : $_;
        $_ = 'Lambert Conformal'   if /lambert/i;
        $_ = 'Mercator'            if /mercator/i;
        $_ = 'Polar Stereographic' if /polar/i;
    }


    my @pgr = ();

    for my $i (0 .. $masternl{SHARE}{max_dom}[0]-1) {

        my $p  = $masternl{GEOGRID}{parent_id}[$i];
        my $r  = $masternl{GEOGRID}{parent_grid_ratio}[$i];

        $pgr[$i] = $i ? ($r * $pgr[$p-1]) : $r;


        #  Determine the value for $dxc, which is the grid spacing in kilometers for
        #  a specific domain.  This information will be used to establish the best
        #  version of the requested datasets to use.
        #
        my $dx  = sprintf ("%.2f",$masternl{dwdx}/$pgr[$i]);
        my $dd  = $global ? (360.0/($masternl{GEOGRID}{e_we}[0]-1)) : $masternl{GEOGRID}{dx}[0] ; $dd = sprintf ("%.4f",$dd/$pgr[$i]);
        my $dm  = int $dx*1000;
        my $dxc = ($masternl{GEOGRID}{map_proj}[0] =~ /lat-lon/) ? 111.0*$dd : $dx;
        my $gs  = ($masternl{GEOGRID}{map_proj}[0] =~ /lat-lon/) ? "$dd degree" : $dx < 1.0 ? "$dm meter" : "$dx kilometer";

        my @gds = split '\+', $masternl{GEOGRID}{geog_data_res}[$i]; my $gd = $gds[-1]; $gd =~ s/'//g;

        my $d = $i+1;
        my $nr = ($r != 3 and $r != 5) ? "Parent Grid Ratio   | $r:1 (!)" : "Parent Grid Ratio   | $r:1";


        if ($i) {
            $mesg = "  Nested Domain ID    | $d\n".
                    "  Parent Domain       | $masternl{GEOGRID}{parent_id}[$i]\n".
                    "  Parent I,J Start    | $masternl{GEOGRID}{i_parent_start}[$i],$masternl{GEOGRID}{j_parent_start}[$i]\n".
                    "  $nr\n".
                    "  Grid NX x NY        | $masternl{GEOGRID}{e_we}[$i] x $masternl{GEOGRID}{e_sn}[$i]\n".
                    "  Grid Spacing        | $gs\n".
                    "  Geog Dset Res       | $gd\n";
        } else {

            my $d = $masternl{SHARE}{max_dom}[0] > 1 ? 'domains' : 'domain';

            &Ecomm::PrintTerminal(0,4,255,2,1,sprintf ("%-4s The configuration for the $domain run-time domain:",&Ecomm::GetRN($ENV{DRN}++)));

            my $len = 0;
            foreach ($topo,$landuse,$gfrac,$leaf,$stype) {my $slen = length $_; $len = $slen if $slen > $len;} $len+=24;

            my @mesgs=();
            push @mesgs => ($maxdoms > 1) ? 'Terrestrial Datasets (Used by all domains)' : 'Terrestrial Datasets';
            push @mesgs => sprintf('%s', '-' x $len);
            push @mesgs => "  Terrain Elevation   | $topo";
            push @mesgs => "  Land Use            | $landuse";
            push @mesgs => "  Vegetation Fraction | $gfrac";
            push @mesgs => "  Leaf Area Index     | $leaf";
            push @mesgs => "  Soil Type           | $stype\n\n";


            push @mesgs => ($maxdoms > 1) ? 'Primary & Nested Domain Configurations'  : 'Primary Domain Configuration';
            push @mesgs => '--------------------------------------------------------';
            push @mesgs => $global ? '  Domain Number       | 1 (global)' : '  Domain Number       | 1';
            push @mesgs => "  Projection          | $pro";
            push @mesgs => "  Standard Longitude  | $masternl{GEOGRID}{stand_lon}[$i] degrees" if defined $masternl{GEOGRID}{stand_lon};
            push @mesgs => "  True Latitude 1     | $masternl{GEOGRID}{truelat1}[$i] degrees"  if defined $masternl{GEOGRID}{truelat1};
            push @mesgs => "  True Latitude 2     | $masternl{GEOGRID}{truelat2}[$i] degrees"  if defined $masternl{GEOGRID}{truelat2};
            push @mesgs => "  Reference Latitude  | $masternl{GEOGRID}{ref_lat}[$i] degrees"   if defined $masternl{GEOGRID}{ref_lat};
            push @mesgs => "  Reference Longitude | $masternl{GEOGRID}{ref_lon}[$i] degrees"   if defined $masternl{GEOGRID}{ref_lon};
            push @mesgs => "  Pole Latitude       | $masternl{GEOGRID}{pole_lat}[$i] degrees"  if defined $masternl{GEOGRID}{pole_lat};
            push @mesgs => "  Pole Longitude      | $masternl{GEOGRID}{pole_lon}[$i] degrees"  if defined $masternl{GEOGRID}{pole_lon};
            push @mesgs => "  Grid NX x NY        | $masternl{GEOGRID}{e_we}[$i] x $masternl{GEOGRID}{e_sn}[$i]";
            push @mesgs => "  Grid Spacing        | $gs";
            push @mesgs => "  Default Geog Res    | $gd\n";

            $mesg = join "\n", @mesgs;
        }

        &Ecomm::PrintTerminal(0,11,144,1,1,$mesg);

    }


return;
}


sub DescriptionLanduse {
#==================================================================================
#  Routine provides a description of the landuse dataset based upon the 
#  geog_data_res entry in the static/namelist.wps file.
#==================================================================================
#
    my %dsdesc = ();
       
       #  USGS Landuse datasets
       #
       $dsdesc{usgs_30s}   = 'Global 30-arc second, 24-category USGS landuse classification (no lakes)';
       $dsdesc{usgs_2m}    = 'Global  2-arc minute, 24-category USGS landuse classification (no lakes)';
       $dsdesc{usgs_5m}    = 'Global  5-arc minute, 24-category USGS landuse classification (no lakes)';
       $dsdesc{usgs_10m}   = 'Global 10-arc minute, 24-category USGS landuse classification (no lakes)';
       $dsdesc{usgs_lakes} = 'Global 30-arc second, 25-category USGS landuse classification with lakes';

       #  MODIS Landuse datasets
       #
       $dsdesc{modis_15s}       = 'Global 15-arc second, 20-category IGBP-Modified MODIS landuse classification (no lakes)';
       $dsdesc{modis_30s}       = 'Global 30-arc second, 20-category IGBP-Modified MODIS landuse classification (no lakes)';
       $dsdesc{modis_lakes}     = 'Global 30-arc second, 21-category IGBP-Modified MODIS landuse classification with lakes';
       $dsdesc{modis_30s_lake}  = 'Global 30-arc second, 20-category IGBP-Modified MODIS landuse classification with lakes';


       #  SSIB Landuse datasets
       #
       $dsdesc{ssib_5m}         = 'Global 5-arc minute, 12-category SSiB vegitation classification (no lakes)';
       $dsdesc{ssib_10m}        = 'Global 10-arc minute, 12-category SSiB vegitation classification (no lakes)';


       #  NLCD Landuse datasets
       #
       $dsdesc{nlcd2006_9s}     = 'US CONUS  9-arc second, 40-category 2006 NLCD/MODIS landuse classification (no lakes)';
       $dsdesc{nlcd2006_30s}    = 'US CONUS 30-arc second, 40-category 2006 NLCD/MODIS landuse classification (no lakes)';
       $dsdesc{nlcd2006}        = 'US CONUS 30-arc second, 40-category 2006 NLCD/MODIS landuse classification (no lakes)';
       $dsdesc{nlcd2011_9s}     = 'US CONUS  9-arc second, 40-category 2006 NLCD/MODIS landuse classification (no lakes)';

       #  The Default from GEOGRID.TBL
       #
       $dsdesc{default}         = 'Global 30-arc second, 20-category IGBP-Modified MODIS landuse classification with lakes';
       

    my $ds = shift; $ds = 'default' unless defined $ds and $ds; $ds = lc $ds;

return defined $dsdesc{$ds} ? $dsdesc{$ds} : "Some unknown landuse dataset - $ds"; 
}


sub DescriptionTerrain {
#==================================================================================
#  Routine provides a description of the terrain elevation dataset based upon
#  the geog_data_res entry in the static/namelist.wps file.
#==================================================================================
#
    my %dsdesc = ();
       $dsdesc{gmted2010_30s}   = 'Global 30-arc second, USGS GMTED2010 terrain elevation dataset';
       $dsdesc{gtopo_30s}       = 'Global 30-arc second, USGS terrain elevation dataset (Pre-WRF V3.8)';
       $dsdesc{gtopo_2m}        = 'Global  2-arc minute, USGS terrain elevation dataset (Pre-WRF V3.8)';
       $dsdesc{gtopo_5m}        = 'Global  5-arc minute, USGS terrain elevation dataset (Pre-WRF V3.8)';
       $dsdesc{gtopo_10m}       = 'Global 10-arc minute, USGS terrain elevation dataset (Pre-WRF V3.8)';

       $dsdesc{default}         = 'Global 30-arc second, USGS GMTED2010 terrain elevation dataset';

    my $ds = shift; $ds = 'default' unless defined $ds and $ds; $ds = lc $ds;

return defined $dsdesc{$ds} ? $dsdesc{$ds} : "Some unknown terrain elevation dataset - $ds";
}


sub DescriptionGreenFraction {
#==================================================================================
#  Routine provides a description of the greenness fraction dataset based upon
#  the geog_data_res entry in the static/namelist.wps file.
#==================================================================================
#
    my %dsdesc = ();
       $dsdesc{modis_fpar}       = 'Global 30-arc second monthly Greenness Vegetation Fraction based on 10 years MODIS (FPAR)';
       $dsdesc{nesdis_greenfrac} = 'Global 10-arc minute Greenness Vegetation Fraction based on AVHRR (Pre-WRF V3.8 Default)';

       $dsdesc{default}          = 'Global 30-arc second monthly Greenness Vegetation Fraction based on 10 years MODIS (FPAR)';

    my $ds = shift; $ds = 'default' unless defined $ds and $ds; $ds = lc $ds;

return defined $dsdesc{$ds} ? $dsdesc{$ds} : "Some unknown Greenness Vegetation Fraction dataset - $ds";
}


sub DescriptionLeafAreaIndex {
#==================================================================================
#  Routine provides a description of the leaf area index dataset based upon
#  the geog_data_res entry in the static/namelist.wps file.
#==================================================================================
#
    my %dsdesc = ();
       $dsdesc{modis_lai}  = 'Global 30-arc second monthly Leaf Area Index (LAI) data based on 10 years MODIS';
       $dsdesc{default}    = 'Global 10-arc minute monthly Leaf Area Index (LAI) data based on 10 years MODIS';

    my $ds = shift; $ds = 'default' unless defined $ds and $ds; $ds = lc $ds;

return defined $dsdesc{$ds} ? $dsdesc{$ds} : "Some unknown Leaf Area Index dataset - $ds";
}


sub DescriptionSoilType {
#==================================================================================
#  Routine provides a description of the soil type dataset based upon
#  the geog_data_res entry in the static/namelist.wps file.
#==================================================================================
#
    my %dsdesc = ();
       $dsdesc{bnu_soil_30s}  = 'Global 30-arc second BNU soil 16-category datasets';

       $dsdesc{'30s'}         = 'Global 30-arc second 16-category soil type dataset';
       $dsdesc{'10m'}         = 'Global 10-arc minute 16-category soil type dataset';
       $dsdesc{'5m'}          = 'Global  5-arc minute 16-category soil type dataset';
       $dsdesc{'2m'}          = 'Global  2-arc minute 16-category soil type dataset';

       $dsdesc{default}       = 'Global 30-arc second 16-category soil type dataset';

    my $ds = shift; $ds = 'default' unless defined $ds and $ds; $ds = lc $ds;

return defined $dsdesc{$ds} ? $dsdesc{$ds} : "Some unknown Soil Type dataset - $ds";
}


sub ImportRuntimeDomains {
#===============================================================================
#  This routine simply imports (rsync) existing UEMS run-time domains to the
#  local $EMS_RUN directory.  All that is passed in is a hash containing a 
#  previously vetted list of domains to import along with the local directory
#  names.
#===============================================================================
#
use List::Util qw(max);

    my @domains = ();
    my $pathimp = 0;
    my $pathexp = 0;
    my $err     = '- with Enthusiasm!';

    my $upref   = shift;
    my %imports = %{$upref};  return @domains unless %imports;

    foreach (values %imports) {$pathimp = max $pathimp, length $_;}
    foreach (keys   %imports) {$pathexp = max $pathexp, length $_;}  $pathexp = $pathexp + 1;

    &Ecomm::PrintTerminal(0,4,255,2,2,sprintf ("%-4s Importing the following run-time domains at your request:",&Ecomm::GetRN($ENV{DRN}++)));

    foreach my $import (keys %imports) {

        my $export = "$ENV{EMS_RUN}/$import";

        &Ecomm::PrintTerminal(0,11,255,0,0,sprintf("Importing: %-${pathimp}s  -> %-${pathexp}s",$imports{$import},"uems/runs/$import"));

        my $status = &Ecore::SysExecute("rsync -qa $imports{$import}/ $export > /dev/null 2>&1");

        $status   ? &Ecomm::PrintMessage(0,1,96,0,1,sprintf("- Failed (%s)",&Ecore::RsyncExitCodes($status)))
                  : &Ecomm::PrintMessage(0,1,96,0,1,sprintf("- Success"));

        push @domains => $export unless $status;
        $err = '- with Errors (Oops!)' if $status;

    }

    &Ecomm::PrintMessage(0,9,84,1,2,"Domain import completed $err");
    
    
return @domains;
}


sub LocalizeRuntimeDomain {
#==================================================================================
#  Manages the localization of the run-time domain as requested by the user.
#==================================================================================
#
use Dutils;


    my $upref      = shift;
    my %Udomain = %{$upref};  

    my $emsrun  = $Udomain{CONF}{localize}  || return 0;  #  Return unless --create flag was passed
    my $global  = ($Udomain{CONF}{global}   || $Udomain{MASTERNL}{global}) ? 1 : 0;


    #------------------------------------------------------------------------------
    #  Define the necessary files & other variables
    #------------------------------------------------------------------------------
    #
    my $mpiexec = $Udomain{UEXE}{mpiexec};
    my $geogrid = $Udomain{UEXE}{geogrid};

    my $core    = uc $Udomain{CONF}{core} || 'ARW';
    my $domain  = &Others::popit($emsrun);

    my $tabldir = "$ENV{EMS_DATA}/tables/wps";
    my $static  = $Udomain{EMSRUN}{static};
    my $wpsnl   = $Udomain{EMSRUN}{wpsnl};

    my $logfile = 'domain_geogrid.log';
    my $lfpath  = "$Udomain{EMSRUN}{logdir}/$logfile";
    my $geotbl  = $global ? "$tabldir/GEOGRID.TBL.${core}.GLOBAL" : "$tabldir/GEOGRID.TBL.$core";  #  Hardcoded - which I don't like

    my $ncpus   = $Udomain{CONF}{ncpus};


    #------------------------------------------------------------------------------
    #  Run from the top level of the domain directory
    #------------------------------------------------------------------------------
    #
    chdir $emsrun;


    #------------------------------------------------------------------------------
    #  Start this panic attack!
    #------------------------------------------------------------------------------
    #
    &Ecomm::PrintTerminal(0,4,255,1,1,sprintf ("%-4s Localizing the $core core computational domain \"$domain\"",&Ecomm::GetRN($ENV{DRN}++)));


    #------------------------------------------------------------------------------
    #  Delete any MPI environmental variables that may cause problems. Hopefully
    #  the user doesn't need these - Oh well.
    #------------------------------------------------------------------------------
    #
    delete $ENV{$_} foreach qw(MPIEXEC_PORT_RANGE MPICH_PORT_RANGE HYDRA_IFACE HYDRA_ENV MPIEXEC_TIMEOUT);

    &Others::rm('static/GEOGRID.TBL');  #  just making sure 

    symlink $geotbl => 'static/GEOGRID.TBL';
    symlink $wpsnl  => 'namelist.wps';
     
    

    #------------------------------------------------------------------------------
    #  If the user passed --debug geogrid then it's time to shut down and allow
    #  their hands to get dirty.
    #------------------------------------------------------------------------------
    #
    if ($Udomain{CONF}{debug}== 5) {
        &Ecomm::PrintMessage(4,11,256,2,2,"The table has been set for you. Now try running:\n\n  % $mpiexec -n $ncpus $geogrid\n\nfrom the $emsrun directory.");
        &Ecore::SysExit(98);
    }

    
    &Ecomm::PrintTerminal(1,11,255,1,0,"Employing $ncpus cores to create the domain you deserve - ");

    my $secs = time();
    if (my $status = &Ecore::SysExecute("$mpiexec -n $ncpus $geogrid",$lfpath)) {

        &Ecomm::PrintMessage(0,0,32,0,1,sprintf("Failed (%s)",&Ecore::RsyncExitCodes($status)));
 
        if (-e $lfpath and -s $lfpath) {

            my @mesgs = ();

            open (my $lfh, '<', $lfpath);
            while (<$lfh>){chomp; push @mesgs => $_ if /Error|Segmentation|Float/i;} close $lfh;
            @mesgs = &Others::rmdups(@mesgs);

            if (@mesgs) {
                 &Ecomm::PrintMessage(6,11,96,1,2,"While perusing the log/$logfile file I saw the following:");
                 &Ecomm::PrintMessage(0,14,144,0,1,$_) foreach @mesgs;
            }

            &Ecomm::PrintMessage(0,9,256,1,1,"See $logfile for more gory details.\n\nTry including \"--debug geogrid\" for troubleshooting.");
        }
        my @geologs = &Others::FileMatch($emsrun,'geogrid.log',0,1);
        system "cat @geologs > $Udomain{EMSRUN}{logdir}/domain_geogrid_failed.log > /dev/null 2>&1";
        return 1;
    }
    $secs = time() - $secs;
    &Ecomm::PrintMessage(0,0,24,0,1,'Success');

    &Ecomm::PrintMessage(0,9,144,1,1,sprintf ("Computational domain localized in %s",&Ecomm::FormatTimingString($secs)));


    #------------------------------------------------------------------------------
    #  Scour the static directory but this time keep the files you just created - Duh!
    #------------------------------------------------------------------------------
    #
    &Others::rm("$emsrun/namelist.wps");

    my @geologs = &Others::FileMatch($emsrun,'geogrid.log',0,1);
    &Others::rm(@geologs);

    &Dutils::RefreshRuntimeDomain(1,$emsrun);

    system "rsync -av $tabldir/dwiz_hysm.jpg $static/projection.jpg > /dev/null 2>&1";


return;
}


sub CreateRuntimeDomain {
#===============================================================================
#  This routine simply imports (rsync) existing UEMS run-time domains to the
#  local $EMS_RUN directory.  All that is passed in is a hash containing a 
#  previously vetted list of domains to import along with the local directory
#  names.
#===============================================================================
#
use Dutils;


    my $upref      = shift;
    my %Udomain = %{$upref};  

    my $emsrun  = $Udomain{CONF}{create}  || return %Udomain;  #  Return unless --create flag was passed

    my $core    = lc $Udomain{CONF}{core} || 'arw';
    my $dwiz    = $Udomain{CONF}{dwiz};

    my $domain  = &Others::popit($emsrun);
    my $estatic = "$ENV{EMS_DATA}/domains/$core/static";
    my $edpost  = "$ENV{EMS_DATA}/tables/post";
    my $econf   = "$ENV{EMS_CONF}";

    my $dstatic = "$emsrun/static";
    my $dconf   = "$emsrun/conf";
    my $dlog    = "$emsrun/log";


    &Ecomm::PrintTerminal(0,4,255,1,1,sprintf ("%-4s Creating a new $core core computational domain - $emsrun",&Ecomm::GetRN($ENV{DRN}++)));

    #  If a runtime directory of the same name already resides in $EMS_RUN then delete it since
    #  we would not be here unless the user passed the --force flag.
    #
    if (-e $emsrun and $dwiz)      {&Others::rm("${emsrun}.prev");system "mv $emsrun ${emsrun}.prev > /dev/null 2>&1";}
    if (-e $emsrun)                {&Ecomm::PrintMessage(0,9,114,1,1,"Deleting existing \"$domain\" domain directory. You made me do it!"); return () if &Others::rm($emsrun);}
    if (&Others::mkdir($emsrun))   {&Ecomm::PrintMessage(6,9,255,2,1,"There was an error in creating the $domain directory - Possible permission problem?"); return ();}

    chdir $emsrun; # Begin from the domain directory

    &Others::mkdir($dconf);
    &Others::mkdir($dstatic) if $dwiz;

    unless ($dwiz) {
        if (my $status = &Ecore::SysExecute("rsync -qa $estatic $emsrun > /dev/null 2>&1")) {
            &Ecomm::PrintMessage(6,9,96,1,1,sprintf("Copying of template into $domain/static - Failed (%s)",&Ecore::RsyncExitCodes($status)));
            return ();
        }
        return () if &Others::mkdir($dlog);
    }
    system "touch $dstatic/.$core";  #  Update the core ID


    unless ($Udomain{CONF}{mcserver}) {
        #  Now copy over the default configuration files.
        #
        &Ecore::SysExecute("rsync -qa $econf/ems_auto/      $dconf/ems_auto > /dev/null 2>&1");
        &Ecore::SysExecute("rsync -qa $econf/ems_run/       $dconf/ems_run  > /dev/null 2>&1");
        &Ecore::SysExecute("rsync -qa $econf/ems_post/      $dconf/ems_post > /dev/null 2>&1");

        #  Finally copy over the EMSUPP control files
        #
        &Ecore::SysExecute("rsync -qa $edpost/grib2/emsupp_cntrl.MASTER     $dstatic/emsupp_cntrl.parm > /dev/null 2>&1");
        &Ecore::SysExecute("rsync -qa $edpost/grib2/emsupp_auxcntrl.MASTER  $dstatic/emsupp_auxcntrl.parm > /dev/null 2>&1");
        &Ecore::SysExecute("rsync -qa $edpost/bufr/emsbufr_stations.MASTER  $dstatic/emsbufr_stations_d01.txt > /dev/null 2>&1");
    }

    &Ecomm::PrintMessage(0,9,114,1,1,"An all new run-time domain was created - with \"New Domain\" scented potpourri included!");


return %Udomain;
}


