#!/usr/bin/perl
#
#	Apple Mobile report
#	https://covid19.apple.com/mobility
#
#	Complete Data
#	https://covid19-static.cdn-apple.com/covid19-mobility-data/2025HotfixDev13/v3/en-us/applemobilitytrends-2021-01-25.csv
#
#	0        1      2                   3                4          5       6         7
#	geo_type,region,transportation_type,alternative_name,sub-region,country,2020/1/13,2020/1/14,2020/1/15,2020/1/16
#	country/region,Japan,driving,日本,Japan-driving,,100,97.94,99.14,103.16
#
##	CSV_DEF = {
#		title => "Apple Mobility Trends",						# Title of CSV (use for HTML and other)
#		main_url =>  "https://covid19.apple.com/mobility",		# Main URL to reffer
#
#		src_url => $src_url,									# Source URL to download (mainly for HTML)
#		csv_file =>  "$config::WIN_PATH/apm/abc.csv.txt",		# Dowanloaded file, csv file for anlyize
#		down_load => \&download,								# Download function (User must define this)
#
#		timefmt = '%Y-%m-%d',									# 2021-01-02 %Y/%m/%d
#		src_dlm => ",",											# Delimitter (usually "," or "\t")
#		keys => [1, 2],		# 5, 1, 2							# key column numbers  -> Japana-driving
#		data_start => 6,										# Start column number of dates
#
#		#### INITAIL at new
#		csv_data =>  {},										# Main Data (All data of CSV file)
#		date_list =>  [],										# Date information 
#		dates =>  0,											# Number of dates
#		order =>  {},											# Soreted order of data (key)
#		key_items =>  {};
#		avr_date =>  ($CDP->{avr_date} // $DEFAULT_AVR_DATE),
#	};
#
##	GRAPH_PARAMN
#		html_file => "$config::HTML_PATH/apple_mobile.html",	# HTML file to generate
#		html_title => $CSV_DEF->{title},						# Use for HTML Title
#		png_path   => "$config::PNG_PATH",						# directory for generating graph items
#		png_rel_path => "../PNG",								# Relative path of CSV, PNG
#		GRAPH_PARAMS = {
#
#		dst_dlm => "\t",										# Delimitter of csv  for gnueplot
#		avr_date => 7,											# Default rolling average term (date)
#	
#		timefmt => '%Y-%m-%d',									# Time format of CSV (gnueplot)
#		format_x => '%m/%d',									# Time format for Graph (gnueplot)
#	
#		term_x_size => 1000,									# Graph image size (x) PNG
#		term_y_size => 350,										# Graph image size (y) PNG
#	
#		END_OF_DATA => $END_OF_DATA,							# END MARK of graph parameters
#		graph_params => [
#			{
#				dsc => "Japan target prefecture", 				# Description of the graph, use for title and file name
#				lank => [1,5], 									# Target data for use (#1 to #5)
#				static => "rlavr", 								# "": Raw, "rlavr":Rolling average
#				start_date => "", 								# Start date: Date format or number (+: from firsta date, -: from last date)
#				end_date => ""									# 	2021-01-01, 10, -10
#				target_col => [ 								### Taget itmes 
#					"sub-region", 								# Col#0 = sub-region
#					"Tokyo,Osaka,Kanagawa",						# Col#1 = Tokyo or Osaka or Kanagawa
#					 "transit", 								# Col#2 = transit
#					"",											# Col#3 = any (*)
#					"",											# Col#4 = any (*)
#					"Japan" 									# Col#5 = Japan
#				],
#			},
#			{dsc => "Japan", lank => [1,99], static => "rlavr", target_col => [@JAPAN], start_date => "", end_date => ""},
#			{dsc => "Japan 2m", lank => [1,99], static => "", target_col => [@JAPAN], start_date => -93, end_date => ""},
#			{dsc => "Japan 2m", lank => [1,99], static => "rlavr", target_col => [@JAPAN], start_date => -93, end_date => ""},
#			{dsc => $END_OF_DATA},
#		}
#	};
#
package csvgraph;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(csvgraph);

use strict;
use warnings;
use utf8;
use Encode 'decode';
use JSON qw/encode_json decode_json/;
use Data::Dumper;
use config;
use csvlib;

binmode(STDOUT, ":utf8");

my $DEBUG = 0;
my $VERBOSE = 0;
my $DEFAULT_AVR_DATE = 7;
my $DEFAULT_KEY_DLM = "-";					# Initial key items
my $DEFAULT_GRAPH = "line";
our $CDP = {};

my $FIRST_DATE = "";
my $LAST_DATE  = "";

#
# Province,Region, Lat, Long, 2021-01-23, 2021-01-24
# ,Japan,33.39,44.12,32,101, 10123, 10124,,,,
# Tokyo,Japan,33.39,44.12,32,20123, 20124,,,,
#
my @cdp_arrays = (
	"date_list", 	# Date list (formated %Y-%m-%d)
	"keys", 		# items to gen key [1, 0] -> Japan#Tokyo, Japan#
	"load_order",	# Load order of the key (Japan#Tokyo, Japan#)
	"item_name_list",			# set by load csv ["Province","Region","Lat","Long"]
	"defined_item_name_list",	# set by user (definition)
);

my @cdp_hashs = (
	"order",					# sorted order 
	"item_name_hash",			# {"Province" => 0,"Region" => 1,"Lat" => 2,"Long" => 3]
	"defined_item_name_hash",	# Set from @defined_item_name_list
);

my @cdp_hash_with_keys = (
	"csv_data", 				# csv_data->{Japan#Tokyo}: [10123, 10124,,,,]
	"key_items"					# key_items->{Japan#Tokyo}: ["Tokyo","Japan",33,39]
);
my @cdp_values = (
	"id",			# ID of the definition "ccse", "amt" ,, etc
	"title", 		# Title(Description) of the definition
	"main_url", 	# main url to reffer
	"src_url", 		# source url of data
	"csv_file",		# CSV(or other) file to be downloaded
	"src_dlm", 		# Delimtter of the data "," or "\t"
	"timefmt", 		# Time format (gnuplot) %Y-%m-%d, %Y/%m/%d, etc
	"data_start",	# Data start colum, ex, 4 : Province,Region, Lat, Long, 2021-01-23, 
	"down_load", 	# Download function
);

sub	new
{
	my ($cdp) = @_;
	
	&init_cdp($cdp);
}

sub	init_cdp
{
	my ($cdp) = @_;
	
	foreach my $item (@cdp_arrays){
		$cdp->{$item} = [] if(! defined $cdp->{$item});
	}
	foreach my $item (@cdp_hashs, @cdp_hash_with_keys){
		$cdp->{$item} = {} if(! defined $cdp->{$item});
	}

	$cdp->{dates} = 0,
	$cdp->{avr_date} = ($cdp->{avr_date} // $DEFAULT_AVR_DATE),
	$cdp->{timefmt} = $cdp->{timefmt} // "%Y-%m-%d";
	$cdp->{key_dlm} = $cdp->{key_dlm} // $DEFAULT_KEY_DLM;
}

#
#	Dump csv definition
#
sub	dump_cdp
{
	my ($cdp, $p) = @_;

	my $ok = $p->{ok} // 1;
	my $lines = $p->{lines} // "";
	my $items =$p->{items} // 5;
	my $mess = $p->{message} // "";


	print "#" x 10 . "[$mess] CSV DUMP " . $cdp->{title} . " " . "#" x 10 ."\n";
	print "##### VALUE ######\n";
	foreach my $k (@cdp_values){
		print "$k\t" . ($cdp->{$k} // "undef") . "\n";
	}
	print "##### ARRAY ######\n";
	foreach my $k (@cdp_arrays){
		my $p = $cdp->{$k} // "";
		if($p){
			my $arsize = scalar(@$p) - 1;
			$arsize = $items if($arsize > $items);
		 	print "$k\t" . join(",", @{$p}[0..$arsize]). "\n";
		}
		else {
			print "$k\tundef\n";
		}
	}
	print "##### HASH ######\n";
	foreach my $k (@cdp_hashs){
		my $p = $cdp->{$k} // "";
		if($p){
			my @ar = %$p;
			my $arsize = ($#ar > ($items * 2)) ? ($items * 2) : $#ar;
		 	print "$k\t" . join(",", @ar[0..$arsize]). "\n";
		}
		else {
			print "$k\tundef\n";
		}
	}

	my $csv_data = $cdp->{csv_data};
	my $key_items = $cdp->{key_items};
	my $key_count = scalar(keys (%$csv_data));
	my $load_order = $cdp->{load_order};
	
	$p->{src_csv} = $cdp->{src_csv};
	&dump_csv_data($csv_data, $p, $cdp);
	&dump_key_items($key_items, $p, $cdp);
	#dp::dp "LOAD ORDER " . join(",", @$load_order) . "\n";

	print "#" x 40 . "\n\n";
}

sub dump_key_items
{
	my($key_items, $p, $cdp) = @_;
	my $ok = $p->{ok} // 1;
	my $lines = $p->{lines} // 5;
	my $items = $p->{items} // 5;
	my $mess = $p->{message} // "";


	my $src_csv = $cdp->{src_csv} // "";
	my $search_key = $p->{search_key} // "";
	$lines = 0 if($search_key && ! defined $p->{lines});

	print "------ [$mess] Dump keyitems data ($key_items) search_key[$search_key] --------\n";
	my $ln = 0;
	foreach my $k (keys %$key_items){
		if($search_key &&  $k =~ /$search_key/){
			print "key_items[$ln] $k: " . join(",", @{$key_items->{$k}}, " [$search_key]") . "\n";
		}
		elsif($lines eq "" || $ln <= $lines){
			print "key_items[$ln] $k: " . join(",", @{$key_items->{$k}}) . "\n";
		}
		$ln++;
	}
}

sub	dump_csv_data
{
	my($csv_data, $p, $cdp) = @_;
	my $ok = $p->{ok} // 1;
	my $lines = $p->{lines} // "";
	my $items = $p->{items} // 5;
	my $src_csv = $cdp->{src_csv} // "";
	my $mess = $p->{message} // "";
	my $search_key = $p->{search_key} // "";
	$lines = 0 if($search_key && ! defined $p->{lines});

	$mess = " [$mess]" if($mess);
	print "------$mess Dump csv data ($csv_data) [$search_key]--------\n";
	#csvlib::disp_caller(1..3);
	print "-" x 30 . "\n";
	my $ln = 0;
	foreach my $k (keys %$csv_data){
		my @w = @{$csv_data->{$k}};
		next if($#w < 0);

		my $f = ($k =~ /$search_key/) ? "*" : " ";
		#dp::dp "$f $ok $k [$search_key] \n";
		if(! defined $w[1]){
			dp::dp " --> [$k] csv_data is not assigned\n";
		}
		if($ok){
			my $scv = "";
			if($src_csv) {
				$scv = $src_csv->{$k} // "-" ;
			}

			if($search_key && $k =~ /$search_key/){
				print "[$ln] " . join(", ", $k, "[$scv]", @w[0..$items]) . " [$search_key]\n";
			}
			elsif($lines eq "" || $ln < $lines){
				print "[$ln] " . join(", ", $k, "[$scv]", @w[0..$items]) . "\n";
			}
		}
		$ln++;
	}
	dp::dp "-" x 30 . "\n";
}


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

	dp::dp "LOAD CSV  [$cdp->{title}][$cdp->{id}]\n";
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
	&dump_cdp($cdp, {ok => 1, lines => 5}) if($rc || $VERBOSE > 1);
	
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
		$date_list->[$i] = &timefmt($timefmt, $date_list->[$i]);
	}
		
	$cdp->{dates} = scalar(@$date_list) - 1;
	$FIRST_DATE = $date_list->[0];
	$LAST_DATE = $date_list->[$#w - $data_start];

	#dp::dp join(",", "# ", @$date_list) . "\n";
	#dp::dp "keys : ", join(",", @keys). "\n";
	my @key_order = &gen_key_order($cdp, $cdp->{keys});		# keys to gen record key
	my $load_order = $cdp->{load_order};
	my $key_dlm = $cdp->{key_dlm} // $DEFAULT_KEY_DLM;
	my $ln = 0;
	while(<FD>){
		s/[\r\n]+$//;
		my $line = decode('utf-8', $_);
		my @items = split(/$src_dlm/, $line);
		my $k = &gen_record_key($key_dlm, \@key_order, \@items);

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
	
		$date_list->[$ln] = &timefmt($timefmt, $date);
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
	my @items = &csv($line);

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
		my (@vals)  = &csv($_);

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


#
#	Marge csvdef
#
sub	marge_csv
{
	my ($marge, @src_csv_list) = @_;

	&new($marge);
	foreach my $key (@cdp_values){
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
}

#
#	Copy and Reduce CSV DATA with replace data set
#
sub	copy_cdp
{
	my($cdp, $dst_cdp) = @_;
	
	&reduce_cdp($dst_cdp, $cdp, $cdp->{load_order});
}

my $dumpf = 0;
sub	reduce_cdp_target
{
	my ($dst_cdp, $cdp, $target_colp) = @_;

	#dp::dp Dumper $target_colp;

	my @target_keys = ();
	my $target = &select_keys($cdp, $target_colp // "", \@target_keys);
	if($target < 0){
		dp::ABORT "No data " . csvlib::join_array(",", @$target_colp) . "##" . join(",", @target_keys) . "\n";
	}
	#my $ft = $target_colp->[0] ;
	#if(0 && $ft eq "NULL"){
	#	$dumpf = 1;
	#	#dp::dp "###### TARGET_KEYS #######\n";
	#	#dp::dp join("\n", @target_keys);
	#	#dp::dp "################\n";
	#}
	&reduce_cdp($dst_cdp, $cdp, \@target_keys);
	&dump_cdp($dst_cdp, {ok => 1, lines => 20, items => 20}) if($DEBUG);
	$dumpf = 0;
}

sub	reduce_cdp
{
	my($dst_cdp, $cdp, $target_keys) = @_;

	&new($dst_cdp);

	@{$dst_cdp->{load_order}} = @$target_keys;		

	#my @arrays = ("date_list", "keys");
	#my @hashs = ("order");
	my @hash_with_keys = ("csv_data", "key_items");

	&new($dst_cdp);
	%$dst_cdp = %$cdp;
	foreach my $val (@cdp_values){
		$dst_cdp->{$val} = $cdp->{$val} // "";
	}
	foreach my $array_item (@cdp_arrays){
		$dst_cdp->{$array_item} = [];
		@{$dst_cdp->{$array_item}} = @{$cdp->{$array_item}};
	}
	foreach my $hash_item (@cdp_hashs){
		$dst_cdp->{$hash_item} = {};
		%{$dst_cdp->{$hash_item}} = %{$cdp->{$hash_item}};
	}
	foreach my $hwk (@hash_with_keys){
		my $src = $cdp->{$hwk};
		$dst_cdp->{$hwk} = {};
		my $dst = $dst_cdp->{$hwk};
		foreach my $key (@$target_keys){
			#dp::dp "reduce - target_keys: $hwk:$key\n" if($dumpf);
			$dst->{$key} = [];
			@{$dst->{$key}} = @{$src->{$key}};
		}
	}
	my $dst_key = $dst_cdp->{key_items};
	my $dst_csv = $dst_cdp->{csv_data};
	if($DEBUG){
		my $kn = 0;
		foreach my $key (keys %$dst_csv){
			last if($kn++ > 5);

			#dp::dp "############ $key\n" if($key =~ /Canada/);
			#dp::dp "csv[$key] " . join(",", @{$dst_csv->{$key}}[0..5]) . "\n";
			#dp::dp "key[$key] " . join(",", @{$dst_key->{$key}}[0..5]) . "\n";
		}
		&dump_cdp($dst_cdp, {ok => 1, lines => 20, items => 20}); # if($DEBUG);
	}
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
	if(! ($target_colp//"") || &array_size($target_colp) <= 0){
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
			#dp::dp "[$key:$condition:$res]\n" if($verbose  > 1);
			#dp::dp "### " . join(", ", (($res >= $condition) ? "#" : "-"), $key, $res, $condition, @$key_in_data) . "\n" if($verbose > 1) ;
			next if ($res < 0);

			if($res >= $condition){
				push(@$target_keys, $key);
				if($verbose){
					dp::dp "### " . join(", ", (($res >= $condition) ? "#" : "-"), $key, $res, $condition, @$key_in_data) . "\n";
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
			"No data Target[".ref($target_colp)."]:(".csvlib::join_array(",", $target_colp).") Result:(".join(",", @$target_keys).")\n",
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

	dp::dp csvlib::join_array(",", @$target_col_array) . "\n" if($verbose);
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

		dp::dp "data $kn $key_in_data->[$kn] =~ (" .join(",", @{$target_col_array->[$kn]}) . ") ["
				 . join(",", @$key_in_data) . "]\n" if($verbose);
		if(csvlib::search_listn($key_in_data->[$kn], @$skey) >= 0){
			$condition++ 									# Hit to target
		}
	}
	#dp::dp "----> $condition: $kid\n" if($kid =~ /Canada/);
	return $condition;
}

#
#	Add Average
#
#	obsoleted: use calc_items "avr"
#
#
sub	add_average
{
	my ($cdp, $target_col, $name) = @_;
	$name = $name // "avr";

	#
	#	Calc total
	#
	my $csv_data = $cdp->{csv_data};
	my $key_items = $cdp->{key_items};

	if($target_col =~ /\D/){ 		# array number or item name
		my $item_name_hash = $cdp->{item_name_hash};
		my $tn = $item_name_hash->{$target_col} // "";
		if($tn eq ""){
			dp::ABORT "no column naeme [$target_col]\n";
		}
		$target_col = $tn;
	}

	my $dates = $cdp->{dates};
	#my @keys = @{$cdp->{keys}};						# Item No for gen HASH Key
	my @key_order = &gen_key_order($cdp, $cdp->{keys});		# keys to gen record key
	my $key_dlm = $cdp->{key_dlm} // $DEFAULT_KEY_DLM;
	my %ak_list = ();
	foreach my $key (keys %$csv_data){
		my @avr_key_items = (@{$key_items->{$key}});	# generate average key items
		$avr_key_items[$target_col] = $name;

		my @gen_key = ();							# generate average key
		foreach my $n (@key_order){
			my $itm = $avr_key_items[$n];
			push(@gen_key, $itm);
		}
		my $ak = join($key_dlm, @gen_key);			# set key_name
		$ak_list{$ak}++;							# set average key list

		if(! defined $csv_data->{$ak}){				# initail average data
			$csv_data->{$ak}= [];					# set csv data
			$key_items->{$ak} = [@avr_key_items];	# set key data
		}

		my $csvp = $csv_data->{$key};				# add data to average
		my $avr_csvp = $csv_data->{$ak};
		for(my $i = 0; $i <= $dates; $i++){
			my $v = $csvp->[$i] // 0;
			my $va = $avr_csvp->[$i] // 0;
			$v = 0 if($v eq "");
			$va = 0 if($va eq "");
			#dp::dp "$i: $key -> [$v]  $ak -> [$va]\n";
			$avr_csvp->[$i] = $v + $va;
		}
	}

	#
	#	Total to average
	#
	foreach my $ak (keys %ak_list){
		my $avr_csvp = $csv_data->{$ak};
		for(my $i = 0; $i <= $dates; $i++){
			my $va = $avr_csvp->[$i];
			$avr_csvp->[$i] = $va / $ak_list{$ak};
		}
	}
	#&dump_cdp($cdp, {ok => 0});
}

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
sub	calc_items
{
	my ($cdp, $method, $target_colp, $result_colp) = @_;

	my $verbose = 0;
	#
	#	Calc 
	#
	my $csv_data = $cdp->{csv_data};
	my $key_items = $cdp->{key_items};
	my $key_dlm = $cdp->{key_dlm} // $DEFAULT_KEY_DLM;

	#my $target_colp = $instruction->{target_col};
	#my $result_colp = $instruction->{result_col};

	my $target_keys = [];
	my $target = &select_keys($cdp, $target_colp // "", $target_keys);	# set target records
	if($target < 0){
		return -1;
	}
	dp::dp "target items : $target " . csvlib::join_array(",", $target_colp) . "\n" if($verbose);

	my @key_order = &gen_key_order($cdp, $cdp->{keys}); # keys to gen record key
	my @riw = &gen_key_order($cdp, [keys %$result_colp]); # keys order to gen record key

	dp::dp "key_order: " .join(",", @key_order) . "\n" if($verbose);
	dp::dp "restore_order: " .join(",", @riw) . "\n" if($verbose);

	my @result_info = ();
	for(my $i = 0; $i < $cdp->{data_start}; $i++){			# clear to avoid undef
		$result_info[$i] = "";
	}
	my $item_name_hash = $cdp->{item_name_hash};						# List and Hash need to make here
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
		my @key_list = ();
		for (my $i = 0 ; $i <= $#key_order; $i++){				# [0, 1] 
			my $kn = $key_order[$i];
			my $item_name = $src_kp->[$kn];				# ["Qbek", "Canada"]
			dp::dp "$item_name [$i][$kn]($result_info[$kn])\n" if($verbose);
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
				else {
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
		my $record_key = &gen_record_key($key_dlm, \@key_order, \@dst_keys);
		$record_key_list{$record_key}++;
		dp::dp "record_key [$record_key]" . join(",", @key_order, "##", @key_list) . "\n" if($verbose && $record_key =~ /Japan/ );
		
		if(! defined $csv_data->{$record_key}){				# initial $record_key
			dp::dp "init: $record_key\n" if($VERBOSE);
			$key_items->{$record_key} = [@dst_keys];
			$csv_data->{$record_key} = [];
			my $dst_dp = $csv_data->{$record_key};			# total -> dst
			for(my $i = 0; $i < scalar(@$src_dp); $i++){	# initial csv_data
				$dst_dp->[$i] = 0;					
			}
		}
		my $dst_dp = $csv_data->{$record_key};				# total -> dst
		for(my $i = 0; $i < scalar(@$src_dp); $i++){
			my $v = $src_dp->[$i] // 0;
			$v = 0 if($v eq "");
			$dst_dp->[$i] += $v;
		}
		dp::dp "####[$record_key] " . join(",", @$dst_dp[0..5]) . "\n" if($verbose);
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

#
#	Generate png, plot-csv.txt, plot-cmv
#
sub	gen_graph_by_list
{
	my($cdp, $gdp) = @_;

	foreach my $gp (@{$gdp->{graph_params}}){
		&csv2graph($cdp, $gdp, $gp);
		#dp::dp join(",", $gp->{dsc}, $gp->{start_date}, $gp->{end_date},
		#		$gp->{fname}, $gp->{plot_png}, $gp->{plot_csv}, $gp->{plot_cmd}) . "\n";
	}
	return (@{$gdp->{graph_params}});
}


#
#
#
sub gen_html_by_gp_list
{
	my ($graph_params, $p) = @_;

	my $html_title = $p->{html_tilte} // "html_title";
	my $src_url = $p->{src_url} //"src_url";
	my $html_file = $p->{html_file} //"html_file";
	my $png_path = $p->{png_path} //"png_path";
	my $png_rel_path = $p->{png_rel_path} //"png_rel_path";
	my $data_source = $p->{data_source} // "data_source";
	my $dst_dlm = $p->{dst_dlm} // "\t";

	my $CSS = $config::CSS;
	my $class = $config::CLASS;

	csvlib::disp_caller(1..3) if($VERBOSE);
	open(HTML, ">$html_file") || die "Cannot create file $html_file";
	binmode(HTML, ":utf8");

	print HTML "<HTML>\n";
	print HTML "<HEAD>\n";
	print HTML "<TITLE> " . $html_title . "</TITLE>\n";
	print HTML $CSS;
	print HTML "</HEAD>\n";
	print HTML "<BODY>\n";
	my $now = csvlib::ut2d4(time, "/") . " " . csvlib::ut2t(time, ":");

	print HTML "<h3>Data Source：$data_source</h3>\n";

	dp::dp  ">>>> " .scalar(@$graph_params) . "\n";
	foreach my $gp (@$graph_params){
		print HTML "<span class=\"c\">$now</span><br>\n";
		print HTML '<img src="' . $png_rel_path . "/" . $gp->{plot_png} . '">' . "\n";
		print HTML "<br>\n";
	
		#
		#	Lbale name on HTML for search
		#
		my $csv_file = $png_path . "/" . $gp->{plot_csv};
		open(CSV, $csv_file) || die "canot open $csv_file";
		binmode(CSV, ":utf8");

		my $l = <CSV>;		# get label form CSV file
		close(CSV);
		$l =~ s/[\r\n]+$//;
		my @lbl = split($dst_dlm, $l);
		shift(@lbl);

		my $lcount = 10;
		print HTML "<span class=\"c\">\n";
		print HTML "<table>\n<tbody>\n";
		for (my $i = 0; $i < $#lbl; $i += $lcount){
			print HTML "<tr>";
			for(my $j = 0; $j < $lcount; $j++){
				last if(($i + $j) > $#lbl);
				print HTML "<td>" . $lbl[$i+$j] . "</td>";
				#dp::dp "HTML LABEL: " . $lbl[$i+$j] . "\n";
			}
			print HTML "</tr>\n";
		}
		print HTML "</tbody>\n</table>\n";
		print HTML "</span>\n";

		print HTML "<span $class> <a href=\"$src_url\" target=\"blank\"> Data Source (CSV) </a></span>\n";
		#
		#	References
		#
		my @refs = (join(":", "PNG", $png_rel_path . "/" .$gp->{plot_png}),
					join(":", "CSV", $png_rel_path . "/" .$gp->{plot_csv}),
					join(":", "PLT", $png_rel_path . "/" .$gp->{plot_cmd}),
		);
		print HTML "<hr>\n";
		print HTML "<span $class>";
		foreach my $r (@refs){
			my ($tag, $path) = split(":", $r);
			print HTML "$tag:<a href=\"$path\" target=\"blank\">$path</a>\n"; 
		}
		print HTML "<br>\n" ;
		print HTML "</span>\n";
		print HTML "<br><hr>\n\n";
	}
	print HTML "</BODY>\n";
	print HTML "</HTML>\n";
	close(HTML);
}

#
#
#	&gen_html($cdp, $GRAPH_PARAMS);
#
sub	gen_html
{
	my ($cdp, $gdp, $gp) = @_;

	csvlib::disp_caller(1..3); # if($VERBOSE);
	my $html_file = $gdp->{html_file};
	my $png_path = $gdp->{png_path};
	my $png_rel_path = $gdp->{png_rel_path};
	my $data_source = $cdp->{data_source};
	my $dst_dlm = $gdp->{dst_dlm} // "\t";

	foreach my $gp (@{$gdp->{graph_params}}){
		last if($gp->{dsc} eq $gdp->{END_OF_DATA});
		&csv2graph($cdp, $gdp, $gp);
	}
	my $p = {
		src_url => $cdp->{src_url} // "",
		html_title => $gdp->{html_title} // "",
		html_file => $gdp->{html_file} // "",
		png_path => $gdp->{png_path} // "",
		png_rel_path => $gdp->{png_rel_path} // "",
	};
	&gen_html_by_gp_list($gdp->{graph_params}, $p);
}

sub	dup_csv
{
	my ($cdp, $work_csv, $target_keys) = @_;

	my $csv_data = $cdp->{csv_data};
	#dp::dp "dup_csv: cdp[$cdp] csv_data : $csv_data\n";
	$target_keys = $target_keys // "";
	if(! $target_keys){
		my @tgk = ();
		my $csv_data = $cdp->{csv_data};
		#dp::dp ">>dup_csv cdp[$cdp] csv_data[$csv_data]\n";
		foreach my $k (keys %$csv_data){
			push(@tgk, $k);
		}
		#@$target_keys = (keys %$csv_data);
		#dp::dp "DUP.... " . join(",", @tgk) . "\n";
		$target_keys = \@tgk;
		#exit;
	}
	foreach my $key (@$target_keys){						#
		$work_csv->{$key} = [];
		#dp::dp "$key: $csv_data->{$key}\n";
		push(@{$work_csv->{$key}}, @{$csv_data->{$key}});
	}
}

#
#	Generate Graph and its information but not html file
#
sub	csv2graph_list
{
	my($cdp, $gdp, $graph_params, $verbose) = @_;
	$verbose = $verbose // "";

	if(! (defined $cdp->{id})){
		dp::ABORT "may be you call  csv2graph_list_mix, instead of csv2graph_list\n";
	}
	foreach my $gp (@$graph_params){
		&csv2graph($cdp, $gdp, $gp, $verbose);
	}
	return (@$graph_params);
}

sub	csv2graph_list_mix
{
	my(@gp_list) = @_;

	my @graph_params = ();
	foreach my $gp (@gp_list){
		if(ref($gp) ne "HASH"){
			dp::ABORT "Parameter is not HAS $gp\n";
		}
		if(! (defined $gp->{cdp})){
			dp::ABORT "may be you call  csv2graph_list, instead of csv2graph_list_mix\n";
		}
		last if($gp->{cdp} eq "");

		my $cdp = $gp->{cdp} // dp::ABORT "cdp";
		my $gdp = $gp->{gdp} // dp::ABORT "gdp";
		&csv2graph($cdp, $gdp, $gp);
		push(@graph_params, $gp);
	}

	return (@graph_params);
}

#
#	Generate Graph fro CSV_DATA and Graph Parameters
#
sub	csv2graph
{
	my($cdp, $gdp, $gp, $verbose) = @_;
	$verbose = $verbose // "";
	my $csv_data = $cdp->{csv_data};

	#
	#	Set Date Infomation to Graph Parameter
	#
	my $date_list = $cdp->{date_list};
	my $dates = $cdp->{dates};
	my $start_date = &date_calc(($gp->{start_date} // ""), $date_list->[0], $cdp->{dates}, $date_list);
	my $end_date   = &date_calc(($gp->{end_date} // ""),   $date_list->[$dates], $cdp->{dates}, $date_list);
	#dp::dp "START_DATE: $start_date [" . ($gp->{start_date} // "NULL"). "] END_DATE: $end_date [" . ($gp->{end_date}//"NULL") . "]\n";
	$gp->{start_date} = $start_date;
	$gp->{end_date} = $end_date;
	&date_range($cdp, $gdp, $gp); 						# Data range (set dt_start, dt_end (position of array)

	#
	#	Set File Name
	#
	my $fname = $gp->{fname} // "";
	if(! $fname){
		$fname = join(" ", $gp->{dsc}, $gp->{static}, $gp->{start_date});
		$fname =~ s/[\/\.\*\ #]/_/g;
		$fname =~ s/\W+/_/g;
		$fname =~ s/__+/_/g;
		$fname =~ s/^_//;
		$gp->{fname} = $fname;
	}
	$gp->{plot_png} = $gp->{plot_png} // "$fname.png";
	$gp->{plot_csv} = $gp->{plot_csv} // "$fname-plot.csv.txt";
	$gp->{plot_cmd} = $gp->{plot_cmd} // "$fname-plot.txt";

	#
	#	select data and generate csv data
	#
	my @target_keys = ();
	my $target_col = $gp->{target_col};
	my $tn  = &array_size($target_col);
	if($tn < 0){
		dp::WARNING "target_col is not array or hash ($target_col)\n";
	}

	dp::dp "$target_col: ($tn)(" . csvlib::join_array(",", $target_col) . ")\n" if($verbose);

	&select_keys($cdp, $gp->{target_col} // "", \@target_keys, 0);	# select data for target_keys
	#dp::dp "target_key: " . join(" : ", @target_keys). "\n" ;
	#dp::dp "target_col: " . join(" : ", @{$gp->{target_col}}) . "\n";
	if($#target_keys < 0){
		return -1;
	}

	my %work_csv = ();									# copy csv data to work csv
	&dup_csv($cdp, \%work_csv, \@target_keys);
	
	if($gp->{static} eq "rlavr"){ 						# Rolling Average
		&rolling_average($cdp, \%work_csv, $gdp, $gp);
	}
	elsif($gp->{static} eq "ern"){ 						# Rolling Average
		&ern($cdp, \%work_csv, $gdp, $gp);
	}

	#
	#	Sort target record
	#
	my @lank = ();
	@lank = (@{$gp->{lank}}) if(defined $gp->{lank});
	$lank[0] = 1 if(defined $lank[0] && ! $lank[0]);
	my $lank_select = (defined $lank[0] && defined $lank[1] && $lank[0] && $lank[1]) ? 1 : "";

	my @sorted_keys = ();								# sort
	if($lank_select){
		&sort_csv($cdp, \%work_csv, $gp, \@target_keys, \@sorted_keys);
	}
	else {
		my $load_order = $cdp->{load_order};
		@sorted_keys = @$load_order;		# no sort, load Order
	}

	my $order = $cdp->{order};							# set order of key
	my $n = 1;
	foreach my $k (@sorted_keys){
		$order->{$k} = ($lank_select) ? $n : 1;
		$n++;
	}

	#
	#	Genrarte csv file and graph (png)
	#
	my @output_keys = ();
	foreach my $key (@sorted_keys){
		next if($lank_select && ($order->{$key} < $lank[0] || $order->{$key} > $lank[1]));
		push(@output_keys, $key);
	}
	my $csv_for_plot = &gen_csv_file($cdp, $gdp, $gp, \%work_csv, \@output_keys);		# Generate CSV File
	#dp::dp "$csv_for_plot\n";

	&graph($csv_for_plot, $cdp, $gdp, $gp);					# Generate Graph
	return @;
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
#	Generate CSV File
#
sub	gen_csv_file
{
	my($cdp, $gdp, $gp, $work_csvp, $output_keysp) = @_;
	my $fname = $gp->{fname};
	my $date_list = $cdp->{date_list};
	my $dst_dlm = $gdp->{dst_dlm};
	my $dt_start = $gp->{dt_start};
	my $dt_end = $gp->{dt_end};

	#dp::dp "[$dt_start][$dt_end]\n";
	my $csv_for_plot = $gdp->{png_path} . "/" . $gp->{plot_csv}; #"/$fname-plot.csv.txt";
	#dp::dp "### $csv_for_plot\n";
	open(CSV, "> $csv_for_plot") || die "cannot create $csv_for_plot";
	binmode(CSV, ":utf8");

	my $order = $cdp->{order};
	my @csv_label = ();
	foreach my $k (@$output_keysp){
		my $label = join(":", $order->{$k}, $k);
		push(@csv_label, $label);
	}
	print CSV join($dst_dlm, "#date", @csv_label) . "\n";

	for(my $dt = $dt_start; $dt <= $dt_end; $dt++){
		my @w = ();
		foreach my $key (@$output_keysp){
			my $csv = $work_csvp->{$key};
			my $v = $csv->[$dt] // "";
			$v = 0 if($v eq "");
			push(@w, $v);
		}
		if(! defined $date_list->[$dt]){
			dp::dp "### undefined date_list : $dt\n";
		}
		print CSV join($dst_dlm, $date_list->[$dt], @w) . "\n";
	}
	close(CSV);

	return $csv_for_plot;
}

#
#	SORT
#
sub	sort_csv
{
	my ($cdp, $cvdp, $gp, $target_keysp, $sorted_keysp) = @_;
	my $dt_start = $gp->{dt_start};
	my $dt_end = $gp->{dt_end};

	my %SORT_VAL = ();
	my $src_csv = $cdp->{src_csv} // "";
	foreach my $key (@$target_keysp){
		if(! $key){
			dp::dp "WARING at sort_csv: empty key [$key]\n";
			next;
		}

		my $csv = $cvdp->{$key};
		my $total = 0;
		for(my $dt = $dt_start; $dt <= $dt_end; $dt++){
			my $v = $csv->[$dt] // 0;
			$v = 0 if(! $v);
			$total += $v ;
		}
		$SORT_VAL{$key} = $total;
		if($src_csv && (! defined $src_csv->{$key})){
			dp::dp "WARING at sort_csv: No src_csv definition for [$key]\n";
		}
	}
	if(! $src_csv){		# Marged CSV
		@$sorted_keysp = (sort {$SORT_VAL{$b} <=> $SORT_VAL{$a}} keys %SORT_VAL);
	}
	else {
		@$sorted_keysp = (sort {$src_csv->{$a} <=> $src_csv->{$b} or $SORT_VAL{$b} <=> $SORT_VAL{$a}} keys %SORT_VAL);
	}
}

#
#	Data range
#
sub	date_range
{
	my($cdp, $gdp, $gp) = @_;

	my $id = $cdp->{id} // ($cdp->{title} // "no-id");
	my $date_list = $cdp->{date_list};
	#dp::dp "DATE: " . join(", ", $gp->{start_date}, $gp->{end_date}, "#", @$date_list[0..5]) . "\n";
	my $dt_start = csvlib::search_listn($gp->{start_date}, @$date_list);
	if($dt_start < 0){
		dp::WARNING "[$id]: Date $gp->{start_date} is not in the data ($cdp->{title}) " . join(",", @$date_list[0..5]) ."\n";
		csvlib::disp_caller(1..3);
		$dt_start = 1;
	}
	$dt_start = 0 if($dt_start < 0 || $dt_start > $cdp->{dates});
	my $dt_end   = csvlib::search_listn($gp->{end_date},   @$date_list);
	if($dt_end < 0){
		my $dtc = scalar(@$date_list) - 1;
		dp::WARNING "[$id]: Date $gp->{end_date} is not in the data ($cdp->{title}) $dtc" . join(",", @$date_list[($dtc-5)..$dtc]) ."\n";
		csvlib::disp_caller(1..3);
		$dt_end = $dt_end + 1;
	}
	$dt_end = $cdp->{dates} if($dt_end < 0 || $dt_end > $cdp->{dates});
	$gp->{dt_start} = $dt_start;
	$gp->{dt_end}   = $dt_end;
}

##########################
#
#	Calc Rolling Average
#
sub	rolling_average
{
	my($cdp, $work_csvp, $gdp, $gp) = @_;

	my $avr_date = $cdp->{avr_date} // $DEFAULT_AVR_DATE;
	foreach my $key (keys %$work_csvp){
		my $dp = $work_csvp->{$key};
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
}	

#
#	combert csv data to ERN
#
sub	comvert2rlavr
{
	my($cdp, $p) = @_;

	my $gdp = {};
	my $gp = {};
	my %work_csv = ();
	my $work_csvp = \%work_csv;

	&dup_csv($cdp, $work_csvp, "");
	#&dump_csv_data($work_csvp, {ok => 1, lines => 5, message => "comver2rlavr:dup"}) if(1);
	&rolling_average($cdp, $work_csvp, $gdp, $gp);
	#&dump_csv_data($work_csvp, {ok => 1, lines => 5, message => "comver2rlavr:ern"}) if(1);
	$cdp->{csv_data} = "";
	$cdp->{csv_data} = $work_csvp;
}

#
#	combert csv data to ERN
#
sub	comvert2ern
{
	my($cdp, $p) = @_;

	my $gp  = {
		lp => $p->{lp} // $config::RT_LP,
		ip => $p->{ip} // $config::RT_IP,
	};
	my $gdp = {};
	my %ern_csv = ();
	my $ern_csvp = \%ern_csv;

	&dup_csv($cdp, $ern_csvp, "");
	#&dump_csv_data($ern_csvp, {ok => 1, lines => 5, message => "comver2ern:dup"}) if(1);

	&ern($cdp, $ern_csvp, $gdp, $gp);
	#&dump_csv_data($ern_csvp, {ok => 1, lines => 5, message => "comver2ern:ern"}) if(1);
	$cdp->{csv_data} = "";
	$cdp->{csv_data} = $ern_csvp;
}

#
#	ERN
#
sub	ern
{
	my($cdp, $work_csvp, $gdp, $gp) = @_;

	my $lp = $gp->{lp} // ($gdp->{lp} // $config::RT_LP);
	my $ip = $gp->{ip} // ($gdp->{ip} // $config::RT_IP);	# 5 感染期間
	my $avr_date = $cdp->{avr_date} // $DEFAULT_AVR_DATE;

	dp::dp "CALC ERN: $lp, $ip\n";
	my %rl_avr = ();
	&rolling_average($cdp, $work_csvp, $gdp, $gp);

	my $date_number = $cdp->{dates};
	my $rate_term = $date_number - $ip - $lp;
	my $date_term = $rate_term - 1;
	foreach my $key (keys %$work_csvp){
		my $dp = $work_csvp->{$key};
		my @ern = ();
		my $dt = 0;
		for($dt = 0; $dt < $rate_term; $dt++){
			my $ppre = $ip * $dp->[$dt+$lp+$ip];
			my $pat = 0;
			for(my $d = $dt + 1; $d <= ($dt + $ip); $d++){
				$pat += $dp->[$d];
			}
			# print "$country $dt: $ppre / $pat\n";
			if($pat > 0){
				$ern[$dt] =  int(1000 * $ppre / $pat) / 1000;
			}
			else {
				$ern[$dt] =  0;
			}
		}
		for(; $dt <= $date_number; $dt++){
			$ern[$dt] = "NaN";
		}
		@$dp = @ern;
		#dp::dp join(",", @$dp[0..5]). "\n";
	}

}	


#
#	Generate Glaph from csv file by gnuplot
#
sub	graph
{
	my($csv_for_plot, $cdp, $gdp, $gp) = @_;

	my $title = join(" ", $gp->{dsc}, $gp->{static}, "($LAST_DATE)");
	#dp::dp "#### " . join(",", "[" . $p->{lank}[0] . "]", @lank) . "\n";

	my $fname = $gdp->{png_path} . "/" . $gp->{fname};
	my $csvf = $fname . "-plot.csv.txt";
	my $pngf = $fname . ".png";
	my $plotf = $fname. "-plot.txt";

	my $dlm = $gdp->{dst_dlm};

	my $time_format = $gdp->{timefmt};
	my $format_x = $gdp->{format_x};
	my $term_x_size = $gdp->{term_x_size};
	my $term_y_size = $gdp->{term_y_size};

	my $start_date = $gp->{start_date} // "NONE";
	my $end_date = $gp->{end_date} // "NONE";

	my $start_ut = csvlib::ymds2tm($start_date);
	my $end_ut = csvlib::ymds2tm($end_date);
	my $dates = ($end_ut - $start_ut) / (60 * 60 * 24);
	my $xtics = 60 * 60 * 24 * 7;
	if($dates < 93){
		$xtics = 1 * 60 * 60 * 24;
	}
	elsif($dates < 120){
		$xtics = 2 * 60 * 60 * 24;
	}

	#dp::dp "ymin: [$gdp->{ymin}]\n";
	my $ymin = $gp->{ymin} // ($gdp->{ymin} // "");
	my $ymax = $gp->{ymax} // ($gdp->{ymax} // "");
	my $yrange = ($ymin ne ""|| $ymax ne "") ? "set yrange [$ymin:$ymax]" : "# yrange";
	my $ylabel = $gp->{ylabel} // ($gdp->{ylabel} // "");
	$ylabel = "set ylabel '$ylabel'"  if($ylabel);

	my $y2min = $gp->{y2min} // ($gdp->{y2min} // "");
	my $y2max = $gp->{y2max} // ($gdp->{y2max} // "");
	my $y2range = ($y2min ne ""|| $y2max ne "") ? "set y2range [$y2min:$y2max]" : "# y2range";
	my $y2label = $gp->{y2label} // ($gdp->{y2label} // "");
	$y2label = ($y2label) ? "set y2label '$y2label'" : "# y2label";
	my $y2tics = "set y2tics";		# Set y2tics anyway

	#
	#	Draw Graph
	#
	my $PARAMS = << "_EOD_";
#!/usr/bin/gnuplot
#csv_file = $csvf
set datafile separator '$dlm'
set xtics rotate by -90
set xdata time
set timefmt '$time_format'
set format x '$format_x'
set mxtics 2
set mytics 2
#set grid xtics ytics mxtics mytics
set key below
set title '$title' font "IPAexゴシック,12" enhanced
#set xlabel 'date'
$ylabel
$y2label
#
set xtics $xtics
set xrange ['$start_date':'$end_date']
set grid
$yrange
$y2range
$y2tics

set terminal pngcairo size $term_x_size, $term_y_size font "IPAexゴシック,8" enhanced
set output '/dev/null'
plot #PLOT_PARAM#
Y_MIN = GPVAL_Y_MIN
Y_MAX = GPVAL_Y_MAX

set output '$pngf'
#ARROW#
plot #PLOT_PARAM#
exit
_EOD_

	#
	#	Gen Plot Param
	#
	my @p= ();
	my $pn = 0;

	open(CSV, $csvf) || die "cannot open $csvf";
	binmode(CSV, ":utf8");
	my $l = <CSV>;
	close(CSV);
	$l =~ s/[\r\n]+$//;
	my @label = split(/$dlm/, $l);
	#dp::dp "### $csvf: $l\n";
	#dp::dp "### $csvf\n";

	my $src_csv = $cdp->{src_csv} // "";
	my $y2_source = $gdp->{y2_source} // "";
	#dp::dp "soruce_csv[$src_csv] $y2_source\n";
	$src_csv = "" if($y2_source eq "");

	for(my $i = 1; $i <= $#label; $i++){
		my $graph = $gp->{graph} // ($gdp->{graph} // ($cdp->{graph} // $DEFAULT_GRAPH));
		my $y2_graph = "";
		my $key = $label[$i];
		$key =~ s/^[0-9]+://;
		$key =~ s/[']/_/g;	# avoid error at plot
		#dp::dp "### $i: $key\n";
		$pn++;

		my $axis = "";
		my $dot = "";
		if($y2_source ne ""){		#####
			#dp::dp "csv_source: $key [" . $src_csv->{$key} . "]\n";
			#dp::dp "csv_source: $key [" . $src_csv . "]\n";
			$axis =	"axis x1y1";
			#dp::dp "$src_csv->{$key},$y2_source:\n";
			if($src_csv && $src_csv->{$key} == $y2_source) {
				$axis = "axis x1y2" ;
				$dot = "dt (7,3)";
				$graph = $gp->{y2_graph} // ($gdp->{y2_graph} // ($cdp->{y2_graph} // $DEFAULT_GRAPH));
			}
		}
		#dp::dp "axis:[$axis]\n";
		#my $pl = sprintf("'%s' using 1:%d $axis with lines title '%d:%s' linewidth %d $dot", 
		#				$csvf, $i + 1, $i, $label[$i], ($pn < 7) ? 2 : 1);
		
		if($graph =~ /line/){
			$graph .= sprintf(" linewidth %d $dot ", ($pn < 7) ? 2 : 1);
		}
		elsif($graph =~ /box/){
			#dp::dp "BOX\n";
			$graph =~ s/box/box fill/ if(! ($graph =~ /fill/));
		}
		my $pl = sprintf("'%s' using 1:%d $axis with $graph title '%s' ", $csvf, $i + 1, $key);
		push(@p, $pl);
	}
	#push(@p, "0 with lines dt '-' title 'base line'");
	my $additional_plot = $gp->{additional_plot} // ($gdp->{additional_plot} // "");
    if($additional_plot){
        #dp::dp "additional_plot: " . $additional_plot . "\n";
		push(@p, $additional_plot);
    }

	my $plot = join(",", @p);
	$PARAMS =~ s/#PLOT_PARAM#/$plot/g;

	my $date_list = $cdp->{date_list};
	my $dt_start = $gp->{dt_start};
	my $dt_end = $gp->{dt_end};
	#dp::dp join(",", @$date_list) . "\n";
	#dp::dp "###" . join(",", $dt_start, $dt_end, $date_list->[$dt_start], $date_list->[$dt_end], scalar(@$date_list)) . "\n";
	if(1){
		my $RELATIVE_DATE = 7;
		my @aw = ();

		for(my $dn = $gp->{dt_end} - $RELATIVE_DATE; $dn > $gp->{dt_start}; $dn -= $RELATIVE_DATE){
			my $mark_date = $date_list->[$dn];
			
			#dp::dp "ARROW: $dn, [$mark_date]\n";
			my $a = sprintf("set arrow from '%s',Y_MIN to '%s',Y_MAX nohead lw 1 dt (3,7) lc rgb \"dark-red\"",
				$mark_date,  $mark_date);
			push(@aw, $a);
		}
		my $arw = join("\n", @aw);
		#dp::dp "ARROW: $arw\n";
		$PARAMS =~ s/#ARROW#/$arw/;	
	}

	open(PLOT, ">$plotf") || die "cannto create $plotf";
	binmode(PLOT, ":utf8");
	print PLOT $PARAMS;
	close(PLOT);

	#system("cat $plotf");
	#dp::dp "gnuplot $plotf\n";
	system("gnuplot $plotf");
	#dp::dp "-- Done\n";
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
