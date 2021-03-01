#########################################
#
#					day1, d2, d3, d4
#	nagative_count, 1,2,3,4,5,
#	positive_count, 11,12,13,14,15
#	-------------------------------
#	tested,12,14,16,20
#
#	calc_items( $cdp, 
#			[ "key", "negative_count,positive_count", "tested"],
#			"tested");
#		"tested", sum(negative,pitive)
#
#########################################
#
#				day1, d2, d3, d4
#	area1,Canada,1,2,3,4,5
#	area2,Canada,11,12,13,14,15
#	area3,Canada,21,22,23,24,25
#	---------------------------
#	"",Canada,33,36,39,42,45
#
#	csvgraph::calc_items($CCSE_DEF, "sum", 
#				{"Province/State" => "", "Country/Region" => "Canada"},		# All Province/State with Canada, ["*","Canada",]
#				{"Province/State" => "null", "Country/Region" => "="}		# total gos ["","Canada"] null = "", = keep
#	);
#
#########################################
#
#	geo_type,region,transportation,alt,sub-reg,country,day1, d2, d3, d4
#	country/reagion,Japan,drivig,,,1,2,3,4,5
#	country/reagion,Japan,walking,,,1,2,3,4,5
#	country/reagion,Japan,transit,,,1,2,3,4,5
#	---------------------------
#	country/reagion,Japan,average,,,3,6,9,12,15
#
#
#	Province/State,Country/Region,Lat,Long,1/22/20
#
#	calc_items( $cdp, {
#			method => "sum",
#			{"Province/State" => "NULL", "Country/Region" => "Canada"},
#			{"Province/State" => "", "Country/Region" => ".-total"},
#														"=": keep item name ("" remove the item name )
#														".postfix": add positfix 
#														"+postfix": add positfix (same as .)
#														"<prefix": add prefix (same as .)
#														"null": replace to null ""
#														"other": replace to new name
#		});
#
#######################################

package calc;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(calc);

use strict;
use warnings;
use utf8;
use Encode 'decode';
use JSON qw/encode_json decode_json/;
use Data::Dumper;
use Clone qw(clone);

use config;
use csvlib;
use util;
use dump;
use csv2graph;

my $VERBOSE = 0;


#
#	Main calc function
#
#			date1, date2, date3,....
#	item1
#	item2
#	item3
#		-----------------------------
#		(avr, total)
#
#
sub	calc_items
{
	my $self = shift;
	my ($method, $target_colp, $result_colp) = @_;

	my $verbose = 0;
	#
	#	Calc 
	#
	my $csv_data = $self->{csv_data};
	my $key_items = $self->{key_items};
	my $key_dlm = $self->{key_dlm};
	my $src_csvp = $self->{src_csv};

	#my $target_colp = $instruction->{target_col};
	#my $result_colp = $instruction->{result_col};

	my $target_keys = [];
	my $target = $self->select_keys($target_colp // "", $target_keys);	# set target records
	if($target < 0){
		return -1;
	}
	dp::dp "target items : $target " . csvlib::join_array(",", $target_colp) . "\n" if($verbose);

	my @key_order = $self->gen_key_order($self->{keys}); 		# keys to gen record key
	my @riw = $self->gen_key_order([keys %$result_colp]); 	# keys order to gen record kee

	dp::dp "key_order: " .join(",", @key_order) . "\n" if($verbose);
	dp::dp "restore_order: " .join(",", @riw) . "\n" if($verbose);
	dp::dp "restore_order: " . csvlib::join_array(",", $result_colp) . "\n" if($verbose);

	my @result_info = ();
	for(my $i = 0; $i < $self->{data_start}; $i++){				# clear to avoid undef
		$result_info[$i] = "";
	}
	my $item_name_hash = $self->{item_name_hash};				# List and Hash need to make here
	foreach my $k (keys %$result_colp){
		my $n = $item_name_hash->{$k} // "";
		if($n eq "") {
			dp::ABORT "[$k] is not item name \n";
		}
		$result_info[$n] = $result_colp->{$k};
	}
	dp::dp "################ result_info: " . join(",", @result_info) . "\n" if($verbose);

	#
	#	Generate record_key and total source data and put to destination(record_key)
	#
	my %record_key_list = ();
	foreach my $key (@$target_keys){
		dp::dp "[$key]\n" if($verbose);
		my $src_kp = $key_items->{$key};			# ["Qbek", "Canada"]
		my $src_dp = $csv_data->{$key};	
		my @dst_keys = @$src_kp;
		my $src_csv = $src_csvp->{$key} // 0;
	
		#
		# key  			 1,2 (region, transportation_type)
		#				         v      v
		#				geo_type,region,transportation_type,alternative_name,sub-region,country,2020-01-13,,,,
		# restore_info	"",      =,     avr,                ,                ,          ,
		#     v
		# dst_key		same,    same,   avr, same, same, same
		#     v
		# record_key	region + transportation_type ("avr")
		#

		#
		#	Generate new key (result key)
		#
		my @key_list = ();
		for (my $i = 0 ; $i <= $#key_order; $i++){				# [0, 1] 
			my $kn = $key_order[$i];
			my $item_name = $src_kp->[$kn];				# ["Qbek", "Canada"]
			#dp::dp "itemnaem: $item_name [$i][$kn]($result_info[$kn])" . csvlib::join_array(",", @{$src_kp}) . "\n";# if($verbose);
			if($result_info[$kn]){
				my $rsi = $result_info[$kn];
				if($rsi eq "null"){
					$item_name = "";
				}
				elsif($rsi =~ /^[\.\+]/){
					$rsi =~ s/.//;
					$item_name .= $rsi;		# ex. -Total
				}
				elsif($rsi =~ /^</){
					$rsi =~ s/.//;
					$item_name = $rsi . $item_name;		# ex. -Total
				}
				elsif($rsi =~ /^=/){
				}
				else {			# if something else set, comvert to it (like, rlavr, ern, ,,,)
					dp::dp "$item_name -> $rsi\n" if($verbose);
					$item_name = $rsi;
				}
				$dst_keys[$kn] = $item_name;
			}
			else {
				$item_name = "";						# ex. ""
			}
			push(@key_list, $item_name);
		}

		my $record_key = select::gen_record_key($key_dlm, \@key_order, \@dst_keys);

		$record_key_list{$record_key}++;
		#dp::dp "record_key [$record_key]" . join(",", @key_order, "##", @key_list) . "\n" ;#if($verbose && $record_key =~ /Japan/ );
		
		if(! defined $csv_data->{$record_key}){				# initial $record_key
			dp::dp "init: $record_key\n" if($VERBOSE);
			
##			$key_items->{$record_key} = [@dst_keys];
##			$csv_data->{$record_key} = [];
			$self->add_record($record_key, [@dst_keys], []);
			my $dst_dp = $csv_data->{$record_key};			# total -> dst
			for(my $i = 0; $i < scalar(@$src_dp); $i++){	# initial csv_data
				$dst_dp->[$i] = 0;					
			}
			$src_csvp->{$record_key} = $src_csv;			# add $record_key record to self
			#dp::dp "$record_key : $src_csv\n";
		}
		my $dst_dp = $csv_data->{$record_key};				# total -> dst
		for(my $i = 0; $i < scalar(@$src_dp); $i++){
			my $v = $src_dp->[$i] // 0;
			$v = 0 if($v eq "");
			$dst_dp->[$i] += $v;
		}
		#dp::dp "####[$record_key] " . "\n" ; #. join(",", @$dst_dp[0..5]) . "\n" ;#if($verbose);
	}
	
	#
	#	Average and others
	#
	if($method eq "avr"){
		foreach my $record_key (keys %record_key_list){
			my $dst_dp = $csv_data->{$record_key};
			#dp::dp "$record_key: $record_key_list{$record_key} ". join(",", @$dst_dp[0..10]) . "\n" if($record_key =~ /Japan/);
			for(my $i = 0; $i < scalar(@$dst_dp); $i++){
				$dst_dp->[$i] /= $record_key_list{$record_key};
			}
		}
	}
	my $record_number = scalar(keys %record_key_list) - 1;
	return $record_number;
}

##########################
#
#	Calc Rolling Average
#
sub	rolling_average
{
	my $self = shift;
	my($csvp) = @_;

	my $avr_date = $self->{avr_date};
	foreach my $key (keys %$csvp){
		my $dp = $csvp->{$key};
		for(my $i = scalar(@$dp) - 1; $i >= $avr_date; $i--){
			my $tl = 0;
			for(my $j = $i - $avr_date + 1; $j <= $i; $j++){
				my $v = $dp->[$j] // 0;
				$v = 0 if(!$v);
				$tl += $v;
			}
			#dp::dp join(", ", $key, $i, $csv->[$i], $tl / $avr_date) . "\n";
			my $avr = sprintf("%.3f", $tl / $avr_date);
			$dp->[$i] = $avr;
		}
	}
	return $csvp;
}	

#
#	combert csv data to ERN
#
#			item_name_list , item_name_has <- "calc"
#
#
sub	calc_rlavr
{
	my $self = shift;
	my $csvp = shift;

	return $self->calc_method("rlavr", $csvp);
}

sub	calc_ern
{
	my $self = shift;
	my $csvp = shift;

	return $self->calc_method("ern", $csvp);
}

sub	calc_method
{
	my $self = shift;
	my($method, @params) = @_;


	if(! defined $self->{item_name_hash}->{calc}){		# gen key item "calc"
		dp::dp "------ calc \n";
		$self->add_key_items(["calc"], "RAW");		# set calc = RAW for exit rows
	}
	my $calc_item = $self->{item_name_hash}->{calc};

	my $work_csvp = clone($self->{csv_data});			# clone self
	#&dump_csv_data($work_csvp, {ok => 1, lines => 5, message => "comver2rlavr:dup"}) if(1);
	if($method eq "rlavr"){
		$self->rolling_average($work_csvp, @params);	# comber csv_data to rlavr
	}
	elsif($method eq "ern"){
		$self->ern($work_csvp, @params);				# comber csv_data to ern
	}
	else {
		dp::ABORT "undefined method [$method]\n";
	}

	my $key_items = $self->{key_items};
	my $key_dlm = $self->{key_dlm} // $config::DEFAULT_KEY_DLM;
	foreach my $kn (keys %$work_csvp){
		my $ckn = join($key_dlm, $kn, $method);
		my $items = [@{$key_items->{$kn}}];
		$items->[$calc_item] = $method;
		$self->add_record($ckn, $items, $work_csvp->{$kn});
	}
	dp::dp "calc_method[$method,csv_data]:" . dump::print_hash($self->{csv_data}) . "\n";

	return $self;
}

#
#	combert csv data to ERN
#
##sub	ern
##{
##	my $self = shift;
##	my($csvp, $p) = @_;
##
##	my $gp  = {
##		lp => $p->{lp} // $self->{lp} // $config::RT_LP,
##		ip => $p->{ip} // $self->{ip} // $config::RT_IP,
##	};
##	my $gdp = {};
##	#my $ern_csvp = {};
##
##	$self->ern($csvp, $gdp, $gp);
##
##	#dump::dump_csv_data($ern_csvp, {ok => 1, lines => 5, message => "comver2ern:ern"}) if(1);
##
##	return $self;
##}

#
#	ERN
#
sub	ern
{
	my $self = shift;
	my($csvp, $p) = @_;

	my $lp = $p->{lp} // $self->{lp} // $config::RT_LP;
	my $ip = $p->{ip} // $self->{lp} // $config::RT_IP;	# 5 感染期間
	my $avr_date = $self->{avr_date};

	dp::dp "CALC ERN: $lp, $ip\n";
	my %rl_avr = ();
	$self->rolling_average($csvp);

	my $date_number = $self->{dates};
	my $rate_term = $date_number - $ip - $lp;
	my $date_term = $rate_term - 1;
	my @keylist = (keys %$csvp);
	foreach my $key (@keylist){
		my $dp = $csvp->{$key};
		my @ern = ();
		my $dt = 0;
		for($dt = 0; $dt < $rate_term; $dt++){
			my $ppre = $ip * $dp->[$dt+$lp+$ip];
			my $pat = 0;
			for(my $d = $dt + 1; $d <= ($dt + $ip); $d++){
				$pat += $dp->[$d];
			}
			# print "$country $dt: $ppre / $pat\n";
			if($pat > 1){	# 0 -> 1
				$ern[$dt] =  int(1000 * $ppre / $pat) / 1000;
			}
			else {
				$ern[$dt] =  0;
			}
			if($ern[$dt] > 100){
				dp::WARNING "ern bigger than 100 : ern:$ern[$dt] = ppre($ppre) / pat($pat)\n" if($VERBOSE);
			}
			# print "$country $dt: $ppre / $pat\n";
		}
		$self->{NaN_start} = $dt;
		for(; $dt <= $date_number; $dt++){
			$ern[$dt] = "NaN";
		}
		@$dp = @ern;			# overwrite csv data by ern
	}
	return $self;
}	

1;
