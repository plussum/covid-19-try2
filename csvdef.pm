#!/usr/bin/perl
#
#	Apple Mobile report
#
package csvdef;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(csvdef);

use strict;
use warnings;
use utf8;
use config;

my $WIN_PATH = $config::WIN_PATH;
my $HTML_PATH = "$WIN_PATH/HTML2",
my $PNG_PATH  = "$WIN_PATH/PNG2",
my $PNG_REL_PATH  = "../PNG2",
my $CSV_PATH  = $config::WIN_PATH;

my $DEFAULT_AVR_DATE = $config::DEFAULT_AVR_DATE;
my $END_OF_DATA = $config::END_OF_DATA;


#####################################################
#
#	Definion of Apple Mobility Trends CSV Format
#
#	geo_type,region,transportation_type,alternative_name,sub-region,country,2020-01-13,,,,
#
#
our $AMT_DEF = {
	id => "amt",
	src_info => "Apple Mobility Trends",
	main_url =>  "https://covid19.apple.com/mobility",
	src_file =>  "$config::WIN_PATH/applemobile/applemobilitytrends.csv.txt",
	src_url => "https://covid19.apple.com/mobility",		# set

	down_load => \&download,

	direct => "holizontal",		# vertical or holizontal(Default)
	timefmt => '%Y-%m-%d',		# comverbt to %Y-%m-%d
	src_dlm => ",",
	key_dlm => "#",
	keys => ["region", "transportation_type"],		# 5, 1, 2
	data_start => 6,
};

our $REG = "country/region";
our $SUBR = "sub-region";
our $CITY = "city";
our $DRV = "driving";
our $TRN = "transit";
our $WLK = "walking";
our $AVR = "avr";

our $AMT_GRAPH = {
	html_title => $AMT_DEF->{src_info},
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

sub amt_download
{
}

#
#		target_area => "Japan,XXX,YYY", 
#		exclusion_are => ""
#
#
#
#	Definition of Johns Hpkings University CCSE CSV format
#
#	Province/State,Country/Region,Lat,Long,1/22/20
#
my $CCSE_ROOT = "$WIN_PATH/ccse2/COVID-19";
my $CCSE_BASE_DIR = "$CCSE_ROOT/csse_covid_19_data/csse_covid_19_time_series";
our $CCSE_DEF = {
	id => "ccse",
	src_info => "Johns Hopkins CSSE",
	main_url =>  "https://covid19.apple.com/mobility",
	src_file =>  "$CSV_PATH/time_series_covid19_confirmed_global.csv",
	src_url => "https://github.com/beoutbreakprepared/nCoV2019",
	cumrative => 1,
	down_load => \&download,

	src_dlm => ",",
	key_dlm => "-",
#	keys => ["Country/Region", "Province/State"],		# 5, 1, 2
	data_start => 4,

	direct => "holizontal",		# vertical or holizontal(Default)
	timefmt => '%m/%d/%y',		# comverbt to %Y-%m-%d
	alias => {"subr" => "Province/State", "region" => "Country/Region"},
};
my @MAIN_KEYS = ("Country/Region", "Province/State"),	#

our $CCSE_CONF_DEF = clone($CCSE_DEF);
$CCSE_CONF_DEF->{id} = "ccse_conf";
$CCSE_CONF_DEF->{src_file} = "$CSV_PATH/time_series_covid19_confirmed_global.csv",
$CCSE_CONF_DEF->{keys} = [@MAIN_KEYS, "=conf"];
#print Dumper $CCSE_CONF_DEF;

our $CCSE_DEATHS_DEF = clone($CCSE_CONF_DEF);
$CCSE_DEATHS_DEF->{id} = "ccse_death";
$CCSE_DEATHS_DEF->{src_file} = "$CSV_PATH/time_series_covid19_deaths_global.csv",
$CCSE_DEATHS_DEF->{keys} = [@MAIN_KEYS, "=death"];

our $CCSE_US_CONF_DEF = clone($CCSE_CONF_DEF);
$CCSE_US_CONF_DEF->{id} = "ccse_us_conf";
$CCSE_US_CONF_DEF->{src_file} = "$CSV_PATH/time_series_covid19_confirmed_US.csv",
$CCSE_US_CONF_DEF->{keys} = [@MAIN_KEYS, "=conf_us"];

our $CCSE_US_DEATHS_DEF = clone($CCSE_CONF_DEF);
$CCSE_US_DEATHS_DEF->{id} = "ccse_us_death";
$CCSE_US_DEATHS_DEF->{src_file} = "$CSV_PATH/time_series_covid19_deaths_US.csv",
$CCSE_US_DEATHS_DEF->{keys} = [@MAIN_KEYS, "=death_us"];

#dp::dp $CCSE_DEF->{csv_file} . "\n";
our $CCSE_GRAPH = {
	html_title => $CCSE_CONF_DEF->{src_info},
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
#	Download data from the data source
#
sub	ccse_download
{
	my ($cdp) = @_;

	#system("(cd ../COVID-19; git pull origin master)");
	system("(cd $CCSE_ROOT; git pull origin master)");
	system("cp $CCSE_BASE_DIR/*.csv $config::CSV_PATH/");
}

#
#   SRC: https://mobaku.jp/covid-19/download/%E5%A2%97%E6%B8%9B%E7%8E%87%E4%B8%80%E8%A6%A7.csv
# エリア,メッシュ,各日15時時点増減率(%),2020/5/1
# 北海道,札幌駅,644142881,感染拡大前比,-58
# 北海道,札幌駅,644142881,緊急事態宣言前比,-54.4
# 北海道,札幌駅,644142881,前年同月比,-62.5
# 北海道,札幌駅,644142881,前日比,-2.2
# 北海道,すすきの,644142683,感染拡大前比,-50.6
# 北海道,すすきの,644142683,緊急事態宣言前比,-36
# 北海道,すすきの,644142683,前年同月比,-44.3
# 北海道,すすきの,644142683,前日比,1.3
# 北海道,新千歳空港,644115441,感染拡大前比,-69.6
#
our $DOCOMO_DEF = {
	id => "docomo",
	src_info => "Docomo MObile",
	main_url => "https://mobaku.jp/covid-19/download/%E5%A2%97%E6%B8%9B%E7%8E%87%E4%B8%80%E8%A6%A7.csv",
	src_file => "$CSV_PATH/docomo.csv.txt",
	src_url => 	"--- src url ---",		# set
	src_url => "https://mobaku.jp/covid-19/download/%E5%A2%97%E6%B8%9B%E7%8E%87%E4%B8%80%E8%A6%A7.csv",
	json_items => [qw (diagnosed_date positive_count negative_count positive_rate)],
	down_load => \&download,

	direct => "holizontal",		# vertical or holizontal(Default)
	cumrative => 0,
	timefmt => '%Y/%m/%d',		# comverbt to %Y-%m-%d
	src_dlm => ",",
	key_dlm => "#",
	keys => ["area","base",],		# PrefectureNameJ, and Column name
	data_start => 3,
	alias => { area => "エリア", mesh => "メッシュ", base => "各日15時時点増減率(%)"},
};
our $DOCOMO_GRAPH = {
	html_title => $DOCOMO_DEF->{src_info},
	png_path   => "$PNG_PATH",
	png_rel_path => $PNG_REL_PATH,
	html_file => "$HTML_PATH/docomomobile.html",

	dst_dlm => "\t",
	avr_date => 7,
	END_OF_DATA => $END_OF_DATA,

	timefmt => '%Y-%m-%d', format_x => '%m/%d',
	term_x_size => 1000, term_y_size => 350,

	#ykey => "testedPositive", y2key => "ern",
	y2label => 'Number', y2min => "", y2max => "", y2_source => 0,		# soruce csv definition for y2
	ylabel => '%', ymin => 0,

	graph => 'boxes fill',
	y2_graph => 'line',
	additional_plot => "",

	graph_params => [
	],
};

sub docomo_download
{
}


####################################################################
#
#	https://github.com/kaz-ogiwara/covid19
#
# year,month,date,prefectureNameJ,prefectureNameE,testedPositive,peopleTested,hospitalized,serious,discharged,deaths,effectiveReproductionNumber
# 	2020,2,8,東京,Tokyo,3,,,,,,
#
# 	year,month,date,prefectureNameJ,prefectureNameE,
#	y,m,d,東京,Tokyo,testedPositive,1,2,3,4,
#	y,m,d,東京,Tokyo,peopleTested,1,2,3,4,
#
#my $TKO_PATH = "$WIN_PATH/tokyokeizai";
#my $BASE_DIR = "$TKO_PATH/covid19/data";
#our $transaction = "$BASE_DIR/prefectures.csv";
my $TKO_PATH = "$config::WIN_PATH/tokyokeizai/covid19/data";
#/mnt/f/_share/cov/plussum.github.io/tokyokeizai/covid19/data/prefectures.csv
#/mnt/f/_share/cov/plussum.github.io/tokyokeizai/prefecture.csv.txt
our $JAPAN_DEF = 
{
	id => "japan",
	src_info => "Japan COVID-19 data (Tokyo Keizai)",
	main_url => "-- tokyo keizai data --- ",
	src_file => "$TKO_PATH/prefectures.csv",
	src_url => 	"--- src url ---",		# set
	down_load => \&download,

	direct => "transaction",		# vertical or holizontal(Default)
	cumrative => 1,
	timefmt => '%Y:0-%m:1-%d:2',		# comverbt to %Y-%m-%d
	src_dlm => ",",
	key_dlm => "#",
	keys => ["prefectureNameJ"],		# PrefectureNameJ, and Column name
	data_start => 5,
	alias => { ern => "effectiveReproductionNumber"},
};
our $JAPAN_GRAPH = {
	html_title => $JAPAN_DEF->{src_info},
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

sub	japan_dwonload
{
}

#
#	気象庁　過去の気象データ・ダウンロード
#	https://www.data.jma.go.jp/gmd/risk/obsdl/index.php
#
#

####################################################################
#
#	年月日	平均気温(℃)	最高気温(℃)	最低気温(℃)	平均湿度(％)
#	2020/1/1	5.5	10.2	3.2	49
#	2020/1/2	6.2	11.3	1.9	60
#
#	年月日		2020/1/1, 2020/1/2
#	平均気温(℃)		5.5		6.2
#	最高気温(℃)		10.2	11.3
#	最低気温(℃)		3.2		1.9
#	平均湿度(％)	49		60
our $TKOW_DEF = 
{
	id => "tkow",
	src_info => "Tokyo Wheater", 
	main_url => "-- tokyo wheather data --- ",
	src_file => "$CSV_PATH/TokyoWeather.csv",
	src_url => 	"--- src url ---",		# set
	down_load => \&download,

	direct => "vertical",		# vertical or holizontal(Default)
	cumrative => 0,
	timefmt => '%Y/%m/%d',		# comverbt to %Y-%m-%d
	src_dlm => ",",
	key_dlm => "#",
	keys => ["item"],				# 気温,湿度,,,
	data_start => 1,
	item_name_line => 3,
	data_start_line => 7,
	alias => {"平均気温" => 1, "最高気温" => 4, "最低気温" => 7, "平均湿度" => 10},
	load_col => [0,3,6,9],		# columns for load B -> 0, C->1 (skip col 0:date)
};

our $TKOW_GRAPH = {
	html_title => $TKOW_DEF->{src_info},
	png_path   => $PNG_PATH,
	png_rel_path => $PNG_REL_PATH,
	html_file => "$HTML_PATH/tkow.html",

	dst_dlm => "\t",
	avr_date => 7,
	graph => "line",

	timefmt => '%Y-%m-%d', format_x => '%m/%d',
	term_x_size => 1000, term_y_size => 350,

	#y2label => 'ERN', y2min => 0, y2max => 3, y2_source => 0,		# soruce csv definition for y2
	ylabel => "Number", ymin => 0,
	additional_plot => "",

	graph_params => [
		{dsc => "気温 ", lank => [1,10], static => "", target_col => {key => "~気温"}},
		{dsc => "気温 ", lank => [1,10], static => "rlavr", target_col => {key => "~気温"}},
		{dsc => "平均気温 ", lank => [1,10], static => "", target_col => {key => "~平均気温"}},
		{dsc => "平均気温 ", lank => [1,10], static => "rlavr", target_col => {key => "~平均気温"}},
		{dsc => "平均湿度 ", lank => [1,10], static => "", target_col => {key => "~平均湿度"}},
		{dsc => "平均湿度 ", lank => [1,10], static => "rlavr", target_col => {key => "~平均湿度"}},
	],
};

#
#	Down Load CSV 
#
sub	tkow_download
{
	my ($cdp) = @_;
	return 1;
}


####################################################################
#
#	Tokyo Positive Rate from Tokyo Opensource (JSON)
#
#   "date": "2021\/2\/4 19:45",
#    "data": [
#        {
#            "diagnosed_date": "2020-02-15",
#            "positive_count": 8,
#            "negative_count": 122,
#            "positive_rate": null,
#            "weekly_average_diagnosed_count": null,
#            "pcr_positive_count": 8,
#            "pcr_negative_count": 122,
#            "antigen_positive_count": null,
#            "antigen_negative_count": null
#        },
#
#                  d1,d2,d3
#	positive_count,1,2,3,
#	negative_count,1,2,3,
#	positive_rate,1,2,3,
#	
#
my $TKY_DIR = "$config::WIN_PATH/tokyo/covid19"; # "/home/masataka/who/tokyo/covid19";
our $TOKYO_DEF = {
	id => "tokyo",
	src_info => "Tokyo Positive Rate",
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
our $TOKYO_GRAPH = {
	html_title => $TOKYO_DEF->{src_info},
	png_path   => "$PNG_PATH",
	png_rel_path => $PNG_REL_PATH,
	html_file => "$HTML_PATH/tokyoTest.html",

	dst_dlm => "\t",
	avr_date => 7,
	END_OF_DATA => $END_OF_DATA,

	timefmt => '%Y-%m-%d', format_x => '%m/%d',
	term_x_size => 1000, term_y_size => 350,

	#ykey => "testedPositive", y2key => "ern",
	y2label => 'Number', y2min => "", y2max => "", y2_source => 0,		# soruce csv definition for y2
	ylabel => '%', ymin => 0,

	graph => 'boxes fill',
	y2_graph => 'line',
	additional_plot => "",

	graph_params => [
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
our $TOKYO_ST_DEF = {
	id => "tokyo",
	src_info => "Tokyo Positive Status",
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
our $TOKYO_ST_GRAPH = {
	html_title => $TOKYO_DEF->{src_info},
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
	],
};
sub rokyo_download
{
}
1;
