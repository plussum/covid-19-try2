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

my $fname = "data_dir/CSV/vaccine.ndjson";
my $out = "data_dir/vaccine.txt";
open(FD, $fname) || die "cannot open $fname";
open(OUT, ">$out") || die "cannot create $out\n";
my $line = 0;
while(<FD>){
	s/[\r\n]+$//;
	s/^{//;
	s/}$//;
	my @w = split(/,/, $_);
	my @nmlist = ();
	my @vals = ();
	foreach my $item (@w){
		$item =~ s/\"//g;
		my ($nm, $v) = split(/:/, $item);
		push(@nmlist, $nm);
		push(@vals, $v);
	}
	if($line++ <= 0){
		print OUT join("\t", @nmlist) . "\n";
	}
	print OUT join("\t", @vals) . "\n";
}
close(FD);
close(OUT);
