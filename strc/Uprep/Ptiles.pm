#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Ptiles.pm
#
#  DESCRIPTION:  Ptiles contains each of the primary routines used for the 
#                configuration and downloading of UEMS personal tiles by 
#                the Unified Environmental Modeling System (UEMS).
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Ptiles;

use warnings;
use strict;
require 5.008;
use English;

use vars qw (%Uprep);

use Others;
use Emaproj;


sub PersonalTileInit {
#==================================================================================
#  This routine handles the initialization if the personal tile datasets available
#  to ems_prep.  The initialization includes the navigation information for each
#  PT dataset, so if a flavor of PT is added then a new "if ($ptile eq '<dset>')"
#  section must be created.
#==================================================================================
#
    my %ptnav = ();
    my %pmap  = ( 'LC', 'Lambert Conformal',   'RL', 'Rotated Lat-Lon', 'LL', 'Latitude-Longitude',
                  'PS', 'Polar Stereographic', 'ME', 'Mercator');

    my $ptile = shift;


    #  The information below includes the definition for each GRIB file used to 
    #  create the personal tiles. It consists of the navigation information 
    #  along with the moniker for that dataset.
    #
    if ($ptile eq 'namak6km') {

        $ptnav{nxmax} = 825;  #  Number of NX grid points
        $ptnav{nymax} = 553;  #  Number of NY grid points
        $ptnav{bzpts} = 2;    #  Number of additional boundary points
        $ptnav{globl} = 0;    #  Is it a global dataset (1|0)
        $ptnav{dsid}  = '6km NAM Alaska'; #  ID used for information
        $ptnav{dset}  = 'namak6km';  #  Dataset name

        %{$ptnav{grnav}} = &Emaproj::map_set('PS',40.530,-178.571,1.0,1.0,5953,-150.00,60.00,90.00,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{PS};

    }


    if ($ptile eq 'namak') {

        $ptnav{nxmax} = 553;  #  Number of NX grid points
        $ptnav{nymax} = 425;  #  Number of NY grid points
        $ptnav{bzpts} = 2;    #  Number of additional boundary points
        $ptnav{globl} = 0;    #  Is it a global dataset (1|0)
        $ptnav{dsid}  = '11km NAM Alaska'; #  ID used for information
        $ptnav{dset}  = 'namak';  #  Dataset name

        %{$ptnav{grnav}} = &Emaproj::map_set('PS',30.000,-173.000,1.0,1.0,11250,-135.00,60.00,90.00,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{PS};

    }


    if ($ptile eq 'namca') {

        $ptnav{nxmax} = 370;  #  Number of NX grid points
        $ptnav{nymax} = 278;  #  Number of NY grid points
        $ptnav{bzpts} = 2;    #  Number of additional boundary points
        $ptnav{globl} = 0;    #  Is it a global dataset (1|0)
        $ptnav{dsid}  = '11km NAM Central America'; #  ID used for information
        $ptnav{dset}  = 'namca';  #  Dataset name

        %{$ptnav{grnav}} = &Emaproj::map_set('LL',0.138000,-100.00,1.0,1.0,0.108000,0.108000,0.108000,0.108000,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{LL};

    }


    if ($ptile eq 'nam4km') {

        $ptnav{nxmax} = 1473; #  Number of NX grid points
        $ptnav{nymax} = 1025; #  Number of NY grid points
        $ptnav{bzpts} = 2;    #  Number of additional boundary points
        $ptnav{globl} = 0;    #  Is it a global dataset (1|0)
        $ptnav{dsid}  = '5km HiRes NAM'; #  ID used for information
        $ptnav{dset}  = 'nam4km';  #  Dataset name

        %{$ptnav{grnav}} =  &Emaproj::map_set('LC',12.190,-133.459,1.0,1.0,5079,-95.00,25.00,25.00,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{LC};

    }

   if ($ptile eq 'namnest') {

        $ptnav{nxmax} = 1799; #  Number of NX grid points
        $ptnav{nymax} = 1059; #  Number of NY grid points
        $ptnav{bzpts} = 2;    #  Number of additional boundary points
        $ptnav{globl} = 0;    #  Is it a global dataset (1|0)
        $ptnav{dsid}  = '3km CONUS NAM'; #  ID used for information
        $ptnav{dset}  = $ptile;  #  Dataset name

        %{$ptnav{grnav}} = &Emaproj::map_set('LC',21.138,-122.720,1.0,1.0,3000,-97.50,38.50,38.50,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{LC};

    }


    if ($ptile eq 'nam') {

        $ptnav{nxmax} = 614;  #  Number of NX grid points
        $ptnav{nymax} = 428;  #  Number of NY grid points
        $ptnav{bzpts} = 2;    #  Number of additional boundary points
        $ptnav{globl} = 0;    #  Is it a global dataset (1|0)
        $ptnav{dsid}  = '12km NAM North America'; #  ID used for information
        $ptnav{dset}  = 'nam';  #  Dataset name

        %{$ptnav{grnav}} = &Emaproj::map_set('LC',12.190,-133.459,1.0,1.0,12191,-95.00,25.00,25.00,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{LC};

    }


    if ($ptile eq 'rap') {

        $ptnav{nxmax} = 451;  #  Number of NX grid points
        $ptnav{nymax} = 337;  #  Number of NY grid points
        $ptnav{bzpts} = 2;    #  Number of additional boundary points
        $ptnav{globl} = 0;    #  Is it a global dataset (1|0)
        $ptnav{dsid}  = '13km RAP B-grid (hybrid)'; #  ID used for information
        $ptnav{dset}  = 'raphyb'; #  Dataset name

        %{$ptnav{grnav}} = &Emaproj::map_set('LC',16.281,-126.138,1.0,1.0,13545,-95.00,25.00,25.00,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{LC};

    }


    if ($ptile eq 'ruc') {

        $ptnav{nxmax} = 451;  #  Number of NX grid points
        $ptnav{nymax} = 337;  #  Number of NY grid points
        $ptnav{bzpts} = 2;    #  Number of additional boundary points
        $ptnav{globl} = 0;    #  Is it a global dataset (1|0)
        $ptnav{dsid}  = '13km RUC B-grid (hybrid)'; #  ID used for information
        $ptnav{dset}  = 'ruchyb'; #  Dataset name

        %{$ptnav{grnav}} = &Emaproj::map_set('LC',16.281,-126.138,1.0,1.0,13545,-95.00,25.00,25.00,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{LC};

    }


    if ($ptile eq 'hrrr') {

        $ptnav{nxmax} = 1799; #  Number of NX grid points
        $ptnav{nymax} = 1059; #  Number of NY grid points
        $ptnav{bzpts} = 2;    #  Number of additional boundary points
        $ptnav{globl} = 0;    #  Is it a global dataset (1|0)
        $ptnav{dsid}  = '3km CONUS HRRR'; #  ID used for information
        $ptnav{dset}  = 'hrrr';  #  Dataset name

        %{$ptnav{grnav}} = &Emaproj::map_set('LC',21.138,-122.720,1.0,1.0,3000,-97.50,38.50,38.50,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{LC};

    }


    if ($ptile eq 'rap') {

        $ptnav{nxmax} = 451;  #  Number of NX grid points
        $ptnav{nymax} = 337;  #  Number of NY grid points
        $ptnav{bzpts} = 2;    #  Number of additional boundary points
        $ptnav{globl} = 0;    #  Is it a global dataset (1|0)
        $ptnav{dsid}  = '13km RAP B-grid (hybrid)'; #  ID used for information
        $ptnav{dset}  = 'raphyb'; #  Dataset name

        %{$ptnav{grnav}} = &Emaproj::map_set('LC',16.281,-126.138,1.0,1.0,13545,-95.00,25.00,25.00,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{LC};

    }


    if ($ptile eq 'ruc') {

        $ptnav{nxmax} = 451;  #  Number of NX grid points
        $ptnav{nymax} = 337;  #  Number of NY grid points
        $ptnav{bzpts} = 2;    #  Number of additional boundary points
        $ptnav{globl} = 0;    #  Is it a global dataset (1|0)
        $ptnav{dsid}  = '13km RUC B-grid (hybrid)'; #  ID used for information
        $ptnav{dset}  = 'ruchyb'; #  Dataset name

        %{$ptnav{grnav}} = &Emaproj::map_set('LC',16.281,-126.138,1.0,1.0,13545,-95.00,25.00,25.00,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{LC};

    }


    if ($ptile eq 'gfsp50' or $ptile eq 'gfs') {

        $ptnav{nxmax} = 720;  #  Number of NX grid points
        $ptnav{nymax} = 361;  #  Number of NY grid points
        $ptnav{bzpts} = 3;    #  Number of additional boundary points
        $ptnav{globl} = 1;    #  Is it a global dataset (1|0)
        $ptnav{dsid}  = '0.5 degree GFS';   #  ID used for information
        $ptnav{dset}  = 'gfsp50';   #  Dataset name

        %{$ptnav{grnav}} = &Emaproj::map_set('LL',-90.,0.0,1.0,1.0,0.5,0.5,0.5,0.5,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{LL};

    }


    if ($ptile eq 'gfsp25') {

        $ptnav{nxmax} = 1440; #  Number of NX grid points
        $ptnav{nymax} = 721;  #  Number of NY grid points
        $ptnav{bzpts} = 3;    #  Number of additional boundary points
        $ptnav{globl} = 1;    #  Is it a global dataset (1|0)
        $ptnav{dsid}  = '0.25 degree GFS';   #  ID used for information
        $ptnav{dset}  = 'gfsp25';   #  Dataset name

        %{$ptnav{grnav}} = &Emaproj::map_set('LL',-90.,0.0,1.0,1.0,0.25,0.25,0.25,0.25,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{LL};

    }


    if ($ptile eq 'cfsrr' or $ptile eq 'cfsr') {

        $ptnav{nxmax} = 720;  #  Number of NX grid points
        $ptnav{nymax} = 361;  #  Number of NY grid points
        $ptnav{bzpts} = 3;    #  Number of additional boundary points
        $ptnav{globl} = 1;    #  Is it a global dataset (1|0)
        $ptnav{dsid}  = '0.5 degree Climate Forecast System Reanalysis'; #  ID used for information
        $ptnav{dset}  = $ptile;  #  Dataset name

        %{$ptnav{grnav}} = &Emaproj::map_set('LL',-90.,0.0,1.0,1.0,0.5,0.5,0.5,0.5,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{LL};

    }


    if ($ptile eq 'narr') {

        $ptnav{nxmax} = 349;  #  Number of NX grid points
        $ptnav{nymax} = 277;  #  Number of NY grid points
        $ptnav{bzpts} = 3;    #  Number of additional boundary points
        $ptnav{globl} = 0;    #  Is it a global dataset (1|0)
        $ptnav{dsid}  = '32km North American Regional Reanalysis';  #  ID used for information
        $ptnav{dset}  = 'narr';  #  Dataset name

        %{$ptnav{grnav}} = &Emaproj::map_set('LC',1.000,-145.50,1.0,1.0,32463,-107.00,50.00,50.00,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{LC};

    }


    if ($ptile eq 'sportsstnwh') { #  NASA/SPoRT 2-km multi-sensor Northern Hemisphere SST product

        $ptnav{nxmax} = 13348;  #  Number of NX grid points
        $ptnav{nymax} = 4448;   #  Number of NY grid points
        $ptnav{bzpts} = 10;     #  Number of additional boundary points
        $ptnav{globl} = 1;      #  It's not a global dataset but must be treated as such because wgrib2
                                #  has problems subsetting across 0 degrees longitude, so we must define
                                #  the domain in terms of lat/lon rather than i,j.
        $ptnav{dsid}  = '0.018 degree NWH NASA SpORT SSTs';     #  ID used for information
        $ptnav{dset}  = 'sportsst';  #  Dataset name

        %{$ptnav{grnav}} = &Emaproj::map_set('LL',-0.020833,129.919443,1.0,1.0,0.017994,0.017994,0.017993,0.017993,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{LL};

    }


    if ($ptile eq 'sportsst') { #  NASA/SPoRT 2-km multi-sensor Northern Hemisphere SST product

        $ptnav{nxmax} = 20000;  #  Number of NX grid points
        $ptnav{nymax} = 4448;   #  Number of NY grid points
        $ptnav{bzpts} = 10;     #  Number of additional boundary points
        $ptnav{globl} = 1;      #  It's not a global dataset but must be treated as such because wgrib2
                                #  has problems subsetting across 0 degrees longitude, so we must define
                                #  the domain in terms of lat/lon rather than i,j.
        $ptnav{dsid}  = '0.018 degree NH NASA SpORT SSTs';     #  ID used for information
        $ptnav{dset}  = 'sportsst';  #  Dataset name

        %{$ptnav{grnav}} = &Emaproj::map_set('LL',-0.020833,70.068055,1.0,1.0,0.017994,0.017994,0.017993,0.017993,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{LL};

    }



    if ($ptile eq 'rtgsst') {

        $ptnav{nxmax} = 4320;   #  Number of NX grid points
        $ptnav{nymax} = 2160;   #  Number of NY grid points
        $ptnav{bzpts} = 10;     #  Number of additional boundary points
        $ptnav{globl} = 1;      #  It's a global dataset
        $ptnav{dsid}  = 'SST';  #  ID used for information
        $ptnav{dset}  = 'rtgsst';  #  Dataset name

        #  Note:  Due to the navigation in the grid2 files being reported as DX = 0.083 (Lat1 & Lon1 truncated too)
        #         wgrib2 does not cut out a correct domain. Consequently, there may be regions where sst values = 0
        #         around the periphery of the personal tile domain.
        #
        %{$ptnav{grnav}} = &Emaproj::map_set('LL',89.958336,0.041667,1.0,1.0,-0.0833333,-0.0833333,-0.0833333,0.0833333,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{LL};

    }


    if ($ptile eq 'ice') {

        $ptnav{nxmax} = 4320;   #  Number of NX grid points
        $ptnav{nymax} = 2160;   #  Number of NY grid points
        $ptnav{bzpts} = 10;     #  Number of additional boundary points
        $ptnav{globl} = 1;      #  Is it a global dataset (1|0)
        $ptnav{dsid}  = 'Sea Ice'; #  ID used for information
        $ptnav{dset}  = 'ice';  #  Dataset name

        #  Note:  Due to the navigation in the grid2 files being reported as DX = 0.083 (Lat1 & Lon1 truncated too)
        #         wgrib2 does not cut out a correct domain. Consequently, there may be regions where ice values = 0
        #         around the periphery of the personal tile domain.
        #
        %{$ptnav{grnav}} = &Emaproj::map_set('LL',89.958336,0.041667,1.0,1.0, 0.0833333, 0.0833333,-0.0833333,0.0833333,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{LL};

    }


    if ($ptile eq 'lis') {  #  LIS LatLon grid

        $ptnav{nxmax} = 1064;  #  Number of NX grid points
        $ptnav{nymax} =  672;  #  Number of NY grid points
        $ptnav{bzpts} = 2;    #  Number of additional boundary points
        $ptnav{globl} = 0;    #  Is it a global dataset (1|0)
        $ptnav{dsid}  = '3km LIS LSM dataset'; #  ID used for information
        $ptnav{dset}  = 'lis';  #  Dataset name

        %{$ptnav{grnav}} = &Emaproj::map_set('LL',24.000,-99.980,1.0,1.0,0.03000,0.03000,0.03000,0.03000,$ptnav{nxmax},$ptnav{nymax});
        $ptnav{mproj}    = $pmap{LC};

    }

    #  The following section includes deprecated PT datasets that probably should be removed from
    #  this subroutine but I'm afraid that as soon as I do I will need them again.
    #

    #if ($ptile eq 'lis') {  #  No longer used - LIS Lambert Conformal grid

    #    $ptnav{nxmax} = 910;  #  Number of NX grid points
    #    $ptnav{nymax} = 800;  #  Number of NY grid points
    #    $ptnav{bzpts} = 2;    #  Number of additional boundary points
    #    $ptnav{globl} = 0;    #  Is it a global dataset (1|0)
    #    $ptnav{dsid}  = '3km LIS LSM dataset'; #  ID used for information
    #    $ptnav{dset}  = 'lis';  #  Dataset name
    #    %{$ptnav{grnav}} = &Emaproj::map_set('LC',20.50,-96.900,1.0,1.0,3000,-77.00,33.00,33.00,$ptnav{nxmax},$ptnav{nymax});
    #    $ptnav{mproj} = $pmap{LC};

    #}

    &Ecomm::PrintMessage(6,9+$Uprep{arf},96,1,2,"Excuse me, but I'm not familiar with $ptile personal tiles.") unless %ptnav;


return %ptnav;
}


sub PersonalTilesConfig {
#==================================================================================
#  This routine does the bulk of the configuration necessary prior to requesting 
#  personal tiles from the UEMS servers.
#==================================================================================
#
use POSIX qw(ceil floor);

    %Uprep = %Pacquire::Uprep;

    my ($ptile, $host, %files) = @_;

    my $mesg = qw{};
    my %pmap = ('LC', 'Lambert Conformal', 'RL', 'Rotated Lat-Lon', 'LL', 'Latitude-Longitude',
                'PS', 'Polar Stereographic', 'ME', 'Mercator');

    my $dbg  = ($Uprep{parms}{debug} == 4) ? 1 : 0;

    #  If the user has requested a subset of the data then get the lat-lon
    #  points at the approximate edges of the computational domain.
    #
    my @lats  = ();
    my @lons  = ();

    my $xdim  = $Uprep{masternl}{GEOGRID}{e_we}[0];
    my $ydim  = $Uprep{masternl}{GEOGRID}{e_sn}[0];
    my $klat  = $Uprep{masternl}{GEOGRID}{ref_lat}[0];
    my $klon  = $Uprep{masternl}{GEOGRID}{ref_lon}[0];
    my $name  = $Uprep{masternl}{GEOGRID}{map_proj}[0];
    my $dx    = $Uprep{masternl}{GEOGRID}{dx}[0];
    my $dy    = $Uprep{masternl}{GEOGRID}{dy}[0];

    my $ri    = $Uprep{masternl}{GEOGRID}{ref_x}[0] ? $Uprep{masternl}{GEOGRID}{ref_x}[0] : 0.5*($xdim+1);
    my $rj    = $Uprep{masternl}{GEOGRID}{ref_y}[0] ? $Uprep{masternl}{GEOGRID}{ref_y}[0] : 0.5*($ydim+1);

    my $tlat1 = $Uprep{masternl}{GEOGRID}{truelat1}[0] ? $Uprep{masternl}{GEOGRID}{truelat1}[0] : $Uprep{masternl}{GEOGRID}{ref_lat}[0];
    my $tlat2 = $Uprep{masternl}{GEOGRID}{truelat2}[0] ? $Uprep{masternl}{GEOGRID}{truelat2}[0] : $tlat1;

    my $slon  = $Uprep{masternl}{GEOGRID}{stand_lon}[0] ? $Uprep{masternl}{GEOGRID}{stand_lon}[0] : $klon;

    $name = "LC" if $name =~ /lambert/i;
    $name = "RL" if $name =~ /rotlat/i;
    $name = "RL" if $name =~ /rotated_ll/i;
    $name = "LL" if $name =~ /latlon|lat-lon/i;
    $name = "PS" if $name =~ /polar/i;
    $name = "ME" if $name =~ /merc/i;


    #  Project the rotated Lat-Lon grid onto a Lambert Conic Conformal grid since the Emaproj
    #  routing can not handle the grid and the LCC is close enough at mid-latitudes.
    #  This may lead to problems near the equator though. Come up  with a better solution later.
    #
    if ($name eq 'RL') { # Additional calculations needed for rotated lat-lon grid
        #  Use the mean of DLMD and DPHD for the DX (km) value
        $dx   = 0.5*($dx*107.5251+$dy*111.3206);
        #  adding in additional fudge factor (4%)
        $dx   = $dx*1.04;
        # Convert to meters
        $dx   = $dx * 1000.;
        #  Calculate center X,Y on computational grid
        $xdim = ($xdim*2)-1;
        $ri   = 0.5*($xdim+1);
        #  Pretend it is a LCC projection
        $name = "LC"
    } elsif ($name eq 'LL') {
        #  Make some changes for lat-lon grids
        #  Also navigation should be based on mass point grid so dimensions
        #  are 1 less than that specified.
        #
        $xdim = $xdim - 1;
        $ydim = $ydim - 1;
        $slon  = $dx;
        $tlat1 = $dy;
    } else {
        $xdim = $xdim - 1;
        $ydim = $ydim - 1;
    }

    my %proj = &Emaproj::map_set($name,$klat,$klon,$ri,$rj,$dx,$slon,$tlat1,$tlat2,$xdim,$ydim);

    $mesg = "Computational Mapset Arguments: map_set($name,$klat,$klon,$ri,$rj,$dx,$slon,$tlat1,$tlat2,$xdim,$ydim)";
    &Ecomm::PrintMessage(4,14+$Uprep{arf},255,1,1,$mesg) if $dbg;

    &Ecomm::PrintMessage(4,14+$Uprep{arf},96,2,1,"Areal coverage of the $pmap{$name} computational domain") if $dbg;

    my @dpts = ($proj{latsw},$proj{lonsw},$proj{latnw},$proj{lonnw},$proj{latse},
                $proj{lonse},$proj{latne},$proj{lonne},$proj{latcen},$proj{loncen});

    &Ecomm::PrintMessage(4,14+$Uprep{arf},96,1,1,&Others::FormatCornerPoints(@dpts)) if $dbg;



    #--------------------------------------------------------------------------------
    #  Here we have a problem. The areal coverage of the domain requested
    #  must be specified by the 4 corner points. The problem is that if we
    #  simply use the corner points of the computational domain then its 
    #  possible that the initialization dataset may be too small due to
    #  projection of one navigation on to another.  
    #
    #  Addressing this problem becomes messy.

    #  Define the navigation for all the grids available as personal tiles.  At some
    #  point this information will need to be migrated to a separate module but today 
    #  is not the day.
    #--------------------------------------------------------------------------------
    #
    my ($slat, $wlon, $nlat, $elon);
    my ($mini, $minj, $maxi, $maxj);

    my $lsm    = $ptile =~ s/lsm//g;


    my %ptinfo = &PersonalTileInit($ptile); return 0 unless %ptinfo;

    my %ptnav  = %{$ptinfo{grnav}};

    my $nymax  = $ptinfo{nymax};
    my $nxmax  = $ptinfo{nxmax};

    my $globl  = $ptinfo{globl};
    my $bzpts  = $ptinfo{bzpts};
    my $dsid   = $ptinfo{dsid};
    my $mod    = $ptinfo{dset};


    #  A debug message about the areal coverage of the initialization dataset
    #
    @dpts = ($ptnav{latsw},$ptnav{lonsw},$ptnav{latnw},$ptnav{lonnw},$ptnav{latse},$ptnav{lonse},$ptnav{latne},$ptnav{lonne},$ptnav{latcen},$ptnav{loncen});
    &Ecomm::PrintMessage(4,14+$Uprep{arf},96,2,1,"Areal coverage of the $dsid dataset") if $dbg;
    &Ecomm::PrintMessage(4,14+$Uprep{arf},96,1,3,&Others::FormatCornerPoints(@dpts)) if $dbg;


    if ($dbg) {

        my ($ni,$nj,$alat,$alon,$lat,$lon);

        ($ni,$nj)     = &Emaproj::latlon_to_ij($proj{latsw},$proj{lonsw},%ptnav);
        ($alat,$alon) = &Emaproj::ij_to_latlon($ni,$nj,%ptnav);
        $alat = int ($alat * 100); $alat = $alat * 0.01;
        $alon = int ($alon * 100); $alon = $alon * 0.01;
        $ni   = int ($ni + 0.5);
        $nj   = int ($nj + 0.5);
        $lat  = int ($proj{latsw} * 100); $lat = $lat * 0.01;
        $lon  = int ($proj{lonsw} * 100); $lon = $lon * 0.01;
        &Ecomm::PrintMessage(4,14+$Uprep{arf},144,1,1,"Point 1, 1 ($lat,$lon) on user domain corresponds to $ni,$nj ($alat,$alon) on $dsid dataset");

        ($ni,$nj)     = &Emaproj::latlon_to_ij($proj{latnw},$proj{lonnw},%ptnav);
        ($alat,$alon) = &Emaproj::ij_to_latlon($ni,$nj,%ptnav);
        $alat = int ($alat * 100); $alat = $alat * 0.01;
        $alon = int ($alon * 100); $alon = $alon * 0.01;
        $ni   = int ($ni + 0.5);
        $nj   = int ($nj + 0.5);
        $lat  = int ($proj{latnw} * 100); $lat = $lat * 0.01;
        $lon  = int ($proj{lonnw} * 100); $lon = $lon * 0.01;
        &Ecomm::PrintMessage(4,14+$Uprep{arf},144,0,1,"Point 1, $ydim ($lat,$lon) on user domain corresponds to $ni,$nj ($alat,$alon) on $dsid dataset");

        ($ni,$nj)     = &Emaproj::latlon_to_ij($proj{latne},$proj{lonne},%ptnav);
        ($alat,$alon) = &Emaproj::ij_to_latlon($ni,$nj,%ptnav);
        $alat = int ($alat * 100); $alat = $alat * 0.01;
        $alon = int ($alon * 100); $alon = $alon * 0.01;
        $ni   = int ($ni + 0.5);
        $nj   = int ($nj + 0.5);
        $lat  = int ($proj{latne} * 100); $lat = $lat * 0.01;
        $lon  = int ($proj{lonne} * 100); $lon = $lon * 0.01;
        &Ecomm::PrintMessage(4,14+$Uprep{arf},144,0,1,"Point $xdim, $ydim ($lat,$lon) on user domain corresponds to $ni,$nj ($alat,$alon) on $dsid dataset");

        ($ni,$nj)     = &Emaproj::latlon_to_ij($proj{latse},$proj{lonse},%ptnav);
        ($alat,$alon) = &Emaproj::ij_to_latlon($ni,$nj,%ptnav);
        $alat = int ($alat * 100); $alat = $alat * 0.01;
        $alon = int ($alon * 100); $alon = $alon * 0.01;
        $ni   = int ($ni + 0.5);
        $nj   = int ($nj + 0.5);
        $lat  = int ($proj{latse} * 100); $lat = $lat * 0.01;
        $lon  = int ($proj{lonse} * 100); $lon = $lon * 0.01;
        &Ecomm::PrintMessage(4,14+$Uprep{arf},144,0,1,"Point $xdim, 1 ($lat,$lon) on user domain corresponds to $ni,$nj ($alat,$alon) on $dsid dataset");
    }


    if ($globl) {

        #  The GFS global grid must be handled differently from the limited area grids since 
        #  the current version of wgrib2 does not allow for subsetting across 0 degrees W with 
        #  the -ijsmall_grib opion. Maybe this will change in the future but I will likely
        #  miss the announcement.
        #

        #  Check if +-90 lat is in the domain - Only an issue for PS projections
        #
        if ($proj{proj} eq 'PS') {

            my ($ni,$nj);

            if ($proj{truelat1} lt 0.0) { #  A southern hemisphere grid
                ($ni,$nj) = &Emaproj::latlon_to_ij(-90.0,0,%proj);
                $slat = -90. if ($ni >= 0 and $ni <= $xdim and $nj >= 0 and $nj <= $ydim);
            } else { #  A northern hemisphere grid
                ($ni,$nj) = &Emaproj::latlon_to_ij(90.0,0,%proj);
                $nlat = 90. if ($ni >= 0 and $ni <= $xdim and $nj >= 0 and $nj <= $ydim);
            }
        }

        unless ($slat) {
            $slat = 90.;
            for (my $i = 0; $i <= $xdim; $i++) {
                my ($lat,$lon) = &Emaproj::ij_to_latlon($i,0,%proj);
                $slat = $lat if $lat < $slat;
            }
        }

        unless ($nlat) {
            $nlat = -90.;
            for (my $i = 0; $i <= $xdim; $i++) {
                my ($lat,$lon) = &Emaproj::ij_to_latlon($i,$ydim+1,%proj);
                $nlat = $lat if $lat > $nlat;
            }
        }

        #  Check if domain crosses 0 degrees along western side of domain
        #
        if ($proj{lonsw}*$proj{lonnw}<0) { # crosses +-180 or 0 degrees
            if ( ((abs $proj{lonsw})+(abs $proj{lonnw})) > 180) { #crosses +-180
                $wlon = $proj{lonsw} > 0 ? $proj{lonsw} : $proj{lonnw};
            } else { # crosses 0 degrees
                $wlon = $proj{lonsw} < 0 ? $proj{lonsw} : $proj{lonnw};
            }
        } else { #  does not cross
            $wlon = $proj{lonsw} < $proj{lonnw} ? $proj{lonsw} : $proj{lonnw};
        }


        #  Check if domain crosses 0 degrees along eastern side of domain
        #
        if ($proj{lonse}*$proj{lonne}<0) { # crosses +-180 or 0 degrees
            if ( ((abs $proj{lonse})+(abs $proj{lonne})) > 180) { #crosses +-180
                $elon = $proj{lonse} < 0 ? $proj{lonse} : $proj{lonne};
            } else { # crosses 0 degrees
                $elon = $proj{lonse} > 0 ? $proj{lonse} : $proj{lonne};
            }
        } else { # does not cross
            $elon = $proj{lonse} > $proj{lonne} ? $proj{lonse} : $proj{lonne};
        }

        #  Estimate the DX in degrees at the center of the domain. This value will be used to create
        #  a bufr zone around the personal tile. When completed, dlat & dlon should represent the grid
        #  spacing in degrees of the dataset. Take the average for the bufr zone.
        #
        my ($dni,$dnj)   = &Emaproj::latlon_to_ij($proj{latcen},$proj{loncen},%ptnav); $dni++; $dnj++;
        my ($dlat,$dlon) = &Emaproj::ij_to_latlon($dni,$dnj,%ptnav);
        $dlat = abs($dlat-$proj{latcen});
        $dlon = abs($dlon-$proj{loncen});

        my $deldeg = 0.50*($dlat+$dlon); $deldeg = 1.5*$deldeg; # Fudge factor


        #  Now get the SW corner points of the personal tile domain
        #  
        my ($ni,$nj)   = &Emaproj::latlon_to_ij($slat,$wlon,%ptnav);

        #  Extend the southwest corner outward by deldeg degrees. Assume that
        #  lons decrease westward.
        #
        $slat = $slat - $deldeg unless ($slat-$deldeg <= -90.);
        $wlon = $wlon - $deldeg;


        #  Now get the SW corner points of the extended personal tile domain
        #
        ($dni,$dnj)  = &Emaproj::latlon_to_ij($slat,$wlon,%ptnav);


        #  the personal tile routine needs the lat-lon values at the
        #  dataset grid points, so we need to use integer values to
        #  again calculate the SW point.
        #
        $ni = $dni < $ni ? floor($ni)-1 : ceil($ni)+1;
        $nj = $dnj < $nj ? floor($nj)-1 : ceil($nj)+1;


        #  Calculate the final LAT-LON for the SW dataset grid point
        #
        ($slat,$wlon) = &Emaproj::ij_to_latlon($ni,$nj,%ptnav);


        #  Now we need to do the same with the NE corner
        #
        ($ni,$nj)   = &Emaproj::latlon_to_ij($nlat,$elon,%ptnav);

        $nlat = $nlat + $deldeg unless ($nlat+$deldeg >= 90.);
        $elon = $elon + $deldeg;

        ($dni,$dnj)   = &Emaproj::latlon_to_ij($nlat,$elon,%ptnav);

        $ni = $dni > $ni ? ceil($ni)+1 : floor($ni)-1;
        $nj = $dnj > $nj ? ceil($nj)+1 : floor($nj)-1;

        ($nlat,$elon) = &Emaproj::ij_to_latlon($ni,$nj,%ptnav);


        $elon = $elon + 360.0 if $wlon > $elon and $elon < 0;
        $wlon = $wlon - 360.0 if $wlon > $elon and $elon > 0;

        #  Center point is estimated and not necessarily correct - for display purposes
        #
        @dpts = ($slat, $wlon, $nlat, $wlon, $slat, $elon, $nlat, $elon, $proj{latcen},$proj{loncen});

    } else {

        $mini = 9999;
        $minj = 9999;
        $maxi = 0;
        $maxj = 0;

        #  The initialization grid is not global although we need to
        #  make sure the user is not requesting data from outside
        #  the areal coverage of the initialization dataset.

        #  At the same time get the corner points to be requested
        #

        #  Begin with the S & N boundaries
        #
        my ($lat,$lon,$ni,$nj);
        for my $j (1-$bzpts, $ydim+$bzpts) { #  S & N boundaries
            for (my $i = 1-$bzpts; $i <= $xdim+$bzpts; $i++) {
                ($lat,$lon) = &Emaproj::ij_to_latlon($i,$j,%proj);
                ($ni,$nj)   = &Emaproj::latlon_to_ij($lat,$lon,%ptnav);
                $mini = $ni if $ni < $mini; $minj = $nj if $nj < $minj;
                $maxi = $ni if $ni > $maxi; $maxj = $nj if $nj > $maxj;
                if ($ni < 0 or $ni > $nxmax or $nj < 0 or $nj > $nymax) {
                    $lat = sprintf ( "%.0f", ceil $lat*10.); $lat = $lat * 0.1;
                    $lon = sprintf ( "%.0f", ceil $lon*10.); $lon = $lon * 0.1;

                    $mesg = "The areal coverage of your computational domain lies outside that ".
                            "of the $dsid grid at $lat, $lon ($i,$j). You can not use the ".
                            "$mod personal tiles with this domain.";
                    &Ecomm::PrintMessage(6,9+$Uprep{arf},88,2,2,"Computational Domain Too Large",$mesg);
                    return 0;
                }
            }
        }

        #  Next the W & E boundaries
        #
        for my $i (1-$bzpts, $xdim+$bzpts) { #  S-N boundaries
            for (my $j = 1-$bzpts; $j <= $ydim+$bzpts; $j++) {
                ($lat,$lon) = &Emaproj::ij_to_latlon($i,$j,%proj);
                ($ni,$nj)   = &Emaproj::latlon_to_ij($lat,$lon,%ptnav);
                $mini = $ni if $ni < $mini; $minj = $nj if $nj < $minj;
                $maxi = $ni if $ni > $maxi; $maxj = $nj if $nj > $maxj; 
                if ($ni < 0 or $ni > $nxmax or $nj < 0 or $nj > $nymax) {
                    $lat = sprintf ( "%.0f", ceil $lat*10.); $lat = $lat * 0.1;
                    $lon = sprintf ( "%.0f", ceil $lon*10.); $lon = $lon * 0.1;

                    $mesg = "The areal coverage of your computational domain lies outside that ".
                            "of the $dsid grid at $lat, $lon ($i,$j). You can not use the ".
                            "$mod personal tiles with this domain.";
                    &Ecomm::PrintMessage(6,9+$Uprep{arf},88,2,2,"Computational Domain Too Large",$mesg);
                    return 0;
                }
            }
        }

        #  Add a bufr zone around domain to be extracted
        #
        $mini = int ($mini - 0.5) - $bzpts; $mini = 1 if $mini < 1;
        $minj = int ($minj - 0.5) - $bzpts; $minj = 1 if $minj < 1;
        $maxi = int ($maxi + 0.5) + $bzpts; $maxi = $nxmax if $maxi > $nxmax;
        $maxj = int ($maxj + 0.5) + $bzpts; $maxj = $nymax if $maxj > $nymax;

        &Ecomm::PrintMessage(4,14+$Uprep{arf},144,2,0,"$mini,$maxj ........... $maxi,$maxj final corner points for wgrib2") if $dbg;
        &Ecomm::PrintMessage(4,14+$Uprep{arf},144,1,2,"$mini,$minj ........... $maxi,$minj final corner points for wgrib2") if $dbg;

        #  Now get the corner points for the display
        #
        my ($alat,$alon);

        #  SW corner
        #
        ($alat,$alon) = &Emaproj::ij_to_latlon($mini,$minj,%ptnav);
        $alat = int ($alat * 1000); my $swlat = $alat * 0.001;
        $alon = int ($alon * 1000); my $swlon = $alon * 0.001;

        #  NW corner
        #
        ($alat,$alon) = &Emaproj::ij_to_latlon($mini,$maxj,%ptnav);
        $alat = int ($alat * 1000); my $nwlat = $alat * 0.001;
        $alon = int ($alon * 1000); my $nwlon = $alon * 0.001;

        #  NE corner
        #
        ($alat,$alon) = &Emaproj::ij_to_latlon($maxi,$maxj,%ptnav);
        $alat = int ($alat * 1000); my $nelat = $alat * 0.001;
        $alon = int ($alon * 1000); my $nelon = $alon * 0.001;

        #  SE corner
        #
        ($alat,$alon) = &Emaproj::ij_to_latlon($maxi,$minj,%ptnav);
        $alat = int ($alat * 1000); my $selat = $alat * 0.001;
        $alon = int ($alon * 1000); my $selon = $alon * 0.001;

        #  Center Point
        #
        my $ci = $mini + ($maxi-$mini)*0.5;
        my $cj = $minj + ($maxj-$minj)*0.5;
        ($alat,$alon) = &Emaproj::ij_to_latlon($ci,$cj,%ptnav);
        $alat = int ($alat * 1000); my $cplat = $alat * 0.001;
        $alon = int ($alon * 1000); my $cplon = $alon * 0.001;

        @dpts = ($swlat, $swlon, $nwlat, $nwlon, $selat, $selon, $nelat, $nelon, $cplat, $cplon);

    }

    &Ecomm::PrintMessage(1,11+$Uprep{arf},96,1,1,"Areal coverage of your $dsid personal tile");
    &Ecomm::PrintMessage(0,14+$Uprep{arf},96,1,2,&Others::FormatCornerPoints(@dpts));


    #----------------------------------------------------------------------------------
    #  Build portions of the URL command to send to the server to request the data.
    #----------------------------------------------------------------------------------
    #
    my @list   = ();
    my $script = qw{};

    for my $lfile (sort keys %files) {
        ($script, my $rfile ) = split  /\?/ => $files{$lfile};
        push @list => "file=$rfile";
    }

    my $flist   = join "&" => @list;

    my $domain  =  $globl ? "leftlon=$wlon&rightlon=$elon&toplat=$nlat&bottomlat=$slat" : "mini=$mini&maxi=$maxi&minj=$minj&maxj=$maxj";

    my $dset    = "dset=$mod";
       $dset    = "$dset&lsm" if $lsm;

    my $https   = "http://$host";
    my $request = "\"$https$script?$flist&$domain&$dset\"";


    if ($dbg) {
        $request =~ s/"//g;
        &Ecomm::PrintMessage(4,14+$Uprep{arf},999,1,1,"$request&debug") if $dbg;
    }

return $request;
}


