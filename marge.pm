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

	#
	#	init marge csv, set marge cdp from src_csvs
	#
	&csv2graph::new($marge);

	foreach my $src_cdp (@src_csv_list){
		dp::dp "$src_cdp: $src_cdp->{id}\n";
		foreach my $key (@$csv2graph::cdp_values){
			$marge->{$key} = $src_cdp->{$key} // "";
			# last if($marge->{$key});
		}
	}
	$marge->{src_csv} = {};

	#
	#	get max(date_start)  min($date_end)
	#
	my $date_start = "0000-00-00";
	foreach my $src_cdp (@src_csv_list){
		my $dt = $src_cdp->{date_list}->[0];
		if(! ($dt // "")){
			dp::WARNING "No date in $src_cdp->{id} [$src_cdp->{id}]\n";
			csvlib::disp_caller(1..3);
		}
		$date_start = $dt if($dt gt $date_start );
		dp::dp "date_start[$dt] $date_start [$src_cdp->{id}\n";
	}
	my $date_end = "9999-99-99";
	foreach my $src_cdp (@src_csv_list){
		my $dates = $src_cdp->{dates};
		my $dt = $src_cdp->{date_list}->[$dates];
		if(defined $src_cdp->{NaN_start}){
			my $dn = $src_cdp->{NaN_start};
			$dt = $src_cdp->{date_list}->[$dn];
		}
		$date_end = $dt if($dt le $date_end );
		dp::dp "date_end[$dt] $date_end [$src_cdp->{id}] $dates\n";
	}
	my $dates = csvlib::date2ut($date_end, "-") - csvlib::date2ut($date_start, "-");
	$dates /= 60 * 60 * 24;

	$marge->{dates} = int($dates);
	$marge->{date_start_subs} = $date_start;
	$marge->{date_end_subs} = $date_end;
	#dp::dp join(", ", $date_start, $date_end, $dates) . "\n" ;# if($DEBUG);

	#
	#	set date to marge cdp
	#
	my @csv_info = ();
	for(my $i = 0; $i <= $#src_csv_list; $i++){
		$csv_info[$i] = {};
		my $infop = $csv_info[$i];
		my $src_cdp = $src_csv_list[$i];
		my $date_list = $src_cdp->{date_list};

		my $dt_start = csvlib::search_listn($date_start, @$date_list);
		if($dt_start < 0){
			dp::WARNING "Date $date_start is not in the data\n";
			$dt_start = 0;
		}
		$infop->{date_start} = $dt_start;

		my $dt_end = csvlib::search_listn($date_end, @$date_list);
		if($dt_end < 0){
			dp::WARNING "Date $date_end is not in the data [$src_cdp->{id}]\n";
			$dt_end = 0;
		}
		$infop->{date_end} = $dt_end;
	
		#dp::dp ">>>>>>>>>> date:[$i] " . join(", ", $dt_start, $dt_end) . "\n";
	}
	#
	#	Copy date list from src_csv_list[0]
	#
	my $infop = $csv_info[0];
	my $start_subs = $infop->{date_start} // "UNDEF";
	my $end_subs   = $infop->{date_end} // "UNDEF";
	my $date_list = $src_csv_list[0]->{date_list};

	my $m_date_list = $marge->{date_list};
	@{$m_date_list} = @{$date_list}[$start_subs..$end_subs];
	dp::dp "marge date $start_subs to $end_subs\n" if($DEBUG);

	#
	#	Marge arrays
	#
	foreach my $src_cdp (@src_csv_list){
		push(@{$marge->{load_order}}, @{$src_cdp->{load_order}});
	}

	#
	#	Marge csv data and key data
	#
	my $m_csv_data = $marge->{csv_data};
	my $m_key_items = $marge->{key_items};

	$marge->{dates} = $dates;
	$marge->{data_start} = 1;

	#
	#	Set key item name (default "key")
	#
	my $item_name = "key";
	@{$marge->{item_name_list}} = ($item_name);
	$marge->{item_name_hash}->{$item_name} = 0;
	my $m_src_csv = $marge->{src_csv};
	#dp::dp ">>> Dates: $dates,  $m_csv_data\n";

	#dp::dp "start:$start, end:$end dates:$dates\n";
	#dp::dp "## src:" . join(",", @{$date_list} ) . "\n";
	#dp::dp "## dst:" . join(",", @{$m_date_list} ) . "\n";

	for(my $csvn = 0; $csvn <= $#src_csv_list; $csvn++){
		my $src_cdp = $src_csv_list[$csvn];
		my $csv_data = $src_cdp->{csv_data};

		#
		#	Copy date list from 
		#
		my $infop = $csv_info[$csvn];
		my $start_subs = $infop->{date_start} // "UNDEF";
		my $end_subs   = $infop->{date_end} // "UNDEF";
		dp::dp "marge [$csvn] date $start_subs to $end_subs\n" if($DEBUG);
		if($csvn == 0){
			my $date_list = $src_cdp->{date_list};
			@{$m_date_list} = @{$date_list}[$start_subs..$end_subs];
		}

		foreach my $k (keys %$csv_data){
			$m_src_csv->{$k} = $csvn;		# set source csv number
			$m_key_items->{$k} = [$k];		# set key of csv_data as key in marge

			my $src_dp = $csv_data->{$k};	# refarence of csv_data
			$m_csv_data->{$k} = [];			# gen array for key
			my $marge_dp = $m_csv_data->{$k};
			if(! defined $src_dp->[1]){
				dp::WARNING "no data in [$k]\n" if(0);
			}
			for(my $i = 0; $i <= $dates; $i++){
				$marge_dp->[$i] = $src_dp->[$start_subs + $i] // 0;		# may be something wrong
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
