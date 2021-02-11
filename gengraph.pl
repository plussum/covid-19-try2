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
my @CCSE_TARGET_REAGION = (
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


my @TARGET_REAGION = (
		"Japan", "US,United States",
		"United Kingdom", "France", #"Spain", "Italy", "Russia", 
#			"Germany", "Poland", "Ukraine", "Netherlands", "Czechia,Czech Republic", "Romania",
#			"Belgium", "Portugal", "Sweden",
#		"India",  "Indonesia", "Israel", # "Iran", "Iraq","Pakistan",
#		"Brazil", "Colombia", "Argentina", "Chile", "Mexico", "Canada", 
#		"South Africa", 
);


my @cdp_list = ($defamt::AMT_DEF, $defccse::CCSE_DEF, $MARGE_CSV_DEF, 
					$deftokyo::TOKYO_DEF, $defjapan::JAPAN_DEF, $deftkow::TKOW_DEF); 

my $cmd_list = {"amt-jp" => 1, "amt-jp-pref" => 1, "tkow-ern" => 1};

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
}

#
#	Load Johns Hoping Univercity CCSE
#
#	Province/State,Country/Region,Lat,Long,1/22/20
#
my $gp_list = [];
my $ccse_country = {};
if($golist{ccse}){
	my $CCSE_DEF = $defccse::CCSE_DEF;
	my $CCSE_GRAPH = $defccse::CCSE_GRAPH;
	csv2graph::new($defccse::CCSE_DEF); 							# Load Johns Hopkings University CCSE
	csv2graph::load_csv($defccse::CCSE_DEF);
	#csv2graph::dump_cdp($CCSE_DEF, {ok => 1, lines => 1, items => 10, search_key => "Canada"}); # if($DEBUG);
	csv2graph::calc_items($CCSE_DEF, "sum", 
				{"Province/State" => "", "Country/Region" => "Canada"},		# All Province/State with Canada, ["*","Canada",]
				{"Province/State" => "null", "Country/Region" => "="}		# total gos ["","Canada"] null = "", = keep
	);
	$ccse_country = csv2graph::reduce_cdp_target($CCSE_DEF, {"Province/State" => "NULL"});	# Select Country
	#csv2graph::dump_cdp($ccse_country, {ok => 1, lines => 5, items => 10, search_key => "Canada"}); # if($DEBUG);

	$ccse_country->{src_info} .= "-- reduced";
	#csv2graph::dump_cdp($ccse_country, {ok => 1, lines => 5, items => 10, search_key => "Japan"}); # if($DEBUG);
	my $gp = []; 
	my $prov = "Province/State";
	my $cntry = "Country/Region";
	foreach my $reagion (@TARGET_REAGION){
		push (@$gp, {
				dsc => "CCSE $reagion",
				lank => [1,10],
				static => "",
				target_col => {$prov => "NULL", $cntry => $reagion},	# Country only
			}
		);
		push (@$gp, {
				dsc => "CCSE $reagion",
				lank => [1,10],
				static => "rlavr",
				target_col => {$prov => "NULL", $cntry => $reagion},	# Country only
			}
		);
	}

	my $ccse_graph_01 = [
		{dsc => "Japan ", lank => [1,10], static => "rlavr", target_col => {"$prov" => "", "$cntry" => "Japan"}},
		{dsc => "Canada ", lank => [1,10], static => "rlavr", target_col => {"$prov" => "", "$cntry" => "Canada"}},
	#	{dsc => "Japan top 10", lank => [1,10], static => "rlavr", target_col => {"$prov" => "", "$cntry" => "Japan"}},
		{dsc => "World Wild ", lank => [1,10], static => "rlavr", target_col => {"$prov" => "", "$cntry" => ""}},
		{dsc => "World Wild ", lank => [11,20], static => "rlavr", target_col => {"$prov" => "", "$cntry" => ""}},
	];

	push(@$ccse_graph_01, @$gp);
	push(@$gp_list,
		 csv2graph::csv2graph_list($ccse_country, $CCSE_GRAPH, $ccse_graph_01)); 
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

	csv2graph::new($defamt::AMT_DEF); 										# Init AMD_DEF
	csv2graph::load_csv($AMT_DEF);									# Load to memory
	#csv2graph::dump_cdp($AMT_DEF, {ok => 1, lines => 5});			# Dump for debug

	$amt_country = csv2graph::reduce_cdp_target($AMT_DEF, {geo_type => $REG});
	csv2graph::calc_items($amt_country, "avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);

	$amt_pref = csv2graph::reduce_cdp_target($AMT_DEF, {geo_type => $SUBR});
	csv2graph::calc_items($amt_pref, "avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);
	push(@$gp_list , csv2graph::csv2graph_list_mix( 
		{cdp => $amt_country, gdp => $AMT_GRAPH, 
			dsc => "Worldwide Apple Mobility Trends World Wilde", lank => [1,10], static => "", },
		{cdp => $amt_country, gdp => $AMT_GRAPH, 
			dsc => "Worldwide Apple Mobility Trends World Wilde average", lank => [1,10], static => "rlavr", 
			target_col => {transportation_type => $AVR}, },
		{cdp => $amt_country, gdp => $AMT_GRAPH,
			dsc => "Japan Apple Mobility Trends Japan", lank => [1,10], static => "rlavr", 
			target_col => {region => "Japan",} ,},

		{cdp => $amt_country, gdp => $AMT_GRAPH, 
			dsc => "(a part of) EU mobility States.", lank => [1,10], static => "rlavr", 
			target_col => { region => $EU, transportation_type => "avr"},},
		{cdp => $amt_pref, gdp => $AMT_GRAPH, 
			dsc => "Worldwide Apple mobility Japan Pref.", lank => [1,10], static => "rlavr", 
			target_col => {country => "Japan", transportation_type => "avr"}},
		{cdp => $amt_pref, gdp => $AMT_GRAPH,
			dsc => "United State mobility.", lank => [1,10], static => "rlavr", 
			target_col => {country => "United States", transportation_type => "avr"},},
	));
	#dp::dp "-" x 20 . "\n";

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
	csv2graph::new($defamt::AMT_DEF); 										# Init AMD_DEF
	csv2graph::load_csv($AMT_DEF);									# Load to memory
	#csv2graph::dump_cdp($AMT_DEF, {ok => 1, lines => 5});			# Dump for debug

	$amt_pref = csv2graph::reduce_cdp_target($AMT_DEF, {geo_type => $SUBR});
	csv2graph::calc_items($amt_pref, "avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);
	csv2graph::dump_cdp($amt_pref, {ok => 1, lines => 5, search_key => "Japan"});			# Dump for debug
	my @target_pref = ("Tokyo", "Kanagawa", "Chiba", "Saitama", "Kyoto", "Osaka");

	my $gp_pref = [];
	
	my $tgs = "";
	foreach my $rg (@target_pref){
		$tgs .= "~$rg,";
	}
	$tgs =~ s/,$//;
	foreach my $start (0, -62, -93){
		my $dt = "";
		$dt = "2m" if($start == -62);
		$dt = "3m" if($start == -93);
		foreach my $sts ("", "rlavr"){
			push(@$gp_pref, 
				{cdp => $amt_pref, gdp => $AMT_GRAPH, start_date => $start,
					dsc => "Japan Selected focus Pref $dt", lank => [1,10], static => $sts, 
							target_col => {country => "Japan", transportation_type => $AVR, region => "$tgs",}
				},
			);
		}
	}

	foreach my $rg (@target_pref){
		foreach my $sts ("", "rlavr"){
			push(@$gp_pref, 
				{
					cdp => $amt_pref, gdp => $AMT_GRAPH, start_date => -62,
					dsc => "[$rg] Apple mobility Trends months", lank => [1,10], static => $sts, 
					target_col => {country => "Japan", region => "~$rg",}
				}
			);
		}
	}

	foreach my $start (0, -62, -93){
		my $dt = "";
		$dt = "2m" if($start == -62);
		$dt = "3m" if($start == -93);
		foreach my $sts ("", "rlavr"){
			my $w = 5;
			for(my $s = 1; $s <= 10; $s+= $w){
				my $e = $s + $w - 1;

				push(@$gp_pref, {
					cdp => $amt_pref, gdp => $AMT_GRAPH, start_date => $start,
					dsc => "Japan $s-$e $dt ", lank => [$s,$e], static => $sts, 
					target_col => {country => "Japan", transportation_type => $AVR},},
				);
			}
		}
	}

#	push(@$gp_pref,
#		{cdp => $amt_pref, gdp => $AMT_GRAPH, 
#			dsc => "Tokyo  01-05", lank => [1,5], static => "", 
#			target_col => {country => "Japan", transportation_type => $AVR},},
#		{cdp => $amt_pref, gdp => $AMT_GRAPH, 
#			dsc => "Japan Pref 06-10", lank => [6,10], static => "", 
#			target_col => {country => "Japan", transportation_type => $AVR},},
#
#		{cdp => $amt_pref, gdp => $AMT_GRAPH, 
#			dsc => "Japan Pref 01-05", lank => [1,5], static => "rlavr", 
#			target_col => {country => "Japan", transportation_type => $AVR},},
#		{cdp => $amt_pref, gdp => $AMT_GRAPH, 
#			dsc => "Japan Pref 06-10", lank => [6,10], static => "rlavr", 
#			target_col => {country => "Japan", transportation_type => $AVR},},
#
#		{cdp => $amt_pref, gdp => $AMT_GRAPH, start_date => -62,
#			dsc => "Japan Pref Apple mobility Trends months", lank => [1,10], static => "rlavr", 
#			target_col => {country => "Japan", transportation_type => $AVR},},
#		{cdp => $amt_pref, gdp => $AMT_GRAPH, start_date => -62,
#			dsc => "Japan Pref Apple mobility Trends months", lank => [1,10], static => "", 
#			target_col => {country => "Japan", transportation_type => $AVR},},
#	);

	push(@$gp_list , csv2graph::csv2graph_list_mix(@$gp_pref));
}

#
#	Generate Marged Graph of Apple Mobility Trends and CCSE-ERN
#
if($golist{"amt-ccse"}){
	#
	#	Apple Mobility Trends
	#
	my $AMT_DEF = $defamt::AMT_DEF;
	my $AMT_GRAPH = $defamt::AMT_GRAPH;

	csv2graph::new($defamt::AMT_DEF); 										# Init AMD_DEF
	csv2graph::load_csv($AMT_DEF);									# Load to memory
	#csv2graph::dump_cdp($AMT_DEF, {ok => 1, lines => 5});			# Dump for debug

	$amt_country = csv2graph::reduce_cdp_target($AMT_DEF, {geo_type => $REG});
	csv2graph::calc_items($amt_country, "avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);
	calc::comvert2rlavr($amt_country);							# rlavr for marge with CCSE

	$amt_pref = csv2graph::reduce_cdp_target($AMT_DEF, {geo_type => $SUBR});
	csv2graph::calc_items($amt_pref, "avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);
	calc::comvert2rlavr($amt_pref);							# rlavr for marge with CCSE

	#
	#	CCSE
	#
	my $CCSE_DEF = $defccse::CCSE_DEF;
	my $CCSE_GRAPH = $defccse::CCSE_GRAPH;

	csv2graph::new($defccse::CCSE_DEF); 							# Load Johns Hopkings University CCSE
	csv2graph::load_csv($defccse::CCSE_DEF);
	#csv2graph::dump_cdp($CCSE_DEF, {ok => 1, lines => 1, items => 10, search_key => "Canada"}); # if($DEBUG);
	csv2graph::calc_items($CCSE_DEF, "sum", 
				{"Province/State" => "", "Country/Region" => "Canada"},		# All Province/State with Canada, ["*","Canada",]
				{"Province/State" => "null", "Country/Region" => "="}		# total gos ["","Canada"] null = "", = keep
	);
	$ccse_country = csv2graph::reduce_cdp_target($CCSE_DEF, {"Province/State" => "NULL"});	# Select Country
	#csv2graph::dump_cdp($ccse_country, {ok => 1, lines => 5, items => 10, search_key => "Canada"}); # if($DEBUG);
	
	#
	#	Marge amt and ccse, gen rlabr and erc
	#
	my $ccse_rlavr = csv2graph::dup_cdp($ccse_country);

	#	Rolling Average
	$ccse_rlavr = csv2graph::comvert2rlavr($ccse_country);					# Calc Rooling Average
	my $ccse_amt_rlavr = csv2graph::marge_csv($ccse_rlavr, $amt_country);	# Marge CCSE and Apple Mobility Trends
	#	set infomation for graph
	$ccse_amt_rlavr->{id} = "amt-ccse-rlavr";
	$ccse_amt_rlavr->{src_info} = "(rlavr)Apple Mobility Trends and Johns Hokings Univ.";
	$ccse_amt_rlavr->{main_url} = "please reffer amt and ccse";
	$ccse_amt_rlavr->{csv_file} = "please reffer amt and ccse";
	$ccse_amt_rlavr->{src_url} =  "please reffer amt and ccse";	

	#	ERN
	$ccse_country = csv2graph::comvert2ern($ccse_country);					# Calc ERN
	my $ccse_amt_ern = csv2graph::marge_csv($ccse_country, $amt_country);	# Marge CCSE(ERN) and Apple Mobility Trends
	$ccse_amt_ern->{id} = "amt-ccse-ern";
	$ccse_amt_ern->{src_info} = "(ern)Apple Mobility Trends and Johns Hokings Univ.";
	$ccse_amt_ern->{main_url} = "please reffer amt and ccse";
	$ccse_amt_ern->{csv_file} = "please reffer amt and ccse";
	$ccse_amt_ern->{src_url} =  "please reffer amt and ccse";	

	#csv2graph::dump_cdp($ccse_amt, {ok => 1, lines => 5});

	my $MARGE_GRAPH_PARAMS = {
		html_title => "MARGE Apple Mobility Trends and ERN",
		png_path   => $PNG_PATH,
		png_rel_path => $PNG_REL_PATH,
		html_file => "$HTML_PATH/applemobile_ern.html",

		y2label => 'ERN', y2min => 0, y2max => 3, y2_source => 0,		# soruce csv definition for y2
		ylabel => '%', ymin => 0,
		additional_plot => $additional_plot,
	};

	#
	#	Generate Graph Pamaters
	#
	my $g_params = [];
	foreach my $reagion (@TARGET_REAGION){			# Generate Graph Parameters
		my $rn = $reagion;
		$rn =~ s/,.*$//;
		my @rr = ();
		foreach my $r (split(/,/, $reagion)){
			push(@rr, "$r", "~$r#");			# ~ regex
		}
		$reagion = join(",", @rr);
		
		push (@$g_params, {
				cdp => $ccse_amt_ern, 
				gdp => $MARGE_GRAPH_PARAMS, 
				dsc => "Mobiliy and ERN $rn",
				lank => [1,10],
				static => "",
				target_col => {key => $reagion},
			}
		);
		push (@$g_params, {
				cdp => $ccse_amt_rlavr, 
				gdp => $MARGE_GRAPH_PARAMS, 
				dsc => "Mobiliy and rlavr $rn",
				lank => [1,10],
				static => "",
				y2min => "",
				y2max => "",
				target_col => {key => $reagion},
			}
		);
	} 

	#	Set to graph list
	push(@$gp_list, csv2graph::csv2graph_list_mix(@$g_params));
	#csv2graph::gen_graph_by_list($ccse_amt, $MARGE_GRAPH_PARAMS, $g_params);
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

	csv2graph::new($defamt::AMT_DEF); 										# Init AMD_DEF
	my $amt_altname = csv2graph::dup_cdp($AMT_DEF);
	@{$amt_altname->{key}} = ("alternative_name", "transportation_type");			# 5, 1, 2
	csv2graph::load_csv($amt_altname);									# Load to memory
	csv2graph::dump_cdp($amt_altname, {ok => 1, lines => 5});			# Dump for debug

	$amt_pref = csv2graph::reduce_cdp_target($amt_altname, {geo_type => $SUBR, country => "Japan"});
	csv2graph::calc_items($amt_pref, "avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);
	calc::comvert2rlavr($amt_pref);							# rlavr for marge with CCSE

	#
	#	Japan Prefecture Data
	#
	my $JAPAN_DEF = $defjapan::JAPAN_DEF;
	$JAPAN_DEF->{keys} = ["prefectureNameE"],		# PrefectureNameJ, and Column name
	my $JAPAN_GRAPH = $defjapan::JAPAN_GRAPH;
	csv2graph::new($JAPAN_DEF); 						# Load Apple Mobility Trends
	csv2graph::load_csv($JAPAN_DEF);
	my $jp_positive_case = csv2graph::reduce_cdp_target($JAPAN_DEF, {key => "testedPositive"});
	csv2graph::comvert2ern($jp_positive_case);					# Calc ERN
	csv2graph::dump_cdp($jp_positive_case, {ok => 1, lines => 5});			# Dump for debug

	my $g_params = [];
#
#	Confirm the Japan Data with graph
#
#	push (@$g_params, {
#			cdp => $jp_positive_case, 
#			gdp => $JAPAN_GRAPH, 
#			dsc => "Positive cases Japan ",
#			lank => [1,10],
#			static => "",
#			#target_col => {key => $reagion},
#		},
#		{
#			cdp => $jp_positive_case, 
#			gdp => $JAPAN_GRAPH, 
#			dsc => "Positive cases Japan 滋賀",
#			lank => [1,10],
#			static => "",
#			target_col => {prefectureNameE => "=Shiga"},
#		}
#	);
#	push(@$gp_list, csv2graph::csv2graph_list_mix(@$g_params));
	#csv2graph::gen_html($JAPAN_DEF, $JAPAN_GRAPH, $jp_graph);		# Generate Graph/HTHML
if(1){
	#
	#	Marge
	#
	my $japan_amt_ern = csv2graph::marge_csv($jp_positive_case, $amt_pref);	# Marge CCSE(ERN) and Apple Mobility Trends
	#dp::dp Dumper $japan_amt_ern->{item_name_list};
	$japan_amt_ern->{id} = "amt-Japan-ern";
	$japan_amt_ern->{src_info} = "(ern)Apple Mobility Trends and Toyo Keizai.";
	$japan_amt_ern->{main_url} = "please reffer amt and ccse";
	$japan_amt_ern->{csv_file} = "please reffer amt and ccse";
	$japan_amt_ern->{src_url} =  "please reffer amt and ccse";	
	csv2graph::dump_cdp($japan_amt_ern, {ok => 1, lines => 5, items => 10, search_key => "Tokyo"});			# Dump for debug

	my $MARGE_GRAPH_PARAMS = {
		html_title => "MARGE Apple Mobility Trends and ERN",
		png_path   => $PNG_PATH,
		png_rel_path => $PNG_REL_PATH,
		html_file => "$HTML_PATH/applemobile_jp_ern.html",

		y2label => 'ERN', y2min => 0, y2max => 3, y2_source => 0,		# soruce csv definition for y2
		ylabel => '%', ymin => 0,
		additional_plot => $additional_plot,
	};

	my @pref = ("~東京,~Tokyo", "~神奈川,~Kanagawa", "~埼玉,~Saitama",
			 "~千葉,~Chiba", "~大阪,~Osaka","~京都,~Kyoto");			# Generate Graph Parameters
	@pref = ("~Tokyo", "~^Kanagawa", "~^Saitama",
			 "~千葉,~Chiba", "~大阪,~Osaka","~京都,~Kyoto");			# Generate Graph Parameters
	foreach my $reagion (@pref){			# Generate Graph Parameters
		#my $rn = $reagion;
		#$rn =~ s/,.*$//;
		#my @rr = ();
		#foreach my $r (split(/,/, $reagion)){
		#	push(@rr, "$r", "~$r#");			# ~ regex
		#}
		#my $rgn = join(",", @rr);
		push (@$g_params, {
				cdp => $japan_amt_ern, 
				gdp => $MARGE_GRAPH_PARAMS, 
				dsc => "Mobiliy and ern ",
				lank => [1,10],
				static => "",
				target_col => {marge_key => $reagion},
			}
		);
	}
	push(@$gp_list, csv2graph::csv2graph_list_mix(@$g_params));
}
	#csv2graph::gen_html($JAPAN_DEF, $JAPAN_GRAPH, $jp_graph);		# Generate Graph/HTHML
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
#	y,m,d,東京,Tokyo,testedPositive,1,2,3,4,
#	y,m,d,東京,Tokyo,peopleTested,1,2,3,4,
#
#
#
if($golist{japan}){
	my $JAPAN_DEF = $defjapan::JAPAN_DEF;
	my $JAPAN_GRAPH = $defjapan::JAPAN_GRAPH;
	csv2graph::new($JAPAN_DEF); 						# Load Apple Mobility Trends
	csv2graph::load_csv($JAPAN_DEF);
	my $jp_graph = [
		{dsc => "Japan TestPositive ", lank => [1,10], static => "rlavr", target_col => {key => "testedPositive"} },
		{dsc => "Japan PeopleTested", lank => [1,10], static => "rlavr", target_col => {key => "peopleTested"} },
		{dsc => "Japan hospitalized", lank => [1,10], static => "rlavr", target_col => {key => "hospitalized"} },
		{dsc => "Japan serious", lank => [1,10], static => "rlavr", target_col => {key => "serious"} },
		{dsc => "Japan discharged", lank => [1,10], static => "rlavr", target_col => {key => "discharged"} },
		{dsc => "Japan deaths", lank => [1,10], static => "rlavr", target_col => {key => "deaths"} },
		{dsc => "Japan ERN", lank => [1,10], static => "", target_col => {key => "effectiveReproductionNumber"}, 
				ymin => "",ymax => ""},
	];
	push(@$gp_list , 
		csv2graph::csv2graph_list($JAPAN_DEF, $JAPAN_GRAPH, $jp_graph)); 
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
		{dsc => "平均気温 ", lank => [1,10], static => "", target_col => {key => "平均気温"}},
		{dsc => "平均気温 ", lank => [1,10], static => "rlavr", target_col => {key => "平均気温"}},
		{dsc => "平均湿度 ", lank => [1,10], static => "", target_col => {key => "平均湿度"}},
		{dsc => "平均湿度 ", lank => [1,10], static => "rlavr", target_col => {key => "平均湿度"}},
	];
	push(@$gp_list , 
		csv2graph::csv2graph_list($TKOW_DEF, $TKOW_GRAPH, $tkow_graph)); 
}

#
#
#
if($golist{"tkow-ern"}) {
	#
	#	Tokyo Weather
	#
	my $TKOW_DEF   = $deftkow::TKOW_DEF;
	my $TKOW_GRAPH = $deftkow::TKOW_GRAPH;

	csv2graph::new($TKOW_DEF); 						# Load Apple Mobility Trends
	csv2graph::load_csv($TKOW_DEF);
	my $tkow_cdp = csv2graph::comvert2rlavr($TKOW_DEF);					# Calc ERN

	#
	#	CCSE
	#
	my $CCSE_DEF = $defccse::CCSE_DEF;
	my $CCSE_GRAPH = $defccse::CCSE_GRAPH;

	csv2graph::new($defccse::CCSE_DEF); 							# Load Johns Hopkings University CCSE
	csv2graph::load_csv($defccse::CCSE_DEF);
	#csv2graph::dump_cdp($CCSE_DEF, {ok => 1, lines => 1, items => 10, search_key => "Canada"}); # if($DEBUG);
	csv2graph::calc_items($CCSE_DEF, "sum", 
				{"Province/State" => "", "Country/Region" => "Canada"},		# All Province/State with Canada, ["*","Canada",]
				{"Province/State" => "null", "Country/Region" => "="}		# total gos ["","Canada"] null = "", = keep
	);
	$ccse_country = csv2graph::reduce_cdp_target($CCSE_DEF, {"Province/State" => "NULL"});	# Select Country
	#csv2graph::dump_cdp($ccse_country, {ok => 1, lines => 5, items => 10, search_key => "Canada"}); # if($DEBUG);
	
	#
	#	Marge	ERN
	#
	my $ccse_cdp_ern = csv2graph::comvert2ern(csv2graph::dup_cdp($ccse_country));					# Calc ERN
	#csv2graph::dump_cdp($ccse_cdp_ern, {ok => 1, lines => 5, items => 10, message => "ccse_cdp_ern"}); # if($DEBUG);
	my $marge_cdp_ern = csv2graph::marge_csv($ccse_cdp_ern, $tkow_cdp);	# 
	$marge_cdp_ern->{id} = "tkow-ccse-ern";
	$marge_cdp_ern->{src_info} = "(ern)Tokyo Weather Trends and Johns Hokings Univ.";
	$marge_cdp_ern->{main_url} = "please reffer amt and ccse";
	$marge_cdp_ern->{csv_file} = "please reffer amt and ccse";
	$marge_cdp_ern->{src_url} =  "please reffer amt and ccse";	
	#csv2graph::dump_cdp($marge_cdp_ern, {ok => 1, lines => 5, items => 10, message => "marge_cdp_ern"}); # if($DEBUG);

	#
	#	Marge rlavr
	#
	my $ccse_cdp_rlavr = csv2graph::comvert2rlavr(csv2graph::dup_cdp($ccse_country));					# Calc ERN
	my $marge_cdp_rlavr = csv2graph::marge_csv($ccse_cdp_rlavr, $tkow_cdp);	# 
	$marge_cdp_rlavr->{id} = "tkow-ccse-rlavr";
	$marge_cdp_rlavr->{src_info} = "(rlavr)Tokyo Weather Trends and Johns Hokings Univ.";
	$marge_cdp_rlavr->{main_url} = "please reffer amt and ccse";
	$marge_cdp_rlavr->{csv_file} = "please reffer amt and ccse";
	$marge_cdp_rlavr->{src_url} =  "please reffer amt and ccse";	
	#csv2graph::dump_cdp($marge_cdp_rlavr, {ok => 1, lines => 5, items => 10, message => "marge_cdp_rlavr"}); # if($DEBUG);

	#
	#	Apple Mobility Trends
	#
	my $AMT_DEF = $defamt::AMT_DEF;
	my $AMT_GRAPH = $defamt::AMT_GRAPH;

	csv2graph::new($defamt::AMT_DEF); 										# Init AMD_DEF
	csv2graph::load_csv($AMT_DEF);									# Load to memory
	#csv2graph::dump_cdp($AMT_DEF, {ok => 1, lines => 5});			# Dump for debug

	my $amt_country = csv2graph::reduce_cdp_target($AMT_DEF, {geo_type => $REG});
	csv2graph::calc_items($amt_country, "avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);
	calc::comvert2rlavr($amt_country);							# rlavr for marge with CCSE

	my $ccse_amt_ern = csv2graph::marge_csv($ccse_cdp_ern, $amt_country);	# Marge CCSE(ERN) and Apple Mobility Trends
	$ccse_amt_ern->{id} = "amt-ccse-ern";
	$ccse_amt_ern->{src_info} = "(ern)Apple Mobility Trends and Johns Hokings Univ.";
	$ccse_amt_ern->{main_url} = "please reffer amt and ccse";
	$ccse_amt_ern->{csv_file} = "please reffer amt and ccse";
	$ccse_amt_ern->{src_url} =  "please reffer amt and ccse";	

	#
	#	Generate Graph Pamaters
	#
	my $MARGE_GRAPH_PARAMS = {
		html_title => "MARGE Tokyo Weather Trends and ERN",
		png_path   => $PNG_PATH,
		png_rel_path => $PNG_REL_PATH,
		html_file => "$HTML_PATH/tko_ern.html",

		#additional_plot => $additional_plot,
	};

	my $g_params = [];
	my @target = "Japan";
	foreach my $reagion (@target){			# Generate Graph Parameters
		my $rn = $reagion;
		$rn =~ s/,.*$//;
		my @rr = ();
		foreach my $r (split(/,/, $reagion)){
			push(@rr, "$r", "~$r#");			# ~ regex
		}
		my $regkey = join(",", @rr);

		push (@$g_params, {
			cdp => $ccse_amt_ern, 
			gdp => $MARGE_GRAPH_PARAMS, 
			dsc => "$reagion and ccse ERN $rn",
			lank => [1,10],
			static => "",
			target_col => {key => "$regkey"},
			y2label => 'ERN', y2min => 0, y2max => 3, y2_source => 0,		# soruce csv definition for y2
			ylabel => "Apple mobility Trends", ymin => 0, ymax => "",
			additional_plot => $additional_plot,
			}
		);
		
		foreach my $weather ("平均気温","平均湿度"){
			push (@$g_params, {
				cdp => $marge_cdp_ern, 
				gdp => $MARGE_GRAPH_PARAMS, 
				dsc => "$reagion $weather and ccse new cases $rn",
				lank => [1,10],
				static => "",
				target_col => {key => "$regkey,$weather"},
				y2label => 'ERN', y2min => 0, y2max => 3, y2_source => 0,		# soruce csv definition for y2
				ylabel => $weather, ymin => "", ymax => "",
				additional_plot => $additional_plot_item{ern},
				}
			);
		}
		foreach my $weather ("平均気温","平均湿度"){
			push (@$g_params, {
				cdp => $marge_cdp_rlavr, 
				gdp => $MARGE_GRAPH_PARAMS, 
				dsc => "$reagion $weather and newcases rlavr $rn",
				lank => [1,10],
				static => "",
				target_col => {key => "$regkey,$weather"},
				y2label => 'new cases(rlavr)', y2min => "", y2max => "", y2_source => 0,		# soruce csv definition for y2
				ylabel => $weather, ymin => "", ymax => "",
				}
			);
		}


	} 

	#	Set to graph list
	push(@$gp_list, csv2graph::csv2graph_list_mix(@$g_params));
	#csv2graph::gen_graph_by_list($ccse_amt, $MARGE_GRAPH_PARAMS, $g_params);
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
