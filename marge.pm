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
##sub	marge_csv
##{
##	my $self = shift;
##	my (@src_csv_list) = @_;
##
##	my $marge = {};
##	return $self->marge_csv_a(@src_csv_list);
##}

#
#	Marge csvdef
#
sub	marge_csv
{
	my $self = shift;
	my (@src_csv_list) = @_;

	#@src_csv_list = ($self, @src_csv_list);

	#
	#	init marge csv, set marge cdp from src_csvs
	#
	#my $marge = $self->dup();
	my $marge = csv2graph->new($self);

	#
	#	copy values
	#
	foreach my $src_cdp (@src_csv_list){		# copy values
		#dp::dp "$src_cdp: $src_cdp->{id}\n";
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
		#dp::dp "date_start[$dt] $date_start [$src_cdp->{id}\n";
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
		#dp::dp "date_start[" . $src_cdp->{date_list}->[0], "] date_end[$dt] $date_end [$src_cdp->{id}] $dates\n";
	}
	my $dates = csvlib::date2ut($date_end, "-") - csvlib::date2ut($date_start, "-");
	$dates /= 60 * 60 * 24;

	$marge->{dates} = int($dates);
	$marge->{date_start_subs} = $date_start;
	$marge->{date_end_subs} = $date_end;
    my $dt_start = csvlib::date2ut($date_start, "-");
    for(my $i = 0; $i <= $dates; $i++){
        my $ut = $dt_start + $i * 24 * 60 * 60;
        my $ymd = csvlib::ut2date($ut, "-");
        $marge->{date_list}->[$i] = $ymd;
    }
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

        #dp::dp "date_list:[$date_end] " . csvlib::join_array(",", @$date_list). "\n";
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
	#	Marge arrays, item_name_list/hash
	#
	my $n = 0;
	$marge->{marge_item_pos} = [];
	$marge->{keys} = [];

	#dp::dp "MARGE: " . join(",", $marge->{item_name_list}, $marge->{item_name_hash}) . "\n";
	#$marge->{item_name_list} = [] if(! defined $marge->{item_name_list});
	#$marge->{item_name_hash} = {} if(! defined $marge->{item_name_hash});
	my $m_in_list = $marge->{item_name_list};
	my $m_in_hash = $marge->{item_name_hash};

    #dp::dp "LIST: " . csvlib::join_array(",", @{$marge->{item_name_list}}) . "\n";
    #dp::dp "HASH: " . csvlib::join_array(",", $marge->{item_name_hash}) . "\n";
	for(my $cdn = 0; $cdn <= $#src_csv_list; $cdn++){
		my $src_cdp = $src_csv_list[$cdn];
        #$src_cdp->dump();
        my $id =  $src_cdp->{mid} // $src_cdp->{id}//"no-id";

        my @w = @{$src_cdp->{keys}};
        push(@w, "item") if($#w < 0);
        #dp::dp "######## " . join(", ", $#w,  $src_cdp->{keys}, @w, "#", csvlib::join_array(@w) ) .  "\n";
        foreach my $k (@w){
			#dp::dp "### [$k]\n";
            push(@{$marge->{keys}}, $k . "-$id"); #sprintf("$k-%02d", $cdn+1) ;
        }

		push(@{$marge->{load_order}}, @{$src_cdp->{load_order}});

		my $arp = scalar(@{$marge->{item_name_list}});		# key positon (where to add key)
		push(@{$marge->{marge_item_pos}}, $arp);

		#push(@$m_in_list, @w);		# add item_name_list
		#dp::dp "ITEM_NAME_LIST: " . join(",", scalar(@$m_in_list), @$m_in_list, "list:$m_in_list") . "\n";

		my $src_hash = $src_cdp->{item_name_hash};
        my $src_list = $src_cdp->{item_name_list};
		for(my $i = 0; $i < scalar(@$src_list); $i++){ #  foreach my $k (keys %$src_hash){					# operate item_name_hash for alias, 
            my $k = $src_list->[$i];
            if(! defined $src_hash->{$k}){
                dp::ABORT "undefined hash [$k]\n";
            }
            #dp::dp "m_in_hash $k($cdn) : " . ((defined $m_in_hash->{$k}) ? $m_in_hash->{$k} : "undef") . "  [$arp]\n";
			#if((defined $m_in_hash->{$k})){ # $skn eq $config::MAIN_KEY){  # 2021.08.03
            #    $k .= "-" . $src_cdp->{id}; #sprintf("$k-%02d", $cdn+1) ;
            #    #dp::dp "LIST: $k $i\n";
            #:}
            $k .= "-" . ($src_cdp->{mid} // $src_cdp->{id}); #sprintf("$k-%02d", $cdn+1) ;
            push(@$m_in_list, $k);
        }
		foreach my $k (keys %$src_hash){					# operate item_name_hash for alias, 
			my $skn = $src_hash->{$k};
			#if((defined $m_in_hash->{$k})){ # $skn eq $config::MAIN_KEY){  # 2021.08.03
            #    $k .= "-" . $src_cdp->{id}; #sprintf("$k-%02d", $cdn+1) ;
            #    #dp::dp "HASH: $k: $skn\n";
            #}
            $k .= "-" . ($src_cdp->{mid} // $src_cdp->{id}); #sprintf("$k-%02d", $cdn+1) ;
            $skn += $arp;
            #dp::dp "m_in_hash: $k: [$skn][$arp] \n";
			$m_in_hash->{$k} = $skn; # $src_hash->{$k} + $arp;
		}
		#dp::dp "LIST: " . csvlib::join_array(",", @{$marge->{item_name_list}}) . "\n";
		#dp::dp "HASH: " . csvlib::join_array(",", $marge->{item_name_hash}) . "\n";

	}

	#push(@{$marge->{marge_item_pos}}, scalar(@{$marge->{item_name_list}}) - 1);
	#dp::dp join(",",  @{$marge->{marge_item_pos}}) . "\n";

	#my $item_name = "marge_key";
	#push(@$m_in_list, $item_name);
	#$m_in_hash->{$item_name} = scalar(@$m_in_list) - 1;

	#dp::dp "ITEM_NAME_LIST: " . csvlib::join_arrayn(",", @$m_in_list) . " / " .join(",", $m_in_list, scalar(@$m_in_list)) . "\n";
	#dp::dp "ITEM_NAME_LIST: " . join(",", @{$marge->{item_name_list}}, $marge->{item_name_list}) . "\n";
	#$n = 0;
	#foreach my $k (@$m_in_list){		# SET HASH
	#	$m_in_hash->{$k} = $n++;
	#}

	#
	#	Marge csv data and key data
	#
	my $m_csv_data = $marge->{csv_data};
	my $m_key_items = $marge->{key_items};

	$marge->{dates} = $dates;
	$marge->{data_start} = 1;
	my $m_src_csv = $marge->{src_csv};
	#dp::dp ">>> Dates: $dates,  $m_csv_data\n";

	#dp::dp "start:$start, end:$end dates:$dates\n";
	#dp::dp "## src:" . join(",", @{$date_list} ) . "\n";
	#dp::dp "## dst:" . join(",", @{$m_date_list} ) . "\n";

	#dp::dp "SRC_CSV_LIST: " . $#src_csv_list . "\n";
	for(my $csvn = 0; $csvn <= $#src_csv_list; $csvn++){
		my $src_cdp = $src_csv_list[$csvn];
		my $csv_data = $src_cdp->{csv_data};
		my $src_key_items = $src_cdp->{key_items};

		#dp::dp "SRC_CSV: " . $src_cdp->{id}. "\n";
		#
		#	Copy date list from 
		#
		my $infop = $csv_info[$csvn];
		my $start_subs = $infop->{date_start} // "UNDEF";
		my $end_subs   = $infop->{date_end} // "UNDEF";
		dp::dp "marge [$csvn] date $start_subs to $end_subs\n" if($DEBUG);
		#if($csvn == 0){
		#	my $date_list = $src_cdp->{date_list};
		##	@{$m_date_list} = @{$date_list}[$start_subs..$end_subs];
		#}

		my $marge_item_pos = $marge->{marge_item_pos}->[$csvn];
		my $item_number = scalar(@{$marge->{item_name_list}}) - 1;
		my $src_item_number = scalar(@{$src_cdp->{item_name_list}}) -1;
		#dp::dp "MARGE_INFO:" . join(",", $csvn, $marge_item_pos, $item_number, $src_cdp->{id}, "#", @{$src_cdp->{marge_item_pos}},"#") . "\n";
		#dp::dp "MARGE_INFO:" . csvlib::join_array(",", @{$marge->{item_name_list}}) . "\n";
		foreach my $k (keys %$csv_data){
			$m_src_csv->{$k} = $csvn;						# set source csv number
            $m_key_items->{$k} = [];
			my $m_key = $m_key_items->{$k};
			
			#dp::dp "[$csvn] $k\n";
			for(my $i = 0; $i <= $item_number; $i++){		# Intial key items by ""
				$m_key->[$i] = "NaN";		
			}
			for(my $i = 0; $i <= $src_item_number; $i++){	# copy key items
				$m_key->[$i + $marge_item_pos] = $src_key_items->{$k}->[$i] ;# . "-" . $src_cdp->{id}; 
			}
			#$m_key->[$item_number] = $csvn;		
			#dp::dp "key_items:$csvn:$marge_item_pos:$item_number:$k " . csvlib::join_array(",", @$m_key) . "\n";

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
	#my $m_csv_data = $marge->{csv_data};
	#my $m_key_items = $marge->{key_items};
#	my $marge_item_pos = $m_in_hash->{$item_name};
#	dp::dp "[$marge_item_pos:$item_name]\n";
#	foreach my $k (keys %$m_key_items){
#		$m_key_items->{$k}->[$marge_item_pos] = $item_name;
#	}
	
	#dp::dp "ITEM_NAME_LIST: " . join(",", @{$marge->{item_name_list}}, $marge->{item_name_list}) . "\n";
	#print Dumper $marge->{item_name_list};
	#print Dumper $m_in_list;
	$marge->dump({ok => 1, lines => 5}) if($DEBUG);
	return $marge;
}

1;
