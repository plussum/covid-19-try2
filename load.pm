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

	#@{$cdp->{item_name_list}} = @w[0..($data_start-1)];	# set item_name 

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
	open(FD, $csv_file) || die "Cannot open $csv_file";
	my $line = <FD>;
	$line =~ s/[\r\n]+$//;
	$line = decode('utf-8', $line);

	my @w = split(/$src_dlm/, $line);

	my $item_name_list = $cdp->{item_name_list};
	my $item_name_hash = $cdp->{item_name_hash};						# List and Hash need to make here
	@$item_name_list = @w[0..($data_start - 1)];	# set item_name 
	for(my $i = 0; $i < scalar(@$item_name_list); $i++){				# use for loading and gen keys
		my $kn = $item_name_list->[$i];
		$item_name_hash->{$kn} = $i;
	}

	@$date_list = @w[$data_start..$#w];
	for(my $i = 0; $i < scalar(@$date_list); $i++){
		$date_list->[$i] = util::timefmt($timefmt, $date_list->[$i]);
	}
		
	$cdp->{dates} = scalar(@$date_list) - 1;
	$FIRST_DATE = $date_list->[0];
	$LAST_DATE = $date_list->[$#w - $data_start];

	#dp::dp join(",", "# ", @$date_list) . "\n";
	#dp::dp "keys : ", join(",", @keys). "\n";
	my @key_order = select::gen_key_order($cdp, $cdp->{keys});		# keys to gen record key
	my $load_order = $cdp->{load_order};
	my $key_dlm = $cdp->{key_dlm}; 
	my $ln = 0;
	while(<FD>){
		s/[\r\n]+$//;
		my $line = decode('utf-8', $_);
		my @items = split(/$src_dlm/, $line);
		my $k = select::gen_record_key($key_dlm, \@key_order, \@items);

		$csv_data->{$k}= [@items[$data_start..$#items]];	# set csv data
		$key_items->{$k} = [@items[0..($data_start - 1)]];	# set csv data
		push(@$load_order, $k);
		
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

	#
	#	Load CSV DATA
	#
	dp::dp "$csv_file\n";
	open(FD, $csv_file) || die "Cannot open $csv_file";
	my $line = <FD>;
	$line =~ s/[\r\n]+$//;
	$line = decode('utf-8', $line);

	dp::dp "$line\n";

	my @key_list = split(/$src_dlm/, $line);
	if($#key_list <= 1){
		dp::WARNING "may be wrong delimitter [$src_dlm]\n";
		print "\n";
	}
	shift(@key_list);
	foreach my $k (@key_list){
		#$k =~ s/^[0-9]+:// if($remove_head);			# 
		$csv_data->{$k}= [];		# set csv data array
		$key_items->{$k} = [$k];
	}

	my $key_name = $cdp->{key_name} // "";
	$key_name = "key" if(! $key_name);
	@{$cdp->{item_name_list}} = ($key_name);	# set item_name 
	$cdp->{item_name_hash}->{$key_name} = 0;

	my $ln = 0;
	while(<FD>){
		s/[\r\n]+$//;
		my $line = decode('utf-8', $_);
		my ($date, @items) = split(/$src_dlm/, $line);
	
		$date_list->[$ln] = util::timefmt($timefmt, $date);
		#dp::dp "date:$ln $date " . $date_list->[$ln] . " ($timefmt) $cdp->{title}\n";
	
		for(my $i = 0; $i <= $#items; $i++){
			my $k = $key_list[$i];
			$csv_data->{$k}->[$ln]= $items[$i];
		}
		$ln++;
	}
	close(FD);

	$cdp->{dates} = $ln - 1;
	$FIRST_DATE = $date_list->[0];
	$LAST_DATE = $date_list->[$ln-1];
	return 1;
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
	if(!defined $csv_data){
		dp::dp "somthing wrong at json, csv_data\n";
		$csv_data = {};
		$cdp->{csv_data} = $csv_data;
	}
	foreach my $k (@items){
		$key_items->{$k} = [$k];
		$csv_data->{$k} = [];
		#dp::dp "csv_data($k) :". $csv_data->{$k} . "\n";
	}	

	my $key_name = $cdp->{key_name} // "";
	$key_name = "key" if(! $key_name);
	@{$cdp->{item_name_list}} = ($key_name);	# set item_name 
	$cdp->{item_name_hash}->{$key_name} = 0;
	dp::dp "item_name_list: (" . join(",", @{$cdp->{item_name_list}}). ") [$key_name]\n";

	for(my $itn = 0; $itn <= $#items; $itn++){
		$load_order->[$itn] = $items[$itn];
	}
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
	$key_name = "key" if(! $key_name);
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
