#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Dutils.pm
#
#  DESCRIPTION:  Dutils contains subroutines used by multiple ems_domain
#                modules. No real organization, just a dumping ground.
#
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Dutils;

use warnings;
use strict;
require 5.008;
use English;

use Others;
use Ecore;
use Ecomm;
use vars qw (@RNS);

sub RefreshRuntimeDomain {
#=====================================================================
#  This routine is the ems_run front end that calls the UEMS
#  cleaning utility.  Each one of the run-time routines should have 
#  a similar subroutine in its arsenal.  This routine should probably
#  be moved to the Eclean module, but I'm too lazy.
#=====================================================================
#
use Eclean;

    my ($level, $domain) = @_; return unless $domain;

    my @args = ('--domain',$domain,'--level',$level,'--silent');


return &Eclean::CleanDriver(@args);
}


sub LookupGreenFractionDataset {
#==================================================================================
#  This subroutine takes an argument and attempts to match it to an available
#  greenness fraction dataset used in the creation of the WPS terrestrial dataset.
#
#  Available datasets are specified by the keys defined in uems/datatables/wps/GEOGRID.TBL,
#  where:
#         rel_path = KEY:dataset directory
#
#  If there is no match then an empty string is returned.
#==================================================================================
#
    #  Currently available datasets 
    #
    my @gf_modis = qw(modis_fpar);
    my @gf_nesdis= qw(nesdis_greenfrac);

    my ($passed, $exact) = @_; $exact = (defined $exact and $exact) ? 1 : 0;

    return '' unless defined $passed and $passed; $passed = lc $passed;

    for ($passed) {
        return $passed       if grep {/^${passed}$/} (@gf_modis,@gf_nesdis);
        unless ($exact) {
            return $gf_modis[0]  if /^mo/;
            return $gf_nesdis[0] if /^ne/;
        }
    }


return '';  #  Don't play games
}


sub LookupLanduseDataset {
#==================================================================================
#  This subroutine takes an argument and attempts to match it to an available
#  landuse dataset used in the creation of the WPS terrestrial dataset. Available
#  datasets are specified by the keys defined in uems/datatables/wps/GEOGRID.TBL,
#  where:
#         rel_path = KEY:dataset directory
#
#  If there is no match then an empty string is returned.
#==================================================================================
#
    #  Currently available datasets 
    #
    my @lu_modis = qw(modis modis_30s_lake modis_15s modis_30s modis_lakes);
    my @lu_usgs  = qw(usgs usgs_lakes usgs_30s usgs_2m usgs_5m usgs_10m);
    my @lu_nlcd11= qw(nlcd2011_9s);
    my @lu_nlcd06= qw(nlcd2006_9s nlcd2006_30s nlcd2006);
    my @lu_ssib  = qw(ssib ssib_5m ssib_10m);

    my ($passed, $exact) = @_; $exact = (defined $exact and $exact) ? 1 : 0;

    return '' unless defined $passed and $passed; $passed = lc $passed;

    for ($passed) {
        return $passed       if grep {/^${passed}$/} @lu_modis;
        return $lu_modis[0]  if /^mod/ and ! $exact;

        return $passed       if grep {/^${passed}$/} @lu_usgs;
        return $lu_usgs[0]   if /^usg/ and ! $exact;

        return $passed       if grep {/^${passed}$/} @lu_ssib;
        return $lu_ssib[0]   if /^ssi/ and ! $exact;

        return $passed       if grep {/^${passed}$/} @lu_nlcd11;
        return $lu_nlcd11[0] if /^nlcd201/;

        return $passed       if grep {/^${passed}$/} @lu_nlcd06;
        return $lu_nlcd06[0] if /^nlcd200/;

        return $lu_nlcd11[0] if /^nc|^nl/;
    }


return '';  #  Don't play games
}


sub LookupSoilTypeDataset {
#==================================================================================
#  This subroutine takes an argument and attempts to match it to an available
#  soil dataset used in the creation of the WPS terrestrial dataset.
#
#  Available datasets are specified by the keys defined in uems/datatables/wps/GEOGRID.TBL,
#  where:
#         rel_path = KEY:dataset directory
#
#  If there is no match then an empty string is returned.
#==================================================================================
#
    #  Currently available datasets 
    #
    my @sc_bnu   = qw(bnu_soil_30s);
    my @sc_def   = qw(30s 2m 5m 10m);

    my ($passed, $exact) = @_; $exact = (defined $exact and $exact) ? 1 : 0;

    return '' unless defined $passed and $passed; $passed = lc $passed;

    for ($passed) {
        return $passed     if grep {/^${passed}$/} (@sc_bnu,@sc_def);
        return $sc_bnu[0]  if /^bnu/;
    }


return '';  #  Don't play games
}


sub LookupTerrainDataset {
#==================================================================================
#  This subroutine takes an argument and attempts to match it to an available
#  terrain elevation dataset used in the creation of the WPS terrestrial dataset.
#
#  Available datasets are specified by the keys defined in uems/datatables/wps/GEOGRID.TBL,
#  where:
#         rel_path = KEY:dataset directory
#
#  If there is no match then an empty string is returned.
#==================================================================================
#
    #  Currently available datasets 
    #
    my @te_gtopo = qw(gtopo gtopo_30s gtopo_2m gtopo_5m gtopo_10m);  #  Used to be 30s, 2m, 5m, 10m
    my @te_gmted = qw(gmted2010_30s);

    my ($passed, $exact) = @_; $exact = (defined $exact and $exact) ? 1 : 0;

    return '' unless defined $passed and $passed; $passed = lc $passed;

    for ($passed) {
        return $passed       if grep {/^${passed}$/} (@te_gtopo,@te_gmted);
        return $te_gmted[0]  if /^gmt/;
        return $te_gtopo[0]  if /^gto|^top/;
    }


return '';  #  Don't play games
}


sub LookupLeafAreaIndexDataset {
#==================================================================================
#  This subroutine takes an argument and attempts to match it to an available
#  leaf area index dataset used in the creation of the WPS terrestrial dataset.
#
#  Available datasets are specified by the keys defined in uems/datatables/wps/GEOGRID.TBL,
#  where:
#         rel_path = KEY:dataset directory
#
#  If there is no match then an empty string is returned.
#==================================================================================
#
    #  Currently available datasets 
    #
    my @lai_modis = qw(modis_lai); #  modis_lai get you 30s lai; otherwise default

    my ($passed, $exact) = @_; $exact = (defined $exact and $exact) ? 1 : 0;

    return '' unless defined $passed and $passed; $passed = lc $passed;

    for ($passed) {
        return $passed       if grep {/^${passed}$/} @lai_modis;
        return $lai_modis[0]  if /^lai/;
    }


return '';  # Default
}


sub LookupGravityWaveDragDataset {
#==================================================================================
#  This subroutine takes an argument and attempts to match it to an available
#  gravity wave drag fields used in the creation of the WPS terrestrial dataset.
#
#  Available datasets are specified by the keys defined in uems/datatables/wps/GEOGRID.TBL,
#  where:
#         rel_path = KEY:dataset directory
#
#  If there is no match then an empty string is returned.
#==================================================================================
#
    #  Currently available datasets 
    #
    my @gw_def   = qw(20m 30m 1deg 2deg);  #  Exclude 10m because its the default and conflicts with other 10m fields

    my ($passed, $exact) = @_; $exact = (defined $exact and $exact) ? 1 : 0;

    return '' unless defined $passed and $passed; $passed = lc $passed;

    for ($passed) {
        return $passed     if grep {/^${passed}$/} @gw_def;
    }


return '';  #  Don't play games
}


