#!/usr/bin/perl
#
#
package deftokyo;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(deftokyo);

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
sub download
{
}
1;
