#
#
#
package config;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(config);

use strict;
use warnings;
#use ccse;
#use who;

our $VERBOSE = 1;
our $DEBUG = 0;
our $CODE_PATH = "/home/masataka/who/src";
#our $WIN_PATH = "/mnt/f/cov/plussum.github.io";
our $WIN_PATH = "/mnt/f/_share/cov/plussum.github.io";
our $HTML_PATH = "$WIN_PATH/HTML";
our $CSV_PATH  = "$WIN_PATH/CSV";
our $PNG_PATH  = "$WIN_PATH/PNG";
our $PNG_REL_PATH  = "../PNG";		# HTML からの相対パス
our $CSV_REL_PATH  = "../CSV";		# HTML からの相対パス

our $DEFAULT_AVR_DATE = 7;
our $END_OF_DATA = "###EOD###";

our $MAIN_KEY = "mainkey";

our $WHO_INDEX = "who_index.html";
our $RT_IP = 5;
our $RT_LP = 8;
our $THRESH_FT = {NC => 9, ND => 3, NR => 3};		# 

our $NO_DATA = "NaN";
our $DEFAULT_KEY_DLM = "#";

our $POPF = "$WIN_PATH/pop.csv";
#our $POPF_JP = "$WIN_PATH/popjp.txt";
#our $POPF_US = "$WIN_PATH/popus.txt";
our $POP_BASE = 100 * 1000;			# 10万人当たりのケース数
our $POP_THRESH = 100 * 1000;		# 人口が少ないと振れ幅が大きいので、この人口より少ない国は対象外にする

our $SYNONYM_FILE = "$WIN_PATH/synonym.csv";
our	%SYNONYM = ();

our $DLM = "\t";
our $DLM_OUT = "\t";


my $CCSE_BASE_DIR = "/home/masataka/who/COVID-19/csse_covid_19_data/csse_covid_19_time_series";

our $CSS = << "_EOCSS_";
    <meta charset="utf-8">
    <style type="text/css">
    <!--
        span.c {font-size: 12px;}
    -->
    </style>
	<meta http-equiv="Cache-Control" content="no-cache">
_EOCSS_

our $CLASS = "class=\"c\"";

1;	
