#
#
#
package marge;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(marge);

use strict;
use warnings;
use utf8;
use Encode 'decode';
use JSON qw/encode_json decode_json/;
use Data::Dumper;
use config;
use csvlib;
use dump;
use util;
use csv2graph;

my $DEBUG = 0;
my $VERBOSE = 0;

#
#
#
sub	marge_csv
{
	my (@src_csv_list) = @_;

	my $marge = {};
	return &marge_csv_a($marge, @src_csv_list);
}

#
#	Marge csvdef
#
sub	marge_csv_a
{
	my ($marge, @src_csv_list) = @_;

	&csv2graph::new($marge);
	foreach my $key (@$csv2graph::cdp_values){
		my $v = "";
		foreach my $src_cdp (@src_csv_list){
			$marge->{$key} = $src_cdp->{$key} // "";
			last if($marge->{$key});
		}
	}

	my $date_start = "0000-00-00";
	foreach my $cdp (@src_csv_list){
		my $dt = $cdp->{date_list}->[0];
		$date_start = $dt if($dt gt $date_start );
		#dp::dp "date_start[$dt] $date_start\n";
	}
	my $date_end = "9999-99-99";
	foreach my $cdp (@src_csv_list){
		my $dates = $cdp->{dates};
		my $dt = $cdp->{date_list}->[$dates];
		$date_end = $dt if($dt le $date_end );
		#dp::dp "date_end[$dt] $date_end\n";
	}
	my $dates = csvlib::date2ut($date_end, "-") - csvlib::date2ut($date_start, "-");
	$dates /= 60 * 60 * 24;

	$marge->{dates} = int($dates);
	$marge->{start_date} = $date_start;
	$marge->{end_date} = $date_end;
	#dp::dp join(", ", $date_start, $date_end, $dates) . "\n" ;# if($DEBUG);

	#
	#	Check Start date(max) and End date(min)
	#
	my @csv_info = ();
	for(my $i = 0; $i <= $#src_csv_list; $i++){
		$csv_info[$i] = {};
		my $infop = $csv_info[$i];
		my $cdp = $src_csv_list[$i];
		my $date_list = $cdp->{date_list};
		push(@{$marge->{load_order}}, @{$cdp->{load_order}});

		my $dt_start = csvlib::search_listn($date_start, @$date_list);
		if($dt_start < 0){
			dp::WARNING "Date $date_start is not in the data\n";
			$dt_start = 0;
		}
		$infop->{date_start} = $dt_start;

		my $dt_end = csvlib::search_listn($date_end, @$date_list);
		if($dt_end < 0){
			dp::WARNING "Date $date_end is not in the data\n";
			$dt_end = 0;
		}
		$infop->{date_end} = $dt_end;
	
		#dp::dp ">>>>>>>>>> date:[$i] " . join(", ", $dt_start, $dt_end) . "\n";
	}

	#
	#	Marge
	#
	my $m_csv_data = $marge->{csv_data};
	my $m_date_list = $marge->{date_list};
	my $m_key_items = $marge->{key_items};


	my $infop = $csv_info[0];
	$marge->{dates} = $dates;
	$marge->{src_csv} = {};
	$marge->{data_start} = 1;
	my $item_name = "key";
	@{$marge->{item_name_list}} = ($item_name);
	$marge->{item_name_hash}->{$item_name} = 0;
	my $src_csv = $marge->{src_csv};
	#dp::dp ">>> Dates: $dates,  $m_csv_data\n";

	#dp::dp "start:$start, end:$end dates:$dates\n";
	#dp::dp "## src:" . join(",", @{$date_list} ) . "\n";
	#dp::dp "## dst:" . join(",", @{$m_date_list} ) . "\n";

	for(my $csvn = 0; $csvn <= $#src_csv_list; $csvn++){
		my $cdp = $src_csv_list[$csvn];
		my $csv_data = $cdp->{csv_data};

		my $infop = $csv_info[$csvn];
		my $start = $infop->{date_start} // "UNDEF";
		my $end   = $infop->{date_end} // "UNDEF";
		dp::dp "marge [$csvn] date $start to $end\n" if($DEBUG);
		if($csvn == 0){
			my $date_list = $cdp->{date_list};
			@{$m_date_list} = @{$date_list}[$start..$end];
		}

		foreach my $k (keys %$csv_data){
			$src_csv->{$k} = $csvn;
			$m_key_items->{$k} = [$k];

			my $dp = $csv_data->{$k};
			$m_csv_data->{$k} = [];
			my $mdp = $m_csv_data->{$k};
			if(! defined $dp->[1]){
				dp::WARNING "no data in [$k]\n" if(0);
			}
			for(my $i = 0; $i <= $dates; $i++){
				$mdp->[$i] = $dp->[$start + $i] // 0;		# may be something wrong
			}
			#@{$m_csv_data->{$k}} = @{$csv_data->{$k}}[$start..$end];
			#dp::dp ">> src" . join(",", $k, @{$csv_data->{$k}} ) . "\n";
			#dp::dp ">> dst" . join(",", $k, @{$m_csv_data->{$k}} ) . "\n";
		}
	} 
	&dump_cdp($marge, {ok => 1, lines => 5}) if($DEBUG);
	return $marge;
}

1;
