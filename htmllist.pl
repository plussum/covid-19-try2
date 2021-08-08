#!/usr/bin/perl
#
#
use strict;
use warnings;
use utf8;
use Encode 'decode';
use Data::Dumper;

use config;
use csvlib;
use csv2graph;
use dp;

my $WIN_PATH = $config::WIN_PATH;
my $index_html = "$WIN_PATH/covid2_frame.html";
my $HTML_PATH = "$WIN_PATH/HTML2";

# <li><a href ="HTML2/japanpref_pop.html" target="graph"><b>Japan Pref_POP</b></a></li>
my @LIST = ();
open(HTML, $index_html) || die "cannot open $index_html";
while(<HTML>){
	next if(/<!--/);
	if(/href *= *"([^"]+)".*<b>([^\<]+)\</){
		my($fn, $dsc) = ($1, $2);
		$fn = "$WIN_PATH/$fn";	
		my $ymd = "NO FILE";
		if(-e $fn){
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($fn);
			$ymd = csvlib::ut2dt($mtime);
		}
		push(@LIST, sprintf("%s %-30s %s\n", $ymd, $dsc, $fn));
	}
}
close(HTML);

open(OUT, "> $HTML_PATH/times.txt") || die "cannot create $HTML_PATH/times.txt";
my $ymd = csvlib::ut2dt(time);
print OUT "LIST CREATED: $ymd\n" . "\n";

my $i = 0;
foreach my $l (sort @LIST){
	print OUT sprintf("%2d: ", $i++) . $l;
}
close(OUT);

