#!/usr/bin/perl
#
#	Apple Mobile report
#
package defamt;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(defamt);

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
	csv_file =>  "$config::WIN_PATH/applemobile/applemobilitytrends.csv.txt",
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

sub download
{
}

1; 
