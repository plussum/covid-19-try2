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

binmode(STDOUT, ":utf8");

my $VERBOSE = 0;
my $DOWN_LOAD = 0;

my $WIN_PATH = $config::WIN_PATH;
my $HTML_PATH = "$WIN_PATH/HTML2",
my $PNG_PATH  = "$WIN_PATH/PNG2",
my $PNG_REL_PATH  = "../PNG2",
my $CSV_PATH  = $config::CSV_PATH;


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
our $TKW_DEF = 
{
	id => "TKOW",
	src_info => "Tokyo Wheater", 
	main_url => "-- tokyo wheather data --- ",
	csv_file => "$CSV_PATH/TokyoWeather.csv",
	src_url => 	"--- src url ---",		# set
	down_load => \&download,

	direct => "vertical",		# vertical or holizontal(Default)
	cumrative => 0,
	timefmt => '%Y/%m/%d',		# comverbt to %Y-%m-%d
	src_dlm => ",",
	key_dlm => "#",
	keys => [0],		# PrefectureNameJ, and Column name
	data_start => 1,
};

our $TKW_GRAPH = {
	html_title => $TKW_DEF->{src_info},
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
		{dsc => "平均気温 ", lank => [1,10], static => "", target_col => {key => "平均気温"}},
		{dsc => "平均気温 ", lank => [1,10], static => "rlavr", target_col => {key => "平均気温"}},
		{dsc => "平均湿度 ", lank => [1,10], static => "", target_col => {key => "平均湿度"}},
		{dsc => "平均湿度 ", lank => [1,10], static => "rlavr", target_col => {key => "平均湿度"}},
	],
};

csv2graph::new($TKW_DEF); 							# Load Johns Hopkings University CCSE
csv2graph::load_csv($TKW_DEF);

csv2graph::gen_html($TKW_DEF, $TKW_GRAPH, $TKW_GRAPH->{graph_params}); 


#
#	Down Load CSV 
#
sub	download
{
	my ($cdp) = @_;
	return 1;
}


