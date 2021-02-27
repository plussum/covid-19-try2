#!/usr/bin/perl
#
#		target_area => "Japan,XXX,YYY", 
#		exclusion_are => ""
#
#
package defccse;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(defccse);

use strict;
use warnings;
use utf8;
use Encode 'decode';
use config;

my $VERBOSE = 0;
my $DOWN_LOAD = 0;

my $WIN_PATH = "$config::WIN_PATH";
my $HTML_PATH = "$WIN_PATH/HTML2",
my $PNG_PATH  = "$WIN_PATH/PNG2",
my $PNG_REL_PATH  = "../PNG2",
my $CSV_PATH  = $config::WIN_PATH;

my $DEFAULT_AVR_DATE = $config::DEFAULT_AVR_DATE;
my $END_OF_DATA = $config::END_OF_DATA;

#
#	Definition of Johns Hpkings University CCSE CSV format
#
#	Province/State,Country/Region,Lat,Long,1/22/20
#
my $CCSE_ROOT = "$WIN_PATH/ccse/COVID-19";
my $CCSE_BASE_DIR = "$CCSE_ROOT/csse_covid_19_data/csse_covid_19_time_series";
our $CCSE_DEF = {
	id => "ccse",
	src_info => "Johns Hopkins CSSE",
	main_url =>  "https://covid19.apple.com/mobility",
	src_file =>  "$CCSE_BASE_DIR/time_series_covid19_confirmed_global.csv",
	src_url => "https://github.com/beoutbreakprepared/nCoV2019",
	cumrative => 1,
	down_load => \&download,

	src_dlm => ",",
	key_dlm => "-",
	keys => ["Country/Region", "Province/State"],		# 5, 1, 2
	data_start => 4,

	direct => "holizontal",		# vertical or holizontal(Default)
	timefmt => '%m/%d/%y',		# comverbt to %Y-%m-%d
	alias => {"subr" => "Province/State", "region" => "Country/Region"},
};
#dp::dp $CCSE_DEF->{csv_file} . "\n";
our $CCSE_GRAPH = {
	html_title => $CCSE_DEF->{src_info},
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
sub	download
{
	my ($cdp) = @_;

	#system("(cd ../COVID-19; git pull origin master)");
	system("(cd $CCSE_ROOT; git pull origin master)");
	system("cp $CCSE_BASE_DIR/*.csv $config::CSV_PATH/");
}

