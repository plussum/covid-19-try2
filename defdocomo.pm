#!/usr/bin/perl
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
#
#
#
package defdocomo;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(defdocomo);

use strict;
use warnings;
use utf8;
use config;

my $WIN_PATH = $config::WIN_PATH;
my $HTML_PATH = "$WIN_PATH/HTML2",
my $PNG_PATH  = "$WIN_PATH/PNG2",
my $PNG_REL_PATH  = "../PNG2",
my $CSV_PATH  = $config::CSV_PATH;

my $DEFAULT_AVR_DATE = $config::DEFAULT_AVR_DATE;
my $END_OF_DATA = $config::END_OF_DATA;


####################################################################
#
# エリア,メッシュ,各日15時時点増減率(%),2020/5/1
# 北海道,札幌駅,644142881,感染拡大前比,-58
# 北海道,札幌駅,644142881,緊急事態宣言前比,-54.4
# 北海道,札幌駅,644142881,前年同月比,-62.5
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

sub download
{
}
1;
