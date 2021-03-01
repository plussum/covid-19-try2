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
#	CSV_DEF
#		src_url => source_url of data,
#		src_csv => download csv data,
#		keys => [1, 2],		# region, transport
#		date_start => 6,	# 2020/01/13
#		html_title => "Apple Mobility Trends",
#	GRAPH_PARAMN
#		dsc => "Japan"
#		lank => [1,999],
#		graph => "LINE | BOX",
#		statics => "RLAVR",
#		target_area => "Japan,XXX,YYY", 
#		exclusion_are => ""
#
#
use strict;
use warnings;
use utf8;
use Encode 'decode';
use Data::Dumper;
use config;
use csvlib;
use csv2graph;
use dp;

use defamt;
use defccse;
use defjapan;
use deftokyo;
use deftkow;


binmode(STDOUT, ":utf8");

my $VERBOSE = 0;
my $DOWN_LOAD = 0;

my $WIN_PATH = $config::WIN_PATH;
my $HTML_PATH = "$WIN_PATH/HTML2",
my $PNG_PATH  = "$WIN_PATH/PNG2",
my $PNG_REL_PATH  = "../PNG2",
my $CSV_PATH  = $config::WIN_PATH;

my $DEFAULT_AVR_DATE = 7;
my $END_OF_DATA = "###EOD###";

my $gp_list = [];

#
#	for APPLE Mobility Trends
#
my $SRC_URL_TAG = "https://covid19-static.cdn-apple.com/covid19-mobility-data/2025HotfixDev13/v3/en-us/applemobilitytrends-%04d-%02d-%02d.csv";
my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $src_url = sprintf($SRC_URL_TAG, $year + 1900, $mon + 1, $mday);
my $ern_adp	= "1 with lines title 'ern=1' lw 1 lc 'red' dt (3,7)";

my $REG = $defamt::REG;
my $SUBR = $defamt::SUBR;
my $CITY = $defamt::CITY;
my $DRV = $defamt::DRV;
my $TRN = $defamt::TRN;
my $WLK = $defamt::WLK;
my $AVR = $defamt::AVR;



my %additional_plot_item = (
	amt => "100 axis x1y1 with lines title '100%' lw 1 lc 'blue' dt (3,7)",
	ern => "1 axis x1y2 with lines title 'ern=1' lw 1 lc 'red' dt (3,7)",
);
my $additional_plot = join(",", values %additional_plot_item);



my @cdp_list = ($deftokyo::TOKYO_DEF, $defjapan::JAPAN_DEF, $deftkow::TKOW_DEF, $defccse::CCSE_DEF); 

my $cmd_list = {}; # "amt-jp" => 1, "amt-jp-pref" => 1, "tkow-ern" => 1};

####################################
#
#	Start Main
#
####################################
my %golist = ();
my $all = "";
if($#ARGV >= 0){
	for(@ARGV){
		if(/-all/){
			$all = 1;
			last;
		}
		if(/^-clear/){
			dp::dp "Remove .png and other plot data: $PNG_PATH\n";
			system("ls $PNG_PATH | head");
			#dp::dp "Remove OK? (YES/no)";
			#my $ok = <STDIN>;
			my $ok = "YES";
			if(!($ok =~ /no/i)){
				system("rm $PNG_PATH/*");
			}
			exit;
		}
		if($cmd_list->{$_}){
			$golist{$_} = 1;
			next;
		}
		foreach my $cdp (@cdp_list){
			if($cdp->{id} eq $_){
				$golist{$_} = 1 
			}
		}
		if(! (defined $golist{$_})){
			dp::dp "Undefined dataset [$_]\n";
		}
	}
}
else {
	my @ids = ();
	foreach my $cdp (@cdp_list){
		my $id = $cdp->{id};
		push(@ids, $id);
	}
	dp::dp "usage:$0 " . join(" | ", "-all", @ids, keys %$cmd_list) ."\n";
	exit;
}
#if($golist{"amt-ccse"}){
#	$golist{amt} = 1;
#	$golist{ccse} = 1;
#}
if($all){
	foreach my $cdp (@cdp_list){
		my $id = $cdp->{id};
		$golist{$id} = 1 ;
	}
	foreach my $id (keys %$cmd_list){
		$golist{$id} = 1 ;
	}
}

#
#	Generate Graph
#
#	positive_count,1,2,3,
#	negative_count,1,2,3,
#	positive_rate,1,2,3,
#
if($golist{"tokyo"}){
	my $TOKYO_DEF = $deftokyo::TOKYO_DEF;
	my $TOKYO_GRAPH = $deftokyo::TOKYO_GRAPH;
	my $TOKYO_ST_DEF = $deftokyo::TOKYO_ST_DEF;
	my $TOKYO_ST_GRAPH = $deftokyo::TOKYO_ST_GRAPH;

	my $tko_cdp = csv2graph->new($TOKYO_DEF); 						# Load Apple Mobility Trends
	$tko_cdp->load_csv();
	$tko_cdp->calc_items("sum", 
				{mainkey => "positive_count,negative_count"}, # All Province/State with Canada, ["*","Canada",]
				{mainkey => "tested_count" },# total gos ["","Canada"] null = "", = keep
	);
# 	$tko_cdp->dump({ok => 1, lines => 5, items => 10});               

	my $y2_graph = "line" ; # 'boxes fill', # 'boxes fill solid',
	my $tko_gpara01 = [
		{dsc => "Tokyo Positve/negative/rate", lank => [1,10], static => "", 
			target_col => {mainkey =>"tested_count,positive_count,positive_rate"},
			y2key => "positive_rate", y2label => "rate", y2min => 0, y2max => "", y2_grap => $y2_graph,
			ykey => "", ylabel => 'Number of cases', ymin => 0, },
		{dsc => "Tokyo Positve/negative/rate", lank => [1,10], static => "rlavr", 
			target_col => {mainkey =>"tested_count,positive_count,positive_rate"},
			y2key => "rate", y2label => "rate", y2min => 0, y2max => "", y2_grap => $y2_graph,
			ykey => "", ylabel => 'Number of cases', ymin => 0, },
	];

	my $tko_graph = [];
	push(@$tko_graph , 
		$tko_cdp->csv2graph_list($TOKYO_GRAPH, $tko_gpara01));

	#	hospitalized,1,2,3,
	#	severe_case,1,2,3,
	my $st_cdp = csv2graph->new($TOKYO_ST_DEF); 						# Load Apple Mobility Trends
	$st_cdp->load_csv();
	my $tko_gpara02 = [
		{dsc => "Tokyo Positive Status 01", lank => [1,10], static => "", target_col => [],
				y2key => "severe", y2label => "severe_case", y2min => 0, y2max => "", y2_grap => $y2_graph, },
		{dsc => "Tokyo Positive Status 02", lank => [1,10], static => "rlavr", target_col => [],
				y2key => "severe", y2label => "severe_case", y2min => 0, y2max => "", y2_grap => $y2_graph, },
	];
	push(@$tko_graph , 
		$st_cdp->csv2graph_list($TOKYO_ST_GRAPH, $tko_gpara02));

	push(@$gp_list, @$tko_graph);
	csv2graph->gen_html_by_gp_list($tko_graph, {						# Generate HTML file with graphs
			html_tilte => "Tokyo Open Data",
			src_url => $TOKYO_DEF->{src_url} // "src_url",
			html_file => "$HTML_PATH/tokyo_opendata.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $TOKYO_DEF->{data_source} // "data_source",
			dst_dlm => $TOKYO_GRAPH->{dst_dlm} // "dst_dlm",
		}
	);
}

#
#	Japan provience information from Tokyo Keizai
# year,month,date,prefectureNameJ,prefectureNameE,testedPositive,peopleTested,hospitalized,serious,discharged,deaths,effectiveReproductionNumber
# 2020,2,8,東京,Tokyo,3,,,,,,
#
# 	year,month,date,prefectureNameJ,prefectureNameE,
#	y,m,d,東京,Tokyo,testedPositive,1,2,3,4,
#	y,m,d,東京,Tokyo,peopleTested,1,2,3,4,
#
#
if($golist{japan}){
	my $JAPAN_DEF = $defjapan::JAPAN_DEF;
	my $JAPAN_GRAPH = $defjapan::JAPAN_GRAPH;

	my $japan_def = csv2graph->new($JAPAN_DEF); 						# Load Apple Mobility Trends
	$japan_def->load_csv($JAPAN_DEF);
 	#$japan_def->dump_cdp({ok => 1, lines => 5, items => 10});               

	my $y2_graph = "line" ; # 'boxes fill', # 'boxes fill solid',
	my $jp_graph = [];
	my $an = 0;
	foreach my $area ("東京都", "千葉県", "埼玉県", "神奈川県", "茨城県"){
		my $test_positive = $japan_def->reduce_cdp_target({item => "testedPositive,deaths", prefectureNameJ => $area});
		$test_positive->calc_rlavr();							# rlavr for marge with CCSE
 		#$test_positive->dump_cdp({ok => 1, lines => 5, items => 10});               

		my $params = [];
		foreach my $kind ("testedPositive,deaths"){
			push(@$params, {dsc => "Japan $kind $area", lank => [1,10],  static => "", start_date => -90,
				#target_col => {item => $kind, prefectureNameJ => $area},
				y2key => "deaths", y2label => 'DEATHS', y2min => 0, y2max => "", y2_graph => $y2_graph, # 'boxes fill solid',
				ykey => "testedPositive", ylabel => 'POSITIVE', ymin => 0, }
			);
		}
		push(@$gp_list, $test_positive->csv2graph_list($JAPAN_GRAPH, $params)); 
		$an++;
	}
	$japan_def->gen_html($JAPAN_GRAPH, $jp_graph);		# Generate Graph/HTHML
}

#
#	Tokyo Weather
#
if($golist{tkow}){
	my $TKOW_DEF   = $deftkow::TKOW_DEF;
	my $TKOW_GRAPH = $deftkow::TKOW_GRAPH;

	my $tkow_cdp = csv2graph->new($TKOW_DEF); 						# Load Apple Mobility Trends
	$tkow_cdp->load_csv();
	$tkow_cdp->calc_rlavr();			# rlavr for marge with CCSE

	my $y2_graph = "line" ; # line 'boxes fill', # 'boxes fill solid',
	my $tkow_graph = [
		{dsc => "気温と湿度", lank => [1,10], static => "", target_col => {mainkey => "~平均気温,~平均湿度"},
			y2key => "湿度", y2label => "湿度", y2min => 0, y2max => "", y2_graph => $y2_graph,
			ylabel => "温度", ymin => 0, ymax => "" },
		{dsc => "気温 RAW", lank => [1,10], static => "", target_col => {mainkey => "~気温", calc => "RAW"},},
		{dsc => "気温 RLAVR", lank => [1,10], static => "", target_col => {mainkey => "~気温", calc => "rlavr"},},
		{dsc => "平均気温 ", lank => [1,10], static => "", target_col => {mainkey => "~平均気温"}},
		{dsc => "平均湿度 ", lank => [1,10], static => "", target_col => {mainkey => "~平均湿度"}},
	];
	push(@$gp_list , 
		$tkow_cdp->csv2graph_list($TKOW_GRAPH, $tkow_graph)); 
}
#
#	Load Johns Hoping Univercity CCSE
#
#	Province/State,Country/Region,Lat,Long,1/22/20
#
if($golist{ccse}){
	my @TARGET_REAGION = (
			"Japan", "US,United States",
			"United Kingdom", "France", #"Spain", "Italy", "Russia", 
	#			"Germany", "Poland", "Ukraine", "Netherlands", "Czechia,Czech Republic", "Romania",
	#			"Belgium", "Portugal", "Sweden",
	#		"India",  "Indonesia", "Israel", # "Iran", "Iraq","Pakistan",
	#		"Brazil", "Colombia", "Argentina", "Chile", "Mexico", "Canada", 
	#		"South Africa", 
	);

	my $CCSE_DEF = $defccse::CCSE_DEF;
	my $CCSE_GRAPH = $defccse::CCSE_GRAPH;

	my $ccse_cdp = csv2graph->new($CCSE_DEF); 							# Load Johns Hopkings University CCSE
	$ccse_cdp->load_csv();
	#$ccse_cdp->dump({ok => 1, lines => 1, items => 10, search_key => "Canada"}); # if($DEBUG);
	$ccse_cdp->calc_items("sum", 
				{"Province/State" => "", "Country/Region" => "Canada"},		# All Province/State with Canada, ["*","Canada",]
				{"Province/State" => "null", "Country/Region" => "="}		# total gos ["","Canada"] null = "", = keep
	);
	#$ccse_cdp->dump({ok => 1, lines => 5, items => 10, search_key => "Canada"}); # if($DEBUG);
	my $ccse_country = $ccse_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country
	my $ccse_ern = $ccse_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country
	$ccse_ern->calc_ern();			# ern for marge with CCSE
	$ccse_ern->dump({ok => 1, lines => 5, items => 10, search_key => "Japan"}); # if($DEBUG);

	$ccse_country->{src_info} .= "-- reduced";
	#csv2graph::dump_cdp($ccse_country, {ok => 1, lines => 5, items => 10, search_key => "Japan"}); # if($DEBUG);
	my $gp = []; 
	my $prov = "Province/State";
	my $cntry = "Country/Region";
	foreach my $reagion (@TARGET_REAGION){
		foreach my $static ("", "rlavr", "ern"){
			push (@$gp, {
				dsc => "CCSE $reagion", lank => [1,10], static => $static,
				target_col => {$prov => "NULL", $cntry => "$reagion"},	# Country only
				}
			);
		}
	}

	my $ccse_graph_01 = [
		{dsc => "Japan ", lank => [1,10], static => "rlavr", target_col => {"$prov" => "", "$cntry" => "Japan", calc => "RAW"}},
		{dsc => "Canada ", lank => [1,10], static => "rlavr", target_col => {"$prov" => "", "$cntry" => "Canada"}},
	#	{dsc => "Japan top 10", lank => [1,10], static => "rlavr", target_col => {"$prov" => "", "$cntry" => "Japan"}},
		{dsc => "World Wild ", lank => [1,10], static => "rlavr", target_col => {"$prov" => "", "$cntry" => ""}},
		{dsc => "World Wild ", lank => [11,20], static => "rlavr", target_col => {"$prov" => "", "$cntry" => ""}},
	];

	push(@$gp_list,
		 $ccse_ern->csv2graph_list($CCSE_GRAPH, [
			{dsc => "Japan ern", lank => [1,10], target_col => {$prov => "", $cntry => "Japan", calc => "ern"}}]));

	push(@$gp_list,
		 $ccse_country->csv2graph_list($CCSE_GRAPH, [@$ccse_graph_01, @$gp])); 
}

#
#	Generate HTML FILE
#
csv2graph->gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
		html_tilte => "COVID-19 related data visualizer ",
		src_url => "src_url",
		html_file => "$HTML_PATH/csv2graph_index.html",
		png_path => $PNG_PATH // "png_path",
		png_rel_path => $PNG_REL_PATH // "png_rel_path",
		data_source => "data_source",
	}
);

#
#	Down Load CSV 
#
sub	download
{
	my ($cdp) = @_;
	return 1;
}


#
#
#
sub	test_seach_list
{
	my @skeys = (
		["Japan", "~Japan-"],
		["United Kingdom", "United Kingdom-"],
	);
	my @items = ("Japan", "Japan-", "United State", "United Kingdom-Falkland Islands");
	foreach my $item ("Japan", "Japan-", "United State"){
		for my $skey (@skeys){
			dp::dp csvlib::search_listn($item, @$skey) . "[$item]" . join(",", @$skey) . "\n";
		}
	}
}
