#!/usr/bin/perl
#
#
#
package defmhlw;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(defmhlw);

use strict;
use warnings;
use utf8;
use Encode 'decode';
use config;

my $WIN_PATH = "$config::WIN_PATH";
my $HTML_PATH = "$WIN_PATH/HTML2",
my $PNG_PATH  = "$WIN_PATH/PNG2",
my $PNG_REL_PATH  = "../PNG2",
my $CSV_PATH  = $config::CSV_PATH;

my $DEFAULT_AVR_DATE = $config::DEFAULT_AVR_DATE;
my $END_OF_DATA = $config::END_OF_DATA;
my $MLW_DL_FLAG_FILE = "$CSV_PATH/mhlw_flag";


####################################################################
#
#	https://github.com/kaz-ogiwara/covid19
#
# year,month,date,prefectureNameJ,prefectureNameE,testedPositive,peopleTested,hospitalized,serious,discharged,deaths,effectiveReproductionNumber
# 	2020,2,8,東京,Tokyo,3,,,,,,
#
#my $TKO_PATH = "$WIN_PATH/tokyokeizai";
#my $BASE_DIR = "$TKO_PATH/covid19/data";
#our $transaction = "$BASE_DIR/prefectures.csv";
my %defs = (
	positive =>	{mid => "p",
				src_file => "$CSV_PATH/mhlw_newcases.csv", 
				src_url => "https://covid19.mhlw.go.jp/public/opendata/newly_confirmed_cases_daily.csv",
				data_start => 2, 
				#keys => ["Prefecture"],
				#item_names => ["Date", "Prefecture", "Positive"] },
				keys => ["pref"],
				#item_names => ["Date", "Prefecture", "Inpatient", "Discharged", "ToBeConfirmed"] ,
				},

	hosp => {	mid => "h",
				src_file => "$CSV_PATH/mhlw_hospitalaized.csv", 
				src_url => "https://covid19.mhlw.go.jp/public/opendata/requiring_inpatient_care_etc_daily.csv",
				data_start => 2, 
				keys => ["pref"],
				#item_names => ["Date", "Prefecture", "Inpatient", "Discharged", "ToBeConfirmed"] ,
				item_names => ["pref"],
				},

	severe => {	mid => "s",
				src_file => "$CSV_PATH/mhlw_severe.csv", 
				src_url => "https://covid19.mhlw.go.jp/public/opendata/severe_cases_daily.csv",
				data_start => 2, 
				keys => ["pref"],
				#item_names => ["Date", "Prefecture", "Severe"]},
				item_names => ["pref"]
				},

	deaths => {	mid => "d",
				src_file => "$CSV_PATH/mhlw_deaths.csv", 
				src_url => "https://covid19.mhlw.go.jp/public/opendata/deaths_cumulative_daily.csv", 
				data_start => 2, 
				keys => ["pref"],
				#item_names => ["Date", "Prefecture", "Deaths"], cumrative => "init0",},
				item_names => ["pref"]
				},
	tested => {	mid => "t",
				src_file => "$CSV_PATH/mhlw_tested.csv", 
				src_url => "https://www.mhlw.go.jp/content/pcr_tested_daily.csv",
				data_start => 1, 
				#add_keys => ["Prefecture=ALL"],
				#keys => ["item"],
				#item_names => ["Date", "Tested"]},
				keys => ["pref"],
				item_names => ["pref"]
				#item_names => ["Date", "Prefecture", "Inpatient", "Discharged", "ToBeConfirmed"] ,
				},

);
my @defs_none = (

);

my $MHLW_CSV = "$CSV_PATH/mhlw.csv";
our $MHLW_TAG = 
{
	id => "mhlw",
	src_info => "MHLW open data",
	main_url => "https://www.mhlw.go.jp/stf/covid-19/open-data.html",
	src_file => "",
	src_url => 	"",
	cumrative => 0,

	down_load => \&download,

	#direct => "transaction",		# vertical or holizontal(Default)
	direct => "vertical_matrix",		# vertical or holizontal(Default)
	timefmt => '%Y/%m/%d',		# comverbt to %Y-%m-%d
	src_dlm => ",",
	key_dlm => "#",
	keys => ["item"],		# PrefectureNameJ, and Column name
	data_start => 1,
	alias => {},
	date_col => 0,
	data_start => 1,
	item_name_line => 1,		# from 1
	data_start_line => 2,		# from 1 
	alias => {},
	load_col => "",			# [   ]
};

our %MHLW_DEFS = ();
foreach my $k(keys %defs){
	my $def = {%$MHLW_TAG};
	my $p = $defs{$k};
	foreach my $k (keys %$p){
		$def->{$k} = $p->{$k};
	}
	$MHLW_DEFS{$k} = $def;
}

our $MHLW_GRAPH = {
	html_title => $MHLW_TAG->{src_info},
	png_path   => "$PNG_PATH",
	png_rel_path => $PNG_REL_PATH,
	html_file => "$HTML_PATH/mhlw_open_data.html",

	dst_dlm => "\t",
	avr_date => 7,
	END_OF_DATA => $END_OF_DATA,
	graph => "line",

	timefmt => '%Y-%m-%d', format_x => '%m/%d',
	term_x_size => 1000, term_y_size => 350,

	ylabel => "Number", ymin => 0,
	additional_plot => "",

	graph_params => [
	],
};

sub	download
{
	my $self = shift;
	my ($p) = @_;

	my $item = $p->{item};
	dp::ABORT "download [$item]" if(! defined $MHLW_DEFS{$item});

	my $download = $self->check_download();
	$download = 1 if($p->{download} > 1);

	# severe => {src_file => "$CSV_PATH/mhlw_severe.csv", src_url => "https://covid19.mhlw.go.jp/public/opendata/severe_cases_daily.csv"},
	my $def = $MHLW_DEFS{$item};
	my $csvf_raw = $def->{src_file} . ".raw";
	my $csvf = $def->{src_file};
	my $cmd = "wget " . $def->{src_url} . " -O $csvf_raw";
	&do($cmd) if($download || !(-f $csvf));
	&do("nkf -w80 $csvf_raw > $csvf");
	dp::dp "download done\n";
}

sub	do
{
	my ($cmd) = @_;

	dp::dp $cmd . "\n";
	system($cmd);
}

1;
