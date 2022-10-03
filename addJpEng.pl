#!/usr/bin/perl
#
#
#
use strict;
use warnings;

my $fn = "/mnt/f/_share/cov/plussum.github.io/pop.csv";

my @line = ();
open(FD, $fn) || die "$fn";
while(<FD>){
	push(@line, $_);
	if(/;Japan/){
		s/$&//;
		push(@line, $_);
	}
}
close(FD);

system("cp $fn $fn.old");
open(OUT, "> $fn.new") || die "cannot create $fn.new";
foreach my $r (@line){
	print OUT $r;
}
close(OUT);

