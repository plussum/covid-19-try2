#
#
#
package util;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(util);

use strict;
use warnings;
use utf8;
use Encode 'decode';
use JSON qw/encode_json decode_json/;
use Data::Dumper;
use config;
use csvlib;
use dump;


sub	csv
{
	my ($line) = @_;

	$line =~ s/"*[\r\n]+$//;
	$line =~ s/",/,/g;
	$line =~ s/,"/,/g;
	return (split(/,/, $line));
}

#
#	Combert time format
#
sub	timefmt
{
	my ($timefmt, $date) = @_;

	#dp::dp "[$timefmt][$date]\n";
	my($y, $m, $d) = (); 
	if($timefmt eq "%Y-%m-%d"){
		($y, $m, $d) = split(/-/, $date);
	}
	elsif($timefmt eq "%Y/%m/%d"){
		#$date =~ s#/#-#g;
		($y, $m, $d) = split(/\//, $date);
	}
	elsif($timefmt eq "%m/%d/%y"){
		($m, $d, $y) = split(/\//, $date);
		$y += 2000;
		#$date = sprintf("%04d-%02d-%02d", $y + 2000, $m, $d);
	}
	if(!defined $y){
		dp::ABORT "Unkonw format $timefmt\n";
	}
	my $dtt = join("", $y,$m,$d);
	if($dtt =~ /[^0-9]/){
		dp::ABORT "Error: timefmt[$timefmt] date[$date] [$dtt]\n";
	}
	$date = sprintf("%04d-%02d-%02d", $y, $m, $d);
	#dp::dp $date . "\n";
	return $date;
}

sub	array_size
{
	my ($p) = @_;

	my $tn = -1;
	my $ref = ref($p);
	if($ref eq "HASH"){
		$tn = keys(%$p);
	}
	elsif($ref eq "ARRAY"){
		$tn = scalar(@$p);
	}
	return $tn;
}

#
#	$date		date to calc yyyy-mm-dd or number 0, -91
#	$default	use as date when date udenfined (0)
#	$max		number of date list
#	$list		date list, or start date by yyyy-mm-dd
#
#	return		yyyy-mm-dd
#
sub	date_calc
{
	my($date, $default, $max, $list) = @_;
			
	#csvlib::disp_caller(1..3);

	$date = $date // "";
	$date = $default if($date eq "");

	#dp::dp "[[$date,$default,$max,$list]]\n";
	#if(!$date ){ }
	#elsif(!($date =~ /[0-9][\-\/][0-9]/)){	# 
	if($date =~ /^[\-\+]?\d+$/){ 
		#dp::dp "[[$date]]\n";
		if($date < 0){
			$date = $max + $date;
		}
		if($date < 0 || $date > $max){
			dp::WARNING "Error at date $date (date is not between  0 to $max)\n";
			$date = 0;
		}
		#dp::dp "[[$date]]\n";
		if(ref($list) eq "ARRAY"){
			#dp::dp "$date <- " . $list->[$date] . "\n";
			$date = $list->[$date];
		}
		else {
			#dp::dp "date_calc list: $list\n";
			my $date_ut = csvlib::ymds2tm($list) + $date * 24*60*60;
			$date = csvlib::ut2date($date_ut, "-");
			#dp::dp "[[$date]]\n";
		}
	}
	#dp::dp $date . "\n";
	return $date;
}

sub	date_pos
{
	my($date, $default, $max, $list) = @_;

	$date = &date_calc($date, $default, $max, $list);
	my $start_date = (ref($list) eq "ARRAY") ? $list->[0] : $list;
	#dp::dp "$start_date, $date\n";

	my $start_ut = csvlib::ymds2tm($start_date);
	my $ut = csvlib::ymds2tm($date);

	my $pos = ($ut - $start_ut) / (24*60*60);
	#dp::dp $pos . "\n";
	return $pos;
}

1;
