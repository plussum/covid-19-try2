#!/usr/bin/perl
#
#
#
package defjapan;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(defjapan);

use strict;
use warnings;
use utf8;
use Encode 'decode';
use config;

my $WIN_PATH = "$config::WIN_PATH";
my $HTML_PATH = "$WIN_PATH/HTML2",
my $PNG_PATH  = "$WIN_PATH/PNG2",
my $PNG_REL_PATH  = "../PNG2",
my $CSV_PATH  = $config::WIN_PATH;

my $DEFAULT_AVR_DATE = $config::DEFAULT_AVR_DATE;
my $END_OF_DATA = $config::END_OF_DATA;


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
	src_info => "Japan COVID-19 data (Toyo Keizai)",
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

sub	dwonload
{
}

1;
