#!/usr/bin/perl
#
use strict;
use warnings;
#use encoding "cp932";
use utf8;
use Encode 'decode';
use Data::Dumper;
use List::Util 'min';
use config;
use csvlib;
use csv2graph;
use dp;


binmode(STDOUT, ":utf8");
use defvac;


my $def = $defvac::VACCINE_DEF;
my $download = $def->{download};

