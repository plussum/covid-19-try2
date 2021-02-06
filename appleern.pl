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
use csvgraph;
use dp;

binmode(STDOUT, ":utf8");

my $VERBOSE = 0;
my $DOWN_LOAD = 0;

my $WIN_PATH = "/mnt/f/_share/cov/plussum.github.io";
my $HTML_PATH = "$WIN_PATH/HTML2",
my $PNG_PATH  = "$WIN_PATH/PNG2",
my $PNG_REL_PATH  = "../PNG2",
my $CSV_PATH  = $config::WIN_PATH;

my $DEFAULT_AVR_DATE = 7;
my $END_OF_DATA = "###EOD###";

my $SRC_URL_TAG = "https://covid19-static.cdn-apple.com/covid19-mobility-data/2025HotfixDev13/v3/en-us/applemobilitytrends-%04d-%02d-%02d.csv";
my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $src_url = sprintf($SRC_URL_TAG, $year + 1900, $mon + 1, $mday);
my $ern_adp	= "1 with lines title 'ern=1' lw 1 lc 'red' dt (3,7)";


#####################################################
#
#	Definion of Apple Mobility Trends CSV Format
#
#	geo_type,region,transportation_type,alternative_name,sub-region,country,2020-01-13,,,,
#
#
my $AMT_DEF = {
	id => "amt",
	title => "Apple Mobility Trends",
	main_url =>  "https://covid19.apple.com/mobility",
	csv_file =>  "$config::WIN_PATH/applemobile/applemobilitytrends.csv.txt",
	src_url => $src_url,		# set

	down_load => \&download,

	direct => "holizontal",		# vertical or holizontal(Default)
	timefmt => '%Y-%m-%d',		# comverbt to %Y-%m-%d
	src_dlm => ",",
	key_dlm => "#",
	keys => ["region", "transportation_type"],		# 5, 1, 2
	data_start => 6,
};

my $REG = "country/region";
my $SUBR = "sub-region";
my $CITY = "city";
my $DRV = "driving";
my $TRN = "transit";
my $WLK = "walking";
my $AVR = "avr";

my $AMT_GRAPH = {
	html_title => $AMT_DEF->{title},
	png_path   => "$PNG_PATH",
	png_rel_path => $PNG_REL_PATH,
	html_file => "$HTML_PATH/apple_mobile.html",

	dst_dlm => "\t",
	avr_date => 7,

	timefmt => '%Y-%m-%d', format_x => '%m/%d',
	term_x_size => 1000, term_y_size => 350,
	ymin => 0,

	END_OF_DATA => $END_OF_DATA,

	graph => "line",
	additional_plot => "100 with lines title '100%' lw 1 lc 'blue' dt (3,7)",
	graph_params => [

	],
};

#
#	Definition of Johns Hpkings University CCSE CSV format
#
#	Province/State,Country/Region,Lat,Long,1/22/20
#
my $CCSE_BASE_DIR = "$WIN_PATH/ccse/COVID-19/csse_covid_19_data/csse_covid_19_time_series";
my $CCSE_DEF = {
	id => "ccse",
	title => "Johns Hopkins Global",
	main_url =>  "https://covid19.apple.com/mobility",
	csv_file =>  "$CCSE_BASE_DIR/time_series_covid19_confirmed_global.csv",
	src_url => $src_url,		# set
	cumrative => 1,
	down_load => \&download,

	src_dlm => ",",
	keys => [1, 0],		# 5, 1, 2
	data_start => 4,

	direct => "holizontal",		# vertical or holizontal(Default)
	timefmt => '%m/%d/%y',		# comverbt to %Y-%m-%d
};
#dp::dp $CCSE_DEF->{csv_file} . "\n";
my $CCSE_GRAPH = {
	html_title => $CCSE_DEF->{title},
	png_path   => "$PNG_PATH",
	png_rel_path => $PNG_REL_PATH,
	html_file => "$HTML_PATH/ccse2.html",

	dst_dlm => "\t",
	avr_date => 7,
	graph => "line",

	timefmt => '%Y-%m-%d', format_x => '%m/%d',
	term_x_size => 1000, term_y_size => 350,
	ymin => 0,

	END_OF_DATA => $END_OF_DATA,

	graph_params => [
#		{dsc => "Japan ern", lank => [1,99], static => "", target_col => ["","Japan"], 
#			ylabel => "ern", y2label => "ern", additional_plot => $ern_adp, ymax => 3},
	],
};

#
#	Definition of Marged CSV from Apple Mobility Trends and Johns Hopkings Univ. CCSE
#
my $MARGE_CSV_DEF = {
	id => "amt-ccse",
	title => "MARGED Apple and ERN pref",
	main_url =>  "Marged, no url",
	csv_file =>  "Marged, no csv file",
	src_url => 	"Marged, no src url",		# set
};
my @additonal_plot_list = (
	"100 axis x1y1 with lines title '100%' lw 1 lc 'blue' dt (3,7)",
	"1 axis x1y2 with lines title 'ern=1' lw 1 lc 'red' dt (3,7)",
);
my $additional_plot = join(",", @additonal_plot_list);

my $MARGE_GRAPH_PARAMS = {
	html_title => "MARGE Apple Mobility Trends and ERN",
	png_path   => "$PNG_PATH",
	png_rel_path => $PNG_REL_PATH,
	html_file => "$HTML_PATH/applemobile_ern.html",

	dst_dlm => "\t",
	avr_date => 7,
	END_OF_DATA => $END_OF_DATA,
	graph => "line",

	timefmt => '%Y-%m-%d', format_x => '%m/%d',
	term_x_size => 1000, term_y_size => 350,

	y2label => 'ERN', y2min => 0, y2max => 3, y2_source => 0,		# soruce csv definition for y2
	ylabel => '%', ymin => 0,
	additional_plot => $additional_plot,

	graph_params => [
#		{dsc => "Japan ", lank => [1,99], static => "", target_col => ["Japan"] },
	],
};

#my @TARGET_REAGION = (	"Italy", );
my @TARGET_REAGION = (
		"Canada", "Japan", "US,United States",
		"United Kingdom", "France", #"Spain", "Italy", "Russia", 
#			"Germany", "Poland", "Ukraine", "Netherlands", "Czechia,Czech Republic", "Romania",
#			"Belgium", "Portugal", "Sweden",
#		"India",  "Indonesia", "Israel", # "Iran", "Iraq","Pakistan",
#		"Brazil", "Colombia", "Argentina", "Chile", "Mexico", "Canada", 
#		"South Africa", 
);

#foreach my $p (@$gp){
#	dp::dp join(", ", $p->{dsc}, @{$p->{target_col}}, @{$p->{lank}}, ) . "\n";
#}
#
#	Generate Graph of Apple Mobility Trends and John Hopings CCSE-ERN
#

####################################################################
#
#	Tokyo Positive Rate from Tokyo Opensource (JSON)
#
#                  d1,d2,d3
#	positive_count,1,2,3,
#	negative_count,1,2,3,
#	positive_rate,1,2,3,
#	
#
my $TKY_DIR = "$config::WIN_PATH/tokyo/covid19"; # "/home/masataka/who/tokyo/covid19";
my $TOKYO_DEF = {
	id => "tokyo",
	title => "Tokyo Positive Rate",
	main_url => "-- tokyo data --- ",
	src_file => "$TKY_DIR/data/positive_rate.json",
	src_url => 	"--- src url ---",		# set
	json_items => [qw (diagnosed_date positive_count negative_count positive_rate)],
	down_load => \&download,

	direct => "json",		# vertical or holizontal(Default)
	timefmt => '%Y-%m-%d',		# comverbt to %Y-%m-%d
	src_dlm => ",",
	key_dlm => "#",
	keys => [0],		# 5, 1, 2
	data_start => 1,
};
my $TOKYO_GRAPH = {
	html_title => $TOKYO_DEF->{title},
	png_path   => "$PNG_PATH",
	png_rel_path => $PNG_REL_PATH,
	html_file => "$HTML_PATH/tokyoTest.html",

	dst_dlm => "\t",
	avr_date => 7,
	END_OF_DATA => $END_OF_DATA,

	timefmt => '%Y-%m-%d', format_x => '%m/%d',
	term_x_size => 1000, term_y_size => 350,

	y2label => 'Number', y2min => "", y2max => "", y2_source => 0,		# soruce csv definition for y2
	ylabel => '%', ymin => 0,

	graph => 'boxes fill',
	y2_graph => 'line',
	additional_plot => "",

	graph_params => [
		{dsc => "Tokyo Positve/negative/rate", lank => [1,10], static => "", target_col => ["",""] },
		{dsc => "Tokyo Positve/negative/rate", lank => [1,10], static => "rlavr", target_col => ["",""] },
	],
};

####################################################################
#
#	Tokyo Positive Status from Tokyo Opensource (JSON)
#
#    "date": "2021\/2\/4 19:45",
#    "data": [
#        {
#            "date": "2020-02-28",
#            "hospitalized": 21,
#            "severe_case": 5
#        },
#                  d1,d2,d3
#	hospitalized,1,2,3,
#	sever_case,1,2,3,
#	
#
my $TOKYO_ST_DEF = {
	id => "tokyo",
	title => "Tokyo Positive Status",
	main_url => "-- tokyo data --- ",
	src_file => "$TKY_DIR/data/positive_status.json",
	src_url => 	"--- src url ---",		# set
	json_items => [qw (date hospitalized severe_case)],
	down_load => \&download,

	direct => "json",		# vertical or holizontal(Default)
	timefmt => '%Y-%m-%d',		# comverbt to %Y-%m-%d
	src_dlm => ",",
	key_dlm => "#",
	keys => [0],		# 5, 1, 2
	data_start => 1,
};
my $TOKYO_ST_GRAPH = {
	html_title => $TOKYO_DEF->{title},
	png_path   => "$PNG_PATH",
	png_rel_path => $PNG_REL_PATH,
	html_file => "$HTML_PATH/tokyoTest.html",

	dst_dlm => "\t",
	avr_date => 7,
	END_OF_DATA => $END_OF_DATA,

	timefmt => '%Y-%m-%d', format_x => '%m/%d',
	term_x_size => 1000, term_y_size => 350,

	ylabel => 'hospitlized', ymin => 0,
	y2_source => 1,		# soruce csv definition for y2
	y2label => 'sever cases', y2min => "", y2max => "", 

	graph => 'line',
	y2_graph => 'boxes fill',
	additional_plot => "",

	graph_params => [
		{dsc => "Tokyo Positive Status", lank => [1,10], static => "", target_col => ["",""] },
		{dsc => "Tokyo Positive Status", lank => [1,10], static => "rlavr", target_col => ["",""] },
	],
};

####################################################################
#
#	https://github.com/kaz-ogiwara/covid19
#
# year,month,date,prefectureNameJ,prefectureNameE,testedPositive,peopleTested,hospitalized,serious,discharged,deaths,effectiveReproductionNumber
# 2020,2,8,東京,Tokyo,3,,,,,,
#
#	y,m,d,東京,Tokyo,testedPositive,1,2,3,4,
#	y,m,d,東京,Tokyo,peopleTested,1,2,3,4,
#
#my $TKO_PATH = "$WIN_PATH/tokyokeizai";
#my $BASE_DIR = "$TKO_PATH/covid19/data";
#our $transaction = "$BASE_DIR/prefectures.csv";
my $TKO_PATH = "$config::WIN_PATH/tokyokeizai/covid19/data";
#/mnt/f/_share/cov/plussum.github.io/tokyokeizai/covid19/data/prefectures.csv
#/mnt/f/_share/cov/plussum.github.io/tokyokeizai/prefecture.csv.txt
my $TKO_TRAN_DEF = 
{
	id => "japan",
	title => "Japan COVID-19 data (Tokyo Keizai)",
	main_url => "-- tokyo keizai data --- ",
	csv_file => "$TKO_PATH/prefectures.csv",
	src_url => 	"--- src url ---",		# set
	down_load => \&download,

	direct => "transaction",		# vertical or holizontal(Default)
	cumrative => 1,
	timefmt => '%Y:0-%m:1-%d:2',		# comverbt to %Y-%m-%d
	src_dlm => ",",
	key_dlm => "#",
	keys => [3],		# PrefectureNameJ, and Column name
	data_start => 5,
};
my $TKO_TRAN_GRAPH = {
	html_title => $TKO_TRAN_DEF->{title},
	png_path   => "$PNG_PATH",
	png_rel_path => $PNG_REL_PATH,
	html_file => "$HTML_PATH/JapanTokyoKeizai.html",

	dst_dlm => "\t",
	avr_date => 7,
	END_OF_DATA => $END_OF_DATA,
	graph => "line",

	timefmt => '%Y-%m-%d', format_x => '%m/%d',
	term_x_size => 1000, term_y_size => 350,

	#y2label => 'ERN', y2min => 0, y2max => 3, y2_source => 0,		# soruce csv definition for y2
	ylabel => "Number", ymin => 0,
	additional_plot => "",

	graph_params => [
	],
};

####################################
#
#
#
my @cdp_list = ($AMT_DEF, $CCSE_DEF, $MARGE_CSV_DEF, $TKO_TRAN_DEF, $TOKYO_DEF); 
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
#	Load CCSE
#
#	Province/State,Country/Region,Lat,Long,1/22/20
#
my $gp_list = [];
my $ccse_country = {};
#	Load Johns Hoping Univercity CCSE
if($golist{ccse}){
	csvgraph::new($CCSE_DEF); 							# Load Johns Hopkings University CCSE
	csvgraph::load_csv($CCSE_DEF);
	#csvgraph::dump_cdp($CCSE_DEF, {ok => 1, lines => 1, items => 10, search_key => "Canada"}); # if($DEBUG);
	csvgraph::calc_items($CCSE_DEF, "sum", 
				{"Province/State" => "", "Country/Region" => "Canada"},		# All Province/State with Canada, ["*","Canada",]
				{"Province/State" => "null", "Country/Region" => "="}		# total gos ["","Canada"] null = "", = keep
	);
	#csvgraph::dump_cdp($CCSE_DEF, {ok => 1, lines => 5, items => 10, search_key => "Canada"}); # if($DEBUG);

	csvgraph::reduce_cdp_target($ccse_country, $CCSE_DEF, {"Province/State" => "NULL"});	# Select Country
	#csvgraph::dump_cdp($ccse_country, {ok => 1, lines => 5, items => 10, search_key => "Canada"}); # if($DEBUG);
	$ccse_country->{title} .= "-- reduced";
	#csvgraph::dump_cdp($ccse_country, {ok => 1, lines => 5, items => 10, search_key => "Japan"}); # if($DEBUG);
	my $gp = $CCSE_GRAPH->{graph_params};
	foreach my $reagion (@TARGET_REAGION){
		push (@$gp, {
			dsc => "CCSE $reagion",
			lank => [1,10],
			static => "rlavr",
			target_col => ["", $reagion],
			}
		);
	}
	my $prov = "Province/State";
	my $cntry = "Country/Region";
	my $ccse_graph_01 = [
		{dsc => "Japan ", lank => [1,10], static => "rlavr", target_col => {"$prov" => "", "$cntry" => "Japan"}},
	#	{dsc => "Japan top 10", lank => [1,10], static => "rlavr", target_col => {"$prov" => "", "$cntry" => "Japan"}},
		{dsc => "World Wild ", lank => [1,10], static => "rlavr", target_col => {"$prov" => "", "$cntry" => ""}},
		{dsc => "World Wild ", lank => [11,20], static => "rlavr", target_col => {"$prov" => "", "$cntry" => ""}},
	];
	push(@$gp_list,
		 csvgraph::csv2graph_list($ccse_country, $CCSE_GRAPH, $ccse_graph_01)); 
				#$ccse_graph_01));	# gen Graph and params instead of html
	#csvgraph::gen_html($ccse_country, $CCSE_GRAPH);		# Generate Graph/HTML
	csvgraph::comvert2ern($ccse_country);				# Calc ERN
	#csvgraph::dump_cdp($ccse_country, {ok => 1, lines => 5});
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
	csvgraph::new($AMT_DEF); 										# Init AMD_DEF
	csvgraph::load_csv($AMT_DEF);									# Load to memory
	#csvgraph::dump_cdp($AMT_DEF, {ok => 1, lines => 5});			# Dump for debug

	csvgraph::reduce_cdp_target($amt_country, $AMT_DEF, {geo_type => $REG});
	#csvgraph::add_average($amt_country, "transportation_type", "avr");		# change to calc_items
	csvgraph::calc_items($amt_country, "avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);

	#csvgraph::gen_html($amt_country, $AMT_GRAPH);					# Generate Graph/HTHML
	#push(@$gp_list,
	#	 csvgraph::csv2graph_list($amt_country, $AMT_GRAPH, $amt_country));	# gen Graph and params instead of html

	csvgraph::reduce_cdp_target($amt_pref, $AMT_DEF, {geo_type => $SUBR});
	csvgraph::calc_items($amt_pref, "avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);
	push(@$gp_list , csvgraph::csv2graph_list_mix( 
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

	csvgraph::comvert2rlavr($amt_country);							# rlavr for marge with CCSE
}

#
#	Generate Marged Graph of Apple Mobility Trends and CCSE-ERN
#
if($golist{"amt-ccse"}){
	csvgraph::marge_csv($MARGE_CSV_DEF, $ccse_country, $amt_country);		# Marge CCSE(ERN) and Apple Mobility Trends
	#csvgraph::dump_cdp($MARGE_CSV_DEF, {ok => 1, lines => 5});

	my $gp = $MARGE_GRAPH_PARAMS->{graph_params};
	foreach my $reagion (@TARGET_REAGION){			# Generate Graph Parameters
		my $rn = $reagion;
		$rn =~ s/,.*$//;
		my @rr = ();
		foreach my $r (split(/,/, $reagion)){
			push(@rr, "$r", "~$r#");			# ~ regex
		}
		$reagion = join(",", @rr);
		
		push (@$gp, {
			dsc => "Mobiliy and ERN $rn",
			lank => [1,10],
			static => "",
			target_col => [$reagion],
			}
		);
	} 
	push(@$gp_list, 
		csvgraph::csv2graph_list($MARGE_CSV_DEF, $MARGE_GRAPH_PARAMS, $MARGE_GRAPH_PARAMS->{graph_params}, 2));
	csvgraph::gen_html($MARGE_CSV_DEF, $MARGE_GRAPH_PARAMS);		# Gererate Graph
	csvgraph::gen_graph_by_list($MARGE_CSV_DEF, $MARGE_GRAPH_PARAMS);
}

#	Generate Graph
#
#	positive_count,1,2,3,
#	negative_count,1,2,3,
#	positive_rate,1,2,3,
#
if($golist{"tokyo"}){
	csvgraph::new($TOKYO_DEF); 						# Load Apple Mobility Trends
	csvgraph::load_csv($TOKYO_DEF);
	my $y1 = {};
	my $y2 = {};
	my $marge = {};
	csvgraph::reduce_cdp_target($y1, $TOKYO_DEF, ["positive_count,negative_count"]);
	csvgraph::reduce_cdp_target($y2, $TOKYO_DEF, ["positive_rate"]);
	csvgraph::marge_csv($marge, $y1, $y2);		# Gererate Graph

	#my $dkey = "item_name_list"; # "load_order";
	#dp::dp "$dkey: " . join(",", @{$TOKYO_DEF->{$dkey}}). "\n";
	#dp::dp "$dkey: " . join(",", @{$y1->{$dkey}}). "\n";
	#dp::dp "$dkey: " . join(",", @{$marge->{$dkey}}). "\n";

	#csvgraph::dump_cdp($marge, {ok => 1, lines => 5});
	my $tko_graph = [];
	push(@$tko_graph , 
		csvgraph::csv2graph_list($marge, $TOKYO_GRAPH, $TOKYO_GRAPH->{graph_params}));
	#csvgraph::gen_html($marge, $TOKYO_GRAPH);		# Generate Graph/HTHML

#	hospitalized,1,2,3,
#	severe_case,1,2,3,
	csvgraph::new($TOKYO_ST_DEF); 						# Load Apple Mobility Trends
	csvgraph::load_csv($TOKYO_ST_DEF);
	#csvgraph::dump_cdp($TOKYO_ST_DEF, {ok => 1, lines => 5});
	my $y21 = {};
	my $y22 = {};
	my $marge2 = {};
	csvgraph::reduce_cdp_target($y21, $TOKYO_ST_DEF, ["hospitalized"]);
	csvgraph::reduce_cdp_target($y22, $TOKYO_ST_DEF, ["severe_case"]);
	csvgraph::marge_csv($marge2, $y21, $y22);		# Gererate Graph
	#csvgraph::dump_cdp($marge2, {ok => 1, lines => 5});
	#csvgraph::gen_html($marge, $TOKYO_GRAPH);		# Generate Graph/HTHML
	#csvgraph::dump_cdp($marge, {ok => 1, lines => 5});
	push(@$tko_graph , 
		csvgraph::csv2graph_list($marge2, $TOKYO_ST_GRAPH, $TOKYO_ST_GRAPH->{graph_params}));

	push(@$gp_list, @$tko_graph);
	csvgraph::gen_html_by_gp_list($tko_graph, {						# Generate HTML file with graphs
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
	csvgraph::new($TKO_TRAN_DEF); 						# Load Apple Mobility Trends
	csvgraph::load_csv($TKO_TRAN_DEF);
	#csvgraph::dump_cdp($TKO_TRAN_DEF, {ok => 1, lines => 5});
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
		csvgraph::csv2graph_list($TKO_TRAN_DEF, $TKO_TRAN_GRAPH, $jp_graph)); 
	@{$TKO_TRAN_GRAPH->{graph_params}} = @$jp_graph;
	csvgraph::gen_html($TKO_TRAN_DEF, $TKO_TRAN_GRAPH);		# Generate Graph/HTHML
}

#
#	Generate HTML FILE
#
csvgraph::gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
		html_tilte => "Apple Mobile Trends",
		src_url => $AMT_DEF->{src_url} // "src_url",
		html_file => "$HTML_PATH/csvgraph_index.html",
		png_path => $PNG_PATH // "png_path",
		png_rel_path => $PNG_REL_PATH // "png_rel_path",
		data_source => $AMT_GRAPH->{data_source} // "data_source",
		dst_dlm => $AMT_GRAPH->{dst_dlm} // "dst_dlm",
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
