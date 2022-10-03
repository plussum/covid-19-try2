#!/usr/bin/perl
#
#	NHK: https://www3.nhk.or.jp/news/special/coronavirus/data-widget/
#
package defnhk;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(defnhk);

use strict;
use warnings;
use utf8;
use Encode 'decode';
use config;

my $WIN_PATH = "$config::WIN_PATH";
my $HTML_PATH = "$WIN_PATH/HTML2";
my $PNG_PATH  = "$WIN_PATH/PNG2";
my $PNG_REL_PATH = "../PNG2";
my $CSV_PATH  = "$config::WIN_PATH/CSV";

my $DEFAULT_AVR_DATE = $config::DEFAULT_AVR_DATE;
my $END_OF_DATA = $config::END_OF_DATA;


####################################################################
#
#	NHK: https://www3.nhk.or.jp/news/special/coronavirus/data-widget/
#	https://www3.nhk.or.jp/n-data/opendata/coronavirus/nhk_news_covid19_prefectures_daily_data.csv
#日付	都道府県コード	都道府県名	各地の感染者数_1日ごとの発表数	各地の感染者数_累計	各地の死者数_1日ごとの発表数	各地の死者数_累計
# 2020/1/16	1	北海道	0	0	0	0
#
our $CDP = 
{
	id => "nhk",
	src_info => "Japan COVID-19 data (NHK)",
	#main_url => " https://www3.nhk.or.jp/news/special/coronavirus/data-widget/",
	#src_url => "https://www3.nhk.or.jp/n-data/opendata/coronavirus/nhk_news_covid19_prefectures_daily_data.csv",
	main_url => " https://covid19.mhlw.go.jp/public/opendata/",
	src_file => "$CSV_PATH/nhk_news_covid19_prefectures_daily_data.csv",
	src_url => 	"https://covid19.mhlw.go.jp/public/opendata/newly_confirmed_cases_daily.csv",
	down_load => \&download,

	#direct => "transaction",		# vertical or holizontal(Default)
	direct => "vertical",		# vertical or holizontal(Default)
	cumrative => 0,
	timefmt => '%Y/%m/%d',			# comverbt to %Y-%m-%d
	src_dlm => ",",
	key_dlm => "#",
	#keys => ["prefectureNameJ"],		# PrefectureNameJ, and Column name
	data_start => 1,
		#日付,都道府県コード,都道府県名,各地の感染者数_1日ごとの発表数,各地の感染者数_累計,各地の死者数_1日ごとの発表数,各地の死者数_累計
		# year,month,date,prefectureNameJ,prefectureNameE,testedPositive,peopleTested,hospitalized,serious,discharged,deaths,effectiveReproductionNumber
	##item_names => ["date", "area_code", "prefectureNameJ","testedPositive", "testedPositive_cum", "deaths", "deaths_cum"],
	item_names => ["date", "area_code", "prefectureNameJ","testedPositive", "testedPositive_cum", "deaths", "deaths_cum"],
	#alias => {pref => 2, positive_new => 3, positive_cum => 4 , deaths_new => 5, deaths_cum => 6},
	alias => {},
};
our $DEF_GRAPH = {
	html_title => $CDP->{src_info},
	png_path   => "$PNG_PATH",
	png_rel_path => $PNG_REL_PATH,
	html_file => "$HTML_PATH/nhk_japan.html",

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

sub	download
{
	my $self = shift;
	my ($p) = @_;
	$p = $p // {};

	my $csvf = $self->{src_file};
	my $url = $self->{src_url};
	my $cmd = "wget $url -O $csvf.dl0";

	my $download = $self->check_download();
	$download = 1 if($p->{download} > 1);

	if($download || !(-f "$csvf.dl0")){
		&do($cmd);
		&do("nkf -w80 $csvf.dl0 > $csvf");
	}
	#&load_transaction("$csvf.dl1", $csvf);
}

sub	do
{
	my ($cmd) = @_;

	dp::dp $cmd . "\n";
	system($cmd);
}

1;
