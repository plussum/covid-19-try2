#
#
#
package select;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(select);

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

my $VERBOSE = 0;
my $DEBUG = 0;

#
#	Generate Recored key 
#
sub	gen_record_key 
{
	my($dlm, $key_order, $items) = @_;

	my @gen_key = ();
	my $k = "";
	foreach my $n (@$key_order){		# @keys
		my $itm = $items->[$n] // "";
		push(@gen_key, $itm);
		$k .= $itm . $dlm if($itm);
	}
	$k =~ s/$dlm$//;
	return $k;
}

#
#	geo_type,region,transportation_type,alternative_name,sub-region,country,2020-01-13,,,,
#	
#		keys => ["region", "transportation"], => [1,2]
#
sub	gen_key_order
{
	my ($cdp, $key_order) = @_;
	my @keys = ();

	my $item_name_hash = $cdp->{item_name_hash};
	foreach my $k (@$key_order){
		my $itn = $k;
		if($k =~ /\D/){
			$itn = $item_name_hash->{$k} // "UNDEF";
			dp::dp ">> $k: [$itn]\n" if($VERBOSE);
			if($itn eq "UNDEF"){
				dp::ABORT "no item_name_hash defined [$k] (" . join(",", keys %$item_name_hash) . ")\n";
			}
		}
		else {
			dp::dp "[$itn] as numeric\n" if($VERBOSE > 1);
		}
		push(@keys, $itn);
	}
	dp::dp join(",", @keys) . "\n" if($VERBOSE);
	return (@keys);
}

#
#	form target_col format1 and format2 to format1(output is format1)
#		No need to selparate items, just keep it ("Japan,Italy" => "Japan,Italy")
#
#			geo_type, region, transpotation_type, allternative,sub-reagion,country
#	format1: ["country/region","Japan","walking,driving"]
#	format2: {geo_type => "country/region", region => "Japan", transportation_type => "walking,driving"}
#
#			Province/State,Country/Region,Lat,Long,1/22/20
#	format1: ["NULL","Japan"]			# as country of Japan
#	format1: ["","Japan,Italy"]			# any Province/States in Japan and Itanly
#	fromat2: {"Province/State" => "NULL", "Country/Region" => "Japan"},
#	fromat2: {"Province/State" => "", "Country/Region" => "Japan,Italy"}
#
#
sub	gen_target_col
{
	my ($cdp, $target_colp) = @_;
	my @target_col = ();

	#dp::dp "gen_target_col: " . Dumper($target_colp) . "\n";
	#csvlib::disp_caller(1..4);
	my $item_name_list = $cdp->{item_name_list};
	my $item_name_hash = $cdp->{item_name_hash};						# List and Hash need to make here

	my $ref = ref($target_colp);
	if($ref eq "ARRAY"){
		@target_col = @$target_colp;
		my $target_size = $#target_col;
		if($target_size > scalar(@$item_name_list)){
			dp::WARNING "select key out of range[$target_size] :keys in select(" . join(",", @target_col) . ") "
					. "keys in definiton [" . scalar(@$item_name_list) ."] (". join(",", @$item_name_list) . ")\n";
			#&dump_cdp($cdp, {ok => 1, lines => 5}); 
		}
		elsif($target_size < 0){
			dp::WARNING "no select keys :keys(" . join(",", @$item_name_list) . ")\n";
		}
	}
	elsif($ref eq "HASH"){
		my $item_name_hash = $cdp->{item_name_hash};
		dp::dp join(",", %$target_colp) . "\n" if($VERBOSE > 1);
		foreach my $k (keys %$target_colp){
			my $itn = $item_name_hash->{$k} // "UNDEF";
			#dp::dp ">> $k: [$itn]\n";
			if($itn eq "UNDEF"){
				dp::WARNING "select key not found[$k] :keys(" . join(",", @$item_name_list) . ")\n";
			}
			else {
				$target_col[$itn] = $target_colp->{$k};
			}
		}
		for(my $i = 0; $i <= $#target_col; $i++){
			$target_col[$i] = "" if(! defined $target_col[$i]);
		}
	}
	dp::dp join(",", @target_col) . "\n" if($VERBOSE);
	return (@target_col);
}

#
#	Select CSV DATA
#
sub	select_keys
{
	my($cdp, $target_colp, $target_keys, $verbose) = @_;

	$verbose = $verbose // "";
	my @target_col_array = ();
	my @non_target_col_array = ();
	my $condition = 0;
	my $clm = 0;

	my @target_list =  ();
	#dp::dp "[$target_colp]\n";
	if(! ($target_colp//"") || util::array_size($target_colp) <= 0){
		@$target_keys = keys %{$cdp->{csv_data}};		# put all keys to target keys
		dp::dp "target_keys: " . scalar(@$target_keys) . "\n";
	}
	else {
		@target_list = &gen_target_col($cdp, $target_colp);
		dp::dp csvlib::join_array(",", $target_colp) . "\n" if($verbose);
		dp::dp csvlib::join_array(",", @target_list) . "\n" if($verbose);
		foreach my $sk (@target_list){
			#dp::dp "Target col $sk\n";
			if($sk){
				my ($tg, $ex) = split(/ *\! */, $sk);
				my @w = split(/\s*,\s*/, $tg);
				push(@target_col_array, [@w]);
				$condition++;

				@w = ();
				if($ex){
					@w = split(/\s*,\s*/, $ex);
				}
				push(@non_target_col_array, [@w]);
				#dp::dp "NoneTarget:[$clm] " . join(",", @w) . "\n";
			}
			else {
				push(@target_col_array, []);
				push(@non_target_col_array, []);
			}
			$clm++;
		}

		dp::dp "Condition: $condition " . csvlib::join_array(", ", @target_col_array) . "\n" if($verbose);
		dp::dp "Nontarget: " . csvlib::join_array(",", @non_target_col_array) . "\n" if($verbose);
		my $key_items = $cdp->{key_items};
		#dp::dp "Key_itmes: " . csvlib::join_array(",", $key_items) . "\n";
		foreach my $key (keys %$key_items){
			my $key_in_data = $key_items->{$key};
			my $res = &check_keys($key_in_data, \@target_col_array, \@non_target_col_array, $key, $verbose);
			#dp::dp "[$key:$condition:$res]\n" ;#if($verbose  > 1);
			dp::dp "### " . join(", ", (($res >= $condition) ? "O" : "-"), $key, $res, $condition, @$key_in_data) . "\n" if($verbose > 1) ;
			next if ($res < 0);

			if($res >= $condition){
				push(@$target_keys, $key);
				if($verbose){
					dp::dp "### " . join(", ", (($res >= $condition) ? "O" : "-"), $key, $res, $condition, @$key_in_data) . "\n";
				}
			}
		}
	}

	if($verbose){
		my $size = scalar(@$target_keys) - 1;
		dp::dp "SIZE: $size\n";
		$size = 5 if($size > 5);
		if($size >= 0){
			dp::dp "## TARGET_COLP $size " . csvlib::join_array(",", $target_colp) . "\n";
			dp::dp "## TARGET_LIST " . join(",", @target_list) . "\n";
			dp::dp "## TARGET_KEYS " . join(", ", @$target_keys[0..$size]) . "\n";
		}
		else {
			dp::dp "## TARGET_KEYS no data" . csvlib::join_array(",", $target_colp) . join(",", @target_list) . "\n";
		}
	}
	if(scalar(@$target_keys) <= 0){
		my $dkey = "item_name_list"; # "load_order";
		dp::WARNING (
			#"No data Target[".ref($target_colp)."]:(".csvlib::join_array(",", $target_colp).") Result:(".join(",", @$target_keys).")\n",
			"No data Target[".$target_colp."]:(".csvlib::join_array(",", $target_colp).") Result:(".join(",", @$target_keys).")\n",
			"Poosibly miss use of [ ], {} at target_colp " . ref($target_colp) . "\n",
			"$dkey:(" . join(",", @{$cdp->{$dkey}}) . ")\n",
		);
		csvlib::disp_caller(1..3);
	}
	return(scalar(@$target_keys) - 1);
}



#
#	Check keys for select
#
#	key_in_data	item names of record: country/region,Japan,,,,
#				execlusion(nskey)
#				""			*				* means somthing
#	skey	""	no-check	check !nkey
#			*	check key	check !nkey/skey
#
#	(non_)target_col_array => [
#				["japan","United States","Italy"], 
#				["avr"]		set at select_keys
#			];
#
sub	check_keys
{
	my($key_in_data, $target_col_array, $non_target_col_array, $key, $verbose) = @_;
	$verbose = $verbose // "";

	if(!defined $key_in_data){
		dp::WARNING "###!!!! key in data not defined [$key]\n";
	}
	#dp::dp "key_in_data: $key_in_data " . scalar(@$key_in_data) . " [$key]\n";
	my $kid = join(",", @$key_in_data);
	my $condition = 0;
	my $cols = scalar(@$target_col_array) - 1;

	dp::dp csvlib::join_array(",", @$target_col_array) . "\n" if($verbose == 1);
	for(my $kn = 0; $kn <= $cols; $kn++){
		my $skey = $target_col_array->[$kn];
		my $nskey = $non_target_col_array->[$kn];
		#dp::dp "$skey:$nskey\n";
		if(!($skey->[0] // "") && !($nskey->[0] // "")){		# skey="", nskey=""
			#dp::dp "NIL:[$kn] [" . ($skey->[0]//"NONE") . "]" . scalar(@$skey) . "\n";
			next;
		}
		
		#dp::dp ">>> " . join(",", $key_in_data->[$kn] . ":", @{$non_target_col_array->[$kn]}) . "\n" if($kid =~ /country.*Japan/);
		if(scalar(@{$nskey}) > 0){			# Check execlusion
			if(csvlib::search_listn($key_in_data->[$kn], @$nskey) >= 0){
				#dp::dp "EXECLUSION: $kid \n";
				$condition = -1;							# hit to execlusion
				last;
			}
			elsif(scalar(@$skey) <= 0){		# Only search key set (no specific target)
				$condition++;				
				next;
			}
		}

		for(my $i = 0; $i < scalar(@$key_in_data); $i++){
			if(!defined $key_in_data->[$i]){
				dp::ABORT "$kn\n";
			}
		}
		dp::dp "key_in_data $kn [" . csvlib::join_arrayn(",", @$key_in_data) . "]\n" if($verbose);
		dp::dp "key_in_data [" . $key_in_data->[$kn] . "]["  . csvlib::join_arrayn(",", @$skey) . "]\n" if($verbose);
		dp::ABORT "key_in_data $kn [" . csvlib::join_arrayn(",", @$key_in_data) . "]\n" if(!defined $key_in_data->[$kn]);
		dp::ABORT "target_col_array $kn\n" if(!defined $target_col_array->[$kn]);
		dp::dp "data $kn $key_in_data->[$kn] =~ (" . join(",", @{$target_col_array->[$kn]}) . ") ["
				 . join(",", @$key_in_data) . "]\n" if($verbose == 1);
		
		if(csvlib::search_listn($key_in_data->[$kn], @$skey) >= 0){
			$condition++ 									# Hit to target
		}
	}
	#dp::dp "----> $condition: $kid\n" if($kid =~ /Canada/);
	return $condition;
}

#
#	Data range
#
sub	date_range
{
	my($cdp, $gdp, $gp) = @_;

	my $id = $cdp->{id} // ($cdp->{src_info} // "no-id");
	my $date_list = $cdp->{date_list};
	#dp::dp "DATE: " . join(", ", $gp->{start_date}, $gp->{end_date}, "#", @$date_list[0..5]) . "\n";
	my $dt_start = csvlib::search_listn($gp->{start_date}, @$date_list);
	if($dt_start < 0){
		dp::WARNING "[$id]: Date $gp->{start_date} is not in the data ($cdp->{src_info}) " . join(",", @$date_list[0..5]) ."\n";
		csvlib::disp_caller(1..3);
		$dt_start = 1;
	}
	$dt_start = 0 if($dt_start < 0 || $dt_start > $cdp->{dates});
	my $dt_end   = csvlib::search_listn($gp->{end_date},   @$date_list);
	if($dt_end < 0){
		my $dtc = scalar(@$date_list) - 1;
		dp::WARNING "[$id]: Date $gp->{end_date} is not in the data ($cdp->{src_info}) $dtc" . join(",", @$date_list[($dtc-5)..$dtc]) ."\n";
		csvlib::disp_caller(1..3);
		$dt_end = $dt_end + 1;
	}
	$dt_end = $cdp->{dates} if($dt_end < 0 || $dt_end > $cdp->{dates});
	$gp->{dt_start} = $dt_start;
	$gp->{dt_end}   = $dt_end;
}
1;
