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

my $mainkey = $config::MAIN_KEY;

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

#
#	For CCSE, Johns holkins University
#
my @CCSE_TARGET_REGION = (
		"Canada", "Japan", "US,United States",
		"United Kingdom", "France", #"Spain", "Italy", "Russia", 
#			"Germany", "Poland", "Ukraine", "Netherlands", "Czechia,Czech Republic", "Romania",
#			"Belgium", "Portugal", "Sweden",
#		"India",  "Indonesia", "Israel", # "Iran", "Iraq","Pakistan",
#		"Brazil", "Colombia", "Argentina", "Chile", "Mexico", "Canada", 
#		"South Africa", 
);

#
#	Form Marge data (amt and ccse-ern)
#
my $MARGE_CSV_DEF = {
	id => "amt-ccse",
	title => "MARGED Apple and ERN pref",
	main_url =>  "Marged, no url",
	csv_file =>  "Marged, no csv file",
	src_url => 	"Marged, no src url",		# set
};


my %additional_plot_item = (
	amt => "100 axis x1y1 with lines title '100%' lw 1 lc 'blue' dt (3,7)",
	ern => "1 axis x1y2 with lines title 'ern=1' lw 1 lc 'red' dt (3,7)",
);
my $additional_plot = join(",", values %additional_plot_item);


my @TARGET_REGION = (
		"Japan", "US,United States",
		"United Kingdom", "France", "Spain", "Italy", "Russia", 
			"Germany", "Poland", "Ukraine", "Netherlands", "Czechia,Czech Republic", "Romania",
			"Belgium", "Portugal", "Sweden",
		"India",  "Indonesia", "Israel", # "Iran", "Iraq","Pakistan", different name between amt and ccse  
		"Brazil", "Colombia", "Argentina", "Chile", "Mexico", "Canada", 
		"South Africa", 
);

my @TARGET_PREF = ("Tokyo", "Kanagawa", "Chiba", "Saitama", "Kyoto", "Osaka");

my @cdp_list = ($defamt::AMT_DEF, $defccse::CCSE_CONF_DEF, $MARGE_CSV_DEF, 
					$deftokyo::TOKYO_DEF, $defjapan::JAPAN_DEF, $deftkow::TKOW_DEF); 

my $cmd_list = {"amt-jp" => 1, "amt-jp-pref" => 1, "tkow-ern" => 1, try => 1};

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
#	Load Johns Hoping Univercity CCSE
#
#	Province/State,Country/Region,Lat,Long,1/22/20
#
my $gp_list = [];
my $ccse_country = {};

#
#	Try for using 
#
#
if($golist{try}){
	my $ccse_cdp = csv2graph->new($defccse::CCSE_CONF_DEF); 						# Load Johns Hopkings University CCSE
	$ccse_cdp->load_csv($defccse::CCSE_CONF_DEF);
	$ccse_cdp->calc_items("sum", 
				{"Province/State" => "", "Country/Region" => "Canada"},				# All Province/State with Canada, ["*","Canada",]
				{"Province/State" => "null", "Country/Region" => "="}				# total gos ["","Canada"] null = "", = keep
	);
	my $ccse_country = $ccse_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country

	my $death_cdp = csv2graph->new($defccse::CCSE_DEATHS_DEF); 						# Load Johns Hopkings University CCSE
	$death_cdp->load_csv($defccse::CCSE_DEATHS_DEF);
	$death_cdp->calc_items("sum", 
				{"Province/State" => "", "Country/Region" => "Canada"},				# All Province/State with Canada, ["*","Canada",]
				{"Province/State" => "null", "Country/Region" => "="}				# total gos ["","Canada"] null = "", = keep
	);
	my $death_country = $death_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country


	my $prov = "Province/State";
	my $cntry = "Country/Region";
	my $graph_kind = $csv2graph::GRAPH_KIND;
	foreach my $region (@TARGET_REGION){
		my $y2y1rate = 2.5;
		foreach my $start_date (0, -93){
			my $p = {start_date => $start_date};
			my $conf_region = $ccse_country->reduce_cdp_target({$prov => "", $cntry => $region});
			my $y0max = $conf_region->max_val($p);

			$conf_region->rolling_average();
			my $y1max = $conf_region->max_val($p);
			my $y2max = int($y1max * $y2y1rate / 100 + 0.9999999); 
			my $ymax = csvlib::calc_max2($y1max);			# try to set reasonable max 
		
			my $death_region = $death_country->reduce_cdp_target({$prov => "", $cntry => $region});
			$death_region->rolling_average();
			my $death_max = $death_region->max_val($p);

			my $drate = sprintf("%.2f%%", 100 * $death_max / $y1max);
			#dp::dp "y0max:$y0max y1max:$y1max, ymax:$ymax, y2max:$y2max death_max:$death_max\n";

			push(@$gp_list, csv2graph->csv2graph_list_gpmix(
			{gdp => $defccse::CCSE_GRAPH, dsc => "[$region] new cases and deaths [$drate]", start_date => $start_date, 
				ymax => $ymax, y2max => $y2max, y2min => 0,
				ylabel => "confermed", y2label => "deaths (max=$y2y1rate% of rlavr confermed)",
				#additional_plot => $additional_plot_item{ern}, 
				graph_items => [
				{cdp => $ccse_country,  item => {$cntry => "$region",}, static => "rlavr", graph_def => $csv2graph::line_thick},
				{cdp => $death_country, item => {$cntry => "$region",}, static => "rlavr", axis => "y2", graph_def => $csv2graph::box_fill},
				{cdp => $ccse_country,  item => {$cntry => "$region",}, static => "", graph_def => $csv2graph::line_thin_dot,},
				{cdp => $death_country, item => {$cntry => "$region",}, static => "", axis => "y2", graph_def => $csv2graph::line_thin_dot},
				],
			},
			));
		}
		#last;
	}
}

#		{gdp => $AMT_GRAPH, start_date => -92, end_date => "",
#	_mix
#		{gdp => $AMT_GRAPH, start_date => -92, end_date => "",
#			dsc => "Japan Selected focus Pref $dt", lank => [1,10], static => $sts, 
#			graph_item => [
#				{cdp => $amt_pref, staic => "",
#						target_col => {country => "Japan", transportation_type => "average", region => "Japan,USA",}},
#				{cdp => $amt_pref, staic => "rlavr",
#						target_col => {country => "Japan rlavr", transportation_type => "average", region => "Japan,USA",}},
#				{cdp => $amt_pref, staic => "ern", axis => "y2",
#						target_col => {country => "Japan ern", transportation_type => "average", region => "Japan,USA",}},
#				{cdp => $ccse_ern, static => "ern", axis => "y2",
#						target_col => {country => "Japan", transportation_type => "average", region => "Japan,USA",}},
#			],
#		},
#
#
#
if($golist{ccse})
{
	my $ccse_cdp = csv2graph->new($defccse::CCSE_CONF_DEF); 							# Load Johns Hopkings University CCSE
	$ccse_cdp->load_csv($defccse::CCSE_CONF_DEF);
	$ccse_cdp->calc_items("sum", 
				{"Province/State" => "", "Country/Region" => "Canada"},		# All Province/State with Canada, ["*","Canada",]
				{"Province/State" => "null", "Country/Region" => "="}		# total gos ["","Canada"] null = "", = keep
	);
	my $ccse_country = $ccse_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country
	my $ccse_ern = $ccse_cdp->reduce_cdp_target({"Province/State" => "NULL"});		# Select Country
	$ccse_ern->calc_ern();

	my $prov = "Province/State";
	my $cntry = "Country/Region";
	push(@$gp_list, csv2graph->csv2graph_list_gpmix(
		{gdp => $defccse::CCSE_GRAPH, dsc => "Japan new cases and ern", start_date => 0, y2max => 3,
			additional_plot => $additional_plot_item{ern}, 
			graph_items => [
			{cdp => $ccse_ern, target_col => {$prov => "", $cntry => "Japan", calc => "RAW"}, static => ""},
			{cdp => $ccse_ern, target_col => {$prov => "", $cntry => "Japan", calc => "RAW"}, static => "rlavr"},
			{cdp => $ccse_ern, target_col => {$prov => "", $cntry => "Japan", calc => "ern"}, axis => "y2"},
			],
		},

		{gdp => $defccse::CCSE_GRAPH, dsc => "Japan new cases and ern from prov", start_date => 0, y2max => 3,
			additional_plot => $additional_plot_item{ern}, 
			graph_items => [
			{cdp => $ccse_country, target_col => {$prov => "", $cntry => "Japan,US",}, static => ""},
			{cdp => $ccse_country, target_col => {$prov => "", $cntry => "Japan,US",}, static => "rlavr"},
			{cdp => $ccse_country, target_col => {$prov => "", $cntry => "Japan,US",}, static => "ern", axis => "y2"},
			],
		},
		{gdp => $defccse::CCSE_GRAPH, dsc => "Japan new cases and ern from prov 3m", start_date => -91, y2max => 3,
			additional_plot => $additional_plot_item{ern}, 
			graph_items => [
			{cdp => $ccse_country, target_col => {$prov => "", $cntry => "Japan,US",}, static => ""},
			{cdp => $ccse_country, target_col => {$prov => "", $cntry => "Japan,US",}, static => "rlavr"},
			{cdp => $ccse_country, target_col => {$prov => "", $cntry => "Japan,US",}, static => "ern", axis => "y2"},
			],
		},
		{gdp => $defccse::CCSE_GRAPH, dsc => "Japan new cases and ern from prov 3m", start_date => 0, y2max => 3,
			graph_items => [
			{cdp => $ccse_country, target_col => {$prov => "",}, static => "", lank => [0,5]},
			],
		},
	));
}

#
# Load Apple Mobility Trends
#
#	geo_type,region,transportation_type,alternative_name,sub-region,country,2020-01-13,,,,
#
my $amt_country = {};		# for marge wtih ccse-ERN
my $amt_pref = {};
my $EU = "United Kingdom,France,Germany,Italy,Belgium,Greece,Spain,Sweden";
if($golist{amt}){

	my $AMT_DEF = $defamt::AMT_DEF;
	my $AMT_GRAPH = $defamt::AMT_GRAPH;

	my $amt_cdp = csv2graph->new($AMT_DEF); 										# Init AMD_DEF
	$amt_cdp->load_csv($AMT_DEF);									# Load to memory
	#$amt_cdp->dump({ok => 1, lines => 5});			# Dump for debug

	my $amt_country = $amt_cdp->reduce_cdp_target({geo_type => $REG});
	$amt_country->calc_items("avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);

	my $amt_pref = $amt_cdp->reduce_cdp_target({geo_type => $SUBR});
	$amt_pref->calc_items("avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);

	push(@$gp_list, csv2graph->csv2graph_list_gpmix(
		{gdp => $AMT_GRAPH, dsc => "Worldwide Apple Mobility Trends World Wilde", start_date => 0, 
			graph_items => [
			{cdp => $amt_country, static => ""},
			{cdp => $amt_country, static => "rlavr"},
			],
		},
		{gdp => $AMT_GRAPH, dsc => "Japan Apple Mobility Trends", start_date => 0, 
			graph_items => [
			{cdp => $amt_country, static => "", target_col => {region => "Japan",} ,},
			],
		},
		{gdp => $AMT_GRAPH, dsc => "EU Apple Mobility Trends", start_date => 0, 
			graph_items => [
			{cdp => $amt_country, static => "", target_col => {region => $EU, transportation_type => "avr"}, static => "rlavr"},
			],
		},
		{gdp => $AMT_GRAPH, dsc => "Japan Apple Mobility Trends Prefs", start_date => 0, 
			graph_items => [
			{cdp => $amt_pref, static => "", target_col => {country => "Japan", transportation_type => "avr"}, static => "rlavr"},
			],
		},
	));
}

#
#	geo_type,region,transportation_type,alternative_name,sub-region,country,2020-01-13,,,,
#
if($golist{"amt-jp"})
{

	my $AMT_DEF = $defamt::AMT_DEF;
	my $AMT_GRAPH = $defamt::AMT_GRAPH;

	#
	#	Load AMT
	#
	my $amt_cdp = csv2graph->new($defamt::AMT_DEF); 										# Init AMD_DEF
	$amt_cdp->load_csv($AMT_DEF);									# Load to memory
	#$amt_cdp->dump({ok => 1, lines => 5});			# Dump for debug

	my $amt_pref = $amt_cdp->reduce_cdp_target({geo_type => $SUBR});
	$amt_pref->calc_items("avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);
	$amt_pref->dump({ok => 1, lines => 5, search_key => "Japan"});			# Dump for debug

	
	my $prov = "Province/State";		# ccse
	my $cntry = "Country/Region";		# ccse
	foreach my $pref (@TARGET_PREF){			# Generate Graph Parameters
		foreach my $start (0, -62, -93){
			my $dt = "";
			$dt = "2m" if($start == -62);
			$dt = "3m" if($start == -93);
			push(@$gp_list, csv2graph->csv2graph_list_gpmix(
				{gdp => $AMT_GRAPH, dsc => "[$pref] Japan focus pref", start_date => $start, y2max => 3,
					graph_items => [
					#{cdp => $amt_pref, static => "",      target_col => {country => "Japan", transportation_type => $AVR, region => "~$pref"},},
					#{cdp => $amt_pref, static => "rlavr", target_col => {country => "Japan", transportation_type => $AVR, region => "~$pref"},},
					{cdp => $amt_pref, static => "",      target_col => {country => "Japan", region => "~$pref"},},
					{cdp => $amt_pref, static => "rlavr", target_col => {country => "Japan", region => "~$pref"},},
					],
				},
			));
		}
	}
}

#
#	Generate Marged Graph of Apple Mobility Trends and CCSE-ERN
#
if($golist{"amt-ccse"})
{
	#
	#	Apple Mobility Trends
	#
	my $AMT_DEF = $defamt::AMT_DEF;
	my $AMT_GRAPH = $defamt::AMT_GRAPH;

	my $amt_cdp = csv2graph->new($AMT_DEF); 										# Init AMD_DEF
	$amt_cdp->load_csv($AMT_DEF);									# Load to memory
	#$amt_cdp->dump({ok => 1, lines => 5});			# Dump for debug

	my $amt_country = $amt_cdp->reduce_cdp_target({geo_type => $REG});
	$amt_country->calc_items("avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);

	my $amt_pref = $amt_cdp->reduce_cdp_target({geo_type => $SUBR});
	$amt_pref->calc_items("avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);

	#
	#	CCSE
	#
	my $ccse_cdp = csv2graph->new($defccse::CCSE_CONF_DEF); 							# Load Johns Hopkings University CCSE
	$ccse_cdp->load_csv($defccse::CCSE_CONF_DEF);
	#$ccse_cdp->dump({ok => 1, lines => 1, items => 10, search_key => "Canada"}); # if($DEBUG);
	$ccse_cdp->calc_items("sum", 
				{"Province/State" => "", "Country/Region" => "Canada"},		# All Province/State with Canada, ["*","Canada",]
				{"Province/State" => "null", "Country/Region" => "="}		# total gos ["","Canada"] null = "", = keep
	);
	my $ccse_country = $ccse_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country
	#$ccse_country->dump({ok => 1, lines => 5, items => 10, search_key => "Canada"}); # if($DEBUG);
	
	#
	#	Marge amt and ccse, gen rlabr and erc
	#	geo_type,region,transportation_type,alternative_name,sub-region,country,2020-01-13,,,,
	#
	my $ccse_rlavr = $ccse_country->dup();

	my $prov = "Province/State";		# ccse
	my $cntry = "Country/Region";		# ccse
	foreach my $region (@TARGET_REGION){			# Generate Graph Parameters
		push(@$gp_list, csv2graph->csv2graph_list_gpmix(
			{gdp => $AMT_GRAPH, dsc => "Worldwide Apple Mobility Trends World Wilde and ccse ern $region", start_date => 0, y2max => 3,
				additional_plot => $additional_plot,
				graph_items => [
				{cdp => $ccse_country, static => "ern",   target_col => {$prov => "", $cntry => $region}, axis => "y2"},
				{cdp => $amt_country,  static => "rlavr", target_col => {region => $region,}},
				],
			},
		));
	}

}

#
#
#	geo_type,region,transportation_type,alternative_name,sub-region,country,2020-01-13,,,,
#
if($golist{"amt-jp-pref"}) {
	#
	#	Apple Mobility Trends
	#
	my $AMT_DEF = $defamt::AMT_DEF;
	my $AMT_GRAPH = $defamt::AMT_GRAPH;

	my $amt_cdp = csv2graph->new($AMT_DEF); 										# Init AMD_DEF
	#@{$amt_cdp->{key}} = ("alternative_name", "transportation_type");			# 5, 1, 2
	$amt_cdp->load_csv($AMT_DEF);									# Load to memory
	#$amt_cdp->dump({ok => 1, lines => 5});			# Dump for debug

	$amt_pref = $amt_cdp->reduce_cdp_target({geo_type => $SUBR, country => "Japan"});
	$amt_pref->calc_items("avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);
	#calc::comvert2rlavr($amt_pref);							# rlavr for marge with CCSE

	#
	#	Japan Prefecture Data
	# 	year,month,date,prefectureNameJ,prefectureNameE,mainkey
	#	y,m,d,東京,Tokyo,testedPositive,1,2,3,4,
	#	y,m,d,東京,Tokyo,peopleTested,1,2,3,4,
	#
	my $JAPAN_DEF = $defjapan::JAPAN_DEF;
	$JAPAN_DEF->{keys} = ["prefectureNameE"],		# PrefectureNameJ, and Column name
	my $JAPAN_GRAPH = $defjapan::JAPAN_GRAPH;

	my $jp_cdp = csv2graph->new($JAPAN_DEF); 						# Load Apple Mobility Trends
	$jp_cdp->load_csv($JAPAN_DEF);
	my $jp_positive = $jp_cdp->reduce_cdp_target({item => "testedPositive"});
 
	foreach my $pref (@TARGET_PREF){			# Generate Graph Parameters
		push(@$gp_list, csv2graph->csv2graph_list_gpmix(
			{gdp => $AMT_GRAPH, dsc => "Worldwide Apple Mobility Trends Japan and japan ern $pref", start_date => 0, y2max => 3,
				additional_plot => $additional_plot,
				graph_items => [
				{cdp => $jp_positive, static => "ern",   target_col => {prefectureNameE => "$pref"}, axis => "y2"},
				{cdp => $amt_pref,    static => "rlavr", target_col => {country => "Japan", region => "~$pref"},},
				],
			},
		));
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
	$tko_cdp->load_csv($TOKYO_DEF);
	$tko_cdp->calc_items("sum", 
				{mainkey => "positive_count,negative_count"}, # All Province/State with Canada, ["*","Canada",]
				{mainkey => "tested_count" },# total gos ["","Canada"] null = "", = keep
	);
# 	$tko_cdp->dump({ok => 1, lines => 5, items => 10});               

	my $tko_graph = [];
	push(@$tko_graph, 
		{gdp => $TOKYO_GRAPH, dsc => "Tokyo Postive/negative/rate ", graph => 'line', y2_graph => 'line',
			graph_items => [
				{cdp => $tko_cdp, static => "",      target_col => {mainkey => "positive_rate"}, axis => "y2"}, 
				{cdp => $tko_cdp, static => "rlavr", target_col => {mainkey => "positive_count,tested_count"}}, 
				{cdp => $tko_cdp, static => "",      target_col => {mainkey => "positive_count,tested_count"}}, 
		]}
	);

	#	hospitalized,1,2,3,
	#	severe_case,1,2,3,
	my $tkost_cdp = csv2graph->new($TOKYO_ST_DEF); 						# Load Apple Mobility Trends
	$tkost_cdp->load_csv($TOKYO_ST_DEF);
	push(@$tko_graph, 
		{gdp => $TOKYO_GRAPH, dsc => "Tokyo Postive staus", graph => 'line', y2_graph => 'line',
			graph_items => [
				{cdp => $tkost_cdp, static => "rlavr", target_col => {mainkey => "hospitalized"}}, 
				{cdp => $tkost_cdp, static => "rlavr", target_col => {mainkey => "severe_case"}, axis => "y2"}, 
				{cdp => $tkost_cdp, static => "",      target_col => {mainkey => "hospitalized"}}, 
				{cdp => $tkost_cdp, static => "",      target_col => {mainkey => "severe_case"}, axis => "y2"}, 
		]}
	);
	push(@$gp_list, csv2graph->csv2graph_list_gpmix(@$tko_graph));
}

#
#	Japan provience information from Tokyo Keizai
# year,month,date,prefectureNameJ,prefectureNameE,testedPositive,peopleTested,hospitalized,serious,discharged,deaths,effectiveReproductionNumber
# 2020,2,8,東京,Tokyo,3,,,,,,
#
#	y,m,d,東京,Tokyo,testedPositive,1,2,3,4,
#	y,m,d,東京,Tokyo,peopleTested,1,2,3,4,
#
#
#
if($golist{japan}){
	my $jp_cdp = csv2graph->new($defjapan::JAPAN_DEF); 						# Load Apple Mobility Trends
	$jp_cdp->load_csv($defjapan::JAPAN_DEF);
	$jp_cdp->dump({ok => 1, lines => 5});			# Dump for debug

	my $jp_graph = [];

	foreach my $pref ("東京都"){
		foreach my $item ("testedPositive", "deaths"){
			push(@$jp_graph, 
				{gdp => $defjapan::JAPAN_GRAPH, dsc => "Japan [$pref] $item ", start_date => 0, ymin => 0, y2max => 3, graph_items => [
						{cdp => $jp_cdp, static => "rlavr", target_col => {item => "$item", prefectureNameJ => $pref}}, 
						{cdp => $jp_cdp, static => "ern",   target_col => {item => "testedPositive", prefectureNameJ => $pref}, axis => "y2"}, 
						{cdp => $jp_cdp, static => "",      target_col => {item => "$item", prefectureNameJ => $pref}},
				]}
			);
		}
	}
	foreach my $item ("testedPositive", "peopleTested", "hospitalized", "serious", "discharged", "deaths", "effectiveReproductionNumber"){
		foreach my $static ("", "rlavr"){
			my $ymin = ($item eq "effectiveReproductionNumber") ? "" : 0;
			push(@$jp_graph, 
				{gdp => $defjapan::JAPAN_GRAPH, dsc => "Japan $item $static", start_date => 0, ymin => $ymin, graph_items => [
						{cdp => $jp_cdp, static => $static,      target_col => {item => "$item"}},
					#	{cdp => $jp_cdp, static => "rlavr", target_col => {item => "$item"}}, 
					#	{cdp => $jp_positive, static => "ern",   target_col => {prefectureNameE => "$pref"}, axis => "y2"},
				]}
			);
		}
	}

	push(@$gp_list, csv2graph->csv2graph_list_gpmix(@$jp_graph));
}

#
#	Tokyo Weather
#
if($golist{tkow}){
	my $TKOW_DEF   = $deftkow::TKOW_DEF;
	my $TKOW_GRAPH = $deftkow::TKOW_GRAPH;

	my $tkow_cdp = csv2graph->new($TKOW_DEF); 						# Load Apple Mobility Trends
	$tkow_cdp->load_csv($TKOW_DEF);

	my $tkow_graph = [];
	foreach my $static ("", "rlavr"){
		push(@$tkow_graph, 
			{gdp => $TKOW_GRAPH, dsc => "気温と湿度 $static ", start_date => 0, ymin => 0, 
				graph_items => [
					{cdp => $tkow_cdp, static => $static, target_col => {$mainkey => "~気温"}},
					{cdp => $tkow_cdp, static => $static, target_col => {$mainkey => "~湿度"}, axis => "y2"},
				],
			}
		);
	}
	push(@$gp_list, csv2graph->csv2graph_list_gpmix(@$tkow_graph));
}

#
#
#
if($golist{"tkow-ern"}) {
	#
	#	Tokyo Weather
	#
	my $tkow_cdp = csv2graph->new($deftkow::TKOW_DEF); 						# Load Apple Mobility Trends
	$tkow_cdp->load_csv($deftkow::TKOW_DEF);

	#
	#	Japan
	#
	my $jp_cdp = csv2graph->new($defjapan::JAPAN_DEF); 						# Load Apple Mobility Trends
	$jp_cdp->load_csv($defjapan::JAPAN_DEF);
	$jp_cdp->dump({ok => 1, lines => 5});			# Dump for debug


	my $pref = "東京";
	foreach my $weather ("気温", "湿度"){			# Generate Graph Parameters
		foreach my $static ("ern", "rlavr", ""){
			my $y2max = ($static eq "ern") ? 3 : "";
			push(@$gp_list, csv2graph->csv2graph_list_gpmix(
				{gdp => $deftkow::TKOW_GRAPH, dsc => "Weather and ERN $pref $weather $static", start_date => 0, ymax => "", y2max => $y2max,
					additional_plot => $additional_plot_item{ern},
					graph_items => [
					{cdp => $jp_cdp,  static => $static,   target_col => {prefectureNameJ => "~$pref", item => "testedPositive"}, axis => "y2"},
					{cdp => $tkow_cdp,static => "rlavr", target_col => {$mainkey => "~$weather"},},
					],
				},
			));
		}
	}
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
