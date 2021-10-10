#!/usr/bin/perl
#
#
#
use strict;
use warnings;
use utf8;
use Data::Dumper;
use List::Util 'min';
use POSIX ":sys_wait_h";
use Proc::Wait3;
use Time::HiRes qw( usleep gettimeofday tv_interval );

use config;
use csvlib;
use csv2graph;
use dp;

use defratoc;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $VERBOSE = 0;
my $DOWNLOAD = 1;

my $WIN_PATH = "/mnt/f/_share/netatmo/RATOC/";
my $HTML_PATH = "$WIN_PATH/HTML",
my $PNG_PATH  = "$WIN_PATH/PNG",
my $PNG_REL_PATH  = "../PNG",
my $CSV_PATH  = $WIN_PATH;

my $DEFAULT_AVR_DATE = 7;
my $END_OF_DATA = "###EOD###";

my $WEEK_BEFORE = 4;
my $THRESH_POP_NC_LAST = 1.0; #0.5;
my $mainkey = $config::MAIN_KEY;

my $DOWN_LOAD = 1;
my $RECENT = -62;		# recent = 2month

my $line_thick 	= "line linewidth 2";
my $line_thin 		= "line linewidth 1" ;
my $line_thick_dot = "line linewidth 2 dt(7,3)";
my $line_thin_dot 	= "line linewidth 1 dt(6,4)";
my $line_thin_dot2 	= "line linewidth 1 dt(2,6)";
my $box_fill  		= "boxes fill";
my $box_fill_solid 	= 'boxes fill solid border lc rgb "white" lw 1';

my @ALL_PARAMS = qw/ratoc/;
my $DELAY_AT_ALL = 1;

my @cdp_list = ($defratoc::CDP_DEF);

#
#
#
my @gcl = ("royalblue", "#e36c09", "forest-green", "mediumpurple3", 			# https://mz-kb.com/blog/2018/10/31/gnuplot-graph-color/
			"dark-pink", "#00d0f0", "#60d008", "brown",  "gray20", 
			"gray30");
my @bcl = ( "gray10", "dark-orange",		# 0.5
			"midnight-blue", "dark-orange",			# 0.2
			"steelblue", "dark-orange",		# 0.1
			"dark-green", "dark-orange",	# 0.05
			"seagreen", "dark-orange",		# 0.02
			"gray70", "dark-orange",		# 0.01
			"gray80", "dark-orange",		# 0.01
			"gray90", "dark-orange",		# 0.01
			"white", "dark-orange",
			"white", "dark-orange",
		);

####################################
#
#	Start Main
#
####################################
my %golist = ();
my $all = "";
my $db_all = 0;
my $end_target = "";

if($#ARGV >= 0){
	for(my $i = 0; $i <= $#ARGV; $i++){
		$_ = $ARGV[$i];
		if(/-all/){
			$all = 1;
			next;
			#last;
		}
		elsif(/^-nd/){
			$DELAY_AT_ALL = 0;
			next;
		}
		elsif(/^-dball/){
			$db_all = 1;
			next;
		}
		elsif(/^-clear/){
			dp::dp "Remove .png and other plot data: $PNG_PATH\n";
			system("ls $PNG_PATH | head");
			#dp::dp "Remove OK? (YES/no)";
			#my $ok = <STDIN>;
			my $ok = "YES";
			if(!($ok =~ /no/i)){
				system("rm $PNG_PATH/*");
			}
			exit;
		}
		elsif(/^-et/){
			$end_target = $ARGV[++$i];
			dp::dp "end_target: $end_target\n";
			next;
		}
		elsif(/-DL/){
			$DOWNLOAD = $ARGV[++$i];
			next;
		}
		foreach my $cdp (@cdp_list){
			if($cdp->{id} eq $_){
				$golist{$_} = 1 
			}
		}
		if(! (defined $golist{$_})){
			dp::dp "Undefined dataset [$_]\n";
		}
	}
}
else {
	my @ids = ();
	foreach my $cdp (@cdp_list){
		my $id = $cdp->{id};
		push(@ids, $id);
	}
	#dp::dp "usage:$0 " . join(" | ", "-all", @ids, "-et | -poplist") ."\n";
	#exit;
}
dp::dp "Parames: " . join(",", keys %golist) . "\n";
my $gp_list = [];

#
#	RATOC
#
if(1) { # $golist{ratoc}) 
	dp::set_dp_id("ratoc");
	
	@$gp_list = ();
	# positive,  reqcare, deaths, severe
	my %cdp_raw = ();
	my @cdps = ();
	my $cdp = csv2graph->new($defratoc::CDP_DEF); 						# Load Johns Hopkings University CCSE
	$cdp->load_csv({download => $DOWNLOAD});
	$cdp->dump();
	exit;

	csv2graph->gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
			row => 4,
			html_tilte => "COVID-19 related data visualizer ",
			src_url => "src_url",
			html_file => "$HTML_PATH/mhlw_pref.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $cdp->{src_info},
		}
	);
}

sub	set_list
{
	my ($p, $gp, @w) = @_;

	my $pp = $p;
	foreach my $k (@w){
		if(! defined $p->{$k}){
			$pp->{$k} = {};
		}
		$pp = $pp->{$k};
	}
	$pp->{plot_png} = $gp->{plot_png} // "";
	$pp->{plot_csv} = $gp->{plot_csv} // "";
	$pp->{plot_cmd} = $gp->{plot_cmd} // "";
	return $pp;
}


sub	completing_zero
{
	my($self) = @_;

	my $csvp = $self->{csv_data};
	my $dates = $self->{dates};
	foreach my $k (keys %$csvp){
		my $cp = $csvp->{$k};
		for(my $dt = 1; $dt <= $dates; $dt++){
			$cp->[$dt] = $cp->[$dt-1] if($cp->[$dt] eq "NaN" || $cp->[$dt] == 0);
		}
	}
}



#
#
#
sub	calc_dlt
{
	my($pop_max) = @_;
	#my @dlt = (10, 5, 2.5, 2, 1); 
	my @dlt = (0.2, 0.5, 1, 2, 2.5, 5, 10); 

	for(my $dlt_dig = 0; $dlt_dig < 5; $dlt_dig++){
		my $dig = 10**($dlt_dig);
		foreach my $d (@dlt){
			my $dd = $d * $dig;
			my  $dlt = $pop_max / $dd;
			#dp::dp "digit: $dlt $dd, $dig * $dlt_dig [$pop_max]\n";
			return $dd if($dlt < 5.9);
		}
	}
	dp::ABORT "$pop_max\n";
	return "";
}


sub	zd
{
	my($v) = @_;

	$v = 1 / 999 if($v == 0);
	return $v;
}


system("./genreport.pl");
my $times_cmd = "./htmllist.pl";
dp::dp "times: $times_cmd\n";
system($times_cmd);
system("ls -lt $HTML_PATH | head -20");

#
#	Upload to Sakura
#
if($golist{upload}) {
	system("./uploadweb");
}

#
#	Down Load CSV 
#
sub	download
{
	my ($cdp) = @_;
	return 1;
}




#
#
#
sub	test_seach_list
{
	my @skeys = (
		["Japan", "~Japan-"],
		["United Kingdom", "United Kingdom-"],
	);
	my @items = ("Japan", "Japan-", "United State", "United Kingdom-Falkland Islands");
	foreach my $item ("Japan", "Japan-", "United State"){
		for my $skey (@skeys){
			dp::dp csvlib::search_listn($item, @$skey) . "[$item]" . join(",", @$skey) . "\n";
		}
	}
}
