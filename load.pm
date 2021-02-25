#
#
#
package load;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(load);

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

my $FIRST_DATE = "";
my $LAST_DATE = "";
#
#	Lpad CSV File
#
sub	load_csv
{
	my ($cdp, $download) = @_;

	if(($download // "")){
		my $download = $cdp->{download};
		$download->($cdp);
	}

	dp::dp "LOAD CSV  [$cdp->{src_info}][$cdp->{id}]\n";
	my $rc = 0;
	my $direct = $cdp->{direct} // "";
	if($direct =~ /json/i){
		$rc = &load_json($cdp);
	}
	elsif($direct =~ /transact/i){
		$rc = &load_transaction($cdp);
	}
	elsif($direct =~ /vertical/i){
		$rc = &load_csv_vertical($cdp);
	}
	else {
		$rc = &load_csv_holizontal($cdp);
	}

	if(($cdp->{cumrative} // "")){
		&cumrative2daily($cdp);
	}

	#dp::dp "----- $cdp->{src_csv}\n";
	if(! defined $cdp->{src_csv}){
		$cdp->{src_csv} = {};
	}
	my $src_csv = $cdp->{src_csv}; 
	my $csvp = $cdp->{csv_data};
	foreach my $key (keys %{$cdp->{csv_data}}){
		#dp::dp "$key => $csvp->{$key}  " . ($src_csv->{$key} // "undef") . "\n";
		$src_csv->{$key} = 0;
	}
	#dp::dp "-----\n";
	#@{$cdp->{item_name_list}} = @w[0..($data_start-1)];	# set item_name 


	#
	#	set alias
	#
	csv2graph::set_alias($cdp, $cdp->{alias});

	#
	#	DEBUG: Dump data 
	#
	my $dates = $cdp->{dates};
	my $date_list = $cdp->{date_list};
	dp::dp "loaded($cdp->{id}) $dates records $date_list->[0] - $date_list->[$dates] ($rc)\n";
	dump::dump_cdp($cdp, {ok => 1, lines => 5}) if($rc || $VERBOSE > 1);
	
	return 0;
}


#
#	load holizontal csv file
#
#			01/01, 01/02, 01/03 ...
#	key1
#	key1
#
sub	load_csv_holizontal
{
	my ($cdp) = @_;

	my $csv_file = $cdp->{csv_file};
	my $data_start = $cdp->{data_start};
	my $src_dlm = $cdp->{src_dlm};
	my $date_list = $cdp->{date_list};
	my $csv_data = $cdp->{csv_data};	# Data of record ->{$key}->[]
	my $key_items = $cdp->{key_items};	# keys of record ->{$key}->[]
	my @keys = @{$cdp->{keys}};			# Item No for gen HASH Key
	my $timefmt = $cdp->{timefmt};

	#
	#	Load CSV DATA
	#
	dp::dp "$csv_file\n";
	system("nkf -w80 $csv_file >$csv_file.utf8");			# -w8 (with BOM) contain code ,,,so lead some trouble
	open(FD, "$csv_file.utf8") || die "Cannot open $csv_file.utf8";
	binmode(FD, ":utf8");
	my $line = <FD>;
	$line =~ s/[\r\n]+$//;
	#$line =~ s/^.//;				# 2021.02.14 ... amt 
	#$line = decode('utf-8', $line);

	#dp::dp "[" . ord($line) . ":" . substr($line, 0, 20) . "]\n";
	my @item_name = split(/$src_dlm/, $line);

	#dp::dp "[" . join(",", @w[0..5]) . "]\n";

##	my $item_name_list = $cdp->{item_name_list};
##	my $item_name_hash = $cdp->{item_name_hash};						# List and Hash need to make here
##	@$item_name_list = @w[0..($data_start - 1)];	# set item_name 
##	for(my $i = 0; $i < scalar(@$item_name_list); $i++){				# use for loading and gen keys
##		my $kn = $item_name_list->[$i];
##		$item_name_hash->{$kn} = $i;
##	}
	csv2graph::cdp_add_key_items($cdp,[@item_name[0..($data_start - 1)]]);

	@$date_list = @item_name[$data_start..$#item_name];
	for(my $i = 0; $i < scalar(@$date_list); $i++){
		$date_list->[$i] = util::timefmt($timefmt, $date_list->[$i]);
	}
		
	$cdp->{dates} = scalar(@$date_list) - 1;
	$FIRST_DATE = $date_list->[0];
	$LAST_DATE = $date_list->[$#item_name - $data_start];

	#dp::dp join(",", "# ", @$date_list) . "\n";
	#dp::dp "keys : ", join(",", @keys). "\n";
	my @key_order = select::gen_key_order($cdp, $cdp->{keys});		# keys to gen record key
	my $load_order = $cdp->{load_order};
	my $key_dlm = $cdp->{key_dlm}; 
	my $ln = 0;
	while(<FD>){
		s/[\r\n]+$//;
		#my $line = decode('utf-8', $_);
		my $line = $_;
		my @items = split(/$src_dlm/, $line);
		my $k = select::gen_record_key($key_dlm, \@key_order, \@items);

##		$csv_data->{$k}= [@items[$data_start..$#items]];	# set csv data
##		$key_items->{$k} = [@items[0..($data_start - 1)]];	# set csv data
##		push(@$load_order, $k);

		csv2graph::cdp_add_record($cdp, $k, [@items[0..($data_start-1)]], [@items[$data_start..$#items]]);		# add record without data
		
		$ln++;
		#last if($ln > 50);
	}
	close(FD);
	#dp::dp "CSV_HOLIZONTASL: " . join(",", @{$cdp->{item_name_list}}) . "\n";
	return 0;
}


#
#	Load vetical csv file
#
#			key1,key2,key3
#	01/01
#	01/02
#	01/03
#
#	"key" 01/01, 01/02, 01/03
#	key1, 1,2,3
#	key2, 11,12,13
#	key3, 21,22,23
#
sub	load_csv_vertical
{
	my ($cdp) = @_;

	my $remove_head = 1;
	my $csv_file = $cdp->{csv_file};
	my $data_start = $cdp->{data_start};
	my $src_dlm = $cdp->{src_dlm};
	my $date_list = $cdp->{date_list};
	my $csv_data = $cdp->{csv_data};
	my $key_items = $cdp->{key_items};
	my @keys = @{$cdp->{keys}};
	my $timefmt = $cdp->{timefmt};
	my $item_name_line = $cdp->{item_name_line} // 0;
	my $data_start_line = $cdp->{data_start_line} // 1;
	my $load_col = $cdp->{load_col} // "";
	my $load_order = $cdp->{load_order};

	#
	#	set main key (item name) 
	#	vertical csv had only main key (1 key)
	#
	my $key_name = $cdp->{key_name} // "";			# set key name as "key" or $cdp->{key_name}
	$key_name = $config::MAIN_KEY if(! $key_name);
	csv2graph::cdp_add_key_items($cdp,[$key_name]);
	#@{$cdp->{item_name_list}} = ($key_name);		# set item_name 
	#$cdp->{item_name_hash}->{$key_name} = 0;

	#
	#	Load CSV DATA
	#
	dp::dp "LOAD:$csv_file\n";
	system("nkf -w80 $csv_file >$csv_file.utf8");
	open(FD, "$csv_file.utf8" ) || die "Cannot open $csv_file.utf8";
	binmode(FD, ":utf8");
	#binmode(FD, ":encording(cp932)");

	#
	#	load item names
	#
	my $ln = 0;
	my $line = "";
	for(; $ln <= $item_name_line; $ln++){
		$line = <FD>;
	}
	$line =~ s/[\r\n]+$//;
	#$line = decode('utf-8', $line);

	#dp::dp "$line\n";

	my @item_names = split(/$src_dlm/, $line);
	if($#item_names <= 1){
		dp::WARNING "may be wrong delimitter [$src_dlm]\n\n";
	}
	shift(@item_names);
	my @load_flag = ();
	for(my $i = 0; $i < $#item_names; $i++){
		$load_flag[$i] = "";
	}
	foreach my $i (@$load_col){
		$load_flag[$i] = 1;
	}

	for(my $cl = 0; $cl <= $#item_names; $cl++){
		next if(! $load_flag[$cl]);

		my $k = $item_names[$cl];
		#$k =~ s/^[0-9]+:// if($remove_head);			# 
		if(defined $key_items->{$k}){					# comvert same item name to unique
			my $kk = "";
			for(my $i = 1; $i < 10; $i++){
				$kk = sprintf("$k%02d", $i);
				last if(!defined $key_items->{$kk});
			}
			if(! $kk){
				dp::WARNING "something wrong,,, [$k] " . join(",", @item_names) . "\n";
				$kk = $k;
			}
			$k = $kk;
			$item_names[$cl] = $kk;
		}
		#dp::dp "$cl: $k\n";
		csv2graph::cdp_add_record($cdp, $k, [$item_names[$cl]], []);		# add record without data
	}

	#
	#	Skip non data row
	#
	for($ln++; $ln < $data_start_line; $ln++){		# skip lines until data_start_line
		$line = <FD>;
	}

	#
	#	Load dated data
	#
	$ln = 0;
	while(<FD>){
		s/[\r\n]+$//;
		my $line = decode('utf-8', $_);
		my ($date, @items) = split(/$src_dlm/, $line);
	
		#dp::dp "$date, [$src_dlm]" . join(",", @items) ."\n";
		$date_list->[$ln] = util::timefmt($timefmt, $date);
		#dp::dp "date:$ln $date " . $date_list->[$ln] . " ($timefmt) $cdp->{title}\n";
		#my @w = ($date);	
		for(my $i = 0; $i <= $#items; $i++){
			next if(! $load_flag[$i]);

			my $k = $item_names[$i];
			$csv_data->{$k}->[$ln]= $items[$i];
			#push(@w, "$ln:{". $k . "}:$items[$i]");
		}
		#dp::dp join(",", @w) . "\n";
		$ln++;
	}
	close(FD);

#	foreach my $k (keys %$csv_data){
#		dp::dp "$k: \n" . join(",", @{$csv_data->{$k}}). "\n";
#	}
	$cdp->{dates} = $ln - 1;
	$FIRST_DATE = $date_list->[0];
	$LAST_DATE = $date_list->[$ln-1];
#	dump::dump_cdp($cdp, {ok => 1, lines => 5});
#	exit;
	return 0;
}

#
#	Load Json format
#
#		Tokyoのように、１次元データ向けに作ってます。２次元データは未実装
#		for examanple, apll prefectures,,,
#
sub	load_json
{
	my ($cdp) = @_;

	my $remove_head = 1;
	my $src_file = $cdp->{src_file};
	my @items = @{$cdp->{json_items}};
	my $date_key = shift(@items);

	$cdp->{data_start} = $cdp->{data_start} // 1 ;
	my $date_list = $cdp->{date_list};
	my $csv_data = $cdp->{csv_data};
	my $key_items = $cdp->{key_items};
	my @keys = @{$cdp->{keys}};
	my $timefmt = $cdp->{timefmt};
	my $load_order = $cdp->{load_order};

	my $rec = 0;
	my $date_name = "";

	dp::dp "$src_file\n";
	#
	#	Read from JSON file
	#
	my $JSON = "";
	open(FD, $src_file) || die "cannot open $src_file";
	while(<FD>){
		$JSON .= $_;
	}
	close(FD);

	my $positive = decode_json($JSON);
	#print Dumper $positive;
	my @data0 = (@{$positive->{data}});
	#dp::dp "### $date_key\n";

##	if(!defined $csv_data){
##		dp::dp "somthing wrong at json, csv_data\n";
##		$csv_data = {};
##		$cdp->{csv_data} = $csv_data;
##	}
##	foreach my $k (@items){
##		$key_items->{$k} = [$k];
##		$csv_data->{$k} = [];
##		#dp::dp "csv_data($k) :". $csv_data->{$k} . "\n";
##	}	

	csv2graph::cdp_add_key_items($cdp,[@items]);
	foreach my $kn (@items){
		csv2graph::cdp_add_record($cdp, $kn, [$kn], []);		# add record without data
	}

	my $key_name = $cdp->{key_name} // "";
	$key_name = $config::MAIN_KEY if(! $key_name);
	@{$cdp->{item_name_list}} = ($key_name);	# set item_name 
	$cdp->{item_name_hash}->{$key_name} = 0;
	dp::dp "item_name_list: (" . join(",", @{$cdp->{item_name_list}}). ") [$key_name]\n";

##	for(my $itn = 0; $itn <= $#items; $itn++){
##		$load_order->[$itn] = $items[$itn];
##	}

	for(my $rn = 0; $rn <= $#data0; $rn++){
		my $datap = $data0[$rn];
		my $date = $datap->{$date_key};
		$date_list->[$rn] = $date;
		for(my $itn = 0; $itn <= $#items; $itn++){
			my $k = $items[$itn];
			my $v = $datap->{$k} // 0;
			$csv_data->{$k}->[$rn] = $v;
			#dp::dp "$k:$itn: $v ($csv_data->{$k})\n" if($rn < 3);
		}
		#dp::dp  join(",", @$dp) . "\n" if($i < 3);
	}
	#print Dumper $date_list;
	#print Dumper $csv_data;
	#foreach my $k (@items){
	#	print Dumper $csv_data->{$k};
	#}
	$cdp->{dates} = $#data0;
	$FIRST_DATE = $date_list->[0];
	$LAST_DATE = $date_list->[$#data0];
	return 0;
}

#
#	Load Transaction format (One record, One line)
#
sub	load_transaction
{
	my ($cdp) = @_;

	my $csv_file = $cdp->{csv_file};
	my $data_start = $cdp->{data_start};
	my $date_list = $cdp->{date_list};
	my $csv_data = $cdp->{csv_data};
	my $key_items = $cdp->{key_items};
	my @keys = @{$cdp->{keys}};
	my $timefmt = $cdp->{timefmt};
	my $key_dlm = $cdp->{key_dlm} // "#";
	my $load_order = $cdp->{load_order};

	dp::dp "$csv_file\n";
	open(FD, $csv_file) || die "cannot open $csv_file";
	binmode(FD, ":utf8");
	my $line = <FD>;
	$line =~ s/[\r\n]+$//;
	my @items = util::csv($line);

	my $key_name = $cdp->{key_name} // "";
	$key_name = $config::MAIN_KEY if(! $key_name);
	@{$cdp->{item_name_list}} = (@items[0..($data_start-1)], $key_name);	# set item_name 
	my $kn = 0;
	foreach my $k (@items[0..($data_start-1)], $key_name){
		#dp::dp "$k: $kn\n";
		$cdp->{item_name_hash}->{$k} = $kn++;
	}

	#dp::dp join(",", "# " , @key_list) . "\n";
	dp::dp "load_transaction: " . join(", ", @items) . "\n";

	my $dt_end = -1;
	while(<FD>){
		my (@vals)  = util::csv($_);

		$vals[0] += 2000 if($vals[0] < 100);
		my $ymd = sprintf("%04d-%02d-%02d", $vals[0], $vals[1], $vals[2]);		# 2020/01/03 Y/M/D

		if($dt_end < 0 || ($date_list->[$dt_end] // "") ne $ymd){
			$date_list->[++$dt_end] = $ymd;
		}

		my @gen_key = ();			# Generate key
		foreach my $n (@keys){
			if($n =~ /\D/){
				my $nn = $cdp->{item_name_hash}->{$n} // -1;
				if($nn < 0){
					dp::WARNING "key: no defined key[$n] " . join(",", @keys) . "\n";
				}
				$n = $nn;
			}
			my $itm = $vals[$n];
			push(@gen_key, $itm);
		}
		#dp::dp "$ymd: " . join(",", @gen_key) . "\n";

		#
		#		year,month,prefJ,PrefE,testedPositive,PeopleTested,Hospitalzed....
		#		2020,2,東京,Tokyo,3,130,,,,,
		#
		for(my $i = $data_start; $i <= $#items; $i++){
			my $item_name = $items[$i];
			my $k = join($key_dlm, @gen_key, $item_name);				# set key_name
			if(! defined $csv_data->{$k}){
				#dp::dp "load_transaction: assinge csv_data [$k]\n";

				$csv_data->{$k} = [];
				$key_items->{$k} = [];
				@{$key_items->{$k}} = (@vals[0..($data_start - 1)], $item_name);

				push(@$load_order, $k);
			}
			my $v = $vals[$i] // 0;
			$v = 0 if(!$v || $v eq "-");
			$csv_data->{$k}->[$dt_end] = $v;
			#dp::dp "load_transaction: $ymd " . join(",", $k, $dt_end, $v, "#", @{$csv_data->{$k}}) . "\n";
		}
	}
	close(FD);
	dp::dp "##### data_end at transaction: $dt_end: $date_list->[$dt_end]\n";

	#
	#	Set unassgined data with 0
	#
	foreach my $k (keys %$csv_data){
		my $dp = $csv_data->{$k};
		for(my $i = 0; $i <= $dt_end; $i++){
			$dp->[$i] = $dp->[$i] // 0;
		}
	}

	$cdp->{dates} = $dt_end;
	$FIRST_DATE = $date_list->[0];
	$LAST_DATE = $date_list->[$dt_end];

	return 0;
}

#
#	Cumrative data to daily data
#
sub	cumrative2daily
{
	my($cdp) = @_;

	my $csv_data = $cdp->{csv_data};

	foreach my $k  (keys %$csv_data){
		my $dp = $csv_data->{$k};
		#dp::dp "##" . join(",", $k, $csv_data, $dp) . "\n";
		my $dates = scalar(@$dp) - 1;
		for(my $i = $dates; $i > 0; $i--){
			$dp->[$i] = $dp->[$i] - $dp->[$i-1];
		}
	}
}

1;
