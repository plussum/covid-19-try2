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
	if($timefmt eq "%Y/%m/%d"){
		$date =~ s#/#-#g;
	}
	elsif($timefmt eq "%m/%d/%y"){
		my($m, $d, $y) = split(/\//, $date);
		$date = sprintf("%04d-%02d-%02d", $y + 2000, $m, $d);
	}
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

sub	date_calc
{
	my($date, $default, $max, $list) = @_;
			
	$date = $date // "";
	$date = $default if($date eq "");

	#dp::dp "[[$date,$default,$max,$list]]\n";
	if(! ($date =~ /[0-9][\-\/][0-9]/)){
		#dp::dp "[[$date]]\n";
		if($date < 0){
			$date = $max + $date;
		}
		if($date < 0 || $date > $max){
			dp::dp "Error at date $date\n";
			$date = 0;
		}
		#dp::dp "[[$date]]\n";
		$date = $list->[$date];
		#dp::dp "[[$date]]\n";
	}
	return $date;
}

1;
