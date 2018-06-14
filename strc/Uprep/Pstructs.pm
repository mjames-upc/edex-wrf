#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Pstructs.pm
#
#  DESCRIPTION:  The dset_struct defines the structure used to hold the 
#                information about the dataset(s) requested for initialization
#                when running ems_prep.
#
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Pstructs;

use warnings;
use strict;
require 5.008;
use English;

use Class::Struct;

#===============================================================================
#  The dset_struct defines the structure used to hold the information about
#  the dataset(s) requested for initialization when running ems_prep. Any
#  information passed by the user, such as initialization date, length, 
#  instructions for file acquisition, etc., are carried by this structure.
#  
#  Note that there is a unique structure for each initialization dataset
#  regardless how it is to be used.
#===============================================================================
#  
   struct dset_struct =>
   [
       #  Initialized from gribinfo files
       #
       dset       => '$',
       gfile      => '$',
       info       => '$',
       category   => '$',
       vcoord     => '$',
       initfh     => '$',
       finlfh     => '$',
       freqfh     => '$',
       initfm     => '$',
       finlfm     => '$',
       freqfm     => '$',
       delay      => '$',
       cycles     => '@',
       sources    => '%',
       locfil     => '$',
       maxfreq    => '$',
       vtable     => '$',
       lvtable    => '$',
       metgrid    => '$',
       timed      => '$',
       aged       => '$',
       ptile      => '$',
       analysis   => '$',


       #  Assigned based upon user input
       #
       useid      => '$',
       acycle     => '$',  #  Cycle hour of dataset
       yyyymmdd   => '$',  #  Date of dataset
       yyyymmddcc => '$',  #  Really just yyyymmdd+acycle
       yyyymmddhh => '$',  #  First date & hour to use from dataset
       sim00hr    => '$',  #  Simulation start date & time
       rsdate     => '$',  #  Same as sim00hr for legacy
       redate     => '$',  #  Simulation stop date & time
       length     => '$',  #  Simulation length in hours
       local      => '$',  #  File already reside in grib directory
       syncsfc    => '$',  #  Match surface dset to model valid time
       aerosols   => '$',  #  Name of supported aerosol data for use with Thompson MP scheme
       process    => '$',  #  Whether to process dataset (default is yes (1)
       status     => '$',  #  Hold the status (error) value of each dataset
       

       flist      => '@',  #  DO WE NEED THIS ANYMORE?
       gribs      => '@',
       nlink      => '$'
   ];

{
   return new dset_struct;
}

