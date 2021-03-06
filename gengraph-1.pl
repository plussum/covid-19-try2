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


my $additional_plot = join(",", 
	"100 axis x1y1 with lines title '100%' lw 1 lc 'blue' dt (3,7)",
	"1 axis x1y2 with lines title 'ern=1' lw 1 lc 'red' dt (3,7)",
);
my $MARGE_GRAPH_PARAMS = {
	html_title => "MARGE Apple Mobility Trends and ERN",
	png_path   => $PNG_PATH,
	png_rel_path => $PNG_REL_PATH,
	html_file => "$HTML_PATH/applemobile_ern.html",

	y2label => 'ERN', y2min => 0, y2max => 3, y2_source => 0,		# soruce csv definition for y2
	ylabel => '%', ymin => 0,
	additional_plot => $additional_plot,

	graph_params => [
	],
};


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
					$deftokyo::TOKYO_DEF, $defjapan::JAPAN_DEF); 

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
	dp::dp "usage:$0 " . join(" | ", "-all", @ids) ."\n";
	exit;
}
if($golist{"amt-ccse"}){
	$golist{amt} = 1;
	$golist{ccse} = 1;
}
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
	#csv2graph::dump_cdp($CCSE_DEF, {ok => 1, lines => 5, items => 10, search_key => "Canada"}); # if($DEBUG);

	#csv2graph::reduce_cdp_target($ccse_country, $CCSE_DEF, {"Province/State" => "NULL"});	# Select Country
	$ccse_country = csv2graph::reduce_cdp_target($CCSE_DEF, {"Province/State" => "NULL"});	# Select Country
	#csv2graph::dump_cdp($ccse_country, {ok => 1, lines => 5, items => 10, search_key => "Canada"}); # if($DEBUG);

	$ccse_country->{src_info} .= "-- reduced";
	#csv2graph::dump_cdp($ccse_country, {ok => 1, lines => 5, items => 10, search_key => "Japan"}); # if($DEBUG);
	my $gp = []; #$CCSE_GRAPH->{graph_params};
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
				#$ccse_graph_01));	# gen Graph and params instead of html
	#csv2graph::gen_html($ccse_country, $CCSE_GRAPH, $ccse_graph_01);		# Generate Graph/HTML
	csv2graph::comvert2ern($ccse_country);				# Calc ERN
	#csv2graph::dump_cdp($ccse_country, {ok => 1, lines => 5});
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
	#csv2graph::add_average($amt_country, "transportation_type", "avr");		# change to calc_items
	csv2graph::calc_items($amt_country, "avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);
	#csv2graph::dump_cdp($AMT_DEF, {ok => 1, lines => 5});			# Dump for debug

	#csv2graph::gen_html($amt_country, $AMT_GRAPH, $AMT_GRAPH->{graph_params});					# Generate Graph/HTHML
	#push(@$gp_list,
	#	 csv2graph::csv2graph_list($amt_country, $AMT_GRAPH, $amt_country));	# gen Graph and params instead of html

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
		{cdp => $amt_pref, gdp => $AMT_GRAPH, 
			dsc => "Japan Pref Apple mobility Trends and ERN", lank => [1,10], static => "rlavr", 
			target_col => {country => "Japan", transportation_type => $AVR},},
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
	dp::dp "-" x 20 . "\n";

	calc::comvert2rlavr($amt_country);							# rlavr for marge with CCSE
}

#
#	Generate Marged Graph of Apple Mobility Trends and CCSE-ERN
#
if($golist{"amt-ccse"}){
	my $ccse_amt = csv2graph::marge_csv($ccse_country, $amt_country);		# Marge CCSE(ERN) and Apple Mobility Trends
	$ccse_amt->{id} = "amt-ccse";
	$ccse_amt->{src_info} = "Apple Mobility Trends and Johns Hokings Univ.";
	$ccse_amt->{main_url} = "please reffer amt and ccse";
	$ccse_amt->{csv_file} = "please reffer amt and ccse";
	$ccse_amt->{src_url} =  "please reffer amt and ccse";		# set

	#csv2graph::dump_cdp($ccse_amt, {ok => 1, lines => 5});

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
				dsc => "Mobiliy and ERN $rn",
				lank => [1,10],
				static => "",
				target_col => {key => $reagion},
			}
		);
	} 
	push(@$gp_list, 
		csv2graph::csv2graph_list($ccse_amt, $MARGE_GRAPH_PARAMS, $g_params, 2));
	#$MARGE_GRAPH_PARAMS->{graph_params} = $g_params;
	#dp::dp csvlib::join_array(",", $MARGE_GRAPH_PARAMS->{graph_params}) . "\n";
	#csv2graph::gen_html($ccse_amt, $MARGE_GRAPH_PARAMS, $g_params);		# Gererate Graph
	csv2graph::gen_graph_by_list($ccse_amt, $MARGE_GRAPH_PARAMS, $g_params);
}

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

	#my $dkey = "item_name_list"; # "load_order";
	#dp::dp "$dkey: " . join(",", @{$TOKYO_DEF->{$dkey}}). "\n";
	#dp::dp "$dkey: " . join(",", @{$y1->{$dkey}}). "\n";
	#dp::dp "$dkey: " . join(",", @{$marge->{$dkey}}). "\n";

	#csv2graph::dump_cdp($marge, {ok => 1, lines => 5});
	my $tko_graph = [];
	my $tko_gpara01 = [
		{dsc => "Tokyo Positve/negative/rate", lank => [1,10], static => "", target_col => ["",""] },
		{dsc => "Tokyo Positve/negative/rate", lank => [1,10], static => "rlavr", target_col => ["",""] },
	];
	push(@$tko_graph , 
		csv2graph::csv2graph_list($marge, $TOKYO_GRAPH, $tko_gpara01));
	#csv2graph::gen_html($marge, $TOKYO_GRAPH);		# Generate Graph/HTHML

#	hospitalized,1,2,3,
#	severe_case,1,2,3,
	csv2graph::new($TOKYO_ST_DEF); 						# Load Apple Mobility Trends
	csv2graph::load_csv($TOKYO_ST_DEF);
	#csv2graph::dump_cdp($TOKYO_ST_DEF, {ok => 1, lines => 5});
	my $y21 = csv2graph::reduce_cdp_target($TOKYO_ST_DEF, ["hospitalized"]);
	my $y22 = csv2graph::reduce_cdp_target($TOKYO_ST_DEF, ["severe_case"]);
	my $marge2 = csv2graph::marge_csv($y21, $y22);		# Gererate Graph
	#csv2graph::dump_cdp($marge2, {ok => 1, lines => 5});
	#csv2graph::gen_html($marge, $TOKYO_GRAPH, $TOKYO_GRAPH->{graph_params});		# Generate Graph/HTHML
	#csv2graph::dump_cdp($marge, {ok => 1, lines => 5});
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
	#csv2graph::dump_cdp($TKO_TRAN_DEF, {ok => 1, lines => 5});
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
	#@{$JAPAN_DEF->{graph_params}} = @$jp_graph;
	csv2graph::gen_html($JAPAN_DEF, $JAPAN_GRAPH, $jp_graph);		# Generate Graph/HTHML
}

#
#	Generate HTML FILE
#
csv2graph::gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
		html_tilte => "Apple Mobile Trends",
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
