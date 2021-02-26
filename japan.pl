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



my @cdp_list = ($deftokyo::TOKYO_DEF, $defjapan::JAPAN_DEF, $deftkow::TKOW_DEF); 

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

	csv2graph::new($TOKYO_DEF); 						# Load Apple Mobility Trends
	csv2graph::load_csv($TOKYO_DEF);
	#my $y1 = {};
	#my $y2 = {};
	my $y1 = csv2graph::reduce_cdp_target($TOKYO_DEF, ["positive_count,negative_count"]);
	my $y2 = csv2graph::reduce_cdp_target($TOKYO_DEF, ["positive_rate"]);
	my $marge = csv2graph::marge_csv($y1, $y2);		# Gererate Graph

	my $tko_graph = [];
	my $tko_gpara01 = [
		{dsc => "Tokyo Positve/negative/rate", lank => [1,10], static => "", target_col => ["",""] },
		{dsc => "Tokyo Positve/negative/rate", lank => [1,10], static => "rlavr", target_col => ["",""] },
	];
	push(@$tko_graph , 
		csv2graph::csv2graph_list($marge, $TOKYO_GRAPH, $tko_gpara01));

	#	hospitalized,1,2,3,
	#	severe_case,1,2,3,
	csv2graph::new($TOKYO_ST_DEF); 						# Load Apple Mobility Trends
	csv2graph::load_csv($TOKYO_ST_DEF);
	my $y21 = csv2graph::reduce_cdp_target($TOKYO_ST_DEF, ["hospitalized"]);
	my $y22 = csv2graph::reduce_cdp_target($TOKYO_ST_DEF, ["severe_case"]);
	my $marge2 = csv2graph::marge_csv($y21, $y22);		# Gererate Graph

	my $tko_gpara02 = [
		{dsc => "Tokyo Positive Status 01", lank => [1,10], static => "", target_col => ["",""] },
		{dsc => "Tokyo Positive Status 02", lank => [1,10], static => "rlavr", target_col => ["",""] },
	];
	push(@$tko_graph , 
		csv2graph::csv2graph_list($marge2, $TOKYO_ST_GRAPH, $tko_gpara02));

	push(@$gp_list, @$tko_graph);
	csv2graph::gen_html_by_gp_list($tko_graph, {						# Generate HTML file with graphs
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
	csv2graph::new($JAPAN_DEF); 						# Load Apple Mobility Trends
	csv2graph::load_csv($JAPAN_DEF);
 	csv2graph::dump_cdp($JAPAN_DEF, {ok => 1, lines => 5, items => 10});               

	my $y2_graph = "line" ; # 'boxes fill', # 'boxes fill solid',

	#my $test_positive = csv2graph::reduce_cdp_target($JAPAN_DEF, {key => "testedPositive"});
	#my $deaths  = csv2graph::reduce_cdp_target($JAPAN_DEF, {key => "deaths"});
	#my $japan_def = csv2graph::marge_csv($deaths, $test_positive);	# Marge CCSE(ERN) and Apple Mobility Trends
 	#csv2graph::dump_cdp($japan_def, {ok => 1, lines => 5, items => 10});               

	my $jp_graph = [];
	my $an = 0;
	foreach my $area ("東京都", "千葉県", "埼玉県", "神奈川県", "茨城県"){
		my $test_positive = csv2graph::reduce_cdp_target($JAPAN_DEF, {item => "testedPositive,deaths", prefectureNameJ => $area});
#		my $test_positive_rlavr = csv2graph::reduce_cdp_target($JAPAN_DEF, {key => "testedPositive", prefectureNameJ => $area});
#		csv2graph::calc_items($test_positive, "avr", 
#					{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
#					{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
#		);
#		calc::comvert2rlavr($amt_country);							# rlavr for marge with CCSE
		calc::comvert2rlavr($test_positive, "rlavr");							# rlavr for marge with CCSE
 		csv2graph::dump_cdp($test_positive, {ok => 1, lines => 5, items => 10});               

#		my $deaths  = csv2graph::reduce_cdp_target($JAPAN_DEF, {key => "deaths", prefectureNameJ => $area});
#		my $deaths_rlavr  = csv2graph::reduce_cdp_target($JAPAN_DEF, {key => "deaths", prefectureNameJ => $area});
#		calc::comvert2rlavr($deaths_rlavr);							# rlavr for marge with CCSE
#		#my $japan_def = csv2graph::marge_csv($test_positive, $test_positive_rlavr, $deaths, $deaths_rlavr);	# Marge CCSE(ERN) and Apple Mobility Trends
#		my $japan_def = csv2graph::marge_csv($test_positive,  $deaths);	# Marge CCSE(ERN) and Apple Mobility Trends
# 		csv2graph::dump_cdp($japan_def, {ok => 1, lines => 5, items => 10});               

		my $params = [];
		foreach my $kind ("testedPositive", "deaths"){
			push(@$params, {dsc => "Japan $kind $area", lank => [1,10],  static => "", start_date => -90,
				target_col => {item => $kind, prefectureNameJ => $area},
				y2key => "deaths", y2label => 'DEATHS', y2min => 0, y2max => "", y2_graph => $y2_graph, # 'boxes fill solid',
				ykey => "testedPositive", ylabel => 'POSITIVE', ymin => 0, }
			);;
		}
		push(@$gp_list , 
				csv2graph::csv2graph_list($test_positive, $JAPAN_GRAPH, $params)); 
		$an++;
		#{dsc => "Japan TestPositive ", lank => [1,10], static => "rlavr", start_date => -90,
		#	target_col => {key => "testedPositive", prefectureNameJ => "千葉県,埼玉県"} },
		#{dsc => "Japan PeopleTested", lank => [1,10], static => "rlavr", target_col => {key => "peopleTested"} },
		#{dsc => "Japan hospitalized", lank => [1,10], static => "rlavr", target_col => {key => "hospitalized"} },
		#{dsc => "Japan serious", lank => [1,10], static => "rlavr", target_col => {key => "serious"} },
		#{dsc => "Japan discharged", lank => [1,10], static => "rlavr", target_col => {key => "discharged"} },
		#{dsc => "Japan deaths", lank => [1,10], static => "rlavr", target_col => {key => "deaths"} },
		#{dsc => "Japan ERN", lank => [1,10], static => "", target_col => {key => "effectiveReproductionNumber"}, 
		#{dsc => "Japan ERN", lank => [1,10], static => "", target_col => {key => "ern"}, 
		#		ymin => "",ymax => ""},
	}
	csv2graph::gen_html($JAPAN_DEF, $JAPAN_GRAPH, $jp_graph);		# Generate Graph/HTHML
}

#
#	Tokyo Weather
#
if($golist{tkow}){
	my $TKOW_DEF   = $deftkow::TKOW_DEF;
	my $TKOW_GRAPH = $deftkow::TKOW_GRAPH;

	csv2graph::new($TKOW_DEF); 						# Load Apple Mobility Trends
	csv2graph::load_csv($TKOW_DEF);

	my $tkow_graph = [
		{dsc => "気温 ", lank => [1,10], static => "", target_col => {key => "~気温"}},
		{dsc => "気温 ", lank => [1,10], static => "rlavr", target_col => {key => "~気温"}},
		{dsc => "平均気温 ", lank => [1,10], static => "", target_col => {key => "~平均気温"}},
		{dsc => "平均気温 ", lank => [1,10], static => "rlavr", target_col => {key => "~平均気温"}},
		{dsc => "平均湿度 ", lank => [1,10], static => "", target_col => {key => "~平均湿度"}},
		{dsc => "平均湿度 ", lank => [1,10], static => "rlavr", target_col => {key => "~平均湿度"}},
	];
	push(@$gp_list , 
		csv2graph::csv2graph_list($TKOW_DEF, $TKOW_GRAPH, $tkow_graph)); 
}

#
#	Generate HTML FILE
#
csv2graph::gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
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
