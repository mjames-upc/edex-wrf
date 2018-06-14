#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Auems.pm
#
#  DESCRIPTION:  Auems module contains the routines that drive ems_prep, 
#                ems_run, and ems_post, but not necessarily in that order.
#                order. 
#
#                Ok, yes, in that order.
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.3.1
#      CREATED:  08 March 2018
#===============================================================================
#
package Auems;

use warnings;
use strict;
require 5.008;
use English;

use Ecomm;



sub AutoPrepDriver {
#==================================================================================
#  This routine sets up and runs the ems_prep.pl routine to download and process
#  initialization data for a model simulation.
#==================================================================================
#
use Pmain;
use Autils;


    my $upref  = shift; my %Uauto = %{$upref};


    #----------------------------------------------------------------------------------
    #  Just something to amuse myself - Nothing to see here.
    #----------------------------------------------------------------------------------
    #
    my @animals = ('Pink Fairy Armadillo', 'Mullberry Street Unicorn', 'Aye-aye', 'Naked Mole Rat', 'Dugong', 'Blob Fish',
                   'Dumbo Octopus', 'Blue-green Abelard', 'Andulovian Grackler', 'Goo-Goo-Eyed Tasmanian Wolghast', 
                   'Semi-Normal Green-Lidded Fawn', 'Tufted Gustard', 'Two Horned Drouberhannis', 'Flaming Herring', 
                   'Anthony Drexel Goldfarb', 'Eddie', 'Ice Cream Cone Worm', 'Satanic Leaf-tailed Gecko', 'Wunderpus Photogenicus');

    my @emotions = ('jubilant', 'euphoric', 'exultant', 'triumphant', 'enraptured', 'rhapsodic', 'enchanted', 'exhilarated',
                    'joyous', 'frolicsome', 'exuberant', 'good looking', 'fabulous', 'ebullient', 'zesty', 'effervescent',
                    'enthusiastic', 'effusive', 'irrepressible', 'vivacious', 'passionate');
                   

    #----------------------------------------------------------------------------------
    #  The Uparms hash hold the configuration variables to be passed along to the 
    #  run-time driver routines. The parameters include: aerosols, attempts,  autopost,  
    #  debug,  domains,  dsets,  emspost,  length,  lsms,  nolock,  nudging,  rcycle,  
    #  rdate,  rundir,  scour,  sfcs,  sleep,  syncsfc,  users,  wait.
    #----------------------------------------------------------------------------------
    #
    my %Uparms = %{$Uauto{parms}};

    
    #  Do the housekeeping. Moved from Astart::options to avoid problems when a
    #  previous simulation is still running.
    #
    return () if &Autils::AutoCleaner($Uparms{scour},$Uauto{rtenv}{dompath},0);


    #----------------------------------------------------------------------------------
    #  %Pmesgs contains diagnostic messages should ems_prep fail, which it will.
    #  &Pacquire::ReturnMessages lists the return codes as 0, 21, 22, 23, and 24.
    #  Return code 0 is switched for 20 id the --noproc flag was passed. Some
    #  return codes don't require additional blather (23 & 24).
    #----------------------------------------------------------------------------------
    #
    my %Pmesgs  = ();

    $Pmesgs{11} = 'AutoPrep: A problem was encountered during ems_prep initialization';
    $Pmesgs{12} = 'AutoPrep: There is a problem with the ems_prep options';
    $Pmesgs{13} = 'AutoPrep: A problem was encountered during ems_prep configuration';

    $Pmesgs{00} = "AutoPrep: Success - Please commence the dance of the $emotions[int rand @emotions] $animals[int rand @animals]!";
    $Pmesgs{20} = 'AutoPrep: Just as you wished, your requested files have been downloaded - Enjoy!';
    $Pmesgs{21} = 'AutoPrep: Well, at least this hurts you more than it hurts me!';
    $Pmesgs{22} = 'AutoPrep: Time to try another dataset for initialization';
    $Pmesgs{23} = 'AutoPrep: That dataset made you look older anyway';
    $Pmesgs{24} = 'AutoPrep: We\'re so close! You can almost taste the bitter smell of success!';

    $Pmesgs{31} = 'AutoPrep: I\'m not laying any blame, but one of us mangled the GRIB file processing again.';
    $Pmesgs{41} = 'AutoPrep: The interpolation of data to the computational domain is always the most difficult step.';


    #----------------------------------------------------------------------------------
    #  Specify the arguments to be passed to ems_prep. If this is a benchmark run
    #  then the user input arguments are limited to just a couple to avoid failure.
    #----------------------------------------------------------------------------------
    #
    my @pargs=();
    if ($Uparms{rtenv}{bench}) {
        push @pargs => '--bench';
        push @pargs => '--domains 2'                   if $Uparms{pdomains};
        push @pargs => '--noscour';
        push @pargs => "--length   $Uparms{length}"    if $Uparms{length};
    } else {
        push @pargs => "--date     $Uparms{rdate}"     if $Uparms{rdate};
        push @pargs => "--cycle    $Uparms{rcycle}"    if $Uparms{rcycle};
        push @pargs => "--length   $Uparms{length}"    if $Uparms{length};
        push @pargs => "--domains  $Uparms{pdomains}"  if $Uparms{pdomains};
        push @pargs => "--sfc      $Uparms{sfcs}"      if $Uparms{sfcs};
        push @pargs => "--syncsfc  $Uparms{syncsfc}"   if $Uparms{syncsfc};
        push @pargs => "--lsm      $Uparms{lsms}"      if $Uparms{lsms};
        push @pargs => "--aerosols"                    if $Uparms{aerosols};
        push @pargs => "--attempts $Uparms{attempts}"  if $Uparms{attempts};
        push @pargs => "--sleep    $Uparms{sleep}"     if $Uparms{sleep};
        push @pargs => '--debug'                       if $Uparms{debug};
        push @pargs => '--noscour';
    }
    @pargs = split / +/ => (join ' ' => @pargs);


    #----------------------------------------------------------------------------------
    #  Begin running of ems_prep by looping over all the requested initialization 
    #  datasets.  The $pdset variable holds the previous dataset should the 
    #  '--previous' flag be encountered.  
    #
    #  The possible return codes are associated with a message stored in the %Pmesgs
    #  hash that is returned to the calling routine &AutoProcess via $ENV{AMESG}.
    #----------------------------------------------------------------------------------
    #
    my $date = gmtime();
    &Ecomm::PrintMessage(0,4,144,2,2,sprintf ("AutoPrep: Starting UEMS routine ems_prep on %s UTC",$date));


    my $pdset = '';
    foreach my $dset (split /,/ => $Uparms{dsets}) {

        my @args = ($dset =~ /previous/i) ? ('--dset', $pdset, '--previous') : ('--dset', $dset);

        #  If a fail-over was specified for the LSM dataset then we need to determine just
        #  how to handle the --lsm argument passed to ems_prep. It gets a bit tricky as 
        #  the error code must be handled correctly.
        #
        @args = (@args, @pargs);

        $ENV{AMESG} = ();

        for (my $rc = &Pmain::ProcessDriver(@args)) {

            $Uauto{rc} = $rc ? 2 : 0;
            my $umesg  = (defined $ENV{PMESG} and $ENV{PMESG}) ? $ENV{PMESG} : '';

            if (grep {/^$rc$/} (0))                 {&Ecomm::PrintMessage(0,4,255,2,1,$umesg || $Pmesgs{00});  return %Uauto;}
            if (grep {/^$rc$/} (11,12,13,21,31,41)) {&Ecomm::PrintMessage(0,4,255,2,2,$umesg || $Pmesgs{$rc}); return ();}
            if (grep {/^$rc$/} (20))                {&Ecomm::PrintMessage(0,4,255,2,2,$umesg || $Pmesgs{20});  return ();}
            if (grep {/^$rc$/} (22))                {&Ecomm::PrintMessage(0,4,255,2,1,$Pmesgs{22});}

        }
        &Ecomm::PrintMessage(0,4,255,2,1,$Pmesgs{23});
    }

    # Should only reach here if all datasets fail.
    #
    &Ecomm::PrintMessage(0,4,255,2,1,'AutoPrep Failed - Some|Most|All initialization data not available! I really tried though!');


return ();
}



sub AutoRunDriver {
#==================================================================================
#  This routine sets up and runs the ems_run.pl routine to download and process
#  initialization data for a model simulation.
#==================================================================================
#
use Rmain;
use Autils;

    my $upref  = shift; my %Uauto = %{$upref};


    #----------------------------------------------------------------------------------
    #  The Uparms hash hold the configuration variables to be passed along to the 
    #  run-time driver routines. The parameters include: aerosols, attempts,  autopost,  
    #  debug,  domains,  dsets,  emspost,  length,  lsms,  nolock,  nudging,  rcycle,  
    #  rdate,  rundir,  scour,  sfcs,  sleep,  syncsfc,  users,  wait.
    #----------------------------------------------------------------------------------
    #
    my %Uparms = %{$Uauto{parms}};


    #----------------------------------------------------------------------------------
    #  %Rmesgs contains diagnostic messages should ems_run fail, which it will.
    #  &Pacquire::ReturnMessages lists the return codes as 0, 21, 22, 23, and 24.
    #  Return code 0 is switched for 20 id the --noproc flag was passed. Some
    #  return codes don't require additional blather (23 & 24).
    #----------------------------------------------------------------------------------
    #
    my %Rmesgs     = ();

       $Rmesgs{0}  = "AutoRun: Your Simulation Successfully Completed - Let's celebrate together!";

       $Rmesgs{11} = "AutoRun: A problem was encountered during ems_run initialization";
       $Rmesgs{12} = "AutoRun: A problem was encountered during the parsing of ems_run options";
       $Rmesgs{13} = "AutoRun: A problem was encountered during ems_run configuration";
       
       $Rmesgs{21} = "AutoRun: Decomposition is just not your thing";
       $Rmesgs{22} = "AutoRun: The ems_run routine failed while creating initial and boundary condition files";
       $Rmesgs{23} = "AutoRun: Our simulation failed to meet my expectatons - again!";

       $Rmesgs{10} = "AutoRun: Disk space issues encountered on your local system - please investigate";
       $Rmesgs{53} = "AutoRun: Model simulation successfully completed but the autopost failed.\n".
                     "         Running ems_post routine separately with autopost options.";


    #----------------------------------------------------------------------------------
    #  Specify the arguments to be passed to ems_run. If this is a benchmark run
    #  then the user input arguments are limited to just a couple to avoid failure.
    #----------------------------------------------------------------------------------
    #
    my @pargs=();
    if ($Uauto{BM}) {
        push @pargs => "--bench";
        push @pargs => "--domains 2"                    if $Uparms{rdomains};
        push @pargs => "--autopost $Uparms{autopost}"   if $Uparms{autopost};
        push @pargs => "--ahost $Uparms{ahost}"         if $Uparms{autopost};  #  Yes, this should be $Uparms{autopost}
        push @pargs => "--nudging"                      if $Uparms{nudging};
    } else {
        push @pargs => "--domains $Uparms{rdomains}"    if $Uparms{rdomains};
        push @pargs => "--noscour";
        push @pargs => "--autopost $Uparms{autopost}"   if $Uparms{autopost};
        push @pargs => "--ahost $Uparms{ahost}"         if $Uparms{autopost};  #  Again, this should be $Uparms{autopost}
        push @pargs => "--nudging"                      if $Uparms{nudging};
    }
    @pargs = split / +/ => (join " " => @pargs);


    #----------------------------------------------------------------------------------
    #  Start the ems_run routine  that executes the simulation. The $Uauto{rc} 
    #  variable is used to monitor the success/failure of ems_autopost.pl.
    #----------------------------------------------------------------------------------
    #
    my $date = gmtime();
    &Ecomm::PrintMessage(0,4,144,2,2,sprintf ("AutoRun:  Starting UEMS routine ems_run  on %s UTC",$date));

    for ($Uauto{rc} = &Rmain::ProcessDriver(@pargs)) {

        my $umesg = (defined $ENV{RMESG} and $ENV{RMESG}) ? $ENV{RMESG} : '';

        if ($Uauto{rc} ==  0) {&Ecomm::PrintMessage(0,4,255,1,1,$Rmesgs{0}) ;return %Uauto;}
        if ($Uauto{rc} == 53) {&Ecomm::PrintMessage(0,7,255,1,1,$Rmesgs{53});return %Uauto;}

        &Ecomm::PrintMessage(0,7,255,1,1,$umesg || $Rmesgs{$Uauto{rc}});

    }
   
    &Autils::AutoMailer(\%Uauto);


return ();
}



sub AutoPostDriver {
#==================================================================================
#  This routine sets up and runs the ems_post.pl routine to download and process
#  initialization data for a model simulation.
#==================================================================================
#
use Omain;
use Autils;

    my $upref  = shift; my %Uauto = %{$upref};


    #----------------------------------------------------------------------------------
    #  Need to check the status of the $Uauto{rc} variable for a value of 53, which
    #  indicates that the ems_autopost.pl routine failed and thus the domains and 
    #  datasets requested must be merged with $Uauto{parms}{emspost}. If the Autopost
    #  did fail then we have some additional work.
    #----------------------------------------------------------------------------------
    #
    $Uauto{parms}{emspost} = $Uauto{parms}{mergpost} if $Uauto{rc} == 53;
        
    return %Uauto unless $Uauto{parms}{emspost};


    #----------------------------------------------------------------------------------
    #  The Uparms hash hold the configuration variables to be passed along to the 
    #  post-time driver routines. The ems_post parameters include: autopost,  
    #  debug,  domains,  emspost, length, and rundir.  Everything else is obtained
    #  from the post_ configuration files.
    #----------------------------------------------------------------------------------
    #
    my %Uparms = %{$Uauto{parms}};


    #----------------------------------------------------------------------------------
    #  %Omesgs contains diagnostic messages should ems_post fail, which it will.
    #----------------------------------------------------------------------------------
    #
    my %Omesgs     = ();

       $Omesgs{11} = 'AutoPost: A problem was encountered during ems_post initialization';
       $Omesgs{12} = 'AutoPost: There is a problem with the ems_post options';
       $Omesgs{13} = 'AutoPost: A problem was encountered during ems_post configuration';

       $Omesgs{00} = "AutoPost: The simulation output has been processed and delivered to you safely - We're a team!";
       $Omesgs{21} = 'AutoPost: Well, at least this hurts you more than it hurts me!';


    #----------------------------------------------------------------------------------
    #  Specify the arguments to be passed to ems_post. If this is a benchmark run
    #  then the user input arguments are limited to just a couple to avoid failure.
    #----------------------------------------------------------------------------------
    #
    my @pargs=();
    push @pargs => "--rundir   $Uparms{rundir}";
    push @pargs => "--emspost  $Uparms{emspost}"    if $Uparms{emspost};

    push @pargs => "--autorun";
    @pargs = split / +/ => (join " " => @pargs);


    #----------------------------------------------------------------------------------
    #  Begin running of ems_post.
    #----------------------------------------------------------------------------------
    #
    my $date = gmtime();
    &Ecomm::PrintMessage(0,4,255,2,2,sprintf ("AutoPost: Starting UEMS routine ems_post on %s UTC",$date));

    for (my $rc = &Omain::ProcessDriver(@pargs)) {

       $Uauto{rc} = $rc ? 31 : 0;
       my $umesg  = (defined $ENV{OMESG} and $ENV{OMESG}) ? $ENV{OMESG} : '';

       if ($rc ==  0) {&Ecomm::PrintMessage(0,7,255,1,2,$umesg || $Omesgs{00});return %Uauto;}
       if ($rc == 11) {&Ecomm::PrintMessage(6,7,255,2,2,$umesg || $Omesgs{11});return ();}
       if ($rc == 12) {&Ecomm::PrintMessage(6,7,255,2,2,$umesg || $Omesgs{12});return ();}
       if ($rc == 13) {&Ecomm::PrintMessage(6,7,255,2,2,$umesg || $Omesgs{13});return ();}
       if ($rc == 21) {&Ecomm::PrintMessage(6,7,255,2,2,$umesg || $Omesgs{21});return ();}
    }

    &Ecomm::PrintMessage(6,7,255,2,1,"AutoPost: The ems_post routine failed for some unknown reason - Check it out");


return ();
}



