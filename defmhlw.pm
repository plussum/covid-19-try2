#!/usr/bin/perl
#
#		https://www.mhlw.go.jp/stf/covid-19/open-data.html
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
#
#my $TKO_PATH = "$WIN_PATH/tokyokeizai";
#my $BASE_DIR = "$TKO_PATH/covid19/data";
#our $transaction = "$BASE_DIR/prefectures.csv";
sub sub_hosp
{
    my ($l) = @_;
	$l =~ s/Date,/pref#DLM#kind,/;
    $l =~ s/\((\w+)\) ([\w ]+) */$1#DLM#$2/g;
	$l =~ s/Discharged from hospital or released from treatment/Discharged/g;
	$l =~ s/Requiring inpatient care/Inpatient/g;
	$l =~ s/To be confirmed/ToBeConfirmed/g;
	#dp::dp $l . "\n";
    return $l;
}
sub	sub_tested
{
    my ($l) = @_;
	#$l =~ s/PCR 検査実施件数\(単日\)/tested/;
	$l =~ s/,PCR .*$/,tested/;
	      ##PCR 検査実施人数\(単日\)
	dp::dp ">>>>>" . $l . "\n";
	return $l;
}


my @defs = (
	{	tag => "tested", mid => "t",
				src_file => "$CSV_PATH/mhlw_tested.csv", 
				src_url => "https://www.mhlw.go.jp/content/pcr_tested_daily.csv",
				data_start => 1, 
				direct => "vertical",		# vertical or holizontal(Default)
				keys => ["tested"],		# Japan, total_vaccinations_per_hundred,
				data_start => 1,
				item_name_line => 0,
				data_start_line => 1,
				item_name_replace => ["tested"],
				alias => {"tested" => 1},
				default_item_name => "tested",
				subs => \&sub_tested,
				#load_col => [1],		# columns for load B -> 0, C->1 (skip col 0:date)
	},
	{	tag => "hospi",  	mid => "h",
				src_file => "$CSV_PATH/mhlw_hospitalaized.csv", 
				src_url => "https://covid19.mhlw.go.jp/public/opendata/requiring_inpatient_care_etc_daily.csv",
				direct => "vertical_matrix",		# vertical or holizontal(Default)
				data_start => 2, 
				#kind_names => ["inpatient", "dischaged", "tobe_confirmed"],
				keys => ["pref", "kind"],
				#item_names => ["Date", "Prefecture", "Inpatient", "Discharged", "ToBeConfirmed"] ,
				item_names => ["pref", "kind"],
				subs => \&sub_hosp,
				default_item_name => "",
	},

	{ tag => "positive", mid => "positive",
				src_file => "$CSV_PATH/mhlw_newcases.csv", 
				src_url => "https://covid19.mhlw.go.jp/public/opendata/newly_confirmed_cases_daily.csv",
				direct => "vertical_matrix",		# vertical or holizontal(Default)
				data_start => 1, 
				#keys => ["Prefecture"],
				#item_names => ["Date", "Prefecture", "Positive"] },
				keys => ["pref"],
				#item_names => ["Date", "Prefecture", "Inpatient", "Discharged", "ToBeConfirmed"] ,
				default_item_name => "pref",
				subs => "",
	},

	{ tag => "severe", 	mid => "severe",
				src_file => "$CSV_PATH/mhlw_severe.csv", 
				src_url => "https://covid19.mhlw.go.jp/public/opendata/severe_cases_daily.csv",
				direct => "vertical_matrix",		# vertical or holizontal(Default)
				data_start => 1, 
				keys => ["pref"],
				#item_names => ["Date", "Prefecture", "Severe"]},
				item_names => ["pref"],
				default_item_name => "pref",
				subs => "",
	},

	{ tag => "deaths", 	mid => "deaths",
				src_file => "$CSV_PATH/mhlw_deaths.csv", 
				src_url => "https://covid19.mhlw.go.jp/public/opendata/deaths_cumulative_daily.csv", 
				direct => "vertical_matrix",		# vertical or holizontal(Default)
				data_start => 1, 
				keys => ["pref"],
				#item_names => ["Date", "Prefecture", "Deaths"], cumrative => "init0",},
				item_names => ["pref"],
				default_item_name => "pref",
				subs => "",
				cumrative => 1,
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

our @MHLW_DEFS = ();
our %MHLW_HASH = ();
for(my $i = 0; $i <= $#defs; $i++){
	my $p = $defs[$i];
	my $def = {%$MHLW_TAG};
	foreach my $k (keys %$p){
		$def->{$k} = $p->{$k};
	}
	$MHLW_DEFS[$i] = $def;
	my $tag = $p->{tag};
	$MHLW_HASH{$tag} = $MHLW_DEFS[$i];
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
	dp::dp "[[[$item]]\n";
	dp::ABORT "download [$item]" if(! defined $MHLW_HASH{$item});

	my $download = $self->check_download();
	$download = 1 if($p->{download} > 1);

	# severe => {src_file => "$CSV_PATH/mhlw_severe.csv", src_url => "https://covid19.mhlw.go.jp/public/opendata/severe_cases_daily.csv"},
	my $def = $MHLW_HASH{$item};
	dp::dp ">>> [$def]\n";

	my $csvf_raw = $def->{src_file} . ".raw";
	my $csvf = $def->{src_file};
	#my $cmd = "wget " . $def->{src_url} . " -O $csvf_raw";
	my $cmd = "curl " . $def->{src_url} . " -o $csvf_raw";
	&do($cmd) if($download || !(-f $csvf));
	my $file_size = csvlib::file_size($csvf_raw);
	if($file_size > 1024){
		&do("nkf -w80 $csvf_raw > $csvf");
	}
	else {
		dp::WARNING "file_size: $file_size($download), $cmd\n";
	}
	dp::dp "download done\n";
}

sub	do
{
	my ($cmd) = @_;

	dp::dp $cmd . "\n";
	system($cmd);
}

1;
